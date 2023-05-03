--
-- XXD_ONT_OPEN_SO_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_OPEN_SO_CONV_PKG"
/**********************************************************************************************************

    File Name    : XXD_ONT_SALES_ORDER_CONV_PKG

    Created On   : 13-JUN-2014

    Created By   : BT Technology Team

    Purpose      : This  package is to extract Open Sales Orders data from 12.0.6 EBS
                   and import into 12.2.3 EBS after validations.
   ***********************************************************************************************************
   Modification History:
   Version   SCN#        By                        Date                     Comments
  1.0              BT Technology Team          13-Jun-2014               Base Version
  1.1              BT Technology Team          14-Aug-2014               Added Validations
   **********************************************************************************************************
   Parameters: 1.Mode
               2.Debug Flag
   **********************************************************************************************************/
AS
    /******************************************************
    * Procedure: log_recordss
    *
    * Synopsis: This procedure will call we be called by the concurrent program
     * Design:
     *
     * Notes:
     *
     * PARAMETERS:
     *   IN    : p_debug    Varchar2
     *   IN    : p_message  Varchar2
     *
     * Return Values:
     * Modifications:
     *
     ******************************************************/

    TYPE xxd_ont_order_header_tab
        IS TABLE OF xxd_ont_open_so_head_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ont_order_header_tab   xxd_ont_order_header_tab;

    TYPE xxd_ont_order_lines_tab
        IS TABLE OF xxd_ont_open_so_lines_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ont_order_lines_tab    xxd_ont_order_lines_tab;

    TYPE xxd_ont_prc_adj_lines_tab
        IS TABLE OF xxd_ont_open_price_adj_l_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gn_resp_id                 NUMBER;
    gn_resp_appl_id            NUMBER;

    TYPE p_qry_orderinfo_rec IS RECORD
    (
        order_number                NUMBER,
        header_id                   NUMBER,
        org_id                      NUMBER,
        sold_to_org_id              NUMBER,
        cust_account_number         VARCHAR2 (30),
        line_id                     NUMBER,
        inventory_item_id           NUMBER,
        ordered_item                VARCHAR2 (200),
        ship_from_org_id            NUMBER,
        ship_to_org_id              NUMBER,
        schedule_ship_date          DATE,
        ship_to_location_id         NUMBER,
        delivery_detail_id          NUMBER,
        released_status             VARCHAR2 (20),
        original_released_status    VARCHAR2 (20),
        project_id                  NUMBER
    );

    TYPE p_qry_orderinfo_tbl IS TABLE OF p_qry_orderinfo_rec
        INDEX BY BINARY_INTEGER;

    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (p_message);

        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END log_records;

    PROCEDURE truncte_stage_tables (x_ret_code      OUT VARCHAR2,
                                    x_return_mesg   OUT VARCHAR2)
    AS
        lx_return_mesg   VARCHAR2 (2000);
    BEGIN
        --x_ret_code   := gn_suc_const;
        log_records (gc_debug_flag,
                     'Working on truncte_stage_tables to purge the data');

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.XXD_ONT_OPEN_SO_HEAD_STG_T';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.XXD_ONT_OPEN_SO_LINES_STG_T';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.XXD_ONT_OPEN_PRICE_ADJ_L_STG_T';

        log_records (gc_debug_flag, 'Truncate Stage Table Complete');
    EXCEPTION
        WHEN OTHERS
        THEN
            --x_ret_code      := gn_err_const;
            x_return_mesg   := SQLERRM;
            log_records (gc_debug_flag,
                         'Truncate Stage Table Exception t' || x_return_mesg);
            xxd_common_utils.record_error ('AR', gn_org_id, 'Deckers Ecomm Open Sales Order Conversion Program', --  SQLCODE,
                                                                                                                 SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                               --   SYSDATE,
                                                                                                                                                               gn_user_id, gn_conc_request_id, 'truncte_stage_tables', NULL
                                           , x_return_mesg);
    END truncte_stage_tables;

    PROCEDURE backup_header_recon
    AS
        CURSOR cur_order_head IS SELECT * FROM XXD_ONT_OPEN_SO_HEAD_STG_T-- and lines.record_status ='V'
                                                                         ;

        TYPE t_ord_head_type IS TABLE OF cur_order_head%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ord_head_tab   t_ord_head_type;
    BEGIN
        OPEN cur_order_head;

        LOOP
            t_ord_head_tab.delete;

            FETCH cur_order_head BULK COLLECT INTO t_ord_head_tab LIMIT 5000;

            EXIT WHEN t_ord_head_tab.COUNT = 0;

            FORALL I IN 1 .. t_ord_head_tab.COUNT SAVE EXCEPTIONS
                INSERT INTO XXD_ECOM_SO_HEAD_OPEN_DUMP
                     VALUES t_ord_head_tab (i);


            COMMIT;
        END LOOP;
    --  x_retrun_status := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Un-expecetd Error in backing up header records => '
                    || SQLERRM);
    --    ROLLBACK;
    --  x_retrun_status := 'E';
    END backup_header_recon;

    PROCEDURE set_org_context (p_target_org_id IN NUMBER, p_resp_id OUT NUMBER, p_resp_appl_id OUT NUMBER)
    AS
    BEGIN
        SELECT level_value_application_id, fr.responsibility_id
          INTO p_resp_appl_id, p_resp_id
          FROM fnd_profile_option_values fpov, fnd_responsibility_tl fr, fnd_profile_options fpo
         WHERE     fpo.profile_option_id = fpov.profile_option_id --AND LEVEL_ID =
               AND level_value = fr.responsibility_id
               AND level_id = 10003
               AND language = 'US'
               AND profile_option_name = 'DEFAULT_ORG_ID'
               AND responsibility_name LIKE
                       'Deckers Order Management Super User%'
               AND profile_option_value = TO_CHAR (p_target_org_id);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            p_resp_id        := NULL;
            p_resp_appl_id   := NULL;
        WHEN OTHERS
        THEN
            p_resp_id        := NULL;
            p_resp_appl_id   := NULL;
    END set_org_context;

    PROCEDURE progress_order_header (p_order_number    IN NUMBER,
                                     p_activity_name   IN VARCHAR2)
    IS
        CURSOR c_get_line_notf_act (p_order_number    NUMBER,
                                    p_activity_name   VARCHAR2)
        IS
            SELECT oha.header_id header_id, wpa.activity_name
              FROM apps.wf_item_activity_statuses st, apps.wf_process_activities wpa, --  apps.oe_order_lines_all ola,
                                                                                      apps.oe_order_headers_all oha
             WHERE     wpa.instance_id = st.process_activity
                   AND st.item_type = 'OEOH'
                   AND wpa.activity_name = p_activity_name
                   AND st.activity_status = 'NOTIFIED'
                   AND st.item_key = oha.header_id
                   --             AND ola.header_id = oha.header_id
                   AND oha.order_number =
                       NVL (p_order_number, oha.order_number);

        l_retry   BOOLEAN;
        p_lines   BOOLEAN := FALSE;
    BEGIN
        FOR v_get_lines
            IN c_get_line_notf_act (p_order_number, p_activity_name)
        LOOP
            l_retry   := FALSE;
            p_lines   := FALSE;

            wf_engine.completeactivity ('OEOH', v_get_lines.header_id, v_get_lines.activity_name
                                        , NULL);
        END LOOP;

        wf_engine.background ('OEOH', NULL, NULL,
                              TRUE, FALSE, FALSE);
    EXCEPTION
        WHEN OTHERS
        THEN
            RAISE;
    END progress_order_header;

    PROCEDURE progress_order_lines (p_order_number    IN NUMBER,
                                    p_activity_name   IN VARCHAR2)
    IS
        CURSOR c_get_line_notf_act (p_order_number    NUMBER,
                                    p_activity_name   VARCHAR2)
        IS
            SELECT TO_NUMBER (st.item_key) line_id, oha.header_id header_id, wpa.activity_name
              FROM apps.wf_item_activity_statuses st, apps.wf_process_activities wpa, apps.oe_order_lines_all ola,
                   apps.oe_order_headers_all oha
             WHERE     wpa.instance_id = st.process_activity
                   AND st.item_type = 'OEOL'
                   AND wpa.activity_name = p_activity_name
                   AND st.activity_status = 'NOTIFIED'
                   AND st.item_key = ola.line_id
                   AND ola.header_id = oha.header_id
                   AND oha.order_number =
                       NVL (p_order_number, oha.order_number);

        l_retry   BOOLEAN;
        p_lines   BOOLEAN := FALSE;
    BEGIN
        FOR v_get_lines
            IN c_get_line_notf_act (p_order_number, p_activity_name)
        LOOP
            l_retry   := FALSE;
            p_lines   := FALSE;

            wf_engine.completeactivity ('OEOL', v_get_lines.line_id, v_get_lines.activity_name
                                        , NULL);
        END LOOP;

        wf_engine.background ('OEOL', NULL, NULL,
                              TRUE, FALSE, FALSE);
    EXCEPTION
        WHEN OTHERS
        THEN
            RAISE;
    END progress_order_lines;

    PROCEDURE progress_fraud_lines (p_order_line_id IN NUMBER)
    IS
        l_result_code     VARCHAR2 (40);
        l_activity_name   VARCHAR2 (120);

        CURSOR c_lines_to_progress IS
            SELECT ool.line_id, ool.attribute20 status_code
              FROM oe_order_lines_all ool
             WHERE     ool.line_id = p_order_line_id
                   AND ool.cancelled_flag = 'N'
                   AND ool.open_flag = 'Y'
                   AND ool.attribute17 IN ('N', 'P');
    BEGIN
        FOR c1 IN c_lines_to_progress
        LOOP
            IF c1.status_code = 'FRC'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_ACCERTIFY_RESULT';
                l_result_code     := 'NO_FRAUD';                    -- 'FRAUD'
            ELSIF c1.status_code = 'PGA'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_PG_AUTH';
                l_result_code     := 'SUCCESS';                      -- 'FAIL'
            ELSIF c1.status_code = 'SHE'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_SHIPMENT_EMAIL';
                l_result_code     := NULL;
            ELSIF c1.status_code = 'PGC'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_PG_RESPONSE';
                l_result_code     := 'SUCCESS';                      -- 'FAIL'
            ELSIF c1.status_code = 'CHB'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_PG_CHARGEBACK';
                l_result_code     := 'SUCCESS';                      -- 'FAIL'
            ELSIF c1.status_code = 'RCE'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_RECEIPT_EMAIL';
                l_result_code     := NULL;
            ELSIF c1.status_code = 'CSN'
            THEN
                l_activity_name   := 'DOEC_CA_WAIT_FOR_SHIP_NOTIF';
                l_result_code     := 'SUCCESS';
            ELSIF c1.status_code = 'CSE'
            THEN
                l_activity_name   := 'DOEC_CA_WAIT_FOR_SHIP_EMAIL';
                l_result_code     := 'SUCCESS';
            ELSIF c1.status_code = 'M2O'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_M2O_INTF_RESULTS';
                l_result_code     := 'SUCCESS';                        -- FAIL
            ELSIF c1.status_code = 'IPE'
            THEN
                l_activity_name   := 'DOEC_WAIT_FOR_ORDER_ACK_EMAIL';
                l_result_code     := NULL;
            ELSE
                l_activity_name   := NULL;
                l_result_code     := NULL;
            END IF;

            --

            IF l_activity_name IS NOT NULL
            THEN
                UPDATE apps.oe_order_lines_all ool
                   SET attribute19 = l_result_code, attribute17 = 'S'
                 WHERE line_id = c1.line_id;

                wf_engine.completeactivity (itemtype => 'OEOL', itemkey => TO_CHAR (c1.line_id), activity => l_activity_name
                                            , result => l_result_code);
                COMMIT;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            RAISE;
    END progress_fraud_lines;

    PROCEDURE call_atp_toschedule (p_inventory_item_id IN NUMBER, p_quantity_ordered IN NUMBER, p_quantity_uom IN VARCHAR2, p_requested_ship_date IN DATE, p_source_organization_id IN NUMBER, p_order_number IN VARCHAR2 DEFAULT NULL
                                   , p_line_number IN NUMBER DEFAULT NULL, x_return_status OUT VARCHAR2, x_return_msg OUT VARCHAR2)
    AS
        l_atp_rec             mrp_atp_pub.atp_rec_typ;
        p_atp_rec             mrp_atp_pub.atp_rec_typ;
        x_atp_rec             mrp_atp_pub.atp_rec_typ := NULL;
        x_atp_supply_demand   mrp_atp_pub.atp_supply_demand_typ;
        x_atp_period          mrp_atp_pub.atp_period_typ;
        x_atp_details         mrp_atp_pub.atp_details_typ;
        --  x_return_status                 VARCHAR2(2000);
        x_msg_data            VARCHAR2 (500);
        x_msg_count           NUMBER;
        l_session_id          NUMBER;
        l_error_message       VARCHAR2 (250);
        x_error_message       VARCHAR2 (80);
        i                     NUMBER;
        v_file_dir            VARCHAR2 (80);
    BEGIN
        -- Initialize

        --    fnd_global.apps_initialize(user_id        => 1433  ,   -- MFG User ID
        --                               resp_id        => 50709 ,   -- Advanced Supply Chain Planner
        --                               resp_appl_id   => 724       -- Advanced Supply Chain Planning
        --                              );                           -- Note 136098.1
        fnd_global.apps_initialize (gn_user_id, gn_resp_id, gn_resp_appl_id);
        -- ====================================================
        -- IF using 11.5.9 and above, Use MSC_ATP_GLOBAL.Extend_ATP
        -- API to extend record structure as per standards. This
        -- will ensure future compatibility.

        msc_atp_global.extend_atp (l_atp_rec, x_return_status, 1);

        -- IF using 11.5.8 code, Use MSC_SATP_FUNC.Extend_ATP
        -- API to avoid any issues with Extending ATP record
        -- type.
        -- ====================================================

        l_atp_rec.inventory_item_id (1)          := p_inventory_item_id; -- from msc_system_items.sr_inventory_item_id
        --  l_atp_rec.Inventory_Item_Name(1)       := '1001473-CCGN-07';
        l_atp_rec.quantity_ordered (1)           := p_quantity_ordered;
        l_atp_rec.quantity_uom (1)               := p_quantity_uom;
        l_atp_rec.requested_ship_date (1)        := p_requested_ship_date;
        l_atp_rec.action (1)                     := 100;
        l_atp_rec.instance_id (1)                := NULL; -- needed when using calling_module = 724, use msc_system_items.sr_instance_id
        l_atp_rec.source_organization_id (1)     := p_source_organization_id;
        l_atp_rec.oe_flag (1)                    := 'N';
        l_atp_rec.insert_flag (1)                := 1; -- Hardcoded value for profile MRP:Calculate Supply Demand 0= NO
        l_atp_rec.attribute_04 (1)               := 1; -- With this Attribute set to 1 this will enable the Period (Horizontal Plan),
        -- Supply Demand, and Pegging data in the Pl/SQL records of ATP API.
        --
        -- Period (Horizontal Plan) and Supply/DEmand data is available in
        -- mrp_atp_details_temp based on session_id as follows:
        -- HP data: Record_Type=1
        -- SD data: Record_Type=2
        -- Peggng : Record_type=3
        --
        -- If this attribute_04 is set to 1, Please set
        -- the Insert_Flag as well to 1.
        --
        -- If there is a performance hit Please set the
        -- following to 0
        -- l_atp_rec.Insert_Flag(1)               := 0
        -- l_atp_rec.Attribute_04(1)              := 0
        l_atp_rec.customer_id (1)                := NULL;
        l_atp_rec.customer_site_id (1)           := NULL;
        l_atp_rec.calling_module (1)             := NULL; -- use 724 when calling from MSC_ATP_CALL - otherwise NULL
        l_atp_rec.row_id (1)                     := NULL;
        l_atp_rec.source_organization_code (1)   := NULL;
        l_atp_rec.organization_id (1)            := NULL;
        l_atp_rec.order_number (1)               := p_order_number;
        l_atp_rec.line_number (1)                := p_line_number;
        l_atp_rec.override_flag (1)              := 'Y';
        l_error_message                          := NULL;

        SELECT oe_order_sch_util.get_session_id INTO l_session_id FROM DUAL;

        --  SELECT LTRIM(RTRIM(SUBSTR(value, INSTR(value,',',-1,1)+1)))
        --  INTO   v_file_dir
        --  FROM   v$parameter  WHERE  name= 'utl_file_dir';

        apps.msc_atp_pub.call_atp (l_session_id,
                                   l_atp_rec,
                                   x_atp_rec,
                                   x_atp_supply_demand,
                                   x_atp_period,
                                   x_atp_details,
                                   x_return_status,
                                   x_msg_data,
                                   x_msg_count);

        -- OUTPUT Lines - no modifications needed when number of records increases

        log_records (
            gc_debug_flag,
               'session_id and session file name = '
            || l_session_id
            || '   session-'
            || l_session_id);
        --  log_records (gc_debug_flag,'utl_file_dir value where session file is located  =  '||v_file_dir);
        log_records (gc_debug_flag, ' ---- ');
        log_records (gc_debug_flag, 'Return Status = ' || x_return_status);
        log_records (gc_debug_flag, 'Message Count = ' || x_msg_count);

        IF (x_return_status = 'S')
        THEN
            log_records (
                gc_debug_flag,
                'No of records in atp_rec =           ' || x_atp_rec.inventory_item_id.COUNT);
            log_records (
                gc_debug_flag,
                   'No of records in atp_supply_demand = '
                || x_atp_supply_demand.inventory_item_id.COUNT);
            log_records (
                gc_debug_flag,
                'No of records in atp_period =        ' || x_atp_period.inventory_item_id.COUNT);
            log_records (
                gc_debug_flag,
                'No of records in atp_details =       ' || x_atp_details.inventory_item_id.COUNT);
            log_records (gc_debug_flag, ' ---- ');
            log_records (gc_debug_flag, ' Begin Item Availability Results');
            log_records (gc_debug_flag, ' ---- ');

            FOR i IN 1 .. x_atp_rec.inventory_item_id.COUNT
            LOOP
                x_error_message   := '';
                log_records (
                    gc_debug_flag,
                    'Item Name          : ' || x_atp_rec.inventory_item_name (i));
                log_records (
                    gc_debug_flag,
                    'Quantity ordered   : ' || x_atp_rec.quantity_ordered (i));
                log_records (
                    gc_debug_flag,
                    'Source Org Id      : ' || x_atp_rec.source_organization_id (i));
                log_records (
                    gc_debug_flag,
                    'Source Org Code    : ' || x_atp_rec.source_organization_code (i));
                log_records (
                    gc_debug_flag,
                    'Requested Ship Date: ' || x_atp_rec.requested_ship_date (i));
                log_records (
                    gc_debug_flag,
                    'Requested Date Qty : ' || x_atp_rec.requested_date_quantity (i));
                log_records (
                    gc_debug_flag,
                    'Ship Date          : ' || x_atp_rec.ship_date (i));
                log_records (
                    gc_debug_flag,
                    'Error Code         : ' || x_atp_rec.ERROR_CODE (i));

                IF (x_atp_rec.ERROR_CODE (i) <> 0)
                THEN
                    SELECT meaning
                      INTO x_error_message
                      FROM mfg_lookups
                     WHERE     lookup_type = 'MTL_DEMAND_INTERFACE_ERRORS'
                           AND lookup_code = x_atp_rec.ERROR_CODE (i);

                    log_records (gc_debug_flag,
                                 'Error Message      : ' || x_error_message);
                    x_return_msg   := x_error_message;
                END IF;

                log_records (
                    gc_debug_flag,
                    'Insert Flag        : ' || x_atp_rec.insert_flag (i));
                log_records (gc_debug_flag, '----------- ');
            END LOOP;

            log_records (gc_debug_flag, ' ============================= ');
            log_records (gc_debug_flag, ' No. of record in x_atp_period ');
            log_records (gc_debug_flag, ' ============================= ');

            FOR j IN 1 .. x_atp_period.LEVEL.COUNT
            LOOP
                log_records (
                    gc_debug_flag,
                    'Start Date        : ' || x_atp_period.period_start_date (j));
                log_records (
                    gc_debug_flag,
                    'Total Demand      : ' || x_atp_period.total_demand_quantity (j));
                log_records (
                    gc_debug_flag,
                    'Total Supply      : ' || x_atp_period.total_supply_quantity (j));
                log_records (
                    gc_debug_flag,
                    'Cum Quantity      : ' || x_atp_period.cumulative_quantity (j));
                log_records (gc_debug_flag,
                             '---------------------------------- ');
            END LOOP;

            log_records (gc_debug_flag,
                         ' ==================================== ');
            log_records (gc_debug_flag,
                         ' No. of record in x_atp_supply_demand ');
            log_records (gc_debug_flag,
                         ' ==================================== ');

            FOR j IN 1 .. x_atp_supply_demand.LEVEL.COUNT
            LOOP
                log_records (
                    gc_debug_flag,
                    'Supply_Demand Type     : ' || x_atp_supply_demand.supply_demand_type (j));
                log_records (
                    gc_debug_flag,
                    'Supply_Demand Date     : ' || x_atp_supply_demand.supply_demand_date (j));
                log_records (
                    gc_debug_flag,
                    'supply_demand Quantity : ' || x_atp_supply_demand.supply_demand_quantity (j));
                log_records (gc_debug_flag,
                             '---------------------------------- ');
            END LOOP;
        END IF;
    END call_atp_toschedule;

    PROCEDURE create_reservation (p_header_id           IN NUMBER,
                                  p_line_id             IN NUMBER,
                                  p_reserved_quantity   IN NUMBER)
    AS
        l_api_version_number           NUMBER := 1;
        l_return_status                VARCHAR2 (2000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (2000);
        /*****************PARAMETERS****************************************************/
        l_debug_level                  NUMBER := 1;  -- OM DEBUG LEVEL (MAX 5)
        l_org                          NUMBER := 87;         -- OPERATING UNIT
        l_no_orders                    NUMBER := 1;            -- NO OF ORDERS
        l_user                         NUMBER := 7252;                 -- USER
        l_resp                         NUMBER := 50691;      -- RESPONSIBLILTY
        l_appl                         NUMBER := 660;      -- ORDER MANAGEMENT
        /*****************INPUT VARIABLES FOR PROCESS_ORDER API*************************/
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        /*****************OUT VARIABLES FOR PROCESS_ORDER API***************************/
        l_header_rec_out               oe_order_pub.header_rec_type;
        l_header_val_rec_out           oe_order_pub.header_val_rec_type;
        l_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        l_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        l_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        l_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        l_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        l_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        l_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        l_line_tbl_out                 oe_order_pub.line_tbl_type;
        l_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        l_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        l_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        l_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        l_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        l_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        l_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        l_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        l_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        l_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        l_action_request_tbl_out       oe_order_pub.request_tbl_type;
        l_msg_index                    NUMBER;
        l_data                         VARCHAR2 (2000);
        l_loop_count                   NUMBER;
        l_debug_file                   VARCHAR2 (200);
        b_return_status                VARCHAR2 (200);
        b_msg_count                    NUMBER;
        b_msg_data                     VARCHAR2 (2000);

        l_user_id                      NUMBER := -1;
        l_resp_id                      NUMBER := -1;
        l_application_id               NUMBER := -1;

        l_user_name                    VARCHAR2 (30) := 'PVADREVU001';
        l_resp_name                    VARCHAR2 (30) := 'ORDER_MGMT_SU_US';
    BEGIN
        oe_msg_pub.initialize;
        l_line_tbl (1)                     := oe_order_pub.g_miss_line_rec;
        l_line_tbl (1).header_id           := p_header_id;
        l_line_tbl (1).line_id             := p_line_id;
        l_line_tbl (1).reserved_quantity   := p_reserved_quantity;
        l_line_tbl (1).operation           := oe_globals.g_opr_update;

        /*****************CALLTO PROCESS ORDER API*********************************/
        oe_order_pub.process_order (
            p_api_version_number       => l_api_version_number,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            p_line_adj_tbl             => l_line_adj_tbl      -- OUT variables
                                                        ,
            x_header_rec               => l_header_rec_out,
            x_header_val_rec           => l_header_val_rec_out,
            x_header_adj_tbl           => l_header_adj_tbl_out,
            x_header_adj_val_tbl       => l_header_adj_val_tbl_out,
            x_header_price_att_tbl     => l_header_price_att_tbl_out,
            x_header_adj_att_tbl       => l_header_adj_att_tbl_out,
            x_header_adj_assoc_tbl     => l_header_adj_assoc_tbl_out,
            x_header_scredit_tbl       => l_header_scredit_tbl_out,
            x_header_scredit_val_tbl   => l_header_scredit_val_tbl_out,
            x_line_tbl                 => l_line_tbl_out,
            x_line_val_tbl             => l_line_val_tbl_out,
            x_line_adj_tbl             => l_line_adj_tbl_out,
            x_line_adj_val_tbl         => l_line_adj_val_tbl_out,
            x_line_price_att_tbl       => l_line_price_att_tbl_out,
            x_line_adj_att_tbl         => l_line_adj_att_tbl_out,
            x_line_adj_assoc_tbl       => l_line_adj_assoc_tbl_out,
            x_line_scredit_tbl         => l_line_scredit_tbl_out,
            x_line_scredit_val_tbl     => l_line_scredit_val_tbl_out,
            x_lot_serial_tbl           => l_lot_serial_tbl_out,
            x_lot_serial_val_tbl       => l_lot_serial_val_tbl_out,
            x_action_request_tbl       => l_action_request_tbl_out,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data);

        /*****************CHECK RETURN STATUS***********************************/
        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            IF (l_debug_level > 0)
            THEN
                log_records (gc_debug_flag, 'success');
                log_records (
                    gc_debug_flag,
                       'header.order_number IS: '
                    || TO_CHAR (l_header_rec_out.order_number));
            --         progress_order_header(p_order_number => l_header_rec_out.order_number
            --                              ,p_activity_name => 'BOOK_ELIGIBLE' );
            --
            --         progress_order_lines(p_order_number => l_header_rec_out.order_number
            --                             ,p_activity_name => 'SCHEDULING_ELIGIBLE');

            END IF;

            --         UPDATE XXD_ONT_SO_LINES_CONV_STG_T SET
            --                       RECORD_STATUS       = gc_process_status
            --                 WHERE ORIG_SYS_DOCUMENT_REF  = l_header_rec_out.orig_sys_document_ref ;
            --
            --         UPDATE XXD_ONT_SO_HEADERS_CONV_STG_T SET
            --                       record_status          = gc_process_status
            --                 WHERE ORIGINAL_SYSTEM_REFERENCE = l_header_rec_out.orig_sys_document_ref ;

            COMMIT;
        ELSE
            IF (l_debug_level > 0)
            THEN
                FOR i IN 1 .. l_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_data
                                    , p_msg_index_out => l_msg_index);
                    log_records (gc_debug_flag, 'message is: ' || l_data);
                    log_records (gc_debug_flag,
                                 'message index is: ' || l_msg_index);
                END LOOP;
            END IF;

            ROLLBACK;
        --                  UPDATE XXD_ONT_SO_LINES_CONV_STG_T SET
        --                       RECORD_STATUS       = gc_error_status
        --                 WHERE ORIG_SYS_DOCUMENT_REF  = l_header_rec_out.orig_sys_document_ref ;
        --
        --         UPDATE XXD_ONT_SO_HEADERS_CONV_STG_T SET
        --                       record_status          = gc_error_status
        --                 WHERE ORIGINAL_SYSTEM_REFERENCE = l_header_rec_out.orig_sys_document_ref ;
        --        COMMIT;
        END IF;

        log_records (gc_debug_flag,
                     '****************************************************');

        /*****************DISPLAY RETURN STATUS FLAGS******************************/
        IF (l_debug_level > 0)
        THEN
            log_records (gc_debug_flag,
                         'process ORDER ret status IS: ' || l_return_status);
            log_records (gc_debug_flag,
                         'process ORDER msg data IS: ' || l_msg_data);
            log_records (gc_debug_flag,
                         'process ORDER msg COUNT IS: ' || l_msg_count);
            log_records (
                gc_debug_flag,
                   'header.order_number IS: '
                || TO_CHAR (l_header_rec_out.order_number));
            --  DBMS_OUTPUT.put_line ('adjustment.return_status IS: '
            --                    || l_line_adj_tbl_out (1).return_status);
            log_records (
                gc_debug_flag,
                'header.header_id IS: ' || l_header_rec_out.header_id);
            log_records (
                gc_debug_flag,
                   'line.unit_selling_price IS: '
                || l_line_tbl_out (1).unit_selling_price);
        END IF;

        /*****************DISPLAY ERROR MSGS*************************************/
        IF (l_debug_level > 0)
        THEN
            FOR i IN 1 .. l_msg_count
            LOOP
                oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_data
                                , p_msg_index_out => l_msg_index);
                log_records (gc_debug_flag, 'message is: ' || l_data);
                log_records (gc_debug_flag,
                             'message index is: ' || l_msg_index);
            END LOOP;
        END IF;

        IF (l_debug_level > 0)
        THEN
            log_records (gc_debug_flag, 'Debug = ' || oe_debug_pub.g_debug);
            log_records (
                gc_debug_flag,
                'Debug Level = ' || TO_CHAR (oe_debug_pub.g_debug_level));
            log_records (
                gc_debug_flag,
                'Debug File = ' || oe_debug_pub.g_dir || '/' || oe_debug_pub.g_file);
            log_records (
                gc_debug_flag,
                '****************************************************');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RAISE;
    END create_reservation;

    PROCEDURE release_hold (p_header_id IN NUMBER)
    AS
        l_order_tbl        oe_holds_pvt.order_tbl_type;
        l_return_status    VARCHAR2 (30);
        l_msg_data         VARCHAR2 (256);
        l_msg_count        NUMBER;

        l_debug_file       VARCHAR2 (200);
        l_debug_level      NUMBER := 1;              -- OM DEBUG LEVEL (MAX 5)
        l_org              NUMBER := 87;
        l_msg_index        NUMBER;
        l_data             VARCHAR2 (2000);
        l_user_id          NUMBER := -1;
        l_resp_id          NUMBER := -1;
        l_application_id   NUMBER := -1;

        l_user_name        VARCHAR2 (30) := 'PVADREVU001';
        l_resp_name        VARCHAR2 (30) := 'ORDER_MGMT_SU_US';
    BEGIN
        -- Get the user_id
        SELECT user_id
          INTO l_user_id
          FROM fnd_user
         WHERE user_name = l_user_name;

        -- Get the application_id and responsibility_id
        SELECT application_id, responsibility_id
          INTO l_application_id, l_resp_id
          FROM fnd_responsibility
         WHERE responsibility_key = l_resp_name;

        DBMS_APPLICATION_INFO.set_client_info (l_org);

        /*****************INITIALIZE DEBUG INFO*************************************/
        IF (l_debug_level > 0)
        THEN
            --      l_debug_file := oe_debug_pub.set_debug_mode ('FILE');
            --      oe_debug_pub.initialize;
            --      oe_debug_pub.setdebuglevel (l_debug_level);
            oe_msg_pub.initialize;
        END IF;

        /*****************INITIALIZE ENVIRONMENT*************************************/
        fnd_global.apps_initialize (l_user_id, l_resp_id, l_application_id); -- pass in user_id, responsibility_id, and application_id
        mo_global.init ('ONT');                            -- Required for R12
        mo_global.set_policy_context ('S', 87);            -- Required for R12
        /*****************INITIALIZE HEADER RECORD******************************/

        --oe_debug_pub.initialize;
        --oe_debug_pub.setdebuglevel(1);
        oe_msg_pub.initialize;

        l_order_tbl (1).header_id   := p_header_id;

        --OE_DEBUG_PUB.Add('Just before calling OE_Holds_PUB.Apply_Holds:' );

        oe_holds_pub.release_holds (
            p_api_version           => 1.0,
            p_order_tbl             => l_order_tbl,
            p_hold_id               => 17034,
            p_release_reason_code   => 'MANUAL_RELEASE_MARGIN_HOLD',
            p_release_comment       => 'Test',
            x_return_status         => l_return_status,
            x_msg_count             => l_msg_count,
            x_msg_data              => l_msg_data);

        --OE_DEBUG_PUB.Add('Just after calling OE_Holds_PUB.Apply_Holds:');

        -- Check Return Status
        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            log_records (gc_debug_flag, 'success');
            COMMIT;
        ELSE
            log_records (gc_debug_flag, 'failure');
            ROLLBACK;
        END IF;

        FOR i IN 1 .. l_msg_count
        LOOP
            oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_data
                            , p_msg_index_out => l_msg_index);
            log_records (gc_debug_flag, 'message is: ' || l_data);
            log_records (gc_debug_flag, 'message index is: ' || l_msg_index);
        END LOOP;

        -- Display Return Status
        log_records (gc_debug_flag,
                     'process ORDER ret status IS: ' || l_return_status);
        log_records (gc_debug_flag,
                     'process ORDER msg data IS: ' || l_msg_data);
        log_records (gc_debug_flag,
                     'process ORDER msg COUNT IS: ' || l_msg_count);
    --OE_DEBUG_PUB.DEBUG_OFF;

    END release_hold;

    --This procedure is used to cancel sales order line
    PROCEDURE apply_hold_header_line (p_orig_sys_document_ref IN VARCHAR2, p_line_id IN NUMBER, x_return_status OUT VARCHAR2)
    IS
        ln_api_version_number          NUMBER := 1;
        lc_return_status               VARCHAR2 (10);
        ln_msg_count                   NUMBER;
        ln_hold_id                     NUMBER;
        ln_header_id                   NUMBER;
        lc_flow_status_code            VARCHAR2 (60);
        lc_activity_name               VARCHAR2 (60);
        lc_msg_data                    VARCHAR2 (2000);
        lc_error_message               VARCHAR2 (2000);
        ln_cnt                         NUMBER;
        lc_order_number                VARCHAR2 (60);
        l_msg_index                    NUMBER;

        ln_line_count                  NUMBER;
        ln_header_count                NUMBER;
        ex_exception                   EXCEPTION;
        -- INPUT VARIABLES FOR PROCESS_ORDER API
        l_header_rec                   oe_order_pub.header_rec_type
                                           := oe_order_pub.g_miss_header_rec;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        -- OUT VARIABLES FOR PROCESS_ORDER API
        l_header_rec_out               oe_order_pub.header_rec_type;
        l_header_val_rec_out           oe_order_pub.header_val_rec_type;
        l_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        l_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        l_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        l_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        l_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        l_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        l_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        l_line_tbl_out                 oe_order_pub.line_tbl_type;
        l_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        l_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        l_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        l_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        l_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        l_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        l_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        l_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        l_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        l_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        l_action_request_tbl_out       oe_order_pub.request_tbl_type;
    BEGIN
        -- INITIALIZE ENVIRONMENT

        --    fnd_global.apps_initialize(user_id      => p_user_id,
        --                           resp_id          => p_resp_id,
        --                           resp_appl_id     => p_resp_app_id);
        --    mo_global.set_policy_context('S', p_org_id);
        --    mo_global.init('ONT');
        log_records (gc_debug_flag,
                     'Calling apply_hold_header_line Order API');

        FOR holds IN (SELECT *
                        FROM xxd_1206_order_holds_t
                       WHERE orig_sys_document_ref = p_orig_sys_document_ref)
        LOOP
            lc_error_message   := NULL;
            ln_cnt             := 0;

            --Get hold id
            BEGIN
                ln_hold_id         := NULL;
                ln_header_id       := NULL;
                lc_activity_name   := NULL;
                lc_order_number    := NULL;
                log_records (
                    gc_debug_flag,
                    'Calling holds.hold_name Order API' || holds.hold_name);

                SELECT hold_id, DECODE (activity_name, 'BOOK_ORDER', 'BOOKED', 'XXXXX')
                  INTO ln_hold_id, lc_activity_name
                  FROM oe_hold_definitions
                 WHERE name = holds.hold_name;

                log_records (
                    gc_debug_flag,
                    'Calling holds.hold_name Order API' || holds.orig_sys_document_ref);

                SELECT flow_status_code, order_number, header_id
                  INTO lc_flow_status_code, lc_order_number, ln_header_id
                  FROM oe_order_headers_all
                 WHERE orig_sys_document_ref = holds.orig_sys_document_ref;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    log_records (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                               'The hold '
                            || holds.hold_name
                            || ' is not defined');
                    lc_error_message   :=
                        'The hold ' || holds.hold_name || ' is not defined';
                    ln_hold_id   := NULL;
                    RAISE ex_exception;
                WHEN OTHERS
                THEN
                    log_records (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                            'Error while getting hold id:' || SQLERRM);
                    lc_error_message   :=
                        'Error while getting hold id:' || SQLERRM;
                    ln_hold_id   := NULL;
                    RAISE ex_exception;
            END;

            log_records (
                gc_debug_flag,
                   'Calling holds.lc_activity_name Order API'
                || lc_activity_name);

            IF NVL (lc_activity_name, 'XXXXX') = lc_flow_status_code
            THEN
                lc_error_message   :=
                       lc_error_message
                    || ' Hold On Workflow Activity, Book Order Is Not Applicable To The Sales Order - '
                    || lc_order_number
                    || '. ';
                xxd_common_utils.record_error (
                    'ONT',
                    gn_org_id,
                    'Deckers Ecomm Open Sales Order Conversion Program',
                    --      SQLCODE,
                    'APPLY_HOLD_HEADER_LINE' || lc_error_message,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --    SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'ORDER NUMBER',
                    lc_order_number);
            ELSE
                --This is to apply hold an order header or line
                ln_cnt                                       := ln_cnt + 1;
                l_header_rec                                 := oe_order_pub.g_miss_header_rec;
                l_action_request_tbl (ln_cnt)                :=
                    oe_order_pub.g_miss_request_rec;
                l_action_request_tbl (ln_cnt).entity_id      := ln_header_id;
                l_action_request_tbl (ln_cnt).entity_code    :=
                    oe_globals.g_entity_header;
                l_action_request_tbl (ln_cnt).request_type   :=
                    oe_globals.g_apply_hold;
                l_action_request_tbl (ln_cnt).param1         := ln_hold_id; -- hold_id
                l_action_request_tbl (ln_cnt).param2         := 'O'; -- indicator that it is an order hold
                l_action_request_tbl (ln_cnt).param3         := ln_header_id; -- Header or LINE ID of the order
                l_action_request_tbl (ln_cnt).param4         :=
                    holds.hold_comment;                       -- hold comments
            --           l_action_request_tbl (ln_cnt).date_param1  := holds.hold_until_date; -- hold until date
            END IF;
        END LOOP;

        log_records (
            gc_debug_flag,
               'Calling l_action_request_tbl.count Order API'
            || l_action_request_tbl.COUNT);

        IF l_action_request_tbl.COUNT > 0
        THEN
            oe_msg_pub.initialize;
            -- CALL TO PROCESS Order
            oe_order_pub.process_order (
                p_operating_unit           => NULL,
                p_api_version_number       => ln_api_version_number,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                x_header_rec               => l_header_rec_out,
                x_header_val_rec           => l_header_val_rec_out,
                x_header_adj_tbl           => l_header_adj_tbl_out,
                x_header_adj_val_tbl       => l_header_adj_val_tbl_out,
                x_header_price_att_tbl     => l_header_price_att_tbl_out,
                x_header_adj_att_tbl       => l_header_adj_att_tbl_out,
                x_header_adj_assoc_tbl     => l_header_adj_assoc_tbl_out,
                x_header_scredit_tbl       => l_header_scredit_tbl_out,
                x_header_scredit_val_tbl   => l_header_scredit_val_tbl_out,
                x_line_tbl                 => l_line_tbl_out,
                x_line_val_tbl             => l_line_val_tbl_out,
                x_line_adj_tbl             => l_line_adj_tbl_out,
                x_line_adj_val_tbl         => l_line_adj_val_tbl_out,
                x_line_price_att_tbl       => l_line_price_att_tbl_out,
                x_line_adj_att_tbl         => l_line_adj_att_tbl_out,
                x_line_adj_assoc_tbl       => l_line_adj_assoc_tbl_out,
                x_line_scredit_tbl         => l_line_scredit_tbl_out,
                x_line_scredit_val_tbl     => l_line_scredit_val_tbl_out,
                x_lot_serial_tbl           => l_lot_serial_tbl_out,
                x_lot_serial_val_tbl       => l_lot_serial_val_tbl_out,
                x_action_request_tbl       => l_action_request_tbl_out,
                x_return_status            => lc_return_status,
                x_msg_count                => ln_msg_count,
                x_msg_data                 => lc_msg_data);
            -- CHECK RETURN STATUS
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => ' lc_return_status - ' || lc_return_status);
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       ' lc_msg_data - '
                    || lc_msg_data
                    || ' -- ln_msg_count - '
                    || ln_msg_count);

            /*****************CHECK RETURN STATUS***********************************/
            IF lc_return_status = fnd_api.g_ret_sts_success
            THEN
                log_records (gc_debug_flag, 'success');
                log_records (
                    gc_debug_flag,
                    'header.order_number IS: ' || TO_CHAR (lc_order_number));
            ELSE
                FOR i IN 1 .. ln_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                    , p_msg_index_out => l_msg_index);
                    log_records (gc_debug_flag,
                                 'message is: ' || lc_msg_data);
                    log_records (gc_debug_flag,
                                 'message index is: ' || l_msg_index);

                    xxd_common_utils.record_error (
                        'ONT',
                        gn_org_id,
                        'Deckers Ecomm Open Sales Order Conversion Program',
                        --      SQLCODE,
                        'APPLY_HOLD_HEADER_LINE =>' || lc_msg_data,
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --    SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        'ORDER NUMBER',
                        lc_order_number);
                END LOOP;
            END IF;

            log_records (
                gc_debug_flag,
                '****************************************************');
            /*****************DISPLAY RETURN STATUS FLAGS******************************/

            log_records (gc_debug_flag,
                         'process ORDER ret status IS: ' || lc_return_status);
            log_records (gc_debug_flag,
                         'process ORDER msg data IS: ' || lc_msg_data);
            log_records (gc_debug_flag,
                         'process ORDER msg COUNT IS: ' || ln_msg_count);
            log_records (
                gc_debug_flag,
                   'header.order_number IS: '
                || TO_CHAR (l_header_rec_out.order_number));
        END IF;

        x_return_status   := lc_return_status;
    EXCEPTION
        WHEN ex_exception
        THEN
            x_return_status   := 'E';
            log_records (
                gc_debug_flag,
                'Calling holds.lc_activity_name Order API' || SQLERRM);
        WHEN OTHERS
        THEN
            log_records (
                gc_debug_flag,
                'Calling holds.lc_activity_name Order API' || SQLERRM);
            x_return_status   := 'E';
    END apply_hold_header_line;

    -- ========================================================================= --
    --                                                                           --
    -- PROCEDURE      :  pick_confirm                                            --
    --                                                                           --
    -- Description    :  This procedure will be called                           --
    --                   from process_record_prc                                 --
    --                                                                           --
    -- Parameters     :                                                          --
    --                                                                           --
    -- Parameter Name      Mode Type       Description                           --
    -- --------------      ---- --------   ----------------                      --
    --                                                                           --
    -- ========================================================================= --
    /* procedure pick_confirm(p_sch_ship_date in date,
                            x_return_mesg   out varchar2,
                            x_return_sts    out varchar2) is
       lv_trolin_tbl       inv_move_order_pub.trolin_tbl_type;
       lv_mold_tbl         inv_mo_line_detail_util.g_mmtt_tbl_type;
       x_mmtt_tbl          inv_mo_line_detail_util.g_mmtt_tbl_type;
       x_trolin_tbl        inv_move_order_pub.trolin_tbl_type;
       lv_transaction_date date := sysdate;
       ln_mo_line_id       number;

       lc_msg_data        varchar2(2000);
       lc_x_msg_data      varchar2(2000);
       ln_x_msg_count     number;
       lc_x_return_status varchar2(1);
       lc_msg_index_out   number;
       log_msg            varchar2(4000);

       -----------------------------------------------------
       -- Cursor to get delivery detail id to process pick confirm
       -----------------------------------------------------
       cursor cur_get_details(p_sch_shiping_date date) is
         select rowid, a.*
           from xxd_ont_ship_confirm_conv_tbl a
          where status = gc_validate_status
            and request_id = gn_conc_request_id
            and released_status = 'S'
            and trunc(sch_ship_date) = trunc(p_sch_shiping_date);
     begin
       x_return_sts := gc_api_success;
       log_msg      := 'Start of Procedure pick_confirm ';
       --    log_msg := (GC_SOURCE_PROGRAM);
       log_records(p_debug => gc_debug_flag, p_message => log_msg);

       -- open the cursor to transact move order
       for get_move_rec in cur_get_details(p_sch_ship_date) loop
         ln_mo_line_id      := null;
         x_return_mesg      := null;
         lc_x_return_status := null;
         ln_x_msg_count     := null;
         lc_x_msg_data      := null;
         lc_msg_index_out   := null;

         -- Fetch the Move Order Line ID for the delivery detail ID
         --
         begin
           select move_order_line_id
             into ln_mo_line_id
             from wsh_delivery_details
            where delivery_detail_id = get_move_rec.delivery_detail_id
              and trunc(date_scheduled) = trunc(get_move_rec.sch_ship_date);
         exception
           when no_data_found then
             --FND_FILE.PUT_LINE(FND_FILE.LOG,'in exception getting line mover order');
             x_return_mesg := 'No Data found while Fetching Move Order Line ID for delivery detail_id: ' ||
                              get_move_rec.delivery_detail_id || ' Error:' ||
                              sqlerrm;
             fnd_file.put_line(fnd_file.log, x_return_mesg);
           when others then
             --FND_FILE.PUT_LINE(FND_FILE.LOG,'others in exception getting line mover order');
             x_return_mesg := 'Error while Fetching the Move Order Line ID for delivery detail_id: ' ||
                              get_move_rec.delivery_detail_id || ' Error:' ||
                              sqlerrm;
             fnd_file.put_line(fnd_file.log, x_return_mesg);
         end;

         if ln_mo_line_id is not null then
           log_msg := (' Transact move order for move order line ID: ' ||
                      ln_mo_line_id || ' delivery detail id ' ||
                      get_move_rec.delivery_detail_id);
           log_records(p_debug => gc_debug_flag, p_message => log_msg);

           lv_trolin_tbl(1).line_id := ln_mo_line_id;

           ---------------------------------------
           -- Calling Move Order Transact API
           ---------------------------------------
           inv_pick_wave_pick_confirm_pub.pick_confirm(p_api_version_number => 1.0,
                                                       p_init_msg_list      => fnd_api.g_false,
                                                       p_commit             => fnd_api.g_false,
                                                       x_return_status      => lc_x_return_status,
                                                       x_msg_count          => ln_x_msg_count,
                                                       x_msg_data           => lc_x_msg_data,
                                                       p_move_order_type    => 1,
                                                       p_transaction_mode   => 1,
                                                       p_trolin_tbl         => lv_trolin_tbl,
                                                       p_mold_tbl           => lv_mold_tbl,
                                                       x_mmtt_tbl           => x_mmtt_tbl,
                                                       x_trolin_tbl         => x_trolin_tbl,
                                                       p_transaction_date   => p_sch_ship_date);

           if lc_x_return_status <> 'S' then
             -- Retrieve the error
             for i in 1 .. ln_x_msg_count loop
               fnd_msg_pub.get(p_msg_index     => i,
                               p_encoded       => 'F',
                               p_data          => lc_msg_data,
                               p_msg_index_out => lc_msg_index_out);

               x_return_mesg := ' API Error while Transacting Move Order: ' ||
                                lc_msg_data;
               log_msg       := (x_return_mesg);
               log_records(p_debug => gc_debug_flag, p_message => log_msg);
             end loop;

             ------------------------------------------------
             -- Update the status on staging table
             ------------------------------------------------
             begin
               update xxd_ont_ship_confirm_conv_tbl
                  set status = gc_error_status, error_message = x_return_mesg
                where request_id = gn_conc_request_id
                  and status = gc_validate_status
                  and trunc(sch_ship_date) = trunc(get_move_rec.sch_ship_date)
                  and delivery_detail_id = get_move_rec.delivery_detail_id;
             exception
               when others then
                 x_return_mesg := 'In pick confirm, While update header table status Error  ' ||
                                  sqlerrm;
                 x_return_sts  := gc_error_status;
                 fnd_file.put_line(fnd_file.log,
                                   'Error Status ' || x_return_sts ||
                                   ' ,Error message ' || x_return_mesg);
             end;

             log_msg      := ('After call to Transacting Move Order status is ' ||
                             gc_error_status);
             x_return_sts := gc_error_status;
             log_records(p_debug => gc_debug_flag, p_message => log_msg);
           else
             ------------------------------------------------
             -- Update the status on staging table
             ------------------------------------------------
             begin
               update xxd_ont_ship_confirm_conv_tbl
                  set released_status = 'Y'
                where request_id = gn_conc_request_id
                  and status = gc_validate_status
                  and trunc(sch_ship_date) = trunc(get_move_rec.sch_ship_date)
                  and delivery_detail_id = get_move_rec.delivery_detail_id;
             exception
               when others then
                 x_return_mesg := 'In pick confirm,While update header table status success  ' ||
                                  sqlerrm;
                 x_return_sts  := gc_error_status;
                 fnd_file.put_line(fnd_file.log,
                                   'Error Status ' || x_return_sts ||
                                   ' ,Error message ' || x_return_mesg);
             end;

             log_msg      := ('After Transacting Move Order status is  ' ||
                             lc_x_return_status);
             x_return_sts := lc_x_return_status;
             log_records(p_debug => gc_debug_flag, p_message => log_msg);
           end if; -- IF lc_x_return_status <> 'S' THEN
         else
           ------------------------------------------------
           -- Update the status on staging table
           ------------------------------------------------
           begin
             update xxd_ont_ship_confirm_conv_tbl
                set status        = gc_error_status,
                    error_message = 'Transact Move Order is failed , Move Order line id is missing'
              where request_id = gn_conc_request_id
                and status = gc_validate_status
                and trunc(sch_ship_date) = trunc(get_move_rec.sch_ship_date)
                and delivery_detail_id = get_move_rec.delivery_detail_id;
           exception
             when others then
               x_return_mesg := 'In pick confirm,While update header table status to error message  ' ||
                                sqlerrm;
               x_return_sts  := gc_error_status;
               fnd_file.put_line(fnd_file.log,
                                 'Error Status ' || x_return_sts ||
                                 ' ,Error message ' || x_return_mesg);
           end;

           log_msg      := ('Transacting Move Order line status is ' ||
                           gc_error_status);
           x_return_sts := gc_error_status;
           log_records(p_debug => gc_debug_flag, p_message => log_msg);
         end if; -- IF ln_mo_line_id IS NOT NULL THEN
       end loop;

       commit;
       log_msg := 'End of Procedure pick_confirm ';
       --    log_msg := (GC_SOURCE_PROGRAM);
       log_records(p_debug => gc_debug_flag, p_message => log_msg);
     exception
       when others then
         x_return_mesg := 'The procedure pick_confirm Failed  ' || sqlerrm;
         x_return_sts  := gc_error_status;
         fnd_file.put_line(fnd_file.log,
                           'Error Status ' || x_return_sts ||
                           ' ,Error message ' || x_return_mesg);
         raise_application_error(-20003, sqlerrm);
     end pick_confirm;*/

    -- ========================================================================= --
    --                                                                           --
    -- PROCEDURE      :  Ship_confirm                                            --
    --                                                                           --
    -- Description    :  This procedure will be called                           --
    --                   from process_record_prc                                 --
    --                                                                           --
    -- Parameters     :                                                          --
    --                                                                           --
    -- Parameter Name      Mode Type       Description                           --
    -- --------------      ---- --------   ----------------                      --
    --                                                                           --
    -- ========================================================================= --
    /* procedure ship_confirm(p_sch_ship_date in date,
                            x_return_mesg   out varchar2,
                            x_return_sts    out varchar2) is
       lc_x_msg_data             varchar2(2000);
       ln_x_msg_count            number;
       lc_x_return_status        varchar2(1);
       x_trip_id                 wsh_trips.trip_id%type;
       x_trip_name               wsh_trips.name%type;
       lc_msg_index_out          number;
       ln_ship_confirm_rule_id   number;
       lc_ship_confirm_rule_name varchar2(2000);
       error_exception exception;
       x_msg_details  varchar2(4000);
       x_msg_summary  varchar2(4000);
       l_msg_count    number;
       ln_delivery_id number;
       log_msg        varchar2(4000);

       -----------------------------------------------------
       -- Cursor to get delivery id to process ship confirm
       -----------------------------------------------------
       cursor cur_get_details(p_sch_shiping_date date) is
         select distinct delivery_id, ship_from_org_id
           from xxd_ont_ship_confirm_conv_tbl a
          where status = gc_validate_status
            and request_id = gn_conc_request_id
            and released_status = 'Y'
            and trunc(sch_ship_date) = trunc(p_sch_shiping_date);
     begin
       x_return_sts := gc_api_success;
       log_msg      := 'Start of Procedure Ship_confirm ';
       --    log_msg := (GC_SOURCE_PROGRAM);
       log_records(p_debug => gc_debug_flag, p_message => log_msg);

       ------------------------------------------------
       -- Open cursor and pass variables
       ------------------------------------------------
       for ship_rec in cur_get_details(p_sch_ship_date) loop
         ln_ship_confirm_rule_id   := null;
         lc_ship_confirm_rule_name := null;
         x_msg_details             := null;
         x_msg_summary             := null;
         x_return_mesg             := null;
         lc_x_return_status        := null;
         ln_x_msg_count            := null;
         lc_x_msg_data             := null;

         -----------------------------
         -- derive ship confirm rule
         ----------------------------
         begin
           select wsr.ship_confirm_rule_id, wsr.name
             into ln_ship_confirm_rule_id, lc_ship_confirm_rule_name
             from wsh_ship_confirm_rules_v wsr, wsh_shipping_parameters wsp
            where wsp.organization_id = ship_rec.ship_from_org_id
              and wsr.ship_confirm_rule_id = wsp.ship_confirm_rule_id
              and nvl(effective_start_date, trunc(sysdate)) <= trunc(sysdate)
              and nvl(effective_end_date, trunc(sysdate)) >= trunc(sysdate);
         exception
           when others then
             x_return_mesg := 'Error while Fetching the Ship confirm rule: for Delivery Detail id ' ||
                              ship_rec.delivery_id || ' Error:' || sqlerrm;
             fnd_file.put_line(fnd_file.log, x_return_mesg);

             ------------------------------------------------
             -- Update the status on staging table
             ------------------------------------------------
             begin
               update xxd_ont_ship_confirm_conv_tbl
                  set status = gc_error_status, error_message = x_return_mesg
                where request_id = gn_conc_request_id
                  and status = gc_validate_status
                  and trunc(sch_ship_date) = p_sch_ship_date
                  and delivery_id = ship_rec.delivery_id;
             exception
               when others then
                 x_return_mesg := 'During Ship confirm rule, update table to error ' ||
                                  sqlerrm;
                 x_return_sts  := gc_error_status;
                 fnd_file.put_line(fnd_file.log,
                                   'Error Status ' || x_return_sts ||
                                   ' ,Error message ' || x_return_mesg);
             end;
         end;

         if ship_rec.delivery_id is not null and
            ln_ship_confirm_rule_id is not null then
           log_msg := (' Ship confirm for Delivery id  ' ||
                      ship_rec.delivery_id);
           log_records(p_debug => gc_debug_flag, p_message => log_msg);

           ---------------------------------------
           -- Call API to Ship Confirm
           ---------------------------------------
           wsh_deliveries_pub.delivery_action(p_api_version_number => 1.0,
                                              p_init_msg_list      => fnd_api.g_false,
                                              x_return_status      => lc_x_return_status,
                                              x_msg_count          => ln_x_msg_count,
                                              x_msg_data           => lc_x_msg_data,
                                              p_action_code        => 'CONFIRM',
                                              p_delivery_id        => ship_rec.delivery_id,
                                              p_delivery_name      => to_char(ship_rec.delivery_id),
                                              p_sc_action_flag     => 'S',
                                              p_sc_close_trip_flag => 'Y',
                                              p_sc_actual_dep_date => p_sch_ship_date,
                                              x_trip_id            => x_trip_id,
                                              x_trip_name          => x_trip_name,
                                              p_sc_rule_id         => ln_ship_confirm_rule_id,
                                              p_sc_rule_name       => lc_ship_confirm_rule_name);

           -- Check for API status
           if lc_x_return_status not in ('S', 'W') then
             fnd_file.put_line(fnd_file.log,
                               'After Call 1 to Ship confirm for Delivery id  ' ||
                               ship_rec.delivery_id);

             wsh_util_core.get_messages(p_init_msg_list => 'Y',
                                        x_summary       => x_msg_summary,
                                        x_details       => x_msg_details,
                                        x_count         => ln_x_msg_count);

             if l_msg_count > 1 then
               x_return_mesg := 'API Error in Ship Confirming: ' ||
                                x_msg_summary || x_msg_details;
               log_msg       := (x_return_mesg);
               log_records(p_debug => gc_debug_flag, p_message => log_msg);
             else
               x_return_mesg := 'API Error while Ship Confirming :' ||
                                x_msg_summary;
               log_msg       := (x_return_mesg);
               log_records(p_debug => gc_debug_flag, p_message => log_msg);
             end if;

             fnd_file.put_line(fnd_file.log,
                               'status ' || lc_x_return_status || ' ' ||
                               x_return_mesg);

             ------------------------------------------------
             -- Update the status on staging table
             ------------------------------------------------
             begin
               update xxd_ont_ship_confirm_conv_tbl
                  set status = gc_error_status, error_message = x_return_mesg
                where request_id = gn_conc_request_id
                  and status = gc_validate_status
                  and trunc(sch_ship_date) = p_sch_ship_date
                  and delivery_id = ship_rec.delivery_id;
             exception
               when others then
                 x_return_mesg := 'During Ship confirm, update table to error ' ||
                                  sqlerrm;
                 x_return_sts  := gc_error_status;
                 fnd_file.put_line(fnd_file.log,
                                   'Error Status ' || x_return_sts ||
                                   ' ,Error message ' || x_return_mesg);
             end;
           else
             ------------------------------------------------
             -- Update the status on staging table
             ------------------------------------------------
             begin
               update xxd_ont_ship_confirm_conv_tbl
                  set released_status = 'C', status = gc_processed
                where request_id = gn_conc_request_id
                  and status = gc_validate_status
                  and trunc(sch_ship_date) = p_sch_ship_date
                  and delivery_id = ship_rec.delivery_id;
             exception
               when others then
                 x_return_mesg := 'During Ship confirm, update table to success  ' ||
                                  sqlerrm;
                 x_return_sts  := gc_error_status;
                 fnd_file.put_line(fnd_file.log,
                                   'Error Status ' || x_return_sts ||
                                   ' ,Error message ' || x_return_mesg);
             end;
           end if; -- IF lc_x_return_status NOT IN ( 'S','W') THEN
         else
           log_msg := ('After Calling to Ship confirm for Delivery id ' ||
                      ship_rec.delivery_id);
           log_records(p_debug => gc_debug_flag, p_message => log_msg);

           x_return_mesg := 'Delivery did not happen for Delivery details ';

           ------------------------------------------------
           -- Update the status on staging table
           ------------------------------------------------
           begin
             update xxd_ont_ship_confirm_conv_tbl
                set status = gc_error_status, error_message = x_return_mesg
              where request_id = gn_conc_request_id
                and status = gc_validate_status
                and trunc(sch_ship_date) = p_sch_ship_date
                and delivery_id is null;
           exception
             when others then
               x_return_mesg := 'During Ship confirm, update table to error delivery id is missing ' ||
                                sqlerrm;
               x_return_sts  := gc_error_status;
               fnd_file.put_line(fnd_file.log,
                                 'Error Status ' || x_return_sts ||
                                 ' ,Error message ' || x_return_mesg);
           end;
         end if; -- IF ship_rec.delivery_id IS NOT NULL

         log_msg := ('Ship Confirm status ' || lc_x_return_status);
         log_records(p_debug => gc_debug_flag, p_message => log_msg);
       end loop; -- FOR ship_rec IN cur_get_details (p_sch_ship_date)

       commit;
       log_msg := 'End of Procedure Ship_confirm ';
       --    log_msg := (  GC_SOURCE_PROGRAM);
       log_records(p_debug => gc_debug_flag, p_message => log_msg);
     exception
       when error_exception then
         x_return_mesg := x_return_mesg;
         x_return_sts  := gc_error_status;
         fnd_file.put_line(fnd_file.log,
                           'Error Status ' || x_return_sts ||
                           ' ,Error message ' || x_return_mesg);
       when others then
         x_return_mesg := 'The procedure Ship_confirm Failed  ' || sqlerrm;
         x_return_sts  := gc_error_status;
         fnd_file.put_line(fnd_file.log,
                           'Error Status ' || x_return_sts ||
                           ' ,Error message ' || x_return_mesg);
         raise_application_error(-20003, sqlerrm);
     end ship_confirm;*/

    -- ========================================================================= --
    --                                                                           --
    -- PROCEDURE      :  launch_pick_release_order                                      --
    --                                                                           --
    -- Description    :  This procedure will be called                           --
    --                   from process_record_prc                                 --
    --                                                                           --
    -- Parameters     :                                                          --
    --                                                                           --
    -- Parameter Name      Mode Type       Description                           --
    -- --------------      ---- --------   ----------------                      --
    --                                                                           --
    -- ========================================================================= --
    /* procedure launch_pick_release_order(p_sch_ship_date    in date,
                                         p_ship_from_org_id in number,
                                         p_order_header_id  in number,
                                         x_batch_id         out number,
                                         x_request_id       out number,
                                         x_return_mesg      out varchar2,
                                         x_return_sts       out varchar2) is
       -- Declarations for error messages
       lc_msg_data        varchar2(2000);
       lc_x_msg_data      varchar2(2000);
       ln_x_msg_count     number;
       lc_x_return_status varchar2(1);
       lc_msg_index_out   number;
       ln_batch_id        number;
       ln_request_id      number;
       ln_x_batch_id      number;
       error_exception exception;

       -- Api related variables
       t_line_rows wsh_util_core.id_tab_type;
       x_del_rows  wsh_util_core.id_tab_type;
       x_trip_id   wsh_trips.trip_id%type;
       x_trip_name wsh_trips.name%type;
       l_batch_rec wsh_picking_batches_pub.batch_info_rec;

       -- Declarations for wait request
       lb_req_wait   boolean;
       lc_phase      varchar2(100);
       lc_status     varchar2(30);
       lc_dev_phase  varchar2(100);
       lc_dev_status varchar2(100);
       lc_mesg       varchar2(100);
       log_msg       varchar2(4000);

       -------------------------------
       -- Get the pick rules
       ------------------------------
       cursor cur_get_pick_rule_dtl is
         select *
           from wsh_picking_rules_v
          where organization_id = p_ship_from_org_id;
       --AND    attribute1            = 'YES';

     begin
       x_return_sts := gc_api_success;
       log_records(p_debug   => gc_debug_flag,
                   p_message => 'Start of Procedure launch_pick_release_order ');

       ------------------------------------------------------------
       -- Based on Pick rules assign values to parameter
       ------------------------------------------------------------
       for pick_rule_dtl in cur_get_pick_rule_dtl loop
         log_records(p_debug   => gc_debug_flag,
                     p_message => 'Processing for Pick rule name ' ||
                                  pick_rule_dtl.picking_rule_name ||
                                  ' warehouse/ Org id ' || p_ship_from_org_id);

         lc_msg_data        := null;
         lc_x_msg_data      := null;
         ln_x_msg_count     := null;
         lc_x_return_status := null;
         lc_msg_index_out   := null;
         ln_batch_id        := null;
         ln_request_id      := null;
         ln_x_batch_id      := null;

         l_batch_rec.order_header_id          := p_order_header_id;
         l_batch_rec.auto_pick_confirm_flag   := 'N';
         l_batch_rec.autocreate_delivery_flag := pick_rule_dtl.autocreate_delivery_flag;
         l_batch_rec.from_scheduled_ship_date := to_date(trunc(p_sch_ship_date) ||
                                                         ' 00:00:00',
                                                         'DD-MON-RRRR HH24:MI:SS');
         l_batch_rec.to_scheduled_ship_date   := to_date(trunc(p_sch_ship_date) ||
                                                         ' 23:59:59',
                                                         'DD-MON-RRRR HH24:MI:SS');
         l_batch_rec.organization_code        := pick_rule_dtl.warehouse_code;

         l_batch_rec.append_flag                := pick_rule_dtl.append_flag;
         l_batch_rec.allocation_method          := pick_rule_dtl.allocation_method;
         l_batch_rec.default_stage_subinventory := pick_rule_dtl.default_stage_subinventory;
         l_batch_rec.pick_sequence_rule_id      := pick_rule_dtl.pick_sequence_rule_id;

         l_batch_rec.autodetail_pr_flag    := pick_rule_dtl.autodetail_pr_flag;
         l_batch_rec.autopack_flag         := pick_rule_dtl.autopack_flag;
         l_batch_rec.autopack_level        := pick_rule_dtl.autopack_level;
         l_batch_rec.task_planning_flag    := pick_rule_dtl.task_planning_flag;
         l_batch_rec.ac_delivery_criteria  := pick_rule_dtl.ac_delivery_criteria;
         l_batch_rec.include_planned_lines := pick_rule_dtl.include_planned_lines;

         l_batch_rec.backorders_only_flag    := 'I'; -- pick_rule_dtl.Backorders_Only_Flag;
         l_batch_rec.existing_rsvs_only_flag := 'N';
         l_batch_rec.organization_id         := pick_rule_dtl.organization_id;
         l_batch_rec.append_flag             := pick_rule_dtl.append_flag;
         l_batch_rec.task_planning_flag      := pick_rule_dtl.task_planning_flag;
         l_batch_rec.ac_delivery_criteria    := pick_rule_dtl.ac_delivery_criteria;

         ------------------------------------------------------
         -- Call API to Create one batch for each sch ship date
         ------------------------------------------------------
         wsh_picking_batches_pub.create_batch(p_api_version   => 1.0,
                                              p_init_msg_list => fnd_api.g_false,
                                              p_commit        => fnd_api.g_false,
                                              x_return_status => lc_x_return_status,
                                              x_msg_count     => ln_x_msg_count,
                                              x_msg_data      => lc_x_msg_data,
                                              p_batch_rec     => l_batch_rec,
                                              p_batch_prefix  => null,
                                              x_batch_id      => ln_x_batch_id);

         -- Check API error status
         if lc_x_return_status not in ('S', 'W') then
           -- Retrieve the error
           for i in 1 .. ln_x_msg_count loop
             fnd_msg_pub.get(p_msg_index     => i,
                             p_encoded       => 'F',
                             p_data          => lc_msg_data,
                             p_msg_index_out => lc_msg_index_out);

             x_return_mesg := ' while picking create_batch API ERROR  ' ||
                              lc_msg_data;
             log_records(p_debug => gc_debug_flag, p_message => x_return_mesg);
             raise error_exception;
           end loop;
         else
           fnd_file.put_line(fnd_file.log,
                             'The batch_id is ' || ln_x_batch_id);
           ln_batch_id := ln_x_batch_id; -- batch id

           ------------------------------------------------------------
           -- call the API to Pick release through concurrent program
           -- This will submit Pick Selectioin list Generation Program
           ------------------------------------------------------------
           wsh_picking_batches_pub.release_batch(p_api_version   => 1.0,
                                                 p_init_msg_list => fnd_api.g_true,
                                                 p_commit        => fnd_api.g_false,
                                                 x_return_status => lc_x_return_status,
                                                 x_msg_count     => ln_x_msg_count,
                                                 x_msg_data      => lc_x_msg_data,
                                                 p_batch_id      => ln_batch_id,
                                                 p_release_mode  => 'CONCURRENT',
                                                 x_request_id    => ln_request_id);

           wsh_picking_batches_pkg.commit_work;
           log_msg := (' The Request_id submitted ' || ln_request_id);
           log_records(p_debug => gc_debug_flag, p_message => log_msg);
           x_request_id := ln_request_id;

           -- Check API error status
           if lc_x_return_status not in ('S', 'W') then
             -- Retrieve the error
             for i in 1 .. ln_x_msg_count loop
               fnd_msg_pub.get(p_msg_index     => i,
                               p_encoded       => 'F',
                               p_data          => lc_msg_data,
                               p_msg_index_out => lc_msg_index_out);

               x_return_mesg := ' RELEASE_BATCH API ERROR  ' || lc_msg_data;
               log_records(p_debug   => gc_debug_flag,
                           p_message => x_return_mesg);
               raise error_exception;
             end loop;
           else
             x_return_sts := gc_api_success;
           end if;

           if ln_request_id <= 0 then
             x_return_mesg := 'Unable to submit  Pick Selectioin list Generation Program';
             log_records(p_debug => gc_debug_flag, p_message => x_return_mesg);
             raise error_exception;
           end if;

           ------------------------------------------------------------
           -- Wait until the Concurrent Request is Completed .
           ------------------------------------------------------------
           lb_req_wait := fnd_concurrent.wait_for_request(request_id => ln_request_id,
                                                          interval   => 30,
                                                          max_wait   => 0,
                                                          phase      => lc_phase,
                                                          status     => lc_status,
                                                          dev_phase  => lc_dev_phase,
                                                          dev_status => lc_dev_status,
                                                          message    => lc_mesg);

           x_return_mesg := 'Request ' || lc_dev_phase || ', Status - ' ||
                            lc_dev_status;
           log_records(p_debug => gc_debug_flag, p_message => x_return_mesg);
         end if;

         ----------------------------------------------------------
         -- Update the batch and pick selection program request id
         ----------------------------------------------------------
         update xxd_ont_ship_confirm_conv_tbl
            set batch_id = ln_x_batch_id, pick_rel_request_id = ln_request_id
          where trunc(sch_ship_date) = trunc(p_sch_ship_date)
            and header_id = p_order_header_id
            and ship_from_org_id = p_ship_from_org_id
            and released_status in ('R', 'B')
            and status = gc_validate_status
            and request_id = gn_conc_request_id;
       end loop; -- FOR pick_rule_dtl IN cur_get_pick_rule_dtl

       commit;

       log_records(p_debug   => gc_debug_flag,
                   p_message => 'End of Procedure launch_pick_release_order ');
     exception
       when error_exception then
         x_return_mesg := x_return_mesg;
         x_return_sts  := gc_error_status;
         fnd_file.put_line(fnd_file.log,
                           'Error Status ' || x_return_sts ||
                           ' ,Error message ' || x_return_mesg);
         --ROLLBACK;

       when others then
         x_return_mesg := 'The procedure launch_pick_release Failed  ' ||
                          sqlerrm;
         x_return_sts  := gc_error_status;
         fnd_file.put_line(fnd_file.log,
                           'Error Status ' || x_return_sts ||
                           ' ,Error message ' || x_return_mesg);
         raise_application_error(-20003, sqlerrm);
     end launch_pick_release_order;*/

    -- ========================================================================= --
    --                                                                           --
    -- PROCEDURE      :  validate_record_prc                                     --
    --                                                                           --
    -- Description    :  This procedure will be called                           --
    --                   from imnport_main_prc                                   --
    --                                                                           --
    -- Parameters     :                                                          --
    --                                                                           --
    -- Parameter Name      Mode Type       Description                           --
    -- --------------      ---- --------   ----------------                      --
    --                                                                           --
    -- ========================================================================= --
    /* procedure validate_record_prc(x_return_mesg out varchar2,
                                   x_return_sts  out varchar2) is
       ------------------------------
       -- get the data for Validation
       ------------------------------
       cursor cur_validate_details is
         select rowid, a.*
           from xxd_ont_ship_confirm_conv_tbl a
          where status = gc_new
            and request_id = gn_conc_request_id;

       ---
       -- Declarion of variables
       ----

       inv_period_status       varchar2(30);
       lc_error_mesg           varchar2(4000);
       lc_concat_error_message varchar2(4000);
       lc_err_sts              varchar2(2);
       error_exception exception;
       log_msg varchar2(4000);
     begin
       x_return_sts := gc_api_success;
       log_records(p_debug   => gc_debug_flag,
                   p_message => 'Start of Procedure validate_record_prc ');

       -- open validation cursor
       for val_rec in cur_validate_details loop
         lc_err_sts              := gc_api_success;
         lc_concat_error_message := null;
         lc_error_mesg           := null;

         -------------------------------------
         -- Check for sch ship date
         -------------------------------------
         if val_rec.sch_ship_date is null then
           lc_err_sts              := gc_api_error;
           lc_error_mesg           := 'The Schedule Ship Date is null for Order Number ' ||
                                      val_rec.order_number || ' AND line id ' ||
                                      val_rec.line_id;
           lc_concat_error_message := lc_concat_error_message || ' ' ||
                                      lc_error_mesg;
         else
           -----------------------------------------------------------------------
           -- Derive inv period status for sch ship date
           -----------------------------------------------------------------------
           begin
             select upper(status)
               into inv_period_status
               from org_acct_periods_v
              where ((rec_type = 'ORG_PERIOD' and
                    organization_id = val_rec.ship_from_org_id and
                    start_date <= trunc(val_rec.sch_ship_date) and
                    end_date >= trunc(val_rec.sch_ship_date)) or
                    (rec_type = 'GL_PERIOD' and
                    period_set_name = 'Accounting' and
                    accounted_period_type = '1' and
                    (period_year, period_name) not in
                    (select period_year, period_name
                         from org_acct_periods
                        where organization_id = val_rec.ship_from_org_id) and
                    start_date <= trunc(val_rec.sch_ship_date) and
                    end_date >= trunc(val_rec.sch_ship_date)))
              order by end_date desc;
           exception
             when others then
               x_return_mesg := 'Error while Fetching INV periods for the order number ' ||
                                val_rec.order_number || ' AND line id ' ||
                                val_rec.line_id || ' - ' || sqlerrm;
               fnd_file.put_line(fnd_file.log, x_return_mesg);
               raise error_exception;
           end;

           -------------------------------------
           -- Check for Inv period status
           -------------------------------------
           if inv_period_status <> 'OPEN' then
             lc_err_sts              := gc_api_error;
             lc_error_mesg           := 'The Inventory Period is not in Open status for order number ' ||
                                        val_rec.order_number ||
                                        ' AND line id ' || val_rec.line_id ||
                                        ' AND Sch ship date ' ||
                                        to_char(val_rec.sch_ship_date);
             lc_concat_error_message := lc_error_mesg;
           end if;

           -------------------------------------
           -- Check for proejct id
           -------------------------------------
           --            IF val_rec.project_id IS NULL THEN
           --
           --                lc_err_sts    :=  GC_API_ERROR;
           --                lc_error_mesg :=  'The Project Id is null for Order Number ' || val_rec.order_number
           --                    || ' And line id ' || val_rec.line_id ;
           --                lc_concat_error_message :=  lc_concat_error_message || ' ' || lc_error_mesg;
           --
           --            END IF;
           -------------------------------------
           -- Check for Inv period status
           -------------------------------------
           if trunc(val_rec.sch_ship_date) > trunc(sysdate) then
             lc_err_sts              := gc_api_error;
             lc_error_mesg           := 'The Scheduel Ship date for Delivery Details ID  ' ||
                                        val_rec.delivery_detail_id ||
                                        ' AND Order Number ' ||
                                        val_rec.order_number ||
                                        ' has future dated ';
             lc_concat_error_message := lc_error_mesg;
           end if;
         end if; -- IF val_rec.sch_ship_date IS NULL THEN

         --FND_FILE.PUT_LINE(fnd_file.log,'After validation Status of Order number  ' || lc_err_sts);

         ---------------------------------------
         -- Update the status in staging table
         ---------------------------------------
         if lc_err_sts = gc_api_error then
           update xxd_ont_ship_confirm_conv_tbl
              set status        = gc_error_status,
                  error_message = lc_concat_error_message
            where request_id = gn_conc_request_id
              and status = gc_new
              and rowid = val_rec.rowid;
         elsif lc_err_sts = gc_api_success then
           update xxd_ont_ship_confirm_conv_tbl
              set status = gc_validate_status
            where request_id = gn_conc_request_id
              and status = gc_new
              and rowid = val_rec.rowid;
         end if;
       end loop; -- val_rec IN cur_validate_details

       commit;

       log_records(p_debug   => gc_debug_flag,
                   p_message => 'End of Procedure validate_record_prc ');
     exception
       when error_exception then
         x_return_mesg := x_return_mesg;
         x_return_sts  := gc_api_error;
         fnd_file.put_line(fnd_file.log,
                           'Error Status ' || x_return_sts ||
                           ' ,Error message ' || x_return_mesg);
         --ROLLBACK;

       when others then
         x_return_mesg := 'The procedure lauch_pick_release Failed  ' ||
                          sqlerrm;
         x_return_sts  := gc_api_error;
         fnd_file.put_line(fnd_file.log,
                           'Error Status ' || x_return_sts ||
                           ' ,Error message ' || x_return_mesg);
     end validate_record_prc;*/

    -- ========================================================================= --
    --                                                                           --
    -- PROCEDURE      :  process_record_prc                                       --
    --                                                                           --
    -- Description    :  This procedure will be called                           --
    --                   from imnport_main_prc                                   --
    --                                                                           --
    -- Parameters     :                                                          --
    --                                                                           --
    -- Parameter Name      Mode Type       Description                           --
    -- --------------      ---- --------   ----------------                      --
    --                                                                           --
    -- ========================================================================= --
    /* procedure process_record_prc(x_return_mesg out varchar2,
                                  x_return_sts  out varchar2) is
       ---------------------------------
       -- Cusror to get schedule ship date
       ---------------------------------
       cursor cur_get_sch_ship_date is
         select distinct trunc(sch_ship_date) sch_ship_date
           from xxd_ont_ship_confirm_conv_tbl
          where status = gc_validate_status
            and request_id = gn_conc_request_id
          order by sch_ship_date asc;

       --------------------------------------
       -- Cusror to get Different warehouse
       -- for the schedule ship date
       --------------------------------------
       cursor cur_get_warehouse(p_sch_ship_date date) is
         select distinct --ship_to_location_id,
                         ship_from_org_id
           from xxd_ont_ship_confirm_conv_tbl
          where status = gc_validate_status
            and request_id = gn_conc_request_id
            and released_status in ('R', 'B')
            and trunc(sch_ship_date) = trunc(p_sch_ship_date);

       --------------------------------------
       -- Cusror to get delivery id
       --------------------------------------
       cursor cur_get_delivery_dtl(p_sch_ship_date date) is
         select rowid, a.*
           from xxd_ont_ship_confirm_conv_tbl a
          where status = gc_validate_status
            and request_id = gn_conc_request_id
            and trunc(sch_ship_date) = trunc(p_sch_ship_date);

       ----------------------------------------------------
       -- Cusror to get data after pick release
       -- and process them to pick confirm and ship confirm
       ----------------------------------------------------
       cursor cur_get_order_details(p_warehouse number, p_sch_ship_date date) is
         select distinct header_id
           from xxd_ont_ship_confirm_conv_tbl a
          where status = gc_validate_status
            and request_id = gn_conc_request_id
            and ship_from_org_id = p_warehouse
            and trunc(sch_ship_date) = trunc(p_sch_ship_date)
          order by header_id;

       ----------------------------------------------------
       -- Cusror to get data after pick release
       -- and process them to pick confirm and ship confirm
       ----------------------------------------------------
       cursor cur_get_cn_details(p_warehouse number, p_sch_ship_date date) is
         select distinct cust_account_number
           from xxd_ont_ship_confirm_conv_tbl a
          where status = gc_validate_status
            and request_id = gn_conc_request_id
            and ship_from_org_id = p_warehouse
            and trunc(sch_ship_date) = trunc(p_sch_ship_date)
          order by cust_account_number;

       --
       -- Declartion of variables
       --
       x_batch_id          number;
       x_request_id        number;
       x_application_id    number;
       x_responsibility_id number;
       ln_count            number := 1;
       ln_exit_flag        number := 0;
       lb_flag             boolean := false;
       lc_rollback exception;
       lc_launch_rollback exception;

       lc_released_status varchar2(200);
       ln_del_id          number;
       ln_org_id          number;
       log_msg            varchar2(4000);
     begin
       x_return_sts := gc_api_success;
       log_records(p_debug   => gc_debug_flag,
                   p_message => 'Start of Procedure process_record_prc ');
       --    debug(GC_SOURCE_PROGRAM);

       ln_org_id := fnd_profile.value('ORG_ID');

       ----------------------------------------------------------------
       -- call procedure to get responsibility and application details
       ----------------------------------------------------------------
       --    get_resp_appl_ids
       --        (
       --            x_application_id        => x_application_id,
       --            x_responsibility_id     => x_responsibility_id,
       --            x_return_mesg           => x_return_mesg,
       --            x_return_sts            => x_return_sts
       --        );
       -- change required on organizaiton id pvadrevu
       set_org_context(p_target_org_id => ln_org_id,
                       p_resp_id       => x_responsibility_id,
                       p_resp_appl_id  => x_application_id);

       --    -- Set org id
       begin
         mo_global.set_policy_context('S', ln_org_id); -- change this later
       end;

       --
       --    -- set the responsibility and other details
       begin
         fnd_global.apps_initialize(fnd_global.user_id,
                                    x_responsibility_id,
                                    x_application_id);
       end;

       -- open the cursor for each sch ship date
       for get_sch_ship_date in cur_get_sch_ship_date loop
         log_msg := (' ********* Start of processing Sch ship date ' ||
                    get_sch_ship_date.sch_ship_date);
         log_records(p_debug => gc_debug_flag, p_message => log_msg);

         -- open the cursor to get diff warehouses
         for get_warehouse_rec in cur_get_warehouse(get_sch_ship_date.sch_ship_date) loop
           log_msg := ' Before Calling Launch release';
           log_records(p_debug => gc_debug_flag, p_message => log_msg);
           x_return_sts  := null;
           x_return_mesg := null;

           ---------------------------------------------------------------------
           -- Call the procedure to pick selection and release
           -- create one batch with combination of each sch ship date, warehouse
           -- Ones pick selection release the batch through concurrent program
           ---------------------------------------------------------------------
           --            IF GB_ORDER_PASSED
           --            AND GB_SSD_PASSED
           --            AND GB_CUST_ACCT_CN_PASSED THEN

           fnd_file.put_line(fnd_file.log, ' All Parameters are True');
           fnd_file.put_line(fnd_file.log,
                             ' Group the batch based on ship to location ' --|| get_warehouse_rec.ship_to_location_id
                             || ' and warehouse/ org id ' ||
                             get_warehouse_rec.ship_from_org_id);

           for process_ord_rec in cur_get_order_details(get_warehouse_rec.ship_from_org_id,
                                                        get_sch_ship_date.sch_ship_date) loop
             ---------------------------------------------------------------------
             -- Call the procedure to pick selection and release
             ---------------------------------------------------------------------
             launch_pick_release_order(p_sch_ship_date    => get_sch_ship_date.sch_ship_date,
                                       p_ship_from_org_id => get_warehouse_rec.ship_from_org_id,
                                       p_order_header_id  => process_ord_rec.header_id,
                                       x_batch_id         => x_batch_id,
                                       x_request_id       => x_request_id,
                                       x_return_mesg      => x_return_mesg,
                                       x_return_sts       => x_return_sts);

             log_msg := (' After launch_pick_release status is ' ||
                        x_return_sts);
             log_records(p_debug => gc_debug_flag, p_message => log_msg);
           end loop;
           --            END IF;
         end loop; -- FOR get_warehouse_rec IN cur_get_warehouse

         -----------------------------------------------
         -- get the delivery id after pick release
         -----------------------------------------------
         for get_del_id in cur_get_delivery_dtl(get_sch_ship_date.sch_ship_date) loop
           ln_del_id := null;

           begin
             select delivery_id
               into ln_del_id
               from wsh_delivery_assignments wda
              where delivery_detail_id = get_del_id.delivery_detail_id;
           exception
             when others then
               x_return_mesg := 'get the delivery id for delivery details id ' ||
                                get_del_id.delivery_detail_id || ' errror ' ||
                                sqlerrm;
               x_return_sts  := gc_api_error;
               fnd_file.put_line(fnd_file.log,
                                 'Error Status ' || x_return_sts ||
                                 ' ,Error message ' || x_return_mesg);
           end;

           if ln_del_id is not null then
             update xxd_ont_ship_confirm_conv_tbl
                set delivery_id = ln_del_id, released_status = 'S'
              where request_id = gn_conc_request_id
                and status = gc_validate_status
                and delivery_detail_id = get_del_id.delivery_detail_id
                and trunc(sch_ship_date) = get_sch_ship_date.sch_ship_date;
           else
             update xxd_ont_ship_confirm_conv_tbl
                set status        = gc_error_status,
                    error_message = ' Delivery ID is missing / Pick release did not happen during Pick Selection List Generation program'
              where request_id = gn_conc_request_id
                and status = gc_validate_status
                and delivery_detail_id = get_del_id.delivery_detail_id
                and trunc(sch_ship_date) = get_sch_ship_date.sch_ship_date;
           end if;
         end loop; -- FOR get_del_id IN cur_get_delivery_dtl(get_sch_ship_date.sch_ship_date)

         commit;

         ------------------------------------------------------------------
         -- This procedcure will transact the move order from inventory to staging
         -- Release status will be updated Y in wsh_delivery_details
         -------------------------------------------------------------------
         pick_confirm(p_sch_ship_date => get_sch_ship_date.sch_ship_date,
                      x_return_mesg   => x_return_mesg,
                      x_return_sts    => x_return_sts);

         log_msg := (' After pick_confirm status is ' || x_return_sts);
         log_records(p_debug => gc_debug_flag, p_message => log_msg);

         ------------------------------------------------------------------
         -- This procedcure will confirm the shipping
         -- Release status will be updated C in wsh_delivery_details
         ------------------------------------------------------------------
         ship_confirm(p_sch_ship_date => get_sch_ship_date.sch_ship_date,
                      x_return_mesg   => x_return_mesg,
                      x_return_sts    => x_return_sts);

         log_msg := (' After Ship_confirm status is ' || x_return_sts);
         log_records(p_debug => gc_debug_flag, p_message => log_msg);

         ln_count := ln_count + 1;
         log_msg  := (' ********* End of processing Sch ship date ' ||
                     get_sch_ship_date.sch_ship_date);
         log_records(p_debug => gc_debug_flag, p_message => log_msg);
       end loop; -- FOR get_sch_ship_date IN cur_get_sch_ship_date

       log_records(p_debug   => gc_debug_flag,
                   p_message => 'End of Procedure process_record_prc ');
       --    log_msg :=  ( GC_SOURCE_PROGRAM);
       log_records(p_debug => gc_debug_flag, p_message => log_msg);

       commit;
     exception
       when others then
         x_return_mesg := 'The procedure process_record_prc Failed  ' ||
                          sqlerrm;
         x_return_sts  := gc_api_error;
         fnd_file.put_line(fnd_file.log,
                           'Error Status ' || x_return_sts ||
                           ' ,Error message ' || x_return_mesg);
         raise_application_error(-20003, sqlerrm);
     end process_record_prc;*/

    --This procedure is used to book the sales order
    PROCEDURE book_order (p_header_id IN NUMBER, p_line_in_tbl IN oe_order_pub.line_tbl_type, p_line_out_tbl IN oe_order_pub.line_tbl_type--jerry modify 15-may
                                                                                                                                          /*x_retcode out varchar2*/
                                                                                                                                          )
    IS
        ln_api_version_number          NUMBER := 1;
        lc_return_status               VARCHAR2 (10);
        l_debug_level                  NUMBER := 1;  -- OM DEBUG LEVEL (MAX 5)
        l_msg_index                    NUMBER;
        ln_msg_count                   NUMBER;
        lc_msg_data                    VARCHAR2 (2000);
        lc_error_message               VARCHAR2 (2000);
        ln_order_number                NUMBER;
        ln_line_index                  NUMBER;
        l_attribute20                  VARCHAR2 (100);
        -- INPUT VARIABLES FOR PROCESS_ORDER API
        l_header_rec                   oe_order_pub.header_rec_type;

        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        -- OUT VARIABLES FOR PROCESS_ORDER API
        l_header_rec_out               oe_order_pub.header_rec_type;
        l_header_val_rec_out           oe_order_pub.header_val_rec_type;
        l_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        l_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        l_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        l_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        l_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        l_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        l_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        l_line_tbl_out                 oe_order_pub.line_tbl_type;
        l_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        l_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        l_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        l_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        l_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        l_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        l_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        l_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        l_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        l_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        l_action_request_tbl_out       oe_order_pub.request_tbl_type;
    BEGIN
        -- INITIALIZE ENVIRONMENT
        log_records (gc_debug_flag, 'Calling Book Order API');
        l_header_rec.header_id                  := p_header_id;
        ln_line_index                           := 1;

        FOR line IN 1 .. p_line_out_tbl.COUNT
        LOOP
            IF     p_line_in_tbl (line).schedule_ship_date IS NOT NULL
               AND p_line_in_tbl (line).source_type_code = 'INTERNAL'
            THEN
                /*Visible Demand Flag Is 'N' Even Though Sales Order Is Booked With Available Scheduled Date When Using Order Import (Doc ID 1569211.1)

                GOAL
                To explain why the Visible demand flag may be getting set as 'N' even though the sales order is booked with an available scheduled date
                when using Order Import for Sales Order creation.

                SOLUTION
                It is mandatory to set the Profile OM: Bypass ATP to Yes, for the visible_demand_flag to be populated.

                 If wishing to retain the legacy shipment_date and the visible_demand_flag to be set to 'Y', populate the field '
                 override_atp_date_code' in the table 'oe_lines_iface_all' to 'Y at the time of order import.

                */
                log_records (gc_debug_flag,
                             'Inside the scheduling if of book');
                l_line_tbl (line)                          := oe_order_pub.g_miss_line_rec;
                l_line_tbl (line)                          := p_line_out_tbl (line);
                l_line_tbl (line).operation                := oe_globals.g_opr_update;

                l_line_tbl (line).schedule_ship_date       :=
                    p_line_in_tbl (line).schedule_ship_date;

                l_line_tbl (line).schedule_action_code     := 'SCHEDULE'; --                    := FND_API.G_MISS_CHAR;
                l_line_tbl (line).override_atp_date_code   := 'Y';
                l_line_tbl (line).visible_demand_flag      :=
                    fnd_api.g_miss_char;
            END IF;

            ln_line_index   := ln_line_index + 1;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'l_line_tbl.count: ' || l_line_tbl.COUNT);

        l_action_request_tbl (1)                := oe_order_pub.g_miss_request_rec;
        l_action_request_tbl (1).entity_id      := p_header_id;
        l_action_request_tbl (1).entity_code    := oe_globals.g_entity_header;
        l_action_request_tbl (1).request_type   := oe_globals.g_book_order;
        -- l_action_request_tbl(1).date_param1 := p_booked_date;
        -- l_action_request_tbl(1).param1   := 'O';
        -- l_action_request_tbl(1).date_param5 := p_booked_date;

        oe_msg_pub.initialize;
        --call standard api
        oe_order_pub.process_order (p_api_version_number => ln_api_version_number, p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, p_action_request_tbl => l_action_request_tbl, -- OUT variables
                                                                                                                                                                                         x_header_rec => l_header_rec_out, x_header_val_rec => l_header_val_rec_out, x_header_adj_tbl => l_header_adj_tbl_out, x_header_adj_val_tbl => l_header_adj_val_tbl_out, x_header_price_att_tbl => l_header_price_att_tbl_out, x_header_adj_att_tbl => l_header_adj_att_tbl_out, x_header_adj_assoc_tbl => l_header_adj_assoc_tbl_out, x_header_scredit_tbl => l_header_scredit_tbl_out, x_header_scredit_val_tbl => l_header_scredit_val_tbl_out, x_line_tbl => l_line_tbl_out, x_line_val_tbl => l_line_val_tbl_out, x_line_adj_tbl => l_line_adj_tbl_out, x_line_adj_val_tbl => l_line_adj_val_tbl_out, x_line_price_att_tbl => l_line_price_att_tbl_out, x_line_adj_att_tbl => l_line_adj_att_tbl_out, x_line_adj_assoc_tbl => l_line_adj_assoc_tbl_out, x_line_scredit_tbl => l_line_scredit_tbl_out, x_line_scredit_val_tbl => l_line_scredit_val_tbl_out, x_lot_serial_tbl => l_lot_serial_tbl_out, x_lot_serial_val_tbl => l_lot_serial_val_tbl_out, x_action_request_tbl => l_action_request_tbl_out, x_return_status => lc_return_status, x_msg_count => ln_msg_count
                                    , x_msg_data => lc_msg_data);

        /*****************CHECK RETURN STATUS***********************************/
        IF lc_return_status = fnd_api.g_ret_sts_success
        THEN
            --x_retcode := fnd_api.g_ret_sts_success; --jerry modify 15-may
            IF (l_debug_level > 0)
            THEN
                log_records (gc_debug_flag, 'book order success');
                log_records (
                    gc_debug_flag,
                       'header.order_number IS: '
                    || TO_CHAR (l_header_rec_out.order_number));

                log_records (
                    gc_debug_flag,
                    ' l_line_tbl_out.count: ' || l_line_tbl_out.COUNT);

                IF l_line_tbl_out.COUNT > 0
                THEN
                    --jerry modify 15-may
                    FOR xc_line_idx IN l_line_tbl_out.FIRST ..
                                       l_line_tbl_out.LAST
                    LOOP
                        BEGIN
                            SELECT attribute20
                              INTO l_attribute20
                              FROM oe_order_lines_all
                             WHERE line_id =
                                   l_line_tbl_out (xc_line_idx).line_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                log_records (
                                    gc_debug_flag,
                                       'error when check DFF20 for order line: '
                                    || l_line_tbl_out (xc_line_idx).line_id
                                    || ' '
                                    || SQLERRM);
                        END;

                        IF l_attribute20 = 'FRC'
                        THEN
                            progress_fraud_lines (
                                l_line_tbl_out (xc_line_idx).line_id);
                            progress_fraud_lines (
                                l_line_tbl_out (xc_line_idx).line_id);
                        ELSIF l_attribute20 = 'PGA'
                        THEN
                            progress_fraud_lines (
                                l_line_tbl_out (xc_line_idx).line_id);
                        END IF;
                    END LOOP;
                END IF;

                --         progress_order_header(p_order_number => l_header_rec_out.order_number
                --                              ,p_activity_name => 'BOOK_ELIGIBLE' );
                --
                --         progress_order_lines(p_order_number => l_header_rec_out.order_number
                --
                COMMIT;
            END IF;
        --         UPDATE XXD_ONT_SO_LINES_CONV_STG_T SET
        --                       RECORD_STATUS       = gc_process_status
        --                 WHERE ORIG_SYS_DOCUMENT_REF  = l_header_rec_out.orig_sys_document_ref ;
        --
        --         UPDATE XXD_ONT_SO_HEADERS_CONV_STG_T SET
        --                       record_status          = gc_process_status
        --                 WHERE ORIGINAL_SYSTEM_REFERENCE = l_header_rec_out.orig_sys_document_ref ;

        --         COMMIT;
        ELSE
            --x_retcode := fnd_api.g_ret_sts_error; --jerry modify 15-may
            IF (l_debug_level > 0)
            THEN
                FOR i IN 1 .. ln_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                    , p_msg_index_out => l_msg_index);
                    log_records (gc_debug_flag,
                                 'message is: ' || lc_msg_data);
                    log_records (gc_debug_flag,
                                 'message index is: ' || l_msg_index);
                    xxd_common_utils.record_error (
                        'ONT',
                        gn_org_id,
                        'Deckers Ecomm Open Sales Order Conversion Program',
                        --      SQLCODE,
                        lc_msg_data,
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --    SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        'ORDER NUMBER',
                        l_header_rec_out.order_number);
                END LOOP;

                ROLLBACK;
            END IF;
        --        UPDATE XXD_ONT_SO_LINES_CONV_STG_T SET
        --               RECORD_STATUS       = gc_error_status
        --         WHERE ORIG_SYS_DOCUMENT_REF  = l_header_rec_out.orig_sys_document_ref ;
        --
        --         UPDATE XXD_ONT_SO_HEADERS_CONV_STG_T SET
        --                record_status          = gc_error_status
        --          WHERE ORIGINAL_SYSTEM_REFERENCE = l_header_rec_out.orig_sys_document_ref ;
        --        COMMIT;
        END IF;

        log_records (gc_debug_flag,
                     '****************************************************');

        /*****************DISPLAY RETURN STATUS FLAGS******************************/
        IF (l_debug_level > 0)
        THEN
            log_records (gc_debug_flag,
                         'process ORDER ret status IS: ' || lc_return_status);
            -- log_records (gc_debug_flag,'process ORDER msg data IS: '
            --                    || lc_msg_data);
            --log_records (gc_debug_flag,'process ORDER msg COUNT IS: '
            --               || ln_msg_count);
            log_records (
                gc_debug_flag,
                   'header.order_number IS: '
                || TO_CHAR (l_header_rec_out.order_number));
            --  DBMS_OUTPUT.put_line ('adjustment.return_status IS: '
            --                    || l_line_adj_tbl_out (1).return_status);
            log_records (
                gc_debug_flag,
                'header.header_id IS: ' || l_header_rec_out.header_id);
        /*log_records(gc_debug_flag,
                    'line.unit_selling_price IS: ' || l_line_tbl_out(1)
                    .unit_selling_price);*/
        END IF;
    /*****************DISPLAY ERROR MSGS*************************************/
    /*   IF (l_debug_level > 0)
    THEN
       FOR i IN 1 .. l_msg_count
       LOOP
          oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_data, p_msg_index_out => l_msg_index);
          log_records (gc_debug_flag,'message is: ' || l_data);
          log_records (gc_debug_flag,'message index is: ' || l_msg_index);
       END LOOP;
    END IF;

    IF (l_debug_level > 0)
    THEN
       log_records (gc_debug_flag,'Debug = ' || oe_debug_pub.g_debug);
       log_records (gc_debug_flag,'Debug Level = ' || TO_CHAR (oe_debug_pub.g_debug_level));
       log_records (gc_debug_flag,'Debug File = ' || oe_debug_pub.g_dir || '/' || oe_debug_pub.g_file);
       log_records (gc_debug_flag,'****************************************************');

    END IF;*/

    EXCEPTION
        WHEN OTHERS
        THEN
            --x_retcode := fnd_api.g_ret_sts_error; --jerry modify 15-may
            log_records (gc_debug_flag,
                         'Exception in book order:' || SQLERRM);
    END book_order;

    PROCEDURE unschedule_book_lines (
        p_header_id               IN NUMBER,
        p_orig_sys_document_ref   IN VARCHAR2,
        p_line_in_tbl             IN oe_order_pub.line_tbl_type,
        p_line_out_tbl            IN oe_order_pub.line_tbl_type)
    IS
        ln_api_version_number          NUMBER := 1;
        lc_return_status               VARCHAR2 (10);
        l_debug_level                  NUMBER := 1;  -- OM DEBUG LEVEL (MAX 5)
        l_msg_index                    NUMBER;
        ln_msg_count                   NUMBER;
        lc_msg_data                    VARCHAR2 (2000);
        lc_error_message               VARCHAR2 (2000);
        ln_order_number                NUMBER;
        ln_line_index                  NUMBER;
        --ln_header_adj_index   NUMBER ;
        -- INPUT VARIABLES FOR PROCESS_ORDER API
        l_header_rec                   oe_order_pub.header_rec_type;

        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_hdr_adj_tbl                  oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_att_tbl_type;
        l_action_request_tbl           oe_order_pub.Request_Tbl_Type;
        -- OUT VARIABLES FOR PROCESS_ORDER API
        l_header_rec_out               oe_order_pub.header_rec_type;
        l_header_val_rec_out           oe_order_pub.header_val_rec_type;
        l_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        l_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        l_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        l_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        l_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        l_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        l_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        l_line_tbl_out                 oe_order_pub.line_tbl_type;
        l_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        l_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        l_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        l_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        l_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        l_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        l_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        l_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        l_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        l_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        l_action_request_tbl_out       oe_order_pub.request_tbl_type;
        l_line_status                  VARCHAR2 (100);
    BEGIN
        -- INITIALIZE ENVIRONMENT
        log_records (gc_debug_flag, 'Calling Unschedule book lines API');
        l_header_rec.header_id   := p_header_id;
        ln_line_index            := 1;
        --ln_header_adj_index        :=1;

        l_line_tbl.delete;

        FOR line IN 1 .. p_line_out_tbl.COUNT
        LOOP
            l_line_status   := NULL;
            log_records (
                gc_debug_flag,
                   'p_line_in_tbl(line).orig_sys_line_ref '
                || p_line_in_tbl (line).orig_sys_line_ref);
            log_records (
                gc_debug_flag,
                'p_orig_sys_document_ref ' || p_orig_sys_document_ref);

            BEGIN
                SELECT flow_status_code
                  INTO l_line_status
                  FROM XXD_ONT_OPEN_SO_LINES_STG_T
                 WHERE     ORIGINAL_SYSTEM_LINE_REFERENCE =
                           p_line_in_tbl (line).orig_sys_line_ref
                       AND ORIG_SYS_DOCUMENT_REF = p_orig_sys_document_ref
                       AND schedule_ship_date IS NULL;

                log_records (gc_debug_flag,
                             'l_line_status ' || l_line_status);
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (gc_debug_flag,
                                 'error in fetching data booked ' || SQLERRM);
            END;

            IF l_line_status = 'BOOKED'
            THEN
                l_line_tbl (ln_line_index)   := oe_order_pub.g_miss_line_rec;
                -- l_line_tbl(ln_line_index)                         := p_line_out_tbl(line) ;
                l_line_tbl (ln_line_index).operation   :=
                    OE_GLOBALS.G_OPR_UPDATE;
                l_line_tbl (ln_line_index).line_id   :=
                    p_line_out_tbl (line).line_id;
                -- l_line_tbl(ln_line_index).schedule_ship_date      :=  FND_API.G_MISS_date;--null;
                -- l_line_tbl(ln_line_index).schedule_arrival_date      := FND_API.G_MISS_date;
                l_line_tbl (ln_line_index).request_date   :=
                    p_line_in_tbl (line).request_date;
                l_line_tbl (ln_line_index).schedule_action_code   :=
                    'UNSCHEDULE';
                -- l_line_tbl(line).flow_status_code :=  'BOOKED';
                log_records (
                    gc_debug_flag,
                       'p_line_in_tbl(line).line_id '
                    || p_line_in_tbl (line).line_id);

                --       l_action_request_tbl (ln_line_index)              := oe_order_pub.g_miss_request_rec;
                --l_action_request_tbl (ln_line_index).entity_id    := p_line_in_tbl(line).line_id;
                --l_action_request_tbl (ln_line_index).entity_code  := OE_GLOBALS.G_ENTITY_LINE;
                --l_action_request_tbl (ln_line_index).request_type := OE_GLOBALS.G_OPR_UPDATE; --OE_GLOBALS.G_RESCHEDULE_LINE;

                ln_line_index                :=
                    ln_line_index + 1;
            END IF;
        --ln_line_index := ln_line_index + 1;
        END LOOP;

        --   l_action_request_tbl (1)              := oe_order_pub.g_miss_request_rec;
        --  l_action_request_tbl (1).entity_id    := p_header_id;
        ---  l_action_request_tbl (1).entity_code  := OE_GLOBALS.G_ENTITY_LINE;
        --   l_action_request_tbl (1).request_type := OE_GLOBALS.G_SCHEDULE_LINE;

        oe_msg_pub.Initialize;
        --call standard api

        FND_GLOBAL.APPS_INITIALIZE (gn_user_id, gn_resp_id, gn_resp_appl_id);
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', gn_org_id);

        oe_order_pub.process_order (p_api_version_number => ln_api_version_number, p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, --p_header_adj_tbl        => l_hdr_adj_tbl,
                                                                                                                                           -- p_line_adj_tbl       => l_line_adj_tbl,
                                                                                                                                           p_action_request_tbl => l_action_request_tbl, x_header_rec => l_header_rec_out, x_header_val_rec => l_header_val_rec_out, x_header_adj_tbl => l_header_adj_tbl_out, x_header_adj_val_tbl => l_header_adj_val_tbl_out, x_header_price_att_tbl => l_header_price_att_tbl_out, x_header_adj_att_tbl => l_header_adj_att_tbl_out, x_header_adj_assoc_tbl => l_header_adj_assoc_tbl_out, x_header_scredit_tbl => l_header_scredit_tbl_out, x_header_scredit_val_tbl => l_header_scredit_val_tbl_out, x_line_tbl => l_line_tbl_out, x_line_val_tbl => l_line_val_tbl_out, x_line_adj_tbl => l_line_adj_tbl_out, x_line_adj_val_tbl => l_line_adj_val_tbl_out, x_line_price_att_tbl => l_line_price_att_tbl_out, x_line_adj_att_tbl => l_line_adj_att_tbl_out, x_line_adj_assoc_tbl => l_line_adj_assoc_tbl_out, x_line_scredit_tbl => l_line_scredit_tbl_out, x_line_scredit_val_tbl => l_line_scredit_val_tbl_out, x_lot_serial_tbl => l_lot_serial_tbl_out, x_lot_serial_val_tbl => l_lot_serial_val_tbl_out, x_action_request_tbl => l_action_request_tbl_out, x_return_status => lc_return_status, x_msg_count => ln_msg_count
                                    , x_msg_data => lc_msg_data);


        /*****************CHECK RETURN STATUS***********************************/
        IF lc_return_status = fnd_api.g_ret_sts_success
        THEN
            IF (l_debug_level > 0)
            THEN
                --log_records (gc_debug_flag,'success');
                log_records (
                    gc_debug_flag,
                       'header.order_number IS: '
                    || TO_CHAR (l_header_rec_out.order_number));

                --         progress_order_header(p_order_number => l_header_rec_out.order_number
                --                              ,p_activity_name => 'BOOK_ELIGIBLE' );
                --
                --         progress_order_lines(p_order_number => l_header_rec_out.order_number
                --                             ,p_activity_name => 'SCHEDULING_ELIGIBLE');


                COMMIT;
            END IF;
        --         UPDATE XXD_SO_WS_LINES_CONV_STG_T SET
        --                       RECORD_STATUS       = gc_process_status
        --                 WHERE ORIG_SYS_DOCUMENT_REF  = l_header_rec_out.orig_sys_document_ref ;
        --
        --         UPDATE XXD_SO_WS_HEADERS_CONV_STG_T SET
        --                       record_status          = gc_process_status
        --                 WHERE ORIGINAL_SYSTEM_REFERENCE = l_header_rec_out.orig_sys_document_ref ;

        --         COMMIT;
        ELSE
            IF (l_debug_level > 0)
            THEN
                FOR i IN 1 .. ln_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                    , p_msg_index_out => l_msg_index);
                    log_records (gc_debug_flag,
                                 'message is: ' || lc_msg_data);
                    log_records (gc_debug_flag,
                                 'message index is: ' || l_msg_index);
                    xxd_common_utils.record_error (
                        'ONT',
                        gn_org_id,
                        'Deckers Open Sales Order Conversion Program',
                        --      SQLCODE,
                        lc_msg_data,
                        DBMS_UTILITY.format_error_backtrace,
                        --   DBMS_UTILITY.format_call_stack,
                        --    SYSDATE,
                        gn_user_id,
                        gn_conc_request_id,
                        'ORDER NUMBER',
                        l_header_rec_out.ORDER_NUMBER);
                END LOOP;

                ROLLBACK;
            END IF;
        --        UPDATE XXD_SO_WS_LINES_CONV_STG_T SET
        --               RECORD_STATUS       = gc_error_status
        --         WHERE ORIG_SYS_DOCUMENT_REF  = l_header_rec_out.orig_sys_document_ref ;
        --
        --         UPDATE XXD_SO_WS_HEADERS_CONV_STG_T SET
        --                record_status          = gc_error_status
        --          WHERE ORIGINAL_SYSTEM_REFERENCE = l_header_rec_out.orig_sys_document_ref ;
        --        COMMIT;
        END IF;

        --log_records (gc_debug_flag,'****************************************************');
        /*****************DISPLAY RETURN STATUS FLAGS******************************/
        IF (l_debug_level > 0)
        THEN
            log_records (gc_debug_flag,
                         'process ORDER ret status IS: ' || lc_return_status);
            -- log_records (gc_debug_flag,'process ORDER msg data IS: '
            --                   || lc_msg_data);
            -- log_records (gc_debug_flag,'process ORDER msg COUNT IS: '
            --                   || ln_msg_count);
            log_records (
                gc_debug_flag,
                   'header.order_number IS: '
                || TO_CHAR (l_header_rec_out.order_number));
            --  DBMS_OUTPUT.put_line ('adjustment.return_status IS: '
            --                    || l_line_adj_tbl_out (1).return_status);
            log_records (
                gc_debug_flag,
                'header.header_id IS: ' || l_header_rec_out.header_id);
        /*  log_records (gc_debug_flag,'line.unit_selling_price IS: '
                              || l_line_tbl_out (1).unit_selling_price); */
        END IF;
    /*****************DISPLAY ERROR MSGS*************************************/
    /*   IF (l_debug_level > 0)
       THEN
          FOR i IN 1 .. l_msg_count
          LOOP
             oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_data, p_msg_index_out => l_msg_index);
             log_records (gc_debug_flag,'message is: ' || l_data);
             log_records (gc_debug_flag,'message index is: ' || l_msg_index);
          END LOOP;
       END IF;

       IF (l_debug_level > 0)
       THEN
          log_records (gc_debug_flag,'Debug = ' || oe_debug_pub.g_debug);
          log_records (gc_debug_flag,'Debug Level = ' || TO_CHAR (oe_debug_pub.g_debug_level));
          log_records (gc_debug_flag,'Debug File = ' || oe_debug_pub.g_dir || '/' || oe_debug_pub.g_file);
          log_records (gc_debug_flag,'****************************************************');

       END IF;*/

    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (gc_debug_flag,
                         'Exception in unschedule book lines:' || SQLERRM);
    END unschedule_book_lines;

    PROCEDURE relink_return_lines (p_ord_org_sys_ref VARCHAR2)
    AS
        CURSOR cur_order_line IS
            SELECT stg.ORIG_SYS_DOCUMENT_REF, stg.ORIGINAL_SYSTEM_LINE_REFERENCE, stg.NEW_REFERENCE_LINE_ID,
                   stg.NEW_REFERENCE_HEADER_ID
              FROM XXD_ONT_OPEN_SO_LINES_STG_T stg, oe_order_lines_all ret1223
             WHERE     stg.LINE_CATEGORY_CODE = 'RETURN'
                   AND stg.RET_ORG_SYS_LINE_REF IS NOT NULL
                   AND stg.NEW_REFERENCE_LINE_ID IS NOT NULL
                   --and stg.header_id = 31234388
                   AND ret1223.orig_sys_document_ref =
                       stg.RET_ORG_SYS_DOC_REF
                   AND ret1223.orig_sys_line_ref = stg.RET_ORG_SYS_LINE_REF
                   AND stg.ORIG_SYS_DOCUMENT_REF = p_ord_org_sys_ref--  and RET_ORG_SYS_LINE_REF is null
                                                                    -- and lines.record_status ='V'
                                                                    ;

        TYPE t_ord_line_type IS TABLE OF cur_order_line%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ord_line_tab   t_ord_line_type;
    BEGIN
        OPEN cur_order_line;

        LOOP
            t_ord_line_tab.delete;

            FETCH cur_order_line BULK COLLECT INTO t_ord_line_tab LIMIT 5000;

            EXIT WHEN t_ord_line_tab.COUNT = 0;
            log_records (gc_debug_flag, 'in relink ');

            FORALL I IN 1 .. t_ord_line_tab.COUNT SAVE EXCEPTIONS
                UPDATE oe_order_lines_all
                   SET REFERENCE_HEADER_ID = t_ord_line_tab (i).NEW_REFERENCE_HEADER_ID, REFERENCE_LINE_ID = t_ord_line_tab (i).NEW_REFERENCE_LINE_ID, RETURN_ATTRIBUTE1 = t_ord_line_tab (i).NEW_REFERENCE_HEADER_ID,
                       RETURN_ATTRIBUTE2 = t_ord_line_tab (i).NEW_REFERENCE_LINE_ID
                 WHERE     ORIG_SYS_DOCUMENT_REF =
                           t_ord_line_tab (i).ORIG_SYS_DOCUMENT_REF
                       AND ORIG_SYS_LINE_REF =
                           t_ord_line_tab (i).ORIGINAL_SYSTEM_LINE_REFERENCE;

            /*    FOR I IN 1 ..  t_ord_line_tab.COUNT
                LOOP

                BEGIN
                update oe_order_lines_all
               set REFERENCE_HEADER_ID =t_ord_line_tab(i).NEW_REFERENCE_HEADER_ID,
               REFERENCE_LINE_ID = t_ord_line_tab(i).NEW_REFERENCE_LINE_ID,
               RETURN_ATTRIBUTE1 =t_ord_line_tab(i).NEW_REFERENCE_HEADER_ID,
               RETURN_ATTRIBUTE2 = t_ord_line_tab(i).NEW_REFERENCE_LINE_ID
                where ORIG_SYS_DOCUMENT_REF = t_ord_line_tab (i).ORIG_SYS_DOCUMENT_REF
               and ORIG_SYS_LINE_REF= t_ord_line_tab (i).ORIGINAL_SYSTEM_LINE_REFERENCE;
               EXCEPTION
               WHEN OTHERS THEN
               log_records(gc_debug_flag, 'eRROR IN RELINK ORIGINAL_SYSTEM_LINE_REFERENCE' || t_ord_line_tab (i).ORIGINAL_SYSTEM_LINE_REFERENCE );
               log_records(gc_debug_flag, 'sqlerrm ' || SQLERRM );
               eND;

            END LOOP;*/

            COMMIT;
        END LOOP;
    --  x_retrun_status := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Un-expecetd Error in relink_return_line => ' || SQLERRM);
    --    ROLLBACK;
    --  x_retrun_status := 'E';
    END relink_return_lines;

    PROCEDURE create_order (
        p_header_rec                  oe_order_pub.header_rec_type,
        p_line_tbl                    oe_order_pub.line_tbl_type,
        p_price_adj_line_tbl          oe_order_pub.line_adj_tbl_type,
        p_closed_line_tbl             oe_order_pub.line_tbl_type,
        p_price_adj_closed_line_tbl   oe_order_pub.line_adj_tbl_type,
        p_action_request_tbl          oe_order_pub.request_tbl_type,
        p_open_line_flag              VARCHAR2,
        p_closed_line_flag            VARCHAR2)
    AS
        CURSOR cur_closed_lines (p_header_id NUMBER)
        IS
            SELECT ool.orig_sys_line_ref, ool.line_id, stg.flow_status_code
              FROM xxd_ont_open_so_lines_stg_t stg, oe_order_lines_all ool
             WHERE     ool.orig_sys_line_ref =
                       stg.original_system_line_reference
                   AND stg.header_id = p_header_id;

        TYPE lt_lines_closed_typ IS TABLE OF cur_closed_lines%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_lines_closed_data           lt_lines_closed_typ;

        l_api_version_number           NUMBER := 1;
        l_return_status                VARCHAR2 (2000);
        l_closed_line_return_status    VARCHAR2 (2000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (2000);

        l_return_status_c              VARCHAR2 (2000);
        l_msg_count_c                  NUMBER;
        l_msg_data_c                   VARCHAR2 (2000);
        /*****************PARAMETERS****************************************************/
        --   l_debug_level                  NUMBER  := 1;    -- OM DEBUG LEVEL (MAX 5)
        --   l_org                          NUMBER  := 87;         -- OPERATING UNIT
        --   l_no_orders                    NUMBER  := 1;              -- NO OF ORDERS
        --   l_user                         NUMBER  := 7252;          -- USER
        --   l_resp                         NUMBER  := 50691;        -- RESPONSIBLILTY
        --   l_appl                         NUMBER  := 660;        -- ORDER MANAGEMENT
        /*****************INPUT VARIABLES FOR PROCESS_ORDER API*************************/
        l_header_rec                   oe_order_pub.header_rec_type;
        l_closed_line_tbl              oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        /*****************OUT VARIABLES FOR PROCESS_ORDER API***************************/
        l_header_rec_out               oe_order_pub.header_rec_type;
        l_header_rec_out_closed        oe_order_pub.header_rec_type;
        l_header_val_rec_out           oe_order_pub.header_val_rec_type;
        l_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        l_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        l_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        l_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        l_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        l_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        l_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        l_line_tbl_out                 oe_order_pub.line_tbl_type;
        l_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        l_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        l_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        l_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        l_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        l_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        l_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        l_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        l_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        l_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        l_action_request_tbl_out       oe_order_pub.request_tbl_type;
        l_msg_index                    NUMBER;
        l_data                         VARCHAR2 (2000);
        l_loop_count                   NUMBER;
        l_debug_file                   VARCHAR2 (200);
        b_return_status                VARCHAR2 (200);
        b_msg_count                    NUMBER;
        b_msg_data                     VARCHAR2 (2000);
        i                              NUMBER;

        l_1206_headerid                NUMBER;
        l_flow_status_code             VARCHAR2 (200);
    --    l_user_id        NUMBER := -1;
    --    l_resp_id        NUMBER := -1;
    --    l_application_id    NUMBER := -1;
    --
    --    l_user_name        VARCHAR2(30) := 'PVADREVU001';
    --    l_resp_name        VARCHAR2(30) := 'ORDER_MGMT_SU_US';

    BEGIN
        log_records (gc_debug_flag, 'Inside create order API call function');
        oe_msg_pub.initialize;

        --Meenakshi 27-May
        fnd_global.apps_initialize (gn_user_id, gn_resp_id, gn_resp_appl_id); -- pass in user_id, responsibility_id, and application_id
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', p_header_rec.org_id);
        --                  COMMIT;
        /*****************CALLTO PROCESS ORDER API*********************************/
        log_records (gc_debug_flag, 'Start create open SO');
        oe_order_pub.process_order (
            p_api_version_number       => l_api_version_number,
            p_header_rec               => p_header_rec,
            p_line_tbl                 => p_line_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            p_action_commit            => fnd_api.g_false,
            p_line_adj_tbl             => p_price_adj_line_tbl -- OUT variables
                                                              ,
            x_header_rec               => l_header_rec_out,
            x_header_val_rec           => l_header_val_rec_out,
            x_header_adj_tbl           => l_header_adj_tbl_out,
            x_header_adj_val_tbl       => l_header_adj_val_tbl_out,
            x_header_price_att_tbl     => l_header_price_att_tbl_out,
            x_header_adj_att_tbl       => l_header_adj_att_tbl_out,
            x_header_adj_assoc_tbl     => l_header_adj_assoc_tbl_out,
            x_header_scredit_tbl       => l_header_scredit_tbl_out,
            x_header_scredit_val_tbl   => l_header_scredit_val_tbl_out,
            x_line_tbl                 => l_line_tbl_out,
            x_line_val_tbl             => l_line_val_tbl_out,
            x_line_adj_tbl             => l_line_adj_tbl_out,
            x_line_adj_val_tbl         => l_line_adj_val_tbl_out,
            x_line_price_att_tbl       => l_line_price_att_tbl_out,
            x_line_adj_att_tbl         => l_line_adj_att_tbl_out,
            x_line_adj_assoc_tbl       => l_line_adj_assoc_tbl_out,
            x_line_scredit_tbl         => l_line_scredit_tbl_out,
            x_line_scredit_val_tbl     => l_line_scredit_val_tbl_out,
            x_lot_serial_tbl           => l_lot_serial_tbl_out,
            x_lot_serial_val_tbl       => l_lot_serial_val_tbl_out,
            x_action_request_tbl       => l_action_request_tbl_out,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data);

        /*****************CHECK RETURN STATUS***********************************/
        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            --         IF (l_debug_level > 0)
            --         THEN
            log_records (gc_debug_flag, 'create open sales order success');
            log_records (
                gc_debug_flag,
                   'sales order order_number IS: '
                || TO_CHAR (l_header_rec_out.order_number));

            --   if  p_line_tbl.count >0 then
            --Meenakshi 27-May
            fnd_global.apps_initialize (gn_user_id,
                                        gn_resp_id,
                                        gn_resp_appl_id); -- pass in user_id, responsibility_id, and application_id
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', p_header_rec.org_id);

            book_order (p_header_id      => l_header_rec_out.header_id,
                        p_line_in_tbl    => p_line_tbl,
                        p_line_out_tbl   => l_line_tbl_out/*,
                                                         x_retcode      => l_return_status*/
                                                          ); --jerry modify 15-may

            unschedule_book_lines (p_header_id => l_header_rec_out.header_id, p_orig_sys_document_ref => l_header_rec_out.orig_sys_document_ref, p_line_in_tbl => p_line_tbl
                                   , p_line_out_tbl => l_line_tbl_out);

            log_records (gc_debug_flag, 'After booking');

            IF p_open_line_flag = 'Y'
            THEN
                log_records (
                    gc_debug_flag,
                    'Calling apply_hold_header_line ' || l_header_rec_out.orig_sys_document_ref);

                --Meenakshi 27-May
                fnd_global.apps_initialize (gn_user_id,
                                            gn_resp_id,
                                            gn_resp_appl_id); -- pass in user_id, responsibility_id, and application_id
                mo_global.init ('ONT');
                mo_global.set_policy_context ('S', p_header_rec.org_id);

                apply_hold_header_line (
                    p_orig_sys_document_ref   =>
                        l_header_rec_out.orig_sys_document_ref,
                    p_line_id         => NULL,
                    x_return_status   => l_return_status);
            END IF;

            --   end if;
            log_records (gc_debug_flag,
                         'Before closed lines validation Check');

            -- adding closed lines
            IF p_closed_line_flag = 'Y'
            THEN
                log_records (
                    gc_debug_flag,
                       'Updating closed lines table with new header id '
                    || l_header_rec_out.header_id);
                l_closed_line_tbl   := p_closed_line_tbl;

                FOR l_closed_line_inx IN l_closed_line_tbl.FIRST ..
                                         l_closed_line_tbl.LAST
                LOOP
                    l_closed_line_tbl (l_closed_line_inx).header_id   :=
                        l_header_rec_out.header_id;
                END LOOP;

                log_records (gc_debug_flag, 'Start create closed SO');

                --Meenakshi 27-May
                oe_msg_pub.initialize;
                fnd_global.apps_initialize (gn_user_id,
                                            gn_resp_id,
                                            gn_resp_appl_id); -- pass in user_id, responsibility_id, and application_id
                mo_global.init ('ONT');
                mo_global.set_policy_context ('S', p_header_rec.org_id);

                oe_order_pub.process_order (
                    p_api_version_number       => l_api_version_number,
                    p_header_rec               => l_header_rec,
                    p_line_tbl                 => l_closed_line_tbl,
                    p_action_request_tbl       => l_action_request_tbl,
                    p_action_commit            => fnd_api.g_false,
                    p_line_adj_tbl             => p_price_adj_closed_line_tbl -- OUT variables
                                                                             ,
                    x_header_rec               => l_header_rec_out_closed,
                    x_header_val_rec           => l_header_val_rec_out,
                    x_header_adj_tbl           => l_header_adj_tbl_out,
                    x_header_adj_val_tbl       => l_header_adj_val_tbl_out,
                    x_header_price_att_tbl     => l_header_price_att_tbl_out,
                    x_header_adj_att_tbl       => l_header_adj_att_tbl_out,
                    x_header_adj_assoc_tbl     => l_header_adj_assoc_tbl_out,
                    x_header_scredit_tbl       => l_header_scredit_tbl_out,
                    x_header_scredit_val_tbl   => l_header_scredit_val_tbl_out,
                    x_line_tbl                 => l_line_tbl_out,
                    x_line_val_tbl             => l_line_val_tbl_out,
                    x_line_adj_tbl             => l_line_adj_tbl_out,
                    x_line_adj_val_tbl         => l_line_adj_val_tbl_out,
                    x_line_price_att_tbl       => l_line_price_att_tbl_out,
                    x_line_adj_att_tbl         => l_line_adj_att_tbl_out,
                    x_line_adj_assoc_tbl       => l_line_adj_assoc_tbl_out,
                    x_line_scredit_tbl         => l_line_scredit_tbl_out,
                    x_line_scredit_val_tbl     => l_line_scredit_val_tbl_out,
                    x_lot_serial_tbl           => l_lot_serial_tbl_out,
                    x_lot_serial_val_tbl       => l_lot_serial_val_tbl_out,
                    x_action_request_tbl       => l_action_request_tbl_out,
                    x_return_status            => l_closed_line_return_status,
                    x_msg_count                => l_msg_count,
                    x_msg_data                 => l_msg_data);

                log_records (
                    gc_debug_flag,
                       'create closed order line return status: '
                    || l_closed_line_return_status);

                --closing the lines workflow
                IF l_closed_line_return_status = fnd_api.g_ret_sts_success
                THEN
                    FOR l_closed_line_inx IN l_line_tbl_out.FIRST ..
                                             l_line_tbl_out.LAST
                    LOOP
                        --Meenakshi 2-Sept
                        oe_msg_pub.initialize;
                        fnd_global.apps_initialize (gn_user_id,
                                                    gn_resp_id,
                                                    gn_resp_appl_id); -- pass in user_id, responsibility_id, and application_id
                        mo_global.init ('ONT');
                        mo_global.set_policy_context ('S',
                                                      p_header_rec.org_id);

                        SELECT flow_status_code
                          INTO l_flow_status_code
                          FROM oe_order_lines_all
                         WHERE line_id =
                               l_line_tbl_out (l_closed_line_inx).line_id;

                        --   begin
                        IF l_flow_status_code NOT IN ('CLOSED', 'CANCELLED')
                        THEN
                            oe_order_close_util.CLOSE_LINE (
                                p_api_version_number   => 1.0,
                                p_line_id              =>
                                    l_line_tbl_out (l_closed_line_inx).line_id,
                                x_return_status        => l_return_status_c,
                                x_msg_count            => l_msg_count_c,
                                x_msg_data             => l_msg_data_c);
                        END IF;

                        --   exception
                        --  when others then
                        --  null;
                        --   end;

                        BEGIN
                            wf_engine.abortprocess (
                                itemtype   => 'OEOL',
                                itemkey    =>
                                    TO_CHAR (
                                        l_line_tbl_out (l_closed_line_inx).line_id), --activity => l_activity_name,
                                result     => 'SUCCESS');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;
                    END LOOP;
                END IF;

                -- relink_return_lines        (l_header_rec_out.orig_sys_document_ref);

                FOR i IN 1 .. l_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_data
                                    , p_msg_index_out => l_msg_index);
                    log_records (gc_debug_flag, 'message is: ' || l_data);
                    log_records (gc_debug_flag,
                                 'message index is: ' || l_msg_index);
                END LOOP;

                log_records (
                    gc_debug_flag,
                       'header.order_number IS: '
                    || TO_CHAR (l_header_rec_out.order_number));
            END IF;

            log_records (gc_debug_flag, 'before calling relink ');
            relink_return_lines (l_header_rec_out.orig_sys_document_ref);

            --  progress_order_header(p_order_number => l_header_rec_out.order_number
            --             ,p_activity_name => 'BOOK_ELIGIBLE' );

            /*      select header_id
                 into l_1206_headerid
                 from XXD_ONT_OPEN_SO_HEAD_STG_T
                 where order_number = l_header_rec_out.order_number  ;

                  log_records (gc_debug_flag,'After book eligible l_1206_headerid: '||l_1206_headerid);

                  OPEN cur_closed_lines(l_1206_headerid);
                  LOOP
                  FETCH cur_closed_lines
                 BULK COLLECT INTO lt_lines_closed_data   LIMIT 50;
                 EXIT WHEN lt_lines_closed_data.COUNT = 0;
                  IF lt_lines_closed_data.COUNT > 0
                 THEN
                  FOR xc_line_closed_idx IN lt_lines_closed_data.FIRST .. lt_lines_closed_data.LAST
                  LOOP
                  if lt_lines_closed_data(xc_line_closed_idx).flow_status_code ='CLOSED' then
                   log_records (gc_debug_flag,'Closing line_id: '||lt_lines_closed_data(xc_line_closed_idx).line_id);
                  OE_ORDER_CLOSE_UTIL.CLOSE_LINE
                 ( p_api_version_number => 1.0
                 , p_line_id=> lt_lines_closed_data(xc_line_closed_idx).line_id
                 , x_return_status => l_return_status_c
                 , x_msg_count => l_msg_count_c
                 , x_msg_data => l_msg_data_c
                 );
               end if;
                  END LOOP;  --closed loop
                  END IF;     --if closed count
            END LOOP; --clsoed for loop
            close cur_closed_lines; */

            --     log_records (gc_debug_flag,'p_open_line_flag  '||p_open_line_flag );
            --     if p_open_line_flag = 'Y' then
            /*   book_order(  p_header_id     =>   l_header_rec_out.header_id
            ,p_line_in_tbl   =>   p_line_tbl
            ,p_line_out_tbl  =>   l_line_tbl_out) ; */

            /*  log_records (gc_debug_flag,'Scheduling eligibale '||l_header_rec_out.order_number);
            progress_order_lines(p_order_number => l_header_rec_out.order_number
                                      ,p_activity_name => 'SCHEDULING_ELIGIBLE');


                      log_records (gc_debug_flag,'Calling apply_hold_header_line '||l_header_rec_out.orig_sys_document_ref);
                      apply_hold_header_line(p_orig_sys_document_ref     => l_header_rec_out.orig_sys_document_ref,
                                             p_line_id                   => NULL,
                                             x_return_status             => l_return_status)   ;
                                             null;
                end if;    */

            --         progress_order_lines(p_order_number => l_header_rec_out.order_number
            --                             ,p_activity_name => 'SCHEDULING_ELIGIBLE');

            /*    book_order(  p_header_id     =>   l_header_rec_out.header_id
                          ,p_line_in_tbl   =>   p_line_tbl
                          ,p_line_out_tbl  =>   l_line_tbl_out) ;

            log_records (gc_debug_flag,'Calling apply_hold_header_line '||l_header_rec_out.orig_sys_document_ref);
              apply_hold_header_line(p_orig_sys_document_ref     => l_header_rec_out.orig_sys_document_ref,
                                     p_line_id                   => NULL,
                                     x_return_status             => l_return_status)   ;*/

            --             IF x_return_status <> fnd_api.g_ret_sts_success THEN

            --             COMMIT;

            --             END IF;
            --         END IF;
            --jerry modify 15-may
            --if l_return_status = fnd_api.g_ret_sts_success then
            UPDATE xxd_ont_open_so_lines_stg_t
               SET record_status   = gc_process_status
             WHERE orig_sys_document_ref =
                   l_header_rec_out.orig_sys_document_ref;

            UPDATE xxd_ont_open_so_head_stg_t
               SET record_status   = gc_process_status
             WHERE original_system_reference =
                   l_header_rec_out.orig_sys_document_ref;

            /*else
              update xxd_ont_open_so_lines_stg_t
                 set record_status = gc_error_status
               where orig_sys_document_ref =
                     l_header_rec_out.orig_sys_document_ref;

              update xxd_ont_open_so_head_stg_t
                 set record_status = gc_error_status
               where original_system_reference =
                     l_header_rec_out.orig_sys_document_ref;*/

            --end if;
            COMMIT;
        ELSE
            --         IF (l_debug_level > 0)
            --         THEN
            FOR i IN 1 .. l_msg_count
            LOOP
                oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_data
                                , p_msg_index_out => l_msg_index);
                log_records (gc_debug_flag, 'message is: ' || l_data);
                log_records (gc_debug_flag,
                             'message index is: ' || l_msg_index);

                xxd_common_utils.record_error (
                    'ONT',
                    gn_org_id,
                    'Deckers Ecomm Open Sales Order Conversion Program',
                    --      SQLCODE,
                    l_data,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --    SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'ORDER NUMBER',
                    l_header_rec_out.order_number);
            END LOOP;

            ROLLBACK;

            --         END IF;

            UPDATE xxd_ont_open_so_lines_stg_t
               SET record_status   = gc_error_status
             WHERE orig_sys_document_ref =
                   l_header_rec_out.orig_sys_document_ref;

            UPDATE xxd_ont_open_so_head_stg_t
               SET record_status   = gc_error_status
             WHERE original_system_reference =
                   l_header_rec_out.orig_sys_document_ref;

            COMMIT;
        END IF;
    -- log_records (gc_debug_flag,'****************************************************');
    /*****************DISPLAY RETURN STATUS FLAGS******************************/
    --   IF (l_debug_level > 0)
    --   THEN
    --      log_records (gc_debug_flag,'process ORDER ret status IS: '
    --                          || l_return_status);
    --      log_records (gc_debug_flag,'process ORDER msg data IS: '
    --                          || l_msg_data);
    --      log_records (gc_debug_flag,'process ORDER msg COUNT IS: '
    --                          || l_msg_count);
    --      log_records (gc_debug_flag,'header.order_number IS: '
    --                          || TO_CHAR (l_header_rec_out.order_number));
    --    --  DBMS_OUTPUT.put_line ('adjustment.return_status IS: '
    --      --                    || l_line_adj_tbl_out (1).return_status);
    --      log_records (gc_debug_flag,'header.header_id IS: '
    --                          || l_header_rec_out.header_id);
    --      log_records (gc_debug_flag,'line.unit_selling_price IS: '
    --                          || l_line_tbl_out (1).unit_selling_price);
    --   END IF;

    /*****************DISPLAY ERROR MSGS*************************************/
    /*   IF (l_debug_level > 0)
    THEN
       FOR i IN 1 .. l_msg_count
       LOOP
          oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_data, p_msg_index_out => l_msg_index);
          log_records (gc_debug_flag,'message is: ' || l_data);
          log_records (gc_debug_flag,'message index is: ' || l_msg_index);
       END LOOP;
    END IF;

    IF (l_debug_level > 0)
    THEN
       log_records (gc_debug_flag,'Debug = ' || oe_debug_pub.g_debug);
       log_records (gc_debug_flag,'Debug Level = ' || TO_CHAR (oe_debug_pub.g_debug_level));
       log_records (gc_debug_flag,'Debug File = ' || oe_debug_pub.g_dir || '/' || oe_debug_pub.g_file);
       log_records (gc_debug_flag,'****************************************************');

    END IF;*/
    --   oe_debug_pub.debug_off;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            RAISE;
    END create_order;

    FUNCTION get_new_inv_org_id (p_old_org_id IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_ORG_ID                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name,p_request_id,p_inter_head_id              |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
        x_org_id         NUMBER;
    BEGIN
        px_lookup_code   := p_old_org_id;
        apps.xxd_common_utils.get_mapping_value (
            p_lookup_type    => 'XXD_1206_INV_ORG_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        SELECT organization_id
          INTO x_org_id
          FROM mtl_parameters                   --org_organization_definitions
         WHERE UPPER (organization_code) = UPPER (x_attribute1);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'ONT',
                gn_org_id,
                'Deckers Ecomm Open Sales Order Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'get_new_inv_org_id',
                p_old_org_id,
                'Exception to get_new_inv_org_id Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_new_inv_org_id;

    FUNCTION get_org_id (p_1206_org_id IN NUMBER)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_ORG_ID                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name,p_request_id,p_inter_head_id              |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
        x_org_id         NUMBER;
    BEGIN
        --         px_meaning := p_org_name;
        px_lookup_code   := p_1206_org_id;
        apps.xxd_common_utils.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (name) = UPPER (x_attribute1);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'ONT',
                gn_org_id,
                'Deckers Ecomm Open Sales Order Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_1206_org_id,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_org_id;

    FUNCTION get_targetorg_id (p_org_name IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : get_targetorg_id                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_org_id   NUMBER;
    BEGIN
        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (name) = UPPER (p_org_name);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'ONT',
                gn_org_id,
                'Decker Open Sales Order Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_org_name,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_targetorg_id;

    PROCEDURE create_order_line (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_action IN VARCHAR2, p_header_id IN NUMBER, p_customer_type IN VARCHAR2, p_line_tbl OUT oe_order_pub.line_tbl_type
                                 , p_adj_line_tbl OUT oe_order_pub.line_adj_tbl_type, x_retrun_status OUT VARCHAR2, x_open_line_flag OUT VARCHAR2)
    AS
        CURSOR cur_order_lines IS
            (SELECT *
               FROM xxd_ont_open_so_lines_stg_t cust
              WHERE     header_id = p_header_id
                    AND flow_status_code NOT IN
                            ('CLOSED', 'CANCELLED', 'INVOICED'));

        CURSOR cur_order_lines_adj (p_line_id NUMBER)
        IS
            SELECT *
              FROM xxd_ont_open_price_adj_l_stg_t cust
             WHERE header_id = p_header_id AND line_id = p_line_id;

        l_line_adj_tbl        oe_order_pub.line_adj_tbl_type;

        l_line_tbl            oe_order_pub.line_tbl_type;
        ln_line_index         NUMBER := 0;
        l_open_line_flag      VARCHAR2 (1) := 'N';

        TYPE lt_order_lines_typ IS TABLE OF cur_order_lines%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_order_lines_data   lt_order_lines_typ;

        ln_line_adj_index     NUMBER := 0;

        TYPE lt_lines_adj_typ IS TABLE OF cur_order_lines_adj%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_lines_adj_data     lt_lines_adj_typ;
    BEGIN
        log_records (gc_debug_flag, 'Inside create_order_line +');

        OPEN cur_order_lines;

        LOOP
            FETCH cur_order_lines
                BULK COLLECT INTO lt_order_lines_data
                LIMIT 50;

            EXIT WHEN lt_order_lines_data.COUNT = 0;

            IF lt_order_lines_data.COUNT > 0
            THEN
                FOR xc_order_idx IN lt_order_lines_data.FIRST ..
                                    lt_order_lines_data.LAST
                LOOP
                    ln_line_index   := ln_line_index + 1;
                    l_line_tbl (ln_line_index)   :=
                        oe_order_pub.g_miss_line_rec;
                    l_line_tbl (ln_line_index).operation   :=
                        oe_globals.g_opr_create;
                    l_line_tbl (ln_line_index).header_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).ordered_item_id   :=
                        fnd_api.g_miss_num; --3274788 ;--lt_order_lines_data(xc_order_idx).inventory_item_id;
                    l_line_tbl (ln_line_index).inventory_item_id   :=
                        lt_order_lines_data (xc_order_idx).inventory_item_id;

                    --                l_line_tbl(ln_line_index).ordered_item                            := lt_order_lines_data(xc_order_idx).ITEM_SEGMENT1;
                    l_line_tbl (ln_line_index).line_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).line_number   :=
                        lt_order_lines_data (xc_order_idx).line_number;

                    IF lt_order_lines_data (xc_order_idx).new_line_type_id
                           IS NULL
                    THEN
                        l_line_tbl (ln_line_index).line_type_id   :=
                            fnd_api.g_miss_num; --lt_order_lines_data(xc_order_idx).new_line_type_id;
                    ELSE
                        l_line_tbl (ln_line_index).line_type_id   :=
                            lt_order_lines_data (xc_order_idx).new_line_type_id;
                    END IF;

                    l_line_tbl (ln_line_index).ordered_quantity   :=
                        lt_order_lines_data (xc_order_idx).ordered_quantity;
                    l_line_tbl (ln_line_index).order_quantity_uom   :=
                        lt_order_lines_data (xc_order_idx).order_quantity_uom;
                    l_line_tbl (ln_line_index).org_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).orig_sys_document_ref   :=
                        lt_order_lines_data (xc_order_idx).orig_sys_document_ref; --||TO_CHAR(SYSDATE,'ddmmyyyyhhmiss');
                    l_line_tbl (ln_line_index).orig_sys_line_ref   :=
                        lt_order_lines_data (xc_order_idx).original_system_line_reference; --||TO_CHAR(SYSDATE,'ddmmyyyyhhmiss');
                    l_line_tbl (ln_line_index).fulfilled_quantity   :=
                        lt_order_lines_data (xc_order_idx).fulfilled_quantity;
                    l_line_tbl (ln_line_index).FULFILLMENT_DATE   :=
                        lt_order_lines_data (xc_order_idx).FULFILLMENT_DATE;

                    l_line_tbl (ln_line_index).ship_from_org_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).ship_to_contact_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).ship_to_org_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).sold_to_org_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).sold_from_org_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).ship_to_customer_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).invoice_to_customer_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).deliver_to_customer_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).unit_list_price   :=
                        lt_order_lines_data (xc_order_idx).unit_list_price;
                    l_line_tbl (ln_line_index).unit_selling_price   :=
                        lt_order_lines_data (xc_order_idx).unit_selling_price;
                    l_line_tbl (ln_line_index).latest_acceptable_date   :=
                        lt_order_lines_data (xc_order_idx).latest_acceptable_date;
                    l_line_tbl (ln_line_index).pricing_date   :=
                        lt_order_lines_data (xc_order_idx).pricing_date;
                    l_line_tbl (ln_line_index).calculate_price_flag   :=
                        'N';

                    l_line_tbl (ln_line_index).source_type_code   :=
                        lt_order_lines_data (xc_order_idx).source_type_code;
                    l_line_tbl (ln_line_index).ship_from_org_id   :=
                        lt_order_lines_data (xc_order_idx).new_ship_from;
                    --Meenakshi 15-Jun
                    l_line_tbl (ln_line_index).actual_shipment_date   :=
                        lt_order_lines_data (xc_order_idx).actual_shipment_date;

                    --Meenakshi 1-Sept
                    l_line_tbl (ln_line_index).request_date   :=
                        lt_order_lines_data (xc_order_idx).request_date;
                    l_line_tbl (ln_line_index).SHIPPING_INSTRUCTIONS   :=
                        lt_order_lines_data (xc_order_idx).SHIPPING_INSTRUCTIONS;

                    --   l_line_tbl(ln_line_index).schedule_status_code                         := 'SCHEDULED';
                    -- l_line_tbl(ln_line_index).schedule_action_code                         := 'SCHEDULED';
                    IF lt_order_lines_data (xc_order_idx).flow_status_code =
                       'CLOSED'
                    THEN
                        l_line_tbl (ln_line_index).flow_status_code   :=
                            'CLOSED';
                        l_line_tbl (ln_line_index).cancelled_flag   := 'N';
                        l_line_tbl (ln_line_index).booked_flag      := 'Y';
                        l_line_tbl (ln_line_index).open_flag        := 'N';
                        l_line_tbl (ln_line_index).fulfilled_quantity   :=
                            lt_order_lines_data (xc_order_idx).fulfilled_quantity;
                        l_line_tbl (ln_line_index).fulfilled_flag   :=
                            'Y';
                    --          l_line_tbl(ln_line_index).schedule_status_code                         := null;
                    --  l_line_tbl(ln_line_index).schedule_action_code                         := null;
                    ELSIF lt_order_lines_data (xc_order_idx).flow_status_code =
                          'CANCELLED'
                    THEN
                        l_line_tbl (ln_line_index).flow_status_code   :=
                            'CANCELLED';
                        l_line_tbl (ln_line_index).cancelled_flag   := 'Y';
                        l_line_tbl (ln_line_index).cancelled_quantity   :=
                            lt_order_lines_data (xc_order_idx).cancelled_quantity;
                        l_line_tbl (ln_line_index).schedule_status_code   :=
                            NULL;
                        l_line_tbl (ln_line_index).schedule_action_code   :=
                            NULL;
                        l_line_tbl (ln_line_index).shipping_method_code   :=
                            lt_order_lines_data (xc_order_idx).new_ship_method_code;
                        l_line_tbl (ln_line_index).fulfilled_flag   :=
                            'N';
                        l_line_tbl (ln_line_index).open_flag        :=
                            'N';
                    ELSIF lt_order_lines_data (xc_order_idx).flow_status_code =
                          'BOOKED'
                    THEN
                        l_line_tbl (ln_line_index).flow_status_code   :=
                            'BOOKED';
                        log_records (gc_debug_flag, 'In booked if   ');
                        l_line_tbl (ln_line_index).booked_flag   := 'Y';
                        l_line_tbl (ln_line_index).open_flag     := 'Y';
                        l_line_tbl (ln_line_index).cancelled_flag   :=
                            FND_API.G_MISS_CHAR;
                    ELSE
                        l_line_tbl (ln_line_index).flow_status_code   :=
                            'ENTERED'; --lt_order_lines_data(xc_order_idx).flow_status_code  ;--'ENTERED';
                        --l_line_tbl(ln_line_index).flow_status_code := lt_order_lines_data(xc_order_idx).flow_status_code;
                        l_open_line_flag   := 'Y';
                        --Meenakshi 18-May
                        l_line_tbl (ln_line_index).booked_flag   :=
                            FND_API.G_MISS_CHAR;
                    END IF;

                    log_records (
                        gc_debug_flag,
                           ' lt_order_lines_data(xc_order_idx).attribute20 '
                        || lt_order_lines_data (xc_order_idx).attribute20);

                    IF NVL (p_customer_type, 'XXX') = 'ECOMM'
                    THEN
                        l_line_tbl (ln_line_index).attribute1    :=
                            TO_CHAR (
                                TO_TIMESTAMP (
                                    lt_order_lines_data (xc_order_idx).attribute1,
                                    'DD-MON-RR'),
                                'YYYY/MM/DD HH24:MI:SS');
                        l_line_tbl (ln_line_index).attribute2    :=
                            lt_order_lines_data (xc_order_idx).attribute2;
                        l_line_tbl (ln_line_index).attribute3    :=
                            lt_order_lines_data (xc_order_idx).attribute3;
                        l_line_tbl (ln_line_index).attribute4    :=
                            lt_order_lines_data (xc_order_idx).new_attribute4;
                        l_line_tbl (ln_line_index).attribute5    :=
                            lt_order_lines_data (xc_order_idx).attribute5;
                        l_line_tbl (ln_line_index).attribute6    :=
                            lt_order_lines_data (xc_order_idx).attribute6;
                        l_line_tbl (ln_line_index).attribute7    :=
                            lt_order_lines_data (xc_order_idx).attribute7;
                        l_line_tbl (ln_line_index).attribute8    :=
                            lt_order_lines_data (xc_order_idx).attribute8;
                        l_line_tbl (ln_line_index).attribute9    :=
                            lt_order_lines_data (xc_order_idx).attribute9;
                        l_line_tbl (ln_line_index).attribute10   :=
                            lt_order_lines_data (xc_order_idx).attribute10;
                        l_line_tbl (ln_line_index).attribute11   :=
                            lt_order_lines_data (xc_order_idx).attribute11;
                        l_line_tbl (ln_line_index).attribute12   :=
                            lt_order_lines_data (xc_order_idx).attribute12;
                        l_line_tbl (ln_line_index).attribute13   :=
                            lt_order_lines_data (xc_order_idx).attribute13;

                        l_line_tbl (ln_line_index).context       :=
                            'DO eCommerce';
                        l_line_tbl (ln_line_index).attribute14   :=
                            lt_order_lines_data (xc_order_idx).attribute14;
                        l_line_tbl (ln_line_index).attribute15   :=
                            lt_order_lines_data (xc_order_idx).attribute15;
                        l_line_tbl (ln_line_index).attribute16   :=
                            lt_order_lines_data (xc_order_idx).attribute16;
                        l_line_tbl (ln_line_index).attribute17   := 'N'; --lt_order_lines_data(xc_order_idx).attribute17;
                        l_line_tbl (ln_line_index).attribute18   :=
                            lt_order_lines_data (xc_order_idx).attribute18;
                        l_line_tbl (ln_line_index).attribute19   :=
                            lt_order_lines_data (xc_order_idx).attribute19;
                        l_line_tbl (ln_line_index).attribute20   :=
                            lt_order_lines_data (xc_order_idx).attribute20;
                    ELSE
                        --                l_line_tbl(ln_line_index).context                                 := lt_order_lines_data(xc_order_idx).context;
                        l_line_tbl (ln_line_index).attribute1    :=
                            TO_CHAR (
                                TO_TIMESTAMP (
                                    lt_order_lines_data (xc_order_idx).attribute1,
                                    'DD-MON-RR'),
                                'YYYY/MM/DD HH24:MI:SS');
                        l_line_tbl (ln_line_index).attribute2    := NULL;
                        l_line_tbl (ln_line_index).attribute3    := NULL;
                        l_line_tbl (ln_line_index).attribute4    :=
                            lt_order_lines_data (xc_order_idx).new_attribute4;
                        l_line_tbl (ln_line_index).attribute5    :=
                            lt_order_lines_data (xc_order_idx).attribute5;
                        l_line_tbl (ln_line_index).attribute6    :=
                            lt_order_lines_data (xc_order_idx).attribute6;
                        l_line_tbl (ln_line_index).attribute7    :=
                            lt_order_lines_data (xc_order_idx).attribute7;
                        l_line_tbl (ln_line_index).attribute8    :=
                            lt_order_lines_data (xc_order_idx).attribute8;
                        l_line_tbl (ln_line_index).attribute9    := NULL;
                        l_line_tbl (ln_line_index).attribute10   :=
                            lt_order_lines_data (xc_order_idx).attribute10;
                        l_line_tbl (ln_line_index).attribute11   := NULL;
                        l_line_tbl (ln_line_index).attribute12   :=
                            lt_order_lines_data (xc_order_idx).attribute12;
                        l_line_tbl (ln_line_index).attribute13   := NULL; --lt_order_lines_data(xc_order_idx).attribute13;
                        l_line_tbl (ln_line_index).attribute14   := NULL; --lt_order_lines_data(xc_order_idx).attribute14;
                        --See Conversion Instructions
                        l_line_tbl (ln_line_index).attribute15   := NULL;
                        l_line_tbl (ln_line_index).attribute16   := NULL; --lt_order_lines_data(xc_order_idx).attribute16;
                        l_line_tbl (ln_line_index).attribute17   := NULL; --lt_order_lines_data(xc_order_idx).attribute17;
                        l_line_tbl (ln_line_index).attribute18   := NULL; --lt_order_lines_data(xc_order_idx).attribute18;
                        l_line_tbl (ln_line_index).attribute19   := NULL; --lt_order_lines_data(xc_order_idx).attribute19;
                        l_line_tbl (ln_line_index).attribute20   := NULL; --lt_order_lines_data(xc_order_idx).attribute20;
                    END IF;

                    IF lt_order_lines_data (xc_order_idx).line_category_code =
                       'RETURN'
                    THEN
                        l_line_tbl (ln_line_index).return_reason_code   :=
                            lt_order_lines_data (xc_order_idx).return_reason_code; --'30_DAYS_RETURN';--lt_order_lines_data(xc_order_idx).return_reason_code;

                        -- l_line_tbl(ln_line_index).reference_line_id := lt_order_lines_data(xc_order_idx)
                        --                                                .new_reference_line_id; -- Original order line_id
                        --  l_line_tbl(ln_line_index).reference_header_id := lt_order_lines_data(xc_order_idx)
                        --                                                  .new_reference_header_id; -- Original order header_id
                        --Meenakshi 18-May
                        IF lt_order_lines_data (xc_order_idx).return_context
                               IS NOT NULL
                        THEN
                            l_line_tbl (ln_line_index).return_context   :=
                                lt_order_lines_data (xc_order_idx).return_context;
                        ELSE
                            l_line_tbl (ln_line_index).return_context   :=
                                fnd_api.g_miss_char;
                        END IF;

                        -- l_line_tbl(ln_line_index).return_context := 'ORDER';
                        --  l_line_tbl(ln_line_index).return_attribute1 := lt_order_lines_data(xc_order_idx)
                        --                                                .new_reference_header_id; -- Original order header_id
                        -- l_line_tbl(ln_line_index).return_attribute2 := lt_order_lines_data(xc_order_idx)
                        --                                                .new_reference_line_id; -- Original order line_id
                        l_line_tbl (ln_line_index).line_category_code   :=
                            lt_order_lines_data (xc_order_idx).line_category_code;
                    ELSE
                        l_line_tbl (ln_line_index).return_reason_code   :=
                            fnd_api.g_miss_char;
                    --   l_line_tbl (ln_line_index).reference_line_id := FND_API.G_MISS_CHAR; -- Original order line_id
                    --      l_line_tbl (ln_line_index).reference_header_id := FND_API.G_MISS_CHAR; -- Original order header_id
                    --      l_line_tbl(ln_line_index).return_context := FND_API.G_MISS_CHAR;
                    --      l_line_tbl (ln_line_index).return_attribute1 :=FND_API.G_MISS_CHAR; -- Original order header_id
                    --     l_line_tbl (ln_line_index).return_attribute2 := FND_API.G_MISS_CHAR;
                    END IF;

                    log_records (
                        gc_debug_flag,
                           'lt_order_lines_data(xc_order_idx).tax_value '
                        || lt_order_lines_data (xc_order_idx).tax_value);
                    l_line_tbl (ln_line_index).tax_code   :=
                        lt_order_lines_data (xc_order_idx).new_tax_code;
                    l_line_tbl (ln_line_index).tax_date   :=
                        lt_order_lines_data (xc_order_idx).tax_date;
                    l_line_tbl (ln_line_index).tax_exempt_flag   :=
                        lt_order_lines_data (xc_order_idx).tax_exempt_flag;
                    l_line_tbl (ln_line_index).tax_exempt_number   :=
                        lt_order_lines_data (xc_order_idx).tax_exempt_number;
                    l_line_tbl (ln_line_index).tax_exempt_reason_code   :=
                        lt_order_lines_data (xc_order_idx).tax_exempt_reason_code;
                    l_line_tbl (ln_line_index).tax_point_code   :=
                        lt_order_lines_data (xc_order_idx).tax_point_code;
                    l_line_tbl (ln_line_index).tax_rate   :=
                        lt_order_lines_data (xc_order_idx).tax_rate;
                    l_line_tbl (ln_line_index).tax_value   :=
                        TO_NUMBER (
                            lt_order_lines_data (xc_order_idx).tax_value);
                    l_line_tbl (ln_line_index).shipment_priority_code   :=
                        lt_order_lines_data (xc_order_idx).shipment_priority_code;

                    --jerry modify 12-may
                    --default shipment priority to null for DC
                    IF UPPER (
                           SUBSTR (
                               lt_order_lines_data (xc_order_idx).shipment_priority_code,
                               1,
                               2)) =
                       'DC'
                    THEN
                        l_line_tbl (ln_line_index).shipment_priority_code   :=
                            '';
                    END IF;

                    IF     lt_order_lines_data (xc_order_idx).schedule_ship_date
                               IS NOT NULL
                       AND lt_order_lines_data (xc_order_idx).flow_status_code <>
                           'BOOKED'
                    THEN                                    --Meenakshi 2-Sept
                        log_records (gc_debug_flag,
                                     'in schedule ship date if  ');
                        l_line_tbl (ln_line_index).schedule_status_code   :=
                            'SCHEDULED';
                        l_line_tbl (ln_line_index).schedule_action_code   :=
                            'SCHEDULED';
                        l_line_tbl (ln_line_index).schedule_ship_date   :=
                            lt_order_lines_data (xc_order_idx).schedule_ship_date;
                        l_line_tbl (ln_line_index).schedule_arrival_date   :=
                            lt_order_lines_data (xc_order_idx).schedule_arrival_date;
                        l_line_tbl (ln_line_index).override_atp_date_code   :=
                            'Y';
                    /*Visible Demand Flag Is 'N' Even Though Sales Order Is Booked With Available Scheduled Date When Using Order Import (Doc ID 1569211.1)

                    GOAL
                    To explain why the Visible demand flag may be getting set as 'N' even though the sales order is booked with an available scheduled date
                    when using Order Import for Sales Order creation.

                    SOLUTION
                    It is mandatory to set the Profile OM: Bypass ATP to Yes, for the visible_demand_flag to be populated.

                     If wishing to retain the legacy shipment_date and the visible_demand_flag to be set to 'Y', populate the field '
                     override_atp_date_code' in the table 'oe_lines_iface_all' to 'Y at the time of order import.

                    */
                    --  IF lt_order_lines_data(xc_order_idx).source_type_code <> 'EXTERNAL' OR
                    --        p_customer_type          = 'RMS' THEN
                    --     l_line_tbl(ln_line_index).Override_atp_date_code                  := 'Y';
                    --    l_line_tbl(ln_line_index).tax_code                                := lt_order_lines_data(xc_order_idx).tax_code;
                    --    l_line_tbl(ln_line_index).tax_date                                := lt_order_lines_data(xc_order_idx).tax_date;
                    --    l_line_tbl(ln_line_index).tax_exempt_flag                         := lt_order_lines_data(xc_order_idx).tax_exempt_flag;
                    --    l_line_tbl(ln_line_index).tax_exempt_number                       := lt_order_lines_data(xc_order_idx).tax_exempt_number;
                    --    l_line_tbl(ln_line_index).tax_exempt_reason_code                  := lt_order_lines_data(xc_order_idx).tax_exempt_reason_code;
                    --   l_line_tbl(ln_line_index).tax_point_code                          := lt_order_lines_data(xc_order_idx).tax_point_code;
                    --   l_line_tbl(ln_line_index).tax_rate                                := lt_order_lines_data(xc_order_idx).tax_rate;
                    --   l_line_tbl(ln_line_index).tax_value                               := lt_order_lines_data(xc_order_idx).tax_value;

                    --   ELSE
                    --    l_line_tbl(ln_line_index).drop_ship_flag                          := 'Y';
                    --    END IF;
                    --                l_line_tbl(ln_line_index).visible_demand_flag                     := FND_API.G_MISS_CHAR;
                    --jerry modify 15-may
                    ELSE
                        l_line_tbl (ln_line_index).schedule_ship_date   := '';
                        l_line_tbl (ln_line_index).visible_demand_flag   :=
                            'Y';
                    -- l_line_tbl(ln_line_index).override_atp_date_code := 'Y';
                    --   l_line_tbl(ln_line_index).schedule_ship_date := lt_order_lines_data(xc_order_idx).schedule_ship_date;
                    END IF;

                    ---creating line adjustemnts
                    log_records (gc_debug_flag,
                                 'p_header_id  ' || p_header_id);
                    log_records (
                        gc_debug_flag,
                           'l_line_tbl(ln_line_index).line_id '
                        || TO_NUMBER (
                               lt_order_lines_data (xc_order_idx).line_id));

                    OPEN cur_order_lines_adj (
                        TO_NUMBER (
                            lt_order_lines_data (xc_order_idx).line_id));

                    LOOP
                        FETCH cur_order_lines_adj
                            BULK COLLECT INTO lt_lines_adj_data
                            LIMIT 50;

                        EXIT WHEN lt_lines_adj_data.COUNT = 0;

                        IF lt_lines_adj_data.COUNT > 0
                        THEN
                            FOR xc_line_adj_idx IN lt_lines_adj_data.FIRST ..
                                                   lt_lines_adj_data.LAST
                            LOOP
                                log_records (
                                    gc_debug_flag,
                                    'Assigning values in price adj lines+');

                                log_records (
                                    gc_debug_flag,
                                       'new line id '
                                    || lt_lines_adj_data (xc_line_adj_idx).new_list_line_id);
                                log_records (
                                    gc_debug_flag,
                                       'new header id '
                                    || lt_lines_adj_data (xc_line_adj_idx).new_list_header_id);
                                log_records (
                                    gc_debug_flag,
                                       'Operand '
                                    || lt_lines_adj_data (xc_line_adj_idx).operand);
                                log_records (
                                    gc_debug_flag,
                                       'Arithmetic operator '
                                    || lt_lines_adj_data (xc_line_adj_idx).arithmetic_operator);
                                log_records (
                                    gc_debug_flag,
                                       'List type code '
                                    || lt_lines_adj_data (xc_line_adj_idx).list_line_type_code);
                                log_records (
                                    gc_debug_flag,
                                       'List line num '
                                    || lt_lines_adj_data (xc_line_adj_idx).new_list_line_no);

                                ln_line_adj_index   := ln_line_adj_index + 1;
                                l_line_adj_tbl (ln_line_adj_index)   :=
                                    oe_order_pub.g_miss_line_adj_rec;
                                l_line_adj_tbl (ln_line_adj_index).operation   :=
                                    oe_globals.g_opr_create;
                                l_line_adj_tbl (ln_line_adj_index).price_adjustment_id   :=
                                    oe_price_adjustments_s.NEXTVAL;
                                l_line_adj_tbl (ln_line_adj_index).header_id   :=
                                    fnd_api.g_miss_num;
                                ------------------- PASS HEADER ID
                                l_line_adj_tbl (ln_line_adj_index).line_id   :=
                                    fnd_api.g_miss_num;
                                ----------------------- PASS LINE ID
                                l_line_adj_tbl (ln_line_adj_index).line_index   :=
                                    ln_line_index;
                                l_line_adj_tbl (ln_line_adj_index).automatic_flag   :=
                                    'N';
                                --  l_line_adj_tbl(ln_line_adj_index).orig_sys_discount_ref :=  lt_lines_adj_data(xc_line_adj_idx).ORIG_SYS_DISCOUNT_REF;
                                l_line_adj_tbl (ln_line_adj_index).list_header_id   :=
                                    lt_lines_adj_data (xc_line_adj_idx).new_list_header_id; --from validation
                                l_line_adj_tbl (ln_line_adj_index).list_line_id   :=
                                    lt_lines_adj_data (xc_line_adj_idx).new_list_line_id; -- find out how to get this using list line number
                                l_line_adj_tbl (ln_line_adj_index).list_line_type_code   :=
                                    lt_lines_adj_data (xc_line_adj_idx).list_line_type_code;
                                -- l_line_adj_tbl(ln_line_adj_index).update_allowed :='Y';--  lt_lines_adj_data(xc_line_adj_idx).update_allowed;
                                l_line_adj_tbl (ln_line_adj_index).updated_flag   :=
                                    'Y'; -- lt_lines_adj_data(xc_line_adj_idx).updated_flag;
                                l_line_adj_tbl (ln_line_adj_index).applied_flag   :=
                                    'Y'; -- lt_lines_adj_data(xc_line_adj_idx).applied_flag;
                                l_line_adj_tbl (ln_line_adj_index).operand   :=
                                    lt_lines_adj_data (xc_line_adj_idx).operand;
                                l_line_adj_tbl (ln_line_adj_index).arithmetic_operator   :=
                                    lt_lines_adj_data (xc_line_adj_idx).arithmetic_operator;
                                l_line_adj_tbl (ln_line_adj_index).adjusted_amount   :=
                                    lt_lines_adj_data (xc_line_adj_idx).adjusted_amount;
                                --   l_line_adj_tbl(ln_line_adj_index).pricing_phase_id :=  lt_lines_adj_data(xc_line_adj_idx).pricing_phase_id;
                                --  l_line_adj_tbl(ln_line_adj_index).accrual_flag :=  lt_lines_adj_data(xc_line_adj_idx).accrual_flag;
                                --   l_line_adj_tbl(ln_line_adj_index).list_line_no :=  lt_lines_adj_data(xc_line_adj_idx).NEW_LIST_line_no;
                                --   l_line_adj_tbl(ln_line_adj_index).source_system_code := 'QP';
                                --   l_line_adj_tbl(ln_line_adj_index).modifier_level_code :=  lt_lines_adj_data(xc_line_adj_idx).MODIFIER_LEVEL_CODE;
                                --   l_line_adj_tbl(ln_line_adj_index).proration_type_code :=  lt_lines_adj_data(xc_line_adj_idx).proration_type_code ;
                                l_line_adj_tbl (ln_line_adj_index).operand_per_pqty   :=
                                    lt_lines_adj_data (xc_line_adj_idx).operand_per_pqty;
                                l_line_adj_tbl (ln_line_adj_index).adjusted_amount_per_pqty   :=
                                    lt_lines_adj_data (xc_line_adj_idx).adjusted_amount_per_pqty;
                                --   l_line_adj_tbl(ln_line_adj_index).change_reason_code := lt_lines_adj_data(xc_line_adj_idx).CHANGE_REASON_CODE;
                                -- l_line_adj_tbl(ln_line_adj_index).change_reason_text :=  lt_lines_adj_data(xc_line_adj_idx).CHANGE_REASON_text;
                                --added by me
                                l_line_adj_tbl (ln_line_adj_index).charge_type_code   :=
                                    lt_lines_adj_data (xc_line_adj_idx).charge_type_code;

                                l_line_adj_tbl (ln_line_adj_index).attribute1   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute1;
                                l_line_adj_tbl (ln_line_adj_index).attribute10   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute10;
                                l_line_adj_tbl (ln_line_adj_index).attribute11   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute11;
                                l_line_adj_tbl (ln_line_adj_index).attribute12   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute12;
                                l_line_adj_tbl (ln_line_adj_index).attribute13   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute13;
                                l_line_adj_tbl (ln_line_adj_index).attribute14   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute14;
                                l_line_adj_tbl (ln_line_adj_index).attribute15   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute15;
                                l_line_adj_tbl (ln_line_adj_index).attribute2   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute2;
                                l_line_adj_tbl (ln_line_adj_index).attribute3   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute3;
                                l_line_adj_tbl (ln_line_adj_index).attribute4   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute4;
                                l_line_adj_tbl (ln_line_adj_index).attribute5   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute5;
                                l_line_adj_tbl (ln_line_adj_index).attribute6   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute6;
                                l_line_adj_tbl (ln_line_adj_index).attribute7   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute7;
                                l_line_adj_tbl (ln_line_adj_index).attribute8   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute8;
                                l_line_adj_tbl (ln_line_adj_index).attribute9   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute9;
                            /*l_line_adj_tbl(ln_line_adj_index).context  :=  lt_lines_adj_data(xc_line_adj_idx).context;
                              l_line_adj_tbl(ln_line_adj_index).modifier_mechanism_type_code  :=  lt_lines_adj_data(xc_line_adj_idx).MODIFIER_MECHANISM_TYPE_CODE;
                                l_line_adj_tbl(ln_line_adj_index).modified_from              :=  lt_lines_adj_data(xc_line_adj_idx).modified_from ;
                                l_line_adj_tbl(ln_line_adj_index).modified_to                  :=  lt_lines_adj_data(xc_line_adj_idx).modified_to ;
                                l_line_adj_tbl(ln_line_adj_index).tax_code        :=  lt_lines_adj_data(xc_line_adj_idx).tax_code;
                                l_line_adj_tbl(ln_line_adj_index).tax_exempt_flag               :=  lt_lines_adj_data(xc_line_adj_idx).tax_exempt_flag;
                                l_line_adj_tbl(ln_line_adj_index).tax_exempt_number             :=  lt_lines_adj_data(xc_line_adj_idx).tax_exempt_number;
                                l_line_adj_tbl(ln_line_adj_index).tax_exempt_reason_code         :=  lt_lines_adj_data(xc_line_adj_idx).tax_exempt_reason_code ;
                               -- l_line_adj_tbl(ln_line_adj_index).invoiced_flag                  :=  lt_lines_adj_data(xc_line_adj_idx).invoiced_flag;
                               -- l_line_adj_tbl(ln_line_adj_index).estimated_flag                 :=  lt_lines_adj_data(xc_line_adj_idx).estimated_flag;
                                --l_line_adj_tbl(ln_line_adj_index).inc_in_sales_performance       :=  lt_lines_adj_data(xc_line_adj_idx).inc_in_sales_performance ;
                               -- l_line_adj_tbl(ln_line_adj_index).split_action_code              :=  lt_lines_adj_data(xc_line_adj_idx).split_action_code;
                              --  l_line_adj_tbl(ln_line_adj_index).charge_type_code              :=  lt_lines_adj_data(xc_line_adj_idx).charge_type_code;
                               -- l_line_adj_tbl(ln_line_adj_index).charge_subtype_code           :=  lt_lines_adj_data(xc_line_adj_idx).charge_subtype_code;
                                l_line_adj_tbl(ln_line_adj_index).source_system_code             :=  lt_lines_adj_data(xc_line_adj_idx).source_system_code;
                               -- l_line_adj_tbl(ln_line_adj_index).benefit_qty                    :=  lt_lines_adj_data(xc_line_adj_idx).benefit_qty;
                               -- l_line_adj_tbl(ln_line_adj_index).benefit_uom_code               :=  lt_lines_adj_data(xc_line_adj_idx).benefit_uom_code ;
                                l_line_adj_tbl(ln_line_adj_index).print_on_invoice_flag          :=  lt_lines_adj_data(xc_line_adj_idx).print_on_invoice_flag ;
                               -- l_line_adj_tbl(ln_line_adj_index).expiration_date                :=  lt_lines_adj_data(xc_line_adj_idx).expiration_date ;
                               -- l_line_adj_tbl(ln_line_adj_index).rebate_transaction_type_code   :=  lt_lines_adj_data(xc_line_adj_idx).rebate_transaction_type_code ;
                               -- l_line_adj_tbl(ln_line_adj_index).rebate_transaction_reference   :=  lt_lines_adj_data(xc_line_adj_idx).rebate_transaction_reference;
                               -- l_line_adj_tbl(ln_line_adj_index).rebate_payment_system_code     :=  lt_lines_adj_data(xc_line_adj_idx).rebate_payment_system_code;
                               -- l_line_adj_tbl(ln_line_adj_index).redeemed_date                  :=  lt_lines_adj_data(xc_line_adj_idx).redeemed_date;
                               -- l_line_adj_tbl(ln_line_adj_index).redeemed_flag                  :=  lt_lines_adj_data(xc_line_adj_idx).redeemed_flag;
                                l_line_adj_tbl(ln_line_adj_index).accrual_flag                 :=  lt_lines_adj_data(xc_line_adj_idx).accrual_flag;
                                l_line_adj_tbl(ln_line_adj_index).range_break_quantity             :=  lt_lines_adj_data(xc_line_adj_idx).range_break_quantity ;
                                l_line_adj_tbl(ln_line_adj_index).accrual_conversion_rate         :=  lt_lines_adj_data(xc_line_adj_idx).accrual_conversion_rate ;
                               -- l_line_adj_tbl(ln_line_adj_index).pricing_group_sequence         :=  lt_lines_adj_data(xc_line_adj_idx).pricing_group_sequence;
                                l_line_adj_tbl(ln_line_adj_index).price_break_type_code         :=  lt_lines_adj_data(xc_line_adj_idx).price_break_type_code;
                                l_line_adj_tbl(ln_line_adj_index).substitution_attribute         :=  lt_lines_adj_data(xc_line_adj_idx).substitution_attribute;
                               -- l_line_adj_tbl(ln_line_adj_index).proration_type_code             :=  lt_lines_adj_data(xc_line_adj_idx).proration_type_code ;
                                l_line_adj_tbl(ln_line_adj_index).credit_or_charge_flag          :=  lt_lines_adj_data(xc_line_adj_idx).credit_or_charge_flag;
                                l_line_adj_tbl(ln_line_adj_index).include_on_returns_flag         :=  lt_lines_adj_data(xc_line_adj_idx).include_on_returns_flag;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute1                   :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute1 ;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute10                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute10;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute11                 :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute11;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute12                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute12;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute13                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute13;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute14                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute14;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute15                 :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute15;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute2                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute2;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute3                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute3;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute4                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute4;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute5                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute5;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute6                 :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute6;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute7                   :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute7;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute8                   :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute8;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute9                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute9;
                                l_line_adj_tbl(ln_line_adj_index).ac_context                     :=  lt_lines_adj_data(xc_line_adj_idx).ac_context;
                                l_line_adj_tbl(ln_line_adj_index).invoiced_amount                :=  lt_lines_adj_data(xc_line_adj_idx).invoiced_amount;
                            */

                            END LOOP;                           --adj for loop
                        END IF;                                 --if adj count
                    END LOOP;                                   --adj for loop

                    CLOSE cur_order_lines_adj;
                END LOOP;
            END IF;
        END LOOP;

        p_line_tbl         := l_line_tbl;
        p_adj_line_tbl     := l_line_adj_tbl;
        x_open_line_flag   := l_open_line_flag;

        CLOSE cur_order_lines;

        x_retrun_status    := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Un-expecetd Error in  create_order_line => ' || SQLERRM);
            --    ROLLBACK;
            x_retrun_status   := 'E';
    END create_order_line;

    -- closed order lines

    PROCEDURE create_order_closed_line (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_action IN VARCHAR2, p_header_id IN NUMBER, p_customer_type IN VARCHAR2, p_line_tbl OUT oe_order_pub.line_tbl_type
                                        , p_adj_line_tbl OUT oe_order_pub.line_adj_tbl_type, x_retrun_status OUT VARCHAR2, x_closed_line_flag OUT VARCHAR2)
    AS
        CURSOR cur_order_lines IS
            (SELECT *
               FROM xxd_ont_open_so_lines_stg_t cust
              WHERE     header_id = p_header_id
                    AND flow_status_code IN
                            ('CLOSED', 'CANCELLED', 'INVOICED' /*,'AWAITING_RETURN'*/
                                                              )); --jerry modify 15-may

        CURSOR cur_order_lines_adj (p_line_id NUMBER)
        IS
            SELECT *
              FROM xxd_ont_open_price_adj_l_stg_t cust
             WHERE header_id = p_header_id AND line_id = p_line_id;

        l_line_adj_tbl        oe_order_pub.line_adj_tbl_type;

        l_line_tbl            oe_order_pub.line_tbl_type;
        ln_line_index         NUMBER := 0;
        l_closed_line_flag    VARCHAR2 (1) := 'N';

        TYPE lt_order_lines_typ IS TABLE OF cur_order_lines%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_order_lines_data   lt_order_lines_typ;

        ln_line_adj_index     NUMBER := 0;

        TYPE lt_lines_adj_typ IS TABLE OF cur_order_lines_adj%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_lines_adj_data     lt_lines_adj_typ;
    BEGIN
        log_records (gc_debug_flag, 'Inside create_order_closed_line +');

        OPEN cur_order_lines;

        LOOP
            FETCH cur_order_lines
                BULK COLLECT INTO lt_order_lines_data
                LIMIT 50;

            EXIT WHEN lt_order_lines_data.COUNT = 0;

            IF lt_order_lines_data.COUNT > 0
            THEN
                FOR xc_order_idx IN lt_order_lines_data.FIRST ..
                                    lt_order_lines_data.LAST
                LOOP
                    ln_line_index   := ln_line_index + 1;
                    l_line_tbl (ln_line_index)   :=
                        oe_order_pub.g_miss_line_rec;
                    l_line_tbl (ln_line_index).operation   :=
                        oe_globals.g_opr_create;
                    l_line_tbl (ln_line_index).header_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).ordered_item_id   :=
                        fnd_api.g_miss_num; --3274788 ;--lt_order_lines_data(xc_order_idx).inventory_item_id;
                    l_line_tbl (ln_line_index).inventory_item_id   :=
                        lt_order_lines_data (xc_order_idx).inventory_item_id;

                    --                l_line_tbl(ln_line_index).ordered_item                            := lt_order_lines_data(xc_order_idx).ITEM_SEGMENT1;
                    l_line_tbl (ln_line_index).line_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).line_number   :=
                        lt_order_lines_data (xc_order_idx).line_number;

                    IF lt_order_lines_data (xc_order_idx).new_line_type_id
                           IS NULL
                    THEN
                        l_line_tbl (ln_line_index).line_type_id   :=
                            fnd_api.g_miss_num; --lt_order_lines_data(xc_order_idx).new_line_type_id;
                    ELSE
                        l_line_tbl (ln_line_index).line_type_id   :=
                            lt_order_lines_data (xc_order_idx).new_line_type_id;
                    END IF;

                    l_line_tbl (ln_line_index).ordered_quantity   :=
                        lt_order_lines_data (xc_order_idx).ordered_quantity;
                    l_line_tbl (ln_line_index).order_quantity_uom   :=
                        lt_order_lines_data (xc_order_idx).order_quantity_uom;
                    l_line_tbl (ln_line_index).org_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).orig_sys_document_ref   :=
                        lt_order_lines_data (xc_order_idx).orig_sys_document_ref; --||TO_CHAR(SYSDATE,'ddmmyyyyhhmiss');
                    l_line_tbl (ln_line_index).orig_sys_line_ref   :=
                        lt_order_lines_data (xc_order_idx).original_system_line_reference; --||TO_CHAR(SYSDATE,'ddmmyyyyhhmiss');
                    l_line_tbl (ln_line_index).fulfilled_quantity   :=
                        lt_order_lines_data (xc_order_idx).fulfilled_quantity;
                    l_line_tbl (ln_line_index).FULFILLMENT_DATE   :=
                        lt_order_lines_data (xc_order_idx).FULFILLMENT_DATE;
                    l_line_tbl (ln_line_index).ship_from_org_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).ship_to_contact_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).ship_to_org_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).sold_to_org_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).sold_from_org_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).ship_to_customer_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).invoice_to_customer_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).deliver_to_customer_id   :=
                        fnd_api.g_miss_num;
                    l_line_tbl (ln_line_index).unit_list_price   :=
                        lt_order_lines_data (xc_order_idx).unit_list_price;
                    l_line_tbl (ln_line_index).unit_selling_price   :=
                        lt_order_lines_data (xc_order_idx).unit_selling_price;
                    l_line_tbl (ln_line_index).latest_acceptable_date   :=
                        lt_order_lines_data (xc_order_idx).latest_acceptable_date;
                    l_line_tbl (ln_line_index).pricing_date   :=
                        lt_order_lines_data (xc_order_idx).pricing_date;
                    l_line_tbl (ln_line_index).calculate_price_flag   :=
                        'N';

                    l_line_tbl (ln_line_index).source_type_code   :=
                        lt_order_lines_data (xc_order_idx).source_type_code;
                    l_line_tbl (ln_line_index).ship_from_org_id   :=
                        lt_order_lines_data (xc_order_idx).new_ship_from;
                    --Meenakshi 15-Jun
                    l_line_tbl (ln_line_index).actual_shipment_date   :=
                        lt_order_lines_data (xc_order_idx).actual_shipment_date;
                    --Meenakshi 1-Sept
                    l_line_tbl (ln_line_index).request_date   :=
                        lt_order_lines_data (xc_order_idx).request_date;
                    l_line_tbl (ln_line_index).SHIPPING_INSTRUCTIONS   :=
                        lt_order_lines_data (xc_order_idx).SHIPPING_INSTRUCTIONS;

                    --Meenakshi 9-Aug
                    l_line_tbl (ln_line_index).schedule_status_code   :=
                        'SCHEDULED';
                    l_line_tbl (ln_line_index).schedule_action_code   :=
                        'SCHEDULED';

                    IF /*lt_order_lines_data(xc_order_idx).flow_status_code = 'CLOSED'*/
                       lt_order_lines_data (xc_order_idx).flow_status_code IN
                           ('CLOSED', 'INVOICED'        /*,'AWAITING_RETURN'*/
                                                )        --jerry modify 15-may
                    THEN
                        l_line_tbl (ln_line_index).flow_status_code   :=
                            'CLOSED';
                        l_line_tbl (ln_line_index).cancelled_flag   := 'N';
                        l_line_tbl (ln_line_index).booked_flag      := /*'N' */
                                                                       'Y'; --jerry modify 14-may
                        l_line_tbl (ln_line_index).open_flag        := 'N';
                        l_line_tbl (ln_line_index).fulfilled_quantity   :=
                            lt_order_lines_data (xc_order_idx).fulfilled_quantity;
                        l_line_tbl (ln_line_index).fulfilled_flag   :=
                            'Y';
                        l_closed_line_flag                          :=
                            'Y';
                    --          l_line_tbl(ln_line_index).schedule_status_code                         := null;
                    --  l_line_tbl(ln_line_index).schedule_action_code                         := null;
                    ELSIF lt_order_lines_data (xc_order_idx).flow_status_code =
                          'CANCELLED'
                    THEN
                        l_line_tbl (ln_line_index).flow_status_code   :=
                            'CANCELLED';
                        l_line_tbl (ln_line_index).cancelled_flag   := 'Y';
                        l_line_tbl (ln_line_index).cancelled_quantity   :=
                            lt_order_lines_data (xc_order_idx).cancelled_quantity;
                        l_line_tbl (ln_line_index).schedule_status_code   :=
                            NULL;
                        l_line_tbl (ln_line_index).schedule_action_code   :=
                            NULL;
                        l_line_tbl (ln_line_index).shipping_method_code   :=
                            lt_order_lines_data (xc_order_idx).new_ship_method_code;
                        l_line_tbl (ln_line_index).fulfilled_flag   :=
                            'N';
                        l_line_tbl (ln_line_index).open_flag        :=
                            'N';
                        l_line_tbl (ln_line_index).booked_flag      :=
                            'N'; --jerry modify 18-may for error 'Quantity cannot be greater than original ordered quantity'
                        l_closed_line_flag                          :=
                            'Y';
                    ELSE
                        l_line_tbl (ln_line_index).flow_status_code   :=
                            'ENTERED'; --lt_order_lines_data(xc_order_idx).flow_status_code  ;--'ENTERED';
                    END IF;

                    l_line_tbl (ln_line_index).line_category_code   :=
                        lt_order_lines_data (xc_order_idx).line_category_code;

                    IF NVL (p_customer_type, 'XXX') = 'ECOMM'
                    THEN
                        l_line_tbl (ln_line_index).attribute1   :=
                            TO_CHAR (
                                TO_TIMESTAMP (
                                    lt_order_lines_data (xc_order_idx).attribute1,
                                    'DD-MON-RR'),
                                'YYYY/MM/DD HH24:MI:SS');
                        l_line_tbl (ln_line_index).attribute2   :=
                            lt_order_lines_data (xc_order_idx).attribute2;
                        l_line_tbl (ln_line_index).attribute3   :=
                            lt_order_lines_data (xc_order_idx).attribute3;
                        l_line_tbl (ln_line_index).attribute4   :=
                            lt_order_lines_data (xc_order_idx).new_attribute4;
                        l_line_tbl (ln_line_index).attribute5   :=
                            lt_order_lines_data (xc_order_idx).attribute5;
                        l_line_tbl (ln_line_index).attribute6   :=
                            lt_order_lines_data (xc_order_idx).attribute6;
                        l_line_tbl (ln_line_index).attribute7   :=
                            lt_order_lines_data (xc_order_idx).attribute7;
                        l_line_tbl (ln_line_index).attribute8   :=
                            lt_order_lines_data (xc_order_idx).attribute8;
                        l_line_tbl (ln_line_index).attribute9   :=
                            lt_order_lines_data (xc_order_idx).attribute9;
                        l_line_tbl (ln_line_index).attribute10   :=
                            lt_order_lines_data (xc_order_idx).attribute10;
                        l_line_tbl (ln_line_index).attribute11   :=
                            lt_order_lines_data (xc_order_idx).attribute11;
                        l_line_tbl (ln_line_index).attribute12   :=
                            lt_order_lines_data (xc_order_idx).attribute12;
                        l_line_tbl (ln_line_index).attribute13   :=
                            lt_order_lines_data (xc_order_idx).attribute13;

                        l_line_tbl (ln_line_index).context   :=
                            'DO eCommerce';
                        l_line_tbl (ln_line_index).attribute14   :=
                            lt_order_lines_data (xc_order_idx).attribute14;
                        l_line_tbl (ln_line_index).attribute15   :=
                            lt_order_lines_data (xc_order_idx).attribute15;
                        l_line_tbl (ln_line_index).attribute16   :=
                            lt_order_lines_data (xc_order_idx).attribute16;
                        l_line_tbl (ln_line_index).attribute17   :=
                            lt_order_lines_data (xc_order_idx).attribute17;
                        l_line_tbl (ln_line_index).attribute18   :=
                            lt_order_lines_data (xc_order_idx).attribute18;
                        l_line_tbl (ln_line_index).attribute19   :=
                            lt_order_lines_data (xc_order_idx).attribute19;
                        l_line_tbl (ln_line_index).attribute20   :=
                            lt_order_lines_data (xc_order_idx).attribute20;
                    ELSE
                        --                l_line_tbl(ln_line_index).context                                 := lt_order_lines_data(xc_order_idx).context;
                        l_line_tbl (ln_line_index).attribute1    :=
                            TO_CHAR (
                                TO_TIMESTAMP (
                                    lt_order_lines_data (xc_order_idx).attribute1,
                                    'DD-MON-RR'),
                                'YYYY/MM/DD HH24:MI:SS');
                        l_line_tbl (ln_line_index).attribute2    := NULL;
                        l_line_tbl (ln_line_index).attribute3    := NULL;
                        l_line_tbl (ln_line_index).attribute4    :=
                            lt_order_lines_data (xc_order_idx).new_attribute4;
                        l_line_tbl (ln_line_index).attribute5    :=
                            lt_order_lines_data (xc_order_idx).attribute5;
                        l_line_tbl (ln_line_index).attribute6    :=
                            lt_order_lines_data (xc_order_idx).attribute6;
                        l_line_tbl (ln_line_index).attribute7    :=
                            lt_order_lines_data (xc_order_idx).attribute7;
                        l_line_tbl (ln_line_index).attribute8    :=
                            lt_order_lines_data (xc_order_idx).attribute8;
                        l_line_tbl (ln_line_index).attribute9    := NULL;
                        l_line_tbl (ln_line_index).attribute10   :=
                            lt_order_lines_data (xc_order_idx).attribute10;
                        l_line_tbl (ln_line_index).attribute11   := NULL;
                        l_line_tbl (ln_line_index).attribute12   :=
                            lt_order_lines_data (xc_order_idx).attribute12;
                        l_line_tbl (ln_line_index).attribute13   := NULL; --lt_order_lines_data(xc_order_idx).attribute13;
                        l_line_tbl (ln_line_index).attribute14   := NULL; --lt_order_lines_data(xc_order_idx).attribute14;
                        --See Conversion Instructions
                        l_line_tbl (ln_line_index).attribute15   := NULL;
                        l_line_tbl (ln_line_index).attribute16   := NULL; --lt_order_lines_data(xc_order_idx).attribute16;
                        l_line_tbl (ln_line_index).attribute17   := NULL; --lt_order_lines_data(xc_order_idx).attribute17;
                        l_line_tbl (ln_line_index).attribute18   := NULL; --lt_order_lines_data(xc_order_idx).attribute18;
                        l_line_tbl (ln_line_index).attribute19   := NULL; --lt_order_lines_data(xc_order_idx).attribute19;
                        l_line_tbl (ln_line_index).attribute20   := NULL; --lt_order_lines_data(xc_order_idx).attribute20;
                    END IF;

                    IF lt_order_lines_data (xc_order_idx).line_category_code =
                       'RETURN'
                    THEN
                        l_line_tbl (ln_line_index).return_reason_code   :=
                            lt_order_lines_data (xc_order_idx).return_reason_code; --'30_DAYS_RETURN';--lt_order_lines_data(xc_order_idx).return_reason_code;
                        --  l_line_tbl(ln_line_index).reference_line_id := lt_order_lines_data(xc_order_idx)
                        --                                                .new_reference_line_id; -- Original order line_id
                        -- l_line_tbl(ln_line_index).reference_header_id := lt_order_lines_data(xc_order_idx)
                        --                                                   .new_reference_header_id; -- Original order header_id
                        l_line_tbl (ln_line_index).return_context   :=
                            lt_order_lines_data (xc_order_idx).return_context; --'ORDER';
                        -- l_line_tbl(ln_line_index).return_attribute1 := lt_order_lines_data(xc_order_idx)
                        --                                                .new_reference_header_id; -- Original order header_id
                        --  l_line_tbl(ln_line_index).return_attribute2 := lt_order_lines_data(xc_order_idx)
                        --                                                 .new_reference_line_id; -- Original order line_id
                        l_line_tbl (ln_line_index).line_category_code   :=
                            lt_order_lines_data (xc_order_idx).line_category_code;
                    ELSE
                        l_line_tbl (ln_line_index).return_reason_code   :=
                            fnd_api.g_miss_char;
                    --   l_line_tbl (ln_line_index).reference_line_id := FND_API.G_MISS_CHAR; -- Original order line_id
                    --      l_line_tbl (ln_line_index).reference_header_id := FND_API.G_MISS_CHAR; -- Original order header_id
                    --      l_line_tbl(ln_line_index).return_context := FND_API.G_MISS_CHAR;
                    --      l_line_tbl (ln_line_index).return_attribute1 :=FND_API.G_MISS_CHAR; -- Original order header_id
                    --     l_line_tbl (ln_line_index).return_attribute2 := FND_API.G_MISS_CHAR;
                    END IF;

                    log_records (
                        gc_debug_flag,
                           'lt_order_lines_data(xc_order_idx).tax_value '
                        || lt_order_lines_data (xc_order_idx).tax_value);
                    l_line_tbl (ln_line_index).tax_code   :=
                        lt_order_lines_data (xc_order_idx).new_tax_code;
                    l_line_tbl (ln_line_index).tax_date   :=
                        lt_order_lines_data (xc_order_idx).tax_date;
                    l_line_tbl (ln_line_index).tax_exempt_flag   :=
                        lt_order_lines_data (xc_order_idx).tax_exempt_flag;
                    l_line_tbl (ln_line_index).tax_exempt_number   :=
                        lt_order_lines_data (xc_order_idx).tax_exempt_number;
                    l_line_tbl (ln_line_index).tax_exempt_reason_code   :=
                        lt_order_lines_data (xc_order_idx).tax_exempt_reason_code;
                    l_line_tbl (ln_line_index).tax_point_code   :=
                        lt_order_lines_data (xc_order_idx).tax_point_code;
                    l_line_tbl (ln_line_index).tax_rate   :=
                        lt_order_lines_data (xc_order_idx).tax_rate;
                    l_line_tbl (ln_line_index).tax_value   :=
                        TO_NUMBER (
                            lt_order_lines_data (xc_order_idx).tax_value);
                    l_line_tbl (ln_line_index).shipment_priority_code   :=
                        lt_order_lines_data (xc_order_idx).shipment_priority_code;

                    --jerry modify 12-may
                    --default shipment priority to null for DC
                    IF UPPER (
                           SUBSTR (
                               lt_order_lines_data (xc_order_idx).shipment_priority_code,
                               1,
                               2)) =
                       'DC'
                    THEN
                        l_line_tbl (ln_line_index).shipment_priority_code   :=
                            '';
                    END IF;

                    IF lt_order_lines_data (xc_order_idx).schedule_ship_date
                           IS NOT NULL
                    THEN
                        l_line_tbl (ln_line_index).schedule_ship_date   :=
                            lt_order_lines_data (xc_order_idx).schedule_ship_date;
                        --Meenakshi 9-Aug
                        l_line_tbl (ln_line_index).override_atp_date_code   :=
                            'Y';
                        l_line_tbl (ln_line_index).schedule_arrival_date   :=
                            lt_order_lines_data (xc_order_idx).schedule_arrival_date;
                    /*Visible Demand Flag Is 'N' Even Though Sales Order Is Booked With Available Scheduled Date When Using Order Import (Doc ID 1569211.1)

                    GOAL
                    To explain why the Visible demand flag may be getting set as 'N' even though the sales order is booked with an available scheduled date
                    when using Order Import for Sales Order creation.

                    SOLUTION
                    It is mandatory to set the Profile OM: Bypass ATP to Yes, for the visible_demand_flag to be populated.

                     If wishing to retain the legacy shipment_date and the visible_demand_flag to be set to 'Y', populate the field '
                     override_atp_date_code' in the table 'oe_lines_iface_all' to 'Y at the time of order import.

                    */
                    --  IF lt_order_lines_data(xc_order_idx).source_type_code <> 'EXTERNAL' OR
                    --        p_customer_type          = 'RMS' THEN
                    --     l_line_tbl(ln_line_index).Override_atp_date_code                  := 'Y';
                    --    l_line_tbl(ln_line_index).tax_code                                := lt_order_lines_data(xc_order_idx).tax_code;
                    --    l_line_tbl(ln_line_index).tax_date                                := lt_order_lines_data(xc_order_idx).tax_date;
                    --    l_line_tbl(ln_line_index).tax_exempt_flag                         := lt_order_lines_data(xc_order_idx).tax_exempt_flag;
                    --    l_line_tbl(ln_line_index).tax_exempt_number                       := lt_order_lines_data(xc_order_idx).tax_exempt_number;
                    --    l_line_tbl(ln_line_index).tax_exempt_reason_code                  := lt_order_lines_data(xc_order_idx).tax_exempt_reason_code;
                    --   l_line_tbl(ln_line_index).tax_point_code                          := lt_order_lines_data(xc_order_idx).tax_point_code;
                    --   l_line_tbl(ln_line_index).tax_rate                                := lt_order_lines_data(xc_order_idx).tax_rate;
                    --   l_line_tbl(ln_line_index).tax_value                               := lt_order_lines_data(xc_order_idx).tax_value;

                    --   ELSE
                    --    l_line_tbl(ln_line_index).drop_ship_flag                          := 'Y';
                    --    END IF;
                    --                l_line_tbl(ln_line_index).visible_demand_flag                     := FND_API.G_MISS_CHAR;
                    ELSE
                        l_line_tbl (ln_line_index).schedule_ship_date   := '';
                    END IF;

                    ---creating line adjustemnts
                    log_records (gc_debug_flag,
                                 'p_header_id  ' || p_header_id);
                    log_records (
                        gc_debug_flag,
                           'l_line_tbl(ln_line_index).line_id '
                        || TO_NUMBER (
                               lt_order_lines_data (xc_order_idx).line_id));

                    OPEN cur_order_lines_adj (
                        TO_NUMBER (
                            lt_order_lines_data (xc_order_idx).line_id));

                    LOOP
                        FETCH cur_order_lines_adj
                            BULK COLLECT INTO lt_lines_adj_data
                            LIMIT 50;

                        EXIT WHEN lt_lines_adj_data.COUNT = 0;

                        IF lt_lines_adj_data.COUNT > 0
                        THEN
                            FOR xc_line_adj_idx IN lt_lines_adj_data.FIRST ..
                                                   lt_lines_adj_data.LAST
                            LOOP
                                log_records (
                                    gc_debug_flag,
                                    'Assigning values in price adj lines+');

                                log_records (
                                    gc_debug_flag,
                                       'new line id '
                                    || lt_lines_adj_data (xc_line_adj_idx).new_list_line_id);
                                log_records (
                                    gc_debug_flag,
                                       'new header id '
                                    || lt_lines_adj_data (xc_line_adj_idx).new_list_header_id);
                                log_records (
                                    gc_debug_flag,
                                       'Operand '
                                    || lt_lines_adj_data (xc_line_adj_idx).operand);
                                log_records (
                                    gc_debug_flag,
                                       'Arithmetic operator '
                                    || lt_lines_adj_data (xc_line_adj_idx).arithmetic_operator);
                                log_records (
                                    gc_debug_flag,
                                       'List type code '
                                    || lt_lines_adj_data (xc_line_adj_idx).list_line_type_code);
                                log_records (
                                    gc_debug_flag,
                                       'List line num '
                                    || lt_lines_adj_data (xc_line_adj_idx).new_list_line_no);

                                ln_line_adj_index   := ln_line_adj_index + 1;
                                l_line_adj_tbl (ln_line_adj_index)   :=
                                    oe_order_pub.g_miss_line_adj_rec;
                                l_line_adj_tbl (ln_line_adj_index).operation   :=
                                    oe_globals.g_opr_create;
                                l_line_adj_tbl (ln_line_adj_index).price_adjustment_id   :=
                                    oe_price_adjustments_s.NEXTVAL;
                                l_line_adj_tbl (ln_line_adj_index).header_id   :=
                                    fnd_api.g_miss_num;
                                ------------------- PASS HEADER ID
                                l_line_adj_tbl (ln_line_adj_index).line_id   :=
                                    fnd_api.g_miss_num;
                                ----------------------- PASS LINE ID
                                l_line_adj_tbl (ln_line_adj_index).line_index   :=
                                    ln_line_index;
                                l_line_adj_tbl (ln_line_adj_index).automatic_flag   :=
                                    'N';
                                --  l_line_adj_tbl(ln_line_adj_index).orig_sys_discount_ref :=  lt_lines_adj_data(xc_line_adj_idx).ORIG_SYS_DISCOUNT_REF;
                                l_line_adj_tbl (ln_line_adj_index).list_header_id   :=
                                    lt_lines_adj_data (xc_line_adj_idx).new_list_header_id; --from validation
                                l_line_adj_tbl (ln_line_adj_index).list_line_id   :=
                                    lt_lines_adj_data (xc_line_adj_idx).new_list_line_id; -- find out how to get this using list line number
                                l_line_adj_tbl (ln_line_adj_index).list_line_type_code   :=
                                    lt_lines_adj_data (xc_line_adj_idx).list_line_type_code;
                                -- l_line_adj_tbl(ln_line_adj_index).update_allowed :='Y';--  lt_lines_adj_data(xc_line_adj_idx).update_allowed;
                                l_line_adj_tbl (ln_line_adj_index).updated_flag   :=
                                    'Y'; -- lt_lines_adj_data(xc_line_adj_idx).updated_flag;
                                l_line_adj_tbl (ln_line_adj_index).applied_flag   :=
                                    'Y'; -- lt_lines_adj_data(xc_line_adj_idx).applied_flag;
                                l_line_adj_tbl (ln_line_adj_index).operand   :=
                                    lt_lines_adj_data (xc_line_adj_idx).operand;
                                l_line_adj_tbl (ln_line_adj_index).arithmetic_operator   :=
                                    lt_lines_adj_data (xc_line_adj_idx).arithmetic_operator;
                                l_line_adj_tbl (ln_line_adj_index).adjusted_amount   :=
                                    lt_lines_adj_data (xc_line_adj_idx).adjusted_amount;
                                --   l_line_adj_tbl(ln_line_adj_index).pricing_phase_id :=  lt_lines_adj_data(xc_line_adj_idx).pricing_phase_id;
                                --  l_line_adj_tbl(ln_line_adj_index).accrual_flag :=  lt_lines_adj_data(xc_line_adj_idx).accrual_flag;
                                --   l_line_adj_tbl(ln_line_adj_index).list_line_no :=  lt_lines_adj_data(xc_line_adj_idx).NEW_LIST_line_no;
                                --   l_line_adj_tbl(ln_line_adj_index).source_system_code := 'QP';
                                --   l_line_adj_tbl(ln_line_adj_index).modifier_level_code :=  lt_lines_adj_data(xc_line_adj_idx).MODIFIER_LEVEL_CODE;
                                --   l_line_adj_tbl(ln_line_adj_index).proration_type_code :=  lt_lines_adj_data(xc_line_adj_idx).proration_type_code ;
                                l_line_adj_tbl (ln_line_adj_index).operand_per_pqty   :=
                                    lt_lines_adj_data (xc_line_adj_idx).operand_per_pqty;
                                l_line_adj_tbl (ln_line_adj_index).adjusted_amount_per_pqty   :=
                                    lt_lines_adj_data (xc_line_adj_idx).adjusted_amount_per_pqty;
                                --   l_line_adj_tbl(ln_line_adj_index).change_reason_code := lt_lines_adj_data(xc_line_adj_idx).CHANGE_REASON_CODE;
                                -- l_line_adj_tbl(ln_line_adj_index).change_reason_text :=  lt_lines_adj_data(xc_line_adj_idx).CHANGE_REASON_text;
                                --added by me
                                l_line_adj_tbl (ln_line_adj_index).charge_type_code   :=
                                    lt_lines_adj_data (xc_line_adj_idx).charge_type_code;

                                l_line_adj_tbl (ln_line_adj_index).attribute1   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute1;
                                l_line_adj_tbl (ln_line_adj_index).attribute10   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute10;
                                l_line_adj_tbl (ln_line_adj_index).attribute11   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute11;
                                l_line_adj_tbl (ln_line_adj_index).attribute12   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute12;
                                l_line_adj_tbl (ln_line_adj_index).attribute13   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute13;
                                l_line_adj_tbl (ln_line_adj_index).attribute14   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute14;
                                l_line_adj_tbl (ln_line_adj_index).attribute15   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute15;
                                l_line_adj_tbl (ln_line_adj_index).attribute2   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute2;
                                l_line_adj_tbl (ln_line_adj_index).attribute3   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute3;
                                l_line_adj_tbl (ln_line_adj_index).attribute4   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute4;
                                l_line_adj_tbl (ln_line_adj_index).attribute5   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute5;
                                l_line_adj_tbl (ln_line_adj_index).attribute6   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute6;
                                l_line_adj_tbl (ln_line_adj_index).attribute7   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute7;
                                l_line_adj_tbl (ln_line_adj_index).attribute8   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute8;
                                l_line_adj_tbl (ln_line_adj_index).attribute9   :=
                                    lt_lines_adj_data (xc_line_adj_idx).attribute9;
                            /*l_line_adj_tbl(ln_line_adj_index).context  :=  lt_lines_adj_data(xc_line_adj_idx).context;
                              l_line_adj_tbl(ln_line_adj_index).modifier_mechanism_type_code  :=  lt_lines_adj_data(xc_line_adj_idx).MODIFIER_MECHANISM_TYPE_CODE;
                                l_line_adj_tbl(ln_line_adj_index).modified_from              :=  lt_lines_adj_data(xc_line_adj_idx).modified_from ;
                                l_line_adj_tbl(ln_line_adj_index).modified_to                  :=  lt_lines_adj_data(xc_line_adj_idx).modified_to ;
                                l_line_adj_tbl(ln_line_adj_index).tax_code        :=  lt_lines_adj_data(xc_line_adj_idx).tax_code;
                                l_line_adj_tbl(ln_line_adj_index).tax_exempt_flag               :=  lt_lines_adj_data(xc_line_adj_idx).tax_exempt_flag;
                                l_line_adj_tbl(ln_line_adj_index).tax_exempt_number             :=  lt_lines_adj_data(xc_line_adj_idx).tax_exempt_number;
                                l_line_adj_tbl(ln_line_adj_index).tax_exempt_reason_code         :=  lt_lines_adj_data(xc_line_adj_idx).tax_exempt_reason_code ;
                               -- l_line_adj_tbl(ln_line_adj_index).invoiced_flag                  :=  lt_lines_adj_data(xc_line_adj_idx).invoiced_flag;
                               -- l_line_adj_tbl(ln_line_adj_index).estimated_flag                 :=  lt_lines_adj_data(xc_line_adj_idx).estimated_flag;
                                --l_line_adj_tbl(ln_line_adj_index).inc_in_sales_performance       :=  lt_lines_adj_data(xc_line_adj_idx).inc_in_sales_performance ;
                               -- l_line_adj_tbl(ln_line_adj_index).split_action_code              :=  lt_lines_adj_data(xc_line_adj_idx).split_action_code;
                              --  l_line_adj_tbl(ln_line_adj_index).charge_type_code              :=  lt_lines_adj_data(xc_line_adj_idx).charge_type_code;
                               -- l_line_adj_tbl(ln_line_adj_index).charge_subtype_code           :=  lt_lines_adj_data(xc_line_adj_idx).charge_subtype_code;
                                l_line_adj_tbl(ln_line_adj_index).source_system_code             :=  lt_lines_adj_data(xc_line_adj_idx).source_system_code;
                               -- l_line_adj_tbl(ln_line_adj_index).benefit_qty                    :=  lt_lines_adj_data(xc_line_adj_idx).benefit_qty;
                               -- l_line_adj_tbl(ln_line_adj_index).benefit_uom_code               :=  lt_lines_adj_data(xc_line_adj_idx).benefit_uom_code ;
                                l_line_adj_tbl(ln_line_adj_index).print_on_invoice_flag          :=  lt_lines_adj_data(xc_line_adj_idx).print_on_invoice_flag ;
                               -- l_line_adj_tbl(ln_line_adj_index).expiration_date                :=  lt_lines_adj_data(xc_line_adj_idx).expiration_date ;
                               -- l_line_adj_tbl(ln_line_adj_index).rebate_transaction_type_code   :=  lt_lines_adj_data(xc_line_adj_idx).rebate_transaction_type_code ;
                               -- l_line_adj_tbl(ln_line_adj_index).rebate_transaction_reference   :=  lt_lines_adj_data(xc_line_adj_idx).rebate_transaction_reference;
                               -- l_line_adj_tbl(ln_line_adj_index).rebate_payment_system_code     :=  lt_lines_adj_data(xc_line_adj_idx).rebate_payment_system_code;
                               -- l_line_adj_tbl(ln_line_adj_index).redeemed_date                  :=  lt_lines_adj_data(xc_line_adj_idx).redeemed_date;
                               -- l_line_adj_tbl(ln_line_adj_index).redeemed_flag                  :=  lt_lines_adj_data(xc_line_adj_idx).redeemed_flag;
                                l_line_adj_tbl(ln_line_adj_index).accrual_flag                 :=  lt_lines_adj_data(xc_line_adj_idx).accrual_flag;
                                l_line_adj_tbl(ln_line_adj_index).range_break_quantity             :=  lt_lines_adj_data(xc_line_adj_idx).range_break_quantity ;
                                l_line_adj_tbl(ln_line_adj_index).accrual_conversion_rate         :=  lt_lines_adj_data(xc_line_adj_idx).accrual_conversion_rate ;
                               -- l_line_adj_tbl(ln_line_adj_index).pricing_group_sequence         :=  lt_lines_adj_data(xc_line_adj_idx).pricing_group_sequence;
                                l_line_adj_tbl(ln_line_adj_index).price_break_type_code         :=  lt_lines_adj_data(xc_line_adj_idx).price_break_type_code;
                                l_line_adj_tbl(ln_line_adj_index).substitution_attribute         :=  lt_lines_adj_data(xc_line_adj_idx).substitution_attribute;
                               -- l_line_adj_tbl(ln_line_adj_index).proration_type_code             :=  lt_lines_adj_data(xc_line_adj_idx).proration_type_code ;
                                l_line_adj_tbl(ln_line_adj_index).credit_or_charge_flag          :=  lt_lines_adj_data(xc_line_adj_idx).credit_or_charge_flag;
                                l_line_adj_tbl(ln_line_adj_index).include_on_returns_flag         :=  lt_lines_adj_data(xc_line_adj_idx).include_on_returns_flag;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute1                   :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute1 ;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute10                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute10;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute11                 :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute11;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute12                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute12;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute13                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute13;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute14                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute14;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute15                 :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute15;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute2                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute2;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute3                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute3;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute4                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute4;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute5                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute5;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute6                 :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute6;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute7                   :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute7;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute8                   :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute8;
                                l_line_adj_tbl(ln_line_adj_index).ac_attribute9                  :=  lt_lines_adj_data(xc_line_adj_idx).ac_attribute9;
                                l_line_adj_tbl(ln_line_adj_index).ac_context                     :=  lt_lines_adj_data(xc_line_adj_idx).ac_context;
                                l_line_adj_tbl(ln_line_adj_index).invoiced_amount                :=  lt_lines_adj_data(xc_line_adj_idx).invoiced_amount;
                            */

                            END LOOP;                           --adj for loop
                        END IF;                                 --if adj count
                    END LOOP;                                   --adj for loop

                    CLOSE cur_order_lines_adj;
                END LOOP;
            END IF;
        END LOOP;

        p_line_tbl           := l_line_tbl;
        p_adj_line_tbl       := l_line_adj_tbl;
        x_closed_line_flag   := l_closed_line_flag;

        CLOSE cur_order_lines;

        x_retrun_status      := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Un-expecetd Error in  create_order_line => ' || SQLERRM);
            --    ROLLBACK;
            x_retrun_status   := 'E';
    END create_order_closed_line;

    PROCEDURE create_order (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_action IN VARCHAR2
                            , p_operating_unit IN VARCHAR2, p_target_org_id IN NUMBER, p_batch_id IN NUMBER)
    AS
        CURSOR cur_order_header IS
            (SELECT *
               FROM xxd_ont_open_so_head_stg_t cust
              WHERE     record_status = p_action
                    AND batch_number = p_batch_id --AND header_id = 40408042 --35981918
                    AND new_org_id = p_target_org_id);

        --
        l_header_rec            oe_order_pub.header_rec_type;
        l_line_tbl              oe_order_pub.line_tbl_type;
        l_line_adj_tbl          oe_order_pub.line_adj_tbl_type;
        l_closed_line_tbl       oe_order_pub.line_tbl_type;
        l_closed_line_adj_tbl   oe_order_pub.line_adj_tbl_type;
        l_action_request_tbl    oe_order_pub.request_tbl_type;
        l_request_rec           oe_order_pub.request_rec_type;
        ln_line_index           NUMBER := 0;
        l_open_line_flag        VARCHAR2 (1);
        l_closed_line_flag      VARCHAR2 (1);

        TYPE lt_order_header_typ IS TABLE OF cur_order_header%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_order_header_data    lt_order_header_typ;

        lx_retrun_status        VARCHAR2 (10) := NULL;
    BEGIN
        log_records (gc_debug_flag, 'Inside create_order +');

        OPEN cur_order_header;

        LOOP
            --      SAVEPOINT INSERT_TABLE2;
            FETCH cur_order_header
                BULK COLLECT INTO lt_order_header_data
                LIMIT 10;

            EXIT WHEN lt_order_header_data.COUNT = 0;
            log_records (
                gc_debug_flag,
                   'Inside create_order lt_order_header_data.COUNT  => '
                || lt_order_header_data.COUNT);

            IF lt_order_header_data.COUNT > 0
            THEN
                FOR xc_order_idx IN lt_order_header_data.FIRST ..
                                    lt_order_header_data.LAST
                LOOP
                    /*****************INITIALIZE HEADER RECORD******************************/
                    l_header_rec                                := oe_order_pub.g_miss_header_rec;
                    /*****************POPULATE REQUIRED ATTRIBUTES **********************************/
                    l_header_rec.operation                      := oe_globals.g_opr_create;
                    l_header_rec.header_id                      := fnd_api.g_miss_num;
                    l_header_rec.order_number                   :=
                        lt_order_header_data (xc_order_idx).order_number;
                    l_header_rec.ordered_date                   :=
                        lt_order_header_data (xc_order_idx).ordered_date;
                    l_header_rec.request_date                   :=
                        lt_order_header_data (xc_order_idx).request_date;
                    l_header_rec.order_source_id                :=
                        lt_order_header_data (xc_order_idx).new_order_source_id;
                    l_header_rec.order_type_id                  :=
                        lt_order_header_data (xc_order_idx).new_order_type_id;
                    l_header_rec.org_id                         :=
                        lt_order_header_data (xc_order_idx).new_org_id;
                    l_header_rec.orig_sys_document_ref          :=
                        lt_order_header_data (xc_order_idx).original_system_reference;
                    --            l_header_rec.ship_to_customer_id                                             := FND_API.G_MISS_NUM;
                    --            l_header_rec.invoice_to_customer_id                                          := FND_API.G_MISS_NUM;
                    l_header_rec.sold_to_contact_id             :=
                        fnd_api.g_miss_num;
                    l_header_rec.invoice_to_contact_id          :=
                        fnd_api.g_miss_num;
                    l_header_rec.ship_to_contact_id             :=
                        fnd_api.g_miss_num;

                    l_header_rec.invoice_to_org_id              :=
                        lt_order_header_data (xc_order_idx).new_bill_to_site_id;
                    l_header_rec.sold_to_org_id                 :=
                        lt_order_header_data (xc_order_idx).new_sold_to_org_id;
                    l_header_rec.ship_to_org_id                 :=
                        lt_order_header_data (xc_order_idx).new_ship_to_site_id;

                    l_header_rec.ship_from_org_id               :=
                        lt_order_header_data (xc_order_idx).new_ship_from_org_id;
                    l_header_rec.sold_from_org_id               :=
                        lt_order_header_data (xc_order_idx).new_sold_from_org_id;

                    l_header_rec.price_list_id                  :=
                        lt_order_header_data (xc_order_idx).new_pricelist_id;
                    --l_header_rec.shipping_method_code := fnd_api.g_miss_char;--jerry modify 11-may
                    --FND_API.G_MISS_CHAR;
                    l_header_rec.fob_point_code                 :=
                        fnd_api.g_miss_char;

                    l_header_rec.shipping_instructions          :=
                        lt_order_header_data (xc_order_idx).shipping_instructions;
                    l_header_rec.packing_instructions           :=
                        lt_order_header_data (xc_order_idx).packing_instructions;

                    --Meenakshi 18-May

                    /* if lt_order_header_data(xc_order_idx).flow_status_code = 'BOOKED' then
                       l_header_rec.flow_status_code := 'BOOKED';
                       l_header_rec.booked_date      := lt_order_header_data(xc_order_idx)
                                                        .ordered_date; --FND_API.G_MISS_DATE;
                       l_header_rec.booked_flag      := 'Y';
                     end if;*/
                    l_header_rec.booked_date                    :=
                        lt_order_header_data (xc_order_idx).booked_date;
                    l_header_rec.booked_flag                    :=
                        fnd_api.g_miss_char;

                    --       l_action_request_tbl (1)              := oe_order_pub.g_miss_request_rec;
                    --   l_action_request_tbl(1).request_type := oe_globals.g_book_order;
                    --            l_action_request_tbl(1).entity_id    := l_header_rec.header_id;
                    --      l_action_request_tbl(1).entity_code  := oe_globals.g_entity_header;
                    ----
                    ----             --This is to apply hold an order header l_request_rec.entity_id := 98258;
                    ----              l_request_rec.entity_code  := oe_globals.g_entity_header;
                    ----              l_request_rec.request_type := oe_globals.g_apply_hold;
                    ----              -- hold_id must be passed
                    ----              l_request_rec.param1    := 1000; -- indicator that it is an order hold
                    ----              l_request_rec.param2    := 'O' ; -- Header ID of the order
                    ----              l_request_rec.param3    := FND_API.G_MISS_NUM;
                    ----              l_action_request_tbl(2) := l_request_rec;
                    --            ELSE
                    --            l_header_rec.flow_status_code                                                := 'ENTERED';
                    --            l_header_rec.booked_date                                                     := FND_API.G_MISS_DATE;
                    --            l_header_rec.booked_flag                                                     := FND_API.G_MISS_CHAR;
                    --            l_action_request_tbl (1)              := oe_order_pub.g_miss_request_rec;
                    --            END IF;
                    l_header_rec.cust_po_number                 :=
                        lt_order_header_data (xc_order_idx).cust_po_number;
                    --            l_header_rec.demand_class_code                                               :=  lt_order_header_data(xc_order_idx).demand_class_code;

                    l_header_rec.salesrep_id                    :=
                        lt_order_header_data (xc_order_idx).new_salesrep_id;
                    l_header_rec.sales_channel_code             :=
                        lt_order_header_data (xc_order_idx).new_sales_channel_code;
                    l_header_rec.payment_term_id                :=
                        lt_order_header_data (xc_order_idx).new_pay_term_id;
                    l_header_rec.shipment_priority_code         :=
                        lt_order_header_data (xc_order_idx).shipment_priority_code;

                    --            l_header_rec.context                                                         := lt_order_header_data(xc_order_idx).context;
                    --l_header_rec.attribute1  := to_char(to_date(lt_order_header_data(xc_order_idx)
                    --       .attribute1,
                    --          'DD-MON-RR'),
                    --      'YYYY/MM/DD'); --2015/01/15 00:00:00
                    l_header_rec.attribute1                     :=
                        TO_CHAR (
                            TO_TIMESTAMP (
                                lt_order_header_data (xc_order_idx).attribute1,
                                'DD-MON-RR'),
                            'YYYY/MM/DD HH24:MI:SS');
                    l_header_rec.attribute2                     := NULL;
                    l_header_rec.attribute3                     :=
                        lt_order_header_data (xc_order_idx).attribute3;
                    l_header_rec.attribute4                     :=
                        lt_order_header_data (xc_order_idx).attribute4;
                    l_header_rec.attribute5                     :=
                        lt_order_header_data (xc_order_idx).attribute5;
                    l_header_rec.attribute6                     :=
                        lt_order_header_data (xc_order_idx).attribute6;
                    l_header_rec.attribute7                     :=
                        lt_order_header_data (xc_order_idx).attribute7;
                    l_header_rec.attribute8                     :=
                        lt_order_header_data (xc_order_idx).attribute8;
                    l_header_rec.attribute9                     := NULL;
                    l_header_rec.attribute10                    :=
                        lt_order_header_data (xc_order_idx).attribute10;
                    l_header_rec.attribute11                    := NULL;
                    --            l_header_rec.attribute12                                                     := lt_order_header_data(xc_order_idx).attribute12;
                    l_header_rec.attribute13                    :=
                        lt_order_header_data (xc_order_idx).attribute13;
                    l_header_rec.attribute14                    :=
                        lt_order_header_data (xc_order_idx).attribute14;
                    --See Conversion Instruction MD50 need to check
                    l_header_rec.attribute15                    := NULL;
                    l_header_rec.attribute16                    := NULL;
                    --            l_header_rec.attribute17                                                     := lt_order_header_data(xc_order_idx).attribute17;
                    --            l_header_rec.attribute18                                                     := lt_order_header_data(xc_order_idx).attribute18;
                    --            l_header_rec.attribute19                                                     := lt_order_header_data(xc_order_idx).attribute19;
                    --            l_header_rec.attribute20                                                     := lt_order_header_data(xc_order_idx).attribute20;

                    l_header_rec.accounting_rule_id             :=
                        fnd_api.g_miss_num;
                    l_header_rec.accounting_rule_duration       :=
                        fnd_api.g_miss_num;
                    l_header_rec.agreement_id                   :=
                        fnd_api.g_miss_num;
                    l_header_rec.cancelled_flag                 :=
                        fnd_api.g_miss_char;
                    l_header_rec.conversion_rate                :=
                        fnd_api.g_miss_num;
                    l_header_rec.conversion_rate_date           :=
                        fnd_api.g_miss_date;
                    l_header_rec.conversion_type_code           :=
                        fnd_api.g_miss_char;
                    l_header_rec.customer_preference_set_code   :=
                        fnd_api.g_miss_char;
                    l_header_rec.created_by                     :=
                        fnd_api.g_miss_num;
                    l_header_rec.creation_date                  :=
                        fnd_api.g_miss_date;
                    l_header_rec.deliver_to_contact_id          :=
                        fnd_api.g_miss_num;
                    l_header_rec.deliver_to_org_id              :=
                        fnd_api.g_miss_num;

                    l_header_rec.earliest_schedule_limit        :=
                        fnd_api.g_miss_num;
                    l_header_rec.expiration_date                :=
                        fnd_api.g_miss_date;
                    l_header_rec.freight_carrier_code           :=
                        fnd_api.g_miss_char;
                    l_header_rec.freight_terms_code             :=
                        lt_order_header_data (xc_order_idx).freight_terms_code;
                    l_header_rec.global_attribute1              :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute10             :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute11             :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute12             :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute13             :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute14             :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute15             :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute16             :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute17             :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute18             :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute19             :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute2              :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute20             :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute3              :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute4              :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute5              :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute6              :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute7              :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute8              :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute9              :=
                        fnd_api.g_miss_char;
                    l_header_rec.global_attribute_category      :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_context                     :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute1                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute2                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute3                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute4                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute5                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute6                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute7                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute8                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute9                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute10                 :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute11                 :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute12                 :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute13                 :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute14                 :=
                        fnd_api.g_miss_char;
                    l_header_rec.tp_attribute15                 :=
                        fnd_api.g_miss_char;
                    l_header_rec.invoicing_rule_id              :=
                        fnd_api.g_miss_num;
                    l_header_rec.last_updated_by                :=
                        fnd_api.g_miss_num;
                    l_header_rec.last_update_date               :=
                        fnd_api.g_miss_date;
                    l_header_rec.last_update_login              :=
                        fnd_api.g_miss_num;
                    l_header_rec.latest_schedule_limit          :=
                        fnd_api.g_miss_num;
                    l_header_rec.open_flag                      :=
                        fnd_api.g_miss_char;
                    l_header_rec.order_category_code            :=
                        fnd_api.g_miss_char;
                    l_header_rec.order_date_type_code           :=
                        fnd_api.g_miss_char;
                    l_header_rec.partial_shipments_allowed      :=
                        fnd_api.g_miss_char;
                    l_header_rec.pricing_date                   :=
                        fnd_api.g_miss_date;
                    l_header_rec.program_application_id         :=
                        fnd_api.g_miss_num;
                    l_header_rec.program_id                     :=
                        fnd_api.g_miss_num;
                    l_header_rec.program_update_date            :=
                        fnd_api.g_miss_date;
                    l_header_rec.request_id                     :=
                        fnd_api.g_miss_num;
                    l_header_rec.return_reason_code             :=
                        fnd_api.g_miss_char;

                    l_header_rec.ship_tolerance_above           :=
                        fnd_api.g_miss_num;
                    l_header_rec.ship_tolerance_below           :=
                        fnd_api.g_miss_num;
                    l_header_rec.sold_to_phone_id               :=
                        fnd_api.g_miss_num;
                    l_header_rec.source_document_id             :=
                        fnd_api.g_miss_num;
                    l_header_rec.source_document_type_id        :=
                        fnd_api.g_miss_num;

                    l_header_rec.tax_exempt_flag                :=
                        fnd_api.g_miss_char;
                    l_header_rec.tax_exempt_number              :=
                        fnd_api.g_miss_char;
                    l_header_rec.tax_exempt_reason_code         :=
                        fnd_api.g_miss_char;
                    l_header_rec.tax_point_code                 :=
                        fnd_api.g_miss_char;

                    l_header_rec.transactional_curr_code        :=
                        fnd_api.g_miss_char;
                    l_header_rec.version_number                 :=
                        fnd_api.g_miss_num;
                    l_header_rec.return_status                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.db_flag                        :=
                        fnd_api.g_miss_char;
                    l_header_rec.first_ack_code                 :=
                        fnd_api.g_miss_char;
                    l_header_rec.first_ack_date                 :=
                        fnd_api.g_miss_date;
                    l_header_rec.last_ack_code                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.last_ack_date                  :=
                        fnd_api.g_miss_date;
                    l_header_rec.change_reason                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.change_comments                :=
                        fnd_api.g_miss_char;
                    l_header_rec.change_sequence                :=
                        fnd_api.g_miss_char;
                    l_header_rec.change_request_code            :=
                        fnd_api.g_miss_char;
                    l_header_rec.ready_flag                     :=
                        fnd_api.g_miss_char;
                    l_header_rec.status_flag                    :=
                        fnd_api.g_miss_char;
                    l_header_rec.force_apply_flag               :=
                        fnd_api.g_miss_char;
                    l_header_rec.drop_ship_flag                 :=
                        fnd_api.g_miss_char;
                    l_header_rec.customer_payment_term_id       :=
                        fnd_api.g_miss_num;
                    l_header_rec.payment_type_code              :=
                        fnd_api.g_miss_char;
                    l_header_rec.payment_amount                 :=
                        fnd_api.g_miss_num;
                    l_header_rec.check_number                   :=
                        fnd_api.g_miss_char;
                    l_header_rec.credit_card_code               :=
                        fnd_api.g_miss_char;
                    l_header_rec.credit_card_holder_name        :=
                        fnd_api.g_miss_char;
                    l_header_rec.credit_card_number             :=
                        fnd_api.g_miss_char;
                    l_header_rec.credit_card_expiration_date    :=
                        fnd_api.g_miss_date;
                    l_header_rec.credit_card_approval_code      :=
                        fnd_api.g_miss_char;
                    l_header_rec.credit_card_approval_date      :=
                        fnd_api.g_miss_date;
                    l_header_rec.marketing_source_code_id       :=
                        fnd_api.g_miss_num;
                    l_header_rec.upgraded_flag                  :=
                        fnd_api.g_miss_char;
                    l_header_rec.deliver_to_customer_id         :=
                        fnd_api.g_miss_num;
                    l_header_rec.blanket_number                 :=
                        fnd_api.g_miss_num;
                    l_header_rec.minisite_id                    :=
                        fnd_api.g_miss_num;
                    l_header_rec.ib_owner                       :=
                        fnd_api.g_miss_char;
                    l_header_rec.ib_installed_at_location       :=
                        fnd_api.g_miss_char;
                    l_header_rec.ib_current_location            :=
                        fnd_api.g_miss_char;
                    l_header_rec.end_customer_id                :=
                        fnd_api.g_miss_num;
                    l_header_rec.end_customer_contact_id        :=
                        fnd_api.g_miss_num;
                    l_header_rec.end_customer_site_use_id       :=
                        fnd_api.g_miss_num;
                    l_header_rec.supplier_signature             :=
                        fnd_api.g_miss_char;
                    l_header_rec.supplier_signature_date        :=
                        fnd_api.g_miss_date;
                    l_header_rec.customer_signature             :=
                        fnd_api.g_miss_char;
                    l_header_rec.customer_signature_date        :=
                        fnd_api.g_miss_date;
                    l_header_rec.shipping_method_code           :=
                        lt_order_header_data (xc_order_idx).new_ship_method_code;

                    lx_retrun_status                            := 'S';

                    create_order_line (
                        x_errbuf           => x_errbuf,
                        x_retcode          => x_retcode,
                        p_action           => p_action,
                        p_header_id        =>
                            lt_order_header_data (xc_order_idx).header_id,
                        p_customer_type    =>
                            lt_order_header_data (xc_order_idx).customer_type,
                        p_line_tbl         => l_line_tbl,
                        p_adj_line_tbl     => l_line_adj_tbl,
                        x_retrun_status    => lx_retrun_status,
                        x_open_line_flag   => l_open_line_flag);

                    create_order_closed_line (
                        x_errbuf             => x_errbuf,
                        x_retcode            => x_retcode,
                        p_action             => p_action,
                        p_header_id          =>
                            lt_order_header_data (xc_order_idx).header_id,
                        p_customer_type      =>
                            lt_order_header_data (xc_order_idx).customer_type,
                        p_line_tbl           => l_closed_line_tbl,
                        p_adj_line_tbl       => l_closed_line_adj_tbl,
                        x_retrun_status      => lx_retrun_status,
                        x_closed_line_flag   => l_closed_line_flag);

                    create_order (
                        p_header_rec                  => l_header_rec,
                        p_line_tbl                    => l_line_tbl,
                        p_price_adj_line_tbl          => l_line_adj_tbl,
                        p_closed_line_tbl             => l_closed_line_tbl,
                        p_price_adj_closed_line_tbl   => l_closed_line_adj_tbl,
                        p_action_request_tbl          => l_action_request_tbl,
                        p_open_line_flag              => l_open_line_flag,
                        p_closed_line_flag            => l_closed_line_flag);
                END LOOP;
            END IF;
        END LOOP;

        CLOSE cur_order_header;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Un-expecetd Error in  create_order => ' || SQLERRM);
            ROLLBACK;
    END create_order;

    /****************************************************************************************
    *  Procedure Name :   pricelist_validation                                              *
    *                                                                                       *
    *  Description    :   Procedure to validate the Price lists in the stag                 *
    *                                                                                       *
    *                                                                                       *
    *  Called From    :   Concurrent Program                                                *
    *                                                                                       *
    *  Parameters             Type       Description                                        *
    *  -----------------------------------------------------------------------------        *
    *  errbuf                  OUT       Standard errbuf                                    *
    *  retcode                 OUT       Standard retcode                                   *
    *  p_batch_id               IN       Batch Number to fetch the data from header stage   *
    *  p_action                 IN       Action (VALIDATE OR PROCESSED)                     *
    *                                                                                       *
    * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
    *                                                                                       *
     *****************************************************************************************/

    PROCEDURE sales_order_validation (errbuf               OUT VARCHAR2,
                                      retcode              OUT VARCHAR2,
                                      p_action          IN     VARCHAR2,
                                      p_customer_type   IN     VARCHAR2,
                                      p_batch_number    IN     NUMBER)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lt_oe_header_data            xxd_ont_order_header_tab;
        lt_oe_lines_data             xxd_ont_order_lines_tab;
        lt_oe_price_adj_lines_data   xxd_ont_prc_adj_lines_tab;
        lc_status                    VARCHAR2 (20);

        CURSOR cur_oe_header (p_batch_number NUMBER)
        IS
            SELECT *
              FROM xxd_ont_open_so_head_stg_t
             WHERE     record_status IN (gc_new_status, gc_error_status)
                   AND batch_number = p_batch_number;

        --          AND header_id = 40371209;

        CURSOR cur_oe_lines (p_header_id NUMBER)
        IS
            SELECT *
              FROM xxd_ont_open_so_lines_stg_t
             WHERE header_id = p_header_id;

        CURSOR cur_oe_price_adj_lines (p_header_id NUMBER)
        IS
            SELECT *
              FROM xxd_ont_open_price_adj_l_stg_t
             WHERE header_id = p_header_id;

        lc_oe_header_valid_data      VARCHAR2 (1) := gc_yes_flag;
        lc_oe_line_valid_data        VARCHAR2 (1) := gc_yes_flag;
        ln_count                     NUMBER := 0;
        l_exists                     VARCHAR2 (10) := gc_no_flag;
        lc_error_message             VARCHAR2 (2000);
        lx_return_status             VARCHAR2 (10);

        ln_new_customer_id           NUMBER := NULL;
        ln_new_sold_to_org_id        NUMBER := NULL;
        ln_new_ship_to_site_id       NUMBER := NULL;
        ln_new_bill_to_site_id       NUMBER := NULL;
        ln_ship_from_org_id          NUMBER := NULL;
        ln_new_org_id                NUMBER := NULL;
        ln_new_pay_term_id           NUMBER := NULL;
        ln_new_salesrep_id           NUMBER := NULL;
        ln_new_pricelist_id          NUMBER := NULL;
        ln_new_source_id             NUMBER := NULL;
        ln_new_order_type_id         NUMBER := NULL;
        ln_new_line_type_id          NUMBER := NULL;
        ln_inventory_item_id         NUMBER := NULL;
        ln_line_ship_from_org_id     NUMBER := NULL;
        ln_line_ship_to_site_id      NUMBER := NULL;
        lc_new_sales_channel_code    VARCHAR2 (50) := NULL;

        ln_new_ship_method_line      VARCHAR2 (240) := NULL;
        ln_new_ship_method           VARCHAR2 (240) := NULL;
        ln_new_list_l_id             NUMBER;
        ln_new_list_h_id             NUMBER;
        ln_list_line_no              VARCHAR2 (240);
        ln_new_ret_header_id         NUMBER;
        ln_new_ret_line_id           NUMBER;

        ln_ship_method_header        NUMBER;
        ln_ship_method_line          NUMBER;

        l_new_line_num               NUMBER;
        l_duplicate_num              NUMBER;

        l_1206_tax_code              VARCHAR2 (250);
        l_1206_tax_rate              NUMBER;
        l_content_owner_id           NUMBER;
        l_new_rate_code              VARCHAR2 (100);
        l_new_attribute4             NUMBER;
        ln_tax_rate_exists           NUMBER;
        ln_rate_exists               NUMBER;
        l_1206_tax_code1             VARCHAR2 (100);
    BEGIN
        retcode   := NULL;
        errbuf    := NULL;
        log_records (gc_debug_flag, 'In Validate procedure ');

        OPEN cur_oe_header (p_batch_number => p_batch_number);

        LOOP
            FETCH cur_oe_header BULK COLLECT INTO lt_oe_header_data LIMIT 10;

            EXIT WHEN lt_oe_header_data.COUNT = 0;

            log_records (gc_debug_flag,
                         'validate Order header ' || lt_oe_header_data.COUNT);

            IF lt_oe_header_data.COUNT > 0
            THEN
                FOR xc_header_idx IN lt_oe_header_data.FIRST ..
                                     lt_oe_header_data.LAST
                LOOP
                    lc_oe_header_valid_data     := gc_yes_flag;
                    lc_oe_line_valid_data       := gc_yes_flag;
                    lc_error_message            := NULL;
                    ln_new_customer_id          := NULL;
                    ln_new_sold_to_org_id       := NULL;
                    ln_new_ship_to_site_id      := NULL;
                    ln_new_bill_to_site_id      := NULL;
                    ln_ship_from_org_id         := NULL;
                    ln_new_pay_term_id          := NULL;
                    ln_new_salesrep_id          := NULL;
                    ln_new_pricelist_id         := NULL;
                    ln_new_source_id            := NULL;
                    ln_new_order_type_id        := NULL;
                    lc_new_sales_channel_code   := NULL;

                    IF p_customer_type = 'eComm' OR p_customer_type = 'RMS'
                    THEN
                        -- Validate           CUSTOMER_ID
                        BEGIN
                            SELECT cust_account_id
                              INTO ln_new_sold_to_org_id
                              FROM hz_cust_accounts_all
                             WHERE cust_account_id =
                                   lt_oe_header_data (xc_header_idx).customer_id;
                        --                  AND ATTRIBUTE18 IS NOT NULL;

                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'Customer '
                                    || lt_oe_header_data (xc_header_idx).customer_id
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'CUSTOMER_ID',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).customer_id);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'Customer '
                                    || lt_oe_header_data (xc_header_idx).customer_id
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'CUSTOMER_ID',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).customer_id);
                        END;

                        --            BILL_TO_ORG_ID
                        BEGIN
                            SELECT site_use_id
                              INTO ln_new_bill_to_site_id
                              FROM hz_cust_site_uses_all
                             WHERE     orig_system_reference =
                                       TO_CHAR (
                                           lt_oe_header_data (xc_header_idx).bill_to_org_id) --jerry modify 11-may
                                   AND site_use_code = 'BILL_TO'
                                   AND status = 'A';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'Customer Bill to '
                                    || lt_oe_header_data (xc_header_idx).bill_to_org_id
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'BILL_TO_ORG_ID',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).bill_to_org_id);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'Customer Bill to '
                                    || lt_oe_header_data (xc_header_idx).bill_to_org_id
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'BILL_TO_ORG_ID',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).bill_to_org_id);
                        END;
                    ELSIF p_customer_type = 'Wholesale'
                    THEN
                        BEGIN
                            SELECT hcsu.site_use_id, hca.cust_account_id
                              INTO ln_new_bill_to_site_id, ln_new_sold_to_org_id
                              FROM hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcas, hz_cust_acct_relate_all hcar,
                                   hz_cust_accounts_all hca
                             WHERE     hcsu.cust_acct_site_id =
                                       hcas.cust_acct_site_id
                                   AND hcas.cust_account_id =
                                       hcar.cust_account_id
                                   AND hcas.cust_account_id =
                                       hca.cust_account_id
                                   AND related_cust_account_id =
                                       lt_oe_header_data (xc_header_idx).customer_id --legacy Customer_account
                                   AND site_use_code = 'BILL_TO'
                                   --       AND hcsu.PRIMARY_FLAG = 'Y'
                                   AND hca.attribute1 =
                                       lt_oe_header_data (xc_header_idx).attribute5;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'Customer '
                                    || lt_oe_header_data (xc_header_idx).customer_id
                                    || ' attribute5 '
                                    || lt_oe_header_data (xc_header_idx).attribute5
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'CUSTOMER_ID',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).customer_id,
                                    p_more_info4   =>
                                        lt_oe_header_data (xc_header_idx).attribute5);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'Customer '
                                    || lt_oe_header_data (xc_header_idx).customer_id
                                    || ' attribute5 '
                                    || lt_oe_header_data (xc_header_idx).attribute5
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'CUSTOMER_ID',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).customer_id,
                                    p_more_info4   =>
                                        lt_oe_header_data (xc_header_idx).attribute5);
                        END;
                    END IF;

                    --            SHIP_TO_ORG_ID

                    BEGIN
                        SELECT site_use_id
                          INTO ln_new_ship_to_site_id
                          FROM hz_cust_site_uses_all
                         WHERE     orig_system_reference =
                                   TO_CHAR (
                                       lt_oe_header_data (xc_header_idx).ship_to_org_id) --jerry modify 11-may
                               AND site_use_code = 'SHIP_TO'
                               AND status = 'A';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_oe_header_valid_data   := gc_no_flag;
                            fnd_file.put_line (fnd_file.LOG,
                                               lc_error_message);      --jerry
                            lc_error_message          :=
                                   'Customer Ship to '
                                || lt_oe_header_data (xc_header_idx).ship_to_org_id
                                || ' is not available in the System';
                            xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Ecomm Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'SHIP_TO_ORG_ID',
                                p_more_info3   =>
                                    lt_oe_header_data (xc_header_idx).ship_to_org_id);
                        WHEN OTHERS
                        THEN
                            lc_oe_header_valid_data   := gc_no_flag;
                            fnd_file.put_line (fnd_file.LOG,
                                               lc_error_message);      --jerry
                            lc_error_message          :=
                                   'Customer Ship to '
                                || lt_oe_header_data (xc_header_idx).ship_to_org_id
                                || ' is not available in the System';
                            xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Ecomm Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'SHIP_TO_ORG_ID',
                                p_more_info3   =>
                                    lt_oe_header_data (xc_header_idx).ship_to_org_id);
                    END;

                    --            SHIP_FROM_ORG_ID
                    IF     lt_oe_header_data (xc_header_idx).ship_from_org_id
                               IS NOT NULL
                       AND lt_oe_header_data (xc_header_idx).ship_from_org_id <>
                           612
                    THEN
                        ln_ship_from_org_id   :=
                            get_new_inv_org_id (
                                p_old_org_id   =>
                                    lt_oe_header_data (xc_header_idx).ship_from_org_id);

                        IF ln_ship_from_org_id IS NULL
                        THEN
                            lc_oe_header_valid_data   := gc_no_flag;
                            lc_error_message          :=
                                   'No Ship From Organization '
                                || lt_oe_header_data (xc_header_idx).ship_from_org_id
                                || ' is not available in the System';
                            fnd_file.put_line (fnd_file.LOG,
                                               lc_error_message);      --jerry
                            xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Ecomm Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'SHIP_FROM_ORG_ID',
                                p_more_info3   =>
                                    lt_oe_header_data (xc_header_idx).ship_from_org_id);
                        END IF;
                    ELSIF lt_oe_header_data (xc_header_idx).ship_from_org_id =
                          612
                    THEN
                        ln_ship_from_org_id   := 109;
                    END IF;

                    --           ORG_ID
                    IF lt_oe_header_data (xc_header_idx).org_id IS NOT NULL
                    THEN
                        ln_new_org_id   :=
                            get_org_id (
                                p_1206_org_id   =>
                                    lt_oe_header_data (xc_header_idx).org_id);

                        IF ln_new_org_id IS NULL
                        THEN
                            lc_oe_header_valid_data   := gc_no_flag;
                            lc_error_message          :=
                                   'No operating Unit '
                                || lt_oe_header_data (xc_header_idx).org_id
                                || ' is not available in the System';
                            fnd_file.put_line (fnd_file.LOG,
                                               lc_error_message);      --jerry
                            xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Ecomm Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'ORG_ID',
                                p_more_info3   =>
                                    lt_oe_header_data (xc_header_idx).org_id);
                        END IF;
                    END IF;

                    --SALES_CHANNEL_CODE
                    --jerry modify
                    --SALES_CHANNEL_CODE
                    IF p_customer_type = 'eComm'
                    THEN
                        lc_new_sales_channel_code   := 'E-COMMERCE';
                    /*BEGIN
                        SELECT lookup_code
                        INTO   lc_new_sales_channel_code
                        FROM   oe_lookups
                        WHERE  lookup_type = 'SALES_CHANNEL'
                        AND    SYSDATE BETWEEN
                               nvl(start_date_active, SYSDATE) AND
                               nvl(end_date_active, SYSDATE)
                        AND    enabled_flag = 'Y'
                        AND    lookup_code = 'E-COMMERCE';
                    EXCEPTION
                        WHEN no_data_found THEN
                            lc_oe_header_valid_data := gc_no_flag;
                            lc_error_message        := 'SALES_CHANNEL E-COMMERCE is not available in the System';
                            fnd_file.put_line(fnd_file.log,
                                              lc_error_message);
                            xxd_common_utils.record_error(p_module     => 'ONT',
                                                          p_org_id     => gn_org_id,
                                                          p_program    => 'Deckers Ecomm Closed Sales Order Conversion Program',
                                                          p_error_line => SQLCODE,
                                                          p_error_msg  => lc_error_message,
                                                          p_created_by => gn_user_id,
                                                          p_request_id => gn_conc_request_id,
                                                          p_more_info1 => lt_oe_header_data(xc_header_idx)
                                                                          .order_number,
                                                          p_more_info2 => 'SALES_CHANNEL_CODE',
                                                          p_more_info3 => lt_oe_header_data(xc_header_idx)
                                                                          .sales_channel_code);
                        WHEN OTHERS THEN
                            lc_oe_header_valid_data := gc_no_flag;
                            lc_error_message        := 'SALES_CHANNEL E-COMMERCE is not available in the System';
                            fnd_file.put_line(fnd_file.log,
                                              lc_error_message);
                            xxd_common_utils.record_error(p_module     => 'ONT',
                                                          p_org_id     => gn_org_id,
                                                          p_program    => 'Deckers Ecomm Closed Sales Order Conversion Program',
                                                          p_error_line => SQLCODE,
                                                          p_error_msg  => lc_error_message,
                                                          p_created_by => gn_user_id,
                                                          p_request_id => gn_conc_request_id,
                                                          p_more_info1 => lt_oe_header_data(xc_header_idx)
                                                                          .order_number,
                                                          p_more_info2 => 'SALES_CHANNEL_CODE',
                                                          p_more_info3 => lt_oe_header_data(xc_header_idx)
                                                                          .sales_channel_code);
                    END;*/
                    END IF;

                    /* IF lt_oe_header_data (xc_header_idx).SALES_CHANNEL_CODE
                          IS NOT NULL
                    THEN
                       BEGIN
                          SELECT LOOKUP_CODE
                            INTO lc_new_sales_channel_code
                            FROM XXD_1206_SALES_CHANNEL_MAP_T xsc, oe_lookups oel
                           WHERE     xsc.NEW_SALES_CHANNEL_CODE = LOOKUP_CODE
                                 AND OLD_SALES_CHANNEL_CODE =
                                        lt_oe_header_data (xc_header_idx).SALES_CHANNEL_CODE
                                 AND lookup_type = 'SALES_CHANNEL';
                       EXCEPTION
                          WHEN NO_DATA_FOUND
                          THEN
                             lc_oe_header_valid_data := gc_no_flag;
                             lc_error_message :=
                                'SALES_CHANNEL is not available in the System';
                             xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'SALES_CHANNEL_CODE',
                                p_more_info3   => lt_oe_header_data (xc_header_idx).SALES_CHANNEL_CODE);
                          WHEN OTHERS
                          THEN
                             lc_oe_header_valid_data := gc_no_flag;
                             lc_error_message :=
                                'SALES_CHANNEL is not available in the System';
                             xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'SALES_CHANNEL_CODE',
                                p_more_info3   => lt_oe_header_data (xc_header_idx).SALES_CHANNEL_CODE);
                       END;
                    END IF;*/

                    --            PAYMENT_TERM_NAME
                    IF lt_oe_header_data (xc_header_idx).payment_term_name
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT rt.term_id
                              INTO ln_new_pay_term_id
                              FROM ra_terms rt, xxd_1206_payment_term_map_t xrt
                             WHERE     rt.name = xrt.new_term_name
                                   AND old_term_name =
                                       lt_oe_header_data (xc_header_idx).payment_term_name;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'PAYMENT_TERM_NAME '
                                    || lt_oe_header_data (xc_header_idx).payment_term_name
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'PAYMENT_TERM_NAME',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).payment_term_name);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'PAYMENT_TERM_NAME '
                                    || lt_oe_header_data (xc_header_idx).payment_term_name
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'PAYMENT_TERM_NAME',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).payment_term_name);
                        END;
                    END IF;

                    --            SALES_REPNAME
                    IF lt_oe_header_data (xc_header_idx).sales_repname
                           IS NOT NULL
                    THEN
                        BEGIN
                            /*select salesrep_id
                              into ln_new_salesrep_id
                              from ra_salesreps --ra_salesreps_all
                             where name = lt_oe_header_data(xc_header_idx).sales_repname
                               and org_id = ln_new_org_id;*/
                            SELECT rs.salesrep_id
                              INTO ln_new_salesrep_id
                              FROM apps.jtf_rs_salesreps rs, apps.jtf_rs_resource_extns_vl res, apps.hr_organization_units hou,
                                   apps.jtf_rs_defresources_v jrd
                             WHERE     hou.organization_id = rs.org_id
                                   AND rs.resource_id = res.resource_id
                                   AND org_id = ln_new_org_id
                                   AND jrd.resource_name =
                                       lt_oe_header_data (xc_header_idx).sales_repname
                                   AND rs.resource_id = jrd.resource_id
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   rs.start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   rs.end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                   AND rs.status = 'A';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                BEGIN
                                    /*select salesrep_id
                                      into ln_new_salesrep_id
                                      from ra_salesreps
                                     where name = 'CONV_REP' --salesrep_number = '11179'
                                       and org_id = ln_new_org_id;*/
                                    SELECT rs.salesrep_id
                                      INTO ln_new_salesrep_id
                                      FROM apps.jtf_rs_salesreps rs, apps.jtf_rs_resource_extns_vl res, hr_organization_units hou
                                     WHERE     hou.organization_id =
                                               rs.org_id
                                           AND rs.resource_id =
                                               res.resource_id
                                           -- and rs.salesrep_number = to_char('10648')
                                           AND rs.salesrep_number =
                                               (SELECT DESCRIPTION
                                                  FROM apps.fnd_lookup_values
                                                 WHERE     lookup_type =
                                                           'XXD_SO_CONV_SALES_REP' --'XXD_1206_OU_MAPPING'
                                                       AND MEANING =
                                                           'SALES REP NUMBER'
                                                       AND language = 'US')
                                           AND org_id = ln_new_org_id;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                        lc_error_message   :=
                                               'SALES_REPNAME CONV_REP for org id '
                                            || ln_new_org_id
                                            || ' is not available in the System';
                                        fnd_file.put_line (fnd_file.LOG,
                                                           lc_error_message); --jerry
                                        xxd_common_utils.record_error (
                                            p_module       => 'ONT',
                                            p_org_id       => gn_org_id,
                                            p_program      =>
                                                'Deckers Open Sales Order Conversion Program',
                                            p_error_line   => SQLCODE,
                                            p_error_msg    => lc_error_message,
                                            p_created_by   => gn_user_id,
                                            p_request_id   =>
                                                gn_conc_request_id,
                                            p_more_info1   =>
                                                lt_oe_header_data (
                                                    xc_header_idx).order_number,
                                            p_more_info2   => 'SALES_REPNAME',
                                            p_more_info3   =>
                                                lt_oe_header_data (
                                                    xc_header_idx).sales_repname);
                                END;
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'SALES_REPNAME CONV_REP for org id '
                                    || ln_new_org_id
                                    || ' is not available in the System '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Closed Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'SALES_REPNAME',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).sales_repname);
                        END;
                    ELSE
                        BEGIN
                            /*select salesrep_id
                              into ln_new_salesrep_id
                              from ra_salesreps
                             where name = 'CONV_REP' --salesrep_number = '11179'
                               and org_id = ln_new_org_id;*/
                            SELECT rs.salesrep_id
                              INTO ln_new_salesrep_id
                              FROM apps.jtf_rs_salesreps rs, apps.jtf_rs_resource_extns_vl res, hr_organization_units hou
                             WHERE     hou.organization_id = rs.org_id
                                   AND rs.resource_id = res.resource_id
                                   --  and rs.salesrep_number = to_char('10648')
                                   AND rs.salesrep_number =
                                       (SELECT DESCRIPTION
                                          FROM apps.fnd_lookup_values
                                         WHERE     lookup_type =
                                                   'XXD_SO_CONV_SALES_REP' --'XXD_1206_OU_MAPPING'
                                               AND MEANING =
                                                   'SALES REP NUMBER'
                                               AND language = 'US')
                                   AND org_id = ln_new_org_id;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'SALES_REPNAME CONV_REP for org id '
                                    || ln_new_org_id
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Closed Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'SALES_REPNAME',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).sales_repname);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'SALES_REPNAME CONV_REP for org id '
                                    || ln_new_org_id
                                    || ' is not available in the System '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Closed Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'SALES_REPNAME',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).sales_repname);
                        END;
                    END IF;

                    /*  IF lt_oe_header_data (xc_header_idx).SALES_REPNAME IS NOT NULL
                    THEN
                       BEGIN
                          SELECT salesrep_id
                            INTO ln_new_salesrep_id
                            FROM ra_salesreps_all
                           WHERE     NAME =
                                        lt_oe_header_data (xc_header_idx).SALES_REPNAME
                                 AND org_id = ln_new_org_id;
                       EXCEPTION
                          WHEN NO_DATA_FOUND
                          THEN
                             BEGIN
                                SELECT salesrep_id
                                  INTO ln_new_salesrep_id
                                  FROM ra_salesreps_all
                                 WHERE     SALESREP_NUMBER = '11179'
                                       AND org_id = ln_new_org_id;
                             EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                   lc_oe_header_valid_data := gc_no_flag;
                                   lc_error_message :=
                                      'SALES_REPNAME is not available in the System';
                                   xxd_common_utils.record_error (
                                      p_module       => 'ONT',
                                      p_org_id       => gn_org_id,
                                      p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                      p_error_line   => SQLCODE,
                                      p_error_msg    => lc_error_message,
                                      p_created_by   => gn_user_id,
                                      p_request_id   => gn_conc_request_id,
                                      p_more_info1   => lt_oe_header_data (
                                                          xc_header_idx).order_number,
                                      p_more_info2   => 'SALES_REPNAME',
                                      p_more_info3   => lt_oe_header_data (
                                                          xc_header_idx).SALES_REPNAME);
                             END;
                          WHEN OTHERS
                          THEN
                             lc_oe_header_valid_data := gc_no_flag;
                             lc_error_message :=
                                'SALES_REPNAME is not available in the System';
                             xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'SALES_REPNAME',
                                p_more_info3   => lt_oe_header_data (xc_header_idx).SALES_REPNAME);
                       END;
                    ELSE
                       BEGIN
                          SELECT salesrep_id
                            INTO ln_new_salesrep_id
                            FROM ra_salesreps_all
                           WHERE     SALESREP_NUMBER = '11179'
                                 AND org_id = ln_new_org_id;
                       EXCEPTION
                          WHEN NO_DATA_FOUND
                          THEN
                             lc_oe_header_valid_data := gc_no_flag;
                             lc_error_message :=
                                'SALES_REPNAME is not available in the System';
                             xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'SALES_REPNAME',
                                p_more_info3   => lt_oe_header_data (xc_header_idx).SALES_REPNAME);
                          WHEN OTHERS
                          THEN
                             lc_oe_header_valid_data := gc_no_flag;
                             lc_error_message :=
                                'SALES_REPNAME is not available in the System';
                             xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'SALES_REPNAME',
                                p_more_info3   => lt_oe_header_data (xc_header_idx).SALES_REPNAME);
                       END;
                    END IF;*/

                    --            PRICE_LIST
                    IF lt_oe_header_data (xc_header_idx).price_list
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT qph.list_header_id
                              INTO ln_new_pricelist_id
                              FROM xxd_conv.xxd_1206_so_price_list_map_t xqph, qp_list_headers qph
                             WHERE     xqph.pricelist_new_name = qph.name
                                   AND legacy_pricelist_name =
                                       lt_oe_header_data (xc_header_idx).price_list;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'PRICE_LIST '
                                    || lt_oe_header_data (xc_header_idx).price_list
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'PRICE_LIST',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).price_list);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'PRICE_LIST '
                                    || lt_oe_header_data (xc_header_idx).price_list
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'PRICE_LIST',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).price_list);
                        END;
                    END IF;

                    --            ORDER_SOURCE
                    IF lt_oe_header_data (xc_header_idx).order_source
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT order_source_id
                              INTO ln_new_source_id
                              FROM oe_order_sources
                             WHERE name =
                                   lt_oe_header_data (xc_header_idx).order_source;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                    'ORDER_SOURCE is not available in the System';
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'ORDER_SOURCE',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).order_source);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                    'ORDER_SOURCE is not available in the System';
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'ORDER_SOURCE',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).order_source);
                        END;
                    END IF;

                    --RE-ORDER SPRING
                    --            ORDER_TYPE
                    IF     lt_oe_header_data (xc_header_idx).order_type
                               IS NOT NULL
                       AND lt_oe_header_data (xc_header_idx).order_type <>
                           'UK eComm'                    --jerry modify 12-may
                    THEN
                        BEGIN
                            IF     lt_oe_header_data (xc_header_idx).attribute2 IN
                                       ('PRE-SEASON FALL', 'PRE-SEASON SPRING')
                               AND lt_oe_header_data (xc_header_idx).customer_type IN
                                       ('ECOMM', 'RMS')
                            THEN
                                SELECT transaction_type_id
                                  INTO ln_new_order_type_id
                                  FROM oe_transaction_types_tl ott, xxd_1206_order_type_map_t xtt
                                 WHERE     ott.name = xtt.new_12_2_3_name
                                       AND legacy_12_0_6_name =
                                           lt_oe_header_data (xc_header_idx).order_type
                                       AND UPPER (ott.name) LIKE
                                               '%PRE-SEASON%'
                                       AND language = 'US';
                            ELSIF     lt_oe_header_data (xc_header_idx).attribute2 IN
                                          ('RE-ORDER FALL', 'RE-ORDER SPRING')
                                  AND lt_oe_header_data (xc_header_idx).customer_type IN
                                          ('RMS')
                            THEN
                                SELECT transaction_type_id
                                  INTO ln_new_order_type_id
                                  FROM oe_transaction_types_tl ott, xxd_1206_order_type_map_t xtt
                                 WHERE     ott.name = xtt.new_12_2_3_name
                                       AND legacy_12_0_6_name =
                                           lt_oe_header_data (xc_header_idx).order_type
                                       AND UPPER (ott.name) LIKE '%RE-ORDER%'
                                       AND language = 'US';
                            ELSIF     lt_oe_header_data (xc_header_idx).attribute2 =
                                      'CLOSE-OUT'
                                  AND lt_oe_header_data (xc_header_idx).customer_type IN
                                          ('ECOMM', 'RMS')
                            THEN
                                SELECT transaction_type_id
                                  INTO ln_new_order_type_id
                                  FROM oe_transaction_types_tl ott, xxd_1206_order_type_map_t xtt
                                 WHERE     ott.name = xtt.new_12_2_3_name
                                       AND legacy_12_0_6_name =
                                           lt_oe_header_data (xc_header_idx).order_type
                                       AND UPPER (ott.name) LIKE
                                               '%CLOSE-OUT%'
                                       AND language = 'US';
                            ELSE
                                SELECT transaction_type_id
                                  INTO ln_new_order_type_id
                                  FROM oe_transaction_types_tl ott, xxd_1206_order_type_map_t xtt
                                 WHERE     ott.name = xtt.new_12_2_3_name
                                       AND legacy_12_0_6_name =
                                           lt_oe_header_data (xc_header_idx).order_type
                                       AND language = 'US';
                            END IF;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'ORDER_TYPE '
                                    || lt_oe_header_data (xc_header_idx).order_type
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'ORDER_TYPE',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).order_type);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'ORDER_TYPE '
                                    || lt_oe_header_data (xc_header_idx).order_type
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'ORDER_TYPE',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).order_type);
                        END;
                    --jerry modify 12-may
                    --combile order type with demand_class_code for UK eComm
                    ELSIF lt_oe_header_data (xc_header_idx).order_type =
                          'UK eComm'
                    THEN
                        BEGIN
                            SELECT transaction_type_id
                              INTO ln_new_order_type_id
                              FROM oe_transaction_types_tl ott
                             WHERE     ott.name =
                                          lt_oe_header_data (xc_header_idx).order_type
                                       || ' '
                                       || lt_oe_header_data (xc_header_idx).demand_class_code
                                   AND language = 'US';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'ORDER_TYPE '
                                    || lt_oe_header_data (xc_header_idx).order_type
                                    || ' '
                                    || lt_oe_header_data (xc_header_idx).demand_class_code
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'ORDER_TYPE',
                                    p_more_info3   =>
                                           lt_oe_header_data (xc_header_idx).order_type
                                        || ' '
                                        || lt_oe_header_data (xc_header_idx).demand_class_code);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'ORDER_TYPE '
                                    || lt_oe_header_data (xc_header_idx).order_type
                                    || ' '
                                    || lt_oe_header_data (xc_header_idx).demand_class_code
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);  --jerry
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Ecomm Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'ORDER_TYPE',
                                    p_more_info3   =>
                                           lt_oe_header_data (xc_header_idx).order_type
                                        || ' '
                                        || lt_oe_header_data (xc_header_idx).demand_class_code);
                        END;
                    END IF;

                    --- Ship method validation code
                    BEGIN
                        SELECT new_ship_method_code
                          INTO ln_new_ship_method
                          FROM xxd_1206_ship_methods_map_t
                         WHERE old_ship_method_code =
                               lt_oe_header_data (xc_header_idx).shipping_method_code;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            --jerry modify
                            /*lc_oe_header_valid_data := gc_no_flag;
                            lc_error_message        := 'SHIPMETHOD ' || lt_oe_header_data(xc_header_idx)
                                                      .shipping_method_code ||
                                                       ' is not available in the System';
                            xxd_common_utils.record_error(p_module     => 'ONT',
                                                          p_org_id     => gn_org_id,
                                                          p_program    => 'Deckers Ecomm Closed Sales Order Conversion Program',
                                                          p_error_line => SQLCODE,
                                                          p_error_msg  => lc_error_message,
                                                          p_created_by => gn_user_id,
                                                          p_request_id => gn_conc_request_id,
                                                          p_more_info1 => lt_oe_header_data(xc_header_idx)
                                                                          .order_number,
                                                          p_more_info2 => 'SHIPMETHOD',
                                                          p_more_info3 => lt_oe_header_data(xc_header_idx)
                                                                          .shipping_method_code);*/
                            --                              lc_oe_header_valid_data := gc_no_flag;
                            --ln_new_ship_method := NULL;
                            --set default value for new ship method
                            SELECT ship_method_code
                              INTO ln_new_ship_method
                              FROM wsh_carriers_v a, wsh_carrier_services_v b
                             WHERE     a.carrier_id = b.carrier_id
                                   AND a.carrier_name = 'CONVERSION'
                                   AND a.active = 'A'
                                   AND b.enabled_flag = 'Y'
                                   AND b.ship_method_meaning = 'CONV-CODE';
                        WHEN OTHERS
                        THEN
                            --                              lc_oe_header_valid_data := gc_no_flag;
                            ln_new_ship_method   := NULL;
                    END;

                    IF     ln_new_ship_method IS NOT NULL
                       AND ln_ship_from_org_id IS NOT NULL
                    THEN
                        --check assignment by ship_from_orgznization_id
                        ln_ship_method_header   := 0;

                        SELECT COUNT (a.organization_id)
                          INTO ln_ship_method_header
                          FROM wsh_org_carrier_services_v a, wsh_carrier_services_v b
                         WHERE     a.carrier_service_id =
                                   b.carrier_service_id
                               AND b.enabled_flag = 'Y'
                               AND b.ship_method_code = ln_new_ship_method
                               AND a.enabled_flag = 'Y'
                               AND a.organization_id = ln_ship_from_org_id;

                        IF ln_ship_method_header = 0
                        THEN
                            /*lc_oe_header_valid_data := gc_no_flag;
                            lc_error_message        := 'SHIPMETHOD ' ||
                                                       ln_new_ship_method ||
                                                       ' is not assigned to org id ' ||
                                                       ln_ship_from_org_id ||
                                                       ' in the System';
                            xxd_common_utils.record_error(p_module     => 'ONT',
                                                          p_org_id     => gn_org_id,
                                                          p_program    => 'Deckers Ecomm Closed Sales Order Conversion Program',
                                                          p_error_line => SQLCODE,
                                                          p_error_msg  => lc_error_message,
                                                          p_created_by => gn_user_id,
                                                          p_request_id => gn_conc_request_id,
                                                          p_more_info1 => lt_oe_header_data(xc_header_idx)
                                                                          .order_number,
                                                          p_more_info2 => 'SHIPMETHOD',
                                                          p_more_info3 => ln_new_ship_method);*/

                            --no data found then default shipmethod
                            SELECT ship_method_code
                              INTO ln_new_ship_method
                              FROM wsh_carriers_v a, wsh_carrier_services_v b
                             WHERE     a.carrier_id = b.carrier_id
                                   AND a.carrier_name = 'CONVERSION'
                                   AND a.active = 'A'
                                   AND b.enabled_flag = 'Y'
                                   AND b.ship_method_meaning = 'CONV-ORG';
                        END IF;
                    END IF;

                    /*
                    --            SHIPMENT_PRIORITY_CODE


                    --            DEMAND_CLASS_CODE


                                    IF lt_oe_header_data(xc_header_idx).DEMAND_CLASS_CODE IS NOT NULL THEN
                                           BEGIN
                                               SELECT FLV12.lookup_code
                                                 INTO  l_exists
                                                 FROM   fnd_lookup_values                  FLV12
                                                WHERE  1=1
                                                  AND    FLV12.lookup_type      = 'DEMAND_CLASS'
                                                  AND    FLV12.enabled_flag     = 'Y'
                                                  AND    FLV12.lookup_code      =  lt_oe_header_data(xc_header_idx).DEMAND_CLASS_CODE;
                                           EXCEPTION
                                          WHEN NO_DATA_FOUND THEN
                                              lc_oe_header_valid_data := gc_no_flag;
                                              lc_error_message  := 'DEMAND_CLASS_CODE is not available in the System';
                                              xxd_common_utils.record_error (
                                                                               p_module       => 'ONT',
                                                                               p_org_id       => gn_org_id,
                                                                               p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                                                               p_error_line   => SQLCODE,
                                                                               p_error_msg    => lc_error_message,
                                                                               p_created_by   => gn_user_id,
                                                                               p_request_id   => gn_conc_request_id,
                                                                               p_more_info1   => lt_oe_header_data(xc_header_idx).order_number,
                                                                               p_more_info2   => 'DEMAND_CLASS_CODE',
                                                                               p_more_info3   => lt_oe_header_data(xc_header_idx).DEMAND_CLASS_CODE);
                                          WHEN OTHERS THEN
                                              lc_oe_header_valid_data := gc_no_flag;
                                              lc_error_message  := 'DEMAND_CLASS_CODE is not available in the System';
                                              xxd_common_utils.record_error (
                                                                               p_module       => 'ONT',
                                                                               p_org_id       => gn_org_id,
                                                                               p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                                                               p_error_line   => SQLCODE,
                                                                               p_error_msg    => lc_error_message,
                                                                               p_created_by   => gn_user_id,
                                                                               p_request_id   => gn_conc_request_id,
                                                                               p_more_info1   => lt_oe_header_data(xc_header_idx).order_number,
                                                                               p_more_info2   => 'DEMAND_CLASS_CODE',
                                                                               p_more_info3   => lt_oe_header_data(xc_header_idx).DEMAND_CLASS_CODE);
                                          END;
                                   END IF;

                    --            SHIPPING_METHOD_CODE
                     select lookup_code --into l_meaning
                      from oe_ship_methods_v where lookup_type = 'SHIP_METHOD' and meaning = 'Freight Forwarder'


                                    IF lt_oe_header_data(xc_header_idx).SHIPPING_METHOD_CODE IS NOT NULL THEN
                                           BEGIN

                                               SELECT FLV12.lookup_code
                                                 INTO  l_exists
                                                 FROM   fnd_lookup_values                  FLV12
                                                WHERE  1=1
                                                  AND    FLV12.lookup_type      = 'SHIP_METHOD'
                                                  AND    FLV12.enabled_flag     = 'Y'
                                                  AND    FLV12.lookup_code      =  lt_oe_header_data(xc_header_idx).SHIPPING_METHOD_CODE;
                                           EXCEPTION
                                          WHEN NO_DATA_FOUND THEN
                                              lc_oe_header_valid_data := gc_no_flag;
                                              lc_error_message  := 'SHIPPING_METHOD is not available in the System';
                                              xxd_common_utils.record_error (
                                                                               p_module       => 'ONT',
                                                                               p_org_id       => gn_org_id,
                                                                               p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                                                               p_error_line   => SQLCODE,
                                                                               p_error_msg    => lc_error_message,
                                                                               p_created_by   => gn_user_id,
                                                                               p_request_id   => gn_conc_request_id,
                                                                               p_more_info1   => lt_oe_header_data(xc_header_idx).order_number,
                                                                               p_more_info2   => 'SHIPPING_METHOD_CODE',
                                                                               p_more_info3   => lt_oe_header_data(xc_header_idx).SHIPPING_METHOD_CODE);
                                          WHEN OTHERS THEN
                                              lc_oe_header_valid_data := gc_no_flag;
                                              lc_error_message  := 'SHIPPING_METHOD is not available in the System';
                                              xxd_common_utils.record_error (
                                                                               p_module       => 'ONT',
                                                                               p_org_id       => gn_org_id,
                                                                               p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                                                               p_error_line   => SQLCODE,
                                                                               p_error_msg    => lc_error_message,
                                                                               p_created_by   => gn_user_id,
                                                                               p_request_id   => gn_conc_request_id,
                                                                               p_more_info1   => lt_oe_header_data(xc_header_idx).order_number,
                                                                               p_more_info2   => 'SHIPPING_METHOD_CODE',
                                                                               p_more_info3   => lt_oe_header_data(xc_header_idx).SHIPPING_METHOD_CODE);
                                          END;
                                   END IF;

                    --            FREIGHT_CARRIER_CODE
                                    IF lt_oe_header_data(xc_header_idx).FREIGHT_CARRIER_CODE IS NOT NULL THEN
                                           BEGIN

                                               SELECT  gc_yes_flag
                                                 INTO  l_exists
                                                 FROM   WSH_CARRIERS_V                  FLV12
                                                WHERE  1=1
                                                  AND    FREIGHT_CODE      =  lt_oe_header_data(xc_header_idx).FREIGHT_CARRIER_CODE;
                                           EXCEPTION
                                          WHEN NO_DATA_FOUND THEN
                                              lc_oe_header_valid_data := gc_no_flag;
                                              lc_error_message  := 'FREIGHT_CARRIER_CODE is not available in the System';
                                              xxd_common_utils.record_error (
                                                                               p_module       => 'ONT',
                                                                               p_org_id       => gn_org_id,
                                                                               p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                                                               p_error_line   => SQLCODE,
                                                                               p_error_msg    => lc_error_message,
                                                                               p_created_by   => gn_user_id,
                                                                               p_request_id   => gn_conc_request_id,
                                                                               p_more_info1   => lt_oe_header_data(xc_header_idx).order_number,
                                                                               p_more_info2   => 'FREIGHT_CARRIER_CODE',
                                                                               p_more_info3   => lt_oe_header_data(xc_header_idx).FREIGHT_CARRIER_CODE);
                                          WHEN OTHERS THEN
                                              lc_oe_header_valid_data := gc_no_flag;
                                              lc_error_message  := 'FREIGHT_CARRIER_CODE is not available in the System';
                                              xxd_common_utils.record_error (
                                                                               p_module       => 'ONT',
                                                                               p_org_id       => gn_org_id,
                                                                               p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                                                               p_error_line   => SQLCODE,
                                                                               p_error_msg    => lc_error_message,
                                                                               p_created_by   => gn_user_id,
                                                                               p_request_id   => gn_conc_request_id,
                                                                               p_more_info1   => lt_oe_header_data(xc_header_idx).order_number,
                                                                               p_more_info2   => 'FREIGHT_CARRIER_CODE',
                                                                               p_more_info3   => lt_oe_header_data(xc_header_idx).FREIGHT_CARRIER_CODE);
                                          END;
                                   END IF;


                    --            FOB_POINT_CODE


                    --            FREIGHT_TERMS_CODE
                                    IF lt_oe_header_data(xc_header_idx).FREIGHT_TERMS_CODE IS NOT NULL THEN
                                           BEGIN

                                              SELECT FLV12.lookup_code
                                                 INTO  l_exists
                                                 FROM   fnd_lookup_values                  FLV12
                                                WHERE  1=1
                                                  AND    FLV12.lookup_type      = 'FREIGHT_TERMS'
                                                  AND    FLV12.enabled_flag     = 'Y'
                                                  AND    FLV12.lookup_code      =  lt_oe_header_data(xc_header_idx).FREIGHT_TERMS_CODE;
                                           EXCEPTION
                                          WHEN NO_DATA_FOUND THEN
                                              lc_oe_header_valid_data := gc_no_flag;
                                              lc_error_message  := 'FREIGHT_TERMS_CODE is not available in the System';
                                              xxd_common_utils.record_error (
                                                                               p_module       => 'ONT',
                                                                               p_org_id       => gn_org_id,
                                                                               p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                                                               p_error_line   => SQLCODE,
                                                                               p_error_msg    => lc_error_message,
                                                                               p_created_by   => gn_user_id,
                                                                               p_request_id   => gn_conc_request_id,
                                                                               p_more_info1   => lt_oe_header_data(xc_header_idx).order_number,
                                                                               p_more_info2   => 'FREIGHT_TERMS_CODE',
                                                                               p_more_info3   => lt_oe_header_data(xc_header_idx).FREIGHT_TERMS_CODE);
                                          WHEN OTHERS THEN
                                              lc_oe_header_valid_data := gc_no_flag;
                                              lc_error_message  := 'FREIGHT_TERMS_CODE is not available in the System';
                                              xxd_common_utils.record_error (
                                                                               p_module       => 'ONT',
                                                                               p_org_id       => gn_org_id,
                                                                               p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                                                               p_error_line   => SQLCODE,
                                                                               p_error_msg    => lc_error_message,
                                                                               p_created_by   => gn_user_id,
                                                                               p_request_id   => gn_conc_request_id,
                                                                               p_more_info1   => lt_oe_header_data(xc_header_idx).order_number,
                                                                               p_more_info2   => 'FREIGHT_TERMS_CODE',
                                                                               p_more_info3   => lt_oe_header_data(xc_header_idx).FREIGHT_TERMS_CODE);
                                          END;
                                   END IF;
                    --ITEM_SEGMENT1
                    --SHIPPING_METHOD_CODE
                    --FOB_POINT_CODE
                    --ITEM_TYPE_CODE
                    --LINE_CATEGORY_CODE
                    --SOURCE_TYPE_CODE
                    --LINE_TYPE
                    --BILL_TO_ORG_ID
                    --SHIP_TO_ORG_ID
                    --SHIP_FROM
                        */
                    OPEN cur_oe_lines (
                        p_header_id   =>
                            lt_oe_header_data (xc_header_idx).header_id);

                    FETCH cur_oe_lines BULK COLLECT INTO lt_oe_lines_data;

                    CLOSE cur_oe_lines;

                    log_records (
                        gc_debug_flag,
                        'validate Order Lines ' || lt_oe_lines_data.COUNT);

                    IF lt_oe_lines_data.COUNT > 0
                    THEN
                        FOR xc_line_idx IN lt_oe_lines_data.FIRST ..
                                           lt_oe_lines_data.LAST
                        LOOP
                            ln_new_line_type_id        := NULL;
                            ln_inventory_item_id       := NULL;
                            ln_line_ship_from_org_id   := NULL;
                            ln_line_ship_to_site_id    := NULL;
                            lc_oe_line_valid_data      := gc_yes_flag;
                            l_1206_tax_code            := NULL;
                            l_1206_tax_rate            := NULL;
                            l_content_owner_id         := NULL;
                            l_new_rate_code            := NULL;
                            l_new_attribute4           := NULL;
                            ln_rate_exists             := NULL;
                            l_1206_tax_code1           := NULL;

                            -- IF lt_oe_lines_data(xc_line_idx).SOURCE_TYPE_CODE   = 'EXTERNAL' THEN
                            /* begin
                               select ott.transaction_type_id
                                 into ln_new_line_type_id
                                 from oe_workflow_assignments   owa,
                                      oe_transaction_types_tl   ott,
                                      xxd_1206_order_type_map_t xott
                                where owa.line_type_id = ott.transaction_type_id
                                  and line_type_for_conversion = ott.name
                                  and legacy_12_0_6_name = lt_oe_header_data(xc_header_idx)
                                     .order_type
                                  and language = 'US'
                                  and sysdate between start_date_active and
                                      nvl(end_date_active, sysdate);
                             exception
                               when no_data_found then
                                 --                              lc_oe_header_valid_data := gc_no_flag;
                                 ln_new_line_type_id := null;
                               when others then
                                 --                              lc_oe_header_valid_data := gc_no_flag;
                                 ln_new_line_type_id := null;
                             end;*/

                            --meenakshi 18-may
                            BEGIN
                                SELECT ott.transaction_type_id
                                  INTO ln_new_line_type_id
                                  FROM oe_transaction_types_tl ott
                                 WHERE     ott.name =
                                           lt_oe_lines_data (xc_line_idx).line_type
                                       AND LANGUAGE = 'US';
                            -- AND    SYSDATE BETWEEN start_date_active AND
                            --       nvl(end_date_active, SYSDATE);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    --                              lc_oe_header_valid_data := gc_no_flag;
                                    ln_new_line_type_id   := NULL;
                                WHEN OTHERS
                                THEN
                                    --                              lc_oe_header_valid_data := gc_no_flag;
                                    ln_new_line_type_id   := NULL;
                            END;

                            --   END IF;
                            --            SHIP_TO_ORG_ID

                            IF lt_oe_lines_data (xc_line_idx).ship_to_org_id
                                   IS NOT NULL
                            THEN
                                BEGIN
                                    SELECT site_use_id
                                      INTO ln_line_ship_to_site_id
                                      FROM hz_cust_site_uses_all
                                     WHERE     orig_system_reference =
                                               TO_CHAR (
                                                   lt_oe_lines_data (
                                                       xc_line_idx).ship_to_org_id) --jerry modify 11-may
                                           AND site_use_code = 'SHIP_TO'
                                           AND status = 'A';
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        --                              lc_oe_header_valid_data := gc_no_flag;
                                        lc_error_message   :=
                                               'Customer Ship to '
                                            || lt_oe_lines_data (xc_line_idx).ship_to_org_id
                                            || ' is not available in the System';
                                        fnd_file.put_line (fnd_file.LOG,
                                                           lc_error_message); --jerry
                                        xxd_common_utils.record_error (
                                            p_module       => 'ONT',
                                            p_org_id       => gn_org_id,
                                            p_program      =>
                                                'Deckers Ecomm Open Sales Order Conversion Program',
                                            p_error_line   => SQLCODE,
                                            p_error_msg    => lc_error_message,
                                            p_created_by   => gn_user_id,
                                            p_request_id   =>
                                                gn_conc_request_id,
                                            p_more_info1   =>
                                                lt_oe_header_data (
                                                    xc_header_idx).order_number,
                                            p_more_info2   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).line_number,
                                            p_more_info3   =>
                                                'LINE_SHIP_TO_ORG_ID',
                                            p_more_info4   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).ship_to_org_id);
                                    WHEN OTHERS
                                    THEN
                                        --                              lc_oe_header_valid_data := gc_no_flag;
                                        lc_error_message   :=
                                               'Customer Ship to '
                                            || lt_oe_lines_data (xc_line_idx).ship_to_org_id
                                            || ' is not available in the System';
                                        fnd_file.put_line (fnd_file.LOG,
                                                           lc_error_message); --jerry
                                        xxd_common_utils.record_error (
                                            p_module       => 'ONT',
                                            p_org_id       => gn_org_id,
                                            p_program      =>
                                                'Deckers Ecomm Open Sales Order Conversion Program',
                                            p_error_line   => SQLCODE,
                                            p_error_msg    => lc_error_message,
                                            p_created_by   => gn_user_id,
                                            p_request_id   =>
                                                gn_conc_request_id,
                                            p_more_info1   =>
                                                lt_oe_header_data (
                                                    xc_header_idx).order_number,
                                            p_more_info2   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).line_number,
                                            p_more_info3   =>
                                                'LINE_SHIP_TO_ORG_ID',
                                            p_more_info4   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).ship_to_org_id);
                                END;
                            END IF;

                            IF ln_line_ship_to_site_id IS NULL
                            THEN
                                ln_line_ship_to_site_id   :=
                                    ln_new_ship_to_site_id;
                            END IF;

                            IF     lt_oe_lines_data (xc_line_idx).ship_from
                                       IS NOT NULL
                               AND lt_oe_lines_data (xc_line_idx).ship_from <>
                                   612
                            THEN
                                ln_line_ship_from_org_id   :=
                                    get_new_inv_org_id (
                                        p_old_org_id   =>
                                            lt_oe_lines_data (xc_line_idx).ship_from);

                                IF ln_line_ship_from_org_id IS NULL
                                THEN
                                    lc_oe_header_valid_data   := gc_no_flag;
                                    lc_error_message          :=
                                           'Ship From Organization '
                                        || lt_oe_lines_data (xc_line_idx).ship_from
                                        || ' is not available in the System';
                                    fnd_file.put_line (fnd_file.LOG,
                                                       lc_error_message); --jerry
                                    xxd_common_utils.record_error (
                                        p_module       => 'ONT',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers Ecomm Open Sales Order Conversion Program',
                                        p_error_line   => SQLCODE,
                                        p_error_msg    => lc_error_message,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   =>
                                            lt_oe_header_data (xc_header_idx).order_number,
                                        p_more_info2   =>
                                            lt_oe_lines_data (xc_line_idx).line_number,
                                        p_more_info3   =>
                                            'LINE_SHIP_FROM_ORG_ID',
                                        p_more_info4   =>
                                            lt_oe_lines_data (xc_line_idx).ship_from);
                                END IF;
                            ELSIF lt_oe_lines_data (xc_line_idx).ship_from =
                                  612
                            THEN
                                ln_line_ship_from_org_id   := 109;
                            ELSE
                                ln_line_ship_from_org_id   :=
                                    ln_ship_from_org_id;
                            END IF;

                            BEGIN
                                --    Inventory validation
                                SELECT inventory_item_id
                                  INTO ln_inventory_item_id
                                  FROM mtl_system_items_b
                                 WHERE --segment1 = lt_oe_lines_data(xc_line_idx)
                                           --.item_segment1
                                                             --Meenakshi 8-Jul
                                           inventory_item_id =
                                           lt_oe_lines_data (xc_line_idx).old_inventory_item_id
                                       AND organization_id =
                                           ln_line_ship_from_org_id
                                       --                               IN
                                       --                                   (SELECT warehouse_id
                                       --                                      FROM oe_transaction_types_all
                                       --                                     WHERE transaction_type_id = ln_new_order_type_id)
                                       AND customer_order_flag = 'Y'
                                       AND customer_order_enabled_flag = 'Y'
                                       AND inventory_item_status_code =
                                           'Active';
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_oe_line_valid_data   := gc_no_flag;
                                    lc_error_message        :=
                                           'ITEM_SEGMENT1 '
                                        || lt_oe_lines_data (xc_line_idx).item_segment1
                                        || ' is not available in the System';
                                    fnd_file.put_line (fnd_file.LOG,
                                                       lc_error_message); --jerry
                                    xxd_common_utils.record_error (
                                        p_module       => 'ONT',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers Ecomm Open Sales Order Conversion Program',
                                        p_error_line   => SQLCODE,
                                        p_error_msg    => lc_error_message,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   =>
                                            lt_oe_header_data (xc_header_idx).order_number,
                                        p_more_info2   =>
                                            lt_oe_lines_data (xc_line_idx).line_number,
                                        p_more_info3   => 'ITEM_SEGMENT1',
                                        p_more_info4   =>
                                            lt_oe_lines_data (xc_line_idx).item_segment1);
                                WHEN OTHERS
                                THEN
                                    lc_oe_line_valid_data   := gc_no_flag;
                                    lc_error_message        :=
                                           'ITEM_SEGMENT1 '
                                        || lt_oe_lines_data (xc_line_idx).item_segment1
                                        || ' is not available in the System';
                                    fnd_file.put_line (fnd_file.LOG,
                                                       lc_error_message); --jerry
                                    xxd_common_utils.record_error (
                                        p_module       => 'ONT',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers Ecomm Open Sales Order Conversion Program',
                                        p_error_line   => SQLCODE,
                                        p_error_msg    => lc_error_message,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   =>
                                            lt_oe_header_data (xc_header_idx).order_number,
                                        p_more_info2   =>
                                            lt_oe_lines_data (xc_line_idx).line_number,
                                        p_more_info3   => 'ITEM_SEGMENT1',
                                        p_more_info4   =>
                                            lt_oe_lines_data (xc_line_idx).item_segment1);
                            END;

                            lx_return_status           := NULL;

                            /*  call_atp_toschedule (p_inventory_item_id            =>         ln_inventory_item_id
                                                ,p_quantity_ordered            =>         lt_oe_lines_data(xc_line_idx).ORDERED_QUANTITY
                                                ,p_quantity_uom                =>         lt_oe_lines_data(xc_line_idx).ORDER_QUANTITY_UOM
                                                ,p_requested_ship_date         =>         lt_oe_header_data(xc_header_idx).REQUEST_DATE
                                                ,p_source_organization_id      =>         ln_ship_from_org_id
                                                ,p_order_number                =>         NULL
                                                ,p_line_number                 =>         NULL
                                                ,x_return_status               =>         lx_return_status
                                                ,x_return_msg                  =>         lc_error_message);

                            IF   lc_error_message IS NOT NULL THEN
                                 lc_oe_line_valid_data := gc_no_flag;
                                 xxd_common_utils.record_error (
                                                                p_module       => 'ONT',
                                                                p_org_id       => gn_org_id,
                                                                p_program      => 'Deckers Ecomm Open Sales Order Conversion Program',
                                                                p_error_line   => SQLCODE,
                                                                p_error_msg    => lc_error_message,
                                                                p_created_by   => gn_user_id,
                                                                p_request_id   => gn_conc_request_id,
                                                                p_more_info1   => lt_oe_header_data(xc_header_idx).order_number,
                                                                p_more_info2   => lt_oe_lines_data(xc_line_idx).line_number,
                                                                p_more_info3   => 'CALL_ATP_TOSCHEDULE',
                                                                p_more_info4   => lt_oe_lines_data(xc_line_idx).ITEM_SEGMENT1 );
                            END IF;*/
                            --- workflow validation
                            --        SELECT COUNT(1)
                            --          INTO l_cnt
                            --          FROM oe_wf_line_assign_v
                            --         WHERE order_type_id = ln_new_order_type_id AND line_type_id = line_rec.line_type_id AND
                            --               SYSDATE BETWEEN start_date_active AND nvl(end_date_active, SYSDATE);

                            --- Ship method validation code
                            BEGIN
                                SELECT new_ship_method_code
                                  INTO ln_new_ship_method_line
                                  FROM xxd_1206_ship_methods_map_t
                                 WHERE old_ship_method_code =
                                       lt_oe_lines_data (xc_line_idx).shipping_method_code;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    --jerry modify
                                    /*lc_oe_header_valid_data := gc_no_flag;
                                    lc_error_message        := 'SHIPMETHOD ' || lt_oe_lines_data(xc_line_idx)
                                                              .shipping_method_code ||
                                                               ' is not available in the System';
                                    xxd_common_utils.record_error(p_module     => 'ONT',
                                                                  p_org_id     => gn_org_id,
                                                                  p_program    => 'Deckers Ecomm Closed Sales Order Conversion Program',
                                                                  p_error_line => SQLCODE,
                                                                  p_error_msg  => lc_error_message,
                                                                  p_created_by => gn_user_id,
                                                                  p_request_id => gn_conc_request_id,
                                                                  p_more_info1 => lt_oe_header_data(xc_header_idx)
                                                                                  .order_number,
                                                                  p_more_info2 => lt_oe_lines_data(xc_line_idx)
                                                                                  .line_number,
                                                                  p_more_info3 => 'SHIPMETHOD',
                                                                  p_more_info4 => lt_oe_lines_data(xc_line_idx)
                                                                                  .shipping_method_code);*/
                                    --                              lc_oe_header_valid_data := gc_no_flag;
                                    --ln_new_ship_method_line := NULL;
                                    --set default value for new ship method
                                    SELECT ship_method_code
                                      INTO ln_new_ship_method_line
                                      FROM wsh_carriers_v a, wsh_carrier_services_v b
                                     WHERE     a.carrier_id = b.carrier_id
                                           AND a.carrier_name = 'CONVERSION'
                                           AND a.active = 'A'
                                           AND b.enabled_flag = 'Y'
                                           AND b.ship_method_meaning =
                                               'CONV-CODE';
                                WHEN OTHERS
                                THEN
                                    --                              lc_oe_header_valid_data := gc_no_flag;
                                    ln_new_ship_method_line   := NULL;
                            END;

                            IF     ln_new_ship_method_line IS NOT NULL
                               AND ln_line_ship_from_org_id IS NOT NULL
                            THEN
                                --check assignment by ship_from_orgznization_id
                                ln_ship_method_line   := 0;

                                SELECT COUNT (a.organization_id)
                                  INTO ln_ship_method_line
                                  FROM wsh_org_carrier_services_v a, wsh_carrier_services_v b
                                 WHERE     a.carrier_service_id =
                                           b.carrier_service_id
                                       AND b.enabled_flag = 'Y'
                                       AND b.ship_method_code =
                                           ln_new_ship_method_line
                                       AND a.enabled_flag = 'Y'
                                       AND a.organization_id =
                                           ln_line_ship_from_org_id;

                                IF ln_ship_method_line = 0
                                THEN
                                    /*lc_oe_header_valid_data := gc_no_flag;
                                    lc_error_message        := 'SHIPMETHOD ' ||
                                                               ln_new_ship_method_line ||
                                                               ' is not assigned to org id ' ||
                                                               ln_line_ship_from_org_id ||
                                                               ' in the System';
                                    xxd_common_utils.record_error(p_module     => 'ONT',
                                                                  p_org_id     => gn_org_id,
                                                                  p_program    => 'Deckers Ecomm Closed Sales Order Conversion Program',
                                                                  p_error_line => SQLCODE,
                                                                  p_error_msg  => lc_error_message,
                                                                  p_created_by => gn_user_id,
                                                                  p_request_id => gn_conc_request_id,
                                                                  p_more_info1 => lt_oe_header_data(xc_header_idx)
                                                                                  .order_number,
                                                                  p_more_info2 => lt_oe_lines_data(xc_line_idx)
                                                                                  .line_number,
                                                                  p_more_info3 => 'SHIPMETHOD',
                                                                  p_more_info4 => ln_new_ship_method_line);*/
                                    --no data found then default shipmethod
                                    SELECT ship_method_code
                                      INTO ln_new_ship_method_line
                                      FROM wsh_carriers_v a, wsh_carrier_services_v b
                                     WHERE     a.carrier_id = b.carrier_id
                                           AND a.carrier_name = 'CONVERSION'
                                           AND a.active = 'A'
                                           AND b.enabled_flag = 'Y'
                                           AND b.ship_method_meaning =
                                               'CONV-ORG';
                                END IF;
                            END IF;


                            -- Meenakshi Tax Validation Changes
                            IF ln_new_org_id NOT IN (100)
                            THEN
                                BEGIN
                                    SELECT --rates.TAX_RATE_CODE  TAX_RATE_code ,
                                           adj.operand PERCENTAGE_RATE, tax_rate_code
                                      INTO                  --l_1206_tax_code,
                                           l_1206_tax_rate, l_1206_tax_code1
                                      FROM -- xxd_so_ws_lines_conv_stg_t lines,
                                           xxd_conv.xxd_1206_OE_PRICE_ADJUSTMENTs adj, xxd_conv.xxd_1206_ZX_RATES_B rates
                                     WHERE     lt_oe_lines_data (xc_line_idx).header_id =
                                               adj.header_id
                                           AND lt_oe_lines_data (xc_line_idx).line_id =
                                               adj.line_id
                                           AND adj.tax_rate_id =
                                               rates.tax_rate_id
                                           -- and lines.tax_code is null
                                           AND (NVL (lt_oe_lines_data (xc_line_idx).TAX_CODE, 'XXX') <> 'Exempt' -- or  lt_oe_lines_data(xc_line_idx).TAX_CODE is null
                                                                                                                 OR NVL (lt_oe_lines_data (xc_line_idx).TAX_CODE, 'XXX') <> 'EU ZERO RATE')
                                           AND adj.LIST_LINE_TYPE_CODE =
                                               'TAX'
                                           --   and to_date( nvl(lines.tax_date,sysdate),'DD-MM-YYYY') between to_date(rates.EFFECTIVE_FROM ,'DD/MM/YYYY')and to_date (nvl(rates.EFFECTIVE_TO,nvl(lines.tax_date,sysdate)),
                                           -- 'DD/MM/YYYY')
                                           AND NVL (
                                                   lt_oe_lines_data (
                                                       xc_line_idx).tax_date,
                                                   SYSDATE) BETWEEN rates.EFFECTIVE_FROM
                                                                AND NVL (
                                                                        rates.EFFECTIVE_TO,
                                                                        NVL (
                                                                            lt_oe_lines_data (
                                                                                xc_line_idx).tax_date,
                                                                            SYSDATE))--and lines.line_id = lt_oe_lines_data(xc_line_idx).line_id
                                                                                     ;

                                    l_1206_tax_code   := 'XXX';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_1206_tax_rate   := NULL;
                                END;

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'derived rate ' || l_1206_tax_rate);

                                SELECT PTP.PARTY_TAX_PROFILE_ID
                                  INTO l_content_owner_id
                                  FROM apps.ZX_PARTY_TAX_PROFILE PTP, apps.HR_OPERATING_UNITS HOU
                                 WHERE     PTP.PARTY_TYPE_CODE = 'OU'
                                       AND PTP.PARTY_ID = HOU.ORGANIZATION_ID
                                       AND HOU.ORGANIZATION_ID =
                                           ln_new_org_id;

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'l_content_owner_id '
                                    || l_content_owner_id);

                                IF l_1206_tax_rate IS NOT NULL
                                THEN
                                    BEGIN
                                        SELECT 1
                                          INTO ln_rate_exists
                                          FROM apps.zx_jurisdictions_vl zjv, apps.zx_taxes_b ztb, apps.zx_taxes_tl ztt,
                                               apps.hz_geographies hg, apps.hz_geography_types_b hgt, apps.zx_regimes_b zrb,
                                               apps.zx_regimes_tl zrt, apps.zx_status_b zsb, apps.zx_status_tl zst,
                                               apps.zx_rates_b zb, apps.zx_rates_tl zbt, apps.hz_relationships hzr,
                                               apps.hz_geographies hg1
                                         WHERE     zjv.tax = ztb.tax
                                               AND zjv.tax_regime_code =
                                                   ztb.tax_regime_code
                                               AND zjv.tax_regime_code =
                                                   zrb.tax_regime_code
                                               AND NVL (zrb.effective_to,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND ztt.tax_id = ztb.tax_id
                                               AND ztt.language = 'US'
                                               AND zrb.tax_regime_id =
                                                   zrt.tax_regime_id
                                               AND zrt.language = 'US'
                                               AND ztb.tax = zsb.tax
                                               AND ztb.tax_regime_code =
                                                   zsb.tax_regime_code
                                               AND NVL (ztb.effective_to,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND ztb.content_owner_id =
                                                   zsb.content_owner_id
                                               AND NVL (zsb.effective_to,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND zsb.tax_status_id =
                                                   zst.tax_status_id
                                               AND zst.language = 'US'
                                               AND zb.tax_regime_code =
                                                   zsb.tax_regime_code
                                               AND zb.tax = zsb.tax
                                               AND zb.tax_status_code =
                                                   zsb.tax_status_code
                                               AND zb.content_owner_id =
                                                   zsb.content_owner_id
                                               AND zb.active_flag = 'Y'
                                               AND NVL (zb.effective_to,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND zb.tax_regime_code =
                                                   zrb.tax_regime_code
                                               AND zb.tax = ztb.tax
                                               AND zb.tax_regime_code =
                                                   ztb.tax_regime_code
                                               AND zb.content_owner_id =
                                                   ztb.content_owner_id
                                               AND zb.active_flag = 'Y'
                                               AND zb.rate_type_code <>
                                                   'RECOVERY'
                                               AND zb.tax_jurisdiction_code =
                                                   zjv.tax_jurisdiction_code
                                               AND zb.tax_rate_id =
                                                   zbt.tax_rate_id
                                               AND zbt.language = 'US'
                                               AND zsb.tax_regime_code =
                                                   zrb.tax_regime_code
                                               AND ztb.Tax = zsb.tax
                                               AND zsb.tax_regime_code =
                                                   ztb.tax_regime_code
                                               AND zsb.content_owner_id =
                                                   ztb.content_owner_id
                                               AND hg.geography_id =
                                                   zjv.zone_geography_id
                                               AND hgt.geography_type =
                                                   hg.geography_type
                                               AND ztb.source_tax_flag = 'Y'
                                               AND hg.geography_id =
                                                   hzr.subject_id
                                               AND hzr.subject_type =
                                                   hg.geography_type
                                               AND hzr.object_id =
                                                   hg1.geography_id
                                               AND hzr.object_table_name =
                                                   'HZ_GEOGRAPHIES'
                                               AND ztb.content_owner_id =
                                                   l_content_owner_id -- 812722
                                               AND 1 =
                                                   CASE
                                                       WHEN    INSTR (
                                                                   zb.tax_rate_code,
                                                                   'EXEMPT') >
                                                               0
                                                            OR INSTR (
                                                                   zb.tax_rate_code,
                                                                   'ZERO RATE') >
                                                               0
                                                       THEN
                                                           0
                                                       ELSE
                                                           1
                                                   END
                                               AND zb.percentage_rate =
                                                   l_1206_tax_rate
                                               AND zb.tax_rate_code =
                                                   l_1206_tax_code1;

                                        l_new_rate_code   := l_1206_tax_code1;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            ln_rate_exists   := 0;
                                    END;
                                END IF;

                                BEGIN
                                    --if  l_1206_tax_rate is not null then
                                    IF ln_rate_exists = 0
                                    THEN
                                        SELECT DISTINCT zb.tax_rate_code
                                          INTO l_new_rate_code
                                          FROM apps.zx_jurisdictions_vl zjv, apps.zx_taxes_b ztb, apps.zx_taxes_tl ztt,
                                               apps.hz_geographies hg, apps.hz_geography_types_b hgt, apps.zx_regimes_b zrb,
                                               apps.zx_regimes_tl zrt, apps.zx_status_b zsb, apps.zx_status_tl zst,
                                               apps.zx_rates_b zb, apps.zx_rates_tl zbt, apps.hz_relationships hzr,
                                               apps.hz_geographies hg1, apps.hz_cust_acct_sites_all hcsa, apps.hz_cust_site_uses_all hcsu,
                                               apps.hz_party_sites hps, apps.hz_locations hl
                                         WHERE     zjv.tax = ztb.tax
                                               AND zjv.tax_regime_code =
                                                   ztb.tax_regime_code
                                               AND zjv.tax_regime_code =
                                                   zrb.tax_regime_code
                                               AND NVL (zrb.effective_to,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND ztt.tax_id = ztb.tax_id
                                               AND ztt.language = 'US'
                                               AND zrb.tax_regime_id =
                                                   zrt.tax_regime_id
                                               AND zrt.language = 'US'
                                               AND ztb.tax = zsb.tax
                                               AND ztb.tax_regime_code =
                                                   zsb.tax_regime_code
                                               AND NVL (ztb.effective_to,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND ztb.content_owner_id =
                                                   zsb.content_owner_id
                                               AND NVL (zsb.effective_to,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND zsb.tax_status_id =
                                                   zst.tax_status_id
                                               AND zst.language = 'US'
                                               AND zb.tax_regime_code =
                                                   zsb.tax_regime_code
                                               AND zb.tax = zsb.tax
                                               AND zb.tax_status_code =
                                                   zsb.tax_status_code
                                               AND zb.content_owner_id =
                                                   zsb.content_owner_id
                                               AND zb.active_flag = 'Y'
                                               AND NVL (zb.effective_to,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND zb.tax_regime_code =
                                                   zrb.tax_regime_code
                                               AND zb.tax = ztb.tax
                                               AND zb.tax_regime_code =
                                                   ztb.tax_regime_code
                                               AND zb.content_owner_id =
                                                   ztb.content_owner_id
                                               AND zb.active_flag = 'Y'
                                               AND zb.rate_type_code <>
                                                   'RECOVERY'
                                               AND zb.tax_jurisdiction_code =
                                                   zjv.tax_jurisdiction_code
                                               AND zb.tax_rate_id =
                                                   zbt.tax_rate_id
                                               AND zbt.language = 'US'
                                               AND zsb.tax_regime_code =
                                                   zrb.tax_regime_code
                                               AND ztb.Tax = zsb.tax
                                               AND zsb.tax_regime_code =
                                                   ztb.tax_regime_code
                                               AND zsb.content_owner_id =
                                                   ztb.content_owner_id
                                               AND hg.geography_id =
                                                   zjv.zone_geography_id
                                               AND hgt.geography_type =
                                                   hg.geography_type
                                               AND ztb.source_tax_flag = 'Y'
                                               AND hg.geography_id =
                                                   hzr.subject_id
                                               AND hzr.subject_type =
                                                   hg.geography_type
                                               AND hzr.object_id =
                                                   hg1.geography_id
                                               AND hzr.object_table_name =
                                                   'HZ_GEOGRAPHIES'
                                               AND ztb.content_owner_id =
                                                   l_content_owner_id -- 812722
                                               AND 1 =
                                                   CASE
                                                       WHEN    INSTR (
                                                                   zb.tax_rate_code,
                                                                   'EXEMPT') >
                                                               0
                                                            OR INSTR (
                                                                   zb.tax_rate_code,
                                                                   'ZERO RATE') >
                                                               0
                                                       THEN
                                                           0
                                                       ELSE
                                                           1
                                                   END
                                               AND zb.percentage_rate =
                                                   l_1206_tax_rate
                                               AND hcsu.cust_acct_site_id =
                                                   hcsa.cust_acct_site_id
                                               AND hcsa.party_site_id =
                                                   hps.party_site_id
                                               AND hps.location_id =
                                                   hl.location_id
                                               AND site_use_id =
                                                   ln_new_ship_to_site_id
                                               AND zrb.country_code =
                                                   hl.country--   and rownum = 1
                                                             ;

                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'l_new_rate_code  '
                                            || l_new_rate_code);
                                    END IF;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_new_rate_code   := NULL;
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'l_new_rate_code excception '
                                            || l_new_rate_code);
                                END;

                                IF    l_new_rate_code IS NULL
                                   OR l_1206_tax_rate = NULL
                                THEN
                                    BEGIN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'in if of deriving new tax rate');

                                        SELECT DISTINCT zb.tax_rate_code
                                          INTO l_new_rate_code
                                          FROM apps.zx_jurisdictions_vl zjv, apps.zx_taxes_b ztb, apps.zx_taxes_tl ztt,
                                               apps.hz_geographies hg, apps.hz_geography_types_b hgt, apps.zx_regimes_b zrb,
                                               apps.zx_regimes_tl zrt, apps.zx_status_b zsb, apps.zx_status_tl zst,
                                               apps.zx_rates_b zb, apps.zx_rates_tl zbt, apps.hz_relationships hzr,
                                               apps.hz_geographies hg1, apps.hz_cust_acct_sites_all hcsa, apps.hz_cust_site_uses_all hcsu,
                                               apps.hz_party_sites hps, apps.hz_locations hl
                                         WHERE     zjv.tax = ztb.tax
                                               AND zjv.tax_regime_code =
                                                   ztb.tax_regime_code
                                               AND zjv.tax_regime_code =
                                                   zrb.tax_regime_code
                                               AND NVL (zrb.effective_to,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND ztt.tax_id = ztb.tax_id
                                               AND ztt.language = 'US'
                                               AND zrb.tax_regime_id =
                                                   zrt.tax_regime_id
                                               AND zrt.language = 'US'
                                               AND ztb.tax = zsb.tax
                                               AND ztb.tax_regime_code =
                                                   zsb.tax_regime_code
                                               AND NVL (ztb.effective_to,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND ztb.content_owner_id =
                                                   zsb.content_owner_id
                                               AND NVL (zsb.effective_to,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND zsb.tax_status_id =
                                                   zst.tax_status_id
                                               AND zst.language = 'US'
                                               AND zb.tax_regime_code =
                                                   zsb.tax_regime_code
                                               AND zb.tax = zsb.tax
                                               AND zb.tax_status_code =
                                                   zsb.tax_status_code
                                               AND zb.content_owner_id =
                                                   zsb.content_owner_id
                                               AND zb.active_flag = 'Y'
                                               AND NVL (zb.effective_to,
                                                        SYSDATE) >=
                                                   SYSDATE
                                               AND zb.tax_regime_code =
                                                   zrb.tax_regime_code
                                               AND zb.tax = ztb.tax
                                               AND zb.tax_regime_code =
                                                   ztb.tax_regime_code
                                               AND zb.content_owner_id =
                                                   ztb.content_owner_id
                                               AND zb.active_flag = 'Y'
                                               AND zb.rate_type_code <>
                                                   'RECOVERY'
                                               AND zb.tax_jurisdiction_code =
                                                   zjv.tax_jurisdiction_code
                                               AND zb.tax_rate_id =
                                                   zbt.tax_rate_id
                                               AND zbt.language = 'US'
                                               AND zsb.tax_regime_code =
                                                   zrb.tax_regime_code
                                               AND ztb.Tax = zsb.tax
                                               AND zsb.tax_regime_code =
                                                   ztb.tax_regime_code
                                               AND zsb.content_owner_id =
                                                   ztb.content_owner_id
                                               AND hg.geography_id =
                                                   zjv.zone_geography_id
                                               AND hgt.geography_type =
                                                   hg.geography_type
                                               AND ztb.source_tax_flag = 'Y'
                                               AND hg.geography_id =
                                                   hzr.subject_id
                                               AND hzr.subject_type =
                                                   hg.geography_type
                                               AND hzr.object_id =
                                                   hg1.geography_id
                                               AND hzr.object_table_name =
                                                   'HZ_GEOGRAPHIES'
                                               AND ztb.content_owner_id =
                                                   l_content_owner_id -- 812722
                                               AND 1 =
                                                   CASE
                                                       WHEN    INSTR (
                                                                   zb.tax_rate_code,
                                                                   'EXEMPT') >
                                                               0
                                                            OR INSTR (
                                                                   zb.tax_rate_code,
                                                                   'ZERO RATE') >
                                                               0
                                                       THEN
                                                           0
                                                       ELSE
                                                           1
                                                   END
                                               AND zb.percentage_rate = 0
                                               AND hcsu.cust_acct_site_id =
                                                   hcsa.cust_acct_site_id
                                               AND hcsa.party_site_id =
                                                   hps.party_site_id
                                               AND hps.location_id =
                                                   hl.location_id
                                               AND site_use_id =
                                                   ln_new_ship_to_site_id
                                               --  and head.header_id = lines.header_id
                                               AND zrb.country_code =
                                                   hl.country--and rownum = 1
                                                             ;


                                        l_1206_tax_rate   := 0;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            l_new_rate_code   := NULL;
                                            l_1206_tax_rate   := NULL;
                                    END;

                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           ' l_new_rate_code '
                                        || l_new_rate_code);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'l_1206_tax_rate ' || l_1206_tax_rate);
                                END IF;

                                IF    UPPER (
                                          lt_oe_lines_data (xc_line_idx).tax_code) LIKE
                                          '%EXEMPT%'
                                   OR UPPER (
                                          lt_oe_lines_data (xc_line_idx).tax_code) LIKE
                                          '%ZERO RATE%'
                                THEN
                                    l_1206_tax_rate   := 0;
                                    l_new_rate_code   :=
                                        UPPER (
                                            lt_oe_lines_data (xc_line_idx).tax_code);
                                END IF;
                            ELSE
                                BEGIN
                                    SELECT --rates.TAX_RATE_CODE  TAX_RATE_code ,
                                           adj.operand PERCENTAGE_RATE, tax_rate_code
                                      INTO                  --l_1206_tax_code,
                                           l_1206_tax_rate, l_1206_tax_code1
                                      FROM -- xxd_so_ws_lines_conv_stg_t lines,
                                           xxd_conv.xxd_1206_OE_PRICE_ADJUSTMENTs adj, xxd_conv.xxd_1206_ZX_RATES_B rates
                                     WHERE     lt_oe_lines_data (xc_line_idx).header_id =
                                               adj.header_id
                                           AND lt_oe_lines_data (xc_line_idx).line_id =
                                               adj.line_id
                                           AND adj.tax_rate_id =
                                               rates.tax_rate_id
                                           -- and lines.tax_code is null
                                           AND (NVL (lt_oe_lines_data (xc_line_idx).TAX_CODE, 'XXX') <> 'Exempt' -- or  lt_oe_lines_data(xc_line_idx).TAX_CODE is null
                                                                                                                 OR NVL (lt_oe_lines_data (xc_line_idx).TAX_CODE, 'XXX') <> 'EU ZERO RATE')
                                           AND adj.LIST_LINE_TYPE_CODE =
                                               'TAX'
                                           --   and to_date( nvl(lines.tax_date,sysdate),'DD-MM-YYYY') between to_date(rates.EFFECTIVE_FROM ,'DD/MM/YYYY')and to_date (nvl(rates.EFFECTIVE_TO,nvl(lines.tax_date,sysdate)),
                                           -- 'DD/MM/YYYY')
                                           AND NVL (
                                                   lt_oe_lines_data (
                                                       xc_line_idx).tax_date,
                                                   SYSDATE) BETWEEN rates.EFFECTIVE_FROM
                                                                AND NVL (
                                                                        rates.EFFECTIVE_TO,
                                                                        NVL (
                                                                            lt_oe_lines_data (
                                                                                xc_line_idx).tax_date,
                                                                            SYSDATE))--and lines.line_id = lt_oe_lines_data(xc_line_idx).line_id
                                                                                     ;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_1206_tax_rate   := NULL;
                                --  l_1206_tax_code1 := null;

                                END;

                                ln_tax_rate_exists   := 0;

                                BEGIN
                                    IF l_1206_tax_rate IS NOT NULL
                                    THEN
                                        SELECT 1
                                          INTO ln_tax_rate_exists
                                          FROM apps.zx_rates_b
                                         WHERE     tax_rate_code =
                                                   l_1206_tax_code1 -- lt_oe_lines_data(xc_line_idx).TAX_CODE
                                               AND PERCENTAGE_RATE =
                                                   l_1206_tax_rate;
                                    END IF;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_tax_rate_exists   := 0;
                                END;

                                IF ln_tax_rate_exists = 1
                                THEN
                                    l_new_rate_code   := l_1206_tax_code1; -- lt_oe_lines_data(xc_line_idx).TAX_CODE;
                                ELSIF l_1206_tax_rate IS NULL
                                THEN
                                    l_new_rate_code   :=
                                        lt_oe_lines_data (xc_line_idx).TAX_CODE;
                                ELSE
                                    lc_oe_line_valid_data   := gc_no_flag; --jerry modify 19-may
                                    --                              lc_oe_header_valid_data := gc_no_flag;
                                    lc_error_message        :=
                                           'Tax Code not set up '
                                        || lt_oe_lines_data (xc_line_idx).TAX_CODE;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       lc_error_message); --jerry
                                    xxd_common_utils.record_error (
                                        p_module       => 'ONT',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers Ecomm Closed Sales Order Conversion Program',
                                        p_error_line   => SQLCODE,
                                        p_error_msg    => lc_error_message,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   =>
                                            lt_oe_header_data (xc_header_idx).order_number,
                                        p_more_info2   =>
                                            lt_oe_lines_data (xc_line_idx).line_number,
                                        p_more_info3   => 'TAX_CODE ',
                                        p_more_info4   =>
                                            lt_oe_lines_data (xc_line_idx).TAX_CODE);
                                END IF;
                            END IF;


                            -- lines attribute4 update
                            IF lt_oe_lines_data (xc_line_idx).attribute4
                                   IS NOT NULL
                            THEN
                                BEGIN
                                    SELECT DISTINCT pvsa.vendor_site_id
                                      INTO l_new_attribute4
                                      FROM ap_supplier_sites_all pvsa, ap_suppliers@BT_READ_1206.US.ORACLE.COM pv, ap_supplier_sites_all@BT_READ_1206.US.ORACLE.COM pvsa1206,
                                           ap_suppliers pv1223
                                     WHERE     pvsa.attribute5 =
                                               pv.attribute1
                                           --  and oel.attribute4 is not null
                                           AND pv.vendor_id =
                                               lt_oe_lines_data (xc_line_idx).attribute4
                                           AND pvsa.ORG_ID =
                                               (SELECT ORGANIZATION_ID
                                                  FROM APPS.HR_ALL_ORGANIZATION_UNITS
                                                 WHERE NAME = 'Deckers US OU')
                                           AND pvsa1206.vendor_site_code =
                                               pvsa.vendor_site_code
                                           AND pvsa1206.vendor_id =
                                               pv.vendor_id
                                           AND pvsa1206.vendor_id =
                                               lt_oe_lines_data (xc_line_idx).attribute4
                                           AND pv1223.vendor_id =
                                               pvsa.vendor_id
                                           AND pv1223.segment1 = pv.segment1;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_new_attribute4   := NULL;
                                END;
                            ELSE
                                l_new_attribute4   := NULL;
                            END IF;



                            l_duplicate_num            := 0;
                            l_new_line_num             := 0;

                            ------    Duplicate line validation

                            BEGIN
                                SELECT COUNT (*)
                                  INTO l_duplicate_num
                                  FROM xxd_ont_open_so_lines_stg_t
                                 WHERE     line_number =
                                           lt_oe_lines_data (xc_line_idx).line_number
                                       AND header_id =
                                           lt_oe_lines_data (xc_line_idx).header_id;

                                -- log_records(gc_debug_flag,'l_duplicate_num ' || l_duplicate_num);
                                --   log_records(gc_debug_flag,'lt_oe_lines_data(xc_line_idx).line_number ' ||lt_oe_lines_data(xc_line_idx)
                                --      .line_number);

                                -- log_records(gc_debug_flag,'t_oe_lines_data(xc_line_idx).header_id ' ||lt_oe_lines_data(xc_line_idx)
                                --        .header_id);
                                IF l_duplicate_num > 1
                                THEN
                                    SELECT MAX (line_number) + 1
                                      INTO l_new_line_num
                                      FROM xxd_ont_open_so_lines_stg_t
                                     WHERE header_id =
                                           lt_oe_lines_data (xc_line_idx).header_id;

                                    --log_records(gc_debug_flag,'l_new_line_num' ||l_new_line_num);

                                    UPDATE xxd_ont_open_so_lines_stg_t
                                       SET line_number   = l_new_line_num
                                     WHERE line_id =
                                           lt_oe_lines_data (xc_line_idx).line_id;
                                --log_records(gc_debug_flag,'After Update');

                                END IF;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_oe_line_valid_data   := gc_no_flag;
                                    lc_error_message        :=
                                        'Duplicate Line Number';
                                    xxd_common_utils.record_error (
                                        p_module       => 'ONT',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers Closed EcommSales Order Conversion Program',
                                        p_error_line   => SQLCODE,
                                        p_error_msg    => lc_error_message,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   =>
                                            lt_oe_header_data (xc_header_idx).order_number,
                                        p_more_info2   =>
                                            lt_oe_lines_data (xc_line_idx).line_number,
                                        p_more_info3   => 'LINE_NUMBER',
                                        p_more_info4   =>
                                            lt_oe_lines_data (xc_line_idx).line_number);
                                WHEN OTHERS
                                THEN
                                    lc_oe_line_valid_data   := gc_no_flag;
                                    lc_error_message        :=
                                        'Duplicate Line Number';
                                    xxd_common_utils.record_error (
                                        p_module       => 'ONT',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers Closed Ecomm Sales Order Conversion Program',
                                        p_error_line   => SQLCODE,
                                        p_error_msg    => lc_error_message,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   =>
                                            lt_oe_header_data (xc_header_idx).order_number,
                                        p_more_info2   =>
                                            lt_oe_lines_data (xc_line_idx).line_number,
                                        p_more_info3   => 'LINE_NUMBER',
                                        p_more_info4   =>
                                            lt_oe_lines_data (xc_line_idx).line_number);
                            END;

                            /*  BEGIN
                               SELECT NEW_SHIP_METHOD_CODE
                                 INTO ln_new_ship_method_line
                                 FROM XXD_1206_SHIP_METHODS_MAP_T
                                WHERE OLD_SHIP_METHOD_CODE =
                                         lt_oe_lines_data (xc_line_idx).SHIPPING_METHOD_CODE;
                            EXCEPTION
                               WHEN NO_DATA_FOUND
                               THEN
                                  --                              lc_oe_header_valid_data := gc_no_flag;
                                  ln_new_ship_method_line := NULL;
                               WHEN OTHERS
                               THEN
                                  --                              lc_oe_header_valid_data := gc_no_flag;
                                  ln_new_ship_method_line := NULL;
                            END;*/

                            -- Added for return order processing

                            IF lt_oe_lines_data (xc_line_idx).line_category_code =
                               'RETURN'
                            THEN
                                BEGIN
                                      SELECT header_id, line_id
                                        INTO ln_new_ret_header_id, ln_new_ret_line_id
                                        FROM oe_order_lines_all
                                       WHERE     orig_sys_document_ref =
                                                 lt_oe_lines_data (xc_line_idx).ret_org_sys_doc_ref
                                             AND orig_sys_line_ref =
                                                 lt_oe_lines_data (xc_line_idx).ret_org_sys_line_ref
                                    GROUP BY header_id, line_id;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        ln_new_ret_header_id   := NULL;
                                        ln_new_ret_line_id     := NULL;
                                /*lc_oe_line_valid_data := gc_no_flag;
                                lc_error_message  := 'Order for the return order is not available in the System';
                                xxd_common_utils.record_error (
                                                                 p_module       => 'ONT',
                                                                 p_org_id       => gn_org_id,
                                                                 p_program      => 'Deckers Ecomm Closed Sales Order Conversion Program',
                                                                 p_error_line   => SQLCODE,
                                                                 p_error_msg    => lc_error_message,
                                                                 p_created_by   => gn_user_id,
                                                                 p_request_id   => gn_conc_request_id,
                                                                 p_more_info1   => lt_oe_header_data(xc_header_idx).order_number,
                                                                 p_more_info2   => lt_oe_lines_data(xc_line_idx).line_number,
                                                                 p_more_info3   => 'The Order line reference number',
                                                                 p_more_info4   => lt_oe_lines_data(xc_line_idx).ret_org_sys_line_ref  );*/
                                END;
                            ELSE
                                ln_new_ret_header_id   := NULL;
                                ln_new_ret_line_id     := NULL;
                            END IF;

                            IF    lc_oe_line_valid_data = gc_no_flag
                               OR lc_oe_header_valid_data = gc_no_flag
                            THEN
                                UPDATE xxd_ont_open_so_lines_stg_t
                                   SET record_status = gc_error_status, new_line_type_id = ln_new_line_type_id, inventory_item_id = ln_inventory_item_id,
                                       new_ship_from = ln_line_ship_from_org_id, new_ship_to_site = ln_line_ship_to_site_id, new_ship_method_code = ln_new_ship_method_line,
                                       new_reference_header_id = ln_new_ret_header_id, new_reference_line_id = ln_new_ret_line_id, new_tax_code = l_new_rate_code, --ln_tax_code,
                                       tax_rate = l_1206_tax_rate, NEW_ATTRIBUTE4 = l_new_attribute4, tax_code = l_1206_tax_code1
                                 WHERE record_id =
                                       lt_oe_lines_data (xc_line_idx).record_id;

                                lc_oe_header_valid_data   := gc_no_flag;
                            ELSE
                                UPDATE xxd_ont_open_so_lines_stg_t
                                   SET record_status = gc_validate_status, new_line_type_id = ln_new_line_type_id, inventory_item_id = ln_inventory_item_id,
                                       new_ship_from = ln_line_ship_from_org_id, new_ship_to_site = ln_line_ship_to_site_id, new_ship_method_code = ln_new_ship_method_line,
                                       new_reference_header_id = ln_new_ret_header_id, new_reference_line_id = ln_new_ret_line_id, new_tax_code = l_new_rate_code, --ln_tax_code,
                                       tax_rate = l_1206_tax_rate, NEW_ATTRIBUTE4 = l_new_attribute4, tax_code = l_1206_tax_code1
                                 WHERE record_id =
                                       lt_oe_lines_data (xc_line_idx).record_id;
                            END IF;
                        END LOOP;
                    END IF;

                    --Price adjustments line validations

                    OPEN cur_oe_price_adj_lines (
                        p_header_id   =>
                            lt_oe_header_data (xc_header_idx).header_id);

                    FETCH cur_oe_price_adj_lines
                        BULK COLLECT INTO lt_oe_price_adj_lines_data;

                    CLOSE cur_oe_price_adj_lines;

                    log_records (
                        gc_debug_flag,
                           'validate Price Lines Adjustments '
                        || lt_oe_price_adj_lines_data.COUNT);

                    BEGIN
                        IF lt_oe_price_adj_lines_data.COUNT > 0
                        THEN
                            FOR xc_line_idx IN lt_oe_price_adj_lines_data.FIRST ..
                                               lt_oe_price_adj_lines_data.LAST
                            LOOP
                                ln_new_list_l_id        := NULL;
                                ln_new_list_h_id        := NULL;
                                ln_list_line_no         := NULL;
                                lc_oe_line_valid_data   := gc_yes_flag;
                                fnd_file.put_line (
                                    fnd_file.output,
                                       'record id being processed '
                                    || lt_oe_price_adj_lines_data (
                                           xc_line_idx).record_id);

                                BEGIN
                                    /* SELECT qph.list_header_id,qpl.list_line_id,qpl.LIST_LINE_NO
                                    into  ln_new_list_h_id,ln_new_list_l_id,ln_LIST_LINE_NO
                                         FROM qp_list_headers qph,
                                         qp_list_lines qpl
                                        WHERE     qph.list_header_id = qpl.list_header_id
                                        and qph.name =lt_oe_price_adj_lines_data(xc_header_idx).ADJUSTMENT_NAME
                                        and LIST_LINE_TYPE_CODE in( 'FREIGHT_CHARGE','DIS')
                                       and qpl.MODIFIER_LEVEL_CODE =lt_oe_price_adj_lines_data(xc_header_idx).MODIFIER_LEVEL_CODE ;*/

                                    IF lt_oe_price_adj_lines_data (
                                           xc_line_idx).list_line_type_code <>
                                       'FREIGHT_CHARGE'
                                    THEN
                                        SELECT qph.list_header_id, qpl.list_line_id, qpl.list_line_no
                                          INTO ln_new_list_h_id, ln_new_list_l_id, ln_list_line_no
                                          FROM qp_list_headers qph, qp_list_lines qpl
                                         WHERE     qph.list_header_id =
                                                   qpl.list_header_id
                                               AND qph.name =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).adjustment_name
                                               AND qpl.modifier_level_code =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).modifier_level_code
                                               --and LIST_LINE_TYPE_CODE = lt_oe_price_adj_lines_data(xc_header_idx).LIST_LINE_TYPE_CODE
                                               AND NVL (qpl.end_date_active,
                                                        TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE);
                                    -- AND LIST_LINE_NO LIKE 'DOEC%';
                                    ELSE
                                        SELECT qph.list_header_id, qpl.list_line_id, qpl.list_line_no
                                          INTO ln_new_list_h_id, ln_new_list_l_id, ln_list_line_no
                                          FROM qp_list_headers qph, qp_list_lines qpl
                                         WHERE     qph.list_header_id =
                                                   qpl.list_header_id
                                               AND qph.name =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).adjustment_name
                                               AND qpl.modifier_level_code =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).modifier_level_code
                                               --and LIST_LINE_TYPE_CODE = lt_oe_price_adj_lines_data(xc_header_idx).LIST_LINE_TYPE_CODE
                                               AND NVL (qpl.end_date_active,
                                                        TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND qpl.charge_type_code =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).charge_type_code;
                                    END IF;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                        lc_oe_line_valid_data   := gc_no_flag;
                                        lc_error_message        :=
                                            'List header id or line id not found is not available in the System';
                                        xxd_common_utils.record_error (
                                            p_module       => 'ONT',
                                            p_org_id       => gn_org_id,
                                            p_program      =>
                                                'Deckers Ecomm Closed Sales Order Conversion Program',
                                            p_error_line   => SQLCODE,
                                            p_error_msg    => lc_error_message,
                                            p_created_by   => gn_user_id,
                                            p_request_id   =>
                                                gn_conc_request_id,
                                            p_more_info1   =>
                                                lt_oe_header_data (
                                                    xc_header_idx).order_number,
                                            p_more_info2   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).line_number,
                                            p_more_info3   =>
                                                'ADJUSTMENT NAME',
                                            p_more_info4   =>
                                                lt_oe_price_adj_lines_data (
                                                    xc_header_idx).adjustment_name);
                                        ln_new_list_l_id        := -1;
                                        ln_new_list_h_id        := -1;
                                    WHEN OTHERS
                                    THEN
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                        lc_oe_line_valid_data   := gc_no_flag;
                                        lc_error_message        :=
                                            'List header id or line id more than one present';
                                        xxd_common_utils.record_error (
                                            p_module       => 'ONT',
                                            p_org_id       => gn_org_id,
                                            p_program      =>
                                                'Deckers Ecomm Closed Sales Order Conversion Program',
                                            p_error_line   => SQLCODE,
                                            p_error_msg    => lc_error_message,
                                            p_created_by   => gn_user_id,
                                            p_request_id   =>
                                                gn_conc_request_id,
                                            p_more_info1   =>
                                                lt_oe_header_data (
                                                    xc_header_idx).order_number,
                                            p_more_info2   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).line_number,
                                            p_more_info3   =>
                                                'ADJUSTMENT NAME',
                                            p_more_info4   =>
                                                lt_oe_price_adj_lines_data (
                                                    xc_header_idx).adjustment_name);
                                        ln_new_list_l_id        := -1;
                                        ln_new_list_h_id        := -1;
                                END;

                                BEGIN
                                    IF    lc_oe_line_valid_data = gc_no_flag
                                       OR lc_oe_header_valid_data =
                                          gc_no_flag
                                    THEN
                                        UPDATE xxd_ont_open_price_adj_l_stg_t
                                           SET record_status = gc_error_status, new_list_header_id = ln_new_list_h_id, new_list_line_id = ln_new_list_l_id,
                                               new_list_line_no = ln_list_line_no
                                         WHERE record_id =
                                               lt_oe_price_adj_lines_data (
                                                   xc_line_idx).record_id;

                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                    ELSE
                                        UPDATE xxd_ont_open_price_adj_l_stg_t
                                           SET record_status = gc_validate_status, new_list_header_id = ln_new_list_h_id, new_list_line_id = ln_new_list_l_id,
                                               new_list_line_no = ln_list_line_no
                                         WHERE record_id =
                                               lt_oe_price_adj_lines_data (
                                                   xc_line_idx).record_id;
                                    END IF;
                                --commit;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.output,
                                               'Error during price adj stage table update'
                                            || SQLERRM);
                                END;
                            END LOOP;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.output,
                                   'Error during price adj stage table update'
                                || SQLERRM);
                    END;

                    IF lc_oe_header_valid_data = gc_no_flag
                    THEN
                        UPDATE xxd_ont_open_so_head_stg_t
                           SET record_status = gc_error_status, new_customer_id = ln_new_customer_id, new_sold_to_org_id = ln_new_sold_to_org_id,
                               new_ship_to_site_id = ln_new_ship_to_site_id, new_bill_to_site_id = ln_new_bill_to_site_id, new_ship_from_org_id = ln_ship_from_org_id,
                               new_pay_term_id = ln_new_pay_term_id, new_salesrep_id = ln_new_salesrep_id, new_pricelist_id = ln_new_pricelist_id,
                               new_sales_channel_code = lc_new_sales_channel_code, new_order_source_id = ln_new_source_id, new_order_type_id = ln_new_order_type_id,
                               new_org_id = ln_new_org_id, freight_terms_code = lt_oe_header_data (xc_header_idx).freight_terms_code --jerry modify
                         --   new_ship_method_code = ln_new_ship_method
                         WHERE record_id =
                               lt_oe_header_data (xc_header_idx).record_id;
                    ELSE
                        UPDATE xxd_ont_open_so_head_stg_t
                           SET record_status = gc_validate_status, new_customer_id = ln_new_customer_id, new_sold_to_org_id = ln_new_sold_to_org_id,
                               new_ship_to_site_id = ln_new_ship_to_site_id, new_bill_to_site_id = ln_new_bill_to_site_id, new_ship_from_org_id = ln_ship_from_org_id,
                               new_pay_term_id = ln_new_pay_term_id, new_salesrep_id = ln_new_salesrep_id, new_pricelist_id = ln_new_pricelist_id,
                               new_sales_channel_code = lc_new_sales_channel_code --jerry modify 11-may
                                                                                 , new_order_source_id = ln_new_source_id, new_order_type_id = ln_new_order_type_id,
                               new_org_id = ln_new_org_id, new_ship_method_code = ln_new_ship_method --jerry modify 11-may
                                                                                                    , freight_terms_code = lt_oe_header_data (xc_header_idx).freight_terms_code --jerry modify
                         --   new_ship_method_code = ln_new_ship_method
                         WHERE record_id =
                               lt_oe_header_data (xc_header_idx).record_id;
                    END IF;
                END LOOP;                                         -- qp_header
            END IF;

            COMMIT;
        END LOOP;

        CLOSE cur_oe_header;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
            ROLLBACK;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.output,
                'Exception Raised During Order Header Validation Program');
            ROLLBACK;
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
    END sales_order_validation;

    PROCEDURE extract_1206_data (p_customer_type    IN     VARCHAR2,
                                 p_org_name         IN     VARCHAR2,
                                 p_org_type         IN     VARCHAR2,
                                 p_order_ret_type   IN     VARCHAR2,
                                 x_total_rec           OUT NUMBER,
                                 x_validrec_cnt        OUT NUMBER,
                                 x_errbuf              OUT VARCHAR2,
                                 x_retcode             OUT NUMBER)
    IS
        procedure_name     CONSTANT VARCHAR2 (30) := 'EXTRACT_R12';
        lv_error_stage              VARCHAR2 (32767) := NULL;
        ln_record_count             NUMBER := 0;
        lv_string                   LONG;

        CURSOR lcu_ecomm_orders (ln_org_id NUMBER)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ont_open_so_headers_conv_v xoeh
             WHERE     creation_date > TO_DATE ('12/31/2014', 'mm/dd/yyyy')
                   --sysdate - /*365*/90 --jerry modify 11-may
                   --need the following condition to fetch ecomm orders only since we donot have order type as mandatory
                   AND EXISTS
                           (SELECT 1
                              FROM hz_cust_accounts_all
                             WHERE     cust_account_id = xoeh.sold_to_org_id
                                   AND attribute18 IS NOT NULL)
                   AND org_id = ln_org_id
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_1206_order_type_map_t xom
                             WHERE     xoeh.order_type =
                                       xom.legacy_12_0_6_name
                                   AND new_12_2_3_name =
                                       NVL (p_org_type, new_12_2_3_name)
                                   AND order_category = p_order_ret_type)
                   --jerry modify 16-may
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_1206_oe_order_lines_all oel
                             WHERE     oel.header_id = xoeh.header_id
                                   AND oel.flow_status_code IN
                                           ('AWAITING_RETURN', 'AWAITING_SHIPPING', 'BOOKED',
                                            'CANCELLED', 'CLOSED', 'INVOICED'));

        CURSOR lcu_nonecomm_orders (ln_org_id NUMBER)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ont_open_so_headers_conv_v xoeh
             WHERE     creation_date > SYSDATE - 365
                   AND EXISTS
                           (SELECT 1
                              FROM hz_cust_accounts_all
                             WHERE     cust_account_id = xoeh.sold_to_org_id
                                   AND attribute18 IS NULL)
                   AND org_id = ln_org_id
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_1206_order_type_map_t xom
                             WHERE     xoeh.order_type =
                                       xom.legacy_12_0_6_name
                                   AND new_12_2_3_name =
                                       NVL (p_org_type, new_12_2_3_name)
                                   AND order_category = p_order_ret_type);

        CURSOR lcu_order_lines (ln_org_id NUMBER)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   oel.line_id,
                   oel.header_id,
                   oel.line_number,
                   oel.order_quantity_uom,
                   oel.ordered_quantity,
                   oel.shipped_quantity,
                   oel.cancelled_quantity,
                   oel.fulfilled_quantity,
                   oel.inventory_item_id inventory_item,
                   oel.ordered_item item_segment1,
                   NULL item_segment2,
                   NULL item_segment3,
                   oel.unit_selling_price,
                   oel.unit_list_price,
                   oel.tax_date,
                   oel.tax_code,
                   oel.tax_rate,
                   oel.tax_value,
                   oel.tax_exempt_flag,
                   oel.tax_exempt_number,
                   oel.tax_exempt_reason_code,
                   oel.tax_point_code,
                   oel.shipping_method_code,
                   oel.customer_line_number,
                   oel.invoice_to_org_id,
                   oel.ship_to_org_id,
                   oel.ship_from_org_id,
                   oel.promise_date,
                   oel.orig_sys_document_ref,
                   oel.orig_sys_line_ref,
                   oel.schedule_ship_date,
                   oel.pricing_date,
                   NULL order_source,
                   oel.attribute1,
                   oel.attribute2,
                   oel.attribute3,
                   oel.attribute4,
                   oel.attribute5,
                   oel.attribute6,
                   oel.attribute7,
                   oel.attribute8,
                   oel.attribute9,
                   oel.attribute10,
                   oel.attribute11,
                   oel.attribute12,
                   oel.attribute13,
                   oel.attribute14,
                   oel.attribute15,
                   oel.attribute16,
                   oel.attribute17,
                   oel.attribute18,
                   oel.attribute19,
                   oel.attribute20,
                   oel.org_id,
                   (SELECT DISTINCT ottt.name
                      FROM oe_transaction_types_tl@BT_READ_1206 ottt
                     WHERE     ottt.transaction_type_id = oel.line_type_id
                           AND ottt.language = 'US') line_type,
                   --  oel.line_type_id,
                   oel.cust_po_number,
                   oel.ship_tolerance_above,
                   oel.ship_tolerance_below,
                   oel.fob_point_code,
                   oel.item_type_code,
                   oel.line_category_code,
                   oel.source_type_code,
                   oel.return_reason_code,
                   oel.open_flag,
                   oel.booked_flag,
                   oel.ship_from_org_id,
                   oel.flow_status_code,
                   oel.shipment_priority_code,
                   -- null      reference_header_id,null reference_line_id
                   oel.reference_header_id,
                   oel.reference_line_id,
                   --   '9009208925'     ret_org_sys_doc_ref,'9009208925-1' ret_org_sys_line_ref
                   (  SELECT TRIM (a.orig_sys_document_ref)
                        FROM xxd_1206_oe_order_lines_all a
                       WHERE     a.header_id =
                                 NVL (oel.reference_header_id, -1)
                             AND a.line_id = NVL (oel.reference_line_id, -1)
                    GROUP BY a.orig_sys_document_ref) ret_org_sys_doc_ref,
                   (  SELECT TRIM (a.orig_sys_line_ref)
                        FROM xxd_1206_oe_order_lines_all a
                       WHERE     a.header_id =
                                 NVL (oel.reference_header_id, -1)
                             AND a.line_id = NVL (oel.reference_line_id, -1)
                    GROUP BY a.orig_sys_line_ref) ret_org_sys_line_ref,
                   oel.latest_acceptable_date--Meenakshi 18-May
                                             ,
                   oel.return_context--Meenakshi 15-Jun
                                     ,
                   oel.actual_shipment_date,                --Meenakshi 1-Sept
                   oel.request_date,
                   oel.SHIPPING_INSTRUCTIONS,
                   oel.FULFILLMENT_DATE,
                   oel.schedule_arrival_date
              FROM xxd_1206_oe_order_lines_all oel
             --        SELECT
             --                /*+leading(XOEL,xsh) parallel(xsh) no_merge */ *
             --        FROM   XXD_ONT_SO_LINES_CONV_V   XOEL
             WHERE             --              FLOW_STATUS_CODE <> 'CANCELLED'
                       --jerry modify 15-may
                       oel.flow_status_code IN
                           ('AWAITING_RETURN', 'AWAITING_SHIPPING', 'BOOKED',
                            'CANCELLED', 'CLOSED', 'INVOICED')
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_ont_open_so_head_stg_t xsh
                             WHERE     oel.header_id = xsh.header_id
                                   AND record_status = gc_new_status
                                   AND org_id = ln_org_id);

        CURSOR lcu_price_adj_lines (ln_org_id NUMBER)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_open_so_oe_price_adjust_v oel
             WHERE EXISTS
                       (SELECT 1
                          FROM xxd_ont_open_so_head_stg_t xsh
                         WHERE     oel.header_id = xsh.header_id
                               AND record_status = gc_new_status
                               AND org_id = ln_org_id);

        TYPE xxd_ont_order_header_tab
            IS TABLE OF xxd_ont_open_so_headers_conv_v%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ont_order_header_tab      xxd_ont_order_header_tab;

        TYPE xxd_ont_order_lines_tab
            IS TABLE OF xxd_ont_open_so_lines_v%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ont_order_lines_tab       xxd_ont_order_lines_tab;

        TYPE xxd_ont_price_adj_lines_tab
            IS TABLE OF xxd_open_so_oe_price_adjust_v%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ont_price_adj_lines_tab   xxd_ont_price_adj_lines_tab;
    BEGIN
        t_ont_order_header_tab.delete;
        gtt_ont_order_lines_tab.delete;
        lv_error_stage   :=
               'Inserting Order_headers  Data p_customer_type =>'
            || p_customer_type;
        fnd_file.put_line (fnd_file.LOG, lv_error_stage);

        IF p_customer_type = 'eComm'
        THEN
            FOR lc_org
                IN (SELECT lookup_code
                      FROM apps.fnd_lookup_values
                     WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                           AND attribute1 = p_org_name
                           AND language = 'US')
            LOOP
                OPEN lcu_ecomm_orders (TO_NUMBER (lc_org.lookup_code));

                LOOP
                    lv_error_stage   := 'Inserting Order_headers  Data';
                    --                    fnd_file.put_line(fnd_file.log,lv_error_stage);
                    t_ont_order_header_tab.delete;

                    FETCH lcu_ecomm_orders
                        BULK COLLECT INTO t_ont_order_header_tab
                        LIMIT 500;

                    FORALL l_indx IN 1 .. t_ont_order_header_tab.COUNT
                        INSERT INTO xxd_ont_open_so_head_stg_t (
                                        record_id,
                                        record_status,
                                        header_id,
                                        org_id,
                                        order_source,
                                        order_type,
                                        ordered_date,
                                        booked_flag,
                                        flow_status_code,
                                        shipment_priority_code,
                                        demand_class_code,
                                        tax_exempt_number,
                                        tax_exempt_reason_code,
                                        transactional_curr_code,
                                        customer_id,            --customer_id,
                                        --                                                 customer_name ,-- customer_name,
                                        --                                                 customer_number,--customer_number,
                                        cust_po_number,
                                        fob_point_code,
                                        freight_terms_code,
                                        freight_carrier_code,
                                        packing_instructions,
                                        request_date,
                                        shipping_instructions,
                                        shipping_method_code,
                                        price_list,
                                        pricing_date,
                                        attribute1,
                                        attribute2,
                                        attribute3,
                                        attribute4,
                                        attribute5,
                                        attribute6,
                                        attribute7,
                                        attribute8,
                                        attribute9,
                                        attribute10,
                                        attribute11,
                                        attribute12,
                                        attribute13,
                                        attribute14,
                                        attribute15,
                                        tax_exempt_flag,
                                        sales_channel_code,
                                        sales_repname,
                                        payment_term_name,
                                        bill_to_org_id,
                                        ship_to_org_id,
                                        ship_from_org_id,
                                        order_number,
                                        original_system_reference,
                                        created_by,
                                        creation_date,
                                        last_updated_by,
                                        last_update_date,
                                        request_id,
                                        customer_type,
                                        booked_date)
                                 VALUES (
                                            xxd_ont_so_header_conv_stg_s.NEXTVAL,
                                            'N',
                                            t_ont_order_header_tab (l_indx).header_id,
                                            t_ont_order_header_tab (l_indx).org_id,
                                            t_ont_order_header_tab (l_indx).order_source,
                                            t_ont_order_header_tab (l_indx).order_type,
                                            t_ont_order_header_tab (l_indx).ordered_date,
                                            t_ont_order_header_tab (l_indx).booked_flag,
                                            t_ont_order_header_tab (l_indx).flow_status_code,
                                            t_ont_order_header_tab (l_indx).shipment_priority_code,
                                            t_ont_order_header_tab (l_indx).demand_class_code,
                                            t_ont_order_header_tab (l_indx).tax_exempt_number,
                                            t_ont_order_header_tab (l_indx).tax_exempt_reason_code,
                                            t_ont_order_header_tab (l_indx).transactional_curr_code,
                                            t_ont_order_header_tab (l_indx).sold_to_org_id,
                                            --                       t_ont_order_header_tab (l_indx).customer_name,
                                            --                       t_ont_order_header_tab (l_indx).customer_number,
                                            t_ont_order_header_tab (l_indx).cust_po_number,
                                            t_ont_order_header_tab (l_indx).fob_point_code,
                                            t_ont_order_header_tab (l_indx).freight_terms_code,
                                            t_ont_order_header_tab (l_indx).freight_carrier_code,
                                            t_ont_order_header_tab (l_indx).packing_instructions,
                                            t_ont_order_header_tab (l_indx).request_date,
                                            t_ont_order_header_tab (l_indx).shipping_instructions,
                                            t_ont_order_header_tab (l_indx).shipping_method_code,
                                            t_ont_order_header_tab (l_indx).price_list,
                                            t_ont_order_header_tab (l_indx).pricing_date,
                                            t_ont_order_header_tab (l_indx).attribute1,
                                            t_ont_order_header_tab (l_indx).attribute2,
                                            t_ont_order_header_tab (l_indx).attribute3,
                                            t_ont_order_header_tab (l_indx).attribute4,
                                            t_ont_order_header_tab (l_indx).attribute5,
                                            t_ont_order_header_tab (l_indx).attribute6,
                                            t_ont_order_header_tab (l_indx).attribute7,
                                            t_ont_order_header_tab (l_indx).attribute8,
                                            t_ont_order_header_tab (l_indx).attribute9,
                                            t_ont_order_header_tab (l_indx).attribute10,
                                            t_ont_order_header_tab (l_indx).attribute11,
                                            t_ont_order_header_tab (l_indx).attribute12,
                                            t_ont_order_header_tab (l_indx).attribute13,
                                            t_ont_order_header_tab (l_indx).attribute14,
                                            t_ont_order_header_tab (l_indx).attribute15,
                                            t_ont_order_header_tab (l_indx).tax_exempt_flag,
                                            t_ont_order_header_tab (l_indx).sales_channel_code,
                                            t_ont_order_header_tab (l_indx).sales_repname,
                                            t_ont_order_header_tab (l_indx).payment_term_name,
                                            t_ont_order_header_tab (l_indx).invoice_to_org_id,
                                            t_ont_order_header_tab (l_indx).ship_to_org_id,
                                            t_ont_order_header_tab (l_indx).ship_from_org_id,
                                            t_ont_order_header_tab (l_indx).order_number,
                                            t_ont_order_header_tab (l_indx).orig_sys_document_ref,
                                            gn_user_id,
                                            SYSDATE,
                                            gn_user_id,
                                            SYSDATE,
                                            gn_conc_request_id,
                                            'ECOMM',
                                            t_ont_order_header_tab (l_indx).booked_date);

                    COMMIT;
                    EXIT WHEN lcu_ecomm_orders%NOTFOUND;
                END LOOP;

                CLOSE lcu_ecomm_orders;
            END LOOP;
        ELSIF p_customer_type = 'Wholesale' OR p_customer_type = 'RMS'
        THEN
            lv_error_stage   := 'IF p_customer_type =>' || p_customer_type;
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);

            FOR lc_org
                IN (SELECT lookup_code
                      FROM apps.fnd_lookup_values
                     WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                           AND attribute1 = p_org_name
                           AND language = 'US')
            LOOP
                lv_error_stage   :=
                       'LOOP to_number(lc_org.lookup_code) =>'
                    || TO_NUMBER (lc_org.lookup_code);
                fnd_file.put_line (fnd_file.LOG, lv_error_stage);

                OPEN lcu_nonecomm_orders (TO_NUMBER (lc_org.lookup_code));

                LOOP
                    lv_error_stage   := 'Inserting Order_headers Data';
                    fnd_file.put_line (fnd_file.LOG, lv_error_stage);
                    t_ont_order_header_tab.delete;

                    FETCH lcu_nonecomm_orders
                        BULK COLLECT INTO t_ont_order_header_tab
                        LIMIT 500;

                    FORALL l_indx IN 1 .. t_ont_order_header_tab.COUNT
                        INSERT INTO xxd_ont_open_so_head_stg_t (
                                        record_id,
                                        record_status,
                                        header_id,
                                        org_id,
                                        order_source,
                                        order_type,
                                        ordered_date,
                                        booked_flag,
                                        flow_status_code,
                                        shipment_priority_code,
                                        demand_class_code,
                                        tax_exempt_number,
                                        tax_exempt_reason_code,
                                        transactional_curr_code,
                                        customer_id,            --customer_id,
                                        --                                                 customer_name ,-- customer_name,
                                        --                                                 customer_number,--customer_number,
                                        cust_po_number,
                                        fob_point_code,
                                        freight_terms_code,
                                        freight_carrier_code,
                                        packing_instructions,
                                        request_date,
                                        shipping_instructions,
                                        shipping_method_code,
                                        price_list,
                                        pricing_date,
                                        attribute1,
                                        attribute2,
                                        attribute3,
                                        attribute4,
                                        attribute5,
                                        attribute6,
                                        attribute7,
                                        attribute8,
                                        attribute9,
                                        attribute10,
                                        attribute11,
                                        attribute12,
                                        attribute13,
                                        attribute14,
                                        attribute15,
                                        tax_exempt_flag,
                                        sales_channel_code,
                                        sales_repname,
                                        payment_term_name,
                                        bill_to_org_id,
                                        ship_to_org_id,
                                        ship_from_org_id,
                                        order_number,
                                        original_system_reference,
                                        created_by,
                                        creation_date,
                                        last_updated_by,
                                        last_update_date,
                                        request_id,
                                        customer_type,
                                        booked_date)
                                 VALUES (
                                            xxd_ont_so_header_conv_stg_s.NEXTVAL,
                                            'N',
                                            t_ont_order_header_tab (l_indx).header_id,
                                            t_ont_order_header_tab (l_indx).org_id,
                                            t_ont_order_header_tab (l_indx).order_source,
                                            t_ont_order_header_tab (l_indx).order_type,
                                            t_ont_order_header_tab (l_indx).ordered_date,
                                            t_ont_order_header_tab (l_indx).booked_flag,
                                            t_ont_order_header_tab (l_indx).flow_status_code,
                                            t_ont_order_header_tab (l_indx).shipment_priority_code,
                                            t_ont_order_header_tab (l_indx).demand_class_code,
                                            t_ont_order_header_tab (l_indx).tax_exempt_number,
                                            t_ont_order_header_tab (l_indx).tax_exempt_reason_code,
                                            t_ont_order_header_tab (l_indx).transactional_curr_code,
                                            t_ont_order_header_tab (l_indx).sold_to_org_id,
                                            --                       t_ont_order_header_tab (l_indx).customer_name,
                                            --                       t_ont_order_header_tab (l_indx).customer_number,
                                            t_ont_order_header_tab (l_indx).cust_po_number,
                                            t_ont_order_header_tab (l_indx).fob_point_code,
                                            t_ont_order_header_tab (l_indx).freight_terms_code,
                                            t_ont_order_header_tab (l_indx).freight_carrier_code,
                                            t_ont_order_header_tab (l_indx).packing_instructions,
                                            t_ont_order_header_tab (l_indx).request_date,
                                            t_ont_order_header_tab (l_indx).shipping_instructions,
                                            t_ont_order_header_tab (l_indx).shipping_method_code,
                                            t_ont_order_header_tab (l_indx).price_list,
                                            t_ont_order_header_tab (l_indx).pricing_date,
                                            t_ont_order_header_tab (l_indx).attribute1,
                                            t_ont_order_header_tab (l_indx).attribute2,
                                            t_ont_order_header_tab (l_indx).attribute3,
                                            t_ont_order_header_tab (l_indx).attribute4,
                                            t_ont_order_header_tab (l_indx).attribute5,
                                            t_ont_order_header_tab (l_indx).attribute6,
                                            t_ont_order_header_tab (l_indx).attribute7,
                                            t_ont_order_header_tab (l_indx).attribute8,
                                            t_ont_order_header_tab (l_indx).attribute9,
                                            t_ont_order_header_tab (l_indx).attribute10,
                                            t_ont_order_header_tab (l_indx).attribute11,
                                            t_ont_order_header_tab (l_indx).attribute12,
                                            t_ont_order_header_tab (l_indx).attribute13,
                                            t_ont_order_header_tab (l_indx).attribute14,
                                            t_ont_order_header_tab (l_indx).attribute15,
                                            t_ont_order_header_tab (l_indx).tax_exempt_flag,
                                            t_ont_order_header_tab (l_indx).sales_channel_code,
                                            t_ont_order_header_tab (l_indx).sales_repname,
                                            t_ont_order_header_tab (l_indx).payment_term_name,
                                            t_ont_order_header_tab (l_indx).invoice_to_org_id,
                                            t_ont_order_header_tab (l_indx).ship_to_org_id,
                                            t_ont_order_header_tab (l_indx).ship_from_org_id,
                                            t_ont_order_header_tab (l_indx).order_number,
                                            t_ont_order_header_tab (l_indx).orig_sys_document_ref,
                                            gn_user_id,
                                            SYSDATE,
                                            gn_user_id,
                                            SYSDATE,
                                            gn_conc_request_id,
                                            UPPER (p_customer_type),
                                            t_ont_order_header_tab (l_indx).booked_date);

                    COMMIT;
                    EXIT WHEN lcu_nonecomm_orders%NOTFOUND;
                END LOOP;

                CLOSE lcu_nonecomm_orders;
            END LOOP;
        END IF;

        FOR lc_org
            IN (SELECT lookup_code
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                       AND attribute1 = p_org_name
                       AND language = 'US')
        LOOP
            OPEN lcu_order_lines (TO_NUMBER (lc_org.lookup_code));

            LOOP
                lv_error_stage   := 'Inserting Order Lines Data';
                --                    fnd_file.put_line(fnd_file.log,lv_error_stage);
                gtt_ont_order_lines_tab.delete;

                FETCH lcu_order_lines
                    BULK COLLECT INTO t_ont_order_lines_tab
                    LIMIT 2000;

                FORALL l_indx IN 1 .. t_ont_order_lines_tab.COUNT
                    INSERT INTO xxd_ont_open_so_lines_stg_t (
                                    record_id,
                                    record_status,
                                    line_number,
                                    org_id,
                                    header_id,
                                    line_id,
                                    line_type,
                                    flow_status_code,
                                    item_segment1,
                                    item_segment2,
                                    item_segment3,
                                    promise_date,
                                    order_quantity_uom,
                                    ordered_quantity,
                                    cancelled_quantity,
                                    shipped_quantity,
                                    unit_selling_price,
                                    unit_list_price,
                                    tax_date,
                                    tax_code,
                                    tax_rate,
                                    tax_value,
                                    tax_exempt_flag,
                                    tax_exempt_number,
                                    tax_exempt_reason_code,
                                    tax_point_code,
                                    schedule_ship_date,
                                    pricing_date,
                                    shipping_method_code,
                                    customer_line_number,
                                    ship_tolerance_above,
                                    ship_tolerance_below,
                                    fob_point_code,
                                    item_type_code,
                                    line_category_code,
                                    source_type_code,
                                    open_flag,
                                    booked_flag,
                                    bill_to_org_id,
                                    ship_to_org_id,
                                    ship_from,
                                    orig_sys_document_ref,
                                    original_system_line_reference,
                                    attribute1,
                                    attribute2,
                                    attribute3,
                                    attribute4,
                                    attribute5,
                                    attribute6,
                                    attribute7,
                                    attribute8,
                                    attribute9,
                                    attribute10,
                                    attribute11,
                                    attribute12,
                                    attribute13,
                                    attribute14,
                                    attribute15,
                                    attribute16,
                                    attribute17,
                                    attribute18,
                                    attribute19,
                                    attribute20,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    request_id,
                                    shipment_priority_code,
                                    reference_header_id,
                                    reference_line_id,
                                    ret_org_sys_doc_ref,
                                    ret_org_sys_line_ref,
                                    return_reason_code,
                                    latest_acceptable_date,
                                    --Meenakshi 18-May
                                    return_context,
                                    --Meenakshi 15-Jun
                                    actual_shipment_date,
                                    old_inventory_item_id,
                                    request_date,
                                    SHIPPING_INSTRUCTIONS,
                                    FULFILLED_QUANTITY,
                                    FULFILLMENT_DATE,
                                    schedule_arrival_date)  --Meenakshi 8-Jul)
                             VALUES (
                                        xxd_ont_so_line_conv_stg_s.NEXTVAL,
                                        'N',
                                        t_ont_order_lines_tab (l_indx).line_number,
                                        t_ont_order_lines_tab (l_indx).org_id,
                                        t_ont_order_lines_tab (l_indx).header_id,
                                        t_ont_order_lines_tab (l_indx).line_id,
                                        t_ont_order_lines_tab (l_indx).line_type,
                                        t_ont_order_lines_tab (l_indx).flow_status_code,
                                        t_ont_order_lines_tab (l_indx).item_segment1,
                                        t_ont_order_lines_tab (l_indx).item_segment2,
                                        t_ont_order_lines_tab (l_indx).item_segment3,
                                        t_ont_order_lines_tab (l_indx).promise_date,
                                        t_ont_order_lines_tab (l_indx).order_quantity_uom,
                                        t_ont_order_lines_tab (l_indx).ordered_quantity,
                                        t_ont_order_lines_tab (l_indx).cancelled_quantity,
                                        t_ont_order_lines_tab (l_indx).shipped_quantity,
                                        t_ont_order_lines_tab (l_indx).unit_selling_price,
                                        t_ont_order_lines_tab (l_indx).unit_list_price,
                                        t_ont_order_lines_tab (l_indx).tax_date,
                                        t_ont_order_lines_tab (l_indx).tax_code,
                                        t_ont_order_lines_tab (l_indx).tax_rate,
                                        t_ont_order_lines_tab (l_indx).tax_value,
                                        t_ont_order_lines_tab (l_indx).tax_exempt_flag,
                                        t_ont_order_lines_tab (l_indx).tax_exempt_number,
                                        t_ont_order_lines_tab (l_indx).tax_exempt_reason_code,
                                        t_ont_order_lines_tab (l_indx).tax_point_code,
                                        t_ont_order_lines_tab (l_indx).schedule_ship_date,
                                        t_ont_order_lines_tab (l_indx).pricing_date,
                                        t_ont_order_lines_tab (l_indx).shipping_method_code,
                                        t_ont_order_lines_tab (l_indx).customer_line_number,
                                        t_ont_order_lines_tab (l_indx).ship_tolerance_above,
                                        t_ont_order_lines_tab (l_indx).ship_tolerance_below,
                                        t_ont_order_lines_tab (l_indx).fob_point_code,
                                        t_ont_order_lines_tab (l_indx).item_type_code,
                                        t_ont_order_lines_tab (l_indx).line_category_code,
                                        t_ont_order_lines_tab (l_indx).source_type_code,
                                        t_ont_order_lines_tab (l_indx).open_flag,
                                        t_ont_order_lines_tab (l_indx).booked_flag,
                                        t_ont_order_lines_tab (l_indx).bill_to_org_id,
                                        t_ont_order_lines_tab (l_indx).ship_to_org_id,
                                        t_ont_order_lines_tab (l_indx).ship_from,
                                        t_ont_order_lines_tab (l_indx).orig_sys_document_ref,
                                        t_ont_order_lines_tab (l_indx).orig_sys_line_ref,
                                        t_ont_order_lines_tab (l_indx).attribute1,
                                        t_ont_order_lines_tab (l_indx).attribute2,
                                        t_ont_order_lines_tab (l_indx).attribute3,
                                        t_ont_order_lines_tab (l_indx).attribute4,
                                        t_ont_order_lines_tab (l_indx).attribute5,
                                        t_ont_order_lines_tab (l_indx).attribute6,
                                        t_ont_order_lines_tab (l_indx).attribute7,
                                        t_ont_order_lines_tab (l_indx).attribute8,
                                        t_ont_order_lines_tab (l_indx).attribute9,
                                        t_ont_order_lines_tab (l_indx).attribute10,
                                        t_ont_order_lines_tab (l_indx).attribute11,
                                        t_ont_order_lines_tab (l_indx).attribute12,
                                        t_ont_order_lines_tab (l_indx).attribute13,
                                        t_ont_order_lines_tab (l_indx).attribute14,
                                        t_ont_order_lines_tab (l_indx).attribute15,
                                        t_ont_order_lines_tab (l_indx).attribute16,
                                        t_ont_order_lines_tab (l_indx).attribute17,
                                        t_ont_order_lines_tab (l_indx).attribute18,
                                        t_ont_order_lines_tab (l_indx).attribute19,
                                        t_ont_order_lines_tab (l_indx).attribute20,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_conc_request_id,
                                        t_ont_order_lines_tab (l_indx).shipment_priority_code,
                                        TO_NUMBER (
                                            t_ont_order_lines_tab (l_indx).reference_header_id),
                                        TO_NUMBER (
                                            t_ont_order_lines_tab (l_indx).reference_line_id),
                                        t_ont_order_lines_tab (l_indx).ret_org_sys_doc_ref,
                                        t_ont_order_lines_tab (l_indx).ret_org_sys_line_ref,
                                        t_ont_order_lines_tab (l_indx).return_reason_code,
                                        t_ont_order_lines_tab (l_indx).latest_acceptable_date,
                                        --Meenakshi 18-May
                                        t_ont_order_lines_tab (l_indx).return_context,
                                        --Meenakshi 15-Jun
                                        t_ont_order_lines_tab (l_indx).actual_shipment_date,
                                        t_ont_order_lines_tab (l_indx).inventory_item,
                                        t_ont_order_lines_tab (l_indx).request_date,
                                        t_ont_order_lines_tab (l_indx).SHIPPING_INSTRUCTIONS,
                                        t_ont_order_lines_tab (l_indx).FULFILLED_QUANTITY,
                                        t_ont_order_lines_tab (l_indx).FULFILLMENT_DATE,
                                        t_ont_order_lines_tab (l_indx).schedule_arrival_date); --Meenakshi 8-Jul

                COMMIT;
                EXIT WHEN lcu_order_lines%NOTFOUND;
            END LOOP;

            CLOSE lcu_order_lines;
        END LOOP;

        -- PRICE ADJUSTMENTS

        FOR lc_org
            IN (SELECT lookup_code
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                       AND attribute1 = p_org_name
                       AND language = 'US')
        LOOP
            OPEN lcu_price_adj_lines (TO_NUMBER (lc_org.lookup_code));

            LOOP
                lv_error_stage   := 'Inserting Price Adjustments Lines Data';
                --                    fnd_file.put_line(fnd_file.log,lv_error_stage);
                t_ont_price_adj_lines_tab.delete;

                FETCH lcu_price_adj_lines
                    BULK COLLECT INTO t_ont_price_adj_lines_tab
                    LIMIT 2000;

                FORALL l_indx IN 1 .. t_ont_price_adj_lines_tab.COUNT
                    INSERT INTO xxd_ont_open_price_adj_l_stg_t (
                                    record_id,
                                    record_status,
                                    --     V_ROWID                ,
                                    price_adjustment_id,
                                    program_application_id,
                                    program_id,
                                    program_update_date,
                                    header_id,
                                    discount_id,
                                    discount_line_id,
                                    automatic_flag,
                                    percent,
                                    line_id,
                                    context,
                                    attribute1,
                                    attribute2,
                                    attribute3,
                                    attribute4,
                                    attribute5,
                                    attribute6,
                                    attribute7,
                                    attribute8,
                                    attribute9,
                                    attribute10,
                                    attribute11,
                                    attribute12,
                                    attribute13,
                                    attribute14,
                                    attribute15,
                                    orig_sys_discount_ref,
                                    -- CHANGE_SEQUENCE         ,
                                    list_header_id,
                                    list_line_id,
                                    list_line_type_code,
                                    modifier_mechanism_type_code,
                                    modified_from,
                                    modified_to,
                                    update_allowed,
                                    updated_flag,
                                    applied_flag,
                                    change_reason_code,
                                    change_reason_text,
                                    adjustment_name,
                                    adjustment_type_code,
                                    override_allowed_flag,
                                    adjustment_type_name,
                                    operand,
                                    arithmetic_operator,
                                    cost_id,
                                    tax_code,
                                    tax_exempt_flag,
                                    tax_exempt_number,
                                    tax_exempt_reason_code,
                                    parent_adjustment_id,
                                    invoiced_flag,
                                    estimated_flag,
                                    inc_in_sales_performance,
                                    split_action_code,
                                    adjusted_amount,
                                    pricing_phase_id,
                                    charge_type_code,
                                    charge_subtype_code,
                                    range_break_quantity,
                                    accrual_conversion_rate,
                                    pricing_group_sequence,
                                    accrual_flag,
                                    list_line_no,
                                    source_system_code,
                                    benefit_qty,
                                    benefit_uom_code,
                                    print_on_invoice_flag,
                                    expiration_date,
                                    rebate_transaction_type_code,
                                    rebate_transaction_reference,
                                    rebate_payment_system_code,
                                    redeemed_date,
                                    redeemed_flag,
                                    modifier_level_code,
                                    price_break_type_code,
                                    substitution_attribute,
                                    proration_type_code,
                                    include_on_returns_flag,
                                    credit_or_charge_flag,
                                    adjustment_description,
                                    ac_context,
                                    ac_attribute1,
                                    ac_attribute2,
                                    ac_attribute3,
                                    ac_attribute4,
                                    ac_attribute5,
                                    ac_attribute6,
                                    ac_attribute7,
                                    ac_attribute8,
                                    ac_attribute9,
                                    ac_attribute10,
                                    ac_attribute11,
                                    ac_attribute12,
                                    ac_attribute13,
                                    ac_attribute14,
                                    ac_attribute15,
                                    lock_control,
                                    operand_per_pqty,
                                    adjusted_amount_per_pqty,
                                    -- INTERCO_INVOICED_FLAG         ,
                                    invoiced_amount,
                                    retrobill_request_id,
                                    tax_rate_id,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    request_id,
                                    orig_sys_line_ref,
                                    orig_sys_header_ref)
                             VALUES (
                                        xxd_ont_so_pri_adj_conv_stg_s.NEXTVAL,
                                        'N',
                                        --     t_ont_price_adj_lines_tab(l_indx).ROW_ID                ,
                                        t_ont_price_adj_lines_tab (l_indx).price_adjustment_id,
                                        t_ont_price_adj_lines_tab (l_indx).program_application_id,
                                        t_ont_price_adj_lines_tab (l_indx).program_id,
                                        t_ont_price_adj_lines_tab (l_indx).program_update_date,
                                        t_ont_price_adj_lines_tab (l_indx).header_id,
                                        t_ont_price_adj_lines_tab (l_indx).discount_id,
                                        t_ont_price_adj_lines_tab (l_indx).discount_line_id,
                                        t_ont_price_adj_lines_tab (l_indx).automatic_flag,
                                        t_ont_price_adj_lines_tab (l_indx).percent,
                                        t_ont_price_adj_lines_tab (l_indx).line_id,
                                        t_ont_price_adj_lines_tab (l_indx).context,
                                        t_ont_price_adj_lines_tab (l_indx).attribute1,
                                        t_ont_price_adj_lines_tab (l_indx).attribute2,
                                        t_ont_price_adj_lines_tab (l_indx).attribute3,
                                        t_ont_price_adj_lines_tab (l_indx).attribute4,
                                        t_ont_price_adj_lines_tab (l_indx).attribute5,
                                        t_ont_price_adj_lines_tab (l_indx).attribute6,
                                        t_ont_price_adj_lines_tab (l_indx).attribute7,
                                        t_ont_price_adj_lines_tab (l_indx).attribute8,
                                        t_ont_price_adj_lines_tab (l_indx).attribute9,
                                        t_ont_price_adj_lines_tab (l_indx).attribute10,
                                        t_ont_price_adj_lines_tab (l_indx).attribute11,
                                        t_ont_price_adj_lines_tab (l_indx).attribute12,
                                        t_ont_price_adj_lines_tab (l_indx).attribute13,
                                        t_ont_price_adj_lines_tab (l_indx).attribute14,
                                        t_ont_price_adj_lines_tab (l_indx).attribute15,
                                        t_ont_price_adj_lines_tab (l_indx).orig_sys_discount_ref,
                                        -- CHANGE_SEQUENCE         ,
                                        t_ont_price_adj_lines_tab (l_indx).list_header_id,
                                        t_ont_price_adj_lines_tab (l_indx).list_line_id,
                                        t_ont_price_adj_lines_tab (l_indx).list_line_type_code,
                                        t_ont_price_adj_lines_tab (l_indx).modifier_mechanism_type_code,
                                        t_ont_price_adj_lines_tab (l_indx).modified_from,
                                        t_ont_price_adj_lines_tab (l_indx).modified_to,
                                        t_ont_price_adj_lines_tab (l_indx).update_allowed,
                                        t_ont_price_adj_lines_tab (l_indx).updated_flag,
                                        t_ont_price_adj_lines_tab (l_indx).applied_flag,
                                        t_ont_price_adj_lines_tab (l_indx).change_reason_code,
                                        t_ont_price_adj_lines_tab (l_indx).change_reason_text,
                                        t_ont_price_adj_lines_tab (l_indx).adjustment_name,
                                        t_ont_price_adj_lines_tab (l_indx).adjustment_type_code,
                                        t_ont_price_adj_lines_tab (l_indx).override_allowed_flag,
                                        t_ont_price_adj_lines_tab (l_indx).adjustment_type_name,
                                        t_ont_price_adj_lines_tab (l_indx).operand,
                                        t_ont_price_adj_lines_tab (l_indx).arithmetic_operator,
                                        t_ont_price_adj_lines_tab (l_indx).cost_id,
                                        t_ont_price_adj_lines_tab (l_indx).tax_code,
                                        t_ont_price_adj_lines_tab (l_indx).tax_exempt_flag,
                                        t_ont_price_adj_lines_tab (l_indx).tax_exempt_number,
                                        t_ont_price_adj_lines_tab (l_indx).tax_exempt_reason_code,
                                        t_ont_price_adj_lines_tab (l_indx).parent_adjustment_id,
                                        t_ont_price_adj_lines_tab (l_indx).invoiced_flag,
                                        t_ont_price_adj_lines_tab (l_indx).estimated_flag,
                                        t_ont_price_adj_lines_tab (l_indx).inc_in_sales_performance,
                                        t_ont_price_adj_lines_tab (l_indx).split_action_code,
                                        t_ont_price_adj_lines_tab (l_indx).adjusted_amount,
                                        t_ont_price_adj_lines_tab (l_indx).pricing_phase_id,
                                        t_ont_price_adj_lines_tab (l_indx).charge_type_code,
                                        t_ont_price_adj_lines_tab (l_indx).charge_subtype_code,
                                        t_ont_price_adj_lines_tab (l_indx).range_break_quantity,
                                        t_ont_price_adj_lines_tab (l_indx).accrual_conversion_rate,
                                        t_ont_price_adj_lines_tab (l_indx).pricing_group_sequence,
                                        t_ont_price_adj_lines_tab (l_indx).accrual_flag,
                                        t_ont_price_adj_lines_tab (l_indx).list_line_no,
                                        t_ont_price_adj_lines_tab (l_indx).source_system_code,
                                        t_ont_price_adj_lines_tab (l_indx).benefit_qty,
                                        t_ont_price_adj_lines_tab (l_indx).benefit_uom_code,
                                        t_ont_price_adj_lines_tab (l_indx).print_on_invoice_flag,
                                        t_ont_price_adj_lines_tab (l_indx).expiration_date,
                                        t_ont_price_adj_lines_tab (l_indx).rebate_transaction_type_code,
                                        t_ont_price_adj_lines_tab (l_indx).rebate_transaction_reference,
                                        t_ont_price_adj_lines_tab (l_indx).rebate_payment_system_code,
                                        t_ont_price_adj_lines_tab (l_indx).redeemed_date,
                                        t_ont_price_adj_lines_tab (l_indx).redeemed_flag,
                                        t_ont_price_adj_lines_tab (l_indx).modifier_level_code,
                                        t_ont_price_adj_lines_tab (l_indx).price_break_type_code,
                                        t_ont_price_adj_lines_tab (l_indx).substitution_attribute,
                                        t_ont_price_adj_lines_tab (l_indx).proration_type_code,
                                        t_ont_price_adj_lines_tab (l_indx).include_on_returns_flag,
                                        t_ont_price_adj_lines_tab (l_indx).credit_or_charge_flag,
                                        t_ont_price_adj_lines_tab (l_indx).adjustment_description,
                                        t_ont_price_adj_lines_tab (l_indx).ac_context,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute1,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute2,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute3,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute4,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute5,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute6,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute7,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute8,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute9,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute10,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute11,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute12,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute13,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute14,
                                        t_ont_price_adj_lines_tab (l_indx).ac_attribute15,
                                        t_ont_price_adj_lines_tab (l_indx).lock_control,
                                        t_ont_price_adj_lines_tab (l_indx).operand_per_pqty,
                                        t_ont_price_adj_lines_tab (l_indx).adjusted_amount_per_pqty,
                                        --  t_ont_price_adj_lines_tab(l_indx).INTERCO_INVOICED_FLAG         ,
                                        t_ont_price_adj_lines_tab (l_indx).invoiced_amount,
                                        t_ont_price_adj_lines_tab (l_indx).retrobill_request_id,
                                        t_ont_price_adj_lines_tab (l_indx).tax_rate_id,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_conc_request_id,
                                        t_ont_price_adj_lines_tab (l_indx).orig_sys_line_ref,
                                        t_ont_price_adj_lines_tab (l_indx).orig_sys_header_ref);

                COMMIT;
                EXIT WHEN lcu_price_adj_lines%NOTFOUND;
            END LOOP;

            CLOSE lcu_price_adj_lines;
        END LOOP;

        --        DELETE
        --          FROM XXD_ONT_SO_HEADERS_CONV_STG_T
        --         WHERE header_id NOT IN
        --                  (SELECT header_id
        --                     FROM XXD_ONT_SO_HEADERS_CONV_STG_T h
        --                    WHERE EXISTS
        --                             (SELECT 1
        --                                FROM XXD_ONT_SO_lines_CONV_STG_T l
        --                               WHERE     h.header_id = l.header_id
        --                                     AND l.FLOW_STATUS_CODE NOT IN
        --                                            ('CLOSED', 'INVOICED')));
        --
        --            DELETE xxd_ont_so_lines_conv_stg_t xoel
        --             WHERE header_id NOT in (SELECT header_id
        --                                 FROM XXD_ONT_SO_HEADERS_CONV_STG_T xsh);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Inserting record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Exception ' || SQLERRM);
    END extract_1206_data;

    -- ========================================================================= --
    --                                                                           --
    -- PROCEDURE      :  import_main_prc                                         --
    --                                                                           --
    -- Description    :  This is the procedure which will be called              --
    --                   from concurrent program                                 --
    --                                                                           --
    -- Parameters     :                                                          --
    --                                                                           --
    -- Parameter Name      Mode Type       Description                           --
    -- --------------      ---- --------   ----------------                      --
    --                                                                           --
    -- ========================================================================= --
    /*procedure progress_order_main(x_errbuff    out varchar2,
                                  x_retcode    out varchar2,
                                  p_debug_flag in varchar2) is
      x_return_mesg           varchar2(4000);
      x_return_sts            varchar2(1);
      lc_query                varchar2(4000);
      lc_order_query          varchar2(4000);
      lc_sort_option          varchar2(4000);
      lc_customer_query       varchar2(4000);
      lc_ship_date_query      varchar2(4000);
      ln                      number := 1;
      ld_from_ship_date       date;
      ld_to_ship_date         date;
      ln_from_cust_account_id number;
      ln_to_cust_account_id   number;
      lc_final_query          varchar2(4000);
      error_exception exception;
      log_msg varchar2(4000);

      type getordlist is ref cursor;

      cur_order_header getordlist;

      l_qry_orderinfo_tbl p_qry_orderinfo_tbl;

      p_from_order_number          number := null;
      p_to_order_number            number := null;
      p_from_sch_ship_confrim_date varchar2(250) := null;
      p_to_sch_ship_confrim_date   varchar2(250) := null;
      p_from_bill_to_customer      number := null;
      p_to_bill_to_customer        number := null;
    begin
      gn_conc_request_id := fnd_global.conc_request_id; -- Concurrent Request Id
      gn_user_id         := fnd_global.user_id; -- User ID
      gd_sys_date        := sysdate;
      gc_debug_flag      := 'Y';

      x_return_sts := gc_api_success;
      log_records(gc_debug_flag, 'Start of Procedure import_main_prc ');

      -----------------------------------------------------
      -- Get the base query
      -----------------------------------------------------
      lc_query := 'SELECT   distinct ooh.order_number,' || ' ooh.header_id,' ||
                  ' ooh.org_id,' || ' ooh.sold_to_org_id,' ||
                  ' hca.account_number,' || ' ool.line_id,' ||
                  ' ool.inventory_item_id,' || ' ool.ordered_item,' ||
                  ' ool.ship_from_org_id,' || ' ool.ship_to_org_id,' ||
                  ' ool.schedule_ship_date,' || ' wdd.ship_to_location_id,' ||
                  ' wdd.delivery_detail_id,' || ' wdd.released_status,' ||
                  ' wdd.released_status,' || ' wdd.project_id ' ||
                  ' FROM     oe_order_headers_all ooh,' ||
                  '          oe_order_lines_all   ool,' ||
                  '          wsh_delivery_details wdd,' ||
                  '          hz_cust_accounts_all hca ' ||
                  ' WHERE    1  = 1  ' ||
                  ' AND      ooh.flow_status_code   = ' || '''BOOKED''' ||
                  ' AND OOH.order_number = ''50560663'' ' ||
                  ' AND      ool.header_id          = ooh.header_id' ||
                  ' AND      ool.flow_status_code   = ' ||
                  '''AWAITING_SHIPPING''' ||
                  ' AND      wdd.released_status    IN (' || '''R''' || ',' ||
                  '''S''' || ',' || '''Y''' || ',' || '''B''' || ')' ||
                  ' AND      wdd.org_id             =  ool.org_id' ||
                  ' AND      wdd.source_code        = ' || '''OE''' ||
                  ' AND      wdd.source_header_id   =  ool.header_id' ||
                  ' AND      wdd.source_line_id     =  ool.line_id' ||
                  ' AND      wdd.inventory_item_id  =  ool.inventory_item_id' ||
                  ' AND      hca.cust_account_id    =  ooh.sold_to_org_id' ||
                  ' AND      ool.line_id NOT IN(' -- To exclude Hold lines
                  || ' SELECT   distinct line_id' ||
                  ' FROM     oe_order_holds_all ooh' ||
                  ' WHERE    ooh.header_id      = ool.header_id' ||
                  ' AND      ool.line_id        = ooh.line_id  ' ||
                  ' AND      ooh.released_flag  = ' || '''N''' ||
                  ' AND      ooh.hold_release_id IS NULL' || ' )';

      -----------------------------------------
      -- Get the query if order number is
      -- given in the parameter
      -----------------------------------------
      if p_from_order_number is not null and p_to_order_number is not null then
        lc_order_query := ' AND order_number between ' || p_from_order_number ||
                          ' AND ' || p_to_order_number;
        --        GB_ORDER_PASSED := TRUE;

      end if;

      -----------------------------------------
      -- Get the query if sch ship date is
      -- given in the parameter
      -----------------------------------------
      if p_from_sch_ship_confrim_date is not null and
         p_to_sch_ship_confrim_date is not null then
        ld_from_ship_date := to_date(p_from_sch_ship_confrim_date,
                                     'MM/DD/YYYY');
        ld_to_ship_date   := to_date(p_to_sch_ship_confrim_date, 'MM/DD/YYYY');

        if ld_from_ship_date > ld_to_ship_date then
          x_return_mesg := 'The Input Parameter From Sch Ship Date ' ||
                           ld_from_ship_date ||
                           ' is Greater than To Sch Ship Date ' ||
                           ld_to_ship_date;
          raise error_exception;
        else
          lc_ship_date_query := ' AND  TRUNC(ool.schedule_ship_date) BETWEEN  NVL(' || '''' ||
                                ld_from_ship_date || '''' ||
                                ',TRUNC(ool.schedule_ship_date)) AND NVL(' || '''' ||
                                ld_to_ship_date || '''' ||
                                ',TRUNC(ool.schedule_ship_date)) ';
          --            GB_SSD_PASSED := TRUE;
        end if;
      end if;

      -----------------------------------------
      -- Get the query if sch ship date is
      -- given in the parameter
      -----------------------------------------
      if p_from_sch_ship_confrim_date is not null and
         p_to_sch_ship_confrim_date is null then
        ld_from_ship_date := to_date(p_from_sch_ship_confrim_date,
                                     'MM/DD/YYYY');
        ld_to_ship_date   := trunc(sysdate);

        lc_ship_date_query := ' AND  TRUNC(ool.schedule_ship_date) BETWEEN  NVL(' || '''' ||
                              ld_from_ship_date || '''' ||
                              ',TRUNC(ool.schedule_ship_date)) AND NVL(' || '''' ||
                              ld_to_ship_date || '''' ||
                              ',TRUNC(ool.schedule_ship_date)) ';
        --        GB_SSD_PASSED := TRUE;
      end if;

      -----------------------------------------
      -- Get the query if cust account number is
      -- given in the parameter
      -----------------------------------------
      if p_from_bill_to_customer is not null and
         p_to_bill_to_customer is not null then
        begin
          select min(cust_account_id), max(cust_account_id)
            into ln_from_cust_account_id, ln_to_cust_account_id
            from hz_cust_accounts_all
           where account_number between to_number(p_from_bill_to_customer) and
                 to_number(p_to_bill_to_customer);
        exception
          when no_data_found then
            x_return_mesg := 'The Input Parameter From Bill To Account number  ' ||
                             p_from_bill_to_customer || ' and ' ||
                             ' To Bill to Account number ' ||
                             p_to_bill_to_customer || 'is not valid';
            raise error_exception;
            fnd_file.put_line(fnd_file.log,
                              'Error Status ' || x_return_sts ||
                              ' ,Error message ' || x_return_mesg);
          when others then
            x_return_mesg := 'The procedure import_main_prc Failed  ' ||
                             sqlerrm;
            x_return_sts  := gc_api_error;
            fnd_file.put_line(fnd_file.log,
                              'Error Status ' || x_return_sts ||
                              ' ,Error message ' || x_return_mesg);
        end;

        if ln_from_cust_account_id is not null and
           ln_to_cust_account_id is not null then
          lc_customer_query := ' AND ooh.sold_to_org_id between ' ||
                               ln_from_cust_account_id || ' AND ' ||
                               ln_to_cust_account_id;
          --            GB_CUST_ACCT_CN_PASSED  := TRUE;

        end if;
      end if;

      lc_sort_option := ' Order By Order_number ';

      -- concatenate all the dynamic sql based on input parameters
      lc_final_query := lc_query || lc_order_query || lc_ship_date_query ||
                        lc_customer_query || lc_sort_option;

      fnd_file.put_line(fnd_file.log, lc_customer_query);
      fnd_file.put_line(fnd_file.log, lc_final_query);
      fnd_file.put_line(fnd_file.log, lc_order_query);

      --------------------------------------------------------------------------
      -- Print the heading and other details in output file
      --------------------------------------------------------------------------
      log_msg := ('Begin import_main_prc procedure');
      log_records(gc_debug_flag, log_msg);

      fnd_file.put_line(fnd_file.output,
                        '**************************************************' ||
                        '*****************************');
      fnd_file.put_line(fnd_file.output,
                        '    Deckers : Ship Confirm Interface Program');
      fnd_file.put_line(fnd_file.output,
                        '**************************************************' ||
                        '*****************************');
      fnd_file.put_line(fnd_file.output,
                        ' Concurrent Request Id               : ' ||
                        gn_conc_request_id);
      fnd_file.put_line(fnd_file.output,
                        ' Program Run Date                    : ' ||
                        gd_sys_date);
      fnd_file.put_line(fnd_file.output,
                        ' Parameters                          : ');
      fnd_file.put_line(fnd_file.output,
                        ' From Sales Order Number             : ' ||
                        p_from_order_number);
      fnd_file.put_line(fnd_file.output,
                        ' To Sales Order Number               : ' ||
                        p_to_order_number);
      fnd_file.put_line(fnd_file.output,
                        ' From Sch Shipping Date              : ' ||
                        p_from_sch_ship_confrim_date);
      fnd_file.put_line(fnd_file.output,
                        ' To Sch Shipping Date                : ' ||
                        ld_to_ship_date);
      fnd_file.put_line(fnd_file.output,
                        ' From Bill To customer Account Number: ' ||
                        p_from_bill_to_customer);
      fnd_file.put_line(fnd_file.output,
                        ' To Bill To customer Account Number  : ' ||
                        p_to_bill_to_customer);
      fnd_file.put_line(fnd_file.output,
                        '--------------------------------------------------' ||
                        '-----------------------------');

      fnd_file.put_line(fnd_file.log,
                        '**************************************************' ||
                        '*****************************');
      fnd_file.put_line(fnd_file.log,
                        '    Deckers : Ship Confirm Interface Program');
      fnd_file.put_line(fnd_file.log,
                        '**************************************************' ||
                        '*****************************');
      fnd_file.put_line(fnd_file.log,
                        ' Concurrent Request Id : ' || gn_conc_request_id);
      fnd_file.put_line(fnd_file.log,
                        ' Program Run Date      : ' || gd_sys_date);
      fnd_file.put_line(fnd_file.log, ' Parameters            : ');
      fnd_file.put_line(fnd_file.log,
                        ' From Sales Order Number             : ' ||
                        p_from_order_number);
      fnd_file.put_line(fnd_file.log,
                        ' To Sales Order Number               : ' ||
                        p_to_order_number);
      fnd_file.put_line(fnd_file.log,
                        ' From Sch Shipping Date              : ' ||
                        p_from_sch_ship_confrim_date);
      fnd_file.put_line(fnd_file.log,
                        ' To Sch Shipping Date                : ' ||
                        ld_to_ship_date);
      fnd_file.put_line(fnd_file.log,
                        ' From Bill To customer Account Number: ' ||
                        p_from_bill_to_customer);
      fnd_file.put_line(fnd_file.log,
                        ' To Bill To customer Account Number  : ' ||
                        p_to_bill_to_customer);
      fnd_file.put_line(fnd_file.log,
                        '--------------------------------------------------' ||
                        '-----------------------------');

      --------------------------------------------------
      -- Open the ref cursor to get data into table type
      --------------------------------------------------
      open cur_order_header for lc_final_query;

      loop
        fetch cur_order_header
          into l_qry_orderinfo_tbl(ln);

        exit when cur_order_header%notfound;
        ln := l_qry_orderinfo_tbl.count + 1;
      end loop;

      close cur_order_header;*/

    /*  IF l_qry_orderinfo_tbl.COUNT > 0 THEN
        FORALL j IN l_qry_orderinfo_tbl.FIRST..l_qry_orderinfo_tbl.LAST
        INSERT INTO raghu_test VALUES l_qry_orderinfo_tbl(j);
    END IF;

    COMMIT;*/

    -- insert data if cursor retreive any data for the parameter range
    /*  if l_qry_orderinfo_tbl.count > 0 then
        for ln in 1 .. l_qry_orderinfo_tbl.count loop
          -------------------------------------------------
          --  Insert data into staging table
          -------------------------------------------------

          begin
            insert into xxd_ont_ship_confirm_conv_tbl
              (record_id,
               order_number,
               header_id,
               org_id,
               ship_from_org_id,
               ship_to_location_id,
               line_id,
               inventory_item_id,
               ordered_item,
               sch_ship_date,
               bill_to_customer,
               cust_account_number,
               delivery_detail_id,
               released_status,
               original_released_status,
               project_id -- batch_id
               -- group_id
               -- program_request_id
              ,
               request_id,
               created_by,
               created_date,
               last_updated_by,
               last_updated_date,
               status,
               error_message)
            values
              (xxd_ont_ship_confirm_conv_seq.nextval -- record_id
              ,
               l_qry_orderinfo_tbl                  (ln).order_number -- order_number
              ,
               l_qry_orderinfo_tbl                  (ln).header_id -- header_id
              ,
               l_qry_orderinfo_tbl                  (ln).org_id -- org_id
              ,
               l_qry_orderinfo_tbl                  (ln).ship_from_org_id -- ship_from_org_id
              ,
               l_qry_orderinfo_tbl                  (ln).ship_to_location_id -- ship_to_location_id
              ,
               l_qry_orderinfo_tbl                  (ln).line_id -- line_id
              ,
               l_qry_orderinfo_tbl                  (ln).inventory_item_id -- inventory_item_id
              ,
               l_qry_orderinfo_tbl                  (ln).ordered_item -- ordered_item
              ,
               l_qry_orderinfo_tbl                  (ln).schedule_ship_date -- sch_ship_date
              ,
               l_qry_orderinfo_tbl                  (ln).sold_to_org_id -- bill_to_customer
              ,
               l_qry_orderinfo_tbl                  (ln).cust_account_number -- cust_account_number
              ,
               l_qry_orderinfo_tbl                  (ln).delivery_detail_id -- delivery_detail_id
              ,
               l_qry_orderinfo_tbl                  (ln).released_status -- released_status
              ,
               l_qry_orderinfo_tbl                  (ln).released_status -- original_released_status
              ,
               l_qry_orderinfo_tbl                  (ln).project_id -- project_id
               -- batch_id
               -- program_request_id
              ,
               gn_conc_request_id -- request_id
              ,
               gn_user_id -- created_by
              ,
               gd_sys_date -- created_date
              ,
               gn_user_id -- last_updated_by
              ,
               gd_sys_date -- last_updated_date
              ,
               gc_new -- status
              ,
               null -- error_message
               );
          exception
            when others then
              x_return_mesg := 'While inserting data into staging table ' ||
                               sqlerrm;
              x_return_sts  := gc_api_error;
              fnd_file.put_line(fnd_file.log,
                                'Error Status ' || x_return_sts ||
                                ' ,Error message ' || x_return_mesg);
          end;
        end loop;

        commit;

        -------------------------------------------------
        --  Call procedure to validate data
        -------------------------------------------------
        if x_return_sts = gc_api_success then
          validate_record_prc(x_return_mesg => x_return_mesg,
                              x_return_sts  => x_return_sts);
        end if;

        -------------------------------------------------
        --  Call procedure to process data
        -------------------------------------------------
        if x_return_sts = gc_api_success then
          process_record_prc(x_return_mesg => x_return_mesg,
                             x_return_sts  => x_return_sts);
        end if;
        -------------------------------------------------
        --  Call procedure to print error details
        -------------------------------------------------
        --IF x_return_sts = GC_API_SUCCESS THEN
        --            Print_output_Report(
        --            p_request_id     => GN_CONC_REQUEST_ID,
        --            x_return_mesg    => X_Return_Mesg,
        --            x_return_sts     => x_return_sts
        --           );

        -- END IF;*/
    ---------------------------------------------------
    -- GET count of total records
    ---------------------------------------------------
    /*   SELECT COUNT(1)
    INTO   GN_IMP_REC_CNT
    FROM   XXD_ONT_SHIP_CONFIRM_CONV_TBL
    WHERE  request_id   = GN_CONC_REQUEST_ID;

    ---------------------------------------------------
    -- GET count of Error records
    ---------------------------------------------------
    SELECT COUNT(1)
    INTO   GN_ERR_REC_CNT
    FROM   XXD_ONT_SHIP_CONFIRM_CONV_TBL
    WHERE  request_id   = GN_CONC_REQUEST_ID
    AND    status       = GC_ERROR;

    ---------------------------------------------------
    -- GET count of processd records
    ---------------------------------------------------
    SELECT COUNT(1)
    INTO   GN_PRO_REC_CNT
    FROM   XXD_ONT_SHIP_CONFIRM_CONV_TBL
    WHERE  request_id    = GN_CONC_REQUEST_ID
    AND    status        = GC_PROCESSED;

    IF GN_ERR_REC_CNT > 0 THEN
        x_retcode := 1;
    END IF;*/
    /* else
       log_records(gc_debug_flag,
                   '************ No Records available to process Ship confirm program for the Request Id: ' ||
                   gn_conc_request_id || ' *************');
       x_retcode := 1;
     end if; -- IF l_qry_orderinfo_tbl.count > 0 THEN

     ----------------------------------------------------------------------
     -- print statistics of the records in output of the concurrent program
     ----------------------------------------------------------------------
     fnd_file.put_line(fnd_file.output, chr(10));
     fnd_file.put_line(fnd_file.output,
                       '**************************************************');
     fnd_file.put_line(fnd_file.output,
                       ' Statistics FOR Ship Confirmation Program :-');
     fnd_file.put_line(fnd_file.output,
                       '**************************************************');
     --    FND_FILE.PUT_LINE(fnd_file.output,' Total Records Eligible for process   = '||GN_IMP_REC_CNT);
     --    FND_FILE.PUT_LINE(fnd_file.output,' Number of Records PROCESSED          = '||GN_PRO_REC_CNT);
     --    FND_FILE.PUT_LINE(fnd_file.output,' Number of Records ERROR              = '||GN_ERR_REC_CNT);

   exception
     when error_exception then
       x_return_mesg := x_return_mesg;
       x_return_sts  := gc_api_error;
       fnd_file.put_line(fnd_file.log,
                         'Error Status ' || x_return_sts ||
                         ' ,Error message ' || x_return_mesg);
     when others then
       x_return_mesg := 'The procedure import_main_prc Failed  ' || sqlerrm;
       x_return_sts  := gc_api_error;
       fnd_file.put_line(fnd_file.log,
                         'Error Status ' || x_return_sts ||
                         ' ,Error message ' || x_return_mesg);
   end progress_order_main;*/

    --+=====================================================================================+
    -- |Procedure  :  customer_child                                                       |
    -- |                                                                                    |
    -- |Description:  This procedure is the Child Process which will validate and create the|
    -- |              Price list in QP 1223 instance                                        |
    -- |                                                                                    |
    -- | Parameters : p_batch_id, p_action                                                  |
    -- |              p_debug_flag, p_parent_req_id                                         |
    -- |                                                                                    |
    -- |                                                                                    |
    -- | Returns :     x_errbuf,  x_retcode                                                 |
    -- |                                                                                    |
    --+=====================================================================================+

    --Deckers AR Customer Conversion Program (Worker)
    PROCEDURE sales_order_child (errbuf                   OUT VARCHAR2,
                                 retcode                  OUT VARCHAR2,
                                 p_org_name            IN     VARCHAR2,
                                 p_debug_flag          IN     VARCHAR2 DEFAULT 'N',
                                 p_action              IN     VARCHAR2,
                                 p_batch_number        IN     NUMBER,
                                 p_customer_type       IN     VARCHAR2,
                                 p_parent_request_id   IN     NUMBER)
    AS
        le_invalid_param            EXCEPTION;
        ln_new_ou_id                hr_operating_units.organization_id%TYPE; --:= fnd_profile.value('ORG_ID');
        -- This is required in release 12 R12

        ln_request_id               NUMBER := 0;
        lc_username                 fnd_user.user_name%TYPE;
        lc_operating_unit           hr_operating_units.name%TYPE;
        lc_cust_num                 VARCHAR2 (5);
        lc_pri_flag                 VARCHAR2 (1);
        ld_start_date               DATE;
        ln_ins                      NUMBER := 0;
        lc_create_reciprocal_flag   VARCHAR2 (1) := gc_no_flag;
        --ln_request_id             NUMBER                     := 0;
        lc_phase                    VARCHAR2 (200);
        lc_status                   VARCHAR2 (200);
        lc_delc_phase               VARCHAR2 (200);
        lc_delc_status              VARCHAR2 (200);
        lc_message                  VARCHAR2 (200);
        ln_ret_code                 NUMBER;
        lc_err_buff                 VARCHAR2 (1000);
        ln_count                    NUMBER;
        l_target_org_id             NUMBER;
        l_user_id                   NUMBER := -1;
        l_resp_id                   NUMBER := -1;
        l_application_id            NUMBER := -1;

        l_user_name                 VARCHAR2 (30) := 'PVADREVU001';
        l_resp_name                 VARCHAR2 (30) := 'ORDER_MGMT_SU_US';
    BEGIN
        gc_debug_flag        := p_debug_flag;
        gn_conc_request_id   := p_parent_request_id;

        --g_err_tbl_type.delete;
        -- Get the user_id
        /*  SELECT user_id
          INTO l_user_id
          FROM fnd_user
         WHERE user_name = l_user_name;

        -- Get the application_id and responsibility_id
        SELECT application_id, responsibility_id
          INTO l_application_id, l_resp_id
          FROM fnd_responsibility
         WHERE responsibility_key = l_resp_name;*/
        l_user_id            := fnd_global.user_id;
        l_resp_id            := fnd_global.resp_id;
        l_application_id     := fnd_global.resp_appl_id;

        BEGIN
            SELECT name
              INTO lc_operating_unit
              FROM hr_operating_units
             WHERE organization_id = fnd_profile.VALUE ('ORG_ID');
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_operating_unit   := NULL;
        END;

        -- Validation Process for Price List Import
        log_records (
            gc_debug_flag,
            '*************************************************************************** ');
        log_records (
            gc_debug_flag,
               '***************     '
            || lc_operating_unit
            || '***************** ');
        log_records (
            gc_debug_flag,
            '*************************************************************************** ');
        log_records (
            gc_debug_flag,
               '                                         Busines Unit:'
            || lc_operating_unit);
        --      log_records (gc_debug_flag, '                                         Run By      :' || lc_username);
        log_records (
            gc_debug_flag,
               '                                         Run Date    :'
            || TO_CHAR (gd_sys_date, 'DD-MON-YYYY HH24:MI:SS'));
        log_records (
            gc_debug_flag,
               '                                         Request ID  :'
            || fnd_global.conc_request_id);
        log_records (
            gc_debug_flag,
               '                                         Batch ID    :'
            || p_batch_number);
        fnd_file.new_line (fnd_file.LOG, 1);

        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');
        log_records (gc_debug_flag,
                     '******** START of Sales Order Program ******');
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');

        gc_debug_flag        := p_debug_flag;
        l_target_org_id      := get_targetorg_id (p_org_name => p_org_name);
        set_org_context (p_target_org_id   => l_target_org_id,
                         p_resp_id         => gn_resp_id,
                         p_resp_appl_id    => gn_resp_appl_id);

        IF p_action = gc_validate_only
        THEN
            log_records (gc_debug_flag, 'Calling sales_order_validation :');
            ---sales_order_validation
            sales_order_validation (errbuf            => errbuf,
                                    retcode           => retcode,
                                    p_action          => p_action,
                                    p_customer_type   => p_customer_type,
                                    p_batch_number    => p_batch_number);
        ELSIF p_action = gc_load_only
        THEN
            l_target_org_id   := get_targetorg_id (p_org_name => p_org_name);
            --         oe_debug_pub.initialize;
            --         oe_debug_pub.setdebuglevel (1);
            oe_msg_pub.initialize;
            /*****************INITIALIZE ENVIRONMENT*************************************/

            log_records (gc_debug_flag,
                         'Calling l_target_org_id =>' || l_target_org_id);
            log_records (gc_debug_flag,
                         'Calling gn_user_id      =>' || gn_user_id);
            log_records (gc_debug_flag,
                         'Calling gn_resp_id      =>' || gn_resp_id);
            log_records (gc_debug_flag,
                         'Calling gn_resp_appl_id =>' || gn_resp_appl_id);
            DBMS_APPLICATION_INFO.set_client_info (l_target_org_id);
            fnd_global.apps_initialize (gn_user_id,
                                        gn_resp_id,
                                        gn_resp_appl_id); -- pass in user_id, responsibility_id, and application_id
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', l_target_org_id);
            /*****************INITIALIZE HEADER RECORD******************************/

            create_order (x_errbuf           => errbuf,
                          x_retcode          => retcode,
                          p_action           => gc_validate_status,
                          p_operating_unit   => p_org_name,
                          p_target_org_id    => l_target_org_id,
                          p_batch_id         => p_batch_number);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.output,
                'Exception Raised During sales_order  Program');
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
    END sales_order_child;

    /******************************************************
    * Procedure: Customer_main_proc
    *
    * Synopsis: This procedure will call we be called by the concurrent program
    * Design:
    *
    * Notes:
    *
    * PARAMETERS:
    *   IN OUT: x_errbuf   Varchar2
    *   IN OUT: x_retcode  Varchar2
    *   IN    : p_process  varchar2
    *
    * Return Values:
    * Modifications:
    *
    ******************************************************/

    PROCEDURE main (x_retcode             OUT NUMBER,
                    x_errbuf              OUT VARCHAR2,
                    p_org_name         IN     VARCHAR2,
                    p_org_type         IN     VARCHAR2,
                    p_process          IN     VARCHAR2,
                    p_customer_type    IN     VARCHAR2,
                    p_debug_flag       IN     VARCHAR2,
                    p_no_of_process    IN     NUMBER,
                    p_order_ret_type   IN     VARCHAR2)
    IS
        x_errcode                VARCHAR2 (500);
        x_errmsg                 VARCHAR2 (500);
        lc_debug_flag            VARCHAR2 (1);
        ln_process               NUMBER;
        ln_ret                   NUMBER;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id          hdr_batch_id_t;

        TYPE hdr_customer_process_t IS TABLE OF VARCHAR2 (250)
            INDEX BY BINARY_INTEGER;

        lc_hdr_customer_proc_t   hdr_customer_process_t;

        lc_conlc_status          VARCHAR2 (150);
        ln_request_id            NUMBER := 0;
        lc_phase                 VARCHAR2 (200);
        lc_status                VARCHAR2 (200);
        lc_dev_phase             VARCHAR2 (200);
        lc_dev_status            VARCHAR2 (200);
        lc_message               VARCHAR2 (200);
        ln_ret_code              NUMBER;
        lc_err_buff              VARCHAR2 (1000);
        ln_count                 NUMBER;
        ln_cntr                  NUMBER := 0;
        --      ln_batch_cnt          NUMBER                                   := 0;
        ln_parent_request_id     NUMBER := fnd_global.conc_request_id;
        lb_wait                  BOOLEAN;
        lx_return_mesg           VARCHAR2 (2000);
        ln_valid_rec_cnt         NUMBER;
        x_total_rec              NUMBER;
        x_validrec_cnt           NUMBER;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                 request_table;
    BEGIN
        gc_debug_flag   := p_debug_flag;

        IF p_process = gc_extract_only
        THEN
            IF p_debug_flag = 'Y'
            THEN
                gc_code_pointer   := 'Calling Extract process  ';
                log_records (gc_debug_flag,
                             'Code Pointer: ' || gc_code_pointer);
            END IF;

            truncte_stage_tables (x_ret_code      => x_retcode,
                                  x_return_mesg   => x_errbuf);

            log_records (gc_debug_flag,
                         'Woking on extract the data for the OU ');
            extract_1206_data (p_customer_type => p_customer_type, p_org_name => p_org_name, p_org_type => p_org_type, p_order_ret_type => p_order_ret_type, x_total_rec => x_total_rec, x_validrec_cnt => ln_valid_rec_cnt
                               , x_errbuf => x_errbuf, x_retcode => x_retcode);
        ELSIF p_process = gc_validate_only
        THEN
            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM xxd_ont_open_so_head_stg_t
             WHERE batch_number IS NULL AND record_status = gc_new_status;

            FOR i IN 1 .. p_no_of_process
            LOOP
                BEGIN
                    SELECT xxd_ont_open_so_h_conv_batch_s.NEXTVAL
                      INTO ln_hdr_batch_id (i)
                      FROM DUAL;

                    log_records (
                        gc_debug_flag,
                        'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
                END;

                log_records (gc_debug_flag,
                             ' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                log_records (
                    gc_debug_flag,
                       'ceil( ln_valid_rec_cnt/p_no_of_process) := '
                    || CEIL (ln_valid_rec_cnt / p_no_of_process));

                UPDATE xxd_ont_open_so_head_stg_t
                   SET batch_number = ln_hdr_batch_id (i), request_id = ln_parent_request_id
                 WHERE     batch_number IS NULL
                       AND ROWNUM <=
                           CEIL (ln_valid_rec_cnt / p_no_of_process)
                       AND record_status = gc_new_status;
            END LOOP;

            COMMIT;

            FOR l IN 1 .. ln_hdr_batch_id.COUNT
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM xxd_ont_open_so_head_stg_t
                 WHERE     record_status = gc_new_status
                       AND batch_number = ln_hdr_batch_id (l);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXD_ONT_ECOM_OPEN_SO_COV_CHILD',
                                '',
                                '',
                                FALSE,
                                p_org_name,
                                p_debug_flag,
                                p_process,
                                ln_hdr_batch_id (l),
                                p_customer_type,
                                ln_parent_request_id);
                        log_records (gc_debug_flag,
                                     'v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (l)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_ONT_ECOM_OPEN_SO_COV_CHILD error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_ONT_ECOM_OPEN_SO_COV_CHILD error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;
        ELSIF p_process = gc_load_only
        THEN
            ln_cntr   := 0;
            log_records (
                gc_debug_flag,
                'Fetching batch id from XXD_ONT_OPEN_SO_HEAD_STG_T stage to call worker process');

            FOR i
                IN (  SELECT DISTINCT batch_number
                        FROM xxd_ont_open_so_head_stg_t
                       WHERE     batch_number IS NOT NULL
                             AND record_status = gc_validate_status
                    ORDER BY batch_number)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_number;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_ONT_OPEN_SO_HEAD_STG_T');

            COMMIT;

            IF ln_hdr_batch_id.COUNT > 0
            THEN
                log_records (
                    gc_debug_flag,
                       'Calling XXD_AR_CUST_CHILD_CONV in batch '
                    || ln_hdr_batch_id.COUNT);

                FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
                LOOP
                    SELECT COUNT (*)
                      INTO ln_cntr
                      FROM xxd_ont_open_so_head_stg_t
                     WHERE batch_number = ln_hdr_batch_id (i);

                    IF ln_cntr > 0
                    THEN
                        BEGIN
                            ln_request_id   :=
                                apps.fnd_request.submit_request (
                                    'XXDCONV',
                                    'XXD_ONT_ECOM_OPEN_SO_COV_CHILD',
                                    '',
                                    '',
                                    FALSE,
                                    p_org_name,
                                    p_debug_flag,
                                    p_process,
                                    ln_hdr_batch_id (i),
                                    p_customer_type,
                                    ln_parent_request_id);
                            log_records (gc_debug_flag,
                                         'v_request_id := ' || ln_request_id);

                            IF ln_request_id > 0
                            THEN
                                l_req_id (i)   := ln_request_id;
                                COMMIT;
                            ELSE
                                ROLLBACK;
                            END IF;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                x_retcode   := 2;
                                x_errbuf    := x_errbuf || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_ONT_ECOM_OPEN_SO_COV_CHILD error'
                                    || SQLERRM);
                            WHEN OTHERS
                            THEN
                                x_retcode   := 2;
                                x_errbuf    := x_errbuf || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_ONT_ECOM_OPEN_SO_COV_CHILD error'
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;
            END IF;
        END IF;

        log_records (
            gc_debug_flag,
            'Calling XXD_ONT_ECOM_OPEN_SO_COV_CHILD in batch ' || l_req_id.COUNT);
        log_records (
            gc_debug_flag,
            'Calling WAIT FOR REQUEST XXD_ONT_ECOM_OPEN_SO_COV_CHILD to complete');

        IF l_req_id.COUNT > 0
        THEN
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                IF l_req_id (rec) > 0
                THEN
                    LOOP
                        lc_dev_phase    := NULL;
                        lc_dev_status   := NULL;
                        lb_wait         :=
                            fnd_concurrent.wait_for_request (
                                request_id   => l_req_id (rec) --ln_concurrent_request_id
                                                              ,
                                interval     => 1,
                                max_wait     => 1,
                                phase        => lc_phase,
                                status       => lc_status,
                                dev_phase    => lc_dev_phase,
                                dev_status   => lc_dev_status,
                                MESSAGE      => lc_message);

                        IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                        THEN
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;
            END LOOP;
        END IF;

        --Meenakshi Aug-25 Loading data in dump table
        IF p_process = gc_load_only
        THEN
            backup_header_recon;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (gc_debug_flag, 'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250));
            log_records (gc_debug_flag, '');
            x_retcode   := 2;
            x_errbuf    :=
                   'Error Message Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250);
    END main;
END xxd_ont_open_so_conv_pkg;
/
