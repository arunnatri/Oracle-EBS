--
-- XXDOAR044_SHIPTOUPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR044_SHIPTOUPD_PKG"
AS
    /***********************************************************************************
     *$header : *
     * *
     * AUTHORS : Showkath Ali V *
     * *
     * PURPOSE : To update the "ship to" at invoice header level Nordstrom, Belk *
     * *
     * PARAMETERS : *
     * *
     * *
     * Assumptions : *
     * *
     * *
     * History *
     * Vsn   Change Date Changed By         Change Description *
     * ----- ----------- ------------------ ------------------------------------- *
     * 1.0   27-OCT-2015 Showkath Ali V     Initial Creation *
     * *
     *********************************************************************************/
    PROCEDURE update_shiptos (errbuf OUT VARCHAR2, retcode OUT VARCHAR2)
    IS
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                           'Ship To Update program start....: ');

        UPDATE apps.ra_customer_trx_all rcta
           SET rcta.ship_to_site_use_id   =
                   (SELECT MAX (rctla.ship_to_site_use_id)
                      FROM apps.ra_customer_trx_lines_all rctla
                     WHERE rctla.customer_trx_id = rcta.customer_trx_id)
         WHERE customer_trx_id IN
                   (SELECT DISTINCT rcta.customer_trx_id
                      FROM apps.ra_customer_trx_all rcta, apps.ra_cust_trx_types_all rctta, apps.hz_cust_accounts hca,
                           apps.hz_parties hp
                     WHERE     rctta.org_id = rcta.org_id
                           AND rctta.cust_trx_type_id = rcta.cust_trx_type_id
                           AND rctta.TYPE = 'INV'
                           AND rcta.interface_header_context = 'ORDER ENTRY'
                           AND rcta.trx_date >= TO_DATE ('01-JUN-2009')
                           AND rcta.bill_to_customer_id = hca.cust_account_id
                           AND hca.party_id = hp.party_id
                           AND UPPER (hp.party_name) IN
                                   (SELECT meaning
                                      FROM apps.fnd_lookup_values a
                                     WHERE     lookup_type =
                                               'XXDOAR044_CUSTOMERS'
                                           AND LANGUAGE = 'US'
                                           AND NVL (enabled_flag, 'X') = 'Y'
                                           AND SYSDATE >=
                                               NVL (start_date_active,
                                                    SYSDATE)
                                           AND SYSDATE <
                                                 NVL (end_date_active,
                                                      SYSDATE)
                                               + 1)
                           AND rcta.ship_to_site_use_id IS NULL);

        FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                           'Number of records Updated: ' || SQL%ROWCOUNT);


        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'In Exception: Unable to update' || SQLERRM);
    END;
END;
/
