DROP DIRECTORY XXD_PPM_IN;

--
-- XXD_PPM_IN  (Directory) 
--
CREATE OR REPLACE DIRECTORY 
XXD_PPM_IN AS 
'/f01/EBSPROD/Inbound/Integrations/PPM';


GRANT READ, WRITE ON DIRECTORY XXD_PPM_IN TO APPS;
