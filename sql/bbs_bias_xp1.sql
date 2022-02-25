------------------------------------------------------------------------------
--	FILE:	 bbg_bias_xp1.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by new BBS
------------------------------------------------------------------------------

-- Tier 1 = most impactful, Tier 5 = least impactful

			
INSERT OR IGNORE INTO StartBiasNegatives
		(CivilizationType,							FeatureType,						Tier)
		VALUES	
		--('CIVILIZATION_NETHERLANDS',				'FEATURE_FLOODPLAINS',				5),		
		--('CIVILIZATION_NETHERLANDS',				'FEATURE_FLOODPLAINS_PLAINS',		5),
		--('CIVILIZATION_NETHERLANDS',				'FEATURE_FLOODPLAINS_GRASSLAND',	5),
		('CIVILIZATION_MAPUCHE',					'FEATURE_FLOODPLAINS',				3),		
		('CIVILIZATION_MAPUCHE',					'FEATURE_FLOODPLAINS_PLAINS',		3),
		('CIVILIZATION_MAPUCHE',					'FEATURE_FLOODPLAINS_GRASSLAND',	3);

