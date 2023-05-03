--
-- XXDO_WMS_3PL_INTERFACE  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_WMS_3PL_INTERFACE"
AS
    /******************************************************************************************
     Modification History:
     Version    By                     Date           Comments

     1.0  BT-Technology Team     22-Nov-2014          Updated for  BT
     1.1  Aravind Kannuri        12-Jun-2019          Changes as per CCR0007979(Macau-EMEA)
     1.2  Aravind Kannuri        22-Jan-2020          Changes as per CCR0008341
     1.3  Greg Jensen            19-May-2020          Changes as per CCR0008621
     1.4  Greg Jensen            13-Jul-2020          Changes as per CCR0008762
     1.5  Greg Jensen            23-Jul-2020          Changes as per CCR0008701, CCR0008762
     1.6  Greg Jensen            01-Oct-2020          Changes as per CCR0008925
     1.7  Satyanarana Kotha      01-Jan-2021          Changes as per CCR0008837
     1.8  Aravind Kannuri        02-Mar-2021          Changes as per CCR0009126
     1.9  Greg Jensen            04-May-2021          Changes as per CCR0009126
     1.10  Tejaswi Gangumalla    20-Mar-2021          Changes as per CCR0008870
  1.11  Aravind Kannuri       18-Aug-2021          Changes as per CCR0009513
  1.12  Balavenu\Aravind K    25-May-2022          Changes as per CCR0009887
  1.13  Arun N Murthy         13-Jan-2023          changes for CCR0010406 which is nothing
  1.13                        13-Jan-2023          but Included Gauravs changes as per CCR0009446
  1.14 Shivanshu              01-FEB-2023          CCR0010347 - Nexus ASN Interface: To modify Pick Ticket consolidation logic
  1.15 Ramesh Reddy           10-MAR-2023          Changes as per CCR0010325
  1.16 Aravind Kannuri        16-Mar-2023          Changes as per CCR0009817(HK Wholesale)
    ******************************************************************************************/
    lg_package_name             CONSTANT VARCHAR2 (200) := 'XXDO_WMS_3PL_INTERFACE';
    g_mail_debugging_p                   VARCHAR2 (1)
        := SUBSTR (
               NVL (apps.do_get_profile_value ('DO_3PL_MAIL_DEBUG'), 'N'),
               1,
               1);
    g_mail_debug_attach_debug_p          VARCHAR2 (1)
        := SUBSTR (
               NVL (apps.do_get_profile_value ('DO_3PL_MAIL_DEBUG_DETAIL'),
                    'N'),
               1,
               1);
    /* Private Types */
    /* Private Variables */
    l_api_version_number                 NUMBER := 1.0;
    l_commit                             VARCHAR2 (1) := apps.fnd_api.g_false;
    c_debugging                          BOOLEAN := TRUE;
    l_mti_source_code           CONSTANT VARCHAR2 (30) := '3PL WMS Interface';
    l_grn_complete              CONSTANT VARCHAR2 (10) := 'GRN COMPLT';
    l_grn_pending               CONSTANT VARCHAR2 (10) := 'PENDING';
    l_grn_error                 CONSTANT VARCHAR2 (10) := 'ERROR';
    l_grn_complete_no_partial   CONSTANT VARCHAR2 (10) := 'GRN CMP NP';
    -- CCR0002036
    l_update_type_status        CONSTANT VARCHAR2 (20) := 'STATUS';
    l_3pl_hold_name             CONSTANT VARCHAR2 (200)
                                             := '3PL Backorder Hold' ;
    l_buffer_number                      NUMBER;
    l_global_user_id                     NUMBER;
    l_global_resp_id                     NUMBER;
    l_global_appn_id                     NUMBER;
    g_n_temp                             NUMBER;
    l_resp_id                            NUMBER;
    l_appn_id                            NUMBER;
    --Start Added for 1.12
    gn_user_id                           NUMBER := fnd_global.user_id;
    gn_login_id                          NUMBER := fnd_global.login_id;
    gn_request_id                        NUMBER := fnd_global.conc_request_id;
    gn_program_id                        NUMBER := fnd_global.conc_program_id;
    gn_program_appl_id                   NUMBER := fnd_global.prog_appl_id;
    gn_resp_appl_id                      NUMBER := fnd_global.resp_appl_id;
    gn_resp_id                           NUMBER := fnd_global.resp_id;
    g_num                                NUMBER := 0;

    --End Added for 1.12

    TYPE shipment_rec IS RECORD
    (
        delivery_detail_id    NUMBER,
        inventory_item_id     NUMBER,
        quantity              NUMBER
    );

    TYPE shipment_tab IS TABLE OF shipment_rec
        INDEX BY BINARY_INTEGER;

    TYPE tabtype_id IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    FUNCTION g_mail_debugging
        RETURN BOOLEAN
    IS
    BEGIN
        IF g_mail_debugging_p = 'Y'
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END;

    FUNCTION g_mail_debugging_attach_debug
        RETURN BOOLEAN
    IS
    BEGIN
        IF g_mail_debug_attach_debug_p = 'Y'
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END;

    PROCEDURE msg (p_message VARCHAR2, p_severity NUMBER:= 10000)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO xxdo.xxd_3pl_lc_int_debug_t (creation_date, log_message, created_by
                                                 , session_id, seq_number)
                 VALUES (SYSDATE,
                         p_message,
                         apps.fnd_global.user_id,
                         USERENV ('SESSIONID'),
                         TO_CHAR (SYSTIMESTAMP, 'YYYYDDMMHH24MISSFF'));

        COMMIT;
        DBMS_OUTPUT.put_line (p_message);
        apps.do_debug_tools.msg (p_message, p_severity);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            ROLLBACK;
    END;

    PROCEDURE msg (p_module     VARCHAR2,
                   p_message    VARCHAR2,
                   p_severity   NUMBER:= 10000)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO xxdo.xxd_3pl_lc_int_debug_t (creation_date, log_message, created_by
                                                 , session_id, seq_number)
                 VALUES (SYSDATE,
                         p_message,
                         apps.fnd_global.user_id,
                         USERENV ('SESSIONID'),
                         TO_CHAR (SYSTIMESTAMP, 'YYYYDDMMHH24MISSFF'));

        COMMIT;
        DBMS_OUTPUT.put_line (p_message);
        apps.do_debug_tools.msg (p_message, p_severity);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            ROLLBACK;
    END;

    PROCEDURE start_debugging
    IS
    BEGIN
        apps.do_debug_tools.start_debugging;
        apps.do_debug_tools.enable_pipe;
    END;

    PROCEDURE stop_debugging
    IS
    BEGIN
        apps.do_debug_tools.stop_debugging;
    END;

    PROCEDURE m_start (l_title VARCHAR2)
    IS
        v_def_mail_recips   apps.do_mail_utils.tbl_recips;
        iretval             VARCHAR2 (4000);
    BEGIN
        IF NOT g_mail_debugging
        THEN
            RETURN;
        END IF;

        v_def_mail_recips.DELETE;
        v_def_mail_recips (1)   := 'bburns@deckers.com';
        --  V_DEF_MAIL_RECIPS(2):='kgates@deckers.com';
        apps.do_mail_utils.send_mail_header ('3PL_INTERFACE@deckers.com', v_def_mail_recips, l_title || '  --  ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                             , iretval);
        apps.do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            iretval);
        apps.do_mail_utils.send_mail_line ('--boundarystring', iretval);
        apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                           iretval);
        apps.do_mail_utils.send_mail_line ('', iretval);
    END;

    PROCEDURE m_msg (l_text VARCHAR2)
    IS
        iretval   VARCHAR2 (4000);
    BEGIN
        IF g_mail_debugging
        THEN
            apps.do_mail_utils.send_mail_line (l_text, iretval);
        END IF;

        apps.do_debug_tools.msg (l_text);
    END;

    PROCEDURE m_end
    IS
        iretval   VARCHAR2 (4000);
    BEGIN
        IF NOT g_mail_debugging
        THEN
            RETURN;
        END IF;

        SELECT COUNT (*)
          INTO g_n_temp
          FROM custom.do_debug
         WHERE session_id = USERENV ('SESSIONID');

        IF g_n_temp > 0 AND g_mail_debugging_attach_debug
        THEN
            m_msg ('--boundarystring');
            m_msg ('Content-Type: text/xls');
            m_msg (
                'Content-Disposition: attachment; filename="debug_information.xls"');
            m_msg ('');
            m_msg (
                   'Debug Text'
                || CHR (9)
                || 'Creation Date'
                || CHR (9)
                || 'Session ID'
                || CHR (9)
                || 'Debug ID'
                || CHR (9)
                || 'Call Stack');

            FOR debug_line IN (  SELECT *
                                   FROM custom.do_debug
                                  WHERE session_id = USERENV ('SESSIONID')
                               ORDER BY debug_id ASC)
            LOOP
                m_msg (
                       ''''
                    || REPLACE (debug_line.debug_text, CHR (9), ' ')
                    || CHR (9)
                    || TO_CHAR (debug_line.creation_date,
                                'MM/DD/YYYY HH:MI:SS AM')
                    || CHR (9)
                    || debug_line.session_id
                    || CHR (9)
                    || debug_line.debug_id
                    || CHR (9)
                    || REPLACE (SUBSTR (debug_line.call_stack, 83),
                                CHR (10),
                                CHR (9)));
            END LOOP;

            DELETE FROM custom.do_debug
                  WHERE session_id = USERENV ('SESSIONID');
        END IF;

        apps.do_mail_utils.send_mail_close (iretval);
    END;

    PROCEDURE mail_debug (p_user_id IN NUMBER, p_title IN VARCHAR2)
    IS
        v_def_mail_recips   apps.do_mail_utils.tbl_recips;
        tmp                 NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO tmp
          FROM custom.do_debug
         WHERE session_id = USERENV ('SESSIONID');

        IF tmp = 0 OR p_user_id < 0
        THEN
            RETURN;
        END IF;

        v_def_mail_recips.DELETE;

        SELECT NVL (ppf.email_address, fu.email_address) AS email_address
          INTO v_def_mail_recips (1)
          FROM apps.per_people_f ppf, apps.fnd_user fu
         WHERE fu.user_id = p_user_id AND ppf.person_id(+) = fu.employee_id;

        IF v_def_mail_recips (1) IS NULL
        THEN
            RETURN;
        END IF;

        apps.do_mail_utils.send_mail_header ('3PL_INTERFACE@deckers.com', v_def_mail_recips, p_title || '  --  ' || TO_CHAR (SYSDATE, 'YYYY-MM-DD')
                                             , tmp);
        apps.do_mail_utils.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            tmp);
        apps.do_mail_utils.send_mail_line ('--boundarystring', tmp);
        apps.do_mail_utils.send_mail_line ('Content-Type: text/plain', tmp);
        apps.do_mail_utils.send_mail_line ('', tmp);
        apps.do_mail_utils.send_mail_line ('--boundarystring', tmp);
        apps.do_mail_utils.send_mail_line ('Content-Type: text/txt', tmp);
        apps.do_mail_utils.send_mail_line (
            'Content-Disposition: attachment; filename="debug_information.txt"',
            tmp);
        apps.do_mail_utils.send_mail_line ('', tmp);

        FOR debug_line IN (  SELECT *
                               FROM custom.do_debug
                              WHERE session_id = USERENV ('SESSIONID')
                           ORDER BY debug_id ASC)
        LOOP
            apps.do_mail_utils.send_mail_line (
                   TO_CHAR (debug_line.creation_date,
                            'YYYY-MM-DD HH24:MI:SS')
                || ' -- '
                || REPLACE (REPLACE (debug_line.debug_text, CHR (13), '  '),
                            CHR (10),
                            '  '),
                tmp);
        END LOOP;

        DELETE FROM custom.do_debug
              WHERE session_id = USERENV ('SESSIONID');

        apps.do_mail_utils.send_mail_close (tmp);
    END;

    PROCEDURE log_update (p_updated_by     IN     NUMBER,
                          p_update_type    IN     VARCHAR2,
                          p_update_table   IN     VARCHAR2,
                          p_update_id      IN     NUMBER,
                          p_update_rowid   IN     VARCHAR2,
                          p_comments       IN     VARCHAR2,
                          x_ret_stat          OUT VARCHAR2,
                          x_hist_id           OUT NUMBER,
                          x_message           OUT VARCHAR2);

    PROCEDURE get_resp_app_id (p_org_id IN NUMBER, x_responsibility_id OUT NUMBER, x_application_id OUT NUMBER)
    IS
        l_profile_id    NUMBER;    --Added by BT Technology team on 11/10/2014
        l_profile_ids   NUMBER;    --Added by BT Technology team on 11/10/2014
    BEGIN
        SELECT profile_option_id
          INTO l_profile_id
          FROM fnd_profile_options
         WHERE profile_option_name = 'DEFAULT_ORG_ID';

        --Added by BT Technology team on 11/10/2014

        SELECT profile_option_id
          INTO l_profile_ids
          FROM fnd_profile_options
         WHERE profile_option_name = 'ORG_ID';

        --Added by BT Technology team on 11/10/2014

        SELECT responsibility_id, application_id
          INTO x_responsibility_id, x_application_id
          FROM (  SELECT DISTINCT
                         TO_NUMBER (fpov.level_value) responsibility_id,
                         (SELECT COUNT (*)
                            FROM fnd_profile_options fpo, fnd_profile_option_values fpov2
                           WHERE     fpo.profile_option_name LIKE 'XXDO_3PL%'
                                 AND fpov2.profile_option_id =
                                     fpo.profile_option_id
                                 AND fpov2.level_id = 10003
                                 AND fpov2.level_value = fpov.level_value) cnt,
                         fr.application_id
                    FROM fnd_profile_option_values fpov, fnd_responsibility_tl frt, fnd_responsibility fr
                   /*WHERE fpov.profile_option_id IN (6684, 1991)
                     AND fpov.level_id = 10003
                     AND fpov.level_value IN (
                            SELECT responsibility_id
                              FROM fnd_user_resp_groups
                             WHERE user_id = 1037*/
                   --commented by BT Technology team on 11/10/2014
                   WHERE     fpov.profile_option_id IN
                                 (l_profile_id, l_profile_ids)
                         --Added by BT Technology team on 11/10/2014  BEGIN
                         AND fpov.level_id = 10003
                         AND fpov.level_value IN
                                 (SELECT responsibility_id
                                    FROM fnd_user_resp_groups
                                   WHERE     user_id IN
                                                 (SELECT user_id
                                                    FROM fnd_user
                                                   WHERE user_name = 'BATCH')
                                         --Added by BT Technology team on 11/10/2014 END
                                         AND SYSDATE BETWEEN NVL (start_date,
                                                                  SYSDATE - 1)
                                                         AND NVL (end_date,
                                                                  SYSDATE + 1))
                         AND frt.LANGUAGE = 'US'
                         AND frt.responsibility_id = fpov.level_value
                         AND fr.responsibility_id = frt.responsibility_id
                         --AND fr.menu_id = 70603                                                                           --commented by BT Technology team on 11/10/2014
                         --     AND fr.menu_id IN (SELECT MENU_ID FROM FND_MENUS WHERE MENU_NAME='ONT_SUPER_USER')                 --Added by BT Technology team on 11/10/2014
                         AND fr.menu_id IN (SELECT menu_id
                                              FROM fnd_menus
                                             WHERE menu_name = 'DO_ONT_USER')
                         --Added JFT 11/19/2015
                         AND fpov.profile_option_value = p_org_id
                ORDER BY 2 DESC)
         WHERE ROWNUM = 1;
    END;

    PROCEDURE set_om_context (p_user_id IN NUMBER, p_org_id IN NUMBER)
    IS
        l_resp_id   NUMBER;
        l_appn_id   NUMBER;
    BEGIN
        --START Added as per ver 1.1
        BEGIN
              SELECT frv.responsibility_id, frv.application_id
                INTO l_resp_id, l_appn_id
                FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                     apps.hr_organization_units hou
               WHERE     1 = 1
                     AND hou.organization_id = p_org_id
                     AND frv.responsibility_name LIKE
                             'Deckers Order Management Super User%'
                     AND fpov.profile_option_value =
                         TO_CHAR (hou.organization_id)
                     AND fpo.profile_option_id = fpov.profile_option_id
                     AND fpo.user_profile_option_name = 'MO: Operating Unit'
                     AND frv.responsibility_id = fpov.level_value
            ORDER BY frv.responsibility_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                SELECT responsibility_id, application_id
                  INTO l_global_resp_id, l_global_appn_id
                  FROM apps.fnd_responsibility_tl
                 WHERE     responsibility_name =
                           'Order Management Super User'
                       AND LANGUAGE = 'US';
        END;

        --END Added as per ver 1.1
        apps.fnd_global.apps_initialize (user_id        => p_user_id,
                                         resp_id        => l_resp_id,
                                         resp_appl_id   => l_appn_id);
        apps.mo_global.init ('ONT');
    --  apps.mo_global.set_policy_context ('S', c_hold.hold_org_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END;

    -- RETURNS BEGIN --
    PROCEDURE build_return_header_rec (
        p_grn_header_id   IN     NUMBER,
        p_so_header_id    IN     NUMBER,
        x_oi_header_rec      OUT oe_order_pub.header_rec_type,
        x_ret_status         OUT VARCHAR2,
        x_message            OUT VARCHAR2)
    IS
        l_proc_name              VARCHAR2 (240)
                                     := lg_package_name || '.BUILD_RETURN_HEADER_REC';
        l_func_curr              gl_ledgers.currency_code%TYPE;
        l_conversion_type_code   oe_order_headers_all.conversion_type_code%TYPE;
        l_conversion_rate        NUMBER;
        l_conversion_date        DATE;
    BEGIN
        BEGIN
            msg (p_message => '+' || l_proc_name);
            msg (p_message => '  GRN Header ID: ' || p_grn_header_id);
            msg (p_message => '  Sales Order Header ID: ' || p_so_header_id);
            x_oi_header_rec.operation          := oe_globals.g_opr_create;

            SELECT oe_order_headers_s.NEXTVAL
              INTO x_oi_header_rec.header_id
              FROM DUAL;

            msg (
                p_message   => '  Got new header id: ' || x_oi_header_rec.header_id);

            SELECT sold_to_org_id, sold_to_org_id, invoice_to_org_id,
                   ship_to_org_id, deliver_to_org_id, --Commented as per CCR0006788
                                                      --'RTN - ' || cust_po_number AS cust_po_number,
                                                      --Added as per CCR0006788
                                                      cust_po_number || '_RT' AS cust_po_number,
                   orig_sys_document_ref || '_RT' AS orig_sys_document_ref, --End for changes CCR0006788
                                                                            price_list_id, org_id,
                   org_id, salesrep_id, shipping_method_code,
                   freight_terms_code, sales_channel_code, fob_point_code,
                   attribute5, payment_term_id, transactional_curr_code,
                   conversion_type_code, conversion_rate, conversion_rate_date,
                   tax_exempt_flag
              INTO x_oi_header_rec.sold_to_org_id, x_oi_header_rec.invoice_to_customer_id, x_oi_header_rec.invoice_to_org_id, x_oi_header_rec.ship_to_org_id,
                                                 x_oi_header_rec.deliver_to_org_id, x_oi_header_rec.cust_po_number, --Added as per CCR0006788
                                                                                                                    x_oi_header_rec.orig_sys_document_ref,
                                                 --End for changes CCR0006788
                                                 x_oi_header_rec.price_list_id, x_oi_header_rec.org_id, x_oi_header_rec.sold_from_org_id,
                                                 x_oi_header_rec.salesrep_id, x_oi_header_rec.shipping_method_code, x_oi_header_rec.freight_terms_code,
                                                 x_oi_header_rec.sales_channel_code, x_oi_header_rec.fob_point_code, x_oi_header_rec.attribute5,
                                                 x_oi_header_rec.payment_term_id, x_oi_header_rec.transactional_curr_code, l_conversion_type_code,
                                                 l_conversion_rate, l_conversion_date, x_oi_header_rec.tax_exempt_flag
              FROM oe_order_headers_all
             WHERE header_id = NVL (p_so_header_id, -1);

            msg (p_message => '  Got values from original sales order.');

            SELECT organization_id
              INTO x_oi_header_rec.ship_from_org_id
              FROM xxdo.xxdo_wms_3pl_grn_h
             WHERE grn_header_id = p_grn_header_id;

            msg (
                p_message   =>
                       '  Got organization ID from GRN header: '
                    || x_oi_header_rec.ship_from_org_id);
            x_oi_header_rec.version_number     := 1;
            x_oi_header_rec.open_flag          := 'Y';
            x_oi_header_rec.booked_flag        := 'Y';
            x_oi_header_rec.pricing_date       := SYSDATE;
            x_oi_header_rec.creation_date      := SYSDATE;
            x_oi_header_rec.last_update_date   := SYSDATE;
            x_oi_header_rec.ordered_date       := TRUNC (SYSDATE);
            x_oi_header_rec.created_by         := fnd_global.user_id;
            x_oi_header_rec.last_updated_by    := fnd_global.user_id;
            x_oi_header_rec.request_date       := TRUNC (SYSDATE);
            --Changed as per Japan Ph2/PRB0041591
            --x_oi_header_rec.attribute1 := TO_CHAR (ADD_MONTHS (x_oi_header_rec.request_date, 1));
            x_oi_header_rec.attribute1         :=
                apps.fnd_date.date_to_canonical (
                    ADD_MONTHS (x_oi_header_rec.request_date, 1));
            --Changes completed for Japan Ph2/PRB0041591

            --Commented as per CCR0006788
            --x_oi_header_rec.orig_sys_document_ref := '3PLGRN-' || p_grn_header_id;
            msg (
                p_message   =>
                       '  x_oi_header_rec.orig_sys_document_ref='
                    || x_oi_header_rec.orig_sys_document_ref);
            x_oi_header_rec.order_source_id    :=
                NVL (fnd_profile.VALUE ('XXDO_3PL_EDI_RET_ORDER_SOURCE_ID'),
                     6);
            msg (
                p_message   =>
                    '  x_oi_header_rec.order_source_id=' || x_oi_header_rec.order_source_id);
            x_oi_header_rec.order_type_id      :=
                fnd_profile.VALUE ('XXDO_3PL_EDI_RET_ORDER_TYPE_ID');
            msg (
                p_message   =>
                    '  x_oi_header_rec.order_type_id=' || x_oi_header_rec.order_type_id);

            IF x_oi_header_rec.order_type_id IS NULL
            THEN
                raise_application_error (
                    -20001,
                    'Failed to obtain order type.  OrgID=' || fnd_global.org_id);
            END IF;

            /*
             --Commented as per CCR CCR0006805
                     x_oi_header_rec.return_reason_code :=
                        fnd_profile.VALUE ('XXDO_3PL_EDI_RET_REASON_CODE');
                     msg (
                        p_message =>    '  x_oi_header_rec.return_reason_code='
                                     || x_oi_header_rec.return_reason_code);

                     IF x_oi_header_rec.return_reason_code IS NULL
                     THEN
                        raise_application_error (
                           -20001,
                           'Failed to obtain reason code.  OrgID=' || fnd_global.org_id);
                     END IF;
             --End changes for CCR CCR0006805
            */
            msg (p_message => '  Populated remaining values.');

            SELECT currency_code
              INTO l_func_curr
              FROM gl_ledgers gl, hr_organization_information hoi
             WHERE     gl.ledger_id = TO_NUMBER (hoi.org_information3)
                   AND hoi.org_information_context =
                       'Operating Unit Information'
                   AND hoi.organization_id = x_oi_header_rec.org_id;

            --Intl currency support
            IF NVL (l_func_curr, 'XXXX') !=
               x_oi_header_rec.transactional_curr_code
            THEN
                IF l_conversion_rate IS NULL
                THEN
                    x_oi_header_rec.conversion_type_code   := 'Corporate';
                    x_oi_header_rec.conversion_rate_date   := TRUNC (SYSDATE);

                    BEGIN
                        SELECT conversion_rate
                          INTO x_oi_header_rec.conversion_rate
                          FROM gl_daily_rates_v
                         WHERE     status_code != 'D'
                               AND user_conversion_type =
                                   x_oi_header_rec.conversion_type_code
                               AND conversion_date =
                                   x_oi_header_rec.conversion_rate_date
                               AND from_currency =
                                   x_oi_header_rec.transactional_curr_code
                               AND to_currency = l_func_curr
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            raise_application_error (
                                -20001,
                                   'Failed to obtain exchange rate from '
                                || x_oi_header_rec.transactional_curr_code
                                || ' to '
                                || l_func_curr
                                || ' for '
                                || TO_DATE (
                                       x_oi_header_rec.conversion_rate_date));
                    END;
                ELSE
                    x_oi_header_rec.conversion_type_code   :=
                        l_conversion_type_code;
                    x_oi_header_rec.conversion_rate   := l_conversion_rate;
                    x_oi_header_rec.conversion_rate_date   :=
                        l_conversion_date;
                END IF;
            END IF;

            x_ret_status                       := fnd_api.g_ret_sts_success;
            x_message                          := NULL;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_oi_header_rec   := oe_order_pub.g_miss_header_rec;
                x_ret_status      := fnd_api.g_ret_sts_error;
                x_message         :=
                    'The original sales order record was not found.';
            WHEN OTHERS
            THEN
                x_oi_header_rec   := oe_order_pub.g_miss_header_rec;
                x_ret_status      := fnd_api.g_ret_sts_error;
                x_message         := SQLERRM;
        END;

        msg (' x_ret_status=' || x_ret_status || ', x_message=' || x_message);
        msg (p_message => '-' || l_proc_name);
    END;

    --Start Added for 1.16
    FUNCTION validate_odc_org_exists (p_osc_header_id     IN NUMBER,
                                      p_organization_id   IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_odc_org_exists   VARCHAR2 (100) := 'N';
    BEGIN
        BEGIN
            SELECT 'Y'
              INTO lv_odc_org_exists
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     flv.lookup_code = mp.organization_code
                   AND flv.lookup_type = 'XXD_ODC_ORG_CODE_LKP'
                   AND mp.organization_id = p_organization_id
                   AND flv.language = USERENV ('Lang')
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE + 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_odc_org_exists   := 'N';
        END;

        RETURN lv_odc_org_exists;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP -Others in validate_odc_org_exists : ' || SQLERRM);
            RETURN NULL;
    END validate_odc_org_exists;

    --Start Added for 1.16
    PROCEDURE get_odc_order_type (p_osc_header_id IN NUMBER, p_odc_org_exists IN VARCHAR2, p_order_type OUT VARCHAR2)
    IS
        lv_order_type           VARCHAR2 (100) := NULL;
        lv_dc_dc_exists         NUMBER := 0;
        lv_direct_ship_exists   NUMBER := 0;
    BEGIN
        IF NVL (p_odc_org_exists, 'N') = 'Y'
        THEN
            --Validate Backorder Process
            BEGIN
                SELECT 'ODC_BACKORDERED' AS name
                  INTO lv_order_type
                  FROM xxdo.xxdo_wms_3pl_osc_h osch, apps.oe_order_headers_all ooha, apps.wsh_new_deliveries wnd,
                       oe_transaction_types_tl ott
                 WHERE     1 = 1
                       AND osch.osc_header_id = p_osc_header_id
                       AND osch.order_id = wnd.delivery_id
                       AND wnd.source_header_id = ooha.header_id
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM xxdo.xxdo_wms_3pl_osc_l
                                 WHERE osc_header_id = p_osc_header_id)
                       AND ooha.order_type_id = ott.transaction_type_id
                       AND ott.language = USERENV ('Lang');
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_order_type   := NULL;
            END;

            --Validate 'DC to DC Transfer' exists
            IF lv_order_type IS NULL
            THEN
                BEGIN
                    SELECT MAX (1)
                      INTO lv_dc_dc_exists
                      FROM xxdo.xxdo_wms_3pl_osc_l oscl, apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha,
                           oe_transaction_types_tl ott
                     WHERE     1 = 1
                           AND oscl.osc_header_id = p_osc_header_id
                           AND oola.line_id = oscl.source_line_id
                           AND ooha.header_id = oola.header_id
                           AND ott.name = 'DC to DC Transfer - US'
                           AND ott.transaction_type_id = ooha.order_type_id
                           AND ott.language = USERENV ('Lang');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_dc_dc_exists   := 0;
                END;

                --NON-DC to DC Transfer
                IF NVL (lv_dc_dc_exists, -99) <> 1
                THEN
                    lv_direct_ship_exists   := 1;
                END IF;
            END IF;

            IF NVL (lv_order_type, 'NA') = 'ODC_BACKORDERED'
            THEN
                p_order_type   := lv_order_type;
            ELSE
                IF NVL (lv_dc_dc_exists, -99) = 1
                THEN
                    p_order_type   := 'ODC_DC_DC_TRANSFER';
                ELSIF NVL (lv_direct_ship_exists, -99) = 1
                THEN
                    p_order_type   := 'ODC_DIRECT_SHIP';
                ELSE
                    p_order_type   := NULL;
                END IF;
            END IF;
        ELSE                                          --p_odc_org_exists = 'N'
            p_order_type   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP -Others in get_odc_order_type : ' || SQLERRM);
            p_order_type   := NULL;
    END get_odc_order_type;

    --End Added for 1.16

    --Commented for 1.16
    --Start Added for 1.12
    /*PROCEDURE get_order_type_org_code (
     p_osc_header_id   IN   NUMBER,
     p_organization_id IN   NUMBER,
     p_order_type      OUT  VARCHAR2,
     p_odc_org_exists  OUT  VARCHAR2
     ) IS
         lv_order_type   VARCHAR2(100);
         lv_odc_org_exists    VARCHAR2(100);
     BEGIN
         BEGIN
             SELECT
                 DECODE(MAX(ott.name),
      'Direct Ship OriginHub-US','DIRECTSHIP_ORIGHUB_US',
      'DC to DC Transfer - US', 'DC_DC_TRANSFER') name
             INTO lv_order_type
             FROM
                 xxdo.xxdo_wms_3pl_osc_l     oscl,
                 apps.oe_order_lines_all     oola,
                 apps.oe_order_headers_all   ooha,
                 oe_transaction_types_tl     ott
             WHERE
                 1 = 1
                 AND oscl.osc_header_id = p_osc_header_id
                 AND oola.line_id = oscl.source_line_id
                 AND ooha.header_id = oola.header_id
     AND ott.name IN ('Direct Ship OriginHub-US',
          'DC to DC Transfer - US')
                 AND ott.transaction_type_id = ooha.order_type_id
                 AND ott.language = userenv('Lang');
         EXCEPTION
             WHEN OTHERS
    THEN
                 lv_order_type := NULL;
         END;

   --For Backorder Process
   IF lv_order_type IS NULL
   THEN
     BEGIN
    SELECT
                 'US7_BACKORDERED' AS name
     INTO lv_order_type
             FROM
                 xxdo.xxdo_wms_3pl_osc_h     osch,
                 apps.oe_order_headers_all   ooha,
                 apps.wsh_new_deliveries     wnd,
                 oe_transaction_types_tl     ott
             WHERE
                 1 = 1
                 AND osch.osc_header_id = p_osc_header_id
                 AND osch.order_id = wnd.delivery_id
                 AND wnd.source_header_id = ooha.header_id
     AND NOT EXISTS (SELECT 1 FROM xxdo.xxdo_wms_3pl_osc_l
          WHERE osc_header_id = p_osc_header_id)
                 AND ooha.order_type_id = ott.transaction_type_id
     AND ott.name IN ('Direct Ship OriginHub-US',
          'DC to DC Transfer - US')
                 AND ott.language = userenv('Lang');
     EXCEPTION
             WHEN OTHERS
    THEN
                 lv_order_type := NULL;
           END;
   END IF;

   BEGIN
      SELECT 'Y'
      INTO lv_odc_org_exists
    FROM
     fnd_lookup_values   flv,
     mtl_parameters      mp
    WHERE
     flv.lookup_code = mp.organization_code
     AND flv.lookup_type = 'XXD_ODC_ORG_CODE_LKP'
     AND mp.organization_id = p_organization_id
     AND flv.language = userenv('Lang')
     AND flv.enabled_flag = 'Y'
     AND SYSDATE BETWEEN nvl(start_date_active, SYSDATE)
         AND nvl(end_date_active, SYSDATE + 1);
         EXCEPTION
             WHEN OTHERS
    THEN
                 lv_odc_org_exists := 'N';
         END;

         p_order_type := lv_order_type;
         p_odc_org_exists := lv_odc_org_exists;
     EXCEPTION
         WHEN OTHERS
   THEN
       msg('EXP -Others in get_order_type_org_code : '||SQLERRM);
             p_order_type := NULL;
             p_odc_org_exists  := NULL;
     END get_order_type_org_code; */

    FUNCTION validate_multi_cartons (p_source_header_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_multi_ctns_exist   NUMBER := 0;
        ln_partial_qty_chk    NUMBER := 0;
        ln_result             NUMBER;
    BEGIN
        --Validate Multiple Containers exists
        BEGIN
              SELECT COUNT (l.carton_number)
                INTO ln_multi_ctns_exist
                FROM xxdo.xxdo_wms_3pl_osc_h h, xxdo.xxdo_wms_3pl_osc_l l
               WHERE     1 = 1
                     AND h.osc_header_id = l.osc_header_id
                     AND h.source_header_id = p_source_header_id
                     --AND l.process_status IN ('S')
                     AND l.processing_session_id = USERENV ('SESSIONID')
                     AND l.qty_shipped != 0
            GROUP BY h.source_header_id, l.source_line_id, l.inventory_item_id
              HAVING COUNT (l.carton_number) > 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_multi_ctns_exist   := 0;
            WHEN OTHERS
            THEN
                ln_multi_ctns_exist   := 99;
        END;

        msg ('ln_multi_cartons_exist :' || ln_multi_ctns_exist);

        IF NVL (ln_multi_ctns_exist, 0) > 0
        THEN
            --Validate partial qty check for delivery
            BEGIN
                  SELECT NVL (wdd.requested_quantity, 0) - NVL (SUM (l.qty_shipped), 0) qty
                    INTO ln_partial_qty_chk
                    FROM xxdo.xxdo_wms_3pl_osc_h h, xxdo.xxdo_wms_3pl_osc_l l, wsh_delivery_details wdd,
                         wsh_delivery_assignments wda
                   WHERE     1 = 1
                         AND h.osc_header_id = l.osc_header_id
                         AND h.source_header_id = p_source_header_id
                         AND h.source_header_id = wda.delivery_id
                         AND wdd.delivery_detail_id = wda.delivery_detail_id
                         AND l.source_line_id = wdd.source_line_id
                         AND l.inventory_item_id = wdd.inventory_item_id
                         --AND greatest(nvl(wdd.requested_quantity, 0) - nvl(l.qty_shipped, 0), 0) > 0
                         AND wdd.source_code = 'OE'
                         AND wdd.released_status = 'S'
                         -- AND l.process_status = 'P'
                         AND l.processing_session_id = USERENV ('SESSIONID')
                         AND l.qty_shipped != 0
                GROUP BY wdd.source_header_id, wdd.source_line_id, wdd.inventory_item_id,
                         wdd.requested_quantity
                  HAVING   NVL (wdd.requested_quantity, 0)
                         - NVL (SUM (l.qty_shipped), 0) >
                         0;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_partial_qty_chk   := 0;
                WHEN OTHERS
                THEN
                    ln_partial_qty_chk   := 99;
            END;
        ELSE
            RETURN 1;
        END IF;

        msg ('ln_partial_qty_chk :' || ln_partial_qty_chk);

        --IF exists, new delivery creation process
        --IF not exists, skip new delivery creation process
        IF NVL (ln_partial_qty_chk, 0) > 0
        THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;

    --End Added for 1.12

    --Start Added for 1.12
    FUNCTION validate_lines_qty_split (p_source_header_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_split_line_cnt   NUMBER := 0;
        ln_result           NUMBER;
    BEGIN
        --Validate SKU Line Split
        BEGIN
            SELECT COUNT (1)
              INTO ln_split_line_cnt
              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda, xxdo.xxdo_wms_3pl_osc_l oscl
             WHERE     1 = 1
                   AND GREATEST (
                             NVL (wdd.requested_quantity, 0)
                           - NVL (wdd.shipped_quantity, 0),
                           0) >
                       0
                   AND GREATEST (
                             NVL (wdd.requested_quantity, 0)
                           - NVL (oscl.qty_shipped, 0),
                           0) >
                       0
                   AND wdd.source_code = 'OE'
                   AND wdd.released_status = 'S'
                   AND oscl.process_status = 'P'
                   AND oscl.processing_session_id = USERENV ('SESSIONID')
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_line_id = oscl.source_line_id
                   AND wda.delivery_id = p_source_header_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxdo_wms_3pl_osc_h h, xxdo.xxdo_wms_3pl_osc_l l
                             WHERE     1 = 1
                                   AND h.osc_header_id = l.osc_header_id
                                   AND h.source_header_id =
                                       p_source_header_id
                                   AND l.source_line_id = wdd.source_line_id
                                   AND l.process_status = 'S'
                                   AND l.processing_session_id =
                                       USERENV ('SESSIONID')
                                   AND l.qty_shipped != 0);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_split_line_cnt   := 0;
            WHEN OTHERS
            THEN
                ln_split_line_cnt   := 99;
        END;

        --IF exists, new delivery creation process
        --IF not exists, skip new delivery creation process
        IF NVL (ln_split_line_cnt, 0) > 0
        THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;

    --End Added for 1.12

    --Start Added for 1.12
    FUNCTION validate_lines_split (p_source_header_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_lines_equal_qty_cnt   NUMBER := 0;
        ln_delivery_lines_cnt    NUMBER := 0;
        ln_result                NUMBER;
    BEGIN
        --Fetch count of Delivery Lines qty equal with Staging Lines Qty
        BEGIN
            SELECT COUNT (1)
              INTO ln_lines_equal_qty_cnt
              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda, xxdo.xxdo_wms_3pl_osc_l oscl
             WHERE     1 = 1
                   AND GREATEST (
                             NVL (wdd.requested_quantity, 0)
                           - NVL (wdd.shipped_quantity, 0),
                           0) >
                       0
                   AND GREATEST (
                             NVL (wdd.requested_quantity, 0)
                           - NVL (oscl.qty_shipped, 0),
                           0) =
                       0
                   AND wdd.source_code = 'OE'
                   AND wdd.released_status = 'S'
                   AND oscl.process_status = 'P'
                   AND oscl.processing_session_id = USERENV ('SESSIONID')
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_line_id = oscl.source_line_id
                   AND wda.delivery_id = p_source_header_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxdo_wms_3pl_osc_h h, xxdo.xxdo_wms_3pl_osc_l l
                             WHERE     1 = 1
                                   AND h.osc_header_id = l.osc_header_id
                                   AND h.source_header_id =
                                       p_source_header_id
                                   AND l.source_line_id = wdd.source_line_id
                                   AND l.process_status = 'S'
                                   AND l.processing_session_id =
                                       USERENV ('SESSIONID')
                                   AND l.qty_shipped != 0);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_lines_equal_qty_cnt   := 0;
        END;

        --Fetch count of Delivery Lines
        BEGIN
            SELECT COUNT (1)
              INTO ln_delivery_lines_cnt
              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
             WHERE     1 = 1
                   AND GREATEST (
                             NVL (wdd.requested_quantity, 0)
                           - NVL (wdd.shipped_quantity, 0),
                           0) >
                       0
                   AND wdd.source_code = 'OE'
                   AND wdd.released_status = 'S'
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wda.delivery_id = p_source_header_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxdo_wms_3pl_osc_h h, xxdo.xxdo_wms_3pl_osc_l l
                             WHERE     1 = 1
                                   AND h.osc_header_id = l.osc_header_id
                                   AND h.source_header_id =
                                       p_source_header_id
                                   AND l.source_line_id = wdd.source_line_id
                                   AND l.process_status = 'S'
                                   AND l.processing_session_id =
                                       USERENV ('SESSIONID')
                                   AND l.qty_shipped != 0);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_delivery_lines_cnt   := 0;
        END;

        --msg ('ln_delivery_lines_cnt :' ||ln_delivery_lines_cnt);
        --msg ('ln_lines_equal_qty_cnt :' ||ln_lines_equal_qty_cnt);

        --IF delivery lines count greater than Staging Lines count, new delivery creation process
        --IF not exists, skip new delivery creation process
        IF (NVL (ln_delivery_lines_cnt, 0) - NVL (ln_lines_equal_qty_cnt, 0)) >
           0
        THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;

    --End Added for 1.12

    --Start Added for 1.12 (LC Split Line)
    --Split Line
    PROCEDURE move_order_split_line (p_transaction_temp_id IN NUMBER, p_missing_quantity IN NUMBER, -- 3PL Qty
                                                                                                    p_detailed_quantity IN NUMBER -- EBS Qty
                                                                                                                                 )
    IS
        --variables declaration
        lv_return_status   VARCHAR2 (1);
        ln_msg_count       NUMBER;
        lv_msg_data        VARCHAR2 (32767);
        pv_retcode         VARCHAR2 (1);
        pv_errbuf          VARCHAR2 (32767);
        ln_msg_cntr        NUMBER;
        ln_msg_index_out   NUMBER;
    BEGIN
        msg (
               'p_transaction_temp_id :'
            || p_transaction_temp_id
            || ' and p_missing_quantity(3PL Qty) :'
            || p_missing_quantity
            || ' and p_detailed_quantity(EBS Qty) :'
            || p_detailed_quantity);
        --move order split
        inv_replenish_detail_pub.split_line_details (
            p_transaction_temp_id    => p_transaction_temp_id     --1598664585
                                                             ,
            p_missing_quantity       => p_missing_quantity          -- 3PL Qty
                                                          ,
            p_detailed_quantity      => p_detailed_quantity         -- EBS Qty
                                                           ,
            p_transaction_quantity   => 0,
            x_return_status          => lv_return_status,
            x_msg_count              => ln_msg_count,
            x_msg_data               => lv_msg_data);
        msg ('Return Status: ' || lv_return_status);

        --IF lv_return_status <> fnd_api.g_ret_sts_success
        IF NVL (lv_return_status, 'XX') <> fnd_api.g_ret_sts_success
        THEN
            pv_retcode    := '1';
            pv_errbuf     :=
                   'API to confirm picking failed with status: '
                || lv_return_status
                || ' Move Line ID : '
                --|| pn_mo_line_id
                || 'Error: '
                || lv_msg_data;
            -- Retrieve messages
            ln_msg_cntr   := 1;
            ln_msg_cntr   := 1;

            WHILE ln_msg_cntr <= ln_msg_count
            LOOP
                fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                 , p_msg_index_out => ln_msg_index_out);

                ln_msg_cntr   := ln_msg_cntr + 1;
                msg ('Error Message: ' || lv_msg_data);
            END LOOP;
        ELSE
            pv_errbuf   :=
                   'API to confirm picking was successful with status: '
                || lv_return_status;
            msg (pv_errbuf);
        -- UPDATE wsh_delivery_details
        -- SET attribute15 = 'Pick Confirmed'
        -- WHERE move_order_line_id = pn_mo_line_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP- Others in move_order_split_line : ' || SQLERRM);
    END move_order_split_line;

    --Delete Allocation
    PROCEDURE delete_allocation_details (p_transaction_temp_id IN NUMBER, p_move_order_line_id IN NUMBER, p_reservation_id IN NUMBER
                                         , p_quantity IN NUMBER)
    IS
        --Variables declaration
        l_api_version           NUMBER := 1.0;
        l_init_msg_list         VARCHAR2 (2) := fnd_api.g_true;
        l_commit                VARCHAR2 (2) := fnd_api.g_false;
        x_return_status         VARCHAR2 (2);
        x_msg_count             NUMBER := 0;
        x_msg_data              VARCHAR2 (255);

        --API specific declaration
        l_transaction_temp_id   NUMBER := p_transaction_temp_id;   --37897967;

        --WHO columns
        l_user_id               NUMBER := -1;
        l_resp_id               NUMBER := -1;
        l_application_id        NUMBER := -1;
        l_row_cnt               NUMBER := 1;
        l_user_name             VARCHAR2 (30) := 'CHAITHANYA.CHIMMAPUDI';
        l_resp_name             VARCHAR2 (80) := 'Inventory';
    BEGIN
        -- Call API to delete move order line allocation
        msg (
               'p_transaction_temp_id :'
            || l_transaction_temp_id
            || ' and p_move_order_line_id :'
            || p_move_order_line_id
            || ' and p_reservation_id :'
            || p_reservation_id
            || ' and p_quantity :'
            || p_quantity);

        inv_replenish_detail_pub.delete_details (
            p_transaction_temp_id     => l_transaction_temp_id,
            p_move_order_line_id      => p_move_order_line_id,      --99477838
            p_reservation_id          => p_reservation_id,         --279292641
            p_transaction_quantity    => p_quantity,
            p_transaction_quantity2   => NULL,
            p_primary_trx_qty         => p_quantity,
            x_return_status           => x_return_status,
            x_msg_count               => x_msg_count,
            x_msg_data                => x_msg_data,
            p_delete_temp_records     => TRUE);
        msg ('Return Status: ' || x_return_status);

        --IF ( x_return_status <> fnd_api.g_ret_sts_success )
        IF (NVL (x_return_status, 'XX') <> fnd_api.g_ret_sts_success)
        THEN
            msg (
                   'Message count: '
                || x_msg_count
                || ' Error Message :'
                || x_msg_data);

            IF (x_msg_count > 1)
            THEN
                FOR i IN 1 .. x_msg_count
                LOOP
                    x_msg_data   :=
                        fnd_msg_pub.get (p_msg_index   => i,
                                         p_encoded     => fnd_api.g_false);

                    msg ('message :' || x_msg_data);
                END LOOP;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP -Others in delete_allocation_details : ' || SQLERRM);
    END delete_allocation_details;

    --Transact Move Order Line
    PROCEDURE transact_mo_line (p_transaction_temp_id IN NUMBER)
    IS
        --Variables declaration
        l_api_version           NUMBER := 1.0;
        l_init_msg_list         VARCHAR2 (2) := fnd_api.g_true;
        l_commit                VARCHAR2 (2) := fnd_api.g_false;
        x_return_status         VARCHAR2 (2);
        x_msg_count             NUMBER := 0;
        x_msg_data              VARCHAR2 (255);

        --API specific declaration
        l_move_order_type       NUMBER := 1;
        l_transaction_mode      NUMBER := 1;
        l_transaction_temp_id   NUMBER := p_transaction_temp_id;
        l_trolin_tbl            inv_move_order_pub.trolin_tbl_type;
        l_mold_tbl              inv_mo_line_detail_util.g_mmtt_tbl_type;
        x_mmtt_tbl              inv_mo_line_detail_util.g_mmtt_tbl_type;
        x_trolin_tbl            inv_move_order_pub.trolin_tbl_type;
        l_transaction_date      DATE := SYSDATE;
    BEGIN
        --l_trolin_tbl(1).line_id := l_mo_line_id;

        l_mold_tbl (1)   :=
            inv_mo_line_detail_util.query_row (
                p_line_detail_id => l_transaction_temp_id);

        --Call API to Transact Move Order Line and Pick confirm
        msg ('Calling inv_pick_wave_pick_confirm_pub.pick_confirm API');

        --Pick_Confirm (Removed from Temp Table same like Transact)
        inv_pick_wave_pick_confirm_pub.pick_confirm (
            p_api_version_number   => l_api_version,
            p_init_msg_list        => l_init_msg_list,
            p_commit               => l_commit,
            x_return_status        => x_return_status,
            x_msg_count            => x_msg_count,
            x_msg_data             => x_msg_data,
            p_move_order_type      => l_move_order_type,
            p_transaction_mode     => l_transaction_mode,
            p_trolin_tbl           => l_trolin_tbl,
            p_mold_tbl             => l_mold_tbl,
            x_mmtt_tbl             => x_mmtt_tbl,
            x_trolin_tbl           => x_trolin_tbl,
            p_transaction_date     => l_transaction_date);

        msg ('Return Status: ' || x_return_status);

        IF (NVL (x_return_status, 'XX') <> fnd_api.g_ret_sts_success)
        THEN
            msg (
                   'Message count: '
                || x_msg_count
                || ' Error Message :'
                || x_msg_data);

            IF (x_msg_count > 1)
            THEN
                FOR i IN 1 .. x_msg_count
                LOOP
                    x_msg_data   :=
                        fnd_msg_pub.get (p_msg_index   => i,
                                         p_encoded     => fnd_api.g_false);

                    msg ('message :' || x_msg_data);
                END LOOP;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP -Others in transact_mo_line : ' || SQLERRM);
    END transact_mo_line;

    PROCEDURE partail_pick_confirm (p_delivery_detail_id IN NUMBER, p_quantity IN NUMBER, x_delivery_detail_id OUT NUMBER
                                    , x_status OUT VARCHAR2)
    IS
        --Variables declaration
        lv_return_status                 VARCHAR2 (1);
        ln_msg_count                     NUMBER;
        lv_msg_data                      VARCHAR2 (32767);
        pv_retcode                       VARCHAR2 (1);
        pv_errbuf                        VARCHAR2 (32767);
        ln_msg_cntr                      NUMBER;
        ln_msg_index_out                 NUMBER;
        ln_move_order_line_id            NUMBER;
        ln_requested_quantity            NUMBER;
        ln_transaction_temp_id           NUMBER := NULL;
        ln_reservation_id                NUMBER;
        ln_confirm_transaction_temp_id   NUMBER := NULL;
        ln_confirm_delivery_detail_id    NUMBER := NULL;
    BEGIN
        BEGIN
              SELECT wdd.move_order_line_id, wdd.requested_quantity, MAX (mmt.transaction_temp_id),
                     mmt.reservation_id
                INTO ln_move_order_line_id, ln_requested_quantity, ln_transaction_temp_id, ln_reservation_id
                FROM wsh_delivery_details wdd, mtl_material_transactions_temp mmt
               WHERE     delivery_detail_id = p_delivery_detail_id
                     AND wdd.move_order_line_id = mmt.move_order_line_id
            GROUP BY wdd.move_order_line_id, wdd.requested_quantity, mmt.reservation_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_move_order_line_id    := NULL;
                ln_requested_quantity    := NULL;
                ln_transaction_temp_id   := NULL;
                msg ('EXP: Others- ln_requested_quantity: NULL');
        END;

        -- Calling Split Line
        msg ('=======================================================');
        msg ('Calling move_order_split_line1 -SplitQty');
        --msg ('ln_transaction_temp_id : '||ln_transaction_temp_id);

        move_order_split_line (ln_transaction_temp_id,
                               p_quantity,
                               ln_requested_quantity);

        --calling move order split line
        msg ('=======================================================');
        msg ('Calling move_order_split_line2 -LeftQty');
        move_order_split_line (ln_transaction_temp_id,
                               ln_requested_quantity - p_quantity,         --5
                               ln_requested_quantity);

        --calling delete allocation
        msg ('=======================================================');
        msg ('Calling delete_allocation_details');
        --msg ('ln_reservation_id : '||ln_reservation_id);
        delete_allocation_details (ln_transaction_temp_id, ln_move_order_line_id, ln_reservation_id
                                   , ln_requested_quantity);

        BEGIN
            SELECT MAX (transaction_temp_id)
              INTO ln_confirm_transaction_temp_id
              FROM mtl_material_transactions_temp a
             WHERE     1 = 1
                   AND move_order_line_id = ln_move_order_line_id
                   AND transaction_quantity = p_quantity;           -- 3PL Qty
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'EXP: Others- fetching ln_confirm_transaction_temp_id :'
                    || ln_confirm_transaction_temp_id);
        END;

        --calling transact move order line
        msg ('=======================================================');
        msg ('Calling transact move order line');
        msg (
               'ln_confirm_transaction_temp_id : '
            || ln_confirm_transaction_temp_id);
        transact_mo_line (ln_confirm_transaction_temp_id);

        BEGIN
            SELECT MAX (wdd.delivery_detail_id)
              INTO ln_confirm_delivery_detail_id
              FROM wsh_delivery_details wdd
             WHERE     1 = 1
                   AND wdd.source_code = 'OE'
                   AND wdd.released_status = 'Y'
                   AND wdd.move_order_line_id = ln_move_order_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_confirm_delivery_detail_id   := NULL;
                msg (
                       'EXP: Others -ln_confirm_delivery_detail_id : '
                    || ln_confirm_delivery_detail_id);
        END;

        x_delivery_detail_id   := ln_confirm_delivery_detail_id;
        msg ('pickconfirm_delivery_detail_id : ' || x_delivery_detail_id);
        msg ('=======================================================');

        IF (x_delivery_detail_id IS NOT NULL)
        THEN
            x_status   := fnd_api.g_ret_sts_success;
        ELSE
            x_status   := fnd_api.g_ret_sts_error;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP- Others in partail_pick_confirm : ' || SQLERRM);
    END partail_pick_confirm;

    --End Added for 1.12   (LC Split Line)

    FUNCTION return_open_ra_line (p_so_header_id IN NUMBER, p_inventory_item_id IN NUMBER, p_qty_received IN NUMBER)
        RETURN NUMBER
    IS
        l_line_id   NUMBER := NULL;
    BEGIN
        BEGIN
            /*Check for the given order-item-line combination for open lines*/
            msg (LPAD ('.', 58, '.'));
            msg ('Order Header ID ' || p_so_header_id);
            msg ('Item ID ' || p_inventory_item_id);

            BEGIN
                --If Return order already created for the same item (either less quantity or equal quantity)
                SELECT NVL (orig_line.line_id, -1)
                  INTO l_line_id
                  FROM apps.oe_order_lines_all ret_line, apps.oe_order_lines_all orig_line
                 WHERE     ret_line.reference_header_id = p_so_header_id
                       AND ret_line.inventory_item_id = p_inventory_item_id
                       AND ret_line.reference_header_id = orig_line.header_id
                       AND ret_line.inventory_item_id =
                           orig_line.inventory_item_id
                       AND (orig_line.shipped_quantity - ret_line.shipped_quantity) >=
                           p_qty_received;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_line_id   := -1;
            END;

            IF l_line_id IS NULL OR l_line_id = -1
            THEN
                --If No Return Orders created, and order has only one item or duplicate items
                BEGIN
                    SELECT NVL (MIN (orig_line.line_id), -1)
                      INTO l_line_id
                      FROM oe_order_lines_all orig_line
                     WHERE     inventory_item_id = p_inventory_item_id
                           AND orig_line.header_id = p_so_header_id
                           AND orig_line.line_category_code NOT IN ('RETURN')
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM apps.oe_order_lines_all ret_line
                                     WHERE ret_line.reference_line_id =
                                           orig_line.line_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_line_id   := -1;
                END;
            END IF;                                       -- End for l_line_id

            RETURN l_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Error ' || SQLERRM);
                msg (LPAD ('.', 58, '.'));
                RETURN l_line_id;
        END;
    END return_open_ra_line;

    PROCEDURE build_return_line_tbl (p_grn_header_id IN NUMBER, p_so_header_id IN NUMBER, p_oi_header_rec IN OUT oe_order_pub.header_rec_type, x_oi_line_tbl OUT oe_order_pub.line_tbl_type, x_oi_adj_tbl OUT oe_order_pub.line_adj_tbl_type, x_ret_status OUT VARCHAR2
                                     , x_message OUT VARCHAR2)
    IS
        l_proc_name            VARCHAR2 (240)
                                   := lg_package_name || '.BUILD_RETURN_LINE_TBL';
        l_ot_line_type_id      NUMBER;
        -- l_uom_code             mtl_system_items_b.primary_uom_code%TYPE;                        --commented by BT Technology team on 11/10/2014
        l_uom_code             xxd_common_items_v.primary_uom_code%TYPE;
        --Added by BT Technology team on 11/10/2014
        l_unit_list_price      NUMBER;
        l_unit_selling_price   NUMBER;
        l_tax_code             oe_order_lines_all.tax_code%TYPE;
        l_adj_type_code        qp_list_lines.list_line_type_code%TYPE;
        is_japan_ou            VARCHAR2 (1) := 'N';
        --Added for Japan eComm Ph2
        l_per_unit_operand     NUMBER := 0;
        --Added for Japan eComm Ph2
        is_japan_cod_order     NUMBER := 0;

        --Added for Japan eComm Ph2

        CURSOR c_lines IS
            --Query modified for CCR0006357
            SELECT l.inventory_item_id, l.quantity_to_receive, l.subinventory_code,
                   l.grn_line_id, l.return_reason_code, --Added as per CCR CCR0006805
                                                        return_open_ra_line (p_so_header_id, l.inventory_item_id, l.qty_received) orig_line_id
              FROM xxdo.xxdo_wms_3pl_grn_l l
             WHERE     l.grn_header_id = p_grn_header_id
                   AND l.process_status = 'P'
                   AND NVL (l.receipt_type, 'RECEIVE') = 'RECEIVE'
                   --Added for change 1.10
                   AND l.processing_session_id = USERENV ('SESSIONID');

        CURSOR c_orig_charges (p_line_id IN NUMBER)
        IS
            SELECT list_header_id, list_line_id, list_line_type_code,
                   charge_type_code, (-1 * operand) operand, arithmetic_operator,
                   (l.ordered_quantity - l.cancelled_quantity) ordered_quantity, (-1 * adjusted_amount) adjusted_amount
              FROM apps.oe_price_adjustments opa, apps.oe_order_lines_all l
             WHERE     opa.line_id = p_line_id
                   AND opa.line_id = l.line_id
                   AND opa.list_line_type_code = 'FREIGHT_CHARGE';
    /*SELECT l.inventory_item_id,
           l.quantity_to_receive,
           l.subinventory_code,
           l.grn_line_id,
           (SELECT MIN (line_id)
              FROM oe_order_lines_all
             WHERE     inventory_item_id = l.inventory_item_id
                   AND header_id = p_so_header_id)
              orig_line_id
      FROM xxdo.xxdo_wms_3pl_grn_l l
     WHERE     l.grn_header_id = p_grn_header_id
           AND l.process_status = 'P'
           AND l.processing_session_id = USERENV ('SESSIONID');*/
    BEGIN
        BEGIN
            msg (p_message => '+' || l_proc_name);
            msg (p_message => '  GRN Header ID: ' || p_grn_header_id);
            msg (p_message => '  Sales Order Header ID: ' || p_so_header_id);

            SELECT default_inbound_line_type_id
              INTO l_ot_line_type_id
              FROM oe_transaction_types_all
             WHERE     transaction_type_id = p_oi_header_rec.order_type_id
                   AND org_id = p_oi_header_rec.org_id;

            msg (
                p_message   =>
                       '  Obtained default line type for order type: '
                    || l_ot_line_type_id);

            FOR c_line IN c_lines
            LOOP
                x_oi_line_tbl (x_oi_line_tbl.COUNT + 1)         :=
                    oe_order_pub.g_miss_line_rec;
                msg (p_message => '  Line loop #' || x_oi_line_tbl.COUNT);
                msg (
                    p_message   =>
                           '  ItemID='
                        || c_line.inventory_item_id
                        || ', Quantity='
                        || c_line.quantity_to_receive
                        || ', Subinventory='
                        || c_line.subinventory_code
                        || ', Original LineID='
                        || c_line.orig_line_id);
                x_oi_line_tbl (x_oi_line_tbl.COUNT).header_id   :=
                    p_oi_header_rec.header_id;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).operation   :=
                    oe_globals.g_opr_create;

                SELECT oe_order_lines_s.NEXTVAL
                  INTO x_oi_line_tbl (x_oi_line_tbl.COUNT).line_id
                  FROM DUAL;

                msg (
                    p_message   =>
                           '  Got LineID: '
                        || x_oi_line_tbl (x_oi_line_tbl.COUNT).line_id);

                IF c_line.orig_line_id IS NOT NULL
                THEN
                    SELECT order_quantity_uom, unit_list_price, unit_selling_price,
                           tax_code
                      INTO l_uom_code, l_unit_list_price, l_unit_selling_price, l_tax_code
                      FROM oe_order_lines_all
                     WHERE line_id = c_line.orig_line_id;
                ELSE
                    SELECT primary_uom_code
                      INTO l_uom_code
                      --  FROM mtl_system_items_b                                                               --commented by BT Technology Team on 11/10/2014
                      FROM xxd_common_items_v
                     --Added by BT Technology team On 11/10/2014
                     WHERE     organization_id =
                               p_oi_header_rec.ship_from_org_id
                           AND inventory_item_id = c_line.inventory_item_id;

                    l_unit_list_price      :=
                        do_oe_utils.do_get_price_list_value (
                            p_price_list_id       => p_oi_header_rec.price_list_id,
                            p_inventory_item_id   => c_line.inventory_item_id,
                            p_uom_code            => l_uom_code);
                    l_unit_selling_price   := l_unit_list_price;

                    SELECT tax_code
                      INTO l_tax_code
                      FROM hz_cust_site_uses_all
                     WHERE site_use_id = p_oi_header_rec.ship_to_org_id;
                END IF;

                msg (
                    p_message   =>
                           '  UOM='
                        || l_uom_code
                        || ', List Price='
                        || l_unit_list_price
                        || ', Selling Price='
                        || l_unit_selling_price
                        || ', Tax Code='
                        || l_tax_code);

                IF l_unit_list_price IS NULL OR l_unit_selling_price IS NULL
                THEN
                    raise_application_error (-20001,
                                             'Failed to obtain unit price.');
                END IF;

                IF c_line.orig_line_id IS NOT NULL
                THEN
                    x_oi_line_tbl (x_oi_line_tbl.COUNT).line_type_id   :=
                        l_ot_line_type_id;
                ELSE
                    x_oi_line_tbl (x_oi_line_tbl.COUNT).line_type_id   :=
                        fnd_profile.VALUE (
                            'XXDO_3PL_EDI_RET_BLIND_LINE_TYPE_ID');
                END IF;

                msg (
                    p_message   =>
                           ' line_type_id='
                        || x_oi_line_tbl (x_oi_line_tbl.COUNT).line_type_id);

                IF x_oi_line_tbl (x_oi_line_tbl.COUNT).line_type_id IS NULL
                THEN
                    raise_application_error (-20001,
                                             'Failed to obtain line type.');
                END IF;

                x_oi_line_tbl (x_oi_line_tbl.COUNT).line_number   :=
                    x_oi_line_tbl.COUNT;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).open_flag   := 'Y';
                x_oi_line_tbl (x_oi_line_tbl.COUNT).payment_term_id   :=
                    p_oi_header_rec.payment_term_id;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).price_list_id   :=
                    p_oi_header_rec.price_list_id;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).org_id      :=
                    p_oi_header_rec.org_id;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).pricing_date   :=
                    SYSDATE;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).creation_date   :=
                    SYSDATE;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).last_update_date   :=
                    SYSDATE;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).created_by   :=
                    fnd_global.user_id;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).last_updated_by   :=
                    fnd_global.user_id;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).order_source_id   :=
                    p_oi_header_rec.order_source_id;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).orig_sys_document_ref   :=
                    p_oi_header_rec.orig_sys_document_ref;
                --Commented  for CCR0006788
                --x_oi_line_tbl (x_oi_line_tbl.COUNT).orig_sys_line_ref := '3PLGRN-' || c_line.grn_line_id;
                --End changes for CCR0006788
                x_oi_line_tbl (x_oi_line_tbl.COUNT).inventory_item_id   :=
                    c_line.inventory_item_id;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).ship_from_org_id   :=
                    p_oi_header_rec.ship_from_org_id;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).order_quantity_uom   :=
                    l_uom_code;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).pricing_quantity_uom   :=
                    l_uom_code;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).ship_to_org_id   :=
                    p_oi_header_rec.ship_to_org_id;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).pricing_quantity   :=
                    c_line.quantity_to_receive;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).ordered_quantity   :=
                    c_line.quantity_to_receive;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).unit_list_price   :=
                    l_unit_list_price;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).unit_selling_price   :=
                    l_unit_list_price;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).calculate_price_flag   :=
                    'N';
                x_oi_line_tbl (x_oi_line_tbl.COUNT).request_date   :=
                    p_oi_header_rec.request_date;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).salesrep_id   :=
                    p_oi_header_rec.salesrep_id;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).tax_code    :=
                    l_tax_code;
                x_oi_line_tbl (x_oi_line_tbl.COUNT).attribute1   :=
                    p_oi_header_rec.attribute1;

                --Added as per CCR0006805 (Japan eComm Ph2)
                IF c_line.return_reason_code IS NOT NULL
                THEN
                    BEGIN
                        SELECT lookup_code
                          INTO x_oi_line_tbl (x_oi_line_tbl.COUNT).return_reason_code
                          FROM apps.fnd_lookup_values
                         WHERE     lookup_type = 'CREDIT_MEMO_REASON'
                               AND lookup_code = c_line.return_reason_code
                               AND LANGUAGE = 'US'
                               AND enabled_flag = 'Y'
                               AND SYSDATE BETWEEN NVL (start_date_active,
                                                        SYSDATE - 1)
                                               AND NVL (end_date_active,
                                                        SYSDATE + 1);

                        msg (
                            p_message   =>
                                   ' x_oi_line_tbl (x_oi_line_tbl.COUNT).return_reason_code='
                                || x_oi_line_tbl (x_oi_line_tbl.COUNT).return_reason_code);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_oi_header_rec.return_reason_code   :=
                                fnd_profile.VALUE (
                                    'XXDO_3PL_EDI_RET_REASON_CODE');
                            msg (
                                p_message   =>
                                       '  x_oi_header_rec.return_reason_code='
                                    || p_oi_header_rec.return_reason_code);

                            IF p_oi_header_rec.return_reason_code IS NULL
                            THEN
                                raise_application_error (
                                    -20001,
                                       'Failed to obtain reason code.  OrgID='
                                    || fnd_global.org_id);
                            END IF;
                    END;
                ELSE
                    --Derive from profile and update header
                    p_oi_header_rec.return_reason_code   :=
                        fnd_profile.VALUE ('XXDO_3PL_EDI_RET_REASON_CODE');
                    msg (
                        p_message   =>
                               '  x_oi_header_rec.return_reason_code='
                            || p_oi_header_rec.return_reason_code);

                    IF p_oi_header_rec.return_reason_code IS NULL
                    THEN
                        raise_application_error (
                            -20001,
                               'Failed to obtain reason code.  OrgID='
                            || fnd_global.org_id);
                    END IF;
                END IF;                           --End for return_reason_code

                --Changes for COD Refunds for Japan eComm ph2
                /*
                Deliberately doing hard wire check for Japan eComm OU and Return Reason code for COD Refunds.
                This can be revisited when an eComm global change is in scope.
                */
                is_japan_ou                                     :=
                    'N';

                BEGIN
                    SELECT NVL ('Y', 'N')
                      INTO is_japan_ou
                      FROM apps.hr_operating_units
                     WHERE     NAME = 'Deckers Japan eCommerce OU'
                           AND organization_id =
                               (SELECT DISTINCT org_id
                                  FROM apps.oe_order_lines_all l
                                 WHERE l.line_id = c_line.orig_line_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        is_japan_ou   := 'N';
                END;

                is_japan_cod_order                              :=
                    0;

                BEGIN
                    SELECT COUNT (1)
                      INTO is_japan_cod_order
                      FROM apps.oe_price_adjustments opa
                     WHERE     opa.line_id = c_line.orig_line_id
                           AND opa.list_line_type_code = 'FREIGHT_CHARGE'
                           AND opa.charge_type_code = 'CODCHARGE';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        is_japan_cod_order   := 0;
                END;

                IF     x_oi_line_tbl (x_oi_line_tbl.COUNT).return_reason_code =
                       'ECOM - 0210'
                   AND is_japan_ou = 'Y'
                   AND is_japan_cod_order > 0
                THEN
                    --Call for charges
                    BEGIN
                        FOR c_chrgs IN c_orig_charges (c_line.orig_line_id)
                        LOOP
                            --l_adj_index := l_adj_index + 1;
                            x_oi_adj_tbl (x_oi_adj_tbl.COUNT + 1)   :=
                                oe_order_pub.g_miss_line_adj_rec;
                            x_oi_adj_tbl (x_oi_adj_tbl.COUNT).operation   :=
                                oe_globals.g_opr_create;
                            x_oi_adj_tbl (x_oi_adj_tbl.COUNT).line_index   :=
                                x_oi_line_tbl.COUNT;
                            x_oi_adj_tbl (x_oi_adj_tbl.COUNT).list_header_id   :=
                                c_chrgs.list_header_id;
                            x_oi_adj_tbl (x_oi_adj_tbl.COUNT).list_line_id   :=
                                c_chrgs.list_line_id;
                            x_oi_adj_tbl (x_oi_adj_tbl.COUNT).list_line_type_code   :=
                                c_chrgs.list_line_type_code;
                            x_oi_adj_tbl (x_oi_adj_tbl.COUNT).charge_type_code   :=
                                c_chrgs.charge_type_code;
                            x_oi_adj_tbl (x_oi_adj_tbl.COUNT).arithmetic_operator   :=
                                c_chrgs.arithmetic_operator;
                            x_oi_adj_tbl (x_oi_adj_tbl.COUNT).adjusted_amount   :=
                                c_chrgs.adjusted_amount;
                            x_oi_adj_tbl (x_oi_adj_tbl.COUNT).automatic_flag   :=
                                'N';
                            x_oi_adj_tbl (x_oi_adj_tbl.COUNT).applied_flag   :=
                                'Y';
                            x_oi_adj_tbl (x_oi_adj_tbl.COUNT).updated_flag   :=
                                'Y';

                            --Check for ordered quantity is more than 1 but customer returning only one quantity
                            IF c_chrgs.ordered_quantity !=
                               c_line.quantity_to_receive
                            THEN
                                l_per_unit_operand   :=
                                      c_chrgs.operand
                                    / c_chrgs.ordered_quantity;
                                x_oi_adj_tbl (x_oi_adj_tbl.COUNT).operand   :=
                                    (l_per_unit_operand * c_line.quantity_to_receive);
                            ELSE
                                x_oi_adj_tbl (x_oi_adj_tbl.COUNT).operand   :=
                                    c_chrgs.operand;
                            END IF;
                        END LOOP;                            --End for c_chrgs

                        IF x_oi_adj_tbl.COUNT > 0
                        THEN
                            x_ret_status   := fnd_api.g_ret_sts_success;
                            x_message      := NULL;
                        ELSE
                            x_ret_status   := fnd_api.g_ret_sts_error;
                            x_message      := 'There were no lines found.';
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            x_oi_adj_tbl.DELETE;
                            x_ret_status   := fnd_api.g_ret_sts_error;
                            x_message      := SQLERRM;
                    END;
                END IF;                           --End for return_reason_code

                --End Changes for COD Refunds for Japan eComm ph2
                --End Changes CCR0006805
                IF c_line.orig_line_id IS NOT NULL
                THEN
                    msg (
                        ' referecing original sales order line: ' || c_line.orig_line_id);
                    x_oi_line_tbl (x_oi_line_tbl.COUNT).return_context   :=
                        'ORDER';
                    x_oi_line_tbl (x_oi_line_tbl.COUNT).return_attribute1   :=
                        p_so_header_id;
                    x_oi_line_tbl (x_oi_line_tbl.COUNT).return_attribute2   :=
                        c_line.orig_line_id;
                END IF;

                x_oi_line_tbl (x_oi_line_tbl.COUNT).credit_invoice_line_id   :=
                    NULL;

                IF x_oi_line_tbl (x_oi_line_tbl.COUNT).unit_list_price !=
                   x_oi_line_tbl (x_oi_line_tbl.COUNT).unit_selling_price
                THEN
                    -- Price Adjustment Record Needed--
                    IF x_oi_line_tbl (x_oi_line_tbl.COUNT).unit_list_price =
                       0
                    THEN
                        raise_application_error (
                            -20001,
                            'Unable to create and adjustement for a 0 list price and non-zero selling price.');
                    END IF;

                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT + 1)            :=
                        oe_order_pub.g_miss_line_adj_rec;
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).operation      :=
                        oe_globals.g_opr_create;
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).header_id      :=
                        x_oi_line_tbl (x_oi_line_tbl.COUNT).header_id;
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).line_id        :=
                        x_oi_line_tbl (x_oi_line_tbl.COUNT).line_id;

                    IF x_oi_line_tbl (x_oi_line_tbl.COUNT).unit_list_price <
                       x_oi_line_tbl (x_oi_line_tbl.COUNT).unit_selling_price
                    THEN
                        l_adj_type_code   := 'SUR';
                    ELSE
                        l_adj_type_code   := 'DIS';
                    END IF;

                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).list_line_type_code   :=
                        l_adj_type_code;

                    BEGIN
                        msg (
                            p_message   =>
                                ' Looking up list_header_id and list_line_id.');
                        msg (
                            p_message   =>
                                   '  p_adjustment_type='
                                || x_oi_adj_tbl (x_oi_adj_tbl.COUNT).list_line_type_code
                                || ', p_currency_code='
                                || p_oi_header_rec.transactional_curr_code
                                || ', p_org_id='
                                || p_oi_header_rec.org_id);

                        SELECT list_header_id, list_line_id
                          INTO x_oi_adj_tbl (x_oi_adj_tbl.COUNT).list_header_id, x_oi_adj_tbl (x_oi_adj_tbl.COUNT).list_line_id
                          FROM (  SELECT qll.list_header_id, qll.list_line_id
                                    FROM qp_list_headers_b qlh, qp_list_lines qll
                                   WHERE     qlh.list_header_id =
                                             qll.list_header_id
                                         AND qll.list_line_type_code =
                                             l_adj_type_code
                                         AND qlh.currency_code =
                                             p_oi_header_rec.transactional_curr_code
                                         AND qlh.automatic_flag = 'N'
                                         AND qlh.active_flag = 'Y'
                                         AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         qlh.start_date_active,
                                                                           SYSDATE
                                                                         - 1)
                                                                 AND NVL (
                                                                         qlh.end_date_active,
                                                                           SYSDATE
                                                                         + 1)
                                         AND (qlh.global_flag = 'Y' OR qlh.orig_org_id = p_oi_header_rec.org_id)
                                         AND qll.automatic_flag = 'N'
                                         AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         qll.start_date_active,
                                                                           SYSDATE
                                                                         - 1)
                                                                 AND NVL (
                                                                         qll.end_date_active,
                                                                           SYSDATE
                                                                         + 1)
                                         AND qll.modifier_level_code = 'LINE'
                                ORDER BY DECODE (qlh.orig_org_id, NULL, 0, 1), qll.list_line_id)
                         WHERE ROWNUM = 1;

                        msg (
                            p_message   =>
                                   ' list_header_id='
                                || x_oi_adj_tbl (x_oi_adj_tbl.COUNT).list_header_id
                                || ', list_line_id='
                                || x_oi_adj_tbl (x_oi_adj_tbl.COUNT).list_line_id);
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            raise_application_error (
                                -20001,
                                   'Unable to determine discount types for currency code '
                                || p_oi_header_rec.transactional_curr_code);
                    END;

                    SELECT oe_price_adjustments_s.NEXTVAL
                      INTO x_oi_adj_tbl (x_oi_adj_tbl.COUNT).price_adjustment_id
                      FROM DUAL;

                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).orig_sys_discount_ref   :=
                           x_oi_line_tbl (x_oi_line_tbl.COUNT).orig_sys_line_ref
                        || '-ADJ';
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).created_by     :=
                        fnd_global.user_id;
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).last_updated_by   :=
                        fnd_global.user_id;
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).creation_date   :=
                        SYSDATE;
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).last_update_date   :=
                        SYSDATE;
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).applied_flag   := 'Y';
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).PERCENT        :=
                          ((x_oi_line_tbl (x_oi_line_tbl.COUNT).unit_list_price - x_oi_line_tbl (x_oi_line_tbl.COUNT).unit_selling_price) / x_oi_line_tbl (x_oi_line_tbl.COUNT).unit_list_price)
                        * 100;
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).operand        :=
                        x_oi_adj_tbl (x_oi_adj_tbl.COUNT).PERCENT;
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).arithmetic_operator   :=
                        '%';
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).adjusted_amount   :=
                          x_oi_line_tbl (x_oi_line_tbl.COUNT).unit_selling_price
                        - x_oi_line_tbl (x_oi_line_tbl.COUNT).unit_list_price;
                    x_oi_adj_tbl (x_oi_adj_tbl.COUNT).automatic_flag   :=
                        'N';
                END IF;
            END LOOP;

            IF x_oi_line_tbl.COUNT > 0
            THEN
                x_ret_status   := fnd_api.g_ret_sts_success;
                x_message      := NULL;
            ELSE
                x_ret_status   := fnd_api.g_ret_sts_error;
                x_message      := 'There were no lines found.';
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_oi_line_tbl.DELETE;
                x_ret_status   := fnd_api.g_ret_sts_error;
                x_message      := SQLERRM;
        END;

        msg (' x_ret_status=' || x_ret_status || ', x_message=' || x_message);
        msg (p_message => '-' || l_proc_name);
    END;

    PROCEDURE run_order_import (p_grn_header_id IN NUMBER, p_oi_header_rec IN oe_order_pub.header_rec_type, p_oi_line_tbl IN oe_order_pub.line_tbl_type
                                , p_oi_adj_tbl IN oe_order_pub.line_adj_tbl_type, x_ret_status OUT VARCHAR2, x_message OUT VARCHAR2)
    IS
        l_proc_name                VARCHAR2 (240)
                                       := lg_package_name || '.RUN_ORDER_IMPORT';
        p_request_tbl              oe_order_pub.request_tbl_type;
        -- API Variables
        x_return_status            VARCHAR2 (1);
        x_msg_data                 VARCHAR2 (2000);
        x_msg_count                NUMBER;
        x_header_rec               oe_order_pub.header_rec_type;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_tbl                 oe_order_pub.line_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
        l_resp_id                  NUMBER;
        l_app_id                   NUMBER;
        l_user_id                  NUMBER;
        v_org_id                   NUMBER;

        FUNCTION get_api_errors (p_msg_count NUMBER)
            RETURN VARCHAR2
        IS
            l_message    VARCHAR2 (2000);
            l_next_msg   NUMBER;
            l_ret        VARCHAR2 (4000);
        BEGIN
            l_ret   := NULL;

            IF p_msg_count > 0
            THEN
                FOR i IN 1 .. p_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_message
                                    , p_msg_index_out => l_next_msg);
                    msg (p_message => '  Error #' || i || ': ' || l_message);
                    l_ret   := SUBSTR (l_ret || '. ' || l_message, 1, 4000);
                END LOOP;
            END IF;

            RETURN l_ret;
        END;
    BEGIN
        BEGIN
            msg (p_message => '+' || l_proc_name);
            p_request_tbl.DELETE;

            IF NVL (p_grn_header_id, -1) > 0
            THEN
                msg (p_message => '  GRN Header ID: ' || p_grn_header_id);
                p_request_tbl (1).request_type   := oe_globals.g_book_order;
                p_request_tbl (1).entity_code    :=
                    oe_globals.g_entity_header;
            END IF;

            --Added  by Chaithanya Chimmapudi for BTUAT2 defect fix
            SELECT user_id
              INTO l_user_id
              FROM fnd_user
             WHERE user_name = 'BATCH';

            v_org_id    := fnd_global.org_id;
            get_resp_app_id (p_org_id              => v_org_id,
                             x_responsibility_id   => l_resp_id,
                             x_application_id      => l_app_id);
            apps.fnd_global.apps_initialize (user_id        => l_user_id,
                                             resp_id        => l_resp_id,
                                             resp_appl_id   => l_app_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', v_org_id);
            --End code changes by Chaithanya Chimmapudi
            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_org_id                   => fnd_global.org_id,
                p_init_msg_list            => fnd_api.g_true,
                p_header_rec               => p_oi_header_rec,
                p_line_tbl                 => p_oi_line_tbl,
                p_line_adj_tbl             => p_oi_adj_tbl,
                p_action_request_tbl       => p_request_tbl,
                x_return_status            => x_ret_status,
                x_msg_data                 => x_msg_data,
                x_msg_count                => x_msg_count,
                x_header_rec               => x_header_rec,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => x_line_tbl,
                x_line_val_tbl             => x_line_val_tbl,
                x_line_adj_tbl             => x_line_adj_tbl,
                x_line_adj_val_tbl         => x_line_adj_val_tbl,
                x_line_price_att_tbl       => x_line_price_att_tbl,
                x_line_adj_att_tbl         => x_line_adj_att_tbl,
                x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
                x_line_scredit_tbl         => x_line_scredit_tbl,
                x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
                x_lot_serial_tbl           => x_lot_serial_tbl,
                x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
                x_action_request_tbl       => x_action_request_tbl);

            -- Remove link to original invoice.  This causes errors during receiving/autoinvoice when the original invoice has already been paid in full. --
            IF NVL (p_grn_header_id, -1) > 0
            THEN
                UPDATE apps.oe_order_lines_all
                   SET credit_invoice_line_id = NULL, reference_customer_trx_line_id = NULL
                 WHERE header_id = x_header_rec.header_id;
            END IF;

            x_message   := get_api_errors (x_msg_count);
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_status   := fnd_api.g_ret_sts_error;
                x_message      := SQLERRM;
        END;

        msg (' x_ret_status=' || x_ret_status || ', x_message=' || x_message);
        msg (p_message => '-' || l_proc_name);
    END;

    PROCEDURE create_return (p_grn_header_id IN NUMBER, x_ret_status OUT VARCHAR2, x_message OUT VARCHAR2)
    IS
        l_proc_name       VARCHAR2 (240) := lg_package_name || '.CREATE_RETURN';
        l_so_header_id    NUMBER;
        l_org_id          NUMBER;
        l_resp_id         NUMBER;
        l_app_id          NUMBER;
        l_oi_header_rec   oe_order_pub.header_rec_type;
        l_oi_line_tbl     oe_order_pub.line_tbl_type;
        l_oi_adj_tbl      oe_order_pub.line_adj_tbl_type;
        l_user_id         NUMBER;             --added by BT team on 11/10/2014
    BEGIN
        SELECT user_id
          INTO l_user_id
          FROM fnd_user
         WHERE user_name = 'BATCH';           --added by BT team on 11/10/2014

        BEGIN
            SAVEPOINT before_return_create;
            msg (p_message => '+' || l_proc_name);
            msg (p_message => '  GRN Header ID: ' || p_grn_header_id);

            BEGIN
                SELECT DISTINCT ooha.header_id, ooha.org_id
                  INTO l_so_header_id, l_org_id
                  FROM xxdo.xxdo_wms_3pl_grn_h grnh, oe_order_headers_all ooha
                 WHERE     grnh.grn_header_id = p_grn_header_id
                       AND SUBSTR (grnh.preadvice_id, 1, 3) IN ('RTN', 'RET')
                       AND ooha.order_number =
                           TO_NUMBER (SUBSTR (grnh.preadvice_id, 4));
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    raise_application_error (
                        -20001,
                           'Failed to resolve GRN Header ID '
                        || p_grn_header_id
                        || ' to a sales order.');
                WHEN OTHERS
                THEN
                    raise_application_error (
                        -20001,
                        'Failed to load sales order data.  ' || SQLERRM);
            END;

            msg (
                p_message   =>
                       '  Sales Order Header ID: '
                    || l_so_header_id
                    || ', Org ID: '
                    || l_org_id);
            get_resp_app_id (p_org_id              => l_org_id,
                             x_responsibility_id   => l_resp_id,
                             x_application_id      => l_app_id);
            msg (
                p_message   =>
                    '  RespID=' || l_resp_id || ', AppID=' || l_app_id);
            -- apps.fnd_global.apps_initialize (user_id           => 1037,                 --commented by BT Technology Team on 11/10/2014
            apps.fnd_global.apps_initialize (user_id        => l_user_id,
                                             --added by BT team on 11/10/2014
                                             resp_id        => l_resp_id,
                                             resp_appl_id   => l_app_id);
            msg (p_message => 'Building header record.');
            build_return_header_rec (p_grn_header_id   => p_grn_header_id,
                                     p_so_header_id    => l_so_header_id,
                                     x_oi_header_rec   => l_oi_header_rec,
                                     x_ret_status      => x_ret_status,
                                     x_message         => x_message);

            IF NVL (x_ret_status, fnd_api.g_ret_sts_error) =
               fnd_api.g_ret_sts_success
            THEN
                msg (p_message => 'Building line table.');
                build_return_line_tbl (p_grn_header_id => p_grn_header_id, p_so_header_id => l_so_header_id, p_oi_header_rec => l_oi_header_rec, x_oi_line_tbl => l_oi_line_tbl, x_oi_adj_tbl => l_oi_adj_tbl, x_ret_status => x_ret_status
                                       , x_message => x_message);
            END IF;

            IF NVL (x_ret_status, fnd_api.g_ret_sts_error) =
               fnd_api.g_ret_sts_success
            THEN
                msg (p_message => 'Running order import.');
                run_order_import (p_grn_header_id   => p_grn_header_id,
                                  p_oi_header_rec   => l_oi_header_rec,
                                  p_oi_line_tbl     => l_oi_line_tbl,
                                  p_oi_adj_tbl      => l_oi_adj_tbl,
                                  x_ret_status      => x_ret_status,
                                  x_message         => x_message);
            END IF;

            IF NVL (x_ret_status, fnd_api.g_ret_sts_error) =
               fnd_api.g_ret_sts_success
            THEN
                msg (
                    p_message   =>
                        'Updating GRN header record with return header_id.');

                UPDATE xxdo.xxdo_wms_3pl_grn_h
                   SET source_header_id   = l_oi_header_rec.header_id
                 WHERE grn_header_id = p_grn_header_id;

                FOR idx IN 1 .. l_oi_line_tbl.COUNT
                LOOP
                    msg (
                        p_message   =>
                            'Updating GRN line record with return line_id.');

                    --Changed for CCR0006788

                    /*UPDATE xxdo.xxdo_wms_3pl_grn_l
                      SET source_line_id = l_oi_line_tbl (idx).line_id
                    WHERE grn_line_id = TO_NUMBER (SUBSTR (l_oi_line_tbl (idx).orig_sys_line_ref, 8));
                    */
                    BEGIN
                        UPDATE xxdo.xxdo_wms_3pl_grn_l
                           SET source_line_id   = l_oi_line_tbl (idx).line_id
                         WHERE grn_line_id IN
                                   (SELECT grn_line_id
                                      FROM xxdo.xxdo_wms_3pl_grn_l
                                     WHERE     grn_header_id =
                                               p_grn_header_id
                                           AND inventory_item_id =
                                               l_oi_line_tbl (idx).inventory_item_id
                                           AND qty_received =
                                               l_oi_line_tbl (idx).ordered_quantity);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            UPDATE xxdo.xxdo_wms_3pl_grn_l
                               SET source_line_id = l_oi_line_tbl (idx).line_id
                             WHERE grn_line_id IN
                                       (SELECT grn_line_id
                                          FROM xxdo.xxdo_wms_3pl_grn_l
                                         WHERE     grn_header_id =
                                                   p_grn_header_id
                                               AND inventory_item_id =
                                                   l_oi_line_tbl (idx).inventory_item_id
                                               AND qty_received =
                                                   l_oi_line_tbl (idx).ordered_quantity
                                               AND ROWNUM = 1);
                    END;
                --End changes for CCR0006788
                END LOOP;
            END IF;

            IF NVL (x_ret_status, fnd_api.g_ret_sts_error) !=
               fnd_api.g_ret_sts_success
            THEN
                msg ('Erorrs encountered.  Rolling back to savepoint.');
                ROLLBACK TO before_return_create;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_return_create;
                x_ret_status   := fnd_api.g_ret_sts_error;
                x_message      := SQLERRM;
        END;

        msg (' x_ret_status=' || x_ret_status || ', x_message=' || x_message);
        msg (p_message => '-' || l_proc_name);
    END;

    -- RETURNS END --
    PROCEDURE change_cust_po_number (p_osc_header_id IN NUMBER, p_cust_po_number IN VARCHAR2, x_ret_stat OUT VARCHAR2
                                     , x_message OUT VARCHAR2)
    IS
        l_oe_header_id     NUMBER;
        l_oe_order_count   NUMBER;
        l_curr_po_number   oe_order_headers_all.cust_po_number%TYPE;
        l_org_id           NUMBER;
        l_resp_id          NUMBER;
        l_app_id           NUMBER;
        l_header_rec       oe_order_pub.header_rec_type;
        l_line_tbl         oe_order_pub.line_tbl_type;
        x_header_rec       oe_order_pub.header_rec_type;
        x_header_adj_tbl   oe_order_pub.header_adj_tbl_type;
        x_line_tbl         oe_order_pub.line_tbl_type;
        x_line_adj_tbl     oe_order_pub.line_adj_tbl_type;
        l_return_status    VARCHAR2 (1) := fnd_api.g_ret_sts_success;
        x_error_text       VARCHAR2 (2000);
        l_proc_name        VARCHAR2 (240)
                               := lg_package_name || '.change_cust_po_number';

        CURSOR c_lines (p_header_id NUMBER)
        IS
              SELECT line_id
                FROM oe_order_lines_all
               WHERE header_id = p_header_id AND open_flag = 'Y'
            ORDER BY line_id;

        u_id               NUMBER; --added by BT Technology team on 11/10/2014
    BEGIN
        BEGIN
            SELECT user_id
              INTO u_id
              FROM fnd_user
             WHERE user_name = 'BATCH';

            --added by BT Technology team on 11/10/2014

            SAVEPOINT before_update_po;
            msg (p_message => '+' || l_proc_name);
            msg (p_message => '  OSC Header ID: ' || p_osc_header_id);
            msg (p_message => '  New PO #: ' || p_cust_po_number);

            SELECT MAX (ooha.header_id) AS header_id, MAX (ooha.cust_po_number) AS cust_po_number, COUNT (DISTINCT ooha.header_id) AS order_count,
                   MAX (ooha.org_id) AS org_id
              INTO l_oe_header_id, l_curr_po_number, l_oe_order_count, l_org_id
              FROM xxdo.xxdo_wms_3pl_osc_l oscl, apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
             WHERE     oscl.osc_header_id = p_osc_header_id
                   AND oola.line_id = oscl.source_line_id
                   AND ooha.header_id = oola.header_id;

            msg (
                p_message   =>
                       '  OE Header ID: '
                    || l_oe_header_id
                    || ', Current PO #: '
                    || l_curr_po_number
                    || ', OE Order Count: '
                    || l_oe_order_count
                    || ', Org ID: '
                    || l_org_id);

            IF l_oe_order_count != 1
            THEN
                ROLLBACK TO before_update_po;
                x_ret_stat   := fnd_api.g_ret_sts_error;
                x_message    :=
                       'There are '
                    || l_oe_order_count
                    || ' orders associated with the current load confirm record.';
            ELSIF l_curr_po_number IS NOT NULL
            THEN
                ROLLBACK TO before_update_po;
                x_ret_stat   := fnd_api.g_ret_sts_success;
                x_message    := NULL;
            ELSE
                -- So far, so good --
                get_resp_app_id (p_org_id              => l_org_id,
                                 x_responsibility_id   => l_resp_id,
                                 x_application_id      => l_app_id);
                msg (
                    p_message   =>
                        '  RespID=' || l_resp_id || ', AppID=' || l_app_id);
                apps.fnd_global.apps_initialize (--user_id           => 1037,                       --commented by BT Technology  Team on 11/10/2014
                                                 user_id        => u_id,
                                                 --Added by BT Technology Team on 11/10/2014
                                                 resp_id        => l_resp_id,
                                                 resp_appl_id   => l_app_id);
                mo_global.set_org_context (
                    p_org_id_char       => TO_CHAR (l_org_id),
                    p_sp_id_char        => '',
                    p_appl_short_name   => 'CUSTOM');
                l_header_rec                  := oe_order_pub.g_miss_header_rec;
                l_header_rec.operation        := oe_globals.g_opr_update;
                l_header_rec.header_id        := l_oe_header_id;
                l_header_rec.cust_po_number   := p_cust_po_number;
                l_header_rec.org_id           := l_org_id;

                FOR c_line IN c_lines (l_oe_header_id)
                LOOP
                    msg (p_message => '  OE Line ID: ' || c_line.line_id);
                    l_line_tbl (l_line_tbl.COUNT + 1)       :=
                        oe_order_pub.g_miss_line_rec;
                    l_line_tbl (l_line_tbl.COUNT).operation   :=
                        oe_globals.g_opr_update;
                    l_line_tbl (l_line_tbl.COUNT).line_id   := c_line.line_id;
                    l_line_tbl (l_line_tbl.COUNT).cust_po_number   :=
                        p_cust_po_number;
                    l_line_tbl (l_line_tbl.COUNT).org_id    :=
                        l_org_id;
                END LOOP;

                run_order_import (p_grn_header_id   => -1,
                                  p_oi_header_rec   => l_header_rec,
                                  p_oi_line_tbl     => l_line_tbl,
                                  p_oi_adj_tbl      => x_line_adj_tbl,
                                  x_ret_status      => x_ret_stat,
                                  x_message         => x_message);
                msg ('Returned from PROCESS_ORDER call');

                IF NVL (x_ret_stat, fnd_api.g_ret_sts_error) !=
                   fnd_api.g_ret_sts_success
                THEN
                    msg ('Erorrs encountered.  Rolling back to savepoint.');
                    ROLLBACK TO before_update_po;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_update_po;
                x_ret_stat   := fnd_api.g_ret_sts_error;
                x_message    := SQLERRM;
        END;

        msg (' x_ret_status=' || x_ret_stat || ', x_message=' || x_message);
        msg (p_message => '-' || l_proc_name);
    END;

    PROCEDURE m_end (x_ret_stat VARCHAR2, x_message VARCHAR2)
    IS
    BEGIN
        IF g_mail_debugging
        THEN
            IF x_ret_stat = g_ret_success
            THEN
                m_msg ('--boundarystring');
                m_msg ('Content-Type: text/plain');
                m_msg ('');
            END IF;

            m_msg ('Returning with a status of: ' || x_ret_stat);

            IF NVL (x_ret_stat, g_ret_unexp_error) != g_ret_success
            THEN
                m_msg ('Message: ' || x_message);
            END IF;

            m_end;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END;

    PROCEDURE rcv_headers_insert (p_receipt_source_code       VARCHAR2,
                                  p_shipment_num              VARCHAR2,
                                  p_receipt_date              DATE,
                                  p_organization_id           NUMBER,
                                  x_ret_stat              OUT VARCHAR2,
                                  x_message               OUT VARCHAR2,
                                  p_customer_id               NUMBER := NULL,
                                  p_vendor_id                 NUMBER := NULL)
    IS
    BEGIN
        INSERT INTO apps.rcv_headers_interface (header_interface_id,
                                                GROUP_ID,
                                                processing_status_code,
                                                receipt_source_code,
                                                transaction_type,
                                                auto_transact_code,
                                                last_update_date,
                                                last_updated_by,
                                                last_update_login,
                                                creation_date,
                                                created_by,
                                                shipment_num,
                                                ship_to_organization_id,
                                                expected_receipt_date,
                                                employee_id,
                                                validation_flag,
                                                customer_id,
                                                vendor_id)
            (SELECT apps.rcv_headers_interface_s.NEXTVAL --header_interface_id
                                                        , apps.rcv_interface_groups_s.NEXTVAL --group_id
                                                                                             , 'PENDING' --processing_status_code
                                                                                                        , p_receipt_source_code --receipt_source_code
                                                                                                                               , 'NEW' --transaction_type
                                                                                                                                      , 'DELIVER' --auto_transact_code
                                                                                                                                                 , SYSDATE --last_update_date
                                                                                                                                                          , apps.fnd_global.user_id --last_update_by
                                                                                                                                                                                   , USERENV ('SESSIONID') --last_update_login
                                                                                                                                                                                                          , SYSDATE --creation_date
                                                                                                                                                                                                                   , apps.fnd_global.user_id --created_by
                                                                                                                                                                                                                                            , p_shipment_num --shipment_num
                                                                                                                                                                                                                                                            , p_organization_id --ship_to_organization_id
                                                                                                                                                                                                                                                                               , NVL (p_receipt_date, SYSDATE + 1) --expected_receipt_date
                                                                                                                                                                                                                                                                                                                  , apps.fnd_global.employee_id --employee_id
                                                                                                                                                                                                                                                                                                                                               , 'Y' --validation_flag
                                                                                                                                                                                                                                                                                                                                                    , p_customer_id, p_vendor_id FROM DUAL);

        x_ret_stat   := g_ret_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_error;
            x_message    := SQLERRM;
    END;

    PROCEDURE rcv_lines_insert (
        p_org_id                            NUMBER,
        p_receipt_source_code               VARCHAR2,
        p_source_document_code              VARCHAR2,
        p_group_id                          NUMBER,
        p_location_id                       NUMBER,
        p_subinventory                      VARCHAR2,
        p_header_interface_id               NUMBER,
        p_shipment_num                      VARCHAR2,
        p_receipt_date                      DATE,
        p_item_id                           NUMBER,
        p_uom                               VARCHAR2,
        p_quantity                          NUMBER,
        x_ret_stat                      OUT VARCHAR2,
        x_message                       OUT VARCHAR2,
        p_shipment_header_id                NUMBER := NULL,
        p_shipment_line_id                  NUMBER := NULL,
        p_ship_to_location_id               NUMBER := NULL,
        p_from_organization_id              NUMBER := NULL,
        p_to_organization_id                NUMBER := NULL,
        p_requisition_line_id               NUMBER := NULL,
        p_requisition_distribution_id       NUMBER := NULL,
        p_deliver_to_person_id              NUMBER := NULL,
        p_deliver_to_location_id            NUMBER := NULL,
        p_oe_order_header_id                NUMBER := NULL,
        p_oe_order_line_id                  NUMBER := NULL,
        p_customer_id                       NUMBER := NULL,
        p_customer_site_id                  NUMBER := NULL,
        p_vendor_id                         NUMBER := NULL,
        p_parent_transaction_id             NUMBER := NULL,
        p_duty_paid_flag                    VARCHAR2 := NULL,
        --Added as per ver 1.1
        p_carton_code                       VARCHAR2 := NULL,
        p_receipt_type                      VARCHAR2   --Added for change 1.10
                                                    ) --Added for carton code support
    IS
        l_cnt              NUMBER;
        l_trx_type         VARCHAR2 (20);
        ln_del_cnt         NUMBER := 0;                --Added for change 1.10
        ln_int_trx_id      NUMBER := TO_NUMBER (NULL);
        --Added for change 1.10
        ln_parent_trx_id   NUMBER := TO_NUMBER (NULL);
        --Added for change 1.10
        ln_int_trx_qty     NUMBER := 0;                 --Added for CCR0009513
    BEGIN
        /*Start of changes for 1.10*/
        /*SELECT COUNT (1)
             INTO l_cnt
             FROM apps.rcv_shipment_lines rsl,
                  apps.po_line_locations_all plla,
                  apps.fnd_lookup_values flv
            WHERE rsl.shipment_line_id = p_shipment_line_id
              AND plla.line_location_id = rsl.po_line_location_id
              AND flv.lookup_type = 'RCV_ROUTING_HEADERS'
              AND flv.LANGUAGE = 'US'
              AND flv.lookup_code = TO_CHAR (plla.receiving_routing_id)
              AND flv.view_application_id = 0
              AND flv.security_group_id = 0
              AND flv.meaning = 'Standard Receipt';
           IF l_cnt = 1
           THEN
              l_trx_type := 'DELIVER';
           ELSE
              l_trx_type := 'RECEIVE';
           END IF;*/
        IF p_receipt_type IS NULL
        THEN
            SELECT COUNT (1)
              INTO l_cnt
              FROM apps.rcv_shipment_lines rsl, apps.po_line_locations_all plla, apps.fnd_lookup_values flv
             WHERE     rsl.shipment_line_id = p_shipment_line_id
                   AND plla.line_location_id = rsl.po_line_location_id
                   AND flv.lookup_type = 'RCV_ROUTING_HEADERS'
                   AND flv.LANGUAGE = 'US'
                   AND flv.lookup_code = TO_CHAR (plla.receiving_routing_id)
                   AND flv.view_application_id = 0
                   AND flv.security_group_id = 0
                   AND flv.meaning = 'Standard Receipt';

            IF l_cnt = 1
            THEN
                l_trx_type   := 'DELIVER';
            ELSE
                l_trx_type   := 'RECEIVE';
            END IF;

            ln_parent_trx_id   := p_parent_transaction_id;
        ELSE
            IF p_receipt_type = 'DELIVER'
            THEN
                IF p_oe_order_line_id IS NULL
                THEN
                    SELECT COUNT (*)
                      INTO ln_del_cnt
                      FROM xxdo.xxdo_wms_3pl_grn_l l
                     WHERE     source_line_id = p_shipment_line_id
                           AND l.process_status = 'S'
                           AND l.receipt_type = 'RECEIVE'
                           AND l.processing_session_id =
                               USERENV ('SESSIONID')
                           AND TRUNC (last_update_date) = TRUNC (SYSDATE)
                           AND EXISTS
                                   (SELECT 1
                                      FROM rcv_transactions_interface
                                     WHERE     shipment_line_id =
                                               p_shipment_line_id
                                           AND auto_transact_code = 'RECEIVE'
                                           AND processing_status_code =
                                               'PENDING');

                    IF NVL (ln_del_cnt, 0) > 0
                    THEN
                        BEGIN
                            SELECT interface_transaction_id
                              INTO ln_int_trx_id
                              FROM rcv_transactions_interface
                             WHERE     shipment_line_id = p_shipment_line_id
                                   AND auto_transact_code = 'RECEIVE'
                                   AND processing_status_code = 'PENDING'
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_int_trx_id   := TO_NUMBER (NULL);
                        END;

                        l_trx_type         := NULL;
                        ln_parent_trx_id   := TO_NUMBER (NULL);
                    ELSE
                        l_trx_type         := p_receipt_type;
                        ln_parent_trx_id   := p_parent_transaction_id;
                    END IF;
                END IF;

                IF p_oe_order_line_id IS NOT NULL
                THEN
                    SELECT COUNT (*)
                      INTO ln_del_cnt
                      FROM xxdo.xxdo_wms_3pl_grn_l l
                     WHERE     source_line_id = p_oe_order_line_id
                           AND l.process_status = 'S'
                           AND l.receipt_type = 'RECEIVE'
                           AND l.processing_session_id =
                               USERENV ('SESSIONID')
                           AND TRUNC (last_update_date) = TRUNC (SYSDATE)
                           AND EXISTS
                                   (SELECT 1
                                      FROM rcv_transactions_interface
                                     WHERE     oe_order_line_id =
                                               p_oe_order_line_id
                                           AND auto_transact_code = 'RECEIVE'
                                           AND processing_status_code =
                                               'PENDING');

                    IF ln_del_cnt > 0
                    THEN
                        BEGIN
                            SELECT interface_transaction_id
                              INTO ln_int_trx_id
                              FROM rcv_transactions_interface
                             WHERE     oe_order_line_id = p_oe_order_line_id
                                   AND auto_transact_code = 'RECEIVE'
                                   AND processing_status_code = 'PENDING'
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_int_trx_id   := TO_NUMBER (NULL);
                        END;

                        l_trx_type         := NULL;
                        ln_parent_trx_id   := TO_NUMBER (NULL);
                    ELSE
                        l_trx_type         := p_receipt_type;
                        ln_parent_trx_id   := p_parent_transaction_id;
                    END IF;
                END IF;
            ELSE
                l_trx_type   := p_receipt_type;
            END IF;
        END IF;

        /*End of changes for 1.10*/
        INSERT INTO apps.rcv_transactions_interface (
                        interface_transaction_id,
                        GROUP_ID,
                        org_id,
                        last_update_date,
                        last_updated_by,
                        creation_date,
                        created_by,
                        last_update_login,
                        transaction_type,
                        transaction_date,
                        processing_status_code,
                        processing_mode_code,
                        transaction_status_code,
                        quantity,
                        unit_of_measure,
                        interface_source_code,
                        item_id,
                        employee_id,
                        auto_transact_code,
                        shipment_header_id,
                        shipment_line_id,
                        ship_to_location_id,
                        receipt_source_code,
                        to_organization_id,
                        source_document_code,
                        requisition_line_id,
                        req_distribution_id,
                        destination_type_code,
                        deliver_to_person_id,
                        location_id,
                        deliver_to_location_id,
                        subinventory,
                        shipment_num,
                        expected_receipt_date,
                        header_interface_id,
                        validation_flag,
                        oe_order_header_id,
                        oe_order_line_id,
                        customer_id,
                        customer_site_id,
                        vendor_id,
                        parent_transaction_id,
                        attribute11,                    --Added as per ver 1.1
                        attribute6,
                        parent_interface_txn_id        --Added for change 1.10
                                               )                 --carton code
            (SELECT apps.rcv_transactions_interface_s.NEXTVAL, -- interface_transaction_id
                                                               p_group_id, --group_id
                                                                           p_org_id, SYSDATE, --last_update_date
                                                                                              apps.fnd_global.user_id, --last_updated_by
                                                                                                                       SYSDATE, --creation_date
                                                                                                                                apps.fnd_global.user_id, --created_by
                                                                                                                                                         USERENV ('SESSIONID'), --last_update_login
                                                                                                                                                                                NVL (l_trx_type, 'DELIVER'), --'DELIVER'     --transaction_type  --Modified for change 1.10
                                                                                                                                                                                                             --Added as per CCR0006788
                                                                                                                                                                                                             NVL (p_receipt_date, SYSDATE), --transaction_date
                                                                                                                                                                                                                                            --End for CCR0006788
                                                                                                                                                                                                                                            'PENDING', --processing_status_code
                                                                                                                                                                                                                                                       'BATCH', --processing_mode_code
                                                                                                                                                                                                                                                                'PENDING', --transaction_status_code
                                                                                                                                                                                                                                                                           p_quantity, --quantity
                                                                                                                                                                                                                                                                                       p_uom, --unit_of_measure
                                                                                                                                                                                                                                                                                              'RCV', --interface_source_code
                                                                                                                                                                                                                                                                                                     p_item_id, --item_id
                                                                                                                                                                                                                                                                                                                apps.fnd_global.employee_id, --employee_id
                                                                                                                                                                                                                                                                                                                                             DECODE (p_receipt_type, NULL, 'DELIVER', l_trx_type), --'DELIVER'  --auto_transact_code --Modified for change 1.10
                                                                                                                                                                                                                                                                                                                                                                                                   p_shipment_header_id, --shipment_header_id
                                                                                                                                                                                                                                                                                                                                                                                                                         p_shipment_line_id, --shipment_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                             p_ship_to_location_id, --ship_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                    p_receipt_source_code, --receipt_source_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           p_to_organization_id, --to_organization_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 p_source_document_code, --source_document_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         p_requisition_line_id, --requisition_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                p_requisition_distribution_id, --req_distribution_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               'INVENTORY', --destination_type_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            p_deliver_to_person_id, --deliver_to_person_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    p_location_id, --location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   p_deliver_to_location_id, --deliver_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             DECODE (p_receipt_type, 'RECEIVE', NULL, p_subinventory), --subinventory
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       p_shipment_num, --shipment_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       p_receipt_date, --expected_receipt_date,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       p_header_interface_id, --header_interface_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              'Y', --validation_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   p_oe_order_header_id, p_oe_order_line_id, p_customer_id, p_customer_site_id, p_vendor_id, ln_parent_trx_id, -- p_parent_transaction_id,--Modified for change 1.10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               p_duty_paid_flag, p_carton_code, ln_int_trx_id --Added for change 1.10
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              FROM DUAL);

        x_ret_stat   := g_ret_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_error;
            x_message    := SQLERRM;
    END;

    PROCEDURE rcv_line (p_source_document_code        VARCHAR2,
                        p_source_line_id              NUMBER,
                        p_quantity                    NUMBER,
                        x_ret_stat                OUT VARCHAR2,
                        x_message                 OUT VARCHAR2,
                        p_subinventory                VARCHAR2 := NULL,
                        --p_receipt_date                DATE := SYSDATE,
                        --Commented and added as per CCR0006788
                        p_receipt_date                DATE,
                        --End changes for CCR0006788
                        p_parent_transaction_id       NUMBER := NULL,
                        p_duty_paid_flag              VARCHAR2 := NULL, --Added as per ver 1.1
                        p_carton_code                 VARCHAR2 := NULL,
                        p_receipt_type                VARCHAR2 --Added for change 1.10
                                                              ) --Added to support 3PL carton receiving
    IS
        l_header_interface_id    NUMBER;
        l_group_id               NUMBER;
        l_location_id            NUMBER;
        l_item_id                NUMBER;
        l_uom                    VARCHAR2 (240);
        --
        l_receipt_source_code    VARCHAR2 (240);
        l_organization_id        NUMBER;
        l_org_id                 NUMBER;
        l_vendor_id              NUMBER;
        --return
        l_order_header_rec       apps.oe_order_headers_all%ROWTYPE;
        l_order_line_rec         apps.oe_order_lines_all%ROWTYPE;
        --Shipments
        l_shipment_header_rec    apps.rcv_shipment_headers%ROWTYPE;
        l_shipment_line_rec      apps.rcv_shipment_lines%ROWTYPE;
        --requisition
        l_req_header_rec         apps.po_requisition_headers_all%ROWTYPE;
        l_req_line_rec           apps.po_requisition_lines_all%ROWTYPE;
        --PO
        l_po_header_rec          apps.po_headers_all%ROWTYPE;
        l_po_line_rec            apps.po_lines_all%ROWTYPE;
        l_po_line_location_rec   apps.po_line_locations_all%ROWTYPE;
        l_po_distribution_rec    apps.po_distributions_all%ROWTYPE;
    BEGIN
        IF p_source_document_code = 'PO'
        THEN
            l_receipt_source_code   := 'VENDOR';

            BEGIN
                SELECT *
                  INTO l_shipment_line_rec
                  FROM apps.rcv_shipment_lines
                 WHERE shipment_line_id = p_source_line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate shipment line ('
                        || p_source_line_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;

            BEGIN
                SELECT *
                  INTO l_shipment_header_rec
                  FROM apps.rcv_shipment_headers
                 WHERE shipment_header_id =
                       l_shipment_line_rec.shipment_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate shipment header ('
                        || l_shipment_line_rec.shipment_header_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;

            BEGIN
                IF l_shipment_line_rec.po_distribution_id IS NOT NULL
                THEN
                    SELECT *
                      INTO l_po_distribution_rec
                      FROM apps.po_distributions_all
                     WHERE po_distribution_id =
                           l_shipment_line_rec.po_distribution_id;
                ELSE
                    SELECT *
                      INTO l_po_distribution_rec
                      FROM apps.po_distributions_all pda
                     WHERE pda.line_location_id =
                           l_shipment_line_rec.po_line_location_id;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate PO distribution ('
                        || NVL (l_shipment_line_rec.po_distribution_id,
                                l_shipment_line_rec.po_line_location_id)
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;

            BEGIN
                SELECT *
                  INTO l_po_line_location_rec
                  FROM apps.po_line_locations_all
                 WHERE line_location_id =
                       l_po_distribution_rec.line_location_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate PO line location ('
                        || l_po_distribution_rec.line_location_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;

            BEGIN
                SELECT *
                  INTO l_po_line_rec
                  FROM apps.po_lines_all
                 WHERE po_line_id = l_po_distribution_rec.po_line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate PO line ('
                        || l_po_distribution_rec.po_line_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;

            BEGIN
                SELECT *
                  INTO l_po_header_rec
                  FROM apps.po_headers_all
                 WHERE po_header_id = l_po_distribution_rec.po_header_id;

                l_org_id   := l_po_header_rec.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate PO header ('
                        || l_po_distribution_rec.po_header_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;
        ELSIF p_source_document_code = 'RMA'
        THEN
            l_receipt_source_code   := 'CUSTOMER';

            BEGIN
                SELECT *
                  INTO l_order_line_rec
                  FROM apps.oe_order_lines_all
                 WHERE line_id = p_source_line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate order line ('
                        || p_source_line_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;

            BEGIN
                SELECT *
                  INTO l_order_header_rec
                  FROM apps.oe_order_headers_all
                 WHERE header_id = l_order_line_rec.header_id;

                l_org_id   := l_order_header_rec.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate order header ('
                        || l_order_line_rec.header_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;
        ELSIF p_source_document_code = 'REQ'
        THEN
            l_receipt_source_code   := 'INTERNAL ORDER';

            BEGIN
                SELECT *
                  INTO l_shipment_line_rec
                  FROM apps.rcv_shipment_lines
                 WHERE shipment_line_id = p_source_line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate shipment line ('
                        || p_source_line_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;

            BEGIN
                SELECT *
                  INTO l_shipment_header_rec
                  FROM apps.rcv_shipment_headers
                 WHERE shipment_header_id =
                       l_shipment_line_rec.shipment_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate shipment header ('
                        || l_shipment_line_rec.shipment_header_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;

            BEGIN
                SELECT *
                  INTO l_req_line_rec
                  FROM apps.po_requisition_lines_all
                 WHERE requisition_line_id =
                       l_shipment_line_rec.requisition_line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate requisition line ('
                        || l_shipment_line_rec.requisition_line_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;

            BEGIN
                SELECT *
                  INTO l_req_header_rec
                  FROM apps.po_requisition_headers_all
                 WHERE requisition_header_id =
                       l_req_line_rec.requisition_header_id;

                l_org_id   := l_req_header_rec.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate requisition header ('
                        || l_req_line_rec.requisition_header_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;
        ELSIF p_source_document_code = 'INVENTORY'
        THEN
            l_receipt_source_code   := 'INVENTORY';

            BEGIN
                SELECT *
                  INTO l_shipment_line_rec
                  FROM apps.rcv_shipment_lines
                 WHERE shipment_line_id = p_source_line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate shipment line ('
                        || p_source_line_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;

            BEGIN
                SELECT *
                  INTO l_shipment_header_rec
                  FROM apps.rcv_shipment_headers
                 WHERE shipment_header_id =
                       l_shipment_line_rec.shipment_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to locate shipment header ('
                        || l_shipment_line_rec.shipment_header_id
                        || ') '
                        || SQLERRM;
                    m_msg (x_message);
                    RETURN;
            END;
        ELSE
            x_ret_stat   := g_ret_error;
            x_message    :=
                   'Receipt Source Code ('
                || l_receipt_source_code
                || ') not supported';
            m_msg (x_message);
            RETURN;
        END IF;

        SELECT MAX (header_interface_id)
          INTO l_header_interface_id
          FROM apps.rcv_headers_interface
         WHERE     last_update_login = USERENV ('SESSIONID')
               AND receipt_source_code = l_receipt_source_code
               AND NVL (shipment_num, 'NoShipMentXXX') =
                   NVL (
                       NVL (l_shipment_header_rec.shipment_num,
                            l_order_header_rec.order_number),
                       NVL (shipment_num, 'NoShipMentXXX'))
               AND processing_status_code = 'PENDING';

        IF p_source_document_code = 'PO'
        THEN
            l_vendor_id   := l_shipment_header_rec.vendor_id;
        ELSE
            l_vendor_id   := NULL;
        END IF;

        IF l_header_interface_id IS NULL
        THEN
            rcv_headers_insert (
                p_receipt_source_code   => l_receipt_source_code,
                p_shipment_num          =>
                    NVL (l_shipment_header_rec.shipment_num,
                         l_order_header_rec.order_number),
                p_receipt_date          => p_receipt_date,
                p_organization_id       => l_organization_id,
                x_ret_stat              => x_ret_stat,
                x_message               => x_message,
                p_customer_id           => l_order_header_rec.sold_to_org_id,
                p_vendor_id             => l_vendor_id);

            IF x_ret_stat != g_ret_success
            THEN
                m_msg (x_message);
                RETURN;
            END IF;

            SELECT MAX (header_interface_id)
              INTO l_header_interface_id
              FROM apps.rcv_headers_interface
             WHERE     last_update_login = USERENV ('SESSIONID')
                   AND receipt_source_code = l_receipt_source_code
                   AND NVL (shipment_num, 'NoShipMentXXX') =
                       NVL (
                           NVL (l_shipment_header_rec.shipment_num,
                                l_order_header_rec.order_number),
                           NVL (shipment_num, 'NoShipMentXXX'));

            IF l_header_interface_id IS NULL
            THEN
                x_ret_stat   := g_ret_error;
                m_msg (x_message);
                x_message    := 'Unable to generate a header_interface_id';
                m_msg (x_message);
                RETURN;
            END IF;
        END IF;

        BEGIN
            SELECT GROUP_ID
              INTO l_group_id
              FROM apps.rcv_headers_interface
             WHERE header_interface_id = l_header_interface_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_stat   := g_ret_error;
                x_message    :=
                       'Unable to locate group for header ('
                    || l_header_interface_id
                    || ') '
                    || SQLERRM;
                m_msg (x_message);
                RETURN;
        END;

        l_item_id   :=
            NVL (l_order_line_rec.inventory_item_id,
                 l_shipment_line_rec.item_id);
        rcv_lines_insert (
            p_org_id                   => l_org_id,
            p_receipt_source_code      => l_receipt_source_code,
            p_source_document_code     => p_source_document_code,
            p_group_id                 => l_group_id,
            p_location_id              => l_location_id,
            p_subinventory             =>
                NVL (p_subinventory, l_shipment_line_rec.to_subinventory),
            p_header_interface_id      => l_header_interface_id,
            p_shipment_num             => l_shipment_header_rec.shipment_num,
            p_receipt_date             => p_receipt_date,
            p_item_id                  => l_item_id,
            p_uom                      => l_uom,
            p_quantity                 => p_quantity,
            x_ret_stat                 => x_ret_stat,
            x_message                  => x_message,
            p_shipment_header_id       =>
                l_shipment_header_rec.shipment_header_id,
            p_shipment_line_id         => l_shipment_line_rec.shipment_line_id,
            p_ship_to_location_id      =>
                l_shipment_line_rec.deliver_to_location_id,
            p_from_organization_id     =>
                l_shipment_line_rec.from_organization_id,
            p_to_organization_id       => l_shipment_line_rec.to_organization_id,
            p_requisition_line_id      =>
                l_shipment_line_rec.requisition_line_id,
            p_requisition_distribution_id   =>
                l_shipment_line_rec.req_distribution_id,
            p_deliver_to_person_id     =>
                l_shipment_line_rec.deliver_to_person_id,
            p_deliver_to_location_id   =>
                l_shipment_line_rec.deliver_to_location_id,
            p_oe_order_header_id       => l_order_header_rec.header_id,
            p_oe_order_line_id         => l_order_line_rec.line_id,
            p_customer_id              => l_order_header_rec.sold_to_org_id,
            p_customer_site_id         => l_order_line_rec.ship_to_org_id,
            p_vendor_id                => l_vendor_id,
            p_parent_transaction_id    => p_parent_transaction_id,
            p_duty_paid_flag           => p_duty_paid_flag,
            --Added as per ver 1.1
            p_carton_code              => p_carton_code,
            p_receipt_type             => p_receipt_type--Added for change 1.10
                                                        );
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_error;
            x_message    := SQLERRM;
    END;

    --Start Added for CCR0009513
    --To get remaining Receive-Qty post validate of RCV and RTI
    FUNCTION get_rcv_rti_qty (p_shipment_line_id   IN NUMBER,
                              p_inv_item_id        IN NUMBER DEFAULT NULL)
        RETURN NUMBER
    IS
        ln_rcv_rti_qty   NUMBER := 0;
    BEGIN
        SELECT (  NVL (
                      (SELECT SUM (quantity)
                         FROM apps.rcv_transactions rt
                        WHERE     rt.shipment_line_id = rsl.shipment_line_id
                              AND rt.transaction_type = 'RECEIVE'),
                      0)
                + NVL (
                      (SELECT SUM (quantity)
                         FROM rcv_transactions_interface
                        WHERE     shipment_line_id = rsl.shipment_line_id
                              AND transaction_type = 'RECEIVE'
                              AND processing_status_code = 'PENDING'),
                      0)
                - NVL (
                      (SELECT SUM (quantity)
                         FROM apps.rcv_transactions rt
                        WHERE     rt.shipment_line_id = rsl.shipment_line_id
                              AND rt.transaction_type = 'DELIVER'),
                      0)
                - NVL (
                      (SELECT SUM (quantity)
                         FROM rcv_transactions_interface
                        WHERE     shipment_line_id = rsl.shipment_line_id
                              AND transaction_type = 'DELIVER'
                              AND processing_status_code = 'PENDING'),
                      0)) line_qty
          INTO ln_rcv_rti_qty
          FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh
         WHERE     rsl.shipment_header_id = rsh.shipment_header_id
               AND rsl.item_id = NVL (p_inv_item_id, rsl.item_id)
               AND rsl.shipment_line_id = p_shipment_line_id;

        RETURN ln_rcv_rti_qty;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_rcv_rti_qty   := 0;
            RETURN ln_rcv_rti_qty;
    END;

    --To get ParentTrxID and Qty
    --It validate all possible cases(Match\UN-Match\Split)
    FUNCTION get_parenttrxid_qty (p_shipment_line_id IN NUMBER, p_inv_item_id IN NUMBER, p_qty_deliver IN NUMBER
                                  , p_type IN VARCHAR2 --QUANTITY \ PARENT_TRANS_ID
                                                      )
        RETURN NUMBER
    IS
        ln_qty_deliver         NUMBER := p_qty_deliver;
        ln_curr_qty_deliver    NUMBER := 0;
        ln_rcv_match_qty       NUMBER := 0;
        ln_max_rcv_qty         NUMBER := 0;
        ln_parent_trans_id     NUMBER := NULL;
        ln_rcv_trans_id        NUMBER := NULL;
        ln_min_trans_id        NUMBER := NULL;
        ln_max_parent_trx_id   NUMBER := NULL;
        ln_min_rcv_qty         NUMBER := NULL;
        ln_least_max_rcv_qty   NUMBER := NULL;
        ln_deliver_cnt         NUMBER := 0;
        ln_int_trx_id          NUMBER := NULL;
        ln_int_trx_qty         NUMBER := 0;
    BEGIN
        FOR qty_rec
            IN (SELECT parent_trans_id, qty_receive
                  FROM (  SELECT rt.transaction_id parent_trans_id, rt.quantity qty_receive1, get_remaining_deliver_qty (p_shipment_line_id => p_shipment_line_id, p_parent_trx_id => rt.transaction_id, p_qty_deliver => rt.quantity) qty_receive
                            FROM apps.rcv_transactions rt, apps.rcv_shipment_lines rsl
                           WHERE     1 = 1
                                 AND rt.shipment_header_id =
                                     rsl.shipment_header_id
                                 AND rt.shipment_line_id = rsl.shipment_line_id
                                 AND rt.shipment_line_id = p_shipment_line_id
                                 AND rsl.item_id = p_inv_item_id
                                 AND rt.transaction_type = 'RECEIVE'
                                 AND NOT EXISTS
                                         (SELECT 1
                                            FROM apps.rcv_transactions rt1
                                           WHERE     rt.shipment_header_id =
                                                     rsl.shipment_header_id
                                                 AND rt.shipment_line_id =
                                                     rsl.shipment_line_id
                                                 AND rt1.parent_transaction_id =
                                                     rt.transaction_id
                                                 AND NVL (rt1.quantity, 0) >=
                                                     NVL (rt.quantity, 0)
                                                 AND rt1.transaction_type =
                                                     'DELIVER')
                                 AND NOT EXISTS
                                         (SELECT 1
                                            FROM apps.rcv_transactions_interface rti
                                           WHERE     rti.shipment_header_id =
                                                     rsl.shipment_header_id
                                                 AND rti.shipment_line_id =
                                                     rsl.shipment_line_id
                                                 AND rti.parent_transaction_id =
                                                     rt.transaction_id
                                                 AND NVL (rti.quantity, 0) >=
                                                     NVL (rt.quantity, 0)
                                                 AND rti.processing_status_code =
                                                     'PENDING'
                                                 AND rti.transaction_type =
                                                     'DELIVER')
                        ORDER BY rt.transaction_id)
                 WHERE NVL (qty_receive, 0) > 0)
        LOOP
            --EQUAL Quantity Check
            --Validate DeliverQty Equal with ReceiveQty
            BEGIN
                  SELECT MIN (rt.transaction_id), --rt.quantity,
                                                  get_remaining_deliver_qty (p_shipment_line_id => p_shipment_line_id, p_parent_trx_id => rt.transaction_id, p_qty_deliver => rt.quantity) rcv_match_qty
                    INTO ln_parent_trans_id, ln_rcv_match_qty
                    FROM apps.rcv_transactions rt, apps.rcv_shipment_lines rsl
                   WHERE     1 = 1
                         AND rt.shipment_header_id = rsl.shipment_header_id
                         AND rt.shipment_line_id = rsl.shipment_line_id
                         AND rt.shipment_line_id = p_shipment_line_id
                         AND rsl.item_id = p_inv_item_id
                         --AND rt.quantity = p_qty_deliver
                         AND get_remaining_deliver_qty (
                                 p_shipment_line_id   => p_shipment_line_id,
                                 p_parent_trx_id      => rt.transaction_id,
                                 p_qty_deliver        => rt.quantity) =
                             NVL (p_qty_deliver, qty_rec.qty_receive)
                         AND NOT EXISTS
                                 (SELECT 1
                                    FROM apps.rcv_transactions rt1
                                   WHERE     NVL (rt1.parent_transaction_id,
                                                  -1) =
                                             rt.transaction_id
                                         AND NVL (rt1.quantity, 0) =
                                             NVL (rt.quantity, 0)
                                         AND rt1.transaction_type = 'DELIVER')
                         AND NOT EXISTS
                                 (SELECT 1
                                    FROM rcv_transactions_interface rti
                                   WHERE     NVL (rti.parent_transaction_id,
                                                  -1) =
                                             rt.transaction_id
                                         AND rti.processing_status_code =
                                             'PENDING'
                                         AND NVL (rti.quantity, 0) =
                                             NVL (rt.quantity, 0)
                                         AND rti.transaction_type = 'DELIVER')
                         AND rt.transaction_type = 'RECEIVE'
                GROUP BY --rt.quantity,
                         get_remaining_deliver_qty (p_shipment_line_id => p_shipment_line_id, p_parent_trx_id => rt.transaction_id, p_qty_deliver => rt.quantity);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_parent_trans_id   := NULL;
                    ln_rcv_match_qty     := 0;
            END;

            --dbms_output.put_line (' p_qty_deliver  :'||p_qty_deliver);
            --dbms_output.put_line (' qty_rec.qty_receive  :'||qty_rec.qty_receive);

            IF (NVL (p_qty_deliver, 0) = NVL (ln_rcv_match_qty, 0) --DIRECT MATCH QTY
                                                                   AND (NVL (ln_rcv_match_qty, 0) <> 0))
            THEN
                ln_curr_qty_deliver   := ln_rcv_match_qty;
                ln_parent_trans_id    := ln_parent_trans_id;
                --dbms_output.put_line (' DIRECT MATCH QTY :'||ln_curr_qty_deliver);
                EXIT;
            ELSE                                                 --UNMATCH QTY
                --Get MAX Receive-QTY
                IF NVL (ln_rcv_match_qty, 0) = 0
                THEN
                    BEGIN
                        SELECT MAX (rt.quantity)
                          INTO ln_max_rcv_qty
                          FROM apps.rcv_transactions rt, apps.rcv_shipment_lines rsl
                         WHERE     1 = 1
                               AND rt.shipment_header_id =
                                   rsl.shipment_header_id
                               AND rt.shipment_line_id = rsl.shipment_line_id
                               AND rt.shipment_line_id = p_shipment_line_id
                               AND rsl.item_id = p_inv_item_id
                               --Get MAX Qty Line
                               AND rt.quantity >=
                                   (SELECT NVL (MAX (rt1.quantity), 0)
                                      FROM apps.rcv_transactions rt1
                                     WHERE     rt1.shipment_header_id =
                                               rt.shipment_header_id
                                           AND rt1.shipment_line_id =
                                               rt.shipment_line_id
                                           AND rt1.transaction_type =
                                               'RECEIVE')
                               --Exclude MATCH Qty Line
                               AND rt.quantity <>
                                   (SELECT NVL (MAX (rt1.quantity), 0)
                                      FROM apps.rcv_transactions rt1, xxdo.xxdo_wms_3pl_grn_l grnl
                                     WHERE     rt1.shipment_line_id =
                                               grnl.source_line_id
                                           AND rt1.quantity =
                                               grnl.quantity_to_receive
                                           AND rt1.shipment_header_id =
                                               rt.shipment_header_id
                                           AND rt1.shipment_line_id =
                                               rt.shipment_line_id
                                           AND rt1.transaction_type =
                                               'RECEIVE'
                                           AND grnl.process_status IN
                                                   ('P', 'S')
                                           AND grnl.receipt_type = 'DELIVER'
                                           AND grnl.processing_session_id =
                                               USERENV ('SESSIONID')
                                           AND TRUNC (grnl.last_update_date) =
                                               TRUNC (SYSDATE))
                               AND rt.transaction_type = 'RECEIVE';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_max_rcv_qty   := 0;
                    END;

                    --Get Parent TrxID for MAX Qty
                    BEGIN
                        SELECT MAX (rt.transaction_id)
                          INTO ln_max_parent_trx_id
                          FROM apps.rcv_transactions rt, apps.rcv_shipment_lines rsl
                         WHERE     1 = 1
                               AND rt.shipment_header_id =
                                   rsl.shipment_header_id
                               AND rt.shipment_line_id = rsl.shipment_line_id
                               AND rt.shipment_line_id = p_shipment_line_id
                               AND rsl.item_id = p_inv_item_id
                               AND rt.quantity = ln_max_rcv_qty
                               AND rt.transaction_type = 'RECEIVE';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_max_parent_trx_id   := NULL;
                    END;
                END IF;

                --dbms_output.put_line (' UN-MATCH QTY :'||ln_max_rcv_qty);

                --UN-EQUAL Quantity Check
                --Validate Max-Receive QTY un-equal with Receive-QTY
                --If Deliver-QTY greater than Max-Receive QTY then get Base Receive-QTY
                IF ((NVL (ln_max_rcv_qty, 0) <> NVL (qty_rec.qty_receive, 0)) AND (NVL (ln_qty_deliver, 0) > NVL (ln_max_rcv_qty, 0)))
                THEN
                    ln_max_rcv_qty   := qty_rec.qty_receive;
                    ln_parent_trans_id   :=
                        NVL (qty_rec.parent_trans_id, ln_max_parent_trx_id);
                --dbms_output.put_line (' Max-Receive QTY un-equal with Receive-QTY: '||ln_max_rcv_qty);
                END IF;

                ln_qty_deliver   := p_qty_deliver;

                --Validate Max-ReceiveQty Equal with DeliverQty
                IF ln_qty_deliver = ln_max_rcv_qty       --Both Quantity Equal
                THEN
                    ln_curr_qty_deliver   := ln_max_rcv_qty;
                    ln_parent_trans_id    := ln_max_parent_trx_id;
                    --dbms_output.put_line (' Max-ReceiveQty Equal with DeliverQty : '||ln_curr_qty_deliver);
                    EXIT;
                ELSIF ln_qty_deliver < ln_max_rcv_qty --Deliver Qty < Receive Qty
                THEN
                    IF NVL (ln_curr_qty_deliver, 0) <= ln_max_rcv_qty
                    THEN
                        ln_curr_qty_deliver   := ln_qty_deliver;

                        --Get Parent TrxID for LEAST-MAX ReceiveQty
                        ln_parent_trans_id    :=
                            get_least_max_trx_id (
                                p_shipment_line_id   => p_shipment_line_id,
                                p_qty_deliver        => ln_curr_qty_deliver,
                                p_inv_item_id        => p_inv_item_id);
                    --dbms_output.put_line (' Deliver Qty < Receive Qty for LEAST-MAX ReceiveQty :'||ln_curr_qty_deliver);
                    ELSIF NVL (ln_curr_qty_deliver, 0) > ln_max_rcv_qty
                    THEN
                        ln_curr_qty_deliver   := qty_rec.qty_receive;
                        ln_parent_trans_id    := qty_rec.parent_trans_id;
                    --dbms_output.put_line (' nvl(ln_curr_qty_deliver,0) > ln_max_rcv_qty :'||ln_curr_qty_deliver);
                    END IF;

                    EXIT;
                ELSE                  --Deliver Qty > Receive Qty (SPLIT Case)
                    IF ((NVL (ln_qty_deliver, 0) - NVL (ln_max_rcv_qty, 0)) <= NVL (ln_max_rcv_qty, 0))
                    THEN
                        ln_curr_qty_deliver   :=
                            ln_qty_deliver - ln_max_rcv_qty;

                        --Get Parent TrxID for LEAST-MAX ReceiveQty
                        ln_parent_trans_id   :=
                            get_least_max_trx_id (
                                p_shipment_line_id   => p_shipment_line_id,
                                p_qty_deliver        => ln_curr_qty_deliver,
                                p_inv_item_id        => p_inv_item_id);
                        --dbms_output.put_line (' SPLIT Case - ln_qty_deliver - ln_max_rcv_qty :'||ln_curr_qty_deliver);
                        EXIT;
                    ELSE
                        BEGIN
                            --Get MIN Receive QTY
                            SELECT MIN (min_rcv_qty)
                              INTO ln_min_rcv_qty
                              FROM (SELECT --MIN(rt.quantity),
                                           get_remaining_deliver_qty (p_shipment_line_id => p_shipment_line_id, p_parent_trx_id => rt.transaction_id, p_qty_deliver => rt.quantity) min_rcv_qty
                                      FROM apps.rcv_transactions rt, apps.rcv_shipment_lines rsl
                                     WHERE     1 = 1
                                           AND rt.shipment_header_id =
                                               rsl.shipment_header_id
                                           AND rt.shipment_line_id =
                                               rsl.shipment_line_id
                                           AND rt.shipment_line_id =
                                               p_shipment_line_id
                                           AND rsl.item_id = p_inv_item_id
                                           AND rt.quantity <>
                                               (SELECT NVL (MIN (rt1.quantity), 0)
                                                  FROM apps.rcv_transactions rt1, xxdo.xxdo_wms_3pl_grn_l grnl
                                                 WHERE     rt1.shipment_line_id =
                                                           grnl.source_line_id
                                                       AND rt1.quantity =
                                                           grnl.quantity_to_receive
                                                       AND rt1.shipment_header_id =
                                                           rt.shipment_header_id
                                                       AND rt1.shipment_line_id =
                                                           rt.shipment_line_id
                                                       AND rt1.transaction_type =
                                                           'RECEIVE'
                                                       AND grnl.receipt_type =
                                                           'DELIVER'
                                                       AND grnl.processing_session_id =
                                                           USERENV (
                                                               'SESSIONID')
                                                       AND TRUNC (
                                                               grnl.last_update_date) =
                                                           TRUNC (SYSDATE))
                                           AND rt.transaction_type =
                                               'RECEIVE')
                             WHERE NVL (min_rcv_qty, 0) > 0;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_min_rcv_qty   := 0;
                        END;

                        --Get Parent TrxID for MIN-Receive Qty
                        IF NVL (ln_min_rcv_qty, 0) > 0
                        THEN
                            BEGIN
                                SELECT MIN (rt.transaction_id)
                                  INTO ln_min_trans_id
                                  FROM apps.rcv_transactions rt, apps.rcv_shipment_lines rsl
                                 WHERE     1 = 1
                                       AND rt.shipment_header_id =
                                           rsl.shipment_header_id
                                       AND rt.shipment_line_id =
                                           rsl.shipment_line_id
                                       AND rt.shipment_line_id =
                                           p_shipment_line_id
                                       AND rsl.item_id = p_inv_item_id
                                       AND rt.quantity = ln_min_rcv_qty
                                       AND rt.transaction_type = 'RECEIVE';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_min_trans_id   := NULL;
                            END;
                        END IF;

                        IF ((NVL (ln_qty_deliver, 0) - NVL (ln_min_rcv_qty, 0)) <= NVL (qty_rec.qty_receive, 0))
                        THEN
                            ln_curr_qty_deliver   :=
                                  NVL (ln_qty_deliver, 0)
                                - NVL (ln_min_rcv_qty, 0);
                            ln_parent_trans_id   :=
                                NVL (qty_rec.parent_trans_id,
                                     ln_min_trans_id);
                            DBMS_OUTPUT.put_line (
                                   ' ELSE SPLIT Case1 - -ln_min_trans_id and qty :'
                                || ln_curr_qty_deliver);
                        ELSE
                            ln_curr_qty_deliver   :=
                                  NVL (ln_qty_deliver, 0)
                                - NVL (ln_min_rcv_qty, 0);

                            --ln_parent_trans_id  := nvl(ln_parent_trans_id, qty_rec.parent_trans_id);

                            --Get Parent TrxID for MAX ReceiveQty
                            BEGIN
                                SELECT MAX (rt.transaction_id)
                                  INTO ln_parent_trans_id
                                  FROM apps.rcv_transactions rt, apps.rcv_shipment_lines rsl
                                 WHERE     1 = 1
                                       AND rt.shipment_header_id =
                                           rsl.shipment_header_id
                                       AND rt.shipment_line_id =
                                           rsl.shipment_line_id
                                       AND rt.shipment_line_id =
                                           p_shipment_line_id
                                       AND rsl.item_id = p_inv_item_id
                                       AND rt.quantity >= ln_curr_qty_deliver
                                       AND rt.transaction_type = 'RECEIVE'
                                       AND rt.transaction_id <>
                                           (SELECT NVL (MAX (parent_transaction_id), -1)
                                              FROM rcv_transactions_interface rti
                                             WHERE     1 = 1
                                                   AND shipment_line_id =
                                                       p_shipment_line_id
                                                   AND item_id =
                                                       p_inv_item_id
                                                   AND transaction_type =
                                                       'DELIVER'
                                                   AND quantity >=
                                                       ln_curr_qty_deliver);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_parent_trans_id   := NULL;
                            END;
                        --dbms_output.put_line (' ELSE SPLIT Case2- ln_min_trans_id and qty :'||ln_curr_qty_deliver);
                        END IF;

                        EXIT;
                    END IF;

                    EXIT;
                END IF;
            END IF;       --IF nvl(ln_qty_deliver,0) = nvl(ln_rcv_match_qty,0)
        END LOOP;

        IF p_type = 'QUANTITY'                                      --QUANTITY
        THEN
            IF NVL (ln_curr_qty_deliver, 0) = 0
            THEN
                RETURN 0;
            ELSE
                RETURN ln_curr_qty_deliver;
            END IF;
        ELSE                                                 --PARENT_TRANS_ID
            IF NVL (ln_curr_qty_deliver, 0) = 0
            THEN
                RETURN NULL;
            ELSE
                RETURN ln_parent_trans_id;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --Get Remaining Deliver Quantity for Parent TrxID
    --Reduce Deliver Quantity if exists for TrxID
    FUNCTION get_remaining_deliver_qty (p_shipment_line_id IN NUMBER, p_parent_trx_id IN NUMBER, p_qty_deliver IN NUMBER)
        RETURN NUMBER
    IS
        ln_remaining_deliver_qty   NUMBER := 0;
    BEGIN
        SELECT NVL (
                   (  p_qty_deliver
                    - (  NVL (
                             (  SELECT SUM (quantity)
                                  FROM apps.rcv_transactions rt
                                 WHERE     rt.shipment_line_id =
                                           p_shipment_line_id
                                       AND rt.parent_transaction_id =
                                           p_parent_trx_id
                                       AND rt.transaction_type = 'DELIVER'
                              GROUP BY rt.parent_transaction_id),
                             0)
                       + NVL (
                             (  SELECT SUM (quantity)
                                  FROM apps.rcv_transactions_interface rti
                                 WHERE     rti.shipment_line_id =
                                           p_shipment_line_id
                                       AND rti.parent_transaction_id =
                                           p_parent_trx_id
                                       AND rti.transaction_type = 'DELIVER'
                                       AND rti.processing_status_code =
                                           'PENDING'
                              GROUP BY rti.parent_transaction_id),
                             0))),
                   p_qty_deliver) ln_remaining_deliver_qty
          INTO ln_remaining_deliver_qty
          FROM DUAL;

        RETURN ln_remaining_deliver_qty;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --Get Parent TrxID for LEAST-MAX ReceiveQty
    FUNCTION get_least_max_trx_id (p_shipment_line_id IN NUMBER, p_qty_deliver IN NUMBER, p_inv_item_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_least_max_rcv_qty       NUMBER := 0;
        ln_least_max_rcv_del_qty   NUMBER := 0;
        ln_least_max_qty           NUMBER := 0;
        ln_parent_trans_id         NUMBER := 0;
    BEGIN
        BEGIN
            SELECT MIN (rt.quantity) least_max_rcv_qty, MIN (get_remaining_deliver_qty (p_shipment_line_id => p_shipment_line_id, p_parent_trx_id => rt.transaction_id, p_qty_deliver => rt.quantity)) least_max_rcv_del_qty
              INTO ln_least_max_rcv_qty, ln_least_max_rcv_del_qty
              FROM apps.rcv_transactions rt, apps.rcv_shipment_lines rsl
             WHERE     1 = 1
                   AND rt.shipment_header_id = rsl.shipment_header_id
                   AND rt.shipment_line_id = rsl.shipment_line_id
                   AND rt.shipment_line_id = p_shipment_line_id
                   AND rsl.item_id = p_inv_item_id
                   --AND rt.quantity >= p_qty_deliver
                   AND get_remaining_deliver_qty (
                           p_shipment_line_id   => p_shipment_line_id,
                           p_parent_trx_id      => rt.transaction_id,
                           p_qty_deliver        => rt.quantity) >=
                       p_qty_deliver
                   AND rt.transaction_type = 'RECEIVE';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_least_max_rcv_qty       := NULL;
                ln_least_max_rcv_del_qty   := NULL;
        END;

        IF NVL (ln_least_max_rcv_qty, 0) = NVL (ln_least_max_rcv_del_qty, 0)
        THEN
            ln_least_max_qty   := ln_least_max_rcv_del_qty;
        ELSE
            ln_least_max_qty   := ln_least_max_rcv_qty;
        END IF;

        BEGIN
            SELECT MIN (rt.transaction_id)
              INTO ln_parent_trans_id
              FROM apps.rcv_transactions rt, apps.rcv_shipment_lines rsl
             WHERE     1 = 1
                   AND rt.shipment_header_id = rsl.shipment_header_id
                   AND rt.shipment_line_id = rsl.shipment_line_id
                   AND rt.shipment_line_id = p_shipment_line_id
                   AND rsl.item_id = p_inv_item_id
                   AND rt.quantity = ln_least_max_qty
                   AND rt.transaction_type = 'RECEIVE';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_parent_trans_id   := NULL;
        END;

        RETURN ln_parent_trans_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    PROCEDURE update_asn_status (p_organization_id NUMBER, x_ret_stat OUT VARCHAR2, x_message OUT VARCHAR2
                                 , p_source_document_code VARCHAR2:= NULL, p_source_header_id NUMBER:= NULL, p_asn_status VARCHAR2:= NULL)
    IS
        l_asn_status       VARCHAR2 (10);
        l_pa_grp_enabled   apps.mtl_parameters.attribute11%TYPE;
        l_carton_flag      VARCHAR2 (1);
    BEGIN
        l_asn_status   := NVL (p_asn_status, USERENV ('SESSIONID'));

        SELECT NVL (attribute11, '0') AS pa_grouping_enabled
          INTO l_pa_grp_enabled
          FROM apps.mtl_parameters
         WHERE organization_id = p_organization_id;

        IF l_pa_grp_enabled != '1'
        THEN
            -- Manual pre-advice grouping is not enabled for the current inventory organization.  Set grouping attribute automatically. --
            UPDATE rcv_shipment_headers
               SET attribute2   = TO_CHAR (shipment_header_id)
             WHERE     ship_to_org_id = p_organization_id
                   AND attribute2 IS NULL
                   AND receipt_source_code IN ('INTERNAL ORDER', 'VENDOR');
        END IF;

        FOR rec
            IN (SELECT *
                  FROM xxdo.xxdo_edi_3pl_preadvice_h_v
                 WHERE     organization_id = p_organization_id
                       AND source_document_code =
                           NVL (p_source_document_code, source_document_code)
                       AND source_header_id =
                           NVL (p_source_header_id, source_header_id)
                       AND NVL (asn_status, TO_CHAR (USERENV ('SESSIONID'))) IN
                               (l_grn_pending, TO_CHAR (USERENV ('SESSIONID')), l_grn_complete))
        LOOP
            IF rec.source_document_code IN ('INVENTORY', 'REQ', 'PO')
            THEN
                SELECT DISTINCT
                       CASE xxdo_wms_carton_utils.check_asn_cartons (
                                rec.source_header_id)
                           WHEN 1
                           THEN
                               'Y'
                           WHEN 0
                           THEN
                               'N'
                           ELSE
                               --This will be -1 returned from the function
                               'E'
                       END
                  INTO l_carton_flag
                  FROM rcv_shipment_headers
                 WHERE     TO_NUMBER (attribute2) = rec.source_header_id
                       AND receipt_source_code = rec.receipt_source_code
                       AND ship_to_org_id = p_organization_id;

                --'E' is returned if there are multiple ASNs in the GRN and they are not homegenous with respect to cartons
                IF l_carton_flag = 'E'
                THEN
                    --we have an invalid state. Set all ASNs to ERROR
                    UPDATE rcv_shipment_headers
                       SET asn_status   = 'ERR - GRP'
                     WHERE     TO_NUMBER (attribute2) = rec.source_header_id
                           AND receipt_source_code = rec.receipt_source_code
                           AND ship_to_org_id = p_organization_id;
                ELSE                                      --Update carton flag
                    UPDATE rcv_shipment_headers
                       SET asn_status = l_asn_status, attribute4 = l_carton_flag
                     WHERE     TO_NUMBER (attribute2) = rec.source_header_id
                           AND receipt_source_code = rec.receipt_source_code
                           AND ship_to_org_id = p_organization_id;
                END IF;
            ELSIF rec.source_document_code = 'RMA'
            THEN
                UPDATE oe_order_headers_all ooha
                   SET user_status_code   = l_asn_status
                 WHERE     header_id = rec.source_header_id
                       -- Start modification by BT Team in consultation with Brian Burns on 5-29-2015
                       --               AND ooha.order_category_code = 'RETURN';
                       AND ooha.order_category_code IN ('RETURN', 'MIXED');
            -- End modification by BT Team in consultation with Brian Burns on 5-29-2015
            END IF;
        END LOOP;

        x_ret_stat     := g_ret_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_error;
            x_message    := SQLERRM;
    END;

    PROCEDURE update_ats_status (p_organization_id        NUMBER,
                                 x_ret_stat           OUT VARCHAR2,
                                 x_message            OUT VARCHAR2,
                                 p_source_header_id       NUMBER := NULL,
                                 p_asn_status             VARCHAR2 := NULL)
    IS
        l_asn_status               VARCHAR2 (10);
        n_bonded_value             NUMBER;
        n_count                    NUMBER;
        n_free_circulation_value   NUMBER;
        n_dest_org                 NUMBER;
        n_item_cost                NUMBER;
        n_inventory_item_id        NUMBER;
        n_conversion_rate          NUMBER;
    BEGIN
        l_asn_status   := NVL (p_asn_status, USERENV ('SESSIONID'));

        FOR rec
            IN (SELECT *
                  FROM xxdo.xxdo_edi_3pl_ats_headers_v
                 WHERE     organization_id = p_organization_id
                       AND order_id = NVL (p_source_header_id, order_id)
                       AND NVL (asn_status_code,
                                TO_CHAR (USERENV ('SESSIONID'))) =
                           TO_CHAR (USERENV ('SESSIONID')))
        LOOP
            UPDATE wsh_new_deliveries
               SET attribute4   = l_asn_status
             WHERE delivery_id = rec.order_id;

            --Begin 1.9
            SELECT COUNT (*)
              INTO n_count
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     flv.lookup_type = 'XXD_WMS_3PL_ATS_COMINV_ORG_MAP'
                   AND flv.language = 'US'
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                            SYSDATE - 1)
                                   AND NVL (flv.end_date_active, SYSDATE + 1)
                   AND rec.organization_id = mp.organization_id
                   AND mp.organization_code = flv.meaning;

            IF n_count > 0
            THEN
                FOR line_rec
                    IN (SELECT *
                          FROM xxdo.xxdo_edi_3pl_ats_lines_v lv
                         WHERE lv.source_header_id = rec.source_header_id)
                LOOP
                    IF rec.customer_type = 'DC TRANSFER'
                    THEN
                        BEGIN
                            SELECT prla.org_id, oola.inventory_item_id
                              INTO n_dest_org, n_inventory_item_id
                              FROM po_requisition_lines_all prla, oe_order_lines_all oola
                             WHERE     prla.requisition_line_id =
                                       oola.source_document_line_id
                                   AND prla.item_id = oola.inventory_item_id
                                   AND oola.line_id = line_rec.source_line_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                n_dest_org   := rec.org_id;
                                n_inventory_item_id   :=
                                    apps.sku_to_iid (line_rec.sku);
                        END;

                        IF n_dest_org = rec.org_id
                        THEN
                            BEGIN
                                SELECT conversion_rate
                                  INTO n_conversion_rate
                                  FROM gl_daily_rates
                                 WHERE     from_currency = 'USD'
                                       AND to_currency = 'EUR'
                                       AND conversion_type = 'Corporate'
                                       AND conversion_date = TRUNC (SYSDATE);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    n_conversion_rate   := 1;
                            END;


                            n_item_cost   :=
                                  APPS.XXDOGET_ITEM_COST (
                                      pv_cost                => 'ITEMCOST',
                                      pn_organization_id     =>
                                          line_rec.organization_id,
                                      pn_inventory_item_id   =>
                                          n_inventory_item_id,
                                      pv_custom_cost         => 'N')
                                * n_conversion_rate;

                            n_item_cost   := NVL (ROUND (n_item_cost, 2), 0);

                            UPDATE wsh_delivery_details wdd
                               SET attribute4 = n_item_cost, attribute5 = n_item_cost
                             WHERE     wdd.source_line_id =
                                       line_rec.source_line_id
                                   AND source_code = 'OE'
                                   AND wdd.organization_id =
                                       line_rec.organization_id;
                        ELSE
                            n_free_circulation_value   :=
                                XXD_OM_INTERCO_PRICE_PKG.get_free_circulation_value (
                                    line_rec.source_line_id);


                            UPDATE wsh_delivery_details wdd
                               SET attribute4 = n_free_circulation_value, attribute5 = n_free_circulation_value
                             WHERE     wdd.source_line_id =
                                       line_rec.source_line_id
                                   AND source_code = 'OE'
                                   AND wdd.organization_id =
                                       line_rec.organization_id;
                        END IF;
                    ELSE
                        n_free_circulation_value   :=
                            XXD_OM_INTERCO_PRICE_PKG.get_free_circulation_value (
                                line_rec.source_line_id);

                        n_bonded_value   :=
                            XXD_OM_INTERCO_PRICE_PKG.get_bonded_value (
                                line_rec.source_line_id);

                        UPDATE wsh_delivery_details wdd
                           SET attribute4 = n_bonded_value, attribute5 = n_free_circulation_value
                         WHERE     wdd.source_line_id =
                                   line_rec.source_line_id
                               AND source_code = 'OE'
                               AND wdd.organization_id =
                                   line_rec.organization_id;
                    END IF;
                END LOOP;
            END IF;
        --End 1.9
        END LOOP;

        x_ret_stat     := g_ret_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_error;
            x_message    := SQLERRM;
    END;

    --BEGIN: Added for CCR0010325
    PROCEDURE get_shipment_line_id
    IS
        CURSOR c_grn_lines IS
              SELECT grnh.source_header_id, grnl.*
                FROM xxdo.xxdo_wms_3pl_grn_h grnh, xxdo.xxdo_wms_3pl_grn_l grnl, mtl_parameters mp
               WHERE     1 = 1
                     AND grnh.grn_header_id = grnl.grn_header_id
                     AND grnh.organization_id = mp.organization_id
                     AND grnl.receipt_type = 'DELIVER'
                     AND grnl.process_status = 'P'
                     AND grnl.source_line_id = -1
                     AND grnl.split IS NULL
            ORDER BY grnh.grn_header_id, grnl.sku_code, TO_NUMBER (grnl.qty_received);


        CURSOR c_rsl_lines (p_source_header_id NUMBER, p_sku_code VARCHAR2)
        IS
              SELECT shipment_line_id, transaction_id, qty_remaining
                FROM (SELECT rsl.shipment_line_id,
                             rt.transaction_id,
                             (  NVL (rt.quantity, 0)
                              - (  NVL (
                                       (SELECT SUM (quantity)
                                          FROM rcv_transactions
                                         WHERE     1 = 1
                                               AND shipment_line_id =
                                                   rsl.shipment_line_id
                                               AND parent_transaction_id =
                                                   rt.transaction_id
                                               AND transaction_type = 'DELIVER'),
                                       0)
                                 + NVL (
                                       (SELECT SUM (quantity)
                                          FROM rcv_transactions_interface
                                         WHERE     1 = 1
                                               AND shipment_line_id =
                                                   rsl.shipment_line_id
                                               AND parent_transaction_id =
                                                   rt.transaction_id  --230310
                                               AND transaction_type = 'DELIVER'
                                               AND processing_status_code =
                                                   'PENDING'),
                                       0)
                                 + NVL (
                                       (SELECT SUM (grnl.qty_received)
                                          FROM xxdo.xxdo_wms_3pl_grn_l grnl
                                         WHERE     1 = 1
                                               AND source_line_id =
                                                   rsl.shipment_line_id
                                               AND transaction_id =
                                                   rt.transaction_id
                                               AND receipt_type = 'DELIVER'
                                               AND process_status = 'P'),
                                       0))) qty_remaining
                        FROM apps.rcv_shipment_lines rsl,
                             apps.rcv_shipment_headers rsh,
                             apps.rcv_routing_headers rrh,
                             rcv_transactions rt,
                             (  SELECT source_line_id,
                                       destination_line_id,
                                       CASE rsh1.attribute4
                                           WHEN 'Y' THEN carton_number
                                           ELSE NULL
                                       END carton_number,
                                       SUM (quantity) quantity,
                                       SUM (quantity_received) quantity_received
                                  FROM xxdo.xxdo_wms_asn_cartons c1, apps.rcv_shipment_headers rsh1
                                 WHERE     status_flag = 'ACTIVE'
                                       AND c1.destination_header_id =
                                           rsh1.shipment_header_id
                              GROUP BY source_line_id,
                                       destination_line_id,
                                       CASE rsh1.attribute4
                                           WHEN 'Y' THEN carton_number
                                           ELSE NULL
                                       END) cart
                       WHERE     1 = 1
                             AND rsl.shipment_line_status_code IN
                                     ('FULLY RECEIVED', 'PARTIALLY RECEIVED', 'EXPECTED')
                             AND rsl.shipment_header_id =
                                 rsh.shipment_header_id
                             AND rsh.shipment_header_id = rt.shipment_header_id
                             AND rsl.shipment_line_id = rt.shipment_line_id
                             AND rt.transaction_type = 'RECEIVE'
                             AND rsl.shipment_line_id =
                                 cart.destination_line_id(+)
                             AND rsl.source_document_code IN ('PO', 'REQ')
                             AND TO_NUMBER (rsh.attribute2) =
                                 p_source_header_id
                             AND apps.iid_to_sku (rsl.item_id) = p_sku_code
                             AND rrh.routing_header_id = rsl.routing_header_id
                             AND rrh.routing_name = 'Standard Receipt') TBL
               WHERE 1 = 1 AND qty_remaining > 0
            ORDER BY (qty_remaining);

        l_qty_bal   NUMBER;
        l_err_msg   VARCHAR2 (240);
    BEGIN
        FOR grn_rec IN c_grn_lines
        LOOP
            FOR rsl_rec
                IN c_rsl_lines (
                       p_source_header_id   => grn_rec.source_header_id,
                       p_sku_code           => grn_rec.sku_code)
            LOOP
                MSG (
                    'GET_SHIPMENT_LINE_ID',
                       'GRNLID,TRXID, GRNQTY, RSLQTY '
                    || grn_rec.grn_line_id
                    || ', '
                    || rsl_rec.transaction_id
                    || ', '
                    || grn_rec.qty_received
                    || ', '
                    || rsl_rec.qty_remaining);

                IF rsl_rec.qty_remaining = grn_rec.qty_received
                THEN
                    UPDATE xxdo.xxdo_wms_3pl_grn_l
                       SET source_line_id = rsl_rec.shipment_line_id, transaction_id = rsl_rec.transaction_id, last_update_date = SYSDATE,
                           split = 'U', process_status = 'P'
                     WHERE     1 = 1
                           AND source_line_id = -1
                           AND grn_line_id = grn_rec.grn_line_id;

                    COMMIT;
                    EXIT;
                END IF;
            END LOOP;                                                --rsl_rec
        END LOOP;                                                    --grn_rec



        FOR grn_rec IN c_grn_lines
        LOOP
            l_qty_bal   := 0;

            FOR rsl_rec
                IN c_rsl_lines (
                       p_source_header_id   => grn_rec.source_header_id,
                       p_sku_code           => grn_rec.sku_code)
            LOOP
                MSG (
                    'GET_SHIPMENT_LINE_ID',
                       'Split-GRNLID,TRXID, GRNQTY, RSLQTY '
                    || grn_rec.grn_line_id
                    || ', '
                    || rsl_rec.transaction_id
                    || ', '
                    || grn_rec.qty_received
                    || ', '
                    || rsl_rec.qty_remaining);
                l_qty_bal   := l_qty_bal + rsl_rec.qty_remaining;

                IF TO_NUMBER (grn_rec.qty_received) <= l_qty_bal
                THEN
                    INSERT INTO XXDO.XXDO_WMS_3PL_GRN_L_GTT (
                                    grn_line_id,
                                    grn_received_qty,
                                    shipment_line_id,
                                    shipment_open_qty,
                                    grn_split_qty,
                                    transaction_id)
                             VALUES (
                                        grn_rec.grn_line_id,
                                        grn_rec.qty_received,
                                        rsl_rec.shipment_line_id,
                                        rsl_rec.qty_remaining,
                                          rsl_rec.qty_remaining
                                        - (l_qty_bal - grn_rec.qty_received),
                                        rsl_rec.transaction_id);
                ELSE
                    INSERT INTO XXDO.XXDO_WMS_3PL_GRN_L_GTT (
                                    grn_line_id,
                                    grn_received_qty,
                                    shipment_line_id,
                                    shipment_open_qty,
                                    grn_split_qty,
                                    transaction_id)
                             VALUES (grn_rec.grn_line_id,
                                     grn_rec.qty_received,
                                     rsl_rec.shipment_line_id,
                                     rsl_rec.qty_remaining,
                                     rsl_rec.qty_remaining,
                                     rsl_rec.transaction_id);
                END IF;
            END LOOP;

            FOR idx
                IN (SELECT *
                      FROM xxdo.xxdo_wms_3pl_grn_l_gtt
                     WHERE     grn_line_id = grn_rec.grn_line_id
                           AND grn_split_qty > 0)
            LOOP
                BEGIN
                    l_err_msg   := '';

                    INSERT INTO xxdo.xxdo_wms_3pl_grn_l (
                                    GRN_HEADER_ID,
                                    GRN_LINE_ID,
                                    MESSAGE_TYPE,
                                    SKU_CODE,
                                    LINE_SEQUENCE,
                                    QTY_RECEIVED,
                                    LOCK_CODE,
                                    CREATED_BY,
                                    CREATION_DATE,
                                    LAST_UPDATED_BY,
                                    LAST_UPDATE_DATE,
                                    SOURCE_LINE_ID,
                                    INVENTORY_ITEM_ID,
                                    QUANTITY_TO_RECEIVE,
                                    SUBINVENTORY_CODE,
                                    PROCESS_STATUS,
                                    PROCESSING_SESSION_ID,
                                    ERROR_MESSAGE,
                                    CARTON_CODE,
                                    RETURN_REASON_CODE,
                                    DUTY_PAID_FLAG,
                                    RECEIPT_TYPE,
                                    COO,
                                    UNIT_WEIGHT,
                                    UNIT_LENGTH,
                                    UNIT_WIDTH,
                                    UNIT_HEIGHT,
                                    split,
                                    transaction_id)
                         VALUES (grn_rec.GRN_HEADER_ID, xxdo.xxdo_wms_3pl_grn_l_s.NEXTVAL --grn_rec.GRN_LINE_ID
                                                                                         , grn_rec.MESSAGE_TYPE, grn_rec.SKU_CODE, grn_rec.LINE_SEQUENCE, idx.grn_split_qty --grn_rec.QTY_RECEIVED
                                                                                                                                                                           , grn_rec.LOCK_CODE, grn_rec.CREATED_BY, SYSDATE --grn_rec.CREATION_DATE
                                                                                                                                                                                                                           , grn_rec.LAST_UPDATED_BY, SYSDATE --grn_rec.LAST_UPDATE_DATE
                                                                                                                                                                                                                                                             , idx.shipment_line_id --grn_rec.SOURCE_LINE_ID
                                                                                                                                                                                                                                                                                   , grn_rec.INVENTORY_ITEM_ID, idx.grn_split_qty --grn_rec.QUANTITY_TO_RECEIVE
                                                                                                                                                                                                                                                                                                                                 , grn_rec.SUBINVENTORY_CODE, grn_rec.PROCESS_STATUS, grn_rec.PROCESSING_SESSION_ID, grn_rec.ERROR_MESSAGE, grn_rec.CARTON_CODE, grn_rec.RETURN_REASON_CODE, grn_rec.DUTY_PAID_FLAG, grn_rec.RECEIPT_TYPE, grn_rec.COO, grn_rec.UNIT_WEIGHT, grn_rec.UNIT_LENGTH, grn_rec.UNIT_WIDTH, grn_rec.UNIT_HEIGHT
                                 , 'I'                                 --Split
                                      , idx.transaction_id);


                    UPDATE xxdo.xxdo_wms_3pl_grn_l
                       SET process_status = 'X', split = 'U', error_message = 'Line Splitted'
                     WHERE 1 = 1 AND grn_line_id = grn_rec.grn_line_id;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_err_msg   := SUBSTR (SQLERRM, 1, 240);

                        UPDATE xxdo.xxdo_wms_3pl_grn_l
                           SET process_status = 'E', split = 'U', error_message = l_err_msg
                         WHERE 1 = 1 AND grn_line_id = grn_rec.grn_line_id;

                        COMMIT;
                END;
            END LOOP;
        END LOOP;                                                --c_grn_lines
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('GET_SHIPMENT_LINE_ID', 'Exception:- ' || SQLERRM);
    END get_shipment_line_id;

    --END: Added for CCR0010325



    PROCEDURE process_grn
    IS
        l_ret_stat            VARCHAR2 (1);
        l_message             VARCHAR2 (2000);
        l_qty_remaining       NUMBER;
        l_qty_to_receive      NUMBER;
        l_send_partial        VARCHAR2 (1);                      -- CCR0002036
        l_carton_count        NUMBER;
        l_carton_flag         NUMBER;
        ln_recei_count        NUMBER;                 -- Added for change 1.10
        lv_continue_flag      VARCHAR2 (2);           -- Added for change 1.10
        lv_standard_org       VARCHAR2 (2);           -- Added for change 1.10
        ln_rt_lines_count     NUMBER;                 -- Added for change 1.10
        --Start Added for CCR0009513
        l_del_qty_remaining   NUMBER;
        lv_del_qty_err        VARCHAR2 (2);
        ln_qty_rcv_check      NUMBER;
        ln_get_rcv_rti_qty    NUMBER;
        ln_split_rec_cnt      NUMBER;
    --End Added for CCR0009513

    BEGIN
        --BEGIN: Added for CCR0010325
        BEGIN
            get_shipment_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_ret_stat   := g_ret_unexp_error;
                l_message    := SQLERRM;
        END;

        --END: Added for CCR0010325


        FOR c_header
            IN (SELECT h.grn_header_id, h.source_document_code, h.receiving_date,
                       h.source_header_id, h.preadvice_id, h.organization_id
                  FROM xxdo.xxdo_wms_3pl_grn_h h
                 WHERE     1 = 1
                       AND h.process_status = 'P'
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM xxdo.xxdo_wms_3pl_grn_l l2
                                 WHERE     l2.grn_header_id = h.grn_header_id
                                       --AND l2.process_status != 'P'           -- Commented for CCR0010325
                                       AND l2.process_status IN
                                               ('E', 'A', 'S') -- Added for CCR0010325
                                                              )
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM xxdo.xxdo_wms_3pl_grn_l l2
                                 WHERE     l2.grn_header_id = h.grn_header_id
                                       AND l2.processing_session_id !=
                                           h.processing_session_id)
                       AND h.processing_session_id = USERENV ('SESSIONID'))
        LOOP
            BEGIN
                SAVEPOINT begin_header;

                l_send_partial    := 'Y';                        -- CCR0002036
                l_ret_stat        := g_ret_success;


                --Validation step for cartons
                IF SUBSTR (c_header.preadvice_id, 1, 3) IN ('RTN', 'RET')
                THEN
                    --No cartons for Returns.
                    l_carton_flag   := 0;
                ELSE
                    l_carton_flag   :=
                        xxdo_wms_carton_utils.check_carton_receiving (
                            c_header.grn_header_id);
                END IF;

                DBMS_OUTPUT.put_line ('l_carton_flag : ' || l_carton_flag);


                IF SUBSTR (c_header.preadvice_id, 1, 3) = 'RTN'
                THEN
                    /*Start of changes for 1.10*/
                    BEGIN
                        SELECT COUNT (*)
                          INTO ln_rt_lines_count
                          FROM xxdo.xxdo_wms_3pl_grn_l l
                         WHERE     l.grn_header_id = c_header.grn_header_id
                               AND l.process_status = 'P'
                               AND NVL (l.receipt_type, 'RECEIVE') =
                                   'RECEIVE'
                               AND l.processing_session_id =
                                   USERENV ('SESSIONID');
                    END;

                    IF ln_rt_lines_count > 0
                    THEN
                        /*End of changes for 1.10*/
                        create_return (
                            p_grn_header_id   => c_header.grn_header_id,
                            x_ret_status      => l_ret_stat,
                            x_message         => l_message);

                        IF NVL (l_ret_stat, g_ret_unexp_error) !=
                           g_ret_success
                        THEN
                            ROLLBACK TO begin_header;

                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_grn_h
                                   SET process_status = 'E', error_message = 'Unable to generate Return'
                                 WHERE grn_header_id = c_header.grn_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;

                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_grn_l
                                   SET process_status = 'E', error_message = 'Unable to generate Return'
                                 WHERE grn_header_id = c_header.grn_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;
                        END IF;
                    END IF;                            --Added for change 1.10
                --Commented as per CCR0006943 by CVC on 03/07/2018
                --EXIT WHEN l_ret_stat != g_ret_success;
                END IF;

                l_qty_remaining   := 0;

                FOR c_line
                    IN (  SELECT l.source_line_id,
                                 CASE l_carton_flag
                                     WHEN 1 THEN l.quantity_to_receive
                                     ELSE SUM (l.quantity_to_receive)
                                 END quantity_to_receive,
                                 l.subinventory_code,
                                 l.grn_line_id,
                                 l.inventory_item_id,
                                 l.duty_paid_flag,
                                 --Added as per ver 1.1
                                 CASE l_carton_flag
                                     WHEN 1 THEN l.carton_code
                                     ELSE NULL
                                 END carton_code,
                                 l.receipt_type       -- Added for change 1.10
                                               ,
                                 l.transaction_id      -- Added for CCR0010325
                            FROM xxdo.xxdo_wms_3pl_grn_l l
                           WHERE     l.grn_header_id = c_header.grn_header_id
                                 AND l.process_status = 'P'
                                 AND l.processing_session_id =
                                     USERENV ('SESSIONID')
                        GROUP BY l.source_line_id,
                                 l.quantity_to_receive,
                                 l.subinventory_code,
                                 l.grn_line_id,
                                 l.inventory_item_id,
                                 l.duty_paid_flag,      --Added as per ver 1.1
                                 l.receipt_type,      -- Added for change 1.10
                                 CASE l_carton_flag
                                     WHEN 1 THEN l.carton_code
                                     ELSE NULL
                                 END,
                                 l.transaction_id       --Added for CCR0010325
                        ORDER BY l.receipt_type DESC  -- Added for change 1.10
                                                    )
                LOOP
                    /*Start of changes for 1.10*/
                    BEGIN
                        SELECT 'Y'
                          INTO lv_standard_org
                          FROM fnd_lookup_values fv, org_organization_definitions ood
                         WHERE     fv.lookup_type =
                                   'XDO_PO_STAND_RECEIPT_ORGS'
                               AND fv.LANGUAGE = USERENV ('Lang')
                               AND fv.enabled_flag = 'Y'
                               AND SYSDATE BETWEEN fv.start_date_active
                                               AND NVL (fv.end_date_active,
                                                        SYSDATE)
                               AND ood.organization_code = fv.meaning
                               AND ood.organization_id =
                                   c_header.organization_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_standard_org   := 'N';
                    END;

                    IF     NVL (lv_standard_org, 'N') = 'Y'
                       AND c_line.receipt_type = 'DELIVER'
                    THEN
                        BEGIN
                            SELECT COUNT (*)
                              INTO ln_recei_count
                              FROM xxdo.xxdo_wms_3pl_grn_l
                             WHERE     source_line_id = c_line.source_line_id
                                   AND receipt_type = 'RECEIVE'
                                   AND process_status = 'S';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_recei_count   := 0;
                        END;

                        IF ln_recei_count = 0
                        THEN
                            IF SUBSTR (c_header.preadvice_id, 1, 3) IN
                                   ('RTN', 'RET')
                            THEN
                                BEGIN
                                    SELECT COUNT (*)
                                      INTO ln_recei_count
                                      FROM rcv_transactions
                                     WHERE     oe_order_line_id =
                                               c_line.source_line_id
                                           AND transaction_type = 'RECEIVE';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_recei_count   := 0;
                                END;
                            ELSE
                                BEGIN
                                    SELECT COUNT (*)
                                      INTO ln_recei_count
                                      FROM rcv_transactions
                                     WHERE     shipment_line_id =
                                               c_line.source_line_id
                                           AND transaction_type = 'RECEIVE';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_recei_count   := 0;
                                END;
                            END IF;
                        END IF;

                        IF ln_recei_count = 0
                        THEN
                            lv_continue_flag   := 'N';
                        --Start Added for CCR0009513
                        ELSE
                            ln_qty_rcv_check   :=
                                NVL (c_line.quantity_to_receive, 0);
                            ln_get_rcv_rti_qty   :=
                                NVL (
                                    get_rcv_rti_qty (
                                        p_shipment_line_id   =>
                                            c_line.source_line_id,
                                        p_inv_item_id   =>
                                            c_line.inventory_item_id),
                                    0);

                            IF SUBSTR (c_header.preadvice_id, 1, 3) IN
                                   ('RTN', 'RET')
                            THEN
                                lv_continue_flag   := 'Y';
                            ELSE
                                IF     NVL (c_line.quantity_to_receive, 0) <=
                                       NVL (
                                           get_rcv_rti_qty (
                                               p_shipment_line_id   =>
                                                   c_line.source_line_id,
                                               p_inv_item_id   =>
                                                   c_line.inventory_item_id),
                                           0)
                                   AND SIGN (
                                           NVL (c_line.quantity_to_receive,
                                                0)) <>
                                       -1               --Added for CCR0010325
                                THEN
                                    lv_continue_flag   := 'Y';
                                ELSE
                                    lv_continue_flag   := 'N';
                                    lv_del_qty_err     := 'E';
                                END IF;
                            END IF;
                        --End Added for CCR0009513
                        END IF;
                    ELSE
                        lv_continue_flag   := 'Y';
                    END IF;

                    IF lv_continue_flag = 'Y'
                    THEN
                        /*End of changes for 1.10*/
                        BEGIN
                            IF SUBSTR (c_header.preadvice_id, 1, 3) IN
                                   ('RTN', 'RET')
                            THEN
                                -- Returns --
                                rcv_line (
                                    p_source_document_code   =>
                                        c_header.source_document_code,
                                    p_source_line_id   =>
                                        c_line.source_line_id,
                                    p_quantity       => c_line.quantity_to_receive,
                                    x_ret_stat       => l_ret_stat,
                                    x_message        => l_message,
                                    p_subinventory   =>
                                        c_line.subinventory_code,
                                    p_duty_paid_flag   =>
                                        c_line.duty_paid_flag,
                                    --Added as per ver 1.1
                                    p_receipt_date   =>
                                        c_header.receiving_date,
                                    p_receipt_type   => c_line.receipt_type--Added for change 1.10
                                                                           );
                            ELSE
                                -- Internal Shipment or Purchase Order --
                                l_qty_remaining   :=
                                    c_line.quantity_to_receive;

                                FOR c_ship_line
                                    IN (-- 2013/01/03 - KWG -- CCR0002494 - BEGIN EMEA Procurement Restructure --
                                        /*
                                            select shipment_line_id
                                                   , quantity_shipped - quantity_received - nvl((select sum(quantity) from apps.rcv_transactions_interface rti where rti.shipment_line_id=rsl.shipment_line_id), 0) as line_qty
                                                   , max(shipment_line_id) over (partition by item_id) as max_ship_line_id
                                            from apps.rcv_shipment_lines rsl
                                                  , apps.rcv_shipment_headers rsh
                                            where rsl.shipment_header_id = rsh.shipment_header_id
                                                and to_number(rsh.attribute2) = c_header.source_header_id
                                                and rsh.receipt_source_code = decode(c_header.source_document_code, 'REQ', 'INTERNAL ORDER' , 'PO', 'VENDOR', '***NONE***')
                                                and rsh.ship_to_org_id = c_header.organization_id
                                                and rsl.item_id = c_line.inventory_item_id
                                                and rsl.shipment_line_status_code in ('EXPECTED', 'PARTIALLY RECEIVED')
                                                and rsl.quantity_shipped - rsl.quantity_received - nvl((select sum(quantity) from apps.rcv_transactions_interface rti where rti.shipment_line_id=rsl.shipment_line_id), 0) > 0
                                            order by shipment_line_id
                                       */
                                        -- Internal requisition direct delivery PO's --
                                        SELECT rsl.shipment_line_id,
                                                 rsl.quantity_shipped
                                               - rsl.quantity_received
                                               - NVL (
                                                     (SELECT SUM (quantity)
                                                        FROM apps.rcv_transactions_interface rti
                                                       WHERE rti.shipment_line_id =
                                                             rsl.shipment_line_id),
                                                     0)
                                                   AS line_qty,
                                               MAX (rsl.shipment_line_id)
                                                   OVER (
                                                       PARTITION BY rsl.item_id)
                                                   AS max_ship_line_id,
                                               TO_NUMBER (NULL)
                                                   AS parent_transaction_id
                                          FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh
                                         WHERE     rsl.shipment_header_id =
                                                   rsh.shipment_header_id
                                               AND NOT EXISTS
                                                       (SELECT NULL
                                                          FROM apps.po_line_locations_all plla, apps.rcv_routing_headers rrh
                                                         WHERE     plla.receiving_routing_id =
                                                                   rrh.routing_header_id
                                                               AND plla.line_location_id =
                                                                   rsl.po_line_location_id
                                                               AND rrh.routing_name =
                                                                   'Standard Receipt')
                                               AND TO_NUMBER (rsh.attribute2) =
                                                   c_header.source_header_id
                                               AND rsh.receipt_source_code =
                                                   DECODE (
                                                       c_header.source_document_code,
                                                       'REQ', 'INTERNAL ORDER',
                                                       'PO', 'VENDOR',
                                                       '***NONE***')
                                               AND rsh.ship_to_org_id =
                                                   c_header.organization_id
                                               AND rsl.item_id =
                                                   c_line.inventory_item_id
                                               AND rsl.shipment_line_status_code IN
                                                       ('EXPECTED', 'PARTIALLY RECEIVED')
                                               AND   rsl.quantity_shipped
                                                   - rsl.quantity_received
                                                   - NVL (
                                                         (SELECT SUM (quantity)
                                                            FROM apps.rcv_transactions_interface rti
                                                           WHERE rti.shipment_line_id =
                                                                 rsl.shipment_line_id),
                                                         0) >
                                                   0
                                               AND NVL (lv_standard_org, 'N') =
                                                   'N'
                                        --Added for change 1.10
                                        UNION ALL
                                        -- Split Receive/Deliver PO's --
                                        SELECT rsl.shipment_line_id,
                                                 NVL (
                                                     (SELECT SUM (quantity)
                                                        FROM apps.rcv_supply rs
                                                       WHERE     rs.shipment_line_id =
                                                                 rsl.shipment_line_id
                                                             AND rs.supply_type_code =
                                                                 'RECEIVING'),
                                                     0)
                                               - NVL (
                                                     (SELECT SUM (quantity)
                                                        FROM apps.rcv_transactions_interface rti
                                                       WHERE rti.shipment_line_id =
                                                             rsl.shipment_line_id),
                                                     0)
                                                   AS line_qty,
                                               MAX (rsl.shipment_line_id)
                                                   OVER (
                                                       PARTITION BY rsl.item_id)
                                                   AS max_ship_line_id-- Note: The logic below to obtain the parent transaction id requires that there is only one RECEIVE operation for the shipment line.
                                                                      --          This condition is always true when the shipment line (ASN) is created using our custom logic.  If support for multiple RECEIVE
                                                                      --          operations is required, logic will need to be incorporate to compensate for CORRECT and RETURN TO XXX transactions.
                                                                      ,
                                               (SELECT transaction_id
                                                  FROM apps.rcv_transactions rt
                                                 WHERE     rt.shipment_line_id =
                                                           rsl.shipment_line_id
                                                       AND rt.transaction_type =
                                                           'RECEIVE'
                                                       AND ROWNUM = 1)
                                                   AS parent_transaction_id
                                          FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.po_line_locations_all plla,
                                               apps.rcv_routing_headers rrh
                                         WHERE     rsl.shipment_header_id =
                                                   rsh.shipment_header_id
                                               AND plla.line_location_id =
                                                   rsl.po_line_location_id
                                               AND plla.receiving_routing_id =
                                                   rrh.routing_header_id
                                               AND rrh.routing_name =
                                                   'Standard Receipt'
                                               AND   NVL (
                                                         (SELECT SUM (quantity)
                                                            FROM apps.rcv_supply rs
                                                           WHERE     rs.shipment_line_id =
                                                                     rsl.shipment_line_id
                                                                 AND rs.supply_type_code =
                                                                     'RECEIVING'),
                                                         0)
                                                   - NVL (
                                                         (SELECT SUM (quantity)
                                                            FROM apps.rcv_transactions_interface rti
                                                           WHERE rti.shipment_line_id =
                                                                 rsl.shipment_line_id),
                                                         0) >
                                                   0
                                               AND TO_NUMBER (rsh.attribute2) =
                                                   c_header.source_header_id
                                               AND rsh.receipt_source_code =
                                                   DECODE (
                                                       c_header.source_document_code,
                                                       'REQ', 'INTERNAL ORDER',
                                                       'PO', 'VENDOR',
                                                       '***NONE***')
                                               AND rsh.ship_to_org_id =
                                                   c_header.organization_id
                                               AND NVL (lv_standard_org, 'N') =
                                                   'N'
                                               --Added for change 1.10
                                               AND rsl.item_id =
                                                   c_line.inventory_item_id
                                        --Start of changes for 1.10
                                        UNION ALL
                                        SELECT rsl.shipment_line_id,
                                                 rsl.quantity_shipped
                                               - rsl.quantity_received
                                               - NVL (
                                                     (SELECT SUM (quantity)
                                                        FROM apps.rcv_transactions_interface rti
                                                       WHERE     rti.shipment_line_id =
                                                                 rsl.shipment_line_id
                                                             --Start Added for CCR0009513
                                                             AND transaction_type =
                                                                 'RECEIVE'),
                                                     --End Added for CCR0009513
                                                     0)
                                                   AS line_qty,
                                               MAX (rsl.shipment_line_id)
                                                   OVER (
                                                       PARTITION BY rsl.item_id)
                                                   AS max_ship_line_id,
                                               TO_NUMBER (NULL)
                                                   AS parent_transaction_id
                                          FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh
                                         WHERE     rsl.shipment_header_id =
                                                   rsh.shipment_header_id
                                               AND TO_NUMBER (rsh.attribute2) =
                                                   c_header.source_header_id
                                               AND rsh.receipt_source_code =
                                                   DECODE (
                                                       c_header.source_document_code,
                                                       'REQ', 'INTERNAL ORDER',
                                                       'PO', 'VENDOR',
                                                       '***NONE***')
                                               AND rsh.ship_to_org_id =
                                                   c_header.organization_id
                                               AND rsl.item_id =
                                                   c_line.inventory_item_id
                                               AND rsl.shipment_line_status_code IN
                                                       ('EXPECTED', 'PARTIALLY RECEIVED')
                                               AND   rsl.quantity_shipped
                                                   - rsl.quantity_received
                                                   - NVL (
                                                         (SELECT SUM (quantity)
                                                            FROM apps.rcv_transactions_interface rti
                                                           WHERE     rti.shipment_line_id =
                                                                     rsl.shipment_line_id
                                                                 --Start Added for CCR0009513
                                                                 AND transaction_type =
                                                                     'RECEIVE'),
                                                         --End Added for CCR0009513),
                                                         0) >
                                                   0
                                               AND NVL (lv_standard_org, 'N') =
                                                   'Y'
                                               AND c_line.receipt_type =
                                                   'RECEIVE'
                                        /* --Start Commented for CCR0009513
                                        UNION ALL
                                        SELECT   rsl.shipment_line_id,
                                                   (  NVL
                                                         ((SELECT SUM (quantity)
                                                             FROM apps.rcv_transactions rt
                                                            WHERE rt.shipment_line_id =
                                                                      rsl.shipment_line_id
                                                              AND rt.transaction_type =
                                                                                 'RECEIVE'),
                                                          0
                                                         )
                                                    + NVL
                                                         ((SELECT SUM (quantity)
                                                             FROM rcv_transactions_interface
                                                            WHERE shipment_line_id =
                                                                      rsl.shipment_line_id
                                                              AND transaction_type =
                                                                                 'RECEIVE'
                                                              AND processing_status_code =
                                                                                 'PENDING'),
                                                          0
                                                         )
                                                   )
                                                 - NVL ((SELECT SUM (quantity)
                                                           FROM apps.rcv_transactions rt
                                                          WHERE rt.shipment_line_id =
                                                                      rsl.shipment_line_id
                                                            AND rt.transaction_type =
                                                                                 'DELIVER'),
                                                        0
                                                       ) AS line_qty,
                                                 MAX
                                                    (rsl.shipment_line_id
                                                    ) OVER (PARTITION BY rsl.item_id)
                                                                      AS max_ship_line_id,
                                                 NVL
                                                    ((SELECT transaction_id
                                                        FROM apps.rcv_transactions rt
                                                       WHERE rt.shipment_line_id =
                                                                      rsl.shipment_line_id
                                                         AND rt.transaction_type =
                                                                                 'RECEIVE'
                                                         AND NOT EXISTS (
                                                                SELECT 1
                                                                  FROM apps.rcv_transactions rt1
                                                                 WHERE rt1.shipment_line_id =
                                                                          rt.shipment_line_id
                                                                   AND rt.transaction_id =
                                                                          parent_transaction_id)
                                                         AND ROWNUM = 1),
                                                     (SELECT interface_transaction_id
                                                        FROM apps.rcv_transactions_interface rt
                                                       WHERE rt.shipment_line_id =
                                                                      rsl.shipment_line_id
                                                         AND rt.transaction_type =
                                                                                 'RECEIVE'
                                                         AND ROWNUM = 1)
                                                    ) AS parent_transaction_id
                                            FROM apps.rcv_shipment_lines rsl,
                                                 apps.rcv_shipment_headers rsh
                                           WHERE rsl.shipment_header_id =
                                                                    rsh.shipment_header_id
                                             AND TO_NUMBER (rsh.attribute2) =
                                                                 c_header.source_header_id
                                             AND rsh.receipt_source_code =
                                                    DECODE (c_header.source_document_code,
                                                            'REQ', 'INTERNAL ORDER',
                                                            'PO', 'VENDOR',
                                                            '***NONE***'
                                                           )
                                             AND rsh.ship_to_org_id =
                                                                  c_header.organization_id
                                             AND rsl.item_id = c_line.inventory_item_id
                                             AND rsl.shipment_line_status_code IN
                                                    ('EXPECTED', 'PARTIALLY RECEIVED',
                                                     'FULLY RECEIVED')
                                             AND   (  NVL
                                                         ((SELECT SUM (quantity)
                                                             FROM apps.rcv_transactions rt
                                                            WHERE rt.shipment_line_id =
                                                                      rsl.shipment_line_id
                                                              AND rt.transaction_type =
                                                                                 'RECEIVE'),
                                                          0
                                                         )
                                                    + NVL
                                                         ((SELECT SUM (quantity)
                                                             FROM rcv_transactions_interface
                                                            WHERE shipment_line_id =
                                                                      rsl.shipment_line_id
                                                              AND transaction_type =
                                                                                 'RECEIVE'
                                                              AND processing_status_code =
                                                                                 'PENDING'),
                                                          0
                                                         )
                                                   )
                                                 - NVL ((SELECT SUM (quantity)
                                                           FROM apps.rcv_transactions rt
                                                          WHERE rt.shipment_line_id =
                                                                      rsl.shipment_line_id
                                                            AND rt.transaction_type =
                                                                                 'DELIVER'),
                                                        0
                                                       ) > 0
                                             AND NVL (lv_standard_org, 'N') = 'Y'
                                             AND c_line.receipt_type = 'DELIVER'
                     */
                                        --End Commented for CCR0009513
                                        UNION ALL
                                        SELECT rsl.shipment_line_id,
                                                 rsl.quantity_shipped
                                               - rsl.quantity_received
                                               - NVL (
                                                     (SELECT SUM (quantity)
                                                        FROM apps.rcv_transactions_interface rti
                                                       WHERE     rti.shipment_line_id =
                                                                 rsl.shipment_line_id
                                                             --Start Added for CCR0009513
                                                             AND transaction_type =
                                                                 'RECEIVE'),
                                                     --End Added for CCR0009513
                                                     0)
                                                   AS line_qty,
                                               MAX (rsl.shipment_line_id)
                                                   OVER (
                                                       PARTITION BY rsl.item_id)
                                                   AS max_ship_line_id,
                                               (SELECT transaction_id
                                                  FROM apps.rcv_transactions rt
                                                 WHERE     rt.shipment_line_id =
                                                           rsl.shipment_line_id
                                                       AND rt.transaction_type =
                                                           'RECEIVE'
                                                       AND ROWNUM = 1)
                                                   AS parent_transaction_id
                                          FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.po_line_locations_all plla,
                                               apps.rcv_routing_headers rrh
                                         WHERE     rsl.shipment_header_id =
                                                   rsh.shipment_header_id
                                               AND plla.line_location_id =
                                                   rsl.po_line_location_id
                                               AND plla.receiving_routing_id =
                                                   rrh.routing_header_id
                                               AND rrh.routing_name =
                                                   'Standard Receipt'
                                               AND   rsl.quantity_shipped
                                                   - rsl.quantity_received
                                                   - NVL (
                                                         (SELECT SUM (quantity)
                                                            FROM apps.rcv_transactions_interface rti
                                                           WHERE     rti.shipment_line_id =
                                                                     rsl.shipment_line_id
                                                                 --Start Added for CCR0009513
                                                                 AND transaction_type =
                                                                     'RECEIVE'),
                                                         --End Added for CCR0009513),
                                                         0) >
                                                   0
                                               AND TO_NUMBER (rsh.attribute2) =
                                                   c_header.source_header_id
                                               AND rsh.receipt_source_code =
                                                   DECODE (
                                                       c_header.source_document_code,
                                                       'REQ', 'INTERNAL ORDER',
                                                       'PO', 'VENDOR',
                                                       '***NONE***')
                                               AND rsh.ship_to_org_id =
                                                   c_header.organization_id
                                               AND NVL (lv_standard_org, 'N') =
                                                   'Y'
                                               AND rsl.item_id =
                                                   c_line.inventory_item_id
                                               AND NVL (c_line.receipt_type,
                                                        'RECEIVE') =
                                                   'RECEIVE'
                                        /* --Start Commented for CCR0009513
                                        UNION ALL
                                        SELECT   rsl.shipment_line_id,
                                                   (  NVL
                                                         ((SELECT SUM (quantity)
                                                             FROM apps.rcv_transactions rt
                                                            WHERE rt.shipment_line_id =
                                                                      rsl.shipment_line_id
                                                              AND rt.transaction_type =
                                                                                 'RECEIVE'),
                                                          0
                                                         )
                                                    + NVL
                                                         ((SELECT SUM (quantity)
                                                             FROM rcv_transactions_interface
                                                            WHERE shipment_line_id =
                                                                      rsl.shipment_line_id
                                                              AND transaction_type =
                                                                                 'RECEIVE'
                                                              AND processing_status_code =
                                                                                 'PENDING'),
                                                          0
                                                         )
                                                   )
                                                 - NVL ((SELECT SUM (quantity)
                                                           FROM apps.rcv_transactions rt
                                                          WHERE rt.shipment_line_id =
                                                                      rsl.shipment_line_id
                                                            AND rt.transaction_type =
                                                                                 'DELIVER'),
                                                        0
                                                       ) AS line_qty,
                                                 MAX
                                                    (rsl.shipment_line_id
                                                    ) OVER (PARTITION BY rsl.item_id)
                                                                      AS max_ship_line_id,
                                                 NVL
                                                    ((SELECT transaction_id
                                                        FROM apps.rcv_transactions rt
                                                       WHERE rt.shipment_line_id =
                                                                      rsl.shipment_line_id
                                                         AND rt.transaction_type =
                                                                                 'RECEIVE'
                                                         AND NOT EXISTS (
                                                                SELECT 1
                                                                  FROM apps.rcv_transactions rt1
                                                                 WHERE rt1.shipment_line_id =
                                                                          rt.shipment_line_id
                                                                   AND rt.transaction_id =
                                                                          parent_transaction_id)
                                                         AND ROWNUM = 1),
                                                     (SELECT interface_transaction_id
                                                        FROM apps.rcv_transactions_interface rt
                                                       WHERE rt.shipment_line_id =
                                                                      rsl.shipment_line_id
                                                         AND rt.transaction_type =
                                                                                 'RECEIVE'
                                                         AND ROWNUM = 1)
                                                    ) AS parent_transaction_id
                                            FROM apps.rcv_shipment_lines rsl,
                                                 apps.rcv_shipment_headers rsh,
                                                 apps.po_line_locations_all plla,
                                                 apps.rcv_routing_headers rrh
                                           WHERE rsl.shipment_header_id =
                                                                    rsh.shipment_header_id
                                             AND plla.line_location_id =
                                                                   rsl.po_line_location_id
                                             AND plla.receiving_routing_id =
                                                                     rrh.routing_header_id
                                             AND rrh.routing_name = 'Standard Receipt'
                                             AND   (  NVL
                                                         ((SELECT SUM (quantity)
                                                             FROM apps.rcv_transactions rt
                                                            WHERE rt.shipment_line_id =
                                                                      rsl.shipment_line_id
                                                              AND rt.transaction_type =
                                                                                 'RECEIVE'),
                                                          0
                                                         )
                                                    + NVL
                                                         ((SELECT SUM (quantity)
                                                             FROM rcv_transactions_interface
                                                            WHERE shipment_line_id =
                                                                      rsl.shipment_line_id
                                                              AND transaction_type =
                                                                                 'RECEIVE'
                                                              AND processing_status_code =
                                                                                 'PENDING'),
                                                          0
                                                         )
                                                   )
                                                 - NVL ((SELECT SUM (quantity)
                                                           FROM apps.rcv_transactions rt
                                                          WHERE rt.shipment_line_id =
                                                                      rsl.shipment_line_id
                                                            AND rt.transaction_type =
                                                                                 'DELIVER'),
                                                        0
                                                       ) > 0
                                             AND TO_NUMBER (rsh.attribute2) =
                                                                 c_header.source_header_id
                                             AND rsh.receipt_source_code =
                                                    DECODE (c_header.source_document_code,
                                                            'REQ', 'INTERNAL ORDER',
                                                            'PO', 'VENDOR',
                                                            '***NONE***'
                                                           )
                                             AND rsh.ship_to_org_id =
                                                                  c_header.organization_id
                                             AND NVL (lv_standard_org, 'N') = 'Y'
                                             AND rsl.item_id = c_line.inventory_item_id
                                             AND c_line.receipt_type = 'DELIVER'
                                        --End of changes for 1.10
                   */
                                        --End Commented for CCR0009513
                                        --Start Added for CCR0009513
                                        UNION ALL
                                        SELECT rsl.shipment_line_id,
                                               get_parenttrxid_qty (
                                                   p_shipment_line_id   =>
                                                       rsl.shipment_line_id,
                                                   p_inv_item_id   =>
                                                       rsl.item_id,
                                                   p_qty_deliver   =>
                                                       c_line.quantity_to_receive,
                                                   p_type   => 'QUANTITY')
                                                   AS line_qty,
                                               MAX (rsl.shipment_line_id)
                                                   OVER (
                                                       PARTITION BY rsl.item_id)
                                                   AS max_ship_line_id,
                                               get_parenttrxid_qty (
                                                   p_shipment_line_id   =>
                                                       rsl.shipment_line_id,
                                                   p_inv_item_id   =>
                                                       rsl.item_id,
                                                   p_qty_deliver   =>
                                                       c_line.quantity_to_receive,
                                                   p_type   =>
                                                       'PARENT_TRANS_ID')
                                                   AS parent_transaction_id
                                          FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh
                                         WHERE     rsl.shipment_header_id =
                                                   rsh.shipment_header_id
                                               AND TO_NUMBER (rsh.attribute2) =
                                                   c_header.source_header_id
                                               AND rsh.receipt_source_code =
                                                   DECODE (
                                                       c_header.source_document_code,
                                                       'REQ', 'INTERNAL ORDER',
                                                       'PO', 'VENDOR',
                                                       '***NONE***')
                                               AND rsh.ship_to_org_id =
                                                   c_header.organization_id
                                               AND rsl.item_id =
                                                   c_line.inventory_item_id
                                               AND rsl.shipment_line_status_code IN
                                                       ('EXPECTED', 'PARTIALLY RECEIVED', 'FULLY RECEIVED')
                                               AND get_parenttrxid_qty (
                                                       p_shipment_line_id   =>
                                                           rsl.shipment_line_id,
                                                       p_inv_item_id   =>
                                                           rsl.item_id,
                                                       p_qty_deliver   =>
                                                           c_line.quantity_to_receive,
                                                       p_type   => 'QUANTITY') >
                                                   0
                                               AND NVL (lv_standard_org, 'N') =
                                                   'Y'
                                               AND c_line.receipt_type =
                                                   'DELIVER'
                                               AND rsl.shipment_line_id =
                                                   c_line.source_line_id --Added for CCR0010325
                                               AND c_line.transaction_id
                                                       IS NULL --Added for CCR0010325
                                        UNION --Changed to UNION ALL to UNION(JAN)
                                        SELECT rsl.shipment_line_id,
                                               get_parenttrxid_qty (
                                                   p_shipment_line_id   =>
                                                       rsl.shipment_line_id,
                                                   p_inv_item_id   =>
                                                       rsl.item_id,
                                                   p_qty_deliver   =>
                                                       c_line.quantity_to_receive,
                                                   p_type   => 'QUANTITY')
                                                   AS line_qty,
                                               MAX (rsl.shipment_line_id)
                                                   OVER (
                                                       PARTITION BY rsl.item_id)
                                                   AS max_ship_line_id,
                                               get_parenttrxid_qty (
                                                   p_shipment_line_id   =>
                                                       rsl.shipment_line_id,
                                                   p_inv_item_id   =>
                                                       rsl.item_id,
                                                   p_qty_deliver   =>
                                                       c_line.quantity_to_receive,
                                                   p_type   =>
                                                       'PARENT_TRANS_ID')
                                                   AS parent_transaction_id
                                          FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.po_line_locations_all plla,
                                               apps.rcv_routing_headers rrh
                                         WHERE     rsl.shipment_header_id =
                                                   rsh.shipment_header_id
                                               AND plla.line_location_id =
                                                   rsl.po_line_location_id
                                               AND plla.receiving_routing_id =
                                                   rrh.routing_header_id
                                               AND rrh.routing_name =
                                                   'Standard Receipt'
                                               AND get_parenttrxid_qty (
                                                       p_shipment_line_id   =>
                                                           rsl.shipment_line_id,
                                                       p_inv_item_id   =>
                                                           rsl.item_id,
                                                       p_qty_deliver   =>
                                                           c_line.quantity_to_receive,
                                                       p_type   => 'QUANTITY') >
                                                   0
                                               AND TO_NUMBER (rsh.attribute2) =
                                                   c_header.source_header_id
                                               AND rsh.receipt_source_code =
                                                   DECODE (
                                                       c_header.source_document_code,
                                                       'REQ', 'INTERNAL ORDER',
                                                       'PO', 'VENDOR',
                                                       '***NONE***')
                                               AND rsh.ship_to_org_id =
                                                   c_header.organization_id
                                               AND rsl.item_id =
                                                   c_line.inventory_item_id
                                               AND NVL (lv_standard_org, 'N') =
                                                   'Y'
                                               AND c_line.receipt_type =
                                                   'DELIVER'
                                               --End Added for CCR0009513
                                               --BEGIN: Added for CCR0010325
                                               AND rsl.shipment_line_id =
                                                   c_line.source_line_id
                                               AND c_line.transaction_id
                                                       IS NULL
                                        UNION ALL
                                        SELECT grnl.source_line_id shipment_line_id, grnl.quantity_to_receive line_qty, grnl.source_line_id max_ship_line_id,
                                               grnl.transaction_id parent_transaction_id
                                          FROM xxdo.xxdo_wms_3pl_grn_l grnl
                                         WHERE     1 = 1
                                               AND grnl.grn_line_id =
                                                   c_line.grn_line_id
                                               AND grnl.transaction_id
                                                       IS NOT NULL
                                        --END:Added for CCR0010325
                                        ORDER BY shipment_line_id)
                                LOOP
                                    --Start Added for CCR0009513
                                    IF NVL (c_line.receipt_type, 'RECEIVE') =
                                       'RECEIVE'
                                    THEN
                                        --End Added for CCR0009513
                                        IF c_ship_line.max_ship_line_id =
                                           c_ship_line.shipment_line_id
                                        THEN
                                            l_qty_to_receive   :=
                                                l_qty_remaining;
                                        ELSE
                                            l_qty_to_receive   :=
                                                LEAST (l_qty_remaining,
                                                       c_ship_line.line_qty);
                                        END IF;
                                    --Start Added for CCR0009513
                                    ELSIF c_line.receipt_type = 'DELIVER'
                                    THEN
                                        l_qty_to_receive   :=
                                            c_ship_line.line_qty;
                                    END IF;

                                    --End Added for CCR0009513

                                    rcv_line (
                                        p_source_document_code   =>
                                            c_header.source_document_code,
                                        p_source_line_id   =>
                                            c_ship_line.shipment_line_id,
                                        p_quantity      => l_qty_to_receive,
                                        p_parent_transaction_id   =>
                                            c_ship_line.parent_transaction_id,
                                        x_ret_stat      => l_ret_stat,
                                        x_message       => l_message,
                                        p_subinventory   =>
                                            c_line.subinventory_code,
                                        p_duty_paid_flag   =>
                                            c_line.duty_paid_flag,
                                        --Added as per ver 1.1
                                        p_receipt_date   =>
                                            c_header.receiving_date,
                                        p_carton_code   => c_line.carton_code,
                                        p_receipt_type   =>
                                            c_line.receipt_type--Added for change 1.10
                                                               );
                                    --dbms_output.put_line('c_line.quantity_to_receive :'||l_qty_remaining);
                                    --Deliver Quantity Remaining
                                    l_qty_remaining   :=
                                        l_qty_remaining - l_qty_to_receive;

                                    --Start Added for CCR0009513
                                    IF c_line.receipt_type = 'DELIVER'
                                    THEN
                                        --dbms_output.put_line('c_line.quantity_to_receive :'||c_line.quantity_to_receive);
                                        --dbms_output.put_line('c_ship_line.line_qty :'||c_ship_line.line_qty);
                                        --dbms_output.put_line('l_qty_remaining Left :'||l_qty_remaining);

                                        l_del_qty_remaining   :=
                                            get_rcv_rti_qty (
                                                p_shipment_line_id   =>
                                                    c_ship_line.shipment_line_id,
                                                p_inv_item_id   =>
                                                    c_line.inventory_item_id);

                                        --dbms_output.put_line('l_del_qty_remaining :'||l_del_qty_remaining);
                                        IF (NVL (l_qty_remaining, 0) > 0)
                                        THEN
                                            LOOP --Loop counter for SPLIT Case
                                                IF (NVL (l_del_qty_remaining, 0) >= NVL (l_qty_remaining, 0))
                                                THEN
                                                    FOR c_deliver_line
                                                        IN (SELECT rsl.shipment_line_id,
                                                                   get_parenttrxid_qty (
                                                                       p_shipment_line_id   =>
                                                                           rsl.shipment_line_id,
                                                                       p_inv_item_id   =>
                                                                           rsl.item_id,
                                                                       p_qty_deliver   =>
                                                                           l_qty_remaining,
                                                                       p_type   =>
                                                                           'QUANTITY')
                                                                       AS line_qty,
                                                                   MAX (
                                                                       rsl.shipment_line_id)
                                                                       OVER (
                                                                           PARTITION BY rsl.item_id)
                                                                       AS max_ship_line_id,
                                                                   get_parenttrxid_qty (
                                                                       p_shipment_line_id   =>
                                                                           rsl.shipment_line_id,
                                                                       p_inv_item_id   =>
                                                                           rsl.item_id,
                                                                       p_qty_deliver   =>
                                                                           l_qty_remaining,
                                                                       p_type   =>
                                                                           'PARENT_TRANS_ID')
                                                                       AS parent_transaction_id
                                                              FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh
                                                             WHERE     rsl.shipment_header_id =
                                                                       rsh.shipment_header_id
                                                                   AND TO_NUMBER (
                                                                           rsh.attribute2) =
                                                                       c_header.source_header_id
                                                                   AND rsh.receipt_source_code =
                                                                       DECODE (
                                                                           c_header.source_document_code,
                                                                           'REQ', 'INTERNAL ORDER',
                                                                           'PO', 'VENDOR',
                                                                           '***NONE***')
                                                                   AND rsh.ship_to_org_id =
                                                                       c_header.organization_id
                                                                   AND rsl.item_id =
                                                                       c_line.inventory_item_id
                                                                   AND rsl.shipment_line_status_code IN
                                                                           ('EXPECTED', 'PARTIALLY RECEIVED', 'FULLY RECEIVED')
                                                                   AND get_parenttrxid_qty (
                                                                           p_shipment_line_id   =>
                                                                               rsl.shipment_line_id,
                                                                           p_inv_item_id   =>
                                                                               rsl.item_id,
                                                                           p_qty_deliver   =>
                                                                               l_qty_remaining,
                                                                           p_type   =>
                                                                               'QUANTITY') >
                                                                       0
                                                                   AND NVL (
                                                                           lv_standard_org,
                                                                           'N') =
                                                                       'Y'
                                                                   AND c_line.receipt_type =
                                                                       'DELIVER'
                                                            UNION
                                                            SELECT rsl.shipment_line_id,
                                                                   get_parenttrxid_qty (
                                                                       p_shipment_line_id   =>
                                                                           rsl.shipment_line_id,
                                                                       p_inv_item_id   =>
                                                                           rsl.item_id,
                                                                       p_qty_deliver   =>
                                                                           l_qty_remaining,
                                                                       p_type   =>
                                                                           'QUANTITY')
                                                                       AS line_qty,
                                                                   MAX (
                                                                       rsl.shipment_line_id)
                                                                       OVER (
                                                                           PARTITION BY rsl.item_id)
                                                                       AS max_ship_line_id,
                                                                   get_parenttrxid_qty (
                                                                       p_shipment_line_id   =>
                                                                           rsl.shipment_line_id,
                                                                       p_inv_item_id   =>
                                                                           rsl.item_id,
                                                                       p_qty_deliver   =>
                                                                           l_qty_remaining,
                                                                       p_type   =>
                                                                           'PARENT_TRANS_ID')
                                                                       AS parent_transaction_id
                                                              FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.po_line_locations_all plla,
                                                                   apps.rcv_routing_headers rrh
                                                             WHERE     rsl.shipment_header_id =
                                                                       rsh.shipment_header_id
                                                                   AND plla.line_location_id =
                                                                       rsl.po_line_location_id
                                                                   AND plla.receiving_routing_id =
                                                                       rrh.routing_header_id
                                                                   AND rrh.routing_name =
                                                                       'Standard Receipt'
                                                                   AND get_parenttrxid_qty (
                                                                           p_shipment_line_id   =>
                                                                               rsl.shipment_line_id,
                                                                           p_inv_item_id   =>
                                                                               rsl.item_id,
                                                                           p_qty_deliver   =>
                                                                               l_qty_remaining,
                                                                           p_type   =>
                                                                               'QUANTITY') >
                                                                       0
                                                                   AND TO_NUMBER (
                                                                           rsh.attribute2) =
                                                                       c_header.source_header_id
                                                                   AND rsh.receipt_source_code =
                                                                       DECODE (
                                                                           c_header.source_document_code,
                                                                           'REQ', 'INTERNAL ORDER',
                                                                           'PO', 'VENDOR',
                                                                           '***NONE***')
                                                                   AND rsh.ship_to_org_id =
                                                                       c_header.organization_id
                                                                   AND NVL (
                                                                           lv_standard_org,
                                                                           'N') =
                                                                       'Y'
                                                                   AND rsl.item_id =
                                                                       c_line.inventory_item_id
                                                                   AND NVL (
                                                                           lv_standard_org,
                                                                           'N') =
                                                                       'Y'
                                                                   AND c_line.receipt_type =
                                                                       'DELIVER'
                                                            ORDER BY
                                                                shipment_line_id)
                                                    LOOP
                                                        rcv_line (
                                                            p_source_document_code   =>
                                                                c_header.source_document_code,
                                                            p_source_line_id   =>
                                                                c_deliver_line.shipment_line_id,
                                                            p_quantity   =>
                                                                c_deliver_line.line_qty,
                                                            p_parent_transaction_id   =>
                                                                c_deliver_line.parent_transaction_id,
                                                            x_ret_stat   =>
                                                                l_ret_stat,
                                                            x_message   =>
                                                                l_message,
                                                            p_subinventory   =>
                                                                c_line.subinventory_code,
                                                            p_duty_paid_flag   =>
                                                                c_line.duty_paid_flag,
                                                            p_receipt_date   =>
                                                                c_header.receiving_date,
                                                            p_carton_code   =>
                                                                c_line.carton_code,
                                                            p_receipt_type   =>
                                                                c_line.receipt_type);

                                                        --Qty remaining check
                                                        l_qty_remaining   :=
                                                              l_qty_remaining
                                                            - c_deliver_line.line_qty;
                                                    END LOOP;
                                                END IF; --IF (NVL(l_del_qty_remaining,0) >= NVL(l_qty_remaining,0))

                                                EXIT WHEN (l_qty_remaining <= 0);
                                            END LOOP;
                                        END IF; --IF (NVL(l_qty_remaining,0) > 0
                                    END IF;  --c_line.receipt_type = 'DELIVER'

                                    --End Added for CCR0009513
                                    EXIT WHEN l_qty_remaining <= 0;
                                END LOOP;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_ret_stat   := g_ret_unexp_error;
                                l_message    := SQLERRM;
                        END;

                        IF l_qty_remaining > 0
                        THEN
                            l_ret_stat   := g_ret_error;
                            l_message    :=
                                   'There were no open shipment lines found for item '
                                || apps.iid_to_sku (c_line.inventory_item_id);
                        END IF;

                        IF l_ret_stat = g_ret_success
                        THEN
                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_grn_l
                                   SET process_status = 'S', error_message = 'Processing Complete'
                                 WHERE grn_line_id = c_line.grn_line_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_ret_stat   := g_ret_error;
                                    l_message    := SQLERRM;
                            END;
                        END IF;

                        IF NVL (l_ret_stat, g_ret_unexp_error) !=
                           g_ret_success
                        THEN
                            --ROLLBACK TO begin_header;
                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_grn_h
                                   SET process_status = 'E', error_message = 'One or more lines failed to process'
                                 WHERE grn_header_id = c_header.grn_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;

                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_grn_l
                                   SET process_status = 'E', error_message = 'One or more lines failed to process'
                                 WHERE grn_header_id = c_header.grn_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;

                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_grn_l
                                   SET process_status = 'E', error_message = SUBSTR ('Error processing line: ' || l_message, 1, 240)
                                 WHERE grn_line_id = c_line.grn_line_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;
                        END IF;

                        EXIT WHEN l_ret_stat != g_ret_success;
                    --begin CCR0007790
                    /*
                                   IF SUBSTR (c_header.preadvice_id, 1, 3) != 'RTN'
                                   THEN
                                      -- CCR0002036
                                      SELECT NVL (TO_NUMBER (mpd.partial_asn_in_3pl_interface),
                                                  1)
                                                AS allow_partial
                                        INTO l_send_partial
                                        FROM apps.mtl_parameters_dfv mpd, apps.mtl_parameters mp
                                       WHERE     mp.organization_id = c_header.organization_id
                                             AND mpd.row_id = mp.ROWID;

                                      UPDATE apps.rcv_shipment_headers
                                         SET asn_status =
                                                DECODE (l_send_partial,
                                                        2, l_grn_complete_no_partial,
                                                        l_grn_complete)              -- CCR0002036
                                       WHERE     TO_NUMBER (attribute2) =
                                                    c_header.source_header_id
                                             AND receipt_source_code =
                                                    DECODE (c_header.source_document_code,
                                                            'REQ', 'INTERNAL ORDER',
                                                            'PO', 'VENDOR',
                                                            '***NONE***')
                                             AND ship_to_org_id = c_header.organization_id;
                                   END IF;
                                   */
                    --end CCR0007790
                    ELSE                           --IF lv_continue_flag = 'Y'
                        l_ret_stat   := 'E';

                        --Start Added for CCR0009513
                        IF NVL (lv_del_qty_err, 'N') = 'E'
                        THEN
                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_grn_l
                                   SET process_status = 'E', error_message = SUBSTR ('DELIVER Qty is more than RECEIVE Qty ' || l_message, 1, 240)
                                 WHERE grn_line_id = c_line.grn_line_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;

                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_grn_h
                                   SET process_status = 'E', error_message = 'One or more lines failed to process'
                                 WHERE grn_header_id = c_header.grn_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;
                        ELSE
                            --End Added for CCR0009513
                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_grn_l
                                   SET process_status = 'E', error_message = SUBSTR ('RECEIVE Transactions not processed for this line' || l_message, 1, 240)
                                 WHERE grn_line_id = c_line.grn_line_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;

                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_grn_h
                                   SET process_status = 'E', error_message = 'One or more lines failed to process'
                                 WHERE grn_header_id = c_header.grn_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;
                        END IF;                         --Added for CCR0009513
                    END IF;
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_ret_stat   := g_ret_unexp_error;
                    l_message    := SQLERRM;
            END;

            BEGIN
                IF l_ret_stat = g_ret_success
                THEN
                    UPDATE xxdo.xxdo_wms_3pl_grn_h
                       SET process_status = 'S', error_message = NULL
                     WHERE grn_header_id = c_header.grn_header_id;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            RAISE;
    END;

    PROCEDURE write_mti_record (p_mti IN OUT inv.mtl_transactions_interface%ROWTYPE, x_ret_stat OUT VARCHAR2, x_message OUT VARCHAR2)
    IS
        l_pn   VARCHAR2 (240) := '.write_mti_record';
    BEGIN
        x_ret_stat                := g_ret_error;
        SAVEPOINT begin_write_mti_record;
        p_mti.creation_date       := NVL (p_mti.creation_date, SYSDATE);
        p_mti.created_by          := NVL (p_mti.created_by, fnd_global.user_id);
        p_mti.last_update_date    := NVL (p_mti.last_update_date, SYSDATE);
        p_mti.last_updated_by     :=
            NVL (p_mti.last_updated_by, fnd_global.user_id);
        p_mti.last_update_login   :=
            NVL (p_mti.last_update_login, fnd_global.login_id);
        p_mti.request_id          :=
            NVL (p_mti.request_id, fnd_global.conc_login_id);

        INSERT INTO inv.mtl_transactions_interface
             VALUES p_mti;

        x_ret_stat                := g_ret_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_unexp_error;
            x_message    := SQLERRM;
            msg (x_message);
            ROLLBACK TO begin_write_mti_record;
    END;

    PROCEDURE adjust_material (p_organization_id NUMBER, p_secondary_organization_id NUMBER:= NULL, p_inventory_item_id NUMBER, p_quantity NUMBER, p_transaction_date DATE, p_subinventory VARCHAR2, p_secondary_subinventory VARCHAR2:= NULL, p_locator_id NUMBER:= NULL, p_secondary_locator_id NUMBER:= NULL, p_lpn_id NUMBER:= NULL, p_secondary_lpn_id NUMBER:= NULL, p_source_header_id NUMBER, p_source_line_id NUMBER, p_trx_reference VARCHAR2:= NULL, p_trx_comments VARCHAR2:= NULL
                               , p_duty_paid_flag VARCHAR2:= NULL, --Added as per ver 1.1
                                                                   x_ret_stat OUT VARCHAR2, x_message OUT VARCHAR2)
    IS
        l_primary_organization     mtl_parameters%ROWTYPE;
        l_primary_location         mtl_item_locations%ROWTYPE;
        l_primary_lpn              wms_license_plate_numbers%ROWTYPE;
        l_primary_subinventory     mtl_secondary_inventories%ROWTYPE;
        --l_item                     mtl_system_items_b%ROWTYPE;                                    --commented by BT Technology team on 11/10/2014
        l_item                     xxd_common_items_v%ROWTYPE;
        --Added by BT Technology team on 11/10/2014
        l_secondary_organization   mtl_parameters%ROWTYPE;
        l_secondary_location       mtl_item_locations%ROWTYPE;
        l_secondary_lpn            wms_license_plate_numbers%ROWTYPE;
        l_secondary_subinventory   mtl_secondary_inventories%ROWTYPE;
        l_mti                      inv.mtl_transactions_interface%ROWTYPE;
        l_reason_id                NUMBER;              --Added for CCR0008837
        -----------------------------------------------------
        -- Added By Sivakumar Boothathan For ENHC0010815
        -----------------------------------------------------
        l_adj_type_code            VARCHAR2 (100);
    ------------------------------------------------------
    -- End of addition for ENHC0010815
    ------------------------------------------------------
    BEGIN
        -- Added for CCR0008837
        IF p_trx_reference IS NOT NULL
        THEN
            BEGIN
                SELECT reason_id
                  INTO l_reason_id
                  FROM mtl_transaction_reasons
                 WHERE UPPER (reason_name) = UPPER (p_trx_reference);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_mti.transaction_reference   :=
                        NVL (
                            p_trx_reference,
                               '3PL WMS Adjustment OUT '
                            || p_source_header_id
                            || ' - '
                            || p_source_line_id);
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                        'Reason Code not found (' || p_trx_reference || ')';
                    msg (x_message);
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to retrieve reason name information for reason code('
                        || p_trx_reference
                        || ')';
                    msg (x_message);
            END;
        END IF;

        ---- End for CCR0008837
        BEGIN
            SELECT *
              INTO l_primary_organization
              FROM mtl_parameters
             WHERE organization_id = p_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_stat   := g_ret_error;
                x_message    :=
                       'Unable to retrieve Organization information for primary org ('
                    || p_organization_id
                    || ')';
                msg (x_message);
        END;

        BEGIN
            SELECT *
              INTO l_primary_subinventory
              FROM mtl_secondary_inventories
             WHERE     organization_id = p_organization_id
                   AND secondary_inventory_name = p_subinventory;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_stat   := g_ret_error;
                x_message    :=
                       'Unable to retrieve SubInventory information for primary subinventory ('
                    || p_subinventory
                    || ')';
                msg (x_message);
        END;

        BEGIN
            SELECT *
              INTO l_item
              --FROM mtl_system_items_b                                                               --commented by BT Technology team on 11/10/2014
              FROM xxd_common_items_v --Added by BT Technology team on 11/10/2014
             WHERE     organization_id = p_organization_id
                   AND inventory_item_id = p_inventory_item_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_stat   := g_ret_error;
                x_message    :=
                       'Unable to retrieve SubInventory information for primary subinventory ('
                    || p_subinventory
                    || ')';
                msg (x_message);
        END;

        IF p_locator_id IS NOT NULL
        THEN
            BEGIN
                SELECT *
                  INTO l_primary_location
                  FROM mtl_item_locations
                 WHERE     organization_id = p_organization_id
                       AND inventory_location_id = p_locator_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to retrieve Locator information for primary locator ('
                        || p_locator_id
                        || ')';
                    msg (x_message);
            END;
        END IF;

        IF p_lpn_id IS NOT NULL
        THEN
            BEGIN
                SELECT *
                  INTO l_primary_lpn
                  FROM wms_license_plate_numbers
                 WHERE lpn_id = p_lpn_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to retrieve LPN information for primary LPN ('
                        || p_lpn_id
                        || ')';
                    msg (x_message);
            END;
        END IF;

        IF p_secondary_organization_id IS NOT NULL
        THEN
            BEGIN
                SELECT *
                  INTO l_secondary_organization
                  FROM mtl_parameters
                 WHERE organization_id = p_secondary_organization_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to retrieve Secondary Organization information for primary org ('
                        || p_secondary_organization_id
                        || ')';
                    msg (x_message);
            END;
        END IF;

        IF p_secondary_subinventory IS NOT NULL
        THEN
            BEGIN
                SELECT *
                  INTO l_secondary_subinventory
                  FROM mtl_secondary_inventories
                 WHERE     organization_id =
                           NVL (p_secondary_organization_id,
                                p_organization_id)
                       AND secondary_inventory_name =
                           p_secondary_subinventory;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to retrieve Secondary SubInventory information for primary subinventory ('
                        || p_secondary_subinventory
                        || ')';
                    msg (x_message);
            END;
        END IF;

        IF p_secondary_locator_id IS NOT NULL
        THEN
            BEGIN
                SELECT *
                  INTO l_secondary_location
                  FROM mtl_item_locations
                 WHERE     organization_id =
                           NVL (p_secondary_organization_id,
                                p_organization_id)
                       AND inventory_location_id = p_secondary_locator_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to retrieve Secondary Locator information for primary locator ('
                        || p_secondary_locator_id
                        || ')';
                    msg (x_message);
            END;
        END IF;

        IF p_lpn_id IS NOT NULL
        THEN
            BEGIN
                SELECT *
                  INTO l_secondary_lpn
                  FROM wms_license_plate_numbers
                 WHERE lpn_id = p_secondary_lpn_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                           'Unable to retrieve Secondary LPN information for primary LPN ('
                        || p_secondary_lpn_id
                        || ')';
                    msg (x_message);
            END;
        END IF;

        ---------------------------------------------------
        -- Added By Sivakumar Boothathan for ENHC0010815
        ---------------------------------------------------
        BEGIN
            SELECT adj_type_code
              INTO l_adj_type_code
              FROM xxdo.xxdo_wms_3pl_adj_h
             WHERE adj_header_id = p_source_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_message   :=
                    'No Data Found Error While Retriving The Adjustment Type Code At The Header Level';
                msg (x_message);
        END;

        IF (l_adj_type_code IS NULL)
        THEN
            BEGIN
                SELECT adj_type_code
                  INTO l_adj_type_code
                  FROM xxdo.xxdo_wms_3pl_adj_l
                 WHERE adj_line_id = p_source_line_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_message   :=
                        'No Data Found Error While Retriving The Adjustment Type Code At The Line Level';
                    msg (x_message);
            END;
        END IF;

        ---------------------------------------------------
        -- End Of Code Change for ENHC0010815
        ---------------------------------------------------
        l_mti.source_header_id        := p_source_header_id;
        l_mti.source_line_id          := p_source_line_id;
        l_mti.process_flag            := 1;
        l_mti.transaction_mode        := 3;
        l_mti.inventory_item_id       := l_item.inventory_item_id;
        l_mti.organization_id         := l_primary_organization.organization_id;
        l_mti.transaction_quantity    := p_quantity;
        l_mti.transaction_uom         := l_item.primary_uom_code;
        l_mti.transaction_date        := p_transaction_date;
        l_mti.attribute12             := p_duty_paid_flag; --Added as per ver 1.1
        l_mti.transaction_source_id   := NULL;
        l_mti.scheduled_flag          := 2;
        l_mti.flow_schedule           := 'Y';
        l_mti.shippable_flag          := 'Y';
        l_mti.subinventory_code       :=
            l_primary_subinventory.secondary_inventory_name;
        msg (
               'Looking up disposition for org '
            || l_primary_organization.organization_id
            || ', item '
            || l_item.inventory_item_id);

        BEGIN
            SELECT mgd.disposition_id
              INTO l_mti.transaction_source_id
              FROM mtl_generic_dispositions_dfv mgdd, mtl_generic_dispositions mgd, do_custom.do_ora_items_all_v doiav
             WHERE     mgdd.CONTEXT = '3PL'
                   AND mgdd.row_id = mgd.ROWID
                   AND mgdd.brand = doiav.brand
                   AND mgd.organization_id = doiav.organization_id
                   AND doiav.organization_id =
                       l_primary_organization.organization_id
                   AND doiav.inventory_item_id = l_item.inventory_item_id
                   ----------------------------------------------------
                   -- Added By Sivakumar Boothathan for ENHC0010815
                   ----------------------------------------------------
                   --and nvl(mgdd.adj_code,'ZZZ') = nvl(l_adj_type_code,'ZZZ')
                   AND (NVL (mgdd.adj_code, 'ZZZ') = NVL (l_adj_type_code, 'ZZZ') OR p_secondary_subinventory IS NOT NULL)
                   ----------------------------------------------------
                   -- End of code change for ENHC0010815
                   ----------------------------------------------------
                   AND TRUNC (p_transaction_date) BETWEEN TRUNC (
                                                              NVL (
                                                                  mgd.effective_date,
                                                                    p_transaction_date
                                                                  - 1))
                                                      AND TRUNC (
                                                              NVL (
                                                                  mgd.disable_date,
                                                                    p_transaction_date
                                                                  + 1))
                   AND ROWNUM = 1;

            msg ('Found disposition ' || l_mti.transaction_source_id);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                raise_application_error (
                    -20001,
                       'Failed to determine the account alias for item '
                    || l_item.inventory_item_id
                    || ', warehouse '
                    || l_primary_organization.organization_id
                    || ', date '
                    || TO_CHAR (p_transaction_date));
        END;

        IF p_quantity < 0
        THEN
            l_mti.lpn_id                := l_primary_lpn.lpn_id;
            l_mti.transaction_type_id   := 31;

            -- Added for CCR0008837
            IF l_reason_id IS NOT NULL
            THEN
                l_mti.reason_id               := l_reason_id;
                l_mti.transaction_reference   := p_trx_comments;
            ELSE
                l_mti.transaction_reference   :=
                    NVL (
                        p_trx_reference,
                           '3PL WMS Adjustment OUT '
                        || p_source_header_id
                        || ' - '
                        || p_source_line_id);
            END IF;
        -- Commented for CCR0008837
        /* l_mti.transaction_reference :=
           NVL (
              p_trx_reference,
                 '3PL WMS Adjustment OUT '
              || p_source_header_id
              || ' - '
              || p_source_line_id);
              */
        ELSE
            l_mti.lpn_id                := l_secondary_lpn.lpn_id;
            l_mti.transaction_type_id   := 41;

            -- Added for CCR0008837
            IF l_reason_id IS NOT NULL
            THEN
                l_mti.reason_id               := l_reason_id;
                l_mti.transaction_reference   := p_trx_comments;
            ELSE
                l_mti.transaction_reference   :=
                    NVL (
                        p_trx_reference,
                           '3PL WMS Adjustment OUT '
                        || p_source_header_id
                        || ' - '
                        || p_source_line_id);
            END IF;

            -- Commented for CCR0008837
            /* l_mti.transaction_reference :=
               NVL (
                  p_trx_reference,
                     '3PL WMS Adjustment OUT '
                  || p_source_header_id
                  || ' - '
                  || p_source_line_id);
                  */
            IF l_secondary_subinventory.secondary_inventory_name IS NOT NULL
            THEN
                -- Added for CCR0008837
                IF l_reason_id IS NOT NULL
                THEN
                    l_mti.reason_id               := l_reason_id;
                    l_mti.transaction_reference   := p_trx_comments;
                ELSE
                    l_mti.transaction_reference   :=
                        NVL (
                            p_trx_reference,
                               '3PL WMS Adjustment OUT '
                            || p_source_header_id
                            || ' - '
                            || p_source_line_id);
                END IF;

                -- Commented for CCR0008837
                /* l_mti.transaction_reference :=
                   NVL (
                      p_trx_reference,
                         '3PL WMS Adjustment OUT '
                      || p_source_header_id
                      || ' - '
                      || p_source_line_id);
                      */
                l_mti.transaction_source_id   := NULL;
                l_mti.transaction_type_id     := 2;
                l_mti.transfer_lpn_id         := l_primary_lpn.lpn_id;
                l_mti.transfer_subinventory   :=
                    l_secondary_subinventory.secondary_inventory_name;
                l_mti.transfer_organization   :=
                    NVL (l_secondary_organization.organization_id,
                         l_secondary_subinventory.organization_id);
                --Added for CCR0009126
                l_mti.transfer_locator        :=
                    NVL (l_primary_location.inventory_location_id,
                         l_secondary_location.inventory_location_id);
            END IF;
        END IF;

        l_mti.source_code             := l_mti_source_code;
        msg ('Writing MTI Record');
        write_mti_record (p_mti        => l_mti,
                          x_ret_stat   => x_ret_stat,
                          x_message    => x_message);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_error;
            x_message    := SQLERRM;
            msg (x_message);
    END;

    PROCEDURE process_adjustments
    IS
        l_ret_stat   VARCHAR2 (1);
        l_message    VARCHAR2 (2000);
    BEGIN
        FOR c_header
            IN (SELECT h.adj_header_id, h.organization_id, h.adjust_date
                  FROM xxdo.xxdo_wms_3pl_adj_h h
                 WHERE     h.process_status = 'P'
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM xxdo.xxdo_wms_3pl_adj_l l2
                                 WHERE     l2.adj_header_id = h.adj_header_id
                                       AND l2.process_status != 'P')
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM xxdo.xxdo_wms_3pl_adj_l l2
                                 WHERE     l2.adj_header_id = h.adj_header_id
                                       AND l2.processing_session_id !=
                                           h.processing_session_id)
                       AND h.processing_session_id = USERENV ('SESSIONID'))
        LOOP
            BEGIN
                SAVEPOINT begin_header;
                l_ret_stat   := g_ret_success;

                FOR c_line
                    IN (SELECT l.adj_line_id, l.inventory_item_id, l.quantity_to_adjust,
                               l.subinventory_code, l.comments, l.adjusted_by,
                               l.reason_code, l.duty_paid_flag --Added as per ver 1.1
                          FROM xxdo.xxdo_wms_3pl_adj_l l
                         WHERE     l.adj_header_id = c_header.adj_header_id
                               AND l.process_status = 'P'
                               AND l.processing_session_id =
                                   USERENV ('SESSIONID'))
                LOOP
                    BEGIN
                        adjust_material (
                            p_organization_id     => c_header.organization_id,
                            p_inventory_item_id   => c_line.inventory_item_id,
                            p_quantity            => c_line.quantity_to_adjust,
                            p_transaction_date    => c_header.adjust_date,
                            p_subinventory        => c_line.subinventory_code,
                            p_source_header_id    => c_header.adj_header_id,
                            p_source_line_id      => c_line.adj_line_id,
                            p_trx_reference       => c_line.reason_code,
                            p_trx_comments        => c_line.comments,
                            p_duty_paid_flag      => c_line.duty_paid_flag,
                            --Added as per ver 1.1
                            x_ret_stat            => l_ret_stat,
                            x_message             => l_message);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg ('Outer Exception');
                            l_ret_stat   := g_ret_unexp_error;
                            l_message    := SQLERRM;
                    END;

                    IF l_ret_stat = g_ret_success
                    THEN
                        BEGIN
                            UPDATE xxdo.xxdo_wms_3pl_adj_l
                               SET process_status = 'S', error_message = 'Processing Complete'
                             WHERE adj_line_id = c_line.adj_line_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_ret_stat   := g_ret_error;
                                l_message    := SQLERRM;
                                msg ('Error Updating');
                        END;
                    END IF;

                    IF NVL (l_ret_stat, g_ret_unexp_error) != g_ret_success
                    THEN
                        msg ('Rolling Back');
                        ROLLBACK TO begin_header;

                        BEGIN
                            UPDATE xxdo.xxdo_wms_3pl_adj_h
                               SET process_status = 'E', error_message = 'One or more lines failed to process'
                             WHERE adj_header_id = c_header.adj_header_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;

                        BEGIN
                            UPDATE xxdo.xxdo_wms_3pl_adj_l
                               SET process_status = 'E', error_message = 'One or more lines failed to process'
                             WHERE adj_header_id = c_header.adj_header_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;

                        BEGIN
                            msg ('Error processing line: ' || l_message);

                            UPDATE xxdo.xxdo_wms_3pl_adj_l
                               SET process_status = 'E', error_message = SUBSTR ('Error processing line: ' || l_message, 1, 240)
                             WHERE adj_line_id = c_line.adj_line_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;
                    END IF;

                    EXIT WHEN l_ret_stat != g_ret_success;
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_ret_stat   := g_ret_unexp_error;
                    l_message    := SQLERRM;
            END;

            BEGIN
                IF l_ret_stat = g_ret_success
                THEN
                    UPDATE xxdo.xxdo_wms_3pl_adj_h
                       SET process_status = 'S', error_message = NULL
                     WHERE adj_header_id = c_header.adj_header_id;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            RAISE;
    END;

    --Start Added for CCR0009126
    --XPO Physical move -Locator Creation for Truck Sub Inventory
    PROCEDURE xpo_create_locator (p_organization_id NUMBER, p_subinv_to VARCHAR2, p_loc_segments VARCHAR2, p_comments VARCHAR2, x_locator_id OUT NUMBER, x_ret_status OUT VARCHAR2
                                  , x_message OUT VARCHAR2)
    IS
        --Variables Declaration
        ln_organization_id     mtl_parameters.organization_id%TYPE := NULL;
        lv_organization_code   mtl_parameters.organization_code%TYPE := NULL;
        lv_subinv_to           mtl_secondary_inventories.secondary_inventory_name%TYPE
            := NULL;
        lv_loc_segments        mtl_item_locations.descriptive_text%TYPE
                                   := NULL;
        lv_comments            mtl_item_locations.descriptive_text%TYPE
                                   := 'XPO-PHYSICAL MOVE';
        xv_msg_data            VARCHAR2 (1000);
        xn_msg_count           NUMBER;
        xv_ret_status          VARCHAR2 (1) := NULL;
        lx_message             VARCHAR2 (1000);
        lx_ret_status          VARCHAR2 (1) := NULL;
        xn_locator_id          NUMBER := NULL;
        xn_locator_exists      VARCHAR2 (1) := NULL;
    BEGIN
        lv_loc_segments      := p_loc_segments;
        lv_subinv_to         := p_subinv_to;
        ln_organization_id   := p_organization_id;

        --To fetch Organization Code
        BEGIN
            SELECT organization_code
              INTO lv_organization_code
              FROM mtl_parameters
             WHERE organization_id = p_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lx_ret_status   := g_ret_error;
                lx_message      :=
                       'Unable to retrieve Organization Code ('
                    || p_organization_id
                    || ')';
                msg (lx_message);
        END;

        inv_loc_wms_pub.create_locator (x_return_status => xv_ret_status, x_msg_count => xn_msg_count, x_msg_data => xv_msg_data, x_inventory_location_id => xn_locator_id, x_locator_exists => xn_locator_exists, p_organization_id => ln_organization_id, p_organization_code => lv_organization_code, p_concatenated_segments => lv_loc_segments, p_description => lv_comments, p_inventory_location_type => 3, -- Storage locator
                                                                                                                                                                                                                                                                                                                                                                                                                   p_picking_order => NULL, p_location_maximum_units => NULL, p_subinventory_code => lv_subinv_to, p_location_weight_uom_code => NULL, p_max_weight => NULL, p_volume_uom_code => NULL, p_max_cubic_area => NULL, p_x_coordinate => NULL, p_y_coordinate => NULL, p_z_coordinate => NULL, p_physical_location_id => NULL, p_pick_uom_code => NULL, p_dimension_uom_code => NULL, p_length => NULL, p_width => NULL, p_height => NULL, p_status_id => 1
                                        , -- Default status 'Active'
                                          p_dropping_order => NULL);
        x_ret_status         := xv_ret_status;
        x_message            := xv_msg_data;
        x_locator_id         := xn_locator_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_locator_id   := xn_locator_id;
            x_ret_status   := 'E';
            x_message      := xv_msg_data || SQLERRM;
    END;

    --End Added for CCR0009126
    PROCEDURE process_transfers
    IS
        l_ret_stat                VARCHAR2 (1);
        l_message                 VARCHAR2 (2000);
        --Added for CCR0009126
        ln_stg_line_cnt           NUMBER;
        ln_stg_eligble_cnt        NUMBER;
        ln_loc_seq_id             NUMBER;
        lv_to_subinventory_code   VARCHAR2 (50);
        lv_comments               VARCHAR2 (240);
        lv_loc_segment1           VARCHAR2 (50);
        lv_loc_segment5           VARCHAR2 (50);
        lv_loc_segments           VARCHAR2 (150);
        lv_seperator              VARCHAR2 (50);
        lx_locator_id             NUMBER;
        ln_loc_exists             NUMBER;
    BEGIN
        FOR c_header
            IN (SELECT h.tra_header_id, h.organization_id, h.xfer_date
                  FROM xxdo.xxdo_wms_3pl_tra_h h
                 WHERE     h.process_status = 'P'
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM xxdo.xxdo_wms_3pl_tra_l l2
                                 WHERE     l2.tra_header_id = h.tra_header_id
                                       AND l2.process_status != 'P')
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM xxdo.xxdo_wms_3pl_tra_l l2
                                 WHERE     l2.tra_header_id = h.tra_header_id
                                       AND l2.processing_session_id !=
                                           h.processing_session_id)
                       AND h.processing_session_id = USERENV ('SESSIONID'))
        LOOP
            BEGIN
                SAVEPOINT begin_header;
                l_ret_stat   := g_ret_success;

                --Start Added for CCR0009126
                --Fetch count of all lines in Staging
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_stg_line_cnt
                      FROM xxdo.xxdo_wms_3pl_tra_l l
                     WHERE     l.tra_header_id = c_header.tra_header_id
                           AND l.process_status = 'P'
                           AND l.processing_session_id =
                               USERENV ('SESSIONID');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_stg_line_cnt   := 0;
                END;

                --Fetch count of eligible lines for Locator Creation
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_stg_eligble_cnt
                      FROM xxdo.xxdo_wms_3pl_tra_l l
                     WHERE     l.tra_header_id = c_header.tra_header_id
                           AND l.to_lock_code = 'TRUCK'
                           AND l.process_status = 'P'
                           AND l.processing_session_id =
                               USERENV ('SESSIONID');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_stg_eligble_cnt   := 0;
                END;

                --IF Mismatch of All Lines with Eligible Locator Lines
                IF     NVL (ln_stg_line_cnt, 0) > 0
                   AND NVL (ln_stg_eligble_cnt, 0) > 0
                   AND (NVL (ln_stg_line_cnt, 0) <> NVL (ln_stg_eligble_cnt, 0))
                THEN
                    ROLLBACK TO begin_header;

                    --Locator validation fails, update error in staging
                    BEGIN
                        UPDATE xxdo.xxdo_wms_3pl_tra_h
                           SET process_status = 'E', error_message = 'Invalid Sub-Inventory Code for Physical Move'
                         WHERE tra_header_id = c_header.tra_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;

                    BEGIN
                        UPDATE xxdo.xxdo_wms_3pl_tra_l
                           SET process_status = 'E', error_message = 'Invalid Sub-Inventory Code for Physical Move for one or more lines'
                         WHERE tra_header_id = c_header.tra_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
                ELSIF     NVL (ln_stg_line_cnt, 0) > 0
                      --IF Eligible for Locator Creation
                      AND NVL (ln_stg_eligble_cnt, 0) > 0
                      AND (NVL (ln_stg_line_cnt, 0) = NVL (ln_stg_eligble_cnt, 0))
                THEN
                    BEGIN
                        --Get Locator Sequence
                        BEGIN
                            SELECT DISTINCT comments, 'TRUCK' to_subinventory_code
                              INTO lv_loc_segment1, lv_to_subinventory_code
                              FROM xxdo.xxdo_wms_3pl_tra_l l
                             WHERE     l.tra_header_id =
                                       c_header.tra_header_id
                                   AND l.to_lock_code = 'TRUCK'
                                   AND l.process_status = 'P'
                                   AND l.processing_session_id =
                                       USERENV ('SESSIONID');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_loc_segment1   := 'NOTRUCK';
                        END;

                        --To Generate locator segments
                        IF NVL (lv_loc_segment1, 'NOTRUCK') <> 'NOTRUCK'
                        THEN
                            lv_loc_segment5   := 1;
                            lv_seperator      := '.';
                            lv_comments       := lv_loc_segment1;

                            BEGIN
                                SELECT COUNT (1)
                                  INTO ln_loc_exists
                                  FROM mtl_item_locations
                                 WHERE     1 = 1
                                       AND organization_id =
                                           c_header.organization_id
                                       AND    segment1
                                           || '.'
                                           || segment2
                                           || '.'
                                           || segment3
                                           || '.'
                                           || segment4
                                           || '.'
                                           || segment5 =
                                              lv_loc_segment1
                                           || lv_seperator
                                           || lv_seperator
                                           || lv_seperator
                                           || lv_seperator
                                           || lv_loc_segment5
                                       AND subinventory_code = 'TRUCK';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_loc_exists   := 99;
                            END;

                            IF NVL (ln_loc_exists, 0) <> 0
                            THEN
                                l_ret_stat        := g_ret_unexp_error;
                                l_message         :=
                                    ' Locator Segment combination already exists in EBS ';
                                lv_loc_segments   := NULL;
                            ELSE
                                lv_loc_segments   :=
                                       lv_loc_segment1
                                    || lv_seperator
                                    || lv_seperator
                                    || lv_seperator
                                    || lv_seperator
                                    || lv_loc_segment5;
                            END IF;
                        ELSE
                            l_ret_stat   := g_ret_unexp_error;
                            l_message    :=
                                ' Locator Segments validation failure ';
                        END IF;

                        --For locator creation
                        IF l_ret_stat = g_ret_success
                        THEN
                            BEGIN
                                xpo_create_locator (p_organization_id => c_header.organization_id, p_subinv_to => lv_to_subinventory_code, p_loc_segments => lv_loc_segments, p_comments => lv_comments, x_locator_id => lx_locator_id, x_ret_status => l_ret_stat
                                                    , x_message => l_message);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_ret_stat   := g_ret_unexp_error;
                                    l_message    := SQLERRM;
                            END;
                        END IF;

                        IF l_ret_stat = g_ret_success
                        THEN
                            FOR c_line
                                IN (SELECT l.tra_line_id, l.inventory_item_id, l.quantity_to_transfer,
                                           l.from_subinventory_code, 'TRUCK' to_subinventory_code, l.reason_code,
                                           l.comments, l.to_lock_code, l.duty_paid_flag
                                      FROM xxdo.xxdo_wms_3pl_tra_l l
                                     WHERE     l.tra_header_id =
                                               c_header.tra_header_id
                                           AND l.process_status = 'P'
                                           AND l.processing_session_id =
                                               USERENV ('SESSIONID'))
                            LOOP
                                IF l_ret_stat = g_ret_success
                                THEN
                                    BEGIN
                                        NULL;
                                        adjust_material (
                                            p_organization_id   =>
                                                c_header.organization_id,
                                            p_inventory_item_id   =>
                                                c_line.inventory_item_id,
                                            p_quantity         =>
                                                c_line.quantity_to_transfer,
                                            p_transaction_date   =>
                                                c_header.xfer_date,
                                            p_subinventory     =>
                                                c_line.from_subinventory_code,
                                            p_secondary_subinventory   =>
                                                c_line.to_subinventory_code,
                                            p_locator_id       => lx_locator_id,
                                            --Added for CCR0009126
                                            p_source_header_id   =>
                                                c_header.tra_header_id,
                                            p_source_line_id   =>
                                                c_line.tra_line_id,
                                            p_trx_reference    =>
                                                c_line.reason_code,
                                            p_trx_comments     =>
                                                c_line.comments,
                                            p_duty_paid_flag   =>
                                                c_line.duty_paid_flag,
                                            --Added as per ver 1.1
                                            x_ret_stat         => l_ret_stat,
                                            x_message          => l_message);
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            l_ret_stat   := g_ret_unexp_error;
                                            l_message    := SQLERRM;
                                    END;
                                END IF;

                                IF l_ret_stat = g_ret_success
                                THEN
                                    BEGIN
                                        UPDATE xxdo.xxdo_wms_3pl_tra_l
                                           SET process_status = 'S', error_message = 'Processing Complete'
                                         WHERE tra_line_id =
                                               c_line.tra_line_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            l_ret_stat   := g_ret_error;
                                            l_message    := SQLERRM;
                                    END;
                                END IF;

                                IF NVL (l_ret_stat, g_ret_unexp_error) !=
                                   g_ret_success
                                THEN
                                    ROLLBACK TO begin_header;

                                    BEGIN
                                        UPDATE xxdo.xxdo_wms_3pl_tra_h
                                           SET process_status = 'E', error_message = 'One or more lines failed to process'
                                         WHERE tra_header_id =
                                               c_header.tra_header_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            NULL;
                                    END;

                                    BEGIN
                                        UPDATE xxdo.xxdo_wms_3pl_tra_l
                                           SET process_status = 'E', error_message = 'One or more lines failed to process'
                                         WHERE tra_header_id =
                                               c_header.tra_header_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            NULL;
                                    END;

                                    BEGIN
                                        UPDATE xxdo.xxdo_wms_3pl_tra_l
                                           SET process_status = 'E', error_message = SUBSTR ('Error processing line: ' || l_message, 1, 240)
                                         WHERE tra_line_id =
                                               c_line.tra_line_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            NULL;
                                    END;
                                END IF;

                                EXIT WHEN l_ret_stat != g_ret_success;
                            END LOOP;
                        ELSE
                            ROLLBACK TO begin_header;

                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_tra_h
                                   SET process_status = 'E', error_message = 'Locator Creation Failure -' || l_message
                                 WHERE tra_header_id = c_header.tra_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;

                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_tra_l
                                   SET process_status = 'E', error_message = 'Locator Creation Failure -' || l_message
                                 WHERE tra_header_id = c_header.tra_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_ret_stat   := g_ret_unexp_error;
                            l_message    := SQLERRM;
                    END;
                ELSE                          -- Non-Eligible Locator creation
                    --End Added for CCR0009126
                    --Not eligible for Locator creation, same as existing functiionality
                    BEGIN
                        SAVEPOINT begin_header;
                        l_ret_stat   := g_ret_success;

                        FOR c_line
                            IN (SELECT l.tra_line_id, l.inventory_item_id, l.quantity_to_transfer,
                                       l.from_subinventory_code, l.to_subinventory_code, l.reason_code,
                                       l.comments, l.duty_paid_flag --Added as per ver 1.1
                                  FROM xxdo.xxdo_wms_3pl_tra_l l
                                 WHERE     l.tra_header_id =
                                           c_header.tra_header_id
                                       AND l.process_status = 'P'
                                       AND l.processing_session_id =
                                           USERENV ('SESSIONID'))
                        LOOP
                            BEGIN
                                NULL;
                                adjust_material (p_organization_id => c_header.organization_id, p_inventory_item_id => c_line.inventory_item_id, p_quantity => c_line.quantity_to_transfer, p_transaction_date => c_header.xfer_date, p_subinventory => c_line.from_subinventory_code, p_secondary_subinventory => c_line.to_subinventory_code, p_source_header_id => c_header.tra_header_id, p_source_line_id => c_line.tra_line_id, p_trx_reference => c_line.reason_code, p_trx_comments => c_line.comments, p_duty_paid_flag => c_line.duty_paid_flag, --Added as per ver 1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           x_ret_stat => l_ret_stat
                                                 , x_message => l_message);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_ret_stat   := g_ret_unexp_error;
                                    l_message    := SQLERRM;
                            END;

                            IF l_ret_stat = g_ret_success
                            THEN
                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_tra_l
                                       SET process_status = 'S', error_message = 'Processing Complete'
                                     WHERE tra_line_id = c_line.tra_line_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_ret_stat   := g_ret_error;
                                        l_message    := SQLERRM;
                                END;
                            END IF;

                            IF NVL (l_ret_stat, g_ret_unexp_error) !=
                               g_ret_success
                            THEN
                                ROLLBACK TO begin_header;

                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_tra_h
                                       SET process_status = 'E', error_message = 'One or more lines failed to process'
                                     WHERE tra_header_id =
                                           c_header.tra_header_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;

                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_tra_l
                                       SET process_status = 'E', error_message = 'One or more lines failed to process'
                                     WHERE tra_header_id =
                                           c_header.tra_header_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;

                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_tra_l
                                       SET process_status = 'E', error_message = SUBSTR ('Error processing line: ' || l_message, 1, 240)
                                     WHERE tra_line_id = c_line.tra_line_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;
                            END IF;

                            EXIT WHEN l_ret_stat != g_ret_success;
                        END LOOP;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_ret_stat   := g_ret_unexp_error;
                            l_message    := SQLERRM;
                    END;
                END IF;                                 --Added for CCR0009126
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            BEGIN
                IF l_ret_stat = g_ret_success
                THEN
                    UPDATE xxdo.xxdo_wms_3pl_tra_h
                       SET process_status = 'S', error_message = NULL
                     WHERE tra_header_id = c_header.tra_header_id;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            RAISE;
    END;

    PROCEDURE update_itm_status (p_organization_id         NUMBER,
                                 x_ret_stat            OUT VARCHAR2,
                                 x_message             OUT VARCHAR2,
                                 p_inventory_item_id       NUMBER := NULL,
                                 p_confirmed_flag          VARCHAR2 := NULL)
    IS
        l_org_code   apps.mtl_parameters.organization_code%TYPE;
    BEGIN
        SELECT organization_code
          INTO l_org_code
          FROM apps.mtl_parameters
         WHERE organization_id = p_organization_id;

        IF p_inventory_item_id IS NULL
        THEN
            FOR rec
                IN (SELECT inventory_item_id, item_status
                      FROM xxdo.xxdo_edi_3pl_itm_lines_v
                     WHERE     organization_id = p_organization_id
                           AND inventory_item_id =
                               NVL (p_inventory_item_id, inventory_item_id)
                           AND NVL (item_status,
                                    TO_CHAR (USERENV ('SESSIONID'))) =
                               TO_CHAR (USERENV ('SESSIONID')))
            LOOP
                IF rec.item_status IS NULL
                THEN
                    INSERT INTO do_custom.do_items_repl (system_code,
                                                         inventory_item_id,
                                                         repl_date,
                                                         repl_by,
                                                         batch_name,
                                                         confirmed_flag)
                             VALUES (l_org_code,
                                     rec.inventory_item_id,
                                     SYSDATE,
                                     apps.fnd_global.user_id,
                                     USERENV ('SESSIONID'),
                                     NVL (p_confirmed_flag, 'N'));
                ELSE
                    UPDATE do_custom.do_items_repl
                       SET confirmed_flag   = NVL (p_confirmed_flag, 'N')
                     WHERE     system_code = l_org_code
                           AND inventory_item_id = rec.inventory_item_id;
                END IF;
            END LOOP;
        ELSE
            UPDATE do_custom.do_items_repl
               SET confirmed_flag   = NVL (p_confirmed_flag, 'N')
             WHERE     system_code = l_org_code
                   AND inventory_item_id = p_inventory_item_id;

            IF SQL%ROWCOUNT = 0
            THEN
                INSERT INTO do_custom.do_items_repl (system_code,
                                                     inventory_item_id,
                                                     repl_date,
                                                     repl_by,
                                                     batch_name,
                                                     confirmed_flag)
                         VALUES (l_org_code,
                                 p_inventory_item_id,
                                 SYSDATE,
                                 apps.fnd_global.user_id,
                                 USERENV ('SESSIONID'),
                                 NVL (p_confirmed_flag, 'N'));
            END IF;
        END IF;

        x_ret_stat   := g_ret_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_error;
            x_message    := SQLERRM;
    END;

    PROCEDURE create_container (p_delivery_id IN NUMBER, p_container_item_id IN NUMBER, p_container_name IN VARCHAR2
                                , x_container_instance_id OUT NUMBER, x_ret_stat OUT VARCHAR2, p_organization_id IN NUMBER-- Commented for BT := 7  Added IN
                                                                                                                          )
    IS
        l_pn          VARCHAR2 (200) := lg_package_name || '.create_container';
        hell          EXCEPTION;
        containers    wsh_util_core.id_tab_type;
        msg_count     NUMBER;
        msg_data      VARCHAR2 (2000);
        api_version   NUMBER := 1.0;
        segs          fnd_flex_ext.segmentarray;
        ret_stat      VARCHAR2 (1);
    BEGIN
        msg ('Start of ' || l_pn);
        fnd_msg_pub.initialize;
        wsh_container_pub.create_containers (p_api_version => api_version, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_false, p_validation_level => fnd_api.g_valid_level_full, x_return_status => x_ret_stat, x_msg_count => msg_count, x_msg_data => msg_data, p_container_item_id => p_container_item_id, p_container_item_name => NULL, p_container_item_seg => segs, p_organization_id => p_organization_id, p_organization_code => NULL, p_name_prefix => NULL, p_name_suffix => NULL, p_base_number => NULL, p_num_digits => NULL, p_quantity => 1, p_container_name => p_container_name
                                             , x_container_ids => containers);
        msg ('-----');
        msg ('Ret_stat: ' || x_ret_stat);
        msg ('msg_count: ' || msg_count);
        msg ('msg data: ' || msg_data);

        FOR j IN 1 .. fnd_msg_pub.count_msg
        LOOP
            msg_data   := fnd_msg_pub.get (j, 'F');
            msg_data   := REPLACE (msg_data, CHR (0), ' ');
            msg (msg_data);
        END LOOP;

        IF x_ret_stat <> fnd_api.g_ret_sts_success
        THEN
            RETURN;
        END IF;

        msg ('container count:' || containers.COUNT);

        FOR i IN 1 .. containers.COUNT
        LOOP
            x_container_instance_id   := containers (i);
            msg ('container id:' || containers (i));
            fnd_msg_pub.initialize;
            wsh_container_actions.update_cont_attributes (NULL, p_delivery_id, containers (i)
                                                          , ret_stat);
            msg ('update attributes ret_stat: ' || ret_stat);

            FOR j IN 1 .. fnd_msg_pub.count_msg
            LOOP
                msg_data   := fnd_msg_pub.get (j, 'F');
                msg_data   := REPLACE (msg_data, CHR (0), ' ');
                msg (msg_data);
            END LOOP;

            IF ret_stat <> fnd_api.g_ret_sts_success
            THEN
                x_ret_stat   := ret_stat;
                msg ('-' || l_pn);
                RETURN;
            END IF;

            fnd_msg_pub.initialize;
            wsh_container_actions.assign_to_delivery (containers (i),
                                                      p_delivery_id,
                                                      ret_stat);
            msg ('Container assign to delivery ret_stat: ' || ret_stat);

            FOR j IN 1 .. fnd_msg_pub.count_msg
            LOOP
                msg_data   := fnd_msg_pub.get (j, 'F');
                msg_data   := REPLACE (msg_data, CHR (0), ' ');
                msg (msg_data);
            END LOOP;

            IF ret_stat <> fnd_api.g_ret_sts_success
            THEN
                x_ret_stat   := ret_stat;
                msg ('-' || l_pn);
                RETURN;
            END IF;

            UPDATE wsh_delivery_details
               SET source_header_id   =
                       (SELECT source_header_id
                          FROM wsh_new_deliveries
                         WHERE delivery_id = p_delivery_id)
             WHERE delivery_detail_id = x_container_instance_id;
        END LOOP;

        msg ('-----');
        x_ret_stat   := fnd_api.g_ret_sts_success;
        msg ('End of ' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'EXP: Others- wsh_container_pub.create_containers- sqlerrm: '
                || SQLERRM);
            msg ('-----');
            x_ret_stat   := fnd_api.g_ret_sts_unexp_error;
            msg ('EXP: End of ' || l_pn || ' -  x_ret_stat :' || x_ret_stat);
    END;

    FUNCTION get_requested_quantity (p_delivery_detail_id IN NUMBER)
        RETURN NUMBER
    IS
        l_pn        VARCHAR2 (200) := lg_package_name || '.get_requested_quantity';
        requested   NUMBER;
    BEGIN
        msg ('Start of ' || l_pn);

        SELECT requested_quantity
          INTO requested
          FROM wsh_delivery_details
         WHERE delivery_detail_id = p_delivery_detail_id;

        RETURN requested;
        msg ('End of ' || l_pn);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            msg ('EXP: get_requested_quantity');
            RETURN 0;
        WHEN OTHERS
        THEN
            msg ('EXP: Others- get_requested_quantity');
            RETURN -1;
    END;

    PROCEDURE split_delivery_detail (p_delivery_detail_id IN NUMBER, p_x_split_quantity IN OUT NUMBER, x_new_delivery_detail_id OUT NUMBER
                                     , x_ret_stat OUT VARCHAR2)
    IS
        l_pn        VARCHAR2 (200) := lg_package_name || '.split_delivery_detail';
        msg_count   NUMBER;
        msg_data    VARCHAR2 (2000);
        dummy       NUMBER;
    BEGIN
        msg ('+' || l_pn);
        wsh_delivery_details_pub.split_line (
            p_api_version        => 1.0,
            p_init_msg_list      => fnd_api.g_false,
            p_commit             => fnd_api.g_false,
            p_validation_level   => fnd_api.g_valid_level_full,
            x_return_status      => x_ret_stat,
            x_msg_count          => msg_count,
            x_msg_data           => msg_data,
            p_from_detail_id     => p_delivery_detail_id,
            x_new_detail_id      => x_new_delivery_detail_id,
            x_split_quantity     => p_x_split_quantity,
            x_split_quantity2    => dummy);
        msg ('msg_count: ' || msg_count);
        msg (
            'msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 1, 100));
        msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 100, 100));
        msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 200, 100));
        msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 300, 100));
        msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 400, 100));
        msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 500, 100));
        msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 600, 100));
        msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 700, 100));
        msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 800, 100));
        msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 900, 100));

        FOR j IN 1 .. fnd_msg_pub.count_msg
        LOOP
            msg_data   := fnd_msg_pub.get (j, 'F');
            msg_data   := REPLACE (msg_data, CHR (0), ' ');
            msg (msg_data);
        END LOOP;

        msg ('-' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('sql errm: ' || SQLERRM);
            msg ('-----');
            x_ret_stat   := fnd_api.g_ret_sts_unexp_error;
            msg ('-' || l_pn);
    END;


    PROCEDURE process_delivery_line (p_delivery_detail_id       NUMBER,
                                     p_ship_qty                 NUMBER,
                                     p_ship_date                DATE,
                                     p_carrier                  VARCHAR2,
                                     p_carrier_code             VARCHAR2,
                                     p_shipping_method          VARCHAR2,
                                     p_tracking_number          VARCHAR2,
                                     x_retstat              OUT VARCHAR2)
    IS
        l_pn                 VARCHAR2 (200) := lg_package_name || '.process_delivery_line';
        changed_attributes   wsh_delivery_details_pub.changedattributetabtype;
        retstat              VARCHAR2 (1);
        msgcount             NUMBER;
        msgdata              VARCHAR2 (2000);
        l_message            VARCHAR2 (2000);
        l_message1           VARCHAR2 (2000);
        iid                  NUMBER;
        l_carrier_code       VARCHAR2 (100);
        l_ship_method_code   VARCHAR2 (100);
    BEGIN
        msg ('Start of ' || l_pn);
        msg ('delivery_detail_id = ' || TO_CHAR (p_delivery_detail_id));
        changed_attributes (1).delivery_detail_id     := p_delivery_detail_id;
        --changed_attributes (1).date_scheduled := p_ship_date; -- Raja
        --Added by CC for Canada 3PL Phase-3
        --changed_attributes (1).freight_carrier_code := p_carrier;
        ----Added by CC for Canada Retail and Ecomm
        changed_attributes (1).freight_carrier_code   :=
            NVL (p_carrier, p_carrier_code);
        changed_attributes (1).tracking_number        :=
            TRIM (p_tracking_number);
        --08/26/2003 - KWG  Trim for searching performance
        changed_attributes (1).shipped_quantity       := p_ship_qty;
        msg ('before select');

        SELECT source_line_id, organization_id, requested_quantity - p_ship_qty,
               inventory_item_id, ship_method_code
          INTO changed_attributes (1).source_line_id, changed_attributes (1).ship_from_org_id, changed_attributes (1).cycle_count_quantity, iid,
                                                    l_ship_method_code
          FROM wsh_delivery_details
         WHERE delivery_detail_id = p_delivery_detail_id;

        FOR i IN 1 .. changed_attributes.COUNT
        LOOP
            msg (
                   'SKU: '
                || iid_to_sku (iid)
                || ' DDID: '
                || TO_CHAR (changed_attributes (1).delivery_detail_id)
                || ' Requested: '
                || TO_CHAR (
                         changed_attributes (1).shipped_quantity
                       + changed_attributes (1).cycle_count_quantity)
                || ' Shipped: '
                || TO_CHAR (changed_attributes (1).shipped_quantity)
                || ' Cycle_count: '
                || TO_CHAR (changed_attributes (1).cycle_count_quantity)
                || ' Ship Method Code: '
                || l_ship_method_code);
        END LOOP;

        msg ('before update_shipping_attributes');

        ----Added by CC for Canada Retail and Ecomm
        IF p_carrier_code IS NOT NULL
        THEN
            BEGIN
                UPDATE apps.wsh_new_deliveries
                   SET attribute2   = TRIM (p_carrier_code)
                 WHERE delivery_id =
                       (SELECT DISTINCT delivery_id
                          FROM apps.wsh_delivery_assignments
                         WHERE     delivery_detail_id = p_delivery_detail_id
                               AND delivery_id IS NOT NULL);

                msg ('Carrier SCAC updated in WND');
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        wsh_delivery_details_pub.update_shipping_attributes (
            p_api_version_number   => 1.0,
            p_init_msg_list        => NULL,
            p_commit               => NULL,
            x_return_status        => retstat,
            x_msg_count            => msgcount,
            x_msg_data             => msgdata,
            p_changed_attributes   => changed_attributes,
            p_source_code          => 'OE');

        BEGIN
            msg (
                   'wsh_delivery_details_pub.update_shipping_attributes - retstat: '
                || retstat);
            msg ('Message count: ' || msgcount);

            FOR i IN 1 .. NVL (msgcount, 5)
            LOOP
                l_message   := fnd_msg_pub.get (i, 'F');
                l_message   := REPLACE (l_message, CHR (0), ' ');
                msg (
                       'Exp - wsh_delivery_details_pub.update_shipping_attributes : '
                    || SUBSTR (l_message, 1, 200));

                IF (i = 1)
                THEN
                    l_message1   := l_message;
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'EXP: wsh_delivery_details_pub.update_shipping_attributes - Error : '
                    || SQLERRM);
        END;

        fnd_msg_pub.delete_msg ();
        x_retstat                                     := retstat;
        msg ('-' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP: Ohers - process_delivery_line - Error: ' || SQLERRM);
            x_retstat   := 'U';
            msg ('End of ' || l_pn);
    END;

    PROCEDURE process_delivery_line (p_delivery_detail_id NUMBER, p_ship_date DATE, p_carrier VARCHAR2, p_carrier_code VARCHAR2, p_shipping_method VARCHAR2, p_tracking_number VARCHAR2
                                     , x_retstat OUT VARCHAR2)
    IS
        l_pn                 VARCHAR2 (200) := lg_package_name || '.process_delivery_line';
        changed_attributes   wsh_delivery_details_pub.changedattributetabtype;
        retstat              VARCHAR2 (1);
        msgcount             NUMBER;
        msgdata              VARCHAR2 (2000);
        l_message            VARCHAR2 (2000);
        l_message1           VARCHAR2 (2000);
        iid                  NUMBER;
    BEGIN
        msg ('Start of 2nd ' || l_pn);
        msg ('delivery_detail_id = ' || TO_CHAR (p_delivery_detail_id));
        changed_attributes (1).delivery_detail_id   := p_delivery_detail_id;
        changed_attributes (1).date_scheduled       := p_ship_date;

        IF NVL (p_carrier, p_carrier_code) <> g_miss_char
        THEN
            ----Added by CC for Canada 3PL Phase-3
            --changed_attributes (1).freight_carrier_code := p_carrier;
            changed_attributes (1).freight_carrier_code   :=
                NVL (p_carrier, p_carrier_code);
        --Changes completed
        END IF;

        ----Added by CC for Canada 3PL Phase-3
        --      IF p_shipping_method <> g_miss_char
        --      THEN
        --         changed_attributes (1).shipping_method_code := p_shipping_method;
        --      END IF;
        --Changes completed
        IF p_tracking_number <> g_miss_char
        THEN
            changed_attributes (1).tracking_number   :=
                TRIM (p_tracking_number);
        END IF;

        msg ('before select');

        FOR i IN 1 .. changed_attributes.COUNT
        LOOP
            msg (
                   'SKU: '
                || iid_to_sku (iid)
                || ' DDID: '
                || TO_CHAR (changed_attributes (1).delivery_detail_id));
        END LOOP;

        ----Added by CC for Canada 3PL Phase-3
        IF p_carrier_code IS NOT NULL
        THEN
            BEGIN
                UPDATE wsh_new_deliveries
                   SET attribute2   = TRIM (p_carrier_code)
                 WHERE delivery_id =
                       (SELECT DISTINCT delivery_id
                          FROM apps.wsh_delivery_assignments
                         WHERE     delivery_detail_id = p_delivery_detail_id
                               AND delivery_id IS NOT NULL);

                msg ('Carrier SCAC updated in WND');
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        --Changes completed
        msg ('before update_shipping_attributes');
        wsh_delivery_details_pub.update_shipping_attributes (
            p_api_version_number   => 1.0,
            p_init_msg_list        => NULL,
            p_commit               => NULL,
            x_return_status        => retstat,
            x_msg_count            => msgcount,
            x_msg_data             => msgdata,
            p_changed_attributes   => changed_attributes,
            p_source_code          => 'OE');

        BEGIN
            msg ('update_shipping_attributes api -retstat: ' || retstat);
            msg ('Message count: ' || msgcount);

            FOR i IN 1 .. NVL (msgcount, 5)
            LOOP
                l_message   := fnd_msg_pub.get (i, 'F');
                l_message   := REPLACE (l_message, CHR (0), ' ');
                msg ('Error message: ' || SUBSTR (l_message, 1, 200));

                IF (i = 1)
                THEN
                    l_message1   := l_message;
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Error loop Unexp Error message: ' || SQLERRM);
        END;

        fnd_msg_pub.delete_msg ();
        x_retstat                                   := retstat;
        msg ('-' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP: Others - End of 2nd ' || l_pn || 'Error -' || SQLERRM);
            x_retstat   := 'U';
            msg ('End of 2nd ' || l_pn);
    END;

    PROCEDURE split_shipments (p_shipments IN shipment_tab, p_carrier IN VARCHAR2, p_carrier_code VARCHAR2, p_shipping_method VARCHAR2, p_tracking_no IN VARCHAR2, p_shipment_date IN DATE
                               , x_delivery_ids OUT wsh_util_core.id_tab_type, x_ret_stat OUT VARCHAR2)
    IS
        l_pn                   VARCHAR2 (200) := lg_package_name || '.split_shipments';
        ret_stat               VARCHAR2 (1);
        qty                    NUMBER;
        split_line_failure     EXCEPTION;
        process_line_failure   EXCEPTION;
    BEGIN
        msg ('Start of ' || l_pn);

        FOR i IN 1 .. p_shipments.COUNT
        LOOP
            IF p_shipments (i).quantity >=
               get_requested_quantity (p_shipments (i).delivery_detail_id)
            THEN
                qty                  := p_shipments (i).quantity;
                x_delivery_ids (i)   := p_shipments (i).delivery_detail_id;
                msg ('took old delivery_id');
            ELSE
                qty          := p_shipments (i).quantity;
                msg (
                       'Need to Create new delivery_id  for '
                    || p_shipments (i).quantity
                    || ' units ');
                split_delivery_detail (p_shipments (i).delivery_detail_id, qty, x_delivery_ids (i)
                                       , ret_stat);
                x_ret_stat   := ret_stat;
                msg ('New delivery_id :' || x_delivery_ids (i));

                IF NVL (ret_stat, g_ret_error) <>
                   apps.fnd_api.g_ret_sts_success
                THEN
                    RAISE split_line_failure;
                END IF;
            END IF;

            process_delivery_line (x_delivery_ids (i), qty, p_shipment_date,
                                   p_carrier, p_carrier_code, p_shipping_method
                                   , p_tracking_no, ret_stat);
            x_ret_stat   := ret_stat;

            IF NVL (ret_stat, g_ret_error) <> apps.fnd_api.g_ret_sts_success
            THEN
                RAISE process_line_failure;
            END IF;
        END LOOP;

        msg ('End of ' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_unexp_error;
            msg ('EXP: Others -split_shipments - Error :' || x_ret_stat);
            msg ('End of ' || l_pn);
            RETURN;
    END;

    --Start Added for 1.12
    --Orgin Hub Split Shipments
    PROCEDURE origin_hub_split_shipments (p_shipments IN shipment_tab, p_carrier IN VARCHAR2, p_carrier_code IN VARCHAR2, p_shipping_method IN VARCHAR2, p_tracking_no IN VARCHAR2, p_shipment_date IN DATE
                                          , x_delivery_ids OUT wsh_util_core.id_tab_type, x_ret_stat OUT VARCHAR2, p_split_flag OUT VARCHAR2)
    IS
        l_pn                    VARCHAR2 (200)
                                    := lg_package_name || '.origin_hub_split_shipments';
        ret_stat                VARCHAR2 (1);
        qty                     NUMBER;
        split_line_failure      EXCEPTION;
        process_line_failure    EXCEPTION;
        mo_lines                inv_move_order_pub.trolin_tbl_type;
        ln_move_order_line_id   NUMBER;
    BEGIN
        p_split_flag   := 'N';

        msg ('p_shipments.count : ' || p_shipments.COUNT);

        FOR i IN 1 .. p_shipments.COUNT
        LOOP
            msg (
                   'p_shipments(i).delivery_detail_id : '
                || p_shipments (i).delivery_detail_id);

            IF p_shipments (i).quantity >=
               get_requested_quantity (p_shipments (i).delivery_detail_id)
            THEN
                qty                  := p_shipments (i).quantity;
                x_delivery_ids (i)   := p_shipments (i).delivery_detail_id;

                msg ('SPLIT not required, Only pick confirm process');
                msg ('took old delivery_id');

                BEGIN
                    SELECT mtrl.line_id
                      INTO ln_move_order_line_id
                      FROM wsh_delivery_details wdd, mtl_txn_request_lines mtrl
                     WHERE     1 = 1
                           AND wdd.source_code = 'OE'
                           AND wdd.released_status = 'S'
                           AND wdd.delivery_detail_id =
                               p_shipments (i).delivery_detail_id
                           AND wdd.source_line_id = mtrl.txn_source_line_id
                           AND wdd.move_order_line_id = mtrl.line_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_move_order_line_id   := NULL;
                        msg (
                               'EXP: move_order_line_id : '
                            || ln_move_order_line_id);
                END;

                msg ('move_order_line_id : ' || ln_move_order_line_id);
                mo_lines             :=
                    inv_trolin_util.query_rows (
                        p_line_id => ln_move_order_line_id);
                msg (
                    'mo_lines.COUNT before pick confirm : ' || mo_lines.COUNT);

                msg ('pick confirm start ');

                IF pick_confirm (mo_lines) = FALSE
                THEN
                    msg ('Failed to pick confirm');
                --    RETURN fnd_api.g_ret_sts_error;
                END IF;

                msg ('pick confirm end ');
            ELSE
                qty            := p_shipments (i).quantity;
                msg ('SPLIT required, Partial pick_confirm process');
                msg (
                       'Need to Create new delivery_id  for quantity '
                    || p_shipments (i).quantity
                    || ' units ');
                /*split_delivery_detail (p_shipments (i).delivery_detail_id,
                                   qty,
                                   x_delivery_ids (i),
                                   ret_stat
                                  );*/


                --Calling procedure for Partial Pick Confirm by Split line
                msg ('Partial Pick Confirm by Split line start ');
                partail_pick_confirm (p_delivery_detail_id => p_shipments (i).delivery_detail_id, p_quantity => qty, x_delivery_detail_id => x_delivery_ids (i)
                                      , x_status => ret_stat);
                msg ('Partail_pick_confirm- Return status :' || ret_stat);
                msg ('Partial Pick Confirm by Split line end ');

                x_ret_stat     := ret_stat;
                p_split_flag   := 'Y';

                IF NVL (ret_stat, g_ret_error) <>
                   apps.fnd_api.g_ret_sts_success
                THEN
                    RAISE split_line_failure;
                END IF;
            END IF;
        /* process_delivery_line (x_delivery_ids (i),
           qty,
        p_shipment_date,
        p_carrier,
        p_carrier_code,
        p_shipping_method,
        p_tracking_no,
        ret_stat
        );*/
         /*  --RECHECK
         x_ret_stat := ret_stat;
         IF nvl(ret_stat, g_ret_error) <> apps.fnd_api.g_ret_sts_success
THEN
             RAISE process_line_failure;
         END IF;
*/

        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_unexp_error;
            msg ('EXP: Others in ' || l_pn || ' -SQLERRM : ' || SQLERRM);
            RETURN;
    END;

    --End Added for 1.12

    PROCEDURE pack_into_container (p_delivery_id IN NUMBER, p_container_id IN NUMBER, p_delivery_ids IN wsh_util_core.id_tab_type
                                   , x_ret_stat OUT VARCHAR2)
    IS
        l_pn          VARCHAR2 (200) := lg_package_name || '.pack_into_container';
        pack_status   VARCHAR2 (2000);
        msg_count     NUMBER;
        msg_data      VARCHAR2 (4000);
    BEGIN
        msg ('Start of ' || l_pn);
        fnd_msg_pub.initialize;
        msg ('Trying to pack into container id: ' || p_container_id);
        msg ('delivery_id: ' || p_delivery_id);

        FOR i IN 1 .. p_delivery_ids.COUNT
        LOOP
            msg ('delivery_detail_id (' || i || '): ' || p_delivery_ids (i));
        END LOOP;

        wsh_container_pub.container_actions (
            p_api_version        => 1.0,
            p_init_msg_list      => fnd_api.g_false,
            p_commit             => fnd_api.g_false,
            p_validation_level   => fnd_api.g_valid_level_full,
            x_return_status      => x_ret_stat,
            x_msg_count          => msg_count,
            x_msg_data           => msg_data,
            p_detail_tab         => p_delivery_ids,
            p_container_name     => NULL,
            p_cont_instance_id   => p_container_id,
            p_container_flag     => 'N',
            p_delivery_flag      => 'N',
            p_delivery_id        => p_delivery_id,
            p_delivery_name      => NULL,
            p_action_code        => 'PACK');
        msg ('pack container status: ' || pack_status);
        msg ('msg_count: ' || msg_count);

        /* msg ('msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 1, 100));
         msg ('msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 100, 100));
         msg ('msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 200, 100));
         msg ('msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 300, 100));
         msg ('msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 400, 100));
         msg ('msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 500, 100));
         msg ('msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 600, 100));
         msg ('msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 700, 100));
         msg ('msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 800, 100));
         msg ('msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 900, 100));*/

        FOR j IN 1 .. fnd_msg_pub.count_msg
        LOOP
            msg_data   := fnd_msg_pub.get (j, 'F');
            msg_data   := REPLACE (msg_data, CHR (0), ' ');
            msg (msg_data);
        END LOOP;

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_into_container, API Message: '||msg_data);
        msg ('End of ' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('sql errm: ' || SQLERRM);
            msg ('-----');
            x_ret_stat   := fnd_api.g_ret_sts_unexp_error;
            msg ('EXP: Others in ' || l_pn);
    END;

    PROCEDURE process_delivery_freight (p_delivery_id              NUMBER,
                                        p_freight_charge           NUMBER,
                                        p_carrier_code             VARCHAR2,
                                        p_freight_charges          NUMBER,
                                        p_delivery_detail_id       NUMBER,
                                        p_carrier                  VARCHAR2,
                                        p_shipping_method          VARCHAR2,
                                        x_retstat              OUT VARCHAR2)
    IS
        l_pn                     VARCHAR2 (200)
                                     := lg_package_name || '.process_delivery_freight';
        v_header_id              NUMBER;
        cust_flag                VARCHAR2 (1);
        order_type_flag          VARCHAR2 (1);
        carrier                  VARCHAR2 (1) := 'Y';
        freight                  wsh_freight_costs_pub.pubfreightcostrectype;
        retstat                  VARCHAR2 (1);
        msgcount                 NUMBER;
        msgdata                  VARCHAR2 (2000);
        l_message                VARCHAR2 (2000);
        l_message1               VARCHAR2 (2000);
        l_curr_code              VARCHAR2 (10);
        l_freight_applied        VARCHAR2 (1);
        ln_freight_overide_cnt   NUMBER;      -- ver 1.13 Added for CCR0009446
    BEGIN
        msg ('Start of ' || l_pn);

        SELECT MAX (wdd.source_header_id)
          INTO v_header_id
          FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
         WHERE     wda.delivery_id = p_delivery_id
               AND wdd.delivery_detail_id = wda.delivery_detail_id
               AND wdd.container_flag = 'N';

        --      BEGIN
        --         SELECT TRIM (nvl(attribute1, 'Y'))
        --           INTO carrier
        --           FROM org_freight f, apps.org_organization_definitions o
        --          WHERE     o.organization_id = f.organization_id
        --                AND freight_code = NVL (p_carrier, p_carrier_code)
        --                AND o.organization_code =
        --                       fnd_profile.VALUE ('XXDO: ORGANIZATION CODE'); --'VNT';
        -- Start ver 1.13 changes for CCR0009446  comment below sql
        /*
                 SELECT TRIM (NVL (wcsd.freight_charge_flag, 'Y'))
                   INTO carrier
                   FROM apps.wsh_carrier_services wcs,
                        apps.wsh_carrier_services_dfv wcsd
                  WHERE wcs.ship_method_code = p_shipping_method
                    AND wcs.ROWID = wcsd.ROWID;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    carrier := 'Y';
              END; */
        -- end ver 1.13 changes for CCR0009446  comment  sql

        -- begin ver 1.13
        BEGIN
            SELECT SUBSTR (wcs.attribute3, 1, 1)
              INTO carrier
              FROM apps.wsh_carrier_services wcs, apps.wsh_carrier_services_dfv wcsd
             WHERE     wcs.ship_method_code = p_shipping_method
                   AND wcs.ROWID = wcsd.ROWID;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                carrier   := 'Y';
        END;

        -- Restict Freight Application when there is already a surchare applied

        BEGIN
            SELECT COUNT (opa.header_id)
              INTO ln_freight_overide_cnt
              FROM apps.fnd_lookup_values flv, apps.oe_price_adjustments_v opa
             WHERE     flv.lookup_type = 'XXD_ONT_FREIGHT_MOD_EXCLUSION'
                   AND flv.language = 'US'
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute1 = opa.list_header_id
                   AND opa.header_id = v_header_id
                   AND opa.operand <> 0
                   AND opa.adjustment_type_code = 'FREIGHT_CHARGE'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.start_date_active)
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE));
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_freight_overide_cnt   := 0;
        END;

        -- end ver 1.13

        BEGIN
            SELECT SUBSTR (rc.attribute6, 1, 1), oh.transactional_curr_code
              INTO cust_flag, l_curr_code
              FROM ra_customers rc, oe_order_headers_all oh
             WHERE     rc.customer_id = oh.sold_to_org_id
                   AND oh.header_id = v_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                cust_flag   := 'N';
        END;

        BEGIN
            SELECT NVL (ott.attribute4, 'N')
              INTO order_type_flag
              FROM oe_transaction_types_all ott, oe_order_headers_all oh
             WHERE     ott.transaction_type_id = oh.order_type_id
                   AND oh.header_id = v_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                order_type_flag   := 'N';
        END;

        -- Check to see if we've already applied freight for this delivery
        l_freight_applied           := 'N';

        BEGIN
            SELECT 'Y'
              INTO l_freight_applied
              FROM wsh_freight_costs wfc
             WHERE wfc.delivery_id = p_delivery_id AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_freight_applied   := 'N';
        END;

        IF (l_freight_applied = 'Y' OR cust_flag = 'Y' OR order_type_flag = 'Y' OR carrier = 'N' OR (p_freight_charge = 0 AND p_freight_charges = 0) OR ln_freight_overide_cnt <> 0) --Added per ver 1.13
        THEN
            x_retstat   := 'S';
            msg ('Start of ' || l_pn);
            RETURN;
        END IF;

        freight.currency_code       := NVL (l_curr_code, 'USD');
        freight.action_code         := 'CREATE';
        freight.delivery_id         := p_delivery_id;
        freight.attribute1          := TO_CHAR (p_delivery_detail_id);
        --freight.freight_cost_type_id := 1;
        freight.freight_cost_type   := 'Shipping';

        --Added by CC for Canada 3PL Phase-3
        IF p_freight_charges IS NOT NULL OR p_freight_charges <> 0
        THEN
            freight.unit_amount   := p_freight_charges;
        ELSE
            freight.unit_amount   := p_freight_charge;
        END IF;

        BEGIN
            SELECT freight_cost_type_id
              INTO freight.freight_cost_type_id
              FROM apps.wsh_freight_cost_types
             WHERE freight_cost_type_code = 'FREIGHT' AND NAME = 'Shipping';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                freight.freight_cost_type_id   := 1;
        END;

        --Changes completed
        UPDATE oe_order_lines_all
           SET calculate_price_flag   = 'Y'
         WHERE line_id IN
                   (SELECT source_line_id
                      FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
                     WHERE     wda.delivery_id = p_delivery_id
                           AND wdd.delivery_detail_id =
                               wda.delivery_detail_id
                           AND wdd.container_flag = 'N');

        msg (
               'Charging freight: '
            || freight.unit_amount
            || ' for delivery_id: '
            || freight.delivery_id
            || ' on delivery_detail_id: '
            || freight.delivery_detail_id,
            1000);
        apps.wsh_freight_costs_pub.create_update_freight_costs (
            p_api_version_number   => 1.0,
            p_init_msg_list        => NULL,
            p_commit               => NULL,
            x_return_status        => retstat,
            x_msg_count            => msgcount,
            x_msg_data             => msgdata,
            p_pub_freight_costs    => freight,
            p_action_code          => 'CREATE',
            x_freight_cost_id      => freight.freight_cost_type_id);

        FOR i IN 1 .. msgcount + 10
        LOOP
            l_message   := fnd_msg_pub.get (i, 'F');
            l_message   := REPLACE (l_message, CHR (0), ' ');
            msg ('Error message: ' || SUBSTR (l_message, 1, 200), 100);

            IF (i = 1)
            THEN
                l_message1   := l_message;
            END IF;
        END LOOP;

        fnd_msg_pub.delete_msg ();
        x_retstat                   := retstat;
        msg ('End of ' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP: Others - Error: ' || SQLERRM, 100);
            x_retstat   := 'U';
            msg ('EXP: Others in ' || l_pn);
    END;

    PROCEDURE process_container_tracking (
        p_delivery_detail_id       NUMBER,
        p_tracking_number          VARCHAR2,
        p_container_weight         NUMBER,
        p_carrier                  VARCHAR2,
        x_retstat              OUT VARCHAR2)
    IS
        l_pn      VARCHAR2 (200)
                      := lg_package_name || '.process_container_tracking';
        retstat   VARCHAR2 (1);
    BEGIN
        msg ('Start of ' || l_pn);
        msg ('delivery_detail_id = ' || TO_CHAR (p_delivery_detail_id));

        UPDATE wsh_delivery_details
           SET tracking_number = TRIM (p_tracking_number), net_weight = p_container_weight
         WHERE delivery_detail_id = p_delivery_detail_id;

        x_retstat   := 'S';
        msg ('End of ' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP: Others- tracking_number Error: ' || SQLERRM);
            x_retstat   := 'U';
            msg ('EXP: Others in ' || l_pn);
    END;

    --START Added as per ver 1.1
    PROCEDURE upd_duty_paid_flag (p_osc_header_id   IN     NUMBER,
                                  x_ret_stat           OUT VARCHAR2)
    IS
        lx_ret_stat      VARCHAR2 (1) := NULL;
        ln_delivery_id   NUMBER;
    BEGIN
        msg ('In the procedure upd_duty_paid_flag');

        FOR c_line_upd
            IN (  SELECT l.source_line_id, l.duty_paid_flag
                    FROM xxdo.xxdo_wms_3pl_osc_l l
                   WHERE     l.osc_header_id = p_osc_header_id
                         AND l.process_status IN ('P', 'S')
                         AND l.duty_paid_flag IS NOT NULL
                         AND NOT EXISTS
                                 (SELECT NULL
                                    FROM xxdo.xxdo_wms_3pl_osc_h h
                                   WHERE     h.osc_header_id = l.osc_header_id
                                         AND h.processing_session_id !=
                                             l.processing_session_id)
                --AND l.processing_session_id = USERENV('SESSIONID')
                ORDER BY l.source_line_id)
        LOOP
            BEGIN
                UPDATE apps.wsh_delivery_details
                   SET attribute12   = c_line_upd.duty_paid_flag
                 WHERE     1 = 1
                       AND source_code = 'OE'
                       AND source_line_id = c_line_upd.source_line_id;
            --COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP: Others in upd_duty_paid_flag: ' || SQLERRM);
            lx_ret_stat   := 'U';
            x_ret_stat    := lx_ret_stat;
    END upd_duty_paid_flag;

    --END Added as per ver 1.1

    --Added for Canada Retail and Ecomm Project
    PROCEDURE process_shipping_details (p_delivery_id IN NUMBER, p_shipping_method IN VARCHAR2, x_ret_stat OUT VARCHAR2)
    IS
        lv_ship_method_code   VARCHAR2 (100);
        lv_service_level      VARCHAR2 (100);
        ln_carrier_id         NUMBER;
        -----
        lt_delivery_info      wsh_deliveries_pub.delivery_pub_rec_type;
        lv_return_status      VARCHAR2 (200);
        ln_msg_count          NUMBER;
        lv_msg_data           VARCHAR2 (2000);
        ln_delivery_id        NUMBER;
        lv_name               VARCHAR2 (100);
        lv_msg_details        VARCHAR2 (3000);
        lv_msg_summary        VARCHAR2 (3000);
    BEGIN
        msg ('In the procedure process_shipping_details');

        /* Get the carrier details*/
        BEGIN
            SELECT ship_method_code, carrier_id, service_level
              INTO lv_ship_method_code, ln_carrier_id, lv_service_level
              FROM apps.wsh_carrier_services
             WHERE     enabled_flag = 'Y'
                   AND ship_method_code = p_shipping_method;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        IF p_shipping_method IS NOT NULL
        THEN
            /* Update Delivery Attributes */
            lt_delivery_info.delivery_id        := p_delivery_id;
            lt_delivery_info.NAME               := TO_CHAR (p_delivery_id);
            lt_delivery_info.ship_method_code   := p_shipping_method;
            lt_delivery_info.carrier_id         := ln_carrier_id;
            lt_delivery_info.service_level      := lv_service_level;
            wsh_deliveries_pub.create_update_delivery (p_api_version_number => 1.0, p_init_msg_list => fnd_api.g_true, x_return_status => lv_return_status, x_msg_count => ln_msg_count, x_msg_data => lv_msg_data, p_action_code => 'UPDATE', p_delivery_info => lt_delivery_info, p_delivery_name => TO_CHAR (p_delivery_id), x_delivery_id => ln_delivery_id
                                                       , x_name => lv_name);
            x_ret_stat                          := lv_return_status;

            IF lv_return_status <> 'S'
            THEN
                wsh_util_core.get_messages ('Y', lv_msg_summary, lv_msg_details
                                            , ln_msg_count);
                lv_msg_summary   := lv_msg_summary || ' ' || lv_msg_details;
                msg (
                       'API Error while updating the Delivey: '
                    || lv_msg_summary);
            ELSE
                msg ('Delivery: ' || p_delivery_id || ' Updated Successful');

                BEGIN
                    UPDATE apps.wsh_delivery_details
                       SET ship_method_code = p_shipping_method, carrier_id = ln_carrier_id, service_level = lv_service_level
                     WHERE delivery_detail_id IN
                               (SELECT delivery_detail_id
                                  FROM apps.wsh_delivery_assignments
                                 WHERE delivery_id = p_delivery_id);
                --COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            END IF;
        END IF;                                    --End for p_shipping_method
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := 'U';
            msg (
                   'EXP: Others -process_shipping_details- x_ret_stat: '
                || x_ret_stat);
            msg (
                   'EXP: Others -process_shipping_details- Unexp Error: '
                || SQLERRM);
    END;

    PROCEDURE pack_container (p_delivery_id IN NUMBER, p_osc_hdr_id IN NUMBER, --Added as per ver 1.1
                                                                               p_container_name IN VARCHAR2, p_shipments IN shipment_tab, p_freight_cost IN NUMBER, p_container_weight IN NUMBER, p_tracking_number IN VARCHAR2, p_carrier IN VARCHAR2, p_carrier_code IN VARCHAR2, p_shipping_method IN VARCHAR2, p_freight_charges IN NUMBER, p_shipment_date IN DATE, x_container_id OUT NUMBER, x_ret_stat OUT VARCHAR2, p_organization_id IN NUMBER
                              , p_delivery_ids IN wsh_util_core.id_tab_type --Added For 1.12
                                                                           --:= 7  -- Commented for BT Added IN
                                                                           )
    IS
        l_pn                          VARCHAR2 (200) := lg_package_name || '.pack_container';
        ret_stat                      VARCHAR2 (1);
        lx_ret_stat                   VARCHAR2 (1);
        g_container_item_id           NUMBER := 160489;
        container_id                  NUMBER;
        delivery_ids                  wsh_util_core.id_tab_type;
        junk                          wsh_util_core.id_tab_type;
        create_container_failure      EXCEPTION;
        split_shipments_failure       EXCEPTION;
        pack_into_container_failure   EXCEPTION;
        process_freight_failure       EXCEPTION;
        process_tracking_failure      EXCEPTION;
        --Added for Canada Retail and Ecomm Project
        process_shipping_failure      EXCEPTION;
        l_requested_quantity          NUMBER;                 --Added For 1.12

        CURSOR headers (p2_delivery_id NUMBER)
        IS
            SELECT DISTINCT wdd.source_header_id
              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
             WHERE     wda.delivery_id = p2_delivery_id
                   AND wdd.delivery_detail_id = wda.delivery_detail_id;

        temp                          BOOLEAN;
    BEGIN
        msg ('Start of ' || l_pn);
        wsh_delivery_autocreate.autocreate_deliveries (
            p_line_rows           => junk,
            p_init_flag           => 'N',
            p_pick_release_flag   => 'N',
            p_container_flag      => 'Y',
            p_check_flag          => 'Y',
            p_max_detail_commit   => 1000,
            x_del_rows            => junk,
            x_grouping_rows       => junk,
            x_return_status       => ret_stat);
        ret_stat         := NULL;
        create_container (p_delivery_id, g_container_item_id, p_container_name
                          , container_id, ret_stat, p_organization_id);
        msg ('Create Container End- Ret Stat: ' || ret_stat);

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_container, create_container status : '||ret_stat);
        IF ret_stat <> apps.fnd_api.g_ret_sts_success
        THEN
            RAISE create_container_failure;
        END IF;

        IF (p_delivery_ids.COUNT = 0)
        THEN                                                  --Added For 1.12
            split_shipments (p_shipments, p_carrier, p_carrier_code,
                             p_shipping_method, p_tracking_number, p_shipment_date
                             , delivery_ids, ret_stat);
            msg ('Split Shipments End- Ret Stat: ' || ret_stat);
        END IF;                                               --Added For 1.12

        msg ('delivery id count: ' || p_delivery_ids.COUNT);

        --Start Added For 1.12
        IF (p_delivery_ids.COUNT <> 0)
        THEN
            delivery_ids   := p_delivery_ids;

            FOR i IN 1 .. delivery_ids.LAST
            LOOP
                BEGIN
                    SELECT requested_quantity
                      INTO l_requested_quantity
                      FROM wsh_delivery_details
                     WHERE     1 = 1
                           AND delivery_detail_id = delivery_ids (i)
                           AND source_code = 'OE';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_requested_quantity   := 0;
                        msg (
                               'process_delivery_line -l_requested_quantity : '
                            || l_requested_quantity);
                END;

                process_delivery_line (delivery_ids (i), l_requested_quantity, p_shipment_date, p_carrier, p_carrier_code, p_shipping_method
                                       , p_tracking_number, ret_stat);
                x_ret_stat   := ret_stat;
                msg ('process_delivery_line End- Ret Stat: ' || ret_stat);
            -- IF NVL (ret_stat, g_ret_error) <> apps.fnd_api.g_ret_sts_success
            -- THEN
            -- RAISE process_line_failure;
            -- END IF;
            END LOOP;
        END IF;

        --End Added For 1.12

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_container, split_shipments status : '||ret_stat);

        IF ret_stat <> apps.fnd_api.g_ret_sts_success
        THEN
            RAISE split_shipments_failure;
        END IF;

        msg (
               'Delivery_id :'
            || p_delivery_id
            || ' container_id: '
            || container_id
            || ' count of delivery dtl_ids: '
            || delivery_ids.COUNT);

        FOR i IN 1 .. delivery_ids.COUNT
        LOOP
            msg ('     Delivery Dtl_Id to be packed: ' || delivery_ids (i));
        END LOOP;

        --Added for Canada Retail and Ecomm Project
        process_shipping_details (p_delivery_id, p_shipping_method, ret_stat);
        msg ('Process Delivery Shipping Details Ret Stat: ' || ret_stat);

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_container, process_shipping_details status : '||ret_stat);
        IF ret_stat <> apps.fnd_api.g_ret_sts_success
        THEN
            RAISE process_shipping_failure;
        END IF;

        --START Added as per ver 1.1
        upd_duty_paid_flag (p_osc_header_id   => p_osc_hdr_id,
                            x_ret_stat        => lx_ret_stat);
        msg ('Process Duty Paid Flag Status: ' || lx_ret_stat);
        --END Added as per ver 1.1
        pack_into_container (p_delivery_id, container_id, delivery_ids,
                             ret_stat);
        x_container_id   := container_id;
        msg ('Pack into container Ret Stat: ' || ret_stat);

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_container, pack_into_container status : '||ret_stat);
        IF ret_stat <> apps.fnd_api.g_ret_sts_success
        THEN
            RAISE pack_into_container_failure;
        END IF;

        process_delivery_freight (p_delivery_id, p_freight_cost, p_carrier_code, p_freight_charges, container_id, p_carrier
                                  , p_shipping_method, ret_stat);
        msg ('process_delivery_freight- Ret Stat: ' || ret_stat);

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_container, process_delivery_freight status : '||ret_stat);
        IF ret_stat <> apps.fnd_api.g_ret_sts_success
        THEN
            RAISE process_freight_failure;
        END IF;

        process_container_tracking (container_id, p_tracking_number, p_container_weight
                                    , p_carrier, ret_stat);
        msg ('process_container_tracking Ret Stat: ' || ret_stat);

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_container, process_container_tracking status : '||ret_stat);
        IF ret_stat <> apps.fnd_api.g_ret_sts_success
        THEN
            RAISE process_tracking_failure;
        END IF;

        x_ret_stat       := g_ret_success;
        msg ('End of ' || l_pn);
    EXCEPTION
        WHEN create_container_failure
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            msg ('EXP: create_container_failure - ' || x_ret_stat);
            RETURN;
        WHEN split_shipments_failure
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            msg ('EXP: split_shipments_failure - ' || x_ret_stat);
            RETURN;
        WHEN pack_into_container_failure
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            msg ('EXP: pack_into_container_failure - ' || x_ret_stat);
            RETURN;
        WHEN process_freight_failure
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            msg ('EXP: process_freight_failure - ' || x_ret_stat);
            RETURN;
        WHEN process_tracking_failure
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            msg ('EXP: process_tracking_failure - ' || x_ret_stat);
            RETURN;
        WHEN process_shipping_failure
        THEN
            --x_ret_stat := apps.fnd_api.g_ret_sts_error;
            x_ret_stat   := 'S';
            --Manually updating the STATUS to support EMEA/APAC 3PL operations
            msg ('EXP: process_shipping_failure - ' || x_ret_stat);
            RETURN;
        WHEN OTHERS
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_unexp_error;
            msg ('EXP: Others in pack_container- x_ret_stat: ' || x_ret_stat);
            RETURN;
    END;

    PROCEDURE process_delivery (
        p_delivery_id           NUMBER,
        p_ship_date             DATE,
        --Added for CCR0006806
        p_hold_source_tbl       do_shipping_tools.hold_source_tbl_type,
        x_retmsg            OUT VARCHAR2,              -- Added as per ver 1.2
        x_retstat           OUT VARCHAR2)
    IS
        l_pn                 VARCHAR2 (200) := lg_package_name || '.process_delivery';
        l_header_id          NUMBER;
        l_released_status    VARCHAR2 (1);
        retstat              VARCHAR2 (1);
        msgcount             NUMBER;
        msgdata              VARCHAR2 (2000);
        x_trip_id            VARCHAR2 (30);
        x_trip_name          VARCHAR2 (30);
        l_message            VARCHAR2 (4000);
        -- Changes length 240 to max as per ver 1.2
        temp                 BOOLEAN;
        --Added for CCR0008701
        l_hold_id            NUMBER;
        l_org_id             NUMBER;
        l_user_id            NUMBER := fnd_global.user_id;
        l_hold_description   VARCHAR2 (2000);
        l_hold_source_rec    oe_holds_pvt.hold_source_rec_type;
        l_msg_index_out      NUMBER;
        l_msg_data           VARCHAR2 (4000);
        l_msg_count          NUMBER := 0;
        l_return_status      VARCHAR2 (1);
        l_cnt                NUMBER;
        lv_coo               VARCHAR2 (150);           -- Added for CCR0009126
        --Added for CCR0006806
        l_chr_errbuf         VARCHAR2 (2000);
        l_chr_ret_code       VARCHAR2 (30);
        l_result             VARCHAR2 (240);
        l_line_tbl           oe_holds_pvt.order_tbl_type;

        TYPE tbl_lines IS TABLE OF INTEGER;

        lt_lines             tbl_lines;
        j                    NUMBER;

        CURSOR c_lines (p_delivery_id IN NUMBER, p_order_header_id IN NUMBER)
        IS
            SELECT DISTINCT oola.line_id
              FROM apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda, apps.oe_order_lines_all oola
             WHERE     wda.delivery_id = p_delivery_id
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.source_line_id = oola.line_id
                   AND oola.header_id = p_order_header_id
                   AND oola.flow_status_code = 'SHIPPED';
    BEGIN
        msg ('Start of ' || l_pn);
        msg ('p_delivery_id: ' || p_delivery_id);
        msg ('p_ship_date: ' || TO_CHAR (p_ship_date, 'MM/DD/YY'));
        msg ('BAB Before APPS.Wsh_Deliveries_Pub.DELIVERY_ACTION');
        SAVEPOINT begin_process;
        msg ('SAVEPOINT begin_process - ' || l_pn);

        --Begin CCR0008701
        --get order header for delivery
        --The assumption that for a given delivery_id only 1 SO header will esixt
        SELECT MAX (wdd.source_header_id), MAX (wdd.org_id)
          INTO l_header_id, l_org_id
          FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
         WHERE     wda.delivery_id = p_delivery_id
               AND wdd.delivery_detail_id = wda.delivery_detail_id
               AND wdd.source_code = 'OE';

        msg ('l_header_id: ' || l_header_id);

        --End CCR0008701

        --Begin CCR0008925
        --Get a collection of the lines on the delivery
        SELECT oola.line_id
          BULK COLLECT INTO lt_lines
          FROM oe_order_lines_all oola, wsh_delivery_details wdd, wsh_delivery_assignments wda
         WHERE     oola.line_id = wdd.source_line_id
               AND wdd.delivery_detail_id = wda.delivery_detail_id
               AND wda.delivery_id = p_delivery_id
               AND oola.header_id = l_header_id;

        msg ('lt_lines.count : ' || lt_lines.COUNT);

        FOR i IN 1 .. lt_lines.COUNT
        LOOP
            msg ('i: ' || i || ' value ' || lt_lines (i));
        END LOOP;

        --End CCR0008925

        -- l_holds_t := do_shipping_tools.remove_holds (l_header_id);
        BEGIN
            apps.wsh_deliveries_pub.delivery_action (
                p_api_version_number        => 1.0,
                p_init_msg_list             => NULL,
                x_return_status             => retstat,
                x_msg_count                 => msgcount,
                x_msg_data                  => msgdata,
                p_action_code               => 'CONFIRM',
                p_delivery_id               => p_delivery_id,
                p_sc_action_flag            => 'B',
                p_sc_intransit_flag         => 'Y',
                p_sc_close_trip_flag        => 'Y',
                p_sc_defer_interface_flag   => 'Y',
                p_sc_actual_dep_date        => p_ship_date,
                x_trip_id                   => x_trip_id,
                x_trip_name                 => x_trip_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'EXP: Others- API: Wsh_Deliveries_Pub.DELIVERY_ACTION: '
                    || SQLERRM);
                msg (
                    'EXP - ROLLBACK TO begin_process - API: Wsh_Deliveries_Pub');
                ROLLBACK TO begin_process;
                RAISE;
        END;

        msg ('After APPS.Wsh_Deliveries_Pub.DELIVERY_ACTION');

        BEGIN
            IF retstat NOT IN ('S', 'W')
            THEN
                msg ('delivery_action error: ' || retstat);
            END IF;

            msg ('Error message: ' || SUBSTR (msgdata, 1, 200));
            msg ('Error messagecount: ' || NVL (msgcount, 0));

            FOR i IN 1 .. NVL (msgcount, 0) + 10
            LOOP
                l_message   := fnd_msg_pub.get (i, 'F');
                l_message   := REPLACE (l_message, CHR (0), ' ');
                msg ('Error message: ' || SUBSTR (l_message, 1, 200));
            --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, API Error message: '||l_message);
            END LOOP;

            fnd_msg_pub.delete_msg ();
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('EXP: Error message incaps: ' || SQLERRM);
                x_retstat   := 'U';
        END;

        x_retstat   := retstat;

        IF retstat IN ('S', 'W')
        THEN
            --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, Before calling ITS..');
            wsh_ship_confirm_actions.interface_all_wrp (
                errbuf          => l_chr_errbuf,
                retcode         => l_chr_ret_code,
                p_mode          => 'ALL',
                p_delivery_id   => p_delivery_id);
        --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, After calling ITS..');
        --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, ITS completed, l_chr_ret_code..'||l_chr_ret_code);
        END IF;

        --Begin CCR0008701
        IF retstat IN ('S', 'W')
        THEN
            --Start Added for CCR0009126
            BEGIN
                --Loop to get all lines collection of Deliveries
                FOR i IN 1 .. lt_lines.COUNT
                LOOP
                    msg (
                           'COO for Delivery Lines - i: '
                        || i
                        || 'lt_lines (i): '
                        || lt_lines (i));

                    --Looo to get Shipped\Closed lines for Deliveries
                    --Either the line is Shipped\Closed or the child line is Shipped\Closed
                    FOR line_coo_rec
                        IN (SELECT oola.line_id
                              FROM wsh_delivery_details wdd, oe_order_lines_all oola
                             WHERE     wdd.source_line_id = oola.line_id
                                   AND wdd.source_line_id = lt_lines (i)
                                   AND wdd.source_code = 'OE'
                                   AND released_status = 'C'
                                   AND oola.header_id = l_header_id
                            UNION
                            SELECT oola1.line_id
                              FROM wsh_delivery_details wdd, oe_order_lines_all oola, oe_order_lines_all oola1,
                                   wsh_delivery_details wdd1
                             WHERE     wdd.source_line_id = oola.line_id
                                   AND oola.line_id =
                                       oola1.split_from_line_id
                                   AND oola.line_number = oola1.line_number
                                   AND oola.inventory_item_id =
                                       oola1.inventory_item_id
                                   AND oola1.line_id = wdd1.source_line_id
                                   AND wdd.source_line_id = lt_lines (i)
                                   AND wdd.source_code = 'OE'
                                   AND wdd1.released_status = 'C'
                                   AND wdd1.source_code = 'OE'
                                   AND oola.header_id = l_header_id)
                    LOOP
                        msg (
                               'Updation COO Header ID : '
                            || l_header_id
                            || ' Line ID : '
                            || line_coo_rec.line_id);

                        --Shipped\Closed lines in the result collection

                        --To fetch COO for staging lines
                        BEGIN
                            SELECT DISTINCT l.country_of_origin
                              INTO lv_coo
                              FROM xxdo.xxdo_wms_3pl_osc_h h, xxdo.xxdo_wms_3pl_osc_l l
                             WHERE     1 = 1
                                   AND h.osc_header_id = l.osc_header_id
                                   AND l.qty_shipped != 0
                                   AND l.source_line_id =
                                       line_coo_rec.line_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_coo   := NULL;
                        END;

                        IF lv_coo IS NOT NULL
                        THEN
                            BEGIN
                                UPDATE apps.wsh_delivery_details
                                   SET attribute3   = lv_coo
                                 WHERE     source_header_id = l_header_id
                                       AND source_line_id =
                                           line_coo_rec.line_id
                                       AND source_code = 'OE'
                                       AND released_status = 'C';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;
                        END IF;
                    END LOOP;
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg ('Error message: ' || SQLERRM);
                    NULL; --Delivery should not be Shipped\Closed for COO Updation
            END;

            --End Added for CCR0009126
            BEGIN
                --Check for backordered status of the delivery details
                msg ('Check for backordered holds\lines. ');

                --Get custom 3PL hold
                SELECT hold_id, description
                  INTO l_hold_id, l_hold_description
                  FROM oe_hold_definitions od
                 WHERE     NAME = l_3pl_hold_name
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           od.start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (
                                                           od.end_date_active,
                                                           SYSDATE));

                set_om_context (l_user_id, l_org_id);
                msg ('Org ID : ' || l_org_id);
                msg ('Hold ID : ' || l_hold_id);

                --Begin CCR0008925
                --Loop through the lines collection and backorder any needed lines
                FOR i IN 1 .. lt_lines.COUNT
                LOOP
                    --Get any backordered lines for the order line :
                    --either the line is backordered or the child line is backordered
                    msg ('i: ' || i || 'lt_lines (i): ' || lt_lines (i));

                    FOR line_rec
                        IN (SELECT oola.line_id
                              FROM wsh_delivery_details wdd, oe_order_lines_all oola
                             WHERE     wdd.source_line_id = oola.line_id
                                   AND wdd.source_line_id = lt_lines (i)
                                   AND wdd.source_code = 'OE'
                                   AND released_status = 'B'
                                   AND oola.header_id = l_header_id
                            UNION
                            SELECT oola1.line_id
                              FROM wsh_delivery_details wdd, oe_order_lines_all oola, oe_order_lines_all oola1,
                                   wsh_delivery_details wdd1
                             WHERE     wdd.source_line_id = oola.line_id
                                   AND oola.line_id =
                                       oola1.split_from_line_id
                                   AND oola.line_number = oola1.line_number
                                   AND oola.inventory_item_id =
                                       oola1.inventory_item_id
                                   AND oola1.line_id = wdd1.source_line_id
                                   AND wdd.source_line_id = lt_lines (i)
                                   AND wdd.source_code = 'OE'
                                   AND wdd1.released_status = 'B'
                                   AND wdd1.source_code = 'OE'
                                   AND oola.header_id = l_header_id)
                    LOOP
                        j                          := l_line_tbl.COUNT + 1;
                        msg (j);
                        msg (
                               'Header ID : '
                            || l_header_id
                            || ' Line ID : '
                            || line_rec.line_id);
                        --Backorder any lines in the result collection
                        l_line_tbl (j).header_id   := l_header_id;
                        l_line_tbl (j).line_id     := line_rec.line_id;
                    END LOOP;
                END LOOP;

                --End CCR0008925
                msg ('Applying hold of hold name : ' || l_hold_description);
                msg ('User ID : ' || l_user_id);
                msg ('Resp ID : ' || fnd_global.resp_id);
                msg ('Resp Appl ID : ' || fnd_global.resp_appl_id);
                --Begin CCR0008925
                oe_holds_pub.apply_holds (
                    p_api_version        => 1.0,
                    p_init_msg_list      => fnd_api.g_false,
                    p_commit             => fnd_api.g_false,
                    p_validation_level   => fnd_api.g_valid_level_full,
                    p_order_tbl          => l_line_tbl,
                    p_hold_id            => l_hold_id,
                    p_hold_until_date    => NULL,
                    p_hold_comment       => l_hold_description,
                    x_msg_count          => l_msg_count,
                    x_msg_data           => l_msg_data,
                    x_return_status      => l_return_status);

                --Check API return
                IF l_return_status <> 'S'
                THEN
                    FOR i IN 1 .. oe_msg_pub.count_msg
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                        , p_msg_index_out => l_msg_index_out);
                        l_message   :=
                            SUBSTR (l_message || l_msg_data, 1, 4000);
                    END LOOP;

                    msg ('Hold failed to apply :' || l_message);
                --x_retstat := 'E';
                -- RETURN;
                END IF;

                /*   msg ('Count of backordered details : ' || l_cnt);

                   --If the delivery details are backordered
                   IF l_cnt > 0
                   THEN
                      BEGIN
                         --Get custom 3PL hold
                         SELECT hold_id, description
                           INTO l_hold_id, l_hold_description
                           FROM oe_hold_definitions od
                          WHERE     name = l_3PL_Hold_name
                                AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                               NVL (
                                                                  od.start_date_active,
                                                                  SYSDATE))
                                                        AND TRUNC (
                                                               NVL (od.end_date_active,
                                                                    SYSDATE));


                         l_hold_source_rec.hold_id := l_hold_id;
                         l_hold_source_rec.hold_entity_code := 'O';
                         l_hold_source_rec.hold_entity_id := l_header_id;
                         l_hold_source_rec.hold_comment := l_hold_description;

                         set_om_context (l_user_id, l_org_id);

                         msg ('Org ID : ' || l_org_id);


                         msg ('Applying hold of hold name : ' || l_hold_description);
                         msg ('User ID : ' || l_user_id);

                         msg ('Resp ID : ' || fnd_global.resp_id);
                         msg ('Resp Appl ID : ' || fnd_global.resp_appl_id);
                         --Apply order header level hold
                         oe_holds_pub.apply_holds (
                            p_api_version        => 1.0,
                            p_validation_level   => fnd_api.g_valid_level_full,
                            p_hold_source_rec    => l_hold_source_rec,
                            x_msg_count          => l_msg_count,
                            x_msg_data           => l_msg_data,
                            x_return_status      => l_return_status);

                         --Check API return
                         IF l_return_status <> 'S'
                         THEN
                            FOR i IN 1 .. oe_msg_pub.count_msg
                            LOOP
                               oe_msg_pub.get (p_msg_index       => i,
                                               p_encoded         => fnd_api.g_false,
                                               p_data            => l_msg_data,
                                               p_msg_index_out   => l_msg_index_out);
                               l_message := SUBSTR (l_message || l_msg_data, 1, 4000);
                            END LOOP;

                            msg ('Hold failed to apply :' || l_message);
                         --x_retstat := 'E';
                         -- RETURN;
                         END IF;*/
                --End CCR0008925
                msg ('x_retstat : ' || x_retstat);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL; --The desired hold type is invalid (no hold applied)
                WHEN OTHERS
                THEN
                    x_retmsg    :=
                           'Exception when applying 3PL order hold : '
                        || SQLERRM;
                    x_retstat   := 'E';
                    msg ('EXP - Others - ' || x_retmsg);
                    RETURN;
            END;
        --  END IF;
        END IF;

        --End CCR0008701

        --Added for CCR0006806
        -----------------------------------------------------------------------------------------------
        /*
        Need to initiate Interface Trip stop API and then also launch OM Workflow program
        */
        BEGIN
            --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, p_hold_source_tbl total count :'||p_hold_source_tbl.count);
            FOR i IN 1 .. p_hold_source_tbl.COUNT
            LOOP
                FOR r_lines
                    IN c_lines (p_delivery_id,
                                p_hold_source_tbl (i).header_id)
                LOOP
                    --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, p_hold_source_tbl(i).header_id..'||p_hold_source_tbl(i).header_id);
                    --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, r_lines.line_id..'||r_lines.line_id);
                    apps.oe_standard_wf.oeol_selector (
                        p_itemtype   => 'OEOL',
                        p_itemkey    => TO_CHAR (r_lines.line_id),
                        p_actid      => 12345,
                        p_funcmode   => 'SET_CTX',
                        p_result     => l_result);
                    apps.wf_engine.handleerror ('OEOL', TO_CHAR (r_lines.line_id), 'INVOICE_INTERFACE'
                                                , 'RETRY', '');
                --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, After calling OM Workflow..l_result :'||l_result);
                END LOOP;                                    --End for c_lines

                COMMIT;
            END LOOP;                                          -- end for loop
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('EXP: API -oe_standard_wf.oeol_selector: ' || SQLERRM);
        --x_retstat := 'U';
        END;

        -----------------------------------------------------------------------------------------------
        -- IF NOT do_shipping_tools.reapply_holds (p_hold_source_tbl)     -- Commented as per ver 1.2
        IF NOT do_shipping_tools.reapply_holds (p_hold_source_tbl, l_message)
        -- Added as per ver 1.2
        THEN
            --Commented for CCR0006806
            --ROLLBACK TO begin_process;
            x_retstat   := 'E';
            x_retmsg    := 'Reapply Hold Failure. ' || l_message;
            -- Added as per ver 1.2
            msg ('Error attempting to re-apply holds; ship-confirm aborted.');
        END IF;

        msg ('End of ' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error message: ' || SQLERRM);
            x_retstat   := 'U';
            msg ('EXP - Others - ' || l_pn);
    END;

    --Start Added for 1.12
    --New procedure copied from base for US7 Backordered All
    PROCEDURE process_delivery_bo_us7 (
        p_delivery_id           NUMBER,
        p_ship_date             DATE,                   --Added for CCR0006806
        p_hold_source_tbl       do_shipping_tools.hold_source_tbl_type,
        x_retmsg            OUT VARCHAR2,              -- Added as per ver 1.2
        x_retstat           OUT VARCHAR2)
    IS
        l_pn                 VARCHAR2 (200) := lg_package_name || '.process_delivery';
        l_header_id          NUMBER;
        l_released_status    VARCHAR2 (1);
        retstat              VARCHAR2 (1);
        msgcount             NUMBER;
        msgdata              VARCHAR2 (2000);
        x_trip_id            VARCHAR2 (30);
        x_trip_name          VARCHAR2 (30);
        l_message            VARCHAR2 (4000);
        -- Changes length 240 to max as per ver 1.2
        temp                 BOOLEAN;
        --Added for CCR0008701
        l_hold_id            NUMBER;
        l_org_id             NUMBER;
        l_user_id            NUMBER := fnd_global.user_id;
        l_hold_description   VARCHAR2 (2000);
        l_hold_source_rec    oe_holds_pvt.hold_source_rec_type;
        l_msg_index_out      NUMBER;
        l_msg_data           VARCHAR2 (4000);
        l_msg_count          NUMBER := 0;
        l_return_status      VARCHAR2 (1);
        l_cnt                NUMBER;
        lv_coo               VARCHAR2 (150);           -- Added for CCR0009126
        --Added for CCR0006806
        l_chr_errbuf         VARCHAR2 (2000);
        l_chr_ret_code       VARCHAR2 (30);
        l_result             VARCHAR2 (240);
        l_line_tbl           oe_holds_pvt.order_tbl_type;

        TYPE tbl_lines IS TABLE OF INTEGER;

        lt_lines             tbl_lines;
        j                    NUMBER;

        CURSOR c_lines (p_delivery_id IN NUMBER, p_order_header_id IN NUMBER)
        IS
            SELECT DISTINCT oola.line_id
              FROM apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda, apps.oe_order_lines_all oola
             WHERE     wda.delivery_id = p_delivery_id
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.source_line_id = oola.line_id
                   AND oola.header_id = p_order_header_id
                   AND oola.flow_status_code = 'SHIPPED';
    BEGIN
        msg ('Start of ' || l_pn);
        msg ('p_delivery_id: ' || p_delivery_id);
        msg ('p_ship_date: ' || TO_CHAR (p_ship_date, 'MM/DD/YY'));
        msg ('BAB Before APPS.Wsh_Deliveries_Pub.DELIVERY_ACTION');
        SAVEPOINT begin_process;

        --Begin CCR0008701
        --get order header for delivery
        --The assumption that for a given delivery_id only 1 SO header will esixt
        SELECT MAX (wdd.source_header_id), MAX (wdd.org_id)
          INTO l_header_id, l_org_id
          FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
         WHERE     wda.delivery_id = p_delivery_id
               AND wdd.delivery_detail_id = wda.delivery_detail_id
               AND wdd.source_code = 'OE';

        msg ('l_header_id: ' || l_header_id);

        --End CCR0008701

        --Begin CCR0008925
        --Get a collection of the lines on the delivery
        SELECT oola.line_id
          BULK COLLECT INTO lt_lines
          FROM oe_order_lines_all oola, wsh_delivery_details wdd, wsh_delivery_assignments wda
         WHERE     oola.line_id = wdd.source_line_id
               AND wdd.delivery_detail_id = wda.delivery_detail_id
               AND wda.delivery_id = p_delivery_id
               AND oola.header_id = l_header_id;

        msg ('lt_lines.count : ' || lt_lines.COUNT);

        FOR i IN 1 .. lt_lines.COUNT
        LOOP
            msg ('i: ' || i || ' value ' || lt_lines (i));
        END LOOP;

        --End CCR0008925

        -- l_holds_t := do_shipping_tools.remove_holds (l_header_id);
        BEGIN
            apps.wsh_deliveries_pub.delivery_action (
                p_api_version_number        => 1.0,
                p_init_msg_list             => NULL,
                x_return_status             => retstat,
                x_msg_count                 => msgcount,
                x_msg_data                  => msgdata,
                p_action_code               => 'CONFIRM',
                p_delivery_id               => p_delivery_id,
                p_sc_action_flag            => 'C',            --Backorded ALL
                p_sc_intransit_flag         => 'Y',
                p_sc_close_trip_flag        => 'Y',
                p_sc_defer_interface_flag   => 'Y',
                p_sc_actual_dep_date        => p_ship_date,
                x_trip_id                   => x_trip_id,
                x_trip_name                 => x_trip_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO begin_process;
                msg (
                       'Exception in Wsh_Deliveries_Pub.DELIVERY_ACTION: '
                    || SQLERRM);
                msg (
                    'EXP: ROLLBACK TO begin_process - Wsh_Deliveries_Pub.DELIVERY_ACTION ');
                RAISE;
        END;

        msg ('After APPS.Wsh_Deliveries_Pub.DELIVERY_ACTION');

        BEGIN
            IF retstat NOT IN ('S', 'W')
            THEN
                msg ('delivery_action error: ' || retstat);
            END IF;

            msg ('Error message: ' || SUBSTR (msgdata, 1, 200));
            msg ('Error messagecount: ' || NVL (msgcount, 0));

            FOR i IN 1 .. NVL (msgcount, 0) + 10
            LOOP
                l_message   := fnd_msg_pub.get (i, 'F');
                l_message   := REPLACE (l_message, CHR (0), ' ');
                msg ('Error message: ' || SUBSTR (l_message, 1, 200));
            END LOOP;

            fnd_msg_pub.delete_msg ();
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('EXP: Error message incaps: ' || SQLERRM);
                x_retstat   := 'U';
        END;

        x_retstat   := retstat;

        IF retstat IN ('S', 'W')
        THEN
            wsh_ship_confirm_actions.interface_all_wrp (
                errbuf          => l_chr_errbuf,
                retcode         => l_chr_ret_code,
                p_mode          => 'ALL',
                p_delivery_id   => p_delivery_id);
        END IF;

        --Begin CCR0008701
        IF retstat IN ('S', 'W')
        THEN
            --Start Added for CCR0009126
            BEGIN
                --Loop to get all lines collection of Deliveries
                FOR i IN 1 .. lt_lines.COUNT
                LOOP
                    msg (
                           'COO for Delivery Lines - i: '
                        || i
                        || 'lt_lines (i): '
                        || lt_lines (i));

                    --Looo to get Shipped\Closed lines for Deliveries
                    --Either the line is Shipped\Closed or the child line is Shipped\Closed
                    FOR line_coo_rec
                        IN (SELECT oola.line_id
                              FROM wsh_delivery_details wdd, oe_order_lines_all oola
                             WHERE     wdd.source_line_id = oola.line_id
                                   AND wdd.source_line_id = lt_lines (i)
                                   AND wdd.source_code = 'OE'
                                   AND released_status = 'C'
                                   AND oola.header_id = l_header_id
                            UNION
                            SELECT oola1.line_id
                              FROM wsh_delivery_details wdd, oe_order_lines_all oola, oe_order_lines_all oola1,
                                   wsh_delivery_details wdd1
                             WHERE     wdd.source_line_id = oola.line_id
                                   AND oola.line_id =
                                       oola1.split_from_line_id
                                   AND oola.line_number = oola1.line_number
                                   AND oola.inventory_item_id =
                                       oola1.inventory_item_id
                                   AND oola1.line_id = wdd1.source_line_id
                                   AND wdd.source_line_id = lt_lines (i)
                                   AND wdd.source_code = 'OE'
                                   AND wdd1.released_status = 'C'
                                   AND wdd1.source_code = 'OE'
                                   AND oola.header_id = l_header_id)
                    LOOP
                        msg (
                               'Updation COO Header ID : '
                            || l_header_id
                            || ' Line ID : '
                            || line_coo_rec.line_id);

                        --Shipped\Closed lines in the result collection

                        --To fetch COO for staging lines
                        BEGIN
                            SELECT DISTINCT l.country_of_origin
                              INTO lv_coo
                              FROM xxdo.xxdo_wms_3pl_osc_h h, xxdo.xxdo_wms_3pl_osc_l l
                             WHERE     1 = 1
                                   AND h.osc_header_id = l.osc_header_id
                                   AND l.qty_shipped != 0
                                   AND l.source_line_id =
                                       line_coo_rec.line_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_coo   := NULL;
                        END;

                        IF lv_coo IS NOT NULL
                        THEN
                            BEGIN
                                UPDATE apps.wsh_delivery_details
                                   SET attribute3   = lv_coo
                                 WHERE     source_header_id = l_header_id
                                       AND source_line_id =
                                           line_coo_rec.line_id
                                       AND source_code = 'OE'
                                       AND released_status = 'C';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;
                        END IF;
                    END LOOP;
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg ('Error message: ' || SQLERRM);
                    NULL; --Delivery should not be Shipped\Closed for COO Updation
            END;

            --End Added for CCR0009126
            BEGIN
                --Check for backordered status of the delivery details
                --Get custom 3PL hold
                SELECT hold_id, description
                  INTO l_hold_id, l_hold_description
                  FROM oe_hold_definitions od
                 WHERE     NAME = l_3pl_hold_name
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           od.start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (
                                                           od.end_date_active,
                                                           SYSDATE));

                set_om_context (l_user_id, l_org_id);
                msg ('Org ID : ' || l_org_id);
                msg ('Hold ID : ' || l_hold_id);

                --Begin CCR0008925
                --Loop through the lines collection and backorder any needed lines
                FOR i IN 1 .. lt_lines.COUNT
                LOOP
                    --Get any backordered lines for the order line :
                    --either the line is backordered or the child line is backordered
                    msg ('i: ' || i || 'lt_lines (i): ' || lt_lines (i));

                    FOR line_rec
                        IN (SELECT oola.line_id
                              FROM wsh_delivery_details wdd, oe_order_lines_all oola
                             WHERE     wdd.source_line_id = oola.line_id
                                   AND wdd.source_line_id = lt_lines (i)
                                   AND wdd.source_code = 'OE'
                                   AND released_status = 'B'
                                   AND oola.header_id = l_header_id
                            UNION
                            SELECT oola1.line_id
                              FROM wsh_delivery_details wdd, oe_order_lines_all oola, oe_order_lines_all oola1,
                                   wsh_delivery_details wdd1
                             WHERE     wdd.source_line_id = oola.line_id
                                   AND oola.line_id =
                                       oola1.split_from_line_id
                                   AND oola.line_number = oola1.line_number
                                   AND oola.inventory_item_id =
                                       oola1.inventory_item_id
                                   AND oola1.line_id = wdd1.source_line_id
                                   AND wdd.source_line_id = lt_lines (i)
                                   AND wdd.source_code = 'OE'
                                   AND wdd1.released_status = 'B'
                                   AND wdd1.source_code = 'OE'
                                   AND oola.header_id = l_header_id)
                    LOOP
                        j                          := l_line_tbl.COUNT + 1;
                        msg (j);
                        msg (
                               'Header ID : '
                            || l_header_id
                            || ' Line ID : '
                            || line_rec.line_id);
                        --Backorder any lines in the result collection
                        l_line_tbl (j).header_id   := l_header_id;
                        l_line_tbl (j).line_id     := line_rec.line_id;
                    END LOOP;
                END LOOP;

                --End CCR0008925
                msg ('Applying hold of hold name : ' || l_hold_description);
                msg ('User ID : ' || l_user_id);
                msg ('Resp ID : ' || fnd_global.resp_id);
                msg ('Resp Appl ID : ' || fnd_global.resp_appl_id);
                --Begin CCR0008925
                oe_holds_pub.apply_holds (
                    p_api_version        => 1.0,
                    p_init_msg_list      => fnd_api.g_false,
                    p_commit             => fnd_api.g_false,
                    p_validation_level   => fnd_api.g_valid_level_full,
                    p_order_tbl          => l_line_tbl,
                    p_hold_id            => l_hold_id,
                    p_hold_until_date    => NULL,
                    p_hold_comment       => l_hold_description,
                    x_msg_count          => l_msg_count,
                    x_msg_data           => l_msg_data,
                    x_return_status      => l_return_status);

                --Check API return
                IF l_return_status <> 'S'
                THEN
                    FOR i IN 1 .. oe_msg_pub.count_msg
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                        , p_msg_index_out => l_msg_index_out);
                        l_message   :=
                            SUBSTR (l_message || l_msg_data, 1, 4000);
                    END LOOP;

                    msg ('Hold failed to apply :' || l_message);
                END IF;

                msg ('x_retstat : ' || x_retstat);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL; --The desired hold type is invalid (no hold applied)
                WHEN OTHERS
                THEN
                    x_retmsg    :=
                           'Exception when applying 3PL order hold : '
                        || SQLERRM;
                    x_retstat   := 'E';
                    msg (
                           'EXP: Hold failed to apply - x_retstat :'
                        || x_retstat);
                    RETURN;
            END;
        --  END IF;
        END IF;

        -----------------------------------------------------------------------------------------------
        --Need to initiate Interface Trip stop API and then also launch OM Workflow program
        BEGIN
            FOR i IN 1 .. p_hold_source_tbl.COUNT
            LOOP
                FOR r_lines
                    IN c_lines (p_delivery_id,
                                p_hold_source_tbl (i).header_id)
                LOOP
                    --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, p_hold_source_tbl(i).header_id..'||p_hold_source_tbl(i).header_id);
                    --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, r_lines.line_id..'||r_lines.line_id);
                    apps.oe_standard_wf.oeol_selector (
                        p_itemtype   => 'OEOL',
                        p_itemkey    => TO_CHAR (r_lines.line_id),
                        p_actid      => 12345,
                        p_funcmode   => 'SET_CTX',
                        p_result     => l_result);
                    apps.wf_engine.handleerror ('OEOL', TO_CHAR (r_lines.line_id), 'INVOICE_INTERFACE'
                                                , 'RETRY', '');
                --apps.XXDO_3PL_DEBUG_PROCEDURE('process_delivery, After calling OM Workflow..l_result :'||l_result);
                END LOOP;                                    --End for c_lines

                COMMIT;
            END LOOP;                                          -- end for loop
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                    'EXP: oe_standard_wf.oeol_selector - Error: ' || SQLERRM);
        --x_retstat := 'U';
        END;

        -----------------------------------------------------------------------------------------------
        -- IF NOT do_shipping_tools.reapply_holds (p_hold_source_tbl)     -- Commented as per ver 1.2
        IF NOT do_shipping_tools.reapply_holds (p_hold_source_tbl, l_message)
        -- Added as per ver 1.2
        THEN
            --Commented for CCR0006806
            --ROLLBACK TO begin_process;
            x_retstat   := 'E';
            x_retmsg    := 'Reapply Hold Failure. ' || l_message;
            -- Added as per ver 1.2
            msg ('Error attempting to re-apply holds; ship-confirm aborted.');
        END IF;

        msg ('-' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP: Error attempting to re-apply holds : ' || SQLERRM);
            x_retstat   := 'U';
            msg ('End of ' || l_pn);
    END;

    --End Added for 1.12

    FUNCTION pick_confirm (
        l_mo_lin_tbl IN OUT inv_move_order_pub.trolin_tbl_type)
        RETURN BOOLEAN
    IS
        l_return_status      VARCHAR2 (1);
        l_msg_count          NUMBER;
        l_msg_data           VARCHAR2 (2000);
        l_message            VARCHAR2 (2000);
        l_mmtt_tbl           inv_mo_line_detail_util.g_mmtt_tbl_type;
        l_temp               inv_move_order_pub.trolin_tbl_type;
        l_mo_lin_tbl2        inv_move_order_pub.trolin_tbl_type;
        l_transaction_date   DATE := SYSDATE;                 --Added for 1.12
        hell                 EXCEPTION;
    BEGIN
        l_mmtt_tbl.DELETE;
        l_temp         := l_mo_lin_tbl;

        IF l_mo_lin_tbl.COUNT = 0
        THEN
            msg ('Critical Error Order contains no lines to confirm!', 1500);
            RETURN FALSE;
        END IF;

        inv_pick_wave_pick_confirm_pub.pick_confirm (
            p_api_version_number   => l_api_version_number,
            p_init_msg_list        => fnd_api.g_true,
            p_commit               => l_commit,
            p_move_order_type      => inv_globals.g_move_order_pick_wave,
            p_transaction_mode     => 1,
            p_trolin_tbl           => l_mo_lin_tbl,
            p_mold_tbl             => l_mmtt_tbl,
            x_mmtt_tbl             => l_mmtt_tbl,
            x_trolin_tbl           => l_mo_lin_tbl2,
            x_return_status        => l_return_status,
            x_msg_count            => l_msg_count,
            x_msg_data             => l_msg_data,
            p_transaction_date     => l_transaction_date      --Added for 1.12
                                                        );

        FOR i IN 1 .. l_mo_lin_tbl.COUNT
        LOOP
            UPDATE wsh_delivery_details
               SET attribute15   = 'Pick Confirmed'
             WHERE move_order_line_id = l_mo_lin_tbl (i).line_id;

            msg ('move_order_line_id => ' || l_mo_lin_tbl (i).line_id);
            msg ('mo_creation_date => ' || l_mo_lin_tbl (i).creation_date);
            msg ('mo_date_required => ' || l_mo_lin_tbl (i).date_required);
            msg ('Changed ' || SQL%ROWCOUNT || ' records to pick confirmed');
        /*IF SQL%ROWCOUNT > 1
        THEN
           RAISE hell;
        END IF;*/
        END LOOP;

        l_mo_lin_tbl   := l_mo_lin_tbl2;

        IF (l_return_status = wsh_util_core.g_ret_sts_unexp_error)
        THEN
            msg (
                   'Critical Error occurred in INV_Pick_Wave_Pick_Confirm_PUB.Pick_Confirm  - '
                || SQLERRM,
                1);
            msg ('There are ' || l_msg_count || ' messages');
            msg ('Message: ' || REPLACE (l_msg_data, CHR (0), ' '));

            FOR i IN 1 .. l_msg_count
            LOOP
                l_message   := fnd_msg_pub.get (i, 'F');
                l_message   := REPLACE (l_message, CHR (0), ' ');
                msg (l_message, 1);
            END LOOP;

            fnd_msg_pub.delete_msg ();
            RETURN FALSE;
        END IF;

        IF (l_return_status = wsh_util_core.g_ret_sts_error)
        THEN
            msg (
                'Non-Critical Error occurred in INV_Pick_Wave_Pick_Confirm_PUB.Pick_Confirm',
                1500);

            FOR i IN 1 .. l_msg_count
            LOOP
                l_message   := fnd_msg_pub.get (i, 'F');
                l_message   := REPLACE (l_message, CHR (0), ' ');
                msg (l_message);
            END LOOP;

            fnd_msg_pub.delete_msg ();
        END IF;

        msg ('pick_confirm Success', 150000);
        RETURN TRUE;
    END;

    FUNCTION repopulate_mo_lines (p_delivery_id NUMBER)
        RETURN inv_move_order_pub.trolin_tbl_type
    IS
        l_mo_lin_tbl        inv_move_order_pub.trolin_tbl_type;
        l_temp_trolin_rec   inv_move_order_pub.trolin_rec_type;

        CURSOR details (p2_delivery_id NUMBER)
        IS
            SELECT DISTINCT wdd.move_order_line_id, wdd.source_line_id
              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
             WHERE     wda.delivery_id = p2_delivery_id
                   AND wdd.delivery_detail_id = wda.delivery_detail_id;
    BEGIN
        FOR detail IN details (p_delivery_id)
        LOOP
            l_temp_trolin_rec   :=
                inv_trolin_util.query_row (
                    p_line_id => detail.move_order_line_id);
            l_mo_lin_tbl (l_mo_lin_tbl.COUNT + 1)   :=
                inv_trolin_util.query_row (
                    p_line_id => detail.move_order_line_id);
        END LOOP;

        RETURN l_mo_lin_tbl;
    END;

    FUNCTION pick_confirm_delivery (p_delivery_id NUMBER)
        RETURN VARCHAR2
    IS
        mo_lines   inv_move_order_pub.trolin_tbl_type;
        hell       EXCEPTION;
    BEGIN
        msg ('Start of pick_confirm_delivery');
        mo_lines   := repopulate_mo_lines (p_delivery_id);
        msg ('repopulate returned with ' || mo_lines.COUNT || ' records');

        IF pick_confirm (mo_lines) = FALSE
        THEN
            msg ('Failed to pick confirm');
            msg ('-pick_confirm_delivery');
            RETURN fnd_api.g_ret_sts_error;
        END IF;

        msg ('Pick confirm Succeed ' || mo_lines.COUNT || ' lines');

        FOR i IN 1 .. mo_lines.COUNT
        LOOP
            UPDATE wsh_delivery_details
               SET attribute15   = 'Pick Confirmed'
             WHERE move_order_line_id = mo_lines (i).line_id;

            msg ('Changed ' || SQL%ROWCOUNT || ' records to pick confirmed');
        /*IF SQL%ROWCOUNT > 1
        THEN
           RAISE hell;
        END IF;*/
        END LOOP;

        msg ('End of pick_confirm_delivery');
        RETURN fnd_api.g_ret_sts_success;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Failed to pick confirm BLAH! ' || SQLERRM);
            msg ('EXP: pick_confirm_delivery');
            RETURN fnd_api.g_ret_sts_unexp_error;
    END;

    --Begin CCR0008762
    FUNCTION check_org_edi_status (pn_organization_id IN NUMBER)
        RETURN BOOLEAN
    IS
        n_cnt   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO n_cnt
          FROM fnd_lookup_values flv, mtl_parameters mp
         WHERE     flv.lookup_type = 'XXDO_WMS_3PL_EDI_ASN_MAP'
               AND flv.LANGUAGE = 'US'
               AND mp.organization_id = pn_organization_id
               AND mp.organization_code = flv.lookup_code
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (flv.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (flv.end_date_active,
                                                    SYSDATE));

        RETURN n_cnt > 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END;

    --End  CCR0008762
    PROCEDURE edi_asn_interface (p_delivery_id IN NUMBER, p_organization_id IN NUMBER, p_shipment_date IN DATE, p_carrier IN VARCHAR2, p_carrier_code IN VARCHAR2, p_bol_number IN VARCHAR2, p_load_id IN VARCHAR2, --Added for the CCR0006013
                                                                                                                                                                                                                    p_pro_number IN VARCHAR2, --Added for the CCR0008925
                                                                                                                                                                                                                                              p_seal_code IN VARCHAR2
                                 ,                            --Added for 1.12
                                   x_ret_stat OUT VARCHAR2)
    IS
        l_num_shipment_id          NUMBER;
        l_chr_bol_number           VARCHAR2 (30);
        l_chr_record_exists        VARCHAR2 (1);
        l_user_id                  NUMBER;
        l_num_of_picktickets       NUMBER;
        --Start Added for 1.12
        ln_old_shipment_id         NUMBER := NULL;
        lv_org_code                VARCHAR2 (30);
        lv_odc_org_exists_flag     VARCHAR2 (10);
        lv_edi_856_ship_exists     VARCHAR2 (10);
        lv_bol_cust_brand_exists   BOOLEAN;

        --End Added for 1.12

        CURSOR cur_customer_shipments (p_delivery_id       IN NUMBER,
                                       p_organization_id   IN NUMBER) --Added for 1.16
        IS
            SELECT DISTINCT
                   wda.delivery_id,
                   ooha.order_number,
                   rc.customer_id,
                   ooha.sold_to_org_id,
                   (SELECT oola.ship_to_org_id
                      FROM apps.oe_order_lines_all oola
                     WHERE     oola.header_id = ooha.header_id
                           AND ROWNUM = 1)
                       ship_to_org_id,
                   wdd.tracking_number,
                   hps.location_id,
                   ooha.attribute5
                       brand,
                   --begin  CCR0008762
                   (SELECT flv.attribute1
                      FROM fnd_lookup_values flv
                     WHERE     lookup_type = 'XXDO_EDI_CUSTOMERS'
                           AND flv.LANGUAGE = 'US'
                           AND flv.enabled_flag = 'Y'
                           AND flv.lookup_code = hca.account_number)
                       sps_event,
                   --End  CCR0008762
                   --begin  CCR0010347
                   (SELECT attribute5
                      FROM ar.hz_cust_acct_sites_all a
                     WHERE     1 = 1
                           AND a.party_site_id = hps.party_site_id
                           AND ROWNUM = 1)
                       ship_to_dc,
                   (SELECT attribute9
                      FROM wsh_new_deliveries
                     WHERE delivery_id = wda.delivery_id)
                       container_number
              --End  CCR0010347
              FROM apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd, apps.oe_order_headers_all ooha,
                   apps.xxd_ra_customers_v rc, apps.hz_party_sites hps, hz_cust_accounts_all hca
             WHERE     wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_header_id = ooha.header_id
                   AND wdd.source_code = 'OE'
                   AND ooha.sold_to_org_id = rc.customer_id
                   AND rc.party_id = hps.party_id
                   AND hps.status = 'A'
                   --AND wda.delivery_id = :p_delivery_id
                   --Added for Canada Retail and Ecomm
                   AND wdd.ship_to_location_id = hps.location_id
                   AND ooha.sold_to_org_id = hca.cust_account_id
                   AND rc.party_id = hca.party_id
                   AND EXISTS
                           ((SELECT 1
                               FROM fnd_lookup_values flv
                              WHERE     lookup_type = 'XXDO_EDI_CUSTOMERS'
                                    AND flv.LANGUAGE = 'US'
                                    AND flv.enabled_flag = 'Y'
                                    --Start Added for 1.16
                                    AND flv.language = USERENV ('Lang')
                                    AND SYSDATE BETWEEN NVL (
                                                            start_date_active,
                                                            SYSDATE)
                                                    AND NVL (end_date_active,
                                                             SYSDATE + 1)
                                    --End Added for 1.16
                                    AND flv.lookup_code = hca.account_number)
                            --Start Added for 1.16
                            UNION
                            (SELECT 1
                               FROM fnd_lookup_values flv, mtl_parameters mp
                              WHERE     flv.lookup_code =
                                        mp.organization_code
                                    AND flv.lookup_type =
                                        'XXD_ODC_ORG_CODE_LKP'
                                    AND mp.organization_id =
                                        p_organization_id
                                    AND NVL (flv.attribute1, 'N') = 'Y'
                                    AND flv.language = USERENV ('Lang')
                                    AND flv.enabled_flag = 'Y'
                                    AND SYSDATE BETWEEN NVL (
                                                            start_date_active,
                                                            SYSDATE)
                                                    AND NVL (end_date_active,
                                                             SYSDATE + 1)))
                   --End Added for 1.16
                   AND wda.delivery_id = p_delivery_id;

        CURSOR cur_customer_picktickets (p_delivery_id IN NUMBER)
        IS
              SELECT lines.header_id, MAX (lines.weight_uom_code) weight_uom_code, MAX (lines.volume_uom_code) volume_uom_code,
                     MAX (lines.shipping_quantity_uom) shipping_quantity_uom, MAX (lines.intmed_ship_to_org_id) intmed_ship_to_org_id, SUM (lines.ordered_quantity) ordered_quantity,
                     SUM (lines.shipped_quantity) shipped_quantity, SUM (lines.net_weight) shipped_weight, SUM (lines.volume) shipped_volume
                FROM (  SELECT oola.header_id, wnd.weight_uom_code, wnd.volume_uom_code,
                               oola.shipping_quantity_uom, oola.intmed_ship_to_org_id, oola.ordered_quantity,
                               SUM (wdd.requested_quantity) shipped_quantity, SUM (wdd.net_weight) net_weight, SUM (wdd.volume) volume
                          FROM oe_order_lines_all oola, wsh_delivery_details wdd, wsh_delivery_assignments wda,
                               wsh_new_deliveries wnd
                         WHERE     wnd.delivery_id = p_delivery_id
                               AND wda.delivery_id = wnd.delivery_id
                               AND wdd.delivery_detail_id =
                                   wda.delivery_detail_id
                               AND wdd.source_code = 'OE'
                               AND oola.line_id = wdd.source_line_id
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM do_edi.do_edi856_pick_tickets dept
                                         WHERE dept.delivery_id = wnd.delivery_id)
                      /* prevents insert of existing deliveries */
                      GROUP BY oola.header_id, oola.line_id, wnd.weight_uom_code,
                               wnd.volume_uom_code, oola.shipping_quantity_uom, oola.intmed_ship_to_org_id,
                               oola.ordered_quantity) lines
            GROUP BY lines.header_id;
    BEGIN
        x_ret_stat   := 'S';

        SELECT user_id
          INTO l_user_id
          FROM fnd_user
         WHERE user_name = 'WMS_BATCH';

        --Start Added for 1.12
        BEGIN
            SELECT 'Y'
              INTO lv_odc_org_exists_flag
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     flv.lookup_code = mp.organization_code
                   AND flv.lookup_type = 'XXD_ODC_ORG_CODE_LKP'
                   AND mp.organization_id = p_organization_id
                   AND flv.language = USERENV ('Lang')
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE + 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_odc_org_exists_flag   := NULL;
        END;

        IF NVL (lv_odc_org_exists_flag, 'N') <> 'Y'
        THEN
            --End Added for 1.12
            FOR customer_shipments_rec
                IN cur_customer_shipments (p_delivery_id, p_organization_id) --Added for 1.16
            LOOP
                --We will get BOL at header level and tracking number at line level and so
                --we can insert data as-is for either LTL or Parcel shipments
                l_chr_bol_number       := p_bol_number;

                UPDATE wsh_new_deliveries
                   SET waybill   = l_chr_bol_number
                 WHERE delivery_id = customer_shipments_rec.delivery_id;

                l_num_shipment_id      := NULL;
                --- Get next shipment id
                do_edi.get_next_values ('DO_EDI856_SHIPMENTS',
                                        1,
                                        l_num_shipment_id);

                BEGIN
                    INSERT INTO do_edi.do_edi856_shipments (
                                    shipment_id,
                                    asn_status,
                                    asn_date,
                                    invoice_date,
                                    customer_id,
                                    ship_to_org_id,
                                    waybill,
                                    tracking_number,
                                    seal_code,                --Added for 1.12
                                    pro_number,
                                    est_delivery_date,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by,
                                    archive_flag,
                                    organization_id,
                                    location_id,
                                    request_sent_date,
                                    reply_rcv_date,
                                    scheduled_pu_date,
                                    bill_of_lading,
                                    carrier,
                                    carrier_scac,
                                    comments,
                                    confirm_sent_date,
                                    contact_name,
                                    cust_shipment_id,
                                    earliest_pu_date,
                                    latest_pu_date,
                                    load_id,
                                    routing_status,
                                    ship_confirm_date,
                                    shipment_weight,
                                    shipment_weight_uom,
                                    sps_event,
                                    ship_to_dc,  --added as part of CCR0010347
                                    container_number --added as part of CCR0010347
                                                    )      -- CCR0008762  --35
                             VALUES (l_num_shipment_id,
                                     'R',
                                     NULL,
                                     NULL,
                                     customer_shipments_rec.customer_id,
                                     customer_shipments_rec.ship_to_org_id,
                                     l_chr_bol_number,
                                     customer_shipments_rec.tracking_number,
                                     p_seal_code,             --Added for 1.12
                                     p_pro_number, --Added for the CCR0008925,
                                     p_shipment_date + 3,
                                     SYSDATE,
                                     l_user_id,
                                     SYSDATE,
                                     l_user_id,
                                     'N',
                                     p_organization_id,
                                     customer_shipments_rec.location_id,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     p_carrier,
                                     p_carrier_code,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     p_load_id,     --Added for the CCR0006013
                                     NULL,
                                     p_shipment_date,
                                     NULL,
                                     'LB',
                                     customer_shipments_rec.sps_event, -- CCR0008762
                                     customer_shipments_rec.ship_to_dc, --added as part of CCR0010347
                                     customer_shipments_rec.container_number --added as part of CCR0010347
                                                                            );
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                l_num_of_picktickets   := 0;

                FOR customer_picktickets_rec
                    IN cur_customer_picktickets (p_delivery_id)
                LOOP
                    l_chr_record_exists   := 'N';

                    BEGIN
                        SELECT 'Y'
                          INTO l_chr_record_exists
                          FROM do_edi.do_edi856_pick_tickets
                         WHERE delivery_id = p_delivery_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_chr_record_exists   := 'N';
                    END;

                    IF l_chr_record_exists = 'N'
                    THEN
                        BEGIN
                            INSERT INTO do_edi.do_edi856_pick_tickets (
                                            shipment_id,
                                            delivery_id,
                                            weight,
                                            weight_uom,
                                            number_cartons,
                                            cartons_uom,
                                            volume,
                                            volume_uom,
                                            ordered_qty,
                                            shipped_qty,
                                            shipped_qty_uom,
                                            source_header_id,
                                            intmed_ship_to_org_id,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            archive_flag,
                                            shipment_key)
                                     VALUES (
                                                l_num_shipment_id,
                                                p_delivery_id,
                                                apps.do_edi_utils_pub.delivery_ship_weight (
                                                    p_delivery_id),
                                                'LB',
                                                apps.do_edi_utils_pub.delivery_container_count (
                                                    p_delivery_id),
                                                'EA',
                                                apps.do_edi_utils_pub.delivery_ship_volume (
                                                    p_delivery_id),
                                                'CI',
                                                customer_picktickets_rec.ordered_quantity,
                                                customer_picktickets_rec.shipped_quantity,
                                                'EA',
                                                customer_picktickets_rec.header_id,
                                                customer_picktickets_rec.intmed_ship_to_org_id,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                'N',
                                                --shipment_key : Need to check with Yashoda/Joe about this logic
                                                (SELECT l_num_shipment_id || brand_code
                                                   FROM do_custom.do_brands
                                                  WHERE     brand_name =
                                                            customer_shipments_rec.brand
                                                        AND ROWNUM = 1));
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;

                        l_num_of_picktickets   := l_num_of_picktickets + 1;
                    END IF;                      --end for l_chr_record_exists
                END LOOP;

                IF l_num_of_picktickets > 0
                THEN
                    COMMIT;
                ELSE
                    ROLLBACK;
                END IF;
            END LOOP;
        --Start Added for 1.12
        ELSE                      --IF NVL(lv_odc_org_exists_flag, 'N') <> 'Y'
            FOR customer_shipments_rec
                IN cur_customer_shipments (p_delivery_id, p_organization_id) --Added for 1.16
            LOOP
                --We will get BOL at header level and tracking number at line level and so
                --we can insert data as-is for either LTL or Parcel shipments
                l_chr_bol_number       := p_bol_number;

                --Update BOL
                BEGIN
                    UPDATE wsh_new_deliveries
                       SET waybill   = l_chr_bol_number
                     WHERE delivery_id = customer_shipments_rec.delivery_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                DBMS_OUTPUT.put_line (
                    'Customer ID  :' || customer_shipments_rec.sold_to_org_id);
                DBMS_OUTPUT.put_line ('BOL Number  :' || l_chr_bol_number);
                DBMS_OUTPUT.put_line (
                    'Organization ID  :' || p_organization_id);

                --Validate BOL and Customer Combination exists
                BEGIN
                    SELECT COUNT (1)
                      INTO lv_edi_856_ship_exists
                      FROM do_edi.do_edi856_shipments ship
                     WHERE     1 = 1
                           AND customer_id =
                               customer_shipments_rec.sold_to_org_id
                           AND waybill = l_chr_bol_number
                           AND organization_id = p_organization_id
                           AND NVL (ship_to_dc, 'XXX') =
                               NVL (customer_shipments_rec.ship_to_dc, 'XXX') --added as part of CCR0010347
                           AND NVL (container_number, 'XXX') =
                               NVL (customer_shipments_rec.container_number,
                                    'XXX');      --added as part of CCR0010347
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_edi_856_ship_exists   := NULL;
                END;

                DBMS_OUTPUT.put_line (
                    'lv_edi_856_ship_exists  :' || lv_edi_856_ship_exists);

                IF NVL (lv_edi_856_ship_exists, 0) > 0
                THEN
                    lv_bol_cust_brand_exists   := TRUE;
                ELSE
                    lv_bol_cust_brand_exists   := FALSE;
                END IF;

                IF lv_bol_cust_brand_exists
                THEN
                    --Get shipment_id
                    BEGIN
                        SELECT MAX (shipment_id)
                          INTO ln_old_shipment_id
                          FROM do_edi.do_edi856_shipments ship
                         WHERE     1 = 1
                               AND customer_id =
                                   customer_shipments_rec.sold_to_org_id
                               AND waybill = l_chr_bol_number
                               AND organization_id = p_organization_id
                               AND NVL (ship_to_dc, 'XXX') =
                                   NVL (customer_shipments_rec.ship_to_dc,
                                        'XXX')   --added as part of CCR0010347
                               AND NVL (container_number, 'XXX') =
                                   NVL (
                                       customer_shipments_rec.container_number,
                                       'XXX');   --added as part of CCR0010347
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_old_shipment_id   := NULL;
                    END;

                    DBMS_OUTPUT.put_line (
                        'ln_old_shipment_id  :' || ln_old_shipment_id);

                    IF ln_old_shipment_id IS NOT NULL
                    THEN
                        DBMS_OUTPUT.put_line (
                            'Shipment_ID already exists, SKIP Insertion in EDI856 Shipments TBL ');
                    END IF;
                ELSE                               -- lv_bol_cust_brand_exists
                    l_num_shipment_id   := NULL;
                    --- Get next shipment id
                    do_edi.get_next_values ('DO_EDI856_SHIPMENTS',
                                            1,
                                            l_num_shipment_id);
                    DBMS_OUTPUT.put_line (
                           'new_shipment_id insertion into do_edi856_shipments : '
                        || l_num_shipment_id);

                    BEGIN
                        INSERT INTO do_edi.do_edi856_shipments (
                                        shipment_id,
                                        asn_status,
                                        asn_date,
                                        invoice_date,
                                        customer_id,
                                        ship_to_org_id,
                                        waybill,
                                        tracking_number,
                                        seal_code,
                                        pro_number,
                                        est_delivery_date,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        archive_flag,
                                        organization_id,
                                        location_id,
                                        request_sent_date,
                                        reply_rcv_date,
                                        scheduled_pu_date,
                                        bill_of_lading,
                                        carrier,
                                        carrier_scac,
                                        comments,
                                        confirm_sent_date,
                                        contact_name,
                                        cust_shipment_id,
                                        earliest_pu_date,
                                        latest_pu_date,
                                        load_id,
                                        routing_status,
                                        ship_confirm_date,
                                        shipment_weight,
                                        shipment_weight_uom,
                                        sps_event,
                                        ship_to_dc, --added as part of CCR0010347
                                        container_number --added as part of CCR0010347
                                                        ,
                                        dock_door_event --Added as part of CCR0010347
                                                       )
                                 VALUES (
                                            l_num_shipment_id,
                                            'N',
                                            NULL,
                                            NULL,                        --'R'
                                            customer_shipments_rec.customer_id,
                                            customer_shipments_rec.ship_to_org_id,
                                            l_chr_bol_number,
                                            customer_shipments_rec.tracking_number,
                                            p_seal_code,
                                            p_pro_number,
                                            p_shipment_date + 3,
                                            SYSDATE,
                                            l_user_id,
                                            SYSDATE,
                                            l_user_id,
                                            'N',
                                            p_organization_id,
                                            customer_shipments_rec.location_id,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            p_carrier,
                                            p_carrier_code,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            NULL,
                                            p_load_id,
                                            NULL,
                                            NULL,            --p_shipment_date
                                            NULL,
                                            'LB',
                                            customer_shipments_rec.sps_event,
                                            customer_shipments_rec.ship_to_dc, --added as part of CCR0010347
                                            customer_shipments_rec.container_number --added as part of CCR0010347
                                                                                   ,
                                            'Y'  --Added as part of CCR0010347
                                               );
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
                END IF;                            -- lv_bol_cust_brand_exists

                l_num_of_picktickets   := 0;

                FOR customer_picktickets_rec
                    IN cur_customer_picktickets (p_delivery_id)
                LOOP
                    l_chr_record_exists   := 'N';

                    BEGIN
                        SELECT 'Y'
                          INTO l_chr_record_exists
                          FROM do_edi.do_edi856_pick_tickets
                         WHERE delivery_id = p_delivery_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_chr_record_exists   := 'N';
                    END;

                    IF l_chr_record_exists = 'N'
                    THEN
                        IF ln_old_shipment_id IS NOT NULL
                        THEN
                            DBMS_OUTPUT.put_line (
                                   'old_shipment_id insertion into do_edi856_pick_tickets : '
                                || ln_old_shipment_id);

                            BEGIN
                                INSERT INTO do_edi.do_edi856_pick_tickets (
                                                shipment_id,
                                                delivery_id,
                                                weight,
                                                weight_uom,
                                                number_cartons,
                                                cartons_uom,
                                                volume,
                                                volume_uom,
                                                ordered_qty,
                                                shipped_qty,
                                                shipped_qty_uom,
                                                source_header_id,
                                                intmed_ship_to_org_id,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_updated_by,
                                                archive_flag,
                                                shipment_key)
                                         VALUES (
                                                    ln_old_shipment_id,
                                                    p_delivery_id,
                                                    apps.do_edi_utils_pub.delivery_ship_weight (
                                                        p_delivery_id),
                                                    'LB',
                                                    apps.do_edi_utils_pub.delivery_container_count (
                                                        p_delivery_id),
                                                    'EA',
                                                    apps.do_edi_utils_pub.delivery_ship_volume (
                                                        p_delivery_id),
                                                    'CI',
                                                    customer_picktickets_rec.ordered_quantity,
                                                    customer_picktickets_rec.shipped_quantity,
                                                    'EA',
                                                    customer_picktickets_rec.header_id,
                                                    customer_picktickets_rec.intmed_ship_to_org_id,
                                                    SYSDATE,
                                                    fnd_global.user_id,
                                                    SYSDATE,
                                                    fnd_global.user_id,
                                                    'N',
                                                    (SELECT ln_old_shipment_id || brand_code
                                                       FROM do_custom.do_brands
                                                      WHERE     brand_name =
                                                                customer_shipments_rec.brand
                                                            AND ROWNUM = 1));
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;

                            l_num_of_picktickets   :=
                                l_num_of_picktickets + 1;
                        ELSE               --IF ln_old_shipment_id IS NOT NULL
                            DBMS_OUTPUT.put_line (
                                   'new_shipment_id insertion into do_edi856_pick_tickets : '
                                || l_num_shipment_id);

                            BEGIN
                                INSERT INTO do_edi.do_edi856_pick_tickets (
                                                shipment_id,
                                                delivery_id,
                                                weight,
                                                weight_uom,
                                                number_cartons,
                                                cartons_uom,
                                                volume,
                                                volume_uom,
                                                ordered_qty,
                                                shipped_qty,
                                                shipped_qty_uom,
                                                source_header_id,
                                                intmed_ship_to_org_id,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_updated_by,
                                                archive_flag,
                                                shipment_key)
                                         VALUES (
                                                    l_num_shipment_id,
                                                    p_delivery_id,
                                                    apps.do_edi_utils_pub.delivery_ship_weight (
                                                        p_delivery_id),
                                                    'LB',
                                                    apps.do_edi_utils_pub.delivery_container_count (
                                                        p_delivery_id),
                                                    'EA',
                                                    apps.do_edi_utils_pub.delivery_ship_volume (
                                                        p_delivery_id),
                                                    'CI',
                                                    customer_picktickets_rec.ordered_quantity,
                                                    customer_picktickets_rec.shipped_quantity,
                                                    'EA',
                                                    customer_picktickets_rec.header_id,
                                                    customer_picktickets_rec.intmed_ship_to_org_id,
                                                    SYSDATE,
                                                    fnd_global.user_id,
                                                    SYSDATE,
                                                    fnd_global.user_id,
                                                    'N',
                                                    (SELECT l_num_shipment_id || brand_code
                                                       FROM do_custom.do_brands
                                                      WHERE     brand_name =
                                                                customer_shipments_rec.brand
                                                            AND ROWNUM = 1));
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;

                            l_num_of_picktickets   :=
                                l_num_of_picktickets + 1;
                        END IF;            --IF ln_old_shipment_id IS NOT NULL
                    END IF;                        --l_chr_record_exists = 'N'
                END LOOP;

                DBMS_OUTPUT.put_line (
                    'l_num_of_picktickets : ' || l_num_of_picktickets);

                IF l_num_of_picktickets > 0
                THEN
                    COMMIT;
                ELSE
                    ROLLBACK;
                END IF;
            END LOOP;
        END IF;                   --IF NVL(lv_odc_org_exists_flag, 'N') <> 'Y'
    --End Added for 1.12

    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXP - do_edi856_pick_tickets - Error: ' || SQLERRM);
            x_ret_stat   := 'E';
    END;                                                   --edi_asn_interface

    /******************************************************************************/
    /* Name         : VALID_LOADID_REQ
       /* Type         : FUNCTION (Return : Boolean)
       /* Description  : Function to check LoadID is required or not
       /******************************************************************************/
    FUNCTION valid_loadid_req (p_cust_id IN NUMBER)
        RETURN BOOLEAN
    IS
        l_load_id_req   CHAR (1);
    BEGIN
        /*Check if customer required Load ID or not*/
        msg (LPAD ('.', 58, '.'));
        msg ('Load ID Required for Cusomer ID ' || p_cust_id || ' ?');

        SELECT enabled_flag
          INTO l_load_id_req
          FROM custom.do_edi_lookup_values
         WHERE     lookup_type = '856_LOADID_REQ'
               AND enabled_flag = 'Y'
               AND lookup_code = p_cust_id
               AND ROWNUM < 2;

        msg (LPAD ('.', 58, '.'));
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            msg ('EXP: Load ID Is Not Required ');
            msg (LPAD ('.', 58, '.'));
            RETURN FALSE;
        WHEN OTHERS
        THEN
            msg ('EXP: Others -Error ' || SQLERRM);
            msg (LPAD ('.', 58, '.'));
            RETURN FALSE;
    END valid_loadid_req;

    --Start Added for 1.12
    --Create New Delivery
    PROCEDURE create_delivery (p_delivery_id IN NUMBER, xn_delivery_id OUT NUMBER, pv_errbuf OUT VARCHAR2
                               , pv_retcode OUT VARCHAR2)
    IS
        lv_return_status      VARCHAR2 (30) := NULL;
        ln_msg_count          NUMBER;
        ln_msg_cntr           NUMBER;
        ln_msg_index_out      NUMBER;
        lv_msg_data           VARCHAR2 (2000);
        ln_delivery_id        NUMBER;
        lv_delivery_name      VARCHAR2 (240);
        l_rec_delivery_info   wsh_deliveries_pub.delivery_pub_rec_type;
        ln_trip_id            NUMBER;
        lv_trip_name          VARCHAR2 (240);
        ln_to_stop            NUMBER;

        CURSOR cur_delivery IS
            SELECT wnd.*
              FROM wsh_new_deliveries wnd
             WHERE     1 = 1
                   AND wnd.delivery_id = p_delivery_id
                   --AND wnd.organization_id = gn_inv_org_id
                   AND wnd.status_code = 'OP';
    BEGIN
        --Reset status variables
        pv_retcode   := '0';
        pv_errbuf    := NULL;

        FOR rec_delivery IN cur_delivery
        LOOP
            -- Set record info variables
            l_rec_delivery_info.organization_id   :=
                rec_delivery.organization_id;
            l_rec_delivery_info.customer_id   := rec_delivery.customer_id;
            l_rec_delivery_info.ship_method_code   :=
                rec_delivery.ship_method_code;
            l_rec_delivery_info.initial_pickup_location_id   :=
                rec_delivery.initial_pickup_location_id;
            l_rec_delivery_info.ultimate_dropoff_location_id   :=
                rec_delivery.ultimate_dropoff_location_id;
            l_rec_delivery_info.attribute11   :=
                p_delivery_id;
            --l_rec_delivery_info.waybill    := rec_delivery.waybill;--waybill;
            --l_rec_delivery_info.attribute2 := rec_delivery.attribute2;--carrier;
            --l_rec_delivery_info.attribute1 := rec_delivery.attribute1;--tracking_number;

            msg (' ');
            msg ('Start Calling Create Delivery API..');

            --Calling API to Create Update Delivery
            wsh_deliveries_pub.create_update_delivery (
                p_api_version_number   => 1.0,
                p_init_msg_list        => fnd_api.g_true,
                x_return_status        => lv_return_status,
                x_msg_count            => ln_msg_count,
                x_msg_data             => lv_msg_data,
                p_action_code          => 'CREATE',
                p_delivery_info        => l_rec_delivery_info,
                x_delivery_id          => ln_delivery_id,
                x_name                 => lv_delivery_name);

            IF lv_return_status <> fnd_api.g_ret_sts_success
            THEN
                pv_retcode   := '2';
                pv_errbuf    :=
                       'API to create delivery was failed with status: '
                    || lv_return_status;
                msg ('pv_errbuf : ' || pv_errbuf);

                IF ln_msg_count > 0
                THEN
                    xn_delivery_id   := 0;
                    -- Retrieve messages
                    ln_msg_cntr      := 1;

                    WHILE ln_msg_cntr <= ln_msg_count
                    LOOP
                        fnd_msg_pub.get (
                            p_msg_index       => ln_msg_cntr,
                            p_encoded         => 'F',
                            p_data            => lv_msg_data,
                            p_msg_index_out   => ln_msg_index_out);

                        ln_msg_cntr   := ln_msg_cntr + 1;
                        fnd_file.put_line (fnd_file.LOG,
                                           'Error Message:' || lv_msg_data);
                        msg ('Error Message:' || lv_msg_data);
                    END LOOP;
                END IF;
            ELSE
                pv_errbuf        :=
                       'API to create delivery was successful with status: '
                    || lv_return_status;
                msg ('pv_errbuf :' || pv_errbuf);
                xn_delivery_id   := ln_delivery_id;

                BEGIN
                    --Assigning the delivery detail to new delivery was failing since Source header id is blank on the new delivery created in 12.2.3.
                    --So, Source header id is updated on new delivery */
                    UPDATE wsh_new_deliveries
                       SET source_header_id   = rec_delivery.source_header_id
                     WHERE delivery_id = ln_delivery_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        msg (
                               'Error updating new Delivery ID > '
                            || TO_CHAR (ln_delivery_id)
                            || ' with source header id. Error is: '
                            || SQLERRM);

                        pv_errbuf    :=
                               'Error updating new Delivery ID > '
                            || TO_CHAR (ln_delivery_id)
                            || ' with source header id. Error is: '
                            || SQLERRM;
                        pv_retcode   := '2';
                END;

                msg ('End Calling Create Delivery API..');
                msg (' ');
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    := 'Error while Creation of Delivery.' || SQLERRM;
            msg (
                'EXP: Others- Error while Creation of Delivery :' || SQLERRM);
    END create_delivery;

    --Assign and Unasign Delivery
    PROCEDURE assign_detail_to_delivery (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_delivery_id IN NUMBER
                                         , pv_delivery_name IN VARCHAR2, p_delivery_detail_ids IN wsh_util_core.id_tab_type, pv_action IN VARCHAR2 DEFAULT 'ASSIGN')
    IS
        lv_return_status        VARCHAR2 (30) := NULL;
        ln_msg_count            NUMBER;
        ln_msg_cntr             NUMBER;
        ln_msg_index_out        NUMBER;
        lv_msg_data             VARCHAR2 (2000);
        l_del_details_ids_tab   wsh_delivery_details_pub.id_tab_type;
        l_ex_set_error          EXCEPTION;
    BEGIN
        --Reset status variables
        pv_errbuf    := NULL;
        pv_retcode   := '0';

        --Set delivery detail id
        FOR l_num_ind IN 1 .. p_delivery_detail_ids.COUNT
        LOOP
            l_del_details_ids_tab (l_num_ind)   :=
                p_delivery_detail_ids (l_num_ind);
        END LOOP;

        wsh_delivery_details_pub.detail_to_delivery (
            p_api_version        => 1.0,
            p_init_msg_list      => fnd_api.g_true,
            p_commit             => fnd_api.g_false,
            p_validation_level   => NULL,
            x_return_status      => lv_return_status,
            x_msg_count          => ln_msg_count,
            x_msg_data           => lv_msg_data,
            p_tabofdeldets       => l_del_details_ids_tab,
            p_action             => pv_action,
            p_delivery_id        => pn_delivery_id);

        IF lv_return_status <> fnd_api.g_ret_sts_success
        THEN
            IF ln_msg_count > 0
            THEN
                pv_retcode    := '2';
                pv_errbuf     :=
                       'API to '
                    || LOWER (pv_action)
                    || ' delivery detail id failed with status: '
                    || lv_return_status;
                msg (pv_errbuf);

                -- Retrieve messages
                ln_msg_cntr   := 1;

                WHILE ln_msg_cntr <= ln_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                     , p_msg_index_out => ln_msg_index_out);
                    ln_msg_cntr   := ln_msg_cntr + 1;
                    msg ('Error Message : ' || lv_msg_data);
                END LOOP;
            END IF;
        ELSE
            pv_errbuf   :=
                   'API to '
                || LOWER (pv_action)
                || ' delivery detail was successful with status: '
                || lv_return_status;
            msg (pv_errbuf);

            --- Logic to update the delivery name on the unassigned delivery details
            IF pv_action = 'UNASSIGN'
            THEN
                FOR l_num_ind IN 1 .. p_delivery_detail_ids.COUNT
                LOOP
                    UPDATE wsh_delivery_details wdd
                       SET attribute11   = pv_delivery_name /* VVAP attribute11*/
                     WHERE delivery_detail_id =
                           p_delivery_detail_ids (l_num_ind);
                END LOOP;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                   'Unexpected error while '
                || LOWER (pv_action)
                || 'ing delivery detail.'
                || SQLERRM;
            msg ('EXP: Others -assign_detail_to_delivery');
    END assign_detail_to_delivery;

    --End Added for 1.12

    PROCEDURE process_load_confirmation
    IS
        l_ret_stat                    VARCHAR2 (1);
        l_message                     VARCHAR2 (4000);
        --Changes length 240 to max as per ver 1.2
        l_needs_confirm               NUMBER;
        l_shipments                   shipment_tab;
        l_container                   NUMBER;
        l_remainder                   NUMBER;
        --Added by CC for Canada 3PL Phase-3
        is_carrier_scac_valid         VARCHAR2 (1) := 'N';
        v_ship_method_code            VARCHAR2 (30);
        v_ship_method_meaning         VARCHAR2 (2000);
        is_canada_org                 VARCHAR2 (1) := 'N';
        carrier_scac_failure          EXCEPTION;
        load_id_failure               EXCEPTION;        --Added for CCR0006013
        v_customer_id                 NUMBER;
        v_delivery_detail_id          NUMBER;
        v_released_status             VARCHAR2 (5);
        -- Start Added for CCR0009126
        is_emea_org                   VARCHAR2 (1) := 'N';
        is_valid_3pl_scac             VARCHAR2 (1) := 'N';
        lv_scac_code                  VARCHAR2 (10);
        -- End Added for CCR0009126

        --Added for CCR0006806
        l_holds_t                     do_shipping_tools.hold_source_tbl_type;
        l_header_id                   NUMBER;

        lv_order_type                 VARCHAR2 (100) := NULL;
        lv_odc_org_exists             VARCHAR2 (10) := 'N';

        --Start Added for 1.12
        ln_line_count                 NUMBER := 0;
        ln_count_unasin               NUMBER := 0;
        ln_validate_cartons           NUMBER := 0;
        ln_multi_cartons              NUMBER := 0;
        ln_validate_lines_split       NUMBER := 0;
        ln_validate_qty_split         NUMBER := 0;
        ln_lines_qty_split            NUMBER := 0;
        lv_errbuf                     VARCHAR2 (4000) := NULL;
        lv_retcode                    VARCHAR2 (10) := 0;
        ln_new_delivery_id            NUMBER := NULL;
        l_undership_del_dtl_ids_tab   tabtype_id;
        lv_delivery_detail_ids        wsh_util_core.id_tab_type;
        lv_delvry_detail_ids          wsh_util_core.id_tab_type;
        lv_mc_del_dtl_ids             wsh_util_core.id_tab_type;
        lv_split_shipments_ret_stat   VARCHAR2 (1);
        lv_split_flag                 VARCHAR2 (1);
        lv_origin_hub_org             VARCHAR2 (1) := 'N';
    --End Added for 1.12

    BEGIN
        FOR c_header
            IN (SELECT h.osc_header_id, h.source_header_id, h.ship_confirm_date,
                       h.carrier, h.organization_id, h.customer_reference,
                       --Added by CC for Canada 3PL Phase-3
                       h.carrier_code, h.shipping_method, h.bol_number,
                       h.freight_charges, --Changes completed,
                                          --Added for the CCR0006013
                                          h.pro_number,          -- CCR0008925
                                                        --Start Added for 1.12
                                                        h.container_number,
                       h.seal_number, --End Added for 1.12
                                      h.load_id
                  FROM xxdo.xxdo_wms_3pl_osc_h h
                 WHERE     h.process_status = 'P'
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM xxdo.xxdo_wms_3pl_osc_l l2
                                 WHERE     l2.osc_header_id = h.osc_header_id
                                       AND l2.process_status != 'P')
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM xxdo.xxdo_wms_3pl_osc_l l2
                                 WHERE     l2.osc_header_id = h.osc_header_id
                                       AND l2.processing_session_id !=
                                           h.processing_session_id)
                       AND h.processing_session_id = USERENV ('SESSIONID'))
        LOOP
            BEGIN
                msg ('process_load_confirmation starts ');
                l_ret_stat   := g_ret_success;
                SAVEPOINT begin_header;

                BEGIN
                    BEGIN
                        l_needs_confirm   := 0;

                        SELECT MAX (1)
                          INTO l_needs_confirm
                          FROM apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd
                         WHERE     wda.delivery_id =
                                   c_header.source_header_id
                               AND wdd.delivery_detail_id =
                                   wda.delivery_detail_id
                               AND wdd.source_code = 'OE'
                               AND wdd.released_status = 'S'
                               AND ROWNUM = 1;

                        --Start changes for 1.16
                        lv_odc_org_exists   :=
                            validate_odc_org_exists (
                                c_header.osc_header_id,
                                c_header.organization_id);

                        get_odc_order_type (c_header.osc_header_id,
                                            lv_odc_org_exists,
                                            lv_order_type);

                        msg (
                               'osc_header_id : '
                            || c_header.osc_header_id
                            || ' and order_id : '
                            || c_header.source_header_id);
                        msg (
                               'lv_order_type :'
                            || lv_order_type
                            || ' OR lv_odc_org_exists : '
                            || lv_odc_org_exists);

                        IF NVL (lv_odc_org_exists, 'N') = 'Y'
                        THEN
                            IF (NVL (lv_order_type, 'NA') <> 'ODC_BACKORDERED')
                            THEN
                                lv_origin_hub_org   := 'Y';
                            ELSE
                                lv_origin_hub_org   := 'N';
                            END IF;
                        END IF;

                        --End changes for 1.16

                        msg (
                               'lv_origin_hub_org :'
                            || lv_origin_hub_org
                            || ' and l_needs_confirm : '
                            || NVL (l_needs_confirm, 0));

                        IF     NVL (l_needs_confirm, 0) = 1
                           AND NVL (lv_origin_hub_org, 'N') <> 'Y' --Added for 1.12
                        THEN
                            msg ('Calling pick confirm delivery start ');
                            l_ret_stat   :=
                                pick_confirm_delivery (
                                    c_header.source_header_id);
                            msg (
                                   'pick_confirm_delivery -l_ret_stat : '
                                || l_ret_stat);

                            --Start Added for 1.12
                            IF NVL (lv_order_type, 'NA') = 'ODC_BACKORDERED'
                            THEN
                                l_ret_stat   := g_ret_success;
                                msg (
                                       'pick_confirm_delivery(ODC_BACKORDERED)- l_ret_stat : '
                                    || l_ret_stat);
                            END IF;

                            --End Added for 1.12

                            msg ('Calling pick confirm delivery end ');
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg (
                                   'EXP - ROLLBACK TO begin_header '
                                || 'Header failed to pick-confirm ');
                            ROLLBACK TO begin_header;
                            l_ret_stat   := g_ret_unexp_error;
                            l_message    := SQLERRM;

                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_osc_h
                                   SET process_status = 'E', error_message = 'Header failed to pick-confirm'
                                 WHERE osc_header_id = c_header.osc_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;

                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_osc_l
                                   SET process_status = 'E', error_message = 'Header failed to pick-confirm'
                                 WHERE osc_header_id = c_header.osc_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;
                    END;

                    EXIT WHEN l_ret_stat != g_ret_success;

                    IF c_header.customer_reference IS NOT NULL
                    THEN
                        -- Update customer PO #
                        change_cust_po_number (p_osc_header_id => c_header.osc_header_id, p_cust_po_number => c_header.customer_reference, x_ret_stat => l_ret_stat
                                               , x_message => l_message);

                        IF NVL (l_ret_stat, g_ret_error) != g_ret_success
                        THEN
                            msg (
                                   'EXP - ROLLBACK TO begin_header '
                                || 'Failed to update customer PO #.');
                            ROLLBACK TO begin_header;

                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_osc_h
                                   SET process_status = 'E', error_message = 'Failed to update customer PO #.' || DECODE (l_message, NULL, NULL, '  ' || l_message)
                                 WHERE osc_header_id = c_header.osc_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;

                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_osc_l
                                   SET process_status = 'E', error_message = 'Failed to update customer PO #.' || DECODE (l_message, NULL, NULL, '  ' || l_message)
                                 WHERE osc_header_id = c_header.osc_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;
                        END IF;

                        EXIT WHEN l_ret_stat != g_ret_success;
                    END IF;

                    /* --Start commented for 1.12
                    --Begin CCR0008925
                    IF c_header.pro_number IS NOT NULL
                    THEN
                       UPDATE wsh_new_deliveries
                          SET attribute15 = c_header.pro_number
                        WHERE delivery_id = c_header.source_header_id;
                    END IF;
           --End CCR0008925
           */
                    --End commented for 1.12

                    --Start Added for 1.12
                    --Validate Multiple Containers exists
                    --IF partial quantity, new delivery creation process
                    ln_validate_cartons       :=
                        validate_multi_cartons (
                            p_source_header_id => c_header.source_header_id);
                    ln_multi_cartons          := ln_validate_cartons;


                    --Validate SKU Lines qty split
                    ln_validate_qty_split     :=
                        validate_lines_qty_split (
                            p_source_header_id => c_header.source_header_id);

                    --Validate SKU Lines split
                    ln_validate_lines_split   :=
                        validate_lines_split (
                            p_source_header_id => c_header.source_header_id);

                    --Validate, If split then new delivery creation process
                    IF (NVL (ln_validate_lines_split, 0) > 0 OR NVL (ln_validate_qty_split, 0) > 0)
                    THEN
                        ln_lines_qty_split   := 1;
                    ELSE
                        ln_lines_qty_split   := 0;
                    END IF;

                    ln_new_delivery_id        := NULL;
                    msg ('ln_validate_cartons :' || ln_validate_cartons);
                    msg ('ln_validate_qty_split :' || ln_validate_qty_split);
                    msg (
                           'ln_validate_lines_split :'
                        || ln_validate_lines_split);
                    msg ('ln_lines_qty_split :' || ln_lines_qty_split);

                    --End Added for 1.12

                    FOR c_container
                        IN (SELECT DISTINCT NVL (l.carton_number, NVL (l.tracking_number, 'NoContainer-' || c_header.source_header_id)) carton_number, l.tracking_number
                              FROM xxdo.xxdo_wms_3pl_osc_l l
                             WHERE     l.osc_header_id =
                                       c_header.osc_header_id
                                   AND l.process_status = 'P'
                                   AND l.processing_session_id =
                                       USERENV ('SESSIONID')
                                   AND l.qty_shipped != 0--CCR1535 -- Backorder lines with 0 quantity --
                                                         )
                    LOOP
                        l_shipments.DELETE;
                        msg (
                            '=======================================================');
                        msg (
                               'container loop.  carton # = '
                            || c_container.carton_number
                            || ', tracking # = '
                            || c_container.tracking_number);

                        FOR c_line
                            IN (  SELECT l.source_line_id, l.inventory_item_id, SUM (l.quantity_to_ship) quantity_to_ship
                                    FROM xxdo.xxdo_wms_3pl_osc_l l
                                   WHERE     l.osc_header_id =
                                             c_header.osc_header_id
                                         AND l.process_status = 'P'
                                         AND l.processing_session_id =
                                             USERENV ('SESSIONID')
                                         AND l.qty_shipped != 0
                                         --CCR1535 -- Backorder lines with 0 quantity --
                                         AND NVL (
                                                 l.carton_number,
                                                 NVL (
                                                     l.tracking_number,
                                                        'NoContainer-'
                                                     || c_header.source_header_id)) =
                                             c_container.carton_number
                                GROUP BY l.source_line_id, l.inventory_item_id)
                        LOOP
                            BEGIN
                                l_remainder   := c_line.quantity_to_ship;
                                msg (
                                       'container line loop.  source_line_id = '
                                    || c_line.source_line_id
                                    || ', item_id = '
                                    || c_line.inventory_item_id
                                    || ', quantity = '
                                    || c_line.quantity_to_ship);

                                FOR c_detail
                                    IN (SELECT wdd.delivery_detail_id, GREATEST (NVL (wdd.requested_quantity, 0) - NVL (wdd.shipped_quantity, 0), 0) quantity
                                          FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
                                         WHERE     GREATEST (
                                                         NVL (
                                                             wdd.requested_quantity,
                                                             0)
                                                       - NVL (
                                                             wdd.shipped_quantity,
                                                             0),
                                                       0) >
                                                   0
                                               AND wdd.source_code = 'OE'
                                               AND wdd.source_line_id =
                                                   c_line.source_line_id
                                               AND wdd.released_status = --'Y'         -- Commented for 1.12
                                                   DECODE (
                                                       NVL (
                                                           lv_origin_hub_org,
                                                           'N'),
                                                       'Y', 'S',
                                                       'Y')  -- Added for 1.12
                                               --CCR0001800 -- Support for partially picked lines--
                                               AND wda.delivery_detail_id =
                                                   wdd.delivery_detail_id
                                               AND wda.delivery_id =
                                                   c_header.source_header_id--CCR0001800 -- Support for partially picked lines--
                                                                            )
                                LOOP
                                    msg (
                                           'container detail loop.  delivery_detail_id = '
                                        || c_detail.delivery_detail_id
                                        || ', quantity = '
                                        || c_detail.quantity);
                                    l_shipments (l_shipments.COUNT + 1).delivery_detail_id   :=
                                        c_detail.delivery_detail_id;
                                    l_shipments (l_shipments.COUNT).inventory_item_id   :=
                                        c_line.inventory_item_id;
                                    l_shipments (l_shipments.COUNT).quantity   :=
                                        LEAST (l_remainder,
                                               c_detail.quantity);
                                    l_remainder   :=
                                          l_remainder
                                        - l_shipments (l_shipments.COUNT).quantity;
                                    EXIT WHEN l_remainder <= 0;
                                END LOOP;

                                IF l_shipments.COUNT <> 0
                                THEN ---BT Team: Entered the condition for testing
                                    l_shipments (l_shipments.COUNT).quantity   :=
                                          l_shipments (l_shipments.COUNT).quantity
                                        + l_remainder;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    msg (
                                        'EXP - cursor c_line loop begin exception ');
                                    l_ret_stat   := g_ret_error;
                                    l_message    := SQLERRM;
                            END;

                            EXIT WHEN l_ret_stat != g_ret_success;

                            IF l_ret_stat = g_ret_success
                            THEN
                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_osc_l l
                                       SET process_status = 'S', error_message = 'Processing Complete'
                                     WHERE     l.osc_header_id =
                                               c_header.osc_header_id
                                           AND l.source_line_id =
                                               c_line.source_line_id
                                           AND NVL (
                                                   l.carton_number,
                                                   NVL (
                                                       l.tracking_number,
                                                          'NoContainer-'
                                                       || c_header.source_header_id)) =
                                               c_container.carton_number;
                                -- 6/24/2011 -- KWG -- Defect fix for issue with a single line being packed into multiple cartons --
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_ret_stat   := g_ret_error;
                                        l_message    := SQLERRM;
                                END;
                            END IF;
                        END LOOP;

                        BEGIN
                            IF l_ret_stat = g_ret_success
                            THEN
                                /* --Start Commented for CCR0009126
                                --Added by CC for Canada 3PL Phase-3
                                --Validate Carrier SCAC and Ship method and then call pack_container
                                BEGIN
                                   SELECT 'Y'
                                     INTO is_canada_org
                                     FROM apps.mtl_parameters
                                    WHERE     organization_id =
                                                 c_header.organization_id
                                          AND organization_code = 'CA2';

                                   IF is_canada_org = 'Y'
                                   THEN
                                      BEGIN
                                         SELECT 'Y'
                                           INTO is_carrier_scac_valid
                                           FROM apps.wsh_carriers
                                          WHERE scac_code = c_header.carrier_code;
                                      EXCEPTION
                                         WHEN OTHERS
                                         THEN
                                            is_carrier_scac_valid := 'N';
                                      END;

                                      IF is_carrier_scac_valid = 'Y'
                                      THEN
                                         BEGIN
                                            SELECT wcs.ship_method_code,
                                                   wcs.ship_method_meaning
                                              INTO v_ship_method_code,
                                                   v_ship_method_meaning
                                              FROM apps.wsh_carriers wc,
                                                   apps.WSH_CARRIER_SERVICES wcs
                                             WHERE     wc.carrier_id = wcs.carrier_id
                                                   --and     wc.scac_code = c_header.carrier_code
                                                   AND wcs.ship_method_meaning =
                                                          c_header.shipping_method;
                                         EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                               v_ship_method_code := NULL;
                                               v_ship_method_meaning := NULL;
                                         END;
                                      ELSE
                                         --update osc header and line tables withe error status
                                         ROLLBACK TO begin_header;

                                         BEGIN
                                            UPDATE xxdo.xxdo_wms_3pl_osc_h
                                               SET process_status = 'E',
                                                   error_message =
                                                      'One or more containers failed to process'
                                             WHERE osc_header_id =
                                                      c_header.osc_header_id;
                                         EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                               NULL;
                                         END;

                                         BEGIN
                                            UPDATE xxdo.xxdo_wms_3pl_osc_l
                                               SET process_status = 'E',
                                                   error_message =
                                                      'Invalid Carrier SCAC code'
                                             WHERE osc_header_id =
                                                      c_header.osc_header_id;
                                         EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                               NULL;
                                         END;

                                         RAISE carrier_scac_failure;
                                      END IF;
                                   END IF;                     --End for is_canada_org
                                EXCEPTION
                                   WHEN OTHERS
                                   THEN
                                      is_canada_org := 'N';
                                END;
                                */
                                --End Commented for CCR0009126

                                --Start Added for CCR0009126
                                --Added for 3PL CA and EMEA(ME3), Validate Carrier SCAC and Ship method and then call pack_container
                                BEGIN
                                    --Validate 3pl SCAC code in Lookup
                                    BEGIN
                                        SELECT 'Y'
                                          INTO is_valid_3pl_scac
                                          FROM fnd_lookup_values flv, mtl_parameters mp
                                         WHERE     1 = 1
                                               AND flv.lookup_type =
                                                   'XXDO_WMS_3PL_EDI_ASN_MAP'
                                               AND flv.LANGUAGE = 'US'
                                               AND flv.enabled_flag = 'Y'
                                               AND mp.organization_id =
                                                   c_header.organization_id
                                               AND mp.organization_code =
                                                   flv.lookup_code
                                               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                               NVL (
                                                                                   flv.start_date_active,
                                                                                   SYSDATE))
                                                                       AND TRUNC (
                                                                               NVL (
                                                                                   flv.end_date_active,
                                                                                   SYSDATE));
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            is_valid_3pl_scac   := 'N';
                                    END;

                                    IF is_valid_3pl_scac = 'Y'
                                    THEN
                                        BEGIN
                                            SELECT wcs.ship_method_code, wcs.ship_method_meaning
                                              INTO v_ship_method_code, v_ship_method_meaning
                                              FROM apps.wsh_carriers wc, apps.wsh_carrier_services wcs
                                             WHERE     wc.carrier_id =
                                                       wcs.carrier_id
                                                   AND wcs.ship_method_meaning =
                                                       c_header.shipping_method;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                v_ship_method_code   := NULL;
                                                v_ship_method_meaning   :=
                                                    NULL;
                                        END;

                                        --To validate SCAC Exists
                                        BEGIN
                                            SELECT 'Y'
                                              INTO is_carrier_scac_valid
                                              FROM apps.wsh_carriers
                                             WHERE scac_code =
                                                   c_header.carrier_code;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                is_carrier_scac_valid   :=
                                                    'N';
                                        END;

                                        IF NVL (is_carrier_scac_valid, 'N') =
                                           'N'
                                        THEN
                                            BEGIN
                                                SELECT DISTINCT wc.scac_code
                                                  INTO lv_scac_code
                                                  FROM apps.wsh_carrier_ship_methods_v wcsm, apps.wsh_carriers_v wc
                                                 WHERE     wcsm.carrier_id =
                                                           wc.carrier_id
                                                       AND ship_method_code =
                                                           v_ship_method_code;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    lv_scac_code   := NULL;
                                            END;
                                        ELSE
                                            lv_scac_code   :=
                                                c_header.carrier_code;
                                        END IF;

                                        IF lv_scac_code IS NULL
                                        THEN
                                            --update osc header and line tables withe error status
                                            ROLLBACK TO begin_header;

                                            BEGIN
                                                UPDATE xxdo.xxdo_wms_3pl_osc_h
                                                   SET process_status = 'E', error_message = 'One or more containers failed to process'
                                                 WHERE osc_header_id =
                                                       c_header.osc_header_id;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    NULL;
                                            END;

                                            BEGIN
                                                UPDATE xxdo.xxdo_wms_3pl_osc_l
                                                   SET process_status = 'E', error_message = 'Invalid Carrier SCAC code'
                                                 WHERE osc_header_id =
                                                       c_header.osc_header_id;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    NULL;
                                            END;

                                            RAISE carrier_scac_failure;
                                        END IF;
                                    END IF;        --End for is_valid_3pl_scac
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        is_valid_3pl_scac   := 'N';
                                END;

                                --End Added for CCR0009126

                                ----------------------------------------------------------------------------------------------------------------
                                --Added for CCR0006806
                                SELECT MAX (wdd.source_header_id)
                                  INTO l_header_id
                                  FROM apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda
                                 WHERE     wda.delivery_id =
                                           c_header.source_header_id
                                       AND wdd.delivery_detail_id =
                                           wda.delivery_detail_id
                                       AND wdd.source_code = 'OE';

                                --apps.XXDO_3PL_DEBUG_PROCEDURE('Before calling remove_holds..');
                                --apps.XXDO_3PL_DEBUG_PROCEDURE('Before calling remove_holds..delivery_id :'||c_header.source_header_id);
                                --apps.XXDO_3PL_DEBUG_PROCEDURE('Before calling remove_holds..order header id:'||l_header_id);
                                l_holds_t   :=
                                    do_shipping_tools.remove_holds (
                                        l_header_id);

                                --apps.XXDO_3PL_DEBUG_PROCEDURE('After calling remove_holds..');

                                --Start Added for 1.12
                                IF l_shipments.COUNT = 0
                                THEN
                                    l_ret_stat   := g_ret_error;
                                    msg (
                                        '=======================================================');
                                    msg ('l_shipments.COUNT = 0');
                                    msg (
                                        'Raise Error- One or more lines shipping quantity lesser then requested quantity');
                                    msg (
                                        '=======================================================');
                                END IF;

                                IF NVL (l_ret_stat, g_ret_success) =
                                   g_ret_success      --l_shipments.COUNT <> 0
                                THEN
                                    --msg (lv_order_type :'|| lv_order_type ||' and lv_odc_org_exists :'||lv_odc_org_exists);
                                    IF (NVL (lv_odc_org_exists, 'N') = 'Y' AND NVL (lv_order_type, 'NA') <> 'ODC_BACKORDERED')
                                    THEN
                                        msg (
                                            '=======================================================');
                                        msg (
                                            'Calling Orgin Hub Split Shipments start ');
                                        --Calling Orgin Hub Split Shipments
                                        origin_hub_split_shipments (
                                            l_shipments,
                                            c_header.carrier,
                                            lv_scac_code,
                                            v_ship_method_code,
                                            c_container.tracking_number,
                                            c_header.ship_confirm_date,
                                            lv_delivery_detail_ids,
                                            lv_split_shipments_ret_stat,
                                            lv_split_flag);
                                        msg (
                                            'Calling Orgin Hub Split Shipments end ');
                                        msg (
                                            '=======================================================');
                                        msg (
                                               'SESSIONID '
                                            || USERENV ('SESSIONID')
                                            || ' and c_header.source_header_id '
                                            || c_header.source_header_id);
                                        msg (
                                               'ln_lines_qty_split :'
                                            || ln_lines_qty_split
                                            || ' OR Return lv_split_flag :'
                                            || lv_split_flag);

                                        IF (ln_lines_qty_split > 0 OR lv_split_flag = 'Y')
                                        THEN
                                            --ln_multi_cartons := ln_validate_cartons;
                                            msg (
                                                   'ln_multi_cartons :'
                                                || ln_multi_cartons);

                                            IF NVL (ln_multi_cartons, 0) > 0
                                            THEN
                                                --Calling create new delivery
                                                create_delivery (
                                                    p_delivery_id   =>
                                                        c_header.source_header_id,
                                                    xn_delivery_id   =>
                                                        ln_new_delivery_id,
                                                    pv_errbuf    => lv_errbuf,
                                                    pv_retcode   => lv_retcode);
                                                msg (
                                                       'New Delivery_Id Created :  '
                                                    || ln_new_delivery_id);
                                            ELSE
                                                msg (
                                                    'multi cartons none -Skip new delivery creation process');
                                            END IF;

                                            --Nullify once delivery is created
                                            ln_multi_cartons   := 0;

                                            --ln_lines_qty_split := 0;
                                            IF ln_new_delivery_id IS NOT NULL
                                            THEN
                                                ---------------------------------------------------------------
                                                --Start UNASSIGN and ASSIGN Delivery Logic
                                                ---------------------------------------------------------------
                                                msg (
                                                    'UNASSIGN and ASSIGN Delivery Logic Start ');

                                                BEGIN
                                                    SELECT COUNT (1)
                                                      INTO ln_count_unasin
                                                      FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
                                                     WHERE     GREATEST (
                                                                     NVL (
                                                                         wdd.requested_quantity,
                                                                         0)
                                                                   - NVL (
                                                                         wdd.shipped_quantity,
                                                                         0),
                                                                   0) >
                                                               0
                                                           AND wdd.source_code =
                                                               'OE'
                                                           AND wdd.released_status =
                                                               'Y'   --RECHECK
                                                           AND wda.delivery_detail_id =
                                                               wdd.delivery_detail_id
                                                           AND wda.delivery_id =
                                                               c_header.source_header_id
                                                           AND EXISTS
                                                                   (SELECT 1
                                                                      FROM xxdo.xxdo_wms_3pl_osc_h h, xxdo.xxdo_wms_3pl_osc_l l
                                                                     WHERE     h.osc_header_id =
                                                                               l.osc_header_id
                                                                           AND h.source_header_id =
                                                                               c_header.source_header_id
                                                                           AND l.source_line_id =
                                                                               wdd.source_line_id
                                                                           AND l.process_status =
                                                                               'S'
                                                                           AND l.processing_session_id =
                                                                               USERENV (
                                                                                   'SESSIONID')
                                                                           AND l.qty_shipped !=
                                                                               0);
                                                EXCEPTION
                                                    WHEN OTHERS
                                                    THEN
                                                        ln_count_unasin   :=
                                                            0;
                                                END;

                                                msg (
                                                       'ln_count_unassign :'
                                                    || ln_count_unasin);

                                                IF (NVL (ln_count_unasin, 0) > 0)
                                                THEN
                                                    FOR c_unassin_detail
                                                        IN (SELECT wda.delivery_detail_id, wda.delivery_id
                                                              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
                                                             WHERE     GREATEST (
                                                                             NVL (
                                                                                 wdd.requested_quantity,
                                                                                 0)
                                                                           - NVL (
                                                                                 wdd.shipped_quantity,
                                                                                 0),
                                                                           0) >
                                                                       0
                                                                   AND wdd.source_code =
                                                                       'OE'
                                                                   AND wdd.released_status =
                                                                       'Y' --RECHECK
                                                                   AND wda.delivery_detail_id =
                                                                       wdd.delivery_detail_id
                                                                   AND wda.delivery_id =
                                                                       c_header.source_header_id
                                                                   AND EXISTS
                                                                           (SELECT 1
                                                                              FROM xxdo.xxdo_wms_3pl_osc_h h, xxdo.xxdo_wms_3pl_osc_l l
                                                                             WHERE     h.osc_header_id =
                                                                                       l.osc_header_id
                                                                                   AND h.source_header_id =
                                                                                       c_header.source_header_id
                                                                                   AND l.source_line_id =
                                                                                       wdd.source_line_id
                                                                                   AND l.process_status =
                                                                                       'S'
                                                                                   AND l.processing_session_id =
                                                                                       USERENV (
                                                                                           'SESSIONID')
                                                                                   AND l.qty_shipped !=
                                                                                       0))
                                                    LOOP
                                                        lv_delvry_detail_ids (
                                                            1)   :=
                                                            c_unassin_detail.delivery_detail_id;
                                                        msg (
                                                            'Calling unassign detail to delivery');
                                                        msg (
                                                               'Unassign delivery_detail_id :'
                                                            || c_unassin_detail.delivery_detail_id
                                                            || ' from Delivery_Id : '
                                                            || c_unassin_detail.delivery_id);

                                                        BEGIN
                                                            assign_detail_to_delivery (
                                                                pv_errbuf   =>
                                                                    lv_errbuf,
                                                                pv_retcode   =>
                                                                    lv_retcode,
                                                                pn_delivery_id   =>
                                                                    c_unassin_detail.delivery_id,
                                                                pv_delivery_name   =>
                                                                    NULL,
                                                                p_delivery_detail_ids   =>
                                                                    lv_delvry_detail_ids,
                                                                pv_action   =>
                                                                    'UNASSIGN');
                                                        EXCEPTION
                                                            WHEN OTHERS
                                                            THEN
                                                                msg (
                                                                       ' Error UNASSIGN  :'
                                                                    || SQLERRM);
                                                        END;

                                                        msg (
                                                            'Calling assign detail to delivery');
                                                        msg (
                                                               'Assign delivery_detail_id :'
                                                            || c_unassin_detail.delivery_detail_id
                                                            || ' to Delivery_Id : '
                                                            || ln_new_delivery_id);

                                                        BEGIN
                                                            assign_detail_to_delivery (
                                                                pv_errbuf   =>
                                                                    lv_errbuf,
                                                                pv_retcode   =>
                                                                    lv_retcode,
                                                                pn_delivery_id   =>
                                                                    ln_new_delivery_id, --new created delivery
                                                                pv_delivery_name   =>
                                                                    NULL,
                                                                p_delivery_detail_ids   =>
                                                                    lv_delvry_detail_ids,
                                                                pv_action   =>
                                                                    'ASSIGN');
                                                        EXCEPTION
                                                            WHEN OTHERS
                                                            THEN
                                                                msg (
                                                                       ' Error UNASSIGN  :'
                                                                    || SQLERRM);
                                                        END;
                                                    END LOOP;
                                                END IF;

                                                msg (
                                                    'UNASSIGN and ASSIGN Delivery Logic End ');
                                            ---------------------------------------------------------------
                                            ---End UNASSIGN and ASSIGN Delivery Logic
                                            ---------------------------------------------------------------
                                            END IF; --IF ln_new_delivery_id IS NOT NULL
                                        END IF; --IF(ln_lines_qty_split > 0  OR lv_split_flag = 'Y')
                                    END IF; --IF NVL(lv_odc_org_exists, 'N') = 'Y'
                                END IF; --IF NVL (l_ret_stat, g_ret_success) = g_ret_success

                                -- End Added for 1.12

                                ----------------------------------------------------------------------------------------------------------------

                                --apps.XXDO_3PL_DEBUG_PROCEDURE('Before calling pack_container..');
                                -------------------------------------------------------------------------------------------------------------
                                --Changes completed
                                --Start Added for 1.12
                                IF l_shipments.COUNT <> 0
                                THEN
                                    msg (
                                        '=======================================================');
                                    msg ('Calling pack container start ');
                                    msg ('l_shipments.COUNT <> 0');
                                    msg (
                                           'ln_new_delivery_id :'
                                        || ln_new_delivery_id
                                        || ' OR c_header.source_header_id :'
                                        || c_header.source_header_id);
                                    --End Added for 1.12

                                    pack_container (
                                        p_delivery_id        =>
                                            NVL (ln_new_delivery_id,
                                                 c_header.source_header_id), --Added for 1.12
                                        p_osc_hdr_id         =>
                                            c_header.osc_header_id,
                                        --Added as per ver 1.1
                                        p_container_name     =>
                                            c_container.carton_number,
                                        p_shipments          => l_shipments,
                                        p_freight_cost       => 0,
                                        p_container_weight   => 0,
                                        p_tracking_number    =>
                                            c_container.tracking_number,
                                        p_carrier            =>
                                            c_header.carrier,
                                        --p_carrier_code       => c_header.carrier_code, -- Added by CC for Canada Phase-3
                                        p_carrier_code       => lv_scac_code,
                                        -- Added for CCR0009126
                                        p_shipping_method    =>
                                            v_ship_method_code,
                                        p_freight_charges    =>
                                            c_header.freight_charges,
                                        --Changes completed Canada Phase-3
                                        p_shipment_date      =>
                                            c_header.ship_confirm_date,
                                        x_container_id       => l_container,
                                        x_ret_stat           => l_ret_stat,
                                        p_organization_id    =>
                                            c_header.organization_id,
                                        p_delivery_ids       =>
                                            lv_delivery_detail_ids --Added For 1.12
                                                                  );

                                    msg ('Calling pack container end ');
                                END IF; --IF l_shipments.COUNT <> 0    --End Added for 1.12
                            END IF;                       --End for l_ret_stat
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                msg ('EXP - pack_container ');
                                l_ret_stat   := g_ret_unexp_error;
                                l_message    := SQLERRM;
                        END;

                        msg (
                               'delivery_id :'
                            || NVL (ln_new_delivery_id,
                                    c_header.source_header_id)
                            || ' and pack_container l_ret_stat :'
                            || l_ret_stat);

                        --apps.XXDO_3PL_DEBUG_PROCEDURE('After calling pack_container.., status :'||l_ret_stat);
                        IF NVL (l_ret_stat, g_ret_unexp_error) !=
                           g_ret_success
                        THEN
                            ROLLBACK TO begin_header;                --RECHECK

                            --Start Added for 1.12
                            IF l_shipments.COUNT = 0
                            THEN
                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_osc_h
                                       SET process_status = 'E', error_message = 'One or more lines quantity is lesser, failed to process'
                                     WHERE osc_header_id =
                                           c_header.osc_header_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;

                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_osc_l
                                       SET process_status = 'E', error_message = 'One or more lines quantity is lesser, failed to process'
                                     WHERE osc_header_id =
                                           c_header.osc_header_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;
                            ELSE
                                --End Added for 1.12
                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_osc_h
                                       SET process_status = 'E', error_message = 'One or more containers failed to process'
                                     WHERE osc_header_id =
                                           c_header.osc_header_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;

                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_osc_l
                                       SET process_status = 'E', error_message = 'One or more containers failed to process'
                                     WHERE osc_header_id =
                                           c_header.osc_header_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;
                            END IF;                       --End Added for 1.12
                        END IF;
                    END LOOP;
                END LOOP;

                IF l_ret_stat = g_ret_success
                THEN
                    --Start Added for 1.12
                    IF ln_new_delivery_id IS NOT NULL
                    THEN
                        --Update new delivery in osc_h
                        BEGIN
                            UPDATE xxdo.xxdo_wms_3pl_osc_h
                               SET original_delivery = order_id, order_id = ln_new_delivery_id
                             WHERE osc_header_id = c_header.osc_header_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;

                        --Update attribute4 for NOT transmit the delivery to KN-US7
                        BEGIN
                            UPDATE wsh_new_deliveries
                               SET attribute4   = 'EXTRACTED'
                             WHERE delivery_id = ln_new_delivery_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                msg (
                                       'Updation failed for attribute4(asn_status) in wsh_new_deliveries - '
                                    || SQLERRM);
                        END;

                        IF c_header.pro_number IS NOT NULL
                        THEN
                            BEGIN
                                UPDATE wsh_new_deliveries
                                   SET attribute15   = c_header.pro_number
                                 WHERE delivery_id = ln_new_delivery_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    msg (
                                           'Updation failed for attribute15(pro_number) in wsh_new_deliveries - '
                                        || SQLERRM);
                            END;
                        END IF;

                        IF c_header.container_number IS NOT NULL
                        THEN
                            BEGIN
                                UPDATE wsh_new_deliveries
                                   SET attribute9 = c_header.container_number
                                 WHERE delivery_id = ln_new_delivery_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    msg (
                                           'Updation failed for attribute9(container_number) in wsh_new_deliveries - '
                                        || SQLERRM);
                            END;
                        END IF;
                    ELSE
                        --Update attribute4 for NOT transmit the delivery to KN-US7
                        BEGIN
                            UPDATE wsh_new_deliveries
                               SET attribute4   = 'EXTRACTED'
                             WHERE delivery_id = c_header.source_header_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                msg (
                                       'Updation failed for attribute4(asn_status) in wsh_new_deliveries - '
                                    || SQLERRM);
                        END;

                        IF c_header.pro_number IS NOT NULL
                        THEN
                            BEGIN
                                UPDATE wsh_new_deliveries
                                   SET attribute15   = c_header.pro_number
                                 WHERE delivery_id =
                                       c_header.source_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    msg (
                                           'Updation failed for attribute15(pro_number) in wsh_new_deliveries - '
                                        || SQLERRM);
                            END;
                        END IF;

                        IF c_header.container_number IS NOT NULL
                        THEN
                            BEGIN
                                UPDATE wsh_new_deliveries
                                   SET attribute9 = c_header.container_number
                                 WHERE delivery_id =
                                       c_header.source_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    msg (
                                           'Updation failed for attribute9(container_number) in wsh_new_deliveries - '
                                        || SQLERRM);
                            END;
                        END IF;
                    END IF;                --IF ln_new_delivery_id IS NOT NULL

                    --End Added for 1.12

                    BEGIN
                        --Begin CCR0008762
                        --Load EDI tables based on lookup
                        /*     BEGIN
                                SELECT 'Y'
                                  INTO is_canada_org
                                  FROM apps.mtl_parameters
                                 WHERE     organization_id = c_header.organization_id
                                       AND organization_code = 'CA2';
                             EXCEPTION
                                WHEN OTHERS
                                THEN
                                   is_canada_org := 'N';
                             END;*/

                        --end CCR0008762

                        --Begin CCR0008762
                        msg (
                            '=======================================================');
                        msg ('Start EDI Orgs ');

                        IF check_org_edi_status (c_header.organization_id)
                        --End CCR0008762
                        THEN
                            msg ('check_org_edi_status return TRUE ');

                            --Added for CCR0006013
                            BEGIN
                                SELECT DISTINCT (wdd.customer_id)
                                  INTO v_customer_id
                                  FROM apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda
                                 WHERE     wda.delivery_id =
                                           NVL (ln_new_delivery_id,
                                                c_header.source_header_id)
                                       --c_header.source_header_id
                                       AND wda.delivery_detail_id =
                                           wdd.delivery_detail_id
                                       AND ROWNUM < 2;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;

                            msg (
                                   'ln_new_delivery_id :'
                                || ln_new_delivery_id
                                || ' and EDI Customer_id :'
                                || v_customer_id);

                            -- Start Added for 1.12
                            -- Start Changes for 1.16
                            IF (NVL (lv_odc_org_exists, 'N') <> 'Y' OR (NVL (lv_odc_org_exists, 'N') = 'Y' AND NVL (lv_order_type, 'NA') = 'ODC_DC_DC_TRANSFER')) --DC to DC
                            -- End Changes for 1.16
                            THEN
                                --Added for CCR0006013
                                IF valid_loadid_req (v_customer_id)
                                THEN
                                    IF c_header.load_id IS NULL
                                    THEN
                                        --ROLLBACK TO begin_header;
                                        l_ret_stat   := g_ret_unexp_error;
                                    ELSE
                                        l_ret_stat   := g_ret_success;
                                    END IF;         --end for c_header.load_id
                                END IF;             --end for valid_loadid_req
                            END IF;                          -- Added for 1.16

                            msg (
                                   'EDI Validate LoadId Return status :'
                                || l_ret_stat);

                            IF l_ret_stat = g_ret_success
                            THEN
                                BEGIN
                                    -- Start Added for 1.12
                                    -- Start Changes for 1.16
                                    IF (NVL (lv_odc_org_exists, 'N') <> 'Y' OR (NVL (lv_odc_org_exists, 'N') = 'Y' AND NVL (lv_order_type, 'NA') = 'ODC_DC_DC_TRANSFER') --DC to DC
                                                                                                                                                                         OR (NVL (lv_odc_org_exists, 'N') = 'Y' AND NVL (lv_order_type, 'NA') = 'ODC_BACKORDERED')) --Backorder
                                    -- End Changes for 1.16
                                    THEN
                                        msg (
                                            'EDI process for DC to DC \ODC Backordered\Non US7 Org start');

                                        IF NVL (lv_order_type, 'NA') =
                                           'ODC_DC_DC_TRANSFER'
                                        THEN
                                            process_delivery (
                                                NVL (
                                                    ln_new_delivery_id,
                                                    c_header.source_header_id),
                                                c_header.ship_confirm_date,
                                                --Added for CCR0006806
                                                l_holds_t,
                                                l_message, -- Added as per ver 1.2
                                                l_ret_stat);
                                            msg (
                                                   'process_delivery(ODC_DC_DC_TRANSFER) return status : '
                                                || l_ret_stat);
                                        ELSIF NVL (lv_order_type, 'NA') =
                                              'ODC_BACKORDERED'
                                        THEN
                                            process_delivery_bo_us7 (
                                                NVL (
                                                    ln_new_delivery_id,
                                                    c_header.source_header_id),
                                                c_header.ship_confirm_date,
                                                l_holds_t,
                                                l_message,
                                                l_ret_stat);
                                            msg (
                                                   'process_delivery(ODC_BACKORDERED) return status : '
                                                || l_ret_stat);
                                        ELSE
                                            -- End Added for 1.12
                                            process_delivery (
                                                c_header.source_header_id,
                                                c_header.ship_confirm_date,
                                                --Added for CCR0006806
                                                l_holds_t,
                                                l_message, -- Added as per ver 1.2
                                                l_ret_stat);
                                            msg (
                                                   'EDI process_delivery return status : '
                                                || l_ret_stat);
                                        --START Added for 1.12
                                        END IF;
                                    END IF;

                                    msg (
                                           'EDI process_delivery return message : '
                                        || l_message);

                                    -- IF l_ret_stat = g_ret_success     -- Commented for for 1.16
                                    IF (l_ret_stat = g_ret_success OR l_ret_stat = g_ret_warning)
                                    THEN
                                        BEGIN
                                            UPDATE xxdo.xxdo_wms_3pl_osc_h
                                               SET process_status = 'S', error_message = NULL
                                             WHERE osc_header_id =
                                                   c_header.osc_header_id;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                NULL;
                                        END;

                                        BEGIN
                                            UPDATE xxdo.xxdo_wms_3pl_osc_l l
                                               SET process_status = 'S', error_message = 'Processing Complete'
                                             WHERE l.osc_header_id =
                                                   c_header.osc_header_id;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                NULL;
                                        END;
                                    ELSE
                                        IF l_message IS NOT NULL
                                        THEN
                                            BEGIN
                                                UPDATE xxdo.xxdo_wms_3pl_osc_h
                                                   SET process_status = 'E', error_message = DECODE (l_message, NULL, NULL, '  ' || l_message)
                                                 WHERE osc_header_id =
                                                       c_header.osc_header_id;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    NULL;
                                            END;

                                            BEGIN
                                                UPDATE xxdo.xxdo_wms_3pl_osc_l
                                                   SET process_status = 'E', error_message = DECODE (l_message, NULL, NULL, '  ' || l_message)
                                                 WHERE osc_header_id =
                                                       c_header.osc_header_id;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    NULL;
                                            END;
                                        END IF;
                                    END IF;

                                    --End Added for 1.12

                                    IF l_ret_stat = g_ret_success
                                    THEN
                                        msg (
                                            'Calling EDI ASN Interface to insert into EDI Tables ');
                                        edi_asn_interface (NVL (ln_new_delivery_id, c_header.source_header_id), c_header.organization_id, c_header.ship_confirm_date, c_header.carrier, c_header.carrier_code, c_header.bol_number, c_header.load_id, c_header.pro_number, c_header.seal_number
                                                           ,  --Added for 1.12
                                                             l_ret_stat);

                                        msg (
                                               'EDI ASN Interface return status :'
                                            || l_ret_stat);

                                        IF l_ret_stat != g_ret_success
                                        THEN
                                            --ROLLBACK TO begin_header;
                                            BEGIN
                                                UPDATE xxdo.xxdo_wms_3pl_osc_h
                                                   SET process_status = 'E', error_message = 'Header failed to process.'
                                                 WHERE osc_header_id =
                                                       c_header.osc_header_id;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    NULL;
                                            END;

                                            BEGIN
                                                UPDATE xxdo.xxdo_wms_3pl_osc_l
                                                   SET process_status = 'E', error_message = 'Failed to insert data into EDI STG tables.'
                                                 WHERE osc_header_id =
                                                       c_header.osc_header_id;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    NULL;
                                            END;
                                        ELSE
                                            BEGIN
                                                UPDATE xxdo.xxdo_wms_3pl_osc_h
                                                   SET process_status = 'S', error_message = NULL
                                                 WHERE osc_header_id =
                                                       c_header.osc_header_id;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    NULL;
                                            END;

                                            BEGIN
                                                UPDATE xxdo.xxdo_wms_3pl_osc_l l
                                                   SET process_status = 'S', error_message = 'Processing Complete'
                                                 WHERE l.osc_header_id =
                                                       c_header.osc_header_id;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    NULL;
                                            END;
                                        END IF; --End for edi_asn_interface status
                                    END IF;  --End for process_delivery status
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        msg (
                                               'Exp- Process of edi_asn_interface :'
                                            || SQLERRM);
                                        l_ret_stat   := g_ret_unexp_error;
                                        l_message    := SQLERRM;
                                END;
                            ELSE
                                --ROLLBACK TO begin_header;
                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_osc_h
                                       SET process_status = 'E', error_message = 'Header failed to process.'
                                     WHERE osc_header_id =
                                           c_header.osc_header_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;

                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_osc_l
                                       SET process_status = 'E', error_message = 'Missing Load ID for EDI Customer in STG tables.'
                                     WHERE osc_header_id =
                                           c_header.osc_header_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;
                            END IF;

                            IF NVL (l_ret_stat, g_ret_error) != g_ret_success
                            THEN
                                ROLLBACK TO begin_header;

                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_osc_h
                                       SET process_status = 'E', error_message = 'Header failed to process.' || DECODE (l_message, NULL, NULL, '  ' || l_message)
                                     WHERE osc_header_id =
                                           c_header.osc_header_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;

                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_osc_l
                                       SET process_status = 'E', error_message = 'Header failed to process.' || DECODE (l_message, NULL, NULL, '  ' || l_message)
                                     WHERE osc_header_id =
                                           c_header.osc_header_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;
                            END IF;
                        ELSE                              -- ELSE for EDI orgs
                            --Start Added for 1.12
                            msg ('ELSE for EDI orgs start ');

                            --Start changes for 1.16
                            /*lv_odc_org_exists := validate_odc_org_exists(
                    c_header.osc_header_id,
                    c_header.organization_id);

             get_odc_order_type(
                 c_header.osc_header_id,
                 lv_odc_org_exists,
                 lv_order_type); */
                            --End changes for 1.16
                            msg (
                                   'lv_order_type : '
                                || lv_order_type
                                || ' and lv_odc_org_exists : '
                                || lv_odc_org_exists);

                            BEGIN
                                --Start changes for 1.16
                                IF (NVL (lv_odc_org_exists, 'N') <> 'Y' OR (NVL (lv_odc_org_exists, 'N') = 'Y' AND NVL (lv_order_type, 'NA') = 'ODC_DC_DC_TRANSFER') --DC to DC
                                                                                                                                                                     OR (NVL (lv_odc_org_exists, 'N') = 'Y' AND NVL (lv_order_type, 'NA') = 'ODC_BACKORDERED')) --Backorder
                                --End changes for 1.16
                                THEN
                                    msg (
                                        'EDI process for DC to DC \US7 Backordered\Non US7 Org start');

                                    IF NVL (lv_order_type, 'NA') <>
                                       'ODC_BACKORDERED'
                                    THEN
                                        process_delivery (
                                            NVL (ln_new_delivery_id,
                                                 c_header.source_header_id),
                                            c_header.ship_confirm_date,
                                            --Added for CCR0006806
                                            l_holds_t,
                                            l_message, -- Added as per ver 1.2
                                            l_ret_stat);
                                    ELSE
                                        --End Added for 1.12
                                        process_delivery (
                                            c_header.source_header_id,
                                            c_header.ship_confirm_date,
                                            --Added for CCR0006806
                                            l_holds_t,
                                            l_message, -- Added as per ver 1.2
                                            l_ret_stat);
                                    END IF;                   --Added for 1.12
                                END IF;                       --Added for 1.12

                                --apps.XXDO_3PL_DEBUG_PROCEDURE('After calling process_delivery.."ELSE for is_canada_org", status :'||l_ret_stat);
                                msg (
                                       'EDI process_delivery return status : '
                                    || l_ret_stat);
                                msg (
                                       'EDI process_delivery return message : '
                                    || l_message);

                                -- IF l_ret_stat = g_ret_success     -- Commented for for 1.16
                                IF (l_ret_stat = g_ret_success OR l_ret_stat = g_ret_warning)
                                THEN
                                    BEGIN
                                        UPDATE xxdo.xxdo_wms_3pl_osc_h
                                           SET process_status = 'S', error_message = NULL
                                         WHERE osc_header_id =
                                               c_header.osc_header_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            NULL;
                                    END;

                                    BEGIN
                                        UPDATE xxdo.xxdo_wms_3pl_osc_l l
                                           SET process_status = 'S', error_message = 'Processing Complete'
                                         WHERE l.osc_header_id =
                                               c_header.osc_header_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            NULL;
                                    END;
                                --START Added as per ver 1.2
                                ELSE
                                    IF l_message IS NOT NULL
                                    THEN
                                        BEGIN
                                            UPDATE xxdo.xxdo_wms_3pl_osc_h
                                               SET process_status = 'E', error_message = DECODE (l_message, NULL, NULL, '  ' || l_message)
                                             WHERE osc_header_id =
                                                   c_header.osc_header_id;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                NULL;
                                        END;

                                        BEGIN
                                            UPDATE xxdo.xxdo_wms_3pl_osc_l
                                               SET process_status = 'E', error_message = DECODE (l_message, NULL, NULL, '  ' || l_message)
                                             WHERE osc_header_id =
                                                   c_header.osc_header_id;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                NULL;
                                        END;
                                    END IF;
                                --END Added as per ver 1.2
                                END IF;      --End for process_delivery status
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    msg (
                                        'EXP - Post End process_delivery status ');
                                    l_ret_stat   := g_ret_unexp_error;
                                    l_message    := SQLERRM;
                            END;

                            IF NVL (l_ret_stat, g_ret_error) != g_ret_success
                            THEN
                                ROLLBACK TO begin_header;

                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_osc_h
                                       SET process_status = 'E', error_message = 'Header failed to process.' || DECODE (l_message, NULL, NULL, '  ' || l_message)
                                     WHERE osc_header_id =
                                           c_header.osc_header_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;

                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_osc_l
                                       SET process_status = 'E', error_message = 'Header failed to process.' || DECODE (l_message, NULL, NULL, '  ' || l_message)
                                     WHERE osc_header_id =
                                           c_header.osc_header_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;
                            END IF;                        -- end for EDI orgs
                        END IF;                       -- end for is_canada_org

                        msg ('EndIF for EDI orgs end ');
                        msg (
                            '=======================================================');
                    --END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            msg ('EXP- Post EndIF of EDI orgs ');
                            l_ret_stat   := g_ret_unexp_error;
                            l_message    := SQLERRM;
                    END;
                END IF;
            -------------------------------------------------------------------------------------------------------------
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_message   := 'Global Failure ' || SQLERRM;
                    msg ('EXP- Others -Global Failure : ' || l_message);

                    BEGIN
                        UPDATE xxdo.xxdo_wms_3pl_osc_h
                           SET process_status = 'E', error_message = l_message
                         WHERE osc_header_id = c_header.osc_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;

                    BEGIN
                        UPDATE xxdo.xxdo_wms_3pl_osc_l
                           SET process_status = 'E', error_message = l_message
                         WHERE osc_header_id = c_header.osc_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
            END;
        END LOOP;

        msg ('process_load_confirmation ends ');
    EXCEPTION
        WHEN carrier_scac_failure
        THEN
            msg ('Main EXP- carrier_scac_failure ');
            RAISE;
        WHEN OTHERS
        THEN
            msg ('Main EXP - Others ');
            RAISE;
    END;

    PROCEDURE resubmit_interface (p_user_id IN NUMBER, p_message_type IN VARCHAR2, p_header_id IN NUMBER
                                  , p_comments IN VARCHAR2:= NULL, x_ret_stat OUT VARCHAR2, x_message OUT VARCHAR2)
    IS
        l_cnt          NUMBER := 0;
        l_rowid        ROWID;
        l_table_name   VARCHAR2 (50);
        l_hist_id      NUMBER;
    BEGIN
        IF NVL (p_user_id, -1) < 0
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            x_message    :=
                'You must specify a user ID to resubmit interface errors.';
        END IF;

        IF NVL (p_header_id, -1) < 0
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            x_message    :=
                'You must specify an ID to resubmit interface errors.';
        END IF;

        do_debug_tools.enable_table (100000);

        IF p_message_type = 'HADJ'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_ADJ_H';

               UPDATE xxdo.xxdo_wms_3pl_adj_h
                  SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
                WHERE     adj_header_id = p_header_id
                      AND NVL (process_status, 'E') != 'S'
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);

            UPDATE xxdo.xxdo_wms_3pl_adj_l
               SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
             WHERE     adj_header_id = p_header_id
                   AND NVL (process_status, 'E') != 'S';

            l_cnt          := NVL (l_cnt, 0) + NVL (SQL%ROWCOUNT, 0);
        ELSIF p_message_type = 'HGRN'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_GRN_H';

               UPDATE xxdo.xxdo_wms_3pl_grn_h
                  SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
                WHERE     grn_header_id = p_header_id
                      AND NVL (process_status, 'E') != 'S'
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);

            UPDATE xxdo.xxdo_wms_3pl_grn_l
               SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
             WHERE     grn_header_id = p_header_id
                   AND NVL (process_status, 'E') != 'S';

            l_cnt          := NVL (l_cnt, 0) + NVL (SQL%ROWCOUNT, 0);
        ELSIF p_message_type = 'HOSC'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_OSC_H';

               UPDATE xxdo.xxdo_wms_3pl_osc_h
                  SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
                WHERE     osc_header_id = p_header_id
                      AND NVL (process_status, 'E') != 'S'
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);

            UPDATE xxdo.xxdo_wms_3pl_osc_l
               SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
             WHERE     osc_header_id = p_header_id
                   AND NVL (process_status, 'E') != 'S';

            l_cnt          := NVL (l_cnt, 0) + NVL (SQL%ROWCOUNT, 0);
        ELSIF p_message_type = 'HTRA'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_TRA_H';

               UPDATE xxdo.xxdo_wms_3pl_tra_h
                  SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
                WHERE     tra_header_id = p_header_id
                      AND NVL (process_status, 'E') != 'S'
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);

            UPDATE xxdo.xxdo_wms_3pl_tra_l
               SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
             WHERE     tra_header_id = p_header_id
                   AND NVL (process_status, 'E') != 'S';

            l_cnt          := NVL (l_cnt, 0) + NVL (SQL%ROWCOUNT, 0);
        ELSIF p_message_type = 'HOHR'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_OHR_H';

               UPDATE xxdo.xxdo_wms_3pl_ohr_h
                  SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
                WHERE     ohr_header_id = p_header_id
                      AND NVL (process_status, 'E') != 'S'
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);

            UPDATE xxdo.xxdo_wms_3pl_ohr_l
               SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
             WHERE     ohr_header_id = p_header_id
                   AND NVL (process_status, 'E') != 'S';

            l_cnt          := NVL (l_cnt, 0) + NVL (SQL%ROWCOUNT, 0);
        ELSIF p_message_type = 'HTRK'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_TRK_H';

               UPDATE xxdo.xxdo_wms_3pl_trk_h
                  SET process_status = 'P', error_message = NULL, processing_session_id = USERENV ('SESSIONID')
                WHERE     trk_header_id = p_header_id
                      AND NVL (process_status, 'E') != 'S'
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);
        ELSE
            x_ret_stat   := g_ret_error;
            x_message    :=
                'Unsupported message type (' || p_message_type || ')';
            RETURN;
        END IF;

        IF l_cnt = 0
        THEN
            x_ret_stat   := g_ret_warning;
            x_message    := 'No records updated';
            RETURN;
        ELSE
            x_ret_stat   := g_ret_success;
            x_message    := '(' || l_cnt || ') records updated';
            msg (x_message);
        END IF;

        IF p_message_type = 'HADJ'
        THEN
            BEGIN
                process_adjustments;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                        'Error in process_adjustments ' || SQLERRM;
                    RETURN;
            END;
        ELSIF p_message_type = 'HGRN'
        THEN
            BEGIN
                process_grn;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    := 'Error in process_grn ' || SQLERRM;
                    RETURN;
            END;
        ELSIF p_message_type = 'HOSC'
        THEN
            BEGIN
                process_load_confirmation;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                        'Error in process_load_confirmation ' || SQLERRM;
                    RETURN;
            END;
        ELSIF p_message_type = 'HTRA'
        THEN
            BEGIN
                process_transfers;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    := 'Error in process_transfers ' || SQLERRM;
                    RETURN;
            END;
        ELSIF p_message_type = 'HOHR'
        THEN
            BEGIN
                process_inventory_sync;
                x_ret_stat   := g_ret_success;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_error;
                    x_message    :=
                        'Error in process_order_tracking ' || SQLERRM;
                    RETURN;
            END;
        ELSE
            x_ret_stat   := g_ret_error;
            x_message    :=
                'Unsupported message type (' || p_message_type || ')';
            RETURN;
        END IF;

        log_update (p_updated_by     => p_user_id,
                    p_update_type    => 'RESUBMIT',
                    p_update_table   => l_table_name,
                    p_update_id      => p_header_id,
                    p_update_rowid   => l_rowid,
                    p_comments       => p_comments,
                    x_ret_stat       => x_ret_stat,
                    x_hist_id        => l_hist_id,
                    x_message        => x_message);
        mail_debug (
            p_user_id   => p_user_id,
            p_title     =>
                   '3PL Interface Resubmit of '
                || p_message_type
                || ' ('
                || p_header_id
                || ')');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_error;
            x_message    := 'Unhandled exception ' || SQLERRM;
            RETURN;
    END;

    PROCEDURE acknowledge_interface (p_user_id IN NUMBER, p_message_type IN VARCHAR2, p_header_id IN NUMBER
                                     , p_comments IN VARCHAR2:= NULL, x_ret_stat OUT VARCHAR2, x_message OUT VARCHAR2)
    IS
        l_cnt          NUMBER := 0;
        l_rowid        ROWID;
        l_table_name   VARCHAR2 (50);
        l_hist_id      NUMBER;
    BEGIN
        IF NVL (p_user_id, -1) < 0
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            x_message    :=
                'You must specify a user ID to acknowledge interface errors.';
        END IF;

        IF NVL (p_header_id, -1) < 0
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            x_message    :=
                'You must specify an ID to acknowledge interface errors.';
        END IF;

        IF p_message_type = 'HADJ'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_ADJ_H';

               UPDATE xxdo.xxdo_wms_3pl_adj_h
                  SET process_status   = g_proc_status_acknowledged
                WHERE     adj_header_id = p_header_id
                      AND NVL (process_status, 'E') != 'S'
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);

            UPDATE xxdo.xxdo_wms_3pl_adj_l
               SET process_status   = g_proc_status_acknowledged
             WHERE     adj_header_id = p_header_id
                   AND NVL (process_status, 'E') != 'S';

            l_cnt          := NVL (l_cnt, 0) + NVL (SQL%ROWCOUNT, 0);
        ELSIF p_message_type = 'HGRN'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_GRN_H';

               UPDATE xxdo.xxdo_wms_3pl_grn_h
                  SET process_status   = g_proc_status_acknowledged
                WHERE     grn_header_id = p_header_id
                      AND NVL (process_status, 'E') != 'S'
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);

            UPDATE xxdo.xxdo_wms_3pl_grn_l
               SET process_status   = g_proc_status_acknowledged
             WHERE     grn_header_id = p_header_id
                   AND NVL (process_status, 'E') != 'S';

            l_cnt          := NVL (l_cnt, 0) + NVL (SQL%ROWCOUNT, 0);
        ELSIF p_message_type = 'HOSC'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_OSC_H';

               UPDATE xxdo.xxdo_wms_3pl_osc_h
                  SET process_status   = g_proc_status_acknowledged
                WHERE     osc_header_id = p_header_id
                      AND NVL (process_status, 'E') != 'S'
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);

            UPDATE xxdo.xxdo_wms_3pl_osc_l
               SET process_status   = g_proc_status_acknowledged
             WHERE     osc_header_id = p_header_id
                   AND NVL (process_status, 'E') != 'S';

            l_cnt          := NVL (l_cnt, 0) + NVL (SQL%ROWCOUNT, 0);
        ELSIF p_message_type = 'HTRA'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_TRA_H';

               UPDATE xxdo.xxdo_wms_3pl_tra_h
                  SET process_status   = g_proc_status_acknowledged
                WHERE     tra_header_id = p_header_id
                      AND NVL (process_status, 'E') != 'S'
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);

            UPDATE xxdo.xxdo_wms_3pl_tra_l
               SET process_status   = g_proc_status_acknowledged
             WHERE     tra_header_id = p_header_id
                   AND NVL (process_status, 'E') != 'S';

            l_cnt          := NVL (l_cnt, 0) + NVL (SQL%ROWCOUNT, 0);
        ELSIF p_message_type = 'HOHR'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_HOHR_H';

               UPDATE xxdo.xxdo_wms_3pl_ohr_h
                  SET process_status   = g_proc_status_acknowledged
                WHERE     ohr_header_id = p_header_id
                      AND NVL (process_status, 'E') != 'S'
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);

            UPDATE xxdo.xxdo_wms_3pl_ohr_l
               SET process_status   = g_proc_status_acknowledged
             WHERE     ohr_header_id = p_header_id
                   AND NVL (process_status, 'E') != 'S';

            l_cnt          := NVL (l_cnt, 0) + NVL (SQL%ROWCOUNT, 0);
        ELSIF p_message_type = 'HTRK'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_TRK_H';

               UPDATE xxdo.xxdo_wms_3pl_trk_h
                  SET process_status   = g_proc_status_acknowledged
                WHERE     trk_header_id = p_header_id
                      AND NVL (process_status, 'E') != 'S'
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);
        ELSIF p_message_type = 'LOG'
        THEN
            l_table_name   := 'XXDO.XXDO_WMS_3PL_ERR_LOG';

               UPDATE xxdo.xxdo_wms_3pl_err_log
                  SET process_status   = g_proc_status_acknowledged
                WHERE err_id = p_header_id
            RETURNING ROWID
                 INTO l_rowid;

            l_cnt          := NVL (SQL%ROWCOUNT, 0);
        ELSE
            x_ret_stat   := g_ret_error;
            x_message    :=
                'Unsupported message type (' || p_message_type || ')';
            RETURN;
        END IF;

        IF l_cnt = 0
        THEN
            x_ret_stat   := g_ret_warning;
            x_message    := 'No records updated';
            RETURN;
        ELSE
            x_ret_stat   := g_ret_success;
            x_message    := '(' || l_cnt || ') records updated';
            msg (x_message);
        END IF;

        log_update (p_updated_by     => p_user_id,
                    p_update_type    => 'ACKNOWLEDGE',
                    p_update_table   => l_table_name,
                    p_update_id      => p_header_id,
                    p_update_rowid   => l_rowid,
                    p_comments       => p_comments,
                    x_ret_stat       => x_ret_stat,
                    x_hist_id        => l_hist_id,
                    x_message        => x_message);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_error;
            x_message    := 'Unhandled exception ' || SQLERRM;
            RETURN;
    END;

    PROCEDURE process_order_tracking
    IS
        l_ret_stat   VARCHAR2 (1);
        l_message    VARCHAR2 (2000);
    BEGIN
        FOR c_header
            IN (SELECT h.trk_header_id, h.organization_id, h.tracking_number,
                       h.source_header_id
                  FROM xxdo.xxdo_wms_3pl_trk_h h
                 WHERE     h.process_status = 'P'
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM xxdo.xxdo_wms_3pl_trk_h l2
                                 WHERE     l2.trk_header_id = h.trk_header_id
                                       AND l2.process_status != 'P')
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM xxdo.xxdo_wms_3pl_trk_h l2
                                 WHERE     l2.trk_header_id = h.trk_header_id
                                       AND l2.processing_session_id !=
                                           h.processing_session_id)
                       AND h.processing_session_id = USERENV ('SESSIONID'))
        LOOP
            SAVEPOINT begin_header_trk;
            l_ret_stat   := g_ret_success;
            l_message    := NULL;

            BEGIN
                UPDATE apps.wsh_delivery_details
                   SET tracking_number   = c_header.tracking_number
                 WHERE     delivery_detail_id IN
                               (SELECT delivery_detail_id
                                  FROM apps.wsh_delivery_assignments
                                 WHERE delivery_id =
                                       c_header.source_header_id)
                       AND organization_id = c_header.organization_id
                       AND source_code = 'OE'
                       AND tracking_number IS NULL
                       AND released_status IN ('S', 'Y', 'C');

                UPDATE apps.wsh_delivery_details wdd_cnt
                   SET tracking_number   = c_header.tracking_number
                 WHERE     delivery_detail_id IN
                               (SELECT delivery_detail_id
                                  FROM apps.wsh_delivery_assignments
                                 WHERE delivery_id =
                                       c_header.source_header_id)
                       AND organization_id = c_header.organization_id
                       AND container_flag = 'Y'
                       AND tracking_number IS NULL
                       AND EXISTS
                               (SELECT NULL
                                  FROM apps.wsh_delivery_details wdd_itm, apps.wsh_delivery_assignments wda_itm
                                 WHERE     wda_itm.parent_delivery_detail_id =
                                           wdd_cnt.delivery_detail_id
                                       AND wdd_itm.tracking_number =
                                           c_header.tracking_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_ret_stat   := g_ret_unexp_error;
                    l_message    := SQLERRM;
            END;

            IF NVL (l_ret_stat, apps.fnd_api.g_ret_sts_error) !=
               apps.fnd_api.g_ret_sts_success
            THEN
                ROLLBACK TO begin_header_trk;
            END IF;

            UPDATE xxdo.xxdo_wms_3pl_trk_h
               SET process_status = l_ret_stat, error_message = l_message
             WHERE trk_header_id = c_header.trk_header_id;
        END LOOP;
    END;

    PROCEDURE log_update (p_updated_by     IN     NUMBER,
                          p_update_type    IN     VARCHAR2,
                          p_update_table   IN     VARCHAR2,
                          p_update_id      IN     NUMBER,
                          p_update_rowid   IN     VARCHAR2,
                          p_comments       IN     VARCHAR2,
                          x_ret_stat          OUT VARCHAR2,
                          x_hist_id           OUT NUMBER,
                          x_message           OUT VARCHAR2)
    IS
    BEGIN
        SELECT xxdo.xxdo_wms_3pl_update_hist_s.NEXTVAL
          INTO x_hist_id
          FROM DUAL;

        INSERT INTO xxdo.xxdo_wms_3pl_update_hist (hist_id, hist_updated_by, update_type, update_table, update_id, update_rowid
                                                   , comments)
             VALUES (x_hist_id, p_updated_by, p_update_type,
                     p_update_table, p_update_id, p_update_rowid,
                     p_comments);

        x_ret_stat   := apps.fnd_api.g_ret_sts_success;
        x_message    := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_hist_id    := NULL;
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            x_message    := SQLERRM;
    END;

    --Begin CCR0008621
    FUNCTION get_asn_fac_po_line (p_shipment_line_id IN NUMBER)
        RETURN NUMBER
    IS
        l_po_line_id   NUMBER;
    BEGIN
        BEGIN
            --Check link direct ship PO/JP PO
            SELECT DISTINCT NVL (dss.po_line_id, pla.po_line_id)
              INTO l_po_line_id
              FROM rcv_shipment_lines rsl, po_lines_all pla, oe_order_lines_all oola,
                   oe_drop_ship_sources dss
             WHERE     1 = 1
                   AND rsl.shipment_line_id = p_shipment_line_id
                   AND rsl.source_document_code = 'PO'
                   AND rsl.po_line_id = pla.po_line_id
                   AND pla.attribute5 = oola.line_id(+)
                   AND oola.line_id = dss.line_id(+);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    --Get ASN linked to Fac_po via internal SO (interco)
                    SELECT DISTINCT rsl_fac.po_line_id
                      INTO l_po_line_id
                      FROM rcv_shipment_lines rsl, mtl_material_transactions mmt, wsh_delivery_details wdd,
                           oe_order_lines_all oola, rcv_shipment_lines rsl_fac
                     WHERE     1 = 1
                           AND rsl.source_document_code = 'REQ'
                           AND rsl.shipment_line_id = p_shipment_line_id
                           AND rsl.mmt_transaction_id = mmt.transaction_id
                           AND mmt.picking_line_id = wdd.delivery_detail_id
                           AND wdd.source_line_id = oola.line_id
                           AND oola.line_id = rsl_fac.attribute3;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l_po_line_id   := NULL;
                END;
        END;

        RETURN l_po_line_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_line_hts_code (p_style_number      IN VARCHAR2,
                                p_organization_id   IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_hts_code   VARCHAR2 (150) := NULL;
    BEGIN
        SELECT dhtc.harmonized_tariff_code
          INTO lv_hts_code
          FROM do_custom.do_harmonized_tariff_codes dhtc, fnd_lookup_values flv, mtl_parameters mp
         WHERE     dhtc.country = flv.description
               AND mp.organization_code = flv.lookup_code
               AND flv.lookup_type = 'XXD_INV_HTS_REGION_INV_ORG_MAP'
               AND flv.LANGUAGE = USERENV ('LANG')
               AND flv.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (flv.start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (flv.end_date_active,
                                                    SYSDATE + 1))
               AND mp.organization_id = p_organization_id
               AND dhtc.style_number = p_style_number;

        RETURN lv_hts_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_asn_line_factory_price (p_shipment_line_id IN NUMBER)
        RETURN NUMBER
    IS
        l_po_line_id   NUMBER;
        l_fac_price    NUMBER;
    BEGIN
        --Get the factory PO line
        l_po_line_id   := get_asn_fac_po_line (p_shipment_line_id);
        DBMS_OUTPUT.put_line (l_po_line_id);

        IF l_po_line_id IS NOT NULL
        --There is a PO line linked to the ASN line,get the price from the PO line
        THEN
            SELECT pla.unit_price
              INTO l_fac_price
              FROM po_lines_all pla
             WHERE pla.po_line_id = l_po_line_id;
        ELSE
            --get linked ISO line price
            SELECT oola.unit_selling_price
              INTO l_fac_price
              FROM rcv_shipment_lines rsl, mtl_material_transactions mmt, wsh_delivery_details wdd,
                   oe_order_lines_all oola
             WHERE     1 = 1
                   AND rsl.shipment_line_id = p_shipment_line_id
                   AND rsl.mmt_transaction_id = mmt.transaction_id
                   AND mmt.picking_line_id = wdd.delivery_detail_id
                   AND wdd.source_line_id = oola.line_id;
        END IF;

        RETURN l_fac_price;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    /* --Start Commented for CCR0009126
    FUNCTION get_asn_line_country_of_origin (p_shipment_line_id IN NUMBER)
       RETURN VARCHAR2
    IS
       l_assignment_set_id   NUMBER
          := apps.do_get_profile_value ('MRP_DEFAULT_ASSIGNMENT_SET');
       l_country             VARCHAR2 (10);
       l_po_line_id          NUMBER;
       l_item_id             NUMBER;
       l_organization_id     NUMBER;
    BEGIN
       --Get the factory PO line
       l_po_line_id := get_asn_fac_po_line (p_shipment_line_id);

       IF l_po_line_id IS NOT NULL
       --There is a PO line linked to the ASN line, get the contry for the associated PO/Vendor
       THEN
          SELECT apsa.country
            INTO l_country
            FROM ap_supplier_sites_all apsa,
                 po_headers_all pha,
                 po_lines_all pla
           WHERE     1 = 1
                 AND apsa.vendor_site_id = pha.vendor_site_id
                 AND pla.po_header_id = pha.po_header_id
                 AND pla.po_line_id = l_po_line_id;
       ELSE
          --Get the item, detstination org for the asn line
          --For DC-DC xfer return NULL for COO
          RETURN NULL;
       END IF;

       RETURN l_country;
    EXCEPTION
       WHEN OTHERS
       THEN
          apps.do_debug_tools.msg (
             'GET_Country_of_origin Exception:' || SQLERRM);
          RETURN NULL;
    END; */
    --End Commented for CCR0009126

    --Start Added for CCR0009126
    FUNCTION get_asn_line_country_of_origin (p_shipment_line_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_assignment_set_id   NUMBER
            := apps.do_get_profile_value ('MRP_DEFAULT_ASSIGNMENT_SET');
        l_country             VARCHAR2 (10);
        l_po_line_id          NUMBER;
        l_item_id             NUMBER;
        l_organization_id     NUMBER;
        ln_organization_id    NUMBER;
    BEGIN
        --Get the factory PO line
        l_po_line_id   := get_asn_fac_po_line (p_shipment_line_id);

        BEGIN
            SELECT DISTINCT organization_id
              INTO ln_organization_id
              FROM apps.rcv_shipment_headers rsh, apps.rcv_shipment_lines rsl
             WHERE     rsh.shipment_header_id = rsl.shipment_header_id
                   AND rsl.shipment_line_id = p_shipment_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_organization_id   := NULL;
        END;

        IF l_po_line_id IS NOT NULL
        --PO line linked to the ASN line, get the COO for the associated PO/Vendor
        THEN
            SELECT apsa.country
              INTO l_country
              FROM ap_suppliers aps,
                   ap_supplier_sites_all apsa,
                   po_headers_all ph,
                   (SELECT pla1.line_num, pla1.po_header_id, pla1.po_line_id,
                           apsa1.vendor_site_id
                      FROM po_headers_all ph1, po_lines_all pla1, ap_supplier_sites_all apsa1
                     WHERE     pla1.po_header_id = ph1.po_header_id
                           AND pla1.org_id = apsa1.org_id
                           --AND ph1.vendor_site_id = apsa1.vendor_site_id 1.9  CCR0009126
                           AND NVL (
                                   pla1.attribute7,
                                   (SELECT vendor_site_code
                                      FROM ap_supplier_sites_all
                                     WHERE vendor_site_id =
                                           ph1.vendor_site_id)) =
                               apsa1.vendor_site_code
                           AND pla1.item_id IS NOT NULL
                           AND pla1.po_line_id = l_po_line_id) psub
             WHERE     aps.vendor_id = ph.vendor_id
                   AND aps.vendor_id = apsa.vendor_id
                   AND apsa.vendor_site_id =
                       NVL (psub.vendor_site_id, apsa.vendor_site_id)
                   AND ph.po_header_id = psub.po_header_id
                   AND psub.po_line_id = l_po_line_id;
        ELSE
              --DC# case, To get ISO line from IR line based on shipment line for COO
              SELECT wdd.attribute3
                INTO l_country
                FROM apps.po_requisition_headers_all prha, apps.po_requisition_lines_all prla, oe_order_headers_all ooha,
                     oe_order_lines_all oola, rcv_shipment_lines rsl, rcv_shipment_headers rsh,
                     hr_all_organization_units hr_dest, hr_all_organization_units hr_org, hr_all_organization_units hr_src,
                     mtl_material_transactions mmt, wsh_delivery_details wdd, wsh_delivery_assignments wda
               WHERE     prha.type_lookup_code = 'INTERNAL'
                     AND prla.source_organization_id = ln_organization_id
                     AND NVL (prha.attribute_category, 'NONE') !=
                         'REQ_CONVERSION'
                     AND prla.destination_organization_id =
                         hr_dest.organization_id
                     AND prla.source_organization_id = hr_src.organization_id
                     AND prha.requisition_header_id =
                         prla.requisition_header_id
                     AND prla.requisition_line_id =
                         oola.source_document_line_id
                     AND oola.header_id = ooha.header_id
                     AND prla.requisition_line_id = rsl.requisition_line_id
                     AND prha.org_id = hr_org.organization_id
                     AND rsl.mmt_transaction_id = mmt.transaction_id
                     AND rsl.shipment_header_id = rsh.shipment_header_id
                     AND mmt.picking_line_id = wdd.delivery_detail_id
                     AND wdd.source_line_id = oola.line_id
                     AND wdd.delivery_detail_id = wda.delivery_detail_id
                     AND   prla.quantity_delivered
                         + NVL (prla.quantity_cancelled, 0) <
                         prla.quantity
                     AND authorization_status = 'APPROVED'
                     AND rsl.shipment_line_id = p_shipment_line_id
            ORDER BY order_number, oola.line_number || '.' || oola.shipment_number;
        END IF;

        RETURN l_country;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.do_debug_tools.msg (
                'GET_Country_of_origin Exception:' || SQLERRM);
            RETURN NULL;
    END;

    --End Added for CCR0009126
    FUNCTION get_shipment_bol (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_grouping_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_ret   VARCHAR2 (30);
    BEGIN
        IF p_shipment_type = 'IS'
        THEN
            SELECT DECODE (MIN (s.bill_of_lading), MAX (s.bill_of_lading), MAX (s.bill_of_lading), '{Multiple}')
              INTO l_ret
              FROM po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh, mtl_material_transactions mmt,
                   wsh_delivery_details wdd, oe_order_lines_all oola, rcv_shipment_lines rsl_fac,
                   rcv_shipment_headers rsh_fac, custom.do_items i, custom.do_containers c,
                   custom.do_shipments s
             WHERE     1 = 1
                   AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                   AND rsh.ship_to_org_id = p_organization_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsl.mmt_transaction_id = mmt.transaction_id
                   AND rsl.item_id = mmt.inventory_item_id
                   AND mmt.picking_line_id = wdd.delivery_detail_id
                   AND wdd.source_line_id = oola.line_id
                   AND TO_CHAR (oola.line_id) = rsl_fac.attribute3
                   AND oola.inventory_item_id = rsl_fac.item_id
                   AND rsl_fac.shipment_header_id =
                       rsh_fac.shipment_header_id
                   AND rsl_fac.po_line_location_id = i.line_location_id
                   AND rsh_fac.shipment_num = i.atr_number
                   AND i.container_id = c.container_id
                   AND c.shipment_id = s.shipment_id
                   AND rsh.receipt_source_code = 'INTERNAL ORDER';
        ELSE
            SELECT DECODE (MIN (s.bill_of_lading), MAX (s.bill_of_lading), MAX (s.bill_of_lading), '{Multiple}')
              INTO l_ret
              FROM po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh, custom.do_items i,
                   custom.do_containers c, custom.do_shipments s
             WHERE     1 = 1
                   AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                   AND rsh.ship_to_org_id = p_organization_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsl.po_line_location_id = i.line_location_id
                   AND rsh.shipment_num = i.atr_number
                   AND i.container_id = c.container_id
                   AND c.shipment_id = s.shipment_id
                   AND rsh.receipt_source_code = 'VENDOR';

            IF l_ret IS NULL
            THEN
                SELECT DECODE (MIN (s.bill_of_lading), MAX (s.bill_of_lading), MAX (s.bill_of_lading), '{Multiple}')
                  INTO l_ret
                  FROM po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh, po_lines_all pla,
                       oe_order_lines_all oola, oe_drop_ship_sources dss, po.rcv_shipment_lines rsl_fac,
                       po.rcv_shipment_headers rsh_fac, custom.do_items i, custom.do_containers c,
                       custom.do_shipments s
                 WHERE     1 = 1
                       AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                       AND rsh.ship_to_org_id = p_organization_id
                       AND rsl.shipment_header_id = rsh.shipment_header_id
                       AND rsl.po_line_id = pla.po_line_id
                       AND pla.attribute5 = oola.line_id
                       AND oola.line_id = dss.line_id
                       AND dss.line_location_id = rsl_fac.po_line_location_id
                       AND rsl_fac.shipment_header_id =
                           rsh_fac.shipment_header_id
                       AND rsl_fac.po_line_location_id = i.line_location_id
                       AND rsh_fac.shipment_num = i.atr_number
                       AND i.container_id = c.container_id
                       AND c.shipment_id = s.shipment_id
                       AND rsh.receipt_source_code = 'VENDOR';
            END IF;
        END IF;

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.do_debug_tools.msg ('GET_BOL Exception:' || SQLERRM);
            RETURN NULL;
    END;

    --End CCR0008621
    FUNCTION get_shipment_invoice (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_grouping_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_ret   VARCHAR2 (30);
    BEGIN
        IF p_shipment_type = 'IS'
        THEN
            SELECT DECODE (MIN (rsl_fac.packing_slip), MAX (rsl_fac.packing_slip), MAX (rsl_fac.packing_slip), '{Multiple}')
              INTO l_ret
              FROM po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh, mtl_material_transactions mmt,
                   wsh_delivery_details wdd, oe_order_lines_all oola, rcv_shipment_lines rsl_fac
             WHERE     1 = 1
                   AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                   AND rsh.ship_to_org_id = p_organization_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsl.mmt_transaction_id = mmt.transaction_id
                   AND rsl.item_id = mmt.inventory_item_id
                   AND mmt.picking_line_id = wdd.delivery_detail_id
                   AND wdd.source_line_id = oola.line_id
                   AND TO_CHAR (oola.line_id) = rsl_fac.attribute3
                   AND oola.inventory_item_id = rsl_fac.item_id
                   AND rsh.receipt_source_code = 'INTERNAL ORDER';

            IF l_ret IS NULL
            THEN
                SELECT DECODE (MIN ('CI' || wda.delivery_id), MAX ('CI' || wda.delivery_id), MAX ('CI' || wda.delivery_id), '{Multiple}')
                  INTO l_ret
                  FROM po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh, mtl_material_transactions mmt,
                       wsh_delivery_details wdd, wsh_delivery_assignments wda, oe_order_lines_all oola
                 WHERE     1 = 1
                       AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                       AND rsh.ship_to_org_id = p_organization_id
                       AND rsl.shipment_header_id = rsh.shipment_header_id
                       AND rsl.mmt_transaction_id = mmt.transaction_id
                       AND rsl.item_id = mmt.inventory_item_id
                       AND mmt.picking_line_id = wdd.delivery_detail_id
                       AND wdd.source_line_id = oola.line_id
                       AND wdd.delivery_detail_id = wda.delivery_detail_id
                       AND oola.org_id = 95                               --US
                       AND rsh.receipt_source_code = 'INTERNAL ORDER';
            END IF;
        ELSE
            SELECT DECODE (MIN (rsl.packing_slip), MAX (rsl.packing_slip), MAX (rsl.packing_slip), '{Multiple}')
              INTO l_ret
              FROM po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh
             WHERE     1 = 1
                   AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                   AND rsh.ship_to_org_id = p_organization_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsh.receipt_source_code = 'VENDOR';

            IF l_ret IS NULL
            THEN
                SELECT DECODE (MIN (rsl_fac.packing_slip), MAX (rsl_fac.packing_slip), MAX (rsl_fac.packing_slip), '{Multiple}')
                  INTO l_ret
                  FROM po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh, po_lines_all pla,
                       oe_order_lines_all oola, oe_drop_ship_sources dss, po.rcv_shipment_lines rsl_fac
                 WHERE     1 = 1
                       AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                       AND rsh.ship_to_org_id = p_organization_id
                       AND rsl.shipment_header_id = rsh.shipment_header_id
                       AND rsl.po_line_id = pla.po_line_id
                       AND pla.attribute5 = oola.line_id
                       AND oola.line_id = dss.line_id
                       AND dss.line_location_id = rsl_fac.po_line_location_id
                       AND rsh.receipt_source_code = 'VENDOR';
            END IF;
        END IF;

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.do_debug_tools.msg ('GET_INVOICE Exception:' || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION get_shipment_po_number (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_grouping_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_ret   apps.po_vendors.vendor_name%TYPE;
    BEGIN
        IF p_shipment_type = 'IS'
        THEN
            /*SELECT DECODE (MIN (pha.segment1),
                           MAX (pha.segment1), MAX (pha.segment1),
                           '{Multiple}')
              INTO l_ret
              --FROM apps.po_vendors pv,                  ---commented by BT Technology team on 11/10/2014
              FROM apps.ap_suppliers pv, -- Added by BT Technology Team on 11/10/2014
                   apps.po_headers_all pha,
                   apps.po_line_locations_all plla,
                   apps.oe_order_lines_all oola,
                   apps.oe_order_headers_all ooha,
                   apps.rcv_shipment_lines rsl,
                   apps.rcv_shipment_headers rsh,
                   apps.po_requisition_lines_all prla
             WHERE     pv.vendor_id = pha.vendor_id
                   AND plla.line_location_id = TO_NUMBER (oola.attribute16)
                   AND pha.po_header_id = plla.po_header_id
                   AND prla.requisition_line_id = rsl.requisition_line_id
                   AND oola.header_id = ooha.header_id
                   AND oola.source_document_line_id = rsl.requisition_line_id
                   AND ooha.source_document_type_id = 10
                   AND ooha.source_document_id = prla.requisition_header_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                   AND rsh.ship_to_org_id = p_organization_id;*/
            SELECT DECODE (MIN (pha.segment1), MAX (pha.segment1), MAX (pha.segment1), '{Multiple}')
              INTO l_ret
              FROM po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh, mtl_material_transactions mmt,
                   wsh_delivery_details wdd, oe_order_lines_all oola, rcv_shipment_lines rsl_fac,
                   po_headers_all pha, ap_suppliers aps
             WHERE     1 = 1
                   AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                   AND rsh.ship_to_org_id = p_organization_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsl.mmt_transaction_id = mmt.transaction_id
                   AND rsl.item_id = mmt.inventory_item_id
                   AND mmt.picking_line_id = wdd.delivery_detail_id
                   AND wdd.source_line_id = oola.line_id
                   AND TO_CHAR (oola.line_id) = rsl_fac.attribute3
                   AND oola.inventory_item_id = rsl_fac.item_id
                   AND rsl_fac.po_header_id = pha.po_header_id
                   AND pha.vendor_id = aps.vendor_id
                   AND rsh.receipt_source_code = 'INTERNAL ORDER';
        ELSE
            l_ret   := NULL;
        END IF;

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.do_debug_tools.msg ('GET_PO_NUMBER Exception:' || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION get_shipment_sender (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_grouping_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_ret   apps.po_vendors.vendor_name%TYPE;
    BEGIN
        IF p_shipment_type = 'IS'
        THEN
            /*
               SELECT DECODE (MIN (pv.vendor_name),
                              MAX (pv.vendor_name), MAX (pv.vendor_name),
                              '{Multiple}')
                 INTO l_ret
                 --FROM apps.po_vendors pv,                  ---commented by BT Technology team on 11/10/2014
                 FROM apps.ap_suppliers pv, -- Added by BT Technology Team on 11/10/2014
                      apps.po_headers_all pha,
                      apps.po_line_locations_all plla,
                      apps.oe_order_lines_all oola,
                      apps.oe_order_headers_all ooha,
                      apps.rcv_shipment_lines rsl,
                      apps.rcv_shipment_headers rsh,
                      apps.po_requisition_lines_all prla
                WHERE     pv.vendor_id = pha.vendor_id
                      AND plla.line_location_id = TO_NUMBER (oola.attribute16)
                      AND pha.po_header_id = plla.po_header_id
                      AND prla.requisition_line_id = rsl.requisition_line_id
                      AND oola.header_id = ooha.header_id
                      AND oola.source_document_line_id = rsl.requisition_line_id
                      AND ooha.source_document_type_id = 10
                      AND ooha.source_document_id = prla.requisition_header_id
                      AND rsl.shipment_header_id = rsh.shipment_header_id
                      AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                      AND rsh.ship_to_org_id = p_organization_id;*/
            SELECT DECODE (MIN (aps.vendor_name), MAX (aps.vendor_name), MAX (aps.vendor_name), '{Multiple}')
              INTO l_ret
              FROM po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh, mtl_material_transactions mmt,
                   wsh_delivery_details wdd, oe_order_lines_all oola, rcv_shipment_lines rsl_fac,
                   po_headers_all pha, ap_suppliers aps
             WHERE     1 = 1
                   AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                   AND rsh.ship_to_org_id = p_organization_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsl.mmt_transaction_id = mmt.transaction_id
                   AND rsl.item_id = mmt.inventory_item_id
                   AND mmt.picking_line_id = wdd.delivery_detail_id
                   AND wdd.source_line_id = oola.line_id
                   AND TO_CHAR (oola.line_id) = rsl_fac.attribute3
                   AND oola.inventory_item_id = rsl_fac.item_id
                   AND rsl_fac.po_header_id = pha.po_header_id
                   AND pha.vendor_id = aps.vendor_id
                   AND rsh.receipt_source_code = 'INTERNAL ORDER';
        ELSE
            l_ret   := NULL;
        END IF;

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.do_debug_tools.msg (
                'GET_SHIPMENT_SENDER Exception:' || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION get_shipment_container (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_grouping_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_ret   custom.do_containers.container_ref%TYPE;
    BEGIN
        IF p_shipment_type = 'IS'
        THEN
            /*  SELECT DECODE (MAX (dc.container_ref),
                             MIN (dc.container_ref), MAX (dc.container_ref),
                             '{Multiple}')
                        AS container_number
                INTO l_ret
                FROM custom.do_items di,
                     custom.do_containers dc,
                     apps.oe_order_lines_all oola,
                     apps.po_line_locations_all plla,
                     apps.wsh_delivery_assignments wda,
                     apps.wsh_delivery_details wdd,
                     apps.rcv_shipment_headers rsh
               WHERE     dc.container_id = di.container_id
                     AND di.order_line_id = plla.po_line_id
                     AND di.line_location_id = plla.line_location_id
                     AND plla.line_location_id = TO_NUMBER (oola.attribute16)
                     AND oola.line_id = wdd.source_line_id
                     AND wdd.delivery_detail_id = wda.delivery_detail_id
                     AND wdd.source_code = 'OE'
                     AND wda.delivery_id = TO_NUMBER (rsh.shipment_num)
                     AND rsh.receipt_source_code = 'INTERNAL ORDER'
                     AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                     AND rsh.ship_to_org_id = p_organization_id;*/
            SELECT DECODE (MIN (rsl_fac.container_num), MAX (rsl_fac.container_num), MAX (rsl_fac.container_num), '{Multiple}') AS container_number
              INTO l_ret
              FROM po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh, mtl_material_transactions mmt,
                   wsh_delivery_details wdd, oe_order_lines_all oola, rcv_shipment_lines rsl_fac,
                   po_headers_all pha, ap_suppliers aps
             WHERE     1 = 1
                   AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                   AND rsh.ship_to_org_id = p_organization_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsl.mmt_transaction_id = mmt.transaction_id
                   AND rsl.item_id = mmt.inventory_item_id
                   AND mmt.picking_line_id = wdd.delivery_detail_id
                   AND wdd.source_line_id = oola.line_id
                   AND TO_CHAR (oola.line_id) = rsl_fac.attribute3
                   AND oola.inventory_item_id = rsl_fac.item_id
                   AND rsl_fac.po_header_id = pha.po_header_id
                   AND pha.vendor_id = aps.vendor_id
                   AND rsh.receipt_source_code = 'INTERNAL ORDER';
        ELSIF p_shipment_type = 'PO'
        THEN
            /*        SELECT DECODE (MAX (dc.container_ref),
                                   MIN (dc.container_ref), MAX (dc.container_ref),
                                   '{Multiple}')
                              AS container_number
                      INTO l_ret
                      FROM custom.do_items di,
                           custom.do_containers dc,
                           apps.rcv_shipment_lines rsl,
                           apps.rcv_shipment_headers rsh
                     WHERE     dc.container_id = di.container_id
                           AND di.order_line_id = rsl.po_line_id
                           AND di.line_location_id = rsl.po_line_location_id
                           AND di.atr_number = rsh.shipment_num
                           AND rsl.shipment_header_id = rsh.shipment_header_id
                           AND rsh.receipt_source_code = 'VENDOR'
                           AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                           AND rsh.ship_to_org_id = p_organization_id;*/
            SELECT DECODE (MIN (rsl.container_num), MAX (rsl.container_num), MAX (rsl.container_num), '{Multiple}')
              INTO l_ret
              FROM po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh
             WHERE     1 = 1
                   AND TO_NUMBER (rsh.attribute2) = p_grouping_id
                   AND rsh.ship_to_org_id = p_organization_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsh.receipt_source_code = 'VENDOR';
        ELSE
            l_ret   := NULL;
        END IF;

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.do_debug_tools.msg (
                'GET_SHIPMENT_CONTAINER Exception:' || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION get_delivery_sender (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_shipment_num IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_ret   apps.po_vendors.vendor_name%TYPE;
    BEGIN
        IF p_shipment_type = 'IS'
        THEN
            /* SELECT DECODE (MIN (pv.vendor_name),
                            MAX (pv.vendor_name), MAX (pv.vendor_name),
                            '{Multiple}')
               INTO l_ret
               -- FROM apps.po_vendors pv,                                                    --commented by BT Technology team on 11/10/2014
               FROM apps.ap_suppliers pv, --Added by BT Technology team on 11/10/2014
                    apps.po_headers_all pha,
                    apps.po_line_locations_all plla,
                    apps.oe_order_lines_all oola,
                    apps.oe_order_headers_all ooha,
                    apps.rcv_shipment_lines rsl,
                    apps.rcv_shipment_headers rsh,
                    apps.po_requisition_lines_all prla
              WHERE     pv.vendor_id = pha.vendor_id
                    AND plla.line_location_id = TO_NUMBER (oola.attribute16)
                    AND pha.po_header_id = plla.po_header_id
                    AND prla.requisition_line_id = rsl.requisition_line_id
                    AND oola.header_id = ooha.header_id
                    AND oola.source_document_line_id = rsl.requisition_line_id
                    AND ooha.source_document_type_id = 10
                    AND ooha.source_document_id = prla.requisition_header_id
                    AND rsl.shipment_header_id = rsh.shipment_header_id
                    AND rsh.shipment_num = p_shipment_num
                    AND rsh.ship_to_org_id = p_organization_id
                    AND rsh.receipt_source_code = 'INTERNAL ORDER';*/
            SELECT DECODE (MIN (aps.vendor_name), MAX (aps.vendor_name), MAX (aps.vendor_name), '{Multiple}')
              INTO l_ret
              FROM po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh, mtl_material_transactions mmt,
                   wsh_delivery_details wdd, oe_order_lines_all oola, rcv_shipment_lines rsl_fac,
                   po_headers_all pha, ap_suppliers aps
             WHERE     1 = 1
                   AND rsh.shipment_num = p_shipment_num
                   AND rsh.ship_to_org_id = p_organization_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND rsl.mmt_transaction_id = mmt.transaction_id
                   AND rsl.item_id = mmt.inventory_item_id
                   AND mmt.picking_line_id = wdd.delivery_detail_id
                   AND wdd.source_line_id = oola.line_id
                   AND TO_CHAR (oola.line_id) = rsl_fac.attribute3
                   AND oola.inventory_item_id = rsl_fac.item_id
                   AND rsl_fac.po_header_id = pha.po_header_id
                   AND pha.vendor_id = aps.vendor_id
                   AND rsh.receipt_source_code = 'INTERNAL ORDER';
        ELSE
            l_ret   := NULL;
        END IF;

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.do_debug_tools.msg (
                'GET_DELIVERY_SENDER Exception:' || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION get_delivery_container (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_shipment_num IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_ret   custom.do_containers.container_ref%TYPE;
    BEGIN
        IF p_shipment_type = 'IS'
        THEN
            /*  SELECT DECODE (MAX (dc.container_ref),
                             MIN (dc.container_ref), MAX (dc.container_ref),
                             '{Multiple}')
                        AS container_number
                INTO l_ret
                FROM custom.do_items di,
                     custom.do_containers dc,
                     apps.oe_order_lines_all oola,
                     apps.oe_order_headers_all ooha,
                     apps.po_line_locations_all plla,
                     apps.wsh_delivery_assignments wda,
                     apps.wsh_delivery_details wdd
               WHERE     dc.container_id = di.container_id
                     AND di.order_line_id = plla.po_line_id
                     AND di.line_location_id = plla.line_location_id
                     AND plla.line_location_id = TO_NUMBER (oola.attribute16)
                     AND oola.header_id = ooha.header_id
                     AND oola.line_id = wdd.source_line_id
                     AND ooha.header_id = wdd.source_header_id
                     AND wda.delivery_id = TO_NUMBER (p_shipment_num)
                     AND wdd.delivery_detail_id = wda.delivery_detail_id
                     AND wdd.source_code = 'OE';*/
            SELECT DECODE (MAX (rsl_fac.container_num), MIN (rsl_fac.container_num), MAX (rsl_fac.container_num), '{Multiple}') AS container_number
              INTO l_ret
              FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha, apps.wsh_delivery_assignments wda,
                   apps.wsh_delivery_details wdd, apps.rcv_shipment_lines rsl_fac
             WHERE     1 = 1
                   AND TO_CHAR (oola.line_id) = rsl_fac.attribute3
                   AND oola.header_id = ooha.header_id
                   AND oola.line_id = wdd.source_line_id
                   AND ooha.header_id = wdd.source_header_id
                   AND wda.delivery_id = TO_NUMBER (p_shipment_num)
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND wdd.source_code = 'OE';
        ELSIF p_shipment_type = 'PO'
        THEN
            SELECT DECODE (MAX (dc.container_ref), MIN (dc.container_ref), MAX (dc.container_ref), '{Multiple}') AS container_number
              INTO l_ret
              FROM custom.do_items di, custom.do_containers dc
             WHERE     dc.container_id = di.container_id
                   --and di.order_line_id = rsl.po_line_id
                   --and di.line_location_id = rsl.po_line_location_id
                   AND di.atr_number = p_shipment_num;
        ELSE
            l_ret   := NULL;
        END IF;

        RETURN l_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.do_debug_tools.msg (
                'GET_DELIVERY_CONTAINER Exception:' || SQLERRM);
            RETURN NULL;
    END;

    PROCEDURE process_inventory_sync
    IS
        /*
        New logic : 1) Identify sku-lock code combination for multiple entries with status = P.  If exists then update the first line quantity with sum of remaining duplicate lines quantity
                       Update the remaining duplicate line status as "Duplicate sku-lock code"
                    2) After step-1, mark all the remaining records status = 'S' and INV_CONCILLATION_DATE columns should be null
                    3) Create a new concurrent program, process the records with status ='S' and INV_CONCILLATION_DATE is NULL
                    4) In the program, perform all the remaining validations and update the line level quantity columns and send mail
        */
        l_ret_stat           VARCHAR2 (1);
        l_message            VARCHAR2 (2000);
        v_lock_code_count    NUMBER := NULL;
        v_total_sku_qty      NUMBER;
        v_processed_record   VARCHAR2 (1) := 'N';
    BEGIN
        FOR c_header
            IN (SELECT h.ohr_header_id, h.organization_id
                  FROM xxdo.xxdo_wms_3pl_ohr_h h
                 WHERE     h.process_status = 'P'
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM xxdo.xxdo_wms_3pl_ohr_l l1
                                 WHERE     l1.ohr_header_id = h.ohr_header_id
                                       AND l1.process_status != 'P')
                       AND NOT EXISTS
                               (SELECT NULL
                                  FROM xxdo.xxdo_wms_3pl_ohr_l l2
                                 WHERE     l2.ohr_header_id = h.ohr_header_id
                                       AND l2.processing_session_id !=
                                           h.processing_session_id)--AND h.processing_session_id = USERENV ('SESSIONID')
                                                                   )
        LOOP
            BEGIN
                SAVEPOINT begin_header;
                l_ret_stat           := g_ret_success;
                v_lock_code_count    := NULL;
                msg (
                       'In the process_inventory_sync...Header loop  :'
                    || c_header.ohr_header_id);
                v_processed_record   := 'N';

                FOR c_line
                    IN (SELECT l.ohr_line_id, l.sku_code, l.inventory_item_id,
                               l.quantity, l.subinventory_code
                          FROM xxdo.xxdo_wms_3pl_ohr_l l
                         WHERE     l.ohr_header_id = c_header.ohr_header_id
                               AND l.process_status = 'P'--AND l.processing_session_id = USERENV ('SESSIONID')
                                                         )
                LOOP
                    msg (
                        p_message   =>
                               'In the process_inventory_sync...Line loop  :'
                            || c_line.ohr_line_id);

                    BEGIN
                        SELECT 'Y'
                          INTO v_processed_record
                          FROM xxdo.xxdo_wms_3pl_ohr_l l1
                         WHERE     l1.ohr_header_id = c_header.ohr_header_id
                               AND l1.sku_code = c_line.sku_code
                               AND l1.subinventory_code =
                                   c_line.subinventory_code
                               AND l1.process_status = 'S'
                               AND l1.error_message IS NOT NULL
                               AND l1.ohr_line_id = c_line.ohr_line_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            v_processed_record   := 'N';
                    END;

                    msg (
                        p_message   =>
                               'In the process_inventory_sync...Record Processed ?:'
                            || v_processed_record);

                    IF v_processed_record = 'N'
                    THEN
                        BEGIN
                            SELECT COUNT (1)
                              INTO v_lock_code_count
                              FROM xxdo.xxdo_wms_3pl_ohr_l l2
                             WHERE (l2.ohr_header_id, l2.sku_code, l2.subinventory_code) IN
                                       (  SELECT l1.ohr_header_id, l1.sku_code, l1.subinventory_code
                                            FROM xxdo.xxdo_wms_3pl_ohr_l l1
                                           WHERE     l1.ohr_header_id =
                                                     c_header.ohr_header_id
                                                 AND l1.sku_code =
                                                     c_line.sku_code
                                                 AND l1.subinventory_code =
                                                     c_line.subinventory_code
                                                 AND l1.process_status = 'P'
                                                 AND l1.error_message IS NULL
                                        GROUP BY l1.ohr_header_id, l1.sku_code, l1.subinventory_code
                                          HAVING COUNT (l1.sku_code) >= 2);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_lock_code_count   := NULL;
                        END;

                        msg (
                            p_message   =>
                                   'In the process_inventory_sync...v_lock_code_count value  :'
                                || v_lock_code_count);

                        IF v_lock_code_count = 0
                        THEN
                            --Mark the records as Success
                            BEGIN
                                UPDATE xxdo.xxdo_wms_3pl_ohr_l
                                   SET process_status = 'S', error_message = 'Processing Complete'
                                 WHERE ohr_line_id = c_line.ohr_line_id;

                                UPDATE xxdo.xxdo_wms_3pl_ohr_h
                                   SET process_status = 'S', error_message = NULL
                                 WHERE ohr_header_id = c_header.ohr_header_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_ret_stat   := g_ret_error;
                                    l_message    := SQLERRM;
                            END;

                            msg (
                                p_message   =>
                                       'In the process_inventory_sync...updated ohr line table1  :'
                                    || v_lock_code_count);
                        ELSIF v_lock_code_count > 1
                        THEN
                            --Need to update the status of remaining lines to 'S' with respective status message
                            SELECT SUM (quantity)
                              INTO v_total_sku_qty
                              FROM xxdo.xxdo_wms_3pl_ohr_l l
                             WHERE     l.ohr_header_id =
                                       c_header.ohr_header_id
                                   AND l.sku_code = c_line.sku_code
                                   AND l.subinventory_code =
                                       c_line.subinventory_code;

                            UPDATE xxdo.xxdo_wms_3pl_ohr_l
                               SET quantity = v_total_sku_qty, process_status = 'S', error_message = 'Processing Complete'
                             WHERE ohr_line_id = c_line.ohr_line_id;

                            msg (
                                p_message   =>
                                       'In the process_inventory_sync...updated quantity  :'
                                    || v_total_sku_qty);
                            msg (
                                p_message   =>
                                       'In the process_inventory_sync...updated quantity for the line id  :'
                                    || c_line.ohr_line_id);

                            FOR c_dup_line
                                IN (SELECT l3.ohr_line_id
                                      FROM xxdo.xxdo_wms_3pl_ohr_l l3
                                     WHERE     l3.ohr_header_id =
                                               c_header.ohr_header_id
                                           AND l3.sku_code = c_line.sku_code
                                           AND l3.subinventory_code =
                                               c_line.subinventory_code
                                           AND l3.ohr_line_id <>
                                               c_line.ohr_line_id)
                            LOOP
                                BEGIN
                                    UPDATE xxdo.xxdo_wms_3pl_ohr_l
                                       SET process_status = 'S', error_message = 'Duplicate SKU-Lock Code information'
                                     WHERE ohr_line_id =
                                           c_dup_line.ohr_line_id;

                                    msg (
                                        p_message   =>
                                               'In the process_inventory_sync...updated ohr line table with status..line id is  :'
                                            || c_dup_line.ohr_line_id);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_ret_stat   := g_ret_error;
                                        l_message    := SQLERRM;
                                END;
                            --return;
                            --continue;
                            END LOOP;                     --end for c_dup_line

                            UPDATE xxdo.xxdo_wms_3pl_ohr_h
                               SET process_status = 'S', error_message = NULL
                             WHERE ohr_header_id = c_header.ohr_header_id;
                        END IF;                    --End for v_lock_code_count
                    END IF;                       --end for v_processed_record
                END LOOP;                                     --End for c_line
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_ret_stat   := g_ret_unexp_error;
                    l_message    := SQLERRM;
            END;

            BEGIN
                IF l_ret_stat = g_ret_success
                THEN
                    UPDATE xxdo.xxdo_wms_3pl_ohr_h
                       SET process_status = 'S', error_message = NULL
                     WHERE ohr_header_id = c_header.ohr_header_id;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;                                           --End for c_header
    EXCEPTION
        WHEN OTHERS
        THEN
            RAISE;
    END;                                      --end for process_inventory_sync

    PROCEDURE log_error (p_operation_type   IN VARCHAR2,
                         p_operation_code   IN VARCHAR2,
                         p_error_message    IN VARCHAR2,
                         p_file_name        IN VARCHAR2 := NULL,
                         p_logging_id       IN VARCHAR2 := NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO xxdo.xxdo_wms_3pl_err_log (err_id, operation_type, operation_code, error_message, file_name, logging_id, created_by, last_updated_by, process_status
                                               , processing_session_id)
             VALUES (xxdo.xxdo_wms_3pl_err_s.NEXTVAL, p_operation_type, p_operation_code, p_error_message, p_file_name, p_logging_id, apps.fnd_global.user_id, apps.fnd_global.user_id, 'E'
                     , USERENV ('SESSIONID'));

        COMMIT;
    END;

    FUNCTION mti_source_code
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN l_mti_source_code;
    END;

    --Record ID will either be a Sales Order Number - Return or a Shipment_num ASN
    PROCEDURE populate_grn_from_record_id (l_org_id         NUMBER,
                                           l_record_id   IN VARCHAR2)
    IS
        n_grn_header_id          NUMBER;
        p_source_header_id       NUMBER;
        p_source_document_code   VARCHAR2 (30);

        CURSOR c_header IS
            SELECT site_id, customer_ref, source_header_id,
                   source_document_code, TO_CHAR (SYSDATE, 'yyyymmddhh24miss') receipt_date
              FROM xxdo.xxdo_edi_3pl_preadvice_h_v
             WHERE     source_header_id = l_record_id
                   AND organization_id = l_org_id;

        CURSOR c_line IS
            SELECT sku, line_num, qty,
                   carton_code
              FROM xxdo.xxdo_edi_3pl_preadvice_l_v
             WHERE     source_header_id = l_record_id
                   AND source_document_code = p_source_document_code;
    --Next GRN Header ID
    BEGIN
        FOR h_rec IN c_header
        LOOP
            SELECT xxdo.xxdo_wms_3pl_grn_h_s.NEXTVAL
              INTO n_grn_header_id
              FROM DUAL;

            --   DBMS_OUTPUT.put_line ('n_grn_header_id : ' || n_grn_header_id);
            INSERT INTO xxdo.xxdo_wms_3pl_grn_h (grn_header_id, site_id, preadvice_id
                                                 , receipt_date)
                 VALUES (n_grn_header_id, h_rec.site_id, h_rec.customer_ref,
                         h_rec.receipt_date);

            p_source_header_id       := h_rec.source_header_id;
            p_source_document_code   := h_rec.source_document_code;

            FOR l_rec IN c_line
            LOOP
                --   DBMS_OUTPUT.put_line ('l_rec.sku : ' || l_rec.sku|| ' - '||to_char(sysdate,'YYYYMMDD HH24:MI:SS'));
                INSERT INTO xxdo.xxdo_wms_3pl_grn_l (grn_header_id,
                                                     sku_code,       --PAL.SKU
                                                     line_sequence, --PAL.LINE_NUM
                                                     qty_received,   --PAL.QTY
                                                     carton_code) --PAL.CARTON_CODE
                     VALUES (n_grn_header_id, l_rec.sku, l_rec.line_num,
                             l_rec.qty, l_rec.carton_code);
            END LOOP;
        END LOOP;

        COMMIT;
    END;

    PROCEDURE process_auto_receipt (p_org_id        IN     NUMBER,
                                    p_record_id     IN     VARCHAR,
                                    -- ORDER HEADER_ID for RMA, SHIPMENT_HEADER_ID for ASN
                                    p_record_type   IN     VARCHAR2, --REQ (ASN), RET (RETURN)
                                    p_error_stat       OUT VARCHAR2,
                                    p_error_msg        OUT VARCHAR2)
    IS
        v_record_id       VARCHAR2 (30);
        v_record_number   VARCHAR2 (30);
        l_rec_new_count   NUMBER;
        l_header_id       NUMBER;
        l_rec_count       NUMBER;
        p_request_id      NUMBER;
    BEGIN
        DBMS_OUTPUT.put_line ('Process_auto_receipt - Enter');
        DBMS_OUTPUT.put_line ('Record ID ' || p_record_id);

        --Get the corrected record_id
        IF p_record_type = 'REQ'
        THEN
            --For ASNs we get the shipment header Id,so we just pass along to the record_id value
            SELECT TO_CHAR (shipment_header_id), shipment_num, shipment_header_id
              INTO v_record_id, v_record_number, l_header_id
              FROM rcv_shipment_headers
             WHERE     shipment_header_id = p_record_id
                   AND ship_to_org_id = p_org_id;
        ELSIF p_record_type = 'RMA'
        THEN
            --For RETs,we get the order HEADER_ID but need the ORDER_NUMBER
            SELECT TO_CHAR (header_id), TO_CHAR (order_number), header_id
              INTO v_record_id, v_record_number, l_header_id
              FROM oe_order_headers_all
             WHERE header_id = p_record_id AND ship_from_org_id = p_org_id;
        ELSE
            p_error_stat   := 'E';
            p_error_msg    := 'Not a valid record type';
        END IF;

        DBMS_OUTPUT.put_line ('Updated Record ID ' || p_record_id);
        DBMS_OUTPUT.put_line ('Updated Record ID ' || v_record_id);

        --get count of lines from PA view
        SELECT COUNT (*)
          INTO l_rec_count
          FROM xxdo.xxdo_edi_3pl_preadvice_l_v
         WHERE source_header_id = v_record_id;

        DBMS_OUTPUT.put_line ('Line_count ' || l_rec_count);

        IF l_rec_count = 0
        THEN
            p_error_stat   := 'E';
            p_error_msg    := 'No lines to process';
            RETURN;
        END IF;

        --Populate the grn tables
        populate_grn_from_record_id (p_org_id, v_record_id);
        DBMS_OUTPUT.put_line ('v_record_id ' || v_record_id);

        -- check/compare grn_lines to initial count
        SELECT COUNT (*)
          INTO l_rec_new_count
          FROM xxdo.xxdo_wms_3pl_grn_l l, xxdo.xxdo_wms_3pl_grn_h h
         WHERE     l.grn_header_id = h.grn_header_id
               AND h.source_header_id = v_record_id
               AND l.process_status = 'P';

        DBMS_OUTPUT.put_line ('processed line_count ' || l_rec_new_count);

        IF l_rec_new_count != l_rec_count
        THEN
            --The sucessful processed records in the GRN tables does not equal the initial qty
            p_error_stat   := 'E';
            p_error_msg    :=
                'Not all records posted to GRN table sucessfully';
            RETURN;
        END IF;

        --process records
        process_grn;

        -- check/compare grn_lines to initial count
        SELECT COUNT (*)
          INTO l_rec_new_count
          FROM xxdo.xxdo_wms_3pl_grn_l l, xxdo.xxdo_wms_3pl_grn_h h
         WHERE     l.grn_header_id = h.grn_header_id
               AND h.source_header_id = v_record_id
               AND l.process_status = 'S';

        IF l_rec_new_count != l_rec_count
        THEN
            --The sucessful processed records in the GRN tables does not equal the initial qty
            p_error_stat   := 'E';
            p_error_msg    := 'Not all records processed sucessfully';
            RETURN;
        END IF;

        --Get RTI groups to process based on the RMA header ID or the REQ shipment header id
        FOR c_rti
            IN (SELECT DISTINCT GROUP_ID rti_group
                  FROM rcv_transactions_interface
                 WHERE    (v_record_id = shipment_header_id AND source_document_code = 'REQ')
                       OR (l_header_id = oe_order_header_id AND source_document_code = 'RMA') --   AND to_organization_id = p_org_id
                                                                                             )
        LOOP
            --Process RTI records
            apps.do_wms_receiving_utils_pub.rcv_transaction_processor (
                p_group_id     => c_rti.rti_group,
                p_wait         => 'Y',
                p_request_id   => p_request_id,
                x_ret_stat     => p_error_stat,
                x_error_text   => p_error_msg);
        END LOOP;

        --Verify receipts
        SELECT COUNT (*)
          INTO l_rec_new_count
          FROM rcv_transactions
         WHERE     ((v_record_id = shipment_header_id AND source_document_code = 'REQ') OR (l_header_id = oe_order_header_id AND source_document_code = 'RMA'))
               AND transaction_type = 'DELIVER'
               AND organization_id = p_org_id;

        IF l_rec_new_count != l_rec_count
        THEN
            --The sucessful processed records in the GRN tables does not equal the initial qty
            p_error_stat   := 'E';
            p_error_msg    := 'Not all rti records processed sucessfully';
            RETURN;
        END IF;

        p_error_stat   := 'S';
        p_error_msg    := NULL;
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            p_error_stat   := 'E';
            p_error_msg    := 'Record Not found';
        WHEN OTHERS
        THEN
            p_error_stat   := 'U';
            p_error_msg    := SQLERRM;
    END;

    PROCEDURE update_in_process_status (p_created_by IN NUMBER, p_message_type IN VARCHAR2, p_header_id IN NUMBER, p_in_process_flag IN VARCHAR2, p_comments IN VARCHAR2, x_ret_stat OUT VARCHAR2
                                        , x_message OUT VARCHAR2)
    IS
        l_proc_name    VARCHAR2 (240)
                           := lg_package_name || '.UPDATE_IN_PROCESS_STATUS';
        l_table_name   VARCHAR2 (50);
        l_comments     VARCHAR2 (2000);
        l_new_status   VARCHAR2 (1);
        l_old_status   VARCHAR2 (1);
        l_cnt          NUMBER;
        l_hist_id      NUMBER;
        l_rowid        ROWID;
        l_uid          NUMBER;                              --Added by BT Team
        l_resp_id      NUMBER;                              --Added by BT Team
        l_appl_id      NUMBER;                              --Added by BT Team
    BEGIN
        SELECT user_id
          INTO l_uid
          FROM fnd_user
         WHERE user_name = 'BATCH';                         --Added by BT Team

        BEGIN
            SAVEPOINT before_status_update;
            msg (p_message => '+' || l_proc_name);
            msg (p_message => '  Created By: ' || p_created_by);
            msg (p_message => '  Message Type: ' || p_message_type);
            msg (p_message => '  Header ID: ' || p_header_id);
            msg (p_message => '  In Process Flag: ' || p_in_process_flag);
            msg (p_message => '  Comments: ' || p_comments);
            x_ret_stat   := fnd_api.g_ret_sts_success;
            x_message    := NULL;

            IF NVL (p_in_process_flag, 'N') = 'Y'
            THEN
                l_new_status   := 'Y';
            ELSE
                l_new_status   := 'N';
            END IF;

            IF p_message_type = 'HADJ'
            THEN
                l_table_name   := 'XXDO.XXDO_WMS_3PL_ADJ_H';

                SELECT ROWID, in_process_flag
                  INTO l_rowid, l_old_status
                  FROM xxdo.xxdo_wms_3pl_adj_h
                 WHERE adj_header_id = p_header_id
                FOR UPDATE;

                UPDATE xxdo.xxdo_wms_3pl_adj_h
                   SET in_process_flag   = l_new_status
                 WHERE adj_header_id = p_header_id;

                l_cnt          := NVL (SQL%ROWCOUNT, 0);
            ELSIF p_message_type = 'HGRN'
            THEN
                l_table_name   := 'XXDO.XXDO_WMS_3PL_GRN_H';

                SELECT ROWID, in_process_flag
                  INTO l_rowid, l_old_status
                  FROM xxdo.xxdo_wms_3pl_grn_h
                 WHERE grn_header_id = p_header_id
                FOR UPDATE;

                UPDATE xxdo.xxdo_wms_3pl_grn_h
                   SET in_process_flag   = l_new_status
                 WHERE grn_header_id = p_header_id;

                l_cnt          := NVL (SQL%ROWCOUNT, 0);
            ELSIF p_message_type = 'HOSC'
            THEN
                l_table_name   := 'XXDO.XXDO_WMS_3PL_OSC_H';

                SELECT ROWID, in_process_flag
                  INTO l_rowid, l_old_status
                  FROM xxdo.xxdo_wms_3pl_osc_h
                 WHERE osc_header_id = p_header_id
                FOR UPDATE;

                UPDATE xxdo.xxdo_wms_3pl_osc_h
                   SET in_process_flag   = l_new_status
                 WHERE osc_header_id = p_header_id;

                l_cnt          := NVL (SQL%ROWCOUNT, 0);
            ELSIF p_message_type = 'HTRA'
            THEN
                l_table_name   := 'XXDO.XXDO_WMS_3PL_TRA_H';

                SELECT ROWID, in_process_flag
                  INTO l_rowid, l_old_status
                  FROM xxdo.xxdo_wms_3pl_tra_h
                 WHERE tra_header_id = p_header_id
                FOR UPDATE;

                UPDATE xxdo.xxdo_wms_3pl_tra_h
                   SET in_process_flag   = l_new_status
                 WHERE tra_header_id = p_header_id;

                l_cnt          := NVL (SQL%ROWCOUNT, 0);
            ELSIF p_message_type = 'HTRK'
            THEN
                l_table_name   := 'XXDO.XXDO_WMS_3PL_TRK_H';

                SELECT ROWID, in_process_flag
                  INTO l_rowid, l_old_status
                  FROM xxdo.xxdo_wms_3pl_trk_h
                 WHERE trk_header_id = p_header_id
                FOR UPDATE;

                UPDATE xxdo.xxdo_wms_3pl_trk_h
                   SET in_process_flag   = l_new_status
                 WHERE trk_header_id = p_header_id;

                l_cnt          := NVL (SQL%ROWCOUNT, 0);
            ELSE
                x_ret_stat   := g_ret_error;
                x_message    :=
                    'Unsupported message type (' || p_message_type || ')';
            END IF;

            IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) =
               apps.fnd_api.g_ret_sts_success
            THEN
                l_comments   := NULL;

                IF l_new_status != NVL (l_old_status, ' ')
                THEN
                    l_comments   :=
                           'In Process status changed from '''
                        || l_old_status
                        || ''' to '''
                        || l_new_status
                        || '''.'
                        || CHR (13)
                        || CHR (10);
                END IF;

                l_comments   := SUBSTR (l_comments || p_comments, 1, 2000);

                IF l_comments IS NOT NULL
                THEN
                    log_update (p_updated_by     => p_created_by,
                                p_update_type    => l_update_type_status,
                                p_update_table   => l_table_name,
                                p_update_id      => p_header_id,
                                p_update_rowid   => l_rowid,
                                p_comments       => l_comments,
                                x_ret_stat       => x_ret_stat,
                                x_hist_id        => l_hist_id,
                                x_message        => x_message);
                END IF;
            END IF;

            IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
               apps.fnd_api.g_ret_sts_success
            THEN
                ROLLBACK TO before_status_update;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_status_update;
                x_ret_stat   := fnd_api.g_ret_sts_error;
                x_message    := SQLERRM;
        END;

        msg (' x_ret_status=' || x_ret_stat || ', x_message=' || x_message);
        msg (p_message => '-' || l_proc_name);
    END;
BEGIN
    SELECT COUNT (*)
      INTO g_n_temp
      FROM v$database
     WHERE NAME = 'PROD';

    SELECT user_id
      INTO l_global_user_id
      FROM fnd_user
     WHERE user_name = 'BATCH.WMS';

    SELECT responsibility_id, application_id
      INTO l_global_resp_id, l_global_appn_id
      FROM apps.fnd_responsibility_tl
     WHERE     responsibility_name = 'Order Management Super User'
           AND LANGUAGE = 'US';

    --apps.XXDO_3PL_DEBUG_PROCEDURE('Globale User ID: '||l_global_user_id);
    --apps.XXDO_3PL_DEBUG_PROCEDURE('Globale Resp ID: '||l_global_resp_id);
    --apps.XXDO_3PL_DEBUG_PROCEDURE('Globale Appn ID: '||l_global_appn_id);
    apps.fnd_global.apps_initialize (user_id        => l_global_user_id,
                                     resp_id        => l_resp_id,
                                     resp_appl_id   => l_appn_id);

    --apps.XXDO_3PL_DEBUG_PROCEDURE('Function Resp ID: '||l_resp_id);
    --apps.XXDO_3PL_DEBUG_PROCEDURE('Function Appn ID: '||l_appn_id);
    IF apps.fnd_global.user_id = -1
    THEN
        IF g_n_temp = 1
        THEN                              -- if it's prod then log in as BATCH
            apps.fnd_global.apps_initialize (
                user_id        => l_global_user_id,
                resp_id        => l_global_resp_id,
                resp_appl_id   => l_global_appn_id);
            apps.fnd_global.initialize (l_buffer_number, l_global_user_id, --comm
                                                                           l_global_resp_id, l_global_appn_id, 0, -1, -1, -1, -1
                                        , -1, 666, -1);
        ELSE                                     -- otherwise log in as BBURNS
            apps.fnd_global.apps_initialize (
                user_id        => l_global_user_id,
                resp_id        => l_global_resp_id,
                resp_appl_id   => l_global_appn_id);
            apps.fnd_global.initialize (l_buffer_number, l_global_user_id, l_global_resp_id, l_global_appn_id, 0, -1, -1, -1, -1
                                        , -1, 666, -1);
            apps.fnd_file.put_names (
                '3PL_IFACE_' || USERENV ('SESSIONID') || '.log',
                '3PL_IFACE_' || USERENV ('SESSIONID') || '.out',
                '/usr/tmp');

            IF apps.fnd_profile.VALUE ('MFG_ORGANIZATION_ID') IS NULL
            THEN
                apps.fnd_profile.put ('MFG_ORGANIZATION_ID', 334);
            END IF;
        END IF;

        apps.fnd_profile.put ('DO_DISABLE_DROP_LPN', 'N');
    END IF;

    IF apps.fnd_global.user_id = 1062                     /*or g_n_temp = 0 */
    THEN                              -- if BBURNS then crank up the debugging
        apps.do_debug_tools.enable_table (10000000);
        apps.fnd_profile.put ('DO_3PL_MAIL_DEBUG', 'Y');
        apps.fnd_profile.put ('DO_3PL_MAIL_DEBUG_DETAIL', 'Y');
        g_mail_debugging_p            := 'Y';
        g_mail_debug_attach_debug_p   := 'Y';
    END IF;

    IF g_mail_debugging_attach_debug
    THEN
        apps.do_debug_tools.enable_table (10000000);
    END IF;
EXCEPTION
    WHEN OTHERS
    THEN
        NULL;
END xxdo_wms_3pl_interface;
/


GRANT EXECUTE ON APPS.XXDO_WMS_3PL_INTERFACE TO XXDO
/
