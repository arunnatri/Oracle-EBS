--
-- XXDOAR_INVDETREG_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAR_INVDETREG_PKG"
IS
    --------------------------------------------------------------------------------
    -- Created By              : Vijaya Reddy ( Suneara Technologies )
    -- Creation Date           : 14-SEP-2011
    -- File Name               : XXDOAR019
    -- Work Order Num          : Invoice Details Register - Deckers
    --                                      Incident INC0094675
    --                                      Enhancement ENHC0010241
    -- Description             :
    -- Latest Version          : 2.3
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name            Remarks
    -- =============================================================================
    -- 14-SEP-2011        1.0         Vijaya Reddy         Initial development.
    --01-MAY-2012         2.1         Shibu Alex
    --9-Jul-2013          2.2         Murali Bachina       Added Employee Order Classification
    --11-Sep-2013         2.3         Madhav Dhurjaty      Added function get_vat_number and new field zip_code
    --11-JAN-2015         2.4         BT Technology Team   Retrofitted the program
    --12-Nov-2015         3           BT Technology Team   Defect UAT2 570
    --26-NOV-2018         4.0         Madhav Dhurjaty      Modified for CCR0007628 - IDR Delivery
    -------------------------------------------------------------------------------
    FUNCTION get_invoice_gl_code (p_customer_trx_id   IN NUMBER,
                                  p_style             IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_vat_number (p_customer_id IN NUMBER, pn_ou IN NUMBER)
        RETURN VARCHAR2;

    PROCEDURE intl_invoices (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_from_date IN VARCHAR2:= NULL, p_to_date IN VARCHAR2:= NULL, pv_show_land_cost IN VARCHAR2, pv_custom_cost IN VARCHAR2, pv_regions IN VARCHAR2, pn_region_ou IN VARCHAR2, pn_price_list IN NUMBER, pn_inv_org IN NUMBER, pn_elim_org IN NUMBER, pv_brand IN VARCHAR2
                             , pv_disc_len IN NUMBER, pv_send_to_bl IN VARCHAR2, --Added for CCR0007628
                                                                                 pv_file_path IN VARCHAR2 --Added for CCR0007628
                                                                                                         );

    PROCEDURE pending_edi_invoices (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, v_send_none_msg IN VARCHAR2:= 'N');

    PROCEDURE new_accounts (errbuf               OUT VARCHAR2,
                            retcode              OUT VARCHAR2,
                            v_send_none_msg   IN     VARCHAR2 := 'N');

    FUNCTION get_price (pn_so_line_id   VARCHAR2,
                        pn_org_id       NUMBER,
                        pv_col          VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_mmt_cost (pn_interface_line_attribute6 VARCHAR2, pn_interface_line_attribute7 VARCHAR2, pn_organization_id NUMBER
                           , pn_sob_id NUMBER, -- Added by BT Tech Team for defect# 570 on 17-Nov-15
                                               pv_detail IN VARCHAR)
        RETURN NUMBER;

    FUNCTION GET_PARENT_ORD_DET (PN_SO_LINE_ID   NUMBER,
                                 PN_ORG_ID       NUMBER,
                                 PV_COL          VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_cic_item_cost (pn_warehouse_id NUMBER, pn_inventory_item_id NUMBER, pv_custom_cost IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION GET_FACTORY_INVOICE (p_Cust_Trx_ID   IN VARCHAR2,
                                  p_Style         IN VARCHAR2)
        RETURN VARCHAR2;

    --Start Changes by BT tech team on 13-Nov-15 for defect# 570
    FUNCTION get_tax_details (p_trx_id        IN NUMBER,
                              p_trx_line_id   IN NUMBER,
                              p_mode          IN VARCHAR2)
        RETURN VARCHAR2;

    --End Changes by BT tech team on 13-Nov-15 for defect# 570
    --Start Changes by BT tech team on 18-Nov-15 for defect# 570
    FUNCTION get_account (p_trx_id       IN NUMBER,
                          p_sob_id       IN NUMBER,
                          p_gl_dist_id   IN NUMBER)
        RETURN VARCHAR2;

    --End Changes by BT tech team on 18-Nov-15 for defect# 570

    FUNCTION XXD_REMOVE_JUNK_CHAR_FNC (p_input IN VARCHAR2)
        RETURN VARCHAR2;
END;
/
