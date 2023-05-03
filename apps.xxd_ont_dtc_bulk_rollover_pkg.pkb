--
-- XXD_ONT_DTC_BULK_ROLLOVER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_DTC_BULK_ROLLOVER_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_DTC_BULK_ROLLOVER_PKG
    * Design       : This plsql is for DTC rollover order creation
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 01-Jan-2021  1.0        Gaurav Joshi            Initial Version
    -- 14-MAR-2023  1.1        Srinath Siricilla       CCR0010520 - PDCTOM-653 - SOMT Table needs record_id Column for GG replication
    ******************************************************************************************/
    --
    -- Set values for Global Variables
    -- ======================================================================================
    -- Modifed to init G variable from input params

    gn_org_id              NUMBER;
    gn_user_id             NUMBER;
    gn_login_id            NUMBER;
    gn_application_id      NUMBER;
    gn_responsibility_id   NUMBER;
    gn_request_id          NUMBER := fnd_global.conc_request_id;
    gc_debug_enable        VARCHAR2 (1);


    -- ======================================================================================
    -- This procedure prints the Debug Messages in Log Or File
    -- ======================================================================================

    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        -- Write Conc Log
        IF gn_request_id <> -1
        THEN
            fnd_file.put_line (fnd_file.LOG, p_msg);
        ELSE
            NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END debug_msg;

    -- ======================================================================================
    -- This procedure will be used to initialize
    -- ======================================================================================

    PROCEDURE init
    AS
    BEGIN
        mo_global.init ('ONT');
        oe_msg_pub.delete_msg;
        oe_msg_pub.initialize;
        mo_global.set_policy_context ('S', gn_org_id);
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_responsibility_id,
                                    resp_appl_id   => gn_application_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in INIT = ' || SQLERRM);
    END init;

    PROCEDURE cancel_lines (p_group_id IN NUMBER)
    AS
        ln_request_id   NUMBER;
        lv_def_org_id   NUMBER;
        v_dummy         VARCHAR2 (100);
        x_dummy         VARCHAR2 (250);
        v_dphase        VARCHAR2 (100);
        v_dstatus       VARCHAR2 (100);

        CURSOR c_get_headers IS
            (SELECT DISTINCT oha.org_id, oha.header_id, oha.order_source_id,
                             orig_sys_document_ref, sold_to_org_id
               FROM xxd_ont_order_modify_details_t a, xxd_ont_dtc_rollover_run_t b, oe_order_headers_all oha
              WHERE     a.GROUP_ID = p_group_id
                    AND a.GROUP_ID = b.GROUP_ID
                    AND oha.header_id = a.source_header_id
                    AND a.status = 'N');

        CURSOR c_get_lines (p_in_source_header_id NUMBER)
        IS
            SELECT ola.*
              FROM xxd_ont_order_modify_details_t a, xxd_ont_dtc_rollover_run_t b, oe_order_lines_all ola
             WHERE     a.GROUP_ID = p_group_id
                   AND a.GROUP_ID = b.GROUP_ID
                   AND source_header_id = p_in_source_header_id
                   AND ola.header_id = a.source_header_id
                   AND ola.line_id = a.source_line_id
                   AND a.status = 'N';
    BEGIN
        lv_def_org_id   := mo_utils.get_default_org_id;

        /*
  mo_global.init ('ONT');
        mo_global.set_policy_context ('S', fnd_global.org_id);
        fnd_global.apps_initialize (fnd_global.user_id,
                                    fnd_global.resp_id,
                                    fnd_global.resp_appl_id);
         */

        FOR i IN c_get_headers
        LOOP
            INSERT INTO oe_headers_iface_all (order_source_id, orig_sys_document_ref, sold_to_org_id, operation_code, change_sequence, force_apply_flag, created_by, creation_date, last_updated_by
                                              , last_update_date)
                 VALUES (i.order_source_id,                 -- order_source_id
                                            i.orig_sys_document_ref, -- orig_sys_document_ref
                                                                     i.sold_to_org_id, 'UPDATE', -- operation_code
                                                                                                 p_group_id, -- change sequence as user id
                                                                                                             'Y', -1, -- created_by
                                                                                                                      SYSDATE, -- creation_date
                                                                                                                               -1
                         ,                                  -- last_updated_by
                           SYSDATE                         -- last_update_date
                                  );


            FOR j IN c_get_lines (i.header_id)
            LOOP
                INSERT INTO oe_lines_iface_all (order_source_id,
                                                orig_sys_document_ref,
                                                orig_sys_line_ref,
                                                operation_code,
                                                change_sequence,
                                                inventory_item,
                                                inventory_item_id,
                                                ordered_quantity,
                                                created_by,
                                                creation_date,
                                                last_updated_by,
                                                last_update_date,
                                                org_id,
                                                change_reason,
                                                change_comments)
                     VALUES (j.order_source_id, j.orig_sys_document_ref, j.orig_sys_line_ref, 'UPDATE', p_group_id, j.ordered_item, j.inventory_item_id, 0, -- orderd qty as 0   this will take care of line cancellation
                                                                                                                                                            fnd_global.user_id, SYSDATE, fnd_global.user_id, SYSDATE
                             , i.org_id, '1', 'HOKA Intro Date Changes');
            END LOOP;

            COMMIT;
        END LOOP;

        ln_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'ONT',
                program       => 'OEOIMP',
                argument1     => fnd_global.org_id,          -- Operating Unit
                argument2     => NULL,                         -- Order Source
                argument3     => NULL,                      -- Order Reference
                argument4     => 'UPDATE',                   -- Operation Code
                argument5     => 'N',                        -- Validate Only?
                argument6     => '1',                           -- Debug Level
                argument7     => 4,                               -- Instances
                argument8     => NULL,                       -- Sold To Org Id
                argument9     => NULL,                          -- Sold To Org
                argument10    => p_group_id,                -- Change Sequence
                argument11    => 'Y', -- Enable Single Line Queue for Instances
                argument12    => 'N',                  -- Trim Trailing Blanks
                argument13    => 'Y',  -- Process Orders With No Org Specified
                argument14    => lv_def_org_id,      -- Default Operating Unit
                argument15    => 'Y',
                argument16    => CHR (0));   -- Validate Descriptive Flexfield
        COMMIT;


        IF (APPS.FND_CONCURRENT.WAIT_FOR_REQUEST (ln_request_id, 1, 600000,
                                                  v_dummy, v_dummy, v_dphase,
                                                  v_dstatus, x_dummy))
        THEN
            IF v_dphase = 'COMPLETE' AND v_dstatus = 'NORMAL'
            THEN
                debug_msg (
                    'import program for line cancellation completed sucessfully');
            ELSE
                debug_msg (
                    'import program  for line cancellation completed with errors');
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END cancel_lines;

    PROCEDURE import_lines (p_group_id IN NUMBER)
    AS
        l_count               NUMBER;
        l_source_line_rec     oe_order_pub.line_rec_type;
        l_new_creation_date   DATE;
        l_profile_value       VARCHAR2 (20);
        l_osdr                VARCHAR2 (100);
        l_sold_to_org_id      NUMBER;
        ln_order_source_id    NUMBER;
        ln_request_id         NUMBER;
        v_dummy               VARCHAR2 (100);
        x_dummy               VARCHAR2 (250);
        v_dphase              VARCHAR2 (100);
        v_dstatus             VARCHAR2 (100);
        lv_def_org_id         NUMBER;

        CURSOR c_get_lines IS
            SELECT a.org_id, source_header_id, source_line_id,
                   target_header_id, TO_NUMBER (a.attribute10) target_line_number, new_request_date,
                   new_cancel_lad_date, orig_sys_document_ref, sold_to_org_id
              FROM xxd_ont_order_modify_details_t a, xxd_ont_dtc_rollover_run_t b, oe_order_headers_all oha
             WHERE     a.GROUP_ID = p_group_id
                   AND a.GROUP_ID = b.GROUP_ID
                   AND oha.header_id = a.target_header_id
                   -- AND batch_id = p_thread_no
                   AND a.status = 'N';
    BEGIN
        lv_def_org_id   := mo_utils.get_default_org_id;
        l_profile_value   :=
            fnd_profile.VALUE ('XXD_ONT_DTC_BULK_CREATION_DATE');
        l_new_creation_date   :=
            TO_DATE (l_profile_value, 'DD-MON-YYYY HH24:MI:SS');

        SELECT order_source_id
          INTO ln_order_source_id
          FROM oe_order_sources
         WHERE (name) = 'SOMT-Copy';



        FOR i IN c_get_lines
        LOOP
            l_osdr             := i.orig_sys_document_ref;
            l_sold_to_org_id   := i.sold_to_org_id;
            OE_Line_Util.Query_Row (p_line_id    => i.source_line_id,
                                    x_line_rec   => l_source_line_rec);

            INSERT INTO oe_lines_iface_all (order_source_id, orig_sys_document_ref, orig_sys_line_ref, operation_code, change_sequence, inventory_item, inventory_item_id, ordered_quantity, request_date, created_by, creation_date, last_updated_by, last_update_date, attribute1, unit_selling_price, unit_list_price, calculate_price_flag, -- subinventory,
                                                                                                                                                                                                                                                                                                                                                org_id
                                            , --   blanket_number,
                                              --   customer_item_id_type,
                                              --   customer_item_name,
                                              latest_acceptable_date)
                 VALUES (ln_order_source_id, i.orig_sys_document_ref, -- header osdr
                                                                      'DTC_ROLLOVER_' || p_group_id || '_' || i.target_line_number, 'INSERT', NULL, l_source_line_rec.ordered_item, l_source_line_rec.inventory_item_id, l_source_line_rec.ordered_quantity, l_source_line_rec.request_date, fnd_global.user_id, SYSDATE, fnd_global.user_id, SYSDATE, l_source_line_rec.attribute1, l_source_line_rec.unit_selling_price, l_source_line_rec.unit_list_price, l_source_line_rec.calculate_price_flag, --subinventory,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      l_source_line_rec.org_id
                         , -- blanket_number,
                           -- customer_item_id_type,
                           -- customer_item_name,
                           l_source_line_rec.latest_acceptable_date);
        END LOOP;

        INSERT INTO oe_headers_iface_all (order_source_id,
                                          orig_sys_document_ref,
                                          sold_to_org_id,
                                          operation_code,
                                          change_sequence,
                                          created_by,
                                          creation_date,
                                          last_updated_by,
                                          last_update_date)
             VALUES (ln_order_source_id,                    -- order_source_id
                                         l_osdr,      -- orig_sys_document_ref
                                                 l_sold_to_org_id,
                     'UPDATE',                               -- operation_code
                               NULL, -1,                         -- created_by
                     SYSDATE,                                 -- creation_date
                              -1,                           -- last_updated_by
                                  SYSDATE                  -- last_update_date
                                         );

        COMMIT;
        --  mo_global.init ('ONT');
        debug_msg ('fnd_global.org_id:' || fnd_global.org_id);
        debug_msg ('fnd_global.user_id:' || fnd_global.user_id);
        debug_msg ('fnd_global.resp_id:' || fnd_global.resp_id);
        debug_msg ('fnd_global.resp_appl_id:' || fnd_global.resp_appl_id);
        /*      mo_global.set_policy_context ('S', fnd_global.org_id);
              fnd_global.apps_initialize (fnd_global.user_id,
                                          fnd_global.resp_id,
                                          fnd_global.resp_appl_id);
      */

        ln_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'ONT',
                program       => 'OEOIMP',
                argument1     => fnd_global.org_id,          -- Operating Unit
                argument2     => ln_order_source_id,           -- Order Source
                argument3     => NVL (l_osdr, NULL),        -- Order Reference
                argument4     => 'UPDATE',                   -- Operation Code
                argument5     => 'N',                        -- Validate Only?
                argument6     => '1',                           -- Debug Level
                argument7     => 4,                               -- Instances
                argument8     => NULL,                       -- Sold To Org Id
                argument9     => NULL,                          -- Sold To Org
                argument10    => NULL,                      -- Change Sequence
                argument11    => 'Y', -- Enable Single Line Queue for Instances
                argument12    => 'N',                  -- Trim Trailing Blanks
                argument13    => 'Y',  -- Process Orders With No Org Specified
                argument14    => lv_def_org_id,      -- Default Operating Unit
                argument15    => 'Y',
                argument16    => CHR (0));   -- Validate Descriptive Flexfield
        COMMIT;
        debug_msg ('import program request id:' || ln_request_id);

        IF NVL (ln_request_id, 0) = 0
        THEN
            NULL;
        END IF;


        IF (APPS.FND_CONCURRENT.WAIT_FOR_REQUEST (ln_request_id, 1, 600000,
                                                  v_dummy, v_dummy, v_dphase,
                                                  v_dstatus, x_dummy))
        THEN
            IF v_dphase = 'COMPLETE' AND v_dstatus = 'NORMAL'
            THEN
                debug_msg ('import program completed sucessfully');
            ELSE
                debug_msg ('import program  Completed With Errors');
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END import_lines;

    -- ======================================================================================
    -- This procedure calls OE_ORDER_PUB to make changes in the order
    -- ======================================================================================

    PROCEDURE process_order (p_header_rec IN oe_order_pub.header_rec_type, p_line_tbl IN oe_order_pub.line_tbl_type, p_action_request_tbl IN oe_order_pub.request_tbl_type, x_header_rec OUT NOCOPY oe_order_pub.header_rec_type, x_line_tbl OUT NOCOPY oe_order_pub.line_tbl_type, x_return_status OUT NOCOPY VARCHAR2
                             , x_error_message OUT NOCOPY VARCHAR2)
    AS
        lc_sub_prog_name            VARCHAR2 (100) := 'PROCESS_ORDER';
        lc_return_status            VARCHAR2 (2000);
        lc_error_message            VARCHAR2 (4000);
        lc_msg_data                 VARCHAR2 (4000);
        ln_msg_count                NUMBER;
        ln_msg_index_out            NUMBER;
        lx_header_rec               oe_order_pub.header_rec_type;
        lx_header_val_rec           oe_order_pub.header_val_rec_type;
        lx_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        lx_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        lx_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        lx_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        lx_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        lx_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        lx_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        lx_line_tbl                 oe_order_pub.line_tbl_type;
        lx_line_val_tbl             oe_order_pub.line_val_tbl_type;
        lx_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        lx_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        lx_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        lx_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        lx_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        lx_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        lx_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        lx_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        lx_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        lx_action_request_tbl       oe_order_pub.request_tbl_type;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        oe_msg_pub.delete_msg;
        oe_order_pub.process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_true,
            p_return_values            => fnd_api.g_true,
            p_action_commit            => fnd_api.g_false,
            x_return_status            => lc_return_status,
            x_msg_count                => ln_msg_count,
            x_msg_data                 => lc_msg_data,
            p_org_id                   => gn_org_id,
            p_header_rec               => p_header_rec,
            p_line_tbl                 => p_line_tbl,
            p_action_request_tbl       => p_action_request_tbl,
            x_header_rec               => lx_header_rec,
            x_header_val_rec           => lx_header_val_rec,
            x_header_adj_tbl           => lx_header_adj_tbl,
            x_header_adj_val_tbl       => lx_header_adj_val_tbl,
            x_header_price_att_tbl     => lx_header_price_att_tbl,
            x_header_adj_att_tbl       => lx_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => lx_header_adj_assoc_tbl,
            x_header_scredit_tbl       => lx_header_scredit_tbl,
            x_header_scredit_val_tbl   => lx_header_scredit_val_tbl,
            x_line_tbl                 => lx_line_tbl,
            x_line_val_tbl             => lx_line_val_tbl,
            x_line_adj_tbl             => lx_line_adj_tbl,
            x_line_adj_val_tbl         => lx_line_adj_val_tbl,
            x_line_price_att_tbl       => lx_line_price_att_tbl,
            x_line_adj_att_tbl         => lx_line_adj_att_tbl,
            x_line_adj_assoc_tbl       => lx_line_adj_assoc_tbl,
            x_line_scredit_tbl         => lx_line_scredit_tbl,
            x_line_scredit_val_tbl     => lx_line_scredit_val_tbl,
            x_lot_serial_tbl           => lx_lot_serial_tbl,
            x_lot_serial_val_tbl       => lx_lot_serial_val_tbl,
            x_action_request_tbl       => lx_action_request_tbl);

        IF lc_return_status <> fnd_api.g_ret_sts_success
        THEN
            FOR i IN 1 .. oe_msg_pub.count_msg
            LOOP
                oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                , p_msg_index_out => ln_msg_index_out);

                lc_error_message   :=
                    SUBSTR (lc_error_message || lc_msg_data, 1, 4000);
            END LOOP;

            x_error_message   :=
                NVL (lc_error_message, 'OE_ORDER_PUB Failed');
        ELSE
            x_header_rec   := lx_header_rec;
            x_line_tbl     := lx_line_tbl;
        END IF;

        x_return_status   := lc_return_status;
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Others Exception in PROCESS_ORDER = ' || SQLERRM);
            debug_msg ('End ' || lc_sub_prog_name);
            x_return_status   := 'E';
            x_error_message   := SQLERRM;
    END process_order;

    PROCEDURE start_rollover (p_operation_mode   IN VARCHAR2,
                              p_group_id         IN NUMBER)
    AS
        l_execution_mode   VARCHAR2 (100);
    BEGIN
        SELECT execution_mode
          INTO l_execution_mode
          FROM XXD_ONT_DTC_ROLLOVER_RUN_T
         WHERE GROUP_ID = p_group_id;

        IF l_execution_mode = 'REPORTANDSUBMITBOTH'
        THEN
            insert_prc (p_operation_mode, p_group_id); -- this will extract all the lines and insert into custom table
            bucketing_of_lines (p_operation_mode, p_group_id); -- this will split all extracted lines into N batches(one thread/one batch for each source header id ).
            create_header (p_operation_mode, p_group_id); -- this will just create the heder with no lines in it
        ELSIF l_execution_mode = 'REPORTONLY'
        THEN
            insert_prc (p_operation_mode, p_group_id); -- this will extract all the lines and insert into custom table
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in start_rollover = ' || SQLERRM);
    END start_rollover;


    PROCEDURE create_header (p_operation_mode   IN VARCHAR2,
                             p_group_id         IN NUMBER)
    AS
        CURSOR c_get_headers_info IS
            (SELECT a.org_id, a.attribute5 brand, sold_to_org_id,
                    ship_from_org_id, shipping_method_code, ship_to_org_id,
                    invoice_to_org_id, salesrep_id, freight_terms_code,
                    payment_term_id, demand_class_code, sold_to_contact_id,
                    transactional_curr_code, order_source_id, order_type_id
               FROM oe_order_headers_all a, xxd_ont_order_modify_details_t b
              WHERE     GROUP_ID = p_group_id
                    AND a.header_id = b.source_header_id
                    AND ROWNUM = 1); -- all rows are same w.r.t to header, so pick any for getting hedaer attribute

        l_rec                          c_get_headers_info%ROWTYPE;


        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := FND_API.G_FALSE;
        p_return_values                VARCHAR2 (10) := FND_API.G_FALSE;
        p_action_commit                VARCHAR2 (10) := FND_API.G_FALSE;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        l_header_rec                   OE_ORDER_PUB.Header_Rec_Type;
        l_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type;
        l_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        l_header_adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        l_line_adj_tbl                 OE_ORDER_PUB.line_adj_tbl_Type;
        l_header_scr_tbl               OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        l_line_scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        l_request_rec                  OE_ORDER_PUB.Request_Rec_Type;
        x_header_rec                   OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_old_header_rec               OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_old_header_val_rec           OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_old_Header_Adj_tbl           OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_old_Header_Adj_val_tbl       OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_old_Header_Price_Att_tbl     OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_old_Header_Adj_Att_tbl       OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_old_Header_Adj_Assoc_tbl     OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_old_Header_Scredit_tbl       OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_old_Header_Scredit_val_tbl   OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        x_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type;
        x_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type;
        x_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type;
        x_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type;
        x_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type;
        x_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type;
        x_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        x_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type;
        x_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type;
        x_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type;
        x_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        p_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_old_line_tbl                 OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_old_line_val_tbl             OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_old_Line_Adj_tbl             OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_old_Line_Adj_val_tbl         OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_old_Line_Price_Att_tbl       OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_old_Line_Adj_Att_tbl         OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_old_Line_Adj_Assoc_tbl       OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_old_Line_Scredit_tbl         OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_old_Line_Scredit_val_tbl     OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_old_Lot_Serial_tbl           OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;



        p_old_Lot_Serial_val_tbl       OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_REQUEST_TBL;
        x_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type;
        x_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        x_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type;
        x_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type;
        x_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type;
        x_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type;
        x_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        x_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type;
        X_DEBUG_FILE                   VARCHAR2 (100);
        l_line_tbl_index               NUMBER;
        l_msg_index_out                NUMBER (10);
        l_new_creation_date            DATE;
        l_profile_value                VARCHAR2 (20);
        l_po_number                    VARCHAR2 (100);
        l_new_request_date             DATE;
        l_new_cancel_date              DATE;
        ln_order_source_id             NUMBER;
    BEGIN
        --  attribute1 CD and RD at hdr level
        l_profile_value                         :=
            NVL (fnd_profile.VALUE ('XXD_ONT_DTC_BULK_CREATION_DATE'),
                 '01-Jan-2021');
        l_new_creation_date                     :=
            TO_DATE (l_profile_value, 'DD-MON-YYYY HH24:MI:SS');
        l_header_rec                            := oe_order_pub.g_miss_header_rec;
        l_line_tbl                              := oe_order_pub.g_miss_line_tbl;
        l_action_request_tbl                    := oe_order_pub.g_miss_request_tbl;

        SELECT order_source_id
          INTO ln_order_source_id
          FROM oe_order_sources
         WHERE (name) = 'SOMT-Copy';

        BEGIN
            SELECT SUBSTR (brand || '-' || region || '-' || channel || '-' || department || '-' || period_name, 1, 50), new_request_date, new_cancel_lad_date
              INTO l_po_number, l_new_request_date, l_new_cancel_date
              FROM xxd_ont_dtc_rollover_run_t a
             WHERE     GROUP_ID = p_group_id
                   AND operation_mode = p_operation_mode;
        EXCEPTION
            WHEN OTHERS
            THEN
                UPDATE xxd_ont_order_modify_details_t
                   SET status = 'E', error_message = 'Unexpected error in Cust PO Number Query'
                 WHERE     1 = 1
                       AND GROUP_ID = p_group_id
                       AND operation_mode = p_operation_mode;

                COMMIT;
                RETURN;
        END;

        OPEN c_get_headers_info;

        FETCH c_get_headers_info INTO l_rec;

        CLOSE c_get_headers_info;


        -- New Header Details


        l_header_rec.org_id                     := fnd_global.org_id;
        l_header_rec.sold_to_org_id             := l_rec.sold_to_org_id;
        l_header_rec.cust_po_number             := l_po_number;
        l_header_rec.order_type_id              := l_rec.order_type_id;
        l_header_rec.request_date               := l_new_request_date;
        l_header_rec.ship_from_org_id           := l_rec.ship_from_org_id;
        l_header_rec.shipping_method_code       := l_rec.shipping_method_code;
        l_header_rec.ship_to_org_id             := l_rec.ship_to_org_id;
        l_header_rec.invoice_to_org_id          := l_rec.invoice_to_org_id;
        l_header_rec.salesrep_id                := l_rec.salesrep_id;
        l_header_rec.freight_terms_code         := l_rec.freight_terms_code;
        l_header_rec.payment_term_id            := l_rec.payment_term_id;
        l_header_rec.demand_class_code          := l_rec.demand_class_code;
        l_header_rec.sold_to_contact_id         := l_rec.sold_to_contact_id;
        l_header_rec.transactional_curr_code    :=
            l_rec.transactional_curr_code;
        l_header_rec.order_source_id            := ln_order_source_id;

        IF l_new_creation_date IS NOT NULL
        THEN
            l_header_rec.ordered_date   := l_new_creation_date;
        ELSE
            l_header_rec.ordered_date   := SYSDATE;
        END IF;

        l_header_rec.deliver_to_org_id          := NULL;
        l_header_rec.attribute1                 := l_new_cancel_date; -- header cancel date
        l_header_rec.attribute2                 := NULL;
        l_header_rec.attribute3                 := NULL;
        l_header_rec.attribute4                 := NULL;
        l_header_rec.attribute5                 := l_rec.brand;
        l_header_rec.attribute6                 := NULL;
        l_header_rec.attribute7                 := NULL;
        l_header_rec.attribute8                 := NULL;
        l_header_rec.attribute9                 := NULL;
        l_header_rec.attribute10                := NULL;
        l_header_rec.attribute11                := NULL;
        l_header_rec.attribute12                := NULL;
        l_header_rec.attribute13                := NULL;
        l_header_rec.attribute14                := NULL;
        l_header_rec.attribute15                := NULL;
        l_header_rec.attribute16                := NULL;
        l_header_rec.attribute17                := NULL;
        l_header_rec.attribute18                := NULL;
        l_header_rec.attribute19                := NULL;

        l_header_rec.operation                  := oe_globals.g_opr_create;


        -- Action Table Details
        l_action_request_tbl (1)                :=
            oe_order_pub.g_miss_request_rec;
        l_action_request_tbl (1).entity_code    := oe_globals.g_entity_header;
        l_action_request_tbl (1).request_type   := oe_globals.g_book_order;

        OE_ORDER_PUB.PROCESS_ORDER (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_false,
            p_return_values            => fnd_api.g_false,
            p_action_commit            => fnd_api.g_false,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            x_header_rec               => x_header_rec,
            x_header_val_rec           => x_header_val_rec,
            x_Header_Adj_tbl           => x_Header_Adj_tbl,
            x_Header_Adj_val_tbl       => x_Header_Adj_val_tbl,
            x_Header_price_Att_tbl     => x_Header_price_Att_tbl,
            x_Header_Adj_Att_tbl       => x_Header_Adj_Att_tbl,
            x_Header_Adj_Assoc_tbl     => x_Header_Adj_Assoc_tbl,
            x_Header_Scredit_tbl       => x_Header_Scredit_tbl,
            x_Header_Scredit_val_tbl   => x_Header_Scredit_val_tbl,
            x_line_tbl                 => p_line_tbl,
            x_line_val_tbl             => x_line_val_tbl,
            x_Line_Adj_tbl             => x_Line_Adj_tbl,
            x_Line_Adj_val_tbl         => x_Line_Adj_val_tbl,
            x_Line_price_Att_tbl       => x_Line_price_Att_tbl,
            x_Line_Adj_Att_tbl         => x_Line_Adj_Att_tbl,
            x_Line_Adj_Assoc_tbl       => x_Line_Adj_Assoc_tbl,
            x_Line_Scredit_tbl         => x_Line_Scredit_tbl,
            x_Line_Scredit_val_tbl     => x_Line_Scredit_val_tbl,
            x_Lot_Serial_tbl           => x_Lot_Serial_tbl,
            x_Lot_Serial_val_tbl       => x_Lot_Serial_val_tbl,
            x_action_request_tbl       => l_action_request_tbl);
        fnd_file.put_line (fnd_file.LOG,
                           'Order Header_ID : ' || x_header_rec.header_id);

        FOR i IN 1 .. l_msg_count
        LOOP
            Oe_Msg_Pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                            , p_msg_index_out => l_msg_index_out);

            fnd_file.put_line (fnd_file.LOG, 'message : ' || l_msg_data);
            fnd_file.put_line (fnd_file.LOG,
                               'message index : ' || l_msg_index_out);
        END LOOP;

        -- Check the return status
        IF l_return_status = FND_API.G_RET_STS_SUCCESS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'order Created Successfully' || SQLERRM);

            UPDATE xxd_ont_order_modify_details_t
               SET target_order_number = x_header_rec.order_number, target_header_id = x_header_rec.header_id, status = 'N'
             WHERE     1 = 1
                   AND GROUP_ID = p_group_id
                   AND operation_mode = p_operation_mode;

            IF l_new_creation_date IS NOT NULL
            THEN
                UPDATE oe_order_headers_all
                   SET creation_date   = l_new_creation_date
                 WHERE header_id = x_header_rec.header_id;
            END IF;
        ELSE
            fnd_file.put_line (fnd_file.LOG,
                               'order Creation failed' || SQLERRM);

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = SUBSTR (l_msg_data, 1, 2000)
             WHERE     1 = 1
                   AND GROUP_ID = p_group_id
                   AND operation_mode = p_operation_mode;
        END IF;


        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in create_header = ' || SQLERRM);
            ROLLBACK;
    END create_header;

    PROCEDURE book_order (p_group_id IN NUMBER)
    AS
        lc_api_return_status     VARCHAR2 (1);
        lc_lock_status           VARCHAR2 (1);
        lc_error_message         VARCHAR2 (4000);
        ln_line_tbl_count        NUMBER := 0;
        l_header_rec             oe_order_pub.header_rec_type;
        l_header_rec_1           oe_order_pub.header_rec_type;
        lx_header_rec            oe_order_pub.header_rec_type;
        lx_header_rec_1          oe_order_pub.header_rec_type;
        l_source_header_rec      oe_order_pub.header_rec_type;
        l_target_header_rec      oe_order_pub.header_rec_type;
        l_line_tbl               oe_order_pub.line_tbl_type;
        l_line_tbl_1             oe_order_pub.line_tbl_type;
        lx_line_tbl              oe_order_pub.line_tbl_type;
        lx_line_tbl_1            oe_order_pub.line_tbl_type;
        l_source_line_rec        oe_order_pub.line_rec_type;
        l_action_request_tbl     oe_order_pub.request_tbl_type;
        l_action_request_tbl_1   oe_order_pub.request_tbl_type;


        CURSOR c_get_source_header IS
            SELECT target_header_id
              FROM xxd_ont_order_modify_details_t a
             WHERE     a.GROUP_ID = p_group_id
                   AND source_header_id IS NOT NULL
                   AND ROWNUM = 1;
    BEGIN
        FOR rec IN c_get_source_header
        LOOP
            -- Action Table Details
            l_action_request_tbl (1)                := oe_order_pub.g_miss_request_rec;
            l_action_request_tbl (1).entity_code    :=
                oe_globals.g_entity_header;
            l_action_request_tbl (1).request_type   :=
                oe_globals.g_book_order;
            l_action_request_tbl (1).entity_id      := rec.target_header_id;

            process_order (p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, p_action_request_tbl => l_action_request_tbl, x_header_rec => lx_header_rec, x_line_tbl => lx_line_tbl, x_return_status => lc_api_return_status
                           , x_error_message => lc_error_message);

            IF lc_api_return_status <> 'S'
            THEN
                debug_msg (
                    'error while booking the order ' || lc_error_message);
            END IF;
        END LOOP;

        -- new update the somt table with the ssd back
        UPDATE xxd_ont_order_modify_details_t a
           SET target_schedule_ship_date   =
                   (SELECT schedule_ship_date
                      FROM oe_order_lines_all b
                     WHERE b.line_id = a.target_line_id)
         WHERE GROUP_ID = p_group_id AND status = 'S';

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in book_order = ' || SQLERRM);
    END book_order;

    -- this process will add lines into the given order header
    --   attribute1 CD, LAD and RD at line level

    PROCEDURE add_lines (p_group_id      IN NUMBER,
                         p_thread_no     IN NUMBER,
                         p_line_status   IN VARCHAR2)
    AS
        lc_api_return_status           VARCHAR2 (1);
        lc_lock_status                 VARCHAR2 (1);
        lc_error_message               VARCHAR2 (4000);
        ln_line_tbl_count              NUMBER := 0;
        l_header_rec                   oe_order_pub.header_rec_type;
        l_header_rec_1                 oe_order_pub.header_rec_type;
        lx_header_rec                  oe_order_pub.header_rec_type;
        lx_header_rec_1                oe_order_pub.header_rec_type;
        l_source_header_rec            oe_order_pub.header_rec_type;
        l_target_header_rec            oe_order_pub.header_rec_type;    -- 1.1
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_line_tbl_1                   oe_order_pub.line_tbl_type;
        lx_line_tbl                    oe_order_pub.line_tbl_type;
        lx_line_tbl_1                  oe_order_pub.line_tbl_type;
        l_source_line_rec              oe_order_pub.line_rec_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_action_request_tbl_1         oe_order_pub.request_tbl_type;
        l_new_creation_date            DATE;
        l_profile_value                VARCHAR2 (20);
        l_count_cancellation_attempt   NUMBER;

        CURSOR c_get_lines IS
            SELECT a.org_id, source_header_id, source_line_id,
                   target_header_id, TO_NUMBER (a.attribute10) target_line_number, new_request_date,
                   new_cancel_lad_date
              FROM xxd_ont_order_modify_details_t a, xxd_ont_dtc_rollover_run_t b
             WHERE     a.GROUP_ID = p_group_id
                   AND a.GROUP_ID = b.GROUP_ID
                   AND batch_id =
                       DECODE (p_line_status,
                               'N', p_thread_no,
                               'E', batch_id)
                   AND a.status = p_line_status;
    BEGIN
        l_profile_value   :=
            NVL (fnd_profile.VALUE ('XXD_ONT_DTC_BULK_CREATION_DATE'),
                 '01-Jan-2021');
        l_new_creation_date   :=
            TO_DATE (l_profile_value, 'DD-MON-YYYY HH24:MI:SS');

        FOR i IN c_get_lines
        LOOP
            SAVEPOINT line;
            debug_msg ('begin cancelling Source line ' || i.source_line_id);

            l_count_cancellation_attempt               := 1;
            --step1 query the source line before cancelling
            OE_Line_Util.Query_Row (p_line_id    => i.source_line_id,
                                    x_line_rec   => l_source_line_rec);
            debug_msg (
                   ' cancelling Source line ordered Quantity:-'
                || l_source_line_rec.ordered_quantity);
            l_header_rec                               := oe_order_pub.g_miss_header_rec;
            l_line_tbl                                 := oe_order_pub.g_miss_line_tbl;
            l_action_request_tbl                       := oe_order_pub.g_miss_request_tbl;
            -- step2 cancel the source line
            l_line_tbl (1)                             := oe_order_pub.g_miss_line_rec;
            l_line_tbl (1).header_id                   := i.source_header_id;
            l_line_tbl (1).org_id                      := i.org_id;
            l_line_tbl (1).line_id                     := i.source_line_id;
            l_line_tbl (1).ordered_quantity            := 0;
            l_line_tbl (1).cancelled_flag              := 'Y';
            l_line_tbl (1).calculate_price_flag        := 'N';
            l_line_tbl (1).change_reason               := 'BLK_CANDEL_DECKERS';
            l_line_tbl (1).change_comments             :=
                   'Line cancelled on '
                || SYSDATE
                || ' by program request_id: '
                || gn_request_id;
            l_line_tbl (1).request_id                  := gn_request_id;
            l_line_tbl (1).operation                   := oe_globals.g_opr_update;

            process_order (p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, p_action_request_tbl => l_action_request_tbl, x_header_rec => lx_header_rec, x_line_tbl => lx_line_tbl, x_return_status => lc_api_return_status
                           , x_error_message => lc_error_message);

            -- lc_api_return_status := 'S';
            debug_msg (
                   ' end cancelling line status attempt '
                || l_count_cancellation_attempt
                || ' is '
                || lc_api_return_status);

            IF lc_api_return_status <> 'S'
            THEN
                UPDATE xxd_ont_order_modify_details_t
                   SET status = 'E', error_message = SUBSTR (lc_error_message, 1, 2000), request_id = gn_request_id
                 WHERE     1 = 1
                       AND GROUP_ID = p_group_id
                       AND source_header_id = i.source_header_id
                       AND source_line_id = i.source_line_id
                       AND batch_id = p_thread_no;

                CONTINUE; -- wont even go to step3 onwards;jsut skip to the next line
            ELSIF     l_source_line_rec.ordered_quantity = 0
                  AND lc_api_return_status = 'S'
            THEN -- line cancellation is sucess but somehow the soruce ordwred qty is zero
                ROLLBACK TO line;

                UPDATE xxd_ont_order_modify_details_t
                   SET status = 'E', error_message = 'Source line Qty is 0 when attempting for Cancellation. no New line created', request_id = gn_request_id
                 WHERE     1 = 1
                       AND GROUP_ID = p_group_id
                       AND source_header_id = i.source_header_id
                       AND source_line_id = i.source_line_id
                       AND batch_id = p_thread_no;

                COMMIT;
                CONTINUE;
            ELSE                                -- line cancellation is sucess
                NULL;
            END IF;

            -- step3 add the old soruce line(canceled in step2) into the new header
            debug_msg ('  line cancellation done ' || i.source_line_id);
            -- reset the variables
            --   l_header_rec_1 := oe_order_pub.g_miss_header_rec;
            l_line_tbl_1                               :=
                oe_order_pub.g_miss_line_tbl;
            l_action_request_tbl_1                     :=
                oe_order_pub.g_miss_request_tbl;
            --
            --   l_header_rec_1.header_id := i.target_header_id;
            --    l_header_rec_1.org_id := i.org_id;
            --  l_header_rec_1.operation := oe_globals.g_opr_update;

            l_line_tbl_1 (1)                           :=
                oe_order_pub.g_miss_line_rec;
            l_line_tbl_1 (1).operation                 := oe_globals.g_opr_create;
            l_line_tbl_1 (1).line_number               := i.target_line_number; -- line number
            l_line_tbl_1 (1).calculate_price_flag      := 'N';
            l_line_tbl_1 (1).unit_selling_price        :=
                l_source_line_rec.unit_selling_price;

            l_line_tbl_1 (1).inventory_item_id         :=
                l_source_line_rec.inventory_item_id;
            l_line_tbl_1 (1).header_id                 := i.target_header_id;
            l_line_tbl_1 (1).ordered_quantity          :=
                l_source_line_rec.ordered_quantity;
            l_line_tbl_1 (1).source_document_line_id   :=
                l_source_line_rec.line_id;
            l_line_tbl_1 (1).source_document_id        :=
                l_source_line_rec.header_id;
            l_line_tbl_1 (1).source_document_type_id   :=
                l_source_line_rec.source_document_type_id;
            l_line_tbl_1 (1).deliver_to_org_id         :=
                l_source_line_rec.deliver_to_org_id;
            l_line_tbl_1 (1).ship_to_org_id            :=
                l_source_line_rec.ship_to_org_id;
            l_line_tbl_1 (1).invoice_to_org_id         :=
                l_source_line_rec.invoice_to_org_id;
            l_line_tbl_1 (1).pricing_date              :=
                l_source_line_rec.pricing_date;
            l_line_tbl_1 (1).order_source_id           :=
                l_source_line_rec.order_source_id;
            l_line_tbl_1 (1).salesrep_id               :=
                l_source_line_rec.salesrep_id;
            l_line_tbl_1 (1).payment_term_id           :=
                l_source_line_rec.payment_term_id;
            l_line_tbl_1 (1).freight_terms_code        :=
                l_source_line_rec.freight_terms_code;
            l_line_tbl_1 (1).shipping_method_code      :=
                l_source_line_rec.shipping_method_code;
            l_line_tbl_1 (1).ship_from_org_id          :=
                l_source_line_rec.ship_from_org_id;
            l_line_tbl_1 (1).demand_class_code         :=
                l_source_line_rec.demand_class_code;
            l_line_tbl_1 (1).unit_list_price           :=
                l_source_line_rec.unit_list_price;

            l_line_tbl_1 (1).request_date              := i.new_request_date; -- this will come from lookup
            l_line_tbl_1 (1).attribute1                :=
                i.new_cancel_lad_date;           -- this will come from lookup
            l_line_tbl_1 (1).latest_acceptable_date    :=
                i.new_cancel_lad_date;           -- this will come from lookup
            l_line_tbl_1 (1).attribute2                :=
                l_source_line_rec.attribute2;
            l_line_tbl_1 (1).attribute3                :=
                l_source_line_rec.attribute3;
            l_line_tbl_1 (1).attribute4                :=
                l_source_line_rec.attribute4;
            l_line_tbl_1 (1).attribute5                :=
                l_source_line_rec.attribute5;
            l_line_tbl_1 (1).attribute6                :=
                l_source_line_rec.attribute6;
            l_line_tbl_1 (1).attribute7                :=
                l_source_line_rec.attribute7;
            l_line_tbl_1 (1).attribute8                :=
                l_source_line_rec.attribute8;
            l_line_tbl_1 (1).attribute9                :=
                l_source_line_rec.attribute9;
            l_line_tbl_1 (1).attribute10               :=
                l_source_line_rec.attribute10;
            l_line_tbl_1 (1).attribute11               :=
                l_source_line_rec.attribute11;
            l_line_tbl_1 (1).attribute12               :=
                l_source_line_rec.attribute12;
            l_line_tbl_1 (1).attribute13               :=
                l_source_line_rec.attribute13;
            l_line_tbl_1 (1).attribute14               :=
                l_source_line_rec.attribute14;
            l_line_tbl_1 (1).attribute15               :=
                l_source_line_rec.attribute15;

           <<process_addline>>
            process_order (p_header_rec => l_header_rec_1, p_line_tbl => l_line_tbl_1, p_action_request_tbl => l_action_request_tbl_1, x_header_rec => lx_header_rec_1, x_line_tbl => lx_line_tbl_1, x_return_status => lc_api_return_status
                           , x_error_message => lc_error_message);

            debug_msg ('  new line creation ' || lc_api_return_status);

            IF lc_api_return_status <> 'S'
            THEN
                -- failure
                IF (l_count_cancellation_attempt < 4)
                THEN
                    UPDATE xxd_ont_order_modify_details_t
                       SET attribute4 = DECODE (l_count_cancellation_attempt, 1, SUBSTR (lc_error_message, 1, 239), attribute4), attribute5 = DECODE (l_count_cancellation_attempt, 2, SUBSTR (lc_error_message, 1, 239), attribute5), attribute6 = DECODE (l_count_cancellation_attempt, 3, SUBSTR (lc_error_message, 1, 239), attribute6),
                           request_id = gn_request_id
                     WHERE     1 = 1
                           AND GROUP_ID = p_group_id
                           AND source_header_id = i.source_header_id
                           AND source_line_id = i.source_line_id
                           AND batch_id =
                               DECODE (p_line_status,
                                       'N', p_thread_no,
                                       'E', batch_id);

                    l_count_cancellation_attempt   :=
                        l_count_cancellation_attempt + 1;
                    DBMS_LOCK.sleep (1);
                    GOTO process_addline;
                END IF;

                ROLLBACK TO line;

                UPDATE xxd_ont_order_modify_details_t
                   SET status = 'E', error_message = SUBSTR ('This Line will be reprocess again: ' || lc_error_message, 1, 1900), request_id = gn_request_id
                 WHERE     1 = 1
                       AND GROUP_ID = p_group_id
                       AND source_header_id = i.source_header_id
                       AND source_line_id = i.source_line_id
                       AND batch_id =
                           DECODE (p_line_status,
                                   'N', p_thread_no,
                                   'E', batch_id);
            ELSE                               -- new line creation is success
                UPDATE xxd_ont_order_modify_details_t
                   SET status = 'S', target_line_id = lx_line_tbl_1 (1).line_id, target_customer_number = source_cust_account,
                       target_cust_po_num = lx_line_tbl_1 (1).cust_po_number, target_ordered_item = lx_line_tbl_1 (1).ordered_item, target_ordered_quantity = lx_line_tbl_1 (1).ordered_quantity,
                       target_line_request_date = lx_line_tbl_1 (1).request_date, target_schedule_ship_date = lx_line_tbl_1 (1).schedule_ship_date, target_latest_acceptable_date = lx_line_tbl_1 (1).latest_acceptable_date,
                       target_line_cancel_date = lx_line_tbl_1 (1).attribute1, target_order_type = source_order_type, request_id = gn_request_id,
                       error_message = NULL
                 WHERE     1 = 1
                       AND GROUP_ID = p_group_id
                       AND source_header_id = i.source_header_id
                       AND source_line_id = i.source_line_id
                       AND batch_id =
                           DECODE (p_line_status,
                                   'N', p_thread_no,
                                   'E', batch_id);

                IF l_new_creation_date IS NOT NULL
                THEN
                    UPDATE oe_order_lines_all
                       SET creation_date   = l_new_creation_date
                     WHERE line_id = lx_line_tbl_1 (1).line_id;
                END IF;
            END IF;

            -- if error at any stage rollback completely to savept;
            COMMIT;
        END LOOP;

        -- booking the order at the end; we are calling one instance of child program at the end to reprocess all the rror lines; at the time only,at the end, we are booking the order
        IF (p_line_status = 'E')
        THEN
            book_order (p_group_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in add_lines = ' || SQLERRM);
    END add_lines;

    -- procedure to split lines; split all the lines of the given group id
    --into N batches/thread to be triggerd simantiously. lines of an order may split b/w two different thread but its ok as we are pre populating the line num
    -- if required we can change the logic and group all the lines of same header id into one thread.
    PROCEDURE bucketing_of_lines (p_operation_mode   IN VARCHAR2,
                                  p_group_id         IN NUMBER)
    AS
        lc_debug_mode      VARCHAR2 (1000);

        lv_error_msg       VARCHAR2 (4000) := NULL;
        lv_error_stat      VARCHAR2 (4) := 'S';
        lv_error_code      VARCHAR2 (4000) := NULL;
        ln_error_num       NUMBER;
        l_batch_id         NUMBER := 0;

        /*
                CURSOR c_get_lines (p_no_of_threads NUMBER)
                IS
                    (SELECT bucket_no,
                            source_line_id,
                            GROUP_ID,
                            new_line_num
                       FROM (SELECT NTILE (p_no_of_threads) OVER (ORDER BY NULL)
                                        bucket_no,
                                    ROW_NUMBER ()
                                        OVER (PARTITION BY GROUP_ID ORDER BY NULL)
                                        new_line_num,
                                    a.*
                               FROM xxd_ont_order_modify_details_t a
                              WHERE     1 = 1
                                    AND GROUP_ID = p_group_id
                                    AND operation_mode = p_operation_mode));
        */
        CURSOR c_get_distinct_source_headers IS
            (SELECT DISTINCT source_header_id
               FROM xxd_ont_order_modify_details_t a
              WHERE     GROUP_ID = p_group_id
                    AND operation_mode = p_operation_mode);


        --     TYPE xxd_line_typ IS TABLE OF c_get_lines%ROWTYPE;

        --v_ins_type         xxd_line_typ := xxd_line_typ ();
        ln_lines_count     NUMBER;
        ln_no_of_process   NUMBER;
    BEGIN
        FOR i IN c_get_distinct_source_headers
        LOOP
            l_batch_id   := l_batch_id + 1;

            UPDATE xxd_ont_order_modify_details_t a
               SET batch_id = l_batch_id, status = 'N'
             WHERE     source_header_id = i.source_header_id
                   AND GROUP_ID = p_group_id;

            COMMIT;
        END LOOP;

        /*
        BEGIN
                  SELECT COUNT (1)
                    INTO ln_lines_count
                    FROM xxd_ont_order_modify_details_t
                   WHERE     batch_id IS NULL
                         AND status = 'I'
                         AND GROUP_ID = p_group_id;

                  SELECT lookup_code
                    INTO ln_no_of_process
                    FROM fnd_lookup_values
                   WHERE     1 = 1
                         AND lookup_type = 'XXD_ONT_NO_OF_PROCESSES'
                         AND enabled_flag = 'Y'
                         AND language = USERENV ('LANG')
                         AND SYSDATE BETWEEN start_date_active
                                         AND NVL (end_date_active, SYSDATE + 1)
                         AND ln_lines_count BETWEEN TO_NUMBER (meaning)
                                                AND TO_NUMBER (
                                                        NVL (tag, 9999999999999999));

              EXCEPTION
                  WHEN OTHERS
                  THEN
                      ln_lines_count := 0;
                      ln_no_of_process := 0;
                      debug_msg ('Exception - ' || SQLERRM);
              END;

              OPEN c_get_lines (1);

              LOOP
                  FETCH c_get_lines BULK COLLECT INTO v_ins_type LIMIT 5000;

                  IF (v_ins_type.COUNT > 0)
                  THEN
                      BEGIN
                          FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                            SAVE EXCEPTIONS
                              UPDATE xxd_ont_order_modify_details_t
                                 SET batch_id = v_ins_type (i).bucket_no,
                                     attribute10 = v_ins_type (i).new_line_num,
                                     status = 'N'
                               WHERE     GROUP_ID = p_group_id
                                     AND source_line_id =
                                         v_ins_type (i).source_line_id
                                     AND operation_mode = p_operation_mode;
                      EXCEPTION
                          WHEN OTHERS
                          THEN
                              FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                              LOOP
                                  lv_error_stat := 'E';
                                  ln_error_num :=
                                      SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                  lv_error_code :=
                                      SQLERRM (
                                          -1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                  lv_error_msg :=
                                      SUBSTR (
                                          (   lv_error_msg
                                           || ' Error While updating into Table'
                                           || lv_error_code
                                           || ' #'),
                                          1,
                                          4000);
                              END LOOP;
                      END;
                  END IF;

                  EXIT WHEN c_get_lines%NOTFOUND;
              END LOOP;

              CLOSE c_get_lines;
      */

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END bucketing_of_lines;


    -- ======================================================================================
    -- This procedure will be called from oaf page
    -- ======================================================================================

    PROCEDURE process_order_prc (p_operation_mode IN VARCHAR2, p_group_id IN NUMBER, p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_brand IN VARCHAR2, p_order_type_id IN VARCHAR2, p_inv_org_id IN NUMBER, p_channel IN VARCHAR2, p_department IN VARCHAR2, p_request_date_from IN DATE, p_request_date_to IN DATE, p_execution_mode IN VARCHAR2, x_ret_status OUT NOCOPY VARCHAR2
                                 , x_err_msg OUT NOCOPY VARCHAR2)
    AS
        lc_status           VARCHAR2 (10);
        lc_ret_status       VARCHAR2 (1);
        ln_record_count     NUMBER := 0;
        ln_valid_count      NUMBER := 0;
        ln_req_id           NUMBER;
        l_child_plsql       VARCHAR2 (4000);
        l_jobid             NUMBER;
        l_mode              VARCHAR2 (20);
        l_calendar_period   VARCHAR2 (100);
        l_new_rd            DATE;
        l_new_cancel_lad    DATE;
        l_running_count     NUMBER;
    /*
       CURSOR c_create_batches IS
                (  SELECT MIN (startdate)
                              start_date,
                          MAX (startdate + 1) - INTERVAL '0.001' SECOND
                              end_date,
                          thread_no
                     FROM (SELECT a.*,
                                  NTILE (2) OVER (ORDER BY startdate)    AS thread_no
                             FROM (WITH
                                       n
                                       AS
                                           (    SELECT LEVEL     n
                                                  FROM DUAL
                                            CONNECT BY LEVEL <= 365),
                                       t
                                       AS
                                           (SELECT 1
                                                       AS id,
                                                   TO_DATE (p_request_date_from,
                                                            'dd-mm-yyyy')
                                                       AS StartDate,
                                                   TO_DATE (p_request_date_to)
                                                       AS EndDate
                                              FROM DUAL)
                                     SELECT t.id,
                                            (CASE
                                                 WHEN n = 1 THEN StartDate
                                                 ELSE TRUNC (StartDate + n - 1)
                                             END)    AS StartDate
                                       FROM t JOIN n ON StartDate + n - 1 <= EndDate
                                   ORDER BY id, StartDate) a) b
                 GROUP BY thread_no);
    */

    BEGIN
        gn_org_id              := p_org_id;
        gn_user_id             := p_user_id;
        gn_application_id      := p_resp_app_id;
        gn_responsibility_id   := p_resp_id;
        init ();

        SELECT COUNT (1)
          INTO l_running_count
          FROM fnd_concurrent_requests
         WHERE     request_id IN
                       (SELECT request_id
                          FROM XXDO.XXD_ONT_DTC_ROLLOVER_RUN_T
                         WHERE     org_id = p_org_id
                               AND order_type_id = p_order_type_id
                               AND inv_org_id = p_inv_org_id
                               AND department = p_department
                               AND brand = p_brand
                               AND request_date_from = p_request_date_from
                               AND request_date_to = p_request_date_to)
               AND phase_code IN ('P', 'R', 'I');


        IF l_running_count > 0
        THEN
            x_err_msg      := 'Program already running for the same Paramters';
            x_ret_status   := 'E';
            RETURN;
        END IF;

        lc_status              := xxd_ont_check_plan_run_fnc ();
        x_ret_status           := 'S';
        lc_status              := 'N';                          -- for testing

        BEGIN
            SELECT LOOKUP_CODE, FND_DATE.CANONICAL_TO_DATE (ATTRIBUTE3) new_RD, FND_DATE.CANONICAL_TO_DATE (ATTRIBUTE4) new_cancel_LAD
              INTO l_calendar_period, l_new_rd, l_new_cancel_lad
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'XXDO_ROLLOVER_445_CALENDAR'
                   AND enabled_flag = 'Y'
                   -- tag is null for  us and ca;both 100 and 82 is same
                   --tag is org id for emea
                   AND (fnd_global.org_id IN (100, 82) AND tag IS NULL OR (fnd_global.org_id = tag))
                   AND language = USERENV ('LANG')
                   AND SYSDATE BETWEEN FND_DATE.CANONICAL_TO_DATE (
                                           ATTRIBUTE1)
                                   AND FND_DATE.CANONICAL_TO_DATE (
                                           ATTRIBUTE2)
                   AND SYSDATE BETWEEN start_date_active
                                   AND NVL (end_date_active, SYSDATE + 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                x_err_msg      := 'Incorrect 445 calender setup';
                x_ret_status   := 'E';
                RETURN;
        END;

        IF lc_status = 'N'
        THEN
            INSERT INTO XXDO.XXD_ONT_DTC_ROLLOVER_RUN_T (GROUP_ID,
                                                         operation_mode,
                                                         BRAND,
                                                         org_id,
                                                         CHANNEL,
                                                         order_type_id,
                                                         inv_org_id,
                                                         department,
                                                         region,
                                                         new_request_date,
                                                         new_cancel_LAD_date,
                                                         period_Name,
                                                         REQUEST_DATE_FROM,
                                                         REQUEST_DATE_TO,
                                                         execution_mode,
                                                         CREATED_BY,
                                                         CREATION_DATE,
                                                         LAST_UPDATED_BY,
                                                         LAST_UPDATE_DATE,
                                                         LAST_UPDATE_LOGIN)
                 VALUES (p_group_id, p_operation_mode, p_BRAND,
                         p_org_id, p_channel, p_order_type_id,
                         p_inv_org_id, p_department, DECODE (p_org_id,  100, 'US',  82, 'CA',  98, 'EMEA'), l_new_rd, l_new_cancel_lad, l_calendar_period, p_request_date_from, p_request_date_to, p_execution_mode, fnd_global.user_id, SYSDATE, fnd_global.user_id
                         , SYSDATE, -1);

            COMMIT;
        ELSE
            x_err_msg      :=
                'Planning Programs are running in ASCP. Order Update Program cannot run now';
            x_ret_status   := 'E';
            RETURN;
        END IF;

        -- this master submission will take care of extracting the lines and insert into the custom table and create blank header
        ln_req_id              := 0;
        ln_req_id              :=
            fnd_request.submit_request (application => 'XXDO', program => 'XXD_ONT_DTC_BULK_ROLLOVER_MST', description => NULL, start_time => NULL, sub_request => NULL, argument1 => p_operation_mode
                                        , argument2 => p_group_id);

        IF ln_req_id > 0
        THEN
            UPDATE XXDO.XXD_ONT_DTC_ROLLOVER_RUN_T
               SET request_id   = ln_req_id
             WHERE GROUP_ID = p_group_id;

            COMMIT;
            x_ret_status   := 'S';
        ELSE
            ROLLBACK;
            x_err_msg      := 'Unable to submit master concurrent program';
            x_ret_status   := 'E';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_err_msg      := SUBSTR (SQLERRM, 1, 2000);
            x_ret_status   := 'E';
    END process_order_prc;



    PROCEDURE insert_prc (p_operation_mode IN VARCHAR2, p_group_id IN NUMBER)
    AS
        CURSOR c_get_lines IS
            (((SELECT ooha.header_id,
                      oola.line_id,
                      (CASE
                           WHEN     (SELECT 1
                                       FROM wsh_delivery_details wdd
                                      WHERE     wdd.source_line_id =
                                                oola.line_id
                                            AND wdd.source_code = 'OE'
                                            AND wdd.move_order_line_id
                                                    IS NOT NULL
                                            AND ROWNUM = 1) =
                                    1
                                AND oe_line_status_pub.get_line_status (
                                        oola.line_id,
                                        oola.flow_status_code) =
                                    'Awaiting Shipping'
                           THEN
                               'Picked'
                           ELSE
                               oe_line_status_pub.get_line_status (
                                   oola.line_id,
                                   oola.flow_status_code)
                       END)
                          pick_status,
                      (SELECT hou.name
                         FROM hr_operating_units hou
                        WHERE hou.organization_id = ooha.org_id)
                          operating_unit,
                      (SELECT hca.account_name
                         FROM hz_cust_accounts hca
                        WHERE hca.cust_account_id = ooha.sold_to_org_id)
                          customer_name,
                      (SELECT hca.account_number
                         FROM hz_cust_accounts hca
                        WHERE hca.cust_account_id = ooha.sold_to_org_id)
                          account_number,
                      ooha.order_number,
                      ooha.cust_po_number,
                      (SELECT name
                         FROM oe_transaction_types_tl ottt
                        WHERE     ottt.transaction_type_id =
                                  ooha.order_type_id
                              AND ottt.language = USERENV ('LANG'))
                          order_type,
                      ooha.attribute5
                          brand,
                      TRUNC (ooha.request_date)
                          header_request_date,
                      fnd_conc_date.string_to_date (ooha.attribute1)
                          header_cancel_date,
                      oola.line_number || '.' || oola.shipment_number
                          line_number,
                      oola.ordered_item,
                      REGEXP_SUBSTR (oola.ordered_item, '[^-]+', 1,
                                     1)
                          style,
                      REGEXP_SUBSTR (oola.ordered_item, '[^-]+', 1,
                                     2)
                          color,
                      (SELECT mp.organization_code
                         FROM mtl_parameters mp
                        WHERE mp.organization_id = oola.ship_from_org_id)
                          warehouse,
                      oola.ordered_quantity,
                      TRUNC (oola.request_date)
                          line_request_date,
                      TRUNC (oola.latest_acceptable_date)
                          latest_acceptable_date,
                      TRUNC (oola.schedule_ship_date)
                          schedule_ship_date,
                      fnd_conc_date.string_to_date (oola.attribute1)
                          line_cancel_date,
                      ooha.org_id,
                      OOHA.sold_to_org_id,
                      ooha.order_type_id,
                      oola.inventory_item_id,
                      ROW_NUMBER ()
                          OVER (PARTITION BY GROUP_ID ORDER BY NULL)
                          new_line_num
                 FROM oe_order_headers_all ooha, oe_order_lines_all oola, xxd_ont_dtc_rollover_run_t xod,
                      xxd_common_items_v xiv
                WHERE     1 = 1
                      AND xod.GROUP_ID = p_group_id
                      -- AND xod.created_by = fnd_global.user_id
                      AND xiv.organization_id = 106                     -- mst
                      AND xiv.inventory_item_id = oola.inventory_item_id
                      -- AND ooha.order_number = 83234392
                      AND ordered_quantity > 0
                      AND ooha.booked_flag = 'Y'
                      AND oola.booked_flag = 'Y'
                      AND oola.ship_from_org_id = xod.inv_org_id
                      --AND ROWNUM < 2
                      AND DECODE (xiv.department,
                                  'FOOTWEAR', 'FOOTWEAR',
                                  'NON-FOOTWEAR') =
                          xod.department
                      AND xod.order_type_id = ooha.order_type_id
                      AND xod.org_id = ooha.org_id
                      AND xod.brand = ooha.attribute5
                      AND oola.request_date BETWEEN xod.request_date_from
                                                AND xod.request_date_to
                      AND ooha.header_id = oola.header_id
                      AND ooha.open_flag = 'Y'
                      AND oola.open_flag = 'Y')));

        lv_error_msg    VARCHAR2 (4000) := NULL;
        lv_error_stat   VARCHAR2 (4) := 'S';
        lv_error_code   VARCHAR2 (4000) := NULL;
        ln_error_num    NUMBER;

        TYPE xxd_line_typ IS TABLE OF c_get_lines%ROWTYPE;

        v_ins_type      xxd_line_typ := xxd_line_typ ();
    BEGIN
        --  job will start inserting data into the caustom table

        UPDATE XXD_ONT_DTC_ROLLOVER_RUN_T
           SET program_start_time = SYSDATE, status = 'Started'
         WHERE GROUP_ID = p_group_id;


        COMMIT;

        OPEN c_get_lines;

        LOOP
            FETCH c_get_lines BULK COLLECT INTO v_ins_type LIMIT 1000;

            IF (v_ins_type.COUNT > 0)
            THEN
                BEGIN
                    FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                      SAVE EXCEPTIONS
                        INSERT INTO xxd_ont_order_modify_details_t (
                                        source_order_number,
                                        source_header_id,
                                        source_cust_account,
                                        source_sold_to_org_id,
                                        source_order_type,
                                        brand,
                                        source_line_id,
                                        source_ordered_item,
                                        source_line_number,
                                        source_cust_po_number,
                                        source_inventory_item_id,
                                        source_ordered_quantity,
                                        source_header_request_date,
                                        source_line_request_date,
                                        SOURCE_SCHEDULE_SHIP_DATE,
                                        SOURCE_LATEST_ACCEPTABLE_DATE,
                                        status,
                                        GROUP_ID,
                                        batch_id,
                                        org_id,
                                        parent_request_id,
                                        operation_mode,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        last_update_login,
                                        attribute10,
                                        record_id   -- Added as per CCR0010520
                                                 )
                                 VALUES (
                                            v_ins_type (i).order_number,
                                            v_ins_type (i).header_id,
                                            v_ins_type (i).account_number,
                                            v_ins_type (i).sold_to_org_id,
                                            v_ins_type (i).order_type,
                                            v_ins_type (i).brand,
                                            v_ins_type (i).line_id,
                                            v_ins_type (i).ordered_item,
                                            v_ins_type (i).line_number,
                                            v_ins_type (i).cust_po_number,
                                            v_ins_type (i).inventory_item_id,
                                            v_ins_type (i).ordered_quantity,
                                            v_ins_type (i).header_request_date,
                                            v_ins_type (i).line_request_date,
                                            v_ins_type (i).schedule_ship_date,
                                            v_ins_type (i).latest_acceptable_date,
                                            'I',
                                            p_group_id,
                                            NULL,
                                            v_ins_type (i).org_id,
                                            gn_request_id,
                                            p_operation_mode,
                                            SYSDATE,
                                            fnd_global.user_id,
                                            SYSDATE,
                                            fnd_global.user_id,
                                            fnd_global.login_id,
                                            v_ins_type (i).new_line_num,
                                            xxdo.XXD_ONT_ORDER_MODIFY_DETAILS_REC_S.NEXTVAL -- Added as per CCR0010520
                                                                                           );
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                        LOOP
                            lv_error_stat   := 'E';
                            ln_error_num    :=
                                SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                            lv_error_code   :=
                                SQLERRM (
                                    -1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                            lv_error_msg    :=
                                SUBSTR (
                                    (lv_error_msg || ' Error While Inserting into Table' || v_ins_type (ln_error_num).order_number || lv_error_code || ' #'),
                                    1,
                                    4000);
                        END LOOP;
                END;
            END IF;

            EXIT WHEN c_get_lines%NOTFOUND;
        END LOOP;

        CLOSE c_get_lines;

        UPDATE XXD_ONT_DTC_ROLLOVER_RUN_T
           SET program_start_time = SYSDATE, status = 'Extracted'
         WHERE GROUP_ID = p_group_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_prc;

    -- U means valuet is not correctly configured
    -- S SUCCESSFUL
    -- E error
    FUNCTION validate_request_date_to (p_in_request_date DATE)
        RETURN VARCHAR2
    IS
        l_end_date   DATE;
    BEGIN
        SELECT FND_DATE.CANONICAL_TO_DATE (ATTRIBUTE2) end_date
          INTO l_end_date
          FROM fnd_lookup_values
         WHERE     1 = 1
               AND lookup_type = 'XXDO_ROLLOVER_445_CALENDAR'
               AND enabled_flag = 'Y'
               AND language = USERENV ('LANG')
               -- tag is null for  us and ca;both 100 and 82 is same
               --tag is org id for emea
               AND (fnd_global.org_id IN (100, 82) AND tag IS NULL OR (fnd_global.org_id = tag))
               AND TRUNC (SYSDATE) BETWEEN FND_DATE.CANONICAL_TO_DATE (
                                               ATTRIBUTE1)
                                       AND FND_DATE.CANONICAL_TO_DATE (
                                               ATTRIBUTE2)
               AND SYSDATE BETWEEN start_date_active
                               AND NVL (end_date_active, SYSDATE + 1);

        IF p_in_request_date <= l_end_date
        THEN
            RETURN 'S';
        ELSE
            RETURN 'E';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'U';
    END validate_request_date_to;


    FUNCTION validate_request_date_from (p_in_request_date_from DATE)
        RETURN VARCHAR2
    IS
        l_start_date   DATE;
    BEGIN
        SELECT FND_DATE.CANONICAL_TO_DATE (ATTRIBUTE1) start_date
          INTO l_start_date
          FROM fnd_lookup_values
         WHERE     1 = 1
               AND lookup_type = 'XXDO_ROLLOVER_445_CALENDAR'
               AND enabled_flag = 'Y'
               AND language = USERENV ('LANG')
               -- tag is null for  us and ca;both 100 and 82 is same
               --tag is org id for emea
               AND (fnd_global.org_id IN (100, 82) AND tag IS NULL OR (fnd_global.org_id = tag))
               AND TRUNC (SYSDATE) BETWEEN FND_DATE.CANONICAL_TO_DATE (
                                               ATTRIBUTE1)
                                       AND FND_DATE.CANONICAL_TO_DATE (
                                               ATTRIBUTE2)
               AND SYSDATE BETWEEN start_date_active
                               AND NVL (end_date_active, SYSDATE + 1);

        -- RD shuld be with the 90 days from that month period start date
        IF p_in_request_date_from > l_start_date - 365
        THEN
            RETURN 'S';
        ELSE
            RETURN 'E';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'U';
    END validate_request_date_from;


    FUNCTION validate_access (p_in_org_id NUMBER)
        RETURN VARCHAR2
    IS
        l_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM fnd_lookup_values
         WHERE     1 = 1
               AND lookup_type = 'XXDO_ROLLOVER_ORDER_TYPES'
               AND enabled_flag = 'Y'
               AND language = USERENV ('LANG')
               AND tag = TO_NUMBER (p_in_org_id)
               AND SYSDATE BETWEEN start_date_active
                               AND NVL (end_date_active, SYSDATE + 1);

        IF l_count > 1
        THEN
            RETURN 'S';
        ELSE
            RETURN 'E';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'E';
    END validate_access;

    PROCEDURE MASTER_PRC (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_operation_mode IN VARCHAR2
                          , p_group_id IN NUMBER)
    AS
        ln_req_id              NUMBER;
        ln_record_count        NUMBER := 0;
        ln_batch_id            NUMBER := 0;
        lc_req_data            VARCHAR2 (10);
        lc_status              VARCHAR2 (10);
        v_req_data             VARCHAR2 (20);
        l_execution_mode       VARCHAR2 (240);
        L_PHASE                VARCHAR2 (50);
        L_STATUS               VARCHAR2 (50);
        L_DEV_PHASE            VARCHAR2 (50);
        L_DEV_STATUS           VARCHAR2 (50);
        L_MESSAGE              VARCHAR2 (50);
        Lb_REQ_RETURN_STATUS   BOOLEAN;
    BEGIN
        v_req_data   := fnd_conc_global.request_data;
        fnd_file.put_line (fnd_file.LOG, 'v_req_data : ' || v_req_data);

        -- If equals to 'MASTER', exit the program.
        IF v_req_data = 'MASTER'
        THEN
            -- ANOTHER ATTEMPT TO RETRY FOR ALL THE FAILED LINES in one batch

            ln_req_id   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXD_ONT_DTC_BULK_ROLLOVER_CHLD',
                    description   => NULL,
                    start_time    => NULL,
                    sub_request   => FALSE,
                    argument1     => p_operation_mode,
                    argument2     => p_group_id,
                    argument3     => NULL,
                    argument4     => 'E');

            COMMIT;


            IF ln_req_id > 0
            THEN
                LOOP
                    Lb_REQ_RETURN_STATUS   :=
                        FND_CONCURRENT.WAIT_FOR_REQUEST (
                            REQUEST_ID   => ln_req_id,
                            INTERVAL     => 60 --Number of seconds to wait between checks (i.e., number of seconds to sleep.)
                                              ,
                            MAX_WAIT     => 0 --The maximum time in seconds to wait for the request's completion.
                                             ,
                            PHASE        => L_PHASE,
                            STATUS       => L_STATUS,
                            DEV_PHASE    => L_DEV_PHASE,
                            DEV_STATUS   => L_DEV_STATUS,
                            MESSAGE      => L_MESSAGE);

                    IF (UPPER (L_PHASE) = 'COMPLETED' OR UPPER (L_STATUS) IN ('CANCELLED', 'ERROR', 'TERMINATED'))
                    THEN
                        RETURN;
                    END IF;
                END LOOP;
            END IF;
        END IF;

        DELETE xxd_ont_order_modify_details_t
         WHERE org_id = fnd_global.org_id AND creation_date < SYSDATE - 90;

        -- this will insert the data into the custom table
        -- do batching as per disticnt source header id
        -- create header with no line
        start_rollover (p_operation_mode, p_group_id);

        -- Submit Child Programs
        FOR i
            IN (  SELECT DISTINCT batch_id
                    FROM xxd_ont_order_modify_details_t
                   WHERE     1 = 1
                         AND batch_id IS NOT NULL
                         AND status = 'N'
                         AND GROUP_ID = p_group_id
                ORDER BY 1)
        LOOP
            ln_req_id   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXD_ONT_DTC_BULK_ROLLOVER_CHLD',
                    description   => NULL,
                    start_time    => NULL,
                    sub_request   => TRUE,
                    argument1     => p_operation_mode,
                    argument2     => p_group_id,
                    argument3     => i.batch_id,
                    argument4     => 'N');

            COMMIT;
        END LOOP;



        IF ln_req_id > 0
        THEN
            debug_msg ('Successfully Submitted Child Threads');
            fnd_conc_global.set_req_globals (conc_status    => 'PAUSED',
                                             request_data   => 'MASTER');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_errbuf    := SUBSTR (SQLERRM, 1, 2000);
            x_retcode   := 2;

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = error_message || x_errbuf, request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE GROUP_ID = p_group_id;

            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in MASTER_PRC : ' || x_errbuf);
    END master_prc;



    PROCEDURE child_prc (x_errbuf              OUT NOCOPY VARCHAR2,
                         x_retcode             OUT NOCOPY NUMBER,
                         p_operation_mode   IN            VARCHAR2,
                         p_group_id         IN            NUMBER,
                         p_batch_id         IN            NUMBER,
                         p_line_status      IN            VARCHAR2)
    AS
        lc_error_message   VARCHAR2 (4000);
        lc_debug_mode      VARCHAR2 (50);
    BEGIN
        add_lines (p_group_id, p_batch_id, p_line_status);
    --   cancel_lines(p_group_id);
    --   import_lines (p_group_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);
            x_retcode          := 2;
            x_errbuf           := lc_error_message;

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     status IN ('N')
                   AND batch_id = p_batch_id
                   AND operation_mode = p_operation_mode
                   AND GROUP_ID = p_group_id;


            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in CHILD_PRC = ' || lc_error_message);
    END child_prc;
END XXD_ONT_DTC_BULK_ROLLOVER_PKG;
/
