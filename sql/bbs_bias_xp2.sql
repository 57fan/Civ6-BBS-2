------------------------------------------------------------------------------
--	FILE:	 bbg_bias_xp2.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by new BBS
------------------------------------------------------------------------------

-- Tier 1 = most impactful, Tier 5 = least impactful

			
--INSERT OR IGNORE INTO StartBiasNegatives
		--(CivilizationType,							FeatureType,						Tier)
		--VALUES	
		--('CIVILIZATION_SWEDEN',						'FEATURE_JUNGLE',					5),	
		--('CIVILIZATION_HUNGARY',					'FEATURE_FLOODPLAINS',				3),		
		--('CIVILIZATION_HUNGARY',					'FEATURE_FLOODPLAINS_PLAINS',		3),
		--('CIVILIZATION_HUNGARY',					'FEATURE_FLOODPLAINS_GRASSLAND',	3);

--INSERT OR IGNORE INTO StartBiasNegatives
		--(CivilizationType,							TerrainType,						Tier)
		--VALUES	
		--('CIVILIZATION_SWEDEN',						'TERRAIN_TUNDRA',					2),
		--('CIVILIZATION_SWEDEN',						'TERRAIN_TUNDRA_MOUNTAIN',			2),
		--('CIVILIZATION_SWEDEN',						'TERRAIN_TUNDRA_HILLS',				2);


INSERT OR IGNORE INTO StartBiasCustom
		(CivilizationType,							CustomPlacement)
		VALUES	
		('CIVILIZATION_SWEDEN',						'CUSTOM_KING_OF_THE_NORTH'),
		--('CIVILIZATION_INCA',						'CUSTOM_CONTINENT_SPLIT'),
		('CIVILIZATION_INCA',						'CUSTOM_MOUNTAIN_LOVER');