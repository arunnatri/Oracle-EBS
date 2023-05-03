DROP DIRECTORY XXDOAR_B2B_OPEN_AR_OUTBOUND;

--
-- XXDOAR_B2B_OPEN_AR_OUTBOUND  (Directory) 
--
CREATE OR REPLACE DIRECTORY 
XXDOAR_B2B_OPEN_AR_OUTBOUND AS 
'/f01/EBSPROD/Outbound/Integrations/BillTrust/OpenAR';


GRANT EXECUTE, READ, WRITE ON DIRECTORY XXDOAR_B2B_OPEN_AR_OUTBOUND TO APPS WITH GRANT OPTION;