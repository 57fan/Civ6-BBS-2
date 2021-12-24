------------------------------------------------------------------------------
--	FILE:	 bbg_bias_australia.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by new BBS
------------------------------------------------------------------------------

-- Tier 1 = most impactful, Tier 5 = least impactful

			
INSERT OR IGNORE INTO StartBiasNegatives
		(CivilizationType,							FeatureType,						Tier)
		VALUES	
		('CIVILIZATION_AUSTRALIA',					'FEATURE_FLOODPLAINS',			1),
		('CIVILIZATION_AUSTRALIA',					'FEATURE_FLOODPLAINS_PLAINS',		1),
		('CIVILIZATION_AUSTRALIA',					'FEATURE_FLOODPLAINS_GRASSLAND',	1);

INSERT OR IGNORE INTO StartBiasCustom
		(CivilizationType,							CustomPlacement)
		VALUES	
		('CIVILIZATION_AUSTRALIA',					'CUSTOM_I_AM_SALTY');		