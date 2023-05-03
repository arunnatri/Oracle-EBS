--
-- XXD_ONT_XFER_REQ_IR_ADI_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_XFER_REQ_IR_ADI_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_XFER_REQ_IR_ADI_PKG
    * Design       : This package is  for Transfer Order Requisition and IR Creation Program (Web ADI)
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date          Version#   Name                    Comments
    -- ===============================================================================
    -- 16-Mar-2022   1.0        Jayarajan A K           Initial Version
    -- 07-Jul-2022   1.1        Jayarajan A K           Modified to add TPO Order check
    -- 02-Feb-2023   1.2        Jayarajan A K           Modified as per latest UAT requirements
    -- 16-Feb-2023   1.3        Jayarajan A K           Modified for the new CPQ logic requirements identified during UAT
    -- 21-Mar-2023   1.4        Jayarajan A K           Modified for the new Inventory Aging logic and Onhand qty
    ******************************************************************************************/
    TYPE organization_rec IS RECORD
    (
        org_id                 NUMBER,
        organization_id        NUMBER,
        organization_code      VARCHAR2 (100),
        location_id            NUMBER,
        material_account_id    NUMBER,
        set_of_books_id        NUMBER
    );

    gn_resp_id                    NUMBER := apps.fnd_global.resp_id;
    gn_resp_appl_id               NUMBER := apps.fnd_global.resp_appl_id;

    gn_org_id                     NUMBER := fnd_global.org_id;
    gn_user_id                    NUMBER := fnd_global.user_id;
    gv_user_name                  VARCHAR2 (200) := FND_GLOBAL.USER_NAME;
    gn_request_id                 NUMBER := fnd_global.conc_request_id;
    gc_debug_enable               VARCHAR2 (1);
    --Start changes v1.1
    --gv_ir_interface_source_code             VARCHAR2 (40) := 'PHYSICAL_MOVE';
    gv_ir_interface_source_code   VARCHAR2 (5) := 'P_MV';
    --End changes v1.1

    gn_master_org        CONSTANT NUMBER := 106;
    gn_batchO2F_ID       CONSTANT NUMBER := 1875;

    gn_master_org_id              mtl_parameters.organization_id%TYPE;

    FUNCTION get_organization_data (pn_organization_id IN NUMBER)
        RETURN organization_rec
    IS
        lr_organization        organization_rec;
        lv_organization_code   VARCHAR2 (100);
        ln_org_id              NUMBER;
    BEGIN
        lr_organization.organization_id   := pn_organization_id;

        SELECT organization_code, operating_unit, set_of_books_id
          INTO lr_organization.organization_code, lr_organization.org_id, lr_organization.set_of_books_id
          FROM apps.org_organization_definitions
         WHERE organization_id = pn_organization_id;

        SELECT location_id
          INTO lr_organization.location_id
          FROM hr_organization_units_v
         WHERE organization_id = pn_organization_id;

        SELECT material_account
          INTO lr_organization.material_account_id
          FROM mtl_parameters
         WHERE organization_id = pn_organization_id;

        RETURN lr_organization;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN lr_organization;
    END get_organization_data;

    FUNCTION get_tpo_qty (pn_item_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_tpo_qty   NUMBER;
    BEGIN
        SELECT SUM (oola.ordered_quantity)
          INTO ln_tpo_qty
          FROM apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
         WHERE     flv.lookup_type = 'XXD_WMS_BLANKET_ISO_LIST'
               AND flv.language = USERENV ('LANG')
               AND flv.enabled_flag = 'Y'
               AND flv.lookup_code = ooha.order_number
               AND ooha.open_flag = 'Y'
               AND ooha.header_id = oola.header_id
               AND oola.open_flag = 'Y'
               AND oola.inventory_item_id = pn_item_id;

        RETURN ln_tpo_qty;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_tpo_qty   := 0;
            RETURN ln_tpo_qty;
    END get_tpo_qty;


    PROCEDURE validate_prc (p_src_org_code IN mtl_parameters.organization_code%TYPE, p_dest_org_code IN mtl_parameters.organization_code%TYPE, p_sku IN oe_order_lines_all.ordered_item%TYPE
                            , p_qty IN oe_order_lines_all.ordered_quantity%TYPE, p_group_num IN NUMBER)
    AS
        ln_inv_itm_id               mtl_system_items_b.inventory_item_id%TYPE;
        ln_cust_inventory_item_id   mtl_system_items_b.inventory_item_id%TYPE;
        ln_src_inv_org_id           mtl_parameters.organization_id%TYPE;
        ln_dest_inv_org_id          mtl_parameters.organization_id%TYPE;
        ln_ship_to_org_id           oe_headers_iface_all.ship_to_org_id%TYPE;
        ln_invoice_to_org_id        oe_headers_iface_all.invoice_to_org_id%TYPE;
        ln_deliver_to_org_id        oe_headers_iface_all.deliver_to_org_id%TYPE;
        ln_cust_account_id          hz_cust_accounts.cust_account_id%TYPE;
        ln_list_header_id           qp_list_headers.list_header_id%TYPE;
        ln_sa_header_id             oe_blanket_headers_all.header_id%TYPE;
        lc_inventory_item_brand     oe_order_headers_all.attribute5%TYPE;
        lc_customer_item_brand      oe_order_headers_all.attribute5%TYPE;
        lc_cust_item_type           oe_lines_iface_all.customer_item_id_type%TYPE;
        ld_request_date             oe_headers_iface_all.request_date%TYPE;
        ln_exists                   NUMBER DEFAULT 0;
        ln_tpo_qty                  NUMBER DEFAULT 0;
        lc_err_message              VARCHAR2 (4000);
        lc_ret_message              VARCHAR2 (4000);
        lv_brand                    VARCHAR2 (40);
        ln_record_id                NUMBER;
        lr_src_org                  organization_rec;
        lr_dest_org                 organization_rec;
        le_webadi_exception         EXCEPTION;
        lv_period_open              VARCHAR2 (1);
    BEGIN
        --Validate p_group_num
        IF p_group_num IS NULL
        THEN
            lc_err_message   := lc_err_message || 'Missing Grouping Number; ';
        ELSIF p_group_num <= 0
        THEN
            lc_err_message   := lc_err_message || 'Invalid Grouping Number; ';
        --Start changes v1.1
        ELSIF LENGTH (p_group_num) > 9
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Grouping Number should not exceed 9 digits; ';
        --Start changes v1.1
        END IF;

        -- Derive Source Inv Org ID
        BEGIN
            SELECT organization_id
              INTO ln_src_inv_org_id
              FROM mtl_parameters
             WHERE UPPER (organization_code) = UPPER (p_src_org_code);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lc_err_message   :=
                    lc_err_message || 'Invalid Source Warehouse; ';
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    SUBSTR (lc_err_message || SQLERRM, 1, 4000);
        END;

        -- Derive Dest Inv Org ID
        BEGIN
            SELECT organization_id
              INTO ln_dest_inv_org_id
              FROM mtl_parameters
             WHERE UPPER (organization_code) = UPPER (p_dest_org_code);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lc_err_message   :=
                    lc_err_message || 'Invalid Destination Warehouse; ';
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    SUBSTR (lc_err_message || SQLERRM, 1, 4000);
        END;

        --validate Source and Dest Orgs
        BEGIN
            IF     NVL (ln_src_inv_org_id, 0) <> 0
               AND NVL (ln_dest_inv_org_id, 0) <> 0
            THEN
                ln_exists   := 0;

                SELECT COUNT (*)
                  INTO ln_exists
                  FROM apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola,
                       apps.po_requisition_headers_all porh, apps.po_requisition_lines_all porl
                 WHERE     flv.lookup_type = 'XXD_WMS_BLANKET_ISO_LIST'
                       AND flv.language = USERENV ('LANG')
                       AND flv.enabled_flag = 'Y'
                       AND flv.lookup_code = ooha.order_number
                       AND ooha.header_id = oola.header_id
                       AND oola.ship_from_org_id = ln_src_inv_org_id
                       AND oola.ordered_quantity > 0
                       AND porh.requisition_header_id =
                           oola.source_document_id
                       AND porh.requisition_header_id =
                           porl.requisition_header_id
                       AND porl.destination_organization_id =
                           ln_dest_inv_org_id
                       AND porl.requisition_line_id =
                           oola.source_document_line_id
                       AND porl.item_id = oola.inventory_item_id
                       AND porl.source_organization_id =
                           oola.ship_from_org_id;

                IF ln_exists = 0
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'The Source/Destination org pair must belong to an active TPO; ';
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    SUBSTR (lc_err_message || SQLERRM, 1, 4000);
        END;

        -- Derive Inv Item ID
        BEGIN
            SELECT inventory_item_id
              INTO ln_inv_itm_id
              FROM mtl_system_items_b msib
             WHERE     msib.organization_id = ln_src_inv_org_id
                   AND UPPER (msib.segment1) = UPPER (p_sku)
                   AND EXISTS
                           (SELECT 1
                              FROM mtl_system_items_b dest
                             WHERE     dest.inventory_item_id =
                                       msib.inventory_item_id
                                   AND dest.organization_id =
                                       ln_dest_inv_org_id);

            -- check tpo quantity balance
            ln_tpo_qty   := get_tpo_qty (ln_inv_itm_id);

            IF p_qty <= 0
            THEN
                lc_err_message   := lc_err_message || 'Invalid Quantity; ';
            --Start changes v1.1
            --Entered SKU is not on the TPO
            ELSIF NVL (ln_tpo_qty, 0) <= 0
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Entered SKU is not on the Transfer Placeholder Order; ';
            --End changes v1.1
            --Qty not greater than available TPO Qty check
            ELSIF p_qty > ln_tpo_qty
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Entered Quantity is more than TPO Quantity; ';
            --Qty not greater than available ATR check
            ELSIF p_qty >
                  NVL (
                      xxd_inv_common_utils_x_pk.get_atr_qty_fnc (
                          ln_inv_itm_id,
                          ln_src_inv_org_id),
                      0)
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Quantity cannot be greater than available ATR; ';
            END IF;

            --Get Brand value
            BEGIN
                SELECT mc.segment1
                  INTO lv_brand
                  FROM mtl_item_categories mic, mtl_category_sets mcs, mtl_categories mc
                 WHERE     mic.category_set_id = mcs.category_set_id
                       AND mic.category_id = mc.category_id
                       AND mc.structure_id = mcs.structure_id
                       AND mcs.category_set_name = 'Inventory'
                       AND mic.inventory_item_id = ln_inv_itm_id
                       AND mic.organization_id = ln_src_inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        SUBSTR (
                               lc_err_message
                            || 'Error while fetching Brand: '
                            || SQLERRM,
                            1,
                            4000);
            END;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lc_err_message   := lc_err_message || 'Invalid SKU; ';
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    SUBSTR (lc_err_message || SQLERRM, 1, 4000);
        END;

        BEGIN
            lr_src_org    := get_organization_data (ln_src_inv_org_id);
            lr_dest_org   := get_organization_data (ln_dest_inv_org_id);

            --Check if GL Period is Open
            BEGIN
                SELECT 'Y'
                  INTO lv_period_open
                  FROM gl_period_statuses gps
                 WHERE     closing_status = 'O'
                       AND gps.application_id = 101                       --GL
                       AND gps.set_of_books_id = lr_src_org.set_of_books_id
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (gps.start_date)
                                               AND TRUNC (gps.end_date);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                        lc_err_message || 'GL Period is not Open; ';
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        SUBSTR (lc_err_message || SQLERRM, 1, 4000);
            END;

            --Check if Purchasing Period in Dest org is Open
            BEGIN
                SELECT 'Y'
                  INTO lv_period_open
                  FROM gl_period_statuses gps
                 WHERE     closing_status = 'O'
                       AND gps.application_id = 201                       --PO
                       AND gps.set_of_books_id = lr_dest_org.set_of_books_id
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (gps.start_date)
                                               AND TRUNC (gps.end_date);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Purchasing Accounting Period is not open in Dest Operating Unit; ';
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        SUBSTR (lc_err_message || SQLERRM, 1, 4000);
            END;

            --Check if INV Accting Period in Src org is Open
            BEGIN
                SELECT 'Y'
                  INTO lv_period_open
                  FROM org_acct_periods oap
                 WHERE     oap.organization_id = ln_src_inv_org_id
                       AND oap.open_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       oap.period_start_date)
                                               AND TRUNC (
                                                       oap.schedule_close_date);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Inventory Accounting Period is not open in Source Org; ';
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        SUBSTR (lc_err_message || SQLERRM, 1, 4000);
            END;

            --Check if INV Accting Period in Dest org is Open
            BEGIN
                SELECT 'Y'
                  INTO lv_period_open
                  FROM org_acct_periods oap
                 WHERE     oap.organization_id = ln_dest_inv_org_id
                       AND oap.open_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       oap.period_start_date)
                                               AND TRUNC (
                                                       oap.schedule_close_date);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Inventory Accounting Period is not open in Destination Org; ';
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        SUBSTR (lc_err_message || SQLERRM, 1, 4000);
            END;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    SUBSTR (lc_err_message || SQLERRM, 1, 4000);
        END;

        -- If no error Insert into Staging Table
        IF lc_err_message IS NULL
        THEN
            SELECT XXDO.XXD_ONT_OH_IR_XFER_SEQ.NEXTVAL
              INTO ln_record_id
              FROM DUAL;

            INSERT INTO xxdo.xxd_ont_xfer_req_ir_adi_stg_t (
                            record_id,
                            org_id,
                            src_org_id,
                            dest_org_id,
                            sku,
                            brand,
                            inventory_item_id,
                            quantity,
                            group_no,
                            status,
                            MESSAGE,
                            creation_date,
                            created_by,
                            last_update_date,
                            last_updated_by)
                 VALUES (ln_record_id,                             --record_id
                                       gn_org_id,                     --org_id
                                                  ln_src_inv_org_id, --src_org_id
                         ln_dest_inv_org_id,                     --dest_org_id
                                             UPPER (p_sku),              --sku
                                                            lv_brand,  --brand
                         ln_inv_itm_id,                    --inventory_item_id
                                        p_qty,                      --quantity
                                               p_group_num,         --group_no
                         NULL,                                        --status
                               NULL,                                 --message
                                     SYSDATE,                  --creation_date
                         gn_user_id,                              --created_by
                                     SYSDATE,               --last_update_date
                                              gn_user_id     --last_updated_by
                                                        );
        ELSE
            RAISE le_webadi_exception;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG'); -- still be ok to use this
            fnd_message.set_token ('ERROR_MESSAGE', lc_err_message);
            lc_ret_message   := fnd_message.get ();
            raise_application_error (-20000, lc_ret_message);
        WHEN OTHERS
        THEN
            lc_ret_message   := SQLERRM;
            raise_application_error (-20001, lc_ret_message);
    END validate_prc;

    --Private Functions and Procedures
    PROCEDURE insert_message (pv_message_type   IN VARCHAR2,
                              pv_message        IN VARCHAR2)
    AS
    BEGIN
        IF UPPER (pv_message_type) IN ('LOG', 'BOTH')
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
    END insert_message;

    --Wrapper around executing con current request with wait for completion
    PROCEDURE exec_conc_request (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_request_id OUT NUMBER, pv_application IN VARCHAR2 DEFAULT NULL, pv_program IN VARCHAR2 DEFAULT NULL, pv_argument1 IN VARCHAR2 DEFAULT CHR (0), pv_argument2 IN VARCHAR2 DEFAULT CHR (0), pv_argument3 IN VARCHAR2 DEFAULT CHR (0), pv_argument4 IN VARCHAR2 DEFAULT CHR (0), pv_argument5 IN VARCHAR2 DEFAULT CHR (0), pv_argument6 IN VARCHAR2 DEFAULT CHR (0), pv_argument7 IN VARCHAR2 DEFAULT CHR (0), pv_argument8 IN VARCHAR2 DEFAULT CHR (0), pv_argument9 IN VARCHAR2 DEFAULT CHR (0), pv_argument10 IN VARCHAR2 DEFAULT CHR (0), pv_argument11 IN VARCHAR2 DEFAULT CHR (0), pv_argument12 IN VARCHAR2 DEFAULT CHR (0), pv_argument13 IN VARCHAR2 DEFAULT CHR (0), pv_argument14 IN VARCHAR2 DEFAULT CHR (0), pv_argument15 IN VARCHAR2 DEFAULT CHR (0), pv_argument16 IN VARCHAR2 DEFAULT CHR (0), pv_argument17 IN VARCHAR2 DEFAULT CHR (0), pv_argument18 IN VARCHAR2 DEFAULT CHR (0), pv_argument19 IN VARCHAR2 DEFAULT CHR (0), pv_argument20 IN VARCHAR2 DEFAULT CHR (0), pv_argument21 IN VARCHAR2 DEFAULT CHR (0), pv_argument22 IN VARCHAR2 DEFAULT CHR (0), pv_argument23 IN VARCHAR2 DEFAULT CHR (0), pv_argument24 IN VARCHAR2 DEFAULT CHR (0), pv_argument25 IN VARCHAR2 DEFAULT CHR (0), pv_argument26 IN VARCHAR2 DEFAULT CHR (0), pv_argument27 IN VARCHAR2 DEFAULT CHR (0), pv_argument28 IN VARCHAR2 DEFAULT CHR (0), pv_argument29 IN VARCHAR2 DEFAULT CHR (0), pv_argument30 IN VARCHAR2 DEFAULT CHR (0), pv_argument31 IN VARCHAR2 DEFAULT CHR (0), pv_argument32 IN VARCHAR2 DEFAULT CHR (0), pv_argument33 IN VARCHAR2 DEFAULT CHR (0), pv_argument34 IN VARCHAR2 DEFAULT CHR (0), pv_argument35 IN VARCHAR2 DEFAULT CHR (0), pv_argument36 IN VARCHAR2 DEFAULT CHR (0), pv_argument37 IN VARCHAR2 DEFAULT CHR (0), pv_argument38 IN VARCHAR2 DEFAULT CHR (0), pv_wait_for_request IN VARCHAR2 DEFAULT 'Y', pn_interval IN NUMBER DEFAULT 60
                                 , pn_max_wait IN NUMBER DEFAULT 0)
    IS
        l_req_status   BOOLEAN;
        l_request_id   NUMBER;

        l_phase        VARCHAR2 (120 BYTE);
        l_status       VARCHAR2 (120 BYTE);
        l_dev_phase    VARCHAR2 (120 BYTE);
        l_dev_status   VARCHAR2 (120 BYTE);
        l_message      VARCHAR2 (2000 BYTE);
    BEGIN
        l_request_id    :=
            apps.fnd_request.submit_request (application   => pv_application,
                                             program       => pv_program,
                                             start_time    => SYSDATE,
                                             sub_request   => FALSE,
                                             argument1     => pv_argument1,
                                             argument2     => pv_argument2,
                                             argument3     => pv_argument3,
                                             argument4     => pv_argument4,
                                             argument5     => pv_argument5,
                                             argument6     => pv_argument6,
                                             argument7     => pv_argument7,
                                             argument8     => pv_argument8,
                                             argument9     => pv_argument9,
                                             argument10    => pv_argument10,
                                             argument11    => pv_argument11,
                                             argument12    => pv_argument12,
                                             argument13    => pv_argument13,
                                             argument14    => pv_argument14,
                                             argument15    => pv_argument15,
                                             argument16    => pv_argument16,
                                             argument17    => pv_argument17,
                                             argument18    => pv_argument18,
                                             argument19    => pv_argument19,
                                             argument20    => pv_argument20,
                                             argument21    => pv_argument21,
                                             argument22    => pv_argument22,
                                             argument23    => pv_argument23,
                                             argument24    => pv_argument24,
                                             argument25    => pv_argument25,
                                             argument26    => pv_argument26,
                                             argument27    => pv_argument27,
                                             argument28    => pv_argument28,
                                             argument29    => pv_argument29,
                                             argument30    => pv_argument30,
                                             argument31    => pv_argument31,
                                             argument32    => pv_argument32,
                                             argument33    => pv_argument33,
                                             argument34    => pv_argument34,
                                             argument35    => pv_argument35,
                                             argument36    => pv_argument36,
                                             argument37    => pv_argument37,
                                             argument38    => pv_argument38);
        COMMIT;

        IF l_request_id <> 0
        THEN
            IF pv_wait_for_request = 'Y'
            THEN
                l_req_status   :=
                    apps.fnd_concurrent.wait_for_request (
                        request_id   => l_request_id,
                        interval     => pn_interval,
                        max_wait     => pn_max_wait,
                        phase        => l_phase,
                        status       => l_status,
                        dev_phase    => l_dev_phase,
                        dev_status   => l_dev_status,
                        MESSAGE      => l_message);



                IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
                THEN
                    IF NVL (l_dev_status, 'ERROR') = 'WARNING'
                    THEN
                        pv_error_stat   := 'W';
                    ELSE
                        pv_error_stat   := apps.fnd_api.g_ret_sts_error;
                    END IF;

                    pv_error_msg   :=
                        NVL (
                            l_message,
                               'The request ended with a status of '
                            || NVL (l_dev_status, 'ERROR'));
                ELSE
                    pv_error_stat   := 'S';
                END IF;
            ELSE
                pv_error_stat   := 'S';
            END IF;
        ELSE
            pv_error_stat   := 'E';
            pv_error_msg    := 'No request launched';
            pn_request_id   := NULL;
            RETURN;
        END IF;

        pn_request_id   := l_request_id;
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := 'Unexpected error : ' || SQLERRM;
    END exec_conc_request;

    FUNCTION get_requisition_number (pv_interface_source_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_req_number   VARCHAR2 (50);
    BEGIN
        SELECT DISTINCT segment1
          INTO lv_req_number
          FROM po_requisition_headers_all
         WHERE interface_source_code = pv_interface_source_code;

        RETURN lv_req_number;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_requisition_number;

    --Start changes v1.4
    PROCEDURE insert_data (pn_rec_num IN NUMBER, pn_rec_qty IN NUMBER, pd_rec_dte IN DATE, pn_grp_num IN NUMBER, pn_item_id IN NUMBER, pn_orgn_id IN NUMBER
                           , pv_rtn_sts OUT VARCHAR2)
    IS
        CURSOR row_cur IS
            SELECT *
              FROM xxdo.xxd_ont_oh_ir_xfer_tmp
             WHERE     request_id = gn_request_id
                   AND group_no = pn_grp_num
                   AND organization_id = pn_orgn_id
                   AND inventory_item_id = pn_item_id
                   AND record_id = pn_rec_num
                   AND ROWNUM = 1;

        ln_record_id   NUMBER;
        ln_err_cnt     NUMBER := 0;
    BEGIN
        FOR rec IN row_cur
        LOOP
            SELECT XXD_WMS_OH_IR_XFER_SEQ.NEXTVAL INTO ln_record_id FROM DUAL;

            BEGIN
                INSERT INTO XXDO.XXD_ONT_OH_IR_XFER_STG_T (
                                RECORD_ID,
                                ORG_ID,
                                ORGANIZATION_ID,
                                SUBINVENTORY_CODE,
                                DEST_ORG_ID,
                                DEST_ORGANIZATION_ID,
                                DEST_LOCATION_ID,
                                DEST_SUBINVENTORY_CODE,
                                NEED_BY_DATE,
                                BRAND,
                                STYLE,
                                SKU,
                                INVENTORY_ITEM_ID,
                                UOM_CODE,
                                GROUP_NO,
                                QUANTITY,
                                UNIT_PRICE,
                                AGING_DATE,
                                CHARGE_ACCOUNT_ID,
                                REQ_HEADER_ID,
                                REQ_LINE_ID,
                                STATUS,
                                MESSAGE,
                                REQUEST_ID,
                                CREATION_DATE,
                                CREATED_BY,
                                LAST_UPDATE_DATE,
                                LAST_UPDATED_BY,
                                LOCATOR_NAME,
                                LOCATOR_ID)
                         VALUES (ln_record_id,
                                 rec.org_id,
                                 rec.organization_id,
                                 rec.subinventory_code,
                                 rec.dest_org_id,
                                 rec.dest_organization_id,
                                 rec.dest_location_id,
                                 rec.dest_subinventory_code,
                                 rec.need_by_date,
                                 rec.brand,
                                 rec.style,
                                 rec.sku,
                                 rec.inventory_item_id,
                                 rec.uom_code,
                                 rec.group_no,
                                 pn_rec_qty,
                                 rec.unit_price,
                                 pd_rec_dte,
                                 rec.charge_account_id,
                                 rec.req_header_id,
                                 rec.req_line_id,
                                 rec.status,
                                 rec.MESSAGE,
                                 gn_request_id,
                                 SYSDATE,
                                 fnd_global.user_id,
                                 SYSDATE,
                                 fnd_global.user_id,
                                 rec.locator_name,
                                 rec.locator_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    insert_message (
                        'LOG',
                           'Inv Org ID : '
                        || rec.organization_id
                        || ' Item : '
                        || rec.inventory_item_id
                        || ' Aging Date '
                        || TO_CHAR (pd_rec_dte, 'MM-DD-YYYY')
                        || '-'
                        || SQLERRM);
                    ln_err_cnt   := ln_err_cnt + 1;
            END;
        END LOOP;

        IF ln_err_cnt > 0
        THEN
            ROLLBACK;
            pv_rtn_sts   := 'E';
            insert_message (
                'LOG',
                'One or more records failed to insert. Batch rolled back.');
            RETURN;
        END IF;

        COMMIT;

        pv_rtn_sts   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            insert_message ('LOG', SQLERRM);
            pv_rtn_sts   := 'E';
    END insert_data;

    --End changes v1.4


    PROCEDURE insert_into_oh_table (pn_grp_num IN NUMBER, pr_src_organization IN organization_rec, pr_dest_organization IN organization_rec
                                    , pv_return_status OUT VARCHAR2)
    IS
        --no parameter
        CURSOR c_rec IS
            SELECT (SELECT operating_unit
                      FROM apps.org_organization_definitions ood
                     WHERE ood.organization_id = a.organization_id)
                       org_id,
                   a.organization_id,
                   a.organization_code,
                   a.inventory_item_id,
                   a.primary_transaction_quantity
                       ttl_qty,
                   a.transaction_uom_code
                       uom_code,
                   LEAST (
                       receipt_quantity,
                         LEAST (primary_transaction_quantity - running_total,
                                primary_transaction_quantity)
                       + receipt_quantity)
                       quantity,
                   rcv_date
                       inv_date,
                   apps.iid_to_sku (inventory_item_id)
                       sku,
                   (SELECT brand
                      FROM xxd_common_items_v vw
                     WHERE     vw.organization_id = a.organization_id
                           AND vw.inventory_item_id = a.inventory_item_id)
                       brand,
                   (SELECT style_number
                      FROM xxd_common_items_v vw
                     WHERE     vw.organization_id = a.organization_id
                           AND vw.inventory_item_id = a.inventory_item_id)
                       style,
                   (SELECT list_price_per_unit
                      FROM mtl_system_items_b msib
                     WHERE     msib.organization_id = a.organization_id
                           AND msib.inventory_item_id = a.inventory_item_id)
                       unit_price
              FROM (  SELECT moqd.organization_id, mp.organization_code, moqd.primary_transaction_quantity,
                             moqd.transaction_uom_code, moqd.inventory_item_id, rt.quantity receipt_quantity,
                             rt.transaction_date rcv_date, SUM (rt.quantity) OVER (PARTITION BY moqd.organization_id, moqd.inventory_item_id--ORDER BY rt.transaction_date ASC)  --v1.2
                                                                                                                                            ORDER BY rt.transaction_date DESC) --v1.2
                                                                                                                                                                               AS running_total
                        --Start changes v1.4
                        FROM (  SELECT moqd1.organization_id, SUM (moqd1.primary_transaction_quantity) primary_transaction_quantity, moqd1.inventory_item_id,
                                       moqd1.transaction_uom_code
                                  FROM apps.mtl_onhand_quantities_detail moqd1, xxdo.xxd_ont_xfer_req_ir_adi_stg_t stg
                                 WHERE     stg.src_org_id =
                                           pr_src_organization.organization_id
                                       AND stg.dest_org_id =
                                           pr_dest_organization.organization_id
                                       AND stg.group_no = pn_grp_num
                                       AND stg.request_id = gn_request_id
                                       AND moqd1.inventory_item_id =
                                           stg.inventory_item_id
                                       AND moqd1.organization_id = stg.src_org_id
                              GROUP BY moqd1.organization_id, moqd1.inventory_item_id, moqd1.transaction_uom_code)
                             moqd,
                             /*
                             FROM (  SELECT stg.src_org_id organization_id,
                                            SUM (stg.quantity) primary_transaction_quantity,
                                            stg.inventory_item_id,
                                            msib.primary_uom_code transaction_uom_code
                                       FROM apps.mtl_system_items_b msib,
                 xxdo.xxd_ont_xfer_req_ir_adi_stg_t stg
                                      WHERE stg.src_org_id = pr_src_organization.organization_id
                                            AND stg.dest_org_id = pr_dest_organization.organization_id
                 AND stg.group_no = pn_grp_num
                 AND stg.request_id = gn_request_id
                 AND msib.inventory_item_id = stg.inventory_item_id
                                            AND msib.organization_id = stg.src_org_id
                                   GROUP BY stg.src_org_id,
                                            stg.inventory_item_id,
                                            msib.primary_uom_code) moqd,
              */
                             --End changes v1.4
                              (SELECT *
                                 FROM (  SELECT rt1.organization_id,
                                                NVL (
                                                    TO_DATE (prla.attribute11),
                                                    TRUNC (rt1.transaction_date))
                                                    transaction_date,
                                                  SUM (rt1.quantity)
                                                - SUM (
                                                      NVL (
                                                          (SELECT SUM (ordered_quantity) iso_qty
                                                             FROM oe_order_headers_all ooha, oe_order_lines_all oola, po_requisition_lines_all prla1,
                                                                  po_requisition_headers_all prha1
                                                            WHERE     ooha.header_id =
                                                                      oola.header_id
                                                                  AND oola.order_source_id =
                                                                      10
                                                                  AND oola.inventory_item_id =
                                                                      prla1.item_id
                                                                  AND oola.source_document_line_id =
                                                                      prla1.requisition_line_id
                                                                  AND prla1.requisition_header_id =
                                                                      prha1.requisition_header_id
                                                                  AND NVL (
                                                                          prla1.cancel_flag,
                                                                          'N') =
                                                                      'N'
                                                                  AND prha1.interface_source_code LIKE
                                                                          'PHYSICAL_MOVE-%'
                                                                  AND oola.inventory_item_id =
                                                                      rsl.item_id
                                                                  AND oola.ship_from_org_id =
                                                                      rsl.to_organization_id
                                                                  AND NVL (
                                                                          TO_DATE (
                                                                              prla.attribute11),
                                                                          TRUNC (
                                                                              rt1.transaction_date)) =
                                                                      TO_DATE (
                                                                          prla1.attribute11)),
                                                          0))        --End 1.1
                                                    quantity,
                                                rsl.item_id
                                           FROM (  SELECT TRUNC (transaction_date) transaction_date, shipment_line_id, organization_id,
                                                          SUM (quantity) quantity
                                                     FROM rcv_transactions
                                                    WHERE     transaction_type =
                                                              'DELIVER'
                                                          AND destination_type_code =
                                                              'INVENTORY'
                                                          AND source_document_code IN
                                                                  ('PO', 'REQ')
                                                 GROUP BY TRUNC (transaction_date), shipment_line_id, organization_id)
                                                rt1,
                                                rcv_shipment_lines rsl,
                                                (SELECT requisition_line_id, attribute11
                                                   FROM po_requisition_lines_all
                                                  WHERE attribute11 IS NOT NULL)
                                                prla
                                          WHERE     rt1.shipment_line_id =
                                                    rsl.shipment_line_id
                                                AND rsl.requisition_line_id =
                                                    prla.requisition_line_id(+)
                                       GROUP BY rt1.organization_id, NVL (TO_DATE (prla.attribute11), TRUNC (rt1.transaction_date)), rsl.item_id)
                                      a
                                WHERE a.quantity > 0) rt,
                             mtl_parameters mp
                       WHERE     1 = 1
                             AND moqd.organization_id = rt.organization_id
                             AND moqd.inventory_item_id = rt.item_id
                             AND moqd.organization_id = mp.organization_id
                             AND mp.organization_id =
                                 pr_src_organization.organization_id
                    ORDER BY moqd.organization_id, moqd.inventory_item_id, rt.transaction_date ASC)
                   a
             WHERE   LEAST (primary_transaction_quantity - running_total,
                            primary_transaction_quantity)
                   + receipt_quantity >
                   0
            UNION
            SELECT (SELECT operating_unit
                      FROM apps.org_organization_definitions ood
                     WHERE ood.organization_id = moqd.organization_id)
                       org_id,
                   moqd.organization_id,
                   organization_code,
                   inventory_item_id,
                   primary_transaction_quantity,
                   transaction_uom_code,
                     primary_transaction_quantity
                   - NVL (
                         (SELECT SUM (rt1.quantity)
                            FROM rcv_transactions rt1, rcv_shipment_lines rsl
                           WHERE     transaction_type = 'DELIVER'
                                 AND rt1.source_document_code IN
                                         ('PO', 'REQ')
                                 AND rt1.shipment_line_id =
                                     rsl.shipment_line_id
                                 AND moqd.organization_id =
                                     rt1.organization_id
                                 AND moqd.inventory_item_id = rsl.item_id),
                         0)
                       qty,
                   TRUNC (SYSDATE - 30, 'month') + 14
                       inv_date,
                   apps.iid_to_sku (inventory_item_id)
                       sku,
                   (SELECT brand
                      FROM xxd_common_items_v vw
                     WHERE     vw.organization_id = moqd.organization_id
                           AND vw.inventory_item_id = moqd.inventory_item_id)
                       brand,
                   (SELECT style_number
                      FROM xxd_common_items_v vw
                     WHERE     vw.organization_id = moqd.organization_id
                           AND vw.inventory_item_id = moqd.inventory_item_id)
                       style,
                   (SELECT list_price_per_unit
                      FROM mtl_system_items_b msib
                     WHERE     msib.organization_id = moqd.organization_id
                           AND msib.inventory_item_id =
                               moqd.inventory_item_id)
                       unit_price
              --Start changes v1.4
              FROM (  SELECT moqd1.organization_id, SUM (moqd1.primary_transaction_quantity) primary_transaction_quantity, moqd1.inventory_item_id,
                             moqd1.transaction_uom_code
                        FROM apps.mtl_onhand_quantities_detail moqd1, xxdo.xxd_ont_xfer_req_ir_adi_stg_t stg
                       WHERE     stg.src_org_id =
                                 pr_src_organization.organization_id
                             AND stg.dest_org_id =
                                 pr_dest_organization.organization_id
                             AND stg.group_no = pn_grp_num
                             AND stg.request_id = gn_request_id
                             AND moqd1.inventory_item_id =
                                 stg.inventory_item_id
                             AND moqd1.organization_id = stg.src_org_id
                    GROUP BY moqd1.organization_id, moqd1.inventory_item_id, moqd1.transaction_uom_code)
                   moqd,
                   /*
                     FROM (  SELECT stg.src_org_id organization_id,
                                 SUM (stg.quantity) primary_transaction_quantity,
                  stg.inventory_item_id,
                  msib.primary_uom_code transaction_uom_code
                   FROM apps.mtl_system_items_b msib,
                     xxdo.xxd_ont_xfer_req_ir_adi_stg_t stg
                  WHERE stg.src_org_id = pr_src_organization.organization_id
                   AND stg.dest_org_id = pr_dest_organization.organization_id
                  AND stg.group_no = pn_grp_num
                  AND stg.request_id = gn_request_id
                  AND msib.inventory_item_id = stg.inventory_item_id
                  AND msib.organization_id = stg.src_org_id
                  GROUP BY stg.src_org_id,
                   stg.inventory_item_id,
                  msib.primary_uom_code) moqd,
             */
                   --End changes v1.4
                   mtl_parameters mp
             WHERE     1 = 1
                   AND primary_transaction_quantity >
                       NVL (
                           (SELECT SUM (rt1.quantity)
                              FROM rcv_transactions rt1,
                                   rcv_shipment_lines rsl,
                                   (SELECT requisition_line_id, attribute11
                                      FROM po_requisition_lines_all
                                     WHERE attribute11 IS NOT NULL) prla1
                             WHERE     transaction_type = 'DELIVER'
                                   AND rt1.source_document_code IN
                                           ('PO', 'REQ')
                                   AND rt1.shipment_line_id =
                                       rsl.shipment_line_id
                                   AND moqd.organization_id =
                                       rt1.organization_id
                                   AND moqd.inventory_item_id = rsl.item_id
                                   AND rt1.requisition_line_id =
                                       prla1.requisition_line_id(+)),
                           0)
                   AND moqd.organization_id = mp.organization_id
                   AND mp.organization_id =
                       pr_src_organization.organization_id
            ORDER BY 2, 4, 8 DESC;

        ln_record_id           NUMBER;
        ld_need_by_date        DATE;
        ln_group_number        NUMBER := 1;
        ln_rec_number          NUMBER := 1;
        n_cnt                  NUMBER;
        ln_inventory_item_id   NUMBER;
        ln_err_cnt             NUMBER := 0;
        ln_locator_id          NUMBER;

        --Start changes v1.3
        ln_tot_qty             NUMBER;
        ln_new_qty             NUMBER;
        ln_last_id             NUMBER;

        CURSOR itm_cur IS
              SELECT inventory_item_id,
                     (SELECT conversion_rate
                        FROM apps.mtl_uom_conversions muc
                       WHERE     muc.inventory_item_id = stg.inventory_item_id
                             AND muc.uom_code = 'CSE') cpq,
                     SUM (quantity) tot_qty
                FROM xxdo.xxd_ont_oh_ir_xfer_stg_t stg
               WHERE request_id = gn_request_id AND group_no = pn_grp_num
            GROUP BY inventory_item_id;

        CURSOR rec_cur (p_itm_id NUMBER)
        IS
              SELECT record_id, quantity, aging_date
                FROM xxdo.xxd_ont_oh_ir_xfer_stg_t
               WHERE     request_id = gn_request_id
                     AND group_no = pn_grp_num
                     AND inventory_item_id = p_itm_id
            ORDER BY aging_date;

        --End changes v1.3

        --Start changes v1.4
        ln_rec_num             NUMBER := 0;
        ln_rec_qty             NUMBER;
        ln_rem_qty             NUMBER;
        ld_rec_dte             DATE;
        ln_adjst_qty           NUMBER;
        ln_await_qty           NUMBER;

        CURSOR stg_cur IS
              SELECT inventory_item_id, group_no, src_org_id,
                     quantity
                FROM xxdo.xxd_ont_xfer_req_ir_adi_stg_t
               WHERE request_id = gn_request_id
            ORDER BY inventory_item_id;

        CURSOR tmp_cur (p_grp_no NUMBER, p_item_id NUMBER, p_org_id NUMBER)
        IS
              SELECT inventory_item_id, organization_id, quantity,
                     aging_date, record_id
                FROM xxdo.xxd_ont_oh_ir_xfer_tmp
               WHERE     request_id = gn_request_id
                     AND group_no = p_grp_no
                     AND organization_id = p_org_id
                     AND inventory_item_id = p_item_id
                     AND quantity > 0
            ORDER BY aging_date;
    --End changes v1.4

    BEGIN
        insert_message ('LOG', 'Inside Onhand Insert Procedure');

        --Get Need By Date for req
        SELECT TRUNC (DECODE (TO_CHAR (SYSDATE, 'FMDAY'),  'FRIDAY', SYSDATE + 3,  'SATURDAY', SYSDATE + 2,  SYSDATE + 1))
          INTO ld_need_by_date
          FROM DUAL;

        /*
              BEGIN
                 SELECT inventory_location_id
                   INTO ln_locator_id
                   FROM mtl_item_locations_kfv kv
                  WHERE KV.CONCATENATED_SEGMENTS = pv_src_locator;
              EXCEPTION
                 WHEN OTHERS
                 THEN
                    ln_locator_id := NULL;
              END;

              --Get next group value from seq
              SELECT XXD_WMS_OH_IR_XFER_GRP_SEQ.NEXTVAL
                INTO ln_group_number
                FROM DUAL;
        */

        FOR rec IN c_rec
        LOOP
            --SELECT XXD_WMS_OH_IR_XFER_SEQ.NEXTVAL INTO ln_record_id FROM DUAL;  --v1.4

            BEGIN
                --Start changes v1.4
                BEGIN
                    SELECT SUM (oola.ordered_quantity)
                      INTO ln_await_qty
                      FROM oe_order_lines_all oola, oe_order_headers_all ooha, xxdo.xxd_ont_oh_ir_xfer_stg_t stg
                     WHERE     oola.inventory_item_id = stg.inventory_item_id
                           AND oola.source_document_line_id = stg.req_line_id
                           AND oola.flow_status_code = 'AWAITING_SHIPPING'
                           AND oola.header_id = ooha.header_id
                           AND ooha.order_number = stg.iso_number
                           AND ooha.org_id = stg.org_id
                           AND stg.status = 'Y'
                           AND stg.inventory_item_id = rec.inventory_item_id
                           AND stg.org_id = rec.org_id
                           AND stg.organization_id = rec.organization_id
                           AND stg.dest_organization_id =
                               pr_dest_organization.organization_id
                           AND stg.aging_date = rec.inv_date;

                    IF ln_await_qty > 0
                    THEN
                        ln_adjst_qty   := rec.quantity - ln_await_qty;
                    ELSE
                        ln_adjst_qty   := rec.quantity;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_adjst_qty   := rec.quantity;
                END;

                ln_rec_num   := ln_rec_num + 1;

                --INSERT INTO XXDO.XXD_ONT_OH_IR_XFER_STG_T
                INSERT INTO XXDO.XXD_ONT_OH_IR_XFER_TMP --End changes v1.4
                                                        (RECORD_ID, ORG_ID, ORGANIZATION_ID, SUBINVENTORY_CODE, DEST_ORG_ID, DEST_ORGANIZATION_ID, DEST_LOCATION_ID, DEST_SUBINVENTORY_CODE, NEED_BY_DATE, BRAND, STYLE, SKU, INVENTORY_ITEM_ID, UOM_CODE, GROUP_NO, QUANTITY, UNIT_PRICE, AGING_DATE, CHARGE_ACCOUNT_ID, REQ_HEADER_ID, REQ_LINE_ID, STATUS, MESSAGE, REQUEST_ID, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY, LOCATOR_NAME, LOCATOR_ID
                                                         , OLD_QTY)
                     VALUES (                          --ln_record_id,  --v1.4
                             ln_rec_num,                                --v1.4
                                         rec.org_id, rec.organization_id,
                             NULL,                             --pv_src_subinv
                                   pr_dest_organization.org_id, pr_dest_organization.organization_id, pr_dest_organization.location_id, NULL, -- rec.subinventory_code,
                                                                                                                                              ld_need_by_date, rec.brand, rec.style, --style
                                                                                                                                                                                     rec.sku, rec.inventory_item_id, rec.uom_code, pn_grp_num, --group_number
                                                                                                                                                                                                                                               ln_adjst_qty, rec.unit_price, rec.inv_date, pr_dest_organization.material_account_id, --charge_account_id,
                                                                                                                                                                                                                                                                                                                                     NULL, --rec_header_id,
                                                                                                                                                                                                                                                                                                                                           NULL, --rec_line_id
                                                                                                                                                                                                                                                                                                                                                 'N', --status,
                                                                                                                                                                                                                                                                                                                                                      NULL, --message,
                                                                                                                                                                                                                                                                                                                                                            gn_request_id, --request_id,
                                                                                                                                                                                                                                                                                                                                                                           SYSDATE, fnd_global.user_id, SYSDATE, fnd_global.user_id, NULL, --pv_src_locator
                                                                                                                                                                                                                                                                                                                                                                                                                                           NULL
                             ,                                 --ln_locator_id
                               rec.quantity);
            EXCEPTION
                WHEN OTHERS
                THEN
                    insert_message (
                        'LOG',
                           'Inv Org ID : '
                        || rec.organization_id
                        || ' Item : '
                        || rec.inventory_item_id
                        || ' Aging Date '
                        || TO_CHAR (rec.inv_date, 'MM-DD-YYYY')
                        || '-'
                        || SQLERRM);
                    ln_err_cnt   := ln_err_cnt + 1;
            END;
        END LOOP;

        IF ln_err_cnt > 0
        THEN
            ROLLBACK;
            pv_return_status   := 'E';
            insert_message (
                'LOG',
                'One or more records failed to insert. Batch rolled back.');
            RETURN;
        END IF;

        COMMIT;

        --Start changes v1.4
        insert_message ('LOG', 'Comparing TPO and TMP Quantities');

        FOR stg_rec IN stg_cur
        LOOP
            ln_rem_qty   := stg_rec.quantity;

            FOR tmp_rec
                IN tmp_cur (stg_rec.group_no,
                            stg_rec.inventory_item_id,
                            stg_rec.src_org_id)
            LOOP
                IF ln_rem_qty <= tmp_rec.quantity
                THEN
                    ln_rec_qty   := ln_rem_qty;
                    ld_rec_dte   := tmp_rec.aging_date;
                    insert_data (tmp_rec.record_id, ln_rec_qty, ld_rec_dte,
                                 stg_rec.group_no, tmp_rec.inventory_item_id, tmp_rec.organization_id
                                 , pv_return_status);
                    EXIT;
                ELSE
                    ln_rec_qty   := tmp_rec.quantity;
                    ld_rec_dte   := tmp_rec.aging_date;
                    insert_data (tmp_rec.record_id, ln_rec_qty, ld_rec_dte,
                                 stg_rec.group_no, tmp_rec.inventory_item_id, tmp_rec.organization_id
                                 , pv_return_status);
                    ln_rem_qty   := ln_rem_qty - tmp_rec.quantity;
                END IF;

                IF ln_rem_qty <= 0
                THEN
                    EXIT;
                END IF;
            END LOOP;                                               --tmp loop
        END LOOP;                                                   --stg loop

        COMMIT;

        --End changes v1.4

        SELECT COUNT (*)
          INTO n_cnt
          FROM XXDO.XXD_ONT_OH_IR_XFER_STG_T
         WHERE request_id = gn_request_id AND group_no = pn_grp_num;

        IF n_cnt = 0
        THEN
            insert_message ('LOG', 'No Records inserted');
            pv_return_status   := 'E';

            RETURN;
        --Start changes v1.3
        ELSE
            insert_message ('LOG', 'Updating CPQ Quantity');

            FOR itm_rec IN itm_cur
            LOOP
                ln_tot_qty   := itm_rec.tot_qty;

                FOR lne_rec IN rec_cur (itm_rec.inventory_item_id)
                LOOP
                    IF ln_tot_qty > 0
                    THEN
                        IF MOD (lne_rec.quantity, itm_rec.cpq) = 0
                        THEN
                            ln_new_qty   := lne_rec.quantity;
                        ELSE
                            ln_new_qty   :=
                                  itm_rec.cpq
                                * ROUND (lne_rec.quantity / itm_rec.cpq, 0);
                        END IF;

                        IF ln_new_qty > ln_tot_qty
                        THEN
                            ln_new_qty   := ln_tot_qty;
                        END IF;

                        ln_tot_qty   := ln_tot_qty - ln_new_qty;
                    ELSE
                        ln_new_qty   := 0;
                    END IF;

                    --update the new qty after calculations
                    UPDATE xxdo.xxd_ont_oh_ir_xfer_stg_t stg
                       SET quantity = ln_new_qty, cpq = itm_rec.cpq, old_qty = lne_rec.quantity
                     WHERE record_id = lne_rec.record_id;

                    ln_last_id   := lne_rec.record_id;
                END LOOP;

                COMMIT;

                IF ln_tot_qty > 0
                THEN
                    UPDATE xxdo.xxd_ont_oh_ir_xfer_stg_t stg
                       SET quantity   = quantity + ln_tot_qty
                     WHERE record_id = ln_last_id;
                END IF;
            END LOOP;

            COMMIT;
        --End changes v1.3

        END IF;

        pv_return_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            insert_message ('LOG', SQLERRM);
            pv_return_status   := 'E';
    END insert_into_oh_table;

    PROCEDURE create_oh_xfer_ir (pr_src_organization IN organization_rec, pr_dest_organization IN organization_rec, pv_return_status OUT VARCHAR2)
    IS
        CURSOR c_header_rec IS
            SELECT DISTINCT group_no, dest_org_id
              FROM xxdo.xxd_ont_oh_ir_xfer_stg_t stg
             WHERE     organization_id = pr_src_organization.organization_id
                   AND request_id = gn_request_id
                   AND status = 'P';

        CURSOR c_line_rec (n_group_no NUMBER)
        IS
            SELECT record_id, org_id, dest_org_id,
                   charge_account_id, organization_id, uom_code,
                   quantity, dest_organization_id, dest_location_id,
                   inventory_item_id, aging_date, need_by_date,
                   subinventory_code
              FROM xxdo.xxd_ont_oh_ir_xfer_stg_t stg
             WHERE     group_no = n_group_no
                   AND request_id = gn_request_id
                   AND status = 'P';


        lv_src_type_code    VARCHAR2 (20) := 'INVENTORY';
        lv_dest_type_code   VARCHAR2 (20) := 'INVENTORY';
        lv_source_code      VARCHAR2 (50);
        ln_batch_id         NUMBER := 1;
        l_request_id        NUMBER;
        l_req_status        BOOLEAN;
        l_dest_org          NUMBER;
        l_req_quantity      NUMBER;
        ln_ir_rcv_qty       NUMBER;

        --TODO: need to determine these.
        ln_person_id        NUMBER;
        ln_user_id          NUMBER;


        l_phase             VARCHAR2 (80);
        l_status            VARCHAR2 (80);
        l_dev_phase         VARCHAR2 (80);
        l_dev_status        VARCHAR2 (80);
        l_message           VARCHAR2 (255);

        pv_error_stat       VARCHAR2 (1);
        pv_error_msg        VARCHAR2 (2000);

        ln_req_header_id    NUMBER;
        lv_req_number       VARCHAR2 (20);
        ln_req_ttl_qty      NUMBER := 0;

        ld_need_by_date     DATE;

        exREQHeader         EXCEPTION;
    BEGIN
        BEGIN
            SELECT employee_id
              INTO ln_person_id
              FROM fnd_user
             WHERE user_name = fnd_global.user_name;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                --User is not a buyer
                insert_message ('LOG', 'User is not a buyer');
                pv_error_stat   := pv_error_stat;
                pv_error_msg    := 'User is not a buyer';
                RETURN;
        END;



        FOR h_rec IN c_header_rec
        LOOP
            MO_GLOBAL.init ('PO');
            mo_global.set_policy_context ('S', h_rec.dest_org_id);
            FND_REQUEST.SET_ORG_ID (h_rec.dest_org_id);

            insert_message (
                'LOG',
                'Start Header Loop. Group No : ' || h_rec.group_no);

            lv_source_code   :=
                   gv_ir_interface_source_code
                || '-'
                || gn_request_id
                || '_'
                || h_rec.group_no;
            insert_message ('LOG',
                            'Create IR - Begin  Src : ' || lv_source_code);

            BEGIN
                SAVEPOINT rec_header;

                FOR l_rec IN c_line_rec (h_rec.group_no)
                LOOP
                    l_req_quantity   := l_rec.quantity;

                    IF l_req_quantity > 0
                    THEN
                        ln_req_ttl_qty   := ln_req_ttl_qty + l_req_quantity;
                        insert_message (
                            'LOG',
                               'Need by date '
                            || TO_CHAR (l_rec.need_by_date, 'DD-MON-YYYY'));

                        INSERT INTO APPS.PO_REQUISITIONS_INTERFACE_ALL (
                                        BATCH_ID,
                                        INTERFACE_SOURCE_CODE,
                                        ORG_ID,
                                        DESTINATION_TYPE_CODE,
                                        AUTHORIZATION_STATUS,
                                        PREPARER_ID,
                                        CHARGE_ACCOUNT_ID,
                                        SOURCE_TYPE_CODE,
                                        SOURCE_ORGANIZATION_ID,
                                        UOM_CODE,
                                        LINE_TYPE_ID,
                                        QUANTITY,
                                        UNIT_PRICE,
                                        DESTINATION_ORGANIZATION_ID,
                                        DELIVER_TO_LOCATION_ID,
                                        DELIVER_TO_REQUESTOR_ID,
                                        ITEM_ID,
                                        SUGGESTED_VENDOR_ID,
                                        SUGGESTED_VENDOR_SITE_ID,
                                        HEADER_DESCRIPTION,
                                        NEED_BY_DATE,
                                        LINE_ATTRIBUTE11,
                                        line_attribute15,
                                        CREATION_DATE,
                                        CREATED_BY,
                                        LAST_UPDATE_DATE,
                                        LAST_UPDATED_BY) --Place SO organization code in this field
                                 VALUES (
                                            h_rec.group_no,
                                            lv_source_code,
                                            l_rec.dest_org_id,
                                            lv_dest_type_code,
                                            'APPROVED',
                                            ln_person_id,
                                            l_rec.charge_account_id,
                                            lv_src_type_code,
                                            l_rec.organization_id,
                                            (SELECT primary_uom_code
                                               FROM apps.mtl_system_items_b
                                              WHERE     inventory_item_id =
                                                        l_rec.inventory_item_id
                                                    AND organization_id =
                                                        l_rec.dest_organization_id),
                                            1,
                                            l_req_quantity,
                                            (SELECT list_price_per_unit
                                               FROM apps.mtl_system_items_b
                                              WHERE     inventory_item_id =
                                                        l_rec.inventory_item_id
                                                    AND organization_id =
                                                        l_rec.dest_organization_id),
                                            l_rec.dest_organization_id,
                                            l_rec.dest_location_id,
                                            ln_person_id,
                                            l_rec.inventory_item_id,
                                            NULL,
                                            NULL,
                                            /*   (SELECT description
                                                  FROM apps.mtl_system_items_b
                                                 WHERE     inventory_item_id = l_rec.inventory_item_id
                                                       AND organization_id =
                                                              l_rec.dest_organization_id),*/
                                            NULL,         --header description
                                            l_rec.need_by_date,
                                            TO_CHAR (l_rec.aging_date,
                                                     'DD-MON-YYYY'),
                                            TO_CHAR (l_rec.record_id), --Pointer to sourcing staging record for mapping
                                            SYSDATE,
                                            gn_user_id,
                                            SYSDATE,
                                            gn_user_id); --Set autosource to P so that passed in vendor/vendor site is used
                    ELSE
                        insert_message (
                            'LOG',
                            'No quantity added to REQ for item : ' || apps.iid_to_sku (l_rec.inventory_item_id));
                    END IF;
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    --Roolback this REQ then proceed top next header
                    insert_message ('LOG', 'Hit rollback: ' || SQLERRM);
                    ROLLBACK TO exREQHeader;
                    CONTINUE;
            END;

            IF ln_req_ttl_qty > 0
            THEN
                BEGIN
                    SELECT MAX (need_by_date)
                      INTO ld_need_by_date
                      FROM po_requisitions_interface_all
                     WHERE batch_id = h_rec.group_no;
                --    log_errors (
                --      'IFACE : ' || TO_CHAR (ld_need_by_date, 'MM/DD/YYYY'));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;


                insert_message (
                    'LOG',
                    'Before Concurrent Request. Group No  :' || h_rec.group_no);
                insert_message ('LOG',
                                'Interface Source Code  :' || lv_source_code);

                COMMIT;

                exec_conc_request (pv_error_stat => pv_error_stat, pv_error_msg => pv_error_msg, pn_request_id => l_request_id, pv_application => 'PO', pv_program => 'REQIMPORT', pv_argument1 => lv_source_code, --Interface source code
                                                                                                                                                                                                                   pv_argument2 => h_rec.group_no, --batch id
                                                                                                                                                                                                                                                   pv_argument3 => 'INVENTORY', pv_argument4 => '', pv_argument5 => 'N', pv_argument6 => 'Y', pv_wait_for_request => 'Y'
                                   , pn_interval => 10, pn_max_wait => 0);

                IF pv_error_stat != 'S'
                THEN
                    pv_error_stat   := pv_error_stat;
                    pv_error_msg    :=
                        'Requisition import error : ' || pv_error_msg;
                    RETURN;
                END IF;

                insert_message ('LOG', 'Check Req Created');
                insert_message ('LOG', 'Source Code : ' || lv_source_code);
                insert_message ('LOG', 'Req ID : ' || l_request_id);

                --Get req created
                BEGIN
                    SELECT requisition_header_id, segment1
                      INTO ln_req_header_id, lv_req_number
                      FROM po_requisition_headers_all
                     WHERE     interface_source_code = lv_source_code
                           AND request_id = l_request_id;
                EXCEPTION
                    WHEN TOO_MANY_ROWS
                    THEN
                        --Multiple Reqs created. No error
                        NULL;
                    WHEN NO_DATA_FOUND
                    THEN
                        --If we cannot reteieve the created IR fail these records and continue to next group
                        pv_return_status   := 'E';

                        --pv_error_msg := 'Unable to find created Requisition';

                        UPDATE XXDO.XXD_ONT_OH_IR_XFER_STG_T
                           SET status = 'E', MESSAGE = 'Error retrieving created internal requisition'
                         WHERE GROUP_NO = h_rec.group_no;

                        insert_message ('LOG', 'No REQ created');

                        CONTINUE;
                END;
            ELSE
                pv_return_status   := 'E';
                insert_message ('LOG', 'No items to be added to REQ');
            END IF;

            --check/update stg records that werenot added to REQ
            UPDATE XXDO.XXD_ONT_OH_IR_XFER_STG_T stg
               SET status = 'E', MESSAGE = 'Item not added to requisition'
             WHERE     GROUP_NO = h_rec.group_no
                   AND request_id = gn_request_id
                   AND quantity > 0                                     --v1.3
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                             WHERE     prla.requisition_header_id =
                                       prha.requisition_header_id
                                   AND prha.interface_source_code =
                                       lv_source_code
                                   AND prla.attribute15 =
                                       TO_CHAR (stg.record_id));

            IF SQL%ROWCOUNT > 0
            THEN
                COMMIT;
                pv_error_msg       :=
                       'One or more items from the locator were not added to requisition: '
                    || lv_req_number;
                pv_return_status   := 'E';
                RETURN;
            END IF;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_return_status   := 'E';
    --pv_error_msg := SQLERRM;
    END create_oh_xfer_ir;

    PROCEDURE insert_iso_data (pr_src_organization IN organization_rec)
    IS
        ln_ordered_quantity     NUMBER;
        ln_remaining_quantity   NUMBER;
        lv_requisition_number   VARCHAR2 (50);

        CURSOR c_item_details IS
              SELECT stg.inventory_item_id,
                     stg.group_no,
                     msi.segment1 item_number,
                     (SELECT conversion_rate
                        FROM apps.mtl_uom_conversions muc
                       WHERE     muc.inventory_item_id = stg.inventory_item_id
                             --AND muc.disable_date IS NULL) cpq,  --v1.2
                             AND muc.uom_code = 'CSE') cpq,             --v1.2
                     SUM (stg.quantity) quantity
                FROM xxdo.xxd_ont_xfer_req_ir_adi_stg_t stg, apps.mtl_system_items_kfv msi
               WHERE     stg.src_org_id = pr_src_organization.organization_id
                     AND stg.request_id = gn_request_id
                     AND stg.status = 'P'
                     AND msi.inventory_item_id = stg.inventory_item_id
                     AND msi.organization_id = stg.src_org_id
            GROUP BY stg.inventory_item_id, stg.group_no, msi.segment1,
                     msi.primary_uom_code
            ORDER BY stg.inventory_item_id;

        CURSOR c_order_data IS
              SELECT ooha.header_id, ooha.order_number, flv.meaning
                FROM apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha
               WHERE     flv.lookup_type = 'XXD_WMS_BLANKET_ISO_LIST'
                     AND flv.language = 'US'
                     AND ooha.order_number = flv.lookup_code
                     AND flv.enabled_flag = 'Y'
            ORDER BY flv.tag;
    BEGIN
        insert_message ('LOG', 'Inside ISO Data Procedure');

        FOR r_item_details IN c_item_details
        LOOP
            ln_remaining_quantity   := r_item_details.quantity;

            FOR r_order_data IN c_order_data
            LOOP
                BEGIN
                    SELECT NVL (SUM (ordered_quantity), 0)
                      INTO ln_ordered_quantity
                      FROM apps.oe_order_lines_all
                     WHERE     header_id = r_order_data.header_id
                           AND inventory_item_id =
                               r_item_details.inventory_item_id
                           AND open_flag = 'Y';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_ordered_quantity   := 0;
                END;

                lv_requisition_number   :=
                    get_requisition_number (
                           gv_ir_interface_source_code
                        || '-'
                        || gn_request_id
                        || '_'
                        || r_item_details.group_no);



                IF     ln_ordered_quantity >= ln_remaining_quantity
                   AND ln_ordered_quantity > 0
                THEN
                    INSERT INTO XXDO.XXD_WMS_ISO_ITEM_ATP_STG (ISO_NUMBER, ITEM_NUMBER, INVENTORY_ITEM_ID, QUANTITY, INTERNAL_REQUISITION, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY
                                                               , REQUEST_ID)
                         VALUES (r_order_data.order_number, r_item_details.item_number, r_item_details.inventory_item_id, ln_remaining_quantity, lv_requisition_number, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                                 , gn_request_id);

                    EXIT;
                ELSIF     ln_ordered_quantity > 0
                      AND ln_ordered_quantity < ln_remaining_quantity
                THEN
                    ln_remaining_quantity   :=
                        ln_remaining_quantity - ln_ordered_quantity;

                    INSERT INTO XXDO.XXD_WMS_ISO_ITEM_ATP_STG (ISO_NUMBER, ITEM_NUMBER, INVENTORY_ITEM_ID, QUANTITY, INTERNAL_REQUISITION, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY
                                                               , REQUEST_ID)
                         VALUES (r_order_data.order_number, r_item_details.item_number, r_item_details.inventory_item_id, ln_ordered_quantity, lv_requisition_number, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                                 , gn_request_id);
                END IF;
            END LOOP;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            --insert_message ('LOG', 'Inside Releieve ATP Exception: ' || SQLERRM);  --v1.2
            insert_message ('LOG',
                            'Inside insert_iso_data Exception: ' || SQLERRM); --v1.2
    END insert_iso_data;

    PROCEDURE relieve_atp (pr_src_organization IN organization_rec)
    IS
        l_header_rec                   OE_ORDER_PUB.Header_Rec_Type;
        l_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type;
        l_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        l_header_adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        l_line_adj_tbl                 OE_ORDER_PUB.line_adj_tbl_Type;
        l_header_scr_tbl               OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        l_line_scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        l_request_rec                  OE_ORDER_PUB.Request_Rec_Type;
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
        p_header_rec                   OE_ORDER_PUB.Header_Rec_Type
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
        X_DEBUG_FILE                   VARCHAR2 (500);
        l_line_tbl_index               NUMBER;
        l_msg_index_out                NUMBER (10);

        CURSOR c_order_number IS
              SELECT DISTINCT iso_number, ooha.header_id
                FROM xxdo.xxd_wms_iso_item_atp_stg stg, apps.oe_order_headers_all ooha
               WHERE     stg.request_id = gn_request_id
                     AND stg.iso_number = ooha.order_number
            ORDER BY iso_number;


        CURSOR c_line_details (pv_order_number VARCHAR2)
        IS
              SELECT oola.line_id, oola.line_number, oola.header_id,
                     oola.ordered_quantity, oola.ordered_item, oola.request_date,
                     stg.quantity stg_quantity
                FROM xxdo.xxd_wms_iso_item_atp_stg stg, apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
               WHERE     stg.request_id = gn_request_id
                     AND stg.iso_number = ooha.order_number
                     AND ooha.order_number = pv_order_number
                     AND ooha.header_id = oola.header_id
                     AND oola.ordered_item = stg.item_number
                     AND oola.open_flag = 'Y'
            ORDER BY oola.ordered_quantity DESC;

        ln_ordered_quantity            NUMBER;
        ln_total_sum                   NUMBER;
        ln_initial_quantity            NUMBER;
        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;
    BEGIN
        insert_message ('LOG', 'Inside Releieve ATP Procedure');

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       'Deckers Order Management Super User - US'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := 52736;
                ln_resp_appl_id   := 660;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_batchO2F_ID,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        mo_global.Set_org_context (pr_src_organization.org_id, NULL, 'ONT');

        FOR r_order_number IN c_order_number
        LOOP
            oe_debug_pub.initialize;
            oe_msg_pub.initialize;
            l_line_tbl_index         := 1;
            l_line_tbl.delete ();
            insert_message (
                'LOG',
                'Processing for Placeholder Order: ' || r_order_number.iso_number);

            l_header_rec             := OE_ORDER_PUB.G_MISS_HEADER_REC;
            l_header_rec.header_id   := r_order_number.header_id;
            l_header_rec.operation   := OE_GLOBALS.G_OPR_UPDATE;

            FOR r_line_details IN c_line_details (r_order_number.iso_number)
            LOOP
                ln_ordered_quantity                                    :=
                    GREATEST (
                        r_line_details.ordered_quantity - r_line_details.stg_quantity,
                        0);

                insert_message (
                    'LOG',
                       'Relieving ATP for Item: '
                    || r_line_details.ordered_item
                    || ', Line Number: '
                    || r_line_details.line_number
                    || ', for quantity: '
                    || r_line_details.ordered_quantity
                    || 'Order Quantity: '
                    || r_line_details.ordered_quantity
                    || ', Stage Quantity: '
                    || r_line_details.stg_quantity
                    || ', remaining on order: '
                    || ln_ordered_quantity);
                -- Changed attributes
                l_line_tbl (l_line_tbl_index)                          :=
                    OE_ORDER_PUB.G_MISS_LINE_REC;
                l_line_tbl (l_line_tbl_index).operation                :=
                    OE_GLOBALS.G_OPR_UPDATE;
                l_line_tbl (l_line_tbl_index).header_id                :=
                    r_line_details.header_id;        -- header_id of the order
                l_line_tbl (l_line_tbl_index).line_id                  :=
                    r_line_details.line_id;       -- line_id of the order line
                l_line_tbl (l_line_tbl_index).ordered_quantity         :=
                    ln_ordered_quantity;               -- new ordered quantity
                l_line_tbl (l_line_tbl_index).Override_atp_date_code   := 'Y';
                l_line_tbl (l_line_tbl_index).change_reason            := '1'; -- change reason code
                l_line_tbl (l_line_tbl_index).schedule_arrival_date    :=
                    r_line_details.request_date;
                l_line_tbl_index                                       :=
                    l_line_tbl_index + 1;
            END LOOP;

            IF l_line_tbl.COUNT > 0
            THEN
                -- CALL TO PROCESS ORDER
                OE_ORDER_PUB.process_order (
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
                    x_header_rec               => p_header_rec,
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
                    x_action_request_tbl       => p_action_request_tbl);

                -- Check the return status
                IF l_return_status = FND_API.G_RET_STS_SUCCESS
                THEN
                    insert_message ('LOG', 'Line Quantity Update Sucessful');
                    COMMIT;
                ELSE
                    -- Retrieve messages
                    FOR i IN 1 .. l_msg_count
                    LOOP
                        Oe_Msg_Pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                        , p_msg_index_out => l_msg_index_out);
                        insert_message (
                            'LOG',
                            'message index is: ' || l_msg_index_out);
                        insert_message ('LOG', 'message is: ' || l_msg_data);
                    END LOOP;

                    insert_message ('LOG', 'Relieving ATP Failed');

                    UPDATE xxdo.xxd_wms_iso_item_atp_stg stg
                       SET attribute1   = 'Relieving ATP Failed'
                     WHERE     iso_number = r_order_number.iso_number
                           AND request_id = gn_request_id;
                END IF;
            END IF;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message ('LOG',
                            'Exception while relieving ATP: ' || SQLERRM);
    END relieve_atp;

    PROCEDURE create_internal_orders (pr_src_organization IN organization_rec, pv_return_status OUT VARCHAR2)
    IS
        ln_req_request_id   NUMBER;
        ln_resp_id          NUMBER;
        ln_resp_appl_id     NUMBER;
        lv_chr_phase        VARCHAR2 (120 BYTE);
        lv_chr_status       VARCHAR2 (120 BYTE);
        lv_chr_dev_phase    VARCHAR2 (120 BYTE);
        lv_chr_dev_status   VARCHAR2 (120 BYTE);
        lv_chr_message      VARCHAR2 (2000 BYTE);
        lb_bol_result       BOOLEAN;
    BEGIN
        insert_message ('LOG', 'Inside Create Internal Orders');

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       'Deckers Order Management User - US'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := 50744;
                ln_resp_appl_id   := 660;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        FND_REQUEST.SET_ORG_ID (pr_src_organization.org_id);

        ln_req_request_id   :=
            apps.fnd_request.submit_request (application => 'PO', -- application short name
                                                                  program => 'POCISO', -- program short name
                                                                                       start_time => SYSDATE
                                             , sub_request => FALSE);

        COMMIT;

        IF ln_req_request_id <> 0
        THEN
            insert_message (
                'LOG',
                'Create Internal Orders Request Id: ' || ln_req_request_id);
            lb_bol_result   :=
                fnd_concurrent.wait_for_request (ln_req_request_id,
                                                 60,
                                                 0,
                                                 lv_chr_phase,
                                                 lv_chr_status,
                                                 lv_chr_dev_phase,
                                                 lv_chr_dev_status,
                                                 lv_chr_message);

            IF lv_chr_dev_phase = 'COMPLETE'
            THEN
                insert_message ('LOG', 'Create Internal Completed');

                IF lv_chr_status = 'Normal'
                THEN
                    pv_return_status   := 'S';
                    insert_message (
                        'LOG',
                        'Internal order program completed successfully');
                END IF;
            ELSE
                insert_message ('LOG', 'Create Internal Not Completed Yet');
            END IF;
        END IF;
    END create_internal_orders;

    PROCEDURE run_order_import (pn_grp_no IN NUMBER, pr_src_organization IN organization_rec, pv_return_status OUT VARCHAR2)
    IS
        ln_req_request_id    NUMBER;
        ln_resp_id           NUMBER;
        ln_resp_appl_id      NUMBER;
        ln_requisition_id    NUMBER;
        lv_requisition_num   VARCHAR2 (100);
        lv_chr_phase         VARCHAR2 (120 BYTE);
        lv_chr_status        VARCHAR2 (120 BYTE);
        lv_chr_dev_phase     VARCHAR2 (120 BYTE);
        lv_chr_dev_status    VARCHAR2 (120 BYTE);
        lv_chr_message       VARCHAR2 (2000 BYTE);
        lb_bol_result        BOOLEAN;
    BEGIN
        insert_message ('LOG', 'Inside Order Import program');

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       'Deckers Order Management User - US'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := 50744;
                ln_resp_appl_id   := 660;
        END;

        BEGIN
            SELECT requisition_header_id, segment1
              INTO ln_requisition_id, lv_requisition_num
              FROM apps.po_requisition_headers_all
             WHERE interface_source_code =
                      gv_ir_interface_source_code
                   || '-'
                   || gn_request_id
                   || '_'
                   || pn_grp_no;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_requisition_id   := NULL;
        END;

        /*

        IF lv_requisition_num IS NOT NULL
        THEN
           UPDATE XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
              SET INTERNAL_REQUISITION = lv_requisition_num
            WHERE REQUEST_ID = gn_request_id;

           COMMIT;

           insert_message ('LOG',
                           'Requisition Number: ' || lv_requisition_num);
        END IF;
     */


        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        mo_global.Set_org_context (pr_src_organization.org_id, NULL, 'ONT');

        ln_req_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'ONT',              -- application short name
                program       => 'OEOIMP',               -- program short name
                argument1     => pr_src_organization.org_id, -- Operating Unit
                argument2     => 10,                         -- Internal Order
                argument3     => NVL (ln_requisition_id, NULL), -- Orig Sys Document Ref
                argument4     => NULL,                       -- operation code
                argument5     => 'N',                         -- Validate Only
                argument6     => NULL,                          -- Debug level
                argument7     => 4,                               -- Instances
                argument8     => NULL,                       -- Sold to Org Id
                argument9     => NULL,                          -- Sold To Org
                argument10    => NULL,                           -- Change seq
                argument11    => NULL,                           -- Perf Param
                argument12    => 'N',                  -- Trim Trailing Blanks
                argument13    => NULL,           -- Process Orders with no org
                argument14    => NULL,                       -- Default org id
                argument15    => 'Y'              -- Validate Desc Flex Fields
                                    );



        COMMIT;

        IF ln_req_request_id <> 0
        THEN
            insert_message ('LOG',
                            'Order Import Request Id: ' || ln_req_request_id);
            lb_bol_result   :=
                fnd_concurrent.wait_for_request (ln_req_request_id,
                                                 60,
                                                 0,
                                                 lv_chr_phase,
                                                 lv_chr_status,
                                                 lv_chr_dev_phase,
                                                 lv_chr_dev_status,
                                                 lv_chr_message);

            IF UPPER (lv_chr_dev_phase) = 'COMPLETE'
            THEN
                IF UPPER (lv_chr_status) = 'NORMAL'
                THEN
                    pv_return_status   := 'S';
                    insert_message ('LOG',
                                    'Order Import completed successfully');
                END IF;
            ELSE
                insert_message ('LOG', 'Create Internal Not Completed Yet');
            END IF;
        END IF;
    END run_order_import;

    PROCEDURE schedule_iso (pn_grp_no IN NUMBER)
    IS
        v_api_version_number           NUMBER := 1;
        v_return_status                VARCHAR2 (4000);
        v_msg_count                    NUMBER;
        v_msg_data                     VARCHAR2 (4000);

        -- IN Variables --
        v_header_rec                   oe_order_pub.header_rec_type;
        test_line                      oe_order_pub.Line_Rec_Type;
        v_line_tbl                     oe_order_pub.line_tbl_type;
        v_action_request_tbl           oe_order_pub.request_tbl_type;
        v_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;

        -- OUT Variables --
        v_header_rec_out               oe_order_pub.header_rec_type;
        v_header_val_rec_out           oe_order_pub.header_val_rec_type;
        v_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        v_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        v_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        v_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        v_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        v_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        v_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        v_line_tbl_out                 oe_order_pub.line_tbl_type;
        v_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        v_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        v_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        v_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        v_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        v_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        v_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        v_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        v_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        v_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        v_action_request_tbl_out       oe_order_pub.request_tbl_type;

        v_msg_index                    NUMBER;
        v_data                         VARCHAR2 (2000);
        v_loop_count                   NUMBER;
        v_debug_file                   VARCHAR2 (200);
        b_return_status                VARCHAR2 (200);
        b_msg_count                    NUMBER;
        b_msg_data                     VARCHAR2 (2000);
        i                              NUMBER := 0;
        j                              NUMBER := 0;
        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;

        CURSOR header_cur IS
            SELECT DISTINCT ooha.order_number, ooha.header_id order_id, ooha.org_id
              FROM apps.po_requisition_headers_all prh, apps.oe_order_headers_all ooha
             WHERE     prh.interface_source_code =
                          gv_ir_interface_source_code
                       || '-'
                       || gn_request_id
                       || '_'
                       || pn_grp_no
                   AND prh.segment1 = ooha.orig_sys_document_ref
                   AND ooha.open_flag = 'Y';

        CURSOR line_cur (p_order_id NUMBER)
        IS
            SELECT DISTINCT oel.line_id, oel.request_date
              FROM apps.oe_order_lines_all oel
             WHERE     oel.header_id = p_order_id
                   AND oel.flow_status_code IN ('BOOKED')
                   AND oel.schedule_ship_date IS NULL
                   AND oel.open_flag = 'Y';
    BEGIN
        insert_message ('LOG', 'Inside Schedule ISO procedure');

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       'Deckers Order Management Manager - US'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := 50746;
                ln_resp_appl_id   := 660;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        --mo_global.Set_org_context (95, NULL, 'ONT');



        FOR header_rec IN header_cur
        LOOP
            i   := i + 1;
            j   := 0;
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;
            mo_global.init ('ONT');
            mo_global.Set_org_context (HEADER_REC.ORG_ID, NULL, 'ONT');
            insert_message ('LOG', 'Order id: ' || header_rec.order_id);

            /*
            UPDATE XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
               SET INTERNAL_ORDER = header_rec.order_number
             WHERE REQUEST_ID = gn_request_id;

            COMMIT;
      */

            insert_message ('LOG',
                            'Order Number: ' || header_rec.order_number);

            /*v_header_rec                        := oe_order_pub.g_miss_header_rec;
            v_header_rec.operation              := OE_GLOBALS.G_OPR_UPDATE;
            v_header_rec.header_id              := header_rec .order_id; */


            --v_action_request_tbl (i) := oe_order_pub.g_miss_request_rec;

            v_line_tbl.delete ();

            FOR line_rec IN line_cur (header_rec.order_id)
            LOOP
                insert_message ('LOG', 'Order Line' || line_rec.line_id);
                j                                       := j + 1;

                v_line_tbl (j)                          := OE_ORDER_PUB.G_MISS_LINE_REC;
                v_line_tbl (j).header_id                := header_rec.order_id;
                v_line_tbl (j).line_id                  := line_rec.line_id;
                v_line_tbl (j).operation                := oe_globals.G_OPR_UPDATE;
                v_line_tbl (j).OVERRIDE_ATP_DATE_CODE   := 'Y';
                v_line_tbl (j).schedule_arrival_date    :=
                    line_rec.request_date;
            --  v_line_tbl (j).schedule_ship_date := line_rec.request_date;
            --v_line_tbl(j).schedule_action_code := oe_order_sch_util.oesch_act_schedule;


            END LOOP;

            IF j > 0
            THEN
                OE_ORDER_PUB.PROCESS_ORDER (
                    p_api_version_number       => v_api_version_number,
                    p_header_rec               => v_header_rec,
                    p_line_tbl                 => v_line_tbl,
                    p_action_request_tbl       => v_action_request_tbl,
                    p_line_adj_tbl             => v_line_adj_tbl,
                    x_header_rec               => v_header_rec_out,
                    x_header_val_rec           => v_header_val_rec_out,
                    x_header_adj_tbl           => v_header_adj_tbl_out,
                    x_header_adj_val_tbl       => v_header_adj_val_tbl_out,
                    x_header_price_att_tbl     => v_header_price_att_tbl_out,
                    x_header_adj_att_tbl       => v_header_adj_att_tbl_out,
                    x_header_adj_assoc_tbl     => v_header_adj_assoc_tbl_out,
                    x_header_scredit_tbl       => v_header_scredit_tbl_out,
                    x_header_scredit_val_tbl   => v_header_scredit_val_tbl_out,
                    x_line_tbl                 => v_line_tbl_out,
                    x_line_val_tbl             => v_line_val_tbl_out,
                    x_line_adj_tbl             => v_line_adj_tbl_out,
                    x_line_adj_val_tbl         => v_line_adj_val_tbl_out,
                    x_line_price_att_tbl       => v_line_price_att_tbl_out,
                    x_line_adj_att_tbl         => v_line_adj_att_tbl_out,
                    x_line_adj_assoc_tbl       => v_line_adj_assoc_tbl_out,
                    x_line_scredit_tbl         => v_line_scredit_tbl_out,
                    x_line_scredit_val_tbl     => v_line_scredit_val_tbl_out,
                    x_lot_serial_tbl           => v_lot_serial_tbl_out,
                    x_lot_serial_val_tbl       => v_lot_serial_val_tbl_out,
                    x_action_request_tbl       => v_action_request_tbl_out,
                    x_return_status            => v_return_status,
                    x_msg_count                => v_msg_count,
                    x_msg_data                 => v_msg_data);



                IF v_return_status = fnd_api.g_ret_sts_success
                THEN
                    COMMIT;
                    insert_message (
                        'LOG',
                        'Update Success for order number:' || header_rec.order_number);
                ELSE
                    insert_message (
                        'LOG',
                        'Update Failed for order number:' || header_rec.order_number);
                    insert_message (
                        'LOG',
                        'Reason is:' || SUBSTR (v_msg_data, 1, 1900));
                    ROLLBACK;

                    FOR i IN 1 .. v_msg_count
                    LOOP
                        v_msg_data   :=
                            oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                        insert_message ('LOG', i || ') ' || v_msg_data);
                    END LOOP;

                    insert_message ('LOG', 'v_msg_data  : ' || v_msg_data);
                END IF;
            END IF;

            COMMIT;
        END LOOP;

        COMMIT;
    -- DBMS_OUTPUT.put_line ('END OF THE PROGRAM');
    END schedule_iso;

    PROCEDURE onhand_extract (pn_src_org_id IN NUMBER)
    AS
        CURSOR cur_onhand IS
            SELECT hr_src.name
                       source_org,
                   sku,
                   quantity,
                   aging_date,
                   unit_price,
                   quantity * unit_price
                       total_cost,
                   requisition_number,
                   iso_number,
                   (SELECT attribute11
                      FROM po_requisition_lines_all prla
                     WHERE stg.req_line_id = prla.requisition_line_id)
                       ir_aging_date,
                   mp_dest.organization_code
                       dest_org
              FROM xxdo.xxd_ont_oh_ir_xfer_stg_t stg, hr_all_organization_units hr_src, mtl_parameters mp_dest
             WHERE     stg.org_id = hr_src.organization_id
                   AND stg.dest_organization_id = mp_dest.organization_id
                   AND stg.request_id = gn_request_id;
    BEGIN
        insert_message ('LOG', 'Inside Extract Procedure');

        fnd_file.put_line (
            fnd_file.output,
               'Source Org'
            || ','
            || 'SKU'
            || ','
            || 'Quantity'
            || ','
            || 'Aging Date'
            || ','
            || 'Unit Cost'
            || ','
            || 'Total Cost'
            || ','
            || 'Internal REQ #'
            || ','
            || 'Internal Sales Order #'
            || ','
            || 'Aging Date in ISO Line'
            || ','
            || 'ISO Destination Org');

        FOR rec_onhand IN cur_onhand
        LOOP
            fnd_file.put_line (
                fnd_file.output,
                   rec_onhand.source_org
                || ','
                || rec_onhand.sku
                || ','
                || rec_onhand.quantity
                || ','
                || rec_onhand.aging_date
                || ','
                || rec_onhand.unit_price
                || ','
                || rec_onhand.total_cost
                || ','
                || rec_onhand.requisition_number
                || ','
                || rec_onhand.iso_number
                || ','
                || rec_onhand.ir_aging_date
                || ','
                || rec_onhand.dest_org);
        END LOOP;

        insert_message ('LOG', 'Completed Extract Procedure');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END onhand_extract;

    --New program start (old Inv Transfer Program)
    --Transfer Order Requisition and IR Creation Program Main procedure
    PROCEDURE main_proc (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2)
    IS
        lv_brand                 VARCHAR2 (50);
        lv_src_org               VARCHAR2 (10);
        lv_dest_org              VARCHAR2 (10);
        lv_return_status         VARCHAR2 (1) := 'S';
        ln_dock_door_id          NUMBER;
        ln_org_id                NUMBER;
        lv_err_message           VARCHAR2 (2000) := NULL;

        exPreProcess             EXCEPTION;
        exProcess                EXCEPTION;

        lrec_src_organization    organization_rec;
        lrec_dest_organization   organization_rec;
        ln_src_cnt               NUMBER := 0;
        ln_dest_cnt              NUMBER := 0;
        ln_brnd_cnt              NUMBER := 0;
        ln_inv_qty               NUMBER := 0;
        ln_wrng_cnt              NUMBER := 0;
        ln_insrt_cnt             NUMBER := 0;
        lv_failure               VARCHAR2 (1) := 'N';

        -- distinct group id, where status is NULL and for that user IDENTIFIED
        CURSOR cur_grp_list IS
            SELECT DISTINCT group_no, src_org_id, dest_org_id
              FROM xxdo.xxd_ont_xfer_req_ir_adi_stg_t
             WHERE     status IS NULL
                   AND created_by = gn_user_id
                   AND TRUNC (creation_date) = TRUNC (SYSDATE);

        --Start changes v1.1
        CURSOR cur_batch_inv_qty IS
              SELECT src_org_id, inventory_item_id, sku,
                     SUM (quantity) batch_qty
                FROM xxdo.xxd_ont_xfer_req_ir_adi_stg_t
               WHERE status IS NULL AND created_by = gn_user_id
            GROUP BY src_org_id, inventory_item_id, sku;

        /*
        CURSOR cur_grp_inv_qty (grp_num NUMBER)
        IS
    SELECT src_org_id, inventory_item_id, SUM (quantity) grp_qty
      FROM xxdo.xxd_ont_xfer_req_ir_adi_stg_t
     WHERE group_no = grp_num
       AND status IS NULL
       AND created_by = gn_user_id
     GROUP BY src_org_id, inventory_item_id;
     */
        --End changes v1.1

        CURSOR cur_valid_grp IS
            SELECT DISTINCT group_no
              FROM xxdo.xxd_ont_oh_ir_xfer_stg_t
             WHERE status = 'P' AND request_id = gn_request_id;
    BEGIN
        insert_message ('LOG', 'Inside Main Procedure');
        insert_message ('LOG', 'User Name: ' || gv_user_name);
        insert_message ('LOG', 'Resp Appl ID: ' || FND_GLOBAL.RESP_APPL_ID);

        --Start changes v1.4
        insert_message ('LOG', 'Truncating Temp Table');

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ont_oh_ir_xfer_tmp';

        --End changes v1.4

        --Start changes v1.1
        FOR qty_rec IN cur_batch_inv_qty
        LOOP
            lv_failure   := 'N';
            -- Get tpo quantity balance
            ln_inv_qty   := get_tpo_qty (qty_rec.inventory_item_id);

            --Batch qty not greater than available TPO Qty check
            IF qty_rec.batch_qty > ln_inv_qty
            THEN
                lv_failure   := 'Y';
                lv_err_message   :=
                       'Total batch qty more than TPO qty for item: '
                    || qty_rec.sku;
                insert_message ('LOG', lv_err_message);
            --Batch qty not greater than available ATR check
            ELSIF qty_rec.batch_qty >
                  NVL (
                      xxd_inv_common_utils_x_pk.get_atr_qty_fnc (
                          qty_rec.inventory_item_id,
                          qty_rec.src_org_id),
                      0)
            THEN
                lv_failure   := 'Y';
                lv_err_message   :=
                       'Total batch qty more than available ATR for item: '
                    || qty_rec.sku;
                insert_message ('LOG', lv_err_message);
            END IF;

            IF lv_failure = 'Y'
            THEN
                ln_wrng_cnt   := ln_wrng_cnt + 1;

                UPDATE xxdo.xxd_ont_xfer_req_ir_adi_stg_t
                   SET status = 'E', MESSAGE = lv_err_message
                 WHERE     inventory_item_id = qty_rec.inventory_item_id
                       AND status IS NULL
                       AND created_by = gn_user_id;
            END IF;
        END LOOP;

        UPDATE xxdo.xxd_ont_xfer_req_ir_adi_stg_t stg
           SET status = 'E', MESSAGE = 'One or more items of this group could not be processed due to error'
         WHERE     status IS NULL
               AND created_by = gn_user_id
               AND EXISTS
                       (SELECT 1
                          FROM xxdo.xxd_ont_xfer_req_ir_adi_stg_t stg1
                         WHERE     status = 'E'
                               AND stg1.created_by = stg.created_by
                               AND stg1.group_no = stg.group_no
                               AND stg1.src_org_id = stg.src_org_id
                               AND stg1.dest_org_id = stg.dest_org_id
                               AND stg1.brand = stg.brand
                               AND TRUNC (stg1.creation_date) =
                                   TRUNC (stg.creation_date));

        COMMIT;

        --End changes v1.1

        FOR grp_rec IN cur_grp_list
        LOOP
            lv_failure   := 'N';

            BEGIN
                SELECT COUNT (DISTINCT src_org_id), COUNT (DISTINCT dest_org_id), COUNT (DISTINCT brand)
                  INTO ln_src_cnt, ln_dest_cnt, ln_brnd_cnt
                  FROM xxdo.xxd_ont_xfer_req_ir_adi_stg_t
                 WHERE     group_no = grp_rec.group_no
                       AND status IS NULL
                       AND created_by = gn_user_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    insert_message (
                        'LOG',
                        'Error for Group Num: ' || grp_rec.group_no);
                    ln_src_cnt    := 0;
                    ln_dest_cnt   := 0;
                    ln_brnd_cnt   := 0;
            END;

            IF ln_src_cnt = 1 AND ln_dest_cnt = 1 AND ln_brnd_cnt = 1
            THEN
                --Start changes v1.1
                /*
          FOR qty_rec IN cur_grp_inv_qty (grp_rec.group_no)
          LOOP
         -- Get tpo quantity balance
         ln_inv_qty := get_tpo_qty (qty_rec.inventory_item_id);

         --Qty not greater than available TPO Qty check
         IF qty_rec.grp_qty > ln_inv_qty THEN
           lv_failure := 'Y';
           lv_err_message := 'Total group qty more than TPO qty for item id: '||qty_rec.inventory_item_id;
         --Qty not greater than available ATR check
         ElSIF qty_rec.grp_qty > NVL(xxd_inv_common_utils_x_pk.get_atr_qty_fnc(qty_rec.inventory_item_id, qty_rec.src_org_id),0) THEN
           lv_failure := 'Y';
           lv_err_message := 'Total group qty more than available ATR for item id: '||qty_rec.inventory_item_id;
         END IF;

         IF lv_failure = 'Y' THEN

           UPDATE xxdo.xxd_ont_xfer_req_ir_adi_stg_t
           SET status = 'E',
            message = lv_err_message
            WHERE group_no = grp_rec.group_no
           AND status IS NULL
           AND created_by = gn_user_id;

           EXIT;
         END IF;

          END LOOP;
          */
                --End changes v1.1

                IF lv_failure = 'Y'
                THEN
                    insert_message (
                        'LOG',
                           'Total group qty more than TPO qty / available ATR for Group Number: '
                        || grp_rec.group_no);
                    ln_wrng_cnt   := ln_wrng_cnt + 1;
                ELSE
                    UPDATE xxdo.xxd_ont_xfer_req_ir_adi_stg_t
                       SET status = 'P', request_id = gn_request_id
                     WHERE     group_no = grp_rec.group_no
                           AND status IS NULL
                           AND created_by = gn_user_id;

                    insert_message ('LOG',
                                    'Group Number: ' || grp_rec.group_no);
                    --Get Source Organization Data
                    lrec_src_organization   :=
                        get_organization_data (grp_rec.src_org_id);


                    --Det destination Data
                    lrec_dest_organization   :=
                        get_organization_data (grp_rec.dest_org_id);

                    insert_into_oh_table (grp_rec.group_no, lrec_src_organization, lrec_dest_organization
                                          , lv_return_status);

                    IF lv_return_status = 'E'
                    THEN
                        lv_err_message   :=
                            'Insert of On Hand data failed. See log for details';
                        RAISE exPreProcess;
                    ELSE
                        ln_insrt_cnt   := ln_insrt_cnt + 1;
                    END IF;
                END IF;                                           --lv_failure
            ELSE
                UPDATE xxdo.xxd_ont_xfer_req_ir_adi_stg_t
                   SET status = 'E', MESSAGE = 'Only one Source org, Dest org and Brand allowed per Group Num'
                 WHERE     group_no = grp_rec.group_no
                       AND status IS NULL
                       AND created_by = gn_user_id;
            END IF;
        END LOOP;

        insert_message (
            'Log',
            '+Validation and Pre-Process complete                                            +');

        --Finished Pre - Processing Stg records created
        pv_errbuf    := NULL;
        pv_retcode   := 0;

        IF ln_insrt_cnt > 0
        THEN
            insert_message (
                'LOG',
                   'Updating stg records to ''P'' for request_id : '
                || gn_request_id);

            --Update staging table for added records to processing
            UPDATE XXDO.XXD_ONT_OH_IR_XFER_STG_T
               SET status   = 'P'
             WHERE request_id = gn_request_id AND status = 'N';

            COMMIT;

            create_oh_xfer_ir (lrec_src_organization,
                               lrec_dest_organization,
                               lv_return_status);

            IF lv_return_status = 'E'
            THEN
                lv_err_message   :=
                    'Error during creation of internal requisitions. See log for details';
                RAISE exProcess;
            END IF;

            BEGIN
                --Update staging records with IDs from generated IR
                UPDATE XXDO.XXD_ONT_OH_IR_XFER_STG_T
                   SET req_header_id   =
                           (SELECT prha.requisition_header_id
                              FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                             WHERE     prla.requisition_header_id =
                                       prha.requisition_header_id
                                   AND prla.attribute15 = TO_CHAR (record_id)
                                   AND prha.interface_source_code =
                                          gv_ir_interface_source_code
                                       || '-'
                                       || gn_request_id
                                       || '_'
                                       || group_no),
                       req_line_id   =
                           (SELECT prla.requisition_line_id
                              FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                             WHERE     prla.requisition_header_id =
                                       prha.requisition_header_id
                                   AND prla.attribute15 = TO_CHAR (record_id)
                                   AND prha.interface_source_code =
                                          gv_ir_interface_source_code
                                       || '-'
                                       || gn_request_id
                                       || '_'
                                       || group_no),
                       requisition_number   =
                           (SELECT prha.segment1
                              FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                             WHERE     prla.requisition_header_id =
                                       prha.requisition_header_id
                                   AND prla.attribute15 = TO_CHAR (record_id)
                                   AND prha.interface_source_code =
                                          gv_ir_interface_source_code
                                       || '-'
                                       || gn_request_id
                                       || '_'
                                       || group_no)
                 WHERE request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            --TO DO - What type of failure here
            END;


            --TODO: Any IR Failure issues?

            --IR Created Now we progress to ISO


            insert_message ('LOG', 'Insert ISO Data');
            insert_iso_data (lrec_src_organization);

            insert_message ('LOG', 'Relieve ATP');
            relieve_atp (lrec_src_organization);


            insert_message ('LOG', 'Create Internal Orders');
            create_internal_orders (lrec_src_organization, lv_return_status);

            IF lv_return_status != 'S'
            THEN
                insert_message (
                    'LOG',
                    'Error occurred in Create Internal Orders. See Log for details');
                RAISE exProcess;
            END IF;

            BEGIN
                SELECT responsibility_id, application_id
                  INTO gn_resp_id, gn_resp_appl_id
                  FROM fnd_responsibility_tl
                 WHERE     responsibility_name =
                           'Deckers Order Management User - US'
                       AND language = 'US';
            EXCEPTION
                WHEN OTHERS
                THEN
                    gn_resp_id        := 50744;
                    gn_resp_appl_id   := 660;
            END;

            do_apps_initialize (gn_user_id, gn_resp_id, gn_resp_appl_id);

            --Update customer_po_number to locator on all Order Interface Records sourced by
            --IRs created by this process

            FOR v_grp_rec IN cur_valid_grp
            LOOP
                BEGIN
                    UPDATE oe_headers_iface_all
                       SET customer_po_number   =
                               (SELECT segment1
                                  FROM po_requisition_headers_all prha
                                 WHERE prha.interface_source_code =
                                          gv_ir_interface_source_code
                                       || '-'
                                       || gn_request_id
                                       || '_'
                                       || v_grp_rec.group_no)
                     WHERE orig_sys_document_ref IN
                               (SELECT TO_CHAR (requisition_header_id)
                                  FROM po_requisition_headers_all prha
                                 WHERE prha.interface_source_code =
                                          gv_ir_interface_source_code
                                       || '-'
                                       || gn_request_id
                                       || '_'
                                       || v_grp_rec.group_no);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        insert_message (
                            'LOG',
                               'Unable to set ISO cust_po_number. Error: '
                            || SQLERRM);
                --Only ramification here is not populating ISO cust_po_number. Resulting ISO could be updated via data fix
                END;

                insert_message ('LOG', 'Run Order Import');
                run_order_import (v_grp_rec.group_no,
                                  lrec_src_organization,
                                  lv_return_status);

                IF lv_return_status != 'S'
                THEN
                    insert_message (
                        'LOG',
                        'Error occurred in Run Order Import. See Log for details');
                    RAISE exProcess;
                END IF;

                IF lv_return_status = 'S'
                THEN
                    insert_message ('LOG', 'Schedule ISO');
                    schedule_iso (v_grp_rec.group_no);
                END IF;
            END LOOP;

            --Update stg table data fields;
            UPDATE XXDO.XXD_ONT_OH_IR_XFER_STG_T stg
               SET iso_number   =
                       (SELECT DISTINCT ooha.order_number
                          FROM oe_order_headers_all ooha, oe_order_lines_all oola
                         WHERE     oola.header_id = ooha.header_id
                               AND oola.source_document_line_id =
                                   stg.req_line_id
                               AND oola.inventory_item_id =
                                   stg.inventory_item_id)
             WHERE request_id = gn_request_id;

            COMMIT;

            --Set records to E for any that do not have ISO set
            UPDATE XXDO.XXD_ONT_OH_IR_XFER_STG_T stg
               SET STATUS = 'E', MESSAGE = 'ISO line not created for this record', last_update_date = SYSDATE,
                   last_updated_by = gn_user_id
             WHERE     stg.iso_number IS NULL
                   AND request_id = gn_request_id
                   AND STATUS != 'E';


            --Update staging table status fields
            UPDATE XXDO.XXD_ONT_OH_IR_XFER_STG_T
               SET STATUS = 'Y', MESSAGE = NULL, last_update_date = SYSDATE,
                   last_updated_by = gn_user_id
             WHERE request_id = gn_request_id AND status != 'E';

            COMMIT;

            onhand_extract (lrec_src_organization.org_id);
        ELSE                                             -- ln_insrt_cnt check
            insert_message ('LOG',
                            'Exiting as no further records to be processed');
        END IF;                                          -- ln_insrt_cnt check

        IF ln_wrng_cnt > 0
        THEN
            pv_errbuf    :=
                'One or More records were not processed. Please check log for details';
            pv_retcode   := 1;
        END IF;
    EXCEPTION
        WHEN exPreProcess
        THEN
            UPDATE xxdo.xxd_ont_xfer_req_ir_adi_stg_t
               SET status = 'E', MESSAGE = lv_err_message, last_update_date = SYSDATE,
                   last_updated_by = gn_user_id
             WHERE status IS NULL AND created_by = gn_user_id;

            insert_message ('LOG', lv_err_message);
            pv_errbuf    := lv_err_message;
            pv_retcode   := 2;
        WHEN exProcess
        THEN
            UPDATE XXDO.XXD_ONT_OH_IR_XFER_STG_T
               SET STATUS = 'E', MESSAGE = lv_err_message, last_update_date = SYSDATE,
                   last_updated_by = gn_user_id
             WHERE request_id = gn_request_id;

            COMMIT;

            pv_errbuf    := lv_err_message;
            insert_message ('LOG', lv_err_message);
            pv_retcode   := 2;
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            insert_message ('LOG', SQLERRM);
            pv_retcode   := 0;
    END main_proc;
END xxd_ont_xfer_req_ir_adi_pkg;
/
