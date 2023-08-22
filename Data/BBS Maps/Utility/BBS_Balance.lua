 ------------------------------------------------------------------------------
--	FILE:	 BBS_Balance.lua 2.2.3
--	AUTHOR:  D. / Jack The Narrator, 57Fan
--	PURPOSE: Rebalance the map spawn post placement 
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
ExposedMembers.LuaEvents = LuaEvents

include "MapEnums"
include "SupportFunctions"
include "BBS_AssignStartingPlots"
include( "MapUtilities" );

local world_age = 2;
local high_roll = 0.15;
local bHighRoll = false;

local m_BBGId:string = "bdffd1bc-49e5-4dd6-81b2-aab1eb55563f";
local m_BBGEnabled:boolean = false;

local 	g_negative_bias = {}
local 	g_custom_bias = {}



-----------------------------------------------------------------------------------------------------------------------------------
-- Coastal score constants
-- Unless specified, Ring 1 has the same value as Ring 2
--
local CRABS_R3 = 10;
local CRABS_R2 = 30;
local FISH_R3 = 40;
local FISH_R2 = 70;
local PEARLS_R3 = 40;
local PEARLS_R2 = 70;
local AMBER_R3 = 30;
local AMBER_R2 = 55;
local WHALES_R3 = 50;
local WHALES_R2 = 80;
local TURTLES_R3 = 95; -- always includes a reef
local TURTLES_R2 = 120;
local FISH_REEF_R3 = 80;
local FISH_REEF_R2 = 110;
local REEF_R3 = 10; -- Reef alone (no resource)
local REEF_R2 = 20;

local REEF_CAMPUS = 20; -- in case a reef tile (naked, or with fish/turtel) is next to a campusable tile, we add extra
local HARBOR_ADJ = 30; -- if a resource is next to harbor tile, per resource

-- This will be the minimum score that each coastal spawn should reach after balancing
local BASE_COASTAL_SCORE = 210;

-- When balancing coastal spawns, we will add/remove resources to each players in order to reach the desired score
-- If the player's score is within the margin, nothing will be done
local COASTAL_MARGIN = 30;


-- Coastal codes (not score, juste making difference between each)

local COASTAL_START_STANDARD = 10;
local COASTAL_START_SMALL_FJORD = 20;
local COASTAL_START_LONG_FJORD = 30;
local COASTAL_START_PENINSULA = 40;

local LAKE_START_SMALL = 100; -- will simply clean the harbour spot
local COASTAL_START_SMALL = 110; -- will simply clean the harbour spot

local LAKE_START_BIG = 200; -- will provide fishes
local LAKE_START_WITH_COAST = 210; -- unlikely: full lake spawn, but still has coast on the spawn


-- Coastal penalties:

local LONG_FJORD_PENALTY = 50;
local BIG_LAKE_PENALTY = 50;
local SMALL_FJORD_PENALTY = 30;
local PENINSULA_PENALTY = -50;

local COASTAL_CIVS = {"LEADER_VICTORIA", "LEADER_HOJO", "LEADER_DIDO"};  -- Use a IsCoastalCiv ? Like IsTundraCiv 
local COASTAL_LEADERS = {"LEADER_VICTORIA", "LEADER_HOJO", "LEADER_DIDO"};


------ New Vars ------

local spawnTwoTwo = 0.15
local spawnHills = 0.5

-------------

-- Returns:
-- -1 = no
-- 0  = Fallback (you will need to remove the resource)
-- 1  = Yes

function isHillAble (x, y)

   if x < 0 or y < 0 then
      __Debug("Hillable: invalid index", x, y)
      return -1;
   end

   local xIndex = x + 1;
   local yIndex = y + 1;
   
   local feature = mapFeatureCode[xIndex][yIndex];
   local terrain = mapTerrainCode[xIndex][yIndex];
   local resource = mapResourceCode[xIndex][yIndex];
   
   -- anything that is not: forest or rainforest
   if (feature == 0 or feature > 4) then
      return -1;
   end
   
   -- We only look at plains/grassland
   if terrain >= 6 then
      return -1;
   end
   
   -- Mountain
   if terrain % 3 == 2 then
      return -1;
   end
   
   -- Hill
   if terrain % 3 == 1 then
      __Debug("Is already a hill ...", x, y);
      return -1;
   end
   
   -- Rice, wheat, cattle and Maize: will need to remove if we wanna change
   -- including deer: want to prevent 2-3 possible
   if (resource == 1 or resource == 4 or resource == 6 or resource == 9 or resource == 52) then
      return 0;
   end
   
   -- resources only found on flat land
   if (resource == 10 or resource == 12 or resource == 18 or resource == 20 or resource == 22 or resource == 24 or resource == 27 or resource == 28
        or resource == 30 or resource == 31 or resource == 42 or resource == 44 or resource == 45 or resource == 53) then
      return -1;
   end
   
   -- plain with gypsum or ivory, can't cuz would great 2-3 tile
   if (terrain == 3 and (resource == 17 or resource == 19)) then
      return -1;
   end
   
   return 1;
   
end

function twoTwoScore(x, y)

   local xIndex = x + 1;
   local yIndex = y + 1;
   
   local terrain = mapTerrainCode[xIndex][yIndex];
   local resource = mapResourceCode[xIndex][yIndex];
   
   local food = mapFoodYield[xIndex][yIndex];
   local prod = mapProdYield[xIndex][yIndex];
   
  
   if resource == 41 then
      prod = prod - 2;
   elseif (resource == 42 or resource == 44) then
      prod = prod - 1;
      food = food - 1;
   elseif resource == 45 then
      prod = prod - 3;
   elseif resource == 46 then
      prod = prod - 2; 
   end
   
   if (terrain >= 15) then -- water
      return 0;
   
   elseif (food < 2 or prod < 2) then -- not 2-2
      return 1;
      
   elseif (food == 2 and prod == 2) then -- 2-2
      return 2;
   
   else -- better than 2-2
      return 3;
   end
   
   return -1;

end

-- Will transform a functionning tile to hill
function toHill (x, y, cleanResource, cleanFeature)
   if x < 0 or y < 0 then
      __Debug("toHill: invalid index", x, y)
      return -1;
   end
   
   __Debug("Transforming this tile to hill:", x, y);

   local xIndex = x + 1;
   local yIndex = y + 1;
   local plot = Map.GetPlot(x, y)
   local terrain = mapTerrainCode[xIndex][yIndex];
   
   local newResource = -2;
   local newFeature = -2;
   
   if cleanResource then
      newResource = -1;
      --ResourceBuilder.SetResourceType(plot, -1);
      --mapResourceCode[xIndex][yIndex] = -1;
   end
   
   if cleanFeature then
      newFeature = -1;
      --TerrainBuilder.SetFeatureType(plot, -1);
      --mapFeatureCode[xIndex][yIndex] = -1;
   end
   
   terraformBBS(x, y, terrain + 1, newResource, newFeature);
   
   --[[
   
   TerrainBuilder.SetTerrainType(plot, terrain + 1);
   mapTerrainCode[xIndex][yIndex] = mapTerrainCode[xIndex][yIndex] + 1;
   
   local feature = plot:GetFeatureType();
   local terrain = plot:GetTerrainType();
   local resource = plot:GetResourceType();
   --local isCoastal = false;
   local food = plot:GetYield(g_YIELD_FOOD);
   local prod = plot:GetYield(g_YIELD_PRODUCTION);
   local gold = plot:GetYield(g_YIELD_GOLD);
   local science = plot:GetYield(g_YIELD_SCIENCE);
   local culture = plot:GetYield(g_YIELD_CULTURE);
   local faith = plot:GetYield(g_YIELD_FAITH);
   
   
   mapTerrainCode[xIndex][yIndex] = terrain;
   mapResourceCode[xIndex][yIndex] = resource;
   mapFeatureCode[xIndex][yIndex] = feature;

   --- strategics are not visible at start, but the game would count their stat anyway
   if (resource == 40 or resource == 43) then
      science = science - 1;
   elseif resource == 41 then
      prod = prod - 2;
   elseif (resource == 42 or resource == 44) then
      prod = prod - 1;
      food = food - 1;
   elseif resource == 45 then
      prod = prod - 3;
   elseif resource == 46 then
      prod = prod - 2; 
   end
   
   mapFoodYield[xIndex][yIndex] = food;
   mapProdYield[xIndex][yIndex] = prod;
   mapGoldYield[xIndex][yIndex] = gold;
   mapScienceYield[xIndex][yIndex] = science;
   mapCultureYield[xIndex][yIndex] = culture;
   mapFaithYield[xIndex][yIndex] = faith;
   --]]
   
   local twoTwo = twoTwoScore(x, y);
   
   --mapTwoTwo[xIndex][yIndex] = twoTwo;
   
   if (twoTwo >= 2) then
      return 2;
   end
   
   return 1;

end

function giveHills(okToHill, okToHillCount, okToHillBkp, okToHillBkpCount, hillDiff)

   local okToHilIndex = 0;
   local okToHilBkpIndex = 0;
   
   local givenTwoTwo = 0;
   

   for i = 1, hillDiff do
      if okToHilIndex < okToHillCount then
         okToHilIndex = okToHilIndex + 1;
         
         local returnValue = toHill(okToHill[okToHilIndex][1], okToHill[okToHilIndex][2], false, false);
         
         if (returnValue >= 2) then
            __Debug("improved true tile, now a TWO TWO", okToHill[okToHilIndex][1], okToHill[okToHilIndex][2]);
            givenTwoTwo = givenTwoTwo + 1;
         else
            __Debug("improved true tile", okToHill[okToHilIndex][1], okToHill[okToHilIndex][2]);
         end

      elseif okToHilBkpIndex < okToHillBkpCount then
         okToHilBkpIndex = okToHilBkpIndex + 1;
         
         toHill(okToHillBkp[okToHilBkpIndex][1], okToHillBkp[okToHilBkpIndex][2], true, true);
         
         __Debug("improved backup tile", okToHillBkp[okToHilBkpIndex][1], okToHillBkp[okToHilBkpIndex][2]);
      else
         __Debug("Warning, not enough tiles to improve !!");
      end
   end
   
   return givenTwoTwo;

end

function changePlot(x, y, targetTerrain, targetResource, targetFeature)
   
   if (x < 0 or y < 0) then
      return -1;
   end
   
   local plot = Map.GetPlot(x, y);
   
   if plot == nil then
      return -1;
   end
   
   if (targetTerrain >= 0) then
      TerrainBuilder.SetTerrainType(plot, targetTerrain);
   end
   
   if (targetResource >= -1) then
      ResourceBuilder.SetResourceType(plot, targetResource, 1);
   end
   
   if (targetFeature >= -1) then
      TerrainBuilder.SetFeatureType(plot, targetFeature, 1);
   end
   
   return 0;
   
end

function toTwoTwo(x, y, canStone, canSheep, canBanana)
   local xIndex = x + 1;
   local yIndex = y + 1;

--   local plot = Map.GetPlot(x, y);
   local terrain = mapTerrainCode[xIndex][yIndex];
   local resource = mapResourceCode[xIndex][yIndex];
   local feature = mapFeatureCode[xIndex][yIndex];
   
   local clearResource = false;
   local clearFeature = false;
   
   --- we'll have clear the resource if it does not belong to the list
   if (resource ~= 0 and resource ~= 4 and resource ~= 7 and resource ~= 8 and resource ~= 11
          and resource ~= 14 and resource ~= 15 and resource ~= 16 and resource ~= 4 and resource ~= 19 and resource ~= 25
           and resource ~= 27 and resource ~= 33) then
      cleanResource = true;
   end
   
   if (feature ~= 2 and feature ~= 3) then
      cleanFeature = true;
   end
   
   local rng = TerrainBuilder.GetRandomNumber(100,"test")/100
   local canRainforest = true;
   
   if MapConfiguration.GetValue("MAP_SCRIPT") ~= "Tilted_Axis.lua" then
      if y > mapYSize * 0.75 or y < mapYSize * 0.25 then -- too close to pole for rainforest
         canRainforest = false;
      end
   end
   
   -- if -2, means don't touch the resource
   local targetResource = -2;
   local targetTerrain = -2;
   local targetFeature = -2;
   
   if (terrain == 1) then -- grassland Hill, only a few cases here
   
      if (resource == 15 or resource == 16 or resource == 25 or resource == 27) then -- resources that can be with forest
         targetFeature = 3;
         __Debug("Adding forest to tile", x, y);
         
      else -- resource that can't be turned to two-two
         if (canStone) then
            if (rng >= 0.5) then -- add stone
               targetResource = 8;
               targetFeature = -1;
               
               __Debug("Turning to 2-2 hill stone", x, y);
            else -- add forest
               targetFeature = 3;
               targetResource = -1;
               __Debug("Turning to 2-2 hill forest", x, y);
               
            end
         else -- forest only
            targetFeature = 3;
            targetResource = -1;
            __Debug("Turning to 2-2 hill forest", x, y);
            
         end
      end
      
   elseif (terrain == 0) then --grassland
   
      targetResource = 4;
      targetFeature = 3;
      __Debug("Turning to 2-2 forest - deer", x, y);
      
   elseif (terrain == 4) then --plain hill
      if canRainforest then
         if (resource == 12 or resource == 14 or resource == 15 or resource == 19 or resource == 25) then -- resources that can be with rainforest
            targetFeature = 2;
         else
            if canSheep then
               if (rng >= 0.5) then -- add sheep
                  targetResource = 7;
                  targetFeature = -1;
                  __Debug("Turning to 2-2 plain hill sheep", x, y);
                  
               else --rainforest
                  targetResource = -1;
                  targetFeature = 2;
                  __Debug("Turning to 2-2 plain hill rainforest", x, y);
               end
            else
               --rainforest
               targetResource = -1;
               targetFeature = 2;
               __Debug("Turning to 2-2 plain hill rainforest", x, y);
            end
         end
         
      else -- close to pole, can only sheep
         if canSheep then
            targetResource = 7;
            targetFeature = -1;
            __Debug("Turning to 2-2 plain hill sheep", x, y);
         else
            __Debug("I can't either sheep nor rainforest, error", x, y);
            return -1;
         end
      end
   elseif (terrain == 3) then -- flat plain
      -- We need to turn the tile to hill to provide a two two
      if canRainforest then
         if (resource == 12 or resource == 14 or resource == 15 or resource == 19 or resource == 25) then -- resources that can be with rainforest
            targetFeature = 2;
            targetTerrain = 4;
         else
            if canSheep then
               if (rng >= 0.5) then -- add sheep
                  targetResource = 7;
                  targetFeature = -1;
                  targetTerrain = 4;
                  __Debug("Turning to 2-2 plain hill sheep", x, y);
                  
               else --rainforest
                  targetResource = -1;
                  targetFeature = 2;
                  targetTerrain = 4;
                  __Debug("Turning to 2-2 plain hill rainforest", x, y);
               end
            else
               --rainforest
               targetResource = -1;
               targetFeature = 2;
               targetTerrain = 4;
               __Debug("Turning to 2-2 plain hill rainforest", x, y);
            end
         end
         
      else -- close to pole, can only sheep
         if canSheep then
            targetResource = 7;
            targetFeature = -1;
            targetTerrain = 4;
            __Debug("Turning to 2-2 plain hill sheep", x, y);
         else
            __Debug("I can't either sheep nor rainforest, error", x, y);
            return -1;
         end
      end
   end
   
   --return changePlot(x, y, targetTerrain, targetResource, targetFeature);
   return terraformBBS(x, y, targetTerrain, targetResource, targetFeature);
   

end

function giveTwoTwos(okToHill, okToHillCount, okToHillBkp, okToHillBkpCount, missingTwoTwo)

   local okToHilIndex = 0;
   local okToHilBkpIndex = 0;
   
   local i = 0;
   
   while i < missingTwoTwo do
   
       if okToHilIndex < okToHillCount then
         okToHilIndex = okToHilIndex + 1;
         
         local x = okToHill[okToHilIndex][1];
         local y = okToHill[okToHilIndex][2];
         
         local xIndex = x + 1;
         local yIndex = y + 1;
         
         
         if (mapTwoTwo[xIndex][yIndex] < 2) then -- not a two two
            toTwoTwo(x, y);
            __Debug("TWO TWO improved tile", x, y);
            i = i + 1;
         end

      elseif okToHilBkpIndex < okToHillBkpCount then
         okToHilBkpIndex = okToHilBkpIndex + 1;
         i = i + 1;
         
         local x = okToHillBkp[okToHilBkpIndex][1];
         local y = okToHillBkp[okToHilBkpIndex][2];
         
         local xIndex = x + 1;
         local yIndex = y + 1;

         toTwoTwo(x, y);
         __Debug("TWO TWO improved tile", x, y);
      else
         __Debug("Two two: warning, not enough tiles to improve !!");
         return;
      end
   end

end

-----------------------------------------------------------------------------------------------------------------------------------

function BBS_Script()
	print ("Initialization Balancing Spawn", os.date("%c"))
   print ("test autre scrip", CS_CS_MIN_DISTANCE);
	
	local currentTurn = Game.GetCurrentGameTurn();
	eContinents	= {};
	
	

-- =============================================================================
-- BBG Check
-- =============================================================================

	-- Mod compatibility
	--if Modding.IsModActive(m_BBGId) then
	m_BBGEnabled = true;
	--end

	g_negative_bias = {}
	g_custom_bias = {}
	local info_query = "SELECT * from StartBiasNegatives";
	local info_results = DB.Query(info_query);
	for k , v in pairs(info_results) do
		local tmp = { CivilizationType = v.CivilizationType, TerrainType = v.TerrainType, FeatureType = v.FeatureType, Tier = v.Tier, Extra = v.Extra}
		if tmp.CivilizationType ~= nil then
			table.insert(g_negative_bias, tmp)
		end
	end
	
	
	
	local info_query = "SELECT * from StartBiasCustom";
	local info_results = DB.Query(info_query);
	for k , v in pairs(info_results) do
		local tmp = { CivilizationType = v.CivilizationType, CustomPlacement = v.CustomPlacement}
		print("g_custom_bias",v.CivilizationType,v.CustomPlacement)
		if tmp.CivilizationType ~= nil then
			table.insert(g_custom_bias, tmp)
		end
	end


	if currentTurn == GameConfiguration.GetStartTurn() then
		local rng = TerrainBuilder.GetRandomNumber(100,"test")/100
		print ("Init: Map Seed", MapConfiguration.GetValue("RANDOM_SEED"));
		print ("Init: Game Seed", GameConfiguration.GetValue("GAME_SYNC_RANDOM_SEED"));
		print ("Init: Number of Major Civs", PlayerManager.GetAliveMajorsCount());
		print ("Init: Local Player Id", Game.GetLocalPlayer());
		print ("Init: Number of City-States", PlayerManager.GetAliveMinorsCount());
		local mapName = MapConfiguration.GetValue("MAP_SCRIPT")
		print ("Init: Loading "..tostring(mapName).." script");
		local startTemp = MapConfiguration.GetValue("temperature")
		local mapSize = Map.GetMapSize();
		local sea_level = MapConfiguration.GetValue("sea_level")
		local rainfall = MapConfiguration.GetValue("rainfall");
		world_age = MapConfiguration.GetValue("world_age");
      if (world_age == 1) then -- new
         spawnHills = 0.45;
      elseif (world_age == 2) then
         spawnHills = 0.30;
      else
         spawnHills = 0.20;
      end
      
      if (MapConfiguration.GetValue("MAP_SCRIPT") == "Highlands_XP2.lua") then
         if (world_age == 1) then -- new
            spawnHills = 0.7;
         elseif (world_age == 2) then
            spawnHills = 0.45;
         else
            spawnHills = 0.30;
         end
      end

      
		local ridge = MapConfiguration.GetValue("BBSRidge");
		print ("Init: Map Size: ", mapSize, "2 = Small, 5 = Huge");
		print ("Context",GameConfiguration.IsAnyMultiplayer())
		local gridWidth, gridHeight = Map.GetGridSize();
		print ("Init: gridWidth",gridWidth,"gridHeight",gridHeight)
		print ("Init: Climate: ", startTemp, "1 = Hot, 2 = Standard, 3 = Cold");
		local BBS_temp = false;
		if (GameConfiguration.GetValue("BBStemp") ~= nil) then 
			if (GameConfiguration.GetValue("BBStemp") == true) then
				BBS_temp = true;
				print ("Init: BBS Temperature: On");
				else
				BBS_temp = false;
				print ("Init: BBS Temperature: Off")
			end
			else
			BBS_temp = false;
			print ("Init: BBS Temperature: Off")
		end
		print ("Init: Rainfall: ", rainfall, "1 = Dry, 2 = Standard, 3 = Humid");
		print ("Init: World Age: ", world_age, "1 = New, 2 = Standard 3 = Old");
		print ("Init: Ridge: ", ridge, "0 = Standard, 1 = Classic, 2 = Large Open 4 = Flat Earth");
		print ("Init: Sea Level: ", sea_level, "1 = Low Sea Level, 2 = Standard, 3 = High Sea Level");
		print("Init: Strategic Resources:",MapConfiguration.GetValue("BBSStratRes"))
		local resourcesConfig = MapConfiguration.GetValue("resources");
		print ("Init: Resources: ", resourcesConfig, "1 = Sparse, 2 = Standard, 3 = Abundant");
		local startConfig = MapConfiguration.GetValue("start")
		if rng < high_roll then
			print ("Init: Resources: High Roll");
			bHighRoll = true;
		end
		print ("Init: Spawntype: ", startConfig, "1 = Standard, 2 = Balanced, 3 = Legendary");

		local iBalancingOne = 2;
		local iBalancingTwo = 0;
		local iBalancingThree = -1;
		local force_remap = true;
		local majList = {}
		local tempEval = {}
		local minFood = 10;
		local avgFood = 0;
		local maxFood = 0;
		local minProd = 7;
		local avgProd = 0;
		local maxProd = 0;
		local avgHill = 0;
		local dispersion = 0.15; --override later
		local dispersion_2 = 0.075;
		local count = 0;	
		local debug_balancing = false

		if (GameConfiguration.GetValue("DEBUG_BALANCING") ~= nil) then 
			if (GameConfiguration.GetValue("DEBUG_BALANCING") == true) then
				debug_balancing = true
			end
		end
		if (GameConfiguration.GetValue("AutoRemap") ~= nil) then 
			if (GameConfiguration.GetValue("AutoRemap") == true) then
				force_remap = true;
				print ("Init: Forced Remap: On");
				else
				force_remap = false;
			end
			else
			force_remap = false;
		end
		-- iBalancing are the legacy sliders now set in place
		if resourcesConfig ~= nil then
			if (resourcesConfig == 1 or resourcesConfig == 2) then
				iBalancingTwo = math.min (resourcesConfig - 2,0);
				minFood = minFood + resourcesConfig;
				elseif (resourcesConfig == 3) then
				iBalancingTwo = 1;
				minFood = minFood + 4;	
				minProd = minProd + 4;
				else
				minFood = 9;
			end
		end
		if (startConfig == 3) then
			iBalancingTwo = iBalancingTwo + 3;
		end


		
		--
		--if (GameConfiguration.GetValue("BalancingTypeThree") and GameConfiguration.GetValue("BalancingTypeThree") ~= nil) then 
		--	iBalancingThree = GameConfiguration.GetValue("BalancingTypeThree");
		--end
		iBalancingThree = 1; -- Always tries to reallocate to better spawn if possible and apply limited terraforming if needed
		
		--if (GameConfiguration.GetValue("BalancingTypeFour") and GameConfiguration.GetValue("BalancingTypeFour") ~= nil) then 
		--	iBalancingFour = GameConfiguration.GetValue("BalancingTypeFour");
		--end
		iBalancingFour = 0;


		print ("Init: Global Parameters: Natural Wonder Buffer:", GlobalParameters.START_DISTANCE_MAJOR_NATURAL_WONDER)
		print ("Init: Global Parameters: City-State Buffer:", GlobalParameters.START_DISTANCE_MINOR_MAJOR_CIVILIZATION)
		print ("Init: Global Parameters: Major Civs Buffer:", GlobalParameters.START_DISTANCE_MAJOR_CIVILIZATION - GlobalParameters.START_DISTANCE_RANGE_MAJOR)

		-------------------------------------------------------------------------------------
		-- Settings: Importing BBS Settings
		-------------------------------------------------------------------------------------
		if (iBalancingOne == 1) then
			dispersion = 0.33;
			elseif (iBalancingOne == 2) then
			dispersion = 0.25;
			elseif (iBalancingOne == 3) then
			dispersion = 0.10;
		end

		dispersion = 0.15;

		-------------------------------------------------------------------------------------
		-- Settings: Importing Map Variables
		-------------------------------------------------------------------------------------

		-- Firaxis Defaults from SetDefaultAssignedStartingPlots.lua
		local bTerraformingSpawn = true;
		if GameConfiguration.GetValue("SpawnTerraforming") ~= nil then
			bTerraformingSpawn = GameConfiguration.GetValue("SpawnTerraforming");
		end
		__Debug("SpawnTerraforming",bTerraformingSpawn)
   		--Find Default Number
    		local MapSizeTypes = {};
    		for row in GameInfo.Maps() do
       			MapSizeTypes[row.RowId] = row.DefaultPlayers;
    		end
    		local sizekey = Map.GetMapSize() + 1;
    		local iDefaultNumberPlayers = MapSizeTypes[sizekey] or 8;
    		iDefaultNumberMajor = iDefaultNumberPlayers ;
    		iDefaultNumberMinor = math.floor(iDefaultNumberPlayers * 1.5);
		

		-------------------------------------------------------------------------------------
		-- Settings: Importing Player Variables
		-------------------------------------------------------------------------------------
		local iNumMinCivs = 0;
		tempMajorList = PlayerManager.GetAliveMajorIDs();


		-- Creating Player Table
		local major_table = {}
		local minor_table = {}
		local major_count = 0
		local minor_count = 0
		for i = 0, 60 do
			local tmp_civ = Players[i]
			if Players[i] ~= nil then
				if tmp_civ:IsMajor() == true and tmp_civ:IsAlive() == true then
					major_count = major_count + 1
					major_table[major_count] = i
				end
				if tmp_civ:IsMajor() == false and tmp_civ:IsAlive() == true then
					minor_count = minor_count + 1
					minor_table[minor_count] = i
				end
			end
		end

		if (force_remap == true and bError_proximity == true) then
			print ("Init: Defeat all players");
			for i = 1, major_count do
				local pPlayer = Players[major_table[i]]
				local playerUnits;
				local startPlot;
				playerUnits = pPlayer:GetUnits()

				for j, unit in playerUnits:Members() do
					playerUnits:Destroy(unit)			
				end
			end
			Game:SetProperty("BBS_DISTANCE_ERROR","Minimum distances between civilizations could not be met. You must remap as per CPL rules.");
			print ("Init: Exit");
			return
		end
		

		print ("Initialization - Completed", os.date("%c"))
      
      
      ---- REMOVING COASTAL MOUNTAINS -----
      for i = 1, majorCount do
         local player = majorAll[i];
         local spawnX = player.spawnX;
         local spawnY = player.spawnY;
         
         --__Debug("player", i, spawnX, spawnY);
         
         if spawnX < 0 or spawnY < 0 then
            print("invalid spawn, won't apply hill removal");
            break;
         end
         
         for j = 1, 5 do
            local list = getRing(spawnX, spawnY, j, mapXSize, mapYSize, mapIsRoundWestEast);
            
            --__Debug("----list", j);
            
            for _, element in ipairs(list) do
               
               local x = element[1];
               local y = element[2];
               
               --__Debug("----element", x, y);
               
               local xIndex = x + 1;
               local yIndex = y + 1;
               
               if (mapTerrainCode[xIndex][yIndex] % 3 == 2 and mapNextToWater[xIndex][yIndex]) then
                  __Debug(x, y)
                  local plot = Map.GetPlot(x, y);
                  print("Mountain work X: ", x, "Y: ", y, "Removing coastal mountain");
                  mountainToHill(plot);
               end
               
            end
            
         end

      end
      
      __Debug("sorti montagnes")

      -------------------------------

       ---- LARGE SPAWN CORRECTION -----
      ---- Here we will ensure that all player receive a decent amount of hills/two-twos ---
      ----------------------------
      
      -- With 12 distance, we are going to fix up to ring 7
      local fixedRing = math.floor((Major_Distance_Target / 2) + 1);
      
      __Debug("Major count", majorCount);
      
      for i = 1, majorCount do
         local player = majorAll[i];
         local spawnX = player.spawnX;
         local spawnY = player.spawnY;
         
         if spawnX < 0 or spawnY < 0 then
            print("invalid spawn, won't apply spawn correction");
            break;
         end
         
         __Debug("-----------------");
         __Debug("Player", player.civName);
         __Debug("-----------------");
         
         local missingHills = 0;
         local missingTwoTwo = 0;
         
         for j = 3, fixedRing do
         
            local okToHill = {};
            local okToHillCount = 0;
            
            local okToHillBkp = {}; -- use as failback: will need to remove resource
            local okToHillBkpCount = 0;
            
            local hillCount = 0;
            local twoTwoCount = 0;
            local plainGrasslandTile = 0; -- this tile is workable
            
            
            
            local list = getRing(spawnX, spawnY, j, mapXSize, mapYSize, mapIsRoundWestEast);
            
            for _, element in ipairs(list) do
               local x = element[1];
               local y = element[2];
               
               local xIndex = x + 1;
               local yIndex = y + 1;
               
               if mapTwoTwo[xIndex][yIndex] >= 2 then
                  twoTwoCount = twoTwoCount + 1;
               end
               
               if (mapTerrainCode[xIndex][yIndex] == 0 or mapTerrainCode[xIndex][yIndex] == 1 or mapTerrainCode[xIndex][yIndex] == 3
                      or mapTerrainCode[xIndex][yIndex] == 4) then -- we are looking at plain/grassland only
                  plainGrasslandTile = plainGrasslandTile + 1;
                  if (mapTerrainCode[xIndex][yIndex] == 4 or mapTerrainCode[xIndex][yIndex] == 1) then
                     hillCount = hillCount + 1;
                  end
               end
               
               local hillReturn = isHillAble(x, y);
               if hillReturn == 1 then
                  table.insert(okToHill, {x, y});
                  okToHillCount = okToHillCount + 1;
               elseif hillReturn == 0 then
                  table.insert(okToHillBkp, {x, y});
                  okToHillBkpCount = okToHillBkpCount + 1;
               end
            end
            
            local aimedTwoTwo =  math.floor(plainGrasslandTile * spawnTwoTwo + 1);
            local aimedHills =  math.floor(plainGrasslandTile * spawnHills + 1);
            
            __Debug("Ring ", j, "Hill status: current", hillCount, "Aimed hills", aimedHills);
            __Debug("Ring ", j, "two-two status: current", twoTwoCount, "Aimed two-two:", aimedTwoTwo);
            __Debug("Ring ", j, "Workable tiles", plainGrasslandTile);
            
            local hillDiff = aimedHills - hillCount;
            local twotwoDiff = aimedTwoTwo - twoTwoCount;
            
            if (hillDiff > 0) then
               missingHills = missingHills + hillDiff;
            end
            
            if (twotwoDiff > 0) then
               missingTwoTwo = missingTwoTwo + twotwoDiff;
            end
            
            okToHill = GetShuffledCopyOfTable(okToHill);
            okToHillBkp = GetShuffledCopyOfTable(okToHillBkp);
            
            local givenTwoTwos = giveHills(okToHill, okToHillCount, okToHillBkp, okToHillBkpCount, hillDiff)
            
            twotwoDiff = twotwoDiff - givenTwoTwos;
            
            giveTwoTwos(okToHill, okToHillCount, okToHillBkp, okToHillBkpCount, twotwoDiff)
            
         end
         
         __Debug("Missing", missingTwoTwo, "Two-twos and ", missingHills, "hills");
      end

		--------------------------------------------------------------------------------------
		-- Terrain Balancing - Init
		--------------------------------------------------------------------------------------		

		for i = 1, major_count do
			local sPlayerLeaderName = PlayerConfigurations[major_table[i]]:GetLeaderTypeName()
			local sPlayerCivName = PlayerConfigurations[major_table[i]]:GetCivilizationTypeName()
			local pPlayer = Players[major_table[i]]
			local playerUnits;
			local startPlot;
			--playerUnits = pPlayer:GetUnits()

			--for j, unit in playerUnits:Members() do
				--local unitTypeName = UnitManager.GetTypeName(unit)
				--if "LOC_UNIT_SETTLER_NAME" == unitTypeName then
					SpawnTurn = 1;
					--startPlot = Map.GetPlot(unit:GetX(), unit:GetY());
					startPlot = pPlayer:GetStartingPlot()
					if (startPlot ~= nil) then
						tempEval = EvaluateStartingLocation(startPlot)
						
					------------------------------------------------------------------------------------------------------------		
					-- Create the master major table assigning the data from the EvaluateStartingLocation function
					--	Then majList[i] object is used for the rest of the code to store each players information for balancing
					------------------------------------------------------------------------------------------------------------
					-- EvalType = {impassable,water,snow,desert, food_spawn_start, prod_spawn_start, culture_spawn_start, faith_spawn_start, impassable_start,water_start,snow_start,desert_start,impassable_inner,water_inner,snow_inner,desert_inner,impassable_outer,water_outer,snow_outer,desert_outer,flood,hill_start,hill_inner,best_tile,second_best_tile}
					----------------------------------------------------------------------------------------------
						--------------------------------------------------------------------------------------------
						majList[i] = 	{	leader = sPlayerLeaderName; 
											civ = sPlayerCivName; 
											plotX = startPlot:GetX(); 
											plotY = startPlot:GetY(); 
											food_spawn_start = tempEval[5]; 
											prod_spawn_start = tempEval[6]; 
											culture_spawn_start = tempEval[7]; 
											faith_spawn_start = tempEval[8]; 
											impassable_start = tempEval[9];
											water_start = tempEval[10];
											snow_start = tempEval[11];
											desert_start = tempEval[12];
											impassable_inner = tempEval[13];
											water_inner = tempEval[14];
											snow_inner = tempEval[15];
											desert_inner = tempEval[16];
											impassable_outer = tempEval[17];
											water_outer = tempEval[18];
											snow_outer = tempEval[19];
											desert_outer = tempEval[20];
											flood = tempEval[21];
											hill_start = tempEval[22];
											hill_inner = tempEval[23];
											prod_adjust=tempEval[6];
											food_adjust=tempEval[5];
											best_tile = tempEval[24]; 
											best_tile_2 = tempEval[25]; 
											food_spawn_inner = tempEval[26]; 
											prod_spawn_inner = tempEval[27]; 
											best_tile_inner = tempEval[28]; 
											best_tile_inner_2 = tempEval[29];
											plains = tempEval[30];
											isBase22 = tempEval[31];
											bestTiles1Ring1_index = tempEval[32];
											bestTiles1Ring2_index = tempEval[33];
											bestTiles2Ring1_index = tempEval[34];
											bestTiles2Ring2_index = tempEval[35];
											best_tile_3 = tempEval[36]; 
											bestTiles1Ring3_index = tempEval[37];
											isFullCoastal = false; 
											coastalType = -1; 
											harborPlot = nil; 
											coastalScore = 0; 
											minCoastalScore = 0; 
											seaResourcesR2Count = 0; 
											improvableSeaR2Count = 0; 
											seaResourcesR3Count = 0; 
											improvableSeaR3Count = 0; 
											seaResourcesR2 = nil; 
											seaResourcesR3 = nil; 
											possibleCoastalRing2Count = 0; 
											possibleCoastalRing3Count = 0; 
											possibleCoastalRing2 = nil; 
											possibleCoastalRing3 = nil;
										};

						__Debug("Major Start X: ", majList[i].plotX, "Major Start Y: ", majList[i].plotY, "Player: ",major_table[i]," ",majList[i].leader, majList[i].civ);
					end
							
				--end
			--end
		end

		--------------------------------------------------------------------------------------	
		-- Terraforming
		--------------------------------------------------------------------------------------
		if debug_balancing == false then
		__Debug("Terraforming Starts")
		print("--- Begin debug information ---");
        print("---");

        for i = 1, major_count do
			if major_table[i] ~= nil then
				if Players[major_table[i]] ~= nil and Players[major_table[i]]:GetTeam() ~= nil and majList[i] ~= nil then
					print("Player ID:", major_table[i], " Team:", Players[major_table[i]]:GetTeam(), majList[i].civ, majList[i].leader);
            else
					print("Error:",i,major_table[i],"Missing Player")
				end
         else
				print("Error:",i,major_table[i],"Missing Player")
			end
	   end


        print("---");
        print("--- End debug information ---");
        
     
      
      -----------------
      
		-- Fix lack of freshwater
		--[[
		for i = 1, major_count do
			-- Added Spectator mod handling if a major player isn't detected
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR" and majList[i].leader ~= "LEADER_LADY_SIX_SKY") then
				-- Check for freshwater
					local wplot = Map.GetPlot(majList[i].plotX,majList[i].plotY)
					if (wplot:IsCoastalLand() == false and wplot:IsWater() == false and  wplot:IsRiver() == false and wplot:IsFreshWater() == false) then
					-- Fix No Water
						print("Water Terraforming Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ); -- put a print to catch the error in non debug mode
						Terraforming_Water(Map.GetPlot(majList[i].plotX,majList[i].plotY));
					end
				end
			end
		end

		-- Buff the negative score at the AssignStage, 
		-- Look at Floodplains and remove the excess in the starting circle to allow the balancing to work properly

		--for i = 1, major_count do
		--	-- Added Spectator mod handling if a major player isn't detected
		--	if (majList[i] ~= nil) then
		--		if(majList[i].leader ~= "LEADER_SPECTATOR"  ) then
		--		-- Do not reduce floodplain for Egypt or Desert Civ with Desert Floodplains
		--		if (majList[i].flood > 4 and IsFloodCiv(majList[i].civ) == false) then
		--			-- Check for Floodplains Start
		--			__Debug("Floodplains Terraforming Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
		--			Terraforming_Flood(Map.GetPlot(majList[i].plotX,majList[i].plotY), iBalancingThree);
		--		end
		--		end
		--	end
		--end]]

		-- Fix an error where Civ could spawn on a Luxury

		for i = 1, major_count do
			-- Added Spectator mod handling if a major player isn't detected
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR"  ) then
					local start_plot = Map.GetPlot(majList[i].plotX,majList[i].plotY);
					if (start_plot ~= nil) then
						if (start_plot:GetResourceCount() > 0) then
							--ResourceBuilder.SetResourceType(start_plot, -1);
                     terraformBBSPlot(start_plot, -2, -1, -2)                     
						end
						--if (startConfig ~= 3) then
							--__Debug("Luxury balancing: Check for Banned Luxury on Spawn");
							--Terraforming_BanLux(start_plot);
						--end
					end
				end
			end
		end

		-- Check the style option selected by the player, default = 1

		if (bTerraformingSpawn == true) then

			-- Cycle through Civs to find the ones with odd starts

			for i = 1, major_count do
				-- Added Spectator mod handling if a major player isn't detected
				if (majList[i] ~= nil) then
					if(majList[i].leader ~= "LEADER_SPECTATOR"  ) then
						-- Check for Tundra Starts
						if ( (majList[i].snow_start + majList[i].snow_inner + majList[i].snow_outer) > 6 and IsTundraCiv(majList[i].civ) == false ) or ( (majList[i].snow_start + majList[i].snow_inner + majList[i].snow_outer) > 2 and (majList[i].water_start + majList[i].water_inner + majList[i].water_outer) > 4 and IsTundraCiv(majList[i].civ) == false ) then
							__Debug("Terraforming Polar Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
							Terraforming(Map.GetPlot(majList[i].plotX,majList[i].plotY), iBalancingThree,0);
						end
						
						if ( (majList[i].desert_outer + majList[i].desert_inner + majList[i].desert_start) > 6 and IsDesertCiv(majList[i].civ) == false ) or ( (majList[i].desert_outer + majList[i].desert_inner + majList[i].desert_start) > 2  and (majList[i].water_start + majList[i].water_inner + majList[i].water_outer) > 4 and IsDesertCiv(majList[i].civ) == false ) then
							if( IsTundraCiv(majList[i].civ) == true ) then 
							__Debug("Terraforming Desert Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
							Terraforming(Map.GetPlot(majList[i].plotX,majList[i].plotY), iBalancingThree,1);
							else
							__Debug("Terraforming Desert Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
							Terraforming(Map.GetPlot(majList[i].plotX,majList[i].plotY), iBalancingThree,0);
							end
						end
						
						if (IsDesertCiv(majList[i].civ) == false) and ( IsTundraCiv(majList[i].civ) == false ) and (majList[i].desert_outer + majList[i].desert_inner + majList[i].desert_start + majList[i].snow_start + majList[i].snow_inner + majList[i].snow_outer) > 4  then
							__Debug("Terraforming Mixed Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
							Terraforming(Map.GetPlot(majList[i].plotX,majList[i].plotY), iBalancingThree,0);
						end


						if( IsDesertCiv(majList[i].civ) == true) then -- Now forces to Terraform Mali to counterbalance the lower amount of deserts on the map
							__Debug("Mali Terraforming Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
							Terraforming(Map.GetPlot(majList[i].plotX,majList[i].plotY), iBalancingThree,2);
						end
						
						if( IsTundraCiv(majList[i].civ) == true ) then
							__Debug("Terraforming Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
							Terraforming(Map.GetPlot(majList[i].plotX,majList[i].plotY), iBalancingThree,1);
						end

					end
				end
			end



			else


			__Debug("Terraforming: Terrain Update Not Required (Use Original Civ 6 Map)");
		end
      
  
      

		-- Fix Natural Wonders mountains problem
		-- Will Handle in 1.4.7 from Database
		--for iPlotIndex = 0, Map.GetPlotCount()-1 do
		--	local natPlot = Map.GetPlotByIndex(iPlotIndex)
		--	if (natPlot ~= nil) then
		--		if (natPlot:IsNaturalWonder() == true and natPlot:GetFeatureType() ~= 29) then
		--			for i = 0, 5 do
		--				local adjacentPlot = GetAdjacentTiles(natPlot, i);
		--				if (adjacentPlot ~= nil) then
		--					if (adjacentPlot:IsImpassable() == true and adjacentPlot:GetFeatureType() ~= g_FEATURE_VOLCANO and adjacentPlot:IsNaturalWonder() == false) then
		--						TerrainBuilder.SetTerrainType(adjacentPlot,adjacentPlot:GetTerrainType()-1);
		--						if ( adjacentPlot:GetFeatureType() == g_FEATURE_VOLCANO) then
		--							TerrainBuilder.SetFeatureType(adjacentPlot,-1);
		--						end	
		--					end
		--				end
		--			end
		--		end
		--	end
		--end

		-- Fix extreme Mountains Start
		for i = 1, major_count do
			-- Added Spectator mod handling if a major player isn't detected
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR"    and majList[i].leader ~= "LEADER_PACHACUTI"  ) then
					if ( ( (majList[i].impassable_start + majList[i].impassable_inner + majList[i].impassable_outer) >= 12) or ((majList[i].impassable_start + majList[i].impassable_inner + majList[i].impassable_outer) >= 8 and (majList[i].water_start + majList[i].water_inner + majList[i].water_outer) >= 4 ) ) then
						-- Check for Mountain Start
						__Debug("Mountain Terraforming Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
						Terraforming_Mountain(Map.GetPlot(majList[i].plotX,majList[i].plotY),0)

					end
				end
				if(majList[i].leader == "LEADER_PACHACUTI" and  (majList[i].impassable_start + majList[i].impassable_inner + majList[i].impassable_outer) < 2)  then
						__Debug("Mountain Terraforming Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
						Terraforming_Mountain(Map.GetPlot(majList[i].plotX,majList[i].plotY),3)
				end
			end
		end

		-- Fix Walled in
		for i = 1, major_count do
			-- Added Spectator mod handling if a major player isn't detected
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR"  ) then
					if ( ( (majList[i].impassable_start + majList[i].water_start ) > 4) and majList[i].leader ~= "LEADER_PACHACUTI"  ) then
						-- Check for Walled-in
						__Debug("Walled-In Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
						Terraforming_Nuke_Mountain(Map.GetPlot(majList[i].plotX,majList[i].plotY))

					end
				end
			end
		end

		-- Fix Trees missing / Plains 
		if string.lower(mapName) ~= "tilted_axis.lua" then
		for iPlotIndex = 0, Map.GetPlotCount()-1, 1 do
			local rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
			local pPlot = Map.GetPlotByIndex(iPlotIndex)
			if (pPlot:GetY() > gridHeight/6 and pPlot:GetY() < gridHeight*4/9) or (pPlot:GetY() > 5*gridHeight/9 and pPlot:GetY() < gridHeight*5/6) then
				if rng < 0.55 then
				if pPlot:IsImpassable() == false and pPlot:IsWater() == false and pPlot:GetResourceType() == -1 and pPlot:GetFeatureType() == -1 and pPlot:GetTerrainType() ~= 7 and pPlot:GetTerrainType() ~= 6 and pPlot:GetTerrainType() ~= 7 and pPlot:GetTerrainType() ~= 12 and pPlot:GetTerrainType() ~= 13 then
					if rng < 0.15 or  (rng < 0.33 and pPlot:GetTerrainType() == 3) then
						--TerrainBuilder.SetFeatureType(pPlot,3)
                  terraformBBSPlot(pPlot, -2, -2, 3);
					end
				end
				end
			end
		end
			
		end

		for i = 1, major_count do
			-- Added Spectator mod handling if a major player isn't detected
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR") then
				-- Check for freshwater
					local wplot = Map.GetPlot(majList[i].plotX,majList[i].plotY)
					if (wplot:IsFreshWater() == false) then
					-- Fix No Water
						__Debug("Water Terraforming Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ); -- put a print to catch the error in non debug mode
						Terraforming_Water(Map.GetPlot(majList[i].plotX,majList[i].plotY),majList[i].civ);
					end
				end
			end
		end
		__Debug("Terraforming: Completed")
		print ("Terraforming - Completed", os.date("%c"))
      

		---------------------------------------------------------------------------------------------------------------
		-- Starting the resources rebalancing in 3 phases: Strategic, Food and Production
		---------------------------------------------------------------------------------------------------------------
		---------------------------------------------------------------------------------------------------------------
		-- Phase 1: Strategic Resource Balancing / Original Firaxis Code from AddBalancedResources() reworked
		---------------------------------------------------------------------------------------------------------------

		__Debug("Phase 1: Strategic Resource Balancing")

		for i = 1, major_count do
		-- Added Spectator mod handling if a major player isn't detected
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR"  ) then
               if (Map.GetPlot(majList[i].plotX,majList[i].plotY):IsWater() == false) then
                  --print("Will ensure that all strategics resources are present");
                  BalanceStrategic(Map.GetPlot(majList[i].plotX,majList[i].plotY))
               end
				end
			end
		end

		-- Phase 1 Completed
		print ("Strategic Resouce Balancing - Completed", os.date("%c"))
		
		---------------------------------------------------------------------------------------------------------------
		-- Phase 2: Food Resource Balancing / Original Fertility function Code from AddBalancedResources() reworked
		---------------------------------------------------------------------------------------------------------------
		local bStrategic_only = false
		if (bStrategic_only == true) then
			print("Debut Mode: Only Do Strategic Resources Rebalancing")
		end

		-- Check for Food in the starting area of each Major Civ
		if (bStrategic_only == false) then
		count = 0;
		for i = 1, major_count do
			local temp = 0;
			
			if (majList[i] == nil or majList[i].leader == "LEADER_SPECTATOR"  ) then

				count = count + 1
				else
				startPlot = Map.GetPlot(majList[i].plotX, majList[i].plotY);
				tempEval = EvaluateStartingLocation(startPlot)
				majList[i].food_spawn_start = tempEval[5]+0.25 * tempEval[26] + tempEval[13]*0.75  -- Adjust for Mountains;;
				majList[i].prod_spawn_start = tempEval[6]+0.25 * tempEval[27];
				if (majList[i].civ == "CIVILIZATION_MALI" ) then
					majList[i].food_spawn_start = majList[i].food_spawn_start + tempEval[12] * 1.5
					elseif (majList[i].civ == "CIVILIZATION_CANADA" ) then
						if m_BBGEnabled == true then
							majList[i].food_spawn_start = majList[i].food_spawn_start + tempEval[11] * 1.75 -- was 1.25 would make Canada less prone to food correction
						end
					elseif (majList[i].civ == "CIVILIZATION_RUSSIA" ) then
					majList[i].food_spawn_start = majList[i].food_spawn_start + tempEval[11] * 1 -- was 0 would make Russia less prone to food correction
					elseif (majList[i].civ == "CIVILIZATION_MAORI" ) then
					majList[i].food_spawn_start = math.max(majList[i].food_spawn_start,18) -- so Maori doesn't penalized other.
				end
				temp = majList[i].food_spawn_start;

				if (temp > maxFood) then
					maxFood = temp;
				end

				avgFood = avgFood + temp;
		
			end

		end
		
		if (count > 0) then
			__Debug(count , "Spectators detected.")
		end

		avgFood = avgFood / (major_count - count)	
		
		__Debug("Phase 2: Food Balancing: Average:", avgFood)

		-- Check for Major Civ below threshold

		for i = 1, major_count do
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR"  ) then
				if (majList[i].food_spawn_start < ((avgFood) * (1 - dispersion*3)) or majList[i].food_spawn_start < minFood) then
					__Debug("Need to adjust: ", majList[i].leader, majList[i].food_spawn_start, "Min Food:",minFood)
					-- Try to Understand the reason for the low food
					-- Is it Maori ?
					if (Map.GetPlot(majList[i].plotX,majList[i].plotY):IsWater() == true) then
						__Debug("Food balancing:", majList[i].leader, "Don't adjust Maori start");
	
				-- Is it a Mountain start?
						elseif (majList[i].impassable_start > 1) then
							__Debug("Food balancing:", majList[i].leader, "Mountains detected");

				-- But is the leader biased toward Mountains? 
							if (((majList[i].civ == "CIVILIZATION_INCA") and (math.floor(avgFood  - majList[i].food_spawn_start) < 4)) or ((majList[i].civ == "CIVILIZATION_MAPUCHE") and (math.floor(avgFood + iBalancingTwo - majList[i].food_spawn_start) < 4))) then
								__Debug("Food balancing:", majList[i].leader, "Mountain Civ Detected: No need to re-balance");
								else
								__Debug("Food balancing:", majList[i].leader, "Start Mountains re-Balancing");
								__Debug("Food balancing: Food missing:", math.max(math.floor(avgFood  - majList[i].food_spawn_start), minFood - majList[i].food_spawn_start));
								count = 0;
								for j = 1, math.max(math.floor(avgFood + 1 - majList[i].food_spawn_start), minFood - majList[i].food_spawn_start,5) do
									if ((AddBonusFood(Map.GetPlot(majList[i].plotX,majList[i].plotY),iBalancingThree,3, majList[i].harborPlot) == false)) then
										count = count + 1
										if (count == 3) then
											__Debug("Food balancing:", majList[i].leader, "Will grand a luxury");
											AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"food")
											count = count + 1;
										end
									end
								end
							end

						else

				-- Well it has to be a shitty start then....
							__Debug("Food balancing:", majList[i].leader, "Poor start detected");
							__Debug("Food balancing: Food missing:", math.max(math.floor(avgFood  - majList[i].food_spawn_start),minFood - majList[i].food_spawn_start));
							count = 0;
							local count_2 = 0;
							for j = 1, math.max(math.floor(avgFood  + 1 - majList[i].food_spawn_start), minFood - majList[i].food_spawn_start,5) do
								if (majList[i].civ == "CIVILIZATION_MALI" and majList[i].desert_start > 0) then
										__Debug("Food balancing:", majList[i].leader, "Desert start detected");
										count = count + 1;
										if count < 4 then
											if ((AddBonusFood(Map.GetPlot(majList[i].plotX,majList[i].plotY),iBalancingThree,2, majList[i].harborPlot) == false)) then
												count = count + 1;
											end
											elseif count == 3 then
												__Debug("Food balancing:", majList[i].leader, "Will grand a luxury (Desert Start)");
												AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"food")
											else
												__Debug("Food balancing:", majList[i].leader, "No longer grant anything to avoid overloading the spawn (Desert Start)");
							
										end
									elseif (majList[i].civ == "CIVILIZATION_RUSSIA" or majList[i].civ == "CIVILIZATION_CANADA" and majList[i].snow_start > 2) then
										__Debug("Food balancing:", majList[i].leader, "Tundra start detected");
										if ((AddBonusFood(Map.GetPlot(majList[i].plotX,majList[i].plotY),iBalancingThree,1, majList[i].harborPlot) == false)) then
											count = count + 1;
											if (count == 3) then
												__Debug("Food balancing:", majList[i].leader, "Will grand a luxury (Tundra Start)");
												AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"food")
												count = count + 1;
											end
											if (count == 5) then
												__Debug("Food balancing:", majList[i].leader, "Will grand a luxury (Tundra Start)");
												AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"food")
											end
										end
									elseif (majList[i].plains > 5) then
										__Debug("Food balancing:", majList[i].leader, "Plains start detected");
										count_2 = count_2 + 1;
										if count_2 < 3 then
											if ((AddBonusFood(Map.GetPlot(majList[i].plotX,majList[i].plotY),iBalancingThree,0, majList[i].harborPlot) == false)) then
												count = count + 1;
												if (count == 3) then
												__Debug("Food balancing:", majList[i].leader, "Will grand a luxury (Plain Start)");
												AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"food")
												count = count + 1;
												end
												if (count == 5) then
												__Debug("Food balancing:", majList[i].leader, "Will grand a luxury (Plain Start)");
												AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"food")
												end
											end
											elseif count_2 == 3 then
											__Debug("Food balancing:", majList[i].leader, "Will grand a luxury (Plain Start)");
											AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"food")											
											else
											__Debug("Food balancing:", majList[i].leader, "No longer grant anything to avoid overloading the spawn (Plain Start)");
										end
									else 
									__Debug("Food balancing:", majList[i].leader, "Unordinary start detected");
									if ((AddBonusFood(Map.GetPlot(majList[i].plotX,majList[i].plotY),iBalancingThree,0, majList[i].harborPlot) == false)) then
										count = count + 1;
										if (count == 3) then
											__Debug("Food balancing:", majList[i].leader, "Will grand a luxury");
											AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"food")
											count = count + 1;
										end
										if (count == 5) then
											__Debug("Food balancing:", majList[i].leader, "Will grand a luxury");
											AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"food")
										end
									end

								end
							end
	

					end
					
				else
					__Debug("No Need to adjust: ", majList[i].leader, majList[i].food_spawn_start)
				end
				end
			end
		end
	

		-- Phase 2 reduce the positive outliers (Yes Firaxis intended to correct positive outliers! here this is skwed to extrem outlier with "dispersion * 2")

		-- Check for Major Civ below threshold
		
		if (startConfig ~= 3) then

		for i = 1, major_count do
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR" and IsFloodCiv(majList[i].civ) == false ) then
				if (majList[i].food_spawn_start > ((avgFood + iBalancingTwo) * (1 + dispersion * 1.5))) then
					__Debug("Need to adjust Food Down: ", majList[i].leader);

					if (math.ceil(majList[i].food_spawn_start - (avgFood + iBalancingTwo)-1) > 0) then
						for j = 1, math.ceil(majList[i].food_spawn_start - (avgFood + iBalancingTwo)-1) do
							RemoveFood(Map.GetPlot(majList[i].plotX,majList[i].plotY));
						end
					end
				end
				end
			end
		end

		end


		-- Phase 2 completed
		print ("Food Balancing - Completed", os.date("%c"))
		
		
		    ---- BEGIN Coastal work -------
      
      __Debug("---");
      __Debug("---");
      __Debug("------ BEGIN Coastal work ------");
      __Debug("---");
      __Debug("---");

      ------------------------------------------------------------------------
      --- Coastal work
      --- The aim of this section is to balance the coastal spawns
      --- The final result should be that each player spawing coastal will have:
      ---   - A FAIR start, including a minimum of workable resources
      ---   - A BALANCED start: All the coastal starts will be compared and balanced with each other
      ---
      --- The objective is to prevent coastal players from having too much of difference at start
      ---
      --- Please note:
      --- - Coastal work is done BEFORE the actual BBS land balancing
      ---     - Having too good of coastal start can impact your land tiles (food removal, ...)
      ---     - BBS, in case of plain start with low food, can add fish to balance, after the coastal work
      ---
      --- - All calculation is done based on your actual spawn
      ---     You may get a way better situation by moving one tile away
      ---     It would be too complicated to take that into account.
      ---
      ---
      --- - Oil is completely excluded and remains untouched
      ---   Oil provides adjacency, nice production bonus and strategics, but is unlocked way too late to be taken into account for start balance
      ------------------------------------------------------------------------
      
		-- Fix improper reef and ice placement in coastal start
		for i = 1, major_count do
			-- Added Spectator mod handling if a major player isn't detected
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR"  ) then
					if (Map.GetPlot(majList[i].plotX,majList[i].plotY):IsCoastalLand() == true) then
						-- Check for Coastal Start
                  __Debug("--------------");
						__Debug("Coastal Terraforming Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
                  
                  local harborPlot = nil;
                  local coastalScore = 0;
                  
                  
                  -------
                  -- Phase one of the coastal balancing, this will:
                  --    - Will clean harbor location
                  --    - Remove ice around the spawn
                  --    - Change ocean into coast around the spawn
                  --    - Make sure that you have at least 3 workable (where you can put fishing boat) sea tiles
                  --    - Build structures (list of tiles, ...) for the next phases
                  -------
                  Cleaning_Coastal(majList[i]);
                  
                  
                  
                  
                  -------
                  -- Phase two of the coastal balancing, this will:
                  --    - Compute the coastal score of each spawn
                  --    - The score is based on:
                  --          - The type of the resource (amber, fish, turtle, ...)
                  --          - The location of the resource (Ring 1, 2 or 3)
                  --          - Whether it's giving harbour adjancency or not
                  --          - In case of reef (naked, with turtle or fish), bonus is added if it is giving campus adj
                  --
                  --    - Compute the MINIMAL score of each spawn
                  --          - Same formula applies, but we only count luxuries
                  --          - Luxuries may not be removed by this script (BBS policy, don't remove them !)
                  -------
                  
                  __Debug("--");
                  
                  if (majList[i].isFullCoastal == true) then
                  -- will compute the naval score
                     majList[i].coastalScore = Coastal_Score(majList[i]);
                     __Debug("Coastal: finished counting the civ score:", majList[i].coastalScore);
                     majList[i].minCoastalScore = Min_Coastal_Score(majList[i]);
                     __Debug("Coastal: finished counting the civ minimal score:", majList[i].minCoastalScore);
                  end
                  
                  __Debug("--");
                  --__Debug("Coastal Terraforming Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
						--Terraforming_Coastal(Map.GetPlot(majList[i].plotX,majList[i].plotY), iBalancingThree, false)
                  
                                
                  
					end
				end
			end
		end
      
      -------
      -- Phase three of the coastal balancing, this will:
      --    - Compute the mean Naval Score (mathematical mean of all spawns)
      --    - Find the global minimal score
      --        - That score will be a score under which a civ can't go
      --
      --    - Decide the AIMED score, which will be used as basis to balance the civs
      --      That score will be picked as the maximal value between
      --       
      --          - The Meanscore (this way we do not artifically nerf all the spawns if they are balanced with one another)
      --          - The Global minimal score: As a civ will ne be able to get under that amount, we'll bring all the others towards
      --               If a civ has 2 turtles ring two, we'll make that the other civs also have really good spawns
      --          - The "Base Coastal Score"
      --              The base coastal score is an artificial score, picked to make sure that all the spaws have a minimal viability
      --              The base coastal score will ensure that even if all the civs have a poor start, they will be brought to a correct one
      -------
      
      __Debug("---");
      __Debug("---");
      __Debug("Major civ naval calculation done, printing scores and computing means");
      -- plot all naval scores
      local navalCivsCount = 0;
      local totalcoastalScore = 0;
      local navalMeanScore = 0;
      -- Minimal naval score, under which one civ cannot go under (with luxuries for exemple)
      local minNavalScore = 0;
      for i = 1, major_count do
		if (majList[i] ~= nil and majList[i].leader ~= "LEADER_SPECTATOR") then
			if (majList[i].isFullCoastal == true) then
				__Debug("Leader:", majList[i].leader, " score:", majList[i].coastalScore);
				__Debug("Leader:", majList[i].leader, " MIN score:", majList[i].minCoastalScore);
				navalCivsCount = navalCivsCount + 1;
				totalcoastalScore = totalcoastalScore + majList[i].coastalScore;
				if (majList[i].minCoastalScore > minNavalScore) then
					minNavalScore = majList[i].minCoastalScore;
				end
			end
		 end
      end
      
      
      navalMeanScore = totalcoastalScore / navalCivsCount;
      
      -- If the mean score is lower than what we believe to be a minimum, we aim at the base minimum
      local aimedNavalScore = math.max(navalMeanScore, BASE_COASTAL_SCORE);
      -- If one civ has a spawn that cannot be reduced to the mean, we will use that score for a minimum
      -- Remember that BBS will balance overly good naval spawns by removing inland yield
      aimedNavalScore = math.max(aimedNavalScore, minNavalScore);
      __Debug("---");
      __Debug("naval mean score:", navalMeanScore);
      __Debug("---");
      __Debug("Minimal naval score:", minNavalScore);
      __Debug("---");
      __Debug("Aimed naval score", aimedNavalScore);
      __Debug("---");
      
      
      
      
      -------
      -- Phase four of the coastal balancing, this will:
      --    - Buff the starts which are under the aimed score
      --    - Nerf the starts which are over the aimed score
      -- 
      -- In both cases, we put a margin.
      -- If a civ is within the margin (up or down) of the aimed score, no further change will be made
      --
      --
      -- Please also note:
      --    - If a start has to be nerfed, it will NEVER, go under the aimed score
      --    - If a start has to be buffed, it will NEVER, go over the aimed score
      -- This to make some fairness (if you had good start, you won't get worse than the guy who had shitty one at start
      -------
      
      for i = 1, major_count do
		if (majList[i] ~= nil and majList[i].leader ~= "LEADER_SPECTATOR") then
			if (majList[i].isFullCoastal == true) then
            __Debug("--------------");
            __Debug("Adjusting naval score of:", majList[i].leader);
            __Debug("Current Costal score:", majList[i].coastalScore);
            adjustCoastal(majList[i], aimedNavalScore, COASTAL_MARGIN);
            __Debug("Score after balancing:", majList[i].coastalScore);
         end
		 end
      end

      __Debug("---");
      __Debug("---");
      __Debug("------ END Coastal work ------");
      __Debug("---");
      __Debug("---");
      ---- END of Coastal balancing ------
		
		
		
		
		---------------------------------------------------------------------------------------------------------------------------------------------------------
		-- Phase 3: Production Balancing: Firaxis didn't have production rebalancing in their AddBalancedResources(), so this mimics the Phase 2
		----------------------------------------------------------------------------------------------------------------------------------------------------------

		-- First let's check the hills
		count = 0;
		for i = 1, major_count do
			
			if (majList[i] == nil or majList[i].leader == "LEADER_SPECTATOR") then
				count = count +1;
				else
				startPlot = Map.GetPlot(majList[i].plotX, majList[i].plotY);
				tempEval = EvaluateStartingLocation(startPlot)
				majList[i].food_spawn_start = tempEval[5]+0.25 * tempEval[26];
				majList[i].prod_spawn_start = tempEval[6]+0.25 * tempEval[27];
				majList[i].hill_start = tempEval[22];
				majList[i].hill_inner = tempEval[23];
				avgHill = avgHill + majList[i].hill_start * 2 + majList[i].hill_inner;
			end

		end
		
		avgHill = avgHill / (major_count - count);	
		
		__Debug("Phase 3a: Prod - Hills Balancing: Average:", avgHill)
		
		-- Check for Major Civ below threshold	

		for i = 1, major_count do
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR") then
				if ((majList[i].hill_start * 2 + majList[i].hill_inner) < ((avgHill + 1)* (1 - dispersion*2))) then
					__Debug("Hill balancing: Need to adjust: ", majList[i].leader)

				-- Try to Understand the reason for the low hill count
				-- Is it Maori ?
					if (Map.GetPlot(majList[i].plotX,majList[i].plotY):IsWater() == true) then
						__Debug("Prod balancing:", majList[i].leader, "Don't adjust Maori start");
	
						else
						__Debug("Prod balancing:", majList[i].leader, "Start Hill Rebalancing");
						__Debug("Prod balancing: Hills missing:", math.floor((avgHill + iBalancingTwo - (majList[i].hill_start + majList[i].hill_inner))/2));
					
						if (math.floor((avgHill + iBalancingTwo  - (majList[i].hill_start + majList[i].hill_inner))/2) > 0) then
							count = 0;
							for j = 1, math.floor((avgHill + iBalancingTwo  - (majList[i].hill_start + majList[i].hill_inner))/2) do

									if (AddHills(Map.GetPlot(majList[i].plotX,majList[i].plotY),iBalancingThree,0) == false) then
										count = count + 1;

										if (count == math.min(3 - iBalancingTwo,1)) then
											__Debug("Hill balancing:", majList[i].leader, "Will Grant something to be defined");
										end
									end


							end
						end
					end
				end
				end
			end	
		end



		__Debug("Phase 3a: Prod - Hills Balancing: Completed")


		---
		count = 0;
		for i = 1, major_count do
			
			if (majList[i] == nil or majList[i].leader == "LEADER_SPECTATOR") then
				count = count +1;
				else
				startPlot = Map.GetPlot(majList[i].plotX, majList[i].plotY);
				tempEval = EvaluateStartingLocation(startPlot)
				majList[i].food_spawn_start = tempEval[5]+0.25 * tempEval[26];
				majList[i].prod_spawn_start = tempEval[6]+0.25 * tempEval[27] + tempEval[13]*0.75  -- Adjust for Mountains;
				if (majList[i].civ == "CIVILIZATION_INCA" ) then
					majList[i].prod_spawn_start = majList[i].prod_spawn_start + tempEval[9] + tempEval[13]*0.25  -- Adjust for Mountains more
				end
				if (majList[i].civ == "CIVILIZATION_RUSSIA" ) then
					majList[i].prod_spawn_start = majList[i].prod_spawn_start + tempEval[11]*2  -- Was 1.75 Add +0.75 prod per Tundra tile for the faith bonus
				end
				if (majList[i].civ == "CIVILIZATION_MALI" ) then
					majList[i].prod_spawn_start = majList[i].prod_spawn_start + tempEval[12]*0.75 -- Add +0.75 prod per Desert tile for the faith bonus
				end
				if (majList[i].civ == "CIVILIZATION_MAORI" ) then
					majList[i].prod_spawn_start = math.max(majList[i].prod_spawn_start,10) -- so Maori doesn't penalized other.
				end
				avgProd = avgProd + majList[i].prod_spawn_start;
			end

		end
		
		avgProd = avgProd / (major_count - count);	
		
		__Debug("Phase 3b: Prod - Bonus Balancing: Average:", avgProd)

		-- Check for Major Civ below threshold	

		for i = 1, major_count do
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR") then
					if ( majList[i].prod_spawn_start < ( (avgProd + iBalancingTwo )*(1-dispersion) ) or majList[i].prod_spawn_start < minProd ) then
						__Debug("Prod balancing: Need to adjust: ", majList[i].leader,majList[i].prod_spawn_start, "Min Prod:", minProd)

				-- Try to Understand the reason for the low PRODUCTION
				-- Is it Maori ?
						if (Map.GetPlot(majList[i].plotX,majList[i].plotY):IsWater() == true) then
							__Debug("Prod balancing:", majList[i].leader, "Don't adjust Maori start");
	
							else
							__Debug("Prod balancing:", majList[i].leader, "Start Production Rebalancing");
							__Debug("Prod balancing: Prod missing:", math.max( math.floor( (avgProd + iBalancingTwo - majList[i].prod_spawn_start) ), minProd - majList[i].prod_spawn_start));
					
							if (math.max( math.floor( (avgProd + iBalancingTwo - majList[i].prod_spawn_start) ), minProd - majList[i].prod_spawn_start) > 0) then
								count = 0;
								for j = 1, math.max( math.floor( (avgProd + iBalancingTwo + 1 - majList[i].prod_spawn_start) ), minProd - majList[i].prod_spawn_start) do

									if (majList[i].civ == "CIVILIZATION_INCA") then

										if (AddBonusProd(Map.GetPlot(majList[i].plotX,majList[i].plotY),iBalancingThree,3) == false) then
										count = count + 1;

											if (count == math.min(3 - iBalancingTwo,1)) then
											__Debug("Prod balancing:", majList[i].leader, "Will try to grant a luxury");
											AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"prod");
											count = count + 1;
											end
											if (count == math.min(7 - iBalancingTwo,1)) then
											__Debug("Prod balancing:", majList[i].leader, "Will try to grant a luxury");
											AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"prod");
											end
										end
									
										else

										if (AddBonusProd(Map.GetPlot(majList[i].plotX,majList[i].plotY),iBalancingThree,0) == false) then
										count = count + 1;

											if (count == math.min(3 - iBalancingTwo,1)) then
											__Debug("Prod balancing:", majList[i].leader, "Will try to grant a luxury");
											AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"prod");
											count = count + 1;
											end
											if (count == math.min(7 - iBalancingTwo,1)) then
											__Debug("Prod balancing:", majList[i].leader, "Will try to grant a luxury");
											AddLuxuryStarting(Map.GetPlot(majList[i].plotX,majList[i].plotY),"prod");
											end
										end


									end
								end
							end
						end
					else	
						__Debug("Prod balancing: No Need to adjust: ", majList[i].leader,majList[i].prod_spawn_start)
					end
				end
			end	
		end

		-- Phase 3 reduce the positive outliers

		-- Check for Major Civ below threshold
		if (startConfig ~= 3) then
		
		for i = 1, major_count do
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR"  ) then
					if (majList[i].prod_spawn_start > ((avgProd + iBalancingTwo) * (1 + dispersion))) then
						__Debug("Need to adjust Production Down: ", majList[i].leader,majList[i].prod_spawn_start);
						if (math.floor(majList[i].prod_spawn_start - (avgProd + iBalancingTwo) - 1) > 0) then
							for j = 1, math.floor(majList[i].prod_spawn_start - (avgProd + iBalancingTwo) - 1) do
								RemoveProd(Map.GetPlot(majList[i].plotX,majList[i].plotY));
							end
						end
						else
						__Debug("No need to adjust Production Down: ", majList[i].leader,majList[i].prod_spawn_start);						
					end
					local max_score = 5.5
					Terraforming_Cap_Yield(Map.GetPlot(majList[i].plotX, majList[i].plotY),max_score,18,35);
				end
			end
		end
		

		end
		print ("Production Balancing - Completed", os.date("%c"))
		---------------------------------------------------------------------------------------------------------------------------------------------------------
		-- Phase 4: Best Tiles Balancing: Looking at the 4 best tiles for Ancient and Classical Starts
		----------------------------------------------------------------------------------------------------------------------------------------------------------;
		-- Reminder of the Evalfunction output
		
		-- Tile 0-5
		-- best_tile = tempEval[24]; 
		-- best_tile_2 = tempEval[25]; 
		-- bestTiles1Ring1_index = tempEval[32];
		-- bestTiles1Ring2_index = tempEval[33];
		--	best_tile_3 = tempEval[36]; 
		-- bestTiles1Ring2_index = tempEval[37];
		
		-- Tiles 6 - 13
		-- best_tile_inner = tempEval[28]; 
		-- best_tile_inner_2 = tempEval[29];
		-- bestTiles2Ring1_index = tempEval[34];
		-- bestTiles2Ring2_index = tempEval[35];
		
		-- Base tile
		-- isBase22 = tempEval[31];



		local iStartEra = GameInfo.Eras[ GameConfiguration.GetStartEra() ];
		local iStartIndex = 1;

		local data = {}
		if iStartEra ~= nil then
			iStartIndex = iStartEra.ChronologyIndex;
		end

		if (iStartIndex == 1 or iStartIndex == 2) then

		data = Terraforming_Best_Refresh(majList,major_count,"First Pass",bHighRoll)
		-- Pre Pass
		if data ~= nil then
			local max_best_tile_1 = data[1]
			local max_best_tile_2 = data[2]
			local max_best_tile_3 = data[3]
			local max_best_tile_4 = data[4]
			local avg_best_ring_1 = data[5]
			local avg_best_ring_2 = data[6]
			majList = data[7];
		
			for i = 1, major_count do
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR") then	
					local immediate_raw = (majList[i].best_tile + majList[i].best_tile_2 + majList[i].best_tile_3 + majList[i].isBase22)
					local missing_amount =  13 - immediate_raw;
					if (immediate_raw < 13) then
					
						__Debug("Tile balancing: Need to adjust: ", majList[i].leader, "Raw Immediate:",immediate_raw, "Weak",missing_amount)	
						Terraforming_Best(Map.GetPlot(majList[i].plotX,majList[i].plotY), missing_amount, max_best_tile_1, max_best_tile_2, avg_best_ring_1 ,avg_best_ring_2, majList[i].best_tile, majList[i].bestTiles1Ring1_index, majList[i].best_tile_2, majList[i].bestTiles1Ring2_index,majList[i].best_tile_3,majList[i].bestTiles1Ring3_index,majList[i].best_tile_inner,majList[i].bestTiles2Ring1_index,majList[i].best_tile_inner_2,majList[i].bestTiles2Ring2_index, 1, bHighRoll,true);
						else
						__Debug("Tile balancing: Need to adjust: ", majList[i].leader, "Raw Immediate:",immediate_raw, "Acceptable",majList[i].best_tile,majList[i].best_tile_inner)	
					end
				end
			end
			end		
		end
		
		data = Terraforming_Best_Refresh(majList,major_count,"Second Pass",bHighRoll)
		-- Pre Pass
		if data ~= nil then
			local max_best_tile_1 = data[1]
			local max_best_tile_2 = data[2]
			local max_best_tile_3 = data[3]
			local max_best_tile_4 = data[4]
			local avg_best_ring_1 = data[5]
			local avg_best_ring_2 = data[6]
			majList = data[7];
		
		-- High Roll a.k.a. Coloo's Greed
		if bHighRoll == true then
			for i = 1, major_count do
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR") then
					if  majList[i].isBase22 > 1 then
						TerrainBuilder.SetTerrainType(Map.GetPlot(majList[i].plotX,majList[i].plotY),3);
						majList[i].isBase22 = 0
						__Debug("Terraforming Best X: ", majList[i].plotX, "Y: ", majList[i].plotY, "Removed Plain Hills Start");		
					end
				
				
					if (majList[i].best_tile < 6) and (majList[i].best_tile_inner < 6) then
						__Debug("Tile balancing: Need to adjust: ", majList[i].leader, "Raw Yields:",total_raw_spawn_yield, "Hasn't High Rolled - Missing Score",6.5-math.max(majList[i].best_tile,majList[i].best_tile_inner))	
						Terraforming_Best(Map.GetPlot(majList[i].plotX,majList[i].plotY), 2, 7, 7, avg_best_ring_1 ,avg_best_ring_2, majList[i].best_tile, majList[i].bestTiles1Ring1_index, majList[i].best_tile_2, majList[i].bestTiles1Ring2_index,majList[i].best_tile_3,majList[i].bestTiles1Ring3_index,majList[i].best_tile_inner,majList[i].bestTiles2Ring1_index,majList[i].best_tile_inner_2,majList[i].bestTiles2Ring2_index, 1, bHighRoll,true);
						else
						__Debug("Tile balancing: Need to adjust: ", majList[i].leader, "Raw Yields:",total_raw_spawn_yield, "Already High Rolled - Best",majList[i].best_tile,majList[i].best_tile_inner)	
					end
				end
			end
			end
		
		end
			
		end
		
		data = Terraforming_Best_Refresh(majList,major_count,"Third Pass",bHighRoll)
		if data ~= nil then
			local max_best_tile_1 = data[1]
			local max_best_tile_2 = data[2]
			local max_best_tile_3 = data[3]
			local max_best_tile_4 = data[4]
			local avg_best_ring_1 = data[5]
			local avg_best_ring_2 = data[6]
			majList = data[7];
			for i = 1, major_count do
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR") then
					if majList[i].best_tile > 5.75 and majList[i].isBase22 > 1 then
							TerrainBuilder.SetTerrainType(Map.GetPlot(majList[i].plotX,majList[i].plotY),3);
							majList[i].isBase22 = 0
							__Debug("Terraforming Best X: ", majList[i].plotX, "Y: ", majList[i].plotY, "Removed Plain Hills Start");		
					end
					
					local total_average = (avg_best_ring_1  + avg_best_ring_2);
					local total_raw_spawn_yield = (majList[i].best_tile + majList[i].best_tile_2 + majList[i].best_tile_3 + majList[i].best_tile_inner + majList[i].best_tile_inner_2 + majList[i].isBase22);
					local missing_amount =  total_average - total_raw_spawn_yield;
					
					if ( missing_amount > 0.75 ) then
						-- Looking at the 4 best tiles unadjusted average we have more than 1 yield (e.g. 1 food) missing 
						
						__Debug("Tile balancing: Need to adjust: ", majList[i].leader, "Raw Yields:",total_raw_spawn_yield, "Missing score:", missing_amount)
						if (majList[i].civ == "CIVILIZATION_RUSSIA" or majList[i].civ == "CIVILIZATION_CANADA" ) and majList[i].tundra_start > 3 then
							Terraforming_Best(Map.GetPlot(majList[i].plotX,majList[i].plotY), missing_amount, max_best_tile_1, max_best_tile_2, avg_best_ring_1 ,avg_best_ring_2 ,majList[i].best_tile, majList[i].bestTiles1Ring1_index, majList[i].best_tile_2, majList[i].bestTiles1Ring2_index,majList[i].best_tile_3,majList[i].bestTiles1Ring3_index,majList[i].best_tile_inner,majList[i].bestTiles2Ring1_index,majList[i].best_tile_inner_2,majList[i].bestTiles2Ring2_index, 1, false);
							elseif (majList[i].civ == "CIVILIZATION_MALI")  and majList[i].desert_start > 3 then
							Terraforming_Best(Map.GetPlot(majList[i].plotX,majList[i].plotY), missing_amount, max_best_tile_1, max_best_tile_2,avg_best_ring_1 ,avg_best_ring_2,majList[i].best_tile, majList[i].bestTiles1Ring1_index, majList[i].best_tile_2, majList[i].bestTiles1Ring2_index,majList[i].best_tile_3,majList[i].bestTiles1Ring3_index,majList[i].best_tile_inner,majList[i].bestTiles2Ring1_index,majList[i].best_tile_inner_2,majList[i].bestTiles2Ring2_index, 2, false);
							else
							Terraforming_Best(Map.GetPlot(majList[i].plotX,majList[i].plotY), missing_amount, max_best_tile_1, max_best_tile_2, avg_best_ring_1 ,avg_best_ring_2,majList[i].best_tile, majList[i].bestTiles1Ring1_index, majList[i].best_tile_2, majList[i].bestTiles1Ring2_index,majList[i].best_tile_3,majList[i].bestTiles1Ring3_index,majList[i].best_tile_inner,majList[i].bestTiles2Ring1_index,majList[i].best_tile_inner_2,majList[i].bestTiles2Ring2_index, 0, false);
						end
						elseif ( missing_amount < -1.5 ) then
						
						__Debug("Tile balancing: Need to adjust: ", majList[i].leader, "Raw Yields:",total_raw_spawn_yield, "Extra Yield:", -missing_amount)
					
						Terraforming_Best(Map.GetPlot(majList[i].plotX,majList[i].plotY), missing_amount, max_best_tile_1, max_best_tile_2, avg_best_ring_1 ,avg_best_ring_2, majList[i].best_tile, majList[i].bestTiles1Ring1_index, majList[i].best_tile_2, majList[i].bestTiles1Ring2_index,majList[i].best_tile_3,majList[i].bestTiles1Ring3_index,majList[i].best_tile_inner,majList[i].bestTiles2Ring1_index,majList[i].best_tile_inner_2,majList[i].bestTiles2Ring2_index, 0, bHighRoll);
					
						else
						
						__Debug("Tile balancing: No Need to adjust: ", majList[i].leader, "Raw Yields:",total_raw_spawn_yield, "Missing score:", missing_amount)

					end
				end
			end
			end
		end


		print ("Best Tiles Balancing - Completed", os.date("%c"))
		end -- era check end
		---------------------------------------------------------------------------------------------------------------------------------------------------------
		-- Finalize
		----------------------------------------------------------------------------------------------------------------------------------------------------------

		-- Re-run coastal check if Reefs added are blocking a harbour
      -- Useless since no resource/reef maybe added at the harbor location (57F@n)
      --[[
		for i = 1, major_count do
			-- Added Spectator mod handling if a major player isn't detected
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR"  ) then
				if (Map.GetPlot(majList[i].plotX,majList[i].plotY):IsCoastalLand() == true) then
					-- Check for Coastal Start
					__Debug("Coastal Terraforming Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ);
					Terraforming_Coastal(Map.GetPlot(majList[i].plotX,majList[i].plotY), iBalancingThree, true)
				end
				end
			end
		end
      --]]

		-- Oasis Hills ? Well no
		for i = 1, major_count do
			-- Added Spectator mod handling if a major player isn't detected
			if (majList[i] ~= nil) then
				if(majList[i].civ == "CIVILIZATION_MALI") then
					for j = 0, 60 do
 						local mali_plot = GetAdjacentTiles(Map.GetPlot(majList[i].plotX,majList[i].plotY),j) -- forgot the j!
						if mali_plot ~= nil then
							if (mali_plot:GetTerrainType() == 7 and mali_plot:GetFeatureType() == 4) then
								print ("Oasis on Hills -----> Die")
								TerrainBuilder.SetTerrainType(mali_plot, 6);
								ResourceBuilder.SetResourceType(mali_plot, -1);
							end
						end
					end
				end
			end
		end

		-- Fix lack of freshwater #2

		for i = 1, major_count do
			-- Added Spectator mod handling if a major player isn't detected
			if (majList[i] ~= nil) then
				if(majList[i].leader ~= "LEADER_SPECTATOR"  ) then
				-- Check for freshwater
					local wplot = Map.GetPlot(majList[i].plotX,majList[i].plotY)
					if (wplot:IsCoastalLand() == false and wplot:IsWater() == false and  wplot:IsRiver() == false and wplot:IsFreshWater() == false) then
					-- Fix No Water
						print("Water Terraforming Start X: ", majList[i].plotX, "Start Y: ", majList[i].plotY, "Player: ",i," ",majList[i].leader, majList[i].civ); -- put a print to catch the error in non debug mode
						Terraforming_Water(Map.GetPlot(majList[i].plotX,majList[i].plotY),majList[i].civ);
					end
				end
			end
		end

		-- Run one last eval for debug
		--
		
		for i = 1, major_count do
			local temp = 0;
			count = 0;
			if (majList[i] == nil or majList[i].leader == "LEADER_SPECTATOR"  ) then
				count = count + 1
				else
				startPlot = Map.GetPlot(majList[i].plotX, majList[i].plotY);
				tempEval = EvaluateStartingLocation(startPlot)
				--	Ring 1
				majList[i].best_tile = tempEval[24];
				majList[i].best_tile_2 = tempEval[25];
				majList[i].best_tile_3 = tempEval[36];
				-- Ring 2
				majList[i].best_tile_inner = tempEval[28]; 
				majList[i].best_tile_inner_2 = tempEval[29];
				if (majList[i].civ == "CIVILIZATION_RUSSIA" or majList[i].civ == "CIVILIZATION_CANADA" ) and tempEval[11] > 4 then
				-- Russia/Canada on Tundra
				--	Ring 1
				majList[i].best_tile = tempEval[24]+1.5;
				majList[i].best_tile_2 = tempEval[25]+1.5;
				majList[i].best_tile_3 = tempEval[36]+1.5;
				-- Ring 2
				majList[i].best_tile_inner = tempEval[28]+1.5; 
				majList[i].best_tile_inner_2 = tempEval[29]+1.5;
				end
				if (majList[i].civ == "CIVILIZATION_MALI" ) and tempEval[12] > 4 then
				-- Mali on Desert
				--	Ring 1
				majList[i].best_tile = tempEval[24]+1.5;
				majList[i].best_tile_2 = tempEval[25]+1.5;
				majList[i].best_tile_3 = tempEval[36]+1.5;
				-- Ring 2
				majList[i].best_tile_inner = tempEval[28]+1.5; 
				majList[i].best_tile_inner_2 = tempEval[29]+1.5;
				end				
				if (majList[i].civ == "CIVILIZATION_MAORI" ) and tempEval[14] > 4 then
				-- Maori if on water
				--	Ring 1 like a 2:2
				majList[i].best_tile = 5;
				majList[i].best_tile_2 = 5;
				majList[i].best_tile_3 = 5;
				-- Ring 2
				majList[i].best_tile_inner = 5; 
				majList[i].best_tile_inner_2 = 5;
				end
				if majList[i].best_tile > 5.75 and majList[i].isBase22 > 1 then
					TerrainBuilder.SetTerrainType(Map.GetPlot(majList[i].plotX,majList[i].plotY),3);
					majList[i].isBase22 = 0
					__Debug("Terraforming Best X: ", majList[i].plotX, "Y: ", majList[i].plotY, "Removed Plain Hills Start");		
				end
				print ("BBS Script - Completed", os.date("%c"), "Player", i,Locale.Lookup(PlayerConfigurations[major_table[i]]:GetPlayerName()) ,"Food adjustement:", (tempEval[5]-majList[i].food_adjust), "Production adjustement:", (tempEval[6]-majList[i].prod_adjust) );
				print ("S1-S2-S3:", majList[i].best_tile, majList[i].best_tile_2,majList[i].best_tile_3,"I1-I2:",majList[i].best_tile_inner,majList[i].best_tile_inner_2,"2:2 Base?",majList[i].isBase22)
			end
         
         --- ETHIOPIA HILL FIX
         
         if (majList[i] ~= nil and majList[i].leader == "LEADER_MENELIK" ) then
            local x = majList[i].plotX;
            local y = majList[i].plotY;
            
            local plot = Map.GetPlot(x, y);
            local terrain = plot:GetTerrainType();
            local feature = plot:GetFeatureType();
            
            if terrain % 3 ~= 1 then -- not a hill
               TerrainBuilder.SetTerrainType(plot, 1); -- granting grassland hill
               if (feature == 2 or feature == 5) then
                  TerrainBuilder.SetFeatureType(plot, -1);
               end
               print("Fixed Ethiopian spawn to hill", x, y);
            end
         end

		end
		

		end -- Strategic Only loop
		else
		print ("BBS Script - Completed - Debug", os.date("%c") );
		end -- Debug Balancing

		-- Gemedon's input to limit crash
		TerrainBuilder.AnalyzeChokepoints()
		-- Coast -> Lake
		AreaBuilder.Recalculate();
		-- Fix the Volcano bug
		for iPlotIndex = 0, Map.GetPlotCount()-1, 1 do
			local pPlot = Map.GetPlotByIndex(iPlotIndex)
			if (pPlot:GetFeatureType() == g_FEATURE_VOLCANO) then
				local iPlotTerrain = pPlot:GetTerrainType()
				if iPlotTerrain ~= 2 and iPlotTerrain ~= 5 and iPlotTerrain ~= 8 and iPlotTerrain ~= 11 and iPlotTerrain ~= 14 then
					TerrainBuilder.SetFeatureType(pPlot,5)
					ResourceBuilder.SetResourceType(pPlot,-1)
				end
			end
		end
		print ("BBS Script - Completed", os.date("%c") );
	else
		__Debug("D TURN STARTING: Any other turn");

	end
   
end

------------------------------------------------------------------------------------------------------------------------------

function EvaluateStartingLocation(plot)

--Terrain Type
--0 Grassland
--1 Grass + hill
--2 grass + mountain
--3 plain
--4 plain + hill
--5 plain + mountain
--6 desert
--7 desert + hill
--8 desert + mountain
--9 tundra
--10 tundra + hill
--11 tundra + mountain
--12 snow
--13 snow + hill
--14 snow + mountain
--15 water
--16 ocean
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	local impassable = 0;
	local snow = 0;
	local water = 0;
	local desert = 0;
	local flood = 0;
	local hill = 0;
	local plains = 0;
	local flood_start = 0;
	local flood_inner = 0;
	local flood_outer = 0;
	local food_spawn_start = 0;
	local prod_spawn_start = 0;
	local food_spawn_inner = 0;
	local prod_spawn_inner = 0;
	local culture_spawn_start = 0;
	local faith_spawn_start = 0;
	local best_yield_start = 0;
	local impassable_start = 0;
	local snow_start = 0;
	local water_start = 0;
	local desert_start = 0;
	local hill_start = 0;
	local impassable_inner = 0;
	local snow_inner = 0;
	local water_inner = 0;
	local desert_inner = 0;
	local hill_inner = 0;
	local impassable_outer = 0;
	local snow_outer = 0;
	local water_outer = 0;
	local desert_outer = 0
	local type = "Standard"
	local gridWidth, gridHeight = Map.GetGridSize();
	local terrainType = plot:GetTerrainType();
	local iResourcesInDB = 0;
	local bCulture = false;
	local bFaith = false;
	local direction = 0;
	eResourceType	= {};
	eResourceClassType = {};
	eRevealedEra = {};
	local count = 0;
	local adjacentPlot = nil;
	local adjacentPlot2 = nil;
	local adjacentPlot3 = nil;
	local adjacentPlot4 = nil;
	local temp_tile = 0;
	local best_tile = 0;
	local best_tile_i = 0;
	local second_best_tile = 0;
	local second_best_tile_i = 0;
	local third_best_tile = 0;
	local third_best_tile_i = 0;
	local best_tile_inner = 0;
	local best_tile_inner_i = 0;
	local second_best_tile_inner = 0;
	local second_best_tile_inner_i = 0;
	local plainhills = 0;

-- EvalType is the result table to then be used as the basis for later balancing opperation

	local EvalType = {impassable,water,snow,desert, food_spawn_start, prod_spawn_start, culture_spawn_start, faith_spawn_start, impassable_start,water_start,snow_start,desert_start,impassable_inner,water_inner,snow_inner,desert_inner,impassable_outer,water_outer,snow_outer,desert_outer}

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Hash;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
		eRevealedEra[iResourcesInDB] = row.RevealedEra;
		iResourcesInDB = iResourcesInDB + 1;
	end


-- Starting plot:
-- Tile #-1

	for i = -1, 35 do
		adjacentPlot = GetAdjacentTiles(plot, i)
		if (adjacentPlot ~= nil) then
			terrainType = adjacentPlot:GetTerrainType();
				if (i == -1) then
					if(adjacentPlot:IsImpassable() == true) then
						impassable = impassable + 1;
					end

					-- Checks to see if the plot is water
					if(adjacentPlot:IsWater() == true) then
						water = water + 1;
					end

					-- Add to the Snow counter if snow shows up
					if(terrainType == 9 or terrainType == 10 or terrainType == 12 or terrainType == 13) then
						snow = snow + 1;
					end

					-- Add to the hills counter if Hill shows up
					if(terrainType == 1 or terrainType == 7 or terrainType == 4 or terrainType == 10) then
						hill = hill + 1;
					end
					
					-- Add to the plains counter if Plain shows up
					if(terrainType == 3 or terrainType == 4) then
						plains = plains + 1;
					end
					
					-- Add flag for plain hills.
					if(terrainType == 4) then
						plainhills = 1.5
					end
			
					-- Add to the Desert counter if desert shows up
					if(terrainType == 6 or terrainType == 7) then
						desert = desert + 1;
					end

					-- Add to Floodplains if they are showing up
					if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS or adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS or adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_GRASSLAND) then
						flood = flood +1;
					end
                    			-- Gets the food and production counts
                   			food_spawn_start = food_spawn_start + adjacentPlot:GetYield(g_YIELD_FOOD);
                    			prod_spawn_start = prod_spawn_start + adjacentPlot:GetYield(g_YIELD_PRODUCTION);
					bCulture = false;
					bFaith = false;
					for row = 0, iResourcesInDB do
						if (eResourceClassType[row]== "RESOURCECLASS_LUXURY") then
							if(adjacentPlot:GetResourceCount() > 0) then
								-- Check for Coffee, Jade, Marble, Incense, dyes and clams
								if (adjacentPlot:GetResourceType() == 12 or adjacentPlot:GetResourceType() == 20 or adjacentPlot:GetResourceType() == 21 or adjacentPlot:GetResourceType() == 49) then
									bCulture = true;
									elseif (adjacentPlot:GetResourceType() == 15 or adjacentPlot:GetResourceType() == 18 or adjacentPlot:GetResourceType() == 23) then
									bFaith = true;
								end
							end
						end
					end
					if (bCulture == true) then
						culture_spawn_start = culture_spawn_start + 1;
					end
					if (bFaith == true) then
						faith_spawn_start = faith_spawn_start + 1;
					end
-- Starting ring
-- Tiles #0 #5
				elseif (i > -1 and i < 6) then

					temp_tile = 0;

					if(adjacentPlot:IsImpassable() == true) then
						impassable_start = impassable_start + 1;
					end

					-- Checks to see if the plot is water
					if(adjacentPlot:IsWater() == true) then
						water_start = water_start + 1;
					end

					-- Add to the Snow counter if snow shows up
					if(terrainType == 9 or terrainType == 10 or terrainType == 12 or terrainType == 13) then
						snow_start = snow_start + 1;
					end
			
					-- Add to the Desert counter if desert shows up
					if(terrainType == 6 or terrainType == 7) then
						desert_start = desert_start + 1;
					end

					-- Add to the hills counter if Hill shows up
					if(terrainType == 1 or terrainType == 7 or terrainType == 4 or terrainType == 10) then
						hill_start = hill_start + 1;
					end
					
					-- Add to the plains counter if Plain shows up
					if(terrainType == 3 or terrainType == 4) then
						plains = plains + 1;
					end

					-- Add to Floodplains if they are showing up
					if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS or adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS or adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_GRASSLAND) then
						flood_start = flood_start +1;
					end

                    -- Gets the food and production counts
                   	food_spawn_start = food_spawn_start + adjacentPlot:GetYield(g_YIELD_FOOD);
                    prod_spawn_start = prod_spawn_start + adjacentPlot:GetYield(g_YIELD_PRODUCTION);
					temp_food = adjacentPlot:GetYield(g_YIELD_FOOD)
               temp_prd = adjacentPlot:GetYield(g_YIELD_PRODUCTION)
               temp_gold = adjacentPlot:GetYield(g_YIELD_GOLD)
               temp_tile = 0;
               
               
               
               -- low food amount, tile will be worth less
               if temp_food <= 1 then
               
                  if temp_prd <= 2 then
                     temp_tile = temp_food + temp_prd * 0.5;
                  -- 1/3 tile, worth somehow more
                  elseif temp_prd == 3 then
                     temp_tile = temp_food + temp_prd * 1.0 + temp_gold * 0.25;
                  elseif temp_prd == 4 then
                     temp_tile = temp_food + temp_prd * 1.50 + temp_gold * 0.25;
                  else
                     __Debug("I have found a plain tile with more than 4 production !");
                     temp_tile = temp_food + temp_prd * 1.50 + temp_gold * 0.25;
                  end
                  
               elseif temp_food == 2 then
                  
                  if temp_prd <= 2 then
                     temp_tile = temp_food + temp_prd * 1.5 + temp_gold * 0.25;
                  elseif temp_prd == 3 then
                     temp_tile = temp_food + temp_prd * 1.5 + temp_gold * 0.25;
                  else
                     __Debug("I have found a grassland tile with more than 3 production !");
                     temp_tile = temp_food + temp_prd * 1.75 + temp_gold * 0.25;
                  end
                  
               elseif temp_food == 3 then
               
                  if temp_prd <= 1 then
                     temp_tile = temp_food + temp_prd * 1.5 + temp_gold * 0.25;
                  elseif temp_prd == 2 then
                     temp_tile = temp_food + temp_prd * 1.75 + temp_gold * 0.25;
                  else
                     __Debug("I have found a tile with more than 3 food AND production !");
                     temp_tile = temp_food + temp_prd * 1.75 + temp_gold * 0.25;
                  end
               elseif temp_food == 4 then
                  if temp_prd == 0 then
                     temp_tile = temp_food;
                  else
                     __Debug("I have found a tile with 4 food AND production !");
                     temp_tile = temp_food + temp_prd * 1.75 + temp_gold * 0.25;
                  end
                  
               elseif temp_food == 5 then
                  if temp_prd == 0 then
                     temp_tile = temp_food;
                  else
                     __Debug("I have found a tile with 5 food AND production !");
                     temp_tile = temp_food + temp_prd * 1.75 + temp_gold * 0.25;
                  end
                  
               else
                  __Debug("I have found a tile with 6 food!");
                  temp_tile = temp_food + temp_prd * 1.75 + temp_gold * 0.25;
                  
               end
               
                  
                  
               --[[
					if temp_tile > 1 then
						temp_tile = temp_tile + adjacentPlot:GetYield(g_YIELD_PRODUCTION) * 1.5 + adjacentPlot:GetYield(g_YIELD_GOLD) * 0.25;
               elseif adjacentPlot:GetYield(g_YIELD_PRODUCTION) < 3.5 then -- not enough food to value those tiles fully
						temp_tile = temp_tile + adjacentPlot:GetYield(g_YIELD_PRODUCTION) * 0.5 + adjacentPlot:GetYield(g_YIELD_GOLD) * 0;
               else
						temp_tile = temp_tile + adjacentPlot:GetYield(g_YIELD_PRODUCTION) * 0.75 + adjacentPlot:GetYield(g_YIELD_GOLD) * 0;
					end
               --]]
					
					-- Adjust for non discovered resources
					if(adjacentPlot:GetResourceType() ~= -1) then
						if (adjacentPlot:GetResourceType() == 41 or adjacentPlot:GetResourceType() == 46 or adjacentPlot:GetResourceType() == 43) then
							temp_tile = temp_tile - 2 * 1.5
							prod_spawn_start = prod_spawn_start - 2
							elseif (adjacentPlot:GetResourceType() == 42 or adjacentPlot:GetResourceType() == 44) then
							temp_tile = temp_tile - 1 * 1.5 - 1 
							food_spawn_start = food_spawn_start - 1
							prod_spawn_start = prod_spawn_start - 1
							elseif (adjacentPlot:GetResourceType() == 45) then
							temp_tile = temp_tile - 3 * 1.5
							prod_spawn_start = prod_spawn_start - 3
						end
					end

					bCulture = false;
					bFaith = false;
					if(adjacentPlot:GetResourceType() ~= -1) then
						-- Check for Coffee, Jade, Marble, Incense, Silk, dyes and clams
						if (adjacentPlot:GetResourceType() == 12 or adjacentPlot:GetResourceType() == 20 or adjacentPlot:GetResourceType() == 21 or adjacentPlot:GetResourceType() == 25 or adjacentPlot:GetResourceType() == 49) then
							bCulture = true;
							elseif (adjacentPlot:GetResourceType() == 15 or adjacentPlot:GetResourceType() == 18 or adjacentPlot:GetResourceType() == 23) then
							bFaith = true;
						end
					end

					if (bCulture == true) then
						culture_spawn_start = culture_spawn_start + 1;
						if adjacentPlot:GetYield(g_YIELD_PRODUCTION) > 0 and adjacentPlot:GetYield(g_YIELD_FOOD) > 1 then
							temp_tile = temp_tile + 1.5;
							else
							temp_tile = temp_tile + 0.5;
						end
					end
					if (bFaith == true) then
						faith_spawn_start = faith_spawn_start + 1;
						if adjacentPlot:GetYield(g_YIELD_PRODUCTION) > 0 and adjacentPlot:GetYield(g_YIELD_FOOD) > 1 then
							temp_tile = temp_tile + 1;
							else
							temp_tile = temp_tile + 0.5;
						end
					end
					if (temp_tile > best_tile or temp_tile == best_tile) then
						third_best_tile = second_best_tile
						third_best_tile_i = second_best_tile_i 
						second_best_tile = best_tile
						second_best_tile_i = best_tile_i 
						best_tile = temp_tile
						best_tile_i = adjacentPlot:GetIndex()
						elseif ((temp_tile > second_best_tile or temp_tile == second_best_tile) and temp_tile < best_tile) then
							third_best_tile = second_best_tile
							third_best_tile_i = second_best_tile_i 
							second_best_tile = temp_tile
							second_best_tile_i = adjacentPlot:GetIndex()
						elseif (temp_tile > third_best_tile and temp_tile < second_best_tile) then
							third_best_tile = temp_tile
							third_best_tile_i = adjacentPlot:GetIndex()
					end
					temp_tile = 0	
-- Inner ring
-- Tiles #6 to #17
			elseif (i > 5 and i < 18) then

				-- Checks to see if the plot is impassable
			if(adjacentPlot:IsImpassable() == true) then
				impassable_inner = impassable_inner + 1;
			end

				-- Checks to see if the plot is water
			if(adjacentPlot:IsWater() == true) then
				water_inner = water_inner + 1;
			end

				-- Add to the Snow counter if snow shows up
			if(terrainType == 9 or terrainType == 10 or terrainType == 12 or terrainType == 13) then
				snow_inner = snow_inner + 1;
			end

			-- Add to the hills counter if Hill shows up
			if(terrainType == 1 or terrainType == 7 or terrainType == 4 or terrainType == 10) then
				hill_inner = hill_inner + 1;
			end
			
			-- Add to the plains counter if Plain shows up
			if(terrainType == 3 or terrainType == 4) then
				plains = plains + 1;
			end

				-- Add to Floodplains if they are showing up
			if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS or adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS or adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_GRASSLAND) then
				flood_inner = flood_inner +1;
			end
	
				-- Add to the Desert counter if desert shows up
			if(terrainType == 6 or terrainType == 7) then
				desert_inner = desert_inner + 1;
			end

                    	-- Gets the food and production counts
                   	food_spawn_inner = food_spawn_inner + adjacentPlot:GetYield(g_YIELD_FOOD);
                    	prod_spawn_inner = prod_spawn_inner + adjacentPlot:GetYield(g_YIELD_PRODUCTION);
					temp_tile = adjacentPlot:GetYield(g_YIELD_FOOD) 
					
					if temp_tile > 1 then
						temp_tile = temp_tile + adjacentPlot:GetYield(g_YIELD_PRODUCTION) * 1.5 + adjacentPlot:GetYield(g_YIELD_GOLD) * 0.25;
						elseif adjacentPlot:GetYield(g_YIELD_PRODUCTION) < 3.5 then -- not enough food to value those tiles fully
						temp_tile = temp_tile + adjacentPlot:GetYield(g_YIELD_PRODUCTION) * 0.5 + adjacentPlot:GetYield(g_YIELD_GOLD) * 0;
						else
						temp_tile = temp_tile + adjacentPlot:GetYield(g_YIELD_PRODUCTION) * 0.75 + adjacentPlot:GetYield(g_YIELD_GOLD) * 0;
					end

			-- Adjust for non discovered resources
			if(adjacentPlot:GetResourceType() ~= -1) then
				if (adjacentPlot:GetResourceType() == 41 or adjacentPlot:GetResourceType() == 46 or adjacentPlot:GetResourceType() == 43) then
							temp_tile = temp_tile - 2 * 1.5
							prod_spawn_start = prod_spawn_start - 2
							elseif (adjacentPlot:GetResourceType() == 42 or adjacentPlot:GetResourceType() == 44) then
							temp_tile = temp_tile - 1 * 1.5 - 1 
							food_spawn_inner = food_spawn_inner - 1
							prod_spawn_inner = prod_spawn_inner - 1
							elseif (adjacentPlot:GetResourceType() == 45) then
							temp_tile = temp_tile - 3 * 1.5
							prod_spawn_inner = prod_spawn_inner - 3
				end
			end
					bCulture = false;
					bFaith = false;
					if(adjacentPlot:GetResourceType() ~= -1) then
						-- Check for Coffee, Jade, Marble, Incense, Silk, dyes and clams
						if (adjacentPlot:GetResourceType() == 12 or adjacentPlot:GetResourceType() == 20 or adjacentPlot:GetResourceType() == 21 or adjacentPlot:GetResourceType() == 25 or adjacentPlot:GetResourceType() == 49) then
							bCulture = true;
							elseif (adjacentPlot:GetResourceType() == 15 or adjacentPlot:GetResourceType() == 18 or adjacentPlot:GetResourceType() == 23) then
							bFaith = true;
						end
					end

					if (bCulture == true) then
						culture_spawn_start = culture_spawn_start + 1;
						if adjacentPlot:GetYield(g_YIELD_PRODUCTION) > 0 and adjacentPlot:GetYield(g_YIELD_FOOD) > 1 then
							temp_tile = temp_tile + 1.5;
							else
							temp_tile = temp_tile + 0.5;
						end
					end
					if (bFaith == true) then
						faith_spawn_start = faith_spawn_start + 1;
						if adjacentPlot:GetYield(g_YIELD_PRODUCTION) > 0 and adjacentPlot:GetYield(g_YIELD_FOOD) > 1 then
							temp_tile = temp_tile + 1;
							else
							temp_tile = temp_tile + 0.5;
						end
					end
					if (temp_tile > best_tile_inner or temp_tile == best_tile_inner) then
						second_best_tile_inner = best_tile_inner
						second_best_tile_inner_i = best_tile_inner_i
						best_tile_inner = temp_tile
						best_tile_inner_i = adjacentPlot:GetIndex()
						else
						
						if (temp_tile > second_best_tile_inner and temp_tile < best_tile_inner) then
							second_best_tile_inner = temp_tile
							second_best_tile_inner_i = adjacentPlot:GetIndex()
						end
					end
					temp_tile = 0	

-- Outer ring
-- Tiles #18 to #35
			elseif (i > 17 and i < 36) then

				if(adjacentPlot:IsImpassable() == true) then
					impassable_outer = impassable_outer + 1;
				end

						-- Checks to see if the plot is water
				if(adjacentPlot:IsWater() == true) then
					water_outer = water_outer + 1;
				end

				-- Add to the Snow counter if snow shows up
				if(terrainType == 9 or terrainType == 10 or terrainType == 12 or terrainType == 13) then
					snow_outer = snow_outer + 1;
				end
			
				-- Add to the Desert counter if desert shows up
				if(terrainType == 6 or terrainType == 7) then
					desert_outer = desert_outer + 1;
				end

				-- Add to Floodplains if they are showing up
				if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS or adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS or adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_GRASSLAND) then
					flood_outer = flood_outer +1;
				end


			end
		end
	end

	impassable = impassable + impassable_start + impassable_inner + impassable_outer
	water = water + water_start + water_inner + water_outer
	snow = snow + snow_start + snow_inner + snow_outer
	flood = flood + flood_start + flood_inner + flood_outer
	desert = desert + desert_start + desert_inner + desert_outer
	hill = hill + hill_start + hill_inner
	__Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Total mountain: ", impassable, "Total water: ", water, "Total snow: ", snow, "Total desert: ", desert, "Total hill", hill, "Immediate Food: ", food_spawn_start, "Immediate Prod: ", prod_spawn_start, "Immediate Culture: ", culture_spawn_start, "Immediate Faith: ",faith_spawn_start,"Floodplains",flood,"Best_tile",best_tile,"Best_tile_2",second_best_tile, "Plains Tiles",plains)
	EvalType = {impassable,water,snow,desert, food_spawn_start, prod_spawn_start, culture_spawn_start, faith_spawn_start, impassable_start,water_start,snow_start,desert_start,impassable_inner,water_inner,snow_inner,desert_inner,impassable_outer,water_outer,snow_outer,desert_outer,flood,hill_start,hill_inner,best_tile,second_best_tile,food_spawn_inner, prod_spawn_inner,best_tile_inner,second_best_tile_inner,plains,plainhills,best_tile_i,second_best_tile_i,best_tile_inner_i,second_best_tile_inner_i,third_best_tile,third_best_tile_i}
	return EvalType
end


------------------------------------------------------------------------------------------------------------------------------------------------


function Terraforming_Cap_Yield(plot,cap_yield,start_i,end_i)

	if start_i == nil or end_i == nil or start_i <-1 or start_i > end_i then
		return
	end

	local bCulture = false;
	local bFaith = false;
	local temp_tile
	local adjacentPlot
-- Starting plot:
-- Tile #-1
-- Outer ring
-- Tiles #18 to #35
	for i = start_i, end_i do
		adjacentPlot = GetAdjacentTiles(plot, i)
		if (adjacentPlot ~= nil) then

					temp_tile = 0;
					temp_tile = adjacentPlot:GetYield(g_YIELD_FOOD) 
					if temp_tile > 1 then
						temp_tile = temp_tile + adjacentPlot:GetYield(g_YIELD_PRODUCTION) * 1.5 + adjacentPlot:GetYield(g_YIELD_GOLD) * 0.25;
						else -- not enough food to value those tiles fully
						temp_tile = temp_tile + adjacentPlot:GetYield(g_YIELD_PRODUCTION) * 0.5 + adjacentPlot:GetYield(g_YIELD_GOLD) * 0;
					end
					
					-- Adjust for non discovered resources
					if(adjacentPlot:GetResourceType() ~= -1) then
						if (adjacentPlot:GetResourceType() == 41 or adjacentPlot:GetResourceType() == 46 or adjacentPlot:GetResourceType() == 43) then
							temp_tile = temp_tile - 2 * 1.5
							elseif (adjacentPlot:GetResourceType() == 42 or adjacentPlot:GetResourceType() == 44) then
							temp_tile = temp_tile - 1 * 1.5 - 1 
							elseif (adjacentPlot:GetResourceType() == 45) then
							temp_tile = temp_tile - 3 * 1.5
						end
					end

					bCulture = false;
					bFaith = false;
					if(adjacentPlot:GetResourceType() ~= -1) then
						-- Check for Coffee, Jade, Marble, Incense, Silk, dyes and clams
						if (adjacentPlot:GetResourceType() == 12 or adjacentPlot:GetResourceType() == 20 or adjacentPlot:GetResourceType() == 21 or adjacentPlot:GetResourceType() == 25 or adjacentPlot:GetResourceType() == 49) then
							bCulture = true;
							elseif (adjacentPlot:GetResourceType() == 15 or adjacentPlot:GetResourceType() == 18 or adjacentPlot:GetResourceType() == 23) then
							bFaith = true;
						end
					end

					if (bCulture == true) then
						if adjacentPlot:GetYield(g_YIELD_PRODUCTION) > 0 and adjacentPlot:GetYield(g_YIELD_FOOD) > 1 then
							temp_tile = temp_tile + 1.5;
							else
							temp_tile = temp_tile + 0.5;
						end
					end
					if (bFaith == true) then
						if adjacentPlot:GetYield(g_YIELD_PRODUCTION) > 0 and adjacentPlot:GetYield(g_YIELD_FOOD) > 1 then
							temp_tile = temp_tile + 1;
							else
							temp_tile = temp_tile + 0.5;
						end
					end
					if (temp_tile > cap_yield) then
						__Debug("Terraforming_Cap_Yield Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Total Score:",temp_tile,"Exceeded Cap will remove resource",adjacentPlot:GetResourceType())
						--ResourceBuilder.SetResourceType(adjacentPlot,-1)
                  terraformBBSPlot(adjacentPlot, -2, -1, -2)
					end
		end
	end

end











--------------------------------------------------------------------------------------------------
function AddBonusFood(plot,intensity, flag, harborPlot)
	-- flag = 0 normal
	-- flag = 1 tundra civ
	-- flag = 2 desert civ
	-- flag = 3 mountain civ
	local iResourcesInDB = 0;
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local direction = 0;
	eResourceType	= {};
	eResourceClassType = {};
	aBonus = {};
	local limit_1 = 0;
	local max_unFeature = 2;
	local adjacentPlot = nil;
	local adjacentPlot2 = nil;
	local adjacentPlot3 = nil;
	local adjacentPlot4 = nil;
	local count = 0;
	local increment = 1;
	local start_range = 0;
	local end_range = 5;

	if (intensity == 0) then
		limit_1 = 0.9;
		elseif (intensity == 1) then
			limit_1 = 0.5;
		elseif (intensity == 2) then
			limit_1 = 0.25;
	end

	for k = 0, 1 do
	
		if k == 0 then	
		
			if (flag == 2 or flag == 1) then
				start_range = 0;
				end_range = 16;
				increment = 2;
				else
				start_range = 0;
				end_range = 5;
				increment = 1;
			end
			
			else
			if k == 1 then
				start_range = 17;
				end_range = 0;
				increment = -1;
			end
			
		end

		for i = start_range, end_range, increment do
			adjacentPlot = GetAdjacentTiles(plot, i)
		
			if (adjacentPlot ~= nil) then

				terrainType = adjacentPlot:GetTerrainType();
				-- Floodplains Only
				if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS or adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS or adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_GRASSLAND)  and  adjacentPlot:GetResourceCount() < 1 then
					
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
					if rng < 0.75 then
						-- Plains wheat
						ResourceBuilder.SetResourceType(adjacentPlot, 9, 1);
						__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added wheat on Floodplains");
						return true;
					end
				
				end
				
				-- Already with a resource
				if (terrainType == 4 and  adjacentPlot:GetResourceType() == 7) then
					
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
					
					if rng < 0.25 then
						-- Plains wheat
						TerrainBuilder.SetTerrainType(adjacentPlot,1);
						__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Converted Plains Hill Sheep into Grassland Hill Ship");
						return true;
					end
				
				end				
				

				-- Floodplains and Volcano failsafe
				if adjacentPlot:GetFeatureType() ~= g_FEATURE_FLOODPLAINS  and  adjacentPlot:GetResourceType() < 0  and adjacentPlot:GetFeatureType() ~= g_FEATURE_MARSH and adjacentPlot:GetFeatureType() ~= g_FEATURE_VOLCANO and adjacentPlot:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_PLAINS and adjacentPlot:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_GRASSLAND and adjacentPlot:IsNaturalWonder() == false then

					rng = TerrainBuilder.GetRandomNumber(100,"test")/100;

					if(adjacentPlot:GetFeatureType() == g_FEATURE_JUNGLE and terrainType ~= 4) then
				--banana
						if(ResourceBuilder.CanHaveResource(adjacentPlot, 0)) then
							ResourceBuilder.SetResourceType(adjacentPlot, 0, 1);
							__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added: Banana");
							return true;
						end

						elseif(terrainType == 3 and adjacentPlot:GetFeatureType() == -1  and adjacentPlot:GetY() > gridHeight * 0.33 and adjacentPlot:GetY() < gridHeight * 0.66  ) then
					-- Jungle
							TerrainBuilder.SetFeatureType(adjacentPlot,-1)
							TerrainBuilder.SetFeatureType(adjacentPlot,2)
							__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Add Jungle");
							return true;

						elseif( (terrainType == 6 and adjacentPlot:GetFeatureType() ~= g_FEATURE_OASIS  )
							or (terrainType == 9 and flag ~= 1) ) and adjacentPlot:IsNaturalWonder() == false and flag ~= 2  then
					-- Convert to Grassland
							if(rng > limit_1) then
								TerrainBuilder.SetTerrainType(adjacentPlot,0);	
								TerrainBuilder.SetFeatureType(adjacentPlot,-1);
								__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Turned the tile to a Grassland");
								return true;
							end
							rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
						
						elseif((terrainType == 4 and flag ~= 1 and rng > 0.75) 
						or (terrainType == 7) 
						or (terrainType == 10 and flag ~= 1)) and flag ~= 2 then
							-- Convert to Grassland
							if(rng > limit_1) then
								TerrainBuilder.SetTerrainType(adjacentPlot,1);
								TerrainBuilder.SetFeatureType(adjacentPlot,-1)
								__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Turned the tile to a Hills Grassland");
								return true;
								end

						elseif(terrainType == 0)  then
						-- Add Cattle / Rice
							if(rng > 0.5) then
								if(ResourceBuilder.CanHaveResource(adjacentPlot, 1)) then
									ResourceBuilder.SetResourceType(adjacentPlot, 1, 1);
									__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added: Cattle");
									return true;
								end
								else
								if(ResourceBuilder.CanHaveResource(adjacentPlot, 6)) then
									ResourceBuilder.SetResourceType(adjacentPlot, 6, 1);
									__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added: Rice");
									return true;
								end
							end
	
						elseif(terrainType == 3 and adjacentPlot:GetFeatureType() == -1) then
							--wheat
							if(rng > 0.5) then
								if(ResourceBuilder.CanHaveResource(adjacentPlot, 9)) then
									ResourceBuilder.SetResourceType(adjacentPlot, 9, 1);
									__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added: Wheat");
									return true;
								end
								-- Sheep
								elseif (rng > 0.1) then
								TerrainBuilder.SetTerrainType(adjacentPlot,4);
								ResourceBuilder.SetResourceType(adjacentPlot, 7, 1);
								__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added: Sheep on Plains Hills");
								return true;
								-- Maize
								else
								ResourceBuilder.SetResourceType(adjacentPlot, 52, 1);
								__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added: Maize");
								return true;
							end	
							
						elseif(terrainType == 4 and adjacentPlot:GetFeatureType() == -1 and rng < 0.75 )  then
							-- Plains wheat
								TerrainBuilder.SetTerrainType(adjacentPlot,3);
							ResourceBuilder.SetResourceType(adjacentPlot, 9, 1);
							__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Turned Plain Hills into Plain with wheat");
							return true;
					
						elseif((terrainType == 4 and adjacentPlot:GetFeatureType() == -1) 
							or (terrainType == 1 and adjacentPlot:GetFeatureType() == -1) 
							or (terrainType == 7 and adjacentPlot:GetFeatureType() == -1 and rng < 0.5) 
							or (terrainType == 10 and adjacentPlot:GetFeatureType() == -1))  then
							-- sheep
							if(ResourceBuilder.CanHaveResource(adjacentPlot, 7)) then
								ResourceBuilder.SetResourceType(adjacentPlot, 7, 1);
								__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added: Sheep");
								return true;
							end
					

						elseif(terrainType == 6 and adjacentPlot:GetFeatureType() == -1 and rng < 0.1) then
							-- Desert Sheep on Hill
							TerrainBuilder.SetTerrainType(adjacentPlot,7);
							ResourceBuilder.SetResourceType(adjacentPlot, 7, 1);
							__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added: Sheep on Desert Hill");
							return true;
			
						elseif(terrainType == 6 and adjacentPlot:GetFeatureType() == -1) then
							-- Oasis
							local bOasis = true
							for j = 0, 5 do
								adjacentPlot2 = GetAdjacentTiles(adjacentPlot, j)
								if (adjacentPlot2 ~= nil ) then
									if (adjacentPlot2:GetTerrainType() ~= 6 and adjacentPlot2:GetTerrainType() ~= 7 and adjacentPlot2:GetTerrainType() ~= 8 or adjacentPlot2:GetFeatureType() == g_FEATURE_OASIS )  then
										bOasis = false	
									end 	
								end
							
							end
							rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
							if (bOasis == true and rng < 0.25) then
								ResourceBuilder.SetResourceType(adjacentPlot, -1);
								TerrainBuilder.SetFeatureType(adjacentPlot,4)
								__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added: Oasis");
								return true;
							end
	
            ------ CHANGED BY 57FAN --------
						elseif(terrainType == 15) then
						-- fish
               -- 57F@n: making sure that we are not adding a resource on harbor tile
							if(ResourceBuilder.CanHaveResource(adjacentPlot, 5) 
								and isSameTile(adjacentPlot, harborPlot) == false 
								and (flag ~= 1 or (flag == 1 and rng > 0.5))) then
								
								ResourceBuilder.SetResourceType(adjacentPlot, 5, 1);
								__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added: Fish");
								return true;
							end
               
            ------- END CHANGE  ----------
			
						elseif( (terrainType == 4 and adjacentPlot:GetFeatureType() == 3) 
								or (terrainType == 1 and adjacentPlot:GetFeatureType() == 3) 
							or (terrainType == 7 and adjacentPlot:GetFeatureType() == 3) 
							or (terrainType == 10 and adjacentPlot:GetFeatureType() == 3) and count < max_unFeature)  then
						-- sheep instead of forest
							TerrainBuilder.SetFeatureType(adjacentPlot,-1)
							count = count + 1;
							ResourceBuilder.SetResourceType(adjacentPlot, 7, 1);
							__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added: Sheep");
							return true;
					
						elseif( (terrainType == 3 and adjacentPlot:GetFeatureType() == 3 and rng > 0.5)) then
						-- sheep instead of forest
							TerrainBuilder.SetFeatureType(adjacentPlot,-1)
							TerrainBuilder.SetTerrainType(adjacentPlot,4);
							ResourceBuilder.SetResourceType(adjacentPlot, 7, 1);
							__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Added: Sheep on Plains Hills");
							return true;



				-- Add floodplains
						elseif( (terrainType == 6 and flag == 2 and adjacentPlot:IsRiver() == true and adjacentPlot:GetFeatureType() == -1) )  then
							-- Add Desert Floodplains
							TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_FLOODPLAINS);
							__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Turned the tile to a Desert Floodplains");
							return true;


			-- Mountains to Hills
						elseif( flag ~= 2 
							and flag ~= 1 
							and ((terrainType == 2 and flag ~= 3 ) 
							or (terrainType == 5 and flag ~= 3 ) 
							or (terrainType == 8 and flag ~= 3 and flag ~= 2 ) 
							or (terrainType == 11 and flag ~= 3 and flag ~= 1) 
							or (terrainType == 14 and flag ~= 3 and flag ~= 1)))  then
					-- Convert to Flatland or Hills
							rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
							if rng > 0.90 and terrainType == 2 then
								TerrainBuilder.SetTerrainType(adjacentPlot,terrainType - 2);
								ResourceBuilder.SetResourceType(adjacentPlot, 8, 1);
								__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Turned the Grass Mountain to a Flat land with stones");
								return true;
								elseif rng > 0.70 then
								TerrainBuilder.SetTerrainType(adjacentPlot,terrainType - 1);
								__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Turned the Mountain to a Hill");					
								return true
							end
			
						else
						
			
					end
				end	
			
			end
		end



	end -- k end loop


	__Debug("Food balancing: Couldn't add Food Bonus");
	return false;
	
end

------------------------------------------------------------------------------------------------------------------------------------------------

function AddBonusProd(plot, intensity,flag)
	local iResourcesInDB = 0;
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local bWater = true;
	local count = 0;
	eResourceType	= {};
	eResourceClassType = {};
	aBonus = {};
	local limit_1 = 0;
	local range = 17;
	local adjacentPlot = nil;
	local adjacentPlot2 = nil;
	local adjacentPlot3 = nil;
	local adjacentPlot4 = nil;
	local start_range = 0;
	local end_range = 5;
	local increment = 1;	

	if (intensity == 0) then
		limit_1 = 0.9;
		elseif (intensity == 1) then
			limit_1 = 0.75;
		elseif (intensity == 2) then
			limit_1 = 0.5;
	end

	for k = 0, 1 do
	
		if k == 0 then	
		
			if (flag == 2 or flag == 1) then
			start_range = 0;
			end_range = 16;
			increment = 2;
			else
			start_range = 0;
			end_range = 5;
			increment = 1;
			end
		
			elseif k == 1 then
			start_range = 17;
			end_range = 0;
			increment = -1;
		end

		for i = start_range, end_range, increment do
		adjacentPlot = GetAdjacentTiles(plot, i);
		

		if (adjacentPlot ~= nil) then
			terrainType = adjacentPlot:GetTerrainType();
			rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
			-- volcano and floodplains safe
			if (adjacentPlot:IsNaturalWonder() == false and adjacentPlot:GetFeatureType() ~= g_FEATURE_FLOODPLAINS and adjacentPlot:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_PLAINS and adjacentPlot:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_GRASSLAND and adjacentPlot:GetFeatureType() ~= g_FEATURE_VOLCANO) then
			
				-- No Resource
				if (adjacentPlot:GetResourceType() < 0) then 
			
			
					-- No feature
					if((adjacentPlot:GetFeatureType() == -1) and (adjacentPlot:IsImpassable() == false) and (adjacentPlot:IsWater() == false) and  (adjacentPlot:GetTerrainType() ~= 6) and (adjacentPlot:GetTerrainType() ~= 7) and (adjacentPlot:GetTerrainType() ~= 12) and (adjacentPlot:GetTerrainType() ~= 13)) then
				--Wood
				--__Debug("Prod balancing: Wood");
						if rng > 0.05 then
							TerrainBuilder.SetFeatureType(adjacentPlot,3);
							ResourceBuilder.SetResourceType(adjacentPlot, -1);
							__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Prod Balancing Y: ", adjacentPlot:GetY(), "Added: Wood");
							return true;
						end
					end
					
					-- Grass	
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
					if (terrainType == 0 or terrainType == 1) and rng > 0.90 then
						ResourceBuilder.SetResourceType(adjacentPlot, 8, 1);
						TerrainBuilder.SetFeatureType(adjacentPlot,-1);
						__Debug("Food Balancing X: ", adjacentPlot:GetX(), "Food Balancing Y: ", adjacentPlot:GetY(), "Flat land with stones");
						return true
					end
					
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
					-- Grass no marsh
					if(terrainType == 0  and adjacentPlot:GetFeatureType() ~= g_FEATURE_MARSH) and rng > 0.50 then
					-- Convert to Hills
							if(rng > limit_1) then
							TerrainBuilder.SetTerrainType(adjacentPlot,1);
								__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Turned the tile to a Grassland Hill");
							return true;
							end
					end
					
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
					-- Plains no marsh
					if(terrainType == 3 and adjacentPlot:GetFeatureType() ~= g_FEATURE_MARSH) and rng > 0.50 then
							-- Convert to Hills
							if(rng > limit_1) then
								TerrainBuilder.SetTerrainType(adjacentPlot,4);
							__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Turned the tile to a Plain Hill");
								return true;
							end
					end
					
					if(terrainType == 6   and adjacentPlot:GetFeatureType() ~= g_FEATURE_OASIS) then
				-- Convert to Hills
							if(rng > limit_1) then
									TerrainBuilder.SetTerrainType(adjacentPlot,7);
								__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Turned the tile to a Desert Hill");
									return true;
								end
					end		
								
					if((terrainType == 2 and flag ~= 3 ) 
						or (terrainType == 5 and flag ~= 3 ) 
						or (terrainType == 8 and flag ~= 3 ) 
						or (terrainType == 11 and flag ~= 3) 
						or  (terrainType == 14 and flag ~= 3) ) then
				-- Convert to Plain Hills
							if(rng > limit_1) then
					TerrainBuilder.SetTerrainType(adjacentPlot,terrainType - 1);
								if ( adjacentPlot:GetFeatureType() == g_FEATURE_VOLCANO) then
						TerrainBuilder.SetFeatureType(adjacentPlot,-1);
									end
					__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Turned the Mountain tile to a Hill");
								return true;
								end
					end
					
					if(terrainType == 9  and adjacentPlot:GetFeatureType() ~= g_FEATURE_MARSH) then
				-- Convert to Hills
							if(rng > limit_1) then
								TerrainBuilder.SetTerrainType(adjacentPlot,10);
								__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Turned the tile to a Tundra Hill");
								return true;
							end
					end		
							
					if((terrainType == 7 ) or (terrainType == 10 )) then
				-- copper
				--__Debug("Food balancing: Copper");
								if(ResourceBuilder.CanHaveResource(adjacentPlot, 2)) then
								ResourceBuilder.SetResourceType(adjacentPlot, 2, 1);
								TerrainBuilder.SetFeatureType(adjacentPlot,-1);
							__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Prod Balancing Y: ", adjacentPlot:GetY(), "Added: Copper");
							return true;
							end
					end
					if((terrainType == 9 or terrainType == 10) ) then
						-- Deer

							if(ResourceBuilder.CanHaveResource(adjacentPlot, 4)) then
								ResourceBuilder.SetResourceType(adjacentPlot, 4, 1);
							__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Prod Balancing Y: ", adjacentPlot:GetY(), "Added: Deer");
							return true;
							end
					end			
				end
				
				-- Water
				if(terrainType == 15 and adjacentPlot:GetFeatureType() == -1 and (adjacentPlot:GetResourceCount() < 1 or adjacentPlot:GetResourceType() == 5 ) ) then
					bWater = true;
					for j = 0, 5 do
					if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
						if(Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), j) ~= nil) then

							if(Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), j):IsWater() == false)	then
								bWater = false;
							end
							else
							bWater = false;	
						end
					end	
					end
					-- Small Island

					if(rng > limit_1 and bWater == true) then
                  print("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Island");
                  TerrainBuilder.SetTerrainType(adjacentPlot,1);
                  
                  local list = getRing(adjacentPlot:GetX(), adjacentPlot:GetY(), 1, mapXSize, mapXSize, mapIsRoundWestEast);
                  for _, element in ipairs(list) do
                     local x = element[1];
                     local y = element[2];
                     if (mapTerrainCode[x + 1][y + 1] == 16) then -- ocean
                        terraformBBS(x, y, 15, -2, -2)
                        print("---- Remove ocean around manually added island :", x, "Y:", y);
                     end
                  end
                  
                  return true;
					end

					elseif(terrainType == 15 and adjacentPlot:GetFeatureType() == -1 and adjacentPlot:IsFreshWater() == false and (adjacentPlot:GetResourceCount() < 1 or adjacentPlot:GetResourceType() == 5 )   ) then

					rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
					if(rng > limit_1 and adjacentPlot:GetResourceType() < 10) then 
					-- Reef

					__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Reef");
					TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_REEF);
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
					if(rng > limit_1 * 1.25 and adjacentPlot:GetResourceType() == -1) then 
						-- Reef with fish 
	
						__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Fish");
						ResourceBuilder.SetResourceType(adjacentPlot, 5, 1);
					end
					return true;
					end

					elseif(terrainType == 15 and adjacentPlot:GetFeatureType() == g_FEATURE_REEF and adjacentPlot:GetResourceType() == -1) then
					__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Fish");
					ResourceBuilder.SetResourceType(adjacentPlot, 5, 1);
					return true;
					
					else
				end	
				
			end
		end

		end	

	end -- k end loop


	__Debug("Prod balancing: Couldn't add Prod Bonus");
	return false;
end

------------------------------------------------------------------------------------------------------------------------------------------------

function AddHills(plot, intensity,flag)
	local iResourcesInDB = 0;
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local direction = 0;
	eResourceType	= {};
	eResourceClassType = {};
	aBonus = {};
	local limit_1 = 0;
	local limit_2 = 0;
	local limit = 0;
	local adjacentPlot = nil;
	local adjacentPlot2 = nil;
	local adjacentPlot3 = nil;
	local adjacentPlot4 = nil;
	local start_range = -1;
	local end_range = 17;
	local increment = 1;	

	if (intensity == 0) then
		limit_1 = 0.9;
		limit_2 = 0.75;
		elseif (intensity == 1) then
			limit_1 = 0.33;
			limit_2 = 0.20;
		elseif (intensity == 2) then
			limit_1 = 0.20;
			limit_2 = 0.10;
	end

	for k = 0, 1 do
	
	if k == 0 then	
		if (flag == 2 or flag == 1) then
			start_range = -1;
			end_range = 17;
			increment = 3;
			else
			start_range = -1;
			end_range = 17;
			increment = 3;
		end
	elseif k == 1 then
		if (flag == 2 or flag == 1) then
			start_range = 17;
			end_range = -1;
			increment = -1;
			else
			start_range = 17;
			end_range = -1;
			increment = -1;
		end
	end

	for i = start_range, end_range, increment do
		adjacentPlot = GetAdjacentTiles(plot, i);

		if (i < 6) then
			limit = limit_1
			else
			limit = limit_2
		end

		if (adjacentPlot ~= nil) then
			if adjacentPlot:IsNaturalWonder() == false and adjacentPlot:GetFeatureType() ~= g_FEATURE_FLOODPLAINS and adjacentPlot:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_PLAINS and adjacentPlot:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_GRASSLAND then
			terrainType = adjacentPlot:GetTerrainType();
			rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
			if(terrainType == 0 and adjacentPlot:GetResourceType() == -1 and adjacentPlot:GetFeatureType() ~= g_FEATURE_MARSH  ) then
				if(rng > limit) then
					TerrainBuilder.SetTerrainType(adjacentPlot,1);
					__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Turned the tile to a Grassland Hill");
					return true;
				end
			elseif(terrainType == 3 and adjacentPlot:GetResourceType() == -1  and adjacentPlot:GetFeatureType() ~= g_FEATURE_MARSH) then
				if(rng > limit) then
					TerrainBuilder.SetTerrainType(adjacentPlot,4);
					__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Turned the tile to a Plain Hill");
					return true;
				end
			elseif(terrainType == 6 and adjacentPlot:GetResourceType() == -1  and adjacentPlot:GetFeatureType() ~= g_FEATURE_MARSH and adjacentPlot:GetFeatureType() ~= g_FEATURE_OASIS) then
				if(rng > limit) then
					TerrainBuilder.SetTerrainType(adjacentPlot,7);
					__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Turned the tile to a Desert Hill");
					return true;
				end
			elseif(terrainType == 9 and adjacentPlot:GetResourceType() == -1  and adjacentPlot:GetFeatureType() ~= g_FEATURE_MARSH ) then
				if(rng > limit) then
					TerrainBuilder.SetTerrainType(adjacentPlot,10);
					__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Turned the tile to a Tundra Hill");
					return true;
				end
			elseif(adjacentPlot:GetResourceType() == -1 and adjacentPlot:GetFeatureType() == g_FEATURE_MARSH and (terrainType == 0 or terrainType == 3)) then
				if(rng > limit * 2) then
					TerrainBuilder.SetTerrainType(adjacentPlot,terrainType + 1);
					TerrainBuilder.SetFeatureType(adjacentPlot,-1);
					__Debug("Prod Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Turned the Marsh tile to a Hill");
					return true;
				end
			end


		end
		end
	end

	end -- end k loop

	__Debug("Hill balancing: Couldn't add Prod Bonus");
	return false;
end
------------------------------------------------------------------------------

function Terraforming_Nuke_Mountain(plot)
	-- flag = 0 normal
	-- flag = 1 tundra civ
	-- flag = 2 desert civ
	-- flag = 3 mountain civ
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local distance = 0;
	local min_distance = 99;
	local minimal_effort_i = nil;
	local adjacentPlot = nil;
	local adjacentPlot2 = nil;
	local adjacentPlot3 = nil;
	local adjacentPlot4 = nil;
	local limit = 0
	local limit_1 = 0.05
	local limit_2 = 0.2


	--------------------------------------------------------------------------------------------------------------
	-- Terraforming Nuke Mountain --------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------

	for i = -1, 17 do
		adjacentPlot = GetAdjacentTiles(plot, i);

		if (i < 6) then
			limit = limit_1
			else
			limit = limit_2
		end

		if (adjacentPlot ~=nil) then
			if ( (adjacentPlot:GetTerrainType() == 2 or adjacentPlot:GetTerrainType() == 5 or adjacentPlot:GetTerrainType() == 8 or adjacentPlot:GetTerrainType() == 11 or adjacentPlot:GetTerrainType() == 14) and adjacentPlot:GetFeatureType() ~= g_FEATURE_VOLCANO ) and adjacentPlot:IsNaturalWonder() == false then
				local rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
				if ( rng > limit ) then
					__Debug("Nuked Mountain X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Replaced a Mountain by a Hill");
					local tmp_terrain = adjacentPlot:GetTerrainType()
					--TerrainBuilder.SetTerrainType(adjacentPlot,tmp_terrain-1);
               terraformBBSPlot(adjacentPlot, tmp_terrain - 1, -2, -2);
				end
			end
		end

	end


end



------------------------------------------------------------------------------

function Terraforming_Mountain(plot,flag)
	-- flag = 0 normal
	-- flag = 1 tundra civ
	-- flag = 2 desert civ
	-- flag = 3 mountain civ
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local distance = 0;
	local min_distance = 99;
	local minimal_effort_i = nil;
	local adjacentPlot = nil;
	local adjacentPlot2 = nil;
	local adjacentPlot3 = nil;
	local adjacentPlot4 = nil;
	local rng = 0
	local count = 0


	--------------------------------------------------------------------------------------------------------------
	-- Terraforming Mountain -------------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------
	if flag == 3 then
		for i = 1, 60 do
			if (GetAdjacentTiles(plot, i) ~= nil) then
				rng = TerrainBuilder.GetRandomNumber(100,"test")/100
				adjacentPlot = GetAdjacentTiles(plot, i)
				if (adjacentPlot:IsImpassable() == false 
					and adjacentPlot:IsWater() == false
					and adjacentPlot:IsNaturalWonder() == false
					and adjacentPlot:GetResourceCount() < 1
					and adjacentPlot:GetFeatureType() ~= g_FEATURE_FLOODPLAINS 
					and adjacentPlot:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_GRASSLAND
					and adjacentPlot:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_PLAINS
					and rng < 0.30
					and count < 6) then
					
					if adjacentPlot:GetTerrainType() == 0 or adjacentPlot:GetTerrainType() == 1 then
						--TerrainBuilder.SetTerrainType(adjacentPlot,2)
                  terraformBBSPlot(adjacentPlot, 2, -2, -2);
               elseif adjacentPlot:GetTerrainType() == 3 or adjacentPlot:GetTerrainType() == 4 then
						--TerrainBuilder.SetTerrainType(adjacentPlot,5)
                  terraformBBSPlot(adjacentPlot, 5, -2, -2);
					end
					--TerrainBuilder.SetFeatureType(adjacentPlot,-1)
               terraformBBSPlot(adjacentPlot, -2, -2, -1);
					count = count + 1
					__Debug("Terraforming_Mountain X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Place a Mountain (Inca)");
				end
			end
		end
	end

	if flag == 3 then
		return
	end


	count = 0
	for i = 0, 5 do
		if (GetAdjacentTiles(plot, i) ~= nil) then
			if ( GetAdjacentTiles(plot, i):IsImpassable() == true ) and GetAdjacentTiles(plot, i):IsNaturalWonder() == false then
				-- immediate wall
				__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "Analysing the plot");
				if (i == 0) then
					if ( GetAdjacentTiles(plot, 5) ~= nil and GetAdjacentTiles(plot, i+1) ~= nil ) then
						if ( GetAdjacentTiles(plot, 5):IsImpassable() == true and GetAdjacentTiles(plot, i+1):IsImpassable() == true ) then
							-- Walled-in is there actual terrain on the other side ?
							if ( GetAdjacentTiles(plot, 5*i+60) ~= nil ) then
								if ( GetAdjacentTiles(plot, 5*i+60):IsImpassable() == false and GetAdjacentTiles(plot, 5*i+60):IsWater() == false  ) then
									-- Ok there is land let measure the distance to dig through
									if ( GetAdjacentTiles(plot, 2*i+6) ~= nil and GetAdjacentTiles(plot, 3*i+18) ~= nil and GetAdjacentTiles(plot, 4*i+36) ~= nil) then
										if ( GetAdjacentTiles(plot, 2*i+6):IsImpassable() == true) then
											distance = 2;
											else
											distance = 1;
										end
										if ( GetAdjacentTiles(plot, 3*i+18):IsImpassable() == true) then
											distance = distance + 1;
										end
										if ( GetAdjacentTiles(plot, 4*i+36):IsImpassable() == true) then
											distance = distance + 1;
										end
										__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "Distance to dig is", distance);
										if (distance < min_distance) then
											min_distance = distance;
											minimal_effort_i = i;
										end
									end
									else
									__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "No good Terrain on the other side");
								end
								else
								__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "No Terrain on the other side");
							end
							else
							__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "Can move around the Mountain");
						end
					end
					elseif (i>0 and i <5) then
					if ( GetAdjacentTiles(plot, i-1) ~= nil and GetAdjacentTiles(plot, i+1) ~= nil ) then
						if ( GetAdjacentTiles(plot, i-1):IsImpassable() == true and GetAdjacentTiles(plot, i+1):IsImpassable() == true ) then
							-- Walled-in is there actual terrain on the other side ?
							if ( GetAdjacentTiles(plot, 5*i+60) ~= nil ) then
								if ( GetAdjacentTiles(plot, 5*i+60):IsImpassable() == false and GetAdjacentTiles(plot, 5*i+60):IsWater() == false  ) then
									-- Ok there is land let measure the distance to dig through
									if ( GetAdjacentTiles(plot, 2*i+6) ~= nil and GetAdjacentTiles(plot, 3*i+18) ~= nil and GetAdjacentTiles(plot, 4*i+36) ~= nil) then
										if ( GetAdjacentTiles(plot, 2*i+6):IsImpassable() == true) then
											distance = 2;
											else
											distance = 1;
										end
										if ( GetAdjacentTiles(plot, 3*i+18):IsImpassable() == true) then
											distance = distance + 1;
										end
										if ( GetAdjacentTiles(plot, 4*i+36):IsImpassable() == true) then
											distance = distance + 1;
										end
										__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "Distance to dig is", distance);
										if (distance < min_distance) then
											min_distance = distance;
											minimal_effort_i = i;
										end
									end
									else
									__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "No good Terrain on the other side");
								end
								else
								__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "No Terrain on the other side");
							end
							else
							__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "Can move around the Mountain");
						end
					end
					elseif (i == 5) then
					if ( GetAdjacentTiles(plot, i-1) ~= nil and GetAdjacentTiles(plot, 0) ~= nil ) then
						if ( GetAdjacentTiles(plot, i-1):IsImpassable() == true and GetAdjacentTiles(plot, 0):IsImpassable() == true ) then
							-- Walled-in is there actual terrain on the other side ?
							if ( GetAdjacentTiles(plot, 5*i+60) ~= nil ) then
								if ( GetAdjacentTiles(plot, 5*i+60):IsImpassable() == false and GetAdjacentTiles(plot, 5*i+60):IsWater() == false  ) then
									-- Ok there is land let measure the distance to dig through
									if ( GetAdjacentTiles(plot, 2*i+6) ~= nil and GetAdjacentTiles(plot, 3*i+18) ~= nil and GetAdjacentTiles(plot, 4*i+36) ~= nil) then
										if ( GetAdjacentTiles(plot, 2*i+6):IsImpassable() == true) then
											distance = 2;
											else
											distance = 1;
										end
										if ( GetAdjacentTiles(plot, 3*i+18):IsImpassable() == true) then
											distance = distance + 1;
										end
										if ( GetAdjacentTiles(plot, 4*i+36):IsImpassable() == true) then
											distance = distance + 1;
										end
										__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "Distance to dig is", distance);
										if (distance < min_distance) then
											min_distance = distance;
											minimal_effort_i = i;
										end
									end
									else
									__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "No good Terrain on the other side");
								end
								else
								__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "No Terrain on the other side");
							end
							else
							__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "Can move around the Mountain");
						end
					end
				end
				else
				-- one tile away wall
				if (GetAdjacentTiles(plot, 2*i+6) ~= nil) then
					__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, 2*i+6):GetX(), "Y: ", GetAdjacentTiles(plot, 2*i+6):GetY(), "Analysing the plot");
					if ( GetAdjacentTiles(plot, 2*i+6):IsImpassable() == true ) then
						if (i == 0) then
							if ( GetAdjacentTiles(plot, 17) ~= nil and GetAdjacentTiles(plot, 2*i+6+1) ~= nil ) then
								if ( GetAdjacentTiles(plot, 17):IsImpassable() == true and GetAdjacentTiles(plot, 2*i+1+6):IsImpassable() == true ) then
								-- Walled-in is there actual terrain on the other side ?
									if ( GetAdjacentTiles(plot, 5*i+60) ~= nil ) then
										if ( GetAdjacentTiles(plot, 5*i+60):IsImpassable() == false and GetAdjacentTiles(plot, 5*i+60):IsWater() == false  ) then
										-- Ok there is land let measure the distance to dig through
											if ( GetAdjacentTiles(plot, 3*i+18) ~= nil and GetAdjacentTiles(plot, 4*i+36) ~= nil) then
												if ( GetAdjacentTiles(plot, 3*i+18):IsImpassable() == true) then
													distance = 1;
													else
													distance = 0;
												end
												if ( GetAdjacentTiles(plot, 4*i+36):IsImpassable() == true) then
													distance = distance + 1;
												end
												__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "Distance to dig is", distance)
												if (distance < min_distance) then
													min_distance = distance;
													minimal_effort_i = i;
												end
											end
											else
											__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "No good Terrain on the other side");

										end
										else
										__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "No Terrain on the other side");
									end
									else
									__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, 2*i+6):GetX(), "Y: ", GetAdjacentTiles(plot, 2*i+6):GetY(), "Can move around the Mountain");
								end
							end
						elseif (i>0) then
							if ( GetAdjacentTiles(plot, 2*i+6-1) ~= nil and GetAdjacentTiles(plot, 2*i+1+6) ~= nil ) then
								if ( GetAdjacentTiles(plot, 2*i+6-1):IsImpassable() == true and GetAdjacentTiles(plot, 2*i+1+6):IsImpassable() == true ) then
								-- Walled-in is there actual terrain on the other side ?
									if ( GetAdjacentTiles(plot, 5*i+60) ~= nil ) then
										if ( GetAdjacentTiles(plot, 5*i+60):IsImpassable() == false and GetAdjacentTiles(plot, 5*i+60):IsWater() == false  ) then
										-- Ok there is land let measure the distance to dig through
											if ( GetAdjacentTiles(plot, 3*i+18) ~= nil and GetAdjacentTiles(plot, 4*i+36) ~= nil) then
												if ( GetAdjacentTiles(plot, 3*i+18):IsImpassable() == true) then
													distance = 1;
													else
													distance = 0;
												end
												if ( GetAdjacentTiles(plot, 4*i+36):IsImpassable() == true) then
													distance = distance + 1;
												end
												__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "Distance to dig is", distance)
												if (distance < min_distance) then
													min_distance = distance;
													minimal_effort_i = i;
												end
											end
											else
											__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "No good Terrain on the other side");

										end
										else
										__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, i):GetX(), "Y: ", GetAdjacentTiles(plot, i):GetY(), "No Terrain on the other side");
									end
									else
									__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, 2*i+6):GetX(), "Y: ", GetAdjacentTiles(plot, 2*i+6):GetY(), "Can move around the Mountain");
								end
							end
						end
					end

				end
			end	
		end
	end
	if (minimal_effort_i ~= nil) then
		__Debug("Terraforming_Mountain X: ", GetAdjacentTiles(plot, minimal_effort_i):GetX(), "Y: ", GetAdjacentTiles(plot, minimal_effort_i):GetY(), "Digging an openning");
		if (GetAdjacentTiles(plot, minimal_effort_i) ~= nil and GetAdjacentTiles(plot, 2*minimal_effort_i+6) ~= nil and GetAdjacentTiles(plot, 3*minimal_effort_i+18) ~= nil and GetAdjacentTiles(plot, 4*minimal_effort_i+36) ~= nil) then
			adjacentPlot = GetAdjacentTiles(plot, minimal_effort_i);
			adjacentPlot2 = GetAdjacentTiles(plot, 2*minimal_effort_i+6);
			adjacentPlot3 = GetAdjacentTiles(plot, 3*minimal_effort_i+18);
			adjacentPlot4 = GetAdjacentTiles(plot, 4*minimal_effort_i+36);
			if (adjacentPlot:IsImpassable() == true and adjacentPlot:GetFeatureType() ~= g_FEATURE_VOLCANO) then
            terraformBBSPlot(adjacentPlot, adjacentPlot:GetTerrainType()-1, -2, -1);
				--TerrainBuilder.SetTerrainType(adjacentPlot,adjacentPlot:GetTerrainType()-1)
				--TerrainBuilder.SetFeatureType(adjacentPlot,-1)
            
            
				if adjacentPlot:GetTerrainType() == 10 or adjacentPlot:GetTerrainType() == 13 or adjacentPlot:GetTerrainType() == 7 then
					--TerrainBuilder.SetTerrainType(adjacentPlot,4)
               terraformBBSPlot(adjacentPlot, 4, -2, -2)
				end
				rng = TerrainBuilder.GetRandomNumber(100,"test")/100
				if rng > 0.75 then
					--TerrainBuilder.SetFeatureType(adjacentPlot,3)
               terraformBBSPlot(adjacentPlot, -2, -2, 3)
				end
				__Debug("Terraforming_Mountain X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "turn Mountain into a Hill");
			end
			if (adjacentPlot2:IsImpassable() == true and adjacentPlot2:GetFeatureType() ~= g_FEATURE_VOLCANO) then
				--TerrainBuilder.SetTerrainType(adjacentPlot2,adjacentPlot2:GetTerrainType()-1)
				--TerrainBuilder.SetFeatureType(adjacentPlot2,-1)
            terraformBBSPlot(adjacentPlot2, adjacentPlot2:GetTerrainType() - 1 , -2, -1)
            
				if adjacentPlot2:GetTerrainType() == 10 or adjacentPlot2:GetTerrainType() == 13 or adjacentPlot2:GetTerrainType() == 7 then
					--TerrainBuilder.SetTerrainType(adjacentPlot2,4)
               terraformBBSPlot(adjacentPlot2, 4, -2, -2)
				end
				rng = TerrainBuilder.GetRandomNumber(100,"test")/100
				if rng > 0.75 then
					TerrainBuilder.SetFeatureType(adjacentPlot2,3)
               terraformBBSPlot(adjacentPlot2, -2, -2, 3)
				end
				__Debug("Terraforming_Mountain X: ", adjacentPlot2:GetX(), "Y: ", adjacentPlot2:GetY(), "turn Mountain into a Hill");
			end
			if (adjacentPlot3:IsImpassable() == true and adjacentPlot3:GetFeatureType() ~= g_FEATURE_VOLCANO) then
				--TerrainBuilder.SetTerrainType(adjacentPlot3,adjacentPlot3:GetTerrainType()-1)
				--TerrainBuilder.SetFeatureType(adjacentPlot3,-1)
            terraformBBSPlot(adjacentPlot3, adjacentPlot3:GetTerrainType() - 1 , -2, -1)
            
				if adjacentPlot3:GetTerrainType() == 10 or adjacentPlot3:GetTerrainType() == 13 or adjacentPlot3:GetTerrainType() == 7 then
					--TerrainBuilder.SetTerrainType(adjacentPlot3,4)
               terraformBBSPlot(adjacentPlot3, 4, -2, -2)
				end
				rng = TerrainBuilder.GetRandomNumber(100,"test")/100
				if rng > 0.75 then
					--TerrainBuilder.SetFeatureType(adjacentPlot3,3)
               terraformBBSPlot(adjacentPlot3, 3, -2, -2)
				end
				__Debug("Terraforming_Mountain X: ", adjacentPlot3:GetX(), "Y: ", adjacentPlot3:GetY(), "turn Mountain into a Hill");
			end
			if (adjacentPlot4:IsImpassable() == true and adjacentPlot4:GetFeatureType() ~= g_FEATURE_VOLCANO) then
				--TerrainBuilder.SetTerrainType(adjacentPlot4,adjacentPlot4:GetTerrainType()-1)
				--TerrainBuilder.SetFeatureType(adjacentPlot4,-1)
            terraformBBSPlot(adjacentPlot4, adjacentPlot4:GetTerrainType() - 1 , -2, -1)
            
				if adjacentPlot4:GetTerrainType() == 10 or adjacentPlot4:GetTerrainType() == 13 or adjacentPlot4:GetTerrainType() == 7 then
					--TerrainBuilder.SetTerrainType(adjacentPlot4,4)
               terraformBBSPlot(adjacentPlot4, 4, -2, -2)
				end
				rng = TerrainBuilder.GetRandomNumber(100,"test")/100
				if rng > 0.75 then
					--TerrainBuilder.SetFeatureType(adjacentPlot4,3)
               terraformBBSPlot(adjacentPlot4, -2, -2, 3)
				end
				__Debug("Terraforming_Mountain X: ", adjacentPlot4:GetX(), "Y: ", adjacentPlot4:GetY(), "turn Mountain into a Hill");
			end

		end
	end

end


------------------------------------------------------------------------------

function Terraforming_Polar_Start(plot)
	-- flag = 0 normal
	-- flag = 1 tundra civ
	-- flag = 2 desert civ
	-- flag = 3 mountain civ
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local ContinentNum = nil;
	local ContinentPlots = {};

	ContinentNum = plot:GetContinentType()
	ContinentPlots =  Map.GetContinentPlots(ContinentNum);
	__Debug("Terraforming Polar Continent",ContinentNum);

	--------------------------------------------------------------------------------------------------------------
	-- Terraforming Polar Start ----------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------
		
	for i, plot in ipairs(ContinentPlots) do
		if plot ~= nil then
			local pPlot = Map.GetPlotByIndex(plot)
			local terrainType = pPlot:GetTerrainType();
			local featureType = pPlot:GetFeatureType();

			-- Let Tundra warm to Plains

			if (terrainType == 9 or terrainType == 10 or terrainType == 11) and pPlot:IsNaturalWonder() == false then
				TerrainBuilder.SetTerrainType(pPlot,terrainType - 6);
				if (pPlot:GetResourceCount() > 0 ) then
					local resourceType = pPlot:GetResourceType();
					if (resourceType == 45) then
						-- Oil requires a Marsh to spawn on Plains
						--TerrainBuilder.SetFeatureType(pPlot,-1);
						--TerrainBuilder.SetFeatureType(pPlot,5);
                  terraformBBSPlot(pPlot, -2, -2, 5)
               elseif (resourceType == 16) then
						-- Fur requires a Wood to spawn on Plains
						--TerrainBuilder.SetFeatureType(pPlot,-1);
						--TerrainBuilder.SetFeatureType(pPlot,3);
                  terraformBBSPlot(pPlot, -2, -2, 3)
               elseif (resourceType == 26) then
						-- Silver cannot spawn on Plains
						--ResourceBuilder.SetResourceType(pPlot,-1);
						--TerrainBuilder.SetFeatureType(pPlot,3);
                  terraformBBSPlot(pPlot, -2, -1, 3)
               elseif (resourceType == 4) then
						-- Deer requires Wood
						--TerrainBuilder.SetFeatureType(pPlot,-1);
						--TerrainBuilder.SetFeatureType(pPlot,3);
                  terraformBBSPlot(pPlot, -2, -2, -1)
					end
				end
			end

			-- Let Snow warm to Tundra

			if (terrainType == 12 or terrainType == 13 or terrainType == 14) then
				--TerrainBuilder.SetTerrainType(pPlot,terrainType - 3);
            terraformBBSPlot(pPlot, terrainType - 3, -2, -2)
			end		
			
		end
	end

	-- Removing the Ice

	for i = 0, 90 do
		adjacentPlot = GetAdjacentTiles(plot, i)
		rng = TerrainBuilder.GetRandomNumber(100,"test")/100
		if (adjacentPlot ~= nil) then
			if (adjacentPlot:GetFeatureType() == 1 and rng > 0.1) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Removing Ice",i);
				--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
            terraformBBSPlot(adjacentPlot, -2, -2, -1)
			end
		end
	end

end

------------------------------------------------------------------------------

function Terraforming_Best_Refresh(majList,major_count,step,bHighRoll)
		if majList == nil then
			__Debug("Terraforming_Best_Refresh: Missing Table")
			return
		end
		if major_count == nil then
			__Debug("Terraforming_Best_Refresh: Missing Upper Bound")
			return
		end
		local output = {}
		-- Let's get the averages
		local avg_best_ring_1 = 0;
		local avg_best_ring_2 = 0;
		local max_best_tile_1 = 0;
		local max_best_tile_2 = 0;
		local max_best_tile_3 = 0;
		local max_best_tile_4 = 0;
		local	maori_sea = 6
		local	tundra_buff = 2.25
		local	desert_buff = 3		
		
		local best_civ_1 = nil
		local best_civ_2 = nil
		local best_civ_3 = nil
		local best_civ_4 = nil
		local maori_sea = 5
		local tundra_buff = 1.5
		local desert_buff = 2.5
		if bHighRoll == true then
			maori_sea = 6
			tundra_buff = 2.25
			desert_buff = 3		
		end
		
		count = 0;
		for i = 1, major_count do
			if (majList[i] == nil or majList[i].leader == "LEADER_SPECTATOR"  ) then
			
				count = count +1;
				
				else
				local startPlot = Map.GetPlot(majList[i].plotX, majList[i].plotY);
				local _tempEval = EvaluateStartingLocation(startPlot)
				majList[i].isBase22 = _tempEval[31];
				--	Ring 1
				majList[i].best_tile = _tempEval[24];
				majList[i].best_tile_2 = _tempEval[25];
				majList[i].best_tile_3 = _tempEval[36];
				-- Ring 2
				majList[i].best_tile_inner = _tempEval[28]; 
				majList[i].best_tile_inner_2 = _tempEval[29];
				majList[i].tundra_start = _tempEval[11];
				if (majList[i].civ == "CIVILIZATION_RUSSIA" or majList[i].civ == "CIVILIZATION_CANADA" ) and _tempEval[11] > 4 then
				-- Russia/Canada on Tundra
				--	Ring 1
				majList[i].best_tile = _tempEval[24]+tundra_buff;
				majList[i].best_tile_2 = _tempEval[25]+tundra_buff;
				majList[i].best_tile_3 = _tempEval[36]+tundra_buff;
				-- Ring 2
				majList[i].best_tile_inner = _tempEval[28]+tundra_buff; 
				majList[i].best_tile_inner_2 = _tempEval[29]+tundra_buff;
				end
				majList[i].desert_start = _tempEval[12];
				if (majList[i].civ == "CIVILIZATION_MALI" ) and _tempEval[12] > 4 then
				-- Mali on Desert
				--	Ring 1
				majList[i].best_tile = _tempEval[24]+desert_buff;
				majList[i].best_tile_2 = _tempEval[25]+desert_buff;
				majList[i].best_tile_3 = _tempEval[36]+desert_buff;
				-- Ring 2
				majList[i].best_tile_inner = _tempEval[28]+desert_buff; 
				majList[i].best_tile_inner_2 = _tempEval[29]+desert_buff;
				end				
				if (majList[i].civ == "CIVILIZATION_MAORI" ) and _tempEval[14] > 4 then
				-- Maori if on water
				--	Ring 1 like a 2:2
				majList[i].best_tile = maori_sea;
				majList[i].best_tile_2 = maori_sea;
				majList[i].best_tile_3 = maori_sea;
				-- Ring 2
				majList[i].best_tile_inner = maori_sea; 
				majList[i].best_tile_inner_2 = maori_sea;
				end
				majList[i].bestTiles1Ring1_index = _tempEval[32];
				majList[i].bestTiles1Ring2_index = _tempEval[33];
				majList[i].bestTiles2Ring1_index = _tempEval[34];
				majList[i].bestTiles2Ring2_index = _tempEval[35];
				majList[i].bestTiles1Ring3_index = _tempEval[37];			
				__Debug(majList[i].civ ,"S1-S2-S3-I1-I2:", majList[i].best_tile,"(",majList[i].bestTiles1Ring1_index,")",majList[i].best_tile_2,"(",majList[i].bestTiles1Ring2_index,")",majList[i].best_tile_3,"(",majList[i].bestTiles1Ring3_index,")",majList[i].best_tile_inner,"(",majList[i].bestTiles2Ring1_index,")",majList[i].best_tile_inner_2,"(",majList[i].bestTiles2Ring2_index,") - 2:2 Base?",majList[i].isBase22)
				-- Best yield first ring
				if majList[i].best_tile > max_best_tile_1 then
					max_best_tile_1 = majList[i].best_tile
					best_civ_1 = majList[i].leader
				end
				-- Best yield second ring
				if majList[i].best_tile_inner > max_best_tile_2 then
					max_best_tile_2 = majList[i].best_tile_inner
					best_civ_2 = majList[i].leader
				end
				-- Best 5 tiles and Base
				if (majList[i].best_tile + majList[i].best_tile_2 + majList[i].best_tile_3 + majList[i].best_tile_inner + majList[i].best_tile_inner_2 + majList[i].isBase22) > max_best_tile_3 then
					max_best_tile_3 = (majList[i].best_tile + majList[i].best_tile_2 + majList[i].best_tile_3 + majList[i].best_tile_inner + majList[i].best_tile_inner_2 + majList[i].isBase22)
					best_civ_3 = majList[i].leader
				end
				-- Best Score
				if (majList[i].best_tile + majList[i].best_tile_2 + majList[i].best_tile_3 + majList[i].best_tile_inner*0.9 + majList[i].best_tile_inner_2*0.9 + majList[i].isBase22) > max_best_tile_4 then
					max_best_tile_4 = (majList[i].best_tile + majList[i].best_tile_2 + majList[i].best_tile_3 + majList[i].best_tile_inner*0.9 + majList[i].best_tile_inner_2*0.9 + majList[i].isBase22)
					best_civ_4 = majList[i].leader
				end
				avg_best_ring_1  = avg_best_ring_1 + majList[i].best_tile  + majList[i].best_tile_2  + majList[i].best_tile_3 + majList[i].isBase22 ;
				avg_best_ring_2  = avg_best_ring_2 + majList[i].best_tile_inner  + majList[i].best_tile_inner_2 ;
			end

		end

		avg_best_ring_1  = avg_best_ring_1  / (major_count - count);
		avg_best_ring_2 = avg_best_ring_2 / (major_count - count);

		__Debug("Phase 4",step,": Average Ring 1:", avg_best_ring_1 ,"Average Ring 2:", avg_best_ring_2);
		__Debug("Best Ring 1 Tile:", max_best_tile_1,best_civ_1);
		__Debug("Best Ring 2 Tile:", max_best_tile_2,best_civ_2);
		__Debug("Best Raw Yields:", max_best_tile_3,best_civ_3);
		__Debug("Best Overall Score:", max_best_tile_4,best_civ_4);
		output = { max_best_tile_1,max_best_tile_2,max_best_tile_3,max_best_tile_4,avg_best_ring_1,avg_best_ring_2,majList}
		return output

end



------------------------------------------------------------------------------

function Terraforming_Best(plot, missing_amount, best_1ring, best_2ring, avg_ring1, avg_ring2,	onering1_yield, onering1_index, 	onering2_yield, onering2_index, 	onering3_yield, onering3_index, 	tworing1_yield, tworing1_index, tworing2_yield, tworing2_index, flag, highroll,highroll_round)
	-- flag = 0 normal
	-- flag = 1 tundra civ
	-- flag = 2 desert civ
	-- flag = 3 mountain civ
	-- flag = 4 floodplains civ
	local iResourcesInDB = 0;
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local direction = 0;
	local bTerraform = true;
	local temp_tile = 0;
	local best_tile = 0;
	local valid_target_1 = nil;
	local valid_target_2 = nil;
	local adjacentPlot = nil;
	local target_tiles = {};
	local rng = 0;
	local remaining_amount = missing_amount;
	local bbuff = false
	if highroll == nil then
		highroll = false
	end
	if highroll_round == nil then
		highroll_round = false
	end

	target_tiles[0] = {yield = onering3_yield, index = onering3_index, isValid = false};
	target_tiles[1] = {yield = onering2_yield, index = onering2_index, isValid = false};
	target_tiles[2] = {yield = onering1_yield, index = onering1_index, isValid = false};
	target_tiles[3] = {yield = tworing2_yield, index = tworing2_index, isValid = false};
	target_tiles[4] = {yield = tworing1_yield, index = tworing1_index, isValid = false};

	
	--------------------------------------------------------------------------------------------------------------
	-- Step: 0: Figuring out where to make changes	  ------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------
	if missing_amount > 0 then
		bbuff = true
	end
	
	
	local valid_count = 0
	local high_roll_count = 0
	for i = 0, 4 do
		__Debug("Terraforming Best X: Best i",i,target_tiles[i].index,target_tiles[i].yield)
		local pPlot = Map.GetPlotByIndex(target_tiles[i].index)
		if (target_tiles[i].yield < 5.5 or highroll == false or high_roll_count == 1) then
			if (pPlot:GetResourceCount() < 1 or (pPlot:GetResourceCount() > 0 and pPlot:GetResourceType() < 10 )) then
				target_tiles[i].isValid = true
				valid_count = valid_count + 1;
				else
				__Debug("Terraforming Best X: ", pPlot:GetX(), "Y: ", pPlot:GetY(), "Index",target_tiles[i].index,"Not Valid - Luxuries or Strategic");
				if target_tiles[i].yield > 5.5 then
					high_roll_count = 1
				end
			end
			else
			__Debug("Terraforming Best X: ", pPlot:GetX(), "Y: ", pPlot:GetY(), "Index",target_tiles[i].index,"Not Valid - High Roll",target_tiles[i].yield);
			high_roll_count = 1;
		end
	end
	
	table.sort (target_tiles, function(a, b) return a.yield > b.yield; end);
	--------------------------------------------------------------------------------------------------------------
	-- Step: 1: Rebalancing Best Plot: Adding  More Plots --------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------
	
	if valid_count < 5 then
		__Debug("Terraforming Best: Not Enough Valid Plots - Will Attempt to find new Tiles");
		local adjacentPlot
		for i = 0, 17 do
			if valid_count == 5 then
				break
			end
			adjacentPlot = GetAdjacentTiles(plot, i);
			if (adjacentPlot:GetResourceCount() < 1 or (adjacentPlot:GetResourceCount() > 0 and adjacentPlot:GetResourceType() < 10 ) ) then
				local alreadyListed = false
				for j = 0, 4 do
					if adjacentPlot:GetIndex() == target_tiles[j].index then
						alreadyListed = true
					end
				end
				if alreadyListed == false then
					for j = 0, 4 do
						if target_tiles[j].isValid == false then
							target_tiles[j].isValid = true
							target_tiles[j].index = adjacentPlot:GetIndex()
							valid_count = valid_count + 1
							__Debug("Terraforming Best: Not Enough Valid Plots - Add Plot X",adjacentPlot:GetX(),"Y:",adjacentPlot:GetY());
							break;
						end
					end				
				end
			end
		end
	end
	
	
	--------------------------------------------------------------------------------------------------------------
	-- Step: 2: Rebalancing Best Plot: First Ring    -------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------
	local correction_number = 0

	for i = 0, 2 do
		__Debug("Terraforming Best: ", i, remaining_amount);
		if remaining_amount < 0.75 then
			break
		end
		
		local pPlot = Map.GetPlotByIndex(target_tiles[i].index)

		if target_tiles[i].isValid == true then
		
			local target_yield = 0
			local placed_yield = 0
			local max_yield = best_1ring
			if correction_number > 0 then
				max_yield = avg_ring1 /3 +0.25
			end
			
			if (max_yield  - target_tiles[i].yield) > remaining_amount and (highroll_round == false) then
				target_yield = target_tiles[i].yield + remaining_amount;
				else
				target_yield = max_yield 
			end
			
			local target_plot_1 = pPlot

			__Debug("Terraforming Best i: ", i, "target_yield: ", target_yield, "target_tiles[i].yield",target_tiles[i].yield,"max_yield ",max_yield );	
				
			-- Grassland
			if ( target_plot_1:GetTerrainType() == 0 or target_plot_1:GetTerrainType() == 1 or (target_plot_1:GetTerrainType() == 2 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO) ) then
					
				--if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_GRASSLAND or ( target_plot_1:GetFeatureType() == g_FEATURE_FLOODPLAINS_GRASSLAND and flag ~= 4) ) then
            if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_GRASSLAND) then
				
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100	
					
					if (flag == 1 or flag == 2) then
						target_yield = math.min(target_yield,5.5)
					end
					
					
					if (target_yield >= 5.75 ) then
						-- Forested Hill with deer 
						TerrainBuilder.SetTerrainType(target_plot_1,1);
						TerrainBuilder.SetFeatureType(target_plot_1,-1);
						ResourceBuilder.SetResourceType(target_plot_1, -1);
						ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
						TerrainBuilder.SetFeatureType(target_plot_1,3);
						__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/3 Forested Deer Grassland Hill");
						placed_yield = 6.5

               elseif (target_yield < 5.75 and target_yield > 4.75) then
							
						if (rng >= 0.75) then
							-- Flat Deer Forest
							TerrainBuilder.SetTerrainType(target_plot_1,0);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Grassland Forest with Deers");
							placed_yield = 5
							
                  elseif (rng >= 0.45 and rng < 0.75) then
							-- Forested Hill
							TerrainBuilder.SetTerrainType(target_plot_1,1);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Forested Grassland Hill");
							placed_yield = 5
							
                  elseif (rng >= 0 and rng < 0.45) then
							-- Stone Hill
							TerrainBuilder.SetTerrainType(target_plot_1,1);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 8, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Stone Grassland Hill");
							placed_yield = 5
							
							
						end

               else -- yield below 4.75
						
						if (rng >= 0.5) then
							-- Hill with Sheep
							TerrainBuilder.SetTerrainType(target_plot_1,1);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 7, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 3/1 Sheep Grassland Hill");
							placed_yield = 4.5
						
                  else
							-- Copper Hill
							TerrainBuilder.SetTerrainType(target_plot_1,1);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 2, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/1/2 Copper Grassland Hill");
							placed_yield = 4.0
						end

					end -- close target if
						
            else -- Grassland with Floodplains
						
						-- floodplains and floodplains Civs
					if (target_plot_1:GetResourceCount() < 1) then
						ResourceBuilder.SetResourceType(target_plot_1, 6, 1)
						__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 3/0 Rice Grassland Floodplains");
						placed_yield = 3
					end
					
				end
				
				-- Plains
         elseif ( target_plot_1:GetTerrainType() == 3 or target_plot_1:GetTerrainType() == 4 or (target_plot_1:GetTerrainType() == 5 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO)) then
					
            --if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_PLAINS or ( target_plot_1:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS and flag ~= 4) ) then
            if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_PLAINS) then
               -- +5.5 on Plains		
               rng = TerrainBuilder.GetRandomNumber(100,"test")/100
               
               if (flag == 1 or flag == 2) then
                  target_yield = math.min(target_yield,5.5)
               end
               
               
               if (target_yield >= 5.75) then
                  
                  if (rng >= 0.9) then
                        -- Forested Hill with Deer
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        TerrainBuilder.SetFeatureType(target_plot_1,3);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/4 Forested Plain Hill with Deer");
                        placed_yield = 6
                        
                     
                        
                  elseif (rng >= 0 and rng < 0.90) then
                        -- Banana Jungle Hill
                     
                     if (target_plot_1:GetY() > gridHeight * 0.25 and target_plot_1:GetY() < gridHeight * 0.75) then
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 0, 1);
                        TerrainBuilder.SetFeatureType(target_plot_1,2);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 3/2 Jungle Plain Hill with Banana");
                        placed_yield = 6.5
                        
                     elseif rng > 0.75 then
                        -- Forested Plain Hill deer
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        TerrainBuilder.SetFeatureType(target_plot_1,3);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/4 Forested Plain Hill with Deer");
                        placed_yield = 6
                        
                     else
                        -- Sheep Plain Hill
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 7, 1)
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Plain Hill with Sheep");	
                        placed_yield = 5
                        
                     end
                  end


   
               elseif (target_yield < 5.75 and target_yield > 4.75) then
                     
                  if (rng >= 0.75) then
                        -- Hill with Sheep
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Sheep Plain Hill");
                        placed_yield = 5
                           
                  elseif (rng >= 0.0 and rng < 0.75) then
                        
                     if (target_plot_1:GetY() > gridHeight * 0.33 and target_plot_1:GetY() < gridHeight * 0.66) then
                        -- Jungle Plain Hill
                           TerrainBuilder.SetTerrainType(target_plot_1,4);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           TerrainBuilder.SetFeatureType(target_plot_1,2);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Jungle Plain Hill");
                           placed_yield = 5
                        else
                           -- Hill with Sheep
                           TerrainBuilder.SetTerrainType(target_plot_1,4);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Sheep Plain Hill");
                           placed_yield = 5
                     end
                  end						
                     
                  else -- yield < 4.75
                     
                     -- Banana Jungle Plain
                     if (target_plot_1:GetY() > gridHeight * 0.33 and target_plot_1:GetY() < gridHeight * 0.66) then
                           TerrainBuilder.SetTerrainType(target_plot_1,3);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           ResourceBuilder.SetResourceType(target_plot_1,0, 1);
                           TerrainBuilder.SetFeatureType(target_plot_1,2);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 3/1 Jungle Plain with Banana");
                           placed_yield = 4.5
                     else

                        if (rng >= 0.5) then 
                           -- Forested Plain With Deer
                           TerrainBuilder.SetTerrainType(target_plot_1,3);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           TerrainBuilder.SetFeatureType(target_plot_1,3);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           ResourceBuilder.SetResourceType(target_plot_1, 4, 1);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/3 Forested Plain with Deer");
                           placed_yield = 4.0
                        else
                           -- plain hill with forest
                           TerrainBuilder.SetTerrainType(target_plot_1,4);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           TerrainBuilder.SetFeatureType(target_plot_1,3);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/3 Plain hill with forest");
                           placed_yield = 4.0
                        end

                     end
                  end

                     
               -- close target
                  
            else
                  
                  -- floodplains and floodplains Civs
               if (target_plot_1:GetResourceCount() < 1 and target_plot_1:GetFeatureType() ~= g_FEATURE_OASIS) then
                     ResourceBuilder.SetResourceType(target_plot_1, 9, 1)
                     __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 3/0 Wheat Plains Floodplains");
               end
               placed_yield = 3	
                  
            end

				-- Desert
				elseif ( target_plot_1:GetTerrainType() == 6 or target_plot_1:GetTerrainType() == 7 or (target_plot_1:GetTerrainType() == 8 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO)) then
					
				if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS and target_plot_1:GetFeatureType() ~= g_FEATURE_OASIS) then
					-- on Desert -> impossible	
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100
					if (rng >= 0.5) then
							-- Hill with Sheep
							TerrainBuilder.SetTerrainType(target_plot_1,7);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/1 Sheep Desert Hill");
							placed_yield = 2.5
							if flag == 2 then
								placed_yield = placed_yield + 1
							end
						elseif (rng >= 0.0 and rng < 0.5) then
							-- Copper Hill
							TerrainBuilder.SetTerrainType(target_plot_1,7);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 2, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/0/2 Copper Desert Hill");
							placed_yield = 2
							if flag == 2 then
								placed_yield = placed_yield + 1
							end
					end
					else
						-- floodplains
					if (target_plot_1:GetResourceCount() < 1 and target_plot_1:GetFeatureType() ~= g_FEATURE_OASIS) then
							ResourceBuilder.SetResourceType(target_plot_1, 9, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/0 Wheat Desert Floodplains");
							placed_yield = 2
					end
				end
				-- Tundra
				elseif ( target_plot_1:GetTerrainType() == 9 or target_plot_1:GetTerrainType() == 10 or (target_plot_1:GetTerrainType() == 11 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO)) then
					
				if ( target_plot_1:GetFeatureType() ~= g_FEATURE_MARSH) then
					-- +5 on Tundra -> impossible	
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100
					if (rng >= 0.75) then
							-- Hill with Sheep
							TerrainBuilder.SetTerrainType(target_plot_1,10);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/1 Sheep Tundra Hill");
							placed_yield = 3.5
							if flag == 1 then
								placed_yield = 4.5
							end
						elseif (rng >= 0.5 and rng < 0.75) then
							-- Copper Hill
							TerrainBuilder.SetTerrainType(target_plot_1,10);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 2, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/1/2 Copper Tundra Hill");
							placed_yield = 3.5
							if flag == 1 then
								placed_yield = 4.5
							end
						elseif (rng >= 0.25 and rng < 0.5) then
							-- Forested Deer Hills
							TerrainBuilder.SetTerrainType(target_plot_1,10);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/3 Deer Tundra Hill");
							placed_yield = 4.5
							if flag == 1 then
								placed_yield = 6.5
							end
						elseif (rng >= 0.0 and rng < 0.25) then
							-- Forested Deer
							TerrainBuilder.SetTerrainType(target_plot_1,9);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/2 Deer Tundra ");
							placed_yield = 4
							if flag == 1 then
								placed_yield = 5
							end
					end
				end
				
				else
				
				placed_yield = target_tiles[i].yield
				__Debug("Terraforming Best Index: ", target_tiles[i].index, "X: ", pPlot:GetY(), "Y: ", pPlot:GetY(),"Index",target_tiles[i].index,"Couldn't Place Any Additional Yield");
			end

			local added_yield = placed_yield - target_tiles[i].yield
			__Debug("Terraforming Best Original Yield: ", target_tiles[i].yield, "Placed Yield ", placed_yield , "Remaining Before", remaining_amount, "After",remaining_amount - added_yield,"Index",target_tiles[i].index);
			remaining_amount = remaining_amount - added_yield
			if added_yield ~= 0 then
				correction_number = correction_number + 1
			end
			else
			
			__Debug("Terraforming Best Index: ", target_tiles[i].index, "X: ", pPlot:GetY(), "Y: ", pPlot:GetY(),"Invalid");
		end
	end
	
	--------------------------------------------------------------------------------------------------------------
	-- Step: 3: Rebalancing Best Plot: Second Ring    -------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------	
	if remaining_amount ~= 2 and highroll_round == true then
		return
	end

	correction_number = 0
	for i = 3, 4 do
		__Debug("Terraforming Best: ", i, remaining_amount);
		if remaining_amount < 0.75 then
			break
		end
		
		local pPlot = Map.GetPlotByIndex(target_tiles[i].index)

		if target_tiles[i].isValid == true then
		
			local target_yield = 0
			local placed_yield = 0
			local max_yield = math.max(best_1ring,best_2ring)
			if correction_number > 0 then
				max_yield = avg_ring2 /2 + 0.25
			end
			
			if (max_yield  - target_tiles[i].yield) > remaining_amount and (highroll_round == false) then
				target_yield = target_tiles[i].yield + remaining_amount;
				else
				target_yield = max_yield 
			end
			
			local target_plot_1 = pPlot

				
				
				-- Grassland
			if ( target_plot_1:GetTerrainType() == 0 or target_plot_1:GetTerrainType() == 1 or (target_plot_1:GetTerrainType() == 2 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO) ) then
					
				--if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_GRASSLAND or ( target_plot_1:GetFeatureType() == g_FEATURE_FLOODPLAINS_GRASSLAND and flag ~= 4) ) then
            
            if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_GRASSLAND) then
				
					if (flag == 1 or flag == 2) then
						target_yield = math.min(target_yield,5.5)
					end
				
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100	
					
					if (target_yield >= 5.75 ) then
						-- Forested Hill with deer 
						TerrainBuilder.SetTerrainType(target_plot_1,1);
						TerrainBuilder.SetFeatureType(target_plot_1,-1);
						ResourceBuilder.SetResourceType(target_plot_1, -1);
						ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
						TerrainBuilder.SetFeatureType(target_plot_1,3);
						__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/3 Forested Deer Grassland Hill");
						placed_yield = 6.5

						elseif (target_yield < 5.75 and target_yield > 4.75) then
							
						if (rng >= 0.75) then
							-- Flat Deer Forest
							TerrainBuilder.SetTerrainType(target_plot_1,0);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Grassland Forest with Deers");
							placed_yield = 5
							
                  elseif (rng >= 0.45 and rng < 0.75) then
							-- Forested Hill
							TerrainBuilder.SetTerrainType(target_plot_1,1);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Forested Grassland Hill");
							placed_yield = 5
							
                  elseif (rng >= 0 and rng < 0.45) then
							-- Stone Hill
							TerrainBuilder.SetTerrainType(target_plot_1,1);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 8, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Stone Grassland Hill");
							placed_yield = 5
							
							
						end

						else -- yield below 4.75
						
						if (rng >= 0.5) then
							-- Hill with Sheep
							TerrainBuilder.SetTerrainType(target_plot_1,1);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 7, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 3/1 Sheep Grassland Hill");
							placed_yield = 4.5
						
							else
							-- Copper Hill
							TerrainBuilder.SetTerrainType(target_plot_1,1);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 2, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/1/2 Copper Grassland Hill");
							placed_yield = 4.0
						end

					end -- close target if
						
					else -- Grassland with Floodplains
						
						-- floodplains and floodplains Civs
					if (target_plot_1:GetResourceCount() < 1) then
						ResourceBuilder.SetResourceType(target_plot_1, 6, 1)
						__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 3/0 Rice Grassland Floodplains");
						placed_yield = 3
					end
					
				end
				
				-- Plains
				elseif ( target_plot_1:GetTerrainType() == 3 or target_plot_1:GetTerrainType() == 4 or (target_plot_1:GetTerrainType() == 5 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO)) then
					
				--if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_PLAINS or ( target_plot_1:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS and flag ~= 4) ) then
            
            if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_PLAINS) then
               -- +5.5 on Plains		
               rng = TerrainBuilder.GetRandomNumber(100,"test")/100
               
               if (flag == 1 or flag == 2) then
                  target_yield = math.min(target_yield,5.5)
               end
               
               
               if (target_yield >= 5.75) then
                  
                  if (rng >= 0.9) then
                     -- Forested Hill with Deer
                     TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                     TerrainBuilder.SetFeatureType(target_plot_1,3);
                     ResourceBuilder.SetResourceType(target_plot_1, -1);
                     ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
                     __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/4 Forested Plain Hill with Deer");
                     placed_yield = 6
                        
                     
                        
                  elseif (rng >= 0 and rng < 0.90) then
                        -- Banana Jungle Hill
                     
                     if (target_plot_1:GetY() > gridHeight * 0.25 and target_plot_1:GetY() < gridHeight * 0.75) then
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 0, 1);
                        TerrainBuilder.SetFeatureType(target_plot_1,2);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 3/2 Jungle Plain Hill with Banana");
                        placed_yield = 6.5
                        
                     elseif rng > 0.75 then
                        -- Forested Plain Hill deer
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        TerrainBuilder.SetFeatureType(target_plot_1,3);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/4 Forested Plain Hill with Deer");
                        placed_yield = 6
                        
                     else
                        -- Sheep Plain Hill
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 7, 1)
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Plain Hill with Sheep");	
                        placed_yield = 5
                        
                     end
                  end


   
               elseif (target_yield < 5.75 and target_yield > 4.75) then
                     
                  if (rng >= 0.75) then
                        -- Hill with Sheep
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Sheep Plain Hill");
                        placed_yield = 5
                           
                  elseif (rng >= 0.0 and rng < 0.75) then
                        
                     if (target_plot_1:GetY() > gridHeight * 0.33 and target_plot_1:GetY() < gridHeight * 0.66) then
                        -- Jungle Plain Hill
                           TerrainBuilder.SetTerrainType(target_plot_1,4);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           TerrainBuilder.SetFeatureType(target_plot_1,2);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Jungle Plain Hill");
                           placed_yield = 5
                        else
                           -- Hill with Sheep
                           TerrainBuilder.SetTerrainType(target_plot_1,4);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/2 Sheep Plain Hill");
                           placed_yield = 5
                     end
                  end						
                     
                  else -- yield < 4.75
                     
                     -- Banana Jungle Plain
                     if (target_plot_1:GetY() > gridHeight * 0.33 and target_plot_1:GetY() < gridHeight * 0.66) then
                        TerrainBuilder.SetTerrainType(target_plot_1,3);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1,0, 1);
                        TerrainBuilder.SetFeatureType(target_plot_1,2);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 3/1 Jungle Plain with Banana");
                        placed_yield = 4.5
                     else
                        if (rng >= 0.5) then 
                           -- Forested Plain With Deer
                           TerrainBuilder.SetTerrainType(target_plot_1,3);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           TerrainBuilder.SetFeatureType(target_plot_1,3);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           ResourceBuilder.SetResourceType(target_plot_1, 4, 1);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/3 Forested Plain with Deer");
                           placed_yield = 4.0
                        else
                           -- plain hill with forest
                           TerrainBuilder.SetTerrainType(target_plot_1,4);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           TerrainBuilder.SetFeatureType(target_plot_1,3);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/3 Plain hill with forest");
                           placed_yield = 4.0
                        end

                     end
                  end

                     
               -- close target
                  
            else
                  
                  -- floodplains and floodplains Civs
               if (target_plot_1:GetResourceCount() < 1 and target_plot_1:GetFeatureType() ~= g_FEATURE_OASIS) then
                     ResourceBuilder.SetResourceType(target_plot_1, 9, 1)
                     __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 3/0 Wheat Plains Floodplains");
               end
               placed_yield = 3	
                  
            end

				-- Desert
				elseif ( target_plot_1:GetTerrainType() == 6 or target_plot_1:GetTerrainType() == 7 or (target_plot_1:GetTerrainType() == 8 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO)) then
					
				if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS and target_plot_1:GetFeatureType() ~= g_FEATURE_OASIS) then
					-- on Desert -> impossible	
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100
					if (rng >= 0.5) then
							-- Hill with Sheep
							TerrainBuilder.SetTerrainType(target_plot_1,7);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/1 Sheep Desert Hill");
							placed_yield = 2.5
							if flag == 2 then
								placed_yield = placed_yield + 1
							end
						elseif (rng >= 0.0 and rng < 0.5) then
							-- Copper Hill
							TerrainBuilder.SetTerrainType(target_plot_1,7);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 2, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/0/2 Copper Desert Hill");
							placed_yield = 2
							if flag == 2 then
								placed_yield = placed_yield + 1
							end
					end
					else
						-- floodplains
					if (target_plot_1:GetResourceCount() < 1 and target_plot_1:GetFeatureType() ~= g_FEATURE_OASIS) then
							ResourceBuilder.SetResourceType(target_plot_1, 9, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/0 Wheat Desert Floodplains");
							placed_yield = 2
					end
				end
				-- Tundra
				elseif ( target_plot_1:GetTerrainType() == 9 or target_plot_1:GetTerrainType() == 10 or (target_plot_1:GetTerrainType() == 11 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO)) then
					
				if ( target_plot_1:GetFeatureType() ~= g_FEATURE_MARSH) then
					-- +5 on Tundra -> impossible	
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100
					if (rng >= 0.75) then
							-- Hill with Sheep
							TerrainBuilder.SetTerrainType(target_plot_1,10);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 2/1 Sheep Tundra Hill");
							placed_yield = 3.5
							if flag == 1 then
								placed_yield = 4.5
							end
						elseif (rng >= 0.5 and rng < 0.75) then
							-- Copper Hill
							TerrainBuilder.SetTerrainType(target_plot_1,10);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 2, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/1/2 Copper Tundra Hill");
							placed_yield = 3.5
							if flag == 1 then
								placed_yield = 4.5
							end
						elseif (rng >= 0.25 and rng < 0.5) then
							-- Forested Deer Hills
							TerrainBuilder.SetTerrainType(target_plot_1,10);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/3 Deer Tundra Hill");
							placed_yield = 4.5
							if flag == 1 then
								placed_yield = 6.5
							end
						elseif (rng >= 0.0 and rng < 0.25) then
							-- Forested Deer
							TerrainBuilder.SetTerrainType(target_plot_1,9);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Added 1/2 Deer Tundra ");
							placed_yield = 4
							if flag == 1 then
								placed_yield = 5
							end
					end
				end
				
				else
				
				placed_yield = target_tiles[i].yield
				__Debug("Terraforming Best Index: ", target_tiles[i].index, "X: ", pPlot:GetY(), "Y: ", pPlot:GetY(),"Index",target_tiles[i].index,"Couldn't Place Any Additional Yield");
			end
			
			local added_yield = placed_yield - target_tiles[i].yield
			__Debug("Terraforming Best Original Yield: ", target_tiles[i].yield, "Placed Yield ", placed_yield , "Remaining Before", remaining_amount, "After",remaining_amount - added_yield,"Index",target_tiles[i].index);
			remaining_amount = remaining_amount - added_yield
			if added_yield ~= 0 then
				correction_number = correction_number + 1
			end
			else
			
			__Debug("Terraforming Best Index: ", target_tiles[i].index, "X: ", pPlot:GetY(), "Y: ", pPlot:GetY(),"Invalid");
		end
	end

	__Debug("Terraforming Best Remaining Amount to Allocate: ", remaining_amount);
	
	if remaining_amount > 1 then
		AddLuxuryStarting(plot,"food")
	end
	
	if remaining_amount > -1 or bbuff == true or highroll_round == true then
		return
	end
	
	--------------------------------------------------------------------------------------------------------------
	-- Step: 4: Rebalancing Best Plot: Nerfing    -------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------	
	
	if plot:GetTerrainType() == 4 then
		TerrainBuilder.SetTerrainType(plot,3);
		__Debug("Terraforming Best X: ", plot:GetX(), "Y: ", plot:GetY(), "Removed Plain Hills Start");
		remaining_amount = remaining_amount + 1.5	
	end

	if remaining_amount > -1 then
		return
	end

	for i = 0, 2 do
		__Debug("Terraforming Best: ", i, remaining_amount);
		if remaining_amount > -1 then
			break
		end
		
		local pPlot = Map.GetPlotByIndex(target_tiles[i].index)

		if target_tiles[i].isValid == true  then
		
			
			local target_yield = 0
			local placed_yield = 0
			
			if  target_tiles[i].yield > 5.25 then
				if remaining_amount < -2 then
					target_yield = 4.5
					else
					target_yield = 5
				end
				elseif target_tiles[i].yield > 4.5 then
				if remaining_amount < -1.5 then
					target_yield = 4
					else
					target_yield = 4.5
				end
				else
				target_yield = -1
			end
			
			local target_plot_1 = pPlot

				
				
			-- Grassland
			if target_yield ~= -1 then
			if ( target_plot_1:GetTerrainType() == 0 or target_plot_1:GetTerrainType() == 1 or (target_plot_1:GetTerrainType() == 2 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO) ) then
					
				--if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_GRASSLAND or ( target_plot_1:GetFeatureType() == g_FEATURE_FLOODPLAINS_GRASSLAND and flag ~= 4) ) then
            
            if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_GRASSLAND) then
				
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100	
					
					if (target_yield < 5.75 and target_yield > 4.75) then
							
						if (rng >= 0.70) then
							-- Flat Deer Forest
							TerrainBuilder.SetTerrainType(target_plot_1,0);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/2 Grassland Forest with Deers");
							placed_yield = 5
							
                  elseif (rng >= 0.35 and rng < 0.70) then
							-- Forested Hill
							TerrainBuilder.SetTerrainType(target_plot_1,1);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/2 Forested Grassland Hill");
							placed_yield = 5
							
                  else
							-- Stone Hill
							TerrainBuilder.SetTerrainType(target_plot_1,1);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 8, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/2 Stone Grassland Hill");
							placed_yield = 5
							
							
						end

               elseif target_yield > 4.25 then -- yield below 4.75
						
                  if (rng >= 0.0 and rng < 0.80) then
                     -- Hill with Sheep
                     TerrainBuilder.SetTerrainType(target_plot_1,1);
                     TerrainBuilder.SetFeatureType(target_plot_1,-1);
                     ResourceBuilder.SetResourceType(target_plot_1, -1);
                     ResourceBuilder.SetResourceType(target_plot_1, 7, 1)
                     __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 3/1 Sheep Grassland Hill");
                     placed_yield = 4.5
                  
                  else
                     -- Copper Hill
                     TerrainBuilder.SetTerrainType(target_plot_1,1);
                     TerrainBuilder.SetFeatureType(target_plot_1,-1);
                     ResourceBuilder.SetResourceType(target_plot_1, -1);
                     ResourceBuilder.SetResourceType(target_plot_1, 2, 1)
                     __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/1/2 Copper Grassland Hill");
                     placed_yield = 4
                  end
						
               else
						
						TerrainBuilder.SetTerrainType(target_plot_1,1);
						TerrainBuilder.SetFeatureType(target_plot_1,-1);
						ResourceBuilder.SetResourceType(target_plot_1, -1);
						__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/1 Grassland Hill");
						placed_yield = 3.5						

					end -- close target if
						
            else -- Grassland with Floodplains
						
						-- floodplains and floodplains Civs
					if (target_plot_1:GetResourceCount() < 1) then
						ResourceBuilder.SetResourceType(target_plot_1, 6, 1)
						__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 3/0 Rice Grassland Floodplains");
						placed_yield = 3
					end
					
				end
				
				-- Plains
				elseif ( target_plot_1:GetTerrainType() == 3 or target_plot_1:GetTerrainType() == 4 or (target_plot_1:GetTerrainType() == 5 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO)) then
					
				--if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_PLAINS or ( target_plot_1:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS and flag ~= 4) ) then
            
            if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_PLAINS) then
            
					-- +5.5 on Plains		
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100
					
					if (target_yield < 5.25 and target_yield > 4.75) then
							
						if (rng >= 0.50) then
								-- Hill with Sheep
								TerrainBuilder.SetTerrainType(target_plot_1,4);
								TerrainBuilder.SetFeatureType(target_plot_1,-1);
								ResourceBuilder.SetResourceType(target_plot_1, -1);
								ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
								__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/2 Sheep Plain Hill");
								placed_yield = 5

                  else
								
							if (target_plot_1:GetY() > gridHeight * 0.33 and target_plot_1:GetY() < gridHeight * 0.66) then
								-- Jungle Plain Hill
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        TerrainBuilder.SetFeatureType(target_plot_1,2);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/2 Jungle Plain Hill");
                        placed_yield = 5
                     else
                        -- Hill with Sheep
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/2 Sheep Plain Hill");
                        placed_yield = 5
							end
						end						
							
						elseif target_yield > 4.25 then -- yield < 4.75
							
							-- Banana Jungle Hill
                     if (target_plot_1:GetY() > gridHeight * 0.33 and target_plot_1:GetY() < gridHeight * 0.66) then
                        TerrainBuilder.SetTerrainType(target_plot_1,3);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1,0, 1);
                        TerrainBuilder.SetFeatureType(target_plot_1,2);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 3/1 Jungle Plain with Banana");
                        placed_yield = 4.5
                     else
                     
                        if (rng >= 0.50) then
                           -- Forested Plain with deers
                           TerrainBuilder.SetTerrainType(target_plot_1,3);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           TerrainBuilder.SetFeatureType(target_plot_1,3);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           ResourceBuilder.SetResourceType(target_plot_1, 4, 1);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/3 Forested Plain with Deer");
                           placed_yield = 4
                        else
                           -- Forested Plain hill
                           TerrainBuilder.SetTerrainType(target_plot_1,4);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           TerrainBuilder.SetFeatureType(target_plot_1,3);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/3 Forested Plain Hill");
                           placed_yield = 4
                        end

                     end
						
						elseif target_yield > 3.75 then
                  
                     if (rng >= 0.50) then
                        -- Forested Plain with deers
                        TerrainBuilder.SetTerrainType(target_plot_1,3);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        TerrainBuilder.SetFeatureType(target_plot_1,3);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 4, 1);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/3 Forested Plain with Deer");
                        placed_yield = 4
                     else
                        -- Forested Plain hill
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        TerrainBuilder.SetFeatureType(target_plot_1,3);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/3 Forested Plain Hill");
                        placed_yield = 4
                     end

                  else
                     -- Plain Hill
                     TerrainBuilder.SetTerrainType(target_plot_1,4);
                     TerrainBuilder.SetFeatureType(target_plot_1,-1);
                     ResourceBuilder.SetResourceType(target_plot_1, -1);
                     __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/2 Plain Hills");
                     placed_yield = 3


							
					end -- close target
						
					else
						
						-- floodplains and floodplains Civs
					if (target_plot_1:GetResourceCount() < 1 and target_plot_1:GetFeatureType() ~= g_FEATURE_OASIS) then
							ResourceBuilder.SetResourceType(target_plot_1, 9, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 3/0 Wheat Plains Floodplains");
					end
					placed_yield = 3	
						
				end

				-- Desert
				elseif ( target_plot_1:GetTerrainType() == 6 or target_plot_1:GetTerrainType() == 7 or (target_plot_1:GetTerrainType() == 8 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO)) then
					
				if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS and target_plot_1:GetFeatureType() ~= g_FEATURE_OASIS) then
					-- on Desert -> impossible	
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100
					if (rng >= 0.5) then
							-- Hill with Sheep
							TerrainBuilder.SetTerrainType(target_plot_1,7);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/1 Sheep Desert Hill");
							placed_yield = 2.5
														if flag == 2 then
								placed_yield = placed_yield + 1
							end
						elseif (rng >= 0.0 and rng < 0.5) then
							-- Copper Hill
							TerrainBuilder.SetTerrainType(target_plot_1,7);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 2, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/0/2 Copper Desert Hill");
							placed_yield = 2
														if flag == 2 then
								placed_yield = placed_yield + 1
							end
					end
					else
						-- floodplains
					if (target_plot_1:GetResourceCount() < 1 and target_plot_1:GetFeatureType() ~= g_FEATURE_OASIS) then
							ResourceBuilder.SetResourceType(target_plot_1, 9, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/0 Wheat Desert Floodplains");
							placed_yield = 2
														if flag == 2 then
								placed_yield = placed_yield + 1
							end
					end
				end
				-- Tundra
				elseif ( target_plot_1:GetTerrainType() == 9 or target_plot_1:GetTerrainType() == 10 or (target_plot_1:GetTerrainType() == 11 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO)) then
					
				if ( target_plot_1:GetFeatureType() ~= g_FEATURE_MARSH) then
					-- +5 on Tundra -> impossible	
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100
					if (rng >= 0.75) then
							-- Hill with Sheep
							TerrainBuilder.SetTerrainType(target_plot_1,10);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/1 Sheep Tundra Hill");
							placed_yield = 2.5
						elseif (rng >= 0.5 and rng < 0.75) then
							-- Copper Hill
							TerrainBuilder.SetTerrainType(target_plot_1,10);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 2, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/0/2 Copper Tundra Hill");
							placed_yield = 2
						elseif (rng >= 0.0 and rng < 0.5) then
							-- Forested Deer
							TerrainBuilder.SetTerrainType(target_plot_1,10);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/0/2 Deer Tundra Hill");
							placed_yield = 2
					end
				end
			
				else
				
				placed_yield = target_tiles[i].yield
				__Debug("Terraforming Best Index: ", target_tiles[i].index, "X: ", pPlot:GetY(), "Y: ", pPlot:GetY(),"Couldn't Nerf This Tile");
			
			end
			end
			if placed_yield == 0 then
				placed_yield = target_tiles[i].yield
			end
			local added_yield = placed_yield - target_tiles[i].yield
			__Debug("Terraforming Best Original Yield: ", target_tiles[i].yield, "Placed Yield ", placed_yield , "Remaining Before", remaining_amount, "After",remaining_amount - added_yield);
			remaining_amount = remaining_amount - added_yield

			else
			
			__Debug("Terraforming Best Index: ", target_tiles[i].index, "X: ", pPlot:GetY(), "Y: ", pPlot:GetY(),"Invalid");
		end
	end
	
	if remaining_amount > -1 then
		return
	end
	
	
	for i = 3, 4 do
		__Debug("Terraforming Best: ", i, remaining_amount);
		if remaining_amount > -1 then
			break
		end
		
		local pPlot = Map.GetPlotByIndex(target_tiles[i].index)

		if target_tiles[i].isValid == true  then
		
			
			local target_yield = 0
			local placed_yield = 0
			
			if  target_tiles[i].yield > 5.25 then
				target_yield = 5
				elseif target_tiles[i].yield > 4.5 then
				target_yield = 4.5
				else
				target_yield = -1
			end
			
			local target_plot_1 = pPlot

				
			if target_yield ~= -1 then
			if ( target_plot_1:GetTerrainType() == 0 or target_plot_1:GetTerrainType() == 1 or (target_plot_1:GetTerrainType() == 2 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO) ) then
					
				--if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_GRASSLAND or ( target_plot_1:GetFeatureType() == g_FEATURE_FLOODPLAINS_GRASSLAND and flag ~= 4) ) then
            
            if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_GRASSLAND) then
				
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100	
					
					if (target_yield < 5.75 and target_yield > 4.75) then
							
						if (rng >= 0.70) then
							-- Flat Deer Forest
							TerrainBuilder.SetTerrainType(target_plot_1,0);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/2 Grassland Forest with Deers");
							placed_yield = 5
							
                  elseif (rng >= 0.35 and rng < 0.70) then
							-- Forested Hill
							TerrainBuilder.SetTerrainType(target_plot_1,1);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/2 Forested Grassland Hill");
							placed_yield = 5
							
                  else
							-- Stone Hill
							TerrainBuilder.SetTerrainType(target_plot_1,1);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 8, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/2 Stone Grassland Hill");
							placed_yield = 5
							
							
						end

               elseif target_yield > 4.25 then -- yield below 4.75
						
                  if (rng >= 0.0 and rng < 0.80) then
                     -- Hill with Sheep
                     TerrainBuilder.SetTerrainType(target_plot_1,1);
                     TerrainBuilder.SetFeatureType(target_plot_1,-1);
                     ResourceBuilder.SetResourceType(target_plot_1, -1);
                     ResourceBuilder.SetResourceType(target_plot_1, 7, 1)
                     __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 3/1 Sheep Grassland Hill");
                     placed_yield = 4.5
                  
                  else
                     -- Copper Hill
                     TerrainBuilder.SetTerrainType(target_plot_1,1);
                     TerrainBuilder.SetFeatureType(target_plot_1,-1);
                     ResourceBuilder.SetResourceType(target_plot_1, -1);
                     ResourceBuilder.SetResourceType(target_plot_1, 2, 1)
                     __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/1/2 Copper Grassland Hill");
                     placed_yield = 4
                  end
						
               else
						
						TerrainBuilder.SetTerrainType(target_plot_1,1);
						TerrainBuilder.SetFeatureType(target_plot_1,-1);
						ResourceBuilder.SetResourceType(target_plot_1, -1);
						__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/1 Grassland Hill");
						placed_yield = 3.5						

					end -- close target if
						
            else -- Grassland with Floodplains
						
						-- floodplains and floodplains Civs
					if (target_plot_1:GetResourceCount() < 1) then
						ResourceBuilder.SetResourceType(target_plot_1, 6, 1)
						__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 3/0 Rice Grassland Floodplains");
						placed_yield = 3
					end
					
				end
				
				-- Plains
				elseif ( target_plot_1:GetTerrainType() == 3 or target_plot_1:GetTerrainType() == 4 or (target_plot_1:GetTerrainType() == 5 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO)) then
					
				--if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_PLAINS or ( target_plot_1:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS and flag ~= 4) ) then
            
            if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS_PLAINS) then
					-- +5.5 on Plains		
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100
					
					if (target_yield < 5.25 and target_yield > 4.75) then
							
						if (rng >= 0.50) then
								-- Hill with Sheep
								TerrainBuilder.SetTerrainType(target_plot_1,4);
								TerrainBuilder.SetFeatureType(target_plot_1,-1);
								ResourceBuilder.SetResourceType(target_plot_1, -1);
								ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
								__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/2 Sheep Plain Hill");
								placed_yield = 5

                  else
								
							if (target_plot_1:GetY() > gridHeight * 0.33 and target_plot_1:GetY() < gridHeight * 0.66) then
								-- Jungle Plain Hill
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        TerrainBuilder.SetFeatureType(target_plot_1,2);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/2 Jungle Plain Hill");
                        placed_yield = 5
                     else
                        -- Hill with Sheep
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/2 Sheep Plain Hill");
                        placed_yield = 5
							end
						end						
							
						elseif target_yield > 4.25 then -- yield < 4.75
							
							-- Banana Jungle Hill
                     if (target_plot_1:GetY() > gridHeight * 0.33 and target_plot_1:GetY() < gridHeight * 0.66) then
                        TerrainBuilder.SetTerrainType(target_plot_1,3);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1,0, 1);
                        TerrainBuilder.SetFeatureType(target_plot_1,2);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 3/1 Jungle Plain with Banana");
                        placed_yield = 4.5
                     else
                     
                        if (rng >= 0.50) then
                           -- Forested Plain with deers
                           TerrainBuilder.SetTerrainType(target_plot_1,3);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           TerrainBuilder.SetFeatureType(target_plot_1,3);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           ResourceBuilder.SetResourceType(target_plot_1, 4, 1);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/3 Forested Plain with Deer");
                           placed_yield = 4
                        else
                           -- Forested Plain hill
                           TerrainBuilder.SetTerrainType(target_plot_1,4);
                           TerrainBuilder.SetFeatureType(target_plot_1,-1);
                           TerrainBuilder.SetFeatureType(target_plot_1,3);
                           ResourceBuilder.SetResourceType(target_plot_1, -1);
                           __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/3 Forested Plain Hill");
                           placed_yield = 4
                        end

                     end
						
						elseif target_yield > 3.75 then
                  
                     if (rng >= 0.50) then
                        -- Forested Plain with deers
                        TerrainBuilder.SetTerrainType(target_plot_1,3);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        TerrainBuilder.SetFeatureType(target_plot_1,3);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        ResourceBuilder.SetResourceType(target_plot_1, 4, 1);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/3 Forested Plain with Deer");
                        placed_yield = 4
                     else
                        -- Forested Plain hill
                        TerrainBuilder.SetTerrainType(target_plot_1,4);
                        TerrainBuilder.SetFeatureType(target_plot_1,-1);
                        TerrainBuilder.SetFeatureType(target_plot_1,3);
                        ResourceBuilder.SetResourceType(target_plot_1, -1);
                        __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/3 Forested Plain Hill");
                        placed_yield = 4
                     end

                  else
                     -- Plain Hill
                     TerrainBuilder.SetTerrainType(target_plot_1,4);
                     TerrainBuilder.SetFeatureType(target_plot_1,-1);
                     ResourceBuilder.SetResourceType(target_plot_1, -1);
                     __Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/2 Plain Hills");
                     placed_yield = 3


							
					end -- close target
						
					else
						
						-- floodplains and floodplains Civs
					if (target_plot_1:GetResourceCount() < 1 and target_plot_1:GetFeatureType() ~= g_FEATURE_OASIS) then
							ResourceBuilder.SetResourceType(target_plot_1, 9, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 3/0 Wheat Plains Floodplains");
					end
					placed_yield = 3	
						
				end

				-- Desert
				elseif ( target_plot_1:GetTerrainType() == 6 or target_plot_1:GetTerrainType() == 7 or (target_plot_1:GetTerrainType() == 8 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO)) then
					
				if ( target_plot_1:GetFeatureType() ~= g_FEATURE_FLOODPLAINS and target_plot_1:GetFeatureType() ~= g_FEATURE_OASIS) then
					-- on Desert -> impossible	
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100
					if (rng >= 0.5) then
							-- Hill with Sheep
							TerrainBuilder.SetTerrainType(target_plot_1,7);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/1 Sheep Desert Hill");
							placed_yield = 2.5
														if flag == 2 then
								placed_yield = placed_yield + 1
							end
						elseif (rng >= 0.0 and rng < 0.5) then
							-- Copper Hill
							TerrainBuilder.SetTerrainType(target_plot_1,7);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 2, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/0/2 Copper Desert Hill");
							placed_yield = 2
														if flag == 2 then
								placed_yield = placed_yield + 1
							end
					end
					else
						-- floodplains
					if (target_plot_1:GetResourceCount() < 1 and target_plot_1:GetFeatureType() ~= g_FEATURE_OASIS) then
							ResourceBuilder.SetResourceType(target_plot_1, 9, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 2/0 Wheat Desert Floodplains");
							placed_yield = 2
														if flag == 2 then
								placed_yield = placed_yield + 1
							end
					end
				end
				-- Tundra
				elseif ( target_plot_1:GetTerrainType() == 9 or target_plot_1:GetTerrainType() == 10 or (target_plot_1:GetTerrainType() == 11 and flag ~= 3 and target_plot_1:GetFeatureType() ~= g_FEATURE_VOLCANO)) then
					
				if ( target_plot_1:GetFeatureType() ~= g_FEATURE_MARSH) then
					-- +5 on Tundra -> impossible	
					rng = TerrainBuilder.GetRandomNumber(100,"test")/100
					if (rng >= 0.75) then
							-- Hill with Sheep
							TerrainBuilder.SetTerrainType(target_plot_1,10);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 7, 1);
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/1 Sheep Tundra Hill");
							placed_yield = 2.5
						elseif (rng >= 0.5 and rng < 0.75) then
							-- Copper Hill
							TerrainBuilder.SetTerrainType(target_plot_1,10);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 2, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/0/2 Copper Tundra Hill");
							placed_yield = 2
						elseif (rng >= 0.0 and rng < 0.5) then
							-- Forested Deer
							TerrainBuilder.SetTerrainType(target_plot_1,10);
							TerrainBuilder.SetFeatureType(target_plot_1,-1);
							TerrainBuilder.SetFeatureType(target_plot_1,3);
							ResourceBuilder.SetResourceType(target_plot_1, -1);
							ResourceBuilder.SetResourceType(target_plot_1, 4, 1)
							__Debug("Terraforming Best X: ", target_plot_1:GetX(), "Y: ", target_plot_1:GetY(), "Nerfed to 1/0/2 Deer Tundra Hill");
							placed_yield = 2
					end
				end
			
				else
				
				placed_yield = target_tiles[i].yield
				__Debug("Terraforming Best Index: ", target_tiles[i].index, "X: ", pPlot:GetY(), "Y: ", pPlot:GetY(),"Couldn't Nerf This Tile");
			
			end
			end
			if placed_yield == 0 then
				placed_yield = target_tiles[i].yield
			end
			local added_yield = placed_yield - target_tiles[i].yield
			__Debug("Terraforming Best Original Yield: ", target_tiles[i].yield, "Placed Yield ", placed_yield , "Remaining Before", remaining_amount, "After",remaining_amount - added_yield);
			remaining_amount = remaining_amount - added_yield

			else
			
			__Debug("Terraforming Best Index: ", target_tiles[i].index, "X: ", pPlot:GetY(), "Y: ", pPlot:GetY(),"Invalid");
		end
	end
end





------------------------------------------------------------------------------

------------------------------------------------------------------------------

function Terraforming_Water(plot,civilizationType)
	local iResourcesInDB = 0;
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local adjacentPlot = nil;

	--------------------------------------------------------------------------------------------------------------
	-- Terraforming Water Start ----------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------
	if plot:IsWater() == true then
		return
	end
	
	
	if plot:IsFreshWater() == true then
		return
	end
	
	
	if IsDryCiv(civilizationType) then
		return
	end
		
	if plot:IsCoastalLand() == true and IsSaltyCiv(civilizationType) then
		return
	end
		
	if plot:IsCoastalLand() == true then
	
		local rivernum = RiverManager.GetNumRivers();
		if rivernum ~= nil then
			local placed = addCoastalRiver(plot, rivernum);
			if placed == true then
				return
			end
		end
		
	end
		
		
		
	for i = 0, 5 do
		adjacentPlot = GetAdjacentTiles(plot, i);

		if (adjacentPlot ~=nil) then
			if (adjacentPlot:GetResourceCount() < 1 and adjacentPlot:IsUnit() == false and adjacentPlot:IsCoastalLand() == false) then
				__Debug("Terraforming Water X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Water Lake");
				--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
				--TerrainBuilder.SetTerrainType(adjacentPlot, 15);
            terraformBBSPlot(adjacentPlot, 15, -2, -2)
				return
			end
		end

	end
	-- Second round if you have an unit -- todo later moving the unit to starting plot to allow the lake to be placed
	for i = 0, 5 do
		adjacentPlot = GetAdjacentTiles(plot, i);

		if (adjacentPlot ~=nil) then
			if (adjacentPlot:GetResourceCount() < 1 and adjacentPlot:IsCoastalLand() == false and adjacentPlot:GetFeatureType() ~= g_FEATURE_VOLCANO) then
				__Debug("Terraforming Water X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Water Lake but unit was on the way");
				--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
				--TerrainBuilder.SetTerrainType(adjacentPlot, 15);
            terraformBBSPlot(adjacentPlot, 15, -2, -2)
				return
			end
		end

	end
	-- third round remove resources so water get priority
	for i = 0, 5 do
		adjacentPlot = GetAdjacentTiles(plot, i);

		if (adjacentPlot ~=nil) then
         if (adjacentPlot:IsCoastalLand() == false) then
            __Debug("Terraforming Water X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Water Lake but unit was on the way");
            ResourceBuilder.SetResourceType(adjacentPlot, -1);
            --TerrainBuilder.SetFeatureType(adjacentPlot,-1);
            --TerrainBuilder.SetTerrainType(adjacentPlot, 15);
            terraformBBSPlot(adjacentPlot, 15, -2, -2)
            return
         end
		end

	end

end

------------------------------------------------------------------------------


------------------------------------------------------------------------------

function Terraforming_Flood(plot, intensity)
	-- flag = 0 normal
	-- flag = 1 tundra civ
	-- flag = 2 desert civ
	-- flag = 3 mountain civ
	local max_water = 0;
	local harborplot_index = nil;
	local iResourcesInDB = 0;
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local direction = 0;
	local bTerraform = true;
	local limit = 0;
	local limit_1 = 1;
	local limit_2 = 1;
	local limit_3 = 1;
	local limit_4 = 1;
	local adjacentPlot = nil;
	local adjacentPlot2 = nil;
	local adjacentPlot3 = nil;
	local adjacentPlot4 = nil;


	--------------------------------------------------------------------------------------------------------------
	-- Terraforming Floodplains Start ----------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------

	if (intensity == 1) then
		limit_1 = 0.25;
		limit_2 = 0.50;
		limit_3 = 0.33;
		limit_4 = 0.66;

		elseif (intensity == 2) then
			limit_1 = 0.10;
			limit_2 = 0.25;
			limit_3 = 0.25;
			limit_4 = 0.50;

	end
		
	for i = -1, 17 do
		adjacentPlot = GetAdjacentTiles(plot, i);

		if (i < 6) then
			limit = limit_1
			else
			limit = limit_2
		end

		if (adjacentPlot ~=nil) then
			if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS or adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS or adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_GRASSLAND) and adjacentPlot:IsNaturalWonder() == false then
				local rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
				if ( rng > limit ) then
					__Debug("Terraforming Floodplains X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Removed: Floodplains");
					if (i < 6) then
						TerrainBuilder.SetFeatureType(plot,-1);
					end
					TerrainBuilder.SetFeatureType(adjacentPlot,-1);
				end
			end
		end

	end
end

------------------------------------------------------------------------------

------------------------------------------------------------------------------
--- 57Fan functions
------------------------------------------------------------------------------

------------ Main functions ----------------

------
-- Function for PHASE ONE of the Coastal work
-- 1. Identify harbor spot
-- 2. Clean the harbor spot and making sure there is fresh water.
-- 3. Counting the water tiles and categorizing the spawn
-- 3. remove ice from ring 1-4
-- 4. changing ocean to coast for all ring 1-2 tiles
-- 5. changing ocean to coast for 50 % of ring 3 tiles
-- 6. making sure that there is at least one sea resource (oil excluded) on ring 2
-- 7. making sure that there are at least 3 sea resources in total (oil excluded) in total, adding in ring 3 if need be
-- Also building various structures used further during the coastal balancing
------
function Cleaning_Coastal(player)
	-- flag = 0 normal
	-- flag = 1 tundra civ
	-- flag = 2 desert civ
	-- flag = 3 mountain civ
	local max_water = 0;
	local harborplot_index = nil;
	local iResourcesInDB = 0;
   local plot = Map.GetPlot(player.plotX,player.plotY);
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local count = 0;
	local limit = 0;
	local adjacentPlot = nil;
	local adjacentPlot2 = nil;
	local adjacentPlot3 = nil;
	local adjacentPlot4 = nil;
   local seaResourcesR2Count = 0;
   local seaResourcesR2 = nil;
   local seaResourcesR3Count = 0;
   local seaResourcesR3 = nil;
   local improvableSeaResourcesCount = 0;
   local improvableSeaR2Count = 0;
   local improvableSeaR3Count = 0;
   
   
   -- Cannot use time here as all the players need the exact same generation
   math.randomseed("57000057");

-- Step 1  Getting a Valid Harbor
   
   local tileEmpty = 1000;
   local adjacentResource = 100;
   local adjacentWater = 10;

   local harborplot_index = -1;
   local maxScore = -1;

   for i = 0, 5 do
      local tileScore = 0;
		adjacentPlot = GetAdjacentTiles(plot, i);
      if (adjacentPlot ~=nil) then
			if (adjacentPlot:IsWater() == true) then
            local resource = adjacentPlot:GetResourceType();
            local feature = adjacentPlot:GetFeatureType();
            
            -- If the tile is empty, or with oil
            if (feature ~= g_FEATURE_REEF and (resource == -1 or resource == 45)) then
               tileScore = tileScore + tileEmpty;
            end
            for j = 0, 5 do
               adjacentPlot2 = GetAdjacentTiles(adjacentPlot, j);
               if (adjacentPlot2 ~=nil) then
						if (adjacentPlot2:IsWater() == true) then
                  -- adjacent water, counting points
                     tileScore = tileScore + adjacentWater;
                     
                     local adjResource = adjacentPlot2:GetResourceType();
							if (adjResource ~= -1 and adjResource ~= 45) then
                        -- adjacent resource, counting points
                        tileScore = tileScore + adjacentResource;
                     end
						end
               end
            end
            
            if (tileScore > maxScore) then
               harborplot_index = i;
               maxScore = tileScore;
               __Debug("test harbor X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "was picked as harbor plot, score: ", tileScore);
            else
               __Debug("test harbor X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "was not picked as harbor plot, score: ", tileScore);
            end
         end
      end
   end

--[[
	max_water = 0;
	count = 0;
	harborplot_index = 0;
	for i = 0, 5 do
		adjacentPlot = GetAdjacentTiles(plot, i);
		if (adjacentPlot ~=nil) then
			if (adjacentPlot:IsWater() == true) then
				-- try to find the plot with a maximum number of adjacent water tile	
				count = 0		
				for j = 0, 5 do
					adjacentPlot2 = GetAdjacentTiles(adjacentPlot, j);
					if (adjacentPlot2 ~=nil) then
						if (adjacentPlot2:IsWater() == true) then
							count = count + 1;
						end
					end
					if (count > max_water) then
						max_water = count;
						harborplot_index = i;
					end
				end
			end
		end
	end
   
   --]]
   
   -- Step 2 Cleaning the harbor location and adding a river if no fresh water
	local harborPlot = nil
	if (harborplot_index ~= nil) then
		harborPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), harborplot_index);
		if (harborPlot ~= nil) then
			__Debug("Coastal Terraforming (Step 2) X: ", harborPlot:GetX(), "Y: ", harborPlot:GetY(), "Found a valid Harbor tile");
			ResourceBuilder.SetResourceType(harborPlot, -1);
			TerrainBuilder.SetFeatureType(harborPlot,-1);
		end
	end
   
   
   -- Moved into Terraforming_water
   --[[
   if (plot:IsFreshWater()) then
      __Debug("freshwater");
   else
      -- some maps (Highlands and inland so far known) use a specific river script, so we need to adapt
      local isAlternativeRiverScript = false
      
      __Debug("NO fresh water");
      __Debug("adding a river");
      
      local mapName = MapConfiguration.GetValue("MAP_SCRIPT");
      for i = 1, #RIVERS_ALTERNATIVE do
         if (RIVERS_ALTERNATIVE[i] == mapName) then
            isAlternativeRiverScript = true;
         end
      end
      
      if (isAlternativeRiverScript) then
         __Debug("Will use alternate river counting");
         __Debug("River ID:", g_iRiverID);
         addCoastalRiver(plot, g_iRiverID);
		 if g_iRiverID ~= nil then
			g_iRiverID = g_iRiverID + 1;
			__Debug("River ID after:", g_iRiverID);
			else
			__Debug("Error:", g_iRiverID);
		end
         
      else
         __Debug("Will use standard river counting");
         __Debug("River ID:", nextRiverID);
         addCoastalRiver(plot, nextRiverID);
		 if nextRiverID ~= nil then
			nextRiverID = nextRiverID + 1;
			__Debug("River ID after:", nextRiverID);
			else
			__Debug("Error:", nextRiverID);
		end
      end
      
      
      
   end--]]
   
   -- 3. Counting the water tiles and categorizing the type of spawn
   local seaCountR1 = 0;
   local seaCountR2 = 0;
   local seaCountR3 = 0;
   
   local lakeCountR1 = 0;
   local lakeCountR2 = 0;
   local lakeCountR3 = 0;
   
   
   for i = 0, 5 do
      adjacentPlot = GetAdjacentTiles(plot, i);
      if (adjacentPlot ~=nil) then
         if (adjacentPlot:IsWater() == true) then
            if (adjacentPlot:IsLake() == true) then
               lakeCountR1 = lakeCountR1 + 1;
            else
               seaCountR1 = seaCountR1 + 1;
            end
         end
      end
   end
   
   
   for i = 6, 17 do
      adjacentPlot = GetAdjacentTiles(plot, i);
      if (adjacentPlot ~=nil) then
         if (adjacentPlot:IsWater() == true) then
            if (adjacentPlot:IsLake() == true) then
               lakeCountR2 = lakeCountR2 + 1;
            else
               seaCountR2 = seaCountR2 + 1;
            end
         end
      end
   end
   
   for i = 18, 35 do
      adjacentPlot = GetAdjacentTiles(plot, i);
      if (adjacentPlot ~=nil) then
         if (adjacentPlot:IsWater() == true) then
            if (adjacentPlot:IsLake() == true) then
               lakeCountR3 = lakeCountR3 + 1;
            else
               seaCountR3 = seaCountR3 + 1;
            end
         end
      end
   end

   
   __Debug("--- Water tiles analysis ---");
   
   __Debug("Lake R1:", lakeCountR1);
   __Debug("Lake R2:", lakeCountR2);
   __Debug("Lake R3:", lakeCountR3);
   
   __Debug("Sea R1:", seaCountR1);
   __Debug("Sea R2:", seaCountR2);
   __Debug("Sea R3:", seaCountR3);
   
   __Debug("---");
   
   --[[
   
   if (count_water < 5) then
      __Debug("Coastal Terraforming: Lake or Tiny Sea, stop there.");
      player.isFullCoastal = false;
      player.harborPlot = harborPlot;
      return;
   else
      player.isFullCoastal = true;
   end
   
   --]]
   
   if (seaCountR1 == 0) then -- Lake spawn, (no sea connection)
      if (seaCountR1 + seaCountR2 + seaCountR3 < 4) then -- just a lake, no coast, or very few
      
         if (lakeCountR1 + lakeCountR2 + lakeCountR3 <= 4) then -- small lake
            __Debug("Coastal Terraforming step 3: Found a small lake, will stop here");
            player.coastalType = LAKE_START_SMALL;
            player.isFullCoastal = false;
            return;
         else -- big lake
            __Debug("Coastal Terraforming step 3: Found a big lake, will proceed further");
            player.coastalType = LAKE_START_BIG;
            player.isFullCoastal = true;
         end
         
      else -- lake spawn, with some coast
         __Debug("Coastal Terraforming step 3: Found a lake and some coast, will proceed further");
         player.coastalType = LAKE_START_WITH_COAST;
         player.isFullCoastal = true;
      end
   
   elseif (seaCountR1 + seaCountR2 < 3) then -- we have a fjord
      if (seaCountR3 < 4) then -- we have a long fjord
         if (lakeCountR1 + lakeCountR2 + lakeCountR3 > 3) then -- With the lake, it becomes a standard spawn
            __Debug("Coastal Terraforming step 3: Found a long fjord with a lake, will consider as standard coastal");
            player.coastalType = COASTAL_START_STANDARD;
            player.isFullCoastal = true;
         else -- long fjord
            __Debug("Coastal Terraforming step 3: Found a long fjord");
            player.coastalType = COASTAL_START_LONG_FJORD;
            player.isFullCoastal = true;
         end
      else -- small fjord
         if (lakeCountR1 + lakeCountR2 + lakeCountR3 > 3) then -- With the lake, it becomes a standard spawn
            __Debug("Coastal Terraforming step 3: Found a small fjord with a lake, will consider as standard coastal");
            player.coastalType = COASTAL_START_STANDARD;
            player.isFullCoastal = true;
         else -- long fjord
            __Debug("Coastal Terraforming step 3: Found a small fjord");
            player.coastalType = COASTAL_START_SMALL_FJORD;
            player.isFullCoastal = true;
         end
      end
   
   elseif (lakeCountR1 + lakeCountR2 + lakeCountR3 + seaCountR1 + seaCountR2 + seaCountR3 < 5) then -- We have almost no water
      __Debug("Coastal Terraforming step 3: Found a very tiny sea, will stop here");
      player.coastalType = COASTAL_START_SMALL;
      player.isFullCoastal = false;
      return;
   elseif (lakeCountR1 + lakeCountR2 + lakeCountR3 + seaCountR1 + seaCountR2 + seaCountR3 > 14) then -- We have a lot of water
      __Debug("Coastal Terraforming step 3: Found a peninsula");
      player.coastalType = COASTAL_START_PENINSULA;
      player.isFullCoastal = true;
   else -- standard coastal spawn
      __Debug("Coastal Terraforming step 3: Standard coastal spawn");
      player.coastalType = COASTAL_START_STANDARD;
      player.isFullCoastal = true;
   end
   
   
   -- Step 3 Ice removal and also removing the coastal mountain preventing to go to the other side
	for i = 0, 60 do
   adjacentPlot = GetAdjacentTiles(plot, i);
		if (adjacentPlot ~=nil) then
         if (adjacentPlot:GetFeatureType() == 1) then
            __Debug("Costal Terraforming (Step 3a) X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Removing Ice",i);
            TerrainBuilder.SetFeatureType(adjacentPlot,-1);
         end
         
         -- We have a coastal mountain
         if (adjacentPlot:IsCoastalLand() and isMountain(adjacentPlot)) then
            print("Costal Terraforming (Step 3b) X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "found a coastal mountain",i);
            if (isMountainBypassable(adjacentPlot) == false and adjacentPlot:GetFeatureType() ~= g_FEATURE_VOLCANO and adjacentPlot:GetFeatureType() == -1) then
               print("Costal Terraforming (Step 3b) X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Removing non-bypassable mountain",i);
               mountainToHill(adjacentPlot);
            end
            
         end
         --__Debug("57, case X:", adjacentPlot:GetX(), " Y: ", adjacentPlot:GetY(), "code de terrain:", adjacentPlot:GetTerrainType(), " code de resources:" , adjacentPlot:GetResourceType(), "code de feature:", adjacentPlot:GetFeatureType());
      end
	end

   
   
   -- Step 4: Changing ocean to coast in all round 2 tiles
   -- Also counting naval resources for 1st and 2nd ring (excluding oil)
   -- Creating a list with all the tiles having resources in 1st and 2nd rings
   
   
   for i = 0, 17 do
      adjacentPlot = GetAdjacentTiles(plot, i);
		if (adjacentPlot ~=nil) then
         terrainType = adjacentPlot:GetTerrainType();
         -- if tile has a resource (oil excluded)
         if (terrainType == 15) and (adjacentPlot:GetResourceType() ~= -1) and (adjacentPlot:GetResourceType() ~= 45) then
            seaResourcesR2Count = seaResourcesR2Count + 1;
            improvableSeaResourcesCount = improvableSeaResourcesCount + 1;
            improvableSeaR2Count = improvableSeaR2Count + 1;
            seaResourcesR2 = {next = seaResourcesR2, plot = adjacentPlot, hasCampusAdj = false, isHarborAdj = false, score = 0, isLuxury = false};
         -- reef naked
         elseif (adjacentPlot:GetFeatureType() == g_FEATURE_REEF) then
            seaResourcesR2Count = seaResourcesR2Count + 1;
            seaResourcesR2 = {next = seaResourcesR2, plot = adjacentPlot, hasCampusAdj = false, isHarborAdj = false, score = 0, isLuxury = false};
            
         end
         if (terrainType == 16) and (adjacentPlot:GetResourceType() == 5 or adjacentPlot:GetResourceCount() < 1)  and adjacentPlot:IsNaturalWonder() == false then
				__Debug("Terraforming Coastal X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Ocean to Coast tile",i);
				TerrainBuilder.SetTerrainType(adjacentPlot,15);
         end
      end
   end
   
   -- Step 5: Changing ocean to coast in 50% 3 tiles
   -- Also counting naval resources for 3rd ring (excluding oil)
   -- Creating a list with all the tiles having resources 3rd ring
   
   for i = 18, 35 do
      adjacentPlot = GetAdjacentTiles(plot, i);
		if (adjacentPlot ~=nil) then
         terrainType = adjacentPlot:GetTerrainType();
         -- Counting resources
         -- if tile has a resource (oil excluded)
         if (terrainType == 15) and (adjacentPlot:GetResourceType() ~= -1) and (adjacentPlot:GetResourceType() ~= 45) then
            seaResourcesR3Count = seaResourcesR3Count + 1;
            improvableSeaResourcesCount = improvableSeaResourcesCount + 1;
            improvableSeaR3Count = improvableSeaR3Count + 1;
            seaResourcesR3 = {next = seaResourcesR3, plot = adjacentPlot, hasCampusAdj = false, isHarborAdj = false, score = 0, isLuxury = false};
         -- reef naked
         elseif (adjacentPlot:GetFeatureType() == g_FEATURE_REEF) then
            seaResourcesR3Count = seaResourcesR3Count + 1;
            seaResourcesR3 = {next = seaResourcesR3, plot = adjacentPlot, hasCampusAdj = false, isHarborAdj = false, score = 0, isLuxury = false};
            
         end
         if (terrainType == 16) then
            local rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
            if (rng > 0.5 and (adjacentPlot:GetResourceType() == 5 or adjacentPlot:GetResourceCount() < 1)  and adjacentPlot:IsNaturalWonder() == false) then
               __Debug("Terraforming Coastal X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Ocean to Coast tile",i);
               TerrainBuilder.SetTerrainType(adjacentPlot,15);
            end
         end
      end
    end
            
   -- Next: Make sure there are at least
   --   - One resource on ring 2
   --   - Three resources in total (4 for peninsulas and 2 for fjords)
   -- This happens before balancing to ensure that the score will not be too low
   -- Each naval civ will have at least 3 naval ressources (oil excluded), with one of them in ring 2 at least
   -- Further balance (add more resources, reefs, ...) will done in dedicated function
   
   local possibleRing2 = nil;
   local possibleRing2Count = 0;
   
   local aimedRessourcesCount;
   
   if (player.coastalType == COASTAL_START_LONG_FJORD or player.coastalType == COASTAL_START_SMALL_FJORD or player.coastalType == LAKE_START_BIG) then
      aimedRessourcesCount = 2; -- since we have a fjord or small lake, we need less
   elseif (player.coastalType == COASTAL_START_PENINSULA) then
      aimedRessourcesCount = 4; -- since we have a peninsula, we need more
   else
      aimedRessourcesCount = 3;
   end
   
   
   -- Creating a linked list with all resources-free tiles in the 1st and 2nd ring
   for i = 0, 17 do
      adjacentPlot = GetAdjacentTiles(plot, i);
      if (adjacentPlot ~=nil) then
         if (adjacentPlot:IsWater() == true and (adjacentPlot:GetFeatureType() == -1) and (adjacentPlot:GetResourceCount() < 1) and (adjacentPlot:IsNaturalWonder() == false) and isSameTile(harborPlot, adjacentPlot) == false) then
            --__Debug("Debug add list, case X:", adjacentPlot:GetX(), " Y: ", adjacentPlot:GetY(), "code de terrain:", adjacentPlot:GetTerrainType(), " code de resources:" , adjacentPlot:GetResourceType(), "code de feature:", adjacentPlot:GetFeatureType());
            possibleRing2Count = possibleRing2Count + 1;
            possibleRing2 = {next = possibleRing2, plot = adjacentPlot};
         end
      end
   end
   
   -- We start with checking if there are no resources on ring 1-2 at start (phase 6)
   if (improvableSeaR2Count  == 0) then
      -- We then list all the possible tiles which can accept a sea resource
      __Debug("Cleanup Coastal step 6a: found no improvable sea resource on ring 1-2, will try to add one");
      
      if (possibleRing2Count == 0) then
         __Debug("Cleanup Coastal step 6a: found no possible ring 1-2 sea slot ! Will add an extra ring 3");
      else
         __Debug("Cleanup Coastal step 6a: found ", possibleRing2Count, "possible spots to add a ring 1-2 resource");
         -- picking a random seed
         local index = math.random(1, possibleRing2Count);
         --__Debug("57 Cleanup Coastal step 6a: I have picked number ", index);
         
         local element = nil;
         
         possibleRing2, element = extractCellList (possibleRing2, index);
         possibleRing2Count = possibleRing2Count - 1;
         
         local upgradedTile = element.plot;
         
         if(ResourceBuilder.CanHaveResource(upgradedTile, 5)) then
            improvableSeaR2Count = improvableSeaR2Count + 1;
            seaResourcesR2Count = seaResourcesR2Count + 1;
            improvableSeaResourcesCount = improvableSeaResourcesCount + 1;
            
            TerrainBuilder.SetTerrainType(upgradedTile,15);
            ResourceBuilder.SetResourceType(upgradedTile, 5, 1);
            
            
            seaResourcesR2 = {next = seaResourcesR2, plot = upgradedTile, hasCampusAdj = false, isHarborAdj = false, score = 0, isLuxury = false};
            __Debug("cleanup Coastal Terraforming (Step 6a) X: ", upgradedTile:GetX(), "Y: ", upgradedTile:GetY(), "Added: Fish");
         end
         
      end
   else
      __Debug("Cleanup Coastal step 6a: Found ", improvableSeaR2Count, " improvable resources on ring 1-2, not adding extra");
   end
   
   -- We now make sure that there are 3 resources (or different) in total
   -- We adjust here on the third ring (step 7)
   
   -- Gonna be using a linked list
   local possibleRing3 = nil;
   local possibleRing3Count = 0;
   local upgradedTile = nil;
   
   -- Creating a linked list with all resources-free tiles in the 3rd ring
   for i = 18, 35 do
      adjacentPlot = GetAdjacentTiles(plot, i);
      if (adjacentPlot ~=nil) then
         if (adjacentPlot:IsWater() == true) and (adjacentPlot:GetFeatureType() == -1) and (adjacentPlot:GetResourceCount() < 1) and (adjacentPlot:IsNaturalWonder() == false) then
            possibleRing3Count = possibleRing3Count + 1;
            possibleRing3 = {next = possibleRing3, plot = adjacentPlot};
         end
      end
   end
   __Debug("Cleanup Coastal step 6b: found ", possibleRing3Count, "possible spots to add a ring 3 resource");
   
   -- Collecting all possible tiles
   if (improvableSeaResourcesCount >= aimedRessourcesCount) then
      __Debug("Cleanup Coastal step 6b: Found ", improvableSeaResourcesCount, " existing resources on ring 1-2-3, not adding extra");
      
   else
      __Debug("Cleanup Coastal step 6b: Found ", improvableSeaResourcesCount, " existing resources on ring 1-2-3, I will add more");
      
   end
      
   -- Adding resources if need be
   -- First, chosing which tile will receive the extra resource
   
   while (possibleRing3Count > 0 and improvableSeaResourcesCount < aimedRessourcesCount) do
      local index = math.random(1, possibleRing3Count);  
      --__Debug("Cleanup Coastal step 6b: I have picked number ", index);
    
      local element = nil;
    
      possibleRing3, element = extractCellList (possibleRing3, index);
      possibleRing3Count = possibleRing3Count - 1;
      
      
      upgradedTile = element.plot;
      
      -- If ocean, change to coast
      if (upgradedTile:GetTerrainType() == 16) then
         TerrainBuilder.SetTerrainType(upgradedTile,15);
      end
      
      if (ResourceBuilder.CanHaveResource(upgradedTile, 5)) then
         seaResourcesR3Count = seaResourcesR3Count + 1;
         improvableSeaResourcesCount = improvableSeaResourcesCount + 1;
         improvableSeaR3Count = improvableSeaR3Count + 1;
         TerrainBuilder.SetTerrainType(upgradedTile,15);
         ResourceBuilder.SetResourceType(upgradedTile, 5, 1);
         
         seaResourcesR3 = {next = seaResourcesR3, plot = upgradedTile, hasCampusAdj = false, isHarborAdj = false, score = 0, isLuxury = false};
         
         __Debug("cleanup Coastal Terraforming (Step 6b) X: ", upgradedTile:GetX(), "Y: ", upgradedTile:GetY(), "Added: Fish");
      else
         __Debug("cleanup Coastal Terraforming (Step 6b) X: ", upgradedTile:GetX(), "Y: ", upgradedTile:GetY(), "Cannot add Fish");
      end
      
      -- I have chosen the tile to change
      
   end
   
   if (improvableSeaResourcesCount >= aimedRessourcesCount) then
      __Debug("Cleanup Coastal step 6b: There are enough sea resources ");
   else
      __Debug("Cleanup Coastal step 6b: I only managed to have ", improvableSeaResourcesCount, "in total, instead of ", aimedRessourcesCount, "aimed.");
   end
   
   
   player.harborPlot = harborPlot;
   player.coastalScore = coastalScore;
   player.minCoastalScore = minCoastalScore;
   player.seaResourcesR2Count = seaResourcesR2Count;
   player.seaResourcesR3Count = seaResourcesR3Count;
   player.seaResourcesR2 = seaResourcesR2;
   player.seaResourcesR3 = seaResourcesR3;
   player.possibleCoastalRing2Count = possibleRing2Count;
   player.possibleCoastalRing3Count = possibleRing3Count;
   player.possibleCoastalRing2 = possibleRing2;
   player.possibleCoastalRing3 = possibleRing3;
   player.improvableSeaR2Count = improvableSeaR2Count ;
   player.improvableSeaR3Count = improvableSeaR3Count ;
   
   return;
   
end
	

-- This function will compute coastal score of a plot
-- Each tile will be evaluated according to preset
-- Extra info about the tile (hasCampusAdj or isHarborAdj will be completed here as well as the score)
--
-- All the base values used in theses functions can be found on top of this file
-- They are easily edited constants
--
--

function Coastal_Score(player)

   local coastalScore = 0;

   local element = player.seaResourcesR2;
   while (element ~= nil) do
      coastalScore = coastalScore + Coastal_plot_Score_R2(element, player.harborPlot, player.spawn);
      element = element.next;
   end
   
   element = player.seaResourcesR3;
   
   while (element ~= nil) do
      coastalScore = coastalScore + Coastal_plot_Score_R3(element, player.spawn);
      element = element.next;
   end
   
   if (player.coastalType == COASTAL_START_LONG_FJORD) then
      __Debug("Applying Long fjord penalty");
      coastalScore = coastalScore + LONG_FJORD_PENALTY;
      
   elseif (player.coastalType == COASTAL_START_SMALL_FJORD) then
      __Debug("Applying Small fjord penalty");
      coastalScore = coastalScore + SMALL_FJORD_PENALTY;
   
   elseif (player.coastalType == COASTAL_START_PENINSULA) then
      __Debug("Applying peninsula penalty (bonus)");
      coastalScore = coastalScore + PENINSULA_PENALTY;

   elseif (player.coastalType == LAKE_START_BIG) then
      __Debug("Applying big lake penalty");
      coastalScore = coastalScore + BIG_LAKE_PENALTY;  
   end
   
   return coastalScore;
end




function Coastal_plot_Score_R2(element, harborPlot, spawn)

   local plot = element.plot;
   
   if (plot == nil or harborPlot == nil) then
      return 0;
   end   
   
   -- non coastal tile
   if (plot:GetTerrainType() ~= 15) then
      return 0;
   end
   
   local resourceType = plot:GetResourceType();
   local featureType = plot:GetFeatureType();
   local isHarborAdj = isAdjTile(plot, harborPlot);
   
   
   -- Evaluate whether this tile will provide harbour adjacency
   if (isHarborAdj == true) then
      element.isHarborAdj = true;
   end
   
   -- evaluate if one of the tile next to the one we are checking is campusable (and will therefore get +2 from the reef)
   -- useful in case the tile has a reef (for immediate score), or in case of an improvement
   local hasCampusAdj = providesCampusAdj(plot, spawn);
       
   local tileScore = 0;
   
   -- crabs
   if (resourceType == 3) then
      tileScore = tileScore + CRABS_R2;
      if (isHarborAdj == true) then
         tileScore = tileScore + HARBOR_ADJ;
         __Debug("Coastal score R1-R2: found crabs and harbor adj, counting:", tileScore);
      else
         __Debug("Coastal score R1-R2: found crabs, counting:", tileScore);
      end
   end
   
   -- Pearls
   if (resourceType == 23) then
      tileScore = tileScore + PEARLS_R2;
      element.isLuxury = true;
      if (isHarborAdj == true) then
         tileScore = tileScore + HARBOR_ADJ;
         __Debug("Coastal score R1-R2: found pearls and harbor adj, counting:", tileScore);
      else
         __Debug("Coastal score R1-R2: found pearls, counting:", tileScore);
      end
   end
   
   -- amber
   if (resourceType == 49) then

      tileScore = tileScore + AMBER_R2;
      element.isLuxury = true;
      if (isHarborAdj == true) then
         tileScore = tileScore + HARBOR_ADJ;
         __Debug("Coastal score R1-R2: found amber and harbor adj, counting:", tileScore);
      else
         __Debug("Coastal score R1-R2: found amber, counting:", tileScore);
      end
   end
   
   -- whales
   if (resourceType == 32) then
      tileScore = tileScore + WHALES_R2;
      element.isLuxury = true;
      if (isHarborAdj == true) then
         tileScore = tileScore + HARBOR_ADJ;
         __Debug("Coastal score R1-R2: found whales and harbor adj, counting:", tileScore);
      else
         __Debug("Coastal score R1-R2: found whales, counting:", tileScore);
      end
   end
  
   
   -- fish, no reef !
   if (resourceType == 5 and featureType ~= g_FEATURE_REEF) then
      tileScore = tileScore + FISH_R2;
      if (isHarborAdj == true) then
         tileScore = tileScore + HARBOR_ADJ;
         __Debug("Coastal score R1-R2: found fish, no reef and harbor adj, counting:", tileScore);
      else
         __Debug("Coastal score R1-R2: found fish and no reef, counting:", tileScore);
      end
   end
   
   
   -- getting complicated with the reef tiles
   
   if (featureType == g_FEATURE_REEF) then
   
      -- adding campus score already
      if (hasCampusAdj == true) then
         tileScore = tileScore + REEF_CAMPUS;
      end
      
      
      -- Reef all alone
      if (resourceType == -1) then
         tileScore = tileScore + REEF_R2;
         
         if (hasCampusAdj == true) then
            __Debug("Coastal score R1-R2: found naked reef with campus adj, counting:", tileScore);
         else
            __Debug("Coastal score R1-R2: found naked reef without campus adj, counting:", tileScore);
         end
         
      end
      
     
      
      
      -- fish + reef
      if (resourceType == 5) then
         tileScore = tileScore + FISH_REEF_R2;
         
         -- adding harbor score
         if (isHarborAdj == true) then
            tileScore = tileScore + HARBOR_ADJ;
         end
            
         -- logs writing
         if (isHarborAdj == true and hasCampusAdj == true) then
            __Debug("Coastal score R1-R2: found fish-reef with harbor AND campus adj, counting:", tileScore);
         end
         
         if (isHarborAdj == true and hasCampusAdj == false) then
            __Debug("Coastal score R1-R2: found fish-reef with harbor adj, counting:", tileScore);
         end
         
         if (isHarborAdj == false and hasCampusAdj == true) then
            __Debug("Coastal score R1-R2: found fish-reef with campus adj, counting:", tileScore);
         end
         
         if (isHarborAdj == false and hasCampusAdj == false) then
            __Debug("Coastal score R1-R2: found fish-reef without any adj, counting:", tileScore);
         end
      end
      
      -- turtles + reef
      if (resourceType == 51) then
         tileScore = tileScore + TURTLES_R2;
         element.isLuxury = true;
         
         -- adding harbor score
         if (isHarborAdj == true) then
            tileScore = tileScore + HARBOR_ADJ;
         end
         
         -- logs writing
         if (isHarborAdj == true and hasCampusAdj == true) then
            __Debug("Coastal score R1-R2: found turtle with harbor AND campus adj (lucky boy !), counting:", tileScore);
         end
         
         if (isHarborAdj == true and hasCampusAdj == false) then
            __Debug("Coastal score R1-R2: found turtle with harbor adj, counting:", tileScore);
         end
         
         if (isHarborAdj == false and hasCampusAdj == true) then
            __Debug("Coastal score R1-R2: found turtle with campus adj, counting:", tileScore);
         end
         
         if (isHarborAdj == false and hasCampusAdj == false) then
            __Debug("Coastal score R1-R2: found turtle without any adj, counting:", tileScore);
         end
      end
   end
   
   element.score = tileScore;
   
   return tileScore;
   

   
   
end


function Coastal_plot_Score_R3(element)

   local plot = element.plot;

   if (plot == nil) then
      return 0;
   end   
   
   -- non coastal tile
   if (plot:GetTerrainType() ~= 15) then
      return 0;
   end
   
   local resourceType = plot:GetResourceType();
   local featureType = plot:GetFeatureType();
            
   local tileScore = 0;
   
   
   -- evaluate if one of the tile next to the one we are checking is campusable (and will therefore get +2 from the reef)
   -- useful in case the tile has a reef (for immediate score), or in case of an improvement
   local hasCampusAdj = providesCampusAdj(plot, spawn);
   
   -- crabs
   if (resourceType == 3) then
      tileScore = tileScore + CRABS_R3;
      __Debug("57 Coastal score R3: found crabs, counting:", tileScore);
   end
   
   -- Pearls
   if (resourceType == 23) then
      tileScore = tileScore + PEARLS_R3;
      element.isLuxury = true;
      __Debug("Coastal score R3: found pearls, counting:", tileScore);
   end
   
   -- amber
   if (resourceType == 49) then
      tileScore = tileScore + AMBER_R3;
      element.isLuxury = true;
      __Debug("Coastal score R3: found amber, counting:", tileScore);
   end
   
   -- whales
   if (resourceType == 32) then
      tileScore = tileScore + WHALES_R3;
      element.isLuxury = true;
      __Debug("Coastal score R3: found whales, counting:", tileScore);
   end
  
   
   
   -- fish, no reef !
   if (resourceType == 5 and featureType ~= g_FEATURE_REEF) then
      tileScore = tileScore + FISH_R3;
      __Debug("Coastal score R3: found fish and no reef, counting:", tileScore);
   end
   
   -- getting complicated with the reef tiles
   
   if (featureType == g_FEATURE_REEF) then
   
      
      
      -- adding campus score already
      if (hasCampusAdj == true) then
         tileScore = tileScore + REEF_CAMPUS;
      end
      
      
      -- Reef all alone
      if (resourceType == -1) then
         tileScore = tileScore + REEF_R3;
         
         if (hasCampusAdj == true) then
            __Debug("Coastal score R3: found naked reef with campus adj, counting:", tileScore);
         else
            __Debug("Coastal score R3: found naked reef without campus adj, counting:", tileScore);
         end
         
      end
      
      
      -- fish + reef
      if (resourceType == 5) then
         tileScore = tileScore + FISH_REEF_R3;
            
         -- logs writing
         if (hasCampusAdj == true) then
            __Debug("Coastal score R3: found fish-reef with campus adj, counting:", tileScore);
         else
            __Debug("Coastal score R3: found fish-reef without any adj, counting:", tileScore);
         end
      end
      
      -- turtles + reef
      if (resourceType == 51) then
         tileScore = tileScore + TURTLES_R3;
         element.isLuxury = true;
         
         -- logs writing
         if (hasCampusAdj == true) then
            __Debug("Coastal score R3: found turtle with campus adj, counting:", tileScore);
         else
            __Debug("Coastal score R3: found turtle without any adj, counting:", tileScore);
         end
         
      end
   end

   element.score = tileScore;
   return tileScore;

end

-- Will compute the minimal coastal score, which cannot be reduced
-- Here, only luxuries will be counted

function Min_Coastal_Score(player)

   local minCoastalScore = 0;

   local element = player.seaResourcesR2;
   while (element ~= nil) do
      if (element.isLuxury == true) then
         minCoastalScore = minCoastalScore + element.score;
      end
      element = element.next;
   end
   
   element = player.seaResourcesR3;
   
   while (element ~= nil) do
      if (element.isLuxury == true) then
         minCoastalScore = minCoastalScore + element.score;
      end
      element = element.next;
   end
   
   return minCoastalScore;

end


-- This function will adjust the coastal spaws, based on the meanScore of all the coastalScore obtained
-- If the player has a too low score, he will get extra resources/yield
-- If the player has a too high score, he will get resources/yields removed
-- If the player is within the margin (a score close to the goal score), nothing will be done

function adjustCoastal(player, aimedNavalScore, margin)

   -- Too close to the margin, not making any change
   if (math.abs(player.coastalScore - aimedNavalScore) <= margin) then
      __Debug("Score too close to aimed score, not changing anything");
      return;
   end
   
   if (player.coastalScore < aimedNavalScore) then
      __Debug("Score too low, will improve the start");
      improveCostal(player, aimedNavalScore, margin);
   else
      __Debug("Score too high, will nerf the start");
      nerfCostal(player, aimedNavalScore, margin);
   end
   
   return;
end

function improveCostal(player, aimedNavalScore, margin)

   -- will first try to improve existing resources (add fish on reef or reef on fish or upgrade a crab)
   
   -- Ring 2 first
   
   local tile = player.seaResourcesR2;
   
   while (tile ~= nil and (math.abs(player.coastalScore - aimedNavalScore) > margin)) do
      local scoreChange = 0;
      local plot = tile.plot;
      local oldTileScore = tile.score;
      local newTileScore = oldTileScore;
      local wasChanged = false;
      
      
      -- fish without reef
      if (plot:GetResourceType() == 5 and plot:GetFeatureType() ~= g_FEATURE_REEF) then
         scoreChange = FISH_REEF_R2 - FISH_R2;
         if (tile.hasCampusAdj == true) then
            scoreChange = scoreChange + REEF_CAMPUS;
         end
         
         -- will not go over the score
         -- This way, civs who get buffed don't get a bonus higher than the ref civ
         -- Might be changed
         
         if (player.coastalScore + scoreChange <= aimedNavalScore) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "adding REEF to an existing fish");
            TerrainBuilder.SetFeatureType(plot,g_FEATURE_REEF);
            newTileScore = oldTileScore + scoreChange;
            wasChanged = true;
            
         else
            scoreChange = 0;
            --__Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "change would be too big, not changing");
         end

      end
      
      -- just a reef, no resource
      if (plot:GetResourceType() == -1 and plot:GetFeatureType() == g_FEATURE_REEF) then
         scoreChange = FISH_REEF_R2 - REEF_R2;
         if (tile.isHarborAdj == true) then
            scoreChange = scoreChange + HARBOR_ADJ;
         end
         
         if (player.coastalScore  + scoreChange <= aimedNavalScore) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "adding FISH to an existing reef");
            ResourceBuilder.SetResourceType(plot, 5, 1);
            newTileScore = oldTileScore + scoreChange;
            player.improvableSeaR2Count = player.improvableSeaR2Count + 1;
            wasChanged = true;
            
         else
            scoreChange = 0;
            --__Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "change would be too big, not changing");
         end
         
      end
      
      -- crabs
      if (plot:GetResourceType() == 3 and plot:GetFeatureType() ~= g_FEATURE_REEF) then
         
         
         
         -- Will try and change it to a Fish+Reef
         scoreChange = FISH_REEF_R2 - CRABS_R2;
         if (tile.hasCampusAdj == true) then
            scoreChange = scoreChange + REEF_CAMPUS;
         end
         
         if (player.coastalScore + scoreChange <= aimedNavalScore) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Changing a crab into a Fish+reef");
            setResource(plot, 5, 15);
            setFeature(plot, g_FEATURE_REEF);
            newTileScore = oldTileScore + scoreChange;
            wasChanged = true;
            
         else
            scoreChange = 0;
            --__Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "change would be too big, not changing");
         end
         
         -- If failled, will try and change it to a naked Fish
         if (wasChanged == false) then
            scoreChange = FISH_R2 - CRABS_R2;
            if (player.coastalScore + scoreChange <= aimedNavalScore) then
               __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Changing a crab into a naked fish");
               setResource(plot, 5, 15);
               newTileScore = oldTileScore + scoreChange;
               wasChanged = true;
            else
               scoreChange = 0;
            --__Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "change would be too big, not changing");
            end
         end
         
      end
      
      tile.score = newTileScore;
      tile = tile.next;
      player.coastalScore = player.coastalScore + scoreChange;
      
      if (wasChanged) then
      
         __Debug("Old tile Score: ", oldTileScore);
         __Debug("New tile Score: ", newTileScore);
         __Debug("New player Score: ", player.coastalScore);
      else
         __Debug("Tile remained untouched");
      end
   end
   
   
   tile = player.seaResourcesR3;
   
   while (tile ~= nil and (math.abs(player.coastalScore - aimedNavalScore) > margin)) do
      local scoreChange = 0;
      local plot = tile.plot;
      local oldTileScore = tile.score;
      local newTileScore = oldTileScore;
      local wasChanged = false;
      
      
      -- fish without reef
      if (plot:GetResourceType() == 5 and plot:GetFeatureType() ~= g_FEATURE_REEF) then
         scoreChange = FISH_REEF_R3 - FISH_R3;
         if (tile.hasCampusAdj == true) then
            scoreChange = scoreChange + REEF_CAMPUS;
         end
         
         -- will not go over the score
         -- This way, civs who get buffed don't get a bonus higher than the ref civ
         -- Might be changed
         
         if (player.coastalScore  + scoreChange <= aimedNavalScore) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "adding REEF to an existing fish");
            TerrainBuilder.SetFeatureType(plot,g_FEATURE_REEF);
            newTileScore = oldTileScore + scoreChange;
            wasChanged = true;
            
         else
            --__Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "change would be too big, not changing");
            scoreChange = 0;
         end

      end
      
      -- just a reef, no resource
      if (plot:GetResourceType() == -1 and plot:GetFeatureType() == g_FEATURE_REEF) then
         scoreChange = FISH_REEF_R3 - REEF_R3;
         
         if (player.coastalScore  + scoreChange <= aimedNavalScore) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "adding FISH to an existing reef");
            ResourceBuilder.SetResourceType(plot, 5, 1);
            newTileScore = oldTileScore + scoreChange;
            player.improvableSeaR3Count = player.improvableSeaR3Count + 1;
            wasChanged = true;
            
         else
            --__Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "change would be too big, not changing");
            scoreChange = 0;
         end
         
      end
      
      
      -- crabs
      if (plot:GetResourceType() == 3 and plot:GetFeatureType() ~= g_FEATURE_REEF) then
         
         
         
         -- Will try and change it to a Fish+Reef
         scoreChange = FISH_REEF_R3 - CRABS_R3;
         if (tile.hasCampusAdj == true) then
            scoreChange = scoreChange + REEF_CAMPUS;
         end
         
         if (player.coastalScore + scoreChange <= aimedNavalScore) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Changing a crab into a Fish+reef");
            setResource(plot, 5, 15);
            setFeature(plot, g_FEATURE_REEF);
            newTileScore = oldTileScore + scoreChange;
            wasChanged = true;
            
         else
            scoreChange = 0;
            --__Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "change would be too big, not changing");
         end
         
         -- If failed, will try and change it to a naked Fish
         if (wasChanged == false) then
            scoreChange = FISH_R3 - CRABS_R3;
            if (player.coastalScore + scoreChange <= aimedNavalScore) then
               __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Changing a crab into a naked fish");
               setResource(plot, 5, 15);
               newTileScore = oldTileScore + scoreChange;
               wasChanged = true;
            else
               scoreChange = 0;
            --__Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "change would be too big, not changing");
            end
         end
         
      end
         
         
      tile.score = newTileScore;
      tile = tile.next;
      player.coastalScore = player.coastalScore + scoreChange;
         
      if (wasChanged) then
      
         __Debug("Old tile Score: ", oldTileScore);
         __Debug("New tile Score: ", newTileScore);
         __Debug("New player Score: ", player.coastalScore);
      else
         __Debug("Tile remained untouched");
      end
         

   end
   
   
   
   -- Will now work on the empty tiles
   -- working, in alternation, 2nd and 3rd ring
   
   while ((player.possibleCoastalRing2Count > 0 or player.possibleCoastalRing3Count > 0) and (aimedNavalScore - player.coastalScore) > margin) do
   
      
      if (player.possibleCoastalRing2Count > 0) then
      
         -- picking a random seed
         local index = math.random(1, player.possibleCoastalRing2Count);
         
         __Debug("Picked index ", index, "possibles ", player.possibleCoastalRing2Count);
         
         tile = nil;
         
         player.possibleCoastalRing2 , tile = extractCellList(player.possibleCoastalRing2 , index);
         player.possibleCoastalRing2Count = player.possibleCoastalRing2Count - 1;
         
         local plot = tile.plot;
         
         -- defining whether the tile is next to harbor and/or can provide campus adj
         
         local isHarborAdj = isAdjTile(plot, player.harborPlot);
         local hasCampusAdj = providesCampusAdj(plot, player.spawn);
         
         
         -- will now try all possibilities, starting with the best one (fish + reef), ending with the shittiest one (crabs)
         
         local resourceWasAdded = false;
         local newTileScore = 0;
         
         -- fish + reef
         -- adding in this case points for harbor AND campus
         
         
         if (isHarborAdj) then
            newTileScore = newTileScore + HARBOR_ADJ;
         end
         
         if (hasCampusAdj) then
            newTileScore = newTileScore + REEF_CAMPUS;
         end
         
         -- adding raw fish-reef score
         
         newTileScore = newTileScore + FISH_REEF_R2;
         
         --Only applying change if staying under the aimed score
         if (aimedNavalScore - (player.coastalScore + newTileScore) >= 0) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Adding fish + reef here");
            
            setResource(plot, 5, 15);
            setFeature(plot, g_FEATURE_REEF);
            
            player.seaResourcesR2 = {next = player.seaResourcesR2, plot = plot, hasCampusAdj = hasCampusAdj, isHarborAdj = isHarborAdj, score = newTileScore, isLuxury = false};
            player.seaResourcesR2Count = player.seaResourcesR2Count + 1;
            player.improvableSeaR2Count = player.improvableSeaR2Count + 1;
            player.coastalScore = player.coastalScore + newTileScore;
            resourceWasAdded = true;
            
            __Debug("New Player score: ", player.coastalScore);
         end
         
         
         -- just a fish
         
         newTileScore = 0;
         
         if (isHarborAdj) then
            newTileScore = newTileScore + HARBOR_ADJ;
         end
         
         newTileScore = newTileScore + FISH_R2;
         
         if (resourceWasAdded == false and (aimedNavalScore - (player.coastalScore + newTileScore) >= 0)) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Adding naked fish here");
            
            setResource(plot, 5, 15);
            
            player.seaResourcesR2 = {next = player.seaResourcesR2, plot = plot, hasCampusAdj = hasCampusAdj, isHarborAdj = isHarborAdj, score = newTileScore, isLuxury = false};
            player.seaResourcesR2Count = player.seaResourcesR2Count + 1;
            player.improvableSeaR2Count = player.improvableSeaR2Count + 1;
            player.coastalScore = player.coastalScore + newTileScore;
            resourceWasAdded = true;
            
            __Debug("New Player score: ", player.coastalScore);
         end
         
         
         --Crabs
         
         newTileScore = 0;
         
         if (isHarborAdj) then
            newTileScore = newTileScore + HARBOR_ADJ;
         end
         
         newTileScore = newTileScore + CRABS_R2;
         
         if (resourceWasAdded == false and (aimedNavalScore - (player.coastalScore + newTileScore) >= 0)) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Adding crabs here");
            
            setResource(plot, 3, 15);
            
            player.seaResourcesR2 = {next = player.seaResourcesR2, plot = plot, hasCampusAdj = hasCampusAdj, isHarborAdj = isHarborAdj, score = newTileScore, isLuxury = false};
            player.seaResourcesR2Count = player.seaResourcesR2Count + 1;
            player.improvableSeaR2Count = player.improvableSeaR2Count + 1;
            player.coastalScore = player.coastalScore + newTileScore;
            resourceWasAdded = true;
            
            __Debug("New Player score: ", player.coastalScore);
         end
         
         
         -- Just a reef
         
         newTileScore = 0;
         
         if (hasCampusAdj) then
            newTileScore = newTileScore + REEF_CAMPUS;
         end
         
         newTileScore = newTileScore + REEF_R2;
         
         if (resourceWasAdded == false and (aimedNavalScore - (player.coastalScore + newTileScore) >= 0)) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Adding reef here");
            
            setFeature(plot, g_FEATURE_REEF);
            
            player.seaResourcesR2 = {next = player.seaResourcesR2, plot = plot, hasCampusAdj = hasCampusAdj, isHarborAdj = isHarborAdj, score = newTileScore, isLuxury = false};
            player.seaResourcesR2Count = player.seaResourcesR2Count + 1;
            player.coastalScore = player.coastalScore + newTileScore;
            resourceWasAdded = true;
            
            __Debug("New Player score: ", player.coastalScore);
         end
      else
         __Debug("I don't have any empty tile ring 2, will only work the ring 3");
      end
      
      -- Same for Ring 3
      
      if (player.possibleCoastalRing3Count > 0) then
      
         -- picking a random seed
         local index = math.random(1, player.possibleCoastalRing3Count);
         
         tile = nil;
         
         player.possibleCoastalRing3 , tile = extractCellList (player.possibleCoastalRing3 , index);
         player.possibleCoastalRing3Count = player.possibleCoastalRing3Count - 1;
         
         local plot = tile.plot;
         
         -- defining whether the tile is next to harbor and/or can provide campus adj
         
         local isHarborAdj = false
         local hasCampusAdj = providesCampusAdj(plot, player.spawn);
         
         
         -- will now try all possibilities, starting with the best one (fish + reef), ending with the shittiest one (crabs)
         
         local resourceWasAdded = false;
         local newTileScore = 0;
         
         -- fish + reef
         -- adding in this case points for harbor AND campus
         
         
         
         if (hasCampusAdj) then
            newTileScore = newTileScore + REEF_CAMPUS;
         end
         
         -- adding fish-reef score
         
         newTileScore = newTileScore + FISH_REEF_R3;
         
         --Only applying change if staying under the aimed score
         if (aimedNavalScore - (player.coastalScore + newTileScore) >= 0) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Adding fish + reef here");
            
            setResource(plot, 5, 15);
            setFeature(plot, g_FEATURE_REEF);
            
            player.seaResourcesR3 = {next = player.seaResourcesR3, plot = plot, hasCampusAdj = hasCampusAdj, isHarborAdj = isHarborAdj, score = newTileScore, isLuxury = false};
            player.seaResourcesR3Count = player.seaResourcesR3Count + 1;
            player.improvableSeaR3Count = player.improvableSeaR3Count + 1;
            player.coastalScore = player.coastalScore + newTileScore;
            resourceWasAdded = true;
            
            __Debug("New Player score: ", player.coastalScore);
         end
         
         
         -- just a fish
         
         newTileScore = 0;
         

         
         newTileScore = newTileScore + FISH_R3;
         
         if (resourceWasAdded == false and (aimedNavalScore - (player.coastalScore + newTileScore) >= 0)) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Adding naked fish here");
            
            setResource(plot, 5, 15);
            
            player.seaResourcesR3 = {next = player.seaResourcesR3, plot = plot, hasCampusAdj = hasCampusAdj, isHarborAdj = isHarborAdj, score = newTileScore, isLuxury = false};
            player.seaResourcesR3Count = player.seaResourcesR3Count + 1;
            player.improvableSeaR3Count = player.improvableSeaR3Count + 1;
            player.coastalScore = player.coastalScore + newTileScore;
            resourceWasAdded = true;
            
            __Debug("New Player score: ", player.coastalScore);
         end
         
         
         --Crabs
         
         newTileScore = 0;
         

         
         newTileScore = newTileScore + CRABS_R3;
         
         if (resourceWasAdded == false and (aimedNavalScore - (player.coastalScore + newTileScore) >= 0)) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Adding crabs here");
            
            setResource(plot, 3, 15);
            
            player.seaResourcesR3 = {next = player.seaResourcesR3, plot = plot, hasCampusAdj = hasCampusAdj, isHarborAdj = isHarborAdj, score = newTileScore, isLuxury = false};
            player.seaResourcesR3Count = player.seaResourcesR3Count + 1;
            player.improvableSeaR3Count = player.improvableSeaR3Count + 1;
            player.coastalScore = player.coastalScore + newTileScore;
            resourceWasAdded = true;
            
            __Debug("New Player score: ", player.coastalScore);
         end
         
         
         -- Just a reef
         
         newTileScore = 0;
         
         if (hasCampusAdj) then
            newTileScore = newTileScore + REEF_CAMPUS;
         end
         
         newTileScore = newTileScore + REEF_R3;
         
         if (resourceWasAdded == false and (aimedNavalScore - (player.coastalScore + newTileScore) >= 0)) then
            __Debug("Balancing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Adding reef here");
            
            setFeature(plot, g_FEATURE_REEF);
            
            player.seaResourcesR3 = {next = player.seaResourcesR3, plot = plot, hasCampusAdj = hasCampusAdj, isHarborAdj = isHarborAdj, score = newTileScore, isLuxury = false};
            player.seaResourcesR3Count = player.seaResourcesR3Count + 1;
            player.coastalScore = player.coastalScore + newTileScore;
            resourceWasAdded = true;
            
            __Debug("New Player score: ", player.coastalScore);
         end
         
      else
         __Debug("I don't have any empty tile ring 2, will only work the ring 2");

      end
   
   end
   
end

function nerfCostal(player, aimedNavalScore, margin)

   -- will remove feature/nerf existing tiles
   -- will work in alternation: ring 2 then ring 3
   -- Luxuries are not affected
   -- Will work in list order, this way, tiles which were added last will be affected first
   
   local r2Element = player.seaResourcesR2;
   local r2Previous = nil;
   local r3Element = player.seaResourcesR3;
   local r3Previous = nil;
   

   __Debug("Nerfing Coastal Expected R2 count: ",player.seaResourcesR2Count);

   while ((r2Element ~= nil or r3Element ~= nil) and (player.coastalScore - aimedNavalScore) >= margin) do
      
      --__Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY());
      --__Debug("Nerfing Coastal tile score : ",r2Element.score);
      --__Debug("Nerfing Coastal tile Leader Score at the moment : ",player.coastalScore);
      local scoreChange = 0;
      local wasChanged = false;
      local wasRemoved = false;
      
      if (r2Element ~= nil) then
         if (r2Element.isLuxury == false) then
            local plot = r2Element.plot;
            
            
            -- Fish + reef
            if (plot:GetResourceType() == 5 and plot:GetFeatureType() == g_FEATURE_REEF) then
               
               scoreChange = r2Element.score;
               -- First, let's try and remove it all
               if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                  __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Removing Fish + reef here !");
                  setResource(plot, -1, 15);
                  setFeature(plot, -1);
                  wasChanged = true;
                  wasRemoved = true;
                  
                  -- Changing counts
                  player.improvableSeaR2Count = player.improvableSeaR2Count - 1;
                  player.seaResourcesR2Count = player.seaResourcesR2Count - 1;

               end
               
               -- Next, try and remove the fish, leaving the reef alone
               if (wasChanged == false) then
                  scoreChange = 0;
               
                  -- checking harbor adj
                  if (r2Element.isHarborAdj) then
                     scoreChange = scoreChange + HARBOR_ADJ;
                  end
                  
                  scoreChange = scoreChange + FISH_REEF_R2 - REEF_R2;
                  
                  if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                     __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had Fish+Reef here: Now only reef");
                     
                     setResource(plot, -1, 15);
                     wasChanged = true;
                     player.improvableSeaR2Count = player.improvableSeaR2Count - 1;
                     r2Element.score = r2Element.score - scoreChange;
                  end
               
               end
               
               -- Next, try and transform the tile into a crab
               if (wasChanged == false) then
                  scoreChange = 0;
               
                  -- checking campus adj
                  if (r2Element.hasCampusAdj) then
                     scoreChange = scoreChange + REEF_CAMPUS;
                  end
                  
                  scoreChange = scoreChange + FISH_REEF_R2 - CRABS_R2;
                  
                  if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                     __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had Fish+Reef here: Now only crabs");
                     
                     setFeature(plot, -1);
                     setResource(plot, 3, 15);
                     
                     r2Element.score = r2Element.score - scoreChange;
                     wasChanged = true;
                  end
               
               end
               
               -- Next, try and remove the reef from the tile
               if (wasChanged == false) then
                  scoreChange = 0;
               
                  -- checking campus adj
                  if (r2Element.hasCampusAdj) then
                     scoreChange = scoreChange + REEF_CAMPUS;
                  end
                  
                  scoreChange = scoreChange + FISH_REEF_R2 - FISH_R2;
                  
                  if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                     __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had Fish+Reef here: Now only Fish");
                     
                     setFeature(plot, -1);
                     
                     r2Element.score = r2Element.score - scoreChange;
                     wasChanged = true;
                  end
               
               end
               
               
            -- Fish alone
            elseif (wasChanged == false and plot:GetResourceType() == 5 and plot:GetFeatureType() ~= g_FEATURE_REEF) then
               
               -- First, let's try and remove it all
               scoreChange = r2Element.score;
               if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                  __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had naked Fish here: removing it");
               
                  setResource(plot, -1, 15);
                  wasChanged = true;
                  wasRemoved = true;
                  
                  -- Changing counts
                  player.improvableSeaR2Count = player.improvableSeaR2Count - 1;
                  player.seaResourcesR2Count = player.seaResourcesR2Count - 1;
               end
               
               -- Next, try and change it into a crab
               if (wasChanged == false) then
               
                  scoreChange = FISH_R2 - CRABS_R2;
                  if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                  __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had naked Fish here: changing it to Crabs");
               
                  setResource(plot, 3, 15);
                  wasChanged = true;
                  end
               end
               
            -- Reef alone
            elseif (wasChanged == false and plot:GetResourceType() == -1 and plot:GetFeatureType() == g_FEATURE_REEF) then
            
               -- Let's try and remove it
               scoreChange = r2Element.score;
               if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                  __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had naked Fish here: removing it");
               
                  setFeature(plot, -1);
                  wasChanged = true;
                  wasRemoved = true;
                  
                  -- Changing counts
                  player.seaResourcesR2Count = player.seaResourcesR2Count - 1;
                  
               end
            
            -- Crabs
            elseif (wasChanged == false and plot:GetResourceType() == 3) then
               -- Let's try and remove it
               scoreChange = r2Element.score;
               if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                  __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had Crab here: removing it");
                  
                  setResource(plot, -1, 15);
                  wasChanged = true;
                  wasRemoved = true;
                  
                  -- Changing counts
                  player.improvableSeaR2Count = player.improvableSeaR2Count - 1;
                  player.seaResourcesR2Count = player.seaResourcesR2Count - 1;
               end
            end
            
            
            
         
         
            if (wasChanged) then
               player.coastalScore = player.coastalScore - scoreChange;
            end
            __Debug("coastal score after change:", player.coastalScore);
            
             -- Since we removed the tile, removing it from the list !
            if (wasRemoved) then
               if (r2Previous ~= nil) then
                  r2Previous.next = r2Element.next;
               else
                  player.seaResourcesR2 = r2Element.next;
               end
               
            -- no element removed, just moving further in the list
            else
               r2Previous = r2Element;
            end
            
         end

         r2Element = r2Element.next;
      end
      
      scoreChange = 0;
      wasChanged = false;
      wasRemoved = false;
      
      
      if (r3Element ~= nil) then
         if (r3Element.isLuxury == false) then
            local plot = r3Element.plot;
            
            
            -- Fish + reef
            if (plot:GetResourceType() == 5 and plot:GetFeatureType() == g_FEATURE_REEF) then
               
               scoreChange = r3Element.score;
               -- First, let's try and remove it all
               if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                  __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Removing Fish + reef here !");
                  setResource(plot, -1, 15);
                  setFeature(plot, -1);
                  wasChanged = true;
                  wasRemoved = true;
                  
                  -- Changing counts
                  player.improvableSeaR3Count = player.improvableSeaR3Count - 1;
                  player.seaResourcesR3Count = player.seaResourcesR3Count - 1;

               end
               
               -- Next, try and remove the fish, leaving the reef alone
               if (wasChanged == false) then
                  scoreChange = 0;
               
                  -- checking harbor adj
                  if (r3Element.isHarborAdj) then
                     scoreChange = scoreChange + HARBOR_ADJ;
                  end
                  
                  scoreChange = scoreChange + FISH_REEF_R3 - REEF_R3;
                  
                  if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                     __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had Fish+Reef here: Now only reef");
                     
                     setResource(plot, -1, 15);
                     wasChanged = true;
                     player.improvableSeaR3Count = player.improvableSeaR3Count - 1;
                     r3Element.score = r3Element.score - scoreChange;
                  end
               
               end
               
               -- Next, try and transform the tile into a crab
               if (wasChanged == false) then
                  scoreChange = 0;
               
                  -- checking campus adj
                  if (r3Element.hasCampusAdj) then
                     scoreChange = scoreChange + REEF_CAMPUS;
                  end
                  
                  scoreChange = scoreChange + FISH_REEF_R3 - CRABS_R3;
                  
                  if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                     __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had Fish+Reef here: Now only crabs");
                     
                     setFeature(plot, -1);
                     setResource(plot, 3, 15);
                     
                     r3Element.score = r3Element.score - scoreChange;
                     wasChanged = true;
                  end
               
               end
               
               -- Next, try and remove the reef from the tile
               if (wasChanged == false) then
                  scoreChange = 0;
               
                  -- checking campus adj
                  if (r3Element.hasCampusAdj) then
                     scoreChange = scoreChange + REEF_CAMPUS;
                  end
                  
                  scoreChange = scoreChange + FISH_REEF_R3 - FISH_R3;
                  
                  if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                     __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had Fish+Reef here: Now only Fish");
                     
                     setFeature(plot, -1);
                     
                     r3Element.score = r3Element.score - scoreChange;
                     wasChanged = true;
                  end
               
               end
               
               
            -- Fish alone
            elseif (wasChanged == false and plot:GetResourceType() == 5 and plot:GetFeatureType() ~= g_FEATURE_REEF) then
               
               -- First, let's try and remove it all
               scoreChange = r3Element.score;
               if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                  __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had naked Fish here: removing it");
               
                  setResource(plot, -1, 15);
                  wasChanged = true;
                  wasRemoved = true;
                  
                  -- Changing counts
                  player.improvableSeaR3Count = player.improvableSeaR3Count - 1;
                  player.seaResourcesR3Count = player.seaResourcesR3Count - 1;
               end
               
               -- Next, try and change it into a crab
               if (wasChanged == false) then
               
                  scoreChange = FISH_R3 - CRABS_R3;
                  if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                  __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had naked Fish here: changing it to Crabs");
               
                  setResource(plot, 3, 15);
                  wasChanged = true;
                  end
               end
               
            -- Reef alone
            elseif (wasChanged == false and plot:GetResourceType() == -1 and plot:GetFeatureType() == g_FEATURE_REEF) then
            
               -- Let's try and remove it
               scoreChange = r3Element.score;
               if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                  __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had naked Fish here: removing it");
               
                  setFeature(plot, -1);
                  wasChanged = true;
                  wasRemoved = true;
                  
                  -- Changing counts
                  player.seaResourcesR3Count = player.seaResourcesR3Count - 1;
                  
               end
            
            -- Crabs
            elseif (wasChanged == false and plot:GetResourceType() == 3) then
               -- Let's try and remove it
               scoreChange = r3Element.score;
               if (player.coastalScore - aimedNavalScore - scoreChange >= 0) then
                  __Debug("Nerfing Coastal X: ", plot:GetX(), "Y: ", plot:GetY(), "Had Crab here: removing it");
                  
                  setResource(plot, -1, 15);
                  wasChanged = true;
                  wasRemoved = true;
                  
                  -- Changing counts
                  player.improvableSeaR3Count = player.improvableSeaR3Count - 1;
                  player.seaResourcesR3Count = player.seaResourcesR3Count - 1;
               end
            end
            
            
            
         
         
            if (wasChanged) then
               player.coastalScore = player.coastalScore - scoreChange;
            end
            __Debug("coastal score after change:", player.coastalScore);
            
             -- Since we removed the tile, removing it from the list !
            if (wasRemoved) then
               if (r3Previous ~= nil) then
                  r3Previous.next = r3Element.next;
               else
                  player.seaResourcesR3 = r3Element.next;
               end
               
            -- no element removed, just moving further in the list
            else
               r3Previous = r3Element;
            end
            
         end

         r3Element = r3Element.next;
      end
      
   end
   
   

end

------------ Support function ----------------

function isMountain(plot)

   local terrainType = plot:GetTerrainType();
   
   if (terrainType == 2 or terrainType == 5 or terrainType == 8 or terrainType == 11 or terrainType == 14) then
      return true;
   end
   
   return false;

end

-- Check features ???

function isWalkable(plot)
   if (isMountain(plot)) then
      return false;
   end
   
   local terrainType = plot:GetTerrainType();
   
   if (terrainType == 15 or terrainType == 16) then
      return false;
   end
   
   return true;

end


function mountainToHill(plot)
	if plot:GetFeatureType() ~= g_FEATURE_VOLCANO and plot:IsNaturalWonder() == false then
		local terrainType = plot:GetTerrainType();
		
		--TerrainBuilder.SetTerrainType(plot, terrainType - 1);
      terraformBBSPlot(plot, terrainType - 1, -2, -2)
   
		return;
		else
		 __Debug("mountainToHill X: ", plot:GetX(), "Y: ", plot:GetY(), "Cannot Change a Mountain if it is a Volcano or a Natural Wondner");
	end
end


-- Returns whether you can bypass a mountain or not.
-- Basically, checks that all the land are connected with one another

function isMountainBypassable(plot)

   local adjacentTiles = {};

   
   -- check all adjacent tiles on we
   for i = 0, 5 do
      local adjacentTile = GetAdjacentTiles(plot, i);
      if (isWalkable(adjacentTile) or (adjacentTile:IsCoastalLand() and isMountain(adjacentTile))) then
         __Debug("Costal Terraforming (Step 3b) X: ", adjacentTile:GetX(), "Y: ", adjacentTile:GetY(), "This tile is walkable",i);
         adjacentTiles[i + 1] = true;
      else
         __Debug("Costal Terraforming (Step 3b) X: ", adjacentTile:GetX(), "Y: ", adjacentTile:GetY(), "This tile is not walkable",i);
         adjacentTiles[i + 1] = false;
      end
   end
   
   -- Test all adjacent tiles:
   -- If they are no walkable, don't test
   -- If they are walkable (or coastal mountain), make sure that they can reach all the other walkable tiles
   
   local hasPathTo = {};
   
   for i = 1, 6 do
      if (adjacentTiles[i]) then
         for j = 1, 6 do
            hasPathTo[j] = false;
         end
         hasPathTo[i] = true; --Can always reach himself
         
         
         -- Check the tiles one turn
         j = nextIndex (i, 6);
         while (adjacentTiles[j] and j ~= i) do
            hasPathTo[j] = true;
            j = nextIndex (j, 6);
         end
         
         -- now the other way around
         j = previousIndex (i, 6);
         while (adjacentTiles[j] and j ~= i) do
            hasPathTo[j] = true;
            j = previousIndex (j, 6);
         end
         
         -- now compare
         -- if there is a walkable tile that we can't reach, the mountain is not bypassable
         
         for j = 1, 6 do
         
            -- Here, we have at least one tile that is not reachable round the mountain
            if (adjacentTiles[j] == true and hasPathTo[j] == false) then
               return false;
            end
         
         end
         
         
         -- if not, it means that all walkable tiles are connected
         return true;
         
      end   
   end

   -- Mountain on a stick
   return true;
end

-- returns the previous index of an array (the last element if asking for the previous of the first)
function previousIndex (index, arraySize)
   if (index == 1) then
      return arraySize;
   end

   return index - 1;
end

-- returns the previous index of an array (the last element if asking for the previous of the first)
function nextIndex (index, arraySize)
   if (index == arraySize) then
      return 1;
   end

   return index + 1;
end

function providesCampusAdj(plot, spawn)

   local hasCampusAdj = false;

   for i = 0, 5 do
      local campusTile = GetAdjacentTiles(plot, i);

      
      -- we will not count bonus for spawn tile
      if (isSameTile(spawn, campusTile) == false) then
         if (isDistrictable(campusTile) == true) then
            hasCampusAdj = true;
         end
      end
   end
   
   return hasCampusAdj;

end

function setResource(plot, resourceID, terrainType)

--[[
   if(ResourceBuilder.CanHaveResource(plot, 5) ~= true) then 
      __Debug("Can't place the selected resource there");
      __Debug("____57, case X:", plot:GetX(), " Y: ", plot:GetY(), "code de terrain:", plot:GetTerrainType(), " code de resources:" , plot:GetResourceType(), "code de feature:", plot:GetFeatureType());
   end
   
 ]]--
   
   if (terrainType ~= -1) then
      TerrainBuilder.SetTerrainType(plot, terrainType);
   end
   
   ResourceBuilder.SetResourceType(plot, resourceID, 1);
   
   return;

end

function setFeature(plot, featureID)

   TerrainBuilder.SetFeatureType(plot,featureID);
   return;

end

-- Compares 2 tiles coordinates
-- Returns true if the coordinates are the same
-- Returns false otherwise
function isSameTile(a, b)

   if (a == nil or b == nil) then
      return false;
   end
   
   --__Debug("Same tile 1: X: ", a:GetX(), "Y: ", a:GetY());
   --__Debug("Same tile 2: X: ", b:GetX(), "Y: ", b:GetY());

   local aX = a:GetX();
   local aY = a:GetY();
   local bX = b:GetX();
   local bY = b:GetY();
   
   -- same coordinates
   if (aX == bX and aY == bY) then
      --__Debug("returning true");
      return true;
   end

   --__Debug("returning false");
   return false;

end

-- Return true if the two plots are next to one another
-- Return false otherwise
-- same coordinates will be deemed as false

function isAdjTile(a, b)

   if (a == nil or b == nil) then
      return false;
   end

   local aX = a:GetX();
   local aY = a:GetY();
   local bX = b:GetX();
   local bY = b:GetY();
   
   -- same coordinates
   if (isSameTile(a, b) == true) then
      return false;
   end
   
   
   -- If Xs or Ys are more than 1 away from each other, tiles can't be adjacent
   -- if X is 0, we could have adj tile on the other side of the map
   if (aX ~= 0 and bX ~= 0 and (math.abs(aX - bX) > 1 or math.abs(aY - bY) > 1)) then
      return false;
   end
   
   -- if Xs XOR Ys are the same, tiles are adjacents
   -- OR is eliminated at "same coordinates"
   if (aY == bY) or (aX == bX) then
      return true;
   end
   
   
   -- If inconclusive (Ys and Xs one apart), then compare tiles one by one
   for i = 0, 5 do
      adjacentPlot = GetAdjacentTiles(a, i);
      if (isSameTile(b, adjacentPlot) == true) then
         return true;
      end
   end

   return false;
end

-- Return true if a (land) district can be built there
-- Return false otherwise
-- NEEDS TO BE FIXED(not sure of the resources code)

function isDistrictable (plot)

   if (plot == nil) then
      return false;
   end

   local terrainType = plot:GetTerrainType();
   local resourceType = plot:GetResourceType();
   
   -- mountains
   -- FIX HERE --
   if (terrainType == 2 or terrainType == 5 or terrainType == 8 or terrainType == 11 or terrainType == 14 or terrainType == 15 or terrainType == 16) then
      return false;
   end
   
   
   -- strategics, counted as districtable
   if (resourceType >= 40 and resourceType <= 47) then
      return true;
   end
   
   -- luxuries
   if (resourceType >= 10) then
      return false;
   end
   
   return true;  

end

-- Removes a cell from a linked list
-- returns the modified list and the removed cell
-- index starting at 1 (matching this language standard)
-- returns:
-- 1. the modified list
-- 2. the removed cell

function extractCellList (list, index)
   if index < 1 then
      return nil, nil;
   end
   
   if index == 1 then
      return list.next, list;
   end
   
   local element = list;
   local previous = nil;
   
   
   while element ~= nil and index > 1 do
      --__Debug("previous:", previous, "element:" , element);
      previous = element;
      element = element.next;
      index = index - 1;
   end
   
   
   
   previous.next = element.next;
   
   return list, element;

end

function removeElement (previous, current)

   if (previous == nil or current == nil) then
      return;
   end
   
   previous.next = current.next;
   
   return;

end

function addCoastalRiver (plot, riverID)
   
   if riverID == nil then
       __Debug("addCoastalRiver - riverID",riverID);
      return false; 
   end
   
   
   if (plot:IsWater()) then
      __Debug("Plot is water ?!");
      return false;
   end
   
   local nw = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
   local ne = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
   local e = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), DirectionTypes.DIRECTION_EAST);
   local w = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), DirectionTypes.DIRECTION_WEST);
   local sw = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
   local se = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
   
   if (sw:IsWater() == false and w:IsWater() == false and se:IsWater() == true) then
      __Debug("Gonna put a river on S-W part of tile, flowing S-E");
      TerrainBuilder.SetNEOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST, riverID);
      return true;
   end
   
   if (sw:IsWater() == false and se:IsWater() == false and w:IsWater() == true) then
      __Debug("Gonna put a river on S-W part of tile, flowing N-W");
      TerrainBuilder.SetNEOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_NORTHWEST, riverID);
      return true;
   end
   
   if (nw:IsWater() == false and w:IsWater() == false and sw:IsWater() == true) then
      __Debug("Gonna put a river on W part of tile, flowing S");
      TerrainBuilder.SetWOfRiver(w, true, FlowDirectionTypes.FLOWDIRECTION_SOUTH, riverID);
      return true;
   end
   
   if (sw:IsWater() == false and w:IsWater() == false and nw:IsWater() == true) then
      __Debug("Gonna put a river on W part of tile, flowing N");
      TerrainBuilder.SetWOfRiver(w, true, FlowDirectionTypes.FLOWDIRECTION_NORTH, riverID);
      return true;
   end
   
   
   if (nw:IsWater() == false and w:IsWater() == false and ne:IsWater() == true) then
      __Debug("Gonna put a river on N-W part of tile, flowing N-E");
      TerrainBuilder.SetNWOfRiver(nw, true, FlowDirectionTypes.FLOWDIRECTION_NORTHEAST, riverID);
      return true;
   end
   
   if (nw:IsWater() == false and ne:IsWater() == false and w:IsWater() == true) then
      __Debug("Gonna put a river on N-W part of tile, flowing S-W");
      TerrainBuilder.SetNWOfRiver(nw, true, FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST, riverID);
      return true;
   end
   
   if (ne:IsWater() == false and nw:IsWater() == false and e:IsWater() == true) then
      __Debug("Gonna put a river on N-E part of tile, flowing S-E");
      TerrainBuilder.SetNEOfRiver(ne, true, FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST, riverID);
      return true;
   end

   if (ne:IsWater() == false and e:IsWater() == false and w:IsWater() == true) then
      __Debug("Gonna put a river on N-E part of tile, flowing N-W");
      TerrainBuilder.SetNEOfRiver(ne, true, FlowDirectionTypes.FLOWDIRECTION_NORTHWEST, riverID);
      return true;
   end
   
   if (ne:IsWater() == false and e:IsWater() == false and se:IsWater() == true) then
      __Debug("Gonna put a river on E part of tile, flowing S");
      TerrainBuilder.SetWOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_SOUTH, riverID);
      return true;
   end
   
   if (se:IsWater() == false and e:IsWater() == false and ne:IsWater() == true) then
      __Debug("Gonna put a river on E part of tile, flowing S");
      TerrainBuilder.SetWOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_NORTH, riverID);
      return true;
   end
   
   if (se:IsWater() == false and sw:IsWater() == false and e:IsWater() == true) then
      __Debug("Gonna put a river on S-E part of tile, flowing N-E");
      TerrainBuilder.SetNWOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_NORTHEAST, riverID);
      return true;
   end
   
   if (se:IsWater() == false and e:IsWater() == false and sw:IsWater() == true) then
      __Debug("Gonna put a river on S-E part of tile, flowing S-W");
      TerrainBuilder.SetNWOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST, riverID);
      return true;
   end
   
   __Debug("Could not add river !!");
   
   return false;
   
end
 
-----
-- end 57F@n functions
-----

function Terraforming_Coastal(plot, intensity, post_correction)
	-- flag = 0 normal
	-- flag = 1 tundra civ
	-- flag = 2 desert civ
	-- flag = 3 mountain civ
	local max_water = 0;
	local harborplot_index = nil;
	local iResourcesInDB = 0;
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local direction = 0;
	local bTerraform = true;
	local count = 0;
	local limit = 0;
	local limit_1 = 0.75;
	local limit_2 = 0.5;
	local limit_3 = 0.33;
	local limit_4 = 0.5;
	local limit_5 = 0.5;
	local adjacentPlot = nil;
	local adjacentPlot2 = nil;
	local adjacentPlot3 = nil;
	local adjacentPlot4 = nil;


	--------------------------------------------------------------------------------------------------------------
	-- Terraforming Coastal Start --------------------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------

		
	

	-- Step 1  Getting a Valid Harbor
	max_water = 0;
	count = 0;
	harborplot_index = 0;
	for i = 0, 5 do
		adjacentPlot = GetAdjacentTiles(plot, i);
		if (adjacentPlot ~=nil) then
			if (adjacentPlot:IsWater() == true) then
				-- try to find the plot with a maximum number of adjacent water tile	
				count = 0		
				for j = 0, 5 do
					adjacentPlot2 = GetAdjacentTiles(adjacentPlot, j);
					if (adjacentPlot2 ~=nil) then
						if (adjacentPlot2:IsWater() == true) then
							count = count + 1;
						end
					end
					if (count > max_water) then
						max_water = count;
						harborplot_index = i;
					end
				end
			end
		end
	end
	

	-- Step 2 Cleaning the Location
	local harborPlot = nil
	if (harborplot_index ~= nil) then
		harborPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), harborplot_index);
		if (harborPlot ~= nil) then
			__Debug("Coastal Terraforming (Step 2) X: ", harborPlot:GetX(), "Y: ", harborPlot:GetY(), "Found a valid Harbor tile");
			ResourceBuilder.SetResourceType(harborPlot, -1);
			TerrainBuilder.SetFeatureType(harborPlot,-1);
		end
	end

	-- count 
	local count_reefs = 0
	local count_resources = 0
	local count_water = 0
	for i = 0, 17 do
		if (harborPlot ~= nil) then
			adjacentPlot = GetAdjacentTiles(harborPlot, i);
			else
			adjacentPlot = GetAdjacentTiles(plot, i);
		end
		if (adjacentPlot ~=nil) then
			if (adjacentPlot:IsWater() == true) then
				count_water = count_water + 1
			end
			if (adjacentPlot:GetFeatureType() == g_FEATURE_REEF) then
				count_reefs = count_reefs + 1;
				
			end
			if (adjacentPlot:IsWater() == true and adjacentPlot:GetResourceCount() > 0 and adjacentPlot:GetResourceType() ~= 45) then
				count_resources = count_resources + 1;
			end
		end
	end
	__Debug("Count Waters: ", count_water);
	__Debug("Count Reefs: ", count_reefs);
	__Debug("Count Resources: ", count_resources);
	
	if count_water < 5 then
		__Debug("Coastal Terraforming: Lake or Tiny Sea, stop there.")
		return
	end
	
	if (post_correction == false) then
	-- Step 3 Populating the harbor surrounding tiles
	
	for i = 0, 17 do
		if (harborPlot ~= nil) then
				adjacentPlot = GetAdjacentTiles(harborPlot, i);
				else
				adjacentPlot = GetAdjacentTiles(plot, i);
		end
		local rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
		if (adjacentPlot ~=nil) then
			if (adjacentPlot:IsWater() == true and adjacentPlot:GetFeatureType() == -1 and (adjacentPlot:GetResourceCount() < 1 or adjacentPlot:GetResourceType() == 5)) and adjacentPlot:IsNaturalWonder() == false then
				if (count_resources < 3) and adjacentPlot:GetResourceCount() < 1 then
					if(ResourceBuilder.CanHaveResource(adjacentPlot, 5)) then
						count_resources = count_resources+ 1
						ResourceBuilder.SetResourceType(adjacentPlot, 5, 1);
						TerrainBuilder.SetTerrainType(adjacentPlot,15);
						__Debug("Coastal Terraforming (Step 3) X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Fish");
					end
				end
				if (rng > limit_1 and count_reefs <2) and adjacentPlot:IsFreshWater() == false then
					__Debug("Coastal Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Reef");
					TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_REEF);
					TerrainBuilder.SetTerrainType(adjacentPlot,15);
					count_reefs = count_reefs + 1;
					local rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
					elseif (((rng/count_resources  > limit_2) or (count_resources < 3)) and adjacentPlot:GetResourceType() == -1) then
						if(ResourceBuilder.CanHaveResource(adjacentPlot, 5)) then
							count_resources = count_resources+ 1
							ResourceBuilder.SetResourceType(adjacentPlot, 5, 1);
							__Debug("Coastal Terraforming (Step 3) X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Fish");
						end
						
				end
			end
		end
	end
	
	local count_reefs = 0
	local count_resources = 0
	for i = 0, 60 do
		if (harborPlot ~= nil) then
			adjacentPlot = GetAdjacentTiles(harborPlot, i);
			else
			adjacentPlot = GetAdjacentTiles(plot, i);
		end
		if (adjacentPlot ~=nil) then
			if (adjacentPlot:GetFeatureType() == g_FEATURE_REEF) then
				count_reefs = count_reefs + 1;
				
			end
			if (adjacentPlot:IsWater() == true and adjacentPlot:GetResourceCount() > 0) then
				count_resources = count_resources + 1;
			end
		end
	end
	__Debug("Count Reefs: ", count_reefs);
	__Debug("Count Resources: ", count_resources);
		
	-- Step 4 Ocean to Coast and Ice removal
	for i = 0, 60 do

		if (i < 6) then
			limit = limit_3;
			elseif( i>5 and i <18) then
			limit = limit_4;
			elseif( i>18) then
			limit = limit_5;
		end
	
		adjacentPlot = GetAdjacentTiles(plot, i);
		if (adjacentPlot ~=nil) then
			terrainType = adjacentPlot:GetTerrainType();
			rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
			if (terrainType == 16) and rng > limit and (adjacentPlot:GetResourceType() == 5 or adjacentPlot:GetResourceCount() < 1)  and adjacentPlot:IsNaturalWonder() == false then
				__Debug("Terraforming Coastal X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Ocean to Coast tile",i);
				TerrainBuilder.SetTerrainType(adjacentPlot,15);
				local rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
				if (adjacentPlot:GetFeatureType() == -1 and rng > limit and adjacentPlot:GetResourceType() == -1 and ( (count_resources <3 and i <17) or (count_resources < 4 and i > 30) ) and (post_correction == false) and adjacentPlot:IsFreshWater() == false  ) then
					TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_REEF);
					__Debug("Coastal Terraforming (Step 4) X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Reef",i);
					count_resources = count_resources + 1;
					local rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
					if( (rng / count_resources / count_resources ) > limit and adjacentPlot:GetResourceType() == -1) then 
						-- Reef with fish 
						__Debug("Coastal Terraforming (Step 4) X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Fish");
						ResourceBuilder.SetResourceType(adjacentPlot, 5, 1);
					end
				end

				if (adjacentPlot:GetFeatureType() == 1 and rng > limit/2) then
					__Debug("Costal Terraforming (Step 4) X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Removing Ice",i);
					TerrainBuilder.SetFeatureType(adjacentPlot,-1);
				end
			end
		end



	end

	end
	__Debug("Coastal Terraforming : Total Reefs Count:", count_reefs, "Total Sea Resources:",count_resources );

end

------------------------------------------------------------------------------

function Terraforming(plot, intensity, flag)
	-- flag = 0 normal
	-- flag = 1 tundra civ
	-- flag = 2 desert civ
	-- flag = 3 mountain civ
	local iResourcesInDB = 0;
	local terrainType = plot:GetTerrainType();
	local featureType = plot:GetFeatureType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local direction = 0;
	local bTerraform = true;
	local limit = 0;
	local limit_1 = 0;
	local limit_2 = 0;
	local limit_3 = 0;
	local limit_4 = 0;
	local limit_tree = 0;
	local max_wood = 5;
	local adjacentPlot = nil;
	local adjacentPlot2 = nil;
	local adjacentPlot3 = nil;
	local adjacentPlot4 = nil;
	local count_wood = 0;
	local d_factor = 0;

	--------------------------------------------------------------------------------------------------------------
	-- Terraforming the Tundra/Snow/Desert  ----------------------------------------------------------------------
	--------------------------------------------------------------------------------------------------------------

		


	-- Spawn
	--if(plot:GetTerrainType() == 9 or plot:GetTerrainType() == 12 or plot:GetTerrainType() == 6) then
--
--		if (intensity == 1 and flag ~=1 and flag ~=2) then
--			__Debug("Terraforming X: ", plot:GetX(), "Y: ", plot:GetY(), "Changing to Plains tile, Spawn");
--			TerrainBuilder.SetTerrainType(plot,g_TERRAIN_TYPE_PLAINS);
--			else
---			__Debug("Terraforming X: ", plot:GetX(), "Y: ", plot:GetY(), "Changing to Grassland tile, Spawn");
--			TerrainBuilder.SetTerrainType(plot,0)
--		end

--		elseif(plot:GetTerrainType() == 10 or plot:GetTerrainType() == 13 or plot:GetTerrainType() == 7) then
--			if (intensity == 1 and flag ~=1 and flag ~=2) then
--				__Debug("Terraforming X: ", plot:GetX(), "Y: ", plot:GetY(), "Changing to Plains Hills tile, Spawn");
--				TerrainBuilder.SetTerrainType(plot,g_TERRAIN_TYPE_PLAINS_HILLS);
--				else
--				__Debug("Terraforming X: ", plot:GetX(), "Y: ", plot:GetY(), "Changing to Grasslands Hills tile, Spawn");
--				TerrainBuilder.SetTerrainType(plot,1);
--			end
--	end

	-- #0 to #100 Tiles
	for i = -1, 100 do
		if (i < 6) then
			limit = limit_1
			d_factor = -1
			elseif( i >5 and i <18) then
				limit = limit_2
				d_factor = -1
			elseif( i >17 and i <36) then
				limit = limit_3
				d_factor = 1
			else
				limit = limit_4
				d_factor = 2
		end
		adjacentPlot = GetAdjacentTiles(plot, i);
      
      local adjX = -5
      local adjY = -5
      
      if (adjacentPlot ~= nil) then
         adjX = adjacentPlot:GetX();
         adjY = adjacentPlot:GetY();
      end
		--__Debug("Evaluate Start X: ", adjacentPlot:GetX(), "Evaluate Start Y: ", adjacentPlot:GetY(), "Terrain Type: ", terrainType);
		--__Debug("Evaluate Start X: ", adjacentPlot:GetX(), "Evaluate Start Y: ", adjacentPlot:GetY(), "Feature Type: ", adjacentPlot:GetFeatureType());

		if (adjacentPlot ~= nil) then
			if adjacentPlot:IsNaturalWonder() == false then
			terrainType = adjacentPlot:GetTerrainType()
			if (adjacentPlot:GetFeatureType() == g_FEATURE_OASIS and flag ~=2) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Remove Oasis",i);
				--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
            terraformBBS(adjX, adjY, -2, -2, -1);
			end
			if (adjacentPlot:GetFeatureType() == 1) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Remove Ice",i);
				--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
            terraformBBS(adjX, adjY, -2, -2, -1);
			end
			rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
			if((terrainType == 9) and rng > limit and flag ~=1) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Tundra to Plains tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS);
            terraformBBS(adjX, adjY, 3, -2, -2);
				rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
				if world_age == 1 and adjacentPlot:GetResourceCount() == 0 and adjacentPlot:GetFeatureType() < 4 and rng < 0.20 then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Make it a Plains hill",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS_HILLS);	
               terraformBBS(adjX, adjY, 4, -2, -2);
				end
				rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
				if adjacentPlot:GetFeatureType() == -1 and adjacentPlot:GetResourceCount() == 0 and rng < 0.15 then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Add woods",i);
					--TerrainBuilder.SetFeatureType(adjacentPlot,3);
               terraformBBS(adjX, adjY, -2, -2, 3);
				end
			end
			if((terrainType == 10) and rng > limit and flag ~=1) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Tundra Hills to Plains Hills tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS_HILLS);
            terraformBBS(adjX, adjY, 4, -2, -2);
				if adjacentPlot:GetFeatureType() == -1 and adjacentPlot:GetResourceCount() == 0 and rng < 0.15 then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Add woods",i);
					--TerrainBuilder.SetFeatureType(adjacentPlot,3);
               terraformBBS(adjX, adjY, -2, -2, 3);
				end
			end
			if((terrainType == 11) and rng > limit and flag ~=1) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Tundra Mountains to Plains Mountains tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,5);
            terraformBBS(adjX, adjY, 5, -2, -2);
			end
			if((terrainType == 6) and rng > limit and flag ~=2) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Desert to Plains tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS);
            terraformBBS(adjX, adjY, 3, -2, -2);
				if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS) then
					--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
					--TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_FLOODPLAINS_PLAINS);
               terraformBBS(adjX, adjY, -2, -2, -1);
               terraformBBS(adjX, adjY, -2, -2, 32);
				end
			end
			if((terrainType == 7) and rng > limit and flag ~=2) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Desert Hills to Plains Hills tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS_HILLS);
            terraformBBS(adjX, adjY, 4, -2, -2);
			end
			if((terrainType == 8) and rng > limit and flag ~=2) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Desert Hills to Plains Hills tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,5);
            terraformBBS(adjX, adjY, 4, -2, -2);
			end
			if(terrainType == 12) then
				if(i < 18 and flag ~=1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Plain tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS);
               terraformBBS(adjX, adjY, 3, -2, -2);
            elseif(i < 36 and flag == 1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Tundra tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,9);
               terraformBBS(adjX, adjY, 9, -2, -2);
            elseif(flag ~=1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Tundra tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,9);
               terraformBBS(adjX, adjY, 9, -2, -2);
				end
			end
			if(terrainType == 13) then
				if(i < 18 and flag ~=1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Plain tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS_HILLS);
               terraformBBS(adjX, adjY, 4, -2, -2);
					elseif(i < 36 and flag == 1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Tundra tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,10);
               terraformBBS(adjX, adjY, 10, -2, -2);
					elseif(flag ~=1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Tundra tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,10);
               terraformBBS(adjX, adjY, 10, -2, -2);
				end
			end
			if((terrainType == 4) and rng > limit and adjacentPlot:GetFeatureType() ~= g_FEATURE_JUNGLE and flag ~=1 and flag ~=2) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Grassland Hills tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,1);
            terraformBBS(adjX, adjY, 1, -2, -2);
			end
			if((terrainType == 3) and rng > limit and adjacentPlot:GetFeatureType() ~= g_FEATURE_JUNGLE and flag ~=1 and flag ~=2) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Grassland tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,0);
            terraformBBS(adjX, adjY, 0, -2, -2);
			end
			if((terrainType == 0) and adjacentPlot:GetResourceCount() <1 and flag == 2 and rng < 0.50) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Grassland to Plains tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,3);
            terraformBBS(adjX, adjY, 3, -2, -2);
				--if (adjacentPlot:IsRiver() == true) then
					--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
					--TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_FLOODPLAINS_PLAINS);
				--end
			end
			if((terrainType == 1) and adjacentPlot:GetResourceCount() <1 and flag == 2 and rng < 0.66) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Grassland Hills to Plains Hills tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,4);
            terraformBBS(adjX, adjY, 4, -2, -2);
			end
			if((terrainType == 2) and adjacentPlot:GetResourceCount() <1 and flag == 2) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Grassland Mountains to Plains Mountains tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,5);
            terraformBBS(adjX, adjY, 5, -2, -2);
			end
			if( (terrainType == 3 or terrainType == 4 or terrainType == 5) and flag == 2) then
				local d_count = 0
				local adjacentPlot2 = nil
				for k = 0, 5 do
					adjacentPlot2 = GetAdjacentTiles(adjacentPlot, k)
					if adjacentPlot2 ~= nil then
						if adjacentPlot2:GetTerrainType() == 6 or adjacentPlot2:GetTerrainType() == 7 or adjacentPlot2:GetTerrainType() == 8 then
							d_count = d_count + 1
						end
					end		
				end
				if d_count > d_factor then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Plains to Desert tile",i);
               
               if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS) then
                  if adjacentPlot:GetResourceType() == 28 then -- remove sugar and put wheat
                     terraformBBS(adjX, adjY, 6, 9, 0);
                  elseif (adjacentPlot:GetResourceType() == 9 or adjacentPlot:GetResourceType() == 44 or adjacentPlot:GetResourceType() == 13) then -- niter or wheat or coton: can stay
                     terraformBBS(adjX, adjY, 6, -2, 0);
                  else -- other resource is erased
                     terraformBBS(adjX, adjY, 6, -1, 0);
                  end
               else
                  terraformBBS(adjX, adjY, 6, -1, -1);
               end
               
               
               --[[
               
					--ResourceBuilder.SetResourceType(adjacentPlot, -1);
					--TerrainBuilder.SetTerrainType(adjacentPlot,terrainType + 3);
               --terraformBBS(adjX, adjY, terrainType + 3, -1, -2);
					if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS) then
						--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
						--TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_FLOODPLAINS);
                  terraformBBS(adjX, adjY, terrainType + 3, -2, 0);
               elseif (adjacentPlot:IsRiver() == true and  rng < 0.33) and TerrainType == 3 then
						--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
						--TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_FLOODPLAINS);
                  terraformBBS(adjX, adjY, terrainType + 3, -2, -2);
               else
						--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
                  terraformBBS(adjX, adjY, terrainType + 3, -2, -1);
					end
               
               --]]
				end
			end
			rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
			if (adjacentPlot:IsWater() == false and adjacentPlot:IsImpassable() == false and adjacentPlot:GetTerrainType() ~= 12 and adjacentPlot:GetTerrainType() ~= 13 and adjacentPlot:GetTerrainType() ~= 6 and adjacentPlot:GetTerrainType() ~= 7 and adjacentPlot:GetFeatureType() == -1 and rng > limit_tree and adjacentPlot:GetResourceType() == -1 and count_wood < max_wood) then
            terraformBBS(adjX, adjY, -2, -2, 3);
				--TerrainBuilder.SetFeatureType(adjacentPlot,3);
				count_wood = count_wood + 1;
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Wood",i);
			end
			end
		end


	end
	count_wood = 0;
	__Debug("Terraforming East Side");

	if(MapConfiguration.GetValue("MapName") == nil) then
		return
		else
		if(MapConfiguration.GetValue("MapName") == "Tilted_Axis") then
			__Debug("Terraforming: Tilted Axis map");
			return
		end
	end

	local east_plot = GetAdjacentTiles(plot, 65);

	if (east_plot == nil) then
		return
	end

	-- #0 to #100 Tiles
	for i = 0, 90 do
		if (i < 6) then
			limit = limit_1
			d_factor = -1
			elseif( i >5 and i <18) then
				limit = limit_2
				d_factor = 0
			elseif( i >17 and i <36) then
				limit = limit_3
				d_factor = 1
			else
				limit = limit_4
				d_factor = 3
		end
		adjacentPlot = GetAdjacentTiles(east_plot, i);
      local adjX = -5
      local adjY = -5
      
      if (adjacentPlot ~= nil) then
         adjX = adjacentPlot:GetX();
         adjY = adjacentPlot:GetY();
      end
		--__Debug("Evaluate Start X: ", adjacentPlot:GetX(), "Evaluate Start Y: ", adjacentPlot:GetY(), "Terrain Type: ", terrainType);
		--__Debug("Evaluate Start X: ", adjacentPlot:GetX(), "Evaluate Start Y: ", adjacentPlot:GetY(), "Feature Type: ", adjacentPlot:GetFeatureType());

		if (adjacentPlot ~= nil) then
			if adjacentPlot:IsNaturalWonder() == false then
			terrainType = adjacentPlot:GetTerrainType()
			if (adjacentPlot:GetFeatureType() == g_FEATURE_OASIS and flag ~=2) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Remove Oasis",i);
				--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
            terraformBBS(adjX, adjY, -2, -2, -1);
			end
			if (adjacentPlot:GetFeatureType() == 1) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Remove Ice",i);
				--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
            terraformBBS(adjX, adjY, -2, -2, -1);
			end
			rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
			if((terrainType == 9) and rng > limit and flag ~=1) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Tundra to Plains tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS);
            terraformBBS(adjX, adjY, 3, -2, -2);
				rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
				if world_age == 1 and adjacentPlot:GetResourceCount() == 0 and adjacentPlot:GetFeatureType() < 4 and rng < 0.20 then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Make it a Plains hill",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS_HILLS);				
               terraformBBS(adjX, adjY, 4, -2, -2);
				end
				rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
				if adjacentPlot:GetFeatureType() == -1 and adjacentPlot:GetResourceCount() == 0 and rng < 0.15 then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Add woods",i);
					--TerrainBuilder.SetFeatureType(adjacentPlot,3);
               terraformBBS(adjX, adjY, -3, -2, -2);
				end
			end
			if((terrainType == 10) and rng > limit and flag ~=1) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Tundra Hills to Plains Hills tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS_HILLS);
            terraformBBS(adjX, adjY, 4, -2, -2);
				if adjacentPlot:GetFeatureType() == -1 and adjacentPlot:GetResourceCount() == 0 and rng < 0.15 then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Add woods",i);
					--TerrainBuilder.SetFeatureType(adjacentPlot,3);
               terraformBBS(adjX, adjY, 3, -2, -2);
				end
			end
			if(terrainType == 12) then
				if(i < 18 and flag ~=1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Plain tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS);
               terraformBBS(adjX, adjY, 3, -2, -2);
					elseif(flag ~=1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Tundra tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,9);
               terraformBBS(adjX, adjY, 9, -2, -2);
				end
			end
			if(terrainType == 13) then
				if(i < 18 and flag ~=1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Plain tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS_HILLS);
               terraformBBS(adjX, adjY, 4, -2, -2);
            elseif(flag ~=1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Tundra tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,10);
               terraformBBS(adjX, adjY, 10, -2, -2);
				end
			end
			rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
			if((terrainType == 0) and adjacentPlot:GetResourceCount() <1 and flag == 2 and rng < 0.50) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Grassland to Plains tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,3);
            terraformBBS(adjX, adjY, 3, -2, -2);
				--if (adjacentPlot:IsRiver() == true) then
					--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
					--TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_FLOODPLAINS_PLAINS);
				--end
			end
			if((terrainType == 1) and adjacentPlot:GetResourceCount() <1 and flag == 2 and rng < 0.66) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Grassland Hills to Plains Hills tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,4);
            terraformBBS(adjX, adjY, 1, -2, -2);
			end
			if((terrainType == 2) and adjacentPlot:GetResourceCount() <1 and flag == 2) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Grassland Mountains to Plains Mountains tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,5);
            terraformBBS(adjX, adjY, 5, -2, -2);
			end
			if((terrainType == 3 or terrainType == 4 or terrainType == 5) and flag == 2) then
				local d_count = 0
				local adjacentPlot2 = nil
				for k = 0, 5 do
					adjacentPlot2 = GetAdjacentTiles(adjacentPlot, k)
					if adjacentPlot2 ~= nil then
						if adjacentPlot2:GetTerrainType() == 6 or adjacentPlot2:GetTerrainType() == 7 or adjacentPlot2:GetTerrainType() == 8 then
							d_count = d_count + 1
						end
					end		
				end
				if d_count > d_factor then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Plains to Desert tile",i);
					
               if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS) then
                  if adjacentPlot:GetResourceType() == 28 then -- remove sugar and put wheat
                     terraformBBS(adjX, adjY, 6, 9, 0);
                  elseif (adjacentPlot:GetResourceType() == 9 or adjacentPlot:GetResourceType() == 44 or adjacentPlot:GetResourceType() == 13) then -- niter or wheat or coton: can stay
                     terraformBBS(adjX, adjY, 6, -2, 0);
                  else -- other resource is erased
                     terraformBBS(adjX, adjY, 6, -1, 0);
                  end
               else
                  terraformBBS(adjX, adjY, 6, -1, -1);
               end
               
               
               --[[
               
					--ResourceBuilder.SetResourceType(adjacentPlot, -1);
					--TerrainBuilder.SetTerrainType(adjacentPlot,terrainType + 3);
               --terraformBBS(adjX, adjY, terrainType + 3, -1, -2);
					if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS) then
						--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
						--TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_FLOODPLAINS);
                  terraformBBS(adjX, adjY, terrainType + 3, -2, 0);
               elseif (adjacentPlot:IsRiver() == true and  rng < 0.33) and TerrainType == 3 then
						--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
						--TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_FLOODPLAINS);
                  terraformBBS(adjX, adjY, terrainType + 3, -2, -2);
               else
						--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
                  terraformBBS(adjX, adjY, terrainType + 3, -2, -1);
					end
               
               --]]
				end
			end
			if (adjacentPlot:IsWater() == false and adjacentPlot:IsImpassable() == false and adjacentPlot:GetTerrainType() ~= 12 and adjacentPlot:GetTerrainType() ~= 13 and adjacentPlot:GetTerrainType() ~= 6 and adjacentPlot:GetTerrainType() ~= 7 and adjacentPlot:GetFeatureType() == -1 and rng > limit_tree and adjacentPlot:GetResourceType() == -1 and count_wood < max_wood) then
				--TerrainBuilder.SetFeatureType(adjacentPlot,3);
            terraformBBS(adjX, adjY, -2, -2, 3);
				count_wood = count_wood + 1;
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Wood",i);
			end
			end
		end


	end
	count_wood = 0;
	__Debug("Terraforming West Side");
	local west_plot = GetAdjacentTiles(plot, 80);

	if (west_plot == nil) then
		return
	end

	-- #0 to #100 Tiles
	for i = 90, 0, -1 do
		if (i < 6) then
			limit = limit_1
			d_factor = -1
			elseif( i >5 and i <18) then
				limit = limit_2
				d_factor = 0
			elseif( i >17 and i <36) then
				limit = limit_3
				d_factor = 1
			else
				limit = limit_4
				d_factor = 3
		end
		adjacentPlot = GetAdjacentTiles(west_plot, i);
      local adjX = -5
      local adjY = -5
      
      if (adjacentPlot ~= nil) then
         adjX = adjacentPlot:GetX();
         adjY = adjacentPlot:GetY();
      end
		--__Debug("Evaluate Start X: ", adjacentPlot:GetX(), "Evaluate Start Y: ", adjacentPlot:GetY(), "Terrain Type: ", terrainType);
		--__Debug("Evaluate Start X: ", adjacentPlot:GetX(), "Evaluate Start Y: ", adjacentPlot:GetY(), "Feature Type: ", adjacentPlot:GetFeatureType());

		if (adjacentPlot ~= nil) then
			if adjacentPlot:IsNaturalWonder() == false then
			terrainType = adjacentPlot:GetTerrainType()
			if (adjacentPlot:GetFeatureType() == g_FEATURE_OASIS and flag ~=2) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Remove Oasis",i);
				TerrainBuilder.SetFeatureType(adjacentPlot,-1);
            terraformBBS(adjX, adjY, -2, -2, -1);
			end
			if (adjacentPlot:GetFeatureType() == 1) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Remove Ice",i);
				TerrainBuilder.SetFeatureType(adjacentPlot,-1);
            terraformBBS(adjX, adjY, -2, -2, -1);
			end
			rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
			if((terrainType == 9) and rng > limit and flag ~=1) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Tundra to Plains tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS);
            terraformBBS(adjX, adjY, 4, -2, -2);
				rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
				if world_age == 1 and adjacentPlot:GetResourceCount() == 0 and adjacentPlot:GetFeatureType() < 4 and rng < 0.20 then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Make it a Plains hill",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS_HILLS);				
               terraformBBS(adjX, adjY, 4, -2, -2);
				end
				rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
				if adjacentPlot:GetFeatureType() == -1 and adjacentPlot:GetResourceCount() == 0 and rng < 0.15 then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Add woods",i);
					--TerrainBuilder.SetFeatureType(adjacentPlot,3);
               terraformBBS(adjX, adjY, 3, -2, -2);
				end
			end
			if((terrainType == 10) and rng > limit and flag ~=1) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Tundra Hills to Plains Hills tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS_HILLS);
            terraformBBS(adjX, adjY, 4, -2, -2);
				if adjacentPlot:GetFeatureType() == -1 and adjacentPlot:GetResourceCount() == 0 and rng < 0.15 then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Add woods",i);
					--TerrainBuilder.SetFeatureType(adjacentPlot,3);
               terraformBBS(adjX, adjY, -2, -2, 3);
				end
			end
			if(terrainType == 12) then
				if(i < 18 and flag ~=1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Plain tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS);
               terraformBBS(adjX, adjY, 3, -2, -2);
					elseif(flag ~=1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Tundra tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,9);
               terraformBBS(adjX, adjY, 9, -2, -2);
				end
			end
			if(terrainType == 13) then
				if(i < 18 and flag ~=1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Plain tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,g_TERRAIN_TYPE_PLAINS_HILLS);
               terraformBBS(adjX, adjY, 4, -2, -2);
            elseif(flag ~=1) then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing to Tundra tile",i);
					--TerrainBuilder.SetTerrainType(adjacentPlot,10);
               terraformBBS(adjX, adjY, 10, -2, -2);
				end
			end
			rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
			if((terrainType == 0) and adjacentPlot:GetResourceCount() <1 and flag == 2 and rng < 0.50) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Grassland to Plains tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,3);
            terraformBBS(adjX, adjY, 3, -2, -2);
				--if (adjacentPlot:IsRiver() == true) then
					--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
					--TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_FLOODPLAINS_PLAINS);
				--end
			end
			if((terrainType == 1) and adjacentPlot:GetResourceCount() <1 and flag == 2 and rng < 0.66) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Grassland Hills to Plains Hills tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,4);
            terraformBBS(adjX, adjY, 4, -2, -2);
			end
			if((terrainType == 2) and adjacentPlot:GetResourceCount() <1 and flag == 2) then
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Grassland Mountains to Plains Mountains tile",i);
				--TerrainBuilder.SetTerrainType(adjacentPlot,5);
            terraformBBS(adjX, adjY, 5, -2, -2);
			end
			if((terrainType == 3 or terrainType == 4 or terrainType == 5) and flag == 2) then
				local d_count = 0
				local adjacentPlot2 = nil
				for k = 0, 5 do
					adjacentPlot2 = GetAdjacentTiles(adjacentPlot, k)
					if adjacentPlot2 ~= nil then
						if adjacentPlot2:GetTerrainType() == 6 or adjacentPlot2:GetTerrainType() == 7 or adjacentPlot2:GetTerrainType() == 8 then
							d_count = d_count + 1
						end
					end		
				end
				if d_count > d_factor then
					__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Changing Plains to Desert tile",i);
					
               if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS) then
                  if adjacentPlot:GetResourceType() == 28 then -- remove sugar and put wheat
                     terraformBBS(adjX, adjY, 6, 9, 0);
                  elseif (adjacentPlot:GetResourceType() == 9 or adjacentPlot:GetResourceType() == 44 or adjacentPlot:GetResourceType() == 13) then -- niter or wheat or coton: can stay
                     terraformBBS(adjX, adjY, 6, -2, 0);
                  else -- other resource is erased
                     terraformBBS(adjX, adjY, 6, -1, 0);
                  end
               else
                  terraformBBS(adjX, adjY, 6, -1, -1);
               end
               
               
               --[[
               
					--ResourceBuilder.SetResourceType(adjacentPlot, -1);
					--TerrainBuilder.SetTerrainType(adjacentPlot,terrainType + 3);
               --terraformBBS(adjX, adjY, terrainType + 3, -1, -2);
					if (adjacentPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS) then
						--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
						--TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_FLOODPLAINS);
                  terraformBBS(adjX, adjY, terrainType + 3, -2, 0);
               elseif (adjacentPlot:IsRiver() == true and  rng < 0.33) and TerrainType == 3 then
						--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
						--TerrainBuilder.SetFeatureType(adjacentPlot,g_FEATURE_FLOODPLAINS);
                  terraformBBS(adjX, adjY, terrainType + 3, -2, -2);
               else
						--TerrainBuilder.SetFeatureType(adjacentPlot,-1);
                  terraformBBS(adjX, adjY, terrainType + 3, -2, -1);
					end
               
               --]]
				end
			end
			if (adjacentPlot:IsWater() == false and adjacentPlot:IsImpassable() == false and adjacentPlot:GetTerrainType() ~= 12 and adjacentPlot:GetTerrainType() ~= 13 and adjacentPlot:GetTerrainType() ~= 6 and adjacentPlot:GetTerrainType() ~= 7 and adjacentPlot:GetFeatureType() == -1 and rng > limit_tree and adjacentPlot:GetResourceType() == -1 and count_wood < max_wood) then
				--TerrainBuilder.SetFeatureType(adjacentPlot,3);
            terraformBBS(adjX, adjY, -2, -2, 3);
				count_wood = count_wood + 1;
				__Debug("Terraforming X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added: Wood",i);
			end
			end
		end


	end
	----------------------------------------------------------------------
	--------------------- Terraforming Completed -------------------------
	----------------------------------------------------------------------


end


------------------------------------------------------------------------------
function RemoveProd(plot)

	local rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
	if rng > 0.5 then
	for j = 0, 17 do
		rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
		local otherPlot = GetAdjacentTiles(plot, j);
		--__Debug("Evaluate Start X: ", otherPlot:GetX(), "Evaluate Start Y: ", otherPlot:GetY(), "Terrain Type: ", terrainType);
		if otherPlot ~= nil then
		if (otherPlot:GetResourceType() == 4 or otherPlot:GetResourceType() == 8) then
			__Debug("Prod balancing: Prod Removed", otherPlot:GetResourceType());
			ResourceBuilder.SetResourceType(otherPlot, -1);
			return true;
		end
		if (otherPlot:GetFeatureType() == 3 and otherPlot:GetResourceCount() < 1 and rng > 0.5) then
			TerrainBuilder.SetFeatureType(otherPlot,-1);
			__Debug("Prod balancing: Wood Removed");
			return true;
		end
		end
	end 
	else
	for j = 17, 0, -1 do
		rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
		local otherPlot = GetAdjacentTiles(plot, j);
		if otherPlot ~= nil then
		--__Debug("Evaluate Start X: ", otherPlot:GetX(), "Evaluate Start Y: ", otherPlot:GetY(), "Terrain Type: ", terrainType);
		if (otherPlot:GetResourceType() == 4) then
			__Debug("Prod balancing: Prod Removed", otherPlot:GetResourceType());
			ResourceBuilder.SetResourceType(otherPlot, -1);
			return true;
		end
		if (otherPlot:GetFeatureType() == 3 and otherPlot:GetResourceCount() < 1 and rng > 0.5) then
			TerrainBuilder.SetFeatureType(otherPlot,-1);
			__Debug("Prod balancing: Wood Removed");
			return true;
		end
		if (otherPlot:GetResourceType() == 8) then
			__Debug("Prod balancing: Prod Removed", otherPlot:GetResourceType());
			ResourceBuilder.SetResourceType(otherPlot, -1);
			return true;
		end
		end
	end 	
	end
	__Debug("Prod balancing: Couldn't Remove Production through feature / resources, attempt Terrain");
	for j = 0, 17 do
		local otherPlot = GetAdjacentTiles(plot, j);
		--__Debug("Evaluate Start X: ", otherPlot:GetX(), "Evaluate Start Y: ", otherPlot:GetY(), "Terrain Type: ", terrainType);
		if otherPlot ~= nil then
		if (otherPlot:GetTerrainType() == 4 or otherPlot:GetTerrainType() == 1) and otherPlot:GetResourceType() == -1 then
			__Debug("Prod balancing: Prod Removed - Removed a Hill");
			TerrainBuilder.SetTerrainType(otherPlot, otherPlot:GetTerrainType()-1)
			return true;
		end
		end
	end
	__Debug("Prod balancing: Failed to Remove Production ");
	return false;
end

------------------------------------------------------------------------------
function RemoveFood(plot)

	local rng = TerrainBuilder.GetRandomNumber(100,"test")/100;
	if rng > 0.5 then
	for j = 0, 17 do
		local otherPlot = GetAdjacentTiles(plot, j);
		--__Debug("Evaluate Start X: ", otherPlot:GetX(), "Evaluate Start Y: ", otherPlot:GetY(), "Terrain Type: ", terrainType);
		if otherPlot ~= nil then
			if (otherPlot:GetResourceType() == 0 or otherPlot:GetResourceType() == 1 or otherPlot:GetResourceType() == 6 or otherPlot:GetResourceType() == 9) then
				__Debug("Food balancing: Food Removed", otherPlot:GetResourceType());
				ResourceBuilder.SetResourceType(otherPlot, -1);
				return true;
			end
			if ((otherPlot:GetFeatureType() == 2 or otherPlot:GetFeatureType() == 5)and otherPlot:GetResourceCount() < 1) then
				TerrainBuilder.SetFeatureType(otherPlot,-1);
				__Debug("Food balancing: Jungle/Marsh Removed");
				return true;
			end
		end
	end 
	else
	for j = 17, 0,-1 do
		local otherPlot = GetAdjacentTiles(plot, j);
		--__Debug("Evaluate Start X: ", otherPlot:GetX(), "Evaluate Start Y: ", otherPlot:GetY(), "Terrain Type: ", terrainType);
		if otherPlot ~= nil then
			if ((otherPlot:GetFeatureType() == 2 or otherPlot:GetFeatureType() == 5)and otherPlot:GetResourceCount() < 1) then
				TerrainBuilder.SetFeatureType(otherPlot,-1);
				__Debug("Food balancing: Jungle/Marsh Removed");
				return true;
			end
			if (otherPlot:GetResourceType() == 0 or otherPlot:GetResourceType() == 1 or otherPlot:GetResourceType() == 6 or otherPlot:GetResourceType() == 9) then
				__Debug("Food balancing: Food Removed", otherPlot:GetResourceType());
				ResourceBuilder.SetResourceType(otherPlot, -1);
				return true;
			end
		end
	end 
	end
	__Debug("Food balancing: Couldn't Remove Food");
	return false;
end

------------------------------------------------------------------------------
function Terraforming_BanLux(plot)
	for j = 0, 6 do
		local otherPlot = GetAdjacentTiles(plot, j);
      local adjX = -5
      local adjY = -5
      
      if (otherPlot ~= nil) then
         adjX = otherPlot:GetX();
         adjY = otherPlot:GetY();
      end
		if otherPlot ~= nil then
			__Debug("Check Luxury Start X: ", otherPlot:GetX(), "Evaluate Start Y: ", otherPlot:GetY(), "Resource Type: ",otherPlot:GetResourceType());
			if (otherPlot:GetResourceType() == 31 or otherPlot:GetResourceType() == 33 or otherPlot:GetResourceType() == 16 or otherPlot:GetResourceType() == 12 or otherPlot:GetResourceType() == 25) then
				__Debug("Luxury balancing: Banned Luxury Removed", otherPlot:GetResourceType());
				--ResourceBuilder.SetResourceType(otherPlot, -1);
            terraformBBS(adjX, adjY, -2, -1, -2)
			end
		end
	end 
	for j = 0, 30 do
		local otherPlot = GetAdjacentTiles(plot, j);
		if otherPlot ~= nil then
			__Debug("Check Luxury Start X: ", otherPlot:GetX(), "Evaluate Start Y: ", otherPlot:GetY(), "Resource Type: ",otherPlot:GetResourceType());
			if (otherPlot:GetResourceType() == 11 or otherPlot:GetResourceType() == 27 or otherPlot:GetResourceType() == 28) then
				__Debug("Luxury balancing: Banned Luxury Removed", otherPlot:GetResourceType());
				--ResourceBuilder.SetResourceType(otherPlot, -1);
            terraformBBS(adjX, adjY, -2, -1, -2)
			end
		end
	end 
end
------------------------------------------------------------------------------

function BalanceStrategic(plot)
	local iResourcesInDB = 0;
	local iStartEra = GameInfo.Eras[ GameConfiguration.GetStartEra() ];
	local iStartIndex = 1;
	local direction = 0;

	if iStartEra ~= nil then
		iStartIndex = iStartEra.ChronologyIndex;
	end
   
   local i = plot:GetX()
   local j = plot:GetY()

-- 40 Aluminium
-- 41 Coal
-- 42 Horse
-- 43 Iron
-- 44 Niter
-- 45 Oil
-- 46 Uranium

   if MapConfiguration.GetValue("BBSStratRes") == 3 then
      local ring1 = getRing(i, j, 1, mapXSize, mapYSize, mapIsRoundWestEast);
      local ring2 = getRing(i, j, 2, mapXSize, mapYSize, mapIsRoundWestEast);
      local ring3 = getRing(i, j, 3, mapXSize, mapYSize, mapIsRoundWestEast);
      local ring4 = getRing(i, j, 4, mapXSize, mapYSize, mapIsRoundWestEast);
      local ring5 = getRing(i, j, 5, mapXSize, mapYSize, mapIsRoundWestEast);
      
      local ring13 = {};
      local count13 = 0;
      local ring15 = {};
      local count15 = 0;
      
      for _, element in ipairs(ring1) do
         local x = element[1];
         local y = element[2];
         table.insert(ring13, {x, y});
         table.insert(ring15, {x, y});
         count13 = count13 + 1;
         count15 = count15 + 1;
      end
      
      for _, element in ipairs(ring2) do
         local x = element[1];
         local y = element[2];
         table.insert(ring13, {x, y});
         table.insert(ring15, {x, y});
         count13 = count13 + 1;
         count15 = count15 + 1;
      end
      
      for _, element in ipairs(ring3) do
         local x = element[1];
         local y = element[2];
         table.insert(ring13, {x, y});
         table.insert(ring15, {x, y});
         count13 = count13 + 1;
         count15 = count15 + 1;
      end
      
      for _, element in ipairs(ring4) do
         local x = element[1];
         local y = element[2];
         table.insert(ring15, {x, y});
         count15 = count15 + 1;
      end
      
      for _, element in ipairs(ring5) do
         local x = element[1];
         local y = element[2];
         table.insert(ring15, {x, y});
         count15 = count15 + 1;
      end
      
      ring13 = GetShuffledCopyOfTable(ring13);
      ring15 = GetShuffledCopyOfTable(ring15);
      
      -- Checking is strats are there
      
      local isIron = false;
      local isHorse = false;
      local isAluminium = false;
      local isCoal = false;
      local isNiter = false;
      local isOil = false;
      local isUranium = false;
      
      for _, element in ipairs(ring13) do
         local x = element[1];
         local y = element[2];
         
         if (mapResourceCode[x + 1][y + 1] == 42) then
            isHorse = true;
            __Debug("Found horse R3:", x, y);
         end
         
         if (mapResourceCode[x + 1][y + 1] == 43) then
            isIron = true;
            __Debug("Found Iron R3:", x, y);
         end
      end
      
      for _, element in ipairs(ring15) do
         local x = element[1];
         local y = element[2];
         
         if (mapResourceCode[x + 1][y + 1] == 40) then
            isAluminium = true;
            __Debug("Found Aluminium R5:", x, y);
         end
         
         if (mapResourceCode[x + 1][y + 1] == 41) then
            isCoal = true;
            __Debug("Found Coal R5:", x, y);
         end
         
         if (mapResourceCode[x + 1][y + 1] == 44) then
            isNiter = true;
            __Debug("Found Niter R5:", x, y);
         end
         
         if (mapResourceCode[x + 1][y + 1] == 45) then
            isOil = true;
            __Debug("Found Oil R5:", x, y);
         end
         
         if (mapResourceCode[x + 1][y + 1] == 46) then
            isUranium = true;
            __Debug("Found Uranium R5:", x, y);
         end
      end
      
      if (isIron == false) then
         for _, element in ipairs(ring13) do
            local x = element[1];
            local y = element[2];
            
            local xIndex = x + 1;
            local yIndex = y + 1;
            
            local featureTile = mapFeatureCode[xIndex][yIndex];
            local terrainTile = mapTerrainCode[xIndex][yIndex];
            local resourceTile = mapResourceCode[xIndex][yIndex];
            
            -- we can put an Iron here (not water, not floodplain, not a mountain, not a resource
            if (terrainTile < 15 and featureTile ~= 0 and featureTile ~= 31 and featureTile ~= 32 and terrainTile % 3 ~= 2 and resourceTile == -1) then
               
               local localPlot = Map.GetPlot(x, y)
               
               TerrainBuilder.SetFeatureType(localPlot, -1);
               mapFeatureCode[xIndex][yIndex] = -1;
               
               
               if (terrainTile % 3 == 0) then -- flat tile -> to hill
                  TerrainBuilder.SetTerrainType(localPlot, terrainTile + 1);
                  mapTerrainCode[xIndex][yIndex] = terrainTile + 1
               end
               
               ResourceBuilder.SetResourceType(localPlot, 43, 1);
               mapResourceCode[xIndex][yIndex] = 43;
               
               mapGoldYield[xIndex][yIndex] = 0;
               mapScienceYield[xIndex][yIndex] = 0;
               mapCultureYield[xIndex][yIndex] = 0;
               mapFaithYield[xIndex][yIndex] = 0;
               
               if (terrainTile == 1) then
                  mapFoodYield[xIndex][yIndex] = 2;
                  mapProdYield[xIndex][yIndex] = 1;
               elseif (terrainTile == 4) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 2;
               elseif (terrainTile == 11) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 1;
               else --snow, desert
                  mapFoodYield[xIndex][yIndex] = 0;
                  mapProdYield[xIndex][yIndex] = 1;
               end
               
               isIron = true;
               __Debug("Iron placed in", x, y);
               break;
            end
         end
      end
      
      if (isIron == false) then
         __Debug("Warning, could not add an iron !");
      end
      
      if (isHorse == false) then
         for _, element in ipairs(ring13) do
            local x = element[1];
            local y = element[2];
            
            local xIndex = x + 1;
            local yIndex = y + 1;
            
            local featureTile = mapFeatureCode[xIndex][yIndex];
            local terrainTile = mapTerrainCode[xIndex][yIndex];
            local resourceTile = mapResourceCode[xIndex][yIndex];
            
            -- we can put an Iron here (not water, plain or grassland, not floodplain, not a mountain, not a resource
            if (terrainTile < 5 and featureTile ~= 0 and featureTile ~= 31 and featureTile ~= 32 and terrainTile % 3 ~= 2 and resourceTile == -1) then
               
               local localPlot = Map.GetPlot(x, y)
               
               -- cleaning feature
               TerrainBuilder.SetFeatureType(localPlot, -1);
               mapFeatureCode[xIndex][yIndex] = -1;
               
               if (terrainTile % 3 == 1) then -- hill tile -> to flat
                  TerrainBuilder.SetTerrainType(localPlot, terrainTile - 1);
                  mapTerrainCode[xIndex][yIndex] = terrainTile - 1
               end
               
               ResourceBuilder.SetResourceType(localPlot, 42, 1);
               mapResourceCode[xIndex][yIndex] = 42;
               
               mapGoldYield[xIndex][yIndex] = 0;
               mapScienceYield[xIndex][yIndex] = 0;
               mapCultureYield[xIndex][yIndex] = 0;
               mapFaithYield[xIndex][yIndex] = 0;
               
               if (terrainTile == 0) then
                  mapFoodYield[xIndex][yIndex] = 2;
                  mapProdYield[xIndex][yIndex] = 0;
               else
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 1;
               end
               
               isHorse = true;
               __Debug("Horse placed in", x, y);
               break;
            end
         end
      end
      
      if (isHorse == false) then
         __Debug("Warning, could not add a horse !");
      end
      
      if (isNiter == false) then
         for _, element in ipairs(ring15) do
            local x = element[1];
            local y = element[2];
            
            local xIndex = x + 1;
            local yIndex = y + 1;
            
            local featureTile = mapFeatureCode[xIndex][yIndex];
            local terrainTile = mapTerrainCode[xIndex][yIndex];
            local resourceTile = mapResourceCode[xIndex][yIndex];
            
            -- we can put a Niter here (not water, not snow, not a mountain, not a resource
            if (terrainTile < 11 and terrainTile % 3 ~= 2 and resourceTile == -1) then
               
               local localPlot = Map.GetPlot(x, y)
               
               -- cleaning feature
               if (featureTile ~= -1 and featureTile ~= 0) then
                  TerrainBuilder.SetFeatureType(localPlot, -1);
                  mapFeatureCode[xIndex][yIndex] = -1;
               end
               
               if (terrainTile % 3 == 1) then -- hill tile -> to flat
                  TerrainBuilder.SetTerrainType(localPlot, terrainTile - 1);
                  mapTerrainCode[xIndex][yIndex] = terrainTile - 1
               end
               
               ResourceBuilder.SetResourceType(localPlot, 44, 1);
               mapResourceCode[xIndex][yIndex] = 44;
               
               mapGoldYield[xIndex][yIndex] = 0;
               mapScienceYield[xIndex][yIndex] = 0;
               mapCultureYield[xIndex][yIndex] = 0;
               mapFaithYield[xIndex][yIndex] = 0;
               
               if (terrainTile == 0) then
                  mapFoodYield[xIndex][yIndex] = 2;
                  mapProdYield[xIndex][yIndex] = 0;
               elseif (terrainTile == 3) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 1;
               elseif (terrainTile == 6) then
                  mapFoodYield[xIndex][yIndex] = 0;
                  mapProdYield[xIndex][yIndex] = 0;
               elseif (terrainTile == 9) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 0;
               end
               
               isNiter = true;
               __Debug("Niter placed in", x, y);
               break;
            end
         end
      end
      
      if (isNiter == false) then
         __Debug("Warning, could not add a Niter !");
      end
      
      
      if (isCoal == false) then
         for _, element in ipairs(ring15) do
            local x = element[1];
            local y = element[2];
            
            local xIndex = x + 1;
            local yIndex = y + 1;
            
            local featureTile = mapFeatureCode[xIndex][yIndex];
            local terrainTile = mapTerrainCode[xIndex][yIndex];
            local resourceTile = mapResourceCode[xIndex][yIndex];
            
            -- we can put an Iron here (not water, plain or grassland, not floodplain, not a mountain, not a resource
            if (terrainTile < 5 and featureTile ~= 0 and featureTile ~= 31 and featureTile ~= 32 and terrainTile % 3 ~= 2 and resourceTile == -1) then
               
               local localPlot = Map.GetPlot(x, y)
               
               -- cleaning feature
               if (featureTile ~= -1 and featureTile ~= 3) then
                  TerrainBuilder.SetFeatureType(localPlot, -1);
                  mapFeatureCode[xIndex][yIndex] = -1;
               end
               
               if (terrainTile % 3 == 0) then -- flat tile -> to hill
                  TerrainBuilder.SetTerrainType(localPlot, terrainTile + 1);
                  mapTerrainCode[xIndex][yIndex] = terrainTile + 1
               end
               
               ResourceBuilder.SetResourceType(localPlot, 41, 1);
               mapResourceCode[xIndex][yIndex] = 41;
               
               mapGoldYield[xIndex][yIndex] = 0;
               mapScienceYield[xIndex][yIndex] = 0;
               mapCultureYield[xIndex][yIndex] = 0;
               mapFaithYield[xIndex][yIndex] = 0;
               
               if (terrainTile == 1) then
                  mapFoodYield[xIndex][yIndex] = 2;
                  mapProdYield[xIndex][yIndex] = 1;
               else
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 2;
               end
               
               isCoal = true;
               __Debug("Coal placed in", x, y);
               break;
            end
         end
      end
      
      if (isCoal == false) then
         __Debug("Warning, could not add a Coal !");
      end
      
      if (isAluminium == false) then
         for _, element in ipairs(ring15) do
            local x = element[1];
            local y = element[2];
            
            local xIndex = x + 1;
            local yIndex = y + 1;
            
            local featureTile = mapFeatureCode[xIndex][yIndex];
            local terrainTile = mapTerrainCode[xIndex][yIndex];
            local resourceTile = mapResourceCode[xIndex][yIndex];
            
            -- we can put an alumnium here (not water, plain or desert, not floodplain, not a mountain, not a resource
            if ((terrainTile > 2 and terrainTile < 9) and featureTile ~= 0 and featureTile ~= 31 and featureTile ~= 32 and terrainTile % 3 ~= 2 and resourceTile == -1) then
               
               local localPlot = Map.GetPlot(x, y)
               
               -- cleaning feature
               if (featureTile ~= -1 and featureTile ~= 2) then
                  TerrainBuilder.SetFeatureType(localPlot, -1);
                  mapFeatureCode[xIndex][yIndex] = -1;
               end
               
               if (terrainTile == 4) then -- hill tile -> to flat
                  TerrainBuilder.SetTerrainType(localPlot, terrainTile - 1);
                  mapTerrainCode[xIndex][yIndex] = terrainTile - 1
               end
               
               ResourceBuilder.SetResourceType(localPlot, 40, 1);
               mapResourceCode[xIndex][yIndex] = 40;
               
               mapGoldYield[xIndex][yIndex] = 0;
               mapScienceYield[xIndex][yIndex] = 0;
               mapCultureYield[xIndex][yIndex] = 0;
               mapFaithYield[xIndex][yIndex] = 0;
               
               if (terrainTile == 3) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 1;
               elseif (terrainTile == 7) then
                  mapFoodYield[xIndex][yIndex] = 0;
                  mapProdYield[xIndex][yIndex] = 1;
               else
                  mapFoodYield[xIndex][yIndex] = 0;
                  mapProdYield[xIndex][yIndex] = 0;
               end
               
               if (featureTile == 2) then
                  mapFoodYield[xIndex][yIndex] = mapFoodYield[xIndex][yIndex] + 1;
               end
               
               isAluminium = true;
               __Debug("Aluminium placed in", x, y);
               break;
            end
         end
      end
      
      if (isAluminium == false) then
         __Debug("Warning, could not add a Coal !");
      end

      if (isUranium == false) then
         for _, element in ipairs(ring15) do
            local x = element[1];
            local y = element[2];
            
            local xIndex = x + 1;
            local yIndex = y + 1;
            
            local featureTile = mapFeatureCode[xIndex][yIndex];
            local terrainTile = mapTerrainCode[xIndex][yIndex];
            local resourceTile = mapResourceCode[xIndex][yIndex];
            
            -- we can put an Uranium here (not water, plain or grassland, not floodplain, not a mountain, not a resource
            if (terrainTile < 15 and featureTile ~= 0 and featureTile ~= 31 and featureTile ~= 32 and terrainTile % 3 ~= 2 and resourceTile == -1) then
               
               local localPlot = Map.GetPlot(x, y)
               
               -- cleaning feature
               if (featureTile ~= -1 and featureTile ~= 2 and featureTile ~= 3) then
                  TerrainBuilder.SetFeatureType(localPlot, -1);
                  mapFeatureCode[xIndex][yIndex] = -1;
               end
               
               ResourceBuilder.SetResourceType(localPlot, 46, 1);
               mapResourceCode[xIndex][yIndex] = 46;
               
               mapGoldYield[xIndex][yIndex] = 0;
               mapScienceYield[xIndex][yIndex] = 0;
               mapCultureYield[xIndex][yIndex] = 0;
               mapFaithYield[xIndex][yIndex] = 0;
               
               if (terrainTile == 0) then
                  mapFoodYield[xIndex][yIndex] = 2;
                  mapProdYield[xIndex][yIndex] = 0;
               elseif (terrainTile == 1) then
                  mapFoodYield[xIndex][yIndex] = 2;
                  mapProdYield[xIndex][yIndex] = 1;
               elseif (terrainTile == 3) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 1;
               elseif (terrainTile == 4) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 2;
               elseif (terrainTile == 6) then
                  mapFoodYield[xIndex][yIndex] = 0;
                  mapProdYield[xIndex][yIndex] = 0;
               elseif (terrainTile == 7) then
                  mapFoodYield[xIndex][yIndex] = 0;
                  mapProdYield[xIndex][yIndex] = 1;
               elseif (terrainTile == 9) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 0;
               elseif (terrainTile == 10) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 1;
               elseif (terrainTile == 12) then
                  mapFoodYield[xIndex][yIndex] = 0;
                  mapProdYield[xIndex][yIndex] = 0;
               elseif (terrainTile == 13) then
                  mapFoodYield[xIndex][yIndex] = 0;
                  mapProdYield[xIndex][yIndex] = 1;
               end
               
               if (featureTile == 2) then
                  mapFoodYield[xIndex][yIndex] = mapFoodYield[xIndex][yIndex] + 1;
               end
               
               if (featureTile == 3) then
                  mapProdYield[xIndex][yIndex] = mapProdYield[xIndex][yIndex] + 1;
               end
               
               isUranium = true;
               __Debug("Uranium placed in", x, y);
               break;
            end
         end
      end
      
      if (isUranium == false) then
         __Debug("Warning, could not add a Uranium !");
      end
      
      if (isOil == false) then
         for _, element in ipairs(ring15) do
            local x = element[1];
            local y = element[2];
            
            local xIndex = x + 1;
            local yIndex = y + 1;
            
            local featureTile = mapFeatureCode[xIndex][yIndex];
            local terrainTile = mapTerrainCode[xIndex][yIndex];
            local resourceTile = mapResourceCode[xIndex][yIndex];
            
            -- we can put a oil here (not water, not snow, not a mountain, not a resource
            if (terrainTile < 15 and terrainTile % 3 ~= 2 and resourceTile == -1) then
               
               local localPlot = Map.GetPlot(x, y)
               
               -- cleaning feature
               if (featureTile ~= -1 and featureTile ~= 0 and featureTile ~= 31 and featureTile ~= 32 and featureTile ~= 5) then
                  TerrainBuilder.SetFeatureType(localPlot, -1);
                  mapFeatureCode[xIndex][yIndex] = -1;
               end
               
               if (terrainTile % 3 == 1) then -- hill tile -> to flat
                  TerrainBuilder.SetTerrainType(localPlot, terrainTile - 1);
                  mapTerrainCode[xIndex][yIndex] = terrainTile - 1
                  terrainTile = terrainTile - 1;
               end
               
               if (terrainTile == 0 and featureTile ~= 31) then
                  TerrainBuilder.SetFeatureType(localPlot, 5, 1);
                  featureTile = 5;
                  mapFeatureCode[xIndex][yIndex] = 5;
               end
               
               
               ResourceBuilder.SetResourceType(localPlot, 45, 1);
               mapResourceCode[xIndex][yIndex] = 45;
               
               mapGoldYield[xIndex][yIndex] = 0;
               mapScienceYield[xIndex][yIndex] = 0;
               mapCultureYield[xIndex][yIndex] = 0;
               mapFaithYield[xIndex][yIndex] = 0;
               
               if (terrainTile == 0) then
                  mapFoodYield[xIndex][yIndex] = 2;
                  mapProdYield[xIndex][yIndex] = 0;
               elseif (terrainTile == 1) then
                  mapFoodYield[xIndex][yIndex] = 2;
                  mapProdYield[xIndex][yIndex] = 1;
               elseif (terrainTile == 3) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 1;
               elseif (terrainTile == 4) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 2;
               elseif (terrainTile == 6) then
                  mapFoodYield[xIndex][yIndex] = 0;
                  mapProdYield[xIndex][yIndex] = 0;
               elseif (terrainTile == 7) then
                  mapFoodYield[xIndex][yIndex] = 0;
                  mapProdYield[xIndex][yIndex] = 1;
               elseif (terrainTile == 9) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 0;
               elseif (terrainTile == 10) then
                  mapFoodYield[xIndex][yIndex] = 1;
                  mapProdYield[xIndex][yIndex] = 1;
               elseif (terrainTile == 12) then
                  mapFoodYield[xIndex][yIndex] = 0;
                  mapProdYield[xIndex][yIndex] = 0;
               elseif (terrainTile == 13) then
                  mapFoodYield[xIndex][yIndex] = 0;
                  mapProdYield[xIndex][yIndex] = 1;
               end
               
               if (featureTile == 5) then
                  mapFoodYield[xIndex][yIndex] = mapFoodYield[xIndex][yIndex] + 1;
               end
               
               isOil = true;
               __Debug("Oil placed in", x, y);
               break;
            end
         end
      end
      
      if (isOil == false) then
         __Debug("Warning, could not add a Oil !");
      end
      
   

--[[
	if MapConfiguration.GetValue("BBSStratRes") == 3 then

		for k =0, 6 do
			local bHasResource = false;
			__Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check for ",40+k," Garanteed");
			if k == 2 or k == 3 then
				bHasResource = FindResource(40+k, plot,30);
				else
				bHasResource = FindResource(40+k, plot);
			end
			if(bHasResource == false) then
				__Debug("Balance Resources: Need to add", 40+k);
				PlaceResource(40+k, plot);
			end
		end
	--]]	
   else
	
		if (iStartIndex == 1) then
         local bHasResource = false;
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Horse");
         bHasResource = FindResource(42, plot,30);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Horses");
            PlaceResource(42, plot);
         end
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Iron");
         bHasResource = FindResource(43, plot,30);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Iron");
            PlaceResource(43, plot);
         end
         -- Broader Check Oil & Niter & Aluminium + Coal
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Oil");
         bHasResource = ContinentResource(45, plot);	
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Iron");
            PlaceResource(45, plot);
         end		
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Niter");
         bHasResource = FindResource(44, plot, 100);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Niter");
            PlaceResource(44, plot);
         end
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Aluminium");
         bHasResource = ContinentResource(40, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Aluminium");
            PlaceResource(40, plot);
         end
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Coal");
         bHasResource = ContinentResource(41, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Coal");
            PlaceResource(41, plot);
		end
		
	-- Classical or Medieval
		elseif (iStartIndex == 2 or iStartIndex == 3) then
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Horse");
         bHasResource = FindResource(42, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Horses");
            PlaceResource(42, plot);
         end
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Iron");
         bHasResource = FindResource(43, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Iron");
            PlaceResource(43, plot);
         end
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Niter");
         bHasResource = FindResource(44, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Niter");
            PlaceResource(44, plot);
         end
         -- Broader Check Oil & Aluminium + Coal
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Oil");
         bHasResource = ContinentResource(45, plot);	
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Iron");
            PlaceResource(45, plot);
         end		
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Aluminium");
         bHasResource = ContinentResource(40, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Aluminium");
            PlaceResource(40, plot);
         end
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Coal");
         bHasResource = ContinentResource(41, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Coal");
            PlaceResource(41, plot);
		end

	-- 
		elseif (iStartIndex == 4 or iStartIndex == 5) then
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Coal");
         bHasResource = FindResource(41, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Coal");
            PlaceResource(41, plot);
         end
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Iron");
         bHasResource = FindResource(43, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Iron");
            PlaceResource(43, plot);
         end
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Niter");
         bHasResource = FindResource(44, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Niter");
            PlaceResource(44, plot);
         end
         -- Broader Check Oil & Aluminium
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Oil");
         bHasResource = ContinentResource(45, plot);	
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Iron");
            PlaceResource(45, plot);
         end		
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Aluminium");
         bHasResource = ContinentResource(40, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Aluminium");
            PlaceResource(40, plot);
		end

	--

		elseif (iStartIndex == 6) then
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Coal");
         bHasResource = FindResource(41, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Coal");
            PlaceResource(41, plot);
         end
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Oil");
         bHasResource = FindResource(45, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Niter");
            PlaceResource(45, plot);
         end
         -- Broader Aluminium
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Aluminium");
         bHasResource = ContinentResource(40, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Aluminium");
            PlaceResource(40, plot);
         end

         elseif (iStartIndex > 6) then
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Aluminium");
         bHasResource = FindResource(40, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Aluminium");
            PlaceResource(40, plot);
         end
         __Debug("Evaluate Start X: ", plot:GetX(), "Evaluate Start Y: ", plot:GetY(), "Check Oil");
         bHasResource = FindResource(45, plot);
         if(bHasResource == false) then
            __Debug("Balance Resources: Need to add Oil");
            PlaceResource(45, plot);
         end
		end
	end
   

end

------------------------------------------------------------------------------
function PlaceResource(eResourceType, plot)
	local gridWidth, gridHeight = Map.GetGridSize();
	local direction = 0;
	local adjacentPlot = nil;
	-- Place a ressource, first inner ring, then anywhere in 4 tiles


-- Inner ring
-- Tiles #6 to #17
	for i = 6, 17 do
		adjacentPlot = GetAdjacentTiles(plot, i);
		if (adjacentPlot ~= nil) then
			if(adjacentPlot:GetResourceCount() == 0) and adjacentPlot:IsNaturalWonder() == false then
				if(ResourceBuilder.CanHaveResource(adjacentPlot, eResourceType) and adjacentPlot:IsImpassable() == false) then
					ResourceBuilder.SetResourceType(adjacentPlot, eResourceType,1);
					__Debug("Evaluate Start X: ", adjacentPlot:GetX(), "Evaluate Start Y: ", adjacentPlot:GetY(), "Added: ", eResourceType);
					return true;
				end
			end

		end
	end

-- Anywhere within in a 5 tiles radius
	for i = 0, 90 do
		adjacentPlot = GetAdjacentTiles(plot, i);
		if (adjacentPlot ~= nil) then
			if(adjacentPlot:GetResourceCount() == 0) and adjacentPlot:IsNaturalWonder() == false then
				if(ResourceBuilder.CanHaveResource(adjacentPlot, eResourceType) and adjacentPlot:IsImpassable() == false) then
					ResourceBuilder.SetResourceType(adjacentPlot, eResourceType,1);
					__Debug("Evaluate Start X: ", adjacentPlot:GetX(), "Evaluate Start Y: ", adjacentPlot:GetY(), "Added: ", eResourceType);
					return true;
				end
			end

		end
	end

	__Debug("Balance Resources: Failed to Add:", eResourceType);
	return false;
end

------------------------------------------------------------------------------
function FindResource(eResourceType, plot, strength:number)
	local gridWidth, gridHeight = Map.GetGridSize();
	-- Checks to see if there is a specific strategic in a given distance
	local adjacentPlot = nil;
	if strength == nil then
		strength = 60
	end

	for i = 0, strength do
		adjacentPlot = GetAdjacentTiles(plot, i);
		if (adjacentPlot ~= nil) then
			if(adjacentPlot:GetResourceCount() > 0) then
				if(eResourceType == adjacentPlot:GetResourceType()) then
					__Debug("Evaluate Start X: ", adjacentPlot:GetX(), "Evaluate Start Y: ", adjacentPlot:GetY(), "Found Type: ", adjacentPlot:GetResourceType(),"Tile #",i,"Max Range",strength);
					return true;
				end
			end

		end

	end

	return false;
end

------------------------------------------------------------------------------
function ContinentResource(eResourceType, plot)
	local gridWidth, gridHeight = Map.GetGridSize();
	-- Checks to see if there is a specific strategic on a specific continent
	local adjacentPlot = nil;
	local ContinentNum = plot:GetContinentType()
	local ContinentPlots =  Map.GetContinentPlots(ContinentNum);
	__Debug("Check Continent:",ContinentNum," For resource:",eResourceType);
		
	for i, plot in ipairs(ContinentPlots) do
		if plot ~= nil then
			local pPlot = Map.GetPlotByIndex(plot)
			if (pPlot ~= nil) then
				if(pPlot:GetResourceCount() > 0) then
					if(eResourceType == pPlot:GetResourceType()) then
						__Debug("ContinentResource X: ", pPlot:GetX(), " Y: ", pPlot:GetY(), "Found Type: ", pPlot:GetResourceType());
						return true;
					end
				end
			end

		end

	end

	return false;
end

------------------------------------------------------------------------------
function AddLuxuryStarting(plot, s_type)
	-- Checks to see if it can place a nearby luxury
	local terrainType = plot:GetTerrainType();
	local gridWidth, gridHeight = Map.GetGridSize();
	local iResourcesInDB = 0;
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	local currentContinent = plot:GetContinentType();
	local direction = 0;
	local bHasLuxury = false;
	local adjacentPlot = plot;
	eAddLux	= {};
	eAddLux_Terrain	= {};
	eAddLux_Feature = {};
	local count = 0;

	-- Find what luxury are on the current continent
	plots = Map.GetContinentPlots(currentContinent);
	for i, plot in ipairs(plots) do

		local pPlot = Map.GetPlotByIndex(plot);
		if (pPlot~=nil) then
         if (pPlot:GetResourceCount() > 0) and pPlot:IsNaturalWonder() == false and pPlot:IsWater() == false  then
            -- 10 is citrus, 34 is jeans
            if ((pPlot:GetResourceType() >= 10 and pPlot:GetResourceType() < 34 and pPlot:GetResourceType() ~= 27 and pPlot:GetResourceType() ~= 28 and pPlot:GetResourceType() ~= 11 and s_type ~= "plains") 
            or (pPlot:GetResourceType() == 14 and pPlot:GetResourceType() == 16 and pPlot:GetResourceType() == 17 and pPlot:GetResourceType() == 26 and pPlot:GetResourceType() == 31 and s_type ~= "plains")
            or pPlot:GetResourceType() == 53) then
               bHasLuxury = true;
               --__Debug("found luxury at X",  pPlot:GetX(), "Y: ", pPlot:GetY());
               count = count + 1;
               table.insert(eAddLux, pPlot:GetResourceType());
               table.insert(eAddLux_Terrain, pPlot:GetTerrainType());
               table.insert(eAddLux_Feature, pPlot:GetFeatureType());
            end
         end
		end
		
	end

	local lower_bound = 0
	local upper_bound = 17
	-- Try placing a Luxury in the 2 inner rings

	if(bHasLuxury == true) then
		for i = lower_bound, upper_bound, 1 do
			adjacentPlot = GetAdjacentTiles(plot, i);
			if (adjacentPlot ~= nil) then
            
            local x = adjacentPlot:GetX()
            local y = adjacentPlot:GetY()
            
            local isFlood = false;
            if (mapFeatureCode[x + 1][y + 1] == 0 or mapFeatureCode[x + 1][y + 1] == 31 or mapFeatureCode[x + 1][y + 1] == 32) then
               isFlood = true;
            end
            
            local newTerrain = -2;
         
				for j = 1, count do
					if((adjacentPlot:GetTerrainType() == eAddLux_Terrain[j]) and (adjacentPlot:GetResourceType() == -1)) and adjacentPlot:IsNaturalWonder() == false and pPlot:IsWater() == false and isFlood == false then
						if (i > 5 and (eAddLux[j] == 17 or eAddLux[j] == 19)) or (eAddLux[j] ~= 17 and eAddLux[j] ~= 19) then -- very unclear
                     if (mapTerrainCode[x + 1][y + 1] == 4 and (eAddLux[j] == 17 or eAddLux[j] == 19)) then -- no gypsum/ivory on hill
                        newTerrain = 3;
                     end
                     
                     if (mapTerrainCode[x + 1][y + 1] == 0 and (eAddLux[j] == 10 or eAddLux[j] == 28 or eAddLux[j] == 53)) then -- no citrus/sugar/honey on flat grassland
                        newTerrain = 3;
                     end
                     
                     terraformBBSPlot(adjacentPlot, newTerrain, eAddLux[j], eAddLux_Feature[j]);
                     --TerrainBuilder.SetFeatureType(adjacentPlot,eAddLux_Feature[j]);
                     __Debug("Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added a Luxury:",eAddLux[j]);
                     
                     --ResourceBuilder.SetResourceType(adjacentPlot, eAddLux[j], 1);
                     return true;
						end
					end
				end
			end

		end
	end

	__Debug("Balancing X: ", plotX, "Y: ", plotY, "Failed to add a Luxury");
	
	-- Attempt to place a Maize 
		for i = 17, 0, -1 do
			adjacentPlot = GetAdjacentTiles(plot, i);
			if (adjacentPlot ~= nil) then
				for j = 1, count do
					if(adjacentPlot:GetTerrainType() == 3 or adjacentPlot:GetTerrainType() == 0) and (adjacentPlot:GetResourceType() == -1) and adjacentPlot:GetFeatureType() == -1 and adjacentPlot:IsNaturalWonder() == false and pPlot:IsWater() == false then
						__Debug("Balancing X: ", adjacentPlot:GetX(), "Y: ", adjacentPlot:GetY(), "Added a Maize");
						ResourceBuilder.SetResourceType(adjacentPlot, 52, 1);
						return true;
					end
				end
			end

		end	
	
	
	return false;
end


-------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------
function IsTundraCiv(civilizationType)
    for row in GameInfo.StartBiasTerrains() do
        if(row.CivilizationType == civilizationType) then
			if row.TerrainType ~= nil then
				if row.TerrainType == "TERRAIN_TUNDRA" then
					return true
				end
			end
        end
    end
	for _, row in ipairs(g_custom_bias) do
        if(row.CivilizationType == civilizationType) then
			if row.CustomPlacement == "CUSTOM_KING_OF_THE_NORTH" then
				return true
			end			
        end
    end
	return false
end

------------------------------------------------------------------------------
function IsDesertCiv(civilizationType)
    for row in GameInfo.StartBiasTerrains() do
        if(row.CivilizationType == civilizationType) then
			if row.TerrainType ~= nil then
				if row.TerrainType == "TERRAIN_DESERT" then
					return true
				end
			end
        end
    end
	return false
end
------------------------------------------------------------------------------
function IsMountainCiv(civilizationType)
    for row in GameInfo.StartBiasTerrains() do
        if(row.CivilizationType == civilizationType) then
				if row.TerrainType ~= nil then
				if row.TerrainType == "TERRAIN_GRASS_MOUNTAIN" then
					return true
				end
			end
        end
    end
	for _, row in ipairs(g_custom_bias) do
        if(row.CivilizationType == civilizationType) then
			if row.CustomPlacement == "CUSTOM_MOUNTAIN_LOVER" then
				return true
			end			
        end
    end
	return false
end
------------------------------------------------------------------------------
function IsSaltyCiv(civilizationType)
	for _, row in ipairs(g_custom_bias) do
        if(row.CivilizationType == civilizationType) then
			if row.CustomPlacement == "CUSTOM_I_AM_SALTY" then
				return true
			end			
        end
    end
	return false
end

------------------------------------------------------------------------------
function IsDryCiv(civilizationType)
	for _, row in ipairs(g_custom_bias) do
        if(row.CivilizationType == civilizationType) then
			if row.CustomPlacement == "CUSTOM_NO_FRESH_WATER" then
				return true
			end			
        end
    end
	return false
end

------------------------------------------------------------------------------
function IsFloodCiv(civilizationType)
    for row in GameInfo.StartBiasFeatures() do
        if(row.CivilizationType == civilizationType) then
			if row.FeatureType ~= nil then
				if row.FeatureType == "FEATURE_FLOODPLAINS" or row.FeatureType == "FEATURE_FLOODPLAINS_GRASSLAND" or row.FeatureType == "FEATURE_FLOODPLAINS_PLAINS" then
					return true
				end
			end
        end
    end
	return false
end

function GetAdjacentTiles(plot, index)
	-- This is an extended version of Firaxis, moving like a clockwise snail on the hexagon grids
	local gridWidth, gridHeight = Map.GetGridSize();
	local count = 0;
	local k = 0;
	local adjacentPlot = nil;
	local adjacentPlot2 = nil;
	local adjacentPlot3 = nil;
	local adjacentPlot4 = nil;
	local adjacentPlot5 = nil;


	-- Return Spawn if index < 0
	if(plot ~= nil and index ~= nil) then
		if (index < 0) then
			return plot;
		end

		else

		__Debug("GetAdjacentTiles: Invalid Arguments");
		return nil;
	end

	

	-- Return Starting City Circle if index between #0 to #5 (like Firaxis' GetAdjacentPlot) 
	for i = 0, 5 do
		if(plot:GetX() >= 0 and plot:GetY() < gridHeight) then
			adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), i);
			if (adjacentPlot ~= nil and index == i) then
				return adjacentPlot
			end
		end
	end

	-- Return Inner City Circle if index between #6 to #17

	count = 5;
	for i = 0, 5 do
		if(plot:GetX() >= 0 and plot:GetY() < gridHeight) then
			adjacentPlot2 = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), i);
		end

		for j = i, i+1 do
			--__Debug(i, j)
			k = j;
			count = count + 1;

			if (k == 6) then
				k = 0;
			end

			if (adjacentPlot2 ~= nil) then
				if(adjacentPlot2:GetX() >= 0 and adjacentPlot2:GetY() < gridHeight) then
					adjacentPlot = Map.GetAdjacentPlot(adjacentPlot2:GetX(), adjacentPlot2:GetY(), k);

					else

					adjacentPlot = nil;
				end
			end
		

			if (adjacentPlot ~=nil) then
				if(index == count) then
					return adjacentPlot
				end
			end

		end
	end

	-- #18 to #35 Outer city circle
	count = 0;
	for i = 0, 5 do
		if(plot:GetX() >= 0 and plot:GetY() < gridHeight) then
			adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), i);
			adjacentPlot2 = nil;
			adjacentPlot3 = nil;
			else
			adjacentPlot = nil;
			adjacentPlot2 = nil;
			adjacentPlot3 = nil;
		end
		if (adjacentPlot ~=nil) then
			if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
				adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), i);
			end
			if (adjacentPlot3 ~= nil) then
				if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
					adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), i);
				end
			end
		end

		if (adjacentPlot2 ~= nil) then
			count = 18 + i * 3;
			if(index == count) then
				return adjacentPlot2
			end
		end

		adjacentPlot2 = nil;

		if (adjacentPlot3 ~= nil) then
			if (i + 1) == 6 then
				if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
					adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), 0);
				end
				else
				if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
					adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), i +1);
				end
			end
		end

		if (adjacentPlot2 ~= nil) then
			count = 18 + i * 3 + 1;
			if(index == count) then
				return adjacentPlot2
			end
		end

		adjacentPlot2 = nil;

		if (adjacentPlot ~= nil) then
			if (i+1 == 6) then
				if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
					adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), 0);
				end
				if (adjacentPlot3 ~= nil) then
					if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
						adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), 0);
					end
				end
				else
				if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
					adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), i+1);
				end
				if (adjacentPlot3 ~= nil) then
					if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
						adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), i+1);
					end
				end
			end
		end

		if (adjacentPlot2 ~= nil) then
			count = 18 + i * 3 + 2;
			if(index == count) then
				return adjacentPlot2;
			end
		end

	end

	--  #35 #59 These tiles are outside the workable radius of the city
	local count = 0
	for i = 0, 5 do
		if(plot:GetX() >= 0 and plot:GetY() < gridHeight) then
			adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), i);
			adjacentPlot2 = nil;
			adjacentPlot3 = nil;
			adjacentPlot4 = nil;
			else
			adjacentPlot = nil;
			adjacentPlot2 = nil;
			adjacentPlot3 = nil;
			adjacentPlot4 = nil;
		end
		if (adjacentPlot ~=nil) then
			if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
				adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), i);
			end
			if (adjacentPlot3 ~= nil) then
				if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
					adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), i);
					if (adjacentPlot4 ~= nil) then
						if(adjacentPlot4:GetX() >= 0 and adjacentPlot4:GetY() < gridHeight) then
							adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot4:GetX(), adjacentPlot4:GetY(), i);
						end
					end
				end
			end
		end

		if (adjacentPlot2 ~= nil) then
			terrainType = adjacentPlot2:GetTerrainType();
			if (adjacentPlot2 ~=nil) then
				count = 36 + i * 4;
				if(index == count) then
					return adjacentPlot2;
				end
			end

		end

		if (adjacentPlot3 ~= nil) then
			if (i + 1) == 6 then
				if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
					adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), 0);
				end
				else
				if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
					adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), i +1);
				end
			end
		end

		if (adjacentPlot4 ~= nil) then
			if(adjacentPlot4:GetX() >= 0 and adjacentPlot4:GetY() < gridHeight) then
				adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot4:GetX(), adjacentPlot4:GetY(), i);
				if (adjacentPlot2 ~= nil) then
					count = 36 + i * 4 + 1;
					if(index == count) then
						return adjacentPlot2;
					end
				end
			end


		end

		adjacentPlot4 = nil;

		if (adjacentPlot ~= nil) then
			if (i+1 == 6) then
				if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
					adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), 0);
				end
				if (adjacentPlot3 ~= nil) then
					if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
						adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), 0);
					end
				end
				else
				if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
					adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), i+1);
				end
				if (adjacentPlot3 ~= nil) then
					if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
						adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), i+1);
					end
				end
			end
		end

		if (adjacentPlot4 ~= nil) then
			if (adjacentPlot4:GetX() >= 0 and adjacentPlot4:GetY() < gridHeight) then
				adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot4:GetX(), adjacentPlot4:GetY(), i);
				if (adjacentPlot2 ~= nil) then
					count = 36 + i * 4 + 2;
					if(index == count) then
						return adjacentPlot2;
					end

				end
			end

		end

		adjacentPlot4 = nil;

		if (adjacentPlot ~= nil) then
			if (i+1 == 6) then
				if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
					adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), 0);
				end
				if (adjacentPlot3 ~= nil) then
					if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
						adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), 0);
					end
				end
				else
				if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
					adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), i+1);
				end
				if (adjacentPlot3 ~= nil) then
					if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
						adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), i+1);
					end
				end
			end
		end

		if (adjacentPlot4 ~= nil) then
			if (adjacentPlot4:GetX() >= 0 and adjacentPlot4:GetY() < gridHeight) then
				if (i+1 == 6) then
					adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot4:GetX(), adjacentPlot4:GetY(), 0);
					else
					adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot4:GetX(), adjacentPlot4:GetY(), i+1);
				end
				if (adjacentPlot2 ~= nil) then
					count = 36 + i * 4 + 3;
					if(index == count) then
						return adjacentPlot2;
					end

				end
			end

		end

	end

	--  > #60 to #90

local count = 0
	for i = 0, 5 do
		if(plot:GetX() >= 0 and plot:GetY() < gridHeight) then
			adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), i); --first ring
			adjacentPlot2 = nil;
			adjacentPlot3 = nil;
			adjacentPlot4 = nil;
			adjacentPlot5 = nil;
			else
			adjacentPlot = nil;
			adjacentPlot2 = nil;
			adjacentPlot3 = nil;
			adjacentPlot4 = nil;
			adjacentPlot5 = nil;
		end
		if (adjacentPlot ~=nil) then
			if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
				adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), i); --2nd ring
			end
			if (adjacentPlot3 ~= nil) then
				if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
					adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), i); --3rd ring
					if (adjacentPlot4 ~= nil) then
						if(adjacentPlot4:GetX() >= 0 and adjacentPlot4:GetY() < gridHeight) then
							adjacentPlot5 = Map.GetAdjacentPlot(adjacentPlot4:GetX(), adjacentPlot4:GetY(), i); --4th ring
							if (adjacentPlot5 ~= nil) then
								if(adjacentPlot5:GetX() >= 0 and adjacentPlot5:GetY() < gridHeight) then
									adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot5:GetX(), adjacentPlot5:GetY(), i); --5th ring
								end
							end
						end
					end
				end
			end
		end

		if (adjacentPlot2 ~= nil) then
			count = 60 + i * 5;
			if(index == count) then
				return adjacentPlot2; --5th ring
			end
		end

		adjacentPlot2 = nil;

		if (adjacentPlot5 ~= nil) then
			if (i + 1) == 6 then
				if(adjacentPlot5:GetX() >= 0 and adjacentPlot5:GetY() < gridHeight) then
					adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot5:GetX(), adjacentPlot5:GetY(), 0);
				end
				else
				if(adjacentPlot5:GetX() >= 0 and adjacentPlot5:GetY() < gridHeight) then
					adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot5:GetX(), adjacentPlot5:GetY(), i +1);
				end
			end
		end


		if (adjacentPlot2 ~= nil) then
			count = 60 + i * 5 + 1;
			if(index == count) then
				return adjacentPlot2;
			end

		end

		adjacentPlot2 = nil;

		if (adjacentPlot ~=nil) then
			if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
				adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), i);
			end
			if (adjacentPlot3 ~= nil) then
				if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
					adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), i);
					if (adjacentPlot4 ~= nil) then
						if(adjacentPlot4:GetX() >= 0 and adjacentPlot4:GetY() < gridHeight) then
							if (i+1 == 6) then
								adjacentPlot5 = Map.GetAdjacentPlot(adjacentPlot4:GetX(), adjacentPlot4:GetY(), 0);
								else
								adjacentPlot5 = Map.GetAdjacentPlot(adjacentPlot4:GetX(), adjacentPlot4:GetY(), i+1);
							end
							if (adjacentPlot5 ~= nil) then
								if(adjacentPlot5:GetX() >= 0 and adjacentPlot5:GetY() < gridHeight) then
									if (i+1 == 6) then
										adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot5:GetX(), adjacentPlot5:GetY(), 0);
										else
										adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot5:GetX(), adjacentPlot5:GetY(), i+1);
									end
								end
							end
						end
					end
				end
			end
		end

		if (adjacentPlot2 ~= nil) then
			count = 60 + i * 5 + 2;
			if(index == count) then
				return adjacentPlot2;
			end

		end

		if (adjacentPlot ~=nil) then
			if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
				if (i+1 == 6) then
					adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), 0); -- 2 ring
					else
					adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), i+1); -- 2 ring
				end
			end
			if (adjacentPlot3 ~= nil) then
				if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
					if (i+1 == 6) then
						adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), 0); -- 3ring
						else
						adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), i+1); -- 3ring

					end
					if (adjacentPlot4 ~= nil) then
						if(adjacentPlot4:GetX() >= 0 and adjacentPlot4:GetY() < gridHeight) then
							if (i+1 == 6) then
								adjacentPlot5 = Map.GetAdjacentPlot(adjacentPlot4:GetX(), adjacentPlot4:GetY(), 0); --4th ring
								else
								adjacentPlot5 = Map.GetAdjacentPlot(adjacentPlot4:GetX(), adjacentPlot4:GetY(), i+1); --4th ring
							end
							if (adjacentPlot5 ~= nil) then
								if(adjacentPlot5:GetX() >= 0 and adjacentPlot5:GetY() < gridHeight) then
									adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot5:GetX(), adjacentPlot5:GetY(), i); --5th ring
								end
							end
						end
					end
				end
			end
		end

		if (adjacentPlot2 ~= nil) then
			count = 60 + i * 5 + 3;
			if(index == count) then
				return adjacentPlot2;
			end

		end
		
		adjacentPlot2 = nil

		if (adjacentPlot ~=nil) then
			if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
				if (i+1 == 6) then
					adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), 0); -- 2 ring
					else
					adjacentPlot3 = Map.GetAdjacentPlot(adjacentPlot:GetX(), adjacentPlot:GetY(), i+1); -- 2 ring
				end
			end
			if (adjacentPlot3 ~= nil) then
				if(adjacentPlot3:GetX() >= 0 and adjacentPlot3:GetY() < gridHeight) then
					if (i+1 == 6) then
						adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), 0); -- 3ring
						else
						adjacentPlot4 = Map.GetAdjacentPlot(adjacentPlot3:GetX(), adjacentPlot3:GetY(), i+1); -- 3ring

					end
					if (adjacentPlot4 ~= nil) then
						if(adjacentPlot4:GetX() >= 0 and adjacentPlot4:GetY() < gridHeight) then
							if (i+1 == 6) then
								adjacentPlot5 = Map.GetAdjacentPlot(adjacentPlot4:GetX(), adjacentPlot4:GetY(), 0); --4th ring
								else
								adjacentPlot5 = Map.GetAdjacentPlot(adjacentPlot4:GetX(), adjacentPlot4:GetY(), i+1); --4th ring
							end
							if (adjacentPlot5 ~= nil) then
								if(adjacentPlot5:GetX() >= 0 and adjacentPlot5:GetY() < gridHeight) then
									if (i+1 == 6) then
										adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot5:GetX(), adjacentPlot5:GetY(), 0); --5th ring
										else
										adjacentPlot2 = Map.GetAdjacentPlot(adjacentPlot5:GetX(), adjacentPlot5:GetY(), i+1); --5th ring
									end
								end
							end
						end
					end
				end
			end
		end

		if (adjacentPlot2 ~= nil) then
			count = 60 + i * 5 + 4;
			if(index == count) then
				return adjacentPlot2;
			end

		end

	end

end

-----------------------------------------------------------------------------
function __Debug(...)
   --print (...);
end
