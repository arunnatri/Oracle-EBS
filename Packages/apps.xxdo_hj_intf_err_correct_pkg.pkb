--
-- XXDO_HJ_INTF_ERR_CORRECT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_HJ_INTF_ERR_CORRECT_PKG"
AS
    /**********************************************************************************************
    -- Package Name :  XXDO_HJ_INTF_ERR_CORRECT_PKG
    -- Description  :  This is package spec for All common errors interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author                Version    Description
    -- ------------  -----------------     -------  --------------------------------
    --10-Jun-2015    Infosys               1.0        Initial Version
    --03-Sep-2015    Infosys               1.1        Addition of parameters for SPLIT_QUANTITY , identified by SPLIT_QUANTITY
    --07-Aug-2018    Infosys               1.2        Adding parameter BOL number for insertion,  identified by CCR CCR0007450
    --03-Sep-2020    Viswanathan Pandian   1.3        Updated for CCR0008881
    -- *********************************************************************************************/

    PROCEDURE main (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT NUMBER, p_in_chr_operation IN VARCHAR2, /*SPLIT_QUANTITY*/
                                                                                                                 p_in_chr_interface_name IN VARCHAR2, p_in_chr_id1 IN VARCHAR2, p_in_chr_id2 IN VARCHAR2, p_in_chr_id3 IN VARCHAR2, p_in_chr_id4 IN VARCHAR2, p_in_chr_old_proc_status IN VARCHAR2, p_in_chr_process_status IN VARCHAR2, p_in_chr_comments IN VARCHAR2, p_in_chr_order_status IN VARCHAR2
                    , p_in_num_split_qty IN NUMBER)         /*SPLIT_QUANTITY*/
    IS
        l_num_suffix        NUMBER;
        l_num_inv_adj_qty   NUMBER;                        /*SPLIT_QUANTITY */
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Beginning of the program');


        IF p_in_chr_operation = 'Update'
        THEN
            IF p_in_chr_interface_name = 'SHIP'
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Updating Ship Confirm Tables');

                -- ID4 is line number, if this is passed, all other ids also should be passed
                -- and we need to update the status of only carton details records
                IF p_in_chr_id4 IS NOT NULL
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Updating Ship Confirm - Carton Detail table');


                    UPDATE xxdo_ont_ship_conf_cardtl_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     line_number = p_in_chr_id4
                           AND carton_number = p_in_chr_id3
                           AND order_number = p_in_chr_id2
                           AND shipment_number = p_in_chr_id1
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Number of Records Updated: ' || SQL%ROWCOUNT);
                -- id 3 is carton number, the carton and all the carton detail records need to be updated
                ELSIF p_in_chr_id3 IS NOT NULL
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Updating Ship Confirm - Carton and Carton details tables');


                    UPDATE xxdo_ont_ship_conf_carton_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     carton_number = p_in_chr_id3
                           AND order_number = p_in_chr_id2
                           AND shipment_number = p_in_chr_id1
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Number of Carton Records Updated: ' || SQL%ROWCOUNT);

                    UPDATE xxdo_ont_ship_conf_cardtl_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     carton_number = p_in_chr_id3
                           AND order_number = p_in_chr_id2
                           AND shipment_number = p_in_chr_id1
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of Carton Details Records Updated: '
                        || SQL%ROWCOUNT);
                ELSIF p_in_chr_id2 IS NOT NULL
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Updating Ship Confirm - Order, Carton, Carton details tables');

                    SELECT   TO_NUMBER (NVL (REGEXP_SUBSTR (MAX (shipment_number), '[^-]+', 1
                                                            , 2),
                                             0))
                           + 1
                      INTO l_num_suffix
                      FROM xxdo_ont_ship_conf_head_stg
                     WHERE shipment_number LIKE p_in_chr_id1 || '-%';

                    INSERT INTO xxdo_ont_ship_conf_head_stg (
                                    wh_id,
                                    shipment_number,
                                    master_load_ref,
                                    customer_load_id,
                                    carrier,
                                    service_level,
                                    pro_number,
                                    comments,
                                    ship_date,
                                    seal_number,
                                    trailer_number,
                                    employee_id,
                                    employee_name,
                                    process_status,
                                    error_message,
                                    request_id,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by,
                                    source_type,
                                    shipment_type,     -- Added for CCR0008881
                                    sales_channel,     -- Added for CCR0008881
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
                                    SOURCE,
                                    destination,
                                    record_type,
                                    BOL_NUMBER)  --Added as per CCR CCR0007450
                        SELECT wh_id, shipment_number || '-' || l_num_suffix, master_load_ref,
                               customer_load_id, carrier, service_level,
                               pro_number, comments, ship_date,
                               seal_number, trailer_number, employee_id,
                               employee_name, p_in_chr_process_status, error_message,
                               request_id, SYSDATE, g_num_user_id,
                               SYSDATE, g_num_user_id, source_type,
                               shipment_type,          -- Added for CCR0008881
                                              sales_channel, -- Added for CCR0008881
                                                             attribute1,
                               attribute2, attribute3, attribute4,
                               attribute5, attribute6, attribute7,
                               attribute8, attribute9, process_status,
                               p_in_chr_comments, attribute12, attribute13,
                               attribute14, attribute15, attribute16,
                               attribute17, attribute18, attribute19,
                               attribute20, SOURCE, destination,
                               record_type, BOL_NUMBER --Added as per CCR CCR0007450
                          FROM xxdo_ont_ship_conf_head_stg
                         WHERE shipment_number = p_in_chr_id1;

                    fnd_file.put_line (fnd_file.LOG,
                                       '1 Shipment Header is inserted');


                    UPDATE xxdo_ont_ship_conf_order_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments, shipment_number = shipment_number || '-' || l_num_suffix
                     WHERE     shipment_number = p_in_chr_id1
                           AND order_number = p_in_chr_id2
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Number of Order Records Updated: ' || SQL%ROWCOUNT);


                    UPDATE xxdo_ont_ship_conf_carton_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments, shipment_number = shipment_number || '-' || l_num_suffix
                     WHERE     shipment_number = p_in_chr_id1
                           AND order_number = p_in_chr_id2
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Number of Carton Records Updated: ' || SQL%ROWCOUNT);


                    UPDATE xxdo_ont_ship_conf_cardtl_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments, shipment_number = shipment_number || '-' || l_num_suffix
                     WHERE     shipment_number = p_in_chr_id1
                           AND order_number = p_in_chr_id2
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of Carton Details Records Updated: '
                        || SQL%ROWCOUNT);
                ELSE -- Only shipment number was passed - update all the 4 level records
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Updating All the 4 Ship Confirm tables');


                    UPDATE xxdo_ont_ship_conf_head_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     shipment_number = p_in_chr_id1
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of Shipment Header Records Updated: '
                        || SQL%ROWCOUNT);


                    UPDATE xxdo_ont_ship_conf_order_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     shipment_number = p_in_chr_id1
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Number of Order Records Updated: ' || SQL%ROWCOUNT);


                    UPDATE xxdo_ont_ship_conf_carton_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     shipment_number = p_in_chr_id1
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Number of Carton Records Updated: ' || SQL%ROWCOUNT);


                    UPDATE xxdo_ont_ship_conf_cardtl_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     shipment_number = p_in_chr_id1
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of Carton Details Records Updated: '
                        || SQL%ROWCOUNT);
                END IF;
            ELSIF p_in_chr_interface_name = 'ASN'
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Updating ASN Receipt Tables');

                -- in case of ASN , ID3 is the serial sequene id
                IF p_in_chr_id3 IS NOT NULL
                THEN
                    UPDATE xxdo_po_asn_receipt_ser_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     receipt_serial_seq_id =
                               TO_NUMBER (p_in_chr_id3)
                           AND process_status = p_in_chr_old_proc_status;


                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of ASN Serial Records Updated: '
                        || SQL%ROWCOUNT);
                ELSIF p_in_chr_id2 IS NOT NULL
                THEN
                    UPDATE xxdo_po_asn_receipt_dtl_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     receipt_dtl_seq_id = TO_NUMBER (p_in_chr_id2)
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of ASN Receipt Records Updated: '
                        || SQL%ROWCOUNT);


                    UPDATE xxdo_po_asn_receipt_ser_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     receipt_dtl_seq_id = TO_NUMBER (p_in_chr_id2)
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Number of Serial Records Updated: ' || SQL%ROWCOUNT);
                ELSE
                    UPDATE xxdo_po_asn_receipt_head_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     receipt_header_seq_id =
                               TO_NUMBER (p_in_chr_id1)
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of ASN Header Records Updated: '
                        || SQL%ROWCOUNT);

                    UPDATE xxdo_po_asn_receipt_dtl_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     receipt_header_seq_id =
                               TO_NUMBER (p_in_chr_id1)
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of ASN Receipt Records Updated: '
                        || SQL%ROWCOUNT);


                    UPDATE xxdo_po_asn_receipt_ser_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     receipt_header_seq_id =
                               TO_NUMBER (p_in_chr_id1)
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Number of Serial Records Updated: ' || SQL%ROWCOUNT);
                END IF;
            ELSIF p_in_chr_interface_name = 'RMA'
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Updating RMA Receipt Tables');

                --Id3 is the serial sequence id
                IF p_in_chr_id3 IS NOT NULL
                THEN
                    UPDATE xxdo_ont_rma_line_serl_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           result_code = NULL, attribute10 = process_status, -- Old process is retained here
                                                                             attribute11 = p_in_chr_comments
                     WHERE     receipt_serial_seq_id =
                               TO_NUMBER (p_in_chr_id3)
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Number of Serial Records Updated: ' || SQL%ROWCOUNT);
                ELSIF p_in_chr_id2 IS NOT NULL
                THEN
                    UPDATE xxdo_ont_rma_line_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           attribute10 = process_status, -- Old process is retained here
                                                         attribute11 = p_in_chr_comments
                     WHERE     receipt_line_seq_id = TO_NUMBER (p_in_chr_id2)
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of RMA Lines Records Updated: '
                        || SQL%ROWCOUNT);


                    UPDATE xxdo_ont_rma_line_serl_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           result_code = NULL, attribute10 = process_status, -- Old process is retained here
                                                                             attribute11 = p_in_chr_comments
                     WHERE     receipt_line_seq_id = TO_NUMBER (p_in_chr_id2)
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Number of Serial Records Updated: ' || SQL%ROWCOUNT);
                ELSE
                    UPDATE xxdo_ont_rma_hdr_stg
                       SET process_status = p_in_chr_process_status, result_code = NULL, last_updated_by = g_num_user_id,
                           last_update_date = SYSDATE, attribute10 = process_status, -- Old process is retained here
                                                                                     attribute11 = p_in_chr_comments
                     WHERE     receipt_header_seq_id =
                               TO_NUMBER (p_in_chr_id1)
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of RMA Header Records Updated: '
                        || SQL%ROWCOUNT);


                    UPDATE xxdo_ont_rma_line_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           result_code = NULL, attribute10 = process_status, -- Old process is retained here
                                                                             attribute11 = p_in_chr_comments
                     WHERE     receipt_header_seq_id =
                               TO_NUMBER (p_in_chr_id1)
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of RMA Line Records Updated: '
                        || SQL%ROWCOUNT);


                    UPDATE xxdo_ont_rma_line_serl_stg
                       SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                           result_code = NULL, attribute10 = process_status, -- Old process is retained here
                                                                             attribute11 = p_in_chr_comments
                     WHERE     receipt_header_seq_id =
                               TO_NUMBER (p_in_chr_id1)
                           AND process_status = p_in_chr_old_proc_status;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Number of Serial Records Updated: ' || SQL%ROWCOUNT);
                END IF;
            ELSIF p_in_chr_interface_name = 'ORDER'
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Updating Order Status Tables');

                UPDATE xxdo_ont_pick_status_order
                   SET process_status     = p_in_chr_process_status,
                       last_updated_by    = g_num_user_id,
                       last_update_date   = SYSDATE,
                       error_msg          =
                           CASE
                               WHEN p_in_chr_process_status = 'NEW' THEN NULL
                               ELSE error_msg
                           END,
                       request_id         =
                           CASE
                               WHEN p_in_chr_process_status = 'NEW' THEN NULL
                               ELSE request_id
                           END
                 WHERE     order_number = p_in_chr_id1
                       AND status = p_in_chr_order_status
                       AND process_status = p_in_chr_old_proc_status;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Number of Pick Ticket Records Updated: ' || SQL%ROWCOUNT);


                UPDATE xxdo_ont_pick_status_load
                   SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
                 WHERE order_number = p_in_chr_id1;
            --      AND process_status = p_in_chr_order_status;

            ELSIF p_in_chr_interface_name = 'INVENTORY'
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Updating Inventory Adjustment Tables');

                UPDATE xxdo_inv_trans_adj_dtl_stg
                   SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                       attribute10 = process_status, -- Old process is retained here
                                                     attribute11 = p_in_chr_comments
                 WHERE     transaction_seq_id = TO_NUMBER (p_in_chr_id1)
                       AND process_status = p_in_chr_old_proc_status;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Number of Inv Adjustment Records Updated: '
                    || SQL%ROWCOUNT);


                UPDATE xxdo_inv_trans_adj_ser_stg
                   SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE,
                       attribute10 = process_status, -- Old process is retained here
                                                     attribute11 = p_in_chr_comments
                 WHERE     transaction_seq_id = TO_NUMBER (p_in_chr_id1)
                       AND process_status = p_in_chr_old_proc_status;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Number of Serial Records Updated: ' || SQL%ROWCOUNT);
            ELSIF p_in_chr_interface_name = 'HOLD_CANCEL'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Update Hold Cancel Table if CANCEL message exists');

                UPDATE xxdo_ont_hold_cancel_order
                   SET process_status = p_in_chr_process_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
                 WHERE     seq_id = p_in_chr_id1
                       AND process_status = p_in_chr_old_proc_status;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Number of Hold Cancel table Updated: ' || SQL%ROWCOUNT);
            END IF;
        ELSIF p_in_chr_operation = 'Delete'
        THEN
            IF p_in_chr_interface_name = 'HOLD_CANCEL'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Deleting from Hold Cancel Table if CANCEL message exists');

                DELETE FROM xxdo_ont_hold_cancel_order
                      WHERE seq_id = p_in_chr_id1;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Number of Cancel Records Deleted: ' || SQL%ROWCOUNT);
            END IF;
        ELSIF p_in_chr_operation = 'Split'
        THEN
            IF     p_in_chr_interface_name = 'INVENTORY'
               AND p_in_num_split_qty IS NOT NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Inserting into xxdo_inv_trans_adj_dtl_stg for SPLIT Qty');


                IF p_in_num_split_qty <= 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Split Qty should be a positive value');
                ELSE                                  -- split qty is positive
                    BEGIN
                        SELECT qty
                          INTO l_num_inv_adj_qty
                          FROM xxdo_inv_trans_adj_dtl_stg
                         WHERE transaction_seq_id = TO_NUMBER (p_in_chr_id1);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_num_inv_adj_qty   := 0;
                    END;

                    IF ABS (l_num_inv_adj_qty) <= p_in_num_split_qty
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Split Qty should be a less than Qty');
                    ELSE              -- Split qty is valid i.e. less than qty
                        /**Inserting p_in_num_split_qty */
                        INSERT INTO xxdo_inv_trans_adj_dtl_stg (
                                        wh_id,
                                        source_subinventory,
                                        dest_subinventory,
                                        source_locator,
                                        destination_locator,
                                        tran_date,
                                        item_number,
                                        qty,
                                        uom,
                                        employee_id,
                                        employee_name,
                                        reason_code,
                                        comments,
                                        organization_id,
                                        inventory_item_id,
                                        source_locator_id,
                                        destination_locator_id,
                                        transaction_seq_id,
                                        process_status,
                                        error_message,
                                        request_id,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        source_type,
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
                                        source,
                                        destination,
                                        record_type,
                                        interface_transaction_id,
                                        session_id,
                                        server_tran_date,
                                        account_alias)
                            SELECT wh_id,
                                   source_subinventory,
                                   dest_subinventory,
                                   source_locator,
                                   destination_locator,
                                   tran_date,
                                   item_number,
                                   CASE
                                       WHEN qty > 0 THEN p_in_num_split_qty
                                       ELSE -p_in_num_split_qty
                                   END,
                                   uom,
                                   employee_id,
                                   employee_name,
                                   reason_code,
                                   comments,
                                   organization_id,
                                   inventory_item_id,
                                   source_locator_id,
                                   destination_locator_id,
                                   xxdo_inv_trans_adj_dtl_stg_s.NEXTVAL,
                                   process_status,
                                   error_message,
                                   request_id,
                                   SYSDATE,
                                   g_num_user_id,
                                   SYSDATE,
                                   g_num_user_id,
                                   source_type,
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
                                   NVL (attribute12,
                                        TO_NUMBER (p_in_chr_id1)),
                                   NVL (attribute13, qty),
                                   attribute14,
                                   attribute15,
                                   attribute16,
                                   attribute17,
                                   attribute18,
                                   attribute19,
                                   attribute20,
                                   source,
                                   destination,
                                   record_type,
                                   interface_transaction_id,
                                   session_id,
                                   server_tran_date,
                                   account_alias
                              FROM xxdo_inv_trans_adj_dtl_stg
                             WHERE transaction_seq_id =
                                   TO_NUMBER (p_in_chr_id1);


                        /**Inserting qty-p_in_num_split_qty */
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Updating  xxdo_inv_trans_adj_dtl_stg for SPLIT Qty');

                        UPDATE xxdo_inv_trans_adj_dtl_stg
                           SET qty                =
                                     qty
                                   - CASE
                                         WHEN qty > 0 THEN p_in_num_split_qty
                                         ELSE -p_in_num_split_qty
                                     END,
                               attribute12       =
                                   NVL (attribute12,
                                        TO_NUMBER (p_in_chr_id1)),
                               attribute13        = NVL (attribute13, qty),
                               last_update_date   = SYSDATE,
                               last_updated_by    = g_num_user_id
                         WHERE transaction_seq_id = TO_NUMBER (p_in_chr_id1);
                    END IF;                                   -- abs qty check
                END IF;                                 -- Split qty +ve check
            END IF;
        /*END  of  SPLIT_QUANTITY*/
        END IF;


        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error while updating  Interface records :'
                || SQLERRM;
            p_out_chr_retcode   := 2;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    -- ROLLBACK;
    END main;
END xxdo_hj_intf_err_correct_pkg;
/
