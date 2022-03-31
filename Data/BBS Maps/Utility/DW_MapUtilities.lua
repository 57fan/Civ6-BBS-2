-------------------------
-- Civ 6 Map Utilities --
-------------------------

include "MapEnums.lua"

-- Computes IsAdjacentToLand from plotTypes table (when Map not yet filled in)
function IsAdjacentToLand(plotTypes, iX, iY)
	local adjacentPlot;	
	local iW, iH = Map.GetGridSize();

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
		if (adjacentPlot ~= nil) then
	   		local i = adjacentPlot:GetY() * iW + adjacentPlot:GetX();
			if (plotTypes[i] ~= g_PLOT_TYPE_OCEAN) then
				return true;
			end
		end
	end
	return false;
end

------------------------------------------------------------------------------
function IsAdjacentToLandPlot(x, y)
	-- Computes IsAdjacentToLand from the plot
	local plot = Map.GetPlot(x, y);
	if plot ~= nil then
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local testPlot = Map.GetAdjacentPlot(x, y, direction);
			if testPlot ~= nil then
				if testPlot:IsWater() == false then -- Adjacent plot is land
					return true
				end
			end
		end
	end
	return false
end

-- Computes IsAdjacentToIce to check if there are any adjacent river plots
function IsAdjacentToRiver(iX, iY)
	local adjacentPlot;	
	local iW, iH = Map.GetGridSize();

	if (Map.GetPlot(x, y) == nil) then
			return false;
	end

	if (Map.GetPlot(x, y):IsRiver() == true) then
			return true;
	end

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
		if (adjacentPlot ~= nil) then
			if (adjacentPlot:IsRiver()) then
				return true;
			end
		end
	end
	return false;
end


-- Computes IsAdjacentToIce to check if there is ice
function IsAdjacentToIce(iX, iY)
	local adjacentPlot;	
	local iW, iH = Map.GetGridSize();

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
		if (adjacentPlot ~= nil) then
	   		local featureType = adjacentPlot:GetFeatureType();
			if (featureType ~= nil and featureType == g_FEATURE_ICE) then
				return true;
			end
		end
	end
	return false;
end

-- Computes IsAdjacentToShallowWater from terrainTypes table (when Map not yet filled in)
function IsAdjacentToShallowWater(terrainTypes, iX, iY)
	local adjacentPlot;	
	local iW, iH = Map.GetGridSize();

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
		if (adjacentPlot ~= nil) then
	   		local i = adjacentPlot:GetY() * iW + adjacentPlot:GetX();
			if (terrainTypes[i] == g_TERRAIN_TYPE_COAST) then
				return true;
			end
		end
	end
	return false;
end

-- Computes IsAdjacentToDesert from terrainTypes table
function IsAdjacentToDesert(terrainTypes, iX, iY)
	local adjacentPlot;	
	local iW, iH = Map.GetGridSize();

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
		if (adjacentPlot ~= nil) then
	   		local i = adjacentPlot:GetY() * iW + adjacentPlot:GetX();
			if (terrainTypes[i] == g_TERRAIN_TYPE_DESERT) then
				return true;
			end
		end
	end
	return false;
end

------------------------------------------------------------------------------
function AdjacentToWater(x, y, plotTypes)
	-- Checks a plot (x, y) to see if it is any type of land adjacent to at least one body of salt water.
	local plot = Map.GetPlot(x, y);	
	local iW, iH = Map.GetGridSize();
	local index = y * iW + x + 1;
	if plotTypes[index] ~= g_PLOT_TYPE_OCEAN then -- This plot is land, process it.
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local testPlot = Map.GetAdjacentPlot(x, y, direction);
			if testPlot ~= nil then
				local newIndex = testPlot:GetIndex();
				if plotTypes[newIndex] == g_PLOT_TYPE_OCEAN then --Ocean
					return true;
				end
			end
		end
	end
	-- Current plot is itself water, or else no salt water found among adjacent plots.
	return false
end


------------------------------------------------------------------------------
function AdjacentToSaltWater(x, y)
	-- Checks a plot (x, y) to see if it is any type of land adjacent to at least one body of salt water.
	local plot = Map.GetPlot(x, y);
	if not plot:IsWater() then -- This plot is land, process it.
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local testPlot = Map.GetAdjacentPlot(x, y, direction);
			if testPlot ~= nil then
				if testPlot:IsWater() then -- Adjacent plot is water! Check if ocean or lake.
					if testPlot:IsLake() == false then -- Adjacent plot is salt water!
						return true
					end
				end
			end
		end
	end
	-- Current plot is itself water, or else no salt water found among adjacent plots.
	return false
end

------------------------------------------------------------------------------
function AdjacentToMountain(x, y)
	-- Checks a plot (x, y) to see if it is any type of land adjacent to at least one mountain.
	local plot = Map.GetPlot(x, y);
	if not plot:IsWater() then -- This plot is land, process it.
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local testPlot = Map.GetAdjacentPlot(x, y, direction);
			if testPlot ~= nil then
				if testPlot:IsMountain() then -- Adjacent plot is mountain!
					return true
				end
			end
		end
	end
	-- Current plot is itself water, or else no salt water found among adjacent plots.
	return false
end

-------------------------------------------------------------------------------------------
-- FUNCTIONS TO SHIFT LANDMASSES (i.e. to better center them)
-------------------------------------------------------------------------------------------
function ShiftPlotTypes(plotTypes)

	local shift_x = 0; 
	local shift_y = 0;

	shift_x = DetermineXShift(plotTypes);	
	shift_y = DetermineYShift(plotTypes);	
	
	--print ("shift_x: ", shift_x);
	--print ("shift_y: ", shift_y);

	ShiftPlotTypesBy(plotTypes, shift_x, shift_y);
end
-------------------------------------------------------------------------------------------	
function ShiftPlotTypesBy(plotTypes, xshift, yshift)

	local g_iW, g_iH = Map.GetGridSize();

	if(xshift > 0 or yshift > 0) then
		local iWH = g_iW * g_iH;
		local buf = {};
		for i = 0, iWH do
			buf[i] = plotTypes[i];
		end
		
		for iDestY = 0, g_iH do
			for iDestX = 0, g_iW do
				local iDestI = g_iW * iDestY + iDestX;
				local iSourceX = (iDestX + xshift) % g_iW;
				local iSourceY = (iDestY + yshift) % g_iH;
				
				local iSourceI = g_iW * iSourceY + iSourceX

				plotTypes[iDestI] = buf[iSourceI]
			end
		end
	end
end
-------------------------------------------------------------------------------------------
function DetermineXShift(plotTypes)
	--[[ This function will align the most water-heavy vertical portion of the map with the 
	vertical map edge. This is a form of centering the landmasses, but it emphasizes the
	edge not the middle. If there are columns completely empty of land, these will tend to
	be chosen as the new map edge, but it is possible for a narrow column between two large 
	continents to be passed over in favor of the thinnest section of a continent, because
	the operation looks at a group of columns not just a single column, then picks the 
	center of the most water heavy group of columns to be the new vertical map edge. ]]--

	local g_iW, g_iH = Map.GetGridSize();

	-- First loop through the map columns and record land plots in each column.
	local land_totals = {};
	for x = 0, g_iW - 1 do
		local current_column = 0;
		for y = 0, g_iH - 1 do
			local i = y * g_iW + x + 1;
			if (plotTypes[i] ~= g_PLOT_TYPE_OCEAN) then
				current_column = current_column + 1;
			end
		end
		table.insert(land_totals, current_column);
	end
	
	-- Now evaluate column groups, each record applying to the center column of the group.
	local column_groups = {};
	-- Determine the group size in relation to map width.
	local group_radius = math.floor(g_iW / 10);
	-- Measure the groups.
	for column_index = 1, g_iW do
		local current_group_total = 0;
		for current_column = column_index - group_radius, column_index + group_radius do
			local current_index = current_column % g_iW;
			if current_index == 0 then -- Modulo of the last column will be zero; this repairs the issue.
				current_index = g_iW;
			end
			current_group_total = current_group_total + land_totals[current_index];
		end
		table.insert(column_groups, current_group_total);
	end
	
	-- Identify the group with the least amount of land in it.
	local best_value = g_iH * (2 * group_radius + 1); -- Set initial value to max possible.
	local best_group = 1; -- Set initial best group as current map edge.
	for column_index, group_land_plots in ipairs(column_groups) do
		if group_land_plots < best_value then
			best_value = group_land_plots;
			best_group = column_index;
		end
	end
	
	-- Determine X Shift
	local x_shift = best_group - 1;
	return x_shift;
end
-------------------------------------------------------------------------------------------
function DetermineYShift(plotTypes)
	-- Counterpart to DetermineXShift()

	local g_iW, g_iH = Map.GetGridSize();

	-- First loop through the map rows and record land plots in each row.
	local land_totals = {};
	for y = 0, g_iH - 1 do
		local current_row = 0;
		for x = 0, g_iW - 1 do
			local i = y * g_iW + x + 1;
			if (plotTypes[i] ~= g_PLOT_TYPE_OCEAN) then
				current_row = current_row + 1;
			end
		end
		table.insert(land_totals, current_row);
	end
	
	-- Now evaluate row groups, each record applying to the center row of the group.
	local row_groups = {};
	-- Determine the group size in relation to map height.
	local group_radius = math.floor(g_iH / 15);
	-- Measure the groups.
	for row_index = 1, g_iH do
		local current_group_total = 0;
		for current_row = row_index - group_radius, row_index + group_radius do
			local current_index = current_row % g_iH;
			if current_index == 0 then -- Modulo of the last row will be zero; this repairs the issue.
				current_index = g_iH;
			end
			current_group_total = current_group_total + land_totals[current_index];
		end
		table.insert(row_groups, current_group_total);
	end
	
	-- Identify the group with the least amount of land in it.
	local best_value = g_iW * (2 * group_radius + 1); -- Set initial value to max possible.
	local best_group = 1; -- Set initial best group as current map edge.
	for row_index, group_land_plots in ipairs(row_groups) do
		if group_land_plots < best_value then
			best_value = group_land_plots;
			best_group = row_index;
		end
	end
	
	-- Determine Y Shift
	local y_shift = best_group - 1;
	return y_shift;
end

-------------------------------------------------------------------------------------------
-- LATITUDE LOOKUP
----------------------------------------------------------------------------------
function GetLatitudeAtPlot(variationFrac, iX, iY)

	local g_iW, g_iH = Map.GetGridSize();

	-- Terrain bands are governed by latitude.
	-- Returns a latitude value between 0.0 (tropical) and 1.0 (polar).
	local lat = math.abs((g_iH / 2) - iY) / (g_iH / 2);
	
	-- Adjust latitude using variation fractal, to roughen the border between bands:
	lat = lat + (128 - variationFrac:GetHeight(iX, iY))/(255.0 * 5.0);
	-- Limit to the range [0, 1]:
	lat = math.clamp(lat, 0, 1);
	
	return lat;
end

------------------------------------------------------------------------------
-- From former "MapmakerUtilites.lua"
------------------------------------------------------------------------------
function ObtainLandmassBoundaries(iAreaID)
	local iW, iH = Map.GetGridSize();
	-- Set up variables that will be returned by this function.
	local wrapsX = false;
	local wrapsY = false;
	local iWestX, iEastX, iSouthY, iNorthY, iWidth, iHeight;
	
	if Map:IsWrapX() then -- Check to see if landmass Wraps X.
		local foundFirstColumn = false;
		local foundLastColumn = false;
		for y = 0, iH - 1 do
			local plotFirst = Map.GetPlot(0, y);
			local plotLast = Map.GetPlot(iW - 1, y);
			local area = plotFirst:GetArea():GetID();
			if area == iAreaID then -- Found a plot belonging to iAreaID in first column.
				foundFirstColumn = true;
			end
			area = plotLast:GetArea():GetID();
			if area == iAreaID then -- Found a plot belonging to iAreaID in last column.
				foundLastColumn = true;
			end
		end
		if foundFirstColumn and foundLastColumn then -- Plot on both sides of map edge.
			wrapsX = true;
		end
	end
	
	if Map:IsWrapY() then -- Check to see if landmass Wraps Y.
		local foundFirstRow = false;
		local foundLastRow = false;
		for y = 0, iH - 1 do
			local plotFirst = Map.GetPlot(x, 0);
			local plotLast = Map.GetPlot(x, iH - 1);
			local area = plotFirst:GetArea():GetID();
			if area == iAreaID then -- Found a plot belonging to iAreaID in first row.
				foundFirstRow = true;
			end
			area = plotLast:GetArea():GetID();
			if area == iAreaID then -- Found a plot belonging to iAreaID in last row.
				foundLastRow = true;
			end
		end
		if foundFirstRow and foundLastRow then -- Plot on both sides of map edge.
			wrapsY = true;
		end
	end

	-- Find West and East edges of this landmass.
	if not wrapsX then -- no X wrap
		for x = 0, iW - 1 do -- Check for any area membership one column at a time, left to right.
			local foundAreaInColumn = false;
			for y = 0, iH - 1 do -- Checking column.
				local plot = Map.GetPlot(x, y);
				local area = plot:GetArea():GetID();
				if area == iAreaID then -- Found a plot belonging to iAreaID, set WestX to this column.
					foundAreaInColumn = true;
					iWestX = x;
					break
				end
			end
			if foundAreaInColumn then -- Found WestX, done looking.
				break
			end
		end
		for x = iW - 1, 0, -1 do -- Check for any area membership one column at a time, right to left.
			local foundAreaInColumn = false;
			for y = 0, iH - 1 do -- Checking column.
				local plot = Map.GetPlot(x, y);
				local area = plot:GetArea():GetID();
				if area == iAreaID then -- Found a plot belonging to iAreaID, set EastX to this column.
					foundAreaInColumn = true;
					iEastX = x;
					break
				end
			end
			if foundAreaInColumn then -- Found EastX, done looking.
				break
			end
		end
	else -- Landmass Xwraps.
		local landmassSpansEntireWorldX = true;
		for x = iW - 2, 1, -1 do -- Check for end of area membership one column at a time, right to left.
			local foundAreaInColumn = false;
			for y = 0, iH - 1 do -- Checking column.
				local plot = Map.GetPlot(x, y);
				local area = plot:GetArea():GetID();
				if area == iAreaID then -- Found a plot belonging to iAreaID, will have to check the next column too.
					foundAreaInColumn = true;
				end
			end
			if not foundAreaInColumn then -- Found empty column, which is just west of WestX.
				iWestX = x + 1;
				landmassSpansEntireWorldX = false;
				break
			end
		end
		for x = 1, iW - 2 do -- Check for end of area membership one column at a time, left to right.
			local foundAreaInColumn = false;
			for y = 0, iH - 1 do -- Checking column.
				local plot = Map.GetPlot(x, y);
				local area = plot:GetArea():GetID();
				if area == iAreaID then -- Found a plot belonging to iAreaID, will have to check the next column too.
					foundAreaInColumn = true;
				end
			end
			if not foundAreaInColumn then -- Found empty column, which is just east of EastX.
				iEastX = x - 1;
				landmassSpansEntireWorldX = false;
				break
			end
		end
		-- If landmass spans entire world, we'll treat it as if it does not wrap.
		if landmassSpansEntireWorldX then
			wrapsX = false;
			iWestX = 0;
			iEastX = iW - 1;
		end
	end
				
	-- Find South and North edges of this landmass.
	if not wrapsY then -- no Y wrap
		for y = 0, iH - 1 do -- Check for any area membership one row at a time, bottom to top.
			local foundAreaInRow = false;
			for x = 0, iW - 1 do -- Checking row.
				local plot = Map.GetPlot(x, y);
				local area = plot:GetArea():GetID();
				if area == iAreaID then -- Found a plot belonging to iAreaID, set SouthY to this row.
					foundAreaInRow = true;
					iSouthY = y;
					break
				end
			end
			if foundAreaInRow then -- Found SouthY, done looking.
				break
			end
		end
		for y = iH - 1, 0, -1 do -- Check for any area membership one row at a time, top to bottom.
			local foundAreaInRow = false;
			for x = 0, iW - 1 do -- Checking row.
				local plot = Map.GetPlot(x, y);
				local area = plot:GetArea():GetID();
				if area == iAreaID then -- Found a plot belonging to iAreaID, set NorthY to this row.
					foundAreaInRow = true;
					iNorthY = y;
					break
				end
			end
			if foundAreaInRow then -- Found NorthY, done looking.
				break
			end
		end
	else -- Landmass Ywraps.
		local landmassSpansEntireWorldY = true;
		for y = iH - 2, 1, -1 do -- Check for end of area membership one row at a time, top to bottom.
			local foundAreaInRow = false;
			for x = 0, iW - 1 do -- Checking row.
				local plot = Map.GetPlot(x, y);
				local area = plot:GetArea():GetID();
				if area == iAreaID then -- Found a plot belonging to iAreaID, will have to check the next row too.
					foundAreaInRow = true;
				end
			end
			if not foundAreaInRow then -- Found empty row, which is just south of southY.
				iSouthY = y + 1;
				landmassSpansEntireWorldY = false;
				break
			end
		end
		for y = 1, iH - 2 do -- Check for end of area membership one row at a time, bottom to top.
			local foundAreaInRow = false;
			for x = 0, iW - 1 do -- Checking row.
				local plot = Map.GetPlot(x, y);
				local area = plot:GetArea():GetID();
				if area == iAreaID then -- Found a plot belonging to iAreaID, will have to check the next row too.
					foundAreaInRow = true;
				end
			end
			if not foundAreaInRow then -- Found empty column, which is just north of NorthY.
				iNorthY = y - 1;
				landmassSpansEntireWorldY = false;
				break
			end
		end
		-- If landmass spans entire world, we'll treat it as if it does not wrap.
		if landmassSpansEntireWorldY then
			wrapsY = false;
			iSouthY = 0;
			iNorthY = iH - 1;
		end
	end
	
	-- Convert EastX and NorthY into width and height.
	if wrapsX then
		iWidth = (iEastX + iW) - iWestX + 1;
	else
		iWidth = iEastX - iWestX + 1;
	end
	if wrapsY then
		iHeight = (iNorthY + iH) - iSouthY + 1;
	else
		iHeight = iNorthY - iSouthY + 1;
	end

	--[[ Log dump for debug purposes only, disable otherwise.
	print("--- Landmass Boundary Readout ---");
	print("West X:", iWestX, "East X:", iEastX);
	print("South Y:", iSouthY, "North Y:", iNorthY);
	print("Width:", iWidth, "Height:", iHeight);
	local plotTotal = iWidth * iHeight;
	print("Total Plots in 'landmass rectangle':", plotTotal);
	print("- - - - - - - - - - - - - - - - -");
	]]--

	-- Insert data into table, then return the table.
	local data = {iWestX, iSouthY, iEastX, iNorthY, iWidth, iHeight, wrapsX, wrapsY};
	return data
end
------------------------------------------------------------------------------
function GenerateCoastalLandDataTable()

	local iW, iH = Map.GetGridSize();
	print ("Calling GenerateCoastalLandDataTable");
	print ("iW, iH: " .. tostring(iW) .. ", " .. tostring(iH));

	local plotDataIsCoastal = table.fill( false, iW * iH);

	-- When generating a plot data table incrementally, process Y first so that plots go row by row.
	-- Keeping plot data table indices consistent with the main plot database could save you enormous grief.
	-- In this case, accessing by plot index, it doesn't matter.
	for x = 0, iW - 1 do
		for y = 0, iH - 1 do
			local plotIsAdjacent = AdjacentToSaltWater(x, y)
			if plotIsAdjacent then
				local i = iW * y + x + 1;
				plotDataIsCoastal[i] = true;
			end
		end
	end
	
	-- returns table
	return plotDataIsCoastal
end
------------------------------------------------------------------------------
function GenerateNextToCoastalLandDataTables()
	-- Set up data table for IsCoastal
	local plotDataIsCoastal = GenerateCoastalLandDataTable()

	-- Set up data table for IsNextToCoast
	local iW, iH = Map.GetGridSize();
	local plotDataIsNextToCoast = table.fill(false, iW * iH);

	-- When generating a plot data table incrementally, process Y first so that plots go row by row.
	-- Keeping plot data table indices consistent with the main plot database could save you enormous grief.
	-- In this case, accessing an existing table by plot index, it doesn't matter.
	for x = 0, iW - 1 do
		for y = 0, iH - 1 do
			local i = iW * y + x + 1;
			local plot = Map.GetPlot(x, y);
			if plotDataIsCoastal[i] == false and not plot:IsWater() then -- plot is not itself on the coast or in the water.
				for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
					local testPlot = Map.GetAdjacentPlot(x, y, direction);
					if testPlot ~= nil then
						local adjX = testPlot:GetX();
						local adjY = testPlot:GetY();
						local adjI = iW * adjY + adjX + 1;
						if plotDataIsCoastal[adjI] == true then
							-- The current loop plot is not itself on the coast but is next to a plot that is on the coast.
							plotDataIsNextToCoast[i] = true;
						end
					end
				end
			end
		end
	end
	
	-- returns table, table
	return plotDataIsCoastal, plotDataIsNextToCoast
end
------------------------------------------------------------------------------
function TestMembership(table, value)
	local testResult = false;
	for index, data in pairs(table) do
		if data == value then
			testResult = true;
			break
		end
	end
	return testResult
end
------------------------------------------------------------------------------
function GetShuffledCopyOfTable(incoming_table)
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
		local random_index = 1 + TerrainBuilder.GetRandomNumber(left_to_do, "Shuffling table entry - Lua");
		table.insert(shuffledVersion, copy[random_index]);
		table.remove(copy, random_index);
		left_to_do = left_to_do - 1;
	end
	return shuffledVersion
end
------------------------------------------------------------------------------
function IdentifyTableIndex(incoming_table, value)
	-- Purpose of this function is to make it easy to remove a data entry from 
	-- a list (table) when the index of the entry is unknown.
	local bFoundValue = false;
	local iNumTimesFoundValue = 0;
	local table_of_indices = {};
	for loop, test_value in pairs(incoming_table) do
		if test_value == value then
			bFoundValue = true;
			iNumTimesFoundValue = iNumTimesFoundValue + 1;
			table.insert(table_of_indices, loop);
		end
	end
	return bFoundValue, iNumTimesFoundValue, table_of_indices;
end
------------------------------------------------------------------------------
function PrintContentsOfTable(incoming_table) -- For debugging purposes. LOT of table data being handled here.
	print("--------------------------------------------------");
	print("Table printout for table ID:", table);
	for index, data in pairs(incoming_table) do
		print("Table index:", index, "Table entry:", data);
	end
	print("- - - - - - - - - - - - - - - - - - - - - - - - - -");
end


function CanPlaceGoodyAt(improvement, plot)

	local improvementID = improvement.RowId - 1;
	local NO_TEAM = -1;
	local NO_RESOURCE = -1;
	local NO_IMPROVEMENT = -1;

	if (plot:IsWater()) then
		return false;
	end

	if (not ImprovementBuilder.CanHaveImprovement(plot, improvementID, NO_TEAM)) then
		return false;
	end
	

	if (plot:GetImprovementType() ~= NO_IMPROVEMENT) then
		return false;
	end

	if (plot:GetResourceType() ~= NO_RESOURCE) then
		return false;
	end

	if (plot:IsImpassable()) then
		return false;
	end

	if (plot:IsMountain()) then
		return false;
	end
	
	-- Don't allow on tiny islands.
	-- local numTiles = plot:GetArea().GetPlotCount();
	-- if (numTiles < 3) then
		-- return false;
	-- end

	-- Check for being too close to another of this goody type.
	local uniqueRange = improvement.GoodyRange;
	local plotX = plot:GetX();
	local plotY = plot:GetY();
	for dx = -uniqueRange, uniqueRange - 1, 1 do
		for dy = -uniqueRange, uniqueRange - 1, 1 do
			local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, uniqueRange);
			if(otherPlot and otherPlot:GetImprovementType() == improvementID) then
				return false;
			end
		end
	end 

	-- Check for being too close to a civ start.
	for dx = -3, 3 do
		for dy = -3, 3 do
			local otherPlot = Map.GetPlotXYWithRangeCheck(plotX, plotY, dx, dy, 4);
			if(otherPlot) then
				if otherPlot:IsStartingPlot() then -- Loop through all ever-alive major civs, check if their start plot matches "otherPlot"
					for player_num = 0, PlayerManager.GetWasEverAliveCount() - 1 do
						local player = Players[player_num];
						if player:WasEverAlive() then
							-- Need to compare otherPlot with this civ's start plot and return false if a match.
							local playerStartPlot = player:GetStartingPlot();
							if otherPlot == playerStartPlot then
								return false;
							end
						end
					end
				end
			end
		end
	end

	return true;
end

function AddGoodies(iW, iH)
	local NO_PLAYER = -1;
	print("-------------------------------");
	print("Map Generation - Adding Goodies");
	
	--If advanced setting wants no goodies, don't place any.
	local bNoGoodies = GameConfiguration.GetValue("GAME_NO_GOODY_HUTS");
	if (bNoGoodies == true) then
		print("** The game specified NO GOODY HUTS");
		return false;
	end
	
	-- Check XML for any and all Improvements flagged as "Goody" and distribute them.
	local iImprovements = 0;
	local iTiles = 0;
	for improvement in GameInfo.Improvements() do
		local improvementID = improvement.RowId - 1;
		if(improvement.Goody and not (improvement.TilesPerGoody == nil)) then
			for x = 0, iW - 1 do
				for y = 0, iH - 1 do
					local i = y * iW + x;
					local pPlot = Map.GetPlotByIndex(i);
					local bGoody = CanPlaceGoodyAt(improvement, pPlot);
					if (bGoody) then
						if (iImprovements == 0 or (improvement.TilesPerGoody < iTiles / iImprovements)) then
							local goody_dice = TerrainBuilder.GetRandomNumber(2, "Goody Hut - LUA Goody Hut");
							if(goody_dice ==  1) then
								ImprovementBuilder.SetImprovementType(pPlot, improvementID, NO_PLAYER);
								iImprovements = iImprovements + 1;
							end
						end
					end

					iTiles = iTiles + 1;
				end
			end
		end
	end
	print("-------------------------------");
end