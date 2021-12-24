------------------------------------------------------------------------------
--	FILE:	 bbg_new_wonders_xp1.sql
--	AUTHOR:  D. / Jack The Narrator, Deliverator
--	PURPOSE: Database modifications by new BBS
------------------------------------------------------------------------------

-----------------------------------------------
-- Features
-----------------------------------------------

INSERT OR IGNORE INTO MomentIllustrations
		(MomentIllustrationType,							MomentDataType,				GameDataType,							Texture)
		VALUES	
		('MOMENT_ILLUSTRATION_NATURAL_WONDER',				'MOMENT_DATA_FEATURE',		'FEATURE_BARRINGER_CRATER',				'CHM_Moment_PromoteGovernor_Ambassador.dds'),
		('MOMENT_ILLUSTRATION_NATURAL_WONDER',				'MOMENT_DATA_FEATURE',		'FEATURE_BIOLUMINESCENT_BAY',			'CHM_Moment_PromoteGovernor_Ambassador.dds'),
		('MOMENT_ILLUSTRATION_NATURAL_WONDER',				'MOMENT_DATA_FEATURE',		'FEATURE_CERRO_DE_POTOSI',				'CHM_Moment_PromoteGovernor_Ambassador.dds'),
		('MOMENT_ILLUSTRATION_NATURAL_WONDER',				'MOMENT_DATA_FEATURE',		'FEATURE_DALLOL',						'CHM_Moment_PromoteGovernor_Ambassador.dds'),
		('MOMENT_ILLUSTRATION_NATURAL_WONDER',				'MOMENT_DATA_FEATURE',		'FEATURE_GIBRALTAR',					'CHM_Moment_PromoteGovernor_Ambassador.dds'),
		('MOMENT_ILLUSTRATION_NATURAL_WONDER',				'MOMENT_DATA_FEATURE',		'FEATURE_GRAND_MESA',					'CHM_Moment_PromoteGovernor_Ambassador.dds'),
		('MOMENT_ILLUSTRATION_NATURAL_WONDER',				'MOMENT_DATA_FEATURE',		'FEATURE_KAILASH',						'CHM_Moment_PromoteGovernor_Ambassador.dds'),
		('MOMENT_ILLUSTRATION_NATURAL_WONDER',				'MOMENT_DATA_FEATURE',		'FEATURE_LAKE_VICTORIA',				'CHM_Moment_PromoteGovernor_Ambassador.dds'),
		('MOMENT_ILLUSTRATION_NATURAL_WONDER',				'MOMENT_DATA_FEATURE',		'FEATURE_LENCOIS_MARANHENSES',			'CHM_Moment_PromoteGovernor_Ambassador.dds');


