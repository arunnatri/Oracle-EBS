--
-- XXD_ONT_SO_CORRECTION_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_SO_CORRECTION_PKG"
IS
    --  ###################################################################################################
    --  Author(s)       : Kranthi Bollam (Suneratech Consultant)
    --  System          : Oracle Applications
    --  Subsystem       : Order Management
    --  Change          : CCR0007644
    --  Schema          : APPS
    --  Purpose         : Syncing Latest Acceptable Date and Line cancel date with Header Cancel Date of
    --                      Sales Orders
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  15-Jan-2019     Kranthi Bollam      1.0     NA              Initial Version
    --
    --  ####################################################################################################

    --Global Variables
    gv_package_name      CONSTANT VARCHAR2 (30) := 'XXD_ONT_SO_CORRECTION_PKG';
    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    gn_conc_login_id     CONSTANT NUMBER := fnd_global.conc_login_id;
    gn_resp_id           CONSTANT NUMBER := fnd_profile.VALUE ('RESP_ID'); --fnd_global.resp_id;
    gn_resp_appl_id      CONSTANT NUMBER := fnd_profile.VALUE ('RESP_APPL_ID'); --fnd_global.resp_appl_id;
    gn_conc_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;
    gn_parent_req_id     CONSTANT NUMBER := fnd_global.conc_priority_request;
    gn_limit_rec         CONSTANT NUMBER := 100;
    gn_org_id            CONSTANT NUMBER := fnd_global.org_id; --MO_GLOBAL.GET_CURRENT_ORG_ID;
    gv_brand                      VARCHAR2 (20) := NULL;
    gv_order_type                 VARCHAR2 (20) := NULL;
    gv_order_source               VARCHAR2 (20) := NULL;
    gv_request_date_from          VARCHAR2 (30) := NULL;
    gv_request_date_to            VARCHAR2 (30) := NULL;
    gv_process                    VARCHAR2 (30) := NULL;
    gv_send_email                 VARCHAR2 (1) := NULL;

    --Procedure to print messages into either log or output files
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print time or not. Default is no.
    --PV_FILE       Print to LOG or OUTPUT file. Default write it to LOG file
    PROCEDURE msg (pv_msg    IN VARCHAR2,
                   pv_time   IN VARCHAR2 DEFAULT 'N',
                   pv_file   IN VARCHAR2 DEFAULT 'LOG')
    IS
        --Local Variables
        lv_proc_name    VARCHAR2 (30) := 'MSG';
        lv_msg          VARCHAR2 (32767) := NULL;
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF UPPER (pv_file) = 'OUT'
        THEN
            IF gn_user_id = -1
            THEN
                DBMS_OUTPUT.put_line (lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.output, lv_msg);
            END IF;
        ELSE
            IF gn_user_id = -1
            THEN
                DBMS_OUTPUT.put_line (lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, lv_msg);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'In When Others exception in '
                || gv_package_name
                || '.'
                || lv_proc_name
                || ' procedure. Error is: '
                || SQLERRM);
    END msg;

    --Procedure to Retain the data of last 10 runs and purge all other data
    PROCEDURE purge_data
    IS
        --Local Variables
        lv_proc_name   VARCHAR2 (30) := 'SYNC_CANCEL_DATE';
        lv_error_msg   VARCHAR2 (2000) := NULL;
    BEGIN
        DELETE FROM
            xxdo.xxd_ont_so_correction_t
              WHERE     1 = 1
                    AND request_id IN
                            (SELECT request_id
                               FROM (SELECT request_id, RANK () OVER (ORDER BY request_id DESC) req_id_rank
                                       FROM (  SELECT request_id
                                                 FROM xxdo.xxd_ont_so_correction_t
                                             GROUP BY request_id) xx)
                              WHERE req_id_rank > 10);

        msg ('Number of Records Deleted/Purged: ' || SQL%ROWCOUNT, 'Y');
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
    END purge_data;

    PROCEDURE get_sales_orders (pn_ret_code   OUT NUMBER,
                                pv_ret_msg    OUT VARCHAR2)
    IS
        --Local Variables
        lv_proc_name             VARCHAR2 (30) := 'GET_SALES_ORDERS';
        lv_error_msg             VARCHAR2 (2000) := NULL;
        lv_so_cur_stmt           VARCHAR2 (32627) := NULL;
        lv_so_select_clause      VARCHAR2 (10000) := NULL;
        lv_so_from_clause        VARCHAR2 (5000) := NULL;
        lv_so_where_clause       VARCHAR2 (10000) := NULL;
        lv_so_brand_cond         VARCHAR2 (5000) := NULL;
        lv_so_ord_type_cond      VARCHAR2 (5000) := NULL;
        lv_so_ord_src_cond       VARCHAR2 (5000) := NULL;
        lv_so_req_dt_cond        VARCHAR2 (5000) := NULL;
        lv_process_cond          VARCHAR2 (5000) := NULL;
        ln_ord_src_exists_cnt    NUMBER := 0;
        ln_ord_type_exists_cnt   NUMBER := 0;
        lv_request_date_from     VARCHAR2 (30) := NULL;
        lv_request_date_to       VARCHAR2 (30) := NULL;

        TYPE ord_line_rec_type IS RECORD
        (
            org_id                    NUMBER,
            operating_unit            VARCHAR2 (240),
            brand                     VARCHAR2 (20),
            ship_from_org_id          NUMBER,
            ship_from_org             VARCHAR2 (3),
            division                  VARCHAR2 (50),
            department                VARCHAR2 (50),
            style                     VARCHAR2 (30),
            color                     VARCHAR2 (30),
            item_size                 VARCHAR2 (30),
            sku                       VARCHAR2 (50),
            inventory_item_id         NUMBER,
            order_number              NUMBER,
            header_id                 NUMBER,
            ordered_date              DATE,
            customer_name             VARCHAR2 (360),
            customer_number           VARCHAR2 (30),
            customer_id               NUMBER,
            order_source_id           NUMBER,
            order_source              VARCHAR2 (240),
            order_type_id             NUMBER,
            order_type                VARCHAR2 (30),
            customer_po_number        VARCHAR2 (50),
            line_number               VARCHAR2 (10),
            line_id                   NUMBER,
            ordered_quantity          NUMBER,
            demand_class              VARCHAR2 (30),
            header_cancel_date        DATE,
            line_cancel_date          DATE,
            latest_acceptable_date    DATE,
            override_atp_flag         VARCHAR2 (1),
            request_date              DATE,
            schedule_ship_date        DATE,
            new_schedule_ship_date    DATE,
            status                    VARCHAR2 (30),
            error_message             VARCHAR2 (4000),
            next_supply_date          DATE,
            cancel_date_updated       VARCHAR2 (3)  --POSSIBLE VALUES --YES/NO
        );

        TYPE ord_line_type IS TABLE OF ord_line_rec_type
            INDEX BY BINARY_INTEGER;

        ord_line_rec             ord_line_type;

        TYPE ord_line_cur_typ IS REF CURSOR;

        ord_line_cur             ord_line_cur_typ;
    BEGIN
        msg ('START - Get Sales Orders Procedure', 'Y');
        lv_so_select_clause   :=
            'SELECT ooha.org_id
      ,hou.name operating_unit
      ,ooha.attribute5 brand
      ,oola.ship_from_org_id
      ,mp.organization_code ship_from_org
      ,msi.division
      ,msi.department
      ,msi.style_number style
      ,msi.color_code color
      ,msi.item_size
      ,oola.ordered_item sku
      ,oola.inventory_item_id
      ,ooha.order_number
      ,ooha.header_id
      ,ooha.ordered_date
      ,REPLACE(hp.party_name, CHR(9), '''') customer_name
      ,hca.account_number customer_number
      ,ooha.sold_to_org_id customer_id
      ,ooha.order_source_id
      ,oos.name order_source
      ,ooha.order_type_id
      ,ottl.name order_type
      ,REPLACE(ooha.cust_po_number, CHR(9), '''') customer_po_number
      ,oola.line_number||''.''||oola.shipment_number line_number
      ,oola.line_id
      ,oola.ordered_quantity
      ,oola.demand_class_code demand_class
      ,TRUNC(TO_DATE(ooha.attribute1, ''RRRR/MM/DD HH24:MI:SS'')) header_cancel_date
      ,TRUNC(TO_DATE(oola.attribute1, ''RRRR/MM/DD HH24:MI:SS'')) line_cancel_date
      ,oola.latest_acceptable_date
      ,oola.override_atp_date_code override_atp_flag
      ,oola.request_date
      ,oola.schedule_ship_date
      ,NULL new_schedule_ship_date
      ,''NEW'' status
      ,NULL error_message
      ,NULL next_supply_date
      ,NULL cancel_date_updated
  ';

        lv_so_from_clause   := 'FROM apps.oe_order_headers_all  ooha
      ,apps.hr_operating_units hou
      ,apps.oe_transaction_types_tl ottl
      ,apps.oe_order_sources oos
      ,apps.hz_cust_accounts hca
      ,apps.hz_parties hp
      ,apps.oe_order_lines_all oola
      ,apps.xxd_common_items_v msi
      ,apps.mtl_parameters mp
 ';
        lv_so_where_clause   :=
               'WHERE 1=1
   AND ooha.open_flag = ''Y''
   AND ooha.flow_status_code <> ''ENTERED''
   AND ooha.org_id = '
            || gn_org_id
            || '
   AND ooha.org_id = hou.organization_id
   AND ooha.order_type_id = ottl.transaction_type_id
   AND ottl.language = USERENV(''LANG'')
   AND ooha.order_source_id = oos.order_source_id
   AND ooha.sold_to_org_id = hca.cust_account_id
   AND hca.party_id = hp.party_id
   AND ooha.header_id = oola.header_id
   AND oola.open_flag = ''Y''
   AND oola.line_category_code = ''ORDER''
   AND oola.flow_status_code NOT IN (''ENTERED'', ''CLOSED'', ''CANCELLED'',''INVOICED'', ''SHIPPED'', ''FULFILLED'', ''INVOICE_HOLD'', ''INVOICE_NOT_APPLICABLE'')
   --There should not be any reservations on the line
   AND NOT EXISTS (SELECT 1
                    FROM apps.mtl_reservations mr
                   WHERE mr.demand_source_line_id = oola.line_id)
   --Delivery Should not be be in these statuses(C=Shipped D=Cancelled N=Not Ready For Release S=Released to Warehouse X=Not Applicable Y=Staged)
   AND NOT EXISTS (SELECT 1
                     FROM apps.wsh_delivery_details wdd
                    WHERE wdd.source_line_id = oola.line_id
                      AND wdd.source_code = ''OE''
                      AND NVL(wdd.released_status, ''R'') IN (''C'', ''D'', ''N'', ''S'', ''X'', ''Y''))
   AND oola.ship_from_org_id = msi.organization_id
   AND oola.inventory_item_id = msi.inventory_item_id
   AND oola.ship_from_org_id = mp.organization_id
   ';

        --Brand Condition
        IF gv_brand = 'ALL'
        THEN
            lv_so_brand_cond   := 'AND 1=1
            ';
        ELSE
            lv_so_brand_cond   :=
                'AND ooha.attribute5 = ''' || gv_brand || '''
            ';
        END IF;

        --Order Type Exclusion Condition
        IF gv_order_type = 'NONE'
        THEN
            lv_so_ord_type_cond   := 'AND 1=1
            ';
        ELSE
            --Check if any order types are defined for exclusion
            SELECT COUNT (1)
              INTO ln_ord_type_exists_cnt
              FROM apps.fnd_lookup_values flv_os
             WHERE     flv_os.lookup_type = 'XXD_ONT_SO_CORR_ORD_TYPE_EXC'
                   AND flv_os.enabled_flag = 'Y'
                   AND flv_os.language = 'US'
                   AND SYSDATE BETWEEN NVL (flv_os.start_date_active,
                                            SYSDATE)
                                   AND NVL (flv_os.end_date_active,
                                            SYSDATE + 1);

            IF ln_ord_type_exists_cnt > 0
            THEN
                lv_so_ord_type_cond   :=
                    'AND ooha.order_type_id NOT IN (SELECT TO_NUMBER(flv_ot.attribute1)
                                                   FROM apps.fnd_lookup_values flv_ot
                                                  WHERE flv_ot.lookup_type = ''XXD_ONT_SO_CORR_ORD_TYPE_EXC''
                                                    AND flv_ot.enabled_flag = ''Y''
                                                    AND flv_ot.language = ''US''
                                                    AND SYSDATE BETWEEN NVL(flv_ot.start_date_active,SYSDATE) AND NVL(flv_ot.end_date_active, SYSDATE+1))
                ';
            ELSE
                lv_so_ord_type_cond   := 'AND 1=1
                ';
            END IF;
        END IF;

        --        msg('lv_so_ord_type_cond:'||lv_so_ord_type_cond);

        --Order Source Exclusion Condition
        IF gv_order_source = 'NONE'
        THEN
            lv_so_ord_src_cond   := 'AND 1=1
            ';
        ELSE
            --Check if any order sources are defined for exclusion
            SELECT COUNT (1)
              INTO ln_ord_src_exists_cnt
              FROM apps.fnd_lookup_values flv_os
             WHERE     flv_os.lookup_type = 'XXD_ONT_SO_CORR_ORD_SOURCE_EXC'
                   AND flv_os.enabled_flag = 'Y'
                   AND flv_os.language = 'US'
                   AND SYSDATE BETWEEN NVL (flv_os.start_date_active,
                                            SYSDATE)
                                   AND NVL (flv_os.end_date_active,
                                            SYSDATE + 1);

            IF ln_ord_src_exists_cnt > 0
            THEN
                lv_so_ord_src_cond   :=
                    'AND ooha.order_source_id NOT IN (SELECT TO_NUMBER(flv_os.attribute1)
                                                   FROM apps.fnd_lookup_values flv_os
                                                  WHERE flv_os.lookup_type = ''XXD_ONT_SO_CORR_ORD_SOURCE_EXC''
                                                    AND flv_os.enabled_flag = ''Y''
                                                    AND flv_os.language = ''US''
                                                    AND SYSDATE BETWEEN NVL(flv_os.start_date_active, SYSDATE) AND NVL(flv_os.end_date_active, SYSDATE+1))
                ';
            ELSE
                lv_so_ord_src_cond   := 'AND 1=1
                ';
            END IF;
        END IF;

        --        msg('lv_so_ord_src_cond:'||lv_so_ord_src_cond);
        IF gv_request_date_from IS NULL OR gv_request_date_to IS NULL
        THEN
            lv_so_req_dt_cond   := 'AND 1=1
            ';
        ELSE
            lv_request_date_from   :=
                   TO_CHAR (
                       TO_DATE (gv_request_date_from,
                                'RRRR/MM/DD HH24:MI:SS'),
                       'RRRR/MM/DD')
                || ' 00:00:00';
            lv_request_date_to   :=
                   TO_CHAR (
                       TO_DATE (gv_request_date_to, 'RRRR/MM/DD HH24:MI:SS'),
                       'RRRR/MM/DD')
                || ' 23:59:59';
            --            lv_so_req_dt_cond := 'AND TRUNC(oola.request_date) BETWEEN TRUNC(TO_DATE('''||gv_request_date_from||''',''RRRR/MM/DD HH24:MI:SS'')) AND TRUNC(TO_DATE('''||gv_request_date_to||''',''RRRR/MM/DD HH24:MI:SS''))
            --            ';
            lv_so_req_dt_cond   :=
                   'AND oola.request_date BETWEEN TO_DATE('''
                || lv_request_date_from
                || ''',''RRRR/MM/DD HH24:MI:SS'') AND TO_DATE('''
                || lv_request_date_to
                || ''',''RRRR/MM/DD HH24:MI:SS'') 
            ';
        END IF;

        --        msg('lv_so_req_dt_cond:'||lv_so_req_dt_cond);

        --Process Condition
        IF gv_process = 'BOTH'
        THEN
            lv_process_cond   :=
                'AND ooha.attribute1 IS NOT NULL
            AND (
            --Header cancel date not equal to line cancel date condition
            TRUNC(TO_DATE(ooha.attribute1, ''RRRR/MM/DD HH24:MI:SS'')) <>  TRUNC(NVL(TO_DATE(oola.attribute1, ''RRRR/MM/DD HH24:MI:SS''), TO_DATE(ooha.attribute1, ''RRRR/MM/DD HH24:MI:SS'')+1))
            OR --Header cancel date not equal to latest acceptable date(LAD) condition
            TRUNC(TO_DATE(ooha.attribute1, ''RRRR/MM/DD HH24:MI:SS'')) <> TRUNC(NVL(oola.latest_acceptable_date, TO_DATE(ooha.attribute1, ''RRRR/MM/DD HH24:MI:SS'')+1))
            OR --Schedule Ship Date greater than LAD condition
            TRUNC(oola.schedule_ship_date) > TRUNC(oola.latest_acceptable_date)
            )';
        ELSIF gv_process = 'LAD_NOT_EQUAL_TO_CANCEL_DATE'
        THEN
            lv_process_cond   :=
                'AND ooha.attribute1 IS NOT NULL
            AND (
            --Header cancel date not equal to line cancel date condition
            TRUNC(TO_DATE(ooha.attribute1, ''RRRR/MM/DD HH24:MI:SS'')) <>  TRUNC(TO_DATE(oola.attribute1, ''RRRR/MM/DD HH24:MI:SS''))
            OR --Header cancel date not equal to latest acceptable date(LAD) condition
            TRUNC(TO_DATE(ooha.attribute1, ''RRRR/MM/DD HH24:MI:SS'')) <> TRUNC(NVL(oola.latest_acceptable_date, TO_DATE(ooha.attribute1, ''RRRR/MM/DD HH24:MI:SS'')+1))
            )';
        ELSIF gv_process = 'SSD_GREATER_THAN_LAD'
        THEN
            lv_process_cond   :=
                'AND (
            --Schedule Ship Date greater than Request Date condition
            TRUNC(oola.schedule_ship_date) > TRUNC(oola.latest_acceptable_date)
            )';
        END IF;

        --Building the Final Query
        lv_so_cur_stmt      :=
               lv_so_select_clause
            || lv_so_from_clause
            || lv_so_where_clause
            || lv_so_brand_cond
            || lv_so_ord_type_cond
            || lv_so_ord_src_cond
            || lv_so_req_dt_cond
            || lv_process_cond;
        msg ('-------------------------------------------------');
        msg ('Sales Orders Main Query(lv_so_cur_stmt)');
        msg ('-------------------------------------------------');
        msg (lv_so_cur_stmt || ';');
        msg ('-------------------------------------------------');

        --Opening the Sales Orders Cursor for the above sql statement(lv_so_cur_stmt)
        BEGIN
            OPEN ord_line_cur FOR lv_so_cur_stmt;

            FETCH ord_line_cur BULK COLLECT INTO ord_line_rec;

            CLOSE ord_line_cur;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_msg   :=
                    SUBSTR (
                           'Error while opening the cursor to get sales orders. So exiting the program and completing in WARNING. Error is:'
                        || SQLERRM,
                        1,
                        2000);
                msg (lv_error_msg);
                pn_ret_code   := gn_warning;
                pv_ret_msg    := lv_error_msg;
                RETURN;                                  --Exiting the program
        END;

        msg (
            'Count of Sales Orders Lines for Processing : ' || ord_line_rec.COUNT);

        IF ord_line_rec.COUNT > 0
        THEN
            --Bulk Insert of sales order lines into staging table
            FORALL i IN ord_line_rec.FIRST .. ord_line_rec.LAST
                INSERT INTO xxdo.xxd_ont_so_correction_t (
                                org_id,
                                operating_unit,
                                brand,
                                ship_from_org_id,
                                ship_from_org,
                                division,
                                department,
                                style,
                                color,
                                item_size,
                                sku,
                                inventory_item_id,
                                order_number,
                                header_id,
                                ordered_date,
                                customer_name,
                                customer_number,
                                customer_id,
                                order_source_id,
                                order_source,
                                order_type_id,
                                order_type,
                                customer_po_number,
                                line_number,
                                line_id,
                                ordered_quantity,
                                demand_class,
                                header_cancel_date,
                                line_cancel_date,
                                latest_acceptable_date,
                                override_atp_flag,
                                request_date,
                                schedule_ship_date,
                                new_schedule_ship_date,
                                status,
                                error_message,
                                next_supply_date,
                                cancel_date_updated,
                                request_id,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                last_update_login)
                     VALUES (ord_line_rec (i).org_id, ord_line_rec (i).operating_unit, ord_line_rec (i).brand, ord_line_rec (i).ship_from_org_id, ord_line_rec (i).ship_from_org, ord_line_rec (i).division, ord_line_rec (i).department, ord_line_rec (i).style, ord_line_rec (i).color, ord_line_rec (i).item_size, ord_line_rec (i).sku, ord_line_rec (i).inventory_item_id, ord_line_rec (i).order_number, ord_line_rec (i).header_id, ord_line_rec (i).ordered_date, ord_line_rec (i).customer_name, ord_line_rec (i).customer_number, ord_line_rec (i).customer_id, ord_line_rec (i).order_source_id, ord_line_rec (i).order_source, ord_line_rec (i).order_type_id, ord_line_rec (i).order_type, ord_line_rec (i).customer_po_number, ord_line_rec (i).line_number, ord_line_rec (i).line_id, ord_line_rec (i).ordered_quantity, ord_line_rec (i).demand_class, ord_line_rec (i).header_cancel_date, ord_line_rec (i).line_cancel_date, ord_line_rec (i).latest_acceptable_date, ord_line_rec (i).override_atp_flag, ord_line_rec (i).request_date, ord_line_rec (i).schedule_ship_date, ord_line_rec (i).new_schedule_ship_date, ord_line_rec (i).status, ord_line_rec (i).error_message, ord_line_rec (i).next_supply_date, ord_line_rec (i).cancel_date_updated, gn_conc_request_id --request_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             , SYSDATE --creation_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , gn_user_id --created_by
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , SYSDATE --last_update_date
                             , gn_user_id                    --last_updated_by
                                         , gn_login_id     --last_update_login
                                                      );

            COMMIT;
        ELSE
            lv_error_msg   :=
                'No sales order lines returned for the given parameters. So exiting the program and completing in WARNING.';
            msg (lv_error_msg);
            pn_ret_code   := gn_warning;
            pv_ret_msg    := lv_error_msg;
            RETURN;                                      --Exiting the program
        END IF;

        msg ('END - Get Sales Orders Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
    END get_sales_orders;

    --Procedure to sync line cancel date with header cancel date
    PROCEDURE sync_cancel_date
    IS
        --Local Variables
        lv_proc_name           VARCHAR2 (30) := 'SYNC_CANCEL_DATE';
        lv_error_msg           VARCHAR2 (2000) := NULL;
        ln_cancel_dt_upd_cnt   NUMBER := 0;

        CURSOR sync_can_dt_cur IS
            SELECT oola.attribute1 cancel_date, stg.header_cancel_date, stg.line_cancel_date,
                   stg.line_id, stg.schedule_ship_date, stg.latest_acceptable_date
              FROM xxdo.xxd_ont_so_correction_t stg, apps.oe_order_lines_all oola
             WHERE     1 = 1
                   AND stg.request_id = gn_conc_request_id
                   AND stg.status = 'NEW'                                --New
                   AND stg.header_cancel_date IS NOT NULL
                   AND stg.header_cancel_date >= TRUNC (SYSDATE) --Should be in Future
                   AND stg.header_cancel_date <>
                       NVL (stg.line_cancel_date, stg.header_cancel_date + 1)
                   AND stg.line_id = oola.line_id;
    BEGIN
        msg ('START - Sync Cancel Date Procedure', 'Y');

        FOR sync_can_dt_rec IN sync_can_dt_cur
        LOOP
            IF (sync_can_dt_rec.schedule_ship_date > sync_can_dt_rec.latest_acceptable_date AND sync_can_dt_rec.latest_acceptable_date = sync_can_dt_rec.header_cancel_date)
            THEN
                NULL;
            ELSE
                BEGIN
                    --Updating line cancel date
                    UPDATE apps.oe_order_lines_all oola
                       SET oola.attribute1 = TO_CHAR (sync_can_dt_rec.header_cancel_date, 'RRRR/MM/DD HH24:MI:SS') --Updating line cancel date
                                                                                                                  , oola.last_update_date = SYSDATE, oola.last_updated_by = gn_user_id,
                           oola.last_update_login = gn_login_id
                     WHERE 1 = 1 AND line_id = sync_can_dt_rec.line_id;

                    --Updating line cancel date Updated Field
                    UPDATE xxdo.xxd_ont_so_correction_t stg
                       SET stg.cancel_date_updated   = 'Yes' --Updating line cancel date Updated Field
                     WHERE     1 = 1
                           AND stg.line_id = sync_can_dt_rec.line_id
                           AND stg.request_id = gn_conc_request_id;

                    ln_cancel_dt_upd_cnt   := ln_cancel_dt_upd_cnt + 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_msg   :=
                            SUBSTR (
                                   'Error while update line cancel date for line id: '
                                || sync_can_dt_rec.line_id
                                || ' with header cancel date: '
                                || sync_can_dt_rec.header_cancel_date
                                || ' . Error is: '
                                || SQLERRM,
                                1,
                                2000);
                        msg (lv_error_msg);

                        UPDATE xxdo.xxd_ont_so_correction_t stg
                           SET stg.cancel_date_updated = 'No' --Updating line cancel date Updated Flag
                                                             , stg.last_update_date = SYSDATE
                         WHERE     1 = 1
                               AND stg.line_id = sync_can_dt_rec.line_id
                               AND stg.request_id = gn_conc_request_id;
                END;
            END IF;                                        --gv_process end if

            --Commit for every 1000 records
            IF MOD (sync_can_dt_cur%ROWCOUNT, 1000) = 0
            THEN
                COMMIT;
            END IF;
        END LOOP;

        COMMIT;
        msg (
               'Number of lines for which Cancel Date updated is:'
            || ln_cancel_dt_upd_cnt);
        msg ('END - Sync Cancel Date Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
    END sync_cancel_date;

    --Procudure to schedule or unschedule lines based on the action paramter
    PROCEDURE schedule_unschedule_lines (pn_request_id IN NUMBER, pn_header_id IN NUMBER, pn_line_id IN NUMBER, pv_action IN VARCHAR2, pd_header_cancel_date IN DATE, pd_latest_acceptable_date IN DATE
                                         , pd_schedule_ship_date IN DATE)
    IS
        --Local Variables
        lv_proc_name                   VARCHAR2 (30) := 'SCHEDULE_UNSCHEDULE_LINES';
        lv_error_msg                   VARCHAR2 (2000) := NULL;

        l_line_rec                     oe_order_pub.line_rec_type;
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
        l_return_status                VARCHAR2 (2000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (4000);

        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := fnd_api.g_false;
        p_return_values                VARCHAR2 (10) := fnd_api.g_false;
        p_action_commit                VARCHAR2 (10) := fnd_api.g_false;
        --x_return_status                 VARCHAR2(1);
        --x_msg_count                     NUMBER;
        --x_msg_data                      VARCHAR2(100);
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
        --        x_debug_file                    VARCHAR2(100);
        l_line_tbl_index               NUMBER;
        l_msg_index_out                NUMBER (10);
        --        x_errbuf                        VARCHAR2(200);
        --        x_retcode                       VARCHAR2(200);
        l_message_data                 VARCHAR2 (4000);
        lv_ret_sts                     VARCHAR2 (30);
        lv_lock_ret_status             VARCHAR2 (1);
        lv_next_supply_date            VARCHAR2 (20);
        ld_next_supply_date            DATE;
        ld_new_sched_ship_date         DATE;
        lv_next_sup_dt                 VARCHAR2 (2000) := NULL;
    BEGIN
        --Obtain lock for the line before calling API
        oe_line_util.lock_row (p_line_id         => pn_line_id,
                               p_x_line_rec      => l_line_rec,
                               x_return_status   => lv_lock_ret_status);

        --Proceed to API call only if lock row is successful
        IF lv_lock_ret_status = fnd_api.g_ret_sts_success
        THEN
            --Calling API
            lv_ret_sts                                := NULL;
            l_return_status                           := NULL;
            l_msg_data                                := NULL;
            l_message_data                            := NULL;
            lv_next_supply_date                       := NULL;
            ld_next_supply_date                       := NULL;
            ld_new_sched_ship_date                    := NULL;

            l_line_tbl_index                          := 1;
            l_line_tbl (l_line_tbl_index)             := l_line_rec; --oe_order_pub.g_miss_line_rec;
            l_line_tbl (l_line_tbl_index).operation   :=
                oe_globals.g_opr_update;
            --l_line_tbl(l_line_tbl_index).org_id := gn_org_id;
            l_line_tbl (l_line_tbl_index).header_id   := pn_header_id;
            l_line_tbl (l_line_tbl_index).line_id     := pn_line_id;

            --If pv_action is Unschedule then unschedule the line
            IF pv_action = 'UNSCHEDULE'
            THEN
                l_line_tbl (l_line_tbl_index).schedule_action_code   :=
                    oe_order_sch_util.oesch_act_unschedule; --'UNSCHEDULE'; --Unscheduling Action
            END IF;

            --If pv_action is Schedule then Schedule the line
            IF pv_action = 'SCHEDULE'
            THEN
                l_line_tbl (l_line_tbl_index).schedule_action_code   :=
                    oe_order_sch_util.oesch_act_schedule; --'SCHEDULE'; --Scheduling Action

                IF (gv_process <> 'SSD_GREATER_THAN_LAD' AND pd_header_cancel_date <> pd_latest_acceptable_date)
                THEN
                    l_line_tbl (l_line_tbl_index).latest_acceptable_date   :=
                        pd_header_cancel_date; --update LAD with header cancel date
                END IF;
            END IF;

            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_true,
                p_return_values            => fnd_api.g_true,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => l_return_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                x_header_rec               => l_header_rec_x,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => l_line_tbl_x,
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
                x_action_request_tbl       => l_action_request_tbl);

            IF l_return_status = fnd_api.g_ret_sts_success
            THEN
                COMMIT;
            --msg( 'Line ID:'||resched_ord_line_rec.line_id||' Status is :' ||l_return_status);
            ELSE
                --msg( 'Line ID:'||pn_line_id||' Status is :' ||l_return_status);
                FOR i IN 1 .. l_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                    , p_msg_index_out => l_msg_index_out);

                    l_message_data   :=
                        SUBSTR (l_message_data || l_msg_data, 1, 4000);
                --msg( 'Error: ' || l_msg_data);
                --msg( 'Error for Line ID:'||pn_line_id||'  is :' ||l_msg_data);
                END LOOP;

                ROLLBACK;
            END IF;

            IF pv_action = 'UNSCHEDULE'
            THEN
                IF l_return_status = 'S'
                THEN
                    lv_ret_sts   := 'UNSCHEDULED';
                ELSIF l_return_status = 'U'
                THEN
                    lv_ret_sts   := 'API_UNHANDLED_EXCEPTION';
                ELSE
                    lv_ret_sts   := 'UNSCHEDULING_FAILED';
                END IF;

                --Updating the staging table with status and other relevant information
                BEGIN
                    UPDATE xxdo.xxd_ont_so_correction_t xosc
                       SET xosc.status = lv_ret_sts,        --l_return_status,
                                                     xosc.error_message = l_message_data, xosc.last_update_date = SYSDATE
                     WHERE     1 = 1
                           AND xosc.line_id = pn_line_id
                           AND xosc.request_id = pn_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        msg (
                               'Error updating table for Unscheduling for request ID: '
                            || pn_request_id
                            || ' and line ID: '
                            || pn_line_id);
                END;
            ELSIF pv_action = 'SCHEDULE'
            THEN
                IF l_return_status = 'S'
                THEN
                    lv_ret_sts   := 'SCHEDULED';
                    ld_new_sched_ship_date   :=
                        l_line_tbl_x (l_line_tbl_index).schedule_ship_date;
                ELSIF l_return_status = 'U'
                THEN
                    lv_ret_sts   := 'API_UNHANDLED_EXCEPTION';
                ELSE
                    lv_ret_sts               := 'SCHEDULING_FAILED';

                    IF l_message_data IS NOT NULL
                    THEN
                        lv_next_sup_dt   :=
                            RTRIM (LTRIM (SUBSTR (l_message_data,
                                                    INSTR (l_message_data, ':', 1
                                                           , 2)
                                                  + 1)));

                        IF LENGTH (lv_next_sup_dt) = 9
                        THEN
                            lv_next_supply_date   := lv_next_sup_dt; --RTRIM(LTRIM(SUBSTR(l_message_data, INSTR (l_message_data, ':', 1, 2) + 1)));
                        END IF;
                    END IF;

                    IF lv_next_supply_date IS NOT NULL
                    THEN
                        ld_next_supply_date   :=
                            TO_DATE (lv_next_supply_date, 'DD-MON-RR');
                    END IF;

                    --lv_next_supply_date := RTRIM(LTRIM(SUBSTR(l_message_data, INSTR (l_message_data, ':', 1, 2) + 1)));
                    --ld_next_supply_date := TO_DATE(lv_next_supply_date, 'DD-MON-RR');
                    ld_new_sched_ship_date   := NULL;
                END IF;

                --Updating the staging table with status and other relevant information
                BEGIN
                    UPDATE xxdo.xxd_ont_so_correction_t xosc
                       SET xosc.status = lv_ret_sts,        --l_return_status,
                                                     xosc.error_message = l_message_data, xosc.new_schedule_ship_date = ld_new_sched_ship_date,
                           xosc.next_supply_date = ld_next_supply_date, xosc.last_update_date = SYSDATE
                     WHERE     1 = 1
                           AND xosc.line_id = pn_line_id
                           AND xosc.request_id = pn_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        msg (
                               'Error updating table for Scheduling for request ID: '
                            || pn_request_id
                            || ' and line ID: '
                            || pn_line_id);
                END;
            END IF;

            COMMIT;
        ELSE
            BEGIN
                UPDATE xxdo.xxd_ont_so_correction_t xosc
                   SET xosc.status = 'UNABLE_TO_LOCK_ROW', xosc.error_message = 'Unable to lock the line', xosc.last_update_date = SYSDATE
                 WHERE     1 = 1
                       AND xosc.line_id = pn_line_id
                       AND xosc.request_id = pn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error updating table for LocK Row Error for request ID: '
                        || pn_request_id
                        || ' and line ID: '
                        || pn_line_id);
            END;

            COMMIT;
        END IF;                                              --Lock Row end if
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure for request ID: '
                    || pn_request_id
                    || ' and line ID: '
                    || pn_line_id
                    || '. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
    END schedule_unschedule_lines;

    --Procedure to unschedule lines
    PROCEDURE select_sch_unsch_action
    IS
        --Local Variables
        lv_proc_name   VARCHAR2 (30) := 'SELECT_SCH_UNSCH_ACTION';
        lv_error_msg   VARCHAR2 (2000) := NULL;
        ln_unsch_cnt   NUMBER := 0;
        ln_sch_cnt     NUMBER := 0;

        --Cursor to identify the lines to be unscheduled
        CURSOR unsch_cur IS
            SELECT stg.*
              FROM xxdo.xxd_ont_so_correction_t stg, apps.oe_order_lines_all oola
             WHERE     1 = 1
                   AND stg.request_id = gn_conc_request_id
                   AND stg.status = 'NEW'                                --New
                   AND stg.line_id = oola.line_id
                   AND CASE
                           WHEN gv_process = 'SSD_GREATER_THAN_LAD'
                           THEN
                               TRUNC (stg.latest_acceptable_date)
                           ELSE
                               stg.header_cancel_date
                       END >=
                       TRUNC (SYSDATE) --Header cancel Date or LAD should be in future
                   --AND stg.header_cancel_date >= TRUNC(SYSDATE) --Header Cancel Date Should be in Future
                   AND oola.schedule_ship_date IS NOT NULL
                   --There should not be any reservations on the line
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.mtl_reservations mr
                             WHERE     1 = 1
                                   AND mr.demand_source_line_id =
                                       oola.line_id)
                   --Delivery Should not be be in these statuses(C=Shipped D=Cancelled N=Not Ready For Release S=Released to Warehouse X=Not Applicable Y=Staged)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_details wdd
                             WHERE     wdd.source_line_id = oola.line_id
                                   AND wdd.source_code = 'OE'
                                   AND NVL (wdd.released_status, 'R') IN
                                           ('C', 'D', 'N',
                                            'S', 'X', 'Y'));

        --Cursor to identify the lines to be scheduled
        CURSOR sch_cur IS
              SELECT stg.*
                FROM xxdo.xxd_ont_so_correction_t stg, apps.oe_order_lines_all oola
               WHERE     1 = 1
                     AND stg.request_id = gn_conc_request_id
                     AND CASE
                             WHEN gv_process = 'SSD_GREATER_THAN_LAD'
                             THEN
                                 TRUNC (stg.latest_acceptable_date)
                             ELSE
                                 stg.header_cancel_date
                         END >=
                         TRUNC (SYSDATE) --Header cancel Date or LAD should be in future
                     --AND stg.header_cancel_date >= TRUNC(SYSDATE) --Header Cancel Date Should be in Future
                     AND stg.line_id = oola.line_id
                     AND oola.schedule_ship_date IS NULL
                     --There should not be any reservations on the line
                     AND NOT EXISTS
                             (SELECT 1
                                FROM apps.mtl_reservations mr
                               WHERE     1 = 1
                                     AND mr.demand_source_line_id =
                                         oola.line_id)
                     --Delivery Should not be be in these statuses(C=Shipped D=Cancelled N=Not Ready For Release S=Released to Warehouse X=Not Applicable Y=Staged)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM apps.wsh_delivery_details wdd
                               WHERE     wdd.source_line_id = oola.line_id
                                     AND wdd.source_code = 'OE'
                                     AND NVL (wdd.released_status, 'R') IN
                                             ('C', 'D', 'N',
                                              'S', 'X', 'Y'))
            ORDER BY stg.request_date, stg.header_cancel_date, stg.ordered_date;
    BEGIN
        msg ('START - Select Schedule Unschedule Action Procedure', 'Y');

        msg ('Apps Initialization - Setting Context');
        msg ('Org ID         : ' || gn_org_id);
        msg ('User ID        : ' || gn_user_id);
        msg ('Resp ID        : ' || gn_resp_id);
        msg ('Resp Appl ID   : ' || gn_resp_appl_id);
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_resp_id,
                                    resp_appl_id   => gn_resp_appl_id);
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', gn_org_id);

        --Identifying Header Cancel Date in Future and Header Cancel Date <> LAD and unscheduling those lines
        FOR unsch_rec IN unsch_cur
        LOOP
            IF (gv_process <> 'SSD_GREATER_THAN_LAD' AND --unsch_rec.header_cancel_date >= TRUNC(SYSDATE) AND
                                                         unsch_rec.header_cancel_date <> unsch_rec.latest_acceptable_date)
            THEN
                --Call Schedule_unschedule_lines procedure with action as 'UNSCHEDULE'
                schedule_unschedule_lines (
                    pn_request_id           => unsch_rec.request_id,
                    pn_header_id            => unsch_rec.header_id,
                    pn_line_id              => unsch_rec.line_id,
                    pv_action               => 'UNSCHEDULE',
                    pd_header_cancel_date   => unsch_rec.header_cancel_date,
                    pd_latest_acceptable_date   =>
                        unsch_rec.latest_acceptable_date,
                    pd_schedule_ship_date   => unsch_rec.schedule_ship_date);
                ln_unsch_cnt   := ln_unsch_cnt + 1;
            ELSIF (gv_process <> 'SSD_GREATER_THAN_LAD' AND unsch_rec.header_cancel_date = unsch_rec.latest_acceptable_date AND unsch_rec.schedule_ship_date > unsch_rec.latest_acceptable_date)
            THEN
                --Call Schedule_unschedule_lines procedure with action as 'UNSCHEDULE'
                schedule_unschedule_lines (
                    pn_request_id           => unsch_rec.request_id,
                    pn_header_id            => unsch_rec.header_id,
                    pn_line_id              => unsch_rec.line_id,
                    pv_action               => 'UNSCHEDULE',
                    pd_header_cancel_date   => unsch_rec.header_cancel_date,
                    pd_latest_acceptable_date   =>
                        unsch_rec.latest_acceptable_date,
                    pd_schedule_ship_date   => unsch_rec.schedule_ship_date);
                ln_unsch_cnt   := ln_unsch_cnt + 1;
            ELSIF (gv_process = 'SSD_GREATER_THAN_LAD' AND unsch_rec.schedule_ship_date > unsch_rec.latest_acceptable_date)
            THEN
                --Call Schedule_unschedule_lines procedure with action as 'UNSCHEDULE'
                schedule_unschedule_lines (
                    pn_request_id           => unsch_rec.request_id,
                    pn_header_id            => unsch_rec.header_id,
                    pn_line_id              => unsch_rec.line_id,
                    pv_action               => 'UNSCHEDULE',
                    pd_header_cancel_date   => unsch_rec.header_cancel_date,
                    pd_latest_acceptable_date   =>
                        unsch_rec.latest_acceptable_date,
                    pd_schedule_ship_date   => unsch_rec.schedule_ship_date);
                ln_unsch_cnt   := ln_unsch_cnt + 1;
            END IF;
        END LOOP;

        msg ('Number of Lines eligible for Unscheduling:' || ln_unsch_cnt);

        --Identifying Header Cancel Date in Future and Header Cancel Date <> LAD and unscheduling those lines
        FOR sch_rec IN sch_cur
        LOOP
            --Call Schedule_unschedule_lines procedure with action as 'UNSCHEDULE'
            schedule_unschedule_lines (
                pn_request_id               => sch_rec.request_id,
                pn_header_id                => sch_rec.header_id,
                pn_line_id                  => sch_rec.line_id,
                pv_action                   => 'SCHEDULE',
                pd_header_cancel_date       => sch_rec.header_cancel_date,
                pd_latest_acceptable_date   => sch_rec.latest_acceptable_date,
                pd_schedule_ship_date       => sch_rec.schedule_ship_date);
            ln_sch_cnt   := ln_sch_cnt + 1;
        END LOOP;

        msg ('Number of Lines eligible for Scheduling:' || ln_sch_cnt);

        msg ('END - Select Schedule Unschedule Action Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
    END select_sch_unsch_action;

    --This function returns the email ID's listed for the given parameters
    FUNCTION email_recipients
        RETURN apps.do_mail_utils.tbl_recips
    IS
        --Local Variables
        lv_func_name         VARCHAR2 (30) := 'EMAIL_RECIPIENTS';
        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;
        lv_appl_inst_name    VARCHAR2 (25) := NULL;
        lv_error_msg         VARCHAR2 (2000) := NULL;

        CURSOR recipients_cur IS
            SELECT NVL (NVL (fu.email_address, ppx.email_address), 'OMsupport@deckers.com') email_id
              FROM apps.fnd_user fu, apps.per_people_x ppx
             WHERE     1 = 1
                   AND fu.user_id = gn_user_id
                   AND TRUNC (SYSDATE) BETWEEN fu.start_date
                                           AND TRUNC (
                                                   NVL (fu.end_date, SYSDATE))
                   AND fu.employee_id = ppx.person_id(+)
            --Send a copy to OM Support email also
            UNION
            SELECT 'OMsupport@deckers.com' email_id FROM DUAL;
    BEGIN
        lv_def_mail_recips.delete;

        --Get Instance Name
        SELECT applications_system_name
          INTO lv_appl_inst_name
          FROM apps.fnd_product_groups;

        IF lv_appl_inst_name = 'EBSPROD'
        THEN
            FOR recipients_rec IN recipients_cur
            LOOP
                lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                    recipients_rec.email_id;
            END LOOP;
        ELSE
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                'OMsupport@deckers.com';
        END IF;

        RETURN lv_def_mail_recips;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                'OMsupport@deckers.com';
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_func_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
            RETURN lv_def_mail_recips;
    END email_recipients;

    --Procedure to Print the Report in Output File and also to Send email if Send Email parameter is Yes
    PROCEDURE print_email_report
    IS
        --Local Variables
        lv_proc_name         VARCHAR2 (30) := 'PRINT_EMAIL_REPORT';
        lv_error_msg         VARCHAR2 (2000) := NULL;
        ln_rec_cnt           NUMBER := 0;
        lv_def_mail_recips   apps.do_mail_utils.tbl_recips;
        lv_appl_inst_name    VARCHAR2 (25) := NULL;
        lv_email_lkp_type    VARCHAR2 (50) := 'XXD_NEG_ATP_RESCHEDULE_EMAIL';
        ln_counter           NUMBER := 0;
        ln_ret_val           NUMBER := 0;
        lv_out_line          VARCHAR2 (4000);
        lv_emp_name          VARCHAR2 (120) := NULL;
        lv_user_name         VARCHAR2 (30) := NULL;
        lv_email_body        VARCHAR2 (2000);
        ex_no_sender         EXCEPTION;
        ex_no_recips         EXCEPTION;

        CURSOR audit_cur IS
              SELECT stg.*,
                     DECODE (
                         stg.status,
                         'SCHEDULED', 'Scheduled',
                         'SCHEDULING_FAILED', 'scheduling Failed',
                         'UNSCHEDULED', 'Unscheduled',
                         'UNSCHEDULING_FAILED', 'Unscheduling Failed',
                         'API_UNHANDLED_EXCEPTION', 'API Unhandled Exception',
                         'NEW', 'Not Processed',
                         'Error')
                         status_desc,
                     NVL2 (xobot.bulk_order_number, 'Yes', 'No')
                         calloff_order,
                     xobot.bulk_order_number
                         bulk_order_number,
                     REPLACE (xobot.bulk_cust_po_number, CHR (9), '')
                         bulk_cust_po_number,
                     NVL2 (
                         xobot.bulk_order_number,
                            xobot.bulk_line_number
                         || '.'
                         || xobot.bulk_shipment_number,
                         NULL)
                         bulk_line_number,
                     (SELECT request_date
                        FROM apps.oe_order_lines_all
                       WHERE line_id = xobot.bulk_line_id)
                         bulk_request_date,
                     (SELECT schedule_ship_date
                        FROM apps.oe_order_lines_all
                       WHERE line_id = xobot.bulk_line_id)
                         bulk_sched_ship_date,
                     (SELECT latest_acceptable_date
                        FROM apps.oe_order_lines_all
                       WHERE line_id = xobot.bulk_line_id)
                         bulk_latest_accept_date,
                     oola.latest_acceptable_date
                         new_lad,
                     fnd_date.canonical_to_date (oola.attribute1)
                         new_line_cancel_date
                FROM xxdo.xxd_ont_so_correction_t stg, apps.xxd_ont_bulk_orders_t xobot, apps.oe_order_lines_all oola
               WHERE     1 = 1
                     AND stg.request_id = gn_conc_request_id
                     AND stg.header_id = xobot.calloff_header_id(+)
                     AND stg.line_id = xobot.calloff_line_id(+)
                     AND xobot.link_type(+) = 'BULK_LINK'
                     AND stg.line_id = oola.line_id
            ORDER BY stg.ship_from_org, stg.sku, stg.request_date,
                     stg.schedule_ship_date;
    BEGIN
        msg ('START - Print and Email Report', 'Y');
        msg ('START - Writing the report to output file', 'Y');
        --Writing the program output to output file
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               'Operating Unit'
            || '|'
            || 'Brand'
            || '|'
            || 'Ship From Org'
            || '|'
            || 'Division'
            || '|'
            || 'Department'
            || '|'
            || 'Style'
            || '|'
            || 'Color'
            || '|'
            || 'Size'
            || '|'
            || 'SKU'
            || '|'
            || 'SO#'
            || '|'
            || 'Order Source'
            || '|'
            || 'Order Type'
            || '|'
            || 'Customer PO#'
            || '|'
            || 'SO Line#'
            || '|'
            || 'Customer Name'
            || '|'
            || 'Customer Number'
            || '|'
            --         || 'Salesrep Name'
            --         || '|'
            || 'Demand Class'
            || '|'
            || 'Request Date'
            || '|'
            || 'Schedule Ship Date'
            || '|'
            || 'New Schedule Ship Date'
            || '|'
            || 'Old Latest Acceptable Date'
            || '|'
            || 'New Latest Acceptable Date'
            || '|'
            || 'Header Cancel Date'
            || '|'
            || 'Old Line Cancel Date'
            || '|'
            || 'New Line Cancel Date'
            || '|'
            || 'Quantity'
            || '|'
            || 'Status'
            || '|'
            || 'Error Message'
            || '|'
            || 'Next Supply Date'
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

        FOR audit_rec IN audit_cur
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   audit_rec.operating_unit
                || '|'
                || audit_rec.brand
                || '|'
                || audit_rec.ship_from_org
                || '|'
                || audit_rec.division
                || '|'
                || audit_rec.department
                || '|'
                || audit_rec.style
                || '|'
                || audit_rec.color
                || '|'
                || audit_rec.item_size
                || '|'
                || audit_rec.sku
                || '|'
                || audit_rec.order_number
                || '|'
                || audit_rec.order_source
                || '|'
                || audit_rec.order_type
                || '|'
                || audit_rec.customer_po_number
                || '|'
                || audit_rec.line_number
                || '|'
                || audit_rec.customer_name
                || '|'
                || audit_rec.customer_number
                || '|'
                --                                    || audit_rec.salesrep_name
                --                                    || '|'
                || audit_rec.demand_class
                || '|'
                || audit_rec.request_date
                || '|'
                || audit_rec.schedule_ship_date
                || '|'
                || audit_rec.new_schedule_ship_date
                || '|'
                || audit_rec.latest_acceptable_date
                || '|'
                || audit_rec.new_lad
                || '|'
                || audit_rec.header_cancel_date
                || '|'
                || audit_rec.line_cancel_date
                || '|'
                || audit_rec.new_line_cancel_date
                || '|'
                || audit_rec.ordered_quantity
                || '|'
                || audit_rec.status_desc
                || '|'
                || audit_rec.error_message
                || '|'
                || audit_rec.next_supply_date
                || '|'
                || audit_rec.calloff_order
                || '|'
                || audit_rec.bulk_order_number
                || '|'
                || audit_rec.bulk_cust_po_number
                || '|'
                || audit_rec.bulk_line_number
                || '|'
                || audit_rec.bulk_request_date
                || '|'
                || audit_rec.bulk_sched_ship_date
                || '|'
                || audit_rec.bulk_latest_accept_date);
        END LOOP;

        msg ('END - Writing the report to output file', 'Y');

        IF gv_send_email = 'Y'
        THEN
            msg ('START - Sending Email', 'Y');

            SELECT COUNT (*)
              INTO ln_rec_cnt
              FROM xxdo.xxd_ont_so_correction_t stg
             WHERE 1 = 1 AND stg.request_id = gn_conc_request_id--           AND stg.ship_from_org_id = pn_organization_id
                                                                --           AND stg.brand = pv_brand
                                                                ;

            --Get User Name Who Has Submitted the Program
            BEGIN
                SELECT fu.user_name, NVL (NVL (ppx.first_name, ppx.last_name), INITCAP (fu.user_name)) employee_name
                  INTO lv_user_name, lv_emp_name
                  FROM apps.fnd_user fu, apps.per_people_x ppx
                 WHERE     1 = 1
                       AND fu.user_id = gn_user_id
                       AND TRUNC (SYSDATE) BETWEEN fu.start_date
                                               AND TRUNC (
                                                       NVL (fu.end_date,
                                                            SYSDATE))
                       AND fu.employee_id = ppx.person_id(+);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_msg   :=
                        SUBSTR (
                               'In When others exception while getting user name. Error in Package '
                            || gv_package_name
                            || '.'
                            || lv_proc_name
                            || ' '
                            || SQLERRM,
                            1,
                            2000);
                    msg (lv_error_msg);
            END;

            --Attach the file if there are any records
            IF ln_rec_cnt > 0
            THEN
                IF apps.fnd_profile.VALUE ('DO_DEF_ALERT_SENDER') IS NULL
                THEN
                    RAISE ex_no_sender;
                END IF;

                --Getting the email recipients and assigning them to a table type variable
                lv_def_mail_recips   := email_recipients;

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
                            lv_error_msg   :=
                                SUBSTR (
                                       'In When others exception while getting Application Server/Instance Name. Error in Package '
                                    || gv_package_name
                                    || '.'
                                    || lv_proc_name
                                    || ' '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_error_msg);
                    END;

                    apps.do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), lv_def_mail_recips, 'Deckers Sales Orders Correction Program Ran By ' || lv_user_name || ' with Req ID ' || gn_conc_request_id || ' on ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24MISS') || ' from ' || lv_appl_inst_name || ' instance'
                                                         , ln_ret_val);
                    apps.do_mail_utils.send_mail_line (
                        'Content-Type: multipart/mixed; boundary=boundarystring',
                        ln_ret_val);
                    apps.do_mail_utils.send_mail_line ('', ln_ret_val);
                    apps.do_mail_utils.send_mail_line ('--boundarystring',
                                                       ln_ret_val);
                    apps.do_mail_utils.send_mail_line ('', ln_ret_val);
                    apps.do_mail_utils.send_mail_line ('', ln_ret_val);
                    lv_email_body   :=
                           'Dear '
                        || lv_emp_name
                        || ','
                        || CHR (10)
                        || CHR (10)
                        || 'Please find attached the Deckers Sales Orders Correction Program Output with Request ID '
                        || gn_conc_request_id
                        || '.'
                        || CHR (10)
                        || CHR (10)
                        || 'Regards,'
                        || CHR (10)
                        || 'OM Support Team.';
                    apps.do_mail_utils.send_mail_line (lv_email_body,
                                                       ln_ret_val);
                    apps.do_mail_utils.send_mail_line ('--boundarystring',
                                                       ln_ret_val);
                    apps.do_mail_utils.send_mail_line (
                        'Content-Type: text/xls',
                        ln_ret_val);
                    apps.do_mail_utils.send_mail_line (
                           'Content-Disposition: attachment; filename="Deckers_Sales_Order_Correction_Ran_By_'
                        || lv_user_name
                        || '_'
                        || gn_conc_request_id
                        || '_on_'
                        || TO_CHAR (SYSDATE, 'MMDDYYYY_HH24MISS')
                        || '.xls"',
                        ln_ret_val);
                    apps.do_mail_utils.send_mail_line ('', ln_ret_val);
                    apps.do_mail_utils.send_mail_line (
                           'Operating Unit'
                        || CHR (9)
                        || 'Brand'
                        || CHR (9)
                        || 'Ship From Org'
                        || CHR (9)
                        || 'Division'
                        || CHR (9)
                        || 'Department'
                        || CHR (9)
                        || 'Style'
                        || CHR (9)
                        || 'Color'
                        || CHR (9)
                        || 'Size'
                        || CHR (9)
                        || 'SKU'
                        || CHR (9)
                        || 'SO#'
                        || CHR (9)
                        || 'Order Source'
                        || CHR (9)
                        || 'Order Type'
                        || CHR (9)
                        || 'Customer PO#'
                        || CHR (9)
                        || 'SO Line#'
                        || CHR (9)
                        || 'Customer Name'
                        || CHR (9)
                        || 'Customer Number'
                        || CHR (9)
                        --                   || 'Salesrep Name'
                        --                   || CHR (9)
                        || 'Demand Class'
                        || CHR (9)
                        || 'Request Date'
                        || CHR (9)
                        || 'Schedule Ship Date'
                        || CHR (9)
                        || 'New Schedule Ship Date'
                        || CHR (9)
                        || 'Old Latest Acceptable Date'
                        || CHR (9)
                        || 'New Latest Acceptable Date'
                        || CHR (9)
                        || 'Header Cancel Date'
                        || CHR (9)
                        || 'Old Line Cancel Date'
                        || CHR (9)
                        || 'New Line Cancel Date'
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

                    FOR audit_rec IN audit_cur
                    LOOP
                        lv_out_line   := NULL;
                        lv_out_line   :=
                               audit_rec.operating_unit
                            || CHR (9)
                            || audit_rec.brand
                            || CHR (9)
                            || audit_rec.ship_from_org
                            || CHR (9)
                            || audit_rec.division
                            || CHR (9)
                            || audit_rec.department
                            || CHR (9)
                            || audit_rec.style
                            || CHR (9)
                            || audit_rec.color
                            || CHR (9)
                            || audit_rec.item_size
                            || CHR (9)
                            || audit_rec.sku
                            || CHR (9)
                            || audit_rec.order_number
                            || CHR (9)
                            || audit_rec.order_source
                            || CHR (9)
                            || audit_rec.order_type
                            || CHR (9)
                            || audit_rec.customer_po_number
                            || CHR (9)
                            || audit_rec.line_number
                            || CHR (9)
                            || audit_rec.customer_name
                            || CHR (9)
                            || audit_rec.customer_number
                            || CHR (9)
                            --                      || audit_rec.salesrep_name
                            --                      || CHR (9)
                            || audit_rec.demand_class
                            || CHR (9)
                            || audit_rec.request_date
                            || CHR (9)
                            || audit_rec.schedule_ship_date
                            || CHR (9)
                            || audit_rec.new_schedule_ship_date
                            || CHR (9)
                            || audit_rec.latest_acceptable_date
                            || CHR (9)
                            || audit_rec.new_lad
                            || CHR (9)
                            || audit_rec.header_cancel_date
                            || CHR (9)
                            || audit_rec.line_cancel_date
                            || CHR (9)
                            || audit_rec.new_line_cancel_date
                            || CHR (9)
                            || audit_rec.ordered_quantity
                            || CHR (9)
                            || audit_rec.status_desc
                            || CHR (9)
                            || audit_rec.error_message
                            || CHR (9)
                            || audit_rec.next_supply_date
                            || CHR (9)
                            || audit_rec.calloff_order
                            || CHR (9)
                            || audit_rec.bulk_order_number
                            || CHR (9)
                            || audit_rec.bulk_cust_po_number
                            || CHR (9)
                            || audit_rec.bulk_line_number
                            || CHR (9)
                            || audit_rec.bulk_request_date
                            || CHR (9)
                            || audit_rec.bulk_sched_ship_date
                            || CHR (9)
                            || audit_rec.bulk_latest_accept_date
                            || CHR (9);

                        apps.do_mail_utils.send_mail_line (lv_out_line,
                                                           ln_ret_val);
                        ln_counter    := ln_counter + 1;
                    END LOOP;

                    apps.do_mail_utils.send_mail_close (ln_ret_val);
                END IF;                            --lv_def_mail_recips End if
            END IF;                                      --ln_rec_count end if

            msg ('END - Sending Email', 'Y');
        ELSE
            msg (' ');
            msg (
                'Not sending email as the parameter ''Send Email'' is passed as ''No''.');
            msg (' ');
        END IF;                                         --gv_send_email end if

        msg ('END - Print and Email Report', 'Y');
    EXCEPTION
        WHEN ex_no_sender
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            msg (
                'ex_no_sender : There is no sender configured. Check the profile value DO: Default Alert Sender');
        WHEN ex_no_recips
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);         --Be Safe
            msg (
                   'ex_no_recips : There are no recipients configured to receive the email. Check lookup type '
                || lv_email_lkp_type);
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
    END print_email_report;

    --This is the driving procedure called by Deckers Sales Orders Correction Program
    PROCEDURE so_correction_main (pv_errbuf OUT NOCOPY VARCHAR2, pn_retcode OUT NOCOPY NUMBER, pn_org_id IN NUMBER --Mandatory
                                                                                                                  , pv_brand IN VARCHAR2 --Optional
                                                                                                                                        , pv_order_type IN VARCHAR2 DEFAULT 'NONE' --Mandatory
                                                                                                                                                                                  , pv_order_source IN VARCHAR2 DEFAULT 'NONE' --Mandatory
                                                                                                                                                                                                                              , pv_request_date_from IN VARCHAR2 --Optional
                                                                                                                                                                                                                                                                , pv_request_date_to IN VARCHAR2 --Optional
                                                                                                                                                                                                                                                                                                , pv_process IN VARCHAR2 DEFAULT 'BOTH' --Mandatory
                                  , pv_send_email IN VARCHAR2 DEFAULT 'N' --Optional
                                                                         )
    IS
        --Local Variables
        lv_proc_name             VARCHAR2 (30) := 'SO_CORRECTION_MAIN';
        lv_error_msg             VARCHAR2 (2000) := NULL;
        lv_operating_unit        VARCHAR2 (240) := NULL;
        lv_resp_operating_unit   VARCHAR2 (240) := NULL;
        ln_so_rec_exists         NUMBER := 0;
        ln_ret_code              NUMBER := 0;
        lv_ret_msg               VARCHAR2 (2000) := NULL;
    BEGIN
        msg ('Deckers Sales Orders Correction Program - START', 'Y');
        msg ('Parameters');

        BEGIN
            SELECT name
              INTO lv_operating_unit
              FROM apps.hr_operating_units
             WHERE 1 = 1 AND organization_id = pn_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_operating_unit   := NULL;
        END;

        BEGIN
            SELECT name
              INTO lv_resp_operating_unit
              FROM apps.hr_operating_units
             WHERE 1 = 1 AND organization_id = gn_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_resp_operating_unit   := NULL;
        END;

        msg (
            '-------------------------------------------------------------------');
        msg ('Operating Unit Name      : ' || lv_operating_unit);
        msg ('Operating Unit ID        : ' || pn_org_id);
        msg ('Brand                    : ' || pv_brand);
        msg ('Order Type               : ' || pv_order_type);
        msg ('Order Source             : ' || pv_order_source);
        msg ('Request Date From        : ' || pv_request_date_from);
        msg ('Request Date To          : ' || pv_request_date_to);
        msg ('Process                  : ' || pv_process);
        msg ('Send Email(Y=Yes, N=No)  : ' || pv_send_email);
        msg (
            '-------------------------------------------------------------------');
        msg (' ');
        msg ('Printing Technical Details');
        msg ('Concurrent Request ID    :' || gn_conc_request_id);
        msg ('Concurrent Login ID      :' || gn_conc_login_id);
        msg ('Login ID                 :' || gn_login_id);
        msg (' ');

        --Assigning parameters to Global Variables
        gv_brand               := pv_brand;
        gv_order_type          := pv_order_type;
        gv_order_source        := pv_order_source;
        gv_request_date_from   := pv_request_date_from;
        gv_request_date_to     := pv_request_date_to;
        gv_process             := pv_process;
        gv_send_email          := pv_send_email;

        --Calling get_sales_orders procedure which identifies the sales orders to be corrected and inserts into sales orders correction staging table
        msg ('Calling GET_SALES_ORDERS procedure - START', 'Y');
        get_sales_orders (pn_ret_code => ln_ret_code, pv_ret_msg => lv_ret_msg);
        msg ('Calling GET_SALES_ORDERS procedure - END', 'Y');
        msg (' ');

        --Call SYNC_CANCEL_DATE procedure to sync Line Cancel Date with the Header Cancel Date
        IF gv_process = 'SSD_GREATER_THAN_LAD'
        THEN
            msg (
                'As the Process Parameter is ''SSD_GREATER_THAN_LAD'', So not updating the Line Cancel Date and LAD with Header Cancel Date.',
                'Y');
            msg (' ');
        ELSE
            msg ('Calling SYNC_CANCEL_DATE procedure - START', 'Y');
            sync_cancel_date;
            msg ('Calling SYNC_CANCEL_DATE procedure - END', 'Y');
            msg (' ');
        END IF;

        --Calling unschedule_lines procedure which unschedules the lines
        msg ('Calling SELECT_SCH_UNSCH_ACTION procedure - START', 'Y');
        select_sch_unsch_action;
        msg ('Calling SELECT_SCH_UNSCH_ACTION procedure - END', 'Y');
        msg (' ');
        --Calling print_email_report procedure to print the report in output and also to send report as email
        msg ('Calling PRINT_EMAIL_REPORT procedure - START', 'Y');
        print_email_report;
        msg ('Calling print_email_report procedure - END', 'Y');
        msg (' ');
        --Calling print_email_report procedure to print the report in output and also to send report as email
        msg ('Calling PURGE_DATA procedure - START', 'Y');
        purge_data;
        msg ('Calling PURGE_DATA procedure - END', 'Y');
        msg (' ');
        msg ('Deckers Sales Orders Correction Program - END', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg   :=
                SUBSTR (
                       'In When Others exception in '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_error_msg);
            pv_errbuf    := lv_error_msg;
            pn_retcode   := gn_error;
    END so_correction_main;
END XXD_ONT_SO_CORRECTION_PKG;
/
