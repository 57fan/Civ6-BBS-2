------------------------------------------------------------------------------
--	FILE:	BBS_AssignStartingPlot.lua    -- 1.6.7
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Custom Spawn Placement Script
------------------------------------------------------------------------------
--	Copyright (c) 2014 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------
include( "MapEnums" );
include( "MapUtilities" );
include( "FeatureGenerator" );
include( "TerrainGenerator" );
include( "NaturalWonderGenerator" );
include( "ResourceGenerator" );
include ( "AssignStartingPlots" );

local bError_major = false;
local bError_minor = false;
local bError_proximity = false;
local bError_shit_settle = false;
local bRepeatPlacement = false;
local b_debug_region = false
local b_north_biased = false
local Teamers_Config = 0
local Teamers_Ref_team = nil
local g_negative_bias = {}
local g_custom_bias = {}
local g_evaluated_plots = {}
local g_large_islands = {}
local Major_Distance_Target = 12
local Base_Major_Distance_Target = 16
local Minor_Distance_Target = 0
local bMinDistance = false
local civs = {};





------------------------------------------------------------------------------
BBS_AssignStartingPlots = {};


------------------------------------------------------------------------------
function ___Debug(...)
    print (...);
end

------------------------------------------------------------------------------
function BBS_AssignStartingPlots.Create(args)
	if (GameConfiguration.GetValue("SpawnRecalculation") == nil) then
		___Debug("BBS_AssignStartingPlots:",GameConfiguration.GetValue("SpawnRecalculation"))
		Game:SetProperty("BBS_RESPAWN",false)
		return AssignStartingPlots.Create(args)
	end
	___Debug("BBS_AssignStartingPlots: BBS Settings:", GameConfiguration.GetValue("SpawnRecalculation"));
	if (GameConfiguration.GetValue("SpawnRecalculation") == false) then 
		___Debug("BBS_AssignStartingPlots:",GameConfiguration.GetValue("SpawnRecalculation"))
		Game:SetProperty("BBS_RESPAWN",false)
		return AssignStartingPlots.Create(args)
	end
	
	if MapConfiguration.GetValue("BBS_Team_Spawn") ~= nil then
		Teamers_Config = MapConfiguration.GetValue("BBS_Team_Spawn")
	end
	
	g_negative_bias = {}
	
	local info_query = "SELECT * from StartBiasNegatives";
	local info_results = DB.Query(info_query);
	for k , v in pairs(info_results) do
		local tmp = { CivilizationType = v.CivilizationType, TerrainType = v.TerrainType, FeatureType = v.FeatureType, Tier = v.Tier, Extra = v.Extra}
		if tmp.CivilizationType ~= nil then
			table.insert(g_negative_bias, tmp)
		end
	end
	g_custom_bias = {}
	
	local info_query = "SELECT * from StartBiasCustom";
	local info_results = DB.Query(info_query);
	for k , v in pairs(info_results) do
		local tmp = { CivilizationType = v.CivilizationType, CustomPlacement = v.CustomPlacement}
		___Debug("g_custom_bias",v.CivilizationType,v.CustomPlacement)
		if tmp.CivilizationType ~= nil then
			table.insert(g_custom_bias, tmp)
		end
	end
	if (MapConfiguration.GetValue("MAP_SCRIPT") == "Pangaea.lua"
	or MapConfiguration.GetValue("MAP_SCRIPT") == "Continents.lua"
	or MapConfiguration.GetValue("MAP_SCRIPT") == "Terra.lua") then
	print("Calculating Island Size: Start", os.date("%c"));
	for iPlotIndex = 0, Map.GetPlotCount()-1, 1 do
		local pPlot = Map.GetPlotByIndex(iPlotIndex)
		if pPlot ~= nil and (pPlot:IsCoastalLand() or iPlotIndex == Map.GetPlotCount()-1) then
			local tmp = GetIslandPerimeter(pPlot,false,true,iPlotIndex == Map.GetPlotCount()-1)
		end
	end
	print("Calculating Island Size: End", os.date("%c"));
	end
   
   -- Setting minimal distance between players
   -- It will be based on the map used and the ratio size/players (more space if map too big, less space if too small)
   -- Objective is to avoid as much as possible the use of the firaxis placement
   
   ___Debug("Map Script: ", MapConfiguration.GetValue("MAP_SCRIPT"));
   
   
   -- Phase 1: Set base minimal distance according to the map.
   -- Large maps, with low amount of water (ex: highlands, lakes, ...) will see players spawn with a higher distance from each other.
   -- Smaller maps, with high amount of water (ex: Terra, Fractal, ...) will see player spawn closer to each other.
   
   local mapScript = MapConfiguration.GetValue("MAP_SCRIPT");
   
   if mapScript == "Highlands_XP2.lua" or mapScript == "Lakes.lua" then
		Major_Distance_Target = 15
	end
   
   if mapScript == "InlandSea.lua" then
		Major_Distance_Target = 14
	end

   
   if mapScript == "Seven_Seas.lua" or mapScript == "Primordial.lua" then
		Major_Distance_Target = 13
	end
   
	if mapScript == "Pangaea.lua" or mapScript == "DWPangaea.lua" or mapScript == "Shuffle.lua" or mapScript == "Tilted_Axis.lua" then
		Major_Distance_Target = 12
	end


   if mapScript == "Fractal.lua" or mapScript == "Island_Plates.lua" or mapScript == "Small_Continents.lua"
      or mapScript == "Archipelago_XP2.lua"  or mapScript == "Continents.lua" or mapScript == "Wetlands_XP2.lua"
      or mapScript == "Continents_Islands.lua" or mapScript == "Continents_Islands.lua" or mapScript == "Splintered_Fractal.lua"
      or mapScript == "DWArchipelago.lua" or mapScript == "DWFractal.lua" or mapScript == "DWMixedLand.lua"
      or mapScript == "DWSmallContinents.lua" or mapScript == "DWMixedIslands.lua" then
		Major_Distance_Target = 10
	end
	
	if mapScript == "Terra.lua" then
		Major_Distance_Target = 8
	end
   
   -- Checking if map is earth is flat or not.
   
   if mapScript == "Tilted_Axis.lua" or mapScript == "InlandSea.lua" then
		mapIsRoundWestEast = false
	end
   
   
   --Phase 2 : Adapt distance if there are too many/not enough players on for the map size
   
   -- Enormous ?
   if Map.GetMapSize() == 6 and  PlayerManager.GetAliveMajorsCount() > 17 then
		Major_Distance_Target = Major_Distance_Target - 2
	end
	if Map.GetMapSize() == 6 and  PlayerManager.GetAliveMajorsCount() < 15 then
		Major_Distance_Target = Major_Distance_Target + 2
	end	
   
   -- Huge
	if Map.GetMapSize() == 5 and  PlayerManager.GetAliveMajorsCount() > 13 then
		Major_Distance_Target = Major_Distance_Target - 2
	end
	if Map.GetMapSize() == 5 and  PlayerManager.GetAliveMajorsCount() < 11 then
		Major_Distance_Target = Major_Distance_Target + 2
	end	
	-- Large
	if Map.GetMapSize() == 4 and  PlayerManager.GetAliveMajorsCount() > 11 then
		Major_Distance_Target = Major_Distance_Target - 2
	end
	if Map.GetMapSize() == 4 and  PlayerManager.GetAliveMajorsCount() < 9 then
		Major_Distance_Target = Major_Distance_Target + 2
	end	
	-- Standard
	if Map.GetMapSize() == 3 and  PlayerManager.GetAliveMajorsCount() > 9 then
		Major_Distance_Target = Major_Distance_Target - 2
	end
	if Map.GetMapSize() == 3 and  PlayerManager.GetAliveMajorsCount() < 7 then
		Major_Distance_Target = Major_Distance_Target + 2
	end	
	-- Small
	if Map.GetMapSize() == 2 and  PlayerManager.GetAliveMajorsCount() > 7 then
		Major_Distance_Target = Major_Distance_Target - 2
	end
	if Map.GetMapSize() == 2 and  PlayerManager.GetAliveMajorsCount() < 5 then
		Major_Distance_Target = Major_Distance_Target + 2
	end	
	
   -- Tiny
	if Map.GetMapSize() == 1 and  PlayerManager.GetAliveMajorsCount() > 5 then
		Major_Distance_Target = Major_Distance_Target - 2
	end
	if Map.GetMapSize() == 1 and  PlayerManager.GetAliveMajorsCount() < 3 then
		Major_Distance_Target = Major_Distance_Target + 2
	end	
	
   -- Duel
	if Map.GetMapSize() == 0 and  PlayerManager.GetAliveMajorsCount() > 2  then
		Major_Distance_Target = Major_Distance_Target - 2
	end	
   
   Base_Major_Distance_Target = Major_Distance_Target
   
   --[[
   
   ___Debug("Map Script: ", MapConfiguration.GetValue("MAP_SCRIPT"));
	
   if MapConfiguration.GetValue("MAP_SCRIPT") == "Highlands_XP2.lua" then
		Major_Distance_Target = 21
	end
   
   if MapConfiguration.GetValue("MAP_SCRIPT") == "Seven_Seas.lua" then
		Major_Distance_Target = 19
	end
   
	if MapConfiguration.GetValue("MAP_SCRIPT") == "Pangaea.lua" then
		Major_Distance_Target = 18
	end	
	if MapConfiguration.GetValue("MAP_SCRIPT") == "Terra.lua" then
		Major_Distance_Target = 15
	end
	if Teamers_Config == 0 then
		Major_Distance_Target = Major_Distance_Target - 3 
	end
	-- Huge
	if Map.GetMapSize() == 5 and  PlayerManager.GetAliveMajorsCount() > 11 then
		Major_Distance_Target = Major_Distance_Target - 2
	end
	if Map.GetMapSize() == 5 and  PlayerManager.GetAliveMajorsCount() < 8 then
		Major_Distance_Target = Major_Distance_Target + 2
	end	
	-- Large
	if Map.GetMapSize() == 4 and  PlayerManager.GetAliveMajorsCount() > 10 then
		Major_Distance_Target = Major_Distance_Target - 2
	end
	if Map.GetMapSize() == 4 and  PlayerManager.GetAliveMajorsCount() < 8 then
		Major_Distance_Target = Major_Distance_Target + 2
	end	
	-- Standard
	if Map.GetMapSize() == 3 and  PlayerManager.GetAliveMajorsCount() > 7 then
		Major_Distance_Target = Major_Distance_Target - 3
	end
	if Map.GetMapSize() == 3 and  PlayerManager.GetAliveMajorsCount() < 8 then
		Major_Distance_Target = Major_Distance_Target 
	end	
	-- Small
	if Map.GetMapSize() == 2 and  PlayerManager.GetAliveMajorsCount() > 5 then
		Major_Distance_Target = Major_Distance_Target - 4
	end
	if Map.GetMapSize() == 2 and  PlayerManager.GetAliveMajorsCount() < 6 then
		Major_Distance_Target = Major_Distance_Target - 2
	end	
	
	if Map.GetMapSize() == 1 and  PlayerManager.GetAliveMajorsCount() > 5 then
		Major_Distance_Target = Major_Distance_Target - 5
	end
	if Map.GetMapSize() == 1 and  PlayerManager.GetAliveMajorsCount() < 6 then
		Major_Distance_Target = Major_Distance_Target - 3
	end	
	
	if Map.GetMapSize() == 0 and  PlayerManager.GetAliveMajorsCount() > 2  then
		Major_Distance_Target = 15
	end	
	
	if Map.GetMapSize() == 0 and  PlayerManager.GetAliveMajorsCount() == 2  then
		Major_Distance_Target = 18
	end	
	
	Base_Major_Distance_Target = Major_Distance_Target
   
   
   --]]
   
	Game:SetProperty("BBS_MAJOR_DISTANCE",Major_Distance_Target)
   local instance = {}
	instance  = {
        -- Core Process member methods
        __InitStartingData					= BBS_AssignStartingPlots.__InitStartingData,
        __FilterStart                       = BBS_AssignStartingPlots.__FilterStart,
        __SetStartBias                      = BBS_AssignStartingPlots.__SetStartBias,
        __BiasRoutine                       = BBS_AssignStartingPlots.__BiasRoutine,
        __FindBias                          = BBS_AssignStartingPlots.__FindBias,
        __RateBiasPlots                     = BBS_AssignStartingPlots.__RateBiasPlots,
        __SettlePlot                   		= BBS_AssignStartingPlots.__SettlePlot,
        __CountAdjacentTerrainsInRange      = BBS_AssignStartingPlots.__CountAdjacentTerrainsInRange,
        __ScoreAdjacent   					= BBS_AssignStartingPlots.__ScoreAdjacent,
        __CountAdjacentFeaturesInRange      = BBS_AssignStartingPlots.__CountAdjacentFeaturesInRange,
        __CountAdjacentResourcesInRange     = BBS_AssignStartingPlots.__CountAdjacentResourcesInRange,
        __CountAdjacentYieldsInRange        = BBS_AssignStartingPlots.__CountAdjacentYieldsInRange,
        __GetTerrainIndex                   = BBS_AssignStartingPlots.__GetTerrainIndex,
        __GetFeatureIndex                   = BBS_AssignStartingPlots.__GetFeatureIndex,
        __GetResourceIndex                  = BBS_AssignStartingPlots.__GetResourceIndex,
		__LuxuryCount						= BBS_AssignStartingPlots.__LuxuryCount,
        __TryToRemoveBonusResource			= BBS_AssignStartingPlots.__TryToRemoveBonusResource,
		__NaturalWonderBufferCheck			= BBS_AssignStartingPlots.__NaturalWonderBufferCheck,
        __LuxuryBufferCheck					= BBS_AssignStartingPlots.__LuxuryBufferCheck,
        __MajorMajorCivBufferCheck			= BBS_AssignStartingPlots.__MajorMajorCivBufferCheck,
        __MinorMajorCivBufferCheck			= BBS_AssignStartingPlots.__MinorMajorCivBufferCheck,
        __MinorMinorCivBufferCheck			= BBS_AssignStartingPlots.__MinorMinorCivBufferCheck,
        __BaseFertility						= BBS_AssignStartingPlots.__BaseFertility,
        __AddBonusFoodProduction			= BBS_AssignStartingPlots.__AddBonusFoodProduction,
        __AddFood							= BBS_AssignStartingPlots.__AddFood,
        __AddProduction						= BBS_AssignStartingPlots.__AddProduction,
        __AddResourcesBalanced				= BBS_AssignStartingPlots.__AddResourcesBalanced,
        __AddResourcesLegendary				= BBS_AssignStartingPlots.__AddResourcesLegendary,
        __BalancedStrategic					= BBS_AssignStartingPlots.__BalancedStrategic,
        __FindSpecificStrategic				= BBS_AssignStartingPlots.__FindSpecificStrategic,
        __AddStrategic						= BBS_AssignStartingPlots.__AddStrategic,
        __AddLuxury							= BBS_AssignStartingPlots.__AddLuxury,
		__AddLeyLine						= BBS_AssignStartingPlots.__AddLeyLine,
        __AddBonus							= BBS_AssignStartingPlots.__AddBonus,
        __IsContinentalDivide				= BBS_AssignStartingPlots.__IsContinentalDivide,
        __RemoveBonus						= BBS_AssignStartingPlots.__RemoveBonus,
        __TableSize						    = BBS_AssignStartingPlots.__TableSize,
        __GetValidAdjacent					= BBS_AssignStartingPlots.__GetValidAdjacent,
		__GetShuffledCiv					= BBS_AssignStartingPlots.__GetShuffledCiv,
		__CountAdjacentContinentsInRange	= BBS_AssignStartingPlots.__CountAdjacentContinentsInRange,
		__CountAdjacentRiverInRange			= BBS_AssignStartingPlots.__CountAdjacentRiverInRange,
		__SetStartMaori						= BBS_AssignStartingPlots.__SetStartMaori,

        iNumMajorCivs = 0,
		iNumSpecMajorCivs = 0,
        iNumWaterMajorCivs = 0,
        iNumMinorCivs = 0,
        iNumRegions		= 0,
        iDefaultNumberMajor = 0,
        iDefaultNumberMinor = 0,
		iTeamPlacement = Teamers_Config,
        uiMinMajorCivFertility = args.MIN_MAJOR_CIV_FERTILITY or 0,
        uiMinMinorCivFertility = args.MIN_MINOR_CIV_FERTILITY or 0,
        uiStartMinY = args.START_MIN_Y or 0,
        uiStartMaxY = args.START_MAX_Y or 0,
        uiStartConfig = args.START_CONFIG or 2,
        waterMap  = args.WATER or false,
        landMap  = args.LAND or false,
        noStartBiases = args.IGNORESTARTBIAS or false,
        startAllOnLand = args.STARTALLONLAND or false,
        startLargestLandmassOnly = args.START_LARGEST_LANDMASS_ONLY or false,
        majorStartPlots = {},
		majorStartPlotsTeam = {},
        minorStartPlots = {},
		minorStartPlotsID = {},
        majorList = {},
        minorList = {},
        playerStarts = {},
		regionTracker = {},
        aBonusFood = {},
        aBonusProd = {},
        rBonus = {},
        rLuxury = {},
        rStrategic = {},
        aMajorStartPlotIndices = {},
        fallbackPlots = {},
        tierMax = 0,
		iHard_Major = Major_Distance_Target,
		iDistance = 0,
		iDistance_major_minor = 6,
		iMinorAttempts = 0,
        -- Team info variables (not used in the core process, but necessary to many Multiplayer map scripts)
    }

	instance:__InitStartingData()
	
	if bError_major ~= false or bError_proximity ~= false or bError_shit_settle ~= false then
		print("BBS_AssignStartingPlots: To Many Attempts Failed - Go to Firaxis Placement")
		Game:SetProperty("BBS_RESPAWN",false)
		return AssignStartingPlots.Create(args)
	end	
	

	print("BBS_AssignStartingPlots: Sending Data")
	return instance
	
	
end

--- New vars ---

local mapIsRoundWestEast = true;
local mapXSize = 0;
local mapYSize = 0;

-- True = a player is too close to that location to be settle-able ---
local isPlayerProximityBlocked = {};
local mapResourceCode = {};
local mapTerrainCode = {};
local mapFeatureCode = {};
local mapLake = {}; -- true = lake, false = not
local mapCoastal = {}; -- true = Coastal, false = not
local mapFreshWater = {};
local mapRiver = {};


local mapFoodYield = {};
local mapProdYield = {};
local mapGoldYield = {};
local mapScienceYield = {};
local mapCultureYield = {};
local mapFaithYield = {};


--[[

values:
0 - Water
1 - Land (no 2-2)
2 - 2-2
3 - better than 2-2

--]]
local mapTwoTwo = {};


-- counters (purely statistics)

local terrainCount = {};
local featureCount = {};
local resourceCount = {};
local coastalCount = 0;

local landCount = 0;
local lakeCount = 0;
local mountainCount = 0;
local hillsnCount = 0;
local waterCount = 0;
local mountainCount = 0;
local floodPlainsCount = 0;


--- End new vars ---

-- Takes a terrain ID as argument, return whether or not the tile is a water tile.

function isWater(terrain)

   if (terrain == 15 or terrain == 16) then
      return true;
   end
   
   return false;
end


--[[ Draws the two-two map.

Map: the two-two map (see "mapTwoTwo" declaration for details)
xSize: xSize of the map
ySize: ySize of the map

--]]
function drawMap(map, xSize, ySize)

   local rowOne = "---|";
   local rowTwo = "---|";
   local rowThree = "---|";
   ___Debug("-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
   for i = 0, xSize - 1 do
      if (i < 100) then
         rowOne = rowOne .. "0" .. "|";
      else
         rowOne = rowOne .. math.floor(i / 100) .. "|";
      end
      
      if (i < 10) then
         rowTwo = rowTwo .. "0" .. "|";
      else
         rowTwo = rowTwo .. math.floor((i % 100) / 10) .. "|";
      end
      
      rowThree = rowThree .. i % 10 .. "|";

   end
   ___Debug(rowOne);
   ___Debug(rowTwo);
   ___Debug(rowThree);
   
   ___Debug("-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");


   for j = ySize - 1, 0 , -1 do
      jIndex = j + 1;
      
      local line = "";
      if (j < 10) then
         line = line .. "00" .. j .. "|";
      elseif (j < 100) then
         line = line .. "0" .. j .. "|";
      else
         line = line .. j .. "|";
      end
      
      for i = 0, xSize - 1 do
         iIndex = i + 1;
         
         line = line .. map[iIndex][jIndex] .. "|";
         
         
      end
      
      ___Debug(line);
   
   end
   
   ___Debug("-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
   ___Debug(rowOne);
   ___Debug(rowTwo);
   ___Debug(rowThree);
   ___Debug("-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");

end

--[[

Returns a table containing the (real) index of all tiles of ring X for a given coordinate.

--]]

function getRing(startX, startY, ring, xSize, ySize, mapIsRoundWestEast)

   local list = {};

   if (ring < 0) then
      return nil; 
   end

   if (ring == 0) then-- makes no sense
      list = {startX, startY};
      return list;
   end
   
   local workX = -1;
   local workY = -1;
   
   local evenIndex = ring ;
   local posIndex = 0;
   local negIndex = 0;

   
   -- EVEN Rows (0, 2 ,4 ...)
   if (startY % 2 == 0) then
  
      posIndex = ring - 1;
      negIndex = ring;
      
   else -- ODD rows

      posIndex = ring;
      negIndex = ring - 1;
      
   end
   
   print ("start pos", posIndex);
   print ("start neg", negIndex);
   
   for i = 0, ring - 1 do
   
      local tmpPosIndex = 0;
      local tmpNegIndex = 0;
   
      if (i % 2 == 1) then -- rows 1, 3, 5
         tmpPosIndex = posIndex;
         tmpNegIndex = negIndex;
         
         posIndex = posIndex - 1;
         negIndex = negIndex - 1;
      
      else -- rows 0,2,4
      
         tmpPosIndex = evenIndex;
         tmpNegIndex = evenIndex;
         
         evenIndex = evenIndex - 1;
      end
      
      print ("posinde", tmpPosIndex);
      print ("neginde", tmpNegIndex);
      
      -- row above
      workY = startY + i;
      if (workY < ySize) then
      
         -- neg X (tile on the left)
         workX = startX - tmpNegIndex;
         if (workX < 0) then
            if (mapIsRoundWestEast) then
               workX = workX + xSize;
               table.insert(list, {workX, workY})
            end
         else
            table.insert(list, {workX, workY})
         end
         
         -- post X (tile on the right)
               
         workX = startX + tmpPosIndex;
         if (workX >= mapXSize) then
            if (mapIsRoundWestEast) then
                  workX = workX - xSize;
                  table.insert(list, {workX, workY})
            end -- no else as we not adding if map not round

         else
            table.insert(list, {workX, workY});
         end
      end
      
      if (i ~= 0) then
      
         -- row BELOW
         workY = startY - i;
         if (workY >= 0) then
                  
            -- neg X (tile on the left)
            workX = startX - tmpNegIndex;
            if (workX < 0) then
               if (mapIsRoundWestEast) then
                  workX = workX + xSize;
                  table.insert(list, {workX, workY})
               end
            else
               table.insert(list, {workX, workY})
            end
            
            -- post X (tile on the right)
            
            workX = startX + tmpPosIndex;
            if (workX >= mapXSize) then
               if (mapIsRoundWestEast) then
                     workX = workX - xSize;
                     table.insert(list, {workX, workY})
               end -- no else as we not adding if map not round

            else
               table.insert(list, {workX, workY});
            end
         end
      end
   end
   
   
   -- last iteration is always special (more tiles)
   
   local startLastLine = 0;
   local endLastLine = 0;
   
   if (ring % 2 == 0) then
      startLastLine = startX - evenIndex;
      endLastLine = startX + evenIndex;
   else
      startLastLine = startX - negIndex;
      endLastLine = startX + posIndex;
   
   end
   
   -- row above
   workY = startY + ring;
   if (workY < ySize) then
   
      for workX = startLastLine, endLastLine do
      
         if (workX >= 0 and workX < mapXSize) then
            table.insert(list, {workX, workY});
         elseif mapIsRoundWestEast then
            if (workX < 0) then
               table.insert(list, {workX + mapXSize, workY});
            else -- must be over the limit
               table.insert(list, {workX - mapXSize, workY});
            end
         end
      end
      
   
   end
   
    workY = startY - ring;
   if (workY >= 0) then
   
      for workX = startLastLine, endLastLine do
      
         if (workX >= 0 and workX < mapXSize) then
            table.insert(list, {workX, workY});
         elseif mapIsRoundWestEast then
            if (workX < 0) then
               table.insert(list, {workX + mapXSize, workY});
            else -- must be over the limit
               table.insert(list, {workX - mapXSize, workY});
            end
         end
      end
      
   
   end
      
   return list;
      
     
end



--function BBS_AssignStartingPlots:__InitStartingData()
function NewBBS()

   print("----------- BBS BETA -------------");
   print("----------- Starting map parsing -------------");
   print(os.date("%c"));
   
   -- These map are ... flat earth :-)
   local mapScript = MapConfiguration.GetValue("MAP_SCRIPT");
   if (mapScript == "Tilted_Axis.lua" or mapScript == "InlandSea.lua") then
      mapIsRoundWestEast = false;
   end
   
   -- Size = max index
   
   -- duel (1v1)
   if Map.GetMapSize() == 0 then
      mapXSize = 44;
      mapYSize = 26;
   end
   
   -- Tiny (2v2)
   if Map.GetMapSize() == 1 then
      mapXSize = 60;
      mapYSize = 38;
   end
   
   -- Small (3v3)
   if Map.GetMapSize() == 2 then
      mapXSize = 74;
      mapYSize = 46;
   end
   
   -- Standard (4v4)
   if Map.GetMapSize() == 3 then
      mapXSize = 84;
      mapYSize = 54;
   end
   
   -- Large (5v5)
   if Map.GetMapSize() == 4 then
      mapXSize = 96;
      mapYSize = 60;
   end
   
   -- Huge (6v6)
   if Map.GetMapSize() == 5 then
      mapXSize = 106;
      mapYSize = 66;
   end
   
   
   -- Enormous (8v8)
   if Map.GetMapSize() == 6 then
      mapXSize = 128;
      mapYSize = 78;
   end
   
   print("size:", Map.GetMapSize());
   print("X:", mapXSize, "Y:", mapYSize);
   
   
   -- Array init --
   for i = 1, mapXSize do
   
      isPlayerProximityBlocked[i] = {};
      mapResourceCode[i] = {};
      mapTerrainCode[i] = {};
      mapFeatureCode[i] = {};
      mapCoastal[i] = {};
      mapLake[i] = {};
      mapRiver[i] = {};
      mapFreshWater[i] = {};
      
      mapTwoTwo[i] = {};
      mapFoodYield[i] = {};
      mapProdYield[i] = {};
      mapGoldYield[i] = {};
      mapScienceYield[i] = {};
      mapCultureYield[i] = {};
      mapFaithYield[i] = {};
      
      for j = 1, mapYSize do
         mapResourceCode[i][j] = -1;
         mapTerrainCode[i][j] = -1;
         mapFeatureCode[i][j] = -1;
         mapTwoTwo[i][j] = -1;
         mapCoastal[i][j] = false;
         mapLake[i][j] = false;
         mapRiver[i][j] = false;
         mapFreshWater[i][j] = false;
         
         mapFoodYield[i][j] = 0;
         mapProdYield[i][j] = 0;
         mapGoldYield[i][j] = 0;
         mapScienceYield[i][j] = 0;
         mapCultureYield[i][j] = 0;
         mapFaithYield[i][j] = 0;
         
         isPlayerProximityBlocked[i][j] = false;
      end
   end
   
   for i = 1, 17 do
      terrainCount[i] = 0;
   end
   
   for i = 1, 100 do
      resourceCount[i] = 0;
      featureCount[i] = 0;
   end
   
   -- Analysing the Map --
   
   for i = 0, mapXSize - 1 do
   
      local iIndex = i + 1;
      
      for j = 0, mapYSize - 1 do
      
         local jIndex = j + 1 ;
         local plot = Map.GetPlot(i , j);
         
         if (plot ~=nil) then
         
            local feature = plot:GetFeatureType();
            local terrain = plot:GetTerrainType();
            local resource = plot:GetResourceType();
            local isCoastal = plot:IsCoastalLand();
            local food = plot:GetYield(g_YIELD_FOOD);
            local prod = plot:GetYield(g_YIELD_PRODUCTION);
            local gold = plot:GetYield(g_YIELD_GOLD);
            local science = plot:GetYield(g_YIELD_SCIENCE);
            local culture = plot:GetYield(g_YIELD_CULTURE);
            local faith = plot:GetYield(g_YIELD_FAITH);
            
            
            mapTerrainCode[iIndex][jIndex] = terrain;
            mapResourceCode[iIndex][jIndex] = resource;
            mapFeatureCode[iIndex][jIndex] = feature;
            
            mapFoodYield[iIndex][jIndex] = food;
            mapProdYield[iIndex][jIndex] = prod;
            mapGoldYield[iIndex][jIndex] = gold;
            mapScienceYield[iIndex][jIndex] = science;
            mapCultureYield[iIndex][jIndex] = culture;
            mapFaithYield[iIndex][jIndex] = faith;
            
            -- Mapping 2-2
            if (terrain >= 15) then -- water
               mapTwoTwo[iIndex][jIndex] = 0;
            
            elseif (food < 2 or prod < 2) then -- not 2-2
               mapTwoTwo[iIndex][jIndex] = 1;
               
            elseif (food == 2 and prod == 2) then -- 2-2
               mapTwoTwo[iIndex][jIndex] = 2;
            
            else -- better than 2-2
               mapTwoTwo[iIndex][jIndex] = 3;
            end
            --- end mapping 2-2 --
            
            if(plot:IsRiver()) then
               mapRiver[iIndex][jIndex] = true;
            end
            
            if(plot:IsFreshWater()) then
               mapFreshWater[iIndex][jIndex] = true;
            end
            
            if (terrain >= 0) then
               terrainCount[terrain + 1] = terrainCount[terrain + 1] + 1;
            end
            
            if (terrain == 15 and plot:IsLake()) then
               mapLake[iIndex][jIndex] = true;
               lakeCount = lakeCount + 1;
            end
            
            if (resource >= 0) then
               resourceCount[resource + 1] = resourceCount[resource + 1] + 1;
            end
            if (feature >= 0) then
               featureCount[feature + 1] = featureCount[feature + 1] + 1;
            end
            
            if (feature == 0 or feature == 31 or feature == 32) then
               floodPlainsCount = floodPlainsCount + 1;
            end
            
            if (isCoastal) then
               coastalCount = coastalCount + 1;
               mapCoastal[iIndex][jIndex] = true;
            end
            
            ___Debug("Tile X:", i, "Y:", j);
            ___Debug("-- Terrain:", terrain);
            ___Debug("-- Resource:", resource);
            ___Debug("-- Feature:", feature);
            ___Debug("-----");
            
         end
      end
   end
   
   -- Display stats --
   
   local tilesCount = mapXSize * mapYSize
   
   waterCount = terrainCount[16 + 1] + terrainCount[15 + 1];
   landCount = tilesCount - waterCount;
   mountainCount = terrainCount[2 + 1] + terrainCount[5 + 1] + terrainCount[8 + 1] + terrainCount[11 + 1] + terrainCount[14 + 1];
   hillsCount = terrainCount[1 + 1] + terrainCount[4 + 1] + terrainCount[7 + 1] + terrainCount[10 + 1] + terrainCount[13 + 1];
   local usableLand = landCount - mountainCount;
   
   
   
   print("Amount of tiles:", tilesCount);
   print("---------------");
   print("--- Water ---");
   print("---------------");
   print("------Percentage of Water:", ((waterCount / tilesCount) * 100));
   print("------Water Count:", terrainCount[16 + 1] + terrainCount[15 + 1]);
   print("----------Coast Count:", terrainCount[15 + 1] - lakeCount);
   print("----------Lake Count: ", lakeCount);
   print("----------Ocean Count:", terrainCount[16 + 1]);
   print("--------------Of which are ice:", featureCount[1 + 1]);
   print("---------------");
   
   print("---------------");
   print("--- Land ---");
   print("---------------");
   print("------Percentage of Land:", ((landCount / tilesCount) * 100));
   print("------Land count", landCount);
   print("----------Coastal tiles:", coastalCount);
   print("----------Mountains count", mountainCount);
   print("----------Hills count", hillsCount);
   print("------Usable land count (no mountains)", usableLand);
   print("----------Of which: grasland", terrainCount[0 + 1] + terrainCount[1 + 1]);
   print("----------Of which: plain", terrainCount[3 + 1] + terrainCount[4 + 1]);
   print("----------Of which: desert", terrainCount[6 + 1] + terrainCount[7 + 1]);
   print("----------Of which: tundra", terrainCount[9 + 1] + terrainCount[10 + 1]);
   print("----------Of which: snow", terrainCount[12 + 1] + terrainCount[13 + 1]);
   print("----------Floodplains:", floodPlainsCount);
   
   
   ___Debug("---------------");
   ___Debug("--- Two-Two Map ---");
   drawMap(mapTwoTwo, mapXSize, mapYSize);
   
   
   -- test rings
   
   local ringTest = {};
   for i = 1, mapXSize do
      ringTest[i] = {};
      for j = 1, mapYSize do
         ringTest[i][j] = 9;
      end
   end
   
   for i = 1, 5 do
   
      print("--------");
      print("---- Ring:", i, "-------");
      print("--------");
      local list = getRing(65, 37, i, mapXSize, mapXSize, mapIsRoundWestEast)
      
      for _, element in ipairs(list) do
         local x = element[1];
         local y = element[2];
         print("X:", x, "Y:", y);
         ringTest[x + 1][y + 1] = i;
         
      end
      
      print("--------");
      print("--------");
      --for k, v in pairs(list) do
        -- print("X:", v[k], "Y:", y);
         --ringTest[x + 1][y + 1] = i;
      --end
   end
   
   drawMap(ringTest, mapXSize, mapYSize);

end

------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__InitStartingData()
   	___Debug("BBS_AssignStartingPlots: Start:", os.date("%c"));
      
      
   ---- TEMPORARY !!! -----
   NewBBS();
   
   ---- END ----
   
    if(self.uiMinMajorCivFertility <= 0) then
        self.uiMinMajorCivFertility = 110;
    end
    if(self.uiMinMinorCivFertility <= 0) then
        self.uiMinMinorCivFertility = 25;
    end
	local rng = 0
	rng = TerrainBuilder.GetRandomNumber(100,"North Test")/100;
	if rng > 0.5 then
		b_north_biased = true
	end
    --Find Default Number
    local MapSizeTypes = {};
    for row in GameInfo.Maps() do
        MapSizeTypes[row.RowId] = row.DefaultPlayers;
    end
    local sizekey = Map.GetMapSize() + 1;
    local iDefaultNumberPlayers = MapSizeTypes[sizekey] or 8;
    self.iDefaultNumberMajor = iDefaultNumberPlayers ;
    self.iDefaultNumberMinor = math.floor(iDefaultNumberPlayers * 1.5);

    --Init Resources List
    for row in GameInfo.Resources() do
        if (row.ResourceClassType  == "RESOURCECLASS_BONUS") then
            table.insert(self.rBonus, row);
            for row2 in GameInfo.TypeTags() do
                if(GameInfo.Resources[row2.Type] ~= nil and GameInfo.Resources[row2.Type].Hash == row.Hash) then
                    if(row2.Tag=="CLASS_FOOD" and row.Name ~= "LOC_RESOURCE_CRABS_NAME") then
                        table.insert(self.aBonusFood, row);
                    elseif(row2.Tag=="CLASS_PRODUCTION" and row.Name ~= "LOC_RESOURCE_COPPER_NAME") then
                        table.insert(self.aBonusProd, row);
                    end
                end
            end
        elseif (row.ResourceClassType == "RESOURCECLASS_LUXURY") then
            table.insert(self.rLuxury, row);
        elseif (row.ResourceClassType  == "RESOURCECLASS_STRATEGIC") then
            table.insert(self.rStrategic, row);
        end
    end

    for row in GameInfo.StartBiasResources() do
        if(row.Tier > self.tierMax) then
            self.tierMax = row.Tier;
        end
    end
    for row in GameInfo.StartBiasFeatures() do
        if(row.Tier > self.tierMax) then
            self.tierMax = row.Tier;
        end
    end
    for row in GameInfo.StartBiasTerrains() do
        if(row.Tier > self.tierMax) then
            self.tierMax = row.Tier;
        end
    end
    for row in GameInfo.StartBiasRivers() do
        if(row.Tier > self.tierMax) then
            self.tierMax = row.Tier;
        end
    end
	
	if b_debug_region == true then
		for iPlotIndex = 0, Map.GetPlotCount()-1, 1 do
			local pPlot = Map.GetPlotByIndex(iPlotIndex)
			if (pPlot ~= nil) then
				TerrainBuilder.SetFeatureType(pPlot,-1);
			end
		end		
	end

    -- See if there are any civs starting out in the water
    local tempMajorList = {};
    self.majorList = {};
    self.waterMajorList = {};
    self.specMajorList = {};
    self.iNumMajorCivs = 0;
    self.iNumSpecMajorCivs = 0;
    self.iNumWaterMajorCivs = 0;

    tempMajorList = PlayerManager.GetAliveMajorIDs();
	local tempMinorList = PlayerManager.GetAliveMajorIDs();
    
    for i = 1, PlayerManager.GetAliveMajorsCount() do
        local leaderType = PlayerConfigurations[tempMajorList[i]]:GetLeaderTypeName();
        if (not self.startAllOnLand and GameInfo.Leaders_XP2[leaderType] ~= nil and GameInfo.Leaders_XP2[leaderType].OceanStart) then
            table.insert(self.waterMajorList, tempMajorList[i]);
            self.iNumWaterMajorCivs = self.iNumWaterMajorCivs + 1;
            ___Debug ("Found the Maori");
        elseif ( PlayerConfigurations[tempMajorList[i]]:GetLeaderTypeName() == "LEADER_SPECTATOR" or PlayerConfigurations[tempMajorList[i]]:GetHandicapTypeID() == 2021024770) then
		table.insert(self.specMajorList, tempMajorList[i]);
		self.iNumSpecMajorCivs = self.iNumSpecMajorCivs + 1;
		___Debug ("Found a Spectator");
	else
            table.insert(self.majorList, tempMajorList[i]);
            self.iNumMajorCivs = self.iNumMajorCivs + 1;
        end
    end

    -- Do we have enough water on this map for the number of water civs specified?
    local TILES_NEEDED_FOR_WATER_START = 8;
    if (self.waterMap) then
        TILES_NEEDED_FOR_WATER_START = 1;
    end
    local iCandidateWaterTiles = StartPositioner.GetTotalOceanStartCandidates(self.waterMap);
    if (iCandidateWaterTiles < (TILES_NEEDED_FOR_WATER_START * self.iNumWaterMajorCivs)) then
        -- Not enough so reset so all civs start on land
        self.iNumMajorCivs = 0;
        self.majorList = {};
        for i = 1, PlayerManager.GetAliveMajorsCount() do
            table.insert(self.majorList, tempMajorList[i]);
            self.iNumMajorCivs = self.iNumMajorCivs + 1;
        end
    end

    self.iNumMinorCivs = PlayerManager.GetAliveMinorsCount();
    self.minorList = PlayerManager.GetAliveMinorIDs();
    self.iNumRegions = self.iNumMajorCivs + self.iNumMinorCivs;
	
	StartPositioner.DivideMapIntoMajorRegions(self.iNumMajorCivs, self.uiMinMajorCivFertility, self.uiMinMinorCivFertility, self.startLargestLandmassOnly);
	
	local bEndIteration = false
	bMinDistance = false
	
	local try = 1
	Game:SetProperty("BBS_ITERATION",try)
	for k = 1,8 do
		
	if bEndIteration ~= true then
		self.fallbackPlots = {}
		self.regionTracker = {}
		self.majorStartPlots = {}
		local majorStartPlots = {};
		for i = self.iNumMajorCivs - 1, 0, - 1 do
			local plots = StartPositioner.GetMajorCivStartPlots(i);
			table.insert(majorStartPlots, self:__FilterStart(plots, i, true));
		end
	
		bError_shit_settle = false
		bError_major = false;
		bError_proximity = false;
		bError_minor = false;
		
		print("Attempt #",k,"Distance",Major_Distance_Target)
   
		print("Attempt Score Based Major Placement", os.date("%c"))
		self.playerStarts = {};
		self.aMajorStartPlotIndices = {};
		self:__SetStartBias(majorStartPlots, self.iNumMajorCivs, self.majorList,true);
		print("Score Based Major Placement Completed", os.date("%c"))
		
	 -- Finally place the ocean civs
		if bError_shit_settle == false then
	
			if (self.iNumWaterMajorCivs == 1) then
				local attempt, maori_plot_index = self:__SetStartMaori(Players[self.waterMajorList[1]],self.waterMap);
				if attempt == true then
					local maoriPlot = Map.GetPlotByIndex(maori_plot_index)
					___Debug("Water Start X: ", maoriPlot:GetX(), "Water Start Y: ", maoriPlot:GetY());
					else
					local iWaterCivs = StartPositioner.PlaceOceanStartCivs(self.waterMap, self.iNumWaterMajorCivs, self.aMajorStartPlotIndices);
					for i = 1, iWaterCivs do
						local waterPlayer = Players[self.waterMajorList[i]]
						local iStartIndex = StartPositioner.GetOceanStartTile(i - 1);  -- Indices start at 0 here
						local pStartPlot = Map.GetPlotByIndex(iStartIndex);
						waterPlayer:SetStartingPlot(pStartPlot);
						___Debug("Water Start X: ", pStartPlot:GetX(), "Water Start Y: ", pStartPlot:GetY());
					end
					if (iWaterCivs < self.iNumWaterMajorCivs) then
						print("FAILURE PLACING WATER CIVS - Missing civs: " .. tostring(self.iNumWaterMajorCivs - iWaterCivs));
					end
				end
			elseif (self.iNumWaterMajorCivs > 1) then
				local iWaterCivs = StartPositioner.PlaceOceanStartCivs(self.waterMap, self.iNumWaterMajorCivs, self.aMajorStartPlotIndices);
				for i = 1, iWaterCivs do
					local waterPlayer = Players[self.waterMajorList[i]]
					local iStartIndex = StartPositioner.GetOceanStartTile(i - 1);  -- Indices start at 0 here
					local pStartPlot = Map.GetPlotByIndex(iStartIndex);
					waterPlayer:SetStartingPlot(pStartPlot);
					___Debug("Water Start X: ", pStartPlot:GetX(), "Water Start Y: ", pStartPlot:GetY());
				end
				if (iWaterCivs < self.iNumWaterMajorCivs) then
					print("FAILURE PLACING WATER CIVS - Missing civs: " .. tostring(self.iNumWaterMajorCivs - iWaterCivs));
				end
			end

	-- Place the spectator
			if (self.iNumSpecMajorCivs > 0) then
				for i = 1, self.iNumSpecMajorCivs do
					local specPlayer = Players[self.specMajorList[i]]
					local pStartPlot = Map.GetPlotByIndex(0+i+self.iNumSpecMajorCivs);
					specPlayer:SetStartingPlot(pStartPlot);
					___Debug("Spec Start X: ", pStartPlot:GetX(), "Spec Start Y: ", pStartPlot:GetY());
				end
			end
	
	-- Sanity check

			for i = 1, PlayerManager.GetAliveMajorsCount() do
				local startPlot = Players[tempMajorList[i]]:GetStartingPlot();
				if (startPlot == nil) then
					bError_major = true
					--___Debug("Error Major Player is missing:", tempMajorList[i]);
					print("Error Major Player is missing:", tempMajorList[i]);
				else
					___Debug("Major Start X: ", startPlot:GetX(), "Major Start Y: ", startPlot:GetY(), "ID:",tempMajorList[i]);
				end
			end
	
		else
	
			print("Some Major Score are too low",bError_shit_settle)
	
		end
		local majorSpawnsList = {}
		if (bError_major ~= true) and bError_shit_settle == false then
			for i = 1, PlayerManager.GetAliveMajorsCount() do
				if (PlayerConfigurations[tempMajorList[i]]:GetLeaderTypeName() ~= "LEADER_SPECTATOR" and PlayerConfigurations[tempMajorList[i]]:GetLeaderTypeName() ~= "LEADER_KUPE") then
					local pStartPlot_i = Players[tempMajorList[i]]:GetStartingPlot()
					table.insert(majorSpawnsList, pStartPlot_i)
					if (pStartPlot_i ~= nil) then
						for j = 1, PlayerManager.GetAliveMajorsCount() do
							if (PlayerConfigurations[j]:GetLeaderTypeName() ~= "LEADER_SPECTATOR" and PlayerConfigurations[tempMajorList[j]]:GetLeaderTypeName() ~= "LEADER_KUPE" and tempMajorList[i] ~= tempMajorList[j]) then
								local pStartPlot_j = Players[tempMajorList[j]]:GetStartingPlot()
								if (pStartPlot_j ~= nil) then
									local distance = Map.GetPlotDistance(pStartPlot_i:GetIndex(),pStartPlot_j:GetIndex())
									___Debug("I:", tempMajorList[i],"J:", tempMajorList[j],"Distance:",distance)
									if (distance < 9 ) then
										bError_proximity = true;
										print("Need to restart placement as two players are too close",distance,PlayerConfigurations[tempMajorList[i]]:GetLeaderTypeName(),PlayerConfigurations[tempMajorList[j]]:GetLeaderTypeName())
									end
								else
									print("Missing Start: ",PlayerConfigurations[tempMajorList[j]]:GetLeaderTypeName())
									bError_major = true
						
								end
							end
						end
					else
						print("Missing Start: ",PlayerConfigurations[tempMajorList[i]]:GetLeaderTypeName())
						bError_major = true
					end
				end
			end
		end
		
		if bError_shit_settle == false and bError_major == false and bError_proximity == false then

			print("Score Based Major Placement Successful", os.date("%c"))

			if(self.uiStartConfig == 1 ) then
				self:__AddResourcesBalanced();
			elseif(self.uiStartConfig == 3 ) then
				self:__AddResourcesLegendary();
			end

			print("Attempt Score Based Minor Placement", os.date("%c"))
			StartPositioner.DivideMapIntoMinorRegions(self.iNumMinorCivs);
			local minorStartPlots = {};
			self.fallbackPlots = {}
			self.regionTracker = {}
			for i = self.iNumMinorCivs - 1, 0, - 1 do
				local plots = StartPositioner.GetMinorCivStartPlots(i);
				table.insert(minorStartPlots, self:__FilterStart(plots, i, false));
			end

			self:__SetStartBias(minorStartPlots, self.iNumMinorCivs, self.minorList,false);
			print("Attempt Score Based Minor Completed", os.date("%c"))
   



			local tempMinorList = PlayerManager.GetAliveMinorIDs()
			local count = 0
			local fallbackmin_spawns = {}
			for i = 1, PlayerManager.GetAliveMinorsCount() do
				if Players[tempMinorList[i]] ~= nil then
					___Debug("Minor Check:",tempMinorList[i],"exist")
					if Players[tempMinorList[i]]:IsAlive() == true and Players[tempMinorList[i]]:IsMajor() == false then
						if Players[tempMinorList[i]]:GetStartingPlot() ~= nil then
							___Debug("Minor Check:",tempMinorList[i],"spawn present",Players[tempMinorList[i]]:GetStartingPlot():GetX(),Players[tempMinorList[i]]:GetStartingPlot():GetY())
							table.insert(fallbackmin_spawns, Players[tempMinorList[i]]:GetStartingPlot())
							else
							print("Minor Check:",tempMinorList[i],"spawn missing")
						end
					else
					___Debug("Minor Error:",Players[tempMinorList[i]])
					end
				else
				___Debug("Minor Error:",Players[tempMinorList[i]])
				end
			end
			
			for i = 1, PlayerManager.GetAliveMinorsCount() do
				if Players[tempMinorList[i]] ~= nil then
					if Players[tempMinorList[i]]:IsAlive() == true and Players[tempMinorList[i]]:IsMajor() == false then
						if Players[tempMinorList[i]]:GetStartingPlot() == nil then
							print("Minor Check:",tempMinorList[i],"spawn missing - fixing")
							for j, spawns in ipairs(fallbackmin_spawns) do
								bGotValid = false
								local tmp
								if spawns ~= nil then
									for n =1, 4 do
										tmp = Map.GetAdjacentPlot(spawns:GetX(),spawns:GetY(),n)
										if tmp ~= nil then
											bGotValid = true
											for m, spawn_2 in ipairs(fallbackmin_spawns) do
												if spawn_2 == tmp then
													bGotValid = false
												end
											end
											if bGotValid == true then
												Players[tempMinorList[i]]:SetStartingPlot(tmp)
												table.insert(fallbackmin_spawns, tmp)
												break
											end
										end	
									end
								end
								if bGotValid == true then
									print("Minor Check:",tempMinorList[i],"spawn missing - assigned")
									break
								end
							end
						end
					end
				end
			end
			___Debug(count,"Minor Players are missing");
	
			if (count > 0) then
				bError_minor = true
			else
				bError_minor = false
			end
			local count = 0
			if Game:GetProperty("BBS_MINOR_FAILING_TOTAL") ~= nil then
				count = Game:GetProperty("BBS_MINOR_FAILING_TOTAL")
			end


			___Debug("BBS_AssignStartingPlots: Completed", os.date("%c"));
	
		else
	
			print("Score Based Major Placement Failed")
	
		end
	
	
		if bError_major == false and bError_proximity == false and bError_shit_settle == false then
			print("BBS_AssignStartingPlots: Successfully ran!")
			
			if  (bError_minor == true) then
				___Debug("BBS_AssignStartingPlots: An error has occured: A city-state is missing.")
			end
			Game:SetProperty("BBS_RESPAWN",true)
			bEndIteration = true
			else
			print("Attempt Failed",bError_major,bError_proximity,bError_shit_settle)
			if Map.GetMapSize() > 3 then
				Major_Distance_Target = Major_Distance_Target - 2
				Minor_Distance_Target = Minor_Distance_Target - 1
				else
				Major_Distance_Target = Major_Distance_Target - 1
				Minor_Distance_Target = Minor_Distance_Target - 1				
			end
			try = try + 1
			Game:SetProperty("BBS_MAJOR_DISTANCE",Major_Distance_Target)
			Game:SetProperty("BBS_ITERATION",try)
			bRepeatPlacement = true			  
			if Major_Distance_Target < 9 then
				Major_Distance_Target = 9
				bMinDistance = true
			end
		end
		
	end
	
	end
		
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__SetStartMaori(pWaterPlayer, isWaterMap) 
	local gridWidth, gridHeight = Map.GetGridSize();
    local max = 0;
    local min = 0;
	if Map.GetMapSize() == 4 then
				max = 7 -- math.ceil(0.5*gridHeight * self.uiStartMaxY / 100);
				min = 7 -- math.ceil(0.5*gridHeight * self.uiStartMinY / 100);
				elseif Map.GetMapSize() == 5 then
				max = 8
				min = 8
				elseif Map.GetMapSize() == 3 then
				max = 6
				min = 6	
				else
				max = 5
				min = 5
	end	
	local valid_plots = {}
	local bHasPlots = false
	for iPlotIndex = 0, Map.GetPlotCount()-1, 1 do
		local pPlot = Map.GetPlotByIndex(iPlotIndex)
		if pPlot ~= nil then
			if (pPlot:GetY() > min + 4) and (pPlot:GetY() <  gridHeight - 4 - min) then
				if pPlot:GetTerrainType() == g_TERRAIN_TYPE_OCEAN then
					local IsNotBreaching, Distance = self:__MajorMajorCivBufferCheck(pPlot,pWaterPlayer:GetTeam())
					if IsNotBreaching == true then
						local bSurrounderByWater = true
						local low = 60
						local high = 90
						if (isWaterMap == true) then
							low = 30
							high = 60
						end
						for k = high, low, -1 do
							local scanPlot = GetAdjacentTiles(pPlot, k)	
							if scanPlot ~= nil then
								if scanPlot:IsWater() == false then
									bSurrounderByWater = false
									break
								end
							end
						end
						if bSurrounderByWater == true then
							local tmp = {plot = pPlot, score = Distance}
							bHasPlots = true
							table.insert(valid_plots,tmp)
							if tmp.score == 15 then
								break
							end
						end
					end
				end
			end
		end
	end	
	if bHasPlots == true then
		table.sort(valid_plots, function(a, b) return a.score > b.score; end);
		pWaterPlayer:SetStartingPlot(valid_plots[1].plot)
		print("Settled Score: ",valid_plots[1].score,"Player:",pWaterPlayer:GetID(),"Region: N/A")
		return true, valid_plots[1].plot:GetIndex();
		else
		print("Place Water Civs with Firaxis Engine")
		return false, -1;
	end
end


function BBS_AssignStartingPlots:__FilterStart(plots, index, major)
    local sortedPlots = {};
    local atLeastOneValidPlot = false;
	local count_tundra = 0
	local count_desert = 0
	local count_coast = 0
	local count_jungle = 0
	local count_river = 0
	-- Small map reference
	-- tundra 0 - 13 - 14
	-- desert 0 - 3 - 3
	-- coast 5 - 25 - 25
	-- jungle 0 - 8 - 10
	-- river 11 - 34 - 35
    for i, row in ipairs(plots) do
        local plot = Map.GetPlotByIndex(row);
        if (plot:IsImpassable() == false and plot:IsWater() == false and self:__GetValidAdjacent(plot, major)) or b_debug_region == true then
			if ( (plot:IsCoastalLand() == true and plot:IsFreshWater() == false) or (plot:IsCoastalLand() == true and plot:IsFreshWater() == true and plot:IsRiver() == true) ) 
				and ( plot:GetTerrainType() ~= g_TERRAIN_TYPE_TUNDRA and plot:GetTerrainType() ~= g_TERRAIN_TYPE_TUNDRA_HILLS ) then
				count_coast = count_coast + 1
			end
			if (plot:IsRiver() == true and (plot:GetTerrainType() ~= g_TERRAIN_TYPE_TUNDRA and plot:GetTerrainType() ~= g_TERRAIN_TYPE_TUNDRA_HILLS) ) then
				count_river = count_river + 1
			end
			if (plot:GetFeatureType() == g_FEATURE_JUNGLE) then
				count_jungle = count_jungle + 1
			end	
			if (plot:GetTerrainType() == g_TERRAIN_TYPE_DESERT or plot:GetTerrainType() == g_TERRAIN_TYPE_DESERT_HILLS) then
				count_desert = count_desert + 1
			end	
			if (plot:GetTerrainType() == g_TERRAIN_TYPE_TUNDRA or plot:GetTerrainType() == g_TERRAIN_TYPE_TUNDRA_HILLS) then
				count_tundra = count_tundra + 1
			end				
            atLeastOneValidPlot = true;
            table.insert(sortedPlots, plot);
        end
    end
    if (atLeastOneValidPlot == true) then
        if (major == true) then
            StartPositioner.MarkMajorRegionUsed(index);
			for i, plot in ipairs(sortedPlots) do
				plot.RegionIndex = index
				if count_coast > 10 then
					plot.IsRegionCoastal = true
					else
					plot.IsRegionCoastal = false
				end
				if count_river > 20 then
					plot.IsRegionRiver = true
					else
					plot.IsRegionRiver = false
				end
				if count_jungle > 7 then
					plot.IsRegionTropical = true
					else
					plot.IsRegionTropical = false
				end	
				if count_tundra > 7 then
					plot.IsRegionTaiga = true
					else
					plot.IsRegionTaiga = false
				end
				if count_desert > 2 then
					plot.IsRegionArid = true
					else
					plot.IsRegionArid = false
				end					
			end
        end
    end
    return sortedPlots;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__SetStartBias(startPlots, iNumberCiv, playersList, major)


	civs = {}
	
	self.fallbackPlots = {};
	local tmpfallback = {}
	for iPlotIndex = 0, Map.GetPlotCount()-1, 1 do
		local pPlot = Map.GetPlotByIndex(iPlotIndex)
		if pPlot ~= nil and self:__GetValidAdjacent(pPlot,major) == true then
			table.insert(tmpfallback ,pPlot)
		end
	end

	self.fallbackPlots = GetShuffledCopyOfTable(tmpfallback);

	local tierOrder = {};
	self.regionTracker = {};
	local count = 0;
	for i, region in ipairs(startPlots) do
		count = count + 1;
		self.regionTracker[i] = i;
		if (major) then
			-- Make the region inherit the sub plot characteristic for later (first plot is at index 1 not 0)
			if region[1] ~= nil then
				region.IsRegionCoastal 	= region[1].IsRegionCoastal
				region.IsRegionRiver 	= region[1].IsRegionRiver
				region.IsRegionTropical = region[1].IsRegionTropical
				region.IsRegionTaiga 	= region[1].IsRegionTaiga
				region.IsRegionArid 	= region[1].IsRegionArid
				region.StartIndex 		= region[1].RegionIndex	
			end
		end
	end
	___Debug("Set Start Bias: Total Region", count);
    for i = 1, iNumberCiv do
        local civ = {};
        civ.Type = PlayerConfigurations[playersList[i]]:GetCivilizationTypeName();

        civ.Index = i;
        local biases = self:__FindBias(civ.Type);
        if (self:__TableSize(biases) > 0) then
			if bMinDistance then
				if biases[1].Tier == 1 then
					civ.Tier = biases[1].Tier;
				else
					civ.Tier = self.tierMax + 1;
				end
			else
				civ.Tier = biases[1].Tier;	
			end
        else
            civ.Tier = self.tierMax + 1;
        end
        table.insert(civs, civ);
    end

	local shuffledCiv = GetShuffledCopyOfTable(civs);
	
	if bRepeatPlacement == true then
		if self.iHard_Major ~= nil then
			___Debug("Reshuffling Civ Order")
			shuffledCiv = self:__GetShuffledCiv(civs,self.iHard_Major);
			else
			___Debug("Error: Hard Major Limit ")
	  
		end
	end
	
	table.sort (shuffledCiv, function(a, b) return a.Tier < b.Tier; end);
	
    for k, civ in ipairs(shuffledCiv) do
		___Debug("SetStartBias for", k, civ.Type,playersList[civ.Index], civ.Tier,bError_shit_settle,bRepeatPlacement);
		if bError_shit_settle == false or bRepeatPlacement == false then
			self:__BiasRoutine(civ.Type, startPlots, civ.Index, playersList, major);
			___Debug("SetStartBias for", k, civ.Type, "Completed");
		end
    end
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__BiasRoutine(civilizationType, startPlots, index, playersList, major)
    	local biases = self:__FindBias(civilizationType);
    	local ratedBiases = nil;
    	local regionIndex = 0;
    	local settled = false;
		--------------------------------------------------------------------------------------------
		-- Smart placement cut time by looking at the most likely valid region first for Major Civs
		--------------------------------------------------------------------------------------------
		local bTaigaCiv = false
		local bCoastalCiv = false
		local bAridCiv = false
		local bTropicalCiv = false
		local bRiverCiv = false
		
		local regions = GetShuffledCopyOfTable(startPlots);
		
		if (major == true) then			
			table.sort (biases, function(a, b) return a.Tier < b.Tier; end);			
			if (biases ~= nil) then
				for j, bias in ipairs(biases) do
					if bias.Tier < 4 then
						if (bias.Type == "TERRAINS") and (bias.Value == g_TERRAIN_TYPE_DESERT_HILLS or bias.Value == g_TERRAIN_TYPE_DESERT or bias.Value == g_TERRAIN_TYPE_DESERT_MOUNTAIN) then
							bAridCiv = true
							break
						end
						if (bias.Type == "TERRAINS") and (bias.Value == g_TERRAIN_TYPE_TUNDRA_HILLS or bias.Value == g_TERRAIN_TYPE_TUNDRA or bias.Value == g_TERRAIN_TYPE_TUNDRA_MOUNTAIN) then
							bTaigaCiv = true
							break
						end	
						if (bias.Type == "TERRAINS") and (bias.Value == g_TERRAIN_TYPE_COAST) then
							bCoastalCiv = true
							break
						end
						if (bias.Type == "FEATURES") and (bias.Value == g_FEATURE_JUNGLE) then
							bTropicalCiv = true
							break
						end
						if (bias.Type == "RIVERS") then
							bRiverCiv = true
							break
						end
					end
				end
			end
			if (bAridCiv == true or bTaigaCiv == true or bCoastalCiv == true or bTropicalCiv == true or bRiverCiv == true) then
				local sortedstartPlots = {}
				-- best region first
				for i, region in ipairs(regions) do
				if bCoastalCiv == true and region.IsRegionCoastal then
					table.insert(sortedstartPlots,region)
				end
				if bRiverCiv == true and region.IsRegionRiver then
					table.insert(sortedstartPlots,region)
				end
				if bAridCiv == true and region.IsRegionArid then
					table.insert(sortedstartPlots,region)
				end
				if bTaigaCiv == true and region.IsRegionTaiga then
					table.insert(sortedstartPlots,region)
				end
				if bTropicalCiv == true and region.IsRegionTropical then
					table.insert(sortedstartPlots,region)
				end
				end
				
				-- complete the set
				if sortedstartPlots ~= nil then
					for i, region in ipairs(regions) do
						local bRegionAlreadyThere = false
						for j, sorted_region in ipairs(sortedstartPlots) do
							if region.StartIndex == sorted_region.StartIndex then
								bRegionAlreadyThere = true
								break
							end
						end
						if bRegionAlreadyThere == false then
							table.insert(sortedstartPlots,region)
						end
					end
					regions = sortedstartPlots
				end
			end
		end
		
		--------------------------------------------------------------------------------------------
		-- Iteration of plot per Region, then would attempt to place on the best plot of the region
		--------------------------------------------------------------------------------------------		

    	for i, region in ipairs(regions) do
			___Debug("Bias Routine: Analysing Region index", i, "Tracker",self.regionTracker[i]);
			if (self.regionTracker[i] ~= -1) then
       			if (region ~= nil and self:__TableSize(region) > 0) then
            		local tempBiases = self:__RateBiasPlots(biases, region, major, i,civilizationType,playersList[index],false);

            		if ( 	(ratedBiases == nil or ratedBiases[1].Score < tempBiases[1].Score) and 
							(tempBiases[1].Score > 0 or (bRepeatPlacement == true and tempBiases[1].Score > -200) ) ) then
                		ratedBiases = tempBiases;
                		regionIndex = i;
            		end
					if (ratedBiases ~= nil and regionIndex > 0) then
						settled = self:__SettlePlot(ratedBiases, index, Players[playersList[index]], major, regionIndex, civilizationType);
						if (settled == true) then
							self.regionTracker[regionIndex] = -1;
							break
						end
					end
				else
					regionIndex = i;
					self.regionTracker[regionIndex] = -1;
					___Debug("Bias Routine: Remove Region index: Empty Region", regionIndex);
        		end

			end
		end
		
		--------------------------------------------------------------------------------------------
		-- Emergency Iteration on the remaining available plots
		--------------------------------------------------------------------------------------------	

		if (settled == false) then
			if (self:__TableSize(self.fallbackPlots) > 0) then
				___Debug("Attempt to place using fallback",playersList[index],civilizationType)	
				ratedBiases = self:__RateBiasPlots(biases, self.fallbackPlots, major, i,civilizationType,playersList[index],true);
				settled = self:__SettlePlot(ratedBiases, index, Players[playersList[index]], major, -1,civilizationType);
				
				if (settled == false) then
					___Debug("Failed to place",playersList[index],civilizationType)
				end	
			end
		end
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__FindBias(civilizationType)
    local biases = {};
    for row in GameInfo.StartBiasResources() do
        if(row.CivilizationType == civilizationType) then
            local bias = {};
            bias.Tier = row.Tier;
            bias.Type = "RESOURCES";
            bias.Value = self:__GetResourceIndex(row.ResourceType);
            ___Debug("BBS_AssignStartingPlots: Add Bias : Civilization",civilizationType,"Bias Type:", bias.Type, "Tier :", bias.Tier, "Type :", bias.Value);
            table.insert(biases, bias);
        end
    end
    for row in GameInfo.StartBiasFeatures() do
        if(row.CivilizationType == civilizationType) then
            local bias = {};
            bias.Tier = row.Tier;
            bias.Type = "FEATURES";
            bias.Value = self:__GetFeatureIndex(row.FeatureType);
            ___Debug("BBS_AssignStartingPlots: Add Bias : Civilization",civilizationType,"Bias Type:", bias.Type, "Tier :", bias.Tier, "Type :", bias.Value);
            table.insert(biases, bias);
        end
    end
    for row in GameInfo.StartBiasTerrains() do
        if(row.CivilizationType == civilizationType) then
            local bias = {};
            bias.Tier = row.Tier;
            bias.Type = "TERRAINS";
            bias.Value = self:__GetTerrainIndex(row.TerrainType);
            ___Debug("BBS_AssignStartingPlots: Add Bias : Civilization",civilizationType,"Bias Type:", bias.Type, "Tier :", bias.Tier, "Type :", bias.Value);
            table.insert(biases, bias);
        end
    end
    for row in GameInfo.StartBiasRivers() do
        if(row.CivilizationType == civilizationType) then
            local bias = {};
            bias.Tier = row.Tier;
            bias.Type = "RIVERS";
            bias.Value = nil;
            ___Debug("BBS_AssignStartingPlots: Add Bias : Civilization",civilizationType,"Bias Type:", bias.Type, "Tier :", bias.Tier, "Type :", bias.Value);
            table.insert(biases, bias);
        end
    end
	for _, row in ipairs(g_negative_bias) do
        if(row.CivilizationType == civilizationType) then
            local bias = {};
			if row.TerrainType ~= nil then
				bias.Value = self:__GetTerrainIndex(row.TerrainType);
				bias.Type = "NEGATIVE_TERRAINS";
				bias.Tier = row.Tier;
				___Debug("BBS_AssignStartingPlots: Add Bias : Civilization",civilizationType,"Bias Type:", bias.Type, "Tier :", bias.Tier, "Type :", bias.Value);
				table.insert(biases, bias);
				elseif row.FeatureType ~= nil then
				bias.Value = self:__GetFeatureIndex(row.FeatureType);
				bias.Type = "NEGATIVE_FEATURES";
				bias.Tier = row.Tier;
				___Debug("BBS_AssignStartingPlots: Add Bias : Civilization",civilizationType,"Bias Type:", bias.Type, "Tier :", bias.Tier, "Type :", bias.Value);
				table.insert(biases, bias);
				elseif row.ResourceType ~= nil then
				bias.Value = self:__GetResourceIndex(row.ResourceType);
				bias.Type = "NEGATIVE_RESOURCES";
				bias.Tier = row.Tier;
				___Debug("BBS_AssignStartingPlots: Add Bias : Civilization",civilizationType,"Bias Type:", bias.Type, "Tier :", bias.Tier, "Type :", bias.Value);
				table.insert(biases, bias);
			end	
        end
    end
	for _, row in ipairs(g_custom_bias) do
        if(row.CivilizationType == civilizationType) then
            local bias = {};
			if row.CustomPlacement ~= nil then
				bias.Type = row.CustomPlacement;
				bias.Tier = 1;
				bias.Value = -1;
				___Debug("BBS_AssignStartingPlots: Add Bias : Civilization",civilizationType,"Bias Type:", bias.Type, "Tier :", bias.Tier, "Type :", bias.Value);
				___Debug("BBS_AssignStartingPlots: Add Bias : Civilization",civilizationType,"Bias Type:", bias.Type, "Tier :", bias.Tier, "Type :", bias.Value);
				table.insert(biases, bias);				
			end			
        end
    end
    table.sort(biases, function(a, b) return a.Tier < b.Tier; end);
    return biases;
end


function BBS_AssignStartingPlots:__SettlePlot(ratedBiases, index, player, major, regionIndex, civilizationType)
    local settled = false;
	if (regionIndex == -1) then
		___Debug("BBS_AssignStartingPlots: Attempt to place a Player using the Fallback plots.");
		else
		___Debug("BBS_AssignStartingPlots: Attempt to place a Player using region ", regionIndex)
	end

    for j, ratedBias in ipairs(ratedBiases) do
        if (not settled) then
            --___Debug("Rated Bias Plot:", ratedBias.Plot:GetX(), ":", ratedBias.Plot:GetY(), "Score :", ratedBias.Score);
            if (major) then
				local IsNotBreaching, Distance = self:__MajorMajorCivBufferCheck(ratedBias.Plot,Players[player:GetID()]:GetTeam())
				if IsNotBreaching ~= false then
                self.playerStarts[index] = {};
                    ___Debug("Settled plot :", ratedBias.Plot:GetX(), ":", ratedBias.Plot:GetY(), "Score :", ratedBias.Score, "Player:",player:GetID(),"Region:",regionIndex);
					print("Settled Score :", ratedBias.Score.." ("..ratedBias.Region..")", "Player:",player:GetID(),"Region:",regionIndex, "Distance:", Distance, os.date("%c"))
					if ratedBias.Score < - 1000 then
						print("X :", ratedBias.Plot:GetX(), "Y:",ratedBias.Plot:GetY(),"Region:",regionIndex)
						bError_shit_settle = true
					end
                    settled = true;
                    table.insert(self.playerStarts[index], ratedBias.Plot);
                    table.insert(self.majorStartPlots, ratedBias.Plot);
					table.insert(self.majorStartPlotsTeam, player:GetTeam());
                    table.insert(self.aMajorStartPlotIndices, ratedBias.Plot:GetIndex());
                    self:__TryToRemoveBonusResource(ratedBias.Plot);
                    player:SetStartingPlot(ratedBias.Plot);
					self:__AddLeyLine(ratedBias.Plot); 
				end
            else
				local IsNotBreaching_major, Distance_maj = self:__MinorMajorCivBufferCheck(ratedBias.Plot)
				local IsNotBreaching_minor, Distance_min = self:__MinorMinorCivBufferCheck(ratedBias.Plot)
				if IsNotBreaching_major ~= false  then
                self.playerStarts[index + self.iNumMajorCivs] = {};
                    print("Settled Score :", ratedBias.Score, "Player:",player:GetID(),"Region:",regionIndex, "Distance:", Distance_maj, Distance_min,os.date("%c"));
					___Debug("Player:",player:GetID(), "Player Name:",PlayerConfigurations[player:GetID()]:GetLeaderTypeName(),"Settled plot :", ratedBias.Plot:GetX(), ":", ratedBias.Plot:GetY(), "Score :", ratedBias.Score, "Region:",regionIndex);
                    settled = true;
                    table.insert(self.playerStarts[index + self.iNumMajorCivs], ratedBias.Plot);
                    table.insert(self.minorStartPlots, ratedBias.Plot)
					local tmp = {}
					tmp = {ID = player:GetID(), Plot = ratedBias.Plot}
					table.insert(self.minorStartPlotsID, tmp)
                    player:SetStartingPlot(ratedBias.Plot);
				end
            end
        end
    end

    return settled;

end

------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__RateBiasPlots(biases, startPlots, major, region_index, civilizationType,iPlayer,IsFallBack)
    local ratedPlots = {};
	local region_bonus = 0
	local gridWidth, gridHeight = Map.GetGridSize();
	local bFallBack = IsFallBack

	
    for i, plot in ipairs(startPlots) do
        local ratedPlot = {};
        local foundBiasDesert = false;
        local foundBiasToundra = false;
		local foundBiasNordic = false;
		local foundBiasFloodPlains = false;
		local foundBiasCoast = false;
		local bskip = false
        ratedPlot.Plot = plot;
        ratedPlot.Score = 0 + region_bonus;
        ratedPlot.Index = i;
		
		----------------------
		-- Shortcut let's not waste checking if they player would be too close anyway...
		----------------------
		if (major == true and bRepeatPlacement == true) then
			if Players[iPlayer] ~= nil then
				local IsNotBreaching, Distance = self:__MajorMajorCivBufferCheck(plot,Players[iPlayer]:GetTeam())
				if  IsNotBreaching == false then
					ratedPlot.Score = ratedPlot.Score - 5000;
					bskip = true
				end
			end	
		end
      
      -- oasis - not settleable
      if (plot:GetFeatureType() == 4) then
         ratedPlot.Score = ratedPlot.Score - 5000;
         bskip = true;
         ___Debug("Found oasis, gonna apply negative score");
      end
		
		if (major == false) then
			local IsNotBreaching_major, Distance_maj = self:__MinorMajorCivBufferCheck(ratedPlot.Plot)
			local IsNotBreaching_minor, Distance_min = self:__MinorMinorCivBufferCheck(ratedPlot.Plot)
			if IsNotBreaching_major == false or IsNotBreaching_minor == false then
				ratedPlot.Score = ratedPlot.Score - 5000;
				bskip = true
			end
		end
      
      
		
		if 	(bskip == false or (bRepeatPlacement == true and major == true)) and region_index ~= -1 then
		
        if (biases ~= nil) then
            for j, bias in ipairs(biases) do
                ___Debug("Rate Plot:", plot:GetX(), ":", plot:GetY(), "For Bias :", bias.Type, "value :", bias.Value,"Civ",civilizationType, "Base", ratedPlot.Score);
				
				-- Positive Biases
                if (bias.Type == "TERRAINS") then
					if bias.Value == g_TERRAIN_TYPE_COAST then
						foundBiasCoast = true;
						if self:__CountAdjacentTerrainsInRange(ratedPlot.Plot, bias.Value, major) > 0 then
							if bias.Tier < 3 then
								ratedPlot.Score = ratedPlot.Score + 500;
								else
								ratedPlot.Score = ratedPlot.Score + 250;
							end	
							___Debug("Terrain+ Coast:", ratedPlot.Score,bias.Value,bias.Tier);
							else
							ratedPlot.Score = ratedPlot.Score - 1000;
						end
						else
						ratedPlot.Score = ratedPlot.Score + self:__ScoreAdjacent(self:__CountAdjacentTerrainsInRange(ratedPlot.Plot, bias.Value, major), bias.Tier,bias.Type);
						___Debug("Terrain+ Non Coast:", ratedPlot.Score,bias.Value);
					end
                    if (bias.Value == g_TERRAIN_TYPE_DESERT) then
                        foundBiasDesert = true;
						if ratedPlot.Plot:GetTerrainType() ~= g_TERRAIN_TYPE_DESERT or ratedPlot.Plot:GetTerrainType() ~= g_TERRAIN_TYPE_DESERT_HILLS then
							ratedPlot.Score = ratedPlot.Score - 250
						end
						if plot.IsRegionArid == false then
							ratedPlot.Score = ratedPlot.Score - 250
						end
                    end
                    if (bias.Value == g_TERRAIN_TYPE_TUNDRA or bias.Value == g_TERRAIN_TYPE_SNOW) then
                        foundBiasToundra = true;
						if ratedPlot.Plot:GetTerrainType() ~= g_TERRAIN_TYPE_TUNDRA or ratedPlot.Plot:GetTerrainType() ~= g_TERRAIN_TYPE_TUNDRA_HILLS then
							ratedPlot.Score = ratedPlot.Score - 250
						end
						if plot.IsRegionTaiga == false then
							ratedPlot.Score = ratedPlot.Score - 250
						end
                    end
                elseif (bias.Type == "FEATURES") then
                    ratedPlot.Score = ratedPlot.Score + self:__ScoreAdjacent(self:__CountAdjacentFeaturesInRange(ratedPlot.Plot, bias.Value, major), bias.Tier,bias.Type);
					___Debug("Terrain+ Feature:", ratedPlot.Score,bias.Value);
					if (bias.Value == g_FEATURE_FLOODPLAINS or bias.Value == g_FEATURE_FLOODPLAINS_PLAINS or bias.Value == g_FEATURE_FLOODPLAINS_GRASSLAND) then
                        foundBiasFloodPlains = true;
                    end
                elseif (bias.Type == "RIVERS") then
					local number_river_tiles = 0
					if ratedPlot.Plot:IsRiver() == true then
						ratedPlot.Score = ratedPlot.Score + 100;
						number_river_tiles = self:__CountAdjacentRiverInRange(ratedPlot.Plot,major)
						if number_river_tiles ~= nil then
							ratedPlot.Score = ratedPlot.Score + math.min(tonumber(number_river_tiles) * 50,500);
						end
						else
						ratedPlot.Score = ratedPlot.Score - 150;
					end
					___Debug("Terrain+ River:", ratedPlot.Score,number_river_tiles);
                elseif (bias.Type == "RIVERS" and ratedPlot.Plot:IsRiver()) then
                    ratedPlot.Score = ratedPlot.Score + 100 + self:__ScoreAdjacent(1, bias.Tier);
					___Debug("Terrain+ River:", ratedPlot.Score,bias.Value);
                elseif (bias.Type == "RESOURCES") then
					local tmp = self:__ScoreAdjacent(self:__CountAdjacentResourcesInRange(ratedPlot.Plot, bias.Value, major, 1), bias.Tier,bias.Type)
					local tmp_2 = self:__ScoreAdjacent(self:__CountAdjacentResourcesInRange(ratedPlot.Plot, bias.Value, major, 2), bias.Tier,bias.Type)
					if tmp ~= nil then
						ratedPlot.Score = ratedPlot.Score + tmp;
					end
					if tmp_2 ~= nil then
						ratedPlot.Score = ratedPlot.Score + tmp_2 * 0.5;
					end
					___Debug("Resources+:", ratedPlot.Score,bias.Value);
					
				-- Negative Biases are optionnal and act as repellents 	
				elseif (bias.Type == "NEGATIVE_TERRAINS") then
					ratedPlot.Score = ratedPlot.Score - self:__ScoreAdjacent(self:__CountAdjacentTerrainsInRange(ratedPlot.Plot, bias.Value, major,false,17), bias.Tier,bias.Type);
					___Debug("Terrain-:", ratedPlot.Score,bias.Value);
				elseif (bias.Type == "NEGATIVE_FEATURES") then
					ratedPlot.Score = ratedPlot.Score - self:__ScoreAdjacent(self:__CountAdjacentFeaturesInRange(ratedPlot.Plot, bias.Value, major), bias.Tier,bias.Type);
					___Debug("Feature-:", ratedPlot.Score,bias.Value);
				elseif (bias.Type == "NEGATIVE_RESOURCES") then
					local tmp = self:__ScoreAdjacent(self:__CountAdjacentResourcesInRange(ratedPlot.Plot, bias.Value, major, 1), bias.Tier,bias.Type)
					local tmp_2 = self:__ScoreAdjacent(self:__CountAdjacentResourcesInRange(ratedPlot.Plot, bias.Value, major, 2), bias.Tier,bias.Type)
					if tmp ~= nil then
						ratedPlot.Score = ratedPlot.Score - tmp ;
					end
					if tmp_2 ~= nil then
						ratedPlot.Score = ratedPlot.Score - tmp_2 * 0.5;
					end	
					___Debug("Resource-:", ratedPlot.Score,bias.Value);
					
				-- Custom Biases 				
				elseif (bias.Type == "CUSTOM_NO_FRESH_WATER") then
					if plot:IsFreshWater() == false then
						ratedPlot.Score = ratedPlot.Score + 500;
					end	
					___Debug("Custom No Fresh Water", ratedPlot.Score);
				elseif (bias.Type == "CUSTOM_CONTINENT_SPLIT") then
					local continent = self:__CountAdjacentContinentsInRange(ratedPlot.Plot, major)
					if continent ~= nil and continent > 1 then
						ratedPlot.Score = ratedPlot.Score + 250
					end
					___Debug("Custom Continent Split", ratedPlot.Score,continent);
				elseif (bias.Type == "CUSTOM_NO_LUXURY_LIMIT") then
					local luxcount =  self:__LuxuryCount(ratedPlot.Plot)
					if luxcount > 1 then
						ratedPlot.Score = ratedPlot.Score + 100 * luxcount	
					end
					___Debug("Custom no lux limit", ratedPlot.Score);
				elseif (bias.Type == "CUSTOM_MOUNTAIN_LOVER") then
					local impassable = 0
					for direction = 0, 5, 1 do
						local adjacentPlot = Map.GetAdjacentPlot(ratedPlot.Plot:GetX(), ratedPlot.Plot:GetY(), direction);
						if (adjacentPlot ~= nil) then
							if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
							-- Checks to see if the plot is impassable
								if(adjacentPlot:IsImpassable()) then
									impassable = impassable + 1;
								end
								else
								impassable = impassable + 1;
							end
						end
					end
					if impassable > 2 then
						ratedPlot.Score = ratedPlot.Score + 250 * impassable
					end
					local Mountain_plains = self:__CountAdjacentTerrainsInRange(ratedPlot.Plot, 5, false);
					local Mountain_grass = self:__CountAdjacentTerrainsInRange(ratedPlot.Plot, 2, false);
					if Mountain_plains ~= nil and Mountain_grass ~= nil then
						if (Mountain_plains + Mountain_grass) > 2 and (Mountain_plains + Mountain_grass) < 12 then
							ratedPlot.Score = ratedPlot.Score + 250
							elseif (Mountain_plains + Mountain_grass) < 1 then
							ratedPlot.Score = ratedPlot.Score - 250
						end
						else
						ratedPlot.Score = ratedPlot.Score - 250
					end	
					___Debug("Custom Mountain Lover", ratedPlot.Score,Mountain_plains,Mountain_grass,impassable);
					
				elseif (bias.Type == "CUSTOM_KING_OF_THE_NORTH") then	
					foundBiasNordic = true;
					if MapConfiguration.GetValue("MAP_SCRIPT") ~= "Tilted_Axis.lua"  then
						local max = 17;
						local min = 17;
						if Map.GetMapSize() ~= nil then
							local inc = tonumber(Map.GetMapSize())
							max = max + inc - 2
							min = min + inc - 2
						end	

						if(plot:GetY() <= min or plot:GetY() > gridHeight - max) then
							ratedPlot.Score = ratedPlot.Score + 500;
							elseif(plot:GetY() <= min + 1 or plot:GetY() > gridHeight - max - 1) then 
							ratedPlot.Score = ratedPlot.Score + 200;
							elseif(plot:GetY() <= min + 2 or plot:GetY() > gridHeight - max - 2) then 
							ratedPlot.Score = ratedPlot.Score + 100;
							else
							ratedPlot.Score = ratedPlot.Score - 100;
						end	
						___Debug("Custom King of the North", ratedPlot.Score);
					end
					
					elseif (bias.Type == "CUSTOM_I_AM_SALTY")  then	
						if(plot:IsCoastalLand() == true and plot:IsFreshWater() == false) then
							ratedPlot.Score = ratedPlot.Score + 250;
							___Debug("Custom I am Salty", ratedPlot.Score);
						end
						
					elseif (bias.Type == "CUSTOM_HYDROPHOBIC") and waterMap == false then	
						local close_to_coast = false
						for dx = -3, 3, 1 do
							for dy = -3, 3, 1 do
								local adjacentPlot = Map.GetPlotXYWithRangeCheck(plot:GetX(), plot:GetY(), dx, dy, 3);
								if(adjacentPlot ~= nil and adjacentPlot:IsCoastalLand() == true and adjacentPlot:IsFreshWater() == false) then
									close_to_coast = true
								end
							end
						end
						if close_to_coast == true then
							ratedPlot.Score = ratedPlot.Score - 500;
							___Debug("Custom Hydrophobic", ratedPlot.Score);
						end
					
					
					elseif (foundBiasCoast == true) and major then	
						local close_to_coast = false
						for dx = -2, 2, 1 do
							for dy = -2, 2, 1 do
								local adjacentPlot = Map.GetPlotXYWithRangeCheck(plot:GetX(), plot:GetY(), dx, dy, 3);
								if( adjacentPlot ~= nil and 
									( (adjacentPlot:IsCoastalLand() == true and adjacentPlot:IsFreshWater() == false and MapConfiguration.GetValue("MAP_SCRIPT") ~= "Lakes.lua") 
										or (adjacentPlot:IsCoastalLand() == true and adjacentPlot:IsFreshWater() == true and adjacentPlot:IsRiver() == true) 
										or (adjacentPlot:IsCoastalLand() == true and MapConfiguration.GetValue("MAP_SCRIPT") ~= "Lakes.lua") ) ) then
									close_to_coast = true
								end
							end
						end
						if close_to_coast == false then
							ratedPlot.Score = ratedPlot.Score - 2500;
						end
						if 	(plot:IsCoastalLand() == true and plot:IsFreshWater() == false and MapConfiguration.GetValue("MAP_SCRIPT") ~= "Lakes.lua")
						or	(plot:IsCoastalLand() == true and plot:IsFreshWater() == true and plot:IsRiver() == true)
						or 	(plot:IsCoastalLand() == true and MapConfiguration.GetValue("MAP_SCRIPT") == "Lakes.lua") then
							ratedPlot.Score = ratedPlot.Score + 1250;
							else
							ratedPlot.Score = ratedPlot.Score - 1000;
						end
						___Debug("Coastal", ratedPlot.Score);
                end
            end
        end


        if (major) then
			if self.uiStartConfig ~= 3 then
				-- Try to spawn close to 1 luxury
				local luxcount =  self:__LuxuryCount(ratedPlot.Plot)
				if luxcount == 1 then
					ratedPlot.Score = ratedPlot.Score + 50
					elseif luxcount == 2 then
					ratedPlot.Score = ratedPlot.Score - 25
					elseif luxcount > 2 then
					ratedPlot.Score = ratedPlot.Score - 100 * luxcount					
				end	
				___Debug("Lux Check", ratedPlot.Score);	
			end

			if (not foundBiasFloodPlains) then
				if plot:GetFeatureType() == g_FEATURE_FLOODPLAINS or plot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS or plot:GetFeatureType() == g_FEATURE_FLOODPLAINS_GRASSLAND then
					ratedPlot.Score = ratedPlot.Score - 250;
				end
				___Debug("Flood Check", ratedPlot.Score);	
			end
			
			___Debug("tundra Check", ratedPlot.Score,tempTundra,tempTundraHill,ratedPlot.Plot:GetX(),ratedPlot.Plot:GetY());	
			------------------------------------------------------------------------------------------------------
			-- Latitude Placement
			------------------------------------------------------------------------------------------------------
			if MapConfiguration.GetValue("MAP_SCRIPT") ~= "Tilted_Axis.lua"  then
			    local max = 0;
				local min = 0;
				if Map.GetMapSize() == 4 then
					max = 12 -- math.ceil(0.5*gridHeight * self.uiStartMaxY / 100);
					min = 12 -- math.ceil(0.5*gridHeight * self.uiStartMinY / 100);
					elseif Map.GetMapSize() == 5 then
					max = 14
					min = 14
					elseif Map.GetMapSize() == 3 then
					max = 10
					min = 10	
					else
					max = 8
					min = 8
				end	

				if foundBiasNordic == true then
					max = 6
					min = 6
				end
				
				if bFallBack == true then
					max = 10
					min = 10
				end
				
				if(plot:GetY() <= min or plot:GetY() > gridHeight - max) then
					ratedPlot.Score = ratedPlot.Score - 2000
					elseif(plot:GetY() <= min + 1 or plot:GetY() > gridHeight - max - 1) then 
					ratedPlot.Score = ratedPlot.Score - 500
					elseif(plot:GetY() <= min + 2 or plot:GetY() > gridHeight - max - 2) then 
					ratedPlot.Score = ratedPlot.Score - 250
				end	
			end
			

			___Debug("Placement Check", ratedPlot.Score);	
			if self.iTeamPlacement == 1 then
				-- East vs. West
				if Players[iPlayer] ~= nil then
					if Teamers_Ref_team == nil then
						Teamers_Ref_team = Players[iPlayer]:GetTeam()
					end
					if Players[iPlayer]:GetTeam() == Teamers_Ref_team  then
						if plot:GetX() > 2*(gridWidth / 3) then
							ratedPlot.Score = ratedPlot.Score + 500
							elseif plot:GetX() > (gridWidth / 2) then
							ratedPlot.Score = ratedPlot.Score + 250
							elseif plot:GetX() > ((gridWidth / 2) - 3) then
							ratedPlot.Score = ratedPlot.Score + 50
							elseif plot:GetX() > ( (gridWidth / 2) - 5) then
							ratedPlot.Score = ratedPlot.Score + 25
							elseif plot:GetX() > (gridWidth / 3) then
							ratedPlot.Score = ratedPlot.Score
							else
							ratedPlot.Score = ratedPlot.Score - 2000
						end
						else
						if plot:GetX() < gridWidth / 3 then
							ratedPlot.Score = ratedPlot.Score + 500
							elseif plot:GetX() < (gridWidth / 2) then
							ratedPlot.Score = ratedPlot.Score + 250
							elseif plot:GetX() < ((gridWidth / 2) + 3) then
							ratedPlot.Score = ratedPlot.Score + 50
							elseif plot:GetX() < ((gridWidth / 2) + 5) then
							ratedPlot.Score = ratedPlot.Score + 25
							elseif plot:GetX() < (2*(gridWidth / 3) ) then
							ratedPlot.Score = ratedPlot.Score
							else
							ratedPlot.Score = ratedPlot.Score - 2000
						end						
					end
				end	
				
				-- North vs. South
				elseif self.iTeamPlacement == 2 then
				if Players[iPlayer] ~= nil then
					if Teamers_Ref_team == nil then
						Teamers_Ref_team = Players[iPlayer]:GetTeam()
					end
					if Players[iPlayer]:GetTeam() == Teamers_Ref_team then
						if plot:GetY() > 2*gridHeight / 3 then
							ratedPlot.Score = ratedPlot.Score + 500
							elseif plot:GetY() > (gridHeight / 2) then
							ratedPlot.Score = ratedPlot.Score + 250
							elseif plot:GetY() > ((gridHeight / 2) - 3) then
							ratedPlot.Score = ratedPlot.Score + 50
							elseif plot:GetY() > ((gridHeight / 2) - 5) then
							ratedPlot.Score = ratedPlot.Score + 25
							elseif plot:GetY() > (gridHeight / 3) then
							ratedPlot.Score = ratedPlot.Score
							else
							ratedPlot.Score = ratedPlot.Score - 2000
						end
						else
						if plot:GetY() < gridHeight / 3 then
							ratedPlot.Score = ratedPlot.Score + 500
							elseif plot:GetY() < ((gridHeight / 2)) then
							ratedPlot.Score = ratedPlot.Score + 250
							elseif plot:GetY() < ((gridHeight / 2) + 3) then
							ratedPlot.Score = ratedPlot.Score + 50
							elseif plot:GetY() < ((gridHeight / 2) + 5) then
							ratedPlot.Score = ratedPlot.Score + 25
							elseif plot:GetY() < (2*(gridHeight / 3) ) then
							ratedPlot.Score = ratedPlot.Score
							else
							ratedPlot.Score = ratedPlot.Score - 2000
						end						
					end
				end	
				
			end
			
			
		local impassable = 0
		for direction = 0, 5, 1 do
			local adjacentPlot = Map.GetAdjacentPlot(ratedPlot.Plot:GetX(), ratedPlot.Plot:GetY(), direction);
			if (adjacentPlot ~= nil) then
				if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
							-- Checks to see if the plot is impassable
					if(adjacentPlot:IsImpassable()) then
						impassable = impassable + 1;
					end
				else
					impassable = impassable + 1;
				end
			end
		end
		if impassable > 2 then
			ratedPlot.Score = ratedPlot.Score - ( 250 * impassable )
			___Debug("Impassable Check", ratedPlot.Score, impassable);	
		end
	
			
		if Players[iPlayer] ~= nil then
			local IsNotBreaching, Distance = self:__MajorMajorCivBufferCheck(plot,Players[iPlayer]:GetTeam())
			if IsNotBreaching == false then
				ratedPlot.Score = ratedPlot.Score - 5000;
				else
				-- Distance is Max 15 and Min 9
				ratedPlot.Score = ratedPlot.Score  + math.max(Distance - Major_Distance_Target,0) * 6
			end
		end	
			
		if (plot:GetFeatureType() == g_FEATURE_OASIS) then
			ratedPlot.Score = ratedPlot.Score - 250;
		end
        ratedPlot.Score = ratedPlot.Score + self:__CountAdjacentYieldsInRange(plot, major);
		
		if (plot:IsFreshWater() == false and foundBiasCoast == false) then
			ratedPlot.Score = ratedPlot.Score - 500;
		end
		___Debug("Fresh WAter Check", ratedPlot.Score);	
		
		end

		if ratedPlot.Plot:IsRiver() then
			ratedPlot.Score = ratedPlot.Score + 25
		end
		___Debug("River Check", ratedPlot.Score);	

		-- Region check

		if ratedPlot.Score > -500 and (foundBiasCoast == false or foundBiasToundra == false or foundBiasDesert == false) then
			region_bonus = 0
			local count_water = 0
			local count_desert = 0
			local count_tundra = 0
			local count_flood = 0
         local count_snow = 0
			for k = 60, 30, -1 do
				local scanPlot = GetAdjacentTiles(ratedPlot.Plot, k)
				if scanPlot ~= nil then
				
					if (scanPlot:GetTerrainType() == g_TERRAIN_TYPE_TUNDRA or scanPlot:GetTerrainType() == g_TERRAIN_TYPE_TUNDRA_HILLS) then
					
						count_tundra = count_tundra + 1
					end
					
					if (scanPlot:GetTerrainType() ==  g_TERRAIN_TYPE_DESERT or scanPlot:GetTerrainType() ==  g_TERRAIN_TYPE_DESERT_HILLS) then
					
						count_desert = count_desert + 1
					
					end
               
               if (scanPlot:GetTerrainType() ==  g_TERRAIN_TYPE_SNOW or scanPlot:GetTerrainType() ==  g_TERRAIN_TYPE_SNOW_HILLS) then
                  count_snow = count_snow + 1;
               end
					
					if (scanPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS or scanPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_PLAINS or scanPlot:GetFeatureType() == g_FEATURE_FLOODPLAINS_GRASSLAND ) then
					
						count_flood = count_flood + 1
					end
					
					if (scanPlot:IsLake() == false and scanPlot:IsWater()) then

						count_water = count_water + 1				
					end
					
					
				end
			end	
			if count_water > 20 and self.waterMap == false and foundBiasCoast == false then
				region_bonus = region_bonus - 750
			elseif count_water > 10 and self.waterMap == false and foundBiasCoast == false then
				region_bonus = region_bonus - 250
			end
			
			if count_tundra > 5 and foundBiasToundra == false then
				region_bonus = region_bonus - 250
			end
         
         -- fix for cs in snow
         if count_snow > 2 and foundBiasToundra == false then
				region_bonus = region_bonus - 2500
            ___Debug("Snow malus: ", count_snow )
			end
         
			if count_desert > 5 and foundBiasDesert == false then
				region_bonus = region_bonus - 250
			end
		
		end
		------------------------------------
		-- major only end
		------------------------------------
		ratedPlot.Score = ratedPlot.Score + region_bonus
		


		
		end
		------------------------------------
		-- Shortcut end
		------------------------------------
		if major then
		if bRepeatPlacement == false then
		
			local evaluatedPlot = { Index = ratedPlot.Plot:GetIndex(), Civ = civilizationType, Score = ratedPlot.Score, Region = region_bonus}
			table.insert(g_evaluated_plots, evaluatedPlot);
			
			else
			if regionIndex ~= -1 then
			for k, evaluatedPlot in ipairs(g_evaluated_plots) do
				if ratedPlot.Plot:GetIndex() == evaluatedPlot.Index and civilizationType == evaluatedPlot.Civ then
					ratedPlot.Score = evaluatedPlot.Score 
					region_bonus = evaluatedPlot.Region
					break
				end
			
			end
			end
		end
		end
		
		if (major == true) then
			if Players[iPlayer] ~= nil then
				local IsNotBreaching, Distance = self:__MajorMajorCivBufferCheck(plot,Players[iPlayer]:GetTeam())
				if IsNotBreaching == false then
					ratedPlot.Score = ratedPlot.Score - 5000;
				else
				-- Distance is Max 15 and Min 9
					if bFallBack == false then
						ratedPlot.Score = ratedPlot.Score  + (Distance - Base_Major_Distance_Target) * 10
					else
						ratedPlot.Score = ratedPlot.Score  + (Distance - Major_Distance_Target) * 10
					end
				end
			end	
		else
			local IsNotBreaching_major, Distance_maj = self:__MinorMajorCivBufferCheck(ratedPlot.Plot)
			local IsNotBreaching_minor, Distance_min = self:__MinorMinorCivBufferCheck(ratedPlot.Plot)
			if IsNotBreaching_major == false or IsNotBreaching_minor == false then
				ratedPlot.Score = ratedPlot.Score - 5000;
			else
				ratedPlot.Score = ratedPlot.Score  + math.min(Distance_maj - 7,Distance_min - 7) * 50
			end
		end
		
	
		ratedPlot.Score = math.floor(ratedPlot.Score);
		___Debug("Plot :", plot:GetX(), ":", plot:GetY(), "Score :", ratedPlot.Score, "North Biased:",b_north_biased, "Type:",plot:GetTerrainType(),"Region",region_bonus);
		if major then
			___Debug("Plot :", plot:GetX(), ":", plot:GetY(), "Region:",region_index,"Score :", ratedPlot.Score, "Civilization:",civilizationType, "Team",iPlayer,"Type:",plot:GetTerrainType());
		end
		
		
		ratedPlot.Region = region_bonus
		table.insert(ratedPlots, ratedPlot);

    end
    table.sort(ratedPlots, function(a, b) return a.Score > b.Score; end);
    return ratedPlots;
end
------------------------------------------------------------------------------

------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__GetValidAdjacent(plot, major)
    local impassable = 0;
    local water = 0;
    local water = 0;
    local desert = 0;
    local snow = 0;
    local toundra = 0;
    local gridWidth, gridHeight = Map.GetGridSize();
    local terrainType = plot:GetTerrainType();

	if(plot:IsWater() == true or plot:IsImpassable() == true) then
		return false;
	end


	if (self:__NaturalWonderBufferCheck(plot, major) == false) then
		return false;
	end

	if(plot:IsFreshWater() == false and plot:IsCoastalLand() == false and major == true) then
		return false;
	end
	
	if major == false then
		local IsNotBreaching_major, Distance_maj = self:__MinorMajorCivBufferCheck(plot)
		if IsNotBreaching_major == false then
			return false
		end
	end


    	local max = 0;
    	local min = 0;
    	if(major == true) then
			if Map.GetMapSize() == 4 then
				max = 7 -- math.ceil(0.5*gridHeight * self.uiStartMaxY / 100);
				min = 7 -- math.ceil(0.5*gridHeight * self.uiStartMinY / 100);
				elseif Map.GetMapSize() == 5 then
				max = 8
				min = 8
				elseif Map.GetMapSize() == 3 then
				max = 6
				min = 6	
				else
				max = 5
				min = 5
			end	
    	end

    	if(plot:GetY() <= min or plot:GetY() > gridHeight - max) then
        	return false;
    	end
		
		if(plot:GetX() <= min or plot:GetX() > gridWidth - max) then
        	return false;
    	end

	if (major == true and plot:IsFreshWater() == false and plot:IsCoastalLand() == false) then
		return false;
	end


    for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
        local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
        if (adjacentPlot ~= nil) then
            terrainType = adjacentPlot:GetTerrainType();
            if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
                -- Checks to see if the plot is impassable
                if(adjacentPlot:IsImpassable()) then
                    impassable = impassable + 1;
                end
                -- Checks to see if the plot is water
                if(adjacentPlot:IsWater()) then
                    water = water + 1;
                end
		if(adjacentPlot:GetFeatureType() == g_FEATURE_VOLCANO and major == true) then
			return false
		end 
            else
                impassable = impassable + 1;
            end
        end
    end
	
	if major == true then
		if self:__CountAdjacentResourcesInRange(plot, 27, major) > 0 then
		return false
		end
		if self:__CountAdjacentResourcesInRange(plot, 11, major) > 0 then
		return false
		end
		if self:__CountAdjacentResourcesInRange(plot, 28, major) > 0 then
		return false
	end
	end
	
	if (major == true) 
	and (MapConfiguration.GetValue("MAP_SCRIPT") == "Continents.lua"
	or MapConfiguration.GetValue("MAP_SCRIPT") == "Terra.lua") then
		local perimeter = GetIslandPerimeter(plot)
		local min_size = 50
		if Map.GetMapSize() == 4 then
				min_size = 65
				elseif Map.GetMapSize() == 5 then
				min_size = 75
				elseif Map.GetMapSize() > 3 then
				min_size = 80
				else
				min_size = 35
			end	
		if perimeter ~= nil and perimeter < min_size then
			print("Tiny Island", perimeter, plot:GetX(), plot:GetY())
			return false;
		end
	end
	
	if (major == true) 
	and (MapConfiguration.GetValue("MAP_SCRIPT") == "Pangaea.lua") then
		local perimeter = GetIslandPerimeter(plot)
		local min_size = 55
		if Map.GetMapSize() == 4 then
				min_size = 70
				elseif Map.GetMapSize() == 5 then
				min_size = 80
				elseif Map.GetMapSize() > 3 then
				min_size = 85
				else
				min_size = 35
			end	
		if perimeter ~= nil and perimeter < min_size then
			print("Tiny Island", perimeter, plot:GetX(), plot:GetY())
			return false;
		end
	end
	
	

    if(impassable >= 4 and not self.waterMap and major == true) then
        return false;
    elseif(impassable >= 4 and not self.waterMap) then
        return false;
    elseif(water + impassable  >= 4 and not self.waterMap and major == true) then
        return false;
    elseif(water >= 3 and major == true) then
        return false;
    elseif(water >= 4 and self.waterMap and major == true) then
        return false;
    else
        return true;
    end
end


------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__AddLeyLine(plot)
	local iResourcesInDB = 0;
	eResourceType	= {};
	eResourceClassType = {};
	aBonus = {};

	for row in GameInfo.Resources() do
		eResourceType[iResourcesInDB] = row.Hash;
		eResourceClassType[iResourcesInDB] = row.ResourceClassType;
	    iResourcesInDB = iResourcesInDB + 1;
	end

	for row = 0, iResourcesInDB do
		if (eResourceClassType[row] == "RESOURCECLASS_LEY_LINE") then
			if(eResourceType[row] ~= nil) then
				table.insert(aBonus, eResourceType[row]);
			end
		end
	end

	local plotX = plot:GetX();
	local plotY = plot:GetY();
	
	aShuffledBonus =  GetShuffledCopyOfTable(aBonus);
	for i, resource in ipairs(aShuffledBonus) do
		for dx = -2, 2, 1 do
			for dy = -2,2, 1 do
				local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 2);
				if(otherPlot) then
					if(ResourceBuilder.CanHaveResource(otherPlot, resource) and otherPlot:GetIndex() ~= plot:GetIndex()) then
						ResourceBuilder.SetResourceType(otherPlot, resource, 1);
						return;
					end
				end
			end
		end 
	end
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__CountAdjacentTerrainsInRange(plot, terrainType, major,watercheck:boolean,index)
    local count = 0;
    local plotX = plot:GetX();
    local plotY = plot:GetY();
	local range = 35
	if index ~= nil then
		range = index
	end
	if (not watercheck) then
		if major == false then
			for dir = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
				local adjacentPlot = Map.GetAdjacentPlot(plotX, plotY, dir);
				if(adjacentPlot ~= nil and adjacentPlot:GetTerrainType() == terrainType) then
                count = count + 1;
				end
			end
			elseif (terrainType == g_TERRAIN_TYPE_COAST) and (major == false or major == true)  then
			-- At least one adjacent coast but that is not a lake and not more than one
			for dir = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
            local adjacentPlot = Map.GetAdjacentPlot(plotX, plotY, dir);
				if(adjacentPlot ~= nil and adjacentPlot:GetTerrainType() == terrainType) then
					if (not adjacentPlot:IsLake() and count < 1) then
                    count = count + 1;
					end
				end
			end
			elseif major == true then
			for i = 1, range do
				local adjacentPlot = GetAdjacentTiles(plot, i)
				if(adjacentPlot ~= nil and adjacentPlot:GetTerrainType() == terrainType) then
                    count = count + 1;
				end
			end
		end
		return count;
		
		else
		
		for i = 1, 35 do
			local adjacentPlot = GetAdjacentTiles(plot, i)
            if(adjacentPlot ~= nil and adjacentPlot:IsWater() == true) then
                count = count + 1;
            end

        end

		return count
	end

end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__ScoreAdjacent(count, tier, bias_type)
    local score = 0;
	if bias_type == nil then
		if count ~= nil and tier ~= nil and tier ~= 0 then
			score = math.min(50 * count ^ (3/tier),500);
		end
		return score;
	end
	if bias_type == "RESOURCES" or bias_type == "NEGATIVE_RESOURCES" then
		if count ~= nil and tier ~= nil and tier ~= 0 then
			score = math.min(50 * count ^ (4/tier),1000);
		end
		return score;
	end
	if bias_type == "FEATURES" or bias_type == "NEGATIVE_FEATURES" then
		if count ~= nil and tier ~= nil and tier ~= 0 then
			score = math.min(50 * count ^ (3/tier),1000);
		end
		return score;
	end
	if bias_type == "TERRAINS" or bias_type == "NEGATIVE_TERRAINS" then
		if count ~= nil and tier ~= nil and tier ~= 0 then
			score = math.min(50 * count ^ (3/tier),1000);
		end
		return score;
	end
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__CountAdjacentFeaturesInRange(plot, featureType, major)
    local count = 0;
    local plotX = plot:GetX();
    local plotY = plot:GetY();
    if(not major) then
        for dir = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
            local adjacentPlot = Map.GetAdjacentPlot(plotX, plotY, dir);
            if(adjacentPlot ~= nil and adjacentPlot:GetFeatureType() == featureType) then
                count = count + 1;
            end
        end
    else
      	for i = 1, 17 do
			local adjacentPlot = GetAdjacentTiles(plot, i)
               if(adjacentPlot ~= nil and adjacentPlot:GetFeatureType() == featureType) then
                    count = count + 1;
               end
        end
    end
    return count;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__CountAdjacentContinentsInRange(plot, major)
    local count = 0;
    local plotX = plot:GetX();
    local plotY = plot:GetY();
	local continent = plot:GetContinentType()
    if(not major) then
        for dir = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
            local adjacentPlot = Map.GetAdjacentPlot(plotX, plotY, dir);
            if(adjacentPlot ~= nil and adjacentPlot:GetContinentType() ~= continent) then
                count = count + 1;
            end
        end
    else
      	for i = 1, 17 do
			local adjacentPlot = GetAdjacentTiles(plot, i)
                if(adjacentPlot ~= nil and adjacentPlot:GetContinentType() ~= continent) then
                    count = count + 1;
                end
        end

    end
    return count;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__CountAdjacentRiverInRange(plot, major)
    local count = 0;
    local plotX = plot:GetX();
    local plotY = plot:GetY();
    if(not major) then
        for dir = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
            local adjacentPlot = Map.GetAdjacentPlot(plotX, plotY, dir);
            if(adjacentPlot ~= nil and adjacentPlot:IsRiver() == true) then
                count = count + 1;
            end
        end
    else
      	for i = 1, 17 do
			local adjacentPlot = GetAdjacentTiles(plot, i)
                if(adjacentPlot ~= nil and adjacentPlot:IsRiver() == true) then
                    count = count + 1;
                end

        end
    end
    return count;
end
------------------------------------------------------------------------------
-----------------------------------------------------------------------------
function BBS_AssignStartingPlots:__CountAdjacentResourcesInRange(plot, resourceType, major, range)
    local count = 0;
    local plotX = plot:GetX();
    local plotY = plot:GetY();
	if range == nil then
		range = 2
	end
    if(not major) then
        for dir = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
            local adjacentPlot = Map.GetAdjacentPlot(plotX, plotY, dir);
            if(adjacentPlot ~= nil and adjacentPlot:GetResourceType() == resourceType) then
                count = count + 1;
            end
        end
    else
      	for i = 1, 17 do
			local adjacentPlot = GetAdjacentTiles(plot, i)
                if(adjacentPlot ~= nil and adjacentPlot:GetResourceType() == resourceType) then
                    count = count + 1;
                end

        end
    end
    return count;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__CountAdjacentYieldsInRange(plot)
    local score = 0;
    local food = 0;
    local prod = 0;
    local plotX = plot:GetX();
    local plotY = plot:GetY();
    for dir = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
        local adjacentPlot = Map.GetAdjacentPlot(plotX, plotY, dir);
        if(adjacentPlot ~= nil) then
            local foodTemp = 0;
            local prodTemp = 0;
            if (adjacentPlot:GetResourceType() ~= nil) then
                -- Coal or Uranium
                if (adjacentPlot:GetResourceType() == 41 or adjacentPlot:GetResourceType() == 46) then
                    prod = prod - 2;
                -- Horses or Niter
                elseif (adjacentPlot:GetResourceType() == 42 or adjacentPlot:GetResourceType() == 44) then
                    food = food - 1;
                    prod = prod - 1;
                -- Oil
                elseif (adjacentPlot:GetResourceType() == 45) then
                    prod = prod - 3;
                end
            end
            foodTemp = adjacentPlot:GetYield(g_YIELD_FOOD);
            prodTemp = adjacentPlot:GetYield(g_YIELD_PRODUCTION);
            if (foodTemp >= 2 and prodTemp >= 2) then
                score = score + 5;
            end
            food = food + foodTemp;
            prod = prod + prodTemp;
        end
    end
    score = score + food + prod;
    --if (prod == 0) then
    --    score = score - 5;
    --end
    return score;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__GetTerrainIndex(terrainType)
    if (terrainType == "TERRAIN_COAST") then
        return g_TERRAIN_TYPE_COAST;
    elseif (terrainType == "TERRAIN_DESERT") then
        return g_TERRAIN_TYPE_DESERT;
    elseif (terrainType == "TERRAIN_TUNDRA") then
        return g_TERRAIN_TYPE_TUNDRA;
    elseif (terrainType == "TERRAIN_SNOW") then
        return g_TERRAIN_TYPE_SNOW;
    elseif (terrainType == "TERRAIN_PLAINS") then
        return g_TERRAIN_TYPE_PLAINS;
    elseif (terrainType == "TERRAIN_GRASS") then
        return g_TERRAIN_TYPE_GRASS;
    elseif (terrainType == "TERRAIN_DESERT_HILLS") then
        return g_TERRAIN_TYPE_DESERT_HILLS;
    elseif (terrainType == "TERRAIN_TUNDRA_HILLS") then
        return g_TERRAIN_TYPE_TUNDRA_HILLS;
	elseif (terrainType == "TERRAIN_TUNDRA_MOUNTAIN") then
        return g_TERRAIN_TYPE_TUNDRA_MOUNTAIN;
    elseif (terrainType == "TERRAIN_SNOW_HILLS") then
        return g_TERRAIN_TYPE_SNOW_HILLS;
    elseif (terrainType == "TERRAIN_PLAINS_HILLS") then
        return g_TERRAIN_TYPE_PLAINS_HILLS;
    elseif (terrainType == "TERRAIN_GRASS_HILLS") then
        return g_TERRAIN_TYPE_GRASS_HILLS;
    elseif (terrainType == "TERRAIN_GRASS_MOUNTAIN") then
        return g_TERRAIN_TYPE_GRASS_MOUNTAIN;
    elseif (terrainType == "TERRAIN_PLAINS_MOUNTAIN") then
        return g_TERRAIN_TYPE_PLAINS_MOUNTAIN;
    elseif (terrainType == "TERRAIN_DESERT_MOUNTAIN") then
        return g_TERRAIN_TYPE_DESERT_MOUNTAIN;
    end
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__GetFeatureIndex(featureType)
    if (featureType == "FEATURE_VOLCANO") then
        return g_FEATURE_VOLCANO;
    elseif (featureType == "FEATURE_JUNGLE") then
        return g_FEATURE_JUNGLE;
    elseif (featureType == "FEATURE_FOREST") then
        return g_FEATURE_FOREST;
    elseif (featureType == "FEATURE_FLOODPLAINS") then
        return g_FEATURE_FLOODPLAINS;
    elseif (featureType == "FEATURE_FLOODPLAINS_PLAINS") then
        return g_FEATURE_FLOODPLAINS_PLAINS;
    elseif (featureType == "FEATURE_FLOODPLAINS_GRASSLAND") then
        return g_FEATURE_FLOODPLAINS_GRASSLAND;
    elseif (featureType == "FEATURE_GEOTHERMAL_FISSURE") then
        return g_FEATURE_GEOTHERMAL_FISSURE;
    end
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__GetResourceIndex(resourceType)
    local resourceTypeName = "LOC_" .. resourceType .. "_NAME";
    for row in GameInfo.Resources() do
        if (row.Name == resourceTypeName) then
            return row.Index;
        end
    end
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__BaseFertility(plot)
    -- Calculate the fertility of the starting plot
    local pPlot = Map.GetPlotByIndex(plot);
    local iFertility = StartPositioner.GetPlotFertility(pPlot:GetIndex(), -1);
    return iFertility;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__NaturalWonderBufferCheck(plot, major)
    -- Returns false if the player can start because there is a natural wonder too close.
    -- If Start position config equals legendary you can start near Natural wonders
    if(self.uiStartConfig == 3) then
        return true;
    end

    local iMaxNW = 4;

    if(major == false) then
        iMaxNW = GlobalParameters.START_DISTANCE_MINOR_NATURAL_WONDER or 3;
    else
        iMaxNW = GlobalParameters.START_DISTANCE_MAJOR_NATURAL_WONDER or 4;
    end

    local plotX = plot:GetX();
    local plotY = plot:GetY();
    for dx = -iMaxNW, iMaxNW do
        for dy = -iMaxNW, iMaxNW do
            local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, iMaxNW);
            if(otherPlot and otherPlot:IsNaturalWonder()) then
                return false;
            end
        end
    end
    return true;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__LuxuryBufferCheck(plot, major)
    -- Checks to see if there are luxuries in the given distance
    if (major and math.ceil(self.iDefaultNumberMajor * 1.25) + self.iDefaultNumberMinor > self.iNumMinorCivs + self.iNumMajorCivs) then
        local plotX = plot:GetX();
        local plotY = plot:GetY();
        for dx = -2, 2 do
            for dy = -2, 2 do
                local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, 2);
                if(otherPlot) then
                    if(otherPlot:GetResourceCount() > 0) then
                        for _, row in ipairs(self.rLuxury) do 
                            if(row.Index == otherPlot:GetResourceType()) then
                                return true;
                            end
                        end
                    end
                end
            end
        end
        return false;
    end
    return true;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__LuxuryCount(plot)
    -- Checks to see if there are luxuries in the given distance
		local count = 0
        local plotX = plot:GetX();
        local plotY = plot:GetY();
        for dx = -2, 2 do
            for dy = -2, 2 do
                local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, 2);
                if(otherPlot) then
                    if(otherPlot:GetResourceCount() > 0) then
                        for _, row in ipairs(self.rLuxury) do 
                            if(row.Index == otherPlot:GetResourceType()) then
                                count = count + 1
                            end
                        end
                    end
                end
            end
        end
		return count

end

------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__TryToRemoveBonusResource(plot)
    --Removes Bonus Resources underneath starting players
    for row in GameInfo.Resources() do
        if (row.ResourceClassType == "RESOURCECLASS_BONUS") then
            if(row.Index == plot:GetResourceType()) then
                ResourceBuilder.SetResourceType(plot, -1);
            end
        end
    end
end

------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__MinorMinorCivBufferCheck(plot)
    -- Checks to see if there are minors in the given distance for this minor civ
	-- Return arg1: True/False; arg2: Distance
	--------------------------------------------------------------------------------------
    local iMaxStart = GlobalParameters.START_DISTANCE_MINOR_CIVILIZATION_START or 7;
    --iMaxStart = iMaxStart - GlobalParameters.START_DISTANCE_RANGE_MINOR or 2;
	--local iMaxStart = 7;
	local minimumdistance = 15
	if Map.GetMapSize() == 4 then
		minimumdistance = 16
	end
	if Map.GetMapSize() > 4 then
		minimumdistance = 17
	end
    local iSourceIndex = plot:GetIndex();
    for i, minorPlotandID in ipairs(self.minorStartPlotsID) do
		if minorPlotandID.Plot == plot then
			return false, -1;
		end
		local tmp_distance = Map.GetPlotDistance(iSourceIndex, minorPlotandID.Plot:GetIndex())
        if(tmp_distance <= iMaxStart or tmp_distance < 7) then
            return false, -1;
        end
		if (tmp_distance < minimumdistance) then
			minimumdistance = tmp_distance
		end
    end
    return true, minimumdistance;
end

------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__MinorMajorCivBufferCheck(plot)
    -- Checks to see if there are majors in the given distance for this minor civ
    local iMaxStart = GlobalParameters.START_DISTANCE_MINOR_MAJOR_CIVILIZATION or 8;
    --local iMaxStart = 8;
    local iSourceIndex = plot:GetIndex();
    if(self.waterMap) then
        iMaxStart = iMaxStart - 1;
    end
	local minimumdistance = 15
	if Map.GetMapSize() == 4 then
		minimumdistance = 16
	end
	if Map.GetMapSize() > 4 then
		minimumdistance = 17
	end
    for i, majorPlot in ipairs(self.majorStartPlots) do
		if majorPlot == plot then
			return false, -1;
		end
		local tmp_distance = Map.GetPlotDistance(iSourceIndex, majorPlot:GetIndex())
        if(tmp_distance <= iMaxStart + Minor_Distance_Target or tmp_distance < 11 + Minor_Distance_Target or tmp_distance < self.iDistance_major_minor) then
            return false, -1;
        end
		if (tmp_distance < minimumdistance) then
			minimumdistance = tmp_distance
		end
    end
    return true, minimumdistance;
end

------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__MajorMajorCivBufferCheck(plot,team)
	--------------------------------------------------------------------------------------
    -- Checks to see if there are major civs in the given distance for this major civ
	-- Return arg1: True/False; arg2: Distance
	--------------------------------------------------------------------------------------
    local iMaxStart = GlobalParameters.START_DISTANCE_MAJOR_CIVILIZATION or 12;
    if(self.waterMap) then
        iMaxStart = iMaxStart - 3;
    end
    iMaxStart = iMaxStart - GlobalParameters.START_DISTANCE_RANGE_MAJOR or 2;
    --local iMaxStart = 10;
	local minimumdistance = 15
	if Map.GetMapSize() == 4 then
		minimumdistance = 16
	end
	if Map.GetMapSize() > 4 then
		minimumdistance = 17
	end
    local iSourceIndex = plot:GetIndex();
    for i, majorPlot in ipairs(self.majorStartPlots) do
		if (majorPlot == plot) then
			return false, -1;
		end
		local tmp_distance = Map.GetPlotDistance(iSourceIndex, majorPlot:GetIndex())
		if (tmp_distance <= iMaxStart) or (tmp_distance < Major_Distance_Target) then
			return false, -1;
		end
		if (tmp_distance < minimumdistance) then
			minimumdistance = tmp_distance
		end

    end
    return true, minimumdistance;
end

------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__AddBonusFoodProduction(plot)
    local food = 0;
    local production = 0;
    local maxFood = 0;
    local maxProduction = 0;
    local gridHeight = Map.GetGridSize();
    local terrainType = plot:GetTerrainType();

    for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
        local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
        if (adjacentPlot ~= nil) then
            terrainType = adjacentPlot:GetTerrainType();
            if(adjacentPlot:GetX() >= 0 and adjacentPlot:GetY() < gridHeight) then
                -- Gets the food and productions
                food = food + adjacentPlot:GetYield(g_YIELD_FOOD);
                production = production + adjacentPlot:GetYield(g_YIELD_PRODUCTION);

                --Checks the maxFood
                if(maxFood <=  adjacentPlot:GetYield(g_YIELD_FOOD)) then
                    maxFood = adjacentPlot:GetYield(g_YIELD_FOOD);
                end

                --Checks the maxProduction
                if(maxProduction <=  adjacentPlot:GetYield(g_YIELD_PRODUCTION)) then
                    maxProduction = adjacentPlot:GetYield(g_YIELD_PRODUCTION);
                end
            end
        end
    end

    if(food < 7 or maxFood < 3) then
        local retry = 0;
        while (food < 7 and retry < 2) do
            food = food + self:__AddFood(plot);
            retry = retry + 1;
        end
    end

    if(production < 5 or maxProduction < 2) then
        local retry = 0;
        while (production < 5 and retry < 2) do
            production = production + self:__AddProduction(plot);
            retry = retry + 1;
        end
    end
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__AddFood(plot)
    local foodAdded = 0;
    local dir = TerrainBuilder.GetRandomNumber(DirectionTypes.NUM_DIRECTION_TYPES, "Random Direction");
    for i = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
        local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), dir);
        if (adjacentPlot ~= nil) then
            local foodBefore = adjacentPlot:GetYield(g_YIELD_FOOD);
            local aShuffledBonus =  GetShuffledCopyOfTable(self.aBonusFood);
            for _, bonus in ipairs(aShuffledBonus) do
                if(ResourceBuilder.CanHaveResource(adjacentPlot, bonus.Index)) then
                    ResourceBuilder.SetResourceType(adjacentPlot, bonus.Index, 1);
                    foodAdded = adjacentPlot:GetYield(g_YIELD_FOOD) - foodBefore;
                    return foodAdded;
                end
            end
        end

        if(dir == DirectionTypes.NUM_DIRECTION_TYPES - 1) then
            dir = 0;
        else
            dir = dir + 1;
        end
    end
    return foodAdded;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__AddProduction(plot)
    local prodAdded = 0;
    local dir = TerrainBuilder.GetRandomNumber(DirectionTypes.NUM_DIRECTION_TYPES, "Random Direction");
    for i = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
        local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), dir);
        if (adjacentPlot ~= nil) then
            local prodBefore = adjacentPlot:GetYield(g_YIELD_PRODUCTION);
            local aShuffledBonus = GetShuffledCopyOfTable(self.aBonusProd);
            for _, bonus in ipairs(aShuffledBonus) do
                if(ResourceBuilder.CanHaveResource(adjacentPlot, bonus.Index)) then
                    ResourceBuilder.SetResourceType(adjacentPlot, bonus.Index, 1);
                    prodAdded = adjacentPlot:GetYield(g_YIELD_PRODUCTION) - prodBefore;
                    return prodAdded;
                end
            end
        end

        if(dir == DirectionTypes.NUM_DIRECTION_TYPES - 1) then
            dir = 0;
        else
            dir = dir + 1;
        end
    end
    return prodAdded;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__AddResourcesBalanced()
    local iStartEra = GameInfo.Eras[ GameConfiguration.GetStartEra() ];
    local iStartIndex = 1;
    if iStartEra ~= nil then
        iStartIndex = iStartEra.ChronologyIndex;
    end

    local iHighestFertility = 0;
    for _, plot in ipairs(self.majorStartPlots) do
        self:__RemoveBonus(plot);
        self:__BalancedStrategic(plot, iStartIndex);

        if(self:__BaseFertility(plot:GetIndex()) > iHighestFertility) then
            iHighestFertility = self:__BaseFertility(plot:GetIndex());
        end
    end

    for _, plot in ipairs(self.majorStartPlots) do
        local iFertilityLeft = iHighestFertility - self:__BaseFertility(plot:GetIndex());

        if(iFertilityLeft > 0) then
            if(self:__IsContinentalDivide(plot)) then
                --___Debug("START_FERTILITY_WEIGHT_CONTINENTAL_DIVIDE", GlobalParameters.START_FERTILITY_WEIGHT_CONTINENTAL_DIVIDE);
                local iContinentalWeight = math.floor((GlobalParameters.START_FERTILITY_WEIGHT_CONTINENTAL_DIVIDE or 250) / 10);
                iFertilityLeft = iFertilityLeft - iContinentalWeight
            else
                local bAddLuxury = true;
                --___Debug("START_FERTILITY_WEIGHT_LUXURY", GlobalParameters.START_FERTILITY_WEIGHT_LUXURY);
                local iLuxWeight = math.floor((GlobalParameters.START_FERTILITY_WEIGHT_LUXURY or 250) / 10);
                while iFertilityLeft >= iLuxWeight and bAddLuxury do
                    bAddLuxury = self:__AddLuxury(plot);
                    if(bAddLuxury) then
                        iFertilityLeft = iFertilityLeft - iLuxWeight;
                    end
                end
            end
            local bAddBonus = true;
            --___Debug("START_FERTILITY_WEIGHT_BONUS", GlobalParameters.START_FERTILITY_WEIGHT_BONUS);
            local iBonusWeight = math.floor((GlobalParameters.START_FERTILITY_WEIGHT_BONUS or 75) / 10);
            while iFertilityLeft >= iBonusWeight and bAddBonus do
                bAddBonus = self:__AddBonus(plot);
                if(bAddBonus) then
                    iFertilityLeft = iFertilityLeft - iBonusWeight;
                end
            end
        end
    end
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__AddResourcesLegendary()
    local iStartEra = GameInfo.Eras[ GameConfiguration.GetStartEra() ];
    local iStartIndex = 1;
    if iStartEra ~= nil then
        iStartIndex = iStartEra.ChronologyIndex;
    end

    local iLegendaryBonusResources = GlobalParameters.START_LEGENDARY_BONUS_QUANTITY or 2;
    local iLegendaryLuxuryResources = GlobalParameters.START_LEGENDARY_LUXURY_QUANTITY or 1;
    for i, plot in ipairs(self.majorStartPlots) do
        self:__BalancedStrategic(plot, iStartIndex);

        if(self:__IsContinentalDivide(plot)) then
            iLegendaryLuxuryResources = iLegendaryLuxuryResources - 1;
        else
            local bAddLuxury = true;
            while iLegendaryLuxuryResources > 0 and bAddLuxury do
                bAddLuxury = self:__AddLuxury(plot);
                if(bAddLuxury) then
                    iLegendaryLuxuryResources = iLegendaryLuxuryResources - 1;
                end
            end
        end

        local bAddBonus = true;
        iLegendaryBonusResources = iLegendaryBonusResources + 2 * iLegendaryLuxuryResources;
        while iLegendaryBonusResources > 0 and bAddBonus do
            bAddBonus = self:__AddBonus(plot);
            if(bAddBonus) then
                iLegendaryBonusResources = iLegendaryBonusResources - 1;
            end
        end
    end
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__BalancedStrategic(plot, iStartIndex)
    local iRange = STRATEGIC_RESOURCE_FERTILITY_STARTING_ERA_RANGE or 1;
    for _, row in ipairs(self.rStrategic) do
        if(iStartIndex - iRange <= row.RevealedEra and iStartIndex + iRange >= row.RevealedEra) then
            local bHasResource = false;
            bHasResource = self:__FindSpecificStrategic(row.Index, plot);
            if(not bHasResource) then
                self:__AddStrategic(row.Index, plot)
                ___Debug("Strategic Resource Placed :", row.Name);
            end
        end
    end
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__FindSpecificStrategic(eResourceType, plot)
    -- Checks to see if there is a specific strategic in a given distance
    local plotX = plot:GetX();
    local plotY = plot:GetY();
    for dx = -3, 3 do
        for dy = -3,3 do
            local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, 3);
            if(otherPlot) then
                if(otherPlot:GetResourceCount() > 0) then
                    if(eResourceType == otherPlot:GetResourceType()) then
                        return true;
                    end
                end
            end
        end
    end
    return false;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__AddStrategic(eResourceType, plot)
    -- Checks to see if it can place a specific strategic
    local plotX = plot:GetX();
    local plotY = plot:GetY();
    for dx = -2, 2 do
        for dy = -2, 2 do
            local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, 2);
            if(otherPlot) then
                if(ResourceBuilder.CanHaveResource(otherPlot, eResourceType) and otherPlot:GetIndex() ~= plot:GetIndex()) then
                    ResourceBuilder.SetResourceType(otherPlot, eResourceType, 1);
                    return;
                end
            end
        end
    end
    for dx = -3, 3 do
        for dy = -3, 3 do
            local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, 3);
            if(otherPlot) then
                if(ResourceBuilder.CanHaveResource(otherPlot, eResourceType) and otherPlot:GetIndex() ~= plot:GetIndex()) then
                    ResourceBuilder.SetResourceType(otherPlot, eResourceType, 1);
                    return;
                end
            end
        end
    end
    ___Debug("Failed to add Strategic.");
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__AddLuxury(plot)
    local plotX = plot:GetX();
    local plotY = plot:GetY();
    local eAddLux = {};
    for dx = -4, 4 do
        for dy = -4, 4 do
            local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, 4);
            if(otherPlot) then
                if(otherPlot:GetResourceCount() > 0) then
                    for _, row in ipairs(self.rLuxury) do
                        if(otherPlot:GetResourceType() == row.Index) then
                            table.insert(eAddLux, row);
                        end
                    end
                end
            end
        end
    end

    for dx = -2, 2 do
        for dy = -2, 2 do
            local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, 2);
            if(otherPlot) then
                eAddLux = GetShuffledCopyOfTable(eAddLux);
                for _, resource in ipairs(eAddLux) do
                    if(ResourceBuilder.CanHaveResource(otherPlot, resource.Index) and otherPlot:GetIndex() ~= plot:GetIndex()) then
                        ResourceBuilder.SetResourceType(otherPlot, resource.Index, 1);
                        ___Debug("Yeah Lux");
                        return true;
                    end
                end
            end
        end
    end

    ___Debug("Failed Lux");
    return false;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__AddBonus(plot)
    local plotX = plot:GetX();
    local plotY = plot:GetY();
    local aBonus =  GetShuffledCopyOfTable(self.rBonus);
    for _, resource in ipairs(aBonus) do
        for dx = -2, 2 do
            for dy = -2, 2 do
                local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, 2);
                if(otherPlot) then
                    --___Debug(otherPlot:GetX(), otherPlot:GetY(), "Resource Index :", resource.Index);
                    if(ResourceBuilder.CanHaveResource(otherPlot, resource.Index) and otherPlot:GetIndex() ~= plot:GetIndex()) then
                        ResourceBuilder.SetResourceType(otherPlot, resource.Index, 1);
                        ___Debug("Yeah Bonus");
                        return true;
                    end
                end
            end
        end
    end

    ___Debug("Failed Bonus");
    return false
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__IsContinentalDivide(plot)
    local plotX = plot:GetX();
    local plotY = plot:GetY();

    local eContinents = {};

    for dx = -4, 4 do
        for dy = -4, 4 do
            local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, 4);
            if(otherPlot) then
                if(otherPlot:GetContinentType() ~= nil) then
                    if(#eContinents == 0) then
                        table.insert(eContinents, otherPlot:GetContinentType());
                    else
                        if(eContinents[1] ~= otherPlot:GetContinentType()) then
                            return true;
                        end
                    end
                end
            end
        end
    end

    return false;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__RemoveBonus(plot)
    local plotX = plot:GetX();
    local plotY = plot:GetY();
    for _, resource in ipairs(self.rBonus) do
        for dx = -3, 3 do
            for dy = -3,3 do
                local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, 3);
                if(otherPlot) then
                    if(resource.Index == otherPlot:GetResourceType()) then
                        ResourceBuilder.SetResourceType(otherPlot, resource.Index, -1);
                        return;
                    end
                end
            end
        end
    end
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__TableSize(table)
    local count = 0;
    for _ in pairs(table) do
        count = count + 1;
    end
    return count;
end
------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__GetShuffledCiv(incoming_table,param)
	-- Designed to operate on tables with no gaps. Does not affect original table.
	local len = table.maxn(incoming_table);
	local copy = {};
	local shuffledVersion = {};
	-- Make copy of table.
	for loop = 1, len do
		copy[loop] = incoming_table[loop];
	end
	-- One at a time, choose a random index from Copy to insert in to final table, then remove it from the copy.
	local left_to_do = table.maxn(copy);
	for loop = 1, len do
		local random_index = 0
		for n = 1, param do
			random_index = 1 + TerrainBuilder.GetRandomNumber(left_to_do, "Shuffling table entry - Lua");
		end
		table.insert(shuffledVersion, copy[random_index]);
		table.remove(copy, random_index);
		left_to_do = left_to_do - 1;
	end
	return shuffledVersion
end

---------------------------------------
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

		___Debug("GetAdjacentTiles: Invalid Arguments");
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
			--___Debug(i, j)
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

---------------------------------------
function GetIslandPerimeter(plot,B_debug,B_first_layer,B_report)
	-- This is a function to compute the number of tiles around the islands to determinate their sizekey
	
	if plot == nil or plot:GetX() == nil then
		return -1
	end
	local gridWidth, gridHeight = Map.GetGridSize();

	--if plot:GetX() == 50 and plot:GetY() == 53 then
	--	B_debug = true 
	--end
	if B_debug == true then
		print("CHECKING",	plot:GetX(),plot:GetY())
	end
	local orig_X = plot:GetX()
	local orig_Y = plot:GetY()
	local coaststart_plot = {}
	local count = 0
	-- Is True Coast
	local b_true_coast = false
	for w = 0, 5 do 
		if(plot:GetX() >= 0 and plot:GetY() < gridHeight) then 
		local test_plot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), w)
			if test_plot ~= nil and test_plot:IsWater() and test_plot:IsLake() == false and test_plot:IsNaturalWonder() == false then
				b_true_coast = true
				break
			end
		end
	end	
	
	if (b_true_coast == true) then
		coaststart_plot = plot
		if B_debug == true then
			print("VALID COASTAL",	coaststart_plot:GetX(),coaststart_plot:GetY())
		end
		else
		if B_debug == true then
			print("NOT VALID COASTAL")
		end
		for x = orig_X, gridWidth, 1 do
			local check_plot = Map.GetPlot(x,orig_Y)
			if check_plot ~= nil  then
				for w = 0, 5 do 
					if(check_plot:GetX() >= 0 and check_plot:GetY() < gridHeight) then 
						local test_plot = Map.GetAdjacentPlot(check_plot:GetX(), check_plot:GetY(), w)
						if test_plot ~= nil and test_plot:IsWater() and test_plot:IsLake() == false and test_plot:IsNaturalWonder() == false then
							b_true_coast = true
							break
						end
					end
				end
				if b_true_coast == true then
					if B_debug == true then
						print("FOUND TRUE OCEAN")
					end
					coaststart_plot = check_plot
					break
				end
			end
		end
		if coaststart_plot == nil or b_true_coast == false then
			if B_debug == true then
				print("SCAN FOR NEAREST COAST")
			end
			for x = orig_X, 0, -1 do
				local check_plot = Map.GetPlot(x,orig_Y)
				if check_plot ~= nil then
					local b_true_coast = false
					for w = 0, 5 do 
						if(check_plot:GetX() >= 0 and check_plot:GetY() < gridHeight) then 
							local test_plot = Map.GetAdjacentPlot(check_plot:GetX(), check_plot:GetY(), w)
							if test_plot ~= nil and test_plot:IsWater() and test_plot:IsLake() == false and test_plot:IsNaturalWonder() == false then
								b_true_coast = true
								break
							end
						end
					end
					if b_true_coast == true then
						coaststart_plot = check_plot
						break
					end
				end
			end		
		end	
		if coaststart_plot == nil then
			return 666
		end
	end

	-- Check if not already existing large Island
	local cache_count = 0 
	if g_large_islands ~= nil then
		if B_debug == true then
		print("CHECKING: Closest Coastal",	plot:GetX(),plot:GetY())
		end
		local b_already_calculated = false
		for i, island in ipairs(g_large_islands) do
			for p, plot in ipairs(island) do 
				if plot == coaststart_plot then
					b_already_calculated = true
					break
				end
			end
			if b_already_calculated == true then
				count = 0
				for p, plot in ipairs(island) do 
					count = count + 1
				end
				if B_debug == true then
					print("ALREADY CALCULATED",	coaststart_plot:GetX(),coaststart_plot:GetY(),count,"ISLAND #",i)
				end
				if count > 60 then
					if B_debug == true then
						print("BIG ENOUGH STOP HERE",	coaststart_plot:GetX(),coaststart_plot:GetY())
					end		
					return count
					else
					cache_count = count
					break
				end
				else
				if B_debug == true then
					print("NOT ALREADY CALCULATED",	coaststart_plot:GetX(),coaststart_plot:GetY())
				end				
			end
		end
		else
		if B_debug == true then
		print("CHECKING: Closest Coastal Failed")
		end
		return -1
	end

	-- calculate the perimeter
	local perimeter_plot = {}
	count = 0
	table.insert(perimeter_plot,coaststart_plot)
	count = count + 1
	local active_plot = {} 
	local previous_plot = {} 
	active_plot = coaststart_plot
	previous_plot = coaststart_plot
	local lower_bound = 0
	local upper_bound = 5
	local dead_end = false
	local inc = 1
	for i = 0, 100 do
		for d = lower_bound, upper_bound, inc do
			if active_plot ~= nil and active_plot:GetX() ~= nil and active_plot:GetY() ~= nil and gridHeight ~= nil then
				if(active_plot:GetX() >= 0 and active_plot:GetY() < (gridHeight - 1) and active_plot:GetY() > 0) then 
					local adj_plot = Map.GetAdjacentPlot(active_plot:GetX(), active_plot:GetY(), d)
					if B_debug == true then
						print("CHECK:",active_plot:GetX(),active_plot:GetY(),d,adj_plot:GetX(),adj_plot:GetY(),adj_plot:IsCoastalLand())
					end
					local b_already_found = false
					local b_true_ocean = false
					-- add snow / ICE
					if adj_plot ~= nil and adj_plot:IsWater() == false and (adj_plot:GetTerrainType() ~= 15 and adj_plot:GetTerrainType() ~= 16) then
						for w = 0, 5 do 
							if(adj_plot:GetX() >= 0 and adj_plot:GetY() < gridHeight) then 
								local test_plot = Map.GetAdjacentPlot(adj_plot:GetX(), adj_plot:GetY(), w)
								if test_plot ~= nil and test_plot:IsWater() and test_plot:IsLake() == false then
									b_true_ocean = true
									break
								end
							end
						end
					end
					for p, perim_plot in ipairs(perimeter_plot) do
						if perim_plot == adj_plot then
							b_already_found = true
							break
						end
					end
					if b_already_found == false and adj_plot ~= nil and b_true_ocean == true and adj_plot:IsWater() == false and (adj_plot:GetTerrainType() ~= 15 and adj_plot:GetTerrainType() ~= 16) then
						table.insert(perimeter_plot,adj_plot)
						if B_debug == true then
							print("ADD A:",adj_plot:GetX(),adj_plot:GetY(),count,"WAS AT",active_plot:GetX(),active_plot:GetY())
						end
						count = count + 1
						previous_plot = active_plot
						active_plot = adj_plot
						break
					end
					-- reaching a top border / bottom 
				elseif active_plot:GetY() == gridHeight - 1 or active_plot:GetY() ==  0 then
					if B_debug == true then
						print("BORDER:",active_plot:GetX(),active_plot:GetY())
					end
					local low_p = 2
					local high_p = 4
					local inc_p = 1
					if active_plot:GetY() ==  0 then
						low_p = 0
						high_p = 1
						inc_p = 1
					end
			
					local b_moved_away = false
					local adj_plot = Map.GetAdjacentPlot(active_plot:GetX(), active_plot:GetY(), 1)
					if adj_plot ~= nil and adj_plot:IsCoastalLand() == false and (adj_plot:GetTerrainType() ~= 15 and adj_plot:GetTerrainType() ~= 16) then
						local b_already_found = false
						for p, perim_plot in ipairs(perimeter_plot) do
							if perim_plot == adj_plot then
								b_already_found = true
								break
							end
						end
						if b_already_found == false then
							table.insert(perimeter_plot,adj_plot)
							if B_debug == true then
							print("ADD B:",adj_plot:GetX(),adj_plot:GetY(),count,"WAS AT",active_plot:GetX(),active_plot:GetY())
							end
							count = count + 1
							previous_plot = active_plot
							active_plot = adj_plot
							break
						end
				
					elseif adj_plot ~= nil and adj_plot:IsCoastalLand() == true and (adj_plot:GetTerrainType() ~= 15 and adj_plot:GetTerrainType() ~= 16) then
						local b_already_found = false
						for p, perim_plot in ipairs(perimeter_plot) do
							if perim_plot == adj_plot then
								b_already_found = true
								break
							end
						end
						if b_already_found == false then
							table.insert(perimeter_plot,adj_plot)
							count = count + 1
							previous_plot = adj_plot
							for n = low_p, high_p, inc_p do
								adj_plot = Map.GetAdjacentPlot(previous_plot:GetX(), previous_plot:GetY(), n)
								if adj_plot ~= nil and adj_plot:IsCoastalLand() == true and (adj_plot:GetTerrainType() ~= 15 and adj_plot:GetTerrainType() ~= 16) then
									b_already_found = false
									for p, perim_plot in ipairs(perimeter_plot) do
										if perim_plot == adj_plot then
											b_already_found = true
											break
										end
									end
									if b_already_found == false then
										table.insert(perimeter_plot,adj_plot)
										if B_debug == true then
											print("ADD C:",adj_plot:GetX(),adj_plot:GetY(),count,"WAS AT",previous_plot:GetX(),previous_plot:GetY())
										end
										count = count + 1
										active_plot = adj_plot
										b_moved_away = true
										break
									end	
								end
							end
						end				
					end
					if b_moved_away == true then
						break
					end
					local adj_plot = Map.GetAdjacentPlot(active_plot:GetX(), active_plot:GetY(), 4)
					low_p = 2
					high_p = 4
					inc_p = -1
					if active_plot:GetY() ==  0 then
						low_p = 4
						high_p = 5
						inc_p = -1
					end		
					if adj_plot ~= nil and adj_plot:IsCoastalLand() == false and (adj_plot:GetTerrainType() ~= 15 and adj_plot:GetTerrainType() ~= 16) then
						local b_already_found = false
						for p, perim_plot in ipairs(perimeter_plot) do
							if perim_plot == adj_plot then
								b_already_found = true
								break
							end
						end
						if b_already_found == false then
							table.insert(perimeter_plot,adj_plot)
							count = count + 1
							previous_plot = active_plot
							active_plot = adj_plot
							break
						end
				
					elseif adj_plot ~= nil and adj_plot:IsCoastalLand() == true and (adj_plot:GetTerrainType() ~= 15 and adj_plot:GetTerrainType() ~= 16) then
						local b_already_found = false
						for p, perim_plot in ipairs(perimeter_plot) do
							if perim_plot == adj_plot then
								b_already_found = true
								break
							end
						end
						if b_already_found == false then
							table.insert(perimeter_plot,adj_plot)
							count = count + 1
							previous_plot = adj_plot
							for n = high_p, low_p, inc_p do
								adj_plot = Map.GetAdjacentPlot(previous_plot:GetX(), previous_plot:GetY(), n)
								if adj_plot ~= nil and adj_plot:IsCoastalLand() == true and (adj_plot:GetTerrainType() ~= 15 and adj_plot:GetTerrainType() ~= 16) then
									b_already_found = false
									for p, perim_plot in ipairs(perimeter_plot) do
										if perim_plot == adj_plot then
											b_already_found = true
											break
										end
									end
									if b_already_found == false then
										table.insert(perimeter_plot,adj_plot)
										if B_debug == true then
											print("ADD D:",adj_plot:GetX(),adj_plot:GetY(),count,"WAS AT",previous_plot:GetX(),previous_plot:GetY())
										end
										count = count + 1
										active_plot = adj_plot
										b_moved_away = true
										break
									end	
								end
							end
						end				
					end
				end
			end

		
			if d == upper_bound then
			-- Check for ice.
			local b_ice = false
			if(active_plot:GetY() < gridHeight / 0.25) then 
				for t = 1, 4, 1 do
					local test_plot = Map.GetAdjacentPlot(active_plot:GetX(), active_plot:GetY(), t)
					if test_plot ~= nil and test_plot:IsWater() == false then
						for w = 0, 5 do 
							if(test_plot:GetX() >= 0 and test_plot:GetY() < gridHeight+1) then 
								local check_plot = Map.GetAdjacentPlot(test_plot:GetX(), test_plot:GetY(), w)
								if check_plot ~= nil and check_plot:IsWater() and check_plot:IsLake() == false then
									active_plot = test_plot
									if B_debug == true then
										print("ADD E:",test_plot:GetX(),test_plot:GetY(),count,"WAS AT",previous_plot:GetX(),previous_plot:GetY())
									end
									count = count + 1
									b_ice = true
									break
								end
							end
						end
					end
				end	

				elseif active_plot:GetY() > gridHeight / 0.75 then
				for t = 0, 5, 1 do
					local test_plot = Map.GetAdjacentPlot(active_plot:GetX(), active_plot:GetY(), t)
					if test_plot ~= nil and test_plot:IsWater() == false then
						for w = 0, 5 do 
							if(test_plot:GetX() >= 0 and test_plot:GetY() < gridHeight+1) then 
								local check_plot = Map.GetAdjacentPlot(test_plot:GetX(), test_plot:GetY(), w)
								if check_plot ~= nil and check_plot:IsWater() and check_plot:IsLake() == false then
									active_plot = test_plot
									if B_debug == true then
										print("ADD F:",test_plot:GetX(),test_plot:GetY(),count,"WAS AT",previous_plot:GetX(),previous_plot:GetY())
									end
									count = count + 1
									b_ice = true
									break
								end
							end
						end
					end
				end	
			end
			if b_ice == true then
				break
				-- Break the ice, Got it !?
			end
			if active_plot == previous_plot then
				if B_debug == true then
					print("STUCK:",active_plot:GetX(),active_plot:GetY(),count)
				end
				break
				else
				active_plot = previous_plot
			end
			end
		
		end
		
		if active_plot == previous_plot and active_plot ~= coaststart_plot then
			local land_tile = 0
			for d = 0, 5 do
				if active_plot ~= nil then
					if(active_plot:GetX() >= 0 and active_plot:GetY() < gridHeight) then 
						local adj_plot = Map.GetAdjacentPlot(active_plot:GetX(), active_plot:GetY(), d)
						if adj_plot ~= nil and adj_plot:IsWater() == false then
							land_tile = land_tile + 1
						end
					end
				end
			end
			if land_tile < 3 or dead_end == true then
				if dead_end == false then
					lower_bound = 5
					upper_bound = 0
					inc = -1
					active_plot = coaststart_plot
					previous_plot = coaststart_plot
					dead_end = true
					else
					break
				end
			end
		elseif active_plot == previous_plot and active_plot == coaststart_plot then 
			-- one tile island
			if B_debug == true then
				print("STUCK ON ONE TILE:",active_plot:GetX(),active_plot:GetY(),count)
				break
			end
		end
	end
	
	-- Building the cache
	if count > 4 then
		-- Check if we do not have already found a coast line.
		if B_debug == true then
			print("BIG ENOUGH TO ADD",count)
		end
		local b_already_cached = false
		local island_index = -1
		if g_large_islands ~= nil then
			for i, island in ipairs(g_large_islands) do 
				for m, freshplot in ipairs(perimeter_plot) do
					for p, plot in ipairs(island) do	
						if plot == freshplot then
							b_already_cached = true
							island_index = i
							if B_debug == true then
								print("FOUND EXISTING ISLAND",i)
							end
							break
						end
					end
					if b_already_cached == true then
						break
					end
				end
				if b_already_cached == true then
					break
				end
			end
			if b_already_cached == true and island_index ~= -1 then
				for m, freshplot in ipairs(perimeter_plot) do
					local b_is_new_plot = true
					for p, plot in ipairs(g_large_islands[island_index]) do
						if plot == freshplot then
							--print("MATCH",freshplot:GetX(),freshplot:GetY(),"TO ISLAND",plot:GetX(),plot:GetY(),island_index)
							b_is_new_plot = false
							break
							else
							--print("DO NOT MATCH",freshplot:GetX(),freshplot:GetY(),"TO ISLAND",plot:GetX(),plot:GetY(),island_index)
						end		
					end
					if b_is_new_plot == true then
						table.insert(g_large_islands[island_index],freshplot)
						if B_debug == true then
							print("ADDED",freshplot:GetX(),freshplot:GetY(),"TO ISLAND",island_index)
						end
					else
						if B_debug == true then
							print("ALREADY THERE",freshplot:GetX(),freshplot:GetY(),"TO ISLAND",island_index)
						end				
					end
				end
			end
		end
		if b_already_cached == false then
			table.insert(g_large_islands,perimeter_plot)
			if B_debug == true then
				print("NEW ISLAND",perimeter_plot)
			end
		end
	else
		if B_debug == true then
			print("TOO SMALL TO ADD",count)
		end
	end
	if B_debug == true then
		print("RETURN --------------------------------------------------------------------------------------------",count, cache_count)
	end
	if count < 60 then
		if B_debug == true then
		print("PLOT",plot:GetX(),plot:GetY(),count,cache_count)
		end
	end
	
	-- Check duplicate
	if B_first_layer == true and B_report == true then
	local count_island = 0
	if g_large_islands ~= nil then
		for i, island in ipairs(g_large_islands) do 
			count_island = count_island + 1 
		end
	end
	if count_island > 1 then
		local b_is_continuous = false
		for i, island in ipairs(g_large_islands) do 
			for j, island_duplicate in ipairs(g_large_islands) do 
				if island ~= island_duplicate and island ~= nil and island_duplicate ~= nil then
					for p, plot in ipairs(island) do
						for n, plot_duplicate in ipairs(island_duplicate) do
							if plot ~= nil and plot_duplicate ~= nil and plot:GetX() == plot_duplicate:GetX() and plot:GetY() == plot_duplicate:GetY() then
								if B_debug == true then
								print("IS CONTINOUS",plot:GetX(),plot:GetY(),"Island A",i,"island B",j)
								print("IS CONTINOUS",plot_duplicate:GetX(),plot_duplicate:GetY(),"Island A",i,"island B",j)
								end
								b_is_continuous = true
								break
							end
						end
						if b_is_continuous == true then
							if B_debug == true then
							print("IS CONTINOUS",plot:GetX(),plot:GetY(),"Island A",i,"island B",j)
							end
							break
						end
					end
					if b_is_continuous == true then
						for n, plot_duplicate in ipairs(island_duplicate) do
							local b_new_plot = true 
							for p, plot in ipairs(island) do
								if plot == plot_duplicate then
									b_new_plot = false
									break
								end
							end
							if b_new_plot == true then
								if B_debug == true then
								print("ADD PLOT","Island A",i,plot_duplicate:GetX(),plot_duplicate:GetY()," From Island B",j)
								end
								table.insert(g_large_islands[i],plot_duplicate)
							end
						end
						if B_debug == true then
						print("DELETE DUPLICATE:",j)
						end
						g_large_islands[j] = nil
						break
					end
				end
			end	
			b_is_continuous = false
		end	
	end
	end
	
	if B_report == true then
		if g_large_islands ~= nil then
			for i, island in ipairs(g_large_islands) do
				local size = 0
				local ref_plot = nil
				for p, plot in ipairs(island) do
					if plot ~= nil then
						size = size + 1
						ref_plot = plot
					end
				end
				print("ISLAND #",i,"SIZE",size,"ANCHOR",ref_plot:GetX(),ref_plot:GetY())
			end		
			else
			print("NO LARGE ISLANDS DETECTED")
		end
	end
	if cache_count > count then
		return cache_count
		else
		return count
	end
	
end
	