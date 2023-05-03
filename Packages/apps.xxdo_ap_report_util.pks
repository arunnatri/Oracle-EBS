--
-- XXDO_AP_REPORT_UTIL  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_AP_REPORT_UTIL"
IS
    --  Purpose: Briefly explain the functionality of the package
    --  Active Vendors that have NO AP Invoice or Purchase Order History since :through_date - In this case we're using 31-MAR-2008
    --  Where these vendors also have NO invoices or POs that are open.
    --  Change for Defect:
    --  Exclude any suppliers for which any activities (PO, Invoice, Payment) has happened after the cutoff date irrespective of status
    --  MODIFICATION HISTORY
    --  Person                      Version         Date                    Comments
    ---------                   -------         ------------            -----------------------------------------
    --  Shibu                       V1.0            1/11/11
    --  Srinath                     V1.1            02-OCT-2014             Exclude any suppliers for which any activities (PO, Invoice, Payment) has happened
    --after the cutoff date irrespective of status
    --  Srinath                     V1.2            18-May-2015             Retrofit for BT project
    --  ---------                   ------          -----------             ------------------------------------------
    PROCEDURE run_active_vendors (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_through_date IN VARCHAR2, p_upd_yn IN VARCHAR2 DEFAULT 'N', p_level IN VARCHAR2, p_is_level_site IN VARCHAR2, p_operating_unit IN NUMBER, p_incl_supplier_type IN VARCHAR2, p_incl_sup_type_passed IN NUMBER
                                  , p_excl_supplier_type IN VARCHAR2);
END;
/
