--
-- XXD_MSC_OE_RSCHDL_ORDRS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_msc_oe_rschdl_ordrs_pkg
AS
    PROCEDURE prc_xxd_msc_oe_rschdlordrs (errbuff OUT VARCHAR2, retcode OUT NUMBER, pn_ou_id NUMBER
                                          , pn_warehouse_id NUMBER)
    AS
        l_new_request_id          NUMBER;
        l_request_num_lines       NUMBER;
        l_total_lines             NUMBER;
        l_lines_processed         NUMBER;
        l_request_number          NUMBER;
        l_req_data                VARCHAR2 (10);
        l_req_data_counter        NUMBER;
        j                         NUMBER;
        k                         NUMBER;
        l_item_id                 NUMBER;
        l_lines_per_request       NUMBER;
        l_debug_level    CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        x_child_req_tbl           oe_globals.selected_record_tbl;
        l_sch_mode                VARCHAR2 (30);
        l_next                    VARCHAR2 (1);

        l_commit_threshold        NUMBER := 3000;
        l_num_instances           NUMBER := 20;
        l_org_id                  NUMBER := pn_ou_id;
        l_ship_from_org_id        NUMBER := pn_warehouse_id;

        x_return_status           VARCHAR2 (100);

        TYPE bulk_reschedule_table IS TABLE OF oe_bulk_schedule_temp%ROWTYPE;

        g_bulk_reschedule_table   bulk_reschedule_table;

        l_line_index              NUMBER := 0;

        CURSOR c_get_lines (c_org_id NUMBER, c_ship_from_org_id NUMBER)
        IS
              SELECT l.ship_from_org_id, l.inventory_item_id, l.line_id,
                     l.org_id
                FROM oe_order_headers_all H, oe_order_lines_all L
               WHERE     H.header_id = L.header_id
                     AND H.org_id = L.org_id
                     AND NVL (H.transaction_phase_code, 'F') = 'F'
                     AND H.open_flag = 'Y'
                     AND L.open_flag = 'Y'
                     AND L.line_category_code <> 'RETURN'
                     AND L.item_type_code <> 'SERVICE'
                     AND NVL (L.subscription_enable_flag, 'N') = 'N'
                     AND L.source_type_code <> 'EXTERNAL'
                     AND L.org_id = c_org_id
                     AND l.ship_from_org_id = c_ship_from_org_id
                     AND L.schedule_status_code IS NOT NULL
                     AND l.top_model_line_id IS NULL
                     AND l.ship_Set_id IS NULL
                     AND l.arrival_set_id IS NULL
            ORDER BY l.ship_from_org_id, l.inventory_item_id, l.line_id;

        l_session_id              NUMBER;
        l_user_id                 NUMBER := fnd_profile.VALUE ('USER_ID'); --  1318;
        l_responsibility_id       NUMBER := fnd_global.resp_id;       --21623;
        l_login_id                NUMBER := fnd_profile.VALUE ('LOGIN_ID'); --2987330;
    BEGIN
        FND_GLOBAL.INITIALIZE (session_id              => l_session_id,
                               user_id                 => l_user_id,
                               resp_id                 => l_responsibility_id,
                               resp_appl_id            => 660,
                               security_group_id       => 0,
                               site_id                 => NULL,
                               login_id                => l_login_id,
                               conc_login_id           => NULL,
                               prog_appl_id            => NULL,
                               conc_program_id         => NULL,
                               conc_request_id         => NULL,
                               conc_priority_request   => NULL);
        mo_global.set_policy_context ('S', l_org_id);

        l_total_lines             := 0;
        l_lines_processed         := 0;
        l_request_number          := 0;
        l_lines_per_request       := 0;
        x_return_status           := fnd_api.g_ret_sts_success;
        l_sch_mode                := 'BULK_RESCH_CHILD';

        g_bulk_reschedule_table   := bulk_reschedule_table ();   -- ER18493998

        FOR l_rec IN c_get_lines (l_org_id, l_ship_from_org_id)
        LOOP
            l_line_index                                     := l_line_index + 1;
            g_bulk_reschedule_table.EXTEND;
            g_bulk_reschedule_table (l_line_index).line_id   := l_rec.line_id;
            g_bulk_reschedule_table (l_line_index).org_id    := l_org_id;
            g_bulk_reschedule_table (l_line_index).processing_order   :=
                l_line_index;
            g_bulk_reschedule_table (l_line_index).group_number   :=
                l_line_index;
            g_bulk_reschedule_table (l_line_index).attribute1   :=
                l_rec.inventory_item_id;
            g_bulk_reschedule_table (l_line_index).ship_from_org_id   :=
                l_ship_from_org_id;
        /*
        g_bulk_reschedule_table (l_line_index).ship_set_id       := l_ship_set_id;
        g_bulk_reschedule_table (l_line_index).arrival_set_id    := l_arrival_set_id;
        g_bulk_reschedule_table (l_line_index).top_model_line_id := l_top_model_line_id;
        g_bulk_reschedule_table (l_line_index).request_date      := l_request_date;
        */
        END LOOP;

        l_total_lines             := l_line_index;

        l_request_num_lines       := CEIL (l_total_lines / l_num_instances);

        IF l_debug_level > 0
        THEN
            oe_debug_pub.ADD ('l_num_instances : ' || l_num_instances, 1);
            oe_debug_pub.ADD ('l_total_lines : ' || l_total_lines, 1);
        END IF;


        j                         := g_bulk_reschedule_table.FIRST;

        WHILE l_lines_processed < l_total_lines
        LOOP
            IF j IS NULL
            THEN
                EXIT;
            END IF;

            l_lines_per_request   := 0;
            l_request_number      := l_request_number + 1;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                    'Spawning child request : ' || l_request_number,
                    1);
            END IF;

            l_new_request_id      :=
                fnd_request.submit_request ('ONT', 'SCHORD', 'Schedule Orders Child ' || l_request_number, NULL, FALSE, l_org_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, l_sch_mode, 'Y', 'N', 'Y', 'Y', NULL, NULL, NULL, NULL, NULL, 'Y', l_commit_threshold
                                            , NULL);

            fnd_file.put_line (
                fnd_file.LOG,
                   'Spawned child request number : '
                || l_request_number
                || ', Request ID : '
                || l_new_request_id);

            IF l_new_request_id > 0
            THEN
                x_child_req_tbl (l_request_number).id1   := l_new_request_id;
            ELSE
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;

            WHILE l_lines_per_request < l_request_num_lines AND j IS NOT NULL
            LOOP
                IF l_lines_per_request < l_request_num_lines
                THEN                                 -- Bug 20273441 : Issue 8
                    l_lines_per_request                             := l_lines_per_request + 1;
                    g_bulk_reschedule_table (j).parent_request_id   :=
                        l_new_request_id;
                    g_bulk_reschedule_table (j).child_request_id    :=
                        l_new_request_id;
                    l_next                                          := 'Y'; -- Bug 20273441 : Issue 8
                END IF;                              -- Bug 20273441 : Issue 8

                l_item_id   := g_bulk_reschedule_table (j).attribute1; --Inventory Item Id
                k           := j;

                IF l_lines_per_request = l_request_num_lines
                THEN
                    IF l_debug_level > 0
                    THEN
                        oe_debug_pub.ADD (
                            'reached last record. check if it is part of a set or model and then group together.',
                            1);
                    END IF;

                    k   := g_bulk_reschedule_table.NEXT (j); -- Bug 20273441 : Issue 8

                    IF k IS NOT NULL
                    THEN                             -- Bug 20273441 : Issue 8
                        WHILE     k IS NOT NULL
                              AND g_bulk_reschedule_table (k).attribute1 =
                                  l_item_id
                        LOOP
                            IF l_debug_level > 0
                            THEN
                                oe_debug_pub.ADD (
                                    'line is part of a group. query rest of the group as well and add here',
                                    1);
                            END IF;

                            IF g_bulk_reschedule_table (k).attribute1 =
                               l_item_id
                            THEN
                                g_bulk_reschedule_table (k).child_request_id   :=
                                    l_new_request_id;
                                l_lines_per_request   :=
                                    l_lines_per_request + 1;
                                j   := k;
                                k   := g_bulk_reschedule_table.NEXT (k);
                            END IF;
                        END LOOP;
                    END IF;                          -- Bug 20273441 : Issue 8
                END IF;

                IF l_next = 'Y'
                THEN                                 -- Bug 20273441 : Issue 8
                    j        := g_bulk_reschedule_table.NEXT (j);
                    l_next   := 'N';                 -- Bug 20273441 : Issue 8
                END IF;                              -- Bug 20273441 : Issue 8
            END LOOP;

            l_lines_processed     := l_lines_processed + l_lines_per_request;
        END LOOP;

        --bulk insert
        FORALL x
            IN g_bulk_reschedule_table.FIRST .. g_bulk_reschedule_table.LAST
            INSERT INTO oe_bulk_schedule_temp (parent_request_id, child_request_id, org_id, line_id, processing_order, group_number, processed, ship_set_id, arrival_set_id, top_model_line_id, schedule_ship_date, schedule_arrival_date, request_date, ship_from_org_id, attribute1, attribute2, attribute3, attribute4, attribute5, date1, date2
                                               , date3, date4, date5)
                     VALUES (
                                g_bulk_reschedule_table (x).child_request_id,
                                g_bulk_reschedule_table (x).child_request_id,
                                g_bulk_reschedule_table (x).org_id,
                                g_bulk_reschedule_table (x).line_id,
                                g_bulk_reschedule_table (x).processing_order,
                                g_bulk_reschedule_table (x).group_number,
                                'N',
                                g_bulk_reschedule_table (x).ship_set_id,
                                g_bulk_reschedule_table (x).arrival_set_id,
                                g_bulk_reschedule_table (x).top_model_line_id,
                                g_bulk_reschedule_table (x).schedule_ship_date,
                                g_bulk_reschedule_table (x).schedule_arrival_date,
                                g_bulk_reschedule_table (x).request_date,
                                g_bulk_reschedule_table (x).ship_from_org_id,
                                g_bulk_reschedule_table (x).attribute1,
                                g_bulk_reschedule_table (x).attribute2,
                                g_bulk_reschedule_table (x).attribute3,
                                g_bulk_reschedule_table (x).attribute4,
                                g_bulk_reschedule_table (x).attribute5,
                                g_bulk_reschedule_table (x).date1,
                                g_bulk_reschedule_table (x).date2,
                                g_bulk_reschedule_table (x).date3,
                                g_bulk_reschedule_table (x).date4,
                                g_bulk_reschedule_table (x).date5);

        COMMIT;                                            --commit everything

        --Bug 21132131, Gather stats on the table
        BEGIN
            FND_STATS.Gather_Table_Stats (
                ownname   => 'ONT',
                tabname   => 'OE_BULK_SCHEDULE_TEMP');
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;
    END prc_xxd_msc_oe_rschdlordrs;
END xxd_msc_oe_rschdl_ordrs_pkg;
/
