------------------------------------------------------------------------------
--	FILE:	 bbg_bias_master.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by new BBS
------------------------------------------------------------------------------

CREATE TABLE 'StartBiasNegatives' (
								'CivilizationType' TEXT NOT NULL,
								'TerrainType' TEXT,
								'FeatureType' TEXT,
								'ResourceType' TEXT,
								'Tier' INT NOT NULL,
								'Extra' TEXT
								);
								
CREATE TABLE 'StartBiasCustom' (
								'CivilizationType' TEXT NOT NULL,
								'CustomPlacement' TEXT
								);								
			
-- Tier 1 = most impactful, Tier 5 = least impactful

			
--INSERT OR IGNORE INTO StartBiasNegatives
	--	(CivilizationType,							FeatureType,						Tier)
	--	VALUES		
	--	('CIVILIZATION_FRANCE',						'FEATURE_FLOODPLAINS',					5),		
	--	('CIVILIZATION_FRANCE',						'FEATURE_FLOODPLAINS_PLAINS',			5),
	--	('CIVILIZATION_FRANCE',						'FEATURE_FLOODPLAINS_GRASSLAND',		5);

INSERT OR IGNORE INTO StartBiasCustom
		(CivilizationType,							CustomPlacement)
		VALUES	
		--('CIVILIZATION_AZTEC',						'CUSTOM_CONTINENT_SPLIT'),
     ('CIVILIZATION_SPAIN',						'CUSTOM_CONTINENT_SPLIT');
      