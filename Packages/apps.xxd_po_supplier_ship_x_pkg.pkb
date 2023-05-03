--
-- XXD_PO_SUPPLIER_SHIP_X_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_SUPPLIER_SHIP_X_PKG"
IS
    /******************************************************************************
    Date Created    Version      AUTHOR              REMARKS
    -------------------------------------------------------------------------------
    14-Sep-2017     1.0        ARUN N MURTHY        This is package is basically used
                                                   for XXD_SUPP_PO_SHIPMENT.fmb
    ********************************************************************************/

    FUNCTION xxd_return_xdock_customer (pn_so_number VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_cust_name   apps.hz_parties.party_name%TYPE;
    BEGIN
        SELECT MAX (hp.party_name)
          INTO lv_cust_name
          FROM hz_parties hp, hz_cust_accounts_all hca, oe_order_headers_all ooh
         WHERE     1 = 1
               AND ooh.order_number = TO_NUMBER (pn_so_number)
               AND ooh.sold_to_org_id = hca.cust_account_id
               AND hca.party_id = hp.party_id;

        RETURN lv_cust_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;
END;
/
