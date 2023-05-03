--
-- XXDO_NEG_ATP_ORD_RESCHED_PKG1  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_NEG_ATP_ORD_RESCHED_PKG1"
AS
    -- ####################################################################################################################
    -- Package      : XXDO_NEG_ATP_ORD_RESCHED_PKG1
    -- Design       : This package will be used to find Negative ATP items and then Identify the
    --                corresponding sales order lines and try to reschedule them.
    --                If unable to reschedule the line, leave the line as is, do not update anything
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver     Description
    -- ----------      --------------      -----   ------------------------------------------------
    -- 29-Aug-2016    Kranthi Bollam       1.0     Initial Version
    --
    -- 01-Dec-2016    Kranthi Bollam       1.1     Created a worker program to run for each Inv Org
    --                                             and Brand to get Sales order lines.This request
    --                                             would identify the eligible SO lines and calls
    --                                             a worker program for Rescheduling.Number of
    --                                             rescheduling requests will be n times of the max
    --                                             number of records per each worker program.
    --                                             At the end call the Audit report per Org and Brand
    --
    -- 19-DEC-2016    Kranthi Bollam       1.2     If unable to sucessfully reschedule, unschedule
    --                                             SO Line (Remove rollback functionality)
    --                                             Remove org parameters(Ship_from_org 2 to 10).
    --                                             Only one inv org is required.
    --                                             Also Added parameter 'Unschedule' to schedule_orders
    --                                             procedure..If Yes,unschedule SO Lines unable to get
    --                                             rescheduled
    --
    -- 27-Dec-2016    Kranthi Bollam       1.3     Brand wise program output has to be emailed to people
    --                                             in lookup "XXD_NEG_ATP_RESCHEDULE_EMAIL"
    --
    -- 05-APR-2017    Infosys              1.4     Code has been modified to include more fields in the
    --                                             report as requested in CCR #CCR0006177.
    --
    -- 29-Jun-17      Infosys              1.5     Code has been fixed to prevent the 'Single row sub-query
    --                                             error', as part of CCR #CCR0006455.
    -- 20-FEB-2018    Infosys              1.6     Code has been modified to include order type column in the
    --                                             report as requested in CCR #CCR0007070
    -- 25-Jul-2018    Viswanathan Pandian  1.7     Modified to add new columns for CCR0007419
    -- 18-DEC-2018    Srinath Siricilla    1.8     Added New parameter to exclude the specific orders data
    --                                             based on parameters CCR0007642
    -- 18-May-2020    Tejaswi Gangumalla   1.9     CCR0008541 Add Item Description to the Auto-Rescheduling report
    -- 21-Aug-2020    Viswanathan Pandian  2.0     Updated for CCR0008937. If bulk, try split and schedule
    -- 18-Feb-2021    Tejaswi Gangumalla   2.1     Added new parameter for batch records and number of child threads
    -- 22-Feb-2021    Jayarajan A K        2.2     Modified for CCR0008870 - Global Inventory Allocation Project
    -- 30-Apr-2021    Jayarajan A K        2.3     Modified get_sort_by_date function to add copy order scenario
    -- 11-Oct-2021    Tejaswi Gangumalla   2.4     Modified for CCR CCR0009641
    -- #####################################################################################################################

    --Global Variables declaration
    gv_package_name      VARCHAR2 (200) := 'XXDO_NEG_ATP_ORD_RESCHED_PKG';
    gn_created_by        NUMBER := apps.fnd_global.user_id;
    gn_last_updated_by   NUMBER := apps.fnd_global.user_id;
    gn_conc_request_id   NUMBER := apps.fnd_global.conc_request_id;
    gn_user_id           NUMBER := apps.fnd_global.user_id;
    gn_resp_appl_id      NUMBER := apps.fnd_global.resp_appl_id;
    gn_resp_id           NUMBER := apps.fnd_global.resp_id;

    /******************************************************************************************/
    --This procedure is used to identify the Negative ATP items and the corresponding sales
    --order lines and inserts them into a staging table for the parameters passed.
    --Also purges the data in the staging tables
    --If there is no ATP plan available in MSC_PLANS,then the program aborts further execution
    /******************************************************************************************/
    PROCEDURE schedule_orders (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_inv_org_id1 IN NUMBER --                             ,pn_inv_org_id2        IN  NUMBER --Commented for change 1.2
                                                                                                  --                             ,pn_inv_org_id3        IN  NUMBER --Commented for change 1.2
                                                                                                  --                             ,pn_inv_org_id4        IN  NUMBER --Commented for change 1.2
                                                                                                  --                             ,pn_inv_org_id5        IN  NUMBER --Commented for change 1.2
                                                                                                  --                             ,pn_inv_org_id6        IN  NUMBER --Commented for change 1.2
                                                                                                  --                             ,pn_inv_org_id7        IN  NUMBER --Commented for change 1.2
                                                                                                  --                             ,pn_inv_org_id8        IN  NUMBER --Commented for change 1.2
                                                                                                  --                             ,pn_inv_org_id9        IN  NUMBER --Commented for change 1.2
                                                                                                  --                             ,pn_inv_org_id10       IN  NUMBER --Commented for change 1.2
                                                                                                  , pv_unschedule IN VARCHAR2, pv_exclude IN VARCHAR2, -- Added for CCR0007642
                                                                                                                                                       pn_customer_id IN NUMBER, pv_request_date_from IN VARCHAR2, pv_request_date_to IN VARCHAR2, pv_brand IN VARCHAR2, pv_style IN VARCHAR2, pv_color IN VARCHAR2, pv_size IN VARCHAR2
                               , pn_retention_days IN NUMBER, pn_batch_records IN NUMBER, --Added for change 2.1
                                                                                          pn_threads IN NUMBER --Added for change 2.1
                                                                                                              )
    AS
        l_pn                      VARCHAR2 (200) := gv_package_name || '.SCHEDULE_ORDERS';
        ln_plan_id                NUMBER := 0;
        lv_plan_date              VARCHAR2 (20);
        lv_status_desc            VARCHAR2 (100);
        lv_error_message          VARCHAR2 (4000);
        ln_batch_id               NUMBER;
        lv_plan_cur               VARCHAR2 (4000);
        lv_inv_org_cur            VARCHAR2 (4000);
        lv_inv_org_dem_cur        VARCHAR2 (1000);
        lv_inv_org_sup_cur        VARCHAR2 (1000);
        lv_neg_atp_items_cur      VARCHAR2 (32000);
        lv_ord_line_cur           VARCHAR2 (32000);
        lv_dblink                 VARCHAR2 (100) := NULL; -- := 'BT_EBS_TO_ASCP.US.ORACLE.COM';
        lv_brand_cond             VARCHAR2 (2000);
        lv_style_cond             VARCHAR2 (500);
        lv_color_cond             VARCHAR2 (500);
        lv_size_cond              VARCHAR2 (500);
        lv_neg_atp_items_grp_by   VARCHAR2 (500);
        lv_neg_atp_items_ord_by   VARCHAR2 (500);
        lv_customer_cond          VARCHAR2 (150);
        lv_exclude_cond           VARCHAR2 (150);
        lv_request_dt_cond        VARCHAR2 (1000);
        lv_brand_cond1            VARCHAR2 (500);
        lv_style_cond1            VARCHAR2 (500);
        lv_color_cond1            VARCHAR2 (500);
        lv_size_cond1             VARCHAR2 (500);
        lv_ord_line_order_by      VARCHAR2 (500);
        lv_org_cond               VARCHAR2 (1000);
        lv_grp_by_cond            VARCHAR2 (100);
        ln_rentention_days        NUMBER;
        ln_cnt                    NUMBER;

        lv_errbuf                 VARCHAR2 (2000);
        lv_retcode                VARCHAR2 (20);
        ln_request_id             NUMBER;

        TYPE inv_org_rec_type IS RECORD
        (
            organization_id    NUMBER
        );

        TYPE inv_org_type IS TABLE OF inv_org_rec_type
            INDEX BY BINARY_INTEGER;

        inv_org_rec               inv_org_type;

        TYPE neg_atp_rec_type IS RECORD
        (
            ebs_item_id          NUMBER,
            organization_id      NUMBER,
            inventory_item_id    NUMBER,
            demand_class         VARCHAR2 (120),
            negativity           NUMBER
        );

        TYPE neg_atp_items_type IS TABLE OF neg_atp_rec_type
            INDEX BY BINARY_INTEGER;

        neg_atp_items_rec         neg_atp_items_type;

        TYPE plan_cur_typ IS REF CURSOR;

        plan_cur                  plan_cur_typ;

        TYPE inv_org_cur_typ IS REF CURSOR;

        inv_org_cur               inv_org_cur_typ;

        TYPE neg_atp_items_cur_typ IS REF CURSOR;

        neg_atp_items_cur         neg_atp_items_cur_typ;
    --      TYPE ord_line_cur_typ IS REF CURSOR;
    --      ord_line_cur ord_line_cur_typ;

    BEGIN
        write_log (
               'Start of the Auto Reschedule program: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        --Start of changes for change 2.4
        --Commenting calling purge_data procedure as it is handled in program Deckers Reschedule of Negative ATP Items Purge Program
        /*write_log ('Calling purge_data procedure');
        ln_rentention_days := NVL (pn_retention_days, 30);
        purge_data (ln_rentention_days);
        write_log (
             'purge_data procedure completed at: '
          || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));*/
        --End of changes for change 2.4
        --Getting the DBlink from EBS to ASCP
        BEGIN
            SELECT a2m_dblink INTO lv_dblink FROM mrp_ap_apps_instances_all;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_dblink   := NULL;
                write_log (
                       'Exception while fetching EBS to ASCP DBLINK. Error is: '
                    || SQLERRM);
                write_log (
                    'Please check A2M_DBLINK column in MRP_AP_APPS_INSTANCES_ALL table');
                write_log ('Exiting the program');
                RETURN;
        END;

        --Getting the Batch ID
        BEGIN
            SELECT xxdo.xxd_neg_atp_resched_batch_id_s.NEXTVAL
              INTO ln_batch_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_batch_id   := 9999999999;
                write_log (
                       'Exception while generating Batch ID from sequence XXDO_NEG_ATP_RESCHED_BATCH_S. Error is: '
                    || SQLERRM);
        END;

        write_log ('Batch ID:' || ln_batch_id);

        --Plan cursor query
        lv_plan_cur          := '
        SELECT mp.plan_id, 
               TO_CHAR(mp.curr_start_date, ''DD-MON-YYYY'') plan_date 
          FROM msc_plans@' || lv_dblink || ' mp
         WHERE 1 = 1
           AND mp.compile_designator = ''ATP''';

        write_log ('-------------------------------------------');
        write_log ('Plan Cursor Query : ');
        write_log ('-------------------------------------------');
        write_log (lv_plan_cur);
        write_log ('-------------------------------------------');

        --Opening the plan cursor
        OPEN plan_cur FOR lv_plan_cur;

        FETCH plan_cur INTO ln_plan_id, lv_plan_date;

        CLOSE plan_cur;

        write_log ('Plan id for ATP Plan : ' || ln_plan_id);
        write_log ('ATP Plan Start date : ' || lv_plan_date);

        --Exit the program if plan id is null
        IF ln_plan_id IS NULL
        THEN
            write_log (
                'There is no ATP plan available in MSC_PLANS. Please check if ATP plan is currently running.');
            write_log ('Exiting the program');
            retcode   := 2;
            RETURN;
        END IF;

        --Start of building Inventory organization cursor query
        lv_inv_org_dem_cur   :=
            '
        SELECT organization_id
		 --Start Changes v2.2
		 ' || --FROM msc_alloc_demands@'
                ' FROM msc_demands@' --End Changes v2.2
                                     || lv_dblink || ' mad  
          WHERE 1 = 1
            AND mad.plan_id = ' || ln_plan_id;

        lv_inv_org_sup_cur   :=
            '
        SELECT mas.organization_id
		 --Start Changes v2.2
		 ' || --FROM msc_alloc_supplies@'
                ' FROM msc_supplies@' --End Changes v2.2
                                      || lv_dblink || ' mas
         WHERE 1 = 1
           AND mas.plan_id = ' || ln_plan_id;

        IF pn_inv_org_id1 IS NOT NULL
        THEN
            lv_org_cond   := ' AND ( organization_id = ' || pn_inv_org_id1;
        END IF;

        --Commented the below conditions for change
        /*
        IF pn_inv_org_id2 IS NOT NULL
        THEN
           lv_org_cond := lv_org_cond||' OR organization_id = '||pn_inv_org_id2;
        END IF;
        IF pn_inv_org_id3 IS NOT NULL
        THEN
           lv_org_cond := lv_org_cond||' OR organization_id = '||pn_inv_org_id3;
        END IF;
        IF pn_inv_org_id4 IS NOT NULL
        THEN
           lv_org_cond := lv_org_cond||' OR organization_id = '||pn_inv_org_id4;
        END IF;
        IF pn_inv_org_id5 IS NOT NULL
        THEN
           lv_org_cond := lv_org_cond||' OR organization_id = '||pn_inv_org_id5;
        END IF;
        IF pn_inv_org_id7 IS NOT NULL
        THEN
           lv_org_cond := lv_org_cond||' OR organization_id = '||pn_inv_org_id7;
        END IF;
        IF pn_inv_org_id8 IS NOT NULL
        THEN
           lv_org_cond := lv_org_cond||' OR organization_id = '||pn_inv_org_id8;
        END IF;
        IF pn_inv_org_id9 IS NOT NULL
        THEN
           lv_org_cond := lv_org_cond||' OR organization_id = '||pn_inv_org_id9;
        END IF;
        IF pn_inv_org_id10 IS NOT NULL
        THEN
           lv_org_cond := lv_org_cond||' OR organization_id = '||pn_inv_org_id10;
        END IF;
        */
        lv_org_cond          := lv_org_cond || ')';
        lv_grp_by_cond       := ' GROUP BY organization_id';

        --Inventory Org Cursor query
        lv_inv_org_cur       :=
               lv_inv_org_dem_cur
            || lv_org_cond
            || lv_grp_by_cond
            || '
        UNION'
            || lv_inv_org_sup_cur
            || lv_org_cond
            || lv_grp_by_cond;

        write_log ('-------------------------------------------');
        write_log ('Inv Org Cursor Query');
        write_log (
            'Timestamp: ' || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        write_log ('-------------------------------------------');
        write_log (lv_inv_org_cur);
        write_log ('-------------------------------------------');

        ----End of building Inventory organization cursor query

        --Opening the inventory org cursor
        OPEN inv_org_cur FOR lv_inv_org_cur;

        FETCH inv_org_cur BULK COLLECT INTO inv_org_rec;

        CLOSE inv_org_cur;

        --If the Inv Org Cursor returns records then only proceed further
        IF inv_org_rec.COUNT > 0
        THEN
            --Looping through the returned inv org data for processing
            FOR i IN inv_org_rec.FIRST .. inv_org_rec.LAST
            LOOP
                --dbms_output.put_line ('Start of processing data for Inv Org ID : '||inv_org_rec(i).organization_id);
                write_log (
                       'Start of processing data for Inv Org ID : '
                    || inv_org_rec (i).organization_id);
                write_log (
                       'Timestamp: '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

                --Start of Building Negative ATP items cursor Query
                lv_neg_atp_items_cur      :=
                       'SELECT msi.sr_inventory_item_id ebs_item_id,
                      msi.organization_id,
                      x.inventory_item_id,
                      x.demand_class demand_class,
                      MIN (poh) negativity
                 FROM (SELECT alloc_date alloc_date,
                              tot_supply supply_qty,
                              tot_demand demand_qty,
                              tot_supply - tot_demand net_qty,
                              SUM (tot_supply - tot_demand) OVER (PARTITION BY inventory_item_id, demand_class ORDER BY inventory_item_id, demand_class, alloc_date) poh,
                              demand_class,
                              inventory_item_id
                         FROM (  SELECT alloc_date alloc_date,
                                        SUM (supply) tot_supply,
                                        SUM (demand) tot_demand,
                                        demand_class,
                                        inventory_item_id
                                   FROM (SELECT --TRUNC (supply_date) alloc_date,     --commented out as part of v2.2
                                                --allocated_quantity supply,          --commented out as part of v2.2
								                TRUNC (new_schedule_date) alloc_date, --added as part of v2.2
                                                new_order_quantity supply,            --added as part of v2.2
                                                0 demand,
                                              --demand_class,         --commented out as part of v2.2
                                                ''-1'' demand_class,  --added as part of v2.2
                                                inventory_item_id
                                         --FROM msc_alloc_supplies@  --commented out as part of v2.2
                                           FROM msc_supplies@'
                    --added as part of v2.2
                    || lv_dblink
                    || '
                                          WHERE organization_id = '
                    || inv_org_rec (i).organization_id
                    || '
                                                AND plan_id = '
                    || ln_plan_id
                    || '
                                         UNION ALL
                                       --SELECT DECODE (SIGN(TRUNC(demand_date) - TRUNC(TO_DATE (''         --commented out as part of v2.2
                                         SELECT DECODE (SIGN(TRUNC(schedule_ship_date) - TRUNC(TO_DATE ('''
                    --added as part of v2.2
                    || lv_plan_date
                    -- || ''',''DD-MON-YYYY''))), 1, TRUNC(demand_date), TRUNC(TO_DATE ('''      --commented out as part of v2.2
                    || ''',''DD-MON-YYYY''))), 1, TRUNC(schedule_ship_date), TRUNC(TO_DATE (''' --added as part of v2.2
                    || lv_plan_date
                    || ''', ''DD-MON-YYYY''))) alloc_date,
                                                0 supply,
                                              --allocated_quantity demand,         --commented out as part of v2.2
                                              --demand_class,                      --commented out as part of v2.2
                                                using_requirement_quantity demand, --added as part of v2.2
                                                ''-1'' demand_class,               --added as part of v2.2
                                                inventory_item_id
                                         --FROM msc_alloc_demands@   --commented out as part of v2.2
                                           FROM msc_demands@'
                    --added as part of v2.2
                    || lv_dblink
                    || '
                                          WHERE plan_id = '
                    || ln_plan_id
                    || '
                                            AND organization_id = '
                    || inv_org_rec (i).organization_id
                    || '
                                            AND schedule_ship_date IS NOT NULL '
                    --added as part v2.2
                    || '
                                        )
                               GROUP BY inventory_item_id, demand_class, alloc_date)) x,
                      msc_system_items@'
                    || lv_dblink
                    || ' msi
                WHERE x.inventory_item_id = msi.inventory_item_id
                  AND msi.plan_id = '
                    || ln_plan_id
                    || '
                  AND msi.organization_id = '
                    || inv_org_rec (i).organization_id;

                lv_neg_atp_items_grp_by   := '
             GROUP BY  x.inventory_item_id, 
                       x.demand_class, 
                       msi.sr_inventory_item_id,
                       msi.organization_id
              HAVING MIN (poh) < 0';

                lv_neg_atp_items_ord_by   := '
              ORDER BY msi.organization_id, 
                       msi.sr_inventory_item_id, 
                       demand_class';

                IF pv_style IS NOT NULL
                THEN
                    lv_style_cond   :=
                           ' AND SUBSTR(msi.item_name, 1, INSTR(msi.item_name, ''-'', 1)-1) = '''
                        || pv_style
                        || '''';
                ELSE
                    lv_style_cond   := ' AND 1=1';
                END IF;

                IF pv_color IS NOT NULL
                THEN
                    lv_color_cond   :=
                           ' AND SUBSTR(msi.item_name, INSTR(msi.item_name, ''-'', 1)+1, INSTR(msi.item_name, ''-'',1, 2)- INSTR(msi.item_name, ''-'', 1)-1) = '''
                        || pv_color
                        || '''';
                ELSE
                    lv_color_cond   := ' AND 1=1';
                END IF;

                IF pv_size IS NOT NULL
                THEN
                    lv_size_cond   :=
                           ' AND SUBSTR(msi.item_name, INSTR(msi.item_name, ''-'', -1)+1) = '''
                        || pv_size
                        || '''';
                ELSE
                    lv_size_cond   := ' AND 1=1';
                END IF;

                lv_neg_atp_items_cur      :=
                       lv_neg_atp_items_cur
                    || lv_style_cond
                    || lv_color_cond
                    || lv_size_cond
                    || lv_neg_atp_items_grp_by
                    || lv_neg_atp_items_ord_by;
                --End of Building Negative ATP items cursor Query

                write_log ('-------------------------------------------');
                write_log ('Negative ATP Items Query: ');
                write_log (
                       'Timestamp: '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
                write_log ('-------------------------------------------');
                write_log (lv_neg_atp_items_cur);
                write_log ('-------------------------------------------');

                --Opening the Neg ATP Items Cursor by Inventory Org
                OPEN neg_atp_items_cur FOR lv_neg_atp_items_cur;

                FETCH neg_atp_items_cur BULK COLLECT INTO neg_atp_items_rec;

                CLOSE neg_atp_items_cur;

                --dbms_output.put_line ('Count of Neg ATP Items for Processing : '|| neg_atp_items_rec.COUNT);
                write_log (
                       'Count of Neg ATP Items for Processing : '
                    || neg_atp_items_rec.COUNT);
                write_log (
                       'Timestamp: '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

                IF neg_atp_items_rec.COUNT > 0
                THEN
                    --write_log('Before Data is inserted into GTT');
                    --Bulk Insert of order lines into table
                    FORALL y
                        IN neg_atp_items_rec.FIRST .. neg_atp_items_rec.LAST
                        INSERT INTO xxdo.xxd_neg_atp_items_tmp (
                                        batch_id,
                                        plan_id,
                                        plan_date,
                                        ebs_item_id,
                                        organization_id,
                                        inventory_item_id,
                                        demand_class,
                                        negativity,
                                        request_id,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by)
                             VALUES (ln_batch_id, ln_plan_id, TRUNC (TO_DATE (lv_plan_date, 'DD-MON-YYYY')), neg_atp_items_rec (y).ebs_item_id, neg_atp_items_rec (y).organization_id, neg_atp_items_rec (y).inventory_item_id, neg_atp_items_rec (y).demand_class, neg_atp_items_rec (y).negativity, gn_conc_request_id, SYSDATE, gn_user_id, SYSDATE
                                     , gn_user_id);

                    COMMIT;

                    --Getting the count of records inserted into Global Temp Table
                    SELECT COUNT (*)
                      INTO ln_cnt
                      FROM xxdo.xxd_neg_atp_items_tmp
                     WHERE batch_id = ln_batch_id;

                    write_log (
                           'Number of records inserted into Neg ATP Items Temp Table:'
                        || ln_cnt);
                    write_log (
                        'Start of getting the order lines for item and organization combination');
                    write_log (
                           'Timestamp: '
                        || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

                    --Submitting the Worker program to get SO lines by brand child program
                    FOR z
                        IN (  SELECT msi.brand
                                FROM xxdo.xxd_neg_atp_items_tmp tmp, apps.xxd_common_items_v msi
                               WHERE     1 = 1
                                     AND tmp.ebs_item_id =
                                         msi.inventory_item_id
                                     AND tmp.organization_id =
                                         msi.organization_id
                                     AND tmp.organization_id =
                                         inv_org_rec (i).organization_id
                                     AND msi.brand = NVL (pv_brand, msi.brand)
                                     AND batch_id = ln_batch_id
                            GROUP BY msi.brand
                            ORDER BY msi.brand)
                    LOOP
                        ln_request_id   :=
                            fnd_request.submit_request (
                                application   => 'XXDO',
                                program       =>
                                    'XXDO_NEG_ATP_ORD_RESCHED_CHILD',
                                description   =>
                                    'Deckers Reschedule Worker Program to get SO Lines',
                                start_time    => SYSDATE,
                                sub_request   => FALSE,
                                argument1     => ln_batch_id,
                                argument2     =>
                                    inv_org_rec (i).organization_id,
                                argument3     => z.brand,
                                argument4     => lv_dblink,
                                argument5     => pn_customer_id,
                                argument6     => pv_request_date_from,
                                argument7     => pv_request_date_to,
                                argument8     => pv_unschedule,
                                argument9     => pv_exclude, -- Added for Change 1.8
                                argument10    => pn_batch_records, -- Added for change 2.1
                                argument11    => pn_threads -- Added for change 2.1
                                                           );
                        COMMIT;

                        IF ln_request_id = 0
                        THEN
                            write_log (
                                   'Concurrent request failed to submit for brand:'
                                || z.brand);
                            write_log (
                                   'Timestamp: '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-RRRR HH24:MI:SS'));
                        ELSE
                            write_log (
                                   'Successfully Submitted the Concurrent Request for brand:'
                                || z.brand
                                || ' and Request Id is '
                                || ln_request_id);
                            write_log (
                                   'Timestamp: '
                                || TO_CHAR (SYSDATE,
                                            'DD-MON-RRRR HH24:MI:SS'));
                        END IF;
                    END LOOP;
                --Neg ATP Items Cursor records Else
                ELSE
                    write_log (
                           'No Negative ATP Items for Inventory Org Id - '
                        || inv_org_rec (i).organization_id);
                END IF;

                --Delete the records that are processed from plsql table
                neg_atp_items_rec.delete;
            END LOOP;
        --Inv org cursor else
        ELSE
            --Just display as message, Do nothing in else case
            write_log (
                'No Inventory Orgs returned for Plan Id - ' || ln_plan_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                   'In when others exception in schedule_orders procedure. Error message is : '
                || SQLERRM);
    END schedule_orders;

    --Procedure to get sales order lines by brand for each item
    PROCEDURE get_so_lines_by_brand (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2, pv_dblink IN VARCHAR2, pn_customer_id IN NUMBER, pv_request_date_from IN VARCHAR2, pv_request_date_to IN VARCHAR2, pv_unschedule IN VARCHAR2, --Added for change 1.2
                                                                                                                                                                                                                                                                                                         pv_exclude IN VARCHAR2, -- Added for Change 1.8
                                                                                                                                                                                                                                                                                                                                 pn_batch_records IN NUMBER
                                     ,                  --Added for change 2.1
                                       pn_threads IN NUMBER --Added for change 2.1
                                                           )
    IS
        --Cursor to get negative ATP items for batch id, inv org and brand
        CURSOR neg_atp_item_cur (cn_batch_id NUMBER, cn_organization_id NUMBER, cv_brand VARCHAR2)
        IS
            SELECT msi.brand, tmp.*
              FROM xxdo.xxd_neg_atp_items_tmp tmp, apps.xxd_common_items_v msi
             WHERE     1 = 1
                   AND tmp.ebs_item_id = msi.inventory_item_id
                   AND tmp.organization_id = msi.organization_id
                   AND tmp.batch_id = cn_batch_id
                   AND tmp.organization_id = cn_organization_id
                   AND msi.brand = cv_brand          --    ORDER BY msi.brand,
                                           --             tmp.inventory_item_id
                                           ;

        --sales order lines by batch id, inv org and brand
        CURSOR so_line_cur (cn_batch_id          NUMBER,
                            cn_organization_id   NUMBER,
                            cv_brand             VARCHAR2)
        IS
            SELECT sotmp.*
              FROM xxdo.xxd_neg_atp_so_line_tmp sotmp
             WHERE     1 = 1
                   AND sotmp.batch_id = cn_batch_id
                   AND sotmp.organization_id = cn_organization_id
                   AND sotmp.brand = cv_brand;

        TYPE ord_line_rec_type IS RECORD
        (
            --customer_name VARCHAR2(240),
            customer_id               NUMBER,
            --order_number NUMBER,
            org_id                    NUMBER,
            --operating_unit VARCHAR2(120),
            ship_from_org_id          NUMBER,
            --ship_from_org VARCHAR2(10),
            --brand VARCHAR2(40),
            --style VARCHAR2(40),
            --color VARCHAR2(40),
            inventory_item_id         NUMBER,
            sku                       VARCHAR2 (50),
            ordered_quantity          NUMBER,
            --demand_qty NUMBER,
            request_date              DATE,
            schedule_ship_date        DATE,
            latest_acceptable_date    DATE,
            cancel_date               VARCHAR2 (30),
            demand_class_code         VARCHAR2 (120),
            line_num                  VARCHAR2 (10),
            line_id                   NUMBER,
            header_id                 NUMBER,
            override_atp_flag         VARCHAR2 (1),
            order_quantity_uom        VARCHAR2 (10),
            brand                     VARCHAR2 (30),    --Added for change 2.4
            batch_id                  NUMBER            --Added for change 2.4
        );

        TYPE ord_line_type IS TABLE OF ord_line_rec_type
            INDEX BY BINARY_INTEGER;

        ord_line_rec           ord_line_type;

        TYPE ord_line_cur_typ IS REF CURSOR;

        ord_line_cur           ord_line_cur_typ;

        TYPE so_line_id_rec_type IS RECORD
        (
            alloc_date             DATE,
            sales_order_line_id    NUMBER,
            supply_qty             NUMBER,
            demand_qty             NUMBER,
            net_qty                NUMBER,
            poh                    NUMBER,
            demand_class           VARCHAR2 (120),
            inventory_item_id      NUMBER
        );

        TYPE so_line_id_type IS TABLE OF so_line_id_rec_type
            INDEX BY BINARY_INTEGER;

        so_line_id_rec         so_line_id_type;

        TYPE so_line_id_cur_type IS REF CURSOR;

        so_line_id_cur         so_line_id_cur_type;

        lv_ord_line_cur        VARCHAR2 (32000);
        lv_so_line_id_cur      VARCHAR2 (5000);
        lv_dblink              VARCHAR2 (100);
        lv_customer_cond       VARCHAR2 (500);
        --      lv_exclude_cond        VARCHAR2 (500);
        lv_request_dt_cond     VARCHAR2 (500);
        lv_ord_line_order_by   VARCHAR2 (500);

        ln_rec_cnt             NUMBER := 0;
        ln_req_cnt             NUMBER := 0;
        ln_from_seq_num        NUMBER := 0;
        ln_to_seq_num          NUMBER := 0;
        -- ln_max_rec_cnt         NUMBER := 5000;--Commented for change 2.1
        ln_max_rec_cnt         NUMBER := pn_batch_records; -- Added for change 2.1
        lv_sku                 VARCHAR2 (50);
        lv_errbuf              VARCHAR2 (2000);
        lv_retcode             VARCHAR2 (2000);
        ln_resched_req_id      NUMBER := 0;
        lv_req_data            VARCHAR2 (20);
        ln_child_req           NUMBER := 0;
        ln_row_count           NUMBER := 0;
        ln_fin_cnt             NUMBER := 0;
    BEGIN
        lv_req_data   := apps.fnd_conc_global.request_data;

        --lv_req_data will be null for first time when parent is scanned by concurrent manager
        IF (lv_req_data IS NULL)
        THEN
            write_log (
                   'Getting Negative ATP Items corresponding SO lines started for brand '
                || pv_brand
                || ' at '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            --write_log('Child Program started at:'||TO_CHAR(SYSDATE,'DD-MON-RRRR HH24:MI:SS'));
            lv_dblink              := pv_dblink;

            FOR neg_atp_item_rec
                IN neg_atp_item_cur (pn_batch_id,
                                     pn_organization_id,
                                     pv_brand)
            LOOP
                --write_log('Inside cursor at:'||TO_CHAR(SYSDATE,'DD-MON-RRRR HH24:MI:SS'));

                lv_so_line_id_cur   :=
                       'SELECT * FROM (
          SELECT alloc_date alloc_date,
                           sales_order_line_id,
                           tot_supply supply_qty,
                           tot_demand demand_qty,
                           tot_supply - tot_demand net_qty,
                           SUM (tot_supply - tot_demand)
                           OVER (PARTITION BY inventory_item_id, demand_class
                                 ORDER BY inventory_item_id, demand_class, alloc_date
                                 )
                              poh,
                           demand_class,
                           inventory_item_id
                      FROM (  SELECT /*+ driving_site(mas) full(mas) */
                                     alloc_date alloc_date,
                                     SUM (supply) tot_supply,
                                     SUM (demand) tot_demand,
                                     demand_class,
                                     inventory_item_id,
                                     sales_order_line_id
                              --FROM (SELECT /*+ driving_site(mas) full(mas) */ TRUNC (supply_date) alloc_date, --commented out as part of v2.2
                              --  FROM (SELECT /*+ driving_site(mas) full(mas) */ TRUNC (new_schedule_date) alloc_date, --commented as part of v2.4
								FROM (SELECT /*+ driving_site(mas) */ TRUNC (new_schedule_date) alloc_date, --added as part of v2.2
                                           --allocated_quantity supply, --commented out as part of v2.2
                                             new_order_quantity supply, --added as part of v2.2
                                             0 demand,
                                           --demand_class,         --commented out as part of v2.2
                                             ''-1'' demand_class,  --added as part of v2.2
                                             inventory_item_id,
                                             NULL sales_order_line_id
                                      --FROM msc_alloc_supplies@ --commented out as part of v2.2
                                        FROM msc_supplies@'
                    --added as part of v2.2
                    || lv_dblink
                    || ' mas
                                       WHERE     1 = 1
                                             AND organization_id = '
                    || neg_atp_item_rec.organization_id
                    || '
                                             AND plan_id = '
                    || neg_atp_item_rec.plan_id
                    --|| '                                                     --commented out as part of v2.2
                    --                                 AND demand_class = '''  --commented out as part of v2.2
                    --|| neg_atp_item_rec.demand_class                         --commented out as part of v2.2
                    || '
                                             AND inventory_item_id = '
                    || neg_atp_item_rec.inventory_item_id
                    || '
                                      UNION ALL
                                     SELECT /*+ driving_site(mad) */  --rmeoevd full(mad) out as part of v2.4
                                             DECODE (
                                                SIGN (
                                                   --TRUNC (demand_date)        --commented out as part of v2.2
                                                     TRUNC (schedule_ship_date) --added as part of v2.2
                                                   - TRUNC (TO_DATE ('''
                    || neg_atp_item_rec.plan_date
                    || ''', ''DD-MON-RR''))),
                                              --1, TRUNC (demand_date),          --commented out as part of v2.2
                                                1, TRUNC (schedule_ship_date),   --added as part of v2.2
                                                TRUNC (TO_DATE ('''
                    || neg_atp_item_rec.plan_date
                    || ''', ''DD-MON-RR'')))
                                                alloc_date,
                                             0 supply,
                                           --allocated_quantity demand,          --commented out as part of v2.2
                                           --demand_class,                       --commented out as part of v2.2
                                             using_requirement_quantity demand,  --added as part of v2.2
                                             ''-1'' demand_class,                --added as part of v2.2
                                             inventory_item_id,
                                             sales_order_line_id
                                      --FROM msc_alloc_demands@  --commented out as part of v2.2
                                        FROM msc_demands@'
                    --added as part of v2.2
                    || lv_dblink
                    || ' mad
                                       WHERE     1 = 1
                                             AND plan_id = '
                    || neg_atp_item_rec.plan_id
                    || '
                                             AND organization_id = '
                    || neg_atp_item_rec.organization_id
                    --|| '                                                     --commented out as part of v2.2
                    --                                 AND demand_class = '''  --commented out as part of v2.2
                    --|| neg_atp_item_rec.demand_class                         --commented out as part of v2.2
                    || '
                                             AND inventory_item_id = '
                    || neg_atp_item_rec.inventory_item_id
                    || '
                                             AND schedule_ship_date IS NOT NULL '
                    --v2.2
                    || '
                                     )
                            GROUP BY inventory_item_id,
                                     demand_class,
                                     alloc_date,
                                     sales_order_line_id)
              ) xx
              WHERE xx.sales_order_line_id IS NOT NULL
                AND xx.poh < 0
                AND xx.demand_qty > 0';

                write_log (lv_so_line_id_cur);

                --Opening Negative ATP Items SO Line ID cursor to get the sales order lines from ASCP
                OPEN so_line_id_cur FOR lv_so_line_id_cur;

                FETCH so_line_id_cur BULK COLLECT INTO so_line_id_rec;

                CLOSE so_line_id_cur;

                --write_log('Inside cursor after opening query at:'||TO_CHAR(SYSDATE,'DD-MON-RRRR HH24:MI:SS'));

                IF so_line_id_rec.COUNT > 0
                THEN
                    --Bulk Insert of order lines into table
                    FORALL i IN so_line_id_rec.FIRST .. so_line_id_rec.LAST
                        INSERT INTO xxdo.xxd_neg_atp_so_line_tmp (
                                        batch_id,
                                        organization_id,
                                        brand,
                                        alloc_date,
                                        sales_order_line_id,
                                        supply_qty,
                                        demand_qty,
                                        net_qty,
                                        poh,
                                        demand_class,
                                        inventory_item_id,
                                        ebs_item_id,
                                        created_by,
                                        creation_date,
                                        last_updated_by,
                                        last_update_date,
                                        request_id)
                             VALUES (neg_atp_item_rec.batch_id, pn_organization_id, pv_brand, so_line_id_rec (i).alloc_date, so_line_id_rec (i).sales_order_line_id, so_line_id_rec (i).supply_qty, so_line_id_rec (i).demand_qty, so_line_id_rec (i).net_qty, so_line_id_rec (i).poh, so_line_id_rec (i).demand_class, so_line_id_rec (i).inventory_item_id, neg_atp_item_rec.ebs_item_id, gn_created_by, SYSDATE, gn_last_updated_by
                                     , SYSDATE, gn_conc_request_id);

                    COMMIT;                                --commit everything
                ELSE
                    --write_log( 'No Order lines returned for the Item - '||neg_atp_items_rec(j).inventory_item_id);
                    write_log (
                           'No Order lines returned for the Item - '
                        || neg_atp_item_rec.ebs_item_id);
                END IF;

                --Delete the records that are processed from plsql table
                so_line_id_rec.delete;
            END LOOP;

            --cursor to pass eac line ID and validate the so line.
            /*FOR so_line_rec
              IN so_line_cur (pn_batch_id, pn_organization_id, pv_brand)
            LOOP*/
            --Commented for change 2.4
            --Make sure there are no reservations and also released status is  not Shipped, Staged/Pick Confirmed, Cancelled or Released to Warehouse
            lv_ord_line_cur        :=
                   '
                    SELECT 
                           oola.sold_to_org_id customer_id,
                           oola.org_id,
                           oola.ship_from_org_id,
                           oola.inventory_item_id,
                           oola.ordered_item sku,
                           oola.ordered_quantity,
                           oola.request_date,
                           oola.schedule_ship_date,
                           oola.latest_acceptable_date,
                           oola.attribute1 cancel_date,
                           oola.demand_class_code,
                           oola.line_number||''.''||oola.shipment_number line_num,
                           oola.line_id,
                           oola.header_id,
                           oola.override_atp_date_code override_atp_flag,
                           oola.order_quantity_uom,
                           stg.brand, --Added for change 2.4
                           stg.batch_id -- Added for change 2.4
                      FROM
                           apps.oe_order_lines_all oola,
                           xxdo.xxd_neg_atp_so_line_tmp stg
                    WHERE 1=1'
                || --AND oola.line_id = '
                   --|| so_line_rec.sales_order_line_id
                   --|| '*/ --Commented for change 2.4
                   ' AND stg.batch_id= '
                || pn_batch_id
                ||                                      --Added for change 2.4
                   ' AND stg.organization_id= '
                || pn_organization_id
                ||                                      --Added for change 2.4
                   ' AND stg.brand = '
                || ''''
                || pv_brand
                || ''''
                ||                                      --Added for change 2.4
                   ' AND oola.line_id=stg.sales_order_line_id'
                ||                                      --Added for change 2.4
                   ' AND NVL(oola.open_flag,''N'') = ''Y''
                      AND oola.flow_status_code <> ''ENTERED''
                      AND oola.line_category_code = ''ORDER''
                      AND NOT EXISTS (SELECT ''1''
                                        FROM wsh_delivery_details wdd
                                       WHERE wdd.source_line_id = oola.line_id
                                         AND wdd.source_code = ''OE''
                                         AND wdd.released_status IN (''C'', ''Y'', ''D'', ''S'') --C=Shipped, Y=Staged/Pick Confirmed, D=Cancelled, S=Released to Warehouse 
                                     )
                      AND NOT EXISTS (SELECT ''1''
                                        FROM apps.mtl_reservations
                                       WHERE 1 = 1
                                         AND demand_source_line_id = oola.line_id
                                     )
            ';

            --write_log('Inside cursor after lv_or_line cur at:'||TO_CHAR(SYSDATE,'DD-MON-RRRR HH24:MI:SS'));

            IF pn_customer_id IS NOT NULL
            THEN
                lv_customer_cond   :=
                    ' AND oola.sold_to_org_id = ' || pn_customer_id;
            ELSE
                lv_customer_cond   := ' AND 1=1';
            END IF;

            --Added for change 1.8 --START
            --            IF pv_exclude IS NOT NULL AND pv_exclude = 'NONE'
            --            THEN
            --               lv_exclude_cond := ' AND 1=1';
            --            ELSIF pv_exclude IS NOT NULL AND pv_exclude = 'ALL_LINES_WITH_ATP_OVERRIDE'
            --            THEN
            --               lv_exclude_cond := ' AND NVL(oola.override_atp_date_code, ''N'') <> ''Y''';
            --            ELSIF pv_exclude IS NOT NULL AND pv_exclude = 'ALL_ISO'
            --            THEN
            --               lv_exclude_cond := ' AND oola.order_source_id <> 10 ';
            --            ELSIF pv_exclude IS NOT NULL AND pv_exclude = 'ISO_WITH_OVERRIDE_ATP'
            --            THEN
            --               lv_exclude_cond := ' AND (oola.order_source_id <> 10 AND NVL(oola.override_atp_date_code, ''N'') <> ''Y'')';
            --            END IF;
            --Added for change 1.8 --END

            --write_log('Inside cursor after customer ID condition at:'||TO_CHAR(SYSDATE,'DD-MON-RRRR HH24:MI:SS'));
            IF (pv_request_date_from IS NOT NULL OR pv_request_date_to IS NOT NULL)
            THEN
                lv_request_dt_cond   :=
                       ' AND TRUNC(oola.request_date) BETWEEN TRUNC(TO_DATE('''
                    || pv_request_date_from
                    || ''',''RRRR/MM/DD HH24:MI:SS'')) 
                                                                       AND TRUNC(TO_DATE('''
                    || pv_request_date_to
                    || ''',''RRRR/MM/DD HH24:MI:SS''))';
            ELSE
                lv_request_dt_cond   := ' AND 1=1';
            END IF;



            lv_ord_line_order_by   :=
                ' ORDER BY oola.request_date, oola.schedule_ship_date';
            --write_log('Inside cursor before final query at:'||TO_CHAR(SYSDATE,'DD-MON-RRRR HH24:MI:SS'));
            lv_ord_line_cur        :=
                   lv_ord_line_cur
                || lv_customer_cond --               || lv_exclude_cond  --Added for change 1.8
                || lv_request_dt_cond
                ||                                          --lv_brand_cond1||
                   --lv_style_cond1||
                   --lv_color_cond1||
                   --lv_size_cond1||
                   lv_ord_line_order_by;

            --Start of building the query to get sales order lines for the negative ATP items
            --write_log( '-------------------------------------------');
            --write_log( 'Order Lines Cursor Query: ');
            --write_log( 'Timestamp: '||TO_CHAR(SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            --write_log( '-------------------------------------------');
            --write_log( lv_ord_line_cur);
            --write_log( '-------------------------------------------');

            --write_log('Inside cursor before opening query at:'||TO_CHAR(SYSDATE,'DD-MON-RRRR HH24:MI:SS'));

            --Opening Order lines cursor for the neg ATP Items
            OPEN ord_line_cur FOR lv_ord_line_cur;

            FETCH ord_line_cur BULK COLLECT INTO ord_line_rec;

            CLOSE ord_line_cur;

            --write_log('Inside cursor after opening query at:'||TO_CHAR(SYSDATE,'DD-MON-RRRR HH24:MI:SS'));

            IF ord_line_rec.COUNT > 0
            THEN
                --Bulk Insert of order lines into table
                FORALL x IN ord_line_rec.FIRST .. ord_line_rec.LAST
                    INSERT INTO xxdo.xxd_neg_atp_items_resched_stg (
                                    batch_id,
                                    org_id,
                                    --operating_unit,
                                    ship_from_org_id,
                                    --ship_from_org,
                                    brand,
                                    --style,
                                    --color,
                                    sku,
                                    inventory_item_id,
                                    --order_number,
                                    --customer_name,
                                    customer_id,
                                    header_id,
                                    line_id,
                                    line_num,
                                    demand_class_code,
                                    ordered_quantity,
                                    request_date,
                                    schedule_ship_date,
                                    latest_acceptable_date,
                                    override_atp_flag,
                                    cancel_date,
                                    status,
                                    error_message,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    sort_by_date, --added as part of v2.2 changes
                                    request_id)
                         VALUES (--so_line_rec.batch_id,--Commented for change 2.4
                                 ord_line_rec (x).batch_id, --Added for change 2.4
                                                            ord_line_rec (x).org_id, --ord_line_rec(x).operating_unit,
                                                                                     ord_line_rec (x).ship_from_org_id, --ord_line_rec(x).ship_from_org,
                                                                                                                        --ord_line_rec(x).brand,
                                                                                                                        -- so_line_rec.brand, --Commented for 2.4
                                                                                                                        ord_line_rec (x).brand, --Added for change 2.4
                                                                                                                                                --ord_line_rec(x).style,
                                                                                                                                                --ord_line_rec(x).color,
                                                                                                                                                ord_line_rec (x).sku, ord_line_rec (x).inventory_item_id, --ord_line_rec(x).order_number,
                                                                                                                                                                                                          --ord_line_rec(x).customer_name,
                                                                                                                                                                                                          ord_line_rec (x).customer_id, ord_line_rec (x).header_id, ord_line_rec (x).line_id, ord_line_rec (x).line_num, ord_line_rec (x).demand_class_code, ord_line_rec (x).ordered_quantity, ord_line_rec (x).request_date, ord_line_rec (x).schedule_ship_date, ord_line_rec (x).latest_acceptable_date, ord_line_rec (x).override_atp_flag, fnd_date.canonical_to_date (ord_line_rec (x).cancel_date), 'N', --status,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 NULL, --error_message,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       gn_created_by, SYSDATE, gn_last_updated_by, SYSDATE, get_sort_by_date (ord_line_rec (x).line_id)
                                 ,             --added as part of v2.2 changes
                                   gn_conc_request_id);

                COMMIT;                                    --commit everything
            ELSE
                --write_log( 'No Order lines returned for the Item - '||neg_atp_items_rec(j).inventory_item_id);
                write_log (
                       'No Order lines returned for the batch - '
                    || pn_batch_id
                    || ',organization - '
                    || pn_organization_id
                    || ', brand - '
                    || pv_brand);
            END IF;

            --Delete the records that are processed from plsql table
            ord_line_rec.delete;
            -- END LOOP; --Commentd for change 2.4

            --New code changes on 09Dec2016 --START
            write_log (
                   'Approx. number of records to be processed per each reschedule worker program: '
                || ln_max_rec_cnt);

            ln_fin_cnt             := 0;
            ln_row_count           := 0;

            --Cursor to assign rownum after sorting the records by SKU, Request Date and Schedule Ship Date
            --And updating the rownum as seq_no field in xxd_neg_atp_items_resched_stg staging table
            FOR r1
                IN (SELECT ROWNUM rn, xx.*
                      FROM (  SELECT stg.*
                                FROM xxdo.xxd_neg_atp_items_resched_stg stg
                               WHERE     batch_id = pn_batch_id
                                     AND ship_from_org_id = pn_organization_id
                                     AND brand = pv_brand
                                     AND status = 'N'
                            --ORDER BY sku, request_date, schedule_ship_date) xx) --commented out as part of v2.2 changes
                            ORDER BY sku, sort_by_date DESC, request_date,
                                     schedule_ship_date) xx) --added as part of v2.2 changes
            LOOP
                UPDATE xxdo.xxd_neg_atp_items_resched_stg
                   SET seq_no   = r1.rn
                 WHERE     line_id = r1.line_id
                       AND ship_from_org_id = r1.ship_from_org_id
                       --AND org_id = r1.org_id
                       AND batch_id = r1.batch_id
                       AND brand = r1.brand
                       AND status = 'N';

                ln_row_count   := SQL%ROWCOUNT;            --w.r.t version 2.4
                ln_fin_cnt     := ln_row_count + ln_fin_cnt; --w.r.t version 2.4

                IF MOD (ln_fin_cnt, 1000) = 0
                THEN
                    COMMIT;
                END IF;
            END LOOP;

            COMMIT;

            --Getting the total records count
            SELECT COUNT (*)
              INTO ln_rec_cnt
              FROM xxdo.xxd_neg_atp_items_resched_stg
             WHERE     seq_no IS NOT NULL
                   AND ship_from_org_id = pn_organization_id
                   AND batch_id = pn_batch_id
                   AND brand = pv_brand
                   AND status = 'N';

            --Calculating the number of rescheduling child/worker requests to be submitted
            ln_req_cnt             := CEIL (ln_rec_cnt / ln_max_rec_cnt);
            write_log (
                'Total number of records for processing: ' || ln_rec_cnt);
            write_log (
                   'Number of Rescheduling Child/Worker requests to be submitted: '
                || ln_req_cnt);

            --Looping through the number of requests to be submitted
            /* Start of change 2.1 */
            FOR i IN 1 .. ln_req_cnt
            LOOP
                LOOP
                    SELECT COUNT (*)
                      INTO ln_child_req
                      FROM fnd_concurrent_programs fcp, fnd_concurrent_requests fc
                     WHERE     fcp.concurrent_program_name =
                               'XXD_NEG_ATP_ITEM_RESCHED_PRC'
                           AND fc.concurrent_program_id =
                               fcp.concurrent_program_id
                           AND fc.parent_request_id =
                               fnd_global.conc_request_id
                           AND fc.phase_code IN ('R', 'P');

                    IF ln_child_req >= pn_threads
                    THEN
                        DBMS_LOCK.Sleep (30);
                    ELSE
                        EXIT;
                    END IF;
                END LOOP;

                /* End of change 2.1 */

                ln_from_seq_num   := ln_to_seq_num + 1;
                write_log ('From Sequence Number: ' || ln_from_seq_num);
                lv_sku            := NULL;

                --Getting the SKU occurring at each ln_max_rec_cnt.
                --This is to make sure that the SKU is not split across the rescheduling child/worker requests
                BEGIN
                      SELECT sku
                        INTO lv_sku
                        FROM xxdo.xxd_neg_atp_items_resched_stg stg
                       WHERE     batch_id = pn_batch_id
                             AND brand = pv_brand
                             AND ship_from_org_id = pn_organization_id
                             AND seq_no = (ln_to_seq_num + ln_max_rec_cnt) --(i * ln_max_rec_cnt)-- Changed for 2.1
                    ORDER BY stg.seq_no;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_sku   := NULL;
                END;

                IF lv_sku IS NOT NULL
                THEN
                      --Get the max seq number of the item so that the item is not split across the rescheduling requests
                      SELECT MAX (stg.seq_no)
                        INTO ln_to_seq_num
                        FROM xxdo.xxd_neg_atp_items_resched_stg stg
                       WHERE     batch_id = pn_batch_id
                             AND brand = pv_brand
                             AND ship_from_org_id = pn_organization_id
                             AND sku = lv_sku
                    ORDER BY stg.seq_no;
                ELSE
                    --Assigning the last record count to ln_to_seq_num for the last child request
                    ln_to_seq_num   := ln_rec_cnt;
                END IF;

                write_log ('To Sequence Number: ' || ln_to_seq_num);
                --submit the concurrent program to reschedule order lines by brand
                --by spawining the request for every ln_max_rec_cnt
                ln_resched_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXD_NEG_ATP_ITEM_RESCHED_PRC',
                        description   => 'Deckers Rescheduling Worker Program',
                        start_time    => SYSDATE,
                        sub_request   => FALSE, --TRUE, --This program will be submitted as a Child request
                        argument1     => pn_batch_id,
                        argument2     => pn_organization_id,
                        argument3     => pv_brand,
                        argument4     => ln_from_seq_num,
                        argument5     => ln_to_seq_num,
                        argument6     => pv_unschedule,
                        argument7     => pv_exclude    -- Added for Change 1.8
                                                   );
                COMMIT;

                IF ln_resched_req_id = 0
                THEN
                    write_log (
                           'Rescheduling concurrent request failed to submit for seq number from: '
                        || ln_from_seq_num
                        || ' to: '
                        || ln_to_seq_num);
                    write_log (
                           'Timestamp: '
                        || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
                ELSE
                    write_log (
                           'Successfully Submitted the Rescheduling Concurrent Request for seq number from: '
                        || ln_from_seq_num
                        || ' to: '
                        || ln_to_seq_num
                        || ' and Request Id is '
                        || ln_resched_req_id);
                    write_log (
                           'Timestamp: '
                        || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
                END IF;

                EXIT WHEN ln_to_seq_num >= ln_rec_cnt;
            END LOOP;
        --New code changes on 09Dec2016 --END

        --If there are any requests to be submitted then PAUSE the parent request until child requests are completed.
        --Until unless the parent request is 'PAUSED', child requests will not run
        /*  IF ln_req_cnt > 0
          THEN
            apps.fnd_conc_global.set_req_globals (conc_status    => 'PAUSED', --Parent request will be paused until all the child requests are completed
                                                  request_data   => '1' --TO_CHAR (ln_request_id)
                                                                       );
          END IF;*/
        END IF;                                 --lv_req_data IF condition END

        LOOP
            SELECT COUNT (*)
              INTO ln_child_req
              FROM fnd_concurrent_programs fcp, fnd_concurrent_requests fc
             WHERE     fcp.concurrent_program_name =
                       'XXD_NEG_ATP_ITEM_RESCHED_PRC'
                   AND fc.concurrent_program_id = fcp.concurrent_program_id
                   AND fc.parent_request_id = fnd_global.conc_request_id
                   AND fc.phase_code IN ('R', 'P');

            IF ln_child_req <> 0                          -- added as part 2.4
            THEN
                DBMS_LOCK.Sleep (30);
            ELSE
                EXIT;
            END IF;
        --  EXIT WHEN ln_child_req=0;  -- commented as part 2.4
        END LOOP;

        --Resuming the parent request after all the child requests are completed and continuing with the next steps
        /*IF lv_req_data IS NOT NULL
        THEN*/
        write_log (
               'Calling Audit Report Procedure at '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        --Calling the audit report
        audit_report (pn_batch_id, pn_organization_id, pv_brand --pn_from_seq_num,
                                                               --pn_to_seq_num
                                                               );
        write_log (
               'Audit Report Procedure completed at '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        --Added the below email_output call for change 1.3
        --Calling the emailing program
        write_log (
               'Calling Emailing Procedure at '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        email_output (pn_batch_id, pn_organization_id, pv_brand);
        write_log (
               'Emailing Procedure completed at '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
    --END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                   'Exception in get_so_lines_by_brand procedure(Auto Rescheduling child Request) is :'
                || SQLERRM);
    END;

    -- Start changes for 2.0
    -- ======================================================================================
    -- This procedure calls MRP_ATP_PUB to evaluate available SKU quantity
    -- ======================================================================================
    PROCEDURE get_atp_qty (p_line_id IN NUMBER, x_atp_current_available_qty OUT NOCOPY NUMBER, x_return_status OUT NOCOPY VARCHAR2
                           , x_error_message OUT NOCOPY VARCHAR2)
    AS
        lx_atp_rec            mrp_atp_pub.atp_rec_typ;
        l_atp_supply_demand   mrp_atp_pub.atp_supply_demand_typ;
        l_atp_period          mrp_atp_pub.atp_period_typ;
        l_atp_details         mrp_atp_pub.atp_details_typ;
        lc_msg_data           VARCHAR2 (2000);
        lc_msg_dummy          VARCHAR2 (2000);
        lc_return_status      VARCHAR2 (2000);
        ln_msg_index_out      NUMBER;
        ln_session_id         NUMBER;
        ln_msg_count          NUMBER;
        l_line_rec            oe_order_pub.line_rec_type;
        l_atp_rec             mrp_atp_pub.atp_rec_typ;
    BEGIN
        l_line_rec                               := oe_order_pub.get_g_miss_line_rec;
        -- Query Current Order Line
        oe_line_util.query_row (p_line_id    => p_line_id,
                                x_line_rec   => l_line_rec);

        -- ATP Rec
        msc_atp_global.extend_atp (l_atp_rec, lc_return_status, 1);
        l_atp_rec.inventory_item_id (1)          := l_line_rec.inventory_item_id;
        l_atp_rec.quantity_ordered (1)           := l_line_rec.ordered_quantity;
        l_atp_rec.quantity_uom (1)               := l_line_rec.order_quantity_uom;
        -- Pass LAD to Request Date to cover future supplies
        l_atp_rec.requested_ship_date (1)        :=
            l_line_rec.latest_acceptable_date;
        l_atp_rec.latest_acceptable_date (1)     :=
            l_line_rec.latest_acceptable_date;
        l_atp_rec.source_organization_id (1)     := l_line_rec.ship_from_org_id;
        l_atp_rec.demand_class (1)               :=
            l_line_rec.demand_class_code;
        -- Set additional input values
        l_atp_rec.action (1)                     := 100;
        l_atp_rec.instance_id (1)                := 61;
        l_atp_rec.oe_flag (1)                    := 'N';
        l_atp_rec.insert_flag (1)                := 1;
        -- Hardcoded value for profile MRP:Calculate Supply Demand 0= NO
        l_atp_rec.attribute_04 (1)               := 1;
        -- With this Attribute set to 1 this will enable the Period (Horizontal Plan),
        l_atp_rec.customer_id (1)                := NULL;
        l_atp_rec.customer_site_id (1)           := NULL;
        l_atp_rec.calling_module (1)             := NULL;
        l_atp_rec.row_id (1)                     := NULL;
        l_atp_rec.source_organization_code (1)   := NULL;
        l_atp_rec.organization_id (1)            := NULL;
        l_atp_rec.order_number (1)               := NULL;
        l_atp_rec.line_number (1)                := NULL;
        l_atp_rec.override_flag (1)              := 'N';
        write_log ('Item ID=' || l_line_rec.inventory_item_id);
        write_log (
               'Checking ATP for Qty '
            || l_line_rec.ordered_quantity
            || ' with Demand Class Code as '
            || l_line_rec.demand_class_code);

        SELECT oe_order_sch_util.get_session_id INTO ln_session_id FROM DUAL;

        mrp_atp_pub.call_atp (p_session_id          => ln_session_id,
                              p_atp_rec             => l_atp_rec,
                              x_atp_rec             => lx_atp_rec,
                              x_atp_supply_demand   => l_atp_supply_demand,
                              x_atp_period          => l_atp_period,
                              x_atp_details         => l_atp_details,
                              x_return_status       => x_return_status,
                              x_msg_data            => lc_msg_data,
                              x_msg_count           => ln_msg_count);
        write_log ('ATP API Status = ' || x_return_status);

        /*IF x_return_status = 'S'
        THEN
          FOR i IN 1 .. lx_atp_rec.inventory_item_id.COUNT
          LOOP
            x_error_message := '';

            IF (lx_atp_rec.ERROR_CODE (i) <> 0)
            THEN
              SELECT meaning
                INTO x_error_message
                FROM mfg_lookups
               WHERE     lookup_type = 'MTL_DEMAND_INTERFACE_ERRORS'
                     AND lookup_code = lx_atp_rec.ERROR_CODE (i);

              x_return_status := 'E';
              lx_atp_rec.available_quantity (i) := 0;
              write_log ('ATP API Error = ' || x_error_message);
            END IF;
          END LOOP;
        ELSE
          FOR i IN 1 .. ln_msg_count
          LOOP
            fnd_msg_pub.get (i,
                             fnd_api.g_false,
                             lc_msg_data,
                             lc_msg_dummy);
            x_error_message := (TO_CHAR (i) || ': ' || lc_msg_data);
          END LOOP;

          write_log ('ATP API Error = ' || x_error_message);
        END IF;*/

        IF NVL (lx_atp_rec.requested_date_quantity (1), 0) > 0
        THEN
            x_atp_current_available_qty   :=
                NVL (lx_atp_rec.requested_date_quantity (1), 0);
            x_return_status   := 'S';
            x_error_message   := NULL;
        ELSE
            x_return_status   := 'E';
            x_error_message   :=
                'Requested Qty is either 0 or unable to derive';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_atp_current_available_qty   := 0;
            write_log ('Others Exception in GET_ATP_QTY = ' || SQLERRM);
            x_return_status               := 'E';
            x_error_message               := SUBSTR (SQLERRM, 1, 2000);
    END get_atp_qty;

    -- End changes for 2.0

    /************************************************************************************************/
    --This procedure takes batch_id, Inv Org, Brand, seq num from and seq num to as input parameters
    -- and picks up all the order lines for these parameters
    --and tries to reschedule them using OE_ORDER_PUB.process_order API
    /************************************************************************************************/
    PROCEDURE reschedule_api_call (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2, pn_from_seq_num IN NUMBER
                                   , pn_to_seq_num IN NUMBER, pv_unschedule IN VARCHAR2, --Added for change 1.2
                                                                                         pv_exclude IN VARCHAR2 -- Added for Change 1.8
                                                                                                               )
    IS
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_header_rec_x                 oe_order_pub.header_rec_type;
        l_line_tbl_x                   oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        l_request_rec                  oe_order_pub.request_rec_type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        lv_so_line_cur                 VARCHAR2 (32000);
        lv_so_line_act_cur             VARCHAR2 (32000);
        -- Start of Change for 1.8
        lv_exclude_cond                VARCHAR2 (500);
        ln_exclude_org                 NUMBER;
        ln_exclude_OU                  NUMBER;
        ln_exclude_brand               NUMBER;
        ln_exclude_div                 NUMBER;
        ln_exclude_dept                NUMBER;
        ln_exclude_cust                NUMBER;
        ln_exclude_ord_type            NUMBER;
        ln_exclude_sales_chnl          NUMBER;
        ln_exclude_dem_class           NUMBER;
        ln_exclude_req_from_dt         NUMBER;
        ln_exclude_req_to_dt           NUMBER;
        lv_exclude_org                 VARCHAR2 (4000);
        lv_exclude_OU                  VARCHAR2 (4000);
        lv_exclude_brand               VARCHAR2 (4000);
        lv_exclude_div                 VARCHAR2 (4000);
        lv_exclude_dept                VARCHAR2 (4000);
        lv_exclude_cust                VARCHAR2 (4000);
        lv_exclude_ord_type            VARCHAR2 (4000);
        lv_exclude_sales_chnl          VARCHAR2 (4000);
        lv_exclude_dem_class           VARCHAR2 (4000);
        lv_exclude_req_dt              VARCHAR2 (5000);
        -- End of change for 1.8
        -- Start changes for 2.0
        ln_bulk_split_success          NUMBER := 0;
        ln_bulk_split_err              NUMBER := 0;
        ln_atp_current_available_qty   NUMBER := 0;
        ln_new_line_split_qty          NUMBER := 0;
        lc_atp_return_status           VARCHAR2 (1);
        lc_atp_error_message           VARCHAR2 (4000);
        -- End changes for 2.0
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := fnd_api.g_false;
        p_return_values                VARCHAR2 (10) := fnd_api.g_false;
        p_action_commit                VARCHAR2 (10) := fnd_api.g_false;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_old_header_rec               oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        p_header_val_rec               oe_order_pub.header_val_rec_type
            := oe_order_pub.g_miss_header_val_rec;
        p_old_header_val_rec           oe_order_pub.header_val_rec_type
            := oe_order_pub.g_miss_header_val_rec;
        p_header_adj_tbl               oe_order_pub.header_adj_tbl_type
            := oe_order_pub.g_miss_header_adj_tbl;
        p_old_header_adj_tbl           oe_order_pub.header_adj_tbl_type
            := oe_order_pub.g_miss_header_adj_tbl;
        p_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type
            := oe_order_pub.g_miss_header_adj_val_tbl;
        p_old_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type
            := oe_order_pub.g_miss_header_adj_val_tbl;
        p_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_old_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type
            := oe_order_pub.g_miss_header_price_att_tbl;
        p_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_old_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type
            := oe_order_pub.g_miss_header_adj_att_tbl;
        p_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_old_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type
            := oe_order_pub.g_miss_header_adj_assoc_tbl;
        p_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_old_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type
            := oe_order_pub.g_miss_header_scredit_tbl;
        p_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_old_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type
            := oe_order_pub.g_miss_header_scredit_val_tbl;
        p_line_tbl                     oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_old_line_tbl                 oe_order_pub.line_tbl_type
                                           := oe_order_pub.g_miss_line_tbl;
        p_line_val_tbl                 oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_old_line_val_tbl             oe_order_pub.line_val_tbl_type
            := oe_order_pub.g_miss_line_val_tbl;
        p_line_adj_tbl                 oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_old_line_adj_tbl             oe_order_pub.line_adj_tbl_type
            := oe_order_pub.g_miss_line_adj_tbl;
        p_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_old_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type
            := oe_order_pub.g_miss_line_adj_val_tbl;
        p_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_old_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type
            := oe_order_pub.g_miss_line_price_att_tbl;
        p_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_old_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type
            := oe_order_pub.g_miss_line_adj_att_tbl;
        p_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_old_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type
            := oe_order_pub.g_miss_line_adj_assoc_tbl;
        p_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_old_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type
            := oe_order_pub.g_miss_line_scredit_tbl;
        p_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_old_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type
            := oe_order_pub.g_miss_line_scredit_val_tbl;
        p_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_old_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type
            := oe_order_pub.g_miss_lot_serial_tbl;
        p_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_old_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type
            := oe_order_pub.g_miss_lot_serial_val_tbl;
        p_action_request_tbl           oe_order_pub.request_tbl_type
                                           := oe_order_pub.g_miss_request_tbl;
        x_header_val_rec               oe_order_pub.header_val_rec_type;
        x_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl           oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl         oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl           oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl         oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl           oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl       oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl                 oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl             oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl           oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl             oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl           oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl             oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl         oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl               oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl           oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl           oe_order_pub.request_tbl_type;
        x_debug_file                   VARCHAR2 (100);
        l_line_tbl_index               NUMBER;
        l_msg_index_out                NUMBER (10);
        x_errbuf                       VARCHAR2 (200);
        x_retcode                      VARCHAR2 (200);
        l_row_num                      NUMBER := 0;
        l_row_num_err                  NUMBER := 0;
        l_message_data                 VARCHAR2 (2000);
        ln_resp_id                     NUMBER := 0;
        ln_resp_appl_id                NUMBER := 0;
        ln_conc_request_id             NUMBER
                                           := apps.fnd_global.conc_request_id;
        l_unsched_row_num              NUMBER := 0;     --Added for change 1.2
        l_unsched_row_num_err          NUMBER := 0;     --Added for change 1.2

        --Added for Change 1.8 --START
        TYPE so_line_rec_type
            IS RECORD
        (
            batch_id                  xxd_neg_atp_items_resched_stg.batch_id%TYPE,
            org_id                    xxd_neg_atp_items_resched_stg.org_id%TYPE,
            ship_from_org_id          xxd_neg_atp_items_resched_stg.ship_from_org_id%TYPE,
            brand                     xxd_neg_atp_items_resched_stg.brand%TYPE,
            sku                       xxd_neg_atp_items_resched_stg.sku%TYPE,
            inventory_item_id         xxd_neg_atp_items_resched_stg.inventory_item_id%TYPE,
            Customer_id               xxd_neg_atp_items_resched_stg.Customer_id%TYPE,
            header_id                 xxd_neg_atp_items_resched_stg.header_id%TYPE,
            line_id                   xxd_neg_atp_items_resched_stg.line_id%TYPE,
            demand_class_code         xxd_neg_atp_items_resched_stg.demand_class_code%TYPE,
            schedule_ship_date        xxd_neg_atp_items_resched_stg.schedule_ship_date%TYPE,
            new_schedule_ship_date    xxd_neg_atp_items_resched_stg.new_schedule_ship_date%TYPE,
            request_date              xxd_neg_atp_items_resched_stg.request_date%TYPE,
            override_atp_flag         xxd_neg_atp_items_resched_stg.override_atp_flag%TYPE,
            style_number              xxd_common_items_v.style_number%TYPE,
            color_code                xxd_common_items_v.color_code%TYPE,
            division                  xxd_common_items_v.division%TYPE,
            department                xxd_common_items_v.department%TYPE,
            order_source_id           oe_order_headers_all.order_source_id%TYPE,
            -- Start changes for 2.0
            ordered_quantity          xxd_neg_atp_items_resched_stg.ordered_quantity%TYPE,
            bulk_order_flag           VARCHAR2 (10)
        -- End changes for 2.0
        );

        TYPE so_line_type IS TABLE OF so_line_rec_type
            INDEX BY BINARY_INTEGER;

        so_line_rec                    so_line_type;

        TYPE so_line_typ IS REF CURSOR;

        so_line_cur                    so_line_typ;

        --Added for Change 1.8 --END

        --Cursor to identify unique operating units
        CURSOR inv_org_ou_cur (cn_batch_id IN NUMBER, cn_organization_id IN NUMBER, cv_brand IN VARCHAR2)
        IS
              SELECT stg.org_id, stg.ship_from_org_id
                FROM xxdo.xxd_neg_atp_items_resched_stg stg
               WHERE     1 = 1
                     AND stg.batch_id = cn_batch_id
                     AND stg.ship_from_org_id = cn_organization_id
                     AND stg.brand = cv_brand
                     AND stg.status = 'N'                        --NEW records
                     AND stg.seq_no BETWEEN pn_from_seq_num AND pn_to_seq_num
            GROUP BY stg.org_id, stg.ship_from_org_id
            ORDER BY stg.org_id;
    -- Commented below cursor for Change 1.8 to include REF Cursor
    --To get order lines for operating Unit and other parameters and process them
    /*CURSOR resched_ord_line_cur (
       cn_batch_id           IN NUMBER,
       cn_ship_from_org_id   IN NUMBER,
       cn_org_id             IN NUMBER,
       cv_brand              IN VARCHAR2)
    IS
         SELECT stg.*
           FROM xxdo.xxd_neg_atp_items_resched_stg stg
          WHERE     1 = 1
                AND status = 'N'                               --NEW Records
                AND stg.batch_id = cn_batch_id
                AND stg.ship_from_org_id = cn_ship_from_org_id
                AND stg.brand = cv_brand
                AND stg.org_id = cn_org_id
                AND stg.seq_no BETWEEN pn_from_seq_num AND pn_to_seq_num
       ORDER BY stg.sku, stg.request_date, stg.schedule_ship_date; */
    BEGIN
        --fnd_global.apps_initialize (1697, 50744, 660);
        --mo_global.init ('ONT');
        --mo_global.set_policy_context ('S', 95);

        --Below setting is a session specific one. No need to reset it back to Yes
        apps.fnd_profile.put ('MRP_ATP_CALC_SD', 'N'); --'MRP: Calculate Supply Demand' profile set to No

        FOR inv_org_ou_rec
            IN inv_org_ou_cur (pn_batch_id, pn_organization_id, pv_brand)
        LOOP
            ln_resp_id        := NULL;
            ln_resp_appl_id   := NULL;

            BEGIN
                --Getting the responsibility and application to initialize and set the context to reschedule order lines
                --Making sure that the initialization is set for proper OM responsibility
                SELECT frv.responsibility_id, frv.application_id
                  INTO ln_resp_id, ln_resp_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                       apps.hr_organization_units hou
                 WHERE     1 = 1
                       AND hou.organization_id = inv_org_ou_rec.org_id
                       AND fpov.profile_option_value =
                           TO_CHAR (hou.organization_id)
                       AND fpo.profile_option_id = fpov.profile_option_id
                       AND fpo.user_profile_option_name =
                           'MO: Operating Unit'
                       AND frv.responsibility_id = fpov.level_value
                       AND frv.application_id = 660                      --ONT
                       AND frv.responsibility_name LIKE
                               'Deckers Order Management User%' --OM Responsibility
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (frv.start_date)
                                               AND TRUNC (
                                                       NVL (frv.end_date,
                                                            SYSDATE))
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                        'Error getting the responsibility ID : ' || SQLERRM);
            END;

            --fnd_global.apps_initialize (1697, 50744, 660);
            write_log ('Org ID : ' || inv_org_ou_rec.org_id);
            write_log ('Inv Org ID : ' || inv_org_ou_rec.ship_from_org_id);
            write_log ('User ID : ' || gn_user_id);
            write_log ('Resp ID : ' || ln_resp_id);
            write_log ('Resp Appl ID : ' || ln_resp_appl_id);
            fnd_global.apps_initialize (user_id        => gn_user_id,
                                        resp_id        => ln_resp_id,
                                        resp_appl_id   => ln_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', inv_org_ou_rec.org_id);

            BEGIN
                --Passing the line ID to Process Order API to Reschedule the line.
                --It will first unschedules the line and then tries to Reschedule it. If successful, issues a commit else Rollsback the changes

                --Added below code for change 1.8
                -- Start of building the SO Line Cursor
                --Added ORDERED_QUANTITY, BULK_ORDER_FLAG as subquery for 2.0
                lv_so_line_cur          :=
                       ' SELECT  stg.batch_id,
                                      stg.org_id org_id,
                                      stg.ship_from_org_id,
                                      stg.brand,
                                      stg.sku,
                                      stg.inventory_item_id,
                                      stg.Customer_id,
                                      stg.header_id,
                                      stg.line_id,
                                      stg.demand_class_code,
                                      stg.schedule_ship_date, 
                                      stg.new_schedule_ship_date,
                                      stg.request_date,
                                      stg.override_atp_flag,
                                      xxitems.style_number,
                                      xxitems.color_code,
                                      xxitems.division,
                                      xxitems.department,
                                      ooha.order_source_id,
                                      stg.ordered_quantity,
                                      (SELECT DECODE (COUNT (1), 0, ''N'', ''Y'')
                                         FROM fnd_lookup_values flv
                                        WHERE flv.language = USERENV (''LANG'')
                                          AND flv.enabled_flag = ''Y''
                                          AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (flv.start_date_active, SYSDATE))
                                          AND TRUNC (NVL (flv.end_date_active, SYSDATE))
                                          AND flv.lookup_type = ''XXD_ONT_BULK_ORDER_TYPE''
                                          AND TO_NUMBER (flv.tag) = ooha.org_id
                                          AND TO_NUMBER (flv.lookup_code) = ooha.order_type_id)
                                       bulk_order_flag
                                FROM  xxdo.xxd_neg_atp_items_resched_stg stg,
                                      xxd_common_items_v xxitems,
                                      apps.oe_order_headers_all ooha
                               WHERE  stg.inventory_item_id = xxitems.inventory_item_id
                                 AND  stg.ship_from_org_id = xxitems.organization_id
                                 AND  ooha.header_id = stg.header_id
                                 AND  stg.seq_no BETWEEN '
                    || pn_from_seq_num
                    || ' AND '
                    || pn_to_seq_num
                    || ' -- Added for change 2.1
                                 AND  stg.status=''N'' -- Added for change 2.1
                                 AND  stg.batch_id = '
                    || pn_batch_id
                    || ' AND  stg.org_id = '
                    || inv_org_ou_rec.org_id
                    || ' AND  stg.ship_from_org_id = '
                    || inv_org_ou_rec.ship_from_org_id
                    || ' AND  stg.brand = '''
                    || pv_brand
                    || '''';

                --Initialization of variables to default as query built is outside the IF condition
                lv_exclude_org          := ' AND 1=1';
                lv_exclude_OU           := ' AND 1=1';
                lv_exclude_brand        := ' AND 1=1';
                lv_exclude_div          := ' AND 1=1';
                lv_exclude_dept         := ' AND 1=1';
                lv_exclude_cust         := ' AND 1=1';
                lv_exclude_ord_type     := ' AND 1=1';
                lv_exclude_sales_chnl   := ' AND 1=1';
                lv_exclude_dem_class    := ' AND 1=1';
                lv_exclude_req_dt       := ' AND 1=1';
                lv_exclude_cond         := ' AND 1=1';

                IF pv_exclude IS NOT NULL AND pv_exclude = 'LOOKUP_DRIVEN'
                THEN
                    ln_exclude_org           := 0;
                    ln_exclude_OU            := 0;
                    ln_exclude_brand         := 0;
                    ln_exclude_div           := 0;
                    ln_exclude_dept          := 0;
                    ln_exclude_cust          := 0;
                    ln_exclude_ord_type      := 0;
                    ln_exclude_sales_chnl    := 0;
                    ln_exclude_dem_class     := 0;
                    ln_exclude_req_from_dt   := 0;
                    ln_exclude_req_to_dt     := 0;

                    BEGIN
                        SELECT COUNT (attribute1), COUNT (attribute2), COUNT (attribute3),
                               COUNT (attribute4), COUNT (attribute5), COUNT (attribute6),
                               COUNT (attribute7), COUNT (attribute8), COUNT (attribute9),
                               COUNT (attribute10), COUNT (attribute11)
                          INTO ln_exclude_org, ln_exclude_OU, ln_exclude_brand, ln_exclude_div,
                                             ln_exclude_dept, ln_exclude_cust, ln_exclude_ord_type,
                                             ln_exclude_sales_chnl, ln_exclude_dem_class, ln_exclude_req_from_dt,
                                             ln_exclude_req_to_dt
                          FROM apps.fnd_lookup_values
                         WHERE     lookup_type =
                                   'XXD_NEG_ATP_RESCH_EXCLUSIONS'
                               AND language = 'US'
                               AND enabled_flag = 'Y'
                               AND SYSDATE BETWEEN NVL (start_date_active,
                                                        SYSDATE)
                                               AND NVL (end_date_active,
                                                        SYSDATE + 1);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_exclude_org           := 0;
                            ln_exclude_OU            := 0;
                            ln_exclude_brand         := 0;
                            ln_exclude_div           := 0;
                            ln_exclude_dept          := 0;
                            ln_exclude_cust          := 0;
                            ln_exclude_ord_type      := 0;
                            ln_exclude_sales_chnl    := 0;
                            ln_exclude_dem_class     := 0;
                            ln_exclude_req_from_dt   := 0;
                            ln_exclude_req_to_dt     := 0;
                    END;

                    IF ln_exclude_org > 0
                    THEN
                        lv_exclude_org   :=
                            ' AND stg.ship_from_org_id NOT IN (SELECT TO_NUMBER(attribute1) 
                              FROM apps.fnd_lookup_values 
                             WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                               AND enabled_flag = ''Y''
                               AND language = ''US'' 
                               AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_org   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_OU > 0
                    THEN
                        lv_exclude_OU   :=
                            ' AND stg.org_id NOT IN (SELECT TO_NUMBER(attribute2)
                            FROM apps.fnd_lookup_values 
                           WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                             AND enabled_flag = ''Y''
                             AND language = ''US'' 
                             AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_OU   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_brand > 0
                    THEN
                        lv_exclude_brand   :=
                            ' AND stg.brand NOT IN (SELECT attribute3 
                           FROM apps.fnd_lookup_values 
                          WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                            AND enabled_flag = ''Y''
                            AND language = ''US'' 
                            AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_brand   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_div > 0
                    THEN
                        lv_exclude_div   :=
                            ' AND xxitems.division NOT IN (SELECT attribute4 
                            FROM apps.fnd_lookup_values 
                           WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                             AND enabled_flag = ''Y''
                             AND language = ''US'' 
                             AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_div   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_dept > 0
                    THEN
                        lv_exclude_dept   :=
                            ' AND xxitems.department NOT IN (SELECT attribute5 
                             FROM apps.fnd_lookup_values 
                            WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                              AND enabled_flag = ''Y''
                              AND language = ''US'' 
                              AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_dept   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_cust > 0
                    THEN
                        lv_exclude_cust   :=
                            ' AND stg.customer_id NOT IN (SELECT TO_NUMBER(attribute6) 
                           FROM apps.fnd_lookup_values 
                          WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                            AND enabled_flag = ''Y''
                            AND language = ''US'' 
                            AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_cust   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_ord_type > 0
                    THEN
                        lv_exclude_ord_type   :=
                            ' AND NOT EXISTS (SELECT  1
                         FROM  apps.oe_order_headers_all ooha
                        WHERE  ooha.header_id = stg.header_id
                          AND  ooha.order_type_id IN  (SELECT  TO_NUMBER(attribute7)
                                                         FROM  apps.fnd_lookup_values flv
                                                        WHERE  flv.lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                                                          AND  flv.enabled_flag = ''Y''
                                                          AND  flv.language = ''US'' 
                                                          AND  SYSDATE BETWEEN NVL(flv.start_date_active,SYSDATE) AND nvl(flv.end_date_active,SYSDATE+1)))';
                    ELSE
                        lv_exclude_ord_type   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_sales_chnl > 0
                    THEN
                        lv_exclude_sales_chnl   :=
                            ' AND NOT EXISTS  (SELECT  1
                        FROM  apps.oe_order_headers_all ooha
                       WHERE  ooha.header_id = stg.header_id
                         AND  ooha.sales_channel_code IN (SELECT  attribute8
                                                            FROM  apps.fnd_lookup_values flv
                                                           WHERE  flv.lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                                                             AND  flv.enabled_flag = ''Y''
                                                             AND  flv.language = ''US'' 
                                                             AND  SYSDATE BETWEEN NVL(flv.start_date_active,SYSDATE) AND nvl(flv.end_date_active,SYSDATE+1)))';
                    ELSE
                        lv_exclude_sales_chnl   := ' AND 1=1';
                    END IF;

                    IF ln_exclude_dem_class > 0
                    THEN
                        lv_exclude_dem_class   :=
                            ' AND stg.demand_class_code NOT IN  (SELECT attribute9 
                       FROM apps.fnd_lookup_values 
                      WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                        AND enabled_flag = ''Y''
                        AND language = ''US'' 
                        AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) ';
                    ELSE
                        lv_exclude_dem_class   := ' AND 1=1';
                    END IF;

                    IF     ln_exclude_req_from_dt > 0
                       AND ln_exclude_req_to_dt > 0
                    THEN
                        lv_exclude_req_dt   :=
                            ' AND stg.request_date NOT BETWEEN (SELECT TO_DATE(attribute10, ''RRRR/MM/DD HH24:MI:SS'') 
                                   FROM apps.fnd_lookup_values 
                                  WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                                    AND enabled_flag = ''Y''
                                    AND language = ''US'' 
                                    AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1)) 
                            AND  (SELECT TO_DATE(attribute11, ''RRRR/MM/DD HH24:MI:SS'')+(1-1/86399) 
                                   FROM apps.fnd_lookup_values 
                                  WHERE lookup_type = ''XXD_NEG_ATP_RESCH_EXCLUSIONS'' 
                                    AND enabled_flag = ''Y''
                                    AND language = ''US'' 
                                    AND SYSDATE BETWEEN NVL(start_date_active,SYSDATE) AND nvl(end_date_active,SYSDATE+1))';
                    ELSE
                        lv_exclude_req_dt   := ' AND 1=1';
                    END IF;
                --Driven by lookup End if
                ELSIF pv_exclude IS NOT NULL AND pv_exclude = 'NONE'
                THEN
                    lv_exclude_cond   := ' AND 1=1';
                ELSIF     pv_exclude IS NOT NULL
                      AND pv_exclude = 'ALL_LINES_WITH_ATP_OVERRIDE'
                THEN
                    lv_exclude_cond   :=
                        ' AND NVL(stg.override_atp_flag, ''N'') <> ''Y''';
                ELSIF pv_exclude IS NOT NULL AND pv_exclude = 'ALL_ISO'
                THEN
                    lv_exclude_cond   := ' AND ooha.order_source_id <> 10 ';
                ELSIF     pv_exclude IS NOT NULL
                      AND pv_exclude = 'ISO_WITH_OVERRIDE_ATP'
                THEN
                    lv_exclude_cond   :=
                        ' AND (ooha.order_source_id <> 10 AND NVL(stg.override_atp_flag, ''N'') <> ''Y'')';
                ELSE
                    lv_exclude_cond   := ' AND 1=1';
                END IF;

                lv_so_line_act_cur      :=
                       lv_so_line_cur
                    || lv_exclude_org
                    || lv_exclude_ou
                    || lv_exclude_brand
                    || lv_exclude_div
                    || lv_exclude_dept
                    || lv_exclude_cust
                    || lv_exclude_ord_type
                    || lv_exclude_sales_chnl
                    || lv_exclude_dem_class
                    || lv_exclude_req_dt
                    || lv_exclude_cond;

                write_log ('-------------------------------------------');
                write_log ('Rescheduled Orders query: ');
                write_log (
                       'Timestamp: '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
                write_log ('-------------------------------------------');
                write_log (lv_so_line_act_cur);
                write_log ('-------------------------------------------');

                ----Added code for change 1.8 --END

                --Opening the REF cursor created for change 1.8

                OPEN so_line_cur FOR lv_so_line_act_cur;

                FETCH so_line_cur BULK COLLECT INTO so_line_rec;

                CLOSE so_line_cur;


                --Now if the cursor return data the loop the data and call process order API for change 1.8
                --Added below IF and LOOP for change 1.8
                IF so_line_rec.COUNT > 0
                THEN
                    FOR i IN so_line_rec.FIRST .. so_line_rec.LAST
                    LOOP
                        l_return_status    := NULL;
                        l_msg_data         := NULL;
                        l_message_data     := NULL;

                        l_line_tbl_index   := 1;
                        l_line_tbl (l_line_tbl_index)   :=
                            oe_order_pub.g_miss_line_rec;
                        l_line_tbl (l_line_tbl_index).operation   :=
                            oe_globals.g_opr_update;
                        l_line_tbl (l_line_tbl_index).org_id   :=
                            so_line_rec (i).org_id;
                        l_line_tbl (l_line_tbl_index).header_id   :=
                            so_line_rec (i).header_id;
                        l_line_tbl (l_line_tbl_index).line_id   :=
                            so_line_rec (i).line_id;
                        l_line_tbl (l_line_tbl_index).schedule_action_code   :=
                            'RESCHEDULE';                --Rescheduling Action
                        --l_line_tbl (l_line_tbl_index).override_atp_date_code := 'N';  --Commented on 15FEB2017 (we no longer require this as no order line will have this flag as 'Y')

                        --To rollback to this point
                        --SAVEPOINT reschedule;  --Commenting the code for change 1.2
                        oe_order_pub.process_order (
                            p_api_version_number     => 1.0,
                            p_init_msg_list          => fnd_api.g_true,
                            p_return_values          => fnd_api.g_true,
                            p_action_commit          => fnd_api.g_false,
                            x_return_status          => l_return_status,
                            x_msg_count              => l_msg_count,
                            x_msg_data               => l_msg_data,
                            p_header_rec             => l_header_rec,
                            p_line_tbl               => l_line_tbl,
                            p_action_request_tbl     => l_action_request_tbl,
                            x_header_rec             => l_header_rec_x,
                            x_header_val_rec         => x_header_val_rec,
                            x_header_adj_tbl         => x_header_adj_tbl,
                            x_header_adj_val_tbl     => x_header_adj_val_tbl,
                            x_header_price_att_tbl   => x_header_price_att_tbl,
                            x_header_adj_att_tbl     => x_header_adj_att_tbl,
                            x_header_adj_assoc_tbl   => x_header_adj_assoc_tbl,
                            x_header_scredit_tbl     => x_header_scredit_tbl,
                            x_header_scredit_val_tbl   =>
                                x_header_scredit_val_tbl,
                            x_line_tbl               => l_line_tbl_x,
                            x_line_val_tbl           => x_line_val_tbl,
                            x_line_adj_tbl           => x_line_adj_tbl,
                            x_line_adj_val_tbl       => x_line_adj_val_tbl,
                            x_line_price_att_tbl     => x_line_price_att_tbl,
                            x_line_adj_att_tbl       => x_line_adj_att_tbl,
                            x_line_adj_assoc_tbl     => x_line_adj_assoc_tbl,
                            x_line_scredit_tbl       => x_line_scredit_tbl,
                            x_line_scredit_val_tbl   => x_line_scredit_val_tbl,
                            x_lot_serial_tbl         => x_lot_serial_tbl,
                            x_lot_serial_val_tbl     => x_lot_serial_val_tbl,
                            x_action_request_tbl     => l_action_request_tbl);

                        IF l_return_status = fnd_api.g_ret_sts_success
                        THEN
                            --write_log( 'Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);
                            --dbms_output.put_line ('Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);
                            --NULL;
                            --rollback to reschedule;
                            l_row_num   := l_row_num + 1;
                        --xv_schedule_ship_date := l_line_tbl_x(l_line_tbl_index).schedule_ship_date;
                        --xv_schedule_ship_date := TO_CHAR(l_line_tbl_x(l_line_tbl_index).schedule_ship_date,'DD-MON-RRRR');
                        ELSE
                            --dbms_output.put_line ('E');
                            --write_log( 'Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);
                            --dbms_output.put_line ('Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);

                            FOR i IN 1 .. l_msg_count
                            LOOP
                                oe_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => fnd_api.g_false,
                                    p_data            => l_msg_data,
                                    p_msg_index_out   => l_msg_index_out);

                                l_message_data   :=
                                    l_message_data || l_msg_data;
                            --write_log( 'Error: ' || l_msg_data);
                            --write_log( 'Error for Line ID:'||resched_ord_line_rec.line_id||'  is :' ||l_msg_data);
                            --dbms_output.put_line ('Error: ' || l_msg_data);
                            --dbms_output.put_line ('Error for Line ID:'||resched_ord_line_rec.line_id||'  is :' ||l_msg_data);
                            END LOOP;

                            --ROLLBACK TO reschedule; --Commenting the code for change 1.2
                            l_row_num_err   := l_row_num_err + 1;
                            ROLLBACK;
                        END IF;

                        --Updating the staging table with status and other relevant information
                        BEGIN
                            UPDATE xxdo.xxd_neg_atp_items_resched_stg xna_u
                               SET xna_u.status = l_return_status, error_message = l_message_data, xna_u.new_schedule_ship_date = l_line_tbl_x (l_line_tbl_index).schedule_ship_date,
                                   xna_u.last_update_date = SYSDATE, xna_u.child_request_id = ln_conc_request_id
                             WHERE     xna_u.line_id =
                                       so_line_rec (i).line_id
                                   AND xna_u.batch_id =
                                       so_line_rec (i).batch_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                write_log (
                                       'Error while updating the staging table for line ID - '
                                    || so_line_rec (i).line_id);
                        END;

                        COMMIT;

                        --Added code to Unschedule Line for change 1.2 --START
                        --unschedule the lines which are not successfully rescheduled based on user input(pv_unschedule = Yes or No)
                        IF (l_return_status <> fnd_api.g_ret_sts_success AND --If return status is not success(Failed to Reschedule)
                                                                             pv_unschedule = 'Y' --Unschedule = Yes
                                                                                                )
                        THEN
                            l_return_status    := NULL;
                            l_msg_data         := NULL;
                            l_message_data     := NULL;

                            l_line_tbl_index   := 1;
                            l_line_tbl (l_line_tbl_index)   :=
                                oe_order_pub.g_miss_line_rec;
                            l_line_tbl (l_line_tbl_index).operation   :=
                                oe_globals.g_opr_update;
                            l_line_tbl (l_line_tbl_index).org_id   :=
                                so_line_rec (i).org_id;
                            l_line_tbl (l_line_tbl_index).header_id   :=
                                so_line_rec (i).header_id;
                            l_line_tbl (l_line_tbl_index).line_id   :=
                                so_line_rec (i).line_id;
                            l_line_tbl (l_line_tbl_index).schedule_action_code   :=
                                'UNSCHEDULE';            --Unscheduling Action
                            --l_line_tbl (l_line_tbl_index).override_atp_date_code := 'N';
                            xxd_ont_order_utils_pkg.gc_skip_neg_unconsumption   :=
                                'Y';                    --Added for change 2.4
                            oe_order_pub.process_order (
                                p_api_version_number   => 1.0,
                                p_init_msg_list        => fnd_api.g_true,
                                p_return_values        => fnd_api.g_true,
                                p_action_commit        => fnd_api.g_false,
                                x_return_status        => l_return_status,
                                x_msg_count            => l_msg_count,
                                x_msg_data             => l_msg_data,
                                p_header_rec           => l_header_rec,
                                p_line_tbl             => l_line_tbl,
                                p_action_request_tbl   => l_action_request_tbl,
                                x_header_rec           => l_header_rec_x,
                                x_header_val_rec       => x_header_val_rec,
                                x_header_adj_tbl       => x_header_adj_tbl,
                                x_header_adj_val_tbl   => x_header_adj_val_tbl,
                                x_header_price_att_tbl   =>
                                    x_header_price_att_tbl,
                                x_header_adj_att_tbl   => x_header_adj_att_tbl,
                                x_header_adj_assoc_tbl   =>
                                    x_header_adj_assoc_tbl,
                                x_header_scredit_tbl   => x_header_scredit_tbl,
                                x_header_scredit_val_tbl   =>
                                    x_header_scredit_val_tbl,
                                x_line_tbl             => l_line_tbl_x,
                                x_line_val_tbl         => x_line_val_tbl,
                                x_line_adj_tbl         => x_line_adj_tbl,
                                x_line_adj_val_tbl     => x_line_adj_val_tbl,
                                x_line_price_att_tbl   => x_line_price_att_tbl,
                                x_line_adj_att_tbl     => x_line_adj_att_tbl,
                                x_line_adj_assoc_tbl   => x_line_adj_assoc_tbl,
                                x_line_scredit_tbl     => x_line_scredit_tbl,
                                x_line_scredit_val_tbl   =>
                                    x_line_scredit_val_tbl,
                                x_lot_serial_tbl       => x_lot_serial_tbl,
                                x_lot_serial_val_tbl   => x_lot_serial_val_tbl,
                                x_action_request_tbl   => l_action_request_tbl);
                            xxd_ont_order_utils_pkg.gc_skip_neg_unconsumption   :=
                                'N';                    --Added for change 2.4

                            IF l_return_status = fnd_api.g_ret_sts_success
                            THEN
                                write_log (
                                       'Line ID:'
                                    || so_line_rec (i).line_id
                                    || ' Status is :'
                                    || l_return_status);
                                --dbms_output.put_line ('Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);
                                --NULL;
                                --rollback to reschedule;
                                l_unsched_row_num   := l_unsched_row_num + 1;
                            --xv_schedule_ship_date := l_line_tbl_x(l_line_tbl_index).schedule_ship_date;
                            --xv_schedule_ship_date := TO_CHAR(l_line_tbl_x(l_line_tbl_index).schedule_ship_date,'DD-MON-RRRR');
                            ELSE
                                --dbms_output.put_line ('E');
                                write_log (
                                       'Line ID:'
                                    || so_line_rec (i).line_id
                                    || ' Status is :'
                                    || l_return_status);

                                --dbms_output.put_line ('Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);

                                FOR i IN 1 .. l_msg_count
                                LOOP
                                    oe_msg_pub.get (
                                        p_msg_index       => i,
                                        p_encoded         => fnd_api.g_false,
                                        p_data            => l_msg_data,
                                        p_msg_index_out   => l_msg_index_out);

                                    l_message_data   :=
                                        l_message_data || l_msg_data;
                                --write_log( 'Error: ' || l_msg_data);
                                --write_log( 'Error for Line ID:'||resched_ord_line_rec.line_id||'  is :' ||l_msg_data);
                                --dbms_output.put_line ('Error: ' || l_msg_data);
                                --dbms_output.put_line ('Error for Line ID:'||resched_ord_line_rec.line_id||'  is :' ||l_msg_data);
                                END LOOP;

                                --ROLLBACK TO reschedule; --Commenting the code for change 1.2
                                l_unsched_row_num_err   :=
                                    l_unsched_row_num_err + 1;
                            END IF;

                            IF l_return_status <> fnd_api.g_ret_sts_success
                            THEN
                                l_return_status   := 'X'; --Unscheduling Failed
                            ELSE
                                l_return_status   := 'Z'; --Unscheduling Successful
                            END IF;

                            --Updating the staging table with unscheduling status and other relevant information
                            BEGIN
                                UPDATE xxdo.xxd_neg_atp_items_resched_stg xna_u
                                   SET xna_u.status = l_return_status, --error_message = l_message_data,
                                                                       xna_u.last_update_date = SYSDATE, xna_u.child_request_id = ln_conc_request_id
                                 WHERE     xna_u.line_id =
                                           so_line_rec (i).line_id
                                       AND xna_u.batch_id =
                                           so_line_rec (i).batch_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    write_log (
                                           'Error while updating the Unscheduling status to staging table for line ID - '
                                        || so_line_rec (i).line_id);
                            END;

                            COMMIT;
                        END IF;

                        --End of Code change 1.2 --END

                        -- Start changes for 2.0
                        /****************************************************************************************
                         * If unscheduling is success, then try split and schedule for bulks
                         ****************************************************************************************/
                        IF     l_return_status = 'Z'
                           AND so_line_rec (i).bulk_order_flag = 'Y'
                        THEN
                            ln_atp_current_available_qty   := 0;
                            ln_new_line_split_qty          := 0;
                            lc_atp_return_status           := NULL;
                            lc_atp_error_message           := NULL;

                            /****************************************************************************************
                             * ATP check and calculate the available qty
                             ****************************************************************************************/
                            get_atp_qty (
                                p_line_id         => so_line_rec (i).line_id,
                                x_atp_current_available_qty   =>
                                    ln_atp_current_available_qty,
                                x_return_status   => lc_atp_return_status,
                                x_error_message   => lc_atp_error_message);

                            IF    lc_atp_return_status <>
                                  fnd_api.g_ret_sts_success
                               OR ln_atp_current_available_qty = 0
                            THEN
                                l_return_status   := 'BUL-ATP-F';
                                l_message_data    := 'Bulk ATP Check Failed';
                            ELSIF     lc_atp_return_status =
                                      fnd_api.g_ret_sts_success
                                  AND ln_atp_current_available_qty > 0
                            THEN
                                ln_new_line_split_qty              :=
                                      so_line_rec (i).ordered_quantity
                                    - ln_atp_current_available_qty;

                                /****************************************************************************************
                                 * Order line split based on available qty
                                 ****************************************************************************************/
                                l_return_status                    := NULL;
                                l_msg_data                         := NULL;
                                l_message_data                     := NULL;
                                oe_msg_pub.initialize;

                                l_header_rec                       :=
                                    oe_order_pub.g_miss_header_rec;
                                l_line_tbl                         :=
                                    oe_order_pub.g_miss_line_tbl;
                                -- Original Line Changes
                                l_line_tbl (1)                     :=
                                    oe_order_pub.g_miss_line_rec;
                                l_line_tbl (1).header_id           :=
                                    so_line_rec (i).header_id;
                                l_line_tbl (1).org_id              :=
                                    so_line_rec (i).org_id;
                                l_line_tbl (1).line_id             :=
                                    so_line_rec (i).line_id;
                                l_line_tbl (1).split_action_code   := 'SPLIT';
                                -- Pass User Id to "Split_By" instead of value "USER" to Original Line. Oracle Doc ID 2156475.1
                                l_line_tbl (1).split_by            :=
                                    gn_user_id;
                                l_line_tbl (1).ordered_quantity    :=
                                    ln_atp_current_available_qty;
                                l_line_tbl (1).operation           :=
                                    oe_globals.g_opr_update;

                                -- Split Line
                                l_line_tbl (2)                     :=
                                    oe_order_pub.g_miss_line_rec;
                                l_line_tbl (2).header_id           :=
                                    so_line_rec (i).header_id;
                                l_line_tbl (2).org_id              :=
                                    so_line_rec (i).org_id;
                                l_line_tbl (2).split_action_code   := 'SPLIT';
                                -- Pass constant value "USER" to "Split_By" to Split Line. Oracle Doc ID 2156475.1
                                l_line_tbl (2).split_by            := 'USER';
                                l_line_tbl (2).split_from_line_id   :=
                                    so_line_rec (i).line_id;
                                l_line_tbl (2).ordered_quantity    :=
                                    ln_new_line_split_qty;
                                l_line_tbl (2).request_id          :=
                                    ln_conc_request_id;
                                l_line_tbl (2).operation           :=
                                    oe_globals.g_opr_create;

                                oe_order_pub.process_order (
                                    p_api_version_number   => 1.0,
                                    p_init_msg_list        => fnd_api.g_true,
                                    p_return_values        => fnd_api.g_true,
                                    p_action_commit        => fnd_api.g_false,
                                    x_return_status        => l_return_status,
                                    x_msg_count            => l_msg_count,
                                    x_msg_data             => l_msg_data,
                                    p_header_rec           => l_header_rec,
                                    p_line_tbl             => l_line_tbl,
                                    p_action_request_tbl   =>
                                        l_action_request_tbl,
                                    x_header_rec           => l_header_rec_x,
                                    x_header_val_rec       => x_header_val_rec,
                                    x_header_adj_tbl       => x_header_adj_tbl,
                                    x_header_adj_val_tbl   =>
                                        x_header_adj_val_tbl,
                                    x_header_price_att_tbl   =>
                                        x_header_price_att_tbl,
                                    x_header_adj_att_tbl   =>
                                        x_header_adj_att_tbl,
                                    x_header_adj_assoc_tbl   =>
                                        x_header_adj_assoc_tbl,
                                    x_header_scredit_tbl   =>
                                        x_header_scredit_tbl,
                                    x_header_scredit_val_tbl   =>
                                        x_header_scredit_val_tbl,
                                    x_line_tbl             => l_line_tbl_x,
                                    x_line_val_tbl         => x_line_val_tbl,
                                    x_line_adj_tbl         => x_line_adj_tbl,
                                    x_line_adj_val_tbl     =>
                                        x_line_adj_val_tbl,
                                    x_line_price_att_tbl   =>
                                        x_line_price_att_tbl,
                                    x_line_adj_att_tbl     =>
                                        x_line_adj_att_tbl,
                                    x_line_adj_assoc_tbl   =>
                                        x_line_adj_assoc_tbl,
                                    x_line_scredit_tbl     =>
                                        x_line_scredit_tbl,
                                    x_line_scredit_val_tbl   =>
                                        x_line_scredit_val_tbl,
                                    x_lot_serial_tbl       => x_lot_serial_tbl,
                                    x_lot_serial_val_tbl   =>
                                        x_lot_serial_val_tbl,
                                    x_action_request_tbl   =>
                                        l_action_request_tbl);
                                write_log (
                                       'Bulk Split API Status :'
                                    || l_return_status);

                                IF l_return_status <>
                                   fnd_api.g_ret_sts_success
                                THEN
                                    FOR i IN 1 .. l_msg_count
                                    LOOP
                                        oe_msg_pub.get (
                                            p_msg_index   => i,
                                            p_encoded     => fnd_api.g_false,
                                            p_data        => l_msg_data,
                                            p_msg_index_out   =>
                                                l_msg_index_out);

                                        l_message_data   :=
                                            l_message_data || l_msg_data;
                                    END LOOP;

                                    write_log (
                                           'Bulk Split API Error :'
                                        || l_message_data);

                                    ln_bulk_split_err   :=
                                        ln_bulk_split_err + 1;
                                    l_return_status   := 'BUL-SPL-F';
                                    l_message_data    := 'Bulk Split Failed';
                                ELSE
                                    COMMIT; -- this is needed to avoid further split from scheduling API
                                    /****************************************************************************************
                                     * Schedule the original line
                                     ****************************************************************************************/
                                    l_return_status   := NULL;
                                    l_msg_data        := NULL;
                                    l_message_data    := NULL;
                                    oe_msg_pub.initialize;

                                    l_line_tbl        :=
                                        oe_order_pub.g_miss_line_tbl;
                                    l_line_tbl (1)    :=
                                        oe_order_pub.g_miss_line_rec;
                                    l_line_tbl (1).operation   :=
                                        oe_globals.g_opr_update;
                                    l_line_tbl (1).org_id   :=
                                        so_line_rec (i).org_id;
                                    l_line_tbl (1).header_id   :=
                                        so_line_rec (i).header_id;
                                    l_line_tbl (1).line_id   :=
                                        so_line_rec (i).line_id;
                                    l_line_tbl (1).schedule_action_code   :=
                                        'SCHEDULE';

                                    oe_order_pub.process_order (
                                        p_api_version_number   => 1.0,
                                        p_init_msg_list        =>
                                            fnd_api.g_true,
                                        p_return_values        =>
                                            fnd_api.g_true,
                                        p_action_commit        =>
                                            fnd_api.g_false,
                                        x_return_status        =>
                                            l_return_status,
                                        x_msg_count            => l_msg_count,
                                        x_msg_data             => l_msg_data,
                                        p_header_rec           => l_header_rec,
                                        p_line_tbl             => l_line_tbl,
                                        p_action_request_tbl   =>
                                            l_action_request_tbl,
                                        x_header_rec           =>
                                            l_header_rec_x,
                                        x_header_val_rec       =>
                                            x_header_val_rec,
                                        x_header_adj_tbl       =>
                                            x_header_adj_tbl,
                                        x_header_adj_val_tbl   =>
                                            x_header_adj_val_tbl,
                                        x_header_price_att_tbl   =>
                                            x_header_price_att_tbl,
                                        x_header_adj_att_tbl   =>
                                            x_header_adj_att_tbl,
                                        x_header_adj_assoc_tbl   =>
                                            x_header_adj_assoc_tbl,
                                        x_header_scredit_tbl   =>
                                            x_header_scredit_tbl,
                                        x_header_scredit_val_tbl   =>
                                            x_header_scredit_val_tbl,
                                        x_line_tbl             => l_line_tbl_x,
                                        x_line_val_tbl         =>
                                            x_line_val_tbl,
                                        x_line_adj_tbl         =>
                                            x_line_adj_tbl,
                                        x_line_adj_val_tbl     =>
                                            x_line_adj_val_tbl,
                                        x_line_price_att_tbl   =>
                                            x_line_price_att_tbl,
                                        x_line_adj_att_tbl     =>
                                            x_line_adj_att_tbl,
                                        x_line_adj_assoc_tbl   =>
                                            x_line_adj_assoc_tbl,
                                        x_line_scredit_tbl     =>
                                            x_line_scredit_tbl,
                                        x_line_scredit_val_tbl   =>
                                            x_line_scredit_val_tbl,
                                        x_lot_serial_tbl       =>
                                            x_lot_serial_tbl,
                                        x_lot_serial_val_tbl   =>
                                            x_lot_serial_val_tbl,
                                        x_action_request_tbl   =>
                                            l_action_request_tbl);
                                    write_log (
                                           'Bulk Schedule API Status :'
                                        || l_return_status);

                                    IF l_return_status =
                                       fnd_api.g_ret_sts_success
                                    THEN
                                        ln_bulk_split_success   :=
                                            ln_bulk_split_success + 1;
                                        l_return_status   := 'BUL-SCH-S';
                                        l_message_data    := NULL;
                                    ELSE
                                        FOR i IN 1 .. l_msg_count
                                        LOOP
                                            oe_msg_pub.get (
                                                p_msg_index   => i,
                                                p_encoded     =>
                                                    fnd_api.g_false,
                                                p_data        => l_msg_data,
                                                p_msg_index_out   =>
                                                    l_msg_index_out);

                                            l_message_data   :=
                                                l_message_data || l_msg_data;
                                        END LOOP;

                                        write_log (
                                               'Bulk Schedule API Error :'
                                            || l_message_data);

                                        ln_bulk_split_err   :=
                                            ln_bulk_split_err + 1;
                                        l_return_status   := 'BUL-SCH-F';
                                        l_message_data    :=
                                            'Bulk Schedule Failed';
                                    END IF;
                                END IF;                           -- Split API
                            END IF;                                 -- ATP API

                            --Updating the staging table with schedule status

                            UPDATE xxdo.xxd_neg_atp_items_resched_stg xna_u
                               SET xna_u.status = l_return_status, error_message = l_message_data, xna_u.last_update_date = SYSDATE,
                                   xna_u.child_request_id = ln_conc_request_id
                             WHERE     xna_u.line_id =
                                       so_line_rec (i).line_id
                                   AND xna_u.batch_id =
                                       so_line_rec (i).batch_id;

                            COMMIT;
                        END IF;                       -- bulk_order_flag = 'Y'
                    -- End changes for 2.0

                    END LOOP; --REF Cursor Data End Loop --Added for change 1.8
                END IF; --Count of records returned by Ref cursor end if --Added for change 1.8
            --write_log( 'Success record count = ' || l_row_num);
            --write_log( 'Error record count = ' || l_row_num_err);
            --dbms_output.put_line ('Success record count = ' || l_row_num);
            --dbms_output.put_line ('Error record count = ' || l_row_num_err);
            END;
        END LOOP;                                    --inv_org_ou_cur END LOOP

        write_log ('Records successfully got Rescheduled = ' || l_row_num);
        write_log ('Records Errored while Rescheduling = ' || l_row_num_err);
        -- Start changes for 2.0
        write_log (
               'Records successfully split and schedule for Bulk = '
            || ln_bulk_split_success);
        write_log (
               'Records errored while split and schedule for Bulk = '
            || ln_bulk_split_err);

        -- End changes for 2.0

        IF pv_unschedule = 'Y'
        THEN
            write_log (
                'Records Sucessfully Unscheduled = ' || l_unsched_row_num);
            write_log (
                   'Records Errored while Unscheduling = '
                || l_unsched_row_num_err);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            --dbms_output.put_line ('In when others exception in Schedule_Orders procedure. Error message is : ' || SQLERRM);
            write_log (
                   'In when others exception in reschedule_api_call procedure. Error message is : '
                || SQLERRM);
    END reschedule_api_call;

    /******************************************************************************************/
    --This procedure purges the data from the staging table which is before the retention days
    /******************************************************************************************/
    PROCEDURE purge_data (pn_retention_days IN NUMBER DEFAULT 30)
    IS
        CURSOR del_stg_rec_cnt_cur (cn_purge_ret_days IN NUMBER)
        IS
            SELECT COUNT (*) records_cnt
              FROM xxdo.xxd_neg_atp_items_resched_stg stg
             WHERE TRUNC (creation_date) <
                   TRUNC (SYSDATE - NVL (cn_purge_ret_days, 30));

        --Purging the data from the staging table
        CURSOR c_plan_data (cn_purge_ret_days NUMBER)
        IS
              SELECT ship_from_org, COUNT (*) records_purged
                FROM xxdo.xxd_neg_atp_items_resched_stg stg
               WHERE TRUNC (creation_date) <
                     TRUNC (SYSDATE - NVL (cn_purge_ret_days, 30))
            GROUP BY ship_from_org
            ORDER BY ship_from_org;

        ln_commit_count             NUMBER := 0;
        ln_records_deleted          NUMBER := 0;
        ln_stg_rec_cnt              NUMBER := 0;
        ln_neg_atp_item_del_cnt     NUMBER := 0;
        ln_neg_atp_soline_del_cnt   NUMBER := 0;
    BEGIN
        --Truncating the temp table holding the negative ATP items
        --write_log('Truncating the Negative ATP items Temp table (xxd_neg_atp_items_tmp)');
        --EXECUTE IMMEDIATE('TRUNCATE TABLE XXDO.XXD_NEG_ATP_ITEMS_TMP');

        --Deleting the data in the temp table holding the negative ATP items
        DELETE FROM
            xxdo.xxd_neg_atp_items_tmp
              WHERE TRUNC (creation_date) <
                    TRUNC (SYSDATE - NVL (pn_retention_days, 30));

        ln_neg_atp_item_del_cnt     := SQL%ROWCOUNT;
        COMMIT;

        write_log (
               'Number of records deleted from Neg. ATP Items Temp table(XXD_NEG_ATP_ITEMS_TMP) = '
            || ln_neg_atp_item_del_cnt);

        --Deleting the temp table data holding the negative ATP items related SO Lines
        DELETE FROM
            xxdo.xxd_neg_atp_so_line_tmp
              WHERE TRUNC (creation_date) <
                    TRUNC (SYSDATE - NVL (pn_retention_days, 30));

        ln_neg_atp_soline_del_cnt   := SQL%ROWCOUNT;
        COMMIT;

        write_log (
               'Number of records deleted from Neg. ATP Items SO Lines Temp table(XXD_NEG_ATP_SO_LINE_TMP) = '
            || ln_neg_atp_soline_del_cnt);

        OPEN del_stg_rec_cnt_cur (pn_retention_days);

        FETCH del_stg_rec_cnt_cur INTO ln_stg_rec_cnt;

        CLOSE del_stg_rec_cnt_cur;

        IF ln_stg_rec_cnt > 0
        THEN
            ---Printing the count of records purged by inventory organization
            write_log (
                   'Number of records purged from staging table = '
                || ln_stg_rec_cnt);
            write_log ('--------   -----------------');
            write_log ('Org Code   Records Purged');
            write_log ('--------   -----------------');

            FOR rec_plan_data IN c_plan_data (pn_retention_days)
            LOOP
                write_log (
                       rec_plan_data.ship_from_org
                    || '        '
                    || rec_plan_data.records_purged);
            END LOOP;

            write_log ('--------   -----------------');
        ELSE
            write_log (
                'There are no records to Purge from staging table(XXD_NEG_ATP_ITEMS_RESCHED_STG)');
        END IF;


        DELETE FROM
            xxdo.xxd_neg_atp_items_resched_stg
              WHERE TRUNC (creation_date) <
                    TRUNC (SYSDATE - NVL (pn_retention_days, 30));

        ln_records_deleted          := SQL%ROWCOUNT;
        COMMIT;

        write_log (
               'Number of records deleted from staging table(XXD_NEG_ATP_ITEMS_RESCHED_STG) by purge program = '
            || ln_records_deleted);
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in purge_data procedure: ' || SQLERRM);
            raise_application_error (
                -20020,
                'Error in Procedure purge_data ' || SQLERRM);
    END;

    /******************************************************************************************/
    --This procedure Prints the audit report in the concurrent program output file
    /******************************************************************************************/
    PROCEDURE audit_report (pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2 --pn_from_seq_num      IN NUMBER,
                                                                                                     --pn_to_seq_num        IN NUMBER
                                                                                                     )
    IS
        --    CURSOR audit_cur IS
        --    SELECT xna.*,
        --           DECODE(xna.status,
        --                   'S', new_schedule_ship_date) new_schedule_ship_date_der,
        --           DECODE(xna.status,
        --                   'S', 'Success',
        --                   'E' ,'Fail',
        --                   'U', 'API Unhandled Exception',
        --                   'N', 'Not Processed',
        --                   'Error') status_desc
        --    FROM   xxdo.xxd_neg_atp_items_resched_stg xna
        --    WHERE  1 = 1
        --      AND  xna.batch_id = pn_batch_id
        --      AND  xna.ship_from_org_id = pn_organization_id
        --      AND  xna.brand = pv_brand
        --      ORDER BY xna.ship_from_org,
        --               xna.sku,
        --               xna.request_date,
        --               xna.schedule_ship_date
        --    ;
        CURSOR audit_cur IS
              SELECT hou.name operating_unit,
                     mp.organization_code ship_from_org,
                     itm.brand,
                     itm.division,                      --Added for change 1.9
                     itm.department,                    --Added for change 1.9
                     itm.style_number style,
                     itm.style_desc,                    --Added for change 1.9
                     itm.color_code color,
                     itm.color_desc,                    --Added for change 1.9
                     xna.sku,
                     itm.item_description,              --Added for change 1.9
                     --xna.order_number,
                     ooha.order_number,
                     ooha.ordered_date,                 --Added for change 1.9
                     oota.name order_type,                    --Added for 1.6.
                     xna.line_num,
                     hp.party_name customer_name,
                     -- START : Added for 1.4.
                     hca.account_number,
                     (SELECT jrre.resource_name
                        FROM oe_order_lines_all ol, jtf_rs_salesreps jrs, jtf_rs_resource_extns_tl jrre
                       WHERE     jrs.resource_id = jrre.resource_id
                             AND jrre.language = 'US'
                             AND jrs.salesrep_id = ol.salesrep_id
                             AND ol.line_id = xna.line_id
                             AND jrs.org_id = ol.org_id --    Added by Infosys for 1.5.
                                                       ) salesrep_name,
                     -- END : Added for 1.4.
                     xna.demand_class_code,
                     xna.request_date,
                     xna.schedule_ship_date,
                     -- Start changes for 2.0
                     -- DECODE (xna.status, 'S', new_schedule_ship_date)
                     CASE
                         WHEN xna.status IN ('S', 'BUL-SCH-S')
                         THEN
                             oola.schedule_ship_date
                     END -- End changes for 2.0
                         new_schedule_ship_date_der,
                     xna.latest_acceptable_date,
                     xna.override_atp_flag,
                     xna.cancel_date,
                     -- Start changes for 2.0
                     -- xna.ordered_quantity,
                     oola.ordered_quantity,
                     -- End changes for 2.0
                     DECODE (xna.status,
                             --'S', 'Success', --Commenting the code for change 1.2
                             'S', 'Rescheduled', --Added the code for change 1.2
                             --'E' ,'Fail', --Commenting the code for change 1.2
                             'E', 'Rescheduling Failed', --Added the code for change 1.2
                             'X', 'Unscheduling Failed', --Added this code for change 1.2
                             'Z', 'Unscheduled', --Added this for code change 1.2
                             'U', 'API Unhandled Exception',
                             -- Start changes for 2.0
                             'BUL-SCH-S', 'Bulk Scheduled',
                             'BUL-ATP-F', 'Bulk ATP Check Failed',
                             'BUL-SPL-F', 'Bulk Split Failed',
                             'BUL-SCH-F', 'Bulk Schedule Failed',
                             -- End changes for 2.0
                             'N', 'Not Processed',
                             'Error') status_desc,
                     xna.error_message,
                     LTRIM (SUBSTR (xna.error_message,
                                      INSTR (xna.error_message, ':', 1,
                                             2)
                                    + 1)) next_supply_date, --Added for code change 1.2
                     --Start changes for 1.7
                     ooha.cust_po_number,
                     NVL2 (xobot.bulk_order_number, 'Yes', 'No') calloff_order,
                     xobot.bulk_order_number,
                     xobot.bulk_cust_po_number bulk_po,
                     NVL2 (
                         xobot.bulk_order_number,
                            xobot.bulk_line_number
                         || '.'
                         || xobot.bulk_shipment_number,
                         NULL) bulk_line_num,
                     (SELECT request_date
                        FROM oe_order_lines_all
                       WHERE line_id = xobot.bulk_line_id) bulk_rsd,
                     (SELECT schedule_ship_date
                        FROM oe_order_lines_all
                       WHERE line_id = xobot.bulk_line_id) bulk_ssd,
                     (SELECT latest_acceptable_date
                        FROM oe_order_lines_all
                       WHERE line_id = xobot.bulk_line_id) bulk_lad
                --End changes for 1.7
                FROM xxdo.xxd_neg_atp_items_resched_stg xna, apps.hz_cust_accounts hca, apps.hz_parties hp,
                     apps.xxd_common_items_v itm, apps.hr_operating_units hou, apps.mtl_parameters mp,
                     apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, --Added for 1.7
                                                                                   apps.xxd_ont_bulk_orders_t xobot, --Added for 1.7
                     apps.oe_transaction_types_tl oota        --Added for 1.6.
               WHERE     1 = 1
                     AND ooha.order_type_id = oota.transaction_type_id --Added for 1.6.
                     AND oota.language = USERENV ('LANG')     --Added for 1.6.
                     AND xna.batch_id = pn_batch_id
                     AND xna.ship_from_org_id = pn_organization_id
                     AND xna.brand = pv_brand           --Added for change 1.2
                     --AND  itm.brand = pv_brand  --Commented for change 1.2
                     AND xna.customer_id = hca.cust_account_id
                     AND hca.status = 'A'
                     AND hca.party_id = hp.party_id
                     AND hp.status = 'A'
                     AND xna.inventory_item_id = itm.inventory_item_id
                     AND xna.ship_from_org_id = itm.organization_id
                     AND xna.org_id = hou.organization_id
                     AND xna.ship_from_org_id = mp.organization_id
                     AND xna.header_id = ooha.header_id
                     --Start changes for 1.7
                     AND xna.header_id = oola.header_id
                     AND xna.line_id = oola.line_id
                     AND oola.header_id = xobot.calloff_header_id(+)
                     AND oola.line_id = xobot.calloff_line_id(+)
                     AND xobot.link_type(+) = 'BULK_LINK'
            --End changes for 1.7
            --AND  xna.seq_no BETWEEN pn_from_seq_num
            --                  AND pn_to_seq_num
            ORDER BY xna.ship_from_org, xna.sku, xna.request_date,
                     xna.schedule_ship_date;
    BEGIN
        --Writing the program output to output file
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               'Operating Unit'
            || '|'
            || 'Ship From Org'
            || '|'
            || 'Brand'
            || '|'
            || 'Division'                              ---Added for change 1.9
            || '|'                                      --Added for change 1.9
            || 'Department'                             --Added for change 1.9
            || '|'                                      --Added for change 1.9
            || 'Style'
            || '|'
            || 'Style Description'                      --Added for change 1.9
            || '|'                                      --Added for change 1.9
            || 'Color'
            || '|'
            || 'Color Description'                      --Added for change 1.9
            || '|'                                      --Added for change 1.9
            || 'SKU'
            || '|'
            || 'Item Description'                       --Added for change 1.9
            || '|'                                      --Added for change 1.9
            || 'SO#'
            || '|'
            --Start changes for 1.7
            || 'Customer PO#'
            || '|'
            --End changes for 1.7
            || 'Order Type'                                    --Added for 1.6
            || '|'                                             --Added for 1.6
            || 'SO Line#'
            || '|'
            || 'Customer Name'
            || '|'
            -- START : Added for 1.4.
            || 'Account Number'
            || '|'
            || 'Salesrep Name'
            || '|'
            -- END : Added for 1.4.
            || 'Demand Class'
            || '|'
            || 'Ordered Date'                           --Added for change 1.9
            || '|'
            || 'Request Date'
            || '|'
            || 'Schedule Ship Date'
            || '|'
            || 'New Schedule Ship Date'
            || '|'
            || 'Latest Acceptable Date'
            --|| '|'
            --|| 'Override ATP Flag'  --Commented for change 1.3
            || '|'
            || 'Cancel Date'
            || '|'
            || 'Quantity'
            || '|'
            || 'Status'
            || '|'
            || 'Error Message'
            || '|'
            || 'Next Supply Date'                  --Added for code change 1.2
            --Start changes for 1.7
            || '|'
            || 'Calloff Order (Yes/No)'
            || '|'
            || 'Bulk Order#'
            || '|'
            || 'Bulk Customer PO#'
            || '|'
            || 'Bulk Line#'
            || '|'
            || 'Bulk Request Date'
            || '|'
            || 'Bulk Schedule Ship Date'
            || '|'
            || 'Bulk Latest Acceptable Date');

        --End changes for 1.7

        FOR audit_rec IN audit_cur
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   audit_rec.operating_unit
                || '|'
                || audit_rec.ship_from_org
                || '|'
                || audit_rec.brand
                || '|'
                || audit_rec.division                   --Added for change 1.9
                || '|'                                  --Added for change 1.9
                || audit_rec.department                 --Added for change 1.9
                || '|'                                  --Added for change 1.9
                || audit_rec.style
                || '|'
                || audit_rec.style_desc                 --Added for change 1.9
                || '|'                                  --Added for change 1.9
                || audit_rec.color
                || '|'
                || audit_rec.color_desc                 --Added for change 1.9
                || '|'                                  --Added for change 1.9
                || audit_rec.sku
                || '|'
                || audit_rec.item_description           --Added for change 1.9
                || '|'                                  --Added for change 1.9
                || audit_rec.order_number
                || '|'
                --Start changes for 1.7
                || audit_rec.cust_po_number
                || '|'
                --End changes for 1.7
                || audit_rec.order_type                       --Added for 1.6.
                || '|'                                        --Added for 1.6.
                || audit_rec.line_num
                || '|'
                || audit_rec.customer_name
                || '|'
                -- START : Added for 1.4.
                || audit_rec.account_number
                || '|'
                || audit_rec.salesrep_name
                || '|'
                -- END : Added for 1.4.
                || audit_rec.demand_class_code
                || '|'
                || audit_rec.ordered_date               --Added for change 1.9
                || '|'
                || audit_rec.request_date
                || '|'
                || audit_rec.schedule_ship_date
                || '|'
                || audit_rec.new_schedule_ship_date_der
                || '|'
                || audit_rec.latest_acceptable_date
                --|| '|'
                --|| audit_rec.override_atp_flag
                || '|'
                || audit_rec.cancel_date
                || '|'
                || audit_rec.ordered_quantity
                || '|'
                || audit_rec.status_desc
                || '|'
                || audit_rec.error_message
                || '|'
                || audit_rec.next_supply_date      --Added for code change 1.2
                --Start changes for 1.7
                || '|'
                || audit_rec.calloff_order
                || '|'
                || audit_rec.bulk_order_number
                || '|'
                || audit_rec.bulk_po
                || '|'
                || audit_rec.bulk_line_num
                || '|'
                || audit_rec.bulk_rsd
                || '|'
                || audit_rec.bulk_ssd
                || '|'
                || audit_rec.bulk_lad);
        --End changes for 1.7
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in writing Audit Report -> ' || SQLERRM);
    END audit_report;

    --Procedure to write messages to Log
    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (32000);
    BEGIN
        lv_msg   := pv_msg;

        --Writing into Log file if the program is submitted from Front end application
        IF apps.fnd_global.user_id <> -1
        THEN
            fnd_file.put_line (fnd_file.LOG, lv_msg);
        ELSE
            DBMS_OUTPUT.put_line (lv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            raise_application_error (
                -20020,
                'Error in Procedure write_log -> ' || SQLERRM);
    END write_log;

    --Added email_output procedure for change 1.3
    PROCEDURE email_output (pn_batch_id IN NUMBER, pn_organization_id IN NUMBER, pv_brand IN VARCHAR2)
    IS
        CURSOR audit_cur IS
              SELECT hou.name operating_unit,
                     mp.organization_code ship_from_org,
                     itm.brand,
                     itm.division,                      --Added for change 1.9
                     itm.department,                    --Added for change 1.9
                     itm.style_number style,
                     itm.style_desc,                    --Added for change 1.9
                     itm.color_code color,
                     itm.color_desc,                    --Added for change 1.9
                     xna.sku,
                     itm.item_description,              --Added for change 1.9
                     --xna.order_number,
                     ooha.order_number,
                     ooha.ordered_date,                 --Added for change 1.9
                     oota.name order_type,                    --Added for 1.6.
                     xna.line_num,
                     hp.party_name customer_name,
                     -- START : Added for 1.4.
                     hca.account_number,
                     (SELECT jrre.resource_name
                        FROM oe_order_lines_all ol, jtf_rs_salesreps jrs, jtf_rs_resource_extns_tl jrre
                       WHERE     jrs.resource_id = jrre.resource_id
                             AND jrre.language = 'US'
                             AND jrs.salesrep_id = ol.salesrep_id
                             AND ol.line_id = xna.line_id
                             AND jrs.org_id = ol.org_id --    Added by Infosys for 1.5.
                                                       ) salesrep_name,
                     -- END : Added for 1.4.
                     xna.demand_class_code,
                     xna.request_date,
                     xna.schedule_ship_date,
                     -- Start changes for 2.0
                     -- DECODE (xna.status, 'S', new_schedule_ship_date)
                     CASE
                         WHEN xna.status IN ('S', 'BUL-SCH-S')
                         THEN
                             oola.schedule_ship_date
                     END -- End changes for 2.0
                         new_schedule_ship_date_der,
                     xna.latest_acceptable_date,
                     xna.override_atp_flag,
                     xna.cancel_date,
                     -- Start changes for 2.0
                     -- xna.ordered_quantity,
                     oola.ordered_quantity,
                     -- End changes for 2.0
                     DECODE (xna.status,
                             --'S', 'Success', --Commenting the code for change 1.2
                             'S', 'Rescheduled', --Added the code for change 1.2
                             --'E' ,'Fail', --Commenting the code for change 1.2
                             'E', 'Rescheduling Failed', --Added the code for change 1.2
                             'X', 'Unscheduling Failed', --Added this code for change 1.2
                             'Z', 'Unscheduled', --Added this for code change 1.2
                             'U', 'API Unhandled Exception',
                             -- Start changes for 2.0
                             'BUL-SCH-S', 'Bulk Scheduled',
                             'BUL-ATP-F', 'Bulk ATP Check Failed',
                             'BUL-SPL-F', 'Bulk Split Failed',
                             'BUL-SCH-F', 'Bulk Schedule Failed',
                             -- End changes for 2.0
                             'N', 'Not Processed',
                             'Error') status_desc,
                     xna.error_message,
                     LTRIM (SUBSTR (xna.error_message,
                                      INSTR (xna.error_message, ':', 1,
                                             2)
                                    + 1)) next_supply_date, --Added for code change 1.2
                     --Start changes for 1.7
                     ooha.cust_po_number,
                     NVL2 (xobot.bulk_order_number, 'Yes', 'No') calloff_order,
                     xobot.bulk_order_number,
                     xobot.bulk_cust_po_number bulk_po,
                     NVL2 (
                         xobot.bulk_order_number,
                            xobot.bulk_line_number
                         || '.'
                         || xobot.bulk_shipment_number,
                         NULL) bulk_line_num,
                     (SELECT request_date
                        FROM oe_order_lines_all
                       WHERE line_id = xobot.bulk_line_id) bulk_rsd,
                     (SELECT schedule_ship_date
                        FROM oe_order_lines_all
                       WHERE line_id = xobot.bulk_line_id) bulk_ssd,
                     (SELECT latest_acceptable_date
                        FROM oe_order_lines_all
                       WHERE line_id = xobot.bulk_line_id) bulk_lad
                --End changes for 1.7
                FROM xxdo.xxd_neg_atp_items_resched_stg xna, apps.hz_cust_accounts hca, apps.hz_parties hp,
                     apps.xxd_common_items_v itm, apps.hr_operating_units hou, apps.mtl_parameters mp,
                     apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, --Added for 1.7
                                                                                   apps.xxd_ont_bulk_orders_t xobot, --Added for 1.7
                     apps.oe_transaction_types_tl oota        --Added for 1.6.
               WHERE     1 = 1
                     AND ooha.order_type_id = oota.transaction_type_id --Added for 1.6.
                     AND oota.language = USERENV ('LANG')     --Added for 1.6.
                     AND xna.batch_id = pn_batch_id
                     AND xna.ship_from_org_id = pn_organization_id
                     AND xna.brand = pv_brand           --Added for change 1.2
                     --AND  itm.brand = pv_brand  --Commented for change 1.2
                     AND xna.customer_id = hca.cust_account_id
                     AND hca.status = 'A'
                     AND hca.party_id = hp.party_id
                     AND hp.status = 'A'
                     AND xna.inventory_item_id = itm.inventory_item_id
                     AND xna.ship_from_org_id = itm.organization_id
                     AND xna.org_id = hou.organization_id
                     AND xna.ship_from_org_id = mp.organization_id
                     AND xna.header_id = ooha.header_id
                     --Start changes for 1.7
                     AND xna.header_id = oola.header_id
                     AND xna.line_id = oola.line_id
                     AND oola.header_id = xobot.calloff_header_id(+)
                     AND oola.line_id = xobot.calloff_line_id(+)
                     AND xobot.link_type(+) = 'BULK_LINK'
            --End changes for 1.7
            --AND  xna.seq_no BETWEEN pn_from_seq_num
            --                  AND pn_to_seq_num
            ORDER BY xna.ship_from_org, xna.sku, xna.request_date,
                     xna.schedule_ship_date;

        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;
        lv_appl_inst_name    VARCHAR2 (25) := NULL;
        lv_email_lkp_type    VARCHAR2 (50) := 'XXD_NEG_ATP_RESCHEDULE_EMAIL';
        lv_inv_org_code      VARCHAR2 (3) := NULL;
        ln_ret_val           NUMBER := 0;
        lv_out_line          VARCHAR2 (1000);
        ln_counter           NUMBER := 0;
        ln_rec_cnt           NUMBER := 0;

        ex_no_sender         EXCEPTION;
        ex_no_recips         EXCEPTION;
    BEGIN
        SELECT COUNT (*)
          INTO ln_rec_cnt
          FROM xxdo.xxd_neg_atp_items_resched_stg stg
         WHERE     1 = 1
               AND stg.batch_id = pn_batch_id
               AND stg.ship_from_org_id = pn_organization_id
               AND stg.brand = pv_brand;

        IF apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER') IS NULL
        THEN
            RAISE ex_no_sender;
        END IF;

        --Getting the inventory organization code
        BEGIN
            SELECT organization_code
              INTO lv_inv_org_code
              FROM apps.mtl_parameters
             WHERE organization_id = pn_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                    'Unable to fetch inv_org_code in email_output procedure');
        END;

        --Getting the email recipients and assigning them to a table type variable
        lv_def_mail_recips   :=
            email_recipients (lv_email_lkp_type, lv_inv_org_code);

        IF lv_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        ELSE
            --Getting the instance name
            BEGIN
                SELECT applications_system_name
                  INTO lv_appl_inst_name
                  FROM apps.fnd_product_groups;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                        'Unable to fetch the File server name in email_output procedure');
            END;

            apps.do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), lv_def_mail_recips, 'Deckers Negative ATP Reschedule Program output for ' || lv_inv_org_code || ' and ' || pv_brand || ' on ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24MISS') || ' from ' || lv_appl_inst_name || ' instance'
                                                 , ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('--boundarystring',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                               ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                   'Total number of records for '
                || lv_inv_org_code
                || ' and '
                || pv_brand
                || ' = '
                || ln_rec_cnt,
                ln_ret_val);
            apps.do_mail_utils.send_mail_line ('', ln_ret_val);

            --Attach the file if there are any records
            IF ln_rec_cnt > 0
            THEN
                apps.do_mail_utils.send_mail_line ('', ln_ret_val);
                apps.do_mail_utils.send_mail_line (
                    'See attachment for report details.',
                    ln_ret_val);
                apps.do_mail_utils.send_mail_line ('', ln_ret_val);
                apps.do_mail_utils.send_mail_line ('--boundarystring',
                                                   ln_ret_val);
                apps.do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                                   ln_ret_val);
                apps.do_mail_utils.send_mail_line (
                       'Content-Disposition: attachment; filename="Deckers Negative ATP Reschedule Program output for '
                    || lv_inv_org_code
                    || ' and '
                    || pv_brand
                    || ' on '
                    || TO_CHAR (SYSDATE, 'MMDDYYYY HH24MISS')
                    || '.xls"',
                    ln_ret_val);
                apps.do_mail_utils.send_mail_line ('', ln_ret_val);
                --Start changes for 1.7
                /*apps.do_mail_utils.send_mail_line (
                      'OPERATING_UNIT'
                   || CHR (9)
                   || 'SHIP_FROM_ORG'
                   || CHR (9)
                   || 'BRAND'
                   || CHR (9)
                   || 'STYLE'
                   || CHR (9)
                   || 'COLOR'
                   || CHR (9)
                   || 'SKU'
                   || CHR (9)
                   || 'SO#'
                   || CHR (9)
                   || 'ORDER TYPE'                                --Added for 1.6.
                   || CHR (9)                                     --Added for 1.6.
                   || 'SO_LINE#'
                   || CHR (9)
                   || 'CUSTOMER_NAME'
                   || CHR (9)
                   -- START : Added for 1.4.
                   || 'ACCOUNT_NUMBER'
                   || CHR (9)
                   || 'SALESREP_NAME'
                   || CHR (9)
                   -- END : Added for 1.4.
                   || 'DEMAND_CLASS'
                   || CHR (9)
                   || 'REQUEST_DATE'
                   || CHR (9)
                   || 'SCHEDULE_SHIP_DATE'
                   || CHR (9)
                   || 'NEW_SCHEDULE_SHIP_DATE'
                   || CHR (9)
                   || 'LATEST_ACCEPTABLE_DATE'
                   || CHR (9)
                   || 'CANCEL_DATE'
                   || CHR (9)
                   || 'QUANTITY'
                   || CHR (9)
                   || 'STATUS'
                   || CHR (9)
                   || 'ERROR_MESSAGE'
                   || CHR (9)
                   || 'NEXT_SUPPLY_DATE'
                   || CHR (9),
                   ln_ret_val);*/

                apps.do_mail_utils.send_mail_line (
                       'Operating Unit'
                    || CHR (9)
                    || 'Ship From Org'
                    || CHR (9)
                    || 'Brand'
                    || CHR (9)
                    || 'Division'                       --Added for change 1.9
                    || CHR (9)                          --Added for change 1.9
                    || 'Department'                     --Added for change 1.9
                    || CHR (9)                          --Added for change 1.9
                    || 'Style'
                    || CHR (9)
                    || 'Style Description'              --Added for change 1.9
                    || CHR (9)                          --Added for change 1.9
                    || 'Color'
                    || CHR (9)
                    || 'Color Description'              --Added for change 1.9
                    || CHR (9)                          --Added for change 1.9
                    || 'SKU'
                    || CHR (9)
                    || 'Item Description'               --Added for change 1.9
                    || CHR (9)                          --Added for change 1.9
                    || 'SO#'
                    || CHR (9)
                    || 'Customer PO#'
                    || CHR (9)
                    || 'Order Type'
                    || CHR (9)
                    || 'SO Line#'
                    || CHR (9)
                    || 'Customer Name'
                    || CHR (9)
                    || 'Account Number'
                    || CHR (9)
                    || 'Salesrep Name'
                    || CHR (9)
                    || 'Demand Class'
                    || CHR (9)
                    || 'Ordered Date'                   --Added for change 1.9
                    || CHR (9)
                    || 'Request Date'
                    || CHR (9)
                    || 'Schedule Ship Date'
                    || CHR (9)
                    || 'New Schedule Ship Date'
                    || CHR (9)
                    || 'Latest Acceptable Date'
                    || CHR (9)
                    || 'Cancel Date'
                    || CHR (9)
                    || 'Quantity'
                    || CHR (9)
                    || 'Status'
                    || CHR (9)
                    || 'Error Message'
                    || CHR (9)
                    || 'Next Supply Date'
                    || CHR (9)
                    || 'Calloff Order (Yes/No)'
                    || CHR (9)
                    || 'Bulk Order#'
                    || CHR (9)
                    || 'Bulk Customer PO#'
                    || CHR (9)
                    || 'Bulk Line#'
                    || CHR (9)
                    || 'Bulk Request Date'
                    || CHR (9)
                    || 'Bulk Schedule Ship Date'
                    || CHR (9)
                    || 'Bulk Latest Acceptable Date'
                    || CHR (9),
                    ln_ret_val);

                --End changes for 1.7

                FOR audit_rec IN audit_cur
                LOOP
                    lv_out_line   := NULL;
                    lv_out_line   :=
                           audit_rec.operating_unit
                        || CHR (9)
                        || audit_rec.ship_from_org
                        || CHR (9)
                        || audit_rec.brand
                        || CHR (9)
                        || audit_rec.division           --Added for change 1.9
                        || CHR (9)                      --Added for change 1.9
                        || audit_rec.department         --Added for change 1.9
                        || CHR (9)                      --Added for change 1.9
                        || audit_rec.style
                        || CHR (9)
                        || audit_rec.style_desc         --Added for change 1.9
                        || CHR (9)                      --Added for change 1.9
                        || audit_rec.color
                        || CHR (9)
                        || audit_rec.color_desc         --Added for change 1.9
                        || CHR (9)                      --Added for change 1.9
                        || audit_rec.sku
                        || CHR (9)
                        || audit_rec.item_description   --Added for change 1.9
                        || CHR (9)                      --Added for change 1.9
                        || audit_rec.order_number
                        || CHR (9)
                        --Start changes for 1.7
                        || audit_rec.cust_po_number
                        || CHR (9)
                        --End changes for 1.7
                        || audit_rec.order_type               --Added for 1.6.
                        || CHR (9)                            --Added for 1.6.
                        || audit_rec.line_num
                        || CHR (9)
                        || audit_rec.customer_name
                        || CHR (9)
                        -- START : Added for 1.4.
                        || audit_rec.account_number
                        || CHR (9)
                        || audit_rec.salesrep_name
                        || CHR (9)
                        -- END : Added for 1.4.
                        || audit_rec.demand_class_code
                        || CHR (9)
                        || audit_rec.ordered_date       --Added for change 1.9
                        || CHR (9)
                        || audit_rec.request_date
                        || CHR (9)
                        || audit_rec.schedule_ship_date
                        || CHR (9)
                        || audit_rec.new_schedule_ship_date_der
                        || CHR (9)
                        || audit_rec.latest_acceptable_date
                        || CHR (9)
                        || audit_rec.cancel_date
                        || CHR (9)
                        || audit_rec.ordered_quantity
                        || CHR (9)
                        || audit_rec.status_desc
                        || CHR (9)
                        || audit_rec.error_message
                        || CHR (9)
                        || audit_rec.next_supply_date
                        || CHR (9)
                        --Start changes for 1.7
                        || audit_rec.calloff_order
                        || CHR (9)
                        || audit_rec.bulk_order_number
                        || CHR (9)
                        || audit_rec.bulk_po
                        || CHR (9)
                        || audit_rec.bulk_line_num
                        || CHR (9)
                        || audit_rec.bulk_rsd
                        || CHR (9)
                        || audit_rec.bulk_ssd
                        || CHR (9)
                        || audit_rec.bulk_lad
                        || CHR (9);
                    --Start changes for 1.7

                    apps.do_mail_utils.send_mail_line (lv_out_line,
                                                       ln_ret_val);
                    ln_counter    := ln_counter + 1;
                END LOOP;

                apps.do_mail_utils.send_mail_close (ln_ret_val);
            END IF;
        END IF;
    EXCEPTION
        WHEN ex_no_sender
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log (
                'ex_no_sender : There is no sender configured. Check the profile value DO: Default Alert Sender');
        WHEN ex_no_recips
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log (
                'ex_no_recips : There are no recipients configured to receive the email. Check lookup type XXD_NEG_ATP_RESCHEDULE_EMAIL');
        WHEN OTHERS
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            write_log ('Error in Procedure email_ouput -> ' || SQLERRM);
    END email_output;

    --Added email_recipients function for change 1.3
    --This function returns the email ID's listed for the given parameters
    FUNCTION email_recipients (pv_lookup_type   IN VARCHAR2,
                               pv_inv_org       IN VARCHAR2)
        RETURN apps.do_mail_utils.tbl_recips
    IS
        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;
        lv_appl_inst_name    VARCHAR2 (25) := NULL;            --Added for 1.7

        CURSOR recipients_cur IS
            SELECT lookup_code, meaning, description email_id,
                   tag
              FROM apps.fnd_lookup_values
             WHERE     lookup_type = pv_lookup_type
                   AND tag = pv_inv_org
                   AND enabled_flag = 'Y'
                   AND language = USERENV ('LANG')
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);
    BEGIN
        lv_def_mail_recips.delete;

        --Start changes for 1.7
        SELECT applications_system_name
          INTO lv_appl_inst_name
          FROM apps.fnd_product_groups;

        IF lv_appl_inst_name = 'EBSPROD'
        THEN
            --End changes for 1.7
            FOR recipients_rec IN recipients_cur
            LOOP
                lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                    recipients_rec.email_id;
            END LOOP;
        --Start changes for 1.7
        ELSE
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                'Batch.OM@deckers.com';
        END IF;

        --End changes for 1.7

        RETURN lv_def_mail_recips;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                'Batch.OM@deckers.com';
            RETURN lv_def_mail_recips;
    END email_recipients;

    --Start changes v2.2
    --This function returns the sort by date for the given order line id
    FUNCTION get_sort_by_date (pn_line_id IN NUMBER)
        RETURN DATE
    IS
        lv_blk_strng    oe_order_lines_all.global_attribute19%TYPE;
        lv_blk_buf      oe_order_lines_all.global_attribute19%TYPE;
        ld_ret_dte      DATE;
        ln_line_id      NUMBER;
        ln_count        NUMBER := 0;
        lb_error        BOOLEAN := FALSE;
        lv_qry_strng    VARCHAR2 (4000);
        --Start v1.3 changes
        ln_src_doc_id   NUMBER;
        ln_hdr_src_id   NUMBER;
    --End v1.3 changes

    BEGIN
        SELECT oola.global_attribute19, oola.split_from_line_id, oola.source_document_line_id, --v2.3
               ooha.order_source_id                                     --v2.3
          INTO lv_blk_strng, ln_line_id, ln_src_doc_id,                 --v2.3
                                                        ln_hdr_src_id   --v2.3
          FROM oe_order_lines_all oola, oe_order_headers_all ooha       --v2.3
         WHERE line_id = pn_line_id AND oola.header_id = ooha.header_id; --v2.3

        IF lv_blk_strng IS NOT NULL
        THEN
            WHILE INSTR (lv_blk_strng, ';') > 0
            LOOP
                lv_blk_buf   :=
                    SUBSTR (lv_blk_strng, 1, INSTR (lv_blk_strng, ';') - 1);
                lv_blk_strng   :=
                    SUBSTR (lv_blk_strng, INSTR (lv_blk_strng, ';') + 1);

                BEGIN
                    ln_line_id   :=
                        TO_NUMBER (
                            SUBSTR (lv_blk_buf,
                                    1,
                                    INSTR (lv_blk_buf, '-') - 1));
                    ln_count   := ln_count + 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lb_error   := TRUE;
                END;

                IF NOT lb_error
                THEN
                    IF ln_count = 1
                    THEN
                        lv_qry_strng   := TO_CHAR (ln_line_id);
                    ELSE
                        lv_qry_strng   :=
                            SUBSTR (
                                (lv_qry_strng || ', ' || TO_CHAR (ln_line_id)),
                                1,
                                3998);
                    END IF;                                     --end ln_count
                END IF;                                             --lb_error
            END LOOP;                                         --end while loop
        ELSIF ln_line_id IS NOT NULL
        THEN
            lv_qry_strng   := TO_CHAR (ln_line_id);
        --Start v1.3 changes
        ELSIF ln_hdr_src_id = 2 AND ln_src_doc_id IS NOT NULL
        THEN                                                      --copy lines
            lv_qry_strng   := TO_CHAR (ln_src_doc_id);
        --End v1.3 changes
        ELSE
            lv_qry_strng   := TO_CHAR (pn_line_id);
        END IF;                                                 --lv_blk_strng

        lv_qry_strng   := '(' || lv_qry_strng || ')';


        EXECUTE IMMEDIATE 'SELECT MIN(creation_date)
							 FROM oe_order_lines_all
							WHERE line_id IN ' || lv_qry_strng
            INTO ld_ret_dte;

        RETURN ld_ret_dte;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in get_sort_by_date function: ' || SQLERRM);
            RETURN ld_ret_dte;
    END get_sort_by_date;

    --End changes v2.2
    --Added below procedure purge_stg_data for change 2.4
    PROCEDURE purge_stg_data (errbuf OUT VARCHAR2, retcode OUT VARCHAR2)
    IS
        ln_retention_days   NUMBER := 30;
    BEGIN
        --insert data into arch tables
        BEGIN
            INSERT INTO xxdo.xxd_neg_atp_items_tmp_arch
                (SELECT * FROM xxdo.xxd_neg_atp_items_tmp);
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                       'Error while inserting into table xxdo.xxd_neg_atp_items_tmp_arch: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo.xxd_neg_atp_so_line_tmp_arch
                (SELECT * FROM xxdo.xxd_neg_atp_so_line_tmp);
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                       'Error while inserting into table xxdo.xxd_neg_atp_so_line_tmp_arch: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo.xxd_neg_atp_items_resched_arch
                (SELECT * FROM xxdo.xxd_neg_atp_items_resched_stg);
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                       'Error while inserting into table xxdo.xxd_neg_atp_items_resched_stg: '
                    || SQLERRM);
        END;

        COMMIT;

        --truncate tables after archiving
        BEGIN
            EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_neg_atp_items_tmp';
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                       'Error while truncating table xxdo.xxd_neg_atp_items_resched_stg: '
                    || SQLERRM);
        END;

        BEGIN
            EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_neg_atp_so_line_tmp';
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                       'Error while truncating table xxdo.xxd_neg_atp_so_line_tmp: '
                    || SQLERRM);
        END;

        BEGIN
            EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_neg_atp_items_resched_stg';
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                       'Error while truncating table xxdo.xxd_neg_atp_items_resched_stg: '
                    || SQLERRM);
        END;

        --purge archive tables
        BEGIN
            DELETE FROM
                xxdo.xxd_neg_atp_items_tmp_arch
                  WHERE TRUNC (creation_date) <
                        TRUNC (SYSDATE - NVL (ln_retention_days, 30));
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                       'Error while deleating record in table xxdo.xxd_neg_atp_items_tmp_arch: '
                    || SQLERRM);
        END;

        BEGIN
            DELETE FROM
                xxdo.xxd_neg_atp_so_line_tmp_arch
                  WHERE TRUNC (creation_date) <
                        TRUNC (SYSDATE - NVL (ln_retention_days, 30));
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                       'Error while deleating record in table xxdo.xxd_neg_atp_so_line_tmp_arch: '
                    || SQLERRM);
        END;

        BEGIN
            DELETE FROM
                xxdo.xxd_neg_atp_items_resched_arch
                  WHERE TRUNC (creation_date) <
                        TRUNC (SYSDATE - NVL (ln_retention_days, 30));
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log (
                       'Error while deleating record in table xxdo.xxd_neg_atp_items_resched_stg_arch: '
                    || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in purge_stg_data procedure: ' || SQLERRM);
    END purge_stg_data;
END xxdo_neg_atp_ord_resched_pkg1;
/
