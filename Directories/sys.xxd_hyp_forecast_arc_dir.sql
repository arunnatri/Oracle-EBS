DROP DIRECTORY XXD_HYP_FORECAST_ARC_DIR;

--
-- XXD_HYP_FORECAST_ARC_DIR  (Directory) 
--
CREATE OR REPLACE DIRECTORY 
XXD_HYP_FORECAST_ARC_DIR AS 
'/f01/EBSPROD/Inbound/Integrations/Duty/Inbound/Hyperion/Archive';


GRANT EXECUTE, READ, WRITE ON DIRECTORY XXD_HYP_FORECAST_ARC_DIR TO APPS WITH GRANT OPTION;
