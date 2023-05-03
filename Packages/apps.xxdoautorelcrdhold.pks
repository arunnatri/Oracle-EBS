--
-- XXDOAUTORELCRDHOLD  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAUTORELCRDHOLD"
AS
    PROCEDURE hold_release (errbuf        OUT VARCHAR2,
                            retcode       OUT VARCHAR2-- Start code change on 25-Jul-2016
                                                      ,
                            p_org_id   IN     NUMBER-- End code change on 25-Jul-2016
                                                    );
END XXDOAUTORELCRDHOLD;
/
