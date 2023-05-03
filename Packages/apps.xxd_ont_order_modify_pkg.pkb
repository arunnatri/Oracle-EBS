--
-- XXD_ONT_ORDER_MODIFY_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_ORDER_MODIFY_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_ORDER_MODIFY_PKG
    * Design       : This package will be used for modifying the Sales Orders.
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 30-Mar-2020  1.0        Viswanathan Pandian     Initial Version
    --  29-Mar-2020 1.1        Gaurav Joshi            CCR0009171 Changes
    -- 09-Apr-2020  2.0        Balavenu                CCR0008870 GSA Project
    -- 01-Sep-2021  2.1        Laltu                   CCR0009521 VAS Code Update
    -- 21-sep-2021  2.2        Gaurav Joshi            CCR0009617 -Auto Split line/copy attachment and copy att16
    -- 01-Nov-2021  2.3        Gaurav Joshi            CCR0009674 - Order source as Copy for SOMT orders
    -- 04-Jan-2021  2.4        Gaurav Joshi            CCR0009738 - Mutiple changes
    -- 10-Jan-2022  2.5        Gaurav Joshi            CCR0009764  - Batching logic correction
    -- 10-Jan-2022  2.6        Gaurav Joshi            CCR0009772 - Mass Hold apply - order date,Pricing date
    -- 28-Mar-2022  2.7        Gaurav JOshi            CCR0009847 - performance fix
    -- 24-Apr-2022  2.8        Gaurav Joshi            CCR0009334- Amazon 855
    -- 29-Jun-2022  2.9        Gaurav joshi            CCR0010059 - CD/LAD update
    -- 15-Aug-2022  2.10       Gaurav Joshi            CCR0010127 - sku validation
    -- 01-Oct-2022  1.17       Pardeep Rohilla         CCR0010163 - Update Sales Order Cust_PO_Number
    -- 12-Dec-2022  2.11       Gaurav Joshi            CCR0010360  - PDCTOM-291 - SOMT for Mass Units release to ATP
    -- 09-Feb-2023  2.12       Gaurav Joshi            CCR  - Fix RD/CD/LAD update issue when qty is null
    -- 14-MAR-2023  2.13       Srinath Siricilla       CCR0010520 - PDCTOM-653 - SOMT Table needs record_id Column for GG replication
    ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    -- Modifed to init G variable from input params
    -- context : XXD_ONT_APPLY_HOLD
    -- Attribute14 hold id
    -- Attribute13 action
    -- context: XXD_ONT_CANCEL
    --  Attribute15 CANCEL ENTIRE ORDER FLAG
    -- Attribute14 CANCEL UNSCHLD LINES FLAG
    -- Attribute13 RESEND855 FLAG
    -- Attribute12  p_freeAtp_flag
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
        --IF gc_debug_enable = 'Y'
        --THEN
        fnd_file.put_line (fnd_file.LOG, p_msg);
    --END IF;
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
        debug_msg ('Initializing');
        mo_global.init ('ONT');
        oe_msg_pub.delete_msg;
        oe_msg_pub.initialize;
        mo_global.set_policy_context ('S', gn_org_id);
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_responsibility_id,
                                    resp_appl_id   => gn_application_id);
        debug_msg ('Org ID = ' || gn_org_id);
        debug_msg ('User ID = ' || gn_user_id);
        debug_msg ('Responsibility ID = ' || gn_responsibility_id);
        debug_msg ('Application ID = ' || gn_application_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in INIT = ' || SQLERRM);
    END init;

    -- begin  ver 2.7
    PROCEDURE validate_line (p_group_id IN NUMBER, p_batch_id IN NUMBER)
    AS
        l_count               NUMBER;

        CURSOR cur_val IS
            SELECT a.ROWID rwid, source_order_number order_number, source_line_number line_number,
                   source_ordered_item sku, target_ordered_quantity quantity, TARGET_LATEST_ACCEPTABLE_DATE lap,
                   target_line_cancel_date cancel_date, target_line_request_date request_date, attribute3
              FROM xxd_ont_order_modify_details_t a
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND NVL (attribute4, 'N') = 'Y';

        ln_line_num           NUMBER := 0;
        l_oe_header_id        NUMBER;
        l_ship_from_org_id    NUMBER;
        l_line_id             NUMBER;
        l_status              VARCHAR2 (1) := 'N';
        l_error_message       VARCHAR2 (4000);
        lv_open_flag          VARCHAR2 (10);
        l_inventory_item_id   NUMBER;
        l_request_date        DATE;
        l_lap                 DATE;
        l_cancel_date         DATE;
        l_brand               VARCHAR2 (100);
    BEGIN
        FOR i IN cur_val
        LOOP
            ln_line_num           := ln_line_num + 1;
            l_status              := 'N';
            l_error_message       := NULL;
            l_oe_header_id        := NULL;
            l_ship_from_org_id    := NULL;
            l_line_id             := NULL;
            l_inventory_item_id   := NULL;
            lv_open_flag          := NULL;
            l_request_date        := NULL;
            l_lap                 := NULL;
            l_cancel_date         := NULL;

            BEGIN
                SELECT ooh.header_id, ooh.ship_from_org_id, attribute5
                  INTO l_oe_header_id, l_ship_from_org_id, l_brand -- ver 2.10
                  FROM oe_order_headers_all ooh
                 WHERE ooh.order_number = i.order_number AND ROWNUM = 1;

                IF (i.line_number IS NULL)
                THEN
                    l_line_id   := NULL;
                ELSE
                    BEGIN
                        SELECT line_id, open_flag
                          INTO l_line_id, lv_open_flag
                          FROM oe_order_lines_all
                         WHERE     header_id = l_oe_header_id
                               AND line_number || '.' || shipment_number =
                                   i.line_number;

                        IF (lv_open_flag <> 'Y')
                        THEN
                            l_status   := 'E';
                            l_error_message   :=
                                   l_error_message
                                || ' Line not in Open Status '
                                || i.line_number
                                || ' ; ';
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_status   := 'E';
                            l_error_message   :=
                                   l_error_message
                                || '  Invalid Line Number '
                                || i.line_number
                                || ' ; ';
                    END;
                END IF;

                BEGIN
                    /* begin ver 2.10
                    SELECT inventory_item_id
                      INTO l_inventory_item_id
                      FROM mtl_system_items_b
                     WHERE     segment1 = i.sku
                           AND organization_id = l_ship_from_org_id;
         */
                    SELECT inventory_item_id
                      INTO l_inventory_item_id
                      FROM xxd_common_items_v
                     WHERE     1 = 1
                           AND organization_id = l_ship_from_org_id
                           AND brand = l_brand
                           AND item_number = i.sku;
                -- end 2.10
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_status   := 'E';
                        l_error_message   :=
                               l_error_message
                            || '  Invalid SKU '
                            || i.sku
                            || ' ; ';
                END;

                /* begin ver 2.10
                IF (i.quantity IS NULL)
                THEN
                    l_status := 'E';
                    l_error_message :=
                        l_error_message || ' Provide Quantity value ; ';
                END IF;
    end ver 2.10 */

                IF (i.quantity IS NOT NULL)
                THEN
                    IF (REGEXP_LIKE (i.quantity, '^[0-9]+$'))
                    THEN
                        NULL;
                    ELSE
                        l_status   := 'E';
                        l_error_message   :=
                            l_error_message || ' Invalid Quantity ; ';
                    END IF;
                END IF;

                IF (i.request_date IS NOT NULL)
                THEN
                    BEGIN
                        l_request_date   :=
                            TO_DATE (i.request_date, 'DD-Mon-YY');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_status          := 'E';
                            l_error_message   :=
                                   l_error_message
                                || ' Invalid Request Date(DD-MM-YY) ; '
                                || i.request_date;

                            l_request_date    := NULL;
                    END;
                END IF;

                IF (i.lap IS NOT NULL)
                THEN
                    BEGIN
                        l_lap   := TO_DATE (i.lap, 'DD-Mon-YY');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_status          := 'E';
                            l_error_message   :=
                                   l_error_message
                                || ' Invalid Latest Acceptable Date(DD-Mon-YY) ; '
                                || i.lap;

                            l_lap             := NULL;
                    END;
                END IF;

                IF (i.cancel_date IS NOT NULL)
                THEN
                    BEGIN
                        l_cancel_date   :=
                            TO_DATE (i.cancel_date, 'DD-Mon-YY');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_status          := 'E';
                            l_error_message   :=
                                   l_error_message
                                || ' Invalid Cancel Date(DD-Mon-YY) ; '
                                || i.cancel_date;

                            l_cancel_date     := NULL;
                    END;
                END IF;

                IF (i.lap IS NULL)
                THEN
                    NULL;
                ELSE
                    IF (i.request_date IS NOT NULL)
                    THEN
                        IF (TO_DATE (i.request_date, 'DD-Mon-YY') > TO_DATE (i.lap, 'DD-Mon-YY'))
                        THEN
                            l_status   := 'E';
                            l_error_message   :=
                                   l_error_message
                                || ' Latest Acceptable Date should be greater than Request Date ; ';
                        END IF;
                    END IF;
                END IF;

                IF (i.cancel_date IS NULL)
                THEN
                    NULL;
                ELSE
                    IF (i.request_date IS NOT NULL)
                    THEN
                        IF (TO_DATE (i.request_date, 'DD-Mon-YY') > TO_DATE (i.cancel_date, 'DD-Mon-YY'))
                        THEN
                            l_status   := 'E';
                            l_error_message   :=
                                   l_error_message
                                || ' Cancel Date should be greater than Request Date ; '
                                || i.request_date
                                || ' '
                                || i.cancel_date;
                        END IF;
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_status          := 'E';
                    l_error_message   := 'Order Number Invalid ' || SQLERRM;
            END;

            UPDATE xxd_ont_order_modify_details_t a
               SET status = l_status, error_message = l_error_message, source_header_id = l_oe_header_id,
                   source_line_id = l_line_id, target_inventory_item_id = l_inventory_item_id
             WHERE     1 = 1
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND NVL (attribute4, 'N') = 'Y'
                   AND attribute3 = i.attribute3
                   AND ROWID = i.rwid;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
    END validate_line;


    PROCEDURE validate_line_bulk (p_group_id IN NUMBER, p_batch_id IN NUMBER)
    AS
        l_count        NUMBER;

        CURSOR cur_val IS
            SELECT a.ROWID rwid, source_order_number order_number, source_line_number line_number,
                   source_ordered_item sku, target_ordered_quantity quantity, TARGET_LATEST_ACCEPTABLE_DATE lap,
                   target_line_cancel_date cancel_date, target_line_request_date request_date, NULL status,
                   NULL erg_msg, NULL oe_header_id, NULL inventory_item_id,
                   NULL ship_from_org_id, NULL line_id, NULL line_num
              FROM xxd_ont_order_modify_details_t a
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND NVL (attribute4, 'N') = 'Y';

        ln_line_num    NUMBER := 0;
        lv_date        DATE := NULL;
        lv_open_flag   VARCHAR2 (10);

        /*   l_oe_header_id        NUMBER;
           l_ship_from_org_id    NUMBER;
           l_line_id             NUMBER;
           l_status              VARCHAR2 (1) := 'N';
           l_error_message       VARCHAR2 (4000);
           lv_open_flag          VARCHAR2 (10);
           l_inventory_item_id   NUMBER;
           l_request_date        DATE;
           l_lap                 DATE;
           l_cancel_date         DATE; */
        TYPE xxd_insert_book_ord_typ IS TABLE OF cur_val%ROWTYPE;

        v_ins_type     xxd_insert_book_ord_typ := xxd_insert_book_ord_typ ();
    BEGIN
        v_ins_type.DELETE;


        OPEN cur_val;

        LOOP
            FETCH cur_val BULK COLLECT INTO v_ins_type LIMIT 5000;


            IF (v_ins_type.COUNT > 0)
            THEN
                FOR x IN v_ins_type.FIRST .. v_ins_type.LAST
                LOOP
                    ln_line_num               := ln_line_num + 1;
                    v_ins_type (x).line_num   := ln_line_num;

                    BEGIN
                        SELECT ooh.header_id, ooh.ship_from_org_id
                          INTO v_ins_type (x).oe_header_id, v_ins_type (x).ship_from_org_id
                          FROM oe_order_headers_all ooh
                         WHERE ooh.order_number = v_ins_type (x).order_number;

                        IF (v_ins_type (x).line_number IS NULL)
                        THEN
                            v_ins_type (x).line_id   := NULL;
                        ELSE
                            BEGIN
                                SELECT line_id, open_flag
                                  INTO v_ins_type (x).line_id, lv_open_flag
                                  FROM oe_order_lines_all
                                 WHERE     header_id =
                                           v_ins_type (x).oe_header_id
                                       AND    line_number
                                           || '.'
                                           || shipment_number =
                                           v_ins_type (x).line_number;

                                IF (lv_open_flag <> 'Y')
                                THEN
                                    v_ins_type (x).status   := 'E';
                                    v_ins_type (x).erg_msg   :=
                                           v_ins_type (x).erg_msg
                                        || ' Line not in Open Status '
                                        || v_ins_type (x).line_number
                                        || ' ; ';
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    v_ins_type (x).status   := 'E';
                                    v_ins_type (x).erg_msg   :=
                                           v_ins_type (x).erg_msg
                                        || '  Invalid Line Number '
                                        || v_ins_type (x).line_number
                                        || ' ; ';
                            END;
                        END IF;

                        BEGIN
                            SELECT inventory_item_id
                              INTO v_ins_type (x).inventory_item_id
                              FROM mtl_system_items_b
                             WHERE     segment1 = v_ins_type (x).sku
                                   AND organization_id =
                                       v_ins_type (x).ship_from_org_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                       v_ins_type (x).erg_msg
                                    || '  Invalid SKU '
                                    || v_ins_type (x).sku
                                    || ' ; ';
                        END;

                        IF (v_ins_type (x).quantity IS NULL)
                        THEN
                            v_ins_type (x).status   := 'E';
                            v_ins_type (x).erg_msg   :=
                                   v_ins_type (x).erg_msg
                                || ' Provide Quantity value ; ';
                        END IF;

                        IF (v_ins_type (x).quantity IS NOT NULL)
                        THEN
                            IF (REGEXP_LIKE (v_ins_type (x).quantity, '^[0-9]+$'))
                            THEN
                                NULL;
                            ELSE
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                       v_ins_type (x).erg_msg
                                    || ' Invalid Quantity ; ';
                            END IF;
                        END IF;

                        IF (v_ins_type (x).request_date IS NOT NULL)
                        THEN
                            BEGIN
                                lv_date   :=
                                    TO_DATE (v_ins_type (x).request_date,
                                             'DD-Mon-YY');
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    v_ins_type (x).status         := 'E';
                                    v_ins_type (x).erg_msg        :=
                                           v_ins_type (x).erg_msg
                                        || ' Invalid Request Date(DD-MM-YY) ; '
                                        || v_ins_type (x).request_date;

                                    v_ins_type (x).request_date   := NULL;
                            END;
                        END IF;

                        IF (v_ins_type (x).lap IS NOT NULL)
                        THEN
                            BEGIN
                                lv_date   :=
                                    TO_DATE (v_ins_type (x).lap, 'DD-Mon-YY');
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    v_ins_type (x).status    := 'E';
                                    v_ins_type (x).erg_msg   :=
                                           v_ins_type (x).erg_msg
                                        || ' Invalid Latest Acceptable Date(DD-Mon-YY) ; '
                                        || v_ins_type (x).lap;

                                    v_ins_type (x).lap       := NULL;
                            END;
                        END IF;

                        IF (v_ins_type (x).cancel_date IS NOT NULL)
                        THEN
                            BEGIN
                                lv_date   :=
                                    TO_DATE (v_ins_type (x).cancel_date,
                                             'DD-Mon-YY');
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    v_ins_type (x).status        := 'E';
                                    v_ins_type (x).erg_msg       :=
                                           v_ins_type (x).erg_msg
                                        || ' Invalid Cancel Date(DD-Mon-YY) ; '
                                        || v_ins_type (x).cancel_date;

                                    v_ins_type (x).cancel_date   := NULL;
                            END;
                        END IF;

                        IF (v_ins_type (x).lap IS NULL)
                        THEN
                            NULL;
                        ELSE
                            IF (v_ins_type (x).request_date IS NOT NULL)
                            THEN
                                IF (TO_DATE (v_ins_type (x).request_date, 'DD-Mon-YY') > TO_DATE (v_ins_type (x).lap, 'DD-Mon-YY'))
                                THEN
                                    v_ins_type (x).status   := 'E';
                                    v_ins_type (x).erg_msg   :=
                                           v_ins_type (x).erg_msg
                                        || ' Latest Acceptable Date should be greater than Request Date ; ';
                                END IF;
                            END IF;
                        END IF;

                        IF (v_ins_type (x).cancel_date IS NULL)
                        THEN
                            NULL;
                        ELSE
                            IF (v_ins_type (x).request_date IS NOT NULL)
                            THEN
                                IF (TO_DATE (v_ins_type (x).request_date, 'DD-Mon-YY') > TO_DATE (v_ins_type (x).cancel_date, 'DD-Mon-YY'))
                                THEN
                                    v_ins_type (x).status   := 'E';
                                    v_ins_type (x).erg_msg   :=
                                           v_ins_type (x).erg_msg
                                        || ' Cancel Date should be greater than Request Date ; '
                                        || v_ins_type (x).request_date
                                        || ' '
                                        || v_ins_type (x).cancel_date;
                                END IF;
                            END IF;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            v_ins_type (x).status   := 'E';
                            v_ins_type (x).erg_msg   :=
                                'Order Number Invalid ' || SQLERRM;
                    END;
                END LOOP;
            END IF;


            IF (v_ins_type.COUNT > 0)
            THEN
                FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                    UPDATE xxd_ont_order_modify_details_t
                       SET status = NVL (v_ins_type (i).status, 'N'), error_message = v_ins_type (i).erg_msg, source_header_id = v_ins_type (i).oe_header_id,
                           source_line_id = v_ins_type (i).line_id, target_inventory_item_id = v_ins_type (i).inventory_item_id, attribute3 = ln_line_num
                     WHERE     1 = 1
                           AND batch_id = p_batch_id
                           AND GROUP_ID = p_group_id
                           AND ROWID = v_ins_type (i).rwid;

                COMMIT;
            END IF;

            EXIT WHEN cur_val%NOTFOUND;
        END LOOP;

        CLOSE cur_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
    END validate_line_bulk;

    -- begin  ver 2.7

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

    -- ======================================================================================
    -- This procedure calls OE_ORDER_PUB to make changes to book order
    -- ======================================================================================

    PROCEDURE process_book_order (p_header_rec IN oe_order_pub.header_rec_type, p_line_tbl IN oe_order_pub.line_tbl_type, p_action_request_tbl IN oe_order_pub.request_tbl_type, x_header_rec OUT NOCOPY oe_order_pub.header_rec_type, x_line_tbl OUT NOCOPY oe_order_pub.line_tbl_type, x_return_status OUT NOCOPY VARCHAR2
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


        --IF lc_return_status <> fnd_api.g_ret_sts_success
        --THEN

        FOR i IN 1 .. oe_msg_pub.count_msg
        LOOP
            oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                            , p_msg_index_out => ln_msg_index_out);

            lc_error_message   :=
                SUBSTR (lc_error_message || lc_msg_data, 1, 4000);
        END LOOP;

        x_error_message   := NVL (lc_error_message, 'OE_ORDER_PUB Failed');
        --ELSE
        x_header_rec      := lx_header_rec;
        x_line_tbl        := lx_line_tbl;
        --END IF;
        x_return_status   := lc_return_status;
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Others Exception in PROCESS_ORDER = ' || SQLERRM);
            debug_msg ('End ' || lc_sub_prog_name);
            x_return_status   := 'E';
            x_error_message   := SQLERRM;
    END process_book_order;


    /*
        FUNCTION do_batching (p_numbins NUMBER, p_grpid NUMBER)
            RETURN tt_out
            PIPELINED
        IS
            l_bins    SYS.odcinumberlist := sys.odcinumberlist ();
            min_bin   NUMBER := 1;
        BEGIN
            l_bins.EXTEND (p_numbins);

            FOR i IN 1 .. l_bins.COUNT
            LOOP
                l_bins (i) := 0;
            END LOOP;

            FOR rec
                IN (  SELECT item_name, item_value, num_bin
                        FROM (  SELECT source_header_id     item_name,
                                       COUNT (*)            item_value,
                                       0                    num_bin
                                  FROM apps.xxd_ont_order_modify_details_t
                                 WHERE GROUP_ID = p_grpid
                              GROUP BY source_header_id)
                    ORDER BY item_value DESC)
            LOOP
                l_bins (min_bin) := l_bins (min_bin) + rec.item_value;
                rec.num_bin := min_bin;
                PIPE ROW (rec);

                FOR i IN 1 .. l_bins.COUNT
                LOOP
                    IF l_bins (i) < l_bins (min_bin)
                    THEN
                        min_bin := i;
                    END IF;
                END LOOP;
            END LOOP;

            RETURN;
        END do_batching;
    */
    -- begin  ver 2.5
    PROCEDURE update_batch_modified (p_group_id IN NUMBER)
    IS
        ln_lines_count      NUMBER := 0;
        ln_current_bin      NUMBER := 1;
        ln_batch_id         NUMBER := 0;
        ln_no_of_process    NUMBER := 0;

        CURSOR c_get_headers (p_no_of_processes NUMBER)
        IS
            (SELECT hdr_id, bin
               FROM (  SELECT *
                         FROM (  SELECT source_header_id hdr_id, COUNT (*) AS line_count
                                   FROM apps.xxd_ont_order_modify_details_t
                                  WHERE     1 = 1
                                        AND batch_id IS NULL
                                        AND status = 'N'
                                        AND GROUP_ID = p_group_id
                               GROUP BY source_header_id)
                     MODEL
                         DIMENSION BY (
                             ROW_NUMBER () OVER (ORDER BY line_count DESC) rn)
                         MEASURES (
                             hdr_id,
                             line_count,
                             ROW_NUMBER () OVER (ORDER BY line_count DESC) bin,
                             line_count bin_value,
                             ROW_NUMBER () OVER (ORDER BY line_count DESC) rn_m,
                             0 min_bin,
                             COUNT (*) OVER () - p_no_of_processes - 1 n_iters)
                         RULES
                         ITERATE (100000)
                             UNTIL (ITERATION_NUMBER >= n_iters[1])
                         (
                             min_bin [1] =
                                 MIN (rn_m)
                                 KEEP (DENSE_RANK FIRST ORDER BY bin_value)
                                     [rn <= p_no_of_processes],
                             bin [ITERATION_NUMBER + p_no_of_processes + 1] =
                                 min_bin[1],
                             bin_value [min_bin[1]] =
                                   bin_value[CV ()]
                                 + NVL (
                                       line_count[  ITERATION_NUMBER
                                                  + p_no_of_processes
                                                  + 1],
                                       0))
                     ORDER BY bin));

        TYPE vld_record_typ IS TABLE OF c_get_headers%ROWTYPE;

        lv_vld_record_typ   vld_record_typ := vld_record_typ ();
    BEGIN
        BEGIN
            SELECT COUNT (1)
              INTO ln_lines_count
              FROM xxd_ont_order_modify_details_t
             WHERE     batch_id IS NULL
                   AND status = 'N'
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
                ln_lines_count     := 0;
                ln_no_of_process   := 0;
                debug_msg ('Exception - ' || SQLERRM);
        END;

        OPEN c_get_headers (ln_no_of_process);

        FETCH c_get_headers BULK COLLECT INTO lv_vld_record_typ;

        CLOSE c_get_headers;


        FOR l_counter IN 1 .. ln_no_of_process
        LOOP
            ln_batch_id   := xxdo.xxd_ont_order_modify_details_s.NEXTVAL;

            IF (lv_vld_record_typ.COUNT > 0)
            THEN
                FOR i IN lv_vld_record_typ.FIRST .. lv_vld_record_typ.LAST
                LOOP
                    UPDATE xxd_ont_order_modify_details_t
                       SET batch_id = ln_batch_id, parent_request_id = gn_request_id
                     WHERE     1 = 1
                           AND batch_id IS NULL
                           AND source_header_id =
                               lv_vld_record_typ (i).hdr_id
                           AND status = 'N'
                           AND lv_vld_record_typ (i).bin = l_counter
                           AND GROUP_ID = p_group_id;

                    IF lv_vld_record_typ (i).bin <> l_counter
                    THEN
                        CONTINUE;
                    END IF;
                END LOOP;                                   -- end loop record
            END IF;
        END LOOP;                                        -- end loop l_counter

        COMMIT;
        debug_msg ('New Batching process completed.');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in update_batch_modified : ' || SQLERRM);
    END update_batch_modified;

    -- end ver 2.5
    -- ======================================================================================
    -- This procedure performs batching of order data
    -- ======================================================================================

    PROCEDURE update_batch (p_group_id IN NUMBER)
    IS
        lc_sub_prog_name   VARCHAR2 (100) := 'MASTER_PRC';
        ln_lines_count     NUMBER := 0;
        ln_count           NUMBER := 0;
        ln_mod_count       NUMBER := 0;
        ln_batch_id        NUMBER := 0;
        ln_no_of_process   NUMBER := 0;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        -- begin ver 2.5
        update_batch_modified (p_group_id);
        /*
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_lines_count
                      FROM xxd_ont_order_modify_details_t
                     WHERE     batch_id IS NULL
                           AND status = 'N'
                           AND GROUP_ID = p_group_id;

                    SELECT lookup_code
                      INTO ln_no_of_process
                      FROM fnd_lookup_values
                     WHERE     1 = 1
                           AND lookup_type = 'XXD_ONT_NO_OF_PROCESSES' -- ver 2.5 changed to lookup
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

                        -- average batch size per source header id
                        ln_mod_count := CEIL (ln_lines_count / ln_no_of_process);

                        FOR i IN 1 .. ln_no_of_process
                        LOOP
                            ln_batch_id := xxdo.xxd_ont_order_modify_details_s.NEXTVAL;

                            UPDATE xxd_ont_order_modify_details_t
                               SET batch_id = ln_batch_id, parent_request_id = gn_request_id
                             WHERE     batch_id IS NULL
                                   AND source_header_id IN
                                           (SELECT source_header_id
                                              FROM (  SELECT source_header_id,
                                                             SUM (COUNT (1))
                                                                 OVER (
                                                                     ORDER BY
                                                                         COUNT (1),
                                                                         source_header_id)    cntt
                                                        FROM xxd_ont_order_modify_details_t
                                                       WHERE     1 = 1
                                                             AND batch_id IS NULL
                                                             AND status = 'N'
                                                             AND GROUP_ID = p_group_id
                                                    GROUP BY source_header_id
                                                    ORDER BY 2)
                                             WHERE 1 = 1 AND cntt <= ln_mod_count)
                                   AND status = 'N'
                                   AND GROUP_ID = p_group_id;
                        END LOOP;

                        COMMIT;

                -- Update big orders with unique batch id

                FOR i
                    IN (SELECT DISTINCT source_header_id
                          FROM xxd_ont_order_modify_details_t
                         WHERE     1 = 1
                               AND batch_id IS NULL
                               AND status = 'N'
                               AND GROUP_ID = p_group_id)
                LOOP
                    ln_batch_id := xxdo.xxd_ont_order_modify_details_s.NEXTVAL;

                    UPDATE xxd_ont_order_modify_details_t
                       SET batch_id = ln_batch_id, parent_request_id = gn_request_id
                     WHERE     1 = 1
                           AND batch_id IS NULL
                           AND source_header_id = i.source_header_id
                           AND status = 'N'
                           AND GROUP_ID = p_group_id;
                END LOOP;
        */
        -- ver 2.5
        COMMIT;
        debug_msg ('Batching process completed.');
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in UPDATE_BATCH : ' || SQLERRM);
            debug_msg ('End ' || lc_sub_prog_name);
    END update_batch;



    -- ======================================================================================
    -- This procedure selects and inserts records in custom table
    -- ======================================================================================

    PROCEDURE insert_prc (p_operation_mode IN VARCHAR2, p_group_id IN NUMBER, p_order_dtls_tbl_typ IN xxd_ont_order_dtls_tbl_typ
                          , x_record_count OUT NOCOPY NUMBER)
    AS
        ln_record_count   NUMBER := 0;
        new_seq           NUMBER := 0;              -- Added as per CCR0010520
    BEGIN
        FOR ln_index IN 1 .. p_order_dtls_tbl_typ.COUNT
        LOOP
            new_seq           := xxdo.XXD_ONT_ORDER_MODIFY_DETAILS_REC_S.NEXTVAL; -- Added as per CCR0010520

            INSERT INTO xxd_ont_order_modify_details_t (
                            GROUP_ID,
                            org_id,
                            operation_mode,
                            source_header_id,                  -- Source Start
                            source_order_number,
                            source_cust_account,
                            source_sold_to_org_id,
                            source_cust_po_number,
                            source_order_type,
                            source_header_request_date,
                            brand,
                            source_line_id,
                            source_line_number,
                            source_ordered_item,
                            source_inventory_item_id,
                            source_ordered_quantity,
                            source_line_request_date,
                            source_schedule_ship_date,
                            source_latest_acceptable_date,       -- Source End
                            target_customer_number,     -- Target Header Start
                            target_sold_to_org_id,
                            target_order_number,
                            target_header_id,
                            target_cust_po_num,
                            target_order_type,
                            target_order_type_id,
                            target_header_request_date,
                            target_header_cancel_date,
                            target_header_demand_class,
                            target_header_ship_method,
                            target_header_freight_carrier,
                            target_header_freight_terms,
                            target_header_payment_term,   -- Target Header End
                            target_ordered_item,          -- Target Line Start
                            target_inventory_item_id,
                            target_ordered_quantity,
                            target_line_request_date,
                            target_schedule_ship_date,
                            target_latest_acceptable_date,
                            target_line_cancel_date,
                            target_ship_from_org,
                            target_ship_from_org_id,
                            target_line_demand_class,
                            target_line_ship_method,
                            target_line_freight_carrier,
                            target_line_freight_terms,
                            target_line_payment_term,
                            target_change_reason,
                            target_change_reason_code,      -- Target Line End
                            attribute1,          -- Additional Attribute Start
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
                            attribute15,           -- Additional Attribute End
                            batch_id,
                            status,
                            error_message,
                            parent_request_id,
                            request_id,
                            creation_date,
                            created_by,
                            last_update_date,
                            last_updated_by,
                            last_update_login,
                            record_id               -- Added as per CCR0010520
                                     )
                -- Source from an existing line
                (SELECT p_group_id,
                        ooha.org_id,
                        p_operation_mode,
                        ooha.header_id,                        -- Source Start
                        ooha.order_number,
                        (SELECT account_number
                           FROM hz_cust_accounts
                          WHERE cust_account_id = ooha.sold_to_org_id)
                            source_cust_account,
                        ooha.sold_to_org_id,
                        ooha.cust_po_number,
                        (SELECT name
                           FROM oe_transaction_types_tl
                          WHERE     language = USERENV ('LANG')
                                AND transaction_type_id = ooha.order_type_id)
                            source_order_type,
                        ooha.request_date,
                        ooha.attribute5,
                        oola.line_id,
                        oola.line_number || '.' || oola.shipment_number,
                        oola.ordered_item,
                        oola.inventory_item_id,
                        oola.ordered_quantity,
                        oola.request_date,
                        oola.schedule_ship_date,
                        oola.latest_acceptable_date,             -- Source End
                        p_order_dtls_tbl_typ (ln_index).target_customer_number, -- Target Header Start
                        (SELECT cust_account_id
                           FROM hz_cust_accounts
                          WHERE account_number =
                                p_order_dtls_tbl_typ (ln_index).target_customer_number),
                        p_order_dtls_tbl_typ (ln_index).target_order_number,
                        (SELECT header_id
                           FROM oe_order_headers_all
                          WHERE order_number =
                                p_order_dtls_tbl_typ (ln_index).target_order_number),
                        p_order_dtls_tbl_typ (ln_index).target_cust_po_num,
                        p_order_dtls_tbl_typ (ln_index).target_order_type,
                        (SELECT transaction_type_id
                           FROM oe_transaction_types_tl
                          WHERE     language = USERENV ('LANG')
                                AND name =
                                    p_order_dtls_tbl_typ (ln_index).target_order_type),
                        p_order_dtls_tbl_typ (ln_index).target_header_request_date,
                        p_order_dtls_tbl_typ (ln_index).target_header_cancel_date,
                        p_order_dtls_tbl_typ (ln_index).target_header_demand_class,
                        p_order_dtls_tbl_typ (ln_index).target_header_ship_method,
                        p_order_dtls_tbl_typ (ln_index).target_header_freight_carrier,
                        p_order_dtls_tbl_typ (ln_index).target_header_freight_terms,
                        p_order_dtls_tbl_typ (ln_index).target_header_payment_term, -- Target Header End
                        p_order_dtls_tbl_typ (ln_index).target_ordered_item, -- Target Line Start
                        (SELECT inventory_item_id
                           FROM mtl_system_items_b
                          WHERE     segment1 =
                                    p_order_dtls_tbl_typ (ln_index).target_ordered_item
                                AND organization_id = oola.ship_from_org_id),
                        p_order_dtls_tbl_typ (ln_index).target_ordered_quantity,
                        p_order_dtls_tbl_typ (ln_index).target_line_request_date,
                        NULL
                            target_schedule_ship_date,
                        p_order_dtls_tbl_typ (ln_index).target_latest_acceptable_date,
                        p_order_dtls_tbl_typ (ln_index).target_line_cancel_date,
                        p_order_dtls_tbl_typ (ln_index).target_ship_from_org,
                        (SELECT organization_id
                           FROM mtl_parameters
                          WHERE organization_code =
                                p_order_dtls_tbl_typ (ln_index).target_ship_from_org),
                        p_order_dtls_tbl_typ (ln_index).target_line_demand_class,
                        p_order_dtls_tbl_typ (ln_index).target_line_ship_method,
                        p_order_dtls_tbl_typ (ln_index).target_line_freight_carrier,
                        p_order_dtls_tbl_typ (ln_index).target_line_freight_terms,
                        p_order_dtls_tbl_typ (ln_index).target_line_payment_term,
                        p_order_dtls_tbl_typ (ln_index).target_change_reason,
                        (SELECT lookup_code
                           FROM fnd_lookup_values
                          WHERE     lookup_type = 'CANCEL_CODE'
                                AND enabled_flag = 'Y'
                                AND language = USERENV ('LANG')
                                AND SYSDATE BETWEEN start_date_active
                                                AND NVL (end_date_active,
                                                         SYSDATE + 1)
                                AND meaning =
                                    p_order_dtls_tbl_typ (ln_index).target_change_reason), -- Target Line End
                        p_order_dtls_tbl_typ (ln_index).attribute1, -- Additional Attribute Start
                        p_order_dtls_tbl_typ (ln_index).attribute2,
                        p_order_dtls_tbl_typ (ln_index).attribute3,
                        p_order_dtls_tbl_typ (ln_index).attribute4,
                        p_order_dtls_tbl_typ (ln_index).attribute5,
                        p_order_dtls_tbl_typ (ln_index).attribute6,
                        p_order_dtls_tbl_typ (ln_index).attribute7,
                        p_order_dtls_tbl_typ (ln_index).attribute8,
                        p_order_dtls_tbl_typ (ln_index).attribute9,
                        p_order_dtls_tbl_typ (ln_index).attribute10,
                        p_order_dtls_tbl_typ (ln_index).attribute11,
                        p_order_dtls_tbl_typ (ln_index).attribute12,
                        p_order_dtls_tbl_typ (ln_index).attribute13,
                        p_order_dtls_tbl_typ (ln_index).attribute14,
                        p_order_dtls_tbl_typ (ln_index).attribute15, -- Additional Attribute End
                        NULL,
                        'N',
                        NULL,
                        NULL,
                        NULL,
                        SYSDATE,
                        gn_user_id,
                        SYSDATE,
                        gn_user_id,
                        gn_login_id,
                        new_seq                     -- Added as per CCR0010520
                   FROM oe_order_headers_all ooha, oe_order_lines_all oola
                  WHERE     ooha.header_id = oola.header_id
                        AND ooha.open_flag = 'Y'
                        AND oola.open_flag = 'Y'
                        AND ooha.booked_flag IN ('Y', 'N')
                        AND ooha.header_id =
                            p_order_dtls_tbl_typ (ln_index).source_header_id
                        AND oola.line_id =
                            p_order_dtls_tbl_typ (ln_index).source_line_id
                        AND p_order_dtls_tbl_typ (ln_index).source_line_id
                                IS NOT NULL
                 UNION
                 -- To create a new line in an existing order
                 SELECT p_group_id,
                        ooha.org_id,
                        p_operation_mode,
                        ooha.header_id,                        -- Source Start
                        ooha.order_number,
                        (SELECT account_number
                           FROM hz_cust_accounts
                          WHERE cust_account_id = ooha.sold_to_org_id)
                            source_cust_account,
                        ooha.sold_to_org_id,
                        ooha.cust_po_number,
                        (SELECT name
                           FROM oe_transaction_types_tl
                          WHERE     language = USERENV ('LANG')
                                AND transaction_type_id = ooha.order_type_id)
                            source_order_type,
                        ooha.request_date,
                        ooha.attribute5,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,                                    -- Source End
                        NULL,                           -- Target Header Start
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        NULL,                             -- Target Header End
                        p_order_dtls_tbl_typ (ln_index).target_ordered_item, -- Target Line Start
                        (SELECT inventory_item_id
                           FROM mtl_system_items_b
                          WHERE     segment1 =
                                    p_order_dtls_tbl_typ (ln_index).target_ordered_item
                                AND organization_id = ooha.ship_from_org_id),
                        p_order_dtls_tbl_typ (ln_index).target_ordered_quantity,
                        p_order_dtls_tbl_typ (ln_index).target_line_request_date,
                        NULL
                            target_schedule_ship_date,
                        p_order_dtls_tbl_typ (ln_index).target_latest_acceptable_date,
                        p_order_dtls_tbl_typ (ln_index).target_line_cancel_date,
                        p_order_dtls_tbl_typ (ln_index).target_ship_from_org,
                        (SELECT organization_id
                           FROM mtl_parameters
                          WHERE organization_code =
                                p_order_dtls_tbl_typ (ln_index).target_ship_from_org),
                        p_order_dtls_tbl_typ (ln_index).target_line_demand_class,
                        p_order_dtls_tbl_typ (ln_index).target_line_ship_method,
                        p_order_dtls_tbl_typ (ln_index).target_line_freight_carrier,
                        p_order_dtls_tbl_typ (ln_index).target_line_freight_terms,
                        p_order_dtls_tbl_typ (ln_index).target_line_payment_term,
                        p_order_dtls_tbl_typ (ln_index).target_change_reason,
                        (SELECT lookup_code
                           FROM fnd_lookup_values
                          WHERE     lookup_type = 'CANCEL_CODE'
                                AND enabled_flag = 'Y'
                                AND language = USERENV ('LANG')
                                AND SYSDATE BETWEEN start_date_active
                                                AND NVL (end_date_active,
                                                         SYSDATE + 1)
                                AND meaning =
                                    p_order_dtls_tbl_typ (ln_index).target_change_reason), -- Target Line End
                        p_order_dtls_tbl_typ (ln_index).attribute1, -- Additional Attribute Start
                        p_order_dtls_tbl_typ (ln_index).attribute2,
                        p_order_dtls_tbl_typ (ln_index).attribute3,
                        p_order_dtls_tbl_typ (ln_index).attribute4,
                        p_order_dtls_tbl_typ (ln_index).attribute5,
                        p_order_dtls_tbl_typ (ln_index).attribute6,
                        p_order_dtls_tbl_typ (ln_index).attribute7,
                        p_order_dtls_tbl_typ (ln_index).attribute8,
                        p_order_dtls_tbl_typ (ln_index).attribute9,
                        p_order_dtls_tbl_typ (ln_index).attribute10,
                        p_order_dtls_tbl_typ (ln_index).attribute11,
                        p_order_dtls_tbl_typ (ln_index).attribute12,
                        p_order_dtls_tbl_typ (ln_index).attribute13,
                        p_order_dtls_tbl_typ (ln_index).attribute14,
                        p_order_dtls_tbl_typ (ln_index).attribute15, -- Additional Attribute End
                        NULL,
                        'N',
                        NULL,
                        NULL,
                        NULL,
                        SYSDATE,
                        gn_user_id,
                        SYSDATE,
                        gn_user_id,
                        gn_login_id,
                        new_seq                     -- Added as per CCR0010520
                   FROM oe_order_headers_all ooha
                  WHERE     ooha.open_flag = 'Y'
                        AND ooha.booked_flag IN ('Y', 'N')
                        AND ooha.header_id =
                            p_order_dtls_tbl_typ (ln_index).source_header_id
                        AND p_order_dtls_tbl_typ (ln_index).source_line_id
                                IS NULL);

            ln_record_count   := ln_record_count + SQL%ROWCOUNT;
        END LOOP;

        x_record_count   := ln_record_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            ln_record_count   := 0;
    END insert_prc;

    -- ======================================================================================
    -- This procedure validates and update records in custom table
    -- ======================================================================================

    PROCEDURE validate_prc (p_operation_mode   IN VARCHAR2,
                            p_group_id         IN NUMBER)
    AS
        lc_error_message   VARCHAR2 (4000);
    BEGIN
        -- Open Order
        UPDATE xxd_ont_order_modify_details_t xoom
           SET status = 'E', error_message = SUBSTR (error_message || 'Order is not Open.', 1, 2000), last_update_date = SYSDATE,
               last_update_login = gn_login_id
         WHERE     xoom.GROUP_ID = p_group_id
               AND NOT EXISTS
                       (SELECT 1
                          FROM oe_order_headers_all ooha
                         WHERE     ooha.header_id = xoom.source_header_id
                               AND ooha.open_flag = 'Y');

        -- Open Line

        UPDATE xxd_ont_order_modify_details_t xoom
           SET status = 'E', error_message = SUBSTR (error_message || 'Order line is not Open.', 1, 2000), last_update_date = SYSDATE,
               last_update_login = gn_login_id
         WHERE     xoom.GROUP_ID = p_group_id
               AND xoom.source_line_id IS NOT NULL
               AND NOT EXISTS
                       (SELECT 1
                          FROM oe_order_lines_all oola
                         WHERE     oola.line_id = xoom.source_line_id
                               AND oola.open_flag = 'Y');

        --
        -- 2.0 Gaurav Joshi -- Request Date
        -- Request date Should be greater than Today's Date is not applicable for update when the entered qty is zerO
        -- this piece of code is not required , hence commenting
        -- APPLICABLE AS IS FOR MOVE MODE
        -- APPLICABLE AS IS IN CREATE MODE
        /*
     UPDATE xxd_ont_order_modify_details_t
           SET status = 'E',
               error_message =
                  SUBSTR (
                        error_message
                     || 'Request Date cannot be less than SYSDATE.',
                     1,
                     2000),
               last_update_date = SYSDATE,
               last_update_login = gn_login_id
         WHERE     target_line_request_date < TRUNC (SYSDATE)
               AND (   operation_mode = 'XXD_ONT_MOVE'
                    OR operation_mode = 'XXD_ONT_CREATE'
                    OR (    operation_mode = 'XXD_ONT_UPDATE'
                        AND TARGET_ORDERED_QUANTITY > 0))
               AND GROUP_ID = p_group_id;
      */

        /*  2.0 commented Gaurav Joshi
        -- added the modified version below
         -- LAD
              UPDATE xxd_ont_order_modify_details_t
                 SET status = 'E',
                     error_message =
                        SUBSTR (
                              error_message
                           || 'LAD is either less than SYSDATE OR less than Request Date.',
                           1,
                           2000),
                     last_update_date = SYSDATE,
                     last_update_login = gn_login_id
               WHERE     (   target_latest_acceptable_date < TRUNC (SYSDATE)
                          OR target_latest_acceptable_date < target_line_request_date)
                     AND GROUP_ID = p_group_id;
            */

        -- 2.0 Begin Gaurav joshi  LAD

        UPDATE xxd_ont_order_modify_details_t
           SET status = 'E', error_message = SUBSTR (error_message || 'LAD is either less than SYSDATE OR less than Request Date.', 1, 2000), last_update_date = SYSDATE,
               last_update_login = gn_login_id
         WHERE     1 = 1
               AND ((operation_mode IN ('XXD_ONT_MOVE', 'XXD_ONT_CREATE') AND (target_latest_acceptable_date < target_line_request_date)) OR (operation_mode = 'XXD_ONT_UPDATE' AND target_ordered_quantity > 0 AND (target_latest_acceptable_date < target_line_request_date)))
               AND GROUP_ID = p_group_id;
    -- 2.0 End

    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = SUBSTR (error_message || lc_error_message, 1, 2500), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE status = 'N' AND GROUP_ID = p_group_id;

            COMMIT;
    END validate_prc;

    -- ======================================================================================
    -- This procedure performs updates to an existing order
    -- ======================================================================================

    PROCEDURE update_order_prc (p_group_id IN NUMBER, p_batch_id IN NUMBER)
    AS
        CURSOR get_orders_c IS
            SELECT DISTINCT source_order_number, source_header_id, org_id
              FROM xxd_ont_order_modify_details_t
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

        CURSOR get_lines_c (
            p_header_id IN oe_order_headers_all.header_id%TYPE)
        IS
            SELECT source_line_id, target_inventory_item_id, target_ordered_quantity,
                   target_line_request_date, target_latest_acceptable_date, target_change_reason_code
              FROM xxd_ont_order_modify_details_t
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND source_header_id = p_header_id;

        lc_sub_prog_name       VARCHAR2 (100) := 'UPDATE_ORDER_PRC';
        lc_api_return_status   VARCHAR2 (1);
        lc_lock_status         VARCHAR2 (1);
        lc_error_message       VARCHAR2 (4000);
        ln_line_tbl_count      NUMBER := 0;
        l_header_rec           oe_order_pub.header_rec_type;
        lx_header_rec          oe_order_pub.header_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        lx_line_tbl            oe_order_pub.line_tbl_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
        ln_cust_account_id     NUMBER;
        ln_ship_to_org_id      NUMBER;
        lv_color               VARCHAR2 (1000);
        lv_style               VARCHAR2 (1000);
        ln_ship_from_org_id    NUMBER;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        FOR orders_rec IN get_orders_c
        LOOP
            lc_lock_status   := 'S';

            -- Try locking all lines in the order
            oe_line_util.lock_rows (
                p_header_id       => orders_rec.source_header_id,
                x_line_tbl        => l_line_tbl,
                x_return_status   => lc_lock_status);

            IF lc_lock_status = 'S'
            THEN
                lc_api_return_status     := NULL;
                lc_error_message         := NULL;
                oe_msg_pub.delete_msg;
                oe_msg_pub.initialize;
                ln_line_tbl_count        := 0;
                debug_msg (RPAD ('=', 100, '='));
                debug_msg (
                       'Processing Order Number '
                    || orders_rec.source_order_number
                    || '. Header ID '
                    || orders_rec.source_header_id);
                debug_msg (
                       'Start Time '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                l_header_rec             := oe_order_pub.g_miss_header_rec;
                l_line_tbl               := oe_order_pub.g_miss_line_tbl;

                -- Header
                l_header_rec.header_id   := orders_rec.source_header_id;
                l_header_rec.org_id      := orders_rec.org_id;
                l_header_rec.operation   := oe_globals.g_opr_update;

                --Added for CCR0009521--
                BEGIN
                    ln_cust_account_id    := NULL;
                    ln_ship_to_org_id     := NULL;
                    ln_ship_from_org_id   := NULL;

                    SELECT sold_to_org_id, ship_to_org_id, ship_from_org_id
                      INTO ln_cust_account_id, ln_ship_to_org_id, ln_ship_from_org_id
                      FROM oe_order_headers_all
                     WHERE header_id = orders_rec.source_header_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_cust_account_id    := NULL;
                        ln_ship_to_org_id     := NULL;
                        ln_ship_from_org_id   := NULL;
                END;

                --End for CCR0009521--
                -- Lines

                FOR lines_rec IN get_lines_c (orders_rec.source_header_id)
                LOOP
                    ln_line_tbl_count   := ln_line_tbl_count + 1;
                    l_line_tbl (ln_line_tbl_count)   :=
                        oe_order_pub.g_miss_line_rec;
                    -- Original Line Changes
                    l_line_tbl (ln_line_tbl_count).header_id   :=
                        orders_rec.source_header_id;
                    l_line_tbl (ln_line_tbl_count).org_id   :=
                        orders_rec.org_id;

                    IF lines_rec.source_line_id IS NOT NULL
                    THEN
                        l_line_tbl (ln_line_tbl_count).line_id   :=
                            lines_rec.source_line_id;
                        l_line_tbl (ln_line_tbl_count).operation   :=
                            oe_globals.g_opr_update;
                    ELSE
                        l_line_tbl (ln_line_tbl_count).inventory_item_id   :=
                            lines_rec.target_inventory_item_id;
                        l_line_tbl (ln_line_tbl_count).operation   :=
                            oe_globals.g_opr_create;

                        --Added for CCR0009521--
                        BEGIN
                            lv_style   := NULL;
                            lv_color   := NULL;

                            SELECT REGEXP_SUBSTR (msi.concatenated_segments, '[^-]+', 1
                                                  , 1),
                                   REGEXP_SUBSTR (msi.concatenated_segments, '[^-]+', 1
                                                  , 2)
                              INTO lv_style, lv_color
                              FROM mtl_system_items_kfv msi
                             WHERE     msi.organization_id =
                                       NVL (ln_ship_from_org_id,
                                            organization_id)
                                   AND msi.inventory_item_id =
                                       lines_rec.target_inventory_item_id
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_color   := NULL;
                                lv_style   := NULL;
                        END;

                        BEGIN
                            l_line_tbl (ln_line_tbl_count).attribute14   :=
                                xxd_ont_order_modify_pkg.get_vas_code (
                                    p_level             => 'LINE',
                                    p_cust_account_id   => ln_cust_account_id,
                                    p_site_use_id       => ln_ship_to_org_id,
                                    p_style             => lv_style,
                                    p_color             => lv_color);
                        END;
                    --End for CCR0009521--

                    END IF;

                    l_line_tbl (ln_line_tbl_count).ordered_quantity   :=
                        NVL (lines_rec.target_ordered_quantity,
                             fnd_api.g_miss_num);

                    l_line_tbl (ln_line_tbl_count).request_date   :=
                        NVL (lines_rec.target_line_request_date,
                             fnd_api.g_miss_date);

                    l_line_tbl (ln_line_tbl_count).latest_acceptable_date   :=
                        NVL (lines_rec.target_latest_acceptable_date,
                             fnd_api.g_miss_date);

                    l_line_tbl (ln_line_tbl_count).attribute1   :=
                        NVL (
                            fnd_date.date_to_canonical (
                                lines_rec.target_latest_acceptable_date),
                            fnd_api.g_miss_char);

                    l_line_tbl (ln_line_tbl_count).change_reason   :=
                        lines_rec.target_change_reason_code;
                    l_line_tbl (ln_line_tbl_count).change_comments   :=
                           'Line modified on '
                        || SYSDATE
                        || ' by program request_id: '
                        || gn_request_id;

                    l_line_tbl (ln_line_tbl_count).request_id   :=
                        gn_request_id;
                END LOOP;

                process_order (p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, p_action_request_tbl => l_action_request_tbl, x_header_rec => lx_header_rec, x_line_tbl => lx_line_tbl, x_return_status => lc_api_return_status
                               , x_error_message => lc_error_message);

                debug_msg ('Order Update Status = ' || lc_api_return_status);

                IF lc_api_return_status <> 'S'
                THEN
                    debug_msg ('Order Update Error = ' || lc_error_message);
                ELSE
                    debug_msg (
                        'Target Order Header ID ' || lx_header_rec.header_id);
                END IF;
            ELSE
                lc_error_message       :=
                    'One or more line is locked by another user';
                debug_msg (lc_error_message);
                lc_api_return_status   := 'E';
            END IF;

            UPDATE xxd_ont_order_modify_details_t
               SET target_header_id   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.header_id,
                               target_header_id),
                   target_order_number   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.order_number,
                               target_order_number),
                   target_order_type_id   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.order_type_id,
                               target_order_type_id),
                   target_order_type   =
                       DECODE (
                           lc_api_return_status,
                           'S', (SELECT name
                                   FROM oe_transaction_types_tl
                                  WHERE     language = USERENV ('LANG')
                                        AND transaction_type_id =
                                            lx_header_rec.order_type_id),
                           target_order_type),
                   target_sold_to_org_id   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.sold_to_org_id,
                               target_sold_to_org_id),
                   target_customer_number   =
                       DECODE (
                           lc_api_return_status,
                           'S', (SELECT account_number
                                   FROM hz_cust_accounts
                                  WHERE cust_account_id =
                                        lx_header_rec.sold_to_org_id),
                           target_customer_number),
                   target_line_id      = source_line_id,
                   target_schedule_ship_date   =
                       (SELECT TRUNC (schedule_ship_date)
                          FROM oe_order_lines_all
                         WHERE line_id = source_line_id),
                   status              = lc_api_return_status,
                   error_message       =
                       SUBSTR (error_message || lc_error_message, 1, 2000),
                   request_id          = gn_request_id,
                   last_update_date    = SYSDATE,
                   last_update_login   = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND source_header_id = orders_rec.source_header_id;

            debug_msg (
                'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg (
                   'Updated Status in Custom Table Record Count = '
                || SQL%ROWCOUNT);
            debug_msg (RPAD ('=', 100, '='));
            COMMIT;
        END LOOP;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in UPDATE_ORDER_PRC = ' || lc_error_message);
    END update_order_prc;

    -- ======================================================================================
    -- This procedure cancels the source order lines and creates it in an existing/new order
    -- ======================================================================================

    PROCEDURE copy_to_order_prc (p_group_id IN NUMBER, p_batch_id IN NUMBER)
    AS
        CURSOR get_orders_c IS
              SELECT operation_mode, MIN (source_order_number) source_order_number, MIN (source_header_id) source_header_id,
                     target_order_number, target_header_id, target_sold_to_org_id,
                     target_cust_po_num, target_order_type_id, org_id,
                     MIN (target_line_request_date) header_request_date, fnd_date.date_to_canonical (MAX (target_latest_acceptable_date)) header_cancel_date, --1.1
                                                                                                                                                              source_cust_account,
                     target_customer_number
                --1.1
                FROM xxd_ont_order_modify_details_t
               WHERE     status = 'N'
                     AND batch_id = p_batch_id
                     AND GROUP_ID = p_group_id
            GROUP BY operation_mode, target_sold_to_org_id, target_cust_po_num,
                     target_order_type_id, target_order_number, target_header_id,
                     org_id, --1.1
                             source_cust_account, target_customer_number
            --1.1
            ORDER BY source_header_id;

        CURSOR get_lines_c IS
              SELECT *
                FROM xxd_ont_order_modify_details_t
               WHERE     status = 'N'
                     AND batch_id = p_batch_id
                     AND GROUP_ID = p_group_id
            -- AND source_header_id = p_header_id
            ORDER BY source_line_id;

        -- VER 2.2 GET ALL TARGET HEADER ID CREATED IN THIS BATCH AND COPY THE ATTACHMENT
        CURSOR cpy_source_to_target_hdr_attachment_c IS
            SELECT DISTINCT SOURCE_HEADER_ID, TARGET_HEADER_ID
              FROM xxd_ont_order_modify_details_t
             WHERE     status = 'S'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND operation_mode = 'XXD_ONT_CREATE'
                   AND TARGET_HEADER_ID IS NOT NULL;

        lc_sub_prog_name          VARCHAR2 (100) := 'COPY_TO_EXISTING_ORDER_PRC';
        lc_api_return_status      VARCHAR2 (1);
        lc_lock_status            VARCHAR2 (1);
        lc_error_message          VARCHAR2 (4000);
        ln_line_tbl_count         NUMBER := 0;
        ln_target_header_id       oe_order_headers_all.header_id%TYPE;
        ln_target_line_id         oe_order_lines_all.line_id%TYPE;
        ld_target_ssd             oe_order_lines_all.schedule_ship_date%TYPE;
        l_header_rec              oe_order_pub.header_rec_type;
        lx_header_rec             oe_order_pub.header_rec_type;
        l_source_header_rec       oe_order_pub.header_rec_type;
        l_target_header_rec       oe_order_pub.header_rec_type;         -- 1.1
        l_line_tbl                oe_order_pub.line_tbl_type;
        lx_line_tbl               oe_order_pub.line_tbl_type;
        l_source_line_rec         oe_order_pub.line_rec_type;
        l_action_request_tbl      oe_order_pub.request_tbl_type;
        l_cust_account_same       VARCHAR2 (1);
        l_operation_mode          VARCHAR2 (100);
        ln_warehouse_id           NUMBER;
        lv_shipping_method_code   oe_transaction_types_all.shipping_method_code%TYPE;
        ln_order_type_count       NUMBER;
        lv_color                  VARCHAR2 (1000);
        lv_style                  VARCHAR2 (1000);
        l_target_account_number   VARCHAR2 (240);
        ln_order_source_id        NUMBER;                           -- ver 2.3
        l_hdr_ordered_date        DATE;
        l_hdr_pricing_date        DATE;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));
        debug_msg ('before ln_order_source_id ' || ln_order_source_id);

        SELECT order_source_id
          INTO ln_order_source_id
          FROM oe_order_sources
         WHERE (name) = 'SOMT-Copy';

        BEGIN                                                       -- VER 2.6
            -- ver 2.6  when operation mode is create, then get the min of pricing and ordred date
            SELECT MIN (ORDERED_DATE), MIN (PRICING_DATE)
              INTO l_hdr_ordered_date, l_hdr_pricing_date
              FROM oe_order_headers_all
             WHERE HEADER_ID IN
                       (SELECT DISTINCT SOURCE_HEADER_ID
                          FROM xxd_ont_order_modify_details_t
                         WHERE     status = 'N'
                               AND batch_id = p_batch_id
                               AND GROUP_ID = p_group_id
                               AND OPERATION_MODE = 'XXD_ONT_CREATE');
        EXCEPTION
            WHEN OTHERS
            THEN
                l_hdr_ordered_date   := fnd_api.g_miss_date;
                l_hdr_pricing_date   := fnd_api.g_miss_date;
        END;

        debug_msg ('After ln_order_source_id ' || ln_order_source_id);

        FOR orders_rec IN get_orders_c
        LOOP
            lc_api_return_status   := NULL;
            lc_error_message       := NULL;
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            debug_msg (RPAD ('=', 100, '='));
            debug_msg (
                   'Processing Source Order Number '
                || orders_rec.source_order_number
                || '. Header ID '
                || orders_rec.source_header_id);
            debug_msg (
                   'Start Time '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            ln_target_header_id    := orders_rec.target_header_id;
            l_header_rec           := oe_order_pub.g_miss_header_rec;
            l_line_tbl             := oe_order_pub.g_miss_line_tbl;
            l_operation_mode       := orders_rec.operation_mode;         --1.1

            l_cust_account_same    := 'N';                              -- 1.1

            -- 2.4 when the action is move, target cutomer number is null in the custom table. we need to drive it using the target order number
            -- in case of create, its pre-populated at the time of insertion into custom table.
            IF l_operation_mode = 'XXD_ONT_MOVE'
            THEN
                BEGIN
                    SELECT account_number
                      INTO l_target_account_number
                      FROM hz_cust_accounts a, oe_order_headers_all b
                     WHERE     header_id = ln_target_header_id
                           AND a.cust_account_id = b.sold_to_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        debug_msg (
                               'exception while getting target order account number'
                            || SQLERRM);
                END;

                IF orders_rec.source_cust_account = l_target_account_number
                THEN
                    l_cust_account_same   := 'Y';
                END IF;
            ELSE                                   -- OPERATION MODE IS CREATE
                IF orders_rec.source_cust_account =
                   orders_rec.target_customer_number
                THEN
                    l_cust_account_same   := 'Y';
                END IF;
            END IF;

            FOR lines_rec IN get_lines_c
            LOOP
                SAVEPOINT source_order_line;
                oe_msg_pub.delete_msg;
                oe_msg_pub.initialize;
                l_header_rec           := oe_order_pub.g_miss_header_rec;
                l_line_tbl             := oe_order_pub.g_miss_line_tbl;
                l_action_request_tbl   := oe_order_pub.g_miss_request_tbl;
                lc_lock_status         := 'S';

                -- Try locking the current line in the order
                oe_line_util.lock_row (
                    p_line_id         => lines_rec.source_line_id,
                    p_x_line_rec      => l_source_line_rec,
                    x_return_status   => lc_lock_status);

                debug_msg (
                       'Processing Source Line Number '
                    || l_source_line_rec.line_number
                    || '.'
                    || l_source_line_rec.shipment_number
                    || '. Line ID '
                    || lines_rec.source_header_id);

                IF lc_lock_status <> 'S'
                THEN
                    lc_error_message       :=
                        'One or more line is locked by another user';
                    debug_msg (lc_error_message);
                    lc_api_return_status   := 'E';
                ELSE
                    -- Cancel Source Order Line
                    l_line_tbl (1)                   := oe_order_pub.g_miss_line_rec;
                    l_line_tbl (1).header_id         := lines_rec.source_header_id;
                    l_line_tbl (1).org_id            := orders_rec.org_id;
                    l_line_tbl (1).line_id           := lines_rec.source_line_id;

                    IF (lines_rec.target_ordered_quantity >= lines_rec.source_ordered_quantity)
                    THEN
                        l_line_tbl (1).ordered_quantity   := 0;
                        l_line_tbl (1).cancelled_flag     := 'Y';
                    ELSE --- only when source qty is greater; delta shuld go as qty on source line
                        l_line_tbl (1).ordered_quantity   :=
                              lines_rec.source_ordered_quantity
                            - lines_rec.target_ordered_quantity;
                    END IF;

                    l_line_tbl (1).change_reason     :=
                        lines_rec.target_change_reason_code;
                    l_line_tbl (1).change_comments   :=
                           'Line cancelled on '
                        || SYSDATE
                        || ' by program request_id: '
                        || gn_request_id;

                    l_line_tbl (1).request_id        := gn_request_id;
                    l_line_tbl (1).operation         :=
                        oe_globals.g_opr_update;
                    process_order (p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, p_action_request_tbl => l_action_request_tbl, x_header_rec => lx_header_rec, x_line_tbl => lx_line_tbl, x_return_status => lc_api_return_status
                                   , x_error_message => lc_error_message);

                    debug_msg (
                           'Order Line Cancellation Status = '
                        || lc_api_return_status);

                    IF lc_api_return_status <> 'S'
                    THEN
                        ROLLBACK TO source_order_line;
                        debug_msg (
                               'Order Line Cancellation Error = '
                            || lc_error_message);
                    -- Target Line Creation
                    ELSE
                        lc_api_return_status                  := NULL;
                        lc_error_message                      := NULL;
                        oe_msg_pub.delete_msg;
                        oe_msg_pub.initialize;
                        ln_target_line_id                     := NULL;
                        ld_target_ssd                         := NULL;
                        l_header_rec                          :=
                            oe_order_pub.g_miss_header_rec;
                        lx_header_rec                         :=
                            oe_order_pub.g_miss_header_rec;
                        l_line_tbl                            :=
                            oe_order_pub.g_miss_line_tbl;
                        lx_line_tbl                           :=
                            oe_order_pub.g_miss_line_tbl;

                        --1.1 changes start
                        BEGIN
                              SELECT otta.warehouse_id, otta.shipping_method_code, COUNT (1)
                                INTO ln_warehouse_id, lv_shipping_method_code, ln_order_type_count
                                FROM oe_transaction_types_tl ott, oe_transaction_types_all otta
                               WHERE     ott.transaction_type_id =
                                         otta.transaction_type_id
                                     AND otta.transaction_type_id =
                                         orders_rec.target_order_type_id
                                     AND ott.language = 'US'
                                     AND EXISTS
                                             (SELECT 1
                                                FROM fnd_lookup_values flv
                                               WHERE     1 = 1
                                                     AND flv.lookup_type =
                                                         'XXD_SO_MOD_ORDER_TYPE_OVERRIDE'
                                                     AND flv.language = 'US'
                                                     AND NVL (flv.enabled_flag,
                                                              'N') =
                                                         'Y'
                                                     AND NVL (
                                                             TRUNC (
                                                                 flv.start_date_active),
                                                             TRUNC (SYSDATE)) <=
                                                         TRUNC (SYSDATE)
                                                     AND NVL (
                                                             TRUNC (
                                                                 flv.end_date_active),
                                                             TRUNC (SYSDATE)) >=
                                                         TRUNC (SYSDATE)
                                                     AND meaning = ott.name)
                            GROUP BY otta.transaction_type_id, otta.warehouse_id, otta.shipping_method_code;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_order_type_count   := 0;
                            WHEN OTHERS
                            THEN
                                ln_warehouse_id           := NULL;
                                lv_shipping_method_code   := NULL;
                                ln_order_type_count       := 0;
                        END;

                        --1.1 changes

                        IF    ln_target_header_id IS NULL
                           OR l_operation_mode = 'XXD_ONT_MOVE'
                        THEN
                            -- Get the source order information
                            oe_header_util.query_row (
                                p_header_id    => orders_rec.source_header_id,
                                x_header_rec   => l_source_header_rec);
                        END IF;

                        IF l_operation_mode = 'XXD_ONT_MOVE'
                        THEN
                            -- Get the target order information 1.1
                            -- this is need to defuatling in case of move to an order
                            oe_header_util.query_row (
                                p_header_id    => ln_target_header_id,
                                x_header_rec   => l_target_header_rec);
                        END IF;

                        IF ln_target_header_id IS NULL
                        THEN
                            -- New Header Details
                            l_header_rec          := oe_order_pub.g_miss_header_rec;
                            l_header_rec.org_id   := orders_rec.org_id;
                            l_header_rec.sold_to_org_id   :=
                                orders_rec.target_sold_to_org_id;
                            l_header_rec.cust_po_number   :=
                                orders_rec.target_cust_po_num;
                            l_header_rec.order_type_id   :=
                                orders_rec.target_order_type_id;
                            l_header_rec.request_date   :=
                                NVL (orders_rec.header_request_date,
                                     fnd_api.g_miss_date);
                            l_header_rec.attribute1   :=
                                NVL (orders_rec.header_cancel_date,
                                     fnd_api.g_miss_char);


                            -- Assign Source Line value for all other columns
                            l_header_rec.transactional_curr_code   :=
                                l_source_header_rec.transactional_curr_code;
                            -- 1.1 l_header_rec.price_list_id := l_source_header_rec.price_list_id;
                            l_header_rec.order_source_id   :=
                                ln_order_source_id; -- ver 2.3 --l_source_header_rec.order_source_id;

                            -- Begin 1.1
                            --ln_order_type_count this means direct ship order when 1
                            SELECT DECODE (l_operation_mode, 'XXD_ONT_CREATE', DECODE (ln_order_type_count, 1, ln_warehouse_id, l_source_header_rec.ship_from_org_id), l_source_header_rec.ship_from_org_id)
                              INTO l_header_rec.ship_from_org_id
                              FROM DUAL;

                            SELECT DECODE (l_operation_mode, 'XXD_ONT_CREATE', DECODE (ln_order_type_count, 1, lv_shipping_method_code, DECODE (l_cust_account_same, 'Y', l_source_header_rec.shipping_method_code, fnd_api.g_miss_char)), l_source_header_rec.shipping_method_code)
                              INTO l_header_rec.shipping_method_code
                              FROM DUAL;

                            SELECT DECODE (l_cust_account_same, 'Y', l_source_header_rec.ship_to_org_id, fnd_api.g_miss_num), DECODE (l_cust_account_same, 'Y', l_source_header_rec.invoice_to_org_id, fnd_api.g_miss_num), DECODE (l_cust_account_same, 'Y', l_source_header_rec.packing_instructions, fnd_api.g_miss_char),
                                   DECODE (l_cust_account_same, 'Y', l_source_header_rec.shipping_instructions, fnd_api.g_miss_char), DECODE (l_cust_account_same, 'Y', l_source_header_rec.salesrep_id, fnd_api.g_miss_num), DECODE (l_cust_account_same, 'Y', l_source_header_rec.freight_terms_code, fnd_api.g_miss_char),
                                   DECODE (l_cust_account_same, 'Y', l_source_header_rec.payment_term_id, fnd_api.g_miss_num), DECODE (l_cust_account_same, 'Y', l_source_header_rec.demand_class_code, fnd_api.g_miss_char), DECODE (l_cust_account_same, 'Y', l_source_header_rec.deliver_to_org_id, fnd_api.g_miss_num) -- ver 2.4 if customer is different then make it null
                              INTO l_header_rec.ship_to_org_id, l_header_rec.invoice_to_org_id, l_header_rec.packing_instructions, l_header_rec.shipping_instructions,
                                                              l_header_rec.salesrep_id, l_header_rec.freight_terms_code, l_header_rec.payment_term_id,
                                                              l_header_rec.demand_class_code, l_header_rec.deliver_to_org_id -- ver 2.4
                              FROM DUAL;

                            SELECT DECODE (l_operation_mode, 'XXD_ONT_CREATE', l_hdr_ordered_date, l_source_header_rec.ordered_date), DECODE (l_operation_mode, 'XXD_ONT_CREATE', l_hdr_pricing_date, l_source_header_rec.pricing_date)
                              INTO l_header_rec.ordered_date, l_header_rec.pricing_date
                              FROM DUAL;                                -- 2.6


                            -- End 1.1

                            --l_header_rec.deliver_to_org_id := l_source_header_rec.deliver_to_org_id; -- commented ver 2.4
                            l_header_rec.return_reason_code   :=
                                l_source_header_rec.return_reason_code;
                            l_header_rec.attribute3   :=
                                l_source_header_rec.attribute3;
                            l_header_rec.attribute4   :=
                                l_source_header_rec.attribute4;
                            l_header_rec.attribute5   :=
                                l_source_header_rec.attribute5;
                            l_header_rec.attribute6   :=
                                l_source_header_rec.attribute6;
                            l_header_rec.attribute7   :=
                                l_source_header_rec.attribute7;
                            l_header_rec.attribute8   :=
                                l_source_header_rec.attribute8;
                            l_header_rec.attribute9   :=
                                l_source_header_rec.attribute9;
                            l_header_rec.attribute10   :=
                                l_source_header_rec.attribute10;
                            l_header_rec.attribute13   :=
                                l_source_header_rec.attribute13;

                            --Added for CCR0009521--
                            BEGIN
                                l_header_rec.attribute14   :=
                                    xxd_ont_order_modify_pkg.get_vas_code (
                                        'HEADER',
                                        orders_rec.target_sold_to_org_id,
                                        NULL,
                                        NULL,
                                        NULL);
                                l_header_rec.attribute14   :=
                                    NVL (l_header_rec.attribute14,
                                         l_source_header_rec.attribute14); -- ver 2.2
                            -- if null is the above function call then use what is there in source line
                            END;

                            --End for CCR0009521--

                            l_header_rec.attribute15   :=
                                l_source_header_rec.attribute15;
                            l_header_rec.attribute2   :=
                                l_source_header_rec.attribute2;     -- ver 2.2
                            l_header_rec.attribute11   :=
                                l_source_header_rec.attribute11;    -- ver 2.2
                            l_header_rec.attribute12   :=
                                l_source_header_rec.attribute12;    -- ver 2.2
                            l_header_rec.attribute16   :=
                                l_source_header_rec.attribute16;    -- ver 2.2
                            l_header_rec.attribute17   :=
                                l_source_header_rec.attribute17;    -- ver 2.2
                            l_header_rec.attribute18   :=
                                l_source_header_rec.attribute18;    -- ver 2.2
                            l_header_rec.attribute19   :=
                                l_source_header_rec.attribute19;    -- ver 2.2
                            l_header_rec.sold_to_contact_id   :=
                                l_source_header_rec.sold_to_contact_id;
                            l_header_rec.operation   :=
                                oe_globals.g_opr_create;

                            -- Action Table Details
                            l_action_request_tbl (1)   :=
                                oe_order_pub.g_miss_request_rec;
                            l_action_request_tbl (1).entity_code   :=
                                oe_globals.g_entity_header;
                            l_action_request_tbl (1).request_type   :=
                                oe_globals.g_book_order;
                        ELSE
                            -- Header
                            l_header_rec.header_id   := ln_target_header_id;
                            l_header_rec.org_id      := orders_rec.org_id;
                            l_header_rec.operation   :=
                                oe_globals.g_opr_update;
                        END IF;

                        -- New Line Details

                        l_line_tbl (1)                        :=
                            oe_order_pub.g_miss_line_rec;
                        l_line_tbl (1).operation              := oe_globals.g_opr_create;
                        l_line_tbl (1).ordered_quantity       :=
                            NVL (lines_rec.target_ordered_quantity,
                                 fnd_api.g_miss_num);

                        -- Begin 1.1

                        SELECT DECODE (l_operation_mode, 'XXD_ONT_CREATE', NVL (lines_rec.target_line_request_date, fnd_api.g_miss_date), l_target_header_rec.request_date), DECODE (l_operation_mode, 'XXD_ONT_CREATE', NVL (fnd_date.date_to_canonical (lines_rec.target_latest_acceptable_date), fnd_api.g_miss_char), l_target_header_rec.attribute1), DECODE (l_operation_mode, 'XXD_ONT_CREATE', NVL (lines_rec.target_latest_acceptable_date, fnd_api.g_miss_date), TO_DATE (l_target_header_rec.attribute1, 'YYYY/MM/DD HH24:MI:SS')) ---lad
                          INTO l_line_tbl (1).request_date, l_line_tbl (1).attribute1, l_line_tbl (1).latest_acceptable_date
                          FROM DUAL;

                        -- End 1.1

                        IF ln_target_header_id IS NOT NULL
                        THEN
                            l_line_tbl (1).header_id   := ln_target_header_id;
                        END IF;


                        -- Assign Source Line value for all other columns

                        l_line_tbl (1).inventory_item_id      :=
                            l_source_line_rec.inventory_item_id;



                        --l_line_tbl (1).ship_from_org_id :=
                        --  l_source_line_rec.ship_from_org_id;
                        SELECT DECODE (l_operation_mode, 'XXD_ONT_CREATE', DECODE (ln_order_type_count, 1, ln_warehouse_id, l_source_line_rec.ship_from_org_id), l_source_line_rec.ship_from_org_id)
                          INTO l_line_tbl (1).ship_from_org_id
                          FROM DUAL;

                        l_line_tbl (1).calculate_price_flag   := 'Y';
                        l_line_tbl (1).demand_class_code      :=
                            l_source_line_rec.demand_class_code;
                        l_line_tbl (1).unit_list_price        :=
                            l_source_line_rec.unit_list_price;

                        -- Begin 1.1
                        SELECT DECODE (l_operation_mode, 'XXD_ONT_CREATE', DECODE (l_cust_account_same, 'Y', l_source_line_rec.salesrep_id, fnd_api.g_miss_num), fnd_api.g_miss_num), DECODE (l_operation_mode, 'XXD_ONT_CREATE', DECODE (l_cust_account_same, 'Y', l_source_line_rec.payment_term_id, fnd_api.g_miss_num), fnd_api.g_miss_num), DECODE (l_operation_mode, 'XXD_ONT_CREATE', DECODE (l_cust_account_same, 'Y', l_source_line_rec.freight_terms_code, fnd_api.g_miss_char), l_target_header_rec.freight_terms_code),
                               DECODE (l_operation_mode, 'XXD_ONT_CREATE', DECODE (l_cust_account_same, 'Y', l_source_line_rec.shipping_method_code, fnd_api.g_miss_char), l_target_header_rec.shipping_method_code), DECODE (l_operation_mode, 'XXD_ONT_CREATE', lines_rec.target_cust_po_num, l_target_header_rec.cust_po_number)
                          INTO l_line_tbl (1).salesrep_id, l_line_tbl (1).payment_term_id, l_line_tbl (1).freight_terms_code, l_line_tbl (1).shipping_method_code,
                                                         l_line_tbl (1).cust_po_number
                          FROM DUAL;

                        -- End 1.1
                        --1.1   l_line_tbl (1).price_list_id :=
                        --1.1      l_source_line_rec.price_list_id;

                        l_line_tbl (1).order_source_id        :=
                            ln_order_source_id; -- l_source_line_rec.order_source_id;  -- ver 2.3

                        l_line_tbl (1).pricing_date           :=
                            l_source_line_rec.pricing_date;         -- ver 2.6

                        -- Begin 1.1
                        SELECT DECODE (l_operation_mode, 'XXD_ONT_CREATE', DECODE (l_cust_account_same, 'Y', l_source_line_rec.packing_instructions, fnd_api.g_miss_char), l_target_header_rec.packing_instructions), DECODE (l_operation_mode, 'XXD_ONT_CREATE', DECODE (l_cust_account_same, 'Y', l_source_line_rec.shipping_instructions, fnd_api.g_miss_char), l_target_header_rec.shipping_instructions), DECODE (l_operation_mode, 'XXD_ONT_CREATE', DECODE (l_cust_account_same, 'Y', l_source_header_rec.ship_to_org_id, fnd_api.g_miss_num), l_target_header_rec.ship_to_org_id), -- l_target_header_rec.ship_to_org_id
                               DECODE (l_operation_mode, 'XXD_ONT_CREATE', DECODE (l_cust_account_same, 'Y', l_source_line_rec.invoice_to_org_id, fnd_api.g_miss_num), l_target_header_rec.invoice_to_org_id) -- -- l_target_header_rec.ship_to_org_id
                          INTO l_line_tbl (1).packing_instructions, l_line_tbl (1).shipping_instructions, l_line_tbl (1).ship_to_org_id, l_line_tbl (1).invoice_to_org_id
                          FROM DUAL;

                        SELECT DECODE (l_operation_mode, 'XXD_ONT_CREATE', l_source_line_rec.attribute6, fnd_api.g_miss_char), DECODE (l_operation_mode, 'XXD_ONT_CREATE', l_source_line_rec.attribute7, fnd_api.g_miss_char), DECODE (l_operation_mode, 'XXD_ONT_CREATE', l_source_line_rec.attribute8, fnd_api.g_miss_char),
                               DECODE (l_operation_mode, 'XXD_ONT_CREATE', l_source_line_rec.attribute10, fnd_api.g_miss_char), DECODE (l_operation_mode, 'XXD_ONT_CREATE', l_source_line_rec.attribute13, fnd_api.g_miss_char), DECODE (l_operation_mode, 'XXD_ONT_CREATE', l_source_line_rec.attribute14, fnd_api.g_miss_char),
                               DECODE (l_operation_mode, 'XXD_ONT_CREATE', l_source_line_rec.attribute15, fnd_api.g_miss_char)
                          INTO l_line_tbl (1).attribute6, l_line_tbl (1).attribute7, l_line_tbl (1).attribute8, l_line_tbl (1).attribute10,
                                                        l_line_tbl (1).attribute13, l_line_tbl (1).attribute14, l_line_tbl (1).attribute15
                          FROM DUAL;

                        -- End 1.1
                        SELECT DECODE (l_cust_account_same, 'Y', l_source_line_rec.deliver_to_org_id, fnd_api.g_miss_num) -- ver 2.4 if customer is different then make it null
                          INTO l_line_tbl (1).deliver_to_org_id
                          FROM DUAL;

                        --  l_line_tbl(1).deliver_to_org_id := l_source_line_rec.deliver_to_org_id;  -- commented ver 2.4
                        l_line_tbl (1).source_document_type_id   :=
                            ln_order_source_id; --2; -- 2 for "Copy" -- ver 2.3
                        l_line_tbl (1).source_document_id     :=
                            l_source_line_rec.header_id;
                        l_line_tbl (1).source_document_line_id   :=
                            l_source_line_rec.line_id;

                        --Added for CCR0009521--
                        BEGIN
                            BEGIN
                                lv_color   := NULL;
                                lv_style   := NULL;

                                SELECT color_code, style_number
                                  INTO lv_color, lv_style
                                  FROM xxd_common_items_v
                                 WHERE     organization_id =
                                           NVL (
                                               l_line_tbl (1).ship_from_org_id,
                                               l_header_rec.ship_from_org_id)
                                       AND inventory_item_id =
                                           l_line_tbl (1).inventory_item_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_color   := NULL;
                                    lv_style   := NULL;
                            END;

                            l_line_tbl (1).attribute14   :=
                                xxd_ont_order_modify_pkg.get_vas_code (
                                    p_level         => 'LINE',
                                    p_cust_account_id   =>
                                        l_header_rec.sold_to_org_id,
                                    p_site_use_id   =>
                                        NVL (l_line_tbl (1).ship_to_org_id,
                                             l_header_rec.ship_to_org_id),
                                    p_style         => lv_style,
                                    p_color         => lv_color);
                        END;

                        --End for CCR0009521--

                        process_order (p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, p_action_request_tbl => l_action_request_tbl, x_header_rec => lx_header_rec, x_line_tbl => lx_line_tbl, x_return_status => lc_api_return_status
                                       , x_error_message => lc_error_message);

                        debug_msg (
                               'Order Line Creation Status = '
                            || lc_api_return_status);

                        IF lc_api_return_status <> 'S'
                        THEN
                            ROLLBACK TO source_order_line;
                            debug_msg (
                                   'Order Line Creation Error = '
                                || lc_error_message);
                        ELSE
                            -- Get SSD from OOLA
                            SELECT TRUNC (schedule_ship_date)
                              INTO ld_target_ssd
                              FROM oe_order_lines_all
                             WHERE line_id = lx_line_tbl (1).line_id;

                            -- If transaction is "Forced" then rollback when scheduling error

                            IF     ld_target_ssd IS NULL
                               AND lines_rec.attribute1 = 'N'
                            THEN
                                lc_api_return_status   := 'E';
                                lc_error_message       :=
                                    'Failed to Schedule Target Order';
                                ROLLBACK TO source_order_line;
                            ELSE
                                ln_target_header_id   :=
                                    lx_line_tbl (1).header_id;
                                ln_target_line_id   :=
                                    lx_line_tbl (1).line_id;
                            END IF;
                        END IF;
                    END IF;
                END IF;

                UPDATE xxd_ont_order_modify_details_t
                   SET target_header_id           =
                           DECODE (lc_api_return_status,
                                   'S', lx_header_rec.header_id,
                                   target_header_id),
                       target_order_number        =
                           DECODE (lc_api_return_status,
                                   'S', lx_header_rec.order_number,
                                   target_order_number),
                       target_order_type_id       =
                           DECODE (lc_api_return_status,
                                   'S', lx_header_rec.order_type_id,
                                   target_order_type_id),
                       target_order_type          =
                           DECODE (
                               lc_api_return_status,
                               'S', (SELECT name
                                       FROM oe_transaction_types_tl
                                      WHERE     language = USERENV ('LANG')
                                            AND transaction_type_id =
                                                lx_header_rec.order_type_id),
                               target_order_type),
                       target_sold_to_org_id      =
                           DECODE (lc_api_return_status,
                                   'S', lx_header_rec.sold_to_org_id,
                                   target_sold_to_org_id),
                       target_customer_number     =
                           DECODE (
                               lc_api_return_status,
                               'S', (SELECT account_number
                                       FROM hz_cust_accounts
                                      WHERE cust_account_id =
                                            lx_header_rec.sold_to_org_id),
                               target_customer_number),
                       target_line_id              = ln_target_line_id,
                       target_schedule_ship_date   = ld_target_ssd,
                       status                      = lc_api_return_status,
                       error_message              =
                           SUBSTR (error_message || lc_error_message,
                                   1,
                                   2000),
                       request_id                  = gn_request_id,
                       last_update_date            = SYSDATE,
                       last_update_login           = gn_login_id
                 WHERE     status = 'N'
                       AND batch_id = p_batch_id
                       AND GROUP_ID = p_group_id
                       AND source_header_id = lines_rec.source_header_id
                       AND source_line_id = lines_rec.source_line_id;

                debug_msg (
                       'End Time '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                debug_msg (
                       'Updated Status in Custom Table Record Count = '
                    || SQL%ROWCOUNT);
                debug_msg (RPAD ('=', 100, '='));
                COMMIT;
            END LOOP;
        END LOOP;

        -- begin  ver 2.2
        FOR i IN cpy_source_to_target_hdr_attachment_c
        LOOP
            copy_attachment (i.source_header_id,
                             i.target_header_id,
                             'OE_ORDER_HEADERS');
        END LOOP;

        -- end ver 2.2
        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in COPY_TO_EXISTING_ORDER_PRC = '
                || lc_error_message);
    END copy_to_order_prc;

    -- ======================================================================================
    -- This procedure performs below activities for eligible order lines
    -- 1. Performs Batching
    -- 2. Spawns child requests
    -- ======================================================================================

    PROCEDURE master_prc (x_errbuf              OUT NOCOPY VARCHAR2,
                          x_retcode             OUT NOCOPY VARCHAR2,
                          p_operation_mode   IN            VARCHAR2,
                          p_group_id         IN            NUMBER,
                          p_om_debug         IN            VARCHAR2,
                          p_custom_debug     IN            VARCHAR2)
    AS
        lc_sub_prog_name   VARCHAR2 (100) := 'MASTER_PRC';
        ln_req_id          NUMBER;
        ln_record_count    NUMBER := 0;
        ln_batch_id        NUMBER := 0;
        lc_req_data        VARCHAR2 (10);
        lc_status          VARCHAR2 (10);
    BEGIN
        lc_req_data   := fnd_conc_global.request_data;

        IF lc_req_data = 'MASTER'
        THEN
            RETURN;
        ELSE
            gc_debug_enable   :=
                NVL (gc_debug_enable, NVL (p_custom_debug, 'N'));
            debug_msg ('Start ' || lc_sub_prog_name);
            debug_msg (
                   'Start Time '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg (RPAD ('=', 100, '='));

            DELETE xxd_ont_order_modify_details_t
             WHERE     org_id = fnd_global.org_id                   -- ver 2.5
                   AND operation_mode != 'XXD_ONT_DTC_BULK_ROLLOVER'
                   AND creation_date < SYSDATE - 30;

            ln_record_count   := SQL%ROWCOUNT;

            IF ln_record_count > 0
            THEN
                debug_msg (
                       'Deleted 60 Days Older Records Count = '
                    || ln_record_count);
            END IF;

            debug_msg ('Perform Batching');

            -- Perform Batching
            IF p_operation_mode = 'XXD_ONT_UPDATE'
            THEN
                update_batch (p_group_id => p_group_id);
            ELSE
                ln_batch_id   := xxdo.xxd_ont_order_modify_details_s.NEXTVAL;

                UPDATE xxd_ont_order_modify_details_t
                   SET batch_id = ln_batch_id, parent_request_id = gn_request_id
                 WHERE     1 = 1
                       AND batch_id IS NULL
                       AND status = 'N'
                       AND GROUP_ID = p_group_id;

                COMMIT;
            END IF;

            debug_msg ('');
            debug_msg ('Submit Child Threads');

            -- Submit Child Programs
            FOR i
                IN (  SELECT DISTINCT batch_id
                        FROM xxd_ont_order_modify_details_t
                       WHERE     batch_id IS NOT NULL
                             AND status = 'N'
                             AND GROUP_ID = p_group_id
                    ORDER BY 1)
            LOOP
                ln_req_id   :=
                    fnd_request.submit_request (application => 'XXDO', program => 'XXD_ONT_ORDER_MODIFY_CHILD', description => NULL, start_time => NULL, sub_request => TRUE, argument1 => p_operation_mode, argument2 => p_group_id, argument3 => i.batch_id, argument4 => gc_debug_enable
                                                , argument5 => p_custom_debug);

                COMMIT;
            END LOOP;

            IF ln_req_id > 0
            THEN
                debug_msg ('Successfully Submitted Child Threads');
                fnd_conc_global.set_req_globals (conc_status    => 'PAUSED',
                                                 request_data   => 'MASTER');
            END IF;

            debug_msg (
                'Successfully SSD Updated Record Count = ' || SQL%ROWCOUNT);
        END IF;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
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
            debug_msg ('End ' || lc_sub_prog_name);
    END master_prc;

    -- ======================================================================================
    -- This procedure performs order line updates for eligible order lines
    -- ======================================================================================

    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_operation_mode IN VARCHAR2, p_group_id IN NUMBER, p_batch_id IN NUMBER, p_om_debug IN VARCHAR2
                         , p_custom_debug IN VARCHAR2)
    AS
        lc_sub_prog_name   VARCHAR2 (100) := 'CHILD_PRC';
        lc_error_message   VARCHAR2 (4000);
        lc_debug_mode      VARCHAR2 (50);
    BEGIN
        gc_debug_enable   := NVL (gc_debug_enable, NVL (p_custom_debug, 'N'));

        IF p_om_debug = 'Y'
        THEN
            oe_debug_pub.debug_on;
            oe_debug_pub.setdebuglevel (5);
            lc_debug_mode   := oe_debug_pub.set_debug_mode ('CONC');
        END IF;

        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        IF p_operation_mode = 'XXD_ONT_UPDATE'
        THEN
            update_order_prc (p_group_id   => p_group_id,
                              p_batch_id   => p_batch_id);
        ELSIF p_operation_mode <> 'XXD_ONT_UPDATE'
        THEN
            copy_to_order_prc (p_group_id   => p_group_id,
                               p_batch_id   => p_batch_id);
        END IF;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
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
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in CHILD_PRC = ' || lc_error_message);
    END child_prc;

    -- ======================================================================================
    -- This procedure will be called from Sales Order Modify OA page
    -- ======================================================================================

    PROCEDURE process_order_prc (
        p_operation_mode       IN            VARCHAR2,
        p_group_id             IN            NUMBER,
        p_org_id               IN            NUMBER,
        p_resp_id              IN            NUMBER,
        p_resp_app_id          IN            NUMBER,
        p_user_id              IN            NUMBER,
        p_order_dtls_tbl_typ   IN            xxd_ont_order_dtls_tbl_typ,
        p_om_debug             IN            VARCHAR2,
        p_custom_debug         IN            VARCHAR2,
        x_ret_status              OUT NOCOPY VARCHAR2,
        x_err_msg                 OUT NOCOPY VARCHAR2)
    AS
        lc_status         VARCHAR2 (10);
        lc_ret_status     VARCHAR2 (1);
        ln_record_count   NUMBER := 0;
        ln_valid_count    NUMBER := 0;
        ln_req_id         NUMBER;
    BEGIN
        gn_org_id              := p_org_id;
        gn_user_id             := p_user_id;
        gn_application_id      := p_resp_app_id;
        gn_responsibility_id   := p_resp_id;
        lc_status              := xxd_ont_check_plan_run_fnc ();
        init ();
        x_ret_status           := 'S';

        IF lc_status = 'N'
        THEN
            -- Insert records in custom table
            insert_prc (p_operation_mode => p_operation_mode, p_group_id => p_group_id, p_order_dtls_tbl_typ => p_order_dtls_tbl_typ
                        , x_record_count => ln_record_count);

            IF ln_record_count > 0
            THEN
                COMMIT;
                -- Validate records
                validate_prc (p_operation_mode   => p_operation_mode,
                              p_group_id         => p_group_id);

                SELECT COUNT (1)
                  INTO ln_valid_count
                  FROM xxd_ont_order_modify_details_t
                 WHERE status = 'N' AND GROUP_ID = p_group_id;

                IF ln_valid_count > 0
                THEN
                    COMMIT;
                    ln_req_id   := 0;
                    ln_req_id   :=
                        fnd_request.submit_request (
                            application   => 'XXDO',
                            program       => 'XXD_ONT_ORDER_MODIFY_MASTER',
                            description   => NULL,
                            start_time    => NULL,
                            sub_request   => NULL,
                            argument1     => p_operation_mode,
                            argument2     => p_group_id,
                            argument3     => p_om_debug,
                            argument4     => p_custom_debug);

                    IF ln_req_id > 0
                    THEN
                        COMMIT;
                        x_ret_status   := 'S';
                    ELSE
                        ROLLBACK;
                        x_err_msg      :=
                            'Unable to submit master concurrent program';
                        x_ret_status   := 'E';
                    END IF;
                END IF;
            ELSE
                ROLLBACK;
                x_err_msg      := 'No Data Found';
                x_ret_status   := 'E';
            END IF;
        ELSE
            ROLLBACK;
            x_err_msg      :=
                'Planning Programs are running in ASCP. Order Update Program cannot run now';
            x_ret_status   := 'E';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_err_msg      := SUBSTR (SQLERRM, 1, 2000);
            x_ret_status   := 'E';

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = x_err_msg, request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE GROUP_ID = p_group_id;

            COMMIT;
    END process_order_prc;

    /*---------------------------2.0 Start GSA Project-----------------------------------*/

    -- ======================================================================================
    -- This procedure called from OA and copy the existing order and create the new order
    -- ======================================================================================

    PROCEDURE xxd_ont_order_mgt_copy_prc (p_ont_ord_copy_tbl xxdo.xxd_ont_order_copy_tbl_type, p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_om_debug IN VARCHAR2, p_custom_debug IN VARCHAR2, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2
                                          , pv_group_id OUT NUMBER)
    AS
        CURSOR cur_copy (p_order_number NUMBER, p_include_cancelled_lines VARCHAR2, p_include_closed_lines VARCHAR2)
        IS
            (SELECT ooha.org_id,
                    ooha.header_id,
                    ooha.order_number,
                    (SELECT account_number
                       FROM hz_cust_accounts
                      WHERE cust_account_id = ooha.sold_to_org_id)
                        source_cust_account,
                    ooha.sold_to_org_id,
                    ooha.cust_po_number,
                    (SELECT name
                       FROM oe_transaction_types_tl
                      WHERE     language = USERENV ('LANG')
                            AND transaction_type_id = ooha.order_type_id)
                        source_order_type,
                    ooha.order_type_id
                        source_order_type_id,
                    ooha.request_date,
                    ooha.attribute5,
                    oola.line_id,
                    oola.line_number || '.' || oola.shipment_number
                        source_line_number,
                    oola.ordered_item,
                    oola.inventory_item_id,
                    oola.ordered_quantity,
                    oola.schedule_ship_date,
                    oola.sold_to_org_id
                        line_sold_to_org_id,
                    oola.latest_acceptable_date,                 -- Source End
                    (SELECT account_number
                       FROM hz_cust_accounts
                      WHERE cust_account_id = ooha.sold_to_org_id)
                        target_customer_number,
                    ooha.demand_class_code,
                    ooha.freight_carrier_code,
                    ooha.freight_terms_code,              -- Target Header End
                    ooha.payment_type_code,
                    oola.ordered_item
                        target_ordered_item,              -- Target Line Start
                    oola.inventory_item_id
                        target_inventory_item_id,
                    oola.ordered_quantity
                        target_ordered_quantity,
                    oola.request_date
                        target_request_date,
                    oola.schedule_ship_date
                        target_schedule_ship_date,
                    oola.latest_acceptable_date
                        target_latest_acceptable_date,
                    oola.line_type_id
                        target_order_type_id,
                    NULL
                        target_line_cancel_date,
                    oola.ship_from_org_id
                        target_ship_from_org,
                    ooha.sold_from_org_id,
                    oola.demand_class_code
                        target_line_demand_class,
                    oola.freight_carrier_code
                        target_line_freight_carrier,
                    oola.freight_terms_code
                        target_line_freight_terms,
                    oola.payment_term_id
                        target_line_payment_term,
                    NULL
                        target_change_reason,
                    oola.cancelled_quantity
               FROM oe_order_headers_all ooha, oe_order_lines_all oola
              WHERE     ooha.header_id = oola.header_id
                    --                 AND ooha.open_flag = 'Y'
                    AND oola.open_flag IN
                            ('Y', DECODE (NVL (p_include_closed_lines, 'X'),  'Y', 'N',  'N', 'Y',  'X', 'Y',  'Y'))
                    AND oola.cancelled_flag IN
                            ('N', DECODE (NVL (p_include_cancelled_lines, 'X'),  'Y', 'Y',  'N', 'N',  'X', 'N',  'N'))
                    AND ooha.booked_flag IN ('Y', 'N')
                    AND ooha.order_number = p_order_number)
            ORDER BY line_number;

        lv_error_msg        VARCHAR2 (4000) := NULL;
        lv_error_stat       VARCHAR2 (4) := 'S';
        lv_error_code       VARCHAR2 (4000) := NULL;
        ln_error_num        NUMBER;
        ln_group_id         NUMBER;
        lv_ret_status       VARCHAR2 (40) := NULL;
        lv_err_msg          VARCHAR2 (4000) := NULL;
        ln_num_seq          NUMBER := 0;

        TYPE vld_record_typ IS TABLE OF cur_copy%ROWTYPE;

        lv_vld_record_typ   vld_record_typ := vld_record_typ ();

        TYPE ins_rec_type IS TABLE OF xxd_ont_order_modify_details_t%ROWTYPE;

        v_ins_tbl_type      ins_rec_type := ins_rec_type ();
    BEGIN
        v_ins_tbl_type.DELETE;
        ln_group_id   := xxdo.xxd_ont_order_modify_batch_s.NEXTVAL;
        pv_group_id   := ln_group_id;

        BEGIN
            FOR j IN p_ont_ord_copy_tbl.FIRST .. p_ont_ord_copy_tbl.LAST
            LOOP
                lv_vld_record_typ.DELETE;
                ln_num_seq   := ln_num_seq + 1;

                OPEN cur_copy (
                    p_ont_ord_copy_tbl (j).order_number,
                    p_ont_ord_copy_tbl (j).include_cancelled_lines,
                    p_ont_ord_copy_tbl (j).include_closed_lines);

                FETCH cur_copy BULK COLLECT INTO lv_vld_record_typ;

                CLOSE cur_copy;

                IF (lv_vld_record_typ.COUNT > 0)
                THEN
                    FOR i IN lv_vld_record_typ.FIRST ..
                             lv_vld_record_typ.LAST
                    LOOP
                        v_ins_tbl_type.EXTEND;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).GROUP_ID   :=
                            ln_group_id;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).org_id   :=
                            lv_vld_record_typ (i).org_id;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).operation_mode   :=
                            'XXD_ONT_COPY';
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_header_id   :=
                            lv_vld_record_typ (i).header_id;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_order_number   :=
                            lv_vld_record_typ (i).order_number;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_cust_account   :=
                            lv_vld_record_typ (i).source_cust_account;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_sold_to_org_id   :=
                            lv_vld_record_typ (i).line_sold_to_org_id;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_cust_po_number   :=
                            lv_vld_record_typ (i).cust_po_number;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_order_type   :=
                            lv_vld_record_typ (i).source_order_type;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_header_request_date   :=
                            lv_vld_record_typ (i).request_date;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_line_id   :=
                            lv_vld_record_typ (i).line_id;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_line_number   :=
                            lv_vld_record_typ (i).source_line_number;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_ordered_item   :=
                            lv_vld_record_typ (i).ordered_item;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_inventory_item_id   :=
                            lv_vld_record_typ (i).inventory_item_id;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_ordered_quantity   :=
                            lv_vld_record_typ (i).ordered_quantity;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_line_request_date   :=
                            lv_vld_record_typ (i).request_date;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_schedule_ship_date   :=
                            lv_vld_record_typ (i).schedule_ship_date;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).source_latest_acceptable_date   :=
                            lv_vld_record_typ (i).latest_acceptable_date;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_customer_number   :=
                            lv_vld_record_typ (i).target_customer_number;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_sold_to_org_id   :=
                            lv_vld_record_typ (i).sold_to_org_id;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_order_number   :=
                            NULL;         --lv_vld_record_typ(i).ORDER_NUMBER;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_id   :=
                            NULL;            --lv_vld_record_typ(i).HEADER_ID;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_cust_po_num   :=
                            p_ont_ord_copy_tbl (j).cust_po_number;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_order_type   :=
                            NULL;          --p_ont_ord_copy_tbl(j).attribute1;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_order_type_id   :=
                            p_ont_ord_copy_tbl (j).attribute1; --nvl(p_ont_ord_copy_tbl(j).attribute1,lv_vld_record_typ(i).source_order_type_id);
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_request_date   :=
                            p_ont_ord_copy_tbl (j).header_request_date;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_cancel_date   :=
                            NVL (
                                p_ont_ord_copy_tbl (j).lad,
                                lv_vld_record_typ (i).target_line_cancel_date);

                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_demand_class   :=
                            lv_vld_record_typ (i).target_line_demand_class;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_ship_method   :=
                            NVL (p_ont_ord_copy_tbl (j).shipping_method_code,
                                 p_ont_ord_copy_tbl (j).shipping_method_code);

                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_freight_carrier   :=
                            lv_vld_record_typ (i).target_line_freight_carrier;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_freight_terms   :=
                            lv_vld_record_typ (i).target_line_freight_terms;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_payment_term   :=
                            lv_vld_record_typ (i).target_line_payment_term;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_id   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_ordered_item   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_inventory_item_id   :=
                            NULL;

                        IF ('Y' = NVL (p_ont_ord_copy_tbl (j).include_cancelled_lines, 'N') OR 'Y' = NVL (p_ont_ord_copy_tbl (j).include_closed_lines, 'N'))
                        THEN
                            v_ins_tbl_type (v_ins_tbl_type.LAST).target_ordered_quantity   :=
                                  NVL (
                                      lv_vld_record_typ (i).ordered_quantity,
                                      0)
                                + NVL (
                                      lv_vld_record_typ (i).cancelled_quantity,
                                      0);
                        ELSE
                            v_ins_tbl_type (v_ins_tbl_type.LAST).target_ordered_quantity   :=
                                lv_vld_record_typ (i).ordered_quantity;
                        END IF;

                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_request_date   :=
                            p_ont_ord_copy_tbl (j).header_request_date;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_schedule_ship_date   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_latest_acceptable_date   :=
                            p_ont_ord_copy_tbl (j).lad;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_cancel_date   :=
                            p_ont_ord_copy_tbl (j).lad;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_ship_from_org   :=
                            p_ont_ord_copy_tbl (j).warehouse;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_ship_from_org_id   :=
                            p_ont_ord_copy_tbl (j).warehouse;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_demand_class   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_ship_method   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_freight_carrier   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_freight_terms   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_payment_term   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_change_reason   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).target_change_reason_code   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute1   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute2   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute3   :=
                            ln_num_seq;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute4   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute5   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute6   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute7   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute8   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute9   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute10   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute11   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute12   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute13   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute14   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).attribute15   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).batch_id   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).status   := 'N';
                        v_ins_tbl_type (v_ins_tbl_type.LAST).error_message   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).parent_request_id   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).request_id   :=
                            NULL;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).creation_date   :=
                            SYSDATE;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).created_by   :=
                            fnd_global.user_id;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).last_update_date   :=
                            SYSDATE;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).last_updated_by   :=
                            fnd_global.user_id;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).last_update_login   :=
                            fnd_global.login_id;
                        v_ins_tbl_type (v_ins_tbl_type.LAST).record_id   :=
                            xxdo.XXD_ONT_ORDER_MODIFY_DETAILS_REC_S.NEXTVAL; -- Added as per CCR0010520
                    END LOOP;
                ELSE
                    v_ins_tbl_type.EXTEND;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).GROUP_ID   :=
                        ln_group_id;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).org_id   := NULL; --lv_vld_record_typ (i).org_id;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).operation_mode   :=
                        'XXD_ONT_COPY';
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_header_id   :=
                        NULL;               --lv_vld_record_typ (i).header_id;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_order_number   :=
                        p_ont_ord_copy_tbl (j).order_number; --lv_vld_record_typ (i).order_number;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_cust_account   :=
                        NULL;     --lv_vld_record_typ (i).source_cust_account;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_sold_to_org_id   :=
                        NULL;     --lv_vld_record_typ (i).line_sold_to_org_id;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_cust_po_number   :=
                        NULL;          --lv_vld_record_typ (i).cust_po_number;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_order_type   :=
                        NULL;       --lv_vld_record_typ (i).source_order_type;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_header_request_date   :=
                        NULL;            --lv_vld_record_typ (i).request_date;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_line_id   :=
                        NULL;                 --lv_vld_record_typ (i).line_id;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_line_number   :=
                        NULL;      --lv_vld_record_typ (i).source_line_number;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_ordered_item   :=
                        NULL;            --lv_vld_record_typ (i).ordered_item;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_inventory_item_id   :=
                        NULL;       --lv_vld_record_typ (i).inventory_item_id;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_ordered_quantity   :=
                        NULL;        --lv_vld_record_typ (i).ordered_quantity;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_line_request_date   :=
                        NULL;            --lv_vld_record_typ (i).request_date;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_schedule_ship_date   :=
                        NULL;      --lv_vld_record_typ (i).schedule_ship_date;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).source_latest_acceptable_date   :=
                        NULL;  --lv_vld_record_typ (i).latest_acceptable_date;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_customer_number   :=
                        NULL;  --lv_vld_record_typ (i).target_customer_number;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_sold_to_org_id   :=
                        NULL;          --lv_vld_record_typ (i).sold_to_org_id;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_order_number   :=
                        NULL;             --lv_vld_record_typ(i).ORDER_NUMBER;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_id   :=
                        NULL;                --lv_vld_record_typ(i).HEADER_ID;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_cust_po_num   :=
                        p_ont_ord_copy_tbl (j).cust_po_number;
                    --v_ins_tbl_type(v_ins_tbl_type.LAST).TARGET_ORDER_TYPE:=p_ont_ord_copy_tbl(j).attribute1;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_order_type_id   :=
                        p_ont_ord_copy_tbl (j).attribute1; --nvl(p_ont_ord_copy_tbl(j).attribute1,lv_vld_record_typ(i).source_order_type_id);
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_request_date   :=
                        p_ont_ord_copy_tbl (j).header_request_date;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_cancel_date   :=
                        p_ont_ord_copy_tbl (j).lad;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_demand_class   :=
                        NULL; --lv_vld_record_typ (i).target_line_demand_class;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_ship_method   :=
                        NVL (p_ont_ord_copy_tbl (j).shipping_method_code,
                             p_ont_ord_copy_tbl (j).shipping_method_code);

                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_freight_carrier   :=
                        NULL; --lv_vld_record_typ (i).target_line_freight_carrier;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_freight_terms   :=
                        NULL; --lv_vld_record_typ (i).target_line_freight_terms;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_header_payment_term   :=
                        NULL; --lv_vld_record_typ (i).target_line_payment_term;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_id   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_ordered_item   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_inventory_item_id   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_ordered_quantity   :=
                        NULL;        --lv_vld_record_typ (i).ordered_quantity;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_request_date   :=
                        p_ont_ord_copy_tbl (j).header_request_date;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_schedule_ship_date   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_latest_acceptable_date   :=
                        p_ont_ord_copy_tbl (j).lad;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_cancel_date   :=
                        p_ont_ord_copy_tbl (j).lad;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_ship_from_org   :=
                        p_ont_ord_copy_tbl (j).warehouse;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_ship_from_org_id   :=
                        p_ont_ord_copy_tbl (j).warehouse;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_demand_class   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_ship_method   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_freight_carrier   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_freight_terms   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_line_payment_term   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_change_reason   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).target_change_reason_code   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute1   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute2   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute3   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute4   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute5   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute6   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute7   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute8   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute9   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute10   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute11   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute12   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute13   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute14   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).attribute15   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).batch_id   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).status   :=
                        'E';
                    v_ins_tbl_type (v_ins_tbl_type.LAST).error_message   :=
                        'All Lines Are Closed Or Cancelled';
                    v_ins_tbl_type (v_ins_tbl_type.LAST).parent_request_id   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).request_id   :=
                        NULL;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).creation_date   :=
                        SYSDATE;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).created_by   :=
                        fnd_global.user_id;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).last_update_date   :=
                        SYSDATE;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).last_updated_by   :=
                        fnd_global.user_id;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).last_update_login   :=
                        fnd_global.login_id;
                    v_ins_tbl_type (v_ins_tbl_type.LAST).record_id   :=
                        xxdo.XXD_ONT_ORDER_MODIFY_DETAILS_REC_S.NEXTVAL; -- Added as per CCR0010520
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                       lv_error_msg
                    || 'Error While Collect The Data  '
                    || SQLERRM;
        END;

        IF (v_ins_tbl_type.COUNT > 0)
        THEN
            BEGIN
                FORALL i IN v_ins_tbl_type.FIRST .. v_ins_tbl_type.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxd_ont_order_modify_details_t
                         VALUES v_ins_tbl_type (i);
            --            COMMIT;

            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';

                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        ln_error_num    := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                        lv_error_code   :=
                            SQLERRM (-1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                        lv_error_stat   := 'E';
                        lv_error_msg    :=
                            SUBSTR (
                                (lv_error_msg || ' Error While Insert into Table ' || v_ins_tbl_type (ln_error_num).source_order_number || lv_error_code),
                                1,
                                4000);
                    END LOOP;
            END;
        END IF;

        IF (lv_error_stat = 'E')
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            --pv_error_stat := 'S';
            --COMMIT;
            gn_org_id              := p_org_id;
            gn_user_id             := p_user_id;
            gn_application_id      := p_resp_app_id;
            gn_responsibility_id   := p_resp_id;
            submit_book_cancel_updat_order (p_operation_mode => 'XXD_ONT_COPY', p_group_id => ln_group_id, p_org_id => p_org_id, p_resp_id => p_resp_id, p_resp_app_id => p_resp_app_id, p_user_id => p_user_id, p_om_debug => p_om_debug, p_custom_debug => p_custom_debug, x_ret_status => lv_ret_status
                                            , x_err_msg => lv_err_msg);

            pv_error_stat          := lv_ret_status;
            --pv_error_msg := lv_err_msg || ' Successfully Submitted';
            pv_error_msg           := lv_err_msg;

            IF (pv_error_stat = 'E')
            THEN
                ROLLBACK;
            ELSE
                COMMIT;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                lv_error_msg || 'Error While Inserting The Data  ' || SQLERRM;
    END xxd_ont_order_mgt_copy_prc;

    -- ======================================================================================
    -- This procedure called from OA to Load the Book Order Data from CSV file
    -- ======================================================================================

    PROCEDURE process_book_order_file (p_file_id IN NUMBER, p_org_id IN NUMBER, p_operation_mode IN VARCHAR2
                                       , x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, x_file_id OUT NOCOPY VARCHAR2)
    AS
        lv_error_msg        VARCHAR2 (4000) := NULL;
        lv_error_stat       VARCHAR2 (4) := 'S';
        lv_error_code       VARCHAR2 (4000) := NULL;
        ln_error_num        NUMBER;
        ln_operation_mode   VARCHAR2 (100);
        ln_group_id         NUMBER;
        ln_req_id           NUMBER;
        lc_status           VARCHAR2 (10);
        ln_record_count     NUMBER;
        ln_valid_count      NUMBER;
        ln_hold_count       NUMBER;
        ln_line_num         NUMBER := 0;

        CURSOR cur_val IS
            (SELECT TRANSLATE (REGEXP_SUBSTR (x.col1 || ',', '([^,]*),|$', 1,
                                              1, NULL, 1),
                               'x' || CHR (10) || CHR (13),
                               'x') order_number,
                    attribute1,
                    src.file_id,
                    src.file_name,
                    NULL status,
                    NULL erg_msg,
                    NULL oe_header_id,
                    NULL request_date,
                    NULL cancel_date,
                    NULL po_number,
                    NULL cancelled_flag,
                    NULL booked_flag,
                    NULL open_flag,
                    NULL line_num
               FROM xxdo.xxd_file_upload_t src, XMLTABLE ('/a/b' PASSING xmltype ('<a><b>' || REPLACE (xxd_common_utils.conv_to_clob (src.file_data), CHR (10), '</b><b>') || '</b></a>') COLUMNS col1 VARCHAR2 (2000) PATH '.') x
              WHERE     1 = 1
                    AND file_source = 'GSA'
                    AND file_id = p_file_id
                    AND REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                       1)
                            IS NOT NULL
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             'ORDER%')
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             '%NUMBER'))
            ORDER BY ROWNUM;

        TYPE xxd_insert_book_ord_typ IS TABLE OF cur_val%ROWTYPE;

        v_ins_type          xxd_insert_book_ord_typ
                                := xxd_insert_book_ord_typ ();
    BEGIN
        BEGIN
            x_file_id   := xxdo.xxd_ont_order_modify_batch_s.NEXTVAL;

            OPEN cur_val;

            LOOP
                FETCH cur_val BULK COLLECT INTO v_ins_type LIMIT 1000;

                IF (v_ins_type.COUNT > 0)
                THEN
                    FOR x IN v_ins_type.FIRST .. v_ins_type.LAST
                    LOOP
                        BEGIN
                            ln_line_num               := ln_line_num + 1;
                            v_ins_type (x).line_num   := ln_line_num;

                            SELECT ooh.header_id, cust_po_number, request_date,
                                   attribute1, cancelled_flag, open_flag,
                                   booked_flag
                              INTO v_ins_type (x).oe_header_id, v_ins_type (x).po_number, v_ins_type (x).request_date, v_ins_type (x).cancel_date,
                                                              v_ins_type (x).cancelled_flag, v_ins_type (x).open_flag, v_ins_type (x).booked_flag
                              FROM oe_order_headers_all ooh
                             WHERE ooh.order_number =
                                   v_ins_type (x).order_number;

                            IF (v_ins_type (x).cancelled_flag = 'Y')
                            THEN
                                v_ins_type (x).status   := 'E';
                                --                                    v_ins_type(x).erg_msg :=substr(v_ins_type(x).erg_msg||' Order is Cancelled; ',1,2000) ;
                                v_ins_type (x).erg_msg   :=
                                    'Order is not eligibile for current operation';
                            END IF;

                            IF (v_ins_type (x).open_flag = 'N')
                            THEN
                                v_ins_type (x).status   := 'E';
                                --                                    v_ins_type(x).erg_msg := substr(v_ins_type(x).erg_msg||' Order is Not in Open Status; ',1,2000);
                                v_ins_type (x).erg_msg   :=
                                    'Order is not eligibile for current operation';
                            END IF;

                            IF (v_ins_type (x).booked_flag = 'Y')
                            THEN
                                v_ins_type (x).status   := 'E';
                                --                                    v_ins_type(x).erg_msg := substr(v_ins_type(x).erg_msg||' Order is Already Booked ',1,2000);
                                v_ins_type (x).erg_msg   :=
                                    'Order is not eligibile for current operation';
                            END IF;

                            IF (v_ins_type (x).oe_header_id IS NOT NULL)
                            THEN
                                BEGIN
                                    /*SELECT COUNT (1)
                                      INTO ln_hold_count
                                      FROM oe_processing_msgs e,
                                           oe_processing_msgs_tl me
                                     WHERE     e.transaction_id = me.transaction_id
                                           AND e.header_id =
                                                  v_ins_type (x).oe_header_id;*/
                                    SELECT COUNT (1)
                                      INTO ln_hold_count
                                      FROM oe_order_holds_all
                                     WHERE     released_flag = 'N'
                                           AND line_id IS NULL
                                           AND header_id =
                                               v_ins_type (x).oe_header_id;

                                    IF (ln_hold_count > 0)
                                    THEN
                                        v_ins_type (x).status   := 'E';
                                        v_ins_type (x).erg_msg   :=
                                            'A hold prevents booking of this order';
                                    END IF;
                                END;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                    'Order is not eligibile for current operation';
                        END;
                    END LOOP;
                END IF;

                IF (v_ins_type.COUNT > 0)
                THEN
                    BEGIN
                        FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO xxd_ont_order_modify_details_t (
                                            source_order_number,
                                            source_header_id,
                                            status,
                                            error_message,
                                            attribute2,
                                            GROUP_ID,
                                            org_id,
                                            operation_mode,
                                            source_cust_po_number,
                                            source_header_request_date,
                                            target_header_cancel_date,
                                            attribute3,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            record_id --  Added as per CCR0010520
                                                     )
                                     VALUES (
                                                v_ins_type (i).order_number,
                                                v_ins_type (i).oe_header_id,
                                                NVL (v_ins_type (i).status,
                                                     'I'), --NVL (v_ins_type (i).status, 'N'),
                                                v_ins_type (i).erg_msg, -- NVL(v_ins_type(i).erg_msg,'Yet To Process'),
                                                p_file_id,
                                                x_file_id,
                                                p_org_id,
                                                p_operation_mode,
                                                v_ins_type (i).po_number,
                                                v_ins_type (i).request_date,
                                                apps.fnd_date.canonical_to_date (
                                                    (v_ins_type (i).cancel_date)),
                                                v_ins_type (i).line_num,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                fnd_global.login_id,
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
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg    :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Inserting into Table For Order Number' || v_ins_type (ln_error_num).order_number || lv_error_code || ' #'),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                END IF;

                EXIT WHEN cur_val%NOTFOUND;
            END LOOP;

            CLOSE cur_val;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                       lv_error_msg
                    || 'Error While Collect The Data  '
                    || SQLERRM;
        END;

        IF (lv_error_stat = 'E')
        THEN
            x_ret_status   := 'E';
            x_err_msg      :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            x_ret_status   := 'S';
            x_err_msg      :=
                   lv_error_msg
                || ' Successfully Records Inserted, Please Click on Submit To Book Order ';

            UPDATE xxd_ont_order_modify_details_t
               SET GROUP_ID   = x_file_id
             WHERE     status = 'I'
                   AND created_by = fnd_global.user_id
                   AND operation_mode = 'XXD_ONT_BOOK';

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := 'Error While Inserting to Table ' || SQLERRM;
            ROLLBACK;
    END process_book_order_file;

    -- ======================================================================================
    -- This procedure called from OA to Load the Cancel Order Data from CSV file
    -- ======================================================================================

    PROCEDURE process_cancel_order_file (p_file_id IN NUMBER, p_org_id IN NUMBER, p_operation_mode IN VARCHAR2
                                         , x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, x_file_id OUT NOCOPY VARCHAR2)
    AS
        lv_error_msg        VARCHAR2 (4000) := NULL;
        lv_error_stat       VARCHAR2 (4) := 'S';
        lv_error_code       VARCHAR2 (4000) := NULL;
        ln_error_num        NUMBER;
        ln_operation_mode   VARCHAR2 (100);
        ln_group_id         NUMBER;
        ln_req_id           NUMBER;
        lc_status           VARCHAR2 (10);
        ln_record_count     NUMBER;
        ln_valid_count      NUMBER;
        ln_line_num         NUMBER := 0;

        CURSOR cur_val IS
            (SELECT TRANSLATE (REGEXP_SUBSTR (x.col1 || ',', '([^,]*),|$', 1,
                                              1, NULL, 1),
                               'x' || CHR (10) || CHR (13),
                               'x') order_number,
                    attribute1,
                    src.file_id,
                    src.file_name,
                    NULL status,
                    NULL erg_msg,
                    NULL oe_header_id,
                    NULL request_date,
                    NULL cancel_date,
                    NULL po_number,
                    NULL cancelled_flag,
                    NULL open_flag,
                    NULL line_num
               FROM xxdo.xxd_file_upload_t src, XMLTABLE ('/a/b' PASSING xmltype ('<a><b>' || REPLACE (xxd_common_utils.conv_to_clob (src.file_data), CHR (10), '</b><b>') || '</b></a>') COLUMNS col1 VARCHAR2 (2000) PATH '.') x
              WHERE     1 = 1
                    AND file_source = 'GSA'
                    AND file_id = p_file_id
                    AND REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                       1)
                            IS NOT NULL
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             'ORDER%')
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             '%NUMBER'));

        TYPE xxd_insert_book_ord_typ IS TABLE OF cur_val%ROWTYPE;

        v_ins_type          xxd_insert_book_ord_typ
                                := xxd_insert_book_ord_typ ();
    BEGIN
        BEGIN
            x_file_id   := xxdo.xxd_ont_order_modify_batch_s.NEXTVAL;

            OPEN cur_val;

            LOOP
                FETCH cur_val BULK COLLECT INTO v_ins_type LIMIT 1000;

                IF (v_ins_type.COUNT > 0)
                THEN
                    FOR x IN v_ins_type.FIRST .. v_ins_type.LAST
                    LOOP
                        ln_line_num               := ln_line_num + 1;
                        v_ins_type (x).line_num   := ln_line_num;

                        BEGIN
                            SELECT ooh.header_id, cust_po_number, request_date,
                                   attribute1, cancelled_flag, open_flag
                              INTO v_ins_type (x).oe_header_id, v_ins_type (x).po_number, v_ins_type (x).request_date, v_ins_type (x).cancel_date,
                                                              v_ins_type (x).cancelled_flag, v_ins_type (x).open_flag
                              FROM oe_order_headers_all ooh
                             WHERE ooh.order_number =
                                   v_ins_type (x).order_number;

                            IF (v_ins_type (x).cancelled_flag = 'Y')
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                    'Order is not eligibile for current operation';
                            END IF;

                            IF (v_ins_type (x).open_flag = 'N')
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                    'Order is not eligibile for current operation';
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                    'Order is not eligibile for current operation';
                        END;
                    END LOOP;
                END IF;

                IF (v_ins_type.COUNT > 0)
                THEN
                    BEGIN
                        FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO xxd_ont_order_modify_details_t (
                                            source_order_number,
                                            source_header_id,
                                            status,
                                            error_message,
                                            attribute2,
                                            GROUP_ID,
                                            org_id,
                                            operation_mode,
                                            source_cust_po_number,
                                            source_header_request_date,
                                            target_header_cancel_date,
                                            attribute3,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            record_id -- Added as per CCR0010520
                                                     )
                                     VALUES (
                                                v_ins_type (i).order_number,
                                                v_ins_type (i).oe_header_id,
                                                NVL (v_ins_type (i).status,
                                                     'I'), --NVL (v_ins_type (i).status, 'N'),
                                                v_ins_type (i).erg_msg,
                                                p_file_id,
                                                x_file_id,
                                                p_org_id,
                                                p_operation_mode,
                                                v_ins_type (i).po_number,
                                                v_ins_type (i).request_date,
                                                apps.fnd_date.canonical_to_date (
                                                    (v_ins_type (i).cancel_date)),
                                                v_ins_type (i).line_num,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                fnd_global.login_id,
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
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg    :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Inserting into Table' || v_ins_type (ln_error_num).order_number || lv_error_code || ' #'),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                END IF;

                EXIT WHEN cur_val%NOTFOUND;
            END LOOP;

            CLOSE cur_val;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                       lv_error_msg
                    || 'Error While Collect The Data  '
                    || SQLERRM;
        END;

        IF (lv_error_stat = 'E')
        THEN
            x_ret_status   := 'E';
            x_err_msg      :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            x_ret_status   := 'S';
            x_err_msg      :=
                   lv_error_msg
                || ' Successfully Records Inserted, Please Click on Submit To Cancel Order';

            UPDATE xxd_ont_order_modify_details_t
               SET GROUP_ID   = x_file_id
             WHERE     status = 'I'
                   AND created_by = fnd_global.user_id
                   AND operation_mode = 'XXD_ONT_CANCEL';

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := 'Error While Inserting to Table ' || SQLERRM;
            ROLLBACK;
    END process_cancel_order_file;

    -- ======================================================================================
    -- This procedure performs below activities for eligible order lines
    -- 1. Performs Batching
    -- 2. Spawns child requests
    -- ======================================================================================

    PROCEDURE book_cancel_order_mast_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_operation_mode IN VARCHAR2, p_group_id IN NUMBER, p_om_debug IN VARCHAR2, p_custom_debug IN VARCHAR2
                                          , p_freeAtp_flag IN VARCHAR2 -- ver 2.4
                                                                      )
    AS
        lc_sub_prog_name   VARCHAR2 (100) := 'MASTER_BOOK_CANEL_PRC';
        ln_req_id          NUMBER;
        ln_record_count    NUMBER := 0;
        ln_batch_id        NUMBER := 0;
        lc_req_data        VARCHAR2 (10);
        lc_status          VARCHAR2 (10);
    BEGIN
        lc_req_data   := fnd_conc_global.request_data;

        IF lc_req_data = 'MASTER'
        THEN
            RETURN;
        ELSE
            gc_debug_enable   :=
                NVL (gc_debug_enable, NVL (p_custom_debug, 'N'));
            debug_msg ('Start ' || lc_sub_prog_name);
            debug_msg (
                   'Start Time '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg (RPAD ('=', 100, '='));

            DELETE xxd_ont_order_modify_details_t
             WHERE     org_id = FND_GLOBAL.ORG_ID
                   AND operation_mode != 'XXD_ONT_DTC_BULK_ROLLOVER'
                   AND creation_date < SYSDATE - 30;

            COMMIT;
            ln_record_count   := SQL%ROWCOUNT;

            IF ln_record_count > 0
            THEN
                debug_msg (
                       'Deleted 60 Days Older Records Count = '
                    || ln_record_count);
            END IF;

            debug_msg ('Perform Batching');

            -- Perform Batching
            IF p_operation_mode IN ('XXD_ONT_CANCEL', 'XXD_ONT_COPY') --, 'XXD_ONT_UPDATE_LINE') --('XXD_ONT_BOOK','XXD_ONT_CANCEL')
            THEN
                update_batch (p_group_id => p_group_id);
            ELSE
                ln_batch_id   := xxdo.xxd_ont_order_modify_details_s.NEXTVAL;

                UPDATE xxd_ont_order_modify_details_t
                   SET batch_id = ln_batch_id, parent_request_id = gn_request_id
                 WHERE     1 = 1
                       AND batch_id IS NULL
                       AND status = 'N'
                       AND GROUP_ID = p_group_id;

                COMMIT;
            END IF;

            debug_msg ('');
            debug_msg ('Submit Child Threads');

            -- Submit Child Programs
            FOR i
                IN (  SELECT DISTINCT batch_id
                        FROM xxd_ont_order_modify_details_t
                       WHERE     batch_id IS NOT NULL
                             AND status = 'N'
                             AND GROUP_ID = p_group_id
                    ORDER BY 1)
            LOOP
                ln_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXD_ONT_ORDER_BOOK_CANCEL_CHLD',
                        description   => NULL,
                        start_time    => NULL,
                        sub_request   => TRUE,
                        argument1     => p_operation_mode,
                        argument2     => p_group_id,
                        argument3     => i.batch_id,
                        argument4     => p_om_debug,
                        argument5     => p_custom_debug,
                        argument6     => p_freeAtp_flag);

                COMMIT;
                debug_msg (' i.batch_id VALUE = ' || i.batch_id);
            END LOOP;

            IF ln_req_id > 0
            THEN
                debug_msg ('Successfully Submitted Child Threads');
                fnd_conc_global.set_req_globals (conc_status    => 'PAUSED',
                                                 request_data   => 'MASTER');
            END IF;

            debug_msg (
                'Successfully SSD Updated Record Count = ' || SQL%ROWCOUNT);
        END IF;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
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
            debug_msg ('End ' || lc_sub_prog_name);
    END book_cancel_order_mast_prc;

    -- ======================================================================================
    -- This procedure performs order line updates for eligible order lines
    -- ======================================================================================

    PROCEDURE book_cancel_order_child_prc (
        x_errbuf              OUT NOCOPY VARCHAR2,
        x_retcode             OUT NOCOPY VARCHAR2,
        p_operation_mode   IN            VARCHAR2,
        p_group_id         IN            NUMBER,
        p_batch_id         IN            NUMBER,
        p_om_debug         IN            VARCHAR2,
        p_custom_debug     IN            VARCHAR2,
        p_freeAtp_flag     IN            VARCHAR2                   -- ver 2.4
                                                 )
    AS
        lc_sub_prog_name   VARCHAR2 (100) := 'BOOK_CANCAL_CHILD_PRC';
        lc_error_message   VARCHAR2 (4000);
        lc_debug_mode      VARCHAR2 (50);
    BEGIN
        gc_debug_enable   := NVL (gc_debug_enable, NVL (p_custom_debug, 'N'));

        IF p_om_debug = 'Y'
        THEN
            oe_debug_pub.debug_on;
            oe_debug_pub.setdebuglevel (5);
            lc_debug_mode   := oe_debug_pub.set_debug_mode ('CONC');
        END IF;

        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        IF p_operation_mode = 'XXD_ONT_BOOK'
        THEN
            debug_msg (
                'Inside the Book Record Procedure ' || p_operation_mode);
            book_order_prc (p_group_id => p_group_id, p_batch_id => p_batch_id);
        ELSIF p_operation_mode = 'XXD_ONT_CANCEL'
        THEN
            cancel_order_prc855 (p_group_id       => p_group_id,
                                 p_batch_id       => p_batch_id,
                                 p_freeAtp_flag   => p_freeAtp_flag -- ver 2.4
                                                                   );
        ELSIF p_operation_mode = 'XXD_ONT_UPDATE_HEADER'
        THEN
            debug_msg ('Start ' || p_operation_mode);

            validate_update_headers_prc (p_group_id   => p_group_id,
                                         p_batch_id   => p_batch_id);
            update_headers_cust_po_prc (p_group_id   => p_group_id,
                                        p_batch_id   => p_batch_id);
            debug_msg ('End ' || p_operation_mode);
        ELSIF p_operation_mode = 'XXD_ONT_COPY'
        THEN
            copy_sales_order_prc (p_group_id   => p_group_id,
                                  p_batch_id   => p_batch_id);
        ELSIF p_operation_mode = 'XXD_ONT_UPDATE_LINE'
        THEN
            update_order_lines_prc (p_group_id       => p_group_id,
                                    p_batch_id       => p_batch_id,
                                    p_freeAtp_flag   => p_freeAtp_flag -- ver 2.11
                                                                      );
        ELSIF p_operation_mode = 'XXD_ONT_APPLY_REMOVE_HOLD'        -- ver 2.6
        THEN
            apply_remove_hold (p_group_id   => p_group_id,
                               p_batch_id   => p_batch_id);
        END IF;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
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
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in book_cancel_order_child_prc = '
                || lc_error_message);
    END book_cancel_order_child_prc;

    -- ======================================================================================
    -- This procedure called from concurrent program to Book the order and update the status
    -- ======================================================================================

    PROCEDURE book_order_prc (p_group_id IN NUMBER, p_batch_id IN NUMBER)
    AS
        CURSOR get_orders_c IS
              SELECT source_order_number, source_header_id, org_id
                FROM xxd_ont_order_modify_details_t
               WHERE     NVL (status, 'N') = 'N'
                     AND batch_id = p_batch_id
                     AND GROUP_ID = p_group_id
            ORDER BY TO_NUMBER (attribute3) ASC;

        CURSOR get_order_c IS
            SELECT source_line_id, target_inventory_item_id, target_ordered_quantity,
                   target_line_request_date, target_latest_acceptable_date, target_change_reason_code
              FROM xxd_ont_order_modify_details_t
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

        lc_sub_prog_name       VARCHAR2 (100) := 'BOOK_ORDER_PRC';
        lc_api_return_status   VARCHAR2 (1);
        lc_lock_status         VARCHAR2 (1);
        lc_error_message       VARCHAR2 (4000);
        ln_line_tbl_count      NUMBER := 0;
        l_header_rec           oe_order_pub.header_rec_type;
        lx_header_rec          oe_order_pub.header_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        lx_line_tbl            oe_order_pub.line_tbl_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
        l_line_tbl_index       NUMBER := 0;
        lv_status_count        NUMBER := 0;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        FOR orders_rec IN get_orders_c
        LOOP
            lc_lock_status   := 'S';

            -- Try locking all lines in the order
            oe_line_util.lock_rows (
                p_header_id       => orders_rec.source_header_id,
                x_line_tbl        => l_line_tbl,
                x_return_status   => lc_lock_status);

            IF lc_lock_status = 'S'
            THEN
                lc_api_return_status   := NULL;
                lc_error_message       := NULL;
                oe_msg_pub.delete_msg;
                oe_msg_pub.initialize;
                ln_line_tbl_count      := 0;
                debug_msg (RPAD ('=', 100, '='));
                debug_msg (
                       'Processing Order Number '
                    || orders_rec.source_order_number
                    || '. Header ID '
                    || orders_rec.source_header_id);
                debug_msg (
                       'Start Time '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                l_line_tbl_index       := l_line_tbl_index + 1;
                l_action_request_tbl (l_line_tbl_index)   :=
                    oe_order_pub.g_miss_request_rec;
                l_action_request_tbl (l_line_tbl_index).request_type   :=
                    oe_globals.g_book_order;
                l_action_request_tbl (l_line_tbl_index).entity_code   :=
                    oe_globals.g_entity_header;
                l_action_request_tbl (l_line_tbl_index).entity_id   :=
                    orders_rec.source_header_id;
                process_book_order (p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, p_action_request_tbl => l_action_request_tbl, x_header_rec => lx_header_rec, x_line_tbl => lx_line_tbl, x_return_status => lc_api_return_status
                                    , x_error_message => lc_error_message);

                debug_msg ('Order Update Status = ' || lc_api_return_status);

                BEGIN
                    SELECT COUNT (1)
                      INTO lv_status_count
                      FROM oe_order_headers_all
                     WHERE     1 = 1
                           AND header_id = orders_rec.source_header_id
                           AND flow_status_code = 'BOOKED';

                    IF (lv_status_count = 0)
                    THEN
                        lc_api_return_status   := 'E';
                    END IF;
                END;

                IF lc_api_return_status <> 'S'
                THEN
                    debug_msg ('Order Update Error = ' || lc_error_message);
                ELSE
                    debug_msg (
                        'Target Order Header ID ' || lx_header_rec.header_id);
                END IF;
            ELSE
                lc_error_message       :=
                    'One or more line is locked by another user';
                debug_msg (lc_error_message);
                lc_api_return_status   := 'E';
            END IF;

            UPDATE xxd_ont_order_modify_details_t
               SET target_header_id   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.header_id,
                               target_header_id),
                   target_order_number   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.order_number,
                               target_order_number),
                   target_order_type_id   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.order_type_id,
                               target_order_type_id),
                   target_order_type   =
                       DECODE (
                           lc_api_return_status,
                           'S', (SELECT name
                                   FROM oe_transaction_types_tl
                                  WHERE     language = USERENV ('LANG')
                                        AND transaction_type_id =
                                            lx_header_rec.order_type_id),
                           target_order_type),
                   target_sold_to_org_id   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.sold_to_org_id,
                               target_sold_to_org_id),
                   target_customer_number   =
                       DECODE (
                           lc_api_return_status,
                           'S', (SELECT account_number
                                   FROM hz_cust_accounts
                                  WHERE cust_account_id =
                                        lx_header_rec.sold_to_org_id),
                           target_customer_number),
                   target_line_id      = source_line_id,
                   target_schedule_ship_date   =
                       (SELECT TRUNC (schedule_ship_date)
                          FROM oe_order_lines_all
                         WHERE line_id = source_line_id),
                   status             =
                       DECODE (lc_api_return_status,
                               'U', 'E',
                               lc_api_return_status),
                   error_message      =
                       DECODE (lc_api_return_status,
                               'E', SUBSTR (lc_error_message, 1, 2000)),
                   request_id          = gn_request_id,
                   last_update_date    = SYSDATE,
                   last_update_login   = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND source_header_id = orders_rec.source_header_id;

            debug_msg (
                'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg (
                   'Updated Status in Custom Table Record Count = '
                || SQL%ROWCOUNT);
            debug_msg (RPAD ('=', 100, '='));
            COMMIT;
        END LOOP;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in book_order_prc = ' || lc_error_message);
    END book_order_prc;

    -- ======================================================================================
    -- This procedure called from concurrent program to cancel the order and update the status
    -- ======================================================================================

    PROCEDURE cancel_order_prc (p_group_id       IN NUMBER,
                                p_batch_id       IN NUMBER,
                                p_freeAtp_flag   IN VARCHAR2        -- ver 2.4
                                                            )
    AS
        CURSOR get_orders_c IS
            SELECT DISTINCT source_order_number, source_header_id, org_id
              FROM xxd_ont_order_modify_details_t
             WHERE     NVL (status, 'N') = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

        CURSOR get_order_c IS
            SELECT source_line_id, target_inventory_item_id, target_ordered_quantity,
                   target_line_request_date, target_latest_acceptable_date, target_change_reason_code
              FROM xxd_ont_order_modify_details_t
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

        lc_sub_prog_name       VARCHAR2 (100) := 'CANCEL_ORDER_PRC';
        lc_api_return_status   VARCHAR2 (1);
        lc_lock_status         VARCHAR2 (1);
        lc_error_message       VARCHAR2 (4000);
        ln_line_tbl_count      NUMBER := 0;
        l_header_rec           oe_order_pub.header_rec_type;
        lx_header_rec          oe_order_pub.header_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        lx_line_tbl            oe_order_pub.line_tbl_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
        l_line_tbl_index       NUMBER;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        FOR orders_rec IN get_orders_c
        LOOP
            lc_lock_status   := 'S';

            -- Try locking all lines in the order
            oe_line_util.lock_rows (
                p_header_id       => orders_rec.source_header_id,
                x_line_tbl        => l_line_tbl,
                x_return_status   => lc_lock_status);

            IF lc_lock_status = 'S'
            THEN
                lc_api_return_status          := NULL;
                lc_error_message              := NULL;
                oe_msg_pub.delete_msg;
                oe_msg_pub.initialize;
                ln_line_tbl_count             := 0;
                debug_msg (RPAD ('=', 100, '='));
                debug_msg (
                       'Processing Order Number '
                    || orders_rec.source_order_number
                    || '. Header ID '
                    || orders_rec.source_header_id);
                debug_msg (
                       'Start Time '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                l_line_tbl_index              := l_line_tbl_index + 1;
                l_header_rec                  := oe_order_pub.g_miss_header_rec;
                l_header_rec.operation        := oe_globals.g_opr_update;
                l_header_rec.header_id        := orders_rec.source_header_id;
                l_header_rec.cancelled_flag   := 'Y';

                IF p_freeAtp_flag = 'Y'
                THEN
                    xxd_ont_bulk_calloff_pkg.gc_no_unconsumption   := 'Y'; -- ver 2.4; with this in place, qty will go back to the free ATP instead of bulk
                END IF;

                l_header_rec.change_reason    := 'BLK_FORM_TRANSFER';
                l_header_rec.change_comments   :=
                       'Order modified on '
                    || SYSDATE
                    || ' by program request_id: '
                    || gn_request_id;
                process_order (p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, p_action_request_tbl => l_action_request_tbl, x_header_rec => lx_header_rec, x_line_tbl => lx_line_tbl, x_return_status => lc_api_return_status
                               , x_error_message => lc_error_message);

                debug_msg ('Order Update Status = ' || lc_api_return_status);

                IF lc_api_return_status <> 'S'
                THEN
                    debug_msg ('Order Update Error = ' || lc_error_message);
                ELSE
                    debug_msg (
                        'Target Order Header ID ' || lx_header_rec.header_id);
                END IF;
            ELSE
                lc_error_message       :=
                    'One or more line is locked by another user';
                debug_msg (lc_error_message);
                lc_api_return_status   := 'E';
            END IF;

            UPDATE xxd_ont_order_modify_details_t
               SET target_header_id   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.header_id,
                               target_header_id),
                   target_order_number   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.order_number,
                               target_order_number),
                   target_order_type_id   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.order_type_id,
                               target_order_type_id),
                   target_order_type   =
                       DECODE (
                           lc_api_return_status,
                           'S', (SELECT name
                                   FROM oe_transaction_types_tl
                                  WHERE     language = USERENV ('LANG')
                                        AND transaction_type_id =
                                            lx_header_rec.order_type_id),
                           target_order_type),
                   target_sold_to_org_id   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.sold_to_org_id,
                               target_sold_to_org_id),
                   target_customer_number   =
                       DECODE (
                           lc_api_return_status,
                           'S', (SELECT account_number
                                   FROM hz_cust_accounts
                                  WHERE cust_account_id =
                                        lx_header_rec.sold_to_org_id),
                           target_customer_number),
                   target_line_id      = source_line_id,
                   target_schedule_ship_date   =
                       (SELECT TRUNC (schedule_ship_date)
                          FROM oe_order_lines_all
                         WHERE line_id = source_line_id),
                   status             =
                       DECODE (lc_api_return_status,
                               'U', 'E',
                               lc_api_return_status),
                   error_message       = SUBSTR (lc_error_message, 1, 2000),
                   request_id          = gn_request_id,
                   last_update_date    = SYSDATE,
                   last_update_login   = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND source_header_id = orders_rec.source_header_id;

            debug_msg (
                'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg (
                   'Updated Status in Custom Table Record Count = '
                || SQL%ROWCOUNT);
            debug_msg (RPAD ('=', 100, '='));
            COMMIT;
        END LOOP;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in book_order_prc = ' || lc_error_message);
    END cancel_order_prc;

    -- ======================================================================================
    -- This procedure called from concurrent program to apply and remove holds from the order
    -- ======================================================================================
    -- ver 2.6
    PROCEDURE apply_remove_hold (p_group_id IN NUMBER, p_batch_id IN NUMBER)
    AS
        CURSOR get_orders_c IS
            SELECT source_order_number, source_header_id, org_id,
                   attribute13 action, attribute14 hold_id
              FROM xxd_ont_order_modify_details_t
             WHERE     NVL (status, 'N') = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;



        l_line_rec              oe_order_pub.line_rec_type;
        l_header_rec            oe_order_pub.header_rec_type;
        l_action_request_tbl    oe_order_pub.request_tbl_type;
        l_request_rec           oe_order_pub.request_rec_type;
        l_line_tbl              oe_order_pub.line_tbl_type;
        l_hold_source_rec       oe_holds_pvt.hold_source_rec_type;
        l_order_tbl_type        oe_holds_pvt.order_tbl_type;
        ln_hold_msg_count       NUMBER := 0;
        lc_hold_msg_data        VARCHAR2 (2000);
        lc_hold_return_status   VARCHAR2 (20);
        lc_api_return_status    VARCHAR2 (1);
        ln_msg_count            NUMBER := 0;
        ln_msg_index_out        NUMBER;
        ln_record_count         NUMBER := 0;
        lc_msg_data             VARCHAR2 (2000);
        lc_error_message        VARCHAR2 (2000);
        lc_return_status        VARCHAR2 (20);
        lc_delink_status        VARCHAR2 (1);
        lc_lock_status          VARCHAR2 (1);
        lc_status               VARCHAR2 (1);
        lc_wf_status            VARCHAR2 (1);
    BEGIN
        debug_msg ('inside apply hold program');

        FOR orders_rec IN get_orders_c
        LOOP
            lc_error_message   := NULL;
            lc_return_status   := NULL;

            IF UPPER (orders_rec.action) = 'APPLY'
            THEN
                debug_msg ('sinde apply hold selction');
                -- Apply Calloff Order Line Hold
                l_hold_source_rec.hold_id            := orders_rec.hold_id;
                l_hold_source_rec.hold_entity_code   := 'O';
                l_hold_source_rec.hold_entity_id     :=
                    orders_rec.source_header_id;
                oe_holds_pub.apply_holds (
                    p_api_version        => 1.0,
                    p_validation_level   => fnd_api.g_valid_level_full,
                    p_hold_source_rec    => l_hold_source_rec,
                    x_msg_count          => ln_hold_msg_count,
                    x_msg_data           => lc_hold_msg_data,
                    x_return_status      => lc_return_status);


                IF lc_return_status = 'S'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Hold Applied:-' || orders_rec.source_order_number);
                ELSE
                    FOR i IN 1 .. oe_msg_pub.count_msg
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_hold_msg_data
                                        , p_msg_index_out => ln_msg_index_out);
                        lc_error_message   :=
                            lc_error_message || lc_hold_msg_data;
                    END LOOP;

                    --debug_msg ('Hold API Error = ' || lc_error_message);
                    ROLLBACK;
                -- If unable to apply hold, skip and continue
                END IF;
            END IF;


            IF UPPER (orders_rec.action) = 'RELEASE'
            THEN
                debug_msg ('inside relase hold');
                l_order_tbl_type (1).header_id   :=
                    orders_rec.source_header_id;

                -- Call Process Order to release hold
                oe_holds_pub.release_holds (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_false, p_order_tbl => l_order_tbl_type, p_hold_id => orders_rec.hold_id, p_release_reason_code => 'OM_MODIFY', p_release_comment => 'Released from SOMT', x_return_status => lc_return_status, x_msg_count => ln_msg_count
                                            , x_msg_data => lc_msg_data);

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Hold Release Status = ' || lc_return_status);

                IF lc_return_status = 'S'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Released Hold:-' || orders_rec.source_order_number);
                ELSE
                    FOR i IN 1 .. oe_msg_pub.count_msg
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                        , p_msg_index_out => ln_msg_index_out);
                        lc_error_message   := lc_error_message || lc_msg_data;
                    END LOOP;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Hold Release Failed: ' || lc_error_message);
                END IF;
            END IF;

            UPDATE xxd_ont_order_modify_details_t
               SET status = DECODE (lc_return_status, 'U', 'E', lc_return_status), error_message = SUBSTR (lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     NVL (status, 'N') = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND source_header_id = orders_rec.source_header_id;


            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;
    END apply_remove_hold;

    -- This procedure called from OA to book,cancel and update Order lines and submit the master concurrent program
    -- ======================================================================================

    PROCEDURE submit_book_cancel_updat_order (p_operation_mode IN VARCHAR2, p_group_id IN NUMBER, p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_om_debug IN VARCHAR2, p_custom_debug IN VARCHAR2, p_freeAtp_flag IN VARCHAR2
                                              ,                     -- ver 2.4
                                                x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2)
    AS
        ln_group_id       NUMBER;
        ln_req_id         NUMBER;
        lc_status         VARCHAR2 (10);
        ln_record_count   NUMBER;
        ln_valid_count    NUMBER;
    BEGIN
        gn_org_id              := p_org_id;
        gn_user_id             := p_user_id;
        gn_application_id      := p_resp_app_id;
        gn_responsibility_id   := p_resp_id;

        lc_status              := xxd_ont_check_plan_run_fnc ();
        init ();
        x_ret_status           := 'S';
        lc_status              := 'N';                  -- this is for testing

        IF lc_status = 'N'
        THEN
            UPDATE xxd_ont_order_modify_details_t
               SET status   = 'N'
             WHERE GROUP_ID = p_group_id AND status = 'I';

            SELECT COUNT (1)
              INTO ln_valid_count
              FROM xxd_ont_order_modify_details_t
             WHERE NVL (status, 'N') = 'N' AND GROUP_ID = p_group_id;

            x_err_msg   :=
                'Count ' || ln_valid_count || ' Group_id ' || p_group_id;

            IF ln_valid_count > 0
            THEN
                --COMMIT;
                ln_req_id   := 0;
                ln_req_id   :=
                    fnd_request.submit_request (application => 'XXDO', program => 'XXD_ONT_ORDER_BOOK_CANCEL_MAST', description => NULL, start_time => NULL, sub_request => NULL, argument1 => p_operation_mode, argument2 => p_group_id, argument3 => p_om_debug, argument4 => p_custom_debug
                                                , argument5 => p_freeAtp_flag -- ver 2.4
                                                                             );

                IF ln_req_id > 0
                THEN
                    COMMIT;
                    x_ret_status   := 'S';
                    x_err_msg      :=
                        'Request_id ' || ln_req_id || ' ' || x_err_msg;
                ELSE
                    ROLLBACK;
                    x_err_msg      :=
                           x_err_msg
                        || ' Unable to submit master concurrent program ';
                    x_ret_status   := 'E';
                END IF;
            END IF;
        ELSE
            ROLLBACK;
            x_err_msg      :=
                   x_err_msg
                || ' Planning Programs are running in ASCP. Order Update Program cannot run now ';
            x_ret_status   := 'E';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_err_msg      := SUBSTR (SQLERRM, 1, 2000);
            x_ret_status   := 'E';

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = x_err_msg, request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE GROUP_ID = p_group_id;

            COMMIT;
    END submit_book_cancel_updat_order;

    -- ver 2.6
    -- ======================================================================================
    -- This procedure called from OA to Delete the Book,Cancel and update Order lines
    -- ======================================================================================

    PROCEDURE xxd_ont_apply_hold_delete (
        p_ont_order_lines_tbl          xxdo.xxd_ont_order_lines_tbl_type,
        p_org_id                IN     NUMBER,
        p_resp_id               IN     NUMBER,
        p_resp_app_id           IN     NUMBER,
        p_user_id               IN     NUMBER,
        p_operation_mode        IN     VARCHAR2,
        pv_error_stat              OUT VARCHAR2,
        pv_error_msg               OUT VARCHAR2)
    AS
        lv_error_msg    VARCHAR2 (4000) := NULL;
        lv_error_stat   VARCHAR2 (4) := 'S';
        lv_error_code   VARCHAR2 (4000) := NULL;
        ln_error_num    NUMBER;
    BEGIN
        IF (p_ont_order_lines_tbl.COUNT > 0)
        THEN
            BEGIN
                FORALL i
                    IN p_ont_order_lines_tbl.FIRST ..
                       p_ont_order_lines_tbl.LAST
                  SAVE EXCEPTIONS
                    DELETE xxd_ont_order_modify_details_t
                     WHERE     source_order_number =
                               p_ont_order_lines_tbl (i).source_order_number
                           AND GROUP_ID = p_ont_order_lines_tbl (i).GROUP_ID
                           AND operation_mode = p_operation_mode;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';

                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        ln_error_num   := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                        lv_error_code   :=
                            SQLERRM (-1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                        lv_error_msg   :=
                            SUBSTR (
                                (lv_error_msg || '  Error While Delete The Record Table ' || p_ont_order_lines_tbl (ln_error_num).source_order_number || lv_error_code),
                                1,
                                4000);
                    END LOOP;
            END;
        END IF;

        IF (lv_error_stat = 'E')
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            pv_error_stat   := 'S';
            pv_error_msg    :=
                   lv_error_msg
                || ' Successfully Records Deleted, Please Click on Submit To Update Button ';
            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                'Error While Deleting Order Number ' || SQLERRM;
            ROLLBACK;
    END xxd_ont_apply_hold_delete;

    -- ver 2.6 this will process the apply and hold file upload from oaf page
    PROCEDURE process_hold_file (p_file_id IN NUMBER, p_org_id IN NUMBER, p_operation_mode IN VARCHAR2
                                 , x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, x_file_id OUT NOCOPY VARCHAR2)
    AS
        lv_error_msg            VARCHAR2 (4000) := NULL;
        lv_error_stat           VARCHAR2 (4) := 'S';
        lv_error_code           VARCHAR2 (4000) := NULL;
        ln_error_num            NUMBER;
        ln_operation_mode       VARCHAR2 (100);
        ln_group_id             NUMBER;
        ln_req_id               NUMBER;
        lc_status               VARCHAR2 (10);
        ln_record_count         NUMBER;
        ln_valid_count          NUMBER;
        ln_hold_count           NUMBER;
        ln_line_num             NUMBER := 0;

        CURSOR cur_val IS
            (SELECT REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   1, NULL, 1) order_number,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   2, NULL, 1) HOLD_NAME,
                    TRANSLATE (REGEXP_SUBSTR (x.col1 || ',', '([^,]*),|$', 1,
                                              3, NULL, 1),
                               'x' || CHR (10) || CHR (13),
                               'x') ACTION,
                    attribute1,
                    src.file_id,
                    src.file_name,
                    NULL status,
                    NULL erg_msg,
                    NULL oe_header_id,
                    NULL cancelled_flag,
                    NULL hold_id,
                    NULL flow_status_code
               FROM xxdo.xxd_file_upload_t src, XMLTABLE ('/a/b' PASSING xmltype ('<a><b>' || REPLACE (xxd_common_utils.conv_to_clob (src.file_data), CHR (10), '</b><b>') || '</b></a>') COLUMNS col1 VARCHAR2 (2000) PATH '.') x
              WHERE     1 = 1
                    AND file_source = 'GSA'
                    AND file_id = p_file_id
                    AND attribute1 = 'APPLY-REMOVE-HOLD'
                    AND REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                       1, NULL, 1)
                            IS NOT NULL
                    AND REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                       1)
                            IS NOT NULL
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             'ORDER%')
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             '%NUMBER'));

        TYPE xxd_apply_remove_hold_typ IS TABLE OF cur_val%ROWTYPE;

        v_ins_type              xxd_apply_remove_hold_typ
                                    := xxd_apply_remove_hold_typ ();
        l_count                 NUMBER;
        l_hold_valid_for_resp   NUMBER;
        l_count_hold_exists     NUMBER;

        CURSOR c_holdname IS
            SELECT UPPER (name) FROM apps.oe_hold_definitions;

        TYPE type_hold_name IS TABLE OF VARCHAR2 (2000);

        l_type_hold_name        type_hold_name;
    BEGIN
        BEGIN
            -- get the list of all hold name at once
            OPEN c_holdname;

            FETCH c_holdname BULK COLLECT INTO l_type_hold_name;

            CLOSE c_holdname;

            x_file_id   := xxdo.xxd_ont_order_modify_batch_s.NEXTVAL;

            OPEN cur_val;

            LOOP
                FETCH cur_val BULK COLLECT INTO v_ins_type LIMIT 1000;

                IF (v_ins_type.COUNT > 0)
                THEN
                    FOR x IN v_ins_type.FIRST .. v_ins_type.LAST
                    LOOP
                        BEGIN
                            ln_line_num   := ln_line_num + 1;

                            -- validate action
                            SELECT COUNT (1)
                              INTO l_count
                              FROM DUAL
                             WHERE TRIM (UPPER (v_ins_type (x).action)) IN
                                       ('RELEASE', 'APPLY');

                            IF l_count <> 1
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                       v_ins_type (x).erg_msg
                                    || 'Action is not valid. Valid values are  Apply and Release. ';
                            END IF;

                            -- validate hold name
                            IF UPPER (TRIM (v_ins_type (x).hold_name))
                                    MEMBER OF l_type_hold_name
                            THEN
                                SELECT hold_id
                                  INTO v_ins_type (x).hold_id
                                  FROM apps.oe_hold_definitions
                                 WHERE UPPER (name) =
                                       UPPER (
                                           TRIM (v_ins_type (x).hold_name));
                            ELSE
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                       v_ins_type (x).erg_msg
                                    || 'Hold Name is not Valid. ';
                            END IF;

                            IF v_ins_type (x).hold_id IS NOT NULL
                            THEN
                                -- if hold is valid then validate if the hold really exists or not
                                SELECT COUNT (1)
                                  INTO l_count_hold_exists
                                  FROM apps.oe_order_headers_all ooh, apps.oe_order_holds_all hld, apps.oe_hold_sources_all ohs,
                                       apps.oe_hold_definitions ohd
                                 WHERE     1 = 1
                                       AND ooh.order_category_code = 'ORDER'
                                       AND ooh.header_id = hld.header_id
                                       AND ohs.released_flag = 'N' -- HOLD IS PRESENT
                                       AND hld.hold_source_id =
                                           ohs.hold_source_id
                                       AND ohs.hold_id = ohd.hold_id
                                       AND ohs.hold_id =
                                           v_ins_type (x).hold_id
                                       AND order_number =
                                           v_ins_type (x).order_number;

                                IF TRIM (UPPER (v_ins_type (x).action)) =
                                   'RELEASE'
                                THEN
                                    IF l_count_hold_exists = 0
                                    THEN
                                        v_ins_type (x).status   := 'E';
                                        v_ins_type (x).erg_msg   :=
                                               v_ins_type (x).erg_msg
                                            || 'This Hold Does not exists on this order. ';
                                    END IF;
                                END IF;

                                IF TRIM (UPPER (v_ins_type (x).action)) =
                                   'APPLY'
                                THEN
                                    IF l_count_hold_exists = 1
                                    THEN
                                        v_ins_type (x).status   := 'E';
                                        v_ins_type (x).erg_msg   :=
                                               v_ins_type (x).erg_msg
                                            || 'This Hold Already exists on this order. ';
                                    END IF;
                                END IF;
                            END IF;

                            -- valiate if the hold action is allowed in this resp
                            -- IF ACTION IS release then resp shuld have reomve hold authorisation
                            -- if action is apply, then resp shuld have apply hold authorisation
                            -- action has been validated
                            IF     v_ins_type (x).hold_id IS NOT NULL
                               AND l_count = 1
                            THEN
                                BEGIN
                                    SELECT COUNT (1)
                                      INTO l_hold_valid_for_resp
                                      FROM APPS.OE_HOLD_DEFINITIONS OHD, APPS.OE_HOLD_AUTHORIZATIONS OHA, APPS.FND_LOOKUP_VALUES FLV_TC,
                                           APPS.FND_RESPONSIBILITY_VL FRV
                                     WHERE     1 = 1
                                           AND OHD.HOLD_ID = OHA.HOLD_ID
                                           AND FLV_TC.LOOKUP_CODE =
                                               OHD.TYPE_CODE
                                           AND FLV_TC.LOOKUP_TYPE =
                                               'HOLD_TYPE'
                                           AND FLV_TC.LANGUAGE = 'US'
                                           AND FRV.RESPONSIBILITY_ID =
                                               FND_GLOBAL.RESP_ID
                                           AND ohd.hold_id =
                                               v_ins_type (x).hold_id
                                           AND SYSDATE BETWEEN NVL (
                                                                   oha.START_DATE_ACTIVE,
                                                                     SYSDATE
                                                                   - 1)
                                                           AND NVL (
                                                                   OHa.END_DATE_ACTIVE,
                                                                     SYSDATE
                                                                   + 1)
                                           AND OHA.AUTHORIZED_ACTION_CODE =
                                               DECODE (
                                                   UPPER (
                                                       v_ins_type (x).action),
                                                   'RELEASE', 'REMOVE',
                                                   'APPLY', 'APPLY')
                                           AND FRV.RESPONSIBILITY_ID =
                                               OHA.RESPONSIBILITY_ID
                                           AND ROWNUM = 1;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        v_ins_type (x).status   := 'E';
                                        v_ins_type (x).erg_msg   :=
                                            'Couldnt derive hold to responsibility mapping. ';
                                END;

                                IF l_hold_valid_for_resp = 0
                                THEN
                                    v_ins_type (x).status   := 'E';
                                    v_ins_type (x).erg_msg   :=
                                           v_ins_type (x).erg_msg
                                        || 'Hold is not allowed on the given responsibility ID. ';
                                END IF;
                            END IF;



                            -- valdaite order number
                            SELECT ooh.header_id, cancelled_flag, flow_status_code
                              INTO v_ins_type (x).oe_header_id, v_ins_type (x).cancelled_flag, v_ins_type (x).flow_status_code
                              FROM oe_order_headers_all ooh
                             WHERE     ooh.order_number =
                                       v_ins_type (x).order_number
                                   AND org_id = fnd_global.org_id;

                            IF (v_ins_type (x).cancelled_flag = 'Y')
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                       v_ins_type (x).erg_msg
                                    || 'Order is ineligible for current operation. ';
                            END IF;

                            IF (v_ins_type (x).flow_status_code = 'CLOSED')
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                       v_ins_type (x).erg_msg
                                    || 'Order is Closed so not eligible for current operation. ';
                            END IF;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                       v_ins_type (x).erg_msg
                                    || 'Order is ineligible from the current responsibility. '
                                    || SQLERRM;
                            WHEN OTHERS
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                       v_ins_type (x).erg_msg
                                    || 'Order is not eligible for current operation. '
                                    || SQLERRM;
                        END;
                    END LOOP;
                END IF;

                IF (v_ins_type.COUNT > 0)
                THEN
                    BEGIN
                        FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO xxd_ont_order_modify_details_t (
                                            source_order_number,
                                            source_header_id,
                                            status,
                                            error_message,
                                            attribute2,
                                            attribute14,
                                            attribute13,
                                            GROUP_ID,
                                            org_id,
                                            operation_mode,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            record_id -- Added as per CCR0010520
                                                     )
                                     VALUES (
                                                v_ins_type (i).order_number,
                                                v_ins_type (i).oe_header_id,
                                                NVL (v_ins_type (i).status,
                                                     'I'),
                                                v_ins_type (i).erg_msg,
                                                p_file_id,
                                                v_ins_type (i).hold_id,
                                                v_ins_type (i).action,
                                                x_file_id,
                                                p_org_id,
                                                p_operation_mode,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                fnd_global.login_id,
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
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg    :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Inserting into Table For Order Number' || v_ins_type (ln_error_num).order_number || lv_error_code || ' #'),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                END IF;

                EXIT WHEN cur_val%NOTFOUND;
            END LOOP;

            CLOSE cur_val;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                       lv_error_msg
                    || 'Error While Collect The Data  '
                    || SQLERRM;
        END;

        IF (lv_error_stat = 'E')
        THEN
            x_ret_status   := 'E';
            x_err_msg      :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            x_ret_status   := 'S';
            x_err_msg      :=
                   lv_error_msg
                || ' Successfully Records Inserted, Please Click on Submit To Apply or Remove Hold ';

            UPDATE xxd_ont_order_modify_details_t
               SET GROUP_ID   = x_file_id
             WHERE     status = 'I'
                   AND created_by = fnd_global.user_id
                   AND operation_mode = 'XXD_ONT_APPLY_REMOVE_HOLD';

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := 'Error While Inserting to Table ' || SQLERRM;
            ROLLBACK;
    END process_hold_file;

    -- ======================================================================================
    -- This procedure called from OA to Load the Update Order Lines Data from CSV file
    -- ======================================================================================

    PROCEDURE process_update_order_file (p_file_id IN NUMBER, p_org_id IN NUMBER, p_operation_mode IN VARCHAR2
                                         , x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, x_file_id OUT NOCOPY VARCHAR2)
    AS
        lv_error_msg        VARCHAR2 (4000) := NULL;
        lv_error_stat       VARCHAR2 (4) := 'S';
        lv_error_code       VARCHAR2 (4000) := NULL;
        ln_error_num        NUMBER;
        ln_operation_mode   VARCHAR2 (100);
        ln_group_id         NUMBER;
        ln_req_id           NUMBER;
        lc_status           VARCHAR2 (10);
        ln_record_count     NUMBER;
        ln_valid_count      NUMBER;
        lv_ret_status       VARCHAR2 (10);
        lv_err_msg          VARCHAR2 (4000);
        ln_line_num         NUMBER := 0;
        lv_date             DATE := NULL;
        lv_open_flag        VARCHAR2 (10);

        CURSOR cur_val IS
            (SELECT REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   1, NULL, 1) order_number,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   2, NULL, 1) line_number,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   3, NULL, 1) sku,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   4, NULL, 1) quantity,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   5, NULL, 1) request_date,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   6, NULL, 1) cancel_date,
                    --            regexp_substr(x.col1, '([^,]*),|$', 1, 7, NULL, 1) lap,
                    TRANSLATE (REGEXP_SUBSTR (x.col1 || ',', '([^,]*),|$', 1,
                                              7, NULL, 1),
                               'x' || CHR (10) || CHR (13),
                               'x') lap,
                    attribute1,
                    src.file_id,
                    src.file_name,
                    NULL status,
                    NULL erg_msg,
                    NULL oe_header_id,
                    NULL inventory_item_id,
                    NULL ship_from_org_id,
                    NULL line_id,
                    ROW_NUMBER () OVER (PARTITION BY file_id ORDER BY NULL) line_num
               FROM xxdo.xxd_file_upload_t src, XMLTABLE ('/a/b' PASSING xmltype ('<a><b>' || REPLACE (xxd_common_utils.conv_to_clob (src.file_data), CHR (10), '</b><b>') || '</b></a>') COLUMNS col1 VARCHAR2 (2000) PATH '.') x
              WHERE     1 = 1
                    AND file_source = 'GSA'
                    AND file_id = p_file_id
                    AND REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                       1)
                            IS NOT NULL
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             'ORDER%')
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             '%NUMBER'));

        TYPE xxd_insert_book_ord_typ IS TABLE OF cur_val%ROWTYPE;

        v_ins_type          xxd_insert_book_ord_typ
                                := xxd_insert_book_ord_typ ();
    BEGIN
        BEGIN
            v_ins_type.DELETE;
            x_file_id   := xxdo.xxd_ont_order_modify_batch_s.NEXTVAL;

            OPEN cur_val;

            LOOP
                FETCH cur_val BULK COLLECT INTO v_ins_type LIMIT 50000;

                /*  begin ver 2.7
                   IF (v_ins_type.COUNT > 0)
                   THEN
                       FOR x IN v_ins_type.FIRST .. v_ins_type.LAST
                       LOOP
                           ln_line_num := ln_line_num + 1;
                           v_ins_type (x).line_num := ln_line_num;

                           BEGIN
                               SELECT ooh.header_id, ooh.ship_from_org_id
                                 INTO v_ins_type (x).oe_header_id,
                                      v_ins_type (x).ship_from_org_id
                                 FROM oe_order_headers_all ooh
                                WHERE ooh.order_number =
                                      v_ins_type (x).order_number;

                               IF (v_ins_type (x).line_number IS NULL)
                               THEN
                                   v_ins_type (x).line_id := NULL;
                               ELSE
                                   BEGIN
                                       SELECT line_id, open_flag
                                         INTO v_ins_type (x).line_id,
                                              lv_open_flag
                                         FROM oe_order_lines_all
                                        WHERE     header_id =
                                                  v_ins_type (x).oe_header_id
                                              AND    line_number
                                                  || '.'
                                                  || shipment_number =
                                                  v_ins_type (x).line_number;

                                       IF (lv_open_flag <> 'Y')
                                       THEN
                                           v_ins_type (x).status := 'E';
                                           v_ins_type (x).erg_msg :=
                                                  v_ins_type (x).erg_msg
                                               || ' Line not in Open Status '
                                               || v_ins_type (x).line_number
                                               || ' ; ';
                                       END IF;
                                   EXCEPTION
                                       WHEN OTHERS
                                       THEN
                                           v_ins_type (x).status := 'E';
                                           v_ins_type (x).erg_msg :=
                                                  v_ins_type (x).erg_msg
                                               || '  Invalid Line Number '
                                               || v_ins_type (x).line_number
                                               || ' ; ';
                                   END;
                               END IF;

                               BEGIN
                                   SELECT inventory_item_id
                                     INTO v_ins_type (x).inventory_item_id
                                     FROM mtl_system_items_b
                                    WHERE     segment1 = v_ins_type (x).sku
                                          AND organization_id =
                                              v_ins_type (x).ship_from_org_id;
                               EXCEPTION
                                   WHEN OTHERS
                                   THEN
                                       v_ins_type (x).status := 'E';
                                       v_ins_type (x).erg_msg :=
                                              v_ins_type (x).erg_msg
                                           || '  Invalid SKU '
                                           || v_ins_type (x).sku
                                           || ' ; ';
                               END;

                               IF (v_ins_type (x).quantity IS NULL)
                               THEN
                                   v_ins_type (x).status := 'E';
                                   v_ins_type (x).erg_msg :=
                                          v_ins_type (x).erg_msg
                                       || ' Provide Quantity value ; ';
                               END IF;

                               IF (v_ins_type (x).quantity IS NOT NULL)
                               THEN
                                   IF (REGEXP_LIKE (v_ins_type (x).quantity,
                                                    '^[0-9]+$'))
                                   THEN
                                       NULL;
                                   ELSE
                                       v_ins_type (x).status := 'E';
                                       v_ins_type (x).erg_msg :=
                                              v_ins_type (x).erg_msg
                                           || ' Invalid Quantity ; ';
                                   END IF;
                               END IF;

                               IF (v_ins_type (x).request_date IS NOT NULL)
                               THEN
                                   BEGIN
                                       lv_date :=
                                           TO_DATE (v_ins_type (x).request_date,
                                                    'DD-Mon-YY');
                                   EXCEPTION
                                       WHEN OTHERS
                                       THEN
                                           v_ins_type (x).status := 'E';
                                           v_ins_type (x).erg_msg :=
                                                  v_ins_type (x).erg_msg
                                               || ' Invalid Request Date(DD-MM-YY) ; '
                                               || v_ins_type (x).request_date;

                                           v_ins_type (x).request_date := NULL;
                                   END;
                               END IF;

                               IF (v_ins_type (x).lap IS NOT NULL)
                               THEN
                                   BEGIN
                                       lv_date :=
                                           TO_DATE (v_ins_type (x).lap,
                                                    'DD-Mon-YY');
                                   EXCEPTION
                                       WHEN OTHERS
                                       THEN
                                           v_ins_type (x).status := 'E';
                                           v_ins_type (x).erg_msg :=
                                                  v_ins_type (x).erg_msg
                                               || ' Invalid Latest Acceptable Date(DD-Mon-YY) ; '
                                               || v_ins_type (x).lap;

                                           v_ins_type (x).lap := NULL;
                                   END;
                               END IF;

                               IF (v_ins_type (x).cancel_date IS NOT NULL)
                               THEN
                                   BEGIN
                                       lv_date :=
                                           TO_DATE (v_ins_type (x).cancel_date,
                                                    'DD-Mon-YY');
                                   EXCEPTION
                                       WHEN OTHERS
                                       THEN
                                           v_ins_type (x).status := 'E';
                                           v_ins_type (x).erg_msg :=
                                                  v_ins_type (x).erg_msg
                                               || ' Invalid Cancel Date(DD-Mon-YY) ; '
                                               || v_ins_type (x).cancel_date;

                                           v_ins_type (x).cancel_date := NULL;
                                   END;
                               END IF;

                               IF (v_ins_type (x).lap IS NULL)
                               THEN
                                   NULL;
                               ELSE
                                   IF (v_ins_type (x).request_date IS NOT NULL)
                                   THEN
                                       IF (TO_DATE (v_ins_type (x).request_date,
                                                    'DD-Mon-YY') >
                                           TO_DATE (v_ins_type (x).lap,
                                                    'DD-Mon-YY'))
                                       THEN
                                           v_ins_type (x).status := 'E';
                                           v_ins_type (x).erg_msg :=
                                                  v_ins_type (x).erg_msg
                                               || ' Latest Acceptable Date should be greater than Request Date ; ';
                                       END IF;
                                   END IF;
                               END IF;

                               IF (v_ins_type (x).cancel_date IS NULL)
                               THEN
                                   NULL;
                               ELSE
                                   IF (v_ins_type (x).request_date IS NOT NULL)
                                   THEN
                                       IF (TO_DATE (v_ins_type (x).request_date,
                                                    'DD-Mon-YY') >
                                           TO_DATE (v_ins_type (x).cancel_date,
                                                    'DD-Mon-YY'))
                                       THEN
                                           v_ins_type (x).status := 'E';
                                           v_ins_type (x).erg_msg :=
                                                  v_ins_type (x).erg_msg
                                               || ' Cancel Date should be greater than Request Date ; '
                                               || v_ins_type (x).request_date
                                               || ' '
                                               || v_ins_type (x).cancel_date;
                                       END IF;
                                   END IF;
                               END IF;
                           EXCEPTION
                               WHEN OTHERS
                               THEN
                                   v_ins_type (x).status := 'E';
                                   v_ins_type (x).erg_msg :=
                                       'Order Number Invalid ' || SQLERRM;
                           END;
                       END LOOP;
                   END IF;
   end ver 2.7    */

                IF (v_ins_type.COUNT > 0)
                THEN
                    BEGIN
                        FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO xxd_ont_order_modify_details_t (
                                            source_order_number,
                                            source_header_id,
                                            source_line_id,
                                            target_inventory_item_id,
                                            source_line_number,
                                            source_ordered_item,
                                            target_ordered_quantity,
                                            target_line_request_date,
                                            target_line_cancel_date,
                                            target_latest_acceptable_date,
                                            target_change_reason_code,
                                            target_change_reason,
                                            operation_mode,
                                            status,
                                            error_message,
                                            attribute2,
                                            GROUP_ID,
                                            org_id,
                                            attribute3,
                                            attribute4,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            record_id -- Added as per CCR0010520
                                                     )
                                     VALUES (
                                                v_ins_type (i).order_number,
                                                v_ins_type (i).oe_header_id,
                                                v_ins_type (i).line_id,
                                                v_ins_type (i).inventory_item_id,
                                                v_ins_type (i).line_number,
                                                v_ins_type (i).sku,
                                                v_ins_type (i).quantity,
                                                v_ins_type (i).request_date,
                                                v_ins_type (i).cancel_date,
                                                v_ins_type (i).lap,
                                                'BLK_CANDEL_DECKERS',
                                                NULL,
                                                p_operation_mode,
                                                NVL (v_ins_type (i).status,
                                                     'I'), --NVL (v_ins_type (i).status, 'N'),
                                                v_ins_type (i).erg_msg,
                                                p_file_id,
                                                x_file_id,
                                                p_org_id,
                                                v_ins_type (i).line_num,
                                                'Y',
                                                SYSDATE,
                                                fnd_global.user_id,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                fnd_global.login_id,
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
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg    :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Inserting into Table' || v_ins_type (ln_error_num).order_number || lv_error_code || CHR (10)),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                END IF;

                EXIT WHEN cur_val%NOTFOUND;
            END LOOP;

            CLOSE cur_val;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                       lv_error_msg
                    || 'Error While Collect The Data  '
                    || SQLERRM;
        END;

        IF (lv_error_stat = 'E')
        THEN
            x_ret_status   := 'E';
            x_err_msg      :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            x_ret_status   := 'S';
            x_err_msg      :=
                   lv_error_msg
                || ' Successfully Records Inserted, Please Click on Submit To Update Button ';

            UPDATE xxd_ont_order_modify_details_t
               SET GROUP_ID   = x_file_id
             WHERE     status = 'I'
                   AND created_by = fnd_global.user_id
                   AND operation_mode = 'XXD_ONT_UPDATE_LINE';

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := 'Error While Inserting to Table ' || SQLERRM;
            ROLLBACK;
    END process_update_order_file;

    -- ======================================================================================
    -- This procedure called from concurrent program to copy the order and create new order
    -- ======================================================================================

    PROCEDURE copy_sales_order_prc (p_group_id   IN NUMBER,
                                    p_batch_id   IN NUMBER)
    AS
        CURSOR get_orders_c IS
              SELECT operation_mode, MIN (source_order_number) source_order_number, MIN (source_header_id) source_header_id,
                     target_order_number, target_header_id, target_sold_to_org_id,
                     target_cust_po_num, target_order_type_id, org_id,
                     MIN (target_line_request_date) header_request_date, fnd_date.date_to_canonical (MAX (target_latest_acceptable_date)) header_cancel_date, target_ship_from_org_id,
                     target_header_ship_method, attribute3
                FROM xxd_ont_order_modify_details_t
               WHERE     status = 'N'
                     AND batch_id = p_batch_id
                     AND GROUP_ID = p_group_id
            GROUP BY operation_mode, target_sold_to_org_id, target_cust_po_num,
                     target_order_type_id, target_order_number, target_header_id,
                     org_id, target_ship_from_org_id, target_header_ship_method,
                     attribute3
            ORDER BY source_header_id;

        CURSOR get_lines_c (p_header_id IN NUMBER, p_seq_num IN NUMBER)
        IS
              SELECT *
                FROM xxd_ont_order_modify_details_t
               WHERE     status = 'N'
                     AND batch_id = p_batch_id
                     AND GROUP_ID = p_group_id
                     AND source_header_id = p_header_id
                     AND attribute3 = p_seq_num
            ORDER BY TO_NUMBER (source_line_number);

        lc_sub_prog_name       VARCHAR2 (100) := 'COPY_ORDER_PRC';
        lc_api_return_status   VARCHAR2 (1);
        lc_lock_status         VARCHAR2 (1);
        lc_error_message       VARCHAR2 (4000);
        ln_line_tbl_count      NUMBER := 0;
        l_line_tbl_index       NUMBER := 0;
        ln_source_header_id    NUMBER;
        ln_target_header_id    oe_order_headers_all.header_id%TYPE;
        ln_target_line_id      oe_order_lines_all.line_id%TYPE;
        ld_target_ssd          oe_order_lines_all.schedule_ship_date%TYPE;
        l_header_rec           oe_order_pub.header_rec_type;
        lx_header_rec          oe_order_pub.header_rec_type;
        l_source_header_rec    oe_order_pub.header_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        lx_line_tbl            oe_order_pub.line_tbl_type;
        l_source_line_rec      oe_order_pub.line_rec_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
        save_point_flag        VARCHAR2 (10) := 'N';
        lv_color               VARCHAR2 (1000);
        lv_style               VARCHAR2 (1000);
        ln_order_source_id     NUMBER;                              -- ver 2.3
    --      PRAGMA autonomous_transaction;
    BEGIN
        init ();

        SELECT order_source_id
          INTO ln_order_source_id
          FROM oe_order_sources
         WHERE (name) = 'SOMT-Copy';


        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));
        l_line_tbl.DELETE;

        FOR orders_rec IN get_orders_c
        LOOP
            SAVEPOINT source_order_line;
            lc_api_return_status                    := NULL;
            lc_error_message                        := NULL;
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            debug_msg (RPAD ('=', 100, '='));
            debug_msg (
                   'Processing Source Order Number '
                || orders_rec.source_order_number
                || '. Header ID '
                || orders_rec.source_header_id);
            debug_msg (
                   'Start Time '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            ln_target_header_id                     := orders_rec.target_header_id;
            l_header_rec                            := oe_order_pub.g_miss_header_rec;
            l_line_tbl                              := oe_order_pub.g_miss_line_tbl;
            ln_source_header_id                     := orders_rec.source_header_id;

            -- Get the source order information
            oe_header_util.query_row (
                p_header_id    => orders_rec.source_header_id,
                x_header_rec   => l_source_header_rec);
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            l_header_rec                            := oe_order_pub.g_miss_header_rec;
            l_action_request_tbl                    := oe_order_pub.g_miss_request_tbl;
            lc_lock_status                          := 'S';
            debug_msg (
                ' orders_rec.target_sold_to_org_id ' || orders_rec.target_sold_to_org_id);
            debug_msg (
                ' l_source_header_rec.price_list_id ' || l_source_header_rec.price_list_id);
            debug_msg (
                   ' l_source_header_rec.sold_from_org_id '
                || l_source_header_rec.sold_from_org_id);
            debug_msg (
                   ' l_source_header_rec.deliver_to_org_id '
                || l_source_header_rec.deliver_to_org_id);
            l_header_rec                            := oe_order_pub.g_miss_header_rec;
            --        l_header_rec.header_id:=orders_rec.source_header_id;
            l_header_rec.org_id                     := orders_rec.org_id;
            l_header_rec.sold_to_org_id             := orders_rec.target_sold_to_org_id;
            l_header_rec.cust_po_number             := orders_rec.target_cust_po_num;
            l_header_rec.order_type_id              := orders_rec.target_order_type_id;
            l_header_rec.request_date               :=
                NVL (orders_rec.header_request_date, fnd_api.g_miss_date);
            l_header_rec.attribute1                 :=
                NVL (orders_rec.header_cancel_date, fnd_api.g_miss_char);
            l_header_rec.ship_from_org_id           :=
                orders_rec.target_ship_from_org_id;
            l_header_rec.shipping_method_code       :=
                orders_rec.target_header_ship_method;


            -- Assign Source Line value for all other columns
            l_header_rec.transactional_curr_code    :=
                l_source_header_rec.transactional_curr_code;
            l_header_rec.price_list_id              :=
                l_source_header_rec.price_list_id;
            l_header_rec.sold_from_org_id           :=
                l_source_header_rec.sold_from_org_id;
            l_header_rec.order_source_id            := ln_order_source_id; -- ver 2.3 --l_source_header_rec.order_source_id;
            l_header_rec.shipping_instructions      :=
                l_source_header_rec.shipping_instructions;
            l_header_rec.packing_instructions       :=
                l_source_header_rec.packing_instructions;
            l_header_rec.salesrep_id                :=
                l_source_header_rec.salesrep_id;
            --        l_header_rec.shipping_method_code := l_source_header_rec.shipping_method_code;
            l_header_rec.freight_terms_code         :=
                l_source_header_rec.freight_terms_code;
            l_header_rec.payment_term_id            :=
                l_source_header_rec.payment_term_id;
            l_header_rec.deliver_to_org_id          :=
                l_source_header_rec.deliver_to_org_id;
            l_header_rec.return_reason_code         :=
                l_source_header_rec.return_reason_code;
            l_header_rec.attribute3                 :=
                l_source_header_rec.attribute3;
            l_header_rec.attribute4                 :=
                l_source_header_rec.attribute4;
            l_header_rec.attribute5                 :=
                l_source_header_rec.attribute5;
            l_header_rec.attribute6                 :=
                l_source_header_rec.attribute6;
            l_header_rec.attribute7                 :=
                l_source_header_rec.attribute7;
            l_header_rec.attribute8                 :=
                l_source_header_rec.attribute8;
            l_header_rec.attribute9                 :=
                l_source_header_rec.attribute9;
            l_header_rec.attribute10                :=
                l_source_header_rec.attribute10;
            l_header_rec.attribute13                :=
                l_source_header_rec.attribute13;
            l_header_rec.pricing_date               :=
                l_source_header_rec.pricing_date;                   -- ver 2.6
            l_header_rec.ordered_date               :=
                l_source_header_rec.ordered_date;                   -- ver 2.6

            --Added for CCR0009521--
            BEGIN
                l_header_rec.attribute14   :=
                    xxd_ont_order_modify_pkg.get_vas_code ('HEADER', orders_rec.target_sold_to_org_id, NULL
                                                           , NULL, NULL);
                l_header_rec.attribute14   :=
                    NVL (l_header_rec.attribute14,
                         l_source_header_rec.attribute14);          -- ver 2.2
            END;

            --End for CCR0009521--

            l_header_rec.attribute15                :=
                l_source_header_rec.attribute15;
            l_header_rec.attribute11                :=
                l_source_header_rec.attribute11;                    -- ver 2.2
            l_header_rec.attribute12                :=
                l_source_header_rec.attribute12;                    -- ver 2.2
            l_header_rec.attribute16                :=
                l_source_header_rec.attribute16;                    -- ver 2.2
            l_header_rec.attribute17                :=
                l_source_header_rec.attribute17;                    -- ver 2.2
            l_header_rec.attribute18                :=
                l_source_header_rec.attribute18;                    -- ver 2.2
            l_header_rec.attribute19                :=
                l_source_header_rec.attribute19;                    -- ver 2.2
            l_header_rec.context                    :=
                l_source_header_rec.context;                        -- ver 2.2
            l_header_rec.request_date               :=
                orders_rec.header_request_date;
            l_header_rec.demand_class_code          :=
                l_source_header_rec.demand_class_code;
            l_header_rec.sold_to_contact_id         :=
                l_source_header_rec.sold_to_contact_id;
            l_header_rec.operation                  := oe_globals.g_opr_create;

            -- Action Table Details
            l_action_request_tbl (1)                :=
                oe_order_pub.g_miss_request_rec;
            l_action_request_tbl (1).entity_code    :=
                oe_globals.g_entity_header;
            l_action_request_tbl (1).request_type   :=
                oe_globals.g_book_order;
            l_line_tbl_index                        := 0;
            l_line_tbl                              :=
                oe_order_pub.g_miss_line_tbl;

            FOR lines_rec
                IN get_lines_c (orders_rec.source_header_id,
                                orders_rec.attribute3)
            LOOP
                l_source_line_rec   :=
                    oe_line_util.query_row (
                        p_line_id => lines_rec.source_line_id);
                lc_lock_status   := 'S';
                debug_msg (
                       'Processing Source Line Number '
                    || l_source_line_rec.line_number
                    || '.'
                    || l_source_line_rec.shipment_number
                    || '. Line ID '
                    || lines_rec.source_header_id);

                IF lc_lock_status <> 'S'
                THEN
                    lc_error_message       :=
                        'One or more line is locked by another user';
                    debug_msg (lc_error_message);
                    lc_api_return_status   := 'E';
                ELSE
                    -- New Line Details
                    l_line_tbl_index   := l_line_tbl_index + 1;
                    l_line_tbl (l_line_tbl_index)   :=
                        oe_order_pub.g_miss_line_rec;
                    l_line_tbl (l_line_tbl_index).operation   :=
                        oe_globals.g_opr_create;
                    --                l_line_tbl(l_line_tbl_index).header_id                                := FND_API.G_MISS_NUM;
                    l_line_tbl (l_line_tbl_index).ordered_quantity   :=
                        NVL (lines_rec.target_ordered_quantity,
                             fnd_api.g_miss_num);

                    l_line_tbl (l_line_tbl_index).request_date   :=
                        NVL (lines_rec.target_line_request_date,
                             fnd_api.g_miss_date);

                    l_line_tbl (l_line_tbl_index).latest_acceptable_date   :=
                        NVL (lines_rec.target_latest_acceptable_date,
                             fnd_api.g_miss_date);

                    l_line_tbl (l_line_tbl_index).attribute1   :=
                        NVL (
                            fnd_date.date_to_canonical (
                                lines_rec.target_latest_acceptable_date),
                            fnd_api.g_miss_char);

                    l_line_tbl (l_line_tbl_index).ship_from_org_id   :=
                        lines_rec.target_ship_from_org_id;
                    l_line_tbl (l_line_tbl_index).shipping_method_code   :=
                        lines_rec.target_header_ship_method;


                    /*IF ln_target_header_id IS NOT NULL
                    THEN
                      l_line_tbl (1).header_id := ln_target_header_id;
                    END IF;*/
                    debug_msg (
                           ' l_source_line_rec.ship_from_org_id '
                        || l_source_line_rec.ship_from_org_id);
                    debug_msg (
                           ' l_source_line_rec.deliver_to_org_id; '
                        || l_source_line_rec.deliver_to_org_id);
                    debug_msg (
                           ' l_source_line_rec.ship_to_org_id '
                        || l_source_line_rec.ship_to_org_id);

                    -- Assign Source Line value for all other columns
                    l_line_tbl (l_line_tbl_index).cust_po_number   :=
                        l_source_line_rec.cust_po_number;
                    l_line_tbl (l_line_tbl_index).inventory_item_id   :=
                        l_source_line_rec.inventory_item_id;
                    l_line_tbl (l_line_tbl_index).ship_to_org_id   :=
                        l_source_line_rec.ship_to_org_id;

                    --                l_line_tbl(l_line_tbl_index).ship_from_org_id := l_source_line_rec.ship_from_org_id;
                    l_line_tbl (l_line_tbl_index).calculate_price_flag   :=
                        'Y';
                    l_line_tbl (l_line_tbl_index).demand_class_code   :=
                        l_source_line_rec.demand_class_code;
                    l_line_tbl (l_line_tbl_index).unit_list_price   :=
                        l_source_line_rec.unit_list_price;
                    l_line_tbl (l_line_tbl_index).salesrep_id   :=
                        l_source_line_rec.salesrep_id;
                    l_line_tbl (l_line_tbl_index).price_list_id   :=
                        l_source_line_rec.price_list_id;
                    l_line_tbl (l_line_tbl_index).order_source_id   :=
                        ln_order_source_id; -- ver 2.3 l_source_line_rec.order_source_id;
                    l_line_tbl (l_line_tbl_index).payment_term_id   :=
                        l_source_line_rec.payment_term_id;
                    --                l_line_tbl(l_line_tbl_index).shipping_method_code := l_source_line_rec.shipping_method_code;
                    l_line_tbl (l_line_tbl_index).freight_terms_code   :=
                        l_source_line_rec.freight_terms_code;
                    l_line_tbl (l_line_tbl_index).shipping_instructions   :=
                        l_source_line_rec.shipping_instructions;
                    l_line_tbl (l_line_tbl_index).packing_instructions   :=
                        l_source_line_rec.packing_instructions;
                    l_line_tbl (l_line_tbl_index).attribute6   :=
                        l_source_line_rec.attribute6;
                    l_line_tbl (l_line_tbl_index).attribute7   :=
                        l_source_line_rec.attribute7;
                    l_line_tbl (l_line_tbl_index).attribute8   :=
                        l_source_line_rec.attribute8;
                    l_line_tbl (l_line_tbl_index).attribute10   :=
                        l_source_line_rec.attribute10;
                    l_line_tbl (l_line_tbl_index).attribute13   :=
                        l_source_line_rec.attribute13;

                    l_line_tbl (l_line_tbl_index).attribute2   :=
                        l_source_line_rec.attribute2;               -- ver 2.2
                    l_line_tbl (l_line_tbl_index).attribute3   :=
                        l_source_line_rec.attribute3;               -- ver 2.2
                    l_line_tbl (l_line_tbl_index).attribute4   :=
                        l_source_line_rec.attribute4;               -- ver 2.2
                    l_line_tbl (l_line_tbl_index).attribute5   :=
                        l_source_line_rec.attribute5;               -- ver 2.2
                    l_line_tbl (l_line_tbl_index).attribute9   :=
                        l_source_line_rec.attribute9;               -- ver 2.2
                    l_line_tbl (l_line_tbl_index).attribute11   :=
                        l_source_line_rec.attribute11;              -- ver 2.2
                    l_line_tbl (l_line_tbl_index).attribute12   :=
                        l_source_line_rec.attribute12;              -- ver 2.2
                    l_line_tbl (l_line_tbl_index).attribute16   :=
                        l_source_line_rec.attribute16;              -- ver 2.2
                    l_line_tbl (l_line_tbl_index).attribute17   :=
                        l_source_line_rec.attribute17;              -- ver 2.2
                    l_line_tbl (l_line_tbl_index).attribute18   :=
                        l_source_line_rec.attribute18;              -- ver 2.2
                    l_line_tbl (l_line_tbl_index).attribute19   :=
                        l_source_line_rec.attribute19;              -- ver 2.2
                    l_line_tbl (l_line_tbl_index).attribute20   :=
                        l_source_line_rec.attribute20;              -- ver 2.2
                    l_line_tbl (l_line_tbl_index).context   :=
                        l_source_line_rec.context;                  -- ver 2.2


                    --Added for CCR0009521--
                    BEGIN
                        BEGIN
                            lv_color   := NULL;
                            lv_style   := NULL;

                            SELECT color_code, style_number
                              INTO lv_color, lv_style
                              FROM xxd_common_items_v
                             WHERE     organization_id =
                                       NVL (
                                           l_line_tbl (l_line_tbl_index).ship_from_org_id,
                                           l_header_rec.ship_from_org_id)
                                   AND inventory_item_id =
                                       l_line_tbl (l_line_tbl_index).inventory_item_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_color   := NULL;
                                lv_style   := NULL;
                        END;

                        l_line_tbl (l_line_tbl_index).attribute14   :=
                            xxd_ont_order_modify_pkg.get_vas_code (
                                p_level   => 'LINE',
                                p_cust_account_id   =>
                                    l_header_rec.sold_to_org_id,
                                p_site_use_id   =>
                                    l_line_tbl (l_line_tbl_index).ship_to_org_id,
                                p_style   => lv_style,
                                p_color   => lv_color);
                        l_line_tbl (l_line_tbl_index).attribute14   :=
                            NVL (l_line_tbl (l_line_tbl_index).attribute14,
                                 l_source_line_rec.attribute14);    -- ver 2.2
                    END;

                    --End for CCR0009521--

                    l_line_tbl (l_line_tbl_index).attribute15   :=
                        l_source_line_rec.attribute15;
                    l_line_tbl (l_line_tbl_index).deliver_to_org_id   :=
                        l_source_line_rec.deliver_to_org_id;
                    l_line_tbl (l_line_tbl_index).source_document_type_id   :=
                        ln_order_source_id; --; 2; -- 2 for "Copy"  -- ver 2.3
                    l_line_tbl (l_line_tbl_index).source_document_id   :=
                        l_source_line_rec.header_id;
                    l_line_tbl (l_line_tbl_index).source_document_line_id   :=
                        l_source_line_rec.line_id;
                    l_line_tbl (l_line_tbl_index).pricing_date   :=
                        l_source_line_rec.pricing_date;             -- ver 2.6
                END IF;
            END LOOP;

            process_order (p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, p_action_request_tbl => l_action_request_tbl, x_header_rec => lx_header_rec, x_line_tbl => lx_line_tbl, x_return_status => lc_api_return_status
                           , x_error_message => lc_error_message);

            debug_msg (
                'Order Line Creation Status = ' || lc_api_return_status);

            IF lc_api_return_status <> 'S'
            THEN
                l_line_tbl        := oe_order_pub.g_miss_line_tbl;
                oe_msg_pub.delete_msg;
                oe_msg_pub.initialize;
                ROLLBACK TO source_order_line;
                save_point_flag   := 'Y';
                debug_msg (
                    'Order Line Creation Error = ' || lc_error_message);
            ELSE
                save_point_flag   := 'N';
                COMMIT;
            -- Get SSD from OOLA
            --                    SELECT
            --                        trunc(schedule_ship_date)
            --                    INTO ld_target_ssd
            --                    FROM
            --                        oe_order_lines_all
            --                    WHERE
            --                        line_id = lx_line_tbl(1).line_id;

            -- If transaction is "Forced" then rollback when scheduling error

            --                    IF ld_target_ssd IS NULL --AND lines_rec.attribute1 = 'N'
            --                    THEN
            --                        lc_api_return_status := 'E';
            --                        lc_error_message := 'Failed to Schedule Target Order';
            ----                        ROLLBACK TO source_order_line;
            --                    ELSE
            --                        ln_target_header_id := lx_line_tbl(1).header_id;
            --                        ln_target_line_id := lx_line_tbl(1).line_id;
            --                    END IF;
            END IF;

            UPDATE xxd_ont_order_modify_details_t
               SET target_header_id           =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.header_id,
                               target_header_id),
                   target_order_number        =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.order_number,
                               target_order_number),
                   target_order_type_id       =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.order_type_id,
                               target_order_type_id),
                   target_order_type          =
                       DECODE (
                           lc_api_return_status,
                           'S', (SELECT name
                                   FROM oe_transaction_types_tl
                                  WHERE     language = USERENV ('LANG')
                                        AND transaction_type_id =
                                            lx_header_rec.order_type_id),
                           target_order_type),
                   target_sold_to_org_id      =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.sold_to_org_id,
                               target_sold_to_org_id),
                   target_customer_number     =
                       DECODE (
                           lc_api_return_status,
                           'S', (SELECT account_number
                                   FROM hz_cust_accounts
                                  WHERE cust_account_id =
                                        lx_header_rec.sold_to_org_id),
                           target_customer_number),
                   target_line_id              = ln_target_line_id,
                   target_schedule_ship_date   = ld_target_ssd,
                   status                     =
                       DECODE (lc_api_return_status,
                               'U', 'E',
                               lc_api_return_status),
                   error_message               =
                       SUBSTR (lc_error_message, 1, 2000),
                   request_id                  = gn_request_id,
                   last_update_date            = SYSDATE,
                   last_update_login           = fnd_global.login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND source_header_id = ln_source_header_id
                   AND attribute3 = orders_rec.attribute3;

            --AND source_line_id = lines_rec.source_line_id;

            debug_msg (
                'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg (
                   'Updated Status in Custom Table Record Count = '
                || SQL%ROWCOUNT);
            debug_msg (RPAD ('=', 100, '='));
            -- ver 2.2  call copy attachment function
            copy_attachment (ln_source_header_id,
                             lx_header_rec.header_id,
                             'OE_ORDER_HEADERS');
            COMMIT;
        END LOOP;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in COPY_TO_EXISTING_ORDER_PRC = '
                || lc_error_message);
    END copy_sales_order_prc;

    -- ======================================================================================
    -- This procedure called from OA to update the sales order order lines
    -- ======================================================================================

    PROCEDURE xxd_ont_order_lines_update (
        p_ont_order_lines_tbl          xxdo.xxd_ont_order_lines_tbl_type,
        p_org_id                IN     NUMBER,
        p_resp_id               IN     NUMBER,
        p_resp_app_id           IN     NUMBER,
        p_user_id               IN     NUMBER,
        p_action                IN     VARCHAR2,
        pv_error_stat              OUT VARCHAR2,
        pv_error_msg               OUT VARCHAR2)
    AS
        lv_error_msg             VARCHAR2 (4000) := NULL;
        lv_error_stat            VARCHAR2 (4) := 'S';
        lv_error_code            VARCHAR2 (4000) := NULL;
        ln_error_num             NUMBER;
        ln_operation_mode        VARCHAR2 (100);
        ln_group_id              NUMBER;
        ln_req_id                NUMBER;
        lc_status                VARCHAR2 (10);
        ln_record_count          NUMBER;
        ln_valid_count           NUMBER;
        lv_ret_status            VARCHAR2 (10);
        lv_err_msg               VARCHAR2 (4000);
        ln_line_num              NUMBER := 0;
        lv_date                  DATE := NULL;
        lv_open_flag             VARCHAR2 (10);
        ln_header_id             NUMBER := NULL;
        ln_ship_from_org_id      NUMBER := NULL;
        ln_inventory_item_id     NUMBER := NULL;
        lv_ont_order_lines_tbl   xxdo.xxd_ont_order_lines_tbl_type
                                     := xxdo.xxd_ont_order_lines_tbl_type ();
        l_brand                  VARCHAR2 (100);                   -- ver 2.10
    BEGIN
        lv_ont_order_lines_tbl.DELETE;
        lv_ont_order_lines_tbl   := p_ont_order_lines_tbl;

        IF (lv_ont_order_lines_tbl.COUNT = 0)
        THEN
            lv_error_stat   := 'E';
            lv_error_msg    :=
                   lv_error_msg
                || 'Collection Data  counr '
                || lv_ont_order_lines_tbl.COUNT
                || '   ';
        END IF;

        IF (p_action = 'UPDATE')
        THEN
            BEGIN
                IF (lv_ont_order_lines_tbl.COUNT > 0)
                THEN
                    FOR x IN lv_ont_order_lines_tbl.FIRST ..
                             lv_ont_order_lines_tbl.LAST
                    LOOP
                        lv_ont_order_lines_tbl (x).status          := 'I';
                        lv_ont_order_lines_tbl (x).error_message   := NULL;
                        ln_header_id                               := NULL;
                        ln_ship_from_org_id                        := NULL;

                        BEGIN
                            SELECT ooh.header_id, ooh.ship_from_org_id, Attribute5
                              INTO ln_header_id, ln_ship_from_org_id, l_brand -- ver 2.10
                              FROM oe_order_headers_all ooh
                             WHERE ooh.order_number =
                                   lv_ont_order_lines_tbl (x).source_order_number;

                            IF (lv_ont_order_lines_tbl (x).source_line_number IS NULL)
                            THEN
                                NULL;
                            ELSE
                                BEGIN
                                    SELECT open_flag
                                      INTO lv_open_flag
                                      FROM oe_order_lines_all
                                     WHERE     header_id = ln_header_id
                                           AND    line_number
                                               || '.'
                                               || shipment_number =
                                               TO_CHAR (
                                                   lv_ont_order_lines_tbl (x).source_line_number);

                                    IF (lv_open_flag <> 'Y')
                                    THEN
                                        lv_ont_order_lines_tbl (x).status   :=
                                            'E';
                                        lv_ont_order_lines_tbl (x).error_message   :=
                                               lv_ont_order_lines_tbl (x).error_message
                                            || ' Line not in Open Status '
                                            || lv_ont_order_lines_tbl (x).source_line_number
                                            || ' ; ';
                                    END IF;

                                    NULL;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_ont_order_lines_tbl (x).status   :=
                                            'E';
                                        lv_ont_order_lines_tbl (x).error_message   :=
                                               lv_ont_order_lines_tbl (x).error_message
                                            || '  Invalid Line Number '
                                            || lv_ont_order_lines_tbl (x).source_line_number
                                            || ' length '
                                            || LENGTH (
                                                   lv_ont_order_lines_tbl (x).source_line_number)
                                            || 'ln_header_id  ; '
                                            || ln_header_id
                                            || ' ';
                                END;
                            END IF;

                            BEGIN
                                -- begin 2.10
                                SELECT inventory_item_id
                                  INTO ln_inventory_item_id
                                  FROM xxd_common_items_v
                                 WHERE     1 = 1
                                       AND organization_id =
                                           ln_ship_from_org_id
                                       AND brand = l_brand
                                       AND item_number =
                                           lv_ont_order_lines_tbl (x).source_ordered_item;
                            -- end 2.10
                            /*
                                SELECT inventory_item_id
                                  INTO ln_inventory_item_id
                                  FROM mtl_system_items_b
                                 WHERE     segment1 =
                                           lv_ont_order_lines_tbl (x).source_ordered_item
                                       AND organization_id =
                                           ln_ship_from_org_id;
             */
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_ont_order_lines_tbl (x).status   :=
                                        'E';
                                    lv_ont_order_lines_tbl (x).error_message   :=
                                           lv_ont_order_lines_tbl (x).error_message
                                        || '  Invalid SKU'
                                        || lv_ont_order_lines_tbl (x).source_ordered_item
                                        || ' ; ';
                            END;

                            /* ver 2.10
                            IF (lv_ont_order_lines_tbl (x).target_ordered_quantity
                                    IS NULL)
                            THEN
                                lv_ont_order_lines_tbl (x).status := 'E';
                                lv_ont_order_lines_tbl (x).error_message :=
                                       lv_ont_order_lines_tbl (x).error_message
                                    || ' Provide Quantity value ; ';
                            END IF;  ver 2.10 */

                            IF (lv_ont_order_lines_tbl (x).target_ordered_quantity IS NOT NULL)
                            THEN
                                IF (REGEXP_LIKE (lv_ont_order_lines_tbl (x).target_ordered_quantity, '^[0-9]+$'))
                                THEN
                                    NULL;
                                ELSE
                                    lv_ont_order_lines_tbl (x).status   :=
                                        'E';
                                    lv_ont_order_lines_tbl (x).error_message   :=
                                           lv_ont_order_lines_tbl (x).error_message
                                        || ' Invalid Quantity ; ';
                                END IF;
                            END IF;

                            --  IF lv_ont_order_lines_tbl (x).target_ordered_quantity <>
                            --     0  -- ver 2.12
                            --  THEN                                   -- ver 2.11
                            IF (lv_ont_order_lines_tbl (x).target_line_request_date IS NOT NULL)
                            THEN
                                BEGIN
                                    lv_date   :=
                                        TO_DATE (
                                            lv_ont_order_lines_tbl (x).target_line_request_date,
                                            'DD-Mon-YY');
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_ont_order_lines_tbl (x).status   :=
                                            'E';
                                        lv_ont_order_lines_tbl (x).error_message   :=
                                               lv_ont_order_lines_tbl (x).error_message
                                            || ' Invalid Request Date(DD-MM-YY) ; '
                                            || lv_ont_order_lines_tbl (x).target_line_request_date;

                                        lv_ont_order_lines_tbl (x).target_line_request_date   :=
                                            NULL;
                                END;
                            END IF;

                            IF (lv_ont_order_lines_tbl (x).target_latest_acceptable_date IS NOT NULL)
                            THEN
                                BEGIN
                                    lv_date   :=
                                        TO_DATE (
                                            lv_ont_order_lines_tbl (x).target_latest_acceptable_date,
                                            'DD-Mon-YY');
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_ont_order_lines_tbl (x).status   :=
                                            'E';
                                        lv_ont_order_lines_tbl (x).error_message   :=
                                               lv_ont_order_lines_tbl (x).error_message
                                            || ' Invalid Latest Acceptable Date(DD-Mon-YY) ; '
                                            || lv_ont_order_lines_tbl (x).target_latest_acceptable_date;

                                        lv_ont_order_lines_tbl (x).target_latest_acceptable_date   :=
                                            NULL;
                                END;
                            END IF;

                            IF (lv_ont_order_lines_tbl (x).target_header_cancel_date IS NOT NULL)
                            THEN
                                BEGIN
                                    lv_date   :=
                                        TO_DATE (
                                            lv_ont_order_lines_tbl (x).target_header_cancel_date,
                                            'DD-Mon-YY');
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_ont_order_lines_tbl (x).status   :=
                                            'E';
                                        lv_ont_order_lines_tbl (x).error_message   :=
                                               lv_ont_order_lines_tbl (x).error_message
                                            || ' Invalid Cancel Date(DD-Mon-YY) ; '
                                            || lv_ont_order_lines_tbl (x).target_header_cancel_date;

                                        lv_ont_order_lines_tbl (x).target_header_cancel_date   :=
                                            NULL;
                                END;
                            END IF;

                            IF (lv_ont_order_lines_tbl (x).target_latest_acceptable_date IS NULL)
                            THEN
                                lv_ont_order_lines_tbl (x).target_latest_acceptable_date   :=
                                    lv_ont_order_lines_tbl (x).target_header_cancel_date;
                            ELSE
                                IF (lv_ont_order_lines_tbl (x).target_line_request_date IS NOT NULL)
                                THEN
                                    IF (lv_ont_order_lines_tbl (x).target_line_request_date > lv_ont_order_lines_tbl (x).target_latest_acceptable_date)
                                    THEN
                                        lv_ont_order_lines_tbl (x).status   :=
                                            'E';
                                        lv_ont_order_lines_tbl (x).error_message   :=
                                               lv_ont_order_lines_tbl (x).error_message
                                            || ' Latest Acceptable Date should be greater than Request Date ; ';
                                    END IF;
                                END IF;
                            END IF;

                            IF (lv_ont_order_lines_tbl (x).target_header_cancel_date IS NULL)
                            THEN
                                lv_ont_order_lines_tbl (x).target_header_cancel_date   :=
                                    lv_ont_order_lines_tbl (x).target_latest_acceptable_date;
                            ELSE
                                IF (lv_ont_order_lines_tbl (x).target_line_request_date IS NOT NULL)
                                THEN
                                    IF (lv_ont_order_lines_tbl (x).target_line_request_date > lv_ont_order_lines_tbl (x).target_header_cancel_date)
                                    THEN
                                        lv_ont_order_lines_tbl (x).status   :=
                                            'E';
                                        lv_ont_order_lines_tbl (x).error_message   :=
                                               lv_ont_order_lines_tbl (x).error_message
                                            || ' Cancel Date should be greater than Request Date ; ';
                                    END IF;
                                END IF;
                            END IF;
                        --  END IF;                                -- ver 2.11  -- ver 2.12 commented the if condition
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_ont_order_lines_tbl (x).status   := 'E';
                                lv_ont_order_lines_tbl (x).error_message   :=
                                    'Order Number Invalid';
                        END;
                    END LOOP;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';
                    lv_error_msg    :=
                           lv_error_msg
                        || 'Error While Collect The Data  '
                        || SQLERRM;
            END;

            BEGIN
                FORALL i
                    IN lv_ont_order_lines_tbl.FIRST ..
                       lv_ont_order_lines_tbl.LAST
                  SAVE EXCEPTIONS
                    UPDATE xxd_ont_order_modify_details_t
                       SET target_ordered_quantity = lv_ont_order_lines_tbl (i).target_ordered_quantity, target_line_request_date = lv_ont_order_lines_tbl (i).target_line_request_date, target_header_cancel_date = lv_ont_order_lines_tbl (i).target_header_cancel_date,
                           target_latest_acceptable_date = lv_ont_order_lines_tbl (i).target_latest_acceptable_date, target_change_reason = lv_ont_order_lines_tbl (i).target_change_reason, target_change_reason_code = lv_ont_order_lines_tbl (i).target_change_reason_code,
                           target_line_cancel_date = lv_ont_order_lines_tbl (i).target_line_cancel_date, attribute4 = NVL (lv_ont_order_lines_tbl (i).attribute4, 'N'), status = DECODE (NVL (lv_ont_order_lines_tbl (i).attribute4, 'N'), 'N', 'E', NVL (lv_ont_order_lines_tbl (i).status, 'I')),
                           error_message = DECODE (NVL (lv_ont_order_lines_tbl (i).attribute4, 'N'), 'N', 'Line Un-Selected', lv_ont_order_lines_tbl (i).error_message), --lv_ont_order_lines_tbl(i).error_message
                                                                                                                                                                         source_line_number = lv_ont_order_lines_tbl (i).source_line_number
                     WHERE     source_order_number =
                               lv_ont_order_lines_tbl (i).source_order_number
                           AND attribute3 =
                               lv_ont_order_lines_tbl (i).attribute3
                           AND GROUP_ID = lv_ont_order_lines_tbl (i).GROUP_ID;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';

                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        ln_error_num   := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                        lv_error_code   :=
                            SQLERRM (-1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                        lv_error_msg   :=
                            SUBSTR (
                                (lv_error_msg || ' Error While Insert into Table ' || lv_ont_order_lines_tbl (ln_error_num).source_order_number || lv_error_code),
                                1,
                                4000);
                    END LOOP;
            END;
        END IF;

        IF (p_action = 'DELETE')
        THEN
            BEGIN
                FORALL i
                    IN lv_ont_order_lines_tbl.FIRST ..
                       lv_ont_order_lines_tbl.LAST
                  SAVE EXCEPTIONS
                    DELETE xxd_ont_order_modify_details_t
                     WHERE     source_order_number =
                               lv_ont_order_lines_tbl (i).source_order_number
                           AND attribute3 =
                               lv_ont_order_lines_tbl (i).attribute3
                           AND GROUP_ID = lv_ont_order_lines_tbl (i).GROUP_ID;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';

                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        ln_error_num   := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                        lv_error_code   :=
                            SQLERRM (-1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                        lv_error_msg   :=
                            SUBSTR (
                                (lv_error_msg || '  Error While Delete The Record Table ' || lv_ont_order_lines_tbl (ln_error_num).source_order_number || ' Line Number ' || lv_ont_order_lines_tbl (ln_error_num).source_line_number || lv_error_code),
                                1,
                                4000);
                    END LOOP;
            END;
        END IF;

        IF (lv_error_stat = 'E')
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            pv_error_stat   := 'S';

            IF (p_action = 'UPDATE')
            THEN
                pv_error_msg   :=
                       lv_error_msg
                    || ' Successfully Records Inserted, Please Click on Submit To Update Button ';
            ELSE
                pv_error_msg   :=
                       lv_error_msg
                    || ' Successfully Records Delete, Please Click on Submit To Update Button ';
            END IF;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Error While Inserting to Table ' || SQLERRM;
            ROLLBACK;
    END xxd_ont_order_lines_update;


    -- ======================================================================================
    -- This procedure performs updates to an existing order
    -- ======================================================================================

    PROCEDURE update_order_lines_prc (p_group_id IN NUMBER, p_batch_id IN NUMBER, p_freeAtp_flag IN VARCHAR2 -- ver 2.11
                                                                                                            )
    AS
        CURSOR get_orders_c IS
            SELECT DISTINCT source_order_number, source_header_id, org_id
              FROM xxd_ont_order_modify_details_t
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND NVL (attribute4, 'N') = 'Y';

        CURSOR get_lines_c (
            p_header_id IN oe_order_headers_all.header_id%TYPE)
        IS
            SELECT source_line_id, target_inventory_item_id, target_ordered_quantity,
                   target_line_request_date, target_latest_acceptable_date, target_change_reason_code,
                   target_line_cancel_date, attribute3 -- Added for CCR0009521
              FROM xxd_ont_order_modify_details_t
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND source_header_id = p_header_id
                   AND NVL (attribute4, 'N') = 'Y';

        lc_sub_prog_name       VARCHAR2 (100) := 'UPDATE_ORDER_PRC';
        lc_api_return_status   VARCHAR2 (1);
        lc_lock_status         VARCHAR2 (1);
        lc_error_message       VARCHAR2 (4000);
        ln_line_tbl_count      NUMBER := 0;
        l_header_rec           oe_order_pub.header_rec_type;
        lx_header_rec          oe_order_pub.header_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        lx_line_tbl            oe_order_pub.line_tbl_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
        ln_cust_account_id     NUMBER;
        ln_ship_to_org_id      NUMBER;
        lv_color               VARCHAR2 (1000);
        lv_style               VARCHAR2 (1000);
        ln_ship_from_org_id    NUMBER;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        -- begin  ver 2.7
        validate_line (p_group_id, p_batch_id);

        -- end ver 2.7
        FOR orders_rec IN get_orders_c
        LOOP
            lc_lock_status   := 'S';

            -- Try locking all lines in the order
            oe_line_util.lock_rows (
                p_header_id       => orders_rec.source_header_id,
                x_line_tbl        => l_line_tbl,
                x_return_status   => lc_lock_status);

            IF lc_lock_status = 'S'
            THEN
                lc_api_return_status     := NULL;
                lc_error_message         := NULL;
                oe_msg_pub.delete_msg;
                oe_msg_pub.initialize;
                ln_line_tbl_count        := 0;
                debug_msg (RPAD ('=', 100, '='));
                debug_msg (
                       'Processing Order Number '
                    || orders_rec.source_order_number
                    || '. Header ID '
                    || orders_rec.source_header_id);
                debug_msg (
                       'Start Time '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                l_header_rec             := oe_order_pub.g_miss_header_rec;


                -- Header
                l_header_rec.header_id   := orders_rec.source_header_id;
                l_header_rec.org_id      := orders_rec.org_id;
                l_header_rec.operation   := oe_globals.g_opr_update;

                --Added for CCR0009521--
                BEGIN
                    ln_cust_account_id    := NULL;
                    ln_ship_to_org_id     := NULL;
                    ln_ship_from_org_id   := NULL;

                    SELECT sold_to_org_id, ship_to_org_id, ship_from_org_id
                      INTO ln_cust_account_id, ln_ship_to_org_id, ln_ship_from_org_id
                      FROM oe_order_headers_all
                     WHERE header_id = orders_rec.source_header_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_cust_account_id    := NULL;
                        ln_ship_to_org_id     := NULL;
                        ln_ship_from_org_id   := NULL;
                END;

                --End for CCR0009521--

                -- Lines

                FOR lines_rec IN get_lines_c (orders_rec.source_header_id)
                LOOP
                    l_line_tbl          := oe_order_pub.g_miss_line_tbl;
                    -- ln_line_tbl_count := ln_line_tbl_count + 1;
                    ln_line_tbl_count   := 1;
                    l_line_tbl (ln_line_tbl_count)   :=
                        oe_order_pub.g_miss_line_rec;
                    -- Original Line Changes
                    l_line_tbl (ln_line_tbl_count).header_id   :=
                        orders_rec.source_header_id;
                    l_line_tbl (ln_line_tbl_count).org_id   :=
                        orders_rec.org_id;

                    IF lines_rec.source_line_id IS NOT NULL
                    THEN
                        l_line_tbl (ln_line_tbl_count).line_id   :=
                            lines_rec.source_line_id;
                        l_line_tbl (ln_line_tbl_count).operation   :=
                            oe_globals.g_opr_update;
                        debug_msg ('  p_freeAtp_flag: ' || p_freeAtp_flag);

                        -- begin ver 2.11
                        IF p_freeAtp_flag = 'Y'
                        THEN
                            xxd_ont_bulk_calloff_pkg.gc_no_unconsumption   :=
                                'Y';
                        ELSE
                            xxd_ont_bulk_calloff_pkg.gc_no_unconsumption   :=
                                NULL;
                        END IF;

                        debug_msg (
                               'after setting xxd_ont_bulk_calloff_pkg.gc_no_unconsumption based on atp flag value: '
                            || xxd_ont_bulk_calloff_pkg.gc_no_unconsumption);
                    -- end version 2.11
                    ELSE
                        l_line_tbl (ln_line_tbl_count).inventory_item_id   :=
                            lines_rec.target_inventory_item_id;
                        l_line_tbl (ln_line_tbl_count).operation   :=
                            oe_globals.g_opr_create;

                        --Added for CCR0009521--
                        BEGIN
                            lv_style   := NULL;
                            lv_color   := NULL;

                            SELECT REGEXP_SUBSTR (msi.concatenated_segments, '[^-]+', 1
                                                  , 1),
                                   REGEXP_SUBSTR (msi.concatenated_segments, '[^-]+', 1
                                                  , 2)
                              INTO lv_style, lv_color
                              FROM mtl_system_items_kfv msi
                             WHERE     msi.organization_id =
                                       NVL (ln_ship_from_org_id,
                                            organization_id)
                                   AND msi.inventory_item_id =
                                       lines_rec.target_inventory_item_id
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_color   := NULL;
                                lv_style   := NULL;
                        END;

                        BEGIN
                            l_line_tbl (ln_line_tbl_count).attribute14   :=
                                xxd_ont_order_modify_pkg.get_vas_code (
                                    p_level             => 'LINE',
                                    p_cust_account_id   => ln_cust_account_id,
                                    p_site_use_id       => ln_ship_to_org_id,
                                    p_style             => lv_style,
                                    p_color             => lv_color);
                        END;
                    --End for CCR0009521--

                    END IF;

                    l_line_tbl (ln_line_tbl_count).ordered_quantity   :=
                        NVL (lines_rec.target_ordered_quantity,
                             fnd_api.g_miss_num);

                    --  IF lines_rec.target_ordered_quantity <> 0   -- ver 2.12 commented qty <> 0
                    --  THEN                                           -- ver 2.11
                    l_line_tbl (ln_line_tbl_count).request_date   :=
                        NVL (lines_rec.target_line_request_date,
                             fnd_api.g_miss_date);

                    IF lines_rec.target_latest_acceptable_date IS NOT NULL
                    THEN                                            -- VER 2.9
                        l_line_tbl (ln_line_tbl_count).latest_acceptable_date   :=
                            lines_rec.target_latest_acceptable_date;
                    /*  l_line_tbl (ln_line_tbl_count).latest_acceptable_date :=
                          NVL (
                              NVL (lines_rec.target_latest_acceptable_date,
                                   lines_rec.target_line_cancel_date),
                              fnd_api.g_miss_date); */
                    END IF;

                    IF lines_rec.target_line_cancel_date IS NOT NULL
                    THEN                                            -- VER 2.9
                        l_line_tbl (ln_line_tbl_count).attribute1   :=
                            fnd_date.date_to_canonical (
                                lines_rec.target_line_cancel_date);
                    /* l_line_tbl (ln_line_tbl_count).attribute1 :=
                          NVL (
                              fnd_date.date_to_canonical (
                                  NVL (lines_rec.target_line_cancel_date,
                                       lines_rec.target_latest_acceptable_date)),
                              fnd_api.g_miss_char);
                     */
                    END IF;                                        -- ver 2.11

                    --  END IF;  -- ver 2.12

                    l_line_tbl (ln_line_tbl_count).change_reason   :=
                        lines_rec.target_change_reason_code;
                    l_line_tbl (ln_line_tbl_count).change_comments   :=
                           'Line modified on '
                        || SYSDATE
                        || ' by program request_id: '
                        || gn_request_id;

                    l_line_tbl (ln_line_tbl_count).request_id   :=
                        gn_request_id;
                    debug_msg (
                           'just before API xxd_ont_bulk_calloff_pkg.gc_no_unconsumption: '
                        || xxd_ont_bulk_calloff_pkg.gc_no_unconsumption);


                    process_order (p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, p_action_request_tbl => l_action_request_tbl, x_header_rec => lx_header_rec, x_line_tbl => lx_line_tbl, x_return_status => lc_api_return_status
                                   , x_error_message => lc_error_message);
                    debug_msg (
                           'after API xxd_ont_bulk_calloff_pkg.gc_no_unconsumption: '
                        || xxd_ont_bulk_calloff_pkg.gc_no_unconsumption);


                    debug_msg (
                        'Order Update Status = ' || lc_api_return_status);

                    IF lc_api_return_status <> 'S'
                    THEN
                        debug_msg (
                            'Order Update Error = ' || lc_error_message);
                    ELSE
                        debug_msg (
                            'Target Order Header ID ' || lx_header_rec.header_id);
                    END IF;

                    UPDATE xxd_ont_order_modify_details_t
                       SET target_header_id   =
                               DECODE (lc_api_return_status,
                                       'S', lx_header_rec.header_id,
                                       target_header_id),
                           target_order_number   =
                               DECODE (lc_api_return_status,
                                       'S', lx_header_rec.order_number,
                                       target_order_number),
                           target_order_type_id   =
                               DECODE (lc_api_return_status,
                                       'S', lx_header_rec.order_type_id,
                                       target_order_type_id),
                           target_order_type   =
                               DECODE (
                                   lc_api_return_status,
                                   'S', (SELECT name
                                           FROM oe_transaction_types_tl
                                          WHERE     language =
                                                    USERENV ('LANG')
                                                AND transaction_type_id =
                                                    lx_header_rec.order_type_id),
                                   target_order_type),
                           target_sold_to_org_id   =
                               DECODE (lc_api_return_status,
                                       'S', lx_header_rec.sold_to_org_id,
                                       target_sold_to_org_id),
                           target_customer_number   =
                               DECODE (
                                   lc_api_return_status,
                                   'S', (SELECT account_number
                                           FROM hz_cust_accounts
                                          WHERE cust_account_id =
                                                lx_header_rec.sold_to_org_id),
                                   target_customer_number),
                           target_line_id      = source_line_id,
                           target_schedule_ship_date   =
                               (SELECT TRUNC (schedule_ship_date)
                                  FROM oe_order_lines_all
                                 WHERE line_id = source_line_id),
                           status              = lc_api_return_status,
                           error_message      =
                               SUBSTR (error_message || lc_error_message,
                                       1,
                                       2000),
                           request_id          = gn_request_id,
                           last_update_date    = SYSDATE,
                           last_update_login   = gn_login_id,
                           attribute12         = p_freeAtp_flag    -- ver 2.11
                     WHERE     status = 'N'
                           AND batch_id = p_batch_id
                           AND GROUP_ID = p_group_id
                           AND source_header_id = orders_rec.source_header_id
                           --AND source_line_id = lines_rec.source_line_id;
                           AND attribute3 = lines_rec.attribute3 -- Added for CCR0009521
                           AND target_inventory_item_id =
                               lines_rec.target_inventory_item_id; -- Added for CCR0009521

                    debug_msg (
                           'End Time '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                    debug_msg (
                           'Updated Status in Custom Table Record Count = '
                        || SQL%ROWCOUNT);
                    debug_msg (RPAD ('=', 100, '='));
                    COMMIT;
                END LOOP;
            ELSE
                lc_error_message       :=
                    'One or more line is locked by another user';
                debug_msg (lc_error_message);
                lc_api_return_status   := 'E';

                ----start Added for CCR0009521
                UPDATE xxd_ont_order_modify_details_t
                   SET status = 'E', error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                       last_update_date = SYSDATE, last_update_login = gn_login_id
                 WHERE     status = 'N'
                       AND batch_id = p_batch_id
                       AND GROUP_ID = p_group_id
                       AND source_header_id = orders_rec.source_header_id;
            ----End Added for CCR0009521
            END IF;
        END LOOP;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in UPDATE_ORDER_PRC = ' || lc_error_message);
    END update_order_lines_prc;

    -- ======================================================================================
    -- This procedure called from OA to Delete the Book,Cancel and update Order lines
    -- ======================================================================================

    PROCEDURE xxd_ont_order_delete (
        p_ont_order_lines_tbl          xxdo.xxd_ont_order_lines_tbl_type,
        p_org_id                IN     NUMBER,
        p_resp_id               IN     NUMBER,
        p_resp_app_id           IN     NUMBER,
        p_user_id               IN     NUMBER,
        p_operation_mode        IN     VARCHAR2,
        pv_error_stat              OUT VARCHAR2,
        pv_error_msg               OUT VARCHAR2)
    AS
        lv_error_msg    VARCHAR2 (4000) := NULL;
        lv_error_stat   VARCHAR2 (4) := 'S';
        lv_error_code   VARCHAR2 (4000) := NULL;
        ln_error_num    NUMBER;
    BEGIN
        IF (p_ont_order_lines_tbl.COUNT > 0)
        THEN
            BEGIN
                FORALL i
                    IN p_ont_order_lines_tbl.FIRST ..
                       p_ont_order_lines_tbl.LAST
                  SAVE EXCEPTIONS
                    DELETE xxd_ont_order_modify_details_t
                     WHERE     source_order_number =
                               p_ont_order_lines_tbl (i).source_order_number
                           AND attribute3 =
                               p_ont_order_lines_tbl (i).attribute3
                           AND attribute2 =
                               p_ont_order_lines_tbl (i).attribute2
                           AND GROUP_ID = p_ont_order_lines_tbl (i).GROUP_ID
                           AND operation_mode = p_operation_mode;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';

                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        ln_error_num   := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                        lv_error_code   :=
                            SQLERRM (-1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                        lv_error_msg   :=
                            SUBSTR (
                                (lv_error_msg || '  Error While Delete The Record Table ' || p_ont_order_lines_tbl (ln_error_num).source_order_number || lv_error_code),
                                1,
                                4000);
                    END LOOP;
            END;
        END IF;

        IF (lv_error_stat = 'E')
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            pv_error_stat   := 'S';

            IF p_operation_mode = 'XXD_ONT_CANCEL'
            THEN                                                    -- VER 2.6
                pv_error_msg   :=
                    lv_error_msg || ' Records Successfully  Deleted.';
            ELSE
                pv_error_msg   :=
                       lv_error_msg
                    || ' Successfully Records Deleted, Please Click on Submit To Update Button ';
            END IF;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                'Error While Deleting Order Number ' || SQLERRM;
            ROLLBACK;
    END xxd_ont_order_delete;

    /*---------------------------2.0 End GSA Project-----------------------------------*/

    --Start changes for v2.1

    FUNCTION get_vas_code (p_level IN VARCHAR2, p_cust_account_id IN NUMBER, p_site_use_id IN NUMBER
                           , p_style IN VARCHAR2, p_color IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_vas_code   VARCHAR2 (240) := NULL;
        l_style      VARCHAR (240);

        CURSOR lcu_get_vas_code_text (p_cust_account_id IN NUMBER)
        IS
            SELECT title short_text
              FROM oe_attachment_rules oar, fnd_documents_vl fdv, fnd_documents_short_text fdl,
                   fnd_document_categories_vl fdc, hz_cust_accounts cust, oe_attachment_rule_elements_v oare
             WHERE     1 = 1
                   --AND OAR.rule_id        = p_rule_id
                   AND oar.document_id = fdv.document_id
                   AND fdv.datatype_name = 'Short Text'
                   AND fdv.media_id = fdl.media_id
                   AND fdc.category_id = fdv.category_id
                   AND fdc.application_id = 660
                   AND fdc.user_name = 'VAS Codes'
                   AND oare.rule_id = oar.rule_id
                   AND oare.attribute_name = 'Customer'
                   AND TO_CHAR (cust.cust_account_id) = oare.attribute_value
                   AND oare.attribute_value = TO_CHAR (p_cust_account_id)
                   AND TRUNC (SYSDATE) BETWEEN NVL (fdv.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (fdv.end_date_active,
                                                    TRUNC (SYSDATE))
                   AND TRUNC (SYSDATE) BETWEEN NVL (fdc.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (fdc.end_date_active,
                                                    TRUNC (SYSDATE));
    BEGIN
        SELECT DECODE (INSTR (p_style, '-'), 0, p_style, SUBSTR (p_style, 1, INSTR (p_style, '-') - 1))
          INTO l_style
          FROM DUAL;

        IF p_level = 'HEADER'
        THEN
            SELECT SUBSTR (LISTAGG (vas_code, '+') WITHIN GROUP (ORDER BY vas_code), 1, 240)
              INTO l_vas_code
              FROM (SELECT DISTINCT vas_code
                      FROM xxd_ont_vas_assignment_dtls_t
                     WHERE     1 = 1
                           AND cust_account_id = p_cust_account_id
                           AND attribute_level IN ('CUSTOMER'));
        ELSIF p_level = 'LINE'
        THEN
            SELECT SUBSTR (LISTAGG (vas_code, '+') WITHIN GROUP (ORDER BY vas_code), 1, 240)
              INTO l_vas_code
              FROM (SELECT vas_code
                      FROM xxd_ont_vas_assignment_dtls_t a
                     WHERE     a.attribute_level = 'STYLE'
                           AND a.attribute_value = l_style
                           AND cust_account_id = p_cust_account_id --- for style
                    UNION
                    SELECT vas_code
                      FROM xxd_ont_vas_assignment_dtls_t a
                     WHERE     a.attribute_level = 'STYLE_COLOR'
                           AND a.attribute_value = l_style || '-' || p_color
                           AND cust_account_id = p_cust_account_id --- style color
                    UNION
                    SELECT vas_code
                      FROM xxd_ont_vas_assignment_dtls_t a, hz_cust_site_uses_all b
                     WHERE     1 = 1
                           AND cust_account_id = p_cust_account_id
                           AND b.site_use_id = p_site_use_id
                           AND b.cust_acct_site_id = a.attribute_value
                           AND attribute_level IN ('SITE'));
        END IF;

        IF l_vas_code IS NULL AND p_level = 'HEADER'
        THEN
            FOR lr_get_vas_code_text
                IN lcu_get_vas_code_text (p_cust_account_id)
            LOOP
                IF l_vas_code IS NULL
                THEN
                    l_vas_code   := lr_get_vas_code_text.short_text;
                ELSE
                    l_vas_code   :=
                        l_vas_code || '+' || lr_get_vas_code_text.short_text;
                END IF;
            END LOOP;
        END IF;

        RETURN l_vas_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN l_vas_code;
    END get_vas_code;

    --End changes for v2.1
    -- begin added for ber 2.2
    PROCEDURE copy_attachment (p_source_pk_value VARCHAR2, p_target_pk_value VARCHAR2, p_in_entity VARCHAR2)
    AS
        l_sequence   NUMBER;

        -- get long text of source entity
        CURSOR c_long (p_source_pk_value VARCHAR2, p_in_entity VARCHAR2)
        IS
            SELECT ad.seq_num, dt.title, dct.category_id,
                   dt.description, dat.datatype_id, dlt.long_text,
                   det.data_object_code entity_name, ad.pk1_value, d.media_id
              FROM fnd_document_datatypes dat, fnd_document_entities_tl det, fnd_documents_tl dt,
                   fnd_documents d, fnd_document_categories_tl dct, fnd_attached_documents ad,
                   fnd_documents_long_text dlt
             WHERE     d.document_id = ad.document_id
                   AND dt.document_id = d.document_id
                   AND dct.category_id = d.category_id
                   AND d.datatype_id = dat.datatype_id
                   AND ad.entity_name = det.data_object_code
                   AND dlt.media_id = d.media_id
                   AND dat.NAME = 'LONG_TEXT'
                   AND ad.entity_name = p_in_entity       --'OE_ORDER_HEADERS'
                   AND automatically_added_flag = 'N'
                   AND dct.LANGUAGE = 'US'
                   AND det.LANGUAGE = 'US'
                   AND dt.LANGUAGE = 'US'
                   AND dat.LANGUAGE = 'US'
                   AND pk1_value = p_source_pk_value;

        CURSOR c_short (p_source_pk_value VARCHAR2, p_in_entity VARCHAR2)
        IS
            SELECT ad.seq_num, dt.title, dct.category_id,
                   dt.description, dat.datatype_id, dlt.short_text,
                   det.data_object_code entity_name, ad.pk1_value, d.media_id
              FROM fnd_document_datatypes dat, fnd_document_entities_tl det, fnd_documents_tl dt,
                   fnd_documents d, fnd_document_categories_tl dct, fnd_attached_documents ad,
                   fnd_documents_short_text dlt
             WHERE     d.document_id = ad.document_id
                   AND dt.document_id = d.document_id
                   AND dct.category_id = d.category_id
                   AND d.datatype_id = dat.datatype_id
                   AND ad.entity_name = det.data_object_code
                   AND dlt.media_id = d.media_id
                   AND ad.entity_name = p_in_entity      -- 'OE_ORDER_HEADERS'
                   AND automatically_added_flag = 'N'
                   AND dat.NAME = 'SHORT_TEXT'
                   AND dct.LANGUAGE = 'US'
                   AND det.LANGUAGE = 'US'
                   AND dt.LANGUAGE = 'US'
                   AND dat.LANGUAGE = 'US'
                   AND pk1_value = p_source_pk_value;



        CURSOR c_file (p_source_pk_value VARCHAR2, p_in_entity VARCHAR2)
        IS
            SELECT ad.seq_num, dt.title, dct.category_id,
                   dt.description, dat.datatype_id, ad.entity_name,
                   ad.pk1_value, d.media_id, l.file_name
              FROM fnd_document_datatypes dat, fnd_document_entities_tl det, fnd_documents_tl dt,
                   fnd_documents d, fnd_document_categories_tl dct, fnd_attached_documents ad,
                   fnd_lobs l
             WHERE     d.document_id = ad.document_id
                   AND dt.document_id = d.document_id
                   AND dct.category_id = d.category_id
                   AND d.datatype_id = dat.datatype_id
                   AND ad.entity_name = det.data_object_code
                   AND l.file_id = d.media_id
                   AND dat.NAME = 'FILE'
                   AND ad.entity_name = p_in_entity       --'OE_ORDER_HEADERS'
                   AND automatically_added_flag = 'N'
                   AND dct.LANGUAGE = 'US'
                   AND det.LANGUAGE = 'US'
                   AND dt.LANGUAGE = 'US'
                   AND dat.LANGUAGE = 'US'
                   AND pk1_value = p_source_pk_value;
    BEGIN
        FOR rec_long IN c_long (p_source_pk_value, p_in_entity)
        LOOP
            BEGIN
                SELECT NVL (MAX (seq_num), 0) + 10
                  INTO l_sequence
                  FROM fnd_attached_documents
                 WHERE     pk1_value = p_target_pk_value
                       AND entity_name = p_in_entity;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_sequence   := 0;
            END;

            fnd_webattch.add_attachment (
                seq_num                => l_sequence,
                category_id            => rec_long.category_id,
                document_description   => rec_long.description,
                datatype_id            => rec_long.datatype_id,
                text                   => rec_long.long_text,
                file_name              => NULL,
                url                    => NULL,
                function_name          => NULL,      --rec_long.function_name,
                entity_name            => rec_long.entity_name,
                pk1_value              => p_target_pk_value,
                pk2_value              => NULL,
                pk3_value              => NULL,
                pk4_value              => NULL,
                pk5_value              => NULL,
                media_id               => rec_long.media_id,
                user_id                => fnd_global.user_id,
                usage_type             => 'O',
                title                  => rec_long.title);
        END LOOP;



        FOR rec_short IN c_short (p_source_pk_value, p_in_entity)
        LOOP
            BEGIN
                SELECT NVL (MAX (seq_num), 0) + 10
                  INTO l_sequence
                  FROM fnd_attached_documents
                 WHERE     pk1_value = p_target_pk_value
                       AND entity_name = p_in_entity;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_sequence   := 0;
            END;

            fnd_webattch.add_attachment (
                seq_num                => l_sequence,
                category_id            => rec_short.category_id,
                document_description   => rec_short.description,
                datatype_id            => rec_short.datatype_id,
                text                   => rec_short.short_text,
                file_name              => NULL,
                url                    => NULL,
                function_name          => NULL,     --rec_short.function_name,
                entity_name            => rec_short.entity_name,
                pk1_value              => p_target_pk_value,
                pk2_value              => NULL,
                pk3_value              => NULL,
                pk4_value              => NULL,
                pk5_value              => NULL,
                media_id               => rec_short.media_id,
                user_id                => fnd_global.user_id,
                usage_type             => 'O',
                title                  => rec_short.title);
        END LOOP;


        FOR rec_file IN c_file (p_source_pk_value, p_in_entity)
        LOOP
            BEGIN
                SELECT NVL (MAX (seq_num), 0) + 10
                  INTO l_sequence
                  FROM fnd_attached_documents
                 WHERE     pk1_value = p_target_pk_value
                       AND entity_name = p_in_entity;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_sequence   := 0;
            END;

            fnd_webattch.add_attachment (
                seq_num                => l_sequence,
                category_id            => rec_file.category_id,
                document_description   => rec_file.description,
                datatype_id            => rec_file.datatype_id,
                text                   => NULL,
                file_name              => rec_file.file_name,
                url                    => NULL,
                function_name          => NULL,      --rec_file.function_name,
                entity_name            => rec_file.entity_name,
                pk1_value              => p_target_pk_value,
                pk2_value              => NULL,
                pk3_value              => NULL,
                pk4_value              => NULL,
                pk5_value              => NULL,
                media_id               => rec_file.media_id,
                user_id                => fnd_global.user_id,
                usage_type             => 'O',
                title                  => rec_file.title);
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line ('error:' || SQLERRM);
    END copy_attachment;

    -- end ver 2.2
    -- begin 2.8
    -- context: XXD_ONT_CANCEL
    --  Attribute13 CANCEL ENTIRE ORDER FLAG
    -- Attribute14 CANCEL UNSCHLD LINES FLAG
    -- Attribute15 RESEND855 FLAG
    PROCEDURE process_cancel_order_file855 (p_file_id IN NUMBER, p_org_id IN NUMBER, p_operation_mode IN VARCHAR2
                                            , x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, x_file_id OUT NOCOPY VARCHAR2)
    AS
        lv_error_msg        VARCHAR2 (4000) := NULL;
        lv_error_stat       VARCHAR2 (4) := 'S';
        lv_error_code       VARCHAR2 (4000) := NULL;
        ln_error_num        NUMBER;
        ln_operation_mode   VARCHAR2 (100);
        ln_group_id         NUMBER;
        ln_req_id           NUMBER;
        lc_status           VARCHAR2 (10);
        ln_record_count     NUMBER;
        ln_valid_count      NUMBER;
        ln_line_num         NUMBER := 0;

        CURSOR cur_val IS
            (SELECT TRANSLATE (REGEXP_SUBSTR (x.col1 || ',', '([^,]*),|$', 1,
                                              1, NULL, 1),
                               'x' || CHR (10) || CHR (13),
                               'x') order_number,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   2, NULL, 1) CANEL_ENTIRE_ORDER_FLAG,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   3, NULL, 1) CANEL_UNSCH_LINES_FLAG,
                    TRANSLATE (REGEXP_SUBSTR (x.col1 || ',', '([^,]*),|$', 1,
                                              4, NULL, 1),
                               'x' || CHR (10) || CHR (13),
                               'x') RESEND_855_FLAG,
                    attribute1,
                    src.file_id,
                    src.file_name,
                    NULL status,
                    NULL erg_msg,
                    NULL oe_header_id,
                    NULL request_date,
                    NULL cancel_date,
                    NULL po_number,
                    NULL cancelled_flag,
                    NULL open_flag,
                    NULL line_num
               FROM xxdo.xxd_file_upload_t src, XMLTABLE ('/a/b' PASSING xmltype ('<a><b>' || REPLACE (xxd_common_utils.conv_to_clob (src.file_data), CHR (10), '</b><b>') || '</b></a>') COLUMNS col1 VARCHAR2 (2000) PATH '.') x
              WHERE     1 = 1
                    AND file_source = 'GSA'
                    AND file_id = p_file_id
                    AND REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                       1)
                            IS NOT NULL
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             'SALES%')
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             '%NUMBER'));

        TYPE xxd_insert_book_ord_typ IS TABLE OF cur_val%ROWTYPE;

        v_ins_type          xxd_insert_book_ord_typ
                                := xxd_insert_book_ord_typ ();
    BEGIN
        BEGIN
            x_file_id   := xxdo.xxd_ont_order_modify_batch_s.NEXTVAL;

            OPEN cur_val;

            LOOP
                FETCH cur_val BULK COLLECT INTO v_ins_type LIMIT 1000;

                IF (v_ins_type.COUNT > 0)
                THEN
                    FOR x IN v_ins_type.FIRST .. v_ins_type.LAST
                    LOOP
                        ln_line_num               := ln_line_num + 1;
                        v_ins_type (x).line_num   := ln_line_num;

                        IF UPPER (v_ins_type (x).CANEL_ENTIRE_ORDER_FLAG) NOT IN
                               ('Y', 'N')
                        THEN
                            v_ins_type (x).status   := 'E';
                            v_ins_type (x).erg_msg   :=
                                   v_ins_type (x).erg_msg
                                || ' .Cancel Entire Order Flag is not Valid';
                        END IF;

                        IF UPPER (v_ins_type (x).RESEND_855_FLAG) NOT IN
                               ('Y', 'N')
                        THEN
                            v_ins_type (x).status   := 'E';
                            v_ins_type (x).erg_msg   :=
                                   v_ins_type (x).erg_msg
                                || ' .Resend 855 Flag is not Valid';
                        END IF;

                        IF     UPPER (v_ins_type (x).CANEL_ENTIRE_ORDER_FLAG) IN
                                   ('N')
                           AND UPPER (v_ins_type (x).CANEL_UNSCH_LINES_FLAG) NOT IN
                                   ('Y', 'N')
                        THEN
                            v_ins_type (x).status   := 'E';
                            v_ins_type (x).erg_msg   :=
                                   v_ins_type (x).erg_msg
                                || ' .Cancel Unschedule Flag is not Valid';
                        END IF;


                        BEGIN
                            SELECT ooh.header_id, cust_po_number, request_date,
                                   attribute1, cancelled_flag, open_flag
                              INTO v_ins_type (x).oe_header_id, v_ins_type (x).po_number, v_ins_type (x).request_date, v_ins_type (x).cancel_date,
                                                              v_ins_type (x).cancelled_flag, v_ins_type (x).open_flag
                              FROM oe_order_headers_all ooh
                             WHERE ooh.order_number =
                                   v_ins_type (x).order_number;

                            IF ((v_ins_type (x).cancelled_flag = 'Y') AND (v_ins_type (x).CANEL_ENTIRE_ORDER_FLAG = 'Y' OR v_ins_type (x).CANEL_UNSCH_LINES_FLAG = 'Y'))
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                       v_ins_type (x).erg_msg
                                    || ' .Order is not eligibile for current operation';
                            END IF;

                            IF ((v_ins_type (x).open_flag = 'N') AND (v_ins_type (x).CANEL_ENTIRE_ORDER_FLAG = 'Y' OR v_ins_type (x).CANEL_UNSCH_LINES_FLAG = 'Y'))
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                       v_ins_type (x).erg_msg
                                    || ' .Order is not eligibile for current operation';
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                       v_ins_type (x).erg_msg
                                    || ' .Order is not eligibile for current operation';
                        END;
                    END LOOP;
                END IF;

                IF (v_ins_type.COUNT > 0 AND ln_line_num < 1001)
                THEN
                    BEGIN
                        FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO xxd_ont_order_modify_details_t (
                                            source_order_number,
                                            source_header_id,
                                            status,
                                            error_message,
                                            attribute2,
                                            GROUP_ID,
                                            org_id,
                                            operation_mode,
                                            source_cust_po_number,
                                            source_header_request_date,
                                            target_header_cancel_date,
                                            attribute3,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            attribute13,
                                            attribute14,
                                            attribute15,
                                            TARGET_CHANGE_REASON,
                                            TARGET_CHANGE_REASON_CODE,
                                            record_id -- Added as per CCR0010520
                                                     )
                                     VALUES (
                                                v_ins_type (i).order_number,
                                                v_ins_type (i).oe_header_id,
                                                NVL (v_ins_type (i).status,
                                                     'I'),
                                                v_ins_type (i).erg_msg,
                                                p_file_id,
                                                x_file_id,
                                                p_org_id,
                                                p_operation_mode,
                                                v_ins_type (i).po_number,
                                                v_ins_type (i).request_date,
                                                apps.fnd_date.canonical_to_date (
                                                    (v_ins_type (i).cancel_date)),
                                                v_ins_type (i).line_num,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                fnd_global.login_id,
                                                UPPER (
                                                    v_ins_type (i).CANEL_ENTIRE_ORDER_FLAG),
                                                UPPER (
                                                    v_ins_type (i).CANEL_UNSCH_LINES_FLAG),
                                                UPPER (
                                                    v_ins_type (i).RESEND_855_FLAG),
                                                'OM - Cancellation Decision by Deckers',
                                                'BLK_ADJ_MANUAL',
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
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg    :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Inserting into Table' || v_ins_type (ln_error_num).order_number || lv_error_code || ' #'),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                ELSE
                    lv_error_stat   := 'E';
                    lv_error_msg    :=
                        'Please upload less than 1000 records at a time.';
                END IF;

                EXIT WHEN cur_val%NOTFOUND;
            END LOOP;

            CLOSE cur_val;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                       lv_error_msg
                    || 'Error While Collect The Data  '
                    || SQLERRM;
        END;

        IF (lv_error_stat = 'E')
        THEN
            x_ret_status   := 'E';
            x_err_msg      :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            x_ret_status   := 'S';
            x_err_msg      :=
                   lv_error_msg
                || ' Successfully Records Inserted, Please Click on Submit To Cancel Order';

            -- delete any pending INserted reocrds of this user from old grup id
            DELETE FROM
                xxd_ont_order_modify_details_t
                  WHERE     status = 'I'
                        AND created_by = fnd_global.user_id
                        AND operation_mode = 'XXD_ONT_CANCEL'
                        AND GROUP_ID <> x_file_id;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := 'Error While Inserting to Table ' || SQLERRM;
            ROLLBACK;
    END process_cancel_order_file855;

    PROCEDURE xxd_ont_order_cancel_855 (p_ont_order_lines_tbl xxdo.xxd_ont_order_lines_tbl_type, p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_action IN VARCHAR2, p_group_id IN NUMBER, p_freeAtp_flag IN VARCHAR2, pv_error_stat OUT VARCHAR2
                                        , pv_error_msg OUT VARCHAR2)
    AS
        lv_error_msg             VARCHAR2 (4000) := NULL;
        lv_error_stat            VARCHAR2 (4) := 'S';
        lv_error_code            VARCHAR2 (4000) := NULL;
        ln_error_num             NUMBER;
        ln_operation_mode        VARCHAR2 (100);
        ln_group_id              NUMBER;
        ln_req_id                NUMBER;
        lc_status                VARCHAR2 (10);
        ln_record_count          NUMBER;
        ln_valid_count           NUMBER;
        lv_ret_status            VARCHAR2 (10);
        lv_err_msg               VARCHAR2 (4000);
        ln_line_num              NUMBER := 0;
        lv_date                  DATE := NULL;
        lv_open_flag             VARCHAR2 (10);
        ln_header_id             NUMBER := NULL;
        ln_ship_from_org_id      NUMBER := NULL;
        ln_inventory_item_id     NUMBER := NULL;
        ln_batch_id              NUMBER;
        lv_ont_order_lines_tbl   xxdo.xxd_ont_order_lines_tbl_type
                                     := xxdo.xxd_ont_order_lines_tbl_type ();
    BEGIN
        lv_ont_order_lines_tbl.DELETE;
        lv_ont_order_lines_tbl   := p_ont_order_lines_tbl;

        IF (lv_ont_order_lines_tbl.COUNT = 0)
        THEN
            lv_error_stat   := 'E';
            lv_error_msg    :=
                   lv_error_msg
                || 'Collection Data  counr '
                || lv_ont_order_lines_tbl.COUNT
                || '   ';
        END IF;

        IF (p_action = 'SUBMIT')
        THEN
            ln_batch_id   := xxdo.xxd_ont_order_modify_details_s.NEXTVAL;

            BEGIN
                FORALL i
                    IN lv_ont_order_lines_tbl.FIRST ..
                       lv_ont_order_lines_tbl.LAST
                  SAVE EXCEPTIONS
                    UPDATE xxd_ont_order_modify_details_t
                       SET target_change_reason = lv_ont_order_lines_tbl (i).target_change_reason, target_change_reason_code = lv_ont_order_lines_tbl (i).target_change_reason_code, batch_id = ln_batch_id,
                           Attribute12 = p_freeAtp_flag, STATUS = 'N'
                     WHERE     source_order_number =
                               lv_ont_order_lines_tbl (i).source_order_number
                           AND GROUP_ID = lv_ont_order_lines_tbl (i).GROUP_ID
                           AND STATUS <> 'E';

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';

                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        ln_error_num   := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                        lv_error_code   :=
                            SQLERRM (-1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                        lv_error_msg   :=
                            SUBSTR (
                                (lv_error_msg || ' Error While Insert into Table ' || lv_ont_order_lines_tbl (ln_error_num).source_order_number || lv_error_code),
                                1,
                                4000);
                    END LOOP;
            END;

            ln_req_id     :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXD_ONT_ORDER_BOOK_CANCEL_CHLD',
                    description   => NULL,
                    start_time    => NULL,
                    sub_request   => NULL,
                    argument1     => 'XXD_ONT_CANCEL',
                    argument2     => p_group_id,
                    argument3     => ln_batch_id,
                    argument4     => 'N',
                    argument5     => 'N',
                    argument6     => p_freeAtp_flag);

            IF ln_req_id > 0
            THEN
                UPDATE xxd_ont_order_modify_details_t
                   SET request_id   = ln_req_id
                 WHERE status = 'N' AND GROUP_ID = p_group_id;

                COMMIT;
            ELSE
                UPDATE xxd_ont_order_modify_details_t
                   SET status = 'E', error_message = 'Unable to submit concurrent program'
                 WHERE status = 'N' AND GROUP_ID = p_group_id;
            END IF;
        END IF;

        IF (p_action = 'DELETE')
        THEN
            BEGIN
                FORALL i
                    IN lv_ont_order_lines_tbl.FIRST ..
                       lv_ont_order_lines_tbl.LAST
                  SAVE EXCEPTIONS
                    DELETE xxd_ont_order_modify_details_t
                     WHERE     source_order_number =
                               lv_ont_order_lines_tbl (i).source_order_number
                           AND GROUP_ID = lv_ont_order_lines_tbl (i).GROUP_ID;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';

                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        ln_error_num   := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                        lv_error_code   :=
                            SQLERRM (-1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                        lv_error_msg   :=
                            SUBSTR (
                                (lv_error_msg || '  Error While Delete The Record Table ' || lv_ont_order_lines_tbl (ln_error_num).source_order_number || ' Line Number ' || lv_ont_order_lines_tbl (ln_error_num).source_line_number || lv_error_code),
                                1,
                                4000);
                    END LOOP;
            END;
        END IF;

        IF (lv_error_stat = 'E')
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            pv_error_stat   := 'S';

            IF (p_action = 'SUBMIT')
            THEN
                pv_error_msg   :=
                       lv_error_msg
                    || ' Successfully Records Inserted, Please Click on Submit To proceed. ';
            ELSE
                pv_error_msg   :=
                    lv_error_msg || ' Records Successfully deleted. ';
            END IF;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Error While Inserting to Table ' || SQLERRM;
            ROLLBACK;
    END xxd_ont_order_cancel_855;

    -- end 2.8

    --Start ver 2.8
    PROCEDURE cancel_order_prc855 (p_group_id IN NUMBER, p_batch_id IN NUMBER, p_freeAtp_flag IN VARCHAR2 -- ver 2.4
                                                                                                         )
    AS
        CURSOR get_orders_c IS
            SELECT DISTINCT source_order_number, source_header_id, org_id,
                            NVL (attribute13, 'N') cancel_entire_order, NVL (attribute14, 'N') cancel_unschuld_lines_only, attribute15 send855,
                            target_change_reason_code
              FROM xxd_ont_order_modify_details_t
             WHERE     NVL (status, 'N') = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;


        CURSOR get_unschd_lines_c (p_header_id NUMBER)
        IS
            SELECT *
              FROM oe_order_lines_all
             WHERE     open_flag = 'Y'
                   AND header_id = p_header_id
                   AND SCHEDULE_SHIP_DATE IS NULL;

        lc_sub_prog_name       VARCHAR2 (100) := 'CANCEL_ORDER_PRC855';
        lc_api_return_status   VARCHAR2 (1);
        lc_lock_status         VARCHAR2 (1);
        lc_error_message       VARCHAR2 (4000);
        ln_line_tbl_count      NUMBER := 0;
        l_header_rec           oe_order_pub.header_rec_type;
        lx_header_rec          oe_order_pub.header_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        lx_line_tbl            oe_order_pub.line_tbl_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
        l_line_tbl_index       NUMBER;
    BEGIN
        -- init ();
        FOR orders_rec IN get_orders_c
        LOOP
            mo_global.init ('ONT');
            mo_global.set_org_context (orders_rec.org_id, NULL, 'ONT');
            mo_global.set_policy_context ('S', orders_rec.org_id);
            l_line_tbl.delete;
            l_line_tbl_index         := 0;
            l_header_rec             := oe_order_pub.g_miss_header_rec;

            IF     orders_rec.cancel_entire_order = 'N'
               AND orders_rec.cancel_unschuld_lines_only = 'N'
            THEN
                --resend 855
                IF orders_rec.send855 = 'Y'
                THEN
                    --to add logic in below prc
                    debug_msg (
                        'Execute send855 for order header id: ' || orders_rec.source_header_id);
                    send855_prc (orders_rec.source_header_id,
                                 p_group_id,
                                 p_batch_id);
                END IF;

                debug_msg (
                    'Skip processing for order header id: ' || orders_rec.source_header_id);

                UPDATE xxd_ont_order_modify_details_t
                   SET status   = 'S'
                 WHERE     status = 'N'
                       AND batch_id = p_batch_id
                       AND GROUP_ID = p_group_id
                       AND source_header_id = orders_rec.source_header_id;

                COMMIT;
                CONTINUE;
            ELSIF     orders_rec.cancel_entire_order = 'N'
                  AND orders_rec.cancel_unschuld_lines_only = 'Y'
            THEN
                debug_msg (
                       'Process unscheduled lines for order header id: '
                    || orders_rec.source_header_id);


                FOR lines_rec
                    IN get_unschd_lines_c (orders_rec.source_header_id)
                LOOP
                    debug_msg (
                        'inside unschld line cancellation' || lines_rec.line_id);

                    l_line_tbl_index                                 := l_line_tbl_index + 1;
                    l_line_tbl (l_line_tbl_index)                    :=
                        oe_order_pub.g_miss_line_rec;


                    l_line_tbl (l_line_tbl_index).header_id          :=
                        lines_rec.header_id;
                    l_line_tbl (l_line_tbl_index).line_id            :=
                        lines_rec.line_id;
                    l_line_tbl (l_line_tbl_index).ordered_quantity   := 0;
                    l_line_tbl (l_line_tbl_index).cancelled_flag     := 'Y';
                    -- l_line_tbl (ln_line_tbl_count).org_id :=
                    --        lines_rec.org_id;
                    l_line_tbl (l_line_tbl_index).operation          :=
                        OE_GLOBALS.G_OPR_UPDATE;
                    l_line_tbl (l_line_tbl_index).change_reason      :=
                        orders_rec.target_change_reason_code;
                    l_line_tbl (l_line_tbl_index).change_comments    :=
                           'Order modified on '
                        || SYSDATE
                        || ' by program request_id: '
                        || gn_request_id;
                END LOOP;
            ELSE
                debug_msg (
                       'Process entire order cancel for order header id: '
                    || orders_rec.source_header_id);
                l_header_rec.cancelled_flag   := 'Y';
                l_header_rec.operation        := oe_globals.g_opr_update;

                l_header_rec.change_reason    :=
                    orders_rec.target_change_reason_code;
                l_header_rec.change_comments   :=
                       'Order modified on '
                    || SYSDATE
                    || ' by program request_id: '
                    || gn_request_id;
            END IF;


            lc_api_return_status     := NULL;
            lc_error_message         := NULL;
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            ln_line_tbl_count        := 0;
            debug_msg (RPAD ('=', 100, '='));
            debug_msg (
                   'Processing Order Number '
                || orders_rec.source_order_number
                || '. Header ID '
                || orders_rec.source_header_id);
            debug_msg (
                   'Start Time '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            -- l_line_tbl_index := l_line_tbl_index + 1;

            l_header_rec.operation   := oe_globals.g_opr_update;
            l_header_rec.header_id   := orders_rec.source_header_id;

            --l_header_rec.cancelled_flag := 'Y';

            IF p_freeAtp_flag = 'Y'
            THEN
                xxd_ont_bulk_calloff_pkg.gc_no_unconsumption   := 'Y';
            END IF;


            process_order (p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, p_action_request_tbl => l_action_request_tbl, x_header_rec => lx_header_rec, x_line_tbl => lx_line_tbl, x_return_status => lc_api_return_status
                           , x_error_message => lc_error_message);

            debug_msg ('Order Update Status = ' || lc_api_return_status);

            IF lc_api_return_status <> 'S'
            THEN
                debug_msg ('Order Update Error = ' || lc_error_message);
            ELSE
                debug_msg (
                    'Target Order Header ID ' || lx_header_rec.header_id);

                --execute send855_prc
                IF orders_rec.send855 = 'Y'
                THEN
                    --to add logic in below prc
                    debug_msg (
                        'Execute send855 for order header id: ' || orders_rec.source_header_id);
                    send855_prc (orders_rec.source_header_id,
                                 p_group_id,
                                 p_batch_id);
                END IF;
            END IF;


            UPDATE xxd_ont_order_modify_details_t
               SET target_header_id   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.header_id,
                               target_header_id),
                   target_order_number   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.order_number,
                               target_order_number),
                   target_order_type_id   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.order_type_id,
                               target_order_type_id),
                   target_order_type   =
                       DECODE (
                           lc_api_return_status,
                           'S', (SELECT name
                                   FROM oe_transaction_types_tl
                                  WHERE     language = USERENV ('LANG')
                                        AND transaction_type_id =
                                            lx_header_rec.order_type_id),
                           target_order_type),
                   target_sold_to_org_id   =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.sold_to_org_id,
                               target_sold_to_org_id),
                   target_customer_number   =
                       DECODE (
                           lc_api_return_status,
                           'S', (SELECT account_number
                                   FROM hz_cust_accounts
                                  WHERE cust_account_id =
                                        lx_header_rec.sold_to_org_id),
                           target_customer_number),
                   target_line_id      = source_line_id,
                   target_schedule_ship_date   =
                       (SELECT TRUNC (schedule_ship_date)
                          FROM oe_order_lines_all
                         WHERE line_id = source_line_id),
                   status             =
                       DECODE (lc_api_return_status,
                               'U', 'E',
                               lc_api_return_status),
                   error_message       = SUBSTR (lc_error_message, 1, 2000),
                   request_id          = gn_request_id,
                   last_update_date    = SYSDATE,
                   last_update_login   = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND source_header_id = orders_rec.source_header_id;

            debug_msg (
                'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg (
                   'Updated Status in Custom Table Record Count = '
                || SQL%ROWCOUNT);
            debug_msg (RPAD ('=', 100, '='));
            COMMIT;
        END LOOP;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in cancel_order_prc855: Error location = '
                || DBMS_UTILITY.format_error_backtrace);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in cancel_order_prc855: Error = '
                || lc_error_message);
            COMMIT;
    END cancel_order_prc855;

    PROCEDURE send855_prc (p_order_header_id   NUMBER,
                           p_group_id          NUMBER,
                           p_batch_id          NUMBER)
    IS
        lc_sub_prog_name    VARCHAR2 (100) := 'SEND855_PRC';
        lv_order_number     oe_order_headers_all.order_number%TYPE := NULL;
        lv_cust_po_number   oe_order_headers_all.cust_po_number%TYPE := NULL;
        lv_account_number   hz_cust_accounts.account_number%TYPE := NULL;
        lv_party_name       hz_parties.party_name%TYPE := NULL;
    BEGIN
        debug_msg ('Start: ' || lc_sub_prog_name);

        SELECT ooha.order_number, ooha.cust_po_number, hca.account_number,
               hp.party_name
          INTO lv_order_number, lv_cust_po_number, lv_account_number, lv_party_name
          FROM apps.oe_order_headers_all ooha, apps.hz_cust_accounts hca, apps.hz_parties hp
         WHERE     ooha.header_id = p_order_header_id
               AND ooha.sold_to_org_id = hca.cust_account_id
               AND hp.party_id = hca.party_id
               /*  AND NOT EXISTS
                   ((SELECT 'Y'
                       FROM fnd_lookup_values_vl
                      WHERE     lookup_type = 'XXD_ONT_EDI_855_EXCLUSION'
                            AND enabled_flag = 'Y'
                            AND NVL (attribute2, hca.cust_account_id) =
                                hca.cust_account_id
                            AND ooha.order_type_id = attribute3)
                                                               ) */
               AND EXISTS
                       (SELECT 1
                          FROM fnd_lookup_values flv
                         WHERE     1 = 1
                               AND lookup_type = 'XXD_EDI_855_CUSTOMERS'
                               AND enabled_flag = 'Y'
                               AND language = USERENV ('LANG')
                               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                               NVL (
                                                                   start_date_active,
                                                                   SYSDATE))
                                                       AND TRUNC (
                                                               NVL (
                                                                   end_date_active,
                                                                   SYSDATE))
                               AND UPPER (hp.party_name) =
                                   UPPER (TRIM (flv.meaning)));

        write_to_855_table (p_order_number => lv_order_number, p_customer_po_number => lv_cust_po_number, p_acct_num => lv_account_number
                            , p_party_name => lv_party_name);

        debug_msg ('END: ' || lc_sub_prog_name);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            UPDATE xxd_ont_order_modify_details_t
               SET error_message = SUBSTR (error_message || ';' || 'The customer is not part of EDI 855 lookup', 1, 2000)
             WHERE     batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND source_header_id = p_order_header_id;

            COMMIT;
        WHEN OTHERS
        THEN
            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in send855_prc: Error location = '
                || DBMS_UTILITY.format_error_backtrace);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in send855_prc: Error = ' || SQLERRM);
    END;

    FUNCTION check_sps_customer (p_customer_number IN VARCHAR2)
        RETURN VARCHAR2                             --Start W.r.t Version 15.0
    IS
        lv_sps_customer   VARCHAR2 (10) := NULL;
    BEGIN
        BEGIN
            SELECT NVL (flv.attribute1, 'N')
              INTO lv_sps_customer
              FROM fnd_lookup_values flv
             WHERE     1 = 1
                   AND flv.lookup_type = 'XXDO_EDI_CUSTOMERS'
                   AND flv.language = 'US'
                   AND NVL (flv.enabled_flag, 'N') = 'Y'
                   AND NVL (TRUNC (flv.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (flv.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND p_customer_number = flv.lookup_code;

            fnd_file.put_line (
                fnd_file.LOG,
                   'The customer service is:'
                || lv_sps_customer
                || '-'
                || 'for customer');
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_sps_customer   := NULL;
        END;

        RETURN lv_sps_customer;
    END check_sps_customer;

    PROCEDURE write_to_855_table (p_order_number NUMBER, p_customer_po_number VARCHAR2, p_acct_num VARCHAR2
                                  , p_party_name VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lv_sps_customer   VARCHAR2 (10) := NULL;
        l_count_sps       NUMBER;
        l_count           NUMBER;
    BEGIN
        lv_sps_customer   := check_sps_customer (p_acct_num); --W.r.t Version 15.0

        -- check if already existing unprocessed record
        SELECT COUNT (1)
          INTO l_count
          FROM xxdo.xxd_edi_855_order_process
         WHERE     order_number = p_order_number
               AND NVL (process_status, 'N') = 'N';


        SELECT COUNT (1)
          INTO l_count_sps
          FROM xxdo.xxd_edi_855_sps_order_process
         WHERE     order_number = p_order_number
               AND NVL (process_status, 'N') = 'N';


        IF lv_sps_customer = 'N' AND l_count = 0
        THEN
            INSERT INTO xxdo.xxd_edi_855_order_process (order_number,
                                                        cust_po_number,
                                                        account_number,
                                                        customer_name,
                                                        process_status,
                                                        bulk_order_flag,
                                                        creation_date,
                                                        last_update_date)
                 VALUES (p_order_number, p_customer_po_number, p_acct_num,
                         p_party_name, NULL, NULL,
                         SYSDATE, SYSDATE);
        ELSIF lv_sps_customer = 'Y' AND l_count_sps = 0
        THEN
            INSERT INTO xxdo.xxd_edi_855_sps_order_process (order_number,
                                                            cust_po_number,
                                                            account_number,
                                                            customer_name,
                                                            process_status,
                                                            bulk_order_flag,
                                                            creation_date,
                                                            last_update_date)
                 VALUES (p_order_number, p_customer_po_number, p_acct_num,
                         p_party_name, NULL, NULL,
                         SYSDATE, SYSDATE);
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END;

    --End ver 2.8


    -- Begin 1.17  CCR0010163 (Update Cust PO Number)

    -- ============================================================================================
    -- This procedure called from OA to Load the 'Update Orders Cust PO Number' Data from CSV file
    -- ============================================================================================

    PROCEDURE process_update_headers_file (p_file_id IN NUMBER, p_org_id IN NUMBER, p_operation_mode IN VARCHAR2
                                           , x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, x_file_id OUT NOCOPY VARCHAR2)
    AS
        lv_error_msg        VARCHAR2 (4000) := NULL;
        lv_error_stat       VARCHAR2 (4) := 'S';
        lv_error_code       VARCHAR2 (4000) := NULL;
        ln_error_num        NUMBER;
        ln_operation_mode   VARCHAR2 (100);
        ln_group_id         NUMBER;
        ln_req_id           NUMBER;
        lc_status           VARCHAR2 (10);
        ln_record_count     NUMBER;
        ln_valid_count      NUMBER;
        ln_line_num         NUMBER := 0;
        lv_open_flag        VARCHAR2 (10);
        lv_cancel_flag      VARCHAR2 (10);
        lv_count            NUMBER := 0;

        CURSOR cur_val IS
            (SELECT TRANSLATE (REGEXP_SUBSTR (x.col1 || ',', '([^,]*),|$', 1,
                                              1, NULL, 1),
                               'x' || CHR (10) || CHR (13),
                               'x') order_number,
                    NVL (
                        REGEXP_SUBSTR (REGEXP_SUBSTR (x.col1, '\"(.*)\"', 1),
                                       '[^\"].*[^\"]'),
                        TRANSLATE (REGEXP_SUBSTR (x.col1 || ',', '([^,]*),|$', 1
                                                  , 2, NULL, 1),
                                   'x' || CHR (10) || CHR (13),
                                   'x')) new_customer_po_number,
                    /* TRANSLATE (REGEXP_SUBSTR (x.col1 || ',',
                                                  '([^,]*),|$',
                                                  1,
                                                  2,
                                                  NULL,
                                                  1),
                                   'x' || CHR (10) || CHR (13),
                                   'x')  new_customer_po_number,
                       NVL (
                            REGEXP_SUBSTR (REGEXP_SUBSTR (x.col1, '\"(.*)\"', 1),
                                           '[^\"].*[^\"]'),
                            REGEXP_SUBSTR (x.col1,
                                           '[^,]+',
                                           1,
                                           2))    new_customer_po_number,  */
                    attribute1,
                    src.file_id,
                    src.file_name,
                    NULL status,
                    NULL erg_msg,
                    NULL oe_header_id,
                    NULL request_date,
                    NULL cancel_date,
                    NULL cancelled_flag,
                    NULL open_flag,
                    NULL line_num
               FROM xxdo.xxd_file_upload_t src, XMLTABLE ('/a/b' PASSING xmltype ('<a><b>' --- || REPLACE (TRANSLATE (xxd_common_utils.conv_to_clob (src.file_data),'&<>','  '),CHR (10),'</b><b>')
                                                                                           || REPLACE (xxd_common_utils.conv_to_clob (src.file_data), CHR (10), '</b><b>') || '</b></a>') COLUMNS col1 VARCHAR2 (2000) PATH '.') x
              WHERE     1 = 1
                    AND file_source = 'GSA'
                    AND file_id = p_file_id
                    AND REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                       1)
                            IS NOT NULL
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             'SALES%')
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             '%NUMBER'));

        TYPE xxd_update_orders_typ IS TABLE OF cur_val%ROWTYPE;

        v_ins_type          xxd_update_orders_typ := xxd_update_orders_typ ();
    BEGIN
        BEGIN
            x_file_id   := xxdo.xxd_ont_order_modify_batch_s.NEXTVAL;

            OPEN cur_val;

            LOOP
                FETCH cur_val BULK COLLECT INTO v_ins_type LIMIT 1000;

                IF (v_ins_type.COUNT > 0)
                THEN
                    FOR x IN v_ins_type.FIRST .. v_ins_type.LAST
                    LOOP
                        ln_line_num               := ln_line_num + 1;
                        v_ins_type (x).line_num   := ln_line_num;
                    END LOOP;
                END IF;

                IF (v_ins_type.COUNT > 0 AND ln_line_num < 1001)
                THEN
                    BEGIN
                        FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO xxd_ont_order_modify_details_t (
                                            source_order_number,
                                            source_header_id,
                                            status,
                                            error_message,
                                            attribute2,
                                            GROUP_ID,
                                            org_id,
                                            operation_mode,
                                            source_cust_po_number,
                                            source_header_request_date,
                                            target_header_cancel_date,
                                            attribute3,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            last_update_login,
                                            record_id -- Added as per CCR0010520
                                                     --TARGET_CHANGE_REASON,
                                                     --TARGET_CHANGE_REASON_CODE
                                                     )
                                     VALUES (
                                                v_ins_type (i).order_number,
                                                v_ins_type (i).oe_header_id,
                                                NVL (v_ins_type (i).status,
                                                     'I'),
                                                v_ins_type (i).erg_msg,
                                                p_file_id,
                                                x_file_id,
                                                p_org_id,
                                                p_operation_mode,
                                                v_ins_type (i).new_customer_po_number,
                                                v_ins_type (i).request_date,
                                                apps.fnd_date.canonical_to_date (
                                                    (v_ins_type (i).cancel_date)),
                                                v_ins_type (i).line_num,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                SYSDATE,
                                                fnd_global.user_id,
                                                fnd_global.login_id,
                                                xxdo.XXD_ONT_ORDER_MODIFY_DETAILS_REC_S.NEXTVAL -- Added as per CCR0010520
                                                                                               --'OM - Order PO Number Update Decision by Deckers',
                                                                                               --'BLK_ADJ_MANUAL_CUST_PO_NUM'
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
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg    :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Inserting into Table' || v_ins_type (ln_error_num).order_number || lv_error_code || ' #'),
                                        1,
                                        4000);
                            END LOOP;
                    END;
                ELSE
                    lv_error_stat   := 'E';
                    lv_error_msg    :=
                        'Please upload less than 1000 records at a time.';
                END IF;

                EXIT WHEN cur_val%NOTFOUND;
            END LOOP;

            CLOSE cur_val;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_stat   := 'E';
                lv_error_msg    :=
                       lv_error_msg
                    || 'Error While Collect The Data  '
                    || SQLERRM;
        END;

        IF (lv_error_stat = 'E')
        THEN
            x_ret_status   := 'E';
            x_err_msg      :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            x_ret_status   := 'S';
            x_err_msg      :=
                   lv_error_msg
                || ' Successfully Records Inserted, Please Click on Submit To Update Orders Headers';

            -- delete any pending INserted reocrds of this user from old grup id
            DELETE FROM
                xxd_ont_order_modify_details_t
                  WHERE     status = 'I'
                        AND created_by = fnd_global.user_id
                        AND operation_mode = 'XXD_ONT_UPDATE_HEADER'
                        AND GROUP_ID <> x_file_id;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   := 'E';
            x_err_msg      := 'Error While Inserting to Table ' || SQLERRM;
            ROLLBACK;
    END process_update_headers_file;

    -- ===============================================================================================
    -- This procedure used by OAF Page and calls the concurrent program as per the Action provided
    -- ===============================================================================================

    PROCEDURE xxd_ont_update_headers_cust_po_num (p_ont_update_order_tbl xxdo.xxd_ont_order_lines_tbl_type, p_org_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_action IN VARCHAR2
                                                  , p_group_id IN NUMBER, pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2)
    AS
        lv_error_msg              VARCHAR2 (4000) := NULL;
        lv_error_stat             VARCHAR2 (4) := 'S';
        lv_error_code             VARCHAR2 (4000) := NULL;
        ln_error_num              NUMBER;
        ln_operation_mode         VARCHAR2 (100);
        ln_group_id               NUMBER;
        ln_req_id                 NUMBER;
        lc_status                 VARCHAR2 (10);
        ln_record_count           NUMBER;
        ln_valid_count            NUMBER;
        lv_ret_status             VARCHAR2 (10);
        lv_err_msg                VARCHAR2 (4000);
        ln_line_num               NUMBER := 0;
        lv_date                   DATE := NULL;
        lv_open_flag              VARCHAR2 (10);
        ln_header_id              NUMBER := NULL;
        ln_ship_from_org_id       NUMBER := NULL;
        ln_inventory_item_id      NUMBER := NULL;
        ln_batch_id               NUMBER;
        lv_ont_update_order_tbl   xxdo.xxd_ont_order_lines_tbl_type
                                      := xxdo.xxd_ont_order_lines_tbl_type ();
    BEGIN
        lv_ont_update_order_tbl.DELETE;
        lv_ont_update_order_tbl   := p_ont_update_order_tbl;

        IF (lv_ont_update_order_tbl.COUNT = 0)
        THEN
            lv_error_stat   := 'E';
            lv_error_msg    :=
                   lv_error_msg
                || 'Collection Data count is Zero'
                || lv_ont_update_order_tbl.COUNT
                || '   ';
        END IF;

        IF (p_action = 'SUBMIT')
        THEN
            ln_batch_id   := xxdo.xxd_ont_order_modify_details_s.NEXTVAL;

            /*   DBMS_OUTPUT.PUT_LINE (
                      'Order Number: '
                   || lv_ont_update_order_tbl (1).source_order_number); --- testing

               DBMS_OUTPUT.PUT_LINE (
                   'Group ID: ' || lv_ont_update_order_tbl (1).GROUP_ID); --- testing
               DBMS_OUTPUT.PUT_LINE (
                   'Status: ' || lv_ont_update_order_tbl (1).STATUS); --- testing
     */
            BEGIN
                FORALL i
                    IN lv_ont_update_order_tbl.FIRST ..
                       lv_ont_update_order_tbl.LAST
                  SAVE EXCEPTIONS
                    UPDATE xxd_ont_order_modify_details_t
                       SET batch_id = ln_batch_id, STATUS = 'N'
                     WHERE     source_order_number =
                               lv_ont_update_order_tbl (i).source_order_number
                           AND GROUP_ID =
                               lv_ont_update_order_tbl (i).GROUP_ID
                           AND STATUS <> 'E';

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';

                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        ln_error_num   := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                        lv_error_code   :=
                            SQLERRM (-1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                        lv_error_msg   :=
                            SUBSTR (
                                (lv_error_msg || ' Error While Updating into Table ' || lv_ont_update_order_tbl (ln_error_num).source_order_number || lv_error_code),
                                1,
                                4000);
                    END LOOP;
            END;

            --    dbms_output.put_line('before submit request' || ln_req_id);

            ln_req_id     :=
                fnd_request.submit_request (application => 'XXDO', program => 'XXD_ONT_ORDER_BOOK_CANCEL_CHLD', description => NULL, start_time => NULL, sub_request => NULL, argument1 => 'XXD_ONT_UPDATE_HEADER', argument2 => p_group_id, -- argument2     => 49971,
                                                                                                                                                                                                                                             argument3 => ln_batch_id, argument4 => 'N'
                                            , argument5 => 'N');

            --   argument6     => NULL);

            ---    dbms_output.put_line('after submit request' || ln_req_id);
            IF ln_req_id > 0
            THEN
                UPDATE xxd_ont_order_modify_details_t
                   SET request_id   = ln_req_id
                 WHERE status = 'N' AND GROUP_ID = p_group_id;

                COMMIT;
            ELSE
                UPDATE xxd_ont_order_modify_details_t
                   SET status = 'E', error_message = 'Unable to submit concurrent program'
                 WHERE status = 'N' AND GROUP_ID = p_group_id;
            END IF;
        END IF;

        IF (p_action = 'DELETE')
        THEN
            BEGIN
                FORALL i
                    IN lv_ont_update_order_tbl.FIRST ..
                       lv_ont_update_order_tbl.LAST
                  SAVE EXCEPTIONS
                    DELETE xxd_ont_order_modify_details_t
                     WHERE     source_order_number =
                               lv_ont_update_order_tbl (i).source_order_number
                           AND GROUP_ID =
                               lv_ont_update_order_tbl (i).GROUP_ID;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';

                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        ln_error_num   := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                        lv_error_code   :=
                            SQLERRM (-1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                        lv_error_msg   :=
                            SUBSTR (
                                (lv_error_msg || '  Error While Delete The Record Table ' || lv_ont_update_order_tbl (ln_error_num).source_order_number || ' Line Number ' || lv_ont_update_order_tbl (ln_error_num).source_line_number || lv_error_code),
                                1,
                                4000);
                    END LOOP;
            END;
        END IF;

        IF (lv_error_stat = 'E')
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            pv_error_stat   := 'S';

            IF (p_action = 'SUBMIT')
            THEN
                pv_error_msg   :=
                       lv_error_msg
                    || ' Successfully Records Inserted, Please Click on Submit To proceed. ';
            ELSE
                pv_error_msg   :=
                    lv_error_msg || ' Records Successfully deleted. ';
            END IF;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Error While Inserting to Table ' || SQLERRM;
            ROLLBACK;
    END xxd_ont_update_headers_cust_po_num;

    -- ======================================================================================
    -- This procedure validates the data for update orders action
    -- ======================================================================================

    PROCEDURE validate_update_headers_prc (p_group_id   IN NUMBER,
                                           p_batch_id   IN NUMBER)
    AS
        CURSOR cur_val IS
            SELECT a.ROWID rwid, source_order_number order_number, source_cust_po_number cust_po_number,
                   NULL status, NULL erg_msg, NULL oe_header_id,
                   NULL inventory_item_id, NULL org_id, NULL line_id,
                   NULL line_num
              FROM xxd_ont_order_modify_details_t a
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

        ln_line_num      NUMBER := 0;
        lv_date          DATE := NULL;
        lv_open_flag     VARCHAR2 (10);
        lv_cancel_flag   VARCHAR2 (10);
        lv_count         NUMBER := 0;


        TYPE xxd_insert_book_ord_typ IS TABLE OF cur_val%ROWTYPE;

        v_ins_type       xxd_insert_book_ord_typ
                             := xxd_insert_book_ord_typ ();
    BEGIN
        v_ins_type.DELETE;


        OPEN cur_val;

        LOOP
            FETCH cur_val BULK COLLECT INTO v_ins_type LIMIT 1000;


            IF (v_ins_type.COUNT > 0)
            THEN
                FOR x IN v_ins_type.FIRST .. v_ins_type.LAST
                LOOP
                    BEGIN
                        IF (v_ins_type (x).order_number IS NULL)
                        THEN
                            v_ins_type (x).status   := 'E';
                            v_ins_type (x).erg_msg   :=
                                   v_ins_type (x).erg_msg
                                || ' The Order number is invalid '
                                || ' ; ';
                        ELSE
                            BEGIN
                                SELECT ooh.header_id, ooh.org_id, ooh.open_flag,
                                       ooh.cancelled_flag
                                  INTO v_ins_type (x).oe_header_id, v_ins_type (x).org_id, lv_open_flag, lv_cancel_flag
                                  FROM oe_order_headers_all ooh
                                 WHERE ooh.order_number =
                                       v_ins_type (x).order_number;


                                IF (lv_open_flag <> 'Y' OR lv_cancel_flag <> 'N')
                                THEN
                                    v_ins_type (x).status   := 'E';
                                    v_ins_type (x).erg_msg   :=
                                           v_ins_type (x).erg_msg
                                        || ' The Order: '
                                        || v_ins_type (x).order_number
                                        || ' is in closed/cancelled status '
                                        || ' ; ';
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    v_ins_type (x).status   := 'E';
                                    v_ins_type (x).erg_msg   :=
                                           v_ins_type (x).erg_msg
                                        || '  There is no such order: '
                                        || v_ins_type (x).order_number
                                        || ' in OU '
                                        || v_ins_type (x).org_id
                                        || ' ; ';
                            END;
                        END IF;

                        IF (v_ins_type (x).cust_po_number IS NULL)
                        THEN
                            v_ins_type (x).status   := 'E';
                            v_ins_type (x).erg_msg   :=
                                   v_ins_type (x).erg_msg
                                || ' New Customer PO Number can?t be null or greater than 50 bytes '
                                || ' ; ';
                        ELSIF (LENGTH (v_ins_type (x).cust_po_number) > 50)
                        THEN
                            v_ins_type (x).status   := 'E';
                            v_ins_type (x).erg_msg   :=
                                   v_ins_type (x).erg_msg
                                || ' New Customer PO Number can?t be null or greater than 50 bytes '
                                || ' ; ';
                        END IF;

                        BEGIN
                            SELECT COUNT (*)
                              INTO lv_count
                              FROM xxd_ont_order_modify_details_t
                             WHERE     batch_id = p_batch_id
                                   AND SOURCE_ORDER_NUMBER =
                                       v_ins_type (x).order_number;

                            IF (lv_count > 1)
                            THEN
                                v_ins_type (x).status   := 'E';
                                v_ins_type (x).erg_msg   :=
                                       v_ins_type (x).erg_msg
                                    || ' Multiple Customer PO Numbers are entered for single Order '
                                    || ' ; ';
                            END IF;
                        END;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            v_ins_type (x).status   := 'E';
                            v_ins_type (x).erg_msg   :=
                                'Order Number Invalid ' || SQLERRM;
                    END;
                END LOOP;
            END IF;


            IF (v_ins_type.COUNT > 0)
            THEN
                FORALL i IN v_ins_type.FIRST .. v_ins_type.LAST
                    UPDATE xxd_ont_order_modify_details_t
                       SET status = NVL (v_ins_type (i).status, 'N'), error_message = v_ins_type (i).erg_msg, source_header_id = v_ins_type (i).oe_header_id
                     WHERE     1 = 1
                           AND batch_id = p_batch_id
                           AND GROUP_ID = p_group_id
                           AND ROWID = v_ins_type (i).rwid;

                COMMIT;
            END IF;

            EXIT WHEN cur_val%NOTFOUND;
        END LOOP;

        CLOSE cur_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
    END validate_update_headers_prc;

    -- ======================================================================================
    -- This procedure calls the API and updates the Sales Order for Customer PO number
    -- ======================================================================================

    PROCEDURE update_headers_cust_po_prc (p_group_id   IN NUMBER,
                                          p_batch_id   IN NUMBER)
    AS
        CURSOR get_orders_c IS
            SELECT DISTINCT source_order_number, source_header_id, org_id,
                            source_cust_po_number
              FROM xxd_ont_order_modify_details_t
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

        CURSOR get_order_lines_c (p_header_id NUMBER)
        IS
            SELECT *
              FROM oe_order_lines_all
             WHERE open_flag = 'Y' AND header_id = p_header_id;



        lc_sub_prog_name       VARCHAR2 (100) := 'XXD_ONT_UPDATE_HEADER';
        lc_api_return_status   VARCHAR2 (1);
        lc_error_message       VARCHAR2 (4000);
        ln_line_tbl_count      NUMBER := 0;
        l_header_rec           oe_order_pub.header_rec_type;
        lx_header_rec          oe_order_pub.header_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        lx_line_tbl            oe_order_pub.line_tbl_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
        ln_cust_account_id     NUMBER;
        ln_ship_to_org_id      NUMBER;
        lv_color               VARCHAR2 (1000);
        lv_style               VARCHAR2 (1000);
        ln_ship_from_org_id    NUMBER;
        l_line_tbl_index       NUMBER;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        FOR orders_rec IN get_orders_c
        LOOP
            mo_global.init ('ONT');
            mo_global.set_org_context (orders_rec.org_id, NULL, 'ONT');
            mo_global.set_policy_context ('S', orders_rec.org_id);
            l_line_tbl.delete;
            l_line_tbl_index              := 0;

            ---  l_header_rec := oe_order_pub.g_miss_header_rec;

            FOR lines_rec IN get_order_lines_c (orders_rec.source_header_id)
            LOOP
                debug_msg (
                    'inside Update customer po number' || lines_rec.line_id);

                l_line_tbl_index   := l_line_tbl_index + 1;
                l_line_tbl (l_line_tbl_index)   :=
                    oe_order_pub.g_miss_line_rec;
                ---  cust_po_number

                l_line_tbl (l_line_tbl_index).header_id   :=
                    lines_rec.header_id;
                l_line_tbl (l_line_tbl_index).line_id   :=
                    lines_rec.line_id;
                l_line_tbl (l_line_tbl_index).cust_po_number   :=
                    orders_rec.source_cust_po_number;
                -- l_line_tbl (l_line_tbl_index).cancelled_flag := 'Y';
                -- l_line_tbl (ln_line_tbl_count).org_id :=
                --        lines_rec.org_id;
                l_line_tbl (l_line_tbl_index).operation   :=
                    OE_GLOBALS.G_OPR_UPDATE;

                l_line_tbl (l_line_tbl_index).change_comments   :=
                       'Order modified on '
                    || SYSDATE
                    || ' by program request_id: '
                    || gn_request_id;
            END LOOP;

            lc_api_return_status          := NULL;
            lc_error_message              := NULL;
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            ln_line_tbl_count             := 0;
            debug_msg (RPAD ('=', 100, '='));
            debug_msg (
                   'Processing Order Number '
                || orders_rec.source_order_number
                || '. Header ID '
                || orders_rec.source_header_id);
            debug_msg (
                   'Start Time '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

            l_header_rec                  := oe_order_pub.g_miss_header_rec;
            --   l_line_tbl := oe_order_pub.g_miss_line_tbl;    ---testing
            -- l_line_tbl (1) := oe_order_pub.g_miss_line_rec;         ---testing
            -- Header
            l_header_rec.header_id        := orders_rec.source_header_id;
            ---  l_header_rec.org_id := orders_rec.org_id;    ---testing
            l_header_rec.cust_po_number   := orders_rec.source_cust_po_number;
            l_header_rec.operation        := oe_globals.g_opr_update;
            ---   l_action_request_tbl (1) := oe_order_pub.g_miss_request_rec; ---testing


            process_order (p_header_rec => l_header_rec, p_line_tbl => l_line_tbl, p_action_request_tbl => l_action_request_tbl, x_header_rec => lx_header_rec, x_line_tbl => lx_line_tbl, x_return_status => lc_api_return_status
                           , x_error_message => lc_error_message);

            debug_msg ('Order Update Status = ' || lc_api_return_status);

            IF lc_api_return_status <> 'S'
            THEN
                debug_msg ('Order Update Error = ' || lc_error_message);
            ELSE
                debug_msg (
                    'Target Order Header ID ' || lx_header_rec.header_id);
            END IF;

            UPDATE xxd_ont_order_modify_details_t
               SET /* target_header_id =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.header_id,
                               target_header_id),
                   target_order_number =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.order_number,
                               target_order_number),
       target_cust_po_num =
      DECODE (lc_api_return_status,
                               'S', lx_header_rec.cust_po_number,
                               target_cust_po_num),
                   target_order_type_id =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.order_type_id,
                               target_order_type_id),
                   target_order_type =
                       DECODE (
                           lc_api_return_status,
                           'S', (SELECT name
                                   FROM oe_transaction_types_tl
                                  WHERE     language = USERENV ('LANG')
                                        AND transaction_type_id =
                                            lx_header_rec.order_type_id),
                           target_order_type),
                   target_sold_to_org_id =
                       DECODE (lc_api_return_status,
                               'S', lx_header_rec.sold_to_org_id,
                               target_sold_to_org_id),
                   target_customer_number =
                       DECODE (
                           lc_api_return_status,
                           'S', (SELECT account_number
                                   FROM hz_cust_accounts
                                  WHERE cust_account_id =
                                        lx_header_rec.sold_to_org_id),
                           target_customer_number),
                   target_line_id = source_line_id,
                   target_schedule_ship_date =
                       (SELECT TRUNC (schedule_ship_date)
                          FROM oe_order_lines_all
                         WHERE line_id = source_line_id),  */
                   status = lc_api_return_status, error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id
                   AND source_header_id = orders_rec.source_header_id;

            debug_msg (
                'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg (
                   'Updated Status in Custom Table Record Count = '
                || SQL%ROWCOUNT);
            debug_msg (RPAD ('=', 100, '='));
            COMMIT;
        END LOOP;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_order_modify_details_t
               SET status = 'E', error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     status = 'N'
                   AND batch_id = p_batch_id
                   AND GROUP_ID = p_group_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in update_headers_cust_po_prc = '
                || lc_error_message);
            COMMIT;
    END update_headers_cust_po_prc;


    PROCEDURE xxd_ont_update_header_delete (
        p_ont_order_lines_tbl          xxdo.xxd_ont_order_lines_tbl_type,
        p_org_id                IN     NUMBER,
        p_resp_id               IN     NUMBER,
        p_resp_app_id           IN     NUMBER,
        p_user_id               IN     NUMBER,
        p_operation_mode        IN     VARCHAR2,
        pv_error_stat              OUT VARCHAR2,
        pv_error_msg               OUT VARCHAR2)
    AS
        lv_error_msg    VARCHAR2 (4000) := NULL;
        lv_error_stat   VARCHAR2 (4) := 'S';
        lv_error_code   VARCHAR2 (4000) := NULL;
        ln_error_num    NUMBER;
    BEGIN
        IF (p_ont_order_lines_tbl.COUNT > 0)
        THEN
            BEGIN
                FORALL i
                    IN p_ont_order_lines_tbl.FIRST ..
                       p_ont_order_lines_tbl.LAST
                  SAVE EXCEPTIONS
                    DELETE xxd_ont_order_modify_details_t
                     WHERE     source_order_number =
                               p_ont_order_lines_tbl (i).source_order_number
                           AND GROUP_ID = p_ont_order_lines_tbl (i).GROUP_ID
                           AND operation_mode = p_operation_mode;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_stat   := 'E';

                    FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        ln_error_num   := SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                        lv_error_code   :=
                            SQLERRM (-1 * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                        lv_error_msg   :=
                            SUBSTR (
                                (lv_error_msg || '  Error While Delete The Record Table ' || p_ont_order_lines_tbl (ln_error_num).source_order_number || lv_error_code),
                                1,
                                4000);
                    END LOOP;
            END;
        END IF;

        IF (lv_error_stat = 'E')
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                SUBSTR (lv_error_msg, 0, LENGTH (lv_error_msg) - 1);
            ROLLBACK;
        ELSE
            pv_error_stat   := 'S';
            pv_error_msg    :=
                   lv_error_msg
                || ' Successfully Records Deleted, Please Click on Submit To Update Button ';
            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                'Error While Deleting Order Number ' || SQLERRM;
            ROLLBACK;
    END xxd_ont_update_header_delete;
-- End 1.17  CCR0010163 (Update Cust PO Number)

END xxd_ont_order_modify_pkg;
/
