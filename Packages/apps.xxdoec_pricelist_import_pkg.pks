--
-- XXDOEC_PRICELIST_IMPORT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_PRICELIST_IMPORT_PKG"
AS
    PROCEDURE xxdoex_do_delete_table;

    PROCEDURE xxdoec_ins_pricelists_to_temp (p_style VARCHAR2, p_color VARCHAR2, p_price NUMBER);

    PROCEDURE xxdoec_do_pricelist_import (p_price_list_id NUMBER);
END XXDOEC_PRICELIST_IMPORT_PKG;
/
