API = require('api')
UTILS = require("utils")
COLORS = require("colors")

local hasFollower = false;
local plainWhirl = {28726, 28720, 28722, 28723, 28724, 28725, 28719}
local unhandledFrito = 28665;
local handledFrito = 28666;

local startXp = API.GetSkillXP("HUNTER")
local startTime, afk = os.time(), os.time()

-- Rounds a number to the nearest integer or to a specified number of decimal places.
local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

function formatNumber(num)
    if num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end

-- Format script elapsed time to [hh:mm:ss]
local function formatElapsedTime(startTime)
    local currentTime = os.time()
    local elapsedTime = currentTime - startTime
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("[%02d:%02d:%02d]", hours, minutes, seconds)
end

local function calcProgressPercentage(skill, currentExp)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    if currentLevel == 120 then return 100 end
    local nextLevelExp = XPForLevel(currentLevel + 1)
    local currentLevelExp = XPForLevel(currentLevel)
    local progressPercentage = (currentExp - currentLevelExp) / (nextLevelExp - currentLevelExp) * 100
    return math.floor(progressPercentage)
end

local function printProgressReport(final)
    local skill = "HUNTER"
    local currentXp = API.GetSkillXP(skill)
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp);
    local xpPH = round((diffXp * 60) / elapsedMinutes);
    local time = formatElapsedTime(startTime)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    IGP.string_value = time ..
    " | " ..
    string.lower(skill):gsub("^%l", string.upper) ..
    ": " .. currentLevel .. " | XP/H: " .. formatNumber(xpPH) .. " | XP: " .. formatNumber(diffXp)
end

local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(5, 5, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(colorsRGB.RGB("burlywood"));
    IGP.string_value = "WHIRLIGIG CATCHING"
end

function drawGUI()
    API.DrawProgressBar(IGP)
end

setupGUI()

function findNpc(npcid, distance)
    local distance = distance or 20
    return #API.GetAllObjArrayInteract({ npcid }, distance, 1) > 0
end

function handleFrito()
    if not findNpc(handledFrito, 20) then
        print("I have no frito, click handle frito.")
        API.DoAction_NPC(0x29,1488,{ unhandledFrito },50)
        UTILS.randomSleep(1000);
        hasFollower = true;
        print("Frito is now ur pet.")
    else
        hasFollower = true;
        print("Already has frito.")
        UTILS.randomSleep(1000);
    end
end

while API.Read_LoopyLoop() do
    for i in ipairs(plainWhirl) do
        if hasFollower then
            API.DoAction_NPC(0x29,1488,{ plainWhirl[i] }, 50)
            UTILS.randomSleep(1000);
        else
            handleFrito()
        end
        drawGUI()
        printProgressReport()
    end
end
