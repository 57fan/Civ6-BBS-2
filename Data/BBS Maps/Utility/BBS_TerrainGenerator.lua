------------------------------------------------------------------------------
--	FILE:	 BBS_TerrainGenerator.lua -- 1.42
--	AUTHOR:  D. / Jack The Narrator, Wazabaza, Codenaught
--	PURPOSE: Shared map script to assign Civ 6 terrain types to a map
------------------------------------------------------------------------------
--	Copyright (c) 2014-6 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------

include "TerrainGenerator"

-------------------------------------------------------------------------------

function BBS_GenerateTerrainTypes(plotTypes, iW, iH, iFlags, bNoCoastalMountains, temperature, notExpandCoasts, iDesertPercentArg, iPlainsPercentArg, fSnowLatitudeArg, fTundraLatitudeArg, fGrassLatitudeArg, fDesertBottomLatitudeArg, fDesertTopLatitudeArg)
	print("Generating Terrain Types");
	local terrainTypes = {};

	-- Sea Level option affects only plot generation.
	-- World Age option affects plot generation and geothermal/volcanic features
	-- Temperature map options affect only terrain generation.
	-- Rainfall map options affect only feature generation.
	if(temperature == nil) then
		temperature = 2;
	end

	local coldShift = 0.0;
	local temperature_shift = 0.1;
	local desert_shift = 16;
	local plains_shift = 6;
	
	-- Set terrain bands args.
	local iDesertShift = iDesertPercentArg or 0;
	local iPlainsShift = iPlainsPercentArg or 0;
	local fSnowShift = fSnowLatitudeArg or 0.0;
	local fTundraShift = fTundraLatitudeArg or 0.0;
	local fGrassShift = fGrassLatitudeArg or 0.0;
	local fDesertShiftTop = fDesertBottomLatitudeArg or 0.0;
	local fDesertShiftBottom = fDesertTopLatitudeArg or 0.0;
	
	-- Set terrain bands.
	local iDesertPercent = 16; -- Was 30% then 26% while making desert more centered put 18% after Mali's rework
	local iPlainsPercent = 50; 
	local fSnowLatitude  = 0.86 + coldShift; -- was 0.84 in 1.4.1 put back 0.86
	local fTundraLatitude = 0.63 + coldShift; -- was 0.65 put 0.63
	local fGrassLatitude = 0.1; 
	local fDesertBottomLatitude = 0.4; 
	local fDesertTopLatitude = 0.6; -- was 0.56 should be 0.6 to make the map symmetrical

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
	local grain_amount = 3;
	local iDesertTop;
	local iDesertBottom;																
	local iPlainsTop;
	local iPlainsBottom;

	deserts = Fractal.Create(iW, iH, 
									grain_amount, iFlags, 
									fracXExp, fracYExp);
									
	iDesertTop = deserts:GetHeight(iDesertTopPercent);
	iDesertBottom = deserts:GetHeight(iDesertBottomPercent);

	plains = Fractal.Create(iW, iH, 
									grain_amount, iFlags, 
									fracXExp, fracYExp);
																		
	iPlainsTop = plains:GetHeight(iPlainsTopPercent);
	iPlainsBottom = plains:GetHeight(iPlainsBottomPercent);

	local variationFrac = Fractal.Create(iW, iH,  
									grain_amount, iFlags, 
									fracXExp, fracYExp);
	
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

	local bNotExpandCoasts = notExpandCoasts or false;

	if bNotExpandCoasts == true then
		return terrainTypes;
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
					if (IsAdjacentToShallowWater(terrainTypes, iX, iY) and TerrainBuilder.GetRandomNumber(4, "add shallows") == 0) then
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