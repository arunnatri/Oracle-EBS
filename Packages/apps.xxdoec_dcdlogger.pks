--
-- XXDOEC_DCDLOGGER  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--   XXDOEC_DCDLOG (Table)
--   XXDOEC_DCDLOGPARAMETERS (Table)
--
/* Formatted on 4/26/2023 4:12:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdoec_DCDLogger
AS
    /******************************************************************************
       NAME:       xxdoec_DCDLogger
       PURPOSE:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        11/2/2011      mbacigalupi       1. Created this package.
    ******************************************************************************/
    G_APPLICATION   VARCHAR2 (300) := 'xxdo.xxdoec_DCDLogger';

    TYPE dcdLog_rec IS RECORD
    (
        ID                  xxdo.xxdoec_DCDLog.ID%TYPE,
        Code                xxdo.xxdoec_DCDLog.Code%TYPE,
        MESSAGE             xxdo.xxdoec_DCDLog.MESSAGE%TYPE,
        Server              xxdo.xxdoec_DCDLog.Server%TYPE,
        Application         xxdo.xxdoec_DCDLog.Application%TYPE,
        FunctionName        xxdo.xxdoec_DCDLog.FunctionName%TYPE,
        LogEventType        xxdo.xxdoec_DCDLog.LogEventType%TYPE,
        dtLogged            xxdo.xxdoec_DCDLog.dtLogged%TYPE,
        ResolutionStatus    xxdo.xxdoec_DCDLog.ResolutionStatus%TYPE,
        Severity            xxdo.xxdoec_DCDLog.Severity%TYPE,
        ParentID            xxdo.xxdoec_DCDLog.ParentID%TYPE,
        SiteID              xxdo.xxdoec_DCDLog.SiteID%TYPE,
        Repl_Flag           xxdo.xxdoec_DCDLog.Repl_Flag%TYPE
    );

    TYPE dcdLogParameters_rec IS RECORD
    (
        LogId             xxdo.xxdoec_DCDLogParameters.LogId%TYPE,
        ParameterName     xxdo.xxdoec_DCDLogParameters.ParameterName%TYPE,
        ParameterValue    xxdo.xxdoec_DCDLogParameters.ParameterValue%TYPE,
        ParameterType     xxdo.xxdoec_DCDLogParameters.ParameterType%TYPE
    );

    TYPE DCDLog_return_rec IS RECORD
    (
        ParameterName       xxdo.xxdoec_DCDLogParameters.ParameterName%TYPE,
        ParameterValue      xxdo.xxdoec_DCDLogParameters.ParameterValue%TYPE,
        ParameterType       xxdo.xxdoec_DCDLogParameters.ParameterType%TYPE,
        ID                  xxdo.xxdoec_DCDLog.ID%TYPE,
        Code                xxdo.xxdoec_DCDLog.Code%TYPE,
        MESSAGE             xxdo.xxdoec_DCDLog.MESSAGE%TYPE,
        Server              xxdo.xxdoec_DCDLog.Server%TYPE,
        Application         xxdo.xxdoec_DCDLog.Application%TYPE,
        FunctionName        xxdo.xxdoec_DCDLog.FunctionName%TYPE,
        LogEventType        xxdo.xxdoec_DCDLog.LogEventType%TYPE,
        dtLogged            xxdo.xxdoec_DCDLog.dtLogged%TYPE,
        ResolutionStatus    xxdo.xxdoec_DCDLog.ResolutionStatus%TYPE,
        Severity            xxdo.xxdoec_DCDLog.Severity%TYPE,
        ParentID            xxdo.xxdoec_DCDLog.ParentID%TYPE,
        SiteID              xxdo.xxdoec_DCDLog.SiteID%TYPE,
        Repl_Flag           xxdo.xxdoec_DCDLog.Repl_Flag%TYPE
    );

    TYPE dcdLogParameters_tbl_type IS TABLE OF dcdLogParameters_rec
        INDEX BY BINARY_INTEGER;

    TYPE t_id_array IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    TYPE oracle_rec_cur IS REF CURSOR
        RETURN DCDLog_return_rec;

    FUNCTION MyFunction (Param1 IN NUMBER)
        RETURN NUMBER;

    PROCEDURE UpdateRepl_Flag (p_id_list IN t_id_array);

    PROCEDURE get_oracle_records (p_number               NUMBER := 500,
                                  p_oracle_rec_cur   OUT oracle_rec_cur);

    PROCEDURE Delete_replicated_records (p_number IN NUMBER:= 1000);
END xxdoec_DCDLogger;
/
