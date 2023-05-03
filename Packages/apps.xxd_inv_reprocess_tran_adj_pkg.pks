--
-- XXD_INV_REPROCESS_TRAN_ADJ_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_INV_REPROCESS_TRAN_ADJ_PKG"
AS
    --  #########################################################################################
    --  Author(s)       : Tejaswi Gangumalla
    --  System          : Oracle Applications
    --  Subsystem       :
    --  Change          :
    --  Schema          : APPS
    --  Purpose         : This package is used for re-processing of the inventory transaction messages which are in ERROR status
    --  Dependency      : N
    --  Change History
    --  --------------
    --  Date            Name                    Ver     Change                  Description
    --  ----------      --------------          -----   --------------------    ---------------------
    --  16-June-2019     Tejaswi Gangumalla       1.0     NA                      Initial Version
    --
    --  #########################################################################################
    PROCEDURE msg (pv_msg IN VARCHAR2, pv_file IN VARCHAR2 DEFAULT 'LOG');

    PROCEDURE control_proc (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER);

    PROCEDURE update_error_records (pn_count_records OUT NUMBER);

    PROCEDURE validate_and_insert_into_int (pv_submit_prog OUT VARCHAR2);

    PROCEDURE submit_program (pv_error_flag   OUT VARCHAR2,
                              pv_error_msg    OUT VARCHAR2);
END;
/
