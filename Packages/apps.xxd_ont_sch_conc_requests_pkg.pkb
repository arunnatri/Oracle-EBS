--
-- XXD_ONT_SCH_CONC_REQUESTS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_SCH_CONC_REQUESTS_PKG"
AS
    /* $Header: OEXCSCHB.pls 120.30.12020000.26 2015/08/06 08:49:45 rahujain ship $ */
    /****************************************************************************************
    * Package      : XXD_ONT_SCH_CONC_REQUESTS_PKG
    * Design       : Custom Schedule Orders Program
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 19-Jan-2022  1.0        Viswanathan Pandian     Version copied from Schedule Orders
    --                                                 Code created for CCR0009761
    ******************************************************************************************/
    G_PKG_NAME       CONSTANT VARCHAR2 (30) := 'XXD_ONT_SCH_CONC_REQUESTS_PKG';

    --5166476
    /*
    TYPE status_arr IS TABLE OF VARCHAR2(1) INDEX BY BINARY_INTEGER;
    OE_line_status_Tbl status_arr;
    */

    -- ER18493998
    TYPE bulk_reschedule_table IS TABLE OF oe_bulk_schedule_temp%ROWTYPE;

    g_bulk_reschedule_table   bulk_reschedule_table;
    g_total_lines_cnt         NUMBER := 0;

    TYPE bulk_line_table IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;                                --Bug 21132131

    g_bulk_line_table         bulk_line_table;                  --Bug 21132131

    --Bug 18268780, perform mrp cleanup whenever error
    PROCEDURE mrp_cleanup
    IS
        l_return_status          VARCHAR2 (1);
        l_line_tbl               OE_ORDER_PUB.Line_Tbl_Type;
        l_line_sch_tbl           OE_ORDER_PUB.Line_Tbl_Type;   -- Bug 21345576
        j                        NUMBER;                       -- Bug 21345576
        i                        NUMBER;
        l_line_count             NUMBER;

        CURSOR C1 IS
            SELECT line_id, schedule_action_code
              FROM oe_schedule_lines_temp
             WHERE schedule_action_code <> 'SCHEDULE';

        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        IF l_debug_level > 0
        THEN
            OE_DEBUG_PUB.Add ('INSIDE mrp_cleanup', 1);
        END IF;

        --Do the backup first.
        i   := 0;
        j   := 0;

        FOR rec IN c1
        LOOP
            -- Bug 21345576 Issue 2: START
            IF rec.schedule_action_code = 'UNSCHEDULE'
            THEN
                i   := i + 1;
                -- Added query_row
                OE_Line_Util.Query_Row (p_line_id    => rec.line_id,
                                        x_line_rec   => l_line_sch_tbl (i));

                --l_line_sch_tbl(i).line_id := rec.line_id;
                l_line_sch_tbl (i).schedule_action_code   :=
                    rec.schedule_action_code;
            ELSIF rec.schedule_action_code IN ('REDEMAND', 'RESCHEDULE')
            THEN
                j   := j + 1;
                -- Added query_row
                OE_Line_Util.Query_Row (p_line_id    => rec.line_id,
                                        x_line_rec   => l_line_tbl (j));

                --l_line_tbl(j).line_id := rec.line_id;
                l_line_tbl (j).schedule_action_code   :=
                    rec.schedule_action_code;
            END IF;

            -- Bug 21345576 Issue 2: END
            /*l_line_tbl(i).line_id := rec.line_id;
            l_line_tbl(i).schedule_action_code := rec.schedule_action_code ;
            i := i + 1;*/
            IF l_debug_level > 0
            THEN
                OE_DEBUG_PUB.Add (
                    'INSIDE mrp_cleanup: line ID: ' || rec.line_id,
                    1);
                OE_DEBUG_PUB.Add (
                    'INSIDE mrp_cleanup: schedule_action_code: ' || rec.schedule_action_code,
                    1);
            END IF;
        END LOOP;

        BEGIN
            --Call for UNSCHEDULE, before rollback
            oe_schedule_util.call_mrp_rollback (l_return_status);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        ROLLBACK TO SAVEPOINT Schedule_Line;

        BEGIN
            -- Bug 21345576 Issue 2: START
            IF i > 0
            THEN
                oe_schedule_util.mrp_rollback (
                    p_line_tbl               => l_line_sch_tbl,
                    p_old_line_tbl           => l_line_sch_tbl,
                    p_schedule_action_code   =>
                        oe_schedule_util.oesch_act_schedule,
                    x_return_status          => l_return_status);
            END IF;

            IF j > 0
            THEN
                oe_schedule_util.mrp_rollback (
                    p_line_tbl               => l_line_tbl,
                    p_old_line_tbl           => l_line_tbl,
                    p_schedule_action_code   =>
                        oe_schedule_util.oesch_act_redemand,
                    x_return_status          => l_return_status);
            END IF;
        -- Bug 21345576 Issue 2: END
        /*l_line_count := l_line_tbl.count;
        for i in 1..l_line_count loop

         if l_line_tbl(i).schedule_action_code = 'UNSCHEDULE' then
            OE_SCHEDULE_UTIL.MRP_ROLLBACK
            ( p_line_id  =>  l_line_tbl(i).line_id
             ,p_schedule_action_code  =>  'SCHEDULE'
             ,x_return_status    => l_return_status);
         end if;

         if l_line_tbl(i).schedule_action_code in ('REDEMAND','RESCHEDULE') then
            OE_SCHEDULE_UTIL.MRP_ROLLBACK
            ( p_line_id  =>  l_line_tbl(i).line_id
            ,p_schedule_action_code  =>  'REDEMAND'
            ,x_return_status    => l_return_status);
         end if;
        end loop;*/
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        IF l_debug_level > 0
        THEN
            OE_DEBUG_PUB.Add ('EXITING mrp_cleanup', 1);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END mrp_cleanup;

    FUNCTION model_processed (p_model_id IN NUMBER, p_line_id IN NUMBER)
        RETURN BOOLEAN
    IS
        l_found                  BOOLEAN := FALSE;
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        /* If many of the lines selected are part of a smc/ato/non-smc model, then delayed
         * request must get logged only for one of the lines.
         */
        --IF oe_model_id_tbl.EXISTS(p_model_id) THEN
        --Added as per ticket 21079696
        IF oe_model_id_tbl.EXISTS (
               MOD (p_model_id, OE_GLOBALS.G_BINARY_LIMIT))
        THEN
            l_found   := TRUE;
        ELSIF p_model_id = p_line_id
        THEN
            --oe_model_id_tbl(p_model_id) := p_model_id;
            --Added as per ticket 21079696
            oe_model_id_tbl (MOD (p_model_id, OE_GLOBALS.G_BINARY_LIMIT))   :=
                p_model_id;
        END IF;

        RETURN (l_found);
    END model_processed;

    -- ER18493998 Start
    FUNCTION line_exists (p_line_id IN NUMBER)
        RETURN BOOLEAN
    IS
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        --Bug 21132131 - Search in g_bulk_line_table which will be much faster.
        IF     g_bulk_line_table.COUNT > 0
           AND g_bulk_line_table.EXISTS (
                   MOD (p_line_id, OE_GLOBALS.G_BINARY_LIMIT))
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END line_exists;

    -- ER18493998 End


    FUNCTION included_processed (p_inc_item_id IN NUMBER)
        RETURN BOOLEAN
    IS
        l_found                  BOOLEAN := FALSE;
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        /* to list the included items processed alone
         */
        IF l_debug_level > 0
        THEN
            OE_DEBUG_PUB.Add ('INSIDE INCLUDED_PROCESSED', 1);
        END IF;

        IF oe_included_id_tbl.EXISTS (p_inc_item_id)
        THEN
            l_found   := TRUE;
        ELSE
            oe_included_id_tbl (p_inc_item_id)   := p_inc_item_id;
        END IF;

        IF l_found
        THEN
            IF l_debug_level > 0
            THEN
                OE_DEBUG_PUB.Add ('INCLIDED ITEM LISTED', 1);
            END IF;
        ELSE
            IF l_debug_level > 0
            THEN
                OE_DEBUG_PUB.Add ('INCLIDED ITEM NOT LISTED', 1);
            END IF;
        END IF;

        RETURN (l_found);
    END included_processed;

    FUNCTION set_processed (p_set_id IN NUMBER)
        RETURN BOOLEAN
    IS
        l_found                  BOOLEAN := FALSE;
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        /* If many of the lines selected are part of a ship set / Arrival set, then delayed
         * request must get logged only for one of the lines.
         */
        --IF oe_set_id_tbl.EXISTS(p_set_id) THEN
        --Added as per bug 21079696
        IF oe_set_id_tbl.EXISTS (MOD (p_set_id, OE_GLOBALS.G_BINARY_LIMIT))
        THEN
            l_found   := TRUE;
        ELSE
            --oe_set_id_tbl(p_set_id) := p_set_id;
            --Added as per bug 21079696
            oe_set_id_tbl (MOD (p_set_id, OE_GLOBALS.G_BINARY_LIMIT))   :=
                p_set_id;
        END IF;

        RETURN (l_found);
    END set_processed;

    --      17482674: new parameter p_check_scheduled will be used for schedule mode
    -- to stop re-processing of failed lines.
    FUNCTION Line_Eligible (p_line_id           IN NUMBER,
                            p_check_scheduled   IN BOOLEAN DEFAULT FALSE)
        RETURN BOOLEAN
    IS
        l_activity_status_code   VARCHAR2 (8);
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        -- Begin : ER 13114460
        l_msg_count              NUMBER;
        l_msg_data               VARCHAR2 (2000);
        l_result                 VARCHAR2 (30);
        l_out_return_status      VARCHAR2 (1) := FND_API.G_RET_STS_SUCCESS;
        -- End : ER 13114460
        l_ssd                    DATE;                        --      17482674
    BEGIN
        -- Check for workflow status to be Purchase Release Eligible
        SELECT ACTIVITY_STATUS, l.schedule_ship_date
          INTO l_activity_status_code, l_ssd
          FROM oe_order_lines_all l, wf_item_activity_statuses wias, wf_process_activities wpa
         WHERE     l.line_id = p_line_id
               AND wias.item_type = 'OEOL'
               AND wias.item_key = TO_CHAR (l.line_id)
               AND                                    --to_char(p_line_id) AND
                   wias.process_activity = wpa.instance_id
               AND wpa.activity_item_type = 'OEOL'
               AND wpa.activity_name = 'SCHEDULING_ELIGIBLE'
               AND wias.activity_status = 'NOTIFIED';

        --Bug 17482674, do not return true if line eligible but not scheduled
        IF p_check_scheduled AND l_ssd IS NULL
        THEN
            RETURN FALSE;
        END IF;

        -- Return true since the record exists.

        -- Begin : ER 13114460

        OE_Holds_PUB.Check_Holds (
            p_api_version         => 1.0,
            p_init_msg_list       => FND_API.G_FALSE,
            p_commit              => FND_API.G_FALSE,
            p_validation_level    => FND_API.G_VALID_LEVEL_FULL,
            x_return_status       => l_out_return_status,
            x_msg_count           => l_msg_count,
            x_msg_data            => l_msg_data,
            p_line_id             => p_line_id,
            p_hold_id             => NULL,
            p_entity_code         => NULL,
            p_entity_id           => NULL,
            p_wf_item             => 'OEOL',
            p_wf_activity         => 'LINE_SCHEDULING',
            p_chk_act_hold_only   => 'Y',
            x_result_out          => l_result);

        IF l_debug_level > 0
        THEN
            oe_debug_pub.add (
                'AFTER CALLING CHECK HOLDS: ' || L_OUT_RETURN_STATUS,
                1);
        END IF;

        IF (l_out_return_status <> FND_API.G_RET_STS_SUCCESS)
        THEN
            IF l_out_return_status = FND_API.G_RET_STS_ERROR
            THEN
                RAISE FND_API.G_EXC_ERROR;
            ELSE
                RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
            END IF;
        END IF;

        IF (l_result = FND_API.G_TRUE)
        THEN
            RETURN FALSE;
        END IF;

        -- End : ER 13114460
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.add ('RETURNING FALSE 1 ', 1);
            END IF;

            RETURN FALSE;
        WHEN OTHERS
        THEN
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
    END Line_Eligible;

    -- ER18493998 Start
    PROCEDURE spawn_child_requests (p_commit_threshold IN NUMBER, p_num_instances IN NUMBER, p_sch_action IN VARCHAR2
                                    , p_request_id IN NUMBER, p_org_id IN NUMBER, x_return_status OUT NOCOPY VARCHAR2)
    IS
        l_new_request_id         NUMBER;
        l_request_num_lines      NUMBER;
        l_total_lines            NUMBER;
        l_lines_processed        NUMBER;
        l_request_number         NUMBER;
        l_req_data               VARCHAR2 (10);
        l_req_data_counter       NUMBER;
        j                        NUMBER;
        k                        NUMBER;
        l_group_number           NUMBER;
        l_lines_per_request      NUMBER;
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        x_child_req_tbl          oe_globals.selected_record_tbl;
        l_sch_mode               VARCHAR2 (30);
        l_next                   VARCHAR2 (1);        -- Bug 20273441: Issue 8
    BEGIN
        l_total_lines         := g_total_lines_cnt;
        l_lines_processed     := 0;
        l_request_number      := 0;
        l_lines_per_request   := 0;
        x_return_status       := fnd_api.g_ret_sts_success;

        IF l_debug_level > 0
        THEN
            oe_debug_pub.ADD ('Inside Spawn_Child_Requests', 1);
            oe_debug_pub.ADD ('p_num_instances : ' || p_num_instances, 1);
            oe_debug_pub.ADD ('p_sch_action : ' || p_sch_action, 1);
            oe_debug_pub.ADD ('p_request_id : ' || p_request_id, 1);
            oe_debug_pub.ADD ('p_org_id : ' || p_org_id, 1);
            oe_debug_pub.ADD ('l_total_lines : ' || l_total_lines, 1);
        END IF;

        IF p_sch_action = oe_schedule_util.oesch_act_reschedule
        THEN
            l_sch_mode   := 'BULK_RESCH_CHILD';
        ELSIF p_sch_action = oe_schedule_util.oesch_act_schedule
        THEN
            l_sch_mode   := 'BULK_SCH_CHILD';
        ELSIF p_sch_action = oe_schedule_util.oesch_act_unschedule
        THEN
            l_sch_mode   := 'BULK_UNSCH_CHILD';
        END IF;

        IF l_debug_level > 0
        THEN
            oe_debug_pub.ADD ('l_sch_mode is:' || l_sch_mode);
        /*
     FOR x IN 1 .. g_bulk_reschedule_table.COUNT
     LOOP
         oe_debug_pub.ADD ('g_bulk_reschedule_table.COUNT : ' || x);
         oe_debug_pub.ADD (g_bulk_reschedule_table (x).line_id);
         oe_debug_pub.ADD (g_bulk_reschedule_table (x).processing_order);
         oe_debug_pub.ADD (g_bulk_reschedule_table (x).group_number);
         oe_debug_pub.ADD (g_bulk_reschedule_table (x).top_model_line_id);
     END LOOP; */
        END IF;

        l_request_num_lines   := CEIL (l_total_lines / p_num_instances);

        IF l_debug_level > 0
        THEN
            oe_debug_pub.ADD (
                   'Lines in each request l_request_num_lines : '
                || l_request_num_lines,
                1);
        END IF;

        --Set the child request counters. Standard FND code
        l_req_data            := fnd_conc_global.request_data;

        IF (l_req_data IS NOT NULL)
        THEN
            l_req_data_counter   := TO_NUMBER (l_req_data);
            l_req_data_counter   := l_req_data_counter + 1;
        ELSE
            l_req_data_counter   := 1;
        END IF;

        j                     := g_bulk_reschedule_table.FIRST;

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
                fnd_request.submit_request ('ONT', 'SCHORD', 'Schedule Orders Child ' || l_request_number, NULL, TRUE, p_org_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, l_sch_mode, 'Y', 'N', 'Y', 'Y', NULL, NULL, NULL, NULL, NULL, 'Y', p_commit_threshold
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

            --one line is already pending, update child_Request_id for it
            -- commented for Bug 20273441 : Issue 8
            /*l_lines_per_request := l_lines_per_request + 1;
             g_bulk_reschedule_table (j).child_request_id := l_new_request_id;
             j := g_bulk_reschedule_table.NEXT (j);*/

            WHILE l_lines_per_request < l_request_num_lines AND j IS NOT NULL
            LOOP
                IF l_lines_per_request < l_request_num_lines
                THEN                                 -- Bug 20273441 : Issue 8
                    l_lines_per_request                            := l_lines_per_request + 1;
                    g_bulk_reschedule_table (j).child_request_id   :=
                        l_new_request_id;
                    l_next                                         := 'Y'; -- Bug 20273441 : Issue 8
                END IF;                              -- Bug 20273441 : Issue 8

                l_group_number   := g_bulk_reschedule_table (j).group_number;
                k                := j;

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
                        IF    g_bulk_reschedule_table (k).ship_set_id
                                  IS NOT NULL   -- Bug 20273441 : Issue 8 j> k
                           OR g_bulk_reschedule_table (k).arrival_set_id
                                  IS NOT NULL   -- Bug 20273441 : Issue 8 j> k
                           OR g_bulk_reschedule_table (k).top_model_line_id
                                  IS NOT NULL   -- Bug 20273441 : Issue 8 j> k
                        THEN
                            -- k := g_bulk_reschedule_table.NEXT (j); commented for Bug 20273441 : Issue 8

                            WHILE     k IS NOT NULL
                                  AND g_bulk_reschedule_table (k).group_number =
                                      l_group_number
                            LOOP
                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.ADD (
                                        'line is part of a group. query rest of the group as well and add here',
                                        1);
                                END IF;

                                IF g_bulk_reschedule_table (k).group_number =
                                   l_group_number
                                THEN
                                    g_bulk_reschedule_table (k).child_request_id   :=
                                        l_new_request_id;
                                    l_lines_per_request   :=
                                        l_lines_per_request + 1;
                                    j   := k;
                                    k   := g_bulk_reschedule_table.NEXT (k);
                                END IF;
                            END LOOP;
                        END IF;
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

        /*IF l_debug_level > 0 then
        FOR x IN g_bulk_reschedule_table.FIRST .. g_bulk_reschedule_table.LAST
        LOOP
    oe_debug_pub.ADD ('g_bulk_reschedule_table.count :' || x);
    oe_debug_pub.ADD (g_bulk_reschedule_table (x).child_request_id);
                  oe_debug_pub.ADD (g_bulk_reschedule_table (x).org_id);
    oe_debug_pub.ADD (g_bulk_reschedule_table (x).line_id);
    oe_debug_pub.ADD (g_bulk_reschedule_table (x).processing_order);
    oe_debug_pub.ADD (g_bulk_reschedule_table (x).group_number);
    oe_debug_pub.ADD (g_bulk_reschedule_table (x).ship_set_id);
           oe_debug_pub.ADD (g_bulk_reschedule_table (x).arrival_set_id);
    oe_debug_pub.ADD (g_bulk_reschedule_table (x).top_model_line_id);
    oe_debug_pub.ADD (g_bulk_reschedule_table (x).schedule_ship_date);
           oe_debug_pub.ADD (g_bulk_reschedule_table (x).schedule_arrival_date);
    oe_debug_pub.ADD (g_bulk_reschedule_table (x).request_date);
    oe_debug_pub.ADD (g_bulk_reschedule_table (x).ship_from_org_id);
       END LOOP;
    END IF; */

        --bulk insert
        FORALL x
            IN g_bulk_reschedule_table.FIRST .. g_bulk_reschedule_table.LAST
            INSERT INTO oe_bulk_schedule_temp (parent_request_id, child_request_id, org_id, line_id, processing_order, group_number, processed, ship_set_id, arrival_set_id, top_model_line_id, schedule_ship_date, schedule_arrival_date, request_date, ship_from_org_id, attribute1, attribute2, attribute3, attribute4, attribute5, date1, date2
                                               , date3, date4, date5)
                     VALUES (
                                p_request_id,
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


        --Pause the parent request
        IF x_child_req_tbl.COUNT > 0
        THEN
            fnd_conc_global.set_req_globals (
                conc_status    => 'PAUSED',
                request_data   => TO_CHAR (l_req_data_counter));
        END IF;

        IF l_debug_level > 0
        THEN
            oe_debug_pub.ADD (
                   'Exiting Spawn_Child_Requests, number of child requests: '
                || l_request_number,
                1);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                    'Error in Spawn_Child_Requests: ' || SQLERRM,
                    1);
            END IF;

            x_return_status   := fnd_api.g_ret_sts_error;
    END spawn_child_requests;

    PROCEDURE process_bulk (p_selected_tbl IN oe_globals.selected_record_tbl, p_sch_action IN VARCHAR2, x_return_status OUT NOCOPY /* file.sql.39 change */
                                                                                                                                  VARCHAR2)
    IS
        l_atp_tbl                oe_atp.atp_tbl_type;
        l_return_status          VARCHAR2 (1);
        l_msg_count              NUMBER;
        l_msg_data               VARCHAR2 (2000) := NULL;
        l_control_rec            oe_globals.control_rec_type;
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        r_line_tbl               oe_order_pub.line_tbl_type;  -- suneela added
        l_line_rec               oe_order_pub.line_rec_type;         --suneela
        v_line_tbl               oe_order_pub.line_tbl_type;  -- suneela added
        k                        NUMBER := 0;
        l                        NUMBER := 0;
        l_group_number           NUMBER := 0;
    BEGIN
        IF l_debug_level > 0
        THEN
            oe_debug_pub.ADD (
                   'Inside Process_Bulk(), calling Schedule_Multi_lines:'
                || p_sch_action);
        END IF;

        -- SAVEPOINT process_bulk_sp; --Bug 21132131
        SAVEPOINT Schedule_Line;                       -- Bug 21345576 Issue 5

        IF p_sch_action = 'SCHEDULE'
        THEN
            oe_group_sch_util.reschedule_multi_lines           -- Bug 20743728
                                                     (
                p_selected_line_tbl   => p_selected_tbl,
                p_line_count          => p_selected_tbl.COUNT,
                p_sch_action          => 'BULK_SCHEDULE',
                x_atp_tbl             => l_atp_tbl,
                x_return_status       => l_return_status,
                x_msg_count           => l_msg_count,
                x_msg_data            => l_msg_data);
        ELSIF p_sch_action = 'UNSCHEDULE'
        THEN
            oe_group_sch_util.reschedule_multi_lines   -- Bug 21345576 Issue 1
                                                     (
                p_selected_line_tbl   => p_selected_tbl,
                p_line_count          => p_selected_tbl.COUNT,
                p_sch_action          => 'BULK_UNSCHEDULE',
                x_atp_tbl             => l_atp_tbl,
                x_return_status       => l_return_status,
                x_msg_count           => l_msg_count,
                x_msg_data            => l_msg_data);
        ELSIF p_sch_action = 'RESCHEDULE'
        THEN
            oe_group_sch_util.reschedule_multi_lines (
                p_selected_line_tbl   => p_selected_tbl,
                p_line_count          => p_selected_tbl.COUNT,
                p_sch_action          => 'BULK_RESCHEDULE',
                x_atp_tbl             => l_atp_tbl,
                x_return_status       => l_return_status,
                x_msg_count           => l_msg_count,
                x_msg_data            => l_msg_data);
        END IF;


        IF l_debug_level > 0
        THEN
            oe_debug_pub.ADD (
                   'Return Status  After Schedule_Multi_lines '
                || l_return_status,
                1);
        END IF;

        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            BEGIN
                IF l_debug_level > 0
                THEN
                    oe_debug_pub.ADD ('GOING TO EXECUTE DELAYED REQUESTS ',
                                      2);
                END IF;

                oe_delayed_requests_pvt.process_delayed_requests (
                    x_return_status => l_return_status);

                IF l_return_status IN
                       (fnd_api.g_ret_sts_error, fnd_api.g_ret_sts_unexp_error)
                THEN
                    IF l_debug_level > 0
                    THEN
                        oe_debug_pub.ADD ('#### There is a FAILURE #### ');
                    END IF;

                    oe_delayed_requests_pvt.clear_request (l_return_status);
                    --Call MRP rollback for all lines

                    --commented as call_mrp_rollback is called in mrp_cleanup Bug 21345576 Issue 5 : START
                    --oe_schedule_util.call_mrp_rollback (l_return_status);

                    --ROLLBACK;
                    --ROLLBACK TO process_bulk_sp;  --Bug 21132131
                    mrp_cleanup ();

                    -- Bug 21345576 Issue 5 : END

                    IF l_debug_level > 0
                    THEN
                        oe_debug_pub.ADD (
                               'AFTER CLEARING DELAYED REQUESTS: '
                            || l_return_status,
                            2);
                    END IF;

                    BEGIN
                        IF l_debug_level > 0
                        THEN
                            oe_debug_pub.ADD (
                                'DELETING oe_schedule_lines_temp ',
                                1);
                        END IF;

                        DELETE FROM oe_schedule_lines_temp;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    IF l_debug_level > 0
                    THEN
                        oe_debug_pub.ADD (
                               'IN WHEN OTHERS of Process_Bulk, Error:'
                            || SQLERRM,
                            2);
                    END IF;

                    oe_delayed_requests_pvt.clear_request (l_return_status);

                    IF l_debug_level > 0
                    THEN
                        oe_debug_pub.ADD (
                               'IN WHEN OTHERS clear_request '
                            || l_return_status,
                            2);
                    END IF;
            END;
        ELSE                                                     --Not success
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                    'Call to Scehdule_multi_line not success, rollback',
                    1);
            END IF;

            oe_delayed_requests_pvt.clear_request (l_return_status);

            -- commented and added for bug 21345576 Issue 5 : START
            --Call MRP rollback for all lines
            -- oe_schedule_util.call_mrp_rollback (l_return_status);
            --ROLLBACK;
            --ROLLBACK TO process_bulk_sp;  --Bug 21132131
            mrp_cleanup ();
        -- bug 21345576 Issue 5 : END
        END IF;
    END process_bulk;

    -- ER18493998 End

    /*-----------------------------------------------------------------
    PROCEDURE  : Request
    DESCRIPTION: Schedule Orders Concurrent Request

    Change log:
    Bug 8813015: Parameter p_picked is added to allow exclusion of
                 pick released lines.
    -----------------------------------------------------------------*/
    PROCEDURE Request (ERRBUF OUT NOCOPY VARCHAR2, RETCODE OUT NOCOPY VARCHAR2, /* Moac */
                                                                                p_org_id IN NUMBER, p_order_number_low IN NUMBER, p_order_number_high IN NUMBER, p_request_date_low IN VARCHAR2, p_request_date_high IN VARCHAR2, p_customer_po_number IN VARCHAR2, p_ship_to_location IN VARCHAR2, p_order_type IN VARCHAR2, p_order_source IN VARCHAR2, p_brand IN VARCHAR2, p_customer IN VARCHAR2, p_ordered_date_low IN VARCHAR2, p_ordered_date_high IN VARCHAR2, p_warehouse IN VARCHAR2, p_item IN VARCHAR2, p_demand_class IN VARCHAR2, p_planning_priority IN VARCHAR2, p_shipment_priority IN VARCHAR2, p_line_type IN VARCHAR2, p_line_request_date_low IN VARCHAR2, p_line_request_date_high IN VARCHAR2, p_line_ship_to_location IN VARCHAR2, p_sch_ship_date_low IN VARCHAR2, p_sch_ship_date_high IN VARCHAR2, p_sch_arrival_date_low IN VARCHAR2, p_sch_arrival_date_high IN VARCHAR2, p_booked IN VARCHAR2, p_sch_mode IN VARCHAR2, p_req_date_condition IN VARCHAR2, p_dummy4 IN VARCHAR2 DEFAULT NULL, -- ER18493998
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           p_bulk_processing IN VARCHAR2 DEFAULT 'N', -- ER18493998
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      p_dummy1 IN VARCHAR2, p_dummy2 IN VARCHAR2, p_apply_warehouse IN VARCHAR2, p_apply_sch_date IN VARCHAR2, p_order_by_first IN VARCHAR2, p_order_by_sec IN VARCHAR2, p_picked IN VARCHAR2 DEFAULT NULL, --Bug 8813015
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            p_dummy3 IN VARCHAR2 DEFAULT NULL, -- 12639770
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               p_commit_threshold IN NUMBER DEFAULT NULL
                       ,                                           -- 12639770
                         p_num_instances IN NUMBER DEFAULT NULL  -- ER18493998
                                                               )
    IS
        l_apply_sch_date           DATE;
        l_arrival_set_id           NUMBER;
        l_ato_line_id              NUMBER;
        l_atp_tbl                  OE_ATP.Atp_Tbl_Type;
        l_booked_flag              VARCHAR2 (1);
        l_control_rec              OE_GLOBALS.Control_Rec_Type;
        l_cursor_id                INTEGER;
        l_debug_level     CONSTANT NUMBER := oe_debug_pub.g_debug_level;
        l_found                    BOOLEAN;
        l_header_id                NUMBER;
        l_init_msg_list            VARCHAR2 (1) := FND_API.G_FALSE;
        l_item_type_code           VARCHAR2 (30);
        l_line_id                  NUMBER;
        l_line_rec                 OE_ORDER_PUB.Line_Rec_Type;
        l_line_request_date_high   DATE;
        l_line_request_date_low    DATE;
        l_line_tbl                 OE_ORDER_PUB.Line_Tbl_Type;
        l_msg_count                NUMBER;
        l_msg_data                 VARCHAR2 (2000) := NULL;
        l_old_line_tbl             OE_ORDER_PUB.Line_Tbl_Type;
        l_order_date_type_code     VARCHAR2 (30);
        l_ordered_date_high        DATE;
        l_ordered_date_low         DATE;
        l_process_order            BOOLEAN := FALSE;
        l_rec_failure              NUMBER := 0;
        l_rec_processed            NUMBER := 0;
        l_rec_success              NUMBER := 0;
        l_request_date             DATE;
        l_request_date_high        DATE;
        l_request_date_low         DATE;
        l_request_id               VARCHAR2 (50);
        l_return_status            VARCHAR2 (1);
        l_retval                   INTEGER;
        l_sch_arrival_date_high    DATE;
        l_sch_arrival_date_low     DATE;
        l_sch_ship_date_high       DATE;
        l_sch_ship_date_low        DATE;
        l_schedule_status_code     VARCHAR2 (30);
        l_ship_from_org_id         NUMBER;
        l_ship_set_id              NUMBER;
        l_smc_flag                 VARCHAR2 (1);
        l_stmt                     VARCHAR2 (2000);
        l_temp_flag                BOOLEAN;      -- temp variable (re-usable).
        l_temp_line_id             NUMBER;
        l_temp_num                 NUMBER;       -- temp variable (re-usable).
        l_top_model_line_id        NUMBER;
        l_link_to_line_id          NUMBER;
        l_locked_line_id           NUMBER;                           --8731703
        -- Moac
        l_single_org               BOOLEAN := FALSE;
        l_old_org_id               NUMBER := -99;
        l_org_id                   NUMBER;
        l_selected_line_tbl        OE_GLOBALS.Selected_Record_Tbl; -- R12.MOAC
        l_failure                  BOOLEAN := FALSE;
        l_index                    NUMBER;
        l_line_count               NUMBER := 0;                    -- 12639770
        l_prg_start_date           DATE := SYSDATE;                -- 12639770

        -- ER18493998 Start
        l_total_lines_cnt          NUMBER := 0;
        l_line_index_ch            NUMBER := 0;
        l_req_data                 VARCHAR2 (10);
        l_result                   VARCHAR2 (30);
        l_bulk_reschedule_table    bulk_reschedule_table;
        l_line_index               NUMBER := 0;               -- suneela added
        l_processing_order         NUMBER;
        l_group_number             NUMBER;
        l_old_group_number         NUMBER;                      --Bug 21132131
        l_ssd                      DATE;
        l_sad                      DATE;
        l_sch_action               VARCHAR2 (20);
        r_line_tbl                 oe_order_pub.line_tbl_type;
        l_model_remnant_flag       VARCHAR2 (1);               -- bug 21345576

        l_rsv_return_status        VARCHAR2 (1);
        l_rsv_msg_count            NUMBER;
        l_rsv_msg_data             VARCHAR2 (2000) := NULL;


        CURSOR c_get_child_lines (c_request_id NUMBER)
        IS
              SELECT line_id, org_id, processing_order,
                     group_number, ship_from_org_id, schedule_ship_date,
                     schedule_arrival_date
                FROM oe_bulk_schedule_temp
               WHERE child_request_id = c_request_id
            ORDER BY processing_order;

        -- ER18493998 End

        -- Moac. Changed the below cursor logic to also join to oe_order_lines for OU.
        CURSOR wf_item IS
              SELECT item_key, l.org_id, wias.process_activity --added process_activity for bug 13542899
                FROM wf_item_activity_statuses wias, wf_process_activities wpa, oe_order_lines l
               WHERE     wias.item_type = 'OEOL'
                     AND wias.process_activity = wpa.instance_id
                     AND wpa.activity_item_type = 'OEOL'
                     AND wpa.activity_name = 'SCHEDULING_ELIGIBLE'
                     AND wias.activity_status = 'NOTIFIED'
                     AND wias.item_key = l.line_id
                     AND wias.begin_date < l_prg_start_date         --13426757
            ORDER BY l.org_id;

        CURSOR progress_pto IS
            SELECT line_id
              FROM oe_order_lines_all
             WHERE     header_id = l_header_id
                   AND top_model_line_id = l_line_id
                   AND item_type_code IN ('MODEL', 'KIT', 'CLASS',
                                          'OPTION')
                   AND ((ato_line_id IS NOT NULL AND ato_line_id = line_id) OR ato_line_id IS NULL)
                   AND open_flag = 'Y';

        -- 13426757
        TYPE wf_item_type IS TABLE OF wf_item%ROWTYPE;

        l_wf_item_rec              wf_item_type;
        --Bug 17543200, increase to 1000 from 100
        l_commit_threshold         NUMBER := NVL (p_commit_threshold, 1000);

        --ER 13615316
        l_set_line_tbl             OE_ORDER_PUB.line_tbl_type;
    BEGIN
        --Bug#4220950
        ERRBUF            := 'Schedule Orders Request completed successfully';
        RETCODE           := 0;

        -- ER18493998 Start
        l_req_data        := fnd_conc_global.request_data;

        IF l_debug_level > 0
        THEN
            OE_DEBUG_PUB.Add ('l_req_data :' || l_req_data, 1);
        END IF;

        --When a parent goes to paused state and wakes up, it resubmits itself. Meaning
        --during resubmit we should not process the request at all.
        IF (l_req_data IS NOT NULL)
        THEN                                              --means resubmitting
            --GOTO END_REQUEST;
            --We can also return from here, no need of GOTO statement above
            ERRBUF    := 'Schedule Orders Request resubmitted. Exit.';
            RETCODE   := 0;
            RETURN;
        END IF;

        -- ER18493998 End

        -- Moac Start
        IF MO_GLOBAL.get_access_mode = 'S'
        THEN
            l_single_org   := TRUE;
        ELSIF p_org_id IS NOT NULL
        THEN
            l_single_org   := TRUE;
            MO_GLOBAL.set_policy_context (p_access_mode   => 'S',
                                          p_org_id        => p_org_id);
        END IF;

        -- Moac End.

        -- Turning debug on for testing purpose.
        fnd_file.put_line (FND_FILE.LOG, 'Parameters:');
        fnd_file.put_line (FND_FILE.LOG,
                           '    order_number_low =  ' || p_order_number_low);
        fnd_file.put_line (FND_FILE.LOG,
                           '    order_number_high = ' || p_order_number_high);
        fnd_file.put_line (FND_FILE.LOG,
                           '    request_date_low = ' || p_request_date_low);
        fnd_file.put_line (FND_FILE.LOG,
                           '    request_date_high = ' || p_request_date_high);
        fnd_file.put_line (
            FND_FILE.LOG,
            '    customer_po_number = ' || p_customer_po_number);
        fnd_file.put_line (FND_FILE.LOG,
                           '    ship_to_location = ' || p_ship_to_location);
        fnd_file.put_line (FND_FILE.LOG, '    order_type = ' || p_order_type);
        fnd_file.put_line (FND_FILE.LOG,
                           '    order_source = ' || p_order_source);
        fnd_file.put_line (FND_FILE.LOG, '    brand = ' || p_brand);
        fnd_file.put_line (FND_FILE.LOG, '    customer = ' || p_customer);
        fnd_file.put_line (FND_FILE.LOG, '    item = ' || p_item);
        fnd_file.put_line (FND_FILE.LOG,
                           '    ordered_date_low = ' || p_ordered_date_low);
        fnd_file.put_line (FND_FILE.LOG,
                           '    ordered_date_high = ' || p_ordered_date_high);
        fnd_file.put_line (FND_FILE.LOG, '    warehouse = ' || p_warehouse);
        fnd_file.put_line (FND_FILE.LOG,
                           '    demand_class = ' || p_demand_class);
        fnd_file.put_line (FND_FILE.LOG,
                           '    planning_priority = ' || p_planning_priority);
        fnd_file.put_line (FND_FILE.LOG,
                           '    shipment_priority = ' || p_shipment_priority);
        fnd_file.put_line (FND_FILE.LOG, '    line_type = ' || p_line_type);
        fnd_file.put_line (
            FND_FILE.LOG,
            '    line_request_date_low = ' || p_line_request_date_low);
        fnd_file.put_line (
            FND_FILE.LOG,
            '    line_request_date_high = ' || p_line_request_date_high);
        fnd_file.put_line (
            FND_FILE.LOG,
            '    line_ship_to_location = ' || p_line_ship_to_location);
        fnd_file.put_line (FND_FILE.LOG,
                           '    sch_ship_date_low = ' || p_sch_ship_date_low);
        fnd_file.put_line (
            FND_FILE.LOG,
            '    sch_ship_date_high = ' || p_sch_ship_date_high);
        fnd_file.put_line (
            FND_FILE.LOG,
            '    sch_arrival_date_low = ' || p_sch_arrival_date_low);
        fnd_file.put_line (
            FND_FILE.LOG,
            '    sch_arrival_date_high = ' || p_sch_arrival_date_high);
        fnd_file.put_line (FND_FILE.LOG, '    booked = ' || p_booked);
        fnd_file.put_line (FND_FILE.LOG, '    sch_mode = ' || p_sch_mode);
        fnd_file.put_line (
            FND_FILE.LOG,
            '    Order Line RD equals SSD value = ' || p_req_date_condition);
        fnd_file.put_line (FND_FILE.LOG,
                           '    bulk_processing = ' || p_bulk_processing); -- ER18493998
        fnd_file.put_line (FND_FILE.LOG, '    dummy1 = ' || p_dummy1);
        fnd_file.put_line (FND_FILE.LOG,
                           '    apply_warehouse = ' || p_apply_warehouse);
        fnd_file.put_line (FND_FILE.LOG,
                           '    apply_sch_date = ' || p_apply_sch_date);
        fnd_file.put_line (FND_FILE.LOG,
                           '    order_by_first = ' || p_order_by_first);
        fnd_file.put_line (FND_FILE.LOG,
                           '    order_by_sec = ' || p_order_by_sec);
        fnd_file.put_line (FND_FILE.LOG,
                           '    number_instances = ' || p_num_instances); -- ER18493998

        --Bug 8813015: start
        fnd_file.put_line (FND_FILE.LOG, '    picked = ' || p_picked);
        --Bug 8813015: end
        --12639770
        fnd_file.put_line (FND_FILE.LOG,
                           '    Threshold = ' || p_commit_threshold);

        FND_PROFILE.Get (NAME => 'CONC_REQUEST_ID', VAL => l_request_id);
        OE_MSG_PUB.Initialize;  -- Initializing message pub to clear messages.

        -- ER 13114460
        /* Set the global if p_sch_mode is LINE_ELIGIBLE or NULL */
        IF NVL (p_sch_mode, 'LINE_ELIGIBLE') = 'LINE_ELIGIBLE'
        THEN
            G_CHECKED_FOR_HOLDS   := 'Y';
        END IF;

        IF     p_sch_mode NOT IN ('SCHEDULE', 'RESCHEDULE')
           AND (p_apply_sch_date IS NOT NULL OR p_apply_warehouse IS NOT NULL)
        THEN
            Fnd_Message.set_name ('ONT', 'ONT_SCH_INVALID_MODE_ATTRB');
            Oe_Msg_Pub.Add;
            OE_MSG_PUB.Save_Messages (p_request_id => l_request_id);
            l_msg_data   :=
                Fnd_Message.get_string ('ONT', 'ONT_SCH_INVALID_MODE_ATTRB');
            FND_FILE.Put_Line (FND_FILE.LOG, l_msg_data);
            ERRBUF    := 'ONT_SCH_INVALID_MODE_ATTRB';

            IF l_debug_level > 0
            THEN
                OE_DEBUG_PUB.Add (
                    'Error : Schedule date supplied for wrong mode.',
                    1);
            END IF;

            RETCODE   := 2;
            RETURN;
        END IF;

        -- Convert dates passed as varchar2 parameters to date variables.
        SELECT fnd_date.canonical_to_date (p_request_date_low), fnd_date.canonical_to_date (p_request_date_high), fnd_date.canonical_to_date (p_ordered_date_low),
               fnd_date.canonical_to_date (p_ordered_date_high), fnd_date.canonical_to_date (p_line_request_date_low), fnd_date.canonical_to_date (p_line_request_date_high),
               fnd_date.canonical_to_date (p_sch_ship_date_low), fnd_date.canonical_to_date (p_sch_ship_date_high), fnd_date.canonical_to_date (p_sch_arrival_date_low),
               fnd_date.canonical_to_date (p_sch_arrival_date_high)
          --  fnd_date.canonical_to_date(p_apply_sch_date)
          INTO l_request_date_low, l_request_date_high, l_ordered_date_low, l_ordered_date_high,
                                 l_line_request_date_low, l_line_request_date_high, l_sch_ship_date_low,
                                 l_sch_ship_date_high, l_sch_arrival_date_low, l_sch_arrival_date_high
          --  l_apply_sch_date
          FROM DUAL;

        SELECT fnd_date.chardt_to_date (p_apply_sch_date)
          INTO l_apply_sch_date
          FROM DUAL;

        IF l_debug_level > 0
        THEN
            OE_DEBUG_PUB.Add ('Schedule date' || l_apply_sch_date, 1);
        END IF;

        /* When user does not specifiy any parameters, we drive the scheduling
         * through workflow. Pick up all the lines which are schedule eligible
         * and notified status, call wf_engine to complete the activity.
         * If value is passed through any of the parameters, then get the header and
         * line records and call wf_engine.
         */
        IF     p_order_number_low IS NULL
           AND p_order_number_high IS NULL
           AND p_request_date_low IS NULL
           AND p_request_date_high IS NULL
           AND p_customer_po_number IS NULL
           AND p_ship_to_location IS NULL
           AND p_order_type IS NULL
           AND p_order_source IS NULL
           AND p_brand IS NULL
           AND p_customer IS NULL
           AND p_item IS NULL
           AND p_ordered_date_low IS NULL
           AND p_ordered_date_high IS NULL
           AND p_warehouse IS NULL
           AND p_demand_class IS NULL
           AND p_planning_priority IS NULL
           AND p_shipment_priority IS NULL
           AND p_line_type IS NULL
           AND p_line_request_date_low IS NULL
           AND p_line_request_date_high IS NULL
           AND p_line_ship_to_location IS NULL
           AND p_sch_ship_date_low IS NULL
           AND p_sch_ship_date_high IS NULL
           AND p_sch_arrival_date_low IS NULL
           AND p_sch_arrival_date_high IS NULL
           AND NVL (p_sch_mode, 'LINE_ELIGIBLE') = 'LINE_ELIGIBLE'
           AND                                                      --13426757
               NVL (p_booked, 'Y') = 'Y'
           AND NVL (p_picked, 'Y') = 'Y'                         --Bug 8813015
        THEN
            --13426757
            -- Have bulk collect with limit as commit threshold
            -- Commit and close the cursor after each set execution
            BEGIN
                IF l_debug_level > 0
                THEN
                    oe_debug_pub.add (
                        'commit_threshold ' || l_commit_threshold,
                        1);
                END IF;

                --LOOP
                OPEN wf_item;

                LOOP                                               -- 16467034
                    FETCH wf_item
                        BULK COLLECT INTO l_wf_item_rec
                        LIMIT l_commit_threshold;

                    EXIT WHEN l_wf_item_rec.COUNT = 0;

                    FOR k IN 1 .. l_wf_item_rec.COUNT
                    LOOP
                        IF l_debug_level > 0
                        THEN
                            oe_debug_pub.add (
                                   '***** 1. Processing item key '
                                || l_wf_item_rec (k).item_key
                                || ' *****',
                                1);
                        END IF;

                        -- Moac Start
                        IF     NOT l_single_org
                           AND l_wf_item_rec (k).org_id <> l_old_org_id
                        THEN
                            l_old_org_id   := l_wf_item_rec (k).org_id;
                            MO_GLOBAL.set_policy_context (
                                p_access_mode   => 'S',
                                p_org_id        => l_wf_item_rec (k).org_id);
                        END IF;

                        -- Moac End

                        -- Need to check whether still line is eligible for processing
                        IF Line_Eligible (
                               p_line_id   =>
                                   TO_NUMBER (l_wf_item_rec (K).ITEM_KEY))
                        THEN
                            --8448911
                            g_conc_program      := 'Y';
                            g_recorded          := 'N';

                            IF l_debug_level > 0
                            THEN
                                oe_debug_pub.add (
                                       'COMPLETING ACTIVITY FOR : '
                                    || l_wf_item_rec (K).ITEM_KEY,
                                    1);
                            END IF;

                            g_process_records   := 0;
                            g_failed_records    := 0;

                            -- 8606874
                            --Lock the line first
                            BEGIN
                                    SELECT line_id
                                      INTO l_locked_line_id
                                      FROM oe_order_lines_all
                                     WHERE line_id =
                                           TO_NUMBER (l_wf_item_rec (K).ITEM_KEY)
                                FOR UPDATE NOWAIT;

                                wf_engine.CompleteActivityInternalName (
                                    'OEOL',
                                    l_wf_item_rec (k).item_key,
                                    'SCHEDULING_ELIGIBLE',
                                    'COMPLETE',
                                    TRUE);                         -- 15870313
                            EXCEPTION
                                WHEN APP_EXCEPTIONS.RECORD_LOCK_EXCEPTION
                                THEN
                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.add (
                                               'OEXCSCHB.pls: unable to lock the line:'
                                            || l_wf_item_rec (K).ITEM_KEY,
                                            1);
                                    END IF;

                                    wf_item_activity_status.create_status (
                                        'OEOL',
                                        l_wf_item_rec (K).ITEM_KEY,
                                        l_wf_item_rec (K).process_activity,
                                        'NOTIFIED',
                                        NULL,
                                        SYSDATE,
                                        NULL);                      --13542899
                                WHEN OTHERS
                                THEN
                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.add (
                                               '*** 1. Error - '
                                            || SUBSTR (SQLERRM, 1, 200),
                                            1);
                                    END IF;
                            END;

                            /* --8448911
                            OE_MSG_PUB.Count_And_Get
                            ( p_count     => l_msg_count,
                              p_data      => l_msg_data);

                            FOR I in 1..l_msg_count LOOP
                               l_msg_data := OE_MSG_PUB.Get(I,'F');

                              -- Write Messages in the log file
                              fnd_file.put_line(FND_FILE.LOG, l_msg_data);

                            END LOOP;
                         */
                            --5166476

                            --IF g_failed_records > 0 THEN
                            --IF OE_SCH_CONC_REQUESTS.oe_line_status_tbl.EXISTS(l_wf_item_rec(k).item_key) AND
                            --OE_SCH_CONC_REQUESTS.oe_line_status_tbl(l_wf_item_rec(k).item_key)= 'N' THEN
                            --Added as per bug 21079696
                            IF     OE_SCH_CONC_REQUESTS.oe_line_status_tbl.EXISTS (
                                       MOD (l_wf_item_rec (k).item_key,
                                            OE_GLOBALS.G_BINARY_LIMIT))
                               AND OE_SCH_CONC_REQUESTS.oe_line_status_tbl (
                                       MOD (l_wf_item_rec (k).item_key,
                                            OE_GLOBALS.G_BINARY_LIMIT)) =
                                   'N'
                            THEN
                                l_failure   := TRUE;
                            END IF;

                            IF l_debug_level > 0
                            THEN
                                oe_debug_pub.add (
                                       'R1 PROCESSED: '
                                    || l_rec_processed
                                    || ' FAILED: '
                                    || l_rec_failure,
                                    1);
                            END IF;
                        -- Moac
                        END IF;
                    END LOOP;

                    --CLOSE wf_item;
                    -- ER18493998 - Check for reservation validity before commit
                    OE_SCHEDULE_UTIL.Post_Forms_Commit (l_rsv_return_status,
                                                        l_rsv_msg_count,
                                                        l_rsv_msg_data);
                    COMMIT;
                END LOOP;

                CLOSE wf_item;                                      --16467034
            END;
        -- ER18493998 Start
        -- For child requests
        ELSIF p_sch_mode IN
                  ('BULK_SCH_CHILD', 'BULK_RESCH_CHILD', 'BULK_UNSCH_CHILD')
        THEN
            IF p_sch_mode = 'BULK_SCH_CHILD'
            THEN
                l_sch_action   := 'SCHEDULE';
            ELSIF p_sch_mode = 'BULK_RESCH_CHILD'
            THEN
                l_sch_action   := 'RESCHEDULE';
            ELSIF p_sch_mode = 'BULK_UNSCH_CHILD'
            THEN
                l_sch_action   := 'UNSCHEDULE';
            END IF;

            --Set the globals
            g_conc_program   := 'Y';
            g_recorded       := 'N';
            g_request_id     := TO_NUMBER (l_request_id);

            --OE_SCH_CONC_REQUESTS.G_COMMIT_THRESHOLD := l_commit_threshold;

            --Open the cursor to get the child lines.
            OPEN c_get_child_lines (TO_NUMBER (l_request_id));

            LOOP
                FETCH c_get_child_lines
                    INTO l_line_id, l_org_id, l_processing_order, l_group_number,
                         l_ship_from_org_id, l_ssd, l_sad;

                EXIT WHEN c_get_child_lines%NOTFOUND;

                --IF NOT l_single_org AND l_org_id <> l_old_org_id --Bug 21132131, Use the below if
                IF    (NOT l_single_org AND l_org_id <> l_old_org_id)
                   OR (p_commit_threshold IS NOT NULL AND l_line_index >= p_commit_threshold AND l_group_number <> NVL (l_old_group_number, l_group_number))
                THEN
                    l_old_org_id   := l_org_id;

                    -- Send the lines for processing as org changed.
                    IF l_selected_line_tbl.COUNT > 0
                    THEN
                        process_bulk (p_selected_tbl    => l_selected_line_tbl,
                                      p_sch_action      => l_sch_action,
                                      x_return_status   => l_return_status);
                        l_selected_line_tbl.DELETE;
                        l_line_index   := 0;
                        -- Check for reservation validity before commit
                        OE_SCHEDULE_UTIL.Post_Forms_Commit (
                            l_rsv_return_status,
                            l_rsv_msg_count,
                            l_rsv_msg_data);
                        COMMIT; --should we addd commit to inside process_bulk
                    END IF;

                    mo_global.set_policy_context (p_access_mode   => 'S',
                                                  p_org_id        => l_org_id);
                END IF;

                l_old_group_number                          := l_group_number; --Bug 21132131
                l_line_index                                := l_line_index + 1;
                l_selected_line_tbl (l_line_index).id1      := l_line_id;
                l_selected_line_tbl (l_line_index).id2      :=
                    l_ship_from_org_id;
                l_selected_line_tbl (l_line_index).id3      := l_group_number;
                l_selected_line_tbl (l_line_index).date1    := l_ssd;
                l_selected_line_tbl (l_line_index).date2    := l_sad;
                l_selected_line_tbl (l_line_index).org_id   := l_org_id;
            /*--Bug 21132131
         IF     p_commit_threshold IS NOT NULL
            AND l_line_index = p_commit_threshold
         THEN
            process_bulk (p_selected_tbl       => l_selected_line_tbl,
                          p_sch_action         => l_sch_action,
            x_return_status      => l_return_status
           );

           l_selected_line_tbl.DELETE;
           l_line_index := 0;
           -- Check for reservation validity before commit
           OE_SCHEDULE_UTIL.Post_Forms_Commit(l_rsv_return_status, l_rsv_msg_count, l_rsv_msg_data);
           COMMIT;
          END IF; */
            --Bug 21132131
            END LOOP;

            CLOSE c_get_child_lines;

            --See if there are pending records still
            IF l_selected_line_tbl.COUNT > 0
            THEN
                process_bulk (p_selected_tbl    => l_selected_line_tbl,
                              p_sch_action      => l_sch_action,
                              x_return_status   => l_return_status);
                l_selected_line_tbl.DELETE;
            END IF;
        -- ER18493998 End
        ELSE                                       -- Some parameter is passed
            -- Open cursor.
            l_cursor_id               := DBMS_SQL.OPEN_CURSOR;

            -- Building the dynamic query based on parameters passed.
            -- Moac Changed below cursor to use oe_order_headers_all
            /*Start  MOAC_SQL_CHANGE */
            l_stmt                    := 'SELECT ';

            --BUG 13901213
            IF     p_order_number_low IS NOT NULL
               AND p_order_number_high IS NOT NULL
            THEN
                l_stmt   := l_stmt || ' /*+ INDEX(H OE_ORDER_HEADERS_U2) */ ';
            END IF;

            l_stmt                    := l_stmt || '  H.header_id, L.Line_id, L.org_id ';
            --l_stmt := l_stmt || ' ,L.ship_set_id, L.arrival_set_id, L.top_model_line_id ' ; -- ER18493998, Bug 21132131, use the below instead
            l_stmt                    :=
                   l_stmt
                || ' ,L.ship_set_id, L.arrival_set_id, L.top_model_line_id, '
                || ' L.booked_flag, L.request_date, L.ship_from_org_id, L.ato_line_id, '
                || ' L.link_to_line_id, L.ship_model_complete_flag, L.item_type_code, '
                || ' L.schedule_status_code, NVL(h.order_date_type_code,''SHIP''), '
                || ' L.model_remnant_flag ';           -- Bug 21345576 Issue 4

            --BUG 13901213 End

            IF NVL (p_sch_mode, 'LINE_ELIGIBLE') = 'LINE_ELIGIBLE'
            THEN
                l_stmt   :=
                       l_stmt
                    || 'FROM oe_order_headers_all H, oe_order_lines L, '
                    || ' wf_item_activity_statuses wias, wf_process_activities wpa ';
            ELSE
                l_stmt   :=
                       l_stmt
                    || 'FROM oe_order_headers_all H, oe_order_lines L ';
            END IF;

            l_stmt                    :=
                   l_stmt
                || 'WHERE H.header_id = L.header_id '
                || 'AND H.org_id = L.org_id '
                || 'AND nvl(H.transaction_phase_code,''F'')=''F''' -- Bug 8517633
                || 'AND H.open_flag = ''Y'''
                || ' AND L.open_flag = ''Y'''
                --9098824: Start
                || ' AND L.line_category_code <> '
                || '''RETURN'''
                || ' AND L.item_type_code <> '
                || '''SERVICE'''
                || ' AND NVL(L.subscription_enable_flag,''N'')=''N''' -- sol_ord_er #16014165
                || ' AND L.source_type_code <> '
                || '''EXTERNAL'''--9098824: End
                                 ;

            /*End  MOAC_SQL_CHANGE */

            -- Building where clause.
            -- Moac Start
            IF p_org_id IS NOT NULL
            THEN
                l_stmt   := l_stmt || ' AND L.org_id = :org_id';
            END IF;

            -- Moac End

            IF p_order_number_low IS NOT NULL
            THEN
                l_stmt   :=
                    l_stmt || ' AND H.order_number >= :order_number_low';
            END IF;

            IF p_order_number_high IS NOT NULL
            THEN
                l_stmt   :=
                    l_stmt || ' AND H.order_number <= :order_number_high';
            END IF;

            IF p_request_date_low IS NOT NULL
            THEN
                l_stmt   :=
                    l_stmt || ' AND H.request_date >= :request_date_low';
            END IF;

            IF p_request_date_high IS NOT NULL
            THEN
                l_stmt   :=
                    l_stmt || ' AND H.request_date <= :request_date_high';
            END IF;

            IF p_customer_po_number IS NOT NULL
            THEN
                l_stmt   :=
                    l_stmt || ' AND H.cust_po_number = :customer_po_number';
            END IF;

            IF p_ship_to_location IS NOT NULL
            THEN
                l_stmt   :=
                    l_stmt || ' AND H.ship_to_org_id = :ship_to_location';
            END IF;

            IF p_order_type IS NOT NULL
            THEN
                l_stmt   := l_stmt || ' AND H.order_type_id = :order_type';
            END IF;

            IF p_order_source IS NOT NULL
            THEN
                l_stmt   :=
                    l_stmt || ' AND H.order_source_id = :order_source';
            END IF;

            IF p_brand IS NOT NULL
            THEN
                l_stmt   := l_stmt || ' AND H.attribute5 = :brand';
            END IF;

            IF p_customer IS NOT NULL
            THEN
                l_stmt   := l_stmt || ' AND H.sold_to_org_id = :customer';
            END IF;

            IF p_item IS NOT NULL
            THEN
                l_stmt   := l_stmt || ' AND L.inventory_item_id = :item';
            END IF;

            IF p_ordered_date_low IS NOT NULL
            THEN
                l_stmt   :=
                    l_stmt || ' AND H.ordered_date >= :ordered_date_low';
            END IF;

            IF p_ordered_date_high IS NOT NULL
            THEN
                l_stmt   :=
                    l_stmt || ' AND H.ordered_date <= :ordered_date_high';
            END IF;

            IF p_warehouse IS NOT NULL
            THEN
                l_stmt   := l_stmt || ' AND L.ship_from_org_id = :warehouse';
            END IF;

            IF p_demand_class IS NOT NULL
            THEN
                l_stmt   :=
                    l_stmt || ' AND L.demand_class_code = :demand_class';
            END IF;

            IF p_planning_priority IS NOT NULL
            THEN
                l_stmt   :=
                    l_stmt || ' AND L.planning_priority = :planning_priority';
            END IF;

            IF p_shipment_priority IS NOT NULL
            THEN
                l_stmt   :=
                       l_stmt
                    || ' AND L.shipment_priority_code = :shipment_priority';
            END IF;

            IF p_line_type IS NOT NULL
            THEN
                l_stmt   := l_stmt || ' AND L.line_type_id = :line_type';
            END IF;

            IF p_line_request_date_low IS NOT NULL
            THEN
                l_stmt   :=
                    l_stmt || ' AND L.request_date >= :line_request_date_low';
            END IF;

            IF p_line_request_date_high IS NOT NULL
            THEN
                l_stmt   :=
                       l_stmt
                    || ' AND L.request_date <= :line_request_date_high';
            END IF;

            IF p_line_ship_to_location IS NOT NULL
            THEN
                l_stmt   :=
                       l_stmt
                    || ' AND L.ship_to_org_id = :line_ship_to_location';
            END IF;

            IF p_sch_ship_date_low IS NOT NULL
            THEN
                l_stmt   :=
                       l_stmt
                    || ' AND L.schedule_ship_date >= :sch_ship_date_low';
            END IF;

            IF p_sch_ship_date_high IS NOT NULL
            THEN
                l_stmt   :=
                       l_stmt
                    || ' AND L.schedule_ship_date <= :sch_ship_date_high';
            END IF;

            IF p_sch_arrival_date_low IS NOT NULL
            THEN
                l_stmt   :=
                       l_stmt
                    || ' AND L.schedule_arrival_date >= :sch_arrival_date_low';
            END IF;

            IF p_sch_arrival_date_high IS NOT NULL
            THEN
                l_stmt   :=
                       l_stmt
                    || ' AND L.schedule_arrival_date <= :sch_arrival_date_high';
            END IF;

            IF p_booked IS NOT NULL
            THEN
                l_stmt   := l_stmt || ' AND L.booked_flag = :booked';
            END IF;

            --Bug 8813015: start
            IF NVL (p_picked, 'Y') = 'N'
            THEN
                l_stmt   :=
                       l_stmt
                    || ' AND not exists (select 1 from wsh_delivery_details wdd';
                l_stmt   :=
                       l_stmt
                    || '                 where wdd.source_code = ''OE''';
                l_stmt   :=
                       l_stmt
                    || '                 and wdd.source_line_id = l.line_id';
                l_stmt   :=
                    l_stmt || '                 and wdd.released_status in ';
                l_stmt   := l_stmt || ' (''S'',''C'',''Y'')) ';
            END IF;

            --Bug 8813015: end

            IF p_sch_mode = 'SCHEDULE'
            THEN
                l_stmt   := l_stmt || ' AND L.schedule_status_code IS NULL';
            -- Start changes for CCR0009761
            -- ELSIF p_sch_mode IN ('UNSCHEDULE','RESCHEDULE','RESCHEDULE_RD') THEN
            --   l_stmt := l_stmt || ' AND L.schedule_status_code IS NOT NULL';
            ELSIF p_sch_mode = 'UNSCHEDULE'
            THEN
                l_stmt   :=
                    l_stmt || ' AND L.schedule_status_code IS NOT NULL';
            ELSIF p_sch_mode IN ('RESCHEDULE', 'RESCHEDULE_RD')
            THEN
                IF NVL (p_req_date_condition, 'N') = 'Y'
                THEN
                    l_stmt   :=
                           l_stmt
                        || ' AND L.schedule_status_code IS NOT NULL AND TRUNC (L.schedule_ship_date) = TRUNC (L.request_date)';
                ELSE
                    l_stmt   :=
                           l_stmt
                        || ' AND L.schedule_status_code IS NOT NULL AND TRUNC (L.schedule_ship_date) <> TRUNC (L.request_date)';
                END IF;
            -- End changes for CCR0009761
            ELSIF NVL (p_sch_mode, 'LINE_ELIGIBLE') = 'LINE_ELIGIBLE'
            THEN
                l_stmt   :=
                       l_stmt
                    || ' AND wias.item_type = ''OEOL'''
                    || ' AND wias.process_activity = wpa.instance_id'
                    || ' AND wpa.activity_item_type = ''OEOL'''
                    || ' AND wpa.activity_name = ''SCHEDULING_ELIGIBLE'''
                    || ' AND wias.activity_status = ''NOTIFIED'''
                    || ' AND wias.item_key = to_char(L.line_id)'
                    || ' AND wias.begin_date < :prg_start_date';   -- 12639770
            END IF;

            -- ER18493998 Start
            --  making sure always we'll get standard line first
            --Always there will be ORDER BY
            l_stmt                    := l_stmt || ' ORDER BY ';

            --For bulk schedule, get the standard lines first which should be ordered by org id
            IF p_sch_mode = 'SCHEDULE' AND p_bulk_processing = 'Y'
            THEN
                L_stmt   :=
                       l_stmt
                    || ' decode(coalesce(l.ship_set_id, l.arrival_set_id, l.top_model_line_id),null,l.org_id,999999) , ';
            END IF;

            -- ER18493998 End

            -- Building order by clause.
            IF p_order_by_first IS NOT NULL
            THEN
                -- l_stmt := l_stmt ||' ORDER BY L.'||p_order_by_first; ER18493998
                l_stmt   := l_stmt || '  L.' || p_order_by_first;

                IF p_order_by_sec IS NOT NULL
                THEN
                    l_stmt   := l_stmt || ', L.' || p_order_by_sec;
                END IF;
            ELSIF p_order_by_sec IS NOT NULL
            THEN
                --l_stmt := l_stmt ||' ORDER BY L.'||p_order_by_sec; ER18493998
                l_stmt   := l_stmt || ' L.' || p_order_by_sec;
            END IF;

            -- Moac start
            IF NOT l_single_org
            THEN
                IF p_order_by_first IS NOT NULL OR p_order_by_sec IS NOT NULL
                THEN
                    l_stmt   := l_stmt || ', L.org_id';
                ELSE
                    -- l_stmt := l_stmt ||' ORDER BY L.org_id'; ER18493998
                    l_stmt   := l_stmt || ' L.org_id';
                END IF;
            END IF;

            -- Moac End.
            IF    NOT l_single_org
               OR (p_order_by_first IS NOT NULL OR p_order_by_sec IS NOT NULL)
            THEN
                l_stmt   := l_stmt || ', L.top_model_line_id,l.line_id'; --5166476
            ELSE
                --l_stmt := l_stmt ||' ORDER BY L.top_model_line_id,l.line_id' ; ER18493998
                l_stmt   := l_stmt || ' L.top_model_line_id,l.line_id';
            END IF;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.add ('Query : ' || l_stmt, 1);
            END IF;

            -- Parse statement.
            DBMS_SQL.Parse (l_cursor_id, l_stmt, DBMS_SQL.NATIVE);

            -- Bind variables
            -- Moac Start
            IF p_org_id IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id, ':org_id', p_org_id);
            END IF;

            -- Moac End

            IF p_order_number_low IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':order_number_low',
                                        p_order_number_low);
            END IF;

            IF p_order_number_high IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':order_number_high',
                                        p_order_number_high);
            END IF;

            IF p_request_date_low IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':request_date_low',
                                        l_request_date_low);
            END IF;

            IF p_request_date_high IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':request_date_high',
                                        l_request_date_high);
            END IF;

            IF p_customer_po_number IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':customer_po_number',
                                        p_customer_po_number);
            END IF;

            IF p_ship_to_location IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':ship_to_location',
                                        p_ship_to_location);
            END IF;

            IF p_order_type IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':order_type',
                                        p_order_type);
            END IF;

            IF p_order_source IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':order_source',
                                        p_order_source);
            END IF;

            IF p_brand IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id, ':brand', p_brand);
            END IF;

            IF p_customer IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id, ':customer', p_customer);
            END IF;

            IF p_item IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id, ':item', p_item);
            END IF;

            IF p_ordered_date_low IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':ordered_date_low',
                                        l_ordered_date_low);
            END IF;

            IF p_ordered_date_high IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':ordered_date_high',
                                        l_ordered_date_high);
            END IF;

            IF p_warehouse IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':warehouse',
                                        p_warehouse);
            END IF;

            IF p_demand_class IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':demand_class',
                                        p_demand_class);
            END IF;

            IF p_planning_priority IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':planning_priority',
                                        p_planning_priority);
            END IF;

            IF p_shipment_priority IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':shipment_priority',
                                        p_shipment_priority);
            END IF;

            IF p_line_type IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':line_type',
                                        p_line_type);
            END IF;

            IF p_line_request_date_low IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':line_request_date_low',
                                        l_line_request_date_low);
            END IF;

            IF p_line_request_date_high IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':line_request_date_high',
                                        l_line_request_date_high);
            END IF;

            IF p_line_ship_to_location IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':line_ship_to_location',
                                        p_line_ship_to_location);
            END IF;

            IF p_sch_ship_date_low IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':sch_ship_date_low',
                                        l_sch_ship_date_low);
            END IF;

            IF p_sch_ship_date_high IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':sch_ship_date_high',
                                        l_sch_ship_date_high);
            END IF;

            IF p_sch_arrival_date_low IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':sch_arrival_date_low',
                                        l_sch_arrival_date_low);
            END IF;

            IF p_sch_arrival_date_high IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':sch_arrival_date_high',
                                        l_sch_arrival_date_high);
            END IF;

            IF p_booked IS NOT NULL
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id, ':booked', p_booked);
            END IF;

            --12639770
            IF NVL (p_sch_mode, 'LINE_ELIGIBLE') = 'LINE_ELIGIBLE'
            THEN
                DBMS_SQL.Bind_Variable (l_cursor_id,
                                        ':prg_start_date',
                                        l_prg_start_date);
            END IF;

            --Bug 8813015: start
            --This code is to be un-commented while providing option for
            --picked lines in scheduling concurrent request UI.
            /*
            IF p_picked IS NOT NULL THEN
               DBMS_SQL.Bind_Variable(l_cursor_id, ':picked', p_picked);
            END IF;
            */
            --Bug 8813015: end

            -- Map output columns
            DBMS_SQL.Define_Column (l_cursor_id, 1, l_header_id);
            DBMS_SQL.Define_Column (l_cursor_id, 2, l_line_id);
            DBMS_SQL.Define_Column (l_cursor_id, 3, l_org_id);         -- Moac
            -- ER18493998
            DBMS_SQL.Define_Column (l_cursor_id, 4, l_ship_set_id);
            DBMS_SQL.Define_Column (l_cursor_id, 5, l_arrival_set_id);
            DBMS_SQL.Define_Column (l_cursor_id, 6, l_top_model_line_id);
            --Bug 21132131, Add the following columns
            DBMS_SQL.Define_Column (l_cursor_id, 7, l_booked_flag,
                                    1);
            DBMS_SQL.Define_Column (l_cursor_id, 8, l_request_date);
            DBMS_SQL.Define_Column (l_cursor_id, 9, l_ship_from_org_id);
            DBMS_SQL.Define_Column (l_cursor_id, 10, l_ato_line_id);
            DBMS_SQL.Define_Column (l_cursor_id, 11, l_link_to_line_id);
            DBMS_SQL.Define_Column (l_cursor_id, 12, l_smc_flag,
                                    1);
            DBMS_SQL.Define_Column (l_cursor_id, 13, l_item_type_code,
                                    30);
            DBMS_SQL.Define_Column (l_cursor_id, 14, l_schedule_status_code,
                                    30);
            DBMS_SQL.Define_Column (l_cursor_id, 15, l_order_date_type_code,
                                    30);
            DBMS_SQL.Define_Column (l_cursor_id, 16, l_model_remnant_flag,
                                    1);                -- Bug 21345576 Issue 4

            --Bug 21132131, End of addition of above columns

            IF l_debug_level > 0
            THEN
                oe_debug_pub.add ('Before executing query.', 1);
            END IF;

            -- Execute query.
            l_retval                  := DBMS_SQL.Execute (l_cursor_id);

            IF l_debug_level > 0
            THEN
                oe_debug_pub.add ('Execution Result : ' || l_retval, 2);
            END IF;

            g_bulk_reschedule_table   := bulk_reschedule_table (); -- ER18493998
            l_bulk_reschedule_table   := bulk_reschedule_table (); -- ER18493998
            g_bulk_line_table.delete;                           --Bug 21132131

            -- Process each row retrieved.
            LOOP
                l_temp_line_id   := 0;                          --Bug 21132131

                -- Commented ER18493998
                -- IF l_debug_level  > 0 THEN
                --   oe_debug_pub.add('Execution Result : ' || l_retval, 2) ;
                -- END IF;

                IF DBMS_SQL.Fetch_Rows (l_cursor_id) = 0
                THEN
                    EXIT;
                END IF;

                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 1, l_header_id);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 2, l_line_id);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 3, l_org_id);      -- Moac
                -- ER18493998 3 lines below
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 4, l_ship_set_id);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 5, l_arrival_set_id);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 6, l_top_model_line_id);
                --Bug 21132131, Fetch values for new columns
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 7, l_booked_flag);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 8, l_request_date);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 9, l_ship_from_org_id);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 10, l_ato_line_id);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 11, l_link_to_line_id);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 12, l_smc_flag);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 13, l_item_type_code);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id,
                                       14,
                                       l_schedule_status_code);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id,
                                       15,
                                       l_order_date_type_code);
                DBMS_SQL.COLUMN_VALUE (l_cursor_id, 16, l_model_remnant_flag); -- Bug 21345576 Issue 4

                --Bug 21132131 End of fetching values for new columns

                -- 17482674 :Cleanup temp table.
                BEGIN
                    /* IF l_debug_level  > 0 THEN
                      oe_debug_pub.add(  'DELETING oe_schedule_lines_temp ' , 1 ) ;
                    END IF; */
                    DELETE FROM oe_schedule_lines_temp;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                IF l_debug_level > 0
                THEN
                    oe_debug_pub.add (
                           '***** 1. Processing Line Id '
                        || l_line_id
                        || ' *****',
                        1);
                END IF;

                --4777400: Context set is Moved up to set before call to get_date_type
                -- Moac Start
                IF NOT l_single_org AND l_org_id <> l_old_org_id
                THEN
                    l_old_org_id   := l_org_id;
                    MO_GLOBAL.set_policy_context (p_access_mode   => 'S',
                                                  p_org_id        => l_org_id);
                END IF;

                -- Moac End.

                l_temp_line_id   := l_line_id;                  --Bug 21132131

                /* Bug 21132131 - Following is not needed since it's fetched in main cursor
                l_order_date_type_code := NVL
                   (OE_SCHEDULE_UTIL.Get_Date_Type(l_header_id),'SHIP');
                l_temp_line_id := 0;

                BEGIN

                   SELECT L.line_id,
                          L.booked_flag,
                          L.request_date,
                          L.ship_from_org_id,
                          L.ship_set_id,
                          L.arrival_set_id,
                          L.ato_line_id,
                          L.top_model_line_id,
                          L.link_to_line_id,
                          L.ship_model_complete_flag,
                          L.item_type_code,
                          L.schedule_status_code
                   INTO   l_temp_line_id,
                          l_booked_flag,
                          l_request_date,
                          l_ship_from_org_id,
                          l_ship_set_id,
                          l_arrival_set_id,
                          l_ato_line_id,
                          l_top_model_line_id,
                          l_link_to_line_id,
                          l_smc_flag,
                          l_item_type_code,
                          l_schedule_status_code
                   FROM   oe_order_lines_all L
                   WHERE  L.open_flag = 'Y'
                   AND    L.line_id = l_line_id;


                EXCEPTION
                   WHEN no_data_found THEN
                      NULL;
                END;
               */
                --Bug 21132131

                IF l_temp_line_id <> 0
                THEN
                    g_conc_program   := 'Y';
                    g_recorded       := 'N';                        -- 5166476

                    -- ER18493998 Start
                    IF     p_bulk_processing = 'Y'
                       AND p_sch_mode IN ('SCHEDULE', 'UNSCHEDULE', 'RESCHEDULE',
                                          'RESCHEDULE_RD')
                    THEN
                        l_temp_flag    := FALSE;

                        IF     l_smc_flag = 'Y'
                           AND l_top_model_line_id IS NOT NULL
                        THEN
                            l_temp_flag   :=
                                model_processed (l_top_model_line_id,
                                                 l_top_model_line_id);

                            IF     l_temp_flag
                               --AND oe_line_status_tbl.EXISTS (l_top_model_line_id)
                               --AND oe_line_status_tbl (l_top_model_line_id) = 'N'
                               --Added as per bug 21079696
                               AND oe_line_status_tbl.EXISTS (
                                       MOD (l_top_model_line_id,
                                            OE_GLOBALS.G_BINARY_LIMIT))
                               AND oe_line_status_tbl (
                                       MOD (l_top_model_line_id,
                                            OE_GLOBALS.G_BINARY_LIMIT)) =
                                   'N'
                            THEN
                                --oe_line_status_tbl (l_line_id) := 'N';
                                --Added as per bug 21079696
                                oe_line_status_tbl (
                                    MOD (l_line_id,
                                         OE_GLOBALS.G_BINARY_LIMIT))   :=
                                    'N';

                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.ADD (
                                           'R6.1 PROCESSED: '
                                        || l_rec_processed
                                        || ' FAILED: '
                                        || l_rec_failure,
                                        1);
                                END IF;
                            END IF;
                        ELSIF l_ato_line_id IS NOT NULL
                        THEN
                            l_temp_flag   :=
                                model_processed (l_ato_line_id,
                                                 l_ato_line_id);

                            IF     l_temp_flag
                               --AND oe_line_status_tbl.EXISTS (l_ato_line_id)
                               --AND oe_line_status_tbl (l_ato_line_id) = 'N'
                               --Added as per bug 21079696
                               AND oe_line_status_tbl.EXISTS (
                                       MOD (l_ato_line_id,
                                            OE_GLOBALS.G_BINARY_LIMIT))
                               AND oe_line_status_tbl (
                                       MOD (l_ato_line_id,
                                            OE_GLOBALS.G_BINARY_LIMIT)) =
                                   'N'
                            THEN
                                --oe_line_status_tbl (l_line_id) := 'N';
                                --Added as per bug 21079696
                                oe_line_status_tbl (
                                    MOD (l_line_id,
                                         OE_GLOBALS.G_BINARY_LIMIT))   :=
                                    'N';

                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.ADD (
                                           'R6.2 PROCESSED: '
                                        || l_rec_processed
                                        || ' FAILED: '
                                        || l_rec_failure,
                                        1);
                                END IF;
                            END IF;
                        END IF;

                        /* If many of the lines selected are part of a set, then delayed
                      * request must get logged only for one of the lines.
                      */
                        IF    l_ship_set_id IS NOT NULL
                           OR l_arrival_set_id IS NOT NULL
                        THEN
                            l_temp_flag   :=
                                set_processed (
                                    NVL (l_ship_set_id, l_arrival_set_id));
                        END IF;

                        IF NOT l_temp_flag AND NOT line_exists (l_line_id)
                        THEN
                            -- start adding to global table at this point.
                            l_line_index        := l_line_index + 1;
                            l_total_lines_cnt   := l_total_lines_cnt + 1;
                            g_bulk_reschedule_table.EXTEND;
                            g_bulk_reschedule_table (l_line_index).line_id   :=
                                l_line_id;
                            g_bulk_reschedule_table (l_line_index).org_id   :=
                                l_org_id;
                            g_bulk_reschedule_table (l_line_index).ship_set_id   :=
                                l_ship_set_id;
                            g_bulk_reschedule_table (l_line_index).arrival_set_id   :=
                                l_arrival_set_id;
                            g_bulk_reschedule_table (l_line_index).top_model_line_id   :=
                                l_top_model_line_id;
                            g_bulk_reschedule_table (l_line_index).request_date   :=
                                l_request_date;
                            g_bulk_reschedule_table (l_line_index).ship_from_org_id   :=
                                l_ship_from_org_id;
                            g_bulk_reschedule_table (l_line_index).processing_order   :=
                                l_line_index;
                            g_bulk_reschedule_table (l_line_index).group_number   :=
                                l_line_index;

                            g_bulk_reschedule_table (l_line_index).ship_from_org_id   :=
                                NVL (p_apply_warehouse, l_ship_from_org_id);
                            g_bulk_line_table (
                                MOD (l_line_id, OE_GLOBALS.G_BINARY_LIMIT))   :=
                                l_line_id;                      --Bug 21132131

                            IF l_apply_sch_date IS NOT NULL
                            THEN
                                IF l_order_date_type_code = 'SHIP'
                                THEN
                                    g_bulk_reschedule_table (l_line_index).schedule_ship_date   :=
                                        l_apply_sch_date;
                                ELSE
                                    g_bulk_reschedule_table (l_line_index).schedule_arrival_date   :=
                                        l_apply_sch_date;
                                END IF;
                            END IF;

                            IF    g_bulk_reschedule_table (l_line_index).ship_set_id
                                      IS NOT NULL
                               OR g_bulk_reschedule_table (l_line_index).arrival_set_id
                                      IS NOT NULL
                               OR (g_bulk_reschedule_table (l_line_index).top_model_line_id IS NOT NULL AND NVL (l_model_remnant_flag, 'N') <> 'Y') -- Bug 21345576 Issue 4
                            THEN
                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.ADD (
                                        'line part of a group. query children');
                                END IF;

                                r_line_tbl.DELETE;
                                l_selected_line_tbl (1).id1   :=
                                    g_bulk_reschedule_table (l_line_index).line_id;

                                IF p_sch_mode IN
                                       ('RESCHEDULE', 'RESCHEDULE_RD')
                                THEN
                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.ADD (
                                            'query reschedule lines');
                                    END IF;

                                    oe_group_sch_util.query_reschedule_lines (
                                        p_selected_tbl   =>
                                            l_selected_line_tbl,
                                        p_sch_action   =>
                                            oe_schedule_util.oesch_act_reschedule,
                                        x_line_tbl   => r_line_tbl);
                                ELSIF p_sch_mode = 'SCHEDULE'
                                THEN
                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.ADD (
                                            'query schedule lines');
                                    END IF;

                                    oe_group_sch_util.query_schedule_lines (
                                        p_selected_tbl   =>
                                            l_selected_line_tbl,
                                        p_sch_action   =>
                                            oe_schedule_util.OESCH_ACT_CHECK_SCHEDULING, -- oe_schedule_util.oesch_act_schedule, Bug 20083547, 20273441 : Issue 4
                                        x_line_tbl   => r_line_tbl);
                                ELSIF p_sch_mode = 'UNSCHEDULE'
                                THEN
                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.ADD (
                                            'query unschedule lines');
                                    END IF;

                                    oe_group_sch_util.query_unschedule_lines (
                                        p_selected_tbl   =>
                                            l_selected_line_tbl,
                                        p_sch_action   =>
                                            oe_schedule_util.oesch_act_unschedule,
                                        x_line_tbl   => r_line_tbl);
                                END IF;

                                IF r_line_tbl.COUNT > 0
                                THEN
                                    l_line_index_ch   :=
                                        g_bulk_reschedule_table.COUNT; --Bug 21132131

                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.ADD (
                                            'queried all the children. loop through');
                                    END IF;

                                    FOR j IN r_line_tbl.FIRST ..
                                             r_line_tbl.LAST
                                    LOOP
                                        IF r_line_tbl (j).line_id <>
                                           g_bulk_reschedule_table (
                                               l_line_index).line_id
                                        THEN
                                            IF l_debug_level > 0
                                            THEN
                                                oe_debug_pub.ADD (
                                                       'adding children:'
                                                    || r_line_tbl (j).line_id);
                                            END IF;

                                            l_line_index_ch   :=
                                                  g_bulk_reschedule_table.COUNT
                                                + 1;
                                            l_total_lines_cnt   :=
                                                l_total_lines_cnt + 1;
                                            g_bulk_reschedule_table.EXTEND;
                                            g_bulk_reschedule_table (
                                                l_line_index_ch).line_id   :=
                                                r_line_tbl (j).line_id;
                                            g_bulk_reschedule_table (
                                                l_line_index_ch).org_id   :=
                                                r_line_tbl (j).org_id;
                                            g_bulk_reschedule_table (
                                                l_line_index_ch).ship_set_id   :=
                                                r_line_tbl (j).ship_set_id;
                                            g_bulk_reschedule_table (
                                                l_line_index_ch).arrival_set_id   :=
                                                r_line_tbl (j).arrival_set_id;
                                            g_bulk_reschedule_table (
                                                l_line_index_ch).top_model_line_id   :=
                                                r_line_tbl (j).top_model_line_id;
                                            g_bulk_reschedule_table (
                                                l_line_index_ch).request_date   :=
                                                r_line_tbl (j).request_date;
                                            g_bulk_reschedule_table (
                                                l_line_index_ch).processing_order   :=
                                                l_line_index_ch;

                                            IF l_debug_level > 0
                                            THEN
                                                oe_debug_pub.ADD (
                                                       'l_line_index:'
                                                    || l_line_index);
                                                oe_debug_pub.ADD (
                                                       'l_line_index_ch:'
                                                    || l_line_index_ch);
                                            END IF;

                                            g_bulk_line_table (
                                                MOD (
                                                    r_line_tbl (j).line_id,
                                                    OE_GLOBALS.G_BINARY_LIMIT))   :=
                                                r_line_tbl (j).line_id; --Bug 21132131
                                            g_bulk_reschedule_table (
                                                l_line_index_ch).group_number   :=
                                                l_line_index;
                                            g_bulk_reschedule_table (
                                                l_line_index_ch).ship_from_org_id   :=
                                                g_bulk_reschedule_table (
                                                    l_line_index).ship_from_org_id;
                                            g_bulk_reschedule_table (
                                                l_line_index_ch).schedule_ship_date   :=
                                                g_bulk_reschedule_table (
                                                    l_line_index).schedule_ship_date;
                                            g_bulk_reschedule_table (
                                                l_line_index_ch).schedule_arrival_date   :=
                                                g_bulk_reschedule_table (
                                                    l_line_index).schedule_arrival_date;
                                        --IF j= r_line_tbl.COUNT THEN --Bug 21132131, Not needed here. Should be down
                                        --   l_line_index := l_line_index_ch;
                                        --END IF ;
                                        END IF;

                                        IF j = r_line_tbl.COUNT
                                        THEN                    --Bug 21132131
                                            l_line_index   := l_line_index_ch;
                                        END IF;
                                    END LOOP;
                                END IF;
                            END IF;
                        END IF;

                        --Bug 18015878, increment the line count for reschedule/reschedule_rd mode
                        l_line_count   := l_line_count + 1;
                        -- Goto the end of the loop to fetch next records
                        GOTO END_LOOP;
                    END IF;

                    -- ER18493998 End

                    IF NVL (p_sch_mode, 'LINE_ELIGIBLE') = 'LINE_ELIGIBLE'
                    THEN
                        --5166476
                        IF Line_Eligible (p_line_id => l_line_id)
                        THEN
                            IF l_debug_level > 0
                            THEN
                                oe_debug_pub.add (
                                    TO_CHAR (l_line_id) || ' - Line Eligible',
                                    1);
                            END IF;

                            --l_found := FALSE;

                            --IF NOT l_found THEN
                            g_process_records   := 0;
                            g_failed_records    := 0;

                            -- 8731703
                            -- Lock the record before processing
                            BEGIN
                                    SELECT line_id
                                      INTO l_locked_line_id
                                      FROM oe_order_lines_all
                                     WHERE line_id = l_line_id
                                FOR UPDATE NOWAIT;

                                wf_engine.CompleteActivityInternalName (
                                    'OEOL',
                                    TO_CHAR (l_line_id),
                                    'SCHEDULING_ELIGIBLE',
                                    'COMPLETE',
                                    TRUE);                          --15870313
                                l_line_count   := l_line_count + 1; -- 12639770
                            /*
                            OE_MSG_PUB.Count_And_Get (p_count     => l_msg_count,
                                                      p_data      => l_msg_data);

                            FOR I in 1..l_msg_count LOOP
                               l_msg_data := OE_MSG_PUB.Get(I,'F');

                               -- Write Messages in the log file
                               FND_FILE.PUT_LINE(FND_FILE.LOG, l_msg_data);

                            END LOOP;
              */
                            EXCEPTION
                                WHEN APP_EXCEPTIONS.RECORD_LOCK_EXCEPTION
                                THEN
                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.add (
                                               'OEXWSCHB.pls: unable to lock the line:'
                                            || l_line_id,
                                            1);
                                    END IF;
                                WHEN OTHERS
                                THEN
                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.add (
                                               '*** 1. Error -  '
                                            || SUBSTR (SQLERRM, 1, 200),
                                            1);
                                    END IF;
                            END;

                            --5166476

                            --IF g_failed_records > 0 THEN
                            --IF OE_SCH_CONC_REQUESTS.oe_line_status_tbl.EXISTS(l_line_id) AND
                            --OE_SCH_CONC_REQUESTS.oe_line_status_tbl(l_line_id) ='N' THEN
                            --Added as per bug 21079696
                            IF     OE_SCH_CONC_REQUESTS.oe_line_status_tbl.EXISTS (
                                       MOD (l_line_id,
                                            OE_GLOBALS.G_BINARY_LIMIT))
                               AND OE_SCH_CONC_REQUESTS.oe_line_status_tbl (
                                       MOD (l_line_id,
                                            OE_GLOBALS.G_BINARY_LIMIT)) =
                                   'N'
                            THEN
                                l_failure   := TRUE;
                            END IF;

                            IF l_debug_level > 0
                            THEN
                                oe_debug_pub.add (
                                       'R2 PROCESSED: '
                                    || l_rec_processed
                                    || ' FAILED: '
                                    || l_rec_failure,
                                    1);
                            END IF;
                        --END IF;
                        END IF;

                        --12639770
                        IF NVL (p_commit_threshold, 0) > 0
                        THEN
                            IF l_line_count >= p_commit_threshold
                            THEN
                                -- ER18493998 - Check for reservation validity before commit
                                OE_SCHEDULE_UTIL.Post_Forms_Commit (
                                    l_rsv_return_status,
                                    l_rsv_msg_count,
                                    l_rsv_msg_data);
                                COMMIT;
                                l_line_count   := 0;
                            END IF;
                        END IF;
                    ELSIF     p_sch_mode = 'SCHEDULE'
                          AND l_schedule_status_code IS NULL
                    THEN
                        IF l_debug_level > 0
                        THEN
                            oe_debug_pub.add (
                                TO_CHAR (l_line_id) || ' - Schedule',
                                1);
                        END IF;

                        --Bug 21544639, Check if the set is already processed
                        l_temp_flag    := FALSE;

                        IF    l_ship_set_id IS NOT NULL
                           OR l_arrival_set_id IS NOT NULL
                        THEN
                            l_temp_flag   :=
                                set_processed (
                                    NVL (l_ship_set_id, l_arrival_set_id));
                        END IF;

                        IF NOT l_temp_flag
                        THEN
                            --Bug 21544639

                            l_found   := FALSE;

                            IF     l_smc_flag = 'Y'
                               AND l_top_model_line_id IS NOT NULL
                            THEN
                                l_found   :=
                                    model_processed (l_top_model_line_id,
                                                     l_top_model_line_id);

                                --5166476
                                IF     l_found
                                   AND --oe_line_status_tbl.EXISTS(l_top_model_line_id) THEN
                                       --Added as per bug 21079696
                                       oe_line_status_tbl.EXISTS (
                                           MOD (l_top_model_line_id,
                                                OE_GLOBALS.G_BINARY_LIMIT))
                                THEN
                                    --IF OE_SCH_CONC_REQUESTS.OE_line_status_Tbl(l_top_model_line_id) = 'N' THEN
                                    --Added as per bug 21079696
                                    IF OE_SCH_CONC_REQUESTS.OE_line_status_Tbl (
                                           MOD (l_top_model_line_id,
                                                OE_GLOBALS.G_BINARY_LIMIT)) =
                                       'N'
                                    THEN
                                        --5166476
                                        --OE_SCH_CONC_REQUESTS.OE_line_status_Tbl(l_line_id) := 'N';
                                        --Added as per bug 21079696
                                        OE_SCH_CONC_REQUESTS.OE_line_status_Tbl (
                                            MOD (l_line_id,
                                                 OE_GLOBALS.G_BINARY_LIMIT))   :=
                                            'N';
                                    ELSE
                                        --OE_SCH_CONC_REQUESTS.OE_line_status_Tbl(l_line_id) := 'Y';
                                        --Added as per bug 21079696
                                        OE_SCH_CONC_REQUESTS.OE_line_status_Tbl (
                                            MOD (l_line_id,
                                                 OE_GLOBALS.G_BINARY_LIMIT))   :=
                                            'Y';
                                    END IF;

                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.add (
                                            'R3.1 PROCESSED: ' || l_line_id,
                                            1);
                                    END IF;
                                END IF;
                            ELSIF l_ato_line_id IS NOT NULL
                            THEN
                                --l_top_model_line_id = l_ato_line_id THEN --5166476
                                l_found   :=
                                    model_processed (l_ato_line_id,
                                                     l_ato_line_id);

                                --5166476
                                IF     l_found
                                   AND --oe_line_status_tbl.EXISTS(l_ato_line_id) THEN
                                       --Added as per bug 21079696
                                       oe_line_status_tbl.EXISTS (
                                           MOD (l_ato_line_id,
                                                OE_GLOBALS.G_BINARY_LIMIT))
                                THEN
                                    /*IF OE_SCH_CONC_REQUESTS.OE_line_status_Tbl(l_ato_line_id) ='N'  THEN
                                        OE_SCH_CONC_REQUESTS.OE_line_status_Tbl(l_line_id) := 'N';
                                    ELSE
                                       OE_SCH_CONC_REQUESTS.OE_line_status_Tbl(l_line_id) := 'Y';
                                    END IF;*/
                                    --Added as per bug 21079696
                                    IF OE_SCH_CONC_REQUESTS.OE_line_status_Tbl (
                                           MOD (l_ato_line_id,
                                                OE_GLOBALS.G_BINARY_LIMIT)) =
                                       'N'
                                    THEN
                                        OE_SCH_CONC_REQUESTS.OE_line_status_Tbl (
                                            MOD (l_line_id,
                                                 OE_GLOBALS.G_BINARY_LIMIT))   :=
                                            'N';
                                    ELSE
                                        OE_SCH_CONC_REQUESTS.OE_line_status_Tbl (
                                            MOD (l_line_id,
                                                 OE_GLOBALS.G_BINARY_LIMIT))   :=
                                            'Y';
                                    END IF;

                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.add (
                                            'R3.2 PROCESSED: ' || l_line_id,
                                            1);
                                    END IF;
                                END IF;

                                IF     NOT l_found
                                   AND l_top_model_line_id IS NOT NULL
                                   AND l_top_model_line_id <> l_ato_line_id
                                   AND (p_apply_warehouse IS NULL AND p_apply_sch_date IS NULL)
                                THEN
                                    l_found   :=
                                        model_processed (l_top_model_line_id,
                                                         l_line_id);
                                END IF;
                            ELSIF l_top_model_line_id IS NOT NULL
                            THEN
                                IF     (p_apply_warehouse IS NOT NULL OR p_apply_sch_date IS NOT NULL)
                                   AND l_item_type_code NOT IN
                                           (OE_GLOBALS.G_ITEM_INCLUDED)
                                THEN
                                    l_found   :=
                                        model_processed (l_line_id,
                                                         l_line_id);

                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.add (
                                            'R3.4 PROCESSED ' || l_line_id,
                                            1);
                                    END IF;
                                --5166476
                                ELSIF     l_top_model_line_id <>
                                          l_link_to_line_id
                                      AND l_item_type_code =
                                          (OE_GLOBALS.G_ITEM_INCLUDED)
                                      AND (p_apply_warehouse IS NOT NULL OR p_apply_sch_date IS NOT NULL)
                                THEN
                                    l_found   :=
                                        model_processed (l_link_to_line_id,
                                                         l_line_id);

                                    IF     l_found
                                       AND --oe_line_status_tbl.EXISTS(l_link_to_line_id) AND
                                           --oe_line_status_tbl(l_link_to_line_id) ='N' THEN
                                           --oe_line_status_tbl(l_line_id) := 'N';
                                           --Added as per bug 21079696
                                           oe_line_status_tbl.EXISTS (
                                               MOD (
                                                   l_link_to_line_id,
                                                   OE_GLOBALS.G_BINARY_LIMIT))
                                       AND oe_line_status_tbl (
                                               MOD (
                                                   l_link_to_line_id,
                                                   OE_GLOBALS.G_BINARY_LIMIT)) =
                                           'N'
                                    THEN
                                        oe_line_status_tbl (
                                            MOD (l_line_id,
                                                 OE_GLOBALS.G_BINARY_LIMIT))   :=
                                            'N';
                                    END IF;
                                ELSE
                                    l_found   :=
                                        model_processed (l_top_model_line_id,
                                                         l_line_id);

                                    --5166476
                                    IF     l_found
                                       AND --oe_line_status_tbl.EXISTS(l_top_model_line_id) AND
                                           --oe_line_status_tbl(l_top_model_line_id) ='N' THEN
                                           --oe_line_status_tbl(l_line_id) := 'N';
                                           --Added as per bug 21079696
                                           oe_line_status_tbl.EXISTS (
                                               MOD (
                                                   l_top_model_line_id,
                                                   OE_GLOBALS.G_BINARY_LIMIT))
                                       AND oe_line_status_tbl (
                                               MOD (
                                                   l_top_model_line_id,
                                                   OE_GLOBALS.G_BINARY_LIMIT)) =
                                           'N'
                                    THEN
                                        oe_line_status_tbl (
                                            MOD (l_line_id,
                                                 OE_GLOBALS.G_BINARY_LIMIT))   :=
                                            'N';

                                        IF l_debug_level > 0
                                        THEN
                                            oe_debug_pub.add (
                                                   'R3.5 PROCESSED: '
                                                || l_line_id,
                                                1);
                                        END IF;
                                    END IF;
                                END IF;
                            END IF;

                            IF NOT l_found
                            THEN
                                IF    p_apply_warehouse IS NOT NULL
                                   OR p_apply_sch_date IS NOT NULL
                                THEN
                                    -- Define a save point
                                    SAVEPOINT Schedule_Line;

                                    IF l_rec_processed > 1
                                    THEN
                                        -- Initially this will be set to FND_API.G_TRUE
                                        l_init_msg_list   := FND_API.G_FALSE;
                                    END IF;

                                    oe_line_util.lock_row (
                                        x_return_status   => l_return_status,
                                        p_x_line_rec      => l_line_rec,
                                        p_line_id         => l_line_id);

                                    --l_line_tbl := OE_ORDER_PUB.G_MISS_LINE_TBL;
                                    --l_old_line_tbl := OE_ORDER_PUB.G_MISS_LINE_TBL;
                                    --l_line_tbl(1) := OE_ORDER_PUB.G_MISS_LINE_REC;
                                    --l_line_tbl(1).line_id := l_line_id;
                                    --l_line_tbl(1).header_id := l_header_id;
                                    l_line_tbl (1)       := l_line_rec;
                                    l_old_line_tbl (1)   := l_line_rec;

                                    l_line_tbl (1).operation   :=
                                        OE_GLOBALS.G_OPR_UPDATE;

                                    IF p_apply_warehouse IS NOT NULL
                                    THEN
                                        l_line_tbl (1).ship_from_org_id   :=
                                            p_apply_warehouse;
                                    END IF;

                                    IF p_apply_sch_date IS NOT NULL
                                    THEN
                                        IF l_order_date_type_code = 'SHIP'
                                        THEN
                                            l_line_tbl (1).schedule_ship_date   :=
                                                l_apply_sch_date;
                                        ELSE
                                            l_line_tbl (1).schedule_arrival_date   :=
                                                l_apply_sch_date;
                                        END IF;
                                    ELSE
                                        IF l_order_date_type_code = 'SHIP'
                                        THEN
                                            l_line_tbl (1).schedule_ship_date   :=
                                                l_request_date;
                                        ELSE
                                            l_line_tbl (1).schedule_arrival_date   :=
                                                l_request_date;
                                        END IF;
                                    END IF;

                                    --4892724
                                    l_line_tbl (1).change_reason   :=
                                        'SYSTEM';
                                    l_line_tbl (1).change_comments   :=
                                        'SCHEDULE ORDERS CONCURRENT PROGRAM';


                                    -- Call to process order
                                    l_control_rec.controlled_operation   :=
                                        TRUE;
                                    l_control_rec.write_to_db   :=
                                        TRUE;
                                    l_control_rec.PROCESS   :=
                                        FALSE;
                                    l_control_rec.default_attributes   :=
                                        TRUE;
                                    l_control_rec.change_attributes   :=
                                        TRUE;
                                    l_process_order      :=
                                        TRUE;
                                    l_control_rec.check_security   :=
                                        TRUE;                       -- 5168540

                                    g_process_records    := 0;
                                    g_failed_records     := 0;

                                    Oe_Order_Pvt.Lines (
                                        p_init_msg_list    => l_init_msg_list,
                                        p_validation_level   =>
                                            FND_API.G_VALID_LEVEL_FULL,
                                        p_control_rec      => l_control_rec,
                                        p_x_line_tbl       => l_line_tbl,
                                        p_x_old_line_tbl   => l_old_line_tbl,
                                        x_return_status    => l_return_status);

                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.add (
                                               'Oe_Order_Pvt.Lines returns with - '
                                            || l_return_status);
                                    END IF;

                                    IF l_return_status IN
                                           (FND_API.G_RET_STS_ERROR, FND_API.G_RET_STS_UNEXP_ERROR)
                                    THEN
                                        IF l_debug_level > 0
                                        THEN
                                            oe_debug_pub.add (
                                                   '#### FAILURE #### LINE_ID - '
                                                || TO_CHAR (l_line_id)
                                                || ' ####');
                                        END IF;

                                        --5166476
                                        IF g_recorded = 'N'
                                        THEN
                                            --5166476
                                            --OE_SCH_CONC_REQUESTS.oe_line_status_tbl(l_line_id) :='N';
                                            --Added as per bug 21079696
                                            OE_SCH_CONC_REQUESTS.oe_line_status_tbl (
                                                MOD (
                                                    l_line_id,
                                                    OE_GLOBALS.G_BINARY_LIMIT))   :=
                                                'N';
                                            g_recorded   := 'Y';
                                        END IF;

                                        --5166476
                                        --IF l_smc_flag = 'Y' AND
                                        IF     l_top_model_line_id
                                                   IS NOT NULL
                                           AND l_smc_flag = 'Y'
                                           AND l_ato_line_id IS NULL
                                        THEN
                                            --OE_line_status_Tbl(l_top_model_line_id) := 'N';
                                            --Added as per bug 21079696
                                            OE_line_status_Tbl (
                                                MOD (
                                                    l_top_model_line_id,
                                                    OE_GLOBALS.G_BINARY_LIMIT))   :=
                                                'N';
                                        ELSIF l_ato_line_id IS NOT NULL
                                        THEN
                                            --OE_line_status_Tbl(l_ato_line_id) := 'N';
                                            --Added as per bug 21079696
                                            OE_line_status_Tbl (
                                                MOD (
                                                    l_ato_line_id,
                                                    OE_GLOBALS.G_BINARY_LIMIT))   :=
                                                'N';
                                        END IF;


                                        l_failure   := TRUE;

                                        --ROLLBACK TO SAVEPOINT Schedule_Line;
                                        --Bug 18268780, call mrp cleanup which will rollback and cleanup both
                                        mrp_cleanup ();
                                    END IF;

                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.add (
                                            'R3 PROCESSED: ' || l_line_id,
                                            1);
                                    END IF;
                                ELSE  -- No scheduling attributes are provided
                                    --Define a savepoint Bug 13810638
                                    SAVEPOINT Schedule_Line;

                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.add (
                                               'No scheduling attributes. Booked flag - '
                                            || l_booked_flag);
                                    END IF;

                                    g_process_records   := 0;
                                    g_failed_records    := 0;

                                    --R12.MOAC
                                    l_selected_line_tbl (1).id1   :=
                                        l_line_id;

                                    l_process_order     := TRUE; --Bug 13810638

                                    OE_GROUP_SCH_UTIL.Schedule_Multi_lines (
                                        p_selected_line_tbl   =>
                                            l_selected_line_tbl,    --R12.MOAC
                                        p_line_count      => 1,
                                        p_sch_action      => 'SCHEDULE',
                                        x_atp_tbl         => l_atp_tbl,
                                        x_return_status   => l_return_status,
                                        x_msg_count       => l_msg_count,
                                        x_msg_data        => l_msg_data);

                                    --ELSE
                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.add (
                                               'Return Status  After Schedule_Multi_lines '
                                            || l_return_status,
                                            1);
                                    END IF;

                                    IF     NVL (l_booked_flag, 'N') = 'Y'
                                       AND l_return_status =
                                           FND_API.G_RET_STS_SUCCESS
                                    THEN
                                        IF l_debug_level > 0
                                        THEN
                                            oe_debug_pub.add (
                                                'It is a Booked Order');
                                        END IF;

                                        -- Added PTO Logic as part of bug 5186581
                                        IF     l_top_model_line_id
                                                   IS NOT NULL
                                           AND l_top_model_line_id =
                                               l_line_id
                                           AND l_ato_line_id IS NULL
                                           AND l_smc_flag = 'N'
                                        THEN
                                            IF l_debug_level > 0
                                            THEN
                                                oe_debug_pub.add (
                                                    'It is a PTO Model');
                                            END IF;

                                            -- Workflow wont progress all child lines for the Non SMC PTO model scenario. We have to progress all the
                                            -- child lines if the to Model is NON SMC

                                            FOR M IN progress_pto
                                            LOOP
                                                IF l_debug_level > 0
                                                THEN
                                                    oe_debug_pub.add (
                                                           'Progressing Line '
                                                        || M.line_id,
                                                        1);
                                                END IF;

                                                IF Line_Eligible (
                                                       p_line_id   =>
                                                           M.line_id,
                                                       p_check_scheduled   =>
                                                           TRUE)
                                                THEN -- Bug 16818560 --17482674: New parameter passed as True
                                                    BEGIN
                                                        -- COMPLETING ACTIVITY
                                                        wf_engine.CompleteActivityInternalName (
                                                            'OEOL',
                                                            TO_CHAR (
                                                                M.line_id),
                                                            'SCHEDULING_ELIGIBLE',
                                                            'COMPLETE',
                                                            TRUE);  --15870313
                                                    EXCEPTION
                                                        WHEN OTHERS
                                                        THEN
                                                            NULL;
                                                    END;
                                                END IF;        -- Bug 16818560
                                            END LOOP;
                                        ELSE -- Call for each line or ATO/SMC...
                                            IF Line_Eligible (
                                                   p_line_id           => l_line_id,
                                                   p_check_scheduled   => TRUE)
                                            THEN -- Bug 16818560 --17482674: New parameter passed as True
                                                BEGIN
                                                    -- COMPLETING ACTIVITY
                                                    wf_engine.CompleteActivityInternalName (
                                                        'OEOL',
                                                        TO_CHAR (l_line_id),
                                                        'SCHEDULING_ELIGIBLE',
                                                        'COMPLETE',
                                                        TRUE);      --15870313
                                                EXCEPTION
                                                    WHEN OTHERS
                                                    THEN
                                                        NULL;
                                                END;
                                            END IF;
                                        END IF;

                                        --ER 13615316 Start
                                        --Progress all eligile lines in same ship/arrival set
                                        IF    l_ship_set_id IS NOT NULL
                                           OR l_arrival_set_id IS NOT NULL
                                        THEN
                                            OE_Set_Util.Query_Set_Rows (
                                                p_set_id     =>
                                                    NVL (l_ship_set_id,
                                                         l_arrival_set_id),
                                                x_line_tbl   => l_set_line_tbl);

                                            FOR L IN 1 ..
                                                     l_set_line_tbl.COUNT
                                            LOOP
                                                IF Line_Eligible (
                                                       p_line_id   =>
                                                           l_set_line_tbl (L).line_id,
                                                       p_check_scheduled   =>
                                                           TRUE)
                                                THEN            --Bug 21544639
                                                    BEGIN
                                                        -- COMPLETING ACTIVITY
                                                        wf_engine.CompleteActivityInternalName (
                                                            'OEOL',
                                                            TO_CHAR (
                                                                l_set_line_tbl (
                                                                    L).line_id),
                                                            'SCHEDULING_ELIGIBLE',
                                                            'COMPLETE',
                                                            TRUE);  --15870313
                                                    EXCEPTION
                                                        WHEN OTHERS
                                                        THEN
                                                            NULL;
                                                    END;
                                                END IF;
                                            END LOOP;
                                        END IF;
                                    --ER 13615316 END

                                    END IF;

                                    --5166476

                                    --IF g_failed_records > 0 THEN
                                    --IF OE_SCH_CONC_REQUESTS.oe_line_status_tbl.EXISTS(l_line_id) AND
                                    --OE_SCH_CONC_REQUESTS.oe_line_status_tbl(l_line_id) = 'N' THEN
                                    --Added as per bug 21079696
                                    IF     OE_SCH_CONC_REQUESTS.oe_line_status_tbl.EXISTS (
                                               MOD (
                                                   l_line_id,
                                                   OE_GLOBALS.G_BINARY_LIMIT))
                                       AND OE_SCH_CONC_REQUESTS.oe_line_status_tbl (
                                               MOD (
                                                   l_line_id,
                                                   OE_GLOBALS.G_BINARY_LIMIT)) =
                                           'N'
                                    THEN
                                        l_failure   := TRUE;
                                    END IF;

                                    --Bug 13810638
                                    IF l_return_status IN
                                           (FND_API.G_RET_STS_ERROR, FND_API.G_RET_STS_UNEXP_ERROR)
                                    THEN
                                        --ROLLBACK TO SAVEPOINT Schedule_Line;
                                        --Bug 18268780, call mrp cleanup which will rollback and cleanup both
                                        mrp_cleanup ();

                                        IF l_debug_level > 0
                                        THEN
                                            oe_debug_pub.add (
                                                   '#### FAILURE #### LINE_ID - '
                                                || TO_CHAR (l_line_id)
                                                || ' ####');
                                        END IF;

                                        l_failure   := TRUE;
                                    END IF;

                                    IF l_debug_level > 0
                                    THEN
                                        oe_debug_pub.add (
                                               'R4 PROCESSED: '
                                            || l_rec_processed
                                            || ' FAILED: '
                                            || l_rec_failure,
                                            1);
                                    END IF;
                                END IF;
                            END IF;
                        END IF;                     --l_temp_flag Bug 21544639

                        --Bug 17543200, add to line count for commit later
                        l_line_count   := l_line_count + 1;
                    ELSIF     p_sch_mode = 'UNSCHEDULE'
                          AND l_schedule_status_code IS NOT NULL
                    THEN
                        IF l_debug_level > 0
                        THEN
                            oe_debug_pub.add (
                                TO_CHAR (l_line_id) || ' - Unschedule',
                                1);
                        END IF;

                        l_found        := FALSE;

                        IF     l_smc_flag = 'Y'
                           AND l_top_model_line_id IS NOT NULL
                        THEN
                            l_found   :=
                                model_processed (l_top_model_line_id,
                                                 l_top_model_line_id);
                        ELSIF l_ato_line_id IS NOT NULL
                        THEN
                            --l_top_model_line_id = l_ato_line_id THEN
                            l_found   :=
                                model_processed (l_ato_line_id,
                                                 l_ato_line_id);
                        ELSIF     l_smc_flag = 'N'
                              AND l_top_model_line_id IS NOT NULL
                              AND (l_ato_line_id IS NULL OR l_ato_line_id <> l_top_model_line_id)
                              AND l_item_type_code =
                                  OE_GLOBALS.G_ITEM_INCLUDED
                        THEN
                            --l_found := included_processed(l_line_id);
                            --Added as per but 21079696
                            l_found   :=
                                included_processed (
                                    MOD (l_line_id,
                                         OE_GLOBALS.G_BINARY_LIMIT));
                        END IF;

                        IF NOT l_found
                        THEN
                            --Define a savepoint Bug 13810638
                            SAVEPOINT Schedule_Line;

                            g_process_records             := 0;
                            g_failed_records              := 0;

                            IF l_item_type_code = OE_GLOBALS.G_ITEM_INCLUDED
                            THEN
                                --5166476
                                --g_process_records := g_process_records + 1;
                                --OE_SCH_CONC_REQUESTS.oe_line_status_tbl(l_line_id) := 'Y';
                                --Added as per bug 21079696
                                OE_SCH_CONC_REQUESTS.oe_line_status_tbl (
                                    MOD (l_line_id,
                                         OE_GLOBALS.G_BINARY_LIMIT))   :=
                                    'Y';
                            END IF;

                            --R12.MOAC
                            l_selected_line_tbl (1).id1   := l_line_id;
                            l_process_order               := TRUE; --Bug 13810638
                            OE_GROUP_SCH_UTIL.Schedule_Multi_lines (
                                p_selected_line_tbl   => l_selected_line_tbl,
                                p_line_count          => 1,
                                p_sch_action          => 'UNSCHEDULE',
                                x_atp_tbl             => l_atp_tbl,
                                x_return_status       => l_return_status,
                                x_msg_count           => l_msg_count,
                                x_msg_data            => l_msg_data);

                            --5166476

                            --IF g_failed_records > 0 THEN
                            --IF OE_SCH_CONC_REQUESTS.oe_line_status_tbl.EXISTS(l_line_id) AND
                            --OE_SCH_CONC_REQUESTS.oe_line_status_tbl(l_line_id) = 'N' THEN
                            --Added as per bug 21079696
                            IF     OE_SCH_CONC_REQUESTS.oe_line_status_tbl.EXISTS (
                                       MOD (l_line_id,
                                            OE_GLOBALS.G_BINARY_LIMIT))
                               AND OE_SCH_CONC_REQUESTS.oe_line_status_tbl (
                                       MOD (l_line_id,
                                            OE_GLOBALS.G_BINARY_LIMIT)) =
                                   'N'
                            THEN
                                l_failure   := TRUE;
                            END IF;

                            --Bug 13810638
                            IF l_return_status IN
                                   (FND_API.G_RET_STS_ERROR, FND_API.G_RET_STS_UNEXP_ERROR)
                            THEN
                                --ROLLBACK TO SAVEPOINT Schedule_Line;
                                --Bug 18268780, call mrp cleanup which will rollback and cleanup both
                                mrp_cleanup ();

                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.add (
                                           '#### FAILURE #### LINE_ID - '
                                        || TO_CHAR (l_line_id)
                                        || ' ####');
                                END IF;

                                l_failure   := TRUE;
                            END IF;

                            IF l_debug_level > 0
                            THEN
                                oe_debug_pub.add (
                                       'R5 PROCESSED: '
                                    || l_rec_processed
                                    || ' FAILED: '
                                    || l_rec_failure,
                                    1);
                            END IF;
                        END IF;

                        --Bug 17543200, add to line count for commit later
                        l_line_count   := l_line_count + 1;
                    ELSIF p_sch_mode IN ('RESCHEDULE', 'RESCHEDULE_RD')
                    THEN
                        l_temp_flag    := FALSE;

                        IF l_debug_level > 0
                        THEN
                            oe_debug_pub.add (
                                TO_CHAR (l_line_id) || ' - Reschedule',
                                1);
                        END IF;

                        IF     l_smc_flag = 'Y'
                           AND l_top_model_line_id IS NOT NULL
                        THEN
                            l_temp_flag   :=
                                model_processed (l_top_model_line_id,
                                                 l_top_model_line_id);

                            --5166476
                            IF     l_temp_flag
                               AND --oe_line_status_tbl.EXISTS(l_top_model_line_id)  AND
                                   --oe_line_status_tbl(l_top_model_line_id) = 'N' THEN
                                   --oe_line_status_tbl(l_line_id) := 'N';
                                   --Added as per bug 21079696
                                   oe_line_status_tbl.EXISTS (
                                       MOD (l_top_model_line_id,
                                            OE_GLOBALS.G_BINARY_LIMIT))
                               AND oe_line_status_tbl (
                                       MOD (l_top_model_line_id,
                                            OE_GLOBALS.G_BINARY_LIMIT)) =
                                   'N'
                            THEN
                                oe_line_status_tbl (
                                    MOD (l_line_id,
                                         OE_GLOBALS.G_BINARY_LIMIT))   :=
                                    'N';

                                /*
                                 l_rec_processed := l_rec_processed + 1;
                                 l_rec_failure   := l_rec_failure + 1;
                                */
                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.add (
                                           'R6.1 PROCESSED: '
                                        || l_rec_processed
                                        || ' FAILED: '
                                        || l_rec_failure,
                                        1);
                                END IF;
                            END IF;
                        ELSIF l_ato_line_id IS NOT NULL
                        THEN
                            --l_ato_line_id = l_top_model_line_id THEN
                            l_temp_flag   :=
                                model_processed (l_ato_line_id,
                                                 l_ato_line_id);

                            --5166476
                            IF     l_temp_flag
                               AND --oe_line_status_tbl.EXISTS(l_ato_line_id) AND
                                   --oe_line_status_tbl(l_ato_line_id) = 'N' THEN
                                   -- oe_line_status_tbl(l_line_id) := 'N';
                                   --Added as per bug 21079696
                                   oe_line_status_tbl.EXISTS (
                                       MOD (l_ato_line_id,
                                            OE_GLOBALS.G_BINARY_LIMIT))
                               AND oe_line_status_tbl (
                                       MOD (l_ato_line_id,
                                            OE_GLOBALS.G_BINARY_LIMIT)) =
                                   'N'
                            THEN
                                oe_line_status_tbl (
                                    MOD (l_line_id,
                                         OE_GLOBALS.G_BINARY_LIMIT))   :=
                                    'N';

                                /*
                                l_rec_processed := l_rec_processed + 1;
                                l_rec_failure   := l_rec_failure + 1;
                                */
                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.add (
                                           'R6.2 PROCESSED: '
                                        || l_rec_processed
                                        || ' FAILED: '
                                        || l_rec_failure,
                                        1);
                                END IF;
                            END IF;
                        END IF;

                        /* If many of the lines selected are part of a set, then delayed
                         * request must get logged only for one of the lines.
                         */
                        IF    l_ship_set_id IS NOT NULL
                           OR l_arrival_set_id IS NOT NULL
                        THEN
                            l_temp_flag   :=
                                set_processed (
                                    NVL (l_ship_set_id, l_arrival_set_id));
                        END IF;

                        IF NOT l_temp_flag
                        THEN
                            -- Define a save point
                            SAVEPOINT Schedule_Line;

                            IF l_rec_processed > 1
                            THEN
                                l_init_msg_list   := FND_API.G_FALSE;
                            END IF;

                            oe_line_util.lock_row (
                                x_return_status   => l_return_status,
                                p_x_line_rec      => l_line_rec,
                                p_line_id         => l_line_id);

                            l_line_tbl (1)                       := l_line_rec;
                            l_old_line_tbl (1)                   := l_line_rec;

                            l_line_tbl (1).operation             :=
                                OE_GLOBALS.G_OPR_UPDATE;

                            IF p_sch_mode = 'RESCHEDULE_RD'
                            THEN
                                l_apply_sch_date   :=
                                    TRUNC (l_line_tbl (1).request_date); --Bug 18196688 Add trunc to request date
                            END IF;

                            l_line_tbl (1).ship_from_org_id      :=
                                NVL (p_apply_warehouse, l_ship_from_org_id);


                            IF l_apply_sch_date IS NOT NULL
                            THEN
                                IF l_order_date_type_code = 'SHIP'
                                THEN
                                    l_line_tbl (1).schedule_ship_date   :=
                                        l_apply_sch_date;
                                ELSE
                                    l_line_tbl (1).schedule_arrival_date   :=
                                        l_apply_sch_date;
                                END IF;
                            END IF;

                            --l_line_tbl(1).schedule_action_code := OE_SCHEDULE_UTIL.OESCH_ACT_RESCHEDULE;

                            --4892724
                            l_line_tbl (1).change_reason         := 'SYSTEM';
                            l_line_tbl (1).change_comments       :=
                                'SCHEDULE ORDERS CONCURRENT PROGRAM';

                            -- Call to process order
                            l_control_rec.controlled_operation   := TRUE;
                            l_control_rec.write_to_db            := TRUE;
                            --l_control_rec.PROCESS := FALSE;
                            l_control_rec.default_attributes     := TRUE;
                            l_control_rec.change_attributes      := TRUE;
                            l_process_order                      := TRUE;
                            l_control_rec.check_security         := TRUE; -- 5168540

                            g_process_records                    := 0;
                            g_failed_records                     := 0;

                            Oe_Order_Pvt.Lines (
                                p_validation_level   =>
                                    FND_API.G_VALID_LEVEL_FULL,
                                p_init_msg_list    => l_init_msg_list,
                                p_control_rec      => l_control_rec,
                                p_x_line_tbl       => l_line_tbl,
                                p_x_old_line_tbl   => l_old_line_tbl,
                                x_return_status    => l_return_status);

                            IF l_debug_level > 0
                            THEN
                                oe_debug_pub.add (
                                       'Oe_Order_Pvt.Lines returns with - '
                                    || l_return_status);
                            END IF;

                            IF l_return_status IN
                                   (FND_API.G_RET_STS_ERROR, FND_API.G_RET_STS_UNEXP_ERROR)
                            THEN
                                --ROLLBACK TO SAVEPOINT Schedule_Line;
                                --Bug 18268780, call mrp cleanup which will rollback and cleanup both
                                mrp_cleanup ();

                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.add (
                                           '#### FAILURE #### LINE_ID - '
                                        || TO_CHAR (l_line_id)
                                        || ' ####');
                                END IF;

                                --5166476
                                --OE_SCH_CONC_REQUESTS.oe_line_status_tbl(l_line_id) := 'N';
                                --Added as per bug 21079696
                                OE_SCH_CONC_REQUESTS.oe_line_status_tbl (
                                    MOD (l_line_id,
                                         OE_GLOBALS.G_BINARY_LIMIT))   :=
                                    'N';

                                --516476
                                IF     l_smc_flag = 'Y'
                                   AND l_top_model_line_id IS NOT NULL
                                THEN
                                    --OE_line_status_Tbl(l_top_model_line_id) := 'N';
                                    --Added as per bug 21079696
                                    OE_line_status_Tbl (
                                        MOD (l_top_model_line_id,
                                             OE_GLOBALS.G_BINARY_LIMIT))   :=
                                        'N';
                                ELSIF l_ato_line_id IS NOT NULL
                                THEN
                                    --OE_line_status_Tbl(l_ato_line_id) := 'N';
                                    --Added as per bug 21079696
                                    OE_line_status_Tbl (
                                        MOD (l_ato_line_id,
                                             OE_GLOBALS.G_BINARY_LIMIT))   :=
                                        'N';
                                END IF;

                                l_failure   := TRUE;
                            END IF;

                            IF l_debug_level > 0
                            THEN
                                oe_debug_pub.add (
                                       'R6 PROCESSED: '
                                    || l_rec_processed
                                    || ' FAILED: '
                                    || l_rec_failure,
                                    1);
                            END IF;
                        END IF;


                        --Bug 18015878, increment the line count for reschedule/reschedule_rd mode
                        l_line_count   := l_line_count + 1;
                    END IF;                                   -- line eligible

                    IF     l_process_order = TRUE
                       AND l_return_status = FND_API.G_RET_STS_SUCCESS
                    THEN
                        IF l_debug_level > 0
                        THEN
                            oe_debug_pub.add ('After Call to Process Order ',
                                              1);
                        END IF;

                        BEGIN
                            l_control_rec.controlled_operation   := TRUE;
                            l_control_rec.process                := TRUE;
                            l_control_rec.process_entity         :=
                                OE_GLOBALS.G_ENTITY_ALL;
                            l_control_rec.check_security         := FALSE;
                            l_control_rec.clear_dependents       := FALSE;
                            l_control_rec.default_attributes     := FALSE;
                            l_control_rec.change_attributes      := FALSE;
                            l_control_rec.validate_entity        := FALSE;
                            l_control_rec.write_to_DB            := FALSE;

                            --  Instruct API to clear its request table

                            l_control_rec.clear_api_cache        := FALSE;
                            l_control_rec.clear_api_requests     := TRUE;

                            oe_line_util.Post_Line_Process (
                                p_control_rec   => l_control_rec,
                                p_x_line_tbl    => l_line_tbl);
                            g_process_records                    := 0;
                            g_failed_records                     := 0;

                            IF l_debug_level > 0
                            THEN
                                oe_debug_pub.add (
                                    'GOING TO EXECUTE DELAYED REQUESTS ',
                                    2);
                            END IF;

                            OE_DELAYED_REQUESTS_PVT.Process_Delayed_Requests (
                                x_return_status   => l_return_status);

                            IF l_return_status IN
                                   (FND_API.G_RET_STS_ERROR, FND_API.G_RET_STS_UNEXP_ERROR)
                            THEN
                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.add (
                                           '#### FAILURE #### LINE_ID - '
                                        || TO_CHAR (l_line_id)
                                        || ' ####');
                                END IF;

                                l_failure   := TRUE;

                                OE_Delayed_Requests_PVT.Clear_Request (
                                    l_return_status);

                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.add (
                                           'AFTER CLEARING DELAYED REQUESTS: '
                                        || l_return_status,
                                        2);
                                END IF;

                                --ROLLBACK TO SAVEPOINT Schedule_Line;
                                --Bug 18268780, call mrp cleanup which will rollback and cleanup both
                                mrp_cleanup ();
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.add (
                                        'IN WHEN OTHERS, Error:' || SQLERRM,
                                        2);
                                END IF;

                                OE_Delayed_Requests_PVT.Clear_Request (
                                    l_return_status);

                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.add (
                                        'IN WHEN OTHERS ' || l_return_status,
                                        2);
                                END IF;
                        END;

                        l_process_order   := FALSE;
                    ELSE              -- (5174789)Return status is not success
                        OE_DELAYED_REQUESTS_PVT.Clear_Request (
                            l_return_status);
                        l_process_order   := FALSE;
                    END IF;

                    --Bug 17543200, commit after every 1000 records by default
                    --Bug 18015878, add RESCHEDULE/RESCHEDULE_RD mode also
                    IF p_sch_mode IN ('SCHEDULE', 'UNSCHEDULE', 'RESCHEDULE',
                                      'RESCHEDULE_RD')
                    THEN
                        IF l_line_count >= l_commit_threshold
                        THEN
                            IF l_debug_level > 0
                            THEN
                                oe_debug_pub.add (
                                    'COMMITING records:' || l_line_count,
                                    1);
                            END IF;

                            -- ER18493998 - Check for reservation validity before commit
                            OE_SCHEDULE_UTIL.Post_Forms_Commit (
                                l_rsv_return_status,
                                l_rsv_msg_count,
                                l_rsv_msg_data);
                            COMMIT;
                            l_line_count   := 0;
                        END IF;
                    END IF;
                END IF;

               <<END_LOOP>>                         -- ER18493998  added this.
                NULL;                            --no action here. Loop again.
            END LOOP;                   -- loop for each row of dynamic query.

            -- close the cursor
            DBMS_SQL.Close_Cursor (l_cursor_id);

            -- ER18493998 Start
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                       'total records selected for processing is:'
                    || l_total_lines_cnt);
                oe_debug_pub.ADD (
                    'insert the records in bulk table for processing');
            END IF;

            g_total_lines_cnt         := l_total_lines_cnt;

            IF p_bulk_processing = 'Y'
            THEN
                IF p_sch_mode IN ('RESCHEDULE', 'RESCHEDULE_RD')
                THEN
                    l_sch_action   := 'RESCHEDULE';
                ELSIF p_sch_mode = 'SCHEDULE'
                THEN
                    l_sch_action   := 'SCHEDULE';
                ELSIF p_sch_mode = 'UNSCHEDULE'
                THEN
                    l_sch_action   := 'UNSCHEDULE';
                END IF;

                IF NVL (p_num_instances, 1) <= 1
                THEN
                    IF l_debug_level > 0
                    THEN
                        oe_debug_pub.ADD (
                            'number of instances is not more. Process in the parent run itself');
                    END IF;

                    FORALL x
                        IN g_bulk_reschedule_table.FIRST ..
                           g_bulk_reschedule_table.LAST
                        INSERT INTO oe_bulk_schedule_temp (
                                        parent_request_id,
                                        child_request_id,
                                        org_id,
                                        line_id,
                                        processing_order,
                                        group_number,
                                        processed,
                                        ship_set_id,
                                        arrival_set_id,
                                        top_model_line_id,
                                        schedule_ship_date,
                                        schedule_arrival_date,
                                        request_date,
                                        ship_from_org_id,
                                        attribute1,
                                        attribute2,
                                        attribute3,
                                        attribute4,
                                        attribute5,
                                        date1,
                                        date2,
                                        date3,
                                        date4,
                                        date5)
                                 VALUES (
                                            TO_NUMBER (l_request_id),
                                            TO_NUMBER (l_request_id),
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

                    COMMIT;                         --commit in the bulk table

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

                    g_conc_program   := 'Y';
                    g_recorded       := 'N';
                    g_request_id     := TO_NUMBER (l_request_id);

                    l_line_index     := 0;

                    OPEN c_get_child_lines (TO_NUMBER (l_request_id));

                    LOOP
                        FETCH c_get_child_lines
                            INTO l_line_id, l_org_id, l_processing_order, l_group_number,
                                 l_ship_from_org_id, l_ssd, l_sad;

                        EXIT WHEN c_get_child_lines%NOTFOUND;

                        --IF NOT l_single_org AND l_org_id <> l_old_org_id
                        IF    (NOT l_single_org AND l_org_id <> l_old_org_id) --Bug 21132131, this replaces above IF
                           OR (p_commit_threshold IS NOT NULL AND l_line_index >= p_commit_threshold AND l_group_number <> NVL (l_old_group_number, l_group_number))
                        THEN
                            l_old_org_id   := l_org_id;

                            -- Send the lines for processing as org changed.
                            IF l_selected_line_tbl.COUNT > 0
                            THEN
                                IF l_debug_level > 0
                                THEN
                                    oe_debug_pub.ADD (
                                           'before calling process bulk 1:'
                                        || l_selected_line_tbl.COUNT);
                                END IF;

                                process_bulk (
                                    p_selected_tbl    => l_selected_line_tbl,
                                    p_sch_action      => l_sch_action,
                                    x_return_status   => l_return_status);

                                l_selected_line_tbl.DELETE;
                                l_line_index   := 0;
                                COMMIT; --should we addd commit to inside process_bulk
                            END IF;

                            mo_global.set_policy_context (
                                p_access_mode   => 'S',
                                p_org_id        => l_org_id);
                        END IF;

                        l_old_group_number                         := l_group_number; --Bug 21132131
                        l_line_index                               := l_line_index + 1;
                        l_selected_line_tbl (l_line_index).id1     := l_line_id;
                        l_selected_line_tbl (l_line_index).id2     :=
                            l_ship_from_org_id;
                        l_selected_line_tbl (l_line_index).id3     :=
                            l_group_number;
                        l_selected_line_tbl (l_line_index).date1   := l_ssd;
                        l_selected_line_tbl (l_line_index).date2   := l_sad;
                        l_selected_line_tbl (l_line_index).org_id   :=
                            l_org_id;
                    /* Bug 21132131, not needed
                 IF     p_commit_threshold IS NOT NULL
                    AND l_line_index = p_commit_threshold
                 THEN
                    IF l_debug_level  > 0 THEN
                       oe_debug_pub.ADD (   'before calling process bulk 2:'
                     || l_selected_line_tbl.Count );
                        END IF;
                 process_bulk (p_selected_tbl       => l_selected_line_tbl,
                               p_sch_action         => l_sch_action,
                 x_return_status      => l_return_status
                        );
                 l_selected_line_tbl.DELETE;
                 l_line_index := 0;
                 COMMIT;
               END IF;
                  */
                    --Bug 21132131
                    END LOOP;

                    CLOSE c_get_child_lines;

                    --See if there are pending records still
                    IF l_selected_line_tbl.COUNT > 0
                    THEN
                        IF l_debug_level > 0
                        THEN
                            oe_debug_pub.ADD (
                                   'before calling process bulk 3:'
                                || l_selected_line_tbl.COUNT);
                        END IF;

                        process_bulk (p_selected_tbl    => l_selected_line_tbl,
                                      p_sch_action      => l_sch_action,
                                      x_return_status   => l_return_status);
                        l_selected_line_tbl.DELETE;
                    END IF;

                    --Bug 21132131, delete from table.
                    DELETE FROM oe_bulk_schedule_temp
                          WHERE child_request_id = l_request_id;
                ELSE
                    IF l_debug_level > 0
                    THEN
                        oe_debug_pub.ADD (
                            'number of instances is more. Spawn children');
                    END IF;

                    spawn_child_requests (
                        p_commit_threshold   => p_commit_threshold,
                        p_num_instances      => p_num_instances,
                        p_sch_action         => l_sch_action,
                        p_request_id         => TO_NUMBER (l_request_id),
                        p_org_id             => p_org_id,
                        x_return_status      => l_result);
                END IF;
            END IF;
        -- ER18493998 End

        END IF;                              -- if parameters passed are null.

        OE_MSG_PUB.Save_Messages (p_request_id => TO_NUMBER (l_request_id));
        --5166476
        --l_rec_success := l_rec_processed - l_rec_failure;
        l_rec_success     := 0;
        l_rec_processed   := 0;
        l_rec_failure     := 0;
        l_index           := OE_SCH_CONC_REQUESTS.oe_line_status_tbl.FIRST;

        WHILE l_index IS NOT NULL
        LOOP
            --oe_debug_pub.add(  'R7 : '||l_index||' Status: '||oe_line_status_tbl(l_index), 1 ) ;
            --IF OE_SCH_CONC_REQUESTS.oe_line_status_tbl(l_index) = 'Y' THEN
            --Added as per bug 21079696
            IF OE_SCH_CONC_REQUESTS.oe_line_status_tbl (
                   MOD (l_index, OE_GLOBALS.G_BINARY_LIMIT)) =
               'Y'
            THEN
                l_rec_success   := l_rec_success + 1;
            ELSE
                l_rec_failure   := l_rec_failure + 1;
            END IF;

            l_rec_processed   := l_rec_processed + 1;
            --l_index := OE_SCH_CONC_REQUESTS.oe_line_status_tbl.NEXT(l_index);
            --Added as per bug 21079696
            l_index           :=
                OE_SCH_CONC_REQUESTS.oe_line_status_tbl.NEXT (
                    MOD (l_index, OE_GLOBALS.G_BINARY_LIMIT));
        END LOOP;

        -- ER18493998 Start
        -- Delete all the records from temp table
        IF p_sch_mode IN
               ('BULK_SCH_CHILD', 'BULK_RESCH_CHILD', 'BULK_UNSCH_CHILD')
        THEN                                         -- Bug 20273441 : Issue 7
            IF l_debug_level > 0
            THEN
                oe_debug_pub.add (
                    'Deleting records from oe_bulk_schedule_temp for current request',
                    1);
            END IF;

            DELETE FROM oe_bulk_schedule_temp
                  WHERE child_request_id = l_request_id;
        END IF;

        -- ER18493998 End

        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Total Lines Selected : ' || l_rec_processed);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Lines Failed : ' || l_rec_failure);
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Lines Successfully Processed : ' || l_rec_success);

        -- ER18493998- Check for reservation validity before commit
        OE_SCHEDULE_UTIL.Post_Forms_Commit (l_rsv_return_status,
                                            l_rsv_msg_count,
                                            l_rsv_msg_data);

        IF l_failure OR l_rec_failure > 0
        THEN                                         -- Bug 20273441 : Issue 2
            RETCODE   := 1;
        END IF;
    EXCEPTION
        WHEN FND_API.G_EXC_ERROR
        THEN
            fnd_file.put_line (
                FND_FILE.LOG,
                'Error executing Scheduling, Exception:G_EXC_ERROR');
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            fnd_file.put_line (
                FND_FILE.LOG,
                'Error executing Scheduling, Exception:G_EXC_UNEXPECTED_ERROR');
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                FND_FILE.LOG,
                'Unexpected error in OE_SCH_CONC_REQUESTS.Request');
            fnd_file.put_line (FND_FILE.LOG, SUBSTR (SQLERRM, 1, 2000));

            --Added as per bug 21079696
            IF DBMS_SQL.IS_OPEN (l_cursor_id)
            THEN
                DBMS_SQL.Close_Cursor (l_cursor_id);
            END IF;
    END Request;
END xxd_ont_sch_conc_requests_pkg;
/
