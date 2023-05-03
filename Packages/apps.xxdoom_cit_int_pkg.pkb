--
-- XXDOOM_CIT_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOOM_CIT_INT_PKG"
AS
    /*
    ================================================================
     Created By              : Venkatesh Ragamgari
     Creation Date           : 31-Jan-2011
     File Name               : XXDOOM_CIT_INT_PKG.pkb
     Work Order Num          : Sanuk CIT Interface
     Incident Num            :
     Description             :
     Latest Version          : 1.1
     Revision History        : a. Modified to exclude the Return
                                  Lines
                        b. Modified to send whatever value
                                  from Attribute13 of sales order
    ================================================================
     Date               Version#    Name                    Remarks
    ================================================================
     18-NOV-2011        1.0         Venkatesh Ragamgari
     13-Dec-2013        1.1         Madhav Dhurjaty         Modified MAIN, order_outbound for CIT FTP Change ENHC0011747
     01-DEC-2014        1.2         BT Technology Team      If the Payment terms of Order is either Credit Card or Prepay or COD, then the Order should not be considered as Factored Order
                                                            and The Factored Profile class will be at the customer account level only instead of the customer account and bill-to-site since
                                                            the Brands are created as customer accounts,so,modified in the function  is_fact_cust_f

     5-jan-2014         2.1        BT Technology Team        initializing for apps and given the seed for org_id, using canonical  date function
    ================================================================

    */

    /* Function to determine the Terms Date */
    FUNCTION cit_terms_date_f (pn_header_id NUMBER, pd_start_date VARCHAR2)
        RETURN VARCHAR2
    IS
        ln_payment_term   NUMBER;
        ld_start_date     DATE;
        lv_term_days      VARCHAR2 (30);
        ln_due_days       NUMBER;
    BEGIN
        /* Code to retreive the Terms from the Order Header */
        BEGIN
            SELECT payment_term_id
              INTO ln_payment_term
              FROM apps.oe_order_headers_all
             WHERE header_id = pn_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_payment_term   := NULL;
        END;

        IF ln_payment_term IS NOT NULL
        THEN
            /* Verifying for the Due Days in RaTerm lines */
            BEGIN
                ln_due_days   := NULL;

                SELECT rtl.due_days
                  INTO ln_due_days
                  FROM apps.ra_terms_lines rtl, apps.ra_terms rt
                 WHERE     rtl.term_id = rt.term_id
                       AND rt.term_id = ln_payment_term
                       AND rtl.sequence_num = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_due_days   := NULL;
            END;

            IF ln_due_days IS NOT NULL
            THEN
                lv_term_days   := LPAD (ln_due_days, 3, 0);
                RETURN lv_term_days;
            ELSE
                /* Verifying for the Due Months Forward and Due day of the Month */
                BEGIN
                    SELECT (ADD_MONTHS (TO_DATE (ld_start_date, 'MMDDYY'), rtl.due_months_forward) + due_day_of_month) - TO_DATE (ld_start_date, 'MMDDYY') ddays
                      INTO ln_due_days
                      FROM apps.ra_terms_lines rtl, apps.ra_terms rt
                     WHERE     rtl.term_id = rt.term_id
                           AND rt.term_id = ln_payment_term
                           AND rtl.sequence_num = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_due_days   := NULL;
                END;

                IF ln_due_days IS NOT NULL
                THEN
                    lv_term_days   := LPAD (ln_due_days, 3, 0);
                    RETURN lv_term_days;
                ELSE
                    /* Verifying for the Due Date and calculating the Due days based on it */
                    BEGIN
                        SELECT due_date - TO_DATE (ld_start_date, 'MMDDYY') ddays
                          INTO ln_due_days
                          FROM apps.ra_terms_lines rtl, apps.ra_terms rt
                         WHERE     rtl.term_id = rt.term_id
                               AND rt.term_id = ln_payment_term
                               AND rtl.sequence_num = 1
                               AND rtl.due_date IS NOT NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_due_days   := NULL;
                    END;

                    IF ln_due_days IS NOT NULL
                    THEN
                        lv_term_days   := LPAD (ln_due_days, 3, 0);
                        RETURN lv_term_days;
                    ELSE
                        lv_term_days   := NULL;
                        RETURN lv_term_days;
                    END IF;
                END IF;
            END IF;
        ELSE
            RETURN NULL;
        END IF;

        RETURN lv_term_days;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    /* Function to format the Phone number */
    FUNCTION phone_format_f (pn_raw_phone VARCHAR2)
        RETURN NUMBER
    IS
        ln_raw_phone          VARCHAR2 (20);
        j                     NUMBER;
        k                     NUMBER;
        ln_phone_no           VARCHAR2 (40);
        ln_left_param_phone   VARCHAR2 (20);
        ln_rt_param_phone     VARCHAR2 (20);
        ln_final_phone_no     VARCHAR2 (15);
    BEGIN
        ln_raw_phone        := pn_raw_phone;
        /* Removing the - Hiphens from the Phone */
        j                   := 1;
        k                   := 1;

        WHILE k > 0
        LOOP
            k   := INSTR (ln_raw_phone, '-', j);

            SELECT ln_phone_no || SUBSTR (ln_raw_phone, j, DECODE (k, 0, LENGTH (ln_raw_phone), k - j))
              INTO ln_phone_no
              FROM DUAL;

            j   := k + 1;
        END LOOP;

        /* Removing the left paranthesis from the Phone */
        j                   := 1;
        k                   := 1;

        WHILE k > 0
        LOOP
            k   := INSTR (ln_phone_no, '(', j);

            SELECT ln_left_param_phone || SUBSTR (ln_phone_no, j, DECODE (k, 0, LENGTH (ln_phone_no), k - j))
              INTO ln_left_param_phone
              FROM DUAL;

            j   := k + 1;
        END LOOP;

        /* Removing the Right paranthesis from the Phone */
        j                   := 1;
        k                   := 1;

        WHILE k > 0
        LOOP
            k   := INSTR (ln_left_param_phone, ')', j);

            SELECT ln_rt_param_phone || SUBSTR (ln_left_param_phone, j, DECODE (k, 0, LENGTH (ln_left_param_phone), k - j))
              INTO ln_rt_param_phone
              FROM DUAL;

            j   := k + 1;
        END LOOP;

        ln_final_phone_no   := LPAD (ln_rt_param_phone, 10, 0);
        RETURN ln_final_phone_no;
    END;

    /* Function to fetch the Customer Phone Number */
    FUNCTION cust_phone_f (pn_cust_acct_id       NUMBER,
                           pn_cust_site_use_id   NUMBER)
        RETURN NUMBER
    IS
        ln_raw_phone   VARCHAR2 (20);
        ln_phone_no    NUMBER;
    BEGIN
        ln_raw_phone   := NULL;

        BEGIN
            SELECT DISTINCT raw_phone_number
              INTO ln_raw_phone
              FROM apps.hz_contact_points hcp
             WHERE EXISTS
                       (SELECT 1
                          FROM (SELECT hr.party_id, hr.subject_table_name
                                  FROM apps.hz_cust_account_roles hcar, apps.hz_role_responsibility hrr, apps.hz_relationships hr
                                 WHERE     hcar.cust_account_role_id =
                                           hrr.cust_account_role_id
                                       AND hrr.responsibility_type =
                                           'CREDIT_CONTACT'
                                       -- Start changes by BT Technology Team on 02-DEC-2014 (version 1.2)
                                       /*AND hcar.cust_acct_site_id =
                                              NVL (pn_cust_site_use_id,
                                                   hcar.cust_acct_site_id
                                                  )*/
                                       -- End changes by BT Technology Team on 02-DEC-2014 (version 1.2)
                                       AND hcar.cust_account_id =
                                           pn_cust_acct_id
                                       AND hr.subject_id =
                                           (SELECT hp.party_id
                                              FROM apps.hz_parties hp, apps.hz_cust_accounts_all hca
                                             WHERE     hca.party_id =
                                                       hp.party_id
                                                   AND hca.cust_account_id =
                                                       pn_cust_acct_id)
                                       AND hr.party_id = hcar.party_id
                                       AND hrr.primary_flag = 'Y') a
                         WHERE     a.party_id = hcp.owner_table_id
                               AND contact_point_type = 'PHONE' -- Added by BT Technology Team on 02-DEC-2014 (version 1.2)
                               AND a.subject_table_name =
                                   hcp.owner_table_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_raw_phone   := NULL;
        END;

        IF ln_raw_phone IS NULL
        THEN
            BEGIN
                SELECT DISTINCT raw_phone_number
                  INTO ln_raw_phone
                  FROM apps.hz_contact_points hcp
                 WHERE     owner_table_name = 'HZ_PARTY_SITES'
                       AND owner_table_id =
                           (SELECT hcs.party_site_id
                              FROM apps.hz_cust_acct_sites_all hcs, apps.hz_cust_site_uses_all hcsu
                             WHERE     hcs.cust_account_id = pn_cust_acct_id
                                   AND hcs.cust_acct_site_id =
                                       hcsu.cust_acct_site_id
                                   AND hcsu.site_use_id = pn_cust_site_use_id)
                       AND primary_flag = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_raw_phone   := NULL;
            END;

            IF ln_raw_phone IS NULL
            THEN
                BEGIN
                    SELECT DISTINCT raw_phone_number
                      INTO ln_raw_phone
                      FROM apps.hz_contact_points hcp
                     WHERE     owner_table_name = 'HZ_PARTIES'
                           AND owner_table_id =
                               (SELECT party_id
                                  FROM apps.hz_cust_accounts_all hca
                                 WHERE hca.cust_account_id = pn_cust_acct_id)
                           AND primary_flag = 'Y';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_raw_phone   := NULL;
                END;
            END IF;
        END IF;

        IF ln_raw_phone IS NOT NULL
        THEN
            ln_phone_no   := phone_format_f (ln_raw_phone);
            RETURN ln_phone_no;
        ELSE
            RETURN NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    /* Function to find Factored customer */
    FUNCTION is_fact_cust_f (pv_order_number   VARCHAR2,
                             pn_cust_acct      NUMBER,
                             pn_bill_to        NUMBER -- Commented   reverted By BT Technology Team on 01-DEC-2014 (version 1.2) for Transaction PDF File Generation – Deckers
                                                     )
        RETURN VARCHAR2
    IS
        lv_fact_flag    VARCHAR2 (1);
        lv_on_attrib    VARCHAR2 (240);
        -- lv_cs_attrib    VARCHAR2 (1);                                -- Commented By BT Technology Team on 02-DEC-2014 (version 1.2)
        lv_css_attrib   VARCHAR2 (1);
    BEGIN
        lv_fact_flag   := 'N';
        lv_on_attrib   := 'N';

        BEGIN
            SELECT UPPER (TRIM (attribute13))
              INTO lv_on_attrib
              FROM apps.oe_order_headers_all ooha
             WHERE     order_number = pv_order_number
                   -- Started added by BT Technology Team on 02-DEC-2014 (version 1.2)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.oe_order_lines_all oola, apps.ra_terms rt
                             WHERE     oola.header_id = ooha.header_id
                                   AND oola.payment_term_id = rt.term_id
                                   AND rt.NAME IN
                                           ('CREDIT CARD', 'PREPAY', 'COD'));

            -- Ended added by BT Technology Team on 02-DEC-2014 (version 1.2)
            IF lv_on_attrib IS NOT NULL
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'except lv_on_attrib=' || lv_on_attrib);
                RETURN lv_on_attrib;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_on_attrib   := 'N';
        END;

        IF lv_on_attrib != 'Y' OR TRIM (lv_on_attrib) IS NULL
        THEN
            lv_css_attrib   := 'N';

            -- Started Commented by BT Technology Team on 02-DEC-2014 (version 1.2)
            /*        BEGIN
                       SELECT NVL (hcpc.attribute1, 'N')
                         INTO lv_cs_attrib
                         FROM apps.hz_customer_profiles hcp,
                              apps.hz_cust_profile_classes hcpc
                        WHERE hcp.profile_class_id = hcpc.profile_class_id
                          AND hcpc.attribute1 = 'Y'
                          AND hcpc.status = 'A'
                          AND hcp.cust_account_id = pn_cust_acct
                          AND hcp.site_use_id = pn_bill_to;

                       IF lv_cs_attrib = 'Y'
                       THEN
                          lv_fact_flag := 'Y';
                          RETURN lv_fact_flag;
                       END IF;
                    EXCEPTION
                       WHEN OTHERS
                       THEN
                          lv_fact_flag := 'N';
                          lv_cs_attrib := 'N';
                    END;
                 END IF;

               IF lv_cs_attrib != 'Y' OR TRIM (lv_cs_attrib) IS NULL
                 THEN
                    lv_css_attrib := 'N'; */
            -- Ended Commented by BT Technology Team on 02-DEC-2014 (version 1.2)
            BEGIN
                SELECT NVL (hcpc.attribute1, 'N')
                  INTO lv_css_attrib
                  FROM apps.hz_customer_profiles hcp, apps.hz_cust_profile_classes hcpc
                 WHERE     hcp.profile_class_id = hcpc.profile_class_id
                       AND hcpc.attribute1 = 'Y'
                       AND hcpc.status = 'A'
                       AND hcp.cust_account_id = pn_cust_acct
                       AND hcp.site_use_id IS NULL;

                IF lv_css_attrib = 'Y'
                THEN
                    lv_fact_flag   := 'Y';
                    RETURN lv_fact_flag;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_fact_flag    := 'N';
                    lv_css_attrib   := 'N';
            END;
        END IF;

        RETURN lv_fact_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_fact_flag   := 'N';
            RETURN lv_fact_flag;
    END;

    FUNCTION is_credit_check_req_f (pn_cust_acct NUMBER, pn_bill_to NUMBER)
        RETURN VARCHAR2
    IS
        lv_check_req_flag   VARCHAR2 (1) := 'N';
        lv_cs_attrib        VARCHAR2 (1);
        lv_css_attrib       VARCHAR2 (1);
    BEGIN
        lv_css_attrib   := 'N';

        BEGIN
            SELECT NVL (hcp.attribute1, 'N')
              INTO lv_cs_attrib
              FROM apps.hz_customer_profiles hcp
             WHERE     hcp.attribute1 = 'Y'
                   AND hcp.status = 'A'
                   AND hcp.cust_account_id = pn_cust_acct
                   AND hcp.site_use_id = pn_bill_to;

            IF lv_cs_attrib = 'Y'
            THEN
                lv_check_req_flag   := 'Y';
                RETURN lv_check_req_flag;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_check_req_flag   := NULL;
                lv_cs_attrib        := 'N';
        END;

        IF lv_cs_attrib != 'Y' OR TRIM (lv_cs_attrib) IS NULL
        THEN
            lv_css_attrib   := 'N';

            BEGIN
                SELECT NVL (hcp.attribute1, 'N')
                  INTO lv_css_attrib
                  FROM apps.hz_customer_profiles hcp
                 WHERE     hcp.attribute1 = 'Y'
                       AND hcp.status = 'A'
                       AND hcp.cust_account_id = pn_cust_acct
                       AND hcp.site_use_id IS NULL;

                IF lv_css_attrib = 'Y'
                THEN
                    lv_check_req_flag   := 'Y';
                    RETURN lv_check_req_flag;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_check_req_flag   := NULL;
                    lv_css_attrib       := 'N';
            END;
        END IF;

        RETURN NVL (lv_check_req_flag, 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_check_req_flag   := 'N';
            RETURN lv_check_req_flag;
    END;

    /* Procedure for Order Out bound */
    PROCEDURE order_outbound (errbuf                   OUT VARCHAR2,
                              retcode                  OUT VARCHAR2,
                              pv_new_orders         IN     VARCHAR2,
                              pv_brand              IN     VARCHAR2,
                              pd_from_date          IN     VARCHAR2,
                              pd_to_date            IN     VARCHAR2,
                              pv_days               IN     NUMBER,
                              --   Started added by BT Technology Team on 16-JAN-2015 version(2.1)
                              pd_order_from_date    IN     VARCHAR2,
                              pd_order_to_date      IN     VARCHAR2,
                              --   Ended added by BT Technology Team on 16-JAN-2015 version(2.1)
                              --  Started added by BT Technology Team on 16-FEB-2015 version(2.1)
                              p_order_number_from   IN     NUMBER,
                              p_order_number_to     IN     NUMBER--   Ended added by BT Technology Team on 16-FEB-2015 version(2.1)
                                                                 )
    IS
        CURSOR c_main IS
              SELECT DISTINCT
                     apps.fnd_profile.VALUE ('DO CIT: CLIENT NUMBER')
                         client_number,
                     NULL
                         trade_style,
                     'A'
                         record_type,
                     cust_acct.account_number
                         customer_number,
                     party.party_name
                         customer_name,
                     bill_loc.address1
                         customer_address1,
                     bill_loc.address2
                         customer_address2,
                     bill_loc.city
                         customer_city,
                     bill_loc.state
                         customer_state_abbr,
                     bill_loc.postal_code
                         zip,
                     (SELECT SUBSTR (meaning, 1, 17)
                        FROM apps.fnd_common_lookups
                       WHERE     lookup_type = 'PER_US_COUNTRY_CODE'
                             AND enabled_flag = 'Y'
                             AND lookup_code = bill_loc.country)
                         country,
                     bill_loc.country
                         customer_country_code,
                     apps.xxdoom_cit_int_pkg.cust_phone_f (
                         cust_acct.cust_account_id,
                         h.invoice_to_org_id)
                         customer_phone_number,
                     cust_acct.cust_account_id,
                     bill_su.site_use_id,
                     bill_ps.party_site_id,
                     party.party_id
                FROM apps.oe_order_headers_all h, apps.oe_order_lines_all l, apps.hz_cust_site_uses_all bill_su,
                     apps.hz_party_sites bill_ps, apps.hz_locations bill_loc, apps.hz_parties party,
                     apps.hz_cust_accounts cust_acct, apps.hz_cust_acct_sites_all bill_cas
               WHERE     h.header_id = l.header_id
                     AND h.org_id = apps.fnd_profile.VALUE ('ORG_ID')
                     AND h.flow_status_code = 'BOOKED'
                     AND l.line_category_code = 'ORDER'
                     AND l.flow_status_code NOT IN ('CLOSED', 'CANCELLED')
                     AND h.invoice_to_org_id = bill_su.site_use_id
                     AND bill_su.cust_acct_site_id = bill_cas.cust_acct_site_id
                     AND bill_cas.party_site_id = bill_ps.party_site_id
                     AND bill_loc.location_id = bill_ps.location_id
                     AND h.sold_to_org_id = cust_acct.cust_account_id
                     AND cust_acct.party_id = party.party_id
                     AND bill_ps.party_id = party.party_id
                     AND 'Y' =
                         is_fact_cust_f (h.order_number,
                                         cust_acct.cust_account_id,
                                         bill_su.site_use_id --Commented  reverted by BT Technology Team  19-JAN-2015(version 1.2)      for Transaction PDF File Generation – Deckers
                                                            )
                     --AND h.ordered_date >= NVL (to_date(pd_from_date,'YYYY/MM/DD HH24:MI:SS'), h.ordered_date)
                     --AND h.ordered_date <= NVL (to_date(pd_to_date,'YYYY/MM/DD HH24:MI:SS'), h.ordered_date)
                     -- Started commented by BT Technology Team on 15-JAN-2015 version(2.1)
                     /*   AND h.request_date >=

        NVL (TO_DATE (pd_from_date,
                                                     'YYYY/MM/DD HH24:MI:SS'
                                                    ),
                                            SYSDATE
                                           )
                            AND h.request_date <=
                                -- Started commented by BT Technology Team on 15-JAN-2015 version(2.1)
                                   /*    NVL
                                          (TO_DATE (pd_to_date, 'YYYY/MM/DD HH24:MI:SS'),
                                             SYSDATE
                                           + NVL
                                                (pv_days,
                                                 apps.fnd_profile.VALUE
                                                                ('DO CIT: NUMBER OF DAYS')
                                                )
                                          )*/


                     AND h.request_date >=
                         NVL (
                             TO_DATE (
                                 fnd_date.canonical_to_date (pd_from_date)),
                             SYSDATE)
                     AND h.request_date <=
                         NVL (
                             TO_DATE (fnd_date.canonical_to_date (pd_to_date)),
                               SYSDATE
                             + NVL (
                                   pv_days,
                                   apps.fnd_profile.VALUE (
                                       'DO CIT: NUMBER OF DAYS')))
                     -- Ended modified by BT Technology Team on 15-JAN-2015 version(2.1)
                     AND h.attribute5 = NVL (pv_brand, h.attribute5)
                     -- Started added by BT Technology Team on 16-JAN-2015 version(2.1)
                     AND h.ordered_date >=
                         NVL (
                             TO_DATE (
                                 fnd_date.canonical_to_date (
                                     pd_order_from_date)),
                             h.ordered_date)
                     AND h.ordered_date <=
                         NVL (
                             TO_DATE (
                                 fnd_date.canonical_to_date (pd_order_to_date)),
                             h.ordered_date)
                     --     Ended Added by BT Technology Team on 16-JAN-2015 version(2.1)
                     -- Started added by BT Technology Team on 16-FEB-2015 version(2.1)
                     AND h.order_number BETWEEN NVL (p_order_number_from,
                                                     h.order_number)
                                            AND NVL (p_order_number_to,
                                                     h.order_number)
                     -- Ended added by BT Technology Team on 16-FEB-2015 version(2.1)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxdo_cit_order_send_history
                               WHERE     'Y' = pv_new_orders
                                     AND order_number = h.order_number)
            ORDER BY customer_name;

        CURSOR c_main1 (pn_cust_account_id IN NUMBER)
        IS
              SELECT DISTINCT ooha.order_number, ooha.header_id, LPAD (ROUND (SUM (oola.ordered_quantity * oola.unit_selling_price)), 8, 0) order_amount,
                              TO_CHAR (NVL (MIN (oola.schedule_ship_date), MIN (oola.request_date)), 'MMDDYY') start_ship_date, TO_CHAR (NVL (MAX (oola.schedule_ship_date), MAX (oola.request_date)), 'MMDDYY') ship_completion_date
                /*MIN (TO_CHAR (nvl(oola.schedule_ship_date,oola.request_date), 'MMDDYY')
                    ) start_ship_date,
                MAX (TO_CHAR (nvl(oola.schedule_ship_date,oola.request_date), 'MMDDYY')
                    ) ship_completion_date*/
                FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
               WHERE     ooha.header_id = oola.header_id
                     AND ooha.org_id = apps.fnd_profile.VALUE ('ORG_ID')
                     AND ooha.attribute5 = NVL (pv_brand, ooha.attribute5)
                     AND ooha.flow_status_code = 'BOOKED'
                     AND oola.line_category_code = 'ORDER'
                     AND oola.flow_status_code NOT IN ('CLOSED', 'CANCELLED')
                     AND ooha.sold_to_org_id = pn_cust_account_id
                     --AND ooha.ordered_date >= NVL (to_date(pd_from_date,'YYYY/MM/DD HH24:MI:SS'), ooha.ordered_date)
                     --AND ooha.ordered_date <= NVL (to_date(pd_to_date,'YYYY/MM/DD HH24:MI:SS'), ooha.ordered_date)
                     AND ooha.request_date >=
                         -- Started commented by BT Technology Team on 15-JAN-2015 version(2.1)
                         /*  NVL (TO_DATE (pd_from_date,
                                           'YYYY/MM/DD HH24:MI:SS'
                                          ),
                                  SYSDATE
                                 )*/
                         NVL (
                             TO_DATE (
                                 fnd_date.canonical_to_date (pd_from_date)),
                             SYSDATE)
                     -- Ended modified by BT Technology Team on 15-JAN-2015 version(2.1)
                     AND ooha.request_date <=
                         -- Started commented by BT Technology Team on 15-JAN-2015 version(2.1)
                         /*   NVL
                                (TO_DATE (pd_to_date, 'YYYY/MM/DD HH24:MI:SS'),
                                   SYSDATE
                                 + NVL
                                      (pv_days,
                                       apps.fnd_profile.VALUE
                                                      ('DO CIT: NUMBER OF DAYS')
                                      )
                                )*/
                         NVL (
                             TO_DATE (fnd_date.canonical_to_date (pd_to_date)),
                               SYSDATE
                             + NVL (
                                   pv_days,
                                   apps.fnd_profile.VALUE (
                                       'DO CIT: NUMBER OF DAYS')))
                     -- Ended modified by BT Technology Team on 15-JAN-2015 version(2.1)
                     -- Started added by BT Technology Team on 16-JAN-2015 version(2.1)
                     AND ooha.ordered_date >=
                         NVL (
                             TO_DATE (
                                 fnd_date.canonical_to_date (
                                     pd_order_from_date)),
                             ooha.ordered_date)
                     AND ooha.ordered_date <=
                         NVL (
                             TO_DATE (
                                 fnd_date.canonical_to_date (pd_order_to_date)),
                             ooha.ordered_date)
                     --     Ended Added by BT Technology Team on 16-JAN-2015 version(2.1)
                     -- Started added by BT Technology Team on 16-FEB-2015 version(2.1)
                     AND ooha.order_number BETWEEN NVL (p_order_number_from,
                                                        ooha.order_number)
                                               AND NVL (p_order_number_to,
                                                        ooha.order_number)
                     -- Ended added by BT Technology Team on 16-FEB-2015 version(2.1)
                     AND 'Y' =
                         is_fact_cust_f (ooha.order_number,
                                         ooha.sold_to_org_id,
                                         ooha.invoice_to_org_id -- Commented reverted  BT Technology Team on 12-01-2014 (version 1.2)for Transaction PDF File Generation – Deckers
                                                               )
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxdo_cit_order_send_history
                               WHERE     'Y' = pv_new_orders
                                     AND order_number = ooha.order_number)
            GROUP BY ooha.order_number, ooha.header_id;

        --  lv_file_handle   UTL_FILE.file_type;
        lv_output         VARCHAR2 (32767);
        lv_output1        VARCHAR2 (32767);
        lv_dir            VARCHAR2 (300);
        lv_file_name      VARCHAR2 (100);
        ln_na_count       NUMBER;
        ln_o_count        NUMBER;
        ln_o_amount       NUMBER;
        ln_om_cit_s       NUMBER;
        lv_term_days1     VARCHAR2 (5);
        lv_credit_check   VARCHAR2 (5);
    BEGIN
        fnd_global.apps_initialize (fnd_global.user_id,
                                    fnd_global.resp_id,
                                    fnd_global.resp_appl_id);
        mo_global.init ('AR');
        mo_global.set_policy_context ('S', fnd_profile.VALUE ('ORG_ID'));

        --lv_dir := '/tmp';
        SELECT xxdo.xxdo_om_cit_int_s.NEXTVAL INTO ln_om_cit_s FROM DUAL;

        /*lv_file_name :=
              'CIT_CreditRequest_'
           || apps.fnd_profile.VALUE ('DO CIT: CLIENT NUMBER')
           || ln_om_cit_s;
        lv_file_handle := UTL_FILE.fopen (lv_dir, lv_file_name, 'w', 255); */
        -- Start changes by BT Technology Team on 02-DEC-2014 (version 1.2)
        /*apps.fnd_file.put_line
                 (apps.fnd_file.LOG,
                  'Customer Phone number is Null or Credit Check required is N '
                 );*/
        -- End changes by BT Technology Team on 02-DEC-2014 (version 1.2)
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Client No'
            || RPAD (' ', 2, ' ')
            || RPAD ('R', 1, ' ')
            || RPAD ('Customer_Number', 15, ' ')
            || RPAD ('Order_Number', 22, ' ')
            || RPAD ('Order_Amount', 8, ' ')
            || ' '
            || RPAD ('Start_Date', 10, ' ')
            || RPAD (' ', 3, ' ')
            || RPAD ('Completion_Date', 10, ' ')
            || ' '
            || RPAD (' ', 101, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            '---------------------------------------------------------------------------------------------------------------------');
        --apps.fnd_file.put_line (apps.fnd_file.output,'$$ADD ID=EP003F BID=''CO898Y'' PASSWORD=UNAS'); -- Commented by Madhav Dhurjaty 12/18/13 for CIT change
        /*            utl_file.put_line(lv_file_handle,'$$ADD ID=EP003F   BID=''CO6767'' PASSWORD=SDTR'||' hex 0D0A');
        */
        ln_na_count   := 0;
        ln_o_count    := 0;
        ln_o_amount   := 0;

        FOR i IN c_main
        LOOP
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'Enetered');

            BEGIN
                lv_credit_check   := 'N';

                SELECT is_credit_check_req_f (i.cust_account_id, i.site_use_id)
                  INTO lv_credit_check
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_credit_check   := NULL;
            END;

            lv_output   :=
                   RPAD (i.client_number, 4, ' ')
                || RPAD (' ', 2, ' ')
                || RPAD (i.record_type, 1, ' ')
                || RPAD (i.customer_number, 15, ' ')
                || RPAD (i.customer_name, 30, ' ')
                || RPAD (i.customer_address1, 30, ' ')
                || RPAD (NVL (i.customer_address2, ' '), 30, ' ')
                || RPAD (i.customer_city, 17, ' ')
                || RPAD (i.customer_state_abbr, 2, ' ')
                || RPAD (i.zip, 9, ' ')
                || RPAD (i.country, 17, ' ')
                || RPAD (i.customer_country_code, 3, ' ')
                || RPAD (i.customer_phone_number, 10, ' ');

            --  ||'hex 0D0A';
            --|| CHR(13)||CHR(10);
            IF NVL (lv_credit_check, 'Y') = 'Y'
            THEN
                apps.fnd_file.put_line (apps.fnd_file.output, lv_output);
                ln_na_count   := ln_na_count + 1;
            END IF;

            -- Start changes by BT Technology Team on 02-DEC-2014 (version 1.2)
            /*IF TRIM (i.customer_phone_number) IS NULL OR lv_credit_check != 'Y'
            THEN
               apps.fnd_file.put_line (apps.fnd_file.LOG, lv_output);
               retcode := 1;
            END IF;*/
            -- End changes by BT Technology Team on 02-DEC-2014 (version 1.2)

            FOR j IN c_main1 (i.cust_account_id)
            LOOP
                lv_term_days1   := NULL;
                lv_term_days1   :=
                    cit_terms_date_f (j.header_id, j.start_ship_date);
                lv_output       :=
                       RPAD (i.client_number, 4, ' ')
                    || RPAD (' ', 2, ' ')
                    || RPAD ('R', 1, ' ')
                    || RPAD (i.customer_number, 15, ' ')
                    || RPAD (j.order_number, 22, ' ')
                    || LPAD (j.order_amount, 8, 0)
                    || ' '
                    || RPAD (j.start_ship_date, 6, ' ')
                    || RPAD (lv_term_days1, 3, ' ')
                    || RPAD (j.ship_completion_date, 6, ' ')
                    || ' '
                    || RPAD (' ', 101, ' ');

                -- ||'hex 0D0A';
                -- CHR(13)||CHR(10);
                IF NVL (lv_credit_check, 'Y') = 'Y'
                THEN
                    apps.fnd_file.put_line (apps.fnd_file.output, lv_output);
                    ln_o_count    := ln_o_count + 1;
                    ln_o_amount   := ln_o_amount + j.order_amount;
                END IF;

                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'i.customer_phone_number=' || i.customer_phone_number);
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'lv_credit_check=' || lv_credit_check);

                IF    TRIM (i.customer_phone_number) IS NULL
                   OR lv_credit_check != 'Y'
                THEN
                    apps.fnd_file.put_line (apps.fnd_file.LOG, lv_output);
                    retcode   := 1;
                END IF;

                INSERT INTO xxdo.xxdo_cit_order_send_history (creation_date, file_sequence_number, order_number, customer_number, min_request_date, max_request_date
                                                              , order_amount)
                     VALUES (SYSDATE, ln_om_cit_s, j.order_number,
                             i.customer_number, TO_DATE (j.start_ship_date, 'MMDDYY'), TO_DATE (j.ship_completion_date, 'MMDDYY')
                             , j.order_amount);

                COMMIT;
            END LOOP;
        END LOOP;

        lv_output     :=
               RPAD (apps.fnd_profile.VALUE ('DO CIT: CLIENT NUMBER'),
                     4,
                     ' ')
            || RPAD ('99', 2, ' ')
            || RPAD ('S', 1, ' ')
            || RPAD (9, 15, 9)
            || LPAD (ln_na_count, 6, 0)
            || LPAD (ln_o_count, 6, 0)
            || RPAD (' ', 6, ' ')
            || LPAD (ln_o_amount, 12, 0)
            || RPAD (' ', 118, ' ');
        -- ||'hex 0D0A';
        --|| CHR(13)||CHR(10);
        -- IF lv_credit_check='Y' THEN
        apps.fnd_file.put_line (apps.fnd_file.output, lv_output);
        --  END IF;

        /* IF  lv_credit_check !='Y'
         THEN
            apps.fnd_file.put_line (apps.fnd_file.log, lv_output);
            retcode :=1;
         END IF; */
        lv_output1    :=
               RPAD ('9999', 4, ' ')
            || RPAD ('99', 2, ' ')
            || RPAD ('T', 1, ' ')
            || RPAD (9, 15, 9)
            || LPAD (ln_na_count, 6, 0)
            || LPAD (ln_o_count, 6, 0)
            || RPAD (' ', 6, ' ')
            || LPAD (ln_o_amount, 12, 0)
            || RPAD (' ', 12, ' ')
            || RPAD (TO_CHAR (SYSDATE, 'MMDDYY'), 6, ' ')
            || RPAD (' ', 100, ' ');
        --||'hex 0D0A';
        -- || CHR(13)||CHR(10);
        --  IF lv_credit_check='Y' THEN
        apps.fnd_file.put_line (apps.fnd_file.output, lv_output1);
        --  END IF;
        /*
         IF  lv_credit_check !='Y'
         THEN
            apps.fnd_file.put_line (apps.fnd_file.log, lv_output1);
            retcode :=1;
         END IF; */
        COMMIT;
    --   UTL_FILE.fclose (lv_file_handle);
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'other error-' || SQLERRM);
    END order_outbound;

    /* Procedure for Main  */
    PROCEDURE main (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_new_orders IN VARCHAR2, pv_brand IN VARCHAR2, pd_from_date IN VARCHAR2, pd_to_date IN VARCHAR2, pv_days IN NUMBER, pv_transmit_file IN VARCHAR2, --   Started added by BT Technology Team on 16-JAN-2015 version(2.1)
                                                                                                                                                                                                                         pd_order_from_date IN VARCHAR2
                    , pd_order_to_date IN VARCHAR2, --   Ended added by BT Technology Team on 16-JAN-2015  version(2.1)
                                                    --  Started added by BT Technology Team on 16-FEB-2015 version(2.1)
                                                    p_order_number_from IN NUMBER, p_order_number_to IN NUMBER--   Ended added by BT Technology Team on 16-FEB-2015 version(2.1)
                                                                                                              )
    IS
        /* Variaables for calling the ftp program */
        lv_request_id         NUMBER := 0;
        lv_request_id1        NUMBER := 0;
        lv_source_path        VARCHAR2 (100);
        lv_filename           VARCHAR2 (60);
        lv_fileserver         VARCHAR2 (80);
        lv_phasecode          VARCHAR2 (100) := NULL;
        lv_statuscode         VARCHAR2 (100) := NULL;
        lv_devphase           VARCHAR2 (100) := NULL;
        lv_devstatus          VARCHAR2 (100) := NULL;
        lv_returnmsg          VARCHAR2 (200) := NULL;
        lv_concreqcallstat    BOOLEAN := FALSE;
        lv_concreqcallstat1   BOOLEAN := FALSE;
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               fnd_global.user_id
            || ' '
            || fnd_global.resp_id
            || ' '
            || fnd_global.resp_appl_id);
        fnd_global.apps_initialize (fnd_global.user_id,
                                    fnd_global.resp_id,
                                    fnd_global.resp_appl_id);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Org Id' || fnd_profile.VALUE ('ORG_ID'));
        mo_global.init ('AR');
        mo_global.set_policy_context ('S', fnd_profile.VALUE ('ORG_ID'));
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Org Id' || mo_global.get_current_org_id);
        lv_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'XXDO',
                program       => 'XXDOOM005A',
                description   => '',
                start_time    => TO_CHAR (SYSDATE, 'DD-MON-YY'),
                sub_request   => FALSE,
                argument1     => pv_new_orders,
                argument2     => pv_brand,
                argument3     => pd_from_date,
                argument4     => pd_to_date,
                argument5     => pv_days,
                --   Started added by BT Technology Team on 16-JAN-2015 version(2.1)
                argument6     => pd_order_from_date,
                argument7     => pd_order_to_date,
                --   Ended added by BT Technology Team on 16-JAN-2015   version(2.1)
                --   Started added by BT Technology Team on 16-FEB-2015 version(2.1)
                argument8     => p_order_number_from,
                argument9     => p_order_number_to--   Ended added by BT Technology Team on 16-JAN-2015   version(2.1)
                                                  );
        COMMIT;
        lv_concreqcallstat1   :=
            apps.fnd_concurrent.wait_for_request (lv_request_id,
                                                  5 -- wait 5 seconds between db checks
                                                   ,
                                                  0,
                                                  lv_phasecode,
                                                  lv_statuscode,
                                                  lv_devphase,
                                                  lv_devstatus,
                                                  lv_returnmsg);
        COMMIT;
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Request id is ' || lv_request_id);

        /* getting the Source Path */
        BEGIN
            SELECT SUBSTR (outfile_name, 1, INSTR (outfile_name, 'out') + 2)
              INTO lv_source_path
              FROM apps.fnd_concurrent_requests
             WHERE request_id = lv_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Concurrent Request id path is still  not available erroring out ');
                pv_retcode   := 2;
        END;

        /* Retrieving the File Server Name */
        BEGIN
            SELECT DECODE (applications_system_name, 'PROD', apps.fnd_profile.VALUE ('DO CIT: FTP Address'), apps.fnd_profile.VALUE ('DO CIT: Test FTP Address')) file_server_name
              INTO lv_fileserver
              FROM apps.fnd_product_groups;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Unable to fetch the File server name');
                pv_retcode   := 2;
        END;

        lv_filename   := 'o' || lv_request_id || '.out';

        IF pv_transmit_file = 'Y'
        THEN
            BEGIN
                lv_request_id1   :=
                    apps.fnd_request.submit_request (application => 'XXDO', program => 'XXDOOM005B', description => '', start_time => TO_CHAR (SYSDATE, 'DD-MON-YY'), sub_request => FALSE, argument1 => lv_source_path, argument2 => 'CIT_CREDITREQUEST_', argument3 => lv_filename, argument4 => lv_fileserver
                                                     , argument5 => 'data.CO'--Added by Madhav Dhurjaty  on 12/13/13 CIT FTP Change
                                                                             --filetype=data.DI for invoice, data.CO for Orders
                                                                             );
                COMMIT;
                lv_phasecode    := NULL;
                lv_statuscode   := NULL;
                lv_devphase     := NULL;
                lv_devstatus    := NULL;
                lv_returnmsg    := NULL;
                lv_concreqcallstat   :=
                    apps.fnd_concurrent.wait_for_request (lv_request_id1,
                                                          5 -- wait 5 seconds between db checks
                                                           ,
                                                          0,
                                                          lv_phasecode,
                                                          lv_statuscode,
                                                          lv_devphase,
                                                          lv_devstatus,
                                                          lv_returnmsg);
                COMMIT;

                /* Updating the Processed_flag to Y after Transmit is done */
                UPDATE xxdo.xxdo_cit_order_send_history
                   SET processed_flag   = 'Y'
                 WHERE processed_flag = 'N';

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Exception occured while running ftp program'
                        || SQLERRM);
                    pv_retcode   := 2;
            END;
        ELSE
            /* Updating the Processed_flag to Y after Transmit is done */
            DELETE FROM xxdo.xxdo_cit_order_send_history
                  WHERE processed_flag = 'N';

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Exception occured while running Main program' || SQLERRM);
            pv_retcode   := 2;
    END;
END xxdoom_cit_int_pkg;
/
