--
-- XXD_PRINT_TRX_DEC_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PRINT_TRX_DEC_PKG"
AS
    /************************************************************************************************
    * Package         : XXD_PRINT_TRX_DEC_PKG
    * Author          : Infosys
    * Created         : 07-NOV-2016
    * Program Name    : Print Transactions - Deckers
    * Description     : Wrapper Program  to control output file size for OPP - ENHC0012783
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    * Date         Developer     Version    Description
    *-----------------------------------------------------------------------------------------------
    * 07-NOV-2016  Infosys       1.0        Initial Version for Changes to control output
    *                                       file size for OPP - ENHC0012783
    * 24-NOV-2016  Infosys       2.0       a.Fix for submitting bursting program when number of child request is more than 1
    *                                      b.Fix to add Invoice Number from and Invocie Number to in the cursor query
    * 25-AUG-2017  Madhav D      1.1        Added creation date parameters for CCR0005936
    ************************************************************************************************/
    PROCEDURE print_trx_dec_main (errbuf IN OUT VARCHAR2, retcode IN OUT NUMBER, p_org_id IN NUMBER, p_trx_class IN VARCHAR2, p_creation_date_low IN VARCHAR2, --Added for CCR0005936
                                                                                                                                                               p_creation_date_high IN VARCHAR2, --Added for CCR0005936
                                                                                                                                                                                                 p_trx_date_low IN VARCHAR2, p_trx_date_high IN VARCHAR2, p_customer_id IN NUMBER, p_cust_bill_to IN NUMBER, p_invoice_num_from IN VARCHAR2, p_invoice_num_to IN VARCHAR2, p_cust_num_from IN VARCHAR2, p_cust_num_to IN VARCHAR2, p_brand IN VARCHAR2, p_order_by IN VARCHAR2, p_re_transmit_flag IN VARCHAR2, p_printer IN VARCHAR2, p_copies IN NUMBER, p_cc_email_id IN VARCHAR2, p_max_limit IN NUMBER
                                  , p_max_sets IN NUMBER)
    IS
        --Cursor to get the customers
        l_total_rows     NUMBER;
        v_fromdate       DATE;
        v_todate         DATE;
        v_cre_fromdate   DATE;                          --Added for CCR0005936
        v_cre_todate     DATE;                          --Added for CCR0005936

        CURSOR c_customer IS
            SELECT bill.customer_name cust_name, bill.customer_number cust_number
              FROM apps.ra_customer_trx_all rct,
                   apps.ar_payment_schedules_all ps,
                   (SELECT c.cust_account_id customer_id, u.site_use_id site_use_id, c.account_number customer_number,
                           party.party_name customer_name, loc.address1 address1, loc.address2 address2,
                           loc.address3 address3, loc.address4 address4, loc.city city,
                           NVL (loc.state, loc.province) state, loc.postal_code postal_code, loc.country country,
                           terr.territory_short_name country_name, u.tax_reference site_tax_reference, party.tax_reference cust_tax_reference,
                           NVL (u.tax_reference, party.tax_reference) tax_reference, c.CUSTOMER_CLASS_CODE, party_site.attribute1 inv_trans_method,
                           party_site.attribute2 cm_trans_method, party_site.attribute3 dm_trans_method
                      FROM hz_cust_accounts c, hz_parties party, hz_cust_acct_sites_all a,
                           hz_party_sites party_site, hz_locations loc, hz_cust_site_uses_all u,
                           apps.fnd_territories_tl terr
                     WHERE     u.cust_acct_site_id = a.cust_acct_site_id -- address_id
                           AND a.party_site_id = party_site.party_site_id
                           AND loc.location_id = party_site.location_id
                           AND c.party_id = party.party_id
                           AND loc.country = terr.territory_code
                           AND terr.language = USERENV ('LANG')) bill,
                   (SELECT c.cust_account_id customer_id, u.site_use_id site_use_id, c.account_number customer_number,
                           NVL (a.attribute1, party.party_name) customer_name, loc.address1 address1, loc.address2 address2,
                           loc.address3 address3, loc.address4 address4, loc.city city,
                           NVL (loc.state, loc.province) state, loc.postal_code postal_code, loc.country country,
                           terr.territory_short_name country_name, u.tax_reference site_tax_reference, party.tax_reference cust_tax_reference,
                           NVL (u.tax_reference, party.tax_reference) tax_reference
                      FROM hz_cust_accounts c, hz_parties party, hz_cust_acct_sites_all a,
                           hz_party_sites party_site, hz_locations loc, hz_cust_site_uses_all u,
                           apps.fnd_territories_tl terr
                     WHERE     u.cust_acct_site_id = a.cust_acct_site_id -- address_id
                           AND a.party_site_id = party_site.party_site_id
                           AND loc.location_id = party_site.location_id
                           AND c.party_id = party.party_id
                           AND loc.country = terr.territory_code
                           AND terr.language = USERENV ('LANG')) ship,
                   (SELECT acct_site.cust_acct_site_id address_id, loc.address1 address1, loc.address2 address2,
                           loc.address3 address3, loc.ADDRESS4 address4, loc.CITY city,
                           NVL (loc.STATE, loc.province) state, loc.POSTAL_CODE postal_code, loc.COUNTRY country,
                           terr.territory_short_name country_name, party_site.addressee, acct_site.attribute2 contact_number
                      FROM hz_cust_acct_sites_all acct_site, hz_party_sites party_site, hz_locations loc,
                           apps.fnd_territories_tl terr
                     WHERE     acct_site.party_site_id =
                               party_site.party_site_id
                           AND loc.location_id = party_site.location_id
                           AND loc.country = terr.territory_code
                           AND terr.language = USERENV ('LANG')) remit,
                   (SELECT F.freight_code, description
                      FROM APPS.ORG_FREIGHT F, APPS.OE_SYSTEM_PARAMETERS_ALL OSP
                     WHERE     F.ORGANIZATION_ID = OSP.MASTER_ORGANIZATION_ID
                           AND OSP.ORG_ID = p_org_id) ship_via,
                   apps.ra_cust_trx_types_all tt,
                   apps.ra_batch_sources_all abc,
                   apps.ar_lookups arl,
                   apps.ra_terms term,
                   apps.jtf_rs_salesreps rep
             WHERE     rct.bill_to_customer_id = bill.customer_id
                   AND rct.bill_to_site_use_id = bill.site_use_id
                   AND rct.ship_to_customer_id = ship.customer_id(+)
                   AND rct.ship_to_site_use_id = ship.site_use_id(+)
                   AND rct.cust_trx_type_id = tt.cust_trx_type_id
                   AND rct.batch_source_id = abc.batch_source_id(+)
                   AND rct.org_id = abc.org_id(+)
                   AND rct.org_id = tt.org_id
                   AND tt.TYPE = arl.lookup_code
                   AND arl.lookup_type = 'INV/CM'
                   AND rct.customer_trx_id = ps.customer_trx_id
                   AND rct.term_id = term.term_id(+)
                   AND rct.primary_salesrep_id = rep.salesrep_id(+)
                   AND rct.org_id = rep.org_id(+)
                   AND APPS.XXDO_AR_INVOICE_PRINT.remit_to_address_id (
                           rct.customer_trx_id) =
                       remit.address_id(+)
                   AND rct.ship_via = ship_via.freight_code(+)
                   AND rct.printing_option = 'PRI'
                   AND ps.number_of_due_dates = 1
                   AND NOT EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values flv
                             WHERE     1 = 1
                                   AND flv.LANGUAGE = USERENV ('LANG')
                                   AND flv.lookup_type =
                                       'XXDOAR035_EXCLUDED_TRX_TYPES'
                                   AND flv.meaning = tt.name
                                   AND flv.description = tt.TYPE
                                   AND DECODE (
                                           SIGN (
                                                 SYSDATE
                                               - NVL (flv.start_date_active,
                                                      SYSDATE - 1)),
                                           -1, 'INACTIVE',
                                           DECODE (
                                               SIGN (
                                                     NVL (
                                                         flv.end_date_active,
                                                         SYSDATE + 1)
                                                   - SYSDATE),
                                               -1, 'INACTIVE',
                                               DECODE (flv.enabled_flag,
                                                       'N', 'INACTIVE',
                                                       'ACTIVE'))) =
                                       'ACTIVE')
                   AND rct.bill_to_customer_id =
                       NVL (p_customer_id, rct.bill_to_customer_id)
                   AND rct.bill_to_site_use_id =
                       NVL (p_cust_bill_to, rct.bill_to_site_use_id)
                   AND rct.org_id = p_org_id
                   AND rct.attribute5 = NVL (p_brand, rct.attribute5)
                   AND tt.TYPE = NVL (p_trx_class, tt.TYPE)
                   AND rct.trx_date >=
                       NVL (TO_CHAR (v_fromdate, 'DD-MON-YYYY'),
                            rct.trx_date)
                   AND rct.trx_date <=
                       NVL (TO_CHAR (v_todate, 'DD-MON-YYYY'), rct.trx_date)
                   AND rct.creation_date >=
                       NVL (TO_CHAR (v_cre_fromdate, 'DD-MON-YYYY'),
                            rct.creation_date)          --Added for CCR0005936
                   AND rct.creation_date <
                       NVL (TO_CHAR (v_cre_todate + 1, 'DD-MON-YYYY'),
                            rct.creation_date)          --Added for CCR0005936
                   /*Start of Change as part of Ver 2.0 on 24-Nov-2016*/
                   AND rct.trx_number >=
                       NVL (p_invoice_num_from, rct.trx_number)
                   AND rct.trx_number <=
                       NVL (p_invoice_num_to, rct.trx_number)
                   /*Start of Change as part of Ver 2.0 on 24-Nov-2016*/
                   AND bill.customer_number >=
                       NVL (p_cust_num_from, bill.customer_number)
                   AND bill.customer_number <=
                       NVL (p_cust_num_to, bill.customer_number)
                   AND rct.printing_pending =
                       DECODE (p_re_transmit_flag, 'N', 'Y', 'N');

        --Local Variable Declaration
        l_count          NUMBER := 0;
        lp_request_id    NUMBER;
    BEGIN
        --
        v_fromdate       := FND_CONC_DATE.STRING_TO_DATE (p_trx_date_low);
        v_todate         := FND_CONC_DATE.STRING_TO_DATE (p_trx_date_high);
        --
        ----Added for CCR0005936--Start
        v_cre_fromdate   :=
            FND_CONC_DATE.STRING_TO_DATE (p_creation_date_low);
        v_cre_todate     :=
            FND_CONC_DATE.STRING_TO_DATE (p_creation_date_high);
        ----Added for CCR0005936--End
        lp_request_id    := NULL;
        --
        --
        fnd_file.put_line (
            fnd_file.LOG,
            '**************************Input Parameters**************************');
        fnd_file.put_line (fnd_file.LOG, 'p_org_id            :' || p_org_id);
        fnd_file.put_line (fnd_file.LOG,
                           'p_trx_class         :' || p_trx_class);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_creation_date_low      :' || p_creation_date_low); --Added for CCR0005936
        fnd_file.put_line (
            fnd_file.LOG,
            'p_creation_date_high     :' || p_creation_date_high); --Added for CCR0005936
        fnd_file.put_line (fnd_file.LOG,
                           'p_trx_date_low      :' || p_trx_date_low);
        fnd_file.put_line (fnd_file.LOG,
                           'p_trx_date_high     :' || p_trx_date_high);
        fnd_file.put_line (fnd_file.LOG,
                           'p_customer_id       :' || p_customer_id);
        fnd_file.put_line (fnd_file.LOG,
                           'p_cust_bill_to      :' || p_cust_bill_to);
        fnd_file.put_line (fnd_file.LOG,
                           'p_invoice_num_from  :' || p_invoice_num_from);
        fnd_file.put_line (fnd_file.LOG,
                           'p_invoice_num_to    :' || p_invoice_num_to);
        fnd_file.put_line (fnd_file.LOG,
                           'p_cust_num_from     :' || p_cust_num_from);
        fnd_file.put_line (fnd_file.LOG,
                           'p_cust_num_to       :' || p_cust_num_to);
        fnd_file.put_line (fnd_file.LOG, 'p_brand             :' || p_brand);
        fnd_file.put_line (fnd_file.LOG,
                           'p_order_by          :' || p_order_by);
        fnd_file.put_line (fnd_file.LOG,
                           'p_re_transmit_flag  :' || p_re_transmit_flag);
        fnd_file.put_line (fnd_file.LOG,
                           'p_printer           :' || p_printer);
        fnd_file.put_line (fnd_file.LOG, 'p_copies            :' || p_copies);
        fnd_file.put_line (fnd_file.LOG,
                           'p_cc_email_id       :' || p_cc_email_id);
        fnd_file.put_line (fnd_file.LOG,
                           'p_max_limit         :' || p_max_limit);
        fnd_file.put_line (fnd_file.LOG,
                           'p_max_sets          :' || p_max_sets);
        --
        fnd_file.put_line (fnd_file.LOG,
                           'v_fromdate         :' || v_fromdate);
        fnd_file.put_line (fnd_file.LOG, 'v_todate           :' || v_todate);
        --
        --
        fnd_file.put_line (fnd_file.LOG,
                           'v_cre_fromdate         :' || v_cre_fromdate); --Added for CCR0005936
        fnd_file.put_line (fnd_file.LOG,
                           'v_cre_todate           :' || v_cre_todate); --Added for CCR0005936

        --
        FOR cust_rec IN c_customer
        LOOP
            l_count        := l_count + 1;
            l_total_rows   := c_customer%ROWCOUNT;
            fnd_file.put_line (
                fnd_file.LOG,
                'Total record fetched from cursor query: ' || l_total_rows);

            BEGIN
                INSERT INTO XXD_PRINT_TRX_DEC_STG
                     VALUES (cust_rec.cust_name, cust_rec.cust_number, fnd_global.user_id
                             , SYSDATE, FND_GLOBAL.CONC_REQUEST_ID);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while inserting data into table -XXD_INV_PRINT_SELECT_US_STG: '
                        || SQLERRM);
            END;
        END LOOP;

        --
        --
        fnd_file.put_line (fnd_file.LOG, 'Total Records Loaded' || l_count);
        COMMIT;
        lp_request_id    := FND_GLOBAL.CONC_REQUEST_ID;
        --
        --
        Submit_print_trx_dec_child (
            p_org_id               => p_org_id,
            p_trx_class            => p_trx_class,
            p_creation_date_low    => p_creation_date_low, --Added for CCR0005936
            p_creation_date_high   => p_creation_date_high, --Added for CCR0005936
            p_trx_date_low         => p_trx_date_low,
            p_trx_date_high        => p_trx_date_high,
            p_customer_id          => p_customer_id,
            p_cust_bill_to         => p_cust_bill_to,
            p_invoice_num_from     => p_invoice_num_from,
            p_invoice_num_to       => p_invoice_num_to,
            p_cust_num_from        => p_cust_num_from,
            p_cust_num_to          => p_cust_num_to,
            p_brand                => p_brand,
            p_order_by             => p_order_by,
            p_re_transmit_flag     => p_re_transmit_flag,
            p_printer              => p_printer,
            p_copies               => p_copies,
            p_cc_email_id          => p_cc_email_id,
            p_max_limit            => p_max_limit,
            p_max_sets             => p_max_sets,
            p_request_id           => lp_request_id);
    --
    --
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error in print_trx_dec_main procedure ::' || SQLERRM);
    END print_trx_dec_main;

    --
    --
    PROCEDURE Submit_print_trx_dec_child (p_org_id IN NUMBER, p_trx_class IN VARCHAR2, p_creation_date_low IN VARCHAR2, --Added for CCR0005936
                                                                                                                        p_creation_date_high IN VARCHAR2, --Added for CCR0005936
                                                                                                                                                          p_trx_date_low IN VARCHAR2, p_trx_date_high IN VARCHAR2, p_customer_id IN NUMBER, p_cust_bill_to IN NUMBER, p_invoice_num_from IN VARCHAR2, p_invoice_num_to IN VARCHAR2, p_cust_num_from IN VARCHAR2, p_cust_num_to IN VARCHAR2, p_brand IN VARCHAR2, p_order_by IN VARCHAR2, p_re_transmit_flag IN VARCHAR2, p_printer IN VARCHAR2, p_copies IN NUMBER, p_cc_email_id IN VARCHAR2
                                          , p_max_limit IN NUMBER, p_max_sets IN NUMBER, p_request_id IN NUMBER)
    IS
        --Local Variable Declaration
        l_request_id      NUMBER;
        l_layout          BOOLEAN;
        l_phase           VARCHAR2 (100);
        l_status          VARCHAR2 (100);
        l_dev_phase       VARCHAR2 (100);
        l_dev_status      VARCHAR2 (100);
        l_message         VARCHAR2 (4000);
        l_return          BOOLEAN;
        l_count           NUMBER := 0;
        l_cnt             NUMBER := 1;
        l_num_rec_count   NUMBER := 0;
        l_totl_rec        NUMBER;
        l_party_id_low    NUMBER;
        l_party_id_high   NUMBER;
        l_cust_num_from   VARCHAR2 (30);
        l_cust_num_to     VARCHAR2 (30);
        l_request_cnt     NUMBER := 1;
        l_loop_cnt        NUMBER := 0;
        v_sub_req         NUMBER;
        v_end_cust_name   l_end_cust_name;
        v_start_cust_no   l_start_cust_no;
        v_end_cust_no     l_end_cust_no;
        v_wait_count      l_wait_count;
        lc_boolean1       BOOLEAN;
        lc_boolean2       BOOLEAN;
        l_org_id          NUMBER;

        --Cursor to get count of customer
        CURSOR cur_acct IS
              SELECT account_number, COUNT (1) acct_cnt
                FROM (  SELECT DISTINCT account_number
                          FROM XXD_PRINT_TRX_DEC_STG
                         WHERE request_id = p_request_id
                      ORDER BY account_number) cust
            GROUP BY account_number
            ORDER BY account_number;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inside Submit_print_trx_dec_child procedure ');

        --
        --
        BEGIN
            v_start_cust_no.delete;
            v_end_cust_no.delete;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Table Type Error Message' || SQLERRM);
        END;

        --
        --

        l_totl_rec   := NULL;

        BEGIN
              SELECT COUNT (1)
                INTO l_totl_rec
                FROM (  SELECT DISTINCT account_number
                          FROM XXD_PRINT_TRX_DEC_STG
                         WHERE request_id = p_request_id
                      ORDER BY account_number) cust
            ORDER BY account_number;

            fnd_file.put_line (fnd_file.LOG, 'Records count:' || l_totl_rec);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error in derivation of l_totl_rec' || SQLERRM);
        END;

        BEGIN
            FOR cur_acct_rec IN cur_acct
            LOOP
                fnd_file.put_line (fnd_file.LOG, 'After cur_acct For Loop');
                l_num_rec_count   := l_num_rec_count + 1;
                fnd_file.put_line (fnd_file.LOG,
                                   'l_num_rec_count:' || l_num_rec_count);

                IF l_count = 0
                THEN
                    v_start_cust_no (l_cnt)   := cur_acct_rec.account_number;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'v_start_cust_no ('
                        || l_cnt
                        || '):'
                        || v_start_cust_no (l_cnt));
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'l_count for  v_start_cust_no:' || l_num_rec_count);
                l_count           := l_count + cur_acct_rec.acct_cnt;
                fnd_file.put_line (fnd_file.LOG,
                                   'l_num_rec_count:' || l_num_rec_count);
                fnd_file.put_line (fnd_file.LOG, 'l_count:' || l_count);
                fnd_file.put_line (fnd_file.LOG, 'l_totl_rec:' || l_totl_rec);

                IF l_count >= p_max_limit OR l_num_rec_count = l_totl_rec
                THEN
                    v_end_cust_no (l_cnt)   := cur_acct_rec.account_number;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'v_end_cust_no ('
                        || l_cnt
                        || '):'
                        || v_end_cust_no (l_cnt));
                    l_count                 := 0;
                    l_cnt                   := l_cnt + 1;
                    l_loop_cnt              := l_loop_cnt + 1;
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                FND_file.put_line (
                    fnd_file.LOG,
                    'Before assigning value error message' || SQLERRM);
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'Last Value in v_start_cust_no.LAST Variable:' || v_start_cust_no.LAST);
        fnd_file.put_line (fnd_file.LOG, 'l_loop_cnt:' || l_loop_cnt);

        --
        --
        FOR l_cust IN 1 .. l_loop_cnt
        LOOP
            FND_file.put_line (fnd_file.LOG, 'Enter loop');

            BEGIN
                FND_file.put_line (fnd_file.LOG, 'Before layout selection');
                l_org_id   := NULL;

                --
                --
                SELECT organization_id
                  INTO l_org_id
                  FROM hr_operating_units
                 WHERE NAME = 'Deckers Asia Pac Ltd OU';

                --
                --
                IF p_org_id = l_org_id
                THEN
                    mo_global.set_policy_context ('S', l_org_id);

                    IF p_trx_class = 'DM'
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           'Adding Excel Layout.... ');
                        lc_boolean1   :=
                            fnd_request.add_layout (
                                template_appl_name   => 'XXDO',
                                template_code        => 'XXDOAR035_APAC_DM',
                                template_language    => 'en',
                                template_territory   => 'US',
                                output_format        => 'PDF');
                    ELSIF p_trx_class = 'CM'
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           'Adding Text Layout..... ');
                        lc_boolean2   :=
                            fnd_request.add_layout (
                                template_appl_name   => 'XXDO',
                                template_code        => 'XXDOAR035_APAC_CM',
                                template_language    => 'en',
                                template_territory   => 'US',
                                output_format        => 'PDF');
                    ELSE
                        fnd_file.put_line (fnd_file.LOG,
                                           'Adding Text Layout..... ');
                        lc_boolean2   :=
                            fnd_request.add_layout (
                                template_appl_name   => 'XXDO',
                                template_code        => 'XXDOAR035_APAC_INV',
                                template_language    => 'en',
                                template_territory   => 'US',
                                output_format        => 'PDF');
                    END IF;
                ELSE
                    IF p_trx_class = 'DM'
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           'Adding Excel Layout.... ');
                        lc_boolean1   :=
                            fnd_request.add_layout (
                                template_appl_name   => 'XXDO',
                                template_code        => 'XXDOAR035_DM',
                                template_language    => 'en',
                                template_territory   => 'US',
                                output_format        => 'PDF');
                    ELSIF p_trx_class = 'CM'
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           'Adding Text Layout..... ');
                        lc_boolean2   :=
                            fnd_request.add_layout (
                                template_appl_name   => 'XXDO',
                                template_code        => 'XXDOAR035_CM',
                                template_language    => 'en',
                                template_territory   => 'US',
                                output_format        => 'PDF');
                    ELSE
                        mo_global.set_policy_context ('S', p_org_id);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Adding Text Layout..... ');
                        lc_boolean2   :=
                            fnd_request.add_layout (
                                template_appl_name   => 'XXDO',
                                template_code        => 'XXDOAR035_INV',
                                template_language    => 'en',
                                template_territory   => 'US',
                                output_format        => 'PDF');
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error in choosing layout' || SQLERRM);
            END;

            --
            --
            l_party_id_low    := NULL;
            l_party_id_high   := NULL;
            l_cust_num_from   := NULL;
            l_cust_num_to     := NULL;
            fnd_file.put_line (fnd_file.LOG, 'Deriving Customer number:');

            BEGIN
                --
                --

                SELECT a.party_id, b.account_number
                  INTO l_party_id_low, l_CUST_NUM_FROM
                  FROM hz_parties a, hz_cust_accounts b
                 WHERE     a.party_id = b.party_id
                       AND account_number = v_start_cust_no (l_cust)
                       AND ROWNUM = 1;                               --by sree

                fnd_file.put_line (
                    fnd_file.LOG,
                       'v_start_cust_no ('
                    || l_cust
                    || '):'
                    || v_start_cust_no (l_cust));

                SELECT a.party_id, b.account_number
                  INTO l_party_id_high, l_CUST_NUM_TO
                  FROM hz_parties a, hz_cust_accounts b
                 WHERE     a.party_id = b.party_id
                       AND account_number = v_end_cust_no (l_cust)
                       AND ROWNUM = 1;                               --by sree

                fnd_file.put_line (
                    fnd_file.LOG,
                       'v_end_cust_no ('
                    || l_cust
                    || '):'
                    || v_end_cust_no (l_cust));
            --
            --
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'No Data found for party name');
            END;

            --
            fnd_file.put_line (
                fnd_file.LOG,
                'Before calling Print Transactions - Deckers (Child)');

            --
            IF l_party_id_low IS NOT NULL AND l_party_id_high IS NOT NULL
            THEN
                v_wait_count (l_request_cnt)   :=
                    fnd_request.submit_request ('XXDO', 'XXDOAR035', p_request_id, SYSDATE, FALSE, p_org_id, p_trx_class, p_creation_date_low, --Added for CCR0005936
                                                                                                                                               p_creation_date_high, --Added for CCR0005936
                                                                                                                                                                     p_trx_date_low, p_trx_date_high, p_customer_id, p_cust_bill_to, p_invoice_num_from, p_invoice_num_to, l_CUST_NUM_FROM, l_CUST_NUM_TO, p_brand, p_order_by, p_re_transmit_flag, p_printer
                                                , p_copies, p_cc_email_id);
            END IF;



            fnd_file.put_line (fnd_file.LOG, 'Batch :' || l_cust);



            fnd_file.put_line (fnd_file.LOG,
                               'l_request_cnt:' || l_request_cnt);
            fnd_file.put_line (fnd_file.LOG, 'p_max_sets:' || p_max_sets);
            fnd_file.put_line (fnd_file.LOG, 'l_totl_rec:' || l_totl_rec);

            --
            /*Start of Change as part of Ver 2.0 on 24-Nov-2016*/
            --IF l_request_cnt=p_max_sets  or  l_request_cnt = l_totl_rec then
            IF l_request_cnt = p_max_sets OR l_request_cnt = l_loop_cnt
            THEN
                /*End of Change as part of Ver 2.0 on 24-Nov-2016*/
                BEGIN
                    --
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'v_wait_count.LAST:' || v_wait_count.LAST);

                    --
                    FOR l_req_sub IN 1 .. v_wait_count.LAST
                    LOOP
                        IF v_wait_count (l_req_sub) > 0
                        THEN
                            COMMIT;
                            l_return   :=
                                Fnd_Concurrent.wait_for_request (
                                    request_id   => v_wait_count (l_req_sub),
                                    INTERVAL     => 10,
                                    max_wait     => 50000,             --10000
                                    phase        => l_phase,
                                    STATUS       => l_status,
                                    dev_phase    => l_dev_phase,
                                    dev_status   => l_dev_status,
                                    MESSAGE      => l_message);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Request id :'
                                || ' '
                                || v_wait_count (l_req_sub)
                                || 'Phase :  '
                                || l_phase
                                || ' '
                                || 'STATUS:  '
                                || l_status);


                            IF l_status = 'Normal'
                            THEN
                                v_sub_req   :=
                                    fnd_request.submit_request (
                                        application   => 'XDO',
                                        program       => 'XDOBURSTREP',
                                        description   =>
                                            'XML Publisher Report Bursting Program',
                                        argument1     => 'Y',
                                        argument2     =>
                                            v_wait_count (l_req_sub),
                                        argument3     => 'Y');
                                COMMIT;
                            END IF;

                            IF v_sub_req <= 0
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Failed to submit Bursting XML Publisher Request for Request ID = '
                                    || v_wait_count (l_req_sub));
                            ELSE
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Submitted Bursting XML Publisher Request Request ID = '
                                    || v_sub_req);
                            END IF;
                        END IF;

                        v_wait_count (l_req_sub)   := 0;
                    END LOOP;               --End of loop for Bursting program

                    fnd_file.put_line (
                        fnd_file.LOG,
                        '==================================================================');
                -- l_request_cnt:=0; -- Commented for Ver 2.0 on 24-Nov-2016
                END;
            END IF;

            l_request_cnt     := l_request_cnt + 1;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error in Submit_print_trx_dec_child procedure ::' || SQLERRM);
            fnd_file.put_line (
                fnd_file.LOG,
                'Get Error Line :' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
    END Submit_print_trx_dec_child;
END XXD_PRINT_TRX_DEC_PKG;
/
