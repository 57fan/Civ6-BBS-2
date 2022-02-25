------------------------------------------------------------------------------
--	FILE:	 bbg_more_wonders.sql
--	AUTHOR:  D. / Jack The Narrator
--	PURPOSE: Database modifications by new BBS
------------------------------------------------------------------------------

UPDATE Maps SET NumNaturalWonders = 3  	WHERE MapSizeType='MAPSIZE_DUEL' ;
UPDATE Maps SET NumNaturalWonders = 4  	WHERE MapSizeType='MAPSIZE_TINY' ;
UPDATE Maps SET NumNaturalWonders = 6  	WHERE MapSizeType='MAPSIZE_SMALL' ;
UPDATE Maps SET NumNaturalWonders = 8  	WHERE MapSizeType='MAPSIZE_STANDARD' ;
UPDATE Maps SET NumNaturalWonders = 10  WHERE MapSizeType='MAPSIZE_LARGE' ;
UPDATE Maps SET NumNaturalWonders = 12  WHERE MapSizeType='MAPSIZE_HUGE' ;
UPDATE Maps SET NumNaturalWonders = 14  WHERE MapSizeType='MAPSIZE_ENORMOUS' ;

UPDATE Features SET MinDistanceNW = 4 WHERE NaturalWonder = 1 ;