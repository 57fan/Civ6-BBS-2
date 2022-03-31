------------------------------------------------------------------------------
--	FILE:	 bbg_new_wonders_xp1_xp2.sql
--	AUTHOR:  D. / Jack The Narrator, Deliverator
--	PURPOSE: Database modifications by new BBS
------------------------------------------------------------------------------

-----------------------------------------------
-- Features
-----------------------------------------------

INSERT OR IGNORE INTO MomentIllustrations
		(MomentIllustrationType,							MomentDataType,				GameDataType,							Texture)
		VALUES	
		('MOMENT_ILLUSTRATION_NATURAL_WONDER',				'MOMENT_DATA_FEATURE',		'FEATURE_KRAKATOA',						'CHM_Moment_PromoteGovernor_Ambassador.dds');