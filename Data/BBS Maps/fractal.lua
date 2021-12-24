------------------------------------------------------------------------------
--	FILE:	 Fractal.lua
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
local world_age_new = 5;
local world_age_normal = 3;
local world_age_old = 2;

-------------------------------------------------------------------------------
function BBS_Assign(args)
	print("BBS_Assign: Injecting Spawn Placement")
	local start_plot_database = {};

	start_plot_database = BBS_AssignStartingPlots.Create(args)

	return start_plot_database
end
-------------------------------------------------------------------------------
function GenerateMap()
	print("Generating Fractal Map");
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

	plotTypes = GeneratePlotTypes(world_age);
	local BBS_temp = false;
	if (GameConfiguration.GetValue("BBStemp") ~= nil) then 
		if (GameConfiguration.GetValue("BBStemp") == true) then
			BBS_temp = true;
			print ("BBS Temperature: On");
			terrainTypes = BBS_GenerateTerrainTypes(plotTypes, g_iW, g_iH, g_iFlags, false, temperature);
			else
			BBS_temp = false;
			terrainTypes = GenerateTerrainTypes(plotTypes, g_iW, g_iH, g_iFlags, false, temperature);
		end
		else
		BBS_temp = false;
		terrainTypes = GenerateTerrainTypes(plotTypes, g_iW, g_iH, g_iFlags, false, temperature);
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
		MIN_MINOR_CIV_FERTILITY = 20, 
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
	
	local sea_level_low = 59;
	local sea_level_normal = 62;
	local sea_level_high = 68;
	local extra_mountains = 0;
	local adjust_plates = 1.0;
	local shift_plot_types = true;
	local hills_ridge_flags = g_iFlags;
	local peaks_ridge_flags = g_iFlags;
	local has_center_rift = false;

	--	local sea_level
    local sea_level = MapConfiguration.GetValue("sea_level");
	local water_percent;
	if sea_level == 1 then -- Low Sea Level
		water_percent = sea_level_low
	elseif sea_level == 2 then -- Normal Sea Level
		water_percent =sea_level_normal
	elseif sea_level == 3 then -- High Sea Level
		water_percent = sea_level_high
	else
		water_percent = TerrainBuilder.GetRandomNumber(sea_level_high- sea_level_low, "Random Sea Level - Lua") + sea_level_low  + 1 ;
	end

	-- Set values for hills and mountains according to World Age chosen by user.
	local adjustment = world_age;
	if world_age <= world_age_old  then -- 5 Billion Years
		adjust_plates = adjust_plates * 0.75;
	elseif world_age >= world_age_new then -- 3 Billion Years
		adjust_plates = adjust_plates * 1.5;
	else -- 4 Billion Years
	end

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
	local iWaterThreshold = g_continentsFrac:GetHeight(water_percent);
	for x = 0, g_iW - 1 do
		for y = 0, g_iH - 1 do
			local i = y * g_iW + x;
			local val = g_continentsFrac:GetHeight(x, y);
			local pPlot = Map.GetPlotByIndex(i);
			if(val <= iWaterThreshold) then
				plotTypes[i] = g_PLOT_TYPE_OCEAN;
				TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_OCEAN);  -- temporary setting so can calculate areas
			else
				plotTypes[i] = g_PLOT_TYPE_LAND;
				TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_DESERT);  -- temporary setting so can calculate areas
			end
		end
	end

	ShiftPlotTypes(plotTypes);
	AreaBuilder.Recalculate();

	local args = {};
	args.world_age = world_age;
	args.iW = g_iW;
	args.iH = g_iH
	args.iFlags = g_iFlags;
	args.tectonic_islands = true;
	args.blendRidge = 10;
	args.blendFract = 1;
	args.extra_mountains = 5;
	mountainRatio = 11 + world_age * 2;
		if (MapConfiguration.GetValue("BBSRidge") == 1) then
		mountainRatio = 12 + world_age * 2;
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
	
	local args = {rainfall = rainfall}
	featuregen = FeatureGenerator.Create(args);
	featuregen:AddFeatures(true, true);  --second parameter is whether or not rivers start inland);
end

function AddFeaturesFromContinents()
	print("Adding Features from Continents");

	featuregen:AddFeaturesFromContinents();
end
