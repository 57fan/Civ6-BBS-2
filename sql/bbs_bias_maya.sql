------------------------------------------------------------------------------
--	FILE:	 bbg_bias_maya.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by new BBS
------------------------------------------------------------------------------

-- Tier 1 = most impactful, Tier 5 = least impactful

INSERT OR IGNORE INTO StartBiasCustom
		(CivilizationType,							CustomPlacement)
		VALUES	
		('CIVILIZATION_MAYA',							'CUSTOM_HYDROPHOBIC');			

