--
-- XXDOEC_MANUAL_REFUND_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_MANUAL_REFUND_PKG"
AS
    -- ***************************************************************************************
    -- Package      : XXDOEC_MANUAL_REFUND_PKG
    -- Design       :
    -- Notes        :
    -- Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 12-Jun-2015  1.0       Keith Copeland          Initial version
    -- 23-Apr-2018  1.1       Vijay Reddy             CCR0007157 Zendesk Manual Refunds
    -- ****************************************************************************************

    PROCEDURE get_lines_group_id (x_lines_group_id OUT VARCHAR2)
    IS
    BEGIN
        SELECT TO_CHAR (apps.xxdoec_order_lines_group_s.NEXTVAL)
          INTO x_lines_group_id
          FROM DUAL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_lines_group_id   := NULL;
    END get_lines_group_id;

    PROCEDURE get_order_refund_items (p_header_id apps.xxdoec_order_manual_refunds.header_id%TYPE, o_order_refunds OUT t_refund_cursor)
    AS
    BEGIN
        OPEN o_order_refunds FOR SELECT refund_id, header_id, line_group_id,
                                        line_id, refund_component, refund_quantity,
                                        refund_unit_amount, refund_request_date, refund_reason,
                                        refund_processed_by, refund_type, comments,
                                        pg_status, -- CCR0007157 Zendesk Manual Refunds start
                                                   service_order_number, web_site_id,
                                        currency_code
                                   -- CCR0007157 Zendesk Manual Refunds End
                                   FROM xxdoec_order_manual_refunds
                                  WHERE header_id = p_header_id;
    END get_order_refund_items;

    PROCEDURE update_refund_payment_status (p_line_group_id apps.xxdoec_order_manual_refunds.line_group_id%TYPE, p_refund_id apps.xxdoec_order_manual_refunds.refund_id%TYPE, x_return_status OUT VARCHAR2
                                            , x_error_text OUT VARCHAR2)
    IS
        l_pg_reference_num   VARCHAR2 (120);
        l_pg_status          VARCHAR2 (2);
    BEGIN
        IF p_line_group_id IS NOT NULL
        THEN
            BEGIN
                SELECT pg_reference_num
                  INTO l_pg_reference_num
                  FROM apps.xxdoec_manual_refund_pg_dtls
                 WHERE line_group_id = p_line_group_id AND ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_pg_reference_num   := NULL;
            END;
        ELSIF p_refund_id IS NOT NULL
        THEN
            BEGIN
                SELECT pg_reference_num
                  INTO l_pg_reference_num
                  FROM apps.xxdoec_manual_refund_pg_dtls
                 WHERE refund_id = p_refund_id AND ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_pg_reference_num   := NULL;
            END;
        ELSE
            l_pg_reference_num   := NULL;
        END IF;

        IF l_pg_reference_num IS NOT NULL
        THEN
            l_pg_status   := 'S';
        ELSE
            l_pg_status   := 'E';
        END IF;

        UPDATE xxdoec_order_manual_refunds
           SET pg_status   = l_pg_status
         WHERE line_group_id = p_line_group_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;
            x_error_text      :=
                   'Updating apps.xxdoec_order_manual_refunds table failed with Error: '
                || SQLERRM;
    END update_refund_payment_status;

    PROCEDURE insert_order_manual_refund (p_header_id apps.xxdoec_order_manual_refunds.header_id%TYPE, p_line_group_id apps.xxdoec_order_manual_refunds.line_group_id%TYPE, p_line_id apps.xxdoec_order_manual_refunds.line_id%TYPE, p_refund_component apps.xxdoec_order_manual_refunds.refund_component%TYPE, p_refund_quantity apps.xxdoec_order_manual_refunds.refund_quantity%TYPE, p_refund_unit_amount apps.xxdoec_order_manual_refunds.refund_unit_amount%TYPE, p_refund_reason apps.xxdoec_order_manual_refunds.refund_reason%TYPE, p_refund_processed_by apps.xxdoec_order_manual_refunds.refund_processed_by%TYPE, p_refund_type apps.xxdoec_order_manual_refunds.refund_type%TYPE, p_refund_trx_id apps.xxdoec_order_manual_refunds.refund_trx_id%TYPE, p_refund_trx_status apps.xxdoec_order_manual_refunds.refund_trx_status%TYPE, p_comments apps.xxdoec_order_manual_refunds.comments%TYPE, p_pg_status apps.xxdoec_order_manual_refunds.pg_status%TYPE, --CCR0007157 Zendesk Manual Refunds Start
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         p_service_order_number apps.xxdoec_order_manual_refunds.service_order_number%TYPE, p_web_site_id apps.xxdoec_order_manual_refunds.web_site_id%TYPE, p_currency_code apps.xxdoec_order_manual_refunds.currency_code%TYPE, -- CCR0007157 Zendesk Manual Refunds End
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  x_return_status OUT VARCHAR2, x_error_text OUT VARCHAR2
                                          , x_refund_id OUT NUMBER)
    IS
        l_refund_id   NUMBER;
    BEGIN
        x_return_status   := fnd_api.G_RET_STS_SUCCESS;
        x_error_text      := NULL;
        l_refund_id       := XXDOEC_ORDER_MANUAL_REFUNDS_S.NEXTVAL;

        INSERT INTO apps.xxdoec_order_manual_refunds (refund_id,
                                                      header_id,
                                                      line_group_id,
                                                      line_id,
                                                      refund_component,
                                                      refund_quantity,
                                                      refund_unit_amount,
                                                      refund_request_date,
                                                      refund_reason,
                                                      refund_processed_by,
                                                      refund_type,
                                                      refund_trx_id,
                                                      refund_trx_status,
                                                      comments,
                                                      pg_status,
                                                      service_order_number,
                                                      web_site_id,
                                                      currency_code)
             VALUES (l_refund_id, p_header_id, p_line_group_id,
                     p_line_id, p_refund_component, p_refund_quantity,
                     p_refund_unit_amount, SYSDATE, p_refund_reason,
                     p_refund_processed_by, p_refund_type, p_refund_trx_id,
                     p_refund_trx_status, p_comments, p_pg_status,
                     p_service_order_number, p_web_site_id, p_currency_code);

        x_refund_id       := l_refund_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;
            x_error_text      :=
                   'Insert into apps.xxdoec_order_manual_refunds table failed with Error: '
                || SQLERRM;
            x_refund_id       := NULL;
    END insert_order_manual_refund;

    PROCEDURE insert_manual_refund_array (p_refund_tbl IN apps.xxdoec_Refund_tbl_Type, x_rtn_status OUT VARCHAR2, x_error_msg OUT VARCHAR2)
    AS
    BEGIN
        x_rtn_status   := fnd_api.G_RET_STS_SUCCESS;
        x_error_msg    := NULL;

        IF p_refund_tbl.COUNT > 0
        THEN
            -- Create refunds
            FOR i IN p_refund_tbl.FIRST .. p_refund_tbl.LAST
            LOOP
                BEGIN
                    INSERT INTO apps.xxdoec_order_manual_refunds (
                                    refund_id,
                                    header_id,
                                    line_group_id,
                                    line_id,
                                    refund_component,
                                    refund_quantity,
                                    refund_unit_amount,
                                    refund_request_date,
                                    refund_reason,
                                    refund_processed_by,
                                    refund_type,
                                    refund_trx_id,
                                    refund_trx_status,
                                    comments,
                                    pg_status,
                                    service_order_number,
                                    web_site_id,
                                    currency_code)
                             VALUES (XXDOEC_ORDER_MANUAL_REFUNDS_S.NEXTVAL,
                                     p_refund_tbl (i).p_header_id,
                                     p_refund_tbl (i).p_line_group_id,
                                     p_refund_tbl (i).p_line_id,
                                     p_refund_tbl (i).p_refund_component,
                                     p_refund_tbl (i).p_refund_quantity,
                                     p_refund_tbl (i).p_refund_unit_amount,
                                     SYSDATE,
                                     p_refund_tbl (i).p_refund_reason,
                                     p_refund_tbl (i).p_refund_processed_by,
                                     p_refund_tbl (i).p_refund_type,
                                     p_refund_tbl (i).p_refund_trx_id,
                                     p_refund_tbl (i).p_refund_trx_status,
                                     p_refund_tbl (i).p_comments,
                                     p_refund_tbl (i).p_pg_status,
                                     p_refund_tbl (i).p_service_order_number,
                                     p_refund_tbl (i).p_web_site_id,
                                     p_refund_tbl (i).p_currency_code);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_rtn_status   := FND_API.G_RET_STS_UNEXP_ERROR;
                        x_error_msg    :=
                               'Insert into apps.xxdoec_manual_refund_pg_dtls table failed with Error: '
                            || SQLERRM;
                END;
            END LOOP;
        END IF;
    END insert_manual_refund_array;

    PROCEDURE insert_manual_refund_dtls (
        p_header_id                 apps.xxdoec_manual_refund_pg_dtls.header_id%TYPE,
        p_line_group_id             apps.xxdoec_manual_refund_pg_dtls.line_group_id%TYPE,
        p_payment_type              apps.xxdoec_manual_refund_pg_dtls.payment_type%TYPE,
        p_payment_date              apps.xxdoec_manual_refund_pg_dtls.payment_date%TYPE,
        p_payment_amount            apps.xxdoec_manual_refund_pg_dtls.payment_amount%TYPE,
        p_pg_reference_num          apps.xxdoec_manual_refund_pg_dtls.pg_reference_num%TYPE,
        p_unapplied_amount          apps.xxdoec_manual_refund_pg_dtls.unapplied_amount%TYPE,
        p_status                    apps.xxdoec_manual_refund_pg_dtls.status%TYPE,
        -- CCR0007157 Zendesk Manual Refunds Start
        p_refund_id                 apps.xxdoec_manual_refund_pg_dtls.refund_id%TYPE,
        p_payment_tender_type       apps.xxdoec_manual_refund_pg_dtls.payment_tender_type%TYPE,
        p_currency_code             apps.xxdoec_manual_refund_pg_dtls.currency_code%TYPE,
        -- CCR0007157 Zendesk Manual Refunds End
        p_refund_reason             apps.xxdoec_manual_refund_pg_dtls.refund_reason%TYPE,
        x_return_status         OUT VARCHAR2,
        x_error_text            OUT VARCHAR2)
    IS
    BEGIN
        x_return_status   := fnd_api.G_RET_STS_SUCCESS;
        x_error_text      := NULL;

        INSERT INTO apps.xxdoec_manual_refund_pg_dtls (refund_pg_dtl_id, header_id, line_group_id, payment_type, payment_date, payment_amount, pg_reference_num, unapplied_amount, status, refund_id, payment_tender_type, currency_code
                                                       , refund_reason)
             VALUES (xxdoec_manual_refund_pg_dtls_s.NEXTVAL, p_header_id, p_line_group_id, p_payment_type, p_payment_date, p_payment_amount, p_pg_reference_num, p_unapplied_amount, p_status, p_refund_id, p_payment_tender_type, p_currency_code
                     , p_refund_reason);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := FND_API.G_RET_STS_UNEXP_ERROR;
            x_error_text      :=
                   'Insert into apps.xxdoec_manual_refund_pg_dtls table failed with Error: '
                || SQLERRM;
    END insert_manual_refund_dtls;
END XXDOEC_MANUAL_REFUND_PKG;
/
