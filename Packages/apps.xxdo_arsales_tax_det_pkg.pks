--
-- XXDO_ARSALES_TAX_DET_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ARSALES_TAX_DET_PKG"
IS
    FUNCTION get_mmt_cost_sales (pn_interface_line_attribute6 IN VARCHAR2, pn_interface_line_attribute7 IN VARCHAR2, pn_organization_id IN NUMBER
                                 , pn_sob_id IN NUMBER, pv_detail IN VARCHAR)
        RETURN NUMBER;

    FUNCTION get_account (p_trx_id       IN NUMBER,
                          p_sob_id       IN NUMBER,
                          p_gl_dist_id   IN NUMBER)
        RETURN VARCHAR2;

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_from_date IN VARCHAR2:= NULL, p_to_date IN VARCHAR2:= NULL, pn_ou IN VARCHAR2, pn_price_list IN NUMBER
                    , pn_elimination_org IN NUMBER);

    FUNCTION get_price (pn_so_line_id   VARCHAR2,
                        pn_org_id       NUMBER,
                        pv_col          VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_tax_details (p_trx_id        IN NUMBER,
                              p_trx_line_id   IN NUMBER,
                              p_mode          IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION GET_PRICE_LIST_VALUE (ppricelistid       NUMBER,
                                   pinventoryitemid   NUMBER)
        RETURN NUMBER;
END XXDO_ARSALES_TAX_DET_PKG;
/
