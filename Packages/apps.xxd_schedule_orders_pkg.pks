--
-- XXD_SCHEDULE_ORDERS_PKG  (Package) 
--
--  Dependencies: 
--   XXD_BTOM_OEHEADER_TBLTYPE (Type)
--   XXD_BTOM_OELINE_TBLTYPE (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:37 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_SCHEDULE_ORDERS_PKG
AS
    PROCEDURE xxd_schedule_ordders_prc (p_header_id IN xxd_btom_oeheader_tbltype, p_orgid IN NUMBER, p_scheddate IN DATE, p_schedule_type IN VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER
                                        , p_resp_appl_id IN NUMBER, x_err_code OUT VARCHAR2, x_err_msg OUT VARCHAR2);

    PROCEDURE xxd_schedule_ordder_lines_prc (p_orgid IN NUMBER, p_line_id IN xxd_btom_oeline_tbltype, p_scheddate IN DATE, p_schedule_type IN VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER
                                             , p_resp_appl_id IN NUMBER, x_err_code OUT VARCHAR2, x_err_msg OUT VARCHAR2);
END XXD_SCHEDULE_ORDERS_PKG;
/
