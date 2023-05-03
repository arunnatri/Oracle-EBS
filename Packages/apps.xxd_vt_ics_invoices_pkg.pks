--
-- XXD_VT_ICS_INVOICES_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_VT_ICS_INVOICES_PKG"
IS
    /******************************************************************************
       Ver    Date          Author      Description
       -----  -----------   -------     ------------------------------------------
       1.0    28-FEB-2018   Srinath     CCR0007077
       2.0    22-JUL-2019   Showkath    CCR0007979 - Macau Changes
       3.0    18-MAR-2020   Showkath    Macau PhaseII - New request to get the ship to country from SO
       3.1    15-MAR-2020   Showkath    Macau PhaseII - New logic to get Tax codes
       4.0    10-DEC-2020   Srinath     CCR0008507 - MTD Project
       4.1    02-APR-2021   Srinath     CCR0009103 - MTD Project PIII
    ******************************************************************************/

    -- Customized Virtual Trader IC Invoices Program as per requirement

    PROCEDURE IC_Invoice (errbuf OUT VARCHAR2, retcode OUT NUMBER, cInvoiceType IN VARCHAR2, cSource_id IN VARCHAR2, cSource_group_id IN VARCHAR2, cSource_assignment_id IN VARCHAR2, cInvoiceTaxReg IN VARCHAR2, cCustomerTaxReg IN VARCHAR2, cInvoice_Number_From IN VARCHAR2, cInvoice_Number_To IN VARCHAR2, cPurchase_Order IN VARCHAR2, cSales_Order IN VARCHAR2, cInvoice_Date_Low IN VARCHAR2, cInvoice_Date_High IN VARCHAR2, cProduct_Family IN VARCHAR2
                          , cUnPrinted_Flag IN VARCHAR2);


    --FUNCTION get_const_address Return VARCHAR2;

    FUNCTION get_const_address (p_comseg1         IN VARCHAR2,
                                p_comseg2         IN VARCHAR2,
                                p_inv_header_id   IN NUMBER,
                                p_tax_reg_id      IN NUMBER,
                                p_inv_add_id      IN NUMBER)
        RETURN VARCHAR2;

    /*FUNCTION Get_comp_tax_reg(p_type         IN VARCHAR2,
                              p_comseg1      IN VARCHAR2,
                              p_inv_tax_reg  IN VARCHAR2)
    RETURN VARCHAR2;  */

    FUNCTION Get_comp_tax_reg (p_type IN VARCHAR2, p_comseg1 IN VARCHAR2, p_inv_tax_reg IN VARCHAR2
                               , p_inv_header_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_country (p_tax1 IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION Get_Address (cAddress_Id IN NUMBER, cType IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_ou_country (cbal_segment IN VARCHAR2, ctype IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_source (p_inv_header_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_so_ar_number (p_mmt_trx_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_so_cust_po (p_mmt_trx_id IN NUMBER, p_Trx_type IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_lang (p_ComSeg1 IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_source_lang (p_inv_header_id   IN NUMBER,
                              p_ComSeg1         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_ship_from_country (p_inv_header_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_ship_to_country (p_inv_header_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_mmt_type (p_inv_header_id IN NUMBER)
        RETURN VARCHAR2;


    FUNCTION get_legal_text (p_ComSeg1 IN VARCHAR2, p_ComSeg2 IN VARCHAR2, p_tax1 IN VARCHAR2, p_tax2 IN VARCHAR2, p_type IN VARCHAR2, p_lang IN VARCHAR2
                             , p_inv_header_id IN NUMBER)
        RETURN VARCHAR2;

    --CCR0007979 changes start
    FUNCTION get_ship_from (p_header_id IN NUMBER, p_attribute IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_ship_to (p_header_id IN NUMBER, p_attribute IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_eu_non_eu (p_country_code IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_ship_from_country_code (p_country_code IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_tax_codes (pv_org_id        IN VARCHAR2,
                            pv_tax_rate      IN VARCHAR2,
                            pv_ship_to       IN VARCHAR2,
                            pv_ship_to_reg   IN VARCHAR2,
                            pv_ship_from     IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_sold_to (p_OU IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_cust_classification (p_attribute IN VARCHAR2, p_type IN VARCHAR2, p_header_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_legal_text_mt (p_ComSeg1 IN VARCHAR2, p_ComSeg2 IN VARCHAR2, p_ComSeg3 IN VARCHAR2, p_tax1 IN VARCHAR2, p_tax2 IN VARCHAR2, p_type IN VARCHAR2
                                , p_lang IN VARCHAR2, p_inv_header_Id IN NUMBER, p_channel IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_tax_codes_vt_new (pv_template_type IN VARCHAR2, pv_language IN VARCHAR2, pv_seller_comp IN NUMBER, pv_buyer_company IN NUMBER, pv_final_sell_comp IN NUMBER, pv_channel IN VARCHAR2, pv_ship_to IN VARCHAR2, pv_ship_to_reg IN VARCHAR2, ps_ship_from IN VARCHAR2
                                   ,                                     --3.1
                                     pv_line_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_inco_codes_vt_new (pv_template_type IN VARCHAR2, pv_language IN VARCHAR2, pv_seller_comp IN NUMBER, pv_buyer_company IN NUMBER, pv_final_sell_comp IN NUMBER, pv_channel IN VARCHAR2, pv_ship_to IN VARCHAR2, pv_ship_to_reg IN VARCHAR2, ps_ship_from IN VARCHAR2
                                    , pd_invoice_date IN DATE -- Added as per CCR0009103
                                                             )
        RETURN VARCHAR2;

    FUNCTION get_tax_stamt_vt_new (pv_template_type IN VARCHAR2, pv_language IN VARCHAR2, pv_seller_comp IN NUMBER, pv_buyer_company IN NUMBER, pv_final_sell_comp IN NUMBER, pv_channel IN VARCHAR2
                                   , pv_ship_to IN VARCHAR2, pv_ship_to_reg IN VARCHAR2, ps_ship_from IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_so_line_id (pv_mmt_trx_id   IN VARCHAR2,
                             p_header_id     IN NUMBER)
        RETURN NUMBER;

    --CCR0007979 changes End
    FUNCTION get_so_ship_to (pv_mmt_trx_id   IN VARCHAR2,
                             p_header_id     IN NUMBER)
        RETURN VARCHAR2;                                                -- 3.0

    -- Added as per CCR0008507
    FUNCTION get_account_fnc (pn_inv_header_id   IN NUMBER,
                              pn_src_assign_id   IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_nonmat_tax_stmt (p_header_id NUMBER)
        RETURN VARCHAR2;
--END OF Change

END XXD_VT_ICS_INVOICES_PKG;
/
