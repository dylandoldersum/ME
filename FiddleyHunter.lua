API = require('api')
UTILS = require("utils")
COLORS = require("colors")

local pickedWhirl = {};
local whirlieNPCS = {28726, 28720, 28722, 28723, 28724, 28725, 28719}
local flowerStages = {  }
local basketId = 0
local threatScarab = 28671
local unhandledFrito = 28665;
local flowerBasket = false;
startTime, afk = os.time(), os.time()

local Cselect =
    API.ScriptDialogWindow2(
    "Whirligig",
    {"Catch Whirligigs", "Cultivate Flowers"},
    "Start",
    "Close"
).Name

local function getAttackState()
    local whirlStackVB = API.VB_FindPSett(10338).state 
    local whirlStack = whirlStackVB >> 20
    return whirlStack
end

local function getBasketQuantity()
    local flowerBasketVB = API.VB_FindPSett(10330).state
    local flowerQuant64 = flowerBasketVB >> 18 & 0xfff
    return flowerQuant64 / 64
end

if Cselect == "Catch Whirligigs" then
    local Ccheck = API.ScriptDialogWindow2("Flower basket?", {"Roses", "Iris", "Hydrangea", "None"}, "Start", "Close").Name
    if Ccheck == "Roses" then
        flowerBasket = true
        basketId = 122495
    end
    if Ccheck == "Iris" then
        flowerBasket = true
        basketId = 122496
    end
    if Ccheck == "Hydrangea" then
        flowerBasket = true
        basketId = 122497
    end
end

if Cselect == "Cultivate Flowers" then
    local pickedFlower = API.ScriptDialogWindow2("Flower type", {"Roses", "Iris", "Hydrangea"}, "Start", "Close").Name
    if pickedFlower == "Roses" then
        flowerStages = {122504, 122505, 122506, 122507 }
    end
    if pickedFlower == "Iris" then
        flowerStages = {122508, 122509, 122510, 122511 }
    end
    if pickedFlower == "Hydrangea" then
        flowerStages = {122512, 122513, 122514, 122515 }
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

local function findNpcOrObject(npcid, distance, objType)
    local distance = distance or 20
    return #API.GetAllObjArrayInteract({ npcid }, distance, objType) > 0
end

local function run_to_tile(x, y, z)
    local tile = WPOINT.new(x, y, z)
    API.DoAction_Tile(tile)
    while API.Read_LoopyLoop() and API.Math_DistanceW(API.PlayerCoord(), tile) > 5 do
        API.RandomSleep2(100, 200, 200)
    end
end

local function randomWalk()
    local randomW = math.random(1,40)
    if randomW == 5 then
        print ("Random walking")
        run_to_tile(3378+math.random(1, 4), 3207+math.random(1, 8), 0)
    end
end


local function fillRoses()
    print ("Basket quantity: ", getBasketQuantity())
    if getBasketQuantity() <= 9 then
        print ("Time to refill basket")
        UTILS.randomSleep(5000)
        print ("5 secs sleep")
        API.DoAction_Object1(0x29,240,{ basketId },50)
        UTILS.randomSleep(1500)
        API.WaitUntilMovingEnds()
        print("Roses refilled")
    end
end

local function checkForThreats()
    print("Looking for threats")
    if findNpcOrObject(7620, 10, 4) then
        print("Nutritous gas inbound.")
        API.DoAction_NPC(0x29,1488,{ 7620 },50)
        UTILS.randomSleep(1000)
        print("Threats clear")
    end
    if findNpcOrObject(threatScarab, 10, 1) then
        print("Pasty Scarab found! Shoo away")
        API.DoAction_NPC(0x29,1488,{ threatScarab },50)
        UTILS.randomSleep(1000)
        print("Threats clear")
    end
    UTILS.randomSleep(1500)
end

local function cultivateFlowers()
    print ("Check if still busy..")
    if not API.CheckAnim(100) then
        for i in ipairs(flowerStages) do
            if findNpcOrObject(flowerStages[i], 3, 0) then
                print("Found current rose stage!", flowerStages[i])
                API.DoAction_Object1(0x29,0,{ flowerStages[i] },50)
            end
        end
    end
    checkForThreats()
end

local function getFritoState()
    return (API.VB_FindPSett(10339).state)
end



local function catchWhirls()
    for i in ipairs(whirlieNPCS) do
        if API.Buffbar_GetIDstatus(52770).conv_text >=5 then
            UTILS.randomSleep(2000);
            print("Idle for 2 seconds, cuz stack is above 5")
        end

        API.DoAction_NPC(0x29,1488,{ whirlieNPCS[i] }, 50)
        UTILS.randomSleep(1000)
        if flowerBasket then
            if API.InvItemcount_1(52808) > 0 then
                fillRoses()
            else
                print("No more flowers")
                break
            end
        end
        randomWalk()
    end
end

local function handleFrito()
    if getFritoState() > 1 then
        catchWhirls()
    else
        API.DoAction_NPC(0x29,1488,{ unhandledFrito },50)
        UTILS.randomSleep(1000);
        print("Frito is now ur pet.")
    end  
end



while API.Read_LoopyLoop() do
    idleCheck()
    if flowerBasket and API.InvItemcount_1(52808) < 1 then
        print("No more flowers")
        break
    end
    if not string.match(Cselect, "Cultivate") then    
        handleFrito()
    else
        cultivateFlowers()
    end
    API.SetDrawTrackedSkills(true)
end
