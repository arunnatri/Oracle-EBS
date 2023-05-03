--
-- XXDOAR021_REP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAR021_REP_PKG"
AS
    /******************************************************************************
       NAME: XXDOAR021_REP_PKG
      Program NAME:Transmit Factored Remittance Batch detail - Deckers

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       -- MODIFICATION HISTORY
    -- Person                          Date                                Comments
    --Shibu Alex                      12-12-2011                           Initial Version
    --Madhav Dhurjaty                 12-13-2013                           Modified  after_report, main_prog for CIT FTP change ENHC0011747
    --Madhav Dhurjaty                 08-04-2014                           Modified main_prog and Added function is_batch_balanced for ENHC0012098
    ******************************************************************************/

    --======================================================================+
    --                                                                      |
    -- Report Lexical Parameters                                            |
    --                                                                      |
    --======================================================================+
    p_sql_stmt    VARCHAR2 (32000);
    p_sql_stmt2   VARCHAR2 (32000);
    --======================================================================+
    --                                                                      |
    -- Report Input Parameters                                              |
    --                                                                      |
    --======================================================================+
    p_org_id      NUMBER;
    p_batch_id    NUMBER;
    p_file_name   VARCHAR2 (100);
    p_source      VARCHAR2 (1000);
    p_iden_rec    VARCHAR2 (2000);
    p_sent_yn     VARCHAR2 (20);

    FUNCTION before_report
        RETURN BOOLEAN;

    FUNCTION after_report
        RETURN BOOLEAN;

    FUNCTION is_batch_balanced (p_batch_id IN NUMBER, p_org_id IN NUMBER)
        RETURN BOOLEAN;

    FUNCTION cust_contact_det (p_cust_id   NUMBER,
                               p_site_id   NUMBER,
                               p_ret_col   VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION cust_addr_det (p_cust_id NUMBER, p_site_id NUMBER, p_use_code VARCHAR2
                            , p_ret_col VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION itm_color_style_desc (p_item_id      NUMBER,
                                   p_inv_org_id   NUMBER,
                                   p_ret_col      VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE main_prog (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, p_org_id IN NUMBER, p_batch_id IN NUMBER, p_file_name IN VARCHAR2, p_source IN VARCHAR2
                         , p_iden_rec IN VARCHAR2, p_sent_yn IN VARCHAR2);
END xxdoar021_rep_pkg;
/
