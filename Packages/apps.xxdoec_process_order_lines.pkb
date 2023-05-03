--
-- XXDOEC_PROCESS_ORDER_LINES  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_PROCESS_ORDER_LINES"
AS
    /******************************************************************************************************
    * Program Name : XXDOEC_PROCESS_ORDER_LINES
    * Description  :
    *
    * History      :
    *
    * ===============================================================================
    * Who                   Version    Comments                          When
    * ===============================================================================
    * BT Technology Team    1.1        Updated for BT                         05-JAN-2015
    * BT Technology Team    1.2        INFOSYS                                CCR0004339 - EBS changes for?eCommerce?Loyalty program.
    * Bala Murugesan        1.3        Modified to derive the shipment        03-Nov-2016
    *                                  method from order lines for the orders
    *                                  which are booked but dont have WDD;
    *                                  Identified by PRIORITY_SHIPMENT
    * Sivakumar Boothathan  1.4        Modified update toi record the system date ands time 11/10/2016
    * Vijay Reddy           1.5        Exclude EXTRENAL sourced order lines from cancellation CCR0006703
    * Infosys               1.6        Changes to invoice and order freight amount derivation logic as part of CCR0006807
    * Keith Copeland        1.7        Modified for Japan to include COD Charge details
    * Keith Copeland        1.8        Modified to pass the line_group_id in the line cursor within get_line_groups_to_process_orn
    * Vijay Reddy           1.9        Modified get_line_groups_to_process_orn split shipment logic  19-DEC-2018 - CCR0007741
    * Vijay Reddy           2.0        Modified get_orig_pgc_trans_num_by_line 30-AUG-2019  - CCR0008194
    ******************************************************************************************************/

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100, p_runnum NUMBER:= -1
                   , p_header_id NUMBER:= -1, p_category VARCHAR2:= 'I')
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, MESSAGE);

        INSERT INTO xxdo.xxdoec_process_order_log
                 VALUES (xxdo.xxdoec_seq_process_order.NEXTVAL,
                         MESSAGE,
                         CURRENT_TIMESTAMP);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END msg;

    PROCEDURE get_receipt_method (p_receipt_class_id IN NUMBER, p_do_pmt_type IN VARCHAR2, p_website_id IN VARCHAR2, p_currency_code IN VARCHAR2, x_receipt_method_id OUT NUMBER, x_bank_account_id OUT NUMBER
                                  , x_bank_branch_id OUT NUMBER)
    IS
        CURSOR c_receipt_method (c_receipt_class_id IN NUMBER, c_do_pmt_type IN VARCHAR2, c_website_id IN VARCHAR2
                                 , c_currency_code IN VARCHAR2)
        IS
            SELECT arm.receipt_method_id, bau.bank_account_id, cba.bank_branch_id
              FROM ar_receipt_methods arm, ar_receipt_method_accounts_all arma, ce_bank_acct_uses_all bau,
                   ce_bank_accounts cba
             WHERE     arm.receipt_class_id = c_receipt_class_id
                   AND arm.attribute2 = c_do_pmt_type
                   AND NVL (arm.attribute4, 'N') = 'N'
                   AND NVL (arm.attribute1, c_website_id) = c_website_id
                   AND SYSDATE BETWEEN NVL (arm.start_date, SYSDATE)
                                   AND NVL (arm.end_date, SYSDATE)
                   AND arma.receipt_method_id = arm.receipt_method_id
                   AND bau.bank_acct_use_id = arma.remit_bank_acct_use_id
                   AND cba.bank_account_id = bau.bank_account_id
                   AND NVL (cba.currency_code, c_currency_code) =
                       c_currency_code
                   AND cba.account_classification = 'INTERNAL';
    BEGIN
        OPEN c_receipt_method (p_receipt_class_id, p_do_pmt_type, p_website_id
                               , p_currency_code);

        FETCH c_receipt_method INTO x_receipt_method_id, x_bank_account_id, x_bank_branch_id;

        IF c_receipt_method%NOTFOUND
        THEN
            CLOSE c_receipt_method;

            x_receipt_method_id   := NULL;
            x_bank_account_id     := NULL;
            x_bank_branch_id      := NULL;
        ELSE
            CLOSE c_receipt_method;
        END IF;
    END get_receipt_method;


    PROCEDURE set_email_ctr_value (p_header_id      IN     NUMBER,
                                   p_line_grp_id    IN     VARCHAR2,
                                   p_ctr_value      IN     NUMBER,
                                   x_rtn_status        OUT VARCHAR2,
                                   x_rtn_msg_data      OUT VARCHAR2)
    AS
        CURSOR c_order_lines IS
            SELECT line_id
              FROM oe_order_lines_all
             WHERE header_id = p_header_id AND attribute18 = p_line_grp_id;
    BEGIN
        x_rtn_status   := fnd_api.g_ret_sts_success;

        FOR c_lines IN c_order_lines
        LOOP
            BEGIN
                wf_engine.setitemattrnumber (itemtype => 'OEOL', itemkey => TO_CHAR (c_lines.line_id), aname => 'XXDOEC_EMAIL_RETRY_COUNTER'
                                             , avalue => p_ctr_value);
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_rtn_status   := fnd_api.g_ret_sts_error;
                    x_rtn_msg_data   :=
                           x_rtn_msg_data
                        || ' Unable to update counter value for Line ID: '
                        || TO_CHAR (c_lines.line_id)
                        || 'Error: '
                        || SQLERRM;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status   := fnd_api.g_ret_sts_unexp_error;
            x_rtn_msg_data   :=
                   ' Unable to update Email counter Value for Header ID: '
                || p_header_id
                || 'Line Group ID: '
                || p_line_grp_id
                || ' Error: '
                || SQLERRM;
    END set_email_ctr_value;

    FUNCTION get_email_ctr_value (p_header_id     IN NUMBER,
                                  p_line_grp_id   IN VARCHAR2)
        RETURN NUMBER
    AS
        l_ctr_value   NUMBER;
    BEGIN
        SELECT MIN (wf_engine.getitemattrnumber ('OEOL', TO_CHAR (ool.line_id), 'XXDOEC_EMAIL_RETRY_COUNTER'))
          INTO l_ctr_value
          FROM oe_order_lines_all ool
         WHERE header_id = p_header_id AND attribute18 = p_line_grp_id;

        RETURN (l_ctr_value);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN (NULL);
    END get_email_ctr_value;

    FUNCTION evaluate_all_exchanges (p_header_id   IN NUMBER,
                                     p_seq         IN NUMBER,
                                     p_runnum      IN NUMBER)
        RETURN NUMBER
    AS
        l_pgc       NUMBER := 0;
        l_chb       NUMBER := 0;
        l_pga       NUMBER := 0;
        l_total     NUMBER := 0;
        l_amount    NUMBER := 0;
        l_line_id   NUMBER := 0;
        l_cae       NUMBER := 0;
        l_err_num   NUMBER := -1;                             --error handling
        l_err_msg   VARCHAR2 (100) := '';                     --error handling
        l_message   VARCHAR2 (1000) := '';            --for message processing
        l_debug     NUMBER := 0;
        l_rc        NUMBER := 0;
        dcdlog      dcdlog_type
            := dcdlog_type (p_code => -10020, p_application => g_application, p_logeventtype => 2
                            , p_tracelevel => 1, p_debug => l_debug);
    BEGIN
        dcdlog.addparameter ('Run Number', TO_CHAR (p_runnum), 'NUMBER');

        SELECT NVL (COUNT (*), 0)
          INTO l_cae
          FROM oe_order_lines_all
         WHERE header_id = p_header_id AND cancelled_flag = 'Y';

        SELECT NVL (COUNT (*), 0)
          INTO l_total
          FROM oe_order_lines_all
         WHERE header_id = p_header_id;

        SELECT NVL (COUNT (*), 0)
          INTO l_pgc
          FROM bffevents
         WHERE header_id = p_header_id AND seq = p_seq AND code = 'PGC';

        SELECT NVL (COUNT (*), 0)
          INTO l_chb
          FROM bffevents
         WHERE header_id = p_header_id AND seq = p_seq AND code = 'CHB';

        SELECT NVL (COUNT (*), 0)
          INTO l_pga
          FROM bffevents
         WHERE header_id = p_header_id AND seq = p_seq AND code = 'PGA';

        IF (l_pga > 0)
        THEN
            -- If we have any PGA to process just send back the line id of the first one.
            SELECT MIN (line_id)
              INTO l_line_id
              FROM bffevents
             WHERE header_id = p_header_id AND seq = p_seq AND code = 'PGA';

            RETURN l_line_id;
        END IF;

        IF (l_pgc > 0) AND (l_chb > 0)
        THEN
            IF (l_total = ((l_pgc + l_chb) - l_cae))
            THEN
                -- if we have a PGC and  PGA and thats all we have
                -- determine balance, send back line_id of applicable one
                -- 9/15/2011 - make sure that the sum of lines to process = total lines
                -- minus any cancellations.
                SELECT NVL (
                           SUM (
                               CASE
                                   WHEN (p.category_code = 'RETURN')
                                   THEN
                                       (p.amount * -1)
                                   ELSE
                                       (p.amount)
                               END),
                           0) amount
                  INTO l_amount
                  FROM bffevents p
                 WHERE p.header_id = p_header_id AND p.seq = p_seq;

                IF (l_amount > 0)
                THEN
                    SELECT MIN (line_id)
                      INTO l_line_id
                      FROM bffevents
                     WHERE     header_id = p_header_id
                           AND seq = p_seq
                           AND code = 'PGC';
                END IF;

                IF (l_amount < 0)
                THEN
                    SELECT MIN (line_id)
                      INTO l_line_id
                      FROM bffevents
                     WHERE     header_id = p_header_id
                           AND seq = p_seq
                           AND code = 'CHB';
                END IF;

                IF (l_amount = 0)
                THEN
                    SELECT MIN (line_id)
                      INTO l_line_id
                      FROM bffevents
                     WHERE     header_id = p_header_id
                           AND seq = p_seq
                           AND code = 'PGC';
                END IF;

                RETURN l_line_id;
            END IF;
        END IF;

        IF ((((l_pgc > 0) OR (l_chb > 0)) AND (l_cae > 0)) AND ((l_total - l_cae) = (l_pgc + l_chb)))
        THEN
            -- So we have a PGC or a CHB waiting for the other line in the exchange to be ready.
            -- This will never happen if the other line is cancelled.  So we need to return the line
            -- that is waiting for this cancelled line.
            -- 9/15/2011 - Make sure the sum of lines to process = sum of all lines minus cancellations
            -- otherwise we may send through a line that needs to wait for another line to be ready so
            -- that it can be processed together (like a PGC and a CHB).
            l_line_id   := 0;
            --         MSG (
            --               p_header_id
            --            || 'l_pgc:  '
            --            || l_pgc
            --            || ' l_chb:  '
            --            || l_chb
            --            || ' l_cae:  '
            --            || l_cae
            --            || ' l_total:  '
            --            || l_total
            --            || '.');
            dcdlog.addparameter ('PGC count', TO_CHAR (l_pgc), 'NUMBER');
            dcdlog.addparameter ('CHB count', TO_CHAR (l_chb), 'NUMBER');
            dcdlog.addparameter ('CAE count', TO_CHAR (l_cae), 'NUMBER');
            l_rc        := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;

            IF l_pgc > 0 AND l_chb = 0
            THEN
                SELECT MIN (NVL (line_id, 0))
                  INTO l_line_id
                  FROM oe_order_lines_all
                 WHERE     header_id = p_header_id
                       AND attribute20 = 'PGC'
                       AND cancelled_flag <> 'Y';
            END IF;

            IF l_line_id = 0 AND l_pgc = 0 AND l_chb > 0
            THEN
                SELECT MIN (NVL (line_id, 0))
                  INTO l_line_id
                  FROM oe_order_lines_all
                 WHERE     header_id = p_header_id
                       AND attribute20 = 'CHB'
                       AND cancelled_flag <> 'Y';
            END IF;

            IF l_pgc > 0 AND l_chb > 0
            THEN
                -- if we have a PGC and  PGA and thats all we have
                -- determine balance, send back line_id of applicable one
                -- 9/15/2011 - make sure that the sum of lines to process = total lines
                -- minus any cancellations.
                SELECT NVL (
                           SUM (
                               CASE
                                   WHEN (p.category_code = 'RETURN')
                                   THEN
                                       (p.amount * -1)
                                   ELSE
                                       (p.amount)
                               END),
                           0) amount
                  INTO l_amount
                  FROM bffevents p
                 WHERE p.header_id = p_header_id AND p.seq = p_seq;

                IF (l_amount > 0)
                THEN
                    SELECT MIN (line_id)
                      INTO l_line_id
                      FROM bffevents
                     WHERE     header_id = p_header_id
                           AND seq = p_seq
                           AND code = 'PGC';
                END IF;

                IF (l_amount < 0)
                THEN
                    SELECT MIN (line_id)
                      INTO l_line_id
                      FROM bffevents
                     WHERE     header_id = p_header_id
                           AND seq = p_seq
                           AND code = 'CHB';
                END IF;

                IF (l_amount = 0)
                THEN
                    SELECT MIN (line_id)
                      INTO l_line_id
                      FROM bffevents
                     WHERE     header_id = p_header_id
                           AND seq = p_seq
                           AND code = 'PGC';
                END IF;
            END IF;

            IF l_line_id > 0
            THEN
                RETURN l_line_id;
            END IF;
        END IF;

        RETURN 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_err_num   := SQLCODE;
            l_err_msg   := SUBSTR (SQLERRM, 1, 100);
            l_message   := 'ERROR in evaluate_all_exchanges:  ' || SQLERRM;
            l_message   :=
                   l_message
                || ' err_num='
                || TO_CHAR (l_err_num)
                || ' err_msg='
                || l_err_msg
                || '.';
            msg (l_message);
            dcdlog.changecode (p_code => -10021, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => l_debug);
            dcdlog.addparameter ('SQLCODE', TO_CHAR (l_err_num), 'NUMBER');
            dcdlog.addparameter ('SQLERRM', l_err_msg, 'NUMBER');
            l_rc        := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;

            RETURN 0;
    END evaluate_all_exchanges;

    FUNCTION get_sequence (p_header_id IN NUMBER)
        RETURN NUMBER
    AS
        l_seq   NUMBER := 0;
    BEGIN
        SELECT NVL (MAX (seq), -1)
          INTO l_seq
          FROM bffevents
         WHERE header_id = p_header_id;

        RETURN l_seq + 1;
    END get_sequence;

    FUNCTION update_line_group_id (p_header_id   IN NUMBER,
                                   p_line_id     IN NUMBER := -1)
        RETURN NUMBER
    AS
        l_header_id           NUMBER := p_header_id;
        l_line_group_id_num   NUMBER := 0;
        l_line_group_id       VARCHAR2 (240) := '';
    BEGIN
        SELECT xxdo.xxdoec_order_lines_group_s.NEXTVAL
          INTO l_line_group_id_num
          FROM DUAL;

        l_line_group_id   := TO_CHAR (l_line_group_id_num);

        IF p_line_id <> -1
        THEN
            UPDATE oe_order_lines_all
               SET attribute18   = l_line_group_id
             --, attribute17 = 'P'   -- THIS WAS DONE IN THE INITIAL EVALUATION LOOP
             WHERE     header_id = l_header_id
                   AND attribute17 IN ('N', 'E') -- Only lines we should have picked.
                   AND line_id = p_line_id;
        -- Only do the line sent in.  This is only for
        -- PGA processing.  9/16/2011
        ELSE
            UPDATE oe_order_lines_all
               SET attribute18   = l_line_group_id
             --, attribute17 = 'P'   -- THIS WAS DONE IN THE INITIAL EVALUATION LOOP
             WHERE header_id = l_header_id AND attribute17 IN ('N', 'E');
        -- Only lines we should have picked.
        -- Avoid CAE cancel emails and such.
        END IF;

        RETURN l_line_group_id_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN (-1);
    END update_line_group_id;

    -- Public Procedures
    PROCEDURE cancel_line (p_line_id IN NUMBER, p_reason_code IN VARCHAR2, x_rtn_status OUT VARCHAR2
                           , x_rtn_msg_data OUT VARCHAR2)
    IS
        l_header_rec               oe_order_pub.header_rec_type
                                       := oe_order_pub.g_miss_header_rec;
        l_line_tbl                 oe_order_pub.line_tbl_type
                                       := oe_order_pub.g_miss_line_tbl;
        l_action_request_tbl       oe_order_pub.request_tbl_type
                                       := oe_order_pub.g_miss_request_tbl;
        --l_header_adj_tbl         oe_order_pub.header_adj_tbl_type := oe_order_pub.g_miss_header_adj_tbl;
        --l_line_adj_tbl           oe_order_pub.line_adj_tbl_type := oe_order_pub.g_miss_line_adj_tbl;
        --l_header_scr_tbl         oe_order_pub.header_scredit_tbl_type;
        --l_line_scredit_tbl       oe_order_pub.line_scredit_tbl_type;
        l_return_status            VARCHAR2 (1000);
        l_msg_count                NUMBER;
        l_msg_data                 VARCHAR2 (1000);
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
        l_line_tbl_index           NUMBER;
        l_msg_index_out            NUMBER;
        l_user_id                  NUMBER;
        l_resp_id                  NUMBER;
        l_resp_appl_id             NUMBER;
        l_org_id                   NUMBER;
        l_debug                    NUMBER := 0;
        l_rc                       NUMBER := 0;
        dcdlog                     dcdlog_type
            := dcdlog_type (p_code => -10023, p_application => g_application, p_logeventtype => 2
                            , p_tracelevel => 2, p_debug => l_debug);

        CURSOR c_order_line IS
            SELECT /*+ parallel(2) */
                   cbp.transaction_user_id, cbp.erp_login_resp_id, cbp.erp_login_app_id,
                   ool.org_id
              FROM xxdoec_country_brand_params cbp, apps.oe_order_lines_all ool, hz_cust_accounts hca
             WHERE     ool.line_id = p_line_id
                   AND hca.cust_account_id = ool.sold_to_org_id
                   AND cbp.website_id = hca.attribute18;
    BEGIN
        -- validate line_id
        OPEN c_order_line;

        FETCH c_order_line INTO l_user_id, l_resp_id, l_resp_appl_id, l_org_id;

        IF c_order_line%NOTFOUND
        THEN
            CLOSE c_order_line;

            x_rtn_status   := fnd_api.g_ret_sts_error;
            x_rtn_msg_data   :=
                p_line_id || ' is Not a Valid line Id to be Cancelled';
        ELSE
            CLOSE c_order_line;

            fnd_global.apps_initialize (l_user_id, l_resp_id, l_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', l_org_id);
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;
            -- X_DEBUG_FILE := OE_DEBUG_PUB.Set_Debug_Mode('FILE');
            -- oe_debug_pub.SetDebugLevel(5);
            l_line_tbl_index                                 := 1;
            -- Initialize record to missing
            l_line_tbl (l_line_tbl_index)                    := oe_order_pub.g_miss_line_rec;
            l_line_tbl (l_line_tbl_index).line_id            := p_line_id;
            l_line_tbl (l_line_tbl_index).ordered_quantity   := 0;
            l_line_tbl (l_line_tbl_index).cancelled_flag     := 'Y';
            l_line_tbl (l_line_tbl_index).change_reason      :=
                NVL (p_reason_code, 'Not provided');
            l_line_tbl (l_line_tbl_index).operation          :=
                oe_globals.g_opr_update;
            -- CALL to PROCESS ORDER
            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => l_return_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                -- OUT PARAMETERS
                x_header_rec               => l_header_rec,
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

            -- dbms_output.put_line('OM Debug file: '||oe_debug_pub.G_DIR||'/'||oe_debug_pub.G_FILE);
            -- Check the return status
            IF     l_return_status <> fnd_api.g_ret_sts_success
               AND l_msg_count > 0
            THEN
                -- Retrieve messages
                dcdlog.changecode (p_code => -10022, p_application => g_application, p_logeventtype => 1
                                   , p_tracelevel => 2, p_debug => l_debug);

                FOR i IN 1 .. l_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                    , p_msg_index_out => l_msg_index_out);
                    x_rtn_msg_data   :=
                        SUBSTR (x_rtn_msg_data || l_msg_data || CHR (13),
                                1,
                                2000);
                    msg ('Message' || l_msg_index_out || ': ' || l_msg_data);
                    dcdlog.addparameter ('Message index',
                                         TO_CHAR (l_msg_index_out),
                                         'NUMBER');
                    dcdlog.addparameter ('Error message',
                                         l_msg_data,
                                         'VARCHAR2');
                END LOOP;

                l_rc   := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;
            ELSE
                msg ('Cancel Order line Success: ' || p_line_id);
                dcdlog.changecode (p_code => -10023, p_application => g_application, p_logeventtype => 2
                                   , p_tracelevel => 2, p_debug => l_debug);
                dcdlog.addparameter ('line_id',
                                     TO_CHAR (p_line_id),
                                     'NUMBER');
                l_rc   := dcdlog.loginsert ();
                msg ('Return Status: ' || l_return_status);

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;
            END IF;

            x_rtn_status                                     :=
                l_return_status;
        END IF;                                    -- line_id validation check
    END cancel_line;

    PROCEDURE cancel_expired_lines (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, --      p_header_id      IN       NUMBER,                                       --Commented by BT Technology Team on 09-Feb-2015
                                                                                 p_order_number IN NUMBER
                                    , --Added by BT Technology Team on 09-Feb-2015
                                      p_order_source IN VARCHAR2 --Added by BT Technology Team on 09-FEB-2015
                                                                )
    IS
        l_status_code       VARCHAR2 (5);
        l_reason_code       VARCHAR2 (120) := 'LATE';
        -- Late and no longer needed
        l_rtn_status        VARCHAR2 (10);
        l_rtn_msg_data      VARCHAR2 (2000);
        l_sc_line_id        NUMBER;
        l_sc_order_number   NUMBER;
        l_return_line_id    NUMBER;
        l_debug             NUMBER := 0;
        l_rc                NUMBER := 0;
        l_header_id         NUMBER;
        dcdlog              dcdlog_type
            := dcdlog_type (p_code => -10024, p_application => g_application, p_logeventtype => 2
                            , p_tracelevel => 2, p_debug => l_debug);

        CURSOR c_expired_lines (p_header_id IN NUMBER)
        IS
            SELECT /*+ parallel(2) */
                   ool.line_id, ool.flow_status_code status_code, ool.latest_acceptable_date,
                   ott.attribute13 do_order_type, ool.header_id
              FROM oe_order_lines ool, oe_order_headers ooh, oe_transaction_types ott
             WHERE     ool.actual_shipment_date IS NULL
                   AND ool.open_flag = 'Y'
                   AND ool.line_category_code = 'ORDER'
                   AND ool.source_type_code <> 'EXTERNAL'        -- CCR0006703
                   --commented start by BT Technology Team on 09-01-2015
                   --AND ool.order_source_id = 1044
                   /*Start Changes by BT Technology Team on 29-Jan-2015*/
                   AND ool.order_source_id = (SELECT order_source_id
                                                FROM oe_order_sources
                                               WHERE NAME = p_order_source)
                   /* AND ool.order_source_id = (SELECT order_source_id
                                                 FROM oe_order_sources
                                                WHERE NAME = 'Flagstaff') */
                   /*End Changes by BT Technology Team on 29-Jan-2015*/
                   --commented End by BT Technology Team on 09-01-2015
                   AND (ool.orig_sys_document_ref LIKE '90%' OR ool.orig_sys_document_ref LIKE '99%')
                   AND TRUNC (NVL (ool.latest_acceptable_date, SYSDATE)) <
                       TRUNC (SYSDATE)
                   AND ool.header_id = NVL (p_header_id, ool.header_id)
                   AND ooh.ORDER_NUMBER =
                       NVL (p_order_number, ooh.ORDER_NUMBER) --Added by BT Technology Team on 09-FEB-2015
                   AND ooh.header_id = ool.header_id
                   AND ott.transaction_type_id = ooh.order_type_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_reservations mr
                             WHERE mr.demand_source_line_id = ool.line_id)
            UNION
            SELECT /*+ parallel(2) */
                   ool.line_id, ool.flow_status_code, -- Start modification by the BT Team on 24-Aug-15
                                                      --                TO_DATE (ool.attribute1, 'DD-MON-RR'),
                                                      apps.fnd_date.canonical_to_date (ool.attribute1),
                   -- End modification by the BT Team on 24-Aug-15
                   ott.attribute13, ool.header_id
              FROM apps.oe_order_lines ool, oe_order_headers ooh, oe_transaction_types ott
             WHERE     ool.flow_status_code = 'AWAITING_RETURN'
                   AND ool.open_flag = 'Y'
                   AND ool.line_category_code = 'RETURN'
                   --commented start by BT Technology Team on 09-01-2015
                   --AND ool.order_source_id = 1044
                   /*Start Changes by BT Technology Team on 29-Jan-2015*/
                   AND ool.order_source_id = (SELECT order_source_id
                                                FROM oe_order_sources
                                               WHERE NAME = p_order_source)
                   /*  AND ool.order_source_id = (SELECT order_source_id
                                                  FROM oe_order_sources
                                                 WHERE NAME = 'Flagstaff') */
                   /*End Changes by BT Technology Team on 29-Jan-2015*/
                   --commented End by BT Technology Team on 09-01-2015
                   AND ool.orig_sys_document_ref LIKE '90%'
                   AND TRUNC (
                           -- Start modification by the BT Team on 24-Aug-15
                           --                       NVL (TO_DATE (ool.attribute1, 'DD-MON-RR'), SYSDATE)) <
                           NVL (
                               apps.fnd_date.canonical_to_date (
                                   ool.attribute1),
                               SYSDATE)) < -- Start modification by the BT Team on 24-Aug-15
                       TRUNC (SYSDATE)
                   AND ool.header_id = NVL (p_header_id, ool.header_id)
                   AND ooh.ORDER_NUMBER =
                       NVL (p_order_number, ooh.ORDER_NUMBER) --Added by BT Technology Team on 09-FEB-2015
                   AND ooh.header_id = ool.header_id
                   AND ott.transaction_type_id = ooh.order_type_id
                   AND ott.attribute13 = 'AE'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM rcv_transactions_interface rti
                             WHERE     rti.oe_order_line_id = ool.line_id
                                   AND rti.document_num =
                                       TO_CHAR (ooh.order_number));

        CURSOR c_rtn_line (c_line_id IN NUMBER)
        IS
            SELECT /*+ parallel(2) */
                   oolr.line_id
              FROM oe_order_lines ool, oe_order_lines oolr, ---mtl_system_items_b msi,  --commented  by BT Technology Team on 12-01-2015
                                                            ---mtl_system_items_b msir
                                                            apps.xxd_common_items_v msi,
                   --added  by BT Technology Team on 12-01-2015
                   apps.xxd_common_items_v msir
             WHERE     ool.line_id = c_line_id
                   AND oolr.header_id = ool.header_id
                   AND oolr.line_category_code = 'RETURN'
                   AND oolr.unit_selling_price = ool.unit_selling_price
                   -- AND msir.segment1 = msi.segment1   --commented  by BT Technology Team on 12-01-2015
                   AND msir.style_number = msi.style_number
                   --added  by BT Technology Team on 12-01-2015
                   AND msi.inventory_item_id = ool.inventory_item_id
                   AND msi.organization_id = ool.ship_from_org_id
                   AND msir.inventory_item_id = oolr.inventory_item_id
                   AND msi.organization_id = oolr.ship_from_org_id;
    BEGIN
        fnd_global.apps_initialize (fnd_global.user_id,
                                    fnd_global.resp_id,
                                    fnd_global.resp_appl_id);

        /*Start Code Added by BT Technology Team on 09-FEB-2015*/
        BEGIN
            SELECT ooh.header_id
              INTO l_header_id
              FROM oe_order_headers ooh
             WHERE order_number = p_order_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_header_id   := NULL;
        END;

        /*End Code Added by BT Technology Team on 09-FEB-2015*/
        FOR c_exp_lines IN c_expired_lines (l_header_id)
        LOOP
            BEGIN
                l_rtn_status     := fnd_api.g_ret_sts_success;
                l_rtn_msg_data   := NULL;

                -- derive the BFF action code based on DO order ype
                IF c_exp_lines.do_order_type = 'CS'
                THEN
                    l_status_code   := 'CCN';
                ELSIF c_exp_lines.do_order_type = 'CE'
                THEN
                    l_status_code   := 'CCE';
                ELSE
                    l_status_code   := 'CAA';
                END IF;

                -- mark order line for BFF action
                xxdoec_oeol_wf_pkg.update_line_custom_status (
                    p_line_id       => c_exp_lines.line_id,
                    p_status_code   => l_status_code,
                    p_reason_code   => l_reason_code,
                    x_rtn_sts       => l_rtn_status,
                    x_rtn_msg       => l_rtn_msg_data);
                -- Cancel order line
                cancel_line (p_line_id => c_exp_lines.line_id, p_reason_code => l_reason_code, x_rtn_status => l_rtn_status
                             , x_rtn_msg_data => l_rtn_msg_data);

                IF l_rtn_status = fnd_api.g_ret_sts_success
                THEN
                    -- In case of Retail Exchange add Store Credit
                    IF c_exp_lines.do_order_type = 'RE'
                    THEN
                        xxdoec_returns_exchanges_pkg.add_store_credit (
                            p_order_line_id     => c_exp_lines.line_id,
                            p_order_header_id   => c_exp_lines.header_id,
                            x_order_line_id     => l_sc_line_id,
                            x_order_number      => l_sc_order_number,
                            x_rtn_status        => l_rtn_status,
                            x_error_msg         => l_rtn_msg_data);

                        IF l_rtn_status = fnd_api.g_ret_sts_success
                        THEN
                            msg (
                                   'Successfully created Store Credit line to Order: '
                                || l_sc_order_number
                                || ' SC Line ID: '
                                || l_sc_line_id);
                            dcdlog.changecode (
                                p_code           => -10026,
                                p_application    => g_application,
                                p_logeventtype   => 2,
                                p_tracelevel     => 2,
                                p_debug          => l_debug);
                            dcdlog.addparameter ('Order Number',
                                                 TO_CHAR (l_sc_order_number),
                                                 'NUMBER');
                            dcdlog.addparameter ('Line Id',
                                                 TO_CHAR (l_sc_line_id),
                                                 'NUMBER');
                            l_rc   := dcdlog.loginsert ();

                            IF (l_rc <> 1)
                            THEN
                                msg (dcdlog.l_message);
                            END IF;
                        ELSE
                            msg (
                                   'Unable to create Store Credit line to Header ID: '
                                || c_exp_lines.header_id
                                || ' Cancelled Line ID: '
                                || c_exp_lines.line_id);
                            msg ('Error Msg: ' || l_rtn_msg_data);
                            dcdlog.changecode (
                                p_code           => -10027,
                                p_application    => g_application,
                                p_logeventtype   => 1,
                                p_tracelevel     => 1,
                                p_debug          => l_debug);
                            dcdlog.addparameter (
                                'header_id',
                                TO_CHAR (c_exp_lines.header_id),
                                'NUMBER');
                            dcdlog.addparameter (
                                'Line Id',
                                TO_CHAR (c_exp_lines.line_id),
                                'NUMBER');
                            dcdlog.addparameter ('Error message',
                                                 l_rtn_msg_data,
                                                 'VARCHAR2');
                            l_rc   := dcdlog.loginsert ();

                            IF (l_rc <> 1)
                            THEN
                                msg (dcdlog.l_message);
                            END IF;
                        END IF;
                    END IF;

                    -- In case of Channel Advisor Exchange then mark return line for refund
                    IF c_exp_lines.do_order_type = 'CE'
                    THEN
                        OPEN c_rtn_line (c_exp_lines.line_id);

                        FETCH c_rtn_line INTO l_return_line_id;

                        IF c_rtn_line%FOUND
                        THEN
                            CLOSE c_rtn_line;

                            -- mark order line for BFF action
                            xxdoec_oeol_wf_pkg.update_line_custom_status (
                                p_line_id       => l_return_line_id,
                                p_status_code   => 'CRN',
                                p_reason_code   => NULL,
                                x_rtn_sts       => l_rtn_status,
                                x_rtn_msg       => l_rtn_msg_data);
                        ELSE
                            CLOSE c_rtn_line;
                        END IF;
                    END IF;
                ELSE
                    msg ('Return Status: ' || l_rtn_status);
                    msg (
                           'Unable to Cancel some of the expired Order Lines in Status Code: '
                        || c_exp_lines.status_code
                        || ' - Line ID: '
                        || c_exp_lines.line_id
                        || ' - LAD: '
                        || c_exp_lines.latest_acceptable_date);
                    dcdlog.changecode (p_code => -10025, p_application => g_application, p_logeventtype => 1
                                       , p_tracelevel => 1, p_debug => l_debug);
                    dcdlog.addparameter ('status_code',
                                         c_exp_lines.status_code,
                                         'VARCHAR2');
                    dcdlog.addparameter ('Line Id',
                                         TO_CHAR (c_exp_lines.line_id),
                                         'NUMBER');
                    dcdlog.addparameter (
                        'Last acceptable date',
                        TO_CHAR (c_exp_lines.latest_acceptable_date),
                        'VARCHAR2');
                    l_rc   := dcdlog.loginsert ();

                    IF (l_rc <> 1)
                    THEN
                        msg (dcdlog.l_message);
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg ('Return Status: ' || l_rtn_status);
                    msg (
                           'Cancel Expired Order Lines process failed with error: '
                        || SQLERRM);
                    dcdlog.changecode (p_code => -10025, p_application => g_application, p_logeventtype => 1
                                       , p_tracelevel => 1, p_debug => l_debug);
                    dcdlog.addparameter ('l_rtn_status',
                                         l_rtn_status,
                                         'VARCHAR2');
                    dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
                    l_rc   := dcdlog.loginsert ();

                    IF (l_rc <> 1)
                    THEN
                        msg (dcdlog.l_message);
                    END IF;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    := 'Unexpected Error occured ' || SQLERRM;
            dcdlog.changecode (p_code => -10025, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => l_debug);
            dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
            l_rc        := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;
    END cancel_expired_lines;

    PROCEDURE cancel_picked_lines (x_errbuf                OUT VARCHAR2,
                                   x_retcode               OUT NUMBER,
                                   p_delivery_id        IN     NUMBER,
                                   p_web_order_number   IN     VARCHAR2,
                                   p_item_number        IN     VARCHAR2)
    IS
        -- Local variables
        l_trip_id         NUMBER;
        l_trip_name       VARCHAR2 (120);
        l_msg_count       NUMBER;
        l_msg_data        VARCHAR2 (2000);
        l_msg_index_out   NUMBER;
        l_user_id         NUMBER;
        l_resp_id         NUMBER;
        l_resp_appl_id    NUMBER;
        l_delivery_id     NUMBER;
        l_reason_code     VARCHAR2 (40) := 'PRD-0030';
        l_rtn_status      VARCHAR2 (1);
        l_rtn_msg         VARCHAR2 (2000);
        l_tabofdeldets    wsh_delivery_details_pub.id_tab_type;
        l_line_rows       wsh_util_core.id_tab_type;
        x_del_rows        wsh_util_core.id_tab_type;

        CURSOR c_picked_lines IS
            SELECT /*+ parallel(2) */
                   wdd.delivery_detail_id, wdd.source_line_id, wdd.requested_quantity
              FROM wsh_delivery_details wdd, oe_order_lines ool, oe_order_headers ooh
             WHERE     wdd.released_status = 'Y'
                   AND wdd.source_code = 'OE'
                   AND wdd.source_line_id = ool.line_id
                   AND ool.ordered_item = p_item_number
                   AND ool.header_id = ooh.header_id
                   AND ooh.cust_po_number = p_web_order_number;

        CURSOR c_cb_params IS
            SELECT /*+ parallel(2) */
                   cbp.transaction_user_id, cbp.erp_login_resp_id, cbp.erp_login_app_id
              FROM oe_order_headers_all ooh, hz_cust_accounts hca, xxdoec_country_brand_params cbp
             WHERE     ooh.cust_po_number = p_web_order_number
                   AND hca.cust_account_id = ooh.sold_to_org_id
                   AND cbp.website_id = hca.attribute18;

        -- private procedure
        PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100)
        IS
        BEGIN
            fnd_file.put_line (fnd_file.LOG, MESSAGE);
            DBMS_OUTPUT.put_line (MESSAGE);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END msg;
    BEGIN
        l_rtn_status   := fnd_api.g_ret_sts_success;

        --
        IF p_web_order_number IS NULL OR p_item_number IS NULL
        THEN
            x_retcode   := 1;
            msg (
                'Web Order Number and Item Number combination is mandatory. Please enter them');
        ELSE
            OPEN c_cb_params;

            FETCH c_cb_params INTO l_user_id, l_resp_id, l_resp_appl_id;

            IF c_cb_params%NOTFOUND
            THEN
                CLOSE c_cb_params;

                x_retcode   := 1;
                msg (
                       'Web Order Number: '
                    || p_web_order_number
                    || ' is not valid');
            ELSE
                CLOSE c_cb_params;

                do_apps_initialize (l_user_id, l_resp_id, l_resp_appl_id);

                FOR c_del IN c_picked_lines
                LOOP
                    -- Unassign from delivery
                    l_tabofdeldets (1)   := c_del.delivery_detail_id;
                    wsh_delivery_details_pub.detail_to_delivery (
                        p_api_version        => 1.0,
                        p_init_msg_list      => fnd_api.g_true,
                        p_commit             => fnd_api.g_true,
                        p_validation_level   => fnd_api.g_valid_level_full,
                        x_return_status      => l_rtn_status,
                        x_msg_count          => l_msg_count,
                        x_msg_data           => l_msg_data,
                        p_tabofdeldets       => l_tabofdeldets,
                        p_action             => 'UNASSIGN',
                        p_delivery_id        => NULL,
                        p_delivery_name      => NULL);

                    IF     l_rtn_status <> fnd_api.g_ret_sts_success
                       AND l_rtn_status <> 'W'
                       AND l_msg_count > 0
                    THEN
                        -- Retrieve messages
                        FOR i IN 1 .. l_msg_count
                        LOOP
                            fnd_msg_pub.get (
                                p_msg_index       => i,
                                p_encoded         => fnd_api.g_false,
                                p_data            => l_msg_data,
                                p_msg_index_out   => l_msg_index_out);
                            l_rtn_msg   :=
                                SUBSTR (l_rtn_msg || l_msg_data || CHR (13),
                                        1,
                                        2000);
                        END LOOP;

                        msg (
                               'Failed to Unassign from Delivery for Delivery detail ID '
                            || c_del.delivery_detail_id);
                        msg (
                               'Rtn Status: '
                            || l_rtn_status
                            || ' Rtn Msg: '
                            || l_rtn_msg);
                    ELSE
                        -- Auto Create Deliveries
                        l_line_rows (1)   := c_del.delivery_detail_id;
                        wsh_delivery_details_pub.autocreate_deliveries (
                            p_api_version_number   => 1.0,
                            p_init_msg_list        => fnd_api.g_true,
                            p_commit               => fnd_api.g_true,
                            x_return_status        => l_rtn_status,
                            x_msg_count            => l_msg_count,
                            x_msg_data             => l_msg_data,
                            p_line_rows            => l_line_rows,
                            x_del_rows             => x_del_rows);

                        IF     l_rtn_status <> fnd_api.g_ret_sts_success
                           AND l_rtn_status <> 'W'
                           AND l_msg_count > 0
                        THEN
                            -- Retrieve messages
                            FOR i IN 1 .. l_msg_count
                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => fnd_api.g_false,
                                    p_data            => l_msg_data,
                                    p_msg_index_out   => l_msg_index_out);
                                l_rtn_msg   :=
                                    SUBSTR (
                                        l_rtn_msg || l_msg_data || CHR (13),
                                        1,
                                        2000);
                            END LOOP;

                            msg (
                                   'Failed to Auto Create Delivery for Delivery detail ID '
                                || c_del.delivery_detail_id);
                            msg (
                                   'Rtn Status: '
                                || l_rtn_status
                                || ' Rtn Msg: '
                                || l_rtn_msg);
                        ELSE
                            l_delivery_id   := x_del_rows (1);

                            --
                            UPDATE wsh_delivery_details
                               SET cycle_count_quantity = c_del.requested_quantity, shipped_quantity = 0
                             WHERE delivery_detail_id =
                                   c_del.delivery_detail_id;

                            wsh_deliveries_pub.delivery_action (
                                p_api_version_number        => 1.0,
                                p_init_msg_list             => 'T',
                                x_return_status             => l_rtn_status,
                                x_msg_count                 => l_msg_count,
                                x_msg_data                  => l_msg_data,
                                p_action_code               => 'CONFIRM',
                                p_delivery_id               => l_delivery_id,
                                p_sc_intransit_flag         => 'Y',
                                p_sc_close_trip_flag        => 'Y',
                                p_sc_defer_interface_flag   => 'N',
                                x_trip_id                   => l_trip_id,
                                x_trip_name                 => l_trip_name);

                            IF     l_rtn_status <> fnd_api.g_ret_sts_success
                               AND l_rtn_status <> 'W'
                               AND l_msg_count > 0
                            THEN
                                -- Retrieve messages
                                FOR i IN 1 .. l_msg_count
                                LOOP
                                    fnd_msg_pub.get (
                                        p_msg_index       => i,
                                        p_encoded         => fnd_api.g_false,
                                        p_data            => l_msg_data,
                                        p_msg_index_out   => l_msg_index_out);
                                    l_rtn_msg   :=
                                        SUBSTR (
                                               l_rtn_msg
                                            || l_msg_data
                                            || CHR (13),
                                            1,
                                            2000);
                                END LOOP;

                                msg (
                                       'Delivery ID: '
                                    || l_delivery_id
                                    || ' failed to get backordered');
                                msg (
                                       'Rtn Status: '
                                    || l_rtn_status
                                    || ' Rtn Msg: '
                                    || l_rtn_msg);
                            ELSE
                                msg (
                                       'Delivery ID: '
                                    || l_delivery_id
                                    || ' got backordered successfully');
                                -- Mark for Cancellation e-mail
                                xxdoec_oeol_wf_pkg.update_line_custom_status (
                                    p_line_id       => c_del.source_line_id,
                                    p_status_code   => 'CAA',
                                    p_reason_code   => l_reason_code,
                                    x_rtn_sts       => l_rtn_status,
                                    x_rtn_msg       => l_rtn_msg);
                                -- Cancel back ordered lines
                                xxdoec_process_order_lines.cancel_line (
                                    p_line_id        => c_del.source_line_id,
                                    p_reason_code    => l_reason_code,
                                    x_rtn_status     => l_rtn_status,
                                    x_rtn_msg_data   => l_rtn_msg);

                                IF l_rtn_status <> fnd_api.g_ret_sts_success
                                THEN
                                    x_retcode   := 1;
                                    msg (
                                           'Line ID '
                                        || c_del.source_line_id
                                        || ' failed to get cancelled');
                                    msg (
                                           'Rtn Status: '
                                        || l_rtn_status
                                        || ' Rtn Msg: '
                                        || l_rtn_msg);
                                ELSE
                                    msg (
                                           'Line ID '
                                        || c_del.source_line_id
                                        || ' got cancelled successfully');
                                END IF;   -- status check for cancellation API
                            END IF;          -- status check for backorder API
                        END IF;                -- Auto Create delivery success
                    END IF;
                END LOOP;                      -- loop thorough delivery lines
            END IF;                                     -- CB parameters check
        END IF;                -- web order number, item number not null check
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    := 'Unexpected Error occured ' || SQLERRM;
    END cancel_picked_lines;

    PROCEDURE progress_line_id (p_line_id IN NUMBER, p_result_code IN VARCHAR2, x_rtn_status OUT VARCHAR2
                                , x_rtn_msg_data OUT VARCHAR2)
    IS
        l_activity_name   VARCHAR2 (120);
        l_ctr             NUMBER := 0;
        l_debug           NUMBER := 0;
        l_rc              NUMBER := 0;
        dcdlog            dcdlog_type
            := dcdlog_type (p_code => -10032, p_application => g_application, p_logeventtype => 4
                            , p_tracelevel => 2, p_debug => l_debug); -- Start off by logging metric.

        CURSOR c_order_line IS
            SELECT line_id, flow_status_code, attribute20 status_code
              FROM oe_order_lines_all
             WHERE line_id = p_line_id;
    BEGIN
        dcdlog.addparameter ('Start time', CURRENT_TIMESTAMP, 'TIMESTAMP');
        dcdlog.addparameter ('Line_id', p_line_id, 'NUMBER');
        dcdlog.addparameter ('p_result_code', p_result_code, 'VARCHAR2');
        l_rc             := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;

        x_rtn_msg_data   := '__progress_line:  p_line_id: ' || p_line_id;
        x_rtn_status     := fnd_api.g_ret_sts_success;

        FOR c_lines IN c_order_line
        LOOP
            IF c_lines.status_code = 'FRC'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_ACCERTIFY_RESULT';
            ELSIF c_lines.status_code = 'PGA'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_PG_AUTH';
            ELSIF c_lines.status_code = 'SHE'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_SHIPMENT_EMAIL';
            ELSIF c_lines.status_code = 'PGC'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_PG_RESPONSE';
            ELSIF c_lines.status_code = 'CHB'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_PG_CHARGEBACK';
            ELSIF c_lines.status_code = 'RCE'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_RECEIPT_EMAIL';
            ELSIF c_lines.status_code = 'CSN'
            THEN
                l_activity_name   := 'DOEC_CA_WAIT_FOR_SHIP_NOTIF';
            ELSIF c_lines.status_code = 'CRN'
            THEN
                l_activity_name   := 'DOEC_CA_WAIT_FOR_REFUND_NOTIF';
            ELSIF c_lines.status_code = 'CSE'
            THEN
                l_activity_name   := 'DOEC_CA_WAIT_FOR_SHIP_EMAIL';
            ELSIF c_lines.status_code = 'CRE'
            THEN
                l_activity_name   := 'DOEC_CA_WAIT_FOR_REFUND_EMAIL';
            ELSIF c_lines.status_code = 'MTO'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_M2O_INTF_RESULTS';
            ELSIF c_lines.status_code = 'IPE'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_ORDER_ACK_EMAIL';
            ELSIF c_lines.status_code = 'SFS'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_SFS';
            ELSIF c_lines.status_code IN ('CAE', 'CAA')
            -- cancel email... workflow is complete before this, so there is no activity to perform
            THEN
                l_activity_name   := NULL;
                x_rtn_msg_data    :=
                       x_rtn_msg_data
                    || ' workflow already complete, not advancing line.';
            ELSE
                l_activity_name   := NULL;
                x_rtn_status      := fnd_api.g_ret_sts_error;
                x_rtn_msg_data    :=
                       '1) Unable to progress Line ID: '
                    || TO_CHAR (p_line_id)
                    || ' p_status_code unknown: '
                    || c_lines.status_code;
            END IF;

            --    msg(x_rtn_msg_data || ' l_activity_name:  ' ||
            --        NVL(l_activity_name, 'NULL') || '.');
            dcdlog.changecode (p_code => -10028, p_application => g_application, p_logeventtype => 2
                               , p_tracelevel => 2, p_debug => l_debug);
            dcdlog.addparameter ('l_activity_name',
                                 NVL (l_activity_name, 'NULL'),
                                 'VARCHAR2');
            l_rc   := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;

            IF     l_activity_name IS NOT NULL
               AND c_lines.flow_status_code <> 'CLOSED'
            THEN
                x_rtn_msg_data   :=
                       x_rtn_msg_data
                    || 'Line ID: '
                    || p_line_id
                    || ' ~ Activity Name: '
                    || l_activity_name
                    || ' ~ Result Code: '
                    || p_result_code;

                BEGIN
                    --          msg('___line_id is ' || TO_CHAR(c_lines.line_id) || '.');
                    dcdlog.changecode (p_code => -10029, p_application => g_application, p_logeventtype => 2
                                       , p_tracelevel => 2, p_debug => l_debug);
                    dcdlog.addparameter ('c_lines.line_id',
                                         TO_CHAR (c_lines.line_id),
                                         'NUMBER');
                    l_rc             := dcdlog.loginsert ();
                    wf_engine.completeactivity (itemtype => 'OEOL', itemkey => TO_CHAR (c_lines.line_id), activity => l_activity_name
                                                , RESULT => p_result_code);
                    x_rtn_msg_data   :=
                           x_rtn_msg_data
                        || ' line_id '
                        || TO_CHAR (c_lines.line_id)
                        || ' updated '
                        || ' LOOP = '
                        || TO_CHAR (l_ctr)
                        || '.';
                    --          msg(x_rtn_msg_data);
                    dcdlog.changecode (p_code => -10030, p_application => g_application, p_logeventtype => 2
                                       , p_tracelevel => 2, p_debug => l_debug);
                    dcdlog.addparameter ('c_lines.line_id',
                                         TO_CHAR (c_lines.line_id),
                                         'NUMBER');
                    dcdlog.addparameter ('Message data',
                                         x_rtn_msg_data,
                                         'VARCHAR2');
                    dcdlog.addparameter ('loop count at',
                                         TO_CHAR (l_ctr),
                                         'NUMBER');
                    l_rc             := dcdlog.loginsert ();

                    IF (l_rc <> 1)
                    THEN
                        msg (dcdlog.l_message);
                    END IF;

                    l_ctr            := l_ctr + 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_rtn_status     := fnd_api.g_ret_sts_error;
                        x_rtn_msg_data   :=
                               x_rtn_msg_data
                            || '2) Unable to progress Line ID: '
                            || TO_CHAR (c_lines.line_id)
                            || 'Error: '
                            || SQLERRM;
                        --            msg(x_rtn_msg_data);
                        dcdlog.changecode (p_code           => -10031,
                                           p_application    => g_application,
                                           p_logeventtype   => 1,
                                           p_tracelevel     => 1,
                                           p_debug          => l_debug);
                        dcdlog.addparameter ('c_lines.line_id',
                                             TO_CHAR (c_lines.line_id),
                                             'NUMBER');
                        dcdlog.addparameter ('Message data',
                                             x_rtn_msg_data,
                                             'VARCHAR2');
                        dcdlog.addparameter ('loop count at',
                                             TO_CHAR (l_ctr),
                                             'NUMBER');
                        dcdlog.addparameter (SQLERRM, 'SQLERRM', 'VARCHAR2');
                        l_rc             := dcdlog.loginsert ();

                        IF (l_rc <> 1)
                        THEN
                            msg (dcdlog.l_message);
                        END IF;
                END;

                x_rtn_msg_data   := x_rtn_msg_data || ' end.';
                dcdlog.changecode (p_code => -10032, p_application => g_application, p_logeventtype => 4
                                   , p_tracelevel => 2, p_debug => l_debug);
                dcdlog.addparameter ('End',
                                     TO_CHAR (CURRENT_TIMESTAMP),
                                     'TIMESTAMP');
                l_rc             := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;
            END IF;
        END LOOP;
    --    msg(x_rtn_msg_data);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status     := fnd_api.g_ret_sts_unexp_error;
            x_rtn_msg_data   :=
                x_rtn_msg_data || '3) Unable to progress Lines ' || SQLERRM;
            --      msg(x_rtn_msg_data);
            dcdlog.changecode (p_code => -10031, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => l_debug);
            dcdlog.addparameter ('Error message', x_rtn_msg_data, 'VARCHAR2');
            l_rc             := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;
    END progress_line_id;

    PROCEDURE progress_line (p_header_id IN NUMBER, p_line_grp_id IN VARCHAR2, p_status_code IN VARCHAR2
                             , p_result_code IN VARCHAR2, x_rtn_status OUT VARCHAR2, x_rtn_msg_data OUT VARCHAR2)
    IS
        l_activity_name   VARCHAR2 (120);
        l_rtn_status      VARCHAR2 (1);
        l_rtn_msg_data    VARCHAR2 (2000);
        l_ctr             NUMBER := 0;
        l_debug           NUMBER := 0;
        l_rc              NUMBER := 0;
        dcdlog            dcdlog_type
            := dcdlog_type (p_code => -10032, p_application => g_application, p_logeventtype => 4
                            , p_tracelevel => 2, p_debug => l_debug); -- Start off by logging metric.

        CURSOR c_order_lines IS
            SELECT line_id, flow_status_code, attribute20 status_code
              FROM oe_order_lines_all
             WHERE header_id = p_header_id AND attribute18 = p_line_grp_id;
    BEGIN
        -- Diagnostics for debugging
        --    msg('_Entering progress_line:  p_header_id:  ' || TO_CHAR(p_header_id) ||
        --        '  p_line_grp_id:  ' || p_line_grp_id || '  p_status_code:  ' ||
        --        p_status_code || '  p_result_code:  ' || p_result_code || '.');
        dcdlog.addparameter ('Start time', CURRENT_TIMESTAMP, 'TIMESTAMP');
        dcdlog.addparameter ('header_id', p_header_id, 'NUMBER');
        dcdlog.addparameter ('p_line_grp_id', p_line_grp_id, 'VARCHAR2');
        dcdlog.addparameter ('p_status_code', p_status_code, 'VARCHAR2');
        dcdlog.addparameter ('p_result_code', p_result_code, 'VARCHAR2');
        l_rc             := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;

        x_rtn_msg_data   :=
               '__progress_line:  p_header_id: '
            || p_header_id
            || ' p_line_grp_id '
            || p_line_grp_id
            || ' p_status_code '
            || p_status_code;
        x_rtn_status     := fnd_api.g_ret_sts_success;

        FOR c_lines IN c_order_lines
        LOOP
            dcdlog.changecode (p_code => -10053, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => l_debug);
            dcdlog.addparameter ('HEADER_ID', p_header_id, 'NUMBER');
            dcdlog.addparameter ('Error message', x_rtn_msg_data, 'VARCHAR2');
            dcdlog.addparameter ('LINE_ID', c_lines.line_id, 'VARCHAR2');
            dcdlog.addparameter ('FLOW_STATUS_CODE',
                                 c_lines.flow_status_code,
                                 'VARCHAR2');
            dcdlog.addparameter ('attribute20',
                                 c_lines.status_code,
                                 'VARCHAR2');
            l_rc             := dcdlog.loginsert ();
            l_rtn_status     := fnd_api.g_ret_sts_success;
            l_rtn_msg_data   := NULL;
            progress_line_id (p_line_id => c_lines.line_id, p_result_code => p_result_code, x_rtn_status => l_rtn_status
                              , x_rtn_msg_data => l_rtn_msg_data);

            IF l_rtn_status <> fnd_api.g_ret_sts_success
            THEN
                x_rtn_status   := l_rtn_status;
                x_rtn_msg_data   :=
                    x_rtn_msg_data || CHR (10) || l_rtn_msg_data;
            END IF;
        END LOOP;
    --    msg(x_rtn_msg_data);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status     := fnd_api.g_ret_sts_unexp_error;
            x_rtn_msg_data   :=
                x_rtn_msg_data || '3) Unable to progress Lines ' || SQLERRM;
            --      msg(x_rtn_msg_data);
            dcdlog.changecode (p_code => -10031, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => l_debug);
            dcdlog.addparameter ('Error message', x_rtn_msg_data, 'VARCHAR2');
            l_rc             := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;
    END progress_line;

    PROCEDURE create_cash_receipts_prepaid (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER)
    IS
        CURSOR c_order_payments IS
            SELECT /*+ parallel(2) */
                   ordr.sold_to_org_id, ordr.cust_po_number, ordr.header_id,
                   pmts.payment_type, pmts.payment_amount, pmts.payment_date,
                   pmts.payment_number, pmts.pg_reference_num, pmts.line_group_id line_grp_id,
                   pmts.payment_id, pmts.payment_tender_type --Added by Madhav for ENHC0011797
              FROM xxdoec_order_payment_details pmts, oe_order_headers_all ordr
             WHERE     1 = 1
                   AND ordr.header_id = NVL (p_header_id, ordr.header_id)
                   AND ordr.cust_po_number = pmts.web_order_number
                   AND pmts.web_order_number IS NOT NULL
                   AND NVL (pmts.prepaid_flag, 'N') = 'Y'   -- Added by Madhav
                   AND pmts.pg_action = 'PGC'               -- Added by Madhav
                   AND pmts.status = 'OP'
                   AND pmts.payment_amount <> 0;

        CURSOR c_cb_params (c_order_header_id IN NUMBER)
        IS
            SELECT /*+ parallel(2) */
                   cbp.ar_batch_source_id, cbp.ar_bank_branch_id, cbp.ar_bank_account_id,
                   cbp.ar_batch_type, cbp.ar_receipt_class_id, cbp.ar_receipt_method_id,
                   ooh.transactional_curr_code, hca.account_number customer_number, hou.NAME company_name,
                   cbp.website_id, ooh.order_number
              FROM xxdoec_country_brand_params cbp, oe_order_headers_all ooh, hz_cust_accounts hca,
                   hr_operating_units hou
             WHERE     1 = 1
                   AND ooh.header_id = c_order_header_id
                   AND hca.cust_account_id = ooh.sold_to_org_id
                   AND hou.organization_id = ooh.sold_from_org_id
                   AND cbp.website_id = hca.attribute18;

        CURSOR c_receipt_method (c_receipt_class_id IN NUMBER, c_do_pmt_type IN VARCHAR2, c_web_site_id IN VARCHAR2)
        IS
            SELECT arm.receipt_method_id, bau.bank_account_id, cba.bank_branch_id
              FROM ar_receipt_methods arm, ar_receipt_method_accounts_all arma, ce_bank_acct_uses_all bau,
                   ce_bank_accounts cba
             WHERE     1 = 1
                   AND arm.receipt_class_id = c_receipt_class_id
                   AND arm.attribute2 = c_do_pmt_type
                   AND NVL (arm.attribute1, c_web_site_id) = c_web_site_id
                   AND SYSDATE BETWEEN NVL (arm.start_date, SYSDATE)
                                   AND NVL (arm.end_date, SYSDATE)
                   AND arma.receipt_method_id = arm.receipt_method_id
                   AND bau.bank_acct_use_id = arma.remit_bank_acct_use_id
                   AND cba.bank_account_id = bau.bank_account_id
                   AND NVL (arm.attribute4, 'N') = 'Y'
                   AND cba.account_classification = 'INTERNAL';

        l_om_frt_total        NUMBER;
        l_inv_frt_total       NUMBER;
        l_inv_balance         NUMBER;
        l_apply_amt           NUMBER;
        l_receipt_method_id   NUMBER;
        l_bank_account_id     NUMBER;
        l_bank_branch_id      NUMBER;
        l_batch_id            NUMBER;
        l_cash_receipt_id     NUMBER;
        l_receipt_number      VARCHAR2 (30);
        l_batch_name          VARCHAR2 (120);
        l_error_msg           VARCHAR2 (2000);
        l_pmt_status          VARCHAR2 (1);
        l_rtn_status          VARCHAR2 (1);
        cb_params_rec         c_cb_params%ROWTYPE;
        l_debug               NUMBER := 0;
        l_rc                  NUMBER := 0;
        dcdlog                dcdlog_type
            := dcdlog_type (p_code => -10035, p_application => g_application, p_logeventtype => 4
                            , p_tracelevel => 2, p_debug => 0); -- Start off by logging metric.

        -- private procedure
        PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100)
        IS
        BEGIN
            fnd_file.put_line (fnd_file.LOG, MESSAGE);
            DBMS_OUTPUT.put_line (MESSAGE);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END msg;
    BEGIN
        dcdlog.addparameter ('Start',
                             TO_CHAR (CURRENT_TIMESTAMP),
                             'TIMESTAMP');
        l_rc   := dcdlog.loginsert ();

        FOR r_order_payments IN c_order_payments
        LOOP
            l_rtn_status   := 'Y';

            BEGIN
                -- create Receipt Batch
                OPEN c_cb_params (r_order_payments.header_id);

                FETCH c_cb_params INTO cb_params_rec;

                CLOSE c_cb_params;

                --
                IF cb_params_rec.website_id IS NULL
                THEN
                    msg (
                        'Could not find the Country Brand Parameters record to get default receipt values',
                        100);
                    l_pmt_status   := fnd_api.g_ret_sts_error;
                    l_rtn_status   := 'N';
                ELSE
                    OPEN c_receipt_method (cb_params_rec.ar_receipt_class_id,
                                           r_order_payments.payment_type,
                                           cb_params_rec.website_id);

                    FETCH c_receipt_method INTO l_receipt_method_id, l_bank_account_id, l_bank_branch_id;

                    CLOSE c_receipt_method;

                    --
                    do_ar_utils.create_receipt_batch_trans (
                        p_company          => cb_params_rec.company_name,
                        p_batch_source_id   =>
                            cb_params_rec.ar_batch_source_id,
                        p_bank_branch_id   =>
                            NVL (l_bank_branch_id,
                                 cb_params_rec.ar_bank_branch_id),
                        p_batch_type       => cb_params_rec.ar_batch_type,
                        p_currency_code    =>
                            cb_params_rec.transactional_curr_code,
                        p_bank_account_id   =>
                            NVL (l_bank_account_id,
                                 cb_params_rec.ar_bank_account_id),
                        p_batch_date       => r_order_payments.payment_date,
                        p_receipt_class_id   =>
                            cb_params_rec.ar_receipt_class_id,
                        p_control_count    => 1,
                        p_gl_date          => r_order_payments.payment_date,
                        p_receipt_method_id   =>
                            NVL (l_receipt_method_id,
                                 cb_params_rec.ar_receipt_method_id),
                        p_control_amount   => l_apply_amt,
                        p_deposit_date     => r_order_payments.payment_date,
                        p_comments         =>
                               'Order# '
                            || cb_params_rec.order_number
                            || ' Line Grp ID: '
                            || r_order_payments.line_grp_id,
                        p_auto_commit      => 'N',
                        x_batch_id         => l_batch_id,
                        x_batch_name       => l_batch_name,
                        x_error_msg        => l_error_msg);

                    IF l_batch_id <> -1
                    THEN
                        -- create receipt
                        SELECT xxdo.xxdoec_cash_receipts_s.NEXTVAL
                          INTO l_receipt_number
                          FROM DUAL;

                        l_error_msg   := NULL;
                        do_ar_utils.create_receipt_trans (
                            p_batch_id          => l_batch_id,
                            p_receipt_number    => l_receipt_number,
                            p_receipt_amt       =>
                                r_order_payments.payment_amount,
                            p_transaction_num   =>
                                r_order_payments.pg_reference_num,
                            p_payment_server_order_num   =>
                                r_order_payments.pg_reference_num,
                            p_customer_number   =>
                                cb_params_rec.customer_number,
                            p_customer_name     => NULL,
                            p_comments          =>
                                   'Order# '
                                || cb_params_rec.order_number
                                || ' Line Grp ID: '
                                || r_order_payments.line_grp_id
                                || 'PG Ref: '
                                || r_order_payments.pg_reference_num,
                            p_currency_code     =>
                                cb_params_rec.transactional_curr_code,
                            p_location          => NULL,
                            p_auto_commit       => 'N',
                            x_cash_receipt_id   => l_cash_receipt_id,
                            x_error_msg         => l_error_msg);

                        IF NVL (l_cash_receipt_id, -200) = -200
                        THEN
                            msg (
                                   'Unable to create Cash Receipt for the amount '
                                || r_order_payments.payment_amount,
                                100);
                            msg ('Error Message: ' || l_error_msg, 100);
                            l_pmt_status   := fnd_api.g_ret_sts_error;
                            l_rtn_status   := 'N';
                        ELSE
                            msg (
                                   'Successfully created Cash Receipt for the amount '
                                || r_order_payments.payment_amount,
                                100);
                            msg ('Cash Receipt ID: ' || l_cash_receipt_id,
                                 100);
                            l_error_msg   := NULL;

                            --Update cash receipt with the order header id
                            UPDATE ar_cash_receipts_all
                               SET attribute15 = r_order_payments.header_id, attribute14 = r_order_payments.payment_tender_type
                             --Added by Madhav for ENHC0011797
                             WHERE cash_receipt_id = l_cash_receipt_id;
                        END IF;                        -- Cash Receipt success
                    ELSE
                        msg ('Unable to create Cash Receipt Batch ', 100);
                        msg ('Error Message: ' || l_error_msg, 100);
                        l_pmt_status   := fnd_api.g_ret_sts_error;
                        l_rtn_status   := 'N';
                    END IF;                           -- Receipt Batch success
                END IF;                                 -- cb_params_rec found
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_rtn_status   := 'N';
                    x_retcode      := 1;
                    x_errbuf       :=
                           'Unexpected Error occured while processing Order Header ID: '
                        || r_order_payments.header_id
                        || ' Lines Group ID: '
                        || r_order_payments.line_grp_id
                        || SQLERRM;
                    dcdlog.changecode (p_code => -10034, p_application => g_application, p_logeventtype => 1
                                       , p_tracelevel => 1, p_debug => l_debug);
                    dcdlog.addparameter (
                        'c_ccr.header_id',
                        TO_CHAR (r_order_payments.header_id),
                        'NUMBER');
                    dcdlog.addparameter (
                        'c_ccr.line_grp_id',
                        TO_CHAR (r_order_payments.line_grp_id),
                        'NUMBER');
                    dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
                    l_rc           := dcdlog.loginsert ();

                    IF (l_rc <> 1)
                    THEN
                        msg (dcdlog.l_message);
                    END IF;
            END;

            --Update Payments table record status to CL
            IF l_rtn_status = 'Y'
            THEN
                UPDATE xxdoec_order_payment_details pmts
                   SET status   = 'CL'
                 WHERE payment_id = r_order_payments.payment_id;
            END IF;
        END LOOP;                   --FOR c_order_payments IN c_order_payments

        --Apply receipts to invoices
        apply_prepaid_rct_to_inv (x_errbuf      => x_errbuf,
                                  x_retcode     => x_retcode,
                                  p_header_id   => p_header_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    := 'Unexpected Error occured ' || SQLERRM;
            dcdlog.changecode (p_code => -10034, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => l_debug);
            dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
            l_rc        := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;
    END create_cash_receipts_prepaid;

    PROCEDURE apply_prepaid_rct_to_inv (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER)
    AS
        CURSOR c_receipts IS
            SELECT NVL (ps.amount_applied, 0) applied_amount, acr.amount amount, acr.cash_receipt_id,
                   acr.attribute15 order_header_id, NVL (ps.amount_due_remaining, 0) remaining_amt
              FROM ar_cash_receipts acr, ar_cash_receipt_history_all ach, ar_receipt_methods arm,
                   ar_payment_schedules ps
             WHERE     1 = 1
                   AND acr.cash_receipt_id = ach.cash_receipt_id
                   AND acr.receipt_method_id = arm.receipt_method_id
                   AND acr.cash_receipt_id = ps.cash_receipt_id(+)
                   AND acr.org_id = ps.org_id(+)
                   AND acr.org_id = ach.org_id
                   AND ach.status != 'REVERSED'
                   --AND acr.org_id = 472
                   AND NVL (arm.attribute4, 'N') = 'Y'
                   AND acr.attribute15 IS NOT NULL
                   AND NVL (ps.amount_due_remaining, 0) != 0
                   AND NVL (acr.attribute15, 'XyZ') =
                       NVL (p_header_id, NVL (acr.attribute15, 'XyZ'));

        CURSOR c_order_lines (c_header_id IN NUMBER)
        IS
              SELECT /*+ parallel(2) */
                     ool.header_id, ool.sold_to_org_id, ool.invoice_to_org_id,
                     ool.attribute18 line_grp_id, ool.attribute20 status_code, ool.attribute16 pgc_trans_num,
                     rctl.customer_trx_id, SUM (ool.ordered_quantity * ool.unit_selling_price) + SUM (NVL (DECODE (zxr.inclusive_tax_flag, 'Y', 0, opa_tax.adjusted_amount), 0)) om_line_total, SUM (rctl.extended_amount + NVL (rctl_tax.extended_amount, 0)) inv_line_total
                FROM oe_order_lines ool, oe_price_adjustments opa_tax, zx_rates_b zxr,
                     ra_customer_trx_lines rctl, ra_customer_trx_lines rctl_tax
               WHERE     1 = 1
                     AND ool.attribute20 = 'PGC'
                     AND ool.attribute19 = 'SUCCESS'
                     AND ool.attribute17 = 'S'
                     AND ool.line_category_code = 'ORDER'
                     AND opa_tax.line_id(+) = ool.line_id
                     AND opa_tax.list_line_type_code(+) = 'TAX'
                     AND zxr.tax_rate_id(+) = opa_tax.tax_rate_id
                     AND rctl.interface_line_context(+) = 'ORDER ENTRY'
                     AND rctl.interface_line_attribute6(+) =
                         TO_CHAR (ool.line_id)
                     AND rctl_tax.line_type(+) = 'TAX'
                     AND rctl_tax.customer_trx_id(+) = rctl.customer_trx_id
                     AND rctl_tax.link_to_cust_trx_line_id(+) =
                         rctl.customer_trx_line_id
                     AND ool.header_id = NVL (c_header_id, ool.header_id)
            GROUP BY ool.header_id, ool.sold_to_org_id, ool.invoice_to_org_id,
                     ool.attribute18, ool.attribute20, ool.attribute16,
                     rctl.customer_trx_id;

        CURSOR c_inv_balance (c_inv_trx_id IN NUMBER)
        IS
            SELECT SUM (ABS (amount_due_remaining))
              FROM apps.ar_payment_schedules aps
             WHERE customer_trx_id = c_inv_trx_id;

        CURSOR c_frt_charges (c_header_id     IN NUMBER,
                              c_line_grp_id   IN VARCHAR2)
        IS
            SELECT SUM (opa.adjusted_amount) om_frt_amount, SUM (rctl_frt.extended_amount + NVL (rctl_frt_tax.extended_amount, 0)) inv_frt_total
              FROM oe_order_lines ool, oe_price_adjustments opa, ra_customer_trx_lines rctl_frt,
                   ra_customer_trx_lines rctl_frt_tax
             WHERE     ool.attribute20 = 'PGC'
                   AND ool.attribute19 = 'SUCCESS'
                   AND ool.attribute17 = 'S'
                   AND ool.line_category_code = 'ORDER'
                   AND opa.list_line_type_code = 'FREIGHT_CHARGE'
                   AND opa.line_id = ool.line_id
                   AND rctl_frt.interface_line_context(+) = 'ORDER ENTRY'
                   AND rctl_frt.interface_line_attribute6(+) =
                       TO_CHAR (opa.price_adjustment_id)
                   AND rctl_frt_tax.line_type(+) = 'TAX'
                   AND rctl_frt_tax.customer_trx_id(+) =
                       rctl_frt.customer_trx_id
                   AND rctl_frt_tax.link_to_cust_trx_line_id(+) =
                       rctl_frt.customer_trx_line_id
                   AND ool.header_id = c_header_id
                   AND ool.attribute18 = c_line_grp_id;

        l_om_frt_total    NUMBER;
        l_inv_frt_total   NUMBER;
        l_inv_balance     NUMBER;
        l_apply_amt       NUMBER;
        l_rtn_status      VARCHAR2 (1);
        l_pmt_status      VARCHAR2 (1);
        l_error_msg       VARCHAR2 (2000);
        l_debug           NUMBER := 0;
        l_rc              NUMBER := 0;
        dcdlog            dcdlog_type
            := dcdlog_type (p_code => -10035, p_application => g_application, p_logeventtype => 4
                            , p_tracelevel => 2, p_debug => 0); -- Start off by logging metric.

        PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100)
        IS
        BEGIN
            fnd_file.put_line (fnd_file.LOG, MESSAGE);
            DBMS_OUTPUT.put_line (MESSAGE);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END msg;
    BEGIN
        msg ('INSIDE BEGIN');

        FOR r_receipts IN c_receipts
        LOOP
            msg ('INSIDE RECEIPTS LOOP');

            FOR r_order_lines IN c_order_lines (r_receipts.order_header_id)
            LOOP
                msg ('INSIDE ORDER LINES LOOP');

                BEGIN
                    l_om_frt_total    := 0;
                    l_inv_frt_total   := 0;

                    OPEN c_frt_charges (r_order_lines.header_id,
                                        r_order_lines.line_grp_id);

                    FETCH c_frt_charges INTO l_om_frt_total, l_inv_frt_total;

                    CLOSE c_frt_charges;

                    l_inv_frt_total   :=
                        NVL (l_inv_frt_total, l_om_frt_total);

                    IF l_inv_frt_total > l_om_frt_total
                    THEN
                        l_inv_frt_total   := l_om_frt_total;
                    END IF;

                    msg (
                           'Header ID: '
                        || r_order_lines.header_id
                        || ' Lines Group ID: '
                        || r_order_lines.line_grp_id
                        || ' Invoice ID: '
                        || r_order_lines.customer_trx_id,
                        100);
                    msg (
                           'Order Lines Total: '
                        || r_order_lines.om_line_total
                        || ' Order Freight Total: '
                        || l_om_frt_total,
                        100);
                    msg (
                           'Invoice Lines Total: '
                        || r_order_lines.inv_line_total
                        || ' Invoice Freight Total: '
                        || l_inv_frt_total,
                        100);

                    IF   (r_order_lines.om_line_total + NVL (l_om_frt_total, 0))
                       - (NVL (r_order_lines.inv_line_total, 0) + NVL (l_inv_frt_total, 0)) NOT BETWEEN -0.1
                                                                                                    AND 0.1
                    THEN
                        msg ('Some of the Order Lines are not invoiced yet',
                             100);
                    ELSE
                        l_rtn_status   := fnd_api.g_ret_sts_success;

                        OPEN c_inv_balance (r_order_lines.customer_trx_id);

                        FETCH c_inv_balance INTO l_inv_balance;

                        CLOSE c_inv_balance;

                        l_apply_amt    :=
                            LEAST (l_inv_balance, r_receipts.amount);

                        IF l_apply_amt > 0
                        THEN
                            l_error_msg   := NULL;
                            -- Apply cash to Invoice
                            do_ar_utils.apply_transaction_trans (
                                p_cash_receipt_id   =>
                                    r_receipts.cash_receipt_id,
                                p_customer_trx_id   =>
                                    r_order_lines.customer_trx_id,
                                p_trx_number    => NULL,
                                p_applied_amt   => l_apply_amt,
                                p_discount      => NULL,
                                p_auto_commit   => 'N',
                                x_error_msg     => l_error_msg);

                            IF l_error_msg IS NULL
                            THEN
                                msg (
                                       'Successfully Applied Amount: '
                                    || l_apply_amt
                                    || ' to Invoice ID: '
                                    || r_order_lines.customer_trx_id,
                                    100);
                            ELSE
                                msg (
                                       'Unable to Apply Cash Receipt to Invoice ID: '
                                    || r_order_lines.customer_trx_id,
                                    100);
                                msg ('Error Message: ' || l_error_msg, 100);
                                l_pmt_status   := fnd_api.g_ret_sts_error;
                            END IF;                -- Cash Receipt App success

                            IF l_pmt_status = fnd_api.g_ret_sts_success
                            THEN
                                --                       UPDATE xxdoec_order_payment_details
                                --                          SET unapplied_amount = c_opd.payment_amount -
                                --                                                 l_apply_amt,
                                --                              status           = DECODE(SIGN(c_opd.payment_amount -
                                --                                                             l_apply_amt),
                                --                                                        0,
                                --                                                        'CL',
                                --                                                        'OP')
                                --WHERE payment_id = c_opd.payment_id;
                                l_inv_balance   :=
                                    l_inv_balance - l_apply_amt;

                                IF l_inv_balance <= 0
                                THEN
                                    EXIT;
                                END IF;
                            ELSE
                                l_rtn_status   := fnd_api.g_ret_sts_error;
                            END IF;
                        END IF;                    --IF l_inv_balance > 0 THEN
                    --
                    END IF; -- IF Some of the Order Lines are not invoiced yet
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        dcdlog.changecode (p_code           => -10035,
                                           p_application    => g_application,
                                           p_logeventtype   => 4,
                                           p_tracelevel     => 2,
                                           p_debug          => l_debug);
                        dcdlog.addparameter ('End',
                                             TO_CHAR (CURRENT_TIMESTAMP),
                                             'TIMESTAMP');
                        l_rc   := dcdlog.loginsert ();

                        IF (l_rc <> 1)
                        THEN
                            msg (dcdlog.l_message);
                        END IF;
                END;
            END LOOP;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    := 'Unexpected Error occured ' || SQLERRM;
            dcdlog.changecode (p_code => -10034, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => l_debug);
            dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
            l_rc        := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;
    END apply_prepaid_rct_to_inv;

    PROCEDURE prepaid_receipt_write_off (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_org_id IN NUMBER
                                         , p_order_header_id IN NUMBER)
    AS
        p_api_version                    NUMBER;
        p_init_msg_list                  VARCHAR2 (200);
        p_commit                         VARCHAR2 (200);
        p_validation_level               NUMBER;
        x_return_status                  VARCHAR2 (200);
        x_msg_count                      NUMBER;
        x_msg_data                       VARCHAR2 (200);
        l_cash_receipt_id                ar_cash_receipts.cash_receipt_id%TYPE;
        p_receipt_number                 ar_cash_receipts.receipt_number%TYPE;
        l_amount_applied                 ar_receivable_applications.amount_applied%TYPE;
        l_applied_payment_schedule_id    ar_payment_schedules.payment_schedule_id%TYPE;
        p_link_to_customer_trx_id        ra_customer_trx.customer_trx_id%TYPE;
        p_receivables_trx_id             ar_receivable_applications.receivables_trx_id%TYPE;
        p_apply_date                     ar_receivable_applications.apply_date%TYPE;
        p_apply_gl_date                  ar_receivable_applications.gl_date%TYPE;
        p_ussgl_transaction_code         ar_receivable_applications.ussgl_transaction_code%TYPE;
        p_attribute_rec                  ar_receipt_api_pub.attribute_rec_type;
        p_global_attribute_rec           ar_receipt_api_pub.global_attribute_rec_type;
        p_comments                       ar_receivable_applications.comments%TYPE;
        p_application_ref_type           ar_receivable_applications.application_ref_type%TYPE;
        p_application_ref_id             ar_receivable_applications.application_ref_id%TYPE;
        p_application_ref_num            ar_receivable_applications.application_ref_num%TYPE;
        p_secondary_application_ref_id   ar_receivable_applications.secondary_application_ref_id%TYPE;
        p_payment_set_id                 ar_receivable_applications.payment_set_id%TYPE;
        p_receivable_application_id      ar_receivable_applications.receivable_application_id%TYPE;
        p_customer_reference             ar_receivable_applications.customer_reference%TYPE;
        p_val_writeoff_limits_flag       VARCHAR2 (200);
        p_called_from                    VARCHAR2 (200);
        p_netted_receipt_flag            VARCHAR2 (200);
        p_netted_cash_receipt_id         ar_cash_receipts.cash_receipt_id%TYPE;
        p_secondary_app_ref_type         ar_receivable_applications.secondary_application_ref_type%TYPE;
        p_secondary_app_ref_num          ar_receivable_applications.secondary_application_ref_num%TYPE;
        l_rec_num                        VARCHAR2 (240);

        CURSOR c_payments IS
            SELECT pmts.payment_id, ord.header_id, pmts.line_group_id,
                   pmts.payment_trx_id, pmts.payment_type, pmts.payment_number,
                   pmts.payment_date, pmts.payment_amount, pmts.pg_reference_num,
                   pmts.comments, pmts.unapplied_amount, pmts.status,
                   pmts.web_order_number, pmts.pg_action, pmts.prepaid_flag,
                   ord.order_number
              FROM xxdoec_order_payment_details pmts, oe_order_headers_all ord
             WHERE     1 = 1
                   AND pmts.web_order_number = ord.cust_po_number
                   AND pmts.pg_action = 'CHB'
                   AND pmts.prepaid_flag = 'Y'
                   AND pmts.status = 'OP'
                   AND ord.org_id = p_org_id
                   AND ord.header_id = NVL (p_order_header_id, ord.header_id) --AND pmts.web_order_number = NVL(p_web_order_num,pmts.web_order_number)
                                                                             ;

        /*CURSOR c_rct_total (p_header_id NUMBER)
        IS
           SELECT SUM (amount)
             FROM ar_cash_receipts
            WHERE attribute15 = p_header_id;*/
        CURSOR c_rct_total (p_header_id NUMBER, p_payment_type VARCHAR2)
        IS
            SELECT SUM (acr.amount)
              FROM ar_cash_receipts_all acr, ar_cash_receipt_history_all ach, ar_receipt_methods arm,
                   ar_payment_schedules_all ps
             WHERE     1 = 1
                   AND acr.cash_receipt_id = ach.cash_receipt_id
                   AND acr.receipt_method_id = arm.receipt_method_id
                   AND acr.cash_receipt_id = ps.cash_receipt_id(+)
                   AND acr.org_id = ps.org_id(+)
                   AND acr.org_id = ach.org_id
                   AND acr.org_id = p_org_id
                   AND ach.status != 'REVERSED'
                   --AND acr.org_id = 472
                   AND NVL (arm.attribute4, 'N') = 'Y'
                   AND NVL (arm.attribute2, 'XyZ') = p_payment_type
                   AND acr.attribute15 IS NOT NULL
                   AND NVL (ps.amount_due_remaining, 0) != 0
                   AND NVL (acr.attribute15, 'XyZ') =
                       NVL (p_header_id, NVL (acr.attribute15, 'XyZ'));

        /*CURSOR c_receipts (p_header_id NUMBER)
        IS
           SELECT amount, receipt_number, cash_receipt_id, receipt_method_id
             FROM ar_cash_receipts acr
            WHERE 1 = 1
              AND acr.attribute15 IS NOT NULL
              AND NVL (acr.attribute15, 'XyZ') = p_header_id;*/
        CURSOR c_receipts (p_header_id NUMBER, p_payment_type VARCHAR2)
        IS
            SELECT NVL (ps.amount_applied, 0) applied_amount, acr.amount amount, acr.cash_receipt_id,
                   acr.attribute15 order_header_id, NVL (ps.amount_due_remaining, 0) remaining_amt, acr.receipt_method_id,
                   acr.receipt_number
              FROM ar_cash_receipts_all acr, ar_cash_receipt_history_all ach, ar_receipt_methods arm,
                   ar_payment_schedules_all ps
             WHERE     1 = 1
                   AND acr.cash_receipt_id = ach.cash_receipt_id
                   AND acr.receipt_method_id = arm.receipt_method_id
                   AND acr.cash_receipt_id = ps.cash_receipt_id(+)
                   AND acr.org_id = ps.org_id(+)
                   AND acr.org_id = ach.org_id
                   AND acr.org_id = p_org_id
                   AND ach.status != 'REVERSED'
                   --AND acr.org_id = 472
                   AND NVL (arm.attribute4, 'N') = 'Y'
                   AND NVL (arm.attribute2, 'XyZ') = p_payment_type
                   AND acr.attribute15 IS NOT NULL
                   AND NVL (ps.amount_due_remaining, 0) != 0
                   AND NVL (acr.attribute15, 'XyZ') =
                       NVL (p_header_id, NVL (acr.attribute15, 'XyZ'));

        CURSOR c_receivables_trx_id (p_receipt_method_id NUMBER)
        IS
            SELECT receivables_trx_id
              FROM ar_receivables_trx_all rtrx, ar_receipt_methods arm
             WHERE     1 = 1
                   AND rtrx.attribute2 = arm.attribute2
                   AND arm.receipt_method_id = p_receipt_method_id
                   AND rtrx.org_id = p_org_id
                   AND rtrx.TYPE = 'WRITEOFF';

        l_rct_total                      NUMBER;
        l_rcv_trx_id                     NUMBER;
        l_status_flag                    VARCHAR2 (1);
    BEGIN
        apps.mo_global.init ('AR');
        apps.mo_global.set_policy_context ('S', p_org_id);
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('=', 20, '=')
            || RPAD ('=', 20, '=')
            || LPAD ('=', 15, '=')
            || RPAD ('=', 15, '='));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('Web Order#', 20, ' ')
            || RPAD ('Receipt#', 20, ' ')
            || LPAD ('Amount   ', 15, ' ')
            || RPAD ('WriteOff', 15, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('=', 20, '=')
            || RPAD ('=', 20, '=')
            || LPAD ('=', 15, '=')
            || RPAD ('=', 15, '='));

        FOR r_payments IN c_payments
        LOOP
            l_status_flag   := 'Y';

            OPEN c_rct_total (r_payments.header_id, r_payments.payment_type);

            FETCH c_rct_total INTO l_rct_total;

            CLOSE c_rct_total;

            IF r_payments.payment_amount <= NVL (l_rct_total, 0)
            -- payment_amount is the REFUND amount to be processed. This must be <= total open receipts to apply against
            THEN
                FOR r_receipts
                    IN c_receipts (r_payments.header_id,
                                   r_payments.payment_type)
                LOOP
                    --l_cash_receipt_id := p_cash_receipt_id;
                    --l_amount_applied := p_amount_applied;
                    l_applied_payment_schedule_id   := -3;        -- Write-off

                    OPEN c_receivables_trx_id (r_receipts.receipt_method_id);

                    FETCH c_receivables_trx_id INTO l_rcv_trx_id;

                    CLOSE c_receivables_trx_id;

                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Amount :' || TO_CHAR (r_receipts.amount));
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Receipt Number :' || r_receipts.receipt_number);
                    apps.fnd_file.put_line (apps.fnd_file.LOG,
                                            'Rec Trx ID :' || l_rcv_trx_id);
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'applied_payment_schedule_id :'
                        || l_applied_payment_schedule_id);
                    ar_receipt_api_pub.activity_application (
                        p_api_version              => 1.0,
                        p_init_msg_list            => fnd_api.g_true,
                        p_commit                   => fnd_api.g_true,
                        p_validation_level         => fnd_api.g_valid_level_full,
                        x_return_status            => x_return_status,
                        x_msg_count                => x_msg_count,
                        x_msg_data                 => x_msg_data,
                        p_cash_receipt_id          => r_receipts.cash_receipt_id,
                        p_receipt_number           => r_receipts.receipt_number,
                        --p_receipt_number,
                        p_amount_applied           => r_payments.payment_amount,
                        p_applied_payment_schedule_id   =>
                            l_applied_payment_schedule_id,
                        p_link_to_customer_trx_id   =>
                            p_link_to_customer_trx_id,
                        p_receivables_trx_id       => l_rcv_trx_id,
                        --3389,
                        --p_receivables_trx_id,
                        p_apply_date               =>
                            TRUNC (r_payments.payment_date),
                        --p_apply_date,
                        p_apply_gl_date            =>
                            TRUNC (r_payments.payment_date),
                        --p_apply_gl_date,
                        p_ussgl_transaction_code   => p_ussgl_transaction_code,
                        p_attribute_rec            => p_attribute_rec,
                        p_global_attribute_rec     => p_global_attribute_rec,
                        p_comments                 =>
                               'Refund Order#'
                            || r_payments.order_number
                            || ', Web Order#'
                            || r_payments.web_order_number
                            || ', PG Ref#'
                            || r_payments.pg_reference_num,
                        --p_comments,
                        p_application_ref_type     => p_application_ref_type,
                        p_application_ref_id       => p_application_ref_id,
                        p_application_ref_num      => p_application_ref_num,
                        p_secondary_application_ref_id   =>
                            p_secondary_application_ref_id,
                        p_payment_set_id           => p_payment_set_id,
                        p_receivable_application_id   =>
                            p_receivable_application_id,
                        p_customer_reference       => p_customer_reference,
                        p_val_writeoff_limits_flag   =>
                            p_val_writeoff_limits_flag,
                        p_called_from              => p_called_from,
                        p_netted_receipt_flag      => p_netted_receipt_flag,
                        p_netted_cash_receipt_id   => p_netted_cash_receipt_id,
                        p_secondary_app_ref_type   => p_secondary_app_ref_type,
                        p_secondary_app_ref_num    => p_secondary_app_ref_num);

                    IF (x_return_status = 'S')
                    THEN
                        --COMMIT;
                        apps.fnd_file.put_line (apps.fnd_file.LOG, 'SUCCESS');
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Return Status            = '
                            || SUBSTR (x_return_status, 1, 255));
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Message Count             = ' || x_msg_count);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Message Data            = ' || x_msg_data);
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'p_receivable_application_id   = '
                            || p_receivable_application_id);
                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                               RPAD (r_payments.web_order_number, 20, ' ')
                            || RPAD (l_rec_num, 20, ' ')
                            || LPAD (TO_CHAR (l_amount_applied), 15, ' '));
                    ELSE
                        --ROLLBACK;
                        l_status_flag   := 'N';
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Return Status    = '
                            || SUBSTR (x_return_status, 1, 255));
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Message Count     = ' || TO_CHAR (x_msg_count));
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Message Data    = '
                            || SUBSTR (x_msg_data, 1, 255));
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            apps.fnd_msg_pub.get (
                                p_msg_index   => apps.fnd_msg_pub.g_last,
                                p_encoded     => apps.fnd_api.g_false));

                        IF x_msg_count >= 0
                        THEN
                            FOR i IN 1 .. 10
                            LOOP
                                apps.fnd_file.put_line (
                                    apps.fnd_file.LOG,
                                       i
                                    || '. '
                                    || SUBSTR (
                                           fnd_msg_pub.get (
                                               p_encoded => fnd_api.g_false),
                                           1,
                                           255));
                            END LOOP;
                        END IF;

                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                               RPAD (r_payments.web_order_number, 20, ' ')
                            || RPAD (l_rec_num, 20, ' ')
                            || LPAD (TO_CHAR (l_amount_applied), 15, ' '));
                    END IF;
                END LOOP;

                IF l_status_flag = 'N'
                THEN
                    ROLLBACK;
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           RPAD (r_payments.web_order_number, 20, ' ')
                        || RPAD (' ', 20, ' ')
                        || LPAD (' ', 15, ' ')
                        || RPAD ('FAILED', 15, ' '));
                    x_retcode   := 1;
                ELSE
                    UPDATE xxdoec_order_payment_details
                       SET status   = 'CL'
                     WHERE     1 = 1
                           AND header_id = r_payments.header_id
                           AND web_order_number = r_payments.web_order_number
                           AND prepaid_flag = 'Y'
                           AND pg_action = 'CHB'
                           AND status = 'OP';

                    COMMIT;
                END IF;
            ELSE
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       'Web Order#'
                    || r_payments.web_order_number
                    || ' Payment Amount : '
                    || TO_CHAR (r_payments.payment_amount)
                    || ' Does not match with Receipts total : '
                    || TO_CHAR (l_rct_total));
                x_retcode   := 1;
            END IF;
        END LOOP;

        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 20, '-')
            || RPAD ('-', 20, '-')
            || LPAD ('-', 15, '-')
            || RPAD ('-', 15, '-'));
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Exception :' || SQLERRM);
            x_retcode   := 2;
    END prepaid_receipt_write_off;

    PROCEDURE create_cash_receipt (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER)
    IS
        CURSOR c_order_lines IS
              SELECT ool.header_id, ool.sold_to_org_id, ool.invoice_to_org_id,
                     ool.attribute18 line_grp_id, ool.attribute20 status_code, ool.attribute16 pgc_trans_num,
                     rctl.customer_trx_id, SUM (ool.ordered_quantity * ool.unit_selling_price) + SUM (NVL (DECODE (zxr.inclusive_tax_flag, 'Y', 0, opa_tax.adjusted_amount), 0)) om_line_total, SUM (rctl.extended_amount + NVL (rctl_tax.extended_amount, 0)) inv_line_total
                FROM oe_order_lines ool, oe_price_adjustments opa_tax, zx_rates_b zxr,
                     ra_customer_trx_lines rctl, ra_customer_trx_lines rctl_tax, oe_order_headers ooh,
                     oe_transaction_types ott
               WHERE     ool.attribute20 = 'PGC'
                     AND ool.attribute19 = 'SUCCESS'
                     AND ool.attribute17 = 'S'
                     AND ool.line_category_code = 'ORDER'
                     AND opa_tax.line_id(+) = ool.line_id
                     AND opa_tax.list_line_type_code(+) = 'TAX'
                     AND zxr.tax_rate_id(+) = opa_tax.tax_rate_id
                     AND rctl.interface_line_context(+) = 'ORDER ENTRY'
                     AND rctl.interface_line_attribute6(+) =
                         TO_CHAR (ool.line_id)
                     AND rctl_tax.line_type(+) = 'TAX'
                     AND rctl_tax.customer_trx_id(+) = rctl.customer_trx_id
                     AND rctl_tax.link_to_cust_trx_line_id(+) =
                         rctl.customer_trx_line_id
                     AND ool.header_id = NVL (p_header_id, ool.header_id)
                     AND ooh.header_id = ool.header_id
                     AND ott.transaction_type_id = ooh.order_type_id
                     AND ott.attribute13 NOT IN ('PP', 'PE')
            GROUP BY ool.header_id, ool.sold_to_org_id, ool.invoice_to_org_id,
                     ool.attribute18, ool.attribute20, ool.attribute16,
                     rctl.customer_trx_id;

        /*Start of change as part of verison 1.6  */
        /*
        CURSOR c_frt_charges (
           c_header_id     IN NUMBER,
           c_line_grp_id   IN VARCHAR2)
        IS
           SELECT SUM (opa.adjusted_amount) om_frt_amount,
                  SUM (
                     rctl_frt.extended_amount
                     + NVL (rctl_frt_tax.extended_amount, 0))
                     inv_frt_total
             FROM oe_order_lines ool,
                  oe_price_adjustments opa,
                  ra_customer_trx_lines rctl_frt,
                  ra_customer_trx_lines rctl_frt_tax
            WHERE     ool.attribute20 = 'PGC'
                  AND ool.attribute19 = 'SUCCESS'
                  AND ool.attribute17 = 'S'
                  AND ool.line_category_code = 'ORDER'
                  AND opa.list_line_type_code = 'FREIGHT_CHARGE'
                  AND opa.line_id = ool.line_id
                  AND rctl_frt.interface_line_context(+) = 'ORDER ENTRY'
                  AND rctl_frt.interface_line_attribute6(+) =
                         TO_CHAR (opa.price_adjustment_id)
                  AND rctl_frt_tax.line_type(+) = 'TAX'
                  AND rctl_frt_tax.customer_trx_id(+) =
                         rctl_frt.customer_trx_id
                  AND rctl_frt_tax.link_to_cust_trx_line_id(+) =
                         rctl_frt.customer_trx_line_id
                  AND ool.header_id = c_header_id
                  AND ool.attribute18 = c_line_grp_id;
  */
        CURSOR c_ord_frt_charges (c_header_id IN NUMBER, c_line_grp_id IN VARCHAR2, c_cust_trx_id IN NUMBER)
        IS
            SELECT SUM (opa.adjusted_amount) om_frt_amount
              FROM oe_order_headers ooha, oe_order_lines ool, oe_price_adjustments opa,
                   ra_customer_trx rct, ra_customer_trx_lines rctl
             WHERE     ool.attribute20 = 'PGC'
                   AND ool.attribute19 = 'SUCCESS'
                   AND ool.attribute17 = 'S'
                   AND ool.line_category_code = 'ORDER'
                   AND opa.list_line_type_code = 'FREIGHT_CHARGE'
                   AND opa.line_id = ool.line_id
                   AND TO_CHAR (rct.interface_header_attribute1) =
                       TO_CHAR (ooha.order_number)
                   AND rct.customer_trx_id = rctl.customer_trx_id
                   AND RCTL.SALES_ORDER_LINE = OOL.LINE_NUMBER
                   AND rct.customer_trx_id = c_cust_trx_id
                   AND ool.header_id = c_header_id
                   AND ool.attribute18 = c_line_grp_id;

        CURSOR c_inv_frt_charges (c_cust_trx_id IN NUMBER)
        IS
            SELECT SUM (rctl_frt.extended_amount + NVL (rctl_frt_tax.extended_amount, 0)) inv_frt_total
              FROM ra_customer_trx_lines rctl_frt, ra_customer_trx_lines rctl_frt_tax
             WHERE     rctl_frt.customer_trx_id = c_cust_trx_id
                   AND rctl_frt.LINE_TYPE = 'FREIGHT'
                   AND rctl_frt.interface_line_context(+) = 'ORDER ENTRY'
                   AND rctl_frt_tax.line_type(+) = 'TAX'
                   AND rctl_frt_tax.customer_trx_id(+) =
                       rctl_frt.customer_trx_id
                   AND rctl_frt_tax.link_to_cust_trx_line_id(+) =
                       rctl_frt.customer_trx_line_id;

        /*End of change as part of verison 1.6  */
        CURSOR c_order_payments (c_header_id     IN NUMBER,
                                 c_line_grp_id   IN VARCHAR2)
        IS
            SELECT payment_id,
                   payment_trx_id,
                   payment_type,
                   NVL (unapplied_amount, payment_amount)
                       payment_amount,
                   payment_date,
                   pg_reference_num,
                   (SELECT DECODE (SIGN (pt.product_selling_price_total + ftt.freight_charge_total + ftt.freight_discount_total + ftt.gift_wrap_total + ftt.tax_total_no_vat),  -1, 'CHB',  1, 'PGC',  'NOP')
                      FROM xxdoec_oe_order_product_totals pt, xxdoec_oe_order_frt_tax_totals ftt
                     WHERE     pt.header_id = c_header_id
                           AND pt.attribute18 = c_line_grp_id
                           AND ftt.header_id = c_header_id
                           AND ftt.attribute18 = c_line_grp_id)
                       payment_action,
                   payment_tender_type       --Added by Madhav for ENHC0011797
              FROM xxdoec_order_payment_details
             WHERE     status = 'OP'
                   AND payment_type IN ('CC', 'PP', 'GC',
                                        'SC', 'CP', 'AD',
                                        'RM', 'RC')
                   --Added this based on the UAT package change with comment---- added transaction types RM and RC by showkath on 18-AUG-15 --W.r.t Version 1.2
                   AND header_id = c_header_id
                   AND line_group_id = c_line_grp_id
                   AND payment_amount <> 0;

        CURSOR c_inv_balance (c_inv_trx_id IN NUMBER)
        IS
            SELECT SUM (ABS (amount_due_remaining))
              FROM apps.ar_payment_schedules aps
             WHERE customer_trx_id = c_inv_trx_id;

        CURSOR c_cb_params (c_order_header_id IN NUMBER)
        IS
            SELECT cbp.ar_batch_source_id, cbp.ar_bank_branch_id, cbp.ar_bank_account_id,
                   cbp.ar_batch_type, cbp.ar_receipt_class_id, cbp.ar_receipt_method_id,
                   ooh.transactional_curr_code, hca.account_number customer_number, hou.NAME company_name,
                   cbp.website_id, ooh.order_number
              FROM xxdoec_country_brand_params cbp, oe_order_headers_all ooh, hz_cust_accounts hca,
                   hr_operating_units hou
             WHERE     ooh.header_id = c_order_header_id
                   AND hca.cust_account_id = ooh.sold_to_org_id
                   AND hou.organization_id = ooh.sold_from_org_id
                   AND cbp.website_id = hca.attribute18;

        l_om_frt_total        NUMBER;
        l_inv_frt_total       NUMBER;
        l_inv_balance         NUMBER;
        l_apply_amt           NUMBER;
        l_receipt_method_id   NUMBER;
        l_bank_account_id     NUMBER;
        l_bank_branch_id      NUMBER;
        l_batch_id            NUMBER;
        l_cash_receipt_id     NUMBER;
        l_receipt_number      VARCHAR2 (30);
        l_batch_name          VARCHAR2 (120);
        l_error_msg           VARCHAR2 (2000);
        l_pmt_status          VARCHAR2 (1);
        l_rtn_status          VARCHAR2 (1);
        cb_params_rec         c_cb_params%ROWTYPE;
        l_debug               NUMBER := 0;
        l_rc                  NUMBER := 0;
        dcdlog                dcdlog_type
            := dcdlog_type (p_code => -10035, p_application => g_application, p_logeventtype => 4
                            , p_tracelevel => 2, p_debug => 0); -- Start off by logging metric.

        -- private procedure
        PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100)
        IS
        BEGIN
            fnd_file.put_line (fnd_file.LOG, MESSAGE);
            DBMS_OUTPUT.put_line (MESSAGE);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END msg;
    BEGIN
        dcdlog.addparameter ('Start',
                             TO_CHAR (CURRENT_TIMESTAMP),
                             'TIMESTAMP');
        l_rc   := dcdlog.loginsert ();

        FOR c_ccr IN c_order_lines
        LOOP
            BEGIN
                l_om_frt_total    := 0;
                l_inv_frt_total   := 0;

                /*Start of change as part of verison 1.6  */
                /*
                OPEN c_frt_charges (c_ccr.header_id, c_ccr.line_grp_id);

                FETCH c_frt_charges
                INTO l_om_frt_total, l_inv_frt_total;

                CLOSE c_frt_charges;
                */
                OPEN c_ord_frt_charges (c_ccr.header_id,
                                        c_ccr.line_grp_id,
                                        c_ccr.customer_trx_id);

                FETCH c_ord_frt_charges INTO l_om_frt_total;

                CLOSE c_ord_frt_charges;

                OPEN c_inv_frt_charges (c_ccr.customer_trx_id);

                FETCH c_inv_frt_charges INTO l_inv_frt_total;

                CLOSE c_inv_frt_charges;

                /*End of change as part of verison 1.6  */
                l_inv_frt_total   := NVL (l_inv_frt_total, l_om_frt_total);

                IF l_inv_frt_total > l_om_frt_total
                THEN
                    l_inv_frt_total   := l_om_frt_total;
                END IF;

                msg (
                       'Header ID: '
                    || c_ccr.header_id
                    || ' Lines Group ID: '
                    || c_ccr.line_grp_id
                    || ' Invoice ID: '
                    || c_ccr.customer_trx_id,
                    100);
                msg (
                       'Order Lines Total: '
                    || c_ccr.om_line_total
                    || ' Order Freight Total: '
                    || l_om_frt_total,
                    100);
                msg (
                       'Invoice Lines Total: '
                    || c_ccr.inv_line_total
                    || ' Invoice Freight Total: '
                    || l_inv_frt_total,
                    100);

                IF   (c_ccr.om_line_total + NVL (l_om_frt_total, 0))
                   - (NVL (c_ccr.inv_line_total, 0) + NVL (l_inv_frt_total, 0)) NOT BETWEEN -0.1
                                                                                        AND 0.1
                THEN
                    msg ('Some of the Order Lines are not invoiced yet', 100);
                ELSE
                    l_rtn_status   := fnd_api.g_ret_sts_success;

                    OPEN c_inv_balance (c_ccr.customer_trx_id);

                    FETCH c_inv_balance INTO l_inv_balance;

                    CLOSE c_inv_balance;

                    l_inv_balance   :=
                        LEAST (
                            l_inv_balance,
                            (c_ccr.inv_line_total + NVL (l_inv_frt_total, 0)));

                    IF l_inv_balance > 0
                    THEN
                        -- loop through OM Payment details
                        FOR c_opd
                            IN c_order_payments (c_ccr.header_id,
                                                 c_ccr.line_grp_id)
                        LOOP
                            IF     c_opd.payment_type IN ('CC', 'PP', 'GC',
                                                          'SC', 'CP', 'AD',
                                                          'RM', 'RC')
                               --Added this based on the UAT package change with comment---- added transaction types RM and RC by showkath on 18-AUG-15 --W.r.t Version 1.2
                               AND c_opd.payment_action = 'PGC'
                            THEN
                                msg (
                                       'Payment Type: '
                                    || c_opd.payment_type
                                    || 'Payment Action: '
                                    || c_opd.payment_action
                                    || ' Amount: '
                                    || c_opd.payment_amount,
                                    100);
                                l_pmt_status    := fnd_api.g_ret_sts_success;
                                l_error_msg     := NULL;
                                l_apply_amt     :=
                                    LEAST (c_opd.payment_amount,
                                           l_inv_balance);
                                cb_params_rec   := NULL;

                                -- create Receipt Batch
                                OPEN c_cb_params (c_ccr.header_id);

                                FETCH c_cb_params INTO cb_params_rec;

                                CLOSE c_cb_params;

                                --
                                get_receipt_method (cb_params_rec.ar_receipt_class_id, c_opd.payment_type, cb_params_rec.website_id, cb_params_rec.transactional_curr_code, l_receipt_method_id, l_bank_account_id
                                                    , l_bank_branch_id);

                                --
                                IF l_receipt_method_id IS NULL
                                THEN
                                    msg (
                                           'Unable to find the Receipt Method for Payment Type '
                                        || c_opd.payment_type,
                                        100);
                                    l_pmt_status   := fnd_api.g_ret_sts_error;
                                ELSE
                                    -- Create Receipt Batch
                                    do_ar_utils.create_receipt_batch_trans (
                                        p_company          =>
                                            cb_params_rec.company_name,
                                        p_batch_source_id   =>
                                            cb_params_rec.ar_batch_source_id,
                                        p_bank_branch_id   =>
                                            NVL (
                                                l_bank_branch_id,
                                                cb_params_rec.ar_bank_branch_id),
                                        p_batch_type       =>
                                            cb_params_rec.ar_batch_type,
                                        p_currency_code    =>
                                            cb_params_rec.transactional_curr_code,
                                        p_bank_account_id   =>
                                            NVL (
                                                l_bank_account_id,
                                                cb_params_rec.ar_bank_account_id),
                                        p_batch_date       => c_opd.payment_date,
                                        p_receipt_class_id   =>
                                            cb_params_rec.ar_receipt_class_id,
                                        p_control_count    => 1,
                                        p_gl_date          =>
                                            c_opd.payment_date,
                                        p_receipt_method_id   =>
                                            NVL (
                                                l_receipt_method_id,
                                                cb_params_rec.ar_receipt_method_id),
                                        p_control_amount   => l_apply_amt,
                                        p_deposit_date     =>
                                            c_opd.payment_date,
                                        p_comments         =>
                                               'Order# '
                                            || cb_params_rec.order_number
                                            || ' Line Grp ID: '
                                            || c_ccr.line_grp_id,
                                        p_auto_commit      => 'N',
                                        x_batch_id         => l_batch_id,
                                        x_batch_name       => l_batch_name,
                                        x_error_msg        => l_error_msg);

                                    IF l_batch_id <> -1
                                    THEN
                                        -- create receipt
                                        SELECT xxdo.xxdoec_cash_receipts_s.NEXTVAL
                                          INTO l_receipt_number
                                          FROM DUAL;

                                        l_error_msg   := NULL;
                                        do_ar_utils.create_receipt_trans (
                                            p_batch_id        => l_batch_id,
                                            p_receipt_number   =>
                                                l_receipt_number,
                                            p_receipt_amt     => l_apply_amt,
                                            p_transaction_num   =>
                                                c_opd.pg_reference_num,
                                            p_payment_server_order_num   =>
                                                c_opd.pg_reference_num,
                                            p_customer_number   =>
                                                cb_params_rec.customer_number,
                                            p_customer_name   => NULL,
                                            p_comments        =>
                                                   'Order# '
                                                || cb_params_rec.order_number
                                                || ' Line Grp ID: '
                                                || c_ccr.line_grp_id
                                                || 'PG Ref: '
                                                || c_opd.pg_reference_num,
                                            p_currency_code   =>
                                                cb_params_rec.transactional_curr_code,
                                            p_location        => NULL,
                                            p_auto_commit     => 'N',
                                            x_cash_receipt_id   =>
                                                l_cash_receipt_id,
                                            x_error_msg       => l_error_msg);

                                        IF NVL (l_cash_receipt_id, -200) =
                                           -200
                                        THEN
                                            msg (
                                                   'Unable to create Cash Receipt for the amount '
                                                || l_apply_amt,
                                                100);
                                            msg (
                                                   'Error Message: '
                                                || l_error_msg,
                                                100);
                                            l_pmt_status   :=
                                                fnd_api.g_ret_sts_error;
                                        ELSE
                                            msg (
                                                   'Successfully created Cash Receipt for the amount '
                                                || l_apply_amt,
                                                100);
                                            msg (
                                                   'Cash Receipt ID: '
                                                || l_cash_receipt_id,
                                                100);

                                            UPDATE ar_cash_receipts_all
                                               --Added by Madhav for ENHC0011797
                                               SET attribute14 = c_opd.payment_tender_type
                                             --Added by Madhav for ENHC0011797
                                             WHERE cash_receipt_id =
                                                   l_cash_receipt_id;

                                            --Added by Madhav for ENHC0011797
                                            l_error_msg   := NULL;
                                            -- Apply cash to Invoice
                                            do_ar_utils.apply_transaction_trans (
                                                p_cash_receipt_id   =>
                                                    l_cash_receipt_id,
                                                p_customer_trx_id   =>
                                                    c_ccr.customer_trx_id,
                                                p_trx_number    => NULL,
                                                p_applied_amt   => l_apply_amt,
                                                p_discount      => NULL,
                                                p_auto_commit   => 'N',
                                                x_error_msg     => l_error_msg);

                                            IF l_error_msg IS NULL
                                            THEN
                                                msg (
                                                       'Successfully Applied Amount: '
                                                    || l_apply_amt
                                                    || ' to Invoice ID: '
                                                    || c_ccr.customer_trx_id,
                                                    100);
                                            ELSE
                                                msg (
                                                       'Unable to Apply Cash Receipt to Invoice ID: '
                                                    || c_ccr.customer_trx_id,
                                                    100);
                                                msg (
                                                       'Error Message: '
                                                    || l_error_msg,
                                                    100);
                                                l_pmt_status   :=
                                                    fnd_api.g_ret_sts_error;
                                            END IF; -- Cash Receipt App success
                                        END IF;        -- Cash Receipt success
                                    ELSE
                                        msg (
                                            'Unable to create Cash Receipt Batch ',
                                            100);
                                        msg (
                                            'Error Message: ' || l_error_msg,
                                            100);
                                        l_pmt_status   :=
                                            fnd_api.g_ret_sts_error;
                                    END IF;           -- Receipt Batch success
                                END IF;                 -- cb_params_rec found

                                --
                                IF l_pmt_status = fnd_api.g_ret_sts_success
                                THEN
                                    UPDATE xxdoec_order_payment_details
                                       SET unapplied_amount = c_opd.payment_amount - l_apply_amt, status = DECODE (SIGN (c_opd.payment_amount - l_apply_amt), 0, 'CL', 'OP')
                                     WHERE payment_id = c_opd.payment_id;

                                    l_inv_balance   :=
                                        l_inv_balance - l_apply_amt;

                                    IF l_inv_balance <= 0
                                    THEN
                                        EXIT;
                                    END IF;
                                ELSE
                                    l_rtn_status   := fnd_api.g_ret_sts_error;
                                END IF;
                            END IF;                      -- payment_type check
                        END LOOP;                      -- Payment details loop
                    END IF;                       -- invoice balance > 0 check

                    IF     l_rtn_status = fnd_api.g_ret_sts_success
                       AND l_inv_balance = 0
                    THEN
                        UPDATE oe_order_lines_all ool
                           SET ool.attribute20 = 'CCR', ool.attribute19 = 'APPLIED', ool.attribute17 = fnd_api.g_ret_sts_success
                         WHERE     ool.attribute20 = c_ccr.status_code
                               AND ool.header_id = c_ccr.header_id
                               AND ool.attribute18 = c_ccr.line_grp_id
                               AND EXISTS
                                       (SELECT 1
                                          FROM ra_customer_trx_lines_all rctl
                                         WHERE     rctl.customer_trx_id =
                                                   c_ccr.customer_trx_id
                                               AND rctl.interface_line_context =
                                                   'ORDER ENTRY'
                                               AND rctl.interface_line_attribute6 =
                                                   TO_CHAR (ool.line_id));

                        COMMIT;
                    ELSE
                        x_retcode   := 1;
                        ROLLBACK;
                    END IF;
                END IF;                             -- Order lines Total match

                dcdlog.changecode (p_code => -10035, p_application => g_application, p_logeventtype => 4
                                   , p_tracelevel => 2, p_debug => l_debug);
                dcdlog.addparameter ('End',
                                     TO_CHAR (CURRENT_TIMESTAMP),
                                     'TIMESTAMP');
                l_rc              := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_retcode   := 1;
                    x_errbuf    :=
                           'Unexpected Error occured while processing Order Header ID: '
                        || c_ccr.header_id
                        || ' Lines Group ID: '
                        || c_ccr.line_grp_id
                        || SQLERRM;
                    dcdlog.changecode (p_code => -10034, p_application => g_application, p_logeventtype => 1
                                       , p_tracelevel => 1, p_debug => l_debug);
                    dcdlog.addparameter ('c_ccr.header_id',
                                         TO_CHAR (c_ccr.header_id),
                                         'NUMBER');
                    dcdlog.addparameter ('c_ccr.line_grp_id',
                                         TO_CHAR (c_ccr.line_grp_id),
                                         'NUMBER');
                    dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
                    l_rc        := dcdlog.loginsert ();

                    IF (l_rc <> 1)
                    THEN
                        msg (dcdlog.l_message);
                    END IF;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    := 'Unexpected Error occured ' || SQLERRM;
            dcdlog.changecode (p_code => -10034, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => l_debug);
            dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
            l_rc        := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;
    END create_cash_receipt;

    PROCEDURE create_cm_adjustment (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER)
    IS
        CURSOR c_order_lines IS
              SELECT ooh.order_number, ott.attribute13 exchange_order_type, ool.header_id,
                     ool.attribute18 line_grp_id, ool.attribute20 status_code, ool.attribute16 pgc_trans_num,
                     rctl.customer_trx_id, rct.trx_number, rta.NAME adj_activity_name,
                     rctt.NAME trx_type_name, SUM (ool.ordered_quantity * ool.unit_selling_price) + SUM (NVL (DECODE (zxr.inclusive_tax_flag, 'Y', 0, opa_tax.adjusted_amount), 0)) om_line_total, ABS (SUM (rctl.extended_amount + NVL (rctl_tax.extended_amount, 0))) cm_line_total
                FROM oe_order_lines ool, oe_order_headers ooh, oe_transaction_types ott,
                     oe_price_adjustments opa_tax, zx_rates_b zxr, ra_customer_trx_lines rctl,
                     ra_customer_trx_lines rctl_tax, ra_customer_trx rct, ra_cust_trx_types rctt,
                     ar_receivables_trx rta
               WHERE     ool.attribute20 = 'CHB'
                     AND ool.attribute19 = 'SUCCESS'
                     AND ool.attribute17 = 'S'
                     AND ool.line_category_code = 'RETURN'
                     AND ooh.header_id = ool.header_id
                     AND ott.transaction_type_id = ooh.order_type_id
                     AND opa_tax.line_id(+) = ool.line_id
                     AND opa_tax.list_line_type_code(+) = 'TAX'
                     AND zxr.tax_rate_id(+) = opa_tax.tax_rate_id
                     AND rctl.interface_line_context(+) = 'ORDER ENTRY'
                     AND rctl.line_type(+) = 'LINE'
                     AND rctl.interface_line_attribute6(+) =
                         TO_CHAR (ool.line_id)
                     AND rctl.org_id(+) = ool.org_id
                     AND rctl_tax.line_type(+) = 'TAX'
                     AND rctl_tax.customer_trx_id(+) = rctl.customer_trx_id
                     AND rctl_tax.link_to_cust_trx_line_id(+) =
                         rctl.customer_trx_line_id
                     AND rct.customer_trx_id(+) = rctl.customer_trx_id
                     AND rctt.cust_trx_type_id(+) = rct.cust_trx_type_id
                     AND rctt.org_id(+) = rct.org_id
                     AND rta.receivables_trx_id(+) =
                         TO_NUMBER (rctt.attribute2)
                     AND rta.org_id(+) = rctt.org_id
                     AND ool.header_id = NVL (p_header_id, ool.header_id)
            GROUP BY ooh.order_number, ott.attribute13, ool.header_id,
                     ool.attribute18, ool.attribute20, ool.attribute16,
                     rctl.customer_trx_id, rct.trx_number, rta.NAME,
                     rctt.NAME;

        CURSOR c_order_payments (c_header_id     IN NUMBER,
                                 c_line_grp_id   IN VARCHAR2)
        IS
            SELECT payment_id,
                   payment_trx_id,
                   payment_type,
                   NVL (unapplied_amount, payment_amount) payment_amount,
                   payment_date,
                   pg_reference_num,
                   (SELECT DECODE (SIGN (pt.product_selling_price_total + ftt.freight_charge_total + ftt.freight_discount_total + ftt.gift_wrap_total + ftt.tax_total_no_vat),  -1, 'CHB',  1, 'PGC',  'NOP')
                      FROM xxdoec_oe_order_product_totals pt, xxdoec_oe_order_frt_tax_totals ftt
                     WHERE     pt.header_id = c_header_id
                           AND pt.attribute18 = c_line_grp_id
                           AND ftt.header_id = c_header_id
                           AND ftt.attribute18 = c_line_grp_id) payment_action
              FROM xxdoec_order_payment_details
             WHERE     status = 'OP'
                   AND payment_type IN ('CC', 'PP', 'GC',
                                        'SC', 'AD', 'RM',
                                        'RC')
                   --Added this based on the UAT package change with comment-- ----added tansaction types RM and RC by showkath on 18-AUG-15> --W.r.t Version 1.2
                   AND header_id = c_header_id
                   AND line_group_id = c_line_grp_id;

        --
        CURSOR c_cb_params (c_order_header_id IN NUMBER)
        IS
            SELECT cbp.ar_batch_source_id, cbp.ar_bank_branch_id, cbp.ar_bank_account_id,
                   cbp.ar_batch_type, cbp.ar_receipt_class_id, cbp.ar_receipt_method_id,
                   ooh.transactional_curr_code, hca.account_number customer_number, hou.NAME company_name,
                   cbp.website_id, ooh.order_number
              FROM xxdoec_country_brand_params cbp, oe_order_headers_all ooh, hz_cust_accounts hca,
                   hr_operating_units hou
             WHERE     ooh.header_id = c_order_header_id
                   AND hca.cust_account_id = ooh.sold_to_org_id
                   AND hou.organization_id = ooh.sold_from_org_id
                   AND cbp.website_id = hca.attribute18;

        --
        CURSOR c_order_invoice (c_order_number IN NUMBER)
        IS
              SELECT rct.customer_trx_id, rct.bill_to_customer_id, rct.bill_to_site_use_id,
                     SUM (aps.amount_due_remaining) inv_balance
                FROM ra_customer_trx rct, ra_cust_trx_types rctt, ar_payment_schedules aps
               WHERE     rct.interface_header_context = 'ORDER ENTRY'
                     AND rct.interface_header_attribute1 =
                         TO_CHAR (c_order_number)
                     AND rctt.cust_trx_type_id = rct.cust_trx_type_id
                     AND rctt.TYPE = 'INV'
                     AND aps.customer_trx_id = rct.customer_trx_id
            GROUP BY rct.customer_trx_id, rct.bill_to_customer_id, rct.bill_to_site_use_id
              HAVING SUM (aps.amount_due_remaining) > 0;

        CURSOR c_cm_balance (c_cm_trx_id IN NUMBER)
        IS
            SELECT ABS (SUM (aps.amount_due_remaining)) cm_balance, ABS (SUM (aps.amount_line_items_remaining)) cm_line_balance, ABS (SUM (aps.tax_remaining)) cm_tax_balance
              FROM ar_payment_schedules aps
             WHERE customer_trx_id = c_cm_trx_id;

        CURSOR c_adj_activity (c_receipt_method_id IN NUMBER)
        IS
            SELECT NAME
              FROM ar_receivables_trx
             WHERE     attribute4 = TO_CHAR (c_receipt_method_id)
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE);

        l_cm_balance          NUMBER;
        l_cm_line_balance     NUMBER;
        l_cm_tax_balance      NUMBER;
        l_apply_amt           NUMBER;
        l_adj_amt             NUMBER;
        l_adj_activity        VARCHAR2 (120) := NULL; --Added this based on the UAT package change with comment---- Initialized the variable by showkath. --W.r.t Version 1.2
        l_adj_type            VARCHAR2 (40);
        l_rec_appl_id         NUMBER;
        l_adj_id              NUMBER;
        l_adj_number          NUMBER;
        l_err_msg             VARCHAR2 (2000);
        l_pmt_status          VARCHAR2 (1);
        l_adj_status          VARCHAR2 (1);
        l_app_status          VARCHAR2 (1);
        ex_mis_adj_name       EXCEPTION;
        l_payment_amount      NUMBER := 0;
        --
        cb_params_rec         c_cb_params%ROWTYPE;
        l_receipt_method_id   NUMBER;
        l_bank_account_id     NUMBER;
        l_bank_branch_id      NUMBER;

        --Added this based on the UAT package change with comment----- Added by showkath to fix the partial adjustment issue --W.r.t Version 1.2

        -- private procedure
        PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100)
        IS
        BEGIN
            fnd_file.put_line (fnd_file.LOG, MESSAGE);
            DBMS_OUTPUT.put_line (MESSAGE);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END msg;
    BEGIN
        FOR c_cma IN c_order_lines
        LOOP
            BEGIN
                msg (
                       'Header ID: '
                    || c_cma.header_id
                    || ' Lines Group ID: '
                    || c_cma.line_grp_id
                    || ' Credit Memo ID: '
                    || c_cma.customer_trx_id
                    || ' Exchange Order Type: '
                    || c_cma.exchange_order_type,
                    100);
                msg (
                       'Order Lines Total: '
                    || c_cma.om_line_total
                    || ' CM Lines Total: '
                    || c_cma.cm_line_total,
                    100);

                --
                IF c_cma.om_line_total <> NVL (c_cma.cm_line_total, 0)
                THEN
                    msg (
                        'Some or All of the Return Order Lines are not invoiced yet...',
                        100);
                ELSE
                    l_adj_status   := fnd_api.g_ret_sts_success;

                    OPEN c_cm_balance (c_cma.customer_trx_id);

                    FETCH c_cm_balance INTO l_cm_balance, l_cm_line_balance, l_cm_tax_balance;

                    CLOSE c_cm_balance;

                    IF l_cm_balance > 0
                    THEN
                        IF NVL (c_cma.exchange_order_type, '~') IN
                               ('EE', 'AE', 'RE',
                                'RR', 'PE')
                        THEN
                            -- apply CM to invoice(s) of the same order
                            FOR c_inv IN c_order_invoice (c_cma.order_number)
                            LOOP
                                l_apply_amt   :=
                                    LEAST (l_cm_balance, c_inv.inv_balance);
                                do_ar_utils.apply_credit_memo_to_invoice (
                                    p_customer_id          =>
                                        c_inv.bill_to_customer_id,
                                    p_bill_to_site_id      =>
                                        c_inv.bill_to_site_use_id,
                                    p_cm_cust_trx_id       =>
                                        c_cma.customer_trx_id,
                                    p_inv_cust_trx_id      =>
                                        c_inv.customer_trx_id,
                                    p_amount_to_apply      => l_apply_amt,
                                    p_application_date     => TRUNC (SYSDATE),
                                    p_module               => NULL,
                                    p_module_version       => NULL,
                                    x_ret_stat             => l_app_status,
                                    x_rec_application_id   => l_rec_appl_id,
                                    x_error_msg            => l_err_msg);

                                IF l_err_msg IS NOT NULL
                                THEN
                                    msg (
                                           'Unable to apply CM to Invoice ID: '
                                        || c_cma.customer_trx_id,
                                        100);
                                    msg ('Error Message: ' || l_err_msg, 100);
                                    l_adj_status   := fnd_api.g_ret_sts_error;
                                ELSE
                                    msg (
                                           'Successfully applied CM to Invoice ID: '
                                        || c_cma.customer_trx_id,
                                        100);

                                    IF l_apply_amt = c_inv.inv_balance
                                    THEN
                                        UPDATE oe_order_lines_all ool
                                           SET ool.attribute20 = 'CM', ool.attribute19 = 'APPLIED', ool.attribute17 = fnd_api.g_ret_sts_success
                                         WHERE     ool.header_id =
                                                   c_cma.header_id
                                               AND ool.attribute18 =
                                                   c_cma.line_grp_id
                                               AND EXISTS
                                                       (SELECT 1
                                                          FROM ra_customer_trx_lines_all rctl
                                                         WHERE     rctl.customer_trx_id =
                                                                   c_inv.customer_trx_id
                                                               AND rctl.interface_line_context =
                                                                   'ORDER ENTRY'
                                                               AND rctl.interface_line_attribute6 =
                                                                   TO_CHAR (
                                                                       ool.line_id));
                                    END IF;

                                    l_cm_balance   :=
                                        l_cm_balance - l_apply_amt;

                                    IF l_cm_balance = 0
                                    THEN
                                        EXIT;
                                    END IF;
                                END IF;
                            END LOOP;                         -- Invoices loop
                        END IF;                   -- exchange order type check

                        -- Loop through Payment details
                        FOR c_opd
                            IN c_order_payments (c_cma.header_id,
                                                 c_cma.line_grp_id)
                        LOOP
                            IF     c_opd.payment_type IN ('CC', 'PP', 'GC',
                                                          'SC', 'AD', 'RM',
                                                          'RC')
                               --Added this based on the UAT package change with comment---- added transaction types RM and RC by showkath on 18-AUG-15 --W.r.t Version 1.2
                               AND c_opd.payment_action = 'CHB'
                            THEN
                                msg (
                                       'Payment Type: '
                                    || c_opd.payment_type
                                    || ' Amount: '
                                    || c_opd.payment_amount,
                                    100);
                                l_pmt_status       := fnd_api.g_ret_sts_success;
                                l_err_msg          := NULL;
                                l_adj_amt          :=
                                    LEAST (c_opd.payment_amount,
                                           l_cm_balance);

                                l_adj_activity     := NULL; --Added this based on the UAT package change with comment---- Initialized the variable by showkath. --W.r.t Version 1.2

                                -- derive adjustment activity based on Receipt Method ID

                                cb_params_rec      := NULL;

                                -- create Receipt Batch
                                OPEN c_cb_params (c_cma.header_id);

                                FETCH c_cb_params INTO cb_params_rec;

                                CLOSE c_cb_params;

                                --
                                get_receipt_method (cb_params_rec.ar_receipt_class_id, c_opd.payment_type, cb_params_rec.website_id, cb_params_rec.transactional_curr_code, l_receipt_method_id, l_bank_account_id
                                                    , l_bank_branch_id);

                                OPEN c_adj_activity (l_receipt_method_id);

                                FETCH c_adj_activity INTO l_adj_activity;

                                CLOSE c_adj_activity;

                                l_adj_activity     :=
                                    NVL (l_adj_activity,
                                         c_cma.adj_activity_name);

                                --
                                IF l_adj_activity IS NULL
                                THEN
                                    msg (
                                           'Adjustment Activity Name Setup for Payment Type '
                                        || c_opd.payment_type
                                        || ' is missing - Unable to create Adjustment',
                                        100);
                                    RAISE ex_mis_adj_name;
                                END IF;

                                --Added this based on the UAT package change with comment--
                                --
                                l_payment_amount   := 0;
                                -- Added by showkath to fix the partial adjustment bug --W.r.t Version 1.2
                                l_payment_amount   := c_opd.payment_amount;

                                -- Added by showkath to fix the partial adjustment bug --W.r.t Version 1.2

                                WHILE (l_payment_amount > 0)
                                LOOP
                                    -- Added by showkath to fix the partial adjustment bug
                                    --IF l_cm_balance = c_opd.payment_amount -- commented by showkath to fix partial adj issue --W.r.t Version 1.2
                                    IF l_cm_balance = l_payment_amount -- added by showkath to fix partial adj issue --W.r.t Version 1.2
                                    THEN
                                        l_adj_type   := 'INVOICE';
                                        l_adj_amt    :=
                                            --LEAST (l_cm_balance, c_opd.payment_amount);-- commented by showkath to fix partial adj issue --W.r.t Version 1.2
                                             LEAST (l_cm_balance,
                                                    l_payment_amount); -- added by showkath to fix partial adj issue  --W.r.t Version 1.2
                                    ELSIF l_cm_tax_balance > 0
                                    THEN
                                        l_adj_type   := 'TAX';
                                        l_adj_amt    :=
                                            LEAST (l_cm_tax_balance, --c_opd.payment_amount -- commented by showkath to fix partial adj issue --W.r.t Version 1.2
                                                   l_payment_amount -- added by showkath to fix partial adj issue --W.r.t Version 1.2
                                                                   );
                                    --Added this based on the UAT package change with comment--
                                    ELSIF l_cm_line_balance > 0
                                    THEN
                                        l_adj_type   := 'LINE';
                                        l_adj_amt    :=
                                            LEAST (l_cm_line_balance, --c_opd.payment_amount --Added this based on the UAT package change with comment---- commented by showkath to fix partial adj issue --W.r.t Version 1.2
                                                   l_payment_amount --Added this based on the UAT package change with comment---- added by showkath to fix partial adj issue --W.r.t Version 1.2
                                                                   );
                                    END IF;

                                    -- Create Adjustment
                                    do_ar_utils.create_adjustment_trans (
                                        p_customer_trx_id   =>
                                            c_cma.customer_trx_id,
                                        p_activity_name   => l_adj_activity,
                                        p_type            => l_adj_type,
                                        p_amount          => l_adj_amt,
                                        p_reason_code     => 'CB-CRME',
                                        p_gl_date         =>
                                            c_opd.payment_date,
                                        p_adj_date        =>
                                            c_opd.payment_date,
                                        p_comments        =>
                                               'Credit Memo# '
                                            || c_cma.trx_number
                                            || ' Refund. PG Ref: '
                                            || c_opd.pg_reference_num,
                                        p_auto_commit     => 'N',
                                        x_adj_id          => l_adj_id,
                                        x_adj_number      => l_adj_number,
                                        x_error_msg       => l_err_msg);

                                    IF l_err_msg IS NOT NULL
                                    THEN
                                        msg (
                                               'Unable to create Adjustment for Credit Memo #: '
                                            || c_cma.trx_number,
                                            100);
                                        msg ('Error Message: ' || l_err_msg,
                                             100);
                                        l_pmt_status   :=
                                            fnd_api.g_ret_sts_error;
                                        EXIT;
                                    ELSE
                                        l_cm_balance   :=
                                            l_cm_balance - l_adj_amt;

                                        IF l_adj_type = 'TAX'
                                        THEN
                                            l_cm_tax_balance   :=
                                                l_cm_tax_balance - l_adj_amt;
                                        ELSIF l_adj_type = 'LINE'
                                        THEN
                                            l_cm_line_balance   :=
                                                l_cm_line_balance - l_adj_amt;
                                        END IF;

                                        msg (
                                               'Successfully created Adjustment#: '
                                            || l_adj_number
                                            || ' for Credit Memo #: '
                                            || c_cma.trx_number,
                                            100);
                                    END IF;              -- adjustment success

                                    --
                                    IF l_pmt_status =
                                       fnd_api.g_ret_sts_success
                                    THEN
                                        UPDATE xxdoec_order_payment_details
                                           --Added this based on the UAT package change with comment----- Modified by showkath to fix the partial adjustment bug --W.r.t Version 1.2
                                           SET unapplied_amount = --c_opd.payment_amount - l_adj_amt, -- commented by showkath to fix partial adj issue --W.r.t Version 1.2
                                                                  l_payment_amount - l_adj_amt, -- added by showkath to fix partial payment issue --W.r.t Version 1.2
                                                                                                status = DECODE (SIGN ( --c_opd.payment_amount -- commented by showkath to fix partial adj issue --W.r.t Version 1.2
                                                                                                                       l_payment_amount -- added by showkath to fix partial payment issue --W.r.t Version 1.2
                                                                                                                                        - l_adj_amt), 0, 'CL', 'OP')
                                         WHERE payment_id = c_opd.payment_id;

                                        l_payment_amount   :=
                                            l_payment_amount - l_adj_amt; -- added by showkath to fix partial payment issue --W.r.t Version 1.2
                                    ELSE
                                        l_adj_status   :=
                                            fnd_api.g_ret_sts_error;
                                    END IF;

                                    --
                                    IF (l_cm_balance = 0 OR l_payment_amount = 0)
                                    -- added by showkath to fix the partial adjustment bug --W.r.t Version 1.2
                                    THEN
                                        EXIT;
                                    END IF;
                                --
                                END LOOP;
                            --Added this based on the UAT package change with comment---- Modified by showkath to fix the partial adjustment bug --W.r.t Version 1.2

                            END IF;              -- payment type, Action check

                            IF l_cm_balance = 0
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;                             -- Payments loop
                    END IF;                           -- CM balance zero check

                    --
                    IF l_adj_status = fnd_api.g_ret_sts_success
                    THEN
                        IF l_cm_balance = 0
                        THEN
                            UPDATE oe_order_lines_all ool
                               SET ool.attribute20 = 'CMA', ool.attribute19 = 'ADJUSTED', ool.attribute17 = fnd_api.g_ret_sts_success
                             WHERE     ool.attribute20 = c_cma.status_code
                                   AND ool.header_id = c_cma.header_id
                                   AND ool.attribute18 = c_cma.line_grp_id
                                   AND EXISTS
                                           (SELECT 1
                                              FROM ra_customer_trx_lines_all rctl
                                             WHERE     rctl.customer_trx_id =
                                                       c_cma.customer_trx_id
                                                   AND rctl.interface_line_context =
                                                       'ORDER ENTRY'
                                                   AND rctl.interface_line_attribute6 =
                                                       TO_CHAR (ool.line_id));

                            msg (
                                   'Successfully Processed Credit Memo#: '
                                || c_cma.trx_number,
                                100);
                        ELSE
                            msg (
                                   'Credit Memo#: '
                                || c_cma.trx_number
                                || ' has a balance of $'
                                || l_cm_balance,
                                100);
                        END IF;

                        COMMIT;
                    ELSE
                        msg (
                            'Unable to Process Credit Memo#: ' || c_cma.trx_number,
                            100);
                        ROLLBACK;
                    END IF;
                END IF;                                 -- OM, CM totals match
            EXCEPTION
                WHEN ex_mis_adj_name
                THEN
                    x_retcode   := 1;
                    x_errbuf    := 'Please setup Adjustment Activity Name';
                    ROLLBACK;
                WHEN OTHERS
                THEN
                    x_retcode   := 1;
                    x_errbuf    :=
                           'Unexpected Error occured while processing Order Header ID: '
                        || c_cma.header_id
                        || ' Lines Group ID: '
                        || c_cma.line_grp_id
                        || SQLERRM;
                    ROLLBACK;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    := 'Unexpected Error occured ' || SQLERRM;
    END create_cm_adjustment;

    PROCEDURE ship_confirm_delivery (p_delivery_id IN NUMBER, x_rtn_status OUT VARCHAR2, x_rtn_msg OUT VARCHAR2)
    IS
        -- Local variables here
        l_trip_id         NUMBER;
        l_trip_name       VARCHAR2 (120);
        l_msg_count       NUMBER;
        l_msg_data        VARCHAR2 (2000);
        l_msg_index_out   NUMBER;
        l_user_id         NUMBER;
        l_resp_id         NUMBER;
        l_resp_appl_id    NUMBER;

        CURSOR c_cb_params (c_delivery_id IN NUMBER)
        IS
            SELECT cbp.transaction_user_id, cbp.erp_login_resp_id, cbp.erp_login_app_id
              FROM wsh_delivery_assignments wda, wsh_delivery_details wdd, hz_cust_accounts hca,
                   xxdoec_country_brand_params cbp
             WHERE     wdd.delivery_detail_id = wda.delivery_detail_id
                   AND hca.cust_account_id = wdd.customer_id
                   AND cbp.website_id = hca.attribute18
                   AND wda.delivery_id = c_delivery_id
                   AND wdd.released_status = 'Y';
    BEGIN
        OPEN c_cb_params (p_delivery_id);

        FETCH c_cb_params INTO l_user_id, l_resp_id, l_resp_appl_id;

        IF c_cb_params%NOTFOUND
        THEN
            CLOSE c_cb_params;

            x_rtn_status   := fnd_api.g_ret_sts_error;
            x_rtn_msg      :=
                   'Delivery ID: '
                || p_delivery_id
                || ' is not valid for Ship Confirm action';
        ELSE
            CLOSE c_cb_params;

            --do_apps_initialize(l_user_id, l_resp_id, l_resp_appl_id);
            wsh_deliveries_pub.delivery_action (
                p_api_version_number        => 1.0,
                p_init_msg_list             => 'T',
                x_return_status             => x_rtn_status,
                x_msg_count                 => l_msg_count,
                x_msg_data                  => l_msg_data,
                p_action_code               => 'CONFIRM',
                p_delivery_id               => p_delivery_id,
                p_sc_intransit_flag         => 'Y',
                p_sc_close_trip_flag        => 'Y',
                p_sc_defer_interface_flag   => 'N',
                x_trip_id                   => l_trip_id,
                x_trip_name                 => l_trip_name);

            IF     (x_rtn_status = fnd_api.g_ret_sts_error OR x_rtn_status = fnd_api.g_ret_sts_unexp_error)
               AND l_msg_count > 0
            THEN
                -- Retrieve messages
                FOR i IN 1 .. l_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                     , p_msg_index_out => l_msg_index_out);
                    x_rtn_msg   :=
                        SUBSTR (x_rtn_msg || l_msg_data || CHR (13), 1, 2000);
                END LOOP;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status   := fnd_api.g_ret_sts_unexp_error;
            x_rtn_msg      := SQLERRM;
    END ship_confirm_delivery;

    PROCEDURE get_line_groups_to_process_re (
        pn_header_id       IN     NUMBER,
        p_order_driver     IN     VARCHAR2,
        p_line_group_cur      OUT line_group_cur,
        pv_errbuf             OUT VARCHAR2,
        pn_retcode            OUT NUMBER)
    IS
        ln_group_id      NUMBER;
        lv_line_grp_id   VARCHAR2 (120);
        l_err_num        NUMBER := -1;                        --error handling
        l_err_msg        VARCHAR2 (100) := '';                --error handling
        l_message        VARCHAR2 (1000) := '';       --for message processing
        l_runnum         NUMBER := 0;
        l_rc             NUMBER := 0;                     --New for DCDLogging
        l_debug          NUMBER := 0;
        -- change to 1 if debugging using a script in Toad.
        l_step           VARCHAR2 (200) := 'START';
        dcdlog           dcdlog_type
            := dcdlog_type (p_code => -10001, p_application => g_application, p_logeventtype => 4
                            , p_tracelevel => 1, p_debug => l_debug); -- instantiate object with startup message.
        dcdlogparams     dcdlogparameters_type
                             := dcdlogparameters_type (NULL, NULL, NULL,
                                                       NULL);

        -- This cursor will return only exchanges/return  that are ready for
        -- Payment gateway.  they will be combinations of CHB and PGC only.
        CURSOR grp_lines_cur_exre IS
            SELECT /*+ parallel(2) */
                   a.header_id header_id,                    -- group by order
                                          a.attribute20 status_code, -- group on action required
                                                                     a.attribute19 result_code,
                   -- group on last reason code, if any
                   a.attribute16 pgc_trans_num -- group on PG transaction if any
              FROM apps.oe_order_lines_all a
             WHERE a.header_id IN
                       (SELECT DISTINCT oola.header_id
                          FROM apps.oe_order_lines_all oola
                               JOIN apps.oe_order_headers_all ooha
                                   ON oola.header_id = ooha.header_id
                               JOIN apps.oe_transaction_types_all oott
                                   ON ooha.order_type_id =
                                      oott.transaction_type_id
                               JOIN xxdo.xxdoec_poldriver b
                                   ON oola.attribute20 = b.status_code
                         WHERE     oola.attribute20 IS NOT NULL
                               AND oola.attribute17 IN ('N', 'E')
                               AND NVL (oott.attribute13, '~') IN
                                       ('RE', 'EE', 'RR',
                                        'AE', 'ER', 'PE')
                               AND b.event_driver = 'REC'
                               -- RE gets passed in, but we use REC for CHG/PGC
                               --commented start by BT Technology Team on 09-01-2015
                               --AND oola.order_source_id IN (1044, 0)
                               AND oola.order_source_id IN
                                       (SELECT order_source_id
                                          FROM oe_order_sources
                                         WHERE NAME IN
                                                   ('Flagstaff', 'Online'))
                               --commented End by BT Technology Team on 09-01-2015
                               AND NOT EXISTS
                                       ( -- select any line in this order not cancelled and not PGC or CHB and not N, E
                                        SELECT 1
                                          FROM apps.oe_order_lines_all ool
                                               --This means any line other then what we want will get
                                               LEFT JOIN
                                               xxdo.xxdoec_poldriver c
                                                   ON     NVL (
                                                              ool.attribute20,
                                                              '~') =
                                                          c.status_code
                                                      AND c.event_driver =
                                                          'REC'
                                         WHERE     header_id = oola.header_id --this order thrown out by returning 1
                                               AND ool.cancelled_flag = 'N' --no cancelled lines
                                               AND c.status_code IS NULL))
            -- Add this union select to return only CP 'lost shipment' orders to the returns/exchange processor
            UNION ALL
            SELECT /*+ parallel(2) */
                   a.header_id header_id,                    -- group by order
                                          a.attribute20 status_code, -- group on action required
                                                                     a.attribute19 result_code,
                   -- group on last reason code, if any
                   a.attribute16 pgc_trans_num -- group on PG transaction if any
              FROM apps.oe_order_lines_all a
             WHERE a.header_id IN
                       (SELECT DISTINCT oola.header_id
                          FROM apps.oe_order_lines_all oola
                               JOIN apps.oe_order_headers_all ooha
                                   ON oola.header_id = ooha.header_id
                               JOIN apps.oe_transaction_types_all oott
                                   ON ooha.order_type_id =
                                      oott.transaction_type_id
                         --JOIN xxdo.xxdoec_POLDriver b
                         --   ON oola.attribute20 = b.status_code
                         WHERE     oola.attribute20 IS NOT NULL
                               AND oola.attribute17 IN ('N', 'E')
                               AND NVL (oott.attribute13, '~') IN ('CP')
                               --AND b.event_driver = 'REC' -- RE gets passed in, but we use REC for CHG/PGC
                               --commented start by BT Technology Team on 09-01-2015
                               --AND oola.order_source_id IN (1044, 0));
                               AND oola.order_source_id IN
                                       (SELECT order_source_id
                                          FROM oe_order_sources
                                         WHERE NAME IN
                                                   ('Flagstaff', 'Online')));

        --commented End by BT Technology Team on 09-01-2015
        -- This cursor will return exchanges/return lines for any other
        -- type of order not in (PGC, CHB)
        CURSOR grp_lines_cur_or IS
            SELECT /*+ parallel(2) */
                   DISTINCT oola.header_id header_id,        -- group by order
                                                      oola.attribute20 status_code, -- group on action required
                                                                                    oola.attribute19 result_code,
                            -- group on last reason code, if any
                            oola.attribute16 pgc_trans_num
              -- group on PG transaction if any
              FROM apps.oe_order_lines_all oola
                   JOIN apps.oe_order_headers_all c
                       ON oola.header_id = c.header_id
                   JOIN apps.oe_transaction_types_all b
                       ON c.order_type_id = b.transaction_type_id
                   JOIN xxdo.xxdoec_poldriver d
                       ON oola.attribute20 = d.status_code
             WHERE     oola.attribute20 IS NOT NULL
                   AND oola.attribute17 IN ('N', 'E')
                   -- newly needing processing, or previous error
                   AND oola.header_id = NVL (pn_header_id, oola.header_id)
                   -- optionaly force a particular order
                   --commented start by BT Technology Team on 09-01-2015
                   --AND oola.order_source_id IN (1044, 0)
                   AND oola.order_source_id IN
                           (SELECT order_source_id
                              FROM oe_order_sources
                             WHERE NAME IN ('Flagstaff', 'Online'))
                   --commented End by BT Technology Team on 09-01-2015
                   -- restrict to flagstaff orders, plus manually created in oracle
                   AND NVL (b.attribute13, '~') IN ('RE', 'EE', 'RR',
                                                    'AE', 'ER', 'PE')
                   AND d.event_driver = p_order_driver;
    BEGIN
        --Get run number from sequence field.
        SELECT xxdo.xxdoec_pol_runnum_seq.NEXTVAL INTO l_runnum FROM DUAL;

        -- Set the parent Id to be this run number.  This will make it easier to find these log records
        -- later on during research.
        dcdlog.parentid               := l_runnum;
        --This run number will stay with this object for the life of this execution.
        dcdlog.functionname           := 'get_line_groups_to_process_re';
        -- Add parameters to the collection one at a time.
        dcdlogparams.parametername    := 'Run number';
        dcdlogparams.parametervalue   := TO_CHAR (l_runnum);
        dcdlogparams.parametertype    := 'NUMBER';
        dcdlog.addparameter (dcdlogparams);
        l_rc                          := dcdlog.loginsert (); -- Insert log records.

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;

        -- Spin through the regular order cursor.  Update it as normal grouping line
        -- group id's for each status code.  So a PGC will get a different line group id
        -- than say a CHB.
        FOR grp_lines_rec IN grp_lines_cur_or
        LOOP
            BEGIN
                SELECT xxdo.xxdoec_order_lines_group_s.NEXTVAL
                  INTO ln_group_id
                  FROM DUAL;

                lv_line_grp_id        := TO_CHAR (ln_group_id);

                --        Original...
                UPDATE oe_order_lines_all oola
                   SET oola.attribute18 = lv_line_grp_id, oola.attribute17 = 'P' -- mark as processing
                 WHERE     oola.header_id = grp_lines_rec.header_id
                       AND oola.attribute20 = grp_lines_rec.status_code
                       AND NVL (oola.attribute19, '~') =
                           NVL (grp_lines_rec.result_code, '~')
                       -- group same reason codes together, if assigned
                       AND oola.attribute17 IN ('N', 'E')
                       -- newly needing processing, or previous error
                       AND NVL (oola.attribute16, '~') =
                           NVL (grp_lines_rec.pgc_trans_num, '~');

                -- group same auths together, if assigned

                -- Log the lines that have been picked for processing.
                dcdlog.changecode (p_code => -10006, p_application => g_application, p_logeventtype => 2
                                   , p_tracelevel => 2, p_debug => l_debug);
                dcdlog.functionname   := 'get_line_groups_to_process_re.or';
                dcdlog.addparameter ('header_id',
                                     TO_CHAR (grp_lines_rec.header_id),
                                     'NUMBER');
                dcdlog.addparameter ('status_code',
                                     grp_lines_rec.status_code,
                                     'VARCHAR2');
                dcdlog.addparameter ('result_code',
                                     grp_lines_rec.result_code,
                                     'VARCHAR2');
                dcdlog.addparameter ('pgc_trans_num',
                                     grp_lines_rec.pgc_trans_num,
                                     'VARCHAR2');
                l_rc                  := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;
            END;
        END LOOP;

        COMMIT;

        -- Now spin through the exchanges/returns.
        -- This cursor should only pick up those that are at CHB and PGC respectively.
        -- These we will not group on the status code (PGC, CHG) as they both need
        -- to have the same line group id when going to the payment gateway.
        FOR grp_lines_rec IN grp_lines_cur_exre
        LOOP
            BEGIN
                SELECT xxdo.xxdoec_order_lines_group_s.NEXTVAL
                  INTO ln_group_id
                  FROM DUAL;

                lv_line_grp_id        := TO_CHAR (ln_group_id);

                UPDATE oe_order_lines_all oola
                   SET oola.attribute18 = lv_line_grp_id, oola.attribute17 = 'P' -- mark as processing
                 WHERE     oola.header_id = grp_lines_rec.header_id
                       AND oola.cancelled_flag <> 'Y';

                --AND oola.attribute20 = grp_lines_rec.status_code
                --AND NVL(oola.attribute19, '~') = NVL(grp_lines_rec.result_code, '~')
                -- group same reason codes together, if assigned
                --AND oola.attribute17 IN ('N', 'E')
                -- newly needing processing, or previous error
                --AND NVL(oola.attribute16, '~') = NVL(grp_lines_rec.pgc_trans_num, '~');
                -- group same auths together, if assigned

                -- Standard logging...
                -- Log the lines that have been picked for processing.
                dcdlog.changecode (p_code => -10006, p_application => g_application, p_logeventtype => 2
                                   , p_tracelevel => 2, p_debug => l_debug);
                dcdlog.functionname   := 'get_line_groups_to_process_re.exre';
                dcdlog.addparameter ('header_id',
                                     TO_CHAR (grp_lines_rec.header_id),
                                     'NUMBER');
                dcdlog.addparameter ('status_code',
                                     grp_lines_rec.status_code,
                                     'VARCHAR2');
                dcdlog.addparameter ('result_code',
                                     grp_lines_rec.result_code,
                                     'VARCHAR2');
                dcdlog.addparameter ('pgc_trans_num',
                                     grp_lines_rec.pgc_trans_num,
                                     'VARCHAR2');
                l_rc                  := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;
            END;
        END LOOP;

        COMMIT;

        OPEN p_line_group_cur FOR
              SELECT /*+ parallel(2) */
                     DISTINCT
                     oola.header_id,
                     oola.attribute18 AS line_grp_id,
                     --oola.attribute19 AS result_code,
                     NULL AS result_code,
                     (CASE
                          WHEN oola.attribute20 IN ('PGC', 'CHB')
                          THEN
                              (SELECT DECODE (SIGN (pt.product_selling_price_total + ftt.freight_charge_total + ftt.freight_discount_total + ftt.gift_wrap_total + ftt.tax_total_no_vat), -1, -- If DECODE(SIGN is -1 we are a CHB else we are a PGC
                                                                                                                                                                                              'CHB', -- Only send back the line we need to charge or credit
                                                                                                                                                                                                     'PGC')
                                 FROM apps.xxdoec_oe_order_product_totals pt, apps.xxdoec_oe_order_frt_tax_totals ftt
                                WHERE     pt.header_id =
                                          oola.header_id
                                      AND pt.attribute18 =
                                          oola.attribute18
                                      AND ftt.header_id =
                                          oola.header_id
                                      AND ftt.attribute18 =
                                          oola.attribute18)
                          ELSE
                              oola.attribute20
                      END) AS status_code,
                     --               oola.attribute16 AS pgc_trans_num,
                     (SELECT /*+ parallel(2) */
                             MAX (attribute16)
                        FROM apps.oe_order_lines_all
                       WHERE     header_id = oola.header_id
                             AND attribute17 = 'P') pgc_trans_num,
                     NULL AS header_id_orig_order,
                     NULL AS line_grp_id_orig_order,
                     (SELECT /*+ parallel(2) */
                             MIN (b.attribute16)
                        FROM apps.oe_order_lines_all a
                             JOIN apps.oe_order_lines_all b
                                 ON a.reference_line_id = b.line_id
                       WHERE     a.header_id = oola.header_id
                             AND a.attribute17 = 'P') pgc_trans_num_orig_order,
                     (SELECT COUNT (*)
                        FROM apps.oe_order_lines_all
                       -- total lines (for CA)
                       WHERE header_id = oola.header_id) total_lines
                FROM apps.oe_order_lines_all oola, apps.oe_order_lines_all oola_orig, apps.oe_order_headers_all ooha,
                     apps.oe_transaction_types_all oota
               WHERE     oola.attribute17 = 'P'        -- currently processing
                     AND oola.reference_line_id = oola_orig.line_id(+)
                     -- optionally get original order line (for return)
                     AND oola.header_id = NVL (pn_header_id, oola.header_id)
                     -- optionaly force a particular order
                     AND ooha.header_id = oola.header_id
                     AND oota.transaction_type_id = ooha.order_type_id
                     AND NVL (oota.attribute13, '~') IN ('RE', 'EE', 'RR',
                                                         'AE', 'ER', 'PE')
            ORDER BY 4;                           -- which is oola.attribute20

        dcdlog.changecode (p_code => -10018, p_application => g_application, p_logeventtype => 4
                           , p_tracelevel => 2, p_debug => l_debug);
        dcdlog.functionname           := 'get_line_groups_to_process_re';
        l_rc                          := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;

        dcdlog.changecode (p_code => -10019, p_application => g_application, p_logeventtype => 4
                           , p_tracelevel => 1, p_debug => l_debug);
        dcdlog.functionname           := 'get_line_groups_to_process_re';
        dcdlog.addparameter ('End', TO_CHAR (CURRENT_TIMESTAMP), 'TIMESTAMP');
        l_rc                          := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                l_err_num             := SQLCODE;
                l_err_msg             := SUBSTR (SQLERRM, 1, 100);
                l_message             := 'ERROR marking lines for processing:  ';
                l_message             :=
                       l_step
                    || l_message
                    || ' err_num='
                    || TO_CHAR (l_err_num)
                    || ' err_msg='
                    || l_err_msg
                    || '.';
                dcdlog.changecode (p_code => -10017, p_application => g_application, p_logeventtype => 1
                                   , p_tracelevel => 1, p_debug => l_debug);
                dcdlog.functionname   := 'get_line_groups_to_process_re';
                dcdlog.addparameter ('l_step', l_step, 'VARCHAR2');
                dcdlog.addparameter ('SQLCODE',
                                     TO_CHAR (l_err_num),
                                     'NUMBER');
                dcdlog.addparameter ('SQLERRM', l_err_msg, 'VARCHAR2');
                l_rc                  := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;

                pn_retcode            := 2;
                pv_errbuf             :=
                    'Unexpected Error occured ' || SQLERRM;
                dcdlog.changecode (p_code => -10017, p_application => g_application, p_logeventtype => 1
                                   , p_tracelevel => 1, p_debug => l_debug);
                dcdlog.functionname   := 'get_line_groups_to_process_re';
                l_rc                  := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;
            END;
    END;

    ---------------------------------------------------------
    PROCEDURE get_line_groups_to_process_or (
        pn_header_id       IN     NUMBER,
        p_order_driver     IN     VARCHAR2,
        p_line_group_cur      OUT line_group_cur,
        pv_errbuf             OUT VARCHAR2,
        pn_retcode            OUT NUMBER)
    IS
        l_step           VARCHAR2 (200) := 'initial:  ';
        --what step are we on?
        ln_group_id      NUMBER;
        lv_line_grp_id   VARCHAR2 (120);
        l_err_num        NUMBER := -1;                        --error handling
        l_err_msg        VARCHAR2 (100) := '';                --error handling
        l_message        VARCHAR2 (1000) := '';       --for message processing
        l_runnum         NUMBER := 0;
        l_rc             NUMBER := 0;                     --New for DCDLogging
        l_debug          NUMBER := 0;
        l_days           NUMBER := 3;
        --DEFAULT 72 HOURS, THIS NEEDS TO COME FROM BFF AS A PARAMETER.
        l_charge         VARCHAR2 (3) := 'NO';
        l_total_lines    NUMBER := 0;
        l_pgc_count      NUMBER := 0;
        -- change to 1 if debugging using a script in Toad.
        dcdlog           dcdlog_type
            := dcdlog_type (p_code => -10001, p_application => g_application, p_logeventtype => 4
                            , p_tracelevel => 1, p_debug => l_debug); -- instantiate object with startup message.
        dcdlogparams     dcdlogparameters_type
                             := dcdlogparameters_type (NULL, NULL, NULL,
                                                       NULL);

        CURSOR grp_lines_cur IS
              SELECT /*+ parallel(2) */
                     DISTINCT oola.header_id                 -- group by order
                                            , oola.attribute20 status_code -- group on action required
                                                                          , oola.attribute19 result_code -- group on last reason code, if any
                                                                                                        ,
                              oola.attribute16 pgc_trans_num -- group on PG transaction if any
                                                            --            ,(SELECT COUNT (*)
                                                            --                FROM apps.oe_order_lines_all -- total lines (for CA)
                                                            --                WHERE header_id = oola.header_id and oola.cancelled_flag <> 'Y')
                                                            --            total_lines
                                                            --            ,(SELECT COUNT (*)
                                                            --                FROM apps.oe_order_lines_all
                                                            --                WHERE header_id = oola.header_id and oola.attribute20 = 'PGC' and oola.attribute17 IN ('N','E','M')
                                                            --                and oola.flow_status_code IN ('INVOICED')) --WAITING TO BE CAPTURED
                                                            --            pgc_count
                                                            , ooha.ordered_date, oola.flow_status_code
                FROM apps.oe_order_lines_all oola
                     JOIN apps.oe_order_headers_all ooha
                         ON oola.header_id = ooha.header_id
                     JOIN apps.oe_transaction_types_all oott
                         ON ooha.order_type_id = oott.transaction_type_id
                     JOIN xxdo.xxdoec_poldriver d
                         ON oola.attribute20 = d.status_code
               WHERE     oola.attribute20 IS NOT NULL
                     AND oola.attribute17 IN ('N', 'E')
                     -- newly needing processing, or previous error
                     AND oola.header_id = NVL (pn_header_id, oola.header_id)
                     -- optionaly force a particular order
                     --commented start by BT Technology Team on 09-01-2015
                     --AND oola.order_source_id IN (1044, 0)
                     AND oola.order_source_id IN
                             (SELECT order_source_id
                                FROM oe_order_sources
                               WHERE NAME IN ('Flagstaff', 'Online'))
                     --commented End by BT Technology Team on 09-01-2015
                     -- restrict to flagstaff orders, plus manually created in oracle
                     AND (NVL (oott.attribute13, '~') NOT IN ('RE', 'EE', 'RR',
                                                              'AE', 'ER', 'CP',
                                                              'PE'))
                     AND d.event_driver = p_order_driver                   --;
            ORDER BY oola.header_id;
    -- initially this will be:  CA - Channel Advisor or RO - Regular Orders
    -- See xxdo.xxdoec_POLDriver table
    BEGIN
        l_step                        := 'POL OR Identify lines:  ';

        --Get run number from sequence field.
        SELECT xxdo.xxdoec_pol_runnum_seq.NEXTVAL INTO l_runnum FROM DUAL;

        SELECT ROUND (NVL (ss_wait_hours, 72)) / 24
          INTO l_days
          FROM xxdo.xxdoec_country_brand_params
         WHERE ROWNUM < 2;

        -- Set the parent Id to be this run number.  This will make it easier to find these log records
        -- later on during research.
        dcdlog.parentid               := l_runnum;
        --This run number will stay with this object for the life of this execution.
        dcdlog.functionname           := 'get_line_groups_to_process_or';
        -- Add parameters to the collection one at a time.
        dcdlogparams.parametername    := 'Run number';
        dcdlogparams.parametervalue   := TO_CHAR (l_runnum);
        dcdlogparams.parametertype    := 'NUMBER';
        dcdlog.addparameter (dcdlogparams);
        l_rc                          := dcdlog.loginsert (); -- Insert log records.

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;

        --************************************
        -- all lines needing processing without exchanges
        -- do the line grouping operation
        --************************************
        FOR grp_lines_rec IN grp_lines_cur
        LOOP
            BEGIN
                SELECT xxdo.xxdoec_order_lines_group_s.NEXTVAL
                  INTO ln_group_id
                  FROM DUAL;

                l_total_lines         := 0;
                l_pgc_count           := 0;

                -- Following two count selects were being done in the original cursor SQL
                -- But they were not working right.
                SELECT /*+ parallel(2) */
                       COUNT (*)
                  INTO l_total_lines
                  FROM apps.oe_order_lines_all oola    -- total lines on order
                 WHERE     header_id = grp_lines_rec.header_id
                       AND oola.cancelled_flag <> 'Y';

                SELECT /*+ parallel(2) */
                       COUNT (*)
                  INTO l_pgc_count
                  FROM apps.oe_order_lines_all oola
                 -- total lines waiting to be charged.
                 WHERE     header_id = grp_lines_rec.header_id
                       AND oola.attribute20 = 'PGC'
                       AND oola.attribute17 IN ('N', 'E', 'M')
                       AND oola.flow_status_code IN ('INVOICED');

                dcdlog.changecode (p_code => -10053, p_application => g_application, p_logeventtype => 2
                                   , p_tracelevel => 2, p_debug => l_debug);
                dcdlog.addparameter ('header_id',
                                     TO_CHAR (grp_lines_rec.header_id),
                                     'NUMBER');
                dcdlog.addparameter ('header_id',
                                     TO_CHAR (grp_lines_rec.header_id),
                                     'NUMBER');
                dcdlog.addparameter ('status_code',
                                     grp_lines_rec.status_code,
                                     'VARCHAR2');
                dcdlog.addparameter ('result_code',
                                     grp_lines_rec.result_code,
                                     'VARCHAR2');
                dcdlog.addparameter ('pgc_trans_num',
                                     grp_lines_rec.pgc_trans_num,
                                     'VARCHAR2');
                dcdlog.addparameter ('total_lines', l_total_lines, 'NUMBER');
                dcdlog.addparameter ('pgc_count', l_pgc_count, 'NUMBER');
                dcdlog.addparameter ('ordered_date',
                                     grp_lines_rec.ordered_date,
                                     'DATE');
                l_rc                  := dcdlog.loginsert ();
                lv_line_grp_id        := TO_CHAR (ln_group_id);
                -- Changes for split shipment charge project
                l_charge              := 'NO';

                IF (l_total_lines > 1)
                THEN        -- If we only have one line then old logic applies
                    dcdlog.changecode (p_code => -10053, p_application => g_application, p_logeventtype => 2
                                       , p_tracelevel => 2, p_debug => l_debug);
                    dcdlog.addparameter ('IF (l_total_lines > 1)',
                                         'YES',
                                         'VARCHAR2');
                    dcdlog.addparameter ('header_id',
                                         TO_CHAR (grp_lines_rec.header_id),
                                         'NUMBER');
                    l_rc   := dcdlog.loginsert ();

                    IF (l_pgc_count = l_total_lines)
                    THEN
                        -- AND they are all PGC lines - just let them through
                        dcdlog.changecode (p_code           => -10053,
                                           p_application    => g_application,
                                           p_logeventtype   => 2,
                                           p_tracelevel     => 2,
                                           p_debug          => l_debug);
                        dcdlog.addparameter (
                            'IF (l_pgc_count = l_total_lines)',
                            'YES',
                            'VARCHAR2');
                        dcdlog.addparameter (
                            'header_id',
                            TO_CHAR (grp_lines_rec.header_id),
                            'NUMBER');
                        l_rc       := dcdlog.loginsert ();
                        l_charge   := 'YES';
                    ELSE
                        IF (SYSDATE > grp_lines_rec.ordered_date + l_days)
                        THEN
                            -- Also let it go through to be marked for pickup by BFF (setting attribute17 = 'P').
                            l_charge   := 'YES';
                            dcdlog.changecode (
                                p_code           => -10053,
                                p_application    => g_application,
                                p_logeventtype   => 2,
                                p_tracelevel     => 2,
                                p_debug          => l_debug);
                            dcdlog.addparameter (
                                'IF (grp_lines_rec.ordered_date > grp_lines_rec.ordered_date + l_days)',
                                'YES',
                                'VARCHAR2');
                            dcdlog.addparameter (
                                'header_id',
                                TO_CHAR (grp_lines_rec.header_id),
                                'NUMBER');
                            l_rc       := dcdlog.loginsert ();
                        END IF;
                    END IF;
                ELSE
                    -- Only 1 line, just process it, no logic necessary here
                    dcdlog.changecode (p_code => -10053, p_application => g_application, p_logeventtype => 2
                                       , p_tracelevel => 2, p_debug => l_debug);
                    dcdlog.addparameter ('ELSE IF (l_total_lines > 1',
                                         'NO',
                                         'VARCHAR2');
                    dcdlog.addparameter ('header_id',
                                         TO_CHAR (grp_lines_rec.header_id),
                                         'NUMBER');
                    l_rc       := dcdlog.loginsert ();
                    l_charge   := 'YES';
                END IF;

                IF l_charge = 'YES'
                THEN
                    --        Original code fitted inside split shipment IF STMT...
                    --**  NEW SPLIT SHIPMENT CODE
                    --**  Update them all including PGC as we've decided it's ready to go...
                    UPDATE oe_order_lines_all oola
                       SET oola.attribute18 = lv_line_grp_id, oola.attribute17 = 'P' -- mark as processing
                     WHERE     oola.header_id = grp_lines_rec.header_id
                           AND oola.attribute20 = grp_lines_rec.status_code
                           AND NVL (oola.attribute19, '~') =
                               NVL (grp_lines_rec.result_code, '~')
                           -- group same reason codes together, if assigned
                           AND oola.attribute17 IN ('N', 'E')
                           -- newly needing processing, or previous error
                           AND NVL (oola.attribute16, '~') =
                               NVL (grp_lines_rec.pgc_trans_num, '~');

                    dcdlog.changecode (p_code => -10053, p_application => g_application, p_logeventtype => 2
                                       , p_tracelevel => 2, p_debug => l_debug);
                    dcdlog.addparameter ('header_id',
                                         TO_CHAR (grp_lines_rec.header_id),
                                         'NUMBER');
                    dcdlog.addparameter ('CHARGING ANY AND ALL',
                                         'YES',
                                         'VARCHAR2');
                    l_rc   := dcdlog.loginsert ();
                -- group same auths together, if assigned
                ELSE
                    --** NEW SPLIT SHIPMENT CODE
                    --** Update them all exception for PGC as they are not ready yet...
                    UPDATE oe_order_lines_all oola
                       SET oola.attribute18 = lv_line_grp_id, oola.attribute17 = 'P' -- mark as processing
                     WHERE     oola.header_id = grp_lines_rec.header_id
                           AND oola.attribute20 = grp_lines_rec.status_code
                           AND NVL (oola.attribute19, '~') =
                               NVL (grp_lines_rec.result_code, '~')
                           -- group same reason codes together, if assigned
                           AND oola.attribute17 IN ('N', 'E')
                           -- newly needing processing, or previous error
                           AND NVL (oola.attribute16, '~') =
                               NVL (grp_lines_rec.pgc_trans_num, '~')
                           AND NVL (oola.attribute20, 'XXX') <> 'PGC';

                    -- group same auths together, if assigned
                    dcdlog.changecode (p_code => -10053, p_application => g_application, p_logeventtype => 2
                                       , p_tracelevel => 2, p_debug => l_debug);
                    dcdlog.addparameter ('header_id',
                                         TO_CHAR (grp_lines_rec.header_id),
                                         'NUMBER');
                    dcdlog.addparameter ('CHARGING ALL BUT PGC',
                                         'YES',
                                         'VARCHAR2');
                    l_rc   := dcdlog.loginsert ();
                END IF;

                -- end split shipment charge

                -- Log the lines that have been picked for processing.
                dcdlog.changecode (p_code => -10010, p_application => g_application, p_logeventtype => 2
                                   , p_tracelevel => 2, p_debug => l_debug);
                dcdlog.functionname   := 'get_line_groups_to_process_or';
                dcdlog.addparameter ('header_id',
                                     TO_CHAR (grp_lines_rec.header_id),
                                     'NUMBER');
                dcdlog.addparameter ('status_code',
                                     grp_lines_rec.status_code,
                                     'VARCHAR2');
                dcdlog.addparameter ('result_code',
                                     grp_lines_rec.result_code,
                                     'VARCHAR2');
                dcdlog.addparameter ('pgc_trans_num',
                                     grp_lines_rec.pgc_trans_num,
                                     'VARCHAR2');
                l_rc                  := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_retcode   := 1;
                    pv_errbuf    :=
                           'Unable to set lines to processing and assign group id. Status Code: '
                        || grp_lines_rec.status_code
                        || ' - Order Header ID: '
                        || grp_lines_rec.header_id
                        || ' - Group ID: '
                        || lv_line_grp_id;
                    msg (pv_errbuf);
            END;
        END LOOP;

        l_step                        := 'POL OR return lines.';

        -- now return the group ids that need processing
        OPEN p_line_group_cur FOR
              SELECT /*+ parallel(2) */
                     DISTINCT
                     oola.header_id,
                     oola.attribute18 AS line_grp_id,
                     oola.attribute19 AS result_code,
                     oola.attribute20 AS status_code,
                     -- what action needs to be taken
                     oola.attribute16 AS pgc_trans_num,
                     -- transaction reference number for payment gateway
                     oola_orig.header_id AS header_id_orig_order,
                     -- header_id of original order when this is a return
                     oola_orig.attribute18 AS line_grp_id_orig_order,
                     -- line group of original order when this is a return
                     oola_orig.attribute16 AS pgc_trans_num_orig_order,
                     -- line group of original order when this is a return
                     (SELECT COUNT (*)
                        FROM apps.oe_order_lines_all
                       -- total lines (for CA)
                       WHERE header_id = oola.header_id) total_lines
                FROM oe_order_lines_all oola, apps.oe_order_lines_all oola_orig, apps.oe_order_headers_all ooha,
                     apps.oe_transaction_types_all oott, xxdo.xxdoec_poldriver d
               WHERE     oola.attribute17 = 'P'        -- currently processing
                     AND oola.header_id = ooha.header_id
                     AND ooha.order_type_id = oott.transaction_type_id
                     AND oola.attribute20 = d.status_code
                     AND oola.reference_line_id = oola_orig.line_id(+)
                     -- optionally get original order line (for return)
                     AND oola.header_id = NVL (pn_header_id, oola.header_id)
                     -- optionaly force a particular order
                     AND (NVL (oott.attribute13, '~') NOT IN ('RE', 'EE', 'RR',
                                                              'AE', 'ER', 'PE'))
                     AND d.event_driver = p_order_driver
            ORDER BY oola.attribute20             -- sort by the action needed
                                     , oola.header_id;

        dcdlog.changecode (p_code => -10018, p_application => g_application, p_logeventtype => 4
                           , p_tracelevel => 2, p_debug => l_debug);
        dcdlog.functionname           := 'get_line_groups_to_process_or';
        l_rc                          := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;

        dcdlog.changecode (p_code => -10019, p_application => g_application, p_logeventtype => 4
                           , p_tracelevel => 1, p_debug => l_debug);
        dcdlog.functionname           := 'get_line_groups_to_process_or';
        dcdlog.addparameter ('End', TO_CHAR (CURRENT_TIMESTAMP), 'TIMESTAMP');
        l_rc                          := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                l_err_num             := SQLCODE;
                l_err_msg             := SUBSTR (SQLERRM, 1, 100);
                l_message             := 'ERROR marking lines for processing:  ';
                l_message             :=
                       l_step
                    || l_message
                    || ' err_num='
                    || TO_CHAR (l_err_num)
                    || ' err_msg='
                    || l_err_msg
                    || '.';
                dcdlog.changecode (p_code => -10017, p_application => g_application, p_logeventtype => 1
                                   , p_tracelevel => 1, p_debug => l_debug);
                dcdlog.functionname   := 'get_line_groups_to_process_or';
                dcdlog.addparameter ('l_step', l_step, 'VARCHAR2');
                dcdlog.addparameter ('SQLCODE',
                                     TO_CHAR (l_err_num),
                                     'NUMBER');
                dcdlog.addparameter ('SQLERRM', l_err_msg, 'VARCHAR2');
                l_rc                  := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;

                pn_retcode            := 2;
                pv_errbuf             :=
                    'Unexpected Error occured ' || SQLERRM;
                dcdlog.changecode (p_code => -10017, p_application => g_application, p_logeventtype => 1
                                   , p_tracelevel => 1, p_debug => l_debug);
                dcdlog.functionname   := 'get_line_groups_to_process_or';
                l_rc                  := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;
            END;

            pn_retcode   := 2;
            pv_errbuf    := 'Unexpected Error occured ' || SQLERRM;
    END get_line_groups_to_process_or;

    PROCEDURE get_line_groups_to_process_orn (pn_header_id IN NUMBER, p_order_driver IN VARCHAR2, p_count IN NUMBER, p_codes IN ttbl_status_codes, p_line_group_cur OUT line_group_cur, p_order_header_cur OUT order_header_cur
                                              , p_order_line_cur OUT order_line_cur, pv_errbuf OUT VARCHAR2, pn_retcode OUT NUMBER)
    IS
        l_step                          VARCHAR2 (200) := 'initial:  ';
        --what step are we on?
        ln_group_id                     NUMBER;
        lv_line_grp_id                  VARCHAR2 (120);
        l_err_num                       NUMBER := -1;
        --error handling
        l_err_msg                       VARCHAR2 (100) := '';
        --error handling
        l_message                       VARCHAR2 (1000) := '';
        --for message processing
        l_runnum                        NUMBER := 0;
        l_rc                            NUMBER := 0;
        --New for DCDLogging
        l_debug                         NUMBER := 0;
        l_days                          NUMBER := 3;
        --DEFAULT 72 HOURS, THIS NEEDS TO COME FROM BFF AS A PARAMETER.
        l_charge                        VARCHAR2 (3) := 'NO';
        l_total_lines                   NUMBER := 0;
        l_pgc_count                     NUMBER := 0;
        l_line_count                    NUMBER := 500;
        l_rtn_status                    VARCHAR2 (100) := '';
        --new INC0097749
        l_rtn_message                   VARCHAR2 (500) := '';
        --new INC0097749
        l_orig_order_id                 VARCHAR2 (240) := '-1';
        l_list                          xxdoec_upc_list := xxdoec_upc_list ();
        l_header_id                     NUMBER := -1;
        l_order_header_cur              SYS_REFCURSOR;
        l_order_line_cur                SYS_REFCURSOR;
        l_retcode                       NUMBER := 0;
        l_errbuf                        VARCHAR2 (4000) := '';
        l_loop_count                    NUMBER := 0;
        --order header local variables
        l_line_grp_id                   VARCHAR2 (240);
        l_orig_sys_document_ref         VARCHAR2 (50);
        l_account_number                VARCHAR2 (50);
        l_person_first_name             VARCHAR2 (150);
        l_person_last_name              VARCHAR2 (150);
        l_email_address                 VARCHAR2 (2000);
        l_bill_to_address1              VARCHAR2 (240);
        l_bill_to_address2              VARCHAR2 (240);
        l_bill_to_city                  VARCHAR2 (60);
        l_bill_to_state                 VARCHAR2 (60);
        l_bill_to_postal_code           VARCHAR2 (60);
        l_bill_to_country               VARCHAR2 (60);
        l_ship_to_address1              VARCHAR2 (240);
        l_ship_to_address2              VARCHAR2 (240);
        l_ship_to_city                  VARCHAR2 (60);
        l_ship_to_state                 VARCHAR2 (60);
        l_ship_to_postal_code           VARCHAR2 (60);
        l_ship_to_country               VARCHAR2 (60);
        l_product_list_price_total      NUMBER;
        l_product_selling_price_total   NUMBER;
        l_freight_charge_total          NUMBER;
        l_gift_wrap_total               NUMBER;
        l_tax_total_no_vat              NUMBER;
        l_vat_total                     NUMBER;
        l_order_total                   NUMBER;
        l_discount_total                NUMBER;
        l_freight_discount_total        NUMBER;
        l_currency                      VARCHAR2 (15);
        l_locale                        VARCHAR2 (240);
        l_site                          VARCHAR2 (240);
        l_oraclegenerated               VARCHAR2 (1);
        l_order_type_id                 VARCHAR2 (240);
        l_original_order_number         VARCHAR2 (240);
        --commented start by kcopeland 4/21/2016. This code was not ported from 12.1.3
        l_order_subtype                 apps.oe_order_headers_all.global_attribute18%TYPE;
        l_store_id                      apps.oe_order_headers_all.global_attribute19%TYPE;
        l_contact_phone                 VARCHAR2 (40);
        l_is_closet_order               VARCHAR2 (5);
        --commented End by kcopeland 4/21/2016
        --comment start by kcopeland 7/11/2016. New variable
        l_is_emp_purch_order            VARCHAR2 (1) := 'N';
        --comment end
        /*Start of change as part of verison 1.7  */
        l_cod_charge_total              NUMBER := 0;
        /*End of change as part of verison 1.7  */
        --Order line details local variables
        l_l_upc                         VARCHAR2 (240);
        l_l_model_number                VARCHAR2 (40);
        l_l_color_code                  VARCHAR2 (40);
        l_l_color_name                  VARCHAR2 (240);
        l_l_product_size                VARCHAR2 (40);
        l_l_product_name                VARCHAR2 (240);
        l_l_ordered_qty                 NUMBER;
        l_l_unit_selling_price          NUMBER;
        l_l_unit_list_price             NUMBER;
        l_l_selling_price_subtotal      NUMBER;
        l_l_list_price_subtotal         NUMBER;
        l_l_tracking_number             VARCHAR2 (30);
        l_l_carrier                     VARCHAR2 (30);
        l_l_shipping_method             VARCHAR2 (80);
        l_l_line_number                 NUMBER;
        l_l_line_id                     NUMBER;
        l_l_header_id                   NUMBER;
        l_l_line_grp_id                 VARCHAR2 (240);
        l_l_inventory_item_id           NUMBER;
        l_l_fluid_recipe_id             VARCHAR2 (50);
        l_l_organization_id             NUMBER;
        l_l_freight_charge              NUMBER;
        l_l_freight_tax                 NUMBER;
        l_l_tax_amount                  NUMBER;
        l_l_gift_wrap_charge            NUMBER;
        l_l_gift_wrap_tax               NUMBER;
        l_l_reason_code                 apps.oe_reasons.reason_code%TYPE;
        l_l_meaning                     apps.fnd_lookup_values.meaning%TYPE;
        l_l_user_name                   apps.fnd_user.user_name%TYPE;
        l_l_cancel_date                 apps.oe_reasons.creation_date%TYPE;
        l_l_localized_color             apps.oe_order_lines_all.global_attribute19%TYPE;
        l_l_localized_size              apps.oe_order_lines_all.global_attribute20%TYPE;
        l_l_is_final_sale_item          VARCHAR2 (5) := 'false';
        l_l_ship_to_address1            VARCHAR2 (240);
        l_l_ship_to_address2            VARCHAR2 (240);
        l_l_ship_to_city                VARCHAR2 (240);
        l_l_ship_to_state               VARCHAR2 (240);
        l_l_ship_to_postalcode          VARCHAR2 (240);
        l_l_ship_to_country             VARCHAR2 (240);
        l_l_ship_to_site_use_id         NUMBER;
        /*Start of change as part of verison 1.7  */
        l_l_cod_charge                  NUMBER := 0;
        /*End of change as part of verison 1.7  */
        -- change to 1 if debugging using a script in Toad.
        dcdlog                          dcdlog_type
            := dcdlog_type (p_code => -10001, p_application => g_application, p_logeventtype => 4
                            , p_tracelevel => 1, p_debug => l_debug); -- instantiate object with startup message.
        dcdlogparams                    dcdlogparameters_type
                                            := dcdlogparameters_type (NULL, NULL, NULL
                                                                      , NULL);

        CURSOR grp_lines_cur IS
            SELECT /*+ parallel(2) */
                   header_id, result_code, status_code,
                   pgc_trans_num, ordered_date, flow_status_code,
                   orig_order_id
              FROM apps.gtt_line_group_detail
             WHERE ROWNUM <= l_line_count;

        CURSOR grp_line_header_cur IS
              SELECT /*+ parallel(2) */
                     gtt.header_id, gtt.line_id, gtt.line_grp_id
                FROM apps.gtt_line_group_detail gtt
               WHERE gtt.process_flag = 'P'
            GROUP BY gtt.header_id, gtt.line_id, gtt.line_grp_id;
    -- initially this will be:  CA - Channel Advisor or RO - Regular Orders
    -- See xxdo.xxdoec_POLDriver table
    BEGIN
        l_step                        := 'POL OR Identify lines:  ';

        --Clear out the global temp tables from any previous run
        DELETE apps.gtt_line_group_detail;

        DELETE apps.gtt_line_group_header_detail;

        DELETE apps.gtt_line_group_line_detail;

        IF (p_count > 0)
        THEN
            l_line_count   := p_count;
        END IF;

        --Get run number from sequence field.
        SELECT xxdo.xxdoec_pol_runnum_seq.NEXTVAL INTO l_runnum FROM DUAL;

        --1.9  moving the following select to inside cursor loop - CCR0007741
        /*
        SELECT ROUND (NVL (ss_wait_hours, 72)) / 24
          INTO l_days
          FROM xxdo.xxdoec_country_brand_params
         WHERE ROWNUM < 2;
        */
        --Convert the input list of status codes to a table list that can be used in the below select stmt.
        l_list.EXTEND (p_codes.COUNT);

        FOR i IN p_codes.FIRST .. p_codes.LAST
        LOOP
            l_list (i)   := p_codes (i);
        END LOOP;

        -- Set the parent Id to be this run number.  This will make it easier to find these log records
        -- later on during research.
        dcdlog.parentid               := l_runnum;
        --This run number will stay with this object for the life of this execution.
        dcdlog.functionname           := 'get_line_groups_to_process_orn';
        -- Add parameters to the collection one at a time.
        dcdlogparams.parametername    := 'Run number';
        dcdlogparams.parametervalue   := TO_CHAR (l_runnum);
        dcdlogparams.parametertype    := 'NUMBER';
        dcdlog.addparameter (dcdlogparams);
        l_rc                          := dcdlog.loginsert (); -- Insert log records.

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;

        INSERT INTO apps.gtt_line_group_detail
              SELECT /*+ parallel(2) */
                     DISTINCT oola.header_id, oola.line_id, oola.reference_line_id,
                              NULL, oola.attribute20, oola.attribute19,
                              oola.attribute16, oott.attribute13, ooha.ordered_date,
                              oola.flow_status_code, NULL, NULL
                FROM apps.oe_order_lines_all oola
                     JOIN apps.oe_order_headers_all ooha
                         ON oola.header_id = ooha.header_id
                     JOIN apps.oe_transaction_types_all oott
                         ON ooha.order_type_id = oott.transaction_type_id
                     JOIN xxdo.xxdoec_poldriver d
                         ON oola.attribute20 = d.status_code
                     JOIN apps.oe_order_sources oos
                         ON oos.order_source_id = oola.order_source_id
               WHERE     oola.attribute20 IS NOT NULL
                     AND oola.attribute17 IN (SELECT * FROM TABLE (l_list))
                     -- newly needing processing, or previous error
                     AND oola.header_id = NVL (pn_header_id, oola.header_id)
                     -- optionaly force a particular order
                     --commented start by BT Technology Team on 09-01-2015
                     --AND oola.order_source_id IN (1044, 0)
                     --------------------------------------
                     -- Commenting for performance tuning
                     --------------------------------------
                     --AND oola.order_source_id IN
                     --                         (SELECT order_source_id
                     --                            FROM oe_order_sources
                     --                           WHERE NAME IN ('Flagstaff', 'Online'))
                     ----------------------------------------
                     -- Commenting for performance tuning
                     ---------------------------------------
                     ----------------------------------------
                     -- Adding for performance tuning
                     ----------------------------------------
                     AND oos.name IN ('Flagstaff', 'Online')
                     ----------------------------------------
                     -- End of change for performance tuning
                     ----------------------------------------
                     --commented End by BT Technology Team on 09-01-2015
                     -- re ('RE', 'EE', 'RR', 'AE', 'ER', 'CP', 'PE'))
                     AND (NVL (oott.attribute13, '~') NOT IN ('RE', 'EE', 'RR',
                                                              'AE', 'ER', 'PE'))
                     AND d.event_driver = p_order_driver
            ORDER BY oola.header_id;

        --************************************
        -- all lines needing processing without exchanges
        -- do the line grouping operation
        --************************************
        FOR grp_lines_rec IN grp_lines_cur
        LOOP
            BEGIN
                SELECT xxdo.xxdoec_order_lines_group_s.NEXTVAL
                  INTO ln_group_id
                  FROM DUAL;

                l_total_lines         := 0;
                l_pgc_count           := 0;
                l_loop_count          := l_loop_count + 1;

                --1.9 Moved to inside loop and added new filter to make it valid per website instead of just the first value in the table-CCR0007741
                SELECT NVL (ss_wait_hours, 72)
                  INTO l_days
                  FROM xxdo.xxdoec_country_brand_params
                 WHERE     website_id =
                           (SELECT hca.attribute18
                              FROM apps.oe_order_headers_all ooh, apps.hz_cust_accounts hca
                             WHERE     hca.cust_account_id =
                                       ooh.sold_to_org_id
                                   AND ooh.header_id =
                                       grp_lines_rec.header_id)
                       AND ROWNUM < 2;


                --Keeps track of the number of lines processed. Used to exit loop when input parameter p_count is reached which makes sure only that many records are set to 'P' in the oe_order_lines_all table.

                -- Following two count selects were being done in the original cursor SQL
                -- But they were not working right.
                SELECT /*+ parallel(2) */
                       COUNT (1)
                  INTO l_total_lines
                  FROM apps.oe_order_lines_all oola    -- total lines on order
                 WHERE     header_id = grp_lines_rec.header_id
                       AND oola.cancelled_flag <> 'Y';

                SELECT /*+ parallel(2) */
                       COUNT (1)
                  INTO l_pgc_count
                  FROM apps.oe_order_lines_all oola
                 -- total lines waiting to be charged.
                 WHERE     header_id = grp_lines_rec.header_id
                       AND oola.attribute20 = 'PGC'
                       AND oola.attribute17 IN ('N', 'E', 'M')
                       AND oola.flow_status_code IN ('INVOICED');

                dcdlog.changecode (p_code => -10053, p_application => g_application, p_logeventtype => 2
                                   , p_tracelevel => 2, p_debug => l_debug);
                dcdlog.addparameter ('header_id',
                                     TO_CHAR (grp_lines_rec.header_id),
                                     'NUMBER');
                dcdlog.addparameter ('header_id',
                                     TO_CHAR (grp_lines_rec.header_id),
                                     'NUMBER');
                dcdlog.addparameter ('status_code',
                                     grp_lines_rec.status_code,
                                     'VARCHAR2');
                dcdlog.addparameter ('result_code',
                                     grp_lines_rec.result_code,
                                     'VARCHAR2');
                dcdlog.addparameter ('pgc_trans_num',
                                     grp_lines_rec.pgc_trans_num,
                                     'VARCHAR2');
                dcdlog.addparameter ('total_lines', l_total_lines, 'NUMBER');
                dcdlog.addparameter ('pgc_count', l_pgc_count, 'NUMBER');
                dcdlog.addparameter ('ordered_date',
                                     grp_lines_rec.ordered_date,
                                     'DATE');
                l_rc                  := dcdlog.loginsert ();
                lv_line_grp_id        := TO_CHAR (ln_group_id);
                -- Changes for split shipment charge project
                l_charge              := 'NO';

                IF (l_total_lines > 1)
                THEN        -- If we only have one line then old logic applies
                    dcdlog.changecode (p_code => -10053, p_application => g_application, p_logeventtype => 2
                                       , p_tracelevel => 2, p_debug => l_debug);
                    dcdlog.addparameter ('IF (l_total_lines > 1)',
                                         'YES',
                                         'VARCHAR2');
                    dcdlog.addparameter ('header_id',
                                         TO_CHAR (grp_lines_rec.header_id),
                                         'NUMBER');
                    l_rc   := dcdlog.loginsert ();

                    IF (l_pgc_count = l_total_lines)
                    THEN
                        -- AND they are all PGC lines - just let them through
                        dcdlog.changecode (p_code           => -10053,
                                           p_application    => g_application,
                                           p_logeventtype   => 2,
                                           p_tracelevel     => 2,
                                           p_debug          => l_debug);
                        dcdlog.addparameter (
                            'IF (l_pgc_count = l_total_lines)',
                            'YES',
                            'VARCHAR2');
                        dcdlog.addparameter (
                            'header_id',
                            TO_CHAR (grp_lines_rec.header_id),
                            'NUMBER');
                        l_rc       := dcdlog.loginsert ();
                        l_charge   := 'YES';
                    ELSE
                        --1.9 modified following if statement to use the ss_wait_hours as hours instead of days - CCR0007741
                        -- IF (SYSDATE > grp_lines_rec.ordered_date + l_days)
                        IF (SYSDATE > (grp_lines_rec.ordered_date + NUMTODSINTERVAL (TO_CHAR (l_days), 'HOUR')))
                        THEN
                            -- Also let it go through to be marked for pickup by BFF (setting attribute17 = 'P').
                            l_charge   := 'YES';
                            dcdlog.changecode (
                                p_code           => -10053,
                                p_application    => g_application,
                                p_logeventtype   => 2,
                                p_tracelevel     => 2,
                                p_debug          => l_debug);
                            dcdlog.addparameter (
                                'IF (grp_lines_rec.ordered_date > grp_lines_rec.ordered_date + l_days)',
                                'YES',
                                'VARCHAR2');
                            dcdlog.addparameter (
                                'header_id',
                                TO_CHAR (grp_lines_rec.header_id),
                                'NUMBER');
                            l_rc       := dcdlog.loginsert ();
                        END IF;
                    END IF;
                ELSE
                    -- Only 1 line, just process it, no logic necessary here
                    dcdlog.changecode (p_code => -10053, p_application => g_application, p_logeventtype => 2
                                       , p_tracelevel => 2, p_debug => l_debug);
                    dcdlog.addparameter ('ELSE IF (l_total_lines > 1',
                                         'NO',
                                         'VARCHAR2');
                    dcdlog.addparameter ('header_id',
                                         TO_CHAR (grp_lines_rec.header_id),
                                         'NUMBER');
                    l_rc       := dcdlog.loginsert ();
                    l_charge   := 'YES';
                END IF;

                IF l_charge = 'YES'
                THEN
                    --        Original code fitted inside split shipment IF STMT...
                    --**  NEW SPLIT SHIPMENT CODE
                    --**  Update them all including PGC as we've decided it's ready to go...
                    UPDATE apps.gtt_line_group_detail oola
                       SET oola.line_grp_id = lv_line_grp_id, oola.process_flag = 'P' -- mark as processing
                     WHERE     oola.header_id = grp_lines_rec.header_id
                           AND oola.status_code = grp_lines_rec.status_code
                           AND NVL (oola.result_code, '~') =
                               NVL (grp_lines_rec.result_code, '~')
                           -- newly needing processing, or previous error
                           AND NVL (oola.pgc_trans_num, '~') =
                               NVL (grp_lines_rec.pgc_trans_num, '~');

                    dcdlog.changecode (p_code => -10053, p_application => g_application, p_logeventtype => 2
                                       , p_tracelevel => 2, p_debug => l_debug);
                    dcdlog.addparameter ('header_id',
                                         TO_CHAR (grp_lines_rec.header_id),
                                         'NUMBER');
                    dcdlog.addparameter ('CHARGING ANY AND ALL',
                                         'YES',
                                         'VARCHAR2');
                    l_rc   := dcdlog.loginsert ();
                -- group same auths together, if assigned
                ELSE
                    --** NEW SPLIT SHIPMENT CODE
                    --** Update them all exception for PGC as they are not ready yet...
                    UPDATE apps.gtt_line_group_detail oola
                       SET line_grp_id = lv_line_grp_id, process_flag = 'P' -- mark as processing
                     WHERE     oola.header_id = grp_lines_rec.header_id
                           AND oola.status_code = grp_lines_rec.status_code
                           AND NVL (oola.result_code, '~') =
                               NVL (grp_lines_rec.result_code, '~')
                           -- group same reason codes together, if assigned
                           -- newly needing processing, or previous error
                           AND NVL (oola.pgc_trans_num, '~') =
                               NVL (grp_lines_rec.pgc_trans_num, '~')
                           AND NVL (oola.status_code, 'XXX') <> 'PGC';

                    -- group same auths together, if assigned
                    dcdlog.changecode (p_code => -10053, p_application => g_application, p_logeventtype => 2
                                       , p_tracelevel => 2, p_debug => l_debug);
                    dcdlog.addparameter ('header_id',
                                         TO_CHAR (grp_lines_rec.header_id),
                                         'NUMBER');
                    dcdlog.addparameter ('CHARGING ALL BUT PGC',
                                         'YES',
                                         'VARCHAR2');
                    l_rc   := dcdlog.loginsert ();
                END IF;

                -- end split shipment charge

                -- Log the lines that have been picked for processing.
                dcdlog.changecode (p_code => -10010, p_application => g_application, p_logeventtype => 2
                                   , p_tracelevel => 2, p_debug => l_debug);
                dcdlog.functionname   := 'get_line_groups_to_process_orn';
                dcdlog.addparameter ('header_id',
                                     TO_CHAR (grp_lines_rec.header_id),
                                     'NUMBER');
                dcdlog.addparameter ('status_code',
                                     grp_lines_rec.status_code,
                                     'VARCHAR2');
                dcdlog.addparameter ('result_code',
                                     grp_lines_rec.result_code,
                                     'VARCHAR2');
                dcdlog.addparameter ('pgc_trans_num',
                                     grp_lines_rec.pgc_trans_num,
                                     'VARCHAR2');
                l_rc                  := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;

                --Exit the loop if we have processed the requested number of lines.
                IF (l_loop_count >= l_line_count)
                THEN
                    EXIT;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_retcode   := 1;
                    pv_errbuf    :=
                           'Unable to set lines to processing and assign group id. Status Code: '
                        || grp_lines_rec.status_code
                        || ' - Order Header ID: '
                        || grp_lines_rec.header_id
                        || ' - Group ID: '
                        || lv_line_grp_id;
                    msg (pv_errbuf);
            END;
        END LOOP;

        l_step                        := 'Setting group lines to processing';
        msg (l_step);

        UPDATE oe_order_lines_all oola
           SET oola.attribute17        = 'P',
               oola.attribute18       =
                   (SELECT gtt.line_grp_id
                      FROM apps.gtt_line_group_detail gtt
                     WHERE     oola.header_id = gtt.header_id
                           AND oola.line_id = gtt.line_id
                           AND oola.attribute20 = gtt.status_code) -----------------------------------------------------
                          -- Added By Sivakumar Boothathan for Peak Alert V1.4
                         -----------------------------------------------------
               ,
               oola.last_update_date   = SYSDATE
         -----------------------------------------------------
         --End of change By Sivakumar boothathan for peak alert  V1.4
         -----------------------------------------------------
         WHERE EXISTS
                   (SELECT 1
                      FROM apps.gtt_line_group_detail gtt
                     WHERE     oola.header_id = gtt.header_id
                           AND oola.line_id = gtt.line_id
                           AND oola.attribute20 = gtt.status_code
                           AND gtt.process_flag = 'P');

        COMMIT;

        FOR grp_lines_header_rec IN grp_line_header_cur
        --Call get_lines_in_groups for each header_id/line_group_id combination.
        LOOP
            apps.xxdoec_process_order_lines.get_lines_in_group (
                pn_header_id         => grp_lines_header_rec.header_id,
                pv_line_grp_id       => grp_lines_header_rec.line_grp_id,
                p_order_header_cur   => l_order_header_cur,
                --sys_refcursor
                p_order_line_cur     => l_order_line_cur,
                --sys_refcursor
                pv_errbuf            => l_errbuf,
                pn_retcode           => l_retcode);

            --insert order header details to gtt_line_group_header_detail from l_order_header_cursor for final selection
            LOOP
                FETCH l_order_header_cur
                    INTO l_header_id, l_line_grp_id, l_orig_sys_document_ref, l_account_number,
                         l_person_first_name, l_person_last_name, l_email_address,
                         l_bill_to_address1, l_bill_to_address2, l_bill_to_city,
                         l_bill_to_state, l_bill_to_postal_code, l_bill_to_country,
                         l_ship_to_address1, l_ship_to_address2, l_ship_to_city,
                         l_ship_to_state, l_ship_to_postal_code, l_ship_to_country,
                         l_product_list_price_total, l_product_selling_price_total, l_freight_charge_total,
                         l_gift_wrap_total, l_tax_total_no_vat, l_vat_total,
                         l_order_total, l_discount_total, l_freight_discount_total,
                         l_currency, l_locale, l_site,
                         l_oraclegenerated, l_order_type_id, l_original_order_number,
                         --commented start by kcopeland 4/21/2016. This code was not ported from 12.1.3
                         l_order_subtype, l_store_id, l_contact_phone,
                         --commented End by kcopeland 4/21/2016
                         l_is_closet_order, l_is_emp_purch_order, /*Start of change as part of verison 1.7  */
                                                                  l_cod_charge_total;

                /*End of change as part of verison 1.7  */

                INSERT INTO gtt_line_group_header_detail (header_id, line_grp_id, orig_sys_document_ref, account_number, person_first_name, person_last_name, email_address, bill_to_address1, bill_to_address2, bill_to_city, bill_to_state, bill_to_postal_code, bill_to_country, ship_to_address1, ship_to_address2, ship_to_city, ship_to_state, ship_to_postal_code, ship_to_country, product_list_price_total, product_selling_price_total, freight_charge_total, gift_wrap_total, tax_total_no_vat, vat_total, order_total, discount_total, freight_discount_total, currency, locale, site, oraclegenerated, order_type_id, original_order_number, --commented start by kcopeland 4/21/2016. This code was not ported from 12.1.3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          order_subtype, store_id, contact_phone, --commented End by kcopeland 4/21/2016)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  --commented start by kcopeland 12/14/2016
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  is_closet_order, is_emp_purch_order
                                                          , /*Start of change as part of verison 1.7  */
                                                            cod_charge_total/*End of change as part of verison 1.7  */
                                                                            )
                     VALUES (l_header_id, l_line_grp_id, l_orig_sys_document_ref, l_account_number, l_person_first_name, l_person_last_name, l_email_address, l_bill_to_address1, l_bill_to_address2, l_bill_to_city, l_bill_to_state, l_bill_to_postal_code, l_bill_to_country, l_ship_to_address1, l_ship_to_address2, l_ship_to_city, l_ship_to_state, l_ship_to_postal_code, l_ship_to_country, l_product_list_price_total, l_product_selling_price_total, l_freight_charge_total, l_gift_wrap_total, l_tax_total_no_vat, l_vat_total, l_order_total, l_discount_total, l_freight_discount_total, l_currency, l_locale, l_site, l_oraclegenerated, l_order_type_id, l_original_order_number, --commented start by kcopeland 4/21/2016. This code was not ported from 12.1.3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 l_order_subtype, l_store_id, l_contact_phone, --commented End by kcopeland 4/21/2016)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               l_is_closet_order, l_is_emp_purch_order
                             , /*Start of change as part of verison 1.7  */
                               l_cod_charge_total/*End of change as part of verison 1.7  */
                                                 );

                EXIT WHEN l_order_header_cur%NOTFOUND;
            END LOOP;

            CLOSE l_order_header_cur;

            --now do the same thing for the order_details. insert order header details to gtt_line_group_line_detail from l_order_line_cur for final selection
            LOOP
                FETCH l_order_line_cur
                    INTO l_l_upc, l_l_model_number, l_l_color_code, l_l_color_name,
                         l_l_product_size, l_l_product_name, l_l_ordered_qty,
                         l_l_unit_selling_price, l_l_unit_list_price, l_l_selling_price_subtotal,
                         l_l_list_price_subtotal, l_l_tracking_number, l_l_carrier,
                         l_l_shipping_method, l_l_line_number, l_l_line_id,
                         l_l_header_id, l_l_line_grp_id, l_l_inventory_item_id,
                         l_l_fluid_recipe_id, l_l_organization_id, l_l_freight_charge,
                         l_l_freight_tax, l_l_tax_amount, l_l_gift_wrap_charge,
                         l_l_gift_wrap_tax, l_l_reason_code, l_l_meaning,
                         l_l_user_name, l_l_cancel_date, l_l_localized_color,
                         l_l_localized_size, l_l_is_final_sale_item, l_l_ship_to_address1,
                         l_l_ship_to_address2, l_l_ship_to_city, l_l_ship_to_state,
                         l_l_ship_to_postalcode, l_l_ship_to_country, l_l_ship_to_site_use_id,
                         /*Start of change as part of verison 1.7  */
                         l_l_cod_charge/*End of change as part of verison 1.7  */
                                       ;

                INSERT INTO gtt_line_group_line_detail (
                                header_id,
                                line_id,
                                line_grp_id,
                                upc,
                                model_number,
                                color_code,
                                color_name,
                                product_size,
                                product_name,
                                ordered_quantity,
                                unit_selling_price,
                                unit_list_price,
                                selling_price_subtotal,
                                list_price_subtotal,
                                tracking_number,
                                carrier,
                                shipping_method,
                                line_number,
                                inventory_item_id,
                                fluid_recipe_id,
                                organization_id,
                                freight_charge,
                                freight_tax,
                                tax_amount,
                                gift_wrap_charge,
                                gift_wrap_tax,
                                reason_code,
                                meaning,
                                user_name,
                                cancel_date,
                                localized_color,
                                localized_size,
                                is_final_sale_item,
                                ship_to_address1,
                                ship_to_address2,
                                ship_to_city,
                                ship_to_state,
                                ship_to_postal_code,
                                ship_to_country,
                                ship_to_site_use_id,
                                /*Start of change as part of verison 1.7  */
                                cod_charge/*End of change as part of verison 1.7  */
                                          )
                     VALUES (l_l_header_id, l_l_line_id, grp_lines_header_rec.line_grp_id, l_l_upc, l_l_model_number, l_l_color_code, l_l_color_name, l_l_product_size, l_l_product_name, l_l_ordered_qty, l_l_unit_selling_price, l_l_unit_list_price, l_l_selling_price_subtotal, l_l_list_price_subtotal, l_l_tracking_number, l_l_carrier, l_l_shipping_method, l_l_line_number, l_l_inventory_item_id, l_l_fluid_recipe_id, l_l_organization_id, l_l_freight_charge, l_l_freight_tax, l_l_tax_amount, l_l_gift_wrap_charge, l_l_gift_wrap_tax, l_l_reason_code, l_l_meaning, l_l_user_name, l_l_cancel_date, l_l_localized_color, l_l_localized_size, l_l_is_final_sale_item, l_l_ship_to_address1, l_l_ship_to_address2, l_l_ship_to_city, l_l_ship_to_state, l_l_ship_to_postalcode, l_l_ship_to_country
                             , l_l_ship_to_site_use_id, /*Start of change as part of verison 1.7  */
                                                        l_l_cod_charge/*End of change as part of verison 1.7  */
                                                                      );

                EXIT WHEN l_order_line_cur%NOTFOUND;
            END LOOP;

            CLOSE l_order_line_cur;
        END LOOP;

        --populate the final sys_refcursors
        --First the Line Group Detail
        OPEN p_line_group_cur FOR
              SELECT /*+ parallel(2) */
                     DISTINCT
                     oola.header_id,
                     oola.line_grp_id AS line_grp_id,
                     oola.result_code AS result_code,
                     oola.status_code AS status_code,
                     -- what action needs to be taken
                     oola.pgc_trans_num AS pgc_trans_num,
                     --transaction reference number for payment gateway
                     oola_orig.header_id AS header_id_orig_order,
                     -- header_id of original order when this is a return
                     oola_orig.attribute18 AS line_grp_id_orig_order,
                     -- line group of original order when this is a return
                     oola_orig.attribute16 AS pgc_trans_num_orig_order,
                     -- line group of original order when this is a return
                     (SELECT COUNT (*)
                        FROM apps.oe_order_lines_all
                       --total lines (for CA)
                       WHERE header_id = oola.header_id) total_lines
                FROM apps.gtt_line_group_detail oola, apps.oe_order_lines_all oola_orig, apps.oe_order_headers_all ooha
               WHERE     oola.process_flag = 'P'       -- currently processing
                     AND oola.header_id = ooha.header_id
                     AND oola.reference_line_id = oola_orig.line_id(+)
            ORDER BY oola.status_code, -- sort by the action needed                                         ,
                                       oola.header_id;

        --Now the line group order header details
        OPEN p_order_header_cur FOR SELECT /*+ parallel(2) */
                                           DISTINCT header_id, line_grp_id, orig_sys_document_ref,
                                                    account_number, person_first_name, person_last_name,
                                                    email_address, bill_to_address1, bill_to_address2,
                                                    bill_to_city, bill_to_state, bill_to_postal_code,
                                                    bill_to_country, ship_to_address1, ship_to_address2,
                                                    ship_to_city, ship_to_state, ship_to_postal_code,
                                                    ship_to_country, product_list_price_total, product_selling_price_total,
                                                    freight_charge_total, gift_wrap_total, tax_total_no_vat,
                                                    vat_total, order_total, discount_total,
                                                    freight_discount_total, currency, locale,
                                                    site, oraclegenerated, order_type_id,
                                                    original_order_number, --commented start by kcopeland 4/21/2016. This code was not ported from 12.1.3
                                                                           order_subtype, store_id,
                                                    contact_phone, --commented End by kcopeland 4/21/2016
                                                                   is_closet_order, is_emp_purch_order,
                                                    /*Start of change as part of verison 1.7  */
                                                    cod_charge_total
                                      /*End of change as part of verison 1.7  */
                                      FROM apps.gtt_line_group_header_detail;

        --now the line group order line detail
        OPEN p_order_line_cur FOR
            SELECT /*+ parallel(2) */
                   DISTINCT upc,
                            model_number,
                            color_code,
                            color_name,
                            product_size,
                            product_name,
                            ordered_quantity,
                            unit_selling_price,
                            unit_list_price,
                            selling_price_subtotal,
                            list_price_subtotal,
                            tracking_number,
                            carrier,
                            shipping_method,
                            line_number,
                            line_id,
                            header_id,
                            line_grp_id,
                            inventory_item_id,
                            fluid_recipe_id,
                            organization_id,
                            freight_charge,
                            freight_tax,
                            tax_amount,
                            gift_wrap_charge,
                            gift_wrap_tax,
                            reason_code,
                            meaning,
                            user_name,
                            cancel_date,
                            -- ref 2707455 - global_attributes to store localized values
                            localized_size,
                            localized_color,
                            (SELECT CASE
                                        WHEN EXISTS
                                                 (SELECT 1
                                                    FROM XXDO.XXDOEC_ORDER_ATTRIBUTE
                                                   WHERE     ORDER_HEADER_ID =
                                                             gtt_line_group_line_detail.HEADER_ID
                                                         AND ATTRIBUTE_TYPE =
                                                             'FINALSALE'
                                                         AND LINE_ID =
                                                             gtt_line_group_line_detail.LINE_ID)
                                        THEN
                                            'True'
                                        ELSE
                                            'FALSE'
                                    END
                               FROM DUAL) is_final_sale_item,
                            ship_to_address1,
                            ship_to_address2,
                            ship_to_city,
                            ship_to_state,
                            ship_to_postal_code,
                            ship_to_country,
                            ship_to_site_use_id,
                            /*Start of change as part of verison 1.7  */
                            cod_charge
              /*End of change as part of verison 1.7  */
              FROM gtt_line_group_line_detail;

        dcdlog.changecode (p_code => -10018, p_application => g_application, p_logeventtype => 4
                           , p_tracelevel => 2, p_debug => l_debug);
        dcdlog.functionname           := 'get_line_groups_to_process_orn';
        l_rc                          := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;

        dcdlog.changecode (p_code => -10019, p_application => g_application, p_logeventtype => 4
                           , p_tracelevel => 1, p_debug => l_debug);
        dcdlog.functionname           := 'get_line_groups_to_process_orn';
        dcdlog.addparameter ('End', TO_CHAR (CURRENT_TIMESTAMP), 'TIMESTAMP');
        l_rc                          := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                l_err_num             := SQLCODE;
                l_err_msg             := SUBSTR (SQLERRM, 1, 100);
                l_message             := 'ERROR marking lines for processing:  ';
                l_message             :=
                       l_step
                    || l_message
                    || ' err_num='
                    || TO_CHAR (l_err_num)
                    || ' err_msg='
                    || l_err_msg
                    || '.';
                dcdlog.changecode (p_code => -10017, p_application => g_application, p_logeventtype => 1
                                   , p_tracelevel => 1, p_debug => l_debug);
                dcdlog.functionname   := 'get_line_groups_to_process_orn';
                dcdlog.addparameter ('l_step', l_step, 'VARCHAR2');
                dcdlog.addparameter ('SQLCODE',
                                     TO_CHAR (l_err_num),
                                     'NUMBER');
                dcdlog.addparameter ('SQLERRM', l_err_msg, 'VARCHAR2');
                l_rc                  := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;

                pn_retcode            := 2;
                pv_errbuf             :=
                    'Unexpected Error occured ' || SQLERRM;
                dcdlog.changecode (p_code => -10017, p_application => g_application, p_logeventtype => 1
                                   , p_tracelevel => 1, p_debug => l_debug);
                dcdlog.functionname   := 'get_line_groups_to_process_orn';
                l_rc                  := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;
            END;

            pn_retcode   := 2;
            pv_errbuf    := 'Unexpected Error occured ' || SQLERRM;
    END get_line_groups_to_process_orn;

    --------------------------------------------------
    -- Get all the lines that are waiting for some webservice
    -- processing by BFF. This assigns the group id so that
    -- lines can be grouped, and return a cursor of those group ids
    --
    -- Author: Lawrence Walters
    -- Created: 11/4/2010
    -- Modification:  6/28/2011   MB
    --    Modify to exclude exchange orders as they will be picked up elsewhere
    --
    -- Author: Lawrence Walters
    -- Created: 11/4/2010
    -- Modification 8/09/2011 Mike Bacigalupi
    --    Added sub select for fnd_flex_values to eliminate duplicate result record
    --    for virtual gift card.
    -- Modification 9/12/2011 Mike Bacigalupi
    --    Add logic to check for PGA and return order total to avoid authorizing dollar amounts
    --    when it should be zero.
    -- Modification 11/9/2011 Mike Bacigalupi
    --    Add in new DCDLogging code.
    --------------------------------------------------
    PROCEDURE get_lines_in_group (pn_header_id IN NUMBER    -- order header id
                                                        , pv_line_grp_id IN VARCHAR2 -- (optional) line group id (order line attribute18)
                                                                                    , p_order_header_cur OUT order_header_cur
                                  , p_order_line_cur OUT order_line_cur, pv_errbuf OUT VARCHAR2, pn_retcode OUT NUMBER)
    IS
        l_total                         NUMBER := 0;
        l_header_id                     NUMBER := pn_header_id;
        l_line_grp_id                   VARCHAR2 (240) := '';
        l_doing_pga                     NUMBER := 0;
        l_err_num                       NUMBER := -1;         --error handling
        l_err_msg                       VARCHAR2 (100) := ''; --error handling
        l_message                       VARCHAR2 (1000) := '';
        --for message processing
        l_step                          VARCHAR2 (10) := 'START';
        l_rc                            NUMBER := 0;
        --New for DCDLogging
        l_debug                         NUMBER := 0;
        --New for DCDLogging
        dcdlog                          dcdlog_type
                                            := dcdlog_type (p_code => -10036, p_application => g_application, p_logeventtype => 1
                                                            , p_tracelevel => 1, p_debug => 0); --New for DCDLogging

        CURSOR c_cursor IS
            SELECT attribute20, attribute18
              FROM apps.oe_order_lines_all
             WHERE header_id = l_header_id;

        l_status_code                   VARCHAR2 (240) := 'XXX';
        l_flag                          NUMBER := 0;
        l_answer                        VARCHAR2 (240) := 'NONE';
        l_exchange_type                 VARCHAR2 (240) := 'XX';
        l_freight_charge_total          NUMBER := 0;
        l_gift_wrap_total               NUMBER := 0;
        l_tax_total_no_vat              NUMBER := 0;
        l_product_selling_price_total   NUMBER := 0;
        l_freight_discount_total        NUMBER := 0;
        /*Start of change as part of verison 1.7  */
        l_cod_charge_total              NUMBER := 0;
        /*End of change as part of verison 1.7  */
        l_orig_order_id                 VARCHAR2 (240) := '-1';
        --new INC0097749
        l_rtn_status                    VARCHAR2 (100) := ''; --new INC0097749
        l_rtn_message                   VARCHAR2 (500) := ''; --new INC0097749
    BEGIN
        --
        -- First extract the exchange type so we can check and see if its AE, EE or RE
        --
        SELECT NVL (b.attribute13, 'XX')
          INTO l_exchange_type
          FROM apps.oe_order_headers_all a
               JOIN apps.oe_transaction_types_all b
                   ON a.order_type_id = b.transaction_type_id
         WHERE a.header_id = l_header_id;

        --
        -- Then check any line on this order to see if in fact there is a PGA present.
        --
        l_step            := 'STEP2';

        FOR c_status IN c_cursor
        LOOP
            l_status_code   := c_status.attribute20;
            l_line_grp_id   := c_status.attribute18;

            IF (l_status_code = 'PGA')
            THEN
                l_flag   := 1;
            END IF;

            IF     (l_line_grp_id = pv_line_grp_id)
               AND (c_status.attribute20 = 'PGA')
            THEN
                l_doing_pga   := 1;
            END IF;
        END LOOP;

        --IF NVL(l_exchange_type, '~') IN ('EE', 'ER') THEN
        --INC0097749 - return original order id
        l_orig_order_id   :=
            xxdoec_order_utils_pkg.get_orig_order (
                p_order_header_id   => pn_header_id,
                p_rtn_status        => l_rtn_status,
                p_rtn_message       => l_rtn_message);

        --END IF;
        IF l_flag > 0
        THEN
            -- There is a PGA we need to see if this is AE,EE or RE
            --
            -- Get the total price of this order for all lines
            -- because exchange types AE, EE and RE will send the PGA through with only 1 line updated with a line group id.
            -- So this will cause an authorization against a card when there should be none.
            --
            l_step   := 'STEP3';

            IF (l_exchange_type = 'AE' OR l_exchange_type = 'EE' OR l_exchange_type = 'RE')
            THEN
                IF (l_doing_pga = 1)
                THEN
                    -- we are actually processing the PGA line
                    SELECT /*+ parallel(2) */
                           SUM (ROUND (freight_charge_total, 2)), SUM (ROUND (gift_wrap_total, 2)), SUM (ROUND (tax_total_no_vat, 2)),
                           SUM (ROUND (freight_discount_total, 2)), /*Start of change as part of verison 1.7  */
                                                                    SUM (ROUND (cod_charge_total, 0))
                      /*End of change as part of verison 1.7  */
                      INTO l_freight_charge_total, l_gift_wrap_total, l_tax_total_no_vat, l_freight_discount_total,
                                                 /*Start of change as part of verison 1.7  */
                                                 l_cod_charge_total
                      /*End of change as part of verison 1.7  */
                      FROM apps.xxdoec_oe_order_frt_tax_totals
                     WHERE header_id = l_header_id;

                    SELECT SUM (ROUND (product_selling_price_total, 2))
                      INTO l_product_selling_price_total
                      FROM apps.xxdoec_oe_order_product_totals
                     WHERE header_id = l_header_id;

                    l_total   :=
                          l_freight_charge_total
                        + l_gift_wrap_total
                        + l_tax_total_no_vat
                        + l_freight_discount_total
                        /*Start of change as part of verison 1.7  */
                        + l_cod_charge_total
                        /*End of change as part of verison 1.7  */
                        + l_product_selling_price_total;
                ELSE
                    l_step   := 'STEP4';

                    SELECT SUM (ROUND (-- we are processing some other line but not a PGA
                                       xooftt.freight_charge_total + xooftt.gift_wrap_total /*Start of change as part of verison 1.7  */
                                                                                            + xooftt.cod_charge_total /*End of change as part of verison 1.7  */
                                                                                                                      + xooftt.tax_total_no_vat + xoopt.product_selling_price_total + xooftt.freight_discount_total, 2))
                      INTO l_total
                      FROM apps.xxdoec_oe_order_frt_tax_totals xooftt
                           JOIN apps.xxdoec_oe_order_product_totals xoopt
                               ON xoopt.header_id = xooftt.header_id
                     WHERE     xooftt.header_id = l_header_id
                           -- Need only the sum of lines assigned by line group id
                           AND NVL (xooftt.attribute18, '~') =
                               NVL (pv_line_grp_id, '~')
                           AND NVL (xoopt.attribute18, '~') =
                               NVL (pv_line_grp_id, '~');
                END IF;
            ELSE
                l_flag   := 0;
            -- It is not AE,EE or RE so flip flag back because we don't care
            END IF;
        END IF;

        l_step            := 'STEP5';

        OPEN p_order_header_cur FOR
            SELECT /*+ parallel(2) */
                   DISTINCT
                   ooha.header_id,
                   oola.attribute18,
                   CASE
                       -- if the orig_sys... came from oracle, use the oracle order_number instead
                       WHEN SUBSTR (
                                ooha.orig_sys_document_ref,
                                1,
                                20) =
                            'OE_ORDER_HEADERS_ALL'
                       THEN
                           TO_CHAR (
                               ooha.order_number)
                       -- un-prefix order number
                       WHEN SUBSTR (
                                ooha.orig_sys_document_ref,
                                1,
                                2) =
                            '90'
                       THEN
                           SUBSTR (
                               ooha.orig_sys_document_ref,
                               3)
                       WHEN SUBSTR (
                                ooha.orig_sys_document_ref,
                                1,
                                2) =
                            'DW'
                       THEN
                           SUBSTR (
                               ooha.orig_sys_document_ref,
                               3)
                       ELSE
                           ooha.orig_sys_document_ref
                   END
                       orig_sys_document_ref,
                   CASE                           -- un-prefix customer number
                       WHEN SUBSTR (hca.account_number, 1, 2) = '90'
                       THEN
                           SUBSTR (hca.account_number, 3)
                       WHEN SUBSTR (hca.account_number, 1, 2) = 'DW'
                       THEN
                           SUBSTR (hca.account_number, 3)
                       ELSE
                           hca.account_number
                   END
                       account_number,
                   hp.person_first_name,
                   hp.person_last_name,
                   hp.email_address,
                   hl_b.address1
                       bill_to_address1,
                   hl_b.address2
                       bill_to_address2,
                   hl_b.city
                       bill_to_city,
                   hl_b.state
                       bill_to_state,
                   hl_b.postal_code
                       bill_to_postal_code,
                   hl_b.country
                       bill_to_country,
                   hl_s.address1
                       ship_to_address1,
                   hl_s.address2
                       ship_to_address2,
                   hl_s.city
                       ship_to_city,
                   hl_s.state
                       ship_to_state,
                   hl_s.postal_code
                       ship_to_postal_code,
                   hl_s.country
                       ship_to_country,
                   ABS (ROUND (xoopt.product_list_price_total, 2))
                       product_list_price_total,
                   ABS (ROUND (xoopt.product_selling_price_total, 2))
                       product_selling_price_total,
                   ROUND (xooftt.freight_charge_total, 2)
                       freight_charge_total,
                   ROUND (xooftt.gift_wrap_total, 2)
                       gift_wrap_total,
                   ROUND (xooftt.tax_total_no_vat, 2)
                       tax_total_no_vat,
                   ROUND (xooftt.vat_total, 2)
                       AS vat_total,
                   CASE
                       WHEN l_flag = 0
                       THEN
                           -- Return everything assigned by line_group_id, may only be one line
                           ROUND (
                                 xooftt.freight_charge_total
                               + xooftt.gift_wrap_total
                               /*Start of change as part of verison 1.7  */
                               + xooftt.cod_charge_total
                               /*End of change as part of verison 1.7  */
                               + xooftt.tax_total_no_vat
                               + xoopt.product_selling_price_total
                               + xooftt.freight_discount_total,
                               2)                             --AS order_total
                       ELSE
                           l_total
                   -- Return the sum of all lines we got before (PGA and AE,RE,EE only)!!!
                   END
                       AS order_total,
                   ROUND (
                       xoopt.product_list_price_total - xoopt.product_selling_price_total,
                       2)
                       AS discount_total,
                   ROUND (xooftt.freight_discount_total, 2)
                       freight_discount_total,
                   ooha.transactional_curr_code
                       currency,
                   hca.attribute17
                       locale,
                   hca.attribute18
                       site,
                   CASE
                       WHEN SUBSTR (ooha.orig_sys_document_ref, 1, 20) =
                            'OE_ORDER_HEADERS_ALL'
                       THEN
                           'Y'
                       ELSE
                           'N'
                   END
                       oraclegenerated,
                   l_exchange_type
                       AS order_type_id,
                   l_orig_order_id
                       AS original_order_number,
                   --commented start by kcopeland 4/21/2016. This code was not ported from 12.1.3
                   ooha.global_attribute18
                       AS order_subtype,
                   ooha.global_attribute19
                       AS store_id,
                   (SELECT hcp_b.phone_number
                      FROM apps.hz_contact_points hcp_b
                     WHERE (hcas_b.party_site_id = hcp_b.owner_table_id AND hcp_b.owner_table_name = 'HZ_PARTY_SITES' AND ROWNUM < 2))
                       AS contact_phone,
                   --commented End by kcopeland 4/21/2016
                   (SELECT CASE
                               WHEN EXISTS
                                        (SELECT 1
                                           FROM XXDO.XXDOEC_ORDER_ATTRIBUTE
                                          WHERE     ORDER_HEADER_ID =
                                                    pn_header_id
                                                AND ATTRIBUTE_TYPE =
                                                    'CLOSETORDER')
                               THEN
                                   'True'
                               ELSE
                                   'FALSE'
                           END
                      FROM DUAL)
                       AS is_closet_order,
                   (SELECT CASE
                               WHEN EXISTS
                                        (SELECT 1
                                           FROM oe_price_adjustments
                                          WHERE     header_id = pn_header_id
                                                AND (attribute1 LIKE '%EMP%' OR attribute1 LIKE '%BOARD%'))
                               THEN
                                   'Y'
                               ELSE
                                   'N'
                           END
                      FROM DUAL)
                       AS is_emp_purch_order,
                   /*Start of change as part of verison 1.7  */
                   ROUND (xooftt.cod_charge_total, 0)
                       cod_charge_total
              /*End of change as part of verison 1.7  */
              FROM oe_order_lines_all oola, oe_order_headers_all ooha, xxdoec_oe_order_product_totals xoopt,
                   xxdoec_oe_order_frt_tax_totals xooftt, hz_cust_accounts hca, hz_parties hp,
                   hz_cust_site_uses_all hcsu_b, hz_cust_acct_sites_all hcas_b, hz_party_sites hps_b,
                   hz_locations hl_b, hz_cust_site_uses_all hcsu_s, hz_cust_acct_sites_all hcas_s,
                   hz_party_sites hps_s, hz_locations hl_s
             WHERE     oola.header_id = pn_header_id
                   AND NVL (oola.attribute18, '~') =
                       NVL (pv_line_grp_id, '~')
                   AND ooha.header_id = oola.header_id
                   AND xoopt.header_id = oola.header_id
                   AND NVL (xoopt.attribute18, '~') =
                       NVL (oola.attribute18, '~')
                   AND xooftt.header_id = oola.header_id
                   AND NVL (xooftt.attribute18, '~') =
                       NVL (oola.attribute18, '~')
                   AND hca.cust_account_id = ooha.sold_to_org_id
                   AND hp.party_id = hca.party_id
                   AND hcsu_b.site_use_id = ooha.invoice_to_org_id
                   AND hcas_b.cust_acct_site_id = hcsu_b.cust_acct_site_id
                   AND hps_b.party_site_id = hcas_b.party_site_id
                   AND hl_b.location_id = hps_b.location_id
                   AND hcsu_s.site_use_id = ooha.ship_to_org_id
                   AND hcas_s.cust_acct_site_id = hcsu_s.cust_acct_site_id
                   AND hps_s.party_site_id = hcas_s.party_site_id
                   AND hl_s.location_id = hps_s.location_id;

        l_step            := 'STEP6';

        OPEN p_order_line_cur FOR
            SELECT /*msi.attribute11 upc,
                     msi.segment1 model_number,
                   msi.segment2 color_code,*/
                   /*+ parallel(2) */
                  msi.upc_code
                      upc,
                  msi.style_number
                      model_number,
                  msi.color_code
                      color_code,
                  --Start modification by BT Technology Team on 24-Mar-2014
                  /*(SELECT ffv_colors.description
                     FROM fnd_flex_values_vl ffv_colors,
                          fnd_flex_value_sets fvs
                    WHERE
                          --ffv_colors.flex_value = msi.segment2
                          ffv_colors.flex_value = msi.color_code
                      AND fvs.flex_value_set_id = ffv_colors.flex_value_set_id
                      AND fvs.flex_value_set_name = 'DO_COLORS_CAT'
                      AND ROWNUM = 1) color_name,*/
                  msi.color_desc
                      color_name,
                  --End modification by BT Technology Team on 24-Mar-2014
                  --- msi.segment3 product_size, msi.description product_name,
                  msi.item_size
                      product_size,
                  msi.item_description
                      product_name,
                  CASE oola.cancelled_flag
                      WHEN 'Y' THEN oola.cancelled_quantity
                      ELSE oola.ordered_quantity
                  END
                      ordered_quantity,
                  ROUND (oola.unit_selling_price, 2)
                      unit_selling_price,
                  ROUND (oola.unit_list_price, 2)
                      unit_list_price,
                  CASE oola.cancelled_flag
                      WHEN 'Y'
                      THEN
                          ROUND (
                              oola.cancelled_quantity * oola.unit_selling_price,
                              2)
                      ELSE
                          ROUND (oola.ordered_quantity * oola.unit_selling_price,
                                 2)
                  END
                      selling_price_subtotal,
                  CASE oola.cancelled_flag
                      WHEN 'Y'
                      THEN
                          ROUND (oola.cancelled_quantity * oola.unit_list_price,
                                 2)
                      ELSE
                          ROUND (oola.ordered_quantity * oola.unit_list_price, 2)
                  END
                      list_price_subtotal,
                  dd.tracking_number,
                  dd.carrier,
                  --dd.shipping_method, -- Start of PRIORITY_SHIPMENT
                  NVL (dd.shipping_method, oola.shipping_method_code)
                      shipping_method,
                  -- End of PRIORITY_SHIPMENT
                  oola.line_number,
                  oola.line_id,
                  oola.header_id,
                  oola.attribute18,
                  msi.inventory_item_id,
                  oola.customer_job
                      fluid_recipe_id,
                  msi.organization_id,
                  ROUND (oca.freight_charge, 2)
                      freight_charge,
                  ROUND (oca.freight_tax, 2)
                      freight_tax,
                  ROUND (oca.tax_amount, 2)
                      tax_amount,
                  ROUND (oca.gift_wrap_charge, 2)
                      gift_wrap_charge,
                  ROUND (oca.gift_wrap_tax, 2)
                      gift_wrap_tax,
                  NVL (cre.reason_code, 'none')
                      reason_code,
                  NVL (cre.meaning, 'none')
                      meaning,
                  NVL (cre.user_name, 'none')
                      user_name,
                  NVL (cre.creation_date, TO_DATE ('01-JAN-1951'))
                      cancel_date,
                  -- ref 2707455 - global_attributes to store localized values
                  oola.global_attribute19
                      localized_color,
                  oola.global_attribute20
                      localized_size,
                  (SELECT CASE
                              WHEN EXISTS
                                       (SELECT 1
                                          FROM XXDO.XXDOEC_ORDER_ATTRIBUTE
                                         WHERE     ORDER_HEADER_ID =
                                                   oola.header_id
                                               AND ATTRIBUTE_TYPE = 'FINALSALE'
                                               AND LINE_ID = oola.line_id)
                              THEN
                                  'True'
                              ELSE
                                  'FALSE'
                          END
                     FROM DUAL)
                      is_final_sale_item,
                  hl_s.address1
                      ship_to_address1,
                  hl_s.address2
                      ship_to_address2,
                  hl_s.city
                      ship_to_city,
                  hl_s.state
                      ship_to_state,
                  hl_s.postal_code
                      ship_to_postal_code,
                  hl_s.country
                      ship_to_country,
                  hcsu_s.site_use_id,
                  /*Start of change as part of verison 1.7  */
                  ROUND (oca.cod_charge, 2)
                      cod_charge
             /*End of change as part of verison 1.7  */
             FROM oe_order_lines_all oola,
                  --mtl_system_items_b msi,
                  apps.xxd_common_items_v msi,
                  apps.xxdoec_order_line_charges oca,
                  (SELECT /*+ parallel(2) */
                          tracking_number, wc.freight_code carrier, flv_smc.meaning shipping_method,
                          wdd.source_line_id
                     FROM wsh_delivery_details wdd, fnd_lookup_values flv_smc, wsh_carriers wc
                    WHERE     wdd.source_code = 'OE'
                          AND wc.carrier_id = wdd.carrier_id
                          AND flv_smc.lookup_type = 'SHIP_METHOD'
                          AND flv_smc.LANGUAGE = 'US'
                          AND flv_smc.lookup_code = wdd.ship_method_code
                   UNION
                   SELECT /*+ parallel(2) */
                          ssd.tracking_number, wc.freight_code carrier, flv_smc.meaning shipping_method,
                          ssd.line_id
                     FROM xxdoec_sfs_shipment_dtls_stg ssd, fnd_lookup_values flv_smc, wsh_carrier_services wcs,
                          wsh_carriers wc
                    WHERE     1 = 1                 --  wdd.source_code = 'OE'
                          AND wc.carrier_id = wcs.carrier_id
                          AND flv_smc.lookup_type = 'SHIP_METHOD'
                          AND flv_smc.LANGUAGE = 'US'
                          AND flv_smc.lookup_code = wcs.ship_method_code
                          AND wcs.ship_method_code = ssd.ship_method_code) dd,
                  (SELECT /*+ parallel(2) */
                          ors.entity_id entity_id, ors.reason_code reason_code, flv.meaning meaning,
                          fu.user_name user_name, ors.creation_date creation_date
                     FROM apps.oe_reasons ors, apps.fnd_user fu, apps.fnd_lookup_values flv
                    WHERE     ors.entity_code = 'LINE'
                          --AND ors.entity_id = line_id--46201183 -- order line ID
                          AND ors.reason_type = 'CANCEL_CODE'
                          AND fu.user_id = ors.created_by
                          AND flv.lookup_type = 'CANCEL_CODE'
                          AND flv.lookup_code = ors.reason_code
                          AND LANGUAGE = 'US') cre,
                  hz_cust_accounts hca,
                  hz_parties hp,
                  hz_cust_site_uses_all hcsu_s,
                  hz_cust_acct_sites_all hcas_s,
                  hz_party_sites hps_s,
                  hz_locations hl_s
            WHERE     oola.header_id = pn_header_id                -- order id
                  AND NVL (oola.attribute18, '~') = NVL (pv_line_grp_id, '~') -- line group
                  AND msi.inventory_item_id = oola.inventory_item_id
                  AND msi.organization_id = oola.ship_from_org_id
                  AND dd.source_line_id(+) = oola.line_id
                  AND oola.line_id = cre.entity_id(+) -- for cancel information
                  AND oca.header_id = oola.header_id
                  AND oca.line_id = oola.line_id
                  AND hca.cust_account_id = oola.sold_to_org_id
                  AND hp.party_id = hca.party_id
                  AND hcsu_s.site_use_id = oola.ship_to_org_id
                  AND hcas_s.cust_acct_site_id = hcsu_s.cust_acct_site_id
                  AND hps_s.party_site_id = hcas_s.party_site_id
                  AND hl_s.location_id = hps_s.location_id;
    -- don't require tracking info (there won't be until it ships, duh!)
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_retcode   := 1;
            pv_errbuf    :=
                   'Unable to get lines in group for processing and assign group id:  '
                || pv_line_grp_id
                || ' header_id:  '
                || pn_header_id
                || '.';
            l_err_num    := SQLCODE;
            l_err_msg    := SUBSTR (SQLERRM, 1, 100);
            l_message    := 'ERROR marking lines for processing:  ';
            l_message    :=
                   l_step
                || l_message
                || ' err_num='
                || TO_CHAR (l_err_num)
                || ' err_msg='
                || l_err_msg
                || '.';
            msg (l_message || l_step);
            msg (pv_errbuf || l_message);
            dcdlog.changecode (p_code => -10036, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => l_debug);
            dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
            dcdlog.addparameter ('SQLCODE', TO_CHAR (SQLCODE), 'NUMBER');
            dcdlog.addparameter ('pn_header_id',
                                 TO_CHAR (pn_header_id),
                                 'NUMBER');
            dcdlog.addparameter ('pv_line_grp_id',
                                 pv_line_grp_id,
                                 'VARCHAR2');
            dcdlog.addparameter ('step', l_step, 'VARCHAR2');
            l_rc         := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;
    END get_lines_in_group;

    --------------------------------------------------
    -- Get all line groups having a particular custom status
    --
    -- Customer and Order numbers are reported with DW original numbers
    -- NOT including "90" prefix.
    --
    -- Author: Lawrence Walters
    -- Created: 12/14/2010
    --
    --------------------------------------------------
    PROCEDURE get_status_detail (
        pv_action             IN     VARCHAR2 -- this is the action (status_code or attribute20) you are interested in
                                             ,
        p_status_detail_cur      OUT status_detail_cur)
    IS
    BEGIN
        OPEN p_status_detail_cur FOR
              SELECT /*+ parallel(2) */
                     DISTINCT oola.header_id,
                              oola.attribute18 line_grp_id,
                              ooha.order_number,
                              CASE
                                  -- if the orig_sys... came from oracle, show null for clarity
                                  WHEN SUBSTR (ooha.orig_sys_document_ref,
                                               1,
                                               20) =
                                       'OE_ORDER_HEADERS_ALL'
                                  THEN
                                      NULL
                                  -- un-prefix order number
                                  WHEN SUBSTR (ooha.orig_sys_document_ref,
                                               1,
                                               2) =
                                       '90'
                                  THEN
                                      SUBSTR (ooha.orig_sys_document_ref, 3)
                                  WHEN SUBSTR (ooha.orig_sys_document_ref,
                                               1,
                                               2) =
                                       'DW'
                                  THEN
                                      SUBSTR (ooha.orig_sys_document_ref, 3)
                                  ELSE
                                      ooha.orig_sys_document_ref
                              END orig_sys_document_ref,
                              CASE                -- un-prefix customer number
                                  WHEN SUBSTR (hca.account_number, 1, 2) = '90'
                                  THEN
                                      SUBSTR (hca.account_number, 3)
                                  WHEN SUBSTR (hca.account_number, 1, 2) = 'DW'
                                  THEN
                                      SUBSTR (hca.account_number, 3)
                                  ELSE
                                      hca.account_number
                              END account_number,
                              ooha.transactional_curr_code currency,
                              hca.attribute17 locale,
                              hca.attribute18 site,
                              oola.attribute17 return_status
                FROM oe_order_lines_all oola, oe_order_headers_all ooha, hz_cust_accounts hca
               WHERE     oola.attribute17 IN ('N', 'E', 'S',
                                              'M', 'P')
                     AND oola.attribute20 = pv_action
                     AND oola.open_flag = 'Y'
                     AND ooha.header_id = oola.header_id
                     AND hca.cust_account_id = ooha.sold_to_org_id
            ORDER BY orig_sys_document_ref;
    END get_status_detail;

    --------------------------------------------------
    -- Get line group counts for all the different custom actions (attribute20 / status_code)
    --
    -- Author: Lawrence Walters
    -- Created: 12/14/2010
    --
    --------------------------------------------------
    PROCEDURE get_status_summary (
        p_status_summary_cur OUT status_summary_cur)
    IS
    BEGIN
        OPEN p_status_summary_cur FOR
              SELECT /*+ parallel(2) */
                     DISTINCT oola.attribute20 action -- group on action required
                                                     , COUNT (*) total_count, SUM (DECODE (oola.attribute17, 'E', 1, 0)) error_count,
                              SUM (DECODE (oola.attribute17, 'M', 1, 0)) manual_count, SUM (DECODE (oola.attribute17, 'N', 1, 0)) new_count, SUM (DECODE (oola.attribute17, 'P', 1, 0)) processing_count,
                              SUM (DECODE (oola.attribute17, 'S', 1, 0)) success_count
                FROM oe_order_lines_all oola
               WHERE     oola.attribute20 IS NOT NULL
                     AND open_flag = 'Y'
                     AND oola.attribute17 IN ('N', 'E', 'S',
                                              'M', 'P')
            GROUP BY oola.attribute20
            ORDER BY oola.attribute20;
    END get_status_summary;

    --------------------------------------------------
    -- Update a group of lines after making the webservice
    -- calls. This handles progressing the line by calling
    -- progress_line().
    --
    -- This also handles advancing line groups after a number
    -- of failures to send an email using set_email_ctr_value/get_email_ctr_value
    --
    -- Author: Lawrence Walters
    -- Created: 11/4/2010
    --
    --------------------------------------------------
    PROCEDURE update_line_group_result (pn_header_id       IN     NUMBER -- order id
                                                                        ,
                                        pv_line_grp_id     IN     VARCHAR2 -- line group id
                                                                          ,
                                        pv_status_code     IN     VARCHAR2 -- action just done (PGA, PGC, FRC etc)
                                                                          ,
                                        pv_rtn_status      IN     VARCHAR2 -- E = error (webservice call failed / exception), S = success
                                                                          ,
                                        pv_result_code     IN     VARCHAR2 -- result of call, FAIL, SUCCESS, FRAUD, NO_FRAUD etc.
                                                                          ,
                                        pv_pgc_trans_num   IN     VARCHAR2 -- on PG auth actions: payment gateway PGResponse.FollowupPGResponseId
                                                                          ,
                                        pv_errbuf             OUT VARCHAR2 -- error messages from this call, if any
                                                                          ,
                                        pn_retcode            OUT NUMBER -- 0 for success, 1 for error
                                                                        )
    IS
        lv_input_rtn_status    VARCHAR2 (1);        -- locally modifiable copy
        lv_rtn_status          VARCHAR2 (1); -- return status of internal calls
        lv_rtn_msg_data        VARCHAR2 (4000);
        ln_retries             NUMBER := 0;
        lv_other_status_code   VARCHAR2 (240) := 'XXX';
        l_debug                NUMBER := 0;
        l_rc                   NUMBER := 0;
        l_step                 VARCHAR2 (200) := 'START';
        l_txn_type             VARCHAR2 (240) := 'XX';
        dcdlog                 dcdlog_type
            := dcdlog_type (p_code => -10037, p_application => g_application, p_logeventtype => 4
                            , p_tracelevel => 2, p_debug => l_debug);
    BEGIN
        -- Diagnostics for debugging
        --    msg('Entering update_line_group_result:  pn_header_id:  ' ||
        --        TO_CHAR(pn_header_id) || '  pv_line_grp_id:  ' || pv_line_grp_id ||
        --        '  pv_status_code:  ' || pv_status_code || '  pv_rtn_status:  ' ||
        --        pv_rtn_status || '  pv_result_code:  ' || pv_result_code ||
        --        '  pv_pgc_trans_num:  ' || pv_pgc_trans_num || '.');
        dcdlog.addparameter ('pn_header_id',
                             TO_CHAR (pn_header_id),
                             'NUMBER');
        dcdlog.addparameter ('pv_line_grp_id', pv_line_grp_id, 'VARCHAR2');
        dcdlog.addparameter ('pv_status_code', pv_status_code, 'VARCHAR2');
        dcdlog.addparameter ('pv_rtn_status', pv_rtn_status, 'VARCHAR2');
        dcdlog.addparameter ('pv_result_code', pv_result_code, 'VARCHAR2');
        dcdlog.addparameter ('pv_pgc_trans_num',
                             pv_pgc_trans_num,
                             'VARCHAR2');
        l_rc                  := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;

        -- track the input return status with a locally modifiable variable
        lv_input_rtn_status   := pv_rtn_status;

        -- if this was an email failure, check how many times we've retried this line group
        IF     lv_input_rtn_status = fnd_api.g_ret_sts_error
           AND pv_status_code IN ('CAE', 'RCE', 'SHE',
                                  'CSE')
        THEN
            ln_retries   :=
                get_email_ctr_value (p_header_id     => pn_header_id,
                                     p_line_grp_id   => pv_line_grp_id);

            IF ln_retries > 5
            THEN
                -- override failure result with success, so processing will continue without this email having been sent
                lv_input_rtn_status   := fnd_api.g_ret_sts_success;
            ELSE
                -- increment the counter
                ln_retries   := ln_retries + 1;
                set_email_ctr_value (p_header_id      => pn_header_id,
                                     p_line_grp_id    => pv_line_grp_id,
                                     p_ctr_value      => ln_retries,
                                     x_rtn_status     => lv_rtn_status,
                                     x_rtn_msg_data   => lv_rtn_msg_data);

                -- when there is an error, just log it, but continue
                IF lv_rtn_status <> fnd_api.g_ret_sts_success
                THEN
                    pv_errbuf    :=
                           'Unable to increment email failure counter, Ignoring this failure and continuing.: '
                        || lv_rtn_status
                        || ' '
                        || lv_rtn_msg_data;
                    dcdlog.changecode (p_code => -10038, p_application => g_application, p_logeventtype => 1
                                       , p_tracelevel => 1, p_debug => l_debug);
                    dcdlog.addparameter ('Error Message',
                                         lv_rtn_msg_data,
                                         'VARCHAR2');
                    l_rc         := dcdlog.loginsert ();

                    IF (l_rc <> 1)
                    THEN
                        msg (dcdlog.l_message);
                    END IF;

                    pn_retcode   := 1;
                END IF;
            END IF;
        END IF;

        l_step                := 'Update line process Flag';

        -- Update line process Flag
        UPDATE oe_order_lines_all oola
           SET oola.attribute17 = lv_input_rtn_status, oola.attribute19 = DECODE (pv_status_code, 'CAE', oola.attribute19, pv_result_code) -- don't change attribute19 when cancelling, so we preserve the reason for the cancel in attribute19
                                                                                                                                          , oola.attribute16 = pv_pgc_trans_num
         WHERE     oola.header_id = pn_header_id
               AND oola.attribute18 = pv_line_grp_id;

        l_step                :=
            'Progress Order lines based on the result/rtn status';

        -- Progress Order lines based on the result/rtn status
        IF lv_input_rtn_status = fnd_api.g_ret_sts_success
        THEN
            progress_line (p_header_id      => pn_header_id,
                           p_line_grp_id    => pv_line_grp_id,
                           p_status_code    => pv_status_code,
                           p_result_code    => pv_result_code,
                           x_rtn_status     => lv_rtn_status,
                           x_rtn_msg_data   => lv_rtn_msg_data);

            IF lv_rtn_status <> fnd_api.g_ret_sts_success
            THEN
                pv_errbuf    :=
                       'Unable to progress Order Lines in Status Code: '
                    || lv_input_rtn_status
                    || ' - Order Header ID: '
                    || pn_header_id
                    || ' - Group ID: '
                    || pv_line_grp_id
                    || '. progress_line.x_rtn_status = '
                    || lv_rtn_status
                    || '. progress_line.x_rtn_msg_data = '
                    || lv_rtn_msg_data;
                --msg(pv_errbuf);
                dcdlog.changecode (p_code => -10039, p_application => g_application, p_logeventtype => 1
                                   , p_tracelevel => 1, p_debug => l_debug);
                dcdlog.addparameter ('status_code',
                                     lv_input_rtn_status,
                                     'VARCHAR2');
                dcdlog.addparameter ('header_id',
                                     TO_CHAR (pn_header_id),
                                     'NUMBER');
                dcdlog.addparameter ('pv_line_grp_id',
                                     pv_line_grp_id,
                                     'VARCHAR2');
                dcdlog.addparameter ('lv_rtn_status',
                                     lv_rtn_status,
                                     'VARCHAR2');
                dcdlog.addparameter ('lv_rtn_msg_data',
                                     lv_rtn_msg_data,
                                     'VARCHAR2');
                l_rc         := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;

                pn_retcode   := 1;
            ELSE
                pv_errbuf    :=
                       'Sucessfully progressed Order Lines in Status Code: '
                    || lv_input_rtn_status
                    || ' - Order Header ID: '
                    || pn_header_id
                    || ' - Group ID: '
                    || pv_line_grp_id
                    || '. progress_line.x_rtn_status = '
                    || lv_rtn_status
                    || '. progress_line.x_rtn_msg_data = '
                    || lv_rtn_msg_data;
                dcdlog.changecode (p_code => -10040, p_application => g_application, p_logeventtype => 2
                                   , p_tracelevel => 2, p_debug => l_debug);
                dcdlog.addparameter ('status_code',
                                     lv_input_rtn_status,
                                     'VARCHAR2');
                dcdlog.addparameter ('header_id',
                                     TO_CHAR (pn_header_id),
                                     'NUMBER');
                dcdlog.addparameter ('pv_line_grp_id',
                                     pv_line_grp_id,
                                     'VARCHAR2');
                dcdlog.addparameter ('lv_rtn_status',
                                     lv_rtn_status,
                                     'VARCHAR2');
                dcdlog.addparameter ('lv_rtn_msg_data',
                                     lv_rtn_msg_data,
                                     'VARCHAR2');
                l_rc         := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;

                pn_retcode   := 0;
            END IF;
        ELSE
            pv_errbuf    :=
                   'Line status updated, but line not progressed Status Code: '
                || lv_input_rtn_status
                || ' - Order Header ID: '
                || pn_header_id
                || ' - Group ID: '
                || pv_line_grp_id
                || '. progress_line.x_rtn_status = '
                || lv_rtn_status
                || '. progress_line.x_rtn_msg_data = '
                || lv_rtn_msg_data;
            --msg(pv_errbuf);
            pn_retcode   := 0;
        END IF;

        l_step                := 'Retrieve transaction type.';

        -- Get the transaction type of this header_id
        SELECT NVL (b.attribute13, 'XX')
          -- Transaction type ie:  (RE, AE, RT, RR)
          INTO l_txn_type
          FROM oe_order_headers_all c
               JOIN apps.oe_transaction_types_all b
                   ON c.order_type_id = b.transaction_type_id
         WHERE c.header_id = pn_header_id;

        IF l_txn_type IN ('RE', 'AE', 'RT',
                          'RR', 'RE')
        THEN
            -- Progress line for the other line in the exchange if need be:
            -- If passed in status code was PGC, then we need to call it for CHB
            -- and visa versa.
            IF (lv_input_rtn_status = 'PGC')
            THEN
                lv_other_status_code   := 'CHB';
            END IF;

            IF (lv_input_rtn_status = 'CHB')
            THEN
                lv_other_status_code   := 'PGC';
            END IF;

            IF (lv_other_status_code IN ('PGC', 'CHG'))
            THEN
                l_step   := 'Attempt to update other status code for ex/re';
                dcdlog.changecode (p_code => -10041, -- Tell log we are attempting
                                                     p_application => g_application, p_logeventtype => 2
                                   , p_tracelevel => 2, p_debug => l_debug);
                l_rc     := dcdlog.loginsert ();

                IF (l_rc <> 1)
                THEN
                    msg (dcdlog.l_message);
                END IF;

                progress_line (p_header_id      => pn_header_id,
                               p_line_grp_id    => pv_line_grp_id,
                               p_status_code    => lv_other_status_code,
                               p_result_code    => pv_result_code,
                               x_rtn_status     => lv_rtn_status,
                               x_rtn_msg_data   => lv_rtn_msg_data);

                IF lv_rtn_status <> fnd_api.g_ret_sts_success
                THEN
                    pv_errbuf    :=
                           'EX:  Unable to progress Order Lines in Status Code: '
                        || lv_input_rtn_status
                        || ' - Order Header ID: '
                        || pn_header_id
                        || ' - Group ID: '
                        || pv_line_grp_id
                        || '. status code = '
                        || lv_other_status_code
                        || '. progress_line.x_rtn_status = '
                        || lv_rtn_status
                        || '. progress_line.x_rtn_msg_data = '
                        || lv_rtn_msg_data;
                    --msg(pv_errbuf);
                    dcdlog.changecode (p_code => -10039, p_application => g_application, p_logeventtype => 1
                                       , p_tracelevel => 1, p_debug => l_debug);
                    dcdlog.addparameter ('status_code',
                                         lv_input_rtn_status,
                                         'VARCHAR2');
                    dcdlog.addparameter ('header_id',
                                         TO_CHAR (pn_header_id),
                                         'NUMBER');
                    dcdlog.addparameter ('pv_line_grp_id',
                                         pv_line_grp_id,
                                         'VARCHAR2');
                    dcdlog.addparameter ('lv_rtn_status',
                                         lv_rtn_status,
                                         'VARCHAR2');
                    dcdlog.addparameter ('lv_other_status_code',
                                         lv_other_status_code,
                                         'VARCHAR2');
                    dcdlog.addparameter ('lv_rtn_msg_data',
                                         lv_rtn_msg_data,
                                         'VARCHAR2');
                    dcdlog.addparameter ('pv_errbuf', pv_errbuf, 'VARCHAR2');
                    l_rc         := dcdlog.loginsert ();

                    IF (l_rc <> 1)
                    THEN
                        msg (dcdlog.l_message);
                    END IF;

                    pn_retcode   := 1;
                ELSE
                    pv_errbuf    :=
                           'EX:  Sucessfully progressed Order Lines in Status Code: '
                        || lv_input_rtn_status
                        || ' - Order Header ID: '
                        || pn_header_id
                        || ' - Group ID: '
                        || pv_line_grp_id
                        || '. status code = '
                        || lv_other_status_code
                        || '. progress_line.x_rtn_status = '
                        || lv_rtn_status
                        || '. progress_line.x_rtn_msg_data = '
                        || lv_rtn_msg_data;
                    --msg(pv_errbuf);
                    dcdlog.changecode (p_code => -10040, p_application => g_application, p_logeventtype => 2
                                       , p_tracelevel => 2, p_debug => l_debug);
                    dcdlog.addparameter ('status_code',
                                         lv_input_rtn_status,
                                         'VARCHAR2');
                    dcdlog.addparameter ('header_id',
                                         TO_CHAR (pn_header_id),
                                         'NUMBER');
                    dcdlog.addparameter ('pv_line_grp_id',
                                         pv_line_grp_id,
                                         'VARCHAR2');
                    dcdlog.addparameter ('lv_rtn_status',
                                         lv_rtn_status,
                                         'VARCHAR2');
                    dcdlog.addparameter ('lv_other_status_code',
                                         lv_other_status_code,
                                         'VARCHAR2');
                    dcdlog.addparameter ('lv_rtn_msg_data',
                                         lv_rtn_msg_data,
                                         'VARCHAR2');
                    l_rc         := dcdlog.loginsert ();

                    IF (l_rc <> 1)
                    THEN
                        msg (dcdlog.l_message);
                    END IF;

                    pn_retcode   := 0;
                END IF;
            END IF;
        END IF;

        dcdlog.changecode (p_code => -10037, p_application => g_application, p_logeventtype => 4
                           , p_tracelevel => 2, p_debug => l_debug);
        dcdlog.addparameter ('End', TO_CHAR (CURRENT_TIMESTAMP), 'TIMESTAMP');
        l_rc                  := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            pv_errbuf    := pv_errbuf || ' Unexpected error occurred...';
            --msg(pv_errbuf);
            dcdlog.changecode (p_code => -10043, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => l_debug);
            dcdlog.addparameter ('l_step', l_step, 'VARCHAR2');
            l_rc         := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;

            pn_retcode   := 0;
        WHEN OTHERS
        THEN
            pn_retcode   := 1;
            pv_errbuf    :=
                   'EX:  Unexpected error updating line group. Status Code: '
                || lv_input_rtn_status
                || ' - Order Header ID: '
                || pn_header_id
                || ' - Group ID: '
                || pv_line_grp_id
                || ' '
                || pv_errbuf
                || ' Error: '
                || SQLERRM;
            dcdlog.changecode (p_code => -10043, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => l_debug);
            dcdlog.addparameter ('lv_input_rtn_status',
                                 lv_input_rtn_status,
                                 'VARCHAR2');
            dcdlog.addparameter ('pn_header_id',
                                 TO_CHAR (pn_header_id),
                                 'NUMBER');
            dcdlog.addparameter ('pv_line_grp_id',
                                 pv_line_grp_id,
                                 'VARCHAR2');
            dcdlog.addparameter ('l_step', l_step, 'VARCHAR2');
            dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
            l_rc         := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;
    END update_line_group_result;

    --------------------------------------------------
    -- retry a payment gateway charge or credit.
    -- this should be triggered by the intranet todo
    -- list after a charge or credit has failed, and the payment
    -- data in the payment gateway was updated
    --
    -- Author: Lawrence Walters
    -- Created: 11/18/2010
    --
    --------------------------------------------------
    PROCEDURE retry_payment_gateway_action (pn_header_id     IN     NUMBER -- header_id from oe_order_headers_all
                                                                          ,
                                            pv_line_grp_id   IN     VARCHAR2 -- line group id, oe_order_lines_all.attribute18
                                                                            ,
                                            pb_is_charge     IN     NUMBER -- 1 to charge, 0 to credit
                                                                          ,
                                            pv_errbuf           OUT VARCHAR2 -- any descriptive messages about actions/error
                                                                            ,
                                            pn_retcode          OUT NUMBER -- 0 for success, 1 for error
                                                                          )
    IS
        lv_action   VARCHAR2 (30) := 'PGC';               -- default to charge
        dcdlog      dcdlog_type
                        := dcdlog_type (p_code => -10045, p_application => g_application, p_logeventtype => 2
                                        , p_tracelevel => 2, p_debug => 0);
        l_rc        NUMBER := 0;
    BEGIN
        --default the action to the current action
        SELECT oola.attribute20
          INTO lv_action
          FROM oe_order_lines_all oola
         WHERE     oola.header_id = pn_header_id
               AND oola.attribute18 = pv_line_grp_id
               AND ROWNUM = 1;

        -- pb_is_charge determines the retry action applied to the line group
        CASE pb_is_charge
            WHEN 10
            THEN
                lv_action   := 'PGC';
            WHEN 12
            THEN
                lv_action   := lv_action;
            WHEN 13
            THEN
                lv_action   := 'PGA';
            WHEN 14
            THEN
                lv_action   := 'CSN';
            WHEN 15
            THEN
                lv_action   := 'CRN';
            WHEN 16
            THEN
                lv_action   := 'CCN';
            ELSE
                lv_action   := lv_action;
        END CASE;

        -- Update line process Flag
        UPDATE oe_order_lines_all oola
           SET oola.attribute17 = 'N'                        -- retry it, bro!
                                     , oola.attribute19 = NULL -- clear any prior status
                                                              , oola.attribute20 = lv_action
         -- AT1241066 - rjm - 8/8/12, leaving attribute16 alone. These are needed to retry charges for Adyen and Paypal and should not be an issue for other payment types.
         --oola.attribute16 = NULL -- clear any prior transaction id (this forces Jerry to do a new transaction)
         WHERE     oola.header_id = pn_header_id
               AND oola.attribute18 = pv_line_grp_id;

        pv_errbuf    :=
               'Line status updated to retry '
            || lv_action
            || ' - Order Header ID: '
            || pn_header_id
            || ' - Group ID: '
            || pv_line_grp_id;
        msg (pv_errbuf);
        dcdlog.changecode (p_code => -10045, p_application => g_application, p_logeventtype => 2
                           , p_tracelevel => 2, p_debug => 0);
        dcdlog.addparameter ('lv_action', lv_action, 'VARCHAR2');
        dcdlog.addparameter ('pn_header_id',
                             TO_CHAR (pn_header_id),
                             'NUMBER');
        dcdlog.addparameter ('pv_line_grp_id', pv_line_grp_id, 'VARCHAR2');
        l_rc         := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;

        pn_retcode   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_retcode   := 1;
            pv_errbuf    := 'Unexpected Error occured ' || SQLERRM;
            msg (pv_errbuf);
            dcdlog.changecode (p_code => -10044, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => 0);
            dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
            l_rc         := dcdlog.loginsert ();
    END;

    --------------------------------------------------
    -- set status to fail for header id.
    -- this should be triggered by the intranet todo
    -- list after a charge or credit has failed, and
    -- payment will not be re-couped. This will
    -- allow the line to progress to a closed state.
    --
    -- Author: Lawrence Walters
    -- Created: 11/18/2010
    --
    --------------------------------------------------
    PROCEDURE upd_pg_action_fail (pn_header_id IN NUMBER -- header_id from oe_order_headers_all
                                                        , pv_line_grp_id IN VARCHAR2 -- line group id, oe_order_lines_all.attribute18
                                                                                    , pv_errbuf OUT VARCHAR2 -- any descriptive messages about actions/error
                                  , pn_retcode OUT NUMBER -- 0 for success, 1 for error
                                                         )
    IS
        l_rc     NUMBER := 0;
        dcdlog   dcdlog_type
                     := dcdlog_type (p_code => -10047, p_application => g_application, p_logeventtype => 2
                                     , p_tracelevel => 2, p_debug => 0);
    BEGIN
        -- Update line process Flag
        UPDATE oe_order_lines_all oola
           SET oola.attribute17 = 'S'          -- The operation was a success!
                                     , oola.attribute19 = 'FAIL'
         -- set the status to fail so the line will close
         WHERE     oola.header_id = pn_header_id
               AND oola.attribute18 = pv_line_grp_id;

        pv_errbuf    :=
               'Line status updated to fail for - Order Header ID: '
            || pn_header_id
            || ' - Group ID: '
            || pv_line_grp_id;
        msg (pv_errbuf);
        dcdlog.changecode (p_code => -10047, p_application => g_application, p_logeventtype => 2
                           , p_tracelevel => 2, p_debug => 0);
        dcdlog.addparameter ('pn_header_id',
                             TO_CHAR (pn_header_id),
                             'NUMBER');
        dcdlog.addparameter ('pv_line_grp_id', pv_line_grp_id, 'VARCHAR2');
        l_rc         := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;

        pn_retcode   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_retcode   := 1;
            pv_errbuf    := 'Unexpected Error occured ' || SQLERRM;
            msg (pv_errbuf);
            dcdlog.changecode (p_code => -10046, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => 0);
            dcdlog.addparameter ('pn_header_id',
                                 TO_CHAR (pn_header_id),
                                 'NUMBER');
            dcdlog.addparameter ('pv_line_grp_id',
                                 pv_line_grp_id,
                                 'VARCHAR2');
            dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
            l_rc         := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;
    END;

    --------------------------------------------------
    -- set status to success for header id.
    -- this should be triggered by the intranet todo
    -- list after a charge or credit has failed, and
    -- payment has been corrected outside the
    -- todo list. This will allow the line to progress
    -- to a closed state.
    --
    -- Author: Lawrence Walters
    -- Created: 11/18/2010
    --
    --------------------------------------------------
    PROCEDURE upd_pg_action_success (pn_header_id IN NUMBER -- header_id from oe_order_headers_all
                                                           , pv_line_grp_id IN VARCHAR2 -- line group id, oe_order_lines_all.attribute18
                                                                                       , pv_errbuf OUT VARCHAR2 -- any descriptive messages about actions/error
                                     , pn_retcode OUT NUMBER -- 0 for success, 1 for error
                                                            )
    IS
        l_rc     NUMBER := 0;
        dcdlog   dcdlog_type
                     := dcdlog_type (p_code => -10049, p_application => g_application, p_logeventtype => 2
                                     , p_tracelevel => 2, p_debug => 0);
    BEGIN
        -- Update line process Flag
        UPDATE oe_order_lines_all oola
           SET oola.attribute17 = 'S'          -- The operation was a success!
                                     , oola.attribute19 = 'SUCCESS'
         -- set the status to fail so the line will close
         WHERE     oola.header_id = pn_header_id
               AND oola.attribute18 = pv_line_grp_id;

        pv_errbuf    :=
               'Line status updated to fail for - Order Header ID: '
            || pn_header_id
            || ' - Group ID: '
            || pv_line_grp_id;
        msg (pv_errbuf);
        dcdlog.changecode (p_code => -10049, p_application => g_application, p_logeventtype => 2
                           , p_tracelevel => 2, p_debug => 0);
        dcdlog.addparameter ('pn_header_id',
                             TO_CHAR (pn_header_id),
                             'NUMBER');
        dcdlog.addparameter ('pv_line_grp_id', pv_line_grp_id, 'VARCHAR2');
        l_rc         := dcdlog.loginsert ();

        IF (l_rc <> 1)
        THEN
            msg (dcdlog.l_message);
        END IF;

        pn_retcode   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_retcode   := 1;
            pv_errbuf    := 'Unexpected Error occured ' || SQLERRM;
            msg (pv_errbuf);
            dcdlog.changecode (p_code => -10048, p_application => g_application, p_logeventtype => 1
                               , p_tracelevel => 1, p_debug => 0);
            dcdlog.addparameter ('pn_header_id',
                                 TO_CHAR (pn_header_id),
                                 'NUMBER');
            dcdlog.addparameter ('pv_line_grp_id',
                                 pv_line_grp_id,
                                 'VARCHAR2');
            dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
            l_rc         := dcdlog.loginsert ();

            IF (l_rc <> 1)
            THEN
                msg (dcdlog.l_message);
            END IF;
    END;

    PROCEDURE insert_order_payment_detail (pn_header_id IN NUMBER, pv_line_grp_id IN VARCHAR2, pn_payment_amount IN NUMBER, pd_payment_date IN DATE, pn_payment_trx_id IN NUMBER, pv_payment_type IN VARCHAR2, pv_pg_ref_num IN VARCHAR2, pv_status IN VARCHAR2, pv_web_order_number IN VARCHAR2, pv_pg_action IN VARCHAR2, pv_prepaid_flag IN VARCHAR2, pv_payment_tender_type IN VARCHAR2
                                           , pv_transaction_ref_num IN VARCHAR2, pn_retcode OUT NUMBER, pv_errbuf OUT VARCHAR2)
    IS
        ln_payment_id             NUMBER;
        l_existing_record_count   NUMBER := 0;
        l_rc                      NUMBER := 0;
        dcdlog                    dcdlog_type
            := dcdlog_type (p_code => -10050, p_application => g_application, p_logeventtype => 1
                            , p_tracelevel => 1, p_debug => 0);
    BEGIN
        --Initialize the return code.
        pn_retcode   := -1;

        -- Check for exisitng records. Payment for Prepaid orders is recorded before the order is imported,
        -- retrying a failed order import may result in duplicate payment insert.
        SELECT /*+ parallel(2) */
               COUNT (1)
          INTO l_existing_record_count
          FROM xxdo.xxdoec_order_payment_details
         WHERE     web_order_number = pv_web_order_number
               AND pg_action = pv_pg_action
               AND pg_reference_num = pv_pg_ref_num
               AND payment_type = pv_payment_type
               AND payment_amount = pn_payment_amount
               AND transaction_ref_num = pv_transaction_ref_num;

        IF (l_existing_record_count = 0)
        THEN
            BEGIN
                SELECT xxdo.xxdoec_order_payment_details_s.NEXTVAL
                  INTO ln_payment_id
                  FROM DUAL;

                INSERT INTO xxdo.xxdoec_order_payment_details (
                                header_id,
                                line_group_id,
                                payment_amount,
                                payment_date,
                                payment_id,
                                payment_trx_id,
                                payment_type,
                                pg_reference_num,
                                status,
                                web_order_number,
                                pg_action,
                                prepaid_flag,
                                payment_tender_type,
                                transaction_ref_num)
                         VALUES (pn_header_id,
                                 pv_line_grp_id,
                                 pn_payment_amount,
                                 pd_payment_date,
                                 ln_payment_id,
                                 pn_payment_trx_id,
                                 pv_payment_type,
                                 pv_pg_ref_num,
                                 pv_status,
                                 pv_web_order_number,
                                 pv_pg_action,
                                 pv_prepaid_flag,
                                 pv_payment_tender_type,
                                 pv_transaction_ref_num);

                pv_errbuf    := '';
                pn_retcode   := 0;
                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pn_retcode   := 1;
                    pv_errbuf    := 'Unexpected Error occured ' || SQLERRM;
                    dcdlog.changecode (p_code => -10050, p_application => g_application, p_logeventtype => 1
                                       , p_tracelevel => 1, p_debug => 0);
                    dcdlog.addparameter ('SQLERRM', SQLERRM, 'VARCHAR2');
                    l_rc         := dcdlog.loginsert ();

                    IF (l_rc <> 1)
                    THEN
                        msg (dcdlog.l_message);
                    END IF;

                    ROLLBACK;
            END;
        END IF;
    END;

    PROCEDURE get_orig_pgc_trans_num (p_cust_po_number       IN     VARCHAR2,
                                      x_orig_pgc_trans_num      OUT VARCHAR)
    IS
        v_orig_pgc_trans_num   VARCHAR2 (240) := NULL;
    BEGIN
        SELECT NVL (c.attribute16, NULL)
          INTO v_orig_pgc_trans_num
          FROM apps.oe_order_headers_all a
               JOIN apps.oe_order_lines_all b ON a.header_id = b.header_id
               JOIN apps.oe_order_lines_all c
                   ON b.reference_line_id = c.line_id
         WHERE a.cust_po_number = p_cust_po_number AND ROWNUM < 2;

        x_orig_pgc_trans_num   := v_orig_pgc_trans_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_orig_pgc_trans_num   := NULL;
    END get_orig_pgc_trans_num;

    PROCEDURE get_orig_pgc_trans_num_by_line (
        p_line_id              IN     NUMBER,
        x_orig_pgc_trans_num      OUT VARCHAR)
    IS
        v_orig_pgc_trans_num   VARCHAR2 (240) := NULL;
        n_line_id              NUMBER;
        line_id                NUMBER;
        tries                  NUMBER;
        next_ref_line_id       NUMBER;
    BEGIN
        -- Inits
        tries                  := 0;
        v_orig_pgc_trans_num   := NULL;
        line_id                := p_line_id;

        -- Loop back up to 100 times trying to find the original order
        -- Using a while so things can't go off the rails
        WHILE v_orig_pgc_trans_num IS NULL AND tries < 100
        LOOP
            n_line_id   := line_id;

            -- Try Reference_Line_ID (original method)
            SELECT NVL (lineold.attribute16, NULL), NVL (lineold.line_id, NULL), lineold.reference_line_id
              INTO v_orig_pgc_trans_num, line_id, next_ref_line_id
              FROM apps.oe_order_lines_all linenew
                   JOIN apps.oe_order_lines_all lineold
                       ON linenew.reference_line_id = lineold.line_id
             WHERE linenew.line_id = n_line_id;

            IF (v_orig_pgc_trans_num IS NULL AND next_ref_line_id IS NULL)
            THEN
                BEGIN
                    -- Backup method, use Reference_Header_id and Ordered_Item
                    -- Do this when we don't get a PGRefrence and there is no reference_line_id to go to
                    --                DBMS_OUTPUT.put_line('Backup method');
                    SELECT NVL (lineold.attribute16, NULL), lineold.line_id
                      INTO v_orig_pgc_trans_num, line_id
                      FROM apps.oe_order_lines_all linenew
                           JOIN apps.oe_order_lines_all lineold
                               ON     linenew.reference_header_id =
                                      lineold.header_id
                                  AND lineold.line_category_code = 'RETURN'
                     -- AND lineNew.Ordered_Item = lineOld.Ordered_Item
                     WHERE linenew.line_id = n_line_id AND ROWNUM = 1; -- CCR0008194
                EXCEPTION
                    -- This method sometimes fails. If it does, we are out of luck
                    WHEN NO_DATA_FOUND
                    THEN
                        --                  DBMS_OUTPUT.put_line('** NO_DATA_FOUND line_id: ' || TO_CHAR(n_line_id) );
                        EXIT;
                END;
            END IF;

            tries       := tries + 1;
        --            DBMS_OUTPUT.put_line('End: ' || TO_CHAR(tries) || ': ' || TO_CHAR(line_id) || ', ' || TO_CHAR(n_line_id));
        END LOOP;                   -- Walking back to the original order loop

        x_orig_pgc_trans_num   := v_orig_pgc_trans_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_orig_pgc_trans_num   := NULL;
    END get_orig_pgc_trans_num_by_line;

    --   PROCEDURE get_orig_pgc_trans_num_by_line (
    --      p_line_id              IN     NUMBER,
    --      x_orig_pgc_trans_num      OUT VARCHAR)
    --   IS
    --      v_orig_pgc_trans_num   VARCHAR2 (240) := NULL;
    --   BEGIN
    --      SELECT NVL (lineOld.attribute16, NULL) AS v_orig_pgc_trans_num
    --        INTO v_orig_pgc_trans_num
    --        FROM    apps.oe_order_lines_all lineNew
    --             JOIN
    --                apps.oe_order_lines_all lineOld
    --             ON lineNew.reference_line_id = lineOld.line_id
    --       WHERE lineNew.line_id = p_line_id;
    --
    --      x_orig_pgc_trans_num := v_orig_pgc_trans_num;
    --   EXCEPTION
    --      WHEN OTHERS
    --      THEN
    --         x_orig_pgc_trans_num := NULL;
    --   END get_orig_pgc_trans_num_by_line;
    PROCEDURE upd_line_status_by_group_id (p_line_grp_id IN NUMBER, p_state IN VARCHAR2, p_status IN VARCHAR2
                                           , p_outcome IN VARCHAR2, x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER)
    IS
    BEGIN
        UPDATE oe_order_lines_all oola
           SET oola.attribute17 = NVL (p_state, oola.attribute17), oola.attribute20 = NVL (p_status, oola.attribute20), oola.attribute19 = NVL (p_outcome, oola.attribute19)
         WHERE oola.attribute18 = p_line_grp_id;

        x_errbuf    := '';
        x_retcode   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 1;
            x_errbuf    := 'Unexpected Error occured ' || SQLERRM;
    END;

    PROCEDURE upd_line_status_by_line_id (p_line_id IN NUMBER, p_state IN VARCHAR2, p_status IN VARCHAR2
                                          , p_outcome IN VARCHAR2, x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER)
    IS
    BEGIN
        UPDATE oe_order_lines_all oola
           SET oola.attribute17 = NVL (p_state, oola.attribute17), oola.attribute20 = NVL (p_status, oola.attribute20), oola.attribute19 = NVL (p_outcome, oola.attribute19)
         WHERE oola.line_id = p_line_id;

        x_errbuf    := '';
        x_retcode   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 1;
            x_errbuf    := 'Unexpected Error occured ' || SQLERRM;
    END;

    FUNCTION get_line_id (p_line_num            IN NUMBER,
                          p_cust_order_number   IN VARCHAR2)
        RETURN NUMBER
    AS
        l_line_id   NUMBER;
    BEGIN
        SELECT /*+ parallel(2) */
               line_id
          INTO l_line_id
          FROM oe_order_lines_all oola, oe_order_headers_all ooha
         WHERE     ooha.header_id = oola.header_id
               AND ooha.cust_po_number = p_cust_order_number
               AND oola.line_number = p_line_num
               AND oola.org_id IN
                       (SELECT erp_org_id FROM xxdo.xxdoec_country_brand_params);

        RETURN l_line_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;
END xxdoec_process_order_lines;
/


--
-- XXDOEC_PROCESS_ORDER_LINES  (Synonym) 
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDOEC_PROCESS_ORDER_LINES FOR APPS.XXDOEC_PROCESS_ORDER_LINES
/


GRANT EXECUTE ON APPS.XXDOEC_PROCESS_ORDER_LINES TO SOA_INT
/
