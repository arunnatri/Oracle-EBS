DROP DIRECTORY XXDO_EDI846_INC_EXU;

--
-- XXDO_EDI846_INC_EXU  (Directory) 
--
CREATE OR REPLACE DIRECTORY 
XXDO_EDI846_INC_EXU AS 
'/f01/EBSPROD/Outbound/Integrations/EDI846';


GRANT READ, WRITE ON DIRECTORY XXDO_EDI846_INC_EXU TO APPS;
