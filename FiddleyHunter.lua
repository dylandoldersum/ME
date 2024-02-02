API = require('api')
UTILS = require("utils")
COLORS = require("colors")

local pickedWhirl = {};
local whirlieNPCS = {};
local roseStages = {122504, 122505, 122506, 122507 }
local threatScarab = 28671
local Cselect =
    API.ScriptDialogWindow2(
    "Whirligig",
    {"Plain", "Cultivate rose"},
    "Start",
    "Close"
).Name

if Cselect == "Plain" then
    whirlieNPCS = {28726, 28720, 28722, 28723, 28724, 28725, 28719}
end
if Cselect == "Dazzling" then
    whirlieNPCS = {28726, 28720, 28722, 28723, 28724, 28725, 28719}
end

local hasFollower = false;
local unhandledFrito = 28665;
local handledFrito = 28666;

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
    if math.random(1, 40) == 5 then
        print ("Random walking")
        run_to_tile(3378+math.random(1, 4), 3207+math.random(1, 8), 0)
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

function handleFrito()
    if not findNpcOrObject(handledFrito, 20, 1) then
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
    if not string.match(Cselect, "Cultivate") then
        print("Starting croc")
        for i in ipairs(whirlieNPCS) do
            if hasFollower then
                if API.Buffbar_GetIDstatus(52770).conv_text >= 3 then
                    UTILS.randomSleep(2000);
                    print("Idle for 2 seconds, cuz stack is above 5")
                end
                randomWalk()
                API.DoAction_NPC(0x29,1488,{ whirlieNPCS[i] }, 50)
                UTILS.randomSleep(1000)
            else
                handleFrito()
            end
        end
    else
        cultivateRose()
    end
    API.SetDrawTrackedSkills(true)
end
