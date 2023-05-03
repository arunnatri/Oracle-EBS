--
-- XXD_ONT_SO_CONV_WS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_SO_CONV_WS_PKG"
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



    TYPE XXD_ONT_ORDER_HEADER_TAB
        IS TABLE OF XXD_SO_WS_HEADERS_CONV_STG_T%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ont_order_header_tab   XXD_ONT_ORDER_HEADER_TAB;

    TYPE XXD_ONT_ORDER_LINES_TAB
        IS TABLE OF XXD_SO_WS_LINES_CONV_STG_T%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ont_order_lines_tab    XXD_ONT_ORDER_LINES_TAB;

    TYPE XXD_ONT_PRC_ADJ_LINES_TAB
        IS TABLE OF xxd_ont_ws_price_adj_l_stg_t%ROWTYPE
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
        --dbms_output.put_line(p_message);
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


        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxd_conv.xxd_so_ws_headers_conv_stg_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxd_conv.xxd_so_ws_lines_conv_stg_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxd_conv.xxd_ont_ws_price_adj_l_stg_t';



        log_records (gc_debug_flag, 'Truncate Stage Table Complete');
    EXCEPTION
        WHEN OTHERS
        THEN
            --x_ret_code      := gn_err_const;
            x_return_mesg   := SQLERRM;
            log_records (gc_debug_flag,
                         'Truncate Stage Table Exception t' || x_return_mesg);
            xxd_common_utils.record_error ('AR', gn_org_id, 'Deckers Open sales Order Conversion Program', --  SQLCODE,
                                                                                                           SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                         --   SYSDATE,
                                                                                                                                                         gn_user_id, gn_conc_request_id, 'truncte_stage_tables', NULL
                                           , x_return_mesg);
    END truncte_stage_tables;


    PROCEDURE backup_header_recon
    AS
        CURSOR cur_order_head IS SELECT * FROM xxd_so_ws_headers_conv_stg_t-- and lines.record_status ='V'
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
                INSERT INTO XXD_SO_WS_HEAD_CONV_DUMP_BKP
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
         WHERE     fpo.profile_option_id = fpov.profile_option_id --AND level_id =
               AND level_value = fr.responsibility_id
               AND level_id = 10003
               AND language = 'US'
               AND profile_option_name = 'DEFAULT_ORG_ID'
               AND responsibility_name LIKE
                       'Deckers Order Management Manager%'
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
                   --AND     ola.header_id = oha.header_id
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


    PROCEDURE call_atp_toschedule (p_inventory_item_id IN NUMBER, p_quantity_ordered IN NUMBER, p_quantity_uom IN VARCHAR2, p_requested_ship_date IN DATE, p_source_organization_id IN NUMBER, p_order_number IN VARCHAR2 DEFAULT NULL
                                   , p_line_number IN NUMBER DEFAULT NULL, x_return_status OUT VARCHAR2, x_return_msg OUT VARCHAR2)
    AS
        l_atp_rec             MRP_ATP_PUB.ATP_Rec_Typ;
        p_atp_rec             MRP_ATP_PUB.ATP_Rec_Typ;
        x_atp_rec             MRP_ATP_PUB.ATP_Rec_Typ := NULL;
        x_atp_supply_demand   MRP_ATP_PUB.ATP_Supply_Demand_Typ;
        x_atp_period          MRP_ATP_PUB.ATP_Period_Typ;
        x_atp_details         MRP_ATP_PUB.ATP_Details_Typ;
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
        FND_GLOBAL.APPS_INITIALIZE (gn_user_id, gn_resp_id, gn_resp_appl_id);
        -- ====================================================
        -- IF using 11.5.9 and above, Use MSC_ATP_GLOBAL.Extend_ATP
        -- API to extend record structure as per standards. This
        -- will ensure future compatibility.

        MSC_ATP_GLOBAL.Extend_Atp (l_atp_rec, x_return_status, 1);

        -- IF using 11.5.8 code, Use MSC_SATP_FUNC.Extend_ATP
        -- API to avoid any issues with Extending ATP record
        -- type.
        -- ====================================================



        l_atp_rec.Inventory_Item_Id (1)          := p_inventory_item_id; -- from msc_system_items.sr_inventory_item_id
        --  l_atp_rec.Inventory_Item_Name(1)       := '1001473-CCGN-07';
        l_atp_rec.Quantity_Ordered (1)           := p_quantity_ordered;
        l_atp_rec.Quantity_UOM (1)               := p_quantity_uom;
        l_atp_rec.Requested_Ship_Date (1)        := p_requested_ship_date;
        l_atp_rec.Action (1)                     := 100;
        l_atp_rec.Instance_Id (1)                := NULL; -- needed when using calling_module = 724, use msc_system_items.sr_instance_id
        l_atp_rec.Source_Organization_Id (1)     := p_source_organization_id;
        l_atp_rec.OE_Flag (1)                    := 'N';
        l_atp_rec.Insert_Flag (1)                := 1; -- Hardcoded value for profile MRP:Calculate Supply Demand 0= NO
        l_atp_rec.Attribute_04 (1)               := 1; -- With this Attribute set to 1 this will enable the Period (Horizontal Plan),
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
        l_atp_rec.Customer_Id (1)                := NULL;
        l_atp_rec.Customer_Site_Id (1)           := NULL;
        l_atp_rec.Calling_Module (1)             := NULL; -- use 724 when calling from MSC_ATP_CALL - otherwise NULL
        l_atp_rec.Row_Id (1)                     := NULL;
        l_atp_rec.Source_Organization_Code (1)   := NULL;
        l_atp_rec.Organization_Id (1)            := NULL;
        l_atp_rec.order_number (1)               := p_order_number;
        l_atp_rec.line_number (1)                := p_line_number;
        l_atp_rec.override_flag (1)              := 'N';                --'Y';
        l_error_message                          := NULL;


        SELECT OE_ORDER_SCH_UTIL.Get_Session_Id INTO l_session_id FROM DUAL;

        --  SELECT LTRIM(RTRIM(SUBSTR(value, INSTR(value,',',-1,1)+1)))
        --  INTO   v_file_dir
        --  FROM   v$parameter  WHERE  name= 'utl_file_dir';

        APPS.MSC_ATP_PUB.Call_ATP (l_session_id,
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
                || x_atp_supply_demand.Inventory_item_id.COUNT);
            log_records (
                gc_debug_flag,
                'No of records in atp_period =        ' || x_atp_period.Inventory_item_id.COUNT);
            log_records (
                gc_debug_flag,
                'No of records in atp_details =       ' || x_atp_details.Inventory_item_id.COUNT);
            log_records (gc_debug_flag, ' ---- ');
            log_records (gc_debug_flag, ' Begin Item Availability Results');
            log_records (gc_debug_flag, ' ---- ');

            FOR i IN 1 .. x_atp_rec.Inventory_item_id.COUNT
            LOOP
                x_error_message   := '';
                log_records (
                    gc_debug_flag,
                    'Item Name          : ' || x_atp_rec.Inventory_Item_Name (i));
                log_records (
                    gc_debug_flag,
                    'Quantity ordered   : ' || x_atp_rec.Quantity_Ordered (i));
                log_records (
                    gc_debug_flag,
                    'Source Org Id      : ' || x_atp_rec.Source_Organization_Id (i));
                log_records (
                    gc_debug_flag,
                    'Source Org Code    : ' || x_atp_rec.Source_Organization_Code (i));
                log_records (
                    gc_debug_flag,
                    'Requested Ship Date: ' || x_atp_rec.Requested_Ship_Date (i));
                log_records (
                    gc_debug_flag,
                    'Requested Date Qty : ' || x_atp_rec.Requested_Date_Quantity (i));
                log_records (
                    gc_debug_flag,
                    'Ship Date          : ' || x_atp_rec.Ship_Date (i));
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
                    'Insert Flag        : ' || x_atp_rec.Insert_Flag (i));
                log_records (gc_debug_flag, '----------- ');
            END LOOP;

            log_records (gc_debug_flag, ' ============================= ');
            log_records (gc_debug_flag, ' No. of record in x_atp_period ');
            log_records (gc_debug_flag, ' ============================= ');

            FOR j IN 1 .. x_atp_period.LEVEL.COUNT
            LOOP
                log_records (
                    gc_debug_flag,
                    'Start Date        : ' || x_atp_period.Period_Start_Date (j));
                log_records (
                    gc_debug_flag,
                    'Total Demand      : ' || x_atp_period.Total_Demand_Quantity (j));
                log_records (
                    gc_debug_flag,
                    'Total Supply      : ' || x_atp_period.Total_Supply_Quantity (j));
                log_records (
                    gc_debug_flag,
                    'Cum Quantity      : ' || x_atp_period.Cumulative_Quantity (j));
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
                    'Supply_Demand Type     : ' || x_atp_supply_demand.Supply_Demand_Type (j));
                log_records (
                    gc_debug_flag,
                    'Supply_Demand Date     : ' || x_atp_supply_demand.supply_demand_Date (j));
                log_records (
                    gc_debug_flag,
                    'supply_demand Quantity : ' || x_atp_supply_demand.supply_demand_Quantity (j));
                log_records (gc_debug_flag,
                             '---------------------------------- ');
            END LOOP;
        END IF;
    END Call_ATP_toSchedule;


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
        l_hdr_adj_tbl                  oe_order_pub.header_adj_tbl_type;
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
        l_line_tbl (1)                     := OE_ORDER_PUB.G_MISS_LINE_REC;
        l_line_tbl (1).header_id           := p_header_id;
        l_line_tbl (1).line_id             := p_line_id;
        l_line_tbl (1).reserved_quantity   := p_reserved_quantity;
        l_line_tbl (1).operation           := OE_GLOBALS.G_OPR_UPDATE;

        /*****************CALLTO PROCESS ORDER API*********************************/
        oe_order_pub.process_order (
            p_api_version_number       => l_api_version_number,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            p_line_adj_tbl             => l_line_adj_tbl-- , p_header_adj_tbl                => l_hdr_adj_tbl
                                                        -- OUT variables
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

            --         UPDATE XXD_SO_WS_LINES_CONV_STG_T SET
            --                       RECORD_STATUS       = gc_process_status
            --                 WHERE ORIG_SYS_DOCUMENT_REF  = l_header_rec_out.orig_sys_document_ref ;
            --
            --         UPDATE XXD_SO_WS_HEADERS_CONV_STG_T SET
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
        --                  UPDATE XXD_SO_WS_LINES_CONV_STG_T SET
        --                       RECORD_STATUS       = gc_error_status
        --                 WHERE ORIG_SYS_DOCUMENT_REF  = l_header_rec_out.orig_sys_document_ref ;
        --
        --         UPDATE XXD_SO_WS_HEADERS_CONV_STG_T SET
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

    --Added by meenakshi 15-may
    PROCEDURE release_hold (p_header_id       IN     NUMBER,
                            p_hold_id         IN     NUMBER,
                            x_return_status      OUT VARCHAR2)
    AS
        l_order_tbl        OE_HOLDS_PVT.order_tbl_type;
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
        --    -- Get the user_id
        --      SELECT user_id
        --      INTO l_user_id
        --      FROM fnd_user
        --      WHERE user_name = l_user_name;
        --
        --      -- Get the application_id and responsibility_id
        --      SELECT application_id, responsibility_id
        --      INTO l_application_id, l_resp_id
        --      FROM fnd_responsibility
        --      WHERE responsibility_key = l_resp_name;
        --   DBMS_APPLICATION_INFO.set_client_info (l_org);
        --
        --/*****************INITIALIZE DEBUG INFO*************************************/
        --   IF (l_debug_level > 0)
        --   THEN
        ----      l_debug_file := oe_debug_pub.set_debug_mode ('FILE');
        ----      oe_debug_pub.initialize;
        ----      oe_debug_pub.setdebuglevel (l_debug_level);
        --      oe_msg_pub.initialize;
        --   END IF;
        --
        --/*****************INITIALIZE ENVIRONMENT*************************************/
        --   FND_GLOBAL.APPS_INITIALIZE(l_user_id, l_resp_id, l_application_id);-- pass in user_id, responsibility_id, and application_id
        --    MO_GLOBAL.INIT('ONT'); -- Required for R12
        -- MO_GLOBAL.SET_POLICY_CONTEXT('S', 87); -- Required for R12
        --/*****************INITIALIZE HEADER RECORD******************************/
        --
        ----oe_debug_pub.initialize;
        ----oe_debug_pub.setdebuglevel(1);
        --oe_msg_pub.initialize;
        --
        l_order_tbl (1).header_id   := p_header_id;
        --
        ----OE_DEBUG_PUB.Add('Just before calling OE_Holds_PUB.Apply_Holds:' );

        OE_Holds_PUB.Release_Holds (
            p_api_version           => 1.0,
            p_order_tbl             => l_order_tbl,
            p_hold_id               => p_hold_id,
            p_release_reason_code   => 'MANUAL_RELEASE_MARGIN_HOLD',
            p_release_comment       => 'Released by BT Conversion',
            x_return_status         => l_return_status,
            x_msg_count             => l_msg_count,
            x_msg_data              => l_msg_data);


        --OE_DEBUG_PUB.Add('Just after calling OE_Holds_PUB.Apply_Holds:');

        -- Check Return Status
        IF l_return_status = FND_API.G_RET_STS_SUCCESS
        THEN
            log_records (gc_debug_flag, 'success');
            x_return_status   := l_return_status;
            COMMIT;
        ELSE
            log_records (gc_debug_flag, 'failure');
            x_return_status   := l_return_status;
            ROLLBACK;
        END IF;

        /*
            FOR i IN 1 .. l_msg_count
              LOOP
                 oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_data, p_msg_index_out => l_msg_index);
                 log_records (gc_debug_flag,'message is: ' || l_data);
                 log_records (gc_debug_flag,'message index is: ' || l_msg_index);
              END LOOP;
        */
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
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        l_line_tbl                     oe_order_pub.line_tbl_type;
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
    BEGIN
        -- INITIALIZE ENVIRONMENT

        --    fnd_global.apps_initialize(user_id      => p_user_id,
        --                           resp_id          => p_resp_id,
        --                           resp_appl_id     => p_resp_app_id);
        --    mo_global.set_policy_context('S', p_org_id);

        --added by amol on 21-may-15
        -- log_records (gc_debug_flag,'apply hold  p_header_rec.org_id ' ||p_header_rec.org_id );
        log_records (
            gc_debug_flag,
            'apply hold  pl_header_rec.org_id  ' || l_header_rec.org_id);
        log_records (gc_debug_flag, 'apply hold  gn_org_id  ' || gn_org_id);
        --log_records (gc_debug_flag,'apply hold  p_org_id ' ||p_org_id);
        log_records (gc_debug_flag, 'apply hold  gn_user_id ' || gn_user_id);
        log_records (gc_debug_flag, 'apply hold   gn_resp_id ' || gn_resp_id);
        log_records (gc_debug_flag,
                     'apply hold gn_resp_appl_id ' || gn_resp_appl_id);

        FND_GLOBAL.APPS_INITIALIZE (gn_user_id, gn_resp_id, gn_resp_appl_id);
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', gn_org_id);

        log_records (gc_debug_flag,
                     'Calling apply_hold_header_line Order API');
        ln_cnt            := 0;

        FOR holds IN (SELECT *
                        FROM xxd_conv.xxd_1206_order_holds_t
                       WHERE ORIG_SYS_DOCUMENT_REF = p_orig_sys_document_ref)
        LOOP
            ln_cnt             := 0;
            lc_error_message   := NULL;

            --l_action_request_tbl.delete;

            --Get hold id
            BEGIN
                ln_hold_id                                   := NULL;
                ln_header_id                                 := NULL;
                lc_activity_name                             := NULL;
                lc_order_number                              := NULL;
                log_records (
                    gc_debug_flag,
                    'Calling holds.hold_name Order API' || holds.hold_name);

                SELECT hold_id--  ,DECODE(activity_name,'BOOK_ORDER','BOOKED','XXXXX')
                              --Added by meenakshi 15-may
                              -- ,DECODE(activity_name,'BOOK_ORDER','BOOKED','XXXXX')
                              , DECODE (activity_name, 'BOOK_ORDER', 'BOOKED', 'ENTERED')
                  INTO ln_hold_id, lc_activity_name
                  FROM oe_hold_definitions
                 WHERE NAME = holds.hold_name;

                log_records (gc_debug_flag, 'ln_hold_id' || ln_hold_id);
                log_records (gc_debug_flag,
                             'lc_activity_name' || lc_activity_name);

                log_records (
                    gc_debug_flag,
                    'Calling holds.hold_name Order API' || holds.orig_sys_document_ref);

                SELECT flow_status_code, order_number, header_id
                  INTO lc_flow_status_code, lc_order_number, ln_header_id
                  FROM oe_order_headers_all
                 WHERE ORIG_SYS_DOCUMENT_REF = holds.orig_sys_document_ref;

                log_records (gc_debug_flag,
                             'lc_flow_status_code' || lc_flow_status_code);
                log_records (gc_debug_flag,
                             'lc_order_number' || lc_order_number);
                log_records (gc_debug_flag, 'ln_header_id' || ln_header_id);


                log_records (
                    gc_debug_flag,
                       'Calling holds.lc_activity_name Order API'
                    || lc_activity_name);
                /* IF NVL(lc_activity_name,'XXXXX') = lc_flow_status_code  THEN
               --Added by meenakshi 15-may
               ---IF NVL(lc_activity_name,lc_flow_status_code ) = lc_flow_status_code  THEN
                   if  lc_flow_status_code <>'ENTERED' then
                     lc_error_message := lc_error_message || ' Hold On Workflow Activity, Book Order Is Not Applicable To The Sales Order - '||lc_order_number ||'. ';
                     xxd_common_utils.record_error
                                                 ('ONT',
                                                  gn_org_id,
                                                  'Deckers Open Sales Order Conversion Program',
                                            --      SQLCODE,
                                                  'APPLY_HOLD_HEADER_LINE'||lc_error_message,
                                                  DBMS_UTILITY.format_error_backtrace,
                                               --   DBMS_UTILITY.format_call_stack,
                                              --    SYSDATE,
                                                 gn_user_id,
                                                  gn_conc_request_id,
                                                   'ORDER NUMBER'
                                                  , lc_order_number
                                                  );
                  end if;
                 ELSE*/
                --This is to apply hold an order header or line
                --ln_cnt :=   1;
                ln_cnt                                       := ln_cnt + 1;
                l_header_rec                                 := oe_order_pub.g_miss_header_rec;

                l_action_request_tbl (ln_cnt)                :=
                    oe_order_pub.g_miss_request_rec;
                l_action_request_tbl (ln_cnt).entity_id      := ln_header_id;
                l_action_request_tbl (ln_cnt).entity_code    :=
                    OE_GLOBALS.G_ENTITY_HEADER;
                l_action_request_tbl (ln_cnt).request_type   :=
                    OE_GLOBALS.G_APPLY_HOLD;
                l_action_request_tbl (ln_cnt).param1         := ln_hold_id; -- hold_id
                l_action_request_tbl (ln_cnt).param2         := 'O'; -- indicator that it is an order hold
                --l_action_request_tbl (ln_cnt).param3       :=holds.hold_entity_id; --added by amol
                l_action_request_tbl (ln_cnt).param3         := ln_header_id; -- Header or LINE ID of the order
                l_action_request_tbl (ln_cnt).param4         :=
                    holds.hold_comment;                       -- hold comments

                --           l_action_request_tbl (ln_cnt).date_param1  := holds.hold_until_date; -- hold until date

                log_records (
                    gc_debug_flag,
                       'Calling l_action_request_tbl.count Order API'
                    || l_action_request_tbl.COUNT);

                IF l_action_request_tbl.COUNT > 0
                THEN
                    oe_msg_pub.Initialize;

                    log_records (gc_debug_flag,
                                 'apply hold  gn_org_id  ' || gn_org_id);
                    --log_records (gc_debug_flag,'apply hold  p_org_id ' ||p_org_id);
                    log_records (gc_debug_flag,
                                 'apply hold  gn_user_id ' || gn_user_id);
                    log_records (gc_debug_flag,
                                 'apply hold   gn_resp_id ' || gn_resp_id);
                    log_records (
                        gc_debug_flag,
                        'apply hold gn_resp_appl_id ' || gn_resp_appl_id);
                    -- CALL TO PROCESS Order
                    FND_GLOBAL.APPS_INITIALIZE (gn_user_id,
                                                gn_resp_id,
                                                gn_resp_appl_id);
                    mo_global.init ('ONT');
                    mo_global.set_policy_context ('S', gn_org_id);

                    oe_order_pub.process_order (
                        p_operating_unit         => gn_org_id,         --NULL,
                        p_api_version_number     => ln_api_version_number,
                        p_header_rec             => l_header_rec,
                        p_line_tbl               => l_line_tbl,
                        p_action_request_tbl     => l_action_request_tbl,
                        x_header_rec             => l_header_rec_out,
                        x_header_val_rec         => l_header_val_rec_out,
                        x_header_adj_tbl         => l_header_adj_tbl_out,
                        x_header_adj_val_tbl     => l_header_adj_val_tbl_out,
                        x_header_price_att_tbl   => l_header_price_att_tbl_out,
                        x_header_adj_att_tbl     => l_header_adj_att_tbl_out,
                        x_header_adj_assoc_tbl   => l_header_adj_assoc_tbl_out,
                        x_header_scredit_tbl     => l_header_scredit_tbl_out,
                        x_header_scredit_val_tbl   =>
                            l_header_scredit_val_tbl_out,
                        x_line_tbl               => l_line_tbl_out,
                        x_line_val_tbl           => l_line_val_tbl_out,
                        x_line_adj_tbl           => l_line_adj_tbl_out,
                        x_line_adj_val_tbl       => l_line_adj_val_tbl_out,
                        x_line_price_att_tbl     => l_line_price_att_tbl_out,
                        x_line_adj_att_tbl       => l_line_adj_att_tbl_out,
                        x_line_adj_assoc_tbl     => l_line_adj_assoc_tbl_out,
                        x_line_scredit_tbl       => l_line_scredit_tbl_out,
                        x_line_scredit_val_tbl   => l_line_scredit_val_tbl_out,
                        x_lot_serial_tbl         => l_lot_serial_tbl_out,
                        x_lot_serial_val_tbl     => l_lot_serial_val_tbl_out,
                        x_action_request_tbl     => l_action_request_tbl_out,
                        x_return_status          => lc_return_status,
                        x_msg_count              => ln_msg_count,
                        x_msg_data               => lc_msg_data);
                    -- CHECK RETURN STATUS
                    log_records (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                            ' lc_return_status - ' || lc_return_status);

                    --log_records (p_debug => gc_debug_flag, p_message =>' lc_msg_data - '||lc_msg_data || ' -- ln_msg_count - ' ||ln_msg_count);

                    /*****************CHECK RETURN STATUS***********************************/
                    IF lc_return_status = fnd_api.g_ret_sts_success
                    THEN
                        log_records (gc_debug_flag, 'success');
                        log_records (
                            gc_debug_flag,
                               'header.order_number IS: '
                            || TO_CHAR (lc_order_number));
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
                                'Deckers Open Sales Order Conversion Program',
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

                    log_records (
                        gc_debug_flag,
                        'process ORDER ret status IS: ' || lc_return_status);
                    --     log_records (gc_debug_flag,'process ORDER msg data IS: '
                    --                   || lc_msg_data);
                    log_records (
                        gc_debug_flag,
                        'process ORDER msg COUNT IS: ' || ln_msg_count);
                    log_records (
                        gc_debug_flag,
                           'header.order_number IS: '
                        || TO_CHAR (l_header_rec_out.order_number));

                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                        , p_msg_index_out => l_msg_index);
                        log_records (gc_debug_flag,
                                     'message is: ' || lc_msg_data);
                        log_records (gc_debug_flag,
                                     'message index is: ' || l_msg_index);
                    END LOOP;
                END IF;
            --         END IF;
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
        END LOOP;

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

    /* PROCEDURE apply_hold_header_line(p_orig_sys_document_ref     IN VARCHAR2,
                                      p_line_id                   IN NUMBER,
                                      x_return_status             OUT VARCHAR2)
     IS
       ln_api_version_number NUMBER := 1;
       lc_return_status      VARCHAR2(10);
       ln_msg_count          NUMBER;
       ln_hold_id            NUMBER;
       ln_header_id          NUMBER;
       lc_flow_status_code   VARCHAR2(60);
       lc_activity_name      VARCHAR2(60);
       lc_msg_data           VARCHAR2(2000);
       lc_error_message      VARCHAR2(2000);
       ln_cnt                NUMBER;
       lc_order_number       VARCHAR2(60);
       l_msg_index                    NUMBER;

       ln_line_count         NUMBER;
       ln_header_count       NUMBER;
       ex_exception          EXCEPTION;
       -- INPUT VARIABLES FOR PROCESS_ORDER API
       l_header_rec         oe_order_pub.header_rec_type := OE_ORDER_PUB.G_MISS_HEADER_REC;
       l_line_tbl           oe_order_pub.line_tbl_type ;
       l_action_request_tbl oe_order_pub.Request_Tbl_Type;
       -- OUT VARIABLES FOR PROCESS_ORDER API
       l_header_rec_out             oe_order_pub.header_rec_type;
       l_header_val_rec_out         oe_order_pub.header_val_rec_type;
       l_header_adj_tbl_out         oe_order_pub.header_adj_tbl_type;
       l_header_adj_val_tbl_out     oe_order_pub.header_adj_val_tbl_type;
       l_header_price_att_tbl_out   oe_order_pub.header_price_att_tbl_type;
       l_header_adj_att_tbl_out     oe_order_pub.header_adj_att_tbl_type;
       l_header_adj_assoc_tbl_out   oe_order_pub.header_adj_assoc_tbl_type;
       l_header_scredit_tbl_out     oe_order_pub.header_scredit_tbl_type;
       l_header_scredit_val_tbl_out oe_order_pub.header_scredit_val_tbl_type;
       l_line_tbl_out               oe_order_pub.line_tbl_type;
       l_line_val_tbl_out           oe_order_pub.line_val_tbl_type;
       l_line_adj_tbl_out           oe_order_pub.line_adj_tbl_type;
       l_line_adj_val_tbl_out       oe_order_pub.line_adj_val_tbl_type;
       l_line_price_att_tbl_out     oe_order_pub.line_price_att_tbl_type;
       l_line_adj_att_tbl_out       oe_order_pub.line_adj_att_tbl_type;
       l_line_adj_assoc_tbl_out     oe_order_pub.line_adj_assoc_tbl_type;
       l_line_scredit_tbl_out       oe_order_pub.line_scredit_tbl_type;
       l_line_scredit_val_tbl_out   oe_order_pub.line_scredit_val_tbl_type;
       l_lot_serial_tbl_out         oe_order_pub.lot_serial_tbl_type;
       l_lot_serial_val_tbl_out     oe_order_pub.lot_serial_val_tbl_type;
       l_action_request_tbl_out     oe_order_pub.request_tbl_type;

     BEGIN
       -- INITIALIZE ENVIRONMENT

   --    fnd_global.apps_initialize(user_id      => p_user_id,
   --                           resp_id          => p_resp_id,
   --                           resp_appl_id     => p_resp_app_id);
   --    mo_global.set_policy_context('S', p_org_id);

       --added by amol on 21-may-15
        -- log_records (gc_debug_flag,'apply hold  p_header_rec.org_id ' ||p_header_rec.org_id );
         log_records (gc_debug_flag,'apply hold  pl_header_rec.org_id  ' ||l_header_rec.org_id );
         log_records (gc_debug_flag,'apply hold  gn_org_id  ' ||gn_org_id );
         --log_records (gc_debug_flag,'apply hold  p_org_id ' ||p_org_id);
         log_records (gc_debug_flag,'apply hold  gn_user_id ' ||gn_user_id );
         log_records (gc_debug_flag,'apply hold   gn_resp_id ' ||gn_resp_id );
         log_records (gc_debug_flag,'apply hold gn_resp_appl_id ' ||gn_resp_appl_id );

          FND_GLOBAL.APPS_INITIALIZE(gn_user_id, gn_resp_id, gn_resp_appl_id);
          mo_global.init('ONT');
          mo_global.set_policy_context ('S',gn_org_id);

           log_records (gc_debug_flag,'Calling apply_hold_header_line Order API');
            ln_cnt := 0;
            FOR holds in (SELECT * FROM xxd_conv.xxd_1206_order_holds_t WHERE ORIG_SYS_DOCUMENT_REF =  p_orig_sys_document_ref)
            LOOP

              lc_error_message := NULL;

              --Get hold id
                BEGIN
                 ln_hold_id       := NULL;
                 ln_header_id     := NULL;
                 lc_activity_name := NULL;
                 lc_order_number  := NULL;
                 log_records (gc_debug_flag,'Calling holds.hold_name Order API' ||holds.hold_name);

                SELECT hold_id
                     --  ,DECODE(activity_name,'BOOK_ORDER','BOOKED','XXXXX')
                     --Added by meenakshi 15-may
                     -- ,DECODE(activity_name,'BOOK_ORDER','BOOKED','XXXXX')
                      ,DECODE(activity_name,'BOOK_ORDER','BOOKED','ENTERED')
                 INTO ln_hold_id
                     ,lc_activity_name
                 FROM oe_hold_definitions
                 WHERE NAME = holds.hold_name;
                  log_records (gc_debug_flag,'ln_hold_id' ||ln_hold_id);
                  log_records (gc_debug_flag,'lc_activity_name' ||lc_activity_name);

                  log_records (gc_debug_flag,'Calling holds.hold_name Order API' ||holds.orig_sys_document_ref);
                 SELECT flow_status_code
                       ,order_number
                       ,header_id
                 INTO  lc_flow_status_code
                      ,lc_order_number
                      ,ln_header_id
                 FROM oe_order_headers_all
                 WHERE ORIG_SYS_DOCUMENT_REF = holds.orig_sys_document_ref;

                  log_records (gc_debug_flag,'lc_flow_status_code' ||lc_flow_status_code);
                  log_records (gc_debug_flag,'lc_order_number' ||lc_order_number);
                  log_records (gc_debug_flag,'ln_header_id' ||ln_header_id);


               log_records (gc_debug_flag,'Calling holds.lc_activity_name Order API' ||lc_activity_name);
               IF NVL(lc_activity_name,'XXXXX') = lc_flow_status_code  THEN
             --Added by meenakshi 15-may
             ---IF NVL(lc_activity_name,lc_flow_status_code ) = lc_flow_status_code  THEN
                 if  lc_flow_status_code <>'ENTERED' then
                   lc_error_message := lc_error_message || ' Hold On Workflow Activity, Book Order Is Not Applicable To The Sales Order - '||lc_order_number ||'. ';
                   xxd_common_utils.record_error
                                               ('ONT',
                                                gn_org_id,
                                                'Deckers Open Sales Order Conversion Program',
                                          --      SQLCODE,
                                                'APPLY_HOLD_HEADER_LINE'||lc_error_message,
                                                DBMS_UTILITY.format_error_backtrace,
                                             --   DBMS_UTILITY.format_call_stack,
                                            --    SYSDATE,
                                               gn_user_id,
                                                gn_conc_request_id,
                                                 'ORDER NUMBER'
                                                , lc_order_number
                                                );
                end if;
               ELSE
                 --This is to apply hold an order header or line
                 --ln_cnt :=   1;
                  ln_cnt := ln_cnt + 1;
                  l_header_rec := oe_order_pub.g_miss_header_rec;

                  l_action_request_tbl (ln_cnt)              := oe_order_pub.g_miss_request_rec;
                  l_action_request_tbl (ln_cnt).entity_id    := ln_header_id;
                  l_action_request_tbl (ln_cnt).entity_code  := OE_GLOBALS.G_ENTITY_HEADER;
                  l_action_request_tbl (ln_cnt).request_type := OE_GLOBALS.G_APPLY_HOLD;
                  l_action_request_tbl (ln_cnt).param1       := ln_hold_id;    -- hold_id
                  l_action_request_tbl (ln_cnt).param2       := 'O';   -- indicator that it is an order hold
                  --l_action_request_tbl (ln_cnt).param3       :=holds.hold_entity_id; --added by amol
                  l_action_request_tbl (ln_cnt).param3       := ln_header_id; -- Header or LINE ID of the order
                  l_action_request_tbl (ln_cnt).param4       := holds.hold_comment; -- hold comments

       --           l_action_request_tbl (ln_cnt).date_param1  := holds.hold_until_date; -- hold until date

       log_records (gc_debug_flag,'Calling l_action_request_tbl.count Order API' ||l_action_request_tbl.count);
       IF l_action_request_tbl.count > 0  THEN
          oe_msg_pub.Initialize;
          -- CALL TO PROCESS Order
                               FND_GLOBAL.APPS_INITIALIZE(gn_user_id, gn_resp_id, gn_resp_appl_id);
                               mo_global.init('ONT');
                               mo_global.set_policy_context ('S',gn_org_id);

          oe_order_pub.process_order( p_operating_unit     => gn_org_id,--NULL,
                                      p_api_version_number => ln_api_version_number,
                                      p_header_rec         => l_header_rec,
                                      p_line_tbl           => l_line_tbl,
                                      p_action_request_tbl => l_action_request_tbl,
                                      x_header_rec             => l_header_rec_out,
                                      x_header_val_rec         => l_header_val_rec_out,
                                      x_header_adj_tbl         => l_header_adj_tbl_out,
                                      x_header_adj_val_tbl     => l_header_adj_val_tbl_out,
                                      x_header_price_att_tbl   => l_header_price_att_tbl_out,
                                      x_header_adj_att_tbl     => l_header_adj_att_tbl_out,
                                      x_header_adj_assoc_tbl   => l_header_adj_assoc_tbl_out,
                                      x_header_scredit_tbl     => l_header_scredit_tbl_out,
                                      x_header_scredit_val_tbl => l_header_scredit_val_tbl_out,
                                      x_line_tbl               => l_line_tbl_out,
                                      x_line_val_tbl           => l_line_val_tbl_out,
                                      x_line_adj_tbl           => l_line_adj_tbl_out,
                                      x_line_adj_val_tbl       => l_line_adj_val_tbl_out,
                                      x_line_price_att_tbl     => l_line_price_att_tbl_out,
                                      x_line_adj_att_tbl       => l_line_adj_att_tbl_out,
                                      x_line_adj_assoc_tbl     => l_line_adj_assoc_tbl_out,
                                      x_line_scredit_tbl       => l_line_scredit_tbl_out,
                                      x_line_scredit_val_tbl   => l_line_scredit_val_tbl_out,
                                      x_lot_serial_tbl         => l_lot_serial_tbl_out,
                                      x_lot_serial_val_tbl     => l_lot_serial_val_tbl_out,
                                      x_action_request_tbl     => l_action_request_tbl_out,
                                      x_return_status          => lc_return_status,
                                      x_msg_count              => ln_msg_count,
                                      x_msg_data               => lc_msg_data);
           -- CHECK RETURN STATUS
               log_records (p_debug => gc_debug_flag, p_message =>' lc_return_status - '||lc_return_status);
               log_records (p_debug => gc_debug_flag, p_message =>' lc_msg_data - '||lc_msg_data || ' -- ln_msg_count - ' ||ln_msg_count);


             IF lc_return_status = fnd_api.g_ret_sts_success
             THEN

                   log_records (gc_debug_flag,'success');
                   log_records (gc_debug_flag,'header.order_number IS: '
                                 || TO_CHAR (lc_order_number));
             ELSE

                   FOR i IN 1 .. ln_msg_count
                     LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data, p_msg_index_out => l_msg_index);
                        log_records (gc_debug_flag,'message is: ' || lc_msg_data);
                        log_records (gc_debug_flag,'message index is: ' || l_msg_index);

                        xxd_common_utils.record_error
                                           ('ONT',
                                            gn_org_id,
                                            'Deckers Open Sales Order Conversion Program',
                                      --      SQLCODE,
                                            'APPLY_HOLD_HEADER_LINE =>'||lc_msg_data,
                                            DBMS_UTILITY.format_error_backtrace,
                                         --   DBMS_UTILITY.format_call_stack,
                                        --    SYSDATE,
                                           gn_user_id,
                                           gn_conc_request_id,
                                           'ORDER NUMBER'
                                           , lc_order_number
                                            );
                     END LOOP;
             END IF;


    log_records (gc_debug_flag,'****************************************************');


                 log_records (gc_debug_flag,'process ORDER ret status IS: '
                                     || lc_return_status);
            --     log_records (gc_debug_flag,'process ORDER msg data IS: '
                  --                   || lc_msg_data);
                 log_records (gc_debug_flag,'process ORDER msg COUNT IS: '
                                     || ln_msg_count);
                 log_records (gc_debug_flag,'header.order_number IS: '
                                     || TO_CHAR (l_header_rec_out.order_number));

       END IF;
                   END IF;
         EXCEPTION
                 WHEN NO_DATA_FOUND THEN
                       log_records (p_debug => gc_debug_flag, p_message => 'The hold '
                                       ||holds.hold_name
                                       ||' is not defined');
                   lc_error_message := 'The hold '||holds.hold_name ||' is not defined';
                   ln_hold_id := NULL;
                   RAISE ex_exception;
                 WHEN OTHERS THEN
                       log_records (p_debug => gc_debug_flag, p_message => 'Error while getting hold id:'
                                        ||SQLERRM);
                   lc_error_message := 'Error while getting hold id:'||SQLERRM;
                   ln_hold_id := NULL;
                   RAISE ex_exception;
               END;
              END LOOP;
     x_return_status := lc_return_status ;
     EXCEPTION
       WHEN ex_exception THEN
     x_return_status := 'E';
      log_records (gc_debug_flag,'Calling holds.lc_activity_name Order API' ||SQLERRM);
       WHEN OTHERS THEN
   log_records (gc_debug_flag,'Calling holds.lc_activity_name Order API' ||SQLERRM);
     x_return_status := 'E';
     END apply_hold_header_line;*/


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
    /*PROCEDURE pick_confirm(
                           p_sch_ship_date       IN       DATE,
                           x_return_mesg         OUT      VARCHAR2,
                           x_return_sts          OUT      VARCHAR2
                          )
    IS

    lv_trolin_tbl            INV_MOVE_ORDER_PUB.trolin_tbl_type;
    lv_mold_tbl              INV_MO_LINE_DETAIL_UTIL.g_mmtt_tbl_type;
    x_mmtt_tbl               INV_MO_LINE_DETAIL_UTIL.g_mmtt_tbl_type;
    x_trolin_tbl             INV_MOVE_ORDER_PUB.trolin_tbl_type;
    lv_transaction_date      DATE := SYSDATE;
    ln_mo_line_id            NUMBER ;

    lc_msg_data              VARCHAR2 (2000);
    lc_x_msg_data            VARCHAR2 (2000);
    ln_x_msg_count           NUMBER;
    lc_x_return_status       VARCHAR2 (1);
    lc_msg_index_out         NUMBER;
    log_msg                  VARCHAR2(4000);

    -----------------------------------------------------
    -- Cursor to get delivery detail id to process pick confirm
    -----------------------------------------------------
    CURSOR cur_get_details ( p_sch_shiping_date  DATE)
    IS
    SELECT rowid,a.*
    FROM   XXD_ONT_SHIP_CONFIRM_CONV_TBL a
    WHERE  status               = gc_validate_status
    AND    request_id           = GN_CONC_REQUEST_ID
    AND    released_status      = 'S'
    AND    trunc(sch_ship_date) = trunc(p_sch_shiping_date);


    BEGIN

        x_return_sts            := GC_API_SUCCESS;
        log_msg       := 'Start of Procedure pick_confirm ';
    --    log_msg := (GC_SOURCE_PROGRAM);
        log_records (p_debug => gc_debug_flag, p_message => log_msg);

        -- open the cursor to transact move order
        FOR get_move_rec IN cur_get_details (p_sch_ship_date)
        LOOP

            ln_mo_line_id             := NULL;
            x_return_mesg             := NULL;
            lc_x_return_status        := NULL;
            ln_x_msg_count            := NULL;
            lc_x_msg_data             := NULL;
            lc_msg_index_out          := NULL;

            -- Fetch the Move Order Line ID for the delivery detail ID
            --
            BEGIN
                SELECT  move_order_line_id
                INTO    ln_mo_line_id
                FROM    wsh_delivery_details
                WHERE   delivery_detail_id    = get_move_rec.delivery_detail_id
                AND     trunc(date_scheduled) = trunc(get_move_rec.sch_ship_date) ;

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    --FND_FILE.PUT_LINE(FND_FILE.LOG,'in exception getting line mover order');
                    x_return_mesg := 'No Data found while Fetching Move Order Line ID for delivery detail_id: '
                           ||get_move_rec.delivery_detail_id ||' Error:'|| SQLERRM;
                    FND_FILE.PUT_LINE(FND_FILE.LOG,x_return_mesg);

                WHEN OTHERS THEN
                    --FND_FILE.PUT_LINE(FND_FILE.LOG,'others in exception getting line mover order');
                    x_return_mesg := 'Error while Fetching the Move Order Line ID for delivery detail_id: '
                           ||get_move_rec.delivery_detail_id||' Error:'|| SQLERRM;
                    FND_FILE.PUT_LINE(FND_FILE.LOG,x_return_mesg);
            END;


            IF ln_mo_line_id IS NOT NULL THEN

                log_msg := (' Transact move order for move order line ID: '||ln_mo_line_id
                                  || ' delivery detail id ' || get_move_rec.delivery_detail_id );
                log_records (p_debug => gc_debug_flag, p_message => log_msg);

                lv_trolin_tbl(1).line_id := ln_mo_line_id;

                ---------------------------------------
                -- Calling Move Order Transact API
                ---------------------------------------
                inv_pick_wave_pick_confirm_pub.pick_confirm
                        (
                            p_api_version_number => 1.0
                           ,p_init_msg_list      => FND_API.G_FALSE
                           ,p_commit             => FND_API.G_FALSE
                           ,x_return_status      => lc_x_return_status
                           ,x_msg_count          => ln_x_msg_count
                           ,x_msg_data           => lc_x_msg_data
                           ,p_move_order_type    => 1
                           ,p_transaction_mode   => 1
                           ,p_trolin_tbl         => lv_trolin_tbl
                           ,p_mold_tbl           => lv_mold_tbl
                           ,x_mmtt_tbl           => x_mmtt_tbl
                           ,x_trolin_tbl         => x_trolin_tbl
                           ,p_transaction_date   => p_sch_ship_date
                         );

                IF lc_x_return_status <> 'S' THEN

                    -- Retrieve the error
                    FOR i in 1..ln_x_msg_count
                    LOOP

                        fnd_msg_pub.get
                        (
                         p_msg_index     => i,
                         p_encoded       => 'F',
                         p_data          => lc_msg_data,
                         p_msg_index_out => lc_msg_index_out
                        );

                        x_return_mesg  := ' API Error while Transacting Move Order: ' ||lc_msg_data;
                        log_msg := (x_return_mesg);
                        log_records (p_debug => gc_debug_flag, p_message => log_msg);

                    END LOOP;

                    ------------------------------------------------
                    -- Update the status on staging table
                    ------------------------------------------------
                    BEGIN
                        UPDATE  XXD_ONT_SHIP_CONFIRM_CONV_TBL
                        SET     status                  = gc_error_status,
                                error_message           = X_Return_Mesg
                        WHERE   request_id              = GN_CONC_REQUEST_ID
                        AND     status                  = gc_validate_status
                        AND     trunc(sch_ship_date)    = trunc(get_move_rec.sch_ship_date)
                        AND     delivery_detail_id      = get_move_rec.delivery_detail_id;

                    EXCEPTION
                        WHEN OTHERS THEN
                            X_Return_Mesg  :=   'In pick confirm, While update header table status Error  ' || SQLERRM;
                            x_return_sts   :=    gc_error_status ;
                            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
                    END;


                    log_msg := ('After call to Transacting Move Order status is ' || gc_error_status);
                    x_return_sts            := gc_error_status;
                    log_records (p_debug => gc_debug_flag, p_message => log_msg);


                ELSE
                    ------------------------------------------------
                    -- Update the status on staging table
                    ------------------------------------------------
                    BEGIN
                        UPDATE  XXD_ONT_SHIP_CONFIRM_CONV_TBL
                        SET     released_status         = 'Y'
                        WHERE   request_id              = GN_CONC_REQUEST_ID
                        AND     status                  = gc_validate_status
                        AND     trunc(sch_ship_date)    = trunc(get_move_rec.sch_ship_date)
                        AND     delivery_detail_id      = get_move_rec.delivery_detail_id;


                    EXCEPTION
                        WHEN OTHERS THEN
                            X_Return_Mesg  :=   'In pick confirm,While update header table status success  ' || SQLERRM;
                            x_return_sts   :=    gc_error_status ;
                            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
                    END;

                    log_msg := ('After Transacting Move Order status is  ' || lc_x_return_status);
                    x_return_sts            := lc_x_return_status;
                    log_records (p_debug => gc_debug_flag, p_message => log_msg);
                END IF; -- IF lc_x_return_status <> 'S' THEN

            ELSE

                ------------------------------------------------
                -- Update the status on staging table
                ------------------------------------------------
                BEGIN
                    UPDATE  XXD_ONT_SHIP_CONFIRM_CONV_TBL
                    SET     status                  = gc_error_status,
                            error_message           = 'Transact Move Order is failed , Move Order line id is missing'
                    WHERE   request_id              = GN_CONC_REQUEST_ID
                    AND     status                  = gc_validate_status
                    AND     trunc(sch_ship_date)    = trunc(get_move_rec.sch_ship_date)
                    AND     delivery_detail_id      = get_move_rec.delivery_detail_id;

                EXCEPTION
                    WHEN OTHERS THEN
                        X_Return_Mesg  :=   'In pick confirm,While update header table status to error message  ' || SQLERRM;
                        x_return_sts   :=    gc_error_status ;
                        FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
                END;

                log_msg       := ( 'Transacting Move Order line status is ' || gc_error_status);
                x_return_sts  := gc_error_status;
                log_records (p_debug => gc_debug_flag, p_message => log_msg);

            END IF; -- IF ln_mo_line_id IS NOT NULL THEN
        END LOOP;

        COMMIT;
        log_msg := 'End of Procedure pick_confirm ';
    --    log_msg := (GC_SOURCE_PROGRAM);
        log_records (p_debug => gc_debug_flag, p_message => log_msg);


    EXCEPTION
        WHEN OTHERS THEN
            x_return_mesg   := 'The procedure pick_confirm Failed  ' || SQLERRM;
            x_return_sts    := gc_error_status;
            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
            RAISE_APPLICATION_ERROR(-20003, SQLERRM);
    END pick_confirm;*/


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
    /*PROCEDURE Ship_confirm(
                           p_sch_ship_date          IN       DATE,
                           x_return_mesg            OUT      VARCHAR2,
                           x_return_sts             OUT      VARCHAR2
                          )




    IS
    lc_x_msg_data               VARCHAR2 (2000);
    ln_x_msg_count              NUMBER;
    lc_x_return_status          VARCHAR2 (1);
    x_trip_id                   WSH_TRIPS.TRIP_ID%TYPE;
    x_trip_name                 WSH_TRIPS.NAME%TYPE;
    lc_msg_index_out            NUMBER;
    ln_ship_confirm_rule_id     NUMBER;
    lc_ship_confirm_rule_name   VARCHAR2(2000);
    error_exception             EXCEPTION;
    x_msg_details               VARCHAR2(4000);
    x_msg_summary               VARCHAR2(4000);
    l_msg_count                 NUMBER;
    ln_delivery_id              NUMBER;
    log_msg                     VARCHAR2(4000);

    -----------------------------------------------------
    -- Cursor to get delivery id to process ship confirm
    -----------------------------------------------------
    CURSOR cur_get_details ( p_sch_shiping_date  DATE)
    IS
    SELECT distinct delivery_id,ship_from_org_id
    FROM   XXD_ONT_SHIP_CONFIRM_CONV_TBL a
    WHERE  status               = gc_validate_status
    AND    request_id           = GN_CONC_REQUEST_ID
    AND    released_status      = 'Y'
    AND    trunc(sch_ship_date) = trunc(p_sch_shiping_date);

    BEGIN

        x_return_sts            := GC_API_SUCCESS;
        log_msg       := 'Start of Procedure Ship_confirm ';
    --    log_msg := (GC_SOURCE_PROGRAM);
        log_records (p_debug => gc_debug_flag, p_message => log_msg);


        ------------------------------------------------
        -- Open cursor and pass variables
        ------------------------------------------------
        FOR ship_rec IN cur_get_details (p_sch_ship_date)
        LOOP

            ln_ship_confirm_rule_id   := NULL;
            lc_ship_confirm_rule_name := NULL;
            x_msg_details             := NULL;
            x_msg_summary             := NULL;
            x_return_mesg             := NULL;
            lc_x_return_status        := NULL;
            ln_x_msg_count            := NULL;
            lc_x_msg_data             := NULL;
            -----------------------------
            -- derive ship confirm rule
            ----------------------------
            BEGIN

                SELECT wsr.ship_confirm_rule_id,
                       wsr.name
                INTO   ln_ship_confirm_rule_id,
                       lc_ship_confirm_rule_name
                FROM   wsh_ship_confirm_rules_v wsr,
                       wsh_shipping_parameters  wsp
                WHERE  wsp.organization_id      = ship_rec.ship_from_org_id
                AND    wsr.ship_confirm_rule_id = wsp.ship_confirm_rule_id
                AND    NVL (effective_start_date, TRUNC (SYSDATE)) <= TRUNC (SYSDATE)
                AND    NVL (effective_end_date, TRUNC (SYSDATE))   >= TRUNC (SYSDATE);

            EXCEPTION
                WHEN OTHERS THEN
                    x_return_mesg := 'Error while Fetching the Ship confirm rule: for Delivery Detail id '
                           || ship_rec.delivery_id||' Error:'||SQLERRM;
                    FND_FILE.PUT_LINE(FND_FILE.LOG,x_return_mesg);
                    ------------------------------------------------
                    -- Update the status on staging table
                    ------------------------------------------------
                    BEGIN
                        UPDATE  XXD_ONT_SHIP_CONFIRM_CONV_TBL
                        SET     status                  = gc_error_status,
                                error_message           = X_Return_Mesg
                        WHERE   request_id              = GN_CONC_REQUEST_ID
                        AND     status                  = gc_validate_status
                        AND     trunc(sch_ship_date)    = p_sch_ship_date
                        AND     delivery_id             = ship_rec.delivery_id;

                    EXCEPTION
                        WHEN OTHERS THEN
                            X_Return_Mesg  :=   'During Ship confirm rule, update table to error ' || SQLERRM;
                            x_return_sts   :=    gc_error_status ;
                            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
                    END;

            END;

            IF ship_rec.delivery_id IS NOT NULL
            AND ln_ship_confirm_rule_id IS NOT NULL THEN

                log_msg := ( ' Ship confirm for Delivery id  '||ship_rec.delivery_id );
                log_records (p_debug => gc_debug_flag, p_message =>log_msg);

                ---------------------------------------
                -- Call API to Ship Confirm
                ---------------------------------------
                Wsh_Deliveries_Pub.Delivery_Action
                        (
                          p_api_version_number     => 1.0,
                          p_init_msg_list          => Fnd_Api.G_FALSE,
                          x_return_status          => lc_x_return_status,
                          x_msg_count              => ln_x_msg_count,
                          x_msg_data               => lc_x_msg_data,
                          p_action_code            => 'CONFIRM',
                          p_delivery_id            =>  ship_rec.delivery_id,
                          p_delivery_name          => TO_CHAR( ship_rec.delivery_id),
                          p_sc_action_flag         => 'S',
                          p_sc_close_trip_flag     => 'Y',
                          p_sc_actual_dep_date     => p_sch_ship_date,
                          x_trip_id                => x_trip_id,
                          x_trip_name              => x_trip_name,
                          p_sc_rule_id             => ln_ship_confirm_rule_id,
                          p_sc_rule_name           => lc_ship_confirm_rule_name
                         );

                -- Check for API status
                IF lc_x_return_status NOT IN ( 'S','W') THEN

                    FND_FILE.PUT_LINE(FND_FILE.LOG,'After Call 1 to Ship confirm for Delivery id  '
                               ||ship_rec.delivery_id );

                    WSH_UTIL_CORE.get_messages
                    (
                     p_init_msg_list    => 'Y',
                     x_summary          => x_msg_summary,
                     x_details          => x_msg_details,
                     x_count            => ln_x_msg_count
                    );

                    IF l_msg_count > 1  THEN
                        x_return_mesg := 'API Error in Ship Confirming: '||x_msg_summary||x_msg_details;
                        log_msg := ( x_return_mesg);
                        log_records (p_debug => gc_debug_flag, p_message =>log_msg);
                    ELSE
                        x_return_mesg := 'API Error while Ship Confirming :'||x_msg_summary;
                        log_msg := ( x_return_mesg);
                        log_records (p_debug => gc_debug_flag, p_message =>log_msg);
                    END IF;

                    FND_FILE.PUT_LINE(fnd_file.log, 'status ' || lc_x_return_status || ' ' || x_return_mesg );

                    ------------------------------------------------
                    -- Update the status on staging table
                    ------------------------------------------------
                    BEGIN
                        UPDATE  XXD_ONT_SHIP_CONFIRM_CONV_TBL
                        SET     status                  = gc_error_status,
                                error_message           = X_Return_Mesg
                        WHERE   request_id              = GN_CONC_REQUEST_ID
                        AND     status                  = gc_validate_status
                        AND     trunc(sch_ship_date)    = p_sch_ship_date
                        AND     delivery_id             = ship_rec.delivery_id;

                    EXCEPTION
                        WHEN OTHERS THEN
                            X_Return_Mesg  :=   'During Ship confirm, update table to error ' || SQLERRM;
                            x_return_sts   :=    gc_error_status ;
                            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
                    END;

                ELSE
                    ------------------------------------------------
                    -- Update the status on staging table
                    ------------------------------------------------
                    BEGIN
                        UPDATE  XXD_ONT_SHIP_CONFIRM_CONV_TBL
                        SET     released_status         = 'C',
                                status                  = GC_PROCESSED
                        WHERE   request_id              = GN_CONC_REQUEST_ID
                        AND     status                  = gc_validate_status
                        AND     trunc(sch_ship_date)    = p_sch_ship_date
                        AND     delivery_id             = ship_rec.delivery_id;

                    EXCEPTION
                        WHEN OTHERS THEN
                            X_Return_Mesg  :=   'During Ship confirm, update table to success  ' || SQLERRM;
                            x_return_sts   :=    gc_error_status ;
                            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
                    END;
                END IF; -- IF lc_x_return_status NOT IN ( 'S','W') THEN
            ELSE

                log_msg := ( 'After Calling to Ship confirm for Delivery id ' ||ship_rec.delivery_id );
                log_records (p_debug => gc_debug_flag, p_message =>log_msg);

                x_return_mesg := 'Delivery did not happen for Delivery details ';
                ------------------------------------------------
                -- Update the status on staging table
                ------------------------------------------------
                BEGIN
                    UPDATE  XXD_ONT_SHIP_CONFIRM_CONV_TBL
                    SET     status                  = gc_error_status,
                            error_message           = X_Return_Mesg
                    WHERE   request_id              = GN_CONC_REQUEST_ID
                    AND     status                  = gc_validate_status
                    AND     trunc(sch_ship_date)    = p_sch_ship_date
                    AND     delivery_id             IS NULL;

                EXCEPTION
                    WHEN OTHERS THEN
                        X_Return_Mesg  :=   'During Ship confirm, update table to error delivery id is missing ' || SQLERRM;
                        x_return_sts   :=    gc_error_status ;
                        FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
                END;
            END IF; -- IF ship_rec.delivery_id IS NOT NULL

            log_msg := (  'Ship Confirm status ' || lc_x_return_status);
            log_records (p_debug => gc_debug_flag, p_message =>log_msg);
        END LOOP; -- FOR ship_rec IN cur_get_details (p_sch_ship_date)

        COMMIT;
        log_msg       := 'End of Procedure Ship_confirm ';
    --    log_msg := (  GC_SOURCE_PROGRAM);
        log_records (p_debug => gc_debug_flag, p_message =>log_msg);

    EXCEPTION
        WHEN error_exception THEN
            x_return_mesg   := x_return_mesg;
            x_return_sts    := gc_error_status;
            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
        WHEN OTHERS THEN
            x_return_mesg   := 'The procedure Ship_confirm Failed  ' || SQLERRM;
            x_return_sts    := gc_error_status;
            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
            RAISE_APPLICATION_ERROR(-20003, SQLERRM);
    END Ship_confirm;*/


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
    /*PROCEDURE launch_pick_release_order(
                    p_sch_ship_date         IN      DATE,
                    p_ship_from_org_id      IN      NUMBER,
                    p_order_header_id       IN      NUMBER,
                    x_batch_id              OUT     NUMBER,
                    x_request_id            OUT     NUMBER,
                    x_return_mesg           OUT     VARCHAR2,
                    x_return_sts            OUT     VARCHAR2
                   )
    IS

    -- Declarations for error messages
    lc_msg_data            VARCHAR2 (2000);
    lc_x_msg_data          VARCHAR2 (2000);
    ln_x_msg_count         NUMBER;
    lc_x_return_status     VARCHAR2 (1);
    lc_msg_index_out       NUMBER;
    ln_batch_id            NUMBER;
    ln_request_id          NUMBER;
    ln_x_batch_id          NUMBER;
    error_exception        EXCEPTION;

    -- Api related variables
    t_line_rows            WSH_UTIL_CORE.ID_TAB_TYPE;
    x_del_rows             WSH_UTIL_CORE.ID_TAB_TYPE;
    x_trip_id              WSH_TRIPS.TRIP_ID%TYPE;
    x_trip_name            WSH_TRIPS.NAME%TYPE;
    l_batch_rec            wsh_picking_batches_pub.batch_info_rec;


    -- Declarations for wait request
    lb_req_wait            BOOLEAN;
    lc_phase               VARCHAR2(100);
    lc_status              VARCHAR2(30);
    lc_dev_phase           VARCHAR2(100);
    lc_dev_status          VARCHAR2(100);
    lc_mesg                VARCHAR2(100);
    log_msg                VARCHAR2(4000);



    -------------------------------
    -- Get the pick rules
    ------------------------------
    CURSOR cur_get_pick_rule_dtl
    IS
    SELECT *
    FROM   wsh_picking_rules_v
    WHERE  organization_id       = p_ship_from_org_id ;
    --AND    attribute1            = 'YES';

    BEGIN

        x_return_sts            := GC_API_SUCCESS;
        log_records (p_debug => gc_debug_flag, p_message => 'Start of Procedure launch_pick_release_order ');


        ------------------------------------------------------------
        -- Based on Pick rules assign values to parameter
        ------------------------------------------------------------
        FOR pick_rule_dtl IN cur_get_pick_rule_dtl
        LOOP

            log_records (p_debug => gc_debug_flag, p_message => 'Processing for Pick rule name '|| pick_rule_dtl.picking_rule_name || ' warehouse/ Org id '|| p_ship_from_org_id );


            lc_msg_data            := NULL;
            lc_x_msg_data          := NULL;
            ln_x_msg_count         := NULL;
            lc_x_return_status     := NULL;
            lc_msg_index_out       := NULL;
            ln_batch_id            := NULL;
            ln_request_id          := NULL;
            ln_x_batch_id          := NULL;

            l_batch_rec.order_header_id            := p_order_header_id;
            l_batch_rec.auto_pick_confirm_flag     := 'N';
            l_batch_rec.autocreate_delivery_flag   := pick_rule_dtl.autocreate_delivery_flag;
            l_batch_rec.From_Scheduled_Ship_Date   := to_date(trunc(p_sch_ship_date)|| ' 00:00:00', 'DD-MON-RRRR HH24:MI:SS');
            l_batch_rec.to_Scheduled_Ship_Date     := to_date(trunc(p_sch_ship_date)|| ' 23:59:59', 'DD-MON-RRRR HH24:MI:SS');
            l_batch_rec.Organization_Code          := pick_rule_dtl.warehouse_Code;

            l_batch_rec.append_flag                := pick_rule_dtl.append_flag;
            l_batch_rec.allocation_method          := pick_rule_dtl.allocation_method;
            l_batch_rec.Default_Stage_Subinventory := pick_rule_dtl.Default_Stage_Subinventory;
            l_batch_rec.Pick_Sequence_Rule_Id      := pick_rule_dtl.Pick_Sequence_Rule_Id;


            l_batch_rec.autodetail_pr_flag         := pick_rule_dtl.autodetail_pr_flag;
            l_batch_rec.autopack_flag              := pick_rule_dtl.autopack_flag;
            l_batch_rec.autopack_level             := pick_rule_dtl.autopack_level;
            l_batch_rec.task_planning_flag         := pick_rule_dtl.task_planning_flag;
            l_batch_rec.ac_delivery_criteria       := pick_rule_dtl.ac_delivery_criteria;
            l_batch_rec.include_planned_lines      := pick_rule_dtl.include_planned_lines;


            l_batch_rec.Backorders_Only_Flag       := 'I' ; -- pick_rule_dtl.Backorders_Only_Flag;
            l_batch_rec.Existing_Rsvs_Only_Flag    := 'N';
            l_batch_rec.Organization_Id            := pick_rule_dtl.Organization_Id;
            l_batch_rec.append_flag                := pick_rule_dtl.append_flag;
            l_batch_rec.Task_Planning_Flag         := pick_rule_dtl.Task_Planning_Flag;
            l_batch_rec.ac_Delivery_Criteria       := pick_rule_dtl.ac_Delivery_Criteria;

            ------------------------------------------------------
            -- Call API to Create one batch for each sch ship date
            ------------------------------------------------------
            WSH_PICKING_BATCHES_PUB.CREATE_BATCH
                      (
                      p_api_version        => 1.0,
                      p_init_msg_list      => fnd_api.g_false,
                      p_commit             => fnd_api.g_false,
                      x_return_status      => lc_x_return_status,
                      x_msg_count          => ln_x_msg_count,
                      x_msg_data           => lc_x_msg_data,
                      p_batch_rec          => l_batch_rec,
                      p_batch_prefix       => NULL ,
                      x_batch_id           => ln_x_batch_id
                      );

            -- Check API error status
            IF lc_x_return_status NOT IN (  'S' ,'W')
            THEN

                -- Retrieve the error
                FOR i in 1..ln_x_msg_count
                LOOP

                    fnd_msg_pub.get
                    (
                     p_msg_index     => i,
                     p_encoded       => 'F',
                     p_data          => lc_msg_data,
                     p_msg_index_out => lc_msg_index_out
                    );

                    x_return_mesg  := ' while picking create_batch API ERROR  ' ||lc_msg_data;
                    log_records (p_debug => gc_debug_flag, p_message => x_return_mesg);
                    RAISE error_exception;

                END LOOP;
            ELSE

                FND_FILE.PUT_LINE(fnd_file.log,'The batch_id is ' || ln_x_batch_id );
                ln_batch_id := ln_x_batch_id; -- batch id

                ------------------------------------------------------------
                -- call the API to Pick release through concurrent program
                -- This will submit Pick Selectioin list Generation Program
                ------------------------------------------------------------
                WSH_PICKING_BATCHES_PUB.RELEASE_BATCH
                           (
                             p_api_version   => 1.0,
                             p_init_msg_list => FND_API.G_TRUE,
                             p_commit        => FND_API.G_FALSE,
                             x_return_status => lc_x_return_status ,
                             x_msg_count     => ln_x_msg_count,
                             x_msg_data      => lc_x_msg_data,
                             p_batch_id      => ln_batch_id,
                             p_release_mode  => 'CONCURRENT',
                             x_request_id    => ln_request_id
                          );

                wsh_picking_batches_pkg.commit_work;
                log_msg :=  (' The Request_id submitted ' || ln_request_id);
                log_records (p_debug => gc_debug_flag, p_message => log_msg);
                x_request_id := ln_request_id;

                -- Check API error status
                IF lc_x_return_status NOT IN ( 'S', 'W') THEN

                    -- Retrieve the error
                    FOR i in 1..ln_x_msg_count
                    LOOP

                        fnd_msg_pub.get
                        (
                         p_msg_index     => i,
                         p_encoded       => 'F',
                         p_data          => lc_msg_data,
                         p_msg_index_out => lc_msg_index_out
                        );

                        x_return_mesg  := ' RELEASE_BATCH API ERROR  ' ||lc_msg_data  ;
                        log_records (p_debug => gc_debug_flag, p_message => x_return_mesg);
                        RAISE error_exception;

                    END LOOP;

                ELSE

                    x_return_sts            := GC_API_SUCCESS;
                END IF;

                IF ln_request_id <= 0 THEN
                    X_return_mesg := 'Unable to submit  Pick Selectioin list Generation Program';
                    log_records (p_debug => gc_debug_flag, p_message => x_return_mesg);
                    RAISE error_exception;
                END IF;

                ------------------------------------------------------------
                -- Wait until the Concurrent Request is Completed .
                ------------------------------------------------------------
                lb_req_wait := Fnd_Concurrent.WAIT_FOR_REQUEST (
                                    request_id => ln_request_id,
                                    interval   => 30,
                                    max_wait   => 0,
                                    phase      => lc_phase,
                                    status     => lc_status,
                                    dev_phase  => lc_dev_phase,
                                    dev_status => lc_dev_status,
                                    message    => lc_mesg
                                );

                X_return_mesg := 'Request ' || lc_dev_phase || ', Status - ' || lc_dev_status;
                log_records (p_debug => gc_debug_flag, p_message => x_return_mesg);

            END IF;

            ----------------------------------------------------------
            -- Update the batch and pick selection program request id
            ----------------------------------------------------------
            UPDATE  XXD_ONT_SHIP_CONFIRM_CONV_TBL
            SET     batch_id               = ln_x_batch_id,
                    pick_rel_request_id    = ln_request_id
            WHERE   trunc(sch_ship_date)   = trunc(p_sch_ship_date)
            AND     header_id              = p_order_header_id
            AND     ship_from_org_id       = p_ship_from_org_id
            AND     released_Status        IN ( 'R' ,'B')
            AND     status                 = gc_validate_status
            AND     request_id             = GN_CONC_REQUEST_ID;

        END LOOP; -- FOR pick_rule_dtl IN cur_get_pick_rule_dtl

        COMMIT;

        log_records (p_debug => gc_debug_flag, p_message => 'End of Procedure launch_pick_release_order ');


    EXCEPTION
        WHEN error_exception THEN
            x_return_mesg   := x_return_mesg;
            x_return_sts    := gc_error_status;
            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
            --ROLLBACK;

        WHEN OTHERS THEN
            x_return_mesg   := 'The procedure launch_pick_release Failed  ' || SQLERRM;
            x_return_sts    := gc_error_status;
            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
            RAISE_APPLICATION_ERROR(-20003, SQLERRM);
    END launch_pick_release_order;*/
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
    /*PROCEDURE validate_record_prc(
                    x_return_mesg     OUT      VARCHAR2,
                    x_return_sts      OUT      VARCHAR2
                   )
    IS

    ------------------------------
    -- get the data for Validation
    ------------------------------
    CURSOR cur_validate_details
    IS
    SELECT rowid,a.*
    FROM   XXD_ONT_SHIP_CONFIRM_CONV_TBL a
    WHERE  status     = GC_NEW
    AND    request_id = GN_CONC_REQUEST_ID;

    ---
    -- Declarion of variables
    ----

    inv_period_status               VARCHAR2(30);
    lc_error_mesg                   VARCHAR2(4000);
    lc_concat_error_message         VARCHAR2(4000);
    lc_err_sts                      VARCHAR2(2);
    error_exception                 EXCEPTION;
    log_msg                         VARCHAR2(4000);



    BEGIN

        x_return_sts            := GC_API_SUCCESS;
        log_records (p_debug => gc_debug_flag, p_message =>        'Start of Procedure validate_record_prc ');


        -- open validation cursor
        FOR val_rec IN cur_validate_details
        LOOP

            lc_err_sts              := GC_API_SUCCESS;
            lc_concat_error_message := NULL;
            lc_error_mesg           := NULL;

            -------------------------------------
            -- Check for sch ship date
            -------------------------------------
            IF val_rec.sch_ship_date IS NULL THEN

                lc_err_sts    :=  GC_API_ERROR;
                lc_error_mesg :=  'The Schedule Ship Date is null for Order Number ' || val_rec.order_number
                    || ' AND line id ' || val_rec.line_id ;
                lc_concat_error_message :=  lc_concat_error_message || ' ' || lc_error_mesg;

            ELSE
                -----------------------------------------------------------------------
                -- Derive inv period status for sch ship date
                -----------------------------------------------------------------------
                BEGIN

                    SELECT upper(status)
                    INTO   inv_period_status
                    FROM   org_acct_periods_v
                    WHERE (
                            (   rec_type = 'ORG_PERIOD' AND organization_id = val_rec.ship_from_org_id
                                AND start_date <= trunc(val_rec.sch_ship_date)
                                AND end_date   >= trunc(val_rec.sch_ship_date)
                            )
                            OR    ( rec_type = 'GL_PERIOD'
                            AND period_set_name = 'Accounting'
                            AND accounted_period_type = '1'
                            AND (period_year, period_name) NOT IN
                                                        ( SELECT period_year,
                                                                 period_name
                                                          FROM   org_acct_periods
                                                          WHERE  organization_id = val_rec.ship_from_org_id)
                                                          AND    start_date <= trunc(val_rec.sch_ship_date)
                                                          AND    end_date   >= trunc(val_rec.sch_ship_date)
                                                         )
                         )
                    ORDER BY end_date DESC;

                EXCEPTION
                    WHEN OTHERS THEN
                        x_return_mesg := 'Error while Fetching INV periods for the order number ' || val_rec.order_number
                        || ' AND line id ' || val_rec.line_id || ' - ' || SQLERRM;
                        FND_FILE.PUT_LINE(FND_FILE.LOG,x_return_mesg);
                        RAISE error_exception;
                END;

                -------------------------------------
                -- Check for Inv period status
                -------------------------------------
                IF inv_period_status <> 'OPEN' THEN

                    lc_err_sts    :=  GC_API_ERROR;
                    lc_error_mesg :=  'The Inventory Period is not in Open status for order number ' || val_rec.order_number
                        || ' AND line id ' || val_rec.line_id || ' AND Sch ship date ' || to_char (val_rec.sch_ship_date);
                    lc_concat_error_message := lc_error_mesg;

                END IF;

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
                IF trunc(val_rec.sch_ship_date) > trunc(sysdate) THEN

                    lc_err_sts    :=  GC_API_ERROR;
                    lc_error_mesg :=  'The Scheduel Ship date for Delivery Details ID  ' || val_rec.delivery_detail_id
                        || ' AND Order Number ' || val_rec.order_number || ' has future dated ' ;
                    lc_concat_error_message := lc_error_mesg;

                END IF;
            END IF;  -- IF val_rec.sch_ship_date IS NULL THEN

            --FND_FILE.PUT_LINE(fnd_file.log,'After validation Status of Order number  ' || lc_err_sts);

            ---------------------------------------
            -- Update the status in staging table
            ---------------------------------------
            IF lc_err_sts  =  GC_API_ERROR THEN

                UPDATE  XXD_ONT_SHIP_CONFIRM_CONV_TBL
                SET     status                = gc_error_status,
                        error_message         = lc_concat_error_message
                WHERE   request_id            = GN_CONC_REQUEST_ID
                AND     status                = GC_NEW
                AND     rowid                 = val_rec.rowid;

            ELSIF  lc_err_sts  =  GC_API_SUCCESS THEN

                UPDATE  XXD_ONT_SHIP_CONFIRM_CONV_TBL
                SET     status                = gc_validate_status
                WHERE   request_id            = GN_CONC_REQUEST_ID
                AND     status                = GC_NEW
                AND     rowid                 = val_rec.rowid;

            END IF;
        END LOOP; -- val_rec IN cur_validate_details

        COMMIT;

        log_records (p_debug => gc_debug_flag, p_message => 'End of Procedure validate_record_prc ');


    EXCEPTION
        WHEN error_exception THEN
            x_return_mesg   := x_return_mesg;
            x_return_sts    := GC_API_ERROR;
            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
            --ROLLBACK;

        WHEN OTHERS THEN
            x_return_mesg   := 'The procedure lauch_pick_release Failed  ' || SQLERRM;
            x_return_sts    := GC_API_ERROR;
            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
    END validate_record_prc;*/


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
    /*PROCEDURE process_record_prc(
                                 x_return_mesg    OUT   VARCHAR2,
                                 x_return_sts     OUT   VARCHAR2
                                )
    IS

    ---------------------------------
    -- Cusror to get schedule ship date
    ---------------------------------
    CURSOR cur_get_sch_ship_date
    IS
    SELECT DISTINCT trunc(sch_ship_date)sch_ship_date
    FROM   XXD_ONT_SHIP_CONFIRM_CONV_TBL
    WHERE  status          = gc_validate_status
    AND    request_id      = GN_CONC_REQUEST_ID
    ORDER BY sch_ship_date ASC;

    --------------------------------------
    -- Cusror to get Different warehouse
    -- for the schedule ship date
    --------------------------------------
    CURSOR cur_get_warehouse (p_sch_ship_date  DATE )
    IS
    SELECT DISTINCT --ship_to_location_id,
           ship_from_org_id
    FROM   XXD_ONT_SHIP_CONFIRM_CONV_TBL
    WHERE  status               = gc_validate_status
    AND    request_id           = GN_CONC_REQUEST_ID
    AND    released_status      IN ('R','B')
    AND    trunc(sch_ship_date) = trunc(p_sch_ship_date);


    --------------------------------------
    -- Cusror to get delivery id
    --------------------------------------
    CURSOR cur_get_delivery_dtl (p_sch_ship_date  DATE )
    IS
    SELECT rowid,a.*
    FROM   XXD_ONT_SHIP_CONFIRM_CONV_TBL a
    WHERE  status               = gc_validate_status
    AND    request_id           = GN_CONC_REQUEST_ID
    AND    trunc(sch_ship_date) = trunc(p_sch_ship_date);

    ----------------------------------------------------
    -- Cusror to get data after pick release
    -- and process them to pick confirm and ship confirm
    ----------------------------------------------------
    CURSOR cur_get_order_details ( p_warehouse      NUMBER
                                  ,p_sch_ship_date  DATE
                                 )
    IS
    SELECT DISTINCT header_id
    FROM   XXD_ONT_SHIP_CONFIRM_CONV_TBL a
    WHERE  status               = gc_validate_status
    AND    request_id           = GN_CONC_REQUEST_ID
    AND    ship_from_org_id     = p_warehouse
    AND    trunc(sch_ship_date) = trunc(p_sch_ship_date)
    ORDER BY header_id;


    ----------------------------------------------------
    -- Cusror to get data after pick release
    -- and process them to pick confirm and ship confirm
    ----------------------------------------------------
    CURSOR cur_get_cn_details    ( p_warehouse      NUMBER
                                  ,p_sch_ship_date  DATE
                                 )
    IS
    SELECT DISTINCT cust_account_number
    FROM   XXD_ONT_SHIP_CONFIRM_CONV_TBL a
    WHERE  status               = gc_validate_status
    AND    request_id           = GN_CONC_REQUEST_ID
    AND    ship_from_org_id     = p_warehouse
    AND    trunc(sch_ship_date) = trunc(p_sch_ship_date)
    ORDER BY cust_account_number;




    --
    -- Declartion of variables
    --
    x_batch_id              NUMBER;
    x_request_id            NUMBER;
    x_application_id        NUMBER;
    x_responsibility_id     NUMBER;
    ln_count                NUMBER:= 1;
    ln_exit_flag            NUMBER:= 0;
    lb_flag                 BOOLEAN:= FALSE;
    lc_rollback             EXCEPTION;
    lc_launch_rollback      EXCEPTION;

    lc_released_Status      VARCHAR2(200);
    ln_del_id               NUMBER;
    ln_org_id               NUMBER;
    log_msg                 VARCHAR2(4000);

    BEGIN

        x_return_sts            := GC_API_SUCCESS;
       log_records (p_debug => gc_debug_flag, p_message =>         'Start of Procedure process_record_prc ');
    --    debug(GC_SOURCE_PROGRAM);

        ln_org_id := fnd_profile.VALUE ('ORG_ID');

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
    set_org_context (p_target_org_id    =>     ln_org_id
                    ,p_resp_id          =>     x_responsibility_id
                    ,p_resp_appl_id     =>     x_application_id
                              ) ;

    --    -- Set org id
        BEGIN
            MO_GLOBAL.set_policy_context('S',ln_org_id); -- change this later
        END;
    --
    --    -- set the responsibility and other details
        BEGIN
            fnd_global.apps_initialize
            (
                FND_GLOBAL.USER_ID,
                x_responsibility_id,
                x_application_id
            );
        END;

        -- open the cursor for each sch ship date
        FOR get_sch_ship_date IN cur_get_sch_ship_date
        LOOP

            log_msg := ( ' ********* Start of processing Sch ship date ' || get_sch_ship_date.sch_ship_date);
            log_records (p_debug => gc_debug_flag, p_message =>        log_msg);

            -- open the cursor to get diff warehouses
            FOR get_warehouse_rec IN cur_get_warehouse (get_sch_ship_date.sch_ship_date)
            LOOP

                log_msg :=  ' Before Calling Launch release';
               log_records (p_debug => gc_debug_flag, p_message =>         log_msg);
                x_return_sts  := NULL;
                X_Return_Mesg := NULL;

                ---------------------------------------------------------------------
                -- Call the procedure to pick selection and release
                -- create one batch with combination of each sch ship date, warehouse
                -- Ones pick selection release the batch through concurrent program
                ---------------------------------------------------------------------
    --            IF GB_ORDER_PASSED
    --            AND GB_SSD_PASSED
    --            AND GB_CUST_ACCT_CN_PASSED THEN

                    FND_FILE.PUT_LINE(fnd_file.log, ' All Parameters are True' );
                    FND_FILE.PUT_LINE(fnd_file.log, ' Group the batch based on ship to location ' --|| get_warehouse_rec.ship_to_location_id
                                      || ' and warehouse/ org id ' || get_warehouse_rec.ship_from_org_id) ;

                    FOR process_ord_rec IN cur_get_order_details (get_warehouse_rec.ship_from_org_id,
                                                                  get_sch_ship_date.sch_ship_date)
                    LOOP

                        ---------------------------------------------------------------------
                        -- Call the procedure to pick selection and release
                        ---------------------------------------------------------------------
                        launch_pick_release_order(
                                           p_sch_ship_date          => get_sch_ship_date.sch_ship_date,
                                           p_ship_from_org_id       => get_warehouse_rec.ship_from_org_id ,
                                           p_order_header_id        => process_ord_rec.header_id,
                                           x_batch_id               => x_batch_id,
                                           x_request_id             => x_request_id,
                                           X_Return_Mesg            => X_Return_Mesg,
                                           x_return_sts             => x_return_sts
                                          );

                        log_msg :=  ( ' After launch_pick_release status is ' || x_return_sts ) ;
                        log_records (p_debug => gc_debug_flag, p_message =>         log_msg);
                    END LOOP;


    --            END IF;
            END LOOP; -- FOR get_warehouse_rec IN cur_get_warehouse

            -----------------------------------------------
            -- get the delivery id after pick release
            -----------------------------------------------
            FOR get_del_id IN cur_get_delivery_dtl(get_sch_ship_date.sch_ship_date)
            LOOP

                ln_del_id := NULL;
                BEGIN

                    SELECT delivery_id
                    INTO   ln_del_id
                    FROM   wsh_delivery_assignments wda
                    WHERE  delivery_detail_id = get_del_id.delivery_detail_id;

                EXCEPTION
                    WHEN OTHERS THEN
                        X_Return_Mesg  :=   'get the delivery id for delivery details id ' || get_del_id.delivery_detail_id|| ' errror ' || SQLERRM;
                        x_return_sts   :=    GC_API_ERROR ;
                        FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
                END;

                IF ln_del_id IS NOT NULL THEN

                    UPDATE XXD_ONT_SHIP_CONFIRM_CONV_TBL
                    SET    delivery_id          = ln_del_id,
                           released_status      = 'S'
                    WHERE  request_id           = GN_CONC_REQUEST_ID
                    AND    status               = gc_validate_status
                    AND    delivery_detail_id   = get_del_id.delivery_detail_id
                    AND    trunc(sch_ship_date) = get_sch_ship_date.sch_ship_date;

                ELSE

                    UPDATE XXD_ONT_SHIP_CONFIRM_CONV_TBL
                    SET    status             = gc_error_status,
                           error_message      = ' Delivery ID is missing / Pick release did not happen during Pick Selection List Generation program'
                    WHERE  request_id         = GN_CONC_REQUEST_ID
                    AND    status             = gc_validate_status
                    AND    delivery_detail_id = get_del_id.delivery_detail_id
                    AND    trunc(sch_ship_date) = get_sch_ship_date.sch_ship_date ;

                END IF;
            END LOOP; -- FOR get_del_id IN cur_get_delivery_dtl(get_sch_ship_date.sch_ship_date)

            COMMIT;

            ------------------------------------------------------------------
            -- This procedcure will transact the move order from inventory to staging
            -- Release status will be updated Y in wsh_delivery_details
            -------------------------------------------------------------------
            pick_confirm(
                          p_sch_ship_date       => get_sch_ship_date.sch_ship_date,
                          X_Return_Mesg         => X_Return_Mesg,
                          x_return_sts          => x_return_sts
                        );

            log_msg :=  ( ' After pick_confirm status is ' || x_return_sts ) ;
            log_records (p_debug => gc_debug_flag, p_message =>         log_msg);

            ------------------------------------------------------------------
            -- This procedcure will confirm the shipping
            -- Release status will be updated C in wsh_delivery_details
            ------------------------------------------------------------------
            Ship_confirm(
                         p_sch_ship_date       => get_sch_ship_date.sch_ship_date,
                         X_Return_Mesg         => X_Return_Mesg
                        ,x_return_sts          => x_return_sts
                        );

            log_msg :=  ( ' After Ship_confirm status is ' || x_return_sts );
            log_records (p_debug => gc_debug_flag, p_message =>         log_msg);

            ln_count := ln_count + 1;
            log_msg :=  (  ' ********* End of processing Sch ship date ' || get_sch_ship_date.sch_ship_date);
            log_records (p_debug => gc_debug_flag, p_message =>         log_msg);
        END LOOP; -- FOR get_sch_ship_date IN cur_get_sch_ship_date

        log_records (p_debug => gc_debug_flag, p_message =>        'End of Procedure process_record_prc ');
    --    log_msg :=  ( GC_SOURCE_PROGRAM);
       log_records (p_debug => gc_debug_flag, p_message =>         log_msg);

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            x_return_mesg   := 'The procedure process_record_prc Failed  ' || SQLERRM;
            x_return_sts    := GC_API_ERROR;
            FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
            RAISE_APPLICATION_ERROR(-20003, SQLERRM);
    END process_record_prc;*/

    --This procedure is used to book the sales order
    PROCEDURE book_order (p_header_id IN NUMBER, p_line_in_tbl IN oe_order_pub.line_tbl_type, p_line_out_tbl IN oe_order_pub.line_tbl_type)
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
    BEGIN
        -- INITIALIZE ENVIRONMENT
        log_records (gc_debug_flag, 'Calling Book Order API');
        l_header_rec.header_id                  := p_header_id;
        ln_line_index                           := 1;

        --ln_header_adj_index        :=1;
        FOR line IN 1 .. p_line_out_tbl.COUNT
        LOOP
            IF     p_line_in_tbl (line).schedule_ship_date IS NOT NULL
               AND p_line_in_tbl (line).SOURCE_TYPE_CODE = 'INTERNAL'
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
                l_line_tbl (line)             := oe_order_pub.g_miss_line_rec;
                l_line_tbl (line)             := p_line_out_tbl (line);
                l_line_tbl (line).operation   := oe_globals.g_opr_update;


                l_line_tbl (line).schedule_ship_date   :=
                    p_line_in_tbl (line).schedule_ship_date;


                --l_line_tbl(line).schedule_action_code    := 'SCHEDULE' ;--                    := FND_API.G_MISS_CHAR;
                --l_line_tbl(line).Override_atp_date_code  := 'Y'; --commented by amol
                l_line_tbl (line).visible_demand_flag   :=
                    FND_API.G_MISS_CHAR;
            /* else
              l_line_tbl (line)                        := oe_order_pub.g_miss_line_rec;
                   l_line_tbl(line)                         := p_line_out_tbl(line) ;
                   l_line_tbl(line).operation               := oe_globals.g_opr_update;
                   l_line_tbl(line).schedule_ship_date      := null;
                  l_line_tbl(line).schedule_action_code :=  'UNSCHEDULE';*/

            END IF;

            ln_line_index   := ln_line_index + 1;
        END LOOP;

        l_action_request_tbl (1)                := oe_order_pub.g_miss_request_rec;
        l_action_request_tbl (1).entity_id      := p_header_id;
        l_action_request_tbl (1).entity_code    := OE_GLOBALS.G_ENTITY_HEADER;
        l_action_request_tbl (1).request_type   := OE_GLOBALS.G_BOOK_ORDER;

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
                  FROM xxd_so_ws_lines_conv_stg_t
                 WHERE     ORIGINAL_SYSTEM_LINE_REFERENCE =
                           p_line_in_tbl (line).orig_sys_line_ref
                       AND ORIG_SYS_DOCUMENT_REF = p_orig_sys_document_ref;

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


    PROCEDURE create_order_closed_line (p_ord_org_sys_ref VARCHAR2)
    AS
        CURSOR cur_order_lines IS
            (SELECT ool.line_id, ool.org_id
               FROM xxd_conv.xxd_so_ws_lines_conv_stg_t stgl, oe_order_lines_all ool
              WHERE     stgl.ORIGINAL_SYSTEM_LINE_REFERENCE =
                        ool.ORIG_SYS_LINE_REF
                    AND stgl.ORIG_SYS_DOCUMENT_REF = p_ord_org_sys_ref
                    AND ool.ORIG_SYS_DOCUMENT_REF =
                        stgl.ORIG_SYS_DOCUMENT_REF
                    AND stgl.flow_status_code IN ('CLOSED', 'CANCELLED'));



        l_line_adj_tbl        oe_order_pub.line_adj_tbl_type;

        l_line_tbl            oe_order_pub.line_tbl_type;
        l_closed_line_tbl     oe_order_pub.line_tbl_type;
        ln_line_index         NUMBER := 0;
        l_closed_line_flag    VARCHAR2 (1) := 'N';

        l_return_status       VARCHAR2 (30);
        l_msg_data            VARCHAR2 (256);
        l_msg_count           NUMBER;
        l_msg_index           NUMBER;
        l_data                VARCHAR2 (2000);

        TYPE lt_order_lines_typ IS TABLE OF cur_order_lines%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_order_lines_data   lt_order_lines_typ;

        ln_line_adj_index     NUMBER := 0;
    BEGIN
        log_records (gc_debug_flag, 'Inside closed create_order_line +');

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
                    FND_GLOBAL.APPS_INITIALIZE (gn_user_id,
                                                gn_resp_id,
                                                gn_resp_appl_id);
                    mo_global.init ('ONT');
                    mo_global.set_policy_context (
                        'S',
                        lt_order_lines_data (xc_order_idx).ORG_ID);

                    oe_order_close_util.CLOSE_LINE (
                        p_api_version_number   => 1.0,
                        p_line_id              =>
                            lt_order_lines_data (xc_order_idx).line_id,
                        x_return_status        => l_return_status,
                        x_msg_count            => l_msg_count,
                        x_msg_data             => l_msg_data);

                    wf_engine.AbortProcess (
                        itemtype   => 'OEOL',
                        itemkey    =>
                            TO_CHAR (
                                lt_order_lines_data (xc_order_idx).line_id), --activity => l_activity_name,
                        RESULT     => 'SUCCESS');
                    COMMIT;
                END LOOP;
            END IF;
        END LOOP;

        --   x_closed_line_flag := l_closed_line_flag;


        CLOSE cur_order_lines;
    --  x_retrun_status := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Un-expecetd Error in  create_order_line => ' || SQLERRM);
    --    ROLLBACK;
    --  x_retrun_status := 'E';
    END create_order_closed_line;

    PROCEDURE relink_return_lines (p_ord_org_sys_ref VARCHAR2)
    AS
        CURSOR cur_order_line IS
            SELECT stg.ORIG_SYS_DOCUMENT_REF, stg.ORIGINAL_SYSTEM_LINE_REFERENCE, stg.NEW_REFERENCE_LINE_ID,
                   stg.NEW_REFERENCE_HEADER_ID
              FROM xxd_so_ws_lines_conv_stg_t stg, oe_order_lines_all ret1223
             WHERE     stg.LINE_CATEGORY_CODE = 'RETURN'
                   AND stg.RET_ORG_SYS_LINE_REF IS NOT NULL
                   --and stg.NEW_REFERENCE_LINE_ID is null
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

            FORALL I IN 1 .. t_ord_line_tab.COUNT SAVE EXCEPTIONS
                UPDATE oe_order_lines_all
                   SET REFERENCE_HEADER_ID = t_ord_line_tab (i).NEW_REFERENCE_HEADER_ID, REFERENCE_LINE_ID = t_ord_line_tab (i).NEW_REFERENCE_LINE_ID, RETURN_ATTRIBUTE1 = t_ord_line_tab (i).NEW_REFERENCE_HEADER_ID,
                       RETURN_ATTRIBUTE2 = t_ord_line_tab (i).NEW_REFERENCE_LINE_ID
                 WHERE     ORIG_SYS_DOCUMENT_REF =
                           t_ord_line_tab (i).ORIG_SYS_DOCUMENT_REF
                       AND ORIG_SYS_LINE_REF =
                           t_ord_line_tab (i).ORIGINAL_SYSTEM_LINE_REFERENCE;


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


    PROCEDURE create_order1 (p_header_rec oe_order_pub.header_rec_type, p_line_tbl oe_order_pub.line_tbl_type, --   p_closed_line_tbl               oe_order_pub.line_tbl_type,
                                                                                                               p_price_adj_line_tbl oe_order_pub.line_adj_tbl_type
                             , p_price_adj_hdr_tbl oe_order_pub.header_adj_tbl_type, --      p_price_adj_closed_line_tbl     oe_order_pub.line_adj_tbl_type,
                                                                                     --    p_closed_line_flag              VARCHAR2,
                                                                                     p_open_line_flag VARCHAR2, p_action_request_tbl oe_order_pub.request_tbl_type)
    AS
        l_api_version_number           NUMBER := 1;
        --Meenakshi 21-may
        l_return_status                VARCHAR2 (2000);
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
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_hdr_adj_tbl                  oe_order_pub.header_adj_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        l_closed_line_tbl              oe_order_pub.line_tbl_type;
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
        l_order_number                 VARCHAR2 (240);
        l_new_header_id                NUMBER;
        i                              NUMBER;
        lc_error_message               VARCHAR2 (3000);
    --commented by amol

    /*             CURSOR cur_closed_lines(p_header_id NUMBER) IS
                SELECT ool.orig_sys_line_ref
                      ,ool.line_id
                      ,stg.flow_status_code
                FROM   xxd_so_ws_lines_conv_stg_t stg
                      ,oe_order_lines_all          ool
                WHERE  ool.orig_sys_line_ref =
                       stg.original_system_line_reference
                AND    stg.header_id = p_header_id;

                TYPE lt_lines_closed_typ IS TABLE OF cur_closed_lines%ROWTYPE INDEX BY BINARY_INTEGER;

                lt_lines_closed_data lt_lines_closed_typ; */


    BEGIN
        oe_msg_pub.initialize;
        --Meenakshi 21-may
        log_records (gc_debug_flag,
                     'Create order p_line_tbl' || p_line_tbl.COUNT);
        log_records (gc_debug_flag,
                     'Create order l_line_tbl' || l_line_tbl.COUNT);
        log_records (
            gc_debug_flag,
            'Create order p_price_adj_line_tbl' || p_price_adj_line_tbl.COUNT);
        log_records (
            gc_debug_flag,
            'Create order p_price_adj_hdr_tbl' || p_price_adj_hdr_tbl.COUNT);
        log_records (
            gc_debug_flag,
            'Create order p_header_rec.order_number' || p_header_rec.order_number);
        log_records (
            gc_debug_flag,
            'Create order  p_header_rec.invoice_to_org_id ' || p_header_rec.invoice_to_org_id);
        log_records (
            gc_debug_flag,
            'Create order  p_header_rec.org_id' || p_header_rec.org_id);
        log_records (gc_debug_flag, 'Create order  gn_user_id' || gn_user_id);
        log_records (gc_debug_flag, 'Create order  gn_resp_id' || gn_resp_id);
        log_records (gc_debug_flag,
                     'Create order gn_resp_appl_id' || gn_resp_appl_id);
        FND_GLOBAL.APPS_INITIALIZE (gn_user_id, gn_resp_id, gn_resp_appl_id);
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', p_header_rec.org_id);

        --                  COMMIT;
        /*****************CALLTO PROCESS ORDER API*********************************/
        oe_order_pub.process_order (p_api_version_number => l_api_version_number, p_header_rec => p_header_rec, p_line_tbl => p_line_tbl, p_action_request_tbl => l_action_request_tbl, p_action_commit => FND_API.G_FALSE, p_line_adj_tbl => p_price_adj_line_tbl, p_header_adj_tbl => p_price_adj_hdr_tbl-- OUT variables
                                                                                                                                                                                                                                                                                                           , x_header_rec => l_header_rec_out, x_header_val_rec => l_header_val_rec_out, x_header_adj_tbl => l_header_adj_tbl_out, x_header_adj_val_tbl => l_header_adj_val_tbl_out, x_header_price_att_tbl => l_header_price_att_tbl_out, x_header_adj_att_tbl => l_header_adj_att_tbl_out, x_header_adj_assoc_tbl => l_header_adj_assoc_tbl_out, x_header_scredit_tbl => l_header_scredit_tbl_out, x_header_scredit_val_tbl => l_header_scredit_val_tbl_out, x_line_tbl => l_line_tbl_out, x_line_val_tbl => l_line_val_tbl_out, x_line_adj_tbl => l_line_adj_tbl_out, x_line_adj_val_tbl => l_line_adj_val_tbl_out, x_line_price_att_tbl => l_line_price_att_tbl_out, x_line_adj_att_tbl => l_line_adj_att_tbl_out, x_line_adj_assoc_tbl => l_line_adj_assoc_tbl_out, x_line_scredit_tbl => l_line_scredit_tbl_out, x_line_scredit_val_tbl => l_line_scredit_val_tbl_out, x_lot_serial_tbl => l_lot_serial_tbl_out, x_lot_serial_val_tbl => l_lot_serial_val_tbl_out, x_action_request_tbl => l_action_request_tbl_out, x_return_status => l_return_status, x_msg_count => l_msg_count
                                    , x_msg_data => l_msg_data);


        l_new_header_id   := l_header_rec_out.header_id;
        log_records (
            gc_debug_flag,
            'After api call fnd_api.g_ret_sts_success ' || l_return_status);


        /*****************CHECK RETURN STATUS***********************************/

        --  log_records (gc_debug_flag,'3 Closed Flag:Inside create_order main procedure'
        --   ||  (p_closed_line_flag));
        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            -- log_records (gc_debug_flag,'success');
            log_records (
                gc_debug_flag,
                   'header.order_number IS: '
                || TO_CHAR (l_header_rec_out.order_number));

            --  log_records (gc_debug_flag,'4 Closed Flag: Before Book Order '
            --     ||  (p_closed_line_flag));

            log_records (gc_debug_flag, 'Open Flag: ' || (p_open_line_flag));

            --Added by meenakshi 15-may
            /*   IF p_open_line_flag = 'Y' THEN  -- Y'='Y' THEN
                apply_hold_header_line(p_orig_sys_document_ref     => l_header_rec_out.orig_sys_document_ref,
                                       p_line_id                   => NULL,
                                       x_return_status             => l_return_status)   ;
               END IF;*/
            --Added by meenakshi 15-may
            /*   FOR release_rec IN (SELECT oh.header_id header_id,
               oh.line_id line,
               hd.hold_id,
               hd.name hold_name,
               hd.item_type,
               hd.activity_name activity,
               NVL (hd.hold_included_items_flag, 'N') hiif,
               oh.creation_date held_date,
               oe_holds_pvt.user_name (oh.created_by) held_by,
               hs.hold_until_date,
               hs.hold_entity_id2,
               oh.released_flag
             FROM oe_order_holds_all oh, oe_hold_sources_all hs, oe_hold_definitions hd
            WHERE     oh.header_id =  l_new_header_id
               AND oh.released_flag ='N'
               AND oh.hold_source_id = hs.hold_source_id
               AND hd.hold_id = hs.hold_id ) LOOP

                          release_hold (p_header_id    => release_rec.header_id
                                        ,p_hold_id     => release_rec.hold_id
                                       ,x_return_status  => l_return_status);

                              log_records (gc_debug_flag,'RELEASE_FLAG RETURN STATUS'
                                      || l_return_status);
               END LOOP;*/


            book_order (p_header_id      => l_header_rec_out.header_id,
                        p_line_in_tbl    => p_line_tbl,
                        p_line_out_tbl   => l_line_tbl_out);

            unschedule_book_lines (p_header_id => l_header_rec_out.header_id, p_orig_sys_document_ref => l_header_rec_out.orig_sys_document_ref, p_line_in_tbl => p_line_tbl
                                   , p_line_out_tbl => l_line_tbl_out);


            log_records (gc_debug_flag, 'After booking');

            log_records (
                gc_debug_flag,
                'Calling apply_hold_header_line ' || l_header_rec_out.orig_sys_document_ref);

            log_records (
                gc_debug_flag,
                'p_open_line_flag after book order==== ' || p_open_line_flag);

            --  log_records (gc_debug_flag,'p_closed_line_flag after book order==== '||p_closed_line_flag);

            --Added by meenakshi 15-may
            IF p_open_line_flag = 'Y'
            THEN                                                -- Y'='Y' THEN
                apply_hold_header_line (
                    p_orig_sys_document_ref   =>
                        l_header_rec_out.orig_sys_document_ref,
                    p_line_id         => NULL,
                    x_return_status   => l_return_status);
            END IF;

            --log_records(gc_debug_flag,'Before closed lines validation Check');

            --   log_records (gc_debug_flag,'5 Closed Flag:Before close order process procedure'
            --    ||  (p_closed_line_flag));



            -- adding closed lines
            /*  IF p_closed_line_flag = 'Y' THEN
                  log_records(gc_debug_flag,
                              'Updating closed lines table with new header id ' ||
                              l_header_rec_out.header_id);
                  l_closed_line_tbl := p_closed_line_tbl;
                  --l_closed_line_adj_tbl:=p_price_adj_closed_line_tbl;

                  log_records (gc_debug_flag,'l_closed_line_tbl-->==== '||l_closed_line_tbl.count);
  --                l_header_rec :=  NULL;


               -- log_records(gc_debug_flag, 'l_msg_data = '|| l_msg_count);


               IF l_return_status = fnd_api.g_ret_sts_success THEN
               FOR l_closed_line_inx IN l_line_tbl_out.first .. l_line_tbl_out.last
                  LOOP
                       wf_engine.AbortProcess (itemtype => 'OEOL',
                                             itemkey => to_char(l_line_tbl_out(l_closed_line_inx).line_id),                                           --activity => l_activity_name,
                                             RESULT   => 'SUCCESS');
                  END LOOP;
               end if;


              END IF;*/

            create_order_closed_line (l_header_rec_out.orig_sys_document_ref);
            relink_return_lines (l_header_rec_out.orig_sys_document_ref);

            UPDATE XXD_SO_WS_LINES_CONV_STG_T
               SET RECORD_STATUS   = gc_process_status
             WHERE ORIG_SYS_DOCUMENT_REF =
                   l_header_rec_out.orig_sys_document_ref;

            UPDATE XXD_SO_WS_HEADERS_CONV_STG_T
               SET record_status   = gc_process_status
             WHERE ORIGINAL_SYSTEM_REFERENCE =
                   l_header_rec_out.orig_sys_document_ref;



            COMMIT;
        ELSE
            --         IF (l_debug_level > 0)
            --         THEN
            --Meenakshi 21-May
            log_records (gc_debug_flag, 'in Else ');
            log_records (gc_debug_flag, 'Else  l_msg_count' || l_msg_count);

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
                    'Deckers Open Sales Order Conversion Program',
                    --      SQLCODE,
                    l_data,
                    DBMS_UTILITY.format_error_backtrace,
                    --   DBMS_UTILITY.format_call_stack,
                    --    SYSDATE,
                    gn_user_id,
                    gn_conc_request_id,
                    'ORDER NUMBER',
                    l_header_rec_out.ORDER_NUMBER);
            END LOOP;

            ROLLBACK;
            --         END IF;
            log_records (
                gc_debug_flag,
                   'Else  l_header_rec_out.orig_sys_document_ref'
                || l_header_rec_out.orig_sys_document_ref);

            UPDATE XXD_SO_WS_LINES_CONV_STG_T
               SET RECORD_STATUS   = gc_error_status
             WHERE ORIG_SYS_DOCUMENT_REF =
                   l_header_rec_out.orig_sys_document_ref;

            UPDATE XXD_SO_WS_HEADERS_CONV_STG_T
               SET record_status   = gc_error_status
             WHERE ORIGINAL_SYSTEM_REFERENCE =
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
    END create_order1;



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
        apps.XXD_COMMON_UTILS.get_mapping_value (
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
                'Deckers Open Sales Order Conversion Program',
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
        apps.XXD_COMMON_UTILS.get_mapping_value (
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
         WHERE UPPER (NAME) = UPPER (x_attribute1);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'ONT',
                gn_org_id,
                'Deckers Open Sales Order Conversion Program',
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
         WHERE UPPER (NAME) = UPPER (p_org_name);

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
               FROM xxd_so_ws_lines_conv_stg_t cust
              WHERE header_id = p_header_id--  AND flow_status_code NOT IN ('CLOSED', 'CANCELLED')
                                           );

        CURSOR cur_order_lines_adj (p_line_id NUMBER)
        IS
            SELECT *
              FROM xxd_ont_ws_price_adj_l_stg_t cust
             WHERE     header_id = p_header_id
                   AND line_id = p_line_id
                   AND cust.MODIFIER_LEVEL_CODE = 'LINE';

        l_line_tbl            oe_order_pub.line_tbl_type;
        ln_line_index         NUMBER := 0;
        l_line_adj_tbl        oe_order_pub.line_adj_tbl_type;
        l_closed_line_flag    VARCHAR2 (1) := 'Y';
        l_open_line_flag      VARCHAR2 (1) := 'N';

        TYPE lt_order_lines_typ IS TABLE OF cur_order_lines%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_order_lines_data   lt_order_lines_typ;
        -- l_line_adj_tbl            oe_order_pub.line_adj_tbl_type ;
        ln_line_adj_index     NUMBER := 0;

        TYPE lt_lines_adj_typ IS TABLE OF cur_order_lines_adj%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_lines_adj_data     lt_lines_adj_typ;

        l_sales_rep_id        NUMBER;
    BEGIN
        --log_records (gc_debug_flag,'Inside create_order_line +');
        --   l_line_tbl.delete;--Meenakshi 15-May
        --    l_line_adj_tbl.delete; --Meenakshi 21-May

        /*select NEW_SALESREP_ID
        into l_sales_rep_id from xxd_so_ws_headers_conv_stg_t
        where   header_id = p_header_id;*/

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
                    --log_records (gc_debug_flag,'@@500');
                    ln_line_index   := ln_line_index + 1;
                    l_line_tbl (ln_line_index)   :=
                        oe_order_pub.g_miss_line_rec;
                    l_line_tbl (ln_line_index).operation   :=
                        oe_globals.g_opr_create;
                    l_line_tbl (ln_line_index).header_id   :=
                        FND_API.G_MISS_NUM;
                    l_line_tbl (ln_line_index).ordered_item_id   :=
                        FND_API.G_MISS_NUM; --3274788 ;--lt_order_lines_data(xc_order_idx).inventory_item_id;
                    l_line_tbl (ln_line_index).inventory_item_id   :=
                        lt_order_lines_data (xc_order_idx).inventory_item_id;
                    --l_line_tbl(ln_line_index).return_reason_code                    :='CONVERSION';--'Return Reason - Conversion';
                    --l_line_tbl(ln_line_index).ordered_item                        := lt_order_lines_data(xc_order_idx).ITEM_SEGMENT1;
                    l_line_tbl (ln_line_index).line_id   :=
                        FND_API.G_MISS_NUM;
                    l_line_tbl (ln_line_index).line_number   :=
                        lt_order_lines_data (xc_order_idx).line_number;
                    l_line_tbl (ln_line_index).salesrep_id   :=
                        lt_order_lines_data (xc_order_idx).NEW_SALESREP_ID;
                    l_line_tbl (ln_line_index).shipment_priority_code   :=
                        lt_order_lines_data (xc_order_idx).shipment_priority_code;
                    l_line_tbl (ln_line_index).request_date   :=
                        lt_order_lines_data (xc_order_idx).request_date;
                    l_line_tbl (ln_line_index).SHIPPING_INSTRUCTIONS   :=
                        lt_order_lines_data (xc_order_idx).SHIPPING_INSTRUCTIONS;
                    l_line_tbl (ln_line_index).subinventory   :=
                        lt_order_lines_data (xc_order_idx).subinventory;

                    IF lt_order_lines_data (xc_order_idx).new_line_type_id
                           IS NULL
                    THEN
                        l_line_tbl (ln_line_index).line_type_id   :=
                            FND_API.G_MISS_NUM; --lt_order_lines_data(xc_order_idx).new_line_type_id;
                    ELSE
                        l_line_tbl (ln_line_index).line_type_id   :=
                            lt_order_lines_data (xc_order_idx).new_line_type_id;
                    END IF;

                    l_line_tbl (ln_line_index).ordered_quantity   :=
                        lt_order_lines_data (xc_order_idx).ordered_quantity;
                    l_line_tbl (ln_line_index).order_quantity_uom   :=
                        lt_order_lines_data (xc_order_idx).order_quantity_uom;
                    l_line_tbl (ln_line_index).org_id   :=
                        FND_API.G_MISS_NUM;
                    l_line_tbl (ln_line_index).orig_sys_document_ref   :=
                        lt_order_lines_data (xc_order_idx).orig_sys_document_ref; --||TO_CHAR(SYSDATE,'ddmmyyyyhhmiss');                    END LOOP;
                    l_line_tbl (ln_line_index).orig_sys_line_ref   :=
                        lt_order_lines_data (xc_order_idx).ORIGINAL_SYSTEM_LINE_REFERENCE; --||TO_CHAR(SYSDATE,'ddmmyyyyhhmiss');

                    l_line_tbl (ln_line_index).fulfilled_quantity   :=
                        lt_order_lines_data (xc_order_idx).fulfilled_quantity;
                    --    l_line_tbl(ln_line_index).fulfilled_flag                       := 'Y';
                    l_line_tbl (ln_line_index).FULFILLMENT_DATE   :=
                        lt_order_lines_data (xc_order_idx).FULFILLMENT_DATE;
                    l_line_tbl (ln_line_index).ship_from_org_id   :=
                        FND_API.G_MISS_NUM;
                    l_line_tbl (ln_line_index).ship_to_contact_id   :=
                        FND_API.G_MISS_NUM;
                    l_line_tbl (ln_line_index).ship_to_org_id   :=
                        FND_API.G_MISS_NUM;
                    l_line_tbl (ln_line_index).sold_to_org_id   :=
                        FND_API.G_MISS_NUM;
                    l_line_tbl (ln_line_index).sold_from_org_id   :=
                        FND_API.G_MISS_NUM;
                    l_line_tbl (ln_line_index).ship_to_customer_id   :=
                        FND_API.G_MISS_NUM;
                    l_line_tbl (ln_line_index).invoice_to_customer_id   :=
                        FND_API.G_MISS_NUM;
                    l_line_tbl (ln_line_index).deliver_to_customer_id   :=
                        FND_API.G_MISS_NUM;
                    l_line_tbl (ln_line_index).unit_list_price   :=
                        lt_order_lines_data (xc_order_idx).unit_list_price;
                    l_line_tbl (ln_line_index).unit_selling_price   :=
                        lt_order_lines_data (xc_order_idx).unit_selling_price;
                    l_line_tbl (ln_line_index).pricing_date   :=
                        lt_order_lines_data (xc_order_idx).pricing_date;
                    l_line_tbl (ln_line_index).calculate_price_flag   :=
                        'N';
                    l_line_tbl (ln_line_index).shipping_method_code   :=
                        lt_order_lines_data (xc_order_idx).new_shipping_method_code;
                    l_line_tbl (ln_line_index).source_type_code   :=
                        lt_order_lines_data (xc_order_idx).source_type_code;
                    l_line_tbl (ln_line_index).latest_acceptable_date   :=
                        lt_order_lines_data (xc_order_idx).latest_acceptable_date;
                    --Meenakshi 21-sept
                    l_line_tbl (ln_line_index).ship_from_org_id   :=
                        lt_order_lines_data (xc_order_idx).new_ship_from;
                    --Meenakshi 15-Jun
                    l_line_tbl (ln_line_index).actual_shipment_date   :=
                        lt_order_lines_data (xc_order_idx).actual_shipment_date;

                    IF lt_order_lines_data (xc_order_idx).flow_status_code =
                       'CLOSED'
                    THEN
                        l_line_tbl (ln_line_index).flow_status_code   :=
                            'ENTERED';
                        l_line_tbl (ln_line_index).cancelled_flag   := 'N';
                        --meenakshi 24-Aug
                        l_line_tbl (ln_line_index).booked_flag      :=
                            FND_API.G_MISS_CHAR;
                        --  l_line_tbl(ln_line_index).open_flag := 'Y';
                        l_open_line_flag                            := 'Y';
                        l_line_tbl (ln_line_index).fulfilled_quantity   :=
                            lt_order_lines_data (xc_order_idx).fulfilled_quantity;
                        l_line_tbl (ln_line_index).FULFILLMENT_DATE   :=
                            lt_order_lines_data (xc_order_idx).FULFILLMENT_DATE;
                        l_line_tbl (ln_line_index).fulfilled_flag   :=
                            'Y';
                    --  l_closed_line_flag := 'Y';

                    ELSIF lt_order_lines_data (xc_order_idx).flow_status_code =
                          'CANCELLED'
                    THEN
                        l_line_tbl (ln_line_index).flow_status_code   :=
                            'ENTERED';
                        l_line_tbl (ln_line_index).cancelled_flag   := 'Y';
                        l_line_tbl (ln_line_index).cancelled_quantity   :=
                            lt_order_lines_data (xc_order_idx).CANCELLED_QUANTITY;
                        l_line_tbl (ln_line_index).schedule_status_code   :=
                            NULL;
                        l_line_tbl (ln_line_index).schedule_action_code   :=
                            NULL;
                        l_line_tbl (ln_line_index).shipping_method_code   :=
                            lt_order_lines_data (xc_order_idx).NEW_SHIPPING_METHOD_CODE;
                        l_line_tbl (ln_line_index).fulfilled_flag   :=
                            'N';
                        l_line_tbl (ln_line_index).booked_flag      :=
                            FND_API.G_MISS_CHAR;
                    --  l_line_tbl(ln_line_index).open_flag := 'N';
                    --   l_closed_line_flag := 'Y';
                    --Added by meenakshi 15-may
                    ELSE
                        l_line_tbl (ln_line_index).flow_status_code   :=
                            'ENTERED'; --lt_order_lines_data(xc_order_idx).flow_status_code  ;--'ENTERED';
                        l_line_tbl (ln_line_index).booked_flag   :=
                            FND_API.G_MISS_CHAR;
                        l_open_line_flag   := 'Y';
                    END IF;

                    --log_records (gc_debug_flag,'@@400');
                    IF     NVL (p_customer_type, 'XXX') = 'WHOLESALE'
                       AND lt_order_lines_data (xc_order_idx).line_category_code =
                           'RETURN'
                    THEN
                        l_line_tbl (ln_line_index).attribute1    :=
                            TO_CHAR (
                                TO_TIMESTAMP (
                                    lt_order_lines_data (xc_order_idx).attribute1,
                                    'DD-MON-RR'),
                                'YYYY/MM/DD HH24:MI:SS');
                        --l_line_tbl(ln_line_index).attribute1                                :=to_char(FND_DATE.DATE_TO_CANONICAL(to_date (lt_order_lines_data(xc_order_idx).attribute1,'YYYY/MM/DD')));
                        l_line_tbl (ln_line_index).attribute2    := NULL;
                        l_line_tbl (ln_line_index).attribute3    := NULL;
                        l_line_tbl (ln_line_index).attribute4    :=
                            lt_order_lines_data (xc_order_idx).NEW_ATTRIBUTE4; --attribute4;
                        l_line_tbl (ln_line_index).attribute5    :=
                            lt_order_lines_data (xc_order_idx).attribute5;
                        l_line_tbl (ln_line_index).attribute6    :=
                            lt_order_lines_data (xc_order_idx).attribute6;
                        l_line_tbl (ln_line_index).attribute7    :=
                            lt_order_lines_data (xc_order_idx).attribute7;
                        l_line_tbl (ln_line_index).attribute8    :=
                            lt_order_lines_data (xc_order_idx).attribute8;
                        l_line_tbl (ln_line_index).attribute10   :=
                            lt_order_lines_data (xc_order_idx).attribute10;
                        l_line_tbl (ln_line_index).attribute12   :=
                            lt_order_lines_data (xc_order_idx).attribute12;
                        l_line_tbl (ln_line_index).attribute13   := NULL;
                        l_line_tbl (ln_line_index).attribute14   := NULL;
                        l_line_tbl (ln_line_index).attribute15   := NULL;
                        l_line_tbl (ln_line_index).attribute16   := NULL;
                        l_line_tbl (ln_line_index).attribute17   := NULL;
                        l_line_tbl (ln_line_index).attribute18   := NULL;
                        l_line_tbl (ln_line_index).attribute19   := NULL;
                        l_line_tbl (ln_line_index).attribute20   := NULL;
                        l_line_tbl (ln_line_index).override_atp_date_code   :=
                            'N';                               --added by amol
                        -- l_line_tbl(ln_line_index).override_flag                                :='N';
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'l_new_reason_code=> '
                            || lt_order_lines_data (xc_order_idx).new_return_reason_code);
                        l_line_tbl (ln_line_index).return_reason_code   :=
                            lt_order_lines_data (xc_order_idx).new_return_reason_code;
                        l_line_tbl (ln_line_index).return_context   :=
                            lt_order_lines_data (xc_order_idx).return_context;
                        --added by amol
                        l_line_tbl (ln_line_index).drop_ship_flag   :=
                            'N';
                        l_line_tbl (ln_line_index).tax_code      :=
                            lt_order_lines_data (xc_order_idx).new_tax_code;
                        l_line_tbl (ln_line_index).tax_date      :=
                            lt_order_lines_data (xc_order_idx).tax_date;
                        l_line_tbl (ln_line_index).tax_exempt_flag   :=
                            lt_order_lines_data (xc_order_idx).tax_exempt_flag;
                        l_line_tbl (ln_line_index).tax_exempt_number   :=
                            lt_order_lines_data (xc_order_idx).tax_exempt_number;
                        l_line_tbl (ln_line_index).tax_exempt_reason_code   :=
                            lt_order_lines_data (xc_order_idx).tax_exempt_reason_code;
                        l_line_tbl (ln_line_index).tax_point_code   :=
                            lt_order_lines_data (xc_order_idx).tax_point_code;
                        l_line_tbl (ln_line_index).tax_rate      :=
                            lt_order_lines_data (xc_order_idx).tax_rate;
                        l_line_tbl (ln_line_index).tax_value     :=
                            lt_order_lines_data (xc_order_idx).tax_value;
                    --log_records (gc_debug_flag,'@@300');
                    ELSE
                        --log_records (gc_debug_flag,'@@200');
                        l_line_tbl (ln_line_index).attribute1    :=
                            TO_CHAR (
                                TO_TIMESTAMP (
                                    lt_order_lines_data (xc_order_idx).attribute1,
                                    'DD-MON-RR'),
                                'YYYY/MM/DD HH24:MI:SS');
                        l_line_tbl (ln_line_index).attribute2    := NULL;
                        l_line_tbl (ln_line_index).attribute3    := NULL;
                        l_line_tbl (ln_line_index).attribute4    :=
                            lt_order_lines_data (xc_order_idx).NEW_ATTRIBUTE4; --attribute4;
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

                        l_line_tbl (ln_line_index).schedule_arrival_date   :=
                            lt_order_lines_data (xc_order_idx).schedule_arrival_date;
                    /*IF lt_order_lines_data(xc_order_idx).schedule_ship_date IS  NOT NULL THEN

                    l_line_tbl(ln_line_index).schedule_ship_date                      := lt_order_lines_data(xc_order_idx).schedule_ship_date; --added for testing
                    --l_line_tbl(ln_line_index).schedule_arrival_date                      := lt_order_lines_data(xc_order_idx).schedule_ship_date;
                    END IF; */

                    END IF;

                    --log_records (gc_debug_flag,'RETRUN REASON==========  => '||l_line_tbl(ln_line_index).return_reason_code );
                    --log_records (gc_debug_flag,'RETRUN REASON code in lt_order_lines_data ====> '||lt_order_lines_data(xc_order_idx).return_reason_code );
                    --log_records (gc_debug_flag,'@@100');
                    IF     lt_order_lines_data (xc_order_idx).schedule_ship_date
                               IS NOT NULL
                       AND lt_order_lines_data (xc_order_idx).line_category_code <>
                           'RETURN'
                       AND lt_order_lines_data (xc_order_idx).flow_status_code <>
                           'BOOKED'
                    THEN                                     --Meenakshi25-Aug
                        l_line_tbl (ln_line_index).schedule_ship_date   :=
                            lt_order_lines_data (xc_order_idx).schedule_ship_date;
                        --Added by meenakshi 15-may
                        l_line_tbl (ln_line_index).schedule_status_code   :=
                            'SCHEDULED';
                        l_line_tbl (ln_line_index).schedule_action_code   :=
                            'SCHEDULED';
                        l_line_tbl (ln_line_index).override_atp_date_code   :=
                            'Y';
                    END IF;

                    fnd_file.put_line (fnd_file.LOG, '@@1112');

                    IF    lt_order_lines_data (xc_order_idx).source_type_code <>
                          'EXTERNAL'
                       OR p_customer_type = 'RMS'
                    THEN
                        --Added by meenakshi 15-may
                        -- l_line_tbl(ln_line_index).Override_atp_date_code                  := 'Y';
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
                            lt_order_lines_data (xc_order_idx).tax_value;
                    ELSE
                        l_line_tbl (ln_line_index).drop_ship_flag   := 'Y';
                        fnd_file.put_line (fnd_file.LOG, '@@1113');
                    END IF;

                    fnd_file.put_line (fnd_file.LOG, '@@1114');
                    --    END IF;
                    log_records (gc_debug_flag,
                                 'p_header_id  ' || p_header_id);
                    log_records (
                        gc_debug_flag,
                           'l_line_tbl(ln_line_index).line_id '
                        || TO_NUMBER (
                               lt_order_lines_data (xc_order_idx).line_id));
                    --log_records (gc_debug_flag,'@@outside loop for adjustment');

                    fnd_file.put_line (fnd_file.LOG,
                                       '@@before opening adjustement cursor');

                    --Meenakshi 21-may
                    --   l_line_adj_tbl.delete;
                    OPEN cur_order_lines_adj (
                        TO_NUMBER (
                            lt_order_lines_data (xc_order_idx).line_id));

                    LOOP
                        FETCH cur_order_lines_adj
                            BULK COLLECT INTO lt_lines_adj_data
                            LIMIT 50;

                        EXIT WHEN lt_lines_adj_data.COUNT = 0;
                        --log_records (gc_debug_flag,'@@inside loop for adjustment');
                        fnd_file.put_line (fnd_file.LOG,
                                           '@@inside loop for adjustment');
                        log_records (
                            gc_debug_flag,
                               'Assigning values in price adj lines+'
                            || lt_lines_adj_data.COUNT);

                        IF lt_lines_adj_data.COUNT > 0
                        THEN
                            FOR xc_line_adj_idx IN lt_lines_adj_data.FIRST ..
                                                   lt_lines_adj_data.LAST
                            LOOP
                                --log_records (gc_debug_flag,'@@inside for loop for adjustment='||lt_lines_adj_data.COUNT);

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    '@@inside for loop for adjustment=');

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
                                    || lt_lines_adj_data (xc_line_adj_idx).NEW_LIST_line_no);
                                ln_line_adj_index   := ln_line_adj_index + 1;
                                l_line_adj_tbl (ln_line_adj_index)   :=
                                    oe_order_pub.G_MISS_LINE_ADJ_REC;
                                l_line_adj_tbl (ln_line_adj_index).operation   :=
                                    oe_globals.g_opr_create;
                                --l_line_adj_tbl(ln_line_adj_index).price_adjustment_id := oe_price_adjustments_s.NEXTVAL;
                                l_line_adj_tbl (ln_line_adj_index).header_id   :=
                                    FND_API.G_MISS_NUM;
                                ------------------- PASS HEADER ID
                                l_line_adj_tbl (ln_line_adj_index).line_id   :=
                                    FND_API.G_MISS_NUM;
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
                                --l_line_adj_tbl(ln_line_adj_index).update_allowed :='Y';--  lt_lines_adj_data(xc_line_adj_idx).update_allowed;
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
                                --l_line_adj_tbl(ln_line_adj_index).pricing_phase_id :=  lt_lines_adj_data(xc_line_adj_idx).pricing_phase_id;
                                --l_line_adj_tbl(ln_line_adj_index).accrual_flag := 'N'; --lt_lines_adj_data(xc_line_adj_idx).accrual_flag;
                                l_line_adj_tbl (ln_line_adj_index).list_line_no   :=
                                    lt_lines_adj_data (xc_line_adj_idx).NEW_LIST_line_no;
                                --l_line_adj_tbl(ln_line_adj_index).source_system_code := 'QP';
                                --l_line_adj_tbl(ln_line_adj_index).modifier_level_code :=  lt_lines_adj_data(xc_line_adj_idx).MODIFIER_LEVEL_CODE;
                                --l_line_adj_tbl(ln_line_adj_index).proration_type_code :=  lt_lines_adj_data(xc_line_adj_idx).proration_type_code ;
                                l_line_adj_tbl (ln_line_adj_index).operand_per_pqty   :=
                                    lt_lines_adj_data (xc_line_adj_idx).OPERAND_PER_PQTY;
                                l_line_adj_tbl (ln_line_adj_index).adjusted_amount_per_pqty   :=
                                    lt_lines_adj_data (xc_line_adj_idx).ADJUSTED_AMOUNT_PER_PQTY;
                                l_line_adj_tbl (ln_line_adj_index).change_reason_code   :=
                                    lt_lines_adj_data (xc_line_adj_idx).CHANGE_REASON_CODE;
                                l_line_adj_tbl (ln_line_adj_index).change_reason_text   :=
                                    lt_lines_adj_data (xc_line_adj_idx).CHANGE_REASON_text;



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

                                IF     lt_lines_adj_data (xc_line_adj_idx).adjustment_type_code =
                                       'DIS'
                                   AND lt_lines_adj_data (xc_line_adj_idx).modifier_level_code =
                                       'LINE'
                                THEN
                                    l_line_adj_tbl (ln_line_adj_index).attribute3   :=
                                           lt_lines_adj_data (
                                               xc_line_adj_idx).adjustment_description
                                        || '--->'
                                        || lt_lines_adj_data (
                                               xc_line_adj_idx).list_line_no;
                                ELSE
                                    l_line_adj_tbl (ln_line_adj_index).attribute3   :=
                                        lt_lines_adj_data (xc_line_adj_idx).adjustment_description;
                                END IF;

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
                            END LOOP;
                        END IF;
                    END LOOP;

                    CLOSE cur_order_lines_adj;

                    log_records (gc_debug_flag,
                                 '@@order header ID-> ' || p_header_id);
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

    --added closed lines
    -- closed order lines



    PROCEDURE create_order (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_action IN VARCHAR2
                            , p_operating_unit IN VARCHAR2, p_target_org_id IN NUMBER, p_batch_id IN NUMBER)
    AS
        CURSOR cur_order_header IS
            (SELECT *
               FROM XXD_SO_WS_HEADERS_CONV_STG_T cust
              WHERE     record_status = p_action
                    AND batch_number = p_batch_id
                    --AND header_id = 40408042 --35981918
                    AND new_org_id = p_target_org_id);


        CURSOR cur_order_header_adj (p_header_id NUMBER)
        IS
            SELECT *
              FROM xxd_ont_ws_price_adj_l_stg_t cust
             WHERE     header_id = p_header_id
                   AND cust.modifier_level_code = 'ORDER'
                   AND cust.adjustment_type_code <> 'TSN';

        --l_line_tbl                     oe_order_pub.line_tbl_type ;
        ln_line_index           NUMBER := 0;
        --    ln_header_adj_index               NUMBER;
        --l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type ;



        l_header_rec            oe_order_pub.header_rec_type;
        l_line_tbl              oe_order_pub.line_tbl_type;
        l_line_adj_tbl          oe_order_pub.line_adj_tbl_type;
        l_hdr_adj_tbl           oe_order_pub.header_adj_tbl_type;       --amol
        l_action_request_tbl    oe_order_pub.request_tbl_type;
        l_closed_line_adj_tbl   oe_order_pub.line_adj_tbl_type;
        l_request_rec           OE_ORDER_PUB.Request_Rec_Type;
        ln_line_index           NUMBER := 0;
        ln_header_adj_index     NUMBER := 0;
        l_closed_line_flag      VARCHAR2 (1);
        l_open_line_flag        VARCHAR2 (1);

        l_closed_line_tbl       oe_order_pub.line_tbl_type;

        TYPE lt_order_header_typ IS TABLE OF cur_order_header%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_order_header_data    lt_order_header_typ;
        lx_retrun_status        VARCHAR2 (10) := NULL;

        --added by amol

        TYPE lt_headers_adj_typ IS TABLE OF cur_order_header_adj%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_headers_adj_data     lt_headers_adj_typ;
    BEGIN
        --log_records (gc_debug_flag,'Inside create_order +');
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
                    l_header_rec.header_id                      := FND_API.G_MISS_NUM;
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
                        lt_order_header_data (xc_order_idx).ORIGINAL_SYSTEM_REFERENCE;
                    l_header_rec.customer_preference_set_code   :=
                        lt_order_header_data (xc_order_idx).customer_preference_set_code;
                    --            l_header_rec.ship_to_customer_id                                             := FND_API.G_MISS_NUM;
                    --            l_header_rec.invoice_to_customer_id                                          := FND_API.G_MISS_NUM;
                    l_header_rec.sold_to_contact_id             :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.invoice_to_contact_id          :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.ship_to_contact_id             :=
                        FND_API.G_MISS_NUM;

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
                        lt_order_header_data (xc_order_idx).NEW_PRICELIST_ID;
                    l_header_rec.shipping_method_code           :=
                        lt_order_header_data (xc_order_idx).new_ship_method_code;
                    l_header_rec.sales_channel_code             :=
                        lt_order_header_data (xc_order_idx).new_sales_channel_code;
                    l_header_rec.fob_point_code                 :=
                        FND_API.G_MISS_CHAR;


                    l_header_rec.shipping_instructions          :=
                        lt_order_header_data (xc_order_idx).shipping_instructions;
                    l_header_rec.packing_instructions           :=
                        lt_order_header_data (xc_order_idx).packing_instructions;
                    l_action_request_tbl (1)                    :=
                        oe_order_pub.g_miss_request_rec;

                    l_header_rec.cust_po_number                 :=
                        lt_order_header_data (xc_order_idx).cust_po_number;
                    --Meenakshi 13-Aug
                    l_header_rec.salesrep_id                    :=
                        lt_order_header_data (xc_order_idx).NEW_SALESREP_ID;
                    --l_header_rec.salesrep_id                                                     := -3;

                    l_header_rec.payment_term_id                :=
                        lt_order_header_data (xc_order_idx).NEW_PAY_TERM_ID;
                    --Meenakshi 10-sept
                    l_header_rec.shipment_priority_code         :=
                        lt_order_header_data (xc_order_idx).shipment_priority_code; --FND_API.G_MISS_CHAR;

                    l_header_rec.attribute1                     :=
                        TO_CHAR (
                            TO_TIMESTAMP (
                                lt_order_header_data (xc_order_idx).attribute1,
                                'DD-MON-RR'),
                            'YYYY/MM/DD HH24:MI:SS');    --2015/01/15 00:00:00

                    --l_header_rec.attribute1                                                      :=to_char(FND_DATE.DATE_TO_CANONICAL(to_date (lt_order_header_data(xc_order_idx).attribute1,'YYYY/MM/DD')));
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
                    l_header_rec.attribute13                    :=
                        lt_order_header_data (xc_order_idx).attribute13;
                    l_header_rec.attribute14                    :=
                        lt_order_header_data (xc_order_idx).attribute14;


                    --See Conversion Instruction MD50 need to check
                    l_header_rec.attribute15                    := NULL;
                    l_header_rec.attribute16                    := NULL;
                    /*  IF lt_order_header_data(xc_order_idx).flow_status_code = 'BOOKED' THEN
                                  l_header_rec.flow_status_code := 'BOOKED';
                                  l_header_rec.booked_date      := lt_order_header_data(xc_order_idx).ordered_date; --FND_API.G_MISS_DATE;
                                  l_header_rec.booked_flag      := 'Y';
                      --Added by meenakshi 15-may
                      ELSE
                            l_header_rec.booked_flag      := FND_API.G_MISS_CHAR;
                      END IF;*/
                    l_header_rec.booked_flag                    :=
                        FND_API.G_MISS_CHAR;

                    IF lt_order_header_data (xc_order_idx).order_type LIKE
                           '%Return%'
                    THEN
                        l_header_rec.attribute1    :=
                            TO_CHAR (
                                TO_TIMESTAMP (
                                    lt_order_header_data (xc_order_idx).attribute1,
                                    'DD-MON-RR'),
                                'YYYY/MM/DD HH24:MI:SS');
                        l_header_rec.attribute2    := NULL;
                        l_header_rec.attribute3    :=
                            lt_order_header_data (xc_order_idx).attribute3;
                        l_header_rec.attribute4    :=
                            lt_order_header_data (xc_order_idx).attribute4;
                        l_header_rec.attribute5    :=
                            lt_order_header_data (xc_order_idx).attribute5;
                        l_header_rec.attribute6    :=
                            lt_order_header_data (xc_order_idx).attribute6;
                        l_header_rec.attribute7    :=
                            lt_order_header_data (xc_order_idx).attribute7;
                        l_header_rec.attribute8    :=
                            lt_order_header_data (xc_order_idx).attribute8;
                        l_header_rec.attribute9    := NULL;
                        l_header_rec.attribute10   :=
                            lt_order_header_data (xc_order_idx).attribute10;
                        l_header_rec.attribute11   := NULL;
                        l_header_rec.attribute12   := NULL;
                        l_header_rec.attribute13   :=
                            lt_order_header_data (xc_order_idx).attribute13;
                        l_header_rec.attribute14   := NULL;
                        l_header_rec.attribute15   := NULL;
                    END IF;


                    l_header_rec.accounting_rule_id             :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.accounting_rule_duration       :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.agreement_id                   :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.cancelled_flag                 :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.conversion_rate                :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.conversion_rate_date           :=
                        FND_API.G_MISS_DATE;
                    l_header_rec.conversion_type_code           :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.customer_preference_set_code   :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.created_by                     :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.creation_date                  :=
                        FND_API.G_MISS_DATE;
                    l_header_rec.deliver_to_contact_id          :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.deliver_to_org_id              :=
                        FND_API.G_MISS_NUM;

                    l_header_rec.earliest_schedule_limit        :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.expiration_date                :=
                        FND_API.G_MISS_DATE;
                    l_header_rec.freight_carrier_code           :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.freight_terms_code             :=
                        lt_order_header_data (xc_order_idx).freight_terms_code;
                    l_header_rec.global_attribute1              :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute10             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute11             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute12             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute13             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute14             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute15             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute16             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute17             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute18             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute19             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute2              :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute20             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute3              :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute4              :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute5              :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute6              :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute7              :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute8              :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute9              :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.global_attribute_category      :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_CONTEXT                     :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE1                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE2                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE3                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE4                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE5                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE6                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE7                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE8                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE9                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE10                 :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE11                 :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE12                 :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE13                 :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE14                 :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.TP_ATTRIBUTE15                 :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.invoicing_rule_id              :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.last_updated_by                :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.last_update_date               :=
                        FND_API.G_MISS_DATE;
                    l_header_rec.last_update_login              :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.latest_schedule_limit          :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.open_flag                      :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.order_category_code            :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.order_date_type_code           :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.partial_shipments_allowed      :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.pricing_date                   :=
                        FND_API.G_MISS_DATE;
                    l_header_rec.program_application_id         :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.program_id                     :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.program_update_date            :=
                        FND_API.G_MISS_DATE;
                    l_header_rec.request_id                     :=
                        FND_API.G_MISS_NUM;


                    IF lt_order_header_data (xc_order_idx).order_type LIKE
                           '%Return%'
                    THEN
                        l_header_rec.return_reason_code   :=
                            lt_order_header_data (xc_order_idx).return_reason_code;
                    END IF;

                    l_header_rec.ship_tolerance_above           :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.ship_tolerance_below           :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.sold_to_phone_id               :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.source_document_id             :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.source_document_type_id        :=
                        FND_API.G_MISS_NUM;

                    l_header_rec.tax_exempt_flag                :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.tax_exempt_number              :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.tax_exempt_reason_code         :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.tax_point_code                 :=
                        FND_API.G_MISS_CHAR;

                    l_header_rec.transactional_curr_code        :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.version_number                 :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.return_status                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.db_flag                        :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.first_ack_code                 :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.first_ack_date                 :=
                        FND_API.G_MISS_DATE;
                    l_header_rec.last_ack_code                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.last_ack_date                  :=
                        FND_API.G_MISS_DATE;
                    l_header_rec.change_reason                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.change_comments                :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.change_sequence                :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.change_request_code            :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.ready_flag                     :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.status_flag                    :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.force_apply_flag               :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.drop_ship_flag                 :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.customer_payment_term_id       :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.payment_type_code              :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.payment_amount                 :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.check_number                   :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.credit_card_code               :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.credit_card_holder_name        :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.credit_card_number             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.credit_card_expiration_date    :=
                        FND_API.G_MISS_DATE;
                    l_header_rec.credit_card_approval_code      :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.credit_card_approval_date      :=
                        FND_API.G_MISS_DATE;
                    l_header_rec.marketing_source_code_id       :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.upgraded_flag                  :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.deliver_to_customer_id         :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.Blanket_Number                 :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.minisite_Id                    :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.IB_OWNER                       :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.IB_INSTALLED_AT_LOCATION       :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.IB_CURRENT_LOCATION            :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.END_CUSTOMER_ID                :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.END_CUSTOMER_CONTACT_ID        :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.END_CUSTOMER_SITE_USE_ID       :=
                        FND_API.G_MISS_NUM;
                    l_header_rec.SUPPLIER_SIGNATURE             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.SUPPLIER_SIGNATURE_DATE        :=
                        FND_API.G_MISS_DATE;
                    l_header_rec.CUSTOMER_SIGNATURE             :=
                        FND_API.G_MISS_CHAR;
                    l_header_rec.CUSTOMER_SIGNATURE_DATE        :=
                        FND_API.G_MISS_DATE;



                    l_hdr_adj_tbl.delete;                      --added by amol

                    OPEN cur_order_header_adj (
                        TO_NUMBER (
                            lt_order_header_data (xc_order_idx).header_id));

                    LOOP
                        FETCH cur_order_header_adj
                            BULK COLLECT INTO lt_headers_adj_data
                            LIMIT 50;

                        EXIT WHEN lt_headers_adj_data.COUNT = 0;


                        IF lt_headers_adj_data.COUNT > 0
                        THEN
                            FOR xc_header_adj_idx IN lt_headers_adj_data.FIRST ..
                                                     lt_headers_adj_data.LAST
                            LOOP
                                log_records (
                                    gc_debug_flag,
                                    'Assigning values in price adj headers+');
                                log_records (
                                    gc_debug_flag,
                                       'new line id '
                                    || lt_headers_adj_data (
                                           xc_header_adj_idx).new_list_line_id);
                                log_records (
                                    gc_debug_flag,
                                       'new header id '
                                    || lt_headers_adj_data (
                                           xc_header_adj_idx).new_list_header_id);
                                log_records (
                                    gc_debug_flag,
                                       'Operand '
                                    || lt_headers_adj_data (
                                           xc_header_adj_idx).operand);
                                log_records (
                                    gc_debug_flag,
                                       'Arithmetic operator '
                                    || lt_headers_adj_data (
                                           xc_header_adj_idx).arithmetic_operator);
                                log_records (
                                    gc_debug_flag,
                                       'List type code '
                                    || lt_headers_adj_data (
                                           xc_header_adj_idx).list_line_type_code);
                                log_records (
                                    gc_debug_flag,
                                       'List line num '
                                    || lt_headers_adj_data (
                                           xc_header_adj_idx).NEW_LIST_line_no);
                                ln_header_adj_index   :=
                                    ln_header_adj_index + 1;


                                IF lt_headers_adj_data (xc_header_adj_idx).modifier_level_code =
                                   'ORDER'
                                THEN
                                    l_hdr_adj_tbl (ln_header_adj_index)   :=
                                        oe_order_pub.G_MISS_HEADER_ADJ_REC;
                                    l_hdr_adj_tbl (ln_header_adj_index).operation   :=
                                        oe_globals.g_opr_create;

                                    l_hdr_adj_tbl (ln_header_adj_index).header_id   :=
                                        FND_API.G_MISS_NUM;
                                    ------------------- PASS HEADER ID
                                    l_hdr_adj_tbl (ln_header_adj_index).line_id   :=
                                        FND_API.G_MISS_NUM;
                                    ----------------------- PASS LINE ID
                                    --l_hdr_adj_tbl(ln_header_adj_index).index:=ln_header_adj_index;--ln_header_adj_index;--ln_line_index ;
                                    l_hdr_adj_tbl (ln_header_adj_index).automatic_flag   :=
                                        'N';
                                    --  l_line_adj_tbl(ln_line_adj_index).orig_sys_discount_ref :=  lt_lines_adj_data(xc_line_adj_idx).ORIG_SYS_DISCOUNT_REF;
                                    l_hdr_adj_tbl (ln_header_adj_index).list_header_id   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).new_list_header_id; --from validation
                                    l_hdr_adj_tbl (ln_header_adj_index).list_line_id   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).new_list_line_id; -- find out how to get this using list line number
                                    l_hdr_adj_tbl (ln_header_adj_index).list_line_type_code   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).list_line_type_code;
                                    --l_line_adj_tbl(ln_line_adj_index).update_allowed :='Y';--  lt_lines_adj_data(xc_header_adj_idx).update_allowed;
                                    l_hdr_adj_tbl (ln_header_adj_index).updated_flag   :=
                                        'Y'; -- lt_lines_adj_data(xc_header_adj_idx).updated_flag;
                                    l_hdr_adj_tbl (ln_header_adj_index).applied_flag   :=
                                        'Y'; -- lt_lines_adj_data(xc_header_adj_idx).applied_flag;

                                    l_hdr_adj_tbl (ln_header_adj_index).operand   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).operand;
                                    l_hdr_adj_tbl (ln_header_adj_index).arithmetic_operator   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).arithmetic_operator;
                                    l_hdr_adj_tbl (ln_header_adj_index).adjusted_amount   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).adjusted_amount;
                                    --l_line_adj_tbl(ln_line_adj_index).pricing_phase_id :=  lt_lines_adj_data(xc_header_adj_idx).pricing_phase_id;
                                    --l_line_adj_tbl(ln_line_adj_index).accrual_flag := 'N'; --lt_lines_adj_data(xc_header_adj_idx).accrual_flag;
                                    --   l_hdr_adj_tbl(ln_header_adj_index).list_line_no :=  lt_headers_adj_data(xc_header_adj_idx).new_list_line_no;
                                    l_hdr_adj_tbl (ln_header_adj_index).list_line_no   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).new_list_header_no;


                                    l_hdr_adj_tbl (ln_header_adj_index).operand_per_pqty   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).OPERAND_PER_PQTY;
                                    l_hdr_adj_tbl (ln_header_adj_index).adjusted_amount_per_pqty   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).ADJUSTED_AMOUNT_PER_PQTY;
                                    l_hdr_adj_tbl (ln_header_adj_index).change_reason_code   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).CHANGE_REASON_CODE;
                                    l_hdr_adj_tbl (ln_header_adj_index).change_reason_text   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).CHANGE_REASON_text;



                                    --added by me
                                    l_hdr_adj_tbl (ln_header_adj_index).charge_type_code   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).charge_type_code;

                                    l_hdr_adj_tbl (ln_header_adj_index).attribute1   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute1;
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute10   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute10;
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute11   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute11;
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute12   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute12;
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute13   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute13;
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute14   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute14;
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute15   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute15;
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute2   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute2;

                                    -- IF lt_headers_adj_data(xc_header_adj_idx).adjustment_type_code='DIS' AND lt_headers_adj_data(xc_header_adj_idx).modifier_level_code='ORDER' THEN
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute3   :=
                                           lt_headers_adj_data (
                                               xc_header_adj_idx).adjustment_description
                                        || '--->'
                                        || lt_headers_adj_data (
                                               xc_header_adj_idx).list_line_no;
                                    -- ELSE
                                    --l_hdr_adj_tbl(ln_header_adj_index).attribute3                      :=  lt_headers_adj_data(xc_header_adj_idx).adjustment_description;
                                    -- END IF;

                                    l_hdr_adj_tbl (ln_header_adj_index).attribute4   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute4;
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute5   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute5;
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute6   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute6;
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute7   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute7;
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute8   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute8;
                                    l_hdr_adj_tbl (ln_header_adj_index).attribute9   :=
                                        lt_headers_adj_data (
                                            xc_header_adj_idx).attribute9;
                                END IF;
                            END LOOP;
                        END IF;
                    END LOOP;

                    CLOSE cur_order_header_adj;


                    log_records (
                        gc_debug_flag,
                           '@200Create order l_line_tbl before calling create order header cursor '
                        || l_line_tbl.COUNT);

                    log_records (
                        gc_debug_flag,
                           '@300Create order l_line_tbl before calling create order1'
                        || l_line_tbl.COUNT);
                    log_records (
                        gc_debug_flag,
                           '@400Create order l_line_tbl before calling create order1'
                        || l_closed_line_tbl.COUNT);


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
                        --   p_adj_hdr_tbl               =>    NULL, --l_hdr_adj_tbl,  --amol Mismatch parameter
                        x_retrun_status    => lx_retrun_status,
                        x_open_line_flag   => l_open_line_flag);

                    log_records (
                        gc_debug_flag,
                           '@500_line_tbl before calling create order1'
                        || l_line_tbl.COUNT);
                    log_records (
                        gc_debug_flag,
                           '@600Create order l_line_tbl before calling create order1'
                        || l_closed_line_tbl.COUNT);

                    /*create_order_closed_line        (x_errbuf           => x_errbuf,
                                                     x_retcode          => x_retcode,
                                                     p_action           => p_action,
                                                     p_header_id        => lt_order_header_data(xc_order_idx)
                                                                           .header_id,
                                                     p_customer_type    => lt_order_header_data(xc_order_idx).customer_type,
                                                     p_line_tbl         => l_closed_line_tbl,
                                                     p_adj_line_tbl     => l_closed_line_adj_tbl,
                                                     x_retrun_status    => lx_retrun_status,
                                                     x_closed_line_flag => l_closed_line_flag
                                                     );*/


                    log_records (
                        gc_debug_flag,
                           '@700Create order l_line_tbl before calling create order1'
                        || l_line_tbl.COUNT);
                    log_records (
                        gc_debug_flag,
                           '@800Create order l_line_tbl before calling create order1'
                        || l_closed_line_tbl.COUNT);

                    create_order1 (
                        p_header_rec           => l_header_rec,
                        p_line_tbl             => l_line_tbl,
                        p_price_adj_line_tbl   => l_line_adj_tbl,
                        p_price_adj_hdr_tbl    => l_hdr_adj_tbl,        --amol
                        --   p_closed_line_tbl              => l_closed_line_tbl,
                        --  p_price_adj_closed_line_tbl    => l_closed_line_adj_tbl,
                        --    p_closed_line_flag             => l_closed_line_flag,
                        p_open_line_flag       => l_open_line_flag,
                        p_action_request_tbl   => l_action_request_tbl);



                    log_records (
                        gc_debug_flag,
                           '@900Create order l_line_tbl before calling create order1'
                        || l_closed_line_tbl.COUNT);

                    log_records (
                        gc_debug_flag,
                           '@1910 Create order l_line_tbl before calling create order1'
                        || l_line_tbl.COUNT);

                    fnd_file.put_line (
                        fnd_file.LOG,
                           '1 Return Status:After create_order_line '
                        || (lx_retrun_status));                      -- Vaidhy



                    fnd_file.put_line (
                        fnd_file.LOG,
                           '2 Return Status:After create_order_line '
                        || (lx_retrun_status));                      -- Vaidhy
                    fnd_file.put_line (
                        fnd_file.LOG,
                           '2 Closed Flag:After create_order_closed_line '
                        || (l_closed_line_flag));
                --Meenakshi 21-May
                --mo_global.init ('ONT');


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
        lt_oe_header_data              XXD_ONT_ORDER_HEADER_TAB;
        lt_oe_lines_data               XXD_ONT_ORDER_LINES_TAB;
        lt_oe_price_adj_lines_data     XXD_ONT_PRC_ADJ_LINES_TAB;
        lt_oe_price_adj_headers_data   XXD_ONT_PRC_ADJ_LINES_TAB;
        lc_status                      VARCHAR2 (20);
        lh_list_type_code              VARCHAR2 (30);
        l_list_type_code               VARCHAR2 (30);

        CURSOR cur_oe_header (p_batch_number NUMBER)
        IS
            SELECT *
              FROM XXD_SO_WS_HEADERS_CONV_STG_T
             WHERE     record_status IN (gc_new_status, gc_error_status)
                   AND batch_number = p_batch_number;

        --          AND header_id = 40371209;


        CURSOR cur_oe_lines (p_header_id NUMBER)
        IS
            SELECT *
              FROM xxd_so_ws_lines_conv_stg_t
             WHERE header_id = p_header_id;



        lc_oe_header_valid_data        VARCHAR2 (1) := gc_yes_flag;
        lc_oe_line_valid_data          VARCHAR2 (1) := gc_yes_flag;
        ln_count                       NUMBER := 0;
        l_exists                       VARCHAR2 (10) := gc_no_flag;
        lc_error_message               VARCHAR2 (2000);
        lx_return_status               VARCHAR2 (10);

        ln_new_customer_id             NUMBER := NULL;
        ln_new_sold_to_org_id          NUMBER := NULL;
        ln_new_ship_to_site_id         NUMBER := NULL;
        ln_new_bill_to_site_id         NUMBER := NULL;
        ln_ship_from_org_id            NUMBER := NULL;
        ln_new_org_id                  NUMBER := NULL;
        ln_new_pay_term_id             NUMBER := NULL;
        ln_new_salesrep_id             NUMBER := NULL;
        ln_new_salesrep_id_l           NUMBER := NULL;
        ln_new_pricelist_id            NUMBER := NULL;
        ln_new_source_id               NUMBER := NULL;
        ln_new_order_type_id           NUMBER := NULL;
        ln_new_line_type_id            NUMBER := NULL;
        ln_inventory_item_id           NUMBER := NULL;
        ln_line_ship_from_org_id       NUMBER := NULL;
        ln_line_ship_to_site_id        NUMBER := NULL;
        lc_new_sales_channel_code      VARCHAR2 (50) := NULL;
        lc_new_ship_method_code        VARCHAR2 (50) := NULL;
        lc_new_line_ship_method_code   VARCHAR2 (50) := NULL;
        l_new_reason_code              VARCHAR2 (200) := NULL;
        ln_new_list_l_id               NUMBER;
        ln_new_list_h_id               NUMBER;
        ln_list_line_no                VARCHAR2 (240);
        ln_list_header_no              VARCHAR2 (240);
        ln_new_ret_header_id           NUMBER;
        ln_new_ret_line_id             NUMBER;
        ln_new_list_h_hdr_id           NUMBER;
        ln_new_list_l_hdr_id           NUMBER;
        ln_tax_code                    VARCHAR2 (230);
        ln_ship_method_header          NUMBER;
        l_new_line_num                 NUMBER;
        l_duplicate_num                NUMBER;
        lc_cust_country                VARCHAR2 (10);
        l_1206_tax_code                VARCHAR2 (250);
        l_1206_tax_rate                NUMBER;
        l_content_owner_id             NUMBER;
        l_new_rate_code                VARCHAR2 (100);
        l_new_attribute4               NUMBER;
        l_vertex_tax_date              VARCHAR2 (100);
        l_new_tax_date                 DATE;


        CURSOR cur_oe_price_adj_lines (p_header_id NUMBER)
        IS
            SELECT *
              FROM xxd_ont_ws_price_adj_l_stg_t
             WHERE     1 = 1
                   AND header_id = p_header_id
                   AND modifier_level_code = 'LINE';

        CURSOR cur_oe_price_adj_headers (p_header_id NUMBER)
        IS
            SELECT *
              FROM xxd_ont_ws_price_adj_l_stg_t
             WHERE     1 = 1
                   AND header_id = p_header_id
                   AND modifier_level_code = 'ORDER'
                   AND adjustment_type_code <> 'TSN';
    BEGIN
        RETCODE   := NULL;
        ERRBUF    := NULL;

        OPEN cur_oe_header (p_batch_number => p_batch_number);

        LOOP
            FETCH cur_oe_header BULK COLLECT INTO lt_oe_header_data LIMIT 100;

            EXIT WHEN lt_oe_header_data.COUNT = 0;


            log_records (gc_debug_flag,
                         'validate Order header ' || lt_oe_header_data.COUNT);
            log_records (gc_debug_flag,
                         'Working on p_customer_type =>' || p_customer_type);

            IF lt_oe_header_data.COUNT > 0
            THEN
                log_records (
                    gc_debug_flag,
                    'Working on p_customer_type => if ' || lt_oe_header_data.COUNT);

                FOR xc_header_idx IN 1 .. lt_oe_header_data.COUNT
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
                    lc_new_ship_method_code     := NULL;
                    ln_list_line_no             := NULL;
                    ln_list_header_no           := NULL;
                    ln_new_list_l_id            := NULL;
                    ln_new_list_h_id            := NULL;



                    log_records (
                        gc_debug_flag,
                        'Working on p_customer_type =>' || p_customer_type);



                    --            BILL_TO_ORG_ID
                    BEGIN
                        SELECT SITE_USE_ID
                          INTO ln_new_bill_to_site_id
                          FROM HZ_CUST_SITE_USES_ALL
                         WHERE     orig_system_reference =
                                   TO_CHAR (
                                       lt_oe_header_data (xc_header_idx).bill_to_org_id)
                               AND SITE_USE_CODE = 'BILL_TO'
                               AND STATUS = 'A';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_oe_header_valid_data   := gc_no_flag;
                            lc_error_message          :=
                                'Customer Bill to is not available in the System(NO_DATA_FOUND)';
                            xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'BILL_TO_ORG_ID',
                                p_more_info3   =>
                                    lt_oe_header_data (xc_header_idx).BILL_TO_ORG_ID);
                        WHEN OTHERS
                        THEN
                            lc_oe_header_valid_data   := gc_no_flag;
                            lc_error_message          :=
                                'Customer Bill to is not available in the System';
                            xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'BILL_TO_ORG_ID',
                                p_more_info3   =>
                                    lt_oe_header_data (xc_header_idx).BILL_TO_ORG_ID);
                    END;



                    IF UPPER (p_customer_type) = 'WHOLESALE'
                    THEN
                        log_records (
                            gc_debug_flag,
                               'Working on p_customer_type =>'
                            || p_customer_type);

                        BEGIN
                            SELECT hcsu.site_use_id, hca.CUST_ACCOUNT_ID
                              INTO ln_new_bill_to_site_id, ln_new_sold_to_org_id
                              FROM hz_cust_site_uses_all hcsu, HZ_CUST_ACCT_SITES_ALL hcas, --                    HZ_CUST_ACCT_RELATE_ALL hcar,
                                                                                            hz_cust_accounts_all hca
                             WHERE     hcsu.CUST_ACCT_SITE_ID =
                                       hcas.CUST_ACCT_SITE_ID
                                   --            AND        hcas.CUST_ACCOUNT_ID    = hcar.CUST_ACCOUNT_ID
                                   AND hcas.CUST_ACCOUNT_ID =
                                       hca.CUST_ACCOUNT_ID
                                   --AND        RELATED_CUST_ACCOUNT_ID =lt_oe_header_data(xc_header_idx).customer_id--legacy Customer_account
                                   AND SITE_USE_CODE = 'BILL_TO'
                                   --            AND        hcar.status='A'
                                   AND hcsu.orig_system_reference =
                                       TRIM (
                                              TO_CHAR (
                                                  lt_oe_header_data (
                                                      xc_header_idx).bill_to_org_id)
                                           || '-'
                                           || lt_oe_header_data (
                                                  xc_header_idx).attribute5)
                                   --AND hcsu.PRIMARY_FLAG = 'Y'
                                   AND hca.attribute1 =
                                       lt_oe_header_data (xc_header_idx).attribute5;

                            log_records (
                                gc_debug_flag,
                                   'Working on ln_new_bill_to_site_id =>'
                                || ln_new_bill_to_site_id);
                            log_records (
                                gc_debug_flag,
                                   'Working on ln_new_sold_to_org_id =>'
                                || ln_new_sold_to_org_id);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                    'Customer is not available in the System(NO_DATA_FOUND)';
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Open Sales Order Conversion Program',
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
                                log_records (
                                    gc_debug_flag,
                                       'Working on lc_error_message =>'
                                    || lc_error_message
                                    || SQLERRM);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                    'Customer is not available in the System';
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Open Sales Order Conversion Program',
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
                                log_records (
                                    gc_debug_flag,
                                       'Working on lc_error_message =>'
                                    || lc_error_message
                                    || SQLERRM);
                        END;
                    END IF;

                    --            SHIP_TO_ORG_ID

                    BEGIN
                        SELECT site_use_id
                          INTO ln_new_ship_to_site_id
                          FROM hz_cust_site_uses_all
                         WHERE     orig_system_reference =
                                   TO_CHAR (
                                       lt_oe_header_data (xc_header_idx).ship_to_org_id)
                               AND site_use_code = 'SHIP_TO'
                               AND status = 'A';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_oe_header_valid_data   := gc_no_flag;
                            lc_error_message          :=
                                'Customer Ship to is not available in the System(NO_DATA_FOUND)';
                            xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'SHIP_TO_ORG_ID',
                                p_more_info3   =>
                                    lt_oe_header_data (xc_header_idx).SHIP_TO_ORG_ID);
                        WHEN OTHERS
                        THEN
                            lc_oe_header_valid_data   := gc_no_flag;
                            lc_error_message          :=
                                'Customer Ship to is not available in the System';
                            xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'SHIP_TO_ORG_ID',
                                p_more_info3   =>
                                    lt_oe_header_data (xc_header_idx).SHIP_TO_ORG_ID);
                    END;

                    --            SHIP_FROM_ORG_ID
                    IF lt_oe_header_data (xc_header_idx).ship_from_org_id
                           IS NOT NULL
                    THEN
                        ln_ship_from_org_id   :=
                            get_new_inv_org_id (
                                p_old_org_id   =>
                                    lt_oe_header_data (xc_header_idx).ship_from_org_id);

                        IF ln_ship_from_org_id IS NULL
                        THEN
                            lc_oe_header_valid_data   := gc_no_flag;
                            lc_error_message          :=
                                'No Ship From Organization is not available in the System';
                            xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Open Sales Order Conversion Program',
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
                                'No operating Unit is not available in the System';
                            xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Open Sales Order Conversion Program',
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

                    --IF lt_oe_header_data(xc_header_idx).SALES_CHANNEL_CODE IS NOT NULL THEN

                    BEGIN
                        /*    SELECT  hca.sales_channel_code
                            INTO    lc_new_sales_channel_code
                            FROM    hz_cust_accounts_all hca,
                                    hz_cust_site_uses_all hcsu,
                                    hz_cust_acct_sites_all hcas,
                                    hz_cust_acct_relate_all hcar
                            WHERE   1=1
                            AND     hcar.related_cust_account_id=lt_oe_header_data(xc_header_idx).customer_id
                            AND     hca.cust_account_id=hcas.cust_account_id
                            AND     hcsu.site_use_code='BILL_TO'
                            AND     hcsu.CUST_ACCT_SITE_ID  = hcas.CUST_ACCT_SITE_ID
                            AND     hcas.CUST_ACCOUNT_ID    = hcar.CUST_ACCOUNT_ID
                            AND     hcar.status='A'; */

                        SELECT hca.sales_channel_code
                          INTO lc_new_sales_channel_code
                          FROM hz_cust_accounts_all hca
                         WHERE     1 = 1
                               AND hca.cust_account_id =
                                   lt_oe_header_data (xc_header_idx).customer_id
                               AND hca.status = 'A';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_oe_header_valid_data   := gc_no_flag;
                            lc_error_message          :=
                                'SALES_CHANNEL is not available in the System';
                            xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'SALES_CHANNEL_CODE',
                                p_more_info3   =>
                                    lt_oe_header_data (xc_header_idx).SALES_CHANNEL_CODE);
                        WHEN OTHERS
                        THEN
                            lc_oe_header_valid_data   := gc_no_flag;
                            lc_error_message          :=
                                'SALES_CHANNEL is not available in the System';
                            xxd_common_utils.record_error (
                                p_module       => 'ONT',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers Open Sales Order Conversion Program',
                                p_error_line   => SQLCODE,
                                p_error_msg    => lc_error_message,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    lt_oe_header_data (xc_header_idx).order_number,
                                p_more_info2   => 'SALES_CHANNEL_CODE',
                                p_more_info3   =>
                                    lt_oe_header_data (xc_header_idx).SALES_CHANNEL_CODE);
                    END;

                    --END IF;


                    --            PAYMENT_TERM_NAME
                    IF lt_oe_header_data (xc_header_idx).payment_term_name
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT rt.term_id
                              INTO ln_new_pay_term_id
                              FROM ra_terms rt, xxd_1206_payment_term_map_t xrt
                             WHERE     rt.NAME = xrt.NEW_TERM_NAME
                                   AND old_term_name =
                                       lt_oe_header_data (xc_header_idx).payment_term_name
                                   AND ROWNUM < 2;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                    'PAYMENT_TERM_NAME is not available in the System';
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'PAYMENT_TERM_NAME',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).PAYMENT_TERM_NAME);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                    'PAYMENT_TERM_NAME is not available in the System';
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'PAYMENT_TERM_NAME',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).PAYMENT_TERM_NAME);
                        END;
                    END IF;

                    --            salesrep_number
                    IF lt_oe_header_data (xc_header_idx).salesrep_number
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT rs.salesrep_id
                              INTO ln_new_salesrep_id
                              FROM apps.jtf_rs_salesreps rs, apps.JTF_RS_RESOURCE_EXTNS_VL RES, hr_organization_units hou
                             WHERE     hou.organization_id = rs.org_id
                                   AND rs.resource_id = res.resource_id
                                   AND rs.salesrep_number =
                                       TO_CHAR (
                                           lt_oe_header_data (xc_header_idx).salesrep_number)
                                   AND org_id = ln_new_org_id;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                BEGIN
                                    SELECT rs.salesrep_id
                                      INTO ln_new_salesrep_id
                                      FROM apps.jtf_rs_salesreps rs, apps.JTF_RS_RESOURCE_EXTNS_VL RES, hr_organization_units hou
                                     WHERE     hou.organization_id =
                                               rs.org_id
                                           AND rs.resource_id =
                                               res.resource_id
                                           AND rs.salesrep_number =
                                               TO_CHAR ('10648')
                                           AND org_id = ln_new_org_id;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                        lc_error_message   :=
                                               'salesrep_number CONV_REP for org id '
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
                                            p_more_info2   =>
                                                'salesrep_number',
                                            p_more_info3   =>
                                                lt_oe_header_data (
                                                    xc_header_idx).salesrep_number);
                                END;
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'salesrep_number CONV_REP for org id '
                                    || ln_new_org_id
                                    || ' is not available in the System '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);
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
                                    p_more_info2   => 'salesrep_number',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).salesrep_number);
                        END;
                    ELSE
                        BEGIN
                            SELECT rs.salesrep_id
                              INTO ln_new_salesrep_id
                              FROM apps.jtf_rs_salesreps rs, apps.JTF_RS_RESOURCE_EXTNS_VL RES, hr_organization_units hou
                             WHERE     hou.organization_id = rs.org_id
                                   AND rs.resource_id = res.resource_id
                                   AND rs.salesrep_number = TO_CHAR ('10648')
                                   AND org_id = ln_new_org_id;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'salesrep_number CONV_REP for org id '
                                    || ln_new_org_id
                                    || ' is not available in the System';
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);
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
                                    p_more_info2   => 'salesrep_number',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).salesrep_number);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                       'salesrep_number CONV_REP for org id '
                                    || ln_new_org_id
                                    || ' is not available in the System '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG,
                                                   lc_error_message);
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
                                    p_more_info2   => 'salesrep_number',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).salesrep_number);
                        END;
                    END IF;

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
                                       lt_oe_header_data (xc_header_idx).price_list
                                   AND ROWNUM < 2;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                    'PRICE_LIST is not available in the System';
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'price_list',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).price_list);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                    'price_list is not available in the System';
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'price_list',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).price_list);
                        END;
                    END IF;

                    --            ORDER_SOURCE
                    IF lt_oe_header_data (xc_header_idx).ORDER_SOURCE
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
                                        'Deckers Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'ORDER_SOURCE',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).ORDER_SOURCE);
                            WHEN OTHERS
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                    'ORDER_SOURCE is not available in the System';
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'ORDER_SOURCE',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).ORDER_SOURCE);
                        END;
                    END IF;

                    --SHIP_METHOD_CODE at header
                    IF lt_oe_header_data (xc_header_idx).shipping_method_code
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT new_ship_method_code
                              INTO lc_new_ship_method_code
                              FROM xxd_1206_ship_methods_map_t
                             WHERE old_ship_method_code =
                                   lt_oe_header_data (xc_header_idx).shipping_method_code;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                SELECT ship_method_code
                                  INTO lc_new_ship_method_code
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
                                lc_new_ship_method_code   := NULL;
                        END;

                        IF     lc_new_ship_method_code IS NOT NULL
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
                                   AND b.ship_method_code =
                                       lc_new_ship_method_code
                                   AND a.enabled_flag = 'Y'
                                   AND a.organization_id =
                                       ln_ship_from_org_id;



                            IF ln_ship_method_header = 0
                            THEN
                                --no data found then default shipmethod
                                SELECT ship_method_code
                                  INTO lc_new_ship_method_code
                                  FROM wsh_carriers_v a, wsh_carrier_services_v b
                                 WHERE     a.carrier_id = b.carrier_id
                                       AND a.carrier_name = 'CONVERSION'
                                       AND a.active = 'A'
                                       AND b.enabled_flag = 'Y'
                                       AND b.ship_method_meaning = 'CONV-ORG';
                            END IF;
                        END IF;
                    ELSE
                        lc_new_ship_method_code   := NULL;
                    END IF;

                    lc_cust_country             := NULL;

                    --            ORDER_TYPE
                    IF lt_oe_header_data (xc_header_idx).order_type
                           IS NOT NULL
                    THEN
                        BEGIN
                            IF     lt_oe_header_data (xc_header_idx).attribute2 IN
                                       ('PRE-SEASON FALL', 'PRE-SEASON SPRING')
                               AND -- AND lt_oe_header_data(xc_header_idx).new_org_id IN (94,86,88)
                                   lt_oe_header_data (xc_header_idx).order_type LIKE
                                       '%Whole%'
                               AND ln_new_org_id IN (94, 86, 88)
                            THEN
                                IF ln_new_org_id = 94
                                THEN
                                    BEGIN
                                        log_records (gc_debug_flag,
                                                     'Inside Pre season UK');

                                        log_records (
                                            gc_debug_flag,
                                               'upper (lt_oe_header_data(xc_header_idx).PRICE_LIST)'
                                            || UPPER (
                                                   lt_oe_header_data (
                                                       xc_header_idx).PRICE_LIST));

                                        SELECT 'IRL'
                                          INTO lc_cust_country
                                          FROM xxd_so_ws_headers_conv_stg_t
                                         WHERE     UPPER (
                                                       lt_oe_header_data (
                                                           xc_header_idx).PRICE_LIST) LIKE
                                                       '%IRE%'
                                               AND header_id =
                                                   lt_oe_header_data (
                                                       xc_header_idx).header_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            log_records (gc_debug_flag,
                                                         SQLERRM);
                                            lc_cust_country   := 'UK';
                                    END;

                                    log_records (
                                        gc_debug_flag,
                                           ' lc_cust_country '
                                        || lc_cust_country);

                                    SELECT transaction_type_id
                                      INTO ln_new_order_type_id
                                      FROM oe_transaction_types_tl ott, xxd_1206_order_type_map_t xtt
                                     WHERE   -- ott.name = xtt.new_12_2_3_name
                                               -- AND
                                               legacy_12_0_6_name =
                                               lt_oe_header_data (
                                                   xc_header_idx).order_type
                                           AND UPPER (ott.name) LIKE
                                                   '%PRE-SEASON%'
                                           AND UPPER (ott.name) LIKE
                                                      '%'
                                                   || lc_cust_country
                                                   || '%'
                                           AND LANGUAGE = 'US'
                                           AND ROWNUM < 2;

                                    log_records (
                                        gc_debug_flag,
                                           '  ln_new_order_type_id '
                                        || ln_new_order_type_id);
                                ELSE
                                    log_records (gc_debug_flag,
                                                 'Inside Pre season Benelux');

                                    SELECT transaction_type_id
                                      INTO ln_new_order_type_id
                                      FROM oe_transaction_types_tl ott, xxd_1206_order_type_map_t xtt
                                     WHERE     ott.name = xtt.new_12_2_3_name
                                           AND legacy_12_0_6_name =
                                               lt_oe_header_data (
                                                   xc_header_idx).order_type
                                           AND UPPER (ott.name) LIKE
                                                   '%PRE-SEASON%'
                                           AND LANGUAGE = 'US'
                                           AND ROWNUM < 2;
                                END IF;
                            ELSIF     lt_oe_header_data (xc_header_idx).attribute2 IN
                                          ('RE-ORDER FALL', 'RE-ORDER SPRING', 'STOCK SWAP RE-ORDER')
                                  --      AND lt_oe_header_data(xc_header_idx).new_org_id IN (94,86,88)
                                  AND lt_oe_header_data (xc_header_idx).order_type LIKE
                                          '%Whole%'
                                  AND ln_new_org_id IN (94, 86, 88)
                            THEN
                                /*SELECT    transaction_type_id
                                INTO    ln_new_order_type_id
                                FROM    oe_transaction_types_tl ott,
                                        xxd_1206_order_type_map_t xtt
                                WHERE    ott.name = xtt.new_12_2_3_name
                                AND        legacy_12_0_6_name = lt_oe_header_data(xc_header_idx).order_type
                                --AND        upper(ott.name) like '%RE-ORDER%'
                                AND        language = 'US'
                                AND       rownum<2;*/
                                IF ln_new_org_id = 94
                                THEN
                                    /*  SELECT decode (hl.country,'GB','UK','IE','IRL')
                                      into lc_cust_country
                                      FROM hz_cust_site_uses_all hcsua,
                                      HZ_CUST_ACCT_SITES_ALL hcasa,
                                      hz_party_sites  hps,
                                      hz_locations hl
                                      where  hcsua.CUST_ACCT_SITE_ID  = hcasa.CUST_ACCT_SITE_ID
                                      and hcasa.party_site_id = hps.party_site_id
                                      and hps.location_id = hl.location_id
                                      and site_use_id = ln_new_ship_to_site_id;*/
                                    BEGIN
                                        SELECT 'IRL'
                                          INTO lc_cust_country
                                          FROM xxd_so_ws_headers_conv_stg_t
                                         WHERE     UPPER (
                                                       lt_oe_header_data (
                                                           xc_header_idx).PRICE_LIST) LIKE
                                                       '%IRE%'
                                               AND header_id =
                                                   lt_oe_header_data (
                                                       xc_header_idx).header_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            lc_cust_country   := 'UK';
                                    END;


                                    SELECT ott.transaction_type_id
                                      INTO ln_new_order_type_id
                                      FROM oe_transaction_types_tl ott, oe_transaction_types_all otta
                                     WHERE     ott.transaction_type_id =
                                               otta.transaction_type_id
                                           AND otta.org_id = ln_new_org_id
                                           AND UPPER (ott.name) LIKE
                                                   '%RE-ORDER%'
                                           AND UPPER (ott.name) LIKE
                                                      '%'
                                                   || lc_cust_country
                                                   || '%'
                                           AND language = 'US'
                                           AND ROWNUM < 2;
                                ELSE
                                    SELECT ott.transaction_type_id
                                      INTO ln_new_order_type_id
                                      FROM oe_transaction_types_tl ott, oe_transaction_types_all otta
                                     WHERE     ott.transaction_type_id =
                                               otta.transaction_type_id
                                           AND otta.org_id = ln_new_org_id
                                           AND UPPER (ott.name) LIKE
                                                   '%RE-ORDER%'
                                           --  AND        upper(ott.name) like '%'||lc_cust_country  ||'%'
                                           AND language = 'US'
                                           AND ROWNUM < 2;
                                END IF;
                            ELSIF     lt_oe_header_data (xc_header_idx).attribute2 IN
                                          ('SALE BUY', 'CLOSE-OUT')
                                  --      AND lt_oe_header_data(xc_header_idx).new_org_id IN (94,86,88)
                                  AND lt_oe_header_data (xc_header_idx).order_type LIKE
                                          '%Whole%'
                                  AND ln_new_org_id IN (94, 86, 88)
                            THEN
                                SELECT ott.transaction_type_id
                                  INTO ln_new_order_type_id
                                  FROM oe_transaction_types_tl ott, oe_transaction_types_all otta
                                 WHERE     ott.transaction_type_id =
                                           otta.transaction_type_id
                                       AND otta.org_id = ln_new_org_id
                                       AND UPPER (ott.name) LIKE
                                               '%CLOSE OUT%'
                                       --  AND        upper(ott.name) like '%'||lc_cust_country  ||'%'
                                       AND language = 'US';
                            ELSE
                                SELECT transaction_type_id
                                  INTO ln_new_order_type_id
                                  FROM oe_transaction_types_tl ott, XXD_1206_ORDER_TYPE_MAP_T xtt
                                 WHERE     ott.name = xtt.NEW_12_2_3_NAME
                                       AND legacy_12_0_6_name =
                                           lt_oe_header_data (xc_header_idx).order_type
                                       AND LANGUAGE = 'US'
                                       AND ROWNUM < 2;
                            END IF;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_oe_header_valid_data   := gc_no_flag;
                                lc_error_message          :=
                                    'ORDER_TYPE is not available in the System';
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Open Sales Order Conversion Program',
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
                                    'ORDER_TYPE is not available in the System';
                                xxd_common_utils.record_error (
                                    p_module       => 'ONT',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers Open Sales Order Conversion Program',
                                    p_error_line   => SQLCODE,
                                    p_error_msg    => lc_error_message,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        lt_oe_header_data (xc_header_idx).order_number,
                                    p_more_info2   => 'ORDER_TYPE',
                                    p_more_info3   =>
                                        lt_oe_header_data (xc_header_idx).ORDER_TYPE);
                        END;
                    END IF;

                    --price adjustment headers
                    OPEN cur_oe_price_adj_headers (
                        p_header_id   =>
                            lt_oe_header_data (xc_header_idx).header_id);

                    FETCH cur_oe_price_adj_headers
                        BULK COLLECT INTO lt_oe_price_adj_headers_data;

                    CLOSE cur_oe_price_adj_headers;

                    BEGIN
                        log_records (
                            gc_debug_flag,
                               'Header ID Before Price Adjustment Headers => '
                            || lt_oe_header_data (xc_header_idx).header_id);
                        log_records (
                            gc_debug_flag,
                               'Count Of Price Adjustment Headers => '
                            || lt_oe_price_adj_headers_data.COUNT);

                        IF lt_oe_price_adj_headers_data.COUNT > 0
                        THEN
                            FOR xc_headers_idx IN lt_oe_price_adj_headers_data.FIRST ..
                                                  lt_oe_price_adj_headers_data.LAST
                            LOOP
                                ln_new_list_l_hdr_id   := NULL;
                                ln_new_list_h_hdr_id   := NULL;
                                -- ln_list_line_no            := null;
                                ln_list_header_no      := NULL;
                                --lc_oe_header_valid_data := gc_yes_flag;
                                lh_list_type_code      := NULL;


                                BEGIN
                                    SELECT list_type_code
                                      INTO lh_list_type_code
                                      FROM apps.xxd_qp_list_headers_stg_t a, xxd_conv.xxd_ont_ws_price_adj_l_stg_t b
                                     WHERE     a.list_header_id =
                                               lt_oe_price_adj_headers_data (
                                                   xc_headers_idx).list_header_id
                                           AND a.list_header_id =
                                               b.list_header_id
                                           AND b.modifier_level_code =
                                               'ORDER'
                                           AND b.header_id =
                                               lt_oe_price_adj_headers_data (
                                                   xc_headers_idx).header_id
                                           AND b.price_adjustment_id =
                                               lt_oe_price_adj_headers_data (
                                                   xc_headers_idx).price_adjustment_id
                                           AND b.list_line_type_code <> 'TSN';


                                    log_records (
                                        gc_debug_flag,
                                           'Modifier Level Code  => '
                                        || lt_oe_price_adj_headers_data (
                                               xc_headers_idx).modifier_level_code);
                                    log_records (
                                        gc_debug_flag,
                                           'List Line Type Code=> '
                                        || lt_oe_price_adj_headers_data (
                                               xc_headers_idx).list_line_type_code);
                                    log_records (
                                        gc_debug_flag,
                                           'Pricing Phase ID => '
                                        || lt_oe_price_adj_headers_data (
                                               xc_headers_idx).pricing_phase_id);
                                    log_records (
                                        gc_debug_flag,
                                           'Transactional Currency => '
                                        || lt_oe_header_data (xc_header_idx).transactional_curr_code);

                                    IF lh_list_type_code = 'CHARGES'
                                    THEN
                                        SELECT qph.list_header_id, qpl.list_line_id, qpl.list_line_no
                                          INTO ln_new_list_h_hdr_id, ln_new_list_l_hdr_id, ln_list_header_no
                                          FROM apps.qp_list_headers qph, apps.qp_list_lines qpl
                                         WHERE     qph.list_header_id =
                                                   qpl.list_header_id
                                               --AND        qph.name =lt_oe_price_adj_lines_data(xc_line_idx).ADJUSTMENT_NAME
                                               -- AND        qpl.charge_type_code='CONVERSION'
                                               AND qpl.modifier_level_code =
                                                   lt_oe_price_adj_headers_data (
                                                       xc_headers_idx).modifier_level_code
                                               AND qpl.list_line_type_code =
                                                   lt_oe_price_adj_headers_data (
                                                       xc_headers_idx).list_line_type_code
                                               AND NVL (qpl.end_date_active,
                                                        TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND qpl.pricing_phase_id =
                                                   lt_oe_price_adj_headers_data (
                                                       xc_headers_idx).pricing_phase_id
                                               AND qph.currency_code =
                                                   lt_oe_header_data (
                                                       xc_header_idx).transactional_curr_code
                                               AND list_line_no LIKE 'BT%';

                                        --log_records (gc_debug_flag,'@200');
                                        log_records (
                                            gc_debug_flag,
                                               '@list line type code in charges IF  => '
                                            || lh_list_type_code);
                                    END IF;



                                    IF lh_list_type_code = 'DLT'
                                    THEN
                                        --lt_oe_price_adj_headers_data(xc_headers_idx).adjustment_type_code='FREIGHT_CHARGE' THEN
                                        --log_records (gc_debug_flag,'@350');
                                        --  log_records (gc_debug_flag,'mc'||lt_oe_price_adj_headers_data(xc_headers_idx).modifier_level_code);
                                        --   log_records (gc_debug_flag,'PP'||lt_oe_price_adj_headers_data(xc_headers_idx).pricing_phase_id);
                                        --     log_records (gc_debug_flag,'currency'||lt_oe_header_data(xc_headers_idx).transactional_curr_code);
                                        --    log_records (gc_debug_flag,'LLC'||lt_oe_price_adj_headers_data(xc_headers_idx).list_line_type_code);
                                        SELECT qph.list_header_id, qpl.list_line_id, qpl.list_line_no
                                          INTO ln_new_list_h_hdr_id, ln_new_list_l_hdr_id, ln_list_header_no
                                          FROM apps.qp_list_headers qph, apps.qp_list_lines qpl
                                         WHERE     qph.list_header_id =
                                                   qpl.list_header_id
                                               --AND        qph.name =lt_oe_price_adj_headers_data(xc_line_idx).ADJUSTMENT_NAME
                                               --AND        qpl.charge_type_code='CONVERSION'
                                               AND qpl.modifier_level_code =
                                                   lt_oe_price_adj_headers_data (
                                                       xc_headers_idx).modifier_level_code
                                               --AND        qpl.list_line_type_code = lt_oe_price_adj_headers_data(xc_headers_idx).list_line_type_code
                                               AND NVL (qpl.end_date_active,
                                                        TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND qpl.pricing_phase_id =
                                                   lt_oe_price_adj_headers_data (
                                                       xc_headers_idx).pricing_phase_id
                                               AND qph.currency_code =
                                                   lt_oe_header_data (
                                                       xc_header_idx).transactional_curr_code
                                               AND list_type_code = 'DLT'
                                               AND list_line_type_code =
                                                   'DIS'
                                               AND list_line_no LIKE 'BT%';

                                        --log_records (gc_debug_flag,'@400');
                                        log_records (
                                            gc_debug_flag,
                                               '@list line type code in DLT  => '
                                            || lh_list_type_code);
                                    END IF;

                                    IF lh_list_type_code = 'PRO'
                                    THEN
                                        SELECT qph.list_header_id, qpl.list_line_id, qpl.list_line_no
                                          INTO ln_new_list_h_hdr_id, ln_new_list_l_hdr_id, ln_list_header_no
                                          FROM apps.qp_list_headers qph, apps.qp_list_lines qpl
                                         WHERE     qph.list_header_id =
                                                   qpl.list_header_id
                                               --AND        qph.name =lt_oe_price_adj_headers_data(xc_line_idx).ADJUSTMENT_NAME
                                               --AND        qpl.charge_type_code='CONVERSION'
                                               --AND        qpl.modifier_level_code =lt_oe_price_adj_headers_data(xc_headers_idx).modifier_level_code
                                               --AND        qpl.list_line_type_code = lt_oe_price_adj_headers_data(xc_headers_idx).list_line_type_code
                                               AND NVL (qpl.end_date_active,
                                                        TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND qpl.pricing_phase_id =
                                                   lt_oe_price_adj_headers_data (
                                                       xc_headers_idx).pricing_phase_id
                                               AND qph.currency_code =
                                                   lt_oe_header_data (
                                                       xc_header_idx).transactional_curr_code
                                               AND list_type_code = 'PRO'
                                               AND list_line_no LIKE 'BT%';

                                        log_records (
                                            gc_debug_flag,
                                               '@list line type code in PRO  => '
                                            || lh_list_type_code);
                                    END IF;

                                    IF lh_list_type_code = 'SLT'
                                    THEN
                                        SELECT qph.list_header_id, qpl.list_line_id, qpl.list_line_no
                                          INTO ln_new_list_h_hdr_id, ln_new_list_l_hdr_id, ln_list_header_no
                                          FROM apps.qp_list_headers qph, apps.qp_list_lines qpl
                                         WHERE     qph.list_header_id =
                                                   qpl.list_header_id
                                               --AND        qph.name =lt_oe_price_adj_headers_data(xc_line_idx).ADJUSTMENT_NAME
                                               --AND        qpl.charge_type_code='CONVERSION'
                                               AND qpl.modifier_level_code =
                                                   lt_oe_price_adj_headers_data (
                                                       xc_headers_idx).modifier_level_code
                                               --AND        qpl.list_line_type_code = lt_oe_price_adj_headers_data(xc_headers_idx).list_line_type_code
                                               AND NVL (qpl.end_date_active,
                                                        TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND qpl.pricing_phase_id =
                                                   lt_oe_price_adj_headers_data (
                                                       xc_headers_idx).pricing_phase_id
                                               AND qph.currency_code =
                                                   lt_oe_header_data (
                                                       xc_header_idx).transactional_curr_code
                                               AND list_type_code = 'SLT'
                                               AND list_line_no LIKE 'BT%';

                                        log_records (
                                            gc_debug_flag,
                                               '@list line type code in SLT  => '
                                            || lh_list_type_code);
                                    END IF;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                        lc_oe_line_valid_data   := gc_no_flag;
                                        lc_error_message        :=
                                            'List header id or line id not found is not available in the System(NO_DATA_FOUND)';
                                        xxd_common_utils.record_error (
                                            p_module       => 'ONT',
                                            p_org_id       => gn_org_id,
                                            p_program      =>
                                                'Deckers Open Sales Order Wholesale Conversion Program',
                                            p_error_line   => SQLCODE,
                                            p_error_msg    =>
                                                   lc_error_message
                                                || '-'
                                                || SQLERRM,
                                            p_created_by   => gn_user_id,
                                            p_request_id   =>
                                                gn_conc_request_id,
                                            p_more_info1   =>
                                                lt_oe_header_data (
                                                    xc_headers_idx).order_number,
                                            p_more_info2   =>
                                                lt_oe_lines_data (
                                                    xc_headers_idx).line_number,
                                            p_more_info3   =>
                                                'ADJUSTMENT NAME',
                                            p_more_info4   =>
                                                lt_oe_price_adj_headers_data (
                                                    xc_headers_idx).record_id);
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
                                                    xc_headers_idx).line_number,
                                            p_more_info3   =>
                                                'ADJUSTMENT NAME',
                                            p_more_info4   =>
                                                lt_oe_price_adj_headers_data (
                                                    xc_headers_idx).record_id);
                                        ln_new_list_h_hdr_id    := -1;
                                        ln_new_list_l_hdr_id    := -1;
                                END;

                                log_records (
                                    gc_debug_flag,
                                    '@@@@@@@6=> ' || lc_oe_header_valid_data);

                                BEGIN
                                    IF    lc_oe_line_valid_data = gc_no_flag
                                       OR lc_oe_header_valid_data =
                                          gc_no_flag
                                    THEN
                                        UPDATE xxd_ont_ws_price_adj_l_stg_t
                                           SET record_status = gc_error_status, new_list_header_id = ln_new_list_h_hdr_id, new_list_line_id = ln_new_list_l_hdr_id,
                                               -- new_list_line_no        =        ln_list_line_no
                                               new_list_header_no = ln_list_header_no
                                         WHERE record_id =
                                               lt_oe_price_adj_headers_data (
                                                   xc_headers_idx).record_id;

                                        log_records (
                                            gc_debug_flag,
                                               '@@7=> '
                                            || lc_oe_header_valid_data);
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                    ELSE
                                        UPDATE xxd_ont_ws_price_adj_l_stg_t
                                           SET record_status = gc_validate_status, new_list_header_id = ln_new_list_h_hdr_id, new_list_line_id = ln_new_list_l_hdr_id,
                                               --new_list_line_no=ln_list_line_no
                                               new_list_header_no = ln_list_header_no
                                         WHERE record_id =
                                               lt_oe_price_adj_headers_data (
                                                   xc_headers_idx).record_id;

                                        log_records (
                                            gc_debug_flag,
                                               '@@8=> '
                                            || lc_oe_header_valid_data);
                                    END IF;
                                --commit;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.OUTPUT,
                                               'Error during price adj header stage table update'
                                            || SQLERRM);
                                        log_records (
                                            gc_debug_flag,
                                               'xx100=> '
                                            || lc_oe_header_valid_data);
                                END;
                            END LOOP;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.OUTPUT,
                                   'Error during price adj header stage table update'
                                || SQLERRM);
                    END;



                    OPEN cur_oe_lines (
                        p_header_id   =>
                            lt_oe_header_data (xc_header_idx).header_id);

                    FETCH cur_oe_lines BULK COLLECT INTO lt_oe_lines_data;

                    CLOSE cur_oe_lines;

                    log_records (
                        gc_debug_flag,
                        'validate Order Lines ' || lt_oe_lines_data.COUNT);

                    log_records (gc_debug_flag,
                                 '@@@@@@@1=> ' || lc_oe_header_valid_data);

                    IF lt_oe_lines_data.COUNT > 0
                    THEN
                        FOR xc_line_idx IN lt_oe_lines_data.FIRST ..
                                           lt_oe_lines_data.LAST
                        LOOP
                            ln_new_line_type_id            := NULL;
                            ln_inventory_item_id           := NULL;
                            ln_line_ship_from_org_id       := NULL;
                            ln_line_ship_to_site_id        := NULL;
                            lc_new_line_ship_method_code   := NULL;
                            l_new_reason_code              := NULL;
                            ln_tax_code                    := NULL;
                            lc_oe_line_valid_data          := gc_yes_flag;
                            ln_new_salesrep_id_l           := NULL;
                            l_1206_tax_code                := NULL;
                            l_1206_tax_rate                := NULL;
                            l_content_owner_id             := NULL;
                            l_new_rate_code                := NULL;
                            l_new_attribute4               := NULL;
                            l_vertex_tax_date              := NULL;
                            l_new_tax_date                 := NULL;

                            -- IF lt_oe_lines_data(xc_line_idx).SOURCE_TYPE_CODE   = 'EXTERNAL' THEN
                            BEGIN
                                SELECT ott.transaction_type_id
                                  INTO ln_new_line_type_id
                                  FROM oe_workflow_assignments OWA, oe_transaction_types_tl ott, xxd_1206_order_type_map_t xott
                                 WHERE     OWA.line_type_id =
                                           ott.transaction_type_id
                                       AND line_type_for_conversion =
                                           ott.name
                                       AND legacy_12_0_6_name =
                                           lt_oe_header_data (xc_header_idx).order_type
                                       AND LANGUAGE = 'US'
                                       --AND rownum<2;
                                       AND SYSDATE BETWEEN start_date_active
                                                       AND NVL (
                                                               end_date_active,
                                                               SYSDATE);
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
                            -- Tax code
                            IF lt_oe_header_data (xc_header_idx).org_id = 2
                            THEN
                                IF lt_oe_lines_data (xc_line_idx).tax_code =
                                   'Exempt'
                                THEN
                                    ln_tax_code   := 'EXEMPT';
                                ELSE
                                    ln_tax_code   := NULL;
                                END IF;
                            ELSE
                                ln_tax_code   :=
                                    UPPER (
                                        lt_oe_lines_data (xc_line_idx).tax_code);
                            END IF;



                            --            SHIP_TO_ORG_ID

                            IF lt_oe_lines_data (xc_line_idx).SHIP_TO_ORG_ID
                                   IS NOT NULL
                            THEN
                                BEGIN
                                    SELECT site_use_id
                                      INTO ln_line_ship_to_site_id
                                      FROM hz_cust_site_uses_all
                                     WHERE     orig_system_reference =
                                               TO_CHAR (
                                                   lt_oe_lines_data (
                                                       xc_line_idx).ship_to_org_id)
                                           AND site_use_code = 'SHIP_TO'
                                           AND status = 'A';
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                        lc_error_message   :=
                                            'Customer Ship to is not available in the System NO_DATA_FOUND';
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
                                            p_more_info2   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).line_number,
                                            p_more_info3   =>
                                                'LINE_SHIP_TO_ORG_ID',
                                            p_more_info4   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).SHIP_TO_ORG_ID);
                                    WHEN OTHERS
                                    THEN
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                        lc_error_message   :=
                                            'Customer Ship to is not available in the System';
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
                                            p_more_info2   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).line_number,
                                            p_more_info3   =>
                                                'LINE_SHIP_TO_ORG_ID',
                                            p_more_info4   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).SHIP_TO_ORG_ID);
                                END;
                            END IF;

                            --RETURN REASON CODE
                            IF lt_oe_lines_data (xc_line_idx).return_reason_code
                                   IS NOT NULL
                            THEN
                                BEGIN
                                    SELECT lookup_code
                                      INTO l_new_reason_code
                                      FROM ar_lookups
                                     WHERE     1 = 1
                                           AND lookup_type =
                                               'CREDIT_MEMO_REASON'
                                           AND lookup_code =
                                               lt_oe_lines_data (xc_line_idx).return_reason_code;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        lc_error_message        :=
                                            'Return Reason code is not available in the System';
                                        lc_oe_line_valid_data   := gc_no_flag;
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
                                            p_more_info2   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).line_number,
                                            p_more_info3   =>
                                                'LINE_RETURN_REASON_CODE',
                                            p_more_info4   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).return_reason_code);
                                    WHEN OTHERS
                                    THEN
                                        lc_error_message        :=
                                            'Return Reason Code is not available in the System';
                                        lc_oe_line_valid_data   := gc_no_flag;
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
                                            p_more_info2   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).line_number,
                                            p_more_info3   =>
                                                'LINE_RETURN_REASON_CODE',
                                            p_more_info4   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).return_reason_code);
                                END;
                            END IF;

                            log_records (
                                gc_debug_flag,
                                'l_new_reason_code=> ' || l_new_reason_code);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'l_new_reason_code=> ' || l_new_reason_code);

                            --SHIP_METHOD_CODE at line level

                            IF lt_oe_lines_data (xc_line_idx).SHIPPING_METHOD_CODE
                                   IS NOT NULL
                            THEN
                                BEGIN
                                    SELECT new_ship_method_code
                                      INTO lc_new_line_ship_method_code
                                      FROM xxd_1206_ship_methods_map_t
                                     WHERE old_ship_method_code =
                                           lt_oe_lines_data (xc_line_idx).shipping_method_code;
                                /*   SELECT b.ship_method_code
                                   INTO   lc_new_line_ship_method_code
                                   FROM   wsh_org_carrier_services_v a
                                         ,wsh_carrier_services_v     b
                                   WHERE  a.carrier_service_id = b.carrier_service_id
                                   AND    b.enabled_flag = 'Y'
                                   AND    b.ship_method_code =lt_oe_lines_data(xc_line_idx).shipping_method_code
                                   AND    a.enabled_flag = 'Y'
                                   AND    a.organization_id = lt_oe_header_data(xc_header_idx).ship_from_org_id;    */


                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        /*  lc_error_message  := 'Ship Method Code is not available in the System in no data found';
                                          lc_oe_line_valid_data := gc_no_flag;
                                          xxd_common_utils.record_error (
                                                                          p_module       => 'ONT',
                                                                          p_org_id       => gn_org_id,
                                                                          p_program      => 'Deckers Open Sales Order Conversion Program',
                                                                          p_error_line   => SQLCODE,
                                                                          p_error_msg    => lc_error_message,
                                                                          p_created_by   => gn_user_id,
                                                                          p_request_id   => gn_conc_request_id,
                                                                          p_more_info1   => lt_oe_header_data(xc_header_idx).order_number,
                                                                          p_more_info2   => lt_oe_lines_data(xc_line_idx).line_number,
                                                                          p_more_info3   => 'LINE_SHIP_METHOD_CODE',
                                                                          p_more_info4   => lt_oe_lines_data(xc_line_idx).shipping_method_code
                                                                          ); */


                                        /*SELECT ship_method_code
                                        INTO   lc_new_line_ship_method_code
                                        FROM   wsh_carriers_v         a
                                              ,wsh_carrier_services_v b
                                        WHERE  a.carrier_id = b.carrier_id
                                        AND    a.carrier_name = 'CONVERSION'
                                        AND    a.active = 'A'
                                        AND    b.enabled_flag = 'Y'
                                        AND    b.ship_method_meaning = 'CONV-ORG';    */


                                        NULL;

                                        SELECT ship_method_code
                                          INTO lc_new_line_ship_method_code
                                          FROM wsh_carriers_v a, wsh_carrier_services_v b
                                         WHERE     a.carrier_id =
                                                   b.carrier_id
                                               AND a.carrier_name =
                                                   'CONVERSION'
                                               AND a.active = 'A'
                                               AND b.enabled_flag = 'Y'
                                               AND b.ship_method_meaning =
                                                   'CONV-CODE';

                                        log_records (
                                            gc_debug_flag,
                                               'shipping method code in no data found assiging default=> '
                                            || lc_new_line_ship_method_code);
                                    WHEN OTHERS
                                    THEN
                                        lc_error_message        :=
                                            'Ship Method Code is not available in the System when others';
                                        lc_oe_line_valid_data   := gc_no_flag;
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
                                            p_more_info2   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).line_number,
                                            p_more_info3   =>
                                                'LINE_SHIP_METHOD_CODE',
                                            p_more_info4   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).shipping_method_code);
                                END;

                                IF     lc_new_line_ship_method_code
                                           IS NOT NULL
                                   AND ln_ship_from_org_id IS NOT NULL
                                THEN
                                    log_records (
                                        gc_debug_flag,
                                           '@70shipping method code count at header '
                                        || ln_ship_method_header);
                                    ln_ship_method_header   := 0;

                                    SELECT COUNT (a.organization_id)
                                      INTO ln_ship_method_header
                                      FROM wsh_org_carrier_services_v a, wsh_carrier_services_v b
                                     WHERE     a.carrier_service_id =
                                               b.carrier_service_id
                                           AND b.enabled_flag = 'Y'
                                           AND b.ship_method_code =
                                               lc_new_line_ship_method_code
                                           AND a.enabled_flag = 'Y'
                                           AND a.organization_id =
                                               ln_ship_from_org_id;

                                    log_records (
                                        gc_debug_flag,
                                           '@80shipping method code count at header '
                                        || ln_ship_method_header);

                                    IF ln_ship_method_header = 0
                                    THEN
                                        SELECT ship_method_code
                                          INTO lc_new_line_ship_method_code
                                          FROM wsh_carriers_v a, wsh_carrier_services_v b
                                         WHERE     a.carrier_id =
                                                   b.carrier_id
                                               AND a.carrier_name =
                                                   'CONVERSION'
                                               AND a.active = 'A'
                                               AND b.enabled_flag = 'Y'
                                               AND b.ship_method_meaning =
                                                   'CONV-ORG';

                                        log_records (
                                            gc_debug_flag,
                                               '@90shipping method code count at header '
                                            || ln_ship_method_header);
                                    END IF;
                                END IF;
                            ELSE
                                lc_new_line_ship_method_code   := NULL;
                            END IF;


                            --            salesrep_number
                            IF lt_oe_lines_data (xc_line_idx).salesrep_number
                                   IS NOT NULL
                            THEN
                                BEGIN
                                    SELECT rs.salesrep_id
                                      INTO ln_new_salesrep_id_l
                                      FROM apps.jtf_rs_salesreps rs, apps.JTF_RS_RESOURCE_EXTNS_VL RES, hr_organization_units hou
                                     WHERE     hou.organization_id =
                                               rs.org_id
                                           AND rs.resource_id =
                                               res.resource_id
                                           AND rs.salesrep_number =
                                               TO_CHAR (
                                                   lt_oe_lines_data (
                                                       xc_line_idx).salesrep_number)
                                           AND org_id = ln_new_org_id;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        BEGIN
                                            SELECT rs.salesrep_id
                                              INTO ln_new_salesrep_id
                                              FROM apps.jtf_rs_salesreps rs, apps.JTF_RS_RESOURCE_EXTNS_VL RES, hr_organization_units hou
                                             WHERE     hou.organization_id =
                                                       rs.org_id
                                                   AND rs.resource_id =
                                                       res.resource_id
                                                   AND rs.salesrep_number =
                                                       TO_CHAR ('10648')
                                                   AND org_id = ln_new_org_id;
                                        EXCEPTION
                                            WHEN NO_DATA_FOUND
                                            THEN
                                                lc_oe_header_valid_data   :=
                                                    gc_no_flag;
                                                lc_error_message   :=
                                                       'salesrep_number CONV_REP for org id '
                                                    || ln_new_org_id
                                                    || ' is not available in the System';
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                    lc_error_message); --jerry
                                                xxd_common_utils.record_error (
                                                    p_module       => 'ONT',
                                                    p_org_id       => gn_org_id,
                                                    p_program      =>
                                                        'Deckers Wholesale Sales Order Conversion Program',
                                                    p_error_line   => SQLCODE,
                                                    p_error_msg    =>
                                                        lc_error_message,
                                                    p_created_by   =>
                                                        gn_user_id,
                                                    p_request_id   =>
                                                        gn_conc_request_id,
                                                    p_more_info1   =>
                                                        lt_oe_header_data (
                                                            xc_header_idx).order_number,
                                                    p_more_info2   =>
                                                        'salesrep_number',
                                                    p_more_info3   =>
                                                        lt_oe_lines_data (
                                                            xc_line_idx).salesrep_number);
                                        END;
                                    WHEN OTHERS
                                    THEN
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                        lc_error_message   :=
                                               'salesrep_number CONV_REP for org id '
                                            || ln_new_org_id
                                            || ' is not available in the System '
                                            || SQLERRM;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           lc_error_message);
                                        xxd_common_utils.record_error (
                                            p_module       => 'ONT',
                                            p_org_id       => gn_org_id,
                                            p_program      =>
                                                'Deckers Wholesale Sales Order Conversion Program',
                                            p_error_line   => SQLCODE,
                                            p_error_msg    => lc_error_message,
                                            p_created_by   => gn_user_id,
                                            p_request_id   =>
                                                gn_conc_request_id,
                                            p_more_info1   =>
                                                lt_oe_header_data (
                                                    xc_header_idx).order_number,
                                            p_more_info2   =>
                                                'salesrep_number',
                                            p_more_info3   =>
                                                lt_oe_lines_data (
                                                    xc_line_idx).salesrep_number);
                                END;
                            ELSE
                                BEGIN
                                    SELECT rs.salesrep_id
                                      INTO ln_new_salesrep_id
                                      FROM apps.jtf_rs_salesreps rs, apps.JTF_RS_RESOURCE_EXTNS_VL RES, hr_organization_units hou
                                     WHERE     hou.organization_id =
                                               rs.org_id
                                           AND rs.resource_id =
                                               res.resource_id
                                           AND rs.salesrep_number =
                                               TO_CHAR ('10648')
                                           AND org_id = ln_new_org_id;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                        lc_error_message   :=
                                               'salesrep_number CONV_REP for org id '
                                            || ln_new_org_id
                                            || ' is not available in the System';
                                        fnd_file.put_line (fnd_file.LOG,
                                                           lc_error_message);
                                        xxd_common_utils.record_error (
                                            p_module       => 'ONT',
                                            p_org_id       => gn_org_id,
                                            p_program      =>
                                                'Deckers wholesale Sales Order Conversion Program',
                                            p_error_line   => SQLCODE,
                                            p_error_msg    => lc_error_message,
                                            p_created_by   => gn_user_id,
                                            p_request_id   =>
                                                gn_conc_request_id,
                                            p_more_info1   =>
                                                lt_oe_header_data (
                                                    xc_header_idx).order_number,
                                            p_more_info2   =>
                                                'salesrep_number',
                                            p_more_info3   =>
                                                lt_oe_header_data (
                                                    xc_header_idx).salesrep_number);
                                    WHEN OTHERS
                                    THEN
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                        lc_error_message   :=
                                               'salesrep_number CONV_REP for org id '
                                            || ln_new_org_id
                                            || ' is not available in the System '
                                            || SQLERRM;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           lc_error_message);
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
                                                'salesrep_number',
                                            p_more_info3   =>
                                                lt_oe_header_data (
                                                    xc_header_idx).salesrep_number);
                                END;
                            END IF;

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
                                             AND ROWNUM = 1 --jerry modify 20-may for error exact fetch returns more than requested number of rows
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
                                    --jerry modify 20-may
                                    WHEN OTHERS
                                    THEN
                                        ln_new_ret_header_id   := NULL;
                                        ln_new_ret_line_id     := NULL;
                                END;
                            ELSE
                                ln_new_ret_header_id   := NULL;
                                ln_new_ret_line_id     := NULL;
                            END IF;



                            ------    Duplicate line validation

                            BEGIN
                                SELECT COUNT (*)
                                  INTO l_duplicate_num
                                  FROM xxd_so_ws_lines_conv_stg_t
                                 WHERE     line_number =
                                           lt_oe_lines_data (xc_line_idx).line_number
                                       AND header_id =
                                           lt_oe_lines_data (xc_line_idx).header_id;


                                IF l_duplicate_num > 1
                                THEN
                                    SELECT MAX (line_number) + 1
                                      INTO l_new_line_num
                                      FROM xxd_so_ws_lines_conv_stg_t
                                     WHERE header_id =
                                           lt_oe_lines_data (xc_line_idx).header_id;

                                    --log_records(gc_debug_flag,'l_new_line_num' ||l_new_line_num);

                                    UPDATE xxd_so_ws_lines_conv_stg_t
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


                            IF ln_line_ship_to_site_id IS NULL
                            THEN
                                ln_line_ship_to_site_id   :=
                                    ln_new_ship_to_site_id;
                            END IF;


                            IF lt_oe_lines_data (xc_line_idx).ship_from
                                   IS NOT NULL
                            THEN
                                ln_line_ship_from_org_id   :=
                                    get_new_inv_org_id (
                                        p_old_org_id   =>
                                            lt_oe_lines_data (xc_line_idx).ship_from);

                                IF ln_line_ship_from_org_id IS NULL
                                THEN
                                    lc_oe_line_valid_data   := gc_no_flag;
                                    lc_error_message        :=
                                        'No Ship From Organization is not available in the System';
                                    xxd_common_utils.record_error (
                                        p_module       => 'ONT',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers Open Sales Order Conversion Program',
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
                                            lt_oe_lines_data (xc_line_idx).SHIP_FROM);
                                END IF;
                            ELSE
                                ln_line_ship_from_org_id   :=
                                    ln_ship_from_org_id;
                            END IF;

                            IF     lt_oe_header_data (xc_header_idx).ship_from_org_id
                                       IS NULL
                               AND ln_line_ship_from_org_id IS NOT NULL
                            THEN
                                ln_ship_from_org_id   :=
                                    ln_line_ship_from_org_id;
                            END IF;

                            BEGIN
                                --    Inventory validation
                                SELECT inventory_item_id
                                  INTO ln_inventory_item_id
                                  FROM mtl_system_items_b
                                 WHERE --  segment1 = lt_oe_lines_data(xc_line_idx).item_segment1
                                           --Meenakshi 8-Jul
                                           inventory_item_id =
                                           lt_oe_lines_data (xc_line_idx).old_inventory_item_id
                                       AND organization_id =
                                           ln_line_ship_from_org_id
                                       AND customer_order_flag = 'Y'
                                       AND customer_order_enabled_flag = 'Y'
                                       AND inventory_item_status_code =
                                           'Active';
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    lc_oe_line_valid_data   := gc_no_flag;
                                    lc_error_message        :=
                                        'ITEM_SEGMENT1 is not available in the System';
                                    xxd_common_utils.record_error (
                                        p_module       => 'ONT',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers Open Sales Order Conversion Program',
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
                                        'ITEM_SEGMENT1 is not available in the System';
                                    xxd_common_utils.record_error (
                                        p_module       => 'ONT',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers Open Sales Order Conversion Program',
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

                            lx_return_status               := NULL;

                            -- Meenakshi Tax Validation Changes
                            BEGIN
                                SELECT  --rates.TAX_RATE_CODE  TAX_RATE_code ,
                                       SUM (adj.operand) PERCENTAGE_RATE
                                  INTO                      --l_1206_tax_code,
                                       l_1206_tax_rate
                                  FROM    -- xxd_so_ws_lines_conv_stg_t lines,
                                       xxd_conv.xxd_1206_OE_PRICE_ADJUSTMENTs adj, xxd_conv.xxd_1206_ZX_RATES_B rates
                                 WHERE     lt_oe_lines_data (xc_line_idx).header_id =
                                           adj.header_id
                                       AND lt_oe_lines_data (xc_line_idx).line_id =
                                           adj.line_id
                                       AND adj.tax_rate_id =
                                           rates.tax_rate_id
                                       -- and lines.tax_code is null
                                       AND (lt_oe_lines_data (xc_line_idx).TAX_CODE <> 'Exempt' OR lt_oe_lines_data (xc_line_idx).TAX_CODE IS NULL OR lt_oe_lines_data (xc_line_idx).TAX_CODE <> 'EU ZERO RATE')
                                       AND adj.LIST_LINE_TYPE_CODE = 'TAX'
                                       --   and to_date( nvl(lines.tax_date,sysdate),'DD-MM-YYYY') between to_date(rates.EFFECTIVE_FROM ,'DD/MM/YYYY')and to_date (nvl(rates.EFFECTIVE_TO,nvl(lines.tax_date,sysdate)),
                                       -- 'DD/MM/YYYY')
                                       AND NVL (
                                               lt_oe_lines_data (xc_line_idx).tax_date,
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

                            SELECT PTP.PARTY_TAX_PROFILE_ID
                              INTO l_content_owner_id
                              FROM apps.ZX_PARTY_TAX_PROFILE PTP, apps.HR_OPERATING_UNITS HOU
                             WHERE     PTP.PARTY_TYPE_CODE = 'OU'
                                   AND PTP.PARTY_ID = HOU.ORGANIZATION_ID
                                   AND HOU.ORGANIZATION_ID = ln_new_org_id;

                            BEGIN
                                IF l_1206_tax_rate IS NOT NULL
                                THEN
                                    SELECT DISTINCT zb.tax_rate_code
                                      INTO l_new_rate_code
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
                                           AND NVL (zb.effective_to, SYSDATE) >=
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
                                               l_content_owner_id    -- 812722
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
                                           AND ROWNUM = 1;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_new_rate_code   := NULL;
                            END;

                            IF    l_new_rate_code IS NULL
                               OR l_1206_tax_rate = NULL
                            THEN
                                BEGIN
                                    SELECT DISTINCT zb.tax_rate_code
                                      INTO l_new_rate_code
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
                                           AND NVL (zb.effective_to, SYSDATE) >=
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
                                               l_content_owner_id    -- 812722
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
                                           AND ROWNUM = 1;

                                    l_1206_tax_rate   := 0;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_new_rate_code   := NULL;
                                        l_1206_tax_rate   := NULL;
                                END;
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

                            l_new_tax_date                 :=
                                lt_oe_lines_data (xc_line_idx).tax_date;

                            IF ln_new_org_id = 95
                            THEN
                                BEGIN
                                    SELECT fpov.PROFILE_OPTION_VALUE
                                      INTO l_vertex_tax_date
                                      FROM fnd_profile_option_values fpov, fnd_profile_options fpo
                                     WHERE     fpo.profile_option_id =
                                               fpov.profile_option_id
                                           AND profile_option_name =
                                               'XXD_CONV_TAX_DATE';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_vertex_tax_date   := NULL;
                                END;

                                IF     l_vertex_tax_date IS NOT NULL
                                   AND lt_oe_lines_data (xc_line_idx).tax_date >=
                                       TO_DATE (l_vertex_tax_date,
                                                'DD-MON-YYYY')
                                THEN
                                    l_new_tax_date   :=
                                          TO_DATE (l_vertex_tax_date,
                                                   'DD-MON-YYYY')
                                        - 1;
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

                            log_records (
                                gc_debug_flag,
                                '@@@@@@@2=> ' || lc_oe_header_valid_data);

                            IF    lc_oe_line_valid_data = gc_no_flag
                               OR lc_oe_header_valid_data = gc_no_flag
                            THEN
                                UPDATE XXD_SO_WS_LINES_CONV_STG_T
                                   SET record_status = gc_error_status, new_line_type_id = ln_new_line_type_id, inventory_item_id = ln_inventory_item_id,
                                       new_ship_from = ln_line_ship_from_org_id, new_ship_to_site = ln_line_ship_to_site_id, new_shipping_method_code = lc_new_line_ship_method_code,
                                       new_return_reason_code = l_new_reason_code, new_tax_code = l_new_rate_code, --ln_tax_code,
                                                                                                                   tax_rate = l_1206_tax_rate,
                                       NEW_SALESREP_ID = ln_new_salesrep_id_l, new_reference_header_id = ln_new_ret_header_id, new_reference_line_id = ln_new_ret_line_id,
                                       NEW_ATTRIBUTE4 = l_new_attribute4, tax_date = l_new_tax_date
                                 WHERE record_id =
                                       lt_oe_lines_data (xc_line_idx).record_id;

                                lc_oe_header_valid_data   := gc_no_flag;
                            ELSE
                                UPDATE XXD_SO_WS_LINES_CONV_STG_T
                                   SET record_status = gc_validate_status, new_line_type_id = ln_new_line_type_id, inventory_item_id = ln_inventory_item_id,
                                       new_ship_from = ln_line_ship_from_org_id, new_ship_to_site = ln_line_ship_to_site_id, new_shipping_method_code = lc_new_line_ship_method_code,
                                       new_return_reason_code = l_new_reason_code, new_tax_code = l_new_rate_code, --ln_tax_code,
                                                                                                                   tax_rate = l_1206_tax_rate,
                                       NEW_SALESREP_ID = ln_new_salesrep_id_l, new_reference_header_id = ln_new_ret_header_id, new_reference_line_id = ln_new_ret_line_id,
                                       NEW_ATTRIBUTE4 = l_new_attribute4, tax_date = l_new_tax_date
                                 WHERE record_id =
                                       lt_oe_lines_data (xc_line_idx).record_id;
                            END IF;
                        END LOOP;
                    END IF;

                    --------------------------------------------------------------------------------------------------------------------------

                    log_records (gc_debug_flag,
                                 '@@@@@@@3=> ' || lc_oe_header_valid_data);



                    --Price Adjustment line validation
                    OPEN cur_oe_price_adj_lines (
                        p_header_id   =>
                            lt_oe_header_data (xc_header_idx).header_id);

                    FETCH cur_oe_price_adj_lines
                        BULK COLLECT INTO lt_oe_price_adj_lines_data;

                    log_records (
                        gc_debug_flag,
                           'validate Price Lines Adjustments '
                        || lt_oe_price_adj_lines_data.COUNT);

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
                                    l_list_type_code   := NULL;
                                    log_records (
                                        gc_debug_flag,
                                           '@@before select  => '
                                        || l_list_type_code);

                                    SELECT LIST_TYPE_CODE
                                      INTO l_list_type_code
                                      FROM apps.xxd_qp_list_headers_stg_t b, xxd_conv.xxd_ont_ws_price_adj_l_stg_t c
                                     WHERE     b.list_header_id =
                                               lt_oe_price_adj_lines_data (
                                                   xc_line_idx).list_header_id
                                           AND b.list_header_id =
                                               c.LIST_HEADER_ID
                                           AND c.modifier_level_code = 'LINE'
                                           AND c.line_id =
                                               lt_oe_price_adj_lines_data (
                                                   xc_line_idx).line_id
                                           AND c.price_adjustment_id =
                                               lt_oe_price_adj_lines_data (
                                                   xc_line_idx).price_adjustment_id;


                                    log_records (
                                        gc_debug_flag,
                                           '@@after select => '
                                        || l_list_type_code);

                                    IF l_list_type_code = 'DLT'
                                    THEN
                                        SELECT qph.list_header_id, qpl.list_line_id, qpl.list_line_no
                                          INTO ln_new_list_h_id, ln_new_list_l_id, ln_list_line_no
                                          FROM qp_list_headers qph, qp_list_lines qpl
                                         WHERE     qph.list_header_id =
                                                   qpl.list_header_id
                                               --AND        qph.name =lt_oe_price_adj_lines_data(xc_line_idx).ADJUSTMENT_NAME
                                               AND qpl.modifier_level_code =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).modifier_level_code
                                               AND qpl.list_line_type_code =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).list_line_type_code
                                               AND NVL (qpl.end_date_active,
                                                        TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND qpl.pricing_phase_id =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).pricing_phase_id
                                               AND qph.currency_code =
                                                   lt_oe_header_data (
                                                       xc_header_idx).transactional_curr_code
                                               AND list_line_type_code =
                                                   'DIS'
                                               AND list_line_no LIKE 'BT%';

                                        log_records (
                                            gc_debug_flag,
                                               '@@ n DLT  => '
                                            || l_list_type_code);
                                    ELSIF l_list_type_code = 'CHARGES'
                                    THEN
                                        SELECT qph.list_header_id, qpl.list_line_id, qpl.list_line_no
                                          INTO ln_new_list_h_id, ln_new_list_l_id, ln_list_line_no
                                          FROM qp_list_headers qph, qp_list_lines qpl
                                         WHERE     qph.list_header_id =
                                                   qpl.list_header_id
                                               --AND        qph.name =lt_oe_price_adj_lines_data(xc_line_idx).ADJUSTMENT_NAME
                                               --AND        qpl.charge_type_code='CONVERSION'
                                               AND qpl.modifier_level_code =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).modifier_level_code
                                               AND qpl.list_line_type_code =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).list_line_type_code
                                               AND NVL (qpl.end_date_active,
                                                        TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND qpl.pricing_phase_id =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).pricing_phase_id
                                               AND qph.currency_code =
                                                   lt_oe_header_data (
                                                       xc_header_idx).transactional_curr_code
                                               AND list_line_no LIKE 'BT%';

                                        log_records (
                                            gc_debug_flag,
                                               '@@in charges at line  => '
                                            || l_list_type_code);
                                    ELSIF l_list_type_code = 'SLT'
                                    THEN
                                        SELECT qph.list_header_id, qpl.list_line_id, qpl.list_line_no
                                          INTO ln_new_list_h_id, ln_new_list_l_id, ln_list_line_no
                                          FROM qp_list_headers qph, qp_list_lines qpl
                                         WHERE     qph.list_header_id =
                                                   qpl.list_header_id
                                               --AND        qph.name =lt_oe_price_adj_lines_data(xc_line_idx).ADJUSTMENT_NAME
                                               AND qpl.list_line_type_code =
                                                   'SUR'
                                               AND qpl.modifier_level_code =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).modifier_level_code
                                               --AND        qpl.list_line_type_code = lt_oe_price_adj_lines_data(xc_line_idx).list_line_type_code
                                               AND NVL (qpl.end_date_active,
                                                        TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND qpl.pricing_phase_id =
                                                   lt_oe_price_adj_lines_data (
                                                       xc_line_idx).pricing_phase_id
                                               AND qph.currency_code =
                                                   lt_oe_header_data (
                                                       xc_header_idx).transactional_curr_code
                                               AND list_line_no LIKE 'BT%';

                                        log_records (
                                            gc_debug_flag,
                                               '@@in sur at line  => '
                                            || l_list_type_code);
                                    END IF;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                        lc_oe_line_valid_data   := gc_no_flag;
                                        lc_error_message        :=
                                            'List header id or line id not found is not available in the System(NO_DATA_FOUND)';
                                        xxd_common_utils.record_error (
                                            p_module       => 'ONT',
                                            p_org_id       => gn_org_id,
                                            p_program      =>
                                                'Deckers Open Sales Order Wholesale Conversion Program',
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

                                log_records (
                                    gc_debug_flag,
                                    '@@@@@@@6=> ' || lc_oe_header_valid_data);

                                BEGIN
                                    IF    lc_oe_line_valid_data = gc_no_flag
                                       OR lc_oe_header_valid_data =
                                          gc_no_flag
                                    THEN
                                        UPDATE xxd_ont_ws_price_adj_l_stg_t
                                           SET record_status = gc_error_status, new_list_header_id = ln_new_list_h_id, new_list_line_id = ln_new_list_l_id,
                                               new_list_line_no = ln_list_line_no
                                         WHERE record_id =
                                               lt_oe_price_adj_lines_data (
                                                   xc_line_idx).record_id;

                                        log_records (
                                            gc_debug_flag,
                                               '@@@@@@@7=> '
                                            || lc_oe_header_valid_data);
                                        lc_oe_header_valid_data   :=
                                            gc_no_flag;
                                    ELSE
                                        UPDATE xxd_ont_ws_price_adj_l_stg_t
                                           SET record_status = gc_validate_status, new_list_header_id = ln_new_list_h_id, new_list_line_id = ln_new_list_l_id,
                                               new_list_line_no = ln_list_line_no
                                         WHERE record_id =
                                               lt_oe_price_adj_lines_data (
                                                   xc_line_idx).record_id;

                                        log_records (
                                            gc_debug_flag,
                                               '@@@@@@@8=> '
                                            || lc_oe_header_valid_data);
                                    END IF;
                                --commit;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.OUTPUT,
                                               'Error during price adj stage table update'
                                            || SQLERRM);
                                END;
                            END LOOP;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.OUTPUT,
                                   'Error during price adj stage table update'
                                || SQLERRM);
                    END;



                    --------------------------------------------------------------------------------------------------------------------------------------------------
                    log_records (gc_debug_flag,
                                 '@@@@@@@9=> ' || lc_oe_header_valid_data);

                    IF lc_oe_header_valid_data = gc_no_flag
                    THEN
                        UPDATE XXD_SO_WS_HEADERS_CONV_STG_T
                           SET record_status = gc_error_status, new_customer_id = ln_new_customer_id, new_sold_to_org_id = ln_new_sold_to_org_id,
                               new_ship_to_site_id = ln_new_ship_to_site_id, new_bill_to_site_id = ln_new_bill_to_site_id, new_ship_from_org_id = ln_ship_from_org_id,
                               new_pay_term_id = ln_new_pay_term_id, new_salesrep_id = ln_new_salesrep_id, new_pricelist_id = ln_new_pricelist_id,
                               new_sales_channel_code = lc_new_sales_channel_code, new_order_source_id = ln_new_source_id, new_order_type_id = ln_new_order_type_id,
                               new_org_id = ln_new_org_id
                         WHERE record_id =
                               lt_oe_header_data (xc_header_idx).record_id;
                    ELSE
                        UPDATE XXD_SO_WS_HEADERS_CONV_STG_T
                           SET record_status = gc_validate_status, new_customer_id = ln_new_customer_id, new_sold_to_org_id = ln_new_sold_to_org_id,
                               new_ship_to_site_id = ln_new_ship_to_site_id, new_bill_to_site_id = ln_new_bill_to_site_id, new_ship_from_org_id = ln_ship_from_org_id,
                               new_pay_term_id = ln_new_pay_term_id, new_salesrep_id = ln_new_salesrep_id, new_pricelist_id = ln_new_pricelist_id,
                               new_order_source_id = ln_new_source_id, new_order_type_id = ln_new_order_type_id, new_org_id = ln_new_org_id,
                               new_ship_method_code = lc_new_ship_method_code, new_sales_channel_code = lc_new_sales_channel_code
                         WHERE record_id =
                               lt_oe_header_data (xc_header_idx).record_id;
                    END IF;
                END LOOP;                                         -- qp_header
            END IF;

            log_records (gc_debug_flag,
                         '@@@@@@@11=> ' || lc_oe_header_valid_data);
            --------------------------------------------------------------------------------

            COMMIT;
        END LOOP;

        CLOSE cur_oe_header;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETCODE   := 2;
            ERRBUF    := ERRBUF || SQLERRM;
            ROLLBACK;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.output,
                'Exception Raised During Order Header Validation Program');
            ROLLBACK;
            RETCODE   := 2;
            ERRBUF    := ERRBUF || SQLERRM;
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
        lv_error_stage              VARCHAR2 (2050) := NULL;
        ln_record_count             NUMBER := 0;
        lv_string                   LONG;

        -- ln_tax_code         VARCHAR2(250)             :=NULL;



        CURSOR lcu_eComm_orders (ln_org_id NUMBER)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ont_so_headers_conv_v XOEH
             WHERE     creation_date > SYSDATE - 365
                   AND EXISTS
                           (SELECT 1
                              FROM hz_cust_accounts_all
                             WHERE     cust_account_id = XOEH.sold_to_org_id
                                   AND attribute18 IS NOT NULL)
                   AND org_id = ln_org_id
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_1206_order_type_map_t xom
                             WHERE     XOEH.order_type =
                                       xom.legacy_12_0_6_name
                                   AND new_12_2_3_name =
                                       NVL (p_org_type, new_12_2_3_name)
                                   AND order_category = p_order_ret_type);


        CURSOR lcu_noneComm_orders (ln_org_id NUMBER)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ont_so_headers_conv_v XOEH
             WHERE     1 = 1
                   AND TRUNC (creation_date) >
                       TO_DATE ('31-DEC-2013', 'DD-MON-YYYY')
                   AND org_id = ln_org_id
                   AND XOEH.flow_status_code NOT IN
                           ('CANCELLED', 'ENTERED', 'CLOSED')
                   --AND XOEH.sold_to_org_id =922547
                   --   AND XOEH.order_number  in (52440630,51800460)
                   --AND rownum<101
                   AND EXISTS
                           (SELECT 1
                              FROM hz_cust_accounts_all
                             WHERE     cust_account_id = XOEH.sold_to_org_id
                                   AND attribute18 IS NULL)
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_1206_order_type_map_t xom
                             WHERE     XOEH.order_type =
                                       xom.legacy_12_0_6_name
                                   AND new_12_2_3_name =
                                       NVL (p_org_type, new_12_2_3_name)
                                   AND order_category = p_order_ret_type);


        CURSOR lcu_order_lines (ln_org_id NUMBER)
        IS
            SELECT /*+  driving_site(oel)   parallel(oel) no_merge  */
                   oel.line_id,
                   oel.header_id,
                   oel.line_number,
                   oel.order_quantity_uom,
                   oel.ordered_quantity,
                   oel.shipped_quantity,
                   oel.cancelled_quantity,
                   oel.fulfilled_quantity,
                   oel.inventory_item_id inventory_item,
                   oel.ORDERED_ITEM item_segment1,
                   NULL item_segment2,
                   NULL item_segment3,
                   oel.unit_selling_price,
                   oel.unit_list_price,
                   oel.TAX_DATE,
                   oel.TAX_CODE,
                   oel.TAX_RATE,
                   oel.TAX_VALUE,
                   oel.TAX_EXEMPT_FLAG,
                   oel.TAX_EXEMPT_NUMBER,
                   oel.TAX_EXEMPT_REASON_CODE,
                   oel.TAX_POINT_CODE,
                   oel.shipping_method_code,
                   oel.customer_line_number,
                   oel.invoice_to_org_id,
                   oel.ship_to_org_id,
                   oel.ship_from_org_id,
                   oel.promise_date,
                   oel.ORIG_SYS_DOCUMENT_REF,
                   oel.ORIG_SYS_LINE_REF,
                   oel.schedule_ship_date,
                   oel.PRICING_DATE,
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
                   oel.ATTRIBUTE16,
                   oel.ATTRIBUTE17,
                   oel.ATTRIBUTE18,
                   oel.ATTRIBUTE19,
                   oel.ATTRIBUTE20,
                   oel.org_id,
                   (SELECT ottt.name
                      FROM oe_transaction_types_tl@BT_READ_1206 ottt
                     WHERE     ottt.transaction_type_id = oel.line_type_id
                           AND ottt.language = 'US') line_type_id,
                   oel.CUST_PO_NUMBER,
                   oel.SHIP_TOLERANCE_ABOVE,
                   oel.SHIP_TOLERANCE_BELOW,
                   oel.FOB_POINT_CODE,
                   oel.ITEM_TYPE_CODE,
                   oel.LINE_CATEGORY_CODE,
                   oel.SOURCE_TYPE_CODE,
                   oel.RETURN_REASON_CODE,
                   oel.OPEN_FLAG,
                   oel.BOOKED_FLAG,
                   oel.ship_from_org_id,
                   oel.flow_status_code,
                   oel.LATEST_ACCEPTABLE_DATE,
                   oel.schedule_arrival_date--Meenakshi 15-Jun
                                            ,
                   oel.actual_shipment_date-- Meenakshi 25-Aug
                                           ,
                   (SELECT rsa.salesrep_number
                      FROM ra_salesreps_all@BT_READ_1206 rsa
                     WHERE     rsa.SALESREP_ID = oel.SALESREP_ID
                           AND rsa.org_id = oel.org_id) salesrep_number,
                   oel.SHIPMENT_PRIORITY_CODE,
                   oel.request_date,
                   oel.SHIPPING_INSTRUCTIONS,
                   --return
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
                   oel.return_context,
                   oel.FULFILLMENT_DATE,
                   oel.subinventory
              FROM xxd_1206_oe_order_lines_all oel
             --        SELECT
             --                /*+leading(XOEL,xsh) parallel(xsh) no_merge */ *
             --        FROM   XXD_ONT_SO_LINES_CONV_V   XOEL
             WHERE     1 = 1
                   AND flow_status_code IN ('CANCELLED', 'CLOSED', 'AWAITING_SHIPPING',
                                            'AWAITING_RETURN', 'BOOKED')
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_so_ws_headers_conv_stg_t xsh
                             WHERE     oel.header_id = xsh.header_id
                                   AND record_status = gc_new_status
                                   AND org_id = ln_org_id);

        CURSOR lcu_price_adj_lines (ln_org_id NUMBER)
        IS
            SELECT *
              FROM xxd_1206_oe_price_adjust_v oel
             WHERE     1 = 1
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_so_ws_headers_conv_stg_t xsh
                             WHERE     oel.header_id = xsh.header_id
                                   AND record_status = gc_new_status
                                   AND org_id = ln_org_id);


        TYPE XXD_ONT_ORDER_HEADER_TAB
            IS TABLE OF XXD_ONT_SO_HEADERS_CONV_V%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ont_order_header_tab      XXD_ONT_ORDER_HEADER_TAB;

        TYPE XXD_ONT_ORDER_LINES_TAB
            IS TABLE OF XXD_ONT_SO_LINES_CONV_V%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ont_order_lines_tab       XXD_ONT_ORDER_LINES_TAB;

        TYPE XXD_ONT_PRICE_ADJ_LINES_TAB
            IS TABLE OF XXD_1206_OE_PRICE_ADJUST_V%ROWTYPE
            INDEX BY BINARY_INTEGER;

        t_ont_price_adj_lines_tab   XXD_ONT_PRICE_ADJ_LINES_TAB;
    BEGIN
        t_ont_order_header_tab.delete;
        gtt_ont_order_lines_tab.delete;
        lv_error_stage   :=
               'Inserting Order_headers  Data p_customer_type =>'
            || p_customer_type;
        fnd_file.put_line (fnd_file.LOG, lv_error_stage);

        IF p_customer_type = 'eComm'
        THEN
            NULL;
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
                fnd_file.put_line (fnd_file.LOG, lc_org.lookup_code);

                OPEN lcu_noneComm_orders (TO_NUMBER (lc_org.lookup_code));

                LOOP
                    lv_error_stage   := 'Inserting Order_headers Data';
                    fnd_file.put_line (fnd_file.LOG, lv_error_stage);
                    t_ont_order_header_tab.delete;

                    FETCH lcu_noneComm_orders
                        BULK COLLECT INTO t_ont_order_header_tab
                        LIMIT 2000;

                    FORALL l_indx IN 1 .. t_ont_order_header_tab.COUNT
                        INSERT INTO xxd_so_ws_headers_conv_stg_t (
                                        record_id,
                                        record_status,
                                        header_id,
                                        org_id,
                                        order_source,
                                        order_type,
                                        ordered_date,
                                        booked_flag,
                                        FLOW_STATUS_CODE,
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
                                        salesrep_number,
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
                                        return_reason_code,
                                        customer_type,
                                        customer_preference_set_code)
                                 VALUES (
                                            xxd_ont_so_header_conv_stg_s.NEXTVAL,
                                            'N',
                                            t_ont_order_header_tab (l_indx).header_id,
                                            t_ont_order_header_tab (l_indx).org_id,
                                            t_ont_order_header_tab (l_indx).order_source,
                                            t_ont_order_header_tab (l_indx).order_type,
                                            t_ont_order_header_tab (l_indx).ordered_date,
                                            t_ont_order_header_tab (l_indx).booked_flag,
                                            t_ont_order_header_tab (l_indx).FLOW_STATUS_CODE,
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
                                            --    FND_DATE.DATE_TO_CANONICAL(to_date ( t_ont_order_header_tab (l_indx).attribute1,'YYYY/MM/DD')),
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
                                            t_ont_order_header_tab (l_indx).salesrep_number,
                                            t_ont_order_header_tab (l_indx).payment_term_name,
                                            t_ont_order_header_tab (l_indx).invoice_to_org_id,
                                            t_ont_order_header_tab (l_indx).ship_to_org_id,
                                            t_ont_order_header_tab (l_indx).ship_from_org_id,
                                            t_ont_order_header_tab (l_indx).order_number,
                                            t_ont_order_header_tab (l_indx).ORIG_SYS_DOCUMENT_REF,
                                            gn_user_id,
                                            SYSDATE,
                                            gn_user_id,
                                            SYSDATE,
                                            gn_conc_request_id,
                                            t_ont_order_header_tab (l_indx).return_reason_code,
                                            UPPER (p_customer_type),
                                            t_ont_order_header_tab (l_indx).customer_preference_set_code);

                    COMMIT;
                    EXIT WHEN lcu_noneComm_orders%NOTFOUND;
                END LOOP;

                CLOSE lcu_noneComm_orders;
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
                    INSERT INTO xxd_so_ws_lines_conv_stg_t (
                                    record_id,
                                    record_status,
                                    line_number,
                                    org_id,
                                    header_id,
                                    line_id,
                                    line_type,
                                    FLOW_STATUS_CODE,
                                    item_segment1,
                                    item_segment2,
                                    item_segment3,
                                    promise_date,
                                    order_quantity_uom,
                                    ordered_quantity,
                                    cancelled_quantity,
                                    shipped_quantity,
                                    UNIT_SELLING_PRICE,
                                    UNIT_LIST_PRICE,
                                    TAX_DATE,
                                    TAX_CODE,
                                    TAX_RATE,
                                    TAX_VALUE,
                                    TAX_EXEMPT_FLAG,
                                    TAX_EXEMPT_NUMBER,
                                    TAX_EXEMPT_REASON_CODE,
                                    TAX_POINT_CODE,
                                    schedule_ship_date,
                                    PRICING_DATE,
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
                                    ORIG_SYS_DOCUMENT_REF,
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
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    request_id,
                                    LATEST_ACCEPTABLE_DATE,
                                    schedule_arrival_date,
                                    --Meenakshi 15-Jun
                                    actual_shipment_date,
                                    old_inventory_item_id,
                                    SALESREP_NUMBER,
                                    SHIPMENT_PRIORITY_CODE,
                                    request_date,
                                    SHIPPING_INSTRUCTIONS,
                                    return_reason_code,
                                    reference_header_id,
                                    reference_line_id,
                                    ret_org_sys_doc_ref,
                                    ret_org_sys_line_ref,
                                    return_context,
                                    FULFILLED_QUANTITY,
                                    FULFILLMENT_DATE,
                                    subinventory)            --Meenakshi 8-Jul
                             VALUES (
                                        xxd_ont_so_line_conv_stg_s.NEXTVAL,
                                        'N',
                                        t_ont_order_lines_tab (l_indx).line_number,
                                        t_ont_order_lines_tab (l_indx).org_id,
                                        t_ont_order_lines_tab (l_indx).header_id,
                                        t_ont_order_lines_tab (l_indx).line_id,
                                        t_ont_order_lines_tab (l_indx).line_type,
                                        t_ont_order_lines_tab (l_indx).FLOW_STATUS_CODE,
                                        t_ont_order_lines_tab (l_indx).item_segment1,
                                        t_ont_order_lines_tab (l_indx).item_segment2,
                                        t_ont_order_lines_tab (l_indx).item_segment3,
                                        t_ont_order_lines_tab (l_indx).promise_date,
                                        t_ont_order_lines_tab (l_indx).order_quantity_uom,
                                        t_ont_order_lines_tab (l_indx).ordered_quantity,
                                        t_ont_order_lines_tab (l_indx).cancelled_quantity,
                                        t_ont_order_lines_tab (l_indx).shipped_quantity,
                                        t_ont_order_lines_tab (l_indx).UNIT_SELLING_PRICE,
                                        t_ont_order_lines_tab (l_indx).UNIT_LIST_PRICE,
                                        t_ont_order_lines_tab (l_indx).TAX_DATE,
                                        t_ont_order_lines_tab (l_indx).TAX_CODE,
                                        t_ont_order_lines_tab (l_indx).TAX_RATE,
                                        t_ont_order_lines_tab (l_indx).TAX_VALUE,
                                        t_ont_order_lines_tab (l_indx).TAX_EXEMPT_FLAG,
                                        t_ont_order_lines_tab (l_indx).TAX_EXEMPT_NUMBER,
                                        t_ont_order_lines_tab (l_indx).TAX_EXEMPT_REASON_CODE,
                                        t_ont_order_lines_tab (l_indx).TAX_POINT_CODE,
                                        t_ont_order_lines_tab (l_indx).schedule_ship_date,
                                        t_ont_order_lines_tab (l_indx).PRICING_DATE,
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
                                        t_ont_order_lines_tab (l_indx).ORIG_SYS_DOCUMENT_REF,
                                        t_ont_order_lines_tab (l_indx).ORIG_SYS_LINE_REF,
                                        t_ont_order_lines_tab (l_indx).attribute1,
                                        --   FND_DATE.DATE_TO_CANONICAL(to_date (t_ont_order_lines_tab (l_indx).attribute1,'YYYY/MM/DD')),
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
                                        gn_user_id,
                                        SYSDATE,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_conc_request_id,
                                        t_ont_order_lines_tab (l_indx).LATEST_ACCEPTABLE_DATE,
                                        t_ont_order_lines_tab (l_indx).schedule_arrival_date,
                                        --Meenakshi 15-Jun
                                        t_ont_order_lines_tab (l_indx).actual_shipment_date,
                                        t_ont_order_lines_tab (l_indx).inventory_item,
                                        t_ont_order_lines_tab (l_indx).SALESREP_NUMBER,
                                        t_ont_order_lines_tab (l_indx).SHIPMENT_PRIORITY_CODE,
                                        t_ont_order_lines_tab (l_indx).request_date,
                                        t_ont_order_lines_tab (l_indx).SHIPPING_INSTRUCTIONS,
                                        t_ont_order_lines_tab (l_indx).return_reason_code,
                                        TO_NUMBER (
                                            t_ont_order_lines_tab (l_indx).reference_header_id),
                                        TO_NUMBER (
                                            t_ont_order_lines_tab (l_indx).reference_line_id),
                                        t_ont_order_lines_tab (l_indx).ret_org_sys_doc_ref,
                                        t_ont_order_lines_tab (l_indx).ret_org_sys_line_ref,
                                        t_ont_order_lines_tab (l_indx).return_context,
                                        t_ont_order_lines_tab (l_indx).FULFILLED_QUANTITY,
                                        t_ont_order_lines_tab (l_indx).FULFILLMENT_DATE,
                                        t_ont_order_lines_tab (l_indx).subinventory); --Meenakshi 8-Jul

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
                --    fnd_file.put_line(fnd_file.log,lv_error_stage);
                t_ont_price_adj_lines_tab.delete;

                FETCH lcu_price_adj_lines
                    BULK COLLECT INTO t_ont_price_adj_lines_tab
                    LIMIT 2000;

                FORALL l_indx IN 1 .. t_ont_price_adj_lines_tab.COUNT
                    INSERT INTO xxd_ont_ws_price_adj_l_stg_t (
                                    record_id,
                                    record_status,
                                    --    v_rowid    ,
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
                                    -- change_sequence            ,
                                    list_header_id,
                                    list_line_id,
                                    list_line_type_code,
                                    modifier_mechanism_type_CODE,
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
                                    rebate_transaction_type_CODE,
                                    rebate_transaction_referENCE,
                                    rebate_payment_system_coDE,
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
                                    -- interco_invoiced_flag         ,
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
                                        --  t_ont_price_adj_lines_tab(l_indx).interco_invoiced_flag         ,
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
    /*PROCEDURE progress_order_main(
                        x_errbuff                       OUT   VARCHAR2,
                        x_retcode                       OUT   VARCHAR2,
                        P_debug_flag                    IN    VARCHAR2
                      )
    IS

    X_Return_Mesg               VARCHAR2(4000);
    x_return_sts                VARCHAR2(1);
    lc_query                    VARCHAR2(4000);
    lc_order_query              VARCHAR2(4000);
    lc_sort_option              VARCHAR2(4000);
    lc_customer_query           VARCHAR2(4000);
    lc_ship_date_query          VARCHAR2(4000);
    ln                          NUMBER:= 1;
    ld_from_ship_date           DATE;
    ld_to_ship_date             DATE;
    ln_from_cust_account_id     NUMBER;
    ln_to_cust_account_id       NUMBER;
    lc_final_query              VARCHAR2(4000);
    error_exception             EXCEPTION;
    log_msg                     VARCHAR2(4000);

    TYPE GetOrdList IS REF CURSOR;
    cur_order_header   GetOrdList;


    l_qry_orderinfo_tbl         p_qry_orderinfo_tbl;


    P_From_Order_Number                 NUMBER := NULL ;
    P_To_Order_Number                   NUMBER := NULL ;
    P_From_Sch_ship_confrim_date        VARCHAR2(250) := NULL ;
    P_To_Sch_ship_confrim_date          VARCHAR2(250) := NULL ;
    P_From_bill_to_customer             NUMBER := NULL ;
    P_to_bill_to_customer               NUMBER := NULL ;

    BEGIN


        GN_CONC_REQUEST_ID      := FND_GLOBAL.CONC_REQUEST_ID;          -- Concurrent Request Id
        GN_USER_ID              := FND_GLOBAL.USER_ID;                  -- User ID
        gd_sys_date              := SYSDATE;
        gc_debug_flag           := 'Y' ;

        x_return_sts            := GC_API_SUCCESS;
         --log_records (gc_debug_flag,'Start of Procedure import_main_prc ');

        -----------------------------------------------------
        -- Get the base query
        -----------------------------------------------------
        lc_query :=
                    'SELECT   distinct ooh.order_number,'
                || ' ooh.header_id,'
                || ' ooh.org_id,'
                || ' ooh.sold_to_org_id,'
                || ' hca.account_number,'
                || ' ool.line_id,'
                || ' ool.inventory_item_id,'
                || ' ool.ordered_item,'
                || ' ool.ship_from_org_id,'
                || ' ool.ship_to_org_id,'
                || ' ool.schedule_ship_date,'
                || ' wdd.ship_to_location_id,'
                || ' wdd.delivery_detail_id,'
                || ' wdd.released_status,'
                || ' wdd.released_status,'
                || ' wdd.project_id '
                || ' FROM     oe_order_headers_all ooh,'
                || '          oe_order_lines_all   ool,'
                || '          wsh_delivery_details wdd,'
                || '          hz_cust_accounts_all hca '
                || ' WHERE    1  = 1  '
                || ' AND      ooh.flow_status_code   = ' || '''BOOKED'''
                || ' AND OOH.order_number = ''50560663'' '
                || ' AND      ool.header_id          = ooh.header_id'
                || ' AND      ool.flow_status_code   = ' || '''AWAITING_SHIPPING'''
                || ' AND      wdd.released_status    IN (' || '''R''' || ',' || '''S'''|| ',' || '''Y'''|| ',' ||'''B''' || ')'
                || ' AND      wdd.org_id             =  ool.org_id'
                || ' AND      wdd.source_code        = '|| '''OE'''
                || ' AND      wdd.source_header_id   =  ool.header_id'
                || ' AND      wdd.source_line_id     =  ool.line_id'
                || ' AND      wdd.inventory_item_id  =  ool.inventory_item_id'
                || ' AND      hca.cust_account_id    =  ooh.sold_to_org_id'
                || ' AND      ool.line_id NOT IN('                                      -- To exclude Hold lines
                                    || ' SELECT   distinct line_id'
                                    || ' FROM     oe_order_holds_all ooh'
                                    || ' WHERE    ooh.header_id      = ool.header_id'
                                    || ' AND      ool.line_id        = ooh.line_id  '
                                    || ' AND      ooh.released_flag  = '|| '''N'''
                                    || ' AND      ooh.hold_release_id IS NULL'
                                    || ' )';

        -----------------------------------------
        -- Get the query if order number is
        -- given in the parameter
        -----------------------------------------
        IF  P_From_Order_Number  IS NOT NULL
        AND P_To_Order_Number    IS NOT NULL  THEN

            lc_order_query  :=  ' AND order_number between ' || P_From_Order_Number  || ' AND '  || P_To_Order_Number  ;
    --        GB_ORDER_PASSED := TRUE;

        END IF;

        -----------------------------------------
        -- Get the query if sch ship date is
        -- given in the parameter
        -----------------------------------------
        IF P_From_Sch_ship_confrim_date IS NOT NULL
        AND P_To_Sch_ship_confrim_date  IS NOT NULL
        THEN

            ld_from_ship_date := TO_DATE(P_From_Sch_ship_confrim_date,'MM/DD/YYYY');
            ld_to_ship_date   := TO_DATE(P_to_Sch_ship_confrim_date,'MM/DD/YYYY');

            IF ld_from_ship_date > ld_to_ship_date THEN

                x_return_mesg   := 'The Input Parameter From Sch Ship Date ' || ld_from_ship_date
                                    || ' is Greater than To Sch Ship Date '|| ld_to_ship_date ;
                RAISE error_exception;

            ELSE

                lc_ship_date_query :=  ' AND  TRUNC(ool.schedule_ship_date) BETWEEN  NVL('
                                   ||''''||ld_from_ship_date||''''||',TRUNC(ool.schedule_ship_date)) AND NVL('
                                   ||''''||ld_to_ship_date||''''||',TRUNC(ool.schedule_ship_date)) ';

    --            GB_SSD_PASSED := TRUE;
            END IF;
        END IF;


        -----------------------------------------
        -- Get the query if sch ship date is
        -- given in the parameter
        -----------------------------------------
        IF P_From_Sch_ship_confrim_date IS NOT NULL
        AND P_To_Sch_ship_confrim_date  IS NULL
        THEN

            ld_from_ship_date := TO_DATE(P_From_Sch_ship_confrim_date,'MM/DD/YYYY');
            ld_to_ship_date   := trunc(SYSDATE);


            lc_ship_date_query :=  ' AND  TRUNC(ool.schedule_ship_date) BETWEEN  NVL('
                                   ||''''||ld_from_ship_date||''''||',TRUNC(ool.schedule_ship_date)) AND NVL('
                                   ||''''||ld_to_ship_date||''''||',TRUNC(ool.schedule_ship_date)) ';

    --        GB_SSD_PASSED := TRUE;
        END IF;


        -----------------------------------------
        -- Get the query if cust account number is
        -- given in the parameter
        -----------------------------------------
        IF  P_From_bill_to_customer IS NOT NULL
        AND P_to_bill_to_customer   IS NOT NULL
        THEN

            BEGIN

                SELECT MIN(cust_account_id) ,
                       MAX(cust_account_id)
                INTO   ln_from_cust_account_id,
                       ln_to_cust_account_id
                FROM   hz_cust_accounts_all
                WHERE  account_number BETWEEN to_number (P_From_bill_to_customer) AND to_number (P_to_bill_to_customer);

            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    x_return_mesg   := 'The Input Parameter From Bill To Account number  ' || P_From_bill_to_customer
                                        || ' and ' || ' To Bill to Account number ' || P_to_bill_to_customer || 'is not valid';
                    RAISE error_exception;
                    FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);

                WHEN OTHERS THEN
                    x_return_mesg   := 'The procedure import_main_prc Failed  ' || SQLERRM;
                    x_return_sts    := GC_API_ERROR;
                    FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
            END;

            IF ln_from_cust_account_id IS NOT NULL
            AND ln_to_cust_account_id IS NOT NULL THEN

                lc_customer_query :=  ' AND ooh.sold_to_org_id between ' || ln_from_cust_account_id || ' AND '  || ln_to_cust_account_id ;
    --            GB_CUST_ACCT_CN_PASSED  := TRUE;

            END IF;

        END IF;

        lc_sort_option := ' Order By Order_number ';

        -- concatenate all the dynamic sql based on input parameters
        lc_final_query := lc_query  || lc_order_query || lc_ship_date_query ||lc_customer_query || lc_sort_option;

        FND_FILE.PUT_LINE(fnd_file.log,lc_customer_query);
        FND_FILE.PUT_LINE(fnd_file.log,lc_final_query);
        FND_FILE.PUT_LINE(fnd_file.log,lc_order_query);

        --------------------------------------------------------------------------
        -- Print the heading and other details in output file
        --------------------------------------------------------------------------
        log_msg :=  ('Begin import_main_prc procedure');
        log_records (gc_debug_flag,log_msg);

        FND_FILE.PUT_LINE(fnd_file.output,'**************************************************'
                                ||'*****************************');
        FND_FILE.PUT_LINE(fnd_file.output,'    Deckers : Ship Confirm Interface Program');
        FND_FILE.PUT_LINE(fnd_file.output,'**************************************************'
                                ||'*****************************');
        FND_FILE.PUT_LINE(fnd_file.output,' Concurrent Request Id               : ' ||GN_CONC_REQUEST_ID);
        FND_FILE.PUT_LINE(fnd_file.output,' Program Run Date                    : ' ||gd_sys_date);
        FND_FILE.PUT_LINE(fnd_file.output,' Parameters                          : ');
        FND_FILE.PUT_LINE(fnd_file.output,' From Sales Order Number             : ' || P_From_Order_Number);
        FND_FILE.PUT_LINE(fnd_file.output,' To Sales Order Number               : ' || P_To_Order_Number);
        FND_FILE.PUT_LINE(fnd_file.output,' From Sch Shipping Date              : ' || P_From_Sch_ship_confrim_date);
        FND_FILE.PUT_LINE(fnd_file.output,' To Sch Shipping Date                : ' || ld_to_ship_date);
        FND_FILE.PUT_LINE(fnd_file.output,' From Bill To customer Account Number: ' || P_From_bill_to_customer);
        FND_FILE.PUT_LINE(fnd_file.output,' To Bill To customer Account Number  : ' || P_to_bill_to_customer);
        FND_FILE.PUT_LINE(fnd_file.output,'--------------------------------------------------'
                                ||'-----------------------------');



        FND_FILE.PUT_LINE(fnd_file.log,'**************************************************'
                                ||'*****************************');
        FND_FILE.PUT_LINE(fnd_file.log,'    Deckers : Ship Confirm Interface Program');
        FND_FILE.PUT_LINE(fnd_file.log,'**************************************************'
                                ||'*****************************');
        FND_FILE.PUT_LINE(fnd_file.log,' Concurrent Request Id : ' ||GN_CONC_REQUEST_ID);
        FND_FILE.PUT_LINE(fnd_file.log,' Program Run Date      : ' ||gd_sys_date);
        FND_FILE.PUT_LINE(fnd_file.log,' Parameters            : ');
        FND_FILE.PUT_LINE(fnd_file.log,' From Sales Order Number             : ' || P_From_Order_Number);
        FND_FILE.PUT_LINE(fnd_file.log,' To Sales Order Number               : ' || P_To_Order_Number);
        FND_FILE.PUT_LINE(fnd_file.log,' From Sch Shipping Date              : ' || P_From_Sch_ship_confrim_date);
        FND_FILE.PUT_LINE(fnd_file.log,' To Sch Shipping Date                : ' || ld_to_ship_date);
        FND_FILE.PUT_LINE(fnd_file.log,' From Bill To customer Account Number: ' || P_From_bill_to_customer);
        FND_FILE.PUT_LINE(fnd_file.log,' To Bill To customer Account Number  : ' || P_to_bill_to_customer);
        FND_FILE.PUT_LINE(fnd_file.log,'--------------------------------------------------'
                                ||'-----------------------------');

        --------------------------------------------------
        -- Open the ref cursor to get data into table type
        --------------------------------------------------
        OPEN cur_order_header FOR lc_final_query;
        LOOP

          FETCH cur_order_header INTO l_qry_orderinfo_tbl(ln);
          EXIT WHEN cur_order_header%NOTFOUND;
          ln := l_qry_orderinfo_tbl.COUNT + 1;
        END LOOP;
        CLOSE cur_order_header;*/

    /*  IF l_qry_orderinfo_tbl.COUNT > 0 THEN
          FORALL j IN l_qry_orderinfo_tbl.FIRST..l_qry_orderinfo_tbl.LAST
          INSERT INTO raghu_test VALUES l_qry_orderinfo_tbl(j);
      END IF;

      COMMIT;*/



    -- insert data if cursor retreive any data for the parameter range
    /*  IF l_qry_orderinfo_tbl.count > 0 THEN

          FOR ln IN 1..l_qry_orderinfo_tbl.count
          LOOP
              -------------------------------------------------
              --  Insert data into staging table
              -------------------------------------------------

              BEGIN
                  INSERT INTO xxd_ont_ship_confirm_conv_tbl
                          (
                            record_id
                           ,order_number
                           ,header_id
                           ,org_id
                           ,ship_from_org_id
                           ,ship_to_location_id
                           ,line_id
                           ,inventory_item_id
                           ,ordered_item
                           ,sch_ship_date
                           ,bill_to_customer
                           ,cust_account_number
                           ,delivery_detail_id
                           ,released_status
                           ,original_released_status
                           ,project_id
                           -- batch_id
                           -- group_id
                           -- program_request_id
                           ,request_id
                           ,created_by
                           ,created_date
                           ,last_updated_by
                           ,last_updated_date
                           ,status
                           ,error_message
                          )

                  VALUES  (
                            XXD_ONT_SHIP_CONFIRM_CONV_SEQ.nextval                    -- record_id
                           ,l_qry_orderinfo_tbl(ln).order_number              -- order_number
                           ,l_qry_orderinfo_tbl(ln).header_id                 -- header_id
                           ,l_qry_orderinfo_tbl(ln).org_id                    -- org_id
                           ,l_qry_orderinfo_tbl(ln).ship_from_org_id          -- ship_from_org_id
                           ,l_qry_orderinfo_tbl(ln).ship_to_location_id       -- ship_to_location_id
                           ,l_qry_orderinfo_tbl(ln).line_id                   -- line_id
                           ,l_qry_orderinfo_tbl(ln).inventory_item_id         -- inventory_item_id
                           ,l_qry_orderinfo_tbl(ln).ordered_item              -- ordered_item
                           ,l_qry_orderinfo_tbl(ln).schedule_ship_date        -- sch_ship_date
                           ,l_qry_orderinfo_tbl(ln).sold_to_org_id            -- bill_to_customer
                           ,l_qry_orderinfo_tbl(ln).cust_account_number       -- cust_account_number
                           ,l_qry_orderinfo_tbl(ln).delivery_detail_id        -- delivery_detail_id
                           ,l_qry_orderinfo_tbl(ln).released_status           -- released_status
                           ,l_qry_orderinfo_tbl(ln).released_status           -- original_released_status
                           ,l_qry_orderinfo_tbl(ln).project_id                -- project_id
                            -- batch_id
                            -- program_request_id
                           ,GN_CONC_REQUEST_ID                                -- request_id
                           ,GN_USER_ID                                        -- created_by
                           ,gd_sys_date                                        -- created_date
                           ,GN_USER_ID                                        -- last_updated_by
                           ,gd_sys_date                                        -- last_updated_date
                           ,GC_NEW                                            -- status
                           ,NULL                                              -- error_message
                          );
              EXCEPTION
                  WHEN OTHERS THEN
                      X_Return_Mesg  :=   'While inserting data into staging table ' || SQLERRM;
                      x_return_sts   :=    GC_API_ERROR ;
                      FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
              END;
          END LOOP;
          COMMIT;


          -------------------------------------------------
          --  Call procedure to validate data
          -------------------------------------------------
          IF x_return_sts = GC_API_SUCCESS THEN
              validate_record_prc(
                           X_Return_Mesg    => X_Return_Mesg
                          ,x_return_sts     => x_return_sts
                          );
          END IF;
          -------------------------------------------------
          --  Call procedure to process data
          -------------------------------------------------
          IF x_return_sts = GC_API_SUCCESS THEN
              process_record_prc(
                           X_Return_Mesg    => X_Return_Mesg
                          ,x_return_sts     => x_return_sts
                          );
          END IF;*/

    -------------------------------------------------
    --  Call procedure to print error details
    -------------------------------------------------
    --IF x_return_sts = GC_API_SUCCESS THEN
    --            Print_output_Report(
    --            p_request_id     => GN_CONC_REQUEST_ID,
    --            x_return_mesg    => X_Return_Mesg,
    --            x_return_sts     => x_return_sts
    --           );

    -- END IF;
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
    /*  ELSE

          log_records (gc_debug_flag, '************ No Records available to process Ship confirm program for the Request Id: '||GN_CONC_REQUEST_ID
                              || ' *************');
          x_retcode := 1;

      END IF; -- IF l_qry_orderinfo_tbl.count > 0 THEN

      ----------------------------------------------------------------------
      -- print statistics of the records in output of the concurrent program
      ----------------------------------------------------------------------
      FND_FILE.PUT_LINE (FND_FILE.output,CHR(10));
      FND_FILE.PUT_LINE(fnd_file.output,'**************************************************');
      FND_FILE.PUT_LINE(fnd_file.output,' Statistics FOR Ship Confirmation Program :-');
      FND_FILE.PUT_LINE(fnd_file.output,'**************************************************');



  EXCEPTION
      WHEN error_exception THEN
          x_return_mesg   := x_return_mesg;
          x_return_sts    := GC_API_ERROR;
          FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);

      WHEN OTHERS THEN
          x_return_mesg   := 'The procedure import_main_prc Failed  ' || SQLERRM;
          x_return_sts    := GC_API_ERROR;
          FND_FILE.PUT_LINE(fnd_file.log, 'Error Status '|| x_return_sts || ' ,Error message '|| x_return_mesg);
  END progress_order_main;*/

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
        lc_operating_unit           hr_operating_units.NAME%TYPE;
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

        l_user_name                 VARCHAR2 (30) := 'BT_O2C_INSTALL';
        l_resp_name                 VARCHAR2 (30) := 'DO_OM_MANAGER_US';
    BEGIN
        gc_debug_flag        := p_debug_flag;
        gn_conc_request_id   := p_parent_request_id;

        --g_err_tbl_type.delete;
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


        BEGIN
            SELECT NAME
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
            FND_GLOBAL.APPS_INITIALIZE (gn_user_id,
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
            RETCODE   := 2;
            ERRBUF    := ERRBUF || SQLERRM;
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
        ln_parent_request_id     NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
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
        ELSIF p_Process = gc_validate_only
        THEN
            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM xxd_so_ws_headers_conv_stg_t
             WHERE batch_number IS NULL AND RECORD_STATUS = gc_new_status;

            FOR i IN 1 .. p_no_of_process
            LOOP
                BEGIN
                    SELECT XXD_ONT_SO_HEADER_CONV_BATCH_S.NEXTVAL
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

                UPDATE xxd_so_ws_headers_conv_stg_t
                   SET batch_number = ln_hdr_batch_id (i), REQUEST_ID = ln_parent_request_id
                 WHERE     batch_number IS NULL
                       AND ROWNUM <=
                           CEIL (ln_valid_rec_cnt / p_no_of_process)
                       AND RECORD_STATUS = gc_new_status;
            END LOOP;

            COMMIT;

            FOR l IN 1 .. ln_hdr_batch_id.COUNT
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM xxd_so_ws_headers_conv_stg_t
                 WHERE     record_status = gc_new_status
                       AND batch_number = ln_hdr_batch_id (l);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXD_ONT_SALES_ORDER_WHS_CHLD',
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
                            X_ERRBUF    := X_ERRBUF || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_ONT_SALES_ORDER_CNV_CHLD error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            X_ERRBUF    := X_ERRBUF || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_ONT_SALES_ORDER_CNV_CHLD error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;
        ELSIF p_process = gc_load_only
        THEN
            ln_cntr   := 0;
            log_records (
                gc_debug_flag,
                'Fetching batch id from XXD_SO_WS_HEADERS_CONV_STG_T stage to call worker process');

            FOR I
                IN (  SELECT DISTINCT batch_number
                        FROM xxd_so_ws_headers_conv_stg_t
                       WHERE     batch_number IS NOT NULL
                             AND RECORD_STATUS = gc_validate_status
                    ORDER BY batch_number)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_number;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_SO_WS_HEADERS_CONV_STG_T');

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
                      FROM xxd_so_ws_headers_conv_stg_t
                     WHERE batch_number = ln_hdr_batch_id (i);


                    IF ln_cntr > 0
                    THEN
                        BEGIN
                            ln_request_id   :=
                                apps.fnd_request.submit_request (
                                    'XXDCONV',
                                    'XXD_ONT_SALES_ORDER_WHS_CHLD',
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
                                X_ERRBUF    := X_ERRBUF || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_ONT_SALES_ORDER_CNV_CHLD error'
                                    || SQLERRM);
                            WHEN OTHERS
                            THEN
                                x_retcode   := 2;
                                X_ERRBUF    := X_ERRBUF || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_ONT_SALES_ORDER_CNV_CHLD error'
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;
            END IF;
        END IF;

        log_records (
            gc_debug_flag,
            'Calling XXD_ONT_SALES_ORDER_CNV_CHLD in batch ' || l_req_id.COUNT);
        log_records (
            gc_debug_flag,
            'Calling WAIT FOR REQUEST XXD_ONT_SALES_ORDER_CNV_CHLD to complete');

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
END XXD_ONT_SO_CONV_WS_PKG;
/
