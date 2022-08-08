------------------------------------------------------------------------------
--	FILE:	 bbg_new_wonders_xp2.sql
--	AUTHOR:  D. / Jack The Narrator, Deliverator, ChimpanG
--	PURPOSE: Database modifications by new BBS
------------------------------------------------------------------------------


-----------------------------------------------
-- Features
-----------------------------------------------

INSERT OR IGNORE INTO Types
		(Type,										Kind)
		VALUES	
		('FEATURE_KRAKATOA',						'KIND_FEATURE');


INSERT OR IGNORE INTO Features
		(FeatureType,								Name,											Description,										Quote,										QuoteAudio,				NaturalWonder,		Appeal,		 	Tiles,			NoAdjacentFeatures,	NoRiver,		RequiresRiver,	Settlement, 	Coast,		NoCoast, 	Impassable,		SightThroughModifier, 	FollowRulesInWB,	MinDistanceNW, 	AddsFreshWater, Lake,	NotCliff, 	MinDistanceLand,	MaxDistanceLand, 	CustomPlacement)
		VALUES	
		('FEATURE_KRAKATOA',						'LOC_FEATURE_KRAKATOA_NAME',					'LOC_FEATURE_KRAKATOA_DESCRIPTION',					'LOC_FEATURE_KRAKATOA_QUOTE',				NULL,					1,					2,				1,				1,					1,				0,				0,				1,			0,			1,				2,						0,					0, 				0, 				0, 		0, 			0, 					0, 					NULL);

INSERT OR IGNORE INTO Features_XP2
		(FeatureType,								Volcano)
		VALUES	
		('FEATURE_KRAKATOA',						1);

INSERT OR IGNORE INTO Feature_ValidTerrains
		(FeatureType,								TerrainType)
		VALUES	
		('FEATURE_KRAKATOA',						'TERRAIN_GRASS'),
		('FEATURE_KRAKATOA',						'TERRAIN_GRASS_HILLS'),
		('FEATURE_KRAKATOA',						'TERRAIN_PLAINS'),
		('FEATURE_KRAKATOA',						'TERRAIN_PLAINS_HILLS'),		
		('FEATURE_KRAKATOA',						'TERRAIN_DESERT'),
		('FEATURE_KRAKATOA',						'TERRAIN_DESERT_HILLS');

INSERT OR IGNORE INTO Feature_NotAdjacentTerrains
		(FeatureType,								TerrainType)
		VALUES	
		('FEATURE_KRAKATOA',						'TERRAIN_PLAINS_MOUNTAIN'),
		('FEATURE_KRAKATOA',						'TERRAIN_SNOW_MOUNTAIN'),
		('FEATURE_KRAKATOA',						'TERRAIN_TUNDRA_MOUNTAIN'),
		('FEATURE_KRAKATOA',						'TERRAIN_DESERT_MOUNTAIN'),						
		('FEATURE_KRAKATOA',						'TERRAIN_GRASS_MOUNTAIN');		
					
INSERT OR IGNORE INTO Feature_AdjacentYields
		(FeatureType,								YieldType,					YieldChange)
		VALUES				
		('FEATURE_KRAKATOA',						'YIELD_SCIENCE',			2);	
		
		
-----------------------------------------------
-- RandomEvents
-----------------------------------------------

INSERT OR IGNORE INTO RandomEvents
		(NaturalWonder,			RandomEventType,						Name,											Description,											EffectString,								EffectOperatorType, Severity,	IconLarge,						IconSmall						)
VALUES	('FEATURE_KRAKATOA',	'RANDOM_EVENT_KRAKATOA_GENTLE',			'LOC_RANDOM_EVENT_KRAKATOA_GENTLE_NAME',		'LOC_RANDOM_EVENT_KRAKATOA_GENTLE_DESCRIPTION',			'LOC_RANDOM_EVENT_PROP_DAMAGE_FERTILITY',	'FEATURE',			0,			'ClimateEvent_VolcanoInactive',	'ClimateEventStat_Volcanoes'	),
		('FEATURE_KRAKATOA',	'RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'LOC_RANDOM_EVENT_KRAKATOA_CATASTROPHIC_NAME',	'LOC_RANDOM_EVENT_KRAKATOA_CATASTROPHIC_DESCRIPTION',	'LOC_RANDOM_EVENT_ALL_DAMAGE_FERTILITY',	'FEATURE',			1,			'ClimateEvent_VolcanoActive',	'ClimateEventStat_Volcanoes'	),
		('FEATURE_KRAKATOA',	'RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'LOC_RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL_NAME',	'LOC_RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL_DESCRIPTION',	'LOC_RANDOM_EVENT_ALL_DAMAGE_FERTILITY',	'FEATURE',			2,			'ClimateEvent_VolcanoErupting',	'ClimateEventStat_Volcanoes'	);

-----------------------------------------------
-- RandomEvent_Frequencies
-----------------------------------------------

INSERT OR IGNORE INTO RandomEvent_Frequencies
		(RandomEventType,						RealismSettingType,				OccurrencesPerGame	)
VALUES	('RANDOM_EVENT_KRAKATOA_GENTLE',		'REALISM_SETTING_MINIMAL',		2					),
		('RANDOM_EVENT_KRAKATOA_GENTLE',		'REALISM_SETTING_LIGHT',		3					),
		('RANDOM_EVENT_KRAKATOA_GENTLE',		'REALISM_SETTING_MODERATE',		4					),
		('RANDOM_EVENT_KRAKATOA_GENTLE',		'REALISM_SETTING_HEAVY',		6					),
		('RANDOM_EVENT_KRAKATOA_GENTLE',		'REALISM_SETTING_HYPERREAL',	4					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'REALISM_SETTING_MINIMAL',		1					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'REALISM_SETTING_LIGHT',		2					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'REALISM_SETTING_MODERATE',		2.5					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'REALISM_SETTING_HEAVY',		4					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'REALISM_SETTING_HYPERREAL',	6					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'REALISM_SETTING_MINIMAL',		3					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'REALISM_SETTING_LIGHT',		5					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'REALISM_SETTING_MODERATE',		7					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'REALISM_SETTING_HEAVY',		9					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'REALISM_SETTING_HYPERREAL',	9					);

-----------------------------------------------
-- RandomEvent_Damages
-----------------------------------------------

INSERT OR IGNORE INTO RandomEvent_Damages
		(RandomEventType,						DamageType,					Percentage,	MinHP,	MaxHP,	CoastalLowlandPercentage,	FalloutDuration,	ExtraRangePercentage)
VALUES	('RANDOM_EVENT_KRAKATOA_GENTLE',		'IMPROVEMENT_PILLAGED',		100,		0,		0,		NULL,						0,					0					),
		('RANDOM_EVENT_KRAKATOA_GENTLE',		'BUILDING_PILLAGED',		100,		0,		0,		NULL,						0,					0					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'IMPROVEMENT_DESTROYED',	80,			0,		0,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'IMPROVEMENT_PILLAGED',		100,		0,		0,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'DISTRICT_PILLAGED',		80,			0,		0,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'BUILDING_PILLAGED',		100,		0,		0,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'POPULATION_LOSS',			20,			0,		0,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'UNIT_KILLED_CIVILIAN',		0,			0,		0,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'UNIT_DAMAGE_LAND',			100,		40,		60,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'CITY_GARRISON',			100,		40,		60,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'CITY_WALLS',				100,		40,		60,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'IMPROVEMENT_DESTROYED',	80,			0,		0,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'IMPROVEMENT_PILLAGED',		100,		0,		0,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'DISTRICT_PILLAGED',		80,			0,		0,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'BUILDING_PILLAGED',		100,		0,		0,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'POPULATION_LOSS',			100,		0,		0,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'UNIT_KILLED_CIVILIAN',		0,		0,		0,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'UNIT_DAMAGE_LAND',			100,		70,		90,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'CITY_GARRISON',			100,		70,		90,		NULL,						0,					50					),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'CITY_WALLS',				100,		70,		90,		NULL,						0,					50					);

-----------------------------------------------
-- RandomEvent_Yields
-----------------------------------------------

INSERT OR IGNORE INTO RandomEvent_Yields
		(RandomEventType,						YieldType,			FeatureType,				Percentage, ReplaceFeature	)
VALUES	('RANDOM_EVENT_KRAKATOA_GENTLE',		'YIELD_FOOD',		'FEATURE_VOLCANIC_SOIL',	50,			1				),
		('RANDOM_EVENT_KRAKATOA_GENTLE',		'YIELD_PRODUCTION',	'FEATURE_VOLCANIC_SOIL',	25,			1				),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'YIELD_FOOD',		'FEATURE_VOLCANIC_SOIL',	50,			1				),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'YIELD_PRODUCTION',	'FEATURE_VOLCANIC_SOIL',	35,			1				),
		('RANDOM_EVENT_KRAKATOA_CATASTROPHIC',	'YIELD_SCIENCE',	'FEATURE_VOLCANIC_SOIL',	15,			1				),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'YIELD_FOOD',		'FEATURE_VOLCANIC_SOIL',	25,			1				),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'YIELD_PRODUCTION',	'FEATURE_VOLCANIC_SOIL',	25,			1				),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'YIELD_SCIENCE',	'FEATURE_VOLCANIC_SOIL',	25,			1				),
		('RANDOM_EVENT_KRAKATOA_MEGACOLOSSAL',	'YIELD_CULTURE',	'FEATURE_VOLCANIC_SOIL',	50,			1				);		
		
		
-----------------------------------------------
-- NamedVolcanoes
-----------------------------------------------

DELETE FROM NamedVolcanoes WHERE NamedVolcanoType = 'NAMED_VOLCANO_KRAKATOA';

DELETE FROM Types WHERE Type = 'NAMED_VOLCANO_KRAKATOA';