------------------------------------------------------------------------------
--	FILE:               NaturalWonderGenerator.lua
--	ORIGNIAL AUTHOR:    Ed Beach
--	PURPOSE:            Default method for natural wonder placement
------------------------------------------------------------------------------
--	Copyright (c) 2014 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------

include "MapEnums"

------------------------------------------------------------------------------
NaturalWonderGenerator = {};
------------------------------------------------------------------------------
function NaturalWonderGenerator.Create(args)

	print ("In NaturalWonderGenerator.Create()");
	print ("    Placing " .. tostring(args.numberToPlace) .. " Natural Wonders");

	-- create instance data

	local instance = {

		-- methods
		__InitNWData		= NaturalWonderGenerator.__InitNWData,
		__FindValidLocs		= NaturalWonderGenerator.__FindValidLocs,
		__PlaceWonders		= NaturalWonderGenerator.__PlaceWonders,
		__ScorePlots		= NaturalWonderGenerator.__ScorePlots,

		-- data
		iNumWondersToPlace  = args.numberToPlace;
		aInvalid = args.Invalid or {};
		iNumWondersInDB     = 0;
		eFeatureType		= {},
		aaPossibleLocs		= {},
		aSelectedWonders    = {},
		aPlacedWonders      = {},
		aInvalidNaturalWonders = {},
	};

	-- initialize instance data
	instance:__InitNWData()

	-- scan the map for valid spots
	instance:__FindValidLocs();

	instance:__PlaceWonders();

	return instance;
end
------------------------------------------------------------------------------
function NaturalWonderGenerator:__InitNWData()
	local iCount = 0;
	local iNonNW = 0;

	local excludedWonders = {};
	local excludeWondersConfig = GameConfiguration.GetValue("EXCLUDE_NATURAL_WONDERS");
	if(excludeWondersConfig and #excludeWondersConfig > 0) then
		print("The following Natural Wonders have been marked as 'excluded':");
		for i,v in ipairs(excludeWondersConfig) do
			print("* " .. v);
			excludedWonders[v] = true;
		end
	end

	for loop in GameInfo.Features() do
		if(loop.NaturalWonder and excludedWonders[loop.FeatureType] ~= true) then
			self.eFeatureType[iCount] = loop.Index;
			self.aaPossibleLocs[iCount] = {};
			iCount = iCount + 1;
		end
		iNonNW = iNonNW + 1;
	end

	self.iNumWondersInDB = iCount;
	iNonNW = iNonNW - iCount;

	local iJ = 1;
	for iI = 0, self.iNumWondersInDB - 1 do
		if(iJ <= #self.aInvalid and iI == self.aInvalid[iJ] - iNonNW) then
			self.aInvalidNaturalWonders[iI] = false;
			iJ = iJ + 1;
		else
			self.aInvalidNaturalWonders[iI] = true;
		end
	end
end
------------------------------------------------------------------------------
function NaturalWonderGenerator:__FindValidLocs()

	local iW, iH;
	iW, iH = Map.GetGridSize();

	local iBaseScore = 1;

	local iPlotCount = Map.GetPlotCount();
	for i = 0, iPlotCount - 1 do
		local pPlot = Map.GetPlotByIndex(i);

		-- See which NW can appear here
		for iI = 0, self.iNumWondersInDB - 1 do
			local customPlacement = GameInfo.Features[self.eFeatureType[iI]].CustomPlacement;
			if (customPlacement == nil) then
				if (TerrainBuilder.CanHaveFeature(pPlot, self.eFeatureType[iI], false) and self.aInvalidNaturalWonders[iI] == true) then
					row = {};
					row.MapIndex = i;
					row.Score = iBaseScore;
					table.insert (self.aaPossibleLocs[iI], row);
				end
			else
				if (CustomCanHaveFeature(pPlot, self.eFeatureType[iI])) then
					row = {};
					row.MapIndex = i;
					row.Score = iBaseScore;
					table.insert (self.aaPossibleLocs[iI], row);
				end
			end
		end
	end

	for iI = 0, self.iNumWondersInDB - 1 do
		local iNumEntries = #self.aaPossibleLocs[iI];
		print ("Feature Type: " .. tostring(self.eFeatureType[iI]) .. ", Valid Hexes: " .. tostring(iNumEntries));
		if (iNumEntries > 0) then
			selectionRow = {}
			selectionRow.NWIndex = iI;
			selectionRow.RandomScore = TerrainBuilder.GetRandomNumber (100, "Natural Wonder Selection Roll");
			table.insert (self.aSelectedWonders, selectionRow);
		end
	end
	table.sort(self.aSelectedWonders, function(a, b) return a.RandomScore > b.RandomScore; end);

	-- Debug output
	print ("Num wonders with valid location: " .. tostring(#self.aSelectedWonders));
end
------------------------------------------------------------------------------
function NaturalWonderGenerator:__PlaceWonders()
	local j = 1;
	for i, selectionRow in ipairs(self.aSelectedWonders) do
		if (j <= self.iNumWondersToPlace) then
			print (" Selected Wonder = " .. tostring(selectionRow.NWIndex) .. ", Random Score = ", tostring(selectionRow.RandomScore));

			-- Score possible locations
			self:__ScorePlots(selectionRow.NWIndex);

			-- Sort and take best score
			table.sort (self.aaPossibleLocs[selectionRow.NWIndex], function(a, b) return a.Score > b.Score; end);
			local iMapIndex = self.aaPossibleLocs[selectionRow.NWIndex][1].MapIndex;

			-- Place at this location
			local pPlot = Map.GetPlotByIndex(iMapIndex);
			local eFeatureType = self.eFeatureType[selectionRow.NWIndex]
			if(TerrainBuilder.CanHaveFeature(pPlot, eFeatureType)) then
				local customPlacement = GameInfo.Features[eFeatureType].CustomPlacement;
				if (customPlacement == nil) then
					TerrainBuilder.SetFeatureType(pPlot, eFeatureType);

					ResetTerrain(pPlot:GetIndex());

					local plotX = pPlot:GetX();
					local plotY = pPlot:GetY();

					for dx = -2, 2 do
						for dy = -2,2 do
							local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 2);
							if(otherPlot) then
								if(otherPlot:IsNaturalWonder() == true) then
									ResetTerrain(otherPlot:GetIndex());
								end
							end
						end
					end
				else
					CustomSetFeatureType(pPlot, eFeatureType);
				end
				print (" Set Wonder with Feature ID of " .. tostring(eFeatureType) .. " at location (" .. tostring(pPlot:GetX()) .. ", " .. tostring(pPlot:GetY()) .. ")");
				table.insert (self.aPlacedWonders, iMapIndex);
				j = j+ 1;
			end
		end
	end
end
------------------------------------------------------------------------------
function NaturalWonderGenerator:__ScorePlots(NWIndex)

	local MAX_MAP_DIST = 1000000;
	for i, row in ipairs(self.aaPossibleLocs[NWIndex]) do

		-- Find the plot to score
		local pPlot = Map.GetPlotByIndex(row.MapIndex);

		local iClosestConflictingDist = MAX_MAP_DIST;

		-- See which other Natural Wonder is close
		for k, index in ipairs(self.aPlacedWonders) do
			local pNWPlot = Map.GetPlotByIndex(index);
			local iDist = Map.GetPlotDistance(pPlot:GetX(), pPlot:GetY(), pNWPlot:GetX(), pNWPlot:GetY());
			if iDist < iClosestConflictingDist then
				iClosestConflictingDist = iDist;
			end
		end

		-- Score is based on distance (high distance is better, but once we get over 10 hexes away it is pretty flat) plus a random element
		local iDistanceScore;
		if (iClosestConflictingDist <= 10) then
			iDistanceScore = iClosestConflictingDist * 100;
		else
			iDistanceScore = 1000 + (iClosestConflictingDist - 10);
		end

		row.Score = iDistanceScore + TerrainBuilder.GetRandomNumber(100, "Natural Wonder Placement Score Adjust");
	end
end

------------------------------------------------------------------------------
function CustomCanHaveFeature(pPlot, eFeatureType)
	local aPlots = {};
	return CustomGetMultiTileFeaturePlotList(pPlot, eFeatureType, aPlots);
end

------------------------------------------------------------------------------
function CustomSetFeatureType(pPlot, eFeatureType)
	local aPlots = {};
	if (CustomGetMultiTileFeaturePlotList(pPlot, eFeatureType, aPlots)) then
		TerrainBuilder.SetMultiPlotFeatureType(aPlots, eFeatureType);

		for k, plot in ipairs(aPlots) do
			SetNaturalCliff(plot);
			ResetTerrain(plot);
		end
	end
end

------------------------------------------------------------------------------
function CustomGetMultiTileFeaturePlotList(pPlot, eFeatureType, aPlots)

	-- First check this plot itself
	if (not TerrainBuilder.CanHaveFeature(pPlot, eFeatureType, true)) then
		return false;
	else
		table.insert(aPlots, pPlot:GetIndex());
	end

	-- Which type of custom placement is it?
	local customPlacement = GameInfo.Features[eFeatureType].CustomPlacement;

	-- 2 tiles inland, east-west facing camera
	if (customPlacement == "PLACEMENT_TORRES_DEL_PAINE" or
			customPlacement == "PLACEMENT_YOSEMITE") then

		-- Assume first tile is the western one, check the one to the east
		local pAdjacentPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_EAST);
		if (pAdjacentPlot ~= nil and TerrainBuilder.CanHaveFeature(pAdjacentPlot, eFeatureType, true) == true) then
			table.insert(aPlots, pAdjacentPlot:GetIndex());
			return true;
		end

		-- 2 tiles on coast, roughly facing camera
	elseif (customPlacement == "PLACEMENT_CLIFFS_DOVER") then
		local pNEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
		local pWPlot  = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_WEST);
		local pSWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
		local pSEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
		local pEPlot  = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_EAST);

		-- W and SW are water, see if SE works
		local pSecondPlot;
		if (pWPlot ~= nil and pSWPlot ~= nil and pWPlot:IsWater() and pWPlot:IsLake() == false and pSWPlot:IsWater() and pWPlot:IsLake() == false) then
			pSecondPlot = pSEPlot;

			-- SW and SE are water, see if E works
		elseif (pSWPlot ~= nil and pSEPlot ~= nil and pSWPlot:IsWater() and pSWPlot:IsLake() == false and pSEPlot:IsWater() and pSEPlot:IsLake() == false) then
			pSecondPlot = pEPlot;

			-- SE and E are water, see if NE works
		elseif (pSWPlot ~= nil and pEPlot ~= nil  and pSEPlot:IsWater() and pSEPlot:IsLake() == false and pEPlot:IsWater() and pEPlot:IsLake() == false) then
			pSecondPlot = pNEPlot;

		else
			return false;
		end

		if (pSecondPlot ~= nil and TerrainBuilder.CanHaveFeature(pSecondPlot, eFeatureType, true)) then
			table.insert(aPlots, pSecondPlot:GetIndex());
			return true;
		end

	elseif (customPlacement == "PLACEMENT_GIBRALTAR") then

        -- Assume first tile a land tile without hills, check around it in a preferred order for water
        if (pPlot:IsWater() or pPlot:IsHills()) then
            return false;
        end

        local pSWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
		local pSEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
        if (pSWPlot ~= nil and pSWPlot:IsWater() and pSWPlot:IsLake() == false and pSEPlot ~= nil and pSEPlot:IsWater() and pSEPlot:IsLake() == false) then
            return true;
		end

	elseif (customPlacement == "PLACEMENT_MOSI_OA_TUNYA") then

        if (pPlot:IsWater() or pPlot:IsHills()) then
            return false;
        end

		if (pPlot:IsWOfRiver() or pPlot:IsNWOfRiver() or pPlot:IsNEOfRiver()) then
			return false;
		end

		local pNWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
		local pNEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
		local pWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_WEST);

		if (pNWPlot:IsNWOfRiver() and pNEPlot:IsNEOfRiver() and not pWPlot:IsWOfRiver()) then
			return true;
		end

		-- 2 tiles, one on coastal land and one in water, try to face camera if possible
	elseif (customPlacement == "PLACEMENT_GIANTS_CAUSEWAY") then

		-- Assume first tile a land tile without hills, check around it in a preferred order for water
		if (pPlot:IsWater() or pPlot:IsHills()) then
			return false;
		end

		local pSWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
		if (pSWPlot ~= nil and pSWPlot:IsWater() and pSWPlot:IsLake() == false) then
			table.insert(aPlots, pSWPlot:GetIndex());
			return true;
		end

		local pSEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
		if (pSEPlot ~= nil and pSEPlot:IsWater() and pSEPlot:IsLake() == false) then
			table.insert(aPlots, pSEPlot:GetIndex());
			return true;
		end

		local pWPlot  = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_WEST);
		if (pWPlot ~= nil and pWPlot:IsWater() and pWPlot:IsLake() == false) then
			table.insert(aPlots, pWPlot:GetIndex());
			return true;
		end

		local pEPlot  = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_EAST);
		if (pEPlot ~= nil and pEPlot:IsWater() and pEPlot:IsLake() == false) then
			table.insert(aPlots, pEPlot:GetIndex());
			return true;
		end

		local pNWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
		if (pNWPlot ~= nil and pNWPlot:IsWater() and pNWPlot:IsLake() == false) then
			table.insert(aPlots, pNWPlot:GetIndex());
			return true;
		end

		local pNEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
		if (pNEPlot ~= nil and pNEPlot:IsWater() and pNEPlot:IsLake() == false) then
			table.insert(aPlots, pNEPlot:GetIndex());
			return true;
		end

		-- 4 tiles (triangle plus a tail)
	elseif (customPlacement == "PLACEMENT_RORAIMA") then

		-- This one does require three in a row, so let's find that first
		for i = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local pFirstPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), i);
			if (pFirstPlot ~= nil and TerrainBuilder.CanHaveFeature(pFirstPlot, eFeatureType, true)) then
				local pSecondPlot = Map.GetAdjacentPlot(pFirstPlot:GetX(), pFirstPlot:GetY(), i);
				if (pSecondPlot ~= nil and TerrainBuilder.CanHaveFeature(pSecondPlot, eFeatureType, true)) then
					local iNewDir = i - 1;
					if iNewDir == -1 then
						iNewDir = 5;
					end
					local pThirdPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), iNewDir);
					if (pThirdPlot ~= nil and TerrainBuilder.CanHaveFeature(pThirdPlot, eFeatureType, true)) then
						table.insert(aPlots, pFirstPlot:GetIndex());
						table.insert(aPlots, pSecondPlot:GetIndex());
						table.insert(aPlots, pThirdPlot:GetIndex());
						return true;
					end
				end
			end
		end

		-- 3 tiles in a straight line
	elseif (customPlacement == "PLACEMENT_ZHANGYE_DANXIA") then

		for i = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local pFirstPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), i);
			if (pFirstPlot ~= nil and TerrainBuilder.CanHaveFeature(pFirstPlot, eFeatureType, true)) then
				local pSecondPlot = Map.GetAdjacentPlot(pFirstPlot:GetX(), pFirstPlot:GetY(), i);
				if (pSecondPlot ~= nil and TerrainBuilder.CanHaveFeature(pSecondPlot, eFeatureType, true)) then
					table.insert(aPlots, pFirstPlot:GetIndex());
					table.insert(aPlots, pSecondPlot:GetIndex());
					return true;
				end
			end
		end

		-- 3 tiles in triangle coast on front edge, land behind (with any rotation)
	elseif (customPlacement == "PLACEMENT_PIOPIOTAHI") then

		local pWPlot  = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_WEST);
		local pNWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
		local pNEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
		local pEPlot  = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_EAST);
		local pSEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
		local pSWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);

		-- all 6 hexes around must be land

		if (pNWPlot == nil or pNEPlot == nil or pWPlot== nil or pSWPlot== nil or pSEPlot== nil or pEPlot== nil or pNWPlot:IsWater() or pNEPlot:IsWater() or pWPlot:IsWater() or pSWPlot:IsWater() or pSEPlot:IsWater() or pEPlot:IsWater()) then
			return false;
		else
			-- find two adjacent plots that can both serve for this NW
			local bWValid  = TerrainBuilder.CanHaveFeature(pWPlot, eFeatureType, true);
			local bNWValid = TerrainBuilder.CanHaveFeature(pNWPlot, eFeatureType, true);
			local bNEValid = TerrainBuilder.CanHaveFeature(pNEPlot, eFeatureType, true);
			local bEValid  = TerrainBuilder.CanHaveFeature(pEPlot, eFeatureType, true);
			local bSEValid = TerrainBuilder.CanHaveFeature(pSEPlot, eFeatureType, true);
			local bSWValid = TerrainBuilder.CanHaveFeature(pSWPlot, eFeatureType, true);

			if (bSEValid ~= nil and bSWValid ~= nil and bSEValid == true and bSWValid == true ) then
				pWaterCheck1 = Map.GetAdjacentPlot(pSEPlot:GetX(), pSEPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
				pWaterCheck2 = Map.GetAdjacentPlot(pSWPlot:GetX(), pSWPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
				pWaterCheck3 = Map.GetAdjacentPlot(pSWPlot:GetX(), pSWPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
				if (pWaterCheck1 == nil or pWaterCheck1:IsWater() == false or pWaterCheck2:IsWater() == false or pWaterCheck3:IsWater() == false) then
					return false;
				else
					table.insert(aPlots, pSEPlot:GetIndex());
					table.insert(aPlots, pSWPlot:GetIndex());
					return true;
				end
			end

			if (bEValid  ~= nil and bSEValid ~= nil and bEValid  == true and bSEValid == true ) then
				if (Map.GetAdjacentPlot(pEPlot:GetX(), pEPlot:GetY(), DirectionTypes.DIRECTION_EAST) == nil) then
					return false;
				elseif (Map.GetAdjacentPlot(pSEPlot:GetX(), pSEPlot:GetY(), DirectionTypes.DIRECTION_EAST) == nil) then
					return false;
				elseif ( Map.GetAdjacentPlot(pSEPlot:GetX(), pSEPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST) == nil) then
					return false;
				end

				pWaterCheck1 = Map.GetAdjacentPlot(pEPlot:GetX(), pEPlot:GetY(), DirectionTypes.DIRECTION_EAST);
				pWaterCheck2 = Map.GetAdjacentPlot(pSEPlot:GetX(), pSEPlot:GetY(), DirectionTypes.DIRECTION_EAST);
				pWaterCheck3 = Map.GetAdjacentPlot(pSEPlot:GetX(), pSEPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);

				if (pWaterCheck1:IsWater() == false or pWaterCheck2:IsWater() == false or pWaterCheck3:IsWater() == false) then
					return false;
				else
					table.insert(aPlots, pEPlot:GetIndex());
					table.insert(aPlots, pSEPlot:GetIndex());
					return true;
				end
			end

			if (bSWValid  ~= nil and bWValid ~= nil and bSWValid  == true and bWValid == true ) then
				if (Map.GetAdjacentPlot(pSWPlot:GetX(), pSWPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST) == nil) then
					return false;
				elseif (Map.GetAdjacentPlot(pWPlot:GetX(), pWPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST) == nil) then
					return false;
				elseif ( Map.GetAdjacentPlot(pWPlot:GetX(), pWPlot:GetY(), DirectionTypes.DIRECTION_WEST) == nil) then
					return false;
				end

				pWaterCheck1 = Map.GetAdjacentPlot(pSWPlot:GetX(), pSWPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
				pWaterCheck2 = Map.GetAdjacentPlot(pWPlot:GetX(), pWPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
				pWaterCheck3 = Map.GetAdjacentPlot(pWPlot:GetX(), pWPlot:GetY(), DirectionTypes.DIRECTION_WEST);
				if (pWaterCheck1:IsWater() == false or pWaterCheck2:IsWater() == false or pWaterCheck3:IsWater() == false) then
					return false;
				else
					table.insert(aPlots, pSWPlot:GetIndex());
					table.insert(aPlots, pWPlot:GetIndex());
					return true;
				end
			end

			if (bWValid  ~= nil and bNWValid ~= nil and bWValid  == true and bNWValid == true ) then
				if (Map.GetAdjacentPlot(pWPlot:GetX(), pWPlot:GetY(), DirectionTypes.DIRECTION_WEST) == nil) then
					return false;
				elseif (Map.GetAdjacentPlot(pNWPlot:GetX(), pNWPlot:GetY(), DirectionTypes.DIRECTION_WEST) == nil) then
					return false;
				elseif ( Map.GetAdjacentPlot(pNWPlot:GetX(), pNWPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST) == nil) then
					return false;
				end

				pWaterCheck1 = Map.GetAdjacentPlot(pWPlot:GetX(), pWPlot:GetY(), DirectionTypes.DIRECTION_WEST);
				pWaterCheck2 = Map.GetAdjacentPlot(pNWPlot:GetX(), pNWPlot:GetY(), DirectionTypes.DIRECTION_WEST);
				pWaterCheck3 = Map.GetAdjacentPlot(pNWPlot:GetX(), pNWPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
				if (pWaterCheck1:IsWater() == false or pWaterCheck2:IsWater() == false or pWaterCheck3:IsWater() == false) then
					return false;
				else
					table.insert(aPlots, pWPlot:GetIndex());
					table.insert(aPlots, pNWPlot:GetIndex());
					return true;
				end
			end

			if (bNEValid  ~= nil and bEValid ~= nil and bNEValid  == true and bEValid == true ) then
				if (Map.GetAdjacentPlot(pNEPlot:GetX(), pNEPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST) == nil) then
					return false;
				elseif (Map.GetAdjacentPlot(pEPlot:GetX(), pEPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST) == nil) then
					return false;
				elseif ( Map.GetAdjacentPlot(pEPlot:GetX(), pEPlot:GetY(), DirectionTypes.DIRECTION_EAST) == nil) then
					return false;
				end

				pWaterCheck1 = Map.GetAdjacentPlot(pNEPlot:GetX(), pNEPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
				pWaterCheck2 = Map.GetAdjacentPlot(pEPlot:GetX(), pEPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
				pWaterCheck3 = Map.GetAdjacentPlot(pEPlot:GetX(), pEPlot:GetY(), DirectionTypes.DIRECTION_EAST);
				if (pWaterCheck1:IsWater() == false or pWaterCheck2:IsWater() == false or pWaterCheck3:IsWater() == false) then
					return false;
				else
					table.insert(aPlots, pNEPlot:GetIndex());
					table.insert(aPlots, pEPlot:GetIndex());
					return true;
				end
			end

			if (bNWValid  ~= nil and bNEValid ~= nil and bNWValid  == true and bNEValid == true ) then
				if (Map.GetAdjacentPlot(pNWPlot:GetX(), pNWPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST) == nil) then
					return false;
				elseif (Map.GetAdjacentPlot(pNEPlot:GetX(), pNEPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST) == nil) then
					return false;
				elseif (Map.GetAdjacentPlot(pNEPlot:GetX(), pNEPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST) == nil) then
					return false;
				end

				pWaterCheck1 = Map.GetAdjacentPlot(pNWPlot:GetX(), pNWPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
				pWaterCheck2 = Map.GetAdjacentPlot(pNEPlot:GetX(), pNEPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST);
				pWaterCheck3 = Map.GetAdjacentPlot(pNEPlot:GetX(), pNEPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST);
				if (pWaterCheck1:IsWater() == false or pWaterCheck2:IsWater() == false or pWaterCheck3:IsWater() == false) then
					return false;
				else
					table.insert(aPlots, pNWPlot:GetIndex());
					table.insert(aPlots, pNEPlot:GetIndex());
					return true;
				end
			end
		end

		-- 3 tiles in a triangle that is always "pointing up"
	elseif (customPlacement == "PLACEMENT_PAITITI") then

		local pSEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST);
		local pSWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST);
		if (pSEPlot ~= nil and pSWPlot ~= nil) then
			local bSEValid:boolean = TerrainBuilder.CanHaveFeature(pSEPlot, eFeatureType, true);
		local bSWValid:boolean = TerrainBuilder.CanHaveFeature(pSWPlot, eFeatureType, true);
		if (bSEValid and bSWValid) then
		table.insert(aPlots, pSEPlot:GetIndex());
		table.insert(aPlots, pSWPlot:GetIndex());
			return true;
			end
		end
	end

	return false;
end

------------------------------------------------------------------------------
function ResetTerrain(iPlot)
	local pPlot = Map.GetPlotByIndex(iPlot);
	local iTerrain = pPlot:GetTerrainType();
	if(iTerrain == g_TERRAIN_TYPE_SNOW_HILLS  or iTerrain == g_TERRAIN_TYPE_SNOW_MOUNTAIN) then
		TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_SNOW);
	elseif(iTerrain == g_TERRAIN_TYPE_DESERT_HILLS  or iTerrain == g_TERRAIN_TYPE_DESERT_MOUNTAIN) then
		TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_DESERT);
	elseif(iTerrain == g_TERRAIN_TYPE_PLAINS_HILLS  or iTerrain == g_TERRAIN_TYPE_PLAINS_MOUNTAIN) then
		TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_PLAINS);
	elseif(iTerrain == g_TERRAIN_TYPE_GRASS_HILLS  or iTerrain == g_TERRAIN_TYPE_GRASS_MOUNTAIN) then
		TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_GRASS);
	elseif(iTerrain == g_TERRAIN_TYPE_TUNDRA_HILLS  or iTerrain == g_TERRAIN_TYPE_TUNDRA_MOUNTAIN) then
		TerrainBuilder.SetTerrainType(pPlot, g_TERRAIN_TYPE_TUNDRA);
	end
end

------------------------------------------------------------------------------
function SetNaturalCliff(iPlot)
	local iW, iH = Map.GetGridSize();
	local pPlot = Map.GetPlotByIndex(iPlot);
	local iX = pPlot:GetX();
	local iY = pPlot:GetY();

	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
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