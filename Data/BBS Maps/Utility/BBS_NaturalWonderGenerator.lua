------------------------------------------------------------------------------
--	FILE:               BBS_NaturalWonderGenerator.lua
--	ORIGNIAL AUTHOR:    Ed Beach
--	PURPOSE:            Default method for natural wonder placement
------------------------------------------------------------------------------
--	Copyright (c) 2014 Firaxis Games, Inc. All rights reserved.
------------------------------------------------------------------------------
print("BBS_NaturalWonderGenerator.lua for BBS")
include "MapEnums"

------------------------------------------------------------------------------
BBS_NaturalWonderGenerator = {};
------------------------------------------------------------------------------
function BBS_NaturalWonderGenerator.Create(args)

	print ("In BBS_NaturalWonderGenerator.Create()");
	print ("    Placing " .. tostring(args.numberToPlace) .. " Natural Wonders");

	-- create instance data

	local instance = {

		-- methods
		__InitNWData		= BBS_NaturalWonderGenerator.__InitNWData,
		__FindValidLocs		= BBS_NaturalWonderGenerator.__FindValidLocs,
		__PlaceWonders		= BBS_NaturalWonderGenerator.__PlaceWonders,
		__CheckWonders		= BBS_NaturalWonderGenerator.__CheckWonders,
		__ScorePlots		= BBS_NaturalWonderGenerator.__ScorePlots,

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
	
	instance:__CheckWonders();

	return instance;
end
------------------------------------------------------------------------------
function BBS_NaturalWonderGenerator:__InitNWData()
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
function BBS_NaturalWonderGenerator:__FindValidLocs()

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
            --print(i, TerrainBuilder.CanHaveFeature(pPlot, self.eFeatureType[iI], false), self.aInvalidNaturalWonders[iI]);
				if (TerrainBuilder.CanHaveFeature(pPlot, self.eFeatureType[iI], false) and self.aInvalidNaturalWonders[iI] == true) then
					row = {};
					row.MapIndex = i;
					row.Score = iBaseScore;
					table.insert (self.aaPossibleLocs[iI], row);
				end
			else
            --print("placement", customPlacement);
            local returnValue = false;
            returnValue = BBSCustomCanHaveFeature(pPlot, self.eFeatureType[iI])
            --print("return value", returnValue);
				if (returnValue) then
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
function BBS_NaturalWonderGenerator:__CheckWonders()

	local iW, iH;
	iW, iH = Map.GetGridSize();

	local iPlotCount = Map.GetPlotCount();
	for i = 0, iPlotCount - 1 do
		local pPlot = Map.GetPlotByIndex(i);
		if pPlot:IsNaturalWonder() == true then
			local CheckedWonder = pPlot:GetFeatureType()
			local CheckedWonder_Name = tostring(GameInfo.Features[CheckedWonder].Name)
			--print ("Feature Type: ",CheckedWonder_Name,"X:",pPlot:GetX(),"Y;",pPlot:GetY(),MapFeatureManager.IsVolcano(pPlot))
			if MapFeatureManager.IsVolcano(pPlot) == true and (CheckedWonder_Name ~= "LOC_FEATURE_VESUVIUS_NAME" and CheckedWonder_Name ~= "LOC_FEATURE_EYJAFJALLAJOKULL_NAME" and CheckedWonder_Name ~= "LOC_FEATURE_KRAKATOA_NAME" and CheckedWonder_Name ~= "LOC_FEATURE_KILIMANJARO_NAME") then
				print ("Volcano Detected: Remove")				
				TerrainBuilder.SetFeatureType(pPlot,-1)
				TerrainBuilder.SetFeatureType(pPlot,g_FEATURE_VOLCANO)
				TerrainBuilder.SetTerrainType(pPlot, BBS_ConvertToMountain(pPlot:GetTerrainType()))
				else
				for j = 1, 50 do
				local otherPlot = GetAdjacentTiles(pPlot, j)
					if(otherPlot) then
						
						if(otherPlot:IsNaturalWonder() == true and otherPlot:GetFeatureType() ~= CheckedWonder) then
							print ("Clumped Wonder Detected: ",tostring(GameInfo.Features[otherPlot:GetFeatureType()].Name),"X:",otherPlot:GetX(),"Y;",otherPlot:GetY())
							TerrainBuilder.SetFeatureType(otherPlot,-1)
						end
					end
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
function BBS_NaturalWonderGenerator:__PlaceWonders()
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

					for dx = -3, 3 do
						for dy = -3,3 do
							local otherPlot = Map.GetPlotXY(plotX, plotY, dx, dy, 3);
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
function BBS_NaturalWonderGenerator:__ScorePlots(NWIndex)

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
function BBSCustomCanHaveFeature(pPlot, eFeatureType)
	local aPlots = {};
   --print("custom can have", eFeatureType);
	return BBSCustomGetMultiTileFeaturePlotList(pPlot, eFeatureType, aPlots);
end

------------------------------------------------------------------------------
function CustomSetFeatureType(pPlot, eFeatureType)

	local aPlots = {};
	if (BBSCustomGetMultiTileFeaturePlotList(pPlot, eFeatureType, aPlots)) then
		TerrainBuilder.SetMultiPlotFeatureType(aPlots, eFeatureType);

		for k, plot in ipairs(aPlots) do
			SetNaturalCliff(plot);
			ResetTerrain(plot);
		end
	end
end

------------------------------------------------------------------------------
function BBSCustomGetMultiTileFeaturePlotList(pPlot, eFeatureType, aPlots)
	-- First check this plot itself
   --print ("entree fonction");
	if (not TerrainBuilder.CanHaveFeature(pPlot, eFeatureType, true)) then
      --print("direct out");
		return false;
	else
		table.insert(aPlots, pPlot:GetIndex());
	end

	-- Which type of custom placement is it?
	local customPlacement = GameInfo.Features[eFeatureType].CustomPlacement;
   
   --print("placement name", customPlacement);
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
		
      
        --print("we are in");
        -- Assume first tile a land tile without hills, check around it in a preferred order for water
        if (pPlot:IsWater()) then --or pPlot:IsHills()
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

function BBS_ConvertToMountain(type)

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

		__Debug("GetAdjacentTiles: Invalid Arguments");
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
			--__Debug(i, j)
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
