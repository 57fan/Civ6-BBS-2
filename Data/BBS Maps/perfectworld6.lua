--------------------------------------------------------------------------------
--PerfectWorld6.lua map script (c)2010-2018 Rich Marinaccio
--version 8
--------------------------------------------------------------------------------
--This map script uses various manipulations of Perlin noise to create
--landforms, and generates climate based on a simplified model of geostrophic
--and monsoon wind patterns. Rivers are generated along accurate drainage paths
--governed by the elevation map used to create the landforms.
--
--Version History
-- 8 D. / Jack The Narrator tweak

--7 Took another stab at backward compatibility.

--6 Get ready for Gathering Storm, including better placement for Natural Wonders.
-- Also required a minimum of real estate for major starts

--5 implemented pokiehl's fixes

--4 - Tweaks to the default values to bring more production

--3 - Eliminated reefs in lakes

--2 - Added reefs and also the JungleToPlains option

--1 - initial release! 

include "MapEnums"
include "MapUtilities"
include "BBS_MountainsCliffs"
include "RiversLakes"
include "FeatureGenerator"
include "BBS_TerrainGenerator"
include "BBS_NaturalWonderGenerator"
include "ResourceGenerator"
include "CoastalLowlands"
include "AssignStartingPlots"
include "BBS_AssignStartingPlots"
include "BBS_Balance"
-------------------------------------------------------------------------------
function BBS_Assign(args)
	print("BBS_Assign: Injecting Spawn Placement")
	local start_plot_database = {};

	start_plot_database = BBS_AssignStartingPlots.Create(args)

	return start_plot_database
end
-------------------------------------------------------------------------------

MapConstants = {}

function MapConstants:New()
	local mconst = {}
	setmetatable(mconst, self)
	self.__index = self

	--Percent of land tiles on the map.
	mconst.landPercent = 0.28

	--Percent of dry land that is below the hill elevation deviance threshold.
	mconst.hillsPercent = 0.54
	
	--Percent of dry land that is below the mountain elevation deviance
	--threshold.
	mconst.mountainsPercent = 0.86

	--Percent of land that is below the desert rainfall threshold.
	mconst.desertPercent = 0.37
	--Coldest absolute temperature allowed to be desert, plains if colder.
	mconst.desertMinTemperature = 0.34

	--Percent of land that is below the plains rainfall threshold.
	mconst.plainsPercent = 0.64

	--Percent of land that is below the rainfall threshold where no trees
	--can appear.
	mconst.zeroTreesPercent = 0.30
	--Coldest absolute temperature where trees appear.
	mconst.treesMinTemperature = 0.27

	--Percent of land below the jungle rainfall threshold.
	mconst.junglePercent = 0.78
	--Coldest absolute temperature allowed to be jungle, forest if colder.
	mconst.jungleMinTemperature = 0.70

	--Percent of land below the marsh rainfall threshold.
	mconst.marshPercent = 0.92

	--Absolute temperature below which is snow.
	mconst.snowTemperature = 0.27

	--Absolute temperature below which is tundra.
	mconst.tundraTemperature = 0.32

	--North and south ice latitude limits. Used for pre-GS
	mconst.iceNorthLatitudeLimit = 60
	mconst.iceSouthLatitudeLimit = -60
	
	--percent of land tiles made to be lakes
	mconst.lakePercent = 0.04
	
	--percent of river junctions that are large enough to become rivers.
	mconst.riverPercent = 0.55
	
	--minumum river length measured in hex sides. Shorter rivers that are not lake
	--outflows will be culled
	mconst.minRiverLength = 5
	
	--this is the percent of rivers that have floodplains that flood
	--largest rivers always have priority for floodability
	mconst.percentRiversFloodplains = 0.25
	
	--Maximum chance for reef at highest temperature
	mconst.maxReefChance = 0.15
	
	--normally, jungle has plains underlying them. I personally don't like it because I want 
	--jungles to look wet, and I like that it makes settling in jungle more challenging, 
	--however, it's a subjective thing. Here is an option to change it back.
	--The settings are:
	--"NONE" to leave them as grassland
	--"HILLS_ONLY" to change only the hills to plains
	--"ALL" to change all jungle tiles to have underlying plains
	mconst.JungleToPlains = "ALL"

	--These attenuation factors lower the altitude of the map edges. This is
	--currently used to prevent large continents in the uninhabitable polar
	--regions.
	mconst.northAttenuationFactor = 0.75
	mconst.northAttenuationRange = 0.15 --percent of the map height.
	mconst.southAttenuationFactor = 0.75
	mconst.southAttenuationRange = 0.15

	--east west attenuation. Civ 6 creates a rather ugly seam when continents
	--straddle the map edge. It still plays well but I have decided to avoid
	--the map edges for aesthetic reasons.
	mconst.eastAttenuationFactor = 0.75
	mconst.eastAttenuationRange = 0.10 --percent of the map width.
	mconst.westAttenuationFactor = 0.75
	mconst.westAttenuationRange = 0.10

	--These set the water temperature compression that creates the land/sea
	--seasonal temperature differences that cause monsoon winds.
	mconst.minWaterTemp = 0.10
	mconst.maxWaterTemp = 0.60

	--Top and bottom map latitudes.
	mconst.topLatitude = 70
	mconst.bottomLatitude = -70

	--Important latitude markers used for generating climate.
	mconst.polarFrontLatitude = 60
	mconst.tropicLatitudes = 23
	mconst.horseLatitudes = 28 -- I shrunk these a bit to emphasize temperate lattitudes

	--Strength of geostrophic climate generation versus monsoon climate
	--generation.
	mconst.geostrophicFactor = 3.0

	mconst.geostrophicLateralWindStrength = 0.6

	--Fill in any lakes smaller than this. It looks bad to have large
	--river systems flowing into a tiny lake.
	mconst.minOceanSize = 50

	--Weight of the mountain elevation map versus the coastline elevation map.
	mconst.mountainWeight = 0.8

	--Crazy rain tweaking variables. I wouldn't touch these if I were you.
	mconst.minimumRainCost = 0.0001
	mconst.upLiftExponent = 4
	mconst.polarRainBoost = 0.00

	--default frequencies for map of width 128. Adjusting these frequences
	--will generate larger or smaller map features.
	mconst.twistMinFreq = 0.05
	mconst.twistMaxFreq = 0.12
	mconst.twistVar = 0.042
	mconst.mountainFreq = 0.078
	
	mconst.AllowPangeas = true
	--a continent with more land tiles than this percentage of total landtiles is 
	--considered a pangaea and broken up if allowed.
	mconst.PangaeaSize = 0.70
	--maximum percentage of land tiles that will be designated as 
	--new world continents.
	mconst.maxNewWorldSize = 0.35
	
	--retrieving the map option to start in the old world or anywhere. This can be overriden
	--in the following section if you would rather use normal starts on a regular basis
	mconst.OldWorldStart = MapConfiguration.GetValue("oldworld") == "OLD_WORLD"
	print("OldWorldStart = ", mconst.OldWorldStart)
	
	--Uncomment the line below to disable the old world start and override the in-game option
	--mconst.OldWorldStart = false
	
	--if OldWorldStart == true, setting this to false will force all minor civs to start
	--in the old world also. Setting this to true will spread minor civs proportional to 
	--the land mass of the old and new worlds. If OldWorldStart == false, then this does nothing
	mconst.ProportionalMinors = true

	
	--This is the minimum contiguous passable non water landmass that can 
	--be considered a major civ capital. Full 3 radius city area could have 
	--37 tiles maximum
	mconst.realEstateMin = 15
	
	--PerfectWorld maps are a bit bigger that normal maps, and it may be appropriate to 
	--have slightly more natural wonders. This variable sets how many extra wonders are set
	--according to map size. I'm told that 'less is more' when it comes to natural wonders, 
	--and I interpret that as a little more is maybe more than less.
	mconst.naturalWonderExtra = 1
	


	-----------------------------------------------------------------------
	--Below are map constants that should not be altered.

	--directions
	mconst.C = 0
	mconst.W = 1
	mconst.NW = 2
	mconst.NE = 3
	mconst.E = 4
	mconst.SE = 5
	mconst.SW = 6

	--flow directions
	mconst.NOFLOW = 0
	mconst.WESTFLOW = 1
	mconst.EASTFLOW = 2
	mconst.VERTFLOW = 3

	--wind zones
	mconst.NOZONE = -1
	mconst.NPOLAR = 0
	mconst.NTEMPERATE = 1
	mconst.NEQUATOR = 2
	mconst.SEQUATOR = 3
	mconst.STEMPERATE = 4
	mconst.SPOLAR = 5
	
    --Maps look bad if too many meteors are required to break up a pangaea.
	--Map will regen after this many meteors are thrown
    mconst.maximumMeteorCount = 8
    
    --Minimum size for a meteor strike that attemps to break pangaeas.
    --Don't bother to change this it will be overwritten depending on
    --map size.
    mconst.minimumMeteorSize = 2      

	--Hex maps are shorter in the y direction than they are
	--wide per unit by this much. We need to know this to sample the perlin
	--maps properly so they don't look squished.
	mconst.YtoXRatio = 1.5/(math.sqrt(0.75) * 2)
	
	return mconst
end

function MapConstants:GetOppositeDir(dir)
	return ((dir + 2) % 6) + 1
end

--Returns a value along a bell curve from a 0 - 1 range
function MapConstants:GetBellCurve(value)
	return math.sin(value * math.pi * 2 - math.pi * 0.5) * 0.5 + 0.5
end

---------------------------------------------------------------------------------
--functions that Civ needs
-------------------------------------------------------------------------------
function CountLand(plotTypes, terrainTypes)
--this function is used sometimes for sanity checks during debugging
	--and also for initializing the feateure
	landCount = 0
	for y = 0, elevationMap.height - 1,1 do
		for x = 0, elevationMap.width - 1,1 do
			local i = elevationMap:GetIndex(x,y)
			if plotTypes == nil and terrainTypes == nil then
				local plot = Map.GetPlotByIndex(i)
				if plot:IsWater() == false then
					landCount = landCount + 1
				end
			else
				if terrainTypes == nil then
					if plotTypes[i] ~= g_PLOT_TYPE_OCEAN then
						landCount = landCount + 1
					end
				else
					if terrainTypes[i] ~= g_TERRAIN_TYPE_COAST and terrainTypes[i] ~= g_TERRAIN_TYPE_OCEAN then
						landCount = landCount + 1
					else
						if terrainTypes[i] == g_TERRAIN_TYPE_NONE then
							print(string.format("terrainTypes[%d] = g_TERRAIN_TYPE_NONE!",i))
						end
					end
				end
			end
		end
	end
	print("===================++++++++++++++landCount = ",landCount)
	return landCount
end
function GenerateMap()
	print("Generating PerfectWorld6 Map");
	
	plotTypes = nil --needs to be global
	local terrainTypes = nil
	g_iW, g_iH = Map.GetGridSize();
  
	local iterations = 0
	while iterations < 10 do
		plotTypes = GeneratePlotTypes()
		terrainTypes = GenerateTerrain()
		FinalAlterations(plotTypes, terrainTypes)
		GenerateCoasts(plotTypes, terrainTypes)
	 
		pb = PangaeaBreaker:New()
		if pb:breakPangaeas(plotTypes, terrainTypes) then
			break
		end
		iterations = iterations + 1
	end
	if iterations == 10 then
		error("pangaeas failed to break up!")
	end
	pb:createNewWorldMap()
	--CountLand(nil,terrainTypes)
  	--combine both types
  	ApplyTerrain(plotTypes, terrainTypes) --only call this once or else it will crash the game!
	--CountLand(nil,terrainTypes)
	
	AreaBuilder.Recalculate()
	TerrainBuilder.AnalyzeChokepoints()
	TerrainBuilder.StampContinents()
	
	local iContinentBoundaryPlots = nil;
	if g_FEATURE_VOLCANO ~= nil then
		iContinentBoundaryPlots = GetContinentBoundaryPlotCount(g_iW, g_iH);
	end
	local biggest_area = Areas.FindBiggestArea(false);
	print("After Adding Hills: ", biggest_area:GetPlotCount());
	if g_FEATURE_VOLCANO ~= nil then
		AddTerrainFromContinents(terrainTypes, g_iW, g_iH, iContinentBoundaryPlots);
	end
	
	riverMap = RiverMap:New(elevationMap)
	riverMap:SetJunctionAltitudes()
	riverMap:SiltifyLakes()
	riverMap:RecreateNewLakes()
	riverMap:SetFlowDestinations()
	riverMap:SetRiverSizes(rainfallMap)
	riverMap:CreateRiverList()
	riverMap:AssignRiverIDs()
  	
	AddLakes()
  	AddRivers()
   	   	
	AreaBuilder.Recalculate()
	local biggest_area = Areas.FindBiggestArea(false);
	print("Biggest area size = ", biggest_area:GetPlotCount());
	
	zeroTreesThreshold = rainfallMap:FindThresholdFromPercent(mc.zeroTreesPercent,false,true) --making this global for later use
    jungleThreshold = rainfallMap:FindThresholdFromPercent(mc.junglePercent,false,true)
	local nwGen = BBS_NaturalWonderGenerator.Create({
		numberToPlace = GameInfo.Maps[Map.GetMapSize()].NumNaturalWonders + mc.naturalWonderExtra,
	});

	--CountLand()
	
   	AddFeatures()	
	
	if g_FEATURE_VOLCANO ~= nil then
		ClearFloodPlains()	
		local iMinFloodplainSize = 2;
		local iMaxFloodplainSize = 12;
		TerrainBuilder.GenerateFloodplains(true, iMinFloodplainSize, iMaxFloodplainSize);
	end
	
	AddCliffs(plotTypes, terrainTypes)
	
	if g_FEATURE_VOLCANO ~= nil then
		local args = {rainfall = 3}
		featuregen = FeatureGenerator.Create(args)
		featuregen.iNumLandPlots = CountLand(nil, terrainTypes)
		featuregen:AddIceToMap();
		featuregen:AddFeaturesFromContinents()
		
		MarkCoastalLowlands();
	end
	

	resourcesConfig = MapConfiguration.GetValue("resources");
	local resGen = ResourceGenerator.Create({
		resources = resourcesConfig,
		bLandBias = true,
	});

	print("Creating start plot database.");
	local startConfig = MapConfiguration.GetValue("start");
    local start_plot_database = BBS_Assign({
		MIN_MAJOR_CIV_FERTILITY = 300,
		MIN_MINOR_CIV_FERTILITY = 50,
		MIN_BARBARIAN_FERTILITY = 1,
		START_MIN_Y = 15,
		START_MAX_Y = 15,
		START_CONFIG = startConfig,
		LAND = true,
	})
	
	local Balance = BBS_Script()
	local gridWidth, gridHeight = Map.GetGridSize();
    AddGoodies(gridWidth, gridHeight);
	print("finished adding goodies")
end

-----------------------------------------------------------------------------
--Interpolation and Perlin functions
-----------------------------------------------------------------------------
function CubicInterpolate(v0,v1,v2,v3,mu)
	local mu2 = mu * mu
	local a0 = v3 - v2 - v0 + v1
	local a1 = v0 - v1 - a0
	local a2 = v2 - v0
	local a3 = v1

	return (a0 * mu * mu2 + a1 * mu2 + a2 * mu + a3)
end

function BicubicInterpolate(v,muX,muY)
	local a0 = CubicInterpolate(v[1],v[2],v[3],v[4],muX);
	local a1 = CubicInterpolate(v[5],v[6],v[7],v[8],muX);
	local a2 = CubicInterpolate(v[9],v[10],v[11],v[12],muX);
	local a3 = CubicInterpolate(v[13],v[14],v[15],v[16],muX);

	return CubicInterpolate(a0,a1,a2,a3,muY)
end

function CubicDerivative(v0,v1,v2,v3,mu)
	local mu2 = mu * mu
	local a0 = v3 - v2 - v0 + v1
	local a1 = v0 - v1 - a0
	local a2 = v2 - v0
	--local a3 = v1

	return (3 * a0 * mu2 + 2 * a1 * mu + a2)
end

function BicubicDerivative(v,muX,muY)
	local a0 = CubicInterpolate(v[1],v[2],v[3],v[4],muX);
	local a1 = CubicInterpolate(v[5],v[6],v[7],v[8],muX);
	local a2 = CubicInterpolate(v[9],v[10],v[11],v[12],muX);
	local a3 = CubicInterpolate(v[13],v[14],v[15],v[16],muX);

	return CubicDerivative(a0,a1,a2,a3,muY)
end

--This function gets a smoothly interpolated value from srcMap.
--x and y are non-integer coordinates of where the value is to
--be calculated, and wrap in both directions. srcMap is an object
--of type FloatMap.
function GetInterpolatedValue(X,Y,srcMap)
	local points = {}
	local fractionX = X - math.floor(X)
	local fractionY = Y - math.floor(Y)

	--wrappedX and wrappedY are set to -1,-1 of the sampled area
	--so that the sample area is in the middle quad of the 4x4 grid
	local wrappedX = ((math.floor(X) - 1) % srcMap.rectWidth) + srcMap.rectX
	local wrappedY = ((math.floor(Y) - 1) % srcMap.rectHeight) + srcMap.rectY

	local x
	local y

	for pY = 0, 4-1,1 do
		y = pY + wrappedY
		for pX = 0,4-1,1 do
			x = pX + wrappedX
			local srcIndex = srcMap:GetRectIndex(x, y)
			points[(pY * 4 + pX) + 1] = srcMap.data[srcIndex]
		end
	end

	local finalValue = BicubicInterpolate(points,fractionX,fractionY)

	return finalValue

end

function GetDerivativeValue(X,Y,srcMap)
	local points = {}
	local fractionX = X - math.floor(X)
	local fractionY = Y - math.floor(Y)

	--wrappedX and wrappedY are set to -1,-1 of the sampled area
	--so that the sample area is in the middle quad of the 4x4 grid
	local wrappedX = ((math.floor(X) - 1) % srcMap.rectWidth) + srcMap.rectX
	local wrappedY = ((math.floor(Y) - 1) % srcMap.rectHeight) + srcMap.rectY

	local x
	local y

	for pY = 0, 4-1,1 do
		y = pY + wrappedY
		for pX = 0,4-1,1 do
			x = pX + wrappedX
			local srcIndex = srcMap:GetRectIndex(x, y)
			points[(pY * 4 + pX) + 1] = srcMap.data[srcIndex]
		end
	end

	local finalValue = BicubicDerivative(points,fractionX,fractionY)

	return finalValue

end

--This function gets Perlin noise for the destination coordinates. Note
--that in order for the noise to wrap, the area sampled on the noise map
--must change to fit each octave.
function GetPerlinNoise(x,y,destMapWidth,destMapHeight,initialFrequency,initialAmplitude,amplitudeChange,octaves,noiseMap)
	local finalValue = 0.0
	local frequency = initialFrequency
	local amplitude = initialAmplitude
	local frequencyX --slight adjustment for seamless wrapping
	local frequencyY --''
	for i = 1,octaves,1 do
		if noiseMap.wrapX then
			noiseMap.rectX = math.floor(noiseMap.width/2 - (destMapWidth * frequency)/2)
			noiseMap.rectWidth = math.max(math.floor(destMapWidth * frequency),1)
			frequencyX = noiseMap.rectWidth/destMapWidth
		else
			noiseMap.rectX = 0
			noiseMap.rectWidth = noiseMap.width
			frequencyX = frequency
		end
		if noiseMap.wrapY then
			noiseMap.rectY = math.floor(noiseMap.height/2 - (destMapHeight * frequency)/2)
			noiseMap.rectHeight = math.max(math.floor(destMapHeight * frequency),1)
			frequencyY = noiseMap.rectHeight/destMapHeight
		else
			noiseMap.rectY = 0
			noiseMap.rectHeight = noiseMap.height
			frequencyY = frequency
		end

		finalValue = finalValue + GetInterpolatedValue(x * frequencyX, y * frequencyY, noiseMap) * amplitude
		frequency = frequency * 2.0
		amplitude = amplitude * amplitudeChange
	end
	finalValue = finalValue/octaves
	return finalValue
end

function GetPerlinDerivative(x,y,destMapWidth,destMapHeight,initialFrequency,initialAmplitude,amplitudeChange,octaves,noiseMap)
	local finalValue = 0.0
	local frequency = initialFrequency
	local amplitude = initialAmplitude
	local frequencyX --slight adjustment for seamless wrapping
	local frequencyY --''
	for i = 1,octaves,1 do
		if noiseMap.wrapX then
			noiseMap.rectX = math.floor(noiseMap.width/2 - (destMapWidth * frequency)/2)
			noiseMap.rectWidth = math.floor(destMapWidth * frequency)
			frequencyX = noiseMap.rectWidth/destMapWidth
		else
			noiseMap.rectX = 0
			noiseMap.rectWidth = noiseMap.width
			frequencyX = frequency
		end
		if noiseMap.wrapY then
			noiseMap.rectY = math.floor(noiseMap.height/2 - (destMapHeight * frequency)/2)
			noiseMap.rectHeight = math.floor(destMapHeight * frequency)
			frequencyY = noiseMap.rectHeight/destMapHeight
		else
			noiseMap.rectY = 0
			noiseMap.rectHeight = noiseMap.height
			frequencyY = frequency
		end

		finalValue = finalValue + GetDerivativeValue(x * frequencyX, y * frequencyY, noiseMap) * amplitude
		frequency = frequency * 2.0
		amplitude = amplitude * amplitudeChange
	end
	finalValue = finalValue/octaves
	return finalValue
end

function Push(a,item)
	table.insert(a,item)
end

function Pop(a)
	return table.remove(a)
end
------------------------------------------------------------------------
--inheritance mechanism from http://www.gamedev.net/community/forums/topic.asp?topic_id=561909
------------------------------------------------------------------------
function inheritsFrom( baseClass )

    local new_class = {}
    local class_mt = { __index = new_class }

    function new_class:create()
        local newinst = {}
        setmetatable( newinst, class_mt )
        return newinst
    end

    if nil ~= baseClass then
        setmetatable( new_class, { __index = baseClass } )
    end

    -- Implementation of additional OO properties starts here --

    -- Return the class object of the instance
    function new_class:class()
        return new_class;
    end

	-- Return the super class object of the instance, optional base class of the given class (must be part of hiearchy)
    function new_class:baseClass(class)
		return new_class:_B(class);
    end

    -- Return the super class object of the instance, optional base class of the given class (must be part of hiearchy)
    function new_class:_B(class)
		if (class==nil) or (new_class==class) then
			return baseClass;
		elseif(baseClass~=nil) then
			return baseClass:_B(class);
		end
		return nil;
    end

	-- Return true if the caller is an instance of theClass
    function new_class:_ISA( theClass )
        local b_isa = false

        local cur_class = new_class

        while ( nil ~= cur_class ) and ( false == b_isa ) do
            if cur_class == theClass then
                b_isa = true
            else
                cur_class = cur_class:baseClass()
            end
        end

        return b_isa
    end

    return new_class
end

-----------------------------------------------------------------------------
-- Random functions will use lua rands for stand alone script running
-- and Map.rand for in game.
-----------------------------------------------------------------------------
function PWRand()
	return math.random()
end

function PWRandSeed(fixedseed)
	local seed
	--fixedseed = 394527185
	if fixedseed == nil then
		seed = TerrainBuilder.GetRandomNumber(255,"Seeding PerfectWorld6")
		seed = seed * 256 + TerrainBuilder.GetRandomNumber(255,"Seeding PerfectWorld6")
		seed = seed * 256 + TerrainBuilder.GetRandomNumber(255,"Seeding PerfectWorld6")
		seed = seed * 64 + TerrainBuilder.GetRandomNumber(255,"Seeding PerfectWorld6")
	else
		seed = fixedseed
	end
	math.randomseed(seed)
	print("random seed for this map is " .. seed)
end

--range is inclusive, low and high are possible results
function PWRandint(low, high)
	return math.random(low, high)
end
-----------------------------------------------------------------------------
-- FloatMap class
-- This is for storing 2D map data. The 'data' field is a zero based, one
-- dimensional array. To access map data by x and y coordinates, use the
-- GetIndex method to obtain the 1D index, which will handle any needs for
-- wrapping in the x and y directions.
-----------------------------------------------------------------------------
FloatMap = inheritsFrom(nil)

function FloatMap:New(width, height, wrapX, wrapY)
	local new_inst = {}
	setmetatable(new_inst, {__index = FloatMap});	--setup metatable

	new_inst.width = width
	new_inst.height = height
	new_inst.wrapX = wrapX
	new_inst.wrapY = wrapY
	new_inst.length = width*height

	--These fields are used to access only a subset of the map
	--with the GetRectIndex function. This is useful for
	--making Perlin noise wrap without generating separate
	--noise fields for each octave
	new_inst.rectX = 0
	new_inst.rectY = 0
	new_inst.rectWidth = width
	new_inst.rectHeight = height

	new_inst.data = {}
	for i = 0,width*height - 1,1 do
		new_inst.data[i] = 0.0
	end

	return new_inst
end

function FloatMap:GetNeighbor(x,y,dir)
	local xx
	local yy
	local odd = y % 2
	if dir == mc.C then
		return x,y
	elseif dir == mc.W then
		xx = x - 1
		yy = y
		return xx,yy
	elseif dir == mc.NW then
		xx = x - 1 + odd
		yy = y + 1
		return xx,yy
	elseif dir == mc.NE then
		xx = x + odd
		yy = y + 1
		return xx,yy
	elseif dir == mc.E then
		xx = x + 1
		yy = y
		return xx,yy
	elseif dir == mc.SE then
		xx = x + odd
		yy = y - 1
		return xx,yy
	elseif dir == mc.SW then
		xx = x - 1 + odd
		yy = y - 1
		return xx,yy
	else
		error("Bad direction in FloatMap:GetNeighbor")
	end
	return -1,-1
end

function FloatMap:GetIndex(x,y)
	local xx
	if self.wrapX then
		xx = x % self.width
	elseif x < 0 or x > self.width - 1 then
		return -1
	else
		xx = x
	end

	if self.wrapY then
		yy = y % self.height
	elseif y < 0 or y > self.height - 1 then
		return -1
	else
		yy = y
	end

	return yy * self.width + xx
end

function FloatMap:GetXYFromIndex(i)
	local x = i % self.width
	local y = (i - x)/self.width
	return x,y
end

--quadrants are labeled
--A B
--D C
function FloatMap:GetQuadrant(x,y)
	if x < self.width/2 then
		if y < self.height/2 then
			return "A"
		else
			return "D"
		end
	else
		if y < self.height/2 then
			return "B"
		else
			return "C"
		end
	end
end

--Gets an index for x and y based on the current
--rect settings. x and y are local to the defined rect.
--Wrapping is assumed in both directions
function FloatMap:GetRectIndex(x,y)
	local xx = x % self.rectWidth
	local yy = y % self.rectHeight

	xx = self.rectX + xx
	yy = self.rectY + yy

	return self:GetIndex(xx,yy)
end

function FloatMap:Normalize()
	--find highest and lowest values
	local maxAlt = -1000.0
	local minAlt = 1000.0
	for i = 0,self.length - 1,1 do
		local alt = self.data[i]
		if alt > maxAlt then
			maxAlt = alt
		end
		if alt < minAlt then
			minAlt = alt
		end

	end
	--subtract minAlt from all values so that
	--all values are zero and above
	for i = 0, self.length - 1, 1 do
		self.data[i] = self.data[i] - minAlt
	end

	--subract minAlt also from maxAlt
	maxAlt = maxAlt - minAlt

	--determine and apply scaler to whole map
	local scaler
	if maxAlt == 0.0 then
		scaler = 0.0
	else
		scaler = 1.0/maxAlt
	end

	for i = 0,self.length - 1,1 do
		self.data[i] = self.data[i] * scaler
	end

end

function FloatMap:GenerateNoise()
	for i = 0,self.length - 1,1 do
		self.data[i] = PWRand()
	end

end

function FloatMap:GenerateBinaryNoise()
	for i = 0,self.length - 1,1 do
		if PWRand() > 0.5 then
			self.data[i] = 1
		else
			self.data[i] = 0
		end
	end

end

function FloatMap:FindThresholdFromPercent(percent, greaterThan, excludeZeros)
	local mapList = {}
	local percentage = percent * 100

	if greaterThan then
		percentage = 100 - percentage
	end

	if percentage >= 100 then
		return 1.01 --whole map
	elseif percentage <= 0 then
		return -0.01 --none of the map
	end

	for i = 0,self.length - 1,1 do
		if not (self.data[i] == 0.0 and excludeZeros) then
			table.insert(mapList,self.data[i])
		end
	end

	table.sort(mapList, function (a,b) return a < b end)
	local threshIndex = math.floor((#mapList * percentage)/100)

	return mapList[threshIndex - 1]

end

function FloatMap:GetLatitudeForY(y)
	local range = mc.topLatitude - mc.bottomLatitude
	return y / self.height * range + mc.bottomLatitude
end

function FloatMap:GetYForLatitude(lat)
	local range = mc.topLatitude - mc.bottomLatitude
	return math.floor(((lat - mc.bottomLatitude) /range * self.height) + 0.5)
end

function FloatMap:GetZone(y)
	local lat = self:GetLatitudeForY(y)
	if y < 0 or y >= self.height then
		return mc.NOZONE
	end
	if lat > mc.polarFrontLatitude then
		return mc.NPOLAR
	elseif lat >= mc.horseLatitudes then
		return mc.NTEMPERATE
	elseif lat >= 0.0 then
		return mc.NEQUATOR
	elseif lat > -mc.horseLatitudes then
		return mc.SEQUATOR
	elseif lat >= -mc.polarFrontLatitude then
		return mc.STEMPERATE
	else
		return mc.SPOLAR
	end
end

function FloatMap:GetYFromZone(zone, bTop)
	if bTop then
		for y=self.height - 1,0,-1 do
			if zone == self:GetZone(y) then
				return y
			end
		end
	else
		for y=0,self.height - 1,1 do
			if zone == self:GetZone(y) then
				return y
			end
		end
	end
	return -1
end

function FloatMap:GetGeostrophicWindDirections(zone)

	if zone == mc.NPOLAR then
		return mc.SW,mc.W
	elseif zone == mc.NTEMPERATE then
		return mc.NE,mc.E
	elseif zone == mc.NEQUATOR then
		return mc.SW,mc.W
	elseif zone == mc.SEQUATOR then
		return mc.NW,mc.W
	elseif zone == mc.STEMPERATE then
		return mc.SE, mc.E
	else
		return mc.NW,mc.W
	end
	return -1,-1
end

function FloatMap:GetGeostrophicPressure(lat)
	local latRange = nil
	local latPercent = nil
	local pressure = nil
	if lat > mc.polarFrontLatitude then
		latRange = 90.0 - mc.polarFrontLatitude
		latPercent = (lat - mc.polarFrontLatitude)/latRange
		pressure = 1.0 - latPercent
	elseif lat >= mc.horseLatitudes then
		latRange = mc.polarFrontLatitude - mc.horseLatitudes
		latPercent = (lat - mc.horseLatitudes)/latRange
		pressure = latPercent
	elseif lat >= 0.0 then
		latRange = mc.horseLatitudes - 0.0
		latPercent = (lat - 0.0)/latRange
		pressure = 1.0 - latPercent
	elseif lat > -mc.horseLatitudes then
		latRange = 0.0 + mc.horseLatitudes
		latPercent = (lat + mc.horseLatitudes)/latRange
		pressure = latPercent
	elseif lat >= -mc.polarFrontLatitude then
		latRange = -mc.horseLatitudes + mc.polarFrontLatitude
		latPercent = (lat + mc.polarFrontLatitude)/latRange
		pressure = 1.0 - latPercent
	else
		latRange = -mc.polarFrontLatitude + 90.0
		latPercent = (lat + 90)/latRange
		pressure = latPercent
	end
	--print(pressure)
	return pressure
end

function FloatMap:ApplyFunction(func)
	for i = 0,self.length - 1,1 do
		self.data[i] = func(self.data[i])
	end
end

function FloatMap:GetRadiusAroundHex(x,y,radius)
	local list = {}
	table.insert(list,{x,y})
	if radius == 0 then
		return list
	end

	local hereX = x
	local hereY = y

	--make a circle for each radius
	for r = 1,radius,1 do
		--start 1 to the west
		hereX,hereY = self:GetNeighbor(hereX,hereY,mc.W)
		if self:IsOnMap(hereX,hereY) then
			table.insert(list,{hereX,hereY})
		end
		--Go r times to the NE
		for z = 1,r,1 do
			hereX, hereY = self:GetNeighbor(hereX,hereY,mc.NE)
			if self:IsOnMap(hereX,hereY) then
				table.insert(list,{hereX,hereY})
			end
		end
		--Go r times to the E
		for z = 1,r,1 do
			hereX, hereY = self:GetNeighbor(hereX,hereY,mc.E)
			if self:IsOnMap(hereX,hereY) then
				table.insert(list,{hereX,hereY})
			end
		end
		--Go r times to the SE
		for z = 1,r,1 do
			hereX, hereY = self:GetNeighbor(hereX,hereY,mc.SE)
			if self:IsOnMap(hereX,hereY) then
				table.insert(list,{hereX,hereY})
			end
		end
		--Go r times to the SW
		for z = 1,r,1 do
			hereX, hereY = self:GetNeighbor(hereX,hereY,mc.SW)
			if self:IsOnMap(hereX,hereY) then
				table.insert(list,{hereX,hereY})
			end
		end
		--Go r times to the W
		for z = 1,r,1 do
			hereX, hereY = self:GetNeighbor(hereX,hereY,mc.W)
			if self:IsOnMap(hereX,hereY) then
				table.insert(list,{hereX,hereY})
			end
		end
		--Go r - 1 times to the NW!!!!!
		for z = 1,r - 1,1 do
			hereX, hereY = self:GetNeighbor(hereX,hereY,mc.NW)
			if self:IsOnMap(hereX,hereY) then
				table.insert(list,{hereX,hereY})
			end
		end
		--one extra NW to set up for next circle
		hereX, hereY = self:GetNeighbor(hereX,hereY,mc.NW)
	end
	return list
end

function FloatMap:GetAverageInHex(x,y,radius)
	local list = self:GetRadiusAroundHex(x,y,radius)
	local avg = 0.0
	for n = 1,#list,1 do
		local hex = list[n]
		local xx = hex[1]
		local yy = hex[2]
		local i = self:GetIndex(xx,yy)
		avg = avg + self.data[i]
	end
	avg = avg/#list

	return avg
end

function FloatMap:GetStdDevInHex(x,y,radius)
	local list = self:GetRadiusAroundHex(x,y,radius)
	local avg = 0.0
	for n = 1,#list,1 do
		local hex = list[n]
		local xx = hex[1]
		local yy = hex[2]
		local i = self:GetIndex(xx,yy)
		avg = avg + self.data[i]
	end
	avg = avg/#list

	local deviation = 0.0
	for n = 1,#list,1 do
		local hex = list[n]
		local xx = hex[1]
		local yy = hex[2]
		local i = self:GetIndex(xx,yy)
		local sqr = self.data[i] - avg
		deviation = deviation + (sqr * sqr)
	end
	deviation = math.sqrt(deviation/ #list)
	return deviation
end

function FloatMap:Smooth(radius)
	local dataCopy = {}
	for y = 0,self.height - 1,1 do
		for x = 0, self.width - 1,1 do
			local i = self:GetIndex(x,y)
			dataCopy[i] = self:GetAverageInHex(x,y,radius)
		end
	end
	self.data = dataCopy
end

function FloatMap:Deviate(radius)
	local dataCopy = {}
	for y = 0,self.height - 1,1 do
		for x = 0, self.width - 1,1 do
			local i = self:GetIndex(x,y)
			dataCopy[i] = self:GetStdDevInHex(x,y,radius)
		end
	end
	self.data = dataCopy
end

function FloatMap:IsOnMap(x,y)
	local i = self:GetIndex(x,y)
	if i == -1 then
		return false
	end
	return true
end

function FloatMap:Save(name)
	print("saving " .. name .. "...")
	local str = self.width .. "," .. self.height
	for i = 0,self.length - 1,1 do
		str = str .. "," .. self.data[i]
	end
	local file = io.open(name,"w+")
	file:write(str)
	file:close()
	print("bitmap saved as " .. name .. ".")
end
------------------------------------------------------------------------
--ElevationMap class
------------------------------------------------------------------------
ElevationMap = inheritsFrom(FloatMap)

function ElevationMap:New(width, height, wrapX, wrapY)
	local new_inst = FloatMap:New(width,height,wrapX,wrapY)
	setmetatable(new_inst, {__index = ElevationMap});	--setup metatable
	return new_inst
end
function ElevationMap:IsBelowSeaLevel(x,y)
	local i = self:GetIndex(x,y)
	if self.data[i] < self.seaLevelThreshold then
		return true
	else
		return false
	end
end
-------------------------------------------------------------------------
--AreaMap class
-------------------------------------------------------------------------
PWAreaMap = inheritsFrom(FloatMap)

function PWAreaMap:New(width,height,wrapX,wrapY)
	local new_inst = FloatMap:New(width,height,wrapX,wrapY)
	setmetatable(new_inst, {__index = PWAreaMap});	--setup metatable

	new_inst.areaList = {}
	new_inst.segStack = {}
	return new_inst
end

function PWAreaMap:Clear()
	--zero map data
	for i = 0,self.width*self.height - 1,1 do
		self.data[i] = 0.0
	end
end

function PWAreaMap:DefineAreas(matchFunction, bDebug)
	--zero map data
	self:Clear()

	self.areaList = {}
	local currentAreaID = 0
	for y = 0, self.height - 1,1 do
		for x = 0, self.width - 1,1 do
			local i = self:GetIndex(x,y)
			if self.data[i] == 0 then
				currentAreaID = currentAreaID + 1
				local area = PWArea:New(currentAreaID,x,y,matchFunction(x,y))
				area.debug = bDebug
				--str = string.format("Filling area %d, matchFunction(x = %d,y = %d) = %s",area.id,x,y,tostring(matchFunction(x,y)))
				--print(str)
				self:FillArea(x,y,area,matchFunction)
				table.insert(self.areaList, area)

			end
		end
	end
end

function PWAreaMap:FillArea(x,y,area,matchFunction)
	--this function will not overwrite other areas, so if matchFunction changes between calls
	--the map data should be cleared before use
	self.segStack = {}
	local seg = LineSeg:New(y,x,x,1)
	Push(self.segStack,seg)
	seg = LineSeg:New(y + 1,x,x,-1)
	Push(self.segStack,seg)
	while #self.segStack > 0 do
		seg = Pop(self.segStack)
		self:ScanAndFillLine(seg,area,matchFunction)
	end
end

function PWAreaMap:ScanAndFillLine(seg,area,matchFunction)

	str = string.format("Processing line y = %d, xLeft = %d, xRight = %d, dy = %d -------",seg.y,seg.xLeft,seg.xRight,seg.dy)
	self:debugPrint(area, str)
	if self:ValidateY(seg.y + seg.dy) == -1 then
		return
	end

	local odd = (seg.y + seg.dy) % 2
	local notOdd = seg.y % 2
	str = string.format("odd = %d, notOdd = %d",odd,notOdd)
	self:debugPrint(area, str)

	local lineFound = 0
	local xStop = nil
	if self.wrapX then
		xStop = 0 - (self.width * 30)
	else
		xStop = -1
	end
	local leftExtreme = nil
	for leftExt = seg.xLeft - odd,xStop + 1,-1 do
		leftExtreme = leftExt --need this saved
		str = string.format("leftExtreme = %d",leftExtreme)
		self:debugPrint(area, str)
		local x = self:ValidateX(leftExtreme)
		local y = self:ValidateY(seg.y + seg.dy)
		local i = self:GetIndex(x,y)
		str = string.format("x = %d, y = %d, area.trueMatch = %s, matchFunction(x,y) = %s",x,y,tostring(area.trueMatch),tostring(matchFunction(x,y)))
		self:debugPrint(area,str)
		if self.data[i] == 0 and area.trueMatch == matchFunction(x,y) then
			self.data[i] = area.id
			area.size = area.size + 1
			self:debugPrint(area,"adding to area")
			lineFound = 1
		else
			--if no line was found, then leftExtreme is fine, but if
			--a line was found going left, then we need to increment
            --xLeftExtreme to represent the inclusive end of the line
			if lineFound == 1 then
				leftExtreme = leftExtreme + 1
				self:debugPrint(area,"line found, adding 1 to leftExtreme")
			end
			break
		end
	end
	if leftExtreme == nil then
		str = "leftExtreme = nil"
	else
		str = string.format("leftExtreme = %d",leftExtreme)
	end
	self:debugPrint(area, str)
	local rightExtreme = nil
	--now scan right to find extreme right, place each found segment on stack
	if self.wrapX then
		xStop = self.width * 20
	else
		xStop = self.width
	end
	for rightExt = seg.xLeft + lineFound - odd,xStop - 1,1 do
		rightExtreme = rightExt --need this saved
		str = string.format("rightExtreme = %d",rightExtreme)
		self:debugPrint(area,str)
		local x = self:ValidateX(rightExtreme)
		local y = self:ValidateY(seg.y + seg.dy)
		local i = self:GetIndex(x,y)
		str = string.format("x = %d, y = %d, area.trueMatch = %s, matchFunction(x,y) = %s",x,y,tostring(area.trueMatch),tostring(matchFunction(x,y)))
		self:debugPrint(area, str)
		if self.data[i] == 0 and area.trueMatch == matchFunction(x,y) then
			self.data[i] = area.id
			area.size = area.size + 1
			self:debugPrint(area,"adding to area")
			if lineFound == 0 then
				lineFound = 1 --starting new line
				leftExtreme = rightExtreme
			end
		elseif lineFound == 1 then --found the right end of a line segment
			self:debugPrint(area,"found right end of line")
			lineFound = 0
			--put same direction on stack
			local newSeg = LineSeg:New(y,leftExtreme,rightExtreme - 1,seg.dy)
			Push(self.segStack,newSeg)
			str = string.format("  pushing y = %d, xLeft = %d, xRight = %d, dy = %d",y,leftExtreme,rightExtreme - 1,seg.dy)
			self:debugPrint(area,str)
			--determine if we must put reverse direction on stack
			if leftExtreme < seg.xLeft - odd or rightExtreme >= seg.xRight + notOdd then
				--out of shadow so put reverse direction on stack
				newSeg = LineSeg:New(y,leftExtreme,rightExtreme - 1,-seg.dy)
				Push(self.segStack,newSeg)
				str = string.format("  pushing y = %d, xLeft = %d, xRight = %d, dy = %d",y,leftExtreme,rightExtreme - 1,-seg.dy)
				self:debugPrint(area,str)
			end
			if(rightExtreme >= seg.xRight + notOdd) then
				break
			end
		elseif lineFound == 0 and rightExtreme >= seg.xRight + notOdd then
			break --past the end of the parent line and no line found
		end
		--continue finding segments
	end
	if lineFound == 1 then --still needing a line to be put on stack
		if leftExtreme ~= nil and rightExtreme ~= nil then		
			--print("still need line segments")
			lineFound = 0
			--put same direction on stack
			local newSeg = LineSeg:New(seg.y + seg.dy,leftExtreme,rightExtreme - 1,seg.dy)
			Push(self.segStack,newSeg)
			str = string.format("  pushing y = %d, xLeft = %d, xRight = %d, dy = %d",seg.y + seg.dy,leftExtreme,rightExtreme - 1,seg.dy)
			--print(str)
			--determine if we must put reverse direction on stack
			if leftExtreme < seg.xLeft - odd or rightExtreme >= seg.xRight + notOdd then
				--out of shadow so put reverse direction on stack
				newSeg = LineSeg:New(seg.y + seg.dy,leftExtreme,rightExtreme - 1,-seg.dy)
				Push(self.segStack,newSeg)
				str = string.format("  pushing y = %d, xLeft = %d, xRight = %d, dy = %d",seg.y + seg.dy,leftExtreme,rightExtreme - 1,-seg.dy)
				--print(str)
			end
		else
			print("seed filler has encountered a problem. Let's pretend it didn't happen")
		end
	end
end

function PWAreaMap:GetAreaByID(id)
	for i = 1,#self.areaList,1 do
		if self.areaList[i].id == id then
			return self.areaList[i]
		end
	end
	error("Can't find area id in AreaMap.areaList")
end

function PWAreaMap:ValidateY(y)
	local yy = nil
	if self.wrapY then
		yy = y % self.height
	elseif y < 0 or y >= self.height then
		return -1
	else
		yy = y
	end
	return yy
end

function PWAreaMap:ValidateX(x)
	local xx = nil
	if self.wrapX then
		xx = x % self.width
	elseif x < 0 or x >= self.width then
		return -1
	else
		xx = x
	end
	return xx
end
function PWAreaMap:debugPrint(area, str)
	if area.debug == true then
		print(str)
	end
end

function PWAreaMap:PrintAreaList()
	for i=1,#self.areaList,1 do
		local id = self.areaList[i].id
		local seedx = self.areaList[i].seedx
		local seedy = self.areaList[i].seedy
		local size = self.areaList[i].size
		local trueMatch = self.areaList[i].trueMatch
		local str = string.format("area id = %d, trueMatch = %s, size = %d, seedx = %d, seedy = %d",id,tostring(trueMatch),size,seedx,seedy)
		print(str)
	end
end
-------------------------------------------------------------------------
--Area class
-------------------------------------------------------------------------
PWArea = inheritsFrom(nil)

function PWArea:New(id,seedx,seedy,trueMatch)
	local new_inst = {}
	setmetatable(new_inst, {__index = PWArea});	--setup metatable

	new_inst.id = id
	new_inst.seedx = seedx
	new_inst.seedy = seedy
	new_inst.trueMatch = trueMatch
	new_inst.size = 0
	new_inst.debug = false

	return new_inst
end
-------------------------------------------------------------------------
--LineSeg class
-------------------------------------------------------------------------
LineSeg = inheritsFrom(nil)

function LineSeg:New(y,xLeft,xRight,dy)
	local new_inst = {}
	setmetatable(new_inst, {__index = LineSeg});	--setup metatable

	new_inst.y = y
	new_inst.xLeft = xLeft
	new_inst.xRight = xRight
	new_inst.dy = dy

	return new_inst
end

-------------------------------------------------------------------------
--RiverMap class
-------------------------------------------------------------------------
RiverMap = inheritsFrom(nil)

function RiverMap:New(elevationMap)
	local new_inst = {}
	setmetatable(new_inst, {__index = RiverMap});

	new_inst.elevationMap = elevationMap
	new_inst.riverData = {}
	for y = 0,new_inst.elevationMap.height - 1,1 do
		for x = 0,new_inst.elevationMap.width - 1,1 do
			local i = new_inst.elevationMap:GetIndex(x,y)
			new_inst.riverData[i] = RiverHex:New(x,y)
		end
	end
	
	new_inst.riverList = nil
	
	return new_inst
end

function RiverMap:GetJunction(x,y,isNorth)
	local i = self.elevationMap:GetIndex(x,y)
	if isNorth then
		return self.riverData[i].northJunction
	else
		return self.riverData[i].southJunction
	end
end

function RiverMap:GetJunctionNeighbor(direction,junction)
	local xx = nil
	local yy = nil
	local ii = nil
	local neighbor = nil
	local odd = junction.y % 2
	if direction == mc.NOFLOW then
		error("can't get junction neighbor in direction NOFLOW")
	elseif direction == mc.WESTFLOW then
		xx = junction.x + odd - 1
		if junction.isNorth then
			yy = junction.y + 1
		else
			yy = junction.y - 1
		end
		ii = self.elevationMap:GetIndex(xx,yy)
		if ii ~= -1 then
			neighbor = self:GetJunction(xx,yy,not junction.isNorth)
			return neighbor
		end
	elseif direction == mc.EASTFLOW then
		xx = junction.x + odd
		if junction.isNorth then
			yy = junction.y + 1
		else
			yy = junction.y - 1
		end
		ii = self.elevationMap:GetIndex(xx,yy)
		if ii ~= -1 then
			neighbor = self:GetJunction(xx,yy,not junction.isNorth)
			return neighbor
		end
	elseif direction == mc.VERTFLOW then
		xx = junction.x
		if junction.isNorth then
			yy = junction.y + 2
		else
			yy = junction.y - 2
		end
		ii = self.elevationMap:GetIndex(xx,yy)
		if ii ~= -1 then
			neighbor = self:GetJunction(xx,yy,not junction.isNorth)
			return neighbor
		end
	end

	return nil --neighbor off map
end

--Get the west or east hex neighboring this junction
function RiverMap:GetRiverHexNeighbor(junction,westNeighbor)
	local xx = nil
	local yy = nil
	local ii = nil
	local odd = junction.y % 2
	if junction.isNorth then
		yy = junction.y + 1
	else
		yy = junction.y - 1
	end
	if westNeighbor then
		xx = junction.x + odd - 1
	else
		xx = junction.x + odd
	end

	ii = self.elevationMap:GetIndex(xx,yy)
	if ii ~= -1 then
		return self.riverData[ii]
	end

	return nil
end

function RiverMap:GetJunctionsAroundHex(hex)
--gets all junctions touching hex
	local junctionList = {}
	if hex.northJunction ~= nil then
		table.insert(junctionList,hex.northJunction)
	end
	if hex.southJunction ~= nil then
		table.insert(junctionList,hex.southJunction)
	end
	--now get east and west neighbors of both
	if hex.northJunction ~= nil then
		--print("northJunction",hex.northJunction,hex.northJunction.x,hex.northJunction.y)
		local nJunc = self:GetJunctionNeighbor(mc.WESTFLOW,hex.northJunction)
		if nJunc ~= nil then
			table.insert(junctionList,nJunc)
		end
	end
	
	if hex.northJunction ~= nil then
		nJunc = self:GetJunctionNeighbor(mc.EASTFLOW,hex.northJunction)
		if nJunc ~= nil then
			table.insert(junctionList,nJunc)
		end
	end

	if hex.southJunction ~= nil then
		nJunc = self:GetJunctionNeighbor(mc.WESTFLOW,hex.southJunction)
		if nJunc ~= nil then
			table.insert(junctionList,nJunc)
		end
	end
	
	if hex.southJunction ~= nil then
		nJunc = self:GetJunctionNeighbor(mc.EASTFLOW,hex.southJunction)
		if nJunc ~= nil then
			table.insert(junctionList,nJunc)
		end
	end
	
	return junctionList
end

function RiverMap:SetJunctionAltitudes()
	for y = 0,self.elevationMap.height - 1,1 do
		for x = 0,self.elevationMap.width - 1,1 do
			local i = self.elevationMap:GetIndex(x,y)
			local vertAltitude = self.elevationMap.data[i]
			local westAltitude = nil
			local eastAltitude = nil
			local vertNeighbor = self.riverData[i]
			local westNeighbor = nil
			local eastNeighbor = nil
			local xx = nil
			local yy = nil
			local ii = nil

			--first do north
			westNeighbor = self:GetRiverHexNeighbor(vertNeighbor.northJunction,true)
			eastNeighbor = self:GetRiverHexNeighbor(vertNeighbor.northJunction,false)

			if westNeighbor ~= nil then
				ii = self.elevationMap:GetIndex(westNeighbor.x,westNeighbor.y)
			else
				ii = -1
			end

			if ii ~= -1 then
				westAltitude = self.elevationMap.data[ii]
			else
				westAltitude = vertAltitude
			end

			if eastNeighbor ~= nil then
				ii = self.elevationMap:GetIndex(eastNeighbor.x, eastNeighbor.y)
			else
				ii = -1
			end

			if ii ~= -1 then
				eastAltitude = self.elevationMap.data[ii]
			else
				eastAltitude = vertAltitude
			end

			vertNeighbor.northJunction.altitude = math.min(math.min(vertAltitude,westAltitude),eastAltitude)

			--then south
			westNeighbor = self:GetRiverHexNeighbor(vertNeighbor.southJunction,true)
			eastNeighbor = self:GetRiverHexNeighbor(vertNeighbor.southJunction,false)

			if westNeighbor ~= nil then
				ii = self.elevationMap:GetIndex(westNeighbor.x,westNeighbor.y)
			else
				ii = -1
			end

			if ii ~= -1 then
				westAltitude = self.elevationMap.data[ii]
			else
				westAltitude = vertAltitude
			end

			if eastNeighbor ~= nil then
				ii = self.elevationMap:GetIndex(eastNeighbor.x, eastNeighbor.y)
			else
				ii = -1
			end

			if ii ~= -1 then
				eastAltitude = self.elevationMap.data[ii]
			else
				eastAltitude = vertAltitude
			end

			vertNeighbor.southJunction.altitude = math.min(math.min(vertAltitude,westAltitude),eastAltitude)
		end
	end
end

function RiverMap:isLake(junction)

	--first exclude the map edges that don't have neighbors
	if junction.y == 0 and junction.isNorth == false then
		return false
	elseif junction.y == self.elevationMap.height - 1 and junction.isNorth == true then
		return false
	end

	--exclude altitudes below sea level
	if junction.altitude < self.elevationMap.seaLevelThreshold then
		return false
	end

	--print(string.format("junction = (%d,%d) N = %s, alt = %f",junction.x,junction.y,tostring(junction.isNorth),junction.altitude))

	local vertNeighbor = self:GetJunctionNeighbor(mc.VERTFLOW,junction)
	local vertAltitude = nil
	if vertNeighbor == nil then
		vertAltitude = junction.altitude
		--print("--vertNeighbor == nil")
	else
		vertAltitude = vertNeighbor.altitude
		--print(string.format("--vertNeighbor = (%d,%d) N = %s, alt = %f",vertNeighbor.x,vertNeighbor.y,tostring(vertNeighbor.isNorth),vertNeighbor.altitude))
	end

	local westNeighbor = self:GetJunctionNeighbor(mc.WESTFLOW,junction)
	local westAltitude = nil
	if westNeighbor == nil then
		westAltitude = junction.altitude
		--print("--westNeighbor == nil")
	else
		westAltitude = westNeighbor.altitude
		--print(string.format("--westNeighbor = (%d,%d) N = %s, alt = %f",westNeighbor.x,westNeighbor.y,tostring(westNeighbor.isNorth),westNeighbor.altitude))
	end

	local eastNeighbor = self:GetJunctionNeighbor(mc.EASTFLOW,junction)
	local eastAltitude = nil
	if eastNeighbor == nil then
		eastAltitude = junction.altitude
		--print("--eastNeighbor == nil")
	else
		eastAltitude = eastNeighbor.altitude
		--print(string.format("--eastNeighbor = (%d,%d) N = %s, alt = %f",eastNeighbor.x,eastNeighbor.y,tostring(eastNeighbor.isNorth),eastNeighbor.altitude))
	end

	local lowest = math.min(vertAltitude,math.min(westAltitude,math.min(eastAltitude,junction.altitude)))

	if lowest == junction.altitude then
		--print("--is lake")
		return true
	end
	--print("--is not lake")
	return false
end

function RiverMap:GetNeighborAverage(junction)
	local count = 0
	local vertNeighbor = self:GetJunctionNeighbor(mc.VERTFLOW,junction)
	local vertAltitude = nil
	if vertNeighbor == nil then
		vertAltitude = 0
	else
		vertAltitude = vertNeighbor.altitude
		count = count +1
	end

	local westNeighbor = self:GetJunctionNeighbor(mc.WESTFLOW,junction)
	local westAltitude = nil
	if westNeighbor == nil then
		westAltitude = 0
	else
		westAltitude = westNeighbor.altitude
		count = count +1
	end

	local eastNeighbor = self:GetJunctionNeighbor(mc.EASTFLOW,junction)
	local eastAltitude = nil
	if eastNeighbor == nil then
		eastAltitude = 0
	else
		eastAltitude = eastNeighbor.altitude
		count = count +1
	end

	local lowestNeighbor = eastAltitude
	if westAltitude < lowestNeighbor then lowestNeighbor = westAltitude end
	if vertAltitude ~= 0 and vertAltitude < lowestNeighbor then lowestNeighbor = vertAltitude end

	--local avg = (vertAltitude + westAltitude + eastAltitude)/count

	return lowestNeighbor+0.0000001
end

--this function alters the drainage pattern. written by Bobert13
function RiverMap:SiltifyLakes()
	local Time3 = os.clock()
	local lakeList = {}
	local onQueueMapNorth = {}
	local onQueueMapSouth = {}

	for i=0,elevationMap.length-1,1 do
		if self:isLake(self.riverData[i].northJunction) then
			table.insert(lakeList,self.riverData[i].northJunction)
			onQueueMapNorth[i] = true
		else
			onQueueMapNorth[i] = false
		end
		if self:isLake(self.riverData[i].southJunction) then
			table.insert(lakeList,self.riverData[i].southJunction)
			onQueueMapSouth[i] = true
		else
			onQueueMapSouth[i] = false
		end
	end


	local iterations = 0
	--print(string.format("Initial lake count = %d",#lakeList))
	while #lakeList > 0 do
		iterations = iterations + 1
		if iterations > 100000000 then
			--debugOn = true
			print("###ERROR### - Endless loop in lake siltification.")
			break
		end

		local junction = table.remove(lakeList)
		local i = elevationMap:GetIndex(junction.x,junction.y)
		if junction.isNorth then
			onQueueMapNorth[i] = false
		else
			onQueueMapSouth[i] = false
		end

		-- local avg = self:GetNeighborAverage(junction)
		-- if avg < junction.altitude + 0.0001 then --using == in fp comparison is precarious and unpredictable due to sp vs. dp floats, rounding, and all that nonsense. =P
			-- while self:isLake(junction) do
				-- junction.altitude = junction.altitude + 0.0001
			-- end
		-- else
			-- junction.altitude = avg
		-- end

		junction.altitude = junction.altitude + self:GetNeighborAverage(junction)

		-- if self:isLake(junction) then
			-- print("Oh bother")
		-- end

		for dir = mc.WESTFLOW,mc.VERTFLOW,1 do
			local neighbor = self:GetJunctionNeighbor(dir,junction)
			if neighbor ~= nil and self:isLake(neighbor) then
				local ii = elevationMap:GetIndex(neighbor.x,neighbor.y)
				if neighbor.isNorth == true and onQueueMapNorth[ii] == false then
					table.insert(lakeList,neighbor)
					onQueueMapNorth[ii] = true
				elseif neighbor.isNorth == false and onQueueMapSouth[ii] == false then
					table.insert(lakeList,neighbor)
					onQueueMapSouth[ii] = true
				end
			end
		end
	end
	print(string.format("Siltified Lakes in %.4f seconds over %d iterations. - Brought to you by Bobert13",os.clock()-Time3,iterations))

end

function RiverMap:RecreateNewLakes()

	self.lakesToAdd = self.elevationMap.height * self.elevationMap.width * mc.landPercent * mc.lakePercent
	self.lakesAdded = 0
	self.currentLakeID = 1

	local riverHexList = {}
	for i=0,self.elevationMap.height * self.elevationMap.width - 1,1 do
		if self.elevationMap.data[i] > elevationMap.seaLevelThreshold then
			self.riverData[i].rainfall = rainfallMap.data[i]
			table.insert(riverHexList,self.riverData[i])
		end
	end
	
	table.sort(riverHexList, function (a,b) return a.rainfall > b.rainfall end)--most first
	
	local portion = math.floor(#riverHexList/4)
	for i=0,portion,1 do
		table.remove(riverHexList)
	end
	
	ShuffleList(riverHexList)
	
	for i=1,#riverHexList do
		if self.lakesAdded < self.lakesToAdd then
			local thisHex = riverHexList[i]
			if self:validLakeHex(thisHex) then
				local growthQueue = {}
				local lakeList = {}
				self.currentLakeSize = 0
				local lakeSize = self:getRandomLakeSize()
				self:growLake(thisHex,lakeSize,lakeList,growthQueue)
				while #growthQueue > 0 do
					local nextLake = table.remove(growthQueue,1)	
					self:growLake(nextLake,lakeSize,lakeList, growthQueue)
				end
				--process junctions for all lake tiles
				--first find lowest junction
				local lowestJunction = nil
				for a=1,#lakeList do
					local thisLake = lakeList[a]
					local thisLowest = self:getLowestJunctionAroundHex(thisLake)
					if lowestJunction == nil or lowestJunction.altitude > thisLowest.altitude then
						lowestJunction = thisLowest
					end
				end
				--set up outflow
				lowestJunction.isOutflow = true
				local validList = self:GetValidFlows(lowestJunction)
				if #validList > 0 and #validList < 2 then
					lowestJunction.flow = validList[1]
				else
					print("length of valid list",#validList)
					error("Bad assumption made. Lake outflow has less than 1 or more than 2 valid flows")
				end
				--print("outflow",lowestJunction:_tostring())
				--then update all junctions with outflow
				for a=1,#lakeList do
					local thisLake = lakeList[a]
					self:setOutflowForLakeHex(thisLake,lowestJunction)				
				end
				
				self.currentLakeID = self.currentLakeID + 1
			end
		end
	end
end

function RiverMap:growLake(lakeHex,lakeSize,lakeList, growthQueue)
--Creates a lake here and places valid neighbors on the queue for later growth stages
	--return if lake has met size reqs
	if self.currentLakeSize >= lakeSize or self.lakesAdded >= self.lakesToAdd then
		return
	end
		
	--lake has grown, increase size
	lakeHex.lakeID = self.currentLakeID
	self.currentLakeSize = self.currentLakeSize + 1
	self.lakesAdded = self.lakesAdded + 1
	--print(string.format("Placed lake tile at %d, %d, lakeID = %d",lakeHex.x,lakeHex.y,lakeHex.lakeID))
	table.insert(lakeList,lakeHex)
	
	--choose random neighbors to put on queue
	local neighbors = GetRadiusAroundCell(lakeHex.x,lakeHex.y,1)
	for i,nIndex in ipairs(neighbors) do
		local neighbor = self.riverData[nIndex]
		--print("neighbor",neighbor.x,neighbor.y)
		if self:validLakeHex(neighbor) then
			local dice = PWRandint(1,3)
			if dice == 1 then
				--print("adding to growth queue",neighbor,neighbor.x,neighbor.y)
				table.insert(growthQueue,neighbor)
			end
		end
	end
	
end

function RiverMap:getLowestJunctionAroundHex(lakeHex)

	local lowestJunction = nil
	local nJunctionList = self:GetJunctionsAroundHex(lakeHex)
	
	--print("for lake hex",lakeHex.x,lakeHex.y)
	for i,nJunc in ipairs(nJunctionList) do
		--print("juncs around",nJunc:_tostring())
		if lowestJunction == nil or lowestJunction.altitude > nJunc.altitude then
			lowestJunction = nJunc
		end	
	end
	return lowestJunction
end

function RiverMap:setOutflowForLakeHex(lakeHex, outflow)

	local nJunctionList = self:GetJunctionsAroundHex(lakeHex)
	for i,nJunc in ipairs(nJunctionList) do
		--skip actual outflow
		if not nJunc.isOutflow then
			nJunc.submerged = true
			nJunc.flow = mc.NOFLOW
			nJunc.outflow = outflow
		end
	end

end

function RiverMap:getRandomLakeSize()
	--puts a bell curve on desired lake size
	local dice1 = PWRandint(1,3)
	local dice2 = PWRandint(0,3)
	return dice1 + dice2
end

function RiverMap:validLakeHex(lakeHex)
--a valid lake hex must not be protected and must not be adjacent to
--ocean or lake with different lake ID
	local ii = self.elevationMap:GetIndex(lakeHex.x,lakeHex.y)
	
	--can't be on a volcano
	local plot = Map.GetPlotByIndex(ii)
	if plot:GetFeatureType() ~= g_FEATURE_NONE then
		return false;
	end
	
	local valid = true --assume true until problem occurs
	cellList = GetRadiusAroundCell(lakeHex.x, lakeHex.y, 1)
	for n=1,#cellList do
		local i = cellList[n]
		nHex = self.riverData[i]
		if self.elevationMap.data[i] < elevationMap.seaLevelThreshold then
			valid = false
		elseif nHex.lakeID ~= -1 and nHex.lakeID ~= self.currentLakeID then
			valid = false
		end
	end
	return valid
end

function RiverMap:getInitialLake(junction, prospectiveflow)
	local lakeHex
	local vertIndex = elevationMap:GetIndex(junction.x,junction.y)
	
	if prospectiveflow == mc.VERTFLOW then
		lakeHex = self.riverData[vertIndex]
	elseif prospectiveflow == mc.WESTFLOW then
		local eastNeighborHex = self:GetRiverHexNeighbor(junction,false)
		lakeHex = eastNeighborHex		
	elseif prospectiveflow == mc.EASTFLOW then
		local westNeighborHex = self:GetRiverHexNeighbor(junction,true)
		lakeHex = westNeighborHex
	end
	return lakeHex

end

function RiverMap:SetFlowDestinations()
	local junctionList = {}
	for y = 0,self.elevationMap.height - 1,1 do
		for x = 0,self.elevationMap.width - 1,1 do
			local i = self.elevationMap:GetIndex(x,y)
			table.insert(junctionList,self.riverData[i].northJunction)
			table.insert(junctionList,self.riverData[i].southJunction)
		end
	end

	table.sort(junctionList,function (a,b) return a.altitude > b.altitude end)
	print("junctionList length",#junctionList)
	local validFlowCount = 0
	for n=1,#junctionList do
		local junction = junctionList[n]
		local validList = self:GetValidFlows(junction)
		--don't overwrite lake outflows
		if not junction.isOutflow and not junction.submerged then
			if #validList > 0 then
				local choice = PWRandint(1,#validList)
				junction.flow = validList[choice]
				validFlowCount = validFlowCount + 1
			else
				junction.flow = mc.NOFLOW
			end
		end
	end
	print("validFlowCount=",validFlowCount)
end

function RiverMap:GetValidFlows(junction)
	local validList = {}
	for dir = mc.WESTFLOW,mc.VERTFLOW,1 do
		neighbor = self:GetJunctionNeighbor(dir,junction)
		if neighbor ~= nil and neighbor.altitude < junction.altitude then
			table.insert(validList,dir)
		end
	end
	return validList
end

function RiverMap:IsTouchingOcean(junction)

	-- if junction == nil or elevationMap:IsBelowSeaLevel(junction.x,junction.y) then
		-- return true
	-- end
	-- local westNeighbor = self:GetRiverHexNeighbor(junction,true)
	-- local eastNeighbor = self:GetRiverHexNeighbor(junction,false)

	-- if westNeighbor == nil or elevationMap:IsBelowSeaLevel(westNeighbor.x,westNeighbor.y) then
		-- return true
	-- end
	-- if eastNeighbor == nil or elevationMap:IsBelowSeaLevel(eastNeighbor.x,eastNeighbor.y) then
		-- return true
	-- end\
	--print("junction x and y",junction.x, junction.y)
	local i = elevationMap:GetIndex(junction.x, junction.y)
	local plot = Map.GetPlotByIndex(i)
	--print(tostring(plot:IsWater()))
	if junction == nil or plot:IsWater() then
		return true
	end
	local westNeighbor = self:GetRiverHexNeighbor(junction,true)
	local eastNeighbor = self:GetRiverHexNeighbor(junction,false)
	local wPlot = nil
	local ePlot = nil
	if westNeighbor ~= nil then
		local wi = elevationMap:GetIndex(westNeighbor.x, westNeighbor.y)
		wPlot = Map.GetPlotByIndex(wi)
	end
	if westNeighbor == nil or wPlot:IsWater() then
		return true
	end
	if eastNeighbor ~= nil then
		local ei = elevationMap:GetIndex(eastNeighbor.x, eastNeighbor.y)
		ePlot = Map.GetPlotByIndex(ei)
	end
	if eastNeighbor == nil or ePlot:IsWater() then
		return true
	end

	return false
end

function RiverMap:SetRiverSizes(rainfallMap)
	local junctionList = {} --only include junctions not touching ocean in this list
	for y = 0,self.elevationMap.height - 1,1 do
		for x = 0,self.elevationMap.width - 1,1 do
			local i = self.elevationMap:GetIndex(x,y)
			if self.riverData[i].northJunction ~= nil and not self:IsTouchingOcean(self.riverData[i].northJunction) then
				table.insert(junctionList,self.riverData[i].northJunction)
			end
			if self.riverData[i].southJunction ~= nil and not self:IsTouchingOcean(self.riverData[i].southJunction) then
				table.insert(junctionList,self.riverData[i].southJunction)
			end
		end
	end

	--highest altitude first
	table.sort(junctionList,function (a,b) return a.altitude > b.altitude end)
	--print("junctionList length",#junctionList)

	for n=1,#junctionList do
		local junction = junctionList[n]
		local nextJunction = junction
		local i = self.elevationMap:GetIndex(junction.x,junction.y)
		local courseLength = 0
		--print("rainfall",rainfallMap.data[i])
		local rainToAdd = rainfallMap.data[i]
		while true do
			if nextJunction.isOutflow then
				rainToAdd = rainToAdd * 2.0
				--print("doubling rain for outflow, now ", rainToAdd)
			end
			nextJunction.size = nextJunction.size + rainToAdd
			courseLength = courseLength + 1
			--print(nextJunction:_tostring())
			if nextJunction.flow == mc.NOFLOW or self:IsTouchingOcean(nextJunction) then
				if nextJunction.isOutflow == false then
					nextJunction.flow = mc.NOFLOW --make sure it has no flow if touching water, unless it's an outflow
					if nextJunction.outflow == nil then --if there is no outflow to jump to, this is the end
						--print("course length", courseLength, n)
						break
					end
				end
			end
			nextJunction = self:GetNextJunctionInFlow(nextJunction)
			if nextJunction == nil then
				break
			end
		end
	end

	--now sort by river size to find river threshold
	table.sort(junctionList,function (a,b) return a.size > b.size end)
	-- for n=1,#junctionList do
		-- print("junction size",junctionList[n].size)
	-- end
	
	local riverIndex = math.floor(mc.riverPercent * #junctionList)
	--print(string.format("threshold index = %d",riverIndex))
	self.riverThreshold = junctionList[riverIndex].size
	print(string.format("river threshold = %f",self.riverThreshold))

	--riverMap:Save("riverSizeMap.csv")
end

function RiverMap:GetNextJunctionInFlow(junction)
	--use outflow if valid
	if junction.outflow ~= nil then
		return junction.outflow
	end
	return self:GetJunctionNeighbor(junction.flow,junction)
end

function RiverMap:IsRiverSource(junction)
	--this function must be called AFTER sizes are determined.
	
	--are we big enough to be a river?
	if junction.size <= self.riverThreshold then
		return false
	end
	--am I a lake outflow?
	if junction.isOutflow then
		return true --outflows are also sources
	end
	
	--am i touching water?
	if self:IsTouchingOcean(junction) then
		return false
	end
	
	--are my predescessors that flow into me big enough to be rivers? 
	local westJunction = self:GetJunctionNeighbor(mc.WESTFLOW,junction)
	if westJunction ~= nil and westJunction.flow == mc.EASTFLOW and westJunction.size > self.riverThreshold then
		return false
	end
	local eastJunction = self:GetJunctionNeighbor(mc.EASTFLOW,junction)
	if eastJunction ~= nil and eastJunction.flow == mc.WESTFLOW and eastJunction.size > self.riverThreshold then
		return false
	end
	local vertJunction = self:GetJunctionNeighbor(mc.VERTFLOW,junction)
	if vertJunction ~= nil and vertJunction.flow == mc.VERTFLOW and vertJunction.size > self.riverThreshold then
		return false
	end
	
	--no big rivers flowing into me, so I must be a source
	return true

end

function RiverMap:CreateRiverList()
	--this list describes rivers from source to  water, (lake or ocean)
	--with longer rivers overwriting the rawID of shorter riverSizeMap
	--riverID used in game is a different variable. Every river source
	--has a rawID but not all with end up with a riverID
	self.riverList = {}
	currentRawID = 0
	--river sources in self.riverList
	for y = 0,self.elevationMap.height - 1,1 do
		for x = 0,self.elevationMap.width - 1,1 do
			local i = self.elevationMap:GetIndex(x,y)
			if self:IsRiverSource(self.riverData[i].northJunction) then
				local nRiver = River:New(self.riverData[i].northJunction,currentRawID)
				table.insert(self.riverList,nRiver)
				currentRawID = currentRawID + 1
			end
			
			if self:IsRiverSource(self.riverData[i].southJunction) then
				local sRiver = River:New(self.riverData[i].southJunction,currentRawID)
				table.insert(self.riverList,sRiver)
				currentRawID = currentRawID + 1
			end
		end
	end
	--print(string.format("river threshold = %f",self.riverThreshold))
	print(string.format("number of river sources found = %d",#self.riverList))
	
	--idea: if rivers grow at one length per loop, you can allow late comers to overwrite
	--their predecessors, as they will always be the longer river. Just make sure to clarify 
	--that river length is not the length of a particular rawID, but length from source 
	--to the ocean
	local stillGrowing = true
	while stillGrowing do
		stillGrowing = false --assume this until something grows
		for n=1,#self.riverList do
			local river = self.riverList[n]
			local lastJunc = river.junctionList[#river.junctionList]
			if lastJunc.flow ~= mc.NOFLOW then
				--print(string.format("lastJunc = %s",lastJunc:_tostring()))
				local nextJunc = self:GetJunctionNeighbor(lastJunc.flow, lastJunc)
				if nextJunc ~= nil then
					nextJunc.rawID = lastJunc.rawID --overwrite whatever was there
					river:Add(nextJunc) --Add to river for now, but all will be deleted before next pass
					--print(string.format("nextJunc = %s",nextJunc:_tostring()))
					nextJunc:AddParent(lastJunc)
					stillGrowing = true
				end
				
			end
		end
	end
	
	self.riverList = {} --junction rawID's are set, now start over from scratch
	currentRawID = 0
	--river sources in self.riverList again
	for y = 0,self.elevationMap.height - 1,1 do
		for x = 0,self.elevationMap.width - 1,1 do
			local i = self.elevationMap:GetIndex(x,y)
			if self:IsRiverSource(self.riverData[i].northJunction) then
				local nRiver = River:New(self.riverData[i].northJunction,currentRawID)
				table.insert(self.riverList,nRiver)
				currentRawID = currentRawID + 1
			end
			
			if self:IsRiverSource(self.riverData[i].southJunction) then
				local sRiver = River:New(self.riverData[i].southJunction,currentRawID)
				table.insert(self.riverList,sRiver)
				currentRawID = currentRawID + 1
			end
		end
	end

	--for this pass add to river list until rawID changes
	for n=1,#self.riverList do
		local river = self.riverList[n]
		local lastJunc = river.junctionList[#river.junctionList]
		--print("starting river definition")
		while true do
			if lastJunc.flow ~= mc.NOFLOW then
				--print(string.format("lastJunc = %s",lastJunc:_tostring()))
				local nextJunc = self:GetJunctionNeighbor(lastJunc.flow, lastJunc)
				if nextJunc ~= nil then
					if nextJunc.rawID == lastJunc.rawID then
						river:Add(nextJunc)
						--print(string.format("added nextJunc = %s",nextJunc:_tostring()))
						lastJunc = nextJunc
					else
						break
					end
				else
					break
				end
			else
				break
			end
		end
	end
	
	--now strip out all the shorties
	ArrayRemove(self.riverList,longEnough)

end

function longEnough(riverList, i)
	--test if a river is long enough to exist, but keep all lake outflows
	local river = riverList[i]
	if #river.junctionList >= mc.minRiverLength or river.sourceJunction.isOutflow then
		return true
	end
	return false
end

function RiverMap:AssignRiverIDs()
	--sort river list by largest first 
	table.sort(self.riverList,function (a,b) return #a.junctionList > #b.junctionList end)
	
	local currentRiverID = 0 --this should closely match river index witch should be id+1
	for i=1,#self.riverList do
		local river = self.riverList[i]
		river.riverID = currentRiverID
		for n=1,#river.junctionList do
			river.junctionList[n].ID = currentRiverID
		end
		currentRiverID = currentRiverID + 1
	end
	
	--report findings
	for i=1,#self.riverList do
		local riv = self.riverList[i]
		if riv.riverID ~= nil then
			local mouth = riv.junctionList[#riv.junctionList]
			print(string.format("river ID %d length=%d with mouth at %d, %d, isNorth = %s",riv.riverID,#riv.junctionList,mouth.x,mouth.y,tostring(mouth.isNorth)))
			for n=1,#riv.junctionList do
				--print(riv.junctionList[n]:_tostring())
			end
		end
	end
	print(string.format("river ID's assigned = %d",currentRiverID))
end


-- function RiverMap:AssignRiverIDs()
	-- --sort river list by largest first so that shorter rivers can see that ID already exists
	-- table.sort(self.riverList,function (a,b) return #a.junctionList > #b.junctionList end)
	
	-- --this loop IDs the river and its tributaries with the same ID
	-- local currentRiverID = 0
	-- for i=1,#self.riverList do
		-- local river = self.riverList[i]
		-- if self:paddleUpRiver(river.junctionList[#river.junctionList],currentRiverID) then
			-- river.riverID = currentRiverID
			-- currentRiverID = currentRiverID + 1
		-- end
	-- end
	
	-- --report findings
	-- for i=1,#self.riverList do
		-- local riv = self.riverList[i]
		-- if riv.riverID ~= nil then
			-- local mouth = riv.junctionList[#riv.junctionList]
			-- print(string.format("river ID %d with mouth at %d, %d, isNorth = %s",riv.riverID,mouth.x,mouth.y,tostring(mouth.isNorth)))
		-- end
	-- end
	-- print(string.format("river ID's assigned = %d",currentRiverID))
-- end

-- function RiverMap:paddleUpRiver(junction, ID)
	-- --if ID already assigned, return false
	-- if junction.ID ~= nil then
		-- return false
	-- end
	-- junction.ID = ID
	-- for i=1,#junction.parentJunctions do
		-- local parent = junction.parentJunctions[i]
		-- self:paddleUpRiver(parent,ID)
	-- end
	-- return true
-- end
function RiverMap:GetRiverHexForJunction(junction)
	local riverHex
	if junction.isNorth then
		if junction.flow == mc.VERTFLOW then
			riverHex = riverMap:GetRiverHexNeighbor(junction,true)
		elseif junction.flow == mc.WESTFLOW then
			riverHex = riverMap:GetRiverHexNeighbor(junction,true)
		elseif junction.flow == mc.EASTFLOW then
			riverHex = riverMap:GetRiverHexNeighbor(junction,false)
		end
	else
		if junction.flow == mc.VERTFLOW then
			riverHex = riverMap:GetRiverHexNeighbor(junction,true)
		elseif junction.flow == mc.WESTFLOW then
			local i = elevationMap:GetIndex(junction.x,junction.y)
			riverHex = self.riverData[i]
		elseif junction.flow == mc.EASTFLOW then
			local i = elevationMap:GetIndex(junction.x,junction.y)
			riverHex = self.riverData[i]
		end
	end
	return riverHex
end
--This function returns the flow directions needed by civ
function RiverMap:GetFlowDirections(x,y)
	--print(string.format("Get flow dirs for %d,%d",x,y))
	local i = elevationMap:GetIndex(x,y)

	local WOfRiver = FlowDirectionTypes.NO_FLOWDIRECTION
	local WID = nil
	local xx,yy = elevationMap:GetNeighbor(x,y,mc.NE)
	local ii = elevationMap:GetIndex(xx,yy)
	if ii ~= -1 and self.riverData[ii].southJunction.flow == mc.VERTFLOW and self.riverData[ii].southJunction.size > self.riverThreshold and self.riverData[ii].southJunction.ID ~= nil then
		--print(string.format("--NE(%d,%d) %s",xx,yy,self.riverData[ii].southJunction:_tostring()))
		WOfRiver = FlowDirectionTypes.FLOWDIRECTION_SOUTH
		WID = self.riverData[ii].southJunction.ID
	end
	xx,yy = elevationMap:GetNeighbor(x,y,mc.SE)
	ii = elevationMap:GetIndex(xx,yy)
	if ii ~= -1 and self.riverData[ii].northJunction.flow == mc.VERTFLOW and self.riverData[ii].northJunction.size > self.riverThreshold and self.riverData[ii].northJunction.ID ~= nil then
		--print(string.format("--SE(%d,%d) %s",xx,yy,self.riverData[ii].northJunction:_tostring()))
		WOfRiver = FlowDirectionTypes.FLOWDIRECTION_NORTH
		WID = self.riverData[ii].northJunction.ID
	end

	local NWOfRiver = FlowDirectionTypes.NO_FLOWDIRECTION
	local NWID = nil
	xx,yy = elevationMap:GetNeighbor(x,y,mc.SE)
	ii = elevationMap:GetIndex(xx,yy)
	if ii ~= -1 and self.riverData[ii].northJunction.flow == mc.WESTFLOW and self.riverData[ii].northJunction.size > self.riverThreshold and self.riverData[ii].northJunction.ID ~= nil then
		--print(string.format("--SE(%d,%d) %s",xx,yy,self.riverData[ii].northJunction:_tostring()))
		NWOfRiver = FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST
		NWID = self.riverData[ii].northJunction.ID
	end
	if self.riverData[i].southJunction.flow == mc.EASTFLOW and self.riverData[i].southJunction.size > self.riverThreshold and self.riverData[i].southJunction.ID ~= nil then
		--print(string.format("(%d,%d) %s",x,y,self.riverData[i].southJunction:_tostring()))
		NWOfRiver = FlowDirectionTypes.FLOWDIRECTION_NORTHEAST
		NWID = self.riverData[i].southJunction.ID
	end

	local NEOfRiver = FlowDirectionTypes.NO_FLOWDIRECTION
	local NEID = nil
	xx,yy = elevationMap:GetNeighbor(x,y,mc.SW)
	ii = elevationMap:GetIndex(xx,yy)
	if ii ~= -1 and self.riverData[ii].northJunction.flow == mc.EASTFLOW and self.riverData[ii].northJunction.size > self.riverThreshold and self.riverData[ii].northJunction.ID ~= nil then
		--print(string.format("--SW(%d,%d) %s",xx,yy,self.riverData[ii].northJunction:_tostring()))
		NEOfRiver = FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST
		NEID = self.riverData[ii].northJunction.ID
	end
	if self.riverData[i].southJunction.flow == mc.WESTFLOW and self.riverData[i].southJunction.size > self.riverThreshold and self.riverData[i].southJunction.ID ~= nil then
		--print(string.format("(%d,%d) %s",x,y,self.riverData[i].southJunction:_tostring()))
		NEOfRiver = FlowDirectionTypes.FLOWDIRECTION_NORTHWEST
		NEID = self.riverData[i].southJunction.ID
	end
	
	--none of this works if river list has been sorted!
	local ID = nil
	--use ID of longest river
	local WIDriver = nil
	local NWIDriver = nil
	local NEIDriver = nil
	local WIDLength = -1
	local NWIDLength = -1
	local NEIDLength = -1
	
	if WID ~= nil then
		WIDriver = self.riverList[WID+1]
		WIDLength = #WIDriver.junctionList
	end
	if NWID ~= nil then
		NWIDriver = self.riverList[NWID+1]
		NWIDLength = #NWIDriver.junctionList
	end
	if NEID ~= nil then
		NEIDriver = self.riverList[NEID+1]
		NEIDLength = #NEIDriver.junctionList
	end
	
	--fight between WID and NWID
	if WIDLength >= NWIDLength  and WIDLength >= NEIDLength then
		ID = WID
	else
		if NWIDLength >= WIDLength and NWIDLength >= NEIDLength then
			ID = NWID
		else
			ID = NEID --only choice left
		end
	end
	
	if WIDLength == -1 and NWIDLength == -1 and NEIDLength == -1 then
		ID = nil --none of these rivers are valid
	end
	
	return WOfRiver,NWOfRiver,NEOfRiver,ID
end
-------------------------------------------------------------------------
--RiverHex class
-------------------------------------------------------------------------
RiverHex = inheritsFrom(nil)

function RiverHex:New(x, y)
	local new_inst = {}
	setmetatable(new_inst, {__index = RiverHex});

	new_inst.x = x
	new_inst.y = y
	new_inst.northJunction = RiverJunction:New(x,y,true)
	new_inst.southJunction = RiverJunction:New(x,y,false)
	new_inst.lakeID = -1 --start with invalid lakeID
	new_inst.rainfall = 0.0

	return new_inst
end

-------------------------------------------------------------------------
--RiverJunction class
-------------------------------------------------------------------------
RiverJunction = inheritsFrom(nil)

function RiverJunction:New(x,y,isNorth)
	local new_inst = {}
	setmetatable(new_inst, {__index = RiverJunction});

	new_inst.x = x
	new_inst.y = y
	new_inst.isNorth = isNorth
	new_inst.altitude = 0.0
	new_inst.flow = mc.NOFLOW
	new_inst.size = 0.0
	new_inst.submerged = false
	new_inst.outflow = nil
	new_inst.isOutflow = false
	new_inst.rawID = nil --used before real ID is assigned
	new_inst.ID = nil
	new_inst.parentJunctions = {}

	return new_inst
end

function RiverJunction:AddParent(parent)
	--make sure to only add if not already in list
	for i=1,#self.parentJunctions do
		oldParent = self.parentJunctions[i]
		if parent.x == oldParent.x and parent.y == oldParent.y and parent.isNorth == oldParent.isNorth then
			return --parent already in list, just return
		end
	end
	table.insert(self.parentJunctions,parent)
	
end

function RiverJunction:_tostring()
	local flowString
	if self.flow == mc.NOFLOW then
		flowString = "NOFLOW"
	elseif self.flow == mc.WESTFLOW then
		flowString = "WESTFLOW"
	elseif self.flow == mc.EASTFLOW then
		flowString = "EASTFLOW"
	elseif self.flow == mc.VERTFLOW then
		flowString = "VERTFLOW"
	end
	return string.format("junction at %d, %d isNorth=%s, flow=%s, size=%f, submerged=%s, outflow=%s, isOutflow=%s riverID = %s",self.x,self.y,tostring(self.isNorth),flowString,self.size,tostring(self.submerged),tostring(self.outflow),tostring(self.isOutflow),tostring(self.ID))
end

-------------------------------------------------------------------------
--River class
-------------------------------------------------------------------------
River = inheritsFrom(nil)

function River:New(sourceJunc,rawID)
	local new_inst = {}
	setmetatable(new_inst, {__index = River});
	
	new_inst.sourceJunction = sourceJunc
	new_inst.riverID = nil
	new_inst.junctionList = {}
	sourceJunc.rawID = rawID 
	table.insert(new_inst.junctionList,sourceJunc)
	
	return new_inst
end

function River:Add(newJunction)
	--newJunction.ID = self.riverID add river IDs later 
	table.insert(self.junctionList,newJunction)
end

function River:GetLength()
	return #self.junctionList
end
------------------------------------------------------------------------------
--Global functions
------------------------------------------------------------------------------
function GenerateTwistedPerlinMap(width, height, xWrap, yWrap,minFreq,maxFreq,varFreq)
	local inputNoise = FloatMap:New(width,height,xWrap,yWrap)
	inputNoise:GenerateNoise()
	inputNoise:Normalize()

	local freqMap = FloatMap:New(width,height,xWrap,yWrap)
	for y = 0, freqMap.height - 1,1 do
		for x = 0,freqMap.width - 1,1 do
			local i = freqMap:GetIndex(x,y)
			local odd = y % 2
			local xx = x + odd * 0.5
			freqMap.data[i] = GetPerlinNoise(xx,y * mc.YtoXRatio,freqMap.width,freqMap.height * mc.YtoXRatio,varFreq,1.0,0.1,8,inputNoise)
		end
	end
	freqMap:Normalize()
--	freqMap:Save("freqMap.csv")

	local twistMap = FloatMap:New(width,height,xWrap,yWrap)
	for y = 0, twistMap.height - 1,1 do
		for x = 0,twistMap.width - 1,1 do
			local i = twistMap:GetIndex(x,y)
			local freq = freqMap.data[i] * (maxFreq - minFreq) + minFreq
			local mid = (maxFreq - minFreq)/2 + minFreq
			local coordScale = freq/mid
			local offset = (1.0 - coordScale)/mid
			--print("1-coordscale = " .. (1.0 - coordScale) .. ", offset = " .. offset)
			local ampChange = 0.85 - freqMap.data[i] * 0.5
			local odd = y % 2
			local xx = x + odd * 0.5
			twistMap.data[i] = GetPerlinNoise(xx + offset,(y + offset) * mc.YtoXRatio,twistMap.width,twistMap.height * mc.YtoXRatio,mid,1.0,ampChange,8,inputNoise)
		end
	end

	twistMap:Normalize()
	--twistMap:Save("twistMap.csv")
	return twistMap
end

--this is a useful function that removes all elements in a list that
--don't meet the fnKeep criteria
function ArrayRemove(t, fnKeep)
    local j, n = 1, #t; --j initialized with 1, n initialized with #t. weird lua thing

    for i=1,n do
        if (fnKeep(t,i)) then
            -- Move i's kept value to j's position, if it's not already there.
            if (i ~= j) then
                t[j] = t[i];
                t[i] = nil;
            end
            j = j + 1; -- Increment position of where we'll place the next kept value.
        else
            t[i] = nil;
        end
    end

    return t;
end

function ShuffleList(list)
	local length = #list
	for i=1,length,1 do
		local k = PWRandint(1,length)
		if k ~= i then
			local temp = list[i]
			list[i] = list[k]
			list[k] = temp
		end
	end
end

function GenerateMountainMap(width,height,xWrap,yWrap,initFreq)
	local inputNoise = FloatMap:New(width,height,xWrap,yWrap)
	inputNoise:GenerateBinaryNoise()
	inputNoise:Normalize()
	local inputNoise2 = FloatMap:New(width,height,xWrap,yWrap)
	inputNoise2:GenerateNoise()
	inputNoise2:Normalize()

	local mountainMap = FloatMap:New(width,height,xWrap,yWrap)
	local stdDevMap = FloatMap:New(width,height,xWrap,yWrap)
	local noiseMap = FloatMap:New(width,height,xWrap,yWrap)
	for y = 0, mountainMap.height - 1,1 do
		for x = 0,mountainMap.width - 1,1 do
			local i = mountainMap:GetIndex(x,y)
			local odd = y % 2
			local xx = x + odd * 0.5
			mountainMap.data[i] = GetPerlinNoise(xx,y * mc.YtoXRatio,mountainMap.width,mountainMap.height * mc.YtoXRatio,initFreq,1.0,0.4,8,inputNoise)
			noiseMap.data[i] = GetPerlinNoise(xx,y * mc.YtoXRatio,mountainMap.width,mountainMap.height * mc.YtoXRatio,initFreq,1.0,0.4,8,inputNoise2)
			stdDevMap.data[i] = mountainMap.data[i]
		end
	end
	mountainMap:Normalize()
	stdDevMap:Deviate(7)
	stdDevMap:Normalize()
	--stdDevMap:Save("stdDevMap.csv")
	--mountainMap:Save("mountainCloud.csv")
	noiseMap:Normalize()
	--noiseMap:Save("noiseMap.csv")

	local moundMap = FloatMap:New(width,height,xWrap,yWrap)
	for y = 0, mountainMap.height - 1,1 do
		for x = 0,mountainMap.width - 1,1 do
			local i = mountainMap:GetIndex(x,y)
			local val = mountainMap.data[i]
			moundMap.data[i] = (math.sin(val*math.pi*2-math.pi*0.5)*0.5+0.5) * GetAttenuationFactor(mountainMap,x,y)
			if val < 0.5 then
				val = val^1 * 4
			else
				val = (1 - val)^1 * 4
			end
			--mountainMap.data[i] = val
			mountainMap.data[i] = moundMap.data[i]
		end
	end
	mountainMap:Normalize()
	--mountainMap:Save("premountMap.csv")
	--moundMap:Save("moundMap.csv")

	for y = 0, mountainMap.height - 1,1 do
		for x = 0,mountainMap.width - 1,1 do
			local i = mountainMap:GetIndex(x,y)
			local val = mountainMap.data[i]
			--mountainMap.data[i] = (math.sin(val * 2 * math.pi + math.pi * 0.5)^8 * val) + moundMap.data[i] * 2 + noiseMap.data[i] * 0.6
			mountainMap.data[i] = (math.sin(val * 3 * math.pi + math.pi * 0.5)^16 * val)^0.5
			if mountainMap.data[i] > 0.2 then
				mountainMap.data[i] = 1.0
			else
				mountainMap.data[i] = 0.0
			end
		end
	end
	--mountainMap:Save("premountMap.csv")

	local stdDevThreshold = stdDevMap:FindThresholdFromPercent(mc.landPercent,true,false)

	for y = 0, mountainMap.height - 1,1 do
		for x = 0,mountainMap.width - 1,1 do
			local i = mountainMap:GetIndex(x,y)
			local val = mountainMap.data[i]
			local dev = 2.0 * stdDevMap.data[i] - 2.0 * stdDevThreshold
			--mountainMap.data[i] = (math.sin(val * 2 * math.pi + math.pi * 0.5)^8 * val) + moundMap.data[i] * 2 + noiseMap.data[i] * 0.6
			mountainMap.data[i] = (val + moundMap.data[i]) * dev
		end
	end

	mountainMap:Normalize()
	--mountainMap:Save("mountainMap.csv")
	return mountainMap
end

function waterMatch(x,y)
	if elevationMap:IsBelowSeaLevel(x,y) then
		return true
	end
	return false
end

function GetAttenuationFactor(map,x,y)
	local southY = map.height * mc.southAttenuationRange
	local southRange = map.height * mc.southAttenuationRange
	local yAttenuation = 1.0
	if y < southY then
		yAttenuation = mc.southAttenuationFactor + (y/southRange) * (1.0 - mc.southAttenuationFactor)
	end

	local northY = map.height - (map.height * mc.northAttenuationRange)
	local northRange = map.height * mc.northAttenuationRange
	if y > northY then
		yAttenuation = mc.northAttenuationFactor + ((map.height - y)/northRange) * (1.0 - mc.northAttenuationFactor)
	end

	local eastY = map.width - (map.width * mc.eastAttenuationRange)
	local eastRange = map.width * mc.eastAttenuationRange
	local xAttenuation = 1.0
	if x > eastY then
		xAttenuation = mc.eastAttenuationFactor + ((map.width - x)/eastRange) * (1.0 - mc.eastAttenuationFactor)
	end

	local westY = map.width * mc.westAttenuationRange
	local westRange = map.width * mc.westAttenuationRange
	if x < westY then
		xAttenuation = mc.westAttenuationFactor + (x/westRange) * (1.0 - mc.westAttenuationFactor)
	end

	return yAttenuation * xAttenuation
end

function GenerateElevationMap(width,height,xWrap,yWrap)
	local twistMinFreq = 128/width * mc.twistMinFreq --0.02/128
	local twistMaxFreq = 128/width * mc.twistMaxFreq --0.12/128
	local twistVar = 128/width * mc.twistVar --0.042/128
	local mountainFreq = 128/width * mc.mountainFreq --0.05/128
	local twistMap = GenerateTwistedPerlinMap(width,height,xWrap,yWrap,twistMinFreq,twistMaxFreq,twistVar)
	local mountainMap = GenerateMountainMap(width,height,xWrap,yWrap,mountainFreq)
	local elevationMap = ElevationMap:New(width,height,xWrap,yWrap)
	for y = 0,height - 1,1 do
		for x = 0,width - 1,1 do
			local i = elevationMap:GetIndex(x,y)
			local tVal = twistMap.data[i]
			tVal = (math.sin(tVal*math.pi-math.pi*0.5)*0.5+0.5)^0.25 --this formula adds a curve flattening the extremes
			elevationMap.data[i] = (tVal + ((mountainMap.data[i] * 2) - 1) * mc.mountainWeight)
		end
	end

	elevationMap:Normalize()

	--attentuation should not break normalization
	for y = 0,height - 1,1 do
		for x = 0,width - 1,1 do
			local i = elevationMap:GetIndex(x,y)
			local attenuationFactor = GetAttenuationFactor(elevationMap,x,y)
			elevationMap.data[i] = elevationMap.data[i] * attenuationFactor
		end
	end

	elevationMap.seaLevelThreshold = elevationMap:FindThresholdFromPercent(mc.landPercent,true,false)

	return elevationMap
end

function FillInLakes()
	local areaMap = PWAreaMap:New(elevationMap.width,elevationMap.height,elevationMap.wrapX,elevationMap.wrapY)
	areaMap:DefineAreas(waterMatch,false)
	for i=1,#areaMap.areaList,1 do
		local area = areaMap.areaList[i]
		if area.trueMatch and area.size < mc.minOceanSize then
			for n = 0,areaMap.length,1 do
				if areaMap.data[n] == area.id then
					elevationMap.data[n] = elevationMap.seaLevelThreshold
				end
			end
		end
	end
end

function GenerateTempMaps(elevationMap)

	local aboveSeaLevelMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
	for y = 0,elevationMap.height - 1,1 do
		for x = 0,elevationMap.width - 1,1 do
			local i = aboveSeaLevelMap:GetIndex(x,y)
			if elevationMap:IsBelowSeaLevel(x,y) then
				aboveSeaLevelMap.data[i] = 0.0
			else
				aboveSeaLevelMap.data[i] = elevationMap.data[i] - elevationMap.seaLevelThreshold
			end
		end
	end
	aboveSeaLevelMap:Normalize()
	--aboveSeaLevelMap:Save("aboveSeaLevelMap.csv")

	local summerMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
	local zenith = mc.tropicLatitudes
	local topTempLat = mc.topLatitude + zenith
	local bottomTempLat = mc.bottomLatitude
	local latRange = topTempLat - bottomTempLat
	for y = 0,elevationMap.height - 1,1 do
		for x = 0,elevationMap.width - 1,1 do
			local i = summerMap:GetIndex(x,y)
			local lat = summerMap:GetLatitudeForY(y)
			--print("y=" .. y ..",lat=" .. lat)
			local latPercent = (lat - bottomTempLat)/latRange
			--print("latPercent=" .. latPercent)
			local temp = (math.sin(latPercent * math.pi * 2 - math.pi * 0.5) * 0.5 + 0.5)
			if elevationMap:IsBelowSeaLevel(x,y) then
				temp = temp * mc.maxWaterTemp + mc.minWaterTemp
			end
			summerMap.data[i] = temp
		end
	end
	summerMap:Smooth(math.floor(elevationMap.width/8))
	summerMap:Normalize()

	local winterMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
	zenith = -mc.tropicLatitudes
	topTempLat = mc.topLatitude
	bottomTempLat = mc.bottomLatitude + zenith
	latRange = topTempLat - bottomTempLat
	for y = 0,elevationMap.height - 1,1 do
		for x = 0,elevationMap.width - 1,1 do
			local i = winterMap:GetIndex(x,y)
			local lat = winterMap:GetLatitudeForY(y)
			local latPercent = (lat - bottomTempLat)/latRange
			local temp = math.sin(latPercent * math.pi * 2 - math.pi * 0.5) * 0.5 + 0.5
			if elevationMap:IsBelowSeaLevel(x,y) then
				temp = temp * mc.maxWaterTemp + mc.minWaterTemp
			end
			winterMap.data[i] = temp
		end
	end
	winterMap:Smooth(math.floor(elevationMap.width/8))
	winterMap:Normalize()

	local temperatureMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
	for y = 0,elevationMap.height - 1,1 do
		for x = 0,elevationMap.width - 1,1 do
			local i = temperatureMap:GetIndex(x,y)
			temperatureMap.data[i] = (winterMap.data[i] + summerMap.data[i]) * (1.0 - aboveSeaLevelMap.data[i])
		end
	end
	temperatureMap:Normalize()

	return summerMap,winterMap,temperatureMap
end

function GenerateRainfallMap(elevationMap)
	local summerMap,winterMap,temperatureMap = GenerateTempMaps(elevationMap)
	--summerMap:Save("summerMap.csv")
	--winterMap:Save("winterMap.csv")
	--temperatureMap:Save("temperatureMap.csv")
	local geoMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
	for y = 0,elevationMap.height - 1,1 do
		for x = 0,elevationMap.width - 1,1 do
			local i = elevationMap:GetIndex(x,y)
			local lat = elevationMap:GetLatitudeForY(y)
			local pressure = elevationMap:GetGeostrophicPressure(lat)
			geoMap.data[i] = pressure
		end
	end
	geoMap:Normalize()
	--geoMap:Save("geoMap.csv")

	local sortedSummerMap = {}
	local sortedWinterMap = {}
	for y = 0,elevationMap.height - 1,1 do
		for x = 0,elevationMap.width - 1,1 do
			local i = elevationMap:GetIndex(x,y)
			sortedSummerMap[i + 1] = {x,y,summerMap.data[i]}
			sortedWinterMap[i + 1] = {x,y,winterMap.data[i]}
		end
	end
	table.sort(sortedSummerMap, function (a,b) return a[3] < b[3] end)
	table.sort(sortedWinterMap, function (a,b) return a[3] < b[3] end)

	local sortedGeoMap = {}
	local xStart = 0
	local xStop = 0
	local yStart = 0
	local yStop = 0
	local incX = 0
	local incY = 0
	local geoIndex = 1
	local str = ""
	for zone=0,5,1 do
		local topY = elevationMap:GetYFromZone(zone,true)
		local bottomY = elevationMap:GetYFromZone(zone,false)
		if not (topY == -1 and bottomY == -1) then
			if topY == -1 then
				topY = elevationMap.height - 1
			end
			if bottomY == -1 then
				bottomY = 0
			end
			--str = string.format("topY = %d, bottomY = %d",topY,bottomY)
			--print(str)
			local dir1,dir2 = elevationMap:GetGeostrophicWindDirections(zone)
			--str = string.format("zone = %d, dir1 = %d",zone,dir1)
			--print(str)
			if (dir1 == mc.SW) or (dir1 == mc.SE) then
				yStart = topY
				yStop = bottomY --- 1
				incY = -1
			else
				yStart = bottomY
				yStop = topY --+ 1
				incY = 1
			end
			if dir2 == mc.W then
				xStart = elevationMap.width - 1
				xStop = 0---1
				incX = -1
			else
				xStart = 0
				xStop = elevationMap.width
				incX = 1
			end
			--str = string.format("yStart = %d, yStop = %d, incY = %d",yStart,yStop,incY)
			--print(str)
			--str = string.format("xStart = %d, xStop = %d, incX = %d",xStart,xStop,incX)
			--print(str)

			for y = yStart,yStop ,incY do
				--str = string.format("y = %d",y)
				--print(str)
				--each line should start on water to avoid vast areas without rain
				local xxStart = xStart
				local xxStop = xStop
				for xx = xStart,xStop - incX, incX do
					local i = elevationMap:GetIndex(xx,y)
					if elevationMap:IsBelowSeaLevel(xx,y) then
						xxStart = xx
						xxStop = xx + elevationMap.width * incX
						break
					end
				end
				for x = xxStart,xxStop - incX,incX do
					local i = elevationMap:GetIndex(x,y)
					sortedGeoMap[geoIndex] = {x,y,geoMap.data[i]}
					geoIndex = geoIndex + 1
				end
			end
		end
	end
--	table.sort(sortedGeoMap, function (a,b) return a[3] < b[3] end)
	--print(#sortedGeoMap)
	--print(#geoMap.data)

	local rainfallSummerMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
	local moistureMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
	for i = 1,#sortedSummerMap,1 do
		local x = sortedSummerMap[i][1]
		local y = sortedSummerMap[i][2]
		local pressure = sortedSummerMap[i][3]
		DistributeRain(x,y,elevationMap,temperatureMap,summerMap,rainfallSummerMap,moistureMap,false)
	end

	local rainfallWinterMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
	local moistureMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
	for i = 1,#sortedWinterMap,1 do
		local x = sortedWinterMap[i][1]
		local y = sortedWinterMap[i][2]
		local pressure = sortedWinterMap[i][3]
		DistributeRain(x,y,elevationMap,temperatureMap,winterMap,rainfallWinterMap,moistureMap,false)
	end

	local rainfallGeostrophicMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
	moistureMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
	--print("----------------------------------------------------------------------------------------")
	--print("--GEOSTROPHIC---------------------------------------------------------------------------")
	--print("----------------------------------------------------------------------------------------")
	for i = 1,#sortedGeoMap,1 do
		local x = sortedGeoMap[i][1]
		local y = sortedGeoMap[i][2]
--~ 		if y == 35 or y == 40 then
--~ 			str = string.format("x = %d, y = %d",x,y)
--~ 			print(str)
--~ 		end
		DistributeRain(x,y,elevationMap,temperatureMap,geoMap,rainfallGeostrophicMap,moistureMap,true)
	end
	--zero below sea level for proper percent threshold finding
	for y = 0,elevationMap.height - 1,1 do
		for x = 0,elevationMap.width - 1,1 do
			local i = elevationMap:GetIndex(x,y)
			if elevationMap:IsBelowSeaLevel(x,y) then
				rainfallSummerMap.data[i] = 0.0
				rainfallWinterMap.data[i] = 0.0
				rainfallGeostrophicMap.data[i] = 0.0
			end
		end
	end

	rainfallSummerMap:Normalize()
	--rainfallSummerMap:Save("rainFallSummerMap.csv")
	rainfallWinterMap:Normalize()
	--rainfallWinterMap:Save("rainFallWinterMap.csv")
	rainfallGeostrophicMap:Normalize()
	--rainfallGeostrophicMap:Save("rainfallGeostrophicMap.csv")

	local rainfallMap = FloatMap:New(elevationMap.width,elevationMap.height,elevationMap.xWrap,elevationMap.yWrap)
	for y = 0,elevationMap.height - 1,1 do
		for x = 0,elevationMap.width - 1,1 do
			local i = elevationMap:GetIndex(x,y)
			rainfallMap.data[i] = rainfallSummerMap.data[i] + rainfallWinterMap.data[i] + (rainfallGeostrophicMap.data[i] * mc.geostrophicFactor)
		end
	end
	rainfallMap:Normalize()

	return rainfallMap, temperatureMap
end

function DistributeRain(x,y,elevationMap,temperatureMap,pressureMap,rainfallMap,moistureMap,boolGeostrophic)

	local i = elevationMap:GetIndex(x,y)
	local upLiftSource = math.max(math.pow(pressureMap.data[i],mc.upLiftExponent),1.0 - temperatureMap.data[i])
	--local str = string.format("geo=%s,x=%d, y=%d, srcPressure uplift = %f, upliftSource = %f",tostring(boolGeostrophic),x,y,math.pow(pressureMap.data[i],mc.upLiftExponent),upLiftSource)
	--print(str)
	if elevationMap:IsBelowSeaLevel(x,y) then
		moistureMap.data[i] = math.max(moistureMap.data[i], temperatureMap.data[i])
		--print("water tile = true")
	end
	--print(string.format("moistureMap.data[i] = %f",moistureMap.data[i]))

	--make list of neighbors
	local nList = {}
	if boolGeostrophic then
		local zone = elevationMap:GetZone(y)
		local dir1,dir2 = elevationMap:GetGeostrophicWindDirections(zone)
		local x1,y1 = elevationMap:GetNeighbor(x,y,dir1)
		local ii = elevationMap:GetIndex(x1,y1)
		--neighbor must be on map and in same wind zone
		if ii >= 0 and (elevationMap:GetZone(y1) == elevationMap:GetZone(y)) then
			table.insert(nList,{x1,y1})
		end
		local x2,y2 = elevationMap:GetNeighbor(x,y,dir2)
		ii = elevationMap:GetIndex(x2,y2)
		if ii >= 0 then
			table.insert(nList,{x2,y2})
		end
	else
		for dir = 1,6,1 do
			local xx,yy = elevationMap:GetNeighbor(x,y,dir)
			local ii = elevationMap:GetIndex(xx,yy)
			if ii >= 0 and pressureMap.data[i] <= pressureMap.data[ii] then
				table.insert(nList,{xx,yy})
			end
		end
	end
	if #nList == 0 or boolGeostrophic and #nList == 1 then
		local cost = moistureMap.data[i]
		rainfallMap.data[i] = cost
		return
	end
	local moisturePerNeighbor = moistureMap.data[i]/#nList
	--drop rain and pass moisture to neighbors
	for n = 1,#nList,1 do
		local xx = nList[n][1]
		local yy = nList[n][2]
		local ii = elevationMap:GetIndex(xx,yy)
		local upLiftDest = math.max(math.pow(pressureMap.data[ii],mc.upLiftExponent),1.0 - temperatureMap.data[ii])
		local cost = GetRainCost(upLiftSource,upLiftDest)
		local bonus = 0.0
		if (elevationMap:GetZone(y) == mc.NPOLAR or elevationMap:GetZone(y) == mc.SPOLAR) then
			bonus = mc.polarRainBoost
		end
		if boolGeostrophic and #nList == 2 then
			if n == 1 then
				moisturePerNeighbor = (1.0 - mc.geostrophicLateralWindStrength) * moistureMap.data[i]
			else
				moisturePerNeighbor = mc.geostrophicLateralWindStrength * moistureMap.data[i]
			end
		end
		--print(string.format("---xx=%d, yy=%d, destPressure uplift = %f, upLiftDest = %f, cost = %f, moisturePerNeighbor = %f, bonus = %f",xx,yy,math.pow(pressureMap.data[ii],mc.upLiftExponent),upLiftDest,cost,moisturePerNeighbor,bonus))
		rainfallMap.data[i] = rainfallMap.data[i] + cost * moisturePerNeighbor + bonus
		--pass to neighbor.
		--print(string.format("---moistureMap.data[ii] = %f",moistureMap.data[ii]))
		moistureMap.data[ii] = moistureMap.data[ii] + moisturePerNeighbor - (cost * moisturePerNeighbor)
		--print(string.format("---dropping %f rain",cost * moisturePerNeighbor + bonus))
		--print(string.format("---passing on %f moisture",moisturePerNeighbor - (cost * moisturePerNeighbor)))
	end

end

function GetRainCost(upLiftSource,upLiftDest)
	local cost = mc.minimumRainCost
	cost = math.max(mc.minimumRainCost, cost + upLiftDest - upLiftSource)
	if cost < 0.0 then
		cost = 0.0
	end
	return cost
end

function GetDifferenceAroundHex(x,y)
	local avg = elevationMap:GetAverageInHex(x,y,1)
 	local i = elevationMap:GetIndex(x,y)
	return elevationMap.data[i] - avg
end

function PlacePossibleOasis(x,y)
    --g_TERRAIN_TYPE_DESERT
	--g_TERRAIN_TYPE_DESERT_HILLS
	--g_TERRAIN_TYPE_DESERT_MOUNTAIN
    --g_FEATURE_OASIS
    local plot = Map.GetPlot(x,y)
    if not plot:IsHills() and not plot:IsMountain() and plot:GetTerrainType() == g_TERRAIN_TYPE_DESERT then
        local canPlace = true
		
		--too many oasis clustered together looks bad
		--reject if within 3 tiles of another oasis
		local tiles = elevationMap:GetRadiusAroundHex(x,y,3)
        for n=1,#tiles do
            local xx = tiles[n][1]
            local yy = tiles[n][2]
            local nPlot = Map.GetPlot(xx,yy)
            if nPlot:GetFeatureType() == g_FEATURE_OASIS then
                canPlace = false
                break
            end
        end

		--oasis tile should be all desert around and not be another feature
		if canPlace then
			local tiles = elevationMap:GetRadiusAroundHex(x,y,1)
			for n=1,#tiles do
				local xx = tiles[n][1]
				local yy = tiles[n][2]
				local nPlot = Map.GetPlot(xx,yy)
				local terrType = nPlot:GetTerrainType()
				if not (terrType == g_TERRAIN_TYPE_DESERT or terrType == g_TERRAIN_TYPE_DESERT_HILLS or terrType == g_TERRAIN_TYPE_DESERT_MOUNTAIN) then
					canPlace = false
					break
				elseif nPlot:GetFeatureType() ~= g_FEATURE_NONE then
					canPlace = false
					break
				end
			end
		end
		
        if canPlace then
            TerrainBuilder.SetFeatureType(plot, g_FEATURE_OASIS)
        end
    end
end

function PlacePossibleIce(x,y)
    local featureIce = g_FEATURE_ICE
    local plot = Map.GetPlot(x,y)
    local i = temperatureMap:GetIndex(x,y)
    if plot:IsWater() then
        local temp = temperatureMap.data[i]
        local latitude = temperatureMap:GetLatitudeForY(y)
        --local randval = PWRand() * (mc.iceMaxTemperature - mc.minWaterTemp) + mc.minWaterTemp * 2
        local randvalNorth = PWRand() * (mc.iceNorthLatitudeLimit - mc.topLatitude) + mc.topLatitude - 2
        local randvalSouth = PWRand() * (mc.bottomLatitude - mc.iceSouthLatitudeLimit) + mc.iceSouthLatitudeLimit
        --print(string.format("lat = %f, randvalNorth = %f, randvalSouth = %f",latitude,randvalNorth,randvalSouth))
        if latitude > randvalNorth  or latitude < randvalSouth then
            TerrainBuilder.SetFeatureType(plot, featureIce)
        end
    end
end

function PlacePossibleReef(x,y)
	--reefs are an expansion feature, might not exist
	if g_FEATURE_REEF == nil then
		return
	end
	
    local plot = Map.GetPlot(x,y)
    local i = temperatureMap:GetIndex(x,y)
    if plot:IsWater() then
		if plot:GetFeatureType() == g_FEATURE_NONE and plot:GetResourceType() == -1 and TerrainBuilder.CanHaveFeature(plot, g_FEATURE_REEF) then
			local temp = temperatureMap.data[i]
			--temp = (temp - mc.minWaterTemp)/(mc.maxWaterTemp - mc.minWaterTemp) -- scaled to between zero and one
			--local sinTemp = math.sin(temp * math.pi -  math.pi * 0.5) * 0.5 + 0.5 -- sine curve for natural effect  
			local chance = mc.maxReefChance
			local randVal = PWRand()
			if randVal < chance then
				TerrainBuilder.SetFeatureType(plot, g_FEATURE_REEF)
			end
		end
    end
end
function AddTerrainFromContinents(terrainTypes, iW, iH, iContinentBoundaryPlots)

	--plotTypes is outdated by the time this function is run, use terrainTypes only
	local iMountainPercentByDistance:table = {42, 24, 6}; 
	local iHillPercentByDistance:table = {50, 40, 30}; 
	local aLonelyMountainIndices:table = {};
	local iVolcanoesPlaced = 0;

	-- Compute target number of volcanoes
	local iTotalLandPlots = 0;
	for iX = 0, iW - 1 do
		for iY = 0, iH - 1 do
			local index = (iY * iW) + iX;
			if (terrainTypes[index] ~= g_TERRAIN_TYPE_COAST and terrainTypes[index] ~= g_TERRAIN_TYPE_OCEAN) then
				iTotalLandPlots = iTotalLandPlots + 1;
			end
		end
	end
	local iDivisor = 8;
--	if (world_age < 8) then
--		iDivisor = 8 - world_age;  -- iDivisor should be 3 for new, 6 for old
-- 	end
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
				if (terrainTypes[index] ~= g_TERRAIN_TYPE_COAST and terrainTypes[index] ~= g_TERRAIN_TYPE_OCEAN) then
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

					elseif (terrainTypes[index] == g_TERRAIN_TYPE_GRASS_MOUNTAIN or terrainTypes[index] == g_TERRAIN_TYPE_PLAINS_MOUNTAIN or terrainTypes[index] == g_TERRAIN_TYPE_DESERT_MOUNTAIN  or terrainTypes[index] == g_TERRAIN_TYPE_TUNDRA_MOUNTAIN ) then
						--leaving out snow mountain
						if (GetNumberAdjacentMountains() == 0) then
							table.insert(aLonelyMountainIndices, index);
						end
					end

					if (bVolcanoHere) then
						TerrainBuilder.SetTerrainType(pPlot, ConvertToMountain(terrainTypes[index]));
						TerrainBuilder.SetFeatureType(pPlot, g_FEATURE_VOLCANO);
						ApplyVolcanoBump(index)
						print ("Volcano Placed at (x, y): " .. iX .. ", " .. iY);
						iVolcanoesPlaced = iVolcanoesPlaced + 1;

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
			ApplyVolcanoBump(index)
			print ("Volcano Placed at (x, y): " .. pPlot:GetX() .. ", " .. pPlot:GetY());
			iVolcanoesPlaced = iVolcanoesPlaced + 1;
			if (iVolcanoesPlaced >= iDesiredVolcanoes) then
				break
			end
		end
	end

	print ("Total Volcanoes Placed: " .. iVolcanoesPlaced);
end
function ApplyVolcanoBump(vPlotIndex)
--this function adds a bump to volcano plots to guide the river system.
	elevationMap.data[vPlotIndex] = elevationMap.data[vPlotIndex] * 1.5
	local x, y = elevationMap:GetXYFromIndex(vPlotIndex)

	local list = elevationMap:GetRadiusAroundHex(x,y,1)
	for n = 1,#list,1 do
		local hex = list[n]
		local xx = hex[1]
		local yy = hex[2]
		local i = elevationMap:GetIndex(xx,yy)
		elevationMap.data[i] = elevationMap.data[i] * 1.25
	end

end

function ApplyTerrain(plotTypes, terrainTypes)
	--don't run this twice! It doesn't work that way!
	local gridWidth, gridHeight = Map.GetGridSize();
	for i = 0, (gridWidth * gridHeight) - 1, 1 do
		pPlot = Map.GetPlotByIndex(i);
		if (plotTypes[i] == g_PLOT_TYPE_HILLS) then
			terrainTypes[i] = terrainTypes[i] + g_TERRAIN_BASE_TO_HILLS_DELTA;
		elseif (plotTypes[i] == g_PLOT_TYPE_MOUNTAIN) then
			terrainTypes[i] = terrainTypes[i] + g_TERRAIN_BASE_TO_MOUNTAIN_DELTA;
		end
		TerrainBuilder.SetTerrainType(pPlot, terrainTypes[i]);
	end
end

function GeneratePlotTypes()
	print("Creating initial map data - PerfectWorld6")
	
	local plotTypes = {}
	
	local gridWidth, gridHeight = Map.GetGridSize();
	--first do all the preliminary calculations in this function
	print(string.format("map size: width=%d, height=%d",gridWidth,gridHeight))
	mc = MapConstants:New()
	PWRandSeed()

	elevationMap = GenerateElevationMap(gridWidth,gridHeight,true,false)
	FillInLakes()
	--elevationMap:Save("elevationMap.csv")

	rainfallMap, temperatureMap = GenerateRainfallMap(elevationMap)
	--rainfallMap:Save("rainfallMap.csv")

	--now gen plot types
	print("Generating plot types - PerfectWorld6")
	local diffMap = FloatMap:New(gridWidth,gridHeight,true,false)
	for y = 0, gridHeight - 1,1 do
		for x = 0,gridWidth - 1,1 do
			local i = diffMap:GetIndex(x,y)
			if elevationMap:IsBelowSeaLevel(x,y) then
				diffMap.data[i] = 0.0
			else
				diffMap.data[i] = GetDifferenceAroundHex(x,y)
			end
		end
	end

	diffMap:Normalize()

	for y = 0, gridHeight - 1,1 do
		for x = 0,gridWidth - 1,1 do
			local i = diffMap:GetIndex(x,y)
			if elevationMap:IsBelowSeaLevel(x,y) then
				diffMap.data[i] = 0.0
			else
				diffMap.data[i] = diffMap.data[i] + elevationMap.data[i] * 1.1
			end
		end
	end

	diffMap:Normalize()

	--find exact thresholds
	local hillsThreshold = diffMap:FindThresholdFromPercent(mc.hillsPercent,false,true)
	local mountainsThreshold = diffMap:FindThresholdFromPercent(mc.mountainsPercent,false,true)

	for y = 0, gridHeight - 1,1 do
		for x = 0,gridWidth - 1,1 do
			local i = diffMap:GetIndex(x,y)
			if elevationMap:IsBelowSeaLevel(x,y) then
				plotTypes[i] = g_PLOT_TYPE_OCEAN
			elseif diffMap.data[i] < hillsThreshold then
				plotTypes[i] = g_PLOT_TYPE_LAND
			elseif diffMap.data[i] < mountainsThreshold then
				plotTypes[i] = g_PLOT_TYPE_HILLS
			else
				plotTypes[i] = g_PLOT_TYPE_MOUNTAIN
			end
		end
	end

	return plotTypes
end

function GenerateTerrain()
	print("Generating terrain - PerfectWorld6")
	--g_TERRAIN_TYPE_DESERT
	--g_TERRAIN_TYPE_PLAINS
	--g_TERRAIN_TYPE_SNOW
	--g_TERRAIN_TYPE_TUNDRA
	--g_TERRAIN_TYPE_GRASS
	local terrainTypes = {}

	local gridWidth, gridHeight = Map.GetGridSize();
	--first find minimum rain above sea level for a soft desert transition
	local minRain = 100.0
	for y = 0, gridHeight - 1,1 do
		for x = 0,gridWidth - 1,1 do
			local i = elevationMap:GetIndex(x,y)
			if not elevationMap:IsBelowSeaLevel(x,y) then
				if rainfallMap.data[i] < minRain then
					minRain = rainfallMap.data[i]
				end
			end
		end
	end

	--find exact thresholds, making these global for subsequent use
	desertThreshold = rainfallMap:FindThresholdFromPercent(mc.desertPercent,false,true)
	plainsThreshold = rainfallMap:FindThresholdFromPercent(mc.plainsPercent,false,true)
	for y = 0, gridHeight - 1,1 do
		for x = 0,gridWidth - 1,1 do
			local i = elevationMap:GetIndex(x,y)
			if not elevationMap:IsBelowSeaLevel(x,y) then
				if rainfallMap.data[i] < desertThreshold then
					if temperatureMap.data[i] < mc.snowTemperature then
						terrainTypes[i] = g_TERRAIN_TYPE_SNOW
					elseif temperatureMap.data[i] < mc.tundraTemperature then
						terrainTypes[i] = g_TERRAIN_TYPE_TUNDRA
					elseif temperatureMap.data[i] < mc.desertMinTemperature then
						terrainTypes[i] = g_TERRAIN_TYPE_PLAINS
					else
						terrainTypes[i] = g_TERRAIN_TYPE_DESERT
					end
				elseif rainfallMap.data[i] < plainsThreshold then
					if temperatureMap.data[i] < mc.snowTemperature then
						terrainTypes[i] = g_TERRAIN_TYPE_SNOW
					elseif temperatureMap.data[i] < mc.tundraTemperature then
						terrainTypes[i] = g_TERRAIN_TYPE_TUNDRA
					else
						if rainfallMap.data[i] < (PWRand() * (plainsThreshold - desertThreshold) + plainsThreshold - desertThreshold)/2.0 + desertThreshold then
							terrainTypes[i] = g_TERRAIN_TYPE_PLAINS
						else
							terrainTypes[i] = g_TERRAIN_TYPE_GRASS
						end
					end
				else
					if temperatureMap.data[i] < mc.snowTemperature then
						terrainTypes[i] = g_TERRAIN_TYPE_SNOW
					elseif temperatureMap.data[i] < mc.tundraTemperature then
						terrainTypes[i] = g_TERRAIN_TYPE_TUNDRA
					else
						terrainTypes[i] = g_TERRAIN_TYPE_GRASS
					end
				end
			end
		end
	end
	
	return terrainTypes
end

function FinalAlterations(plotTypes, terrainTypes)
	--now we fix things up so that the border of tundra and ice regions are hills
	--this looks a bit more believable. Also keep desert away from tundra and ice
	--by turning it into plains
	local gridWidth, gridHeight = Map.GetGridSize();
	for y = 0, gridHeight - 1,1 do
		for x = 0,gridWidth - 1,1 do
			local i = elevationMap:GetIndex(x,y)
			if not elevationMap:IsBelowSeaLevel(x,y) then
				if terrainTypes[i] == g_TERRAIN_TYPE_SNOW then
					local lowerFound = false
					for dir = mc.W,mc.SW,1 do
						local xx,yy = elevationMap:GetNeighbor(x,y,dir)
						local ii = elevationMap:GetIndex(xx,yy)
						if ii ~= -1 then
							local terrainVal = terrainTypes[ii]
							if not elevationMap:IsBelowSeaLevel(xx,yy) and terrainVal ~= g_TERRAIN_TYPE_SNOW then
								lowerFound = true
							end
							if terrainVal == g_TERRAIN_TYPE_DESERT then
								terrainTypes[ii] = g_TERRAIN_TYPE_PLAINS
							end
						end
					end
					if lowerFound and plotTypes[i] == g_PLOT_TYPE_LAND then
						plotTypes[i] = g_PLOT_TYPE_HILLS
					end
				elseif terrainTypes[i] == g_TERRAIN_TYPE_TUNDRA then
					local lowerFound = false
					for dir = mc.W,mc.SW,1 do
						local xx,yy = elevationMap:GetNeighbor(x,y,dir)
						local ii = elevationMap:GetIndex(xx,yy)
						if ii ~= -1 then
							local terrainVal = terrainTypes[ii]
							if not elevationMap:IsBelowSeaLevel(xx,yy) and terrainVal ~= g_TERRAIN_TYPE_SNOW and terrainVal ~= g_TERRAIN_TYPE_TUNDRA then
								lowerFound = true
							end
							if terrainVal == g_TERRAIN_TYPE_DESERT then
								terrainTypes[ii] = g_TERRAIN_TYPE_PLAINS
							end
						end
					end
					if lowerFound and plotTypes[i] == g_PLOT_TYPE_LAND then
						plotTypes[i] = g_PLOT_TYPE_HILLS
					end
				else
					local higherFound = false
					for dir = mc.W,mc.SW,1 do
						local xx,yy = elevationMap:GetNeighbor(x,y,dir)
						local ii = elevationMap:GetIndex(xx,yy)
						if ii ~= -1 then
							local terrainVal = terrainTypes[ii]
							if terrainVal == g_TERRAIN_TYPE_SNOW or terrainVal == g_TERRAIN_TYPE_TUNDRA then
								higherFound = true
							end
						end
					end
					if higherFound and plotTypes[i] == g_PLOT_TYPE_HILLS then
						plotTypes[i] = g_PLOT_TYPE_LAND
					end
				end
			end
		end
	end
end

function GenerateCoasts(plotTypes, terrainTypes)
	local gridWidth, gridHeight = Map.GetGridSize();
	for y = 0, gridHeight - 1,1 do
		for x = 0,gridWidth - 1,1 do
			local i = elevationMap:GetIndex(x,y)
			local coastThreshold = elevationMap.seaLevelThreshold * 0.90
			if(plotTypes[i] == g_PLOT_TYPE_OCEAN) then
				if IsAdjacentToLand(plotTypes, x, y) then
					terrainTypes[i] = g_TERRAIN_TYPE_COAST		
				elseif elevationMap.data[i] > coastThreshold then
					terrainTypes[i] = g_TERRAIN_TYPE_COAST
				else
					terrainTypes[i] = g_TERRAIN_TYPE_OCEAN
				end
			end
		end
	end

end

function IsAdjacentToCoast(terrainTypes,x,y)
	local gridWidth, gridHeight = Map.GetGridSize();
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		adjacentPlot = Map.GetAdjacentPlot(x, y, direction);
		if (adjacentPlot ~= nil) then
			local i = elevationMap:GetIndex(adjacentPlot:GetX(),adjacentPlot:GetY())
			if (terrainTypes[i] ~= g_TERRAIN_TYPE_COAST) then
				return true;
			end
		end
	end

end
------------------------------------------------------------------------------
function AddFeatures()
    print("Adding Features PerfectWorld6");

    local terrainPlains	= g_TERRAIN_TYPE_PLAINS
    local featureFloodPlains = g_FEATURE_FLOODPLAINS
    local featureIce = g_FEATURE_ICE
    local featureJungle = g_FEATURE_JUNGLE
    local featureForest = g_FEATURE_FOREST
    local featureOasis = g_FEATURE_OASIS
    local featureMarsh = g_FEATURE_MARSH

    local gridWidth, gridHeight = Map.GetGridSize();

    zeroTreesThreshold = rainfallMap:FindThresholdFromPercent(mc.zeroTreesPercent,false,true) --making this global for later use
    jungleThreshold = rainfallMap:FindThresholdFromPercent(mc.junglePercent,false,true)
    --local marshThreshold = rainfallMap:FindThresholdFromPercent(marshPercent,false,true)
    for y = 0, gridHeight - 1,1 do
        for x = 0,gridWidth - 1,1 do
            local i = elevationMap:GetIndex(x,y)
            local plot = Map.GetPlot(x, y)
			local existingFeature = plot:GetFeatureType()
            if (not plot:IsWater()) and existingFeature == g_FEATURE_NONE then --avoid overwriting existing features
                if rainfallMap.data[i] < jungleThreshold then
                    if not plot:IsMountain() then
                        local treeRange = jungleThreshold - zeroTreesThreshold
                        if rainfallMap.data[i] > PWRand() * treeRange + zeroTreesThreshold then
                            if temperatureMap.data[i] > mc.treesMinTemperature then
                                TerrainBuilder.SetFeatureType(plot, featureForest)
                            end
                        end
                    end
                else
                    local marshRange = 1.0 - jungleThreshold
                    if rainfallMap.data[i] > PWRand() * marshRange + jungleThreshold and temperatureMap.data[i] > mc.treesMinTemperature then
                        TerrainBuilder.SetTerrainType(plot, g_TERRAIN_TYPE_GRASS)
                        TerrainBuilder.SetFeatureType(plot, featureMarsh)
                    else
                        if not plot:IsMountain() then
                            if temperatureMap.data[i] < mc.jungleMinTemperature and temperatureMap.data[i] > mc.treesMinTemperature then
                                TerrainBuilder.SetFeatureType(plot, featureForest)
                            elseif temperatureMap.data[i] >= mc.jungleMinTemperature then
                                TerrainBuilder.SetFeatureType(plot, featureJungle)
								if (mc.JungleToPlains == "HILLS_ONLY" or mc.JungleToPlains == "ALL") and plot:IsHills() then
									TerrainBuilder.SetTerrainType(plot,g_TERRAIN_TYPE_PLAINS_HILLS)
								elseif mc.JungleToPlains == "ALL" then
									TerrainBuilder.SetTerrainType(plot,g_TERRAIN_TYPE_PLAINS)									
								end
                            end
                        end
                    end
                end
                if TerrainBuilder.CanHaveFeature(plot, featureFloodPlains) then
                    TerrainBuilder.SetFeatureType(plot, featureFloodPlains)
                end
            end
        end
    end
	local minTemp = 1000
	local maxTemp = -1

    for y = 0, gridHeight - 1,1 do
        for x = 0,gridWidth - 1,1 do

            local plot = Map.GetPlot(x, y)
            if not plot:IsWater() then
                PlacePossibleOasis(x,y)
            else
				local i = elevationMap:GetIndex(x,y)
				local temp = temperatureMap.data[i]
				if temp > maxTemp then
					maxTemp = temp
				end
				if temp < minTemp then
					minTemp = temp
				end
				if g_FEATURE_VOLCANO == nil then --need this if not Gathering Storm
					PlacePossibleIce(x,y)
				end
				PlacePossibleReef(x,y)
            end
        end
    end
--	print("minTemp = ",minTemp)
--	print("maxTemp = ",maxTemp)

end
-- function AddRivers()
    -- --local gridWidth, gridHeight = Map.GetGridSize();
	-- --sort river list by largest first 
	-- table.sort(riverMap.riverList,function (a,b) return #a.junctionList > #b.junctionList end)

    -- for i = 1, #riverMap.riverList do
		-- local river = riverMap.riverList[i]
		-- print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXtraversing river ID", river.riverID)
        -- for n = 1,#river.junctionList do
			-- local junction = river.junctionList[n] 
			-- print(junction:_tostring())
			-- SetJunction(junction)
        -- end
    -- end
-- end
function GetDirectionString(direction)
	if direction == FlowDirectionTypes.FLOWDIRECTION_NORTH then
		return "FLOWDIRECTION_NORTH"
	elseif direction == FlowDirectionTypes.FLOWDIRECTION_NORTHEAST then
		return "FLOWDIRECTION_NORTHEAST"
	elseif direction == FlowDirectionTypes.FLOWDIRECTION_NORTHWEST then
		return "FLOWDIRECTION_NORTHWEST"
	elseif direction == FlowDirectionTypes.FLOWDIRECTION_SOUTH then
		return "FLOWDIRECTION_SOUTH"
	elseif direction == FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST then
		return "FLOWDIRECTION_SOUTHEAST"
	elseif direction == FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST then
		return "FLOWDIRECTION_SOUTHWEST"
	elseif direction == FlowDirectionTypes.NO_FLOWDIRECTION then--try
		return "NO_FLOWDIRECTION"
	end
	return "UNKNOWN_FLOWDIRECTION"
end

_rivers = {}
function AddRivers()
    --local gridWidth, gridHeight = Map.GetGridSize();

    for i = 1, #riverMap.riverList do
		local river = riverMap.riverList[i]
		--print("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXtraversing river ID", river.riverID)
        for n = 1,#river.junctionList do
			local junction = river.junctionList[n] 
			--print("********",junction:_tostring())
			local riverHex = riverMap:GetRiverHexForJunction(junction)
			if riverHex ~= nil then
				--print("***riverHex at",riverHex.x, riverHex.y)
				local plotIndex = elevationMap:GetIndex(riverHex.x, riverHex.y)
				local plot = Map.GetPlotByIndex(plotIndex)
				if _rivers[plotIndex] == nil then		
					local WOfRiver, NWOfRiver, NEOfRiver, ID = riverMap:GetFlowDirections(riverHex.x,riverHex.y)
					--print("returned ID = ",ID)
					if ID ~= nil and river.riverID == ID then
						_rivers[plotIndex] = ID
						if WOfRiver == FlowDirectionTypes.NO_FLOWDIRECTION or ID == nil then
							--TerrainBuilder.SetWOfRiver(plot, false, WOfRiver,0)
						else
							-- local xx,yy = elevationMap:GetNeighbor(x,y,mc.E)
							-- local nPlot = Map.GetPlot(xx,yy)
							-- if plot:IsMountain() and nPlot:IsMountain() then
								-- TerrainBuilder.SetTerrainType(plot, plot:GetTerrainType() - 1) --to hills
							-- end
							TerrainBuilder.SetWOfRiver(plot, true, WOfRiver,ID)
							--print(string.format("(%d,%d)WOfRiver = true dir=%s",riverHex.x,riverHex.y,GetDirectionString(WOfRiver)))
						end

						if NWOfRiver == FlowDirectionTypes.NO_FLOWDIRECTION or ID == nil then
							--TerrainBuilder.SetNWOfRiver(plot, false, NWOfRiver,0)
						else
							-- local xx,yy = elevationMap:GetNeighbor(x,y,mc.SE)
							-- local nPlot = Map.GetPlot(xx,yy)
							-- if plot:IsMountain() and nPlot:IsMountain() then
								-- TerrainBuilder.SetTerrainType(plot, plot:GetTerrainType() - 1)
							-- end
							TerrainBuilder.SetNWOfRiver(plot, true, NWOfRiver, ID)
							--print(string.format("(%d,%d)NWOfRiver = true dir=%s",riverHex.x,riverHex.y,GetDirectionString(NWOfRiver)))
						end

						if NEOfRiver == FlowDirectionTypes.NO_FLOWDIRECTION or ID == nil then
							--TerrainBuilder.SetNEOfRiver(plot, false, NEOfRiver, 0)
						else
							-- local xx,yy = elevationMap:GetNeighbor(x,y,mc.SW)
							-- local nPlot = Map.GetPlot(xx,yy)
							-- if plot:IsMountain() and nPlot:IsMountain() then
								-- TerrainBuilder.SetTerrainType(plot, plot:GetTerrainType() - 1)
							-- end
							TerrainBuilder.SetNEOfRiver(plot, true, NEOfRiver, ID)
							--print(string.format("(%d,%d)NEOfRiver = true dir=%s",riverHex.x,riverHex.y,GetDirectionString(NEOfRiver)))
						end
					else
						--print("river traversal found bad id in river", riverHex.x, riverHex.y)
					end
				else
					--print("skipping hex as already completed")
				end
			end
        end
    end
end
function ClearFloodPlains()
    for i = 1, #riverMap.riverList do
		if i < #riverMap.riverList * mc.percentRiversFloodplains then --only do the largest percent of rivers
			local river = riverMap.riverList[i]
			for n = math.floor(#river.junctionList/2),#river.junctionList do --flood the bottom half
				local junction = river.junctionList[n]	
				--print("n = " .. n)
				local iPlot1, iPlot2 = GetRiverSidesForJunction(junction)
				if iPlot1 ~= nil then
					local pPlot1 = Map.GetPlotByIndex(iPlot1)
					local pPlot2 = Map.GetPlotByIndex(iPlot2)
					if not pPlot1:IsHills() and not pPlot1:IsMountain() then
						if pPlot1:GetFeatureType() == g_FEATURE_FOREST or 
						pPlot1:GetFeatureType() == g_FEATURE_JUNGLE or 
						pPlot1:GetFeatureType() == g_FEATURE_MARSH or 
						pPlot1:GetFeatureType() == g_FEATURE_FLOODPLAINS then
							TerrainBuilder.SetFeatureType(pPlot1,g_FEATURE_NONE)
						end
					end
					if not pPlot2:IsHills() and not pPlot2:IsMountain() then
						if pPlot2:GetFeatureType() == g_FEATURE_FOREST or 
						pPlot2:GetFeatureType() == g_FEATURE_JUNGLE or 
						pPlot2:GetFeatureType() == g_FEATURE_MARSH or 
						pPlot2:GetFeatureType() == g_FEATURE_FLOODPLAINS then
							TerrainBuilder.SetFeatureType(pPlot2,g_FEATURE_NONE)
						end
					end
				end
			end
		end
	end
end
function GetRiverSidesForJunction(junction)
	--returns indexes for two tiles on each side of river flow
	local riverHex1 = nil
	local riverHex2 = nil
	if junction.flow == mc.VERTFLOW then
		riverHex1 = riverMap:GetRiverHexNeighbor(junction,true)
		riverHex2 = riverMap:GetRiverHexNeighbor(junction,false)
	elseif junction.flow == mc.EASTFLOW then
		riverHex1 = riverMap.riverData[elevationMap:GetIndex(junction.x, junction.y)]
		riverHex2 = riverMap:GetRiverHexNeighbor(junction,false)
	elseif junction.flow == mc.WESTFLOW then
		riverHex1 = riverMap:GetRiverHexNeighbor(junction,true)
		riverHex2 = riverMap.riverData[elevationMap:GetIndex(junction.x, junction.y)]	
	end
	if riverHex1 == nil or riverHex2 == nil then
		return nil, nil
	end
	return elevationMap:GetIndex(riverHex1.x,riverHex1.y),elevationMap:GetIndex(riverHex2.x,riverHex2.y)
end
-- function SetJunction(junction)
 	-- --[FlowDirectionTypes.FLOWDIRECTION_NORTH]
	-- --[FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST] 
	-- --[FlowDirectionTypes.FLOWDIRECTION_SOUTH]
	-- --[FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST] 
	-- --[FlowDirectionTypes.FLOWDIRECTION_NORTHWEST]
-- --riverMap:GetRiverHexNeighbor(junction,westNeighbor) format for reference
	-- local riverHex
	-- local plot
	-- local plotIndex
	-- local ID
	-- if junction.isNorth then
		-- if junction.flow == mc.VERTFLOW then
			-- riverHex = riverMap:GetRiverHexNeighbor(junction,true)
			-- plotIndex = elevationMap:GetIndex(riverHex.x,riverHex.y)
			-- plot = Map.GetPlotByIndex(plotIndex)
			-- if _rivers[plotIndex] == nil then
				-- ID = junction.ID
				-- _rivers[plotIndex] = ID
			-- else
				-- ID = _rivers[plotIndex]
			-- end
			-- TerrainBuilder.SetWOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_NORTH,ID)
		-- elseif junction.flow == mc.WESTFLOW then
			-- riverHex = riverMap:GetRiverHexNeighbor(junction,true)
			-- plotIndex = elevationMap:GetIndex(riverHex.x,riverHex.y)
			-- plot = Map.GetPlotByIndex(plotIndex)
			-- if _rivers[plotIndex] == nil then
				-- ID = junction.ID
				-- _rivers[plotIndex] = ID
			-- else
				-- ID = _rivers[plotIndex]
			-- end
			-- TerrainBuilder.SetNWOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST,ID)
		-- elseif junction.flow == mc.EASTFLOW then
			-- riverHex = riverMap:GetRiverHexNeighbor(junction,false)
			-- plotIndex = elevationMap:GetIndex(riverHex.x,riverHex.y)
			-- plot = Map.GetPlotByIndex(plotIndex)
			-- if _rivers[plotIndex] == nil then
				-- ID = junction.ID
				-- _rivers[plotIndex] = ID
			-- else
				-- ID = _rivers[plotIndex]
			-- end
			-- TerrainBuilder.SetNEOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST,ID)			
		-- end
	-- else
		-- if junction.flow == mc.VERTFLOW then
			-- riverHex = riverMap:GetRiverHexNeighbor(junction,true)
			-- plotIndex = elevationMap:GetIndex(riverHex.x,riverHex.y)
			-- plot = Map.GetPlotByIndex(plotIndex)
			-- if _rivers[plotIndex] == nil then
				-- ID = junction.ID
				-- _rivers[plotIndex] = ID
			-- else
				-- ID = _rivers[plotIndex]
			-- end
			-- TerrainBuilder.SetWOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_SOUTH,ID)
		-- elseif junction.flow == mc.WESTFLOW then
			-- --riverHex = riverMap:GetRiverHexNeighbor(junction,true)
			-- plotIndex = elevationMap:GetIndex(junction.x,junction.y)
			-- plot = Map.GetPlotByIndex(plotIndex)
			-- if _rivers[plotIndex] == nil then
				-- ID = junction.ID
				-- _rivers[plotIndex] = ID
			-- else
				-- ID = _rivers[plotIndex]
			-- end
			-- TerrainBuilder.SetNEOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_NORTHWEST,ID)
		-- elseif junction.flow == mc.EASTFLOW then
			-- --riverHex = riverMap:GetRiverHexNeighbor(junction,false)
			-- plotIndex = elevationMap:GetIndex(junction.x,junction.y)
			-- plot = Map.GetPlotByIndex(plotIndex)
			-- if _rivers[plotIndex] == nil then
				-- ID = junction.ID
				-- _rivers[plotIndex] = ID
			-- else
				-- ID = _rivers[plotIndex]
			-- end
			-- TerrainBuilder.SetNWOfRiver(plot, true, FlowDirectionTypes.FLOWDIRECTION_NORTHEAST,ID)			
		-- end
	-- end
-- end
-- function AddRivers()
    -- local gridWidth, gridHeight = Map.GetGridSize();
    -- for y = 0, gridHeight - 1,1 do
        -- for x = 0,gridWidth - 1,1 do
            -- local plot = Map.GetPlot(x, y)
			-- if plot:IsWater() ~= true then		

				-- local WOfRiver, NWOfRiver, NEOfRiver, ID = riverMap:GetFlowDirections(x,y)
				-- --print(string.format("WID = %d, NWID = %d, NEID = %d",WID,NWID,NEID))

				-- if WOfRiver == FlowDirectionTypes.NO_FLOWDIRECTION or ID == nil then
					-- --TerrainBuilder.SetWOfRiver(plot, false, WOfRiver,0)
				-- else
					-- local xx,yy = elevationMap:GetNeighbor(x,y,mc.E)
					-- local nPlot = Map.GetPlot(xx,yy)
					-- if plot:IsMountain() and nPlot:IsMountain() then
						-- TerrainBuilder.SetTerrainType(plot, plot:GetTerrainType() - 1) --to hills
					-- end
					-- TerrainBuilder.SetWOfRiver(plot, true, WOfRiver,ID)
					-- print(string.format("(%d,%d)WOfRiver = true dir=%d",x,y,WOfRiver))
				-- end

				-- if NWOfRiver == FlowDirectionTypes.NO_FLOWDIRECTION or ID == nil then
					-- --TerrainBuilder.SetNWOfRiver(plot, false, NWOfRiver,0)
				-- else
					-- local xx,yy = elevationMap:GetNeighbor(x,y,mc.SE)
					-- local nPlot = Map.GetPlot(xx,yy)
					-- if plot:IsMountain() and nPlot:IsMountain() then
						-- TerrainBuilder.SetTerrainType(plot, plot:GetTerrainType() - 1)
					-- end
					-- TerrainBuilder.SetNWOfRiver(plot, true, NWOfRiver, ID)
					-- print(string.format("(%d,%d)NWOfRiver = true dir=%d",x,y,NWOfRiver))
				-- end

				-- if NEOfRiver == FlowDirectionTypes.NO_FLOWDIRECTION or ID == nil then
					-- --TerrainBuilder.SetNEOfRiver(plot, false, NEOfRiver, 0)
				-- else
					-- local xx,yy = elevationMap:GetNeighbor(x,y,mc.SW)
					-- local nPlot = Map.GetPlot(xx,yy)
					-- if plot:IsMountain() and nPlot:IsMountain() then
						-- TerrainBuilder.SetTerrainType(plot, plot:GetTerrainType() - 1)
					-- end
					-- TerrainBuilder.SetNEOfRiver(plot, true, NEOfRiver, ID)
					-- print(string.format("(%d,%d)NEOfRiver = true dir=%d",x,y,NEOfRiver))
				-- end
			-- end
        -- end
    -- end
-- end

-- function EliminateRiversAtTile(x, y)
-- --This function eliminates rivers running along the shore of a prospective lake
	-- local plot = Map.GetPlot(x, y)
	-- TerrainBuilder.SetWOfRiver(plot,false,FlowDirectionTypes.NO_FLOWDIRECTION)
	-- TerrainBuilder.SetNWOfRiver(plot,false,FlowDirectionTypes.NO_FLOWDIRECTION)
	-- TerrainBuilder.SetNEOfRiver(plot,false,FlowDirectionTypes.NO_FLOWDIRECTION)
	
	-- --now do 3 neighbors
	-- local nPlot = Map.GetPlot(elevationMap:GetNeighbor(x,y,mc.E))
	-- TerrainBuilder.SetWOfRiver(nPlot,false,FlowDirectionTypes.NO_FLOWDIRECTION)
	-- nPlot = Map.GetPlot(elevationMap:GetNeighbor(x,y,mc.SE))
	-- TerrainBuilder.SetNWOfRiver(nPlot,false,FlowDirectionTypes.NO_FLOWDIRECTION)
	-- nPlot = Map.GetPlot(elevationMap:GetNeighbor(x,y,mc.SW))
	-- TerrainBuilder.SetNEOfRiver(nPlot,false,FlowDirectionTypes.NO_FLOWDIRECTION)

-- end

function AddLakes()
	local gridWidth, gridHeight = Map.GetGridSize();
	for y = 0, gridHeight - 1,1 do
		for x = 0,gridWidth - 1,1 do
			local i = elevationMap:GetIndex(x,y)
			if riverMap.riverData[i].lakeID ~= -1 then
				local plot = Map.GetPlot(x,y)
				TerrainBuilder.SetTerrainType(plot, g_TERRAIN_TYPE_COAST)
			end
		end
	end
	
end

function GetRadiusAroundCell(x,y,radius)

	local gridWidth, gridHeight = Map.GetGridSize();
	local cellList = {}
	--print("watching GetRadiusAroundCell")

	for i = 1,radius,1 do
		--move here 1 West
		x, y = elevationMap:GetNeighbor(x,y,mc.W)
		--add to list if valid
		if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then
			--print(string.format("i = %d storing %d %d ",i,x,y))
			table.insert(cellList,y*gridWidth + x)
		end

		--go NE i times
		for z = 0, i -1,1 do
			x, y = elevationMap:GetNeighbor(x,y,mc.NE)
			if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then	
				--print(string.format("i = %d storing %d %d ",i,x,y))
				table.insert(cellList,y*gridWidth + x)
			end
		end
		--go E i times
		for z = 0, i -1,1 do
			x, y = elevationMap:GetNeighbor(x,y,mc.E)
			if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then
				--print(string.format("i = %d storing %d %d ",i,x,y))			
				table.insert(cellList,y*gridWidth + x)
			end
		end
		--go SE i times
		for z = 0, i -1,1 do
			x, y = elevationMap:GetNeighbor(x,y,mc.SE)
			if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then	
				--print(string.format("i = %d storing %d %d ",i,x,y))
				table.insert(cellList,y*gridWidth + x)
			end
		end
		--go SW i times
		for z = 0, i -1,1 do
			x, y = elevationMap:GetNeighbor(x,y,mc.SW)
			if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then		
				--print(string.format("i = %d storing %d %d ",i,x,y))
				table.insert(cellList,y*gridWidth + x)
			end
		end
		--go W i times
		for z = 0, i -1,1 do
			x, y = elevationMap:GetNeighbor(x,y,mc.W)
			if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then	
				--print(string.format("i = %d storing %d %d ",i,x,y))
				table.insert(cellList,y*gridWidth + x)
			end
		end
		--go NW i - 1 times
		for z = 0, i -2,1 do
			x, y = elevationMap:GetNeighbor(x,y,mc.NW)
			if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then
				--print(string.format("i = %d storing %d %d ",i,x,y))
				table.insert(cellList,y*gridWidth + x)
			end
		end
		--One more NW for full circle. Do not store
		x, y = elevationMap:GetNeighbor(x,y,mc.NW)
	end

	--print(string.format("length of cellList = %d",#cellList))
	return cellList;			
end

function GetRingAroundCell(x,y,radius)

	local gridWidth, gridHeight = Map.GetGridSize();
	local cellList = {}

	for i = 0,radius - 1,1 do
		--move West radius times
		x, y = elevationMap:GetNeighbor(x,y,mc.W)
		--add to list if valid but only last entry this first time
		if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight and i == radius - 1 then		
			table.insert(cellList,y*gridWidth + x)
		end
	end
		--go NE i times
	for z = 0, radius - 1,1 do
		x, y = elevationMap:GetNeighbor(x,y,mc.NE)
		if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then		
			table.insert(cellList,y*gridWidth + x)
		end
	end
	--go E i times
	for z = 0, radius - 1,1 do
		x, y = elevationMap:GetNeighbor(x,y,mc.E)
		if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then		
			table.insert(cellList,y*gridWidth + x)
		end
	end
	--go SE i times
	for z = 0, radius - 1,1 do
		x, y = elevationMap:GetNeighbor(x,y,mc.SE)
		if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then		
			table.insert(cellList,y*gridWidth + x)
		end
	end
	--go SW i times
	for z = 0, radius - 1,1 do
		x, y = elevationMap:GetNeighbor(x,y,mc.SW)
		if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then		
			table.insert(cellList,y*gridWidth + x)
		end
	end
	--go W i times
	for z = 0, radius -1,1 do
		x, y = elevationMap:GetNeighbor(x,y,mc.W)
		if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then		
			table.insert(cellList,y*gridWidth + x)
		end
	end
	--go NW i - 1 times
	for z = 0, radius - 1,1 do
		x, y = elevationMap:GetNeighbor(x,y,mc.NW)
		if x >= 0 and x < gridWidth and y >= 0 and y < gridHeight then		
			table.insert(cellList,y*gridWidth + x)
		end
	end

	return cellList;			
end

------------------------------------------------------------------------------
function isNonCoastWaterMatch(x,y)
    local i = elevationMap:GetIndex(x,y)
    if pb.terrainTypes[i] == g_TERRAIN_TYPE_OCEAN then
        return true
    end
    return false
end     

PangaeaBreaker = inheritsFrom(nil)

function PangaeaBreaker:New()
	local new_inst = {}
	setmetatable(new_inst, {__index = PangaeaBreaker});
	
	return new_inst
end

function PangaeaBreaker:breakPangaeas(plotTypes, terrainTypes)
	self.areaMap = PWAreaMap:New(elevationMap.width,elevationMap.height,elevationMap.wrapX,elevationMap.wrapY)
    local meteorThrown = false
    local pangeaDetected = false
    self.terrainTypes = terrainTypes
    
    --self:createDistanceMap()
--##        self.printDistanceMap()
    self.areaMap:DefineAreas(isNonCoastWaterMatch,false)
--##        self.areaMap.PrintAreaMap()
    local meteorCount = 0
	print("mc.AllowPangeas = %b",mc.AllowPangeas)
	print("mc.maximumMeteorCount = %d", mc.maximumMeteorCount)
    while ((not mc.AllowPangeas) and self:isPangea() and meteorCount < mc.maximumMeteorCount) do
   
        pangeaDetected = true
        local x,y = self:getMeteorStrike()
        print(string.format("A meteor has struck the Earth at %d, %d!",x,y))
        self:castMeteorUponTheEarth(x,y,plotTypes, terrainTypes)
        meteorThrown = true
        meteorCount = meteorCount + 1
--##            hm.printHeightMap()
        --self:createDistanceMap(terrainTypes)
--##            self.printDistanceMap()
        self.areaMap:DefineAreas(isNonCoastWaterMatch,false)
--##            self.areaMap.PrintAreaMap()
--##            anotherPangaea = False
    end    
    if meteorCount == mc.maximumMeteorCount then
        print(string.format("Maximum meteor count of %d has been reached. Pangaea may still exist.",meteorCount))
		return false
    end
	
	if meteorThrown then
        print("The age of dinosours has come to a cataclysmic end.")
    end
    if mc.AllowPangeas then
		self.oldWorldPercent = 1.0
        print("Pangeas are allowed on this map and will not be suppressed.")
    elseif pangeaDetected == false then
        print("No pangea detected on this map.")
    end
	return true
end

function PangaeaBreaker:isPangea()
--##        starttime = time.clock()
	print("testing pangaea")
    local continentList = {}
    for i = 1, #self.areaMap.areaList do
		a = self.areaMap.areaList[i]
		--print("areaID = %d".self.areaMap.areaList[i].ID
        if a.trueMatch == false then
            table.insert(continentList,a)
        end
    end

    local totalLand = 0             
    for i = 1, #continentList do
		c = continentList[i]
        totalLand = totalLand + c.size
    end
	print(string.format("totalLand = %d", totalLand))
    --#sort all the continents by size, largest first
	table.sort(continentList,function (a,b) return a.size > b.size end)
	
    --continentList.sort(lambda x,y:cmp(x.size,y.size))
   -- continentList.reverse()
   
    local biggestSize = continentList[1].size
    print(string.format("biggest continent = %d", biggestSize))
	
	print(string.format("percent of biggest = %f", biggestSize/totalLand))
	
    self.oldWorldPercent = biggestSize/totalLand
    if mc.PangaeaSize  < biggestSize/totalLand then
        return true
	end
    return false
end

function PangaeaBreaker:getMeteorStrike()
--##        starttime = time.clock()
    local continentList = {}
    for i = 1,#self.areaMap.areaList do
		a = self.areaMap.areaList[i]
        if a.trueMatch == false then
            table.insert(continentList,a)
        end
    end
        
    --sort all the continents by size, largest first
	table.sort(continentList,function (a,b) return a.size > b.size end)
    biggestContinentID = continentList[1].id

    x,y = self:getHighestCentrality(biggestContinentID)

    return x,y
end
                                    
function PangaeaBreaker:castMeteorUponTheEarth(x,y,plotTypes, terrainTypes)
--##        starttime = time.clock()
	local gridWidth, gridHeight = Map.GetGridSize();
    local radius = PWRandint(mc.minimumMeteorSize,math.max(mc.minimumMeteorSize + 1,math.floor(gridWidth/16)))
    local ringList = GetRingAroundCell(x,y,radius)
    local innerList = GetRadiusAroundCell(x,y,radius - 1)
	print(string.format("meteor damage radius = %d at %d, %d",radius,x,y))
	
	--destroy center
	local i = elevationMap:GetIndex(x,y)
	terrainTypes[i] = g_TERRAIN_TYPE_OCEAN
	plotTypes[i] = g_PLOT_TYPE_OCEAN
	elevationMap.data[i] = elevationMap.seaLevelThreshold - 0.01

	--print("ring loop")
    for i=1,#ringList,1 do

		local xx, yy = elevationMap:GetXYFromIndex(ringList[i])
    	if terrainTypes[ringList[i]] ~= g_TERRAIN_TYPE_OCEAN then
    		terrainTypes[ringList[i]] = g_TERRAIN_TYPE_COAST
			elevationMap.data[i] = elevationMap.seaLevelThreshold - 0.01
			--print(string.format("%d, %d changed to coast",xx,yy))
		else
			--print(string.format("%d, %d already ocean not changed",xx,yy))
    	end
		plotTypes[ringList[i]] = g_PLOT_TYPE_OCEAN
		elevationMap.data[i] = elevationMap.seaLevelThreshold - 0.01
    end
	--print("innerLoop")
    for i=1,#innerList,1 do
		local xx, yy = elevationMap:GetXYFromIndex(innerList[i])
    	terrainTypes[innerList[i]] = g_TERRAIN_TYPE_OCEAN
		plotTypes[innerList[i]] = g_PLOT_TYPE_OCEAN
		elevationMap.data[i] = elevationMap.seaLevelThreshold - 0.01

		--print(string.format("%d, %d changed to ocean",xx,yy))
    end
end
    
function PangaeaBreaker:createDistanceMap(terrainTypes)
	local gridWidth, gridHeight = Map.GetGridSize();
    self.distanceMap = {}
    processQueue = {}
    for i = 0,gridWidth*gridHeight-1,1 do
    	if terrainTypes[i] == g_TERRAIN_TYPE_OCEAN then
    		self.distanceMap[i] = 2000
    	else
    		self.distanceMap[i] = 0
    		table.insert(processQueue,i)
    	end
    end
                    
    while #processQueue > 0 do
        local i = table.remove(processQueue,0)
        distanceToLand = self.distanceMap[i]
        local x, y = elevationMap:GetXYFromIndex(i)
        for direction = 1,6,1 do
            xx,yy = elevationMap:GetNeighbor(x,y,direction)
            ii = elevationMap:GetIndex(xx,yy)
            neighborDistanceToLand = self.distanceMap[ii]
            if neighborDistanceToLand > distanceToLand + 1 then
                self.distanceMap[ii] = distanceToLand + 1 --grow entry
                table.insert(processQueue,ii) --process entry again
          	end
      	end
	end
end
             
function PangaeaBreaker:getHighestCentrality(ID)
    C = self:createCentralityList(ID)
    table.sort(C,function (a,b) return a.centrality > b.centrality end)
	print("length of C is %d", #C)
	print(string.format("highest centrality is %d",C[1].centrality))
    return C[1].x,C[1].y
end
    
--creates the sub portion of the continent to be analyzed this was meant to save processing time    
function PangaeaBreaker:createContinentList(ID)
--	for now we will not use gaps and see how it goes
	local gridWidth, gridHeight = Map.GetGridSize();
    local C = {}
    local indexMap = {}
    --local gap = 5 --try to take a rough sample instead of evaluating whole continent
    local n = 1 --crappy lua 1 based indexing
	print(string.format("biggest ID = %d",ID))
    for i = 0,gridWidth * gridHeight - 1,1 do

		--print(self.areaMap.data[i])
		-- print("self.areaMap.data[i] = %d",self.areaMap.data[i])
    	if self.areaMap.data[i] == ID then
    		local x, y = elevationMap:GetXYFromIndex(i)
    		local s = CentralityScore:New(x,y)
    		table.insert(C, s)
    		indexMap[i] = n
    		n = n + 1
    	else
    		indexMap[i] = -1  
		end
    end
    
    for i = 1,#C do
    	local s = C[i]
    	local x = s.x
    	local y = s.y
		nList = GetRadiusAroundCell(x,y,1)
		--print(string.format("neighbors = %d",#nList))		
		for nn = 1,#nList,1 do
			if self.areaMap.data[nList[nn]] == ID then
				table.insert(s.neighborList,indexMap[nList[nn]])
			end
		end
		--nTable = s.neighborList
		--print(string.format("neighbors = %d",#nTable))
	
    end

    return C
end
            
function PangaeaBreaker:createCentralityList(ID)

    C = self:createContinentList(ID)
    
    print(string.format("length of C after createContinentList is %d",#C))
    
    for s = 1,#C,1 do
        local S = {}
        local P = {}
        local sigma = {}
        local d = {}
        local delta = {}
        for t = 1,#C,1 do 
            table.insert(sigma,0)
            table.insert(d,-1)
            table.insert(P, {})
            table.insert(delta,0)
        end
        sigma[s] = 1
        d[s] = 0
        local Q = {}
        table.insert(Q,s)
        while #Q > 0 do
			--print(string.format("top of Q loop length of Q is %d", #Q))
            local v = table.remove(Q,1)
			--print(string.format("v = %d, length of C[v].neighborList = %d",v,#(C[v].neighborList)))
			table.insert(S,v)
			--print(string.format("adding to S length of S is %d", #S))
			for i = 1,#(C[v].neighborList) do
				local w = C[v].neighborList[i]
				--print(string.format("w = %d",w))
                if d[w] < 0 then
                    table.insert(Q,w)
                    --print(string.format("adding to Q length of Q is %d", #Q))
                    d[w] = d[v] + 1
                end
                if d[w] == d[v] + 1 then
                    sigma[w] = sigma[w] + sigma[v]
                    table.insert(P[w],v)
					--print(string.format("adding to P[w] length of P[w] is %d", #P[w]))
                end
         	end
       	end
        while #S > 0 do
			--print(string.format("top of S loop length of S is %d", #S))
            local w = table.remove(S)
			--print(string.format("w = %d",w))
			for i = 1,#P[w] do
				--print(string.format("top of P[w] loop, length = %d",#P[w]))
				local v = P[w][i] 
				--print(string.format("v = %d",v))

                delta[v] = delta[v] + math.floor(sigma[v] / sigma[w]) * (1 + delta[w])
				--print(string.format("delta[v] = %d",delta[v]))
			end
			if w ~= s then
				C[w].centrality = C[w].centrality + delta[w]
				--print(string.format("C[%d].centrality = %d",w,C[w].centrality))
			end

		end
    end
    return C
    
end
function PangaeaBreaker:createNewWorldMap()
	local gridWidth, gridHeight = Map.GetGridSize();
	self.newWorldMap = {}
	self.oldWorldMap = {}
	local newWorldList = {}
	self.areaMap:DefineAreas(isNonCoastWaterMatch,false)
    local continentList = {}
    for i = 1, #self.areaMap.areaList do
		a = self.areaMap.areaList[i]
		--print("areaID = %d".self.areaMap.areaList[i].ID
        if a.trueMatch == false then
            table.insert(continentList,a)
        end
    end

    --#sort all the continents by size, largest first
	table.sort(continentList,function (a,b) return a.size > b.size end)
	   
    local biggestSize = continentList[1].size
    print(string.format("biggest continent = %d", biggestSize))
		
	local totalLand = 0             
    for i = 1, #continentList do
		c = continentList[i]
        totalLand = totalLand + c.size
    end
	print(string.format("totalLand = %d", totalLand))
	
	table.remove(continentList,1)
	table.insert(newWorldList,continentList[1].id) --second biggest is now biggest
	local newWorldSize = continentList[1].size
	table.remove(continentList,1)
	
	--#sort remaining continents by ID, to mix it up
	table.sort(continentList,function (a,b) return a.id > b.id end)

	--add new world continents until mc.maxNewWorldSize is reached
    for i = 1, #continentList do
		c = continentList[i]
        if (newWorldSize + c.size)/totalLand < mc.maxNewWorldSize then
			table.insert(newWorldList,c.id)
			newWorldSize = newWorldSize + c.size
		end
    end
	
	print(string.format("new world percent = %f", newWorldSize/totalLand))
	
	--first assume old world
	for ii = 0,gridWidth * gridHeight - 1 do	
		self.newWorldMap[ii] = false
	end

	--mark new world
	for i = 1,#newWorldList do
		local thisID = newWorldList[i]
		print(string.format("New World Continent with size %d",self.areaMap:GetAreaByID(thisID).size))
		for ii = 0,gridWidth * gridHeight - 1 do
			if self.areaMap.data[ii] == thisID then
				self.newWorldMap[ii] = true
			end		
		end
	end

end

--returns true if new world
function PangaeaBreaker:isTileNewWorld(i)
	return self.newWorldMap[i]
end

function PangaeaBreaker:getOldWorldPlots()
	local gridWidth, gridHeight = Map.GetGridSize();
	local plots = {}
	for ii = 0,gridWidth * gridHeight - 1 do
		--local ii = inputPlots[n]:GetIndex()
		if self:isTileNewWorld(ii) == false then
			local plot = Map.GetPlotByIndex(ii)
			if not plot:IsWater() then
				--check that area is fairly large
				local area = self.areaMap:GetAreaByID(self.areaMap.data[ii])
				if(area.size > 30) then
					table.insert(plots,ii)
				end					
			end
		end
	end
	return plots
end

CentralityScore = inheritsFrom(nil)

function CentralityScore:New(x,y)
	local new_inst = {}
	setmetatable(new_inst, {__index = PWAreaMap});	--setup metatable

	new_inst.x = x
	new_inst.y = y
	new_inst.centrality = 0
	new_inst.neighborList = {}
	return new_inst
end

--******************Starting Plot stuff************************************
function isCityRealEstateMatch(x,y)
    local i = elevationMap:GetIndex(x,y)
	local plot = Map.GetPlotByIndex(i)
    if plot:IsImpassable() or plot:IsWater() then
		--print(string.format("%d, %d plot impassable or water. failed. impass = %s water = %s",x,y,tostring(plot:IsImpassable()),tostring(plot:IsWater())))
        return false
    end
	local dist = Map.GetPlotDistance(latestStartPlotIndex, i)
	--print(string.format("plot distance from %d to %d = %d",latestStartPlotIndex,i,dist))
	if dist > 3 then
		--print(string.format("%d, %d rejected too distant at distance = %d",x,y,dist))
		return false
	end
	--print(string.format("%d, %d passed",x,y))
    return true
end    

function getOldWorldPlots()
	local gridWidth, gridHeight = Map.GetGridSize();
	local plots = {}
	for ii = 0,gridWidth * gridHeight - 1 do
		--local ii = inputPlots[n]:GetIndex()
		if pb:isTileNewWorld(ii) == false then
			local plot = Map.GetPlotByIndex(ii)
			if not plot:IsWater() then
				table.insert(plots,ii)
			end
		end
	end
	return plots
end
function getNewWorldPlots()
	local gridWidth, gridHeight = Map.GetGridSize();
	local plots = {}
	for ii = 0,gridWidth * gridHeight - 1 do
		--local ii = inputPlots[n]:GetIndex()
		if pb:isTileNewWorld(ii) == true then
			local plot = Map.GetPlotByIndex(ii)
			if not plot:IsWater() then
				table.insert(plots,ii)				
			end
		end
	end
	return plots
end
function filterBadStarts(spd, badStarts, bMajor)
	--badStarts is a plot index, not a plot
	local betterStarts = {}
	for n=1,#badStarts do
		local fertility = spd:__BaseFertility(badStarts[n])
		--print("fertility of index " .. n .. " = " .. fertility)
		local ii = badStarts[n]
		local area = pb.areaMap:GetAreaByID(pb.areaMap.data[ii])
		if bMajor and fertility >= 10 then
			if area.size > 30 then --don't strand people on tiny islands
				table.insert(betterStarts,badStarts[n])
			end
		elseif not bMajor and fertility >= 5 then
			if area.size > 5 then --minors can get the dregs
				table.insert(betterStarts,badStarts[n])
			end
		end
	end
	if #betterStarts <= 0 then
		error("all starts filtered out")
	end
	return betterStarts
end
 
function AssignStartingPlots:__InitStartingData()
	print("Initializing start plot data for PerfectWorld6")
	if(self.uiMinMajorCivFertility <= 0) then
		self.uiMinMajorCivFertility = 5;
	end

	if(self.uiMinMinorCivFertility <= 0) then
		self.uiMinMinorCivFertility = 5;
	end

	--Find Default Number
	MapSizeTypes = {};
	for row in GameInfo.Maps() do
		MapSizeTypes[row.RowId] = row.DefaultPlayers;
	end
	local sizekey = Map.GetMapSize() + 1;
	local iDefaultNumberPlayers = MapSizeTypes[sizekey] or 8;
	self.iDefaultNumberMajor = iDefaultNumberPlayers ;
	self.iDefaultNumberMinor = math.floor(iDefaultNumberPlayers * 1.5);

	-- See if there are any civs starting out in the water
	local tempMajorList = {};
	self.majorList = {};
	self.waterMajorList = {};
	self.iNumMajorCivs = 0;
	self.iNumWaterMajorCivs = 0;

	tempMajorList = PlayerManager.GetAliveMajorIDs();
	for i = 1, PlayerManager.GetAliveMajorsCount() do
		local leaderType = PlayerConfigurations[tempMajorList[i]]:GetLeaderTypeName();
		if (GameInfo.Leaders_XP2 ~= nil and GameInfo.Leaders_XP2[leaderType] ~= nil and GameInfo.Leaders_XP2[leaderType].OceanStart == true) then
			table.insert(self.waterMajorList, tempMajorList[i]);
			self.iNumWaterMajorCivs = self.iNumWaterMajorCivs + 1;
			print ("Found the Maori");
		else
			table.insert(self.majorList, tempMajorList[i]);
			self.iNumMajorCivs = self.iNumMajorCivs + 1;
		end
	end 

	-- Do we have enough water on this map for the number of water civs specified?
	if g_FEATURE_VOLCANO ~= nil then
		local TILES_NEEDED_FOR_WATER_START = 8;
		if (self.waterMap == true) then
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
	end

	self.iNumMinorCivs = PlayerManager.GetAliveMinorsCount();
	self.minorList = {};
	self.minorList = PlayerManager.GetAliveMinorIDs();
	self.iNumRegions = self.iNumMajorCivs + self.iNumMinorCivs;
	local iMinNumBarbarians = self.iNumMajorCivs / 2;

	StartPositioner.DivideMapIntoMajorRegions(self.iNumMajorCivs, self.uiMinMajorCivFertility, self.uiMinMinorCivFertility);
	local iMajorCivStartLocs = StartPositioner.GetNumMajorCivStarts(); --might need to print this for debugging
	
	local rawOldWorldPlots = getOldWorldPlots()
	local rawNewWorldPlots = getNewWorldPlots()
	local majorOWPotentials = filterBadStarts(self,rawOldWorldPlots, true)
	local minorOWPotentials = filterBadStarts(self,rawOldWorldPlots, false)
	local minorNWPotentials = filterBadStarts(self,rawNewWorldPlots, false)

	-- Place the major civ start plots in an array
	self.majorStartPlots = {};
	local failed = 0;
	for i = self.iNumMajorCivs - 1, 0, - 1 do
		local tempPlots = StartPositioner.GetMajorCivStartPlots(i);		
		if mc.OldWorldStart then
			plots = majorOWPotentials
		else
			plots = tempPlots
		end
		
		local startPlot = self:__SetStartMajor(plots, i);
		if(startPlot ~= nil) then
			StartPositioner.MarkMajorRegionUsed(i);
			table.insert(self.majorStartPlots, startPlot);
			info = StartPositioner.GetMajorCivStartInfo(i);
			print ("Major civ" .. tostring(i) .. "=============================")
			print ("ContinentType: " .. tostring(info.ContinentType));
			print ("LandmassID: " .. tostring(info.LandmassID));
			print ("Fertility: " .. tostring(info.Fertility));
			print ("TotalPlots: " .. tostring(info.TotalPlots));
			print ("WestEdge: " .. tostring(info.WestEdge));
			print ("EastEdge: " .. tostring(info.EastEdge));
			print ("NorthEdge: " .. tostring(info.NorthEdge));
			print ("SouthEdge: " .. tostring(info.SouthEdge));
		else
			failed = failed + 1;
			info = StartPositioner.GetMajorCivStartInfo(i);
			print ("-- START FAILED MAJOR --");
			print ("ContinentType: " .. tostring(info.ContinentType));
			print ("LandmassID: " .. tostring(info.LandmassID));
			print ("Fertility: " .. tostring(info.Fertility));
			print ("TotalPlots: " .. tostring(info.TotalPlots));
			print ("WestEdge: " .. tostring(info.WestEdge));
			print ("EastEdge: " .. tostring(info.EastEdge));
			print ("NorthEdge: " .. tostring(info.NorthEdge));
			print ("SouthEdge: " .. tostring(info.SouthEdge));
			print ("-- END FAILED MAJOR --");
		end
	end
	for k, plot in ipairs(self.majorStartPlots) do
		table.insert(self.majorCopy, plot);
	end

	--Begin Start Bias for major
	self:__InitStartBias(false);

	if(self.uiStartConfig == 1 ) then
		self:__AddResourcesBalanced();
	elseif(self.uiStartConfig == 3 ) then
		self:__AddResourcesLegendary();
	end

	local aMajorStartPlotIndices = {};
	for i = 1, self.iNumMajorCivs do
		local player = Players[self.majorList[i]]
		
		if(player == nil) then
			print("THIS PLAYER FAILED");
		else
			local hasPlot = false;
			for k, v in pairs(self.playerStarts[i]) do
				if(v~= nil and hasPlot == false) then
					hasPlot = true;
					player:SetStartingPlot(v);
					table.insert(aMajorStartPlotIndices, v:GetIndex());
					print("Major Start X: ", v:GetX(), "Major Start Y: ", v:GetY());
				end
			end
		end
	end

	StartPositioner.DivideMapIntoMinorRegions(self.iNumMinorCivs);
	
	local numMinorsInNewWorld = 0
	if mc.ProportionalMinors then
		numMinorsInNewWorld = math.floor((1.0 - pb.oldWorldPercent) * self.iNumMinorCivs)
	end
	print(string.format("%d minor civs total, %d in new world",self.iNumMinorCivs,numMinorsInNewWorld))

	local iMinorCivStartLocs = StartPositioner.GetNumMinorCivStarts();
	local i = 0;
	local valid = 0;
	while i <= iMinorCivStartLocs - 1 and valid < self.iNumMinorCivs do
	
		if mc.OldWorldStart then
			if mc.ProportionalMinors and valid < numMinorsInNewWorld then
				plots = minorNWPotentials
			else
				plots = minorOWPotentials
			end
		else
			plots = StartPositioner.GetMinorCivStartPlots(i);
		end
		
		local startPlot = self:__SetStartMinor(plots);
		info = StartPositioner.GetMinorCivStartInfo(i);
		if(startPlot ~= nil) then
			table.insert(self.minorStartPlots, startPlot);
			print ("Minor civ---------------------------")
			print ("Minor ContinentType: " .. tostring(info.ContinentType));
			print ("Minor LandmassID: " .. tostring(info.LandmassID));
			print ("Minor Fertility: " .. tostring(info.Fertility));
			print ("Minor TotalPlots: " .. tostring(info.TotalPlots));
			print ("Minor WestEdge: " .. tostring(info.WestEdge));
			print ("Minor EastEdge: " .. tostring(info.EastEdge));
			print ("Minor NorthEdge: " .. tostring(info.NorthEdge));
			print ("Minor SouthEdge: " .. tostring(info.SouthEdge));
			valid = valid + 1;
		else
			print ("-- START FAILED MINOR --");
			print ("Minor ContinentType: " .. tostring(info.ContinentType));
			print ("Minor LandmassID: " .. tostring(info.LandmassID));
			print ("Minor Fertility: " .. tostring(info.Fertility));
			print ("Minor TotalPlots: " .. tostring(info.TotalPlots));
			print ("Minor WestEdge: " .. tostring(info.WestEdge));
			print ("Minor EastEdge: " .. tostring(info.EastEdge));
			print ("Minor NorthEdge: " .. tostring(info.NorthEdge));
			print ("Minor SouthEdge: " .. tostring(info.SouthEdge));
			print ("-- END FAILED MINOR --");
		end
		
		i = i + 1;
	end

	for k, plot in ipairs(self.minorStartPlots) do
		table.insert(self.minorCopy, plot);
	end

	--Begin Start Bias for minor
	self:__InitStartBias(true);

	for i = 1, self.iNumMinorCivs do
		local player = Players[self.minorList[i]]
		
		if(player == nil) then
			print("THIS PLAYER FAILED");
		else
			local hasPlot = false;
			for k, v in pairs(self.playerStarts[i + self.iNumMajorCivs]) do
				if(v~= nil and hasPlot == false) then
					hasPlot = true;
					player:SetStartingPlot(v);
					print("Minor Start X: ", v:GetX(), "Minor Start Y: ", v:GetY());
				end
			end
		end
	end

	-- Finally place the ocean civs
	if (self.iNumWaterMajorCivs > 0) then
		local iWaterCivs = StartPositioner.PlaceOceanStartCivs(self.waterMap, self.iNumWaterMajorCivs, aMajorStartPlotIndices);
		for i = 1, iWaterCivs do
			local waterPlayer = Players[self.waterMajorList[i]]
			local iStartIndex = StartPositioner.GetOceanStartTile(i - 1);  -- Indices start at 0 here
			local pStartPlot = Map.GetPlotByIndex(iStartIndex);
			waterPlayer:SetStartingPlot(pStartPlot);
			print("Water Start X: ", pStartPlot:GetX(), "Water Start Y: ", pStartPlot:GetY());
		end
		if (iWaterCivs < self.iNumWaterMajorCivs) then
			print("FAILURE PLACING WATER CIVS - Missing civs: " .. tostring(self.iNumWaterMajorCivs - iWaterCivs));
		end
	end
end

function AssignStartingPlots:__SetStartMajor(plots, iMajorIndex)
	-- Sort by fertility of all the plots
	-- eliminate them if they do not meet the following:
	-- distance to another civilization
	-- distance to a natural wonder
	-- minimum production
	-- minimum food
	-- minimum luxuries
	-- minimum strategic

	sortedPlots ={};

	if plots == nil then
		return;
	end

	local iSize = #plots;
	local iContinentIndex = 1;
	
	-- Nothing there?  Just exit, returing nil
	if iSize == 0 then
		error("feeding no plots to SetStartMajor")
		return;
	end
		
	for i, plot in ipairs(plots) do
		row = {};
		row.Plot = plot;
		row.Fertility = self:__WeightedFertility(plot, iMajorIndex, true);
		table.insert (sortedPlots, row);

	end
	
	if #sortedPlots == 0 then
		error("No plots to start in")
	end

	if(self.uiStartConfig > 1 ) then
		table.sort (sortedPlots, function(a, b) return a.Fertility > b.Fertility; end);
	else
		self.sortedFertilityArray = {};
		sortedPlotsFertility = {};
		sortedPlotsFertility = self:__PreFertilitySort(sortedPlots);
		self:__SortByFertilityArray(sortedPlots, sortedPlotsFertility);
		for k, v in pairs(sortedPlots) do
			sortedPlots[k] = nil;
		end
		for i, newPlot in ipairs(self.sortedFertilityArray) do
			row = {};
			row.Plot = newPlot.Plot;
			row.Fertility = newPlot.Fertility;
			table.insert (sortedPlots, row);
		end
	end
	
	if(self.areaMap == nil) then--try to do this only once
		self.areaMap = PWAreaMap:New(elevationMap.width,elevationMap.height,elevationMap.wrapX,elevationMap.wrapY)
	end

	local bValid = false;
	local pFallback:table = Map.GetPlotByIndex(sortedPlots[1].Plot);
	local iFallBackScore = -1;
	while bValid == false and iSize >= iContinentIndex do
		bValid = true;
		local NWMajor = 0;
		pTempPlot = Map.GetPlotByIndex(sortedPlots[iContinentIndex].Plot);
				
		iContinentIndex = iContinentIndex + 1;
		--print("Fertility: ", sortedPlots[iContinentIndex].Fertility)

		-- Checks to see if the plot is impassable
		if(pTempPlot:IsImpassable() == true) then
			bValid = false;
		else
			local iFallBackScoreTemp = 0;
			if (iFallBackScore < iFallBackScoreTemp) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		-- Checks to see if the plot is water
		if(pTempPlot:IsWater() == true) then
			bValid = false;
		else
			local iFallBackScoreTemp = 1;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end
				
		-- Checks to see if there are any major civs in the given distance
		local bMajorCivCheck = self:__MajorCivBuffer(pTempPlot); 
		if(bMajorCivCheck == false) then
			bValid = false;
		else
			local iFallBackScoreTemp = 2;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end	
		
		--check if there is enough real estate nearby for a decent capital
		local latestStartPlot = pTempPlot
		local plotX = latestStartPlot:GetX()
		local plotY = latestStartPlot:GetY()
		latestStartPlotIndex = latestStartPlot:GetIndex()
		--print("initial start plot check")
		if bValid and isCityRealEstateMatch(plotX,plotY) then
			self.areaMap:Clear() --clear each time to prevent collisions
			local area = PWArea:New(1,plotX,plotY,true)
			--area.debug = true
			self.areaMap:FillArea(plotX,plotY,area,isCityRealEstateMatch)
			if area.size < mc.realEstateMin then
				print(string.format("area.size = %d not enough real estate on plot %d, %d *************************",area.size,plotX,plotY))
				bValid = false;
			else
				print(string.format("start plot at %d, %d has enough real estate at %d tiles", plotX, plotY, area.size))
				local iFallBackScoreTemp = 3;
				if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
					pFallback = pTempPlot;
					iFallBackScore = iFallBackScoreTemp;
				end
			end
		else
			bValid = false
		end

		-- Checks to see if there are luxuries
		if (math.ceil(self.iDefaultNumberMajor * 1.25) + self.iDefaultNumberMinor > self.iNumMinorCivs + self.iNumMajorCivs) then
			local bLuxuryCheck = self:__LuxuryBuffer(pTempPlot); 
			if(bLuxuryCheck  == false) then
				bValid = false;
			else
				local iFallBackScoreTemp = 4;
				if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
					pFallback = pTempPlot;
					iFallBackScore = iFallBackScoreTemp;
				end
			end
		end
		

		--Checks to see if there are strategics
		-- local bStrategicCheck = self:__StrategicBuffer(pTempPlot); 
		-- if(bStrategicCheck  == false) then
		-- 	bValid = false;
		-- end

		-- Checks to see if there is fresh water or coast
		local bWaterCheck = self:__GetWaterCheck(pTempPlot); 
		if(bWaterCheck == false) then
			bValid = false;
		else
			local iFallBackScoreTemp = 5;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end

		local bValidAdjacentCheck = self:__GetValidAdjacent(pTempPlot, 0); 
		if(bValidAdjacentCheck == false) then
			bValid = false;
		else
			local iFallBackScoreTemp = 6;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end
		
		-- Checks to see if there are natural wonders in the given distance
		local bNaturalWonderCheck = self:__NaturalWonderBuffer(pTempPlot, false); 
		if(bNaturalWonderCheck == false) then
			bValid = false;
		else
			local iFallBackScoreTemp = 7;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end
		
		-- Checks to see if there are resources
		if(pTempPlot:GetResourceCount() > 0) then
		   local bValidResource = self:__BonusResource(pTempPlot);
		    if(bValidResource == false) then
		       bValid = false;
			end
		else
			local iFallBackScoreTemp = 8;
			if (iFallBackScore < iFallBackScoreTemp and bValid == true) then
				pFallback = pTempPlot;
				iFallBackScore = iFallBackScoreTemp;
			end
		end
				
		-- Checks to see if there is an Oasis
		local featureType = pTempPlot:GetFeatureType();
		if(featureType == g_FEATURE_OASIS) then
			bValid = false;
		end

		-- If the plots passes all the checks then the plot equals the temp plot
		if(bValid == true) then
			self:__TryToRemoveBonusResource(pTempPlot);
			self:__AddBonusFoodProduction(pTempPlot);
			local tX = pTempPlot:GetX()
			local tY = pTempPlot:GetY()
			print(string.format("found ideal start for %d at %d, %d",iMajorIndex,tX, tY))
			return pTempPlot;
		end
	end
 
	local fX = pFallback:GetX()
	local fY = pFallback:GetY()
	print(string.format("fallback at %d, %d start used for civ %d", fX, fY, iMajorIndex))
	return pFallback;
end

 function AddCliffs(plotTypes, terrainTypes)
	local iW, iH = Map.GetGridSize();
	for iX = 0, iW - 1 do
		for iY = 0, iH - 1 do
			local index = (iY * iW) + iX;
			local pPlot = Map.GetPlotByIndex(index);
			if (pPlot:IsHills() and AdjacentToSaltWater(iX, iY) == true and IsAdjacentToIce(iX, iY) ==  false) then
				if(IsAdjacentToRiver(iX, iY) == false) then
					
					local area = pPlot:GetArea();
					local plotCount = area:GetPlotCount()
					--local noFlat = area:HasNoFlatCoast()
					--print("area",plotCount,noFlat)
					if area:GetPlotCount() > 10 then
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
function FeatureGenerator:AddFeaturesFromContinents()

	local aPossibleFissureIndices:table = {};

	-- Oasis are in this loop even though not placed near continent boundaries.  Want in a secondary loop since can't be adjacent to other features
	for y = 0, self.iGridH - 1, 1 do
		for x = 0, self.iGridW - 1, 1 do
			local i = y * self.iGridW + x;
			local plot = Map.GetPlotByIndex(i);
			if(plot ~= nil) then
				local featureType = plot:GetFeatureType();

				if(plot:IsImpassable() or featureType ~= g_FEATURE_NONE) then
					--No Feature
				else
					if (TerrainBuilder.CanHaveFeature(plot, g_FEATURE_GEOTHERMAL_FISSURE) == true) then
						if (Map.FindSecondContinent(plot, 3)) then
							table.insert(aPossibleFissureIndices, i);
						end
					end
				end
			end
		end
	end

	
	-- Place fissures near continent divides
	local iDesiredFissures = self.iNumLandPlots / 200;
	print("iDesiredFissures = ",iDesiredFissures,"aPossibleFissureIndices = ",#aPossibleFissureIndices)
	if (iDesiredFissures > 0 and #aPossibleFissureIndices > 0) then
		aShuffledIndices =  GetShuffledCopyOfTable(aPossibleFissureIndices);
		for i, index in ipairs(aShuffledIndices) do
			local pPlot = Map.GetPlotByIndex(index);
			TerrainBuilder.SetFeatureType(pPlot, g_FEATURE_GEOTHERMAL_FISSURE);
			self.iFissureCount = self.iFissureCount + 1;
			print ("Fissure Placed at (x, y): " .. pPlot:GetX() .. ", " .. pPlot:GetY());
			if (self.iFissureCount >= iDesiredFissures) then
				break
			end
		end
	end

	-- Still have fissures to place?  Add them anywhere
	if (iDesiredFissures > self.iFissureCount) then
		local aFullMapFissureIndices:table = {};
		for y = 0, self.iGridH - 1, 1 do
			for x = 0, self.iGridW - 1, 1 do
				local i = y * self.iGridW + x;
				local plot = Map.GetPlotByIndex(i);
				if(plot ~= nil) then
					local featureType = plot:GetFeatureType();

					if(plot:IsImpassable() or featureType ~= g_FEATURE_NONE) then
						--No Feature
					else
						if (TerrainBuilder.CanHaveFeature(plot, g_FEATURE_GEOTHERMAL_FISSURE) == true) then
							if (not Map.FindSecondContinent(plot, 3)) then
								table.insert(aFullMapFissureIndices, i);
							end
						end
					end
				end
			end
		end
		if (#aFullMapFissureIndices > 0) then
			aShuffledIndices =  GetShuffledCopyOfTable(aFullMapFissureIndices);
			for i, index in ipairs(aShuffledIndices) do
				local pPlot = Map.GetPlotByIndex(index);
				TerrainBuilder.SetFeatureType(pPlot, g_FEATURE_GEOTHERMAL_FISSURE);
				self.iFissureCount = self.iFissureCount + 1;
				print ("Full-Map Fissure Placed at (x, y): " .. pPlot:GetX() .. ", " .. pPlot:GetY());
				if (self.iFissureCount >= iDesiredFissures) then
					break
				end
			end
		end
	end

	print("Number of Fissures: ", self.iFissureCount)
end
--******************************************************************************
--** Natural Wonder Generation
--******************************************************************************
--These are not in MapEnums.lua and I will probably need them

--expac 1
g_FEATURE_DELICATE_ARCH			= GetGameInfoIndex("Features", "FEATURE_DELICATE_ARCH");
g_FEATURE_EYE_OF_THE_SAHARA     = GetGameInfoIndex("Features", "FEATURE_EYE_OF_THE_SAHARA");
g_FEATURE_LAKE_RETBA            = GetGameInfoIndex("Features", "FEATURE_LAKE_RETBA");
g_FEATURE_MATTERHORN            = GetGameInfoIndex("Features", "FEATURE_MATTERHORN");
g_FEATURE_RORAIMA               = GetGameInfoIndex("Features", "FEATURE_RORAIMA");
g_FEATURE_UBSUNUR_HOLLOW        = GetGameInfoIndex("Features", "FEATURE_UBSUNUR_HOLLOW");
g_FEATURE_ZHANGYE_DANXIA        = GetGameInfoIndex("Features", "FEATURE_ZHANGYE_DANXIA");
--expac 2
g_FEATURE_CHOCOLATEHILLS    	= GetGameInfoIndex("Features", "FEATURE_CHOCOLATEHILLS");
g_FEATURE_DEVILSTOWER  			= GetGameInfoIndex("Features", "FEATURE_DEVILSTOWER");
g_FEATURE_GOBUSTAN				= GetGameInfoIndex("Features", "FEATURE_GOBUSTAN");
g_FEATURE_IKKIL					= GetGameInfoIndex("Features", "FEATURE_IKKIL");
g_FEATURE_PAMUKKALE				= GetGameInfoIndex("Features", "FEATURE_PAMUKKALE");
g_FEATURE_VESUVIUS				= GetGameInfoIndex("Features", "FEATURE_VESUVIUS");
g_FEATURE_WHITEDESERT			= GetGameInfoIndex("Features", "FEATURE_WHITEDESERT");
--Vikings DLC
g_FEATURE_EYJAFJALLAJOKULL		= GetGameInfoIndex("Features", "FEATURE_EYJAFJALLAJOKULL");
g_FEATURE_LYSEFJORDEN			= GetGameInfoIndex("Features", "FEATURE_LYSEFJORDEN");
g_FEATURE_GIANTS_CAUSEWAY		= GetGameInfoIndex("Features", "FEATURE_GIANTS_CAUSEWAY");
--Australia DLC
g_FEATURE_ULURU					= GetGameInfoIndex("Features", "FEATURE_ULURU");

g_RESOURCE_DEER 				= GetGameInfoIndex("Resources","RESOURCE_DEER");
g_RESOURCE_DIAMONDS 			= GetGameInfoIndex("Resources","RESOURCE_DIAMONDS");
g_RESOURCE_TURTLES				= GetGameInfoIndex("Resources","RESOURCE_TURTLES");
g_RESOURCE_WHALES				= GetGameInfoIndex("Resources","RESOURCE_WHALES");
g_RESOURCE_CRABS                = GetGameInfoIndex("Resources","RESOURCE_CRABS");
g_RESOURCE_FISH                 = GetGameInfoIndex("Resources","RESOURCE_FISH");


function GetNaturalWonderString(nwIndex)

	if nwIndex == g_FEATURE_BARRIER_REEF then
		return "FEATURE_BARRIER_REEF"
	elseif nwIndex == g_FEATURE_CLIFFS_DOVER then
		return "FEATURE_CLIFFS_DOVER"
	elseif nwIndex == g_FEATURE_CRATER_LAKE	 then
		return "FEATURE_CRATER_LAKE"
	elseif nwIndex == g_FEATURE_DEAD_SEA then
		return "FEATURE_DEAD_SEA"
	elseif nwIndex == g_FEATURE_EVEREST then	
		return "FEATURE_EVEREST"
	elseif nwIndex == g_FEATURE_GALAPAGOS then	
		return "FEATURE_GALAPAGOS"
	elseif nwIndex == g_FEATURE_KILIMANJARO then
		return "FEATURE_KILIMANJARO"
	elseif nwIndex == g_FEATURE_PANTANAL then
		return "FEATURE_PANTANAL"
	elseif nwIndex == g_FEATURE_PIOPIOTAHI then	
		return "FEATURE_PIOPIOTAHI"
	elseif nwIndex == g_FEATURE_TORRES_DEL_PAINE then	
		return "FEATURE_TORRES_DEL_PAINE"
	elseif nwIndex == g_FEATURE_TSINGY then	
		return "FEATURE_TSINGY"
	elseif nwIndex == g_FEATURE_YOSEMITE then
		return "FEATURE_YOSEMITE"
	elseif nwIndex == g_FEATURE_CHOCOLATEHILLS then
		return "FEATURE_CHOCOLATEHILLS"
	elseif nwIndex == g_FEATURE_DEVILSTOWER then  
		return "FEATURE_DEVILSTOWER"
	elseif nwIndex == g_FEATURE_GOBUSTAN then
		return "FEATURE_GOBUSTAN"
	elseif nwIndex == g_FEATURE_IKKIL then	
		return "FEATURE_IKKIL"
	elseif nwIndex == g_FEATURE_PAMUKKALE then	
		return "FEATURE_PAMUKKALE"
	elseif nwIndex == g_FEATURE_VESUVIUS then	
		return "FEATURE_VESUVIUS"
	elseif nwIndex == g_FEATURE_WHITEDESERT then			
		return "FEATURE_WHITEDESERT"
	elseif nwIndex == g_FEATURE_EYJAFJALLAJOKULL then	
		return "FEATURE_EYJAFJALLAJOKULL"
	elseif nwIndex == g_FEATURE_LYSEFJORDEN then	
		return "FEATURE_LYSEFJORDEN"
	elseif nwIndex == g_FEATURE_GIANTS_CAUSEWAY then	
		return "FEATURE_GIANTS_CAUSEWAY"
	elseif nwIndex == g_FEATURE_ULURU then			
		return "FEATURE_ULURU"
	elseif nwIndex == g_FEATURE_DELICATE_ARCH then	
		return "FEATURE_DELICATE_ARCH"
	elseif nwIndex == g_FEATURE_EYE_OF_THE_SAHARA then	
		return "FEATURE_EYE_OF_THE_SAHARA"
	elseif nwIndex == g_FEATURE_LAKE_RETBA then			
		return "FEATURE_LAKE_RETBA"
	elseif nwIndex == g_FEATURE_MATTERHORN then	
		return "FEATURE_MATTERHORN"
	elseif nwIndex == g_FEATURE_RORAIMA then	
		return "FEATURE_RORAIMA"
	elseif nwIndex == g_FEATURE_UBSUNUR_HOLLOW then	
		return "FEATURE_UBSUNUR_HOLLOW"
	elseif nwIndex == g_FEATURE_ZHANGYE_DANXIA then			
		return "FEATURE_ZHANGYE_DANXIA"
	end
	
	return tostring(nwIndex)
end
function NW_IsMountain(x,y)
	local iPlot = elevationMap:GetIndex(x,y)
	local plot = Map.GetPlotByIndex(iPlot)
	if plot:IsMountain() then
		return true
	end
	return false
end
function NW_IsPassableLand(x,y)
	local iPlot = elevationMap:GetIndex(x,y)
	local plot = Map.GetPlotByIndex(iPlot)
	if not plot:IsWater() and not plot:IsImpassable() then
		return true
	end
	return false
end
function NW_IsDesert(x,y)
	local iPlot = elevationMap:GetIndex(x,y)
	local plot = Map.GetPlotByIndex(iPlot)
	local terrainType = plot:GetTerrainType()
	if terrainType == g_TERRAIN_TYPE_DESERT	or terrainType == g_TERRAIN_TYPE_DESERT_HILLS or terrainType == g_TERRAIN_TYPE_DESERT_MOUNTAIN then
		return true
	end
	return false;               		
end

function BBS_NaturalWonderGenerator:__FindValidLocs()

	local iW, iH;
	iW, iH = Map.GetGridSize();

	local iBaseScore = 1;
	
-----Preparing mountain and desert data for PW----------------
	mountainRangeList = {}
	PWMountainAreas = PWAreaMap:New(elevationMap.width,elevationMap.height,mc.wrapX, mc.wrapY)
	PWMountainAreas:DefineAreas(NW_IsMountain,false)
	table.sort(PWMountainAreas.areaList,function (a,b) return a.size > b.size; end)
	
	mountainRangesFound = 0
	for n=1,#PWMountainAreas.areaList do
		local area = PWMountainAreas.areaList[n]
		if area.trueMatch then
			local mRange = TerrainArea:New(area.id)
			table.insert(mountainRangeList,mRange)
			mountainRangesFound = mountainRangesFound + 1
			print("mountain range size = " .. area.size)
		end
		if area.size < 5 then
			break
		end
	end
	for n=1,#mountainRangeList do
		local mRange = mountainRangeList[n]
		local iPlotCount = Map.GetPlotCount();
		for i = 0, iPlotCount - 1 do
			if PWMountainAreas.data[i] == mRange.areaID then
				table.insert(mRange.plotIndexList,i)
			end
		end
		mRange:CalculateCenter()
	end
	PWLandAreas = PWAreaMap:New(elevationMap.width,elevationMap.height,mc.wrapX,mc.wrapY)
	PWLandAreas:DefineAreas(NW_IsPassableLand,false)
	--smallest landmass first! different than mountain ranges above
	table.sort(PWLandAreas.areaList,function (a,b) return a.size < b.size; end)


--------------------------------------------------------------
	local iPlotCount = Map.GetPlotCount();
	for i = 0, iPlotCount - 1 do
		local pPlot = Map.GetPlotByIndex(i);

		-- See which NW can appear here
		for iI = 0, self.iNumWondersInDB - 1 do
			--see if PerfectWorld wants to handle this one. However, invalids passed into the NW generator will be
			--skipped. Looks like if invalid == true, then it's actually valid :/
			if HijackedByPW(self.eFeatureType[iI]) then 
				if (PWCanHaveFeature(pPlot, self.eFeatureType[iI]) and self.aInvalidNaturalWonders[iI] == true) then
					row = {};
					row.MapIndex = i;
					row.Score = iBaseScore;
					table.insert (self.aaPossibleLocs[iI], row);
				end			
			else
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
	end

	for iI = 0, self.iNumWondersInDB - 1 do
		local iNumEntries = #self.aaPossibleLocs[iI];
		print ("Feature Type: " .. GetNaturalWonderString(self.eFeatureType[iI]) .. ", Valid Hexes: " .. tostring(iNumEntries));
		if (iNumEntries > 0) then
			selectionRow = {}
			selectionRow.NWIndex = iI;
			selectionRow.RandomScore = TerrainBuilder.GetRandomNumber (100, "Natural Wonder Selection Roll");
			
			--for testing only! comment out before publish
			if PWDebugCheat(self.eFeatureType[iI]) then
				selectionRow.RandomScore = selectionRow.RandomScore + 100
			end
			
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
		if #self.aaPossibleLocs[selectionRow.NWIndex] > 0 then
			if (j <= self.iNumWondersToPlace) then
				print (" Selected Wonder = " .. GetNaturalWonderString(self.eFeatureType[selectionRow.NWIndex]) .. ", Random Score = ", tostring(selectionRow.RandomScore))
				print("number of locations = " .. #self.aaPossibleLocs[selectionRow.NWIndex])

				-- Score possible locations
				self:__ScorePlots(selectionRow.NWIndex);

				-- Sort and take best score
				table.sort (self.aaPossibleLocs[selectionRow.NWIndex], function(a, b) return a.Score > b.Score; end);
				local iMapIndex = self.aaPossibleLocs[selectionRow.NWIndex][1].MapIndex;

				-- Place at this location
				local pPlot = Map.GetPlotByIndex(iMapIndex);
				local eFeatureType = self.eFeatureType[selectionRow.NWIndex]
				if HijackedByPW(eFeatureType) then
					PWSetFeatureType(pPlot, eFeatureType,self.aPlacedWonders)
				else
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
					end
				end
				print (" Set Wonder with Feature ID of " .. GetNaturalWonderString(eFeatureType) .. " at location (" .. tostring(pPlot:GetX()) .. ", " .. tostring(pPlot:GetY()) .. ")");
				table.insert (self.aPlacedWonders, iMapIndex);
				j = j+ 1;

			end
		end
	end
end
function PWCanHaveFeature(pPlot, eFeatureType)
	if eFeatureType == g_FEATURE_TORRES_DEL_PAINE or eFeatureType == g_FEATURE_YOSEMITE then
		return PWCanHaveYosemiteOrTDP(pPlot)
	elseif eFeatureType == g_FEATURE_RORAIMA then
		return PWCanHaveRoraima(pPlot) 
	elseif eFeatureType == g_FEATURE_EVEREST then
		return PWCanHaveEverest(pPlot) 
	elseif eFeatureType == g_FEATURE_PANTANAL then
		return PWCanHavePanatal(pPlot) 
	elseif eFeatureType == g_FEATURE_IKKIL then
		return PWCanHaveIkkil(pPlot) 
	elseif eFeatureType == g_FEATURE_MATTERHORN then
		return PWCanHaveMatterhorn(pPlot) 
	elseif eFeatureType == g_FEATURE_UBSUNUR_HOLLOW then
		return PWCanHaveUbsunurHollow(pPlot) 
	elseif eFeatureType == g_FEATURE_GALAPAGOS then
		return PWCanHaveGalapagos(pPlot) 
	elseif eFeatureType == g_FEATURE_BARRIER_REEF then
		return PWCanHaveBarrierReef(pPlot) 
	elseif eFeatureType == g_FEATURE_ZHANGYE_DANXIA then
		return PWCanHaveDanxia(pPlot) 
	elseif eFeatureType == g_FEATURE_CHOCOLATEHILLS then
		return PWCanHaveChocoHills(pPlot) 
	elseif eFeatureType == g_FEATURE_CRATER_LAKE then
		return PWCanHaveCraterLake(pPlot) 
	end
end
function PWSetFeatureType(pPlot, eFeatureType, placed)
	--do not place closer than 5 to another NW
	local iPlot = pPlot:GetIndex()
	for p=1,#placed do
		if iPlot ==  placed[p] or Map.GetPlotDistance(iPlot,placed[p]) < 5 then
			print("skipping " .. GetNaturalWonderString(eFeatureType) .. " for being too close to another NW")
			return
		end
	end
	if eFeatureType == g_FEATURE_TORRES_DEL_PAINE or eFeatureType == g_FEATURE_YOSEMITE then
		PWSetYosemiteOrTDP(pPlot, eFeatureType)
	elseif eFeatureType == g_FEATURE_RORAIMA then
		PWSetRoraima(pPlot)
	elseif eFeatureType == g_FEATURE_EVEREST then
		PWSetEverest(pPlot)
	elseif eFeatureType == g_FEATURE_PANTANAL then
		PWSetPantanal(pPlot)
	elseif eFeatureType == g_FEATURE_IKKIL then
		PWSetIkkil(pPlot)
	elseif eFeatureType == g_FEATURE_MATTERHORN then
		PWSetMatterhorn(pPlot)
	elseif eFeatureType == g_FEATURE_UBSUNUR_HOLLOW then
		PWSetUbsunurHollow(pPlot)
	elseif eFeatureType == g_FEATURE_GALAPAGOS then
		PWSetGalapagos(pPlot)
	elseif eFeatureType == g_FEATURE_BARRIER_REEF then
		PWSetBarrierReef(pPlot)
	elseif eFeatureType == g_FEATURE_ZHANGYE_DANXIA then
		PWSetDanxia(pPlot)
	elseif eFeatureType == g_FEATURE_CHOCOLATEHILLS then
		PWSetChocoHills(pPlot)
	elseif eFeatureType == g_FEATURE_CRATER_LAKE then
		PWSetCraterLake(pPlot)
	end
end
function HijackedByPW(featureType)
	if featureType == g_FEATURE_YOSEMITE then
		return true
	elseif featureType == g_FEATURE_TORRES_DEL_PAINE then
		return true
	elseif featureType == g_FEATURE_RORAIMA then
		return true
	elseif featureType == g_FEATURE_EVEREST then
		return true
	elseif featureType == g_FEATURE_PANTANAL then
		return true
	elseif featureType == g_FEATURE_IKKIL then
		return true
	elseif featureType == g_FEATURE_MATTERHORN then
		return true
	elseif featureType == g_FEATURE_UBSUNUR_HOLLOW then
		return true
	elseif featureType == g_FEATURE_GALAPAGOS then
		return true
	elseif featureType == g_FEATURE_BARRIER_REEF then
		return true
	elseif featureType == g_FEATURE_ZHANGYE_DANXIA then
		return true
	elseif featureType == g_FEATURE_CHOCOLATEHILLS then
		return true
	elseif featureType == g_FEATURE_CRATER_LAKE then
		return true
	end
	return false
end
function PWDebugCheat(eFeatureType)
	-- if eFeatureType == g_FEATURE_GALAPAGOS then
		-- return true
	-- elseif eFeatureType == g_FEATURE_CRATER_LAKE then
		-- return true
	-- elseif eFeatureType == g_FEATURE_RORAIMA then
		-- return true
	-- elseif eFeatureType == g_FEATURE_ZHANGYE_DANXIA then
		-- return true
	-- elseif eFeatureType == g_FEATURE_CHOCOLATEHILLS then
		-- return true
	-- end
	return false
end

--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
--&& Set Individual Wonders
--&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
function PWSetCraterLake(pPlot)
	TerrainBuilder.SetFeatureType(pPlot,g_FEATURE_CRATER_LAKE)
	TerrainBuilder.SetTerrainType(pPlot,g_TERRAIN_TYPE_PLAINS)
	for dir = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local nPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir)
		if nPlot:IsMountain() then
			TerrainBuilder.SetTerrainType(nPlot,g_TERRAIN_TYPE_TUNDRA_MOUNTAIN)
		else
			TerrainBuilder.SetTerrainType(nPlot,g_TERRAIN_TYPE_PLAINS_HILLS)
			TerrainBuilder.SetFeatureType(nPlot,g_FEATURE_FOREST)
		end
	end
end
function PWSetChocoHills(pPlot)
	for dir = 0, 2, 1 do
		local aPlots = {}
		table.insert(aPlots,pPlot:GetIndex())
		local secondPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir)
		if secondPlot ~= nil then
			table.insert(aPlots,secondPlot:GetIndex())
			local thirdPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir + 1)
			if thirdPlot ~= nil then
				table.insert(aPlots,thirdPlot:GetIndex())
				local fourthPlot = Map.GetAdjacentPlot(secondPlot:GetX(),secondPlot:GetY(),dir + 1)
				if fourthPlot ~= nil then
					table.insert(aPlots,fourthPlot:GetIndex())
					if HasOnlyPassableLand(aPlots) and not HasInternalRivers(aPlots) then
						local adj = GetAdjacentPlots(aPlots)
						--print("adj length = " .. #adj)
						local landCount = 0 --Pantanal should be next to some mountains
						for i=1,#adj do
							adjPlot = Map.GetPlotByIndex(adj[i])
							if not adjPlot:IsWater() and not adjPlot:IsMountain() then
								landCount = landCount + 1
							end
						end
						if landCount >=4 then
							TerrainBuilder.SetMultiPlotFeatureType(aPlots,g_FEATURE_CHOCOLATEHILLS)
							for n=1,#aPlots do
								local curPlot = Map.GetPlotByIndex(aPlots[n])
								TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_GRASS)
							end
							for n=1,#adj do --dress up surrounding area
								local curPlot = Map.GetPlotByIndex(adj[n])
								if curPlot:IsMountain() then
									TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_GRASS_MOUNTAIN)
								elseif curPlot:IsHills() then
									TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_PLAINS_HILLS)
									TerrainBuilder.SetFeatureType(curPlot,g_FEATURE_JUNGLE)
								else
									TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_PLAINS)
									TerrainBuilder.SetFeatureType(curPlot,g_FEATURE_JUNGLE)
								end
							end
							
						end
					end
				end
			end
		end
	end

end
function PWSetDanxia(pPlot)
	for i = 0, 2, 1 do
		local aPlots = {}
		table.insert(aPlots,pPlot:GetIndex())
		local pFirstPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), i);
		if pFirstPlot ~= nil then
			local pSecondPlot = Map.GetAdjacentPlot(pFirstPlot:GetX(), pFirstPlot:GetY(), i);
			if pSecondPlot ~= nil and pSecondPlot:IsMountain() then
				table.insert(aPlots, pFirstPlot:GetIndex());
				table.insert(aPlots, pSecondPlot:GetIndex());
				if not HasInternalRivers(aPlots) then
					local adj = GetAdjacentPlots(aPlots)
					landCount = 0
					for n=1,#adj do
						local nPlot = Map.GetPlotByIndex(adj[n])
						if not nPlot:IsWater() and not nPlot:IsMountain() then
							landCount = landCount + 1
						end
					end
					if landCount >= 3 then
						TerrainBuilder.SetMultiPlotFeatureType(aPlots,g_FEATURE_ZHANGYE_DANXIA)
						for j=1,#aPlots do
							local mainPlot = Map.GetPlotByIndex(aPlots[j])
							TerrainBuilder.SetTerrainType(mainPlot,g_TERRAIN_TYPE_DESERT_MOUNTAIN)
						end
						return
					end
				end
			end
		end
	end
end
function PWSetBarrierReef(pPlot)
	for dir=0,2, 1 do
		local aPlots = {}
		table.insert(aPlots,pPlot:GetIndex())
		local nPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(),dir)
		if nPlot:GetTerrainType() == g_TERRAIN_TYPE_COAST and not nPlot:IsLake() then
			table.insert(aPlots,nPlot:GetIndex())
			TerrainBuilder.SetMultiPlotFeatureType(aPlots,g_FEATURE_BARRIER_REEF)
			for i=1,#aPlots do
				local mainPlot = Map.GetPlotByIndex(aPlots[i])
				TerrainBuilder.SetTerrainType(mainPlot,g_TERRAIN_TYPE_COAST)
				return --cant' just keep going!
			end
		end
	end
end
function PWSetGalapagos(pPlot)
	for dir=0,2, 1 do
		local aPlots = {}
		table.insert(aPlots,pPlot:GetIndex())
		local nPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(),dir)
		local waterSurround = true
		for subdir=0,DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local nnPlot = Map.GetAdjacentPlot(nPlot:GetX(), nPlot:GetY(),subdir)
			if not nnPlot:IsWater() or nnPlot:IsLake() then
				waterSurround = false
			end
		end
		if waterSurround then
			table.insert(aPlots,nPlot:GetIndex())
			TerrainBuilder.SetMultiPlotFeatureType(aPlots,g_FEATURE_GALAPAGOS)
			for i=1,#aPlots do
				local mainPlot = Map.GetPlotByIndex(aPlots[i])
				TerrainBuilder.SetTerrainType(mainPlot,g_TERRAIN_TYPE_COAST)
			end
			--now lets create a surrounding abundance
			local backDir = dir - 1
			if backDir == -1 then
				backDir = 5
			end
			local forDir = dir + 1
			
			local t1Plot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(),backDir)
			TerrainBuilder.SetTerrainType(t1Plot,g_TERRAIN_TYPE_COAST)
			TerrainBuilder.SetFeatureType(t1Plot,g_FEATURE_REEF)
			ResourceBuilder.SetResourceType(t1Plot,g_RESOURCE_TURTLES,1)
			local t2Plot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(),forDir)
			TerrainBuilder.SetTerrainType(t2Plot,g_TERRAIN_TYPE_COAST)
			TerrainBuilder.SetFeatureType(t2Plot,g_FEATURE_REEF)
			ResourceBuilder.SetResourceType(t2Plot,g_RESOURCE_TURTLES,1)
			
			local w1Plot = Map.GetAdjacentPlot(nPlot:GetX(),nPlot:GetY(),backDir)
			TerrainBuilder.SetTerrainType(w1Plot,g_TERRAIN_TYPE_COAST)
			ResourceBuilder.SetResourceType(w1Plot,g_RESOURCE_WHALES,1)
			local oppDir = GetOppositeDirection(backDir)
			local w2Plot = Map.GetAdjacentPlot(pPlot:GetX(),pPlot:GetY(),oppDir)
			TerrainBuilder.SetTerrainType(w2Plot,g_TERRAIN_TYPE_COAST)
			ResourceBuilder.SetResourceType(w2Plot,g_RESOURCE_WHALES,1)
			
			local f1Plot = Map.GetAdjacentPlot(nPlot:GetX(),nPlot:GetY(),dir)
			TerrainBuilder.SetTerrainType(f1Plot,g_TERRAIN_TYPE_COAST)
			TerrainBuilder.SetFeatureType(f1Plot,g_FEATURE_REEF)
			ResourceBuilder.SetResourceType(f1Plot,g_RESOURCE_FISH,1)
			oppDir = GetOppositeDirection(dir)
			local f2Plot = Map.GetAdjacentPlot(pPlot:GetX(),pPlot:GetY(),oppDir)
			TerrainBuilder.SetTerrainType(f2Plot,g_TERRAIN_TYPE_COAST)
			TerrainBuilder.SetFeatureType(f2Plot,g_FEATURE_REEF)
			ResourceBuilder.SetResourceType(f2Plot,g_RESOURCE_FISH,1)

			local c1Plot = Map.GetAdjacentPlot(nPlot:GetX(),nPlot:GetY(),forDir)
			TerrainBuilder.SetTerrainType(c1Plot,g_TERRAIN_TYPE_COAST)
			--TerrainBuilder.SetFeatureType(c1Plot,g_FEATURE_REEF)
			ResourceBuilder.SetResourceType(c1Plot,g_RESOURCE_CRABS,1)
			oppDir = GetOppositeDirection(forDir)
			local c2Plot = Map.GetAdjacentPlot(pPlot:GetX(),pPlot:GetY(),oppDir)
			TerrainBuilder.SetTerrainType(c2Plot,g_TERRAIN_TYPE_COAST)
			--TerrainBuilder.SetFeatureType(c2Plot,g_FEATURE_REEF)
			ResourceBuilder.SetResourceType(c2Plot,g_RESOURCE_CRABS,1)
			
			return
		end	
	end
end
function PWSetMatterhorn(pPlot)
	TerrainBuilder.SetFeatureType(pPlot,g_FEATURE_MATTERHORN)
	TerrainBuilder.SetTerrainType(pPlot,g_TERRAIN_TYPE_TUNDRA_MOUNTAIN)
end
function PWSetIkkil(pPlot)
	TerrainBuilder.SetTerrainType(pPlot,g_TERRAIN_TYPE_GRASS) --erase any hill to prevent this from floating
	TerrainBuilder.SetFeatureType(pPlot,g_FEATURE_IKKIL)
	TerrainBuilder.SetTerrainType(pPlot,g_TERRAIN_TYPE_GRASS)
end
function PWSetUbsunurHollow(pPlot)
	--these rotatable wonders are a PITA, anyway due to symmetry we only need three directions
	for dir = 0, 2, 1 do
		local aPlots = {}
		table.insert(aPlots,pPlot:GetIndex())
		local secondPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir)
		if secondPlot ~= nil then
			table.insert(aPlots,secondPlot:GetIndex())
			local thirdPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir + 1)
			if thirdPlot ~= nil then
				table.insert(aPlots,thirdPlot:GetIndex())
				local fourthPlot = Map.GetAdjacentPlot(secondPlot:GetX(),secondPlot:GetY(),dir + 1)
				if fourthPlot ~= nil then
					table.insert(aPlots,fourthPlot:GetIndex())
					if HasOnlyPassableLand(aPlots) then
						local adj = GetAdjacentPlots(aPlots)
						local mountainCount = 0 --UH should be next to some mountains
						local waterFound = false
						for i=1,#adj do
							adjPlot = Map.GetPlotByIndex(adj[i])
							if adjPlot:IsWater() then
								waterFound = true
								break
							end
							if adjPlot:IsMountain() then
								mountainCount = mountainCount + 1
							end
						end
						if not waterFound and mountainCount >=2 then
							TerrainBuilder.SetMultiPlotFeatureType(aPlots,g_FEATURE_UBSUNUR_HOLLOW)
							for n=1,#aPlots do
								local curPlot = Map.GetPlotByIndex(aPlots[n])
								TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_TUNDRA)
							end
							for n=1,#adj do --dress up surrounding area
								local curPlot = Map.GetPlotByIndex(adj[n])
								if curPlot:IsMountain() then
									TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_TUNDRA_MOUNTAIN)
								elseif curPlot:IsHills() then
									TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_TUNDRA_HILLS)
									TerrainBuilder.SetFeatureType(curPlot,g_FEATURE_FOREST)
								else
									TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_TUNDRA)
									TerrainBuilder.SetFeatureType(curPlot,g_FEATURE_FOREST)
								end
							end
							--Add three deer if you can
							ShuffleList(adj)
							for n=1,#adj do
								local curPlot = Map.GetPlotByIndex(adj[n])
								if curPlot:GetTerrainType() == g_TERRAIN_TYPE_TUNDRA or curPlot:GetTerrainType() == g_TERRAIN_TYPE_TUNDRA_HILLS then
									--if too many deer are added, they should be removed automatically 
									--in resource placement. fill er up.
									ResourceBuilder.SetResourceType(curPlot, g_RESOURCE_DEER, 1);
								end
							end
						end
					end
				end
			end
		end
	end
end
function PWSetPantanal(pPlot)
	--these rotatable wonders are a PITA, anyway due to symmetry we only need three directions
	for dir = 0, 2, 1 do
		local aPlots = {}
		table.insert(aPlots,pPlot:GetIndex())
		local secondPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir)
		if secondPlot ~= nil then
			table.insert(aPlots,secondPlot:GetIndex())
			local thirdPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir + 1)
			if thirdPlot ~= nil then
				table.insert(aPlots,thirdPlot:GetIndex())
				local fourthPlot = Map.GetAdjacentPlot(secondPlot:GetX(),secondPlot:GetY(),dir + 1)
				if fourthPlot ~= nil then
					table.insert(aPlots,fourthPlot:GetIndex())
					if HasOnlyPassableLand(aPlots) then
						local adj = GetAdjacentPlots(aPlots)
						local mountainCount = 0 --Pantanal should be next to some mountains
						local waterFound = false
						for i=1,#adj do
							adjPlot = Map.GetPlotByIndex(adj[i])
							if adjPlot:IsWater() then
								waterFound = true
								break
							end
							if adjPlot:IsMountain() then
								mountainCount = mountainCount + 1
							end
						end
						if not waterFound and mountainCount >=2 then
							TerrainBuilder.SetMultiPlotFeatureType(aPlots,g_FEATURE_PANTANAL)
							for n=1,#aPlots do
								local curPlot = Map.GetPlotByIndex(aPlots[n])
								TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_GRASS)
							end
							for n=1,#adj do --dress up surrounding area
								local curPlot = Map.GetPlotByIndex(adj[n])
								if curPlot:IsMountain() then
									TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_GRASS_MOUNTAIN)
								elseif curPlot:IsHills() then
									TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_PLAINS_HILLS)
									TerrainBuilder.SetFeatureType(curPlot,g_FEATURE_JUNGLE)
								else
									TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_GRASS)
									TerrainBuilder.SetFeatureType(curPlot,g_FEATURE_MARSH)
								end
							end
							ShuffleList(adj)
							for n=1,#adj do
								local curPlot = Map.GetPlotByIndex(adj[n])
								if curPlot:GetTerrainType() == g_TERRAIN_TYPE_PLAINS_HILLS then
									--if too many deer are added, they should be removed automatically 
									--in resource placement. fill er up.
									ResourceBuilder.SetResourceType(curPlot, g_RESOURCE_DIAMONDS, 1);
									break
								end
								if n == adj then
									TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_PLAINS_HILLS)
									TerrainBuilder.SetFeatureType(curPlot,g_FEATURE_JUNGLE)
									ResourceBuilder.SetResourceType(curPlot, g_RESOURCE_DIAMONDS, 1);
								end
							end
						end
					end
				end
			end
		end
	end
end
function PWSetEverest(pPlot)
	aPlots = {}
	table.insert(aPlots,pPlot:GetIndex())
	local pWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST)
	table.insert(aPlots,pWPlot:GetIndex())
	local pEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST)
	table.insert(aPlots,pEPlot:GetIndex())
	TerrainBuilder.SetMultiPlotFeatureType(aPlots,g_FEATURE_EVEREST)
	for i=1,#aPlots do
		curPlot = Map.GetPlotByIndex(aPlots[i])
		TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_TUNDRA_MOUNTAIN)
	end
end

function PWSetRoraima(pPlot)
	-- This one does require three in a row, so let's find that first
	for i = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local aPlots = {}
		table.insert(aPlots,pPlot:GetIndex())
		local pFirstPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), i);
		if pFirstPlot ~= nil then
			local pSecondPlot = Map.GetAdjacentPlot(pFirstPlot:GetX(), pFirstPlot:GetY(), i);
			if pSecondPlot ~= nil then
				local iNewDir = i - 1;
				if iNewDir == -1 then
					iNewDir = 5;
				end
				--check climate at nook
				pNookPlot = Map.GetAdjacentPlot(pFirstPlot:GetX(), pFirstPlot:GetY(), iNewDir)
				iNook = pNookPlot:GetIndex()
				if temperatureMap.data[iNook] >= mc.jungleMinTemperature then
					--print("inside of temperature range")				
					if rainfallMap.data[iNook] >= jungleThreshold then
						--print("plenty of rain")					
						local pThirdPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), iNewDir);
						if pThirdPlot ~= nil then
							table.insert(aPlots, pFirstPlot:GetIndex());
							table.insert(aPlots, pSecondPlot:GetIndex());
							table.insert(aPlots, pThirdPlot:GetIndex());
							
							if (not HasInternalRivers(aPlots)) and (not HasVolcanoesOrWater(aPlots)) then
								--now we know what to place
								TerrainBuilder.SetMultiPlotFeatureType(aPlots,g_FEATURE_RORAIMA)
								for n=1,#aPlots do
									curPlot = Map.GetPlotByIndex(aPlots[n])
									TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_GRASS_MOUNTAIN)
								end
							end
						end
					end
				end
			end
		end
	end
end

function PWSetYosemiteOrTDP(pPlot, eFeatureType)
	local ppPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_EAST)
	local aPlots = {}
	table.insert(aPlots,pPlot:GetIndex())
	table.insert(aPlots,ppPlot:GetIndex())
	TerrainBuilder.SetTerrainType(pPlot,g_TERRAIN_TYPE_PLAINS_MOUNTAIN)
	TerrainBuilder.SetTerrainType(ppPlot,g_TERRAIN_TYPE_PLAINS_MOUNTAIN)
	TerrainBuilder.SetMultiPlotFeatureType(aPlots, eFeatureType)
	print("setting " .. GetNaturalWonderString(eFeatureType) .. " at " .. pPlot:GetX() .. ", " .. pPlot:GetY())
	
	local westAnchorPlots = {} --these are the three plots bracketing the west tile of NW
	local NWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST)
	table.insert(westAnchorPlots,NWPlot)
	local WPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_WEST)
	table.insert(westAnchorPlots,WPlot)
	local SWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST)
	table.insert(westAnchorPlots,SWPlot)
	
	local mountainAnchor = false
	for i=1,#westAnchorPlots do
		curPlot = westAnchorPlots[i]
		if curPlot:IsMountain() then
			mountainAnchor = true
		end
	end
	if not mountainAnchor then
		for i=1,#westAnchorPlots do
			curPlot = westAnchorPlots[i]
			if not curPlot:IsWater() then
				TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_PLAINS_MOUNTAIN)
				break
			end
		end
	end
	
	local eastAnchorPlots = {} --these are the three plots bracketing the east tile of NW
	local NEPlot = Map.GetAdjacentPlot(ppPlot:GetX(), ppPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST)
	table.insert(eastAnchorPlots,NEPlot)
	local EPlot = Map.GetAdjacentPlot(ppPlot:GetX(), ppPlot:GetY(), DirectionTypes.DIRECTION_EAST)
	table.insert(eastAnchorPlots,EPlot)
	local SEPlot = Map.GetAdjacentPlot(ppPlot:GetX(), ppPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST)
	table.insert(eastAnchorPlots,SEPlot)
	
	mountainAnchor = false
	for i=1,#eastAnchorPlots do
		curPlot = eastAnchorPlots[i]
		if curPlot:IsMountain() then
			mountainAnchor = true
		end
	end
	if not mountainAnchor then
		for i=1,#eastAnchorPlots do
			curPlot = eastAnchorPlots[i]
			if not curPlot:IsWater() then
				TerrainBuilder.SetTerrainType(curPlot,g_TERRAIN_TYPE_PLAINS_MOUNTAIN)
				break
			end
		end
	end

	--set surrounding open tiles to forest
	local nPlots = {}
	table.insert(nPlots,Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST))
	table.insert(nPlots,Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST))
	table.insert(nPlots,Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_WEST))
	table.insert(nPlots,Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST))
	table.insert(nPlots,Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST))
	
	table.insert(nPlots,Map.GetAdjacentPlot(ppPlot:GetX(), ppPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST))
	table.insert(nPlots,Map.GetAdjacentPlot(ppPlot:GetX(), ppPlot:GetY(), DirectionTypes.DIRECTION_EAST))
	table.insert(nPlots,Map.GetAdjacentPlot(ppPlot:GetX(), ppPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST))
	for i=1,#nPlots do
		curPlot = nPlots[i]
		if TerrainBuilder.CanHaveFeature(curPlot,g_FEATURE_FOREST) then
			TerrainBuilder.SetFeatureType(curPlot,g_FEATURE_FOREST)
		end
	end
end
--************************************************************************************************************
--** Can Haves
--************************************************************************************************************
function PWCanHaveCraterLake(pPlot)
	local windZone = elevationMap:GetZone(pPlot:GetY()) 
	if windZone == mc.NEQUATOR or windZone == mc.SEQUATOR then
		return false
	end
	--check approaches
	local approachCount = 0
	mountainCount = 0
	for leftDir = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local rightDir = leftDir + 1
		if rightDir == 6 then
			rightDir = 0
		end
		local approach = {}
		local pPointPlot = Map.GetAdjacentPlot(pPlot:GetX(),pPlot:GetY(),leftDir)
		if pPointPlot ~= nil then
			if pPointPlot:IsMountain() then
				mountainCount = mountainCount + 1
			end
			if pPointPlot:IsWater() then
				return false
			end		
			table.insert(approach,pPointPlot:GetIndex())
			local pLeftPlot = Map.GetAdjacentPlot(pPointPlot:GetX(),pPointPlot:GetY(),leftDir)
			if pLeftPlot ~= nil then
				table.insert(approach,pLeftPlot:GetIndex())
				local pRightPlot = Map.GetAdjacentPlot(pPointPlot:GetX(),pPointPlot:GetY(),rightDir)
				if pRightPlot ~= nil then
					table.insert(approach,pRightPlot:GetIndex())
					if HasOnlyPassableLand(approach) then
						approachCount = approachCount + 1
					end
				end
			end
		end
	end
	--I'd like to see this nestled in the mountains, but not inaccesible
	if approachCount < 1 or approachCount > 2 then
		return false
	end
	if mountainCount < 4 then
		return false
	end
	return true
end
function PWCanHaveChocoHills(pPlot)
	--check climate on first plot
	iPlot = pPlot:GetIndex()
	if temperatureMap.data[iPlot] < mc.jungleMinTemperature or rainfallMap.data[iPlot] < jungleThreshold then
		return false
	end	

	--these rotatable wonders are a PITA, anyway due to symmetry we only need three directions
	for dir = 0, 2, 1 do
		local aPlots = {}
		table.insert(aPlots,pPlot:GetIndex())
		local secondPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir)
		if secondPlot ~= nil then
			table.insert(aPlots,secondPlot:GetIndex())
			local thirdPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir + 1)
			if thirdPlot ~= nil then
				table.insert(aPlots,thirdPlot:GetIndex())
				local fourthPlot = Map.GetAdjacentPlot(secondPlot:GetX(),secondPlot:GetY(),dir + 1)
				if fourthPlot ~= nil then
					table.insert(aPlots,fourthPlot:GetIndex())
					if HasOnlyPassableLand(aPlots) and not HasInternalRivers(aPlots) then
						local adj = GetAdjacentPlots(aPlots)
						--print("adj length = " .. #adj)
						local landCount = 0 --Pantanal should be next to some mountains
						for i=1,#adj do
							adjPlot = Map.GetPlotByIndex(adj[i])
							if not adjPlot:IsWater() and not adjPlot:IsMountain() then
								landCount = landCount + 1
							end
						end
						if landCount >=4 then
							return true
						end
					end
				end
			end
		end
	end
	return false
end
function PWCanHaveDanxia(pPlot)
	--climate check first
	local iPlot = pPlot:GetIndex()
	if rainfallMap.data[iPlot] > desertThreshold and temperatureMap.data[iPlot] < mc.tundraTemperature then
		return false
	end
	if not pPlot:IsMountain() then
		return false
	end
	
	for i = 0, 2, 1 do
		local aPlots = {}
		table.insert(aPlots,pPlot:GetIndex())
		local pFirstPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), i);
		if pFirstPlot ~= nil then
			local pSecondPlot = Map.GetAdjacentPlot(pFirstPlot:GetX(), pFirstPlot:GetY(), i);
			if pSecondPlot ~= nil and pSecondPlot:IsMountain() then
				table.insert(aPlots, pFirstPlot:GetIndex());
				table.insert(aPlots, pSecondPlot:GetIndex());
				if not HasInternalRivers(aPlots) and not HasVolcanoesOrWater(aPlots) then
					local adj = GetAdjacentPlots(aPlots)
					landCount = 0
					for n=1,#adj do
						local nPlot = Map.GetPlotByIndex(adj[n])
						if not nPlot:IsWater() and not nPlot:IsMountain() then
							landCount = landCount + 1
						end
					end
					if landCount > 2 then
						return true
					end
				end
			end
		end
	end
	return false
end
function PWCanHaveBarrierReef(pPlot)
	if pPlot:GetTerrainType() ~= g_TERRAIN_TYPE_COAST and not pPlot:IsLake() then
		return false
	end
	--all float maps can tell you the wind zone
	--we want the tropics
	local windZone = elevationMap:GetZone(pPlot:GetY()) 
	if windZone ~= mc.NEQUATOR and windZone ~= mc.SEQUATOR then
		return false
	end
	--now check for nearby land. The rule is to find the first landmass of size 40 or greater for 
	--a neighbor
	local validAreaIDs = {}
	local areasFound = 0
	for i=1,#PWLandAreas.areaList do
		if areasFound < 5 then
			local area = PWLandAreas.areaList[i]
			if area.trueMatch and area.size >= 40 then
				table.insert(validAreaIDs,area.id)
				areasFound = areasFound + 1
			end
		else
			break
		end
	end
	--now lets get nearby outer ring to see if it's acceptable land
	local radiusList = GetRadiusAroundCell(pPlot:GetX(),pPlot:GetY(),1) --these are indices, not plot objects!
	local validFound = false
	for i=1,#radiusList do
		local iPlot = radiusList[i]
		for n=1,#validAreaIDs do
			local vid = validAreaIDs[n]
			if PWLandAreas.data[iPlot] == vid then
				validFound = true
				break
			end
		end
	end
	if not validFound then
		return false
	end

	for dir=0,2, 1 do
		local nPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(),dir)
		if nPlot:GetTerrainType() == g_TERRAIN_TYPE_COAST and not nPlot:IsLake() then
			return true
		end
	end
	return false
end
function PWCanHaveGalapagos(pPlot)
	if pPlot:GetTerrainType() ~= g_TERRAIN_TYPE_COAST and not pPlot:IsLake() then
		return false
	end
	--all float maps can tell you the wind zone
	--we want the tropics
	local windZone = elevationMap:GetZone(pPlot:GetY()) 
	if windZone ~= mc.NEQUATOR and windZone ~= mc.SEQUATOR then
		return false
	end
	--immediate neighbors must be water, not necessarily coast
	for dir=0,DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local nPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(),dir)
		if nPlot == nil or not nPlot:IsWater() then
			return false
		end
	end
	--now check for nearby land. The rule is to find the first landmass of size 10 and then
	--check the 5 continents that are larger than that. This should give us plenty of choices
	local validAreaIDs = {} --this might end up less than 5 if main continents are included, that's ok.
	local areasFound = 0
	for i=1,#PWLandAreas.areaList do
		if areasFound < 5 then
			local area = PWLandAreas.areaList[i]
			if area.trueMatch and area.size >= 10 then
				table.insert(validAreaIDs,area.id)
				areasFound = areasFound + 1
			end
		else
			break
		end
	end
	--now lets get nearby outer ring to see if it's acceptable land
	local ringList = GetRingAroundCell(pPlot:GetX(),pPlot:GetY(),2) --these are indices, not plot objects!
	local validFound = false
	for i=1,#ringList do
		local iPlot = ringList[i]
		for n=1,#validAreaIDs do
			local vid = validAreaIDs[n]
			if PWLandAreas.data[iPlot] == vid then
				validFound = true
				break
			end
		end
	end
	if not validFound then
		return false
	end
	--the rest should be easy, just rotate to the first acceptable spot just checking three directions
	for dir=0,2, 1 do
		local nPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(),dir)
		local waterSurround = true
		for subdir=0,DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local nnPlot = Map.GetAdjacentPlot(nPlot:GetX(), nPlot:GetY(),subdir)
			if not nnPlot:IsWater() then
				waterSurround = false
			end
		end
		if waterSurround then
			return true --this is an acceptable plot for galapagos
		end	
	end
	return false --couldn't find a second plot surrounded by water
end

function PWCanHaveMatterhorn(pPlot)
	if pPlot:IsMountain() then
		mRangeFound = 0
		for n=1,4 do --just check four biggest ranges
			local mRange = mountainRangeList[n]
			--print("mRange.size = " .. #mRange.plotIndexList .. " id = " .. mRange.areaID)
			local iCurPlot = pPlot:GetIndex()
			if PWMountainAreas.data[iCurPlot] == mRange.areaID then
				--check distance from mountain range center
				--print("area id at cur plot " .. curPlot:GetX() .. ", " .. curPlot:GetY() .. " = " .. PWMountainAreas.data[iCurPlot])
				--print("area center = " .. mRange.centerIndex)
				if Map.GetPlotDistance(iCurPlot,mRange.centerIndex) > 4 then
					mRangeFound = mRangeFound + 1
				end
			end
		end
		if mRangeFound < 1 then
			return false
		end
		--check approaches
		local approachCount = 0
		for leftDir = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local rightDir = leftDir + 1
			if rightDir == 6 then
				rightDir = 0
			end
			local approach = {}
			local pPointPlot = Map.GetAdjacentPlot(pPlot:GetX(),pPlot:GetY(),leftDir)
			if pPointPlot ~= nil then
				table.insert(approach,pPointPlot:GetIndex())
				local pLeftPlot = Map.GetAdjacentPlot(pPointPlot:GetX(),pPointPlot:GetY(),leftDir)
				if pLeftPlot ~= nil then
					table.insert(approach,pLeftPlot:GetIndex())
					local pRightPlot = Map.GetAdjacentPlot(pPointPlot:GetX(),pPointPlot:GetY(),rightDir)
					if pRightPlot ~= nil then
						table.insert(approach,pRightPlot:GetIndex())
						if HasOnlyPassableLand(approach) then
							approachCount = approachCount + 1
						end
					end
				end
			end
		end
		--I'd like to see this nestled in the mountains, but not inaccesible
		if approachCount < 1 or approachCount > 2 then
			return false
		end
	else
		return false
	end
	return true
end
function PWCanHaveIkkil(pPlot)
	iPlot = pPlot:GetIndex()
	if temperatureMap.data[iPlot] < mc.jungleMinTemperature or rainfallMap.data[iPlot] < jungleThreshold then
		return false
	end	
	if pPlot:IsMountain() or pPlot:IsWater() then
		return false
	end
	--rivers in front of Ikkil look bad, but rivers behind are ok. Otherwise it's very hard to place
	--in the jungle
	local pWPlot = Map.GetAdjacentPlot(pPlot:GetX(),pPlot:GetY(),DirectionTypes.DIRECTION_WEST)
	if pPlot:IsWOfRiver() or pPlot:IsNWOfRiver() or pPlot:IsNEOfRiver() or pWPlot:IsWOfRiver() then
		return false
	end
	aPlots = {}
	table.insert(aPlots, pPlot:GetIndex())
	adj = GetAdjacentPlots(aPlots)
	if not HasOnlyPassableLand(adj) then
		return false
	end
	return true
end
function PWCanHaveUbsunurHollow(pPlot)
	--check climate on first plot
	iPlot = pPlot:GetIndex()
	if temperatureMap.data[iPlot] > mc.tundraTemperature then
		return false
	end	

	--these rotatable wonders are a PITA, anyway due to symmetry we only need three directions
	for dir = 0, 2, 1 do
		local aPlots = {}
		table.insert(aPlots,pPlot:GetIndex())
		local secondPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir)
		if secondPlot ~= nil then
			table.insert(aPlots,secondPlot:GetIndex())
			local thirdPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir + 1)
			if thirdPlot ~= nil then
				table.insert(aPlots,thirdPlot:GetIndex())
				local fourthPlot = Map.GetAdjacentPlot(secondPlot:GetX(),secondPlot:GetY(),dir + 1)
				if fourthPlot ~= nil then
					table.insert(aPlots,fourthPlot:GetIndex())
					if HasOnlyPassableLand(aPlots) then
						local adj = GetAdjacentPlots(aPlots)
						--print("adj length = " .. #adj)
						local mountainCount = 0 --UH should be next to some mountains
						local waterFound = false
						for i=1,#adj do
							adjPlot = Map.GetPlotByIndex(adj[i])
							if adjPlot:IsWater() then
								waterFound = true
								break
							end
							if adjPlot:IsMountain() then
								mountainCount = mountainCount + 1
							end
						end
						if not waterFound and mountainCount >=2 then
							return true
						end
					end
				end
			end
		end
	end
	return false
end
function PWCanHavePanatal(pPlot)
	--check climate on first plot
	iPlot = pPlot:GetIndex()
	if temperatureMap.data[iPlot] < mc.jungleMinTemperature or rainfallMap.data[iPlot] < jungleThreshold then
		--Pantanal is jungle baby!
		return false
	end	

	--these rotatable wonders are a PITA, anyway due to symmetry we only need three directions
	for dir = 0, 2, 1 do
		local aPlots = {}
		table.insert(aPlots,pPlot:GetIndex())
		local secondPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir)
		if secondPlot ~= nil then
			table.insert(aPlots,secondPlot:GetIndex())
			local thirdPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), dir + 1)
			if thirdPlot ~= nil then
				table.insert(aPlots,thirdPlot:GetIndex())
				local fourthPlot = Map.GetAdjacentPlot(secondPlot:GetX(),secondPlot:GetY(),dir + 1)
				if fourthPlot ~= nil then
					table.insert(aPlots,fourthPlot:GetIndex())
					if HasOnlyPassableLand(aPlots) then
						local adj = GetAdjacentPlots(aPlots)
						--print("adj length = " .. #adj)
						local mountainCount = 0 --Pantanal should be next to some mountains
						local waterFound = false
						for i=1,#adj do
							adjPlot = Map.GetPlotByIndex(adj[i])
							if adjPlot:IsWater() then
								waterFound = true
								break
							end
							if adjPlot:IsMountain() then
								mountainCount = mountainCount + 1
							end
						end
						if not waterFound and mountainCount >=2 then
							return true
						end
					end
				end
			end
		end
	end
	return false
end
function PWCanHaveEverest(pPlot)
	local aPlots = {}
	table.insert(aPlots,pPlot:GetIndex())
	local pWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST)
	if pWPlot == nil then return false; end
	table.insert(aPlots,pWPlot:GetIndex())
	local pEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST)
	if pEPlot == nil then return false; end
	table.insert(aPlots,pEPlot:GetIndex())
	
	--place near the middle of 2 biggest mountain ranges
	local mRangeFound = 0
	for i=1,#aPlots do
		local curPlot = Map.GetPlotByIndex(aPlots[i])
		if curPlot:IsMountain() then
			for n=1,2 do --just check two biggest ranges
				local mRange = mountainRangeList[n]
				--print("mRange.size = " .. #mRange.plotIndexList .. " id = " .. mRange.areaID)
				local iCurPlot = curPlot:GetIndex()
				if PWMountainAreas.data[iCurPlot] == mRange.areaID then
					--check distance from mountain range center
					--print("area id at cur plot " .. curPlot:GetX() .. ", " .. curPlot:GetY() .. " = " .. PWMountainAreas.data[iCurPlot])
					--print("area center = " .. mRange.centerIndex)
					if Map.GetPlotDistance(iCurPlot,mRange.centerIndex) <= 4 then
						mRangeFound = mRangeFound + 1
					end
				end
			end
		end
	end
	if mRangeFound < 2 then
		return false
	end
	--now check for a clear approach on all three sides
	--print("mountain range found at " .. pPlot:GetX() .. ", " .. pPlot:GetY())

	local sApproachClear = true
	local southApproach = {}
	local sAPoint = Map.GetAdjacentPlot(pWPlot:GetX(), pWPlot:GetY(),DirectionTypes.DIRECTION_SOUTHEAST)
	if sAPoint ~= nil then table.insert(southApproach, sAPoint:GetIndex()); else sApproachClear = false; end
	local sASW = Map.GetAdjacentPlot(sAPoint:GetX(), sAPoint:GetY(),DirectionTypes.DIRECTION_SOUTHWEST)
	if sASW ~= nil then table.insert(southApproach, sASW:GetIndex()); else sApproachClear = false; end
	local sASE = Map.GetAdjacentPlot(sAPoint:GetX(), sAPoint:GetY(),DirectionTypes.DIRECTION_SOUTHEAST)
	if sASE ~= nil then table.insert(southApproach, sASE:GetIndex()); else sApproachClear = false; end
	if not HasOnlyPassableLand(southApproach) then
		sApproachClear = false
	end

	local nwApproachClear = true
	local northwestApproach = {}
	local nwAPoint = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(),DirectionTypes.DIRECTION_WEST)
	if nwAPoint ~= nil then table.insert(northwestApproach, nwAPoint:GetIndex()); else nwApproachClear = false; end
	local nwANW = Map.GetAdjacentPlot(nwAPoint:GetX(), nwAPoint:GetY(),DirectionTypes.DIRECTION_NORTHWEST)
	if nwANW ~= nil then table.insert(northwestApproach, nwANW:GetIndex()); else nwApproachClear = false; end
	local nwAW = Map.GetAdjacentPlot(nwAPoint:GetX(), nwAPoint:GetY(),DirectionTypes.DIRECTION_WEST)
	if nwAW ~= nil then table.insert(northwestApproach, nwAW:GetIndex()); else nwApproachClear = false; end
	if not HasOnlyPassableLand(northwestApproach) then
		nwApproachClear = false
	end

	local neApproachClear = true
	local northeastApproach = {}
	local neAPoint = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(),DirectionTypes.DIRECTION_EAST)
	if neAPoint ~= nil then table.insert(northeastApproach, neAPoint:GetIndex()); else neApproachClear = false; end
	local neANE = Map.GetAdjacentPlot(neAPoint:GetX(), neAPoint:GetY(),DirectionTypes.DIRECTION_NORTHEAST)
	if neANE ~= nil then table.insert(northeastApproach, neANE:GetIndex()); else neApproachClear = false; end
	local nwAE = Map.GetAdjacentPlot(neAPoint:GetX(), neAPoint:GetY(),DirectionTypes.DIRECTION_EAST)
	if nwAE ~= nil then table.insert(northeastApproach, nwAE:GetIndex()); else neApproachClear = false; end
	if not HasOnlyPassableLand(northeastApproach) then
		neApproachClear = false
	end
	if (not sApproachClear) and (not nwApproachClear) and (not neApproachClear) then 
		return false --no clear approach
	end
	if HasInternalRivers(aPlots) then
		return false
	end
	return true
end
function PWCanHaveRoraima(pPlot)
	-- This one does require three in a row, so let's find that first
	for i = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local aPlots = {}
		table.insert(aPlots,pPlot:GetIndex())
		local pFirstPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), i);
		if pFirstPlot ~= nil then
			local pSecondPlot = Map.GetAdjacentPlot(pFirstPlot:GetX(), pFirstPlot:GetY(), i);
			if pSecondPlot ~= nil then
				local iNewDir = i - 1;
				if iNewDir == -1 then
					iNewDir = 5;
				end
				--check climate at nook
				pNookPlot = Map.GetAdjacentPlot(pFirstPlot:GetX(), pFirstPlot:GetY(), iNewDir)
				if pNookPlot ~= nil then
					local iNook = pNookPlot:GetIndex()
					if temperatureMap.data[iNook] >= mc.jungleMinTemperature then
						--print("inside of temperature range")				
						if rainfallMap.data[iNook] >= jungleThreshold then
							--print("plenty of rain")
							if (not pNookPlot:IsMountain()) and (not pNookPlot:IsWater()) then							
								local pThirdPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), iNewDir);
								if pThirdPlot ~= nil then
									table.insert(aPlots, pFirstPlot:GetIndex());
									table.insert(aPlots, pSecondPlot:GetIndex());
									table.insert(aPlots, pThirdPlot:GetIndex());
									
									if (not HasInternalRivers(aPlots)) and (not HasVolcanoesOrWater(aPlots)) then
										adj = GetAdjacentPlots(aPlots)
										local landCount = 0
										for n=1,#adj do
											local nPlot = Map.GetPlotByIndex(adj[n])
											if (not nPlot:IsMountain()) and (not nPlot:IsWater()) then
												landCount = landCount + 1
											end
										end
										--print("roraima landcount = " .. landCount)
										if landCount >= 8 then --make sure enough land to be useful
											return true
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return false
end

function PWCanHaveYosemiteOrTDP(pPlot)
	--print("&&&&&&&&&&checking plot at " .. pPlot:GetX() .. ", " .. pPlot:GetY())
	local mainPlots = {} --these are the actual two plots of the NW
	--first get the main plots
	table.insert(mainPlots,pPlot)
	local ppPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_EAST)
	if ppPlot == nil then return false; end
	table.insert(mainPlots,ppPlot)
	for i=1,2 do
		--just can't be water
		local thisPlot = mainPlots[i]
		if thisPlot:IsWater() then
			return false;
		end
		--volcanoes here could crash the game
		if pPlot:GetFeatureType() == g_FEATURE_VOLCANO or ppPlot:GetFeatureType() == g_FEATURE_VOLCANO then
			return false
		end
	end
	if pPlot:IsWOfRiver() or pPlot:IsNWOfRiver() or ppPlot:IsNEOfRiver() then --this rivers won't look right
		return false
	end
	
	local adjacentPlots = {}
	
	local westAnchorPlots = {} --these are the three plots bracketing the west tile of NW
	local NWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST)
	if NWPlot == nil then return false; end
	table.insert(westAnchorPlots,NWPlot)
	table.insert(adjacentPlots,NWPlot)
	local WPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_WEST)
	if WPlot == nil then return false; end
	table.insert(westAnchorPlots,WPlot)
	table.insert(adjacentPlots,WPlot)
	local SWPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST)
	if SWPlot == nil then return false; end
	table.insert(westAnchorPlots,SWPlot)
	table.insert(adjacentPlots,SWPlot)
	
	local eastAnchorPlots = {} --these are the three plots bracketing the east tile of NW
	local NEPlot = Map.GetAdjacentPlot(ppPlot:GetX(), ppPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST)
	if NEPlot == nil then return false; end
	table.insert(eastAnchorPlots,NEPlot)
	table.insert(adjacentPlots,NEPlot)
	local EPlot = Map.GetAdjacentPlot(ppPlot:GetX(), ppPlot:GetY(), DirectionTypes.DIRECTION_EAST)
	if EPlot == nil then return false; end
	table.insert(eastAnchorPlots,EPlot)
	table.insert(adjacentPlots,EPlot)
	local SEPlot = Map.GetAdjacentPlot(ppPlot:GetX(), ppPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST)
	if SEPlot == nil then return false; end
	table.insert(eastAnchorPlots,SEPlot)
	table.insert(adjacentPlots,SEPlot)
	
	local bWestMountainFound = false
	local bWestMajorRangeFound = false;
	for i = 1,#westAnchorPlots do
		local curPlot = westAnchorPlots[i]
		if curPlot:IsMountain() then
			bWestMountainFound = true
			for n=1,#mountainRangeList do
				local mRange = mountainRangeList[n]
				local iCurPlot = curPlot:GetIndex()
				if PWMountainAreas.data[iCurPlot] == mRange.areaID then
					bWestMajorRangeFound = true
				end
			end
		end
	end
	-- if bWestMountainFound == false then --need at least one mountain on this side
		-- return false
	-- end
	local bEastMountainFound = false
	local bEastMajorRangeFound = false;
	for i = 1,#eastAnchorPlots do
		local curPlot = eastAnchorPlots[i]
		if curPlot:IsMountain() then
			bEastMountainFound = true
			for n=1,#mountainRangeList do
				local mRange = mountainRangeList[n]
				local iCurPlot = curPlot:GetIndex()
				if PWMountainAreas.data[iCurPlot] == mRange.areaID then
					bEastMajorRangeFound = true
				end
			end
		end
	end
	-- if bEastMountainFound == false then --need at least one mountain on this side
		-- return false
	-- end
	if bEastMajorRangeFound == false and bWestMajorRangeFound == false then --one side or other must be on major range
		--print("no major range as anchor")
		return false
	end
	
	local northPlots = {} --these are the 3 plots north of the two tile NW
	local npEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST)
	if npEPlot == nil then return false; end
	if npEPlot:IsWOfRiver() or npEPlot:IsNEOfRiver() or npEPlot:IsNWOfRiver() then
		return false
	end
	table.insert(northPlots,npEPlot)
	table.insert(adjacentPlots,npEPlot)
	local npNWPlot = Map.GetAdjacentPlot(npEPlot:GetX(), npEPlot:GetY(), DirectionTypes.DIRECTION_NORTHWEST)
	if npNWPlot == nil then return false; end
	table.insert(northPlots,npNWPlot)
	local npNEPlot = Map.GetAdjacentPlot(npEPlot:GetX(), npEPlot:GetY(), DirectionTypes.DIRECTION_NORTHEAST)
	if npNEPlot == nil then return false; end
	table.insert(northPlots,npNEPlot)
	
	local northApproachLandOnly = true
	for n=1,#northPlots do
		local curPlot = northPlots[n]
		if curPlot:IsMountain() or curPlot:IsWater() then
			northApproachLandOnly = false
		end
	end

	
	local southPlots = {} --these are the 3 plots south of the two tile NW
	local spEPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST)
	if spEPlot == nil then return false; end
	table.insert(southPlots,spEPlot)
	table.insert(adjacentPlots,spEPlot)
	local spSWPlot = Map.GetAdjacentPlot(spEPlot:GetX(), spEPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST)
	if spSWPlot == nil then return false; end
	table.insert(southPlots,spSWPlot)
	local spSEPlot = Map.GetAdjacentPlot(spEPlot:GetX(), spEPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST)
	if spSEPlot == nil then return false; end
	table.insert(southPlots,spSEPlot)
	
	local southApproachLandOnly = true
	for n=1,#southPlots do
		local curPlot = southPlots[n]
		if curPlot:IsMountain() or curPlot:IsWater() then
			southApproachLandOnly = false
		end
	end
	
	--one approach must be clear and passable
	if northApproachLandOnly == false and southApproachLandOnly == false then
		--print("no clear approach triangles")
		return false
	end
	
	local adjacentPassableCount = 0
	for n=1,#adjacentPlots do
		local curPlot = adjacentPlots[n]
		if not (curPlot:IsMountain() or curPlot:IsWater()) then
			adjacentPassableCount = adjacentPassableCount + 1
		end
	end
	if adjacentPassableCount < 5 then
		--print("not enough clear perimeter")
		return false
	end
	--print("adj passable count = " .. adjacentPassableCount)
	
	--now lets look for a temperate climate on the clear approaches
	local iPlot = nil
	if northApproachLandOnly then
		iPlot = npEPlot:GetIndex()
	else
		iPlot = spEPlot:GetIndex()
	end
	if temperatureMap.data[iPlot] > mc.jungleMinTemperature or temperatureMap.data[iPlot] < mc.treesMinTemperature then
		--print("outside of temperature range")
		return false
	end
	
	if rainfallMap.data[iPlot] < zeroTreesThreshold then
		--print("not enough rain")
		return false
	end
	--print("XXXXXXXXXXXXXXXXXXXXlocation passed!XXXXXXXXXXX" .. pPlot:GetX() .. ", " .. pPlot:GetY())
	return true --all tests passed
end

function HasInternalRivers(aPlots)
--aPlots is a list of map indexes, not plot objects!
--determine if wonder tiles have rivers flowing between plots in the list
	for i=1,#aPlots do
		iCurPlot = aPlots[i]
		curPlot = Map.GetPlotByIndex(iCurPlot)
		--checking three directions where rivers can be defined
		--East
		local nPlot =  Map.GetAdjacentPlot(curPlot:GetX(), curPlot:GetY(), DirectionTypes.DIRECTION_EAST)
		--find if nPlot is in aPlots
		if nPlot ~= nil then
			for n=1,#aPlots do
				if nPlot:GetIndex() == aPlots[n] then
					if curPlot:IsWOfRiver() then
						return true --found a river between two wonder plots
					end
				end
			end
		end
		--SouthEast
		nPlot =  Map.GetAdjacentPlot(curPlot:GetX(), curPlot:GetY(), DirectionTypes.DIRECTION_SOUTHEAST)
		--find if nPlot is in aPlots
		if nPlot ~= nil then
			for n=1,#aPlots do
				if nPlot:GetIndex() == aPlots[n] then
					if curPlot:IsNWOfRiver() then
						return true --found a river between two wonder plots
					end
				end
			end
		end
		--SouthWest
		nPlot =  Map.GetAdjacentPlot(curPlot:GetX(), curPlot:GetY(), DirectionTypes.DIRECTION_SOUTHWEST)
		--find if nPlot is in aPlots
		if nPlot ~= nil then
			for n=1,#aPlots do
				if nPlot:GetIndex() == aPlots[n] then
					if curPlot:IsNEOfRiver() then
						return true --found a river between two wonder plots
					end
				end
			end
		end
	end
	return false --no internal rivers found
end

function HasVolcanoesOrWater(aPlots)
	for i=1,#aPlots do
		curPlot = Map.GetPlotByIndex(aPlots[i])
		if curPlot:IsWater() then
			return true
		end
		if curPlot:GetFeatureType() == g_FEATURE_VOLCANO then
			return true
		end
	end
	return false
end
function HasOnlyPassableLand(aPlots)
	for i=1,#aPlots do
		curPlot = Map.GetPlotByIndex(aPlots[i])
		if curPlot:IsWater() then
			return false
		end
		if curPlot:IsImpassable() then
			return false
		end
	end
	return true
end
function GetAdjacentPlots(aPlots)
	local adj = {}
	for i=1,#aPlots do
		local curPlot = Map.GetPlotByIndex(aPlots[i])
		for dir = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local nPlot = Map.GetAdjacentPlot(curPlot:GetX(), curPlot:GetY(), dir)
			if nPlot ~= nil then
				local plotFound = false
				for n=1,#aPlots do --search main plot list
					if nPlot:GetIndex() == aPlots[n] then
						plotFound = true
						break
					end
				end
				for n=1,#adj do --search existed adjacents list
					if nPlot:GetIndex() == adj[n] then
						plotFound = true
						break
					end				
				end
				if not plotFound then --if this is new, then add
					table.insert(adj,nPlot:GetIndex())
				end
			end
		end
	end
	--print("adj length is " .. #adj)
	return adj
end
--this function is made to work with Civ direction defined in MapEnums
function GetOppositeDirection(dir)
	if dir < 0 or dir > 5 then
		error("bad direction input to GetOppositeDirection")
	end
	local opp = dir + 3
	if opp > 5 then
		opp = opp - 6
	end
	return opp
end
-------------------------------------------------------------------------
--TerrainArea class for mountain ranges and deserts
-------------------------------------------------------------------------
TerrainArea = inheritsFrom(nil)

function TerrainArea:New(areaID)
	local new_inst = {}
	setmetatable(new_inst, {__index = TerrainArea});
	
	new_inst.areaID = areaID
	new_inst.plotIndexList = {}
	new_inst.centerIndex = nil
	
	return new_inst
end

function TerrainArea:CalculateCenter()
	local xCume = 0
	local yCume = 0
	for i=1,#self.plotIndexList do
		iPlot = self.plotIndexList[i] 
		local x, y = elevationMap:GetXYFromIndex(iPlot)
		xCume = xCume + x
		yCume = yCume + y
	end
	xCume = math.floor(xCume/#self.plotIndexList)
	yCume = math.floor(yCume/#self.plotIndexList)
	self.centerIndex = elevationMap:GetIndex(xCume,yCume)
	
	return self.centerIndex
end


--~ mc = MapConstants:New()
--~ PWRandSeed()

--~ elevationMap = GenerateElevationMap(100,70,true,false)
--~ FillInLakes()
--~ elevationMap:Save("elevationMap.csv")

--~ rainfallMap, temperatureMap = GenerateRainfallMap(elevationMap)
--~ temperatureMap:Save("temperatureMap.csv")
--~ rainfallMap:Save("rainfallMap.csv")

--~ riverMap = RiverMap:New(elevationMap)
--~ riverMap:SetJunctionAltitudes()
--~ riverMap:SiltifyLakes()
--~ riverMap:SetFlowDestinations()
--~ riverMap:SetRiverSizes(rainfallMap)



