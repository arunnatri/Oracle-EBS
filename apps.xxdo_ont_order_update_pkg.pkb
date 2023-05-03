--
-- XXDO_ONT_ORDER_UPDATE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ONT_ORDER_UPDATE_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ont_order_update.sql   1.0    2014/07/31   10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ont_order_update_pkg
    --
    -- Description  :  This is package  for WMS to OM Order Update Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 31-Jul-14    Infosys            1.0       Created
    --03-Feb-14   Infosys             1.1    Added Archive Logic PURGE_ARCHIVE
    --26-Mar-15   Infosys            1.2    Added code for OU_BUG Issue
    --20-May-15   Infosys            1.3   Commit added after each move order line transaction;
    --                                                  Identified by COMMIT_EACH_LINE
    --22-May-15  Infosys          1.4   Adding BACKORDER_HOLD for cancel_fail and shipped lines
    --                                               Identified by BACKORDER_HOLD
    --25-May-15 Infosys           1.5   Added new HOLD 'Highjump Backoder Hold' for putting holds at Line level
    --                                               Identified by HIGHJUMP_BACKORDER_HOLD
    --01-Jun-15  Infosys           1.6   Added new variable initialization for  table types ,
    --                                             Identified by VARIABLE_INI
    --02-Jun-15 Infosys            1.7    SYSDATE is passed as transaction date to Transact Move order API
    --                                              Identified by MOVE_ORDER_DATE
    --12-Jun-15 Infosys           1.8   Hold not getting applied for ecomm orders
    --                                             Identified by ECOMM_BUG_HOLD
    --03-Sep-15 Infosys            1.9   SHIPPED messages after CANCEL message
    --                                             Identified by CANCEL_SHIP
    --21-Sep-15 Infosys            2.0  Back order Hold only for Ecomm ordersd Identified by ECOMM_BACK
    --28-Sep-15 Infosys           2.1  Update wsh_delivery_details for source_header_id Identified by DEL_SOURCE_HDR_ID
    --30-Oct-15 Infosys           2.2  update oe_order_lines_all for attribute12 Indentified by LINE_ATTRIBUTE
    --30-Oct-15 Infosys           2.3  Remove condition with SHIP message Indentified by
    --05-Dec-17 Infosys     2.4  Updatind SHIPPED message records to PROCESSED if order has No Open shipping lines;
    --                                 Identified by ORDER_NO_OPEN_SHIP_LN
    -- 31-Aug-19 Tejaswi Gangumalla 2.5 Modified for CCR CCR0007831 to apply hold on all order when order is backordered
    -- 31-Dec-22    Shivanshu          2.6       Modified for CCR0010172
    -- ***************************************************************************

    --------------------------
    --Declare global variables
    --
    --------------------------------------------------------------------------------
    -- Procedure  : msg
    -- Description: procedure to print debug messages
    --------------------------------------------------------------------------------
    del_txns             tab_del_txn;
    g_num_shipped_mode   VARCHAR2 (1) := 'N';
    g_package_name       VARCHAR2 (100) := 'XXDO_ONT_ORDER_UPDATE_PKG';

    PROCEDURE msg (MESSAGE IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, MESSAGE);
    END msg;

    /****************************************************************************
    -- Procedure Name      :  purge_archive
    --
    -- Description         :  This procedure is to archive and purge the old records


    -- Parameters          : p_errbuf      OUT : Error message
    --                              p_retcode     OUT : Execution
    -
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------

    --------------------------------
    -- 2015/02/02 Infosys            1.0  Initial Version.
    --
    --
    ***************************************************************************/
    PROCEDURE purge_archive (p_errbuf       OUT VARCHAR2,
                             p_retcode      OUT NUMBER,
                             p_purge     IN     NUMBER)
    IS
        lv_procedure    VARCHAR2 (100) := '.PURGE_ARCHIVE';
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        msg ('Purging ' || p_purge || ' days old records...');

        /*Pick Ticket  Orders interface*/

        BEGIN
            INSERT INTO xxdo_ont_pick_status_order_log (wh_id,
                                                        order_number,
                                                        status,
                                                        tran_date,
                                                        request_id,
                                                        destination,
                                                        source,
                                                        record_type,
                                                        process_status,
                                                        last_update_login,
                                                        last_update_date,
                                                        last_updated_by,
                                                        creation_date,
                                                        created_by,
                                                        error_msg,
                                                        comments,
                                                        shipment_status,
                                                        shipment_number,
                                                        archive_date,
                                                        archive_request_id)
                SELECT wh_id, order_number, status,
                       tran_date, request_id, destination,
                       source, record_type, process_status,
                       last_update_login, last_update_date, last_updated_by,
                       creation_date, created_by, error_msg,
                       comments, shipment_status, shipment_number,
                       l_dte_sysdate, g_num_request_id
                  FROM xxdo_ont_pick_status_order
                 WHERE TRUNC (creation_date) <
                       TRUNC (l_dte_sysdate) - p_purge;

            DELETE FROM
                xxdo_ont_pick_status_order
                  WHERE TRUNC (creation_date) <
                        TRUNC (l_dte_sysdate) - p_purge;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := 1;
                p_errbuf    :=
                       'Error happened while archiving Pick Ticket Order Status Data'
                    || SQLERRM;
                msg (
                       'Error happened while archiving Pick Ticket Order StatusData '
                    || SQLERRM);
        END;

        /*Pick Ticket  Orders Load interface*/

        BEGIN
            INSERT INTO xxdo_ont_pick_status_load_log (wh_id,
                                                       order_number,
                                                       shipment_number,
                                                       master_load_ref,
                                                       comments,
                                                       created_by,
                                                       creation_date,
                                                       last_updated_by,
                                                       last_update_date,
                                                       last_update_login,
                                                       process_status,
                                                       record_type,
                                                       archive_date,
                                                       archive_request_id)
                SELECT wh_id, order_number, shipment_number,
                       master_load_ref, comments, created_by,
                       creation_date, last_updated_by, last_update_date,
                       last_update_login, process_status, record_type,
                       l_dte_sysdate, g_num_request_id
                  FROM xxdo_ont_pick_status_load
                 WHERE TRUNC (creation_date) <
                       TRUNC (l_dte_sysdate) - p_purge;

            DELETE FROM
                xxdo_ont_pick_status_load
                  WHERE TRUNC (creation_date) <
                        TRUNC (l_dte_sysdate) - p_purge;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_retcode   := 1;
                p_errbuf    :=
                       'Error happened while archiving Pick Ticket Order Load Data'
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving Pick Ticket Order Load Data '
                    || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Error occured in PROCEDURE  '
                || lv_procedure
                || '-'
                || SQLERRM);
    END purge_archive;

    /*OU_BUG*/
    /** ****************************************************************************
   -- Procedure Name      :  get_resp_details
   --
   -- Description         :  This procedure is to archive and purge the old records


   -- Parameters          : p_resp_id      OUT : Responsibility ID
   --                              p_resp_appl_id     OUT : Application ID
   -
   -- Return/Exit         :  none
   --
   --
   -- DEVELOPMENT and MAINTENANCE HISTORY
   --
   -- date          author             Version  Description
   -- ------------  -----------------  -------

   --------------------------------
   -- 2015/04/01 Infosys            1.0  Initial Version.
   --
   --

    /*OU_BUG*/

    /****************************************************************************/
    PROCEDURE get_resp_details (p_org_id IN NUMBER, p_module_name IN VARCHAR2, p_resp_id OUT NUMBER
                                , p_resp_appl_id OUT NUMBER)
    IS
        lv_mo_resp_id           NUMBER;
        lv_mo_resp_appl_id      NUMBER;
        lv_const_om_resp_name   VARCHAR2 (200)
                                    := 'Order Management Super User';
        lv_const_po_resp_name   VARCHAR2 (200) := 'Purchasing Super User';
        lv_const_ou_name        VARCHAR2 (200);
        lv_var_ou_name          VARCHAR2 (200);
    BEGIN
        IF p_module_name = 'ONT'
        THEN
            BEGIN
                SELECT resp.responsibility_id, resp.application_id, resp.responsibility_name
                  INTO lv_mo_resp_id, lv_mo_resp_appl_id, lv_const_po_resp_name
                  FROM fnd_lookup_values flv, hr_operating_units hou, fnd_responsibility_vl resp
                 WHERE     flv.lookup_code = UPPER (hou.name)
                       AND flv.lookup_type = 'XXDO_APPL_RESP_SETUP'
                       AND flv.enabled_flag = 'Y'
                       AND language = 'US'
                       AND hou.organization_id = p_org_id
                       AND flv.description = resp.responsibility_name
                       AND end_date_active IS NULL
                       AND end_date IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_resp_id        := NULL;
                    p_resp_appl_id   := NULL;
            END;
        ELSIF p_module_name = 'PO'
        THEN
            BEGIN
                SELECT resp.responsibility_id, resp.application_id, resp.responsibility_name
                  INTO lv_mo_resp_id, lv_mo_resp_appl_id, lv_const_po_resp_name
                  FROM fnd_lookup_values flv, hr_operating_units hou, fnd_responsibility_vl resp
                 WHERE     flv.lookup_code = UPPER (hou.name)
                       AND flv.lookup_type = 'XXDO_APPL_RESP_SETUP'
                       AND flv.enabled_flag = 'Y'
                       AND language = 'US'
                       AND hou.organization_id = p_org_id
                       AND meaning = resp.responsibility_name
                       AND end_date_active IS NULL
                       AND end_date IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_resp_id        := NULL;
                    p_resp_appl_id   := NULL;
            END;
        END IF;

        msg (
               'Responsbility Application Id '
            || lv_mo_resp_appl_id
            || '-'
            || lv_mo_resp_id);

        msg (
               'Responsbility Details '
            || p_module_name
            || '-'
            || lv_const_po_resp_name);
        p_resp_id        := lv_mo_resp_id;
        p_resp_appl_id   := lv_mo_resp_appl_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_resp_id        := NULL;
            p_resp_appl_id   := NULL;
    END get_resp_details;

    /*OU_BUG*/

    /*BACKORDER_HOLD*/
    PROCEDURE apply_hold (ph_line_tbl IN OUT oe_holds_pvt.order_tbl_type, --   p_org_id          IN     NUMBER,
                                                                          p_hold_comment IN VARCHAR2, p_return_status OUT NUMBER
                          , p_error_message OUT VARCHAR2)
    IS
        lv_order_tbl         oe_holds_pvt.order_tbl_type;
        lv_hold_id           NUMBER;
        lv_comment           VARCHAR2 (100);
        lv_return_status     VARCHAR2 (10);
        ln_msg_count         NUMBER;
        lv_msg_data          VARCHAR2 (200);
        lv_procedure         VARCHAR2 (240)
            := SUBSTR (g_package_name || '.apply_hold', 1, 240);
        lv_cnt               NUMBER;
        lv_mo_resp_id        NUMBER;
        lv_mo_resp_appl_id   NUMBER;
        lv_org_exists        VARCHAR2 (3);
        lv_count             NUMBER;
        lv_loop_msg          VARCHAR2 (2000);
        lv_msg_index_out     NUMBER;
        lv_num_first         NUMBER := 0;                   /*ECOMM_BUG_HOLD*/
        lv_org_id            NUMBER;

        CURSOR line_back_order (p_header_id IN NUMBER, p_line_id IN NUMBER)
        IS
            /*Start of ECOMM_BACK*/
            /* 09/15 below cursor is changed to consider only ECOM lines */
            SELECT wdd.source_header_id header_id, wdd.source_line_id line_id, wdd.organization_id,
                   wdd.org_id
              FROM wsh_delivery_details wdd, oe_order_lines_all ool, oe_order_sources oos
             WHERE     wdd.source_header_id = p_header_id
                   AND wdd.source_line_id = p_line_id
                   AND wdd.released_status = 'B'
                   AND ool.line_id = p_line_id
                   AND ool.order_source_id = oos.order_source_id;
    --   AND oos.name = 'Flagstaff'; Commented for CCR CCR0007831 to apply_hold on all orders
    /*Ends  of ECOMM_BACK*/
    BEGIN
        p_error_message   := NULL;
        p_return_status   := 0;                              -- g_ret_success;
        --   lv_order_tbl := ph_line_tbl;
        msg ('Calling Hold Package');

        IF lv_order_tbl.EXISTS (1)
        THEN
            lv_order_tbl.DELETE;                                --VARIABLE_INI
        END IF;

        BEGIN
            SELECT hold_id
              INTO lv_hold_id
              FROM oe_hold_definitions
             WHERE NAME = 'Highjump Backorder Hold'; -- HIGHJUMP_BACKORDER_HOLD
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                msg ('Highjump Backoder Hold is not defined');
                p_error_message   := 'Highjump Backoder Hold is not defined';
                p_return_status   := 2;
                RETURN;
            WHEN OTHERS
            THEN
                p_error_message   := SQLERRM;
                p_return_status   := 2;
                RETURN;
        END;

        lv_comment        :=
            NVL (
                p_hold_comment,
                'Hold applied by Deckers Order Status Program for Back Ordered Line');
        SAVEPOINT APPLY_HOLD;

        FOR i IN 1 .. ph_line_tbl.COUNT
        LOOP
            FOR line_back_order_rec
                IN line_back_order (ph_line_tbl (i).header_id,
                                    ph_line_tbl (i).line_id)
            LOOP
                /*OU_BUG*/

                IF lv_num_first = 0
                THEN
                    lv_org_exists   := line_back_order_rec.org_id;
                END IF;

                IF (lv_num_first = 0 OR (lv_org_exists <> line_back_order_rec.org_id))
                THEN
                    get_resp_details (line_back_order_rec.org_id, 'ONT', lv_mo_resp_id
                                      , lv_mo_resp_appl_id);

                    apps.fnd_global.apps_initialize (
                        user_id        => g_num_user_id,
                        resp_id        => lv_mo_resp_id,
                        resp_appl_id   => lv_mo_resp_appl_id);
                    mo_global.init ('ONT');
                END IF;

                lv_num_first                 := lv_num_first + 1;
                lv_order_tbl (i).header_id   := line_back_order_rec.header_id;
                lv_order_tbl (i).line_id     := line_back_order_rec.line_id;
                msg ('Header id ' || lv_order_tbl (i).header_id);
                msg ('Line Id ' || lv_order_tbl (i).line_id);
                lv_org_id                    := line_back_order_rec.org_id;
            /*OU_BUG*/

            /*Start of LINE_ATTRIBUTE1*/
            --  for j in 1..lv_order_tbl.COUNT
            -- LOOP

            /*      update oe_order_lines_all
                  set attribute11=null
                  where line_id=lv_order_tbl (i).line_id
                  and attribute11 is not null;

                  COMMIT;

                --  END LOOP;
                    /*End  of LINE_ATTRIBUTE1*/
            END LOOP;
        END LOOP;

        msg ('Calling Apply Hold');
        lv_loop_msg       := '';
        mo_global.set_policy_context ('S', lv_org_id);
        oe_holds_pub.apply_holds (
            p_api_version        => 1.0,
            p_init_msg_list      => fnd_api.g_false,
            p_commit             => fnd_api.g_false,
            p_validation_level   => fnd_api.g_valid_level_full,
            p_order_tbl          => lv_order_tbl,
            p_hold_id            => lv_hold_id,
            p_hold_until_date    => NULL,
            p_hold_comment       => lv_comment,
            x_return_status      => lv_return_status,
            x_msg_count          => ln_msg_count,
            x_msg_data           => lv_msg_data);

        IF lv_return_status <> 'S'
        THEN
            p_return_status   := 2;
            p_error_message   := lv_msg_data;
            msg ('Hold Couldn''t be applied ' || SQLERRM);
            msg (
                   'Hold Couldn''t be applied lv_return_status  '
                || lv_return_status);

            -- Retrieve messages
            FOR i IN 1 .. ln_msg_count
            LOOP
                Oe_Msg_Pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => lv_msg_data
                                , p_msg_index_out => lv_msg_index_out);
                msg ('message is: ' || lv_msg_data);
                msg ('message index is: ' || lv_msg_index_out);
            END LOOP;

            ROLLBACK TO APPLY_HOLD;
            RETURN;
        END IF;

        IF NVL (lv_return_status, 'X') = 'S'
        THEN
            COMMIT;

            msg ('Hold Applied Sucessfully');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 2;
            p_error_message   := SQLERRM;
            msg ('Error in ' || lv_procedure || SQLERRM);
    END apply_hold;

    /*BACKORDER_HOLD*/
    --------------------------------------------------------------------------------
    -- Procedure  : back_order
    -- Description: This procedure will be called back Order a sales Order.
    --------------------------------------------------------------------------------

    PROCEDURE back_order (errbuf              OUT VARCHAR2,
                          retcode             OUT NUMBER,
                          p_order_number   IN     VARCHAR2)
    IS
        x_return_status             VARCHAR2 (100);
        x_msg_count                 NUMBER;
        x_msg_data                  VARCHAR2 (100);
        l_chr_return_status         VARCHAR2 (30) := NULL;
        l_num_msg_count             NUMBER;
        l_num_msg_cntr              NUMBER;
        l_msg_index_out             NUMBER;
        l_chr_msg_data              VARCHAR2 (2000);
        l_num_delivery_id           NUMBER;
        l_chr_delivery_name         VARCHAR2 (240);
        l_rec_delivery_info         wsh_deliveries_pub.delivery_pub_rec_type;
        l_num_trip_id               NUMBER;
        l_chr_trip_name             VARCHAR2 (240);
        l_num_to_stop               NUMBER;
        p_out_num_delivery_id       VARCHAR2 (100);
        l_shipped_del_dtl_ids_tab   tabtype_id;
        l_chr_errbuf                VARCHAR2 (100);
        l_chr_retcode               NUMBER;
        lv_i                        NUMBER := 0;
        lv_total                    NUMBER := 0;
        lv_all_total                NUMBER := 0;
        lv_order_tbl                oe_holds_pvt.order_tbl_type;

        CURSOR back_ord_data IS
            SELECT DISTINCT wnd.delivery_id, wnd.initial_pickup_location_id, wnd.ultimate_dropoff_location_id,
                            wnd.customer_id, wnd.ship_method_code, ool.line_id,
                            ool.header_id, wdd.delivery_detail_id, wdd.shipped_quantity,
                            wdd.transaction_id, wdd.released_status, ooh.order_number,
                            wdd.organization_id
              FROM oe_order_headers_all ooh, oe_order_lines_all ool, wsh_delivery_details wdd,
                   wsh_new_deliveries wnd
             WHERE     ooh.header_id = ool.header_id
                   AND ool.line_id = wdd.source_line_id
                   AND wdd.released_status IN ('S', 'Y')
                   AND wnd.delivery_id = wdd.attribute11
                   AND wnd.status_code = 'CL'
                   AND wnd.delivery_id = p_order_number;

        CURSOR after_check (p_delivery_detail_id IN NUMBER)
        IS
            SELECT 1
              FROM wsh_delivery_details wdd
             WHERE     wdd.delivery_detail_id = p_delivery_detail_id
                   AND wdd.released_status = 'B';
    BEGIN
        --VARIABLE_INI
        IF del_txns.EXISTS (1)
        THEN
            del_txns.DELETE;
        END IF;

        IF l_shipped_del_dtl_ids_tab.EXISTS (1)
        THEN
            l_shipped_del_dtl_ids_tab.DELETE;
        END IF;

        IF lv_order_tbl.EXISTS (1)
        THEN
            lv_order_tbl.DELETE;
        END IF;

        --VARIABLE_INI


        FOR c_ord_detials IN back_ord_data
        LOOP
            IF lv_i = 0
            THEN
                l_rec_delivery_info.organization_id   :=
                    c_ord_detials.organization_id;
                l_rec_delivery_info.customer_id   :=
                    c_ord_detials.customer_id;
                l_rec_delivery_info.ship_method_code   :=
                    c_ord_detials.ship_method_code;
                l_rec_delivery_info.initial_pickup_location_id   :=
                    c_ord_detials.initial_pickup_location_id;
                l_rec_delivery_info.ultimate_dropoff_location_id   :=
                    c_ord_detials.ultimate_dropoff_location_id;
                --    l_rec_delivery_info.waybill := p_in_chr_waybill;
                l_rec_delivery_info.attribute11   :=
                    c_ord_detials.delivery_id;
                --  l_rec_delivery_info.attribute2   := p_in_chr_carrier;
                --  l_rec_delivery_info.attribute1   := p_in_chr_tracking_number;

                -- Call create_update_delivery api
                fnd_file.put_line (fnd_file.LOG, ' ');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Start Calling create update delivery API..');
            END IF;

            lv_i                                 := lv_i + 1;
            l_shipped_del_dtl_ids_tab (lv_i)     :=
                c_ord_detials.delivery_detail_id;
            del_txns (lv_i).delivery_detail_id   :=
                c_ord_detials.delivery_detail_id;
            del_txns (lv_i).transaction_id       :=
                c_ord_detials.transaction_id;

            lv_order_tbl (lv_i).header_id        := c_ord_detials.header_id;
            lv_order_tbl (lv_i).line_id          := c_ord_detials.line_id;
        END LOOP;

        wsh_deliveries_pub.create_update_delivery (
            p_api_version_number   => g_num_api_version,
            p_init_msg_list        => fnd_api.g_true,
            x_return_status        => l_chr_return_status,
            x_msg_count            => l_num_msg_count,
            x_msg_data             => l_chr_msg_data,
            p_action_code          => 'CREATE',
            p_delivery_info        => l_rec_delivery_info,
            x_delivery_id          => l_num_delivery_id,
            x_name                 => l_chr_delivery_name);

        IF l_chr_return_status <> fnd_api.g_ret_sts_success
        THEN
            retcode   := 2;
            errbuf    :=
                   'API to create delivery failed with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, errbuf);

            IF l_num_msg_count > 0
            THEN
                p_out_num_delivery_id   := 0;
                -- Retrieve messages
                l_num_msg_cntr          := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message:' || l_chr_msg_data);
                END LOOP;
            END IF;
        ELSE
            errbuf                  :=
                   'API to create delivery was successful with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, errbuf);
            p_out_num_delivery_id   := l_num_delivery_id;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Delivery ID > '
                || TO_CHAR (l_num_delivery_id)
                || ' : Delivery Name > '
                || l_chr_delivery_name);
            fnd_file.put_line (fnd_file.LOG,
                               'End Calling create update delivery.api..');
            retcode                 := 0;

            /* DEL_SOURCE_HDR_ID  - Start */

            /*  Assinging the delivery detail to new delivery was failing since Source header id is blank on the new delivery created in 12.2.3.
             So, Source header id is updated on new delivery */

            UPDATE wsh_new_deliveries
               SET source_header_id   = lv_order_tbl (1).header_id --l_delivery_dtl_tab (1).header_id
             WHERE delivery_id = l_num_delivery_id;

            /* DEL_SOURCE_HDR_ID  - End */

            ---Update the original delivery name

            ---Call Assign Delivery code
            BEGIN
                assign_detail_to_delivery (
                    errbuf                     => errbuf,
                    retcode                    => retcode,
                    p_in_num_delivery_id       => l_num_delivery_id,
                    p_in_chr_delivery_name     => l_chr_delivery_name,
                    p_in_delivery_detail_ids   => l_shipped_del_dtl_ids_tab,
                    p_in_chr_action            => 'ASSIGN');
            EXCEPTION
                WHEN OTHERS
                THEN
                    retcode   := 2;
                    errbuf    :=
                           'Unexpected Error while invoking assign delivery detail procedure :'
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, errbuf);
            END;

            IF retcode = 1
            THEN
                --check the status of the delivery lines
                fnd_file.put_line (fnd_file.LOG,
                                   'Inside Code retcode' || retcode);


                fnd_file.put_line (
                    fnd_file.LOG,
                       'l_shipped_del_dtl_ids_tab.COUNT'
                    || l_shipped_del_dtl_ids_tab.COUNT); /* HIGHJUMP_BACKORDER_HOLD */

                IF l_shipped_del_dtl_ids_tab.COUNT > 0
                THEN
                    FOR i IN 1 .. l_shipped_del_dtl_ids_tab.COUNT
                    LOOP
                        OPEN after_check (l_shipped_del_dtl_ids_tab (i));


                        fnd_file.put_line (fnd_file.LOG, ' i :' || i); /* HIGHJUMP_BACKORDER_HOLD */

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'l_shipped_del_dtl_ids_tab (i) :'
                            || l_shipped_del_dtl_ids_tab (i)); /* HIGHJUMP_BACKORDER_HOLD   */

                        FETCH after_check INTO lv_total;

                        fnd_file.put_line (fnd_file.LOG,
                                           ' lv_total : ' || lv_total); /* HIGHJUMP_BACKORDER_HOLD */

                        lv_all_total   := lv_all_total + lv_total;

                        /* HIGHJUMP_BACKORDER_HOLD  - Start */

                        IF after_check%ISOPEN
                        THEN
                            CLOSE after_check;
                        END IF;
                    /* HIGHJUMP_BACKORDER_HOLD  - End */


                    END LOOP;
                END IF;

                fnd_file.put_line (fnd_file.LOG,
                                   'lv_all_total : ' || lv_all_total); /* HIGHJUMP_BACKORDER_HOLD  */


                IF (l_shipped_del_dtl_ids_tab.COUNT = lv_all_total)
                THEN
                    --Back Order Sucessfull
                    retcode   := 0;
                    errbuf    := 'SUCCESS';
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Inside Code retcode back order ' || retcode);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Inside Code errbuf back order ' || errbuf);

                    /*    Start of LINE_ATTRIBUTE1*/
                    FOR j IN 1 .. lv_order_tbl.COUNT
                    LOOP
                        UPDATE oe_order_lines_all
                           SET attribute11   = NULL
                         WHERE     line_id = lv_order_tbl (j).line_id
                               AND attribute11 IS NOT NULL;

                        COMMIT;
                    END LOOP;

                    /*End  of LINE_ATTRIBUTE1*/

                    /*BACKORDER_HOLD*/
                    BEGIN
                        apply_hold (lv_order_tbl, --     c_hold_data_rec.org_id,
                                                  'Hold applied', retcode,
                                    errbuf);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            retcode   := 2;
                            msg ('Error while calling apply_hold');
                            errbuf    :=
                                'Error while calling apply_hold' || SQLERRM;
                    --  ROLLBACK;
                    END;

                    --   IF retcode = 0 THEN                                    /*REMOVE_CONDITION*/
                    clear_bucket (errbuf, retcode, del_txns);
                --   END IF;                                                     /*REMOVE_CONDITION*/

                /*BACKORDER_HOLD*/
                END IF;
            -- null;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 2;
            errbuf    := 'Error in back_order routine ' || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'errbuf : ' || errbuf); /* HIGHJUMP_BACKORDER_HOLD  */
    END back_order;

    PROCEDURE assign_detail_to_delivery (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_in_num_delivery_id IN NUMBER
                                         , p_in_chr_delivery_name IN VARCHAR2, p_in_delivery_detail_ids IN tabtype_id, p_in_chr_action IN VARCHAR2 DEFAULT 'ASSIGN')
    IS
        l_chr_return_status        VARCHAR2 (30) := NULL;
        l_num_msg_count            NUMBER;
        l_num_msg_cntr             NUMBER;
        l_num_msg_index_out        NUMBER;
        l_chr_msg_data             VARCHAR2 (2000);
        l_del_details_ids_tab      wsh_delivery_details_pub.id_tab_type;
        l_changed_attributes_tab   wsh_delivery_details_pub.changedattributetabtype;
        excp_set_error             EXCEPTION;
    BEGIN
        errbuf    := NULL;
        retcode   := 0;

        --VARIABLE_INI
        IF l_del_details_ids_tab.EXISTS (1)
        THEN
            l_del_details_ids_tab.DELETE;                    --Added 01Jun2015
        END IF;

        IF l_changed_attributes_tab.EXISTS (1)
        THEN
            l_changed_attributes_tab.DELETE;                 --Added 01Jun2015
        END IF;

        --VARIABLE_INI

        FOR l_num_ind IN 1 .. p_in_delivery_detail_ids.COUNT
        LOOP
            l_del_details_ids_tab (l_num_ind)                       :=
                p_in_delivery_detail_ids (l_num_ind);
            l_changed_attributes_tab (l_num_ind).delivery_detail_id   :=
                p_in_delivery_detail_ids (l_num_ind);
            l_changed_attributes_tab (l_num_ind).shipped_quantity   := 0;
        END LOOP;

        wsh_delivery_details_pub.detail_to_delivery (
            p_api_version        => g_num_api_version,
            p_init_msg_list      => fnd_api.g_true,
            p_commit             => fnd_api.g_false,
            p_validation_level   => NULL,
            x_return_status      => l_chr_return_status,
            x_msg_count          => l_num_msg_count,
            x_msg_data           => l_chr_msg_data,
            p_tabofdeldets       => l_del_details_ids_tab,
            p_action             => p_in_chr_action,
            p_delivery_id        => p_in_num_delivery_id);

        IF l_chr_return_status <> fnd_api.g_ret_sts_success
        THEN
            IF l_num_msg_count > 0
            THEN
                retcode          := 2;
                errbuf           :=
                       'API to '
                    || LOWER (p_in_chr_action)
                    || ' delivery detail id failed with status: '
                    || l_chr_return_status;
                fnd_file.put_line (fnd_file.LOG, errbuf);
                -- Retrieve messages
                l_num_msg_cntr   := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message : ' || l_chr_msg_data);
                END LOOP;
            END IF;
        ELSE
            errbuf    :=
                   'API to '
                || LOWER (p_in_chr_action)
                || ' delivery detail was successful with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, errbuf);
            retcode   := 0;

            ---then call ship_line
            BEGIN
                update_backord_delivery (
                    errbuf                 => errbuf,
                    retcode                => retcode,
                    p_in_num_delivery_id   => p_in_num_delivery_id,
                    p_changed_attributes   => l_changed_attributes_tab);
            EXCEPTION
                WHEN OTHERS
                THEN
                    retcode   := 2;
                    errbuf    :=
                           'Unexpected Error while invoking assign delivery detail procedure :'
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, errbuf);
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 2;
            errbuf    :=
                   'Unexpected error while '
                || LOWER (p_in_chr_action)
                || 'ing delivery detail.'
                || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, errbuf);
    END;

    PROCEDURE cancel_delivery (errbuf                    OUT VARCHAR2,
                               retcode                   OUT NUMBER,
                               p_in_num_delivery_id   IN     NUMBER)
    IS
        CURSOR c_cancel_rec IS
            SELECT wdd.delivery_detail_id, wdd.transaction_id, wdd.source_header_id,
                   wdd.source_line_id
              FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
             WHERE     wdd.delivery_detail_id = wda.delivery_detail_id
                   AND wda.delivery_id = p_in_num_delivery_id
                   AND wdd.released_status = 'Y';

        l_changed_attributes_tab   wsh_delivery_details_pub.changedattributetabtype;
        lv_order_tbl               oe_holds_pvt.order_tbl_type;
        lv_i                       NUMBER := 0;
        cancel_dels                tab_del_txn;
    BEGIN
        --VARIABLE_INI
        IF cancel_dels.EXISTS (1)
        THEN
            cancel_dels.DELETE;                              --Added 01Jun2015
        END IF;

        IF l_changed_attributes_tab.EXISTS (1)
        THEN
            l_changed_attributes_tab.DELETE;                 --Added 01Jun2015
        END IF;

        IF lv_order_tbl.EXISTS (1)
        THEN
            lv_order_tbl.DELETE;                             --Added 01Jun2015
        END IF;

        --VARIABLE_INI

        FOR c_cancel_data IN c_cancel_rec
        LOOP
            lv_i                                                 := lv_i + 1;
            l_changed_attributes_tab (lv_i).delivery_detail_id   :=
                c_cancel_data.delivery_detail_id;
            l_changed_attributes_tab (lv_i).shipped_quantity     := 0;
            cancel_dels (lv_i).delivery_detail_id                :=
                c_cancel_data.delivery_detail_id;
            cancel_dels (lv_i).transaction_id                    :=
                c_cancel_data.transaction_id;
            lv_order_tbl (lv_i).header_id                        :=
                c_cancel_data.source_header_id;
            lv_order_tbl (lv_i).line_id                          :=
                c_cancel_data.source_line_id;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'Cancel Delivery:' || p_in_num_delivery_id);
        update_backord_delivery (errbuf, retcode, p_in_num_delivery_id,
                                 l_changed_attributes_tab);
        /*BACKORDER_HOLD*/
        msg ('Retun code for BackORd Delivery ' || retcode);

        IF retcode = 1
        THEN
            /*    Start of LINE_ATTRIBUTE1*/
            FOR j IN 1 .. lv_order_tbl.COUNT
            LOOP
                UPDATE oe_order_lines_all
                   SET attribute11   = NULL
                 WHERE     line_id = lv_order_tbl (j).line_id
                       AND attribute11 IS NOT NULL;

                COMMIT;
            END LOOP;

            /*End  of LINE_ATTRIBUTE1*/

            BEGIN
                apply_hold (lv_order_tbl, --     c_hold_data_rec.org_id,
                                          'Hold applied', retcode,
                            errbuf);
            EXCEPTION
                WHEN OTHERS
                THEN
                    retcode   := 2;
                    msg ('Error while calling apply_hold');
                    errbuf    := 'Error while calling apply_hold' || SQLERRM;
            END;
        END IF;

        clear_bucket (errbuf, retcode, cancel_dels);
    /*BACKORDER_HOLD*/
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                'unexpected error in Cancel Delivery:' || SQLERRM);
    END cancel_delivery;

    PROCEDURE update_backord_delivery (
        errbuf                    OUT VARCHAR2,
        retcode                   OUT NUMBER,
        p_in_num_delivery_id   IN     NUMBER,
        p_changed_attributes   IN     wsh_delivery_details_pub.changedattributetabtype)
    IS
        l_msg_index_out          NUMBER;
        l_num_msg_cntr           NUMBER;
        l_chr_msg_data           VARCHAR2 (2000);
        l_num_delivery_id        NUMBER;
        l_chr_delivery_name      VARCHAR2 (240);
        l_chr_return_status      VARCHAR2 (30) := NULL;
        l_num_msg_count          NUMBER;
        l_num_msg_index_out      NUMBER;
        --  l_chr_msg_data         VARCHAR2 (2000);
        l_chr_source_code        VARCHAR2 (15) := 'OE';
        l_num_trip_id            NUMBER;
        l_chr_trip_name          VARCHAR2 (240);
        p_asg_trip_id            NUMBER;
        p_asg_trip_name          VARCHAR2 (30);
        p_asg_pickup_stop_id     NUMBER;
        p_asg_pickup_loc_id      NUMBER;
        p_asg_pickup_loc_code    VARCHAR2 (30);
        p_asg_pickup_arr_date    DATE;
        p_asg_pickup_dep_date    DATE;
        p_asg_dropoff_stop_id    NUMBER;
        p_asg_dropoff_loc_id     NUMBER;
        p_asg_dropoff_loc_code   VARCHAR2 (30);
        p_asg_dropoff_arr_date   DATE;
        p_asg_dropoff_dep_date   DATE;
        p_sc_action_flag         VARCHAR2 (10);
        p_sc_close_trip_flag     VARCHAR2 (10);
        p_sc_create_bol_flag     VARCHAR2 (10);
        p_sc_stage_del_flag      VARCHAR2 (10);
        p_sc_trip_ship_method    VARCHAR2 (30);
        p_sc_actual_dep_date     VARCHAR2 (30);
        p_sc_report_set_id       NUMBER;
        p_sc_report_set_name     VARCHAR2 (60);
        p_wv_override_flag       VARCHAR2 (10);
    BEGIN
        wsh_delivery_details_pub.update_shipping_attributes (
            p_api_version_number   => g_num_api_version,
            p_init_msg_list        => fnd_api.g_true,
            p_commit               => fnd_api.g_false,
            x_return_status        => l_chr_return_status,
            x_msg_count            => l_num_msg_count,
            x_msg_data             => l_chr_msg_data,
            p_changed_attributes   => p_changed_attributes,
            p_source_code          => l_chr_source_code);

        IF l_chr_return_status <> fnd_api.g_ret_sts_success
        THEN
            IF l_num_msg_count > 0
            THEN
                retcode          := 2;
                errbuf           :=
                       'API to update shipping attributes failed with status: '
                    || l_chr_return_status;
                fnd_file.put_line (fnd_file.LOG, errbuf);
                -- Retrieve messages
                l_num_msg_cntr   := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message : ' || l_chr_msg_data);
                END LOOP;

                errbuf           := l_chr_msg_data;
            END IF;
        ELSE
            errbuf    :=
                   'API to update shipping attributes was successful with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, errbuf);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Delivery Detail > '
                --|| TO_CHAR (1056562061)
                || p_changed_attributes (1).delivery_detail_id
                || ' : Updated Ship Quantity > '
                || TO_CHAR (0));
            retcode   := 0;
            --The calll ship confirm
            wsh_deliveries_pub.delivery_action (
                p_api_version_number     => g_num_api_version,
                p_init_msg_list          => fnd_api.g_true,
                x_return_status          => l_chr_return_status,
                x_msg_count              => l_num_msg_count,
                x_msg_data               => l_chr_msg_data,
                p_action_code            => 'CONFIRM',
                p_delivery_id            => p_in_num_delivery_id,
                p_asg_trip_id            => p_asg_trip_id,
                p_asg_trip_name          => p_asg_trip_name,
                p_asg_pickup_stop_id     => p_asg_pickup_stop_id,
                p_asg_pickup_loc_id      => p_asg_pickup_loc_id,
                p_asg_pickup_loc_code    => p_asg_pickup_loc_code,
                p_asg_pickup_arr_date    => p_asg_pickup_arr_date,
                p_asg_pickup_dep_date    => p_asg_pickup_dep_date,
                p_asg_dropoff_stop_id    => p_asg_dropoff_stop_id,
                p_asg_dropoff_loc_id     => p_asg_dropoff_loc_id,
                p_asg_dropoff_loc_code   => p_asg_dropoff_loc_code,
                p_asg_dropoff_arr_date   => p_asg_dropoff_arr_date,
                p_asg_dropoff_dep_date   => p_asg_dropoff_dep_date,
                p_sc_action_flag         => 'C',
                p_sc_close_trip_flag     => p_sc_close_trip_flag,
                p_sc_create_bol_flag     => p_sc_create_bol_flag,
                p_sc_stage_del_flag      => 'N',
                p_sc_trip_ship_method    => p_sc_trip_ship_method,
                p_sc_actual_dep_date     => p_sc_actual_dep_date,
                p_sc_report_set_id       => p_sc_report_set_id,
                p_sc_report_set_name     => p_sc_report_set_name,
                p_wv_override_flag       => p_wv_override_flag,
                x_trip_id                => l_num_trip_id,
                x_trip_name              => l_chr_trip_name);
            fnd_file.put_line (fnd_file.LOG,
                               'Updating the ship date at order line level');

            IF l_chr_return_status NOT IN (fnd_api.g_ret_sts_success) --g_ret_sts_warning)
            THEN
                retcode   := 2;
                errbuf    :=
                       'API to confirm shipment completed with status:'
                    || l_chr_return_status;
                fnd_file.put_line (fnd_file.LOG, errbuf);

                IF l_num_msg_count > 0
                THEN
                    -- Retrieve messages
                    l_num_msg_cntr   := 1;

                    WHILE l_num_msg_cntr <= l_num_msg_count
                    LOOP
                        fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                         , p_msg_index_out => l_msg_index_out);
                        l_num_msg_cntr   := l_num_msg_cntr + 1;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error Message : ' || l_chr_msg_data);
                    END LOOP;
                END IF;
            ELSE
                errbuf    :=
                       'API to confirm shipment was successful with status: '
                    || l_chr_return_status;
                fnd_file.put_line (fnd_file.LOG, errbuf);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Ship Confirmed Delivery > '
                    || TO_CHAR (p_in_num_delivery_id));
                retcode   := 1;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 2;
            errbuf    :=
                   'Error Occured while calling Update Attrbiute and Ship Confirm '
                || SQLERRM;
    END;

    --------------------------------------------------------------------------------
    -- Procedure  : pick_confirm
    -- Description: This procedure will be called to pick confirm a order.
    --------------------------------------------------------------------------------
    PROCEDURE pick_confirm (p_order_number   IN     VARCHAR2,
                            p_out_msg           OUT VARCHAR2)
    IS
        CURSOR c_del_dets IS
            SELECT mtrl.line_id mo_line_id, mtrl.transaction_header_id
              FROM oe_order_lines_all ool, --Added for OU BUG Issue 26-Mar-2015
                                           wsh_delivery_details wdd, wsh_delivery_assignments wda,
                   mtl_txn_request_lines mtrl
             WHERE     1 = 1
                   AND wda.delivery_id = p_order_number
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.released_status = 'S'
                   /* S means - Released to WMS Y means - Staged */
                   AND ool.line_id = wdd.source_line_id
                   AND ool.line_id = mtrl.txn_source_line_id
                   AND wdd.move_order_line_id = mtrl.line_id;

        lv_out_msg   VARCHAR2 (1000);
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Pick confirm Processing Delivery Number : ' || p_order_number);

        FOR del_rec IN c_del_dets
        LOOP
            pick_line (p_in_num_mo_line_id   => del_rec.mo_line_id,
                       p_in_txn_hdr_id       => del_rec.transaction_header_id,
                       p_out_msg             => lv_out_msg);
        END LOOP;

        IF lv_out_msg IS NOT NULL
        THEN
            p_out_msg   := lv_out_msg;
        ELSE
            p_out_msg   := '';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_msg   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                ' Error in pick_confirm routine: ' || p_out_msg || SQLERRM);
    END pick_confirm;

    PROCEDURE pick_line (p_in_num_mo_line_id IN NUMBER, p_in_txn_hdr_id IN NUMBER, p_out_msg OUT VARCHAR2)
    IS
        l_num_number_of_rows         NUMBER;
        l_num_detailed_qty           NUMBER;
        l_chr_return_status          VARCHAR2 (1);
        l_num_msg_count              NUMBER;
        l_chr_msg_data               VARCHAR2 (32767);
        l_num_revision               NUMBER;
        l_num_locator_id             NUMBER;
        l_num_transfer_to_location   NUMBER;
        l_num_lot_number             NUMBER;
        l_dte_expiration_date        DATE;
        l_num_transaction_temp_id    NUMBER;
        l_num_msg_cntr               NUMBER;
        l_msg_index_out              NUMBER;
        l_trolin_tbl                 inv_move_order_pub.trolin_tbl_type;
        l_mold_tbl                   inv_mo_line_detail_util.g_mmtt_tbl_type;
        l_mmtt_tbl                   inv_mo_line_detail_util.g_mmtt_tbl_type;
        o_trolin_tbl                 inv_move_order_pub.trolin_tbl_type;
        lv_out_msg                   VARCHAR2 (1000);
    BEGIN
        --Reset status variables
        g_chr_status_code   := '0';
        g_chr_status_msg    := '';
        -- Call standard oracle API to perform the allocation and transaction

        /* COMMIT_EACH_LINE - Start */
        --      fnd_file.put_line
        --                    (fnd_file.LOG,
        --                        'Calling  inv_replenish_detail_pub.line_details_pub '
        --                     || p_out_msg
        --                    );

        fnd_file.put_line (
            fnd_file.LOG,
               'Calling  inv_replenish_detail_pub.line_details_pub for move order line : '
            || p_in_num_mo_line_id);


        /* COMMIT_EACH_LINE - End */

        inv_replenish_detail_pub.line_details_pub (p_line_id => p_in_num_mo_line_id, x_number_of_rows => l_num_number_of_rows, x_detailed_qty => l_num_detailed_qty, x_return_status => l_chr_return_status, x_msg_count => l_num_msg_count, x_msg_data => l_chr_msg_data, x_revision => l_num_revision, x_locator_id => l_num_locator_id, x_transfer_to_location => l_num_transfer_to_location, x_lot_number => l_num_lot_number, x_expiration_date => l_dte_expiration_date, x_transaction_temp_id => l_num_transaction_temp_id, p_transaction_header_id => p_in_txn_hdr_id, p_transaction_mode => 1, p_move_order_type => inv_globals.g_move_order_pick_wave, p_serial_flag => NULL, p_plan_tasks => FALSE, p_auto_pick_confirm => FALSE
                                                   , p_commit => FALSE);
        fnd_file.put_line (fnd_file.LOG,
                           'Number of rows :' || l_num_number_of_rows);

        IF l_num_number_of_rows > 0
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Calling inv_pick_wave_pick_confirm_pub.pick_confirm '
                || p_out_msg);
            l_trolin_tbl   :=
                inv_trolin_util.query_rows (p_line_id => p_in_num_mo_line_id);
            inv_pick_wave_pick_confirm_pub.pick_confirm (
                p_api_version_number   => 1.0,
                p_init_msg_list        => fnd_api.g_false,
                p_commit               => fnd_api.g_true,
                x_return_status        => l_chr_return_status,
                x_msg_count            => l_num_msg_count,
                x_msg_data             => l_chr_msg_data,
                p_move_order_type      => 3,
                p_transaction_mode     => 1,                              --2,
                p_trolin_tbl           => l_trolin_tbl,
                p_mold_tbl             => l_mold_tbl,
                x_mmtt_tbl             => l_mmtt_tbl,
                x_trolin_tbl           => o_trolin_tbl,
                p_transaction_date     => SYSDATE --NULL  -- /* MOVE_ORDER_DATE*/
                                                 );

            IF l_chr_return_status <> fnd_api.g_ret_sts_success
            THEN
                g_chr_status_code   := '1';
                g_chr_status_msg    :=
                       'API to confirm picking failed with status: '
                    || l_chr_return_status;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'API to confirm picking failed with status:' || p_out_msg);
                fnd_file.put_line (fnd_file.LOG, g_chr_status_msg);
                lv_out_msg          := g_chr_status_msg;
                -- Retrieve messages
                l_num_msg_cntr      := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message: ' || l_chr_msg_data);
                    lv_out_msg       := lv_out_msg || l_chr_msg_data;
                END LOOP;
            ELSE
                g_chr_status_msg   :=
                       'API to confirm picking was successful with status: '
                    || l_chr_return_status;
                lv_out_msg   := '';
                --   retcode := 0;
                fnd_file.put_line (fnd_file.LOG, g_chr_status_msg);

                COMMIT;                                /* COMMIT_EACH_LINE  */
            END IF;
        ELSE
            g_chr_status_code   := '1';
            g_chr_status_msg    :=
                   'API to allocate and transact line completed with status: '
                || l_chr_return_status
                || '. Since number of rows is:'
                || l_num_number_of_rows
                || ', line cannot be picked.';
            lv_out_msg          := g_chr_status_msg;
            fnd_file.put_line (fnd_file.LOG, g_chr_status_msg);

            /* COMMIT_EACH_LINE  - Start*/
            l_num_msg_cntr      := 1;

            WHILE l_num_msg_cntr <= l_num_msg_count
            LOOP
                fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                 , p_msg_index_out => l_msg_index_out);
                l_num_msg_cntr   := l_num_msg_cntr + 1;
                fnd_file.put_line (fnd_file.LOG,
                                   'Error Message: ' || l_chr_msg_data);
                lv_out_msg       := lv_out_msg || l_chr_msg_data;
            END LOOP;
        /* COMMIT_EACH_LINE  - End*/


        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            g_chr_status_code   := '1';
            g_chr_status_msg    :=
                   'Error while picking move order line id '
                || p_in_num_mo_line_id
                || ': '
                || SQLERRM;
            lv_out_msg          := g_chr_status_msg;
            fnd_file.put_line (fnd_file.LOG, g_chr_status_msg);
    END pick_line;

    PROCEDURE clear_bucket (p_errbuf       OUT VARCHAR2,
                            p_retcode      OUT NUMBER,
                            del_txn_t   IN     tab_del_txn)
    IS
        l_num_txn_intf_id     NUMBER;
        l_exc_seq             EXCEPTION;
        l_chr_return_status   VARCHAR2 (1);
        l_num_msg_count       NUMBER;
        l_chr_msg_data        VARCHAR2 (32500);
        l_num_trans_count     NUMBER;
        l_num_return          NUMBER;
        l_num_process_flag    NUMBER := 0;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Starting Inventory Movement from Stage to Available...');

        -- SAVEPOINT Inventory_Transactions;
        FOR i IN 1 .. del_txn_t.COUNT
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                'Delivery detail ID: ' || del_txn_t (i).delivery_detail_id);
            fnd_file.put_line (
                fnd_file.LOG,
                'Transaction ID: ' || del_txn_t (i).transaction_id);

            -- Insert record in mtl_transactions_interface
            BEGIN
                SELECT mtl_material_transactions_s.NEXTVAL
                  INTO l_num_txn_intf_id
                  FROM DUAL;

                INSERT INTO mtl_transactions_interface (transaction_interface_id, transaction_header_id, source_code, source_header_id, source_line_id, process_flag, transaction_mode, creation_date, created_by, last_update_date, last_updated_by, inventory_item_id, organization_id, transaction_quantity, transaction_uom, transaction_date, subinventory_code, loc_segment1, transaction_type_id, transfer_organization, transfer_subinventory
                                                        , xfer_loc_segment1)
                    SELECT l_num_txn_intf_id, g_num_request_id, 'WMS',
                           g_num_request_id, g_num_request_id, 1,
                           3, SYSDATE, g_num_user_id,
                           SYSDATE, g_num_user_id, mmt.inventory_item_id,
                           mmt.organization_id, wdd.requested_quantity, mmt.transaction_uom,
                           SYSDATE, mmt.transfer_subinventory, mmt.transfer_locator_id,
                           2, mmt.organization_id, mmt.subinventory_code,
                           mmt.locator_id
                      FROM mtl_material_transactions mmt, wsh_delivery_details wdd
                     WHERE     wdd.delivery_detail_id =
                               del_txn_t (i).delivery_detail_id
                           AND mmt.transaction_id =
                               del_txn_t (i).transaction_id
                           AND mmt.subinventory_code <>
                               mmt.transfer_subinventory;

                l_num_process_flag   := 1;
                msg (
                       'Data related to Transactions '
                    || del_txn_t (i).transaction_id);
                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        IF l_num_process_flag = 1
        THEN
            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                'Calling API to process inventory transactions... ');
            l_num_return   :=
                apps.inv_txn_manager_pub.process_transactions (
                    p_api_version     => 1.0,
                    p_commit          => fnd_api.g_false,
                    x_return_status   => l_chr_return_status,
                    x_msg_count       => l_num_msg_count,
                    x_msg_data        => l_chr_msg_data,
                    x_trans_count     => l_num_trans_count,
                    p_table           => 1,
                    p_header_id       => g_num_request_id);

            IF l_chr_return_status = 'S'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Inventory Transaction API completed successfully with status: '
                    || l_chr_return_status);
                p_retcode   := 0;
                p_errbuf    :=
                       'Inventory Transaction API completed successfully with status: '
                    || l_chr_return_status;
                COMMIT;
            ELSE
                -- Retrieve messages
                FOR i IN 1 .. l_num_msg_count
                LOOP
                    l_chr_msg_data   := fnd_msg_pub.get (i, 'F');
                    msg ('Error Due to message' || l_chr_msg_data);
                END LOOP;

                --  ROLLBACK to Inventory_Transactions;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Inventory Transaction API failed with status: '
                    || l_chr_return_status);
                p_retcode   := '1';
                p_errbuf    :=
                       'Inventory Transaction API failed with status: '
                    || l_chr_return_status;
            END IF;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'There are no item quantity in Stage Bucket to move back to Available Bucket.');
        END IF;
    --     END IF;
    EXCEPTION
        WHEN l_exc_seq
        THEN
            p_retcode   := 2;
            p_errbuf    := SQLERRM;
        WHEN OTHERS
        THEN
            p_retcode   := 2;
            p_errbuf    := SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Unexpected error: ' || SQLERRM);
    END clear_bucket;

    PROCEDURE pick_orders
    IS
        CURSOR c_pick_order IS
            SELECT DISTINCT order_number
              FROM xxdo_ont_pick_status_order
             WHERE request_id = g_num_request_id AND status = 'PACKED';

        l_num_count     NUMBER := 0;
        l_num_count2    NUMBER := 0;
        l_chr_err_msg   VARCHAR2 (30000);
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start of Pick Orders'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        FOR c_pick_rec IN c_pick_order
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                'Processing delivery:' || c_pick_rec.order_number);

            /* check if any lines in this delivery are eligible for pick confirmation */
            BEGIN
                SELECT COUNT (1)
                  INTO l_num_count
                  FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
                 WHERE     wda.delivery_id = c_pick_rec.order_number
                       AND wdd.delivery_detail_id = wda.delivery_detail_id
                       AND wdd.released_status = 'S';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_num_count   := 0;
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Eligible lines for for pick confirm in this delivery:'
                || l_num_count);
            l_chr_err_msg   := NULL;

            IF l_num_count = 0
            THEN
                UPDATE xxdo_ont_pick_status_order
                   SET process_status = 'PROCESSED', error_msg = 'No eligible lines'
                 WHERE     request_id = g_num_request_id
                       AND status = 'PACKED'
                       AND process_status = 'INPROCESS'
                       AND order_number = c_pick_rec.order_number;
            ELSE
                pick_confirm (c_pick_rec.order_number, l_chr_err_msg);

                BEGIN
                    SELECT COUNT (1)
                      INTO l_num_count2
                      FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
                     WHERE     wda.delivery_id = c_pick_rec.order_number
                           AND wdd.delivery_detail_id =
                               wda.delivery_detail_id
                           AND wdd.released_status IN ('S', 'B');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_num_count2   := 0;
                END;

                IF l_num_count2 = 0
                THEN
                    UPDATE xxdo_ont_pick_status_order
                       SET process_status   = 'PROCESSED'
                     WHERE     request_id = g_num_request_id
                           AND status = 'PACKED'
                           AND process_status = 'INPROCESS'
                           AND order_number = c_pick_rec.order_number;
                ELSE
                    UPDATE xxdo_ont_pick_status_order
                       SET process_status = 'ERROR', error_msg = l_num_count2 || ' lines did not get picked'
                     WHERE     request_id = g_num_request_id
                           AND status = 'PACKED'
                           AND process_status = 'INPROCESS'
                           AND order_number = c_pick_rec.order_number;
                END IF;
            END IF;

            COMMIT;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'End of Pick Orders'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error in Pick Orders: ' || SQLERRM);
    END pick_orders;

    PROCEDURE ship_orders
    IS
        CURSOR c_ship_order IS
            SELECT DISTINCT order_number
              FROM xxdo_ont_pick_status_order
             WHERE request_id = g_num_request_id AND status = 'SHIPPED';

        l_num_count          NUMBER := 0;
        l_num_count1         NUMBER := 0;
        l_chr_err_msg        VARCHAR2 (30000);
        l_chr_retcode        VARCHAR2 (100);
        l_num_cancel_count   NUMBER := 0;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start of Ship Orders'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        /*Updating Status to PROCESSED for Orders with NO Open shipping lines - ORDER_NO_OPEN_SHIP_LN - BEGIN*/
        BEGIN
            UPDATE apps.xxdo_ont_pick_status_order ordstatus
               SET process_status = 'PROCESSED', error_msg = NULL
             WHERE     1 = 1
                   AND process_status = 'INPROCESS'
                   AND status = 'SHIPPED'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd, wsh_new_deliveries wnd
                             WHERE     1 = 1
                                   AND wdd.released_status IN ('S', 'Y')
                                   AND wnd.delivery_id = wdd.attribute11
                                   AND wnd.status_code = 'CL'
                                   AND wnd.delivery_id =
                                       ordstatus.order_number);

            fnd_file.put_line (
                fnd_file.LOG,
                   'No:of records with (SHIPPED status) updated to PROCESSED status : '
                || SQL%ROWCOUNT);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unexpected error while Updating Order Status to PROCESSED :'
                    || SQLERRM);
        END;

        /*ORDER_NO_OPEN_SHIP_LN - END*/

        FOR c_ship_rec IN c_ship_order
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                'Processing delivery:' || c_ship_rec.order_number);

            /* check if any unprocessed /errored ship confirms exists - if yes dont process shipped message */
            /*BEGIN CANCEL_SHIP*/
            BEGIN
                l_num_cancel_count   := 0;

                SELECT COUNT (1)
                  INTO l_num_cancel_count
                  FROM xxdo_ont_pick_status_order
                 WHERE     order_number = c_ship_rec.order_number
                       AND status = 'CANCEL'
                       AND process_status = 'PROCESSED';



                fnd_file.put_line (
                    fnd_file.LOG,
                    'Cancel Message count :' || l_num_cancel_count);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_num_cancel_count   := -1;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while Cancel Message Count :'
                        || SQLERRM);
            END;

            IF l_num_cancel_count = 1
            THEN
                UPDATE xxdo_ont_pick_status_order
                   SET process_status = 'PROCESSED', error_msg = l_num_cancel_count || ' Cancel messgaes are processed, hence not required for Ship Message Processing'
                 WHERE     request_id = g_num_request_id
                       AND status = 'SHIPPED'
                       AND order_number = c_ship_rec.order_number
                       AND process_status <> 'PROCESSED';

                COMMIT;
            END IF;

            /*ENDS  CANCEL_SHIP*/
            IF l_num_cancel_count <> 1
            THEN
                BEGIN
                    SELECT COUNT (1)
                      INTO l_num_count
                      FROM xxdo_ont_ship_conf_order_stg
                     WHERE     order_number = c_ship_rec.order_number
                           AND process_status <> 'PROCESSED';

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unprocessed /error shipment line count :'
                        || l_num_count);

                    SELECT COUNT (1)
                      INTO l_num_count1
                      FROM xxdo_ont_ship_conf_order_stg
                     WHERE     order_number = c_ship_rec.order_number
                           AND process_status = 'PROCESSED';

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Processed shipment line count :' || l_num_count1);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Unexpected error while checking shipment count :'
                            || SQLERRM);
                END;

                IF l_num_count > 0
                THEN
                    UPDATE xxdo_ont_pick_status_order
                       SET process_status = 'ERROR', error_msg = l_num_count || ' shipment lines are either unprocessed /errored'
                     WHERE     request_id = g_num_request_id
                           AND status = 'SHIPPED'
                           AND order_number = c_ship_rec.order_number;
                ELSIF l_num_count1 = 0
                THEN
                    UPDATE xxdo_ont_pick_status_order
                       SET process_status = 'ERROR', error_msg = ' No shipments are processed for this delivery'
                     WHERE     request_id = g_num_request_id
                           AND status = 'SHIPPED'
                           AND order_number = c_ship_rec.order_number;
                ELSE
                    back_order (l_chr_err_msg,
                                l_chr_retcode,
                                c_ship_rec.order_number);
                    l_num_count   := 0;

                    BEGIN
                        SELECT COUNT (1)
                          INTO l_num_count
                          FROM wsh_delivery_details wdd, wsh_new_deliveries wnd
                         WHERE     1 = 1
                               AND wdd.released_status IN ('S', 'Y')
                               AND wnd.delivery_id = wdd.attribute11
                               AND wnd.status_code = 'CL'
                               AND wnd.delivery_id = c_ship_rec.order_number;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_num_count   := 0;
                    END;

                    IF l_num_count = 0
                    THEN
                        UPDATE xxdo_ont_pick_status_order
                           SET process_status = 'PROCESSED', error_msg = NULL
                         WHERE     request_id = g_num_request_id
                               AND status = 'SHIPPED'
                               AND process_status = 'INPROCESS'
                               AND order_number = c_ship_rec.order_number;
                    ELSE
                        UPDATE xxdo_ont_pick_status_order
                           SET process_status = 'ERROR', error_msg = l_num_count || ' delivery details are in released / staged status'
                         WHERE     request_id = g_num_request_id
                               AND status = 'SHIPPED'
                               AND process_status = 'INPROCESS'
                               AND order_number = c_ship_rec.order_number;
                    END IF;
                END IF;

                COMMIT;
            END IF;                     -- End if for  l_num_cancel_count <> 1
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'End of Ship Orders'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error in Ship Orders: ' || SQLERRM);
    END ship_orders;

    PROCEDURE cancel_orders
    IS
        CURSOR c_cancel_order IS
            SELECT DISTINCT order_number
              FROM xxdo_ont_pick_status_order
             WHERE request_id = g_num_request_id AND status = 'CANCEL';

        l_num_count     NUMBER := 0;
        l_num_count1    NUMBER := 0;
        l_chr_err_msg   VARCHAR2 (30000);
        l_chr_retcode   VARCHAR2 (100);
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start of Cancel Orders'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        FOR c_cancel_rec IN c_cancel_order
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                'Processing delivery:' || c_cancel_rec.order_number);

            BEGIN
                l_num_count   := 0;

                SELECT COUNT (1)
                  INTO l_num_count
                  FROM wsh_new_deliveries wnd
                 WHERE     wnd.delivery_id =
                           TO_NUMBER (c_cancel_rec.order_number)
                       AND status_code = 'OP';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_num_count   := 0;
            END;

            IF l_num_count = 0
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Delivery is in closed status');

                UPDATE xxdo_ont_pick_status_order
                   SET process_status = 'ERROR', error_msg = ' Cannot cancel as delivery is in closed status'
                 WHERE     request_id = g_num_request_id
                       AND status = 'CANCEL'
                       AND order_number = c_cancel_rec.order_number;
            ELSE
                l_num_count     := 0;

                /* check if any lines in this delivery are eligible for pick confirmation */
                BEGIN
                    SELECT COUNT (1)
                      INTO l_num_count
                      FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
                     WHERE     wda.delivery_id = c_cancel_rec.order_number
                           AND wdd.delivery_detail_id =
                               wda.delivery_detail_id
                           AND wdd.released_status = 'S';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_num_count   := 0;
                END;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Eligible lines for for pick confirm in this delivery:'
                    || l_num_count);
                l_chr_err_msg   := NULL;

                IF l_num_count > 0
                THEN
                    pick_confirm (c_cancel_rec.order_number, l_chr_err_msg);
                END IF;                       /* pick confirmation required */

                cancel_delivery (l_chr_retcode,
                                 l_chr_err_msg,
                                 c_cancel_rec.order_number);
                l_num_count     := 0;

                BEGIN
                    SELECT COUNT (1)
                      INTO l_num_count
                      FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
                     WHERE     wda.delivery_id = c_cancel_rec.order_number
                           AND wdd.delivery_detail_id =
                               wda.delivery_detail_id
                           AND wdd.released_status IN ('S', 'Y');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_num_count   := 0;
                END;

                IF l_num_count = 0
                THEN
                    UPDATE xxdo_ont_pick_status_order
                       SET process_status = 'PROCESSED', error_msg = NULL
                     WHERE     request_id = g_num_request_id
                           AND status = 'CANCEL'
                           AND process_status = 'INPROCESS'
                           AND order_number = c_cancel_rec.order_number;
                ELSE
                    UPDATE xxdo_ont_pick_status_order
                       SET process_status = 'ERROR', error_msg = l_num_count || ' delivery details are either in released or staged status'
                     WHERE     request_id = g_num_request_id
                           AND status = 'CANCEL'
                           AND process_status = 'INPROCESS'
                           AND order_number = c_cancel_rec.order_number;
                END IF;
            END IF;

            /* delivery is Open */
            COMMIT;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'End of Cancel Orders'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error in cancel Orders: ' || SQLERRM);
    END cancel_orders;

    PROCEDURE set_in_process (p_retcode OUT NUMBER, p_error_buf OUT VARCHAR2, p_organization_code VARCHAR2
                              , p_order_number VARCHAR2)
    IS
    BEGIN
        p_error_buf   := NULL;
        p_retcode     := '0';

        UPDATE xxdo_ont_pick_status_order
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id, last_update_date = SYSDATE
         WHERE     order_number = NVL (p_order_number, order_number)
               AND wh_id = NVL (p_organization_code, wh_id)
               AND process_status = 'NEW'
               AND request_id IS NULL
               AND (g_num_shipped_mode = 'Y' OR (status <> 'SHIPPED' AND g_num_shipped_mode = 'N'))
               AND wh_id IN
                       (SELECT lookup_code
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXONT_WMS_WHSE'
                               AND NVL (LANGUAGE, USERENV ('LANG')) =
                                   USERENV ('LANG')
                               AND enabled_flag = 'Y');

        fnd_file.put_line (
            fnd_file.LOG,
               'No of rows updated  from XXDO_ONT_PICK_STATUS_ORDER  to INPROCESS '
            || SQL%ROWCOUNT);
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error_buf   := SQLERRM;
            p_retcode     := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected Error in Set_on_process:' || p_error_buf);
    END set_in_process;

    PROCEDURE insert_pick_data (p_wh_id            IN VARCHAR2,
                                p_order_num        IN VARCHAR2,
                                p_date             IN DATE,
                                p_status           IN VARCHAR2,
                                p_shipment_num     IN VARCHAR2,
                                p_ship_status      IN VARCHAR2,
                                p_cmt_load         IN VARCHAR2,
                                p_shipment_num1    IN VARCHAR2,
                                p_mst_load1        IN VARCHAR2,
                                p_cmt_ship1        IN VARCHAR2,
                                p_shipment_num2    IN VARCHAR2,
                                p_mst_load2        IN VARCHAR2,
                                p_cmt_ship2        IN VARCHAR2,
                                p_shipment_num3    IN VARCHAR2,
                                p_mst_load3        IN VARCHAR2,
                                p_cmt_ship3        IN VARCHAR2,
                                p_shipment_num4    IN VARCHAR2,
                                p_mst_load4        IN VARCHAR2,
                                p_cmt_ship4        IN VARCHAR2,
                                p_shipment_num5    IN VARCHAR2,
                                p_mst_load5        IN VARCHAR2,
                                p_cmt_ship5        IN VARCHAR2,
                                p_shipment_num6    IN VARCHAR2,
                                p_mst_load6        IN VARCHAR2,
                                p_cmt_ship6        IN VARCHAR2,
                                p_shipment_num7    IN VARCHAR2,
                                p_mst_load7        IN VARCHAR2,
                                p_cmt_ship7        IN VARCHAR2,
                                p_shipment_num8    IN VARCHAR2,
                                p_mst_load8        IN VARCHAR2,
                                p_cmt_ship8        IN VARCHAR2,
                                p_shipment_num9    IN VARCHAR2,
                                p_mst_load9        IN VARCHAR2,
                                p_cmt_ship9        IN VARCHAR2,
                                p_shipment_num10   IN VARCHAR2,
                                p_mst_load10       IN VARCHAR2,
                                p_cmt_ship10       IN VARCHAR2,
                                p_message_id       IN VARCHAR2 -- added as part of CCR0010172
                                                              )
    IS
        l_chr_error_message   VARCHAR2 (2000);
    BEGIN
        INSERT INTO xxdo_ont_pick_status_order (wh_id,
                                                order_number,
                                                tran_date,
                                                status,
                                                shipment_number,
                                                shipment_status,
                                                comments,
                                                created_by,
                                                creation_date,
                                                last_updated_by,
                                                last_update_date,
                                                last_update_login,
                                                process_status,
                                                record_type,
                                                message_id -- added as part of CCR0010172
                                                          )
             VALUES (p_wh_id, p_order_num, p_date,
                     p_status, p_shipment_num, p_ship_status,
                     p_cmt_load, fnd_global.user_id, SYSDATE,
                     fnd_global.user_id, SYSDATE, fnd_global.login_id,
                     'NEW', 'INSERT', p_message_id -- added as part of CCR0010172
                                                  );

        IF p_shipment_num1 IS NOT NULL
        THEN
            INSERT INTO xxdo_ont_pick_status_load
                 VALUES (p_wh_id, p_order_num, p_shipment_num1,
                         p_mst_load1, p_cmt_ship1, fnd_global.user_id,
                         SYSDATE, fnd_global.user_id, SYSDATE,
                         fnd_global.login_id, 'NEW', 'INSERT');
        END IF;

        IF p_shipment_num2 IS NOT NULL
        THEN
            INSERT INTO xxdo_ont_pick_status_load
                 VALUES (p_wh_id, p_order_num, p_shipment_num2,
                         p_mst_load2, p_cmt_ship2, fnd_global.user_id,
                         SYSDATE, fnd_global.user_id, SYSDATE,
                         fnd_global.login_id, 'NEW', 'INSERT');
        END IF;

        IF p_shipment_num3 IS NOT NULL
        THEN
            INSERT INTO xxdo_ont_pick_status_load
                 VALUES (p_wh_id, p_order_num, p_shipment_num3,
                         p_mst_load3, p_cmt_ship3, fnd_global.user_id,
                         SYSDATE, fnd_global.user_id, SYSDATE,
                         fnd_global.login_id, 'NEW', 'INSERT');
        END IF;

        IF p_shipment_num4 IS NOT NULL
        THEN
            INSERT INTO xxdo_ont_pick_status_load
                 VALUES (p_wh_id, p_order_num, p_shipment_num4,
                         p_mst_load4, p_cmt_ship4, fnd_global.user_id,
                         SYSDATE, fnd_global.user_id, SYSDATE,
                         fnd_global.login_id, 'NEW', 'INSERT');
        END IF;

        IF p_shipment_num5 IS NOT NULL
        THEN
            INSERT INTO xxdo_ont_pick_status_load
                 VALUES (p_wh_id, p_order_num, p_shipment_num5,
                         p_mst_load5, p_cmt_ship5, fnd_global.user_id,
                         SYSDATE, fnd_global.user_id, SYSDATE,
                         fnd_global.login_id, 'NEW', 'INSERT');
        END IF;

        IF p_shipment_num6 IS NOT NULL
        THEN
            INSERT INTO xxdo_ont_pick_status_load
                 VALUES (p_wh_id, p_order_num, p_shipment_num6,
                         p_mst_load6, p_cmt_ship6, fnd_global.user_id,
                         SYSDATE, fnd_global.user_id, SYSDATE,
                         fnd_global.login_id, 'NEW', 'INSERT');
        END IF;

        IF p_shipment_num7 IS NOT NULL
        THEN
            INSERT INTO xxdo_ont_pick_status_load
                 VALUES (p_wh_id, p_order_num, p_shipment_num7,
                         p_mst_load7, p_cmt_ship7, fnd_global.user_id,
                         SYSDATE, fnd_global.user_id, SYSDATE,
                         fnd_global.login_id, 'NEW', 'INSERT');
        END IF;

        IF p_shipment_num8 IS NOT NULL
        THEN
            INSERT INTO xxdo_ont_pick_status_load
                 VALUES (p_wh_id, p_order_num, p_shipment_num8,
                         p_mst_load8, p_cmt_ship8, fnd_global.user_id,
                         SYSDATE, fnd_global.user_id, SYSDATE,
                         fnd_global.login_id, 'NEW', 'INSERT');
        END IF;

        IF p_shipment_num9 IS NOT NULL
        THEN
            INSERT INTO xxdo_ont_pick_status_load
                 VALUES (p_wh_id, p_order_num, p_shipment_num9,
                         p_mst_load9, p_cmt_ship9, fnd_global.user_id,
                         SYSDATE, fnd_global.user_id, SYSDATE,
                         fnd_global.login_id, 'NEW', 'INSERT');
        END IF;

        IF p_shipment_num10 IS NOT NULL
        THEN
            INSERT INTO xxdo_ont_pick_status_load
                 VALUES (p_wh_id, p_order_num, p_shipment_num10,
                         p_mst_load10, p_cmt_ship10, fnd_global.user_id,
                         SYSDATE, fnd_global.user_id, SYSDATE,
                         fnd_global.login_id, 'NEW', 'INSERT');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            --      l_chr_error_message := SQLERRM;
            --      insert into order_status_debug values( 'Unhandled Exception : '|| l_chr_error_message , SYSDATE);
            --      commit;
            NULL;
    END insert_pick_data;


    PROCEDURE mail_hold_report (p_out_chr_errbuf    OUT VARCHAR2,
                                p_out_chr_retcode   OUT VARCHAR2)
    IS
        l_rid_lookup_rec_rowid     ROWID;
        l_chr_from_mail_id         VARCHAR2 (2000);
        l_chr_to_mail_ids          VARCHAR2 (2000);

        l_num_return_value         NUMBER;
        l_chr_header_sent          VARCHAR2 (1) := 'N';
        l_chr_instance             VARCHAR2 (60);

        l_exe_bulk_fetch_failed    EXCEPTION;
        l_exe_no_interface_setup   EXCEPTION;
        l_exe_mail_error           EXCEPTION;
        l_exe_instance_not_known   EXCEPTION;


        CURSOR cur_error_records IS
              SELECT wh_id, order_number, tran_date,
                     status, shipment_number
                FROM xxdo_ont_pick_status_order
               WHERE     request_id = g_num_request_id
                     AND status IN
                             ('EBSRELEASE_FAIL', 'CANCEL_FAIL', 'EBSHOLD_FAIL')
            ORDER BY wh_id, order_number, tran_date;


        TYPE l_error_records_tab_type IS TABLE OF cur_error_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_error_records_tab        l_error_records_tab_type;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, '');

        --g_num_request_id := 100;

        BEGIN
            SELECT instance_name INTO l_chr_instance FROM v$instance;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE l_exe_instance_not_known;
        END;


        -- Derive the last report run time, FROM email id and TO email ids
        BEGIN
            SELECT flv.ROWID, flv.attribute10, flv.attribute11
              INTO l_rid_lookup_rec_rowid, l_chr_from_mail_id, l_chr_to_mail_ids
              FROM fnd_lookup_values flv
             WHERE     flv.language = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = g_chr_order_status_prgm_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Unable to get the inteface setup due to ' || SQLERRM);
                RAISE l_exe_no_interface_setup;
        END;

        -- Convert the FROM email id instance specific
        IF l_chr_from_mail_id IS NULL
        THEN
            l_chr_from_mail_id   := 'WMSInterfacesErrorReporting@deckers.com';
        END IF;

        -- Replace comma with semicolon in TO Ids

        l_chr_to_mail_ids   := TRANSLATE (l_chr_to_mail_ids, ',', ';');


        -- Logic to send the error records
        OPEN cur_error_records;

        LOOP
            IF l_error_records_tab.EXISTS (1)
            THEN
                l_error_records_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_error_records
                    BULK COLLECT INTO l_error_records_tab
                    LIMIT 1000;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_error_records;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Order Hold records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_error_records_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF l_chr_header_sent = 'N'
            THEN
                send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_instance || ' - EBS Orders Hold Application / Release / Cancel Failures'
                                  , l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   := 'Unable to send the mail header';
                    RAISE l_exe_mail_error;
                END IF;

                send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/plain',
                                l_num_return_value);

                send_mail_line ('', l_num_return_value);
                send_mail_line (
                       'EBS Hold application / release / cancel was not successful for the following orders in  '
                    || l_chr_instance
                    || ':',
                    l_num_return_Value);
                send_mail_line ('', l_num_return_value);

                send_mail_line (
                       'Warehouse'
                    || CHR (9)
                    || 'Order Number'
                    || CHR (9)
                    || 'Transaction Date'
                    || CHR (9)
                    || CHR (9)
                    || 'Status'
                    || CHR (9)
                    || CHR (9)
                    || 'Shipment Number'
                    || CHR (9),
                    l_num_return_value);

                --                   send_mail_line('', l_num_return_value);

                l_chr_header_sent   := 'Y';
            END IF;

            FOR l_num_ind IN l_error_records_tab.FIRST ..
                             l_error_records_tab.LAST
            LOOP
                send_mail_line (
                       l_error_records_tab (l_num_ind).wh_id
                    || CHR (9)
                    || CHR (9)
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).order_number
                    || CHR (9)
                    || TO_CHAR (l_error_records_tab (l_num_ind).tran_date,
                                'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).status
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).shipment_number
                    || CHR (9),
                    l_num_return_value);
            END LOOP;
        END LOOP;                                  -- Error headers fetch loop

        -- Close the cursor
        CLOSE cur_error_records;

        --       send_mail_line('', l_num_return_value);
        --      send_mail_line('--boundarystring', l_num_return_value);

        -- Close the mail connection
        send_mail_close (l_num_return_value);

        IF l_num_return_value <> 0
        THEN
            p_out_chr_errbuf   := 'Unable to close the mail connection';
            RAISE l_exe_mail_error;
        END IF;
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_errbuf    :=
                'No Interface setup to generate RMA Request hold report';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_instance_not_known
        THEN
            p_out_chr_errbuf    :=
                'Unable to derive the instance at mail hold report procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_errbuf    :=
                'Bulk fetch failed at mail hold report procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at mail hold report report procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END mail_hold_report;

    PROCEDURE send_mail_header (p_in_chr_msg_from IN VARCHAR2, p_in_chr_msg_to IN VARCHAR2, p_in_chr_msg_subject IN VARCHAR2
                                , p_out_num_status OUT NUMBER)
    IS
        l_num_status              NUMBER := 0;
        l_chr_msg_to              VARCHAR2 (2000) := NULL;
        l_chr_mail_temp           VARCHAR2 (2000) := NULL;
        l_chr_mail_id             VARCHAR2 (255);
        l_num_counter             NUMBER := 0;
        l_exe_conn_already_open   EXCEPTION;
    BEGIN
        IF g_num_connection_flag <> 0
        THEN
            RAISE l_exe_conn_already_open;
        END IF;

        g_smtp_connection       := UTL_SMTP.open_connection ('127.0.0.1');
        g_num_connection_flag   := 1;
        l_num_status            := 1;
        UTL_SMTP.helo (g_smtp_connection, 'localhost');
        UTL_SMTP.mail (g_smtp_connection, p_in_chr_msg_from);


        l_chr_mail_temp         := TRIM (p_in_chr_msg_to);

        IF (INSTR (l_chr_mail_temp, ';', 1) = 0)
        THEN
            l_chr_mail_id   := l_chr_mail_temp;
            fnd_file.put_line (fnd_file.LOG,
                               CHR (10) || 'Email ID: ' || l_chr_mail_id);
            UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
        ELSE
            WHILE (LENGTH (l_chr_mail_temp) > 0)
            LOOP
                IF (INSTR (l_chr_mail_temp, ';', 1) = 0)
                THEN
                    -- Last Mail ID
                    l_chr_mail_id   := l_chr_mail_temp;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        CHR (10) || 'Email ID: ' || l_chr_mail_id);
                    UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
                    EXIT;
                ELSE
                    -- Next Mail ID
                    l_chr_mail_id   :=
                        TRIM (
                            SUBSTR (l_chr_mail_temp,
                                    1,
                                    INSTR (l_chr_mail_temp, ';', 1) - 1));
                    fnd_file.put_line (
                        fnd_file.LOG,
                        CHR (10) || 'Email ID: ' || l_chr_mail_id);
                    UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
                END IF;

                l_chr_mail_temp   :=
                    TRIM (
                        SUBSTR (l_chr_mail_temp,
                                INSTR (l_chr_mail_temp, ';', 1) + 1,
                                LENGTH (l_chr_mail_temp)));
            END LOOP;
        END IF;


        l_chr_msg_to            :=
            '  ' || TRANSLATE (TRIM (p_in_chr_msg_to), ';', ' ');


        UTL_SMTP.open_data (g_smtp_connection);
        l_num_status            := 2;
        UTL_SMTP.write_data (g_smtp_connection,
                             'To: ' || l_chr_msg_to || UTL_TCP.CRLF);
        UTL_SMTP.write_data (g_smtp_connection,
                             'From: ' || p_in_chr_msg_from || UTL_TCP.CRLF);
        UTL_SMTP.write_data (
            g_smtp_connection,
            'Subject: ' || p_in_chr_msg_subject || UTL_TCP.CRLF);

        p_out_num_status        := 0;
    EXCEPTION
        WHEN l_exe_conn_already_open
        THEN
            p_out_num_status   := -2;
        WHEN OTHERS
        THEN
            IF l_num_status = 2
            THEN
                UTL_SMTP.close_data (g_smtp_connection);
            END IF;

            IF l_num_status > 0
            THEN
                UTL_SMTP.quit (g_smtp_connection);
            END IF;

            g_num_connection_flag   := 0;
            p_out_num_status        := -255;
    END send_mail_header;


    PROCEDURE send_mail_line (p_in_chr_msg_text   IN     VARCHAR2,
                              p_out_num_status       OUT NUMBER)
    IS
        l_exe_not_connected   EXCEPTION;
    BEGIN
        IF g_num_connection_flag = 0
        THEN
            RAISE l_exe_not_connected;
        END IF;

        UTL_SMTP.write_data (g_smtp_connection,
                             p_in_chr_msg_text || UTL_TCP.CRLF);

        p_out_num_status   := 0;
    EXCEPTION
        WHEN l_exe_not_connected
        THEN
            p_out_num_status   := -2;
        WHEN OTHERS
        THEN
            p_out_num_status   := -255;
    END send_mail_line;

    PROCEDURE send_mail_close (p_out_num_status OUT NUMBER)
    IS
        l_exe_not_connected   EXCEPTION;
    BEGIN
        IF g_num_connection_flag = 0
        THEN
            RAISE l_exe_not_connected;
        END IF;

        UTL_SMTP.close_data (g_smtp_connection);
        UTL_SMTP.quit (g_smtp_connection);

        g_num_connection_flag   := 0;
        p_out_num_status        := 0;
    EXCEPTION
        WHEN l_exe_not_connected
        THEN
            p_out_num_status   := 0;
        WHEN OTHERS
        THEN
            p_out_num_status        := -255;
            g_num_connection_flag   := 0;
    END send_mail_close;



    --------------------------------------------------------------------------------
    -- Procedure  : main_validate
    -- Description: Procedure will be called to perform various validations on
    --              different message status.
    --------------------------------------------------------------------------------
    PROCEDURE main_validate (errbuf             OUT VARCHAR2,
                             retcode            OUT NUMBER,
                             p_wh_code       IN     VARCHAR2,
                             p_order_num     IN     VARCHAR2,
                             p_source        IN     VARCHAR2 DEFAULT 'WMS',
                             p_destination   IN     VARCHAR2 DEFAULT 'EBS',
                             p_purge_days    IN     NUMBER DEFAULT 30,
                             p_status        IN     VARCHAR2)
    IS
        --------------------------
        --Declare local variables
        --------------------------
        lv_operation_name   VARCHAR2 (200);
        lv_errbuf           VARCHAR2 (1000);
        lv_retcode          NUMBER;
        v_message           VARCHAR2 (200);
        lv_return_code      VARCHAR2 (1);
    BEGIN
        IF NVL (p_status, 'X') = 'SHIP'
        THEN
            g_num_shipped_mode   := 'Y';
        ELSE
            g_num_shipped_mode   := 'N';
        END IF;

        -----------------------------------------------------------------
        lv_operation_name   := 'Writing to log file';
        -----------------------------------------------------------------
        fnd_file.put_line (
            fnd_file.LOG,
            'Pick Ticket: ' || p_order_num || TO_CHAR (SYSDATE));
        fnd_file.put_line (fnd_file.LOG,
                           'Source :' || p_source || TO_CHAR (SYSDATE));
        fnd_file.put_line (
            fnd_file.LOG,
            'Destination: ' || p_destination || TO_CHAR (SYSDATE));
        fnd_file.put_line (
            fnd_file.LOG,
            'Purge Days: ' || p_purge_days || TO_CHAR (SYSDATE));
        -------------------------------------------------
        lv_operation_name   := 'Purging the older data  ';
        fnd_file.put_line (fnd_file.LOG, 'Purging Data');

        -------------------------------------------------
        ----------------------------------------------------------------
        /* Delete archive and purge data from staging tables */
        /*Start of PURGE_ARCHIVE*/
        purge_archive (lv_retcode, lv_errbuf, p_purge_days);
        /*End of PURGE_ARCHIVE*/

        -------------------------------------------------
        lv_operation_name   := 'loop through the cursor  ';
        -------------------------------------------------
        fnd_file.put_line (fnd_file.LOG, 'Purging Data completed');
        set_in_process (lv_retcode, lv_errbuf, p_wh_code,
                        p_order_num);

        /*
        for each record in current run, check if any previous statuses need to be auto inserted -
        if yes - insert them in INPROCESS status. Previous statuses will be inserted only if
        they don't exist in status table
        */
        INSERT INTO xxdo_ont_pick_status_order (wh_id,
                                                order_number,
                                                tran_date,
                                                status,
                                                comments,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_updated_by,
                                                last_update_login,
                                                process_status,
                                                record_type,
                                                SOURCE,
                                                destination,
                                                request_id)
            SELECT DISTINCT xop.wh_id, xop.order_number, xop.tran_date,
                            flv2.meaning, 'AUTOINSERT', SYSDATE,
                            g_num_user_id, SYSDATE, g_num_user_id,
                            g_num_login_id, 'INPROCESS', 'INSERT',
                            xop.SOURCE, xop.destination, g_num_request_id
              FROM fnd_lookup_values flv1, xxdo_ont_pick_status_order xop, fnd_lookup_values flv2
             WHERE     xop.request_id = g_num_request_id
                   AND flv1.lookup_type = 'XXDO_WMS_ORDER_STATUSES'
                   AND flv1.LANGUAGE = 'US'
                   AND flv1.enabled_flag = 'Y'
                   AND xop.status = flv1.meaning
                   AND flv2.lookup_type = 'XXDO_WMS_ORDER_STATUSES'
                   AND flv2.LANGUAGE = 'US'
                   AND flv2.enabled_flag = 'Y'
                   AND flv2.description = 'NORMAL'
                   AND TO_NUMBER (flv2.lookup_code) <
                       TO_NUMBER (flv1.lookup_code)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo_ont_pick_status_order xop2
                             WHERE     xop2.order_number = xop.order_number
                                   AND xop2.status = flv2.meaning);

        fnd_file.put_line (fnd_file.LOG,
                           'No of rows auto inserted :' || SQL%ROWCOUNT);

        /* for all below statuses no processing is requred hence they can be marked as processed */
        UPDATE xxdo_ont_pick_status_order
           SET process_status   = 'PROCESSED'
         WHERE     request_id = g_num_request_id
               AND status IN ('NEW', 'WAVED', 'PACKING',
                              'EBSHOLD', 'EBSRELEASE');

        /*Updating the records as PROCESSED if any of the hold fails*/
        UPDATE xxdo_ont_pick_status_order
           SET process_status = 'PROCESSED', error_msg = DECODE (status,  'EBSRELEASE_FAIL', 'Hold release failed in WMS system',  'CANCEL_FAIL', 'Cancellation failed in WMS system',  'EBSHOLD_FAIL', 'WMS cannot place hold on this pick ticket')
         WHERE     request_id = g_num_request_id
               AND status IN
                       ('EBSRELEASE_FAIL', 'CANCEL_FAIL', 'EBSHOLD_FAIL');

        COMMIT;
        /*
        ****************************
        Special processing messages
        ****************************
        */

        /* Process any PACKED messages*/
        pick_orders;

        /* Process any SHIPPED messages*/
        IF NVL (p_status, 'X') = 'SHIP'
        THEN
            g_num_shipped_mode   := 'Y';
            ship_orders;
        END IF;

        /* Process any CANCEL messages*/
        cancel_orders;

        -- Send notification for 'EBSRELEASE_FAIL', 'EBSHOLD_FAIL', 'CANCEL_FAIL'
        mail_hold_report (p_out_chr_errbuf    => lv_errbuf,
                          p_out_chr_retcode   => lv_return_code);

        IF lv_retcode <> '0'
        THEN
            errbuf    := lv_errbuf;
            retcode   := '1';
            fnd_file.put_line (
                fnd_file.LOG,
                'Unable to send Hold Report due to : ' || errbuf);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 2;
            errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'ERROR in procedure' || retcode || '--' || errbuf);
            msg (v_message);
    END main_validate;
END xxdo_ont_order_update_pkg;
/


GRANT EXECUTE ON APPS.XXDO_ONT_ORDER_UPDATE_PKG TO SOA_INT
/
