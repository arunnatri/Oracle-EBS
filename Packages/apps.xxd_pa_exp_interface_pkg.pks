--
-- XXD_PA_EXP_INTERFACE_PKG  (Package) 
--
--  Dependencies: 
--   XXD_EXP_CIP_TRANSFER_GT (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_PA_EXP_INTERFACE_PKG
AS
    /*******************************************************************************
    * Program Name    : XXD_PA_EXP_INTERFACE_PKG
    * Language        : PL/SQL
    * Description     : This package will is an Interfaces Inter LE CIP Costs
    * History :
    *
    *         WHO             Version        when            Desc
    * --------------------------------------------------------------------------
    * BT Technology Team      1.0          21/Jan/2015        Interface Prog
    * --------------------------------------------------------------------------- */

    --Table type declaration for staging tables
    TYPE lt_xxd_exp_cip_tbl_type IS TABLE OF xxd_exp_cip_transfer_gt%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE request_table IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    --Procedures/Functions
    PROCEDURE insert_negative_line (p_transfer_id IN VARCHAR2, p_status OUT VARCHAR2, p_error_msg OUT VARCHAR2);

    PROCEDURE insert_positive_line (p_transfer_id IN VARCHAR2, p_status OUT VARCHAR2, p_error_msg OUT VARCHAR2);

    PROCEDURE main_interface (p_transfer_ref_no   IN     VARCHAR2,
                              p_errorred             OUT VARCHAR2);

    PROCEDURE submit_import_prog (errbuf                 OUT VARCHAR2,
                                  retcode                OUT NUMBER,
                                  p_transfer_ref_no   IN     VARCHAR2);

    PROCEDURE update_stage3 (p_transfer_ref_no IN VARCHAR2);

    FUNCTION stage1_clear (p_orig_trx_ref IN VARCHAR2)
        RETURN VARCHAR2;
END xxd_pa_exp_interface_pkg;
/
