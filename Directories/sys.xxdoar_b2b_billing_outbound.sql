DROP DIRECTORY XXDOAR_B2B_BILLING_OUTBOUND;

--
-- XXDOAR_B2B_BILLING_OUTBOUND  (Directory) 
--
CREATE OR REPLACE DIRECTORY 
XXDOAR_B2B_BILLING_OUTBOUND AS 
'/f01/EBSPROD/Outbound/Integrations/BillTrust/Billing';


GRANT EXECUTE, READ, WRITE ON DIRECTORY XXDOAR_B2B_BILLING_OUTBOUND TO APPS WITH GRANT OPTION;