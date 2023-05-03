--
-- XXDOEC_CA_SETTLEMENT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_CA_SETTLEMENT_PKG"
AS
    -- Author  : VIJAY.REDDY
    -- Created : 1/7/2012 6:27:51 PM
    -- Purpose : Match to an order line and Invoice then create cash receipts
    --
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

    --
    PROCEDURE update_stlmnt_header (p_stlmnt_hdr_id IN NUMBER, p_receipts_batch_id IN NUMBER, p_interface_status IN VARCHAR2
                                    , p_error_message IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxdoec_ca_stlmnt_headers
           SET interface_status = p_interface_status, error_message = p_error_message, receipts_batch_id = NVL (p_receipts_batch_id, receipts_batch_id)
         WHERE stlmnt_header_id = p_stlmnt_hdr_id;

        COMMIT;
    END update_stlmnt_header;

    --
    PROCEDURE update_stlmnt_lines (p_stlmnt_hdr_id      IN NUMBER,
                                   p_cust_trx_id        IN NUMBER,
                                   p_cash_receipt_id    IN NUMBER,
                                   p_interface_status   IN VARCHAR2,
                                   p_error_message      IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxdoec_ca_stlmnt_lines
           SET interface_status = p_interface_status, error_message = p_error_message, cash_receipt_id = p_cash_receipt_id
         WHERE     customer_trx_id = p_cust_trx_id
               AND stlmnt_header_id = p_stlmnt_hdr_id
               AND cash_receipt_id IS NULL;

        COMMIT;
    END update_stlmnt_lines;

    --
    PROCEDURE insert_header (P_WEBSITE_ID IN VARCHAR2, P_SETTLEMENT_ID IN VARCHAR2, P_CURRENCY_CODE IN VARCHAR2, P_TOTAL_AMOUNT IN NUMBER, P_DEPOSIT_DATE IN DATE, P_TRANS_START_DATE IN DATE, P_TRANS_END_DATE IN DATE, X_STLMNT_HEADER_ID IN OUT NUMBER, X_RTN_STATUS OUT VARCHAR2
                             , X_RTN_MESSAGE OUT VARCHAR2)
    IS
    BEGIN
        SELECT XXDOEC_CA_STLMNT_HEADERS_S.NEXTVAL
          INTO X_STLMNT_HEADER_ID
          FROM DUAL;

        --
        INSERT INTO XXDOEC_CA_STLMNT_HEADERS (STLMNT_HEADER_ID,
                                              WEBSITE_ID,
                                              SETTLEMENT_ID,
                                              CURRENCY_CODE,
                                              TOTAL_AMOUNT,
                                              DEPOSIT_DATE,
                                              TRANS_START_DATE,
                                              TRANS_END_DATE,
                                              RECEIPTS_BATCH_ID,
                                              INTERFACE_STATUS,
                                              ERROR_MESSAGE)
             VALUES (X_STLMNT_HEADER_ID, P_WEBSITE_ID, P_SETTLEMENT_ID,
                     P_CURRENCY_CODE, P_TOTAL_AMOUNT, P_DEPOSIT_DATE,
                     P_TRANS_START_DATE, P_TRANS_END_DATE, NULL,
                     'N', NULL);
    EXCEPTION
        WHEN OTHERS
        THEN
            X_RTN_STATUS         := FND_API.G_RET_STS_UNEXP_ERROR;
            X_RTN_MESSAGE        := SQLERRM;
            X_STLMNT_HEADER_ID   := NULL;
    END insert_header;

    --
    PROCEDURE insert_line (P_STLMNT_HEADER_ID IN NUMBER, P_SETTLEMENT_ID IN VARCHAR2, P_TRANSACTION_TYPE IN VARCHAR2, P_SELLER_ORDER_ID IN VARCHAR2, P_MERCHANT_ORDER_ID IN VARCHAR2, P_POSTED_DATE IN DATE, P_SELLER_ITEM_CODE IN VARCHAR2, P_MERCHANT_ADJ_ITEM_ID IN VARCHAR2, P_SKU IN VARCHAR2, P_QUANTITY IN NUMBER, P_PRINCIPAL_AMOUNT IN NUMBER, P_COMMISSION_AMOUNT IN NUMBER, P_FREIGHT_AMOUNT IN NUMBER, P_TAX_AMOUNT IN NUMBER, P_PROMO_AMOUNT IN NUMBER
                           , X_STLMNT_LINE_ID IN OUT NUMBER, X_RTN_STATUS OUT VARCHAR2, X_RTN_MESSAGE OUT VARCHAR2)
    IS
    BEGIN
        SELECT XXDOEC_CA_STLMNT_LINES_S.NEXTVAL
          INTO X_STLMNT_LINE_ID
          FROM DUAL;

        INSERT INTO XXDOEC_CA_STLMNT_LINES (STLMNT_LINE_ID,
                                            STLMNT_HEADER_ID,
                                            SETTLEMENT_ID,
                                            TRANSACTION_TYPE,
                                            SELLER_ORDER_ID,
                                            MERCHANT_ORDER_ID,
                                            POSTED_DATE,
                                            SELLER_ITEM_CODE,
                                            MERCHANT_ADJ_ITEM_ID,
                                            SKU,
                                            QUANTITY,
                                            PRINCIPAL_AMOUNT,
                                            COMMISSION_AMOUNT,
                                            FREIGHT_AMOUNT,
                                            TAX_AMOUNT,
                                            PROMO_AMOUNT,
                                            ORDER_LINE_ID,
                                            CUSTOMER_TRX_ID,
                                            CASH_RECEIPT_ID,
                                            INTERFACE_STATUS,
                                            ERROR_MESSAGE)
             VALUES (X_STLMNT_LINE_ID, P_STLMNT_HEADER_ID, P_SETTLEMENT_ID,
                     P_TRANSACTION_TYPE, P_SELLER_ORDER_ID, P_MERCHANT_ORDER_ID, P_POSTED_DATE, P_SELLER_ITEM_CODE, P_MERCHANT_ADJ_ITEM_ID, P_SKU, P_QUANTITY, P_PRINCIPAL_AMOUNT, P_COMMISSION_AMOUNT, P_FREIGHT_AMOUNT, P_TAX_AMOUNT, P_PROMO_AMOUNT, NULL, NULL
                     , NULL, 'N', NULL);
    EXCEPTION
        WHEN OTHERS
        THEN
            X_RTN_STATUS       := FND_API.G_RET_STS_UNEXP_ERROR;
            X_RTN_MESSAGE      := SQLERRM;
            X_STLMNT_LINE_ID   := NULL;
    END insert_line;

    --
    PROCEDURE validate_header (p_stlmnt_hdr_id IN NUMBER)
    IS
        l_lines_total_amt   NUMBER;

        CURSOR c_headers IS
            SELECT stlmnt_header_id, total_amount
              FROM xxdoec_ca_stlmnt_headers csh
             WHERE stlmnt_header_id = p_stlmnt_hdr_id
            FOR UPDATE;

        CURSOR c_lines (c_stlmnt_hdr_id IN NUMBER)
        IS
            SELECT SUM (NVL (csl.principal_amount, 0) + NVL (csl.commission_amount, 0) + NVL (csl.freight_amount, 0) + NVL (csl.tax_amount, 0) + NVL (csl.promo_amount, 0)) lines_total_amt
              FROM xxdoec_ca_stlmnt_lines csl
             WHERE stlmnt_header_id = c_stlmnt_hdr_id;
    BEGIN
        FOR c_hdr IN c_headers
        LOOP
            l_lines_total_amt   := 0;

            OPEN c_lines (c_hdr.stlmnt_header_id);

            FETCH c_lines INTO l_lines_total_amt;

            CLOSE c_lines;

            --
            IF c_hdr.total_amount <> l_lines_total_amt
            THEN
                UPDATE xxdoec_ca_stlmnt_headers
                   SET interface_status = 'W', error_message = 'Settlement Header total ' || c_hdr.total_amount || ' does not match to lines total amount ' || l_lines_total_amt
                 WHERE CURRENT OF c_headers;

                msg (
                       'Settlement Header total '
                    || c_hdr.total_amount
                    || ' does not match to lines total amount '
                    || l_lines_total_amt);
            ELSE
                msg (
                       'Settlement Header total '
                    || c_hdr.total_amount
                    || ' matches to lines total amount '
                    || l_lines_total_amt);
            END IF;
        END LOOP;
    END validate_header;

    PROCEDURE match_lines (p_stlmnt_hdr_id IN NUMBER, x_rtn_status OUT VARCHAR2, x_rtn_message OUT VARCHAR2)
    IS
        CURSOR c_lines IS
            SELECT csl.*
              FROM xxdoec_ca_stlmnt_lines csl
             WHERE     stlmnt_header_id = p_stlmnt_hdr_id
                   AND csl.order_line_id IS NULL
            FOR UPDATE;

        CURSOR c_oe_line (p_seller_hdr_id IN VARCHAR2, p_sku IN VARCHAR2)
        IS
            SELECT ooh.order_number, ool.line_id
              FROM oe_order_headers_all ooh, oe_order_lines_all ool, --   mtl_system_items_b_kfv msik    -- 1.0 : Commented for BT.
                                                                     mtl_system_items_b msi -- 1.0 : Modified for BT.
                                                                                           ,
                   oe_order_sources oos                 -- 1.0 : Added for BT.
             --   WHERE ooh.order_source_id = 1044 -- flagstaff   -- 1.0 : Commented for BT.
             WHERE     ooh.order_source_id = oos.order_source_id -- 1.0 : Modified for BT.
                   AND UPPER (oos.name) = 'FLAGSTAFF' -- 1.0 : Modified for BT.
                   AND ooh.orig_sys_document_ref = '99' || p_seller_hdr_id
                   AND ool.header_id = ooh.header_id
                   AND ool.line_category_code = 'ORDER'
                   /* -- 1.0 : START : Commented for BT.
                   AND msik.concatenated_segments = p_sku
                   AND msik.organization_id = ool.ship_from_org_id
                   AND ool.inventory_item_id = msik.inventory_item_id;
                   */
                   -- 1.0 : END : Commented for BT.
                   -- 1.0 : START : Modified for BT.
                   AND msi.segment1 = p_sku
                   AND msi.organization_id = ool.ship_from_org_id
                   AND msi.inventory_item_id = ool.inventory_item_id;

        -- 1.0 : END : Modified for BT.

        CURSOR c_rtn_line (p_seller_hdr_id IN VARCHAR2, p_sku IN VARCHAR2)
        IS
            SELECT oohr.order_number, oolr.line_id
              FROM oe_order_headers_all ooh, oe_order_lines_all ool, oe_order_lines_all oolr,
                   oe_order_headers_all oohr, --    mtl_system_items_b_kfv msik     -- 1.0 : Commented for BT.
                                              mtl_system_items_b msi -- 1.0 : Modified for BT.
                                                                    , oe_order_sources oos -- 1.0 : Added for BT.
             --  WHERE ooh.order_source_id = 1044 -- flagstaff   -- 1.0 : Commented for BT.
             WHERE     ooh.order_source_id = oos.order_source_id -- 1.0 : Modified for BT.
                   AND UPPER (oos.name) = 'FLAGSTAFF' -- 1.0 : Modified for BT.
                   AND ooh.orig_sys_document_ref = '99' || p_seller_hdr_id
                   AND ool.header_id = ooh.header_id
                   AND ool.line_category_code = 'ORDER'
                   /* -- 1.0 : START : Commented for BT.
                   AND msik.concatenated_segments = p_sku
                   AND msik.organization_id = ool.ship_from_org_id
                   AND ool.inventory_item_id = msik.inventory_item_id
                   */
                   -- 1.0 : END : Commented for BT.
                   -- 1.0 : START : Modified for BT.
                   AND msi.segment1 = p_sku
                   AND msi.organization_id = ool.ship_from_org_id
                   AND msi.inventory_item_id = ool.inventory_item_id
                   -- 1.0 : END : Modified for BT.
                   AND oolr.reference_line_id = ool.line_id
                   AND oolr.line_category_code = 'RETURN'
                   AND oohr.header_id = oolr.header_id;

        CURSOR c_cust_trx_id (c_order_number    IN NUMBER,
                              c_order_line_id   IN NUMBER)
        IS
            SELECT customer_trx_id
              FROM ra_customer_trx_lines_all rctl
             WHERE     rctl.interface_line_context = 'ORDER ENTRY'
                   AND rctl.interface_line_attribute1 =
                       TO_CHAR (c_order_number)
                   AND rctl.interface_line_attribute6 =
                       TO_CHAR (c_order_line_id);

        l_matching_order     NUMBER;
        l_matching_line_id   NUMBER;
        l_matching_trx_id    NUMBER;
    BEGIN
        x_rtn_status    := fnd_api.G_RET_STS_SUCCESS;
        x_rtn_message   := NULL;

        FOR c_ln IN c_lines
        LOOP
            BEGIN
                IF UPPER (c_ln.transaction_type) = 'SETTLEMENT'
                THEN
                    -- Match Settlement lines
                    OPEN c_oe_line (c_ln.seller_order_id, c_ln.sku);

                    FETCH c_oe_line INTO l_matching_order, l_matching_line_id;

                    IF c_oe_line%FOUND
                    THEN
                        CLOSE c_oe_line;

                        OPEN c_cust_trx_id (l_matching_order,
                                            l_matching_line_id);

                        FETCH c_cust_trx_id INTO l_matching_trx_id;

                        IF c_cust_trx_id%FOUND
                        THEN
                            CLOSE c_cust_trx_id;

                            UPDATE xxdoec_ca_stlmnt_lines
                               SET order_line_id = l_matching_line_id, customer_trx_id = l_matching_trx_id
                             WHERE CURRENT OF c_lines;
                        ELSE
                            CLOSE c_cust_trx_id;

                            UPDATE xxdoec_ca_stlmnt_lines
                               SET interface_status = 'E', error_message = 'Unable to Match the Order line ' || l_matching_line_id || ' to an Invoice'
                             WHERE CURRENT OF c_lines;

                            x_rtn_status   := fnd_api.G_RET_STS_ERROR;
                        END IF;
                    ELSE
                        CLOSE c_oe_line;

                        UPDATE xxdoec_ca_stlmnt_lines
                           SET interface_status = 'E', error_message = 'Unable to Match to Order line and Invoice'
                         WHERE CURRENT OF c_lines;

                        x_rtn_status   := fnd_api.G_RET_STS_ERROR;
                    END IF;
                ELSIF UPPER (c_ln.transaction_type) = 'ADJUSTMENT'
                THEN
                    -- Match Adjustment lines
                    OPEN c_rtn_line (c_ln.seller_order_id, c_ln.sku);

                    FETCH c_rtn_line INTO l_matching_order, l_matching_line_id;

                    IF c_rtn_line%FOUND
                    THEN
                        CLOSE c_rtn_line;

                        OPEN c_cust_trx_id (l_matching_order,
                                            l_matching_line_id);

                        FETCH c_cust_trx_id INTO l_matching_trx_id;

                        IF c_cust_trx_id%FOUND
                        THEN
                            CLOSE c_cust_trx_id;

                            UPDATE xxdoec_ca_stlmnt_lines
                               SET order_line_id = l_matching_line_id, customer_trx_id = l_matching_trx_id
                             WHERE CURRENT OF c_lines;
                        ELSE
                            CLOSE c_cust_trx_id;

                            UPDATE xxdoec_ca_stlmnt_lines
                               SET interface_status = 'E', error_message = 'Unable to Match the Order line ' || l_matching_line_id || ' to a Credit Memo'
                             WHERE CURRENT OF c_lines;

                            x_rtn_status   := fnd_api.G_RET_STS_ERROR;
                        END IF;
                    ELSE
                        CLOSE c_rtn_line;

                        UPDATE xxdoec_ca_stlmnt_lines
                           SET interface_status = 'E', error_message = 'Unable to Match to Order line and Credit Memo'
                         WHERE CURRENT OF c_lines;

                        x_rtn_status   := fnd_api.G_RET_STS_ERROR;
                    END IF;
                ELSE
                    UPDATE xxdoec_ca_stlmnt_lines
                       SET interface_status = 'E', error_message = 'Invalid Transaction Type, should be Settlement/Adjustment'
                     WHERE CURRENT OF c_lines;

                    x_rtn_status   := fnd_api.G_RET_STS_ERROR;
                END IF;                              -- transaction type check
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_rtn_status    := fnd_api.G_RET_STS_UNEXP_ERROR;
                    x_rtn_message   := 'Unexpected Error occured ' || SQLERRM;
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status    := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_rtn_message   := 'Unexpected Error occured ' || SQLERRM;
    END match_lines;

    --
    PROCEDURE create_cash_receipts (p_stlmnt_hdr_id IN NUMBER, p_gl_date IN DATE, x_rtn_status OUT VARCHAR2
                                    , x_rtn_message OUT VARCHAR2)
    IS
        CURSOR c_stlmnt_header IS
            SELECT deposit_date, receipts_batch_id, total_amount,
                   currency_code, website_id, settlement_id
              FROM xxdoec_ca_stlmnt_headers
             WHERE stlmnt_header_id = p_stlmnt_hdr_id;

        CURSOR c_stlmnt_totals IS
            SELECT SUM (NVL (csl.principal_amount, 0) + NVL (csl.commission_amount, 0) + NVL (csl.freight_amount, 0) + NVL (csl.tax_amount, 0) + NVL (csl.promo_amount, 0)) control_amt, COUNT (DISTINCT customer_trx_id) control_count
              FROM xxdoec_ca_stlmnt_lines csl
             WHERE     csl.stlmnt_header_id = p_stlmnt_hdr_id
                   AND UPPER (csl.transaction_type) = 'SETTLEMENT';

        CURSOR c_cb_params (c_website_id IN VARCHAR2)
        IS
            SELECT cbp.ar_batch_source_id, cbp.ar_bank_branch_id, cbp.ar_bank_account_id,
                   cbp.ar_batch_type, cbp.ar_receipt_class_id, cbp.ar_receipt_method_id,
                   cbp.company_name, cbp.website_id
              FROM xxdoec_country_brand_params cbp
             WHERE cbp.website_id = c_website_id;

        CURSOR c_receipt_method (c_receipt_class_id   IN NUMBER,
                                 c_web_site_id        IN VARCHAR2)
        IS
            SELECT arm.receipt_method_id, bau.bank_account_id, cba.bank_branch_id
              FROM ar_receipt_methods arm, ar_receipt_method_accounts_all arma, ce_bank_acct_uses_all bau,
                   ce_bank_accounts cba
             WHERE     arm.receipt_class_id = c_receipt_class_id
                   AND arm.attribute2 = 'CA'                -- Channel Advisor
                   AND NVL (arm.attribute1, c_web_site_id) = c_web_site_id
                   AND SYSDATE BETWEEN NVL (arm.START_DATE, SYSDATE)
                                   AND NVL (arm.END_DATE, SYSDATE)
                   AND arma.receipt_method_id = arm.receipt_method_id
                   AND bau.bank_acct_use_id = arma.remit_bank_acct_use_id
                   AND cba.bank_account_id = bau.bank_account_id
                   AND cba.account_classification = 'INTERNAL';

        CURSOR c_stlmnt_invoices IS
              SELECT csl.stlmnt_header_id, csl.settlement_id, csl.seller_order_id,
                     csl.customer_trx_id, hca.account_number customer_number, SUM (NVL (csl.principal_amount, 0) + NVL (csl.commission_amount, 0) + NVL (csl.freight_amount, 0) + NVL (csl.tax_amount, 0) + NVL (csl.promo_amount, 0)) payment_amt,
                     SUM (NVL (csl.commission_amount, 0)) commission_amt
                FROM xxdoec_ca_stlmnt_lines csl, oe_order_lines_all ool, hz_cust_accounts hca
               WHERE     csl.stlmnt_header_id = p_stlmnt_hdr_id
                     AND csl.cash_receipt_id IS NULL
                     AND UPPER (csl.transaction_type) = 'SETTLEMENT'
                     AND ool.line_id = csl.order_line_id
                     AND hca.cust_Account_id = ool.sold_to_org_id
            GROUP BY csl.stlmnt_header_id, csl.settlement_id, csl.seller_order_id,
                     csl.customer_trx_id, hca.account_number;

        CURSOR c_inv_balance (c_inv_trx_id IN NUMBER)
        IS
            SELECT SUM (ABS (amount_due_remaining))
              FROM apps.ar_payment_schedules aps
             WHERE customer_trx_id = c_inv_trx_id;

        CURSOR c_adj_activity (c_invoice_id IN NUMBER)
        IS
            SELECT rta.name adj_activity, rctt.name cust_trx_type
              FROM ar_receivables_trx rta, ra_customer_trx rct, ra_cust_trx_types rctt
             WHERE     rct.customer_trx_id = c_invoice_id
                   AND rctt.cust_trx_type_id = rct.cust_trx_type_id
                   AND rctt.org_id = rct.org_id
                   AND rta.receivables_trx_id = TO_NUMBER (rctt.attribute2)
                   AND rta.org_id = rctt.org_id
                   AND SYSDATE BETWEEN NVL (rta.START_DATE_ACTIVE, SYSDATE)
                                   AND NVL (rta.END_DATE_ACTIVE, SYSDATE);

        l_inv_balance         NUMBER;
        cb_params_rec         c_cb_params%ROWTYPE;
        l_stlmnt_hdr_rec      c_stlmnt_header%ROWTYPE;
        l_control_amount      NUMBER;
        l_control_count       NUMBER;
        l_receipt_method_id   NUMBER;
        l_bank_account_id     NUMBER;
        l_bank_branch_id      NUMBER;
        l_batch_id            NUMBER;
        l_batch_name          VARCHAR2 (120);
        l_receipt_number      NUMBER;
        l_cash_receipt_id     NUMBER;
        l_adj_activity        VARCHAR2 (120);
        l_cust_trx_type       VARCHAR2 (120);
        l_adj_id              NUMBER;
        l_adj_number          NUMBER;
        l_rtn_status          VARCHAR2 (1);
        l_pmt_status          VARCHAR2 (1);
        l_error_msg           VARCHAR2 (2000);
        ex_mis_adj_name       EXCEPTION;
    BEGIN
        x_rtn_status   := fnd_api.G_RET_STS_SUCCESS;

        OPEN c_stlmnt_header;

        FETCH c_stlmnt_header INTO l_stlmnt_hdr_rec;

        CLOSE c_stlmnt_header;

        IF l_stlmnt_hdr_rec.receipts_batch_id IS NOT NULL
        THEN
            l_batch_id   := l_stlmnt_hdr_rec.receipts_batch_id;
        ELSE
            -- create Receipt Batch
            cb_params_rec   := NULL;

            OPEN c_cb_params (l_stlmnt_hdr_rec.website_id);

            FETCH c_cb_params INTO cb_params_rec;

            CLOSE c_cb_params;

            IF cb_params_rec.website_id IS NULL
            THEN
                msg (
                    'Could not find the Country Brand Parameters record to get default receipt values',
                    100);
                x_rtn_status   := fnd_api.G_RET_STS_ERROR;
            ELSE
                OPEN c_receipt_method (cb_params_rec.ar_receipt_class_id,
                                       cb_params_rec.website_id);

                FETCH c_receipt_method INTO l_receipt_method_id, l_bank_account_id, l_bank_branch_id;

                CLOSE c_receipt_method;

                --
                OPEN c_stlmnt_totals;

                FETCH c_stlmnt_totals INTO l_control_amount, l_control_count;

                CLOSE c_stlmnt_totals;

                --
                do_ar_utils.create_receipt_batch_trans (
                    p_company            => cb_params_rec.company_name,
                    p_batch_source_id    => cb_params_rec.ar_batch_source_id,
                    p_bank_branch_id     =>
                        NVL (l_bank_branch_id,
                             cb_params_rec.ar_bank_branch_id),
                    p_batch_type         => cb_params_rec.ar_batch_type,
                    p_currency_code      => l_stlmnt_hdr_rec.currency_code,
                    p_bank_account_id    =>
                        NVL (l_bank_account_id,
                             cb_params_rec.ar_bank_account_id),
                    p_batch_date         => l_stlmnt_hdr_rec.deposit_date,
                    p_receipt_class_id   => cb_params_rec.ar_receipt_class_id,
                    p_control_count      => l_control_count,
                    p_gl_date            => p_gl_date,
                    p_receipt_method_id   =>
                        NVL (l_receipt_method_id,
                             cb_params_rec.ar_receipt_method_id),
                    p_control_amount     => l_control_amount,
                    p_deposit_date       => l_stlmnt_hdr_rec.deposit_date,
                    p_comments           =>
                           'Settlement# '
                        || l_stlmnt_hdr_rec.settlement_id
                        || ' Web Site ID: '
                        || l_stlmnt_hdr_rec.website_id,
                    p_auto_commit        => 'N',
                    x_batch_id           => l_batch_id,
                    x_batch_name         => l_batch_name,
                    x_error_msg          => l_error_msg);

                IF NVL (l_batch_id, -1) <> -1
                THEN
                    update_stlmnt_header (p_stlmnt_hdr_id => p_stlmnt_hdr_id, p_receipts_batch_id => l_batch_id, p_interface_status => fnd_api.G_RET_STS_SUCCESS
                                          , p_error_message => NULL);
                    COMMIT;
                ELSE
                    update_stlmnt_header (p_stlmnt_hdr_id => p_stlmnt_hdr_id, p_receipts_batch_id => NULL, p_interface_status => fnd_api.G_RET_STS_ERROR
                                          , p_error_message => l_error_msg);
                    msg (
                           'Unable to create Cash Receipt Batch for stlmnt Hdr ID: '
                        || p_stlmnt_hdr_id,
                        100);
                    msg ('Error Message: ' || l_error_msg, 100);
                    x_rtn_status   := fnd_api.G_RET_STS_ERROR;
                END IF;
            END IF;                                   -- cb params found check
        END IF;                            -- receipts batch ID not null check

        --
        IF NVL (l_batch_id, -1) <> -1
        THEN
            l_rtn_status   := fnd_api.G_RET_STS_SUCCESS;

            FOR c_stlmnt IN c_stlmnt_invoices
            LOOP
                BEGIN
                    l_pmt_status   := fnd_api.G_RET_STS_SUCCESS;
                    l_error_msg    := NULL;

                    OPEN c_inv_balance (c_stlmnt.customer_trx_id);

                    FETCH c_inv_balance INTO l_inv_balance;

                    CLOSE c_inv_balance;

                    -- Create commission Adjustment
                    IF     l_inv_balance >= ABS (c_stlmnt.commission_amt)
                       AND ABS (c_stlmnt.commission_amt) > 0
                    THEN
                        -- derive adjustment activity
                        OPEN c_adj_activity (c_stlmnt.customer_trx_id);

                        FETCH c_adj_activity INTO l_adj_activity, l_cust_trx_type;

                        CLOSE c_adj_activity;

                        --
                        IF l_adj_activity IS NULL
                        THEN
                            msg (
                                   'Adjustment Activity Name Setup for Customer Trx Type '
                                || l_cust_trx_type
                                || ' is missing - Unable to create Adjustment',
                                100);
                            RAISE ex_mis_adj_name;
                        END IF;

                        -- Create Adjustment
                        do_ar_utils.create_adjustment_trans (
                            p_customer_trx_id   => c_stlmnt.customer_trx_id,
                            p_activity_name     => l_adj_activity,
                            p_type              => 'LINE',
                            p_amount            => c_stlmnt.commission_amt,
                            p_reason_code       => 'CB-CRME',
                            p_gl_date           => p_gl_date,
                            p_adj_date          =>
                                l_stlmnt_hdr_rec.deposit_date,
                            p_comments          =>
                                   'Order# '
                                || c_stlmnt.seller_order_id
                                || 'Invoice ID: '
                                || c_stlmnt.customer_trx_id,
                            p_auto_commit       => 'N',
                            x_adj_id            => l_adj_id,
                            x_adj_number        => l_adj_number,
                            x_error_msg         => l_error_msg);

                        IF l_error_msg IS NOT NULL
                        THEN
                            msg (
                                   'Unable to create Adjustment for Invoice ID: '
                                || c_stlmnt.customer_trx_id,
                                100);
                            msg ('Error Message: ' || l_error_msg, 100);
                            l_pmt_status   := FND_API.G_RET_STS_ERROR;
                        ELSE
                            l_inv_balance   :=
                                l_inv_balance - ABS (c_stlmnt.commission_amt);
                            msg (
                                   'Successfully created Adjustment#: '
                                || l_adj_number
                                || ' for Invoice ID: '
                                || c_stlmnt.customer_trx_id,
                                100);
                        END IF;                          -- adjustment success
                    ELSE
                        l_error_msg    :=
                               'Commission Amount : '
                            || ABS (c_stlmnt.commission_amt)
                            || ' is more than the Invoice Balance: '
                            || l_inv_balance;
                        msg (l_error_msg, 100);
                        l_pmt_status   := fnd_api.G_RET_STS_ERROR;
                    END IF;

                    -- Create Cash Receipts
                    IF l_pmt_status = FND_API.G_RET_STS_SUCCESS
                    THEN
                        IF l_inv_balance >= c_stlmnt.payment_amt
                        THEN
                            SELECT xxdoec_cash_receipts_s.NEXTVAL
                              INTO l_receipt_number
                              FROM DUAL;

                            do_ar_utils.create_receipt_trans (
                                p_batch_id          => l_batch_id,
                                p_receipt_number    => l_receipt_number,
                                p_receipt_amt       => c_stlmnt.payment_amt,
                                p_transaction_num   =>
                                    c_stlmnt.seller_order_id,
                                p_payment_server_order_num   =>
                                    c_stlmnt.seller_order_id,
                                p_customer_number   =>
                                    c_stlmnt.customer_number,
                                p_customer_name     => NULL,
                                p_comments          =>
                                       'Order# '
                                    || c_stlmnt.seller_order_id
                                    || 'Invoice ID: '
                                    || c_stlmnt.customer_trx_id,
                                p_currency_code     =>
                                    l_stlmnt_hdr_rec.currency_code,
                                p_location          => NULL,
                                p_auto_commit       => 'N',
                                x_cash_receipt_id   => l_cash_receipt_id,
                                x_error_msg         => l_error_msg);

                            IF NVL (l_cash_receipt_id, -200) = -200
                            THEN
                                msg (
                                       'Unable to create Cash Receipt for the amount '
                                    || c_stlmnt.payment_amt,
                                    100);
                                msg ('Error Message: ' || l_error_msg, 100);
                                l_pmt_status   := fnd_api.G_RET_STS_ERROR;
                            ELSE
                                msg (
                                       'Successfully created Cash Receipt ID: '
                                    || l_cash_receipt_id
                                    || ' for the amount '
                                    || c_stlmnt.payment_amt,
                                    100);
                                l_error_msg   := NULL;
                                -- apply cash receipt
                                do_ar_utils.apply_transaction_trans (
                                    p_cash_receipt_id   => l_cash_receipt_id,
                                    p_customer_trx_id   =>
                                        c_stlmnt.customer_trx_id,
                                    p_trx_number        => NULL,
                                    p_applied_amt       =>
                                        c_stlmnt.payment_amt,
                                    p_discount          => NULL,
                                    p_auto_commit       => 'N',
                                    x_error_msg         => l_error_msg);

                                IF l_error_msg IS NULL
                                THEN
                                    msg (
                                           'Successfully Applied Amount: '
                                        || c_stlmnt.payment_amt
                                        || ' to Invoice ID: '
                                        || c_stlmnt.customer_trx_id,
                                        100);
                                ELSE
                                    msg (
                                           'Unable to Apply Cash Receipt to Invoice ID: '
                                        || c_stlmnt.customer_trx_id,
                                        100);
                                    msg ('Error Message: ' || l_error_msg,
                                         100);
                                    l_pmt_status   := fnd_api.G_RET_STS_ERROR;
                                END IF;              -- Cash Receipt App check
                            END IF;             -- Cash Receipt creation check
                        ELSE
                            l_error_msg    :=
                                   'Payment Amount : '
                                || c_stlmnt.payment_amt
                                || ' is more than the Invoice Balance: '
                                || l_inv_balance;
                            msg (l_error_msg, 100);
                            l_pmt_status   := fnd_api.G_RET_STS_ERROR;
                        END IF;                       -- Invoice balance check
                    END IF;

                    --
                    IF l_pmt_status = fnd_api.G_RET_STS_SUCCESS
                    THEN
                        -- Update order lines
                        UPDATE oe_order_lines_all ool
                           SET ool.attribute20 = 'CCR', ool.attribute19 = 'APPLIED', ool.attribute17 = l_pmt_status
                         WHERE line_id IN
                                   (SELECT csl.order_line_id
                                      FROM xxdoec_ca_stlmnt_lines csl
                                     WHERE     csl.customer_trx_id =
                                               c_stlmnt.customer_trx_id
                                           AND csl.stlmnt_header_id =
                                               c_stlmnt.stlmnt_header_id);

                        COMMIT;
                        -- update stlmnt lines status success
                        update_stlmnt_lines (
                            p_stlmnt_hdr_id      => c_stlmnt.stlmnt_header_id,
                            p_cust_trx_id        => c_stlmnt.customer_trx_id,
                            p_cash_receipt_id    => l_cash_receipt_id,
                            p_interface_status   => l_pmt_status,
                            p_error_message      => l_error_msg);
                    ELSE
                        ROLLBACK;
                        -- update stlmnt lines status error
                        update_stlmnt_lines (
                            p_stlmnt_hdr_id      => c_stlmnt.stlmnt_header_id,
                            p_cust_trx_id        => c_stlmnt.customer_trx_id,
                            p_cash_receipt_id    => NULL,
                            p_interface_status   => l_pmt_status,
                            p_error_message      => l_error_msg);
                        l_rtn_status   := fnd_api.G_RET_STS_ERROR;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        update_stlmnt_lines (
                            p_stlmnt_hdr_id      => c_stlmnt.stlmnt_header_id,
                            p_cust_trx_id        => c_stlmnt.customer_trx_id,
                            p_cash_receipt_id    => NULL,
                            p_interface_status   =>
                                fnd_api.G_RET_STS_UNEXP_ERROR,
                            p_error_message      => SQLERRM);
                        l_rtn_status   := fnd_api.G_RET_STS_UNEXP_ERROR;
                        ROLLBACK;
                END;
            END LOOP;

            -- update stlmnt header if any payment failures
            IF l_rtn_status <> fnd_api.G_RET_STS_SUCCESS
            THEN
                msg (
                       'Some of the stlmnt lines failed to create/apply cash receipt of stlmnt Hdr ID: '
                    || p_stlmnt_hdr_id,
                    100);
                x_rtn_status   := l_rtn_status;
                update_stlmnt_header (
                    p_stlmnt_hdr_id       => p_stlmnt_hdr_id,
                    p_receipts_batch_id   => l_batch_id,
                    p_interface_status    => 'W',
                    p_error_message       =>
                        'Some of the stlmnt lines failed to create/apply cash receipt');
            END IF;
        END IF;                                     --  Receipt batch ID check
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status    := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_rtn_message   := 'Unexpected Error occured ' || SQLERRM;
    END create_cash_receipts;

    --
    PROCEDURE create_cm_adjustments (p_stlmnt_hdr_id IN NUMBER, p_gl_date IN DATE, x_rtn_status OUT VARCHAR2
                                     , x_rtn_message OUT VARCHAR2)
    IS
        CURSOR c_adj_cms IS
              SELECT csl.stlmnt_header_id, csh.deposit_date, csl.settlement_id,
                     csl.seller_order_id, csl.customer_trx_id, hca.account_number customer_number,
                     SUM (NVL (csl.principal_amount, 0) + NVL (csl.commission_amount, 0) + NVL (csl.freight_amount, 0) + NVL (csl.tax_amount, 0) + NVL (csl.promo_amount, 0)) adjust_amt, SUM (NVL (csl.commission_amount, 0)) commission_amt
                FROM xxdoec_ca_stlmnt_lines csl, xxdoec_ca_stlmnt_headers csh, oe_order_lines_all ool,
                     hz_cust_accounts hca
               WHERE     csh.stlmnt_header_id = p_stlmnt_hdr_id
                     AND csl.stlmnt_header_id = csh.stlmnt_header_id
                     AND csl.cash_receipt_id IS NULL
                     AND UPPER (csl.transaction_type) = 'ADJUSTMENT'
                     AND ool.line_id = csl.order_line_id
                     AND hca.cust_Account_id = ool.sold_to_org_id
            GROUP BY csl.stlmnt_header_id, csh.deposit_date, csl.settlement_id,
                     csl.seller_order_id, csl.customer_trx_id, hca.account_number;

        CURSOR c_cm_balance (c_cm_trx_id IN NUMBER)
        IS
            SELECT ABS (SUM (aps.amount_due_remaining)) cm_balance, ABS (SUM (aps.amount_line_items_remaining)) cm_line_balance, ABS (SUM (aps.tax_remaining)) cm_tax_balance
              FROM ar_payment_schedules aps
             WHERE customer_trx_id = c_cm_trx_id;

        CURSOR c_comm_adj_activity (c_cust_trx_id IN NUMBER)
        IS
            SELECT rta.name adj_activity, rctt.name cust_trx_type
              FROM ar_receivables_trx rta, ra_customer_trx rct, ra_cust_trx_types rctt
             WHERE     rct.customer_trx_id = c_cust_trx_id
                   AND rctt.cust_trx_type_id = rct.cust_trx_type_id
                   AND rctt.org_id = rct.org_id
                   AND rta.receivables_trx_id = TO_NUMBER (rctt.attribute2)
                   AND rta.org_id = rctt.org_id
                   AND SYSDATE BETWEEN NVL (rta.START_DATE_ACTIVE, SYSDATE)
                                   AND NVL (rta.END_DATE_ACTIVE, SYSDATE);

        CURSOR c_adj_activity (c_pmt_type IN VARCHAR2)
        IS
            SELECT NAME
              FROM ar_receivables_trx
             WHERE     attribute2 = c_pmt_type
                   AND SYSDATE BETWEEN NVL (START_DATE_ACTIVE, SYSDATE)
                                   AND NVL (END_DATE_ACTIVE, SYSDATE);

        l_cm_balance        NUMBER;
        l_cm_line_balance   NUMBER;
        l_cm_tax_balance    NUMBER;
        l_pmt_type          VARCHAR2 (10) := 'CA';
        l_adj_activity      VARCHAR2 (120);
        l_cust_trx_type     VARCHAR2 (120);
        l_adj_amt           NUMBER;
        l_adj_amt_balance   NUMBER;
        l_adj_type          VARCHAR2 (40);
        l_adj_id            NUMBER;
        l_adj_number        NUMBER;
        l_adj_status        VARCHAR2 (1);
        l_adj_counter       NUMBER;
        l_rtn_status        VARCHAR2 (1);
        l_err_msg           VARCHAR2 (2000);
    BEGIN
        x_rtn_status   := fnd_api.G_RET_STS_SUCCESS;

        FOR c_adj IN c_adj_cms
        LOOP
            BEGIN
                l_adj_status        := fnd_api.G_RET_STS_SUCCESS;
                l_err_msg           := NULL;
                l_adj_amt_balance   := ABS (c_adj.adjust_amt);

                OPEN c_cm_balance (c_adj.customer_trx_id);

                FETCH c_cm_balance INTO l_cm_balance, l_cm_line_balance, l_cm_tax_balance;

                CLOSE c_cm_balance;

                -- Create commission Adjustment
                IF     l_cm_balance >= c_adj.commission_amt
                   AND c_adj.commission_amt > 0
                THEN
                    -- derive adjustment activity
                    OPEN c_comm_adj_activity (c_adj.customer_trx_id);

                    FETCH c_comm_adj_activity INTO l_adj_activity, l_cust_trx_type;

                    CLOSE c_comm_adj_activity;

                    IF l_adj_activity IS NULL
                    THEN
                        l_err_msg      :=
                               'Adjustment Activity Name Setup for Customer Trx Type '
                            || l_cust_trx_type
                            || ' is missing - Unable to create Adjustment';
                        msg (l_err_msg, 100);
                        l_adj_status   := FND_API.G_RET_STS_ERROR;
                    ELSE
                        -- Create Adjustment
                        do_ar_utils.create_adjustment_trans (
                            p_customer_trx_id   => c_adj.customer_trx_id,
                            p_activity_name     => l_adj_activity,
                            p_type              => 'LINE',
                            p_amount            => c_adj.commission_amt,
                            p_reason_code       => 'CB-CRME',
                            p_gl_date           => p_gl_date,
                            p_adj_date          => c_adj.deposit_date,
                            p_comments          =>
                                   'Order# '
                                || c_adj.seller_order_id
                                || 'Credit Memo ID: '
                                || c_adj.customer_trx_id,
                            p_auto_commit       => 'N',
                            x_adj_id            => l_adj_id,
                            x_adj_number        => l_adj_number,
                            x_error_msg         => l_err_msg);

                        IF l_err_msg IS NOT NULL
                        THEN
                            msg (
                                   'Unable to create Adjustment for Credit Memo ID: '
                                || c_adj.customer_trx_id,
                                100);
                            msg ('Error Message: ' || l_err_msg, 100);
                            l_adj_status   := FND_API.G_RET_STS_ERROR;
                        ELSE
                            l_cm_balance   :=
                                l_cm_balance - c_adj.commission_amt;
                            msg (
                                   'Successfully created Adjustment#: '
                                || l_adj_number
                                || ' for Credit Memo ID: '
                                || c_adj.customer_trx_id,
                                100);
                        END IF;                -- Comission adjustment success
                    END IF;                     -- adj activity not null check
                END IF;                             -- Commission amount check

                -- Create Refund Adjustment
                IF l_adj_status = fnd_api.G_RET_STS_SUCCESS
                THEN
                    IF l_cm_balance >= l_adj_amt_balance
                    THEN
                        OPEN c_adj_activity (l_pmt_type);

                        FETCH c_adj_activity INTO l_adj_activity;

                        CLOSE c_adj_activity;

                        IF l_adj_activity IS NULL
                        THEN
                            l_err_msg      :=
                                   'Adjustment Activity Name Setup for Payment Type '
                                || l_pmt_type
                                || ' is missing - Unable to create Adjustment';
                            msg (l_err_msg, 100);
                            l_adj_status   := FND_API.G_RET_STS_ERROR;
                        ELSE
                            --
                            l_adj_counter   := 0;

                            WHILE     l_cm_balance > 0
                                  AND l_adj_amt_balance > 0
                                  AND l_Adj_counter < 2
                            LOOP
                                l_adj_counter   := l_adj_counter + 1;

                                IF l_cm_balance = l_adj_amt_balance
                                THEN
                                    l_adj_type   := 'INVOICE';
                                    l_adj_amt    :=
                                        LEAST (l_cm_balance,
                                               l_adj_amt_balance);
                                ELSIF l_cm_tax_balance > 0
                                THEN
                                    l_adj_type   := 'TAX';
                                    l_adj_amt    :=
                                        LEAST (l_cm_tax_balance,
                                               l_adj_amt_balance);
                                ELSIF l_cm_line_balance > 0
                                THEN
                                    l_adj_type   := 'LINE';
                                    l_adj_amt    :=
                                        LEAST (l_cm_line_balance,
                                               l_adj_amt_balance);
                                END IF;

                                -- Create Adjustment
                                do_ar_utils.create_adjustment_trans (
                                    p_customer_trx_id   =>
                                        c_adj.customer_trx_id,
                                    p_activity_name   => l_adj_activity,
                                    p_type            => l_adj_type,
                                    p_amount          => l_adj_amt,
                                    p_reason_code     => 'CB-CRME',
                                    p_gl_date         => p_gl_date,
                                    p_adj_date        => c_adj.deposit_date,
                                    p_comments        =>
                                           'Order# '
                                        || c_adj.seller_order_id
                                        || 'Credit Memo ID: '
                                        || c_adj.customer_trx_id,
                                    p_auto_commit     => 'N',
                                    x_adj_id          => l_adj_id,
                                    x_adj_number      => l_adj_number,
                                    x_error_msg       => l_err_msg);

                                IF l_err_msg IS NOT NULL
                                THEN
                                    msg (
                                           'Unable to create Adjustment for Credit Memo ID: '
                                        || c_adj.customer_trx_id,
                                        100);
                                    msg ('Error Message: ' || l_err_msg, 100);
                                    l_adj_status   := FND_API.G_RET_STS_ERROR;
                                    EXIT;                   -- exit while loop
                                ELSE
                                    l_cm_balance   :=
                                        l_cm_balance - l_adj_amt;
                                    l_adj_amt_balance   :=
                                        l_adj_amt_balance - l_adj_amt;

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
                                        || ' for Credit Memo ID: '
                                        || c_adj.customer_trx_id,
                                        100);
                                END IF;                  -- adjustment success
                            END LOOP;                            -- while loop
                        END IF;                 -- adj activity not null check
                    ELSE
                        l_err_msg      :=
                               'Adjustment Amount : '
                            || c_adj.adjust_amt
                            || ' is more than the CM Balance: '
                            || l_cm_balance;
                        msg (l_err_msg, 100);
                        l_adj_status   := fnd_api.G_RET_STS_ERROR;
                    END IF;                                -- CM balance check
                END IF;                        -- Comm adjustment status check

                --
                IF l_adj_status = fnd_api.G_RET_STS_SUCCESS
                THEN
                    -- Update order lines
                    UPDATE oe_order_lines_all ool
                       SET ool.attribute20 = 'CMA', ool.attribute19 = 'ADJUSTED', ool.attribute17 = l_adj_status
                     WHERE line_id IN
                               (SELECT csl.order_line_id
                                  FROM xxdoec_ca_stlmnt_lines csl
                                 WHERE     csl.customer_trx_id =
                                           c_adj.customer_trx_id
                                       AND csl.stlmnt_header_id =
                                           c_adj.stlmnt_header_id);

                    COMMIT;
                    -- update stlmnt lines status success
                    update_stlmnt_lines (
                        p_stlmnt_hdr_id      => c_adj.stlmnt_header_id,
                        p_cust_trx_id        => c_adj.customer_trx_id,
                        p_cash_receipt_id    => l_adj_id,
                        p_interface_status   => l_adj_status,
                        p_error_message      => l_err_msg);
                ELSE
                    ROLLBACK;
                    -- update stlmnt lines status error
                    update_stlmnt_lines (
                        p_stlmnt_hdr_id      => c_adj.stlmnt_header_id,
                        p_cust_trx_id        => c_adj.customer_trx_id,
                        p_cash_receipt_id    => NULL,
                        p_interface_status   => l_adj_status,
                        p_error_message      => l_err_msg);
                    l_rtn_status   := fnd_api.G_RET_STS_ERROR;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_rtn_status    := fnd_api.G_RET_STS_UNEXP_ERROR;
                    x_rtn_message   := 'Unexpected Error occured ' || SQLERRM;
                    ROLLBACK;
            END;
        END LOOP;

        -- update stlmnt header if any adjustment failures
        IF l_rtn_status <> fnd_api.G_RET_STS_SUCCESS
        THEN
            msg (
                   'Some of the Adjustment lines failed to adjust of stlmnt Hdr ID: '
                || p_stlmnt_hdr_id,
                100);
            x_rtn_status   := l_rtn_status;
            update_stlmnt_header (
                p_stlmnt_hdr_id       => p_stlmnt_hdr_id,
                p_receipts_batch_id   => NULL,
                p_interface_status    => 'W',
                p_error_message       =>
                    'Some of the adjustment lines failed to adjust');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status    := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_rtn_message   := 'Unexpected Error occured ' || SQLERRM;
    END create_cm_adjustments;

    --
    PROCEDURE apply_cm_to_invoice (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER)
    IS
        CURSOR c_rtn_lines IS
              SELECT ooh.order_number, rct.customer_trx_id, SUM (ABS (aps.amount_due_remaining)) cm_balance,
                     ooh.header_id
                FROM oe_order_headers ooh, oe_transaction_types ott, ra_customer_trx rct,
                     ra_cust_trx_types rctt, ar_payment_schedules aps, oe_order_sources oos -- 1.0 : Added for BT.
               --    WHERE ooh.order_source_id = 1044     -- 1.0 : Commented for BT.
               WHERE     ooh.order_source_id = oos.order_source_id -- 1.0 : Modified for BT.
                     AND UPPER (oos.name) = 'FLAGSTAFF' -- 1.0 : Modified for BT.
                     AND ooh.orig_sys_document_ref LIKE '99%'
                     AND ott.transaction_type_id = ooh.order_type_id
                     AND ott.attribute13 = 'CE'
                     AND ooh.header_id = NVL (p_header_id, ooh.header_id)
                     AND rct.interface_header_context = 'ORDER ENTRY'
                     AND rct.interface_header_attribute1 =
                         TO_CHAR (ooh.order_number)
                     AND rctt.cust_trx_type_id = rct.cust_trx_type_id
                     AND rctt.TYPE = 'CM'
                     AND aps.customer_trx_id = rct.customer_trx_id
            GROUP BY ooh.order_number, rct.customer_trx_id, ooh.header_id
              HAVING SUM (ABS (aps.amount_due_remaining)) > 0;

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

        l_cm_balance    NUMBER;
        l_apply_amt     NUMBER;
        l_app_status    VARCHAR2 (1);
        l_adj_status    VARCHAR2 (1);
        l_rec_appl_id   NUMBER;
        l_err_msg       VARCHAR2 (2000);
    BEGIN
        l_adj_status   := FND_API.G_RET_STS_SUCCESS;

        FOR c_cma IN c_rtn_lines
        LOOP
            BEGIN
                msg (
                       'Processing Order#: '
                    || c_cma.order_number
                    || ' Credit Memo ID: '
                    || c_cma.customer_trx_id,
                    100);
                l_err_msg      := NULL;
                l_cm_balance   := c_cma.cm_balance;

                -- apply CM to invoice(s) of the same order
                FOR c_inv IN c_order_invoice (c_cma.order_number)
                LOOP
                    l_apply_amt   := LEAST (l_cm_balance, c_inv.inv_balance);
                    do_ar_utils.apply_credit_memo_to_invoice (
                        p_customer_id          => c_inv.bill_to_customer_id,
                        p_bill_to_site_id      => c_inv.bill_to_site_use_id,
                        p_cm_cust_trx_id       => c_cma.customer_trx_id,
                        p_inv_cust_trx_id      => c_inv.customer_trx_id,
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
                            'Unable to apply CM to Invoice ID: ' || c_inv.customer_trx_id,
                            100);
                        msg ('Error Message: ' || l_err_msg, 100);
                        l_adj_status   := FND_API.G_RET_STS_ERROR;
                    ELSE
                        msg (
                               'Successfully applied CM to Invoice ID: '
                            || c_inv.customer_trx_id,
                            100);

                        IF l_apply_amt = c_inv.inv_balance
                        THEN
                            UPDATE oe_order_lines_all ool
                               SET ool.attribute20 = 'CM', ool.attribute19 = 'APPLIED', ool.attribute17 = fnd_api.g_ret_sts_success
                             WHERE     ool.header_id = c_cma.header_id
                                   AND EXISTS
                                           (SELECT 1
                                              FROM ra_customer_trx_lines_all rctl
                                             WHERE     rctl.customer_trx_id =
                                                       c_inv.customer_trx_id
                                                   AND rctl.interface_line_context =
                                                       'ORDER ENTRY'
                                                   AND rctl.interface_line_attribute6 =
                                                       TO_CHAR (ool.line_id));
                        END IF;                           -- Invoice amt check

                        l_cm_balance   := l_cm_balance - l_apply_amt;

                        IF l_cm_balance = 0
                        THEN
                            UPDATE oe_order_lines_all ool
                               SET ool.attribute20 = 'CMA', ool.attribute19 = 'ADJUSTED', ool.attribute17 = fnd_api.g_ret_sts_success
                             WHERE     ool.header_id = c_cma.header_id
                                   AND EXISTS
                                           (SELECT 1
                                              FROM ra_customer_trx_lines_all rctl
                                             WHERE     rctl.customer_trx_id =
                                                       c_cma.customer_trx_id
                                                   AND rctl.interface_line_context =
                                                       'ORDER ENTRY'
                                                   AND rctl.interface_line_attribute6 =
                                                       TO_CHAR (ool.line_id));

                            EXIT;
                        END IF;                       -- cm balance zero check
                    END IF;                           -- api call status check
                END LOOP;                                     -- invoices loop
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_adj_status   := FND_API.G_RET_STS_UNEXP_ERROR;
            END;

            -- commit CM application
            IF l_adj_status <> FND_API.G_RET_STS_SUCCESS
            THEN
                ROLLBACK;
                x_retcode   := 1;
            ELSE
                COMMIT;
            END IF;
        END LOOP;                                                  -- CMs loop
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    := 'Unexpected Error occured ' || SQLERRM;
    END apply_cm_to_invoice;

    --
    PROCEDURE process_settlements (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_settlement_id IN VARCHAR2
                                   , p_website_id IN VARCHAR2)
    IS
        CURSOR c_stlmnt_headers IS
            SELECT stlmnt_header_id, deposit_date
              FROM xxdoec_ca_stlmnt_headers csh
             WHERE     interface_status IN ('N', 'W', 'E')
                   AND settlement_id = NVL (p_settlement_id, settlement_id)
                   AND website_id = NVL (p_website_id, website_id);

        CURSOR c_gl_date (p_deposit_date IN DATE)
        IS
            SELECT p_deposit_date
              FROM apps.gl_period_statuses gps, apps.hr_operating_units hou, apps.fnd_application fapp -- 1.0 : Added for BT.
             -- where gps.application_id = 222     -- 1.0 : Commented for BT.
             WHERE     gps.application_id = fapp.application_id -- 1.0 : Modified for BT.
                   AND fapp.application_short_name = 'AR' -- 1.0 : Modified for BT.
                   AND gps.set_of_books_id = hou.set_of_books_id
                   AND hou.organization_id = fnd_profile.VALUE ('ORG_ID')
                   AND gps.closing_status = 'O'
                   AND p_deposit_date BETWEEN gps.start_date AND gps.end_date;

        CURSOR c_op_gl_date (p_deposit_date IN DATE)
        IS
            SELECT MIN (start_date)
              FROM apps.gl_period_statuses gps, apps.hr_operating_units hou, apps.fnd_application fapp -- 1.0 : Added for BT.
             -- where gps.application_id = 222     -- 1.0 : Commented for BT.
             WHERE     gps.application_id = fapp.application_id -- 1.0 : Modified for BT.
                   AND fapp.application_short_name = 'AR' -- 1.0 : Modified for BT.
                   AND gps.set_of_books_id = hou.set_of_books_id
                   AND hou.organization_id = fnd_profile.VALUE ('ORG_ID')
                   AND gps.closing_status = 'O'
                   AND gps.start_date >= p_deposit_date;

        l_gl_date        DATE;
        l_rtn_status     VARCHAR2 (1);
        l_rtn_message    VARCHAR2 (2000);

        l_gl_date_excp   EXCEPTION;
    BEGIN
        FOR c_hdr IN c_stlmnt_headers
        LOOP
            msg (
                'Started Processing stlmnt Header ID: ' || c_hdr.stlmnt_header_id,
                100);

            BEGIN
                l_gl_date       := NULL;
                l_rtn_status    := NULL;
                l_rtn_message   := NULL;

                --derive GL Date
                OPEN c_gl_date (c_hdr.deposit_date);

                FETCH c_gl_date INTO l_gl_date;

                IF c_gl_date%NOTFOUND
                THEN
                    CLOSE c_gl_date;

                    OPEN c_op_gl_date (c_hdr.deposit_date);

                    FETCH c_op_gl_date INTO l_gl_date;

                    CLOSE c_op_gl_date;

                    IF l_gl_date IS NULL
                    THEN
                        RAISE l_gl_date_excp;
                    END IF;
                ELSE
                    CLOSE c_gl_date;
                END IF;

                --
                validate_header (c_hdr.stlmnt_header_id);

                match_lines (p_stlmnt_hdr_id   => c_hdr.stlmnt_header_id,
                             x_rtn_status      => l_rtn_status,
                             x_rtn_message     => l_rtn_message);

                msg ('Match Stlmnt lines Return Status:' || l_rtn_status);

                IF l_rtn_status <> fnd_api.G_RET_STS_SUCCESS
                THEN
                    x_retcode   := 1;
                    msg (
                           'Match Stlmnt lines Return Message:'
                        || NVL (l_rtn_message,
                                'Failed to match some of the lines'));
                END IF;

                create_cash_receipts (p_stlmnt_hdr_id => c_hdr.stlmnt_header_id, p_gl_date => l_gl_date, x_rtn_status => l_rtn_status
                                      , x_rtn_message => l_rtn_message);

                msg ('Create Cash Receipts Return Status:' || l_rtn_status);

                IF l_rtn_status <> fnd_api.G_RET_STS_SUCCESS
                THEN
                    x_retcode   := 1;
                    msg (
                           'Create Cash Receipts Return Message:'
                        || NVL (
                               l_rtn_message,
                               'Failed to create Cash Receipts for some of the lines'));
                END IF;

                create_cm_adjustments (p_stlmnt_hdr_id => c_hdr.stlmnt_header_id, p_gl_date => l_gl_date, x_rtn_status => l_rtn_status
                                       , x_rtn_message => l_rtn_message);

                msg ('Create CM adjustments Return Status:' || l_rtn_status);

                IF l_rtn_status <> fnd_api.G_RET_STS_SUCCESS
                THEN
                    x_retcode   := 1;
                    msg (
                           'Create CM adjustments Return Message:'
                        || NVL (
                               l_rtn_message,
                               'Failed to create CM adjustments for some of the lines'));
                END IF;
            EXCEPTION
                WHEN l_gl_date_excp
                THEN
                    x_retcode   := 1;
                    msg ('Unable to derive open GL peroid Date', 100);
                WHEN OTHERS
                THEN
                    x_retcode   := 1;
                    msg (
                        'Unexpected Error occured ...Error Msg: ' || SQLERRM,
                        100);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    := 'Unexpected Error occured ' || SQLERRM;
    END process_settlements;
END xxdoec_ca_settlement_pkg;
/
