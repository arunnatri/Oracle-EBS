--
-- XXD_PO_MODIFY_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_MODIFY_CONV_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_PO_MODIFY_CONV_PKG
    * Design       : This package is used for PO Modify Move Org Conversion
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 07-Oct-2019  1.0        Viswanathan Pandian     Initial version
    ******************************************************************************************/
    gn_org_id              NUMBER := fnd_global.org_id;
    gn_user_id             NUMBER := fnd_global.user_id;
    gn_login_id            NUMBER := fnd_global.login_id;
    gn_request_id          NUMBER := fnd_global.conc_request_id;
    gn_application_id      NUMBER := fnd_profile.VALUE ('RESP_APPL_ID');
    gn_responsibility_id   NUMBER := fnd_profile.VALUE ('RESP_ID');
    gc_debug_enable        VARCHAR2 (1);

    -- ======================================================================================
    -- This procedure prints the Debug Messages in Log Or File
    -- ======================================================================================
    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        -- Write Conc Log
        IF gc_debug_enable = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END debug_msg;

    -- ======================================================================================
    -- This procedure will be called from the webadi to load data into custom table
    -- ======================================================================================
    PROCEDURE upload_prc (p_operating_unit IN hr_operating_units.NAME%TYPE, p_po_number IN po_headers_all.segment1%TYPE, p_warehouse IN mtl_parameters.organization_code%TYPE)
    AS
        CURSOR po_lines_det_cur (
            p_po_header_id IN po_headers_all.po_header_id%TYPE)
        IS
              SELECT pla.po_header_id, pla.po_line_id, pda.req_distribution_id,
                     (plla.quantity - plla.quantity_received) quantity, plla.line_location_id, xciv.style_number || '-' || xciv.color_code style_color,
                     xciv.item_number
                FROM po_lines_all pla, po_line_locations_all plla, po_distributions_all pda,
                     xxd_common_items_v xciv
               WHERE     pla.po_header_id = plla.po_header_id
                     AND pla.po_line_id = plla.po_line_id
                     AND pla.item_id = xciv.inventory_item_id
                     AND xciv.organization_id = plla.ship_to_organization_id
                     AND pla.po_header_id = pda.po_header_id
                     AND pla.po_line_id = pda.po_line_id
                     AND pla.closed_code = 'OPEN'
                     AND NVL (pla.cancel_flag, 'N') = 'N'
                     AND plla.quantity - plla.quantity_received > 0
                     AND pla.po_header_id = p_po_header_id
            ORDER BY pla.po_line_id;

        lc_err_message            VARCHAR2 (4000);
        lc_ret_message            VARCHAR2 (4000);
        lc_supplier_site_code     VARCHAR2 (100);
        le_webadi_exception       EXCEPTION;
        ln_pr_header_id           NUMBER;
        ln_pr_line_id             NUMBER;
        ln_iso_header_id          NUMBER;
        ln_iso_line_id            NUMBER;
        ln_source_doc_id          NUMBER;
        ln_ir_header_id           NUMBER;
        ln_ir_line_id             NUMBER;
        ln_drop_ship_id           NUMBER;
        ln_source_po_header_id    NUMBER;
        ln_source_org_id          NUMBER;
        ln_target_org_id          NUMBER;
        ln_dest_inv_org_id        NUMBER;
        ln_supplier_id            NUMBER;
        ln_new_supplier_site_id   NUMBER;
        ln_item_count             NUMBER;
        ln_line_count             NUMBER := 0;
        ld_creation_date          DATE := SYSDATE;
    BEGIN
        -- Get Current Operating Unit
        BEGIN
            SELECT organization_id
              INTO ln_source_org_id
              FROM hr_operating_units
             WHERE NAME = p_operating_unit;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    lc_err_message || 'Invalid Source Operating Unit.';
        END;

        -- Get PO Details
        BEGIN
            SELECT pha.po_header_id, pha.vendor_id, apsa.vendor_site_code
              INTO ln_source_po_header_id, ln_supplier_id, lc_supplier_site_code
              FROM po_headers_all pha, ap_supplier_sites_all apsa
             WHERE     pha.vendor_site_id = apsa.vendor_site_id
                   AND pha.segment1 = p_po_number
                   AND apsa.org_id = ln_source_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   := lc_err_message || 'Invalid PO Number.';
        END;

        -- Get Destination Inventory Org
        BEGIN
            SELECT organization_id
              INTO ln_dest_inv_org_id
              FROM mtl_parameters
             WHERE organization_code = p_warehouse;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_err_message   :=
                    lc_err_message || 'Invalid Destination Inv Org.';
        END;

        -- Get Target Operating Unit
        IF ln_dest_inv_org_id IS NOT NULL
        THEN
            BEGIN
                SELECT operating_unit
                  INTO ln_target_org_id
                  FROM org_organization_definitions
                 WHERE organization_id = ln_dest_inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Invalid Destination Operating Unit.';
            END;
        END IF;

        -- Validate Target Supplier Site
        IF ln_target_org_id IS NOT NULL AND ln_supplier_id IS NOT NULL
        THEN
            BEGIN
                SELECT vendor_site_id
                  INTO ln_new_supplier_site_id
                  FROM ap_supplier_sites_all
                 WHERE     org_id = ln_target_org_id
                       AND vendor_id = ln_supplier_id
                       AND vendor_site_code = lc_supplier_site_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Invalid Destination Supplier Site.';
            END;
        END IF;

        -- Validate Item Assignment
        IF     ln_source_po_header_id IS NOT NULL
           AND ln_dest_inv_org_id IS NOT NULL
        THEN
            SELECT COUNT (1)
              INTO ln_item_count
              FROM po_lines_all pla, po_line_locations_all plla
             WHERE     pla.po_header_id = plla.po_header_id
                   AND pla.po_line_id = plla.po_line_id
                   AND pla.closed_code = 'OPEN'
                   AND NVL (pla.cancel_flag, 'N') = 'N'
                   AND plla.quantity - plla.quantity_received > 0
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_system_items_b msib
                             WHERE     pla.item_id = msib.inventory_item_id
                                   AND msib.organization_id =
                                       ln_dest_inv_org_id
                                   AND msib.inventory_item_status_code =
                                       'Active')
                   AND pla.po_header_id = ln_source_po_header_id;

            IF ln_item_count > 0
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'One or more Eligible Items are not assigned to Destination Inv Org.';
            END IF;
        END IF;

        IF lc_err_message IS NULL
        THEN
            FOR po_lines_det_rec IN po_lines_det_cur (ln_source_po_header_id)
            LOOP
                ln_line_count      := ln_line_count + 1;
                ln_pr_header_id    := NULL;
                ln_pr_line_id      := NULL;
                ln_iso_header_id   := NULL;
                ln_iso_line_id     := NULL;
                ln_source_doc_id   := NULL;
                ln_ir_header_id    := NULL;
                ln_ir_line_id      := NULL;

                -- Get Requistion Details
                IF po_lines_det_rec.req_distribution_id IS NOT NULL
                THEN
                    BEGIN
                        SELECT prl.requisition_header_id, prl.requisition_line_id
                          INTO ln_pr_header_id, ln_pr_line_id
                          FROM po_requisition_lines_all prl, po_req_distributions_all prd
                         WHERE     prl.requisition_line_id =
                                   prd.requisition_line_id
                               AND prd.distribution_id =
                                   po_lines_det_rec.req_distribution_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            --no PR for PO
                            ln_pr_header_id   := NULL;
                            ln_pr_line_id     := NULL;
                    END;
                END IF;

                -- Get ISO details
                BEGIN
                    SELECT ool.header_id, ool.line_id, ool.source_document_line_id
                      INTO ln_iso_header_id, ln_iso_line_id, ln_source_doc_id
                      FROM oe_order_headers_all ooh, oe_order_lines_all ool
                     WHERE     ooh.header_id = ool.header_id
                           AND NVL (ool.CONTEXT, 'A') != 'DO eCommerce'
                           AND ool.attribute16 =
                               TO_CHAR (po_lines_det_rec.line_location_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --no iso for PO
                        ln_iso_header_id   := NULL;
                        ln_iso_line_id     := NULL;
                END;

                -- Get IR details
                BEGIN
                    SELECT requisition_header_id, requisition_line_id
                      INTO ln_ir_header_id, ln_ir_line_id
                      FROM po_requisition_lines_all irl
                     WHERE irl.requisition_line_id = ln_source_doc_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --no iso for PO
                        ln_ir_header_id   := NULL;
                        ln_ir_line_id     := NULL;
                END;

                -- Get Drop Ship Details
                BEGIN
                    SELECT drop_ship_source_id
                      INTO ln_drop_ship_id
                      FROM oe_drop_ship_sources
                     WHERE     po_header_id = po_lines_det_rec.po_header_id
                           AND po_line_id = po_lines_det_rec.po_line_id
                           AND line_location_id =
                               po_lines_det_rec.line_location_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_drop_ship_id   := NULL;
                END;

                BEGIN
                    INSERT INTO xxd_po_modify_details_t (record_id, batch_id, org_id, source_po_header_id, style_color, open_qty, action_type, move_inv_org_id, supplier_id, supplier_site_id, move_po, move_po_header_id, source_po_line_id, source_pr_header_id, source_pr_line_id, source_iso_header_id, source_iso_line_id, source_ir_header_id, source_ir_line_id, drop_ship_source_id, item_number, move_org_operating_unit_flag, cancel_po_header_flag, cancel_iso_header_flag, intercompany_po_flag, po_cancelled_flag, pr_cancelled_flag, iso_cancelled_flag, ir_cancelled_flag, po_modify_source, request_id, status, error_message, creation_date, created_by, last_updated_date
                                                         , last_updated_by)
                         VALUES (xxd_po_modify_details_s.NEXTVAL, NULL, ln_source_org_id, ln_source_po_header_id, po_lines_det_rec.style_color, po_lines_det_rec.quantity, 'Move Org', ln_dest_inv_org_id, ln_supplier_id, ln_new_supplier_site_id, NULL, NULL, po_lines_det_rec.po_line_id, ln_pr_header_id, ln_pr_line_id, ln_iso_header_id, ln_iso_line_id, ln_ir_header_id, ln_ir_line_id, ln_drop_ship_id, po_lines_det_rec.item_number, 'Y', '', '', --'Y', 'Y',
                                                                                                                                                                                                                                                                                                                                                                                                                                                           'Y', 'N', DECODE (ln_pr_line_id, NULL, NULL, 'N'), DECODE (ln_iso_line_id, NULL, NULL, 'N'), DECODE (ln_ir_line_id, NULL, NULL, 'N'), 'CONV', gn_request_id, 'N', NULL, ld_creation_date, gn_user_id, SYSDATE
                                 , gn_user_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_err_message   :=
                               lc_err_message
                            || 'Error While Inserting Data in Staging Table.';
                        RAISE le_webadi_exception;
                END;
            END LOOP;

            IF ln_line_count = 0
            THEN
                lc_err_message   :=
                    lc_err_message || 'No Eligible PO Lines Exists.';
            END IF;
        END IF;

        IF lc_err_message IS NOT NULL
        THEN
            RAISE le_webadi_exception;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lc_err_message);
            lc_ret_message   := fnd_message.get ();
            raise_application_error (-20000, lc_ret_message);
        WHEN OTHERS
        THEN
            lc_ret_message   := SQLERRM;
            raise_application_error (-20001, lc_ret_message);
    END upload_prc;

    -- ======================================================================================
    -- This procedure will spawn child program for processing
    -- ======================================================================================
    PROCEDURE master_prc (x_retcode OUT NOCOPY VARCHAR2, x_errbuf OUT NOCOPY VARCHAR2, p_po_header_id IN po_headers_all.po_header_id%TYPE
                          , p_dest_org_id IN mtl_parameters.organization_id%TYPE, p_threads IN NUMBER, p_debug IN VARCHAR2)
    AS
        CURSOR get_po_c IS
            SELECT DISTINCT source_po_header_id
              FROM xxd_po_modify_details_t
             WHERE     status = 'N'
                   AND action_type = 'Move Org'
                   AND po_modify_source = 'CONV'
                   AND ((p_po_header_id IS NOT NULL AND source_po_header_id = p_po_header_id) OR (p_po_header_id IS NULL AND 1 = 1))
                   AND ((p_dest_org_id IS NOT NULL AND move_inv_org_id = p_dest_org_id) OR (p_dest_org_id IS NULL AND 1 = 1));

        CURSOR get_batches IS
              SELECT bucket, MIN (batch_id) from_batch_id, MAX (batch_id) to_batch_id
                FROM (SELECT batch_id, NTILE (p_threads) OVER (ORDER BY batch_id) bucket
                        FROM (SELECT DISTINCT batch_id
                                FROM xxd_po_modify_details_t
                               WHERE request_id = gn_request_id))
            GROUP BY bucket
            ORDER BY 1;

        ln_batch_id                 NUMBER;
        ln_req_id                   NUMBER;
        ln_record_count             NUMBER := 0;
        lc_req_data                 VARCHAR2 (10);
        lc_status                   VARCHAR2 (10);
        ln_source_po_lines_count    NUMBER;
        ln_stg_po_lines_count       NUMBER;
        ln_po_header_cancel_flag    VARCHAR2 (2);
        ln_iso_header_id            NUMBER;
        ln_source_iso_lines_count   NUMBER;
        ln_stg_iso_lines_count      NUMBER;
        ln_iso_header_cancel_flag   VARCHAR2 (2);
    BEGIN
        lc_req_data       := fnd_conc_global.request_data;

        IF lc_req_data = 'MASTER'
        THEN
            RETURN;
        END IF;

        gc_debug_enable   := p_debug;
        debug_msg ('Start MASTER_PRC');
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        -- Perform Batching
        FOR po_rec IN get_po_c
        LOOP
            --Getting count of po_lines
            BEGIN
                SELECT COUNT (*)
                  INTO ln_source_po_lines_count
                  FROM po_lines_all
                 WHERE     po_header_id = po_rec.source_po_header_id
                       AND NVL (cancel_flag, 'N') = 'N';
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_errbuf    := SQLERRM;
                    x_retcode   := 2;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Exception while getting source po count  in MASTER_PRC = '
                        || SQLERRM);

                    UPDATE xxd_po_modify_details_t
                       SET status = 'E', error_message = SUBSTR (x_errbuf, 1, 3000)
                     WHERE     status = 'N'
                           AND action_type = 'Move Org'
                           AND po_modify_source = 'CONV';
            END;

            --Getting count of staging table count
            BEGIN
                SELECT COUNT (*)
                  INTO ln_stg_po_lines_count
                  FROM xxd_po_modify_details_t
                 WHERE     source_po_header_id = po_rec.source_po_header_id
                       AND action_type = 'Move Org'
                       AND po_modify_source = 'CONV'
                       AND status = 'N';
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_errbuf    := SQLERRM;
                    x_retcode   := 2;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Exception while getting staging po count  in MASTER_PRC = '
                        || SQLERRM);

                    UPDATE xxd_po_modify_details_t
                       SET status = 'E', error_message = SUBSTR (x_errbuf, 1, 3000)
                     WHERE     status = 'N'
                           AND action_type = 'Move Org'
                           AND po_modify_source = 'CONV';
            END;

            --If po_lines count and staging table count is equal cancel po_header
            IF ln_stg_po_lines_count = ln_source_po_lines_count
            THEN
                ln_po_header_cancel_flag   := 'Y';
            ELSE
                ln_po_header_cancel_flag   := 'N';
            END IF;

            --Get ISO header_id
            BEGIN
                SELECT DISTINCT source_iso_header_id
                  INTO ln_iso_header_id
                  FROM xxd_po_modify_details_t
                 WHERE     source_po_header_id = po_rec.source_po_header_id
                       AND action_type = 'Move Org'
                       AND po_modify_source = 'CONV'
                       AND status = 'N';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_iso_header_id   := NULL;
            END;

            IF ln_iso_header_id IS NOT NULL
            THEN
                --Getting oe_order_lines_count
                BEGIN
                    SELECT COUNT (*)
                      INTO ln_source_iso_lines_count
                      FROM oe_order_lines_all
                     WHERE     header_id = ln_iso_header_id
                           AND NVL (cancelled_flag, 'N') = 'N';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_errbuf    := SQLERRM;
                        x_retcode   := 2;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Exception while iso header_id in MASTER_PRC = '
                            || SQLERRM);

                        UPDATE xxd_po_modify_details_t
                           SET status = 'E', error_message = SUBSTR (x_errbuf, 1, 3000)
                         WHERE     status = 'N'
                               AND action_type = 'Move Org'
                               AND po_modify_source = 'CONV';
                END;

                --Getting iso lines count fron staging table
                BEGIN
                    SELECT COUNT (*)
                      INTO ln_stg_iso_lines_count
                      FROM xxd_po_modify_details_t
                     WHERE     source_po_header_id =
                               po_rec.source_po_header_id
                           AND action_type = 'Move Org'
                           AND po_modify_source = 'CONV'
                           AND status = 'N'
                           AND source_iso_header_id IS NOT NULL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_errbuf    := SQLERRM;
                        x_retcode   := 2;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Exception while iso header_id in MASTER_PRC = '
                            || SQLERRM);

                        UPDATE xxd_po_modify_details_t
                           SET status = 'E', error_message = SUBSTR (x_errbuf, 1, 3000)
                         WHERE     status = 'N'
                               AND action_type = 'Move Org'
                               AND po_modify_source = 'CONV';
                END;

                --If oe_order_lines count and staging table count is equal cancel iso_header
                IF ln_source_iso_lines_count = ln_stg_iso_lines_count
                THEN
                    ln_iso_header_cancel_flag   := 'Y';
                ELSE
                    ln_iso_header_cancel_flag   := 'N';
                END IF;
            ELSE
                ln_iso_header_cancel_flag   := 'N';
            END IF;

            ln_batch_id       := xxd_po_modify_details_batch_s.NEXTVAL;

            UPDATE xxd_po_modify_details_t
               SET batch_id = ln_batch_id, request_id = gn_request_id, cancel_po_header_flag = ln_po_header_cancel_flag,
                   cancel_iso_header_flag = ln_iso_header_cancel_flag
             WHERE     status = 'N'
                   AND action_type = 'Move Org'
                   AND po_modify_source = 'CONV'
                   AND source_po_header_id = po_rec.source_po_header_id;

            ln_record_count   := ln_record_count + SQL%ROWCOUNT;
        END LOOP;

        COMMIT;
        debug_msg ('Total Lines Count = ' || ln_record_count);

        IF ln_record_count > 0
        THEN
            -- Submit Child Programs
            FOR batch_rec IN get_batches
            LOOP
                ln_req_id   := 0;
                ln_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXD_PO_MODIFY_CONV_CHILD',
                        description   => NULL,
                        start_time    => NULL,
                        sub_request   => TRUE,
                        argument1     => batch_rec.from_batch_id,
                        argument2     => batch_rec.to_batch_id,
                        argument3     => gn_request_id,
                        argument4     => p_debug);
                COMMIT;
                debug_msg ('Child Request ID = ' || ln_req_id);
            END LOOP;

            debug_msg ('Successfully Submitted Child Threads');
            debug_msg (RPAD ('=', 100, '='));

            IF ln_req_id IS NOT NULL
            THEN
                fnd_conc_global.set_req_globals (conc_status    => 'PAUSED',
                                                 request_data   => 'MASTER');
            END IF;
        ELSE
            debug_msg ('No Data Found to Process');
            debug_msg (RPAD ('=', 100, '='));
        END IF;

        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End MASTER_PRC');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            debug_msg ('End MASTER_PRC');
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in MASTER_PRC = ' || SQLERRM);

            UPDATE xxd_po_modify_details_t
               SET status = 'E', error_message = SUBSTR (x_errbuf, 1, 3000)
             WHERE     status = 'N'
                   AND action_type = 'Move Org'
                   AND po_modify_source = 'CONV';
    END master_prc;

    -- ======================================================================================
    -- This procedure will cancel the source PO and create them in destination org
    -- ======================================================================================
    PROCEDURE child_prc (x_retcode            OUT NOCOPY VARCHAR2,
                         x_errbuf             OUT NOCOPY VARCHAR2,
                         p_from_batch_id   IN            NUMBER,
                         p_to_batch_id     IN            NUMBER,
                         p_request_id      IN            NUMBER,
                         p_debug           IN            VARCHAR2)
    AS
        CURSOR get_lines_c IS
            SELECT DISTINCT batch_id, source_po_header_id
              FROM xxd_po_modify_details_t
             WHERE     status = 'N'
                   AND action_type = 'Move Org'
                   AND po_modify_source = 'CONV'
                   AND request_id = p_request_id
                   AND batch_id BETWEEN p_from_batch_id AND p_to_batch_id;

        lc_error_status    VARCHAR2 (100);
        lc_error_message   VARCHAR2 (4000);
    BEGIN
        gc_debug_enable   := p_debug;
        debug_msg ('Start CHILD_PRC');
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        FOR lines_rec IN get_lines_c
        LOOP
            debug_msg (RPAD ('=', 100, '='));
            debug_msg ('Processing Batch ID: ' || lines_rec.batch_id);
            debug_msg (
                   'Start Time '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg (
                'Processing PO Header ID: ' || lines_rec.source_po_header_id);
            xxd_po_pomodify_pkg.process_transaction (
                pv_errbuf      => lc_error_status,
                pv_retcode     => lc_error_message,
                p_batch_id     => lines_rec.batch_id,
                p_request_id   => NULL,
                p_user_id      => gn_user_id);
            debug_msg ('Process Status: ' || lc_error_status);
            debug_msg ('Process Message: ' || lc_error_message);
            debug_msg (
                'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg (RPAD ('=', 100, '='));
        END LOOP;

        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End CHILD_PRC');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            debug_msg ('End MASTER_PRC');
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in MASTER_PRC = ' || SQLERRM);

            UPDATE xxd_po_modify_details_t
               SET status = 'E', error_message = SUBSTR (x_errbuf, 1, 3000)
             WHERE     status = 'N'
                   AND action_type = 'Move Org'
                   AND po_modify_source = 'CONV'
                   AND request_id = p_request_id
                   AND batch_id BETWEEN p_from_batch_id AND p_to_batch_id;
    END child_prc;
END xxd_po_modify_conv_pkg;
/
