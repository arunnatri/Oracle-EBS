--
-- XXD_SALES_ORDER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_SALES_ORDER_PKG"
IS
    /*******************************************************************************
    * PACKAGE NAME : XXD_SALES_ORDER_PKG
    * LANGUAGE     : PL/SQL
    * DESCRIPTION  : This Package will be referred in DOE.
    *
    * WHO            DESC                                            WHEN
    * -------------- ---------------------------------------------- ---------------
    * Infosys        Modified to fix DOE issues while booking        May/31/2016
    *                orders, as part of DOE2.1
    * Infosys        Error while modifying Orders/RMA INC0296155  Jun/13/2016
    * 1.3 Infosys       Copied the same Cancel date value to Latest
    *                Acceptable date                                  Mar/07/2017
    * 1.4 Infosys    Fixed LAD                                     JUN/06/2017
    * --------------------------------------------------------------------------- */

    --This procedure is used to create sales order
    -- AT Header record type p_header_rec.attribute3 is using for Vas Code
    --                       p_header_rec.attribute1 is using for freight terms
    -- At Line record type   p_line_tbl.attribute1 is using for  Shipping Instruction
    --                       p_line_tbl.attribute2 is using for  Packing Instruction
    --                       p_line_tbl.attribute3 is using for  Vas Code
    --                       p_line_tbl.attribute4 is using for  Deliver to org id
    --                       p_line_tbl.attribute5 is using for  cust po number

    PROCEDURE create_order (p_header_rec IN xxd_btom_oeheader_tbltype, p_line_tbl IN xxd_btom_oeline_tbltype, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_action IN VARCHAR2, p_call_from IN VARCHAR2, x_header_id OUT VARCHAR2, x_error_flag OUT VARCHAR2
                            , x_error_message OUT VARCHAR2, x_atp_error_message OUT VARCHAR2, x_atp_error_flag OUT VARCHAR2)
    IS
        ln_api_version_number          NUMBER := 1;
        lc_return_status               VARCHAR2 (10);
        ln_msg_count                   NUMBER;
        lc_msg_data                    VARCHAR2 (4000);
        ln_org_id                      NUMBER;
        ln_line_count                  NUMBER;
        lc_error_message               VARCHAR2 (4000);
        lc_atp_error_msg               VARCHAR2 (4000) := NULL;
        lc_atp_error_flag              VARCHAR2 (10);
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
        lc_demand_class_code           VARCHAR2 (60);
        lc_demand_class                VARCHAR2 (60);
        ln_salesrep_cnt                NUMBER;
        ln_salesrep_id                 NUMBER;
        ln_nosalesep_id                NUMBER;
        lr_header_rec                  xxd_btom_oeheader_tbltype;
        lr_line_tbl                    xxd_btom_oeline_tbltype;
        ln_hold_count                  NUMBER;
        ln_cr_hold_count               NUMBER;
        ln_cr_hold_comment             VARCHAR2 (600);

        CURSOR lcu_get_demand_class_code (p_demand_class VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values
             WHERE     lookup_type = 'DEMAND_CLASS'
                   AND LANGUAGE = USERENV ('LANG')
                   AND meaning = p_demand_class;

        CURSOR lc_get_demand (p_cust_account_id NUMBER)
        IS
            SELECT attribute13
              FROM hz_cust_accounts
             WHERE cust_account_id = p_cust_account_id;

        CURSOR lc_get_multisales_rep (p_org_id NUMBER)
        IS
            SELECT salesrep_id
              FROM ra_salesreps
             WHERE     status = 'A'
                   AND org_id = p_org_id
                   AND SYSDATE BETWEEN start_date_active
                                   AND NVL (end_date_active, SYSDATE)
                   AND NAME IN
                           (SELECT DISTINCT attribute3
                              FROM fnd_lookup_values
                             WHERE     lookup_type = 'XXDO_SALESREP_DEFAULTS'
                                   AND LANGUAGE = USERENV ('LANG'));

        CURSOR lc_get_nosales_rep IS
            SELECT salesrep_id
              FROM ra_salesreps
             WHERE     status = 'A'
                   AND SYSDATE BETWEEN start_date_active
                                   AND NVL (end_date_active, SYSDATE)
                   AND NAME IN
                           (SELECT DISTINCT attribute4
                              FROM fnd_lookup_values
                             WHERE     lookup_type = 'XXDO_SALESREP_DEFAULTS'
                                   AND LANGUAGE = USERENV ('LANG'));
    BEGIN
        -- INITIALIZE ENVIRONMENT
        ln_org_id                              := p_header_rec (1).org_id;
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_app_id);
        mo_global.set_policy_context ('S', ln_org_id);
        mo_global.init ('ONT');
        -- INITIALIZE HEADER RECORD
        l_header_rec                           := oe_order_pub.g_miss_header_rec;
        lc_demand_class_code                   := NULL;
        lc_demand_class                        := NULL;

        SELECT COUNT (*)
          INTO ln_salesrep_cnt
          FROM (SELECT DISTINCT sales_rep_id
                  FROM TABLE (p_line_tbl));

        DBMS_OUTPUT.put_line (' ln_salesrep_cnt - ' || ln_salesrep_cnt);

        IF ln_salesrep_cnt = 0
        THEN
            ln_salesrep_id   := p_header_rec (1).sales_rep_id;
        ELSIF ln_salesrep_cnt = 1
        THEN
            ln_salesrep_id   := p_line_tbl (1).sales_rep_id;
        ELSIF ln_salesrep_cnt > 1
        THEN
            OPEN lc_get_multisales_rep (ln_org_id);

            FETCH lc_get_multisales_rep INTO ln_salesrep_id;

            CLOSE lc_get_multisales_rep;
        END IF;

        DBMS_OUTPUT.put_line (
            ' p_header_rec(1).sales_rep_id - ' || ln_salesrep_id);
        DBMS_OUTPUT.put_line (' ln_salesrep_cnt - ' || ln_salesrep_cnt);
        -- POPULATE REQUIRED ATTRIBUTES
        l_header_rec.operation                 := oe_globals.g_opr_create;
        l_header_rec.transactional_curr_code   := p_header_rec (1).currency;
        l_header_rec.sold_to_org_id            :=
            p_header_rec (1).customer_id;
        l_header_rec.price_list_id             :=
            p_header_rec (1).price_list_id;
        l_header_rec.sold_from_org_id          := p_header_rec (1).org_id;
        l_header_rec.ship_from_org_id          :=
            p_header_rec (1).warehouse_id;
        l_header_rec.ship_to_org_id            :=
            p_header_rec (1).ship_to_address_id;
        l_header_rec.order_type_id             :=
            p_header_rec (1).order_type_id;
        l_header_rec.cust_po_number            :=
            p_header_rec (1).customer_po_number;
        l_header_rec.order_source_id           :=
            p_header_rec (1).order_source_id;
        l_header_rec.invoice_to_org_id         :=
            p_header_rec (1).bill_to_address_id;
        l_header_rec.flow_status_code          := 'ENTERED';
        l_header_rec.shipping_instructions     :=
            p_header_rec (1).shipping_instructions;
        l_header_rec.packing_instructions      :=
            p_header_rec (1).packing_instructions;
        --l_header_rec.salesrep_id             := p_header_rec(1).sales_rep_id;
        l_header_rec.salesrep_id               := ln_salesrep_id;
        l_header_rec.shipping_method_code      :=
            p_header_rec (1).shipping_method_code;
        --l_header_rec.shipping_method         := p_header_rec(1).shipping_method;
        l_header_rec.freight_terms_code        :=
            p_header_rec (1).freight_terms;
        l_header_rec.payment_term_id           :=
            p_header_rec (1).payment_terms_id;
        l_header_rec.deliver_to_org_id         :=
            p_header_rec (1).deliver_to_address_id;
        l_header_rec.return_reason_code        :=
            p_header_rec (1).return_reason;
        -- REQUIRED HEADER DFF INFORMATIONS
        l_header_rec.attribute5                := p_header_rec (1).brand;
        l_header_rec.attribute1                :=
            TO_CHAR (p_header_rec (1).cancel_date, 'YYYY/MM/DD HH:MI:SS');
        l_header_rec.attribute17               :=
            p_header_rec (1).inv_item_type;
        l_header_rec.attribute6                := p_header_rec (1).comments;
        l_header_rec.request_date              :=
            p_header_rec (1).requested_date;
        l_header_rec.demand_class_code         :=
            p_header_rec (1).demand_class_code;
        l_header_rec.attribute14               := p_header_rec (1).attribute3;
        l_header_rec.sold_to_contact_id        :=
            p_header_rec (1).customer_contact_id;
        -- INITIALIZE ACTION REQUEST RECORD
        l_action_request_tbl (1)               :=
            oe_order_pub.g_miss_request_rec;
        --FETCH LINE COUNT
        ln_line_count                          := p_line_tbl.COUNT;

        --POPULATE LINE ATTRIBUTE
        FOR i IN 1 .. ln_line_count
        LOOP
            -- INITIALIZE LINE RECORD
            l_line_tbl (i)                        := oe_order_pub.g_miss_line_rec;
            --POPULATE LINE ATTRIBUTE
            l_line_tbl (i).operation              := oe_globals.g_opr_create;
            l_line_tbl (i).line_type_id           := p_line_tbl (i).line_type_id;
            l_line_tbl (i).inventory_item_id      :=
                p_line_tbl (i).inventory_item_id;
            l_line_tbl (i).ordered_quantity       := p_line_tbl (i).quantity;
            l_line_tbl (i).ship_from_org_id       := p_line_tbl (i).warehouse_id;
            l_line_tbl (i).return_reason_code     :=
                p_line_tbl (i).return_reason;
            l_line_tbl (i).return_context         :=
                p_line_tbl (i).return_context;
            l_line_tbl (i).return_attribute1      :=
                p_line_tbl (i).return_attribute1;
            l_line_tbl (i).return_attribute2      :=
                p_line_tbl (i).return_attribute2;
            l_line_tbl (i).calculate_price_flag   := 'Y';
            l_line_tbl (i).demand_class_code      :=
                p_line_tbl (i).demand_class_code;
            l_line_tbl (i).unit_list_price        :=
                p_line_tbl (i).unit_list_price;
            l_line_tbl (i).invoice_to_org_id      :=
                p_line_tbl (i).bill_to_address_id;
            l_line_tbl (i).ship_to_org_id         :=
                p_line_tbl (i).ship_to_address_id;
            l_line_tbl (i).salesrep_id            :=
                p_line_tbl (i).sales_rep_id;
            l_line_tbl (i).price_list_id          :=
                p_line_tbl (i).price_list_id;
            l_line_tbl (i).payment_term_id        :=
                p_line_tbl (i).payment_terms_id;
            l_line_tbl (i).shipping_method_code   :=
                p_line_tbl (i).shipping_method_code;
            -- l_line_tbl(i).shipping_method       := p_line_tbl(i).shipping_method;
            l_line_tbl (i).freight_terms_code     :=
                p_line_tbl (i).freight_terms;
            l_line_tbl (i).attribute1             :=
                TO_CHAR (p_line_tbl (i).cancel_date, 'YYYY/MM/DD HH:MI:SS');
            -- l_line_tbl(i).request_date          := p_line_tbl(i).requested_date; Changed By Sryeruv (Temp)
            l_line_tbl (i).request_date           :=
                p_line_tbl (i).requested_date;
            l_line_tbl (i).shipping_instructions   :=
                p_line_tbl (i).attribute1;
            l_line_tbl (i).packing_instructions   :=
                p_line_tbl (i).attribute2;
            l_line_tbl (i).attribute14            :=
                p_line_tbl (i).attribute3;
            l_line_tbl (i).deliver_to_org_id      :=
                TO_NUMBER (p_line_tbl (i).attribute4);
            l_line_tbl (i).cust_po_number         :=
                p_line_tbl (i).attribute5;
            l_line_tbl (i).latest_acceptable_Date   :=
                p_line_tbl (i).cancel_date;               ---1.3 version added


            -- REQUIRED LINE DFF INFORMATIONS
            -- l_line_tbl(i).attribute2 ;
            IF p_call_from = 'CREATE_ORDER'
            THEN
                /*IF p_action = 'SAVE' OR   p_action = 'BOOK'   THEN

                  check_atp_qty(p_line_tbl(i).inventory_item_id
                               ,p_line_tbl(i).requested_date
                               , p_line_tbl(i).WAREHOUSE_ID
                               ,p_line_tbl(i).demand_class_code
                               ,p_line_tbl(i).quantity
                               ,NULL
                               ,p_line_tbl(i).UOM
                               ,lc_atp_error_msg
                               ,lc_atp_error_flag
                                );
                   x_atp_error_message := x_atp_error_message|| '. '||lc_atp_error_msg;

                END IF;
                IF  NVL(lc_atp_error_flag,'S') = 'E' THEN
                    x_atp_error_flag := lc_atp_error_flag;
                END IF;
                */
                x_atp_error_flag   := 'S';
            END IF;
        END LOOP;

        IF NVL (x_atp_error_flag, 'S') != 'E'
        THEN
            oe_msg_pub.initialize;
            --call standard api
            oe_order_pub.process_order (
                p_org_id                   => ln_org_id,
                p_operating_unit           => NULL,
                p_api_version_number       => ln_api_version_number,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                -- OUT variables
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
            DBMS_OUTPUT.put_line ('lc_return_status - ' || lc_return_status);

            IF lc_return_status = fnd_api.g_ret_sts_success
            THEN
                IF p_call_from = 'CREATE_ORDER'
                THEN
                    lc_error_message   :=
                           'Sales Order '
                        || l_header_rec_out.order_number
                        || ' Successfully Created . ';
                    DBMS_OUTPUT.put_line (lc_error_message);
                ELSE
                    lc_error_message   :=
                           'Return Order '
                        || l_header_rec_out.order_number
                        || ' Successfully Created . ';
                    DBMS_OUTPUT.put_line (lc_error_message);
                END IF;

                COMMIT;

                OPEN lc_get_nosales_rep;

                FETCH lc_get_nosales_rep INTO ln_nosalesep_id;

                CLOSE lc_get_nosales_rep;

                IF p_call_from = 'CREATE_ORDER'
                THEN
                    IF ln_nosalesep_id = ln_salesrep_id
                    THEN
                        lr_header_rec   := xxd_btom_oeheader_tbltype ();
                        lr_header_rec.EXTEND (1);
                        lr_header_rec (1)   :=
                            xxd_btom_oe_header_type (NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL,
                                                     NULL, NULL, NULL);
                        lr_header_rec (1).hold_name   :=
                            'Salesrep Assignment Hold';
                        lr_header_rec (1).header_id   :=
                            l_header_rec_out.header_id;
                        lr_header_rec (1).hold_comments   :=
                            'No Sales Rep Define For The Sales Order. ';
                        lr_line_tbl     :=
                            xxd_btom_oeline_tbltype ();
                        apply_hold_header_line (lr_header_rec,
                                                lr_line_tbl,
                                                ln_org_id,
                                                'HEADER',
                                                p_user_id,
                                                p_resp_id,
                                                p_resp_app_id,
                                                x_error_flag,
                                                x_error_message);
                    END IF;
                END IF;

                x_header_id        := TO_CHAR (l_header_rec_out.header_id);
                lc_error_message   :=
                    NVL (lc_error_message, '') || x_error_message;

                --x_error_message := NVL (lc_error_message, '') || x_error_message;  -- Apurv commented this line

                IF p_action = 'BOOK'
                THEN
                    SELECT COUNT (1)
                      INTO ln_hold_count
                      FROM oe_order_holds_all oha
                     WHERE     oha.header_id = l_header_rec_out.header_id
                           AND oha.released_flag = 'N';

                    IF (ln_hold_count > 0)
                    THEN
                          SELECT COUNT (1)
                            INTO ln_cr_hold_count
                            FROM oe_order_headers_all oha, oe_order_lines_all ola, oe_order_holds_all ooha,
                                 oe_hold_sources_all ohsa, oe_hold_definitions ohd
                           WHERE     1 = 1
                                 AND oha.header_id = l_header_rec_out.header_id
                                 AND oha.header_id = ooha.header_id
                                 AND ola.line_id(+) = ooha.line_id
                                 AND ooha.hold_source_id = ohsa.hold_source_id
                                 AND ohsa.hold_id = ohd.hold_id
                                 AND ooha.released_flag = 'N'
                                 AND OHD.NAME =
                                     FND_PROFILE.VALUE (
                                         'XXD_CREDIT_CHECK_HOLD_MESSAGE') ---'Credit Check Failure'
                                 AND OHSA.ORG_ID = OOHA.ORG_ID
                        ORDER BY 1;

                        IF ln_cr_hold_count > 0
                        THEN
                            SELECT ohsa.hold_comment
                              INTO ln_cr_hold_comment
                              FROM oe_order_headers_all oha, oe_order_lines_all ola, oe_order_holds_all ooha,
                                   oe_hold_sources_all ohsa, oe_hold_definitions ohd
                             WHERE     1 = 1
                                   AND oha.header_id =
                                       l_header_rec_out.header_id
                                   AND oha.header_id = ooha.header_id
                                   AND ola.line_id(+) = ooha.line_id
                                   AND ooha.hold_source_id =
                                       ohsa.hold_source_id
                                   AND ohsa.hold_id = ohd.hold_id
                                   AND ooha.released_flag = 'N'
                                   AND OHD.NAME =
                                       FND_PROFILE.VALUE (
                                           'XXD_CREDIT_CHECK_HOLD_MESSAGE') ---'Credit Check Failure'
                                   AND OHSA.ORG_ID = OOHA.ORG_ID;

                            IF p_call_from = 'CREATE_ORDER'
                            THEN
                                lc_error_message   :=
                                       'Sales Order '
                                    || l_header_rec_out.order_number
                                    || ' successfully saved but a Credit Check Failure hold prevents booking of this order.Hold reason is "'
                                    || ln_cr_hold_comment
                                    || '".Please release the hold and try to book again.';
                                DBMS_OUTPUT.put_line (lc_error_message);
                            ELSE
                                lc_error_message   :=
                                       'Return Order '
                                    || l_header_rec_out.order_number
                                    || ' successfully saved but a Credit Check Failure hold prevents booking of this order.Hold reason is "'
                                    || ln_cr_hold_comment
                                    || '".Please release the hold and try to book again.';
                                DBMS_OUTPUT.put_line (lc_error_message);
                            END IF;
                        ELSE
                            IF p_call_from = 'CREATE_ORDER'
                            THEN
                                lc_error_message   :=
                                       'Sales Order '
                                    || l_header_rec_out.order_number
                                    || ' successfully saved but a hold prevents booking of this order.Please release the hold and try to book again ';
                                DBMS_OUTPUT.put_line (lc_error_message);
                            ELSE
                                lc_error_message   :=
                                       'Return Order '
                                    || l_header_rec_out.order_number
                                    || ' successfully saved but a hold prevents booking of this order.Please release the hold and try to book again ';
                                DBMS_OUTPUT.put_line (lc_error_message);
                            END IF;
                        END IF;
                    ELSE
                        book_order (l_header_rec_out.header_id, ln_org_id, p_user_id, p_resp_id, p_resp_app_id, p_call_from
                                    , x_error_flag, -- x_error_message
                                                    lc_error_message);
                    END IF;
                END IF;

                x_error_message    := lc_error_message;
            ELSE
                DBMS_OUTPUT.put_line ('Failed to Create Sales Order');
                x_error_flag      := 'E';

                FOR i IN 1 .. ln_msg_count
                LOOP
                    lc_error_message   :=
                        SUBSTR (
                            lc_error_message || oe_msg_pub.get (p_msg_index => i, p_encoded => 'F'),
                            1,
                            3900);
                END LOOP;

                DBMS_OUTPUT.put_line (lc_error_message);
                x_error_message   := lc_error_message;
                ROLLBACK;
            END IF;
        END IF;                     --IF NVL(x_atp_error_flag,'S') != 'E' THEN
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line ('Exception in create order:' || SQLERRM);
    END create_order;

    --This procedure is used to book the sales order
    PROCEDURE book_order (p_header_id       IN     NUMBER,
                          p_org_id          IN     NUMBER,
                          p_user_id         IN     NUMBER,
                          p_resp_id         IN     NUMBER,
                          p_resp_app_id     IN     NUMBER,
                          p_call_from       IN     VARCHAR2,
                          x_error_flag         OUT VARCHAR2,
                          x_error_message      OUT VARCHAR2)
    IS
        ln_api_version_number          NUMBER := 1;
        lc_return_status               VARCHAR2 (10);
        ln_msg_count                   NUMBER;
        lc_msg_data                    VARCHAR2 (2000);
        lc_error_message               VARCHAR2 (2000);
        ln_order_number                NUMBER;
        ln_cr_hold_count               NUMBER;
        ln_cr_hold_comment             VARCHAR2 (600);
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
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_app_id);
        mo_global.set_policy_context ('S', p_org_id);
        mo_global.init ('ONT');

        --fetch order number
        BEGIN
            SELECT order_number
              INTO ln_order_number
              FROM oe_order_headers_all
             WHERE header_id = p_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.put_line (
                    'Unexpected Exception while fetching order number.');
        END;

        l_action_request_tbl (1)                := oe_order_pub.g_miss_request_rec;
        l_action_request_tbl (1).entity_id      := p_header_id;
        l_action_request_tbl (1).entity_code    := oe_globals.g_entity_header;
        l_action_request_tbl (1).request_type   := oe_globals.g_book_order;
        oe_msg_pub.initialize;
        --call standard api
        oe_order_pub.process_order (
            p_org_id                   => p_org_id,
            p_operating_unit           => NULL,
            p_api_version_number       => ln_api_version_number,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            -- OUT variables
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
        -- IF lc_return_status = fnd_api.g_ret_sts_success
        IF l_action_request_tbl_out (1).return_status =
           fnd_api.g_ret_sts_success -- Modified by Infosys for DOE issues. 31-May-2016.
        THEN
            COMMIT;

              SELECT COUNT (1)
                INTO ln_cr_hold_count
                FROM oe_order_headers_all oha, oe_order_lines_all ola, oe_order_holds_all ooha,
                     oe_hold_sources_all ohsa, oe_hold_definitions ohd
               WHERE     1 = 1
                     AND oha.header_id = p_header_id
                     AND oha.header_id = ooha.header_id
                     AND ola.line_id(+) = ooha.line_id
                     AND ooha.hold_source_id = ohsa.hold_source_id
                     AND ohsa.hold_id = ohd.hold_id
                     AND ooha.released_flag = 'N'
                     AND OHD.NAME =
                         FND_PROFILE.VALUE ('XXD_CREDIT_CHECK_HOLD_MESSAGE') --'Credit Check Failure'
                     AND OHSA.ORG_ID = OOHA.ORG_ID
            ORDER BY 1;

            IF ln_cr_hold_count > 0
            THEN
                SELECT ohsa.hold_comment
                  INTO ln_cr_hold_comment
                  FROM oe_order_headers_all oha, oe_order_lines_all ola, oe_order_holds_all ooha,
                       oe_hold_sources_all ohsa, oe_hold_definitions ohd
                 WHERE     1 = 1
                       AND oha.header_id = p_header_id
                       AND oha.header_id = ooha.header_id
                       AND ola.line_id(+) = ooha.line_id
                       AND ooha.hold_source_id = ohsa.hold_source_id
                       AND ohsa.hold_id = ohd.hold_id
                       AND ooha.released_flag = 'N'
                       AND OHD.NAME =
                           FND_PROFILE.VALUE (
                               'XXD_CREDIT_CHECK_HOLD_MESSAGE') ---'Credit Check Failure'
                       AND OHSA.ORG_ID = OOHA.ORG_ID;

                IF p_call_from = 'CREATE_ORDER'
                THEN
                    lc_error_message   :=
                           'Sales Order '
                        || ln_order_number
                        || ' successfully booked but a Credit Check Failure hold is applied.Hold reason is "'
                        || ln_cr_hold_comment
                        || '"';
                    DBMS_OUTPUT.put_line (lc_error_message);
                ELSE
                    lc_error_message   :=
                           'Return Order '
                        || ln_order_number  --|| l_header_rec_out.order_number
                        || ' successfully booked but a Credit Check Failure hold is applied.Hold reason is "'
                        || ln_cr_hold_comment
                        || '"';
                    DBMS_OUTPUT.put_line (lc_error_message);
                END IF;
            ELSE
                IF p_call_from = 'CREATE_ORDER'
                THEN
                    lc_error_message   :=
                           'Sales Order '
                        || ln_order_number
                        || ' successfully booked.';
                    DBMS_OUTPUT.put_line (lc_error_message);
                ELSE
                    lc_error_message   :=
                           'Return Order '
                        || ln_order_number  --|| l_header_rec_out.order_number
                        || ' successfully booked.';
                    DBMS_OUTPUT.put_line (lc_error_message);
                END IF;
            END IF;

            x_error_flag      := 'S';
            --x_error_message :=
            --         'Sales Order ' || ln_order_number || ' Successfully Booked';
            x_error_message   := lc_error_message;
        ELSE
            DBMS_OUTPUT.put_line ('Failed to Book Sales Order');
            x_error_flag       := 'E';
            --     lc_error_message := 'Exception While Booking the Order - ';
            lc_error_message   :=
                'Exception While Booking the Order - ' || CHR (13); -- Modified by Infosys for DOE issues. 31-May-2016.

            FOR i IN 1 .. ln_msg_count
            LOOP
                --   lc_error_message := SUBSTR(lc_error_message|| oe_msg_pub.get (p_msg_index => i, p_encoded => 'F'),1,1900);
                lc_error_message   :=
                    SUBSTR (
                        lc_error_message || CHR (13) || oe_msg_pub.get (p_msg_index => i, p_encoded => 'F'),
                        1,
                        1900); -- Modified by Infosys for DOE issues. 31-May-2016.
            END LOOP;

            DBMS_OUTPUT.put_line (lc_error_message);
            x_error_message    := lc_error_message;
            ROLLBACK;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line ('Exception in book order:' || SQLERRM);
    END book_order;

    --This procedure is used to modify sales order
    PROCEDURE modify_order (p_header_rec          IN     xxd_btom_oeheader_tbltype,
                            p_line_tbl            IN     xxd_btom_oeline_tbltype,
                            p_user_id             IN     NUMBER,
                            p_resp_id             IN     NUMBER,
                            p_resp_app_id         IN     NUMBER,
                            p_action              IN     VARCHAR2,
                            p_call_from           IN     VARCHAR2,
                            x_error_flag             OUT VARCHAR2,
                            x_error_message          OUT VARCHAR2,
                            x_atp_error_message      OUT VARCHAR2,
                            x_atp_error_flag         OUT VARCHAR2)
    IS
        ln_api_version_number          NUMBER := 1;
        lc_return_status               VARCHAR2 (10);
        ln_msg_count                   NUMBER;
        lc_msg_data                    VARCHAR2 (2000);
        ln_org_id                      NUMBER;
        ln_line_count                  NUMBER;
        lc_error_message               VARCHAR2 (2000);
        lc_atp_error_msg               VARCHAR2 (4000) := NULL;
        lc_atp_error_flag              VARCHAR2 (10);
        ln_salesrep_cnt                NUMBER;
        ln_salesrep_id                 NUMBER;
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
        ln_order_type_id               NUMBER;
        ln_line_type_id                NUMBER;
        ex_exception                   EXCEPTION;
        lc_hold_type                   VARCHAR2 (60);
        ln_hold_count                  NUMBER;
        lc_activity_name               VARCHAR2 (100);
        lc_activity_intance            VARCHAR2 (100);

        CURSOR lcu_get_demand_class_code (p_demand_class VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values
             WHERE     lookup_type = 'DEMAND_CLASS'
                   AND LANGUAGE = USERENV ('LANG')
                   AND meaning = p_demand_class;

        CURSOR lc_get_demand (p_cust_account_id NUMBER)
        IS
            SELECT attribute13
              FROM hz_cust_accounts
             WHERE cust_account_id = p_cust_account_id;

        CURSOR lc_get_multisales_rep (p_org_id NUMBER)
        IS
            SELECT salesrep_id
              FROM ra_salesreps
             WHERE     status = 'A'
                   AND org_id = p_org_id
                   AND SYSDATE BETWEEN start_date_active
                                   AND NVL (end_date_active, SYSDATE)
                   AND NAME IN
                           (SELECT DISTINCT attribute3
                              FROM fnd_lookup_values
                             WHERE     lookup_type = 'XXDO_SALESREP_DEFAULTS'
                                   AND LANGUAGE = USERENV ('LANG'));

        CURSOR lc_get_header_hold_itemtype (p_header_id NUMBER)
        IS
            SELECT DECODE (activity_name, 'BOOK_ORDER', 'BOOK', 'XXX')
              FROM oe_hold_definitions ohd
             WHERE     hold_id IN
                           (SELECT DISTINCT hold_id
                              FROM oe_order_headers_all ooh, oe_order_holds_all oha, oe_hold_sources_all ohsa
                             WHERE     ooh.header_id = p_header_id
                                   AND ooh.header_id = oha.header_id
                                   AND oha.line_id IS NULL
                                   AND oha.released_flag = 'N'
                                   AND oha.hold_source_id =
                                       ohsa.hold_source_id)
                   AND item_type = 'OEOH';

        CURSOR lc_get_schedule_lines (p_header_id NUMBER)
        IS
            SELECT ool.line_id
              FROM oe_order_lines_all ool
             WHERE     ool.header_id = p_header_id
                   AND ool.schedule_ship_date IS NOT NULL
                   AND ool.flow_status_code = 'BOOKED'
                   AND ool.schedule_status_code = 'SCHEDULED';

        CURSOR lc_get_qty_update_code IS
            SELECT lookup_code, meaning
              FROM fnd_lookup_values_vl
             WHERE     lookup_type LIKE 'CANCEL_CODE'
                   AND lookup_code IN
                           (SELECT fnd_profile.VALUE ('DO_DOE_UPDATE_QTY') FROM DUAL);

        lc_demand_class_code           VARCHAR2 (60);
        lc_demand_class                VARCHAR2 (60);
        lc_flow_status_code            VARCHAR2 (60);
        ln_index                       NUMBER := 0;
        lc_flow_status_line            VARCHAR2 (60) := NULL;
        lc_cal_price_flag              VARCHAR2 (10) := NULL;
        ln_order_qty                   NUMBER := 0;
        lc_qty_update_code             VARCHAR2 (60) := NULL;
        lc_qty_update_meaning          VARCHAR2 (250) := NULL;
        ln_cr_hold_count               NUMBER;
        ln_cr_hold_comment             VARCHAR2 (600);
    BEGIN
        -- INITIALIZE ENVIRONMENT
        ln_org_id              := p_header_rec (1).org_id;
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_app_id);
        mo_global.set_policy_context ('S', ln_org_id);
        mo_global.init ('ONT');
        -- INITIALIZE HEADER RECORD
        l_header_rec           := oe_order_pub.g_miss_header_rec;
        -- POPULATE REQUIRED ATTRIBUTES
        lc_demand_class_code   := NULL;
        lc_demand_class        := NULL;
        lc_flow_status_code    := NULL;
        lc_hold_type           := NULL;

        SELECT flow_status_code
          INTO lc_flow_status_code
          FROM oe_order_headers_all
         WHERE header_id = p_header_rec (1).header_id;

        OPEN lc_get_header_hold_itemtype (p_header_rec (1).header_id);

        FETCH lc_get_header_hold_itemtype INTO lc_hold_type;

        CLOSE lc_get_header_hold_itemtype;

        IF p_action = lc_hold_type
        THEN
            RAISE ex_exception;
        ELSE
            /* SELECT COUNT (*)
               INTO ln_salesrep_cnt
               FROM (SELECT DISTINCT sales_rep_id
                                FROM TABLE (p_line_tbl));
            */
            IF p_line_tbl.COUNT = 0
            THEN
                ln_salesrep_id   := p_header_rec (1).sales_rep_id;
            ELSE
                SELECT COUNT (*)
                  INTO ln_salesrep_cnt
                  FROM (SELECT DISTINCT sales_rep_id
                          FROM TABLE (p_line_tbl)
                        UNION
                        SELECT DISTINCT salesrep_id
                          FROM oe_order_lines OLL
                         WHERE     header_id = p_header_rec (1).header_id
                               AND NOT EXISTS
                                       (SELECT 1
                                          FROM TABLE (p_line_tbl) TBL
                                         WHERE     TBL.line_id = OLL.line_id
                                               AND TBL.line_id IS NOT NULL));

                DBMS_OUTPUT.put_line (
                    ' ln_salesrep_cnt - ' || ln_salesrep_cnt);

                IF ln_salesrep_cnt = 0
                THEN
                    ln_salesrep_id   := p_header_rec (1).sales_rep_id;
                ELSIF ln_salesrep_cnt = 1
                THEN
                    ln_salesrep_id   := p_line_tbl (1).sales_rep_id;
                ELSIF ln_salesrep_cnt > 1
                THEN
                    OPEN lc_get_multisales_rep (ln_org_id);

                    FETCH lc_get_multisales_rep INTO ln_salesrep_id;

                    CLOSE lc_get_multisales_rep;
                END IF;
            END IF;

            IF p_header_rec (1).order_type_id IS NULL
            THEN
                SELECT order_type_id
                  INTO ln_order_type_id
                  FROM oe_order_headers_all
                 WHERE header_id = p_header_rec (1).header_id;
            ELSE
                ln_order_type_id   := p_header_rec (1).order_type_id;
            END IF;

            DBMS_OUTPUT.put_line (
                ' p_header_rec(1).sales_rep_id - ' || ln_salesrep_id);
            l_header_rec.operation                 := oe_globals.g_opr_update;
            l_header_rec.header_id                 := p_header_rec (1).header_id;
            l_header_rec.transactional_curr_code   :=
                p_header_rec (1).currency;
            l_header_rec.sold_to_org_id            :=
                p_header_rec (1).customer_id;
            l_header_rec.price_list_id             :=
                p_header_rec (1).price_list_id;
            l_header_rec.sold_from_org_id          := p_header_rec (1).org_id;
            l_header_rec.ship_from_org_id          :=
                p_header_rec (1).warehouse_id;
            l_header_rec.ship_to_org_id            :=
                p_header_rec (1).ship_to_address_id;
            -- l_header_rec.order_type_id           := p_header_rec(1).order_type_id;
            l_header_rec.order_type_id             := ln_order_type_id;
            l_header_rec.cust_po_number            :=
                p_header_rec (1).customer_po_number;
            l_header_rec.order_source_id           :=
                p_header_rec (1).order_source_id;
            l_header_rec.invoice_to_org_id         :=
                p_header_rec (1).bill_to_address_id;
            l_header_rec.flow_status_code          := lc_flow_status_code;
            l_header_rec.shipping_instructions     :=
                p_header_rec (1).shipping_instructions;
            l_header_rec.packing_instructions      :=
                p_header_rec (1).packing_instructions;
            --l_header_rec.salesrep_id             := p_header_rec(1).sales_rep_id;
            l_header_rec.salesrep_id               := ln_salesrep_id;
            l_header_rec.shipping_method_code      :=
                p_header_rec (1).shipping_method_code;
            --l_header_rec.shipping_method         := p_header_rec(1).shipping_method;
            l_header_rec.freight_terms_code        :=
                p_header_rec (1).freight_terms;
            l_header_rec.payment_term_id           :=
                p_header_rec (1).payment_terms_id;
            l_header_rec.change_reason             := p_header_rec (1).reason;
            l_header_rec.return_reason_code        :=
                p_header_rec (1).return_reason;
            -- REQUIRED HEADER DFF INFORMATIONS
            l_header_rec.attribute5                := p_header_rec (1).brand;
            l_header_rec.attribute1                :=
                TO_CHAR (p_header_rec (1).cancel_date, 'YYYY/MM/DD HH:MI:SS');

            l_header_rec.attribute17               :=
                p_header_rec (1).inv_item_type;
            l_header_rec.attribute6                :=
                p_header_rec (1).comments;
            l_header_rec.demand_class_code         :=
                p_header_rec (1).demand_class_code;
            l_header_rec.request_date              :=
                p_header_rec (1).requested_date;
            l_header_rec.attribute14               :=
                p_header_rec (1).attribute3;
            l_header_rec.sold_to_contact_id        :=
                p_header_rec (1).customer_contact_id;
            l_header_rec.deliver_to_org_id         :=
                p_header_rec (1).deliver_to_address_id;
            -- INITIALIZE ACTION REQUEST RECORD
            l_action_request_tbl (1)               :=
                oe_order_pub.g_miss_request_rec;
            --FETCH LINE COUNT
            ln_line_count                          := p_line_tbl.COUNT;

            --POPULATE LINE ATTRIBUTE
            FOR i IN 1 .. ln_line_count
            LOOP
                lc_flow_status_line   := NULL;
                ln_order_qty          := 0;
                lc_cal_price_flag     := NULL;

                IF p_line_tbl (i).line_id IS NOT NULL
                THEN
                    SELECT flow_status_code, ordered_quantity, calculate_price_flag
                      INTO lc_flow_status_line, ln_order_qty, lc_cal_price_flag
                      FROM oe_order_lines_all
                     WHERE line_id = p_line_tbl (i).line_id;
                END IF;

                IF NVL (lc_flow_status_line, 'XX') NOT IN
                       ('CANCELLED', 'CLOSED', 'SHIPPED')
                THEN
                    ln_index                := ln_index + 1;
                    -- INITIALIZE LINE RECORD
                    l_line_tbl (ln_index)   := oe_order_pub.g_miss_line_rec;

                    --POPULATE LINE ATTRIBUTE
                    --IF p_line_tbl (ln_index).line_id IS NULL  -- Commented for Inc INC0296155
                    IF p_line_tbl (i).line_id IS NULL -- Added for Inc INC0296155
                    THEN
                        l_line_tbl (ln_index).operation   :=
                            oe_globals.g_opr_create;
                    -- l_line_tbl(i).line_id   := p_line_tbl(i).line_id;
                    ELSE
                        l_line_tbl (ln_index).operation   :=
                            oe_globals.g_opr_update;
                        l_line_tbl (ln_index).line_id   :=
                            p_line_tbl (i).line_id;
                    END IF;

                    --l_line_tbl(i).operation := OE_GLOBALS.G_OPR_UPDATE;

                    l_line_tbl (ln_index).header_id   :=
                        p_line_tbl (i).header_id;
                    -- l_line_tbl(i).line_id := p_line_tbl(i).line_id;
                    l_line_tbl (ln_index).line_type_id   :=
                        p_line_tbl (i).line_type_id;
                    l_line_tbl (ln_index).inventory_item_id   :=
                        p_line_tbl (i).inventory_item_id;
                    l_line_tbl (ln_index).ordered_quantity   :=
                        p_line_tbl (i).quantity;
                    l_line_tbl (ln_index).ship_from_org_id   :=
                        p_line_tbl (i).warehouse_id;
                    l_line_tbl (ln_index).return_reason_code   :=
                        p_line_tbl (i).return_reason;
                    l_line_tbl (ln_index).return_context   :=
                        p_line_tbl (i).return_context;
                    l_line_tbl (ln_index).return_attribute1   :=
                        p_line_tbl (i).return_attribute1;
                    l_line_tbl (ln_index).return_attribute2   :=
                        p_line_tbl (i).return_attribute2;
                    --l_line_tbl (ln_index).calculate_price_flag := 'Y';
                    l_line_tbl (ln_index).calculate_price_flag   :=
                        lc_cal_price_flag;
                    l_line_tbl (ln_index).demand_class_code   :=
                        p_line_tbl (i).demand_class_code;
                    l_line_tbl (ln_index).unit_list_price   :=
                        p_line_tbl (i).unit_list_price;
                    l_line_tbl (ln_index).invoice_to_org_id   :=
                        p_line_tbl (i).bill_to_address_id;
                    l_line_tbl (ln_index).ship_to_org_id   :=
                        p_line_tbl (i).ship_to_address_id;
                    l_line_tbl (ln_index).salesrep_id   :=
                        p_line_tbl (i).sales_rep_id;
                    l_line_tbl (ln_index).price_list_id   :=
                        p_line_tbl (i).price_list_id;
                    l_line_tbl (ln_index).payment_term_id   :=
                        p_line_tbl (i).payment_terms_id;
                    l_line_tbl (ln_index).shipping_method_code   :=
                        p_line_tbl (i).shipping_method_code;
                    --l_line_tbl(i).shipping_method       := p_line_tbl(i).shipping_method;
                    l_line_tbl (ln_index).freight_terms_code   :=
                        p_line_tbl (i).freight_terms;

                    IF ln_order_qty > p_line_tbl (i).quantity
                    THEN
                        OPEN lc_get_qty_update_code;

                        FETCH lc_get_qty_update_code INTO lc_qty_update_code, lc_qty_update_meaning;

                        CLOSE lc_get_qty_update_code;

                        l_line_tbl (ln_index).change_reason   :=
                            lc_qty_update_code;
                        l_line_tbl (ln_index).change_comments   :=
                            lc_qty_update_meaning;
                    ELSE
                        l_line_tbl (ln_index).change_reason   :=
                            p_line_tbl (i).reason;
                    END IF;

                    l_line_tbl (ln_index).attribute1   :=
                        TO_CHAR (p_line_tbl (i).cancel_date,
                                 'YYYY/MM/DD HH:MI:SS');
                    l_line_tbl (ln_index).request_date   :=
                        p_line_tbl (i).requested_date;
                    l_line_tbl (ln_index).override_atp_date_code   :=
                        p_line_tbl (i).override_atp_date_code;
                    l_line_tbl (ln_index).schedule_ship_date   :=
                        p_line_tbl (i).scheduled_date;

                    l_line_tbl (ln_index).shipping_instructions   :=
                        p_line_tbl (i).attribute1;
                    l_line_tbl (ln_index).packing_instructions   :=
                        p_line_tbl (i).attribute2;
                    l_line_tbl (ln_index).attribute14   :=
                        p_line_tbl (i).attribute3;
                    l_line_tbl (ln_index).deliver_to_org_id   :=
                        TO_NUMBER (p_line_tbl (i).attribute4);
                    l_line_tbl (ln_index).cust_po_number   :=
                        p_line_tbl (i).attribute5;
                    --l_line_tbl (i).latest_acceptable_Date := p_line_tbl (i).cancel_date;---1.3 version added --commented w.r.t 1.4
                    l_line_tbl (ln_index).latest_acceptable_Date   :=
                        p_line_tbl (i).cancel_date;          --added w.r.t 1.4

                    -- REQUIRED LINE DFF INFORMATIONS
                    -- l_line_tbl(i).attribute2 ;
                    IF p_call_from = 'CREATE_ORDER'
                    THEN
                        /*IF p_action = 'SAVE' OR   p_action = 'BOOK'   THEN
                          check_atp_qty(p_line_tbl(i).inventory_item_id
                                   ,p_line_tbl(i).requested_date
                                   , p_line_tbl(i).WAREHOUSE_ID
                                   ,p_line_tbl(i).demand_class_code
                                   ,p_line_tbl(i).quantity
                                   ,p_line_tbl(i).line_id
                                   ,p_line_tbl(i).UOM
                                   ,lc_atp_error_msg
                                   ,lc_atp_error_flag
                                    );

                          x_atp_error_message := lc_atp_error_msg|| '. '||lc_atp_error_msg;
                          END IF;
                          IF  NVL(lc_atp_error_flag,'S') = 'E' THEN
                            x_atp_error_flag := lc_atp_error_flag;
                          END IF;
                         */
                        x_atp_error_flag   := 'S';
                    END IF;
                END IF; --IF NVL(lc_flow_status_line,'XX') != 'CANCELLED' THEN
            END LOOP;

            IF NVL (x_atp_error_flag, 'S') != 'E'
            THEN
                oe_msg_pub.initialize;
                --call standard api
                oe_order_pub.process_order (
                    p_org_id                   => ln_org_id,
                    p_operating_unit           => NULL,
                    p_api_version_number       => ln_api_version_number,
                    p_header_rec               => l_header_rec,
                    p_line_tbl                 => l_line_tbl,
                    p_action_request_tbl       => l_action_request_tbl,
                    -- OUT variables
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
                IF lc_return_status = fnd_api.g_ret_sts_success
                THEN
                    DBMS_OUTPUT.put_line (
                           'Sales Order '
                        || l_header_rec_out.order_number
                        || ' Successfully Modified');
                    x_error_flag      := 'S';

                    IF p_call_from = 'CREATE_ORDER'
                    THEN
                        lc_error_message   :=
                               'Sales order '
                            || l_header_rec_out.order_number
                            || ' successfully modified.';
                    ELSE
                        lc_error_message   :=
                               'Return order '
                            || l_header_rec_out.order_number
                            || ' successfully modified.';
                    END IF;

                    IF p_action = 'BOOK'
                    THEN
                        SELECT COUNT (1)
                          INTO ln_hold_count
                          FROM oe_order_holds_all oha
                         WHERE     oha.header_id = l_header_rec_out.header_id
                               AND oha.released_flag = 'N';

                        IF (ln_hold_count > 0)
                        THEN
                              SELECT COUNT (1)
                                INTO ln_cr_hold_count
                                FROM oe_order_headers_all oha, oe_order_lines_all ola, oe_order_holds_all ooha,
                                     oe_hold_sources_all ohsa, oe_hold_definitions ohd
                               WHERE     1 = 1
                                     AND oha.header_id =
                                         l_header_rec_out.header_id
                                     AND oha.header_id = ooha.header_id
                                     AND ola.line_id(+) = ooha.line_id
                                     AND ooha.hold_source_id =
                                         ohsa.hold_source_id
                                     AND ohsa.hold_id = ohd.hold_id
                                     AND ooha.released_flag = 'N'
                                     AND OHD.NAME =
                                         FND_PROFILE.VALUE (
                                             'XXD_CREDIT_CHECK_HOLD_MESSAGE') --'Credit Check Failure'
                                     AND OHSA.ORG_ID = OOHA.ORG_ID
                            ORDER BY 1;

                            IF ln_cr_hold_count > 0
                            THEN
                                SELECT ohsa.hold_comment
                                  INTO ln_cr_hold_comment
                                  FROM oe_order_headers_all oha, oe_order_lines_all ola, oe_order_holds_all ooha,
                                       oe_hold_sources_all ohsa, oe_hold_definitions ohd
                                 WHERE     1 = 1
                                       AND oha.header_id =
                                           l_header_rec_out.header_id
                                       AND oha.header_id = ooha.header_id
                                       AND ola.line_id(+) = ooha.line_id
                                       AND ooha.hold_source_id =
                                           ohsa.hold_source_id
                                       AND ohsa.hold_id = ohd.hold_id
                                       AND ooha.released_flag = 'N'
                                       AND OHD.NAME =
                                           FND_PROFILE.VALUE (
                                               'XXD_CREDIT_CHECK_HOLD_MESSAGE') ---'Credit Check Failure'
                                       AND OHSA.ORG_ID = OOHA.ORG_ID;

                                IF p_call_from = 'CREATE_ORDER'
                                THEN
                                    lc_error_message   :=
                                           'Sales order '
                                        || l_header_rec_out.order_number
                                        || ' successfully modified but a Credit Check Failure hold prevents booking of this order.Hold reason is "'
                                        || ln_cr_hold_comment
                                        || '".Please release the hold and try to book again.';
                                    DBMS_OUTPUT.put_line (lc_error_message);
                                ELSE
                                    lc_error_message   :=
                                           'Return order '
                                        || l_header_rec_out.order_number
                                        || ' successfully modified but a Credit Check Failure hold prevents booking of this order.Hold reason is "'
                                        || ln_cr_hold_comment
                                        || '".Please release the hold and try to book again.';
                                    DBMS_OUTPUT.put_line (lc_error_message);
                                END IF;
                            ELSE
                                IF p_call_from = 'CREATE_ORDER'
                                THEN
                                    lc_error_message   :=
                                           'Sales order '
                                        || l_header_rec_out.order_number
                                        || ' successfully modified but a hold prevents booking of this order.Please release the hold and try to book again ';
                                    DBMS_OUTPUT.put_line (lc_error_message);
                                ELSE
                                    lc_error_message   :=
                                           'Return order '
                                        || l_header_rec_out.order_number
                                        || ' successfully modified but a hold prevents booking of this order.Please release the hold and try to book again ';
                                    DBMS_OUTPUT.put_line (lc_error_message);
                                END IF;
                            END IF;
                        ELSE
                            book_order (l_header_rec_out.header_id, ln_org_id, p_user_id, p_resp_id, p_resp_app_id, p_call_from
                                        , x_error_flag, -- x_error_message
                                                        lc_error_message);
                        END IF;
                    END IF;

                    FOR lc_get_schedule_rec
                        IN lc_get_schedule_lines (l_header_rec_out.header_id)
                    LOOP
                        BEGIN
                            SELECT wpa.activity_name, wpa.instance_label
                              INTO lc_activity_name, lc_activity_intance
                              FROM wf_item_activity_statuses wias, wf_process_activities wpa
                             WHERE     wias.item_type = 'OEOL'
                                   AND wias.activity_status = 'NOTIFIED'
                                   AND wias.process_activity =
                                       wpa.instance_id
                                   AND wias.item_key =
                                       TO_CHAR (lc_get_schedule_rec.line_id);

                            IF (lc_activity_name = 'SCHEDULING_ELIGIBLE')
                            THEN
                                wf_engine.completeactivity ('OEOL', TO_CHAR (lc_get_schedule_rec.line_id), lc_activity_intance
                                                            , NULL);
                            ELSE
                                wf_engine.completeactivity ('OEOL', TO_CHAR (lc_get_schedule_rec.line_id), lc_activity_intance
                                                            , 'COMPLETE');
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;
                    END LOOP;

                    -- x_error_message := NVL (lc_error_message, '')
                    --                   || x_error_message;
                    x_error_message   := NVL (lc_error_message, '');

                    COMMIT;
                ELSE
                    DBMS_OUTPUT.put_line ('Failed to Modify Sales Order');
                    x_error_flag      := 'E';

                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        lc_error_message   :=
                            SUBSTR (
                                lc_error_message || oe_msg_pub.get (p_msg_index => i, p_encoded => 'F'),
                                1,
                                1900);
                    END LOOP;

                    DBMS_OUTPUT.put_line (lc_error_message);
                    x_error_message   := lc_error_message;
                    ROLLBACK;
                END IF;
            END IF;                     -- IF NVL(x_atp_error_flag,'S') != 'E'
        END IF;                  -- IF lc_flow_status_code = lc_hold_type THEN
    EXCEPTION
        WHEN ex_exception
        THEN
            x_error_message   := 'A hold prevents booking of this order.';
            x_error_flag      := 'E';
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line ('Exception in modify order:' || SQLERRM);
            x_error_message   := 'Exception in modify order:' || SQLERRM;
            x_error_flag      := 'E';
    END modify_order;

    PROCEDURE call_api (l_header_rec oe_order_pub.header_rec_type, p_org_id NUMBER, x_error_flag OUT VARCHAR2
                        , x_error_message OUT VARCHAR2)
    IS
        ln_api_version_number          NUMBER := 1;
        lc_return_status               VARCHAR2 (10);
        ln_msg_count                   NUMBER;
        lc_msg_data                    VARCHAR2 (4000);
        lc_error_message               VARCHAR2 (4000);
        ln_line_count                  NUMBER;
        ln_header_count                NUMBER;
        -- INPUT VARIABLES FOR PROCESS_ORDER API
        -- l_header_rec         oe_order_pub.header_rec_type :=OE_ORDER_PUB.G_MISS_HEADER_REC;
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
        DBMS_OUTPUT.put_line ('Inside  - Call_API ');
        oe_msg_pub.initialize;
        -- CALL TO PROCESS Order
        oe_order_pub.process_order (
            p_org_id                   => p_org_id,
            p_operating_unit           => NULL,
            p_api_version_number       => ln_api_version_number,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            -- OUT variables
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
        DBMS_OUTPUT.put_line (
               'lc_return_status  - '
            || lc_return_status
            || ' - '
            || l_header_rec_out.order_number);

        IF lc_return_status = fnd_api.g_ret_sts_success
        THEN
            DBMS_OUTPUT.put_line (
                   'The Sales Order '
                || l_header_rec_out.order_number
                || ' is Successfully cancelled');
            x_error_flag   := 'S';
            lc_error_message   :=
                   'The Sales Order '
                || l_header_rec_out.order_number
                || ' is Successfully cancelled';
            COMMIT;
        ELSE
            DBMS_OUTPUT.put_line ('Failed to cancel the Sales Order.');
            lc_error_message   :=
                ('Failed To Cancel The Sales Order ' || l_header_rec_out.order_number);
            DBMS_OUTPUT.put_line ('lc_error_message - ' || lc_error_message);
            x_error_flag   := 'E';

            FOR i IN 1 .. ln_msg_count
            LOOP
                lc_error_message   :=
                       lc_error_message
                    || oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;

            -- DBMS_OUTPUT.PUT_LINE('lc_error_message - '||lc_error_message);
            ROLLBACK;
        END IF;

        x_error_message   := lc_error_message;
    EXCEPTION
        WHEN OTHERS
        THEN
            --  DBMS_OUTPUT.PUT_LINE('Exception in cancel order line:' );
            x_error_flag      := 'E';
            x_error_message   := SUBSTR (SQLERRM, 1, 1500);
    END call_api;

    --This procedure is used to cancel sales order line
    PROCEDURE cancel_order_header_line (p_header_rec IN xxd_btom_oeheader_tbltype, p_line_tbl IN xxd_btom_oeline_tbltype, p_org_id IN NUMBER, p_call_form IN VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER
                                        , p_resp_app_id IN NUMBER, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        ln_api_version_number          NUMBER := 1;
        lc_return_status               VARCHAR2 (10);
        ln_msg_count                   NUMBER;
        lc_msg_data                    VARCHAR2 (4000);
        lc_error_message               VARCHAR2 (4000);
        ln_line_count                  NUMBER;
        ln_header_count                NUMBER;
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
        xxd_common_utils.record_error (
            'DOE',
            xxd_common_utils.get_org_id,
            'XXD_SALES_ORDER_PKG.CANCEL_ORDER_HEADER_LINE',
               'User ID - '
            || p_user_id
            || ' resp ID - '
            || p_resp_id
            || ' Resp Appl ID - '
            || p_resp_app_id
            || ' Org ID - '
            || p_org_id,
            DBMS_UTILITY.format_error_backtrace,
            fnd_profile.VALUE ('USER_ID'));
        -- INITIALIZE ENVIRONMENT
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_app_id);
        mo_global.set_policy_context ('S', p_org_id);
        mo_global.init ('ONT');
        xxd_common_utils.record_error (
            'DOE',
            xxd_common_utils.get_org_id,
            'XXD_SALES_ORDER_PKG.CANCEL_ORDER_HEADER_LINE',
            'After Apps Initialization p_call_form ' || p_call_form,
            DBMS_UTILITY.format_error_backtrace,
            fnd_profile.VALUE ('USER_ID'));

        IF p_call_form = 'HEADER'
        THEN
            --FETCH Header COUNT
            ln_header_count   := p_header_rec.COUNT;

            -- Initialize the record to missing
            FOR i IN 1 .. ln_header_count
            LOOP
                --l_header_rec := NULL;
                DBMS_OUTPUT.put_line (
                       'p_header_rec(i).header_id - '
                    || p_header_rec (i).header_id);
                l_header_rec                   := oe_order_pub.g_miss_header_rec;
                l_header_rec.header_id         := p_header_rec (i).header_id;
                l_header_rec.cancelled_flag    := 'Y';
                l_header_rec.change_reason     := p_header_rec (i).reason;
                l_header_rec.change_comments   := p_header_rec (i).comments;
                -- l_header_rec.attribute1      := p_header_rec(i).cancel_date;
                l_header_rec.attribute1        := TRUNC (SYSDATE);
                l_header_rec.operation         := oe_globals.g_opr_update;
                -- Initialize record to missing
                --l_line_tbl(1) := OE_ORDER_PUB.G_MISS_LINE_REC;
                /*
                   oe_msg_pub.Initialize;
               -- CALL TO PROCESS Order
               oe_order_pub.process_order(p_org_id             => p_org_id,
                                           p_operating_unit     => NULL,
                                           p_api_version_number => ln_api_version_number,
                                           p_header_rec         => l_header_rec,
                                           p_line_tbl           => l_line_tbl,
                                           p_action_request_tbl => l_action_request_tbl,
                                           -- OUT variables
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
               IF lc_return_status = FND_API.G_RET_STS_SUCCESS THEN
                 DBMS_OUTPUT.PUT_LINE('The Sales Order '|| l_header_rec_out.order_number ||' is Successfully cancelled');
                 x_error_flag := 'S';
                 lc_error_message :='The Sales Order '|| l_header_rec_out.order_number ||' is Successfully cancelled';
                 COMMIT;
               ELSE
                  DBMS_OUTPUT.PUT_LINE('Failed to cancel the Sales Order.');
                  lc_error_message :=('Failed To Cancel The Sales Order '|| l_header_rec_out.order_number );
                  x_error_flag := 'E';
                  FOR i IN 1 .. ln_msg_count LOOP
                    lc_error_message := lc_error_message ||
                                        oe_msg_pub.get(p_msg_index => i,
                                                       p_encoded   => 'F');
                  END LOOP;
                  DBMS_OUTPUT.PUT_LINE(lc_error_message);

                  ROLLBACK;
               END IF;
              */
                DBMS_OUTPUT.put_line ('Calling  - Call_API ');
                lc_error_message               := NULL;
                call_api (l_header_rec, p_org_id, x_error_flag,
                          lc_error_message);
                x_error_message                :=
                    x_error_message || '.   ' || lc_error_message;
            --DBMS_OUTPUT.PUT_LINE('x_error_message - '||x_error_message);
            END LOOP;
        ELSIF p_call_form = 'LINE'
        THEN
            xxd_common_utils.record_error (
                'DOE',
                xxd_common_utils.get_org_id,
                'XXD_SALES_ORDER_PKG.CANCEL_ORDER_HEADER_LINE',
                'After Apps Initialization Inside Line Cancellation Flow',
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'));
            l_header_rec      := oe_order_pub.g_miss_header_rec;
            --FETCH LINE COUNT
            ln_line_count     := p_line_tbl.COUNT;
            xxd_common_utils.record_error (
                'DOE',
                xxd_common_utils.get_org_id,
                'XXD_SALES_ORDER_PKG.CANCEL_ORDER_HEADER_LINE',
                   'After Apps Initialization Inside Line Cancellation Flow ln_line_count '
                || ln_line_count,
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'));

            --POPULATE LINE ATTRIBUTE
            FOR i IN 1 .. ln_line_count
            LOOP
                xxd_common_utils.record_error (
                    'DOE',
                    xxd_common_utils.get_org_id,
                    'XXD_SALES_ORDER_PKG.CANCEL_ORDER_HEADER_LINE',
                       'After Apps Initialization Inside Line Cancellation Flow l_line_tbl (i).header_id '
                    || p_line_tbl (i).header_id
                    || ' p_line_tbl (i).line_id '
                    || p_line_tbl (i).line_id
                    || ' p_line_tbl (i).reason '
                    || p_line_tbl (i).reason
                    || ' p_line_tbl (i).comments '
                    || p_line_tbl (i).comments,
                    DBMS_UTILITY.format_error_backtrace,
                    fnd_profile.VALUE ('USER_ID'));
                l_line_tbl (i)                    := oe_order_pub.g_miss_line_rec;
                l_line_tbl (i).header_id          := p_line_tbl (i).header_id;
                --Optional Parameter
                l_line_tbl (i).line_id            := p_line_tbl (i).line_id;
                --Mandatory parameter
                l_line_tbl (i).ordered_quantity   := 0;
                l_line_tbl (i).cancelled_flag     := 'Y';
                l_line_tbl (i).change_reason      := p_line_tbl (i).reason;
                l_line_tbl (i).change_comments    := p_line_tbl (i).comments;
                l_line_tbl (i).operation          := oe_globals.g_opr_update;
            END LOOP;

            xxd_common_utils.record_error (
                'DOE',
                xxd_common_utils.get_org_id,
                'XXD_SALES_ORDER_PKG.CANCEL_ORDER_HEADER_LINE',
                'After Apps Initialization Inside Line Cancellation Flow Before Calling process_order API',
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'));
            oe_msg_pub.initialize;
            -- CALL TO PROCESS Order
            oe_order_pub.process_order (
                p_org_id                   => p_org_id,
                p_operating_unit           => NULL,
                p_api_version_number       => ln_api_version_number,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                -- OUT variables
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
            xxd_common_utils.record_error (
                'DOE',
                xxd_common_utils.get_org_id,
                'XXD_SALES_ORDER_PKG.CANCEL_ORDER_HEADER_LINE',
                   'After Apps Initialization Inside Line Cancellation Flow Before Calling process_order API with Status :-  '
                || lc_return_status,
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'));

            -- CHECK RETURN STATUS
            IF lc_return_status = fnd_api.g_ret_sts_success
            THEN
                DBMS_OUTPUT.put_line (
                    'The Line of Sales Order Successfully cancelled');
                x_error_flag   := 'S';
                lc_error_message   :=
                    'The Line of Sales Order Successfully cancelled';
                xxd_common_utils.record_error (
                    'DOE',
                    xxd_common_utils.get_org_id,
                    'XXD_SALES_ORDER_PKG.CANCEL_ORDER_HEADER_LINE',
                    'After Apps Initialization Inside Line Cancellation Flow Before Calling process_order API The Line of Sales Order Successfully cancelled ',
                    DBMS_UTILITY.format_error_backtrace,
                    fnd_profile.VALUE ('USER_ID'));
                COMMIT;
            ELSE
                DBMS_OUTPUT.put_line (
                    'Failed to cancel the line of Sales Order.');
                x_error_flag   := 'E';

                FOR i IN 1 .. ln_msg_count
                LOOP
                    lc_error_message   :=
                           lc_error_message
                        || oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                END LOOP;

                DBMS_OUTPUT.put_line (lc_error_message);
                xxd_common_utils.record_error (
                    'DOE',
                    xxd_common_utils.get_org_id,
                    'XXD_SALES_ORDER_PKG.CANCEL_ORDER_HEADER_LINE',
                       'After Apps Initialization Inside Line Cancellation Flow Before Calling process_order API lc_error_message '
                    || lc_error_message,
                    DBMS_UTILITY.format_error_backtrace,
                    fnd_profile.VALUE ('USER_ID'));
                ROLLBACK;
            END IF;

            x_error_message   := lc_error_message;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'Exception in cancel order line:' || SQLERRM);
            x_error_flag      := 'E';
            x_error_message   := SUBSTR (SQLERRM, 1, 1500);
            xxd_common_utils.record_error (
                'DOE',
                xxd_common_utils.get_org_id,
                'XXD_SALES_ORDER_PKG.CANCEL_ORDER_HEADER_LINE',
                   'After Apps Initialization Inside Line Cancellation Flow Before Calling process_order API x_error_message '
                || x_error_message,
                DBMS_UTILITY.format_error_backtrace,
                fnd_profile.VALUE ('USER_ID'));
    END cancel_order_header_line;

    --This procedure is used to cancel sales order line
    PROCEDURE apply_hold_header_line (p_header_rec IN xxd_btom_oeheader_tbltype, p_line_tbl IN xxd_btom_oeline_tbltype, p_org_id IN NUMBER, p_call_form IN VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER
                                      , p_resp_app_id IN NUMBER, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        ln_api_version_number          NUMBER := 1;
        lc_return_status               VARCHAR2 (10);
        ln_msg_count                   NUMBER;
        ln_hold_id                     NUMBER;
        lc_flow_status_code            VARCHAR2 (60);
        lc_activity_name               VARCHAR2 (60);
        lc_msg_data                    VARCHAR2 (2000);
        lc_error_message               VARCHAR2 (2000);
        ln_cnt                         NUMBER;
        lc_order_number                VARCHAR2 (60);
        ln_line_count                  NUMBER;
        ln_header_count                NUMBER;
        ln_hold_check_cnt              NUMBER;
        ln_line_number                 NUMBER;
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
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_app_id);
        mo_global.set_policy_context ('S', p_org_id);
        mo_global.init ('ONT');

        IF p_call_form = 'HEADER'
        THEN
            --FETCH Header COUNT
            ln_header_count    := p_header_rec.COUNT;
            lc_error_message   := NULL;
            ln_cnt             := 0;

            --Get hold id
            FOR i IN 1 .. ln_header_count
            LOOP
                BEGIN
                    ln_hold_id          := NULL;
                    lc_activity_name    := NULL;
                    lc_order_number     := NULL;
                    ln_hold_check_cnt   := NULL;

                    SELECT hold_id, DECODE (activity_name, 'BOOK_ORDER', 'BOOKED', 'XXX')
                      INTO ln_hold_id, lc_activity_name
                      FROM oe_hold_definitions
                     WHERE name = p_header_rec (i).hold_name;

                    SELECT flow_status_code, order_number
                      INTO lc_flow_status_code, lc_order_number
                      FROM oe_order_headers_all
                     WHERE header_id = p_header_rec (i).header_id;

                    SELECT COUNT (*)
                      INTO ln_hold_check_cnt
                      FROM oe_order_headers_all ooha, oe_order_holds_all oha, oe_hold_sources_all ohsa
                     WHERE     ooha.header_id = oha.header_id
                           AND oha.line_id IS NULL
                           AND oha.released_flag = 'N'
                           AND oha.hold_source_id = ohsa.hold_source_id
                           AND ohsa.hold_id = ln_hold_id
                           AND ooha.header_id = p_header_rec (i).header_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        DBMS_OUTPUT.put_line (
                               'The hold '
                            || p_header_rec (i).hold_name
                            || ' is not defined');
                        lc_error_message   :=
                               'The hold '
                            || p_header_rec (i).hold_name
                            || ' is not defined';
                        ln_hold_id   := NULL;
                        RAISE ex_exception;
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.put_line (
                            'Error while getting hold id:' || SQLERRM);
                        lc_error_message   :=
                            'Error while getting hold id:' || SQLERRM;
                        ln_hold_id   := NULL;
                        RAISE ex_exception;
                END;

                IF lc_activity_name = lc_flow_status_code
                THEN
                    lc_error_message   :=
                           lc_error_message
                        || ' Hold On Workflow Activity, Book Order Is Not Applicable To The Sales Order - '
                        || lc_order_number
                        || '. ';
                ELSIF ln_hold_check_cnt > 0
                THEN
                    lc_error_message   :=
                           lc_error_message
                        || ' The Hold '
                        || p_header_rec (i).hold_name
                        || 'Is Already Applied To Order '
                        || lc_order_number
                        || '. ';
                ELSE
                    --This is to apply hold an order header or line
                    ln_cnt                                       := ln_cnt + 1;
                    l_action_request_tbl (ln_cnt)                :=
                        oe_order_pub.g_miss_request_rec;
                    l_action_request_tbl (ln_cnt).entity_id      :=
                        p_header_rec (i).header_id;
                    l_action_request_tbl (ln_cnt).entity_code    :=
                        oe_globals.g_entity_header;
                    l_action_request_tbl (ln_cnt).request_type   :=
                        oe_globals.g_apply_hold;
                    l_action_request_tbl (ln_cnt).param1         :=
                        ln_hold_id;                                 -- hold_id
                    l_action_request_tbl (ln_cnt).param2         := 'O';
                    -- indicator that it is an order hold
                    l_action_request_tbl (ln_cnt).param3         :=
                        p_header_rec (i).header_id;
                    -- Header or LINE ID of the order
                    l_action_request_tbl (ln_cnt).param4         :=
                        p_header_rec (i).hold_comments;
                    -- hold comments
                    l_action_request_tbl (ln_cnt).date_param1    :=
                        p_header_rec (i).hold_until_date;
                -- hold until date
                END IF;
            END LOOP;
        ELSIF p_call_form = 'LINE'
        THEN
            l_header_rec       := oe_order_pub.g_miss_header_rec;
            ln_line_count      := p_line_tbl.COUNT;
            lc_error_message   := NULL;
            ln_line_number     := NULL;
            ln_cnt             := 0;

            FOR i IN 1 .. ln_line_count
            LOOP
                --Get hold id
                BEGIN
                    ln_hold_id          := NULL;
                    ln_hold_check_cnt   := NULL;

                    SELECT hold_id
                      INTO ln_hold_id
                      FROM oe_hold_definitions
                     WHERE NAME = p_line_tbl (i).hold_name;

                    SELECT line_number
                      INTO ln_line_number
                      FROM oe_order_lines_all
                     WHERE line_id = p_line_tbl (i).line_id;

                    SELECT COUNT (*)
                      INTO ln_hold_check_cnt
                      FROM oe_order_holds_all oha, oe_hold_sources_all ohsa, oe_order_lines_all oola
                     WHERE     oola.header_id = oha.header_id
                           AND oola.line_id = oha.line_id
                           AND oha.released_flag = 'N'
                           AND oha.hold_source_id = ohsa.hold_source_id
                           AND ohsa.hold_id = ln_hold_id
                           AND oola.header_id = p_line_tbl (i).header_id
                           AND oola.line_id = p_line_tbl (i).line_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        DBMS_OUTPUT.put_line (
                               'The hold '
                            || p_line_tbl (i).hold_name
                            || ' is not defined');
                        lc_error_message   :=
                               'The hold '
                            || p_line_tbl (i).hold_name
                            || ' is not defined';
                        ln_hold_id   := NULL;
                        RAISE ex_exception;
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.put_line (
                            'Error while getting hold id:' || SQLERRM);
                        lc_error_message   :=
                            'Error while getting hold id:' || SQLERRM;
                        ln_hold_id   := NULL;
                        RAISE ex_exception;
                END;

                IF ln_hold_check_cnt > 0
                THEN
                    lc_error_message   :=
                           lc_error_message
                        || ' The Hold '
                        || p_header_rec (i).hold_name
                        || 'Is Already Applied To Line Numebr '
                        || ln_line_number
                        || '. ';
                ELSE
                    --This is to apply hold an order header or line
                    ln_cnt                                       := ln_cnt + 1;
                    l_action_request_tbl (ln_cnt)                :=
                        oe_order_pub.g_miss_request_rec;
                    l_action_request_tbl (ln_cnt).entity_id      :=
                        p_line_tbl (i).line_id;
                    l_action_request_tbl (ln_cnt).entity_code    :=
                        oe_globals.g_entity_line;
                    l_action_request_tbl (ln_cnt).request_type   :=
                        oe_globals.g_apply_hold;
                    l_action_request_tbl (ln_cnt).param1         :=
                        ln_hold_id;                                 -- hold_id
                    l_action_request_tbl (ln_cnt).param2         := 'O';
                    -- indicator that it is an order hold
                    l_action_request_tbl (ln_cnt).param3         :=
                        p_line_tbl (i).header_id;
                    -- Header or LINE ID of the order
                    l_action_request_tbl (ln_cnt).param4         :=
                        p_line_tbl (i).hold_comments;
                    -- hold comments
                    l_action_request_tbl (ln_cnt).date_param1    :=
                        p_line_tbl (i).hold_until_date;
                -- hold until date
                END IF;
            END LOOP;
        END IF;

        IF ln_hold_id IS NOT NULL AND ln_cnt > 0
        THEN
            oe_msg_pub.initialize;
            -- CALL TO PROCESS Order
            oe_order_pub.process_order (
                p_org_id                   => p_org_id,
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
            DBMS_OUTPUT.put_line (' lc_return_status - ' || lc_return_status);
            DBMS_OUTPUT.put_line (
                   ' lc_msg_data - '
                || lc_msg_data
                || ' -- ln_msg_count - '
                || ln_msg_count);

            IF lc_return_status = fnd_api.g_ret_sts_success
            THEN
                x_error_flag   := 'S';
                lc_error_message   :=
                       lc_error_message
                    || ' The Hold Is Successfully Applied on the Sales Order. ';
                COMMIT;
            ELSE
                DBMS_OUTPUT.put_line (
                    'Failed to cancel the line of Sales Order.');
                x_error_flag   := 'E';

                FOR i IN 1 .. ln_msg_count
                LOOP
                    lc_error_message   :=
                           lc_error_message
                        || oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                END LOOP;

                DBMS_OUTPUT.put_line (
                    'lc_error_message ' || lc_error_message);
                ROLLBACK;
            END IF;

            x_error_message   := lc_error_message;
        ELSE
            x_error_message   := lc_error_message;
        END IF;
    EXCEPTION
        WHEN ex_exception
        THEN
            x_error_message   := lc_error_message;
            x_error_flag      := 'E';
        WHEN OTHERS
        THEN
            x_error_message   := 'Exception in Apply Hold :' || SQLERRM;
            x_error_flag      := 'E';
    END apply_hold_header_line;

    --This procedure is used to cancel sales order line
    PROCEDURE release_hold_header_line (p_header_rec IN xxd_btom_oeheader_tbltype, p_line_tbl IN xxd_btom_oeline_tbltype, p_org_id IN NUMBER, p_call_form IN VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER
                                        , p_resp_app_id IN NUMBER, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        ln_api_version_number          NUMBER := 1;
        lc_return_status               VARCHAR2 (10);
        ln_msg_count                   NUMBER;
        ln_hold_id                     NUMBER;
        lc_msg_data                    VARCHAR2 (2000);
        lc_error_message               VARCHAR2 (2000);
        ln_line_count                  NUMBER;
        ln_header_count                NUMBER;
        ln_cnt                         NUMBER;
        lc_item_type                   VARCHAR2 (10);
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

        CURSOR lcu_chk_hold_release (p_hold_id NUMBER, p_item_type VARCHAR2)
        IS
            SELECT COUNT (*)
              FROM oe_hold_definitions h, oe_hold_authorizations ha, oe_lookups l
             WHERE     SYSDATE BETWEEN NVL (h.start_date_active, SYSDATE)
                                   AND NVL (h.end_date_active, SYSDATE)
                   AND l.lookup_type = 'HOLD_TYPE'
                   AND l.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (l.start_date_active, SYSDATE)
                                   AND NVL (l.end_date_active, SYSDATE)
                   AND h.type_code = l.lookup_code
                   AND h.hold_id >= 1000
                   AND (h.item_type = p_item_type OR h.item_type IS NULL)
                   AND h.hold_id = ha.hold_id(+)
                   AND SYSDATE BETWEEN NVL (ha.start_date_active, SYSDATE)
                                   AND NVL (ha.end_date_active, SYSDATE)
                   AND h.hold_id = p_hold_id
                   AND NVL (ha.authorized_action_code, 'REMOVE') = 'REMOVE'
                   AND ha.responsibility_id = p_resp_id
                   AND ha.application_id = p_resp_app_id;
    BEGIN
        -- INITIALIZE ENVIRONMENT
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_app_id);
        mo_global.set_policy_context ('S', p_org_id);
        mo_global.init ('ONT');

        IF p_call_form = 'HEADER'
        THEN
            --FETCH Header COUNT
            ln_header_count    := p_header_rec.COUNT;
            lc_error_message   := NULL;

            --Get hold id
            FOR i IN 1 .. ln_header_count
            LOOP
                BEGIN
                    SELECT hold_id
                      INTO ln_hold_id
                      FROM oe_hold_definitions
                     WHERE NAME = p_header_rec (i).hold_name;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        DBMS_OUTPUT.put_line (
                               'The hold '
                            || p_header_rec (i).hold_name
                            || ' is not defined');
                        lc_error_message   :=
                               'The hold '
                            || p_header_rec (i).hold_name
                            || ' is not defined';
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.put_line (
                            'Error while getting hold id:' || SQLERRM);
                        lc_error_message   :=
                            'Error while getting hold id:' || SQLERRM;
                END;

                --This is to apply hold an order header or line
                l_action_request_tbl (i)                := oe_order_pub.g_miss_request_rec;
                l_action_request_tbl (i).entity_id      :=
                    p_header_rec (i).header_id;
                l_action_request_tbl (i).entity_code    :=
                    oe_globals.g_entity_header;
                l_action_request_tbl (i).request_type   :=
                    oe_globals.g_release_hold;
                l_action_request_tbl (i).param1         := ln_hold_id; -- hold_id
                l_action_request_tbl (i).param2         := 'O';
                -- indicator that it is an order hold
                l_action_request_tbl (i).param3         :=
                    p_header_rec (i).header_id;
                -- Header or LINE ID of the order
                l_action_request_tbl (i).param4         :=
                    p_header_rec (i).release_reason;
                -- hold comments
                l_action_request_tbl (i).param5         :=
                    p_header_rec (i).release_comments;
            -- hold until date
            END LOOP;
        ELSIF p_call_form = 'LINE'
        THEN
            l_header_rec       := oe_order_pub.g_miss_header_rec;
            ln_line_count      := p_line_tbl.COUNT;
            lc_error_message   := NULL;

            FOR i IN 1 .. ln_line_count
            LOOP
                --Get hold id
                BEGIN
                    ln_hold_id   := NULL;

                    SELECT hold_id
                      INTO ln_hold_id
                      FROM oe_hold_definitions
                     WHERE NAME = p_line_tbl (1).hold_name;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        DBMS_OUTPUT.put_line (
                               'The hold '
                            || p_line_tbl (1).hold_name
                            || ' is not defined');
                        lc_error_message   :=
                               'The hold '
                            || p_line_tbl (1).hold_name
                            || ' is not defined';
                    WHEN OTHERS
                    THEN
                        DBMS_OUTPUT.put_line (
                            'Error while getting hold id:' || SQLERRM);
                        lc_error_message   :=
                            'Error while getting hold id:' || SQLERRM;
                END;

                --This is to apply hold an order header or line
                l_action_request_tbl (i)                := oe_order_pub.g_miss_request_rec;
                l_action_request_tbl (i).entity_id      :=
                    p_line_tbl (i).line_id;
                l_action_request_tbl (i).entity_code    :=
                    oe_globals.g_entity_line;
                l_action_request_tbl (i).request_type   :=
                    oe_globals.g_release_hold;
                l_action_request_tbl (i).param1         := ln_hold_id; -- hold_id
                l_action_request_tbl (i).param2         := 'O';
                -- indicator that it is an order hold
                l_action_request_tbl (i).param3         :=
                    p_line_tbl (i).line_id;
                -- Header or LINE ID of the order
                l_action_request_tbl (1).param4         :=
                    p_line_tbl (i).release_reason;
                -- hold comments
                l_action_request_tbl (1).param5         :=
                    p_line_tbl (i).release_comments;
            -- hold until date
            END LOOP;
        END IF;

        IF ln_hold_id IS NOT NULL
        THEN
            IF p_call_form = 'HEADER'
            THEN
                lc_item_type   := 'OEOH';
            ELSE
                lc_item_type   := 'OEOL';
            END IF;

            OPEN lcu_chk_hold_release (ln_hold_id, lc_item_type);

            FETCH lcu_chk_hold_release INTO ln_cnt;

            CLOSE lcu_chk_hold_release;

            IF ln_cnt = 0
            THEN
                x_error_message   :=
                    'You are not authorized to Release this Hold. ';
                x_error_flag   := 'E';
            ELSE
                oe_msg_pub.initialize;
                -- CALL TO PROCESS Order
                oe_order_pub.process_order (
                    p_org_id                   => p_org_id,
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
                DBMS_OUTPUT.put_line (
                    ' lc_return_status - ' || lc_return_status);

                IF lc_return_status = fnd_api.g_ret_sts_success
                THEN
                    x_error_flag   := 'S';
                    lc_error_message   :=
                        'The Hold Released Successfully on the Sales Order';
                    COMMIT;
                ELSE
                    x_error_flag   := 'E';

                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        lc_error_message   :=
                               lc_error_message
                            || oe_msg_pub.get (p_msg_index   => i,
                                               p_encoded     => 'F');
                    END LOOP;

                    DBMS_OUTPUT.put_line (lc_error_message);
                    ROLLBACK;
                END IF;

                x_error_message   := lc_error_message;
            END IF;                                      -- IF ln_cnt = 0 THEN
        ELSE
            x_error_message   := lc_error_message;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_error_message   := 'Exception in Release Hold :' || SQLERRM;
    END release_hold_header_line;

    PROCEDURE check_atp_qty (p_inv_item_id          NUMBER,
                             p_requested_date       DATE,
                             p_warehouse_id         NUMBER,
                             p_demand_class         VARCHAR2,
                             p_quantity             NUMBER,
                             p_order_line_id        NUMBER,
                             p_uom                  VARCHAR2,
                             x_error_message    OUT VARCHAR2,
                             x_atp_error_flag   OUT VARCHAR2)
    IS
        l_atp_rec             mrp_atp_pub.atp_rec_typ;
        p_atp_rec             mrp_atp_pub.atp_rec_typ;
        x_atp_rec             mrp_atp_pub.atp_rec_typ;
        x_atp_supply_demand   mrp_atp_pub.atp_supply_demand_typ;
        x_atp_period          mrp_atp_pub.atp_period_typ;
        x_atp_details         mrp_atp_pub.atp_details_typ;
        x_return_status       VARCHAR2 (10);
        x_msg_data            VARCHAR2 (4000);
        x_msg_count           NUMBER;
        ln_segment1           VARCHAR2 (150);
        lc_error_message      VARCHAR2 (4000);
        ln_msg_index_out      NUMBER;
        l_session_id          NUMBER;
    BEGIN
        msc_atp_global.extend_atp (l_atp_rec, x_return_status, 1);

        SELECT oe_order_sch_util.get_session_id INTO l_session_id FROM DUAL;

        SELECT segment1
          INTO ln_segment1
          FROM mtl_system_items_b
         WHERE     inventory_item_id = p_inv_item_id
               AND organization_id = p_warehouse_id;

        DBMS_OUTPUT.put_line (' Segment1  - ' || ln_segment1);
        DBMS_OUTPUT.put_line (' Inside check_atp_qty - ' || p_inv_item_id);
        l_atp_rec.inventory_item_id (1)        := p_inv_item_id;
        l_atp_rec.inventory_item_name (1)      := NULL;
        l_atp_rec.quantity_ordered (1)         := 1;
        l_atp_rec.quantity_uom (1)             := p_uom;
        l_atp_rec.requested_ship_date (1)      := p_requested_date;
        l_atp_rec.action (1)                   := 100;
        l_atp_rec.instance_id (1)              := NULL;
        l_atp_rec.source_organization_id (1)   := p_warehouse_id;
        l_atp_rec.demand_class (1)             := p_demand_class;
        l_atp_rec.oe_flag (1)                  := 'N';
        l_atp_rec.insert_flag (1)              := 1;
        l_atp_rec.attribute_04 (1)             := 1;
        l_atp_rec.calling_module (1)           := 660;
        l_atp_rec.IDENTIFIER (1)               := p_order_line_id;
        DBMS_OUTPUT.put_line (' Before calling MRP_ATP_PUB.Call_ATP ');
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
        DBMS_OUTPUT.put_line (' x_return_status - ' || x_return_status);

        IF (x_return_status = 'S')
        THEN
            FOR i IN 1 .. x_atp_rec.inventory_item_id.COUNT
            LOOP
                DBMS_OUTPUT.put_line (
                       ' x_atp_rec.Available_Quantity(1)  - '
                    || NVL (x_atp_rec.available_quantity (1), 0));

                IF p_quantity > NVL (x_atp_rec.available_quantity (i), 0)
                THEN
                    lc_error_message   :=
                           lc_error_message
                        || ' Ordered Quantity for the inventory item '
                        || ln_segment1
                        || ' is greater then the ATP. ';
                END IF;
            END LOOP;

            x_atp_error_flag   := 'S';
            x_error_message    := lc_error_message;
        ELSE
            FOR i IN 1 .. x_msg_count
            LOOP
                fnd_msg_pub.get (i, fnd_api.g_false, x_msg_data,
                                 ln_msg_index_out);
                lc_error_message   :=
                    lc_error_message || (TO_CHAR (i) || ': ' || x_msg_data);
            END LOOP;

            x_atp_error_flag   := 'E';
            x_error_message    := lc_error_message;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (' Exception - ' || SQLERRM);
            x_atp_error_flag   := 'E';
            x_error_message    :=
                'Exception while checking the ATP ' || SQLERRM;
    END check_atp_qty;

    PROCEDURE delete_order_header (p_header_id NUMBER, p_org_id NUMBER, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, x_error_flag OUT VARCHAR2
                                   , x_error_message OUT VARCHAR2)
    IS
        x_return_status    VARCHAR2 (10);
        x_msg_data         VARCHAR2 (4000);
        x_msg_count        NUMBER;
        ln_msg_index_out   NUMBER;
        ln_order_number    NUMBER;
        lc_error_message   VARCHAR2 (4000);
    BEGIN
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_app_id);
        mo_global.set_policy_context ('S', p_org_id);
        mo_global.init ('ONT');

        SELECT order_number
          INTO ln_order_number
          FROM oe_order_headers
         WHERE header_id = p_header_id;

        oe_order_pub.delete_order (p_header_id        => p_header_id,
                                   p_org_id           => p_org_id,
                                   p_operating_unit   => NULL,
                                   x_return_status    => x_return_status,
                                   x_msg_count        => x_msg_count,
                                   x_msg_data         => x_msg_data);

        IF (x_return_status = 'S')
        THEN
            x_error_message   :=
                   'Sales Order Number '
                || ln_order_number
                || ' Successfully Deleted. ';
            x_error_flag   := 'S';
            COMMIT;
        ELSE
            FOR i IN 1 .. x_msg_count
            LOOP
                fnd_msg_pub.get (i, fnd_api.g_false, x_msg_data,
                                 ln_msg_index_out);
                lc_error_message   :=
                    lc_error_message || (TO_CHAR (i) || ': ' || x_msg_data);
            END LOOP;

            ROLLBACK;
            x_error_flag      := 'E';
            x_error_message   := lc_error_message;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (' Exception - ' || SQLERRM);
            x_error_flag   := 'E';
            x_error_message   :=
                   'Exception while Deleting the Sales Order Number - '
                || ln_order_number;
    END delete_order_header;

    PROCEDURE delete_order_line (p_line_tbl IN xxd_btom_oeline_tbltype, p_org_id IN NUMBER, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, x_error_flag OUT VARCHAR2
                                 , x_error_message OUT VARCHAR2)
    IS
        x_return_status    VARCHAR2 (10);
        x_msg_data         VARCHAR2 (4000);
        x_msg_count        NUMBER;
        ln_msg_index_out   NUMBER;
        ln_line_number     NUMBER;
        lc_error_message   VARCHAR2 (4000);
        ln_line_id         NUMBER;
        lc_error_flag      VARCHAR2 (10);
        lc_err_chk         VARCHAR2 (1) := 'S';
    BEGIN
        DBMS_OUTPUT.put_line (' Inside delete_order_line ');
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_app_id);
        mo_global.set_policy_context ('S', p_org_id);
        mo_global.init ('ONT');
        DBMS_OUTPUT.put_line (' p_line_tbl.count -  ' || p_line_tbl.COUNT);

        FOR i IN 1 .. p_line_tbl.COUNT
        LOOP
            DBMS_OUTPUT.put_line (
                ' p_line_tbl(i).line_id -  ' || p_line_tbl (i).line_id);
            ln_line_id   := p_line_tbl (i).line_id;

            SELECT line_number
              INTO ln_line_number
              FROM oe_order_lines
             WHERE line_id = ln_line_id;

            oe_order_pub.delete_line (p_line_id          => ln_line_id,
                                      p_org_id           => p_org_id,
                                      p_operating_unit   => NULL,
                                      x_return_status    => x_return_status,
                                      x_msg_count        => x_msg_count,
                                      x_msg_data         => x_msg_data);
            DBMS_OUTPUT.put_line (' x_return_status - ' || x_return_status);

            IF (x_return_status = 'S')
            THEN
                /*lc_error_message :=
                      lc_error_message
                   || 'Sales Order Line Number '
                   || ln_line_number
                   || ' Successfully Deleted. ';*/
                lc_error_flag   := 'S';
            ELSE
                lc_err_chk         := 'E';

                FOR i IN 1 .. x_msg_count
                LOOP
                    fnd_msg_pub.get (i, fnd_api.g_false, x_msg_data,
                                     ln_msg_index_out);
                    lc_error_message   :=
                           lc_error_message
                        || (TO_CHAR (i) || ': ' || x_msg_data);
                END LOOP;

                lc_error_message   :=
                       lc_error_message
                    || ' for sales order line number '
                    || ln_line_number
                    || ' . ';
                lc_error_flag      := 'E';
            END IF;
        END LOOP;

        IF lc_err_chk = 'E'
        THEN
            lc_error_message   :=
                'Error while deleteing ' || lc_error_message;
            lc_error_flag   := 'E';
            ROLLBACK;
        ELSE
            lc_error_message   :=
                'Selected sale order lines are successfully deleted. ';
            lc_error_flag   := 'S';
            COMMIT;
        END IF;

        x_error_message   := lc_error_message;
        x_error_flag      := lc_error_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (' Exception - ' || SQLERRM);
            x_error_flag   := 'E';
            x_error_message   :=
                'Exception while Deleting the Sales Order Line Number. ';
    END delete_order_line;

    PROCEDURE get_line_price_adj_details (
        p_user_id             IN            NUMBER,
        p_resp_id             IN            NUMBER,
        p_resp_appl_id        IN            NUMBER,
        p_level               IN            VARCHAR2,
        p_entity_id           IN            NUMBER,
        x_modifier_line_tbl      OUT NOCOPY xxd_btom_apply_price_adj_tbl,
        x_error_flag             OUT        VARCHAR2,
        x_error_message          OUT        VARCHAR2)
    IS
        ln_org_id                         NUMBER;
        --LC_LEVEL_ALL          CONSTANT VARCHAR2(10) := 'LINE';
        lc_pdh_mode_parent       CONSTANT VARCHAR2 (6) := 'PARENT';
        lx_manual_adj_tbl                 oe_order_adj_pvt.manual_adj_tbl_type;
        lx_modifier_line_tbl              xxd_btom_apply_price_adj_tbl;
        lcx_return_status                 VARCHAR2 (10);
        ln_header_id                      NUMBER;
        ln_line_id                        NUMBER;
        lnx_header_id                     NUMBER;
        lc_enabled_flag_y        CONSTANT VARCHAR2 (1) := 'Y';
        lc_list_line_type_code   CONSTANT VARCHAR2 (19)
                                              := 'LIST_LINE_TYPE_CODE' ;
        lc_arithmetic_operator   CONSTANT VARCHAR2 (19)
                                              := 'ARITHMETIC_OPERATOR' ;
        ln_current_line_price             NUMBER;
        ln_unit_price                     NUMBER;
        ln_ordered_quantity               NUMBER;
        ln_amount                         NUMBER;
        lc_error_msg                      VARCHAR2 (4000);
        ex_exception                      EXCEPTION;
        l_cnt                             NUMBER := 0;
    BEGIN
        -- Fetch organisation id from Order Line.
        IF p_level = 'LINE'
        THEN
            SELECT org_id, unit_selling_price, unit_list_price,
                   ordered_quantity, header_id
              INTO ln_org_id, ln_current_line_price, ln_unit_price, ln_ordered_quantity,
                            ln_header_id
              FROM oe_order_lines_all
             WHERE line_id = p_entity_id;

            ln_line_id   := p_entity_id;
        END IF;

        IF p_level = 'ORDER'
        THEN
              SELECT SUM (ordered_quantity * unit_list_price), ool.org_id
                INTO ln_amount, ln_org_id
                FROM oe_order_headers_all ooh, oe_order_lines_all ool
               WHERE     ooh.header_id = ool.header_id
                     AND ooh.header_id = p_entity_id
            GROUP BY ool.org_id;

            ln_header_id   := p_entity_id;
            ln_line_id     := NULL;
        END IF;

        -- Set context
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_appl_id);
        DBMS_OUTPUT.put_line ('6');
        mo_global.set_policy_context ('S', ln_org_id);

        -- Get modifiers for current order line
        oe_order_adj_pvt.get_manual_adjustments (
            p_header_id        => ln_header_id,
            p_line_id          => ln_line_id,
            p_level            => p_level,
            p_pbh_mode         => lc_pdh_mode_parent,
            x_manual_adj_tbl   => lx_manual_adj_tbl,
            x_return_status    => lcx_return_status,
            x_header_id        => lnx_header_id);

        lx_modifier_line_tbl   := xxd_btom_apply_price_adj_tbl ();

        FOR ln_manual_adj_index IN 1 .. lx_manual_adj_tbl.COUNT
        LOOP
            lx_modifier_line_tbl.EXTEND;
            lx_modifier_line_tbl (ln_manual_adj_index)   :=
                xxd_btom_apply_price_adj_type (NULL, NULL, NULL,
                                               NULL, NULL, NULL,
                                               NULL, NULL, NULL,
                                               NULL, NULL, NULL,
                                               NULL);

            lx_modifier_line_tbl (ln_manual_adj_index).list_header_id   :=
                lx_manual_adj_tbl (ln_manual_adj_index).list_header_id;

            lx_modifier_line_tbl (ln_manual_adj_index).list_line_id   :=
                lx_manual_adj_tbl (ln_manual_adj_index).list_line_id;

            lx_modifier_line_tbl (ln_manual_adj_index).modifier_level   :=
                lx_manual_adj_tbl (ln_manual_adj_index).modifier_level_code;

            --lx_modifier_line_tbl (ln_manual_adj_index).list_line_number :=
            --             lx_manual_adj_tbl (ln_manual_adj_index).modifier_number;

            lx_modifier_line_tbl (ln_manual_adj_index).override_allowed_flag   :=
                NVL (lx_manual_adj_tbl (ln_manual_adj_index).override_flag,
                     'N');


            --get list line type
            SELECT meaning
              INTO lx_modifier_line_tbl (ln_manual_adj_index).list_line_type
              FROM qp_lookups
             WHERE     lookup_type = lc_list_line_type_code
                   AND lookup_code =
                       lx_manual_adj_tbl (ln_manual_adj_index).list_line_type_code
                   AND enabled_flag = lc_enabled_flag_y
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE);

            --get application method
            IF lx_manual_adj_tbl (ln_manual_adj_index).OPERATOR IS NULL
            THEN
                lx_modifier_line_tbl (ln_manual_adj_index).application_method   :=
                    NULL;
            ELSE
                BEGIN
                    SELECT meaning
                      INTO lx_modifier_line_tbl (ln_manual_adj_index).application_method
                      FROM qp_lookups
                     WHERE     lookup_type = lc_arithmetic_operator
                           AND lookup_code =
                               lx_manual_adj_tbl (ln_manual_adj_index).OPERATOR
                           AND enabled_flag = lc_enabled_flag_y
                           AND SYSDATE BETWEEN NVL (start_date_active,
                                                    SYSDATE)
                                           AND NVL (end_date_active, SYSDATE);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_error_msg   :=
                               'Error while fetching application method:'
                            || SUBSTR (SQLERRM, 1, 1500);
                        RAISE ex_exception;
                END;
            END IF;

            --get modifier number, modifier name
            BEGIN
                SELECT NAME, description
                  INTO lx_modifier_line_tbl (ln_manual_adj_index).modifier_number, lx_modifier_line_tbl (ln_manual_adj_index).modifier_name
                  FROM qp_list_headers_tl
                 WHERE     list_header_id =
                           lx_manual_adj_tbl (ln_manual_adj_index).list_header_id
                       AND LANGUAGE = USERENV ('LANG');
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_error_msg   :=
                           'Error while fetching modifier number and name:'
                        || SUBSTR (SQLERRM, 1, 1500);
                    RAISE ex_exception;
            END;

            lx_modifier_line_tbl (ln_manual_adj_index).automatic_flag   :=
                lx_manual_adj_tbl (ln_manual_adj_index).automatic_flag;
            lx_modifier_line_tbl (ln_manual_adj_index).rate   :=
                lx_manual_adj_tbl (ln_manual_adj_index).operand;

            IF (p_level = 'LINE')
            THEN
                IF lx_modifier_line_tbl (ln_manual_adj_index).application_method =
                   'Percent'
                THEN
                    lx_modifier_line_tbl (ln_manual_adj_index).adjusted_amount   :=
                          (ln_unit_price * lx_manual_adj_tbl (ln_manual_adj_index).operand)
                        / 100;
                    lx_modifier_line_tbl (ln_manual_adj_index).extended_adjusted_amount   :=
                          lx_modifier_line_tbl (ln_manual_adj_index).adjusted_amount
                        * ln_ordered_quantity;
                ELSIF lx_modifier_line_tbl (ln_manual_adj_index).application_method =
                      'Amount'
                THEN
                    lx_modifier_line_tbl (ln_manual_adj_index).adjusted_amount   :=
                        lx_manual_adj_tbl (ln_manual_adj_index).operand;
                    lx_modifier_line_tbl (ln_manual_adj_index).extended_adjusted_amount   :=
                          lx_modifier_line_tbl (ln_manual_adj_index).adjusted_amount
                        * ln_ordered_quantity;
                ELSIF lx_modifier_line_tbl (ln_manual_adj_index).application_method =
                      'Lumpsum'
                THEN
                    lx_modifier_line_tbl (ln_manual_adj_index).adjusted_amount   :=
                        ROUND (
                              lx_manual_adj_tbl (ln_manual_adj_index).operand
                            / ln_ordered_quantity,
                            1);
                    lx_modifier_line_tbl (ln_manual_adj_index).extended_adjusted_amount   :=
                        lx_manual_adj_tbl (ln_manual_adj_index).operand;
                ELSIF lx_modifier_line_tbl (ln_manual_adj_index).application_method =
                      'New Price'
                THEN
                    lx_modifier_line_tbl (ln_manual_adj_index).adjusted_amount   :=
                        ABS (
                              lx_manual_adj_tbl (ln_manual_adj_index).operand
                            - ln_unit_price);
                    lx_modifier_line_tbl (ln_manual_adj_index).extended_adjusted_amount   :=
                          ABS (
                                lx_manual_adj_tbl (ln_manual_adj_index).operand
                              - ln_unit_price)
                        * ln_ordered_quantity;
                END IF;
            END IF;

            IF (p_level = 'ORDER')
            THEN
                IF lx_modifier_line_tbl (ln_manual_adj_index).application_method =
                   'Percent'
                THEN
                    lx_modifier_line_tbl (ln_manual_adj_index).adjusted_amount   :=
                          (ln_amount * lx_manual_adj_tbl (ln_manual_adj_index).operand)
                        / 100;
                    lx_modifier_line_tbl (ln_manual_adj_index).extended_adjusted_amount   :=
                        lx_modifier_line_tbl (ln_manual_adj_index).adjusted_amount;
                END IF;
            END IF;
        END LOOP;

        DBMS_OUTPUT.put_line (lx_modifier_line_tbl.COUNT);
        x_modifier_line_tbl    := xxd_btom_apply_price_adj_tbl ();
        l_cnt                  := 0;

        IF (p_level = 'ORDER')
        THEN
            FOR k
                IN (SELECT xa.list_header_id, xa.list_line_id, xa.modifier_number,
                           xa.modifier_name, xa.modifier_level, xa.list_line_type,
                           xa.application_method, xa.rate, xa.adjusted_amount,
                           xa.extended_adjusted_amount, xa.automatic_flag, xa.list_line_number,
                           xa.override_allowed_flag
                      FROM TABLE (lx_modifier_line_tbl) xa
                     WHERE     NOT EXISTS
                                   (SELECT list_header_id, list_line_id
                                      FROM oe_price_adjustments_v opa
                                     WHERE     1 = 1
                                           AND opa.header_id = p_entity_id
                                           AND opa.line_id IS NULL
                                           AND opa.applied_flag = 'Y'
                                           AND opa.list_line_type_code <>
                                               'FREIGHT_CHARGE'
                                           AND (xa.list_header_id = opa.list_header_id AND xa.list_line_id = opa.list_line_id))
                           AND xa.modifier_number NOT LIKE 'BT_CONV%')
            LOOP
                x_modifier_line_tbl.EXTEND (1);
                l_cnt                                            := l_cnt + 1;
                x_modifier_line_tbl (l_cnt)                      :=
                    xxd_btom_apply_price_adj_type (NULL, NULL, NULL,
                                                   NULL, NULL, NULL,
                                                   NULL, NULL, NULL,
                                                   NULL, NULL, NULL,
                                                   NULL);
                x_modifier_line_tbl (l_cnt).list_header_id       :=
                    k.list_header_id;
                x_modifier_line_tbl (l_cnt).list_line_id         :=
                    k.list_line_id;
                x_modifier_line_tbl (l_cnt).modifier_number      :=
                    k.modifier_number;
                x_modifier_line_tbl (l_cnt).modifier_name        :=
                    k.modifier_name;
                x_modifier_line_tbl (l_cnt).modifier_level       :=
                    k.modifier_level;
                x_modifier_line_tbl (l_cnt).list_line_type       :=
                    k.list_line_type;
                x_modifier_line_tbl (l_cnt).application_method   :=
                    k.application_method;
                x_modifier_line_tbl (l_cnt).rate                 := k.rate;
                x_modifier_line_tbl (l_cnt).adjusted_amount      :=
                    k.adjusted_amount;
                x_modifier_line_tbl (l_cnt).extended_adjusted_amount   :=
                    k.extended_adjusted_amount;
                x_modifier_line_tbl (l_cnt).automatic_flag       :=
                    k.automatic_flag;
                x_modifier_line_tbl (l_cnt).list_line_number     :=
                    k.list_line_number;
                x_modifier_line_tbl (l_cnt).override_allowed_flag   :=
                    k.override_allowed_flag;
            END LOOP;
        END IF;

        IF (p_level = 'LINE')
        THEN
            FOR k
                IN (SELECT xa.list_header_id, xa.list_line_id, xa.modifier_number,
                           xa.modifier_name, xa.modifier_level, xa.list_line_type,
                           xa.application_method, xa.rate, xa.adjusted_amount,
                           xa.extended_adjusted_amount, xa.automatic_flag, xa.list_line_number,
                           xa.override_allowed_flag
                      FROM TABLE (lx_modifier_line_tbl) xa
                     WHERE     NOT EXISTS
                                   (SELECT opa.list_header_id, opa.list_line_id
                                      FROM oe_price_adjustments_v opa, oe_order_lines_all ool
                                     WHERE     1 = 1
                                           AND opa.line_id = ool.line_id
                                           AND opa.header_id = ool.header_id
                                           AND opa.applied_flag(+) = 'Y'
                                           AND opa.list_line_type_code(+) <>
                                               'FREIGHT_CHARGE'
                                           AND opa.list_line_type_code <>
                                               'CIE'
                                           AND ool.line_id = p_entity_id
                                           AND (xa.list_header_id = opa.list_header_id AND xa.list_line_id = opa.list_line_id))
                           AND xa.modifier_number NOT LIKE 'BT_CONV%')
            LOOP
                x_modifier_line_tbl.EXTEND (1);
                l_cnt                                            := l_cnt + 1;
                x_modifier_line_tbl (l_cnt)                      :=
                    xxd_btom_apply_price_adj_type (NULL, NULL, NULL,
                                                   NULL, NULL, NULL,
                                                   NULL, NULL, NULL,
                                                   NULL, NULL, NULL,
                                                   NULL);
                x_modifier_line_tbl (l_cnt).list_header_id       :=
                    k.list_header_id;
                x_modifier_line_tbl (l_cnt).list_line_id         :=
                    k.list_line_id;
                x_modifier_line_tbl (l_cnt).modifier_number      :=
                    k.modifier_number;
                x_modifier_line_tbl (l_cnt).modifier_name        :=
                    k.modifier_name;
                x_modifier_line_tbl (l_cnt).modifier_level       :=
                    k.modifier_level;
                x_modifier_line_tbl (l_cnt).list_line_type       :=
                    k.list_line_type;
                x_modifier_line_tbl (l_cnt).application_method   :=
                    k.application_method;
                x_modifier_line_tbl (l_cnt).rate                 := k.rate;
                x_modifier_line_tbl (l_cnt).adjusted_amount      :=
                    k.adjusted_amount;
                x_modifier_line_tbl (l_cnt).extended_adjusted_amount   :=
                    k.extended_adjusted_amount;
                x_modifier_line_tbl (l_cnt).automatic_flag       :=
                    k.automatic_flag;
                x_modifier_line_tbl (l_cnt).list_line_number     :=
                    k.list_line_number;
                x_modifier_line_tbl (l_cnt).override_allowed_flag   :=
                    k.override_allowed_flag;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN ex_exception
        THEN
            x_error_flag      := 'E';
            x_error_message   := lc_error_msg;
        WHEN OTHERS
        THEN
            x_error_flag      := 'E';
            x_error_message   := SUBSTR (SQLERRM, 1, 1500);
    END get_line_price_adj_details;

    PROCEDURE apply_line_price_adjustment (p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER
                                           , p_price_adjment_tbl IN xxd_doe_price_adjtmnt_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        ln_list_header_id              NUMBER;
        ln_list_line_id                NUMBER;
        lc_operand                     VARCHAR2 (100);
        ln_line_type_code              VARCHAR2 (100);
        lc_operator                    VARCHAR2 (100);
        ln_phase_id                    NUMBER;
        lc_mod_level_code              VARCHAR2 (100);
        ln_line_id                     NUMBER;
        ln_header_id                   NUMBER;
        ln_org_id                      NUMBER;
        lc_error_message               VARCHAR2 (4000);
        ln_msg_index_out               NUMBER;
        -- Process Order API IN OUT parameters start ----
        l_header_rec                   oe_order_pub.header_rec_type;
        l_out_header_rec               oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_out_line_tbl                 oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               oe_order_pub.header_scredit_tbl_type;
        l_request_rec                  oe_order_pub.request_rec_type;
        l_out_return_status            VARCHAR2 (1000);
        l_out_msg_count                NUMBER;
        l_out_msg_data                 VARCHAR2 (1000);
        l_out_header_val_rec           oe_order_pub.header_val_rec_type;
        l_out_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        l_out_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        l_out_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        l_out_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        l_out_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        l_out_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        l_out_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        l_out_line_val_tbl             oe_order_pub.line_val_tbl_type;
        l_out_line_adj_out_tbl         oe_order_pub.line_adj_tbl_type;
        l_out_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        l_out_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        l_out_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        l_out_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        l_out_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        l_out_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        l_out_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        l_out_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        l_out_action_request_tbl       oe_order_pub.request_tbl_type;
    -- Process Order API IN OUT parameters END ----
    BEGIN
        FOR i IN 1 .. p_price_adjment_tbl.COUNT
        LOOP
            -- Fetch Values from Discount Modifier Defined.
            SELECT lin.list_header_id, lin.list_line_id, lin.operand,
                   lin.list_line_type_code, lin.arithmetic_operator, lin.pricing_phase_id,
                   lin.modifier_level_code
              INTO ln_list_header_id, ln_list_line_id, lc_operand, ln_line_type_code,
                                    lc_operator, ln_phase_id, lc_mod_level_code
              FROM qpfv_modifier_lines lin
             WHERE lin.list_line_id =
                   p_price_adjment_tbl (i).modifier_list_line_id;

            -- Fetch Values from Order Line.
            SELECT line_id, header_id, org_id
              INTO ln_line_id, ln_header_id, ln_org_id
              FROM oe_order_lines_all
             WHERE line_id = p_price_adjment_tbl (i).order_line_id;

            fnd_global.apps_initialize (user_id        => p_user_id,
                                        resp_id        => p_resp_id,
                                        resp_appl_id   => p_resp_appl_id);
            mo_global.set_policy_context ('S', ln_org_id);


            --POPULATE LINE ATTRIBUTE
            IF p_price_adjment_tbl (i).price_adjustment_id IS NULL
            THEN
                l_line_adj_tbl (i).operation   := oe_globals.g_opr_create;
                l_line_adj_tbl (i).price_adjustment_id   :=
                    oe_price_adjustments_s.NEXTVAL;
            ELSE
                l_line_adj_tbl (i).operation   := oe_globals.g_opr_update;
                l_line_adj_tbl (i).price_adjustment_id   :=
                    p_price_adjment_tbl (i).price_adjustment_id;
            END IF;

            l_line_adj_tbl (i).creation_date           := SYSDATE;
            l_line_adj_tbl (i).created_by              := fnd_global.user_id;
            l_line_adj_tbl (i).last_update_date        := SYSDATE;
            l_line_adj_tbl (i).last_updated_by         := fnd_global.user_id;
            l_line_adj_tbl (i).last_update_login       := fnd_global.login_id;
            l_line_adj_tbl (i).header_id               := ln_header_id;
            ------------------- PASS HEADER ID
            l_line_adj_tbl (i).line_id                 := ln_line_id;
            ----------------------- PASS LINE ID
            l_line_adj_tbl (i).automatic_flag          := 'N';
            l_line_adj_tbl (i).orig_sys_discount_ref   :=
                'OE_PRICE_ADJUSTMENTS' || 1;
            l_line_adj_tbl (i).list_header_id          := ln_list_header_id;
            l_line_adj_tbl (i).list_line_id            := ln_list_line_id;
            l_line_adj_tbl (i).list_line_type_code     := ln_line_type_code;
            l_line_adj_tbl (i).update_allowed          := 'Y';
            l_line_adj_tbl (i).updated_flag            := 'Y';
            l_line_adj_tbl (i).applied_flag            := 'Y';
            l_line_adj_tbl (i).operand                 :=
                p_price_adjment_tbl (i).operand;
            l_line_adj_tbl (i).arithmetic_operator     := lc_operator;
            -- l_line_adj_tbl(1).adjusted_amount := -lc_operand;
            l_line_adj_tbl (i).pricing_phase_id        := ln_phase_id;
            l_line_adj_tbl (i).accrual_flag            := 'N';
            l_line_adj_tbl (i).list_line_no            := ln_list_line_id;
            l_line_adj_tbl (i).source_system_code      := 'QP';
            l_line_adj_tbl (i).modifier_level_code     := lc_mod_level_code;
            l_line_adj_tbl (i).proration_type_code     := 'N';
            l_line_adj_tbl (i).operand_per_pqty        :=
                p_price_adjment_tbl (i).operand;
            -- l_line_adj_tbl(1).adjusted_amount_per_pqty := -lc_operand;
            l_line_adj_tbl (i).change_reason_code      :=
                p_price_adjment_tbl (i).reason_code;
            l_line_adj_tbl (i).change_reason_text      :=
                p_price_adjment_tbl (i).reason_text;
        END LOOP;

        mo_global.init ('ONT');
        oe_order_pub.process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_false,
            p_return_values            => fnd_api.g_false,
            p_action_commit            => fnd_api.g_true,
            x_return_status            => l_out_return_status,
            x_msg_count                => l_out_msg_count,
            x_msg_data                 => l_out_msg_data,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_line_adj_tbl             => l_line_adj_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            -- OUT PARAMETERS
            x_header_rec               => l_out_header_rec,
            x_header_val_rec           => l_out_header_val_rec,
            x_header_adj_tbl           => l_out_header_adj_tbl,
            x_header_adj_val_tbl       => l_out_header_adj_val_tbl,
            x_header_price_att_tbl     => l_out_header_price_att_tbl,
            x_header_adj_att_tbl       => l_out_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => l_out_header_adj_assoc_tbl,
            x_header_scredit_tbl       => l_out_header_scredit_tbl,
            x_header_scredit_val_tbl   => l_out_header_scredit_val_tbl,
            x_line_tbl                 => l_out_line_tbl,
            x_line_val_tbl             => l_out_line_val_tbl,
            x_line_adj_tbl             => l_out_line_adj_out_tbl,
            x_line_adj_val_tbl         => l_out_line_adj_val_tbl,
            x_line_price_att_tbl       => l_out_line_price_att_tbl,
            x_line_adj_att_tbl         => l_out_line_adj_att_tbl,
            x_line_adj_assoc_tbl       => l_out_line_adj_assoc_tbl,
            x_line_scredit_tbl         => l_out_line_scredit_tbl,
            x_line_scredit_val_tbl     => l_out_line_scredit_val_tbl,
            x_lot_serial_tbl           => l_out_lot_serial_tbl,
            x_lot_serial_val_tbl       => l_out_lot_serial_val_tbl,
            x_action_request_tbl       => l_out_action_request_tbl);

        IF l_out_return_status = fnd_api.g_ret_sts_success
        THEN
            x_error_flag       := 'S';
            lc_error_message   := 'Price Adjustment/s Applied successfully.';
            COMMIT;
        ELSE
            x_error_flag   := 'E';
            lc_error_message   :=
                'Failed To Applying Price List Adjustment For Line : ';

            /* FOR i IN 1 .. l_out_msg_count
             LOOP
                fnd_msg_pub.get (i,
                                 fnd_api.g_false,
                                 l_out_msg_data,
                                 ln_msg_index_out
                                );
                lc_error_message :=
                        lc_error_message
                        || (TO_CHAR (i) || ': ' || l_out_msg_data);
             END LOOP;*/

            FOR i IN 1 .. l_out_msg_count
            LOOP
                Oe_Msg_Pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_out_msg_data
                                , p_msg_index_out => ln_msg_index_out);
                --    DBMS_OUTPUT.PUT_LINE('message is: ' || l_out_msg_data);
                --    DBMS_OUTPUT.PUT_LINE('message index is: ' || ln_msg_index_out);
                lc_error_message   :=
                       lc_error_message
                    || (TO_CHAR (i) || ': ' || l_out_msg_data);
            END LOOP;

            ROLLBACK;
        END IF;

        x_error_message   := lc_error_message;
    END apply_line_price_adjustment;

    PROCEDURE apply_header_price_adjustment (p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER
                                             , p_price_adjment_tbl IN xxd_doe_price_adjtmnt_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        ln_list_header_id              NUMBER;
        ln_list_line_id                NUMBER;
        lc_operand                     VARCHAR2 (100);
        ln_line_type_code              VARCHAR2 (100);
        lc_operator                    VARCHAR2 (100);
        ln_phase_id                    NUMBER;
        lc_mod_level_code              VARCHAR2 (100);
        ln_org_id                      NUMBER;
        ln_order_number                NUMBER;
        lc_error_message               VARCHAR2 (4000);
        ln_msg_index_out               NUMBER;
        -- Process Order API IN OUT parameters start ----
        l_header_rec                   oe_order_pub.header_rec_type;
        l_out_header_rec               oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_out_line_tbl                 oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               oe_order_pub.header_scredit_tbl_type;
        l_request_rec                  oe_order_pub.request_rec_type;
        l_out_return_status            VARCHAR2 (1000);
        l_out_msg_count                NUMBER;
        l_out_msg_data                 VARCHAR2 (1000);
        l_out_header_val_rec           oe_order_pub.header_val_rec_type;
        l_out_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        l_out_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        l_out_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        l_out_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        l_out_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        l_out_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        l_out_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        l_out_line_val_tbl             oe_order_pub.line_val_tbl_type;
        l_out_line_adj_out_tbl         oe_order_pub.line_adj_tbl_type;
        l_out_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        l_out_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        l_out_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        l_out_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        l_out_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        l_out_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        l_out_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        l_out_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        l_out_action_request_tbl       oe_order_pub.request_tbl_type;
        l_accural_flag                 VARCHAR (5);
    -- Process Order API IN OUT parameters END ----
    BEGIN
        FOR i IN 1 .. p_price_adjment_tbl.COUNT
        LOOP
            -- Fetch Values from Discount Modifier Defined.
            SELECT lin.list_header_id, lin.list_line_id, lin.operand,
                   lin.list_line_type_code, lin.arithmetic_operator, lin.pricing_phase_id,
                   lin.modifier_level_code, lin.accrual_flag
              INTO ln_list_header_id, ln_list_line_id, lc_operand, ln_line_type_code,
                                    lc_operator, ln_phase_id, lc_mod_level_code,
                                    l_accural_flag
              FROM qpfv_modifier_lines lin
             WHERE lin.list_line_id =
                   p_price_adjment_tbl (i).modifier_list_line_id;

            -- Fetch Values from Order Line.
            SELECT org_id, order_number
              INTO ln_org_id, ln_order_number
              FROM oe_order_headers_all
             WHERE header_id = p_price_adjment_tbl (i).order_header_id;

            fnd_global.apps_initialize (user_id        => p_user_id,
                                        resp_id        => p_resp_id,
                                        resp_appl_id   => p_resp_appl_id);
            mo_global.set_policy_context ('S', ln_org_id);

            --POPULATE LINE ATTRIBUTE
            IF p_price_adjment_tbl (i).price_adjustment_id IS NULL
            THEN
                l_header_adj_tbl (i).operation   := oe_globals.g_opr_create;
                l_header_adj_tbl (i).price_adjustment_id   :=
                    oe_price_adjustments_s.NEXTVAL;
            ELSE
                l_header_adj_tbl (i).operation   := oe_globals.g_opr_update;
                l_header_adj_tbl (i).price_adjustment_id   :=
                    p_price_adjment_tbl (i).price_adjustment_id;
            END IF;

            l_header_adj_tbl (i).creation_date         := SYSDATE;
            l_header_adj_tbl (i).created_by            := fnd_global.user_id;
            l_header_adj_tbl (i).last_update_date      := SYSDATE;
            l_header_adj_tbl (i).last_updated_by       := fnd_global.user_id;
            l_header_adj_tbl (i).last_update_login     := fnd_global.login_id;
            l_header_adj_tbl (i).header_id             :=
                p_price_adjment_tbl (i).order_header_id;
            ------------------- PASS HEADER ID
            l_header_adj_tbl (i).automatic_flag        := 'N';
            --l_header_adj_tbl(1).orig_sys_discount_ref := 'OE_PRICE_ADJUSTMENTS' || 1;
            l_header_adj_tbl (i).list_header_id        := ln_list_header_id;
            l_header_adj_tbl (i).list_line_id          := ln_list_line_id;
            l_header_adj_tbl (i).list_line_type_code   := ln_line_type_code;
            l_header_adj_tbl (i).update_allowed        := 'Y';
            l_header_adj_tbl (i).updated_flag          := 'Y';
            l_header_adj_tbl (i).applied_flag          := 'Y';
            l_header_adj_tbl (i).operand               :=
                p_price_adjment_tbl (i).operand;
            l_header_adj_tbl (i).arithmetic_operator   := lc_operator;
            --l_header_adj_tbl (1).adjusted_amount := -lc_operand;
            l_header_adj_tbl (i).pricing_phase_id      := ln_phase_id;
            l_header_adj_tbl (i).accrual_flag          := l_accural_flag;
            l_header_adj_tbl (i).list_line_no          := ln_list_line_id;
            l_header_adj_tbl (i).source_system_code    := 'QP';
            l_header_adj_tbl (i).modifier_level_code   := lc_mod_level_code;
            l_header_adj_tbl (i).proration_type_code   := 'N';
            l_header_adj_tbl (i).operand_per_pqty      :=
                p_price_adjment_tbl (i).operand;
            --l_header_adj_tbl (1).adjusted_amount_per_pqty := -lc_operand;
            l_header_adj_tbl (i).change_reason_code    :=
                p_price_adjment_tbl (i).reason_code;
            l_header_adj_tbl (i).change_reason_text    :=
                p_price_adjment_tbl (i).reason_text;
        --l_header_adj_tbl(1).price_break_type_code := 'POINT';
        END LOOP;

        mo_global.init ('ONT');
        oe_order_pub.process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_false,
            p_return_values            => fnd_api.g_false,
            p_action_commit            => fnd_api.g_false,
            x_return_status            => l_out_return_status,
            x_msg_count                => l_out_msg_count,
            x_msg_data                 => l_out_msg_data,
            p_header_rec               => l_header_rec,
            p_header_adj_tbl           => l_header_adj_tbl,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            -- OUT PARAMETERS
            x_header_rec               => l_out_header_rec,
            x_header_val_rec           => l_out_header_val_rec,
            x_header_adj_tbl           => l_out_header_adj_tbl,
            x_header_adj_val_tbl       => l_out_header_adj_val_tbl,
            x_header_price_att_tbl     => l_out_header_price_att_tbl,
            x_header_adj_att_tbl       => l_out_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => l_out_header_adj_assoc_tbl,
            x_header_scredit_tbl       => l_out_header_scredit_tbl,
            x_header_scredit_val_tbl   => l_out_header_scredit_val_tbl,
            x_line_tbl                 => l_out_line_tbl,
            x_line_val_tbl             => l_out_line_val_tbl,
            x_line_adj_tbl             => l_out_line_adj_out_tbl,
            x_line_adj_val_tbl         => l_out_line_adj_val_tbl,
            x_line_price_att_tbl       => l_out_line_price_att_tbl,
            x_line_adj_att_tbl         => l_out_line_adj_att_tbl,
            x_line_adj_assoc_tbl       => l_out_line_adj_assoc_tbl,
            x_line_scredit_tbl         => l_out_line_scredit_tbl,
            x_line_scredit_val_tbl     => l_out_line_scredit_val_tbl,
            x_lot_serial_tbl           => l_out_lot_serial_tbl,
            x_lot_serial_val_tbl       => l_out_lot_serial_val_tbl,
            x_action_request_tbl       => l_out_action_request_tbl);

        IF l_out_return_status = fnd_api.g_ret_sts_success
        THEN
            x_error_flag       := 'S';
            lc_error_message   := 'Price Adjustment/s Applied successfully.';
            COMMIT;
        ELSE
            x_error_flag   := 'E';
            lc_error_message   :=
                'Failed To Applying Price List Adjustment For Order : ';

            FOR i IN 1 .. l_out_msg_count
            LOOP
                fnd_msg_pub.get (i, fnd_api.g_false, l_out_msg_data,
                                 ln_msg_index_out);
                lc_error_message   :=
                       lc_error_message
                    || (TO_CHAR (i) || ': ' || l_out_msg_data);
            END LOOP;

            ROLLBACK;
        END IF;

        x_error_message   := lc_error_message;
    END apply_header_price_adjustment;

    PROCEDURE delete_order_price_adjustment (p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER
                                             , p_price_adjment_tbl IN xxd_doe_price_adjtmnt_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        ln_list_header_id              NUMBER;
        ln_list_line_id                NUMBER;
        lc_operand                     VARCHAR2 (100);
        ln_line_type_code              VARCHAR2 (100);
        lc_operator                    VARCHAR2 (100);
        ln_phase_id                    NUMBER;
        lc_mod_level_code              VARCHAR2 (100);
        ln_line_id                     NUMBER;
        ln_header_id                   NUMBER;
        ln_org_id                      NUMBER;
        lc_error_message               VARCHAR2 (4000);
        ln_msg_index_out               NUMBER;
        -- Process Order API IN OUT parameters start ----
        l_header_rec                   oe_order_pub.header_rec_type;
        l_out_header_rec               oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_out_line_tbl                 oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_header_adj_tbl               oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl               oe_order_pub.header_scredit_tbl_type;
        l_request_rec                  oe_order_pub.request_rec_type;
        l_out_return_status            VARCHAR2 (1000);
        l_out_msg_count                NUMBER;
        l_out_msg_data                 VARCHAR2 (1000);
        l_out_header_val_rec           oe_order_pub.header_val_rec_type;
        l_out_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        l_out_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        l_out_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        l_out_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        l_out_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        l_out_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        l_out_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        l_out_line_val_tbl             oe_order_pub.line_val_tbl_type;
        l_out_line_adj_out_tbl         oe_order_pub.line_adj_tbl_type;
        l_out_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        l_out_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        l_out_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        l_out_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        l_out_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        l_out_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        l_out_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        l_out_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        l_out_action_request_tbl       oe_order_pub.request_tbl_type;
        l_accural_flag                 VARCHAR (5);
    -- Process Order API IN OUT parameters END ----
    BEGIN
        FOR i IN 1 .. p_price_adjment_tbl.COUNT
        LOOP
            SELECT lin.list_header_id, lin.list_line_id, lin.operand,
                   lin.list_line_type_code, lin.arithmetic_operator, lin.pricing_phase_id,
                   lin.modifier_level_code, lin.accrual_flag
              INTO ln_list_header_id, ln_list_line_id, lc_operand, ln_line_type_code,
                                    lc_operator, ln_phase_id, lc_mod_level_code,
                                    l_accural_flag
              FROM qpfv_modifier_lines lin
             WHERE lin.list_line_id =
                   p_price_adjment_tbl (i).modifier_list_line_id;

            IF (p_price_adjment_tbl (i).Adjustment_level = 'LINE')
            THEN
                -- Fetch Values from Order Line.
                SELECT line_id, header_id, org_id
                  INTO ln_line_id, ln_header_id, ln_org_id
                  FROM oe_order_lines_all
                 WHERE line_id = p_price_adjment_tbl (i).order_line_id;

                fnd_global.apps_initialize (user_id        => p_user_id,
                                            resp_id        => p_resp_id,
                                            resp_appl_id   => p_resp_appl_id);
                mo_global.set_policy_context ('S', ln_org_id);
                --POPULATE LINE ATTRIBUTE
                l_line_adj_tbl (i).operation             := oe_globals.g_opr_delete;
                l_line_adj_tbl (i).price_adjustment_id   :=
                    p_price_adjment_tbl (i).price_adjustment_id;
                l_line_adj_tbl (i).header_id             :=
                    p_price_adjment_tbl (i).order_header_id;
                l_line_adj_tbl (i).line_id               :=
                    p_price_adjment_tbl (i).order_line_id;
                l_line_adj_tbl (i).creation_date         := SYSDATE;
                l_line_adj_tbl (i).created_by            :=
                    fnd_global.user_id;
                l_line_adj_tbl (i).last_update_date      := SYSDATE;
                l_line_adj_tbl (i).last_updated_by       :=
                    fnd_global.user_id;
                l_line_adj_tbl (i).last_update_login     :=
                    fnd_global.login_id;
                l_line_adj_tbl (i).list_header_id        := ln_list_header_id;
                l_line_adj_tbl (i).list_line_id          := ln_list_line_id;
                l_line_adj_tbl (i).list_line_type_code   := ln_line_type_code;
                l_line_adj_tbl (i).update_allowed        := 'Y';
                l_line_adj_tbl (i).updated_flag          := 'Y';
                l_line_adj_tbl (i).applied_flag          := 'Y';
                l_line_adj_tbl (i).operand               :=
                    p_price_adjment_tbl (i).operand;
                l_line_adj_tbl (i).arithmetic_operator   := lc_operator;
                --l_header_adj_tbl (1).adjusted_amount := -lc_operand;
                l_line_adj_tbl (i).pricing_phase_id      := ln_phase_id;
                l_line_adj_tbl (i).accrual_flag          := l_accural_flag;
                l_line_adj_tbl (i).list_line_no          := ln_list_line_id;
                l_line_adj_tbl (i).source_system_code    := 'QP';
                l_line_adj_tbl (i).modifier_level_code   := lc_mod_level_code;
                l_line_adj_tbl (i).proration_type_code   := 'N';
            ELSE
                SELECT org_id
                  INTO ln_org_id
                  FROM oe_order_headers_all
                 WHERE header_id = p_price_adjment_tbl (i).order_header_id;

                fnd_global.apps_initialize (user_id        => p_user_id,
                                            resp_id        => p_resp_id,
                                            resp_appl_id   => p_resp_appl_id);
                mo_global.set_policy_context ('S', ln_org_id);
                --POPULATE LINE ATTRIBUTE
                l_header_adj_tbl (i).operation             := oe_globals.g_opr_delete;
                l_header_adj_tbl (i).price_adjustment_id   :=
                    p_price_adjment_tbl (i).price_adjustment_id;
                l_header_adj_tbl (i).header_id             :=
                    p_price_adjment_tbl (i).order_header_id;
                l_header_adj_tbl (i).creation_date         := SYSDATE;
                l_header_adj_tbl (i).created_by            :=
                    fnd_global.user_id;
                l_header_adj_tbl (i).last_update_date      := SYSDATE;
                l_header_adj_tbl (i).last_updated_by       :=
                    fnd_global.user_id;
                l_header_adj_tbl (i).last_update_login     :=
                    fnd_global.login_id;
                l_header_adj_tbl (i).list_header_id        :=
                    ln_list_header_id;
                l_header_adj_tbl (i).list_line_id          := ln_list_line_id;
                l_header_adj_tbl (i).list_line_type_code   :=
                    ln_line_type_code;
                l_header_adj_tbl (i).update_allowed        := 'Y';
                l_header_adj_tbl (i).updated_flag          := 'Y';
                l_header_adj_tbl (i).applied_flag          := 'Y';
                l_header_adj_tbl (i).operand               :=
                    p_price_adjment_tbl (i).operand;
                l_header_adj_tbl (i).arithmetic_operator   := lc_operator;
                --l_header_adj_tbl (1).adjusted_amount := -lc_operand;
                l_header_adj_tbl (i).pricing_phase_id      := ln_phase_id;
                l_header_adj_tbl (i).accrual_flag          := l_accural_flag;
                l_header_adj_tbl (i).list_line_no          := ln_list_line_id;
                l_header_adj_tbl (i).source_system_code    := 'QP';
                l_header_adj_tbl (i).modifier_level_code   :=
                    lc_mod_level_code;
                l_header_adj_tbl (i).proration_type_code   := 'N';
            /* l_header_adj_tbl(i).operand_per_pqty := p_price_adjment_tbl(i).operand;
             --l_header_adj_tbl (1).adjusted_amount_per_pqty := -lc_operand;
             l_header_adj_tbl(i).change_reason_code := p_price_adjment_tbl(i).reason_code;
             l_header_adj_tbl(i).change_reason_text := p_price_adjment_tbl(i).reason_text;*/

            END IF;
        END LOOP;

        mo_global.init ('ONT');
        oe_order_pub.process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_false,
            p_return_values            => fnd_api.g_false,
            p_action_commit            => fnd_api.g_false,
            x_return_status            => l_out_return_status,
            x_msg_count                => l_out_msg_count,
            x_msg_data                 => l_out_msg_data,
            p_header_rec               => l_header_rec,
            p_header_adj_tbl           => l_header_adj_tbl,
            p_line_tbl                 => l_line_tbl,
            p_line_adj_tbl             => l_line_adj_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            -- OUT PARAMETERS
            x_header_rec               => l_out_header_rec,
            x_header_val_rec           => l_out_header_val_rec,
            x_header_adj_tbl           => l_out_header_adj_tbl,
            x_header_adj_val_tbl       => l_out_header_adj_val_tbl,
            x_header_price_att_tbl     => l_out_header_price_att_tbl,
            x_header_adj_att_tbl       => l_out_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => l_out_header_adj_assoc_tbl,
            x_header_scredit_tbl       => l_out_header_scredit_tbl,
            x_header_scredit_val_tbl   => l_out_header_scredit_val_tbl,
            x_line_tbl                 => l_out_line_tbl,
            x_line_val_tbl             => l_out_line_val_tbl,
            x_line_adj_tbl             => l_out_line_adj_out_tbl,
            x_line_adj_val_tbl         => l_out_line_adj_val_tbl,
            x_line_price_att_tbl       => l_out_line_price_att_tbl,
            x_line_adj_att_tbl         => l_out_line_adj_att_tbl,
            x_line_adj_assoc_tbl       => l_out_line_adj_assoc_tbl,
            x_line_scredit_tbl         => l_out_line_scredit_tbl,
            x_line_scredit_val_tbl     => l_out_line_scredit_val_tbl,
            x_lot_serial_tbl           => l_out_lot_serial_tbl,
            x_lot_serial_val_tbl       => l_out_lot_serial_val_tbl,
            x_action_request_tbl       => l_out_action_request_tbl);

        IF l_out_return_status = fnd_api.g_ret_sts_success
        THEN
            x_error_flag       := 'S';
            lc_error_message   := 'Price Adjustment is deleted Successfully';
            COMMIT;
        ELSE
            x_error_flag       := 'E';
            lc_error_message   := 'Failed To delete Price Adjustment : ';

            FOR i IN 1 .. l_out_msg_count
            LOOP
                fnd_msg_pub.get (i, fnd_api.g_false, l_out_msg_data,
                                 ln_msg_index_out);
                lc_error_message   :=
                       lc_error_message
                    || (TO_CHAR (i) || ': ' || l_out_msg_data);
            END LOOP;



            ROLLBACK;
        END IF;

        x_error_message   := lc_error_message;
    END delete_order_price_adjustment;
END xxd_sales_order_pkg;
/
