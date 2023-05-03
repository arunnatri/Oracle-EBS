--
-- XXD_ONT_GENESIS_PROC_ORD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_GENESIS_PROC_ORD_PKG"
AS
    -- ####################################################################################################################
    -- Package      : xxd_ont_genesis_proc_ord_pkg
    -- Design       : This package will be used to fetch values required for LOV
    --                in the genesis tool. This package will also  search
    --                for order details based on user entered data.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 28-Jun-2021    Infosys              1.0    Initial Version
    -- 23-Aug-2021    Jayarajan A K        1.1    Requirement Changes
    -- 25-Aug-2021    Infosys           1.2    New columns addition to capture updates done at UI
    -- 02-Sep-2021    Jayarajan A K        1.3    Modified fetch_trx_details to fetch newly added lines
    -- 03-Sep-2021    Manju Gopakumar      1.4    Modified fetch_trx_details to fetch records if only header updates
    -- 06-Sep-2021    Manju Gopakumar      1.5    Modified process_order_api_p to fetch new line details
    -- 10-Sep-2021    Manju Gopakumar      1.6    Modified insert_stg_data to intialize variables and fix new line creation issues
    -- 22-Sep-2021    Manju Gopakumar      2.0    Modified orig cancel date update to staging table
    -- 28-Oct-2021    Infosys              2.1    Modified to include fetch_cancel_comments procedure and accept cancel reasons and
    --           cancel comments as input
    --14-Feb-2022     Infosys              3.0 HOKA changes
    --01-Jul-2022  Infosys     3.1    Code fix to fetch correct header status in transaction history
    --29-Aug-2022     Infosys              3.2 Code change to insert line price and unit selling price to table
    --21-Sep-2022  Infosys              3.3 Code change to include filters in transaction history page
    --13-Jan-2023  Infosys              3.4 Code change to fix issue with same error repeating in other lines and
    --           seperating header api call
    -- #########################################################################################################################

    PROCEDURE write_to_table (msg VARCHAR2, app VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO custom.do_debug (created_by, application_id, debug_text,
                                     session_id, call_stack)
                 VALUES (NVL (fnd_global.user_id, -1),
                         app,
                         msg,
                         USERENV ('SESSIONID'),
                         SUBSTR (DBMS_UTILITY.format_call_stack, 1, 2000));

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END write_to_table;

    PROCEDURE fetch_ad_user_email (p_in_user_id IN VARCHAR2, p_out_user_name OUT VARCHAR2, p_out_display_name OUT VARCHAR2
                                   , p_out_email_id OUT VARCHAR2)
    IS
        lv_query          VARCHAR2 (2000);
        lv_query1         VARCHAR2 (2000);
        lv_user_name      VARCHAR2 (100);
        lv_display_name   VARCHAR2 (100);
        lv_email          VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT fu.user_name
              INTO lv_user_name
              FROM fnd_user fu
             WHERE     UPPER (fu.user_id) = UPPER (p_in_user_id)
                   AND NVL (fu.start_date, SYSDATE - 1) < SYSDATE
                   AND NVL (fu.end_date, SYSDATE + 1) > SYSDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_user_name   := NULL;
            WHEN TOO_MANY_ROWS
            THEN
                lv_user_name   := NULL;
            WHEN OTHERS
            THEN
                lv_user_name   := NULL;
        END;

        IF lv_user_name IS NOT NULL
        THEN
            lv_query   :=
                   'SELECT val  
						FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(sAMAccountName='
                || lv_user_name
                || '))'')) a  
					   WHERE UPPER(a.attr) = UPPER(''mail'')';

            EXECUTE IMMEDIATE lv_query
                INTO lv_email;

            lv_query1   :=
                   'SELECT val  
						FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(sAMAccountName='
                || lv_user_name
                || '))'')) a  
					   WHERE UPPER(a.attr) = UPPER(''displayName'')';

            EXECUTE IMMEDIATE lv_query1
                INTO lv_display_name;
        END IF;

        p_out_email_id       := lv_email;
        p_out_user_name      := lv_user_name;
        p_out_display_name   := lv_display_name;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lv_user_name   := '';
        WHEN OTHERS
        THEN
            lv_user_name   := '';
    END fetch_ad_user_email;

    PROCEDURE get_size_atp (p_in_style_color IN VARCHAR2, p_in_warehouse IN VARCHAR2, p_out_product OUT VARCHAR2, p_out_color_desc OUT VARCHAR2, p_out_product_no OUT VARCHAR2, p_out_unlim_sup_dt OUT DATE
                            , p_out_size_atp OUT SYS_REFCURSOR, p_out_size OUT SYS_REFCURSOR, p_out_err_msg OUT VARCHAR2)
    IS
        ln_inv_id              NUMBER;
        lv_demand_class_code   VARCHAR2 (100);
        ln_org_id              NUMBER;
    BEGIN
        write_to_table (
               'get_size_atp start'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_ont_genesis_proc_ord_pkg.get_size_atp');

        SELECT organization_id
          INTO ln_org_id
          FROM mtl_parameters
         WHERE organization_code = p_in_warehouse;

        SELECT DISTINCT msib.description product, mc.segment8 color, mc.attribute7 || '-' || mc.attribute8 product_no
          INTO p_out_product, p_out_color_desc, p_out_product_no
          FROM mtl_item_categories mic, mtl_category_sets mcs, mtl_categories_b mc,
               mtl_system_items_b msib
         WHERE     mic.category_set_id = mcs.category_set_id
               AND mic.category_id = mc.category_id
               AND mc.structure_id = mcs.structure_id
               AND mcs.category_set_name = 'Inventory'
               AND msib.inventory_item_id = mic.inventory_item_id
               AND msib.organization_id = mic.organization_id
               AND mc.disable_date IS NULL
               --start ver3.4
               AND msib.enabled_flag = 'Y'
               AND msib.inventory_item_status_code = 'Active'
               --end ver3.4
               AND mc.attribute7 || '-' || mc.attribute8 = p_in_style_color;

        SELECT MAX (xmaf.available_date)
          INTO p_out_unlim_sup_dt
          FROM xxdo.xxd_master_atp_full_t xmaf
         WHERE     SUBSTR (xmaf.sku,
                           1,
                             INSTR (xmaf.sku, '-', 1,
                                    2)
                           - 1) = p_in_style_color
               AND xmaf.application = 'HUBSOFT'
               AND xmaf.inv_organization_id = ln_org_id;

        OPEN p_out_size FOR
              SELECT SUBSTR (segment1,
                               INSTR (segment1, '-', 1,
                                      2)
                             + 1) item_size
                FROM mtl_system_items_b msib
               WHERE     SUBSTR (msib.segment1,
                                 1,
                                   INSTR (msib.segment1, '-', 1
                                          , 2)
                                 - 1) = p_in_style_color
                     AND organization_id = ln_org_id
                     AND SUBSTR (segment1,
                                   INSTR (segment1, '-', 1,
                                          2)
                                 + 1) NOT IN ('ALL')
                     --start ver3.4
                     AND msib.enabled_flag = 'Y'
                     AND msib.inventory_item_status_code = 'Active'
            --end ver3.4
            ORDER BY TO_NUMBER (msib.attribute10);

        OPEN p_out_size_atp FOR
              SELECT SUBSTR (segment1,
                               INSTR (segment1, '-', 1,
                                      2)
                             + 1) item_size,
                     xmaf.available_quantity,
                     xmaf.available_date
                FROM mtl_system_items_b msib, xxdo.xxd_master_atp_full_t xmaf
               WHERE     SUBSTR (msib.segment1,
                                 1,
                                   INSTR (msib.segment1, '-', 1
                                          , 2)
                                 - 1) = p_in_style_color
                     AND xmaf.inventory_item_id = msib.inventory_item_id
                     AND xmaf.inv_organization_id = msib.organization_id
                     AND msib.organization_id = ln_org_id
                     AND xmaf.application = 'HUBSOFT'
                     AND SUBSTR (msib.segment1,
                                   INSTR (msib.segment1, '-', 1,
                                          2)
                                 + 1) NOT IN ('ALL')
                     AND xmaf.available_quantity <> 10000000000
                     --start ver3.4
                     AND msib.enabled_flag = 'Y'
                     AND msib.inventory_item_status_code = 'Active'
            --end ver3.4
            ORDER BY xmaf.available_date, TO_NUMBER (msib.attribute10);

        write_to_table (
            'get_size_atp end' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_ont_genesis_proc_ord_pkg.get_size_atp');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_err_msg   :=
                SUBSTR (
                    'unexpected Error in get_size_atp procedure' || SQLERRM,
                    1,
                    4000);
    END get_size_atp;

    PROCEDURE insert_stg_data (p_in_user_id IN NUMBER, p_in_batch_id IN NUMBER, p_input_data IN gen_tbl_type
                               , p_out_err_msg OUT VARCHAR2)
    IS
        lv_account_number       hz_cust_accounts.account_number%TYPE;
        lv_style                VARCHAR2 (50);
        lv_color                VARCHAR2 (10);
        lv_brand                VARCHAR2 (50);
        lv_channel              VARCHAR2 (50);
        lv_channel_code         VARCHAR2 (30);
        lv_size                 VARCHAR2 (30);
        lv_item_name            VARCHAR2 (2000);
        lv_err_msg              VARCHAR2 (2000);
        lv_order_num            VARCHAR2 (50);
        lv_cust_po_num          VARCHAR2 (50);
        lv_b2b_num              VARCHAR2 (50);
        lv_warehouse            VARCHAR2 (50);
        lv_old_hold_status      VARCHAR2 (10);
        lv_user_name            VARCHAR2 (50);
        lv_display_name         VARCHAR2 (50);
        lv_email_id             VARCHAR2 (50);
        lv_orig_sys_ln_ref      VARCHAR2 (100);                         --v1.6
        ln_prev_line_id         NUMBER;
        ln_prev_line_no         VARCHAR2 (50);                          --v2.1
        ln_sold_to_org_id       NUMBER;
        ln_order_number         NUMBER;
        ln_line_number          NUMBER;
        ln_exists               NUMBER;
        ln_order_source_id      NUMBER;
        ln_quantity             NUMBER;
        ln_count                NUMBER := 0;
        ln_exists_h             NUMBER := 0;
        ln_org_id               NUMBER;
        ln_user_id              NUMBER;
        ln_salesrep_id          NUMBER;
        ln_ship_from_org_id     NUMBER;
        ln_orig_qty             NUMBER;
        ln_inv_id               NUMBER;
        ln_header_id            NUMBER := 0;
        ld_schedule_ship_date   DATE;
        ld_hdr_req_date         DATE;
        ld_hdr_cancel_date      DATE;
        ld_line_req_date        DATE;
        ld_line_cancel_date     DATE;
        ld_latest_accept_date   DATE;                                   --v2.0
    BEGIN
        ln_user_id   := p_in_user_id;
        write_to_table (
               'in insert_stg_data batchid: '
            || p_in_batch_id
            || '. user_id:'
            || p_in_user_id,
            'xxd_ont_genesis_proc_ord_pkg.insert_stg_data');

        BEGIN
            SELECT 1
              INTO ln_exists_h
              FROM xxdo.xxd_ont_genesis_hdr_stg_t
             WHERE batch_id = p_in_batch_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_exists_h   := 0;
            WHEN OTHERS
            THEN
                ln_exists_h   := 0;
        END;

        IF ln_exists_h = 0
        THEN
            BEGIN
                SELECT flv1.attribute1
                  INTO ln_salesrep_id
                  FROM fnd_lookup_values flv1
                 WHERE     1 = 1
                       AND flv1.lookup_type = 'XXD_ONT_GENESIS_SALESREP_LKP'
                       AND flv1.enabled_flag = 'Y'
                       AND flv1.LANGUAGE = USERENV ('LANG')
                       AND flv1.attribute4 = ln_user_id
                       --Start v2.1
                       AND SYSDATE BETWEEN NVL (flv1.start_date_active,
                                                SYSDATE)
                                       AND NVL (flv1.end_date_active,
                                                SYSDATE + 1)
                       --End v2.1
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_salesrep_id   := NULL;
            END;

            fetch_ad_user_email (p_in_user_id => ln_user_id, p_out_user_name => lv_user_name, p_out_display_name => lv_display_name
                                 , p_out_email_id => lv_email_id);


            write_to_table ('line count ' || p_input_data.COUNT,
                            'xxd_ont_genesis_proc_ord_pkg.insert_stg_data');

            FOR i IN 1 .. p_input_data.COUNT
            LOOP
                --v1.6 start
                lv_item_name            := '';
                ln_orig_qty             := NULL;
                ld_line_req_date        := '';
                ld_line_cancel_date     := '';
                ld_latest_accept_date   := '';                          --v2.0
                ln_inv_id               := NULL;
                ln_ship_from_org_id     := NULL;
                ln_org_id               := NULL;
                lv_order_num            := '';
                lv_cust_po_num          := '';
                lv_b2b_num              := '';
                ld_hdr_req_date         := '';
                ld_hdr_cancel_date      := '';
                lv_brand                := '';
                ln_sold_to_org_id       := NULL;
                lv_warehouse            := '';
                lv_account_number       := '';
                lv_old_hold_status      := '';
                ln_exists               := NULL;
                ln_prev_line_id         := NULL;
                ln_prev_line_no         := NULL;
                lv_orig_sys_ln_ref      := '';

                IF ln_header_id <> p_input_data (i).attribute1
                THEN
                    ln_count   := 0;
                END IF;

                ln_header_id            := p_input_data (i).attribute1;

                --v1.6 end
                write_to_table (
                    'in loop ' || p_input_data (i).attribute1,
                    'xxd_ont_genesis_proc_ord_pkg.insert_stg_data');

                BEGIN
                    SELECT ooha.org_id, ooha.order_number, ooha.cust_po_number,
                           ooha.orig_sys_document_ref, ooha.request_date, --Start changes v2.0
                                                                          --ooha.attribute3,
                                                                          TO_DATE (ooha.attribute1, 'YYYY/MM/DD HH24:MI:SS'),
                           --End changes v2.0
                           ooha.attribute5, ooha.sold_to_org_id
                      INTO ln_org_id, lv_order_num, lv_cust_po_num, lv_b2b_num,
                                    ld_hdr_req_date, ld_hdr_cancel_date, lv_brand,
                                    ln_sold_to_org_id
                      FROM oe_order_headers_all ooha
                     WHERE header_id = p_input_data (i).attribute1;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_org_id   := NULL;
                    WHEN OTHERS
                    THEN
                        ln_org_id   := NULL;
                END;

                write_to_table (
                    'lv_order_num  ' || lv_order_num,
                    'xxd_ont_genesis_proc_ord_pkg.insert_stg_data');
                write_to_table (
                    'ld_hdr_cancel_date  ' || ld_hdr_cancel_date,
                    'xxd_ont_genesis_proc_ord_pkg.insert_stg_data');

                --fetch order line details
                IF p_input_data (i).attribute21 IS NOT NULL     --ordered_item
                THEN
                    IF p_input_data (i).attribute13 IS NOT NULL      --line_id
                    THEN
                        write_to_table (
                               'ld_line_cancel_date first '
                            || ld_line_cancel_date,
                            'xxd_ont_genesis_proc_ord_pkg.insert_stg_data');

                        BEGIN
                            SELECT oola.ordered_item, oola.ordered_quantity, oola.request_date,
                                   --Start changes v2.0
                                   --oola.attribute3,
                                   TO_DATE (oola.attribute1, 'YYYY/MM/DD HH24:MI:SS'), oola.latest_acceptable_date, --End changes v2.0
                                                                                                                    oola.inventory_item_id,
                                   oola.ship_from_org_id
                              INTO lv_item_name, ln_orig_qty, ld_line_req_date, ld_line_cancel_date,
                                               --Start changes v2.0
                                               ld_latest_accept_date, --End changes v2.0
                                                                      ln_inv_id, ln_ship_from_org_id
                              FROM oe_order_lines_all oola
                             WHERE     oola.line_id =
                                       p_input_data (i).attribute13
                                   AND oola.header_id =
                                       p_input_data (i).attribute1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_orig_qty             := NULL;
                                lv_item_name            := NULL;
                                ld_line_req_date        := NULL;
                                ld_line_cancel_date     := NULL;
                                ln_inv_id               := NULL;
                                ln_ship_from_org_id     := NULL;
                                ld_latest_accept_date   := NULL;        --v2.0
                        END;

                        write_to_table (
                               'ld_line_cancel_date second '
                            || ld_line_cancel_date,
                            'xxd_ont_genesis_proc_ord_pkg.insert_stg_data');
                    ELSE
                        BEGIN
                            SELECT inventory_item_id
                              INTO ln_inv_id
                              FROM mtl_system_items_b
                             WHERE     segment1 =
                                       p_input_data (i).attribute21
                                   --start ver3.4
                                   AND enabled_flag = 'Y'
                                   AND inventory_item_status_code = 'Active'
                                   --end ver3.4
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_inv_id   := NULL;
                        END;
                    END IF;

                    BEGIN
                        SELECT organization_code
                          INTO lv_warehouse
                          FROM mtl_parameters
                         WHERE organization_id = ln_ship_from_org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_warehouse   := '';
                    END;
                END IF;

                --fetch account number
                BEGIN
                    SELECT hca.account_number
                      INTO lv_account_number
                      FROM hz_cust_accounts hca
                     WHERE hca.cust_account_id = ln_sold_to_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_account_number   := NULL;
                END;

                BEGIN
                    SELECT DECODE (COUNT (1), 0, 'N', 'Y')
                      INTO lv_old_hold_status
                      FROM oe_order_holds_all hold, oe_hold_sources_all ohsa
                     WHERE     hold.header_id = p_input_data (i).attribute1
                           AND hold.released_flag = 'N'
                           AND hold.hold_source_id = ohsa.hold_source_id
                           AND ohsa.released_flag = 'N'
                           AND ohsa.hold_release_id IS NULL
                           --Start changes v2.0
                           --and ohsa.hold_id = 1002
                           AND ohsa.hold_id = 1005
                           --End changes v2.0
                           AND ohsa.hold_entity_code = 'O';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_old_hold_status   := 'N';
                END;

                --v1.6 START
                IF p_input_data (i).attribute22 = 'A'
                THEN
                    ln_count   := ln_count + 1;
                    --start ver 3.0
                    --start v2.1
                    /*SELECT MAX(line_number)||'.'||MAX(shipment_number)
             INTO ln_prev_line_no
             FROM oe_order_lines_all
            WHERE header_id =p_input_data(i).attribute1;*/
                    --End v2.1
                    /* select line_id into ln_prev_line_id
           from oe_order_lines_all where header_id =p_input_data(i).attribute1
           and line_number||'.'||shipment_number =ln_prev_line_no;*/
                    --ver2.1

                    /*write_to_table ('ln_prev_line_id '||ln_prev_line_id,
                'xxd_ont_genesis_proc_ord_pkg.insert_stg_data');

           lv_orig_sys_ln_ref:='GENESIS'||'-'||ln_prev_line_id||'-'||ln_count;*/
                    lv_orig_sys_ln_ref   :=
                           'GENESIS'
                        || '-'
                        || p_in_batch_id
                        || '-'
                        || p_input_data (i).attribute1
                        || '-'
                        || ln_count;
                    --End ver 3.0
                    write_to_table (
                        'lv_orig_sys_ln_ref ' || lv_orig_sys_ln_ref,
                        'xxd_ont_genesis_proc_ord_pkg.insert_stg_data');
                END IF;

                --v1.6 end

                BEGIN
                    SELECT 1
                      INTO ln_exists
                      FROM xxdo.xxd_ont_genesis_hdr_stg_t
                     WHERE batch_id = p_in_batch_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_exists   := 0;
                    WHEN OTHERS
                    THEN
                        ln_exists   := 0;
                END;

                write_to_table (
                    'Before insert ',
                    'xxd_ont_genesis_proc_ord_pkg.insert_stg_data');

                IF ln_exists = 0
                THEN
                    INSERT INTO xxdo.xxd_ont_genesis_hdr_stg_t (
                                    batch_id,
                                    org_id,
                                    brand,
                                    warehouse,
                                    status,
                                    salesrep_id,
                                    created_by,
                                    last_updated_by,
                                    creation_date,
                                    last_update_date)
                         VALUES (p_in_batch_id, ln_org_id, lv_brand,
                                 lv_warehouse, 'NEW', ln_salesrep_id,
                                 ln_user_id, ln_user_id, SYSDATE,
                                 SYSDATE);
                END IF;

                INSERT INTO xxdo.xxd_ont_genesis_dtls_stg_t (
                                batch_id,
                                org_id,
                                header_id,
                                line_id,
                                inventory_item_id,
                                salesrep_id,
                                sales_order_num,
                                db2b_order_num,
                                cust_po_num,
                                item_number,
                                account_number,
                                brand,
                                warehouse,
                                hdr_action,
                                --Start changes v1.2
                                hdr_updates,
                                --End changes v1.2
                                --Start changes v2.1
                                hdr_cancel_reason,
                                hdr_cancel_comment,
                                apprvl_reqd,
                                --End changes v2.1
                                orig_hold_status,
                                new_hold_status,
                                orig_hdr_req_date,
                                new_hdr_req_date,
                                orig_hdr_cancel_date,
                                new_hdr_cancel_date,
                                orig_line_req_date,
                                new_line_req_date,
                                orig_line_cancel_date,
                                new_line_cancel_date,
                                --Start changes v2.0
                                orig_latest_accept_date,
                                new_latest_accept_date,
                                --End changes v2.0
                                lne_action,
                                --Start changes v1.2
                                line_updates,
                                --End changes v1.2
                                --v1.6 START
                                orig_sys_line_ref,
                                --v1.6 end
                                --Start changes v2.1
                                line_reason,
                                line_comment,
                                --End changes v2.1
                                --Start changes v3.2
                                line_price,
                                unit_selling_price,
                                --End changes v3.2
                                orig_qty,
                                new_qty,
                                status,
                                created_by,
                                last_updated_by,
                                creation_date,
                                last_update_date,
                                error_message)
                     VALUES (p_in_batch_id, ln_org_id, p_input_data (i).attribute1, p_input_data (i).attribute13, ln_inv_id, ln_salesrep_id, lv_order_num, lv_b2b_num, lv_cust_po_num, NVL (p_input_data (i).attribute21, lv_item_name), lv_account_number, lv_brand, lv_warehouse, p_input_data (i).attribute10, --Start changes v1.2
                                                                                                                                                                                                                                                                                                                  p_input_data (i).attribute12, --Start changes v1.2
                                                                                                                                                                                                                                                                                                                                                --Start changes v2.1
                                                                                                                                                                                                                                                                                                                                                p_input_data (i).attribute11, p_input_data (i).attribute25, p_input_data (i).attribute27, --End changes v2.1
                                                                                                                                                                                                                                                                                                                                                                                                                                          lv_old_hold_status, p_input_data (i).attribute9, ld_hdr_req_date, p_input_data (i).attribute5, ld_hdr_cancel_date, p_input_data (i).attribute6, ld_line_req_date, p_input_data (i).attribute17, ld_line_cancel_date, p_input_data (i).attribute18, --Start changes v2.0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             ld_latest_accept_date, p_input_data (i).attribute19, --End changes v2.0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  p_input_data (i).attribute22, --Start changes v1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                p_input_data (i).attribute24, --Start changes v1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              --v1.6 START
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              lv_orig_sys_ln_ref, --v1.6 end
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  --Start changes v1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  --Start changes v2.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  p_input_data (i).attribute23, p_input_data (i).attribute26, --End changes v2.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              --Start changes v3.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              p_input_data (i).attribute15, p_input_data (i).attribute16, --End changes v3.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          ln_orig_qty, p_input_data (i).attribute14, 'NEW', ln_user_id, ln_user_id
                             , SYSDATE, SYSDATE, NULL);

                COMMIT;
            END LOOP;

            write_to_table ('calling schedule_order ',
                            'xxd_ont_genesis_proc_ord_pkg.insert_stg_data');

            schedule_order (p_in_batch_id, p_out_err_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_err_msg   :=
                SUBSTR (
                       p_out_err_msg
                    || '-'
                    || 'Error while inserting records to table xxd_ont_genesis_dtls_stg_t'
                    || SQLERRM,
                    1,
                    4000);

            write_to_table (
                SUBSTR (
                       p_out_err_msg
                    || '-'
                    || 'Error while inserting records to table xxd_ont_genesis_dtls_stg_t'
                    || SQLERRM,
                    1,
                    4000),
                'xxd_ont_genesis_proc_ord_pkg.insert_stg_data');
    END insert_stg_data;

    PROCEDURE process_order_api_p (p_in_batch_id IN NUMBER)
    IS
        lv_plan_run                VARCHAR2 (10);
        lv_batch_commit            VARCHAR2 (5) := 'Y';
        lv_err_msg                 VARCHAR2 (2000);
        lv_err_flag                VARCHAR2 (5);
        lc_error_message           VARCHAR2 (2000);
        l_return_status            VARCHAR2 (1000);
        l_msg_data                 VARCHAR2 (1000);
        l_message_data             VARCHAR2 (2000);
        lv_hold_entity_code        VARCHAR2 (10) DEFAULT 'O';
        lv_cancel_date             VARCHAR2 (100);
        lv_username                VARCHAR2 (100);
        lc_lock_status             VARCHAR2 (1) := 'N';
        lc_flow_status_line        VARCHAR2 (60) := NULL;
        lv_display_name            VARCHAR2 (50);
        lv_time_stamp              VARCHAR2 (50);
        lv_email_id                VARCHAR2 (50);
        ln_order_qty               NUMBER := 0;
        ln_line_id                 NUMBER;
        ln_org_id                  NUMBER;
        ln_resp_id                 NUMBER;
        ln_resp_appl_id            NUMBER;
        ln_header_id               NUMBER;
        ln_api_version_number      NUMBER := 1;
        l_line_tbl_index           NUMBER := 0;
        l_msg_count                NUMBER;
        l_msg_index_out            NUMBER (10);
        l_row_num_err              NUMBER := 0;
        --Start changes v2.0
        --ln_hold_id                NUMBER := 1002;
        ln_hold_id                 NUMBER := 1005;
        --End changes v2.0
        ln_hold_check_cnt          NUMBER := 0;
        ln_cnt                     NUMBER;
        ln_line_count              NUMBER;
        ln_status_succcount        NUMBER;
        ln_status_errcount         NUMBER;
        ln_status_newcount         NUMBER;
        --Start changes v2.1
        ln_cancelhold_id           NUMBER := 1001;
        ln_hold_count              NUMBER := 0;
        ln_dec_qty_count           NUMBER := 0;
        ln_line_actn_count         NUMBER := 0;
        --End changes v2.1
        ld_line_req_date           DATE;
        ld_hdr_req_date            DATE;
        ld_time_stamp              TIMESTAMP;
        l_line_tbl                 oe_order_pub.line_tbl_type;
        l_header_rec               oe_order_pub.header_rec_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
        l_header_rec_x             oe_order_pub.header_rec_type;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        l_line_tbl_x               oe_order_pub.line_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        lv_exception               EXCEPTION;
        lv_loop_exception          EXCEPTION;
        lv_lock_exception          EXCEPTION;



        --start ver3.4
        lv_hdr_called              VARCHAR2 (1);
        lv_retn_code               VARCHAR2 (1) := 'N';
        lv_cncl_rsn_miss           VARCHAR2 (1) := 'N';                --manju
        lv_ret_code                VARCHAR2 (1) := 'N';

        --end ver3.4

        CURSOR fetch_ord_hdr_cur IS
              SELECT DISTINCT xgd.header_id, xgd.org_id, xgd.hdr_action,
                              xgd.new_hold_status, xgd.new_hdr_req_date, xgd.new_hdr_cancel_date,
                              xgd.created_by, --Start changes v2.1
                                              --xgd.lne_action
                                              xgd.apprvl_reqd, xgd.hdr_cancel_reason,
                              xgd.hdr_cancel_comment
                --End changes v2.1
                FROM xxdo.xxd_ont_genesis_dtls_stg_t xgd
               WHERE xgd.batch_id = p_in_batch_id
            ORDER BY header_id;

        CURSOR fetch_ord_lines_cur (p_header_id NUMBER)
        IS
              SELECT xgd.header_id, xgd.line_id, xgd.lne_action,
                     xgd.new_qty, xgd.item_number, xgd.inventory_item_id,
                     xgd.new_line_cancel_date, xgd.new_line_req_date, --Start changes v2.0
                                                                      xgd.new_latest_accept_date,
                     --End changes v2.0
                     xgd.salesrep_id, --v1.6 start
                                      xgd.orig_sys_line_ref--v1.6 end
                                                           --Start changes v2.1
                                                           , orig_qty,
                     line_reason, line_comment
                --End changes v2.1
                FROM xxdo.xxd_ont_genesis_dtls_stg_t xgd
               WHERE     xgd.batch_id = p_in_batch_id
                     AND xgd.header_id = p_header_id
                     AND xgd.item_number IS NOT NULL
            ORDER BY line_id;
    BEGIN
        -- Verify all source orders and lock them
        write_to_table ('in process_order_api_p ' || p_in_batch_id,
                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

        FOR fetch_ord_hdr_rec IN fetch_ord_hdr_cur
        LOOP
            ln_cnt                   := 0;
            l_line_tbl_index         := 0;
            ln_dec_qty_count         := 0;                              --v2.1
            ln_line_actn_count       := 0;                              --v2.1
            l_action_request_tbl.DELETE;
            --start ver3.4
            lv_hdr_called            := 'N';
            --end ver3.4
            write_to_table (
                'in process_order_api_p header loop ' || fetch_ord_hdr_rec.header_id,
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
            fetch_ad_user_email (p_in_user_id => fetch_ord_hdr_rec.created_by, p_out_user_name => lv_username, p_out_display_name => lv_display_name
                                 , p_out_email_id => lv_email_id);

            --start ver 3.0
            ln_org_id                := fetch_ord_hdr_rec.org_id;

            --end ver 3.0
            BEGIN
                --Getting the responsibility and application to initialize and set the context to reschedule order lines
                --Making sure that the initialization is set for proper OM responsibility
                SELECT frv.responsibility_id, frv.application_id
                  INTO ln_resp_id, ln_resp_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                       apps.hr_organization_units hou
                 WHERE     1 = 1
                       AND hou.organization_id = ln_org_id     --start ver 3.0
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
                    ln_resp_id        := NULL;
                    ln_resp_appl_id   := NULL;
            END;

            -- INITIALIZE ENVIRONMENT
            --start ver 3.0
            --ln_org_id := fetch_ord_hdr_rec.org_id;
            --end ver 3.0
            fnd_global.apps_initialize (
                user_id        => fetch_ord_hdr_rec.created_by,
                resp_id        => ln_resp_id,
                resp_appl_id   => ln_resp_appl_id);
            mo_global.set_policy_context ('S', ln_org_id);
            mo_global.init ('ONT');


            write_to_table (
                'in process_order_api_p after apps initialize ',
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            BEGIN
                SELECT request_date, org_id
                  INTO ld_hdr_req_date, ln_org_id
                  FROM oe_order_headers_all
                 WHERE header_id = fetch_ord_hdr_rec.header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ld_hdr_req_date   := '';
                    ln_org_id         := NULL;
            END;

            write_to_table (
                'in process_order_api_p checking hold ' || fetch_ord_hdr_rec.new_hold_status,
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            IF        fetch_ord_hdr_rec.hdr_action = 'U'
                  AND fetch_ord_hdr_rec.new_hold_status = 1
               OR fetch_ord_hdr_rec.new_hold_status = 0
            THEN
                write_to_table (
                    'in process_order_api_p hold ',
                    'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                --This is to apply hold an order header or line
                ln_cnt                                      := ln_cnt + 1;
                l_action_request_tbl (ln_cnt)               :=
                    oe_order_pub.g_miss_request_rec;
                l_action_request_tbl (ln_cnt).entity_id     :=
                    fetch_ord_hdr_rec.header_id;
                l_action_request_tbl (ln_cnt).entity_code   :=
                    lv_hold_entity_code;

                l_action_request_tbl (ln_cnt).param1        := ln_hold_id; -- hold_id
                l_action_request_tbl (ln_cnt).param2        := 'O';
                -- indicator that it is an order hold
                l_action_request_tbl (ln_cnt).param3        :=
                    fetch_ord_hdr_rec.header_id;

                -- Header or LINE ID of the order
                IF fetch_ord_hdr_rec.new_hold_status = 1
                THEN
                    l_action_request_tbl (ln_cnt).request_type   :=
                        oe_globals.g_apply_hold;
                    l_action_request_tbl (ln_cnt).param4   := 'Apply Hold'; -- hold comments
                ELSIF fetch_ord_hdr_rec.new_hold_status = 0
                THEN
                    l_action_request_tbl (ln_cnt).request_type   :=
                        oe_globals.g_release_hold;
                    l_action_request_tbl (ln_cnt).param4   :=
                        'SALESREP_HOLD_RELEASE';              -- hold comments
                    l_action_request_tbl (ln_cnt).param5   :=
                           'Sales order is released by '
                        || lv_username
                        || ' on '
                        || SYSDATE;
                END IF;
            END IF;

            -- INITIALIZE HEADER RECORD
            write_to_table (
                'in process_order_api_p header records ',
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
            l_header_rec             := oe_order_pub.g_miss_header_rec;

            l_header_rec.operation   := oe_globals.g_opr_update;
            l_header_rec.header_id   := fetch_ord_hdr_rec.header_id;
            write_to_table (
                'update line new_hdr_cancel_date' || fetch_ord_hdr_rec.new_hdr_cancel_date,
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            IF     fetch_ord_hdr_rec.new_hdr_cancel_date IS NOT NULL
               AND fetch_ord_hdr_rec.new_hdr_cancel_date >= SYSDATE     --v2.1
            THEN
                l_header_rec.attribute1                     :=
                    TO_CHAR (TO_DATE (fetch_ord_hdr_rec.new_hdr_cancel_date),
                             'YYYY/MM/DD HH:MI:SS');

                --Start changes v2.1
                SELECT DECODE (COUNT (1), 0, 0, 1)
                  INTO ln_hold_count
                  FROM oe_order_holds_all hold, oe_hold_sources_all ohsa
                 WHERE     hold.header_id = fetch_ord_hdr_rec.header_id
                       AND hold.released_flag = 'N'
                       AND hold.hold_source_id = ohsa.hold_source_id
                       AND ohsa.released_flag = 'N'
                       AND ohsa.hold_release_id IS NULL
                       AND ohsa.hold_id = 1001
                       AND ohsa.hold_entity_code = 'O';

                ln_cnt                                      := ln_cnt + 1;
                l_action_request_tbl (ln_cnt)               :=
                    oe_order_pub.g_miss_request_rec;
                l_action_request_tbl (ln_cnt).entity_id     :=
                    fetch_ord_hdr_rec.header_id;
                l_action_request_tbl (ln_cnt).entity_code   :=
                    lv_hold_entity_code;

                l_action_request_tbl (ln_cnt).param1        :=
                    ln_cancelhold_id;                               -- hold_id
                l_action_request_tbl (ln_cnt).param2        := 'O';
                -- indicator that it is an order hold
                l_action_request_tbl (ln_cnt).param3        :=
                    fetch_ord_hdr_rec.header_id;

                IF ln_hold_count = 1
                THEN
                    l_action_request_tbl (ln_cnt).request_type   :=
                        oe_globals.g_release_hold;
                    l_action_request_tbl (ln_cnt).param4   :=
                        'SALESREP_HOLD_RELEASE';      -- need new comment name
                    l_action_request_tbl (ln_cnt).param5   :=
                        'Released by Sales Rep in Genesis by update to Cancel Date';
                END IF;
            --End changes v2.1
            END IF;

            write_to_table (
                'update line new_hdr_req_date' || fetch_ord_hdr_rec.new_hdr_req_date,
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            IF fetch_ord_hdr_rec.new_hdr_req_date IS NOT NULL
            THEN
                l_header_rec.request_date   :=
                    fetch_ord_hdr_rec.new_hdr_req_date;
            END IF;

            --start ver3.4
            hdr_rec.hdr_action       := fetch_ord_hdr_rec.hdr_action;
            hdr_rec.hdr_cancel_reason   :=
                fetch_ord_hdr_rec.hdr_cancel_reason;
            write_to_table (
                'call validate_header ',
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            validate_header (retcode      => lv_ret_code,
                             errbuff      => lv_err_msg,
                             p_hdr_attr   => hdr_rec);
            write_to_table (
                'call validate_header lv_ret_code' || lv_ret_code,
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            IF lv_ret_code = 'Y'
            THEN
                --end ver3.4

                --Start changes v2.1
                write_to_table (
                    'hdr_action' || fetch_ord_hdr_rec.hdr_action,
                    'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                l_line_tbl.DELETE;

                IF     NVL (fetch_ord_hdr_rec.apprvl_reqd, 'N') = 'N'
                   AND fetch_ord_hdr_rec.hdr_action = 'C'
                   AND fetch_ord_hdr_rec.hdr_cancel_reason IS NOT NULL
                THEN
                    l_header_rec.cancelled_flag   := 'Y';
                    l_header_rec.change_reason    :=
                        fetch_ord_hdr_rec.hdr_cancel_reason;
                    l_header_rec.change_comments   :=
                        fetch_ord_hdr_rec.hdr_cancel_comment;

                    write_to_table (
                        'cancelled_flag and reason passed to api for header',
                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                    --END IF;
                    --l_line_tbl.DELETE;

                    write_to_table (
                        'in process_order_api_p before line loop ',
                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                --IF NVL(fetch_ord_hdr_rec.apprvl_reqd,'N') = 'N' AND fetch_ord_hdr_rec.hdr_action = 'C' AND fetch_ord_hdr_rec.hdr_cancel_reason IS NOT NULL THEN
                --NULL;
                ELSE
                    -- IF (fetch_ord_hdr_rec.apprvl_reqd = 'N' AND fetch_ord_hdr_rec.hdr_action = 'U' AND fetch_ord_hdr_rec.hdr_cancel_reason IS NULL)  OR fetch_ord_hdr_rec.apprvl_reqd = 'Y' THEN
                    --IF (fetch_ord_hdr_rec.apprvl_reqd = 'N' AND fetch_ord_hdr_rec.hdr_action = 'U'
                    --AND (ln_line_actn_count >0 OR ln_dec_qty_count >0)) OR fetch_ord_hdr_rec.apprvl_reqd = 'Y' THEN
                    SELECT COUNT (1)
                      INTO ln_dec_qty_count
                      FROM xxdo.xxd_ont_genesis_dtls_stg_t
                     WHERE     header_id = fetch_ord_hdr_rec.header_id
                           AND orig_qty > new_qty
                           AND new_qty IS NOT NULL
                           AND batch_id = p_in_batch_id;

                    SELECT COUNT (1)
                      INTO ln_line_actn_count
                      FROM xxdo.xxd_ont_genesis_dtls_stg_t
                     WHERE     header_id = fetch_ord_hdr_rec.header_id
                           AND lne_action = 'C'
                           AND batch_id = p_in_batch_id;

                    --End changes v2.1

                    FOR fetch_ord_lines_rec
                        IN fetch_ord_lines_cur (fetch_ord_hdr_rec.header_id)
                    LOOP
                        write_to_table (
                               'in process_order_api_p in line loop '
                            || fetch_ord_lines_rec.line_id,
                            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                        --start ver3.4
                        lv_ret_code           := '';
                        lv_err_msg            := '';
                        line_rec.lne_action   :=
                            fetch_ord_lines_rec.lne_action;
                        line_rec.new_qty      := fetch_ord_lines_rec.new_qty;
                        line_rec.orig_qty     := fetch_ord_lines_rec.orig_qty;
                        line_rec.line_reason   :=
                            fetch_ord_lines_rec.line_reason;
                        write_to_table (
                            'call validate_line',
                            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                        validate_line (retcode       => lv_ret_code,
                                       errbuff       => lv_err_msg,
                                       p_line_attr   => line_rec);
                        write_to_table (
                            'call validate_line lv_ret_code' || lv_ret_code,
                            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                        IF lv_ret_code = 'Y'
                        THEN
                            --end ver3.4
                            lc_flow_status_line   := NULL;
                            ln_order_qty          := 0;

                            IF fetch_ord_lines_rec.line_id IS NOT NULL
                            THEN
                                SELECT flow_status_code, ordered_quantity, request_date
                                  INTO lc_flow_status_line, ln_order_qty, ld_line_req_date
                                  FROM oe_order_lines_all
                                 WHERE line_id = fetch_ord_lines_rec.line_id;
                            END IF;

                            IF NVL (lc_flow_status_line, 'XX') NOT IN
                                   ('CANCELLED', 'CLOSED', 'SHIPPED')
                            THEN                          --do we need this???
                                -- INITIALIZE LINE RECORD
                                write_to_table (
                                    'in line record ',
                                    'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                l_line_tbl_index   := l_line_tbl_index + 1;
                                l_line_tbl (l_line_tbl_index)   :=
                                    oe_order_pub.g_miss_line_rec;

                                IF     fetch_ord_lines_rec.line_id IS NULL
                                   AND fetch_ord_lines_rec.inventory_item_id
                                           IS NOT NULL
                                   AND fetch_ord_lines_rec.lne_action = 'A' --ver2.1 update, added AND condn
                                THEN
                                    write_to_table (
                                        'in line record new line creation',
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                    l_line_tbl (l_line_tbl_index).operation   :=
                                        oe_globals.g_opr_create;
                                    l_line_tbl (l_line_tbl_index).header_id   :=
                                        fetch_ord_lines_rec.header_id;
                                    --v1.6 start
                                    l_line_tbl (l_line_tbl_index).orig_sys_line_ref   :=
                                        fetch_ord_lines_rec.orig_sys_line_ref;
                                    --v1.6 end
                                    l_line_tbl (l_line_tbl_index).inventory_item_id   :=
                                        fetch_ord_lines_rec.inventory_item_id;
                                    l_line_tbl (l_line_tbl_index).ordered_quantity   :=
                                        fetch_ord_lines_rec.new_qty;
                                    l_line_tbl (l_line_tbl_index).request_date   :=
                                        fetch_ord_lines_rec.new_line_req_date;
                                    l_line_tbl (l_line_tbl_index).salesrep_id   :=
                                        fetch_ord_lines_rec.salesrep_id;
                                    write_to_table (
                                           'new line creation hdr id'
                                        || l_line_tbl (l_line_tbl_index).header_id,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                    write_to_table (
                                           'new line creation inventory_item_id'
                                        || l_line_tbl (l_line_tbl_index).inventory_item_id,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                    write_to_table (
                                           'new line creation ordered_quantity'
                                        || l_line_tbl (l_line_tbl_index).ordered_quantity,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                    write_to_table (
                                           'new line creation request_date'
                                        || l_line_tbl (l_line_tbl_index).request_date,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                    write_to_table (
                                           'new line creation salesrep_id'
                                        || l_line_tbl (l_line_tbl_index).salesrep_id,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                                    write_to_table (
                                           'new line creation new_hdr_cancel_date'
                                        || fetch_ord_hdr_rec.new_hdr_cancel_date,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                                    IF fetch_ord_hdr_rec.new_hdr_cancel_date
                                           IS NOT NULL
                                    THEN
                                        l_line_tbl (l_line_tbl_index).attribute1   :=
                                            TO_CHAR (
                                                TO_DATE (
                                                    fetch_ord_hdr_rec.new_hdr_cancel_date),
                                                'YYYY/MM/DD HH:MI:SS');
                                    ELSE
                                        SELECT attribute1
                                          INTO lv_cancel_date
                                          FROM oe_order_headers_all
                                         WHERE header_id =
                                               fetch_ord_lines_rec.header_id;

                                        l_line_tbl (l_line_tbl_index).attribute1   :=
                                            lv_cancel_date;
                                    END IF;

                                    --Start changes v2.0
                                    IF fetch_ord_lines_rec.new_latest_accept_date
                                           IS NOT NULL
                                    THEN
                                        l_line_tbl (l_line_tbl_index).latest_acceptable_date   :=
                                            fetch_ord_lines_rec.new_latest_accept_date;
                                    END IF;
                                --End changes v2.0
                                --Start changes v2.1
                                --ELSE
                                ELSIF fetch_ord_lines_rec.line_id IS NOT NULL --v2.1 added new condn
                                THEN
                                    --End changes v2.1
                                    write_to_table (
                                        'in line record  update',
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                    l_line_tbl (l_line_tbl_index).line_id   :=
                                        fetch_ord_lines_rec.line_id;
                                    write_to_table (
                                           'update line line_id'
                                        || l_line_tbl (l_line_tbl_index).line_id,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                    l_line_tbl (l_line_tbl_index).operation   :=
                                        oe_globals.g_opr_update;
                                    l_line_tbl (l_line_tbl_index).org_id   :=
                                        ln_org_id;
                                    l_line_tbl (l_line_tbl_index).header_id   :=
                                        fetch_ord_hdr_rec.header_id;
                                    write_to_table (
                                           'update line header_id'
                                        || l_line_tbl (l_line_tbl_index).header_id,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                    write_to_table (
                                           'update line new_qty'
                                        || fetch_ord_lines_rec.new_qty,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                                    IF fetch_ord_lines_rec.new_qty
                                           IS NOT NULL
                                    THEN
                                        --Start changes v2.1
                                        IF fetch_ord_lines_rec.new_qty <
                                           fetch_ord_lines_rec.orig_qty
                                        THEN
                                            l_line_tbl (l_line_tbl_index).change_reason   :=
                                                fetch_ord_lines_rec.line_reason;
                                            l_line_tbl (l_line_tbl_index).change_comments   :=
                                                fetch_ord_lines_rec.line_comment;
                                        END IF;

                                        --End changes v2.1
                                        l_line_tbl (l_line_tbl_index).ordered_quantity   :=
                                            fetch_ord_lines_rec.new_qty;
                                    END IF;

                                    write_to_table (
                                           'update line new_hdr_cancel_date'
                                        || fetch_ord_hdr_rec.new_hdr_cancel_date,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                    write_to_table (
                                           'update line new_line_cancel_date'
                                        || fetch_ord_lines_rec.new_line_cancel_date,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                                    IF     fetch_ord_hdr_rec.new_hdr_cancel_date
                                               IS NOT NULL
                                       AND fetch_ord_lines_rec.lne_action <>
                                           'C'                          --v2.1
                                    THEN
                                        l_line_tbl (l_line_tbl_index).attribute1   :=
                                            TO_CHAR (
                                                TO_DATE (
                                                    fetch_ord_hdr_rec.new_hdr_cancel_date),
                                                'YYYY/MM/DD HH:MI:SS');
                                    ELSIF     fetch_ord_lines_rec.new_line_cancel_date
                                                  IS NOT NULL
                                          AND fetch_ord_lines_rec.lne_action <>
                                              'C'                       --v2.1
                                    THEN
                                        l_line_tbl (l_line_tbl_index).attribute1   :=
                                            TO_CHAR (
                                                TO_DATE (
                                                    fetch_ord_lines_rec.new_line_cancel_date),
                                                'YYYY/MM/DD HH:MI:SS');
                                    END IF;

                                    --Start changes v2.0
                                    IF     fetch_ord_lines_rec.new_latest_accept_date
                                               IS NOT NULL
                                       AND fetch_ord_lines_rec.lne_action <>
                                           'C'
                                    THEN                                --v2.1
                                        l_line_tbl (l_line_tbl_index).latest_acceptable_date   :=
                                            fetch_ord_lines_rec.new_latest_accept_date;
                                    END IF;

                                    --End changes v2.0
                                    write_to_table (
                                           'update line new_hdr_req_date'
                                        || fetch_ord_hdr_rec.new_hdr_req_date,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                    write_to_table (
                                           'update line new_line_req_date'
                                        || fetch_ord_lines_rec.new_line_req_date,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                                    IF     fetch_ord_hdr_rec.new_hdr_req_date
                                               IS NOT NULL
                                       AND fetch_ord_lines_rec.lne_action <>
                                           'C'                          --v2.1
                                    THEN
                                        l_line_tbl (l_line_tbl_index).request_date   :=
                                            fetch_ord_hdr_rec.new_hdr_req_date;
                                    ELSIF     fetch_ord_lines_rec.new_line_req_date
                                                  IS NOT NULL
                                          AND fetch_ord_lines_rec.lne_action <>
                                              'C'                       --v2.1
                                    THEN
                                        l_line_tbl (l_line_tbl_index).request_date   :=
                                            fetch_ord_lines_rec.new_line_req_date;
                                    END IF;

                                    --Start changes v2.1
                                    write_to_table (
                                        'lne_action' || fetch_ord_lines_rec.lne_action,
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                                    IF fetch_ord_lines_rec.lne_action = 'C' --AND fetch_ord_hdr_rec.hdr_cancel_reason IS NULL
                                    THEN
                                        l_line_tbl (l_line_tbl_index).cancelled_flag   :=
                                            'Y';
                                        l_line_tbl (l_line_tbl_index).ordered_quantity   :=
                                            0;
                                        l_line_tbl (l_line_tbl_index).change_reason   :=
                                            fetch_ord_lines_rec.line_reason;
                                        l_line_tbl (l_line_tbl_index).change_comments   :=
                                            fetch_ord_lines_rec.line_comment;

                                        write_to_table (
                                            'cancelled_flag and reason passed to api for line',
                                            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                                        write_to_table (
                                            'cancelled_flag and reason passed to api for line',
                                            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                        write_to_table (
                                            'cancelled_flag and reason passed to api for line',
                                            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                        write_to_table (
                                            'cancelled_flag and reason passed to api for line',
                                            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                                    END IF;
                                --End changes v2.1
                                END IF;
                            ELSE
                                write_to_table (
                                       'in Line status is either cancelled,shipped or closed '
                                    || fetch_ord_lines_rec.line_id,
                                    'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                                UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
                                   --SET status     = 'ERROR',
                                   SET status = 'Error',                --v1.1
                                                         error_message = 'Line status is either cancelled,shipped or closed', last_update_date = SYSDATE
                                 WHERE     batch_id = p_in_batch_id
                                       AND header_id = l_header_rec.header_id
                                       AND line_id =
                                           fetch_ord_lines_rec.line_id;
                            END IF;

                            --start v2.1
                            write_to_table (
                                'ln_line_actn_count: ' || ln_line_actn_count,
                                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                            write_to_table (
                                'ln_dec_qty_count: ' || ln_dec_qty_count,
                                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                            write_to_table (
                                'hdr_action: ' || fetch_ord_hdr_rec.hdr_action,
                                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                            write_to_table (
                                'apprvl_reqd: ' || fetch_ord_hdr_rec.apprvl_reqd,
                                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                            --call API for line level

                            IF    (NVL (fetch_ord_hdr_rec.apprvl_reqd, 'N') = 'N' AND fetch_ord_hdr_rec.hdr_action = 'U' AND (ln_line_actn_count > 0 OR ln_dec_qty_count > 0))
                               OR NVL (fetch_ord_hdr_rec.apprvl_reqd, 'N') =
                                  'Y'
                            THEN
                                oe_msg_pub.initialize;
                                oe_msg_pub.g_msg_tbl.delete;         -- ver3.4
                                write_to_table (
                                    'in line calling process order api ',
                                    'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                                --start ver3.4
                                /* oe_order_pub.process_order (
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
                x_action_request_tbl       => x_action_request_tbl);*/


                                process_order_header_line (
                                    lv_hdr_called,
                                    l_header_rec,
                                    l_action_request_tbl,
                                    l_line_tbl,
                                    lv_err_msg,
                                    lv_retn_code);

                                --end ver3.4

                                --IF l_return_status = fnd_api.g_ret_sts_success-- ver3.4
                                IF lv_retn_code = fnd_api.g_ret_sts_success -- ver3.4
                                THEN
                                    lv_hdr_called   := 'Y';          -- ver3.4
                                    write_to_table (
                                        'success in process order api ',
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                                    UPDATE xxdo.xxd_ont_genesis_dtls_stg_t xogd
                                       SET line_id   =
                                               (SELECT line_id
                                                  FROM oe_order_lines_all oola
                                                 WHERE     oola.header_id =
                                                           l_header_rec.header_id
                                                       AND oola.header_id =
                                                           xogd.header_id
                                                       AND oola.ordered_item =
                                                           xogd.item_number
                                                       AND oola.ordered_quantity =
                                                           xogd.new_qty
                                                       AND oola.request_date =
                                                           xogd.new_line_req_date
                                                       AND xogd.created_by =
                                                           oola.created_by
                                                       AND oola.orig_sys_line_ref =
                                                           xogd.orig_sys_line_ref)
                                     WHERE     batch_id = p_in_batch_id
                                           AND header_id =
                                               l_header_rec.header_id
                                           AND lne_action = 'A';

                                    COMMIT;

                                    IF fetch_ord_lines_rec.lne_action = 'A'
                                    THEN
                                        UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
                                           SET status = 'Success', last_update_date = SYSDATE
                                         WHERE     batch_id = p_in_batch_id
                                               AND header_id =
                                                   fetch_ord_hdr_rec.header_id
                                               AND status = 'NEW'
                                               AND lne_action = 'A'
                                               AND line_id IS NOT NULL;

                                        COMMIT;
                                    END IF;

                                    UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
                                       SET status = 'Success', last_update_date = SYSDATE
                                     WHERE     batch_id = p_in_batch_id
                                           AND header_id =
                                               fetch_ord_hdr_rec.header_id
                                           AND line_id =
                                               fetch_ord_lines_rec.line_id;

                                    COMMIT;
                                ELSE
                                    DBMS_OUTPUT.put_line (
                                        'Failed to Modify Sales Order');
                                    write_to_table (
                                        'Error in process order api in process_order_api_p procedure',
                                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                                    /*ln_line_count:= l_line_tbl_x.count;--start ver3.4

               FOR i IN 1 .. l_msg_count
               LOOP
                  lc_error_message := oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                 END LOOP;
             write_to_table ('lc_error_message '||lc_error_message,
                   'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                 ROLLBACK;*/
                                    --end ver3.4

                                    IF fetch_ord_lines_rec.lne_action = 'A'
                                    THEN
                                        UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
                                           SET status = 'Error', error_message = lv_err_msg, -- ver3.4
                                                                                             last_update_date = SYSDATE
                                         WHERE     batch_id = p_in_batch_id
                                               AND header_id =
                                                   fetch_ord_hdr_rec.header_id
                                               AND status = 'NEW'
                                               AND lne_action = 'A'
                                               AND line_id IS NULL;

                                        COMMIT;
                                    END IF;

                                    UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
                                       SET status = 'Error',            --v1.1
                                                             last_update_date = SYSDATE, error_message = lv_err_msg -- ver3.4
                                     WHERE     batch_id = p_in_batch_id
                                           AND header_id =
                                               fetch_ord_hdr_rec.header_id
                                           AND line_id =
                                               fetch_ord_lines_rec.line_id;

                                    COMMIT;
                                END IF;

                                l_line_tbl_index   := 0;
                            END IF;
                        --END IF;
                        --end ver 2.1
                        --start ver3.4
                        ELSE
                            ROLLBACK;
                            write_to_table (
                                   'fetch_ord_hdr_rec.header_id '
                                || fetch_ord_hdr_rec.header_id,
                                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                            write_to_table (
                                   'fetch_ord_lines_rec.line_id '
                                || fetch_ord_lines_rec.line_id,
                                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                            write_to_table (
                                'p_in_batch_id ' || p_in_batch_id,
                                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                            lv_cncl_rsn_miss   := 'Y';

                            UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
                               SET status = 'Error',                    --v1.1
                                                     last_update_date = SYSDATE, error_message = 'Line Cancel reason is missing'
                             WHERE     batch_id = p_in_batch_id
                                   AND header_id =
                                       fetch_ord_hdr_rec.header_id
                                   AND line_id = fetch_ord_lines_rec.line_id;

                            COMMIT;
                        END IF;                                   --end ver3.4
                    END LOOP;
                END IF;

                write_to_table (
                    'in process_order_api_p end loop ',
                    'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                --v1.6 START
                /*lv_time_stamp := to_char(sysdate, 'DD-MON-YYYY HH24:MI:SS');
           write_to_table ('in process_order_api_p lv_time_stamp: '||lv_time_stamp,
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');*/
                --v1.6 end

                --start v2.1
                --IF NVL(fetch_ord_hdr_rec.apprvl_reqd,'N') = 'N' AND  ( NVL(fetch_ord_hdr_rec.apprvl_reqd,'N')  = 'N'
                --     AND ln_line_actn_count =0 AND ln_dec_qty_count =0)
                IF     NVL (fetch_ord_hdr_rec.apprvl_reqd, 'N') = 'N'
                   AND ln_line_actn_count = 0
                   AND ln_dec_qty_count = 0
                THEN
                    IF lv_cncl_rsn_miss = 'N'
                    THEN                                             -- ver3.4
                        --end v2.1
                        oe_msg_pub.initialize;
                        oe_msg_pub.g_msg_tbl.delete;                 -- ver3.4
                        write_to_table (
                            'in hdr process_order_api_p before calling process order api ',
                            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');


                        oe_order_pub.process_order (
                            p_api_version_number     => 1.0,
                            p_init_msg_list          => fnd_api.g_true,
                            p_return_values          => fnd_api.g_true,
                            --Start changes v1.5
                            --p_action_commit            => fnd_api.g_true,
                            p_action_commit          => fnd_api.g_false,
                            --end changes v1.5
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
                            x_action_request_tbl     => x_action_request_tbl);

                        IF l_return_status = fnd_api.g_ret_sts_success
                        THEN
                            write_to_table (
                                'success in process order api ',
                                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                            /*UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
                 --SET status     = 'SUCCESS',
                SET status     = 'Success', --v1.1
                 last_update_date = SYSDATE
                 WHERE batch_id         = p_in_batch_id
                AND header_id     = l_header_rec.header_id ;
              --Start changes v1.5
              COMMIT;*/
                            --v1.6 start
                            /* UPDATE xxdo.xxd_ont_genesis_dtls_stg_t xogd
                               SET line_id = (SELECT line_id
                                                FROM oe_order_lines_all oola
                                               WHERE oola.header_id  = l_header_rec.header_id
                                               AND oola.header_id    = xogd.header_id
                                               AND oola.ordered_item = xogd.item_number
                                               AND oola.ordered_quantity =xogd.new_qty
                                               AND oola.request_date = xogd.new_line_req_date
                    AND xogd.created_by       = oola.created_by
                    AND oola.creation_date > = to_date(lv_time_stamp, 'DD-MON-YYYY HH24:MI:SS'))
                              WHERE batch_id          = p_in_batch_id
                                AND header_id         = l_header_rec.header_id
                                AND lne_action = 'A';
                COMMIT; */
                            UPDATE xxdo.xxd_ont_genesis_dtls_stg_t xogd
                               SET line_id   =
                                       (SELECT line_id
                                          FROM oe_order_lines_all oola
                                         WHERE     oola.header_id =
                                                   l_header_rec.header_id
                                               AND oola.header_id =
                                                   xogd.header_id
                                               AND oola.ordered_item =
                                                   xogd.item_number
                                               AND oola.ordered_quantity =
                                                   xogd.new_qty
                                               AND oola.request_date =
                                                   xogd.new_line_req_date
                                               AND xogd.created_by =
                                                   oola.created_by
                                               AND oola.orig_sys_line_ref =
                                                   xogd.orig_sys_line_ref)
                             WHERE     batch_id = p_in_batch_id
                                   AND header_id = l_header_rec.header_id
                                   AND lne_action = 'A';

                            COMMIT;

                            UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
                               SET status = 'Success', last_update_date = SYSDATE
                             WHERE     batch_id = p_in_batch_id
                                   AND header_id = l_header_rec.header_id;

                            COMMIT;
                        --v1.6 end

                        ELSE
                            DBMS_OUTPUT.put_line (
                                'Failed to Modify Sales Order');
                            write_to_table (
                                'Error in process order api ',
                                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                            ln_line_count   := l_line_tbl_x.COUNT;

                            FOR i IN 1 .. l_msg_count
                            LOOP
                                lc_error_message   :=
                                    oe_msg_pub.get (p_msg_index   => i,
                                                    p_encoded     => 'F');
                            END LOOP;

                            ROLLBACK;

                            UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
                               --SET status     = 'ERROR' ,
                               SET status = 'Error',                    --v1.1
                                                     last_update_date = SYSDATE, error_message = lc_error_message
                             WHERE     batch_id = p_in_batch_id
                                   AND header_id = l_header_rec.header_id;

                            COMMIT;
                        END IF;
                    --start ver3.4
                    ELSE
                        UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
                           SET status = 'Error', last_update_date = SYSDATE, error_message = 'Line Cancel reason is missing for one of the lines'
                         WHERE     batch_id = p_in_batch_id
                               AND header_id = fetch_ord_hdr_rec.header_id;

                        COMMIT;
                    END IF;
                --end ver3.4
                END IF;
            --start ver3.4
            ELSE
                write_to_table (
                    'Header cancel reason ',
                    'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
                   SET status = 'Error',                                --v1.1
                                         last_update_date = SYSDATE, error_message = 'Header Cancel reason is missing'
                 WHERE     batch_id = p_in_batch_id
                       AND header_id = fetch_ord_hdr_rec.header_id;

                COMMIT;
            END IF;

            --end ver3.4
            write_to_table (
                'Before end loop for order header id ' || l_header_rec.header_id,
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
        END LOOP;

        BEGIN
            SELECT 1
              INTO ln_status_errcount
              FROM xxdo.xxd_ont_genesis_dtls_stg_t
             WHERE     batch_id = p_in_batch_id
                   --AND status   = 'ERROR'
                   AND status = 'Error'                                 --v1.1
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_status_errcount   := 0;
            WHEN OTHERS
            THEN
                ln_status_errcount   := 0;
        END;

        write_to_table (
               'in process_order_api_p ln_status_errcount '
            || ln_status_errcount,
            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

        BEGIN
            SELECT 1
              INTO ln_status_succcount
              FROM xxdo.xxd_ont_genesis_dtls_stg_t
             WHERE     batch_id = p_in_batch_id
                   --AND status   = 'SUCCESS'
                   AND status = 'Success'                               --v1.1
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_status_succcount   := 0;
            WHEN OTHERS
            THEN
                ln_status_succcount   := 0;
        END;

        --v2.1
        BEGIN
            SELECT 1
              INTO ln_status_newcount
              FROM xxdo.xxd_ont_genesis_dtls_stg_t
             WHERE batch_id = p_in_batch_id AND status = 'NEW'          --v1.1
                                                               AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_status_newcount   := 0;
            WHEN OTHERS
            THEN
                ln_status_newcount   := 0;
        END;

        --v2.1
        write_to_table (
               'in process_order_api_p ln_status_succcount '
            || ln_status_succcount,
            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

        IF ln_status_errcount = 1 AND ln_status_succcount = 1
        THEN
            write_to_table (
                'in process_order_api_p partial success ',
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            UPDATE xxdo.xxd_ont_genesis_hdr_stg_t
               --SET status        = 'PARTIAL_SUCCESS',
               SET status = 'Partial Success',                          --v1.1
                                               last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            COMMIT;
        ELSIF ln_status_errcount = 1 AND ln_status_succcount = 0
        THEN
            write_to_table (
                'in process_order_api_p error ',
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            UPDATE xxdo.xxd_ont_genesis_hdr_stg_t
               --SET status        = 'ERROR',
               SET status = 'Error',                                    --v1.1
                                     last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            COMMIT;
        ELSIF ln_status_newcount = 1
        THEN
            write_to_table (
                'in process_order_api_p new status ',
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            UPDATE xxdo.xxd_ont_genesis_hdr_stg_t
               SET status = 'Error', last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            COMMIT;
        ELSE
            write_to_table (
                'in process_order_api_p success ',
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            UPDATE xxdo.xxd_ont_genesis_hdr_stg_t
               --SET status        = 'SUCCESS',
               SET status = 'Success',                                  --v1.1
                                       last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN lv_loop_exception
        THEN
            write_to_table (
                'in lv_loop_exception ',
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            UPDATE xxdo.xxd_ont_genesis_hdr_stg_t
               --SET status    = 'ERROR',
               SET status = 'Error',                                    --v1.1
                                     last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
               --SET status           = 'ERROR',
               SET status = 'Error',                                    --v1.1
                                     error_message = lc_error_message, last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id AND header_id = ln_header_id;

            COMMIT;
        WHEN OTHERS
        THEN
            write_to_table (
                'in others ',
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            UPDATE xxdo.xxd_ont_genesis_hdr_stg_t
               --SET status       = 'ERROR',
               SET status = 'Error',                                    --v1.1
                                     last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            UPDATE xxdo.xxd_ont_genesis_dtls_stg_t
               --SET status       = 'ERROR',
               SET status = 'Error',                                    --v1.1
                                     error_message = 'Unexpected error in  process_order_api_p', last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            COMMIT;
            write_to_table (
                'Unexpected error in  process_order_api_p' || SQLERRM,
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
    END process_order_api_p;

    PROCEDURE schedule_order (p_in_batch_id   IN     NUMBER,
                              p_out_err_msg      OUT VARCHAR2)
    IS
        ln_job   NUMBER;
    BEGIN
        DBMS_JOB.SUBMIT (
            ln_job,
               ' 
    begin
      apps.xxd_ont_genesis_proc_ord_pkg.process_order_api_p('''
            || p_in_batch_id
            || '''); end; ');
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_err_msg   :=
                SUBSTR ('Error in schedule_order proc' || SQLERRM, 1, 4000);

            write_to_table (
                SUBSTR ('Error in schedule_order proc' || SQLERRM, 1, 4000),
                'xxd_ont_genesis_proc_ord_pkg.schedule_order');
    END schedule_order;

    --start ver 3.3
    PROCEDURE fetch_trx_history_data (p_in_user_id IN NUMBER, p_out_hdr OUT SYS_REFCURSOR, p_out_err_msg OUT VARCHAR2)
    IS
        lv_display_name     VARCHAR2 (100);
        lv_username         VARCHAR2 (100);
        lv_email_id         VARCHAR2 (100);
        ln_header_id        NUMBER;
        lv_user_exception   EXCEPTION;
        lv_exception        EXCEPTION;
    BEGIN
        write_to_table (
               'fetch_trx_history_data start'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data');
        fetch_ad_user_email (p_in_user_id => p_in_user_id, p_out_user_name => lv_username, p_out_display_name => lv_display_name
                             , p_out_email_id => lv_email_id);

        BEGIN
            OPEN p_out_hdr FOR   SELECT xogh.batch_id, xogh.status, xogh.creation_date
                                   FROM xxdo.xxd_ont_genesis_hdr_stg_t xogh
                                  WHERE xogh.created_by = p_in_user_id
                               ORDER BY xogh.batch_id DESC;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_err_msg   :=
                       'Error while fetching history header details for user '
                    || lv_display_name;
                write_to_table (
                       'Error while fetching history header details for user '
                    || lv_display_name,
                    'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data');
        END;

        write_to_table (
               'fetch_trx_history_data end'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_err_msg   := 'Error in fetch_trx_history_data for user ';
            write_to_table (
                   'Error in fetch_trx_history_data for user '
                || lv_display_name,
                'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data');
    END fetch_trx_history_data;

    --end ver 3.3

    PROCEDURE fetch_trx_details (p_in_user_id IN NUMBER, p_in_batch_id IN NUMBER, p_out_results OUT CLOB
                                 , p_out_err_msg OUT VARCHAR2)
    IS
        lv_display_name       VARCHAR2 (100);
        lv_username           VARCHAR2 (100);
        lv_email_id           VARCHAR2 (100);
        ln_plan_id            NUMBER;
        ln_pre_headerid       NUMBER;
        ld_plan_date          DATE;
        lv_nodata_exception   EXCEPTION;
        lv_err_msg            VARCHAR2 (100)
            := 'One or more lines ended in error. Please check the lines for more details.';

        CURSOR trx_details_cur IS
              SELECT batch_id,
                     customer_number,
                     customer_name,
                     order_number,
                     header_id,
                     cust_po_number,
                     order_status,
                     header_request_date,
                     header_cancel_date,
                     salesrep_hold,
                     --start ver 3.1
                     --status,
                     --error_message,
                     batch_hdr_status,
                     batch_line_status,
                     batch_hdr_msg,
                     batch_line_msg,
                     --end ver 3.1
                     --Start changes v1.2
                     hdr_updates,
                     --End changes v1.2
                     line_number,
                     line_id,
                     ordered_item,
                     line_status,
                     --Start changes v1.2
                     line_updates,
                     --End changes v1.2
                     quantity,
                     line_request_date,
                     line_cancel_date--start v2.0
                                     ,
                     latest_acceptable_date,
                     sort_order--End v2.0
                               --Start changes v2.1
                               ,
                     hdr_cancel_reason,
                     hdr_cancel_comment,
                     line_reason,
                     line_comment--Start changes v3.2
                                 ,
                     lne_action,
                     orig_qty,
                     new_quantity,
                     line_price,
                     unit_selling_price,
                     currency_code--End changes v3.2
                                  ,
                     (SELECT ol.meaning
                        FROM oe_lookups ol
                       WHERE     ol.lookup_code = hdr_cancel_reason
                             AND ol.lookup_type = 'CANCEL_CODE')
                         hdr_cancel_reason_display,
                     (SELECT ol.meaning
                        FROM oe_lookups ol
                       WHERE     ol.lookup_code = line_reason
                             AND ol.lookup_type = 'CANCEL_CODE')
                         line_reason_display
                --End changes v2.1
                FROM (SELECT DISTINCT
                             xogh.batch_id,
                             xogh.account_number
                                 customer_number,
                             (SELECT account_name
                                FROM hz_cust_accounts hca
                               WHERE     hca.cust_account_id =
                                         ooha.sold_to_org_id
                                     AND ROWNUM = 1)
                                 customer_name,
                             ooha.order_number,
                             xogh.header_id,
                             ooha.cust_po_number,
                             ooha.flow_status_code
                                 order_status,
                             TRUNC (ooha.request_date)
                                 header_request_date,
                             TRUNC (
                                 TO_DATE (ooha.attribute1,
                                          'YYYY/MM/DD HH24:MI:SS'))
                                 header_cancel_date,
                             (SELECT DECODE (COUNT (1), 0, 'N', 'Y')
                                FROM oe_order_holds_all hold, oe_hold_sources_all ohsa
                               WHERE     hold.header_id = ooha.header_id
                                     AND hold.released_flag = 'N'
                                     AND hold.hold_source_id =
                                         ohsa.hold_source_id
                                     AND ohsa.released_flag = 'N'
                                     AND ohsa.hold_release_id IS NULL
                                     --Start changes v2.0
                                     --AND ohsa.hold_id = 1002
                                     AND ohsa.hold_id = 1005
                                     --End changes v2.0
                                     AND ohsa.hold_entity_code = 'O')
                                 salesrep_hold,
                             --start v3.1
                             --xogh.status,
                             CASE
                                 WHEN EXISTS
                                          (SELECT 1
                                             FROM xxdo.xxd_ont_genesis_dtls_stg_t xogh1
                                            WHERE     xogh1.header_id =
                                                      xogh.header_id
                                                  AND xogh1.batch_id =
                                                      p_in_batch_id
                                                  AND status = 'Error'
                                                  AND ROWNUM = 1)
                                 THEN
                                     'Error'
                                 ELSE
                                     'Success'
                             END
                                 AS batch_hdr_status,
                             xogh.status
                                 batch_line_status,
                             --xogh.error_message,
                             CASE
                                 WHEN EXISTS
                                          (SELECT 1
                                             FROM xxdo.xxd_ont_genesis_dtls_stg_t xogh1
                                            WHERE     xogh1.header_id =
                                                      xogh.header_id
                                                  AND xogh1.batch_id =
                                                      p_in_batch_id
                                                  AND status = 'Error'
                                                  AND ROWNUM = 1)
                                 THEN
                                     lv_err_msg
                                 ELSE
                                     NULL
                             END
                                 AS batch_hdr_msg,
                             xogh.error_message
                                 batch_line_msg,
                             --end v3.1
                             --Start changes v1.2
                             xogh.hdr_updates,
                             --End changes v1.2
                             oola.line_number || '.' || oola.shipment_number
                                 line_number,
                             xogh.line_id,
                             oola.ordered_item,
                             oola.flow_status_code
                                 line_status,
                             --Start changes v1.2
                             xogh.line_updates,
                             --End changes v1.2
                             oola.ordered_quantity
                                 quantity,
                             TRUNC (oola.request_date)
                                 line_request_date,
                             TRUNC (
                                 TO_DATE (oola.attribute1,
                                          'YYYY/MM/DD HH24:MI:SS'))
                                 line_cancel_date--start v2.0
                                                 ,
                             oola.latest_acceptable_date
                                 latest_acceptable_date,
                             TO_NUMBER (msib.attribute10)
                                 sort_order--End v2.0
                                           --Start changes v2.1
                                           ,
                             xogh.hdr_cancel_reason,
                             xogh.hdr_cancel_comment,
                             xogh.line_reason,
                             xogh.line_comment--End changes v2.1
                                              --Start changes v3.2
                                              ,
                             xogh.lne_action,
                             xogh.orig_qty,
                             xogh.new_qty
                                 new_quantity,
                             xogh.line_price,
                             xogh.unit_selling_price,
                             (SELECT qh.currency_code
                                FROM apps.qp_list_headers_b qh
                               WHERE qh.list_header_id = ooha.price_list_id)
                                 currency_code
                        --End changes v3.2
                        FROM xxdo.xxd_ont_genesis_dtls_stg_t xogh, oe_order_headers_all ooha, oe_order_lines_all oola--Start changes v2.0
                                                                                                                     ,
                             mtl_system_items_b msib
                       --End changes v2.0
                       WHERE     ooha.header_id = xogh.header_id
                             AND xogh.batch_id = p_in_batch_id
                             AND xogh.created_by = p_in_user_id
                             AND oola.header_id = ooha.header_id
                             AND oola.line_id = xogh.line_id
                             --Start changes v2.0
                             AND msib.inventory_item_id =
                                 oola.inventory_item_id
                             AND msib.organization_id = oola.ship_from_org_id
                             --End changes v2.0
                             --start ver3.4
                             AND msib.enabled_flag = 'Y'
                             AND msib.inventory_item_status_code = 'Active'
                      --end ver3.4
                      UNION
                      SELECT DISTINCT
                             xogh.batch_id,
                             xogh.account_number
                                 customer_number,
                             (SELECT account_name
                                FROM hz_cust_accounts hca
                               WHERE     hca.cust_account_id =
                                         ooha.sold_to_org_id
                                     AND ROWNUM = 1)
                                 customer_name,
                             ooha.order_number,
                             xogh.header_id,
                             ooha.cust_po_number,
                             ooha.flow_status_code
                                 order_status,
                             TRUNC (ooha.request_date)
                                 header_request_date,
                             TRUNC (
                                 TO_DATE (ooha.attribute1,
                                          'YYYY/MM/DD HH24:MI:SS'))
                                 header_cancel_date,
                             (SELECT DECODE (COUNT (1), 0, 'N', 'Y')
                                FROM oe_order_holds_all hold, oe_hold_sources_all ohsa
                               WHERE     hold.header_id = ooha.header_id
                                     AND hold.released_flag = 'N'
                                     AND hold.hold_source_id =
                                         ohsa.hold_source_id
                                     AND ohsa.released_flag = 'N'
                                     AND ohsa.hold_release_id IS NULL
                                     --Start changes v2.0
                                     --AND ohsa.hold_id = 1002
                                     AND ohsa.hold_id = 1005
                                     --End changes v2.0
                                     AND ohsa.hold_entity_code = 'O')
                                 salesrep_hold,
                             --start v3.1
                             --xogh.status,
                             CASE
                                 WHEN EXISTS
                                          (SELECT 1
                                             FROM xxdo.xxd_ont_genesis_dtls_stg_t xogh1
                                            WHERE     xogh1.header_id =
                                                      xogh.header_id
                                                  AND xogh1.batch_id =
                                                      p_in_batch_id
                                                  AND status = 'Error'
                                                  AND ROWNUM = 1)
                                 THEN
                                     'Error'
                                 ELSE
                                     'Success'
                             END
                                 AS batch_hdr_status,
                             xogh.status
                                 batch_line_status,
                             --xogh.error_message,
                             CASE
                                 WHEN EXISTS
                                          (SELECT 1
                                             FROM xxdo.xxd_ont_genesis_dtls_stg_t xogh1
                                            WHERE     xogh1.header_id =
                                                      xogh.header_id
                                                  AND xogh1.batch_id =
                                                      p_in_batch_id
                                                  AND status = 'Error'
                                                  AND ROWNUM = 1)
                                 THEN
                                     lv_err_msg
                                 ELSE
                                     NULL
                             END
                                 AS batch_hdr_msg,
                             xogh.error_message
                                 batch_line_msg,
                             --end v3.1
                             --Start changes v1.2
                             xogh.hdr_updates,
                             --End changes v1.2
                             ''
                                 line_number,
                             NULL
                                 line_id,
                             ''
                                 ordered_item,
                             ''
                                 line_status,
                             --Start changes v1.2
                             ''
                                 line_updates,
                             --End changes v1.2
                             NULL
                                 quantity,
                             NULL
                                 line_request_date,
                             NULL
                                 line_cancel_date--start v2.0
                                                 ,
                             NULL
                                 latest_acceptable_date,
                             NULL
                                 sort_order--End v2.0
                                           --Start changes v2.1
                                           ,
                             xogh.hdr_cancel_reason,
                             xogh.hdr_cancel_comment,
                             xogh.line_reason,
                             xogh.line_comment--End changes v2.1
                                              --Start changes v3.2
                                              ,
                             xogh.lne_action,
                             xogh.orig_qty,
                             xogh.new_qty
                                 new_quantity,
                             xogh.line_price,
                             xogh.unit_selling_price,
                             (SELECT qh.currency_code
                                FROM apps.qp_list_headers_b qh
                               WHERE qh.list_header_id = ooha.price_list_id)
                                 currency_code
                        --End changes v3.2
                        FROM xxdo.xxd_ont_genesis_dtls_stg_t xogh, oe_order_headers_all ooha
                       WHERE     ooha.header_id = xogh.header_id
                             AND xogh.batch_id = p_in_batch_id
                             AND xogh.created_by = p_in_user_id
                             --Start changes v1.4
                             --Start changes v1.3
                             AND xogh.lne_action IS NULL
                      --AND xogh.lne_action = 'A')
                      --End changes v1.3
                      UNION
                      SELECT DISTINCT
                             xogh.batch_id,
                             xogh.account_number
                                 customer_number,
                             (SELECT account_name
                                FROM hz_cust_accounts hca
                               WHERE     hca.cust_account_id =
                                         ooha.sold_to_org_id
                                     AND ROWNUM = 1)
                                 customer_name,
                             ooha.order_number,
                             xogh.header_id,
                             ooha.cust_po_number,
                             ooha.flow_status_code
                                 order_status,
                             TRUNC (ooha.request_date)
                                 header_request_date,
                             TRUNC (
                                 TO_DATE (ooha.attribute1,
                                          'YYYY/MM/DD HH24:MI:SS'))
                                 header_cancel_date,
                             (SELECT DECODE (COUNT (1), 0, 'N', 'Y')
                                FROM oe_order_holds_all hold, oe_hold_sources_all ohsa
                               WHERE     hold.header_id = ooha.header_id
                                     AND hold.released_flag = 'N'
                                     AND hold.hold_source_id =
                                         ohsa.hold_source_id
                                     AND ohsa.released_flag = 'N'
                                     AND ohsa.hold_release_id IS NULL
                                     --Start changes v2.0
                                     --AND ohsa.hold_id = 1002
                                     AND ohsa.hold_id = 1005
                                     --End changes v2.0
                                     AND ohsa.hold_entity_code = 'O')
                                 salesrep_hold,
                             --start v3.1
                             --xogh.status,
                             CASE
                                 WHEN EXISTS
                                          (SELECT 1
                                             FROM xxdo.xxd_ont_genesis_dtls_stg_t xogh1
                                            WHERE     xogh1.header_id =
                                                      xogh.header_id
                                                  AND xogh1.batch_id =
                                                      p_in_batch_id
                                                  AND status = 'Error'
                                                  AND ROWNUM = 1)
                                 THEN
                                     'Error'
                                 ELSE
                                     'Success'
                             END
                                 AS batch_hdr_status,
                             xogh.status
                                 batch_line_status,
                             --xogh.error_message,
                             CASE
                                 WHEN EXISTS
                                          (SELECT 1
                                             FROM xxdo.xxd_ont_genesis_dtls_stg_t xogh1
                                            WHERE     xogh1.header_id =
                                                      xogh.header_id
                                                  AND xogh1.batch_id =
                                                      p_in_batch_id
                                                  AND status = 'Error'
                                                  AND ROWNUM = 1)
                                 THEN
                                     lv_err_msg
                                 ELSE
                                     NULL
                             END
                                 AS batch_hdr_msg,
                             xogh.error_message
                                 batch_line_msg,
                             --end v3.1
                             xogh.hdr_updates,
                             ''
                                 line_number,
                             xogh.line_id,
                             xogh.item_number
                                 ordered_item,
                             ''
                                 line_status,
                             xogh.line_updates,
                             xogh.new_qty
                                 quantity,
                             xogh.new_line_req_date
                                 line_request_date,
                             xogh.new_line_cancel_date
                                 line_cancel_date--start v2.0
                                                 ,
                             NULL
                                 latest_acceptable_date,
                             NULL
                                 sort_order--End v2.0
                                           --Start changes v2.1
                                           ,
                             xogh.hdr_cancel_reason,
                             xogh.hdr_cancel_comment,
                             xogh.line_reason,
                             xogh.line_comment--End changes v2.1
                                              --Start changes v3.2
                                              ,
                             xogh.lne_action,
                             xogh.orig_qty,
                             xogh.new_qty
                                 new_quantity,
                             xogh.line_price,
                             xogh.unit_selling_price,
                             (SELECT qh.currency_code
                                FROM apps.qp_list_headers_b qh
                               WHERE qh.list_header_id = ooha.price_list_id)
                                 currency_code
                        --End changes v3.2
                        FROM xxdo.xxd_ont_genesis_dtls_stg_t xogh, oe_order_headers_all ooha
                       WHERE     ooha.header_id = xogh.header_id
                             AND xogh.batch_id = p_in_batch_id
                             AND xogh.created_by = p_in_user_id
                             AND xogh.lne_action = 'A'
                             AND xogh.line_id IS NULL)
            --End changes v1.4
            ORDER BY header_id;
    BEGIN
        write_to_table (
               'fetch_trx_details start'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_details');
        fetch_ad_user_email (p_in_user_id => p_in_user_id, p_out_user_name => lv_username, p_out_display_name => lv_display_name
                             , p_out_email_id => lv_email_id);

        BEGIN
            ln_pre_headerid   := -1;
            APEX_JSON.initialize_clob_output;
            APEX_JSON.open_object;                                        -- {
            APEX_JSON.open_array ('order_headers');

            BEGIN
                FOR trx_details_rec IN trx_details_cur
                LOOP
                    IF (ln_pre_headerid != trx_details_rec.header_id)
                    THEN
                        BEGIN
                            IF (ln_pre_headerid != -1)
                            THEN
                                BEGIN
                                    APEX_JSON.close_array;    -- ] order_lines
                                    APEX_JSON.close_object;   --} order_header
                                END;
                            END IF;

                            APEX_JSON.open_object;
                            APEX_JSON.write ('order_number',
                                             trx_details_rec.order_number);
                            APEX_JSON.write ('header_id',
                                             trx_details_rec.header_id);
                            APEX_JSON.write ('customer_name',
                                             trx_details_rec.customer_name);
                            APEX_JSON.write ('customer_number',
                                             trx_details_rec.customer_number);
                            APEX_JSON.write ('customer_po_number',
                                             trx_details_rec.cust_po_number);
                            APEX_JSON.write ('order_status',
                                             trx_details_rec.order_status);
                            APEX_JSON.write (
                                'new_header_req_date',
                                trx_details_rec.header_request_date,
                                TRUE);
                            APEX_JSON.write (
                                'new_header_cancel_date',
                                trx_details_rec.header_cancel_date,
                                TRUE);
                            APEX_JSON.write ('new_salesrep_hold',
                                             trx_details_rec.salesrep_hold);
                            --start ver3.1
                            --APEX_JSON.write('batch_status', trx_details_rec.status);
                            --APEX_JSON.write('error_message', trx_details_rec.error_message,TRUE);
                            APEX_JSON.write (
                                'batch_status',
                                trx_details_rec.batch_hdr_status);
                            APEX_JSON.write ('error_message',
                                             trx_details_rec.batch_hdr_msg,
                                             TRUE);
                            --end ver3.1
                            --Start changes v1.2
                            APEX_JSON.write ('hdr_updates',
                                             trx_details_rec.hdr_updates,
                                             TRUE);
                            --End changes v1.2
                            --Start changes v2.1
                            APEX_JSON.write (
                                'hdr_cancel_reason',
                                trx_details_rec.hdr_cancel_reason,
                                TRUE);
                            APEX_JSON.write (
                                'hdr_cancel_reason_display',
                                trx_details_rec.hdr_cancel_reason_display,
                                TRUE);
                            APEX_JSON.write (
                                'hdr_cancel_comment',
                                trx_details_rec.hdr_cancel_comment,
                                TRUE);
                            --End changes v2.1
                            APEX_JSON.write ('currency_code',
                                             trx_details_rec.currency_code,
                                             TRUE);                     --v3.2
                            -- .... all header fields
                            APEX_JSON.open_array ('order_lines');
                        END;
                    END IF;

                    APEX_JSON.open_object;

                    APEX_JSON.write ('line_number',
                                     trx_details_rec.line_number);
                    APEX_JSON.write ('ordered_item',
                                     trx_details_rec.ordered_item);
                    APEX_JSON.write ('line_status',
                                     trx_details_rec.line_status);
                    APEX_JSON.write ('latest_qty', trx_details_rec.quantity); --ver3.2
                    APEX_JSON.write ('new_line_req_date',
                                     trx_details_rec.line_request_date,
                                     TRUE);
                    APEX_JSON.write ('new_line_cancel_date',
                                     trx_details_rec.line_cancel_date,
                                     TRUE);
                    --Start changes v1.2
                    APEX_JSON.write ('line_updates',
                                     trx_details_rec.line_updates,
                                     TRUE);
                    --End changes v1.2
                    --start v2.0
                    APEX_JSON.write ('latest_accepatable_date',
                                     trx_details_rec.latest_acceptable_date,
                                     TRUE);                             --v2.1
                    APEX_JSON.write ('sort_order',
                                     trx_details_rec.sort_order,
                                     TRUE);
                    --End v2.0
                    --Start changes v2.1
                    APEX_JSON.write ('line_reason',
                                     trx_details_rec.line_reason,
                                     TRUE);
                    APEX_JSON.write ('line_reason_display',
                                     trx_details_rec.line_reason_display,
                                     TRUE);
                    APEX_JSON.write ('line_comment',
                                     trx_details_rec.line_comment,
                                     TRUE);
                    --start ver3.1
                    --APEX_JSON.write('line_batch_status', trx_details_rec.status);
                    --APEX_JSON.write('line_error_message', trx_details_rec.error_message,TRUE);
                    APEX_JSON.write ('line_batch_status',
                                     trx_details_rec.batch_line_status);
                    APEX_JSON.write ('line_error_message',
                                     trx_details_rec.batch_line_msg,
                                     TRUE);
                    --end ver3.1
                    --End changes v2.1

                    --Start changes v3.2
                    APEX_JSON.write ('line_action',
                                     trx_details_rec.lne_action,
                                     TRUE);
                    APEX_JSON.write ('new_quantity',
                                     trx_details_rec.new_quantity,
                                     TRUE);
                    APEX_JSON.write (
                        'line_price',
                        TO_CHAR (
                            trx_details_rec.line_price,
                            fnd_currency.get_format_mask (
                                trx_details_rec.currency_code,
                                30)),
                        TRUE);
                    APEX_JSON.write (
                        'unit_selling_price',
                        TO_CHAR (
                            trx_details_rec.unit_selling_price,
                            fnd_currency.get_format_mask (
                                trx_details_rec.currency_code,
                                30)),
                        TRUE);
                    APEX_JSON.write ('quantity',
                                     trx_details_rec.orig_qty,
                                     TRUE);
                    write_to_table (
                           'fetch_trx_details loop '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
                        'xxd_ont_genesis_proc_ord_pkg.fetch_trx_details');
                    --End changes v3.2
                    -- .... all lines fields
                    APEX_JSON.close_object;

                    ln_pre_headerid   := trx_details_rec.header_id;
                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    write_to_table (
                        'No data found for user ' || lv_display_name,
                        'xxd_ont_genesis_proc_ord_pkg.fetch_trx_details');
                    RAISE lv_nodata_exception;
                WHEN OTHERS
                THEN
                    RAISE lv_nodata_exception;
            END;

            APEX_JSON.close_array;                            -- ] order_lines
            APEX_JSON.close_object;                           --} order_header
            APEX_JSON.close_array;                          -- ] order_headers

            APEX_JSON.close_object;                                        --}
        END;

        write_to_table ('fetched trx_details for user ' || lv_display_name,
                        'xxd_ont_genesis_proc_ord_pkg.fetch_trx_details');

        p_out_results   := APEX_JSON.get_clob_output;
        APEX_JSON.free_output;

        write_to_table (
               'fetch_trx_details end'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_details');
    EXCEPTION
        WHEN lv_nodata_exception
        THEN
            p_out_err_msg   :=
                'Unexpected error occured while fetching trx details';
            write_to_table (
                   'Unexpected error occured while fetching trx details '
                || lv_display_name,
                'xxd_ont_genesis_proc_ord_pkg.fetch_trx_details');
        WHEN OTHERS
        THEN
            p_out_err_msg   := 'Unexpected error in fetch_trx_details ';
            write_to_table (
                   'Unexpected error in fetch_trx_details for user '
                || lv_display_name,
                'xxd_ont_genesis_proc_ord_pkg.fetch_trx_details');
    END fetch_trx_details;

    --start ver 3.3
    PROCEDURE fetch_trx_his_filter (p_in_filter IN CLOB, p_out_hdr OUT CLOB, p_out_results OUT CLOB
                                    , p_out_err_msg OUT VARCHAR2)
    IS
        lv_display_name        VARCHAR2 (100);
        lv_username            VARCHAR2 (100);
        lv_email_id            VARCHAR2 (100);

        ln_count               NUMBER := 0;
        lv_cus_number          VARCHAR2 (100);
        lv_so_number           VARCHAR2 (240);
        lv_cust_name           VARCHAR2 (240);
        lv_cus_po_num          VARCHAR2 (240);
        lv_action              VARCHAR2 (2000);
        lv_cart_crtn_date_fm   VARCHAR2 (240);
        lv_cart_crtn_date_to   VARCHAR2 (240);
        l_action_tab           ACTION_TBL_TYPE;
        lv_user_action_cur     VARCHAR2 (32000);
        lv_so_num_cond         VARCHAR2 (500);
        lv_cus_num_cond        VARCHAR2 (500);
        lv_cus_po_num_cond     VARCHAR2 (500);
        lv_ctrn_dt_cond        VARCHAR2 (500);
        lv_user_act_cond       VARCHAR2 (5000);
        ln_user_id             NUMBER;

        lv_string              LONG;
        lv_actions_list        useract_tbl_type := useract_tbl_type ();
        ln_count1              NUMBER;
        tmp                    useract_tbl_type := useract_tbl_type ();

        lv_nodata_exception    EXCEPTION;

        TYPE user_action_rec_type
            IS RECORD
        (
            batch_id         xxdo.xxd_ont_genesis_hdr_stg_t.batch_id%TYPE,
            status           xxdo.xxd_ont_genesis_hdr_stg_t.status%TYPE,
            creation_date    xxdo.xxd_ont_genesis_hdr_stg_t.creation_date%TYPE
        );

        TYPE user_action_type IS TABLE OF user_action_rec_type
            INDEX BY BINARY_INTEGER;

        hdr_records_rec        user_action_type;

        TYPE hdr_records_typ IS REF CURSOR;

        hdr_records_cur        hdr_records_typ;

        CURSOR cust_po_num_cur IS
            SELECT DISTINCT xogd.cust_po_num
              FROM xxdo.xxd_ont_genesis_dtls_stg_t xogd
             WHERE xogd.created_by = ln_user_id;

        CURSOR cust_name_cur IS
            SELECT DISTINCT xogd.account_number, hca.account_name
              FROM xxdo.xxd_ont_genesis_dtls_stg_t xogd, hz_cust_accounts hca
             WHERE     xogd.created_by = ln_user_id
                   AND xogd.account_number = hca.account_number;

        CURSOR user_action_cur IS
            SELECT DISTINCT xogd.hdr_updates usr_action
              FROM xxdo.xxd_ont_genesis_dtls_stg_t xogd
             WHERE xogd.created_by = ln_user_id AND hdr_updates IS NOT NULL
            UNION
            SELECT DISTINCT xogd.line_updates usr_action
              FROM xxdo.xxd_ont_genesis_dtls_stg_t xogd
             WHERE xogd.created_by = ln_user_id AND line_updates IS NOT NULL;
    BEGIN
        write_to_table (
               'fetch_trx_his_filter start'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');


        l_action_tab           := ACTION_TBL_TYPE ();
        APEX_JSON.parse (p_in_filter);

        ln_user_id             := APEX_JSON.get_number (p_path => 'user_id');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'ln_user_id' || ln_user_id,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        fetch_ad_user_email (p_in_user_id => ln_user_id, p_out_user_name => lv_username, p_out_display_name => lv_display_name
                             , p_out_email_id => lv_email_id);

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_username' || lv_username,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        lv_so_number           := APEX_JSON.get_varchar2 (p_path => 'order_number');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in fetch_trx_his_filter parsing data lv_so_number: '
            || lv_so_number,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');
        lv_cust_name           := APEX_JSON.get_varchar2 (p_path => 'customer_name');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in fetch_trx_his_filter parsing data lv_cust_name: '
            || lv_cust_name,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');
        lv_cus_number          :=
            APEX_JSON.get_varchar2 (p_path => 'customer_number');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in fetch_trx_his_filter parsing data lv_cus_number: '
            || lv_cus_number,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');
        lv_cus_po_num          :=
            APEX_JSON.get_varchar2 (p_path => 'customer_po_number');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in fetch_trx_his_filter parsing data lv_cus_po_num: '
            || lv_cus_po_num,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        lv_cart_crtn_date_fm   :=
            APEX_JSON.get_varchar2 (p_path => 'cart_creation_date_from');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in fetch_trx_his_filter parsing data lv_cart_crtn_date_fm: '
            || lv_cart_crtn_date_fm,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');
        lv_cart_crtn_date_to   :=
            APEX_JSON.get_varchar2 (p_path => 'cart_creation_date_to');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in fetch_trx_his_filter parsing data lv_cart_crtn_date_to: '
            || lv_cart_crtn_date_to,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        ln_count               :=
            APEX_JSON.get_count (p_path => 'user_action');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in fetch_trx_his_filter parsing data ln_count: ' || ln_count,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        IF ln_count <> 0
        THEN
            FOR i IN 1 .. ln_count
            LOOP
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                    'in ln_count loop: ',
                    'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');
                l_action_tab.EXTEND;
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                    'in   loop extendd: ',
                    'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

                l_action_tab (i)   := ACTION_REC_TYPE (NULL);
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                    'in   l_action_tab ct: ',
                    'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

                l_action_tab (i).attribute1   :=
                    APEX_JSON.get_varchar2 (
                        p_path   => 'user_action[%d].action',
                        p0       => i);
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'in fetch_trx_his_filter lv_action: '
                    || l_action_tab (i).attribute1,
                    'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');
            END LOOP;
        END IF;

        FOR user_action_rec IN user_action_cur
        LOOP
            lv_string   := user_action_rec.usr_action || ',';

            LOOP
                EXIT WHEN lv_string IS NULL;
                ln_count1   := INSTR (lv_string, ',');
                lv_actions_list.EXTEND;
                lv_actions_list (lv_actions_list.COUNT)   :=
                    LTRIM (RTRIM (SUBSTR (lv_string, 1, ln_count1 - 1)));
                lv_string   :=
                    SUBSTR (lv_string, ln_count1 + 1);
            END LOOP;
        END LOOP;

        tmp                    := SET (lv_actions_list);

        lv_user_action_cur     :=
               'SELECT DISTINCT  xogh.batch_id,xogh.status,xogh.creation_date 
					     FROM xxdo.xxd_ont_genesis_dtls_stg_t xogd,xxdo.xxd_ont_genesis_hdr_stg_t xogh 
					    WHERE xogh.created_by      = xogd.created_by
						  AND xogh.batch_id=xogd.batch_id
						  AND xogd.created_by      ='
            || ln_user_id;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_user_action_cur 1st : ' || lv_user_action_cur,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        IF lv_so_number IS NOT NULL
        THEN
            lv_so_num_cond   :=
                ' AND xogd.sales_order_num = ''' || lv_so_number || '''';
        ELSE
            lv_so_num_cond   := ' AND 1=1';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_so_num_cond  : ' || lv_so_num_cond,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        IF lv_cus_number IS NOT NULL
        THEN
            lv_cus_num_cond   :=
                ' AND xogd.account_number = ''' || lv_cus_number || '''';
        ELSE
            lv_cus_num_cond   := ' AND 1=1';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_cus_num_cond  : ' || lv_cus_num_cond,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        IF lv_cus_po_num IS NOT NULL
        THEN
            lv_cus_po_num_cond   :=
                ' AND xogd.cust_po_num = ''' || lv_cus_po_num || '''';
        ELSE
            lv_cus_po_num_cond   := ' AND 1=1';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_cus_po_num_cond  : ' || lv_cus_po_num_cond,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        IF (lv_cart_crtn_date_fm IS NOT NULL OR lv_cart_crtn_date_to IS NOT NULL)
        THEN
            lv_ctrn_dt_cond   :=
                   ' AND trunc(xogd.creation_date) BETWEEN TO_DATE(Translate(SUBSTR ('''
                || lv_cart_crtn_date_fm
                || ''' ,'
                || '1,19),''T'','' '''
                || '),''YYYY-MM-DD HH24:MI:SS'') AND TO_DATE(Translate(SUBSTR ('''
                || lv_cart_crtn_date_to
                || ''' ,'
                || '1,19),''T'','' '''
                || '),''YYYY-MM-DD HH24:MI:SS'')';
        ELSE
            lv_ctrn_dt_cond   := ' AND 1=1';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_ctrn_dt_cond  : ' || lv_ctrn_dt_cond,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        IF ln_count <> 0
        THEN
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'ln_count count  : ' || ln_count,
                'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

            FOR i IN 1 .. l_action_tab.COUNT
            LOOP
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                    'i  : ' || i,
                    'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

                IF i = 1
                THEN
                    lv_user_act_cond   :=
                           ' AND (xogd.hdr_updates like'
                        || '''%'
                        || l_action_tab (i).attribute1
                        || '%'''
                        || ' OR xogd.line_updates like'
                        || '''%'
                        || l_action_tab (i).attribute1
                        || '%''';
                ELSE
                    lv_user_act_cond   :=
                           lv_user_act_cond
                        || ' OR xogd.hdr_updates like'
                        || '''%'
                        || l_action_tab (i).attribute1
                        || '%'''
                        || ' OR xogd.line_updates like'
                        || '''%'
                        || l_action_tab (i).attribute1
                        || '%''';
                END IF;

                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                    'lv_user_act_cond  : ' || lv_user_act_cond,
                    'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');
            END LOOP;

            lv_user_act_cond   := lv_user_act_cond || ')';
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'lv_user_act_cond last  : ' || lv_user_act_cond,
                'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');
        END IF;

        lv_user_action_cur     :=
               lv_user_action_cur
            || lv_so_num_cond
            || lv_cus_num_cond
            || lv_cus_po_num_cond
            || lv_ctrn_dt_cond
            || lv_user_act_cond
            || ' ORDER BY  xogh.batch_id DESC';
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_user_action_cur last  : ' || lv_user_action_cur,
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        OPEN hdr_records_cur FOR lv_user_action_cur;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in cur  : ',
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        FETCH hdr_records_cur BULK COLLECT INTO hdr_records_rec;

        CLOSE hdr_records_cur;

        APEX_JSON.initialize_clob_output;
        APEX_JSON.open_array;

        BEGIN
            FOR i IN hdr_records_rec.FIRST .. hdr_records_rec.LAST
            LOOP
                APEX_JSON.open_object;
                APEX_JSON.write ('batch_id', hdr_records_rec (i).batch_id);
                APEX_JSON.write ('status', hdr_records_rec (i).status);
                APEX_JSON.write ('creation_date',
                                 hdr_records_rec (i).creation_date);
                APEX_JSON.close_object;
            END LOOP;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                    'NO DATA FOUND  : ',
                    'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');
                NULL;                                 --APEX_JSON.open_object;
                NULL;                                --APEX_JSON.close_object;
            WHEN OTHERS
            THEN
                NULL;                                 --APEX_JSON.open_object;
                NULL;                               -- APEX_JSON.close_object;
        END;

        COMMIT;

        APEX_JSON.close_array;

        p_out_hdr              := APEX_JSON.get_clob_output;

        APEX_JSON.free_output;
        APEX_JSON.initialize_clob_output;

        APEX_JSON.open_object ('Filters');                                -- {
        APEX_JSON.open_array ('cust_po_num');

        FOR cust_po_num_rec IN cust_po_num_cur
        LOOP
            APEX_JSON.write (cust_po_num_rec.cust_po_num);
        END LOOP;

        APEX_JSON.close_array;

        APEX_JSON.open_array ('cust_account');                             --[

        FOR cust_name_rec IN cust_name_cur
        LOOP
            APEX_JSON.open_object;
            APEX_JSON.write ('account_number', cust_name_rec.account_number);
            APEX_JSON.write ('account_name', cust_name_rec.account_name);
            APEX_JSON.close_object;
        END LOOP;

        APEX_JSON.close_array;

        APEX_JSON.open_array ('user_actions');                             --[

        FOR i IN 1 .. tmp.COUNT
        LOOP
            APEX_JSON.write (tmp (i));
        END LOOP;

        APEX_JSON.close_array;
        APEX_JSON.close_object;

        p_out_results          := APEX_JSON.get_clob_output;
        APEX_JSON.free_output;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_err_msg   :=
                   'Error while fetching history header details for user '
                || lv_display_name;
            write_to_table (
                   'Error while fetching history header details for user '
                || lv_display_name,
                'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');
    END fetch_trx_his_filter;

    PROCEDURE fetch_trx_history_data_new (p_in_user_id IN NUMBER, p_out_hdr OUT SYS_REFCURSOR, p_out_results OUT CLOB
                                          , p_out_err_msg OUT VARCHAR2)
    IS
        lv_display_name   VARCHAR2 (100);
        lv_username       VARCHAR2 (100);
        lv_email_id       VARCHAR2 (100);
        lv_string         LONG;
        lv_actions_list   useract_tbl_type := useract_tbl_type ();
        ln_count          NUMBER;
        tmp               useract_tbl_type := useract_tbl_type ();

        CURSOR cust_po_num_cur IS
            SELECT DISTINCT xogd.cust_po_num
              FROM xxdo.xxd_ont_genesis_dtls_stg_t xogd
             WHERE xogd.created_by = p_in_user_id;

        CURSOR cust_name_cur IS
            SELECT DISTINCT xogd.account_number, hca.account_name
              FROM xxdo.xxd_ont_genesis_dtls_stg_t xogd, hz_cust_accounts hca
             WHERE     xogd.created_by = p_in_user_id
                   AND xogd.account_number = hca.account_number;

        CURSOR user_action_cur IS
            SELECT DISTINCT xogd.hdr_updates usr_action
              FROM xxdo.xxd_ont_genesis_dtls_stg_t xogd
             WHERE xogd.created_by = p_in_user_id AND hdr_updates IS NOT NULL
            UNION
            SELECT DISTINCT xogd.line_updates usr_action
              FROM xxdo.xxd_ont_genesis_dtls_stg_t xogd
             WHERE     xogd.created_by = p_in_user_id
                   AND line_updates IS NOT NULL;
    BEGIN
        write_to_table (
               'fetch_trx_history_data_new start'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data_new');
        fetch_ad_user_email (p_in_user_id => p_in_user_id, p_out_user_name => lv_username, p_out_display_name => lv_display_name
                             , p_out_email_id => lv_email_id);

        BEGIN
            OPEN p_out_hdr FOR   SELECT xogh.batch_id, xogh.status, xogh.creation_date
                                   FROM xxdo.xxd_ont_genesis_hdr_stg_t xogh
                                  WHERE xogh.created_by = p_in_user_id
                               ORDER BY xogh.batch_id DESC;

            write_to_table (
                'before user_action_rec start',
                'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data_new');

            FOR user_action_rec IN user_action_cur
            LOOP
                lv_string   := user_action_rec.usr_action || ',';
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                    'lv_string' || lv_string,
                    'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data_new');

                LOOP
                    EXIT WHEN lv_string IS NULL;
                    ln_count   := INSTR (lv_string, ',');
                    xxd_ont_genesis_proc_ord_pkg.write_to_table (
                        'ln_count:' || ln_count,
                        'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data_new');
                    lv_actions_list.EXTEND;
                    lv_actions_list (lv_actions_list.COUNT)   :=
                        LTRIM (RTRIM (SUBSTR (lv_string, 1, ln_count - 1)));

                    xxd_ont_genesis_proc_ord_pkg.write_to_table (
                           'lv_actions_list first: '
                        || lv_actions_list (lv_actions_list.COUNT),
                        'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data_new');

                    lv_string   :=
                        SUBSTR (lv_string, ln_count + 1);
                    xxd_ont_genesis_proc_ord_pkg.write_to_table (
                        'lv_string after:' || lv_string,
                        'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data_new');
                END LOOP;

                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                       'lv_actions_list'
                    || lv_actions_list (lv_actions_list.COUNT),
                    'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data_new');
            END LOOP;

            tmp             := SET (lv_actions_list);
            APEX_JSON.initialize_clob_output;
            APEX_JSON.open_object;                                        -- {
            APEX_JSON.open_array ('cust_po_num');

            FOR cust_po_num_rec IN cust_po_num_cur
            LOOP
                APEX_JSON.write (cust_po_num_rec.cust_po_num);
            END LOOP;

            APEX_JSON.close_array;

            APEX_JSON.open_array ('cust_account');                         --[

            FOR cust_name_rec IN cust_name_cur
            LOOP
                APEX_JSON.open_object;
                APEX_JSON.write ('account_number',
                                 cust_name_rec.account_number);
                APEX_JSON.write ('account_name', cust_name_rec.account_name);
                APEX_JSON.close_object;
            END LOOP;

            APEX_JSON.close_array;

            APEX_JSON.open_array ('user_actions');                         --[

            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'before i:',
                'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data_new');

            FOR i IN 1 .. tmp.COUNT
            LOOP
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                    'in i:' || tmp (i),
                    'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data_new');
                APEX_JSON.write (tmp (i));
            END LOOP;

            APEX_JSON.close_array;
            APEX_JSON.close_object;

            p_out_results   := APEX_JSON.get_clob_output;
            APEX_JSON.free_output;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_err_msg   :=
                       'Error while fetching history header details for user '
                    || lv_display_name;
                write_to_table (
                       'Error while fetching history header details for user '
                    || lv_display_name,
                    'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data_new');
        END;

        write_to_table (
               'fetch_trx_history_data_new end'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data_new');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_err_msg   :=
                'Error in fetch_trx_history_data_new for user ';
            write_to_table (
                   'Error in fetch_trx_history_data_new for user '
                || lv_display_name,
                'xxd_ont_genesis_proc_ord_pkg.fetch_trx_history_data_new');
    END fetch_trx_history_data_new;

    --end ver3.3

    PROCEDURE validate_header (retcode         OUT VARCHAR2,
                               errbuff         OUT VARCHAR2,
                               p_hdr_attr   IN     hdrRecTyp)
    IS
    BEGIN
        IF p_hdr_attr.hdr_action = 'C'
        THEN
            IF p_hdr_attr.hdr_cancel_reason IS NULL
            THEN
                retcode   := 'N';
                write_to_table (
                    'Header cancel reason cannot be null',
                    'xxd_ont_genesis_proc_ord_pkg.validate_header');
            ELSE
                retcode   := 'Y';
            END IF;
        ELSE
            retcode   := 'Y';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 'N';
            write_to_table ('Error in validate_header ',
                            'xxd_ont_genesis_proc_ord_pkg.validate_header');
    END validate_header;

    PROCEDURE validate_line (retcode          OUT VARCHAR2,
                             errbuff          OUT VARCHAR2,
                             p_line_attr   IN     lineRecTyp)
    IS
    BEGIN
        IF     p_line_attr.new_qty >= 0
           AND p_line_attr.new_qty < p_line_attr.orig_qty
           AND p_line_attr.lne_action <> 'A'
        THEN
            IF p_line_attr.line_reason IS NULL
            THEN
                retcode   := 'N';
                write_to_table ('Line cancel reason cannot be null',
                                'xxd_ont_genesis_proc_ord_pkg.validate_line');
            ELSE
                retcode   := 'Y';
            END IF;
        ELSE
            retcode   := 'Y';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 'N';
            write_to_table ('Error in validate_line ',
                            'xxd_ont_genesis_proc_ord_pkg.validate_line');
    END validate_line;

    PROCEDURE process_order_header_line (p_in_hdr_called IN OUT VARCHAR2, p_header_rec IN oe_order_pub.header_rec_type, p_action_request_tbl IN oe_order_pub.request_tbl_type
                                         , p_line_tbl IN oe_order_pub.line_tbl_type, p_out_err_msg OUT VARCHAR2, p_out_ret_code OUT VARCHAR2)
    IS
        lv_ret_code           VARCHAR2 (1) := 'N';
        lv_err_msg            VARCHAR2 (2000) := '';
        lv_line_success       VARCHAR2 (1) := 'N';
        lt_hdr_rec_x          oe_order_pub.header_rec_type;
        l_temp_hdr_rec        oe_order_pub.header_rec_type;
        l_temp_actn_req_tbl   oe_order_pub.request_tbl_type;
        l_temp_line_tbl       oe_order_pub.line_tbl_type;
    BEGIN
        l_temp_hdr_rec        := oe_order_pub.g_miss_header_rec;
        l_temp_line_tbl (1)   := oe_order_pub.g_miss_line_rec;
        write_to_table (
            'in process_order_header_line ' || p_header_rec.header_id,
            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
        write_to_table (
            'in process_order_header_line ' || p_header_rec.request_date,
            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

        write_to_table (
            'l_temp_line_tbl line_id ' || l_temp_line_tbl (1).line_id,
            'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

        write_to_table ('l_temp_hdr_rec hdr id ' || l_temp_hdr_rec.header_id,
                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

        --l_temp_hdr_rec := p_header_rec;
        --l_temp_hdr_rec = process to empty all the fiedls;
        --call process_order for line updates
        process_order (lv_err_msg, lv_ret_code, lt_hdr_rec_x,
                       l_temp_hdr_rec, l_temp_actn_req_tbl, p_line_tbl);
        write_to_table ('lv_ret_code111 ' || lv_ret_code,
                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
        write_to_table ('lv_err_msg111 ' || lv_err_msg,
                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
        write_to_table ('lv_line_success11 ' || lv_line_success,
                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
        write_to_table ('p_in_hdr_called11 ' || p_in_hdr_called,
                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

        IF lv_ret_code = fnd_api.g_ret_sts_success
        THEN
            lv_line_success   := 'Y';
            --p_header_rec := oe_order_pub.g_miss_header_rec;
            write_to_table (
                'success in process order api in process_order_header_line',
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

            COMMIT;
            p_out_err_msg     := lv_err_msg;
            p_out_ret_code    := lv_ret_code;
        ELSE
            p_out_err_msg    := lv_err_msg;
            p_out_ret_code   := lv_ret_code;
            DBMS_OUTPUT.put_line ('Failed to Modify Sales Order');
            ROLLBACK;
            write_to_table (
                'Error in process order api from process_order_header_line',
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
        --is_success = process_order(l_temp_header, , l_line_tbl); this is for line
        END IF;


        IF lv_line_success = 'Y' AND p_in_hdr_called = 'N'
        THEN
            write_to_table (
                'call header update',
                'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
            --call process_order for header updates
            process_order (lv_err_msg,
                           lv_ret_code,
                           lt_hdr_rec_x,
                           p_header_rec,
                           p_action_request_tbl,
                           l_temp_line_tbl);

            IF lv_ret_code = fnd_api.g_ret_sts_success
            THEN
                write_to_table (
                    'success in process order api header update ',
                    'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
                p_in_hdr_called   := 'Y';
                p_out_err_msg     := lv_err_msg;
                p_out_ret_code    := lv_ret_code;
                COMMIT;
            ELSE
                p_out_err_msg    := lv_err_msg;
                p_out_ret_code   := lv_ret_code;
                DBMS_OUTPUT.put_line ('Failed to Modify Sales Order header');
                write_to_table (
                    'Failed to Modify Sales Order header ',
                    'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');

                ROLLBACK;                                 --dont call the line
            END IF; -- this similar to current code hearder logic this is for header
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            write_to_table (
                'Unexpected Error in process_order_header_line:  ',
                'xxd_ont_genesis_proc_ord_pkg.process_order_header_line');
    END process_order_header_line;

    --process_order procedure
    PROCEDURE process_order (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_out_hdr_rec_x OUT oe_order_pub.header_rec_type
                             , p_in_header_rec IN oe_order_pub.header_rec_type, p_in_action_request_tbl IN oe_order_pub.request_tbl_type, p_in_line_tbl IN oe_order_pub.line_tbl_type)
    IS
        l_header_rec_x             oe_order_pub.header_rec_type;
        l_line_tbl_x               oe_order_pub.line_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        l_return_status            VARCHAR2 (1000);
        l_msg_count                NUMBER;
        l_msg_data                 VARCHAR2 (1000);
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
        l_msg_index_out            NUMBER (10);
        l_message_data             VARCHAR2 (2000);
        l_hdr_id                   NUMBER;
    BEGIN
        write_to_table ('in process order procedure ',
                        'xxd_ont_genesis_proc_ord_pkg.process_order_api_p');
        l_return_status   := NULL;
        l_msg_data        := NULL;
        l_message_data    := NULL;
        oe_order_pub.process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_true,
            p_return_values            => fnd_api.g_true,
            p_action_commit            => fnd_api.g_true,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data,
            p_header_rec               => p_in_header_rec,
            p_line_tbl                 => p_in_line_tbl,
            p_action_request_tbl       => p_in_action_request_tbl,
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
            x_action_request_tbl       => x_action_request_tbl);


        write_to_table ('process_order API status: ' || l_return_status,
                        'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');

        p_out_hdr_rec_x   := l_header_rec_x;

        IF l_return_status <> fnd_api.g_ret_sts_success
        THEN
            FOR i IN 1 .. l_msg_count
            LOOP
                oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                , p_msg_index_out => l_msg_index_out);

                l_message_data   :=
                    SUBSTR (l_message_data || l_msg_data, 1, 2000);
            END LOOP;

            write_to_table (
                'process_order API  Error: ' || l_message_data,
                'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');
        END IF;

        retcode           := l_return_status;
        errbuf            := l_message_data;
        p_out_hdr_rec_x   := l_header_rec_x;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_to_table (
                'Unexpected Error in process_order:  ' || l_message_data,
                'xxd_ont_genesis_proc_ord_pkg.fetch_trx_his_filter');
    END process_order;
END xxd_ont_genesis_proc_ord_pkg;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_GENESIS_PROC_ORD_PKG TO XXORDS
/
