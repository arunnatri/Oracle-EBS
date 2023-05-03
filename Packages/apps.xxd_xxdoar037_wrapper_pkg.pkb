--
-- XXD_XXDOAR037_WRAPPER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:37 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_XXDOAR037_WRAPPER_PKG"
AS
    /************************************************************************************************
    * Package      : APPS.XXD_XXDOAR037_WRAPPER_PKG
    * Author       : BT Technology Team
    * Created      : 20-NOV-2015
    * Program Name  : Transaction PDF File Generation Wrapper  Deckers
    * Description  : Wrapper Program to call the Transaction PDF File Generation  Deckers Report for different output types
    *
    * Modification  :
    *-----------------------------------------------------------------------------------------------
    *  Date         Developer             Version  Description
    *-----------------------------------------------------------------------------------------------
    * 20-NOV-2015     BT Technology Team   V1.1     Development
    * 12-May-2016    Infosys                 V2.0      Modified to implement parellel processing for invoices.
    * 01-Aug-2016   BT Technology Team      2.1      Changes for INC0305730 to add creation_date logic
    * 28-Jun-2017   Infosys             V3.0    Modified to include re-transmit logic for PRB0041178
    ************************************************************************************************/

    gn_conc_req_id   NUMBER := fnd_global.conc_request_id; -- Added by Infosys team. 12-May-2016.
    gn_user_id       NUMBER := apps.fnd_global.user_id; -- Added by Infosys team. 12-May-2016.

    PROCEDURE submit_request_layout (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_org_id IN NUMBER, p_trx_class IN VARCHAR2, p_trx_date_low IN VARCHAR2, p_trx_date_high IN VARCHAR2, --Start changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                                                                                                                                                                                    p_creation_date_low IN VARCHAR2, p_creation_date_high IN VARCHAR2, --End changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                                                                                                                                                                                                                                                       p_customer_id IN NUMBER, p_invoice_num_from IN VARCHAR2, p_invoice_num_to IN VARCHAR2, p_cust_num_from IN VARCHAR2
                                     , p_dir_loc IN VARCHAR2, p_batch_size IN NUMBER DEFAULT 300, -- Added by Infosys team. 12-May-2016.
                                                                                                  p_retransmit_flag IN VARCHAR2 -- Added by Infosys for PRB0041178
                                                                                                                               )
    AS
        ln_request_id      NUMBER;
        lc_boolean1        BOOLEAN;
        lc_boolean2        BOOLEAN;
        l_org_id           NUMBER;

        -- START : Modified by Infosys. 12-May-2016.
        ln_counter         NUMBER := 0;
        ln_batch_id        NUMBER := 0;


        l_bol_req_status   BOOLEAN;
        l_chr_phase        VARCHAR2 (100) := NULL;
        l_chr_status       VARCHAR2 (100) := NULL;
        l_chr_dev_phase    VARCHAR2 (100) := NULL;
        l_chr_dev_status   VARCHAR2 (100) := NULL;
        l_chr_message      VARCHAR2 (1000) := NULL;
        l_burst_req_id     NUMBER := NULL;
        l_return_status    VARCHAR2 (30);
        l_return_message   VARCHAR2 (4000);


        CURSOR csr_fetch_invoices IS
            SELECT details.customer_trx_id transaction_id
              FROM (  SELECT rct.customer_trx_id
                                 customer_trx_id,
                             rct.related_customer_trx_id
                                 rel_customer_trx_id,
                             rct.set_of_books_id
                                 set_of_books_id,
                             rct.trx_number
                                 trx_number,
                             TO_CHAR (rct.trx_date, 'MM/DD/YYYY')
                                 trx_date                        --defect 2904
                                         ,
                             TO_CHAR (rct.trx_date, 'MM/DD/YYYY')
                                 trx_date_dsp                    --defect 2904
                                             ,
                             DECODE (tt.TYPE,
                                     'CM', NVL (tt.description, tt.name),
                                     tt.name)
                                 trx_type_name,
                             tt.TYPE
                                 trx_class_code,
                             arl.meaning
                                 trx_class_desc,
                             NVL (abc.name, 'NO SOURCE')
                                 trx_source_type,
                             NVL (abc.batch_source_id, -999)
                                 trx_source_id,
                             rct.reason_code
                                 reason_code,
                             xxdo_ar_invoice_print.factored_flag (
                                 rct.customer_trx_id)
                                 factor_flag,
                             xxdo_ar_invoice_print.remit_to_address_id (
                                 rct.customer_trx_id)
                                 remit_to_address_id,
                             rct.bill_to_customer_id,
                             rct.bill_to_site_use_id,
                             rct.bill_to_contact_id,
                             rct.ship_to_customer_id,
                             rct.ship_to_site_use_id,
                             rct.ship_to_contact_id,
                             bill.customer_name
                                 bill_customer_name,
                             bill.customer_number
                                 bill_cust_num,
                             bill.address1
                                 bill_address1,
                             bill.address2
                                 bill_address2,
                             bill.address3
                                 bill_address3,
                             bill.address4
                                 bill_address4,
                             bill.city
                                 bill_city,
                             bill.state
                                 bill_state,
                             bill.postal_code
                                 bill_postal_code,
                             bill.country
                                 bill_country,
                             bill.country_name
                                 bill_country_name,
                             xxdo_ar_invoice_print.address_dsp (bill.address1, bill.address2, bill.address3, bill.address4, bill.city, bill.state, bill.postal_code, bill.country, bill.country_name
                                                                , rct.org_id)
                                 bill_to_address_dsp,
                             bill.tax_reference
                                 bill_tax_ref,
                             bill.brand
                                 brand,
                             ship.customer_name
                                 ship_customer_name,
                             ship.customer_number
                                 ship_customer_num,
                             ship.address1
                                 ship_address1,
                             ship.address2
                                 ship_address2,
                             ship.address3
                                 ship_address3,
                             ship.address4
                                 ship_address4,
                             ship.city
                                 ship_city,
                             ship.state
                                 ship_state,
                             ship.postal_code
                                 ship_postal_code,
                             ship.country
                                 ship_country,
                             ship.country_name
                                 ship_country_name,
                             ship.store_number
                                 store_number,
                             ship.dc_number
                                 dc_number,
                             apps.do_edi_utils_pub.parse_attributes (
                                 rct.attribute3,
                                 'depart_number')
                                 AS dept_number,
                             xxdo_ar_invoice_print.address_dsp (ship.address1, ship.address2, ship.address3, ship.address4, ship.city, ship.state, ship.postal_code, ship.country, ship.country_name
                                                                , rct.org_id)
                                 ship_to_address_dsp,
                             ship.tax_reference
                                 ship_tax_ref,
                             remit.address1
                                 remit_address1,
                             remit.address2
                                 remit_address2,
                             remit.address3
                                 remit_address3,
                             remit.address4
                                 remit_address4,
                             remit.city || ','
                                 remit_city,
                             remit.state
                                 remit_state,
                             remit.postal_code
                                 remit_postal_code,
                             remit.country
                                 remit_country,
                             remit.country_name
                                 remit_country_name,
                             remit.contact_number
                                 remit_contact_number,
                             remit.addressee
                                 remit_addressee,
                             DECODE (
                                 remit.addressee,
                                 'FACTOR',    'This invoice is assigned and payable to: '
                                           || remit.address1
                                           || ' to whom notice must be given of any returns or claims.'
                                           || CHR (13)
                                           || 'Payment to any other party does not constitute valid payment of this invoice.',
                                 '')
                                 remit_factor_disclaimer,
                             NVL (ship.tax_reference, bill.tax_reference)
                                 tax_reference,
                             term.name
                                 term_name,
                             term.description
                                 term_description,
                             xxdo_ar_invoice_print.discount_amount_explanation (
                                 ps.payment_schedule_id)
                                 term_discount_amount_desc,
                             rep.name
                                 salesrep_name,
                             rct.printing_pending
                                 printing_pending,
                             rct.purchase_order
                                 purchase_order,
                             NVL (
                                 xxdo_ar_invoice_print.discount_amount_explanation (
                                     ps.payment_schedule_id),
                                 rct.comments)
                                 comments,
                             rct.comments
                                 invoice_comments,
                             rct.internal_notes
                                 internal_notes,
                             rct.invoice_currency_code
                                 invoice_currency_code,
                             rct.attribute1
                                 trx_attribute1                 -- cancel_date
                                               ,
                             rct.attribute2
                                 trx_attribute2                 -- order class
                                               ,
                             rct.attribute3
                                 trx_attribute3,
                             rct.attribute4
                                 trx_attribute4,
                             rct.attribute5
                                 trx_brand,
                             rct.attribute6
                                 trx_attribute6                  -- commments1
                                               ,
                             rct.attribute7
                                 trx_attribute7                   -- comments2
                                               ,
                             rct.attribute8
                                 trx_attribute8,
                             rct.attribute9
                                 trx_attribute9,
                             rct.attribute10
                                 trx_attribute10,
                             rct.ship_via
                                 ship_via,
                             ship_via.description
                                 ship_via_desc,
                             DECODE (rct.waybill_number,
                                     '0', '',
                                     rct.waybill_number)
                                 waybill_number,
                             rct.interface_header_context,
                             NVL (rct.interface_header_attribute1,
                                  rct.ct_reference)
                                 order_reference,
                             rct.interface_header_attribute2
                                 order_type,
                             DECODE (rct.interface_header_attribute3,
                                     '0', '',
                                     rct.interface_header_attribute3)
                                 delivery_number,
                             ps.due_date
                                 due_date --COMMENTED by BT Technology Team ON 27/JAN/2015
                                         ,
                             TO_CHAR (ps.due_date, 'MM/DD/YYYY')
                                 due_date_dsp,
                             ps.amount_due_original
                                 invoice_amount,
                             TRIM (
                                 TO_CHAR (ps.amount_due_original,
                                          '999,999,999,990.99'))
                                 inv_amt_dsp,
                             ps.amount_line_items_original,
                             TRIM (
                                 TO_CHAR (ps.amount_line_items_original,
                                          '999,999,999,990.99'))
                                 invoice_line_amt_dsp,
                             ps.freight_original,
                             TRIM (
                                 TO_CHAR (ps.freight_original,
                                          '999,999,999,990.99'))
                                 invoice_freight_amt_dsp,
                             ps.tax_original,
                             TRIM (
                                 TO_CHAR (ps.tax_original,
                                          '999,999,999,990.99'))
                                 invoice_tax_amt_dsp,
                             ROUND (
                                   ps.freight_original
                                 + ps.tax_original
                                 + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))),
                                 2)
                                 disc_amt,
                             TRIM (
                                 TO_CHAR (
                                     ROUND (
                                           ps.freight_original
                                         + ps.tax_original
                                         + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))),
                                         2),
                                     '999,999,999,990.99'))
                                 disc_amt_dsp,
                               ROUND (ps.amount_due_original, 2)
                             - ROUND (
                                     ps.freight_original
                                   + ps.tax_original
                                   + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))),
                                   2)
                                 AS discount,
                             TRIM (
                                 TO_CHAR (
                                       ROUND (ps.amount_due_original, 2)
                                     - ROUND (
                                             ps.freight_original
                                           + ps.tax_original
                                           + (ps.amount_line_items_original * (NVL ((1 - NVL (rtld.discount_percent, 0) / 100), 1))),
                                           2),
                                     '999,999,999,990.99'))
                                 AS discounted
                        FROM apps.ra_customer_trx_all rct,
                             apps.ar_payment_schedules_all ps,
                             (SELECT c.cust_account_id customer_id, c.attribute1 brand, u.site_use_id site_use_id,
                                     c.account_number customer_number, party.party_name customer_name, loc.address1 address1,
                                     loc.address2 address2, loc.address3 address3, loc.address4 address4,
                                     loc.city city, NVL (loc.state, loc.province) state, loc.postal_code postal_code,
                                     loc.country country, terr.territory_short_name country_name, u.tax_reference site_tax_reference,
                                     party.tax_reference cust_tax_reference, NVL (u.tax_reference, party.tax_reference) tax_reference, c.customer_class_code
                                FROM hz_cust_accounts c, hz_parties party, hz_cust_acct_sites_all a,
                                     hz_party_sites party_site, hz_locations loc, hz_cust_site_uses_all u,
                                     apps.fnd_territories_tl terr
                               WHERE     u.cust_acct_site_id =
                                         a.cust_acct_site_id     -- address_id
                                     AND a.party_site_id =
                                         party_site.party_site_id
                                     AND loc.location_id =
                                         party_site.location_id
                                     AND c.party_id = party.party_id
                                     AND loc.country = terr.territory_code
                                     AND terr.language = USERENV ('LANG')) bill,
                             (SELECT c.cust_account_id customer_id, u.site_use_id site_use_id, c.account_number customer_number,
                                     NVL (a.attribute1, party.party_name) customer_name, loc.address1 address1, loc.address2 address2,
                                     loc.address3 address3, loc.address4 address4, loc.city city,
                                     NVL (loc.state, loc.province) state, loc.postal_code postal_code, loc.country country,
                                     terr.territory_short_name country_name, u.tax_reference site_tax_reference, party.tax_reference cust_tax_reference,
                                     NVL (u.tax_reference, party.tax_reference) tax_reference, a.attribute2 store_number, a.attribute5 dc_number
                                FROM hz_cust_accounts c, hz_parties party, hz_cust_acct_sites_all a,
                                     hz_party_sites party_site, hz_locations loc, hz_cust_site_uses_all u,
                                     apps.fnd_territories_tl terr
                               WHERE     u.cust_acct_site_id =
                                         a.cust_acct_site_id     -- address_id
                                     AND a.party_site_id =
                                         party_site.party_site_id
                                     AND loc.location_id =
                                         party_site.location_id
                                     AND c.party_id = party.party_id
                                     AND loc.country = terr.territory_code
                                     AND terr.language = USERENV ('LANG')) ship,
                             (SELECT acct_site.cust_acct_site_id address_id, loc.address1 address1, loc.address2 address2,
                                     loc.address3 address3, loc.address4 address4, loc.city city,
                                     NVL (loc.state, loc.province) state, loc.postal_code postal_code, loc.country country,
                                     terr.territory_short_name country_name, party_site.addressee, acct_site.attribute2 contact_number
                                FROM hz_cust_acct_sites_all acct_site, hz_party_sites party_site, hz_locations loc,
                                     apps.fnd_territories_tl terr
                               WHERE     acct_site.party_site_id =
                                         party_site.party_site_id
                                     AND loc.location_id =
                                         party_site.location_id
                                     AND loc.country = terr.territory_code
                                     AND terr.language = USERENV ('LANG'))
                             remit,
                             (SELECT f.freight_code, description
                                FROM apps.org_freight f, apps.oe_system_parameters_all osp
                               WHERE     f.organization_id =
                                         osp.master_organization_id
                                     AND osp.org_id = p_org_id) ship_via,
                             apps.ra_cust_trx_types_all tt,
                             apps.ra_batch_sources_all abc,
                             apps.ar_lookups arl,
                             apps.ra_terms term,
                             apps.ra_terms_lines_discounts rtld,
                             apps.ra_salesreps rep
                       WHERE     rct.bill_to_customer_id = bill.customer_id
                             AND rct.bill_to_site_use_id = bill.site_use_id
                             AND rct.ship_to_customer_id = ship.customer_id(+)
                             AND rct.ship_to_site_use_id = ship.site_use_id(+)
                             AND rct.cust_trx_type_id = tt.cust_trx_type_id
                             AND rct.org_id = tt.org_id
                             AND tt.TYPE = arl.lookup_code
                             AND arl.lookup_type = 'INV/CM'
                             AND rct.batch_source_id = abc.batch_source_id(+)
                             AND rct.org_id = abc.org_id(+)
                             AND rct.customer_trx_id = ps.customer_trx_id
                             AND rct.term_id = term.term_id(+)
                             AND rtld.term_id(+) = rct.term_id
                             AND rct.primary_salesrep_id = rep.salesrep_id(+)
                             AND rct.org_id = rep.org_id(+)
                             AND apps.xxdo_ar_invoice_print.remit_to_address_id (
                                     rct.customer_trx_id) =
                                 remit.address_id(+)
                             AND rct.ship_via = ship_via.freight_code(+)
                             AND rct.printing_option = 'PRI'
                             AND ps.number_of_due_dates = 1 -- Multiple pay schedule invoices will be printed using a different format
                             AND NVL (
                                     DECODE (
                                         p_retransmit_flag,
                                         'Y', 'N',
                                         'N', NVL (rct.global_attribute4, 'Y')),
                                     NVL (rct.global_attribute4, 'Y')) =
                                 NVL (rct.global_attribute4, 'Y') -- Added by Infosys for PRB0041178
                             AND NOT EXISTS
                                     (SELECT 1
                                        FROM fnd_lookup_values flv
                                       WHERE     1 = 1
                                             AND flv.language =
                                                 USERENV ('LANG')
                                             AND flv.lookup_type =
                                                 'XXDOAR035_EXCLUDED_TRX_TYPES'
                                             AND flv.meaning = tt.name
                                             AND flv.description = tt.TYPE
                                             AND DECODE (
                                                     SIGN (
                                                           SYSDATE
                                                         - NVL (
                                                               flv.start_date_active,
                                                               SYSDATE - 1)),
                                                     -1, 'INACTIVE',
                                                     DECODE (
                                                         SIGN (
                                                               NVL (
                                                                   flv.end_date_active,
                                                                   SYSDATE + 1)
                                                             - SYSDATE),
                                                         -1, 'INACTIVE',
                                                         DECODE (
                                                             flv.enabled_flag,
                                                             'N', 'INACTIVE',
                                                             'ACTIVE'))) =
                                                 'ACTIVE')
                             AND rct.attribute5 = rct.attribute5
                             AND rct.trx_number >=
                                 NVL (p_invoice_num_from, rct.trx_number)
                             AND rct.trx_number <=
                                 NVL (p_invoice_num_to, rct.trx_number)
                             AND rct.org_id = NVL (p_org_id, rct.org_id)
                             AND bill.customer_number =
                                 NVL (p_cust_num_from, bill.customer_number)
                             AND tt.TYPE = NVL (p_trx_class, tt.TYPE)
                             AND rct.trx_date >=
                                 NVL (
                                     TO_CHAR (
                                         TO_DATE (p_trx_date_low,
                                                  'RRRR/MM/DD HH24:MI:SS'),
                                         'DD-MON-YYYY'),
                                     rct.trx_date)
                             AND rct.trx_date <=
                                 NVL (
                                     TO_CHAR (
                                         TO_DATE (p_trx_date_high,
                                                  'RRRR/MM/DD HH24:MI:SS'),
                                         'DD-MON-YYYY'),
                                     rct.trx_date)
                             --Start changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                             AND TRUNC (rct.creation_date) >=
                                 NVL (
                                     TO_CHAR (
                                         TO_DATE (p_creation_date_low,
                                                  'RRRR/MM/DD HH24:MI:SS'),
                                         'DD-MON-YYYY'),
                                     rct.creation_date)
                             AND TRUNC (rct.creation_date) <=
                                 NVL (
                                     TO_CHAR (
                                         TO_DATE (p_creation_date_high,
                                                  'RRRR/MM/DD HH24:MI:SS'),
                                         'DD-MON-YYYY'),
                                     rct.creation_date)
                    --End changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                    ORDER BY rct.customer_trx_id) details;

        CURSOR csr_batch_ids IS
              SELECT DISTINCT batch_id
                FROM xxd_xxdoar037_inv_dtl_stg
               WHERE wrapper_request_id = gn_conc_req_id
            ORDER BY batch_id;
    -- END : Modified by Infosys. 12-May-2016.

    BEGIN
        -- START : Modified by Infosys. 12-May-2016.
        ln_counter   := 0;

        BEGIN
            SELECT xxd_xxdoar037_batch_id_seq.NEXTVAL
              INTO ln_batch_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_batch_id   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error while accessing Sequence : XXD_XXDOAR037_BATCH_ID_SEQ. Error# : '
                    || SQLCODE
                    || '. Error Message : '
                    || SQLERRM);
        END;

        FOR rec_fetch_invoices IN csr_fetch_invoices
        LOOP
            ln_counter   := ln_counter + 1;

            IF ln_counter > p_batch_size
            THEN
                ln_counter   := 0;

                BEGIN
                    SELECT xxd_xxdoar037_batch_id_seq.NEXTVAL
                      INTO ln_batch_id
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_batch_id   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error while accessing Sequence : XXD_XXDOAR037_BATCH_ID_SEQ. Error# : '
                            || SQLCODE
                            || '. Error Message : '
                            || SQLERRM);
                END;
            END IF;

            INSERT INTO xxd_xxdoar037_inv_dtl_stg
                 VALUES (ln_batch_id, rec_fetch_invoices.transaction_id, gn_conc_req_id, SYSDATE, gn_user_id, SYSDATE
                         , gn_user_id);

            COMMIT;
        END LOOP;

        -- END : Modified by Infosys. 12-May-2016.

        fnd_file.put_line (fnd_file.LOG,
                           'In submit_request_layout Program....');

        FOR rec_batch_ids IN csr_batch_ids -- Added by Infosys Team. 12-May-2016.
        LOOP
            IF p_trx_class = 'DM'
            THEN
                fnd_file.put_line (fnd_file.LOG, 'Adding Excel Layout.... ');
                lc_boolean1   :=
                    fnd_request.add_layout (
                        template_appl_name   => 'XXDO',
                        template_code        => 'XXDOAR037_DM',
                        template_language    => 'en',
                        --Use language from template definition
                        template_territory   => 'US',
                        --Use territory from template definition
                        output_format        => 'PDF' --Use output format from template definition
                                                     );
            ELSIF p_trx_class = 'CM' OR p_trx_class = 'CB'
            THEN
                fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');
                lc_boolean2   :=
                    fnd_request.add_layout (
                        template_appl_name   => 'XXDO',
                        template_code        => 'XXDOAR037_CM',
                        template_language    => 'en',
                        --Use language from template definition
                        template_territory   => 'US',
                        --Use territory from template definition
                        output_format        => 'PDF' --Use output format from template definition
                                                     );
            ELSE
                fnd_file.put_line (fnd_file.LOG, 'Adding Text Layout..... ');
                lc_boolean2   :=
                    fnd_request.add_layout (
                        template_appl_name   => 'XXDO',
                        template_code        => 'XXDOAR037_INV',
                        template_language    => 'en',
                        --Use language from template definition
                        template_territory   => 'US',
                        --Use territory from template definition
                        output_format        => 'PDF' --Use output format from template definition
                                                     );
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                'Submitting Print Transactions - Deckers (Sub Program)..... ');
            ln_request_id   :=
                fnd_request.submit_request (
                    'XXDO',                                     -- application
                    'XXDOAR037',                         -- program short name
                    'Transaction PDF File Generation  Deckers',
                    -- description
                    SYSDATE,                                     -- start time
                    FALSE,                                      -- sub request
                    p_org_id,
                    p_trx_class,
                    p_trx_date_low,
                    p_trx_date_high,
                    --Start changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                    p_creation_date_low,
                    p_creation_date_high,
                    --End changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                    p_customer_id,
                    p_invoice_num_from,
                    p_invoice_num_to,
                    p_cust_num_from,
                    p_dir_loc,
                    rec_batch_ids.batch_id -- Added by Infosys team. 12-May-2016.
                                          );

            IF ln_request_id = 0
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Concurrent request failed to submit');
            ELSE
                COMMIT;
            END IF;

            -- START : Added by Infosys. 16-May-2016.
            LOOP
                l_bol_req_status   :=
                    fnd_concurrent.wait_for_request (ln_request_id,
                                                     2,
                                                     0,
                                                     l_chr_phase,
                                                     l_chr_status,
                                                     l_chr_dev_phase,
                                                     l_chr_dev_status,
                                                     l_chr_message);

                EXIT WHEN    UPPER (l_chr_phase) = 'COMPLETED'
                          OR UPPER (l_chr_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;

            COMMIT;

            IF     UPPER (l_chr_phase) = 'COMPLETED'
               AND UPPER (l_chr_status) = 'NORMAL'
            THEN
                l_burst_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XDO',
                        program       => 'XDOBURSTREP',
                        description   =>
                            'XML Publisher Report Bursting Program',
                        start_time    => SYSDATE,
                        sub_request   => FALSE,
                        argument1     => 'Y',
                        argument2     => ln_request_id,
                        argument3     => 'Y');
                COMMIT;

                IF NVL (l_burst_req_id, 0) = 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Bursting Concurrent request failed to submit');
                ELSE
                    l_bol_req_status   := NULL;
                    l_chr_phase        := NULL;
                    l_chr_status       := NULL;
                    l_chr_dev_phase    := NULL;
                    l_chr_dev_status   := NULL;
                    l_chr_message      := NULL;

                    LOOP
                        l_bol_req_status   :=
                            fnd_concurrent.wait_for_request (
                                l_burst_req_id,
                                2,
                                0,
                                l_chr_phase,
                                l_chr_status,
                                l_chr_dev_phase,
                                l_chr_dev_status,
                                l_chr_message);
                        EXIT WHEN    UPPER (l_chr_phase) = 'COMPLETED'
                                  OR UPPER (l_chr_status) IN
                                         ('CANCELLED', 'ERROR', 'TERMINATED');
                    END LOOP;

                    COMMIT;

                    IF     UPPER (l_chr_phase) = 'COMPLETED'
                       AND UPPER (l_chr_status) = 'NORMAL'
                    THEN
                        xxdo_ar_invoice_print.update_pdf_generated_flag (
                            p_customer_id          => p_customer_id,
                            p_trx_class            => p_trx_class,
                            p_cust_num             => p_cust_num_from,
                            p_trx_date_low         => p_trx_date_low,
                            p_trx_date_high        => p_trx_date_high,
                            --Start changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                            p_creation_date_low    => p_creation_date_low,
                            p_creation_date_high   => p_creation_date_high,
                            --End changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                            p_invoice_num_from     => p_invoice_num_from,
                            p_invoice_num_to       => p_invoice_num_to,
                            p_org_id               => p_org_id,
                            p_batch_id             => rec_batch_ids.batch_id, -- Added by Infosys. 12-May-2016.
                            x_return_status        => l_return_status,
                            x_return_message       => l_return_message);

                        IF l_return_status <> 'SUCCESS'
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'UPDATE_PDF_GENERATED_FLAG failed. Status : '
                                || l_return_status
                                || 'Error Message : '
                                || l_return_message);
                        END IF;
                    END IF;
                END IF;
            END IF;
        END LOOP;
    -- END : Added by Infosys. 16-May-2016.
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception Occured while running the Wrapper Program');
            fnd_file.put_line (
                fnd_file.LOG,
                'ERROR Details :' || SQLERRM || '-' || SQLCODE);
    END submit_request_layout;
END xxd_xxdoar037_wrapper_pkg;
/
