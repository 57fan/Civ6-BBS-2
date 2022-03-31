------------------------------------------------------------------------------
--	FILE:	 DW_TerrainGenerator.lua
--	AUTHOR:  EvilVictor (Seven05), codenaught
--	PURPOSE: Map Utility Script
------------------------------------------------------------------------------
--	Copyright (c) 2014-6 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------

-------------------------------------------------------------------------------

function ConvertToMountain(type)

	local rtnValue = type;

	if (type == g_TERRAIN_TYPE_SNOW or type == g_TERRAIN_TYPE_SNOW_HILLS) then
		rtnValue = g_TERRAIN_TYPE_SNOW_MOUNTAIN;
	elseif (type == g_TERRAIN_TYPE_TUNDRA or type == g_TERRAIN_TYPE_TUNDRA_HILLS) then
		rtnValue = g_TERRAIN_TYPE_TUNDRA_MOUNTAIN;
	elseif (type == g_TERRAIN_TYPE_DESERT or type == g_TERRAIN_TYPE_DESERT_HILLS) then
		rtnValue = g_TERRAIN_TYPE_DESERT_MOUNTAIN;
	elseif (type == g_TERRAIN_TYPE_GRASS or type == g_TERRAIN_TYPE_GRASS_HILLS) then
		rtnValue = g_TERRAIN_TYPE_GRASS_MOUNTAIN;
	elseif (type == g_TERRAIN_TYPE_PLAINS or type == g_TERRAIN_TYPE_PLAINS_HILLS) then
		rtnValue = g_TERRAIN_TYPE_PLAINS_MOUNTAIN;
	end

	return rtnValue;
end

function ConvertToHills(type)

	local rtnValue = type;

	if (type == g_TERRAIN_TYPE_SNOW or type == g_TERRAIN_TYPE_SNOW_MOUNTAIN) then
		rtnValue = g_TERRAIN_TYPE_SNOW_HILLS;
	elseif (type == g_TERRAIN_TYPE_TUNDRA or type == g_TERRAIN_TYPE_TUNDRA_MOUNTAIN) then
		rtnValue = g_TERRAIN_TYPE_TUNDRA_HILLS;
	elseif (type == g_TERRAIN_TYPE_DESERT or type == g_TERRAIN_TYPE_DESERT_MOUNTAIN) then
		rtnValue = g_TERRAIN_TYPE_DESERT_HILLS;
	elseif (type == g_TERRAIN_TYPE_GRASS or type == g_TERRAIN_TYPE_GRASS_MOUNTAIN) then
		rtnValue = g_TERRAIN_TYPE_GRASS_HILLS;
	elseif (type == g_TERRAIN_TYPE_PLAINS or type == g_TERRAIN_TYPE_PLAINS_MOUNTAIN) then
		rtnValue = g_TERRAIN_TYPE_PLAINS_HILLS;
	end

	return rtnValue;
end

function ApplyBaseTerrain(plotTypes, terrainTypes, iW, iH)
	for i = 0, (iW * iH) - 1, 1 do
		pPlot = Map.GetPlotByIndex(i);
		if (plotTypes[i] == g_PLOT_TYPE_HILLS) then
			terrainTypes[i] = terrainTypes[i] + 1;
		end
		TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
	end
end

function GetContinentBoundaryPlotCount(iW, iH)

	local iContinentBoundaryPlots = 0;

	for i = 0, (iW * iH) - 1, 1 do
		pPlot = Map.GetPlotByIndex(i);
		if (Map.FindSecondContinent(pPlot, 3)) then
			iContinentBoundaryPlots = iContinentBoundaryPlots + 1;
		end
	end
	return iContinentBoundaryPlots;
end

function GenerateTerrainTypes(plotTypes, iW, iH, iFlags, bNoCoastalMountains, temperature, bonus_cold_shift)
	print("Generating Terrain Types");
	local terrainTypes = {};

	-- Sea Level and World Age map options affect only plot generation.
	-- World Age option affects plot generation and geothermal/volcanic features
	-- Temperature map options affect only terrain generation.
	-- Rainfall map options affect only feature generation.
	if(temperature == nil) then
		temperature = 2;
	end

	local coldShift = bonus_cold_shift or 0;
	local temperature_shift = 0.1;
	local desert_shift = 16;
	local plains_shift = 8;
	
	-- Set terrain bands.
	--local iDesertPercent = 30;
	--local iPlainsPercent = 50; 
	--local fSnowLatitude  = 0.75 + coldShift;
	--local fTundraLatitude = 0.62 + coldShift;
	--local fGrassLatitude = 0.1; 
	--local fDesertBottomLatitude = 0.2;
	--local fDesertTopLatitude = 0.5;

	-- Set terrain bands. -- codenaught's values
	local iDesertPercent = 30;
	local iPlainsPercent = 50; 
	local fSnowLatitude  = 0.88 + coldShift;
	local fTundraLatitude = 0.65 + coldShift;
	local fGrassLatitude = 0.1; 
	local fDesertBottomLatitude = 0.4;
	local fDesertTopLatitude = 0.54;

	-- Adjust user's Temperature selection.
	if temperature > 2.5 then -- World Temperature is Cool.
		iDesertPercent = iDesertPercent - desert_shift;
		fTundraLatitude = fTundraLatitude - (temperature_shift * 1.5);
		iPlainsPercent = iPlainsPercent + plains_shift;
		fDesertTopLatitude = fDesertTopLatitude - temperature_shift;
		fGrassLatitude = fGrassLatitude - (temperature_shift * 0.5);
	elseif temperature < 1.5 then -- World Temperature is Hot.
		iDesertPercent = iDesertPercent + desert_shift;
		fSnowLatitude  = fSnowLatitude + (temperature_shift * 0.5);
		fTundraLatitude = fTundraLatitude + temperature_shift;
		fDesertTopLatitude = fDesertTopLatitude + temperature_shift;
		fGrassLatitude = fGrassLatitude - (temperature_shift * 0.5);
		iPlainsPercent = iPlainsPercent + plains_shift;
	else -- Normal Temperature.
	end

	local iDesertTopPercent		= 100;
	local iDesertBottomPercent	= math.max(0, math.floor(100-iDesertPercent));
	local iPlainsTopPercent		= 100;
	local iPlainsBottomPercent	= math.max(0, math.floor(100-iPlainsPercent));

	
	-- Activate printout for debugging only
	print("-"); print("- Desert Percentage:", iDesertPercent);
	print("--- Latitude Readout ---");
	print("- All Grass End Latitude:", fGrassLatitude);
	print("- Desert Start Latitude:", fDesertBottomLatitude);
	print("- Desert End Latitude:", fDesertTopLatitude);
	print("- Tundra Start Latitude:", fTundraLatitude);
	print("- Snow Start Latitude:", fSnowLatitude);
	print("- - - - - - - - - - - - - -");

	local fracXExp = -1;
	local fracYExp = -1;
	local iDesertTop;
	local iDesertBottom;																
	local iPlainsTop;
	local iPlainsBottom;
	
	-- 705: Changing the grains, old default was 3 for everything now
	-- plains and variation are 4.
	-- Desert grain changes with temp setting, high temp will create more cohesive deserts.

	local grain_amount = 3;
	if temperature < 1.5 then -- World Temperature is Hot.
		grain_amount = 2;
	end

	deserts = Fractal.Create(iW, iH, grain_amount, iFlags, fracXExp, fracYExp);
	
	grain_amount = 4;
	plains = Fractal.Create(iW, iH, grain_amount, iFlags, fracXExp, fracYExp);
	local variationFrac = Fractal.Create(iW, iH, grain_amount, iFlags, fracXExp, fracYExp);

	iDesertTop = deserts:GetHeight(iDesertTopPercent);
	iDesertBottom = deserts:GetHeight(iDesertBottomPercent);

	iPlainsTop = plains:GetHeight(iPlainsTopPercent);
	iPlainsBottom = plains:GetHeight(iPlainsBottomPercent);
	
	for iX = 0, iW - 1 do
		for iY = 0, iH - 1 do
			local index = (iY * iW) + iX;
			if (plotTypes[index] == g_PLOT_TYPE_OCEAN) then
				if (IsAdjacentToLand(plotTypes, iX, iY)) then
					terrainTypes[index] = g_TERRAIN_TYPE_COAST;
				else
					terrainTypes[index] = g_TERRAIN_TYPE_OCEAN;
				end
			end
		end
	end
	
	if (bNoCoastalMountains == true) then
		plotTypes = RemoveCoastalMountains(plotTypes, terrainTypes);
	end

	for iX = 0, iW - 1 do
		for iY = 0, iH - 1 do
			local index = (iY * iW) + iX;
			local lat = GetLatitudeAtPlot(variationFrac, iX, iY);

			if (plotTypes[index] == g_PLOT_TYPE_MOUNTAIN) then
			    terrainTypes[index] = g_TERRAIN_TYPE_GRASS_MOUNTAIN;

				if(lat >= fSnowLatitude) then
					terrainTypes[index] = g_TERRAIN_TYPE_SNOW_MOUNTAIN;
				elseif(lat >= fTundraLatitude) then
					terrainTypes[index] = g_TERRAIN_TYPE_TUNDRA_MOUNTAIN;
				elseif (lat < fGrassLatitude) then
					terrainTypes[index] = g_TERRAIN_TYPE_GRASS_MOUNTAIN;
				else
					local desertVal = deserts:GetHeight(iX, iY);
					local plainsVal = plains:GetHeight(iX, iY);
					if ((desertVal >= iDesertBottom) and (desertVal <= iDesertTop) and (lat >= fDesertBottomLatitude) and (lat < fDesertTopLatitude)) then
						terrainTypes[index] = g_TERRAIN_TYPE_DESERT_MOUNTAIN;
					elseif ((plainsVal >= iPlainsBottom) and (plainsVal <= iPlainsTop)) then
						terrainTypes[index] = g_TERRAIN_TYPE_PLAINS_MOUNTAIN;
					end
				end

			elseif (plotTypes[index] ~= g_PLOT_TYPE_OCEAN) then
				terrainTypes[index] = g_TERRAIN_TYPE_GRASS;
				
				if(lat >= fSnowLatitude) then
					terrainTypes[index] = g_TERRAIN_TYPE_SNOW;
				elseif(lat >= fTundraLatitude) then
					terrainTypes[index] = g_TERRAIN_TYPE_TUNDRA;
				elseif (lat < fGrassLatitude) then
					terrainTypes[index] = g_TERRAIN_TYPE_GRASS;
				else
					local desertVal = deserts:GetHeight(iX, iY);
					local plainsVal = plains:GetHeight(iX, iY);
					if ((desertVal >= iDesertBottom) and (desertVal <= iDesertTop) and (lat >= fDesertBottomLatitude) and (lat < fDesertTopLatitude)) then
						terrainTypes[index] = g_TERRAIN_TYPE_DESERT;
					elseif ((plainsVal >= iPlainsBottom) and (plainsVal <= iPlainsTop)) then
						terrainTypes[index] = g_TERRAIN_TYPE_PLAINS;
					end
				end
			end
		end
	end

	print("Cleaning up grassland-desert borders");
	for iI = 0, 2 do
		local nearDesertPlots = {};
		for iX = 0, iW - 1 do
			for iY = 0, iH - 1 do
				local index = (iY * iW) + iX;
				if (terrainTypes[index] == g_TERRAIN_TYPE_GRASS) then
					-- Chance for each eligible plot to become an expansion is 1 / iExpansionDiceroll.
					-- Default is two passes at 1/4 chance per eligible plot on each pass.
					if (IsAdjacentToDesert(terrainTypes, iX, iY) and TerrainBuilder.GetRandomNumber(3, "add shallows") == 0) then
						table.insert(nearDesertPlots, index);
					end
				end
			end
		end
		for i, index in ipairs(nearDesertPlots) do
			terrainTypes[index] = g_TERRAIN_TYPE_PLAINS;
		end
	end

	print("Expanding coasts");
	for iI = 0, 2 do
		local shallowWaterPlots = {};
		for iX = 0, iW - 1 do
			for iY = 0, iH - 1 do
				local index = (iY * iW) + iX;
				if (terrainTypes[index] == g_TERRAIN_TYPE_OCEAN) then
					-- Chance for each eligible plot to become an expansion is 1 / iExpansionDiceroll.
					-- Default is two passes at 1/4 chance per eligible plot on each pass.
					if (IsAdjacentToShallowWater(terrainTypes, iX, iY) and TerrainBuilder.GetRandomNumber(5, "add shallows") == 0) then
						table.insert(shallowWaterPlots, index);
					end
				end
			end
		end
		for i, index in ipairs(shallowWaterPlots) do
			terrainTypes[index] = g_TERRAIN_TYPE_COAST;
		end
	end
	
	return terrainTypes; 
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
	local iDivisor = 8;
	if (world_age < 8) then
		iDivisor = 8 - world_age;  -- iDivisor should be 3 for new, 6 for old
	end
	local iDesiredVolcanoes = iTotalLandPlots / (iDivisor * 50);
	print ("Desired Volcanoes: " .. iDesiredVolcanoes);

	-- 2/3rds of Earth's volcanoes are near continent boundaries
	print ("Continent Boundary Plots: " .. iContinentBoundaryPlots);
	local iDesiredNearBoundaries = iDesiredVolcanoes * 2 / 3;

	if (iDesiredNearBoundaries > 0) then
		local iBoundaryPlotsPerVolcano = iContinentBoundaryPlots / iDesiredNearBoundaries;

		-- Not more than 1 per 16 tiles
		if (iBoundaryPlotsPerVolcano < 16) then
			iBoundaryPlotsPerVolcano = 16;
		end
		print ("Boundary Plots Per Volcano: " .. iBoundaryPlotsPerVolcano);

		for iX = 0, iW - 1 do
			for iY = 0, iH - 1 do
				local index = (iY * iW) + iX;
				if (plotTypes[index] ~= g_PLOT_TYPE_OCEAN) then
					local pPlot = Map.GetPlotByIndex(index);
					local iPlotsFromBoundary = -1;
					local bVolcanoHere = false;
					-- 705: For now, block volcanoes being created on desert tiles
					if (GetNumberAdjacentVolcanoes(iX, iY) == 0 and GetNumberAdjacentMountains() < 4) then
						if (terrainTypes[index] ~= g_TERRAIN_TYPE_DESERT and terrainTypes[index] ~= g_TERRAIN_TYPE_DESERT_HILLS and terrainTypes[index] ~= g_TERRAIN_TYPE_DESERT_MOUNTAINS) then
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

						-- 705: Reduce boundary mountains in deserts
						if (terrainTypes[index] == g_TERRAIN_TYPE_DESERT or terrainTypes[index] == g_TERRAIN_TYPE_DESERT_HILLS) then
							iMountainChance = math.floor(iMountainChance / 3);
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
			local iX = pPlot:GetX();
			local iY = pPlot:GetY();
			
			if (GetNumberAdjacentVolcanoes(iX, iY) == 0) then
				TerrainBuilder.SetFeatureType(pPlot, g_FEATURE_VOLCANO);
				print ("Lonely Volcano Placed at (x, y): " .. iX .. ", " .. iY);
				iVolcanoesPlaced = iVolcanoesPlaced + 1;
				if (iVolcanoesPlaced >= iDesiredVolcanoes) then
					break
				end
			end
		end
	end

	print ("Total Volcanoes Placed: " .. iVolcanoesPlaced);
end

------------------------------------------------------------------------------
function GetNumberAdjacentVolcanoes(iX, iY)
	
	local iVolcanoCount = 0;
	
	-- 705: Expand the search range from adjacent to 2 tiles to spread the
	-- volcanoes out more.
	local iVolcano = 2;
	
	for dx = -iVolcano, iVolcano do
		for dy = -iVolcano,iVolcano do
			local adjacentPlot = Map.GetPlotXY(iX, iY, dx, dy, iVolcano);
			if (adjacentPlot ~= nil) then
				featureType = adjacentPlot:GetFeatureType();
				if (featureType == g_FEATURE_VOLCANO) then
					iVolcanoCount = iVolcanoCount + 1;
				end
			end
		end
	end 

--	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
--		local adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
--		if (adjacentPlot ~= nil) then
--			terrainType = adjacentPlot:GetTerrainType();
--			if (terrainType == g_TERRAIN_TYPE_DESERT_VOLCANO or
--				terrainType == g_TERRAIN_TYPE_VOLCANO) then
--				iVolcanoCount = iVolcanoCount + 1;
--			end
--		end
--	end

	return iVolcanoCount;
end

------------------------------------------------------------------------------
function GetNumberAdjacentMountains(iX, iY)
	
	local iMountainCount = 0;

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
		if (adjacentPlot ~= nil) then
			terrainType = adjacentPlot:GetTerrainType();
			if (terrainType == g_TERRAIN_TYPE_DESERT_MOUNTAIN or
				terrainType == g_TERRAIN_TYPE_SNOW_MOUNTAIN or
				terrainType == g_TERRAIN_TYPE_TUNDRA_MOUNTAIN or
				terrainType == g_TERRAIN_TYPE_PLAINS_MOUNTAIN or
				terrainType == g_TERRAIN_TYPE_GRASSLAND_MOUNTAIN) then
				iMountainCount = iMountainCount + 1;
			end
		end
	end

	return iMountainCount;
end

------------------------------------------------------------------------------
function GetNumberAdjacentLakes(iX, iY)
	
	local iLakeCount = 0;

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
		if (adjacentPlot ~= nil and adjacentPlot:IsLake() == true) then
				iLakeCount = iLakeCount + 1;
		end
	end

	return iLakeCount;
end