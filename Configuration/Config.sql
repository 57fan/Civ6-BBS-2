--==============================================================================
--******			Global Parameters			  ******
--==============================================================================
-- Minimum Distances for CPL (Original 2 / 3 / 7 / 6)
UPDATE GlobalParameters SET Value='4' WHERE Name='START_DISTANCE_MAJOR_NATURAL_WONDER';
UPDATE GlobalParameters SET Value='4' WHERE Name='START_DISTANCE_MINOR_NATURAL_WONDER';
UPDATE GlobalParameters SET Value='8' WHERE Name='START_DISTANCE_MINOR_MAJOR_CIVILIZATION';
UPDATE GlobalParameters SET Value='7' WHERE Name='START_DISTANCE_MINOR_CIVILIZATION_START';

