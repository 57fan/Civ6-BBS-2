------------------------------------------------------------------------------
--	FILE:	 bbg_less_wonders.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by new BBS
------------------------------------------------------------------------------

UPDATE Maps SET NumNaturalWonders = 1  	WHERE MapSizeType='MAPSIZE_DUEL' ;
UPDATE Maps SET NumNaturalWonders = 1  	WHERE MapSizeType='MAPSIZE_TINY' ;
UPDATE Maps SET NumNaturalWonders = 3  	WHERE MapSizeType='MAPSIZE_SMALL' ;
UPDATE Maps SET NumNaturalWonders = 3  	WHERE MapSizeType='MAPSIZE_STANDARD' ;
UPDATE Maps SET NumNaturalWonders = 4  WHERE MapSizeType='MAPSIZE_LARGE' ;
UPDATE Maps SET NumNaturalWonders = 4  WHERE MapSizeType='MAPSIZE_HUGE' ;
UPDATE Maps SET NumNaturalWonders = 5  WHERE MapSizeType='MAPSIZE_ENORMOUS' ;