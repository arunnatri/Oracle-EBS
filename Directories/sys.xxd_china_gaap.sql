DROP DIRECTORY XXD_CHINA_GAAP;

--
-- XXD_CHINA_GAAP  (Directory) 
--
CREATE OR REPLACE DIRECTORY 
XXD_CHINA_GAAP AS 
'/f01/EBSPROD/Outbound/Integrations/Reports/ChinaGAAP';


GRANT EXECUTE, READ, WRITE ON DIRECTORY XXD_CHINA_GAAP TO APPS;