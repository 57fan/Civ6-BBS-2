------------------------------------------------------------------------------
--	FILE:	BBS_AssignStartingPlot.lua    -- 1.6.9
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
local Major_Distance_Target = 16
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


--- New vars ---

local mapIsRoundWestEast = true;
local mapXSize = 0;
local mapYSize = 0;

-- True = a player is too close to that location to be settle-able ---
local isPlayerProximityBlocked = {};
local mapSpawnable = {}; -- whether the tile can be settled or not
local mapResourceCode = {};
local mapTerrainCode = {};
local mapFeatureCode = {};
local mapLake = {}; -- true = lake, false = not
local mapSea = {}; -- true = sea water (not lake)
local mapCoastal = {}; -- true = Coastal, false = not
local mapFreshWater = {};
local mapRiver = {};
local mapContinent = {};
-- If another continent is within 3 tiles
local mapIsContinentSplit = {};
local mapWonder = {};


local mapFoodYield = {};
local mapProdYield = {};
local mapGoldYield = {};
local mapScienceYield = {};
local mapCultureYield = {};
local mapFaithYield = {};

--- civ related ---

local majorList = {};
local majorBiases = {};


local majorBiasOKlandOKWaterOK = {};
local majorBiasOKlandOKWaterNOK = {};
local majorBiasOKlandNOKWaterOK = {};
local majorBiasOKlandOKWaterNOK = {};
local majorBiasNOKlandOK = {};
local majorBiasNOKlandNOK = {};

local minorList = {};
local minorBiases = {};


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
local twoTwoCount = 0;

-- percentage required for a bias Tx t

local TERRAIN_PERCENTAGE_B1_R3 = 0.65;
local TERRAIN_PERCENTAGE_B1_R5 = 0.55;

local TERRAIN_PERCENTAGE_B2_R3 = 0.6;
local TERRAIN_PERCENTAGE_B2_R5 = 0.5;

local TERRAIN_PERCENTAGE_B3_R3 = 0.4;
local TERRAIN_PERCENTAGE_B3_R5 = 0.3;

local TERRAIN_PERCENTAGE_B4_R3 = 0.3;
local TERRAIN_PERCENTAGE_B4_R5 = 0.2;

local TERRAIN_PERCENTAGE_B5_R3 = 0.2;
local TERRAIN_PERCENTAGE_B5_R5 = 0.2;


-- Negative version

local NEGATIVE_TERRAIN_PERCENTAGE_B1_R3 = 0.02;
local NEGATIVE_TERRAIN_PERCENTAGE_B1_R5 = 0.05;

local NEGATIVE_TERRAIN_PERCENTAGE_B2_R3 = 0.05;
local NEGATIVE_TERRAIN_PERCENTAGE_B2_R5 = 0.10;

local NEGATIVE_TERRAIN_PERCENTAGE_B3_R3 = 0.10;
local NEGATIVE_TERRAIN_PERCENTAGE_B3_R5 = 0.15;

local NEGATIVE_TERRAIN_PERCENTAGE_B4_R3 = 0.15;
local NEGATIVE_TERRAIN_PERCENTAGE_B4_R5 = 0.20;

local NEGATIVE_TERRAIN_PERCENTAGE_B5_R3 = 0.15;
local NEGATIVE_TERRAIN_PERCENTAGE_B5_R5 = 0.20;

---- Mountains

local MOUNTAIN_PERCENTAGE_B1_R3 = 0.35;
local MOUNTAIN_PERCENTAGE_B1_R5 = 0.25;

local MOUNTAIN_PERCENTAGE_B2_R3 = 0.30;
local MOUNTAIN_PERCENTAGE_B2_R5 = 0.25;

local MOUNTAIN_PERCENTAGE_B3_R3 = 0.25;
local MOUNTAIN_PERCENTAGE_B3_R5 = 0.20;

local MOUNTAIN_PERCENTAGE_B4_R3 = 0.20;
local MOUNTAIN_PERCENTAGE_B4_R5 = 0.15;

local MOUNTAIN_PERCENTAGE_B5_R3 = 0.15;
local MOUNTAIN_PERCENTAGE_B5_R5 = 0.10;


-- Negative version

local NEGATIVE_MOUNTAIN_PERCENTAGE_B1_R3 = 0.10;
local NEGATIVE_MOUNTAIN_PERCENTAGE_B1_R5 = 0.10;

local NEGATIVE_MOUNTAIN_PERCENTAGE_B2_R3 = 0.15;
local NEGATIVE_MOUNTAIN_PERCENTAGE_B2_R5 = 0.15;

local NEGATIVE_MOUNTAIN_PERCENTAGE_B3_R3 = 0.15;
local NEGATIVE_MOUNTAIN_PERCENTAGE_B3_R5 = 0.15;

local NEGATIVE_MOUNTAIN_PERCENTAGE_B4_R3 = 0.15;
local NEGATIVE_MOUNTAIN_PERCENTAGE_B4_R5 = 0.15;

local NEGATIVE_MOUNTAIN_PERCENTAGE_B5_R3 = 0.15;
local NEGATIVE_MOUNTAIN_PERCENTAGE_B5_R5 = 0.15;


-- Resources --

local RESOURCE_PERCENTAGE_B1_R3 = 0.15;
local RESOURCE_PERCENTAGE_B1_R5 = 0.10;

local RESOURCE_PERCENTAGE_B2_R3 = 0.12;
local RESOURCE_PERCENTAGE_B2_R5 = 0.09;

local RESOURCE_PERCENTAGE_B3_R3 = 0.10;
local RESOURCE_PERCENTAGE_B3_R5 = 0.075;

local RESOURCE_PERCENTAGE_B4_R3 = 0.07;
local RESOURCE_PERCENTAGE_B4_R5 = 0.05;

local RESOURCE_PERCENTAGE_B5_R3 = 0.03;
local RESOURCE_PERCENTAGE_B5_R5 = 0.03;

--- Negative Resources ---
--- If more than the percentage is found, bias will be deemed as not respected ! ---

local NEGATIVE_RESOURCE_PERCENTAGE_B1_R3 = 0.15;
local NEGATIVE_RESOURCE_PERCENTAGE_B1_R5 = 0.10;

local NEGATIVE_RESOURCE_PERCENTAGE_B2_R3 = 0.12;
local NEGATIVE_RESOURCE_PERCENTAGE_B2_R5 = 0.09;

local NEGATIVE_RESOURCE_PERCENTAGE_B3_R3 = 0.10;
local NEGATIVE_RESOURCE_PERCENTAGE_B3_R5 = 0.075;

local NEGATIVE_RESOURCE_PERCENTAGE_B4_R3 = 0.07;
local NEGATIVE_RESOURCE_PERCENTAGE_B4_R5 = 0.05;

local NEGATIVE_RESOURCE_PERCENTAGE_B5_R3 = 0.03;
local NEGATIVE_RESOURCE_PERCENTAGE_B5_R5 = 0.03;

-- Features --

local FEATURE_PERCENTAGE_B1_R3 = 0.15;
local FEATURE_PERCENTAGE_B1_R5 = 0.10;

local FEATURE_PERCENTAGE_B2_R3 = 0.12;
local FEATURE_PERCENTAGE_B2_R5 = 0.09;

local FEATURE_PERCENTAGE_B3_R3 = 0.10;
local FEATURE_PERCENTAGE_B3_R5 = 0.075;

local FEATURE_PERCENTAGE_B4_R3 = 0.07;
local FEATURE_PERCENTAGE_B4_R5 = 0.05;

local FEATURE_PERCENTAGE_B5_R3 = 0.03;
local FEATURE_PERCENTAGE_B5_R5 = 0.03;

--- Negative Resources ---
--- If more than the percentage is found, bias will be deemed as not respected ! ---

local NEGATIVE_FEATURE_PERCENTAGE_B1_R3 = 0.15;
local NEGATIVE_FEATURE_PERCENTAGE_B1_R5 = 0.10;

local NEGATIVE_FEATURE_PERCENTAGE_B2_R3 = 0.12;
local NEGATIVE_FEATURE_PERCENTAGE_B2_R5 = 0.09;

local NEGATIVE_FEATURE_PERCENTAGE_B3_R3 = 0.10;
local NEGATIVE_FEATURE_PERCENTAGE_B3_R5 = 0.075;

local NEGATIVE_FEATURE_PERCENTAGE_B4_R3 = 0.07;
local NEGATIVE_FEATURE_PERCENTAGE_B4_R5 = 0.05;

local NEGATIVE_FEATURE_PERCENTAGE_B5_R3 = 0.03;
local NEGATIVE_FEATURE_PERCENTAGE_B5_R5 = 0.03;

--- River tiles


local RIVER_PERCENTAGE_B1_R3 = 0.50;
local RIVER_PERCENTAGE_B1_R5 = 0.30;

local RIVER_PERCENTAGE_B2_R3 = 0.45;
local RIVER_PERCENTAGE_B2_R5 = 0.25;

local RIVER_PERCENTAGE_B3_R3 = 0.40;
local RIVER_PERCENTAGE_B3_R5 = 0.25;

local RIVER_PERCENTAGE_B4_R3 = 0.35;
local RIVER_PERCENTAGE_B4_R5 = 0.20;

local RIVER_PERCENTAGE_B5_R3 = 0.25;
local RIVER_PERCENTAGE_B5_R5 = 0.15;


--- Used to evaluate the common part of the spawns

-- Max Percentage of usable land that is actually allowed for a spawn 
local FLOODS_PERCENTAGE_R3 = 0.30;
local FLOODS_PERCENTAGE_R5 = 0.20;

local MOUNTAINS_PERCENTAGE_R3 = 0.50;
local MOUNTAINS_PERCENTAGE_R5 = 0.50;

local TUNDRA_PERCENTAGE_R3 = 0.03;
local TUNDRA_PERCENTAGE_R5 = 0.10;

local DESERT_PERCENTAGE_R3 = 0.03;
local DESERT_PERCENTAGE_R5 = 0.10;

function biasFeatureScore(bias, percentageR3, percentageR5)

   local score = 0;
   
   if bias == 1 then
      -- bias respected
      if percentageR3 >= FEATURE_PERCENTAGE_B1_R3 and percentageR5 >= FEATURE_PERCENTAGE_B1_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 >= FEATURE_PERCENTAGE_B1_R3 - 0.03 and percentageR5 >= FEATURE_PERCENTAGE_B1_R5 - 0.03 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
      
   elseif bias == 2 then 
      -- bias respected
      if percentageR3 >= FEATURE_PERCENTAGE_B2_R3 and percentageR5 >= FEATURE_PERCENTAGE_B2_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 >= FEATURE_PERCENTAGE_B2_R3 - 0.03 and percentageR5 >= FEATURE_PERCENTAGE_B2_R5 - 0.03 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 1000;
      end
   
   elseif bias == 3 then 
      -- bias respected
      if percentageR3 >= FEATURE_PERCENTAGE_B3_R3 and percentageR5 >= FEATURE_PERCENTAGE_B3_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 >= FEATURE_PERCENTAGE_B3_R3 - 0.03 and percentageR5 >= FEATURE_PERCENTAGE_B3_R5 - 0.03 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
   
   elseif bias == 4 then 
      -- bias respected
      if percentageR3 >= FEATURE_PERCENTAGE_B4_R3 and percentageR5 >= FEATURE_PERCENTAGE_B4_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 >= FEATURE_PERCENTAGE_B4_R3 - 0.02 and percentageR5 >= FEATURE_PERCENTAGE_B4_R5 - 0.02 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 1000;
      end
   
   elseif bias == 5 then 
      -- bias respected
      if percentageR3 >= FEATURE_PERCENTAGE_B5_R3 and percentageR5 >= FEATURE_PERCENTAGE_B5_R5 then
         score = score + 200;
      -- bias not respected
      else
         score = score - 400;
      end
   else
      print("Warning, tried to evaluate a bugged Feature bias !");
   end
   
   return score;
   
end

function negativeBiasFeatureScore(negativeBias, percentageR3, percentageR5)

   local score = 0;
   
   if negativeBias == 1 then
      -- negativeBias respected
      if percentageR3 <= NEGATIVE_FEATURE_PERCENTAGE_B1_R3 and percentageR5 <= NEGATIVE_FEATURE_PERCENTAGE_B1_R5 then
         score = score + 1000;
      -- negativeBias somewhat respected
      elseif percentageR3 <= NEGATIVE_FEATURE_PERCENTAGE_B1_R3 - 0.03 and percentageR5 <= NEGATIVE_FEATURE_PERCENTAGE_B1_R5 - 0.03 then
         score = score + 100;
      -- negativeBias not respected
      else
         score = score - 2000;
      end
      
   elseif negativeBias == 2 then 
      -- negativeBias respected
      if percentageR3 <= NEGATIVE_FEATURE_PERCENTAGE_B2_R3 and percentageR5 <= NEGATIVE_FEATURE_PERCENTAGE_B2_R5 then
         score = score + 500;
      -- negativeBias somewhat respected
      elseif percentageR3 <= NEGATIVE_FEATURE_PERCENTAGE_B2_R3 - 0.03 and percentageR5 <= NEGATIVE_FEATURE_PERCENTAGE_B2_R5 - 0.03 then
         score = score + 100;
      -- negativeBias not respected
      else
         score = score - 1000;
      end
   
   elseif negativeBias == 3 then 
      -- negativeBias respected
      if percentageR3 <= NEGATIVE_FEATURE_PERCENTAGE_B3_R3 and percentageR5 <= NEGATIVE_FEATURE_PERCENTAGE_B3_R5 then
         score = score + 1000;
      -- negativeBias somewhat respected
      elseif percentageR3 <= NEGATIVE_FEATURE_PERCENTAGE_B3_R3 - 0.03 and percentageR5 <= NEGATIVE_FEATURE_PERCENTAGE_B3_R5 - 0.03 then
         score = score + 100;
      -- negativeBias not respected
      else
         score = score - 2000;
      end
   
   elseif negativeBias == 4 then 
      -- negativeBias respected
      if percentageR3 <= NEGATIVE_FEATURE_PERCENTAGE_B4_R3 and percentageR5 <= NEGATIVE_FEATURE_PERCENTAGE_B4_R5 then
         score = score + 500;
      -- negativeBias somewhat respected
      elseif percentageR3 <= NEGATIVE_FEATURE_PERCENTAGE_B4_R3 - 0.02 and percentageR5 <= NEGATIVE_FEATURE_PERCENTAGE_B4_R5 - 0.02 then
         score = score + 50;
      -- negativeBias not respected
      else
         score = score - 1000;
      end
   
   elseif negativeBias == 5 then 
      -- negativeBias respected
      if percentageR3 <= NEGATIVE_FEATURE_PERCENTAGE_B5_R3 and percentageR5 <= NEGATIVE_FEATURE_PERCENTAGE_B5_R5 then
         score = score + 200;
      -- negativeBias not respected
      else
         score = score - 400;
      end
      
   else
      print("Warning, tried to evaluate a bugged Negative Feature bias !");
   end
   
   return score;
   
end


function biasResourceScore(bias, percentageR3, percentageR5)

   local score = 0;
   
   if bias == 1 then
      -- bias respected
      if percentageR3 >= RESOURCE_PERCENTAGE_B1_R3 and percentageR5 >= RESOURCE_PERCENTAGE_B1_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 >= RESOURCE_PERCENTAGE_B1_R3 - 0.03 and percentageR5 >= RESOURCE_PERCENTAGE_B1_R5 - 0.03 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
      
   elseif bias == 2 then 
      -- bias respected
      if percentageR3 >= RESOURCE_PERCENTAGE_B2_R3 and percentageR5 >= RESOURCE_PERCENTAGE_B2_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 >= RESOURCE_PERCENTAGE_B2_R3 - 0.03 and percentageR5 >= RESOURCE_PERCENTAGE_B2_R5 - 0.03 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 1000;
      end
   
   elseif bias == 3 then 
      -- bias respected
      if percentageR3 >= RESOURCE_PERCENTAGE_B3_R3 and percentageR5 >= RESOURCE_PERCENTAGE_B3_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 >= RESOURCE_PERCENTAGE_B3_R3 - 0.03 and percentageR5 >= RESOURCE_PERCENTAGE_B3_R5 - 0.03 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
   
   elseif bias == 4 then 
      -- bias respected
      if percentageR3 >= RESOURCE_PERCENTAGE_B4_R3 and percentageR5 >= RESOURCE_PERCENTAGE_B4_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 >= RESOURCE_PERCENTAGE_B4_R3 - 0.02 and percentageR5 >= RESOURCE_PERCENTAGE_B4_R5 - 0.02 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 1000;
      end
   
   elseif bias == 5 then 
      -- bias respected
      if percentageR3 >= RESOURCE_PERCENTAGE_B5_R3 and percentageR5 >= RESOURCE_PERCENTAGE_B5_R5 then
         score = score + 200;
      -- bias not respected
      else
         score = score - 400;
      end
      
   else
      print("Warning, tried to evaluate a bugged Resource bias !");
   end
   
   return score;
   
end

function negativeBiasResourceScore(negativeBias, percentageR3, percentageR5)

   local score = 0;
   
   if negativeBias == 1 then
      -- negativeBias respected
      if percentageR3 <= NEGATIVE_RESOURCE_PERCENTAGE_B1_R3 and percentageR5 <= NEGATIVE_RESOURCE_PERCENTAGE_B1_R5 then
         score = score + 1000;
      -- negativeBias somewhat respected
      elseif percentageR3 <= NEGATIVE_RESOURCE_PERCENTAGE_B1_R3 - 0.03 and percentageR5 <= NEGATIVE_RESOURCE_PERCENTAGE_B1_R5 - 0.03 then
         score = score + 100;
      -- negativeBias not respected
      else
         score = score - 2000;
      end
      
   elseif negativeBias == 2 then 
      -- negativeBias respected
      if percentageR3 <= NEGATIVE_RESOURCE_PERCENTAGE_B2_R3 and percentageR5 <= NEGATIVE_RESOURCE_PERCENTAGE_B2_R5 then
         score = score + 500;
      -- negativeBias somewhat respected
      elseif percentageR3 <= NEGATIVE_RESOURCE_PERCENTAGE_B2_R3 - 0.03 and percentageR5 <= NEGATIVE_RESOURCE_PERCENTAGE_B2_R5 - 0.03 then
         score = score + 100;
      -- negativeBias not respected
      else
         score = score - 1000;
      end
   
   elseif negativeBias == 3 then 
      -- negativeBias respected
      if percentageR3 <= NEGATIVE_RESOURCE_PERCENTAGE_B3_R3 and percentageR5 <= NEGATIVE_RESOURCE_PERCENTAGE_B3_R5 then
         score = score + 1000;
      -- negativeBias somewhat respected
      elseif percentageR3 <= NEGATIVE_RESOURCE_PERCENTAGE_B3_R3 - 0.03 and percentageR5 <= NEGATIVE_RESOURCE_PERCENTAGE_B3_R5 - 0.03 then
         score = score + 100;
      -- negativeBias not respected
      else
         score = score - 2000;
      end
   
   elseif negativeBias == 4 then 
      -- negativeBias respected
      if percentageR3 <= NEGATIVE_RESOURCE_PERCENTAGE_B4_R3 and percentageR5 <= NEGATIVE_RESOURCE_PERCENTAGE_B4_R5 then
         score = score + 500;
      -- negativeBias somewhat respected
      elseif percentageR3 <= NEGATIVE_RESOURCE_PERCENTAGE_B4_R3 - 0.02 and percentageR5 <= NEGATIVE_RESOURCE_PERCENTAGE_B4_R5 - 0.02 then
         score = score + 50;
      -- negativeBias not respected
      else
         score = score - 1000;
      end
   
   elseif negativeBias == 5 then 
      -- negativeBias respected
      if percentageR3 <= NEGATIVE_RESOURCE_PERCENTAGE_B5_R3 and percentageR5 <= NEGATIVE_RESOURCE_PERCENTAGE_B5_R5 then
         score = score + 200;
      -- negativeBias not respected
      else
         score = score - 400;
      end
      
   else
      print("Warning, tried to evaluate a Nagative Resource bias !");
   end
   
   return score;
   
end


function biasTerrainScore(bias, percentageR3, percentageR5)

   local score = 0;

   if bias == 1 then
      -- bias respected
      if percentageR3 >= TERRAIN_PERCENTAGE_B1_R3 and percentageR5 >= TERRAIN_PERCENTAGE_B1_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 >= TERRAIN_PERCENTAGE_B1_R3 -0.1 and percentageR5 >= TERRAIN_PERCENTAGE_B1_R5 - 0.1 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
      
   elseif bias == 2 then 
      -- bias respected
      if percentageR3 >= TERRAIN_PERCENTAGE_B2_R3 and percentageR5 >= TERRAIN_PERCENTAGE_B2_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 >= TERRAIN_PERCENTAGE_B2_R3 -0.1 and percentageR5 >= TERRAIN_PERCENTAGE_B2_R5 - 0.1 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 1000;
      end
      
   elseif bias == 3 then 
      -- bias respected
      if percentageR3 >= TERRAIN_PERCENTAGE_B3_R3 and percentageR5 >= TERRAIN_PERCENTAGE_B3_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 >= TERRAIN_PERCENTAGE_B3_R3 -0.1 and percentageR5 >= TERRAIN_PERCENTAGE_B3_R5 - 0.1 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
      
   elseif bias == 4 then 
      -- bias respected
      if percentageR3 >= TERRAIN_PERCENTAGE_B4_R3 and percentageR5 >= TERRAIN_PERCENTAGE_B4_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 >= TERRAIN_PERCENTAGE_B4_R3 -0.1 and percentageR5 >= TERRAIN_PERCENTAGE_B4_R5 - 0.1 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 1000;
      end
      
   elseif bias == 5 then 
      -- bias respected
      if percentageR3 >= TERRAIN_PERCENTAGE_B5_R3 and percentageR5 >= TERRAIN_PERCENTAGE_B5_R5 then
         score = score + 200;
      -- bias somewhat respected
      elseif percentageR3 >= TERRAIN_PERCENTAGE_B5_R3 -0.1 and percentageR5 >= TERRAIN_PERCENTAGE_B5_R5 - 0.1 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 400;
      end
      
   elseif bias == -1 then 
      -- bias respected
      if percentageR3 <= NEGATIVE_TERRAIN_PERCENTAGE_B1_R3 and percentageR5 <= NEGATIVE_TERRAIN_PERCENTAGE_B1_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 <= NEGATIVE_TERRAIN_PERCENTAGE_B1_R3 + 0.05 and percentageR5 <= NEGATIVE_TERRAIN_PERCENTAGE_B1_R5 - 0.05 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
      
   elseif bias == -2 then 
      -- bias respected
      if percentageR3 <= NEGATIVE_TERRAIN_PERCENTAGE_B2_R3 and percentageR5 <= NEGATIVE_TERRAIN_PERCENTAGE_B2_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 <= NEGATIVE_TERRAIN_PERCENTAGE_B2_R3 + 0.05 and percentageR5 <= NEGATIVE_TERRAIN_PERCENTAGE_B2_R5 - 0.05 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 1000;
      end
      
   elseif bias == -3 then 
      -- bias respected
      if percentageR3 <= NEGATIVE_TERRAIN_PERCENTAGE_B3_R3 and percentageR5 <= NEGATIVE_TERRAIN_PERCENTAGE_B3_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 <= NEGATIVE_TERRAIN_PERCENTAGE_B3_R3 + 0.05 and percentageR5 <= NEGATIVE_TERRAIN_PERCENTAGE_B3_R5 - 0.05 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
   
   elseif bias == -4 then 
      -- bias respected
      if percentageR3 <= NEGATIVE_TERRAIN_PERCENTAGE_B4_R3 and percentageR5 <= NEGATIVE_TERRAIN_PERCENTAGE_B4_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 <= NEGATIVE_TERRAIN_PERCENTAGE_B4_R3 + 0.05 and percentageR5 <= NEGATIVE_TERRAIN_PERCENTAGE_B4_R5 - 0.05 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 1000;
      end
   
   elseif bias == -5 then 
      -- bias respected
      if percentageR3 <= NEGATIVE_TERRAIN_PERCENTAGE_B5_R3 and percentageR5 <= NEGATIVE_TERRAIN_PERCENTAGE_B5_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 <= NEGATIVE_TERRAIN_PERCENTAGE_B5_R3 + 0.05 and percentageR5 <= NEGATIVE_TERRAIN_PERCENTAGE_B5_R5 - 0.05 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 400;
      end
   else
      print("Warning, tried to evaluate a Nagative Terrain bias !");
   
   end
   
   return score

end


function biasMountainScore(bias, percentageR3, percentageR5)

   local score = 0;

   if bias == 1 then
      -- bias respected
      if percentageR3 >= MOUNTAIN_PERCENTAGE_B1_R3 and percentageR5 >= MOUNTAIN_PERCENTAGE_B1_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 >= MOUNTAIN_PERCENTAGE_B1_R3 -0.1 and percentageR5 >= MOUNTAIN_PERCENTAGE_B1_R5 - 0.1 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
      
   elseif bias == 2 then 
      -- bias respected
      if percentageR3 >= MOUNTAIN_PERCENTAGE_B2_R3 and percentageR5 >= MOUNTAIN_PERCENTAGE_B2_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 >= MOUNTAIN_PERCENTAGE_B2_R3 -0.1 and percentageR5 >= MOUNTAIN_PERCENTAGE_B2_R5 - 0.1 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 1000;
      end
      
   elseif bias == 3 then 
      -- bias respected
      if percentageR3 >= MOUNTAIN_PERCENTAGE_B3_R3 and percentageR5 >= MOUNTAIN_PERCENTAGE_B3_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 >= MOUNTAIN_PERCENTAGE_B3_R3 -0.1 and percentageR5 >= MOUNTAIN_PERCENTAGE_B3_R5 - 0.1 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
      
   elseif bias == 4 then 
      -- bias respected
      if percentageR3 >= MOUNTAIN_PERCENTAGE_B4_R3 and percentageR5 >= MOUNTAIN_PERCENTAGE_B4_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 >= MOUNTAIN_PERCENTAGE_B4_R3 -0.1 and percentageR5 >= MOUNTAIN_PERCENTAGE_B4_R5 - 0.1 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 1000;
      end
      
   elseif bias == 5 then 
      -- bias respected
      if percentageR3 >= MOUNTAIN_PERCENTAGE_B5_R3 and percentageR5 >= MOUNTAIN_PERCENTAGE_B5_R5 then
         score = score + 200;
      -- bias somewhat respected
      elseif percentageR3 >= MOUNTAIN_PERCENTAGE_B5_R3 -0.1 and percentageR5 >= MOUNTAIN_PERCENTAGE_B5_R5 - 0.1 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 400;
      end
      
   elseif bias == -1 then 
      -- bias respected
      if percentageR3 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B1_R3 and percentageR5 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B1_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B1_R3 + 0.05 and percentageR5 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B1_R5 - 0.05 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
      
   elseif bias == -2 then 
      -- bias respected
      if percentageR3 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B2_R3 and percentageR5 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B2_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B2_R3 + 0.05 and percentageR5 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B2_R5 - 0.05 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 1000;
      end
      
   elseif bias == -3 then 
      -- bias respected
      if percentageR3 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B3_R3 and percentageR5 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B3_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B3_R3 + 0.05 and percentageR5 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B3_R5 - 0.05 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
   
   elseif bias == -4 then 
      -- bias respected
      if percentageR3 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B4_R3 and percentageR5 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B4_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B4_R3 + 0.05 and percentageR5 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B4_R5 - 0.05 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 1000;
      end
   
   elseif bias == -5 then 
      -- bias respected
      if percentageR3 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B5_R3 and percentageR5 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B5_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B5_R3 + 0.05 and percentageR5 <= NEGATIVE_MOUNTAIN_PERCENTAGE_B5_R5 - 0.05 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 400;
      end
   else
      print("Warning, tried to evaluate a bugged Mountain bias !");
   
   end
   
   
   
   return score

end

function biasRiverScore(bias, percentageR3, percentageR5)

   local score = 0;
   
   if bias == 1 then
      -- bias respected
      if percentageR3 >= RIVER_PERCENTAGE_B1_R3 and percentageR5 >= RIVER_PERCENTAGE_B1_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 >= RIVER_PERCENTAGE_B1_R3 - 0.03 and percentageR5 >= RIVER_PERCENTAGE_B1_R5 - 0.03 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
      
   elseif bias == 2 then 
      -- bias respected
      if percentageR3 >= RIVER_PERCENTAGE_B2_R3 and percentageR5 >= RIVER_PERCENTAGE_B2_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 >= RIVER_PERCENTAGE_B2_R3 - 0.03 and percentageR5 >= RIVER_PERCENTAGE_B2_R5 - 0.03 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 1000;
      end
   
   elseif bias == 3 then 
      -- bias respected
      if percentageR3 >= RIVER_PERCENTAGE_B3_R3 and percentageR5 >= RIVER_PERCENTAGE_B3_R5 then
         score = score + 1000;
      -- bias somewhat respected
      elseif percentageR3 >= RIVER_PERCENTAGE_B3_R3 - 0.03 and percentageR5 >= RIVER_PERCENTAGE_B3_R5 - 0.03 then
         score = score + 100;
      -- bias not respected
      else
         score = score - 2000;
      end
   
   elseif bias == 4 then 
      -- bias respected
      if percentageR3 >= RIVER_PERCENTAGE_B4_R3 and percentageR5 >= RIVER_PERCENTAGE_B4_R5 then
         score = score + 500;
      -- bias somewhat respected
      elseif percentageR3 >= RIVER_PERCENTAGE_B4_R3 - 0.02 and percentageR5 >= RIVER_PERCENTAGE_B4_R5 - 0.02 then
         score = score + 50;
      -- bias not respected
      else
         score = score - 1000;
      end
   
   elseif bias == 5 then 
      -- bias respected
      if percentageR3 >= RIVER_PERCENTAGE_B5_R3 and percentageR5 >= RIVER_PERCENTAGE_B5_R5 then
         score = score + 200;
      -- bias not respected
      else
         score = score - 400;
      end
   else
      print("Warning, tried to evaluate a bugged River bias !");
   
   end
   
   return score;
   
end


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


function drawMapBoolean(map, xSize, ySize)

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
         
         if (map[iIndex][jIndex]) then
            line = line .. "1" .. "|";
         else
            line = line .. "0" .. "|";
         end
         
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
   
   --print ("start pos", posIndex);
   --print ("start neg", negIndex);
   
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
      
      --print ("posinde", tmpPosIndex);
      --print ("neginde", tmpNegIndex);
      
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
      
      if (i ~= 0) then -- because otherwise, we have the tile two times
      
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
   
   
   -------------------------
   ----- PHASE 1 -----------
   ----- Now collecting all kind of stats about the map and the tiles
   
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
      mapSea[i] = {}; -- water that is not lake
      mapLake[i] = {}; -- water that is lake
      mapRiver[i] = {};
      mapFreshWater[i] = {};
      mapContinent[i] = {};
      mapIsContinentSplit[i] = {};
      mapSpawnable[i] = {};
      mapWonder[i] = {};
      
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
         mapSea[i][j] = false;
         mapFreshWater[i][j] = false;
         mapContinent[i][j] = 9;
         mapIsContinentSplit[i][j] = false;
         
         mapFoodYield[i][j] = 0;
         mapProdYield[i][j] = 0;
         mapGoldYield[i][j] = 0;
         mapScienceYield[i][j] = 0;
         mapCultureYield[i][j] = 0;
         mapFaithYield[i][j] = 0;
         mapWonder[i][j] = false;
         
         isPlayerProximityBlocked[i][j] = false;
         mapSpawnable[i][j] = true;
      end
   end
   
   for i = 1, 17 do
      terrainCount[i] = 0;
   end
   
   for i = 1, 100 do
      resourceCount[i] = 0;
      featureCount[i] = 0;
      majorBiases[i] = {};
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
            local isCoastal = false;
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
            
            
            --- strategics are not visible at start, but the game would count their stat anyway
            if (resource == 40 or resource == 43) then
               science = science - 1;
            elseif resource == 41 then
               prod = prod - 1;
            elseif (resource == 42 or resource == 44) then
               prod = prod - 1;
               food = food - 1;
            elseif resource == 45 then
               prod = prod - 3;
            elseif resource == 46 then
               prod = prod - 2; 
            end
               
            
            -- Mapping 2-2
            if (terrain >= 15) then -- water
               mapTwoTwo[iIndex][jIndex] = 0;
            
            elseif (food < 2 or prod < 2) then -- not 2-2
               mapTwoTwo[iIndex][jIndex] = 1;
               
            elseif (food == 2 and prod == 2) then -- 2-2
               mapTwoTwo[iIndex][jIndex] = 2;
               twoTwoCount = twoTwoCount + 1;
            
            else -- better than 2-2
               mapTwoTwo[iIndex][jIndex] = 3;
               twoTwoCount = twoTwoCount + 1;
            end
            --- end mapping 2-2 --
            
            if(plot:IsRiver()) then
               mapRiver[iIndex][jIndex] = true;
            end
            
            if(plot:IsFreshWater()) then
               mapFreshWater[iIndex][jIndex] = true;
            end
            
            if(plot:IsNaturalWonder()) then
               mapWonder[iIndex][jIndex] = true;
            end
            
            if (terrain >= 0) then
               terrainCount[terrain + 1] = terrainCount[terrain + 1] + 1;
            end
            
            if (terrain >= 15) then
               if (plot:IsLake()) then
                  mapLake[iIndex][jIndex] = true;
                  lakeCount = lakeCount + 1;
               else
                  mapSea[iIndex][jIndex] = true;
               end
            end
            
            if (terrain < 15) then
               mapContinent[iIndex][jIndex] = plot:GetContinentType();
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
            
            isCoastal = isCoastalTile(i, j, mapXSize, mapYSize, mapIsRoundWestEast);
            
            if (isCoastal) then
               coastalCount = coastalCount + 1;
               mapCoastal[iIndex][jIndex] = true;
            end
            
            -- Checking Continent Split --
         local continentID = mapContinent[iIndex][jIndex];
         
         ___Debug("-----------------------");
         ___Debug("Tile Test", i, j);
         ___Debug("-----------------------");
         
         for k = 1, 3 do
            local list = getRing(i, j, k, mapXSize, mapYSize, mapIsRoundWestEast);
            for _, element in ipairs(list) do
               local x = element[1];
               local y = element[2];
               ___Debug("x:", x, "y", y);
               if (mapTerrainCode[x + 1][y + 1] < 15 and continentID ~= mapContinent[x + 1][y + 1]) then
                  mapIsContinentSplit[iIndex][jIndex] = true;
                  ___Debug("---- Split Continent", x, "Y:", y);
                  break;
               end
            end
            if mapIsContinentSplit[iIndex][jIndex] then
               break;
            end
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
   
   
   -- test rings
   --[[
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
      local list = getRing(0, 0, i, mapXSize, mapXSize, mapIsRoundWestEast)
      
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
   --]]
   --drawMap(ringTest, mapXSize, mapYSize);
   
   
   -- continent map
   
   --drawMap(mapContinent, mapXSize, mapYSize);
   
   ----------------------
   -----PHASE 2----------
   ---- Now, with all the data, we start analysing the map-----
   ----------------------
   
   ----
   --Now Deciding which tiles are going to be "settle forbidden"
   --
   -- Forbidden:
   --    - Spawn on a resource (any resource)
   --    - Spawn Ring 1 of 1-3 (1-4) gypsum/Ivory/deer with fresh water or coastal (would make capital 2-3)
   --    - Spawn Ring 2 of a Spice (any spice, any land)
   --    - Spawn Ring 2 of 4-0 sugar/honey/citrus, flat grassland, with fresh water or coastal (would make cap 4-1) 
   --    - Spawn on Oasis (unsettleable) or mountain or water (except Maori of course)
   --    - Spawn Ring 3 of a natural wonder (any wonder)
   
   
   
   for i = 0, mapXSize - 1 do
      local iIndex = i + 1;
      
      for j = 0, mapYSize - 1 do 
         local jIndex = j + 1 ;
         
         -- Checking if too many mountains/water around, for a non coastal tile, will ban
         if (mapCoastal[iIndex][jIndex] == false and mapTerrainCode[iIndex][jIndex] < 15) then
            local list = getRing(i, j, 1, mapXSize, mapYSize, mapIsRoundWestEast);
            local unusableTiles = 0;
            for _, element in ipairs(list) do
               local x = element[1];
               local y = element[2];
               if (isMountainCode(mapTerrainCode[x + 1][j + 1]) or mapTerrainCode[x + 1][j + 1] >= 15) then
                  unusableTiles = unusableTiles + 1;
               end
            end
            
            if (unusableTiles >= 4) then
               ___Debug("not enough workable tiles around X:", i, "Y:", j);
               mapSpawnable[iIndex][jIndex] = false;
            end
         end
         ------ Too close to map border ! ----------
         ------ It is forbidden to settle less than 3 tiles away from the map border ----
         
         if (j <= 1 or ((mapYSize - j) <= 1)) then
            mapSpawnable[iIndex][jIndex] = false;
            
            ___Debug("---- Banning border of the map X:", i, "Y:", j);
         end
         
         if (mapIsRoundWestEast == false) then
            if (i <= 1 or ((mapXSize - i) <= 1)) then
            mapSpawnable[iIndex][jIndex] = false;
            
            ___Debug("---- Banning border of the map X:", i, "Y:", j);
            end
         end
         
         ------ removing ... resources -----------
         --if isLuxury(mapResourceCode[iIndex][jIndex]) then
         if (mapResourceCode[iIndex][jIndex] >= 0) then
            mapSpawnable[iIndex][jIndex] = false;
            
            ___Debug("---- Banning resource X:", i, "Y:", j);
         end
         
         ------ removing water ----------
         --if isWater(mapTerrainCode[iIndex][jIndex]) then
         --   mapSpawnable[iIndex][jIndex] = false;
         --end
         
         ----- removing mountains ----------
         if isMountainCode(mapTerrainCode[iIndex][jIndex]) then
            mapSpawnable[iIndex][jIndex] = false;
         end
         
         ----- removing oasis ------------
         if (mapFeatureCode[iIndex][jIndex] == 4) then
            mapSpawnable[iIndex][jIndex] = false;
         end
        
         ---- now starting more complex tasks ----
         ----- banning spawns too close from a certain type of tile ------
        
         ------ gypsum/ivory/deer  needs :----
         ----- Fresh water
         ----- plain hills
         if ((mapResourceCode[iIndex][jIndex] == 17 or mapResourceCode[iIndex][jIndex] == 4 or mapResourceCode[iIndex][jIndex] == 19) and 
               mapFreshWater[iIndex][jIndex] == true and
               mapTerrainCode[iIndex][jIndex] == 4) then
            ___Debug("Found forbidden Gypsum/Ivory/ on X:", i, "Y:", j);
            local list = getRing(i, j, 1, mapXSize, mapXSize, mapIsRoundWestEast);
            for _, element in ipairs(list) do
               local x = element[1];
               local y = element[2];
               mapSpawnable[x + 1][y + 1] = false;
               ___Debug("---- Banning X:", x, "Y:", y);
            end
         end
         
         ----- Spice: no settle ring 2 near a spice -----
         if (mapResourceCode[iIndex][jIndex] == 27) then
            ___Debug("Found Spice on X:", i, "Y:", j);
            local list = getRing(i, j, 1, mapXSize, mapXSize, mapIsRoundWestEast);
            for _, element in ipairs(list) do
               local x = element[1];
               local y = element[2];
               mapSpawnable[x + 1][y + 1] = false;
               ___Debug("---- Banning X:", x, "Y:", y);
            end
            
            list = getRing(i, j, 2, mapXSize, mapXSize, mapIsRoundWestEast);
            for _, element in ipairs(list) do
               local x = element[1];
               local y = element[2];
               mapSpawnable[x + 1][y + 1] = false;
               ___Debug("---- Banning X:", x, "Y:", y);
            end
         end
         
         -- sugar/honey/citrus on fresf water/coastal and on flat grassland
         if ((mapResourceCode[iIndex][jIndex] == 53 or mapResourceCode[iIndex][jIndex] == 10 or mapResourceCode[iIndex][jIndex] == 28) and
               (mapFreshWater[iIndex][jIndex] or mapCoastal[iIndex][jIndex]) and
               (mapTerrainCode[iIndex][jIndex] == 0)) then
            ___Debug("Found a forbidden sugar/honey/citrus on X:", i, "Y:", j);
            local list = getRing(i, j, 1, mapXSize, mapXSize, mapIsRoundWestEast);
            for _, element in ipairs(list) do
               local x = element[1];
               local y = element[2];
               mapSpawnable[x + 1][y + 1] = false;
               ___Debug("---- Banning X:", x, "Y:", y);
            end
            
            list = getRing(i, j, 2, mapXSize, mapXSize, mapIsRoundWestEast);
            for _, element in ipairs(list) do
               local x = element[1];
               local y = element[2];
               mapSpawnable[x + 1][y + 1] = false;
               ___Debug("---- Banning X:", x, "Y:", y);
            end
         end
         
         -- wonder neighbourhood ---
         if mapWonder[iIndex][jIndex] then
            ___Debug("Found a wonder on X:", i, "Y:", j);
            mapSpawnable[iIndex][jIndex] = false; -- banning ring 0
            
            
            local list = getRing(i, j, 1, mapXSize, mapXSize, mapIsRoundWestEast);
            for _, element in ipairs(list) do
               local x = element[1];
               local y = element[2];
               mapSpawnable[x + 1][y + 1] = false;
               ___Debug("---- Banning X:", x, "Y:", y);
            end
            
            list = getRing(i, j, 2, mapXSize, mapXSize, mapIsRoundWestEast);
            for _, element in ipairs(list) do
               local x = element[1];
               local y = element[2];
               mapSpawnable[x + 1][y + 1] = false;
               ___Debug("---- Banning X:", x, "Y:", y);
            end
            
            list = getRing(i, j, 3, mapXSize, mapXSize, mapIsRoundWestEast);
            for _, element in ipairs(list) do
               local x = element[1];
               local y = element[2];
               mapSpawnable[x + 1][y + 1] = false;
               ___Debug("---- Banning X:", x, "Y:", y);
            end
         end
      end
   end
   
   local totalSpawnable = 0;
   
   for i = 1, mapXSize do      
      for j = 1, mapYSize do 
         if (mapSpawnable[i][j]) then
            totalSpawnable = totalSpawnable + 1;
         end
      end
   end
   
   
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
   print("----------Of which: twoTwos", twoTwoCount);
   print("----------Of which: grasland", terrainCount[0 + 1] + terrainCount[1 + 1]);
   print("----------Of which: plain", terrainCount[3 + 1] + terrainCount[4 + 1]);
   print("----------Of which: desert", terrainCount[6 + 1] + terrainCount[7 + 1]);
   print("----------Of which: tundra", terrainCount[9 + 1] + terrainCount[10 + 1]);
   print("----------Of which: snow", terrainCount[12 + 1] + terrainCount[13 + 1]);
   print("----------Floodplains:", floodPlainsCount);
   print("----------Spawnable (after removing restricted tiles)", totalSpawnable);
   
   
   ___Debug("---------------");
   ___Debug("--- Two-Two Map ---");
   drawMap(mapTwoTwo, mapXSize, mapYSize);
   
   ___Debug("---------------");
   ___Debug("---------------");
   ___Debug("--- Spawnablemap ---");
   
   
   drawMapBoolean(mapSpawnable, mapXSize, mapYSize);
   ___Debug("---------------");
   ___Debug("---------------");
   ___Debug("---------------");
   ___Debug("---------------");
   

   ----------------------
   -----PHASE 3----------
   ---- Now, we will rate every settleable tile-----
   ----------------------
   
   print("----------- BBS BETA -------------");
   print("----------- Starting tiles scoring -------------");
   print(os.date("%c"));
   
   -- See if there are any civs starting out in the water
   local tempMajorList = {};
   local specMajorList = {};
   local tempMinorList = {};
   
   local majorAll = {} -- will contain all infos, including biases !
   
   local majorBiases = {};
   local minorBiases = {};
   
   local majorBestBias = {};
   local minorBestBias = {};
   
   for i = 1, 20 do
      majorBestBias[i] = 10;
      minorBestBias[i] = 10;
   end
   
   local specCount = 0;
   local majorCount = 0;
   local minorCount = 0;
   
   local majorList = {};
   local minorList = {};
   local hasMaori = false;
   
   local biasCount = 0;
   
   
   --for i = 1, 40 do
     -- majorBias[i] = {};
   --end
      
   
   tempMajorList = PlayerManager.GetAliveMajorIDs();
	tempMinorList = PlayerManager.GetAliveMinorIDs();
   
   print("List of civs:");
   print("--------------");
   print("Majors (players):");
   
   for i = 1, PlayerManager.GetAliveMajorsCount() do
      local leaderType = PlayerConfigurations[tempMajorList[i]]:GetLeaderTypeName();
      
      local biasTerrain = {};
      local biasFeature = {};
      local biasResource = {};
      
      for k = 1, 100 do
         biasTerrain[k] = 0;
         biasFeature[k] = 0;
         biasResource[k] = 0;
      end
      
      local isNorthKing = false;
      local continentSplit = false;
      local isHydrophobic = false;
      local isSalty = false; -- not used here anyway
      local isMountainLover = false;
      local riverCiv = 0; -- will put tier as value if civ is river
      
      if ( PlayerConfigurations[tempMajorList[i]]:GetLeaderTypeName() == "LEADER_SPECTATOR" or PlayerConfigurations[tempMajorList[i]]:GetHandicapTypeID() == 2021024770) then
         specMajorList[i] = tempMajorList[i];
         specCount = specCount + 1;
         ___Debug ("Found a Spectator");
      else
         majorList[i] = tempMajorList[i];
         
         local civName = PlayerConfigurations[tempMajorList[i]]:GetCivilizationTypeName();
         if (civName == "CIVILIZATION_MAORI") then
            hasMaori = true;
         end
         local tempBias = BBS_AssignStartingPlots:__FindBias(civName);
         
         --print(tempBias);
         --print(tempBias[1].Type);
         
         local biasCount = 0;
         local biasScore = 0; -- will be applied for players with no bias
         
         if tempBias ~= nil then
            for _, element in ipairs(tempBias) do
               local tempScore = 0;
               biasCount = biasCount + 1;
               
               -- computing bias score, will be used to rank civs (placement order)
               if (element.Tier == 1) then
                  tempScore = 5000;
                  if (element.Type == "TERRAINS" and (element.Value == 6 or element.Value == 7)) then --desesrt bias -> prio
                     tempScore = 5800;
                  elseif (element.Type == "TERRAINS" and (element.Value == 12 or element.Value == 13)) then --tundra bias -> prio too !
                     tempScore = 5500;
                  end
               elseif (element.Tier == 2) then
                  tempScore = 4000;
               elseif (element.Tier == 3) then
                  tempScore = 3000;
               elseif (element.Tier == 4) then
                  tempScore = 2000;
               elseif (element.Tier == 5) then
                  tempScore = 1000;
               end
               
               if tempScore > biasScore then
                  biasScore = tempScore;
               end
               
               -- recomputing biases so that it's easier to work with them later on.
               -- will still store "raw" biases anyway
               
                  
               if (element.Type == "TERRAINS") then
                  if (element.Value ~= nil and element.Tier ~= nil) then
                     biasTerrain[element.Value + 1] = element.Tier;
                  else
                     print("Warning: wrongly read bias: Type, ID, Tier", element.Type, element.Value, element.Tier, civName);
                  end
               
               elseif (element.Type == "FEATURES") then
                  if (element.Value ~= nil and element.Tier ~= nil) then
                     biasFeature[element.Value + 1] = element.Tier;
                  else
                     print("Warning: wrongly read bias: Type, ID, Tier", element.Type, element.Value, element.Tier, civName);
                  end
               
               elseif (element.Type == "RESOURCES") then
                  if (element.Value ~= nil and element.Tier ~= nil) then
                     biasResource[element.Value + 1] = element.Tier;
                  else
                     print("Warning: wrongly read bias: Type, ID, Tier", element.Type, element.Value, element.Tier, civName);
                  end
                  
               elseif (element.Type == "RIVERS") then
                  if (element.Tier ~= nil) then
                     
                     riverCiv = element.Tier;
                     ___Debug("River bias:", element.Type, element.Value, element.Tier, civName);
                  else
                     print("Warning: wrongly read bias: Type, ID, Tier", element.Type, element.Value, element.Tier, civName);
                  end
               
               -- negative biases, will simply put the value as ... negative !
               elseif (element.Type == "NEGATIVE_TERRAINS") then
                  if (element.Value ~= nil and element.Tier ~= nil) then
                     biasTerrain[element.Value + 1] = 0 - element.Tier;
                  else
                     print("Warning: wrongly read bias: Type, ID, Tier", element.Type, element.Value, element.Tier, civName);
                  end
                  
               elseif (element.Type == "NEGATIVE_FEATURES") then
                  if (element.Value ~= nil and element.Tier ~= nil) then
                     biasFeature[element.Value + 1] = 0 - element.Tier;
                  else
                     print("Warning: wrongly read bias: Type, ID, Tier", element.Type, element.Value, element.Tier, civName);
                  end
                  
               elseif (element.Type == "NEGATIVE_RESOURCES") then
                  if (element.Value ~= nil and element.Tier ~= nil) then
                     biasResource[element.Value + 1] = 0 - element.Tier;
                  else
                     print("Warning: wrongly read bias: Type, ID, Tier", element.Type, element.Value, element.Tier, civName);
                  end
               
               -- custom biases
               elseif (element.Type == "CUSTOM_KING_OF_THE_NORTH") then
                  isNorthKing = true;
               elseif (element.Type == "CUSTOM_HYDROPHOBIC") then
                  isHydrophobic = true;
               elseif (element.Type == "CUSTOM_CONTINENT_SPLIT") then
                  continentSplit = true;
               elseif (element.Type == "CUSTOM_MOUNTAIN_LOVER") then
                  isMountainLover = true;
               elseif (element.Type == "CUSTOM_I_AM_SALTY") then
                  isSalty = true;
                  
               end

               
            end

            
         end
         
         --- Recomputing the resource biases ---
         --- Idea is to sort them by bias, so that they can be looked up together if same level ---
         
         -- 2D array, x being the bias (1-5) and Y being a list of resources matching that bias
         local resourcesBiasList = {};
         -- counter for each 
         local resourcesBiasListCount = {};
         
         local featuresBiasList = {};
         local featuresBiasListCount = {};
         
         -- Negative version
         local resourcesNegativeBiasList = {};
         local resourcesNegativeBiasListCount = {};
         
         local featuresNegativeBiasList = {};
         local featuresNegativeBiasListCount = {};
         
         for k = 1, 5 do
            resourcesBiasList[k] = {};
            resourcesBiasListCount[k] = 0;
            
            featuresBiasList[k] = {};
            featuresBiasListCount[k] = 0;
            
            resourcesNegativeBiasList[k] = {};
            resourcesNegativeBiasListCount[k] = 0;
            
            featuresNegativeBiasList[k] = {};
            featuresNegativeBiasListCount[k] = 0;
         end
         
         for k = 1, 100 do
         
            -- value of the bias (ex: Tier 1)
            local resourceBiasValue = biasResource[k];
            -- resources with a bias (ex: 10 = citrus)
            local resource = k - 1;
            local resourceNegativeBiasValue = 0;
            
            
            if resourceBiasValue > 0 then
               resourcesBiasListCount[resourceBiasValue] = resourcesBiasListCount[resourceBiasValue] + 1;
               resourcesBiasList[resourceBiasValue][resourcesBiasListCount[resourceBiasValue]] = resource;
            else
               resourceNegativeBiasValue = resourceBiasValue;
            end   
            
            
            
            if resourceNegativeBiasValue < 0 then
               ___Debug("added some negative: bias : value", resourceNegativeBiasValue, feature); 
               resourceNegativeBiasValue = math.abs(resourceNegativeBiasValue);
               
               resourcesNegativeBiasListCount[resourceNegativeBiasValue] = resourcesNegativeBiasListCount[resourceNegativeBiasValue] + 1;
               resourcesNegativeBiasList[resourceNegativeBiasValue][resourcesNegativeBiasListCount[resourceNegativeBiasValue]] = resource;
            end
            
            -- value of the bias (ex: Tier 1)
            local featureBiasValue = biasFeature[k];
            -- features with a bias (ex: 10 = citrus)
            local feature = k - 1;
            local featureNegativeBiasValue = 0;
            
            if featureBiasValue > 0 then
               featuresBiasListCount[featureBiasValue] = featuresBiasListCount[featureBiasValue] + 1;
               featuresBiasList[featureBiasValue][featuresBiasListCount[featureBiasValue]] = feature;
            else
               featureNegativeBiasValue = featureBiasValue;
            end
            
            ___Debug("Feature Negative bias", featureNegativeBiasValue, feature);
            
            if featureNegativeBiasValue < 0 then
               ___Debug("added some negative: bias : value", featureNegativeBiasValue, feature); 
               featureNegativeBiasValue = math.abs(featureNegativeBiasValue);
               
               featuresNegativeBiasListCount[featureNegativeBiasValue] = featuresNegativeBiasListCount[featureNegativeBiasValue] + 1;
               featuresNegativeBiasList[featureNegativeBiasValue][featuresNegativeBiasListCount[featureNegativeBiasValue]] = feature;
            end
         
         end
         
         ----------
         
         majorBiases[majorCount] = tempBias;
         majorCount = majorCount + 1;
         
         
         -- Main object --
         -- This will contain all the player information (leader, civ, biases, ...)
         majorAll[majorCount] = {index = i, civName = civName, major = majorList[i], biases = majorBiases[i], biasScore = biasScore, biasCount = biasCount,
                          biasTerrain = biasTerrain, biasFeature = biasFeature, biasResource = biasResource,
                          resourcesBiasList = resourcesBiasList, resourcesBiasListCount = resourcesBiasListCount, featuresBiasList = featuresBiasList, featuresBiasListCount = featuresBiasListCount, 
                          resourcesNegativeBiasList = resourcesNegativeBiasList, resourcesNegativeBiasListCount = resourcesNegativeBiasListCount, featuresNegativeBiasList = featuresNegativeBiasList, featuresNegativeBiasListCount = featuresNegativeBiasListCount, 
                          isNorthKing = isNorthKing, continentSplit = continentSplit, isHydrophobic = isHydrophobic, isSalty = isSalty, isMountainLover = isMountainLover, riverBias = riverCiv};
         print(i, majorAll[majorCount]);
         print(majorAll[majorCount].index, majorAll[majorCount].civName);
         
         
         
      end
      print("---------Player ", i, "Leader:", leaderType);
   end
   
   
   print("--------------");
   print("Majors (players):");
   print("--------------");
   
   for i = 1, PlayerManager.GetAliveMinorsCount() do
      local leaderType = PlayerConfigurations[tempMinorList[i]]:GetLeaderTypeName();
      minorList[i] = tempMinorList[i];
      minorCount = minorCount + 1;
      local civName = PlayerConfigurations[tempMinorList[i]]:GetCivilizationTypeName();
      minorBiases[i] = BBS_AssignStartingPlots:__FindBias(civName);
      
      print("---------CS ", i, "", leaderType);
   end
   
   print("--------------");
   print("--------------");
   
   --table.sort(majorAll, function(a, b) return a.biasScore > b.biasScore; end);
   

   for i = 1, majorCount do
      print("whole", majorAll[i]) 
      if (majorAll[i] ~= nil) then
         print("players2 ici: ", majorAll[i].civName, majorAll[i].biasScore);
      end
   end
   
   
   
   --------------------------
   ------Phase X Spawn analysis -------
   --------------------------
   
   print("--------------------------");
   print("--------------------------");
   print("Now starting analysis of the spawns");
   print("--------------------------");
   print(os.date("%c"));
   print("--------------------------");
   print("--------------------------");
   
   evaluateSpawns(majorAll, majorCount, minorList, minorCount, hasMaori);
   
   print("--------------------------");
   print("--------------------------");
   print("Ended spawn evaluation");
   print("--------------------------");
   print(os.date("%c"));
   print("--------------------------");
   print("--------------------------");
   

end

function evaluateSpawns(majorAll, majorCount, minorList, minorCount, hasMaori)

   
   if majorCount < 1 then
      print("No Major Civs to evaluate !");
      return;
   end
   
   
   
   
   local resourceBiases = {};
   local resourceBiasesCount = {};
   
   for i = 0, 5 do
      resourceBiases[i] = {};
      resourceBiasesCount[i] = 0;
   end
   
   local topQuartile = mapYSize * 0.75;
   local bottomQuartile = mapYSize * 0.25;
   
   
   for i = 0, mapXSize - 1 do
      local iIndex = i + 1;
      
      for j = 0, mapYSize - 1 do 
         local jIndex = j + 1 ;
         
         local maoriSelection = "NONE"; -- possible value : "NONE", "MAIN", "FALLBACK"
         ___Debug("--------------------------");
         ___Debug("Now evaluating tile:", i, j);
         ___Debug("--------------------------");
         
         if (mapSpawnable[iIndex][jIndex]) then -- We already have eliminated a lot of forbidden spawns
            
            
            if (mapTerrainCode[iIndex][jIndex] >= 15) then--If no maori, we can expedite things and not analyse water tiles
               -- Maori code --
               if (hasMaori) then
                  if (mapTerrainCode[iIndex][jIndex] == 15) then
                     maoriSelection = "FALLBACK";
                  else
                     for k = 1, 5 do
                        local list = getRing(i, j, k, mapXSize, mapYSize, mapIsRoundWestEast);
                        for _, element in ipairs(list) do
                           local x = element[1];
                           local y = element[2];
                           
                           if (mapTerrainCode[x + 1][y + 1] < 15) then -- We have land somewhere around -> tile will be fallback
                              maoriSelection = "FALLBACK";
                              break;
                           end
                        end
                        
                        if (maoriSelection == "FALLBACK") then
                           break; 
                        end
                     end
                     if (maoriSelection ~= "FALLBACK") then -- We have nothing but water -> good maori spawn !
                        maoriSelection = "MAIN";
                     end
                  end -- To finish !
               end
               
               -- END Maori Code --
            else -- we have a "normal" tile

               local ringTerrain = {};
               local ringResource = {};
               local ringFeature = {};
               local ringTwoTwo = {};
               local ringCount = {}; -- Amount of tiles per ring
               local ringMountainCount = {};
               local ringFloodPlains = {};
               local ringLandCount = {};
               local ringTundraCount = {};
               local ringDesertCount = {};
               local ringWaterCount = {};
               local ringRiver = {};
               local ringSea = {}; -- Amount of sea (not lake) tiles in ring x
               
               for k = 1, 5 do
                  ringTerrain[k] = {};
                  ringResource[k] = {};
                  ringFeature[k] = {};
                  ringTwoTwo[k] = 0;
                  ringCount[k] = 0;
                  ringLandCount[k] = 0;
                  ringWaterCount[k] = 0;
                  ringMountainCount[k] = 0;
                  ringDesertCount[k] = 0;
                  ringTundraCount[k] = 0;
                  ringFloodPlains[k] = 0;
                  ringRiver[k] = 0;
                  ringSea[k] = 0;
                  
                  for l = 1, 100 do
                     ringTerrain[k][l] = 0;
                     ringResource[k][l] = 0;
                     ringFeature[k][l] = 0;
                  end
               end
               
               --- Now getting the amount of each terrain, resource and feature for each ring !
               --- Also couting the amount of two-twos and riverTiles
               for k = 1, 5 do
                  local list = getRing(i, j, k, mapXSize, mapYSize, mapIsRoundWestEast);
                  
                  for _, element in ipairs(list) do
                     local x = element[1];
                     local y = element[2];
                     
                     local xIndex = x + 1;
                     local yIndex = y + 1;
                     
                     local terrain = mapTerrainCode[xIndex][yIndex];
                     local resource = mapResourceCode[xIndex][yIndex];
                     local feature = mapFeatureCode[xIndex][yIndex];
                     
                     if (terrain > -1) then
                        ringTerrain[k][terrain + 1] = ringTerrain[k][terrain + 1] + 1;
                        if (terrain >= 15) then
                           ringWaterCount[k] = ringWaterCount[k] + 1;
                        elseif (terrain % 3 == 2) then
                           ringMountainCount[k] = ringMountainCount[k] + 1;
                        else
                           ringLandCount[k] = ringLandCount[k] + 1;
                        end
                        
                        if (terrain == 6 or terrain == 7) then
                           ringDesertCount[k] = ringDesertCount[k] + 1;
                        elseif (terrain == 9 or terrain == 10 or terrain == 12 or terrain == 13) then
                           ringTundraCount[k] = ringTundraCount[k] + 1;
                        end
                     end
                     
                     if (resource > -1) then
                        ringResource[k][resource + 1] = ringResource[k][resource + 1] + 1;
                     end
                     
                     if (feature > -1) then
                        ringFeature[k][feature + 1] = ringFeature[k][feature + 1] + 1;
                        
                        if (feature == 0 or feature == 31 or feature == 32) then
                           ringFloodPlains[k] = ringFloodPlains[k] + 1;
                        end
                     end
                     
                     if mapTwoTwo[xIndex][yIndex] then
                        ringTwoTwo[k] = ringTwoTwo[k] + 1;
                     end
                     
                     if (mapRiver[xIndex][yIndex]) then
                        ringRiver[k] = ringRiver[k] + 1;
                     end
                     
                     if (mapSea[xIndex][yIndex]) then
                        ringSea[k] = ringSea[k] + 1;
                     end

                     ringCount[k] = ringCount[k] + 1;
                  end
               end
               
               -- Checking the amount of tiles for each rings
               local ring3LandCount = 1 + ringLandCount[1] + ringLandCount[2] + ringLandCount[3];
               local ring5LandCount = ring3LandCount + ringLandCount[4] + ringLandCount[5];
               
               local ring3WaterCount = 1 + ringWaterCount[1] + ringWaterCount[2] + ringWaterCount[3];
               local ring5WaterCount = ring3WaterCount + ringWaterCount[4] + ringWaterCount[5];
               
               local ring3Count = 1 + ringCount[1] + ringCount[2] + ringCount[3];
               local ring5Count = ring3Count + ringCount[4] + ringCount[5];
               
               
               --- Going now for a general analysis of the map --
               --- Check parameters: 
                  --- Mountains (not too many around, except for mountains lovers)
                  --- Floodplains
                  --- tundra/snow
                  --- desert
                 ------ The score will be evaluated for each civs according to their bias (ex: no tundra penalty for Russia/Canada
               local mountainScore = 0;
               
               if ringMountainCount[1] >= 3 then
                  mountainScore = mountainScore - 1000;
                  ___Debug("too many mountains ring 1");
               end
               
               local ring3Mountains = ringMountainCount[1] + ringMountainCount[2] + ringMountainCount[3];
               local ring5Mountains = ring3Mountains + ringMountainCount[4] + ringMountainCount[5];
               
               local percentageR3Mountains = ring3Mountains / ring3LandCount;
               local percentageR5Mountains = ring5Mountains / ring5LandCount;
               
               if percentageR3Mountains > MOUNTAINS_PERCENTAGE_R3 then
                  mountainScore = mountainScore - 1000;
                  ___Debug("too many mountains ring 1-3");
               elseif percentageR3Mountains > MOUNTAINS_PERCENTAGE_R3 - 0.05 then
                  mountainScore = mountainScore - 500;
                  ___Debug("too many mountains ring 1-3 (minored)");
               else
                  mountainScore = mountainScore + 500;
               end
               
               if percentageR3Mountains > MOUNTAINS_PERCENTAGE_R5 then
                  mountainScore = mountainScore - 1000;
                  ___Debug("too many mountains ring 1-5");
               elseif percentageR3Mountains > MOUNTAINS_PERCENTAGE_R5 - 0.05 then
                  mountainScore = mountainScore - 500;
                  ___Debug("too many mountains ring 1-5 (minored)");
               else
                  mountainScore = mountainScore + 500;
               end
                
                
               -- Flood Plains calculation
               local floodsScore = 0
               
               
               local ring3Floods = ringFloodPlains[1] + ringFloodPlains[2] + ringFloodPlains[3];
               if (mapFeatureCode[iIndex][jIndex] == 0 or mapFeatureCode[iIndex][jIndex] == 31 or mapFeatureCode[iIndex][jIndex] == 32) then
                  ring3Floods = ring3Floods + 1;
               end
               
               local ring5Floods = ring3Floods + ringFloodPlains[4] + ringFloodPlains[5];
               
               local percentageR3Floods = ring3Floods / ring3LandCount;
               local percentageR5Floods = ring5Floods / ring5LandCount;
               
               if percentageR3Floods > FLOODS_PERCENTAGE_R3 then
                  floodsScore = floodsScore - 1000;
                  ___Debug("too many floods ring 1-3");
               elseif percentageR3Floods > FLOODS_PERCENTAGE_R3 - 0.05 then
                  floodsScore = floodsScore - 500;
                  ___Debug("too many floods ring 1-3 (minored)");
               else
                  floodsScore = floodsScore + 500;
               end
               
               if percentageR5Floods > FLOODS_PERCENTAGE_R5 then
                  floodsScore = floodsScore - 1000;
                  ___Debug("too many floodss ring 1-5");
               elseif percentageR5Floods > FLOODS_PERCENTAGE_R5 - 0.05 then
                  floodsScore = floodsScore - 500;
                  ___Debug("too many floodss ring 1-5 (minored)");
               else
                  floodsScore = floodsScore + 500;
               end
               
               -- tundra (and snow) score
                  
               local tundraScore = 0
               
               
               local ring3Tundra = ringTundraCount[1] + ringTundraCount[2] + ringTundraCount[3];
               if (mapTerrainCode[iIndex][jIndex] == 9 or mapTerrainCode[iIndex][jIndex] == 10 or 
                    mapTerrainCode[iIndex][jIndex] == 12 or mapTerrainCode[iIndex][jIndex] == 13) then
                  ring3Tundra = ring3Tundra + 1;
               end
               
               local ring5Tundra = ring3Tundra + ringTundraCount[4] + ringTundraCount[5];
               
               local percentageR3Tundra = ring3Tundra / ring3LandCount;
               local percentageR5Tundra = ring5Tundra / ring5LandCount;
               
               if percentageR3Tundra > TUNDRA_PERCENTAGE_R3 then
                  tundraScore = tundraScore - 1000;
                  ___Debug("too many tundra ring 1-3");
                else
                  tundraScore = tundraScore + 500;
               end
               
               if percentageR5Tundra > TUNDRA_PERCENTAGE_R5 then
                  tundraScore = tundraScore - 1000;
                  ___Debug("too many tundras ring 1-5");
               elseif percentageR5Tundra > TUNDRA_PERCENTAGE_R5 - 0.02 then
                  tundraScore = tundraScore - 500;
                  ___Debug("too many tundras ring 1-5 (minored)");
               else
                  tundraScore = tundraScore + 500;
               end
               
               -- desert score
                  
               local desertScore = 0
               
               
               local ring3Desert = ringDesertCount[1] + ringDesertCount[2] + ringDesertCount[3];
               if (mapTerrainCode[iIndex][jIndex] == 6 or mapTerrainCode[iIndex][jIndex] == 7) then
                  ring3Desert = ring3Desert + 1;
               end
               
               local ring5Desert = ring3Desert + ringDesertCount[4] + ringDesertCount[5];
               
               local percentageR3Desert = ring3Desert / ring3LandCount;
               local percentageR5Desert = ring5Desert / ring5LandCount;
               
               if percentageR3Desert > DESERT_PERCENTAGE_R3 then
                  desertScore = desertScore - 1000;
                  ___Debug("too many desert ring 1-3");
                else
                  desertScore = desertScore + 500;
               end
               
               if percentageR5Desert > DESERT_PERCENTAGE_R5 then
                  desertScore = desertScore - 1000;
                  ___Debug("too many desert ring 1-5");
               elseif percentageR5Desert > DESERT_PERCENTAGE_R5 - 0.02 then
                  desertScore = desertScore - 500;
                  ___Debug("too many desert ring 1-5 (minored)");
               else
                  desertScore = desertScore + 500;
               end
               
               ---- Now evaluating the biases
               
               for k = 1, majorCount do
               
                  player = majorAll[k];
               
                  ___Debug("--------------------------");
                  ___Debug("---- Now evaluating player:", player.index, player.civName);
                  ___Debug("--------------------------");
                  -- Tier 1 and 2
                  local biasMandatoryScore = 0;
                  -- Tier 3, 4 and 5
                  local biasSecondaryScore = 0;
                  
                  
                  
                  local ringThreeTerrain = 0;
                  local ringFiveTerrain = 0;

                  --- TERRAINS ---
                  --- if two terrain have the same bias (ex: grassland hills and plain hills), they will be considered as one
                  
                  ___Debug("------- Looking at Terrain first");

                  -- grassland bias
                  if (player.biasTerrain[0 + 1] ~= 0) then
                     
                     local bias = player.biasTerrain[0 + 1];
                     
                     local terrainOne = 0;
                     local terrainTwo = -1;
                     
                     -- Actually towards grassland
                     if (player.biasTerrain[1 + 1] == bias) then
                        terrainTwo = 1;
                     
                     -- Looking for flatland (why would you do that ?)
                     elseif (player.biasTerrain[3 + 1] == bias) then
                        terrainTwo = 3;
                     end
                  

                     ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     
                     local percentageR3 = ringThreeTerrain / ring3LandCount;
                     local percentageR5 = ringFiveTerrain / ring5LandCount;
                     
                     local score = biasTerrainScore(bias, percentageR3, percentageR5);
                     
                     -- Main bias
                     if (math.abs(bias) <= 2) then
                        biasMandatoryScore = biasMandatoryScore + score;
                        ___Debug("-- primary -- Grassland flat score:", score)
                     -- Secondary Bias
                     else
                        biasSecondaryScore = biasSecondaryScore + score;
                        ___Debug("-- primary -- Grassland flat score:", score)
                     end
                  end
                  
                  -- Grassland hills
                  if (player.biasTerrain[1 + 1] ~= 0) then
                  
                     local bias = player.biasTerrain[1 + 1];
                  
                     local terrainOne = 1;
                     local terrainTwo = -1;
                     
                     -- flat grassland, but we already have calculated that !
                     if (player.biasTerrain[0 + 1] ~= bias) then
                     
                        -- Looking for hills
                        if (player.biasTerrain[4 + 1] == bias) then
                           terrainTwo = 4;
                        end
                        
                        ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        
                        local percentageR3 = ringThreeTerrain / ring3LandCount;
                        local percentageR5 = ringFiveTerrain / ring5LandCount;
                        
                        local score = biasTerrainScore(bias, percentageR3, percentageR5);
                        
                        -- Main bias
                        if (math.abs(bias) <= 2) then
                           biasMandatoryScore = biasMandatoryScore + score;
                           ___Debug("-- primary -- Grassland Hill score:", score)
                        -- Secondary Bias
                        else
                           biasSecondaryScore = biasSecondaryScore + score;
                           ___Debug("-- primary -- Grassland Hill score:", score)
                        end
                     end
                  
                  end
                  
                  -- Grassland mountain, different job here
                  if (player.biasTerrain[2 + 1] ~= 0) then
                  
                     local bias = player.biasTerrain[2 + 1];
                     local terrainOne = 2;
                     local terrainTwo = -1;
                     
                     -- Looking for mountain buddies
                     if (player.biasTerrain[5 + 1] == bias) then
                        terrainTwo = 5;
                     end
                  
                     ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     
                     local percentageR3 = ringThreeTerrain / ring3LandCount;
                     local percentageR5 = ringFiveTerrain / ring5LandCount;
                     
                     local score = biasMountainScore(bias, percentageR3, percentageR5);
                     
                     -- Main bias
                     if (math.abs(bias) <= 2) then
                        biasMandatoryScore = biasMandatoryScore + score;
                        ___Debug("-- primary -- Grassland Mountain score:", score)
                     -- Secondary Bias
                     else
                        biasSecondaryScore = biasSecondaryScore + score;
                        ___Debug("-- primary -- Grassland Mountain score:", score)
                     end
                  
                     
                  end
                  
                  
                  -- Flat plain
                  if (player.biasTerrain[3 + 1] ~= 0) then
                     
                     local bias = player.biasTerrain[3 + 1];
                     
                     local terrainOne = 3;
                     local terrainTwo = -1;
                     
                     -- flat grassland, but we already have calculated that !
                     if (player.biasTerrain[0 + 1] ~= bias) then
                     
                        -- Looking for plain hills as well
                        if (player.biasTerrain[4 + 1] == bias) then
                           terrainTwo = 4; 
                        end
                        
                        ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        
                        local percentageR3 = ringThreeTerrain / ring3LandCount;
                        local percentageR5 = ringFiveTerrain / ring5LandCount;
                        
                        local score = biasTerrainScore(bias, percentageR3, percentageR5);
                        
                        -- Main bias
                        if (math.abs(bias) <= 2) then
                           biasMandatoryScore = biasMandatoryScore + score;
                           ___Debug("-- primary -- Plain Flat score:", score)
                        -- Secondary Bias
                        else
                           biasSecondaryScore = biasSecondaryScore + score;
                           ___Debug("-- primary -- Plain Flat score:", score)
                        end
                     end
                  end
                  
                  -- Plain hill
                  if (player.biasTerrain[4 + 1] ~= 0) then
                     
                     local bias = player.biasTerrain[4 + 1];
                     
                     local terrainOne = 4;
                     local terrainTwo = -1;
                     
                     -- grassland hills or flat plain, that we already have looked !
                     if (player.biasTerrain[1 + 1] ~= bias and player.biasTerrain[3 + 1] ~= bias) then
                     
                        ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        
                        local percentageR3 = ringThreeTerrain / ring3LandCount;
                        local percentageR5 = ringFiveTerrain / ring5LandCount;
                        
                        local score = biasTerrainScore(bias, percentageR3, percentageR5);
                        
                        -- Main bias
                        if (math.abs(bias) <= 2) then
                           biasMandatoryScore = biasMandatoryScore + score;
                           ___Debug("-- primary -- Plain Hill score:", score)
                        -- Secondary Bias
                        else
                           biasSecondaryScore = biasSecondaryScore + score;
                           ___Debug("-- primary -- Plain Hill score:", score)
                        end
                     end
                  end
                  
                  -- Plain mountain, different job here
                  if (player.biasTerrain[5 + 1] ~= 0) then
                  
                     local bias = player.biasTerrain[5 + 1];
                     local terrainOne = 5;
                     local terrainTwo = -1;
                     
                     -- Grassland mountain that, but we already have calculated that !
                     if (player.biasTerrain[2 + 1] ~= bias) then
                        
                        ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        
                        local percentageR3 = ringThreeTerrain / ring3LandCount;
                        local percentageR5 = ringFiveTerrain / ring5LandCount;
                        
                        local score = biasMountainScore(bias, percentageR3, percentageR5);
                        
                        -- Main bias
                        if (math.abs(bias) <= 2) then
                           biasMandatoryScore = biasMandatoryScore + score;
                           ___Debug("-- primary -- Plain Mountain score:", score)
                        -- Secondary Bias
                        else
                           biasSecondaryScore = biasSecondaryScore + score;
                           ___Debug("-- primary -- Plain Mountain score:", score)
                        end
                     
                     end
                  end
                  
                  -- Flat desert
                  if (player.biasTerrain[6 + 1] ~= 0) then
                     
                     local bias = player.biasTerrain[6 + 1];
                     
                     local terrainOne = 3;
                     local terrainTwo = -1;
                     
                     -- Looking for plain hills as well
                     if (player.biasTerrain[7 + 1] == bias) then
                        terrainTwo = 7; 
                     end
                     
                     ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     
                     local percentageR3 = ringThreeTerrain / ring3LandCount;
                     local percentageR5 = ringFiveTerrain / ring5LandCount;
                     
                     local score = biasTerrainScore(bias, percentageR3, percentageR5);
                     
                     -- Main bias
                     if (math.abs(bias) <= 2) then
                        biasMandatoryScore = biasMandatoryScore + score;
                        ___Debug("-- primary -- Desert flat score:", score)
                     -- Secondary Bias
                     else
                        biasSecondaryScore = biasSecondaryScore + score;
                        ___Debug("-- Secondary -- Desert flat score:", score)
                     end
                  end
                  
                  -- desert hill
                  if (player.biasTerrain[7 + 1] ~= 0) then
                     
                     local bias = player.biasTerrain[7 + 1];
                     
                     local terrainOne = 3;
                     local terrainTwo = -1;
                     
                     -- flat desert, but we already have calculated that !
                     if (player.biasTerrain[6 + 1] ~= bias) then
                        
                        ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        
                        local percentageR3 = ringThreeTerrain / ring3LandCount;
                        local percentageR5 = ringFiveTerrain / ring5LandCount;
                        
                        local score = biasTerrainScore(bias, percentageR3, percentageR5);
                        
                        -- Main bias
                        if (math.abs(bias) <= 2) then
                           biasMandatoryScore = biasMandatoryScore + score;
                           ___Debug("-- primary -- Desert Hill score:", score)
                        -- Secondary Bias
                        else
                           biasSecondaryScore = biasSecondaryScore + score;
                           ___Debug("-- Secondary -- Desert Hill score:", score)
                        end
                     end
                  end
                  
                  -- tundra flat bias
                  if (player.biasTerrain[9 + 1] ~= 0) then
                     
                     local bias = player.biasTerrain[9 + 1];
                     
                     local terrainOne = 9;
                     local terrainTwo = -1;
                     
                     -- Actually towards tundra
                     if (player.biasTerrain[10 + 1] == bias) then
                        terrainTwo = 10;
                     end
                  
                     ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     
                     local percentageR3 = ringThreeTerrain / ring3LandCount;
                     local percentageR5 = ringFiveTerrain / ring5LandCount;
                     
                     local score = biasTerrainScore(bias, percentageR3, percentageR5);
                     
                     ___Debug(ring3LandCount, ring5LandCount);
                     
                     ___Debug(ringThreeTerrain, ringFiveTerrain, percentageR3, percentageR5)
                     
                     -- Main bias
                     if (math.abs(bias) <= 2) then
                        biasMandatoryScore = biasMandatoryScore + score;
                        ___Debug("-- primary -- Tundra flat score:", score)
                     -- Secondary Bias
                     else
                        biasSecondaryScore = biasSecondaryScore + score;
                        ___Debug("-- Secondary -- Tundra flat score:", score)
                     end
                     
                     print("score tundra flat:", biasSecondaryScore);

                  end
                  
                  -- tundra hills
                  if (player.biasTerrain[10 + 1] ~= 0) then
                  
                     local bias = player.biasTerrain[10 + 1];
                  
                     local terrainOne = 10;
                     local terrainTwo = -1;
                     
                     -- flat tundra, but we already have calculated that !
                     if (player.biasTerrain[9 + 1] ~= bias) then

                        ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        
                        local percentageR3 = ringThreeTerrain / ring3LandCount;
                        local percentageR5 = ringFiveTerrain / ring5LandCount;
                        
                        local score = biasTerrainScore(bias, percentageR3, percentageR5);
                        
                        -- Main bias
                        if (math.abs(bias) <= 2) then
                           biasMandatoryScore = biasMandatoryScore + score;
                           ___Debug("-- primary -- Tundra Hill score:", score)
                        -- Secondary Bias
                        else
                           biasSecondaryScore = biasSecondaryScore + score;
                           ___Debug("-- Secondary -- Tundra Hill score:", score)
                        end
                     end
                  
                  end
                  
                  -- tundra mountain, different job here
                  if (player.biasTerrain[11 + 1] ~= 0) then
                  
                     local bias = player.biasTerrain[11 + 1];
                     local terrainOne = 11;
                     local terrainTwo = -1;
                     
                     -- Looking for mountain buddies
                     if (player.biasTerrain[14 + 1] == bias) then
                        terrainTwo = 14;
                     end
                  
                     ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     
                     local percentageR3 = ringThreeTerrain / ring3LandCount;
                     local percentageR5 = ringFiveTerrain / ring5LandCount;
                     
                     local score = biasMountainScore(bias, percentageR3, percentageR5);
                     
                     -- Main bias
                     if (math.abs(bias) <= 2) then
                        biasMandatoryScore = biasMandatoryScore + score;
                        ___Debug("-- primary -- Tundra Mountain score:", score)
                     -- Secondary Bias
                     else
                        biasSecondaryScore = biasSecondaryScore + score;
                        ___Debug("-- Secondary -- Tundra Mountain score:", score)
                     end
                  end
                  
                  
                  -- Flat snow
                  if (player.biasTerrain[12 + 1] ~= 0) then
                     
                     local bias = player.biasTerrain[12 + 1];
                     
                     local terrainOne = 12;
                     local terrainTwo = -1;
                     
                     -- Looking for snow hills as well
                     if (player.biasTerrain[13 + 1] == bias) then
                        terrainTwo = 13; 
                     end
                     
                     ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     
                     local percentageR3 = ringThreeTerrain / ring3LandCount;
                     local percentageR5 = ringFiveTerrain / ring5LandCount;
                     
                     local score = biasTerrainScore(bias, percentageR3, percentageR5);
                     
                     -- Main bias
                     if (math.abs(bias) <= 2) then
                        biasMandatoryScore = biasMandatoryScore + score;
                        ___Debug("-- primary -- flat snow score:", score)
                     -- Secondary Bias
                     else
                        biasSecondaryScore = biasSecondaryScore + score;
                        ___Debug("-- Secondary -- flat snow score:", score)
                     end
                  end
                  
                  -- snow hill
                  if (player.biasTerrain[13 + 1] ~= 0) then
                     
                     local bias = player.biasTerrain[13 + 1];
                     
                     local terrainOne = 13;
                     local terrainTwo = -1;
                     
                     -- grassland hills or flat plain, that we already have looked !
                     if (player.biasTerrain[12 + 1] ~= bias) then
                     
                        ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                        
                        local percentageR3 = ringThreeTerrain / ring3LandCount;
                        local percentageR5 = ringFiveTerrain / ring5LandCount;
                        
                        local score = biasTerrainScore(bias, percentageR3, percentageR5);
                        
                        -- Main bias
                        if (math.abs(bias) <= 2) then
                           biasMandatoryScore = biasMandatoryScore + score;
                           ___Debug("-- primary -- Snow hill score:", score)
                        -- Secondary Bias
                        else
                           biasSecondaryScore = biasSecondaryScore + score;
                           ___Debug("-- Secondary -- Snow hill score:", score)
                        end
                     end
                  end
                  
                  -- snow mountain, different job here
                  if (player.biasTerrain[14 + 1] ~= 0) then
                  
                     local bias = player.biasTerrain[14 + 1];
                     local terrainOne = 14;
                     local terrainTwo = -1;
                     
                     ringThreeTerrain = getRingTerrain(1, 3, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     ringFiveTerrain = ringThreeTerrain + getRingTerrain(4, 5, mapTerrainCode[iIndex][jIndex], ringTerrain, terrainOne, terrainTwo);
                     
                     local percentageR3 = ringThreeTerrain / ring3LandCount;
                     local percentageR5 = ringFiveTerrain / ring5LandCount;
                     
                     local score = biasMountainScore(bias, percentageR3, percentageR5);
                     
                     -- Main bias
                     if (math.abs(bias) <= 2) then
                        biasMandatoryScore = biasMandatoryScore + score;
                        ___Debug("-- primary -- Snow Mountain score:", score)
                     -- Secondary Bias
                     else
                        biasSecondaryScore = biasSecondaryScore + score;
                        ___Debug("-- Secondary -- Snow Mountain score:", score)
                     end
                  end
                  
                  
                  -- Coastal spawn.
                  -- Simply gonna check if the tile is coastal or not
                  if (player.biasTerrain[15 + 1] ~= 0) then
                     local bias = player.biasTerrain[14 + 1];
                     if (mapCoastal[iIndex][jIndex]) then

                        if (bias <= 2) then
                           biasMandatoryScore = biasMandatoryScore + 2000;
                           ___Debug("-- primary -- tile IS coastal", 2000)
                        -- Secondary Bias
                        else
                           biasSecondaryScore = biasSecondaryScore + 1000;
                           ___Debug("-- Secondary -- tile IS coastal", 1000)
                        end 
                     -- non coastal tile
                     else
                        if (bias <= 2) then
                           biasMandatoryScore = biasMandatoryScore - 2000;
                           ___Debug("-- primary -- tile IS NOT coastal", -2000)
                        -- Secondary Bias
                        else
                           biasSecondaryScore = biasSecondaryScore - 1000;
                           ___Debug("-- Secondary -- tile IS NOT coastal", -1000)
                        end 
                     end
                  end
                  
                  
                  --- NEXT Phase --
                  --- Resource bias calculation ---
                  
                  
                  ___Debug("---Resources biases---");
                  
                  local ringThreeResource = 0;
                  local ringFiveResource = 0;

                  for k = 1, 5 do
                     if (player.resourcesBiasListCount[k] > 0) then
                     
                        ___Debug("For bias:", k, ",resources list:");
                        for l = 1, player.resourcesBiasListCount[k] do
                           ___Debug("-----resources looked at:", player.resourcesBiasList[k][l]);
                        end
                     
                        ringThreeResource = getRingResource(1, 3, mapResourceCode[iIndex][jIndex], ringResource, player.resourcesBiasList[k], player.resourcesBiasListCount[k]);
                        ringFiveResource = ringThreeResource + getRingResource(4, 5, mapResourceCode[iIndex][jIndex], ringResource, player.resourcesBiasList[k], player.resourcesBiasListCount[k]);
                  
                         ___Debug("nombre de resources:", ringThreeResource, ringFiveResource);
                  
                        local percentageR3 = ringThreeResource / ring3LandCount;
                        local percentageR5 = ringFiveResource / ring5LandCount;
                  
                        ___Debug("pourcentage de resources:", percentageR3, percentageR5);
                  
                        local score = biasResourceScore(k, percentageR3, percentageR5);
                  
                        ___Debug("Resource score:", score);
                        
                        -- primary bias
                        if (k <= 2) then
                           biasMandatoryScore = biasMandatoryScore + score;
                           ___Debug("-- primary -- score:", score)
                        -- Secondary Bias
                        else
                           biasSecondaryScore = biasSecondaryScore + score;
                           ___Debug("-- Secondary -- score:", score)
                        end
                     end
                     
                  end
                  
                  ___Debug("--- NEGATIVE Resources biases---");
                  
                  for k = 1, 5 do
                     if (player.resourcesNegativeBiasListCount[k] > 0) then
                     
                        ___Debug("For bias:", k, ",resources list:");
                        for l = 1, player.resourcesNegativeBiasListCount[k] do
                           ___Debug("-----resources looked at:", player.resourcesNegativeBiasList[k][l]);
                        end
                     
                        ringThreeResource = getRingResource(1, 3, mapResourceCode[iIndex][jIndex], ringResource, player.resourcesNegativeBiasList[k], player.resourcesNegativeBiasListCount[k]);
                        ringFiveResource = ringThreeResource + getRingResource(4, 5, mapResourceCode[iIndex][jIndex], ringResource, player.resourcesNegativeBiasList[k], player.resourcesNegativeBiasListCount[k]);
                  
                         ___Debug("nombre de resources:", ringThreeResource, ringFiveResource);
                  
                        local percentageR3 = ringThreeResource / ring3LandCount;
                        local percentageR5 = ringFiveResource / ring5LandCount;
                  
                        ___Debug("pourcentage de resources:", percentageR3, percentageR5);
                  
                        local score = NegativeBiasResourceScore(k, percentageR3, percentageR5);
                  
                        ___Debug("Resource score:", score);
                        
                        -- primary bias
                        if (k <= 2) then
                           biasMandatoryScore = biasMandatoryScore + score;
                           ___Debug("-- primary -- score:", score)
                        -- Secondary NegativeBias
                        else
                           biasSecondaryScore = biasSecondaryScore + score;
                           ___Debug("-- Secondary -- score:", score)
                        end
                     end
                     
                  end
                  
                  ___Debug("---Feature biases---");
                  
                  --- Next Phase ---
                  --- Feature bias calculation ---
                  
                  local ringThreeFeature = 0;
                  local ringFiveFeature = 0;

                  for k = 1, 5 do
                     if (player.featuresBiasListCount[k] > 0) then
                     
                        ___Debug("For bias:", k, ",features list:");
                        for l = 1, player.featuresBiasListCount[k] do
                           ___Debug("-----features looked at:", player.featuresBiasList[k][l]);
                        end
                     
                        ringThreeFeature = getRingFeature(1, 3, mapFeatureCode[iIndex][jIndex], ringFeature, player.featuresBiasList[k], player.featuresBiasListCount[k]);
                        ringFiveFeature = ringThreeFeature + getRingFeature(4, 5, mapFeatureCode[iIndex][jIndex], ringFeature, player.featuresBiasList[k], player.featuresBiasListCount[k]);
                  
                         ___Debug("nombre de features:", ringThreeFeature, ringFiveFeature);
                  
                        local percentageR3 = ringThreeFeature / ring3LandCount;
                        local percentageR5 = ringFiveFeature / ring5LandCount;
                  
                        ___Debug("pourcentage de features:", percentageR3, percentageR5);
                  
                        local score = biasFeatureScore(k, percentageR3, percentageR5);
                  
                        ___Debug("Feature score:", score);
                        
                        -- primary bias
                        if (k <= 2) then
                           biasMandatoryScore = biasMandatoryScore + score;
                           ___Debug("-- primary -- score:", score)
                        -- Secondary Bias
                        else
                           biasSecondaryScore = biasSecondaryScore + score;
                           ___Debug("-- Secondary -- score:", score)
                        end
                     end
                     
                  end
                  
                  ___Debug("--- NEGATIVE Feature biases---");
                  
                  for k = 1, 5 do
                     if (player.featuresNegativeBiasListCount[k] > 0) then
                     
                        ___Debug("For bias:", k, ", NEGATIVE features list:");
                        for l = 1, player.featuresNegativeBiasListCount[k] do
                           ___Debug("-----Negative features looked at:", player.featuresNegativeBiasList[k][l]);
                        end
                     
                        ringThreeFeature = getRingFeature(1, 3, mapFeatureCode[iIndex][jIndex], ringFeature, player.featuresNegativeBiasList[k], player.featuresNegativeBiasListCount[k]);
                        ringFiveFeature = ringThreeFeature + getRingFeature(4, 5, mapFeatureCode[iIndex][jIndex], ringFeature, player.featuresNegativeBiasList[k], player.featuresNegativeBiasListCount[k]);
                  
                         ___Debug("nombre de features:", ringThreeFeature, ringFiveFeature);
                  
                        local percentageR3 = ringThreeFeature / ring3LandCount;
                        local percentageR5 = ringFiveFeature / ring5LandCount;
                  
                        ___Debug("pourcentage de feature:", percentageR3, percentageR5);
                  
                        local score = negativeBiasFeatureScore(k, percentageR3, percentageR5);
                  
                        ___Debug("Feature score:", score);
                        
                        -- primary bias
                        if (k <= 2) then
                           biasMandatoryScore = biasMandatoryScore + score;
                           ___Debug("-- primary -- score:", score)
                        -- Secondary NegativeBias
                        else
                           biasSecondaryScore = biasSecondaryScore + score;
                           ___Debug("-- Secondary -- score:", score)
                        end
                     end
                     
                  end
                  
                  
                  local ringThreeRiver = 0;
                  local ringFiveRiver = 0;
                  
                  ___Debug("------------------");
                  ___Debug("--- River Bias ---");
                  ___Debug("------------------");
                  
                  if (player.riverBias > 0 ) then
                     local score = 0;
                     
                     -- Tile is not a river, not even evaluating --
                     if( not mapRiver[iIndex][jIndex]) then
                        
                        if (player.riverBias < 3 ) then
                           score = 0 - 2000;
                        else
                           score = 0 - 1000;
                        end
                     -- Tile is a River
                     else
                        ringThreeRiver = getRingRiver(1, 3, ringRiver);
                        ringFiveRiver = ringThreeRiver + getRingRiver(4, 5, ringRiver);
                        
                        ___Debug("nombre de cases de riviere:", ringThreeRiver, ringFiveRiver);
                  
                        local percentageR3 = ringThreeRiver / ring3LandCount;
                        local percentageR5 = ringFiveRiver / ring5LandCount;
                  
                        ___Debug("pourcentage de rivieres", percentageR3, percentageR5);
                  
                        score = biasRiverScore(player.riverBias, percentageR3, percentageR5);
                  
                        ___Debug("River score:", score);
                     end
                     
                     -- primary bias
                     if (k <= 2) then
                        biasMandatoryScore = biasMandatoryScore + score;
                        ___Debug("-- primary -- score:", score)
                     -- Secondary NegativeBias
                     else
                        biasSecondaryScore = biasSecondaryScore + score;
                        ___Debug("-- Secondary -- score:", score)
                     end
                  end
                  
                  
                  -- Is Salty does not matter for positioning and will be ignored here
                  -- Australia already has a bias for coast
                  
                  -- Mountain lover as well: Inca has a bias towards mountain
                  -- It will be used to allow more mountains in the general placement
                  
                  -----------------
                  -- CUSTOM BIASES ---
                  -----------------
                
                  --- Continent split ---
                
                  if (player.continentSplit) then
                     if (mapIsContinentSplit[iIndex][jIndex]) then
                        biasMandatoryScore = biasMandatoryScore + 800;
                        ___Debug("Tile is Continent Split: score: +800");
                     else
                        biasMandatoryScore = biasMandatoryScore - 1600;
                        ___Debug("Tile is NOT Continent Split: score: -1600");
                     end
                  end
                  
                  --- Hydrophobic ---
                  
                  if (player.isHydrophobic) then
                     local hasWater = false;
                     for k = 1, 3 do
                        if (ringSea[k] > 0) then
                           ___Debug("Found sea water in ring", k, " Breaking");
                           hasWater = true;
                           break;
                        end
                     end
                     
                     if (not hasWater) then
                        -- I will allow a maximum of 2 coastal/deap water tiles ring 4
                        if (ringSea[4] > 2) then
                           ___Debug("Found sea water in ring 4");
                           hasWater = true;
                        end
                        
                        -- I will allow a maximum of 4 coastal/deap water tiles ring 5
                        if (ringSea[5] > 4) then
                           ___Debug("Found sea water in ring 5");
                           hasWater = true;
                        end
                     end
                     
                     if (not hasWater) then
                        biasMandatoryScore = biasMandatoryScore + 800;
                        ___Debug("Tile is far enough from the sea: score: +800");
                     else
                        biasMandatoryScore = biasMandatoryScore - 1600;
                        ___Debug("Tile is too close to the sea: score: -1600");
                     end
                  end
                  
                  
                     
                  
                  if (player.isNorthKing) then
                     -- King of the North --
                     if MapConfiguration.GetValue("MAP_SCRIPT") == "Tilted_Axis.lua"  then
                        if j > bottomQuartile and j < topQuartile and i > bottomQuartile and i < topQuartile then
                           ___Debug("Tile is Northen/Southern enough (Tilted version");
                           biasMandatoryScore = biasMandatoryScore + 800;
                        else
                           ___Debug("Tile is NOT Northen/Southern enough (Tilted version)");
                           biasMandatoryScore = biasMandatoryScore - 1600;
                        end
                     else
                        if j < bottomQuartile or j > topQuartile then
                           ___Debug("Tile is Northen/Southern enough");
                           biasMandatoryScore = biasMandatoryScore + 800;
                        else
                           ___Debug("Tile is NOT Northen/Southern enough");
                           biasMandatoryScore = biasMandatoryScore - 1600;
                        end
                     end
                  end
                   --- End biasis checks
               end
            end
         end
      end
   end
end


function getRingTerrain (ringStart, ringEnd, tileTerrain, ringTerrain, terrainOne, terrainTwo)

   local count = 0;
   
   if (tileTerrain == terrainOne or tileTerrain == terrainTwo) then
      count = count + 1;
   end
   
   if terrainTwo >= 0 then
      for i = ringStart, ringEnd do
         count = count + ringTerrain[i][terrainOne + 1] + ringTerrain[i][terrainTwo + 1];
      end
   
   else
      for i = ringStart, ringEnd do
         count = count + ringTerrain[i][terrainOne + 1];
      end
   end
   
   return count;

end

function getRingResource (ringStart, ringEnd, tileResource, ringResource, biasesList, biasesListCount)

   local count = 0;
   
   for i = 1, biasesListCount do
      if (biasesList[i] == tileResource) then
         print("biases:", biasesList[i]);
         count = count + 1;
      end
   end
   
   for i = ringStart, ringEnd do
      for j = 1, biasesListCount do
          count = count + ringResource[i][biasesList[j] + 1];
      end
   end
   
   return count;

end


function getRingFeature (ringStart, ringEnd, tileFeature, ringFeature, biasesList, biasesListCount)

   local count = 0;
   
   for i = 1, biasesListCount do
      if (biasesList[i] == tileFeature) then
         print("biases:", biasesList[i]);
         count = count + 1;
      end
   end
   
   for i = ringStart, ringEnd do
      for j = 1, biasesListCount do
          count = count + ringFeature[i][biasesList[j] + 1];
      end
   end
   
   return count;

end


function getRingRiver (ringStart, ringEnd, ringRiver)

   local count = 0;
   
   for i = ringStart, ringEnd do
      count = count + ringRiver[i];
   end
   
   return count;

end

function isMountainCode(terrain)

   if (terrain == 2 or terrain == 5 or terrain == 8 or terrain == 11 or terrain == 14) then
      return true;
   end
   
   return false;

end

function isLuxury(resource)

   if(resource >= 10 and resource < 40) then
      return true;
   end
   
   if (resource == 49 or resource == 50 or resource == 51 or resource == 53) then
      return true;
   end
   
   return false;
end



-- Firaxis function would return true for tiles bordering lakes, which we don't want--
function isCoastalTile (xStart, yStart, xSize, ySize, mapIsRoundWestEast)

   -- the tile is water, no sense to evaluate
   if (mapTerrainCode[xStart + 1][yStart + 1] >= 15) then
      return false;
   end
   
   local ring1 = getRing(xStart, yStart, 1, xSize, ySize, mapIsRoundWestEast);
   for _, element in ipairs(ring1) do
      local x = element[1];
      local y = element[2];
      
      if (mapTerrainCode[x + 1][y + 1] == 15 and mapLake[x + 1][y + 1] == false) then
         ___Debug("TEST THIS TILE IS WATER", x, y);
         return true;
      end
   end
   
   return false;
end

------------------------------------------------------------------------------
function BBS_AssignStartingPlots:__InitStartingData()
   	___Debug("BBS_AssignStartingPlots: Start:", os.date("%c"));
      
      
   ---- TEMPORARY !!! -----
   --NewBBS();
   
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
    elseif (featureType == "FEATURE_MARSH") then
        return g_FEATURE_MARSH;
    elseif (featureType == "FEATURE_OASIS") then
        return g_FEATURE_OASIS;
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
	