------------------------------------------------------------------------------
--	FILE:	 Primordial.lua
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Base game script - Produces widely varied continents.
------------------------------------------------------------------------------
--	Copyright (c) 2014 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------

include "MapEnums"
include "MapUtilities"
include "BBS_MountainsCliffs"
include "RiversLakes"
include "FeatureGenerator"
include "BBS_TerrainGenerator"
include "TerrainGenerator"
include "BBS_NaturalWonderGenerator"
include "BBS_ResourceGenerator"
include "CoastalLowlands"
include "AssignStartingPlots"
include "BBS_AssignStartingPlots";include "BBS_Balance";local g_iW, g_iH;
local g_iFlags = {};
local g_continentsFrac = nil;
local featureGen = nil;
local world_age_new = 7;
local world_age_normal = 5;
local world_age_old = 3;
local islands = {};

-------------------------------------------------------------------------------
function BBS_Assign(args)
	print("BBS_Assign: Injecting Spawn Placement")
	local start_plot_database = {};

	start_plot_database = BBS_AssignStartingPlots.Create(args)

	return start_plot_database
end
-------------------------------------------------------------------------------
function GenerateMap()
	print("Generating Primordial Map");
	local pPlot;

	-- Set globals
	g_iW, g_iH = Map.GetGridSize();
	g_iFlags = TerrainBuilder.GetFractalFlags();

	local temperature = MapConfiguration.GetValue("temperature"); -- Default setting is Temperate.
	if temperature == 4 then
		temperature  =  1 + TerrainBuilder.GetRandomNumber(3, "Random Temperature- Lua");
	end
	
	--	local world_age
	local world_age = MapConfiguration.GetValue("world_age");
	if (world_age == 1) then
		world_age = world_age_new;
	elseif (world_age == 2) then
		world_age = world_age_normal;
	elseif (world_age == 3) then
		world_age = world_age_old;
	else
		world_age = 2 + TerrainBuilder.GetRandomNumber(4, "Random World Age - Lua");
	end
	
	local temperature = MapConfiguration.GetValue("temperature"); -- Default setting is Temperate.
	if temperature == 4 then
		temperature  =  1 + TerrainBuilder.GetRandomNumber(3, "Random Temperature- Lua");
	end
	
	plotTypes = GeneratePlotTypes(world_age);
	local BBS_temp = false;
	if (GameConfiguration.GetValue("BBStemp") ~= nil) then 
		if (GameConfiguration.GetValue("BBStemp") == true) then
			BBS_temp = true;
			print ("BBS Temperature: On");
			terrainTypes = BBS_GenerateTerrainTypes(plotTypes, g_iW, g_iH, g_iFlags, false, temperature, 0, 0, 6, 0.05, 0.1, -0.05, 0.0, 0.0);
			else
			BBS_temp = false;
			terrainTypes = GenerateTerrainTypes(plotTypes, g_iW, g_iH, g_iFlags, false, temperature, 0, 0, 6, 0.05, 0.1, -0.05, 0.0, 0.0);
		end
		else
		BBS_temp = false;
		terrainTypes = GenerateTerrainTypes(plotTypes, g_iW, g_iH, g_iFlags, false, temperature, 0, 0, 6, 0.05, 0.1, -0.05, 0.0, 0.0);
	end
	ApplyBaseTerrain(plotTypes, terrainTypes, g_iW, g_iH);
	
	AreaBuilder.Recalculate();
	TerrainBuilder.AnalyzeChokepoints();
	TerrainBuilder.StampContinents();

	local iContinentBoundaryPlots = GetContinentBoundaryPlotCount(g_iW, g_iH);
	local biggest_area = Areas.FindBiggestArea(false);
	print("After Adding Hills: ", biggest_area:GetPlotCount());
		if (MapConfiguration.GetValue("BBSRidge") ~= 1) then
		print("Adding Ridges");
	AddTerrainFromContinents(plotTypes, terrainTypes, world_age, g_iW, g_iH, iContinentBoundaryPlots);
	end
	AreaBuilder.Recalculate();

	-- River generation is affected by plot types, originating from highlands and preferring to traverse lowlands.
	AddRivers();
	
	-- Lakes would interfere with rivers, causing them to stop and not reach the ocean, if placed any sooner.
	local numLargeLakes = GameInfo.Maps[Map.GetMapSize()].Continents
	AddLakes(numLargeLakes);

	AddFeatures();
	TerrainBuilder.AnalyzeChokepoints();
	
	print("Adding cliffs");
	AddCliffs(plotTypes, terrainTypes);

	local args = {
		numberToPlace = GameInfo.Maps[Map.GetMapSize()].NumNaturalWonders,
	};
	local nwGen = BBS_NaturalWonderGenerator.Create(args);
	
	AddFeaturesFromContinents();
	MarkCoastalLowlands();
	
	--for i = 0, (g_iW * g_iH) - 1, 1 do
		--pPlot = Map.GetPlotByIndex(i);
		--print ("i: plotType, terrainType, featureType: " .. tostring(i) .. ": " .. tostring(plotTypes[i]) .. ", " .. tostring(terrainTypes[i]) .. ", " .. tostring(pPlot:GetFeatureType(i)));
	--end
	local resourcesConfig = MapConfiguration.GetValue("resources");
	local startconfig = MapConfiguration.GetValue("start"); -- Get the start config
	local args = {
		iWaterLux = 2,
		resources = resourcesConfig,
		START_CONFIG = startConfig,
	};
	local resGen = BBS_ResourceGenerator.Create(args);
   
   if (MapConfiguration.GetValue("BBSRidge") == 1) then
		AddVolcanos(plotTypes,world_age,g_iW, g_iH)
	end

	print("Creating start plot database.");
	
	-- START_MIN_Y and START_MAX_Y is the percent of the map ignored for major civs' starting positions.
	local args = {
		MIN_MAJOR_CIV_FERTILITY = 175,
		MIN_MINOR_CIV_FERTILITY = 25, 
		MIN_BARBARIAN_FERTILITY = 1,
		START_MIN_Y = 15,
		START_MAX_Y = 15,
		START_CONFIG = startconfig,
	};
	local start_plot_database = BBS_Assign(args)

		local GoodyGen = AddGoodies(g_iW, g_iH);	local Balance = BBS_Script();	AreaBuilder.Recalculate();	TerrainBuilder.AnalyzeChokepoints();
end


-------------------------------------------------------------------------------
function GeneratePlotTypes(world_age)
	print("Generating Plot Types");
	local plotTypes = {};
	
	local sea_level_low = 65;
	local sea_level_normal = 72;
	local sea_level_high = 78;
	local extra_mountains = 0;
	local adjust_plates = 1.0;
	local shift_plot_types = true;
	local hills_ridge_flags = g_iFlags;
	local peaks_ridge_flags = g_iFlags;
	local has_center_rift = false;

	--	local sea_level
    local sea_level = MapConfiguration.GetValue("sea_level");
	local water_percent;
	local water_percent_modifier = 0;
	if sea_level == 1 then -- Low Sea Level
		water_percent = sea_level_low
		water_percent_modifier = -4
	elseif sea_level == 2 then -- Normal Sea Level
		water_percent =sea_level_normal
		water_percent_modifier = 4;
	elseif sea_level == 3 then -- High Sea Level
		water_percent = sea_level_high
	else
		water_percent = TerrainBuilder.GetRandomNumber(sea_level_high- sea_level_low, "Random Sea Level - Lua") + sea_level_low  + 1 ;
		water_percent_modifier = TerrainBuilder.GetRandomNumber(9, "Random Sea Level - Lua") - 4;
	end

	-- Set values for hills and mountains according to World Age chosen by user.
	local adjustment = world_age;
	if world_age <= world_age_old  then -- 5 Billion Years
		adjust_plates = adjust_plates * 0.75;
	elseif world_age >= world_age_new then -- 3 Billion Years
		adjust_plates = adjust_plates * 1.5;
	else -- 4 Billion Years
	end

	local hillsBottom1 = 28 - adjustment;
	local hillsTop1 = 28 + adjustment;
	local hillsBottom2 = 72 - adjustment;
	local hillsTop2 = 72 + adjustment;
	local hillsClumps = 1 + adjustment;
	local hillsNearMountains = 91 - (adjustment * 2) - extra_mountains;
	local mountains = 97 - adjustment - extra_mountains;

	local polar =  true;

	local fracFlags = {};

	fracFlags.FRAC_POLAR = true;
	local MapSizeTypes = {};
	for row in GameInfo.Maps() do
		MapSizeTypes[row.MapSizeType] = row.PlateValue;
	end
	local sizekey = Map.GetMapSize();
	local numPlates = MapSizeTypes[sizekey] or 4;

	local continent_grain = 3;
	local rift_grain = -1;

	local riftsFrac = Fractal.Create(g_iW, g_iH, rift_grain, {}, 6, 5);
	g_continentsFrac = Fractal.CreateRifts(g_iW, g_iH, continent_grain, fracFlags, riftsFrac, 6, 5);
	g_continentsFrac:BuildRidges(numPlates, {}, 1, 2);
	
	hillsFrac = Fractal.Create(g_iW, g_iH, continent_grain, {}, 6, 5);
	mountainsFrac = Fractal.Create(g_iW, g_iH, continent_grain, {}, 6, 5);
	hillsFrac:BuildRidges(numPlates, g_iFlags, 1, 2);
	mountainsFrac:BuildRidges(numPlates * 2/3, g_iFlags, 6, 1);
	local iWaterThreshold = g_continentsFrac:GetHeight(water_percent);	
	local iHillsBottom1 = hillsFrac:GetHeight(hillsBottom1);
	local iHillsTop1 = hillsFrac:GetHeight(hillsTop1);
	local iHillsBottom2 = hillsFrac:GetHeight(hillsBottom2);
	local iHillsTop2 = hillsFrac:GetHeight(hillsTop2);
	local iHillsClumps = mountainsFrac:GetHeight(hillsClumps);
	local iHillsNearMountains = mountainsFrac:GetHeight(hillsNearMountains);
	local iMountainThreshold = mountainsFrac:GetHeight(mountains);
	local iPassThreshold = hillsFrac:GetHeight(hillsNearMountains);
	local iMountain100 = mountainsFrac:GetHeight(100);
	local iMountain99 = mountainsFrac:GetHeight(99);
	local iMountain97 = mountainsFrac:GetHeight(97);
	local iMountain95 = mountainsFrac:GetHeight(95);

	for x = 0, g_iW - 1 do
		for y = 0, g_iH - 1 do
			local i = y * g_iW + x + 1;
			local val = g_continentsFrac:GetHeight(x, y);
			local mountainVal = mountainsFrac:GetHeight(x, y);
			local hillVal = hillsFrac:GetHeight(x, y);
			local pPlot = Map.GetPlotByIndex(i);
	
			if(val <= iWaterThreshold) then
				plotTypes[i] = g_PLOT_TYPE_OCEAN;
				TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_OCEAN);  -- temporary setting so can calculate areas

				if (mountainVal == iMountain100) then -- Isolated peak in the ocean
					plotTypes[i] = g_PLOT_TYPE_MOUNTAIN;
					TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_DESERT);  -- temporary setting so can calculate areas
				elseif (mountainVal == iMountain99) then
					plotTypes[i] = g_PLOT_TYPE_HILLS;
					TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_DESERT);  -- temporary setting so can calculate areas
				elseif (mountainVal == iMountain97) or (mountainVal == iMountain95) then
					plotTypes[i] = g_PLOT_TYPE_LAND;
					TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_DESERT);  -- temporary setting so can calculate areas
				end
			else
				if (mountainVal >= iMountainThreshold) then
					if (hillVal >= iPassThreshold) then -- Mountain Pass though the ridgeline - Brian
						plotTypes[i] = g_PLOT_TYPE_HILLS;
						TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_DESERT);  -- temporary setting so can calculate areas
					else -- Mountain
						plotTypes[i] = g_PLOT_TYPE_MOUNTAIN;
						TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_DESERT);  -- temporary setting so can calculate areas
					end
				elseif (mountainVal >= iHillsNearMountains) then
					plotTypes[i] = g_PLOT_TYPE_HILLS;
					TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_DESERT);  -- temporary setting so can calculate areas
				else
					if ((hillVal >= iHillsBottom1 and hillVal <= iHillsTop1) or (hillVal >= iHillsBottom2 and hillVal <= iHillsTop2)) then
						plotTypes[i] = g_PLOT_TYPE_HILLS;
						TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_DESERT);  -- temporary setting so can calculate areas
					else
						plotTypes[i] = g_PLOT_TYPE_LAND;
						TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_DESERT);  -- temporary setting so can calculate areas
					end
				end
			end
		end
	end
	
	ShiftPlotTypes(plotTypes);
	AreaBuilder.Recalculate();

	-- Generate Large Islands	
	local args = {};	
	islands = plotTypes;
	args.iWaterPercent = 68 + water_percent_modifier;
	args.iRegionWidth = math.ceil(g_iW);
	args.iRegionHeight = math.ceil(g_iH);
	args.iRegionWestX = math.floor(0);
	args.iRegionSouthY = math.floor(0);
	args.iRegionGrain = 3;
	args.iRegionHillsGrain = 4;
	args.iRegionPlotFlags = g_iFlags;
	args.iRegionFracXExp = 6;
	args.iRegionFracYExp = 5;
	plotTypes = GenerateFractalLayerWithoutHills(args, plotTypes);
	
	-- Generate Medium Islands	
	local args = {};	
	islands = plotTypes;
	args.iWaterPercent = 77 + water_percent_modifier;
	args.iRegionWidth = math.ceil(g_iW);
	args.iRegionHeight = math.ceil(g_iH);
	args.iRegionWestX = math.floor(0);
	args.iRegionSouthY = math.floor(0);
	args.iRegionGrain = 3;
	args.iRegionHillsGrain = 4;
	args.iRegionPlotFlags = g_iFlags;
	args.iRegionFracXExp = 6;
	args.iRegionFracYExp = 5;
    plotTypes = GenerateFractalLayerWithoutHills(args, plotTypes);

	-- Generate Small Islands
	local args = {};	
	islands = plotTypes;
	args.iWaterPercent = 86 + water_percent_modifier;
	args.iRegionWidth = math.ceil(g_iW);
	args.iRegionHeight = math.ceil(g_iH);
	args.iRegionWestX = math.floor(0);
	args.iRegionSouthY = math.floor(0);
	args.iRegionGrain = 4;
	args.iRegionHillsGrain = 4;
	args.iRegionPlotFlags = g_iFlags;
	args.iRegionFracXExp = 7;
	args.iRegionFracYExp = 6;
    plotTypes = GenerateFractalLayerWithoutHills(args, plotTypes);

	-- Generate Tiny Islands
	local args = {};	
	islands = plotTypes;
	args.iWaterPercent = 95+ water_percent_modifier;
	args.iRegionWidth = math.ceil(g_iW);
	args.iRegionHeight = math.ceil(g_iH);
	args.iRegionWestX = math.floor(0);
	args.iRegionSouthY = math.floor(0);
	args.iRegionGrain = 5;
	args.iRegionHillsGrain = 4;
	args.iRegionPlotFlags = g_iFlags;
	args.iRegionFracXExp = 7;
	args.iRegionFracYExp = 6;
    plotTypes = GenerateFractalLayerWithoutHills(args, plotTypes);

	ShiftPlotTypes(plotTypes);
	AreaBuilder.Recalculate();

	local args = {};
	world_age = world_age;
	args.world_age = world_age;
	args.iW = g_iW;
	args.iH = g_iH
	args.iFlags = g_iFlags;
	args.tectonic_islands = false;
	args.blendRidge = 10;
	args.blendFract = 1;
	args.extra_mountains = 10;
	mountainRatio = 11 + world_age * 2;
		if (MapConfiguration.GetValue("BBSRidge") == 1) then
		mountainRatio = 10 + world_age * 3;
	end
	plotTypes = ApplyTectonics(args, plotTypes);
	plotTypes = AddLonelyMountains(plotTypes, mountainRatio);

	return plotTypes;
end

----------------------------------------------------------------------------------
function AddFeatures()
	print("Adding Features");

	-- Get Rainfall setting input by user.
	local rainfall = MapConfiguration.GetValue("rainfall");
	if rainfall == 4 then
		rainfall = 1 + TerrainBuilder.GetRandomNumber(3, "Random Rainfall - Lua");
	end
	
	local args = {rainfall = rainfall, iMarshPercent = 9, iJunglePercent = 60, iIcePercent = -5}
	featuregen = FeatureGenerator.Create(args);
	featuregen:AddFeatures(true, true);  --second parameter is whether or not rivers start inland);
end

function AddFeaturesFromContinents()
	print("Adding Features from Continents");

	featuregen:AddFeaturesFromContinents();
end

-------------------------------------------------------------------------------
function GenerateFractalLayerWithoutHills (args, plotTypes)
	local args = args or {};
	local plotTypes2 = {};

	-- Handle args or assign defaults.
	local iWaterPercent = args.iWaterPercent or 55;
	local iRegionWidth = args.iRegionWidth; -- Mandatory Parameter, no default
	local iRegionHeight = args.iRegionHeight; -- Mandatory Parameter, no default
	local iRegionWestX = args.iRegionWestX; -- Mandatory Parameter, no default
	local iRegionSouthY = args.iRegionSouthY; -- Mandatory Parameter, no default
	local iRegionGrain = args.iRegionGrain or 1;
	local iRegionPlotFlags = args.iRegionPlotFlags or g_iFlags;
	local iRegionTerrainFlags = g_iFlags; -- Removed from args list.
	local iRegionFracXExp = args.iRegionFracXExp or 6;
	local iRegionFracYExp = args.iRegionFracYExp or 5;
	local iRiftGrain = args.iRiftGrain or -1;
	local bShift = args.bShift or true;
	
	--print("Received Region Data");
	--print(iRegionWidth, iRegionHeight, iRegionWestX, iRegionSouthY, iRegionGrain);
	--print("- - -");
	
	--print("Filled regional table.");
	-- Loop through the region's plots
	for x = 0, iRegionWidth - 1, 1 do
		for y = 0, iRegionHeight - 1, 1 do
			local i = y * iRegionWidth + x + 1; -- Lua arrays start at 1.
			plotTypes2[i] =g_PLOT_TYPE_OCEAN;
		end
	end

	-- Init the land/water fractal
	local regionContinentsFrac;
	if(iRiftGrain > 0 and iRiftGrain < 4) then
		local riftsFrac = Fractal.Create(g_iW, g_iH, rift_grain, {}, iRegionFracXExp, iRegionFracYExp);
		regionContinentsFrac = Fractal.CreateRifts(g_iW, g_iH, iRegionGrain, iRegionPlotFlags, riftsFrac, iRegionFracXExp, iRegionFracYExp);
	else
		regionContinentsFrac = Fractal.Create(g_iW, g_iH, iRegionGrain, iRegionPlotFlags, iRegionFracXExp, iRegionFracYExp);	
	end
	--print("Initialized main fractal");
	local iWaterThreshold = regionContinentsFrac:GetHeight(iWaterPercent);

	-- Loop through the region's plots
	for x = 0, iRegionWidth - 1, 1 do
		for y = 0, iRegionHeight - 1, 1 do
			local i = y * iRegionWidth + x + 1; 
			local val = regionContinentsFrac:GetHeight(x,y);
			if val <= iWaterThreshold or Adjacent(i) == true then
				--do nothing
			else
				plotTypes2[i] = g_PLOT_TYPE_LAND;
			end
		end
	end

	if bShift then
		ShiftPlotTypes(plotTypes);
	end

	print("Shifted Plots - Width: ", iRegionWidth, "Height: ", iRegionHeight);

	-- Apply the region's plots to the global plot array.
	for x = 0, iRegionWidth - 1, 1 do
		local wholeworldX = x + iRegionWestX;
		for y = 0, iRegionHeight - 1, 1 do
			local index = y * iRegionWidth + x + 1
			if plotTypes2[index] ~= g_PLOT_TYPE_OCEAN then
				local wholeworldY = y + iRegionSouthY;
				local i = wholeworldY * g_iW + wholeworldX + 1
				plotTypes[i] = plotTypes2[index];
			end
		end
	end
	--print("Generated Plot Types");

	return plotTypes;
end

-------------------------------------------------------------------------------------------
function Adjacent(index)
	aIslands = islands;
	index = index -1;

	if(aIslands == nil) then
		return false;
	end
	
	if(index < 0) then
		return false
	end

	local plot = Map.GetPlotByIndex(index);
	if(aIslands[index] ~= nil and aIslands[index] == g_PLOT_TYPE_LAND) then
		return true;
	end

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
		if(adjacentPlot ~= nil) then
			local newIndex = adjacentPlot:GetIndex();
			if(aIslands  ~= nil and aIslands[newIndex] == g_PLOT_TYPE_LAND) then
				return true;
			end
		end
	end

	return false;
end

-------------------------------------------------------------------------------------------
function MarkCoastalLowlands()

	print("Map Generation - Marking Coastal Lowlands");

	local numDesiredCoastalLowlandsPercentage = GlobalParameters.CLIMATE_CHANGE_PERCENT_COASTAL_LOWLANDS or 35;
	numDesiredCoastalLowlandsPercentage = math.ceil(numDesiredCoastalLowlandsPercentage * 1.5); 

	scoredTiles = ScoreCoastalLowlandTiles();
	tilesToMark = math.floor((#scoredTiles * numDesiredCoastalLowlandsPercentage) / 100);
	
	if tilesToMark > 0 then
        table.sort (scoredTiles, function(a, b) return a.Score > b.Score; end);
		for tileIdx = 1, tilesToMark, 1 do
			local iElevation = 2;
			if (tileIdx <= tilesToMark / 3) then
				iElevation = 0;
			elseif (tileIdx <= (tilesToMark * 2) / 3) then
				iElevation = 1;
			end
			TerrainBuilder.AddCoastalLowland(scoredTiles[tileIdx].MapIndex, iElevation);
		end
		print(tostring(tilesToMark).." Coastal Lowland tiles added");
		print("  " .. tostring(GlobalParameters.CLIMATE_CHANGE_PERCENT_COASTAL_LOWLANDS) .. "% of eligible coastal tiles");
	end
end
-------------------------------------------------------------------------------------------
function IsValidCoastalLowland(plot)
	if (plot:IsCoastalLand() == true or GetNumberAdjacentLakes(plot:GetX(), plot:GetY()) > 0) then
		if (not plot:IsHills()) then
			if (not plot:IsMountain()) then
				if (not plot:IsNaturalWonder()) then
					if (not plot:IsLake()) then
						return true;
					end
				end
			end
		end
	end
	return false;
end
-------------------------------------------------------------------------------------------
function ScoreCoastalLowlandTiles()
	
	aaScoredTiles = {};
	local iW, iH = Map.GetGridSize();
	for i = 0, (iW * iH) - 1, 1 do
		plot = Map.GetPlotByIndex(i);
		if (plot) then
			if (IsValidCoastalLowland(plot)) then
				local featureType = plot:GetFeatureType();

				local iScore = 0;

			    -- An adjacent volcano is also bad news
				if (GetNumberAdjacentVolcanoes(plot:GetX(), plot:GetY()) > 0) then
					iScore = 0;

				-- Floodplains are already dangerous, don't include them here
				elseif (featureType == g_FEATURE_FLOODPLAINS or featureType == g_FEATURE_FLOODPLAINS_GRASSLAND or featureType == g_FEATURE_FLOODPLAINS_PLAINS) then
					iScore = 0;

				-- All other tiles are chosen based on the weightings in this section:
				else
					-- Start with a mid-range base Score
					iScore = 500;				
					
					if (GetNumberAdjacentLakes(plot:GetX(), plot:GetY()) > 0 ) then
						iScore = iScore + 250;
					end
					
					-- Marsh is top-priority
					if (featureType == g_FEATURE_MARSH) then
						iScore = 500;
					end
					
					
					-- Tiles near a River are prioritized heavily (to balance with the up-to-six occurrences of the factors below)
					if (plot:IsRiver()) then
						iScore = iScore + 200;
					end

					for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
						local adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction);
						if (adjacentPlot ~= nil) then
							if (adjacentPlot:IsNaturalWonder()) then
								iScore = 0;
								break;
							end
							
							
							local adjFeatureType = adjacentPlot:GetFeatureType();

							-- Tiles near Marsh or Floodplain are prioritized
							if (adjFeatureType == g_FEATURE_MARSH or adjFeatureType == g_FEATURE_FLOODPLAINS or adjFeatureType == g_FEATURE_FLOODPLAINS_GRASSLAND or adjFeatureType == g_FEATURE_FLOODPLAINS_PLAINS) then
								iScore = iScore + 50;
							end

							-- Tiles near Hills
							if (adjacentPlot:IsHills()) then
								iScore = iScore - 25;
							end

							-- Tiles near Mountains
							if (adjacentPlot:IsMountain()) then
								iScore = iScore - 50;
							end
							
							-- Tiles with more adjacent Coast tiles are prioritized
							if (adjacentPlot:IsWater()) then
								iScore = iScore + 50;
							end
						end
					end
				end
				
				if (iScore > 0) then
					row = {};
					row.MapIndex = i;
					row.Score = iScore;
					table.insert(aaScoredTiles, row);
				end
			end
		end
	end

	return aaScoredTiles;
end

function AddTerrainFromContinents(plotTypes, terrainTypes, world_age, iW, iH, iContinentBoundaryPlots)

	local iMountainPercentByDistance:table = {42, 24, 6}; 
	local iHillPercentByDistance:table = {50, 40, 30}; 
	local aLonelyMountainIndices:table = {};
	local iVolcanoesPlaced = 0;

	-- Compute target number of volcanoes
	local iTotalLandPlots = 0;
	for iX = 0, iW - 1 do
		for iY = 0, iH - 1 do
			local index = (iY * iW) + iX;
			if (plotTypes[index] ~= g_PLOT_TYPE_OCEAN) then
				iTotalLandPlots = iTotalLandPlots + 1;
			end
		end
	end
	
	local iDivisor = 5;
	if (world_age < 10) then
		iDivisor = 5 - math.floor(world_age / 2); 
	end
	
	local iDesiredVolcanoes = iTotalLandPlots / (iDivisor * 50) * 4;
	print ("Desired Volcanoes: " .. iDesiredVolcanoes);

	-- 2/3rds of Earth's volcanoes are near continent boundaries
	print ("Continent Boundary Plots: " .. iContinentBoundaryPlots);
	local iDesiredNearBoundaries = iDesiredVolcanoes * 2 / 3;

	if (iDesiredNearBoundaries > 0) then
		local iBoundaryPlotsPerVolcano = iContinentBoundaryPlots / iDesiredNearBoundaries;

		-- Not more than 1 per 16 tiles
		if (iBoundaryPlotsPerVolcano < 6) then
			iBoundaryPlotsPerVolcano = 6;
		end
		print ("Boundary Plots Per Volcano: " .. iBoundaryPlotsPerVolcano);

		for iX = 0, iW - 1 do
			for iY = 0, iH - 1 do
				local index = (iY * iW) + iX;
				if (plotTypes[index] ~= g_PLOT_TYPE_OCEAN) then
					local pPlot = Map.GetPlotByIndex(index);
					local iPlotsFromBoundary = -1;
					local bVolcanoHere = false;
					if (Map.FindSecondContinent(pPlot, 1)) then
						if (TerrainBuilder.GetRandomNumber(iBoundaryPlotsPerVolcano *.7, "Volcano on boundary") == 1) then
							bVolcanoHere = true;
						end
						iPlotsFromBoundary = 1;
					elseif(Map.FindSecondContinent(pPlot, 2)) then
						if (TerrainBuilder.GetRandomNumber(iBoundaryPlotsPerVolcano, "Volcano 1 from boundary") == 1) then
							bVolcanoHere = true;
						end
						iPlotsFromBoundary = 2;
					elseif(Map.FindSecondContinent(pPlot, 3)) then
						if (TerrainBuilder.GetRandomNumber(iBoundaryPlotsPerVolcano * 1.5, "Volcano 2 from boundary") == 1) then
							bVolcanoHere = true;
						end
						iPlotsFromBoundary = 3;

					elseif (plotTypes[index] == g_PLOT_TYPE_MOUNTAIN) then
						if (GetNumberAdjacentMountains() == 0) then
							table.insert(aLonelyMountainIndices, index);
						end
					end

					if (bVolcanoHere) then
						TerrainBuilder.SetTerrainType(pPlot, ConvertToMountain(terrainTypes[index]));
						TerrainBuilder.SetFeatureType(pPlot, g_FEATURE_VOLCANO);
						print ("Volcano Placed at (x, y): " .. iX .. ", " .. iY);
						iVolcanoesPlaced = iVolcanoesPlaced + 1;

					elseif (iPlotsFromBoundary > 0)	then	
						local iMountainChance = iMountainPercentByDistance[iPlotsFromBoundary];
						if (GetNumberAdjacentVolcanoes(iX, iY) > 0) then
							iMountainChance = iMountainChance / 2;
						end						
						-- Mountain?
						if (TerrainBuilder.GetRandomNumber(100, "Mountain near boundary") < iMountainChance) then
							TerrainBuilder.SetTerrainType(pPlot, ConvertToMountain(terrainTypes[index]));

						-- Hills?
						elseif (TerrainBuilder.GetRandomNumber(100, "Hill near boundary") < iHillPercentByDistance[iPlotsFromBoundary]) then
							TerrainBuilder.SetTerrainType(pPlot, ConvertToHills(terrainTypes[index]));
						end
					end
				end
			end
		end
		print ("Continent Edge Volcanoes Placed: " .. iVolcanoesPlaced);
	end

	if ((iDesiredVolcanoes - iVolcanoesPlaced) > 0 and #aLonelyMountainIndices > 0) then
		local iChance = #aLonelyMountainIndices / iDesiredVolcanoes;
		aShuffledIndices =  GetShuffledCopyOfTable(aLonelyMountainIndices);
		for i, index in ipairs(aShuffledIndices) do
			local pPlot = Map.GetPlotByIndex(index);
			TerrainBuilder.SetFeatureType(pPlot, g_FEATURE_VOLCANO);
			print ("Volcano Placed at (x, y): " .. pPlot:GetX() .. ", " .. pPlot:GetY());
			iVolcanoesPlaced = iVolcanoesPlaced + 1;
			if (iVolcanoesPlaced >= iDesiredVolcanoes) then
				break
			end
		end
	end

	print ("Total Volcanoes Placed: " .. iVolcanoesPlaced);
end