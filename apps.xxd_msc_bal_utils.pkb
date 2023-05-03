--
-- XXD_MSC_BAL_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_MSC_BAL_UTILS"
AS
    /* $Header: MSCUBALB.pls 120.8 2007/12/14 07:31:47 sbnaik ship $  */
    PG_DEBUG   VARCHAR2 (1) := NVL (FND_PROFILE.VALUE ('MSC_ATP_DEBUG'), 'N');

    PROCEDURE EXTEND (p_nodes         IN OUT NOCOPY mrp_bal_utils.mrp_oe_rec,
                      extend_amount                 NUMBER);

    PROCEDURE TRIM (p_nodes       IN OUT NOCOPY mrp_bal_utils.mrp_oe_rec,
                    trim_amount                 NUMBER);

    PROCEDURE populate_temp_table (p_session_id       NUMBER,
                                   p_order_by         VARCHAR2,
                                   p_where            VARCHAR2,
                                   p_overwrite        NUMBER,
                                   p_org_id           NUMBER,
                                   p_exclude_picked   NUMBER DEFAULT 0)
    IS
        l_stmt                        VARCHAR2 (4000);
        l_mrp_oe_rec                  mrp_bal_utils.mrp_oe_rec;
        filter_mrp_oe_rec             mrp_bal_utils.mrp_oe_rec;
        j                             NUMBER;

        TYPE curtype IS REF CURSOR;

        CV                            CurType;
        l_seq                         NUMBER;
        num_of_lines                  NUMBER;
        l_ship_set_id                 NUMBER;
        l_arrival_set_id              NUMBER;
        a                             NUMBER;
        -- From patchset G+, new columns in OE/MRP introduced compile-time dependency
        -- between ATP and OM. This fix (using DBMS_SQL) removes this dependency. We check
        -- ALL_TAB_COLUMNS for these columns and then frame the SQL. Bug 2727595.

        bind1                         DBMS_SQL.number_table;
        bind2                         DBMS_SQL.number_table;

        CURSOR check_oe (p_column_name VARCHAR2)
        IS
            SELECT 1
              FROM user_tab_columns
             WHERE     table_name = 'OE_MRP_OPEN_DEMANDS_V'
                   AND column_name = p_column_name;

        l_column_exist                NUMBER;
        l_sql_stmt                    VARCHAR2 (30000);

        l_sql_stmt1                   VARCHAR2 (30000)
            :=    'begin '
               ||                     -- 'FORALL j IN 1 .. :l_num_of_lines '||
                  'insert into mrp_atp_schedule_temp '
               || '(action, '
               || 'calling_module, '
               || 'sequence_number, '
               || 'session_id, '
               || 'scenario_id, '
               || 'firm_flag, '
               || 'status_flag, '
               || 'insert_flag, '
               || 'order_header_id, '
               || 'order_number, '
               || 'order_line_id, '
               || 'order_line_number, '
               || 'inventory_item_id, '
               || 'inventory_item_name, '
               || 'sr_instance_id, '
               || 'source_organization_id, '
               || 'source_organization_code, '
               || 'old_source_organization_code, '
               || 'quantity_ordered, '
               || 'uom_code, '
               || 'scheduled_ship_date, '
               || 'scheduled_arrival_date, '
               || 'old_line_schedule_date, '
               || 'requested_ship_date, '
               || 'requested_arrival_date, '
               || 'promise_date, '
               || 'latest_acceptable_date, '
               || 'delivery_lead_time, '
               || 'ship_method, '
               || 'demand_class, '
               || 'ship_set_id, '
               || 'ship_set_name, '
               || 'arrival_set_id, '
               || 'arrival_set_name, '
               || 'customer_id, '
               || 'customer_site_id, '
               || 'customer_name, '
               || 'customer_location, '
               || 'exception15, '
               ||                   -- Added by BT Team 14 Oct for NegativeATP
                  'exception14, '
               ||       -- Added by BT Team 14 Oct for Defaulting New Quantity
                  'shipment_number, '
               || 'option_number, '
               || 'old_source_organization_id, '
               || 'old_demand_class, '
               || 'creation_date, '
               || 'created_by, '
               || 'last_update_date, '
               || 'last_updated_by, '
               || 'last_update_login, '
               || 'freight_carrier, '
               || 'flow_status_code '
               || ') ( '
               || 'select '
               || '110, '
               || '-1, '
               || ':l_seq_num, '
               || ':p_session_id, '
               || '1, '
               ||                                               -- scenario_id
                  '2, '
               ||                                         -- firm_flag 2 -> NO
                  '1, '
               ||                                    -- status_flag 1 -> INPUT
                  ':l_profile_value, '
               ||                                    -- insert_flag 1 -> INPUT
                  'omodv.header_id, '
               || 'omodv.order_number, '
               || 'omodv.line_id, '
               ||           --start changes by BT Technology team on 04 Nov 15
                                                     --'omodv.line_number, '||
                'omodv.line_number||''.''||omodv.shipment_number,'
               ||             --End changes by BT Technology team on 04 Nov 15
                  'omodv.inventory_item_id, '
               || 'omodv.ordered_item, '
               || 'maai.instance_id, '
               || 'decode(:p_overwrite,1,NULL,omodv.ship_from_org_id), '
               || 'decode(:p_overwrite,1,NULL,ood.organization_code), '
               || 'ood.organization_code, '
               || 'omodv.ordered_quantity, '
               || 'omodv.order_quantity_uom, '
               || 'omodv.schedule_ship_date, '
               || 'omodv.schedule_arrival_date, '
               || 'decode(omodv.schedule_ship_date,NULL, '
               || 'omodv.schedule_arrival_date,omodv.schedule_ship_date), '
               || 'omodv.request_ship_date, '
               || 'omodv.request_arrival_date, '
               || 'omodv.promise_date, '
               || 'omodv.latest_acceptable_date, '
               || 'omodv.delivery_lead_time, '
               || 'omodv.shipping_method_code, '
               || 'omodv.demand_class_code, '
               || 'omodv.ship_set_id, '
               || 'omodv.ship_set_name, '
               || 'omodv.arrival_set_id, '
               || 'omodv.arrival_set_name, '
               || 'omodv.sold_to_org_id, '
               || 'omodv.ship_to_org_id, '
               || 'hp.party_name, '
               || 'ras.location, '
               || 'xxd_cal_atp_pkg.from_alloc_tables@bt_ebs_to_ascp(omodv.inventory_item_id
                                                      ,decode(:p_overwrite,1,NULL,omodv.ship_from_org_id)
                                                      ,decode(sign(to_date(:p_plan_run_date)-NVL(omodv.schedule_ship_date,omodv.schedule_arrival_date)),-1,NVL(omodv.schedule_ship_date,omodv.schedule_arrival_date),to_date(:p_plan_run_date))                                       
                                                      ,omodv.demand_class_code
                                                      ,:p_plan_id
                                                      , to_date(:p_plan_run_date)), '
               ||                   -- Added by BT Team 14 Oct for NegativeATP
                  'omodv.ordered_quantity, '
               ||       -- Added by BT Team 14 Oct for Defaulting New Quantity
                  'omodv.shipment_number, '
               || 'omodv.option_number, '
               || 'omodv.ship_from_org_id, '
               || 'omodv.demand_class_code, '
               || 'sysdate, '
               || 'FND_GLOBAL.USER_ID, '
               || 'sysdate, '
               || 'FND_GLOBAL.USER_ID, '
               || 'FND_GLOBAL.USER_ID ';

        l_new_columns                 VARCHAR2 (100)
            := ' ,omodv.freight_carrier_code, omodv.flow_status_code ';
        l_old_columns                 VARCHAR2 (100) := ' ,null, null ';

        l_sql_stmt2                   VARCHAR2 (30000)
            :=    'FROM '
               || 'mrp_ap_apps_instances maai, '
               || 'hz_cust_site_uses_all ras, '
               || 'hz_parties hp, '
               || 'hz_cust_accounts hca, '
               || 'org_organization_definitions ood, '
               || 'oe_mrp_open_demands_v omodv '
               || 'WHERE hp.party_id = hca.party_id '
               || 'AND hca.cust_account_id = omodv.sold_to_org_id '
               || 'AND ras.site_use_id = omodv.ship_to_org_id '
               || 'AND ras.site_use_code = '
               || ' ''SHIP_TO'' '
               || 'AND ood.organization_id(+) = omodv.ship_from_org_id '
               || 'AND omodv.line_id = :l_line_id ); '
               || 'end; ';

        cur_hdl                       INTEGER;
        rows_processed                BINARY_INTEGER;
        l_time                        VARCHAR2 (80);

        and_sets_lines                VARCHAR2 (400)
            := '  (  omodv.ship_set_id = omodv1.ship_set_id OR
                                             omodv.arrival_set_id = omodv1.arrival_set_id) ';

        and_null_sets_lines           VARCHAR2 (400)
            := '( (omodv.ship_set_id is NULL or omodv.arrival_set_id is NULL)
                                           and  omodv.line_id = omodv1.line_id) ';

        filter_sset_id                NUMBER;
        l_order_number                NUMBER;
        l_top_model_id                NUMBER;
        l_profile_value               NUMBER := 0;
        dummy_schedule_ship_date      DATE;
        dummy_schedule_arrival_date   DATE;
        dummy_request_ship_date       DATE;
        dummy_request_arrival_date    DATE;
        dummy_promise_date            DATE;
        dummy_order_number            NUMBER;
        lv_where                      VARCHAR2 (6000) := NULL; -- Added by BT Team V1.0 # 20-OCT-2015
        ln_plan_id                    NUMBER;
        ld_plan_run_date              VARCHAR2 (20) := NULL;
    BEGIN
        -- MOAC changes
        mo_global.init ('ONT');

        BEGIN
            SELECT plan_id, TO_CHAR (PLAN_COMPLETION_DATE, 'DD-MON-YYYY')
              INTO ln_plan_id, ld_plan_run_date
              FROM msc_plans@bt_ebs_to_ascp mp, msc_designators@bt_ebs_to_ascp md
             WHERE     mp.compile_designator = md.designator
                   AND md.inventory_atp_flag = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.put_line (
                    'Unable to find PlanId/Plan RunDate ' || SQLERRM);
        END;

        -- Start Added by BT Team V1.0 # 20-OCT-2015
        lv_where         :=
               p_where
            || ' AND omodv.inventory_item_id     =  xxd_cal_atp_pkg.is_neg_atp_item@bt_ebs_to_ascp( '
            || p_session_id
            || '
                                                                                                            ,omodv.inventory_item_id
                                                                                                            ,  omodv.ship_from_org_id                                                                                                            
                                                                                                            ,'
            || ln_plan_id
            || '
                                                                                                            ,'''
            || ld_plan_run_date
            || ''') ';

        -- END of added by BT Team V1.0 # 20-OCT-2015

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug ('MSC_BAL_UTILS.populate_temp_table ');

            SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
              INTO l_time
              FROM DUAL;

            msc_sch_wb.atp_debug ('POPULATE_TEMP_TABLE: BEGIN ' || l_time);
        END IF;

        OPEN check_oe ('PLANNING_PRIORITY');

        FETCH check_oe INTO l_column_exist;

        CLOSE check_oe;

        DELETE FROM mrp_atp_schedule_temp
              WHERE session_id = -444;


        IF l_column_exist = 1
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'MSC_BAL_UTILS.populate_temp_table '
                    || 'new column Planning_priority exsits');
            END IF;


            l_stmt   := ' INSERT into mrp_atp_schedule_temp
                         (order_line_id,
                          order_header_id,
                          scenario_id,
                          session_id,
                          inventory_item_id,
                          ship_set_id,
                          arrival_set_id,
                          sequence_number,
                          ato_model_line_id,
                          top_model_line_id,
                          inventory_item_name, ---item_type_code
                          order_number,
                          scheduled_ship_date,
                          scheduled_arrival_date,
                          requested_ship_date,
                          requested_arrival_date,
                          promise_date,
                          sr_instance_id)
                SELECT  omodv.line_id,
                        omodv.header_id,
                        0,
                        -444,
                        0,
                        omodv.ship_set_id,
                        omodv.arrival_set_id,
                        0,
                        omodv.ato_line_id,
                        omodv.top_model_line_id,
                        omodv.item_type_code,
                        omodv.order_number,
                        omodv.schedule_ship_date ,
                        omodv.schedule_arrival_date,
                        omodv.request_ship_date,
                        omodv.request_arrival_date,
                        omodv.promise_date,
                        omodv.planning_priority
                FROM
                        oe_mrp_open_demands_v omodv
                WHERE   1=1 ';
        ELSE
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                    'MSC_BAL_UTILS.populate_temp_table:  new column Planning_priority DOES NOT exsits');
                msc_sch_wb.atp_debug (
                    ' You are trying to sequece lines on planning_priority of a line , however dependency patches are not applied');
                msc_sch_wb.atp_debug (
                    ' OM dependency patch #3898070 is not applied correctly ');
            END IF;

            l_stmt   := ' INSERT into mrp_atp_schedule_temp
                         (order_line_id,
                          order_header_id,
                          scenario_id,  -- not null col
                          session_id,   -- not null col
                          inventory_item_id, -- not null col
                          ship_set_id,
                          arrival_set_id,
                          sequence_number,
                          ato_model_line_id,
                          top_model_line_id,
                          inventory_item_name, -- -item_type_code
                          order_number,
                          scheduled_ship_date,
                          scheduled_arrival_date,
                          requested_ship_date,
                          requested_arrival_date,
                          promise_date)
                  SELECT
                        omodv.line_id,
                        omodv.header_id,
                        0,
                        -444,
                        0,
                        omodv.ship_set_id,
                        omodv.arrival_set_id,
                        0,
                        omodv.ato_line_id,
                        omodv.top_model_line_id,
                        omodv.item_type_code,
                        omodv.order_number,
                        omodv.schedule_ship_date ,
                        omodv.schedule_arrival_date,
                        omodv.request_ship_date,
                        omodv.request_arrival_date,
                        omodv.promise_date
                FROM
                        oe_mrp_open_demands_v omodv
                WHERE   1=1 ';
        END IF;

        --l_stmt := l_stmt || p_where; -- Commented by BT Technology Team
        l_stmt           := l_stmt || lv_where; -- Added by BT Technology Team



        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug ('p_exclude_picked is ' || p_exclude_picked);
        END IF;

        IF p_exclude_picked = 1
        THEN
            l_stmt   :=
                   l_stmt
                || '   and not  exists ( select 1
                        from wsh_delivery_details
                        where source_line_id =omodv.line_id
                        and source_code =  '
                || ' ''OE'' '
                || '  and released_status in  ( '
                || ' ''Y'' '
                || ',  '
                || ' ''S'' '
                || ',  '
                || ' ''C'' '
                || ' ) )  ';
            --start changes by BT Technology team on 25 Apr 2016
            l_stmt   :=
                   l_stmt
                || '  AND 1 = CASE
                       WHEN (SELECT COUNT (1)
                               FROM mtl_reservations
                              WHERE demand_source_line_id = omodv.line_id) > 0 
                       THEN
                          0
                       ELSE
                          1
                        END  ';



            COMMIT;
        --End changes by BT Technology team on 25 Apr 2016
        END IF;


        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                ' POPULATE_TEMP_TABLE - constructed sql is  ' || l_stmt);
        END IF;

        -- BEGIN
        -- DBMS_OUTPUT.PUT_LINE('    execute immediate ' || l_stmt);
        EXECUTE IMMEDIATE l_stmt;

        -- EXCEPTION WHEN OTHERS THEN
        -- DBMS_OUTPUT.PUT_LINE('Internal Error' ||SQLERRM);
        -- END;

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                ' INSERTED into mrp table   ' || SQL%ROWCOUNT);
        END IF;

        IF l_column_exist = 1
        THEN
            l_stmt   := 'select distinct
            omodv1.line_id,
            omodv1.ship_set_id,
            omodv1.arrival_set_id,
            0,
            omodv1.ato_line_id,
            omodv1.top_model_line_id,
            omodv1.item_type_code,
            omodv1.order_number,
            omodv1.schedule_ship_date,
            omodv1.schedule_arrival_date,
            omodv1.request_ship_date,
            omodv1.request_arrival_date,
            omodv1.promise_date,
            omodv1.order_number,
            omodv1.planning_priority
    from oe_mrp_open_demands_v omodv1,
         mrp_atp_schedule_temp mrp
    where mrp.session_id = -444
    and   mrp.order_header_id = omodv1.header_id
    and  ( mrp.order_line_id = omodv1.line_id
           OR
             nvl(mrp.ship_set_id, -1) = nvl(omodv1.ship_set_id, -2)
           OR
             nvl(mrp.arrival_set_id, -1) = nvl(omodv1.arrival_set_id, -2))';
        ELSE
            l_stmt   := 'select distinct
            omodv1.line_id,
            omodv1.ship_set_id,
            omodv1.arrival_set_id,
            0,
            omodv1.ato_line_id,
            omodv1.top_model_line_id,
            omodv1.item_type_code,
            omodv1.order_number,
            omodv1.schedule_ship_date,
            omodv1.schedule_arrival_date,
            omodv1.request_ship_date,
            omodv1.request_arrival_date,
            omodv1.promise_date,
            omodv1.order_number,
            0
    from oe_mrp_open_demands_v omodv1,
         mrp_atp_schedule_temp mrp
    where mrp.session_id = -444
    and   mrp.order_header_id = omodv1.header_id
    and  ( mrp.order_line_id = omodv1.line_id
           OR
             nvl(mrp.ship_set_id, -1) = nvl(omodv1.ship_set_id, -2)
           OR
             nvl(mrp.arrival_set_id, -1) = nvl(omodv1.arrival_set_id, -2))';
        END IF;

        IF p_exclude_picked = 1
        THEN
            l_stmt   :=
                   l_stmt
                || '   and not  exists ( select 1
                        from wsh_delivery_details
                        where source_line_id =omodv1.line_id
                        and source_code =  '
                || ' ''OE'' '
                || '  and released_status in  ( '
                || ' ''Y'' '
                || ',  '
                || ' ''S'' '
                || ',  '
                || ' ''C'' '
                || ' ) )  ';
            --start changes by BT Technology team on 25 Apr 2016
            l_stmt   :=
                   l_stmt
                || '  AND 1= CASE
                       WHEN (SELECT COUNT (1)
                               FROM mtl_reservations
                              WHERE demand_source_line_id = omodv1.line_id) > 0 
                       THEN
                          0
                       ELSE
                          1
                        END  ';
        --End changes by BT Technology team on 25 Apr 2016
        END IF;



        IF l_column_exist IS NULL AND p_order_by = 'omodv1.PLANNING_PRIORITY'
        THEN
            NULL;
        ELSE
            l_stmt   := l_stmt || '  ORDER BY ' || p_order_by;
            COMMIT;
        END IF;

        l_column_exist   := NULL;



        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                   ' POPULATE_TEMP_TABLE - second constructed sql is  '
                || l_stmt);
        END IF;

        j                := 0;



        OPEN CV FOR l_stmt;



        LOOP
            j   := j + 1;
            -- msc_sch_wb.atp_debug(' j '||j);
            EXTEND (filter_mrp_oe_rec, 1);

            FETCH CV
                INTO filter_mrp_oe_rec.line_id (j), filter_mrp_oe_rec.ship_set_id (j), filter_mrp_oe_rec.arrival_set_id (j), filter_mrp_oe_rec.seq_num (j),
                     filter_mrp_oe_rec.ato_line_id (j), filter_mrp_oe_rec.top_model_line_id (j), filter_mrp_oe_rec.item_type_code (j),
                     filter_mrp_oe_rec.order_number (j), dummy_schedule_ship_date, dummy_schedule_arrival_date,
                     dummy_request_ship_date, dummy_request_arrival_date, dummy_promise_date,
                     dummy_order_number, dummy_order_number; -- this is for planning priority

            EXIT WHEN CV%NOTFOUND;
        END LOOP;


        TRIM (filter_mrp_oe_rec, 1);

        CLOSE CV;

        num_of_lines     := j - 1;

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                   'POPULATE_TEMP_TABLE : '
                || ' Num of order lines selected '
                || num_of_lines);
        END IF;


        -- Set the line_id to -9999 for the recrds which we want to get rid of later
        -- because they are in this ship sets with ato lines

        FOR i IN 1 .. num_of_lines
        LOOP
            IF     ((filter_mrp_oe_rec.ato_line_id (i) IS NOT NULL OR filter_mrp_oe_rec.top_model_line_id (i) IS NOT NULL) AND filter_mrp_oe_rec.item_type_code (i) NOT IN ('KIT', 'INCLUDED'))
               AND filter_mrp_oe_rec.ship_set_id (i) IS NOT NULL
            THEN
                filter_sset_id   := filter_mrp_oe_rec.ship_set_id (i);

                FOR j IN i .. num_of_lines
                LOOP
                    IF filter_mrp_oe_rec.ship_set_id (j) = filter_sset_id
                    THEN
                        filter_mrp_oe_rec.line_id (j)   := -9999;
                    END IF;
                END LOOP;
            END IF;
        END LOOP;



        --   Set the line_id to NULL for the records which we want to get rid of later
        --   because they are in the arrival set with ato lines

        FOR i IN 1 .. num_of_lines
        LOOP
            IF     ((filter_mrp_oe_rec.ato_line_id (i) IS NOT NULL OR filter_mrp_oe_rec.top_model_line_id (i) IS NOT NULL) AND filter_mrp_oe_rec.item_type_code (i) NOT IN ('KIT', 'INCLUDED'))
               AND filter_mrp_oe_rec.arrival_set_id (i) IS NOT NULL
            THEN
                filter_sset_id   := filter_mrp_oe_rec.arrival_set_id (i);

                FOR j IN i .. num_of_lines
                LOOP
                    IF filter_mrp_oe_rec.arrival_set_id (j) = filter_sset_id
                    THEN
                        filter_mrp_oe_rec.line_id (j)   := -9999;
                    END IF;
                END LOOP;
            END IF;
        END LOOP;



        -- identify all the INCLUDED lines which belongs to KITS
        FOR i IN 1 .. num_of_lines
        LOOP
            IF (filter_mrp_oe_rec.item_type_code (i) = 'KIT' AND (filter_mrp_oe_rec.top_model_line_id (i) = filter_mrp_oe_rec.line_id (i)))
            THEN
                l_order_number   := filter_mrp_oe_rec.order_number (i);
                l_top_model_id   := filter_mrp_oe_rec.top_model_line_id (i);

                FOR j IN i .. num_of_lines
                LOOP
                    IF     (filter_mrp_oe_rec.order_number (j) = l_order_number)
                       AND (filter_mrp_oe_rec.top_model_line_id (j) = l_top_model_id)
                    THEN
                        filter_mrp_oe_rec.item_type_code (j)   := 'INKITS';
                    END IF;
                END LOOP;
            END IF;
        END LOOP;


        -- populate l_mrp_oe_rec with the good records from filter_mrp_oe_rec
        a                := 1;

        FOR i IN 1 .. num_of_lines
        LOOP
            IF (filter_mrp_oe_rec.line_id (i) <> -9999 AND ((filter_mrp_oe_rec.item_type_code (i) = 'STANDARD') OR (filter_mrp_oe_rec.item_type_code (i) = 'INKITS')))
            THEN
                EXTEND (l_mrp_oe_rec, 1);
                l_mrp_oe_rec.line_id (a)             := filter_mrp_oe_rec.line_id (i);
                l_mrp_oe_rec.ship_set_id (a)         :=
                    filter_mrp_oe_rec.ship_set_id (i);
                l_mrp_oe_rec.arrival_set_id (a)      :=
                    filter_mrp_oe_rec.arrival_set_id (i);
                l_mrp_oe_rec.seq_num (a)             :=
                    filter_mrp_oe_rec.seq_num (i);
                l_mrp_oe_rec.ato_line_id (a)         := NULL;
                l_mrp_oe_rec.top_model_line_id (a)   := NULL;
                l_mrp_oe_rec.item_type_code (a)      :=
                    filter_mrp_oe_rec.item_type_code (i);
                a                                    := a + 1;
            END IF;
        END LOOP;

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                'end of loop l_mrp_oe_rec.line_id.count is ' || l_mrp_oe_rec.line_id.COUNT);
        END IF;

        num_of_lines     := l_mrp_oe_rec.line_id.COUNT;
        l_seq            := 0;

        FOR k IN 1 .. num_of_lines
        LOOP
            IF l_mrp_oe_rec.seq_num (k) = 0
            THEN
                -- If a seq num has already not been assigned.
                l_seq                      := l_seq + 1;
                l_mrp_oe_rec.seq_num (k)   := l_seq;

                IF    l_mrp_oe_rec.ship_set_id (k) IS NOT NULL
                   OR l_mrp_oe_rec.arrival_set_id (k) IS NOT NULL
                THEN
                    -- If it is a ship or arrival set, loop thru rest of records and
                    -- assign the same (highest) seq num to other lines.
                    l_ship_set_id      := l_mrp_oe_rec.ship_set_id (k);
                    l_arrival_set_id   := l_mrp_oe_rec.arrival_set_id (k);

                    FOR m IN k + 1 .. num_of_lines
                    LOOP
                        IF ((l_mrp_oe_rec.ship_set_id (m) = l_ship_set_id OR l_mrp_oe_rec.arrival_set_id (m) = l_arrival_set_id) AND l_mrp_oe_rec.seq_num (m) = 0)
                        THEN
                            l_mrp_oe_rec.seq_num (m)   := l_seq;
                        END IF;
                    END LOOP;
                END IF;
            END IF;
        END LOOP;


        FOR k IN 1 .. num_of_lines
        LOOP
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'POPULATE_TEMP_TABLE: '
                    || ' line_id '
                    || l_mrp_oe_rec.line_id (k)
                    || 'item_type_code '
                    || l_mrp_oe_rec.item_type_code (k)
                    || ' seq '
                    || l_mrp_oe_rec.seq_num (k));
            END IF;
        END LOOP;

        OPEN check_oe ('FLOW_STATUS_CODE');

        FETCH check_oe INTO l_column_exist;

        CLOSE check_oe;

        j                := 1;


        IF l_column_exist = 1
        THEN
            l_sql_stmt   := l_sql_stmt1 || l_new_columns || l_sql_stmt2;
        ELSE
            l_sql_stmt   := l_sql_stmt1 || l_old_columns || l_sql_stmt2;
        END IF;


        IF (NVL (fnd_profile.VALUE ('MRP_ATP_CALC_SD'), 'N')) = 'Y'
        THEN
            l_profile_value   := 1;
        END IF;



        -- move data to bind arrays
        FOR x IN 1 .. l_mrp_oe_rec.seq_num.LAST
        LOOP
            bind1 (x)   := l_mrp_oe_rec.seq_num (x);
            bind2 (x)   := l_mrp_oe_rec.line_id (x);
        END LOOP;


        -- open cursor
        cur_hdl          := DBMS_SQL.open_cursor;

        -- parse cursor
        DBMS_SQL.parse (cur_hdl, l_sql_stmt, DBMS_SQL.native);

        -- supply binds
        DBMS_SQL.bind_array (cur_hdl, ':l_seq_num', bind1);
        DBMS_SQL.bind_array (cur_hdl, ':l_line_id', bind2);
        DBMS_SQL.bind_variable (cur_hdl, ':p_session_id', p_session_id);
        DBMS_SQL.bind_variable (cur_hdl, ':l_profile_value', l_profile_value);
        DBMS_SQL.bind_variable (cur_hdl, ':p_overwrite', p_overwrite);
        DBMS_SQL.bind_variable (cur_hdl, ':p_overwrite', p_overwrite);
        DBMS_SQL.bind_variable (cur_hdl, ':p_plan_id', ln_plan_id);
        DBMS_SQL.bind_variable (cur_hdl,
                                ':p_plan_run_date',
                                ld_plan_run_date);


        -- execute cursor
        rows_processed   := DBMS_SQL.execute (cur_hdl);

        -- close cursor
        DBMS_SQL.close_cursor (cur_hdl);

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug ('MSC_BAL_UTILS.populate_temp_table ');

            SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
              INTO l_time
              FROM DUAL;

            msc_sch_wb.atp_debug ('POPULATE_TEMP_TABLE: END ' || l_time);

            msc_sch_wb.atp_debug (
                   ' Calculate supply/demand profile_value is '
                || l_profile_value);
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'extend: '
                    || ' Excp in populate temp table '
                    || SUBSTR (SQLERRM, 1, 100));
            END IF;
    END populate_temp_table;

    PROCEDURE undemand_orders (p_session_id NUMBER, x_msg_count IN OUT NOCOPY NUMBER, x_msg_data IN OUT NOCOPY VARCHAR2
                               , x_return_status IN OUT NOCOPY VARCHAR2)
    IS
        x_atp_rec             MRP_ATP_PUB.atp_rec_typ;
        x_atp_rec_out         MRP_ATP_PUB.atp_rec_typ;
        x_atp_supply_demand   MRP_ATP_PUB.ATP_Supply_Demand_Typ;
        x_atp_period          MRP_ATP_PUB.ATP_Period_Typ;
        x_atp_details         MRP_ATP_PUB.ATP_Details_Typ;
        char_1_null           VARCHAR2 (2000) := NULL;
        char_30_null          VARCHAR2 (30) := NULL;
        number_null           NUMBER := NULL;
        date_null             DATE := NULL;
        l_session_id          NUMBER := p_session_id;
    BEGIN
        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug ('UNDEMAND_ORDERS ');
        END IF;

          SELECT ROWIDTOCHAR (a.ROWID), a.inventory_item_id, a.inventory_item_name,
                 a.organization_id, a.sr_instance_id, DECODE (override_flag, 'Y', NVL (a.firm_source_org_id, a.source_organization_id), a.source_organization_id),
                 DECODE (override_flag, 'Y', NVL (a.firm_source_org_code, a.source_organization_code), a.source_organization_code), a.order_line_id, a.Scenario_Id,
                 a.Order_Header_Id, a.order_number, a.Calling_Module,
                 a.Customer_Id, a.Customer_Site_Id, a.Destination_Time_Zone,
                 0,                                   --  send qty = 0  to atp
                    a.uom_code, DECODE (override_flag, 'Y', NVL (a.firm_ship_date, a.requested_ship_date), a.requested_ship_date),
                 DECODE (override_flag, 'Y', NVL (a.firm_arrival_date, a.requested_arrival_date), a.requested_arrival_date), date_null, --  a.Earliest_Acceptable_Date,
                                                                                                                                        a.Latest_Acceptable_Date,
                 a.Delivery_Lead_Time, a.Freight_Carrier, a.Ship_Method,
                 a.Demand_Class, a.Ship_Set_Name, -- When it is put back into the table the name will be used.
                                                  a.arrival_set_id, --a.Arrival_Set_Name
                 -- we don't append source_org since they can be different
                 -- and we don't need it since we don't have pick sources
                 a.Override_Flag, a.Action, date_null, --a.Ship_Date, ??? scheduled_ship_date
                 number_null,                         -- a.Available_Quantity,
                              number_null,       -- a.Requested_Date_Quantity,
                                           date_null,    -- a.Group_Ship_Date,
                 date_null,                           -- a.Group_Arrival_Date,
                            a.Vendor_Id, a.Vendor_Name,
                 a.Vendor_Site_Id, a.Vendor_Site_Name, a.Insert_Flag,
                 number_null,                                 -- a.Error_Code,
                              char_1_null,                  -- a.Error_Message
                                           a.old_source_organization_id,
                 a.old_demand_class, a.atp_lead_time,           -- bug 1303240
                                                      NULL, --substitution_typ_code,
                 NULL,                                 -- REQ_ITEM_DETAIL_FLAG
                       2,                                       -- ATP Pegging
                          a.assignment_set_id,                  -- ATP Pegging
                 a.sequence_number, a.firm_flag, a.order_line_number,
                 a.option_number, a.shipment_number, a.item_desc,
                 a.old_line_schedule_date, a.old_source_organization_code, a.firm_source_org_id,
                 a.firm_source_org_code, a.firm_ship_date, a.firm_arrival_date,
                 a.ship_method_text, a.ship_set_id, a.arrival_set_id,
                 a.PROJECT_ID, a.TASK_ID, a.PROJECT_NUMBER,
                 a.TASK_NUMBER, a.Top_Model_line_id, a.ATO_Model_Line_Id,
                 a.Parent_line_id, a.Config_item_line_id, a.Validation_Org,
                 a.Component_Sequence_ID, a.Component_Code, a.line_number,
                 a.included_item_flag
            BULK COLLECT INTO x_atp_rec.row_id, x_atp_rec.Inventory_Item_Id, x_atp_rec.Inventory_Item_Name,
                              x_atp_rec.organization_id, x_atp_rec.instance_id, x_atp_rec.Source_Organization_Id,
                              x_atp_rec.Source_Organization_Code, x_atp_rec.Identifier, x_atp_rec.Scenario_Id,
                              x_atp_rec.Demand_Source_Header_Id, x_atp_rec.order_number, x_atp_rec.Calling_Module,
                              x_atp_rec.Customer_Id, x_atp_rec.Customer_Site_Id, x_atp_rec.Destination_Time_Zone,
                              x_atp_rec.Quantity_Ordered, x_atp_rec.Quantity_UOM, x_atp_rec.Requested_Ship_Date,
                              x_atp_rec.Requested_Arrival_Date, x_atp_rec.Earliest_Acceptable_Date, x_atp_rec.Latest_Acceptable_Date,
                              x_atp_rec.Delivery_Lead_Time, x_atp_rec.Freight_Carrier, x_atp_rec.Ship_Method,
                              x_atp_rec.Demand_Class, x_atp_rec.Ship_Set_Name, x_atp_rec.Arrival_Set_Name,
                              x_atp_rec.Override_Flag, x_atp_rec.Action, x_atp_rec.Ship_Date,
                              x_atp_rec.Available_Quantity, x_atp_rec.Requested_Date_Quantity, x_atp_rec.Group_Ship_Date,
                              x_atp_rec.Group_Arrival_Date, x_atp_rec.Vendor_Id, x_atp_rec.Vendor_Name,
                              x_atp_rec.Vendor_Site_Id, x_atp_rec.Vendor_Site_Name, x_atp_rec.Insert_Flag,
                              x_atp_rec.ERROR_CODE, x_atp_rec.MESSAGE, x_atp_rec.old_source_organization_id,
                              x_atp_rec.old_demand_class, x_atp_rec.atp_lead_time, -- bug 1303240
                                                                                   x_atp_rec.substitution_typ_code,
                              x_atp_rec.REQ_ITEM_DETAIL_FLAG, x_atp_rec.attribute_02, -- ATP Pegging
                                                                                      x_atp_rec.attribute_03,
                              x_atp_rec.sequence_number, x_atp_rec.firm_flag, x_atp_rec.order_line_number,
                              x_atp_rec.option_number, x_atp_rec.shipment_number, x_atp_rec.item_desc,
                              x_atp_rec.old_line_schedule_date, x_atp_rec.old_source_organization_code, x_atp_rec.firm_source_org_id,
                              x_atp_rec.firm_source_org_code, x_atp_rec.firm_ship_date, x_atp_rec.firm_arrival_date,
                              x_atp_rec.ship_method_text, x_atp_rec.ship_set_id, x_atp_rec.arrival_set_id,
                              x_atp_rec.PROJECT_ID, x_atp_rec.TASK_ID, x_atp_rec.PROJECT_NUMBER,
                              x_atp_rec.TASK_NUMBER, x_atp_rec.Top_Model_line_id, x_atp_rec.ATO_Model_Line_Id,
                              x_atp_rec.Parent_line_id, x_atp_rec.Config_item_line_id, x_atp_rec.Validation_Org,
                              x_atp_rec.Component_Sequence_ID, x_atp_rec.Component_Code, x_atp_rec.line_number,
                              x_atp_rec.included_item_flag
            FROM mrp_atp_schedule_temp a
           WHERE a.session_id = p_session_id AND a.status_flag = 1
        ORDER BY a.sequence_number;

        IF x_atp_rec.inventory_item_id.COUNT > 0
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'UNDEMAND_ORDERS: '
                    || ' Before calling scheduling '
                    || x_atp_rec.inventory_item_id.COUNT);
            END IF;

            MSC_SATP_FUNC.new_extend_atp (x_atp_rec,
                                          x_atp_rec.inventory_item_id.COUNT,
                                          x_return_status);

            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                    'GET_ATP_RESULT: after new_extend_atp' || x_return_status);
            END IF;

            IF x_return_status <> 'E'
            THEN
                MRP_ATP_PUB.call_atp_no_commit (l_session_id,
                                                x_atp_rec,
                                                x_atp_rec_out,
                                                x_atp_supply_demand,
                                                x_atp_period,
                                                x_atp_details,
                                                x_return_status,
                                                x_msg_data,
                                                x_msg_count);
            END IF;
        END IF;

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                   'UNDEMAND_ORDERS '
                || 'After calling Scheduling '
                || x_return_status
                || ' $ '
                || x_msg_data
                || ' $ '
                || x_atp_rec_out.inventory_item_id.COUNT);
        END IF;

        IF x_return_status = 'E'
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'UNDEMAND_ORDERS '
                    || ' err '
                    || x_msg_data
                    || ' '
                    || x_msg_count);
            END IF;
        END IF;

        IF x_atp_rec_out.inventory_item_id.COUNT > 0
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                    'UNDEMAND_ORDERS ' || ' sched date ' || x_atp_rec_out.ship_date.COUNT);
                msc_sch_wb.atp_debug (
                    'UNDEMAND_ORDERS ' || ' SD ' || x_atp_supply_demand.LEVEL.COUNT);
                msc_sch_wb.atp_debug (
                    'UNDEMAND_ORDERS ' || ' period ' || x_atp_period.LEVEL.COUNT);
                msc_sch_wb.atp_debug (
                    'UNDEMAND_ORDERS ' || ' details ' || x_atp_details.LEVEL.COUNT);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       ' Exception in undemand_orders '
                    || SUBSTR (SQLERRM, 1, 100));
            END IF;

            x_return_status   := 'E';
            x_msg_data        := SUBSTR (SQLERRM, 1, 100);
    END undemand_orders;

    PROCEDURE reschedule (
        p_session_id                    NUMBER,
        x_msg_count          OUT NOCOPY NUMBER,
        x_msg_data           OUT NOCOPY VARCHAR2,
        x_return_status      OUT NOCOPY VARCHAR2,
        p_tcf                           BOOLEAN DEFAULT TRUE)
    IS
        --p_atp_qty_ordered_temp ATP_QTY_ORDERED_TYP;
        p_atp_qty_ordered_temp   XXD_ATP_QTY_ORDERED_TYP;  -- Added by BT Team
        l_return_status          VARCHAR2 (1);
        l_error_message          VARCHAR2 (100);
        l_time                   VARCHAR2 (80);
    BEGIN
        order_sch_wb.debug_session_id   := p_session_id;

        -- need to remember  the original qty ordered before undemanding
        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug ('MSC_BAL_UTILS.reschedule ');

            SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
              INTO l_time
              FROM DUAL;

            msc_sch_wb.atp_debug ('RESCHEDULE: BEGIN ' || l_time);
        END IF;


        SELECT quantity_ordered, order_line_id, session_id,
               sequence_number
          BULK COLLECT INTO p_atp_qty_ordered_temp.quantity_ordered, p_atp_qty_ordered_temp.order_line_id, p_atp_qty_ordered_temp.session_id,
                            p_atp_qty_ordered_temp.sequence_number
          FROM mrp_atp_schedule_temp
         WHERE session_id = p_session_id AND status_flag = 1;

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug ('MSC_BAL_UTILS.reschedule ');

            SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
              INTO l_time
              FROM DUAL;

            msc_sch_wb.atp_debug (
                'RESCHEDULE: b4 undemand_orders ' || l_time);
        END IF;

        undemand_orders (p_session_id, x_msg_count, x_msg_data,
                         x_return_status);

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug ('MSC_BAL_UTILS.reschedule ');

            SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
              INTO l_time
              FROM DUAL;

            msc_sch_wb.atp_debug (
                'RESCHEDULE: after undemand_orders ' || l_time);
        END IF;

        update_schedule_qties (p_atp_qty_ordered_temp,
                               l_return_status,
                               l_error_message);

        IF l_return_status <> 'E'
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug ('MSC_BAL_UTILS.reschedule ');

                SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                  INTO l_time
                  FROM DUAL;

                msc_sch_wb.atp_debug (
                    'RESCHEDULE: b4 schedule_orders ' || l_time);
            END IF;

            schedule_orders (p_session_id, x_msg_count, x_msg_data,
                             x_return_status);

            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug ('MSC_BAL_UTILS.reschedule ');

                SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                  INTO l_time
                  FROM DUAL;

                msc_sch_wb.atp_debug (
                    'RESCHEDULE: after  schedule_orders ' || l_time);
            END IF;
        ELSE
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'RESCHEDULE: '
                    || ' error is update_qty '
                    || l_error_message);
            END IF;
        END IF;

        XXD_MSC_ONT_ATP_LEVEL_PKG.update_atp_temp_screen3 (p_session_id); -- Added by BT Team on 20-OCT-2015
    END reschedule;


    PROCEDURE update_schedule_qties (p_atp_qty_ordered_temp IN XXD_MSC_BAL_UTILS.XXD_ATP_QTY_ORDERED_TYP, -- Modified by BT Team 14 Oct
                                                                                                          p_return_status OUT NOCOPY VARCHAR2, p_error_message OUT NOCOPY VARCHAR2)
    IS
        l_count   NUMBER := 0;
    BEGIN
        p_return_status   := 'S';

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            SELECT COUNT (*)
              INTO l_count
              FROM mrp_atp_schedule_temp
             WHERE     session_id = p_atp_qty_ordered_temp.session_id (1)
                   AND status_flag = 1;

            msc_sch_wb.atp_debug (
                   'MSC_BAL_UTILS.update_schedule_qties status_flag = 1 rec are '
                || l_count);

            l_count   := 0;

            SELECT COUNT (*)
              INTO l_count
              FROM mrp_atp_schedule_temp
             WHERE     session_id = p_atp_qty_ordered_temp.session_id (1)
                   AND status_flag = 2;

            msc_sch_wb.atp_debug (
                   'MSC_BAL_UTILS.update_schedule_qties status_flag = 2 rec are '
                || l_count);

            l_count   := 0;

            SELECT COUNT (*)
              INTO l_count
              FROM mrp_atp_schedule_temp
             WHERE session_id = p_atp_qty_ordered_temp.session_id (1);

            msc_sch_wb.atp_debug (
                   'MSC_BAL_UTILS.update_schedule_qties TOTAL  rec are '
                || l_count);
        END IF;

        FORALL lCounter IN 1 .. p_atp_qty_ordered_temp.order_line_id.COUNT
            UPDATE mrp_atp_schedule_temp
               SET status_flag = 1, quantity_ordered = p_atp_qty_ordered_temp.quantity_ordered (lCounter)
             WHERE     session_id =
                       p_atp_qty_ordered_temp.session_id (lCounter)
                   AND order_line_id =
                       p_atp_qty_ordered_temp.order_line_id (lCounter)
                   AND sequence_number =
                       p_atp_qty_ordered_temp.sequence_number (lCounter) -- Added by BT
                   AND status_flag = 2;

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                   'MSC_BAL_UTILS.update_schedule_qties '
                || p_atp_qty_ordered_temp.order_line_id.COUNT);
            l_count   := 0;

            SELECT COUNT (*)
              INTO l_count
              FROM mrp_atp_schedule_temp
             WHERE session_id = p_atp_qty_ordered_temp.session_id (1);

            msc_sch_wb.atp_debug (
                   'MSC_BAL_UTILS.update_schedule_qties TOTAL  rec are '
                || l_count);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 'E';
            p_error_message   := SUBSTR (SQLERRM, 1, 100);
    END update_schedule_qties;



    PROCEDURE cmt_schedule (
        p_user_id                       NUMBER,
        p_resp_id                       NUMBER,
        p_appl_id                       NUMBER,
        p_session_id                    NUMBER,
        x_msg_count          OUT NOCOPY NUMBER,
        x_msg_data           OUT NOCOPY VARCHAR2,
        x_return_status      OUT NOCOPY VARCHAR2,
        p_tcf                           BOOLEAN DEFAULT TRUE)
    IS
        --p_atp_qty_ordered_temp ATP_QTY_ORDERED_TYP;
        p_atp_qty_ordered_temp   XXD_ATP_QTY_ORDERED_TYP;       -- Added by BT
        l_return_status          VARCHAR2 (1);
        l_error_message          VARCHAR2 (100);
        l_time                   VARCHAR2 (80);

        CURSOR records_exist IS
            SELECT COUNT (*)
              FROM mrp_atp_schedule_temp
             WHERE session_id = p_session_id AND status_flag = 2;

        l_records_exist          NUMBER := 0;
        pipe_msg_count           NUMBER;
        pipe_return_status       VARCHAR2 (10);
        pipe_msg_data            VARCHAR2 (10);
        l_count                  NUMBER;
    BEGIN
        order_sch_wb.debug_session_id   := p_session_id;

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                   ' Begin MSC_BAL_UTILS.commit_schedule session_id '
                || p_session_id);
            msc_sch_wb.atp_debug ('MSC_BAL_UTILS.cmt_schedule ');

            SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
              INTO l_time
              FROM DUAL;

            msc_sch_wb.atp_debug ('cmt_schedule begin ' || l_time);
        END IF;

        OPEN records_exist;

        FETCH records_exist INTO l_records_exist;

        CLOSE records_exist;

        -- if records exist it means this is saving after scheduling
        IF l_records_exist > 0
        THEN
            DELETE FROM mrp_atp_schedule_temp
                  WHERE session_id = p_session_id AND status_flag = 1;

            DELETE FROM mrp_atp_details_temp
                  WHERE session_id = p_session_id;

            UPDATE mrp_atp_schedule_temp
               SET status_flag   = 1
             WHERE session_id = p_session_id AND status_flag = 2;

            -- if i am saving after scheduling
            -- and om will fail we need to
            -- make sure these records are gone!
            -- otherwise everything inside this if
            -- will be rollbacked by atpui_util package
            IF (p_tcf)
            THEN
                COMMIT;
            END IF;
        END IF;

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                'msc_bal_utils: In Commit_schedule: undemanding orders');
        END IF;

        SELECT quantity_ordered, order_line_id, session_id,
               sequence_number
          BULK COLLECT INTO p_atp_qty_ordered_temp.quantity_ordered, p_atp_qty_ordered_temp.order_line_id, p_atp_qty_ordered_temp.session_id,
                            p_atp_qty_ordered_temp.sequence_number
          FROM mrp_atp_schedule_temp
         WHERE session_id = p_session_id AND status_flag = 1;

        undemand_orders (p_session_id, x_msg_count, x_msg_data,
                         x_return_status);
        update_schedule_qties (p_atp_qty_ordered_temp,
                               l_return_status,
                               l_error_message);

        IF l_return_status <> 'E'
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'msc_bal_utils: In Commit_schedule '
                    || ' calling get_atp_result ');
            END IF;

            msc_sch_wb.get_atp_result (p_session_id,
                                       2,
                                       2,
                                       x_msg_count,
                                       x_msg_data,
                                       x_return_status);

            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug ('MSC_BAL_UTILS.cmt_schedule ');

                SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                  INTO l_time
                  FROM DUAL;

                msc_sch_wb.atp_debug (
                    'cmt_schedule: after call to atp ' || l_time);
            END IF;

            IF x_return_status <> 'S'
            THEN
                IF PG_DEBUG IN ('Y', 'C')
                THEN
                    msc_sch_wb.atp_debug (
                           'MSC_BAL_UTILS.commit_schedule  '
                        || ' sth wrong in get_atp_results'
                        || x_msg_data);
                END IF;

                RETURN;                           -- sth wrong with atp engine
            ELSE                    -- atp is successful , proceed  to om call
                -- need to reset client_info before
                --calling OM api to avoid bug 3145033
                --dbms_application_info.set_client_info(fnd_profile.value('ORG_ID'));
                fnd_global.apps_initialize (p_user_id, p_resp_id, p_appl_id);
                mo_global.init ('ONT');                        -- MOAC changes

                IF PG_DEBUG IN ('Y', 'C')
                THEN
                    msc_sch_wb.atp_debug (
                        'MSC_BAL_UTILS.cmt_schedule: calling OE ');

                    SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                      INTO l_time
                      FROM DUAL;

                    msc_sch_wb.atp_debug (
                        'cmt_schedule: calling OM BEGIN ' || l_time);
                END IF;

                msc_bal_utils.call_oe_api (p_session_id, x_msg_count, x_msg_data
                                           , x_return_status);

                IF PG_DEBUG IN ('Y', 'C')
                THEN
                    msc_sch_wb.atp_debug (
                        'MSC_BAL_UTILS.cmt_schedule: calling OE ');

                    SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                      INTO l_time
                      FROM DUAL;

                    msc_sch_wb.atp_debug (
                        'cmt_schedule: calling OM DONE ' || l_time);
                    msc_sch_wb.atp_debug (
                        ' cmt_schedule : x_msg_data ' || x_msg_data);
                END IF;

                IF x_return_status <> 'S'
                THEN                                       -- from call_oe_api
                    g_om_status   := x_return_status;
                    g_om_req_id   := TO_NUMBER (x_msg_data);

                    IF PG_DEBUG IN ('Y', 'C')
                    THEN
                        msc_sch_wb.atp_debug (
                               'MSC_BAL_UTILS.call_oe_api in cmt_schedule'
                            || x_msg_data);
                    END IF;

                    -- we need to let forms know that OM failed
                    IF (p_tcf)
                    THEN
                        msc_sch_wb.atp_debug (
                            ' tcf is on x_return_status ' || x_return_status);

                        -- call pipe api to send a message that OM failed
                        IF x_return_status = 'OMERROR'
                        THEN
                            msc_sch_wb.pipe_utility (p_session_id, 'OMERROR', x_msg_data, -- this request_id
                                                                                          pipe_msg_count, pipe_return_status, pipe_msg_data
                                                     , pipe_msg_count);
                        END IF;

                        MSC_ATPUI_UTIL.populate_mrp_atp_temp_tables (
                            p_session_id,
                            l_return_status,
                            l_error_message);
                        msc_sch_wb.calc_exceptions (p_session_id, x_return_status, x_msg_data
                                                    , x_msg_count);
                        COMMIT;     -- commit only for tcf because rollback of
                    -- atp inserted data already happened inside of MSC_ATPUI_UTIL
                    ELSE                                      -- not not p_tcf
                        MSC_ATPUI_UTIL.populate_mrp_atp_temp_tables (
                            p_session_id,
                            l_return_status,
                            l_error_message);
                    END IF;                                        -- if p_tcf
                END IF;                             -- oe api returned success
            END IF;                               -- sth wrong with atp engine
        ELSE
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'cmt_schedule: '
                    || ' error in update_qty '
                    || l_error_message);
            END IF;
        END IF;

        IF g_om_status = 'OMERROR'
        THEN
            x_return_status   := g_om_status;
            x_msg_data        := TO_CHAR (g_om_req_id);
        END IF;
    END cmt_schedule;


    PROCEDURE schedule_orders (
        p_session_id                    NUMBER,
        x_msg_count          OUT NOCOPY NUMBER,
        x_msg_data           OUT NOCOPY VARCHAR2,
        x_return_status      OUT NOCOPY VARCHAR2,
        p_tcf                           BOOLEAN DEFAULT TRUE)
    IS
        --bug#2452524
        TYPE RowidTab IS TABLE OF ROWID
            INDEX BY BINARY_INTEGER;

        TYPE CharTab IS TABLE OF VARCHAR2 (30)
            INDEX BY BINARY_INTEGER;

        lb_rowid              RowidTab;
        lb_flow_status_code   CharTab;

        CURSOR check_oe IS
            SELECT 1
              FROM user_tab_columns
             WHERE     table_name = 'OE_MRP_OPEN_DEMANDS_V'
                   AND column_name = 'FLOW_STATUS_CODE';

        l_column_exist        NUMBER;
        l_time                VARCHAR2 (80);

        TYPE CurTyp IS REF CURSOR;

        c1                    CurTyp;

        sql_stmt              VARCHAR2 (3000)
            :=    ' update mrp_atp_schedule_temp a set flow_status_code = '
               -- || '   ( select flow_status_code from oe_mrp_open_demands_v b ' -- Commented by NRK ON 07Dec
               || '   ( select flow_status_code from oe_order_lines_all b ' -- Added by NRK ON 07Dec
               || '     where  a.order_line_id = b.line_id ) '
               || ' where  a.session_id = :p_session_id ';

        l_return_status       VARCHAR2 (1);
        l_error_message       VARCHAR2 (100);
    BEGIN
        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug ('msc_bal_utils.schedule_orders');
        END IF;

        msc_sch_wb.get_atp_result (p_session_id, 2, 2,
                                   x_msg_count, x_msg_data, x_return_status);

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
              INTO l_time
              FROM DUAL;

            msc_sch_wb.atp_debug (
                   ' MSC_BAL_UTILS.schedule_orders  atp engine call END '
                || l_time);
            msc_sch_wb.atp_debug (' x_return_status ' || x_return_status);
        END IF;

        IF x_return_status <> 'S'
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'extend: '
                    || ' schedule_orders : call to get_atp_result returned error '
                    || x_msg_data);
            END IF;

            RETURN;
        ELSE
            -- before we used to call populate_mrp_atp_temp_tables only for
            -- tcf. however, client wants data in temp table even if tcf
            -- not used.
            -- so we will cal populate_mrp_atp_temp_tables all the time.
            -- this will insure that the data inserted by atp is rollbacked
            -- but temp table data stays for further usage, such as reports and etc...
            IF ((p_tcf) OR (NVL (fnd_profile.VALUE ('MRP_ATP_PERSIST'), 'N')) = 'Y')
            THEN
                IF PG_DEBUG IN ('Y', 'C')
                THEN
                    msc_sch_wb.atp_debug (
                           'MSC_BAL_UTILS.schedule_orders '
                        || ' calling populate_mrp_atp_temp_tables '
                        || ' tcf is used ');

                    SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                      INTO l_time
                      FROM DUAL;

                    msc_sch_wb.atp_debug (
                           ' MSC_BAL_UTILS.schedule_orders  b4 call to populate_mrp_atp_temp_tables  '
                        || l_time);
                END IF;

                MSC_ATPUI_UTIL.populate_mrp_atp_temp_tables (p_session_id,
                                                             l_return_status,
                                                             l_error_message);

                IF PG_DEBUG IN ('Y', 'C')
                THEN
                    SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                      INTO l_time
                      FROM DUAL;

                    msc_sch_wb.atp_debug (
                           ' MSC_BAL_UTILS.schedule_orders  after  call to populate_mrp_atp_temp_tables  '
                        || l_time);
                END IF;

                IF l_return_status <> 'S'
                THEN
                    IF PG_DEBUG IN ('Y', 'C')
                    THEN
                        msc_sch_wb.atp_debug (
                               'MSC_BAL_UTILS.schedule_orders '
                            || 'sth wrong in populate_mrp_atp_temp_tables '
                            || l_error_message);
                    END IF;
                END IF;
            END IF;                                                   -- p_tcf


            IF PG_DEBUG IN ('Y', 'C')
            THEN
                SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                  INTO l_time
                  FROM DUAL;

                msc_sch_wb.atp_debug (
                       ' MSC_BAL_UTILS.schedule_orders b4  call to calc_exceptions  '
                    || l_time);
            END IF;

            msc_sch_wb.calc_exceptions (p_session_id, x_return_status, x_msg_data
                                        , x_msg_count);

            IF ((p_tcf) OR (NVL (fnd_profile.VALUE ('MRP_ATP_PERSIST'), 'N')) = 'Y')
            THEN
                COMMIT;
            END IF;

            IF PG_DEBUG IN ('Y', 'C')
            THEN
                SELECT TO_CHAR (SYSDATE, 'DD-MM-YYYY HH24:MI:SS')
                  INTO l_time
                  FROM DUAL;

                msc_sch_wb.atp_debug (
                       ' MSC_BAL_UTILS.schedule_orders after   call to calc_exceptions  '
                    || l_time);
            END IF;

            IF x_return_status <> 'S'
            THEN
                IF PG_DEBUG IN ('Y', 'C')
                THEN
                    msc_sch_wb.atp_debug (
                           'extend: '
                        || ' schedule_orders : call to calc_exceptions returned error '
                        || x_msg_data);
                END IF;
            ELSE
                IF (p_tcf)
                THEN
                    COMMIT;                   -- commit exception calculations
                END IF;
            END IF;
        END IF;

        OPEN check_oe;

        FETCH check_oe INTO l_column_exist;

        CLOSE check_oe;

        IF l_column_exist = 1
        THEN
            --dbms_application_info.set_client_info(fnd_profile.value('ORG_ID'));
            mo_global.init ('ONT');

            EXECUTE IMMEDIATE sql_stmt
                USING p_session_id;
        END IF;
    END schedule_orders;


    PROCEDURE execute_command (p_command VARCHAR2, p_user_command NUMBER, x_msg_data OUT NOCOPY VARCHAR2
                               , x_return_status OUT NOCOPY VARCHAR2)
    IS
        x_msg_count   NUMBER;
        dummy1        VARCHAR2 (1000);
        dummy2        VARCHAR2 (1000);
    BEGIN
        x_return_status   := 'S';

        IF p_user_command = 1
        THEN                                 -- then we pass the std arguments
            EXECUTE IMMEDIATE p_command
                USING OUT x_msg_count, OUT x_msg_data, OUT x_return_status;
        ELSE
            EXECUTE IMMEDIATE p_command;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'extend: '
                    || ' Exception in execute command '
                    || SUBSTR (SQLERRM, 1, 100));
            END IF;

            x_return_status   := 'E';
            x_msg_data        := SUBSTR (SQLERRM, 1, 100);
    END execute_command;


    PROCEDURE EXTEND (p_nodes         IN OUT NOCOPY mrp_bal_utils.mrp_oe_rec,
                      extend_amount                 NUMBER)
    IS
    BEGIN
        p_nodes.line_id.EXTEND (extend_amount);
        p_nodes.ship_set_id.EXTEND (extend_amount);
        p_nodes.arrival_set_id.EXTEND (extend_amount);
        p_nodes.seq_num.EXTEND (extend_amount);
        p_nodes.ato_line_id.EXTEND (extend_amount);
        p_nodes.top_model_line_id.EXTEND (extend_amount);
        p_nodes.item_type_code.EXTEND (extend_amount);
        p_nodes.order_number.EXTEND (extend_amount);
    END EXTEND;

    PROCEDURE EXTEND (p_nodes         IN OUT NOCOPY mrp_bal_utils.seq_alter,
                      extend_amount                 NUMBER)
    IS
    BEGIN
        p_nodes.order_line_id.EXTEND (extend_amount);
        p_nodes.ship_set_id.EXTEND (extend_amount);
        p_nodes.arrival_set_id.EXTEND (extend_amount);
        p_nodes.seq_diff.EXTEND (extend_amount);
    END EXTEND;

    PROCEDURE TRIM (p_nodes       IN OUT NOCOPY mrp_bal_utils.mrp_oe_rec,
                    trim_amount                 NUMBER)
    IS
    BEGIN
        p_nodes.line_id.TRIM (trim_amount);
        p_nodes.ship_set_id.TRIM (trim_amount);
        p_nodes.arrival_set_id.TRIM (trim_amount);
        p_nodes.seq_num.TRIM (trim_amount);
    END TRIM;

    PROCEDURE call_oe_api (p_session_id NUMBER, x_msg_count OUT NOCOPY NUMBER, x_msg_data OUT NOCOPY VARCHAR2
                           , x_return_status OUT NOCOPY VARCHAR2)
    IS
        -- Records must be passed by ordering with
        --org_id(OU),header_id, arrrival_set_id, ship_set_id, top_model_line_id, ato_line_id

        CURSOR mast_cursor IS
              SELECT mrp.order_line_id, omodv.org_id, mrp.order_header_id,
                     mrp.source_organization_id, NVL (mrp.group_ship_date, mrp.scheduled_ship_date), NVL (mrp.group_arrival_date, mrp.scheduled_arrival_date),
                     TO_DATE (NULL),                      --earliest_ship_date
                                     mrp.delivery_lead_time, mrp.ship_method,
                     DECODE (mrp.firm_flag,  1, 'Y',  2, 'N')
                FROM mrp_atp_schedule_temp mrp, oe_mrp_open_demands_v omodv
               WHERE     mrp.session_id = p_session_id
                     AND mrp.order_line_id = omodv.line_id
                     AND mrp.order_header_id = omodv.header_id
                     AND mrp.status_flag = 2
                     AND (mrp.ERROR_CODE IS NULL OR (mrp.ERROR_CODE IS NOT NULL AND mrp.ERROR_CODE IN ('0', '150', '61')))
            ORDER BY omodv.org_id, mrp.order_header_id, omodv.arrival_set_id,
                     omodv.ship_set_id, omodv.top_model_line_id, omodv.ato_line_id;



        mast_table     oe_order_sch_util.mrp_line_tbl_type;
        --mast_table RSF1.mrp_line_tbl_type;
        p_so_table     OE_SCHEDULE_GRP.Sch_Tbl_Type;

        j              NUMBER;
        l_dir          VARCHAR2 (60);
        l_file_val     VARCHAR2 (100);
        l_request_id   NUMBER;
    BEGIN
        x_return_status   := 'S';

        OPEN mast_cursor;

        j                 := 1;

        LOOP
            FETCH mast_cursor
                INTO p_so_table (j).line_id, p_so_table (j).Org_id, p_so_table (j).Header_id, p_so_table (j).Ship_from_org_id,
                     p_so_table (j).Schedule_ship_date, p_so_table (j).Schedule_arrival_date, p_so_table (j).Earliest_ship_date,
                     p_so_table (j).Delivery_lead_time, p_so_table (j).Shipping_Method_Code, p_so_table (j).Firm_Demand_Flag;

            EXIT WHEN mast_cursor%NOTFOUND;

            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       ' call_oe_api: '
                    || ' Fetching record to pass to OE:  line_id '
                    || p_so_table (j).line_id
                    || ' schedule_ship_date  '
                    || p_so_table (j).Schedule_ship_date
                    || ' arrival_date  '
                    || p_so_table (j).schedule_arrival_date
                    || ' ship_from_org_id  '
                    || p_so_table (j).ship_from_org_id
                    || ' ship_method  '
                    || p_so_table (j).Shipping_Method_Code
                    || ' operating_unit '
                    || p_so_table (j).Org_id);
            END IF;

            j   := j + 1;
        END LOOP;

        BEGIN
            -- setup OM debug file if ATP Debug is set to Yes
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'call_oe_api: '
                    || ' before calling Update_Scheduling_Results '
                    || p_so_table.COUNT);
                msc_sch_wb.atp_debug (
                    'Initializing  OM Debug file generation ');

                SELECT LTRIM (RTRIM (VALUE))
                  INTO l_dir
                  FROM (  SELECT VALUE
                            FROM v$parameter2
                           WHERE name = 'utl_file_dir'
                        ORDER BY ROWNUM DESC)
                 WHERE ROWNUM < 2;

                IF l_dir IS NULL
                THEN
                    SELECT VALUE
                      INTO l_dir
                      FROM v$parameter
                     WHERE name = 'utl_file_dir';
                END IF;

                msc_sch_wb.atp_debug (
                    'call_oe_api:OM debugging dir is ' || l_dir);

                fnd_profile.put ('OE_DEBUG_LOG_DIRECTORY', l_dir);
                oe_debug_pub.debug_on;
                oe_debug_pub.initialize;
                oe_debug_pub.setdebuglevel (5);
                msc_sch_wb.atp_debug (
                    'call_oe_api:OM debugging done setdebuglevel');
                l_file_val   := OE_DEBUG_PUB.Set_Debug_Mode ('FILE');


                msc_sch_wb.atp_debug (
                       'call_oe_api: '
                    || ' OM debugging l_file_val is '
                    || l_file_val);
                oe_debug_pub.add ('CALLING FROM ATP', 1);
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                msc_sch_wb.atp_debug (
                    ' There is something wrong with OE debug
                            file generation. No OM debug file will
                            be created ');
                msc_sch_wb.atp_debug (
                    ' The error is  ' || SUBSTR (SQLERRM, 1, 100));
        END;

        SELECT oe_msg_request_id_s.NEXTVAL INTO l_request_id FROM DUAL;

        OE_SCHEDULE_GRP.Update_Scheduling_Results (p_so_table,
                                                   l_request_id,
                                                   x_return_status);

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                   'in call_oe_api: '
                || ' after calling Update_Results_from_backlog_wb '
                || x_return_status
                || ' '
                || x_return_status);
        END IF;

        IF x_return_status = fnd_api.G_RET_STS_SUCCESS
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'call_oe_api: '
                    || ' Committing session after call to OE_API'
                    || x_return_status);
            END IF;

            COMMIT;
        ELSE                                                      -- om failed
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'in call_oe_api: '
                    || ' call to OE_AP errored out x_return_status '
                    || x_return_status);
            END IF;

            -- if error status is W or E
            -- that is a valid error which
            -- could be looked up in OM messages
            IF x_return_status <> 'U'
            THEN
                x_msg_data        := TO_CHAR (l_request_id);
                x_return_status   := 'OMERROR';
            ELSE      -- still error but no messages are found, so un-expected
                x_return_status   := 'U';
                x_msg_data        :=
                    'Unexpected error in oe_order_sch_util.Update_Results_from_backlog_wb ';
            END IF;
        -- do not rollback here, even if om fails
        -- we need to hold on to atp records
        -- rollback in parent call
        -- ROLLBACK;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := 'E';

            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                    ' excp in call_oe_api  ' || SUBSTR (SQLERRM, 1, 100));
            END IF;
    END call_oe_api;

    PROCEDURE call_oe_api (p_atp_rec MRP_ATP_PUB.atp_rec_typ, x_msg_count OUT NOCOPY NUMBER, x_msg_data OUT NOCOPY VARCHAR2
                           , x_return_status OUT NOCOPY VARCHAR2)
    IS
        mast_table   oe_order_sch_util.mrp_line_tbl_type;
        counter      NUMBER := 0;
    BEGIN
        FOR j IN 1 .. p_atp_rec.inventory_item_id.COUNT
        LOOP
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       ' call_oe_api '
                    || p_atp_rec.identifier (j)
                    || ' '
                    || p_atp_rec.ship_date (j)
                    || ' '
                    || p_atp_rec.source_organization_id (j)
                    || ' '
                    || p_atp_rec.ERROR_CODE (j));
            END IF;

            -- cnazarma bug #2605828 only need to select eligible lines
            IF    p_atp_rec.ERROR_CODE (j) IS NULL
               OR     p_atp_rec.ERROR_CODE (j) IS NOT NULL
                  AND p_atp_rec.ERROR_CODE (j) NOT IN ('0', '150', '61')
            THEN
                counter                        := counter + 1;
                --mast_table.extend;
                mast_table (counter).line_id   := p_atp_rec.identifier (j);
                mast_table (counter).schedule_ship_date   :=
                    p_atp_rec.ship_date (j);
                mast_table (counter).schedule_arrival_date   :=
                      p_atp_rec.ship_date (j)
                    + p_atp_rec.delivery_lead_time (j);
                mast_table (counter).ship_from_org_id   :=
                    p_atp_rec.source_organization_id (j);
                mast_table (counter).ship_method_code   :=
                    p_atp_rec.ship_method (j);
            END IF;
        END LOOP;

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                   'call_oe_api: '
                || ' Count of records to pass to OE = '
                || counter);
        END IF;

        IF counter > 0
        THEN
            oe_order_sch_util.Update_Results_from_backlog_wb (
                mast_table,
                x_msg_count,
                x_msg_data,
                x_return_status);

            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'call_oe_api: '
                    || ' after calling Update_Results_from_backlog_wb II '
                    || x_return_status
                    || ' '
                    || x_msg_data);
            END IF;

            IF x_return_status = fnd_api.G_RET_STS_SUCCESS
            THEN
                IF PG_DEBUG IN ('Y', 'C')
                THEN
                    msc_sch_wb.atp_debug (
                           'call_oe_api: '
                        || ' Committing session after call to OE_API II '
                        || x_return_status);
                END IF;

                COMMIT;
            ELSE
                IF PG_DEBUG IN ('Y', 'C')
                THEN
                    msc_sch_wb.atp_debug (
                           'call_oe_api: '
                        || ' rolling back session after call to OE_API II '
                        || x_return_status);
                END IF;

                x_return_status   := 'E';
                x_msg_data        :=
                    'Unexpected error in oe_order_sch_util.Update_Results_from_backlog_wb II ';
                ROLLBACK;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                    ' excp in call_oe_api II ' || SUBSTR (SQLERRM, 1, 100));
            END IF;
    END call_oe_api;

    PROCEDURE update_seq (
        p_session_id                    NUMBER,
        p_seq_alter       IN OUT NOCOPY mrp_bal_utils.seq_alter,
        x_msg_count          OUT NOCOPY NUMBER,
        x_msg_data           OUT NOCOPY VARCHAR2,
        x_return_status      OUT NOCOPY VARCHAR2)
    IS
        l_old_seq            NUMBER;
        l_new_seq            NUMBER;
        l_max_seq            NUMBER;

        -- The p_seq_alter was initially IN, but the form was crashing for some
        -- reason. Once I made it to IN OUT it started to work.
        TYPE curtype IS REF CURSOR;

        l_stmt               VARCHAR2 (2000);
        CV                   CurType;
        a                    NUMBER;
        l_num_rec            NUMBER;
        record_firm_filter   mrp_bal_utils.seq_alter;
        my_count             NUMBER;
    BEGIN
        DELETE FROM mrp_atp_schedule_temp
              WHERE session_id = p_session_id AND status_flag = -88;


        x_return_status      := 'S';

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                ' entered update_seq ' || p_seq_alter.order_line_id.COUNT);
        END IF;

        FOR j IN 1 .. p_seq_alter.order_line_id.COUNT
        LOOP
            INSERT INTO mrp_atp_schedule_temp (session_id,
                                               inventory_item_id,
                                               scenario_id,
                                               status_flag,
                                               sequence_number,
                                               order_line_id,
                                               quantity_ordered, --old_seq_num,
                                               available_quantity) --sequence_diff)
                     VALUES (p_session_id,
                             -88,
                             -88,
                             -88,
                             p_seq_alter.seq_num (j),
                             p_seq_alter.order_line_id (j),
                             p_seq_alter.orig_seq_num (j),
                             p_seq_alter.seq_diff (j));
        END LOOP;

        l_stmt               := ' SELECT
              sequence_number,
              order_line_id,
              quantity_ordered,          --old_seq_num,
              available_quantity         --sequence_diff
              FROM mrp_atp_schedule_temp
              WHERE status_flag = -88
              AND session_id = ' || p_session_id || 'order by sequence_number';
        a                    := 1;

        SELECT COUNT (*)
          INTO l_num_rec
          FROM mrp_atp_schedule_temp
         WHERE status_flag = -88 AND session_id = p_session_id;

        IF PG_DEBUG IN ('Y', 'C')
        THEN
            msc_sch_wb.atp_debug (
                   ' order_line_id.COUNT is '
                || p_seq_alter.order_line_id.COUNT
                || ' and number of rec in table is '
                || l_num_rec);
        END IF;


        OPEN CV FOR l_stmt;

        LOOP
            EXIT WHEN CV%NOTFOUND;

            FETCH CV INTO p_seq_alter.seq_num (a), p_seq_alter.order_line_id (a), p_seq_alter.orig_seq_num (a), p_seq_alter.seq_diff (a);

            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'IN the new LOOP: and a is  '
                    || a
                    || ' new_seq from chopa_table '
                    || p_seq_alter.seq_num (a)
                    || 'order_line_id   '
                    || p_seq_alter.order_line_id (a)
                    || ' orig_seq_num '
                    || p_seq_alter.orig_seq_num (a)
                    || ' diff '
                    || p_seq_alter.seq_diff (a));
            END IF;


            IF a < l_num_rec
            THEN
                a   := a + 1;
            END IF;
        END LOOP;

        CLOSE CV;

        DELETE FROM mrp_atp_schedule_temp
              WHERE session_id = p_session_id AND status_flag = -88;


        SELECT MAX (sequence_number)
          INTO l_max_seq
          FROM mrp_atp_schedule_temp
         WHERE session_id = p_session_id AND status_flag = 1;

        -- loop through the record to find firmed rows:
        my_count             := 1;

        FOR b IN 1 .. p_seq_alter.order_line_id.COUNT
        LOOP
            IF p_seq_alter.seq_diff (b) = 0
            THEN
                record_firm_filter.order_line_id.EXTEND (1);
                record_firm_filter.seq_num.EXTEND (1);
                record_firm_filter.order_line_id (my_count)   :=
                    p_seq_alter.order_line_id (b);
                record_firm_filter.seq_num (my_count)   :=
                    p_seq_alter.seq_num (b);
                my_count   := my_count + 1;
            END IF;
        END LOOP;

        msc_sch_wb.atp_debug (
            ' record_firm_filter is ' || record_firm_filter.order_line_id.COUNT);

        FOR j IN 1 .. p_seq_alter.order_line_id.COUNT
        LOOP
            IF p_seq_alter.order_line_id (j) IS NOT NULL
            THEN
                SELECT sequence_number, sequence_number + p_seq_alter.seq_diff (j)
                  INTO l_old_seq, l_new_seq
                  FROM mrp_atp_schedule_temp
                 WHERE     order_line_id = p_seq_alter.order_line_id (j)
                       AND session_id = p_session_id
                       AND status_flag = 1;
            ELSE
                SELECT sequence_number, sequence_number + p_seq_alter.seq_diff (j)
                  INTO l_old_seq, l_new_seq
                  FROM mrp_atp_schedule_temp
                 WHERE     NVL (p_seq_alter.ship_set_id (j),
                                p_seq_alter.arrival_set_id (j)) =
                           DECODE (p_seq_alter.ship_set_id (j),
                                   NULL, arrival_set_id,
                                   ship_set_id)
                       AND session_id = p_session_id
                       AND status_flag = 1;
            END IF;

            IF l_new_seq > l_max_seq
            THEN
                l_new_seq   := l_max_seq;
            END IF;

            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                       'update_seq: '
                    || ' old seq '
                    || l_old_seq
                    || ' new_seq '
                    || l_new_seq);
            END IF;



            IF p_seq_alter.seq_diff (j) <> 0
            THEN
                -- skip since there is no change.
                -- Set the changed node to l_new_seq. first decode
                -- where clause
                -- select all affected nodes including the changed node
                -- second decode. depening on the direction of change, update the
                -- affected nodes.
                IF PG_DEBUG IN ('Y', 'C')
                THEN
                    msc_sch_wb.atp_debug ('update_seq: ' || ' b4 update ');
                END IF;

                UPDATE mrp_atp_schedule_temp mast
                   SET mast.sequence_number = p_seq_alter.seq_num (j), last_update_date = SYSDATE, last_updated_by = FND_GLOBAL.USER_ID,
                       last_update_login = FND_GLOBAL.USER_ID
                 WHERE     mast.session_id = p_session_id
                       AND mast.order_line_id = p_seq_alter.order_line_id (j);


                UPDATE mrp_atp_schedule_temp mast
                   SET mast.sequence_number = DECODE (SIGN (p_seq_alter.seq_diff (j)),  -1, mast.sequence_number + 1,  1, mast.sequence_number - 1) -- dsting
                                                                                                                                                   , last_update_date = SYSDATE, last_updated_by = FND_GLOBAL.USER_ID,
                       last_update_login = FND_GLOBAL.USER_ID
                 WHERE     mast.sequence_number BETWEEN DECODE (
                                                            SIGN (
                                                                p_seq_alter.seq_diff (
                                                                    j)),
                                                            -1, p_seq_alter.seq_num (
                                                                    j),
                                                            +1, l_old_seq)
                                                    AND DECODE (
                                                            SIGN (
                                                                p_seq_alter.seq_diff (
                                                                    j)),
                                                            -1, l_old_seq,
                                                            +1, p_seq_alter.seq_num (
                                                                    j))
                       AND mast.session_id = p_session_id
                       AND mast.order_line_id <>
                           p_seq_alter.order_line_id (j);

                FOR b IN 1 .. record_firm_filter.order_line_id.COUNT
                LOOP
                    UPDATE mrp_atp_schedule_temp mast
                       SET mast.sequence_number = record_firm_filter.seq_num (b), last_update_date = SYSDATE, last_updated_by = FND_GLOBAL.USER_ID,
                           last_update_login = FND_GLOBAL.USER_ID
                     WHERE     mast.session_id = p_session_id
                           AND mast.order_line_id =
                               record_firm_filter.order_line_id (b);

                    IF PG_DEBUG IN ('Y', 'C')
                    THEN
                        msc_sch_wb.atp_debug (
                               'IN THE LOOP FOR FIRM: '
                            || '  1 after update '
                            || ' seq num '
                            || record_firm_filter.seq_num (b)
                            || ' line_id  '
                            || record_firm_filter.order_line_id (b)
                            || '  '
                            || SQL%ROWCOUNT);
                    END IF;


                    UPDATE mrp_atp_schedule_temp mast
                       SET mast.sequence_number = DECODE (SIGN (p_seq_alter.seq_diff (j)),  -1, mast.sequence_number + 1,  1, mast.sequence_number - 1)
                     WHERE     mast.sequence_number =
                               record_firm_filter.seq_num (b)
                           AND mast.order_line_id <>
                               record_firm_filter.order_line_id (b)
                           AND mast.session_id = p_session_id;

                    IF PG_DEBUG IN ('Y', 'C')
                    THEN
                        msc_sch_wb.atp_debug (
                               'IN THE LOOP FOR FIRM: '
                            || '  2  after update '
                            || SQL%ROWCOUNT);
                    END IF;
                END LOOP;


                IF PG_DEBUG IN ('Y', 'C')
                THEN
                    msc_sch_wb.atp_debug (
                        'update_seq: ' || ' after update ' || SQL%ROWCOUNT);
                END IF;
            END IF;
        END LOOP;

        COMMIT;

        record_firm_filter   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF PG_DEBUG IN ('Y', 'C')
            THEN
                msc_sch_wb.atp_debug (
                    'Excp in update_seq ' || SUBSTR (SQLERRM, 1, 80));
            END IF;

            x_msg_data        := 'Excp in update_seq ' || SUBSTR (SQLERRM, 1, 80);
            x_return_status   := 'E';
    END update_seq;
END XXD_MSC_BAL_UTILS;
/
