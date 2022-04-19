------------------------------------------------------------------------------
--	FILE:	 bbg_bias_australia.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by new BBS
------------------------------------------------------------------------------

-- Tier 1 = most impactful, Tier 5 = least impactful

			
INSERT OR IGNORE INTO StartBiasNegatives
		(CivilizationType,							FeatureType,						Tier)
		VALUES	
		('CIVILIZATION_AUSTRALIA',					'FEATURE_FLOODPLAINS',			2),
		('CIVILIZATION_AUSTRALIA',					'FEATURE_FLOODPLAINS_PLAINS',		2),
      --('CIVILIZATION_SWEDEN',						'FEATURE_JUNGLE',					2),
      ('CIVILIZATION_AUSTRALIA',						'FEATURE_JUNGLE',					4),
		('CIVILIZATION_AUSTRALIA',					'FEATURE_FLOODPLAINS_GRASSLAND',	2);

INSERT OR IGNORE INTO StartBiasCustom
		(CivilizationType,							CustomPlacement)
		VALUES	
		('CIVILIZATION_AUSTRALIA',					'CUSTOM_I_AM_SALTY');		