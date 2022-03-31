------------------------------------------------------------------------------
--	FILE:	 DW_CoastalLowlands.lua
--	AUTHOR:  EvilVictor (Seven05)
--	PURPOSE: Map Utility Script
------------------------------------------------------------------------------
--	Copyright (c) 2017 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------

include "BBS_TerrainGenerator"

-- Marks Coastal Lowlands for Civ VI XP2
--    These are areas that are susceptible to coastal flooding from XP2 environmental effects

function IsValidCoastalLowland(plot)
	if (plot:IsCoastalLand() == true) then
		if (not plot:IsHills()) then
			if (not plot:IsMountain()) then
				if (not plot:IsNaturalWonder()) then
					return true;
				end
			end
		end
	end
	return false;
end

function DW_ScoreCoastalLowlandTiles()
	
	aaScoredTiles = {};
	local iW, iH = Map.GetGridSize();
	for i = 0, (iW * iH) - 1, 1 do
		plot = Map.GetPlotByIndex(i);
		if (plot) then
			if (IsValidCoastalLowland(plot)) then
				local featureType = plot:GetFeatureType();

				local iScore = 0;

			    -- An adjacent volcano or lake is bad news
				-- Marsh is top-priority
				-- Floodplains are already dangerous
				if (GetNumberAdjacentVolcanoes(plot:GetX(), plot:GetY()) > 0) then
					iScore = 0;
				elseif (GetNumberAdjacentLakes(plot:GetX(), plot:GetY()) > 0) then
					iScore = 0;
				elseif (featureType == g_FEATURE_MARSH) then
					iScore = 1000;
				elseif (featureType == g_FEATURE_FLOODPLAINS or featureType == g_FEATURE_FLOODPLAINS_GRASSLAND or featureType == g_FEATURE_FLOODPLAINS_PLAINS) then
					iScore = 0;
				else
					-- Start with a mid-range base Score
					iScore = 500;

					-- Tiles near a River are prioritized heavily
					if (plot:IsRiver()) then
						iScore = iScore + 200;
					end

					local iRange = 2;
					
					for dx = -iRange, iRange do
						for dy = -iRange, iRange do

							local iX = plot:GetX();
							local iY = plot:GetY();
							local adjacentPlot = Map.GetPlotXY(iX, iY, dx, dy, iRange);
							
							if (adjacentPlot ~= nil) then
							
								-- 705: Don't mess with natural wonders at all
								if (adjacentPlot:IsNaturalWonder()) then
									iScore = -1000;
								end
								
								local adjFeatureType = adjacentPlot:GetFeatureType();

								-- Tiles near Marsh or Floodplain are prioritized
								if (adjFeatureType == g_FEATURE_MARSH or adjFeatureType == g_FEATURE_FLOODPLAINS or adjFeatureType == g_FEATURE_FLOODPLAINS_GRASSLAND or adjFeatureType == g_FEATURE_FLOODPLAINS_PLAINS) then
									iScore = iScore + 20;
								end
								
								if (adjacentPlot:IsRiver()) then
									iScore = iScore + 20;
								end

								-- Tiles near Hills or Mountains are deprioritized
								if (adjacentPlot:IsHills()) then
									iScore = iScore - 20;
								end
								
								if (adjacentPlot:IsMountain()) then
									iScore = iScore - 40;
								end

								-- Tiles with more adjacent Coast tiles are prioritized
								if (adjacentPlot:IsWater()) then
									iScore = iScore + 25;
								end
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

function DW_MarkCoastalLowlands()

	print("Map Generation - Marking Coastal Lowlands");

	local numDesiredCoastalLowlandsPercentage = GlobalParameters.CLIMATE_CHANGE_PERCENT_COASTAL_LOWLANDS or 35;
	numDesiredCoastalLowlandsPercentage = math.min(numDesiredCoastalLowlandsPercentage + 15,100);
	
	scoredTiles = DW_ScoreCoastalLowlandTiles();
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
		print("  " .. tostring(#scoredTiles) .. " eligible coastal tiles");
	end
end

function DW_MarkIslandCoastalLowlands()

	print("Map Generation - Marking Coastal Lowlands");

	local numDesiredCoastalLowlandsPercentage = GlobalParameters.CLIMATE_CHANGE_PERCENT_COASTAL_LOWLANDS or 35;
	
	scoredTiles = DW_ScoreCoastalLowlandTiles();
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
		print("  " .. tostring(#scoredTiles) .. " eligible coastal tiles");
	end
end