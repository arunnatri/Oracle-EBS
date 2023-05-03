--
-- XXDOPO_MOQ_SURCHARGE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOPO_MOQ_SURCHARGE_PKG"
IS
    /****************************************************************************************
    * Package      : XXDOPO_MOQ_SURCHARGE_PKG
    * Author       : BT Technology Team
    * Created      : 21-OCT-2014
    * Program Name : MOQ Surcharge Program - Deckers
    * Description  : Package used by: MOQ Surcharge Program - Deckers
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer           Version    Description
    *--------------------------------------------------------------------------------------
    * 09-SEP-2014   BT Technology Team  1.0        Retrofitted
    * 05-FEB-2015   BT Technology Team  1.1        Updating shipment amount along with unit
    *                                              price
    * 23-FEB-2015   BT Technology Team  1.2        Changed api to update po line and shipment
    *                                              price.
    * 23-APR-2015   BT Technology Team  1.3        Changed error handling and corrected
    *                                              duplicate records issue.
    *  1-Nov-2019   GJensen             1.4        Modified for CCR0008186
    ****************************************************************************************/
    --Start Modification by BT Technology Team v1.3 on 23-APR-2014
    PROCEDURE log_message (p_status IN VARCHAR2, p_msg IN VARCHAR2, p_po_line_id IN NUMBER
                           , p_request_id IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxdo.xxdopo_moq_surcharge_stg
           SET status = p_status, error_message = error_message || p_msg
         WHERE po_line_id = p_po_line_id AND request_id = p_request_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error updating message for line id: '
                || p_po_line_id
                || ' - '
                || SQLERRM);
    END;

    --End Modification by BT Technology Team v1.3 on 23-APR-2014

    PROCEDURE xxdo_moq_surcharge_proc (err_buf    OUT VARCHAR2,
                                       ret_code   OUT NUMBER)
    IS
        l_shipment_type   VARCHAR2 (25); --Added by BT Technology Team for v1.1

        CURSOR moq_surcharge IS
            SELECT *
              FROM xxdo.xxdopo_moq_surcharge_stg
             WHERE status = 'N';

        CURSOR moq_surcharge_lines (p_po_number VARCHAR2, p_style VARCHAR2, p_color VARCHAR2
                                    , p_ship_to_loc_id VARCHAR2)
        IS
            SELECT DISTINCT pol.ROWID, pol.*, --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
                                              poh.revision_num revision_num_1, --Gave alias as revision_num_1
                            --End Modification by BT Technology Team v1.0 on 17-OCT-2014
                            pola.shipment_num, pola.promised_date, pola.need_by_date,
                            mtl.segment3
              FROM apps.po_headers_all poh, apps.po_lines_all pol, apps.po_line_locations_all pola,
                   apps.mtl_system_items_b mtl, --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
                                                mtl_item_categories mic, mtl_categories_b mcb,
                   --End Modification by BT Technology Team v1.0 on 17-OCT-2014
                   apps.do_po_details dod
             WHERE     poh.po_header_id = pol.po_header_id
                   AND pol.po_line_id = pola.po_line_id
                   AND pol.po_line_id = dod.po_line_id
                   AND pol.item_id = mtl.inventory_item_id
                   AND NVL (poh.closed_code, 'OPEN') = 'OPEN'
                   AND poh.segment1 = p_po_number
                   --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
                   --AND mtl.segment1 = p_style
                   --AND mtl.segment2 = p_color
                   AND mtl.inventory_item_id = mic.inventory_item_id
                   AND mtl.organization_id = mic.organization_id
                   AND mic.category_id = mcb.category_id
                   AND mic.category_set_id = 1
                   AND mcb.attribute7 = p_style
                   AND mcb.attribute8 = p_color
                   --End Modification by BT Technology Team v1.0 on 17-OCT-2014
                   AND dod.ship_to_location_id = p_ship_to_loc_id;


        CURSOR moq_surcharge_all --(p_status VARCHAR2)
                                 IS
              SELECT DISTINCT pol.ROWID, --Added DISTINCT by BT Technology Team v1.0 on 17-OCT-2014
                                         pol.*, moq.shipment_num,
                              moq.promised_date, moq.need_by_date, moq.global_surcharge,
                              moq.ship_to_id_surcharge, moq.po_no, --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
                                                                   --Added below columns as a part of Redesign
                                                                   moq.unit_price_fob,
                              moq.blended_fob --End Modification by BT Technology Team v1.0 on 17-OCT-2014
                                             --Start Modification by BT Technology Team v1.2 on 23-FEB-2015
                                             , poh.revision_num header_rev_num, pol.line_num line_number,
                              poll.shipment_num shipment_number
                --End Modification by BT Technology Team v1.2 on 23-FEB-2015
                FROM xxdo.xxdopo_moq_surcharge_stg moq, apps.po_lines_all pol --Start Modification by BT Technology Team v1.2 on 23-FEB-2015
                                                                             , po_headers_all poh,
                     po_line_locations_all poll
               --End Modification by BT Technology Team v1.2 on 23-FEB-2015
               WHERE     pol.po_line_id = moq.po_line_id
                     AND status = 'NEW'                             --p_status
                     --Start Modification by BT Technology Team v1.2 on 23-FEB-2015
                     AND pol.po_line_id = poll.po_line_id
                     AND poh.po_header_id = pol.po_header_id
                     AND poll.po_header_id = poh.po_header_id
            --End Modification by BT Technology Team v1.2 on 23-FEB-2015
            ORDER BY pol.org_id;

        --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
        --Commented as Not Used
        --l_unit_price       apps.po_lines_all.unit_price%TYPE;
        --l_revision_num    NUMBER;
        --Removed logic for storing old_unit_price
        --l_old_unit_price   apps.po_lines_all.attribute15%TYPE;         -- Added
        --End Modification by BT Technology Team v1.0 on 17-OCT-2014
        l_result          NUMBER;
        l_api_errors      apps.po_api_errors_rec_type;
        l_error_message   VARCHAR2 (1000);
        l_request_id      NUMBER;
        ln_row_cnt_e      NUMBER := 0;
        ln_row_cnt_s      NUMBER := 0;
        l_org_id          NUMBER := 0;
        l_counter         NUMBER := 1;
        l_invoice_count   NUMBER := 0;
        l_style           mtl_system_items_b.segment1%TYPE;
        l_color           mtl_system_items_b.segment2%TYPE;
        l_instr           NUMBER := 0;
        --Start Modification by BT Technology Team v1.2 on 23-FEB-2015
        ln_revision_num   NUMBER;
        ln_line_num       NUMBER;
        ln_shipment_num   NUMBER;
        --ln_org_id          NUMBER;
        ln_result         NUMBER;
        --End Modification by BT Technology Team v1.2 on 23-FEB-2015
        --Start Modification by BT Technology Team v1.3 on 23-APR-2014
        lv_update_po      VARCHAR2 (1);
        ln_line_count     NUMBER;
    --End Modification by BT Technology Team v1.3 on 23-APR-2014
    BEGIN
        l_request_id   := apps.fnd_global.conc_request_id;
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'l_request_id' || l_request_id);

        DELETE FROM xxdo.xxdopo_moq_surcharge_stg
              WHERE TRUNC (creation_date) <= TRUNC (SYSDATE) - 30;

        --Start Modification by BT Technology Team v1.3 on 23-APR-2014
        UPDATE xxdo.xxdopo_moq_surcharge_stg
           SET blended_fob = NVL (unit_price_fob, 0) + NVL (global_surcharge, 0) + NVL (ship_to_id_surcharge, 0)
         WHERE status = 'N';

        --End Modification by BT Technology Team v1.3 on 23-APR-2014

        COMMIT;
        apps.mo_global.init ('PO');

        FOR rec_header IN moq_surcharge
        LOOP
            FOR rec_line IN moq_surcharge_lines (rec_header.po_no, rec_header.style_no, rec_header.color
                                                 , rec_header.ship_loc_id)
            LOOP
                --Start Modification by BT Technology Team v1.3 on 23-APR-2014
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_line_count
                      FROM xxdopo_moq_surcharge_stg stg
                     WHERE     stg.po_no = rec_header.po_no
                           AND stg.po_line_id = rec_line.po_line_id
                           AND stg.style_no = rec_header.style_no
                           AND stg.color = rec_header.color
                           AND stg.ship_loc_id = rec_header.ship_loc_id
                           AND status = 'NEW';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_line_count   := 0;
                END;

                IF ln_line_count <> 0
                THEN
                    UPDATE xxdo.xxdopo_moq_surcharge_stg
                       SET status = 'SD', error_message = 'Duplicate Line', request_id = l_request_id
                     WHERE sno = rec_header.sno;

                    COMMIT;
                ELSE
                    --End Modification by BT Technology Team v1.3 on 23-APR-2014
                    INSERT INTO xxdo.xxdopo_moq_surcharge_stg (
                                    po_no,
                                    po_line_id,
                                    item_id,
                                    style_no,
                                    color,
                                    size_no,
                                    p_seq_no,
                                    shipment_num,
                                    promised_date,
                                    need_by_date,
                                    --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
                                    unit_price_fob,
                                    blended_fob,
                                    --End Modification by BT Technology Team v1.0 on 17-OCT-2014
                                    file_name, --Added by BT Technology Team v1.3 on 23-APR-2014
                                    ship_loc_id, --Added by BT Technology Team v1.3 on 23-APR-2014
                                    global_surcharge,
                                    ship_to_id_surcharge,
                                    creation_date,
                                    created_by,
                                    last_updated_by,
                                    last_update_date)
                         VALUES (rec_header.po_no, rec_line.po_line_id, rec_line.item_id, rec_header.style_no, rec_header.color, rec_line.segment3, rec_header.sno, rec_line.shipment_num, rec_line.promised_date, rec_line.need_by_date, --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
                                                                                                                                                                                                                                          rec_header.unit_price_fob, rec_header.blended_fob, --End Modification by BT Technology Team v1.0 on 17-OCT-2014
                                                                                                                                                                                                                                                                                             rec_header.file_name, --Added by BT Technology Team v1.3 on 23-APR-2014
                                                                                                                                                                                                                                                                                                                   rec_header.ship_loc_id, --Added by BT Technology Team v1.3 on 23-APR-2014
                                                                                                                                                                                                                                                                                                                                           rec_header.global_surcharge, rec_header.ship_to_id_surcharge, SYSDATE, apps.fnd_global.user_id
                                 , apps.fnd_global.user_id, SYSDATE);
                END IF;
            END LOOP;


            UPDATE xxdo.xxdopo_moq_surcharge_stg
               SET status = 'SD', request_id = l_request_id
             WHERE sno = rec_header.sno;

            UPDATE xxdo.xxdopo_moq_surcharge_stg
               SET status = 'NEW', request_id = l_request_id
             WHERE p_seq_no = rec_header.sno;

            COMMIT;
        END LOOP;



        FOR rec_lines IN moq_surcharge_all
        LOOP
            --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
            --Commented as this calculation is not used
            /*IF    rec_lines.attribute8 IS NOT NULL
               OR rec_lines.attribute9 IS NOT NULL
            THEN
               l_unit_price :=
                    rec_lines.unit_price
                  - NVL (rec_lines.attribute8, 0)
                  - NVL (rec_lines.attribute9, 0)
                  + NVL (rec_lines.global_surcharge, 0)
                  + NVL (rec_lines.ship_to_id_surcharge, 0);

            ELSE
               l_unit_price :=
                    rec_lines.unit_price
                  + NVL (rec_lines.global_surcharge, 0)
                  + NVL (rec_lines.ship_to_id_surcharge, 0);

            END IF;

            BEGIN
               SELECT revision_num
                 INTO l_revision_num
                 FROM apps.po_headers_all
                WHERE segment1 = rec_lines.po_no;
            EXCEPTION
               WHEN OTHERS
               THEN
                  l_revision_num := l_revision_num + 1;
            END;*/
            --End Modification by BT Technology Team v1.0 on 17-OCT-2014

            IF l_counter = 1
            THEN
                l_org_id    := rec_lines.org_id;
                apps.mo_global.set_policy_context ('S', l_org_id);
                l_counter   := l_counter + 1;
            ELSE
                IF l_org_id <> rec_lines.org_id
                THEN
                    apps.mo_global.set_policy_context ('S', rec_lines.org_id);
                    l_org_id   := rec_lines.org_id;
                END IF;
            END IF;


            BEGIN
                SELECT COUNT (apinv.invoice_num)
                  INTO l_invoice_count
                  FROM apps.po_lines_all pol, apps.po_headers_all poh, apps.ap_invoice_distributions_all apd,
                       apps.ap_invoices_all apinv, apps.po_distributions_all pod, apps.po_line_locations_all poll
                 WHERE     pol.po_line_id = poll.po_line_id
                       AND poh.po_header_id = pol.po_header_id
                       AND poll.line_location_id = pod.line_location_id
                       AND apd.invoice_id = apinv.invoice_id
                       AND pod.po_distribution_id = apd.po_distribution_id
                       AND pol.po_line_id = rec_lines.po_line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Exception in checking invoice number for PO line id'
                        || SQLERRM);
            END;


            IF l_invoice_count = 0
            THEN
                --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
                --Removed logic for storing old_unit_price
                /*IF rec_lines.attribute15 IS NULL
                THEN
                   l_old_unit_price := rec_lines.unit_price;
                ELSE
                   l_old_unit_price := rec_lines.attribute7;
                END IF;*/
                --End Modification by BT Technology Team v1.0 on 17-OCT-2014

                --Start Modification by BT Technology Team v1.3 on 23-APR-2014

                BEGIN
                    SELECT revision_num
                      INTO ln_revision_num
                      FROM apps.po_headers_all
                     WHERE segment1 = rec_lines.po_no;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_revision_num   := 1;
                END;

                --ln_revision_num := rec_lines.header_rev_num;
                --End Modification by BT Technology Team v1.3 on 23-APR-2014
                ln_line_num       := rec_lines.line_number;
                ln_shipment_num   := rec_lines.shipment_number;

                --Base table update to update attributes

                UPDATE po_lines_all
                   SET attribute_category = 'PO Data Elements', attribute8 = NVL (rec_lines.global_surcharge, 0), attribute9 = NVL (rec_lines.ship_to_id_surcharge, 0),
                       attribute11 = rec_lines.unit_price_fob
                 WHERE po_line_id = rec_lines.po_line_id;

                --Begin CCR0008186
                UPDATE po_line_locations_all
                   SET attribute6   = 'Y'
                 WHERE po_line_id = rec_lines.po_line_id;

                --End CCR0008186


                --Start Modification by BT Technology Team v1.3 on 23-APR-2014
                ln_result         := 1;
                lv_update_po      := 'Y';

                BEGIN
                    SELECT 'N'
                      INTO lv_update_po
                      FROM apps.po_lines_all pol
                     WHERE     pol.po_line_id = rec_lines.po_line_id
                           --AND attribute_category = 'PO Data Elements'
                           AND NVL (unit_price, 0) =
                               NVL (rec_lines.blended_fob, 0);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_update_po   := 'Y';
                    WHEN OTHERS
                    THEN
                        lv_update_po   := 'N';
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Exception in checking update PO line id'
                            || SQLERRM);
                END;

                IF lv_update_po = 'Y'
                THEN
                    --End Modification by BT Technology Team v1.3 on 23-APR-2014
                    ln_result   :=
                        po_change_api1_s.update_po (
                            x_po_number             => rec_lines.po_no,
                            x_release_number        => NULL,
                            x_revision_number       => ln_revision_num,
                            x_line_number           => ln_line_num,
                            x_shipment_number       => ln_shipment_num,
                            new_quantity            => NULL,
                            new_price               => rec_lines.blended_fob,
                            new_promised_date       => NULL,
                            new_need_by_date        => NULL,
                            --Start modification for Defect 683,Dt 18-Nov-15 by BT Tech Team
                            -- launch_approvals_flag   => 'Y',
                            launch_approvals_flag   => 'N',
                            --End modification for Defect 683,Dt 18-Nov-15 by BT Tech Team
                            update_source           => NULL,
                            version                 => '1.0',
                            x_override_date         => NULL,
                            x_api_errors            => l_api_errors,
                            p_buyer_name            => NULL,
                            p_secondary_quantity    => NULL,
                            p_preferred_grade       => NULL,
                            p_org_id                => l_org_id);

                    IF (ln_result <> 1)
                    THEN
                        -- Display the errors
                        --ROLLBACK; --Commented

                        BEGIN
                            FOR i IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                            LOOP
                                --Start Modification by BT Technology Team v1.3 on 23-APR-2014
                                /*UPDATE xxdo.xxdopo_moq_surcharge_stg
                                   SET status = 'ERROR',
                                       error_message =
                                             error_message
                                          || l_api_errors.MESSAGE_TEXT (i)
                                 WHERE     po_line_id = rec_lines.po_line_id
                                       AND request_id = l_request_id;*/
                                log_message (p_status => 'ERROR', p_msg => l_api_errors.MESSAGE_TEXT (i), p_po_line_id => rec_lines.po_line_id
                                             , p_request_id => l_request_id);
                            --End Modification by BT Technology Team v1.3 on 23-APR-2014
                            END LOOP;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;
                    ELSE
                        --Start Modification by BT Technology Team v1.3 on 23-APR-2014
                        /*UPDATE xxdo.xxdopo_moq_surcharge_stg
                           SET status = 'SUCCESS', error_message = NULL
                         WHERE     po_line_id = rec_lines.po_line_id
                               AND request_id = l_request_id;*/
                        log_message (p_status => 'SUCCESS', p_msg => NULL, p_po_line_id => rec_lines.po_line_id
                                     , p_request_id => l_request_id);
                    --COMMIT; --Commented by BT Technology Team v1.3 on 23-APR-2014
                    --End Modification by BT Technology Team v1.3 on 23-APR-2014
                    END IF;
                ELSE
                    --Start Modification by BT Technology Team v1.3 on 23-APR-2014
                    /*UPDATE xxdo.xxdopo_moq_surcharge_stg
                       SET status = 'ERROR',
                           error_message = 'PO amount is upto date.'
                     WHERE     po_line_id = rec_lines.po_line_id
                           AND request_id = l_request_id;*/

                    log_message (p_status => 'ERROR', p_msg => 'PO amount is upto date.', p_po_line_id => rec_lines.po_line_id
                                 , p_request_id => l_request_id);
                --End Modification by BT Technology Team v1.3 on 23-APR-2014
                --COMMIT; --Commented by BT Technology Team v1.3 on 23-APR-2014
                END IF;      --Added by BT Technology Team v1.3 on 23-APR-2014
            --Commneted as api is changed
            /*apps.po_lines_pkg_sud.update_row (
               x_rowid                         => rec_lines.ROWID,
               x_po_line_id                    => rec_lines.po_line_id,
               x_last_update_date              => SYSDATE,
               x_last_updated_by               => apps.fnd_global.user_id,
               x_po_header_id                  => rec_lines.po_header_id,
               x_line_type_id                  => rec_lines.line_type_id,
               x_line_num                      => rec_lines.line_num,
               x_last_update_login             => apps.fnd_global.login_id,
               x_item_id                       => rec_lines.item_id,
               x_item_revision                 => rec_lines.item_revision,
               x_category_id                   => rec_lines.category_id,
               x_item_description              => rec_lines.item_description,
               x_unit_meas_lookup_code         => rec_lines.unit_meas_lookup_code,
               x_quantity_committed            => rec_lines.quantity_committed,
               x_committed_amount              => rec_lines.committed_amount,
               x_allow_price_override_flag     => rec_lines.allow_price_override_flag,
               x_not_to_exceed_price           => rec_lines.not_to_exceed_price,
               x_list_price_per_unit           => rec_lines.list_price_per_unit,
               x_base_unit_price               => rec_lines.base_unit_price,
               --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
               --Passed blended_fob by BT Technology Team v1.0 on 17-OCT-2014
               x_unit_price                    => rec_lines.blended_fob, --l_unit_price,
               --End Modification by BT Technology Team v1.0 on 17-OCT-2014
               --rec_lines.Unit_Price
               x_quantity                      => rec_lines.quantity,
               x_un_number_id                  => rec_lines.un_number_id,
               x_hazard_class_id               => rec_lines.hazard_class_id,
               x_note_to_vendor                => rec_lines.note_to_vendor,
               x_from_header_id                => rec_lines.from_header_id,
               x_from_line_id                  => rec_lines.from_line_id,
               x_from_line_location_id         => rec_lines.from_line_location_id,
               x_min_order_quantity            => rec_lines.min_order_quantity,
               x_max_order_quantity            => rec_lines.max_order_quantity,
               x_qty_rcv_tolerance             => rec_lines.qty_rcv_tolerance,
               x_over_tolerance_error_flag     => rec_lines.over_tolerance_error_flag,
               x_market_price                  => rec_lines.market_price,
               x_unordered_flag                => rec_lines.unordered_flag,
               x_closed_flag                   => rec_lines.closed_flag,
               x_user_hold_flag                => rec_lines.user_hold_flag,
               x_cancel_flag                   => rec_lines.cancel_flag,
               x_cancelled_by                  => rec_lines.cancelled_by,
               x_cancel_date                   => rec_lines.cancel_date,
               x_cancel_reason                 => rec_lines.cancel_reason,
               --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
               x_firm_status_lookup_code       => rec_lines.firm_status_lookup_code, --'Y',
               --rec_lines.Firm_Status_Lookup_Code
               x_firm_date                     => rec_lines.firm_date, --SYSDATE,
               --rec_lines.Firm_Date
               --End Modification by BT Technology Team v1.0 on 17-OCT-2014
               x_vendor_product_num            => rec_lines.vendor_product_num,
               x_contract_num                  => rec_lines.contract_num,
               x_taxable_flag                  => rec_lines.taxable_flag,
               x_tax_code_id                   => rec_lines.tax_code_id,
               x_type_1099                     => rec_lines.type_1099,
               x_capital_expense_flag          => rec_lines.capital_expense_flag,
               x_negotiated_by_preparer_flag   => rec_lines.negotiated_by_preparer_flag,
               --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
               --Passed 'PO Data Elements' by BT Technology Team v1.0 on 17-OCT-2014
               x_attribute_category            => 'PO Data Elements', --rec_lines.attribute_category,
               --End Modification by BT Technology Team v1.0 on 17-OCT-2014
               x_attribute1                    => rec_lines.attribute1,
               x_attribute2                    => rec_lines.attribute2,
               x_attribute3                    => rec_lines.attribute3,
               x_attribute4                    => rec_lines.attribute4,
               x_attribute5                    => rec_lines.attribute5,
               x_attribute6                    => rec_lines.attribute6,
               x_attribute7                    => rec_lines.attribute7,
               --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
               x_attribute8                    => NVL (rec_lines.global_surcharge,0),
               x_attribute9                    => NVL (rec_lines.ship_to_id_surcharge,0),
               --End Modification by BT Technology Team v1.0 on 17-OCT-2014
               x_attribute10                   => rec_lines.attribute10,
               x_reference_num                 => rec_lines.reference_num,
               --unit_price_fob is passed to attribute11; BT Technology Team v1.0
               x_attribute11                   => rec_lines.unit_price_fob, --rec_lines.attribute11,
               x_attribute12                   => rec_lines.attribute12,
               x_attribute13                   => rec_lines.attribute13,
               x_attribute14                   => rec_lines.attribute14,
               x_attribute15                   => rec_lines.attribute15,
               x_min_release_amount            => rec_lines.min_release_amount,
               x_price_type_lookup_code        => rec_lines.price_type_lookup_code,
               x_closed_code                   => rec_lines.closed_code,
               x_price_break_lookup_code       => rec_lines.price_break_lookup_code,
               x_ussgl_transaction_code        => rec_lines.ussgl_transaction_code,
               x_government_context            => rec_lines.government_context,
               x_closed_date                   => rec_lines.closed_date,
               x_closed_reason                 => rec_lines.closed_reason,
               x_closed_by                     => rec_lines.closed_by,
               x_transaction_reason_code       => rec_lines.transaction_reason_code,
               x_global_attribute_category     => rec_lines.global_attribute_category,
               x_global_attribute1             => rec_lines.global_attribute1,
               x_global_attribute2             => rec_lines.global_attribute2,
               x_global_attribute3             => rec_lines.global_attribute3,
               x_global_attribute4             => rec_lines.global_attribute4,
               x_global_attribute5             => rec_lines.global_attribute5,
               x_global_attribute6             => rec_lines.global_attribute6,
               x_global_attribute7             => rec_lines.global_attribute7,
               x_global_attribute8             => rec_lines.global_attribute8,
               x_global_attribute9             => rec_lines.global_attribute9,
               x_global_attribute10            => rec_lines.global_attribute10,
               x_global_attribute11            => rec_lines.global_attribute11,
               x_global_attribute12            => rec_lines.global_attribute12,
               x_global_attribute13            => rec_lines.global_attribute13,
               x_global_attribute14            => rec_lines.global_attribute14,
               x_global_attribute15            => rec_lines.global_attribute15,
               x_global_attribute16            => rec_lines.global_attribute16,
               x_global_attribute17            => rec_lines.global_attribute17,
               x_global_attribute18            => rec_lines.global_attribute18,
               x_global_attribute19            => rec_lines.global_attribute19,
               x_global_attribute20            => rec_lines.global_attribute20,
               x_expiration_date               => rec_lines.expiration_date,
               x_base_uom                      => rec_lines.base_uom,
               x_base_qty                      => rec_lines.base_qty,
               x_secondary_uom                 => rec_lines.secondary_uom,
               x_secondary_qty                 => rec_lines.secondary_qty,
               x_qc_grade                      => rec_lines.qc_grade,
               x_oke_contract_header_id        => rec_lines.oke_contract_header_id,
               x_oke_contract_version_id       => rec_lines.oke_contract_version_id,
               x_secondary_unit_of_measure     => rec_lines.secondary_unit_of_measure,
               x_secondary_quantity            => rec_lines.secondary_quantity,
               x_preferred_grade               => rec_lines.preferred_grade,
               p_contract_id                   => rec_lines.contract_id,
               x_job_id                        => rec_lines.job_id,
               x_contractor_first_name         => rec_lines.contractor_first_name,
               x_contractor_last_name          => rec_lines.contractor_last_name,
               x_assignment_start_date         => rec_lines.start_date,
               x_amount_db                     => rec_lines.amount,
               p_manual_price_change_flag      => rec_lines.manual_price_change_flag,
               --Start Modification by BT Technology Team v1.0 on 17-OCT-2014
               p_ip_category_id                => rec_lines.ip_category_id
               --End Modification by BT Technology Team v1.0 on 17-OCT-2014
                                                                          );

            --Start Modification by BT Technology Team v1.1 on 05-FEB-2015
            BEGIN
               SELECT shipment_type INTO l_shipment_type
             FROM po_line_locations_all a
            WHERE po_header_id = rec_lines.po_header_id
              AND po_line_id = rec_lines.po_line_id;
            EXCEPTION
            WHEN OTHERS THEN
               l_shipment_type := NULL;
            END;
            IF po_shipments_sv2.update_shipment_price(x_po_line_id    => rec_lines.po_line_id,
                                              x_shipment_type => l_shipment_type,
                                              x_unit_price    => rec_lines.blended_fob)
            THEN
               fnd_file.put_line (fnd_file.LOG, 'Shipment price updated for po_line_id: '||rec_lines.po_line_id);
               UPDATE xxdo.xxdopo_moq_surcharge_stg
                  SET status = 'SUCCESS', error_message = NULL
             -- request_id = l_request_id
                WHERE po_line_id = rec_lines.po_line_id
                  AND request_id = l_request_id;
               COMMIT;
            ELSE
               UPDATE xxdo.xxdopo_moq_surcharge_stg
                  SET status = 'ERROR',
                      error_message = 'Errod updating Unit Price and Shipment Price'
             -- request_id = l_request_id
                WHERE po_line_id = rec_lines.po_line_id
                  AND request_id = l_request_id;
               ROLLBACK;
            END IF;*/
            --End Modification by BT Technology Team v1.2 on 23-FEB-2015
            /*UPDATE xxdo.xxdopo_moq_surcharge_stg
               SET status = 'SUCCESS', error_message = NULL
             -- request_id = l_request_id
             WHERE     po_line_id = rec_lines.po_line_id
                   AND request_id = l_request_id;

            COMMIT;*/
            --End Modification by BT Technology Team v1.1 on 05-FEB-2015
            ELSE
                --Start Modification by BT Technology Team v1.3 on 23-APR-2014
                /*UPDATE xxdo.xxdopo_moq_surcharge_stg
                   SET status = 'ERROR', error_message = 'PO is invoiced.'
                 WHERE     po_line_id = rec_lines.po_line_id
                       AND request_id = l_request_id;*/
                log_message (p_status => 'ERROR', p_msg => 'PO is invoiced.', p_po_line_id => rec_lines.po_line_id
                             , p_request_id => l_request_id);
            --End Modification by BT Technology Team v1.3 on 23-APR-2014
            --COMMIT; --Commented by BT Technology Team v1.3 on 23-APR-2014
            END IF;
        --COMMIT; --Commented by BT Technology Team v1.3 on 23-APR-2014
        END LOOP;

        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD (' ', 40, ' ')
            || ' '
            || RPAD ('MOQ Surcharge Program', 40, ' ')
            || ' '
            || RPAD (' ', 30, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD (' ', 40, ' ')
            || ' '
            || RPAD ('-', 21, '-')
            || ' '
            || RPAD (' ', 30, ' '));
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 60, '-'));
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'MOQ Surcharge Program - Errored Rows');
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 60, '-'));

        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 16, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 50, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('PO NUMBER', 15, ' ')
            || '|'
            || RPAD ('STYLE', 15, ' ')
            || '|'
            || RPAD ('COLOR', 10, ' ')
            || '|'
            || RPAD ('SIZE', 10, ' ')
            || '|'
            || RPAD ('OLD Price', 10, ' ')
            || '|'
            || RPAD ('New Price', 10, ' ')
            || '|'
            || RPAD ('Global Surcharge', 16, ' ')
            || '|'
            || RPAD ('Ship to id Surcharge', 20, ' ')
            || '|'
            || RPAD ('STATUS', 10, ' ')
            || '|'
            || RPAD ('ERROR MESSAGE', 50, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 16, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 50, '-'));

        FOR error_rec
            IN (SELECT stg.po_no, stg.style_no, stg.color,
                       stg.size_no, stg.global_surcharge, stg.ship_to_id_surcharge,
                       stg.status, stg.error_message, pol.unit_price,
                       pol.attribute8, pol.attribute9, (NVL (pol.unit_price, 0) - (NVL (pol.attribute8, 0) + NVL (pol.attribute9, 0))) AS old_price
                  FROM xxdo.xxdopo_moq_surcharge_stg stg, apps.po_lines_all pol
                 WHERE     stg.po_line_id = pol.po_line_id
                       AND stg.status = 'ERROR'
                       AND stg.request_id = l_request_id)
        LOOP
            BEGIN
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       RPAD (NVL (error_rec.po_no, ' '), 15, ' ')
                    || '|'
                    || RPAD (NVL (error_rec.style_no, ' '), 15, ' ')
                    || '|'
                    || RPAD (NVL (error_rec.color, ' '), 10, ' ')
                    || '|'
                    || RPAD (NVL (error_rec.size_no, ' '), 10, ' ')
                    || '|'
                    || RPAD (NVL (error_rec.old_price, ''), 10, ' ')
                    || '|'
                    || RPAD (NVL (error_rec.unit_price, ''), 10, ' ')
                    || '|'
                    || RPAD (NVL (error_rec.global_surcharge, '') || ' ',
                             16,
                             ' ')
                    || '|'
                    || RPAD (NVL (error_rec.ship_to_id_surcharge, '') || ' ',
                             20,
                             ' ')
                    || '|'
                    || RPAD (NVL (error_rec.status, ' '), 10, ' ')
                    || '|'
                    || RPAD (NVL (error_rec.error_message, ' '), 50, ' '));
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error in printing error records output file'
                        || SQLERRM);
            END;

            ln_row_cnt_e   := ln_row_cnt_e + 1;
        END LOOP;

        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 16, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 50, '-'));
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Errored Records Row Count: ' || ln_row_cnt_e);
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 60, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'MOQ Surcharge Program - Successfully Processed Rows');
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 60, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 16, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 50, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('PO NUMBER', 15, ' ')
            || '|'
            || RPAD ('STYLE', 15, ' ')
            || '|'
            || RPAD ('COLOR', 10, ' ')
            || '|'
            || RPAD ('SIZE', 10, ' ')
            || '|'
            || RPAD ('OLD Price', 10, ' ')
            || '|'
            || RPAD ('New Price', 10, ' ')
            || '|'
            || RPAD ('Global Surcharge', 16, ' ')
            || '|'
            || RPAD ('Ship to id Surcharge', 20, ' ')
            || '|'
            || RPAD ('STATUS', 10, ' ')
            || '|'
            || RPAD ('ERROR MESSAGE', 50, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 16, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 50, '-'));

        FOR success_rec
            IN (SELECT stg.po_no, stg.style_no, stg.color,
                       stg.size_no, stg.global_surcharge, stg.ship_to_id_surcharge,
                       stg.status, stg.error_message, pol.unit_price,
                       pol.attribute8, pol.attribute9, (NVL (pol.unit_price, 0) - (NVL (pol.attribute8, 0) + NVL (pol.attribute9, 0))) AS old_price
                  FROM xxdo.xxdopo_moq_surcharge_stg stg, apps.po_lines_all pol
                 WHERE     stg.po_line_id = pol.po_line_id
                       AND stg.status = 'SUCCESS'
                       AND stg.request_id = l_request_id)
        LOOP
            BEGIN
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       RPAD (NVL (success_rec.po_no, ' '), 15, ' ')
                    || '|'
                    || RPAD (NVL (success_rec.style_no, ' '), 15, ' ')
                    || '|'
                    || RPAD (NVL (success_rec.color, ' '), 10, ' ')
                    || '|'
                    || RPAD (NVL (success_rec.size_no, ' '), 10, ' ')
                    || '|'
                    || RPAD (NVL (success_rec.old_price, ''), 10, ' ')
                    || '|'
                    || RPAD (NVL (success_rec.unit_price, ''), 10, ' ')
                    || '|'
                    || RPAD (NVL (success_rec.global_surcharge, '') || ' ',
                             16,
                             ' ')
                    || '|'
                    || RPAD (
                           NVL (success_rec.ship_to_id_surcharge, '') || ' ',
                           20,
                           ' ')
                    || '|'
                    || RPAD (NVL (success_rec.status, ' '), 10, ' ')
                    || '|'
                    || RPAD (NVL (success_rec.error_message, ' '), 50, ' '));
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Error in printing Success records output file'
                        || SQLERRM);
            END;

            ln_row_cnt_s   := ln_row_cnt_s + 1;
        END LOOP;

        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 16, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 10, '-')
            || '|'
            || RPAD ('-', 50, '-'));
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Success Records Row Count: ' || ln_row_cnt_s);
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
    EXCEPTION
        WHEN OTHERS
        THEN
            ret_code   := 1;
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Exception =' || SQLERRM);
    END xxdo_moq_surcharge_proc;
END xxdopo_moq_surcharge_pkg;
/
