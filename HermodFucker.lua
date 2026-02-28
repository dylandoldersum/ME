---@diagnostic disable: undefined-global, missing-parameter
local API              = require("api")
local UTILS            = require("utils")
local GUILib           = require("gui_lib")

--NOTES
--WAR OFFICE REGION 13214

-- ── Config ────────────────────────────────────────────────────────────────────

local FOOD_NAME        = "shark" -- naam van het food item (lowercase, partial match)

-- ── Constanten ────────────────────────────────────────────────────────────────

local WAR_AREA_REGION  = 13214
local RASIAL_CITDAEL   = 3355
local ARMORED_ZOMBIE   = 30164
local HERMOD_BOSS      = 30163
--API.DoAction_Interface(0x24,0xffffffff,1,1591,60,-1,API.OFF_ACT_GeneralInterface_route)#START interface boss

local SCRIPT_VERSION   = "1.0"

-- ── State ─────────────────────────────────────────────────────────────────────

local state            = "IDLE"
local startTime        = os.time()
local killCount        = 0
local plateCount       = 0
local startXP          = 0
local lootLog          = {} -- [name] = { count, gpTotal }
local totalGP          = 0
local bossRoomStartPos = nil

-- ── GUI ───────────────────────────────────────────────────────────────────────

local gui              = GUILib.new()

-- ── Helpers ───────────────────────────────────────────────────────────────────

local instanceTimer    = { { 861, 0, -1, -1, 0 }, { 861, 2, -1, 0, 0 }, { 861, 4, -1, 2, 0 }, { 861, 8, -1, 4, 0 } }

local function isInstanceTimerPresent()
    local result = API.ScanForInterfaceTest2Get(false, instanceTimer)
    print("[DEBUG][Timer] #result=" .. #result)
    if #result > 0 then
        local inter = result[1]
        local timerText = tostring(inter.textids)
        print("[DEBUG][Timer] textids='" .. timerText .. "'")
        if timerText == "00:00" then
            print("[DEBUG][Timer] Timer op 0:00 → false")
            return false
        end
        return true
    else
        print("[DEBUG][Timer] Geen timer interface gevonden → false")
        return false
    end
end

local function inWarArea()
    return API.PlayerRegion().z == WAR_AREA_REGION
end

local function inRasialCitdal()
    return API.PlayerRegion().z == RASIAL_CITDAEL
end

local function inBossRoom()
    --doorway met Exit action
    local doors = API.ReadAllObjectsArray({ 0 }, { -1 }, { "Chamber doorway" })
    if doors and #doors > 0 then
        for _, door in pairs(doors) do
            if door.Action == "Exit" then return true end
        end
    else
        print("[Debug][inBossRoom] Geen Chamber doorway gevonden")
    end
    --Hermod is zichtbaar = in de bossroom
    local hermod = API.ReadAllObjectsArray({ 1 }, { HERMOD_BOSS }, {})
    if hermod and #hermod > 0 then
        print("[Debug][inBossRoom] Hermod gevonden")
        return true
    end
    return false
end

local function formatXP(xp)
    if xp >= 1000000 then
        return string.format("%.2fm", xp / 1000000)
    elseif xp >= 1000 then
        return string.format("%.1fk", xp / 1000)
    else
        return tostring(math.floor(xp))
    end
end

local function snapshotInv()
    local snap = {}
    for _, item in ipairs(Inventory:GetItems()) do
        if item.id and item.id > 0 then
            snap[item.id] = (snap[item.id] or 0) + item.amount
        end
    end
    return snap
end

local function getXpHr()
    local s = math.max(1, os.difftime(os.time(), startTime))
    local gained = API.GetSkillXP("NECROMANCY") - startXP
    return gained / s * 3600
end

local function formatGP(gp)
    if gp >= 1000000 then
        return string.format("%.2fm", gp / 1000000)
    elseif gp >= 1000 then
        return string.format("%.1fk", gp / 1000)
    else
        return tostring(math.floor(gp))
    end
end

local function getGpHr()
    local s = math.max(1, os.difftime(os.time(), startTime))
    return totalGP / s * 3600
end

-- ── Portal logic ──────────────────────────────────────────────────────────────

local function enterRasialPortal()
    if not inWarArea() then return false end
    Interact:Object("Portal (Rasial's Citadel)", "Enter")
    return true
end

local function enterBossRoom()
    if not inRasialCitdal() then return false end
    Interact:Object("Chamber doorway", "Enter")
    return true
end

local function confirmBossEntry()
    API.DoAction_Interface(0x24, 0xffffffff, 1, 1591, 60, -1, API.OFF_ACT_GeneralInterface_route)
end

-- ── Boss combat ───────────────────────────────────────────────────────────────

local HERMOD_ANIM_DODGE = 21650
local DODGE_COOLDOWN    = 4 -- seconden (dekt de animatieduur)
local lastDodgeTime     = 0
local hermodWasAlive    = false
local lootTriggered     = false

local FOOD_HP_THRESHOLD = 50
local KEY_1             = 0x31

local lastEatTime       = 0
local lastSpecTime      = 0
local lowHpSince        = nil

local function UseAbilityByName(skillName)
    local ability = UTILS.getSkillOnBar(skillName)
    if ability ~= nil then
        return API.DoAction_Ability_Direct(ability, 1, API.OFF_ACT_GeneralInterface_route)
    end
    return false
end

local function eatNdrink()
    local currentHp = API.GetHPrecent()
    if currentHp >= FOOD_HP_THRESHOLD then
        lowHpSince = nil
        return
    end

    if lowHpSince == nil then lowHpSince = os.time() end
    local now = os.time()

    if (now - lastEatTime) >= 2 then
        UseAbilityByName("Eat Food")
        lastEatTime = now
        state = "EATING FOOD"
    end
end

local function teleportToWarRetreat()
    UseAbilityByName("War's Retreat Teleport")
end

local function hasFood()
    local items = Inventory:GetItems()
    for _, item in ipairs(items) do
        if item.name and item.name:lower():find(FOOD_NAME) then
            return true
        end
    end
    return false
end

local function countHermodicInInv()
    local count = 0
    local items = Inventory:GetItems()
    for _, item in ipairs(items) do
        if item.name and item.name:lower():find("hermodic plate") then
            count = count + 1
        end
    end
    return count
end

local function bankRun()
    state = "BANK_RUN"
    print("[Hermod] Geen food - teleporteren naar War Retreat...")
    teleportToWarRetreat()

    local timeout = os.time() + 20
    while not inWarArea() and os.time() < timeout do
        API.RandomSleep2(600, 100, 100)
    end

    API.RandomSleep2(800, 200, 200)
    Interact:Object("Bank chest", "Use")
    API.RandomSleep2(2500, 300, 500)

    API.KeyboardPress2(KEY_1, 50, 25)
    API.RandomSleep2(1500, 300, 300)

    -- Wacht tot food in inventory zitten
    local foodTimeout = os.time() + 15
    while not hasFood() and os.time() < foodTimeout do
        API.RandomSleep2(600, 100, 100)
    end

    if not hasFood() then
        print("[Hermod] Quickload mislukt - geen " .. FOOD_NAME .. " na bank. Script gestopt.")
        API.Write_LoopyLoop(false)
        return
    end

    print("[Hermod] Bank klaar, " .. FOOD_NAME .. " gevonden - verder gaan.")
end

local function findNPC(npcId)
    local result = API.ReadAllObjectsArray({ 1 }, { npcId }, {})
    if result and #result > 0 then return result[1] end
    return nil
end

local function hasTarget()
    local interacting = API.ReadLpInteracting()
    if interacting.Id ~= 0 and interacting.Life > 0 then
        return true
    elseif not interacting or not interacting.Id or not interacting.Life then
        return false
    end
end

local function walkToStartPos()
    if bossRoomStartPos == nil then return end
    state = "TERUG_START"
    print("[Hermod] Terug naar startpositie: " .. bossRoomStartPos.x .. "," .. bossRoomStartPos.y)
    API.DoAction_Tile(WPOINT.new(bossRoomStartPos.x, bossRoomStartPos.y, bossRoomStartPos.z))
    API.WaitUntilMovingEnds(6, 8)
end

local function dodgeAttack()
    local p      = API.PlayerCoord()
    local dist   = math.random(2, 3)
    local dir    = math.random(1, 4)
    local dx, dy = 0, 0
    if dir == 1 then
        dy = dist  -- noord
    elseif dir == 2 then
        dy = -dist -- zuid
    elseif dir == 3 then
        dx = dist  -- oost
    else
        dx = -dist -- west
    end
    API.DoAction_Tile(WPOINT.new(p.x + dx, p.y + dy, p.z))
end

local function loot()
    state = "WACHT_LOOT"
    print("[Hermod] Wachten op loot...")
    local lootItems = {}
    local spawnTimeout = os.time() + 10
    while #lootItems == 0 and os.time() < spawnTimeout do
        lootItems = API.ReadAllObjectsArray({ 3 }, { -1 }, {})
        API.RandomSleep2(300, 50, 50)
    end
    if #lootItems == 0 then
        print("[Hermod] Geen loot gevonden.")
        return
    end

    killCount = killCount + 1
    print("[Hermod] Kill #" .. killCount .. " bevestigd.")

    state = "LOOTING"
    print("[Hermod] Looten...")

    local plateBefore = countHermodicInInv()
    local invBefore   = snapshotInv()

    if Inventory:IsFull() then
        print("[Hermod] Inventory vol, eten voor ruimte...")
        UseAbilityByName("Eat Food")
        API.RandomSleep2(1200, 200, 300)
    end

    local lootNumber = 0
    while true do
        print("KLIKKEN OP GRNDITEM")
        if #lootItems > 0 then
            if Inventory:IsFull() then
                if not hasFood() then
                    print("[Hermod] Inventory vol & geen food tijdens loot - bankrun...")
                    bankRun()
                    return
                end
                print("[Hermod] Inventory vol, eten voor ruimte...")
                UseAbilityByName("Eat Food")
                API.RandomSleep2(1200, 200, 300)
            end
            API.DoAction_G_Items1(0x29, { lootItems[1].Id }, 50)
            API.RandomSleep2(1200, 300, 600)
            API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1678, 8, -1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(1200, 300, 600)
            API.DoAction_Interface(0x24, 0xffffffff, 1, 1622, 21, -1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(1200, 300, 600)
            lootItems = API.ReadAllObjectsArray({ 3 }, { -1 }, {})
            lootNumber = lootNumber + 1
        else
            lootItems = API.ReadAllObjectsArray({ 3 }, { -1 }, {})
            API.RandomSleep2(600, 0, 600)
        end
        if #lootItems == 0 and lootNumber > 0 then
            local plateAfter = countHermodicInInv()
            local newPlates = plateAfter - plateBefore
            if newPlates > 0 then
                plateCount = plateCount + newPlates
                print("[Hermod] Hermodic plate geloot! Totaal: " .. plateCount)
            end
            local invAfter = snapshotInv()
            local idToName = {}
            for _, item in ipairs(Inventory:GetItems()) do
                if item.id then idToName[item.id] = item.name end
            end
            for id, amtAfter in pairs(invAfter) do
                local gained = amtAfter - (invBefore[id] or 0)
                if gained > 0 then
                    local name = idToName[id] or ("Item #" .. id)
                    local price = API.GetExchangePrice(id)
                    if not price or price == -1 then
                        price = API.GetExchangePrice(id - 1) or 0
                    end
                    local gpGained = price * gained
                    if not lootLog[name] then
                        lootLog[name] = { count = 0, gpTotal = 0 }
                    end
                    lootLog[name].count   = lootLog[name].count + gained
                    lootLog[name].gpTotal = lootLog[name].gpTotal + gpGained
                    totalGP               = totalGP + gpGained
                end
            end
            print("[Hermod] Loot klaar.")
            return
        end
    end
end

local function handleBossRoom()
    local hermod = findNPC(HERMOD_BOSS)

    eatNdrink()

    -- 1. ALTIJD eerst: dodge check (overrides zombies en aanvallen)
    if hermod and hermod.Anim == HERMOD_ANIM_DODGE then
        local now = os.time()
        if now - lastDodgeTime >= DODGE_COOLDOWN then
            state = "DODGE"
            print("[Debug][Boss] DODGE! Anim=" .. hermod.Anim)
            dodgeAttack()
            lastDodgeTime = now
            -- Wacht tot speler de nieuwe tile bereikt heeft, dan pas aanvallen
            API.WaitUntilMovingEnds(2, 4)
            API.DoAction_NPC(0x29, API.OFF_ACT_AttackNPC_route, { HERMOD_BOSS }, 20, WPOINT.new(0, 0, 0), true, 0)
        else
            state = "DODGE_WACHT"
        end
        return
    end

    -- 2. Armored Zombies (Hermod immuun zolang ze leven)
    local zombies = API.ReadAllObjectsArray({ 1 }, { ARMORED_ZOMBIE }, {})
    print("[Debug][Boss] Zombies=" .. (zombies and #zombies or 0)
        .. " Hermod=" .. (hermod and "ja Anim=" .. hermod.Anim or "nee"))
    if zombies and #zombies > 0 then
        state = "KILLING_ZOMBIE"
        API.DoAction_NPC(0x29, API.OFF_ACT_AttackNPC_route, { ARMORED_ZOMBIE }, 20, WPOINT.new(0, 0, 0), true, 0)
        return
    end

    local currentAdrenaline = API.GetAddreline_()
    if API.DeBuffbar_GetIDstatus(55524, false).id == 0 then
        print("TRUEEEEE")
        if currentAdrenaline >= 30 then
            if os.difftime(os.time(), lastSpecTime) > 3 then
                print("[Hermod] Adrenaline >= 30 >> Casting special attack")
                UseAbilityByName("Weapon special attack")
                lastSpecTime = os.time()
                state = "Casting special attack."
                API.RandomSleep2(400, 100, 100)
            else
                state = "Special attack queued..."
            end
        end
    end

    -- 3. Wacht tot Hermod spawned / loot als hij net doodging
    if not hermod then
        if hermodWasAlive and not lootTriggered then
            hermodWasAlive = false
            lootTriggered = true
            loot()
            walkToStartPos()
        else
            state = "WACHT_HERMOD"
        end
        return
    end

    -- 4. Hermod dood? → loot (1x per kill)
    if hermod.Life < 1 then
        if not lootTriggered then
            hermodWasAlive = false
            lootTriggered = true
            loot()
            walkToStartPos()
        end
        return
    end

    -- 5. Aanvallen
    hermodWasAlive = true
    lootTriggered = false
    state = "ATTACK_HERMOD"
    if not hasTarget() then
        API.DoAction_NPC(0x29, API.OFF_ACT_AttackNPC_route, { HERMOD_BOSS }, 20, WPOINT.new(0, 0, 0), true, 0)
    end
end

-- ── ImGui UI ──────────────────────────────────────────────────────────────────

local function renderGUI()
    local colorCount, styleCount = gui:pushTheme()
    gui:setupWindow("HermodFucker", 380, 0)

    if gui:beginWindow("Hermod Fucker v" .. SCRIPT_VERSION .. "###HermodFucker") then
        -- State color mapping
        local stateColor
        if state == "ATTACK_HERMOD" or state == "KILLING_ZOMBIE" then
            stateColor = gui.theme.colors.success
        elseif state == "DODGE" or state == "EATING FOOD"
            or state == "Casting special attack." then
            stateColor = gui.theme.colors.warning
        elseif state == "NO_INSTANCE" or state == "BANK_RUN" then
            stateColor = gui.theme.colors.error
        else
            stateColor = gui.theme.colors.hint
        end

        -- Runtime string
        local elapsed = os.difftime(os.time(), startTime)
        local h       = math.floor(elapsed / 3600)
        local mins    = math.floor((elapsed % 3600) / 60)
        local secs    = elapsed % 60
        local runtime = string.format("%02d:%02d:%02d", h, mins, secs)

        if gui:beginTabBar("##hf_tabs") then
            -- ── Stats tab ─────────────────────────────────────────────────
            if gui:beginTab("Stats###tab_stats") then
                if gui:beginInfoTable("##hf_stats", 0.40) then
                    gui:tableRow("State", state, stateColor)
                    gui:tableRow("Runtime", runtime)
                    gui:tableRow("Kills", tostring(killCount))
                    gui:tableRow("Plates", tostring(plateCount),
                        plateCount > 0 and gui.theme.colors.accent or nil)
                    gui:tableRow("XP/hr (Def)", formatXP(getXpHr()),
                        { 0.40, 0.80, 1.0, 1.0 })
                    gui:tableRow("GP/hr", formatGP(getGpHr()),
                        { 1.0, 0.84, 0.0, 1.0 })
                    gui:tableRow("Total GP", formatGP(totalGP),
                        { 1.0, 0.84, 0.0, 1.0 })
                    gui:endColumns()
                end
                gui:endTab()
            end

            -- ── Loot Log tab ──────────────────────────────────────────────
            if gui:beginTab("Loot Log###tab_loot") then
                local sorted = {}
                for name, entry in pairs(lootLog) do
                    sorted[#sorted + 1] = {
                        name    = name,
                        count   = entry.count,
                        gpTotal = entry.gpTotal,
                    }
                end
                table.sort(sorted, function(a, b) return a.gpTotal > b.gpTotal end)

                if #sorted == 0 then
                    gui:spacing(2)
                    gui:text("No loot registered yet.", "hint")
                else
                    if ImGui.BeginTable("##loot", 3, 0) then
                        ImGui.TableSetupColumn("Item",
                            ImGuiTableColumnFlags.WidthStretch, 0.55)
                        ImGui.TableSetupColumn("Qty",
                            ImGuiTableColumnFlags.WidthStretch, 0.15)
                        ImGui.TableSetupColumn("Value",
                            ImGuiTableColumnFlags.WidthStretch, 0.30)
                        ImGui.TableHeadersRow()

                        local goldColor = { 1.0, 0.84, 0.0, 1.0 }
                        for _, entry in ipairs(sorted) do
                            gui:tableRow(
                                { entry.name, tostring(entry.count), formatGP(entry.gpTotal) },
                                { nil, nil, goldColor }
                            )
                        end
                        ImGui.EndTable()
                    end
                end
                gui:endTab()
            end

            gui:endTabBar()
        end
    end
    gui:endWindow()
    gui:popTheme(colorCount, styleCount)
end

-- ── Init ──────────────────────────────────────────────────────────────────────

startXP = API.GetSkillXP("NECROMANCY")
print("[Hermod] Gestart.")

-- ── Main loop ─────────────────────────────────────────────────────────────────

API.Write_LoopyLoop(true)
DrawImGui(renderGUI)

while API.Read_LoopyLoop() do
    API.SetMaxIdleTime(5)
    if API.GetGameState2() == 3 then
        local inBoss = inBossRoom()
        print("[DEBUG][Loop] inBossRoom=" ..
            tostring(inBoss) .. " inWarArea=" .. tostring(inWarArea()) .. " inCitadel=" .. tostring(inRasialCitdal()))
        if inBoss then
            local timerPresent = isInstanceTimerPresent()
            print("[DEBUG][Loop] timerPresent=" .. tostring(timerPresent))
            if not timerPresent then
                state = "NO_INSTANCE"
                print("[Hermod] Geen instance timer - teleporteren naar War Retreat...")
                teleportToWarRetreat()
            else
                if bossRoomStartPos == nil then
                    bossRoomStartPos = API.PlayerCoord()
                    print("[Hermod] Startpositie opgeslagen: " .. bossRoomStartPos.x .. "," .. bossRoomStartPos.y)
                end
                if not hasFood() then
                    bankRun()
                else
                    handleBossRoom()
                end
            end
            API.RandomSleep2(400, 100, 100)
        elseif not inBoss and inRasialCitdal() then
            bossRoomStartPos = nil
            state = "CITADEL"
            -- Klik op de doorway en wacht op interface + bevestig entry
            enterBossRoom()
            local timeout = os.time() + 12
            while not inBossRoom() and os.time() < timeout do
                API.RandomSleep2(800, 150, 150)
                confirmBossEntry()
            end
        elseif not inBoss and inWarArea() then
            state = "PORTAL_ZOEKEN"
            enterRasialPortal()
            API.RandomSleep2(1200, 300, 300)
        else
            state = "IDLE"
            print("[DEBUG][Loop] Geen bekende locatie - IDLE")
        end
    end
end
