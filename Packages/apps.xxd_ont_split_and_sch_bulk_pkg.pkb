--
-- XXD_ONT_SPLIT_AND_SCH_BULK_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:07 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_SPLIT_AND_SCH_BULK_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_SPLIT_AND_SCH_BULK_PKG
    -- Design       : This package will be called by Deckers Automated Split and Schedule Bulk Orders program.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name               Ver    Description
    -- ----------      --------------    -----  ------------------
    -- 25-Jul-2022     Jayarajan A K      1.0    Initial Version (CCR0010085)
    -- 25-AUG-2022     Jayarajan A K      1.1    Modified get_atp_val_prc to return correct ATP available date from API
    -- 26-AUG-2022     Jayarajan A K      1.2    Added sorting in output and corrected scheduled No ATP message
    -- 01-SEP-2022     Jayarajan A K      1.3    Modified to ensure SSD is not Truncated
    -- #########################################################################################################################
    gn_request_id   NUMBER := fnd_global.conc_request_id;
    gn_user_id      NUMBER := NVL (fnd_global.user_id, -1);

    --  insert_message procedure
    PROCEDURE insrt_msg (pv_message_type   IN VARCHAR2,
                         pv_message        IN VARCHAR2,
                         pv_debug          IN VARCHAR2 := 'N')
    AS
    BEGIN
        IF UPPER (pv_message_type) IN ('LOG', 'BOTH') AND pv_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, pv_message);
        END IF;

        IF UPPER (pv_message_type) IN ('OUTPUT', 'BOTH')
        THEN
            fnd_file.put_line (fnd_file.OUTPUT, pv_message);
        END IF;

        IF UPPER (pv_message_type) = 'DATABASE'
        THEN
            DBMS_OUTPUT.put_line (pv_message);
        END IF;
    END insrt_msg;

    PROCEDURE generate_output (p_debug IN VARCHAR2:= 'N')
    AS
        lv_line             VARCHAR2 (32767) := NULL;
        lv_file_delimiter   VARCHAR2 (1) := CHR (9);
        ln_count            NUMBER := 0;

        CURSOR output_cur IS
              SELECT org_id,
                     (SELECT name
                        FROM hr_operating_units
                       WHERE organization_id = stg.org_id) op_unit,
                     ship_from_org_id,
                     (SELECT organization_code
                        FROM mtl_parameters
                       WHERE organization_id = stg.ship_from_org_id) ship_from,
                     brand,
                     hdr_id,
                     order_number,
                     order_type_id,
                     (SELECT name
                        FROM oe_transaction_types_tl
                       WHERE     transaction_type_id = stg.order_type_id
                             AND language = USERENV ('LANG')) order_type,
                     sold_to_org_id,
                     (SELECT account_number
                        FROM hz_cust_accounts
                       WHERE cust_account_id = stg.sold_to_org_id) account_num,
                     lne_id,
                     line_number,
                     inventory_item_id,
                     (SELECT segment1
                        FROM mtl_system_items_b
                       WHERE     inventory_item_id = stg.inventory_item_id
                             AND organization_id = 106) sku,
                     lne_creation_date,                                 --v1.2
                     request_date,
                     schedule_ship_date,
                     new_ssd,
                     original_quantity,
                     available_quantity,
                     new_quantity,
                     split_quantity,
                     process_mode,
                     status,
                     MESSAGE
                FROM xxdo.xxd_ont_split_sch_blk_stg_t stg
               WHERE stg.request_id = gn_request_id
            --Start changes v1.2
            ORDER BY sku, lne_creation_date--End changes v1.2
                                           ;
    BEGIN
        insrt_msg ('LOG', 'Inside generate_output Procedure', 'Y');

        lv_line   :=
               'Operating Unit'
            || lv_file_delimiter
            || 'Ship From Org'
            || lv_file_delimiter
            || 'Brand'
            || lv_file_delimiter
            || 'Order Number'
            || lv_file_delimiter
            || 'Order Type'
            || lv_file_delimiter
            || 'Account Number'
            || lv_file_delimiter
            || 'SO Line#'
            || lv_file_delimiter
            || 'SKU'
            || lv_file_delimiter                                        --v1.2
            || 'Line Creation Date'                                     --v1.2
            || lv_file_delimiter
            || 'Request Date'
            || lv_file_delimiter
            || 'Schedule Ship Date'
            || lv_file_delimiter
            || 'New SSD'
            || lv_file_delimiter
            || 'Original Qty'
            || lv_file_delimiter
            || 'Available Qty'
            || lv_file_delimiter
            || 'New Qty'
            || lv_file_delimiter
            || 'Split Qty'
            || lv_file_delimiter
            || 'Processing mode'
            || lv_file_delimiter
            || 'Status'
            || lv_file_delimiter
            || 'Error Message';

        insrt_msg ('OUTPUT', lv_line);

        FOR output_rec IN output_cur
        LOOP
            ln_count   := ln_count + 1;

            lv_line    :=
                   output_rec.op_unit
                || lv_file_delimiter
                || output_rec.ship_from
                || lv_file_delimiter
                || output_rec.brand
                || lv_file_delimiter
                || output_rec.order_number
                || lv_file_delimiter
                || output_rec.order_type
                || lv_file_delimiter
                || output_rec.account_num
                || lv_file_delimiter
                || output_rec.line_number
                || lv_file_delimiter
                || output_rec.sku
                || lv_file_delimiter                                    --v1.2
                || output_rec.lne_creation_date                         --v1.2
                || lv_file_delimiter
                || output_rec.request_date
                || lv_file_delimiter
                || output_rec.schedule_ship_date
                || lv_file_delimiter
                || output_rec.new_ssd
                || lv_file_delimiter
                || output_rec.original_quantity
                || lv_file_delimiter
                || output_rec.available_quantity
                || lv_file_delimiter
                || output_rec.new_quantity
                || lv_file_delimiter
                || output_rec.split_quantity
                || lv_file_delimiter
                || output_rec.process_mode
                || lv_file_delimiter
                || output_rec.status
                || lv_file_delimiter
                || output_rec.MESSAGE;

            insrt_msg ('OUTPUT', lv_line);
        END LOOP;

        insrt_msg ('LOG', 'ln_count: ' || ln_count, p_debug);
        insrt_msg ('LOG', 'Completed generate_output Procedure', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            insrt_msg ('LOG',
                       'Error while generating output: ' || SQLERRM,
                       'Y');
    END generate_output;

    --split_sch_blk_main procedure
    PROCEDURE split_sch_blk_main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_ware_hse_id IN NUMBER, p_brand IN VARCHAR2, p_channel IN VARCHAR2, p_sch_status IN VARCHAR2:= 'BOTH', p_req_date_from IN VARCHAR2, p_req_date_to IN VARCHAR2
                                  , p_debug IN VARCHAR2:= 'N')
    IS
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_header_rec_x                 oe_order_pub.header_rec_type;
        l_line_tbl_x                   oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
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

        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        ln_bulk_split_success          NUMBER := 0;
        ln_bulk_split_err              NUMBER := 0;
        ln_atp_current_available_qty   NUMBER := 0;
        ln_new_line_split_qty          NUMBER := 0;
        l_api_ver_num                  NUMBER := 1.0;
        l_init_msg_list                VARCHAR2 (10) := fnd_api.g_true;
        l_return_values                VARCHAR2 (10) := fnd_api.g_true;
        l_action_commit                VARCHAR2 (10) := fnd_api.g_false;
        l_msg_index_out                NUMBER (10);
        l_row_num                      NUMBER := 0;
        l_row_num_err                  NUMBER := 0;
        l_tot_num                      NUMBER := 0;
        l_tot_num_err                  NUMBER := 0;
        l_message_data                 VARCHAR2 (2000);
        ln_resp_id                     NUMBER := 0;
        ln_resp_appl_id                NUMBER := 0;
        ln_conc_request_id             NUMBER
                                           := apps.fnd_global.conc_request_id;
        l_unsched_row_num              NUMBER := 0;
        l_unsched_row_num_err          NUMBER := 0;
        x_atp_qty                      NUMBER;
        v_msg_data                     VARCHAR2 (2000);
        v_err_code                     VARCHAR2 (2000);
        x_req_date_qty                 NUMBER;
        x_available_date               DATE;
        ld_line_lad_dt                 DATE;
        lv_exception                   EXCEPTION;
        lv_no_atp_msg                  VARCHAR2 (60);                   --v1.2

        CURSOR bulk_org_cur IS
            SELECT DISTINCT org_id
              FROM xxdo.xxd_ont_split_sch_blk_stg_t
             WHERE request_id = gn_request_id AND status IS NULL;

        CURSOR bulk_stg_cur (pn_org_id NUMBER)
        IS
              SELECT stg.*,
                     CASE
                         WHEN schedule_ship_date IS NULL THEN 1
                         ELSE 2
                     END sort_ordr
                FROM xxdo.xxd_ont_split_sch_blk_stg_t stg
               WHERE     request_id = gn_request_id
                     AND org_id = pn_org_id
                     AND status IS NULL
            ORDER BY sort_ordr, stg.lne_creation_date, stg.request_date;

        CURSOR bulk_line_cur IS
            SELECT ott.name,
                   ooha.org_id,
                   oola.ship_from_org_id,
                   ooha.attribute5
                       brand,
                   ooha.order_type_id,
                   oola.ordered_item
                       sku,
                   oola.inventory_item_id,
                   oola.demand_class_code,
                   oola.order_quantity_uom,
                   oola.header_id,
                   oola.line_id,
                   oola.schedule_ship_date,
                   oola.request_date,
                   oola.creation_date,
                   oola.order_source_id,
                   oola.ordered_quantity,
                   oola.latest_acceptable_date,
                   ooha.order_number,
                   ooha.sold_to_org_id
                       cust_account_id,
                   oola.line_number || '.' || oola.shipment_number
                       line_number,
                   ooha.sales_channel_code,
                   CASE
                       WHEN schedule_ship_date IS NULL THEN 1
                       ELSE 2
                   END
                       sort_ordr
              FROM oe_order_lines_all oola, oe_order_headers_all ooha, oe_transaction_types_tl ott
             WHERE     ott.name LIKE 'Bulk%'
                   AND ott.language = USERENV ('LANG')
                   AND ooha.order_type_id = ott.transaction_type_id
                   AND ooha.org_id = NVL (p_org_id, ooha.org_id) -- Operating Unit
                   AND ooha.attribute5 = NVL (p_brand, ooha.attribute5)
                   AND ooha.sales_channel_code =
                       NVL (p_channel, ooha.sales_channel_code)
                   AND ooha.open_flag = 'Y'
                   AND ooha.header_id = oola.header_id
                   AND oola.open_flag = 'Y'
                   --AND oola.flow_status_code NOT IN ('CANCELLED', 'CLOSED')
                   AND oola.ordered_quantity > 0
                   -- SSD
                   AND ((p_sch_status = 'UNSCHEDULED' AND oola.schedule_ship_date IS NULL) OR (p_sch_status = 'SCHEDULED' AND oola.schedule_ship_date IS NOT NULL) OR (p_sch_status = 'BOTH' AND 1 = 1))
                   AND oola.ship_from_org_id =
                       NVL (p_ware_hse_id, oola.ship_from_org_id)
                   -- Request Date From
                   AND ((p_req_date_from IS NOT NULL AND oola.request_date >= fnd_date.canonical_to_date (p_req_date_from)) OR (p_req_date_from IS NULL AND 1 = 1))
                   -- Request Date To
                   AND ((p_req_date_to IS NOT NULL AND oola.request_date <= fnd_date.canonical_to_date (p_req_date_to)) OR (p_req_date_to IS NULL AND 1 = 1))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_reservations mr
                             WHERE mr.demand_source_line_id = oola.line_id);

        TYPE bulk_line_tb IS TABLE OF bulk_line_cur%ROWTYPE;

        vt_bulk_line                   bulk_line_tb;
        v_bulk_limit                   NUMBER := 10000;
    BEGIN
        insrt_msg (
            'LOG',
               'Inside split_sch_blk_main: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'Y');
        insrt_msg ('LOG', 'p_debug: ' || p_debug, 'Y');
        insrt_msg ('LOG', 'p_org_id: ' || p_org_id, p_debug);
        insrt_msg ('LOG', 'p_ware_hse_id: ' || p_ware_hse_id, p_debug);
        insrt_msg ('LOG', 'p_brand: ' || p_brand, p_debug);
        insrt_msg ('LOG', 'p_channel: ' || p_channel, p_debug);
        insrt_msg ('LOG', 'p_sch_status: ' || p_sch_status, p_debug);
        insrt_msg ('LOG', 'p_req_date_from: ' || p_req_date_from, p_debug);
        insrt_msg ('LOG', 'p_req_date_to: ' || p_req_date_to, p_debug);

        apps.fnd_profile.put ('MRP_ATP_CALC_SD', 'N');

        ---CURSOR
        OPEN bulk_line_cur;

        LOOP
            FETCH bulk_line_cur
                BULK COLLECT INTO vt_bulk_line
                LIMIT v_bulk_limit;

            BEGIN
                FORALL i IN 1 .. vt_bulk_line.COUNT
                    INSERT INTO xxdo.xxd_ont_split_sch_blk_stg_t (
                                    org_id,
                                    ship_from_org_id,
                                    hdr_id,
                                    lne_id,
                                    request_id,
                                    brand,
                                    order_type_id,
                                    sold_to_org_id,
                                    sales_channel_code,
                                    sku,
                                    inventory_item_id,
                                    demand_class_code,
                                    order_quantity_uom,
                                    request_date,
                                    lne_creation_date,
                                    latest_acceptable_date,
                                    original_quantity,
                                    -- available_quantity,
                                    schedule_ship_date,
                                    process_mode,
                                    status,
                                    MESSAGE,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by,
                                    order_number,
                                    line_number)
                             VALUES (vt_bulk_line (i).org_id,
                                     vt_bulk_line (i).ship_from_org_id,
                                     vt_bulk_line (i).header_id,
                                     vt_bulk_line (i).line_id,
                                     gn_request_id,
                                     vt_bulk_line (i).brand,
                                     vt_bulk_line (i).order_type_id,
                                     vt_bulk_line (i).cust_account_id, --sold_to_org_id
                                     vt_bulk_line (i).sales_channel_code,
                                     vt_bulk_line (i).sku,
                                     vt_bulk_line (i).inventory_item_id,
                                     vt_bulk_line (i).demand_class_code,
                                     vt_bulk_line (i).order_quantity_uom,
                                     vt_bulk_line (i).request_date,
                                     vt_bulk_line (i).creation_date, --lne_creation_date
                                     vt_bulk_line (i).latest_acceptable_date,
                                     vt_bulk_line (i).ordered_quantity,
                                     --ln_atp_current_available_qty, --available_quantity
                                     vt_bulk_line (i).schedule_ship_date,
                                     'INSERT',                  --process_mode
                                     NULL,                            --status
                                     NULL,                           --message
                                     SYSDATE,                  --creation_date
                                     gn_user_id,                  --created_by
                                     SYSDATE,               --last_update_date
                                     gn_user_id,             --last_updated_by
                                     vt_bulk_line (i).order_number,
                                     vt_bulk_line (i).line_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    insrt_msg ('LOG',
                               'Error during insertion: ' || SQLERRM,
                               'Y');
            END;

            COMMIT;
            EXIT WHEN bulk_line_cur%NOTFOUND;
        END LOOP;

        FOR bulk_org_rec IN bulk_org_cur
        LOOP
            ln_resp_id        := NULL;
            ln_resp_appl_id   := NULL;

            BEGIN
                --Getting the responsibility and application to initialize and set the context
                --Making sure that the initialization is set for proper OM responsibility
                SELECT frv.responsibility_id, frv.application_id
                  INTO ln_resp_id, ln_resp_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                       apps.hr_organization_units hou
                 WHERE     1 = 1
                       AND hou.organization_id = bulk_org_rec.org_id
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
                    insrt_msg (
                        'LOG',
                        'Error getting the responsibility ID : ' || SQLERRM,
                        'Y');
                    RAISE lv_exception;
            END;

            fnd_global.apps_initialize (user_id        => gn_user_id,
                                        resp_id        => ln_resp_id,
                                        resp_appl_id   => ln_resp_appl_id);
            mo_global.init ('ONT');
            mo_global.set_policy_context ('S', bulk_org_rec.org_id);

            FOR bulk_line_rec IN bulk_stg_cur (bulk_org_rec.org_id)
            LOOP
                l_return_status                := NULL;
                l_msg_data                     := NULL;
                l_message_data                 := NULL;

                ln_atp_current_available_qty   := 0;
                ln_new_line_split_qty          := 0;
                l_tot_num                      := l_tot_num + 1;

                IF bulk_line_rec.schedule_ship_date IS NULL
                THEN
                    ld_line_lad_dt   := bulk_line_rec.latest_acceptable_date;
                ELSE
                    ld_line_lad_dt   := bulk_line_rec.request_date;
                END IF;

                --run procedure to get ATP for request date on order line
                --apps.XXD_EDI870_ATP_PKG.get_atp_val_prc
                get_atp_val_prc (x_atp_qty,
                                 v_msg_data,
                                 v_err_code,
                                 bulk_line_rec.inventory_item_id,
                                 bulk_line_rec.ship_from_org_id,
                                 bulk_line_rec.order_quantity_uom,
                                 bulk_line_rec.ship_from_org_id,
                                 bulk_line_rec.original_quantity,
                                 ld_line_lad_dt,
                                 bulk_line_rec.demand_class_code,
                                 x_req_date_qty,
                                 x_available_date);

                --Get avail qty as the largest of ATP vs requested date qty
                IF bulk_line_rec.schedule_ship_date IS NOT NULL
                THEN
                    --IF x_available_date < bulk_line_rec.schedule_ship_date THEN -- commented for v1.3
                    IF x_available_date <
                       TRUNC (bulk_line_rec.schedule_ship_date)
                    THEN                                     -- added for v1.3
                        ln_atp_current_available_qty   :=
                            GREATEST (NVL (x_atp_qty, 0),
                                      NVL (x_req_date_qty, 0));
                    END IF;

                    lv_no_atp_msg   :=
                        'No better ATP available to split/schedule the line'; --v1.2
                ELSE
                    ln_atp_current_available_qty   :=
                        GREATEST (NVL (x_atp_qty, 0),
                                  NVL (x_req_date_qty, 0));
                    lv_no_atp_msg   := 'No Available Quantity';         --v1.2
                END IF;

                --No avail qty
                IF ln_atp_current_available_qty = 0
                THEN
                    insrt_msg ('LOG', lv_no_atp_msg, p_debug);          --v1.2
                    l_tot_num_err   := l_tot_num_err + 1;

                    UPDATE xxdo.xxd_ont_split_sch_blk_stg_t
                       SET MESSAGE = lv_no_atp_msg,                     --v1.2
                                                    process_mode = 'BULK-ATP-FAIL', status = 'P',
                           available_quantity = ln_atp_current_available_qty, available_date = x_available_date, last_update_date = SYSDATE
                     WHERE     request_id = gn_request_id
                           AND lne_id = bulk_line_rec.lne_id;

                    COMMIT;
                ELSIF ln_atp_current_available_qty > 0
                THEN
                    --is there sufficient APT to scedule the line
                    IF bulk_line_rec.original_quantity <=
                       ln_atp_current_available_qty
                    THEN
                        /****************************************************************************************
            * Schedule the original line
            ****************************************************************************************/
                        l_return_status            := NULL;
                        l_msg_data                 := NULL;
                        l_message_data             := NULL;
                        oe_msg_pub.initialize;

                        l_line_tbl                 := oe_order_pub.g_miss_line_tbl;
                        l_line_tbl (1)             := oe_order_pub.g_miss_line_rec;
                        l_line_tbl (1).operation   := oe_globals.g_opr_update;
                        l_line_tbl (1).org_id      := bulk_line_rec.org_id;
                        l_line_tbl (1).header_id   := bulk_line_rec.hdr_id;
                        l_line_tbl (1).line_id     := bulk_line_rec.lne_id;

                        IF bulk_line_rec.schedule_ship_date IS NULL
                        THEN
                            l_line_tbl (1).schedule_action_code   :=
                                'SCHEDULE';
                        ELSE
                            l_line_tbl (1).schedule_action_code   :=
                                'RESCHEDULE';
                            l_line_tbl (1).schedule_ship_date   :=
                                x_available_date;
                        END IF;

                        oe_order_pub.process_order (
                            p_api_version_number     => l_api_ver_num,
                            p_init_msg_list          => l_init_msg_list,
                            p_return_values          => l_return_values,
                            p_action_commit          => l_action_commit,
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
                            l_row_num   := l_row_num + 1;
                            insrt_msg ('LOG',
                                       'Bulk Scheduling Success',
                                       p_debug);

                            UPDATE xxdo.xxd_ont_split_sch_blk_stg_t
                               SET MESSAGE = 'Bulk Scheduling Success', process_mode = 'BULK-SCH-S', status = 'S',
                                   available_quantity = ln_atp_current_available_qty, available_date = x_available_date, last_update_date = SYSDATE,
                                   sch_status = 'S', Split_status = 'N', new_ssd = l_line_tbl_x (1).schedule_ship_date
                             WHERE     request_id = gn_request_id
                                   AND lne_id = bulk_line_rec.lne_id;

                            COMMIT;
                        ELSE
                            ROLLBACK;

                            FOR i IN 1 .. l_msg_count
                            LOOP
                                oe_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => fnd_api.g_false,
                                    p_data            => l_msg_data,
                                    p_msg_index_out   => l_msg_index_out);

                                l_message_data   :=
                                    l_message_data || l_msg_data;
                            END LOOP;

                            l_row_num_err   := l_row_num_err + 1;
                            insrt_msg (
                                'LOG',
                                'Bulk Scheduling Failed:' || l_message_data,
                                p_debug);

                            UPDATE xxdo.xxd_ont_split_sch_blk_stg_t
                               SET MESSAGE = SUBSTR ('Bulk Scheduling Failed: ' || l_message_data, 1, 240), process_mode = 'BULK-SCH-F', status = 'E',
                                   available_quantity = ln_atp_current_available_qty, available_date = x_available_date, last_update_date = SYSDATE
                             WHERE     request_id = gn_request_id
                                   AND lne_id = bulk_line_rec.lne_id;

                            COMMIT;
                        END IF;
                    ELSE
                        --Get split out qty as Ordered qty - avail qty (this will be the qty on the new line)
                        ln_new_line_split_qty              :=
                              bulk_line_rec.original_quantity
                            - ln_atp_current_available_qty;

                        /****************************************************************************************
          * Order line split based on available qty
          ****************************************************************************************/
                        l_return_status                    := NULL;
                        l_msg_data                         := NULL;
                        l_message_data                     := NULL;
                        oe_msg_pub.initialize;

                        l_header_rec                       := oe_order_pub.g_miss_header_rec;
                        l_line_tbl                         := oe_order_pub.g_miss_line_tbl;
                        -- Original Line Changes
                        l_line_tbl (1)                     := oe_order_pub.g_miss_line_rec;
                        l_line_tbl (1).header_id           := bulk_line_rec.hdr_id;
                        l_line_tbl (1).org_id              := bulk_line_rec.org_id;
                        l_line_tbl (1).line_id             := bulk_line_rec.lne_id;
                        l_line_tbl (1).split_action_code   := 'SPLIT';
                        -- Pass User Id to "Split_By" instead of value "USER" to Original Line. Oracle Doc ID 2156475.1
                        l_line_tbl (1).split_by            := gn_user_id;
                        l_line_tbl (1).ordered_quantity    :=
                            ln_atp_current_available_qty;
                        l_line_tbl (1).operation           :=
                            oe_globals.g_opr_update;

                        -- Split Line
                        l_line_tbl (2)                     :=
                            oe_order_pub.g_miss_line_rec;
                        l_line_tbl (2).header_id           :=
                            bulk_line_rec.hdr_id;
                        l_line_tbl (2).org_id              :=
                            bulk_line_rec.org_id;
                        l_line_tbl (2).split_action_code   := 'SPLIT';
                        -- Pass constant value "USER" to "Split_By" to Split Line. Oracle Doc ID 2156475.1
                        l_line_tbl (2).split_by            := 'USER';
                        l_line_tbl (2).split_from_line_id   :=
                            bulk_line_rec.lne_id;
                        l_line_tbl (2).ordered_quantity    :=
                            ln_new_line_split_qty;
                        l_line_tbl (2).request_id          :=
                            ln_conc_request_id;

                        IF bulk_line_rec.schedule_ship_date IS NOT NULL
                        THEN
                            l_line_tbl (2).schedule_ship_date   :=
                                bulk_line_rec.schedule_ship_date;
                        END IF;

                        l_line_tbl (2).operation           :=
                            oe_globals.g_opr_create;

                        oe_order_pub.process_order (
                            p_api_version_number     => l_api_ver_num,
                            p_init_msg_list          => l_init_msg_list,
                            p_return_values          => l_return_values,
                            p_action_commit          => l_action_commit,
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

                        IF l_return_status <> fnd_api.g_ret_sts_success
                        THEN
                            ROLLBACK;

                            FOR i IN 1 .. l_msg_count
                            LOOP
                                oe_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => fnd_api.g_false,
                                    p_data            => l_msg_data,
                                    p_msg_index_out   => l_msg_index_out);

                                l_message_data   :=
                                    l_message_data || l_msg_data;
                            END LOOP;

                            ln_bulk_split_err   := ln_bulk_split_err + 1;
                            insrt_msg (
                                'LOG',
                                'Bulk Split Failed:' || l_message_data,
                                p_debug);

                            UPDATE xxdo.xxd_ont_split_sch_blk_stg_t
                               SET MESSAGE = SUBSTR ('Bulk Split Failed: ' || l_message_data, 1, 240), process_mode = 'BULK-SPLIT-F', status = 'E',
                                   available_quantity = ln_atp_current_available_qty, available_date = x_available_date, last_update_date = SYSDATE
                             WHERE     request_id = gn_request_id
                                   AND lne_id = bulk_line_rec.lne_id;

                            COMMIT;
                        ELSE
                            COMMIT; -- this is needed to avoid further split from scheduling API
                            /****************************************************************************************
           * Schedule the original line
           ****************************************************************************************/
                            l_return_status   := NULL;
                            l_msg_data        := NULL;
                            l_message_data    := NULL;
                            oe_msg_pub.initialize;

                            l_line_tbl        := oe_order_pub.g_miss_line_tbl;
                            l_line_tbl (1)    := oe_order_pub.g_miss_line_rec;
                            l_line_tbl (1).operation   :=
                                oe_globals.g_opr_update;
                            l_line_tbl (1).org_id   :=
                                bulk_line_rec.org_id;
                            l_line_tbl (1).header_id   :=
                                bulk_line_rec.hdr_id;
                            l_line_tbl (1).line_id   :=
                                bulk_line_rec.lne_id;
                            l_line_tbl (1).schedule_action_code   :=
                                'SCHEDULE';

                            IF bulk_line_rec.schedule_ship_date IS NOT NULL
                            THEN
                                l_line_tbl (1).schedule_action_code   :=
                                    'RESCHEDULE';             --added for v1.3
                                l_line_tbl (1).schedule_ship_date   :=
                                    x_available_date;
                            END IF;

                            oe_order_pub.process_order (
                                p_api_version_number   => l_api_ver_num,
                                p_init_msg_list        => l_init_msg_list,
                                p_return_values        => l_return_values,
                                p_action_commit        => l_action_commit,
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

                            IF l_return_status = fnd_api.g_ret_sts_success
                            THEN
                                ln_bulk_split_success   :=
                                    ln_bulk_split_success + 1;
                                insrt_msg (
                                    'LOG',
                                       'Bulk Split Success with split qty: '
                                    || ln_new_line_split_qty,
                                    p_debug);

                                UPDATE xxdo.xxd_ont_split_sch_blk_stg_t
                                   SET MESSAGE = 'Bulk Split Success', process_mode = 'BULK-SPLIT-S', status = 'S',
                                       split_status = 'S', sch_status = 'S', available_quantity = ln_atp_current_available_qty,
                                       available_date = x_available_date, new_quantity = ln_atp_current_available_qty, split_quantity = ln_new_line_split_qty,
                                       new_ssd = l_line_tbl_x (1).schedule_ship_date, last_update_date = SYSDATE
                                 WHERE     request_id = gn_request_id
                                       AND lne_id = bulk_line_rec.lne_id;

                                COMMIT;
                            ELSE
                                ROLLBACK;

                                FOR i IN 1 .. l_msg_count
                                LOOP
                                    oe_msg_pub.get (
                                        p_msg_index       => i,
                                        p_encoded         => fnd_api.g_false,
                                        p_data            => l_msg_data,
                                        p_msg_index_out   => l_msg_index_out);

                                    l_message_data   :=
                                        l_message_data || l_msg_data;
                                END LOOP;

                                ln_bulk_split_err   := ln_bulk_split_err + 1;
                                insrt_msg (
                                    'LOG',
                                       'Bulk Split Schedule Failed:'
                                    || l_message_data,
                                    p_debug);

                                UPDATE xxdo.xxd_ont_split_sch_blk_stg_t
                                   SET MESSAGE = SUBSTR ('Bulk Split Schedule Failed: ' || l_message_data, 1, 240), process_mode = 'BULK-SPLIT-SCH-F', status = 'E',
                                       available_quantity = ln_atp_current_available_qty, available_date = x_available_date, last_update_date = SYSDATE
                                 WHERE     request_id = gn_request_id
                                       AND lne_id = bulk_line_rec.lne_id;

                                COMMIT;
                            END IF;
                        END IF;
                    END IF;                                       -- Split API
                END IF;                                             -- ATP API

                COMMIT;
            END LOOP;                                      --END OF STG CURSOR
        END LOOP;                                          --END OF ORG CURSOR

        UPDATE xxdo.xxd_ont_split_sch_blk_stg_t
           SET status = 'P', process_mode = 'COMPLETE', MESSAGE = 'Not eligible or not applicable for processing',
               last_update_date = SYSDATE
         WHERE request_id = gn_request_id AND status IS NULL;

        COMMIT;
        insrt_msg ('LOG', 'Total Records Processed: ' || l_tot_num, 'Y');
        insrt_msg ('LOG', 'Records with no ATP: ' || l_tot_num_err, 'Y');
        insrt_msg ('LOG',
                   'Records successfully got Rescheduled: ' || l_row_num,
                   'Y');
        insrt_msg ('LOG',
                   'Records errored while Rescheduling: ' || l_row_num_err,
                   'Y');
        insrt_msg (
            'LOG',
               'Records successfully split and scheduled: '
            || ln_bulk_split_success,
            'Y');
        insrt_msg (
            'LOG',
               'Records errored while split and scheduling: '
            || ln_bulk_split_err,
            'Y');

        --Call generate_output procedure
        generate_output (p_debug);

        -- purging at the end;
        DELETE FROM xxdo.xxd_ont_split_sch_blk_stg_t
              WHERE creation_date < SYSDATE - 90;

        COMMIT;
    EXCEPTION
        WHEN lv_exception
        THEN
            insrt_msg (
                'LOG',
                'Unexpected Error while fetching responsibility: ' || SQLERRM,
                'Y');
        WHEN OTHERS
        THEN
            insrt_msg ('LOG',
                       'Unexpected Error in split_sch_blk_main: ' || SQLERRM,
                       'Y');
    END split_sch_blk_main;

    --get_atp_val_prc proecdure
    PROCEDURE get_atp_val_prc (x_atp_qty OUT NUMBER, p_msg_data OUT VARCHAR2, p_err_code OUT VARCHAR2, p_inventory_item_id IN NUMBER, p_org_id IN NUMBER, p_primary_uom_code IN VARCHAR2, p_source_org_id IN NUMBER, p_qty_ordered IN NUMBER, p_req_ship_date IN DATE
                               , p_demand_class_code IN VARCHAR2, x_req_date_qty OUT NUMBER, x_available_date OUT DATE)
    IS
        l_atp_rec             mrp_atp_pub.atp_rec_typ;
        p_atp_rec             mrp_atp_pub.atp_rec_typ;
        x_atp_rec             mrp_atp_pub.atp_rec_typ;
        x_atp_supply_demand   mrp_atp_pub.atp_supply_demand_typ;
        x_atp_period          mrp_atp_pub.atp_period_typ;
        x_atp_details         mrp_atp_pub.atp_details_typ;
        x_return_status       VARCHAR2 (2000);
        x_msg_data            VARCHAR2 (500);
        x_msg_count           NUMBER;
        l_session_id          NUMBER;
        l_error_message       VARCHAR2 (250);
        x_error_message       VARCHAR2 (80);
        i                     NUMBER;
        v_file_dir            VARCHAR2 (80);
        v_inventory_item_id   NUMBER;
        v_organization_id     NUMBER;
        l_qty_uom             VARCHAR2 (10);
        l_req_date            DATE;
        l_demand_class        VARCHAR2 (80);
        v_api_return_status   VARCHAR2 (1);
        v_qty_oh              NUMBER;
        v_qty_res_oh          NUMBER;
        v_qty_res             NUMBER;
        v_qty_sug             NUMBER;
        v_qty_att             NUMBER;
        v_qty_atr             NUMBER;
        v_msg_count           NUMBER;
        v_msg_data            VARCHAR2 (1000);
        ln_cnt                NUMBER := 0;
    BEGIN
        -- ====================================================
        -- IF using 11.5.9 and above, Use MSC_ATP_GLOBAL.Extend_ATP
        -- API to extend record structure as per standards. This
        -- will ensure future compatibility.
        msc_atp_global.extend_atp (l_atp_rec, x_return_status, 1);
        -- ====================================================
        ln_cnt                                        := ln_cnt + 1;

        SELECT oe_order_sch_util.get_session_id INTO l_session_id FROM DUAL;

        l_atp_rec.inventory_item_id (ln_cnt)          := p_inventory_item_id;
        l_atp_rec.inventory_item_name (ln_cnt)        := NULL;
        l_atp_rec.quantity_ordered (ln_cnt)           := p_qty_ordered;
        l_atp_rec.quantity_uom (ln_cnt)               := p_primary_uom_code;
        l_atp_rec.requested_ship_date (ln_cnt)        := p_req_ship_date;
        l_atp_rec.action (ln_cnt)                     := 100; --100ATP Inquiry   110Scheduling   120Rescheduling
        l_atp_rec.instance_id (ln_cnt)                := NULL;
        l_atp_rec.source_organization_id (ln_cnt)     := p_source_org_id;
        l_atp_rec.demand_class (ln_cnt)               := p_demand_class_code;
        l_atp_rec.oe_flag (ln_cnt)                    := 'N';
        l_atp_rec.insert_flag (ln_cnt)                := 1;
        --If this field is set to 1 then ATP calculates supply/demand and period details
        l_atp_rec.attribute_04 (ln_cnt)               := 1;
        l_atp_rec.customer_id (ln_cnt)                := NULL;
        l_atp_rec.customer_site_id (ln_cnt)           := NULL;
        l_atp_rec.calling_module (ln_cnt)             := 660; --'724': planning server; '660': OM; '708': configurator; '-1': backlog scheduling workbench
        l_atp_rec.row_id (ln_cnt)                     := NULL;
        l_atp_rec.source_organization_code (ln_cnt)   := NULL;
        l_atp_rec.organization_id (ln_cnt)            := NULL;
        l_atp_rec.order_number (ln_cnt)               := NULL;
        l_atp_rec.line_number (ln_cnt)                := NULL;
        l_atp_rec.override_flag (ln_cnt)              := NULL;

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

        IF (x_return_status = 'S')
        THEN
            FOR i IN 1 .. x_atp_rec.inventory_item_id.COUNT
            LOOP
                x_error_message   := '';
                x_atp_qty         := x_atp_rec.available_quantity (i);
                x_req_date_qty    := x_atp_rec.requested_date_quantity (i);
                --Start changes v1.1
                --x_available_date :=  x_atp_rec.Ship_Date(i);
                x_available_date   :=
                    x_atp_rec.first_valid_ship_arrival_date (i);

                --End changes v1.1

                IF (x_atp_rec.ERROR_CODE (i) <> 0)
                THEN
                    SELECT meaning
                      INTO x_error_message
                      FROM mfg_lookups
                     WHERE     lookup_type = 'MTL_DEMAND_INTERFACE_ERRORS'
                           AND lookup_code = x_atp_rec.ERROR_CODE (i);

                    x_atp_qty    := 0;
                    p_err_code   := 'E';
                    p_msg_data   := x_error_message;
                END IF;
            END LOOP;
        ELSE
            p_msg_data   := NVL (x_msg_data, 'Error in call_atp API');
            p_err_code   := 'E';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            raise_application_error (
                -20001,
                   'An error was encountered in procedure get_atp_val_prc: '
                || SQLCODE
                || ' -ERROR- '
                || SQLERRM);
    END get_atp_val_prc;
END xxd_ont_split_and_sch_bulk_pkg;
/
