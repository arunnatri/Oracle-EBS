--
-- XXD_ONT_CALLOFF_ORDER_SCH_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_CALLOFF_ORDER_SCH_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CALLOFF_ORDER_SCH_PKG
    * Design       : This package will be used for Calloff Order Scheduling
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 30-May-2018  1.0        Viswanathan Pandian     Initial Version
    -- 02-Mar-2020  1.1        Viswanathan Pandian     Updated for CCR0008440
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
    -- This procedure will be used to release hold
    -- ======================================================================================
    PROCEDURE release_hold_prc (p_from_calloff_batch_id    IN NUMBER,
                                p_to_calloff_batch_id      IN NUMBER,
                                p_from_customer_batch_id   IN NUMBER,
                                p_to_customer_batch_id     IN NUMBER,
                                p_parent_request_id        IN NUMBER)
    AS
        CURSOR get_hold_id_c IS
            SELECT meaning, TO_NUMBER (lookup_code) lookup_code
              FROM oe_lookups
             WHERE     lookup_type = 'XXD_ONT_CALLOFF_ORDER_HOLDS'
                   AND enabled_flag = 'Y'
                   AND ((start_date_active IS NOT NULL AND start_date_active <= SYSDATE) OR (start_date_active IS NULL AND 1 = 1))
                   AND ((end_date_active IS NOT NULL AND end_date_active >= SYSDATE) OR (end_date_active IS NULL AND 1 = 1));

        CURSOR get_new_lines_c IS
            SELECT DISTINCT calloff_header_id, calloff_line_id
              FROM xxd_ont_bulk_orders_t
             WHERE     parent_request_id = p_parent_request_id
                   AND schedule_status = 'N'
                   AND cancel_status = 'S'
                   AND calloff_batch_id >= p_from_calloff_batch_id
                   AND calloff_batch_id <= p_to_calloff_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id;

        lc_sub_prog_name       VARCHAR2 (100) := 'RELEASE_HOLD_PRC';
        lc_return_status       VARCHAR2 (1);
        lc_error_message       VARCHAR2 (4000);
        lc_msg_data            VARCHAR2 (1000);
        ln_msg_count           NUMBER;
        ln_msg_index_out       NUMBER;
        ln_line_count          NUMBER := 0;
        ln_hold_id             oe_hold_sources_all.hold_id%TYPE;
        ln_new_hold_id         oe_hold_sources_all.hold_id%TYPE;
        ln_reprocess_hold_id   oe_hold_sources_all.hold_id%TYPE;
        l_order_tbl_type       oe_holds_pvt.order_tbl_type;
        hold_id_rec            get_hold_id_c%ROWTYPE;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);

        FOR hold_id_rec IN get_hold_id_c
        LOOP
            IF hold_id_rec.meaning = 'NEW'
            THEN
                ln_new_hold_id   := hold_id_rec.lookup_code;
            ELSE
                ln_reprocess_hold_id   := hold_id_rec.lookup_code;
            END IF;
        END LOOP;

        -- Release Hold For NEW Lines
        FOR i IN get_new_lines_c
        LOOP
            ln_line_count                                := ln_line_count + 1;
            l_order_tbl_type (ln_line_count).header_id   :=
                i.calloff_header_id;
            l_order_tbl_type (ln_line_count).line_id     := i.calloff_line_id;
        END LOOP;

        -- Call API once for NEW and once for REPROCESS
        FOR i IN 1 .. 2
        LOOP
            IF i = 1
            THEN
                ln_hold_id   := ln_new_hold_id;
            ELSE
                ln_hold_id   := ln_reprocess_hold_id;
            END IF;

            -- Call Process Order to release hold
            oe_holds_pub.release_holds (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_false, p_order_tbl => l_order_tbl_type, p_hold_id => ln_hold_id, p_release_reason_code => 'PGM_BULK_RELEASE', p_release_comment => 'Program Released hold on Bulk Call off Order by Request ' || gn_request_id, x_return_status => lc_return_status, x_msg_count => ln_msg_count
                                        , x_msg_data => lc_msg_data);

            debug_msg ('Hold ID = ' || ln_hold_id);
            debug_msg ('Hold Release Status = ' || lc_return_status);

            IF lc_return_status <> 'S'
            THEN
                FOR j IN 1 .. oe_msg_pub.count_msg
                LOOP
                    oe_msg_pub.get (p_msg_index => j, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                    , p_msg_index_out => ln_msg_index_out);
                    lc_error_message   := lc_error_message || lc_msg_data;
                END LOOP;

                debug_msg (
                       'Unable to release hold with error = '
                    || lc_error_message);
            END IF;
        END LOOP;

        gc_delimiter   := CHR (9);
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Others Exception in RELEASE_HOLD_PRC = ' || SQLERRM);
            debug_msg ('End ' || lc_sub_prog_name);
            RAISE;
    END release_hold_prc;

    -- ======================================================================================
    -- This procedure will be used to Insert Split At Scheduling System Parameter
    -- ======================================================================================
    FUNCTION insert_split_sys_param_fnc
        RETURN VARCHAR2
    AS
        lc_sub_prog_name           VARCHAR2 (100) := 'INSERT_SPLIT_SYS_PARAM_FNC';
        l_sys_param_all_rec_type   oe_parameters_pkg.sys_param_all_rec_type;
        lc_row_id                  VARCHAR2 (1000);
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        l_sys_param_all_rec_type.org_id              := gn_org_id;
        l_sys_param_all_rec_type.parameter_code      :=
            'AUTO_SPLIT_AT_SCHEDULING';
        l_sys_param_all_rec_type.parameter_value     := 'Q'; -- Without Substitution
        l_sys_param_all_rec_type.creation_date       := SYSDATE;
        l_sys_param_all_rec_type.created_by          := gn_user_id;
        l_sys_param_all_rec_type.last_update_date    := SYSDATE;
        l_sys_param_all_rec_type.last_updated_by     := gn_user_id;
        l_sys_param_all_rec_type.last_update_login   := gn_login_id;
        oe_parameters_pkg.insert_row (
            p_sys_param_all_rec   => l_sys_param_all_rec_type,
            x_row_id              => lc_row_id);

        IF SQL%ROWCOUNT > 0
        THEN
            debug_msg ('System Parameter Insert Count=' || SQL%ROWCOUNT);
            debug_msg (
                'AUTO_SPLIT_AT_SCHEDULING Value=' || oe_sys_parameters.VALUE ('AUTO_SPLIT_AT_SCHEDULING', gn_org_id));
        ELSE
            debug_msg ('Unable to Insert Record');
        END IF;

        debug_msg ('End ' || lc_sub_prog_name);
        RETURN lc_row_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg (
                   'Others Exception in INSERT_SPLIT_SYS_PARAM_FNC = '
                || SQLERRM);
            debug_msg ('End ' || lc_sub_prog_name);
            RETURN NULL;
    END insert_split_sys_param_fnc;

    -- ======================================================================================
    -- This procedure will be used to Delete Split At Scheduling System Parameter
    -- ======================================================================================
    FUNCTION delete_split_sys_param_fnc (p_row_id IN VARCHAR2)
        RETURN VARCHAR2
    AS
        lc_sub_prog_name   VARCHAR2 (100) := 'DELETE_SPLIT_SYS_PARAM_FNC';
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        oe_parameters_pkg.delete_row (x_rowid => p_row_id);
        debug_msg ('End ' || lc_sub_prog_name);
        RETURN 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg (
                   'Others Exception in DELETE_SPLIT_SYS_PARAM_FNC = '
                || SQLERRM);
            debug_msg ('End ' || lc_sub_prog_name);
            RETURN 'E';
    END delete_split_sys_param_fnc;

    -- ======================================================================================
    -- This procedure performs below activities for eligible order lines
    -- 1. Selects and Schedules Eligible Calloff Order Lines
    -- 2. Update Status in Custom Table
    -- ======================================================================================
    PROCEDURE schedule_prc (
        x_errbuf                      OUT NOCOPY VARCHAR2,
        x_retcode                     OUT NOCOPY VARCHAR2,
        p_from_calloff_batch_id    IN            NUMBER,
        p_to_calloff_batch_id      IN            NUMBER,
        p_from_customer_batch_id   IN            NUMBER,
        p_to_customer_batch_id     IN            NUMBER,
        p_parent_request_id        IN            NUMBER,
        p_debug                    IN            VARCHAR2)
    AS
        CURSOR get_calloff_headers_c IS
            SELECT DISTINCT calloff_order_number, calloff_header_id, org_id
              FROM xxd_ont_bulk_orders_t
             WHERE     parent_request_id = p_parent_request_id
                   AND schedule_status = 'N'
                   AND cancel_status = 'S'
                   AND calloff_batch_id >= p_from_calloff_batch_id
                   AND calloff_batch_id <= p_to_calloff_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id;

        CURSOR get_new_lines_c IS
            SELECT DISTINCT calloff_order_number, calloff_line_id, 'BULK' result_code
              FROM xxd_ont_bulk_orders_t
             WHERE     parent_request_id = p_parent_request_id
                   AND cancel_status = 'S'
                   AND calloff_batch_id >= p_from_calloff_batch_id
                   AND calloff_batch_id <= p_to_calloff_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id
            -- Start changes for CCR0008440
            UNION
            -- Lines that got split due to availability
            SELECT ooha.order_number calloff_order_number, oola.line_id calloff_line_id, 'BULK' result_code
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, xxd_ont_bulk_orders_t xobot
             WHERE     xobot.parent_request_id = p_parent_request_id
                   AND xobot.cancel_status = 'S'
                   AND xobot.calloff_batch_id >= p_from_calloff_batch_id
                   AND xobot.calloff_batch_id <= p_to_calloff_batch_id
                   AND xobot.customer_batch_id >= p_from_customer_batch_id
                   AND xobot.customer_batch_id <= p_to_customer_batch_id
                   AND xobot.calloff_header_id = ooha.header_id
                   AND xobot.calloff_line_id = oola.split_from_line_id
                   AND ooha.header_id = oola.header_id
                   AND oola.open_flag = 'Y'
                   AND xobot.link_type = 'BULK_LINK';

        CURSOR get_sys_param_c IS
            SELECT COUNT (1)
              FROM oe_sys_parameters_all
             WHERE     org_id = gn_org_id
                   AND parameter_code = 'AUTO_SPLIT_AT_SCHEDULING'
                   AND parameter_value = 'Q';

        ln_exists          NUMBER := 0;
        -- End changes for CCR0008440

        lc_sub_prog_name   VARCHAR2 (100) := 'CHILD_PRC';
        lc_errbuf          VARCHAR2 (4000);
        lc_retcode         VARCHAR2 (4000);
        lc_row_id          VARCHAR2 (1000);
        lc_message         VARCHAR2 (4000);
        lc_status          VARCHAR2 (1);
        ln_record_count    NUMBER := 0;
    BEGIN
        -- Per Oracle Doc ID 1922152.1
        UPDATE fnd_concurrent_requests
           SET priority_request_id = p_parent_request_id, is_sub_request = 'Y'
         WHERE request_id = gn_request_id;

        gc_debug_enable   := NVL (p_debug, 'N');
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        xxd_ont_calloff_process_pkg.init ();
        fnd_profile.put ('MRP_ATP_CALC_SD', 'N');

        /****************************************************************************************
        * Release Hold section
        ****************************************************************************************/
        release_hold_prc (p_from_calloff_batch_id, p_to_calloff_batch_id, p_from_customer_batch_id
                          , p_to_customer_batch_id, p_parent_request_id);
        debug_msg (
               'Completed Release Hold at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        -- Start changes for CCR0008440
        OPEN get_sys_param_c;

        FETCH get_sys_param_c INTO ln_exists;

        CLOSE get_sys_param_c;

        IF ln_exists > 0
        THEN
            debug_msg ('System Parameter Setup for Split is already enabled');
        END IF;

        -- End changes for CCR0008440

        /****************************************************************************************
        * Schedule Orders section
        ****************************************************************************************/
        FOR calloff_headers_rec IN get_calloff_headers_c
        LOOP
            ln_record_count   := ln_record_count + 1;

            IF lc_row_id IS NULL AND ln_exists = 0 -- Added ln_exists for CCR0008440
            THEN
                debug_msg ('Modify System Parameter for Split');
                /****************************************************************************************
                * Insert Split System Parameter Record section
                ****************************************************************************************/
                lc_row_id   := insert_split_sys_param_fnc;
            END IF;

            debug_msg (RPAD ('=', 100, '='));
            debug_msg (
                   'Scheduling all lines of Calloff Order Number '
                || calloff_headers_rec.calloff_order_number
                || '. Header ID '
                || calloff_headers_rec.calloff_header_id);
            oe_sch_conc_requests.request (errbuf => lc_errbuf, retcode => lc_retcode, p_org_id => calloff_headers_rec.org_id, p_order_number_low => calloff_headers_rec.calloff_order_number, p_order_number_high => calloff_headers_rec.calloff_order_number, p_request_date_low => NULL, p_request_date_high => NULL, p_customer_po_number => NULL, p_ship_to_location => NULL, p_order_type => NULL, p_customer => NULL, p_ordered_date_low => NULL, p_ordered_date_high => NULL, p_warehouse => NULL, p_item => NULL, p_demand_class => NULL, p_planning_priority => NULL, p_shipment_priority => NULL, p_line_type => NULL, p_line_request_date_low => NULL, p_line_request_date_high => NULL, p_line_ship_to_location => NULL, p_sch_ship_date_low => NULL, p_sch_ship_date_high => NULL, p_sch_arrival_date_low => NULL, p_sch_arrival_date_high => NULL, p_booked => NULL, p_sch_mode => 'SCHEDULE', p_dummy4 => 'Y', p_bulk_processing => 'N', p_dummy1 => NULL, p_dummy2 => NULL, p_apply_warehouse => NULL, p_apply_sch_date => NULL, p_order_by_first => NULL, p_order_by_sec => NULL, p_picked => NULL, p_dummy3 => NULL, p_commit_threshold => 999999
                                          , p_num_instances => NULL);
            debug_msg ('Scheduling Done!');
            debug_msg ('Update Status in Custom Table');

            /****************************************************************************************
            * Update Status section
            ****************************************************************************************/
            UPDATE xxd_ont_bulk_orders_t xobot
               SET (xobot.schedule_status,
                    xobot.error_message,
                    xobot.request_id)   =
                       (SELECT CASE
                                   WHEN oola.schedule_ship_date IS NOT NULL
                                   THEN
                                       'S'
                                   ELSE
                                       'E'
                               END,
                               CASE
                                   WHEN oola.schedule_ship_date IS NOT NULL
                                   THEN
                                       NULL
                                   ELSE
                                       (SELECT SUBSTR (MAX (opt.MESSAGE_TEXT), 1, 2000)
                                          FROM oe_processing_msgs opm, oe_processing_msgs_tl opt
                                         WHERE     opm.transaction_id =
                                                   opt.transaction_id
                                               AND opt.language =
                                                   USERENV ('LANG')
                                               AND opm.entity_code = 'LINE'
                                               AND opm.header_id =
                                                   oola.header_id
                                               AND opm.line_id = oola.line_id)
                               END,
                               gn_request_id
                          FROM oe_order_lines_all oola
                         WHERE     oola.header_id = xobot.calloff_header_id
                               AND oola.line_id = xobot.calloff_line_id
                               AND oola.org_id = xobot.org_id
                               AND xobot.parent_request_id =
                                   p_parent_request_id
                               AND xobot.schedule_status = 'N'
                               AND xobot.cancel_status = 'S'
                               AND xobot.calloff_batch_id >=
                                   p_from_calloff_batch_id
                               AND xobot.calloff_batch_id <=
                                   p_to_calloff_batch_id
                               AND xobot.customer_batch_id >=
                                   p_from_customer_batch_id
                               AND xobot.customer_batch_id <=
                                   p_to_customer_batch_id
                               AND xobot.calloff_header_id =
                                   calloff_headers_rec.calloff_header_id)
             WHERE EXISTS
                       (SELECT 1
                          FROM oe_order_lines_all oola
                         WHERE     oola.header_id = xobot.calloff_header_id
                               AND oola.line_id = xobot.calloff_line_id
                               AND oola.org_id = xobot.org_id
                               AND xobot.parent_request_id =
                                   p_parent_request_id
                               AND xobot.schedule_status = 'N'
                               AND xobot.cancel_status = 'S'
                               AND xobot.calloff_batch_id >=
                                   p_from_calloff_batch_id
                               AND xobot.calloff_batch_id <=
                                   p_to_calloff_batch_id
                               AND xobot.customer_batch_id >=
                                   p_from_customer_batch_id
                               AND xobot.customer_batch_id <=
                                   p_to_customer_batch_id
                               AND xobot.calloff_header_id =
                                   calloff_headers_rec.calloff_header_id);
        END LOOP;

        debug_msg (
               'Completed Scheduling at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        /****************************************************************************************
        * Delete Split System Parameter Record section
        ****************************************************************************************/
        IF lc_row_id IS NOT NULL
        THEN
            debug_msg ('Revert System Parameter Modification for Split');
            lc_status   := delete_split_sys_param_fnc (lc_row_id);
        END IF;

        COMMIT;

        debug_msg (RPAD ('=', 100, '='));

        /****************************************************************************************
        * Progress Workflow section
        ****************************************************************************************/
        FOR new_lines_rec IN get_new_lines_c
        LOOP
            debug_msg (
                   'Progressing Workflow Activity for Calloff Order Number '
                || new_lines_rec.calloff_order_number
                || ' Line ID '
                || new_lines_rec.calloff_line_id
                || ' with Result_code as '
                || new_lines_rec.result_code);

            BEGIN
                wf_engine.completeactivity (
                    itemtype   => 'OEOL',
                    itemkey    => TO_CHAR (new_lines_rec.calloff_line_id),
                    activity   => 'XXD_ONT_BULK_WAIT',
                    result     => new_lines_rec.result_code);
                debug_msg ('WF Progress Success');
            EXCEPTION
                WHEN OTHERS
                THEN
                    debug_msg ('WF Error: ' || SQLERRM);
            END;
        END LOOP;

        COMMIT;
        debug_msg (
               'Completed WF Progress at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        /****************************************************************************************
        * Update Order Line Status section
        ****************************************************************************************/
        UPDATE oe_order_lines_all oola
           SET oola.global_attribute19   = 'PROCESSED'
         WHERE EXISTS
                   (  SELECT 1
                        FROM xxd_ont_bulk_orders_t xobot
                       WHERE     xobot.calloff_header_id = oola.header_id
                             AND xobot.calloff_line_id = oola.line_id
                             AND xobot.cancel_status = 'S'
                             AND xobot.parent_request_id = p_parent_request_id
                             AND xobot.calloff_batch_id >=
                                 p_from_calloff_batch_id
                             AND xobot.calloff_batch_id <=
                                 p_to_calloff_batch_id
                             AND xobot.customer_batch_id >=
                                 p_from_customer_batch_id
                             AND xobot.customer_batch_id <=
                                 p_to_customer_batch_id
                    GROUP BY xobot.calloff_line_id);

        COMMIT;

        IF ln_record_count = 0
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
            lc_message   := SUBSTR (SQLERRM, 1, 2000);
            ROLLBACK;

            IF lc_row_id IS NOT NULL
            THEN
                lc_status   := delete_split_sys_param_fnc (lc_row_id);
            END IF;

            UPDATE xxd_ont_bulk_orders_t
               SET schedule_status = 'E', error_message = lc_message, request_id = gn_request_id
             WHERE     parent_request_id = p_parent_request_id
                   AND schedule_status = 'N'
                   AND calloff_batch_id >= p_from_calloff_batch_id
                   AND calloff_batch_id <= p_to_calloff_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id;

            COMMIT;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in CHILD_PRC = ' || SQLERRM);
    END schedule_prc;
END xxd_ont_calloff_order_sch_pkg;
/
