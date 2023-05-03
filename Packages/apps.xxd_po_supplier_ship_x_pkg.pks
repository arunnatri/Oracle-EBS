--
-- XXD_PO_SUPPLIER_SHIP_X_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_SUPPLIER_SHIP_X_PKG"
IS
    /******************************************************************************
    Date Created    Version      AUTHOR              REMARKS
    -------------------------------------------------------------------------------
    14-Sep-2017     1.0        ARUN N MURTHY        This is package is basically used
                                                   for XXD_SUPP_PO_SHIPMENT.fmb
    ********************************************************************************/

    FUNCTION xxd_return_xdock_customer (pn_so_number VARCHAR2)
        RETURN VARCHAR2;
END;
/
