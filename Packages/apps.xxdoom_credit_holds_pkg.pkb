--
-- XXDOOM_CREDIT_HOLDS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDOOM_CREDIT_HOLDS_PKG
AS
    /******************************************************************************
       NAME: XXDOOM_CREDIT_HOLDS_PKG
       PURPOSE:Credit Holds Report - Deckers
       Short Name : DO_OEXOECCH_NEW
       INCIDENT NUMBER : INC0101695

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        12/30/2011    Vijaya Reddy       1. Created this package for (INCIDENT : INC0101695 )
       1.1        05-MAY-2015  BT Technology Team  Retrofit for BT project
    ******************************************************************************/

    -------------------------------------------------------------------------------



    FUNCTION get_collname_for_crholds (pv_order_number VARCHAR2, pn_cust_acct NUMBER, pn_bill_to NUMBER
                                       , pv_brand VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_coll_name   VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT NVL (ac.name, 'None')
              INTO lv_coll_name
              FROM --apps.ar_customer_profiles hcp,--commeneted by BT Technoly Team on 05-MAY-2015 V 1.1
                   apps.hz_customer_profiles hcp, --Added by BT Technology Team on 05-MAY-2015 V 1.1
                                                  hz_cust_accounts hca, apps.ar_collectors ac
             WHERE     hcp.collector_id = ac.collector_id
                   /*Start Changes by BT Technology Team on 05-MAY-2015 - V 1.1 */
                   -- AND hcp.customer_id<> 4712
                   AND hcp.cust_account_id != hca.cust_account_id
                   AND hca.attribute_category = 'Person'
                   AND hca.attribute18 IS NOT NULL
                   /*End Changes by BT Technology Team on 05-MAY-2015 - V 1.1 */
                   AND hcp.status = 'A'
                   --AND hcp.customer_id = pn_cust_acct
                   AND hcp.cust_account_id = pn_cust_acct
                   AND hcp.site_use_id = pn_bill_to;

            IF lv_coll_name != 'None' OR lv_coll_name IS NOT NULL
            THEN
                RETURN lv_coll_name;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_coll_name   := 'None';
        END;

        IF lv_coll_name = 'None' OR lv_coll_name IS NULL
        THEN
            BEGIN
                SELECT NVL (ac.name, 'None')
                  INTO lv_coll_name
                  FROM --apps.ar_customer_profiles hcp,--commeneted by BT Technoly Team on 05-MAY-2015 V 1.1
                       apps.hz_customer_profiles hcp, --Added by BT Technology Team on 05-MAY-2015 V 1.1
                                                      hz_cust_accounts hca, --Added by BT Technology Team on 05-MAY-2015 V 1.1
                                                                            apps.ar_collectors ac
                 WHERE     hcp.collector_id = ac.collector_id
                       /*Start Changes by BT Technology Team on 05-MAY-2015 - V 1.1 */
                       --AND hcp.customer_id<> 4712
                       AND hcp.cust_account_id != hca.cust_account_id
                       AND hca.attribute_category = 'Person'
                       AND hca.attribute18 IS NOT NULL
                       /*End Changes by BT Technology Team on 05-MAY-2015 - V 1.1 */
                       AND hcp.status = 'A'
                       --AND hcp.customer_id =  pn_cust_acct --commeneted by BT Technoly Team on 05-MAY-2015 V 1.1
                       AND hcp.cust_account_id = pn_cust_acct --Added by BT Technology Team on 05-MAY-2015 V 1.1
                       AND hcp.site_use_id IS NULL;


                RETURN lv_coll_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN 'None';
            END;
        ELSE
            RETURN 'None';
        END IF;

        RETURN lv_coll_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'None';
    END;
END XXDOOM_CREDIT_HOLDS_PKG;
/
