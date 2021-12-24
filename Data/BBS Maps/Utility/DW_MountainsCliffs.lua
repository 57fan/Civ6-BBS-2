------------------------------------------------------------------------------
--	FILE:	 DW_MountainsCliffs.lua
--	AUTHOR:  EvilVictor (Seven05)
--	PURPOSE: Map Utility Script
------------------------------------------------------------------------------

include "MapEnums.lua"

-------------------------------------------------------------------------------------------
function ApplyTectonics(args, plotTypes)
	local args = args or {};
	local adjustment = args.world_age or 2; -- Default to 4 Billion Years old.
	--
	--
	local extra_mountains = args.extra_mountains or 0;
	local grain_amount = args.grain_amount or 4;
	local adjust_plates = args.adjust_plates or 2.0;
	local shift_plot_types = args.shift_plot_types or false; -- Default to false for tectonics pass. Land/sea already generated.
	local tectonic_islands = args.tectonic_islands or false;
	local iFlags = args.iFlags or {};
	local hills_ridge_flags = args.hills_ridge_flags or iFlags;
	local peaks_ridge_flags = args.peaks_ridge_flags or iFlags;
	local fracXExp = args.fracXExp or -1;
	local fracYExp = args.fracYExp or -1;
    local blendRidge = args.blendRidge or 5;
	local blendFract = args.blendFract or 5;
	
	if adjustment < 3 then
		adjust_plates = adjust_plates * 0.75;
	elseif adjustment > 3 then 
		adjust_plates = adjust_plates * 1.5;
	end
	--
	-- Set values for hills and mountains according to World Age chosen by user.
	-- Apply adjustment to hills and peaks settings.
	local hillsBottom1 = 28 - adjustment;
	local hillsTop1 = 28 + adjustment;
	local hillsBottom2 = 72 - adjustment;
	local hillsTop2 = 72 + adjustment;
	local hillsClumps = 1 + adjustment;
	local hillsNearMountains = 91 - (adjustment * 2) - extra_mountains;
	local mountains = 97 - adjustment - extra_mountains;

	local numPlates = 9;
	-- Add in any plate count modifications passed in from the map script.
	numPlates = numPlates * adjust_plates;

	-- Generate fractals to govern hills and mountains
	hillsFrac = Fractal.Create(args.iW, args.iH, grain_amount, iFlags, fracXExp, fracYExp);
	mountainsFrac = Fractal.Create(args.iW, args.iH, grain_amount, iFlags, fracXExp, fracYExp);

	-- Use Brian's tectonics method to weave ridgelines in to the fractals.
	hillsFrac:BuildRidges(numPlates, iFlags, blendRidge, blendFract);
	mountainsFrac:BuildRidges(numPlates, peaks_ridge_flags, blendRidge, blendFract);

	-- Get height values for plot types
	local iHillsBottom1 = hillsFrac:GetHeight(hillsBottom1);
	local iHillsTop1 = hillsFrac:GetHeight(hillsTop1);
	local iHillsBottom2 = hillsFrac:GetHeight(hillsBottom2);
	local iHillsTop2 = hillsFrac:GetHeight(hillsTop2);
	local iHillsClumps = mountainsFrac:GetHeight(hillsClumps);
	local iHillsNearMountains = mountainsFrac:GetHeight(hillsNearMountains);
	local iMountainThreshold = mountainsFrac:GetHeight(mountains);
	local iPassThreshold = hillsFrac:GetHeight(hillsNearMountains);

	-- Get height values for tectonic islands
	local iMountain100 = mountainsFrac:GetHeight(100);
	local iMountain99 = mountainsFrac:GetHeight(99);
	local iMountain97 = mountainsFrac:GetHeight(97);
	local iMountain95 = mountainsFrac:GetHeight(95);

	--[[ Activate printout for debugging only.
	print("-"); print("--- Tectonics Readout ---");
	print("- World Age Setting:", world_age);
	print("- Mountain Threshold:", mountains);
	print("- Foot Hills Threshold:", hillsNearMountains);
	print("- Clumps of Hills %:", hillsClumps);
	print("- Loose Hills %:", 4 * adjustment);
	print("- Tectonic Plate Count:", numPlates);
	print("- Tectonic Islands?", tectonic_islands);
	print("- - - - - - - - - - - - - - - - -");
	]]--

	-- Main loop
	for x = 0, args.iW - 1 do
		for y = 0, args.iH - 1 do
			local mountainVal = mountainsFrac:GetHeight(x, y);
			local hillVal = hillsFrac:GetHeight(x, y);		
			local i = y * args.iW + x + 1;
	
			if (plotTypes[i] == g_PLOT_TYPE_OCEAN) then
				-- No hills or mountains here, but check for tectonic islands if that setting is active.
				if tectonic_islands then -- Build islands in oceans along tectonic ridge lines
					local mountainVal = mountainsFrac:GetHeight(x, y);
					if (mountainVal == iMountain100) then -- Isolated peak in the ocean
						plotTypes[i] = g_PLOT_TYPE_MOUNTAIN;
					elseif (mountainVal == iMountain99) then
						plotTypes[i] = g_PLOT_TYPE_HILLS;
					elseif (mountainVal == iMountain97) or (mountainVal == iMountain95) then
						plotTypes[i] = g_PLOT_TYPE_LAND;
					end
				end
			else
				if (mountainVal >= iMountainThreshold) then
					if (hillVal >= iPassThreshold) then -- Mountain Pass though the ridgeline
						plotTypes[i] = g_PLOT_TYPE_HILLS;
					else -- Mountain
						plotTypes[i] = g_PLOT_TYPE_MOUNTAIN;
					end
				elseif (mountainVal >= iHillsNearMountains) then
					plotTypes[i] = g_PLOT_TYPE_HILLS; -- Foot hills
				else
					if ((hillVal >= iHillsBottom1 and hillVal <= iHillsTop1) or (hillVal >= iHillsBottom2 and hillVal <= iHillsTop2)) then
						plotTypes[i] = g_PLOT_TYPE_HILLS;
					else
						plotTypes[i] = g_PLOT_TYPE_LAND;
					end
				end
			end
		end
	end
	
	--Remove Random Coastal Mountains
	-- 705: Added code to help reduce coastal hills too, a side-effect of using the
	-- multilayered fractal's water layer to generate coves & bays

	for x = 0, args.iW - 1 do
		for y = 0, args.iH - 1 do
			local i = y * args.iW + x + 1;
			if(plotTypes[i] == g_PLOT_TYPE_MOUNTAIN  and AdjacentToWater(x,y,plotTypes) == true) then
				local iRandomRemoval = TerrainBuilder.GetRandomNumber(10, "Coastal Mountain Removal");

				if(iRandomRemoval < 6 ) then
					plotTypes[i] = g_PLOT_TYPE_HILLS;
				else
					plotTypes[i] = g_PLOT_TYPE_MOUNTAIN;
				end
				
				--print("Removed. X: ", x, " Y: ", y);
			elseif(plotTypes[i] == g_PLOT_TYPE_HILLS  and AdjacentToWater(x,y,plotTypes) == true) then
				local iRandomRemoval = TerrainBuilder.GetRandomNumber(10, "Coastal Hill Removal");

				if(iRandomRemoval < 3 ) then
					plotTypes[i] = g_PLOT_TYPE_LAND;
				else
					plotTypes[i] = g_PLOT_TYPE_HILLS;
				end
				
				--print("Removed. X: ", x, " Y: ", y);
			end
		end
	end

	return plotTypes;
end
------------------------------------------------------------------------------
function AddLonelyMountains(plotTypes, mountainRatio)
	local iW, iH = Map.GetGridSize();
	local iTotalLandPlots= 0;
	local iTotalMountains = 0;

	for iX = 0, iW - 1 do
		for iY = 0, iH - 1 do
			local index = (iY * iW) + iX;

			if plotTypes[index] ~= g_PLOT_TYPE_OCEAN then
				iTotalLandPlots = iTotalLandPlots + 1;
			end

			if plotTypes[index] == g_PLOT_TYPE_MOUNTAIN then
				iTotalMountains = iTotalMountains + 1;
			end
		end
	end

	local iExistingRatio = iTotalLandPlots / iTotalMountains;
	print("-           Existing Ratio:", iExistingRatio);

	local iNewMountains = math.floor(iTotalLandPlots / mountainRatio) - iTotalMountains;
	if (iNewMountains >= 0) then
		print("-            New Mountains:", iNewMountains);
	else
		iNewMountains = 0;
	end

	local iI = 0;
	local iMountainsSet = 0;
	while iMountainsSet < iNewMountains  and iI < iTotalLandPlots do
		local iRandomY = TerrainBuilder.GetRandomNumber(iH, "Random Y");
		local iRandomX = TerrainBuilder.GetRandomNumber(iW, "Random X");
		local pPlot = Map.GetPlot(iRandomX,iRandomY);
		local index = (iRandomY * iW) + iRandomX;

		if(CanAddLonelyMountains(plotTypes, pPlot) ) then
			iMountainsSet = iMountainsSet + 1;
			plotTypes[index] = g_PLOT_TYPE_MOUNTAIN;
		end

		iI = iI + 1;
	end

	print("-            Mountains Set:", iMountainsSet);

	return plotTypes;
end

------------------------------------------------------------------------------
function CanAddLonelyMountains(plotTypes, plot)
	local iX = plot:GetX();
	local iY = plot:GetY();

	if(plotTypes[plot:GetIndex()] == g_PLOT_TYPE_OCEAN or plotTypes[plot:GetIndex()] == g_PLOT_TYPE_MOUNTAIN) then
		return false
	end

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);

		if (adjacentPlot ~= nil) then
			if (adjacentPlot:IsWater() or plotTypes[index] == g_PLOT_TYPE_OCEAN) then
				return false;
			end

			if (adjacentPlot:IsImpassable() or plotTypes[index] == g_PLOT_TYPE_MOUNTAIN) then
				return false;
			end
		else
			return false
		end
	end

	return true
end
------------------------------------------------------------------------------
function RemoveCoastalMountains(plotTypes, terrainTypes)
	local mountainsTransformed = 0;
	local iW, iH = Map.GetGridSize();
	
	for iX = 0, iW - 1 do
		for iY = 0, iH - 1 do
			local index = (iY * iW) + iX;

			if plotTypes[index] == g_PLOT_TYPE_MOUNTAIN then
				if IsAdjacentToShallowWater(terrainTypes, iX, iY) then
					plotTypes[index] = g_PLOT_TYPE_HILLS;
					mountainsTransformed = mountainsTransformed + 1;
					-- print(iX, " ", iY);
				end
			end
		end
	end

	AreaBuilder.Recalculate();
	local biggest_area = Areas.FindBiggestArea(false);
		
	-- Printout for debug use only
	print("- Mountains Transformed: ", mountainsTransformed);
	print("- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -");

	return plotTypes;
end
------------------------------------------------------------------------------
function AddCliffs(plotTypes, terrainTypes)
	local iW, iH = Map.GetGridSize();
	for iX = 0, iW - 1 do
		for iY = 0, iH - 1 do
			local index = (iY * iW) + iX;
			if (plotTypes[index] == g_PLOT_TYPE_HILLS and AdjacentToSaltWater(iX, iY) == true and IsAdjacentToIce(iX, iY) ==  false) then
				if(IsAdjacentToRiver(iX, iY) == false) then
					local pPlot = Map.GetPlotByIndex(index);
					local area = pPlot:GetArea();
					if (area:GetPlotCount() > 1 and not area:HasNoFlatCoast()) then
						SetCliff(terrainTypes, iX, iY);
					end
				end
			end
		end
	end
end
------------------------------------------------------------------------------
function SetCliff(terrainTypes, iX, iY)
	local iW, iH = Map.GetGridSize();
	local adjacentPlot;	
	local pPlot = Map.GetPlot(iX,iY);

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
		if (adjacentPlot ~= nil) then
			if (adjacentPlot:IsWater() == true) then
				if(direction == DirectionTypes.DIRECTION_NORTHEAST) then
					TerrainBuilder.SetNEOfCliff(adjacentPlot, true);
				elseif(direction == DirectionTypes.DIRECTION_EAST) then
					TerrainBuilder.SetWOfCliff(pPlot, true); 
				elseif(direction == DirectionTypes.DIRECTION_SOUTHEAST) then
					TerrainBuilder.SetNWOfCliff(pPlot, true); 
				elseif(direction == DirectionTypes.DIRECTION_SOUTHWEST) then
					TerrainBuilder.SetNEOfCliff(pPlot, true); 
				elseif(direction == DirectionTypes.DIRECTION_WEST) then
					TerrainBuilder.SetWOfCliff(adjacentPlot, true); 
				elseif(direction == DirectionTypes.DIRECTION_NORTHWEST) then
					TerrainBuilder.SetNWOfCliff(adjacentPlot, true); 
				end
			end
		end
	end
end