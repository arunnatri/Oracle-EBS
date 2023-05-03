--
-- XXDO_ATP_CALCULATION_EBS  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ATP_CALCULATION_EBS"
AS
    /******************************************************************************************************
    * Package Name  : XXDO_ATP_CALCULATION_EBS
    *
    * Description   : Package called by the concurrent program "Program to Refresh ATP -  EBS" (refresh_atp procedure)
    *
    * Maintenance History
    * -------------------
    * Date          Author          Version          Change Description
    * -----------   ------          ---------------  ------------------------------
    * DD-MON-YYYY   Deckers         NA               Initial Version
    * 28-Dec-2020   Jayarajan A K   1.1              Modified for CCR0008870 - Global Inventory Allocation Project
    ********************************************************************************************************/
    gn_user_id             NUMBER := fnd_profile.VALUE ('USER_ID');
    gn_resp_appl_id        NUMBER := fnd_profile.VALUE ('RESP_APPL_ID');

    gl_force_std_atr       VARCHAR2 (1)
        := NVL (SUBSTR (fnd_profile.VALUE ('XXDO_ATP_CALC_STD_ATR'), 1, 1),
                'N');

    gl_indent_depth        NUMBER := 3;
    gl_dop                 NUMBER
        := TO_NUMBER (
               NVL (SUBSTR (fnd_profile.VALUE ('XXDO_ATP_CALC_DOP'), 1, 2),
                    '6'));
    gl_table_owner         VARCHAR2 (10) := 'XXDO';
    gl_package_name        VARCHAR2 (50) := 'xxdo_atp_calculation_ebs';
    gl_ascp_db_link_name   VARCHAR2 (50)
        := NVL (fnd_profile.VALUE ('XXDO_ATP_CALC_DB_LINK'),
                'BT_EBS_TO_ASCP');

    gl_start_ms            NUMBER;
    gl_last_ms             NUMBER;

    gl_debug_enabled       VARCHAR2 (1)
        := NVL (SUBSTR (fnd_profile.VALUE ('XXDO_ATP_CALC_DEBUG'), 1, 1),
                'Y');
    gl_debug_level         NUMBER := 10000;

    gl_refresh_number      NUMBER;
    gl_refresh_type        VARCHAR2 (20);
    gl_refresh_phase       VARCHAR2 (20);
    gl_table_name          VARCHAR2 (20);
    gl_indent              NUMBER := 0;
    gl_snap_time           TIMESTAMP (6) WITH TIME ZONE := SYSTIMESTAMP;

    PROCEDURE update_control (p_status      IN VARCHAR2 := NULL,
                              p_milestone   IN NUMBER := NULL);


    FUNCTION get_ms
        RETURN NUMBER
    IS
        l_cur   TIMESTAMP (6) WITH TIME ZONE := SYSTIMESTAMP;
    BEGIN
        RETURN   TO_NUMBER (TO_CHAR (l_cur, 'ss.FF')) * 1000
               + TO_NUMBER (TO_CHAR (l_cur, 'MI')) * 60000
               + TO_NUMBER (TO_CHAR (l_cur, 'HH24')) * 3600000
               + TO_NUMBER (TO_CHAR (l_cur, 'J')) * 86400000;
    END;

    FUNCTION get_elapsed_ms
        RETURN NUMBER
    IS
    BEGIN
        RETURN get_ms - gl_start_ms;
    END;

    PROCEDURE msg (p_msg VARCHAR2, p_level NUMBER:= 10000)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_ms         NUMBER;
        l_delta_ms   NUMBER;
        l_message    VARCHAR2 (2000);
    BEGIN
        IF gl_start_ms IS NULL
        THEN
            gl_start_ms   := get_ms;
        END IF;

        IF gl_last_ms IS NULL
        THEN
            gl_last_ms   := 0;
        END IF;

        IF gl_indent IS NULL
        THEN
            gl_indent   := 0;
        END IF;

        fnd_file.put_line (fnd_file.LOG, p_msg);

        IF NOT gl_debug_enabled = 'Y' OR p_level < gl_debug_level
        THEN
            RETURN;
        END IF;

        IF SUBSTR (p_msg, 1, 1) = '+'
        THEN
            gl_indent   := gl_indent + 1;
            DBMS_APPLICATION_INFO.set_action (
                SUBSTR (p_msg, INSTR (p_msg, '.') + 1));
        END IF;

        l_ms         := get_elapsed_ms;
        l_delta_ms   := l_ms - gl_last_ms;
        gl_last_ms   := l_ms;
        l_message    :=
            SUBSTR (
                   TO_CHAR (l_ms, '00,000,000.000')
                || ' - '
                || TO_CHAR (l_delta_ms, '000,000.000')
                || ' - '
                || LPAD (' ', gl_indent * gl_indent_depth)
                || p_msg,
                1,
                1999);

        INSERT INTO xxdo.xxdo_debug (created_by, session_id, application_id,
                                     debug_text, call_stack, request_id)
                 VALUES (gn_user_id,
                         USERENV ('SESSIONID'),
                         gn_resp_appl_id,
                         l_message,
                         DBMS_UTILITY.FORMAT_CALL_STACK,
                         fnd_global.conc_request_id);

        IF SUBSTR (p_msg, 1, 1) = '-'
        THEN
            gl_indent   := gl_indent - 1;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                ROLLBACK;
                l_message   := SQLERRM;

                INSERT INTO xxdo.xxdo_debug (debug_text)
                     VALUES (l_message);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
            END;
    END;

    PROCEDURE clean_tables (x_msg OUT VARCHAR2, x_ret_stat IN OUT VARCHAR2)
    IS
        l_name   VARCHAR2 (100) := gl_package_name || '.' || 'clean_tables';
    BEGIN
        msg ('+' || l_name);

        EXECUTE IMMEDIATE   'truncate table '
                         || gl_table_owner
                         || '.xxdo_atr_dirty';

        EXECUTE IMMEDIATE   'truncate table '
                         || gl_table_owner
                         || '.xxdo_atr_stage';

        EXECUTE IMMEDIATE   'truncate table '
                         || gl_table_owner
                         || '.xxdo_atr_inc';

        EXECUTE IMMEDIATE   'truncate table '
                         || gl_table_owner
                         || '.xxdo_atp_stage';

        EXECUTE IMMEDIATE   'truncate table '
                         || gl_table_owner
                         || '.xxdo_atp_master_stage';

        msg ('-' || l_name || ' (' || x_ret_stat || ')');
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                x_ret_stat   := g_ret_unexp;
                x_msg        := SQLERRM;
                msg (x_msg);
                msg ('-' || l_name || ' (' || x_ret_stat || ')');
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_unexp;
                    x_msg        := SQLERRM;
            END;
    END;

    FUNCTION allocate_refresh_number
        RETURN NUMBER
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name             VARCHAR2 (100)
                               := gl_package_name || '.' || 'allocate_refresh_number';
        l_refresh_number   NUMBER;
    BEGIN
        msg ('+' || l_name);

        INSERT INTO xxdo.xxdo_atp_control (refresh_number, submit_time)
             VALUES (
                        (SELECT NVL ((SELECT MAX (refresh_number) FROM xxdo.xxdo_atp_control), 0) + 1 FROM DUAL),
                        SYSTIMESTAMP)
          RETURNING refresh_number
               INTO l_refresh_number;

        COMMIT;
        msg ('-' || l_name);
        RETURN l_refresh_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                ROLLBACK;
                msg (SQLERRM);
                msg ('-' || l_name);
                RAISE;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
                    RAISE;
            END;
    END;

    PROCEDURE update_control (p_status      IN VARCHAR2 := NULL,
                              p_milestone   IN NUMBER := NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        x_msg       VARCHAR2 (240);
        l_elapsed   NUMBER;
        l_now       TIMESTAMP (6) WITH TIME ZONE;
    BEGIN
        l_elapsed   := get_elapsed_ms;
        l_now       := SYSTIMESTAMP;

        IF p_status IS NOT NULL
        THEN
            IF p_status IN (g_status_complete, g_status_error)
            THEN
                UPDATE xxdo.xxdo_atp_control
                   SET status = p_status, end_time = l_now, duration = l_elapsed
                 WHERE refresh_number = gl_refresh_number;
            ELSIF p_status = g_status_processing
            THEN
                UPDATE xxdo.xxdo_atp_control
                   SET status = p_status, snap_time = gl_snap_time
                 WHERE refresh_number = gl_refresh_number;
            ELSIF p_status = g_status_submitted
            THEN
                UPDATE xxdo.xxdo_atp_control
                   SET status = p_status, start_time = l_now, milestone_01 = l_elapsed,
                       last_milestone = l_now
                 WHERE refresh_number = gl_refresh_number;
            ELSE
                UPDATE xxdo.xxdo_atp_control
                   SET status   = p_status
                 WHERE refresh_number = gl_refresh_number;
            END IF;
        END IF;

        IF p_milestone IS NOT NULL AND p_milestone BETWEEN 2 AND 19
        THEN
            EXECUTE IMMEDIATE   'update '
                             || gl_table_owner
                             || '.xxdo_atp_control 
                         set milestone_'
                             || TRIM (TO_CHAR (p_milestone, '00'))
                             || ' = '
                             || l_elapsed
                             || '
                           , last_milestone = to_timestamp_tz ('''
                             || TO_CHAR (SYSTIMESTAMP,
                                         'MM/DD/YYYY HH24:MI:SS.FF TZH:TZM')
                             || ''', ''MM/DD/YYYY HH24:MI:SS.FF TZH:TZM'') 
                         where refresh_number = '
                             || gl_refresh_number;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                x_msg   := SQLERRM;
                ROLLBACK;
                msg (x_msg);
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_msg   := SQLERRM;
                    ROLLBACK;
            END;
    END;

    FUNCTION single_atp (p_source_org_id IN NUMBER, p_inventory_item_id IN NUMBER, p_req_ship_Date IN DATE
                         , p_demand_class IN VARCHAR2)
        RETURN NUMBER
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        x_return_status       VARCHAR2 (2000);
        x_msg_data            VARCHAR2 (500);
        x_msg_count           NUMBER;
        l_atp_rec             apps.mrp_atp_pub.atp_rec_typ;
        x_atp_rec             apps.mrp_atp_pub.atp_rec_typ;
        x_atp_supply_demand   apps.mrp_atp_pub.atp_supply_demand_typ;
        x_atp_period          apps.mrp_atp_pub.atp_period_typ;
        x_atp_details         apps.mrp_atp_pub.atp_details_typ;
        l_session_id          NUMBER;
    BEGIN
        apps.msc_atp_global.extend_atp (l_atp_rec, x_return_status, 1);
        --
        l_atp_rec.action (1)                   := 100;
        l_atp_rec.oe_flag (1)                  := 'N';
        l_atp_rec.insert_flag (1)              := 1;
        l_atp_rec.calling_module (1)           := 660;
        l_atp_rec.quantity_ordered (1)         := 10000000;

        --
        SELECT primary_uom_code, apps.oe_order_sch_util.get_session_id
          INTO l_atp_rec.quantity_uom (1), l_session_id
          FROM apps.mtl_system_items_b
         WHERE     organization_id = p_source_org_id
               AND inventory_item_id = p_inventory_item_id;

        l_atp_rec.Demand_Class (1)             := p_demand_class;
        l_atp_rec.requested_ship_date (1)      := p_req_ship_Date;
        l_atp_rec.source_organization_id (1)   := p_source_org_id;
        l_atp_rec.inventory_item_id (1)        := p_inventory_item_id;
        apps.mrp_atp_pub.call_atp (
            p_session_id          => l_session_id,
            p_atp_rec             => l_atp_rec,
            x_atp_rec             => x_atp_rec,
            x_atp_supply_demand   => x_atp_supply_demand,
            x_atp_period          => x_atp_period,
            x_atp_details         => x_atp_details,
            x_return_status       => x_return_status,
            x_msg_data            => x_msg_data,
            x_msg_count           => x_msg_count);
        ROLLBACK;
        RETURN x_atp_rec.Requested_Date_Quantity (1);
    END;

    FUNCTION single_atr (p_source_org_id       IN NUMBER,
                         p_inventory_item_id   IN NUMBER)
        RETURN NUMBER
    IS
        x_atr                 NUMBER;
        x_qoh                 NUMBER;
        v_api_return_status   VARCHAR2 (1);
        x_rqoh                NUMBER;
        x_qr                  NUMBER;
        x_qs                  NUMBER;
        x_att                 NUMBER;
        v_msg_count           NUMBER;
        v_msg_data            VARCHAR2 (4000);
        x_return_status       VARCHAR2 (1);
    BEGIN
        inv_quantity_tree_grp.clear_quantity_cache;
        apps.inv_quantity_tree_pub.query_quantities (
            p_api_version_number    => 1,
            p_init_msg_lst          => fnd_api.g_false,
            x_return_status         => x_return_status,
            x_msg_count             => v_msg_count,
            x_msg_data              => v_msg_data,
            p_organization_id       => p_source_org_id,
            p_inventory_item_id     => p_inventory_item_id,
            p_tree_mode             =>
                apps.inv_quantity_tree_pub.g_transaction_mode, --p_onhand_source => APPS.INV_QUANTITY_TREE_PVT.g_all_subs, -3,
            p_is_revision_control   => FALSE,
            p_is_lot_control        => FALSE,
            p_is_serial_control     => FALSE,
            p_revision              => NULL,
            p_lot_number            => NULL,
            p_subinventory_code     => NULL,
            p_locator_id            => NULL,
            x_qoh                   => x_qoh,
            x_rqoh                  => x_rqoh,
            x_qr                    => x_qr,
            x_qs                    => x_qs,
            x_att                   => x_att,
            x_atr                   => x_atr);

        IF (x_return_status = 'S')
        THEN
            RETURN x_atr;
        ELSE
            RETURN NULL;
        END IF;
    END;


    PROCEDURE launch_ascp_refresh (p_force_full IN VARCHAR2, p_ascp_refresh_number OUT NUMBER, x_msg OUT VARCHAR2
                                   , x_ret_stat IN OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name          VARCHAR2 (100)
                            := gl_package_name || '.' || 'launch_ascp_refresh';
        l_refresh_num   NUMBER;
    BEGIN
        msg ('+' || l_name);

        EXECUTE IMMEDIATE   '
                      begin
                      xxdo_atp_calculation.launch_atp_refresh@'
                         || gl_ascp_db_link_name
                         || ' 
                                                 ( x_ascp_refresh_number => :a
                                                 , x_ret_stat => :b
                                                 , x_msg => :c
                                                 , p_force_full => :d
                                                 , p_ebs_refresh_number=> :e
                                                 , p_ebs_snap_time => :f
                                                 );
                      end;
                    '
            USING OUT p_ascp_refresh_number, OUT x_ret_stat, OUT x_msg,
                  IN p_force_full, IN gl_refresh_number, IN gl_snap_time;

        IF x_ret_stat = g_ret_success
        THEN
            UPDATE xxdo.xxdo_atp_control
               SET ascp_refresh_number   = p_ascp_refresh_number
             WHERE refresh_number = gl_refresh_number;

            COMMIT;
        ELSE
            msg ('x_msg: ' || x_msg);
        END IF;

        COMMIT;
        msg ('-' || l_name || ' (' || x_ret_stat || ')');
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                x_ret_stat   := g_ret_unexp;
                x_msg        := SQLERRM;
                ROLLBACK;
                msg (x_msg);
                msg ('-' || l_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_unexp;
                    x_msg        := SQLERRM;
                    ROLLBACK;
            END;
    END;

    PROCEDURE wait_for_ascp_refresh (p_ascp_refresh_number IN NUMBER, x_msg OUT VARCHAR2, x_ret_stat IN OUT VARCHAR2)
    IS
        l_name          VARCHAR2 (100)
                            := gl_package_name || '.' || 'wait_for_ascp_refresh';
        l_refresh_num   NUMBER;
        l_msg           VARCHAR2 (240);
    BEGIN
        msg ('+' || l_name);

        EXECUTE IMMEDIATE   '
                      begin
                      xxdo_atp_calculation.blocking_sync@'
                         || gl_ascp_db_link_name
                         || '(p_refresh_number=>:a, x_msg => :b, x_ret_stat => :c);
                      end;
                    '
            USING IN p_ascp_refresh_number, OUT x_msg, OUT x_ret_stat;

        msg ('-' || l_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := g_ret_unexp;
            l_msg        := SQLERRM;
            msg (l_msg);
            msg ('-' || l_name);
            RAISE;
    END;

    PROCEDURE copy_atp_results (x_msg           OUT VARCHAR2,
                                x_ret_stat   IN OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name        VARCHAR2 (100)
                          := gl_package_name || '.' || 'copy_atp_results';
        l_tablename   VARCHAR2 (240) := 'XXDO_ATP_STAGE';
    BEGIN
        msg ('+' || l_name);

        EXECUTE IMMEDIATE   'truncate table '
                         || gl_table_owner
                         || '.'
                         || l_tablename;

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' unusable';
        END LOOP;

        EXECUTE IMMEDIATE   '
                    insert /*+ APPEND PARALLEL('
                         || gl_dop
                         || ') */
                           into '
                         || gl_table_owner
                         || '.'
                         || l_tablename
                         || ' (
                                                                          refresh_number
                                                                        , refresh_time
                                                                        , demand_class
                                                                        , priority
                                                                        , organization_id
                                                                        , inventory_item_id
                                                                        , dte
                                                                        , atp
                                                                        , atp_w_s
																	  --Start changes v1.1
                                                                        , atp_wb_ro  
                                                                        , atp_wb_rc
                                                                        , atp_wb_re
                                                                        , atp_wb_rp
                                                                        , atp_wb_rm
                                                                        , atp_wb_ec
																	  --End changes v1.1
                                                                       )
                         ( 
                           select /*+PARALLEL('
                         || gl_dop
                         || ')*/
                                  xaf.ebs_refresh_number refresh_number
                                , xaf.ebs_refresh_time refresh_time
                                , xaf.demand_class
                                , xaf.priority
                                , xaf.organization_id
                                , xaf.inventory_item_id
                                , xaf.dte
                                , trunc(xaf.atp)
                                , trunc(xaf.atp_w_s)
						      --Start changes v1.1
                                , trunc(xaf.atp_wb_ro)  
                                , trunc(xaf.atp_wb_rc)
                                , trunc(xaf.atp_wb_re)
                                , trunc(xaf.atp_wb_rp)
                                , trunc(xaf.atp_wb_rm)
                                , trunc(xaf.atp_wb_ec)
						      --End changes v1.1
                             from '
                         || gl_table_owner
                         || '.xxdo_atp_final@'
                         || gl_ascp_db_link_name
                         || ' xaf
                         )
                    ';

        DBMS_STATS.gather_table_Stats (ownname => gl_table_owner, tabname => l_tablename, method_opt => 'FOR ALL COLUMNS'
                                       , degree => gl_dop);

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' rebuild online parallel (degree 3 instances 2)';
        END LOOP;

        COMMIT;

        EXECUTE IMMEDIATE   'alter table '
                         || gl_table_owner
                         || '.xxdo_atp_final exchange partition p1 with table '
                         || gl_table_owner
                         || '.'
                         || l_tablename
                         || ' including indexes';

        COMMIT;
        msg ('-' || l_name || ' (' || x_ret_stat || ')');
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                x_ret_stat   := g_ret_unexp;
                x_msg        := SQLERRM;
                ROLLBACK;
                msg (x_msg);
                msg ('-' || l_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_unexp;
                    x_msg        := SQLERRM;
                    ROLLBACK;
            END;
    END;

    PROCEDURE populate_atr (x_msg OUT VARCHAR2, x_ret_stat IN OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name        VARCHAR2 (100) := gl_package_name || '.' || 'populate_atr';
        l_tablename   VARCHAR2 (240) := 'XXDO_ATR_STAGE';
    BEGIN
        msg ('+' || l_name);

        EXECUTE IMMEDIATE   'truncate table '
                         || gl_table_owner
                         || '.'
                         || l_tablename;

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' unusable';
        END LOOP;

        IF gl_force_std_atr = 'N'
        THEN
            EXECUTE IMMEDIATE   '
                        insert /*+ APPEND PARALLEL('
                             || gl_dop
                             || ') */
                          into '
                             || gl_table_owner
                             || '.'
                             || l_tablename
                             || ' (refresh_number, refresh_time, organization_id, inventory_item_id, atr) 
                                (
                                select /*+PARALLEL('
                             || gl_dop
                             || ')*/
                                      '
                             || gl_refresh_number
                             || ' refresh_number
                                     , to_timestamp_tz ('''
                             || TO_CHAR (gl_snap_time,
                                         'MM/DD/YYYY HH24:MI:SS.FF TZH:TZM')
                             || ''', ''MM/DD/YYYY HH24:MI:SS.FF TZH:TZM'')
                                     , organization_id
                                     , inventory_item_id
                                     , sum(qty) atr
                                  from (
                                        select organization_id
                                             , inventory_item_id
                                             , qty 
                                          from (select moqd.organization_id
                                                     , moqd.inventory_item_id
                                                     , nvl(moqd.primary_transaction_quantity, 0) as qty
                                                  from apps.mtl_onhand_quantities_Detail moqd
                                                     , apps.mtl_secondary_inventories msi
                                                  where msi.organization_id = moqd.organization_id
                                                    and msi.secondary_inventory_name = moqd.subinventory_code
                                                    and msi.reservable_type = 1     
                                                union all           
                                                select mr.organization_id
                                                     , mr.inventory_item_id
                                                     , -nvl(mr.primary_reservation_quantity - nvl(mr.detailed_quantity,0), 0) as qty
                                                  from apps.mtl_reservations mr 
                                                  where nvl(mr.supply_source_type_id, 13) = 13
                                                    and mr.primary_reservation_quantity > nvl(mr.detailed_quantity,0)
                                                union all      
                                                select mmtt.organization_id, mmtt.inventory_item_id, -nvl(primary_quantity, 0) qty
                                                  from apps.mtl_secondary_inventories msi 
                                                     , apps.mtl_material_transactions_temp mmtt
                                                  where msi.reservable_type = 1
                                                    and mmtt.posting_flag = ''Y''
                                                    and (nvl(mmtt.transaction_status,0) <> 2 OR (nvl(mmtt.transaction_status,0) = 2 AND mmtt.transaction_action_id IN (1, 2, 28, 3, 21, 29, 32, 34)))
                                                    and mmtt.transaction_action_id NOT IN (24,30) 
                                                    and mmtt.organization_id = msi.organization_id
                                                    and mmtt.subinventory_code = msi.secondary_inventory_name
                                                union all      
                                                select mmtt.organization_id, mmtt.inventory_item_id, nvl(primary_quantity, 0) qty
                                                  from apps.mtl_secondary_inventories msi 
                                                     , apps.mtl_material_transactions_temp mmtt
                                                  where msi.reservable_type = 1
                                                    and mmtt.posting_flag = ''Y''
                                                    and nvl(mmtt.transaction_status,0) = 2 
                                                    AND mmtt.transaction_action_id = 2
                                                    and mmtt.organization_id = msi.organization_id
                                                    and mmtt.transfer_subinventory = msi.secondary_inventory_name
                                                ) 
                                       )
                                  group by organization_id
                                         , inventory_item_id
                               )
                        ';
        ELSE
            EXECUTE IMMEDIATE   '
                        insert /*+ APPEND PARALLEL('
                             || gl_dop
                             || ') */
                          into '
                             || gl_table_owner
                             || '.'
                             || l_tablename
                             || ' (refresh_number, refresh_time, organization_id, inventory_item_id, atr) 
                                (
                                select /*+PARALLEL('
                             || gl_dop
                             || ')*/
                                      '
                             || gl_refresh_number
                             || ' refresh_number
                                     , to_timestamp_tz ('''
                             || TO_CHAR (gl_snap_time,
                                         'MM/DD/YYYY HH24:MI:SS.FF TZH:TZM')
                             || ''', ''MM/DD/YYYY HH24:MI:SS.FF TZH:TZM'')
                                      organization_id
                                     , inventory_item_id
                                     , xxdo_atp_calculation_ebs.single_atr(organization_id, inventory_item_id) atr
                                  from (select distinct
                                               moqd.organization_id
                                             , moqd.inventory_item_id
                                          from apps.mtl_onhand_quantities_Detail moqd
                                             , apps.mtl_secondary_inventories msi
                                          where msi.organization_id = moqd.organization_id
                                            and msi.secondary_inventory_name = moqd.subinventory_code
                                            and msi.reservable_type = 1     
                                       )
                                )
                        ';
        END IF;

        COMMIT;
        DBMS_STATS.gather_table_Stats (ownname => gl_table_owner, tabname => l_tablename, method_opt => 'FOR ALL COLUMNS'
                                       , degree => gl_dop);

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' rebuild online parallel (degree 3 instances 2)';
        END LOOP;

        COMMIT;
        msg ('-' || l_name || ' (' || x_ret_stat || ')');
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                x_ret_stat   := g_ret_unexp;
                x_msg        := SQLERRM;
                ROLLBACK;
                msg (x_msg);
                msg ('-' || l_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_unexp;
                    x_msg        := SQLERRM;
                    ROLLBACK;
            END;
    END;

    PROCEDURE swap_atr_stage_to_final (x_msg           OUT VARCHAR2,
                                       x_ret_stat   IN OUT VARCHAR2)
    IS
        l_name        VARCHAR2 (100)
                          := gl_package_name || '.' || 'swap_atr_stage_to_final';
        l_tablename   VARCHAR2 (240) := 'XXDO_ATR_STAGE';
    BEGIN
        msg ('+' || l_name);

        EXECUTE IMMEDIATE   'alter table '
                         || gl_table_owner
                         || '.xxdo_atr_final exchange partition p1 with table '
                         || gl_table_owner
                         || '.'
                         || l_tablename
                         || ' including indexes';

        msg ('-' || l_name || ' (' || x_ret_stat || ')');
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                x_ret_stat   := g_ret_unexp;
                x_msg        := SQLERRM;
                ROLLBACK;
                msg (x_msg);
                msg ('-' || l_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_unexp;
                    x_msg        := SQLERRM;
                    ROLLBACK;
            END;
    END;

    PROCEDURE reconcile_incremental_atr (x_msg           OUT VARCHAR2,
                                         x_ret_stat   IN OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name        VARCHAR2 (100)
                          := gl_package_name || '.' || 'reconcile_incremental_atr';
        l_tablename   VARCHAR2 (240) := 'XXDO_ATR_STAGE';
    BEGIN
        msg ('+' || l_name);

        EXECUTE IMMEDIATE   'alter table '
                         || gl_table_owner
                         || '.xxdo_atr_inc exchange partition p1 with table '
                         || gl_table_owner
                         || '.XXDO_ATR_STAGE including indexes';

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = 'XXDO_ATR_DIRTY'
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' unusable';
        END LOOP;

        EXECUTE IMMEDIATE   '
                    insert /*+ APPEND PARALLEL('
                         || gl_dop
                         || ') */
                      into '
                         || gl_table_owner
                         || '.XXDO_ATR_DIRTY (organization_id, inventory_item_id) 
                            (
                            select /*+PARALLEL('
                         || gl_dop
                         || ')*/ distinct
                                   organization_id
                                 , inventory_item_id 
                              from (
                                    ( 
                                    select organization_id, inventory_item_id, atr from xxdo.xxdo_atr_final
                                    minus
                                    select organization_id, inventory_item_id, atr from xxdo.xxdo_atr_inc
                                    )
                                    union all
                                    (
                                    select organization_id, inventory_item_id, atr from xxdo.xxdo_atr_final
                                    minus
                                    select organization_id, inventory_item_id, atr from xxdo.xxdo_atr_inc
                                    )
                                   )  
                            )
                    ';

        COMMIT;
        DBMS_STATS.gather_table_Stats (ownname => gl_table_owner, tabname => 'XXDO_ATR_DIRTY', method_opt => 'FOR ALL COLUMNS'
                                       , degree => gl_dop);

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = 'XXDO_ATR_DIRTY'
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' rebuild online parallel (degree 3 instances 2)';
        END LOOP;

        COMMIT;

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' unusable';
        END LOOP;

        EXECUTE IMMEDIATE   '
                    insert /*+ APPEND PARALLEL('
                         || gl_dop
                         || ') */
                      into '
                         || gl_table_owner
                         || '.'
                         || l_tablename
                         || ' (refresh_number, refresh_time, organization_id, inventory_item_id, atr) 
                            (
                            select /*+PARALLEL('
                         || gl_dop
                         || ')*/ 
                                   xaf.refresh_number
                                 , xaf.refresh_time
                                 , xaf.organization_id
                                 , xaf.inventory_item_id
                                 , xaf.atr 
                              from xxdo.xxdo_atr_final xaf 
                              where (xaf.organization_id, xaf.inventory_item_id) not in (select /*+HASH_AJ*/ organization_id, inventory_item_id from xxdo.xxdo_atr_dirty)
                            )
                    ';

        COMMIT;

        EXECUTE IMMEDIATE   '
                    insert /*+ APPEND PARALLEL('
                         || gl_dop
                         || ') */
                      into '
                         || gl_table_owner
                         || '.'
                         || l_tablename
                         || ' (refresh_number, refresh_time, organization_id, inventory_item_id, atr) 
                            (
                            select /*+PARALLEL('
                         || gl_dop
                         || ')*/
                                  '
                         || gl_refresh_number
                         || ' refresh_number
                                 , to_timestamp_tz ('''
                         || TO_CHAR (gl_snap_time,
                                     'MM/DD/YYYY HH24:MI:SS.FF TZH:TZM')
                         || ''', ''MM/DD/YYYY HH24:MI:SS.FF TZH:TZM'')
                                 , organization_id
                                 , inventory_item_id
                                 , max(atr) atr
                              from (
                                    select /*+PARALLEL('
                         || gl_dop
                         || ')*/ 
                                           xai.organization_id
                                         , xai.inventory_item_id
                                         , xai.atr 
                                      from xxdo.xxdo_atr_inc xai
                                         , xxdo.xxdo_atr_dirty xad 
                                      where xai.organization_id = xad.organization_id 
                                        and xai.inventory_item_id = xad.inventory_item_id
                                    union all                           
                                    select /*+PARALLEL('
                         || gl_dop
                         || ')*/ 
                                           xad.organization_id
                                         , xad.inventory_item_id
                                         , 0 atr 
                                      from xxdo.xxdo_atr_final xaf
                                         , xxdo.xxdo_atr_dirty xad 
                                      where xaf.organization_id = xad.organization_id 
                                        and xaf.inventory_item_id = xad.inventory_item_id
                                    )
                              group by organization_id
                                     , inventory_item_id                                     
                            )
                    ';

        COMMIT;
        DBMS_STATS.gather_table_Stats (ownname => gl_table_owner, tabname => l_tablename, method_opt => 'FOR ALL COLUMNS'
                                       , degree => gl_dop);

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' rebuild online parallel (degree 3 instances 2)';
        END LOOP;

        COMMIT;
        msg ('-' || l_name || ' (' || x_ret_stat || ')');
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                x_ret_stat   := g_ret_unexp;
                x_msg        := SQLERRM;
                ROLLBACK;
                msg (x_msg);
                msg ('-' || l_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_unexp;
                    x_msg        := SQLERRM;
                    ROLLBACK;
            END;
    END;

    PROCEDURE publish_atp (x_msg OUT VARCHAR2, x_ret_stat IN OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name        VARCHAR2 (100) := gl_package_name || '.' || 'publish_atp';
        l_tablename   VARCHAR2 (240) := 'XXDO_ATP_MASTER_STAGE';
        l_script      LONG;
        l_replace     LONG;
        --Start v1.1 Changes
        l_tmp_sel     LONG;
        l_tmp_tab     fnd_table_of_varchar2_4000;
    --End v1.1 Changes
    BEGIN
        msg ('+' || l_name);

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' unusable';
        END LOOP;

        FOR rec IN (  SELECT *
                        FROM xxdo.xxdo_atp_integration_scripts
                       WHERE enabled = 1
                    ORDER BY process_number, step_number)
        LOOP
            l_script   := rec.script;
            l_script   := REPLACE (l_script, '#DOP#', gl_dop * 2);

            --Start Changes v1.1
            IF INSTR (l_script, '#O_ST_O#') != 0
            THEN
                BEGIN
                    SELECT '(' || xxdo_atp_calculation_ebs.tab_to_string (CAST (COLLECT (comb) AS fnd_table_of_varchar2_4000)) || ')'
                      INTO l_replace
                      FROM (  SELECT DISTINCT
                                     '''' || mp.organization_id || '''' comb
                                FROM fnd_lookup_values flv, mtl_parameters mp
                               WHERE     lookup_type = 'XXD_ATP_ORG_MAP'
                                     AND flv.language = USERENV ('LANG')
                                     AND mp.organization_code = flv.attribute1
                                     AND flv.enabled_flag = 'Y'
                                     AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                     flv.start_date_active,
                                                                     SYSDATE)
                                                             AND NVL (
                                                                     flv.end_date_active,
                                                                     SYSDATE)
                                     AND flv.attribute3 = rec.application
                                     AND flv.attribute6 = 'OUTLET'
                            GROUP BY '''' || mp.organization_id || '''');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_replace   := 'NULL';
                END;

                l_script   := REPLACE (l_script, '#O_ST_O#', l_replace);
            END IF;

            IF INSTR (l_script, '#O_ST_C#') != 0
            THEN
                BEGIN
                    SELECT '(' || xxdo_atp_calculation_ebs.tab_to_string (CAST (COLLECT (comb) AS fnd_table_of_varchar2_4000)) || ')'
                      INTO l_replace
                      FROM (  SELECT DISTINCT
                                     '''' || mp.organization_id || '''' comb
                                FROM fnd_lookup_values flv, mtl_parameters mp
                               WHERE     lookup_type = 'XXD_ATP_ORG_MAP'
                                     AND flv.language = USERENV ('LANG')
                                     AND mp.organization_code = flv.attribute1
                                     AND flv.enabled_flag = 'Y'
                                     AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                     flv.start_date_active,
                                                                     SYSDATE)
                                                             AND NVL (
                                                                     flv.end_date_active,
                                                                     SYSDATE)
                                     AND flv.attribute3 = rec.application
                                     AND flv.attribute6 = 'CONCEPT'
                            GROUP BY '''' || mp.organization_id || '''');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_replace   := 'NULL';
                END;

                l_script   := REPLACE (l_script, '#O_ST_C#', l_replace);
            END IF;

            IF INSTR (l_script, '#O_ST_E#') != 0
            THEN
                BEGIN
                    SELECT '(' || xxdo_atp_calculation_ebs.tab_to_string (CAST (COLLECT (comb) AS fnd_table_of_varchar2_4000)) || ')'
                      INTO l_replace
                      FROM (  SELECT DISTINCT
                                     '''' || mp.organization_id || '''' comb
                                FROM fnd_lookup_values flv, mtl_parameters mp
                               WHERE     lookup_type = 'XXD_ATP_ORG_MAP'
                                     AND flv.language = USERENV ('LANG')
                                     AND mp.organization_code = flv.attribute1
                                     AND flv.enabled_flag = 'Y'
                                     AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                     flv.start_date_active,
                                                                     SYSDATE)
                                                             AND NVL (
                                                                     flv.end_date_active,
                                                                     SYSDATE)
                                     AND flv.attribute3 = rec.application
                                     AND flv.attribute6 = 'EVENT'
                            GROUP BY '''' || mp.organization_id || '''');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_replace   := 'NULL';
                END;

                l_script   := REPLACE (l_script, '#O_ST_E#', l_replace);
            END IF;

            IF INSTR (l_script, '#O_ST_P#') != 0
            THEN
                BEGIN
                    SELECT '(' || xxdo_atp_calculation_ebs.tab_to_string (CAST (COLLECT (comb) AS fnd_table_of_varchar2_4000)) || ')'
                      INTO l_replace
                      FROM (  SELECT DISTINCT
                                     '''' || mp.organization_id || '''' comb
                                FROM fnd_lookup_values flv, mtl_parameters mp
                               WHERE     lookup_type = 'XXD_ATP_ORG_MAP'
                                     AND flv.language = USERENV ('LANG')
                                     AND mp.organization_code = flv.attribute1
                                     AND flv.enabled_flag = 'Y'
                                     AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                     flv.start_date_active,
                                                                     SYSDATE)
                                                             AND NVL (
                                                                     flv.end_date_active,
                                                                     SYSDATE)
                                     AND flv.attribute3 = rec.application
                                     AND flv.attribute6 = 'POPUP'
                            GROUP BY '''' || mp.organization_id || '''');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_replace   := 'NULL';
                END;

                l_script   := REPLACE (l_script, '#O_ST_P#', l_replace);
            END IF;

            IF INSTR (l_script, '#O_ST_M#') != 0
            THEN
                BEGIN
                    SELECT '(' || xxdo_atp_calculation_ebs.tab_to_string (CAST (COLLECT (comb) AS fnd_table_of_varchar2_4000)) || ')'
                      INTO l_replace
                      FROM (  SELECT DISTINCT
                                     '''' || mp.organization_id || '''' comb
                                FROM fnd_lookup_values flv, mtl_parameters mp
                               WHERE     lookup_type = 'XXD_ATP_ORG_MAP'
                                     AND flv.language = USERENV ('LANG')
                                     AND mp.organization_code = flv.attribute1
                                     AND flv.enabled_flag = 'Y'
                                     AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                     flv.start_date_active,
                                                                     SYSDATE)
                                                             AND NVL (
                                                                     flv.end_date_active,
                                                                     SYSDATE)
                                     AND flv.attribute3 = rec.application
                                     AND flv.attribute6 = 'MKTG'
                            GROUP BY '''' || mp.organization_id || '''');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_replace   := 'NULL';
                END;

                l_script   := REPLACE (l_script, '#O_ST_M#', l_replace);
            END IF;

            IF INSTR (l_script, '#OB#') != 0
            THEN
                SELECT '(' || xxdo_atp_calculation_ebs.tab_to_string (CAST (COLLECT (comb) AS fnd_table_of_varchar2_4000)) || ')'
                  INTO l_replace
                  FROM (  SELECT DISTINCT
                                 '(' || mp.organization_id || ',''' || REPLACE (flv.attribute4, '''', '''''') || ''')' comb
                            FROM fnd_lookup_values flv, mtl_parameters mp
                           WHERE     lookup_type = 'XXD_ATP_ORG_MAP'
                                 AND flv.language = USERENV ('LANG')
                                 AND mp.organization_code = flv.attribute1
                                 AND flv.enabled_flag = 'Y'
                                 AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                 flv.start_date_active,
                                                                 SYSDATE)
                                                         AND NVL (
                                                                 flv.end_date_active,
                                                                 SYSDATE)
                                 AND flv.attribute3 = rec.application
                        GROUP BY '(' || mp.organization_id || ',''' || REPLACE (flv.attribute4, '''', '''''') || ''')');

                l_script   := REPLACE (l_script, '#OB#', l_replace);
            END IF;

            /*
            IF INSTR (l_script, '#OD#') != 0 THEN
               SELECT '('
                      || xxdo_atp_calculation_ebs.
                         tab_to_string (
                            CAST (COLLECT (comb) AS fnd_table_of_varchar2_4000))
                      || ')'
                 INTO l_replace
                 FROM (  SELECT DISTINCT
                                   '('
                                || mp.organization_id
                                || ','''
                                || REPLACE (flv.attribute2, '''', '''''')
                                || ''')'
                                   comb
                           FROM fnd_lookup_values flv, mtl_parameters mp
                          WHERE lookup_type = 'XXD_ATP_ORG_MAP'
                            AND flv.language = 'US'
                            AND mp.organization_code = flv.attribute1
                            AND TRUNC (SYSDATE) BETWEEN NVL (
                                                             flv.start_date_active
                                                            ,SYSDATE
                                                            )
                                                    AND NVL (
                                                             flv.end_date_active
                                                            ,SYSDATE
                                                            )
                            AND flv.attribute3 = rec.application
                       GROUP BY    '('
                                || mp.organization_id
                                || ','''
                                || REPLACE (flv.attribute2, '''', '''''')
                                || ''')');

               l_script   := REPLACE (l_script, '#OD#', l_replace);
            END IF;

            IF INSTR (l_script, '#ODB#') != 0 THEN
               SELECT '('
                      || xxdo_atp_calculation_ebs.
                         tab_to_string (
                            CAST (COLLECT (comb) AS fnd_table_of_varchar2_4000))
                      || ')'
                 INTO l_replace
                 FROM (  SELECT DISTINCT
                                   '('
                                || mp.organization_id
                                || ','''
                                || REPLACE (flv.attribute2, '''', '''''')
                                || ''','''
                                || REPLACE (flv.attribute4, '''', '''''')
                                || ''')'
                                   comb
                           FROM fnd_lookup_values flv, mtl_parameters mp
                          WHERE lookup_type = 'XXD_ATP_ORG_MAP'
                            AND flv.language = 'US'
                            AND mp.organization_code = flv.attribute1
                            AND TRUNC (SYSDATE) BETWEEN NVL (
                                                             flv.start_date_active
                                                            ,SYSDATE
                                                            )
                                                    AND NVL (
                                                             flv.end_date_active
                                                            ,SYSDATE
                                                            )
                            AND flv.attribute3 = rec.application
                       GROUP BY    '('
                                || mp.organization_id
                                || ','''
                                || REPLACE (flv.attribute2, '''', '''''')
                                || ''','''
                                || REPLACE (flv.attribute4, '''', '''''')
                                || ''')');

               l_script   := REPLACE (l_script, '#ODB#', l_replace);
            END IF;
      */
            --End Changes v1.1

            IF INSTR (l_script, '#ODBC#') != 0
            THEN
                SELECT '(' || xxdo_atp_calculation_ebs.tab_to_string (CAST (COLLECT (comb) AS fnd_table_of_varchar2_4000)) || ')'
                  INTO l_replace
                  FROM (  SELECT DISTINCT
                                 '(' || mp.organization_id || ',''' || REPLACE (flv.attribute2, '''', '''''') || ''',''' || REPLACE (flv.attribute4, '''', '''''') || ''',''' || REPLACE (flv.attribute5, '''', '''''') || ''')' comb
                            FROM fnd_lookup_values flv, mtl_parameters mp
                           WHERE     lookup_type = 'XXD_ATP_ORG_MAP'
                                 AND flv.language = 'US'
                                 AND mp.organization_code = flv.attribute1
                                 AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                 flv.start_date_active,
                                                                 SYSDATE)
                                                         AND NVL (
                                                                 flv.end_date_active,
                                                                 SYSDATE)
                                 AND flv.attribute3 = rec.application
                        GROUP BY '(' || mp.organization_id || ',''' || REPLACE (flv.attribute2, '''', '''''') || ''',''' || REPLACE (flv.attribute4, '''', '''''') || ''',''' || REPLACE (flv.attribute5, '''', '''''') || ''')');

                l_script   := REPLACE (l_script, '#ODBC#', l_replace);
            END IF;

            IF INSTR (l_script, '#APP#') != 0
            THEN
                l_replace   := '''' || rec.application || '''';
                l_script    := REPLACE (l_script, '#APP#', l_replace);
            END IF;

            EXECUTE IMMEDIATE l_script;

            COMMIT;
        END LOOP;

        DBMS_STATS.gather_table_Stats (ownname => gl_table_owner, tabname => l_tablename, method_opt => 'FOR ALL COLUMNS'
                                       , degree => gl_dop);

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' rebuild online parallel (degree 6 instances 2)';
        END LOOP;

        COMMIT;

        EXECUTE IMMEDIATE   'alter table xxdo.xxd_master_atp_full_t exchange partition p1 with table '
                         || gl_table_owner
                         || '.'
                         || l_tablename
                         || ' including indexes';

        COMMIT;
        msg ('-' || l_name || ' (' || x_ret_stat || ')');
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                x_ret_stat   := g_ret_unexp;
                x_msg        := SQLERRM;
                ROLLBACK;
                msg (x_msg);
                msg ('-' || l_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_unexp;
                    x_msg        := SQLERRM;
                    ROLLBACK;
            END;
    END;

    PROCEDURE refresh_atp (x_ret_stat        OUT VARCHAR2,
                           x_msg             OUT VARCHAR2,
                           p_force_full   IN     VARCHAR2 := 'N')
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name                  VARCHAR2 (100) := gl_package_name || '.' || 'refresh_worker';
        l_conflicts             NUMBER;
        l_fulls_today           NUMBER := 0;
        l_last_complete         NUMBER := 0;
        l_force_ascp_full       VARCHAR2 (1) := 'N';
        l_ascp_refresh_number   NUMBER;
        l_module                VARCHAR2 (240);
        l_action                VARCHAR2 (240);
        l_client_info           VARCHAR2 (240);
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';

        gl_start_ms         := get_ms;
        gl_last_ms          := 0;
        gl_indent           := 0;
        msg ('+' || l_name);
        DBMS_APPLICATION_INFO.read_module (l_module, l_action);
        DBMS_APPLICATION_INFO.read_client_info (l_client_info);
        x_ret_stat          := g_ret_success;

        SELECT COUNT (*)
          INTO l_conflicts
          FROM gv$session
         WHERE module = gl_package_name;

        msg ('Found (' || l_conflicts || ') conflicts');

        IF l_conflicts != 0
        THEN
            x_ret_stat   := g_ret_error;
            x_msg        := 'Conflict with currently-running refresh';
            msg (x_msg);
            msg ('-' || l_name || ' (' || x_ret_stat || ')');
            ROLLBACK;
            DBMS_APPLICATION_INFO.set_module (l_module, l_action);
            DBMS_APPLICATION_INFO.set_client_info (l_client_info);
            RETURN;
        END IF;

        DBMS_APPLICATION_INFO.set_module (gl_package_name, l_name);

        UPDATE xxdo.xxdo_atp_control
           SET status   = g_status_aborted
         WHERE     status = g_status_new
               AND submit_time < SYSTIMESTAMP - 1 / (24 * 60 * 60);

        UPDATE xxdo.xxdo_atp_control
           SET status   = g_status_error
         WHERE status NOT IN (g_status_complete, g_status_transmitted);

        gl_refresh_number   := allocate_refresh_number;
        DBMS_APPLICATION_INFO.set_client_info (gl_refresh_number);

        SELECT COUNT (*)
          INTO l_fulls_today
          FROM xxdo.xxdo_atp_control
         WHERE     start_time > TRUNC (SYSDATE)
               AND status IN (g_status_complete, g_status_transmitted);

        SELECT MAX (refresh_number)
          INTO l_last_complete
          FROM xxdo.xxdo_atp_control
         WHERE status IN (g_status_complete, g_status_transmitted);

        gl_refresh_type     := 'INC';

        IF p_force_full = 'Y'
        THEN
            gl_refresh_type   := 'FULL';
            msg ('Forcing Full');
        ELSIF l_fulls_today = 0
        THEN
            gl_refresh_type   := 'FULL';
            msg ('No Full Today');
        ELSIF l_last_complete != gl_refresh_number - 1
        THEN
            gl_refresh_type   := 'FULL';
            msg ('Last Refresh was not a success');
        END IF;

        UPDATE xxdo.xxdo_atp_control
           SET refresh_type   = gl_refresh_type
         WHERE refresh_number = gl_refresh_number;

        COMMIT;
        update_control (p_status => g_status_submitted);

        update_control (p_milestone => 1);

        IF gl_refresh_type = 'FULL'
        THEN
            l_force_ascp_full   := 'Y';
        END IF;

        gl_snap_time        := SYSTIMESTAMP;
        update_control (p_status => g_status_processing);
        launch_ascp_refresh (p_force_full => l_force_ascp_full, p_ascp_refresh_number => l_ascp_refresh_number, x_msg => x_msg
                             , x_ret_stat => x_ret_stat);

        IF x_ret_stat != g_ret_success
        THEN
            update_control (p_status => g_status_error);
            msg (x_msg);
            msg ('-' || l_name || ' (' || x_ret_stat || ')');
            ROLLBACK;
            DBMS_APPLICATION_INFO.set_module (l_module, l_action);
            DBMS_APPLICATION_INFO.set_client_info (l_client_info);
            RETURN;
        END IF;

        --
        update_control (p_milestone => 2);
        clean_tables (x_msg, x_ret_stat);

        IF x_ret_stat != g_ret_success
        THEN
            update_control (p_status => g_status_error);
            msg (x_msg);
            msg ('-' || l_name || ' (' || x_ret_stat || ')');
            ROLLBACK;
            DBMS_APPLICATION_INFO.set_module (l_module, l_action);
            DBMS_APPLICATION_INFO.set_client_info (l_client_info);
            RETURN;
        END IF;

        --
        update_control (p_milestone => 3);
        populate_atr (x_ret_Stat => x_ret_stat, x_msg => x_msg);

        IF x_ret_stat != g_ret_success
        THEN
            update_control (p_status => g_status_error);
            msg (x_msg);
            msg ('-' || l_name || ' (' || x_ret_stat || ')');
            ROLLBACK;
            DBMS_APPLICATION_INFO.set_module (l_module, l_action);
            DBMS_APPLICATION_INFO.set_client_info (l_client_info);
            RETURN;
        END IF;

        --
        update_control (p_milestone => 4);

        IF gl_refresh_type != 'FULL'
        THEN
            reconcile_incremental_atr (x_ret_Stat   => x_ret_stat,
                                       x_msg        => x_msg);

            IF x_ret_stat != g_ret_success
            THEN
                update_control (p_status => g_status_error);
                msg (x_msg);
                msg ('-' || l_name || ' (' || x_ret_stat || ')');
                ROLLBACK;
                DBMS_APPLICATION_INFO.set_module (l_module, l_action);
                DBMS_APPLICATION_INFO.set_client_info (l_client_info);
                RETURN;
            END IF;
        END IF;

        --
        update_control (p_milestone => 5);
        swap_atr_stage_to_final (x_ret_Stat => x_ret_stat, x_msg => x_msg);

        IF x_ret_stat != g_ret_success
        THEN
            update_control (p_status => g_status_error);
            msg (x_msg);
            msg ('-' || l_name || ' (' || x_ret_stat || ')');
            ROLLBACK;
            DBMS_APPLICATION_INFO.set_module (l_module, l_action);
            DBMS_APPLICATION_INFO.set_client_info (l_client_info);
            RETURN;
        END IF;

        --
        update_control (p_milestone => 6);
        wait_for_ascp_refresh (
            p_ascp_refresh_number   => l_ascp_refresh_number,
            x_ret_Stat              => x_ret_stat,
            x_msg                   => x_msg);

        IF x_ret_stat != g_ret_success
        THEN
            update_control (p_status => g_status_error);
            msg (x_msg);
            msg ('-' || l_name || ' (' || x_ret_stat || ')');
            ROLLBACK;
            DBMS_APPLICATION_INFO.set_module (l_module, l_action);
            DBMS_APPLICATION_INFO.set_client_info (l_client_info);
            RETURN;
        END IF;

        --
        update_control (p_milestone => 7);
        copy_atp_results (x_ret_Stat => x_ret_stat, x_msg => x_msg);

        IF x_ret_stat != g_ret_success
        THEN
            update_control (p_status => g_status_error);
            msg (x_msg);
            msg ('-' || l_name || ' (' || x_ret_stat || ')');
            ROLLBACK;
            DBMS_APPLICATION_INFO.set_module (l_module, l_action);
            DBMS_APPLICATION_INFO.set_client_info (l_client_info);
            RETURN;
        END IF;

        --
        update_control (p_milestone => 8);
        publish_atp (x_ret_Stat => x_ret_stat, x_msg => x_msg);

        IF x_ret_stat != g_ret_success
        THEN
            update_control (p_status => g_status_error);
            msg (x_msg);
            msg ('-' || l_name || ' (' || x_ret_stat || ')');
            ROLLBACK;
            DBMS_APPLICATION_INFO.set_module (l_module, l_action);
            DBMS_APPLICATION_INFO.set_client_info (l_client_info);
            RETURN;
        END IF;

        --
        update_control (p_status => g_status_complete);
        DBMS_APPLICATION_INFO.set_module (l_module, l_action);
        DBMS_APPLICATION_INFO.set_client_info (l_client_info);
        COMMIT;
        msg ('-' || l_name || ' (' || x_ret_stat || ')');
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                x_ret_stat   := g_ret_unexp;
                x_msg        := SQLERRM;
                ROLLBACK;
                update_control (p_status => g_status_error);
                DBMS_APPLICATION_INFO.set_module (l_module, l_action);
                DBMS_APPLICATION_INFO.set_client_info (l_client_info);
                msg (x_msg);
                msg ('-' || l_name || ' (' || x_ret_stat || ')');
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_ret_stat   := g_ret_unexp;
                    x_msg        := SQLERRM;
                    ROLLBACK;
            END;
    END;

    PROCEDURE validate_atp (p_workers IN NUMBER:= 6)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name        VARCHAR2 (100) := gl_package_name || '.' || 'validate_atp';
        l_msg         VARCHAR2 (240);
        l_tablename   VARCHAR2 (240) := 'XXDO_ATP_VALIDATE';
        l_job_id      NUMBER;
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';

        gl_start_ms   := get_ms;
        gl_last_ms    := 0;
        gl_indent     := 0;
        msg ('+' || l_name);

        EXECUTE IMMEDIATE   'truncate table '
                         || gl_table_owner
                         || '.xxdo_atp_validate';

        EXECUTE IMMEDIATE   'truncate table '
                         || gl_table_owner
                         || '.xxdo_atp_validate_control';

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' unusable';
        END LOOP;

        EXECUTE IMMEDIATE   'insert into '
                         || gl_table_owner
                         || '.'
                         || l_tablename
                         || ' ( refresh_number     
                                                                        , refresh_time       
                                                                        , ascp_refresh_number
                                                                        , ascp_refresh_time  
                                                                        , demand_class       
                                                                        , priority           
                                                                        , organization_id    
                                                                        , inventory_item_id  
                                                                        , dte                
                                                                        , atp                
                                                                        , atp_w_s               
                                                                      --Start changes v1.1
                                                                        , atp_wb_ro            
                                                                        , atp_wb_rc             
                                                                        , atp_wb_re           
                                                                        , atp_wb_rp           
                                                                        , atp_wb_rm             
                                                                        , atp_wb_ec           
                                                                      --End changes v1.1
                                                                        )
                            ( 
                               select refresh_number     
                                    , refresh_time       
                                    , ascp_refresh_number
                                    , ascp_refresh_time  
                                    , demand_class       
                                    , priority           
                                    , organization_id    
                                    , inventory_item_id  
                                    , dte                
                                    , atp                
                                    , atp_w_s                    
                                  --Start changes v1.1         
                                    , atp_wb_ro          
                                    , atp_wb_rc                
                                    , atp_wb_re                 
                                    , atp_wb_rp                 
                                    , atp_wb_rm                
                                    , atp_wb_ec               
                                  --End changes v1.1 
                                 from '
                         || gl_table_owner
                         || '.xxdo_atp_final
                            )
                    ';

        DBMS_STATS.gather_table_Stats (ownname => gl_table_owner, tabname => l_tablename, method_opt => 'FOR ALL COLUMNS'
                                       , degree => gl_dop);

        FOR idx
            IN (SELECT *
                  FROM dba_indexes
                 WHERE     table_name = l_tablename
                       AND table_owner = gl_table_owner)
        LOOP
            EXECUTE IMMEDIATE   'alter index '
                             || idx.owner
                             || '.'
                             || idx.index_name
                             || ' rebuild online parallel (degree 3 instances 2)';
        END LOOP;

        COMMIT;

        FOR i IN 1 .. p_workers
        LOOP
            DBMS_JOB.submit (
                l_job_id,
                'begin xxdo_atp_calculation_ebs.validation_worker; end;');
        END LOOP;

        COMMIT;
        msg ('-' || l_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                l_msg   := SQLERRM;
                ROLLBACK;
                msg (l_msg);
                msg ('-' || l_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
            END;
    END;

    PROCEDURE validation_worker
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_name         VARCHAR2 (100)
                           := gl_package_name || '.' || 'validation_worker';
        l_session_id   NUMBER := TO_NUMBER (USERENV ('SESSIONID'));
        l_abort_flag   NUMBER;
        l_msg          VARCHAR2 (240);
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';

        gl_start_ms   := get_ms;
        gl_last_ms    := 0;
        gl_indent     := 0;
        msg ('+' || l_name);

        LOOP
            SELECT COUNT (*)
              INTO l_abort_flag
              FROM xxdo.xxdo_atp_validate_control;

            EXIT WHEN l_abort_flag != 0;

            UPDATE xxdo.xxdo_atp_validate
               SET processing_session   = l_session_id
             WHERE     processing_session IS NULL
                   AND ROWNUM <= 20
                   AND dte != TRUNC (SYSDATE)
                   AND atp_w_s != 10000000000
                   AND atp_w_s != 0;

            EXIT WHEN SQL%ROWCOUNT = 0;
            COMMIT;

            UPDATE xxdo.xxdo_atp_validate
               SET processed_date   = SYSTIMESTAMP,
                   std_atp          =
                       xxdo_atp_calculation_ebs.single_atp (organization_id, inventory_item_id, dte
                                                            , demand_class)
             WHERE     processing_session = l_session_id
                   AND processed_date IS NULL;

            COMMIT;
        END LOOP;

        COMMIT;
        msg ('-' || l_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                l_msg   := SQLERRM;
                ROLLBACK;
                msg (l_msg);
                msg ('-' || l_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
            END;
    END;

    FUNCTION tab_to_string (p_varchar2_tab   IN fnd_table_of_varchar2_4000,
                            p_delimiter      IN VARCHAR2 DEFAULT ',')
        RETURN CLOB
    IS
        l_string   CLOB;
    BEGIN
        FOR i IN p_varchar2_tab.FIRST .. p_varchar2_tab.LAST
        LOOP
            IF i != p_varchar2_tab.FIRST
            THEN
                l_string   := l_string || p_delimiter;
            END IF;

            l_string   := l_string || p_varchar2_tab (i);
        END LOOP;

        RETURN l_string;
    END tab_to_string;

    PROCEDURE refresh_atp_conc (errorbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, p_force_full IN VARCHAR2)
    IS
        l_name         VARCHAR2 (100)
                           := gl_package_name || '.' || 'refresh_atp_conc';
        l_ret_stat     VARCHAR2 (240);
        l_msg          VARCHAR2 (4000);
        l_force_full   VARCHAR2 (1);
    BEGIN
        msg ('+' || l_name);

        IF SUBSTR (UPPER (p_force_full), 1, 1) = 'Y'
        THEN
            l_force_full   := 'Y';
        ELSE
            l_force_full   := 'N';
        END IF;

        xxdo_atp_calculation_ebs.refresh_atp (x_ret_stat     => l_ret_stat,
                                              x_msg          => l_msg,
                                              p_force_full   => l_force_full);

        IF l_ret_Stat = g_ret_success
        THEN
            retcode   := '0';
        ELSE
            errorbuf   := l_msg;
            retcode    := '2';
        END IF;

        msg ('-' || l_name || ' (' || l_ret_stat || ')');
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                errorbuf   := l_msg;
                retcode    := '2';
                msg (l_msg);
                msg ('-' || l_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    errorbuf   := l_msg;
                    retcode    := '2';
            END;
    END;
END xxdo_atp_calculation_ebs;
/
