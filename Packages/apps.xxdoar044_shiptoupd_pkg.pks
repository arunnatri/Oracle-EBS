--
-- XXDOAR044_SHIPTOUPD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAR044_SHIPTOUPD_PKG"
AS
    /***********************************************************************************
     *$header : *
     * *
     * AUTHORS : Showkath Ali V *
     * *
     * PURPOSE : To update the ship to*
     * *
     * PARAMETERS : *
     * *
     * *
     * Assumptions : *
     * *
     * *
     * History *
     * Vsn   Change Date Changed By         Change Description *
     * ----- ----------- ------------------ ------------------------------------- *
     * 1.0   27-OCT-2015 Showkath Ali V     Initial Creation *
     * *
     *********************************************************************************/
    PROCEDURE update_shiptos (errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
END;
/
