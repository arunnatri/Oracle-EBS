--
-- XXD_GL_JE_RETAIL_IC_MARKUP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_JE_RETAIL_IC_MARKUP_PKG"
IS
    /******************************************************************************************
     NAME           : XXD_GL_JE_RETAIL_IC_MARKUP_PKG
     Desc           : Deckers Retail IC Markup for Sales and Onhand Journal Creation Program

     REVISIONS:
     Date        Author             Version  Description
     ---------   ----------         -------  ---------------------------------------------------
     23-MAR-2023 Thirupathi Gajula  1.0      Created this package XXD_GL_JE_RETAIL_IC_MARKUP_PKG
                                             for Markup Retail GL Journal Import
    *********************************************************************************************/
    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, p_cut_of_date IN VARCHAR2, p_Sales_from_Rep_date IN VARCHAR2, p_ledger IN NUMBER, p_org_unit_id_rms IN NUMBER, p_ou_id IN NUMBER, p_inv_org_id IN NUMBER, p_store_number IN NUMBER, p_onhand_currency IN VARCHAR2, p_markup_currency IN VARCHAR2, p_markup_calc_cur IN VARCHAR2, p_rate_type IN VARCHAR2, p_jl_rate_type IN VARCHAR2, p_type IN VARCHAR2
                        , p_report_mode IN VARCHAR2);

    FUNCTION get_conv_rate (pv_from_currency IN VARCHAR2, pv_to_currency IN VARCHAR2, pv_conversion_type IN VARCHAR2
                            , pd_conversion_date IN DATE)
        RETURN NUMBER;

    PROCEDURE update_oh_direct_ou (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pn_ou_id NUMBER
                                   , pn_request_id NUMBER);
END xxd_gl_je_retail_ic_markup_pkg;
/
