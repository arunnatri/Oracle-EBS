DROP DIRECTORY XXD_GL_TRAIL_BALANCE_DIR;

--
-- XXD_GL_TRAIL_BALANCE_DIR  (Directory) 
--
CREATE OR REPLACE DIRECTORY 
XXD_GL_TRAIL_BALANCE_DIR AS 
'/f01/EBSPROD/Outbound/Integrations/Reports/GLTrailBal';


GRANT EXECUTE, READ, WRITE ON DIRECTORY XXD_GL_TRAIL_BALANCE_DIR TO APPS WITH GRANT OPTION;
