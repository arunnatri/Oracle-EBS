--
-- XXDOEC_RETURNS_EXCHANGES_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_RETURNS_EXCHANGES_PKG"
AS
    -- =======================================================
    -- Author: Vijay Reddy
    -- Create date: 07/18/2011
    -- Description: This package is used to interface customer
    -- Returns and exchanges to Oracle
    -- =======================================================
    -- Modification History
    -- Modified Date/By/Description:
    -- <Modifying Date,     Modifying Author,     Change Description>
    -- 10/21/2011           Vijay Reddy         Added add_store_credit procedure
    -- 10/18/2011           Vijay Reddy         Added KCO header ID to order header
    -- 11/10/2011           Vijay Reddy         Update Order header ship method code
    -- 11/15/2011           Vijay Reddy         populate header ship to address if passed
    --                                          Added Multi Line Order procedure
    -- 08/16/2013           MB                  Added Multi Line Return stage record procedure
    -- 04/16/2014           Robert McCarter     Added p_return_operator to returns creation
    -- 11/25/2014           1.0  Infosys        Modified for BT
    -- 02/24/2014                Infosys        Modified for HighJump project
    -- 08/10/2015           1.1  Infosys        Modified as part of BT improvement (Appropriate logging).
    -- 08/25/2015           1.2  Infosys        Modified to NOT populate SHIP FROM ORG for EBS defaulting rules to take care.
    -- 10/27/2015       1.3  Infosys           Modified to resolve UAT defect # 252.
    -- 10/28/2015       1.4  Infosys           Modified to resolve UAT defect # 211.
    -- 02/03/2017       1.5  Vijay Reddy    Modified to add SFS flag to exchange orders
    -- 03/03/2017       1.6  Vijay Reddy    Modified to check for AEX incase of shipments
    -- 04/24/2017       1.7  Vijay Reddy    Modified for ECDC project add d new parameter p_ship_from_org_id to receive from DOMS
    -- 18/01/2018       1.8  Vijay Reddy    CCR0006939 - Receive into Intransit Locators based on Return Source
    -- 15/05/2018       1.9  Vijay Reddy    CCR0007252 - UGG Emporium Return orders currency code defaulting to USD
    --                                                   Modified to use the original order price list to create the return order
    -- 20/08/2018       2.0  Vijay Reddy    CCR0007457 - Modify Return Order creation to accept warehouse from DOMS
    -- 24/10/2018       2.1  Vijay Reddy    CCR0007571 - Modify create multi line return to consume UPC on DW returns
    -- 21/06/2019       2.2  Vijay Reddy    CCR0008008 - Modify Create multi line order to accept price list id from DOMS
    -- 08-Mar-2022      2.3  Gaurav Joshi   CCR0009841     - US6 defaulting rule
    -- ====================================================================
    -- Sample Execution
    -- ====================================================================
    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100, p_runnum NUMBER:= -1
                   , p_header_id NUMBER:= -1, p_category VARCHAR2:= 'I')
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, MESSAGE);

        INSERT INTO xxdo.XXDOEC_PROCESS_ORDER_LOG
                 VALUES (xxdo.XXDOEC_SEQ_PROCESS_ORDER.NEXTVAL,
                         MESSAGE,
                         CURRENT_TIMESTAMP);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END msg;

    -- START : Added for 1.1.
    /******************************************************************************************************************************************
     Procedure/Function Name  :  log_debug

     Description              :  The purpose of this procedure is to insert debug messages into HSOE.ORDER_IMPORT_DEBUG table.

     INPUT Parameters         :

     OUTPUT Parameters        :

     DEVELOPMENT and MAINTENANCE HISTORY

     Date          Author             Version  Description
     ------------  -----------------  -------  ------------------------------
     10-Aug-2015   Infosys            1.0      Initial Version for BT.
    ******************************************************************************************************************************************/
    PROCEDURE log_debug (p_error_location IN VARCHAR2, p_error_number IN VARCHAR2, p_error_text IN VARCHAR2
                         , p_orig_sys_document_ref IN VARCHAR2, p_addtl_info IN VARCHAR2, p_idx IN NUMBER)
    IS
    BEGIN
        INSERT INTO hsoe.order_import_debug (error_location, error_number, ERROR_TEXT, orig_sys_document_ref, request_id, addtl_info
                                             , sequence_number)
             VALUES (p_error_location, p_error_number, p_error_text,
                     p_orig_sys_document_ref, fnd_global.conc_request_id, p_addtl_info
                     , p_idx);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error while logging error message into HSOE.ORDER_IMPORT_DEBUG.');
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Code : ' || SQLCODE || '. Error Message : ' || SQLERRM);
    END log_debug;

    -- END : Added for 1.1.
    -- CCR0006939 Start ver. 1.8
    PROCEDURE populate_order_attribute (p_attribute_type IN VARCHAR2, p_attribute_value IN VARCHAR2, p_user_name IN VARCHAR2, p_order_header_id IN NUMBER, p_line_id IN NUMBER, p_creation_date IN DATE
                                        , x_attribute_id OUT NUMBER, x_rtn_status OUT VARCHAR2, x_rtn_msg OUT VARCHAR2)
    IS
        CURSOR c_attribute_exists IS
            SELECT attribute_id
              FROM xxdoec_order_attribute
             WHERE     attribute_type = p_attribute_type
                   AND order_header_id = p_order_header_id
                   AND NVL (line_id, -1) = NVL (p_line_id, -1);

        l_dummy          NUMBER;
        l_attribute_id   NUMBER;
    BEGIN
        x_rtn_status   := fnd_api.g_ret_sts_success;
        x_rtn_msg      := NULL;

        -- Check if already exists
        OPEN c_attribute_exists;

        FETCH c_attribute_exists INTO l_attribute_id;

        IF c_attribute_exists%FOUND
        THEN
            CLOSE c_attribute_exists;
        ELSE
            CLOSE c_attribute_exists;

            l_attribute_id   := XXDOEC_ATTRIBUTE_ID_S.NEXTVAL;

            INSERT INTO APPS.XXDOEC_ORDER_ATTRIBUTE (ATTRIBUTE_ID, ATTRIBUTE_TYPE, ATTRIBUTE_VALUE, USER_NAME, ORDER_HEADER_ID, LINE_ID
                                                     , CREATION_DATE)
                 VALUES (l_attribute_id, p_attribute_type, p_attribute_value,
                         p_user_name, p_order_header_id, p_line_id,
                         p_creation_date);

            x_attribute_id   := l_attribute_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_attribute_id   := NULL;
            x_rtn_status     := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_rtn_msg        :=
                   'Unexpected error while populating Order Attribute'
                || 'Error Code : '
                || SQLCODE
                || '. Error Message : '
                || SQLERRM;
    END populate_order_attribute;

    -- CCR0006939 End ver. 1.8
    --
    --
    PROCEDURE create_order_line (p_orig_order_line_id IN NUMBER, p_customer_id IN NUMBER, p_bill_to_site_use_id IN NUMBER, p_ship_to_site_use_id IN NUMBER, p_inventory_item_id IN NUMBER, p_requested_qty IN NUMBER, p_ship_from_org_id IN NUMBER, p_ship_method_code IN VARCHAR2, p_price_list_id IN NUMBER, -- CCR0008008
                                                                                                                                                                                                                                                                                                               p_unit_list_price IN NUMBER, p_unit_selling_price IN NUMBER, p_tax_code IN VARCHAR2, p_tax_date IN DATE, p_tax_value IN NUMBER, p_fluid_recipe_id IN VARCHAR2, p_return_reason_code IN VARCHAR2, p_dam_code IN VARCHAR2, p_factory_code IN VARCHAR2, p_production_code IN VARCHAR2, p_line_type_id IN NUMBER, p_order_type_id IN NUMBER, p_orig_sys_document_ref IN VARCHAR2, p_order_header_id IN OUT NUMBER, p_return_operator IN VARCHAR2 DEFAULT NULL, x_order_line_id OUT NUMBER, x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2
                                 , x_error_msg OUT VARCHAR2)
    IS
        -- IN Parameters
        l_header_rec               oe_order_pub.header_rec_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
        l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;

        -- OUT parameters
        x_header_rec               oe_order_pub.header_rec_type;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_tbl                 oe_order_pub.line_tbl_type;
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

        l_adj_index                NUMBER := 0;
        l_tbl_index                NUMBER;
        l_msg_index_out            NUMBER;
        l_msg_count                NUMBER;
        l_msg_data                 VARCHAR2 (1000);

        l_user_id                  NUMBER;
        l_resp_id                  NUMBER;
        l_resp_appl_id             NUMBER;
        l_org_id                   NUMBER;
        l_inv_org_id               NUMBER;
        l_virtual_inv_org_id       NUMBER;
        l_brand                    VARCHAR2 (40);
        l_website_id               VARCHAR2 (40);
        l_orig_header_id           NUMBER;
        l_orig_line_id             NUMBER;
        l_price_list_id            NUMBER;
        l_customer_id              NUMBER;
        l_ship_to_org_id           NUMBER;
        l_invoice_to_org_id        NUMBER;
        l_inventory_item_id        NUMBER;
        l_payment_term_id          NUMBER;
        l_order_source_id          NUMBER;
        l_kco_header_id            NUMBER;
        l_return_context           VARCHAR2 (40);
        l_do_order_type            VARCHAR2 (40);
        l_line_category_code       VARCHAR2 (40);
        l_cancel_days              NUMBER;
        l_dummy                    NUMBER;
        l_dis_list_name            VARCHAR2 (120)
                                       := 'DOEC MULTI DISCOUNT AMT';
        l_sur_list_name            VARCHAR2 (120)
                                       := 'DOEC GIFT STORE CARD CHARGE';
        l_num_org_id               NUMBER := NULL;                      -- 1.0
        l_inventory_item           VARCHAR2 (40) := NULL;               -- 1.0
        l_warehouse_id             NUMBER;

        CURSOR c_order_line (c_line_id IN NUMBER)
        IS
            SELECT cbp.transaction_user_id, cbp.erp_login_resp_id, cbp.erp_login_app_id,
                   cbp.erp_org_id, cbp.inv_org_id, cbp.virtual_inv_org_id,
                   cbp.brand_name, cbp.website_id, NVL (cbp.om_price_list_id, ooh.price_list_id), -- CCR0007252 ver. 1.9
                   hca.cust_account_id, ool.ship_to_org_id, ool.invoice_to_org_id,
                   ool.header_id, ool.inventory_item_id, 'ORDER' return_context
              FROM xxdoec_country_brand_params cbp, apps.oe_order_lines_all ool, apps.oe_order_headers_all ooh,
                   hz_cust_accounts hca
             WHERE     ool.line_id = c_line_id
                   AND ool.actual_shipment_date IS NOT NULL
                   AND ooh.header_id = ool.header_id
                   AND hca.cust_account_id = ool.sold_to_org_id
                   AND cbp.website_id = hca.attribute18;

        CURSOR c_cust_account (c_customer_id IN NUMBER)
        IS
            SELECT cbp.transaction_user_id, cbp.erp_login_resp_id, cbp.erp_login_app_id,
                   cbp.erp_org_id, cbp.inv_org_id, cbp.virtual_inv_org_id,
                   cbp.brand_name, cbp.website_id, cbp.om_price_list_id,
                   hca.cust_account_id, NULL return_context
              FROM xxdoec_country_brand_params cbp, hz_cust_accounts hca
             WHERE     hca.cust_account_id = c_customer_id
                   AND cbp.website_id = hca.attribute18;

        --
        CURSOR c_order_type (c_order_type_id IN NUMBER)
        IS
            SELECT ott.attribute13 do_return_type, warehouse_id
              FROM oe_transaction_types ott
             WHERE ott.transaction_type_id = c_order_type_id;

        --
        CURSOR c_line_category_code (c_line_type_id IN NUMBER)
        IS
            SELECT order_category_code
              FROM oe_transaction_types ott
             WHERE ott.transaction_type_id = c_line_type_id;

        --
        CURSOR c_customized_product (c_inv_item_id IN NUMBER)
        IS
            SELECT 1
              FROM mtl_system_items_b msi
             WHERE     msi.inventory_item_id = c_inv_item_id --AND msi.organization_id = NVL(l_inv_org_id, 7)  -- Commented 1.0
                   AND msi.organization_id = NVL (l_inv_org_id, l_num_org_id) -- Added 1.0
                   --AND msi.segment2 = 'CUSTOM'; -- Commented 1.0
                   AND msi.segment1 LIKE '%-CUSTOM-%';            -- Added 1.0

        --
        CURSOR c_discount_list_ids (c_dis_list_name IN VARCHAR2)
        IS
            SELECT qlh.list_header_id, qll.list_line_id
              FROM qp_list_headers qlh, qp_list_lines qll
             WHERE     qll.list_header_id = qlh.list_header_id
                   AND qlh.list_type_code = 'DLT'
                   AND qlh.active_flag = 'Y'
                   AND qll.list_line_type_code = 'DIS'
                   AND qll.modifier_level_code = 'LINE'
                   AND qlh.name = c_dis_list_name;

        --
        CURSOR c_surcharge_list_ids (c_sur_list_name IN VARCHAR2)
        IS
            SELECT qlh.list_header_id, qll.list_line_id
              FROM qp_list_headers qlh, qp_list_lines qll
             WHERE     qll.list_header_id = qlh.list_header_id
                   AND qlh.list_type_code = 'SLT'
                   AND qlh.active_flag = 'Y'
                   AND qll.list_line_type_code = 'SUR'
                   AND qll.modifier_level_code = 'LINE'
                   AND qlh.name = c_sur_list_name;

        --
        CURSOR c_orig_charges (c_orig_line_id IN NUMBER)
        IS
            SELECT list_header_id, list_line_id, list_line_type_code,
                   charge_type_code, operand, arithmetic_operator,
                   DECODE (credit_or_charge_flag, 'C', -1 * adjusted_amount, adjusted_amount) adjusted_amount
              FROM apps.oe_price_adjustments opa
             WHERE     line_id = c_orig_line_id
                   AND list_line_type_code = 'FREIGHT_CHARGE';
    BEGIN
        x_rtn_status   := fnd_api.g_ret_sts_success;
        x_error_msg    := NULL;

        -- Start 1.0
        BEGIN
            SELECT organization_id
              INTO l_num_org_id
              FROM mtl_parameters
             WHERE organization_id = master_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_num_org_id   := NULL;
        END;

        -- End 1.0

        -- Validate Order Type ID
        OPEN c_order_type (p_order_type_id);

        FETCH c_order_type INTO l_do_order_type, l_warehouse_id;

        CLOSE c_order_type;

        --
        IF l_do_order_type = 'CP'
        THEN
            l_orig_line_id   := NULL;
        ELSE
            l_orig_line_id   := p_orig_order_line_id;
        END IF;

        -- validate line_id
        IF l_orig_line_id IS NOT NULL
        THEN
            OPEN c_order_line (l_orig_line_id);

            FETCH c_order_line
                INTO l_user_id, l_resp_id, l_resp_appl_id, l_org_id,
                     l_inv_org_id, l_virtual_inv_org_id, l_brand,
                     l_website_id, l_price_list_id, l_customer_id,
                     l_ship_to_org_id, l_invoice_to_org_id, l_orig_header_id,
                     l_inventory_item_id, l_return_context;

            IF c_order_line%NOTFOUND
            THEN
                CLOSE c_order_line;

                x_rtn_status   := fnd_api.g_ret_sts_error;
                x_error_msg    :=
                       l_orig_line_id
                    || ' is Not a Valid Original Order line Id to return';
            ELSE
                CLOSE c_order_line;
            END IF;
        ELSIF p_customer_id IS NOT NULL
        THEN
            -- validate customer ID
            OPEN c_cust_account (p_customer_id);

            FETCH c_cust_account
                INTO l_user_id, l_resp_id, l_resp_appl_id, l_org_id,
                     l_inv_org_id, l_virtual_inv_org_id, l_brand,
                     l_website_id, l_price_list_id, l_customer_id,
                     l_return_context;

            IF c_cust_account%NOTFOUND
            THEN
                CLOSE c_cust_account;

                x_rtn_status   := fnd_api.g_ret_sts_error;
                x_error_msg    :=
                    p_customer_id || ' is Not a Valid customer Id';
            ELSE
                CLOSE c_cust_account;
            END IF;
        END IF;

        -- Payment Term ID
        BEGIN
            SELECT term_id
              INTO l_payment_term_id
              FROM RA_TERMS
             WHERE name = 'PREPAY';
        EXCEPTION
            WHEN OTHERS
            THEN
                l_payment_term_id   := NULL;
        END;

        -- Order Source
        BEGIN
            SELECT order_source_id
              INTO l_order_source_id
              FROM oe_order_sources
             WHERE name = 'Flagstaff';
        EXCEPTION
            WHEN OTHERS
            THEN
                l_order_source_id   := NULL;
        END;

        -- Derive KCO
        BEGIN
            SELECT kco_header_id
              INTO l_kco_header_id
              FROM xxdo.xxdoec_inv_source
             WHERE     inv_org_id = l_inv_org_id
                   AND erp_org_id = l_org_id
                   AND UPPER (brand_name) = UPPER (l_brand)
                   AND SYSDATE BETWEEN NVL (start_date, SYSDATE)
                                   AND NVL (end_date, SYSDATE)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_kco_header_id   := NULL;
        END;

        --
        IF x_rtn_status = fnd_api.g_ret_sts_success
        THEN
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;
            l_tbl_index                                       := 1;

            IF l_do_order_type = 'AE'
            THEN
                l_cancel_days   :=
                    NVL (TO_NUMBER (fnd_profile.VALUE_SPECIFIC (
                                        'XXDOEC_AE_RTN_LINE_CANCEL_DAYS',
                                        l_user_id,
                                        l_resp_id,
                                        l_resp_appl_id,
                                        NULL,
                                        NULL)),
                         30);
            ELSIF l_do_order_type = 'PE'
            THEN
                l_cancel_days   :=
                    NVL (TO_NUMBER (fnd_profile.VALUE_SPECIFIC (
                                        'XXDOEC_CP_LINE_CANCEL_DAYS',
                                        l_user_id,
                                        l_resp_id,
                                        l_resp_appl_id,
                                        NULL,
                                        NULL)),
                         15);
            ELSE
                l_cancel_days   :=
                    NVL (TO_NUMBER (fnd_profile.VALUE_SPECIFIC (
                                        'XXDOEC_ORDER_CANCEL_THRESHOLD_DAYS',
                                        l_user_id,
                                        l_resp_id,
                                        l_resp_appl_id,
                                        NULL,
                                        NULL)),
                         5);
            END IF;

            msg ('Shipping Method is :: ' || p_ship_method_code);
            msg ('Tax Classification Code is :: ' || p_tax_code);
            msg ('Tax Classification Date is :: ' || p_tax_date);


            IF p_order_header_id IS NULL
            THEN
                -- create new order
                l_header_rec                         := oe_order_pub.g_miss_header_rec;
                l_header_rec.operation               := oe_globals.g_opr_create;
                l_header_rec.sold_to_org_id          := l_customer_id;
                l_header_rec.ship_to_org_id          :=
                    NVL (p_ship_to_site_use_id, l_ship_to_org_id);
                l_header_rec.invoice_to_org_id       :=
                    NVL (p_bill_to_site_use_id, l_invoice_to_org_id);
                l_header_rec.order_type_id           := p_order_type_id;
                --     l_header_rec.ship_from_org_id := l_inv_org_id; -- Commented for 1.2.
                l_header_rec.price_list_id           :=
                    NVL (p_price_list_id, l_price_list_id); -- CCR0008008 ver. 2.2
                l_header_rec.payment_term_id         := l_payment_term_id;
                l_header_rec.shipping_method_code    :=
                    NVL (p_ship_method_code, fnd_api.G_MISS_CHAR); -- '000001_R04_P_GND';
                --l_header_rec.demand_class_code     := l_brand; -- Commented 1.0
                l_header_rec.attribute5              := l_brand;
                --l_header_rec.attribute9            := l_kco_header_id; -- Commented 1.0
                l_header_rec.order_source_id         := l_order_source_id;
                l_header_rec.orig_sys_document_ref   :=
                    p_orig_sys_document_ref;
                l_header_rec.cust_po_number          :=
                    SUBSTR (p_orig_sys_document_ref, 3);
                l_header_rec.attribute1              :=
                    TO_CHAR (SYSDATE + l_cancel_days, 'YYYY/MM/DD HH:MI:SS'); --TO_CHAR(SYSDATE +l_cancel_days,'DD-MON-RR');  1.0

                l_header_rec.global_attribute20      := p_return_operator;


                -- Initialize Action record
                l_action_request_tbl (l_tbl_index)   :=
                    oe_order_pub.g_miss_request_rec;
                l_action_request_tbl (l_tbl_index).request_type   :=
                    oe_globals.G_BOOK_ORDER;
                l_action_request_tbl (l_tbl_index).entity_code   :=
                    oe_globals.G_ENTITY_HEADER;
            ELSE
                -- Order already exists, just update shipping method code
                IF     p_ship_method_code IS NOT NULL
                   AND p_ship_method_code <> 'VCRD'
                THEN
                    UPDATE oe_order_headers ooh
                       SET shipping_method_code   = p_ship_method_code
                     WHERE header_id = p_order_header_id;
                END IF;
            END IF;

            -- Initialize line record
            l_line_tbl (l_tbl_index)                          := oe_order_pub.g_miss_line_rec;
            l_line_tbl (l_tbl_index).operation                := oe_globals.g_opr_create;
            l_line_tbl (l_tbl_index).header_id                :=
                NVL (p_order_header_id, fnd_api.g_miss_num);
            l_line_tbl (l_tbl_index).ship_to_org_id           :=
                NVL (l_ship_to_org_id, p_ship_to_site_use_id);
            l_line_tbl (l_tbl_index).invoice_to_org_id        :=
                NVL (l_invoice_to_org_id, p_bill_to_site_use_id);
            l_line_tbl (l_tbl_index).inventory_item_id        :=
                NVL (l_inventory_item_id, p_inventory_item_id);
            l_line_tbl (l_tbl_index).ordered_quantity         := p_requested_qty;
            l_line_tbl (l_tbl_index).shipping_method_code     :=
                NVL (p_ship_method_code,                -- '000001_R04_P_GND';
                                         fnd_api.g_miss_char);
            l_line_tbl (l_tbl_index).price_list_id            :=
                NVL (p_price_list_id, fnd_api.g_miss_num); -- CCR0008008 ver. 2.2;
            l_line_tbl (l_tbl_index).unit_list_price          :=
                NVL (p_unit_list_price, fnd_api.g_miss_num);
            l_line_tbl (l_tbl_index).unit_selling_price       :=
                NVL (p_unit_selling_price, fnd_api.g_miss_num);
            l_line_tbl (l_tbl_index).line_type_id             := p_line_type_id;
            l_line_tbl (l_tbl_index).return_reason_code       :=
                p_return_reason_code;
            l_line_tbl (l_tbl_index).return_context           :=
                l_return_context;
            l_line_tbl (l_tbl_index).return_attribute1        :=
                l_orig_header_id;
            l_line_tbl (l_tbl_index).return_attribute2        := l_orig_line_id;
            l_line_tbl (l_tbl_index).tax_code                 :=
                NVL (p_tax_code, fnd_api.g_miss_char);
            l_line_tbl (l_tbl_index).tax_date                 :=
                NVL (p_tax_date, fnd_api.g_miss_date);
            l_line_tbl (l_tbl_index).tax_value                :=
                NVL (p_tax_value, fnd_api.g_miss_num);
            l_line_tbl (l_tbl_index).customer_job             :=
                p_fluid_recipe_id;
            l_line_tbl (l_tbl_index).latest_acceptable_date   :=
                TO_CHAR (SYSDATE + l_cancel_days, 'DD-MON-RR');
            l_line_tbl (l_tbl_index).attribute1               :=
                TO_CHAR (SYSDATE + l_cancel_days, 'YYYY/MM/DD HH:MI:SS'); --TO_CHAR(SYSDATE + l_cancel_days,'DD-MON-RR'); -- 1.0
            l_line_tbl (l_tbl_index).attribute12              := p_dam_code;
            l_line_tbl (l_tbl_index).attribute4               :=
                p_factory_code;
            l_line_tbl (l_tbl_index).attribute5               :=
                p_production_code;
            l_line_tbl (l_tbl_index).return_attribute15       :=
                p_return_operator;

            IF p_orig_order_line_id IS NOT NULL
            THEN
                IF l_org_id = 105
                THEN                     -- only for EMEA exchange return line
                    l_line_tbl (l_tbl_index).ship_from_org_id   :=
                        NVL (l_warehouse_id, fnd_api.g_miss_num);
                ELSE                                  -- to handle SFS returns
                    l_warehouse_id   := NULL;
                    -- begin ver 2.3
                    /* ver 2.3
             xxd_do_om_default_rules.get_warehouse (
                          p_org_id              => l_org_id,
                          p_line_type_id        =>  NULL,
                          p_inventory_item_id   => l_inventory_item_id,
                          x_warehouse_id        => l_warehouse_id);
              */
                    l_warehouse_id   :=
                        xxd_do_om_default_rules.ret_inv_warehouse (
                            p_org_id              => l_org_id,
                            p_order_type_id       => p_order_type_id,
                            p_line_type_id        => NULL,
                            p_request_date        => SYSDATE,
                            p_inventory_item_id   => l_inventory_item_id);
                    -- end ver 2.3
                    l_line_tbl (l_tbl_index).ship_from_org_id   :=
                        NVL (l_warehouse_id, fnd_api.g_miss_num);
                END IF;
            END IF;

            --  ECDC rules engine on DOMS side  v 1.7
            IF p_ship_from_org_id IS NOT NULL
            THEN
                l_line_tbl (l_tbl_index).ship_from_org_id   :=
                    p_ship_from_org_id;
            END IF;


            IF p_unit_selling_price IS NOT NULL
            THEN
                l_line_tbl (l_tbl_index).calculate_price_flag   := 'P';
            END IF;

            OPEN c_customized_product (
                l_line_tbl (l_tbl_index).inventory_item_id);

            FETCH c_customized_product INTO l_dummy;

            IF c_customized_product%NOTFOUND
            THEN
                CLOSE c_customized_product;
            ELSE
                CLOSE c_customized_product;

                l_line_category_code   := NULL;

                --
                OPEN c_line_category_code (p_line_type_id);

                FETCH c_line_category_code INTO l_line_category_code;

                CLOSE c_line_category_code;
            --

            /* -- START : Commented for 1.2.
            IF l_line_category_code = 'RETURN'
            THEN
               l_line_tbl (l_tbl_index).ship_from_org_id := l_inv_org_id;
            ELSIF l_line_category_code = 'ORDER'
            THEN
               l_line_tbl (l_tbl_index).ship_from_org_id :=
                  l_virtual_inv_org_id;
            END IF;
            */
            -- END : Commented for 1.2.
            END IF;

            --
            IF NVL (l_line_tbl (l_tbl_index).unit_list_price, 0) <>
               NVL (l_line_tbl (l_tbl_index).unit_selling_price, 0)
            THEN
                -- need to create an adjustment
                l_adj_index                                        := l_adj_index + 1;
                l_line_adj_tbl (l_adj_index)                       :=
                    oe_order_pub.g_miss_line_adj_rec;
                l_line_adj_tbl (l_adj_index).operation             :=
                    oe_globals.g_opr_create;
                l_line_adj_tbl (l_adj_index).line_index            := l_tbl_index;
                l_line_adj_tbl (l_adj_index).arithmetic_operator   := 'AMT';
                l_line_adj_tbl (l_adj_index).automatic_flag        := 'N';
                l_line_adj_tbl (l_adj_index).applied_flag          := 'Y';

                IF l_line_tbl (l_tbl_index).unit_list_price >
                   l_line_tbl (l_tbl_index).unit_selling_price
                THEN
                    -- discount
                    l_line_adj_tbl (l_adj_index).list_line_type_code   :=
                        'DIS';
                    l_line_adj_tbl (l_adj_index).operand   :=
                          l_line_tbl (l_tbl_index).unit_list_price
                        - l_line_tbl (l_tbl_index).unit_selling_price;
                    l_line_adj_tbl (l_adj_index).adjusted_amount   :=
                          l_line_tbl (l_tbl_index).unit_selling_price
                        - l_line_tbl (l_tbl_index).unit_list_price;

                    OPEN c_discount_list_ids (l_dis_list_name);

                    FETCH c_discount_list_ids
                        INTO l_line_adj_tbl (l_adj_index).list_header_id, l_line_adj_tbl (l_adj_index).list_line_id;

                    CLOSE c_discount_list_ids;
                ELSE
                    -- surcharge
                    l_line_adj_tbl (l_adj_index).list_line_type_code   :=
                        'SUR';
                    l_line_adj_tbl (l_adj_index).operand   :=
                          l_line_tbl (l_tbl_index).unit_selling_price
                        - l_line_tbl (l_tbl_index).unit_list_price;
                    l_line_adj_tbl (l_adj_index).adjusted_amount   :=
                          l_line_tbl (l_tbl_index).unit_selling_price
                        - l_line_tbl (l_tbl_index).unit_list_price;

                    OPEN c_surcharge_list_ids (l_sur_list_name);

                    FETCH c_surcharge_list_ids
                        INTO l_line_adj_tbl (l_adj_index).list_header_id, l_line_adj_tbl (l_adj_index).list_line_id;

                    CLOSE c_surcharge_list_ids;
                END IF;
            END IF;

            -- in case of Carrier lost shipment we need to create charges
            IF l_do_order_type = 'CP'
            THEN
                FOR c_chrgs IN c_orig_charges (p_orig_order_line_id)
                LOOP
                    l_adj_index                                        := l_adj_index + 1;
                    l_line_adj_tbl (l_adj_index)                       :=
                        oe_order_pub.g_miss_line_adj_rec;
                    l_line_adj_tbl (l_adj_index).operation             :=
                        oe_globals.g_opr_create;
                    l_line_adj_tbl (l_adj_index).line_index            := l_tbl_index;
                    l_line_adj_tbl (l_adj_index).list_header_id        :=
                        c_chrgs.list_header_id;
                    l_line_adj_tbl (l_adj_index).list_line_id          :=
                        c_chrgs.list_line_id;
                    l_line_adj_tbl (l_adj_index).list_line_type_code   :=
                        c_chrgs.list_line_type_code;
                    l_line_adj_tbl (l_adj_index).charge_type_code      :=
                        c_chrgs.charge_type_code;
                    l_line_adj_tbl (l_adj_index).operand               :=
                        c_chrgs.operand;
                    l_line_adj_tbl (l_adj_index).arithmetic_operator   :=
                        c_chrgs.arithmetic_operator;
                    l_line_adj_tbl (l_adj_index).adjusted_amount       :=
                        c_chrgs.adjusted_amount;
                    l_line_adj_tbl (l_adj_index).automatic_flag        := 'N';
                    l_line_adj_tbl (l_adj_index).applied_flag          := 'Y';
                    l_line_adj_tbl (l_adj_index).updated_flag          := 'Y';
                END LOOP;
            END IF;

            --      dbms_output.put_line('Before API call: ' || l_line_tbl (l_tbl_index).ship_from_org_id);

            -- CALL to PROCESS ORDER API
            oe_order_pub.process_order (
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => x_rtn_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_line_adj_tbl             => l_line_adj_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                -- OUT PARAMETERS
                x_header_rec               => x_header_rec,
                x_header_val_rec           => x_header_val_rec,
                x_header_adj_tbl           => x_header_adj_tbl,
                x_header_adj_val_tbl       => x_header_adj_val_tbl,
                x_header_price_att_tbl     => x_header_price_att_tbl,
                x_header_adj_att_tbl       => x_header_adj_att_tbl,
                x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
                x_header_scredit_tbl       => x_header_scredit_tbl,
                x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
                x_line_tbl                 => x_line_tbl,
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

            --dbms_output.put_line('After API call: ' || x_line_tbl (1).ship_from_org_id);

            IF x_rtn_status <> fnd_api.g_ret_sts_success AND l_msg_count > 0
            THEN
                -- Retrieve messages
                FOR i IN 1 .. l_msg_count
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                    , p_msg_index_out => l_msg_index_out);
                    x_error_msg   :=
                        SUBSTR (x_error_msg || l_msg_data || CHR (13),
                                1,
                                2000);
                END LOOP;
            ELSE
                x_order_line_id     := x_line_tbl (1).line_id;
                p_order_header_id   := x_line_tbl (1).header_id;

                BEGIN
                    SELECT order_number
                      INTO x_order_number
                      FROM oe_order_headers ooh
                     WHERE header_id = x_line_tbl (1).header_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_order_number   := NULL;
                END;
            END IF;
        END IF;                                     -- Validation status check
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status   := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_error_msg    := SQLERRM;
    END create_order_line;

    --
    PROCEDURE create_return (p_orig_order_line_id IN NUMBER, p_customer_id IN NUMBER, p_bill_to_site_use_id IN NUMBER, p_ship_to_site_use_id IN NUMBER, p_returned_item_upc IN VARCHAR2, p_returned_qty IN NUMBER, p_ship_from_org_id IN NUMBER, -- CCR0007457 ver. 2.0
                                                                                                                                                                                                                                                 p_price_list_id IN NUMBER, -- CCR0008008
                                                                                                                                                                                                                                                                            p_unit_list_price IN NUMBER, p_unit_selling_price IN NUMBER, p_tax_code IN VARCHAR2, p_tax_date IN DATE, p_tax_value IN NUMBER, p_return_reason_code IN VARCHAR2, p_dam_code IN VARCHAR2, p_factory_code IN VARCHAR2, p_production_code IN VARCHAR2, p_product_received IN VARCHAR2, -- Y/N
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 p_return_type IN VARCHAR2, p_orig_sys_document_ref IN VARCHAR2, p_order_header_id IN OUT NUMBER, p_return_operator IN VARCHAR2 DEFAULT NULL, p_return_source IN VARCHAR2, -- CCR0006939 ver. 1.8
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           x_order_line_id OUT NUMBER
                             , x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2, x_error_msg OUT VARCHAR2)
    IS
        --
        l_order_type_id          NUMBER;
        l_inbound_line_type_id   NUMBER;
        l_returned_item_id       NUMBER;
        l_shipped_qty            NUMBER;
        l_returned_qty           NUMBER;
        l_refunded_qty           NUMBER;
        l_line_booked            VARCHAR2 (1);
        l_ship_from_org_id       NUMBER;
        l_subinventory_code      VARCHAR (30);
        l_locator_id             NUMBER;
        l_attribute_id           NUMBER;
        excess_return_qty        EXCEPTION;
        ordertype_missing        EXCEPTION;

        --
        CURSOR c_order_type (c_do_return_type IN VARCHAR2)
        IS
            SELECT transaction_type_id, default_inbound_line_type_id
              FROM oe_transaction_types_all ott
             WHERE     ott.attribute13 = c_do_return_type
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE)
                   AND (   ott.attribute12 =
                           (SELECT hca.attribute18
                              FROM hz_cust_accounts hca
                             WHERE cust_account_id = p_customer_id)
                        OR ott.attribute12 =
                           (SELECT hca.attribute18
                              FROM oe_order_lines_all ool, hz_cust_accounts hca
                             WHERE     ool.line_id = p_orig_order_line_id
                                   AND hca.cust_account_id =
                                       ool.sold_to_org_id));

        --
        CURSOR c_line_booked (c_rtn_line_id IN NUMBER)
        IS
            SELECT 'Y', ship_from_org_id
              FROM oe_order_lines ool
             WHERE     ool.line_id = c_rtn_line_id
                   AND ool.flow_status_code <> 'ENTERED';

        --
        CURSOR c_returned_qty (c_orig_line_id IN NUMBER)
        IS
            SELECT SUM (ordered_quantity)
              FROM oe_order_lines ool
             WHERE     reference_line_id = c_orig_line_id
                   AND cancelled_flag <> 'Y';

        CURSOR c_refunded_qty (c_orig_line_id IN NUMBER)
        IS
            SELECT SUM (refund_quantity)
              FROM xxdoec_order_manual_refunds omr
             WHERE line_id = c_orig_line_id AND refund_component = 'PRODUCT';

        CURSOR c_shipped_qty (c_orig_line_id IN NUMBER)
        IS
            SELECT shipped_quantity
              FROM oe_order_lines ool
             WHERE line_id = c_orig_line_id AND cancelled_flag <> 'Y';

        CURSOR c_exch_rtn_line_exists (c_orig_line_id IN NUMBER)
        IS
            SELECT ool.line_id, ooh.order_number, ooh.header_id,
                   DECODE (ool.flow_status_code, 'ENTERED', 'N', 'Y') line_booked_flag
              FROM oe_order_lines ool, oe_order_headers ooh, oe_transaction_types ott
             WHERE     ool.reference_line_id = c_orig_line_id
                   AND ooh.header_id = ool.header_id
                   AND ott.transaction_type_id = ooh.order_type_id
                   AND ott.attribute13 = 'AE'
                   AND ool.flow_status_code = 'AWAITING_RETURN'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM rcv_transactions_interface rti
                             WHERE rti.oe_order_line_id = ool.line_id);

        -- CCR0006939 Start ver. 1.8
        CURSOR c_locator_id IS
            SELECT mil.inventory_location_id, mil.subinventory_code
              FROM fnd_lookup_values flv, mtl_item_locations_kfv mil
             WHERE     flv.lookup_type = 'XXDO_ECOMM_INTRANSIT_LOCATIONS'
                   AND flv.language = 'US'
                   AND flv.lookup_code = p_return_source
                   AND mil.concatenated_segments = flv.meaning
                   AND mil.organization_id = l_ship_from_org_id;
    -- CCR0006939 end ver. 1.8

    BEGIN
        x_rtn_status   := fnd_api.g_ret_sts_success;
        x_error_msg    := NULL;

        -- before creating return check to see if AE return line already exists
        -- If exists skip return order creation and just receive the product

        OPEN c_exch_rtn_line_exists (p_orig_order_line_id);

        FETCH c_exch_rtn_line_exists INTO x_order_line_id, x_order_number, p_order_header_id, l_line_booked;

        IF c_exch_rtn_line_exists%FOUND
        THEN
            CLOSE c_exch_rtn_line_exists;
        ELSE
            CLOSE c_exch_rtn_line_exists;

            OPEN c_order_type (p_return_type);

            FETCH c_order_type INTO l_order_type_id, l_inbound_line_type_id;

            CLOSE c_order_type;

            IF l_order_type_id IS NULL OR l_inbound_line_type_id IS NULL
            THEN
                RAISE ordertype_missing;
            END IF;

            --
            IF p_returned_item_upc IS NOT NULL
            THEN
                BEGIN
                    SELECT upc_to_iid (p_returned_item_upc)
                      INTO l_returned_item_id
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_returned_item_id   := NULL;
                END;
            END IF;

            --
            IF p_orig_order_line_id IS NOT NULL
            THEN
                l_shipped_qty    := NULL;

                OPEN c_shipped_qty (p_orig_order_line_id);

                FETCH c_shipped_qty INTO l_shipped_qty;

                CLOSE c_shipped_qty;

                --
                l_returned_qty   := NULL;

                OPEN c_returned_qty (p_orig_order_line_id);

                FETCH c_returned_qty INTO l_returned_qty;

                CLOSE c_returned_qty;

                --
                l_refunded_qty   := NULL;

                OPEN c_refunded_qty (p_orig_order_line_id);

                FETCH c_refunded_qty INTO l_refunded_qty;

                CLOSE c_refunded_qty;

                -- Check to see the total returned Qty against the orig shipped qty
                IF   NVL (l_returned_qty, 0)
                   + NVL (l_refunded_qty, 0)
                   + p_returned_qty >
                   l_shipped_qty
                THEN
                    RAISE excess_return_qty;
                END IF;
            END IF;

            create_order_line (p_orig_order_line_id => p_orig_order_line_id, p_customer_id => p_customer_id, p_bill_to_site_use_id => p_bill_to_site_use_id, p_ship_to_site_use_id => p_ship_to_site_use_id, p_inventory_item_id => l_returned_item_id, p_requested_qty => p_returned_qty, p_ship_from_org_id => p_ship_from_org_id, -- CCR0007457 ver. 2.0
                                                                                                                                                                                                                                                                                                                                     p_price_list_id => p_price_list_id, -- CCR0008008 ver. 2.2
                                                                                                                                                                                                                                                                                                                                                                         p_ship_method_code => NULL, p_unit_list_price => p_unit_list_price, p_unit_selling_price => p_unit_selling_price, p_tax_code => p_tax_code, p_tax_date => p_tax_date, p_tax_value => p_tax_value, p_fluid_recipe_id => NULL, p_return_reason_code => p_return_reason_code, p_dam_code => p_dam_code, p_factory_code => p_factory_code, p_production_code => p_production_code, p_line_type_id => l_inbound_line_type_id, -- return
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  p_order_type_id => l_order_type_id, p_orig_sys_document_ref => p_orig_sys_document_ref, p_order_header_id => p_order_header_id, p_return_operator => p_return_operator, x_order_line_id => x_order_line_id, x_order_number => x_order_number, x_rtn_status => x_rtn_status
                               , x_error_msg => x_error_msg);

            IF x_rtn_status = fnd_api.g_ret_sts_success
            THEN
                UPDATE oe_order_lines
                   SET credit_invoice_line_id = NULL, reference_customer_trx_line_id = NULL
                 WHERE line_id = x_order_line_id;

                -- check order status
                OPEN c_line_booked (x_order_line_id);

                FETCH c_line_booked INTO l_line_booked, l_ship_from_org_id;

                IF c_line_booked%NOTFOUND
                THEN
                    CLOSE c_line_booked;

                    x_rtn_status   := fnd_api.g_ret_sts_error;
                    x_error_msg    :=
                           x_error_msg
                        || ' Unable to Book the Order# '
                        || x_order_number
                        || ' Error :: '
                        || x_error_msg;                         -- Added Error
                ELSE
                    CLOSE c_line_booked;

                    -- CCR0006939 Start ver. 1.8
                    -- populate return source order attribute
                    populate_order_attribute (
                        p_attribute_type    => 'RETURN_SOURCE',
                        p_attribute_value   => p_return_source,
                        p_user_name         => 'ReturnCreation',
                        p_order_header_id   => p_order_header_id,
                        p_line_id           => NULL,
                        p_creation_date     => SYSDATE,
                        x_attribute_id      => l_attribute_id,
                        x_rtn_status        => x_rtn_status,
                        x_rtn_msg           => x_error_msg);
                -- CCR0006939 end ver. 1.8
                END IF;
            -- START : Added for 1.1.
            ELSE
                log_debug (
                    p_error_location          => 'CREATE_RETURN',
                    p_error_number            => NULL,
                    p_error_text              => x_error_msg,
                    p_orig_sys_document_ref   => p_orig_sys_document_ref,
                    p_addtl_info              =>
                           'Input Data ->  P_ORIG_ORDER_LINE_ID : '
                        || p_orig_order_line_id
                        || '. P_CUSTOMER_ID : '
                        || p_customer_id
                        || '. P_BILL_TO_SITE_USE_ID : '
                        || p_bill_to_site_use_id
                        || '. P_SHIP_TO_SITE_USE_ID : '
                        || p_ship_to_site_use_id
                        || '. P_SHIP_FROM_ORG_ID : '
                        || p_ship_from_org_id
                        || '. P_INVENTORY_ITEM_ID   : '
                        || l_returned_item_id
                        || '. P_REQUESTED_QTY       : '
                        || p_returned_qty
                        || '. P_UNIT_LIST_PRICE     : '
                        || p_unit_list_price
                        || '. P_UNIT_SELLING_PRICE  : '
                        || p_unit_selling_price
                        || '. P_TAX_CODE            : '
                        || p_tax_code
                        || '. P_TAX_DATE            : '
                        || p_tax_date
                        || '. P_TAX_VALUE           : '
                        || p_tax_value
                        || '. P_RETURN_REASON_CODE  : '
                        || p_return_reason_code
                        || '. P_DAM_CODE            : '
                        || p_dam_code
                        || '. P_FACTORY_CODE        : '
                        || p_factory_code
                        || '. P_PRODUCTION_CODE     : '
                        || p_production_code
                        || '. P_LINE_TYPE_ID        : '
                        || l_inbound_line_type_id
                        || '. P_ORDER_TYPE_ID       : '
                        || l_order_type_id
                        || '. P_ORIG_SYS_DOCUMENT_REF : '
                        || p_orig_sys_document_ref
                        || '. P_ORDER_HEADER_ID     : '
                        || p_order_header_id
                        || '. P_RETURN_OPERATOR     : '
                        || p_return_operator,
                    p_idx                     => 1);
            -- END : Added for 1.1.

            END IF;
        END IF;

        -- If Order Booked successfully then receive the product
        IF NVL (p_product_received, 'N') = 'Y' AND l_line_booked = 'Y'
        THEN
            -- -- CCR0006939 Start ver. 1.8
            -- receive the product into specific locator
            l_locator_id          := NULL;
            l_subinventory_code   := NULL;

            --
            OPEN c_locator_id;

            FETCH c_locator_id INTO l_locator_id, l_subinventory_code;

            CLOSE c_locator_id;

            receive_product (p_order_line_id   => x_order_line_id,
                             p_returned_qty    => p_returned_qty,
                             p_subinventory    => l_subinventory_code,
                             p_locator_id      => l_locator_id,
                             x_rtn_status      => x_rtn_status,
                             x_error_msg       => x_error_msg);

            -- CCR0006939 End ver. 1.8

            -- START : Added for 1.1.
            IF x_rtn_status <> fnd_api.g_ret_sts_success
            THEN
                log_debug (
                    p_error_location          => 'CREATE_RETURN',
                    p_error_number            => NULL,
                    p_error_text              => x_error_msg,
                    p_orig_sys_document_ref   => p_orig_sys_document_ref,
                    p_addtl_info              =>
                           'Input Data ->  P_ORDER_LINE_ID : '
                        || x_order_line_id
                        || '. P_RETURNED_QTY : '
                        || p_returned_qty,
                    p_idx                     => 2);
            END IF;
        -- END : Added for 1.1.

        END IF;
    EXCEPTION
        WHEN ordertype_missing
        THEN
            x_rtn_status   := fnd_api.g_ret_sts_error;
            x_error_msg    :=
                   'Unable to derive Order/Line Type IDs for the combination of eComm website and order type purpose '
                || p_return_type;
            -- START : Added for 1.1.
            log_debug (
                p_error_location          => 'CREATE_RETURN',
                p_error_number            => SQLCODE,
                p_error_text              => x_error_msg,
                p_orig_sys_document_ref   => p_orig_sys_document_ref,
                p_addtl_info              =>
                    'In Exception : ORDERTYPE_MISSING',
                p_idx                     => 3);
        -- END : Added for 1.1.

        WHEN excess_return_qty
        THEN
            x_rtn_status   := fnd_api.g_ret_sts_error;
            x_error_msg    :=
                   'Toatl Returned qty cannot be more than original shipped qty '
                || CHR (10)
                || 'Previous Rtn Qty: '
                || l_returned_qty
                || ' Current Rtn Qty: '
                || p_returned_qty
                || ' Orig shipped Qty: '
                || l_shipped_qty;
            -- START : Added for 1.1.
            log_debug (
                p_error_location          => 'CREATE_RETURN',
                p_error_number            => SQLCODE,
                p_error_text              => x_error_msg,
                p_orig_sys_document_ref   => p_orig_sys_document_ref,
                p_addtl_info              =>
                    'In Exception : EXCESS_RETURN_QTY',
                p_idx                     => 4);
        -- END : Added for 1.1.

        WHEN OTHERS
        THEN
            x_rtn_status   := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_error_msg    := SQLERRM;
            -- START : Added for 1.1.
            log_debug (p_error_location          => 'CREATE_RETURN',
                       p_error_number            => SQLCODE,
                       p_error_text              => x_error_msg,
                       p_orig_sys_document_ref   => p_orig_sys_document_ref,
                       p_addtl_info              => 'In Exception : OTHERS',
                       p_idx                     => 5);
    -- END : Added for 1.1.

    END create_return;

    --
    PROCEDURE create_shipment (p_customer_id IN NUMBER, p_bill_to_site_use_id IN NUMBER, p_ship_to_site_use_id IN NUMBER, p_requested_item_upc IN VARCHAR2, p_ordered_quantity IN NUMBER, p_ship_from_org_id IN NUMBER, p_ship_method_code IN VARCHAR2, p_price_list_id IN NUMBER, -- CCR0008008
                                                                                                                                                                                                                                                                                   p_unit_list_price IN NUMBER, p_unit_selling_price IN NUMBER, p_tax_code IN VARCHAR2, p_tax_date IN DATE, p_tax_value IN NUMBER, p_sfs_flag IN VARCHAR2, p_fluid_recipe_id IN VARCHAR2, p_order_type IN VARCHAR2, p_orig_sys_document_ref IN VARCHAR2, p_order_header_id IN OUT NUMBER, x_order_line_id OUT NUMBER, x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2
                               , x_error_msg OUT VARCHAR2)
    IS
        l_num_org_id              NUMBER := 0;                    -- Added 1.0

        CURSOR c_order_type (c_do_order_type IN VARCHAR2)
        IS
            SELECT transaction_type_id, default_outbound_line_type_id
              FROM oe_transaction_types ott
             WHERE     ott.attribute13 = c_do_order_type
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE)
                   AND ott.attribute12 =
                       (SELECT hca.attribute18
                          FROM hz_cust_accounts hca
                         WHERE cust_account_id = p_customer_id);

        --
        CURSOR c_line_type (c_item_id IN NUMBER)
        IS
            SELECT ott.transaction_type_id
              FROM apps.fnd_lookup_values_vl flv, apps.oe_transaction_types_tl ott, apps.mtl_system_items_b msi
             WHERE     flv.lookup_type = 'XXDO_GCARD_LINE_TYPE'
                   AND flv.enabled_flag = 'Y'
                   AND NVL (flv.end_date_active, SYSDATE + 1) > SYSDATE
                   AND ott.name = flv.description
                   AND ott.language = 'US'
                   AND flv.lookup_code = msi.segment1             -- Added 1.0
                   --msi.segment1 || '-' || msi.segment2 || '-' || msi.segment3 --Commented 1.0
                   --AND msi.organization_id = 7  -- Commented 1.0
                   AND msi.organization_id = l_num_org_id         -- Added 1.0
                   AND msi.inventory_item_id = c_item_id;

        --
        CURSOR c_aex_line_exists IS
            SELECT COUNT (1)
              FROM oe_order_lines ool, oe_order_headers ooh, oe_transaction_types ott
             WHERE     ooh.header_id = p_order_header_id
                   AND ooh.header_id = ool.header_id
                   AND ott.transaction_type_id = ooh.order_type_id
                   AND ott.attribute13 = 'AE'
                   AND ool.line_category_code = 'ORDER'
                   AND ool.flow_status_code <> 'CANCELLED';

        --
        l_order_type_id           NUMBER;
        l_line_type_id            NUMBER;
        l_outbound_line_type_id   NUMBER;
        l_requested_item_id       NUMBER;
        l_aex_line_count          NUMBER := 0;
    --
    BEGIN
        x_rtn_status   := fnd_api.g_ret_sts_success;
        x_error_msg    := NULL;

        -- Start 1.0
        BEGIN
            SELECT organization_id
              INTO l_num_org_id
              FROM mtl_parameters
             WHERE organization_id = master_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_num_org_id   := NULL;
        END;

        -- End 1.0

        OPEN c_order_type (p_order_type);

        FETCH c_order_type INTO l_order_type_id, l_outbound_line_type_id;

        CLOSE c_order_type;

        IF l_order_type_id IS NULL OR l_outbound_line_type_id IS NULL
        THEN
            x_rtn_status   := fnd_api.G_RET_STS_ERROR;
            x_error_msg    :=
                   'Unable to derive Order/Line Type IDs for the combination of eComm website and order type purpose '
                || p_order_type;
        END IF;

        --
        msg (
               'Requested Item UPC in Create Shipment :: '
            || p_requested_item_upc);

        IF p_requested_item_upc IS NOT NULL
        THEN
            BEGIN
                SELECT upc_to_iid (p_requested_item_upc)
                  INTO l_requested_item_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_requested_item_id   := NULL;
                    x_rtn_status          := fnd_api.G_RET_STS_ERROR;
                    x_error_msg           :=
                        'Invalid Requested Item UPC ' || p_requested_item_upc;
            END;
        END IF;

        --
        OPEN c_aex_line_exists;

        FETCH c_aex_line_exists INTO l_aex_line_count;

        CLOSE c_aex_line_exists;

        --
        OPEN c_line_type (l_requested_item_id);

        FETCH c_line_type INTO l_line_type_id;

        IF c_line_type%NOTFOUND
        THEN
            CLOSE c_line_type;

            l_line_type_id   := l_outbound_line_type_id;
        ELSE
            CLOSE c_line_type;
        END IF;

        -- SFS Line Type I D
        IF NVL (p_sfs_flag, 'N') = 'Y'
        THEN
            BEGIN
                SELECT transaction_type_id
                  INTO l_line_type_id
                  FROM oe_transaction_types
                 WHERE transaction_type_code = 'LINE' AND attribute15 = 'SFS';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_line_type_id   := NULL;
            END;
        END IF;

        --
        IF x_rtn_status = fnd_api.G_RET_STS_SUCCESS AND l_aex_line_count = 0
        THEN
            create_order_line (p_orig_order_line_id => NULL, p_customer_id => p_customer_id, p_bill_to_site_use_id => p_bill_to_site_use_id, p_ship_to_site_use_id => p_ship_to_site_use_id, p_inventory_item_id => l_requested_item_id, p_requested_qty => p_ordered_quantity, p_ship_from_org_id => p_ship_from_org_id, p_ship_method_code => NVL (p_ship_method_code, '000001_GNCR_P_GND'), -- -- CCR0006939 ver. 1.8
                                                                                                                                                                                                                                                                                                                                                                                               p_price_list_id => p_price_list_id, -- CCR0008008
                                                                                                                                                                                                                                                                                                                                                                                                                                   p_unit_list_price => p_unit_list_price, p_unit_selling_price => p_unit_selling_price, p_tax_code => p_tax_code, p_tax_date => p_tax_date, p_tax_value => p_tax_value, p_fluid_recipe_id => p_fluid_recipe_id, p_return_reason_code => NULL, p_dam_code => NULL, p_factory_code => NULL, p_production_code => NULL, p_line_type_id => l_line_type_id, -- shipment
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        p_order_type_id => l_order_type_id, p_orig_sys_document_ref => p_orig_sys_document_ref, p_order_header_id => p_order_header_id, p_return_operator => NULL, x_order_line_id => x_order_line_id, x_order_number => x_order_number, x_rtn_status => x_rtn_status
                               , x_error_msg => x_error_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status   := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_error_msg    := SQLERRM;
    END create_shipment;

    --
    PROCEDURE create_exchange (p_orig_order_line_id IN NUMBER, p_customer_id IN NUMBER, p_bill_to_site_use_id IN NUMBER, p_ship_to_site_use_id IN NUMBER, p_returned_item_upc IN VARCHAR2, p_returned_qty IN NUMBER, p_return_reason_code IN VARCHAR2, p_dam_code IN VARCHAR2, p_factory_code IN VARCHAR2, p_production_code IN VARCHAR2, p_product_received IN VARCHAR2, -- Y/N
                                                                                                                                                                                                                                                                                                                                                                          p_requested_item_upc IN VARCHAR2, p_requested_qty IN NUMBER, p_ship_from_org_id IN NUMBER, p_ship_method_code IN VARCHAR2, p_exchange_type IN VARCHAR2, p_orig_sys_document_ref IN VARCHAR2, p_return_operator IN VARCHAR2 DEFAULT NULL, p_return_source IN VARCHAR2, p_price_list_id IN NUMBER, -- CCR0008008
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           x_order_header_id OUT NUMBER
                               , x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2, x_error_msg OUT VARCHAR2)
    IS
        l_num_org_id           NUMBER := 0;                       -- Added 1.0

        /* CURSOR c_model (c_item_upc IN VARCHAR2)
           IS
            SELECT -- msi.segment1  -- commented for 1.3.
                SUBSTR (msi.segment1, 1, (INSTR (msi.segment1, '-', 1, 1) - 1)) -- Modified for 1.3.
              FROM mtl_system_items_b msi
             WHERE inventory_item_id = upc_to_iid (c_item_upc) --AND organization_id = 7;  -- Commented 1.0
                   AND organization_id = l_num_org_id;               -- Added 1.0
         */
        -- Commented for 1.3

        -- START : Modified for 1.3.
        CURSOR c_model (c_item_upc IN VARCHAR2)
        IS
            SELECT mc.attribute7
              FROM mtl_system_items_b msi, mtl_item_categories mic, mtl_category_sets mcs,
                   mtl_categories mc
             WHERE     msi.inventory_item_id = upc_to_iid (c_item_upc)
                   AND msi.organization_id = l_num_org_id
                   AND mic.inventory_item_id = msi.inventory_item_id
                   AND mic.organization_id = msi.organization_id
                   AND mic.category_set_id = mcs.category_set_id
                   AND mic.category_id = mc.category_id
                   AND mcs.category_set_name = 'Inventory';

        -- END : Modified for 1.3.

        l_return_line_id       NUMBER;
        l_shipment_line_id     NUMBER;
        l_returned_model       VARCHAR2 (40);
        l_requested_model      VARCHAR2 (40);
        l_unit_list_price      NUMBER;
        l_unit_selling_price   NUMBER;
        l_customer_id          NUMBER;
        l_ship_to_org_id       NUMBER;
        l_invoice_to_org_id    NUMBER;
        l_tax_code             VARCHAR2 (40);
        l_tax_date             DATE;
        l_tax_value            NUMBER;
        l_fluid_recipe_id      VARCHAR2 (50);
    BEGIN
        x_rtn_status   := fnd_api.G_RET_STS_SUCCESS;
        x_error_msg    := NULL;

        -- Start 1.0
        BEGIN
            SELECT organization_id
              INTO l_num_org_id
              FROM mtl_parameters
             WHERE organization_id = master_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_num_org_id   := NULL;
        END;

        -- End 1.0

        -- Create return Order and line
        create_return (p_orig_order_line_id      => p_orig_order_line_id,
                       p_customer_id             => p_customer_id,
                       p_bill_to_site_use_id     => p_bill_to_site_use_id,
                       p_ship_to_site_use_id     => p_ship_to_site_use_id,
                       p_returned_item_upc       => p_returned_item_upc,
                       p_returned_qty            => p_returned_qty,
                       p_ship_from_org_id        => p_ship_from_org_id, -- CCR0007457 ver. 2.0
                       p_price_list_id           => p_price_list_id, -- CCR0008008
                       p_unit_list_price         => NULL, --p_unit_list_price,
                       p_unit_selling_price      => NULL, --p_unit_selling_price,
                       p_tax_code                => NULL,        --p_tax_code,
                       p_tax_date                => NULL,        --p_tax_date,
                       p_tax_value               => NULL,       --p_tax_value,
                       p_return_reason_code      => p_return_reason_code,
                       p_dam_code                => p_dam_code,
                       p_factory_code            => p_factory_code,
                       p_production_code         => p_production_code,
                       p_product_received        => p_product_received, -- Y/N
                       p_return_type             => p_exchange_type,
                       p_return_operator         => p_return_operator,
                       p_return_source           => p_return_source,
                       p_order_header_id         => x_order_header_id,
                       p_orig_sys_document_ref   => p_orig_sys_document_ref,
                       x_order_line_id           => l_return_line_id,
                       x_order_number            => x_order_number,
                       x_rtn_status              => x_rtn_status,
                       x_error_msg               => x_error_msg);

        IF x_rtn_status = fnd_api.G_RET_STS_SUCCESS
        THEN
            -- Create shipment line

            BEGIN
                /* -- START : Commented for 1.3.
                SELECT sold_to_org_id,
                       ship_to_org_id,
                       invoice_to_org_id,
                       msi.segment1,
                          ool.unit_list_price,
                       ool.unit_selling_price,
                       ool.tax_code,
                       ool.tax_date,
                       ool.customer_job
                  INTO l_customer_id,
                       l_ship_to_org_id,
                       l_invoice_to_org_id,
                       l_returned_model,
                       l_unit_list_price,
                       l_unit_selling_price,
                       l_tax_code,
                       l_tax_date,
                       l_fluid_recipe_id
                  FROM oe_order_lines ool, mtl_system_items_b msi
                 WHERE     ool.line_id = p_orig_order_line_id
                       AND msi.inventory_item_id = ool.inventory_item_id
                       AND msi.organization_id = ool.ship_from_org_id;
                 */
                -- END : Commented for 1.3.

                -- START : Modified for 1.3.
                SELECT sold_to_org_id, ship_to_org_id, invoice_to_org_id,
                       mc.attribute7, ool.unit_list_price, ool.unit_selling_price,
                       ool.tax_code, ool.tax_date, ool.customer_job
                  INTO l_customer_id, l_ship_to_org_id, l_invoice_to_org_id, l_returned_model,
                                    l_unit_list_price, l_unit_selling_price, l_tax_code,
                                    l_tax_date, l_fluid_recipe_id
                  FROM oe_order_lines ool, mtl_system_items_b msi, mtl_item_categories mic,
                       mtl_category_sets mcs, mtl_categories mc
                 WHERE     ool.line_id = p_orig_order_line_id
                       AND msi.inventory_item_id = ool.inventory_item_id
                       AND msi.organization_id = ool.ship_from_org_id
                       AND mic.inventory_item_id = msi.inventory_item_id
                       AND mic.organization_id = msi.organization_id
                       AND mic.category_set_id = mcs.category_set_id
                       AND mic.category_id = mc.category_id
                       AND mcs.category_set_name = 'Inventory';
            -- END : Modified for 1.3.

            EXCEPTION
                WHEN OTHERS
                THEN
                    l_returned_model       := NULL;
                    l_unit_list_price      := NULL;
                    l_unit_selling_price   := NULL;
                    l_tax_code             := NULL;
                    l_tax_date             := NULL;
            END;

            --
            IF l_returned_model IS NULL
            THEN
                OPEN c_model (p_returned_item_upc);

                FETCH c_model INTO l_returned_model;

                CLOSE c_model;
            END IF;


            msg (
                   'Requested Item UPC in Create Exchange :: '
                || p_requested_item_upc);

            IF p_requested_item_upc IS NOT NULL
            THEN
                OPEN c_model (p_requested_item_upc);

                FETCH c_model INTO l_requested_model;

                CLOSE c_model;
            END IF;

            --
            IF l_requested_model <> l_returned_model
            THEN
                l_unit_list_price      := NULL;
                l_unit_selling_price   := NULL;
            END IF;

            --

            create_shipment (p_customer_id => NVL (p_customer_id, l_customer_id), p_bill_to_site_use_id => NVL (p_bill_to_site_use_id, l_invoice_to_org_id), p_ship_to_site_use_id => NVL (p_ship_to_site_use_id, l_ship_to_org_id), p_requested_item_upc => p_requested_item_upc, p_ordered_quantity => p_requested_qty, p_ship_from_org_id => p_ship_from_org_id, p_ship_method_code => p_ship_method_code, p_price_list_id => p_price_list_id, -- CCR0008008
                                                                                                                                                                                                                                                                                                                                                                                                                                                  p_unit_list_price => l_unit_list_price, p_unit_selling_price => l_unit_selling_price, p_tax_code => l_tax_code, p_tax_date => l_tax_date, p_tax_value => l_tax_value, p_sfs_flag => 'N', p_fluid_recipe_id => l_fluid_recipe_id, p_order_type => p_exchange_type, p_orig_sys_document_ref => p_orig_sys_document_ref, p_order_header_id => x_order_header_id, x_order_line_id => l_shipment_line_id, x_order_number => x_order_number, x_rtn_status => x_rtn_status
                             , x_error_msg => x_error_msg);

            -- START : Added for 1.1.
            log_debug (
                p_error_location          => 'CREATE_EXCHANGE',
                p_error_number            => NULL,
                p_error_text              => x_error_msg,
                p_orig_sys_document_ref   => p_orig_sys_document_ref,
                p_addtl_info              =>
                       'Input Data ->  P_CUSTOMER_ID : '
                    || NVL (p_customer_id, l_customer_id)
                    || '. P_BILL_TO_SITE_USE_ID : '
                    || NVL (p_bill_to_site_use_id, l_invoice_to_org_id)
                    || '. P_SHIP_TO_SITE_USE_ID : '
                    || NVL (p_ship_to_site_use_id, l_ship_to_org_id)
                    || '. P_REQUESTED_ITEM_UPC  : '
                    || p_requested_item_upc
                    || '. P_ORDERED_QUANTITY    : '
                    || p_requested_qty
                    || '. P_SHIP_METHOD_CODE    : '
                    || p_ship_method_code
                    || '. P_UNIT_LIST_PRICE     : '
                    || l_unit_list_price
                    || '. P_UNIT_SELLING_PRICE  : '
                    || l_unit_selling_price
                    || '. P_TAX_CODE            : '
                    || l_tax_code
                    || '. P_TAX_DATE            : '
                    || l_tax_date
                    || '. P_TAX_VALUE           : '
                    || l_tax_value
                    || '. P_FLUID_RECIPE_ID     : '
                    || l_fluid_recipe_id
                    || '. P_ORDER_TYPE          : '
                    || p_exchange_type
                    || '. P_ORIG_SYS_DOCUMENT_REF : '
                    || p_orig_sys_document_ref
                    || '. P_ORDER_HEADER_ID     : '
                    || x_order_header_id,
                p_idx                     => 6);
        -- END : Added for 1.1.

        -- START : Added for 1.1.
        ELSE
            log_debug (
                p_error_location          => 'CREATE_EXCHANGE',
                p_error_number            => NULL,
                p_error_text              => x_error_msg,
                p_orig_sys_document_ref   => p_orig_sys_document_ref,
                p_addtl_info              =>
                       'Input Data ->  P_ORIG_ORDER_LINE_ID : '
                    || p_orig_order_line_id
                    || '. P_CUSTOMER_ID : '
                    || p_customer_id
                    || '. P_BILL_TO_SITE_USE_ID : '
                    || p_bill_to_site_use_id
                    || '. P_SHIP_TO_SITE_USE_ID : '
                    || p_ship_to_site_use_id
                    || '. P_RETURNED_ITEM_UPC   : '
                    || p_returned_item_upc
                    || '. P_RETURNED_QTY        : '
                    || p_returned_qty
                    || '. P_UNIT_LIST_PRICE     : NULL'
                    || '. P_UNIT_SELLING_PRICE  : NULL'
                    || '. P_TAX_CODE            : NULL'
                    || '. P_TAX_DATE            : NULL'
                    || '. P_TAX_VALUE           : NULL'
                    || '. P_RETURN_REASON_CODE  : '
                    || p_return_reason_code
                    || '. P_DAM_CODE            : '
                    || p_dam_code
                    || '. P_FACTORY_CODE        : '
                    || p_factory_code
                    || '. P_PRODUCTION_CODE     : '
                    || p_production_code
                    || '. P_PRODUCT_RECEIVED    : '
                    || p_product_received
                    || '. P_RETURN_TYPE         : '
                    || p_exchange_type
                    || '. P_RETURN_OPERATOR     : '
                    || p_return_operator
                    || '. P_ORDER_HEADER_ID     : '
                    || x_order_header_id
                    || '. P_ORIG_SYS_DOCUMENT_REF : '
                    || p_orig_sys_document_ref,
                p_idx                     => 7);
        -- END : Added for 1.1.
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status   := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_error_msg    := SQLERRM;
            -- START : Added for 1.1.
            log_debug (p_error_location          => 'CREATE_EXCHANGE',
                       p_error_number            => SQLCODE,
                       p_error_text              => x_error_msg,
                       p_orig_sys_document_ref   => p_orig_sys_document_ref,
                       p_addtl_info              => 'In Exception : OTHERS',
                       p_idx                     => 8);
    -- END : Added for 1.1.
    END create_exchange;

    --
    --  Craete shipment line for an existing order or new order
    --
    PROCEDURE create_lost_shipment (p_orig_order_line_id IN NUMBER, p_order_type IN VARCHAR2, p_ship_method_code IN VARCHAR2, p_orig_sys_document_ref IN VARCHAR2, p_order_header_id IN OUT NUMBER, p_return_operator IN VARCHAR2 DEFAULT NULL, x_order_line_id OUT NUMBER, x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2
                                    , x_error_msg OUT VARCHAR2)
    IS
        CURSOR c_line_dtls IS
            SELECT sold_to_org_id, ship_to_org_id, invoice_to_org_id,
                   ool.inventory_item_id, ool.ordered_quantity, ool.ship_from_org_id,
                   ool.shipping_method_code, ool.unit_list_price, ool.unit_selling_price,
                   ool.tax_code, ool.tax_date, ool.tax_value,
                   ool.customer_job
              FROM oe_order_lines ool
             WHERE     ool.line_id = p_orig_order_line_id
                   AND actual_shipment_date IS NOT NULL
                   AND ool.line_category_code = 'ORDER'
                   AND NVL (cancelled_flag, 'N') = 'N';

        CURSOR c_order_type (c_do_order_type IN VARCHAR2)
        IS
            SELECT transaction_type_id, default_outbound_line_type_id
              FROM oe_transaction_types ott
             WHERE     ott.attribute13 = c_do_order_type
                   AND ott.attribute12 =
                       (SELECT hca.attribute18
                          FROM oe_order_lines ool, hz_cust_accounts hca
                         WHERE     ool.line_id = p_orig_order_line_id
                               AND hca.cust_account_id = ool.sold_to_org_id);

        l_line_rec                c_line_dtls%ROWTYPE;
        l_order_type_id           NUMBER;
        l_outbound_line_type_id   NUMBER;
    BEGIN
        x_rtn_status   := fnd_api.g_ret_sts_success;

        -- Validate orig line ID
        OPEN c_line_dtls;

        FETCH c_line_dtls INTO l_line_rec;

        IF c_line_dtls%NOTFOUND
        THEN
            CLOSE c_line_dtls;

            x_rtn_status   := fnd_api.g_ret_sts_error;
            x_error_msg    :=
                   p_orig_order_line_id
                || ' is Not a Valid Original Order line Id to create lost shipment Order';
        ELSE
            CLOSE c_line_dtls;
        END IF;

        -- Derive Order/Line Type IDs
        OPEN c_order_type (p_order_type);

        FETCH c_order_type INTO l_order_type_id, l_outbound_line_type_id;

        CLOSE c_order_type;

        IF l_order_type_id IS NULL OR l_outbound_line_type_id IS NULL
        THEN
            x_rtn_status   := fnd_api.g_ret_sts_error;
            x_error_msg    :=
                   'Unable to derive Order/Line Type IDs for the combination of eComm website and order type purpose '
                || p_order_type;
        END IF;

        --
        IF x_rtn_status = fnd_api.g_ret_sts_success
        THEN
            create_order_line (p_orig_order_line_id => p_orig_order_line_id, p_customer_id => l_line_rec.sold_to_org_id, p_bill_to_site_use_id => l_line_rec.invoice_to_org_id, p_ship_to_site_use_id => l_line_rec.ship_to_org_id, p_inventory_item_id => l_line_rec.inventory_item_id, p_requested_qty => l_line_rec.ordered_quantity, p_ship_from_org_id => l_line_rec.ship_from_org_id, p_ship_method_code => NVL (p_ship_method_code, l_line_rec.shipping_method_code), p_price_list_id => NULL, -- CCR0008008
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      p_unit_list_price => l_line_rec.unit_list_price, p_unit_selling_price => l_line_rec.unit_selling_price, p_tax_code => l_line_rec.tax_code, p_tax_date => l_line_rec.tax_date, p_tax_value => l_line_rec.tax_value, p_fluid_recipe_id => l_line_rec.customer_job, p_return_reason_code => NULL, p_dam_code => NULL, p_factory_code => NULL, p_production_code => NULL, p_line_type_id => l_outbound_line_type_id, -- shipment
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       p_order_type_id => l_order_type_id, p_orig_sys_document_ref => p_orig_sys_document_ref, p_order_header_id => p_order_header_id, p_return_operator => p_return_operator, x_order_line_id => x_order_line_id, x_order_number => x_order_number, x_rtn_status => x_rtn_status
                               , x_error_msg => x_error_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status   := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_error_msg    := SQLERRM;
    END create_lost_shipment;

    --
    -- Receive the product on a return/exchange order
    --
    PROCEDURE receive_product (p_order_line_id IN NUMBER, p_returned_qty IN NUMBER, p_subinventory IN VARCHAR2
                               , p_locator_id IN NUMBER, x_rtn_status OUT VARCHAR2, x_error_msg OUT VARCHAR2)
    IS
        CURSOR c_rtn_line IS
            SELECT ool.sold_to_org_id customer_id, ool.ship_from_org_id, ool.ship_to_org_id,
                   ool.org_id, ool.inventory_item_id, uom.unit_of_measure,
                   ooh.order_number, ool.header_id, ool.line_id,
                   mp.wms_enabled_flag
              FROM oe_order_lines ool, oe_order_headers ooh, mtl_units_of_measure uom,
                   mtl_parameters mp
             WHERE     ool.line_id = p_order_line_id
                   AND ool.line_category_code = 'RETURN'
                   AND ooh.header_id = ool.header_id
                   AND uom.uom_code = ool.order_quantity_uom
                   AND mp.organization_id = ool.ship_from_org_id;

        CURSOR c_rtn_locator (c_inv_org_id IN NUMBER, c_subinv_code VARCHAR2)
        IS
            SELECT inventory_location_id
              FROM mtl_item_locations
             WHERE     organization_id = c_inv_org_id
                   AND subinventory_code = c_subinv_code
                   AND segment1 = 'RTN'
                   AND segment5 = 'CD';

        c_line                c_rtn_line%ROWTYPE;
        l_subinventory        VARCHAR2 (40);
        l_dflt_subinventory   VARCHAR2 (40) := 'RETURNS';
        --  l_3pl_subinventory    VARCHAR2 (40) := 'QCHOLD';
        l_3pl_subinventory    VARCHAR2 (40) := 'RETURNS'; -- Modified for 1.4.
        l_dflt_locator_id     NUMBER;
        l_loc_control_code    mtl_parameters.stock_locator_control_code%TYPE; -- Added 1.0
    BEGIN
        x_rtn_status   := fnd_api.G_RET_STS_SUCCESS;
        x_error_msg    := NULL;

        -- Validate return Line ID
        OPEN c_rtn_line;

        FETCH c_rtn_line INTO c_line;

        IF c_rtn_line%NOTFOUND
        THEN
            CLOSE c_rtn_line;

            x_rtn_status   := fnd_api.G_RET_STS_ERROR;
            x_error_msg    :=
                p_order_line_id || ' - is not a valid Order line to Receive';
        ELSE
            CLOSE c_rtn_line;
        END IF;

        IF c_line.wms_enabled_flag = 'Y'
        THEN
            l_subinventory   := NVL (p_subinventory, l_dflt_subinventory);
        ELSE
            l_subinventory   := NVL (p_subinventory, l_3pl_subinventory);
        END IF;

        /*
         Changes incorporated for HighJump -Start
         */
        BEGIN
            SELECT ha.attribute3
              INTO l_subinventory
              FROM oe_order_lines_all ool, mtl_parameters mp, hr_all_organization_units ha
             WHERE     line_id = p_order_line_id
                   AND ool.ship_from_org_id = mp.organization_id
                   AND mp.organization_id = ha.organization_id
                   AND mp.organization_code IN
                           (SELECT lookup_code
                              FROM fnd_lookup_values fvl
                             WHERE     fvl.lookup_type = 'XXONT_WMS_WHSE'
                                   AND NVL (LANGUAGE, USERENV ('LANG')) =
                                       USERENV ('LANG')
                                   AND fvl.enabled_flag = 'Y')
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        /*
        Changes incorporated for HighJump -End
        */

        -- Derive default locator ID
        -- Start 1.0
        BEGIN
            SELECT stock_locator_control_code
              INTO l_loc_control_code
              FROM mtl_parameters
             WHERE organization_id = c_line.ship_from_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_loc_control_code   := NULL;
        END;

        -- End 1.0

        -- Added 1.0
        IF l_loc_control_code <> 1
        THEN
            IF p_locator_id IS NULL AND c_line.wms_enabled_flag = 'Y'
            THEN
                OPEN c_rtn_locator (c_line.ship_from_org_id, l_subinventory);

                FETCH c_rtn_locator INTO l_dflt_locator_id;

                IF c_rtn_locator%NOTFOUND
                THEN
                    CLOSE c_rtn_locator;

                    x_rtn_status   := fnd_api.G_RET_STS_ERROR;
                    x_error_msg    :=
                        'Uable to find the Locator ID to receive the product into';
                ELSE
                    CLOSE c_rtn_locator;
                END IF;
            ELSE
                l_dflt_locator_id   := p_locator_id;    -- CCR0006939 ver. 1.8
            END IF;
        ELSIF l_loc_control_code = 1
        THEN
            l_dflt_locator_id   := NULL;
        END IF;                                                   -- Added 1.0

        -- Insert data into receiving Interface Tables
        IF x_rtn_status = fnd_api.G_RET_STS_SUCCESS
        THEN
            INSERT INTO apps.rcv_headers_interface (header_interface_id, GROUP_ID, org_id, processing_status_code, receipt_source_code, transaction_type, auto_transact_code, last_update_date, last_updated_by, last_update_login, creation_date, created_by, expected_receipt_date, employee_id, validation_flag
                                                    , customer_id)
                 VALUES (rcv_headers_interface_s.NEXTVAL, rcv_interface_groups_s.NEXTVAL, c_line.org_id, 'PENDING', 'CUSTOMER', 'NEW', 'DELIVER', SYSDATE, fnd_global.user_id, USERENV ('SESSIONID'), SYSDATE, fnd_global.user_id, SYSDATE, fnd_global.employee_id, 'Y'
                         , c_line.customer_id);

            --
            INSERT INTO rcv_transactions_interface (interface_transaction_id,
                                                    GROUP_ID,
                                                    org_id,
                                                    last_update_date,
                                                    last_updated_by,
                                                    creation_date,
                                                    created_by,
                                                    last_update_login,
                                                    transaction_type,
                                                    transaction_date,
                                                    processing_status_code,
                                                    processing_mode_code,
                                                    transaction_status_code,
                                                    item_id,
                                                    quantity,
                                                    unit_of_measure,
                                                    interface_source_code,
                                                    employee_id,
                                                    auto_transact_code,
                                                    receipt_source_code,
                                                    source_document_code,
                                                    document_num,
                                                    destination_type_code,
                                                    to_organization_id,
                                                    subinventory,
                                                    locator_id,
                                                    expected_receipt_date,
                                                    header_interface_id,
                                                    validation_flag,
                                                    oe_order_header_id,
                                                    oe_order_line_id,
                                                    customer_id,
                                                    customer_site_id)
                     VALUES (RCV_TRANSACTIONS_INTERFACE_S.NEXTVAL,
                             RCV_INTERFACE_GROUPS_S.CURRVAL,
                             c_line.org_id,
                             SYSDATE,
                             apps.fnd_global.user_id,
                             SYSDATE,
                             apps.fnd_global.user_id,
                             USERENV ('SESSIONID'),
                             'RECEIVE',
                             SYSDATE,
                             'PENDING',
                             'BATCH',
                             'PENDING',
                             c_line.inventory_item_id,
                             p_returned_qty,
                             c_line.unit_of_measure,
                             'RCV',
                             fnd_global.employee_id,
                             'DELIVER',
                             'CUSTOMER',
                             'RMA',
                             TO_CHAR (c_line.order_number),
                             'INVENTORY',
                             c_line.ship_from_org_id,
                             l_subinventory,
                             NVL (p_locator_id, l_dflt_locator_id),
                             SYSDATE,
                             RCV_HEADERS_INTERFACE_S.CURRVAL,
                             'Y',
                             c_line.header_id,
                             c_line.line_id,
                             c_line.customer_id,
                             c_line.ship_to_org_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status   := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_error_msg    := SQLERRM;
    END receive_product;

    --
    --
    --
    PROCEDURE create_multi_line_order (p_do_order_type IN VARCHAR2, p_customer_id IN NUMBER, p_bill_to_site_use_id IN NUMBER, p_ship_to_site_use_id IN NUMBER, p_orig_sys_document_ref IN VARCHAR2, p_line_tbl IN xxdoec_Line_Tbl_Type, p_return_operator IN VARCHAR2 DEFAULT NULL, p_return_source IN VARCHAR2, p_price_list_id IN NUMBER, -- CCR0008008
                                                                                                                                                                                                                                                                                                                                            x_order_header_id IN OUT NUMBER, x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2
                                       , x_error_msg OUT VARCHAR2)
    AS
        l_return_line_id       NUMBER;
        l_shipment_line_id     NUMBER;
        l_returned_model       VARCHAR2 (40);
        l_requested_model      VARCHAR2 (40);
        l_unit_list_price      NUMBER;
        l_unit_selling_price   NUMBER;
        l_customer_id          NUMBER;
        l_ship_to_org_id       NUMBER;
        l_invoice_to_org_id    NUMBER;
        l_tax_code             VARCHAR2 (40);
        l_tax_date             DATE;
        l_fluid_recipe_id      VARCHAR2 (50);
        l_rtn_item_tbl         rtn_item_tbl_type;
        l_rtn_status           VARCHAR2 (1);
        l_error_msg            VARCHAR2 (2000);
        l_num_org_id           NUMBER := 0;                       -- Added 1.0

        /* -- START Commented for 1.3.
        CURSOR c_model (c_item_upc IN VARCHAR2)
        IS
           SELECT  -- msi.segment1  -- Commented for 1.3.
                SUBSTR (msi.segment1, 1, (INSTR (msi.segment1, '-', 1, 1) - 1)) -- Modified for 1.3.
             FROM mtl_system_items_b msi
            WHERE inventory_item_id = upc_to_iid (c_item_upc) --AND organization_id = 7; -- Commented 1.0
                  AND organization_id = l_num_org_id;               -- Added 1.0
        */
        -- START Commented for 1.3.

        -- START : Modified for 1.3.
        CURSOR c_model (c_item_upc IN VARCHAR2)
        IS
            SELECT mc.attribute7
              FROM mtl_system_items_b msi, mtl_item_categories mic, mtl_category_sets mcs,
                   mtl_categories mc
             WHERE     msi.inventory_item_id = upc_to_iid (c_item_upc)
                   AND msi.organization_id = l_num_org_id
                   AND mic.inventory_item_id = msi.inventory_item_id
                   AND mic.organization_id = msi.organization_id
                   AND mic.category_set_id = mcs.category_set_id
                   AND mic.category_id = mc.category_id
                   AND mcs.category_set_name = 'Inventory';
    -- END : Modified for 1.3.

    BEGIN
        x_rtn_status   := fnd_api.G_RET_STS_SUCCESS;
        x_error_msg    := NULL;

        -- Start 1.0
        BEGIN
            SELECT organization_id
              INTO l_num_org_id
              FROM mtl_parameters
             WHERE organization_id = master_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_num_org_id   := NULL;
        END;

        -- End 1.0

        l_rtn_item_tbl.delete;

        IF p_line_tbl.COUNT > 0
        THEN
            -- Create return lines first
            FOR i IN p_line_tbl.FIRST .. p_line_tbl.LAST
            LOOP
                IF p_line_tbl (i).p_do_line_type = 'RETURN'
                THEN
                    l_rtn_item_tbl (i).p_returned_item_upc   :=
                        p_line_tbl (i).p_item_upc;
                    l_rtn_item_tbl (i).p_orig_order_line_id   :=
                        p_line_tbl (i).p_orig_order_line_id;
                    create_return (
                        p_orig_order_line_id      =>
                            p_line_tbl (i).p_orig_order_line_id,
                        p_customer_id             => p_customer_id,
                        p_bill_to_site_use_id     => p_bill_to_site_use_id,
                        p_ship_to_site_use_id     => p_ship_to_site_use_id,
                        p_returned_item_upc       => p_line_tbl (i).p_item_upc,
                        p_returned_qty            => p_line_tbl (i).p_quantity,
                        p_ship_from_org_id        =>
                            p_line_tbl (i).p_ship_from_org_id,   -- CCR0007457
                        p_price_list_id           => p_price_list_id, -- CCR0008008
                        p_unit_list_price         =>
                            p_line_tbl (i).p_unit_list_price,
                        p_unit_selling_price      =>
                            p_line_tbl (i).p_unit_selling_price,
                        p_tax_code                => p_line_tbl (i).p_tax_code,
                        p_tax_date                => p_line_tbl (i).p_tax_date,
                        p_tax_value               => p_line_tbl (i).p_tax_value,
                        p_dam_code                => p_line_tbl (i).p_dam_code,
                        p_factory_code            =>
                            p_line_tbl (i).p_factory_code,
                        p_production_code         =>
                            p_line_tbl (i).p_production_code,
                        p_return_reason_code      =>
                            p_line_tbl (i).p_return_reason_code,
                        p_product_received        =>
                            p_line_tbl (i).p_product_received,          -- Y/N
                        p_return_type             => p_do_order_type,
                        p_order_header_id         => x_order_header_id,
                        p_return_operator         => p_return_operator,
                        p_return_source           => p_return_source,
                        p_orig_sys_document_ref   => p_orig_sys_document_ref,
                        x_order_line_id           => l_return_line_id,
                        x_order_number            => x_order_number,
                        x_rtn_status              => l_rtn_status,
                        x_error_msg               => l_error_msg);

                    IF l_rtn_status <> fnd_api.G_RET_STS_SUCCESS
                    THEN
                        x_rtn_status   := l_rtn_status;
                        x_error_msg    := x_error_msg || l_error_msg;
                    END IF;
                END IF;
            END LOOP;

            -- Create Exchange lines next
            FOR i IN p_line_tbl.FIRST .. p_line_tbl.LAST
            LOOP
                IF p_line_tbl (i).p_do_line_type = 'ORDER'
                THEN
                    FOR j IN l_rtn_item_tbl.FIRST .. l_rtn_item_tbl.LAST
                    LOOP
                        IF l_rtn_item_tbl (j).p_orig_order_line_id
                               IS NOT NULL
                        THEN
                            BEGIN
                                /* -- START : Commented for 1.3.
                                   SELECT sold_to_org_id,
                                          ship_to_org_id,
                                          invoice_to_org_id,
                                          msi.segment1,
                                          ool.unit_list_price,
                                          ool.unit_selling_price,
                                          ool.tax_code,
                                          ool.tax_date,
                                          ool.customer_job
                                     INTO l_customer_id,
                                          l_ship_to_org_id,
                                          l_invoice_to_org_id,
                                          l_returned_model,
                                          l_unit_list_price,
                                          l_unit_selling_price,
                                          l_tax_code,
                                          l_tax_date,
                                          l_fluid_recipe_id
                                     FROM oe_order_lines ool, mtl_system_items_b msi
                                    WHERE     ool.line_id =
                                                 l_rtn_item_tbl (j).p_orig_order_line_id
                                          AND msi.inventory_item_id =
                                                 ool.inventory_item_id
                                          AND msi.organization_id = ool.ship_from_org_id;
                                  */
                                -- END : Commented for 1.3.

                                -- START : Modified for 1.3.
                                SELECT sold_to_org_id, ship_to_org_id, invoice_to_org_id,
                                       mc.attribute7, ool.unit_list_price, ool.unit_selling_price,
                                       ool.tax_code, ool.tax_date, ool.customer_job
                                  INTO l_customer_id, l_ship_to_org_id, l_invoice_to_org_id, l_returned_model,
                                                    l_unit_list_price, l_unit_selling_price, l_tax_code,
                                                    l_tax_date, l_fluid_recipe_id
                                  FROM oe_order_lines ool, mtl_system_items_b msi, mtl_item_categories mic,
                                       mtl_category_sets mcs, mtl_categories mc
                                 WHERE     ool.line_id =
                                           l_rtn_item_tbl (j).p_orig_order_line_id
                                       AND msi.inventory_item_id =
                                           ool.inventory_item_id
                                       AND msi.organization_id =
                                           ool.ship_from_org_id
                                       AND mic.inventory_item_id =
                                           msi.inventory_item_id
                                       AND mic.organization_id =
                                           msi.organization_id
                                       AND mic.category_set_id =
                                           mcs.category_set_id
                                       AND mic.category_id = mc.category_id
                                       AND mcs.category_set_name =
                                           'Inventory';
                            -- END : Modified for 1.3.
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_returned_model       := NULL;
                                    l_unit_list_price      := NULL;
                                    l_unit_selling_price   := NULL;
                                    l_tax_code             := NULL;
                                    l_tax_date             := NULL;
                                    l_fluid_recipe_id      := NULL;
                            END;


                            msg (
                                   'Requested Item UPC in Create Multi Line Order :: '
                                || p_line_tbl (i).p_item_upc);

                            IF p_line_tbl (i).p_item_upc IS NOT NULL
                            THEN
                                OPEN c_model (p_line_tbl (i).p_item_upc);

                                FETCH c_model INTO l_requested_model;

                                CLOSE c_model;
                            END IF;

                            --
                            IF l_requested_model <> l_returned_model
                            THEN
                                l_unit_list_price      := NULL;
                                l_unit_selling_price   := NULL;
                            ELSE
                                EXIT;
                            END IF;
                        --
                        END IF;
                    END LOOP;

                    --
                    create_shipment (p_customer_id => NVL (p_customer_id, l_customer_id), p_bill_to_site_use_id => NVL (p_bill_to_site_use_id, l_invoice_to_org_id), p_ship_to_site_use_id => NVL (p_ship_to_site_use_id, l_ship_to_org_id), p_requested_item_upc => p_line_tbl (i).p_item_upc, p_ordered_quantity => p_line_tbl (i).p_quantity, p_ship_from_org_id => p_line_tbl (i).p_ship_from_org_id, p_ship_method_code => p_line_tbl (i).p_ship_method_code, p_price_list_id => p_price_list_id, -- CCR0008008
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       p_unit_list_price => NVL (p_line_tbl (i).p_unit_list_price, l_unit_list_price), p_unit_selling_price => NVL (p_line_tbl (i).p_unit_selling_price, l_unit_selling_price), p_tax_code => NVL (p_line_tbl (i).p_tax_code, l_tax_code), p_tax_date => NVL (p_line_tbl (i).p_tax_date, l_tax_date), p_tax_value => p_line_tbl (i).p_tax_value, p_sfs_flag => p_line_tbl (i).p_sfs_flag, p_fluid_recipe_id => l_fluid_recipe_id, p_order_type => p_do_order_type, p_orig_sys_document_ref => p_orig_sys_document_ref, p_order_header_id => x_order_header_id, x_order_line_id => l_shipment_line_id, x_order_number => x_order_number, x_rtn_status => l_rtn_status
                                     , x_error_msg => l_error_msg);

                    IF l_rtn_status <> fnd_api.G_RET_STS_SUCCESS
                    THEN
                        x_rtn_status   := l_rtn_status;
                        x_error_msg    := x_error_msg || l_error_msg;
                    END IF;
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status   := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_error_msg    := SQLERRM;
    END create_multi_line_order;

    PROCEDURE create_multi_line_return (
        P_ORDER_ID               IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.ORDER_ID%TYPE,
        P_ORIGINAL_DW_ORDER_ID   IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.ORIGINAL_DW_ORDER_ID%TYPE,
        --P_ORDER_DATE                  IN XXDO.XXDOEC_RETURN_HEADER_STAGING.ORIGINAL_DW_ORDER_ID%TYPE, -- Commented 1.0
        P_ORDER_DATE             IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.ORDER_DATE%TYPE, -- Modified 1.0
        P_CURRENCY               IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.CURRENCY%TYPE,
        P_DW_CUSTOMER_ID         IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.DW_CUSTOMER_ID%TYPE,
        P_ORACLE_CUSTOMER_ID     IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.ORACLE_CUSTOMER_ID%TYPE,
        P_BILL_TO_ADDR_ID        IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.BILL_TO_ADDR_ID%TYPE,
        P_SHIP_TO_ADDR_ID        IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.SHIP_TO_ADDR_ID%TYPE,
        P_ORDER_TOTAL            IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.ORDER_TOTAL%TYPE,
        P_NET_ORDER_TOTAL        IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.NET_ORDER_TOTAL%TYPE,
        P_TOTAL_ORDER_TAX        IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.TOTAL_ORDER_TAX%TYPE,
        P_SITE_ID                IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.SITE_ID%TYPE,
        P_RETURN_TYPE            IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.RETURN_TYPE%TYPE,
        P_XMLPAYLOAD             IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.XMLPAYLOAD%TYPE,
        P_LINE_TBL               IN     APPS.XXDOEC_RETURN_LINE_TBL_TYPE,
        X_STATUS                    OUT VARCHAR2,
        X_ERROR_MSG                 OUT VARCHAR2)
    IS
        l_step         VARCHAR2 (200) := 'initial:  ';  --what step are we on?
        l_err_num      NUMBER := -1;                          --error handling
        l_err_msg      VARCHAR2 (100) := '';                  --error handling
        l_message      VARCHAR2 (1000) := '';         --for message processing
        l_runnum       NUMBER := 0;
        l_rc           NUMBER := 0;                       --New for DCDLogging
        l_debug        NUMBER := 0; -- change to 1 if debugging using a script in Toad.
        l_order_no     XXDO.XXDOEC_RETURN_HEADER_STAGING.ORDER_ID%TYPE;
        l_do           VARCHAR2 (10) := 'YES';
        l_seq          NUMBER := -1;
        -- TODO:  Instantiate the DCDLogger - need DB recs for this.
        DCDLog         DCDLog_type
            := DCDLog_type (P_CODE => -10001, P_APPLICATION => G_APPLICATION, P_LOGEVENTTYPE => 4
                            , P_TRACELEVEL => 1, P_DEBUG => l_debug); -- instantiate object with startup message.
        DCDLogParams   DCDLogParameters_type
                           := DCDLogParameters_type (NULL, NULL, NULL,
                                                     NULL);
    BEGIN
        x_status      := fnd_api.G_RET_STS_SUCCESS;
        x_error_msg   := NULL;
        l_order_no    := 'GOOD';

        -- Check to make sure P_ORDER_ID is not null
        IF P_ORDER_ID = NULL OR P_ORDER_ID = ''
        THEN
            X_STATUS      := 'F';
            X_ERROR_MSG   := 'NULL OR EMPTY ORDER ID PROVIDED.';
            l_do          := 'NO';
        END IF;

        IF l_do = 'YES'
        THEN
            IF (l_order_no = 'GOOD')
            THEN                 --Only insert the header if it does not exist
                -- Insert header
                SELECT xxdo.xxdoec_returns_hdr_seq.NEXTVAL
                  INTO l_seq
                  FROM DUAL;

                INSERT INTO XXDO.XXDOEC_RETURN_HEADER_STAGING
                     VALUES (l_seq, P_ORDER_ID, P_ORIGINAL_DW_ORDER_ID,
                             P_ORDER_DATE, P_CURRENCY, P_DW_CUSTOMER_ID,
                             P_ORACLE_CUSTOMER_ID, P_BILL_TO_ADDR_ID, P_SHIP_TO_ADDR_ID, P_ORDER_TOTAL, P_NET_ORDER_TOTAL, P_TOTAL_ORDER_TAX
                             , P_SITE_ID, P_RETURN_TYPE, P_XMLPAYLOAD);
            END IF;

            --Insert lines
            FOR i IN p_line_tbl.FIRST .. p_line_tbl.LAST
            LOOP
                IF l_do = 'YES'
                THEN
                    BEGIN
                        INSERT INTO XXDO.XXDOEC_RETURN_LINES_STAGING (
                                        ID,
                                        SKU,
                                        UPC,
                                        QUANTITY,
                                        LINE_TYPE,
                                        ORDER_ID,
                                        LINE_ID,
                                        EXCHANGE_PREFERENCE,
                                        RETURN_REASON,
                                        STATUS)
                             VALUES (l_seq, p_line_tbl (i).SKU, -- p_line_tbl (i).RETURN_REASON, ---- CCR0007571
                                                                p_line_tbl (i).UPC, -- CCR0007571
                                                                                    p_line_tbl (i).QUANTITY, p_line_tbl (i).LINE_TYPE, p_line_tbl (i).ORDER_ID, p_line_tbl (i).LINE_ID, p_line_tbl (i).EXCHANGE_PREFERENCE, p_line_tbl (i).RETURN_REASON
                                     , 'N');
                    END;
                END IF;
            END LOOP;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                l_err_num             := SQLCODE;
                l_err_msg             := SUBSTR (SQLERRM, 1, 100);
                l_message             :=
                    'ERROR creating multi-line return staging records:  ';
                l_message             :=
                       l_step
                    || l_message
                    || ' err_num='
                    || TO_CHAR (l_err_num)
                    || ' err_msg='
                    || l_err_msg
                    || '.';
                DCDLog.ChangeCode (P_CODE => -10017, P_APPLICATION => G_APPLICATION, P_LOGEVENTTYPE => 1
                                   , P_TRACELEVEL => 1, P_DEBUG => l_debug);
                DCDLog.FunctionName   := 'create_multi_line_return';
                DCDLog.AddParameter ('l_step', l_step, 'VARCHAR2');
                DCDLog.AddParameter ('SQLCODE',
                                     TO_CHAR (l_err_num),
                                     'NUMBER');
                DCDLog.AddParameter ('SQLERRM', l_err_msg, 'VARCHAR2');
                l_rc                  := DCDLog.LogInsert ();

                IF (l_rc <> 1)
                THEN
                    msg (DCDLog.l_message);
                END IF;

                DCDLog.ChangeCode (P_CODE => -10017, P_APPLICATION => G_APPLICATION, P_LOGEVENTTYPE => 1
                                   , P_TRACELEVEL => 1, P_DEBUG => l_debug);
                DCDLog.FunctionName   := 'create_multi_line_return';
                l_rc                  := DCDLog.LogInsert ();

                IF (l_rc <> 1)
                THEN
                    msg (DCDLog.l_message);
                END IF;

                X_STATUS              := 'F';
                X_ERROR_MSG           := l_message;
            END;
    END;

    --
    -- Only used on Retail Exchanges when the exchange shoe line got cancelled due to out of stock
    --
    PROCEDURE add_store_credit (p_order_line_id IN NUMBER, p_order_header_id IN OUT NUMBER, x_order_line_id OUT NUMBER
                                , x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2, x_error_msg OUT VARCHAR2)
    IS
        l_customer_id            NUMBER;
        l_ship_to_org_id         NUMBER;
        l_invoice_to_org_id      NUMBER;
        l_shipping_method_code   VARCHAR2 (120);
        l_unit_selling_price     NUMBER;
        l_email_address          VARCHAR2 (240);
        l_brand                  VARCHAR2 (30);
        l_do_order_type          VARCHAR2 (30);
        l_store_card_type        VARCHAR2 (30);
        l_store_card_upc         VARCHAR2 (30);
        l_num_org_id             NUMBER := 0;                     -- Added 1.0
    BEGIN
        -- Start 1.0
        BEGIN
            SELECT organization_id
              INTO l_num_org_id
              FROM mtl_parameters
             WHERE organization_id = master_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_num_org_id   := NULL;
        END;

        -- End 1.0
        x_rtn_status   := fnd_api.g_ret_sts_success;

        -- Validate Order Line ID
        BEGIN
            SELECT ool.sold_to_org_id,
                   ool.ship_to_org_id,
                   ool.invoice_to_org_id,
                   ool.shipping_method_code,
                   ool.unit_selling_price,
                   (SELECT hcp.email_address
                      FROM hz_cust_Accounts hca, hz_contact_points hcp
                     WHERE     hca.cust_account_id = ool.sold_to_org_id
                           AND hcp.contact_point_type(+) = 'EMAIL'
                           AND hcp.owner_table_name(+) = 'HZ_PARTIES'
                           AND hcp.owner_table_id(+) = hca.party_id
                           AND ROWNUM = 1) email_address,
                   ooh.attribute5 brand,
                   ott.attribute13 do_order_type
              INTO l_customer_id, l_ship_to_org_id, l_invoice_to_org_id, l_shipping_method_code,
                                l_unit_selling_price, l_email_address, l_brand,
                                l_do_order_type
              FROM oe_order_lines ool, oe_order_headers ooh, oe_transaction_types ott
             WHERE     ool.line_id = p_order_line_id
                   AND ooh.header_id = ool.header_id
                   AND ott.transaction_type_id = ooh.order_type_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_rtn_status   := fnd_api.g_ret_sts_error;
                x_error_msg    :=
                       p_order_line_id
                    || ' is Not a Valid Order line Id to create store credit against';
        END;

        -- derive store card item UPC
        IF l_email_Address IS NOT NULL
        THEN
            l_store_card_type        := 'VCARD';
            l_shipping_method_code   := 'VCRD';
        ELSE
            l_store_card_type   := 'PCARD';
        END IF;

        --
        BEGIN
            SELECT attribute11
              INTO l_store_card_upc
              FROM mtl_system_items_b
             WHERE                              --segment1 = l_store_card_type
                       --AND segment2 = l_brand
                       --AND segment3 = 'NA'
                       segment1 =
                       l_store_card_type || '-' || l_brand || '-' || 'NA' -- Added 1.0
                   --AND organization_id = 7; Commented 1.0
                   AND organization_id = l_num_org_id;            -- Added 1.0
        EXCEPTION
            WHEN OTHERS
            THEN
                x_rtn_status   := fnd_api.g_ret_sts_error;
                x_error_msg    :=
                       'Could not find the Store Credit item for brand '
                    || l_brand
                    || ' and type '
                    || l_store_card_type;
        END;

        --
        IF x_rtn_status = fnd_api.g_ret_sts_success
        THEN
            create_shipment (p_customer_id => l_customer_id, p_bill_to_site_use_id => l_invoice_to_org_id, p_ship_to_site_use_id => l_ship_to_org_id, p_requested_item_upc => l_store_card_upc, p_ordered_quantity => 1, p_ship_from_org_id => NULL, p_ship_method_code => l_shipping_method_code, p_price_list_id => NULL, -- CCR0008008
                                                                                                                                                                                                                                                                                                                            p_unit_list_price => 0, p_unit_selling_price => l_unit_selling_price, p_tax_code => NULL, p_tax_date => NULL, p_tax_value => NULL, p_sfs_flag => 'N', p_fluid_recipe_id => NULL, p_order_type => l_do_order_type, p_orig_sys_document_ref => NULL, p_order_header_id => p_order_header_id, x_order_line_id => x_order_line_id, x_order_number => x_order_number, x_rtn_status => x_rtn_status
                             , x_error_msg => x_error_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status   := fnd_api.G_RET_STS_UNEXP_ERROR;
            x_error_msg    := SQLERRM;
    END add_store_credit;

    --
    PROCEDURE get_next_cust_number (x_return_number OUT NUMBER)
    AS
    BEGIN
        SELECT XXDOEC_SEQ_RTRN_CUST_NUM.NEXTVAL
          INTO x_return_number
          FROM DUAL;
    END get_next_cust_number;

    --
    --
    --
    PROCEDURE get_next_order_number (x_return_number OUT NUMBER)
    AS
    BEGIN
        SELECT XXDOEC_SEQ_RTRN_ORDER_NUM.NEXTVAL
          INTO x_return_number
          FROM DUAL;
    END get_next_order_number;

    PROCEDURE update_rtn_staging_line_status (p_order_number IN VARCHAR2, p_line_id IN NUMBER, p_status IN VARCHAR2)
    AS
        l_rtn_status   VARCHAR2 (10) := '';
    BEGIN
        BEGIN
            UPDATE XXDO.XXDOEC_RETURN_LINES_STAGING
               SET status   = p_status
             WHERE order_id = p_order_number AND ID = p_line_id;

            COMMIT;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_rtn_status   := 'GOOD';
        END;
    END update_rtn_staging_line_status;
END xxdoec_returns_exchanges_pkg;
/
