--
-- XXDO_SALES_PROGRAM_ALERT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDO_SALES_PROGRAM_ALERT_PKG
IS
    FUNCTION GET_EMAIL_RECIPS (v_lookup_type VARCHAR2)
        RETURN DO_MAIL_UTILS.tbl_recips
    IS
        V_DEF_MAIL_RECIPS   DO_MAIL_UTILS.tbl_recips;

        CURSOR c_recips IS
            SELECT lookup_code, meaning, description
              FROM fnd_lookup_values
             WHERE     lookup_type = v_lookup_type
                   AND enabled_flag = 'Y'
                   AND language = 'US'
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (START_DATE_ACTIVE, SYSDATE))
                                   AND TRUNC (
                                           NVL (END_DATE_ACTIVE, SYSDATE) + 1);
    BEGIN
        V_DEF_MAIL_RECIPS.DELETE;

        FOR c_recip IN c_recips
        LOOP
            V_DEF_MAIL_RECIPS (V_DEF_MAIL_RECIPS.COUNT + 1)   :=
                c_recip.meaning;
        END LOOP;

        RETURN V_DEF_MAIL_RECIPS;
    END;

    PROCEDURE XXDO_SALES_PROGRAM_ALERT (p_d1 OUT VARCHAR2, p_d2 OUT VARCHAR2)
    IS
        v_out_line          VARCHAR2 (2000);

        l_counter           NUMBER := 0;
        l_ret_val           NUMBER := 0;

        V_DEF_MAIL_RECIPS   DO_MAIL_UTILS.tbl_recips;

        CURSOR c_detail IS
              SELECT ooha.attribute5 brand, ooha.order_number, ooha.cust_po_number,
                     rc.customer_name, raa.state, TRUNC (ooha.creation_date) creation_date,
                     TRUNC (ooha.request_date) request_date, rt.name terms, ott.name AS order_type,
                     jrs.name AS salesrep, NVL (fu.description, fu.user_name) AS created_by, SUM (oola.ordered_quantity * oola.unit_selling_price) AS amount
                FROM oe_order_lines_all oola, oe_order_headers_all ooha, oe_transaction_types ott,
                     ra_terms rt /*Start Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                                                            --,ra_customers rc
                                                       --,ra_addresses_all raa
                     , xxd_ra_customers_v rc, xxd_ra_addresses_morg_v raa /*End Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                                                                         ,
                     jtf_rs_salesreps jrs, fnd_user fu
               WHERE     ooha.header_id = oola.header_id
                     /*Start Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                     --and raa.org_id = 2
                     AND ooha.org_id = (SELECT ORGANIZATION_ID
                                          FROM hr_operating_units
                                         WHERE NAME = 'Deckers US OU')
                     /*End Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                     AND oola.org_id = ooha.org_id
                     AND ooha.creation_date >= TRUNC (SYSDATE - 100)
                     AND oola.cancelled_flag != 'Y'
                     AND (ooha.open_flag IS NULL OR ooha.open_flag = 'Y')
                     AND (oola.open_flag IS NULL OR oola.open_flag = 'Y')
                     AND ooha.payment_term_id = rt.term_id
                     AND ooha.payment_term_id = ott.attribute5
                     AND ott.transaction_type_id = ooha.order_type_id
                     AND (ott.end_date_active IS NULL OR ott.end_date_active >= TRUNC (SYSDATE - 100))
                     /*-------------------------------------------------------------------------------------
                   Start Changes by BT Technology Team on 03-APR-2015 -  v1.1
                   ---------------------------------------------------------------------------------------
                    -- and ott.transaction_type_id > 1108
                    -- and transaction_type_id not in (1391,1592)
                   */
                     AND transaction_type_id NOT IN
                             (SELECT ott.transaction_type_id
                                FROM oe_transaction_types_vl OTT, fnd_lookup_values flv
                               WHERE     flv.lookup_type =
                                         'DO_SALES_PGM_EXCLUDE_ORDERS'
                                     AND flv.LANGUAGE = 'US'
                                     AND flv.enabled_flag = 'Y'
                                     AND FLV.MEANING = OTT.NAME)
                     /*----------------------------------------------------------------------------------------
                     End changes by BT Technology Team on 03-APR-2015 -  v1.1
                     ----------------------------------------------------------------------------------------*/
                     AND ooha.sold_to_org_id = rc.customer_id
                     AND raa.customer_id = rc.customer_id
                     AND raa.bill_to_flag = 'P'
                     /*Start Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                     --and raa.org_id = 2
                     AND raa.org_id = (SELECT ORGANIZATION_ID
                                         FROM hr_operating_units
                                        WHERE NAME = 'Deckers US OU')
                     /*End Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                     AND ooha.salesrep_id = jrs.salesrep_id(+)
                     AND ooha.created_by = fu.user_id
            GROUP BY ooha.attribute5, ooha.order_number, ooha.cust_po_number,
                     rc.customer_name, raa.state, TRUNC (ooha.creation_date),
                     TRUNC (ooha.request_date), rt.name, ott.name,
                     jrs.name, NVL (fu.description, fu.user_name);

        ex_no_recips        EXCEPTION;
        ex_no_sender        EXCEPTION;
        ex_no_data_found    EXCEPTION;
    BEGIN
        DO_DEBUG_UTILS.SET_LEVEL (1);

        IF fnd_profile.VALUE ('DO_DEF_ALERT_SENDER') IS NULL
        THEN
            RAISE ex_no_sender;
        END IF;

        DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, /*Start Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                                                                               --v_application_id => 'DO_OM_REPORTS.SALES_PROGRAM_ALERT',
                                                                               v_application_id => 'XXDO_DO_OM_REPORTS.XXDO_SALES_PROGRAM_ALERT', /*End Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                                                                                                                                                  v_debug_text => 'Recipients...'
                              , l_debug_level => 1);


        V_DEF_MAIL_RECIPS   := GET_EMAIL_RECIPS ('DO_SALES_PROGRAM_ALERT');

        FOR i IN 1 .. V_DEF_MAIL_RECIPS.COUNT
        LOOP
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, /*Start Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                                                                                   --v_application_id => 'DO_OM_REPORTS.SALES_PROGRAM_ALERT',
                                                                                   v_application_id => 'XXDO_DO_OM_REPORTS.XXDO_SALES_PROGRAM_ALERT', /*End Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                                                                                                                                                      v_debug_text => V_DEF_MAIL_RECIPS (i)
                                  , l_debug_level => 1);
        END LOOP;

        IF V_DEF_MAIL_RECIPS.COUNT < 1
        THEN
            RAISE ex_no_recips;
        END IF;

        DO_MAIL_UTILS.SEND_MAIL_HEADER (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), V_DEF_MAIL_RECIPS, 'Sales Program Alert - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                        , l_ret_val);
        DO_MAIL_UTILS.SEND_MAIL_LINE (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            l_ret_val);
        DO_MAIL_UTILS.SEND_MAIL_LINE ('--boundarystring', l_ret_val);
        DO_MAIL_UTILS.SEND_MAIL_LINE ('Content-Type: text/plain', l_ret_val);
        DO_MAIL_UTILS.SEND_MAIL_LINE ('', l_ret_val);
        DO_MAIL_UTILS.SEND_MAIL_LINE ('See attachment for report details.',
                                      l_ret_val);
        DO_MAIL_UTILS.SEND_MAIL_LINE ('--boundarystring', l_ret_val);
        DO_MAIL_UTILS.SEND_MAIL_LINE ('Content-Type: text/xls', l_ret_val);
        DO_MAIL_UTILS.SEND_MAIL_LINE (
            'Content-Disposition: attachment; filename="sales program alert.xls"',
            l_ret_val);
        DO_MAIL_UTILS.SEND_MAIL_LINE ('', l_ret_val);

        DO_MAIL_UTILS.SEND_MAIL_LINE (
               'Brand'
            || CHR (9)
            || 'Order Number'
            || CHR (9)
            || 'Cust PO Number'
            || CHR (9)
            || 'Customer Name'
            || CHR (9)
            || 'State'
            || CHR (9)
            || 'Creation Date'
            || CHR (9)
            || 'Start Ship Date'
            || CHR (9)
            || 'Terms'
            || CHR (9)
            || 'Order Type'
            || CHR (9)
            || 'Sales Rep'
            || CHR (9)
            || 'Created By'
            || CHR (9)
            || 'Amount'
            || CHR (9),
            l_ret_val);

        FOR r_detail IN c_detail
        LOOP
            v_out_line   := NULL;

            v_out_line   :=
                   r_detail.brand
                || CHR (9)
                || r_detail.order_number
                || CHR (9)
                || r_detail.cust_po_number
                || CHR (9)
                || r_detail.customer_name
                || CHR (9)
                || r_detail.state
                || CHR (9)
                || r_detail.creation_date
                || CHR (9)
                || r_detail.request_date
                || CHR (9)
                || r_detail.terms
                || CHR (9)
                || r_detail.order_type
                || CHR (9)
                || r_detail.salesrep
                || CHR (9)
                || r_detail.created_by
                || CHR (9)
                || r_detail.amount
                || CHR (9);

            DO_MAIL_UTILS.SEND_MAIL_LINE (v_out_line, l_ret_val);

            l_counter    := l_counter + 1;
        END LOOP;

        IF l_counter = 0
        THEN
            RAISE ex_no_data_found;
        END IF;

        DO_MAIL_UTILS.SEND_MAIL_CLOSE (l_ret_val);
    EXCEPTION
        WHEN ex_no_data_found
        THEN
            ROLLBACK;
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_CONC_OUTPUT, /*Start Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                                                                                   --v_application_id => 'DO_OM_REPORTS.SALES_PROGRAM_ALERT',
                                                                                   v_application_id => 'XXDO_DO_OM_REPORTS.XXDO_SALES_PROGRAM_ALERT', /*End Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                                                                                                                                                      v_debug_text => CHR (10) || 'There are no confirm dates requiring attention.'
                                  , l_debug_level => 1);
            DO_MAIL_UTILS.SEND_MAIL_LINE (
                'There are no orders requiring attention.',
                l_ret_val);
            DO_MAIL_UTILS.SEND_MAIL_CLOSE (l_ret_val);               --Be Safe
        WHEN ex_no_recips
        THEN
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_TABLE, /*Start Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                                                                             --v_application_id => 'DO_OM_REPORTS.SALES_PROGRAM_ALERT',
                                                                             v_application_id => 'XXDO_DO_OM_REPORTS.XXDO_SALES_PROGRAM_ALERT', /*End Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                                                                                                                                                v_debug_text => CHR (10) || 'There were no recipients configured to receive the alert'
                                  , l_debug_level => 1);
            DO_MAIL_UTILS.SEND_MAIL_CLOSE (l_ret_val);               --Be Safe
        WHEN ex_no_sender
        THEN
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_TABLE, /*Start Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                                                                             --v_application_id => 'DO_OM_REPORTS.SALES_PROGRAM_ALERT',
                                                                             v_application_id => 'XXDO_DO_OM_REPORTS.XXDO_SALES_PROGRAM_ALERT', /*End Changes by BT Technology Team on 03-APR-2015 -  v1.1 */
                                                                                                                                                v_debug_text => CHR (10) || 'There is no sender configured.  Check the profile value DO_DEF_ALERT_SENDER'
                                  , l_debug_level => 1);
            DO_MAIL_UTILS.SEND_MAIL_CLOSE (l_ret_val);               --Be Safe
        WHEN OTHERS
        THEN
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_TABLE, v_application_id => 'DO_INVENTORY_ALERTS.PO_CONFIRM_DATE_ALERT', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                  , l_debug_level => 1);
            DO_MAIL_UTILS.SEND_MAIL_CLOSE (l_ret_val);               --Be Safe
    END;
END;
/
