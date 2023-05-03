DROP DIRECTORY XXD_CST_DUTY_ELE_INB_DIR;

--
-- XXD_CST_DUTY_ELE_INB_DIR  (Directory) 
--
CREATE OR REPLACE DIRECTORY 
XXD_CST_DUTY_ELE_INB_DIR AS 
'/f01/EBSPROD/Inbound/Integrations/Duty/Inbound';


GRANT EXECUTE, READ, WRITE ON DIRECTORY XXD_CST_DUTY_ELE_INB_DIR TO APPS WITH GRANT OPTION;