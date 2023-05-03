--
-- XXDOEC_OEOL_WF_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_OEOL_WF_PKG"
AS
    /***********************************************************************************
     * Program Name : XXDOEC_PROCESS_ORDER_LINES
     * Description  :
     *
     * History      :
     *
     * ===============================================================================
     * Who                   Version    Comments                          When
     * ===============================================================================
     * BT Technology Team    1.1        Created for BT                    05-JAN-2015
     * Vijay Reddy           1.2        CCR0008717 - S2S orders should be 16-JUN-2020
     * Gaurav Joshi          1.3        CCR0009841    - US6 defaulting rule   10-Mar-2022
     ***********************************************************************************/
    PROCEDURE update_line_custom_status (
        p_line_id       IN     NUMBER,
        p_status_code   IN     VARCHAR2,
        p_reason_code   IN     VARCHAR2 DEFAULT NULL,
        x_rtn_sts          OUT VARCHAR2,
        x_rtn_msg          OUT VARCHAR2)
    IS
    BEGIN
        UPDATE oe_order_lines_all
           SET attribute20 = p_status_code, attribute19 = p_reason_code, attribute18 = NULL,
               attribute17 = 'N', CONTEXT = 'DO eCommerce'
         WHERE line_id = p_line_id;

        IF SQL%ROWCOUNT = 1
        THEN
            x_rtn_sts   := fnd_api.g_ret_sts_success;
        ELSE
            x_rtn_sts   := fnd_api.g_ret_sts_error;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_sts   := fnd_api.g_ret_sts_unexp_error;
            x_rtn_msg   := SQLERRM;
    END update_line_custom_status;

    PROCEDURE check_latest_acceptable_date (itemtype    IN     VARCHAR2,
                                            itemkey     IN     VARCHAR2,
                                            actid       IN     NUMBER,
                                            funcmode    IN     VARCHAR2,
                                            resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_rec               oe_order_pub.line_rec_type;
        l_line_id                NUMBER;
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD (
                    ' Within SCHEDULE LINE - check latest Acceptable date step ');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'SCH',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);
            oe_line_util.query_row (p_line_id    => l_line_id,
                                    x_line_rec   => l_line_rec);

            IF TRUNC (NVL (l_line_rec.latest_acceptable_date, SYSDATE)) <
               TRUNC (SYSDATE)
            THEN
                resultout   := 'COMPLETE:UNAVAILABLE';
            ELSE
                resultout   := 'COMPLETE:ON_HAND_AVAILABLE';
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'Schedule Line-Check latest acceptable date', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END check_latest_acceptable_date;

    --
    PROCEDURE mark_fraud_check (itemtype    IN     VARCHAR2,
                                itemkey     IN     VARCHAR2,
                                actid       IN     NUMBER,
                                funcmode    IN     VARCHAR2,
                                resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Mark Order Line for Fraud Check ');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            resultout   := 'COMPLETE:';
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'FRC',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:';
            ELSE
                oe_debug_pub.ADD (
                    'Unable to Mark Order Line for Fraud Check ' || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'Send Order dtls to Accertify - Check Fraud', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_fraud_check;

    --
    PROCEDURE mark_pg_authorization (itemtype    IN     VARCHAR2,
                                     itemkey     IN     VARCHAR2,
                                     actid       IN     NUMBER,
                                     funcmode    IN     VARCHAR2,
                                     resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD (
                    'Mark Order Line for Payment Gateway Authorization');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'PGA',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:';
            ELSE
                oe_debug_pub.ADD (
                       'Unable to Mark Order Line for Payment Gateway Authorization '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'Get Payment Gateway Authorization', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_pg_authorization;

    --
    PROCEDURE mark_shipment_email (itemtype    IN     VARCHAR2,
                                   itemkey     IN     VARCHAR2,
                                   actid       IN     NUMBER,
                                   funcmode    IN     VARCHAR2,
                                   resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD (
                    'Mark Order Line for Shipment Confirmation e-mail');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'SHE',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:';
            ELSE
                oe_debug_pub.ADD (
                       'Unable to Mark Order Line for Shipment Confirmation e-mail '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Send Shipment Confirmation e-mail', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_shipment_email;

    --
    PROCEDURE mark_pg_capture_funds (itemtype    IN     VARCHAR2,
                                     itemkey     IN     VARCHAR2,
                                     actid       IN     NUMBER,
                                     funcmode    IN     VARCHAR2,
                                     resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD (
                    'Mark Order Line for Payment Gateway Capture Funds');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'PGC',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:';
            ELSE
                oe_debug_pub.ADD (
                       'Unable to Mark Order Line for Payment Gateway Capture Funds '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Payment Gateway Capture funds', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_pg_capture_funds;

    --
    PROCEDURE mark_cancel_actions (itemtype    IN     VARCHAR2,
                                   itemkey     IN     VARCHAR2,
                                   actid       IN     NUMBER,
                                   funcmode    IN     VARCHAR2,
                                   resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_rec               oe_order_pub.line_rec_type;
        l_line_id                NUMBER;
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Mark Order Line for Cancellation Email');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            oe_line_util.query_row (p_line_id    => l_line_id,
                                    x_line_rec   => l_line_rec);
            update_line_custom_status (
                p_line_id       => l_line_id,
                p_status_code   => 'CAA',
                p_reason_code   => l_line_rec.attribute20,
                x_rtn_sts       => l_rtn_status,
                x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:';
            ELSE
                oe_debug_pub.ADD (
                       'Unable to Mark Order Line for Cancellation Email '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Send Order Line Cancellation Email', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_cancel_actions;

    --
    PROCEDURE mark_cancel_email (itemtype    IN     VARCHAR2,
                                 itemkey     IN     VARCHAR2,
                                 actid       IN     NUMBER,
                                 funcmode    IN     VARCHAR2,
                                 resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_rec               oe_order_pub.line_rec_type;
        l_line_id                NUMBER;
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Mark Order Line for Cancellation Email');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            oe_line_util.query_row (p_line_id    => l_line_id,
                                    x_line_rec   => l_line_rec);
            update_line_custom_status (
                p_line_id       => l_line_id,
                p_status_code   => 'CAA',
                p_reason_code   => l_line_rec.attribute20,
                x_rtn_sts       => l_rtn_status,
                x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:';
            ELSE
                oe_debug_pub.ADD (
                       'Unable to Mark Order Line for Cancellation Email '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Send Order Line Cancellation Email', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_cancel_email;

    --
    PROCEDURE cancel_line (itemtype IN VARCHAR2, itemkey IN VARCHAR2, actid IN NUMBER
                           , funcmode IN VARCHAR2, resultout IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_rec               oe_order_pub.line_rec_type;
        l_line_id                NUMBER;
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Cancel Order Line');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            oe_line_util.query_row (p_line_id    => l_line_id,
                                    x_line_rec   => l_line_rec);
            xxdoec_process_order_lines.cancel_line (
                p_line_id        => l_line_id,
                p_reason_code    => l_line_rec.attribute19,
                x_rtn_status     => l_rtn_status,
                x_rtn_msg_data   => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:';
            ELSE
                oe_debug_pub.ADD (
                    'Unable to Cancel Order Line ' || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Cancel Order Line', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END cancel_line;

    --
    PROCEDURE mark_receipt_email (itemtype    IN     VARCHAR2,
                                  itemkey     IN     VARCHAR2,
                                  actid       IN     NUMBER,
                                  funcmode    IN     VARCHAR2,
                                  resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD (
                    'Mark Order Line for Receipt Confirmation e-mail');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'RCE',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:';
            ELSE
                oe_debug_pub.ADD (
                       'Unable to Mark Order Line for Receipt Confirmation e-mail '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Send Receipt Confirmation e-mail', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_receipt_email;

    --
    PROCEDURE mark_pg_chargeback (itemtype    IN     VARCHAR2,
                                  itemkey     IN     VARCHAR2,
                                  actid       IN     NUMBER,
                                  funcmode    IN     VARCHAR2,
                                  resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_result                 VARCHAR2 (120);
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Mark Returned Order Line for Chargeback ');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'CHB',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:' || l_result;
            ELSE
                oe_debug_pub.ADD (
                       'Unable to mark Returned Order Line for Chargeback '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Chargeback Retuen Order Line', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_pg_chargeback;

    PROCEDURE get_do_order_type (itemtype    IN     VARCHAR2,
                                 itemkey     IN     VARCHAR2,
                                 actid       IN     NUMBER,
                                 funcmode    IN     VARCHAR2,
                                 resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_result                 VARCHAR2 (120);

        CURSOR c_do_order_type IS
            SELECT ott.attribute13
              FROM oe_transaction_types_all ott, oe_order_headers_all ooh, oe_order_lines_all ool
             WHERE     ott.transaction_type_id = ooh.order_type_id
                   AND ooh.header_id = ool.header_id
                   AND ool.line_id = l_line_id;
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Get DO Order Type for CA order ');
            END IF;

            oe_standard_wf.set_msg_context (actid);

            OPEN c_do_order_type;

            FETCH c_do_order_type INTO l_result;

            IF c_do_order_type%FOUND
            THEN
                CLOSE c_do_order_type;

                resultout   := 'COMPLETE:' || l_result;
            ELSE
                CLOSE c_do_order_type;

                oe_debug_pub.ADD (
                    'Unable to derive DO Order Type for CA order');
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Get DO Order Type', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END get_do_order_type;

    PROCEDURE get_do_return_type (itemtype    IN     VARCHAR2,
                                  itemkey     IN     VARCHAR2,
                                  actid       IN     NUMBER,
                                  funcmode    IN     VARCHAR2,
                                  resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_result                 VARCHAR2 (120);

        CURSOR c_do_order_type IS
            SELECT ott.attribute13
              FROM oe_transaction_types_all ott, oe_order_headers_all ooh, oe_order_lines_all ool
             WHERE     ott.transaction_type_id = ooh.order_type_id
                   AND ooh.header_id = ool.header_id
                   AND ool.line_id = l_line_id;
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Get DO Return Type for CA order ');
            END IF;

            oe_standard_wf.set_msg_context (actid);

            OPEN c_do_order_type;

            FETCH c_do_order_type INTO l_result;

            IF c_do_order_type%FOUND
            THEN
                CLOSE c_do_order_type;

                resultout   := 'COMPLETE:' || l_result;
            ELSE
                CLOSE c_do_order_type;

                oe_debug_pub.ADD (
                    'Unable to derive DO Return Type for CA order');
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Get DO Return Type', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END get_do_return_type;

    PROCEDURE mark_ca_ship_notif (itemtype    IN     VARCHAR2,
                                  itemkey     IN     VARCHAR2,
                                  actid       IN     NUMBER,
                                  funcmode    IN     VARCHAR2,
                                  resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_result                 VARCHAR2 (120);
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Mark CA Order line for Ship Notification');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'CSN',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:' || l_result;
            ELSE
                oe_debug_pub.ADD (
                       'Unable to mark CA Order line for Ship Notification '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC CA Order Line Ship Notification', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_ca_ship_notif;

    PROCEDURE mark_ca_ship_email (itemtype    IN     VARCHAR2,
                                  itemkey     IN     VARCHAR2,
                                  actid       IN     NUMBER,
                                  funcmode    IN     VARCHAR2,
                                  resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_result                 VARCHAR2 (120);
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD (
                    'Mark CA exchange Order Line for Ship e_mail ');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'CSE',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:' || l_result;
            ELSE
                oe_debug_pub.ADD (
                       'Unable to mark CA exchange Order Line for ship e-mail '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC CA exchange Order Line Ship Email', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_ca_ship_email;

    PROCEDURE mark_ca_refund_notif (itemtype    IN     VARCHAR2,
                                    itemkey     IN     VARCHAR2,
                                    actid       IN     NUMBER,
                                    funcmode    IN     VARCHAR2,
                                    resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_result                 VARCHAR2 (120);
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Mark CA Returned Order Line for refund');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'CRN',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:' || l_result;
            ELSE
                oe_debug_pub.ADD (
                       'Unable to mark CA Returned Order Line for refund '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC CA Retuend Order Line for refund', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_ca_refund_notif;

    PROCEDURE mark_ca_receipt_email (itemtype    IN     VARCHAR2,
                                     itemkey     IN     VARCHAR2,
                                     actid       IN     NUMBER,
                                     funcmode    IN     VARCHAR2,
                                     resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_result                 VARCHAR2 (120);
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD (
                    'Mark CA exchange Return Line for receipt Email');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'CRE',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:' || l_result;
            ELSE
                oe_debug_pub.ADD (
                       'Unable to mark CA exchnage Return Line for Receipt email '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC CA exchange Return Line for Receipt email', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_ca_receipt_email;

    PROCEDURE is_customized_product (itemtype    IN     VARCHAR2,
                                     itemkey     IN     VARCHAR2,
                                     actid       IN     NUMBER,
                                     funcmode    IN     VARCHAR2,
                                     resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_dummy                  NUMBER;

        CURSOR c_check_cp (c_order_line_id IN NUMBER)
        IS
            SELECT 1
              FROM oe_order_lines_all ool, ---mtl_system_items_b msi         --commented  by BT Technology Team on 12-01-2015
                                           apps.xxd_common_items_v msi --added  by BT Technology Team on 12-01-2015
             WHERE     ool.line_id = c_order_line_id
                   AND msi.inventory_item_id = ool.inventory_item_id
                   AND msi.organization_id = ool.ship_from_org_id
                   --AND msi.segment2 = 'CUSTOM';  --commented  by BT Technology Team on 12-01-2015
                   AND msi.COLOR_CODE = 'CUSTOM'; --added  by BT Technology Team on 12-01-2015
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Check if it is a customized product');
            END IF;

            oe_standard_wf.set_msg_context (actid);

            OPEN c_check_cp (l_line_id);

            FETCH c_check_cp INTO l_dummy;

            IF c_check_cp%FOUND
            THEN
                CLOSE c_check_cp;

                resultout   := 'COMPLETE:' || 'Y';
            ELSE
                CLOSE c_check_cp;

                resultout   := 'COMPLETE:' || 'N';
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Unable to check if customized Product', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END is_customized_product;

    PROCEDURE mark_to_send_to_m2o (itemtype    IN     VARCHAR2,
                                   itemkey     IN     VARCHAR2,
                                   actid       IN     NUMBER,
                                   funcmode    IN     VARCHAR2,
                                   resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_result                 VARCHAR2 (120);
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Mark order line to interface to MTO');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'MTO',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:' || l_result;
            ELSE
                oe_debug_pub.ADD (
                       'Unable to mark order line to interface to M2O '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC mark order line to interface to M2O', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_to_send_to_m2o;

    PROCEDURE mark_order_ack_email (itemtype    IN     VARCHAR2,
                                    itemkey     IN     VARCHAR2,
                                    actid       IN     NUMBER,
                                    funcmode    IN     VARCHAR2,
                                    resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_result                 VARCHAR2 (120);
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Mark order line for In Production Email');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'IPE',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:' || l_result;
            ELSE
                oe_debug_pub.ADD (
                       'Unable to mark order line for In Production Email '
                    || l_rtn_msg);
            END IF;
        END IF;

        --
        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Mark order line for In Production Email', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END mark_order_ack_email;

    -- **********************************

    PROCEDURE mark_sfs_action (itemtype    IN     VARCHAR2,
                               itemkey     IN     VARCHAR2,
                               actid       IN     NUMBER,
                               funcmode    IN     VARCHAR2,
                               resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_line_id                NUMBER;
        l_result                 VARCHAR2 (120);
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD ('Mark order line for Ship from Store');
            END IF;

            oe_standard_wf.set_msg_context (actid);
            update_line_custom_status (p_line_id       => l_line_id,
                                       p_status_code   => 'SFS',
                                       p_reason_code   => NULL,
                                       x_rtn_sts       => l_rtn_status,
                                       x_rtn_msg       => l_rtn_msg);

            IF l_rtn_status = fnd_api.g_ret_sts_success
            THEN
                resultout   := 'COMPLETE:' || l_result;
            ELSE
                oe_debug_pub.ADD (
                       'Unable to mark order line for Ship from Store '
                    || l_rtn_msg);
            END IF;
        END IF;



        --

        IF (funcmode = 'CANCEL')
        THEN
            NULL;

            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Mark order line for Ship from Store', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);

            RAISE;
    END mark_sfs_action;

    -- **********************************

    PROCEDURE update_source_type_code (itemtype    IN     VARCHAR2,
                                       itemkey     IN     VARCHAR2,
                                       actid       IN     NUMBER,
                                       funcmode    IN     VARCHAR2,
                                       resultout   IN OUT VARCHAR2)
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;

        CURSOR c_line_dtls (c_line_id IN NUMBER)
        IS
            SELECT ooh.org_id, inventory_item_id, ool.request_date, -- ver 1.3
                   ooh.order_type_id                                -- ver 1.3
              FROM oe_order_lines_all ool, oe_order_headers_all ooh -- ver 1.3
             WHERE line_id = c_line_id AND ool.header_id = ooh.header_id; -- ver 1.3

        CURSOR c_warehouse_id (c_line_id IN NUMBER)
        IS
            SELECT attribute_value
              FROM xxdoec_order_attribute
             WHERE attribute_type = 'S2SINVORGID' AND line_id = c_line_id;

        l_line_id                NUMBER;
        l_org_id                 NUMBER;
        l_item_id                NUMBER;
        l_warehouse_id           NUMBER;
        l_result                 VARCHAR2 (120);
        l_rtn_status             VARCHAR2 (10);
        l_rtn_msg                VARCHAR2 (2000);
        l_request_date           DATE;                              -- VER 1.3
        l_order_type             NUMBER;                            -- VER 1.3
    BEGIN
        l_line_id   := TO_NUMBER (itemkey);

        IF (funcmode = 'RUN')
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('Item Key:  ' || itemkey);
                oe_debug_pub.ADD (
                    'Update order line Source type code, Warehouse');
            END IF;

            oe_standard_wf.set_msg_context (actid);

            -- fetch line details
            OPEN c_line_dtls (l_line_id);

            FETCH c_line_dtls INTO l_org_id, l_item_id, l_request_date, l_order_type;

            CLOSE c_line_dtls;

            -- Get Warehouse ID
            l_warehouse_id   := NULL;

            -- Start CCR0008717 changes
            OPEN c_warehouse_id (l_line_id);

            FETCH c_warehouse_id INTO l_warehouse_id;

            IF c_warehouse_id%FOUND
            THEN
                CLOSE c_warehouse_id;
            ELSE
                CLOSE c_warehouse_id;

                -- begin 1.3
                /*xxd_do_om_default_rules.get_warehouse (p_org_id          => l_org_id,
                                                   p_line_type_id        => NULL,
                                                   p_inventory_item_id   => l_item_id,
                                                   x_warehouse_id        => l_warehouse_id);
                  */
                l_warehouse_id   :=
                    xxd_do_om_default_rules.ret_inv_warehouse (
                        p_org_id              => l_org_id,
                        p_order_type_id       => l_order_type,
                        p_line_type_id        => NULL,
                        p_request_date        => l_request_date,
                        p_inventory_item_id   => l_item_id);
            -- end 1.3
            END IF;

            -- End CCR0008717 changes
            --update source type code, warehouse
            UPDATE oe_order_lines_all ool
               SET source_type_code = 'INTERNAL', ship_from_org_id = l_warehouse_id
             WHERE line_id = l_line_id;

            IF SQL%ROWCOUNT = 1
            THEN
                resultout   := 'COMPLETE:' || l_result;
            ELSE
                oe_debug_pub.ADD (
                       'Unable to Update order line Source Type, Warehouse '
                    || l_rtn_msg);
            END IF;

            --
            UPDATE xxdoec_sfs_shipment_dtls_stg
               SET process_flag   = 'Y'
             WHERE line_id = l_line_id;
        END IF;

        --

        IF (funcmode = 'CANCEL')
        THEN
            NULL;
            RETURN;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            wf_core.CONTEXT ('OE_OEOL_SCH', 'DOEC Update order line Source Type, Warehouse', itemtype
                             , itemkey, TO_CHAR (actid), funcmode);
            RAISE;
    END update_source_type_code;

    PROCEDURE CHECK_FLAG_STAFF (itemtype    IN            VARCHAR2,
                                itemkey     IN            VARCHAR2,
                                actid       IN            NUMBER,
                                funcmode    IN            VARCHAR2,
                                resultout      OUT NOCOPY VARCHAR2)
    IS
        ln_line_id   NUMBER;
        lc_source    VARCHAR2 (100);

        CURSOR get_order_source (p_line_id IN NUMBER)
        IS
            SELECT oos.name
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, oe_order_sources oos
             WHERE     ooha.header_id = oola.header_id
                   AND ooha.order_source_id = oos.order_source_id
                   AND oola.line_id = p_line_id;
    BEGIN
        IF (funcmode <> wf_engine.eng_run)
        THEN
            --
            resultout   := wf_engine.eng_null;
            RETURN;
        --
        END IF;

        ln_line_id   := TO_NUMBER (itemkey);

        OPEN get_order_source (ln_line_id);

        FETCH get_order_source INTO lc_source;

        CLOSE get_order_source;

        IF lc_source = 'Flagstaff'
        THEN
            resultout   := wf_engine.eng_completed || ':' || 'Y';
        ELSE
            resultout   := wf_engine.eng_completed || ':' || 'N';
        END IF;
    END CHECK_FLAG_STAFF;
END xxdoec_oeol_wf_pkg;
/
