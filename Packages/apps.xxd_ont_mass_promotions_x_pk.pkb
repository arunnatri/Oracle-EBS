--
-- XXD_ONT_MASS_PROMOTIONS_X_PK  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_MASS_PROMOTIONS_X_PK"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_MASS_PROMOTIONS_X_PK
    * Design       : This package is used for mass reprice and promotion data update
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 13-Apr-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    -- ===============================================================================
    -- This procedure reprices order and update promotion data fields
    -- ===============================================================================
    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN appsro.xxd_ont_mass_promotions_stg_t.org_id%TYPE
                         , p_brand IN appsro.xxd_ont_mass_promotions_stg_t.brand%TYPE, p_threads IN NUMBER, p_run_id IN NUMBER)
    AS
        CURSOR get_orders IS
            SELECT *
              FROM (SELECT xompst.header_id,
                           xompst.org_id,
                           xompst.promotion_code,
                           (SELECT COUNT (1)
                              FROM oe_order_lines_all oola
                             WHERE     oola.header_id = xompst.header_id
                                   AND oola.open_flag = 'Y'
                                   AND oola.calculate_price_flag IN
                                           ('N', 'P')) frozen_lines_count,
                           NTILE (p_threads) OVER (ORDER BY xompst.header_id) run_id
                      FROM appsro.xxd_ont_mass_promotions_stg_t xompst
                     WHERE     xompst.record_status = 'N'
                           AND xompst.brand = p_brand
                           AND xompst.org_id = p_org_id)
             WHERE run_id = p_run_id;

        lc_msg_data                VARCHAR2 (1000);
        lc_error_message           VARCHAR2 (4000);
        lc_return_status           VARCHAR2 (1);
        lc_flag                    VARCHAR2 (1);
        ln_msg_count               NUMBER;
        ln_msg_index_out           NUMBER (10);
        ln_order_count             NUMBER DEFAULT 0;
        ln_success_order_count     NUMBER DEFAULT 0;
        ln_error_order_count       NUMBER DEFAULT 0;
        ln_reset_count             NUMBER DEFAULT 0;
        ln_dummy                   NUMBER DEFAULT 0;
        l_header_rec               oe_order_pub.header_rec_type;
        l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
        l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
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
    BEGIN
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', p_org_id);

        FOR orders_rec IN get_orders
        LOOP
            IF orders_rec.frozen_lines_count = 0
            THEN
                BEGIN
                    FOR I
                        IN (    SELECT ooha.header_id, oola.line_id
                                  FROM oe_order_headers_all ooha, oe_order_lines_all oola
                                 WHERE     ooha.header_id = oola.header_id
                                       AND oola.open_flag = 'Y'
                                       AND ooha.header_id = orders_rec.header_id
                            FOR UPDATE NOWAIT)
                    LOOP
                        lc_flag   := 'Y';
                    END LOOP;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_return_status   := 'N';
                        lc_error_message   := 'Order Locked';
                        lc_flag            := 'N';
                END;

                IF lc_flag = 'Y'
                THEN
                    SAVEPOINT before_order;
                    ln_order_count           := ln_order_count + 1;
                    -- Header Record
                    l_header_rec             := oe_order_pub.g_miss_header_rec;
                    l_header_rec.header_id   := orders_rec.header_id;
                    l_header_rec.org_id      := orders_rec.org_id;
                    l_header_rec.operation   := oe_globals.g_opr_update;

                    -- Action Table
                    l_action_request_tbl (1)   :=
                        oe_order_pub.g_miss_request_rec;
                    l_action_request_tbl (1).entity_id   :=
                        orders_rec.header_id;
                    l_action_request_tbl (1).entity_code   :=
                        oe_globals.g_entity_header;
                    l_action_request_tbl (1).request_type   :=
                        oe_globals.g_price_order;

                    oe_order_pub.process_order (
                        p_org_id                   => orders_rec.org_id,
                        p_api_version_number       => 1.0,
                        p_init_msg_list            => fnd_api.g_false,
                        p_return_values            => fnd_api.g_false,
                        p_action_commit            => fnd_api.g_false,
                        x_return_status            => lc_return_status,
                        x_msg_count                => ln_msg_count,
                        x_msg_data                 => lc_msg_data,
                        p_header_rec               => l_header_rec,
                        p_header_adj_tbl           => l_header_adj_tbl,
                        p_line_tbl                 => l_line_tbl,
                        p_line_adj_tbl             => l_line_adj_tbl,
                        p_action_request_tbl       => l_action_request_tbl,
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

                    IF lc_return_status <> fnd_api.g_ret_sts_success
                    THEN
                        FOR i IN 1 .. oe_msg_pub.count_msg
                        LOOP
                            oe_msg_pub.get (
                                p_msg_index       => i,
                                p_encoded         => fnd_api.g_false,
                                p_data            => lc_error_message,
                                p_msg_index_out   => ln_msg_index_out);
                        END LOOP;

                        lc_error_message   :=
                            NVL (lc_error_message, 'OE_ORDER_PUB Failed');
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'OE_ORDER_PUB Failed for Header ID '
                            || orders_rec.header_id);
                        fnd_file.put_line (fnd_file.LOG, lc_error_message);
                        ROLLBACK TO before_order;
                    ELSE
                        SELECT SUM (promo)
                          INTO ln_dummy
                          FROM (SELECT COUNT (1) promo
                                  FROM oe_price_adjustments_v opa
                                 WHERE     opa.header_id =
                                           orders_rec.header_id
                                       AND opa.line_id IS NULL
                                       AND adjustment_name LIKE 'DO_PROMO%'
                                -- Header Promotion
                                UNION
                                -- Line Promotion
                                SELECT COUNT (1) promo
                                  FROM oe_price_adjustments_v opa, oe_order_lines_all oola
                                 WHERE     opa.header_id =
                                           orders_rec.header_id
                                       AND oola.header_id = opa.header_id
                                       AND oola.line_id = opa.line_id
                                       AND oola.open_flag = 'Y'
                                       AND adjustment_name LIKE 'DO_PROMO%');

                        IF ln_dummy > 0
                        THEN
                            ln_error_order_count   :=
                                ln_error_order_count + 1;
                            lc_return_status   := 'E';
                            lc_error_message   :=
                                'Unable to remove old Promotion';
                        ELSE
                            ln_success_order_count   :=
                                ln_success_order_count + 1;
                            ln_reset_count     := ln_success_order_count;
                            lc_error_message   := NULL;

                            UPDATE oe_order_headers_all
                               SET attribute11 = orders_rec.promotion_code, last_update_date = SYSDATE, last_updated_by = fnd_global.user_id,
                                   last_update_login = fnd_global.login_id
                             WHERE header_id = orders_rec.header_id;
                        END IF;
                    END IF;                                      -- API status
                END IF;                                              -- Locked
            ELSE
                ln_error_order_count   := ln_error_order_count + 1;
                lc_return_status       := 'E';
                lc_error_message       :=
                    'Order has one or more lines with Calculate Price Flag as Partial or Freeze';
            END IF;

            UPDATE appsro.xxd_ont_mass_promotions_stg_t
               SET record_status = lc_return_status, error_message = lc_error_message, request_id = fnd_global.conc_request_id,
                   last_update_date = SYSDATE, last_updated_by = fnd_global.user_id, last_update_login = fnd_global.login_id
             WHERE header_id = orders_rec.header_id;

            IF MOD (ln_reset_count, 50) = 0
            THEN
                COMMIT;
                ln_reset_count   := 0;
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in CHILD_PRC - ' || x_errbuf);
    END child_prc;

    -- ===============================================================================
    -- This procedure submits child programs based on the number of threads
    -- ===============================================================================
    PROCEDURE master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN appsro.xxd_ont_mass_promotions_stg_t.org_id%TYPE
                          , p_brand IN appsro.xxd_ont_mass_promotions_stg_t.brand%TYPE, p_threads IN NUMBER)
    AS
        ln_req_id     NUMBER;
        lc_req_data   VARCHAR2 (10);
    BEGIN
        lc_req_data   := fnd_conc_global.request_data;

        IF lc_req_data IS NULL
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Start MASTER_PRC');

            FOR i IN 1 .. p_threads
            LOOP
                ln_req_id   := 0;

                ln_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXD_ONT_MASS_PROMO_CHILD',
                        description   => NULL,
                        start_time    => NULL,
                        sub_request   => TRUE,
                        argument1     => p_org_id,
                        argument2     => p_brand,
                        argument3     => p_threads,
                        argument4     => i);
                COMMIT;
            END LOOP;

            fnd_conc_global.set_req_globals (conc_status    => 'PAUSED',
                                             request_data   => 1);

            fnd_file.put_line (fnd_file.LOG,
                               'Successfully Submitted Child Threads');

            fnd_file.put_line (fnd_file.LOG, 'End MASTER_PRC');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in MASTER_PRC : ' || x_errbuf);
    END master_prc;
END xxd_ont_mass_promotions_x_pk;
/
