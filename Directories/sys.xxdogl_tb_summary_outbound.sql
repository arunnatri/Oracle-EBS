DROP DIRECTORY XXDOGL_TB_SUMMARY_OUTBOUND;

--
-- XXDOGL_TB_SUMMARY_OUTBOUND  (Directory) 
--
CREATE OR REPLACE DIRECTORY 
XXDOGL_TB_SUMMARY_OUTBOUND AS 
'/f01/EBSPROD/Outbound/Integrations/OneSource/TBSummary';


GRANT EXECUTE, READ, WRITE ON DIRECTORY XXDOGL_TB_SUMMARY_OUTBOUND TO APPS WITH GRANT OPTION;
