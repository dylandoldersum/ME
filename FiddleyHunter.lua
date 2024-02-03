API = require('api')
UTILS = require("utils")
COLORS = require("colors")

local pickedWhirl = {};
local whirlieNPCS = {28726, 28720, 28722, 28723, 28724, 28725, 28719}
local roseStages = {122504, 122505, 122506, 122507 }
local threatScarab = 28671
local unhandledFrito = 28665;
local flowerBasket = false;
startTime, afk = os.time(), os.time()

local Cselect =
    API.ScriptDialogWindow2(
    "Whirligig",
    {"Catch Whirligigs", "Cultivate rose"},
    "Start",
    "Close"
).Name



if Cselect == "Catch Whirligigs" then
    local Ccheck = API.ScriptDialogWindow2("Flower basket?", {"Yes", "No"}, "Start", "Close").Name
    if Ccheck == "Yes" then
        flowerBasket = true
    end
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((5 * 60) * 0.6, (5 * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

function findNpcOrObject(npcid, distance, objType)
    local distance = distance or 20
    return #API.GetAllObjArrayInteract({ npcid }, distance, objType) > 0
end

function run_to_tile(x, y, z)
    local tile = WPOINT.new(x, y, z)
    API.DoAction_Tile(tile)
    while API.Read_LoopyLoop() and API.Math_DistanceW(API.PlayerCoord(), tile) > 5 do
        API.RandomSleep2(100, 200, 200)
    end
end

function randomWalk()
    local randomW = math.random(1,40)
    if randomW == 5 then
        print ("Random walking")
        run_to_tile(3378+math.random(1, 4), 3207+math.random(1, 8), 0)
    end
end

function fillRoses()
    print ("Basket quantity: ", getBasketQuantity())
    if getBasketQuantity() <= 5 then
        print ("Time to refill basket")
        UTILS.randomSleep(5000)
        print ("5 secs sleep")
        API.DoAction_Object1(0x29,240,{ 122495 },50)
        UTILS.randomSleep(1500)
        API.WaitUntilMovingEnds()
        print("Roses refilled")
    end
end

function cultivateRose()
    if API.GetPlayerAnimation_(API.GetLocalPlayerName()) == -1 then
        print ("Not doing anything..")
        for i in ipairs(roseStages) do
            if findNpcOrObject(roseStages[i], 3, 0) then
                print("Found current rose stage!", roseStages[i])
                API.DoAction_Object1(0x29,0,{ roseStages[i] },50)
            end
        end
        checkForThreats()
    end
end

function checkForThreats()
    print("Looking for threats")
    if findNpcOrObject(threatScarab, 10, 1) then
        print("Pasty Scarab found! Shoo away")
        API.DoAction_NPC(0x29,1488,{ threatScarab },50)
        UTILS.randomSleep(1000)
        print("Threats clear")
    end
    UTILS.randomSleep(1500)
end

function getFritoState()
    return (API.VB_FindPSett(10339).state)
end

function getAttackState()
    local whirlStackVB = API.VB_FindPSett(10338).state 
    return whirlStackVB
end

function getBasketQuantity()
    local flowerBasketVB = API.VB_FindPSett(10330).state
    local flowerQuant64 = flowerBasketVB >> 18 & 0xfff
    return flowerQuant64 / 64
end

function handleFrito()
    if getFritoState() > 1 then
        catchWhirls()
    else
        API.DoAction_NPC(0x29,1488,{ unhandledFrito },50)
        UTILS.randomSleep(1000);
        print("Frito is now ur pet.")
    end  
end

function catchWhirls()
    for i in ipairs(whirlieNPCS) do
        if API.Buffbar_GetIDstatus(52770).conv_text >=5 then
            UTILS.randomSleep(2000);
            print("Idle for 2 seconds, cuz stack is above 5")
        end
        API.DoAction_NPC(0x29,1488,{ whirlieNPCS[i] }, 50)
        UTILS.randomSleep(1500)
        if flowerBasket then
            fillRoses()
        end
        randomWalk()
    end
end

while API.Read_LoopyLoop() do
    idleCheck()
    if not string.match(Cselect, "Cultivate") then    
        handleFrito()
    else
        cultivateRose()
    end
    API.SetDrawTrackedSkills(true)
end
