--
-- XXDOAP_COMMISSIONS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAP_COMMISSIONS_PKG"
AS
    /***********************************************************************************
     *$header : *
     * *
     * AUTHORS : Venkata Nagalla *
     * *
     * PURPOSE : Commission Calculation and Creation - Deckers *
     * *
     * PARAMETERS : *
     * *
     * DATE : 1-Jun-2014 *
     * *
     * Assumptions : *
     * *
     * *
     * History *
     * Vsn Change Date Changed By Change Description *
     * ----- ----------- ------------------ ------------------------------------------ *
     * 1.0 1-Jun-2014 Venkata Nagalla Initial Creation *
     * 1.1 09-May-2016  BT DEV Team Modified to pass correct sob id parameter to APPRVL*
     * 1.2 10-Aug-2016 Infosys Function get_dist_gl_date for INC0308972-ENHC0012706
    * 1.3 09-MAR-2017 Infosys Modified for the PRB0041200/CCR0006149
    * 2.0 06-Dec-2017 Arun N Murthy  for EU First Sale Project - CCR0006850
    * 3.0 15-Apr-2021 Aravind Kannuri for Impacting Commission Invoices - CCR0009213
     *********************************************************************************/


    PROCEDURE SEND_MAIL (p_msg_from VARCHAR2, p_msg_to VARCHAR2, p_msg_subject VARCHAR2
                         , p_msg_text VARCHAR2)
    IS
        msg_to   tbl_recips;
    BEGIN
        msg_to.DELETE;
        msg_to (1)   := p_msg_to;
        SEND_MAIL (p_msg_from, msg_to, p_msg_subject,
                   p_msg_text);
    END SEND_MAIL;

    PROCEDURE SEND_MAIL (p_msg_from VARCHAR2, p_msg_to tbl_recips, p_msg_subject VARCHAR2
                         , p_msg_text VARCHAR2)
    IS
        c              UTL_SMTP.connection;
        l_status       NUMBER := 0;
        msg_from       VARCHAR2 (200) := NULL;
        msg_from_exp   VARCHAR2 (200) := 'oracle';
        msg_to         VARCHAR2 (200) := NULL;
        msg_subject    VARCHAR2 (200)
            := 'Automated Alert from Oracle, no body text supplied.';
        msg_text       VARCHAR2 (2000)
            := 'Automated Alert from Oracle, no body text supplied.';
    BEGIN
        IF p_msg_from IS NULL
        THEN
            SELECT 'oracle' INTO msg_from FROM DUAL;

            SELECT '"' || NAME || '" <oracle@roadrunner.deckers.com>'
              INTO msg_from_exp
              FROM V$DATABASE;
        ELSE
            msg_from       := p_msg_from;
            msg_from_exp   := p_msg_from;
        END IF;

        IF p_msg_subject IS NULL
        THEN
            SELECT 'Automated Alert from ' || NAME || ' Database on ' || TO_CHAR (SYSDATE, 'MM/DD HH24:MI') || ' no subject text supplied.'
              INTO msg_subject
              FROM V$DATABASE;
        ELSE
            msg_subject   := p_msg_subject;
        END IF;

        IF p_msg_text IS NULL
        THEN
            SELECT 'Automated Alert from ' || NAME || ' Database on ' || TO_CHAR (SYSDATE, 'MM/DD HH24:MI') || ' no subject text supplied.'
              INTO msg_text
              FROM V$DATABASE;
        ELSE
            msg_text   := p_msg_text;
        END IF;

        -- c := utl_smtp.open_connection('127.0.0.1');                                         -- Commented by BTDEV
        c          := UTL_SMTP.open_connection ('mail.deckers.com'); -- Added by BTDEV

        l_status   := 1;
        UTL_SMTP.helo (c, 'localhost');
        UTL_SMTP.mail (c, msg_from);

        IF p_msg_to.COUNT = 0
        THEN
            UTL_SMTP.rcpt (c, 'oracle@localhost');
            msg_to   := 'oracle@localhost';
        ELSE
            msg_to   := ' ';

            FOR l_counter IN 1 .. p_msg_to.COUNT
            LOOP
                UTL_SMTP.rcpt (c, p_msg_to (l_counter));
                msg_to   := msg_to || ' ' || p_msg_to (l_counter);
            END LOOP;
        END IF;

        UTL_SMTP.open_data (c);
        l_status   := 2;
        UTL_SMTP.write_data (c, 'To: ' || msg_to || UTL_TCP.CRLF);
        UTL_SMTP.write_data (c, 'From: ' || msg_from_exp || UTL_TCP.CRLF);
        UTL_SMTP.write_data (c, 'Subject: ' || msg_subject || UTL_TCP.CRLF);
        UTL_SMTP.write_data (c, UTL_TCP.CRLF || msg_text);
        UTL_SMTP.close_data (c);
        UTL_SMTP.quit (c);
    EXCEPTION
        WHEN OTHERS
        THEN
            IF l_status = 2
            THEN
                UTL_SMTP.close_data (c);
            END IF;

            IF l_status > 0
            THEN
                UTL_SMTP.quit (c);
            END IF;

            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_TABLE, v_application_id => 'XXDOAP_COMMISSIONS_PKG.SEND_MAIL', v_debug_text => 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                  , l_debug_level => 1);
    END SEND_MAIL;

    PROCEDURE SEND_MAIL_HEADER (p_msg_from VARCHAR2, p_msg_to VARCHAR2, p_msg_subject VARCHAR2
                                , status OUT NUMBER)
    IS
        msg_to   tbl_recips;
    BEGIN
        msg_to.DELETE;
        msg_to (1)   := p_msg_to;
        send_mail_header (p_msg_from, msg_to, p_msg_subject,
                          status);
    END SEND_MAIL_HEADER;

    PROCEDURE SEND_MAIL_HEADER (p_msg_from VARCHAR2, p_msg_to tbl_recips, p_msg_subject VARCHAR2
                                , status OUT NUMBER)
    IS
        l_status            NUMBER := 0;

        msg_from            VARCHAR2 (200) := NULL;
        msg_from_exp        VARCHAR2 (200) := 'oracle';
        msg_to              VARCHAR2 (2000) := NULL;
        msg_subject         VARCHAR2 (200)
            := 'Automated Alert from Oracle, no body text supplied.';
        l_counter           NUMBER := 0;
        c_global_not_null   EXCEPTION;
    BEGIN
        IF c_global_flag <> 0
        THEN
            RAISE c_global_not_null;
        END IF;

        IF p_msg_from IS NULL
        THEN
            SELECT 'oracle' INTO msg_from FROM DUAL;

            SELECT '"' || NAME || '" <oracle@roadrunner.deckers.com>'
              INTO msg_from_exp
              FROM V$DATABASE;
        ELSE
            msg_from       := p_msg_from;
            msg_from_exp   := p_msg_from;
        END IF;

        IF p_msg_subject IS NULL
        THEN
            SELECT 'Automated Alert from ' || NAME || ' Database on ' || TO_CHAR (SYSDATE, 'MM/DD HH24:MI') || ' no subject text supplied.'
              INTO msg_subject
              FROM V$DATABASE;
        ELSE
            msg_subject   := p_msg_subject;
        END IF;


        -- c_global := utl_smtp.open_connection('127.0.0.1');                       -- commented by #BTDEV
        c_global        := UTL_SMTP.open_connection ('mail.deckers.com'); --Added by BTDEV

        c_global_flag   := 1;
        l_status        := 1;
        UTL_SMTP.helo (c_global, 'localhost');
        UTL_SMTP.mail (c_global, msg_from);

        IF p_msg_to.COUNT = 0
        THEN
            UTL_SMTP.rcpt (c_global, 'oracle@localhost');
            msg_to   := 'oracle@localhost';
        ELSE
            msg_to   := ' ';

            FOR l_counter IN 1 .. p_msg_to.COUNT
            LOOP
                UTL_SMTP.rcpt (c_global, p_msg_to (l_counter));
                msg_to   := msg_to || ' ' || p_msg_to (l_counter);
            END LOOP;
        END IF;

        UTL_SMTP.open_data (c_global);
        l_status        := 2;
        UTL_SMTP.write_data (c_global, 'To: ' || msg_to || UTL_TCP.CRLF);
        UTL_SMTP.write_data (c_global,
                             'From: ' || msg_from_exp || UTL_TCP.CRLF);
        UTL_SMTP.write_data (c_global,
                             'Subject: ' || msg_subject || UTL_TCP.CRLF);

        status          := 0;
    EXCEPTION
        WHEN c_global_not_null
        THEN
            IF l_status = 2
            THEN
                UTL_SMTP.close_data (c_global);
            END IF;

            IF l_status > 0
            THEN
                UTL_SMTP.quit (c_global);
            END IF;

            status   := -2;
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_TABLE, v_application_id => 'XXDOAP_COMMISSIONS_PKG.SEND_MAIL_HEADER', v_debug_text => 'c_global was not null during call to send_mail_header.'
                                  , l_debug_level => 1);
        WHEN OTHERS
        THEN
            IF l_status = 2
            THEN
                UTL_SMTP.close_data (c_global);
            END IF;

            IF l_status > 0
            THEN
                UTL_SMTP.quit (c_global);
            END IF;

            c_global_flag   := 0;
            status          := -255;
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_TABLE, v_application_id => 'XXDOAP_COMMISSIONS_PKG.SEND_MAIL_HEADER', v_debug_text => 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                  , l_debug_level => 1);
    END SEND_MAIL_HEADER;


    PROCEDURE SEND_MAIL_LINE (msg_text VARCHAR2, status OUT NUMBER)
    IS
        c_global_not_connected   EXCEPTION;
    BEGIN
        IF c_global_flag = 0
        THEN
            RAISE c_global_not_connected;
        END IF;

        UTL_SMTP.write_data (c_global, msg_text || UTL_TCP.CRLF);

        status   := 0;
    EXCEPTION
        WHEN c_global_not_connected
        THEN
            status   := -2;
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_TABLE, v_application_id => 'XXDOAP_COMMISSIONS_PKG.SEND_MAIL_LINE', v_debug_text => 'c_global was not null connected during call to send_mail_line.'
                                  , l_debug_level => 1);
        WHEN OTHERS
        THEN
            status   := -255;
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_TABLE, v_application_id => 'XXDOAP_COMMISSIONS_PKG.SEND_MAIL_LINE', v_debug_text => 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                  , l_debug_level => 1);
    END SEND_MAIL_LINE;

    PROCEDURE SEND_MAIL_CLOSE (status OUT NUMBER)
    IS
        c_global_not_connected   EXCEPTION;
    BEGIN
        IF c_global_flag = 0
        THEN
            RAISE c_global_not_connected;
        END IF;

        UTL_SMTP.close_data (c_global);
        UTL_SMTP.quit (c_global);

        c_global_flag   := 0;
        status          := 0;
    EXCEPTION
        WHEN c_global_not_connected
        THEN
            status   := -1;
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_TABLE, v_application_id => 'XXDOAP_COMMISSIONS_PKG.SEND_MAIL_CLOSE', v_debug_text => 'not connected'
                                  , l_debug_level => 1);
        WHEN OTHERS
        THEN
            status          := -255;
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_DEBUG_UTILS.DEBUG_TABLE, v_application_id => 'XXDOAP_COMMISSIONS_PKG.SEND_MAIL_CLOSE', v_debug_text => 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                  , l_debug_level => 1);
            c_global_flag   := 0;
    END SEND_MAIL_CLOSE;

    PROCEDURE print_line (p_mode    IN VARCHAR2 DEFAULT 'L',
                          p_input   IN VARCHAR2)
    IS
    BEGIN
        IF p_mode = 'O'
        THEN
            fnd_file.put_line (fnd_file.output, p_input);
        ELSE
            fnd_file.put_line (fnd_file.LOG, p_input);
        END IF;
    END print_line;

    FUNCTION is_null (p_input IN VARCHAR2)
        RETURN BOOLEAN
    IS
        l_result   BOOLEAN;
    BEGIN
        IF p_input IS NULL
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END is_null;

    PROCEDURE get_ar_trx_num (p_trx_id IN NUMBER)
    IS
        l_trx_num   VARCHAR2 (50);
    BEGIN
        SELECT trx_number
          INTO xxdoap_commissions_pkg.g_target_ar_trx_num
          FROM ra_customer_trx_all
         WHERE customer_trx_id = p_trx_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            print_line ('O', 'Unable to get trx_number:' || p_trx_id); -- Added for v1.3
    END get_ar_trx_num;

    FUNCTION get_batch_source
        RETURN NUMBER
    IS
        l_batch_id   NUMBER;
    BEGIN
        SELECT NAME, batch_source_id
          INTO xxdoap_commissions_pkg.g_target_ar_source, l_batch_id
          FROM ra_batch_sources_all rbs
         WHERE     NVL (attribute1, 'N') = 'Y'
               AND org_id = xxdoap_commissions_pkg.g_target_ar_org_id
               AND NVL (start_date, xxdoap_commissions_pkg.g_target_date) <=
                   xxdoap_commissions_pkg.g_target_date;

        RETURN l_batch_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Unable to get batch source:' || SQLERRM);
            RETURN NULL;
    END get_batch_source;

    FUNCTION get_vendor_exclusion (p_vendor_id      IN NUMBER,
                                   p_invoice_type   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_boolean   BOOLEAN;
        l_exclude   VARCHAR2 (30) := NULL;
    BEGIN
        BEGIN
            --print_line('L','Before SELECT:'||l_exclude);
            SELECT attribute6
              INTO l_exclude
              FROM ap_suppliers
             WHERE vendor_id = p_vendor_id;
        --print_line('L','After SELECT:'||l_exclude);
        EXCEPTION
            WHEN OTHERS
            THEN
                print_line ('L', 'Error getting exclusion flag:' || SQLERRM);
                l_exclude   := NULL;
        END;

        --print_line('L','Exclude Flag for Supplier:'||l_exclude);
        IF l_exclude IS NULL
        THEN
            --print_line('L','No exclusions from commission calculation at supplier level');
            RETURN 'N';
        ELSE
            IF UPPER (l_exclude) = 'ALL'
            THEN
                --print_line('L','Both Invoices and Credit Memos Excluded from commission calculation at supplier level');
                RETURN 'Y';
            ELSIF UPPER (l_exclude) = 'CM'
            THEN
                IF UPPER (p_invoice_type) = 'CREDIT'
                THEN
                    --print_line('L','Credit Memos Excluded from commission calculation at supplier level');
                    RETURN 'Y';
                ELSE
                    --print_line('L','Invoices not excluded from commission calculation at supplier level');
                    RETURN 'N';
                END IF;
            ELSE
                RETURN 'N';
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Error in get_vendor_exclusion:' || SQLERRM);
            RETURN NULL;
    END get_vendor_exclusion;

    FUNCTION get_ven_site_exclusion (p_ven_site_id    IN NUMBER,
                                     p_invoice_type   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_boolean   BOOLEAN;
        l_exclude   VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT apsa.attribute2                       --Exclude Commissions
              INTO l_exclude
              FROM ap_supplier_sites_all apsa, hz_party_sites hps
             WHERE     1 = 1
                   AND hps.party_site_id = apsa.party_site_id
                   AND apsa.vendor_site_id = p_ven_site_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_exclude   := NULL;
        END;

        IF l_exclude IS NULL
        THEN
            --print_line('L','No exclusions from commission calculation at supplier site level');
            RETURN 'N';
        ELSE
            IF UPPER (l_exclude) = 'ALL'
            THEN
                --print_line('L','Both Invoices and Credit Memos Excluded from commission calculation at supplier site level');
                RETURN 'Y';
            ELSIF UPPER (l_exclude) = 'CM'
            THEN
                IF UPPER (p_invoice_type) = 'CREDIT'
                THEN
                    --print_line('L','Credit Memos Excluded from commission calculation at supplier site level');
                    RETURN 'Y';
                ELSE
                    --print_line('L','Invoices not excluded from commission calculation at supplier site level');
                    RETURN 'N';
                END IF;
            ELSE
                RETURN 'N';
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Error in get_ven_site_exclusion:' || SQLERRM);
            RETURN NULL;
    END get_ven_site_exclusion;

    FUNCTION get_concatenated_code
        RETURN VARCHAR2
    IS
        l_segments   VARCHAR2 (50);
    BEGIN
        SELECT concatenated_segments
          INTO l_segments
          FROM gl_code_combinations_kfv
         WHERE code_combination_id =
               xxdoap_commissions_pkg.g_target_ap_dist_set_id;

        RETURN l_segments;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_target_sob (p_org_id IN NUMBER)
        RETURN NUMBER
    IS
        l_sob_id   NUMBER;
    BEGIN
        SELECT set_of_books_id
          INTO l_sob_id
          FROM hr_operating_units
         WHERE organization_id = p_org_id;

        BEGIN
            SELECT currency_code
              INTO xxdoap_commissions_pkg.g_ar_base_currency
              FROM gl_ledgers
             WHERE ledger_id = l_sob_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        RETURN l_sob_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_target_sob;

    FUNCTION get_brand (p_invoice_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_brand   VARCHAR2 (30);
    BEGIN
        SELECT pol.attribute1
          INTO l_brand
          FROM ap_invoice_lines_all l, po_lines_all pol
         WHERE     l.po_line_id = pol.po_line_id
               AND l.invoice_id = p_invoice_id
               AND ROWNUM = 1                        --GROUP BY pol.attribute1
                             ;

        RETURN l_brand;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 'UGG';
        WHEN OTHERS
        THEN
            print_line ('L', 'Unable to get brand:' || SQLERRM);
            RETURN NULL;
    END get_brand;

    FUNCTION get_commission_amt (p_invoice_id IN NUMBER)
        RETURN NUMBER
    IS
        CURSOR c_po IS
              SELECT aia.invoice_num invoice_num, aila.line_number inv_line_num, aila.amount inv_line_amt,
                     pol.line_num po_line_num, pol.unit_price * pol.quantity po_line_amt, pol.creation_date po_line_creation_dt
                FROM ap_invoice_lines_all aila, ap_invoices_all aia, po_lines_all pol
               WHERE     1 = 1
                     AND aia.invoice_id = aila.invoice_id
                     AND aila.po_line_id = pol.po_line_id
                     AND aia.invoice_id = p_invoice_id
            ORDER BY aila.line_number;

        CURSOR c_non_po IS
            SELECT aia.invoice_num, aia.creation_date inv_creation_dt, aia.invoice_amount
              FROM ap_invoices_all aia
             WHERE aia.invoice_id = p_invoice_id;

        l_comm_perc   NUMBER;
        l_comm_amt    NUMBER;
        l_total_amt   NUMBER;
    BEGIN
        print_line (
            'L',
            'Source Relation Trx Type:' || xxdoap_commissions_pkg.g_relation_trx_type);

        IF xxdoap_commissions_pkg.g_relation_trx_type = 'INV/CREDIT'
        THEN
            l_comm_perc   := 0;
            l_total_amt   := 0;
            l_comm_amt    := 0;

            FOR r_non_po IN c_non_po
            LOOP
                l_comm_perc   := 0;
                l_comm_amt    := 0;
                l_comm_perc   :=
                    get_commission_perc (r_non_po.inv_creation_dt);
                l_comm_amt    := l_comm_perc * r_non_po.invoice_amount / 100;
                l_total_amt   := l_total_amt + l_comm_amt;
                print_line (
                    'L',
                       'Invoice#'
                    || r_non_po.invoice_num
                    || ' Invoice Amount:'
                    || TO_CHAR (r_non_po.invoice_amount)
                    || ' Invoice Creation Date:'
                    || TO_CHAR (r_non_po.inv_creation_dt, 'DD-MON-YYYY')
                    || ' Commission Percentage:'
                    || TO_CHAR (l_comm_perc)
                    || ' Commission Amount:'
                    || TO_CHAR (l_comm_amt));
            END LOOP;

            print_line ('L',
                        'Total Commission Amount:' || TO_CHAR (l_total_amt));
        ELSE
            l_comm_perc   := 0;
            l_total_amt   := 0;
            l_comm_amt    := 0;

            FOR r_po IN c_po
            LOOP
                l_comm_perc   := 0;
                l_comm_amt    := 0;
                l_comm_perc   :=
                    get_commission_perc (r_po.po_line_creation_dt);
                l_comm_amt    := l_comm_perc * r_po.po_line_amt / 100;
                l_total_amt   := l_total_amt + l_comm_amt;
                print_line (
                    'L',
                       'Invoice#'
                    || r_po.invoice_num
                    || ' Invoice Line#'
                    || TO_CHAR (r_po.inv_line_num)
                    || ' PO Line Amount:'
                    || TO_CHAR (r_po.po_line_amt)
                    || ' PO Line Creation Date:'
                    || TO_CHAR (r_po.po_line_creation_dt, 'DD-MON-YYYY')
                    || ' Commission Percentage:'
                    || TO_CHAR (l_comm_perc)
                    || ' Commission Amount for the line:'
                    || TO_CHAR (l_comm_amt));
            END LOOP;

            print_line ('L',
                        'Total Commission Amount:' || TO_CHAR (l_total_amt));
        END IF;

        RETURN l_total_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_commission_amt;

    FUNCTION get_po_num (p_invoice_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_po_num   VARCHAR2 (30);
    BEGIN
        SELECT segment1
          INTO l_po_num
          FROM                                            --start Changes V2.1
               (  SELECT poh.po_header_id, poh.segment1
                    --FROM ap_invoice_lines_all l, po_headers_all pol
                    FROM ap_invoice_distributions_all aida, po_distributions_all pod, po_headers_all poh
                   WHERE     aida.po_distribution_id = pod.po_distribution_id
                         AND pod.po_header_id = poh.po_header_id
                         AND aida.invoice_id = p_invoice_id
                ORDER BY poh.po_header_id DESC)
         WHERE 1 = 1                                        --End Changes V2.1
                     AND ROWNUM = 1                   -- GROUP BY pol.segment1
                                   ;

        RETURN l_po_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            --print_line('L','Unable to get po number:'||SQLERRM);
            RETURN NULL;
    END get_po_num;

    FUNCTION is_dist_set_valid (p_dist_set_id IN NUMBER)
        RETURN VARCHAR2
    IS
        CURSOR c_ccid IS
            SELECT lin.dist_code_combination_id
              FROM ap_distribution_set_lines_all lin, ap_distribution_sets_all set1
             WHERE     1 = 1
                   AND lin.distribution_set_id = set1.distribution_set_id
                   AND set1.org_id =
                       xxdoap_commissions_pkg.g_target_ap_org_id
                   AND set1.distribution_set_id = p_dist_set_id
                   AND NVL (set1.inactive_date, SYSDATE) >= SYSDATE;

        l_count   NUMBER;
        l_valid   VARCHAR2 (1) := 'Y';
    BEGIN
        FOR r_ccid IN c_ccid
        LOOP
            l_count   := 0;

            SELECT COUNT (1)
              INTO l_count
              FROM gl_code_combinations
             WHERE     code_combination_id = r_ccid.dist_code_combination_id
                   AND enabled_flag = 'Y';

            IF l_count <> 1
            THEN
                print_line (
                    'L',
                       'Invalid CCID:'
                    || TO_CHAR (r_ccid.dist_code_combination_id));
                l_valid   := 'N';
            END IF;
        END LOOP;

        RETURN l_valid;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Error in is_dist_set_valid:' || SQLERRM);
            RETURN 'N';
    END is_dist_set_valid;

    FUNCTION get_po_date (p_invoice_id IN NUMBER)
        RETURN DATE
    IS
        l_po_date   VARCHAR2 (30);
    BEGIN
        SELECT creation_date
          INTO l_po_date
          FROM                                            --start Changes V2.1
               (  SELECT poh.po_header_id, poh.creation_date
                    --FROM ap_invoice_lines_all l, po_headers_all pol
                    FROM ap_invoice_distributions_all aida, po_distributions_all pod, po_headers_all poh
                   WHERE     aida.po_distribution_id = pod.po_distribution_id
                         AND pod.po_header_id = poh.po_header_id
                         AND aida.invoice_id = p_invoice_id
                ORDER BY poh.po_header_id DESC)
         WHERE 1 = 1                                        --End Changes V2.1
                     AND ROWNUM = 1                   -- GROUP BY pol.segment1
                                   ;

        RETURN l_po_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Unable to get po date:' || SQLERRM);
            RETURN NULL;
    END get_po_date;


    -- Function get_dist_gl_date Added by Infosys on 10-AUG-2016 for INC0308972-ENHC0012706 -- 1.2
    FUNCTION get_dist_gl_date (p_invoice_id    IN NUMBER,
                               pd_start_date      DATE,
                               pd_end_date        DATE)
        RETURN DATE
    IS
        l_dist_gl_date   VARCHAR2 (30);
    BEGIN
        SELECT MAX (accounting_date)
          INTO l_dist_gl_date
          FROM ap.ap_invoice_distributions_all aida
         WHERE     1 = 1
               AND aida.invoice_id = p_invoice_id
               AND accounting_date BETWEEN pd_start_date AND pd_end_date;

        RETURN l_dist_gl_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line (
                'L',
                   'Unable to get Distrubtion GL Date for invoice id: '
                || p_invoice_id
                || '-'
                || SQLERRM);
            RETURN NULL;
    END get_dist_gl_date;


    FUNCTION get_dist_amount (p_invoice_id    IN NUMBER,
                              pd_start_date      DATE,
                              pd_end_date        DATE)
        RETURN NUMBER
    IS
        l_dist_amount   NUMBER;
    BEGIN
        SELECT SUM (NVL (base_amount, amount))
          INTO l_dist_amount
          FROM ap.ap_invoice_distributions_all aida
         WHERE     aida.invoice_id = p_invoice_id
               AND accounting_date BETWEEN pd_start_date AND pd_end_date;

        RETURN l_dist_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line (
                'L',
                   'Unable to get Distrubtion GL Date for invoice id: '
                || p_invoice_id
                || '-'
                || SQLERRM);
            RETURN NULL;
    END get_dist_amount;

    --Start changes by Deckers IT Team on 09-May-2017
    FUNCTION get_is_commissionable (pn_invoice_id NUMBER)
        RETURN CHAR
    IS
        xn_yes_no   CHAR := 'N';
    BEGIN
        SELECT DISTINCT 'Y'
          INTO xn_yes_no
          FROM ap_invoices_all aia, ap_suppliers aps, ap_supplier_sites_all apss
         WHERE     1 = 1
               AND aia.vendor_id = aps.vendor_id
               AND aia.vendor_site_id = apss.vendor_site_id
               AND aia.org_id = apss.org_id
               AND aps.vendor_type_lookup_code = 'MANUFACTURER'
               AND aia.invoice_id = NVL (pn_invoice_id, aia.invoice_id)
               --                AND NVL (aia.attribute9, 'N') = 'N'  --Commissions created DFF
               --Check if transaction type excluded at supplier level
               AND xxdoap_commissions_pkg.get_vendor_exclusion (
                       aia.vendor_id,
                       aia.invoice_type_lookup_code) =
                   'N'
               --Check if transaction type excluded at site level
               AND xxdoap_commissions_pkg.get_ven_site_exclusion (
                       aia.vendor_site_id,
                       aia.invoice_type_lookup_code) =
                   'N'
               --Validate and Accounted invoices only
               AND ap_invoices_pkg.get_posting_status (aia.invoice_id) = 'Y';

        RETURN xn_yes_no;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('',
                        'Error while deriving IS Commissionable ' || SQLERRM);
            RETURN xn_yes_no;
    END get_is_commissionable;

    --End changes by Deckers IT Team on 09-May-2017

    FUNCTION get_tgt_cust_site_id
        RETURN NUMBER
    IS
        l_site_id   NUMBER;
    BEGIN
        SELECT cust_acct_site_id
          INTO l_site_id
          FROM hz_cust_site_uses_all
         WHERE site_use_id = xxdoap_commissions_pkg.g_target_cust_site_use_id;

        RETURN l_site_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Unable to get Customer Site ID:' || SQLERRM);
            RETURN NULL;
    END get_tgt_cust_site_id;

    FUNCTION check_open_period (p_target_date IN DATE)
        RETURN BOOLEAN
    IS
        l_boolean             BOOLEAN;
        l_ap_closing_status   VARCHAR2 (10);
        l_ar_closing_status   VARCHAR2 (10);
        l_next_date           DATE;
    BEGIN
        --Check AR open period
        BEGIN
            SELECT closing_status
              INTO l_ar_closing_status
              FROM gl_period_statuses gps, hr_operating_units hou, fnd_application fa
             WHERE     1 = 1                          --period_name = 'JUN-15'
                   AND gps.application_id = fa.application_id
                   AND fa.application_short_name = 'AR'
                   AND gps.closing_status = 'O'
                   AND gps.set_of_books_id = hou.set_of_books_id
                   AND hou.organization_id =
                       xxdoap_commissions_pkg.g_target_ar_org_id
                   AND start_date <= p_target_date
                   AND end_date >= p_target_date;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_ar_closing_status   := 'C';
        END;

        IF NVL (l_ar_closing_status, 'C') != 'O'
        THEN
            print_line ('L', 'AR Period Closed.');
        END IF;

        --Check AP open period
        BEGIN
            SELECT closing_status
              INTO l_ap_closing_status
              FROM gl_period_statuses gps, hr_operating_units hou, fnd_application fa
             WHERE     1 = 1                          --period_name = 'JUN-15'
                   AND gps.application_id = fa.application_id
                   AND fa.application_short_name = 'SQLAP'
                   AND gps.closing_status = 'O'
                   AND gps.set_of_books_id = hou.set_of_books_id
                   AND hou.organization_id =
                       xxdoap_commissions_pkg.g_target_ap_org_id
                   AND start_date <= p_target_date
                   AND end_date >= p_target_date;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_ap_closing_status   := 'C';
        END;

        IF NVL (l_ap_closing_status, 'C') != 'O'
        THEN
            print_line ('L', 'AP Period Closed.');
        END IF;

        IF l_ar_closing_status != 'O' OR l_ap_closing_status != 'O'
        THEN
            print_line ('L', 'Check for the next period');

            SELECT LAST_DAY (p_target_date) + 1 INTO l_next_date FROM DUAL;

            --Check AR open period
            BEGIN
                SELECT closing_status
                  INTO l_ar_closing_status
                  FROM gl_period_statuses gps, hr_operating_units hou, fnd_application fa
                 WHERE     1 = 1                      --period_name = 'JUN-15'
                       AND gps.application_id = fa.application_id
                       AND fa.application_short_name = 'AR'
                       AND gps.closing_status = 'O'
                       AND gps.set_of_books_id = hou.set_of_books_id
                       AND hou.organization_id =
                           xxdoap_commissions_pkg.g_target_ar_org_id
                       AND start_date <= l_next_date
                       AND end_date >= l_next_date;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_ar_closing_status   := 'C';
            END;

            IF NVL (l_ar_closing_status, 'C') != 'O'
            THEN
                print_line ('L', 'Next AR Period Not Open.');
            END IF;

            --Check AR open period
            BEGIN
                SELECT closing_status
                  INTO l_ap_closing_status
                  FROM gl_period_statuses gps, hr_operating_units hou, fnd_application fa
                 WHERE     1 = 1                      --period_name = 'JUN-15'
                       AND gps.application_id = fa.application_id
                       AND fa.application_short_name = 'SQLAP'
                       AND gps.closing_status = 'O'
                       AND gps.set_of_books_id = hou.set_of_books_id
                       AND hou.organization_id =
                           xxdoap_commissions_pkg.g_target_ap_org_id
                       AND start_date <= l_next_date
                       AND end_date >= l_next_date;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_ap_closing_status   := 'C';
            END;

            IF NVL (l_ap_closing_status, 'C') != 'O'
            THEN
                print_line ('L', 'Next AP Period Not Open.');
            END IF;

            IF l_ar_closing_status != 'O' OR l_ap_closing_status != 'O'
            THEN
                RETURN FALSE;
            ELSE
                print_line (
                    'L',
                       'Next Target Date:'
                    || TO_CHAR (l_next_date, 'DD-MON-YYYY'));
                xxdoap_commissions_pkg.g_target_date   := l_next_date;
                RETURN TRUE;
            END IF;
        ELSE
            RETURN TRUE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Unable to check open period:' || SQLERRM);
            RETURN FALSE;
    END check_open_period;

    FUNCTION get_trx_type (p_class IN VARCHAR2)
        RETURN NUMBER
    IS
        l_type_id   NUMBER;
    BEGIN
        SELECT cust_trx_type_id
          INTO l_type_id
          FROM ra_cust_trx_types_all
         WHERE     org_id = xxdoap_commissions_pkg.g_target_ar_org_id
               AND attribute3 = 'Y'
               AND TYPE = p_class
               AND NVL (start_date, xxdoap_commissions_pkg.g_target_date) <=
                   xxdoap_commissions_pkg.g_target_date;

        RETURN l_type_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Unable to get batch source:' || SQLERRM);
            RETURN NULL;
    END get_trx_type;

    FUNCTION get_commission_perc (p_comm_date IN DATE)
        RETURN NUMBER
    IS
        l_commission   NUMBER;
    BEGIN
        SELECT TO_NUMBER (ffv.flex_value)
          INTO l_commission
          FROM fnd_flex_values ffv, fnd_flex_value_sets ffvs
         WHERE     1 = 1
               AND ffv.flex_value_set_id = ffvs.flex_value_set_id
               AND ffvs.flex_value_set_name =
                   xxdoap_commissions_pkg.g_commission_value_set
               AND ffv.parent_flex_value_low =
                   xxdoap_commissions_pkg.g_relationship
               AND ffv.enabled_flag = 'Y'
               AND ffv.start_date_active IS NOT NULL
               AND TRUNC (ffv.start_date_active) <= p_comm_date
               AND TRUNC (NVL (ffv.end_date_active, SYSDATE)) >= p_comm_date;

        print_line (
            'L',
               'Commission% '
            || xxdoap_commissions_pkg.g_relationship
            || ' for the invoice date: '
            || TO_CHAR (p_comm_date, 'DD-MON-YYYY')
            || '='
            || TO_CHAR (l_commission));
        RETURN l_commission;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            print_line (
                'L',
                   'Commission Percentage for relationship:'
                || xxdoap_commissions_pkg.g_relationship
                || ' not found for the date: '
                || TO_CHAR (p_comm_date, 'DD-MON-YYYY'));
            RETURN NULL;
        WHEN TOO_MANY_ROWS
        THEN
            print_line (
                'L',
                   'Multiple commission percentages found for relationship:'
                || xxdoap_commissions_pkg.g_relationship
                || ' for the date: '
                || TO_CHAR (p_comm_date, 'DD-MON-YYYY'));
            RETURN NULL;
        WHEN OTHERS
        THEN
            print_line ('L', 'Error in get_commission_perc' || SQLERRM);
            RETURN NULL;
    END get_commission_perc;

    FUNCTION get_org_name (p_org_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_name   hr_operating_units.NAME%TYPE;
    BEGIN
        SELECT NAME
          INTO l_name
          FROM hr_operating_units
         WHERE organization_id = p_org_id;

        RETURN l_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_org_name;

    FUNCTION get_vendor_name (p_vendor_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_name   ap_suppliers.vendor_name%TYPE;
    BEGIN
        SELECT vendor_name
          INTO l_name
          FROM ap_suppliers
         WHERE vendor_id = p_vendor_id;

        RETURN l_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_vendor_name;

    FUNCTION get_site_code (p_vendor_site_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_code   ap_supplier_sites_all.vendor_site_code%TYPE;
    BEGIN
        SELECT vendor_site_code
          INTO l_code
          FROM ap_supplier_sites_all
         WHERE vendor_site_id = p_vendor_site_id;

        RETURN l_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_site_code;

    FUNCTION get_currency_code
        RETURN VARCHAR2
    IS
        l_curr_code   VARCHAR2 (30);
    BEGIN
          SELECT currency_code
            INTO l_curr_code
            FROM xxdo.xxdoap_commissions_stg
           WHERE request_id = xxdoap_commissions_pkg.g_conc_request_id
        GROUP BY currency_code;

        RETURN l_curr_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_currency_code;

    PROCEDURE get_customer_det (p_customer_id IN NUMBER, x_customer_num OUT VARCHAR2, x_customer_name OUT VARCHAR2)
    IS
        l_num    hz_cust_accounts.account_number%TYPE;
        l_name   hz_parties.party_name%TYPE;
    BEGIN
        SELECT hp.party_name, hca.account_number
          INTO l_name, l_num
          FROM hz_cust_accounts hca, hz_parties hp
         WHERE     1 = 1
               AND hca.party_id = hp.party_id
               AND hca.cust_account_id = p_customer_id;

        x_customer_num    := l_num;
        x_customer_name   := l_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_customer_num    := NULL;
            x_customer_name   := NULL;
    END get_customer_det;

    FUNCTION is_cust_site_setup (p_site_use_id IN NUMBER, x_term_id OUT NUMBER, x_rev_acc_id OUT NUMBER --,x_rec_acc_id OUT NUMBER
                                 , x_ret_message OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        l_term_id      NUMBER;
        l_rev_acc_id   NUMBER;
        l_rec_acc_id   NUMBER;
        l_message      VARCHAR2 (360);
    BEGIN
        SELECT payment_term_id, gl_id_rev
          --, gl_id_rec
          INTO l_term_id, l_rev_acc_id
          --, l_rec_acc_id
          FROM hz_cust_site_uses_all
         WHERE site_use_id = p_site_use_id;

        IF l_term_id IS NULL
        THEN
            l_message   :=
                   l_message
                || ' Payment Terms not setup at Target Customer Bill To Site Use Details.';
        END IF;

        IF l_rev_acc_id IS NULL
        THEN
            l_message   :=
                   l_message
                || ' Revenue account not setup at Target Customer Bill To Site Accounting Details.';
        END IF;

        --IF l_rec_acc_id IS NULL THEN
        -- l_message := l_message||' Receivable account not setup at Customer Bill To Site Accounting Details.';
        --END IF;
        IF l_message IS NULL
        THEN
            x_term_id       := l_term_id;
            x_rev_acc_id    := l_rev_acc_id;
            --x_rec_acc_id := l_rec_acc_id;
            x_ret_message   := NULL;
            RETURN 'Y';
        ELSE
            x_ret_message   := l_message;
            RETURN 'N';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_message   := 'Error in is_cust_site_setup:' || SQLERRM;
            RETURN 'N';
    END is_cust_site_setup;

    FUNCTION is_supp_site_setup (p_supp_site_id IN NUMBER, x_term_id OUT NUMBER, x_pay_method_code OUT VARCHAR2
                                 , x_dist_set_id OUT NUMBER, x_ship_to_loc_id OUT NUMBER, x_ret_message OUT VARCHAR2)
        RETURN VARCHAR2
    IS
        l_term_id           NUMBER;
        l_pay_method_code   VARCHAR2 (30);
        l_dist_set_id       NUMBER;
        l_message           VARCHAR2 (360);
        l_ship_to_loc_id    NUMBER;
    BEGIN
        BEGIN
            SELECT terms_id, distribution_set_id, ship_to_location_id
              INTO l_term_id, l_dist_set_id, l_ship_to_loc_id
              FROM ap_supplier_sites_all
             WHERE vendor_site_id = p_supp_site_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_term_id          := NULL;
                l_dist_set_id      := NULL;
                l_ship_to_loc_id   := NULL;
        END;

        BEGIN
            SELECT ieppm.payment_method_code
              INTO l_pay_method_code
              FROM ap_supplier_sites_all assa, iby_external_payees_all iepa, iby_ext_party_pmt_mthds ieppm
             WHERE     1 = 1                  --sup.vendor_id = assa.vendor_id
                   AND assa.pay_site_flag = 'Y'
                   AND ieppm.primary_flag = 'Y'
                   AND assa.vendor_site_id = iepa.supplier_site_id
                   AND iepa.ext_payee_id = ieppm.ext_pmt_party_id
                   AND ((ieppm.inactive_date IS NULL) OR (ieppm.inactive_date > SYSDATE))
                   --AND assa.VENDOR_SITE_CODE='TEST_ADD1'
                   AND vendor_site_id = p_supp_site_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_pay_method_code   := NULL;
        END;

        IF l_term_id IS NULL
        THEN
            l_message   :=
                   l_message
                || ' Payment Terms not setup at Target Supplier Site level.';
        END IF;

        IF l_dist_set_id IS NULL
        THEN
            l_message   :=
                   l_message
                || ' Default Distribution Set not setup at Target Supplier Site level.';
        ELSE
            IF is_dist_set_valid (l_dist_set_id) = 'N'
            THEN
                l_message   :=
                       l_message
                    || ' Invalid distribution set/code combinations setup at Supplier Site';
            END IF;
        END IF;

        IF l_pay_method_code IS NULL
        THEN
            l_message   :=
                   l_message
                || ' Default Payment Method code not setup at Target Supplier Site level';
        END IF;

        IF l_ship_to_loc_id IS NULL
        THEN
            l_message   :=
                   l_message
                || ' Default Ship To Location not setup at Target Supplier Site level';
        END IF;

        IF l_message IS NULL
        THEN
            x_term_id           := l_term_id;
            x_pay_method_code   := l_pay_method_code;
            x_dist_set_id       := l_dist_set_id;
            x_ship_to_loc_id    := l_ship_to_loc_id;
            x_ret_message       := NULL;
            RETURN 'Y';
        ELSE
            x_ret_message   := l_message;
            RETURN 'N';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_message   := 'Error in is_supp_site_setup:' || SQLERRM;
            RETURN 'N';
    END is_supp_site_setup;

    PROCEDURE get_target_details (x_target_ar_org_name OUT VARCHAR2, x_target_ap_org_name OUT VARCHAR2, x_customer_name OUT VARCHAR2
                                  , x_customer_number OUT VARCHAR2, x_tgt_vendor_name OUT VARCHAR2, x_tgt_site_code OUT VARCHAR2)
    IS
    BEGIN
        x_target_ar_org_name   :=
            get_org_name (xxdoap_commissions_pkg.g_target_ar_org_id);
        x_target_ap_org_name   :=
            get_org_name (xxdoap_commissions_pkg.g_target_ap_org_id);
        x_tgt_vendor_name   :=
            get_vendor_name (xxdoap_commissions_pkg.g_target_vendor_id);
        x_tgt_site_code   :=
            get_site_code (xxdoap_commissions_pkg.g_target_vendor_site_id);
        get_customer_det (
            p_customer_id     => xxdoap_commissions_pkg.g_target_customer_id,
            x_customer_num    => x_customer_number,
            x_customer_name   => x_customer_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Error in get_target_details:' || SQLERRM);
            NULL;
    END get_target_details;

    FUNCTION get_po_line_creation_dt (p_invoice_id IN NUMBER)
        RETURN DATE
    IS
        l_date   DATE;
    BEGIN
        SELECT MIN (pol.creation_date)
          INTO l_date
          FROM ap_invoice_lines_all l, po_lines_all pol
         WHERE l.po_line_id = pol.po_line_id AND l.invoice_id = p_invoice_id;

        RETURN l_date;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN SYSDATE;
        WHEN OTHERS
        THEN
            print_line ('L', 'Error in get_po_line_creation_dt:' || SQLERRM);
            RETURN NULL;
    END get_po_line_creation_dt;

    FUNCTION get_invoice_id (p_invoice_num IN VARCHAR2)
        RETURN NUMBER
    IS
        l_inv_id   NUMBER;
    BEGIN
        SELECT invoice_id
          INTO l_inv_id
          FROM ap_invoices_all
         WHERE     invoice_num = p_invoice_num
               AND org_id = xxdoap_commissions_pkg.g_target_ap_org_id;

        RETURN l_inv_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_invoice_id;

    FUNCTION is_invoice_validated (p_invoice_id IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_valid   VARCHAR2 (30);
    BEGIN
        SELECT DISTINCT match_status_flag
          INTO l_valid
          FROM ap_invoice_distributions_all
         WHERE invoice_id = p_invoice_id;

        RETURN l_valid;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END is_invoice_validated;

    PROCEDURE create_ar_invoices (x_ret_code   OUT VARCHAR2,
                                  x_ret_msg    OUT VARCHAR2)
    IS
        l_msg_count              NUMBER;
        l_msg_data               VARCHAR2 (2000);
        l_append_msg_data        VARCHAR2 (2000);
        l_trx_header_tbl         ar_invoice_api_pub.trx_header_tbl_type;
        l_trx_lines_tbl          ar_invoice_api_pub.trx_line_tbl_type;
        l_trx_dist_tbl           ar_invoice_api_pub.trx_dist_tbl_type;
        l_trx_salescredits_tbl   ar_invoice_api_pub.trx_salescredits_tbl_type;
        l_batch_source_rec       ar_invoice_api_pub.batch_source_rec_type;
        l_cnt                    NUMBER := 0;
        l_customer_trx_id        NUMBER;
        l_return_status          VARCHAR2 (80);
        l_org_id                 NUMBER;
        l_line_count             NUMBER;
        l_inv_type_id            NUMBER;
        l_trx_id                 NUMBER;
        l_trx_line_id            NUMBER;
        l_brand                  VARCHAR2 (30);
        l_hdr_id                 NUMBER;
        l_line_id                NUMBER;
        l_dist_id                NUMBER;
        ex_invalid_source        EXCEPTION;
        ex_invalid_trx_type      EXCEPTION;
        l_debug                  VARCHAR2 (10);
        l_out_msg_index          NUMBER;
        l_header_context         VARCHAR2 (20);
        l_line_context           VARCHAR2 (20);

        CURSOR c_valid_stg IS
            SELECT *
              FROM xxdo.xxdoap_commissions_stg
             WHERE     1 = 1
                   AND process_flag = 'V'
                   AND request_id = xxdoap_commissions_pkg.g_conc_request_id
                   AND current_status_flag = 'V'             -- Added for v1.3
                                                ;

        CURSOR c_errors (p_trx_id NUMBER)
        IS
            SELECT *
              FROM ar_trx_errors_gt
             WHERE trx_header_id = p_trx_id;
    BEGIN
        l_debug                                            := '1';
        --fnd_file.put_line (fnd_file.LOG, '*******START******');
        mo_global.set_policy_context (
            'S',
            xxdoap_commissions_pkg.g_target_ar_org_id);

        -- The following is required when running from the command line
        -- Remember to comment it out when you are creating the script to run
        -- from a Concurrent program

        --MO_GLOBAL.INIT('AR');
        SELECT mo_global.get_current_org_id () INTO l_org_id FROM DUAL;

        fnd_file.put_line (fnd_file.LOG, 'Current MO Org_id=' || l_org_id);
        l_inv_type_id                                      := get_trx_type ('INV');
        l_debug                                            := '2';

        IF l_inv_type_id IS NULL
        THEN
            RAISE ex_invalid_trx_type;
        END IF;

        l_trx_id                                           := xxdoap_commissions_pkg.g_conc_request_id;
        l_debug                                            := '3';

        BEGIN
              SELECT brand
                INTO l_brand
                FROM xxdo.xxdoap_commissions_stg
               WHERE     request_id = xxdoap_commissions_pkg.g_conc_request_id
                     AND process_flag = 'V'
                     AND current_status_flag = 'V'           -- Added for v1.3
            GROUP BY brand;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_brand   := 'UGG';
        END;

        l_debug                                            := '4';

        SELECT ra_customer_trx_s.NEXTVAL INTO l_hdr_id FROM DUAL;

        IF get_batch_source IS NULL
        THEN
            RAISE ex_invalid_source;
        END IF;

        l_debug                                            := '5';
        -- this is the header
        l_batch_source_rec.batch_source_id                 := get_batch_source;
        l_trx_header_tbl (1).trx_header_id                 := l_hdr_id;
        l_trx_header_tbl (1).cust_trx_type_id              := l_inv_type_id;
        l_trx_header_tbl (1).bill_to_site_use_id           :=
            xxdoap_commissions_pkg.g_target_cust_site_use_id;
        l_trx_header_tbl (1).trx_date                      :=
            xxdoap_commissions_pkg.g_target_date;
        l_trx_header_tbl (1).bill_to_customer_id           :=
            xxdoap_commissions_pkg.g_target_customer_id;
        l_trx_header_tbl (1).term_id                       :=
            xxdoap_commissions_pkg.g_target_ar_terms_id;
        --1037;--NULL;
        l_trx_header_tbl (1).attribute5                    := l_brand;
        l_trx_header_tbl (1).attribute11                   := 'N';

        IF xxdoap_commissions_pkg.g_ar_base_currency != get_currency_code
        THEN
            l_trx_header_tbl (1).exchange_rate_type   :=
                xxdoap_commissions_pkg.g_target_exc_rate_type;
            --'User';
            l_trx_header_tbl (1).exchange_rate   :=
                xxdoap_commissions_pkg.g_target_exc_rate;
            -- 1;
            l_trx_header_tbl (1).trx_currency   := get_currency_code;
        END IF;

        BEGIN
            SELECT descriptive_flex_context_code
              INTO l_header_context
              FROM fnd_descriptive_flexs_tl fdft, fnd_descr_flex_contexts fdfc
             WHERE     fdfc.descriptive_flexfield_name =
                       fdft.descriptive_flexfield_name
                   AND fdft.title = 'Invoice Transaction Flexfield'
                   AND UPPER (descriptive_flex_context_code) = 'COMMISSIONS'
                   AND fdft.application_id =
                       (SELECT application_id
                          FROM fnd_application_tl a
                         WHERE     application_name = 'Receivables'
                               AND LANGUAGE = 'US');
        EXCEPTION
            WHEN OTHERS
            THEN
                l_header_context   := 'COMMISSIONS';
        END;

        l_trx_header_tbl (1).interface_header_context      := l_header_context;
        l_trx_header_tbl (1).interface_header_attribute1   :=
            'INV' || TO_CHAR (l_trx_id);
        fnd_file.put_line (fnd_file.LOG, 'l_trx_id:' || l_trx_id);
        l_trx_header_tbl (1).interface_header_attribute2   := '1';
        l_debug                                            := '6';
        l_line_count                                       := 0;

        FOR r_trx IN c_valid_stg
        LOOP
            SELECT ra_customer_trx_lines_s.NEXTVAL INTO l_line_id FROM DUAL;

            SELECT ra_cust_trx_line_gl_dist_s.NEXTVAL
              INTO l_dist_id
              FROM DUAL;

            l_line_count                                               := l_line_count + 1;
            l_debug                                                    := '7-' || l_line_count;
            l_trx_lines_tbl (l_line_count).trx_header_id               := l_hdr_id;
            l_trx_lines_tbl (l_line_count).trx_line_id                 := l_line_id;
            l_trx_lines_tbl (l_line_count).line_number                 := l_line_count;
            l_trx_lines_tbl (l_line_count).description                 :=
                SUBSTR (
                       r_trx.source_trx_org_name
                    || '-'
                    || r_trx.source_supplier_name
                    || '-'
                    || r_trx.source_trx_number
                    || '-'
                    || r_trx.commission_percentage,
                    1,
                    240);
            --l_trx_lines_tbl (l_line_count).uom_code := 'Ea';
            l_trx_lines_tbl (l_line_count).quantity_invoiced           := 1;
            l_trx_lines_tbl (l_line_count).unit_selling_price          :=
                ROUND (
                      NVL (r_trx.commission_percentage, 0)
                    * NVL (r_trx.source_trx_amount, 0)
                    / 100,
                    2);
            l_trx_lines_tbl (l_line_count).line_type                   := 'LINE';
            l_trx_lines_tbl (l_line_count).attribute13                 :=
                TO_CHAR (r_trx.source_trx_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Source trx id:' || r_trx.source_trx_id);

            BEGIN
                SELECT descriptive_flex_context_code
                  INTO l_line_context
                  FROM fnd_descriptive_flexs_tl fdft, fnd_descr_flex_contexts fdfc
                 WHERE     fdfc.descriptive_flexfield_name =
                           fdft.descriptive_flexfield_name
                       AND fdft.title = 'Line Transaction Flexfield'
                       AND UPPER (descriptive_flex_context_code) =
                           'COMMISSIONS'
                       AND fdft.application_id =
                           (SELECT application_id
                              FROM fnd_application_tl a
                             WHERE     application_name = 'Receivables'
                                   AND LANGUAGE = 'US');
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_header_context   := 'Commissions';
            END;

            l_trx_lines_tbl (l_line_count).interface_line_context      :=
                l_line_context;
            --'Commissions';
            l_trx_lines_tbl (l_line_count).interface_line_attribute1   :=
                'INV' || TO_CHAR (l_trx_id);
            fnd_file.put_line (fnd_file.LOG, 'l_trx_id:' || l_trx_id);
            l_trx_lines_tbl (l_line_count).interface_line_attribute2   :=
                r_trx.source_trx_number;
            fnd_file.put_line (
                fnd_file.LOG,
                'Sourcs Trx Number:' || r_trx.source_trx_number);
            -- Start changes by Deckers IT Team on 27 Apr 2017 to Include Source trx ID in the AR Invoice Side
            l_trx_lines_tbl (l_line_count).interface_line_attribute3   :=
                r_trx.source_trx_id;
            fnd_file.put_line (fnd_file.LOG,
                               'Sourcs Trx ID:' || r_trx.source_trx_id);
            -- End changes by Deckers IT Team on 27 Apr 2017 to Include Source trx ID in the AR Invoice Side
            --l_line_count;
            l_trx_lines_tbl (l_line_count).taxable_flag                := 'N';
            l_trx_lines_tbl (l_line_count).amount_includes_tax_flag    := 'N';
            l_trx_dist_tbl (l_line_count).trx_dist_id                  :=
                l_dist_id;
            l_trx_dist_tbl (l_line_count).trx_line_id                  :=
                l_line_id;
            l_trx_dist_tbl (l_line_count).account_class                :=
                'REV';
            l_trx_dist_tbl (l_line_count).PERCENT                      := 100;
            l_trx_dist_tbl (l_line_count).code_combination_id          :=
                xxdoap_commissions_pkg.g_target_ar_rev_acc_id;
        --l_trx_dist_tbl (1).gl_date := xxdoap_commissions_pkg.G_TARGET_DATE;
        END LOOP;

        l_debug                                            := '8';

        IF l_line_count > 0
        THEN
            BEGIN
                l_debug   := '9';
                ar_invoice_api_pub.create_single_invoice (
                    p_api_version            => 1.0,
                    x_return_status          => l_return_status,
                    x_msg_count              => l_msg_count,
                    x_msg_data               => l_msg_data,
                    x_customer_trx_id        => l_customer_trx_id,
                    p_batch_source_rec       => l_batch_source_rec,
                    p_trx_header_tbl         => l_trx_header_tbl,
                    p_trx_lines_tbl          => l_trx_lines_tbl,
                    p_trx_dist_tbl           => l_trx_dist_tbl,
                    p_trx_salescredits_tbl   => l_trx_salescredits_tbl);
                print_line ('L', 'Msg ' || SUBSTR (l_msg_data, 1, 225));
                print_line ('L', 'Status ' || l_return_status);
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_code   := '2';
                    x_ret_msg    :=
                           'Error in create_ar_invoices:'
                        || l_debug
                        || ':'
                        || SQLERRM;
                    print_line (
                        'L',
                           'Error in create_ar_invoices:'
                        || l_debug
                        || ':'
                        || SQLERRM);
                    print_line (
                        'O',
                           'Failed to create_ar_invoices for target_ar_trx_num and batch_source_id:'
                        || xxdoap_commissions_pkg.g_target_ar_trx_num
                        || '-'
                        || l_batch_source_rec.batch_source_id);
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message: ' || l_msg_data);
            END;

            IF NVL (l_return_status, 'X') <> fnd_api.g_ret_sts_success
            THEN
                IF l_msg_count > 0
                THEN
                    FOR i IN 1 .. l_msg_count
                    LOOP
                        l_append_msg_data   := NULL;
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_append_msg_data
                                        , p_msg_index_out => l_out_msg_index);
                        l_msg_data          :=
                            l_msg_data || CHR (10) || l_append_msg_data;
                    END LOOP;
                END IF;
            END IF;

            fnd_file.put_line (fnd_file.LOG, 'Error Message: ' || l_msg_data);

            IF    l_return_status = fnd_api.g_ret_sts_error
               OR l_return_status = fnd_api.g_ret_sts_unexp_error
            THEN
                l_debug      := '10';
                print_line ('L', 'unexpected errors found!');
                x_ret_code   := '2';
                x_ret_msg    :=
                    'Unexpected Errors:' || SUBSTR (l_msg_data, 1, 225);

                /* start changes for v1.3*/
                UPDATE xxdo.xxdoap_commissions_stg
                   SET current_status_flag = 'X'             -- Added for v1.3
                                                , current_status_msg = 'Unexpected Error while creating ar invoice' -- Added for v1.3
                 WHERE     1 = 1
                       AND process_flag = 'V'
                       AND current_status_flag = 'V'
                       AND request_id =
                           xxdoap_commissions_pkg.g_conc_request_id;

                COMMIT;
            /* End changes for v1.3 */
            ELSE
                SELECT COUNT (*) INTO l_cnt FROM ar_trx_errors_gt;

                l_debug   := '11';

                IF l_cnt = 0
                THEN
                    l_debug   := '12';

                    IF l_customer_trx_id IS NOT NULL
                    THEN
                        get_ar_trx_num (l_customer_trx_id);
                        print_line ('L',
                                    'Customer Trx id ' || l_customer_trx_id);

                        UPDATE xxdo.xxdoap_commissions_stg
                           SET target_ar_trx_id = l_customer_trx_id, target_ar_trx_number = xxdoap_commissions_pkg.g_target_ar_trx_num, current_status_flag = 'R' -- Added for v1.3
                                                                                                                                                                 ,
                               current_status_msg = 'Updating target_ar_trx_details' -- Added for v1.3
                         WHERE     1 = 1
                               AND process_flag = 'V'
                               AND current_status_flag = 'V' -- Added for v1.3
                               AND request_id =
                                   xxdoap_commissions_pkg.g_conc_request_id;

                        l_debug      := '13';
                        COMMIT;
                        x_ret_code   := '0';
                        x_ret_msg    :=
                               'Transaction Created. Trx Num:'
                            || xxdoap_commissions_pkg.g_target_ar_trx_num;
                    ELSE
                        x_ret_code   := '2';
                        x_ret_msg    := 'Transaction Not Created.';
                        l_debug      := '14';

                        FOR r_err IN c_errors (l_trx_id)
                        LOOP
                            print_line (
                                'L',
                                   'Transaction Creation Error. Invalid value:'
                                || r_err.invalid_value
                                || ' Error :'
                                || r_err.error_message);
                            print_line (
                                'O',
                                   'Transaction Creation Error for l_trx_id:'
                                || l_trx_id);                -- Added for v1.3
                        END LOOP;
                    END IF;
                ELSE
                    print_line ('L', 'Transaction not Created');
                    x_ret_code   := '2';
                    x_ret_msg    :=
                        'Transaction Not Created. Please check the log.';
                    l_debug      := '15';

                    FOR r_err IN c_errors (l_hdr_id)
                    LOOP
                        l_debug   := '16';
                        print_line (
                            'L',
                               'Transaction Creation Error. Invalid value:'
                            || r_err.invalid_value
                            || ' Error :'
                            || r_err.error_message);
                        print_line (
                            'O',
                               'Transaction Creation Error for l_hdr_id:'
                            || l_hdr_id);                    -- Added for v1.3
                    END LOOP;
                END IF;
            END IF;
        ELSE
            print_line (
                'L',
                'No valid source transactions found for creation AR commission Invoice.');
            l_debug   := '17';
        END IF;

        l_debug                                            := '18';
    EXCEPTION
        WHEN ex_invalid_source
        THEN
            x_ret_code   := '2';
            x_ret_msg    := ' Invalid Batch Source Setup.';
            /* Start changes for v1.3 */
            fnd_file.put_line (
                fnd_file.LOG,
                x_ret_msg || 'for' || xxdoap_commissions_pkg.g_target_ar_trx_num);
        /*End changes for v1.3*/
        WHEN ex_invalid_trx_type
        THEN
            x_ret_code   := '2';
            x_ret_msg    := ' Invalid Transaction Type Setup.';
            /* Start changes for v1.3 */
            fnd_file.put_line (
                fnd_file.LOG,
                x_ret_msg || 'for' || xxdoap_commissions_pkg.g_target_ar_trx_num);
        /*End changes for v1.3*/
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_msg    :=
                'Error in create_ar_invoices:' || l_debug || ':' || SQLERRM;
            /* Start changes for v1.3 */
            fnd_file.put_line (
                fnd_file.LOG,
                'Error in create_ar_invoices for' || xxdoap_commissions_pkg.g_target_ar_trx_num);
            /*End changes for v1.3*/
            print_line (
                'L',
                'Error in create_ar_invoices:' || l_debug || ':' || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Error Message: ' || l_msg_data);
    END create_ar_invoices;

    --=======================================================
    PROCEDURE validate_ap_invoice (x_ret_code OUT VARCHAR2, x_ret_message OUT VARCHAR2, p_invoice_id IN NUMBER)
    IS
        l_request_id       NUMBER := 0;
        l_user_id          NUMBER := 0;
        l_login_id         NUMBER := 0;
        l_org_id           NUMBER := 0;
        l_req_boolean      BOOLEAN;
        l_req_phase        VARCHAR2 (30);
        l_req_status       VARCHAR2 (30);
        l_req_dev_phase    VARCHAR2 (30);
        l_req_dev_status   VARCHAR2 (30);
        l_req_message      VARCHAR2 (4000);
        l_invoice_status   VARCHAR2 (1);
    BEGIN
        /*FND_GLOBAL.APPS_INITIALIZE(57550--1037--Batch--p_user_id
        , 52026--20639--Payables Manager--p_resp_id
        , 200--SQLAP--p_resp_appl_id
        );*/
        mo_global.set_policy_context (
            'S',
            xxdoap_commissions_pkg.g_target_ap_org_id);
        mo_global.init ('SQLAP');
        --FND_REQUEST.SUBMIT_REQUEST(OPEN INVOICES INTERFACE);
        l_request_id   :=
            fnd_request.submit_request (
                application   => 'SQLAP',
                program       => 'APPRVL',
                description   => ''         --'Payables Open Interface Import'
                                   ,
                start_time    => SYSDATE                              --,NULL,
                                        ,
                sub_request   => FALSE,
                argument1     => xxdoap_commissions_pkg.g_target_ap_org_id --2 org_id
                                                                          ,
                argument2     => 'All'                                --Option
                                      ,
                argument3     => ''                         --invoice batch id
                                   ,
                argument4     => ''                       --Start invoice date
                                   ,
                argument5     => ''                         --End Invoice date
                                   ,
                argument6     => xxdoap_commissions_pkg.g_target_vendor_id --Vendor ID
                                                                          ,
                argument7     => ''                                --Pay Group
                                   ,
                argument8     => p_invoice_id                     --Invoice id
                                             ,
                argument9     => '', --Entered by userid                              ,
                -- argument10    => xxdoap_commissions_pkg.g_target_ap_sob_id, --SOB ID  -- 'N'  --Commented for CCR0009213
                --Start Added for CCR0009213
                argument10    => 'N',                          -- Trace Option
                argument11    => 1000,                          -- Commit Size
                argument12    => 1000,                           -- Num of trx
                argument13    => 'N'                           -- Debug Switch
                                    --End Added for CCR0009213
                                    );

        IF l_request_id <> 0
        THEN
            COMMIT;
            print_line ('L', 'Validation Request ID= ' || l_request_id);
        ELSIF l_request_id = 0
        THEN
            print_line (
                'L',
                'Request Not Submitted due to "' || fnd_message.get || '".');
        END IF;

        --===FND_REQUEST.WAIT_FOR_REQUEST;
        --===IF successful RETURN ar customer trx id as OUT parameter;
        IF l_request_id > 0
        THEN
            LOOP
                l_req_boolean   :=
                    fnd_concurrent.wait_for_request (l_request_id,
                                                     10,
                                                     0,
                                                     l_req_phase,
                                                     l_req_status,
                                                     l_req_dev_phase,
                                                     l_req_dev_status,
                                                     l_req_message);
                EXIT WHEN    UPPER (l_req_phase) = 'COMPLETED'
                          OR UPPER (l_req_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;

            IF     UPPER (l_req_phase) = 'COMPLETED'
               --            AND UPPER (l_req_status) = 'ERROR' -- Commented for v1.3
               AND UPPER (l_req_status) IN ('CANCELLED', 'ERROR', 'TERMINATED',
                                            'WARNING')       -- Added for v1.3
            THEN
                print_line (
                    'L',
                       'Validation completed in error. See log for request id'
                    || l_request_id);
                print_line ('L', SQLERRM);
                x_ret_code   := '2';
                x_ret_message   :=
                       'Validation failed.Review log for Oracle request id '
                    || l_request_id;

                UPDATE xxdo.xxdoap_commissions_stg
                   SET current_status_flag = 'F'             -- Added for v1.3
                                                , current_status_msg = 'Validation completed in error' -- Added for v1.3
                 WHERE     request_id =
                           xxdoap_commissions_pkg.g_conc_request_id
                       AND target_ar_trx_number =
                           xxdoap_commissions_pkg.g_target_ar_trx_num -- Added for v1.3
                                                                     ;

                COMMIT;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Validation completed in error:'
                    || xxdoap_commissions_pkg.g_target_ar_trx_num);
            ELSIF     UPPER (l_req_phase) = 'COMPLETED'
                  AND UPPER (l_req_status) = 'NORMAL'
            THEN
                l_invoice_status   := is_invoice_validated (p_invoice_id);

                IF NVL (l_invoice_status, 'X') != 'A'
                THEN
                    x_ret_code   := '1';
                    x_ret_message   :=
                           'Validation failed. Review output for Oracle request id '
                        || l_request_id;
                    print_line (
                        'L',
                           'Validation request failed.Review log for Oracle request id '
                        || l_request_id);
                ELSE
                    x_ret_code   := '0';
                    x_ret_message   :=
                           'Invoice Validated. Review output for Oracle request id '
                        || l_request_id;
                    print_line (
                        'L',
                           'Invoice Validated. Review output for Oracle request id '
                        || l_request_id);

                    /* Start changes for v1.3 */
                    UPDATE xxdo.xxdoap_commissions_stg
                       SET current_status_flag = 'P', current_status_msg = 'Invoice validation completed normal'
                     WHERE     request_id =
                               xxdoap_commissions_pkg.g_conc_request_id
                           AND target_ar_trx_number =
                               xxdoap_commissions_pkg.g_target_ar_trx_num
                           AND current_status_flag = 'C';

                    COMMIT;
                /* End changes for v1.3 */
                END IF;
            ELSE
                print_line (
                    'L',
                       'Validation request failed.Review log for Oracle request id '
                    || l_request_id);
                print_line ('L', SQLERRM);
                x_ret_code   := '2';
                x_ret_message   :=
                       'Validation request failed. Review log for Oracle request id '
                    || l_request_id;

                /* Start changes for v1.3 */
                UPDATE xxdo.xxdoap_commissions_stg
                   SET current_status_flag = 'F', current_status_msg = 'Invoice validation Failed'
                 WHERE     request_id =
                           xxdoap_commissions_pkg.g_conc_request_id
                       AND target_ar_trx_number =
                           xxdoap_commissions_pkg.g_target_ar_trx_num
                       AND current_status_flag = 'C';

                COMMIT;
            /* End changes for v1.3 */
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Error in validate_ap_invoice:' || SQLERRM);
            x_ret_code   := '2';
            x_ret_message   :=
                   'Validation Failed. Review output for Oracle request id '
                || l_request_id;
    END validate_ap_invoice;

    PROCEDURE create_ap_invoices (x_ret_code      OUT VARCHAR2,
                                  x_ret_message   OUT VARCHAR2)
    IS
        l_request_id       NUMBER := 0;
        l_user_id          NUMBER := 0;
        l_login_id         NUMBER := 0;
        l_org_id           NUMBER := 0;
        l_req_boolean      BOOLEAN;
        l_req_phase        VARCHAR2 (30);
        l_req_status       VARCHAR2 (30);
        l_req_dev_phase    VARCHAR2 (30);
        l_req_dev_status   VARCHAR2 (30);
        l_req_message      VARCHAR2 (4000);
        l_invoice_id       NUMBER := 0;
        l_cm_id            NUMBER := 0;
        l_cm_ret_code      VARCHAR2 (30);
        l_cm_ret_msg       VARCHAR2 (2000);
        l_inv_ret_code     VARCHAR2 (30);
        l_inv_ret_msg      VARCHAR2 (2000);
    BEGIN
        /*FND_GLOBAL.APPS_INITIALIZE(57550--1037--Batch--p_user_id
        , 52026--20639--Payables Manager--p_resp_id
        , 200--SQLAP--p_resp_appl_id
        );*/
        mo_global.set_policy_context (
            'S',
            xxdoap_commissions_pkg.g_target_ap_org_id);
        mo_global.init ('SQLAP');
        --FND_REQUEST.SUBMIT_REQUEST(OPEN INVOICES INTERFACE);
        l_request_id   :=
            fnd_request.submit_request (application => 'SQLAP', program => 'APXIIMPT', description => '' --'Payables Open Interface Import'
                                                                                                        , start_time => SYSDATE --,NULL,
                                                                                                                               , sub_request => FALSE, argument1 => xxdoap_commissions_pkg.g_target_ap_org_id --2 org_id
                                                                                                                                                                                                             , argument2 => 'COMMISSIONS' --p_source --'MANUAL INVOICE ENTRY', -- source
                                                                                                                                                                                                                                         , argument3 => '', argument4 => 'N/A', argument5 => '', argument6 => '', argument7 => TO_CHAR (xxdoap_commissions_pkg.g_target_date, 'YYYY/MM/DD HH24:MI:SS'), argument8 => 'N' --'N', -- purge
                                                                                                                                                                                                                                                                                                                                                                                                                        , argument9 => 'N' --'N', -- trace_switch
                                                                                                                                                                                                                                                                                                                                                                                                                                          , argument10 => 'N' --'N', -- debug_switch
                                                                                                                                                                                                                                                                                                                                                                                                                                                             , argument11 => 'N' --'N', -- summarize report
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                , argument12 => 1000 --1000, -- commit_batch_size
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , argument13 => fnd_global.user_id --'1037',
                                        , argument14 => fnd_global.login_id --'1347386776'
                                                                           );

        IF l_request_id <> 0
        THEN
            COMMIT;
            print_line ('L', 'AP Request ID= ' || l_request_id);
        ELSIF l_request_id = 0
        THEN
            print_line (
                'L',
                'Request Not Submitted due to "' || fnd_message.get || '".');
        END IF;

        --===FND_REQUEST.WAIT_FOR_REQUEST;
        --===IF successful RETURN ar customer trx id as OUT parameter;
        IF l_request_id > 0
        THEN
            LOOP
                l_req_boolean   :=
                    fnd_concurrent.wait_for_request (l_request_id,
                                                     15,
                                                     0,
                                                     l_req_phase,
                                                     l_req_status,
                                                     l_req_dev_phase,
                                                     l_req_dev_status,
                                                     l_req_message);
                EXIT WHEN    UPPER (l_req_phase) = 'COMPLETED'
                          OR UPPER (l_req_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;

            IF     UPPER (l_req_phase) = 'COMPLETED'
               AND UPPER (l_req_status) = 'ERROR'
            THEN
                print_line (
                    'L',
                       'The Payables Open Import prog completed in error. See log for request id'
                    || l_request_id);
                print_line ('L', SQLERRM);
                x_ret_code   := '2';
                x_ret_message   :=
                       'The Payables Open Import request failed.Review log for Oracle request id '
                    || l_request_id;

                /* Start changes for v1.3 */
                UPDATE xxdo.xxdoap_commissions_stg
                   SET current_status_flag = 'E', current_status_msg = 'Payables Open Import failed'
                 WHERE     request_id =
                           xxdoap_commissions_pkg.g_conc_request_id
                       AND target_ar_trx_number =
                           xxdoap_commissions_pkg.g_target_ar_trx_num
                       AND current_status_flag = 'R';

                COMMIT;

                UPDATE ap_invoices_all aia
                   SET aia.attribute9   = 'Y'
                 WHERE EXISTS
                           (SELECT 1
                              FROM xxdo.xxdoap_commissions_stg stg
                             WHERE     stg.request_id =
                                       xxdoap_commissions_pkg.g_conc_request_id
                                   AND stg.source_trx_id = aia.invoice_id
                                   AND stg.current_status_flag = 'E');

                COMMIT;
                /* End changes for v1.3 */
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Payables Open Import failed:' || xxdoap_commissions_pkg.g_target_ar_trx_num);
            ELSIF     UPPER (l_req_phase) = 'COMPLETED'
                  AND UPPER (l_req_status) = 'NORMAL'
            THEN
                print_line (
                    'L',
                    'The Payables Open Import request id: ' || l_request_id);

                /* Start changes for v1.3 */
                UPDATE xxdo.xxdoap_commissions_stg
                   SET current_status_flag = 'C', current_status_msg = 'Payables Open Import Completed'
                 WHERE     request_id =
                           xxdoap_commissions_pkg.g_conc_request_id
                       AND target_ar_trx_number =
                           xxdoap_commissions_pkg.g_target_ar_trx_num
                       AND current_status_flag = 'R';

                COMMIT;

                /* End changes for v1.3 */

                --Start Added for CCR0009213
                UPDATE ap_invoices_all aia
                   SET aia.attribute9   = 'Y'
                 WHERE EXISTS
                           (SELECT 1
                              FROM xxdo.xxdoap_commissions_stg stg
                             WHERE     stg.request_id =
                                       xxdoap_commissions_pkg.g_conc_request_id
                                   AND stg.source_trx_id = aia.invoice_id
                                   AND stg.current_status_flag = 'C');

                COMMIT;
                --End Added for CCR0009213

                l_cm_id   :=
                    get_invoice_id (
                        SUBSTR (
                               xxdoap_commissions_pkg.g_target_ar_trx_num
                            || '-'
                            || xxdoap_commissions_pkg.g_target_ar_org_id
                            || '-'
                            || 'CREDIT',
                            1,
                            50));

                IF NVL (l_cm_id, 0) != 0
                THEN
                    validate_ap_invoice (x_ret_code      => l_cm_ret_code,
                                         x_ret_message   => l_cm_ret_msg,
                                         p_invoice_id    => l_cm_id);
                END IF;

                l_invoice_id   :=
                    get_invoice_id (
                        SUBSTR (
                               xxdoap_commissions_pkg.g_target_ar_trx_num
                            || '-'
                            || xxdoap_commissions_pkg.g_target_ar_org_id,
                            1,
                            50));

                IF NVL (l_invoice_id, 0) != 0
                THEN
                    validate_ap_invoice (x_ret_code      => l_inv_ret_code,
                                         x_ret_message   => l_inv_ret_msg,
                                         p_invoice_id    => l_invoice_id);
                END IF;

                IF l_cm_ret_code = '0' AND l_inv_ret_code = '0'
                THEN
                    x_ret_code   := '0';
                    x_ret_message   :=
                        'Payables Import/Validation Successful. ';

                    /* Start changes for v1.3 */
                    UPDATE xxdo.xxdoap_commissions_stg
                       SET current_status_flag = 'S', current_status_msg = 'Payables Validation Success'
                     WHERE     request_id =
                               xxdoap_commissions_pkg.g_conc_request_id
                           AND target_ar_trx_number =
                               xxdoap_commissions_pkg.g_target_ar_trx_num
                           AND current_status_flag = 'C';

                    COMMIT;
                /* End changes for v1.3 */

                ELSIF l_cm_ret_code = '1' OR l_inv_ret_code = '1'
                THEN
                    --Start Changes V2.0 -- Commented -- If there is Invoice Validation Warning, then it should run for other OUs hence returning the ret_code =0
                    --               x_ret_code := '1';
                    x_ret_code   := '0';
                    --End Changes V2.0
                    x_ret_message   :=
                        'Payables Validation Completed with warning. ';

                    /* Start changes for v1.3 */
                    UPDATE xxdo.xxdoap_commissions_stg
                       SET current_status_flag = 'W', current_status_msg = 'Payables Validation Warning'
                     WHERE     request_id =
                               xxdoap_commissions_pkg.g_conc_request_id
                           AND target_ar_trx_number =
                               xxdoap_commissions_pkg.g_target_ar_trx_num
                           AND current_status_flag = 'C';

                    COMMIT;
                    /* End changes for v1.3 */
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Payables Validation Completed with warning:'
                        || xxdoap_commissions_pkg.g_target_ar_trx_num);
                ELSIF l_cm_ret_code = '2' OR l_inv_ret_code = '2'
                THEN
                    --Start Changes V2.0 -- Commented -- If there is Invoice Validation Error, then it should run for other OUs
                    --               x_ret_code := '2';
                    x_ret_code      := '0';
                    --End Changes V2.0
                    x_ret_message   := 'Payables Validation Failed. ';

                    /* Start changes for v1.3 */
                    UPDATE xxdo.xxdoap_commissions_stg
                       SET current_status_flag = 'E', current_status_msg = 'Payables Validation failed'
                     WHERE     request_id =
                               xxdoap_commissions_pkg.g_conc_request_id
                           AND target_ar_trx_number =
                               xxdoap_commissions_pkg.g_target_ar_trx_num
                           AND current_status_flag = 'C';

                    COMMIT;
                    /* End changes for v1.3 */
                    print_line (
                        'O',
                           'Payables Validation failed:'
                        || xxdoap_commissions_pkg.g_target_ar_trx_num);
                END IF;
            ELSE
                print_line (
                    'L',
                       'The Payables Open Import request failed.Review log for Oracle request id '
                    || l_request_id);
                print_line ('L', SQLERRM);
                x_ret_code   := '2';
                x_ret_message   :=
                       'The Payables Open Import request failed.Review log for Oracle request id '
                    || l_request_id;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Error in create_ap_invoices:' || SQLERRM);
            x_ret_code   := '2';
            x_ret_message   :=
                   'The Payables Open Import request failed.Review log for Oracle request id '
                || l_request_id;
            RAISE;
    END create_ap_invoices;

    PROCEDURE create_target_ap_trx (x_ret_code      OUT VARCHAR2,
                                    x_ret_message   OUT VARCHAR2)
    IS
        CURSOR c_valid_staging_inv IS
            SELECT *
              FROM xxdo.xxdoap_commissions_stg
             WHERE     process_flag = 'R'
                   AND request_id = xxdoap_commissions_pkg.g_conc_request_id
                   AND source_trx_type IN ('STANDARD', 'MIXED')
                   AND current_status_flag = 'R'             -- Added for v1.3
                                                ;

        CURSOR c_valid_staging_cm IS
            SELECT *
              FROM xxdo.xxdoap_commissions_stg
             WHERE     process_flag = 'R'
                   AND request_id = xxdoap_commissions_pkg.g_conc_request_id
                   AND source_trx_type = 'CREDIT'
                   AND current_status_flag = 'R'             -- Added for v1.3
                                                ;

        l_invoice_id       ap_invoices.invoice_id%TYPE;
        l_line_num         ap_invoice_lines.line_number%TYPE;
        l_invoice_amt      ap_invoices.invoice_amount%TYPE;
        l_cm_amt           ap_invoices.invoice_amount%TYPE;
        l_ret_code         VARCHAR2 (30);
        l_ret_msg          VARCHAR2 (360);
        l_cm_line_count    NUMBER;
        l_inv_line_count   NUMBER;
        l_inv_cnt          NUMBER;
        l_cm_cnt           NUMBER;
        l_curr_code        VARCHAR2 (30);
        l_conc_segments    VARCHAR2 (50);
        l_debug            VARCHAR2 (10);
        l_inv_sum          NUMBER := 0;
        l_rounding_diff    NUMBER := 0;
        l_credit_inv_id    NUMBER;
        l_std_inv_id       NUMBER;
        l_hold             VARCHAR2 (30);
    -- Target AP transactions
    BEGIN
        l_cm_line_count    := 0;
        l_inv_line_count   := 0;
        --Start changes by Deckers IT Team on 03 MAy 2017
        l_cm_amt           := 0;
        l_invoice_amt      := 0;
        --End  changes by Deckers IT Team on 03 MAy 2017
        l_debug            := '1';

        BEGIN
            UPDATE ap_invoices_all aia
               -- SET aia.attribute9 = 'PROCESSING'    --Commented for CCR0009213
               SET aia.attribute9   = 'N'               --Added for CCR0009213
             WHERE     aia.invoice_id =
                       (SELECT source_trx_id
                          FROM xxdo.xxdoap_commissions_stg xcs
                         WHERE     1 = 1
                               AND aia.invoice_id = xcs.source_trx_id
                               AND NVL (current_status_flag, 'E') = 'R'
                               AND request_id =
                                   xxdoap_commissions_pkg.g_conc_request_id)
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxdoap_commissions_stg xcs
                             WHERE     1 = 1
                                   AND aia.invoice_id = xcs.source_trx_id
                                   AND NVL (current_status_flag, 'E') = 'R'
                                   AND request_id =
                                       xxdoap_commissions_pkg.g_conc_request_id);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                print_line (
                    'L',
                       'Error while updating the attribute9 to PROCESSING'
                    || SQLERRM);
        END;

        BEGIN
            --Start changes by Deckers IT Team on 03 MAy 2017 Added NVL
            --         SELECT SUM (
            --                   ROUND (
            --                      (  NVL (stg.source_trx_amount, 0)
            --                       * NVL (stg.commission_percentage, 0)
            --                       / 100),
            --                      2))
            --           INTO l_cm_amt                              -- COMMISSION_PERCENTAGE
            --           FROM xxdo.xxdoap_commissions_stg stg
            --          WHERE     process_flag = 'R'
            --                AND request_id = xxdoap_commissions_pkg.g_conc_request_id
            --                AND source_trx_type = 'CREDIT'
            --                AND current_status_flag = 'R'                -- Added for v1.3
            --                                             ;
            SELECT NVL (SUM (ROUND ((NVL (stg.source_trx_amount, 0) * NVL (stg.commission_percentage, 0) / 100), 2)), 0)
              INTO l_cm_amt                           -- COMMISSION_PERCENTAGE
              FROM xxdo.xxdoap_commissions_stg stg
             WHERE     process_flag = 'R'
                   AND request_id = xxdoap_commissions_pkg.g_conc_request_id
                   AND source_trx_type = 'CREDIT'
                   AND current_status_flag = 'R'             -- Added for v1.3
                                                ;
        --End changes by Deckers IT Team on 03 MAy 2017
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
                print_line (
                    'O',
                       'Failed to calculate COMMISSION_PERCENTAGE:'
                    || xxdoap_commissions_pkg.g_target_ar_trx_num);
        END;

        l_debug            := '2';
        l_cm_line_count    := 0;

        SELECT ap_invoices_interface_s.NEXTVAL INTO l_invoice_id FROM DUAL;

        l_debug            := '3';

        IF l_cm_amt <> 0
        THEN
            l_curr_code   := get_currency_code;

            --l_conc_segments := get_concatenated_code;

            --print_line('L','l_conc_segments:'||l_conc_segments);
            INSERT INTO ap_invoices_interface (invoice_id,
                                               invoice_num,
                                               vendor_id,
                                               vendor_site_id,
                                               invoice_amount,
                                               SOURCE,
                                               org_id,
                                               payment_method_code,
                                               terms_id,
                                               invoice_type_lookup_code,
                                               gl_date,
                                               invoice_date,
                                               invoice_currency_code,
                                               exchange_date)
                 VALUES (l_invoice_id, SUBSTR (xxdoap_commissions_pkg.g_target_ar_trx_num || '-' || xxdoap_commissions_pkg.g_target_ar_org_id --G_TARGET_AR_ORG_NAME-- --'TEST07' --INVOICE_NUM,
                                                                                                                                              || '-' || 'CREDIT', 1, 50), xxdoap_commissions_pkg.g_target_vendor_id, xxdoap_commissions_pkg.g_target_vendor_site_id, l_cm_amt, 'COMMISSIONS', xxdoap_commissions_pkg.g_target_ap_org_id, xxdoap_commissions_pkg.g_target_ap_pay_method, xxdoap_commissions_pkg.g_target_ap_terms_id, 'CREDIT', xxdoap_commissions_pkg.g_target_date, xxdoap_commissions_pkg.g_target_date
                         , l_curr_code, xxdoap_commissions_pkg.g_target_date);

            l_line_num    := 0;
            l_debug       := '4';

            FOR r_valid_staging IN c_valid_staging_cm
            LOOP
                l_line_num        := l_line_num + 1;
                l_cm_line_count   := l_cm_line_count + 1;
                l_debug           := '5-' || TO_CHAR (l_cm_line_count);

                -- Insert invoice line --
                INSERT INTO ap_invoice_lines_interface (invoice_id, invoice_line_id, line_number, line_type_lookup_code, amount, accounting_date, --dist_code_concatenated,
                                                                                                                                                  --default_dist_ccid,
                                                                                                                                                  distribution_set_id, ship_to_location_id, attribute3
                                                        , description)
                         VALUES (
                                    l_invoice_id                  --invoice_id
                                                ,
                                    ap_invoice_lines_interface_s.NEXTVAL --invoice line id
                                                                        ,
                                    l_line_num                   --line number
                                              ,
                                    'ITEM'             --line type lookup code
                                          ,
                                    ROUND (
                                          NVL (
                                              r_valid_staging.source_trx_amount,
                                              0)
                                        * NVL (
                                              r_valid_staging.commission_percentage,
                                              0)
                                        / 100,
                                        2),
                                    xxdoap_commissions_pkg.g_target_date --,l_conc_segments
                                                                        --,1109
                                                                        ,
                                    xxdoap_commissions_pkg.g_target_ap_dist_set_id --2172783 10004
                                                                                  ,
                                    xxdoap_commissions_pkg.g_target_ap_ship_loc_id,
                                    r_valid_staging.source_trx_id,
                                    SUBSTR (
                                           r_valid_staging.source_trx_org_name
                                        || '-'
                                        || r_valid_staging.source_supplier_name
                                        || '-'
                                        || r_valid_staging.source_trx_number,
                                        1,
                                        240));
            END LOOP;

            l_debug       := '6';
        END IF;

        l_debug            := '7';

        COMMIT;

        BEGIN
            --Start changes by Deckers IT Team on 03 MAy 2017
            --         SELECT SUM (
            --                   ROUND (
            --                      (  NVL (stg.source_trx_amount, 0)
            --                       * NVL (stg.commission_percentage, 0)
            --                       / 100),
            --                      2))
            --           INTO l_invoice_amt                         -- COMMISSION_PERCENTAGE
            --           FROM xxdo.xxdoap_commissions_stg stg
            --          WHERE     process_flag = 'R'
            --                AND request_id = xxdoap_commissions_pkg.g_conc_request_id
            --                AND source_trx_type IN ('STANDARD', 'MIXED')
            --                AND current_status_flag = 'R'                -- Added for v1.3
            --                                             ;
            SELECT NVL (SUM (ROUND ((NVL (stg.source_trx_amount, 0) * NVL (stg.commission_percentage, 0) / 100), 2)), 0)
              INTO l_invoice_amt                      -- COMMISSION_PERCENTAGE
              FROM xxdo.xxdoap_commissions_stg stg
             WHERE     process_flag = 'R'
                   AND request_id = xxdoap_commissions_pkg.g_conc_request_id
                   AND source_trx_type IN ('STANDARD', 'MIXED')
                   AND current_status_flag = 'R'             -- Added for v1.3
                                                ;
        --End changes by Deckers IT Team on 03 MAy 2017
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
                print_line (
                    'O',
                       'Failed to calculate COMMISSION_PERCENTAGE:'
                    || xxdoap_commissions_pkg.g_target_ar_trx_num);
        END;

        l_debug            := '8';
        l_inv_line_count   := 0;

        /* Start changes for v1.3 */
        IF l_invoice_amt = 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Calculated COMMISSION_PERCENTAGE is 0');
        ELSE
            -- IF l_invoice_amt <> 0
            --THEN
            /* End changes for v1.3 */
            SELECT ap_invoices_interface_s.NEXTVAL
              INTO l_invoice_id
              FROM DUAL;

            /*print_line('L','Invoice#'||SUBSTR(xxdoap_commissions_pkg.G_TARGET_AR_TRX_NUM||'-'
            ||xxdoap_commissions_pkg.G_TARGET_AR_ORG_NAME-- --'TEST07' --INVOICE_NUM,
            ,1,50));*/
            --print_line('L','l_conc_segments:'||l_conc_segments);
            l_debug       := '9';
            l_curr_code   := get_currency_code;
            print_line (
                'L',
                   'Invoice Num#'
                || SUBSTR (
                          xxdoap_commissions_pkg.g_target_ar_trx_num
                       || '-'
                       || xxdoap_commissions_pkg.g_target_ar_org_id,
                       1,
                       50));
            print_line (
                'L',
                'Pay Method#' || xxdoap_commissions_pkg.g_target_ap_pay_method);
            print_line ('L', 'Currency Code#' || l_curr_code);
            print_line ('L', 'Invoice Amount#' || l_invoice_amt);

            INSERT INTO ap_invoices_interface (invoice_id,
                                               invoice_num,
                                               vendor_id,
                                               vendor_site_id,
                                               invoice_amount,
                                               SOURCE,
                                               org_id,
                                               payment_method_code,
                                               terms_id,
                                               gl_date,
                                               invoice_date,
                                               invoice_currency_code,
                                               exchange_date,
                                               invoice_type_lookup_code)
                 VALUES (l_invoice_id, SUBSTR (xxdoap_commissions_pkg.g_target_ar_trx_num || '-' || xxdoap_commissions_pkg.g_target_ar_org_id --G_TARGET_AR_ORG_NAME
                                                                                                                                             , 1, 50) -- --'TEST07' --INVOICE_NUM,
                                                                                                                                                     , xxdoap_commissions_pkg.g_target_vendor_id, xxdoap_commissions_pkg.g_target_vendor_site_id, l_invoice_amt, 'COMMISSIONS', xxdoap_commissions_pkg.g_target_ap_org_id, xxdoap_commissions_pkg.g_target_ap_pay_method, xxdoap_commissions_pkg.g_target_ap_terms_id, xxdoap_commissions_pkg.g_target_date, xxdoap_commissions_pkg.g_target_date, l_curr_code
                         , xxdoap_commissions_pkg.g_target_date, 'STANDARD');

            l_line_num    := 0;

            FOR r_valid_staging IN c_valid_staging_inv
            LOOP
                l_line_num         := l_line_num + 1;
                l_inv_sum          :=
                      l_inv_sum
                    + ROUND (
                            NVL (r_valid_staging.source_trx_amount, 0)
                          * NVL (r_valid_staging.commission_percentage, 0),
                          2);
                l_inv_line_count   := l_inv_line_count + 1;
                l_debug            := '10-' || TO_CHAR (l_inv_line_count);

                -- Insert invoice line --
                INSERT INTO ap_invoice_lines_interface (invoice_id, invoice_line_id, line_number, line_type_lookup_code, amount, accounting_date, distribution_set_id, --dist_code_combination_id,
                                                                                                                                                                       --dist_code_concatenated,
                                                                                                                                                                       ship_to_location_id, attribute3
                                                        , description)
                         VALUES (
                                    l_invoice_id                  --invoice_id
                                                ,
                                    ap_invoice_lines_interface_s.NEXTVAL --invoice line id
                                                                        ,
                                    l_line_num                   --line number
                                              ,
                                    'ITEM'             --line type lookup code
                                          ,
                                    ROUND (
                                          NVL (
                                              r_valid_staging.source_trx_amount,
                                              0)
                                        * NVL (
                                              r_valid_staging.commission_percentage,
                                              0)
                                        / 100,
                                        2),
                                    xxdoap_commissions_pkg.g_target_date,
                                    xxdoap_commissions_pkg.g_target_ap_dist_set_id --2172783 10004
                                                                                  ,
                                    xxdoap_commissions_pkg.g_target_ap_ship_loc_id,
                                    r_valid_staging.source_trx_id,
                                    SUBSTR (
                                           r_valid_staging.source_trx_org_name
                                        || '-'
                                        || r_valid_staging.source_supplier_name
                                        || '-'
                                        || r_valid_staging.source_trx_number,
                                        1,
                                        240));
            END LOOP;

            print_line ('L', 'Total Lines Sum#' || l_inv_sum);
            COMMIT;
            l_debug       := '11';
        END IF;

        IF l_cm_line_count > 0 OR l_inv_line_count > 0
        THEN
            l_debug   := '12';
            create_ap_invoices (x_ret_code      => l_ret_code,
                                x_ret_message   => l_ret_msg);
            l_debug   := '13';

            IF l_ret_code = '2'
            THEN
                x_ret_code      := '2';
                x_ret_message   := 'Payables Open Interface Import Failed.';
                --||x_ret_message;
                l_debug         := '14';

                UPDATE xxdo.xxdoap_commissions_stg
                   SET process_flag = 'E', status_message = status_message || 'Payables Import FAILED.'
                 WHERE     request_id =
                           xxdoap_commissions_pkg.g_conc_request_id
                       AND process_flag = 'R';

                print_line ('L', 'Payables Open Interface Import Failed.');
                COMMIT;                                -- Added for CCR0009213

                --||x_ret_message);
                /*Start changes for v1.3 */
                UPDATE ap_invoices_all aia
                   SET aia.attribute9   = 'Y'
                 WHERE EXISTS
                           (SELECT 1
                              FROM xxdo.xxdoap_commissions_stg stg
                             WHERE     stg.request_id =
                                       xxdoap_commissions_pkg.g_conc_request_id
                                   AND stg.source_trx_id = aia.invoice_id
                                   AND stg.process_flag = 'E');

                COMMIT;
            /*End changes for v1.3 */
            ELSE
                IF l_ret_code = '1'
                THEN
                    l_hold   := ' on hold';
                ELSE
                    l_hold   := NULL;
                END IF;

                l_debug   := '15';

                BEGIN
                    SELECT COUNT (1)
                      INTO l_inv_cnt
                      FROM ap_invoices_all
                     WHERE     invoice_num =
                               SUBSTR (
                                      xxdoap_commissions_pkg.g_target_ar_trx_num
                                   || '-'
                                   || xxdoap_commissions_pkg.g_target_ar_org_id,
                                   1,
                                   50)
                           AND org_id =
                               xxdoap_commissions_pkg.g_target_ap_org_id;

                    SELECT COUNT (1)
                      INTO l_cm_cnt
                      FROM ap_invoices_all
                     WHERE     invoice_num =
                               SUBSTR (
                                      xxdoap_commissions_pkg.g_target_ar_trx_num
                                   || '-'
                                   || xxdoap_commissions_pkg.g_target_ar_org_id
                                   || '-'
                                   || 'CREDIT',
                                   1,
                                   50)
                           AND org_id =
                               xxdoap_commissions_pkg.g_target_ap_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_line (
                            'L',
                            'Error Getting Invoice, CM Count:' || SQLERRM);
                END;

                print_line (
                    'L',
                       'Total Count:'
                    || TO_CHAR (NVL (l_inv_cnt, 0) + NVL (l_cm_cnt, 0)));

                IF l_inv_cnt > 0
                THEN
                    l_debug         := '16';

                    IF is_invoice_validated (
                           get_invoice_id (
                               SUBSTR (
                                      xxdoap_commissions_pkg.g_target_ar_trx_num
                                   || '-'
                                   || xxdoap_commissions_pkg.g_target_ar_org_id,
                                   1,
                                   50))) =
                       'A'
                    THEN
                        l_hold   := ' Validated.';
                    ELSE
                        l_hold   := ' On Hold.';
                    END IF;

                    UPDATE xxdo.xxdoap_commissions_stg
                       SET process_flag = 'P', status_message = status_message || 'AP Trx#' || SUBSTR (xxdoap_commissions_pkg.g_target_ar_trx_num || '-' || xxdoap_commissions_pkg.g_target_ar_org_id, 1, 50) || l_hold, current_status_flag = 'P' -- Added for v1.3
                                                                                                                                                                                                                                                  ,
                           current_status_msg = 'AP Invoice is created' -- Added for v1.3
                     WHERE     request_id =
                               xxdoap_commissions_pkg.g_conc_request_id
                           AND process_flag = 'R'
                           AND current_status_flag = 'S'     -- Added for v1.3
                           AND source_trx_type != 'CREDIT';

                    COMMIT;                            -- Added for CCR0009213

                    UPDATE ap_invoices_all aia
                       SET aia.attribute9   = 'Y'
                     WHERE EXISTS
                               (SELECT 1
                                  FROM xxdo.xxdoap_commissions_stg stg
                                 WHERE     stg.request_id =
                                           xxdoap_commissions_pkg.g_conc_request_id
                                       AND stg.source_trx_id = aia.invoice_id
                                       -- AND stg.process_flag = 'P' -- commented for v1.3
                                       AND stg.current_status_flag = 'P' -- Added for v1.3
                                                                        );

                    COMMIT;
                    x_ret_code      := '0';
                    x_ret_message   := 'SUCCESS' || x_ret_message;
                ELSE
                    l_debug   := '17';
                    print_line ('L', 'Invoices:' || l_inv_cnt);

                    SELECT COUNT (1)
                      INTO l_inv_cnt
                      FROM xxdo.xxdoap_commissions_stg
                     WHERE     request_id =
                               xxdoap_commissions_pkg.g_conc_request_id
                           AND process_flag = 'R'
                           AND source_trx_type != 'CREDIT';

                    IF l_inv_cnt > 0
                    THEN
                        UPDATE xxdo.xxdoap_commissions_stg
                           SET process_flag = 'E', status_message = status_message || ' AP Invoice creation failed.', current_status_flag = 'E' -- Added for v1.3
                                                                                                                                               ,
                               current_status_msg = 'AP Invoice created failed' -- Added for v1.3
                         WHERE     request_id =
                                   xxdoap_commissions_pkg.g_conc_request_id
                               AND process_flag = 'R'
                               AND source_trx_type != 'CREDIT';

                        COMMIT;

                        /*Start changes for v1.3 */
                        UPDATE ap_invoices_all aia
                           SET aia.attribute9   = 'Y'
                         WHERE EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxdoap_commissions_stg stg
                                     WHERE     stg.request_id =
                                               xxdoap_commissions_pkg.g_conc_request_id
                                           AND stg.source_trx_id =
                                               aia.invoice_id
                                           AND stg.process_flag = 'E'
                                           --         AND stg.current_status_flag <> 'F'
                                           /* --Commented for CCR0009213
                    AND stg.status_message LIKE
                                                  '%Payables Import FAILED.'
                   */
                                           AND stg.current_status_flag = 'E' --Added for CCR0009213
                                           AND stg.source_trx_type !=
                                               'CREDIT');

                        COMMIT;
                        /*End changes for v1.3 */

                        x_ret_code      := '2';
                        x_ret_message   := 'Payables Invoices Not Created.';
                    END IF;
                END IF;

                IF l_cm_cnt > 0
                THEN
                    l_debug         := '18';

                    IF is_invoice_validated (
                           get_invoice_id (
                               SUBSTR (
                                      xxdoap_commissions_pkg.g_target_ar_trx_num
                                   || '-'
                                   || xxdoap_commissions_pkg.g_target_ar_org_id
                                   || '-'
                                   || 'CREDIT',
                                   1,
                                   50))) =
                       'A'
                    THEN
                        l_hold   := ' Validated.';
                    ELSE
                        l_hold   := ' On Hold.';
                    END IF;

                    UPDATE xxdo.xxdoap_commissions_stg
                       SET process_flag = 'P', status_message = status_message || ' AP Trx#' || SUBSTR (xxdoap_commissions_pkg.g_target_ar_trx_num || '-' || xxdoap_commissions_pkg.g_target_ar_org_id || '-' || 'CREDIT', 1, 50) || l_hold, current_status_flag = 'P' -- Added for v1.3
                                                                                                                                                                                                                                                                      ,
                           current_status_msg = 'Validation success' -- Added for v1.3
                     WHERE     request_id =
                               xxdoap_commissions_pkg.g_conc_request_id
                           AND process_flag = 'R'
                           AND source_trx_type = 'CREDIT';

                    COMMIT;

                    UPDATE ap_invoices_all aia
                       SET aia.attribute9   = 'Y'
                     WHERE EXISTS
                               (SELECT 1
                                  FROM xxdo.xxdoap_commissions_stg stg
                                 WHERE     stg.request_id =
                                           xxdoap_commissions_pkg.g_conc_request_id
                                       AND stg.source_trx_id = aia.invoice_id
                                       --AND stg.process_flag = 'P' -- commented for v1.3
                                       AND current_status_flag = 'P' -- Added for v1.3
                                                                    );

                    COMMIT;
                    x_ret_code      := '0';
                    x_ret_message   := 'SUCCESS';
                ELSE
                    l_debug   := '19';
                    print_line ('L', 'Credit Memos:' || l_cm_cnt);

                    SELECT COUNT (1)
                      INTO l_cm_cnt
                      FROM xxdo.xxdoap_commissions_stg
                     WHERE     request_id =
                               xxdoap_commissions_pkg.g_conc_request_id
                           AND process_flag = 'R'
                           AND source_trx_type = 'CREDIT';

                    IF l_cm_cnt > 0
                    THEN
                        UPDATE xxdo.xxdoap_commissions_stg
                           SET process_flag = 'E', status_message = status_message || ' AP Credit Memo creation failed.', current_status_flag = 'E' -- Added for CCR0009213
                         WHERE     request_id =
                                   xxdoap_commissions_pkg.g_conc_request_id
                               AND process_flag = 'R'
                               AND source_trx_type = 'CREDIT';

                        COMMIT;

                        --Start Added for CCR0009213
                        UPDATE ap_invoices_all aia
                           SET aia.attribute9   = 'Y'
                         WHERE EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxdoap_commissions_stg stg
                                     WHERE     stg.request_id =
                                               xxdoap_commissions_pkg.g_conc_request_id
                                           AND stg.source_trx_id =
                                               aia.invoice_id
                                           AND stg.process_flag = 'E'
                                           AND stg.current_status_flag = 'E'
                                           AND stg.source_trx_type = 'CREDIT');

                        COMMIT;
                        --End Added for CCR0009213

                        x_ret_code   := '2';
                        x_ret_message   :=
                            'Payables Credit Memos Not Created.';
                    END IF;
                END IF;

                l_debug   := '20';
            END IF;
        END IF;

        l_debug            := '21';
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line (
                'L',
                'Error in create_target_ap_trx:' || l_debug || ':' || SQLERRM);
            x_ret_code   := '2';
            x_ret_message   :=
                'Error in create_target_ap_trx:' || l_debug || ':' || SQLERRM;
    END create_target_ap_trx;

    PROCEDURE create_target_ar_trx (x_ret_code      OUT VARCHAR2,
                                    x_ret_message   OUT VARCHAR2)
    IS
        CURSOR c_valid_staging_inv IS
            SELECT *
              FROM xxdo.xxdoap_commissions_stg
             WHERE     process_flag = 'V'
                   AND request_id = xxdoap_commissions_pkg.g_conc_request_id --AND source_trx_type IN ('MIXED','STANDARD')
                   AND current_status_flag = 'V'             -- Added for v1.3
                                                ;

        CURSOR c_valid_staging_cm IS
            SELECT *
              FROM xxdo.xxdoap_commissions_stg
             WHERE     process_flag = 'V'
                   AND request_id = xxdoap_commissions_pkg.g_conc_request_id
                   AND source_trx_type = 'CREDIT'
                   AND current_status_flag = 'V'             -- Added for v1.3
                                                ;

        l_invoice_id        ap_invoices.invoice_id%TYPE;
        l_line_num          ap_invoice_lines.line_number%TYPE;
        l_invoice_amt       ap_invoices.invoice_amount%TYPE;
        l_cm_amt            ap_invoices.invoice_amount%TYPE;
        l_trx_type_id       ra_cust_trx_types.cust_trx_type_id%TYPE;
        l_cm_type_id        ra_cust_trx_types.cust_trx_type_id%TYPE;
        l_inv_type_id       ra_cust_trx_types.cust_trx_type_id%TYPE;
        l_batch_source_id   ra_batch_sources.batch_source_id%TYPE;
        l_ret_code          VARCHAR2 (30);
        l_ret_msg           VARCHAR2 (360);
        l_cm_line_count     NUMBER;
        l_inv_line_count    NUMBER;
        l_brand             VARCHAR2 (30);
    -- Target AP transactions
    BEGIN
        create_ar_invoices (x_ret_code => l_ret_code, x_ret_msg => l_ret_msg);

        IF l_ret_code = '2'
        THEN
            x_ret_code      := '2';
            x_ret_message   := 'AR Invoice Creation API Failed.' || l_ret_msg;

            UPDATE xxdo.xxdoap_commissions_stg
               SET process_flag = 'E', status_message = status_message || 'AR Invoice Creation API FAILED.'
             WHERE     request_id = xxdoap_commissions_pkg.g_conc_request_id
                   AND current_status_flag = 'X'             -- Added for v1.3
                                                ;

            fnd_file.put_line (
                fnd_file.LOG,
                'Failed to create_ar_invoice:' || xxdoap_commissions_pkg.g_target_ar_trx_num); -- Added for v1.3
        ELSE
            UPDATE xxdo.xxdoap_commissions_stg
               SET process_flag = 'R', status_message = status_message || ' AR Trx#' || xxdoap_commissions_pkg.g_target_ar_trx_num || '. '
             WHERE     request_id = xxdoap_commissions_pkg.g_conc_request_id
                   AND process_flag = 'V'
                   AND current_status_flag = 'R'             -- Added for v1.3
                   AND target_ar_trx_number IS NOT NULL --AND SOURCE_TRX_ID = r_valid_staging.SOURCE_TRX_ID
                                                       --AND source_trx_type IN ('MIXED','STANDARD')
                                                       ;

            x_ret_code      := '0';
            x_ret_message   := 'SUCCESS' || l_ret_msg;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Error in create_target_ar_trx:' || SQLERRM);
            x_ret_code      := '2';
            x_ret_message   := 'Error in create_target_ar_trx:' || SQLERRM;
    END create_target_ar_trx;

    PROCEDURE get_relation_details (p_src_org_id IN NUMBER, p_tgt_ap_org_id IN NUMBER, --Start Changes V2.1
                                                                                       --                                   p_tgt_ar_org_id   IN     NUMBER,
                                                                                       --End Changes V2.1
                                                                                       x_ret_code OUT VARCHAR2
                                    , x_ret_message OUT VARCHAR2)
    IS
    BEGIN
        --start changes V2.1
        /*  SELECT ffv.flex_value,
                 TO_NUMBER (ffv.attribute10)                   -- Source PO/AP Org
                                            ,
                 TO_NUMBER (ffv.attribute11)                      -- Target AR Org
                                            ,
                 TO_NUMBER (ffv.attribute12)                      -- Target AP Org
                                            ,
                 TO_DATE (ffv.attribute13, 'DD-MON-YY') -- Transaction Cutoff date
                                                       ,
                 ffv.attribute14                -- relationship source transaction
                                ,
                 ffv.attribute16                        -- Exclude sample invoices
            INTO xxdoap_commissions_pkg.g_relationship,
                 xxdoap_commissions_pkg.g_source_org_id,
                 xxdoap_commissions_pkg.g_target_ar_org_id,
                 xxdoap_commissions_pkg.g_target_ap_org_id,
                 xxdoap_commissions_pkg.g_trx_cutoff_date,
                 xxdoap_commissions_pkg.g_relation_trx_type,
                 xxdoap_commissions_pkg.g_exclude_sample_invoices
            FROM fnd_flex_values ffv, fnd_flex_value_sets fset
           WHERE     1 = 1
                 AND ffv.flex_value_set_id = fset.flex_value_set_id
                 AND fset.flex_value_set_name =
                        xxdoap_commissions_pkg.g_relationship_value_set
                 AND enabled_flag = 'Y'
                 AND TO_NUMBER (ffv.attribute10) =
                        xxdoap_commissions_pkg.g_source_org_id
                 AND TO_NUMBER (ffv.attribute11) =
                        xxdoap_commissions_pkg.g_target_ar_org_id
                 AND TO_NUMBER (ffv.attribute12) =
                        xxdoap_commissions_pkg.g_target_ap_org_id;
          */
        SELECT ffv.flex_value, TO_NUMBER (ffv.attribute10) -- Source PO/AP Org
                                                          , TO_NUMBER (ffv.attribute11) -- Target AR Org
                                                                                       ,
               TO_NUMBER (ffv.attribute12)                    -- Target AP Org
                                          , TO_DATE (ffv.attribute13, 'DD-MON-YY') -- Transaction Cutoff date
                                                                                  , ffv.attribute14 -- relationship source transaction
                                                                                                   ,
               ffv.attribute16,                     -- Exclude sample invoices
                                TO_NUMBER (ffv.attribute15), -- Target AR Customer Name
                                                             TO_NUMBER (ffv.attribute17), -- Target AR Customer Site Name
               ffv.attribute18,                   --Target AR Invoice Currency
                                TO_NUMBER (ffv.attribute19), --Target AP Vendor
                                                             TO_NUMBER (ffv.attribute20), --Target AP Vendor Site Name
               ffv.attribute21                    --Target AP Invoice Currency
          INTO xxdoap_commissions_pkg.g_relationship, xxdoap_commissions_pkg.g_source_org_id, xxdoap_commissions_pkg.g_target_ar_org_id, xxdoap_commissions_pkg.g_target_ap_org_id,
                                                    xxdoap_commissions_pkg.g_trx_cutoff_date, xxdoap_commissions_pkg.g_relation_trx_type, xxdoap_commissions_pkg.g_exclude_sample_invoices,
                                                    xxdoap_commissions_pkg.g_target_customer_id, xxdoap_commissions_pkg.g_target_cust_site_use_id, xxdoap_commissions_pkg.g_target_ar_currency,
                                                    xxdoap_commissions_pkg.g_target_vendor_id, xxdoap_commissions_pkg.g_target_vendor_site_id, xxdoap_commissions_pkg.g_target_ap_currency
          FROM fnd_flex_values ffv, fnd_flex_value_sets fset
         WHERE     1 = 1
               AND ffv.flex_value_set_id = fset.flex_value_set_id
               AND fset.flex_value_set_name =
                   xxdoap_commissions_pkg.g_relationship_value_set
               AND enabled_flag = 'Y'
               AND TO_NUMBER (ffv.attribute10) =
                   xxdoap_commissions_pkg.g_source_org_id
               AND TO_NUMBER (ffv.attribute12) = p_tgt_ap_org_id;

        --End Changes V2.1

        print_line (
            'L',
            'Source PO/AP Org:' || xxdoap_commissions_pkg.g_source_org_id);
        print_line (
            'L',
            'Target AR Org:' || xxdoap_commissions_pkg.g_target_ar_org_id);
        print_line (
            'L',
            'Target AP Org:' || xxdoap_commissions_pkg.g_target_ap_org_id);
        print_line (
            'L',
            'Transaction Cut-off Date:' || xxdoap_commissions_pkg.g_trx_cutoff_date);
        print_line (
            'L',
            'Source Transaction Type:' || xxdoap_commissions_pkg.g_source_trx_type);
        print_line (
            'L',
            'Relation Transaction Type:' || xxdoap_commissions_pkg.g_relation_trx_type);
        print_line (
            'L',
            'Exclude Sample Invoices:' || xxdoap_commissions_pkg.g_exclude_sample_invoices);
        print_line (
            'L',
            'Target Customer:' || xxdoap_commissions_pkg.g_target_customer_id);
        print_line (
            'L',
            'Site Use ID:' || xxdoap_commissions_pkg.g_target_cust_site_use_id);
        print_line (
            'L',
            'Target AR Currency' || xxdoap_commissions_pkg.g_target_ar_currency);
        print_line (
            'L',
            'Target AP Vendor ID: ' || xxdoap_commissions_pkg.g_target_vendor_id);
        print_line (
            'L',
            'Target Vendor Site ID: ' || xxdoap_commissions_pkg.g_target_vendor_site_id);
        print_line (
            'L',
            'Target AP Currency' || xxdoap_commissions_pkg.g_target_ap_currency);
        print_line ('L',
                    'Relationship:' || xxdoap_commissions_pkg.g_relationship);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_ret_code   := '2';
            x_ret_message   :=
                'No Relationship found between the given source, target organizations';
        WHEN OTHERS
        THEN
            x_ret_code   := '2';
            x_ret_message   :=
                SUBSTR ('Unable to Get Relationship details:' || SQLERRM,
                        1,
                        240);
            print_line ('L',
                        'Unable to Get Relationship details:' || SQLERRM);
    END get_relation_details;

    PROCEDURE validate_staging
    IS
        CURSOR c_trx IS
            SELECT *
              FROM xxdo.xxdoap_commissions_stg
             WHERE     1 = 1
                   AND request_id = xxdoap_commissions_pkg.g_conc_request_id
                   AND process_flag = 'N'
                   AND current_status_flag = 'I'             -- Added for v1.3
                                                ;

        l_valid             VARCHAR2 (1);
        l_message           VARCHAR2 (4000);
        l_cur_status_msg    VARCHAR2 (4000);
        l_cur_status_flag   VARCHAR2 (1);
        l_boolean           BOOLEAN;
    BEGIN
        FOR r_trx IN c_trx
        LOOP
            l_valid             := 'V';
            l_message           := NULL;
            l_cur_status_flag   := 'V';                      -- Added for v1.3
            l_cur_status_msg    := 'Validation';             -- Added for v1.3

            IF is_null (r_trx.source_trx_org_id)
            THEN
                l_valid             := 'E';
                l_message           :=
                       l_message
                    || ' Source Transaction Organization not found.';
                l_cur_status_flag   := 'F';                  -- Added for v1.3
                l_cur_status_msg    :=
                    'Source Transaction Organization not found while validation'; -- Added for v1.3
                print_line (
                    'O',
                    'Unable to find Source TRX Org for :' || r_trx.source_trx_number); -- Added for v1.3
            END IF;

            IF is_null (r_trx.target_ar_org_id)
            THEN
                l_valid             := 'E';
                l_message           :=
                    l_message || ' Target AR Organizaton not found.';
                l_cur_status_flag   := 'F';                  -- Added for v1.3
                l_cur_status_msg    :=
                    'Target AR Organizaton not found while validation'; -- Added for v1.3
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to find AR org for :' || r_trx.source_trx_number); -- Added for v1.3
            END IF;

            IF is_null (r_trx.target_customer_id)
            THEN
                l_valid             := 'E';
                l_message           := l_message || ' Target Customer not found.';
                l_cur_status_flag   := 'F';                  -- Added for v1.3
                l_cur_status_msg    :=
                    'Target Customer not found while validation'; -- Added for v1.3
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to find Customer for :' || r_trx.source_trx_number); -- Added for v1.3
            END IF;

            IF is_null (r_trx.target_customer_site_id)
            THEN
                l_valid             := 'E';
                l_message           :=
                    l_message || ' Target Customer Site not found.';
                l_cur_status_flag   := 'F';                  -- Added for v1.3
                l_cur_status_msg    :=
                    'Target Customer Site not found while validation'; -- Added for v1.3
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to find Customer Site for :' || r_trx.source_trx_number); -- Added for v1.3
            END IF;

            IF is_null (r_trx.target_supplier_id)
            THEN
                l_valid             := 'E';
                l_message           := l_message || ' Target Supplier not found.';
                l_cur_status_flag   := 'F';                  -- Added for v1.3
                l_cur_status_msg    :=
                    'Target Supplier not found while validation'; -- Added for v1.3
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to find Supplier for :' || r_trx.source_trx_number); -- Added for v1.3
            END IF;

            IF is_null (r_trx.target_supplier_site_id)
            THEN
                l_valid             := 'E';
                l_message           :=
                    l_message || ' Target Supplier Site not found.';
                l_cur_status_flag   := 'F';                  -- Added for v1.3
                l_cur_status_msg    :=
                    'Target Supplier Site not found while validation'; -- Added for v1.3
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to find Supplier Site for :' || r_trx.source_trx_number); -- Added for v1.3
            END IF;

            IF is_null (r_trx.commission_percentage)
            THEN
                l_valid             := 'E';
                l_message           :=
                    l_message || ' Commission Percentage not found.';
                l_cur_status_flag   := 'F';                  -- Added for v1.3
                l_cur_status_msg    :=
                    'Commission Percentage not found while validation'; -- Added for v1.3
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to find Commission Percentage for :' || r_trx.source_trx_number); -- Added for v1.3
            END IF;

            UPDATE xxdo.xxdoap_commissions_stg
               SET process_flag = l_valid, status_message = l_message, current_status_flag = l_cur_status_flag -- Added for v1.3
                                                                                                              ,
                   current_status_msg = l_cur_status_msg     -- Added for v1.3
             WHERE     1 = 1
                   AND request_id = xxdoap_commissions_pkg.g_conc_request_id
                   AND source_trx_id = r_trx.source_trx_id;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Unable to Validate Staging:' || SQLERRM);
            NULL;
    END validate_staging;

    PROCEDURE print_output
    IS
        CURSOR c_trx IS
            SELECT *
              FROM xxdo.xxdoap_commissions_stg
             WHERE request_id = xxdoap_commissions_pkg.g_conc_request_id;

        l_count   NUMBER := 0;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM xxdo.xxdoap_commissions_stg
         WHERE request_id = xxdoap_commissions_pkg.g_conc_request_id;

        print_line ('O', '');
        print_line ('O', ' Commission Calculation And Creation - Deckers');
        print_line ('O', '');
        print_line ('O', '');
        print_line (
            'O',
            '=====================================================================================================================================================================');
        print_line (
            'O',
               RPAD ('Operating Unit', 20, ' ')
            || ' '
            || RPAD ('SupplierName', 30, ' ')
            || ' '
            || RPAD ('SupplierSite', 20, ' ')
            || ' '
            || RPAD ('Invoice#', 25, ' ')
            || ' '
            || RPAD ('Type', 8, ' ')
            || ' '
            || RPAD ('PO Number', 10, ' ')
            || ' '
            || RPAD ('InvoiceDate', 14, ' ')
            || ' '
            || RPAD ('Amount', 11, ' ')
            || ' '
            || RPAD ('Comm%', 5, ' ')
            || ' '
            || RPAD ('Flag', 5, ' ')
            || ' '
            || 'Message');
        print_line (
            'O',
            '-------------------- ------------------------------ -------------------- ------------------------- -------- ---------- -------------- ----------- -------------------');

        IF l_count = 0
        THEN
            print_line ('O', ' *** NO DATA FOUND ***');
        ELSE
            FOR r_trx IN c_trx
            LOOP
                print_line (
                    'O',
                       RPAD (r_trx.source_trx_org_name, 20, ' ')
                    || ' '
                    || RPAD (r_trx.source_supplier_name, 30, ' ')
                    || ' '
                    || RPAD (r_trx.source_supplier_site_code, 20, ' ')
                    || ' '
                    || RPAD (r_trx.source_trx_number, 25, ' ')
                    || ' '
                    || RPAD (r_trx.source_trx_type, 8, ' ')
                    || ' '
                    || RPAD (NVL (r_trx.linked_po_number, '-'), 10, ' ')
                    || ' '
                    || RPAD (TO_CHAR (r_trx.source_trx_date, 'MM/DD/YYYY'),
                             14,
                             ' ')
                    || ' '
                    || LPAD (TO_CHAR (r_trx.source_trx_amount), 11, ' ')
                    || ' '
                    || LPAD (TO_CHAR (NVL (r_trx.commission_percentage, 0)),
                             5,
                             ' ')
                    || ' '
                    || RPAD (TO_CHAR (r_trx.process_flag), 5, ' ')
                    || ' '
                    || r_trx.status_message);
            END LOOP;
        END IF;

        print_line (
            'O',
            '=====================================================================================================================================================================');
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Unable to Print Output:' || SQLERRM);
    END print_output;

    PROCEDURE load_src_trx (
        p_src_org_id           IN     NUMBER,
        p_src_trx_type         IN     VARCHAR2,
        p_src_trx_dt_from      IN     VARCHAR2,
        p_src_trx_dt_to        IN     VARCHAR2,
        p_src_invoice_id       IN     NUMBER DEFAULT NULL,
        p_src_vendor_id        IN     NUMBER DEFAULT NULL,
        p_src_vendor_site_id   IN     NUMBER DEFAULT NULL,
        p_gl_date_from         IN     VARCHAR2,               -- Added for 1.2
        p_gl_date_to           IN     VARCHAR2,               -- Added for 1.2
        x_ret_code                OUT VARCHAR2,
        x_ret_message             OUT VARCHAR2)
    IS
        CURSOR c_src_trx (p_org_id NUMBER, p_vendor_id NUMBER, p_vendor_site_id NUMBER, p_date_from DATE, p_date_to DATE, p_src_type VARCHAR2
                          , p_invoice_id NUMBER)
        IS
            SELECT DISTINCT aia.org_id src_org_id, aia.invoice_num src_trx_num, aia.invoice_date src_trx_date,
                            aia.invoice_type_lookup_code src_trx_type, hou.NAME src_org_name, aps.vendor_id src_vendor_id,
                            aps.vendor_name src_vendor_name, apss.vendor_site_id src_vendor_site_id, apss.vendor_site_code src_vendor_site_code,
                            aia.attribute8 sample_invoice, aia.invoice_id source_trx_id, xxdoap_commissions_pkg.get_commission_perc (aia.invoice_date) commission_percentage --, xxdoap_commissions_pkg.get_commission_amt(aia.invoice_id) commission_amount
                                                                                                                                                                            ,
                            aia.invoice_amount source_trx_amount, xxdoap_commissions_pkg.get_brand (aia.invoice_id) brand, aia.invoice_currency_code currency_code
              FROM ap_invoices_all aia, ap_suppliers aps, ap_supplier_sites_all apss,
                   hr_operating_units hou, ap_invoice_lines_all aila1, apps.ap_invoice_distributions_all aida1
             WHERE     1 = 1
                   AND aia.vendor_id = aps.vendor_id
                   AND aia.vendor_site_id = apss.vendor_site_id
                   AND aia.org_id = apss.org_id
                   AND aia.org_id = hou.organization_id
                   AND aps.vendor_type_lookup_code = 'MANUFACTURER'
                   AND aia.org_id = p_org_id
                   AND aia.vendor_id = NVL (p_vendor_id, aia.vendor_id)
                   AND aia.vendor_site_id =
                       NVL (p_vendor_site_id, aia.vendor_site_id)
                   AND aia.invoice_id = NVL (p_invoice_id, aia.invoice_id)
                   AND aia.invoice_date >=
                       NVL (p_date_from, aia.invoice_date)
                   AND aia.invoice_date <
                       NVL (p_date_to, aia.invoice_date) + 1
                   AND aia.invoice_id = aila1.invoice_id     -- Added for v1.3
                   AND aida1.invoice_id = aia.invoice_id     -- Added for v1.3
                   AND aila1.line_number = aida1.invoice_line_number -- Added for v1.3
                   AND aida1.ACCOUNTING_DATE BETWEEN NVL (
                                                         TO_DATE (
                                                             p_gl_date_from),
                                                         aida1.ACCOUNTING_DATE)
                                                 AND NVL (
                                                         TO_DATE (
                                                             p_gl_date_to),
                                                         aida1.ACCOUNTING_DATE) -- Added for v1.3
                   -- Commented for v1.3
                   /*AND xxdoap_commissions_pkg.get_dist_gl_date (NVL(p_invoice_id,aia.invoice_id)) BETWEEN
                   NVL(to_date(p_gl_date_from),xxdoap_commissions_pkg.get_dist_gl_date (NVL(p_invoice_id,aia.invoice_id)))
                   AND NVL(to_date(p_gl_date_to),xxdoap_commissions_pkg.get_dist_gl_date (NVL(p_invoice_id,aia.invoice_id)))*/
                   -- Added for 1.2
                   --Pick Invoice type 'CREDIT','STANDARD','MIXED' when source type 'BOTH'
                   AND ((aia.invoice_type_lookup_code IN ('CREDIT', 'STANDARD', 'MIXED') AND p_src_type = 'BOTH') --Pick Invoice type 'CREDIT' when source type 'CREDIT'
                                                                                                                  OR (aia.invoice_type_lookup_code = ('CREDIT') AND p_src_type = 'CREDIT') --Pick Invoice type 'STANDARD','MIXED' when source type 'INVOICE'
                                                                                                                                                                                           OR (aia.invoice_type_lookup_code IN ('STANDARD', 'MIXED') AND p_src_type = 'INVOICE'))
                   AND DECODE (
                           xxdoap_commissions_pkg.g_exclude_sample_invoices,
                           'Y', NVL (aia.attribute8, 'N'),
                           'Y') =
                       DECODE (
                           xxdoap_commissions_pkg.g_exclude_sample_invoices,
                           'Y', 'N',
                           'Y')
                   AND NVL (aia.attribute9, 'N') = 'N' --Commissions created DFF
                   --IF source type INV/CREDIT invoice creation date must be >= cutoffdate
                   AND DECODE (xxdoap_commissions_pkg.g_relation_trx_type,
                               'INV/CREDIT', aia.creation_date,
                               xxdoap_commissions_pkg.g_trx_cutoff_date) >=
                       xxdoap_commissions_pkg.g_trx_cutoff_date
                   --IF source type 'PO' then pick only PO linked invoices with PO Line creation date >= cutoffdate
                   AND DECODE (
                           xxdoap_commissions_pkg.g_relation_trx_type,
                           'PO', get_po_line_creation_dt (aia.invoice_id),
                           xxdoap_commissions_pkg.g_trx_cutoff_date) >=
                       xxdoap_commissions_pkg.g_trx_cutoff_date
                   --Check if transaction type excluded at supplier level
                   AND xxdoap_commissions_pkg.get_vendor_exclusion (
                           aia.vendor_id,
                           aia.invoice_type_lookup_code) =
                       'N'
                   --Check if transaction type excluded at site level
                   AND xxdoap_commissions_pkg.get_ven_site_exclusion (
                           aia.vendor_site_id,
                           aia.invoice_type_lookup_code) =
                       'N'
                   --Validate and Accounted invoices only
                   AND ap_invoices_pkg.get_posting_status (aia.invoice_id) =
                       'Y'
                   --Start changes for V2.1
                   AND aia.global_attribute1 =
                       xxdoap_commissions_pkg.g_target_ap_org_id --End Changes for V2.1
                                                                --Start Changes by Deckers IT Team on 03 May 2017 -- Commented this code
                                                                --                AND ap_invoices_pkg.get_approval_status (
                                                                --                       aia.invoice_id,
                                                                --                       aia.invoice_amount,
                                                                --                       aia.payment_status_flag,
                                                                --                       aia.invoice_type_lookup_code) = ('APPROVED')
                                                                --End Changes Changes by Deckers IT Team on 03 May 2017 -- Commented this code
                                                                -- AND aia.invoice_num = '95074/16' -- Added by Anjana for testing
                                                                ;

        l_target_ar_org   hr_operating_units.NAME%TYPE;
        l_target_ap_org   hr_operating_units.NAME%TYPE;
        l_customer        hz_parties.party_name%TYPE;
        l_customer_num    hz_cust_accounts.account_number%TYPE;
        l_vendor          po_vendors.vendor_name%TYPE;
        l_vendor_site     po_vendor_sites.vendor_site_code%TYPE;
        l_brand           VARCHAR2 (30);
        l_count           NUMBER;
        l_po_num          po_headers_all.segment1%TYPE;
        l_dist_gl_date    DATE := NULL;                       -- Added for 1.2
    --VARCHAR2 (30); -- BT Changes
    BEGIN
        l_count   := 0;

        FOR r_trx IN c_src_trx (p_src_org_id, p_src_vendor_id, p_src_vendor_site_id, p_src_trx_dt_from, p_src_trx_dt_to, p_src_trx_type
                                , p_src_invoice_id)           -- Added for 1.2
        LOOP
            l_count    := l_count + 1;
            l_brand    := get_brand (r_trx.source_trx_id);
            l_po_num   := get_po_num (r_trx.source_trx_id);

            BEGIN
                INSERT INTO xxdo.xxdoap_commissions_stg (
                                request_id,
                                process_flag,
                                status_message,
                                source_trx_org_id,
                                source_trx_id,
                                source_trx_org_name,
                                source_trx_type,
                                source_trx_date,
                                source_trx_number,
                                source_supplier_name,
                                source_supplier_site_code,
                                source_supplier_id,
                                source_supplier_site_id,
                                sample_invoice,
                                cutoff_date,
                                commission_percentage,
                                target_ar_org_name,
                                target_ar_org_id,
                                target_ap_org_name,
                                target_ap_org_id,
                                target_customer_id,
                                target_customer_name,
                                target_customer_num,
                                target_customer_site_id,
                                target_customer_site_use_id,
                                target_customer_site_name,
                                target_supplier_id,
                                target_supplier_name,
                                target_supplier_site_id,
                                target_supplier_site_code,
                                target_supplier_site_address,
                                target_ap_trx_number,
                                target_ap_trx_id,
                                target_ar_trx_number,
                                target_ar_trx_id,
                                target_ap_trx_amount,
                                target_ar_trx_amount,
                                target_ar_trx_date,
                                target_ap_trx_date,
                                linked_po_number,
                                brand,
                                source_trx_amount,
                                currency_code            --, commission_amount
                                             ,
                                current_status_flag          -- Added for v1.3
                                                   ,
                                current_status_msg           -- Added for v1.3
                                                  )
                         VALUES (
                                    xxdoap_commissions_pkg.g_conc_request_id --request_id
                                                                            ,
                                    'N'                         --process_flag
                                       ,
                                    NULL                      --status_message
                                        ,
                                    r_trx.src_org_id       --source_trx_org_id
                                                    ,
                                    r_trx.source_trx_id        --source_trx_id
                                                       ,
                                    r_trx.src_org_name   --source_trx_org_name
                                                      ,
                                    r_trx.src_trx_type       --source_trx_type
                                                      ,
                                    r_trx.src_trx_date       --source_trx_date
                                                      ,
                                    r_trx.src_trx_num      --source_trx_number
                                                     ,
                                    r_trx.src_vendor_name --source_supplier_name
                                                         ,
                                    r_trx.src_vendor_site_code --source_supplier_site_code
                                                              ,
                                    r_trx.src_vendor_id   --source_supplier_id
                                                       ,
                                    r_trx.src_vendor_site_id --src_vendor_site_idsource_supplier_site_id
                                                            ,
                                    r_trx.sample_invoice      --sample_invoice
                                                        ,
                                    xxdoap_commissions_pkg.g_trx_cutoff_date --cutoff_date
                                                                            ,
                                    r_trx.commission_percentage --NULL--commission_percentage
                                                               ,
                                    xxdoap_commissions_pkg.g_target_ar_org_name --l_target_ar_org--target_ar_org_name
                                                                               ,
                                    xxdoap_commissions_pkg.g_target_ar_org_id --target_ar_org_id
                                                                             ,
                                    xxdoap_commissions_pkg.g_target_ap_org_name --l_target_ap_org--target_ap_org_name
                                                                               ,
                                    xxdoap_commissions_pkg.g_target_ap_org_id --target_ap_org_id
                                                                             ,
                                    xxdoap_commissions_pkg.g_target_customer_id --target_customer_id
                                                                               ,
                                    xxdoap_commissions_pkg.g_target_ar_customer --l_customer--target_customer_name
                                                                               ,
                                    xxdoap_commissions_pkg.g_target_ar_cust_num --l_customer_num --target_customer_num
                                                                               ,
                                    xxdoap_commissions_pkg.g_target_customer_site_id --target_customer_site_id
                                                                                    ,
                                    xxdoap_commissions_pkg.g_target_cust_site_use_id --target_customer_site_use_id
                                                                                    ,
                                    NULL           --target_customer_site_name
                                        ,
                                    xxdoap_commissions_pkg.g_target_vendor_id --target_supplier_id
                                                                             ,
                                    xxdoap_commissions_pkg.g_target_ap_vendor --l_vendor--target_supplier_name
                                                                             ,
                                    xxdoap_commissions_pkg.g_target_vendor_site_id --target_supplier_site_id
                                                                                  ,
                                    xxdoap_commissions_pkg.g_target_ap_vendor_site --l_vendor_site--target_supplier_site_code
                                                                                  ,
                                    NULL        --target_supplier_site_address
                                        ,
                                    NULL                --target_ap_trx_number
                                        ,
                                    NULL                    --target_ap_trx_id
                                        ,
                                    NULL                --target_ar_trx_number
                                        ,
                                    NULL                    --target_ar_trx_id
                                        ,
                                    NULL                --target_ap_trx_amount
                                        ,
                                    NULL                --target_ar_trx_amount
                                        ,
                                    xxdoap_commissions_pkg.g_target_date --target_ar_trx_date
                                                                        ,
                                    xxdoap_commissions_pkg.g_target_date --target_ap_trx_date
                                                                        ,
                                    l_po_num                --linked_po_number
                                            ,
                                    l_brand,
                                    r_trx.source_trx_amount,
                                    r_trx.currency_code --, r_trx.commission_amount
                                                       ,
                                    'I' -- flag while inserting the records  -- Added for v1.3
                                       ,
                                    'INSERTION_XXDOAP_COMMISSIONS_STG' -- Added for v1.3
                                                                      );

                NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_line (
                        'L',
                           'Error inserting into staging:'
                        || TO_CHAR (r_trx.source_trx_id));
            END;
        /* Begin changes for v1.3 */
        /* Commented on 27 Apr 2017 by Deckers IT Team and added while ap invoice creation
    BEGIN

 UPDATE ap_invoices_all aia
                   SET aia.attribute9 = 'PROCESSING'
                 WHERE aia.invoice_num = r_trx.src_trx_num
     and aia.vendor_id = r_trx.src_vendor_id
     and aia.vendor_site_id = r_trx.src_vendor_site_id
     and aia.attribute8 = r_trx.sample_invoice;
                  commit;
     EXCEPTION
    WHEN OTHERS THEN
    print_line (
                   'L',
                      'Error while updating the attribute9:'
                   || TO_CHAR (r_trx.src_trx_num));
    END;
          */
        /* End changes for v1.3 */
        END LOOP;

        IF l_count = 0
        THEN
            x_ret_code   := '1';
            x_ret_message   :=
                'No Data Found for loading into staging table.';
        END IF;

        NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code      := '2';
            x_ret_message   := 'Error in load_src_trx:' || SQLERRM;
            print_line ('L', x_ret_message);
    END load_src_trx;

    FUNCTION get_email_recips (v_lookup_type VARCHAR2)
        RETURN XXDOAP_COMMISSIONS_PKG.tbl_recips
    IS
        v_def_mail_recips   XXDOAP_COMMISSIONS_PKG.tbl_recips;

        CURSOR c_recips IS
            SELECT lookup_code, meaning, description
              FROM apps.fnd_lookup_values
             WHERE     lookup_type = v_lookup_type
                   AND enabled_flag = 'Y'
                   AND LANGUAGE = USERENV ('LANG')
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);
    BEGIN
        v_def_mail_recips.DELETE;

        FOR c_recip IN c_recips
        LOOP
            v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                c_recip.meaning;
        END LOOP;

        RETURN v_def_mail_recips;
    END;

    PROCEDURE commission_alert (errbuff        OUT VARCHAR2,
                                retcode        OUT VARCHAR2,
                                pn_ou_org   IN     NUMBER)
    -- ,pd_cut_off_date in VARCHAR2)
    IS
        v_out_line          VARCHAR2 (4000);
        l_counter           NUMBER := 0;
        l_ret_val           NUMBER := 0;
        v_def_mail_recips   apps.XXDOAP_COMMISSIONS_PKG.tbl_recips;

        CURSOR no_comm_inv (cn_ou_org IN NUMBER)
        IS
              SELECT DISTINCT hp.party_name comm_ar_customer_name, rct.trx_number comm_ar_inv_num, TO_CHAR (rct.trx_date, 'DD-MON-YYYY') comm_ar_inv_date,
                              sched.amount_due_original comm_ar_inv_amount, (NVL (sched.amount_due_original, 0) - NVL (sched.amount_due_remaining, 0)) comm_ar_inv_amt_paid, sched.amount_due_remaining comm_ar_inv_amt_remaining,
                              hou_ar.NAME comm_ar_inv_operating_unit, aps_tgt.vendor_name ap_tgt_supplier_name, apss_tgt.vendor_site_code ap_tgt_supplier_site,
                              ai_tgt.invoice_num ap_tgt_inv_num_tgt, TO_CHAR (ai_tgt.invoice_date, 'DD-MON-YYYY') ap_tgt_inv_date, ai_tgt.invoice_amount ap_tgt_inv_amt_tgt,
                              ai_tgt.amount_paid ap_tgt_inv_amount_paid, (NVL (ai_tgt.invoice_amount, 0) - NVL (ai_tgt.amount_paid, 0)) ap_tgt_inv_amount_remaining, hou_ap_tgt.NAME ap_tgt_inv_operating_unit
                FROM apps.ap_invoices_all aia, apps.ap_suppliers aps, apps.ap_supplier_sites_all apss,
                     apps.ap_invoices_all ai_tgt, apps.ap_invoice_lines_all ail_tgt, apps.ra_customer_trx_all rct,
                     apps.ra_customer_trx_lines_all rctl, apps.ar_payment_schedules_all sched, apps.hr_operating_units hou_ar,
                     apps.hr_operating_units hou_ap_tgt, apps.hz_cust_accounts hca, apps.hz_parties hp,
                     apps.ap_suppliers aps_tgt, apps.ap_supplier_sites_all apss_tgt
               WHERE     1 = 1
                     AND aia.vendor_id = aps.vendor_id
                     AND aia.vendor_site_id = apss.vendor_site_id
                     AND aia.org_id = apss.org_id
                     AND aps.vendor_type_lookup_code = 'MANUFACTURER'
                     AND NVL (aia.attribute9, 'N') = 'Y'
                     AND TO_CHAR (aia.invoice_id) = ail_tgt.attribute3
                     AND ail_tgt.invoice_id = ai_tgt.invoice_id
                     AND TO_CHAR (aia.invoice_id) = rctl.attribute13
                     AND rctl.customer_trx_id = rct.customer_trx_id
                     AND sched.org_id = rct.org_id
                     AND sched.customer_trx_id = rct.customer_trx_id
                     AND sched.status = 'OP'
                     AND sched.customer_id = rct.bill_to_customer_id
                     AND sched.CLASS = 'INV'
                     AND NVL (sched.amount_due_remaining, '0') <> 0
                     AND TRUNC (SYSDATE) - TRUNC (rct.trx_date) >= 60
                     --Need to uncomment this condition
                     AND rct.org_id = hou_ar.organization_id
                     AND ai_tgt.org_id = hou_ap_tgt.organization_id
                     AND rct.bill_to_customer_id = hca.cust_account_id
                     AND hca.party_id = hp.party_id
                     AND ai_tgt.vendor_id = aps_tgt.vendor_id
                     AND ai_tgt.vendor_site_id = apss_tgt.vendor_site_id
                     AND ai_tgt.org_id = apss_tgt.org_id
                     AND aia.org_id = cn_ou_org
            -- AND aia.invoice_id = 77984222--Comment this line
            ORDER BY comm_ar_inv_num, ap_tgt_inv_num_tgt;

        ex_no_recips        EXCEPTION;
        ex_validation_err   EXCEPTION;
        ex_no_data_found    EXCEPTION;

        TYPE no_comm_inv_t IS TABLE OF no_comm_inv%ROWTYPE
            INDEX BY BINARY_INTEGER;

        no_comm_inv_tbl     no_comm_inv_t;
        lv_org_code         VARCHAR2 (240);
        --lv_email_str VARCHAR2(100);
        --lv_str VARCHAR2(20):='@DECKERS.COM';
        ln_cnt              NUMBER := 1;
    BEGIN
        BEGIN
            SELECT hrou.NAME
              INTO lv_org_code
              FROM apps.hr_operating_units hrou
             WHERE organization_id = pn_ou_org;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_org_code   := NULL;
        END;

        v_def_mail_recips   :=
            apps.xxdoap_commissions_pkg.get_email_recips (
                'XXDOAP_COMMISSIONS_DIST_LIST');
        apps.XXDOAP_COMMISSIONS_PKG.send_mail_header (apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_def_mail_recips, 'Commission Alert - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS')
                                                      , l_ret_val);
        apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (
            'Content-Type: multipart/mixed; boundary=boundarystring',
            l_ret_val);
        apps.XXDOAP_COMMISSIONS_PKG.send_mail_line ('--boundarystring',
                                                    l_ret_val);
        apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (
            'Content-Type: text/plain',
            l_ret_val);
        apps.XXDOAP_COMMISSIONS_PKG.send_mail_line ('', l_ret_val);
        apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (
            'Organization - ' || lv_org_code,
            l_ret_val);
        --APPS.XXDOAP_COMMISSIONS_PKG.SEND_MAIL_LINE('Email - '||p_email, l_ret_val);
        --APPS.XXDOAP_COMMISSIONS_PKG.SEND_MAIL_LINE('Cut Off Date - '||pd_cut_off_date, l_ret_val);
        apps.XXDOAP_COMMISSIONS_PKG.send_mail_line ('--boundarystring',
                                                    l_ret_val);
        apps.XXDOAP_COMMISSIONS_PKG.send_mail_line ('Content-Type: text/xls',
                                                    l_ret_val);
        apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (
            'Content-Disposition: attachment; filename="Commission Alert.xls"',
            l_ret_val);
        apps.XXDOAP_COMMISSIONS_PKG.send_mail_line ('', l_ret_val);
        apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (
               'AR Commission Customer Name'
            || CHR (9)
            || 'AR Commission Number'
            || CHR (9)
            || 'AR Commission Amount'
            || CHR (9)
            || 'AR Commission Date'
            || CHR (9)
            || 'AR Commission Amount Paid'
            || CHR (9)
            || 'AR Commission Remaining Balance'
            || CHR (9)
            || 'AR Commission OU'
            || CHR (9)
            || 'AP Commission Vendor Name'
            || CHR (9)
            || 'AP Commission Vendor Site'
            || CHR (9)
            || 'AP Commission Number'
            || CHR (9)
            || 'AP Commission Amount'
            || CHR (9)
            || 'AP Commission Date'
            || CHR (9)
            || 'AP Commission Amount Paid'
            || CHR (9)
            || 'AP Commission Remaining Balance'
            || CHR (9)
            || 'AP Commission OU',
            l_ret_val);

        -- DBMS_OUTPUT.put_line ('Before Loop');
        FOR no_comm_inv_rec IN no_comm_inv (pn_ou_org)
        LOOP
            l_counter    := l_counter + 1;
            --print_line('L','Inside Loop: ' || l_counter);
            v_out_line   := NULL;
            v_out_line   :=
                   no_comm_inv_rec.comm_ar_customer_name
                --'AR Commission Customer Name'
                || CHR (9)
                || no_comm_inv_rec.comm_ar_inv_num    --'AR Commission Number'
                || CHR (9)
                || no_comm_inv_rec.comm_ar_inv_amount --'AR Commission Amount'
                || CHR (9)
                || no_comm_inv_rec.comm_ar_inv_date     --'AR Commission Date'
                || CHR (9)
                || NVL (no_comm_inv_rec.comm_ar_inv_amt_paid, 0)
                --'AR Commission Amount Paid'
                || CHR (9)
                || NVL (no_comm_inv_rec.comm_ar_inv_amt_remaining, 0)
                --'AR Commission Remaining Balance'
                || CHR (9)
                || no_comm_inv_rec.comm_ar_inv_operating_unit --'AR Commission OU'
                || CHR (9)
                || no_comm_inv_rec.ap_tgt_supplier_name
                --'AP Commission Vendor Name'
                || CHR (9)
                || no_comm_inv_rec.ap_tgt_supplier_site
                --'AP Commission Vendor Site'
                || CHR (9)
                || no_comm_inv_rec.ap_tgt_inv_num_tgt --'AP Commission Number'
                || CHR (9)
                || no_comm_inv_rec.ap_tgt_inv_amt_tgt --'AP Commission Amount'
                || CHR (9)
                || no_comm_inv_rec.ap_tgt_inv_date      --'AP Commission Date'
                || CHR (9)
                || NVL (no_comm_inv_rec.ap_tgt_inv_amount_paid, 0)
                --'AP Commission Amount Paid'
                || CHR (9)
                || NVL (no_comm_inv_rec.ap_tgt_inv_amount_remaining, 0)
                --'AP Commission Remaining Balance'
                || CHR (9)
                || no_comm_inv_rec.ap_tgt_inv_operating_unit --'AP Commission OU'
                || CHR (9);
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (v_out_line,
                                                        l_ret_val);
            l_counter    := l_counter + 1;
        END LOOP;

        -- DBMS_OUTPUT.put_line ('After Loop');
        apps.XXDOAP_COMMISSIONS_PKG.send_mail_close (l_ret_val);
        ln_cnt   := ln_cnt + 1;

        IF l_counter = 0
        THEN
            RAISE ex_no_data_found;
        END IF;
    EXCEPTION
        WHEN ex_no_data_found
        THEN
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_header (apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_def_mail_recips, 'Commssion Alert - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS')
                                                          , l_ret_val);
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                l_ret_val);
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_line ('--boundarystring',
                                                        l_ret_val);
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (
                'Content-Type: text/plain',
                l_ret_val);
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_line ('', l_ret_val);
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (' ', l_ret_val);
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (
                '*******No Eligible Records for this Request*********.',
                l_ret_val);
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (' ', l_ret_val);
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (
                'Request id -' || apps.xxdoap_commissions_pkg.g_conc_request_id,
                l_ret_val);
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_line (
                'Organization Code -' || lv_org_code,
                l_ret_val);
            -- APPS.XXDOAP_COMMISSIONS_PKG.SEND_MAIL_LINE('--boundarystring', l_ret_val);
            -- APPS.XXDOAP_COMMISSIONS_PKG.SEND_MAIL_LINE('Content-Type: text/xls', l_ret_val);
            -- APPS.XXDOAP_COMMISSIONS_PKG.SEND_MAIL_LINE('Content-Disposition: attachment; filename="Open Pick Details.xls"', l_ret_val);
            -- APPS.XXDOAP_COMMISSIONS_PKG.SEND_MAIL_LINE('', l_ret_val);
            -- APPS.XXDOAP_COMMISSIONS_PKG.SEND_MAIL_LINE('No Eligible records for this request', l_ret_val);
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_close (l_ret_val); --Be Safe
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '*************** No Eligible Records at this Request *******************');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
        WHEN ex_validation_err
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '*************** Invalid Email format *******************');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
            retcode   := 1;
        WHEN OTHERS
        THEN
            --print_line('L','When others Exception: '||SQLERRM);
            apps.XXDOAP_COMMISSIONS_PKG.send_mail_close (l_ret_val); --Be Safe
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '-----------------------------------------------------------------------');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   '******** Exception Occured while submitting the Request'
                || SQLERRM);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                '----------------------------------------------------------------------------');
    END commission_alert;

    --Start Changes V2.1

    PROCEDURE proc_update_target_ap_ou (
        p_src_org_id           IN     NUMBER,
        p_src_trx_type         IN     VARCHAR2,
        p_src_trx_dt_from      IN     DATE,
        p_src_trx_dt_to        IN     DATE,
        p_src_invoice_id       IN     NUMBER DEFAULT NULL,
        p_src_vendor_id        IN     NUMBER DEFAULT NULL,
        p_src_vendor_site_id   IN     NUMBER DEFAULT NULL,
        p_gl_date_from         IN     VARCHAR2,               -- Added for 1.2
        p_gl_date_to           IN     VARCHAR2,               -- Added for 1.2
        x_ret_code                OUT VARCHAR2,
        x_ret_message             OUT VARCHAR2)
    IS
        ln_row_count   NUMBER;
    BEGIN
        UPDATE ap_invoices_all aia_parent
           SET global_attribute1   =
                   (SELECT DISTINCT
                           xxd_commissn_get_target_ap_ou (aia.invoice_id, aia.org_id) target_ap_org_id
                      FROM ap_invoices_all aia, ap_suppliers aps, ap_supplier_sites_all apss,
                           hr_operating_units hou, ap_invoice_lines_all aila1, apps.ap_invoice_distributions_all aida1
                     WHERE     1 = 1
                           AND aia.vendor_id = aps.vendor_id
                           AND aia.vendor_site_id = apss.vendor_site_id
                           AND aia.org_id = apss.org_id
                           AND aia.org_id = hou.organization_id
                           AND aps.vendor_type_lookup_code = 'MANUFACTURER'
                           AND aia.org_id = p_src_org_id
                           AND aia.vendor_id =
                               NVL (p_src_vendor_id, aia.vendor_id)
                           AND aia.vendor_site_id =
                               NVL (p_src_vendor_site_id, aia.vendor_site_id)
                           AND aia.invoice_id =
                               NVL (p_src_invoice_id, aia.invoice_id)
                           AND aia_parent.invoice_id = aia.invoice_id
                           AND aia.invoice_date >=
                               NVL (p_src_trx_dt_from, aia.invoice_date)
                           AND aia.invoice_date <
                               NVL (p_src_trx_dt_to, aia.invoice_date) + 1
                           AND aia.invoice_id = aila1.invoice_id -- Added for v1.3
                           AND aida1.invoice_id = aia.invoice_id -- Added for v1.3
                           AND aila1.line_number = aida1.invoice_line_number -- Added for v1.3
                           AND aida1.ACCOUNTING_DATE BETWEEN NVL (
                                                                 TO_DATE (
                                                                     p_gl_date_from),
                                                                 aida1.ACCOUNTING_DATE)
                                                         AND NVL (
                                                                 TO_DATE (
                                                                     p_gl_date_to),
                                                                 aida1.ACCOUNTING_DATE)
                           --Pick Invoice type 'CREDIT','STANDARD','MIXED' when source type 'BOTH'
                           AND ((aia.invoice_type_lookup_code IN ('CREDIT', 'STANDARD', 'MIXED') AND p_src_trx_type = 'BOTH') --Pick Invoice type 'CREDIT' when source type 'CREDIT'
                                                                                                                              OR (aia.invoice_type_lookup_code = ('CREDIT') AND p_src_trx_type = 'CREDIT') --Pick Invoice type 'STANDARD','MIXED' when source type 'INVOICE'
                                                                                                                                                                                                           OR (aia.invoice_type_lookup_code IN ('STANDARD', 'MIXED') AND p_src_trx_type = 'INVOICE'))
                           AND NVL (aia.attribute9, 'N') = 'N' --Commissions created DFF
                           --IF source type INV/CREDIT invoice creation date must be >= cutoffdate
                           /* -- Start Changes V2.1 *** IMP****Commented as we would not be getting the Trx Cut Off Date and Relation Trx Type
                           AND DECODE (xxdoap_commissions_pkg.g_relation_trx_type,
                                       'INV/CREDIT', aia.creation_date,
                                       xxdoap_commissions_pkg.g_trx_cutoff_date) >=
                                  xxdoap_commissions_pkg.g_trx_cutoff_date
                           --IF source type 'PO' then pick only PO linked invoices with PO Line creation date >= cutoffdate
                           AND DECODE (xxdoap_commissions_pkg.g_relation_trx_type,
                                       'PO', get_po_line_creation_dt (aia.invoice_id),
                                       xxdoap_commissions_pkg.g_trx_cutoff_date) >=
                                  xxdoap_commissions_pkg.g_trx_cutoff_date*/
                           --                 End Changes V2.1 *** IMP****Commented as we would not be getting the Trx Cut Off Date and Relation Trx Type
                           --Check if transaction type excluded at supplier level
                           AND xxdoap_commissions_pkg.get_vendor_exclusion (
                                   aia.vendor_id,
                                   aia.invoice_type_lookup_code) =
                               'N'
                           --Check if transaction type excluded at site level
                           AND xxdoap_commissions_pkg.get_ven_site_exclusion (
                                   aia.vendor_site_id,
                                   aia.invoice_type_lookup_code) =
                               'N'      --Validate and Accounted invoices only
                                  --                  AND ap_invoices_pkg.get_posting_status (aia.invoice_id) = 'Y'
                                  )
         WHERE EXISTS
                   (SELECT 1
                      FROM ap_invoices_all aia, ap_suppliers aps, ap_supplier_sites_all apss,
                           hr_operating_units hou, ap_invoice_lines_all aila1, apps.ap_invoice_distributions_all aida1
                     WHERE     1 = 1
                           AND aia.vendor_id = aps.vendor_id
                           AND aia.vendor_site_id = apss.vendor_site_id
                           AND aia.org_id = apss.org_id
                           AND aia.org_id = hou.organization_id
                           AND aps.vendor_type_lookup_code = 'MANUFACTURER'
                           AND aia.org_id = p_src_org_id
                           AND aia.vendor_id =
                               NVL (p_src_vendor_id, aia.vendor_id)
                           AND aia.vendor_site_id =
                               NVL (p_src_vendor_site_id, aia.vendor_site_id)
                           AND aia.invoice_id =
                               NVL (p_src_invoice_id, aia.invoice_id)
                           AND aia_parent.invoice_id = aia.invoice_id
                           AND aia.invoice_date >=
                               NVL (p_src_trx_dt_from, aia.invoice_date)
                           AND aia.invoice_date <
                               NVL (p_src_trx_dt_to, aia.invoice_date) + 1
                           AND aia.invoice_id = aila1.invoice_id -- Added for v1.3
                           AND aida1.invoice_id = aia.invoice_id -- Added for v1.3
                           AND aila1.line_number = aida1.invoice_line_number -- Added for v1.3
                           AND aida1.ACCOUNTING_DATE BETWEEN NVL (
                                                                 TO_DATE (
                                                                     p_gl_date_from),
                                                                 aida1.ACCOUNTING_DATE)
                                                         AND NVL (
                                                                 TO_DATE (
                                                                     p_gl_date_to),
                                                                 aida1.ACCOUNTING_DATE)
                           --Pick Invoice type 'CREDIT','STANDARD','MIXED' when source type 'BOTH'
                           AND ((aia.invoice_type_lookup_code IN ('CREDIT', 'STANDARD', 'MIXED') AND p_src_trx_type = 'BOTH') --Pick Invoice type 'CREDIT' when source type 'CREDIT'
                                                                                                                              OR (aia.invoice_type_lookup_code = ('CREDIT') AND p_src_trx_type = 'CREDIT') --Pick Invoice type 'STANDARD','MIXED' when source type 'INVOICE'
                                                                                                                                                                                                           OR (aia.invoice_type_lookup_code IN ('STANDARD', 'MIXED') AND p_src_trx_type = 'INVOICE'))
                           AND NVL (aia.attribute9, 'N') = 'N' --Commissions created DFF
                           --IF source type INV/CREDIT invoice creation date must be >= cutoffdate
                           /* -- Start Changes V2.1 *** IMP****Commented as we would not be getting the Trx Cut Off Date and Relation Trx Type
                           AND DECODE (xxdoap_commissions_pkg.g_relation_trx_type,
                                       'INV/CREDIT', aia.creation_date,
                                       xxdoap_commissions_pkg.g_trx_cutoff_date) >=
                                  xxdoap_commissions_pkg.g_trx_cutoff_date
                           --IF source type 'PO' then pick only PO linked invoices with PO Line creation date >= cutoffdate
                           AND DECODE (xxdoap_commissions_pkg.g_relation_trx_type,
                                       'PO', get_po_line_creation_dt (aia.invoice_id),
                                       xxdoap_commissions_pkg.g_trx_cutoff_date) >=
                                  xxdoap_commissions_pkg.g_trx_cutoff_date*/
                           --                 End Changes V2.1 *** IMP****Commented as we would not be getting the Trx Cut Off Date and Relation Trx Type
                           --Check if transaction type excluded at supplier level
                           AND xxdoap_commissions_pkg.get_vendor_exclusion (
                                   aia.vendor_id,
                                   aia.invoice_type_lookup_code) =
                               'N'
                           --Check if transaction type excluded at site level
                           AND xxdoap_commissions_pkg.get_ven_site_exclusion (
                                   aia.vendor_site_id,
                                   aia.invoice_type_lookup_code) =
                               'N'      --Validate and Accounted invoices only
                                  --                  AND ap_invoices_pkg.get_posting_status (aia.invoice_id) = 'Y'
                                  );

        ln_row_count   := SQL%ROWCOUNT;
        COMMIT;
        print_line (
            'L',
               'Total Number of rows updated for Global Attribute1 - '
            || ln_row_count);
    EXCEPTION
        WHEN OTHERS
        THEN
            print_line (
                'L',
                'Error While Updating the Global Attribute1 - ' || SQLERRM);
    END;

    --End Changes V2.1

    PROCEDURE main (errbuf                 OUT VARCHAR2,
                    retcode                OUT VARCHAR2,
                    p_src_org_id        IN     NUMBER,
                    p_src_trx_type      IN     VARCHAR2,
                    p_src_trx_dt_from   IN     VARCHAR2,
                    p_src_trx_dt_to     IN     VARCHAR2,
                    p_src_trx_id        IN     NUMBER,
                    --Start Changes V2.1
                    --                   p_tgt_ar_org_id          IN     NUMBER,
                    --                   p_tgt_customer_id        IN     NUMBER,
                    --                   p_tgt_cust_site_use_id   IN     NUMBER,
                    --                   p_tgt_ap_org_id          IN     NUMBER,
                    --                   p_tgt_vendor_id          IN     NUMBER,
                    --                   p_tgt_ven_site_id        IN     NUMBER,
                    --End Changes V2.1
                    p_src_vendor_id     IN     NUMBER DEFAULT NULL,
                    p_src_ven_site_id   IN     NUMBER DEFAULT NULL,
                    p_tgt_trx_date      IN     VARCHAR2,
                    p_gl_date_from      IN     VARCHAR2,      -- Added for 1.2
                    p_gl_date_to        IN     VARCHAR2)      -- Added for 1.2
    AS
        l_from_date                DATE;
        l_to_date                  DATE;
        l_ret_code                 VARCHAR2 (30);
        l_ret_msg                  VARCHAR2 (4000);
        ex_no_relation_found       EXCEPTION;
        ex_load_data               EXCEPTION;
        ex_period_not_open         EXCEPTION;
        ex_err_global_attribute1   EXCEPTION;
        ex_create_ar_trx           EXCEPTION;
        ex_create_ap_trx           EXCEPTION;
        ex_invalid_cust_setup      EXCEPTION;
        ex_invalid_supp_setup      EXCEPTION;
        ex_comm_perc_not_found     EXCEPTION;
        l_target_date              DATE;
        l_err_cnt                  NUMBER := 0;
        l_gl_date_from             DATE;                      -- Added for 1.2
        l_gl_date_to               DATE;                      -- Added for 1.2

        CURSOR cur_distinct_tgt_ap_ou (p_src_org_id NUMBER)
        IS
            SELECT DISTINCT global_attribute1
              FROM ap_invoices_all
             WHERE     1 = 1
                   AND global_attribute1 IS NOT NULL
                   AND NVL (attribute9, 'N') = 'N'
                   AND org_id = p_src_org_id    --AND global_attribute1 = '81'
                                            ;
    BEGIN
        l_from_date                                := TO_DATE (p_src_trx_dt_from, 'YYYY/MM/DD HH24:MI:SS');
        l_to_date                                  := TO_DATE (p_src_trx_dt_to, 'YYYY/MM/DD HH24:MI:SS');
        l_gl_date_from                             := TO_DATE (p_gl_date_from, 'YYYY/MM/DD HH24:MI:SS'); -- Added for 1.2
        l_gl_date_to                               := TO_DATE (p_gl_date_to, 'YYYY/MM/DD HH24:MI:SS'); -- Added for 1.2
        l_target_date                              := TO_DATE (p_tgt_trx_date, 'YYYY/MM/DD HH24:MI:SS');
        xxdoap_commissions_pkg.g_source_org_id     := p_src_org_id;
        xxdoap_commissions_pkg.g_source_trx_type   := p_src_trx_type;
        --Start Changes V2.1
        --      xxdoap_commissions_pkg.g_target_ap_org_id := p_tgt_ap_org_id;
        --      xxdoap_commissions_pkg.g_target_ar_org_id := p_tgt_ar_org_id;
        --      xxdoap_commissions_pkg.g_target_customer_id := p_tgt_customer_id;
        --      xxdoap_commissions_pkg.g_target_cust_site_use_id :=
        --         p_tgt_cust_site_use_id;
        --      xxdoap_commissions_pkg.g_target_vendor_id := p_tgt_vendor_id;
        --      xxdoap_commissions_pkg.g_target_vendor_site_id := p_tgt_ven_site_id;
        proc_update_target_ap_ou (p_src_org_id, p_src_trx_type, l_from_date,
                                  l_to_date, p_src_trx_id, p_src_vendor_id,
                                  p_src_ven_site_id, l_gl_date_from, l_gl_date_to
                                  , l_ret_code, l_ret_msg);

        IF l_ret_code = '2'
        THEN
            RAISE ex_err_global_attribute1;
        END IF;

        FOR rec_distinct_tgt_ap_ou IN cur_distinct_tgt_ap_ou (p_src_org_id)
        LOOP
            get_relation_details (p_src_org_id => p_src_org_id, p_tgt_ap_org_id => rec_distinct_tgt_ap_ou.global_attribute1, --Start Changes V2.1
                                                                                                                             --p_tgt_ar_org_id   => p_tgt_ar_org_id,
                                                                                                                             --End Changes V2.1
                                                                                                                             x_ret_code => l_ret_code
                                  , x_ret_message => l_ret_msg);

            IF l_ret_code = '2'
            THEN
                RAISE ex_no_relation_found;
            END IF;

            --End Changes V2.1
            xxdoap_commissions_pkg.g_target_date   :=
                TO_DATE (p_tgt_trx_date, 'YYYY/MM/DD HH24:MI:SS');
            xxdoap_commissions_pkg.g_target_customer_site_id   :=
                get_tgt_cust_site_id;
            xxdoap_commissions_pkg.g_target_ap_sob_id   :=
                get_target_sob (xxdoap_commissions_pkg.g_target_ap_org_id);
            xxdoap_commissions_pkg.g_target_ar_sob_id   :=
                get_target_sob (xxdoap_commissions_pkg.g_target_ar_org_id);
            print_line (
                'L',
                'p_src_org_id:' || xxdoap_commissions_pkg.g_source_org_id);
            print_line (
                'L',
                'p_tgt_ap_org_id:' || xxdoap_commissions_pkg.g_target_ap_org_id);
            print_line (
                'L',
                'p_tgt_ar_org_id:' || xxdoap_commissions_pkg.g_target_ar_org_id);
            print_line (
                'L',
                'p_src_trx_type:' || xxdoap_commissions_pkg.g_source_trx_type);
            print_line (
                'L',
                'p_tgt_customer_id:' || xxdoap_commissions_pkg.g_target_customer_id);
            print_line (
                'L',
                'p_tgt_cust_site_use_id:' || xxdoap_commissions_pkg.g_target_cust_site_use_id);
            print_line (
                'L',
                'p_tgt_vendor_id:' || xxdoap_commissions_pkg.g_target_vendor_id);
            print_line (
                'L',
                'p_tgt_ven_site_id:' || xxdoap_commissions_pkg.g_target_vendor_site_id);
            print_line (
                'L',
                'p_tgt_trx_date:' || xxdoap_commissions_pkg.g_target_date);
            get_target_details (
                x_target_ar_org_name   =>
                    xxdoap_commissions_pkg.g_target_ar_org_name,
                x_target_ap_org_name   =>
                    xxdoap_commissions_pkg.g_target_ap_org_name,
                x_customer_name   =>
                    xxdoap_commissions_pkg.g_target_ar_customer   --l_customer
                                                               ,
                x_customer_number   =>
                    xxdoap_commissions_pkg.g_target_ar_cust_num --l_customer_num
                                                               ,
                x_tgt_vendor_name   =>
                    xxdoap_commissions_pkg.g_target_ap_vendor       --l_vendor
                                                             ,
                x_tgt_site_code   =>
                    xxdoap_commissions_pkg.g_target_ap_vendor_site --l_vendor_site
                                                                  );

            IF check_open_period (l_target_date)
            THEN
                NULL;
            ELSE
                l_ret_msg   := 'Target Date not in open period.';
                RAISE ex_period_not_open;
            END IF;

            --Start Chagnes V2.1 -- Commented and moved up to begining of the code
            --      --Get Source-Target Relationship details
            --      get_relation_details (p_src_org_id      => p_src_org_id,
            --                            p_tgt_ap_org_id   => p_tgt_ap_org_id,
            --                            p_tgt_ar_org_id   => p_tgt_ar_org_id,
            --                            x_ret_code        => l_ret_code,
            --                            x_ret_message     => l_ret_msg);
            --
            --      IF l_ret_code = '2'
            --      THEN
            --         RAISE ex_no_relation_found;
            --      END IF;
            --End Changes V2.1



            --Check if target customer setup is valid
            IF is_cust_site_setup (p_site_use_id => xxdoap_commissions_pkg.g_target_cust_site_use_id, x_term_id => xxdoap_commissions_pkg.g_target_ar_terms_id, x_rev_acc_id => xxdoap_commissions_pkg.g_target_ar_rev_acc_id --,x_rec_acc_id => xxdoap_commissions_pkg.G_TARGET_AR_REC_ACC_ID
                                   , x_ret_message => l_ret_msg) = 'N'
            THEN
                RAISE ex_invalid_cust_setup;
            END IF;

            --Check if target supplier site setup is valid
            IF is_supp_site_setup (
                   p_supp_site_id     =>
                       xxdoap_commissions_pkg.g_target_vendor_site_id,
                   x_term_id          => xxdoap_commissions_pkg.g_target_ap_terms_id,
                   x_pay_method_code   =>
                       xxdoap_commissions_pkg.g_target_ap_pay_method,
                   x_dist_set_id      =>
                       xxdoap_commissions_pkg.g_target_ap_dist_set_id,
                   x_ship_to_loc_id   =>
                       xxdoap_commissions_pkg.g_target_ap_ship_loc_id,
                   x_ret_message      => l_ret_msg) =
               'N'
            THEN
                RAISE ex_invalid_supp_setup;
            END IF;

            --Load Source Invoice details into staging table
            load_src_trx (p_src_org_id           => p_src_org_id,
                          p_src_trx_type         => p_src_trx_type,
                          p_src_trx_dt_from      => l_from_date,
                          p_src_trx_dt_to        => l_to_date,
                          p_src_invoice_id       => p_src_trx_id,
                          p_src_vendor_id        => p_src_vendor_id,
                          p_src_vendor_site_id   => p_src_ven_site_id,
                          p_gl_date_from         => l_gl_date_from, -- Added for 1.2
                          p_gl_date_to           => l_gl_date_to, -- Added for 1.2
                          x_ret_code             => l_ret_code,
                          x_ret_message          => l_ret_msg);

            IF l_ret_code != '0'
            THEN
                RAISE ex_load_data;
            END IF;

            validate_staging;

            SELECT COUNT (1)
              INTO l_err_cnt
              FROM xxdo.xxdoap_commissions_stg
             WHERE     request_id = xxdoap_commissions_pkg.g_conc_request_id
                   AND process_flag = 'E'
                   AND current_status_flag = 'F'             -- Added for v1.3
                                                ;

            IF l_err_cnt > 0
            THEN
                RAISE ex_comm_perc_not_found;
            END IF;

            create_target_ar_trx (l_ret_code, l_ret_msg);

            IF l_ret_code = '2'
            THEN
                RAISE ex_load_data;
            END IF;

            create_target_ap_trx (l_ret_code, l_ret_msg);

            IF l_ret_code = '2'
            THEN
                RAISE ex_load_data;
            END IF;
        END LOOP;

        print_output;
    EXCEPTION
        WHEN ex_err_global_attribute1
        THEN
            l_ret_msg   := 'Error While Updating Target AP OU';
        WHEN ex_comm_perc_not_found
        THEN
            l_ret_msg   :=
                'Commission percentage not found in some or all of dates in the given date range.';
            print_line ('L', l_ret_msg);
            retcode   := '2';
            errbuf    := SUBSTR (l_ret_msg, 1, 240);
        WHEN ex_invalid_cust_setup
        THEN
            print_line ('L', l_ret_msg);
            retcode   := '2';
            errbuf    := SUBSTR (l_ret_msg, 1, 240);
        WHEN ex_invalid_supp_setup
        THEN
            print_line ('L', l_ret_msg);
            retcode   := '2';
            errbuf    := SUBSTR (l_ret_msg, 1, 240);
        WHEN ex_create_ap_trx
        THEN
            print_line ('L', l_ret_msg);
            retcode   := '2';
            errbuf    := SUBSTR (l_ret_msg, 1, 240);
        WHEN ex_create_ar_trx
        THEN
            print_line ('L', l_ret_msg);
            retcode   := '2';
            errbuf    := SUBSTR (l_ret_msg, 1, 240);
        WHEN ex_period_not_open
        THEN
            print_line ('L', l_ret_msg);
            retcode   := '2';
            errbuf    := SUBSTR (l_ret_msg, 1, 240);
        WHEN ex_load_data
        THEN
            print_line ('L', l_ret_msg);
            retcode   := '1';
            errbuf    := SUBSTR (l_ret_msg, 1, 240);
        WHEN ex_no_relation_found
        THEN
            print_line ('L', l_ret_msg);
            retcode   := '2';
            errbuf    := SUBSTR (l_ret_msg, 1, 240);
        WHEN OTHERS
        THEN
            print_line ('L', 'Error in main:' || SQLERRM);
            retcode   := '2';
            errbuf    := SUBSTR ('Error in main:' || SQLERRM, 1, 240);
            NULL;
    END main;
END XXDOAP_COMMISSIONS_PKG;
/
