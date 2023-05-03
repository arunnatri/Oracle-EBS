--
-- XXD_ONT_BULK_ORDER_CANCEL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_BULK_ORDER_CANCEL_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_ORDER_CANCEL_PKG
    * Design       : This package will be used for Bulk Order Cancellation
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 30-May-2018  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    gn_org_id         NUMBER := fnd_global.org_id;
    gn_user_id        NUMBER := fnd_global.user_id;
    gn_login_id       NUMBER := fnd_global.login_id;
    gn_request_id     NUMBER := fnd_global.conc_request_id;
    gc_delimiter      VARCHAR2 (100);
    gc_debug_enable   VARCHAR2 (1);

    -- ======================================================================================
    -- This procedure prints the Debug Messages in Log Or File
    -- ======================================================================================
    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        -- Write Conc Log
        IF gc_debug_enable = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, gc_delimiter || p_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END debug_msg;

    -- ======================================================================================
    -- This procedure performs below activities for eligible order lines
    -- 1. Selects and Cancels Eligible Bulk Order Lines
    -- 2. Update Status in Custom Table
    -- ======================================================================================
    PROCEDURE cancel_prc (x_errbuf                      OUT NOCOPY VARCHAR2,
                          x_retcode                     OUT NOCOPY VARCHAR2,
                          p_from_bulk_batch_id       IN            NUMBER,
                          p_to_bulk_batch_id         IN            NUMBER,
                          p_from_customer_batch_id   IN            NUMBER,
                          p_to_customer_batch_id     IN            NUMBER,
                          p_parent_request_id        IN            NUMBER,
                          p_debug                    IN            VARCHAR2)
    AS
        CURSOR get_bulk_headers_c IS
            SELECT DISTINCT bulk_order_number, bulk_header_id, org_id
              FROM xxd_ont_bulk_orders_t
             WHERE     parent_request_id = p_parent_request_id
                   AND cancel_status = 'N'
                   AND bulk_batch_id >= p_from_bulk_batch_id
                   AND bulk_batch_id <= p_to_bulk_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id;

        CURSOR get_bulk_lines_c (
            p_header_id IN oe_order_lines_all.header_id%TYPE)
        IS
            SELECT *
              FROM (SELECT bulk_line_id, cancel_qty, bulk_id,
                           MAX (bulk_id) OVER (PARTITION BY bulk_line_id) max_bulk_id
                      FROM xxd_ont_bulk_orders_t
                     WHERE     bulk_header_id = p_header_id
                           AND parent_request_id = p_parent_request_id
                           AND cancel_status = 'N'
                           AND bulk_batch_id >= p_from_bulk_batch_id
                           AND bulk_batch_id <= p_to_bulk_batch_id
                           AND customer_batch_id >= p_from_customer_batch_id
                           AND customer_batch_id <= p_to_customer_batch_id)
             WHERE bulk_id = max_bulk_id;

        lc_sub_prog_name       VARCHAR2 (100) := 'CHILD_PRC';
        lc_api_return_status   VARCHAR2 (1);
        lc_lock_status         VARCHAR2 (1);
        lc_status              VARCHAR2 (1);
        lc_row_id              VARCHAR2 (1000);
        lc_error_message       VARCHAR2 (4000);
        ln_record_count        NUMBER := 0;
        ln_line_tbl_count      NUMBER := 0;
        ln_commit_count        NUMBER := 0;
        l_header_rec           oe_order_pub.header_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        lx_line_tbl            oe_order_pub.line_tbl_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
    BEGIN
        -- Per Oracle Doc ID 1922152.1
        UPDATE fnd_concurrent_requests
           SET priority_request_id = p_parent_request_id, is_sub_request = 'Y'
         WHERE request_id = gn_request_id;

        gc_debug_enable   := NVL (p_debug, 'N');
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        xxd_ont_calloff_process_pkg.init ();
        fnd_profile.put ('MRP_ATP_CALC_SD', 'N');

        /****************************************************************************************
        * Cancel Bulk section
        ****************************************************************************************/
        FOR bulk_headers_rec IN get_bulk_headers_c
        LOOP
            lc_lock_status   := 'S';

            BEGIN
                FOR i IN (    SELECT line_id
                                FROM oe_order_lines_all
                               WHERE header_id = bulk_headers_rec.bulk_header_id
                          FOR UPDATE NOWAIT)
                LOOP
                    NULL;
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_error_message       :=
                        'One or more line is locked by another user';
                    debug_msg (lc_error_message);
                    lc_lock_status         := 'E';
                    lc_api_return_status   := 'E';
            END;

            IF lc_lock_status = 'S'
            THEN
                lc_api_return_status     := 'S';
                ln_record_count          := ln_record_count + 1;
                ln_line_tbl_count        := 0;
                debug_msg (RPAD ('=', 100, '='));
                debug_msg (
                       'Processing Bulk Order Number '
                    || bulk_headers_rec.bulk_order_number
                    || '. Header ID '
                    || bulk_headers_rec.bulk_header_id);
                debug_msg (
                       'Start Time '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

                l_header_rec             := oe_order_pub.g_miss_header_rec;
                l_line_tbl               := oe_order_pub.g_miss_line_tbl;
                -- Header
                l_header_rec.header_id   := bulk_headers_rec.bulk_header_id;
                l_header_rec.operation   := oe_globals.g_opr_update;

                FOR bulk_lines_rec
                    IN get_bulk_lines_c (bulk_headers_rec.bulk_header_id)
                LOOP
                    lc_error_message       := NULL;
                    lc_api_return_status   := NULL;

                    ln_line_tbl_count      := ln_line_tbl_count + 1;
                    -- Line
                    l_line_tbl (ln_line_tbl_count)   :=
                        oe_order_pub.g_miss_line_rec;
                    l_line_tbl (ln_line_tbl_count).header_id   :=
                        bulk_headers_rec.bulk_header_id;
                    l_line_tbl (ln_line_tbl_count).org_id   :=
                        bulk_headers_rec.org_id;
                    l_line_tbl (ln_line_tbl_count).line_id   :=
                        bulk_lines_rec.bulk_line_id;
                    l_line_tbl (ln_line_tbl_count).ordered_quantity   :=
                        bulk_lines_rec.cancel_qty;

                    IF bulk_lines_rec.cancel_qty = 0
                    THEN
                        l_line_tbl (ln_line_tbl_count).cancelled_flag   :=
                            'Y';
                    END IF;

                    l_line_tbl (ln_line_tbl_count).change_reason   :=
                        'BLK_ADJ_PGM';
                    l_line_tbl (ln_line_tbl_count).change_comments   :=
                           'Bulk Order Qty Adjustment done on '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM')
                        || ' by program request_id:'
                        || gn_request_id;
                    l_line_tbl (ln_line_tbl_count).request_id   :=
                        gn_request_id;
                    l_line_tbl (ln_line_tbl_count).operation   :=
                        oe_globals.g_opr_update;
                END LOOP;

                xxd_ont_calloff_process_pkg.process_order (
                    p_header_rec           => l_header_rec,
                    p_line_tbl             => l_line_tbl,
                    p_action_request_tbl   => l_action_request_tbl,
                    x_line_tbl             => lx_line_tbl,
                    x_return_status        => lc_api_return_status,
                    x_error_message        => lc_error_message);
                debug_msg (
                    'Bulk Cancellation Status = ' || lc_api_return_status);
                debug_msg (
                       'End Time '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            END IF;

            UPDATE xxd_ont_bulk_orders_t
               SET cancel_status = lc_api_return_status, error_message = SUBSTR (error_message || lc_error_message, 1, 2000), link_type = DECODE (lc_api_return_status, 'S', 'BULK_LINK', 'BULK_DELINK'),
                   request_id = gn_request_id, last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     bulk_header_id = bulk_headers_rec.bulk_header_id
                   AND parent_request_id = p_parent_request_id
                   AND cancel_status = 'N'
                   AND bulk_batch_id >= p_from_bulk_batch_id
                   AND bulk_batch_id <= p_to_bulk_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id;

            debug_msg ('Updated Status in Custom Table');
            debug_msg (RPAD ('=', 100, '='));
        END LOOP;

        COMMIT;

        IF ln_record_count < 0
        THEN
            debug_msg ('No Data Found');
        END IF;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_bulk_orders_t
               SET status = 'E', cancel_status = 'E', link_type = 'BULK_DELINK',
                   error_message = lc_error_message
             WHERE     parent_request_id = p_parent_request_id
                   AND cancel_status = 'N'
                   AND bulk_batch_id >= p_from_bulk_batch_id
                   AND bulk_batch_id <= p_to_bulk_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in CHILD_PRC = ' || lc_error_message);
    END cancel_prc;
END xxd_ont_bulk_order_cancel_pkg;
/
