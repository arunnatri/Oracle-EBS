--
-- XXDOPO_FIRST_SALE_UPLD  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOPO_FIRST_SALE_UPLD"
IS
    --first sale has precision matcing PO currency (poh.currency_code)
    --select currency_code, enabled_flag, precision from FND_CURRENCIES where currency_code = 'USD'
    PROCEDURE first_sale_integrator (p_po_number IN VARCHAR2,      --po_number
                                                              p_po_line_key IN VARCHAR2, --x.y.z where x=pol.line_num y=poll.shipment_num z=pda.distribution num
                                                                                         p_first_sale IN NUMBER, --price > 0 and < pol.unit price
                                                                                                                 p_vendor_name IN VARCHAR2, p_factory_site IN VARCHAR2, p_style_number IN VARCHAR2
                                     , p_color_code IN VARCHAR2);

    --Utility functions to fix/ reprocess records
    PROCEDURE reset_records (p_status OUT VARCHAR2, p_err_msg OUT VARCHAR2, p_rec_id IN NUMBER:= NULL, p_po_number IN VARCHAR2:= NULL, p_style IN VARCHAR2:= NULL, p_color IN VARCHAR2:= NULL
                             , p_source IN VARCHAR2);

    PROCEDURE process_records (p_status OUT VARCHAR2, p_err_msg OUT VARCHAR2, p_source IN VARCHAR2
                               , p_reprocess IN VARCHAR2:= 'N');
END;
/
