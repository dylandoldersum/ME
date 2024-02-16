--[AUTHOR: Fiddle]--
--[V1.0.4]--
-- For red chins start the script near the church at Ooglog --
-- For azure chins start the script at the beginning of the area --

API = require('api')
startTime, afk = os.time(), os.time()


local Ccheck = API.ScriptDialogWindow2("What do you want to hunt?", {"Red chinchompa", "Azure skillchompa"}, "Start", "Close").Name

local shakingBox = 0;
local tileWPoints = {}
local hunterLvl = API.XPLevelTable(API.GetSkillXP("HUNTER"));

if Ccheck == "Red chinchompa" then
    shakingBox = 19190
    tileWPoints = {
        WPOINT.new(2504, 2898, 0), --1
        WPOINT.new(2504, 2900, 0), --2
        WPOINT.new(2506, 2898, 0), --3 
        WPOINT.new(2506, 2900, 0) --4
    }
    if hunterLvl >= 80 then
        table.insert(tileWPoints, WPOINT.new(2505, 2899, 0))
        print("Hunter lvl is 80+ so 5 boxes")
    end
end
if Ccheck == "Azure skillchompa" then
    shakingBox = 91232
    tileWPoints = {
        WPOINT.new(2728, 3857, 0),
        WPOINT.new(2728, 3859, 0),
        WPOINT.new(2730, 3857, 0),
        WPOINT.new(2730, 3859, 0)
    }
    if hunterLvl >= 80 then
        table.insert(tileWPoints,WPOINT.new(2729, 3858, 0))
        print("Hunter lvl is 80+ so 5 boxes")
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

local function placeBox(tile)
    API.RandomSleep2(600, 300, 300)
    if not API.CheckTileforObjects1(tile) then
        print ("PLACING BOX")
        API.DoAction_Inventory3("Box trap",0,1,API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 300, 300)
        API.WaitUntilMovingandAnimEnds()
    end
end

local function initBox(tile)
    API.DoAction_Tile(tile)
    API.RandomSleep2(600, 300, 300)
    API.WaitUntilMovingandAnimEnds()
    placeBox(tile)
end

local function takeBox(objId, tile)
    print (tostring(tile))
    API.DoAction_Tile(tile)
    API.RandomSleep2(600, 300, 300)
    API.WaitUntilMovingandAnimEnds()
    API.DoAction_Object2(0x29,0,{ objId },50, tile)
    API.RandomSleep2(600, 300, 300)
    API.WaitUntilMovingandAnimEnds()
    placeBox(tile)
end

local function rebuildBox(objId, tile)
    API.DoAction_Object2(0x29,0,{ objId },50, tile)
    API.RandomSleep2(600, 300, 300)
    API.WaitUntilMovingandAnimEnds()
end

local function scanForBoxes()
    local objs = API.ReadAllObjectsArray(true, 3)
    for k, v in pairs(tileWPoints) do
        if API.CheckTileforObjects2(v, shakingBox, 1) then
            print("Shaking box found")
            takeBox(shakingBox, v)
        elseif not API.CheckTileforObjects1(v) then -- CHECKS IF OBJECT ON TILE
            print ("NOTHING ON THIS TILE SO I CAN PLACE A BOX ON", k)
            initBox(v)
        elseif API.CheckTileforObjects2(v, 19192, 1) then
            print("Broken box found")
            rebuildBox(19192, v)
        end
        for _, obj in ipairs(objs) do --IF GROUND ITEM FOUND TAKE IT AND PLACE NEW BOX -> OBJ VERDWIJNT -> ITEM KOMT
            if obj.Id == 10008 then
                print(obj.Id, "found")
                API.DoAction_G_Items1(0x29, {obj.Id}, 20)
                API.RandomSleep2(600, 300, 300)
                API.WaitUntilMovingandAnimEnds()
                placeBox(v)
            end
        end
    end
end

while API.Read_LoopyLoop() do
    idleCheck()
    scanForBoxes()
    API.SetDrawTrackedSkills(true)
end
