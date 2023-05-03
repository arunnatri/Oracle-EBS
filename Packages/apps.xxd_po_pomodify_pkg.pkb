--
-- XXD_PO_POMODIFY_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_POMODIFY_PKG"
IS
    /****************************************************************************************
    * Package      : XXD_PO_POMODIFY_PKG
    * Design       : This package is used to modify purcahse order from PO Modify Utility OA Page
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 16-Aug-2019  1.0        Tejaswi Gangumalla      Initial version
    -- 13-Apr-2020  1.1        Tejaswi Gangumalla      CCR0008501
    -- 07-Jul-2020  2.0        Gaurav Joshi            CCR0008752    PO Reroutes for Direct Ship POs
    -- 29-Jun-2021  3.0        Gaurav Joshi            CCR0009391 - PO Modify Utility Bug
    -- 03-Sep-2021  4.0        Gaurav Joshi           CCR0009570 - performance imp and other fix
    -- 25-May-2022  5.0        Aravind Kannuri         CCR0010003 - POC Enhancements
    ******************************************************************************************/
    gn_po_type   VARCHAR2 (240);                                    -- VER 2.0

    PROCEDURE lock_po (pn_batch_id       IN     NUMBER,
                       pn_po_header_id   IN     NUMBER,
                       pv_error_msg         OUT VARCHAR2)
    IS
    BEGIN
        --Lock po lines
        BEGIN
            FOR i
                IN (    SELECT pla.po_line_id
                          FROM po_lines_all pla, xxdo.xxd_po_modify_details_t xxd
                         WHERE     xxd.batch_id = pn_batch_id
                               AND xxd.source_po_header_id = pn_po_header_id
                               AND xxd.status = 'N'
                               AND xxd.source_po_header_id = pla.po_header_id
                               AND xxd.source_po_line_id = pla.po_line_id
                    FOR UPDATE NOWAIT)
            LOOP
                NULL;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_msg   :=
                    'One or more po line is locked by another user';
        END;

        --Lock po distributions
        BEGIN
            FOR i
                IN (    SELECT pda.po_distribution_id
                          FROM po_distributions_all pda, xxdo.xxd_po_modify_details_t xxd
                         WHERE     xxd.batch_id = pn_batch_id
                               AND xxd.source_po_header_id = pn_po_header_id
                               AND xxd.status = 'N'
                               AND xxd.source_po_header_id = pda.po_header_id
                               AND xxd.source_po_line_id = pda.po_line_id
                    FOR UPDATE NOWAIT)
            LOOP
                NULL;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_error_msg   :=
                    'One or more po distribution line is locked by another user';
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg   :=
                'Error While Locking Po Lines and Distributions' || SQLERRM;
    END lock_po;

    PROCEDURE upload_proc (p_user_id IN NUMBER, p_resp_id IN NUMBER, p_seq_number IN NUMBER, p_po_number IN NUMBER, p_org_id IN NUMBER, p_action IN VARCHAR2, p_to_po_number IN NUMBER, p_dest_org_id IN NUMBER, p_style_color IN xxd_style_color_type
                           , p_vendor_id IN NUMBER, p_vendor_site_id IN NUMBER, p_err_msg OUT VARCHAR2)
    IS
        lv_error_message               VARCHAR2 (4000);
        ln_move_po_header_id           NUMBER;
        ln_item_count                  NUMBER;
        ln_po_item_count               NUMBER;
        ln_pr_header_id                NUMBER;
        ln_pr_line_id                  NUMBER;
        ln_iso_header_id               NUMBER;
        ln_iso_line_id                 NUMBER;
        ln_source_doc_id               NUMBER;
        ln_ir_header_id                NUMBER;
        ln_ir_line_id                  NUMBER;
        ln_inprocess_count             NUMBER;
        ln_drop_ship_id                NUMBER;
        ln_ret_code                    NUMBER;
        ln_qty_billed                  NUMBER;
        ln_qty_received                NUMBER;
        ln_asn_line_count              NUMBER;
        ln_source_po_header_id         NUMBER;
        ld_creation_date               DATE := SYSDATE;
        ln_user_id            CONSTANT NUMBER := p_user_id;
        ln_resp_id            CONSTANT NUMBER := p_resp_id;
        ln_batch_id           CONSTANT NUMBER := p_seq_number;
        ln_source_po_num      CONSTANT VARCHAR2 (100) := TO_CHAR (p_po_number);
        ln_org_id             CONSTANT NUMBER := p_org_id;
        ln_dest_inv_org_id    CONSTANT NUMBER := p_dest_org_id;
        ln_supplier_id        CONSTANT NUMBER := p_vendor_id;
        ln_supplier_site_id   CONSTANT NUMBER := p_vendor_site_id;
        l_err                          VARCHAR2 (100);
        ln_item_id                     NUMBER;
        ln_error_count                 NUMBER := 0;
        ln_dest_style_color_count      NUMBER := 0;
        ln_move_org_id                 NUMBER;
        ln_org_id_diff_flag            VARCHAR2 (2);
        lv_intercompany_flag           VARCHAR (2);
        ln_source_po_lines_count       NUMBER;
        ln_stg_po_lines_count          NUMBER;
        ln_po_header_cancel_flag       VARCHAR2 (2);
        ln_iso_header_id_stg           NUMBER;
        ln_source_iso_lines_count      NUMBER;
        ln_stg_iso_lines_count         NUMBER;
        ln_iso_header_cancel_flag      VARCHAR2 (2);
        ln_ret_days                    NUMBER;
        lv_intercompany_validation     VARCHAR2 (2);
        ln_vendor_id                   NUMBER;
        ln_vendor_site_id              NUMBER;
        ln_vendor_site_code            VARCHAR2 (100);
        lv_stg_status                  VARCHAR2 (2);
        lv_stg_error_msg               VARCHAR2 (2000);
        ln_move_po_org_id_id           NUMBER;
        ln_dest_vendor_id              NUMBER;
        ln_dest_vendor_site_id         NUMBER;
        ln_dest_ship_to_location_id    NUMBER;
        ln_ship_to_location_id         NUMBER;
        ln_dest_org_count              NUMBER;
        ln_source_SO                   NUMBER;                      -- ver 2.0
        ln_target_SO                   NUMBER;                      -- ver 2.0
        ln_suggested_po                VARCHAR2 (2000);             -- ver 2.0
        ln_order_number                NUMBER;                      -- ver 2.0
        ln_prev_inprogress_source_SO   NUMBER;                      -- ver 3.0
        ln_request_id                  NUMBER;                      -- ver 3.0
        ln_tq_po_so                    NUMBER;                     -- ver 3.0;
        ln_tq_po_factory_po            NUMBER;                      -- ver 3.0
        l_tq_po_count                  NUMBER;                      -- ver 3.0
        lv_po_type                     VARCHAR2 (100); -- ver 3.0 this is manily for direct procurement PO
        ln_distributor_po_count        NUMBER;                      -- ver 3.0
        exit_validation_exception      EXCEPTION;                   -- ver 3.0
        l_jp_tq_so_count               NUMBER;                      -- VER 3.0
        ln_source_SO_hdr_id            NUMBER;                     --  VER 3.0

        CURSOR po_lines_det_cur IS
              SELECT pda.req_distribution_id, pla.po_header_id, pla.po_line_id,
                     -- pla.quantity, -- ver 3.0 commented
                     (plla.quantity - plla.quantity_cancelled) quantity, -- ver 3.0 added
                                                                         plla.line_location_id, plla.need_by_date,
                     itm.style_number || '-' || itm.color_code style_color, itm.item_number
                FROM po_lines_all pla, po_line_locations_all plla, po_distributions_all pda,
                     xxd_common_items_v itm, TABLE (p_style_color) p_style_color_tab
               WHERE     1 = 1
                     AND pla.po_header_id = ln_source_po_header_id
                     AND pla.po_header_id = plla.po_header_id
                     AND pla.po_line_id = plla.po_line_id
                     AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                     AND NVL (pla.cancel_flag, 'N') = 'N'
                     AND NVL (plla.cancel_flag, 'N') = 'N' --Added for change 1.1
                     AND pla.item_id = itm.inventory_item_id
                     AND pla.po_header_id = pda.po_header_id
                     AND pla.po_line_id = pda.po_line_id
                     AND plla.line_location_id = pda.line_location_id
                     --Added for change 1.1
                     AND TRUNC (plla.need_by_date) =
                         TO_DATE (p_style_color_tab.needby_date, 'DD/MM/YYYY')
                     AND plla.quantity_received = 0
                     AND itm.organization_id = plla.ship_to_organization_id
                     AND itm.style_number = p_style_color_tab.style
                     AND itm.color_code = p_style_color_tab.color
                     /* AND NOT EXISTS   -- commented FOR CCR0009570  ver 4.0
                                (SELECT 1
                                   FROM custom.do_items di
                                  WHERE     di.order_id = pla.po_header_id
                                        AND di.order_line_id = pla.po_line_id
                                        AND di.entered_quantity IS NOT NULL) */
                     AND NOT EXISTS            -- added FOR CCR0009570 ver 4.0
                             (SELECT 1
                                FROM rcv_shipment_lines rsl
                               WHERE     rsl.po_header_id = pla.po_header_id
                                     AND rsl.shipment_line_status_code <>
                                         'CANCELLED')
                     AND NOT EXISTS            -- added for CCR0009570 ver 4.0
                             (SELECT 1
                                FROM apps.rcv_transactions_interface rti
                               WHERE     rti.interface_source_code = 'RCV'
                                     AND rti.source_document_code = 'PO'
                                     AND rti.po_header_id = pla.po_header_id)
            ORDER BY pla.line_num;

        CURSOR move_org_validation_cur IS
            SELECT DISTINCT item_number, move_inv_org_id
              FROM xxd_po_modify_details_t
             WHERE action_type = 'Move Org' AND batch_id = ln_batch_id;

        CURSOR style_color_validation_cur IS
            SELECT DISTINCT p_style_color_tab.style, p_style_color_tab.color
              FROM po_lines_all pla, po_line_locations_all plla, po_distributions_all pda,
                   xxd_common_items_v itm, TABLE (p_style_color) p_style_color_tab
             WHERE     1 = 1
                   AND pla.po_header_id = ln_source_po_header_id
                   AND pla.po_header_id = plla.po_header_id
                   AND pla.po_line_id = plla.po_line_id
                   AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                   AND NVL (pla.cancel_flag, 'N') = 'N'
                   AND pla.item_id = itm.inventory_item_id
                   AND pla.po_header_id = pda.po_header_id
                   AND pla.po_line_id = pda.po_line_id
                   AND itm.organization_id = plla.ship_to_organization_id
                   AND itm.style_number = p_style_color_tab.style
                   AND itm.color_code = p_style_color_tab.color
                   AND TRUNC (plla.need_by_date) =
                       TO_DATE (p_style_color_tab.needby_date, 'DD/MM/YYYY')
                   --check only for direct procurement organizations
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values flv, org_organization_definitions ood
                             WHERE     flv.lookup_type =
                                       'XXD_PO_MOVEPO_INV_ORG'
                                   AND flv.LANGUAGE = 'US'
                                   AND LOWER (flv.description) = 'direct'
                                   AND flv.meaning = ood.organization_code
                                   AND ood.organization_id =
                                       plla.ship_to_organization_id)
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE));
    BEGIN
        --Get retentions days to purge staing table
        SELECT apps.fnd_profile.VALUE ('XXD_PO_MODIFCATION_RETENTION_DAYS')
          INTO ln_ret_days
          FROM DUAL;

        --Purging Staging Table
        BEGIN
            DELETE FROM
                xxd_po_modify_details_t
                  WHERE TRUNC (creation_date) <=
                        TRUNC (SYSDATE - NVL (ln_ret_days, 180));
        EXCEPTION
            WHEN OTHERS
            THEN
                p_err_msg   := 'Error while purging staging table';
        END;

        BEGIN
            SELECT COUNT (*)
              INTO ln_inprocess_count
              FROM xxd_po_modify_details_t stg, TABLE (p_style_color) p_style_color_tab
             WHERE     stg.source_po_header_id = ln_source_po_header_id
                   AND stg.status = 'N'
                   AND stg.style_color =
                          p_style_color_tab.style
                       || '-'
                       || p_style_color_tab.color
                   AND stg.org_id = p_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_err_msg   := 'Error while checking if po is in progress';
        END;

        IF ln_inprocess_count > 0
        THEN
            p_err_msg   := 'Purchase order is already in process';
            RETURN;
        END IF;

        --Get PO header_id
        BEGIN
            SELECT pha.po_header_id, pha.vendor_id, pha.vendor_site_id,
                   apsa.vendor_site_code, pha.ship_to_location_id, pha.attribute10
              INTO ln_source_po_header_id, ln_vendor_id, ln_vendor_site_id, ln_vendor_site_code,
                                         ln_ship_to_location_id, gn_po_type -- ver 2.0 getting PO type for direct_ship
              FROM po_headers_all pha, ap_supplier_sites_all apsa
             WHERE     pha.vendor_site_id = apsa.vendor_site_id
                   AND pha.segment1 = ln_source_po_num
                   AND apsa.org_id = ln_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_err_msg   := 'Invalid PO Number';
                RETURN;
        END;

        IF p_action = 'Move Org'
        THEN
            BEGIN
                SELECT operating_unit
                  INTO ln_move_org_id
                  FROM org_organization_definitions
                 WHERE organization_id = ln_dest_inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_err_msg   := 'Invalid Destination Org';
                    RETURN;
            END;

            IF ln_move_org_id <> ln_org_id
            THEN
                ln_org_id_diff_flag   := 'Y';
            ELSE
                ln_org_id_diff_flag   := 'N';
            END IF;

            --Supplier site validation
            BEGIN
                SELECT vendor_site_id
                  INTO ln_vendor_site_id
                  FROM ap_supplier_sites_all
                 WHERE     vendor_id = ln_vendor_id
                       AND org_id = ln_move_org_id
                       AND (inactive_date IS NULL OR TRUNC (inactive_date) >= TRUNC (SYSDATE))
                       AND vendor_site_code = ln_vendor_site_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        'No Active Vendor Site Code For Vendor In Destination Org';
            END;
        END IF;

        IF p_action = 'Move'
        THEN
            --getting move_po_header_id
            BEGIN
                SELECT po_header_id, org_id, vendor_id,
                       vendor_site_id, ship_to_location_id
                  INTO ln_move_po_header_id, ln_move_po_org_id_id, ln_dest_vendor_id, ln_dest_vendor_site_id,
                                           ln_dest_ship_to_location_id
                  FROM po_headers_all
                 WHERE     segment1 = p_to_po_number
                       AND NVL (closed_code, 'OPEN') = 'OPEN'
                       AND NVL (cancel_flag, 'N') = 'N';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        'Invalid Move PO: ' || p_to_po_number;
            END;

            IF ln_move_po_org_id_id <> ln_org_id
            THEN
                lv_error_message   :=
                    'Souce PO and Target PO operating units are different';
            END IF;

            IF    ln_vendor_id <> ln_dest_vendor_id
               OR ln_vendor_site_id <> ln_dest_vendor_site_id
            THEN
                lv_error_message   :=
                    'Supplier/Supplier Site is different in source and target POs';
            END IF;

            IF ln_ship_to_location_id <> ln_dest_ship_to_location_id
            THEN
                lv_error_message   :=
                    'Source PO and Target PO ship to location id are different';
            END IF;

            -- Begin ver 2.0 -- get the Source and destination SO to validate ONLy for direct_ship
            IF UPPER (gn_po_type) = 'DIRECT_SHIP'
            THEN
                BEGIN
                    SELECT DISTINCT order_number, oha.header_id
                      INTO ln_source_SO, ln_source_SO_hdr_id
                      FROM oe_order_headers_all oha, oe_order_lines_all ool, po_line_locations_all plla
                     WHERE     oha.header_id = ool.header_id
                           AND po_header_id = ln_source_po_header_id
                           AND ool.attribute16 =
                               TO_CHAR (plla.line_location_id);
                EXCEPTION
                    WHEN TOO_MANY_ROWS
                    THEN
                        p_err_msg   := 'Source PO is linked with Mutiple SO';
                        RETURN;
                    WHEN NO_DATA_FOUND
                    THEN
                        p_err_msg   := 'Source PO is not linked with any SO';
                        RETURN;
                    WHEN OTHERS
                    THEN
                        p_err_msg   :=
                            'Unexpected error while trying to fetch sales order for Direct ship PO';
                        RETURN;
                END;

                BEGIN
                    SELECT DISTINCT order_number
                      INTO ln_target_SO
                      FROM oe_order_headers_all oha, oe_order_lines_all ool, po_line_locations_all plla
                     WHERE     oha.header_id = ool.header_id
                           AND po_header_id = ln_move_po_header_id
                           AND ool.attribute16 =
                               TO_CHAR (plla.line_location_id);
                EXCEPTION
                    WHEN TOO_MANY_ROWS
                    THEN
                        p_err_msg   := 'Target PO is linked with Mutiple SO';
                        RETURN;
                    WHEN NO_DATA_FOUND
                    THEN
                        p_err_msg   := 'Target PO is not linked with any SO';
                        RETURN;
                    WHEN OTHERS
                    THEN
                        p_err_msg   :=
                            'Unexpected error while trying to fetch Target sales order for Direct ship PO';
                        RETURN;
                END;

                IF ln_source_SO <> ln_target_SO
                THEN
                    -- use the source SO and get associated PO for suggestiong
                    BEGIN
                        SELECT LISTAGG (segment1, ',') WITHIN GROUP (ORDER BY segment1)
                          INTO ln_suggested_po
                          FROM (  SELECT segment1
                                    FROM oe_order_headers_all oha, oe_order_lines_all ool, po_line_locations_all plla,
                                         po_headers_all pha
                                   WHERE     oha.order_number = ln_source_SO
                                         AND oha.header_id = ool.header_id
                                         AND pha.po_header_id =
                                             plla.po_header_id
                                         AND pha.po_header_id <>
                                             ln_source_po_header_id
                                         AND ool.attribute16 =
                                             TO_CHAR (plla.line_location_id)
                                GROUP BY pha.segment1) a;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_err_msg   :=
                                'Unexpected error while trying to fetch PO suggestion for Direct ship PO sharing same SO';
                            RETURN;
                    END;

                    IF ln_suggested_po IS NULL
                    THEN
                        p_err_msg   :=
                            'Move operation cannot be done as their is not other PO exists having the same SO';
                        RETURN;
                    END IF;

                    p_err_msg   :=
                           'Source and destination direct ship PO’s does not share the same Sales order number. Suggested Purchase order for Move -'
                        || ln_suggested_po;
                    RETURN;
                END IF;
            END IF;

            -- End  ver 2.0
            --Check if PO is intercompnay po
            BEGIN
                SELECT COUNT (*)
                  INTO ln_dest_org_count
                  FROM po_lines_all pla, po_line_locations_all plla, po_distributions_all pda,
                       xxd_common_items_v itm, TABLE (p_style_color) p_style_color_tab
                 WHERE     1 = 1
                       AND pla.po_header_id = ln_source_po_header_id
                       AND pla.po_header_id = plla.po_header_id
                       AND pla.po_line_id = plla.po_line_id
                       AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                       AND NVL (pla.cancel_flag, 'N') = 'N'
                       AND pla.item_id = itm.inventory_item_id
                       AND pla.po_header_id = pda.po_header_id
                       AND pla.po_line_id = pda.po_line_id
                       AND itm.organization_id = plla.ship_to_organization_id
                       AND TRUNC (plla.need_by_date) =
                           TO_DATE (p_style_color_tab.needby_date,
                                    'DD/MM/YYYY')
                       AND itm.style_number = p_style_color_tab.style
                       AND itm.color_code = p_style_color_tab.color
                       AND EXISTS
                               (SELECT 1
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     flv.lookup_type =
                                           'XXD_PO_MOVEPO_INV_ORG'
                                       AND flv.LANGUAGE = 'US'
                                       AND LOWER (flv.description) =
                                           'intercompany'
                                       AND enabled_flag = 'Y'
                                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                       NVL (
                                                                           start_date_active,
                                                                           SYSDATE))
                                                               AND TRUNC (
                                                                       NVL (
                                                                           end_date_active,
                                                                           SYSDATE))
                                       AND flv.meaning =
                                           ood.organization_code
                                       AND ood.organization_id =
                                           plla.ship_to_organization_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                        'Invalid Move PO: ' || p_to_po_number;
            END;

            IF ln_dest_org_count > 0
            THEN
                --If intercaompany po source and destination po must have same destination org for IR
                IF xxd_po_pomodify_utils_pkg.get_destination_org (
                       ln_source_po_header_id) <>
                   xxd_po_pomodify_utils_pkg.get_destination_org (
                       ln_move_po_header_id)
                THEN
                    lv_error_message   :=
                        'End destination is different in source and target POs';
                END IF;
            END IF;

            FOR style_color_validation_rec IN style_color_validation_cur
            LOOP
                BEGIN
                    SELECT COUNT (*)
                      INTO ln_dest_style_color_count
                      FROM po_lines_all pla, xxd_common_items_v itm, TABLE (p_style_color) p_style_color_tab,
                           mtl_parameters mp
                     WHERE     1 = 1
                           AND pla.item_id = itm.inventory_item_id
                           AND itm.color_code =
                               style_color_validation_rec.color
                           AND itm.style_number =
                               style_color_validation_rec.style
                           AND mp.organization_code = 'MST' --Master organization
                           AND mp.organization_id = itm.organization_id
                           AND pla.po_header_id = ln_move_po_header_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_dest_style_color_count   := 0;
                END;

                IF ln_dest_style_color_count = 0
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || ' Style-Color '
                        || style_color_validation_rec.style
                        || '-'
                        || style_color_validation_rec.color
                        || ' does not exist in destination purchase order';
                END IF;
            END LOOP;
        END IF;

        IF lv_error_message IS NULL
        THEN
            FOR po_lines_det_rec IN po_lines_det_cur
            LOOP
                ln_pr_header_id                := NULL;
                ln_pr_line_id                  := NULL;
                ln_iso_header_id               := NULL;
                ln_iso_line_id                 := NULL;
                ln_source_doc_id               := NULL;
                ln_ir_header_id                := NULL;
                ln_ir_line_id                  := NULL;
                lv_error_message               := NULL;
                ln_prev_inprogress_source_SO   := NULL;             -- ver 3.0
                ln_request_id                  := NULL;             -- ver 3.0
                ln_tq_po_so                    := NULL;            -- ver 3.0;
                ln_tq_po_factory_po            := NULL;             -- ver 3.0
                l_tq_po_count                  := NULL;             -- ver 3.0
                lv_po_type                     := NULL; -- ver 3.0 this is manily for direct procurement PO
                ln_distributor_po_count        := NULL;

                --Getting requistion details
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
                ELSE
                    lv_stg_status      := 'E';
                    --Vis
                    lv_stg_error_msg   := 'PR not available for this PO line';
                END IF;

                --Check if po is intercompany
                BEGIN
                    SELECT 'Y'
                      INTO lv_intercompany_flag
                      FROM mtl_reservations mr, oe_order_lines_all oola, po_requisition_lines_all prla,
                           mtl_parameters mp
                     WHERE     mr.demand_source_line_id = oola.line_id
                           AND oola.source_document_line_id =
                               prla.requisition_line_id
                           AND prla.destination_organization_id =
                               mp.organization_id
                           AND mr.supply_source_header_id =
                               po_lines_det_rec.po_header_id
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --not intercaompany
                        lv_intercompany_flag   := 'N';
                END;

                IF    lv_intercompany_flag = 'Y'
                   OR UPPER (gn_po_type) = 'DIRECT_SHIP'
                THEN
                    --Getting ISO details
                    BEGIN
                        SELECT ool.header_id, ool.line_id, ool.source_document_line_id,
                               'Y'
                          INTO ln_iso_header_id, ln_iso_line_id, ln_source_doc_id, lv_intercompany_flag
                          FROM oe_order_headers_all ooh, oe_order_lines_all ool
                         WHERE     ooh.header_id = ool.header_id
                               AND NVL (ool.CONTEXT, 'A') != 'DO eCommerce'
                               AND ool.attribute16 =
                                   TO_CHAR (
                                       po_lines_det_rec.line_location_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            --no iso for PO
                            ln_iso_header_id   := NULL;
                            ln_iso_line_id     := NULL;
                    --    lv_intercompany_flag := 'N';
                    END;

                    -- ver 2.0 Begin check for hold on SO on DS orders

                    IF UPPER (gn_po_type) = 'DIRECT_SHIP'
                    THEN
                        ln_order_number   := NULL;

                        BEGIN
                            SELECT order_number
                              INTO ln_order_number
                              FROM oe_order_holds_all a, oe_order_headers_all b
                             WHERE     a.header_id = b.header_id
                                   AND a.header_id = ln_iso_header_id
                                   AND released_flag = 'N'
                                   AND hold_release_id IS NULL; --- hold is there in the order
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;

                        IF ln_order_number IS NOT NULL
                        THEN
                            p_err_msg   :=
                                   'Hold exists on direct ship SO# '
                                || ln_order_number
                                || ' , this action can''t be performed';
                            RETURN;
                        END IF;
                    END IF;

                    -- ver 2.0 End check for hold on SO on DS orders

                    --Getting IR details
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

                    IF ln_iso_header_id IS NULL
                    THEN
                        lv_stg_status   := 'E';
                        lv_stg_error_msg   :=
                            'Back to Back Order link not established between SO and PO';
                    ELSIF NVL (lv_stg_status, 'N') = 'N'
                    THEN
                        lv_stg_status      := 'N';
                        lv_stg_error_msg   := '';
                    END IF;
                ELSIF NVL (lv_stg_status, 'N') = 'N'
                THEN
                    lv_stg_status      := 'N';
                    lv_stg_error_msg   := '';
                END IF;

                BEGIN
                    SELECT drop_ship_source_id
                      INTO ln_drop_ship_id
                      FROM oe_drop_ship_sources
                     WHERE     po_header_id = po_lines_det_rec.po_header_id
                           AND po_line_id = po_lines_det_rec.po_line_id
                           AND line_location_id =
                               po_lines_det_rec.line_location_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_drop_ship_id   := NULL;
                    WHEN OTHERS
                    THEN
                        ln_drop_ship_id   := NULL;
                END;

                -- begin  ver 3.0
                -- distributor PO
                SELECT COUNT (*)
                  INTO ln_distributor_po_count
                  FROM po_headers_all
                 WHERE     attribute10 = 'INTL_DEST'
                       AND po_header_id = ln_source_po_header_id
                       AND xxd_po_pomodify_utils_pkg.get_destination_org (
                               ln_source_po_header_id) IN
                               ('MC2');

                IF ln_distributor_po_count > 0
                THEN
                    BEGIN
                        SELECT request_id
                          INTO ln_request_id
                          FROM xxd_po_modify_details_t
                         WHERE     status = 'N'
                               AND SOURCE_PR_HEADER_ID = ln_pr_header_id
                               AND batch_id <> ln_batch_id
                               AND request_id IS NOT NULL
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
                /*
                               IF ln_request_id IS NOT NULL
                               THEN
                                  lv_stg_status := 'E';
                                  p_err_msg :=
                                        'PR referring to this Distributor PO is currently in progress via Request id '
                                     || ln_request_id
                                     || '.let this request complete and try again later.';
                                  --  RETURN;
                                  RAISE exit_validation_exception;
                               END IF; */
                END IF;

                -- Direct Procurement PO
                lv_po_type                     :=
                    XXD_PO_GET_PO_TYPE (ln_source_po_header_id); -- if this has standard means its a direct procuremnet PO

                IF lv_po_type = 'STANDARD'
                THEN
                    BEGIN
                        SELECT request_id
                          INTO ln_request_id
                          FROM xxd_po_modify_details_t a
                         WHERE     status = 'N'
                               AND batch_id <> ln_batch_id
                               AND request_id IS NOT NULL
                               AND EXISTS
                                       (SELECT *
                                          FROM po_headers_all pha, po_distributions_all pda, po_req_distributions_all prda,
                                               po_requisition_lines_all prla, po_requisition_headers_all prha
                                         WHERE     pha.po_header_id =
                                                   pda.po_header_id
                                               AND pda.req_distribution_id =
                                                   prda.distribution_id
                                               AND prda.requisition_line_id =
                                                   prla.requisition_line_id
                                               AND prla.requisition_header_id =
                                                   prha.requisition_header_id
                                               AND pha.po_header_id =
                                                   ln_source_po_header_id
                                               AND prha.requisition_header_id =
                                                   a.SOURCE_PR_HEADER_ID)
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
                /*
                               IF ln_request_id IS NOT NULL
                               THEN
                                  lv_stg_status := 'E';
                                  p_err_msg :=
                                        'PR referring to this Direct Procurement PO is currently in progress via Request id '
                                     || ln_request_id
                                     || '.let this request complete and try again later.';
                                  -- RETURN;
                                  RAISE exit_validation_exception;
                               END IF; */
                END IF;

                --  intercompany po
                IF lv_intercompany_flag = 'Y'
                THEN
                    -- If multiple PO modify requests are submitted for Intercompany PO’s and if the PO’s are referring to same Factory PR or ISO/IR
                    -- do not process
                    BEGIN
                        SELECT request_id
                          INTO ln_request_id
                          FROM xxd_po_modify_details_t
                         WHERE     status = 'N'
                               AND batch_id <> ln_batch_id
                               AND (SOURCE_PR_HEADER_ID = ln_pr_header_id OR (SOURCE_ISO_HEADER_ID = ln_iso_header_id AND SOURCE_IR_HEADER_ID = ln_ir_header_id))
                               AND request_id IS NOT NULL
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
                /*
                             IF ln_request_id IS NOT NULL
                             THEN
                                lv_stg_status := 'E';
                                p_err_msg :=
                                      'PR/ISO/IR referring to this Intercompany PO is currently in progress via Request id '
                                   || ln_request_id
                                   || '.let this request complete and try again later.';
                                --RETURN;

                               -- RAISE exit_validation_exception;
                             END IF;
                             */
                END IF;

                -- direct ship po
                IF gn_po_type = 'DIRECT_SHIP'
                THEN
                    -- getting the SO of the pending request in the custom table for the same source SO.
                    BEGIN
                        SELECT request_id
                          INTO ln_request_id
                          FROM xxd_po_modify_details_t
                         WHERE     status = 'N'
                               AND SOURCE_ISO_HEADER_ID = ln_source_SO_hdr_id
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_request_id   := NULL;
                    END;

                    /*   SELECT order_number, pmd.request_id
                         INTO ln_prev_inprogress_source_SO, ln_request_id
                         FROM oe_order_headers_all oha,
                              oe_order_lines_all ool,
                              po_line_locations_all plla,
                              xxd_po_modify_details_t pmd
                        WHERE     oha.header_id = ool.header_id
                              AND po_header_id = pmd.source_po_header_id
                              AND ool.attribute16 = TO_CHAR (plla.line_location_id)
                              AND status = 'N'
                              AND ROWNUM = 1;
                              */

                    IF ln_request_id IS NOT NULL
                    THEN
                        NULL; -- this is a wait condition and ln_request_id has got the rquest id
                    ELSE
                        ln_request_id   := NULL; -- no wait condition; set null in request id
                    --   lv_stg_status := 'E';
                    --   p_err_msg :=
                    --     'SO referring to this Direct Ship PO is currently in process. pls try again in sometime.';
                    --   RETURN;
                    -- RAISE exit_validation_exception;
                    END IF;
                END IF;

                -- Japan TQ
                SELECT COUNT (*)
                  INTO l_tq_po_count
                  FROM po_headers_all pha
                 WHERE     po_header_id = ln_source_po_header_id
                       AND EXISTS
                               (SELECT *
                                  FROM FND_LOOKUP_VALUES
                                 WHERE     lookup_type =
                                           'XXD_PO_TQ_PRICE_RULE_VENDORS'
                                       AND NVL (start_date_active, SYSDATE) <=
                                           SYSDATE
                                       AND NVL (end_date_active, SYSDATE) >=
                                           SYSDATE
                                       AND NVL (enabled_flag, 'N') = 'Y'
                                       AND language = USERENV ('LANG')
                                       AND meaning = pha.vendor_id);

                IF l_tq_po_count > 0
                THEN                                         -- its a JP tq PO
                    BEGIN
                        SELECT ORDER_NUMBER, PHA1.SEGMENT1
                          INTO ln_tq_po_so, ln_tq_po_factory_po
                          FROM apps.oe_drop_ship_sources ods, apps.oe_order_headers_all ooh, apps.po_headers_all pha,
                               po_requisition_lines_all PLA, PO_LINE_LOCATIONS_ALL PLLA, apps.po_headers_all pha1
                         WHERE     1 = 1
                               AND ods.header_id = ooh.header_id
                               AND ooh.cust_po_number = pha.segment1
                               AND PHA.po_header_id = ln_source_po_header_id -- tq po
                               AND PLA.REQUISITION_HEADER_ID =
                                   ods.requisition_header_id
                               AND PLA.LINE_LOCATION_ID =
                                   PLLA.LINE_LOCATION_ID
                               AND PHA1.PO_HEADER_ID = PLLA.PO_HEADER_ID
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_tq_po_so           := NULL;
                            ln_tq_po_factory_po   := NULL;
                    END;

                    IF    ln_tq_po_factory_po IS NOT NULL
                       OR ln_tq_po_so IS NOT NULL
                    THEN
                        lv_stg_status   := 'E';
                        p_err_msg       :=
                            'TQ PO associated with Factory PO. Action cannot be performed.';
                        -- RETURN;
                        RAISE exit_validation_exception;
                    END IF;

                    -- jp tq po associated with SO
                    SELECT COUNT (*)
                      INTO l_jp_tq_so_count
                      FROM po_headers_all pha
                     WHERE     1 = 1
                           AND pha.po_header_id = ln_source_po_header_id -- tq po
                           AND EXISTS
                                   (SELECT *
                                      FROM oe_order_lines_all
                                     WHERE     line_id IN
                                                   (SELECT TO_NUMBER (attribute5)
                                                      FROM po_lines_all
                                                     WHERE po_header_id =
                                                           ln_source_po_header_id -- tq po
                                                                                 )
                                           AND cancelled_flag = 'N')
                           AND EXISTS
                                   (SELECT *
                                      FROM fnd_lookup_values
                                     WHERE     lookup_type =
                                               'XXD_PO_TQ_PRICE_RULE_VENDORS'
                                           AND NVL (start_date_active,
                                                    SYSDATE) <=
                                               SYSDATE
                                           AND NVL (end_date_active, SYSDATE) >=
                                               SYSDATE
                                           AND NVL (enabled_flag, 'N') = 'Y'
                                           AND language = USERENV ('LANG')
                                           AND meaning = pha.vendor_id);

                    IF l_jp_tq_so_count > 0
                    THEN
                        lv_stg_status   := 'E';
                        p_err_msg       :=
                            'TQ PO associated with so. Action cannot be performed.';
                        -- RETURN;
                        RAISE exit_validation_exception;
                    END IF;
                END IF;

                -- end ver 3.0
                BEGIN
                    INSERT INTO xxd_po_modify_details_t (record_id, batch_id, org_id, source_po_header_id, style_color, open_qty, action_type, move_inv_org_id, supplier_id, supplier_site_id, move_po, move_po_header_id, source_po_line_id, source_pr_header_id, source_pr_line_id, source_iso_header_id, source_iso_line_id, source_ir_header_id, source_ir_line_id, drop_ship_source_id, item_number, move_org_operating_unit_flag, po_cancelled_flag, pr_cancelled_flag, iso_cancelled_flag, ir_cancelled_flag, po_modify_source, intercompany_po_flag, status, error_message, creation_date, created_by, last_updated_date
                                                         , last_updated_by)
                         VALUES (xxd_po_modify_details_s.NEXTVAL, ln_batch_id, ln_org_id, ln_source_po_header_id, po_lines_det_rec.style_color, po_lines_det_rec.quantity, p_action, ln_dest_inv_org_id, ln_supplier_id, ln_supplier_site_id, p_to_po_number, ln_move_po_header_id, po_lines_det_rec.po_line_id, ln_pr_header_id, ln_pr_line_id, ln_iso_header_id, ln_iso_line_id, ln_ir_header_id, ln_ir_line_id, ln_drop_ship_id, po_lines_det_rec.item_number, DECODE (p_action, 'Move Org', ln_org_id_diff_flag, NULL), 'N', DECODE (ln_pr_line_id, NULL, NULL, 'N'), DECODE (ln_iso_line_id, NULL, NULL, 'N'), DECODE (ln_ir_line_id, NULL, NULL, 'N'), 'OA', lv_intercompany_flag, lv_stg_status, lv_stg_error_msg, ld_creation_date, ln_user_id, SYSDATE
                                 , ln_user_id);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                               lv_error_message
                            || 'Error While Inserting Data in Staging Table '
                            || SQLERRM;
                        p_err_msg   := lv_error_message;
                END;
            END LOOP;

            -- IF lv_error_message IS NULL
            --THEN
            --validating if item is assigned to destination org for Move Org action
            FOR move_org_valid_rec IN move_org_validation_cur
            LOOP
                ln_item_id   := NULL;

                BEGIN
                    SELECT inventory_item_id
                      INTO ln_item_id
                      FROM mtl_system_items_b
                     WHERE     segment1 = move_org_valid_rec.item_number
                           AND organization_id =
                               move_org_valid_rec.move_inv_org_id
                           AND inventory_item_status_code = 'Active'
                           AND purchasing_enabled_flag = 'Y';
                --Added for change 1.1
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_item_id   := NULL;
                        lv_error_message   :=
                               'Item '
                            || move_org_valid_rec.item_number
                            || ' not assigned to destination organization or not in active status or is not purchasing enabled';
                    WHEN OTHERS
                    THEN
                        ln_item_id   := NULL;
                        lv_error_message   :=
                               'Item '
                            || move_org_valid_rec.item_number
                            || ' not assigned to destination organization';
                END;

                IF ln_item_id IS NULL
                THEN
                    --ln_error_count := ln_error_count + 1;
                    BEGIN
                        UPDATE xxd_po_modify_details_t
                           SET status = 'E', error_message = lv_error_message
                         WHERE     batch_id = ln_batch_id
                               AND item_number =
                                   move_org_valid_rec.item_number
                               AND move_inv_org_id =
                                   move_org_valid_rec.move_inv_org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_error_message   :=
                                   lv_error_message
                                || 'Error While Updating Staging Table '
                                || SQLERRM;
                            p_err_msg   := lv_error_message;
                            RETURN;
                    END;

                    COMMIT;
                END IF;
            END LOOP;

            BEGIN
                SELECT COUNT (*)
                  INTO ln_stg_po_lines_count
                  FROM xxd_po_modify_details_t
                 WHERE     source_po_header_id = ln_source_po_header_id
                       AND batch_id = ln_batch_id
                       AND status = 'N';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_stg_po_lines_count   := 0;
            END;

            BEGIN
                SELECT COUNT (*)
                  INTO ln_source_po_lines_count
                  FROM po_lines_all
                 WHERE     po_header_id = ln_source_po_header_id
                       AND NVL (cancel_flag, 'N') = 'N';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_source_po_lines_count   := 0;
            END;

            IF ln_stg_po_lines_count = ln_source_po_lines_count
            THEN
                ln_po_header_cancel_flag   := 'Y';
            ELSE
                ln_po_header_cancel_flag   := 'N';
            END IF;

            --validation to cancel iso at header leval or line leval
            BEGIN
                SELECT DISTINCT source_iso_header_id
                  INTO ln_iso_header_id_stg
                  FROM xxd_po_modify_details_t
                 WHERE     source_po_header_id = ln_source_po_header_id
                       AND batch_id = ln_batch_id
                       AND status = 'N';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_iso_header_id_stg   := NULL;
            END;

            IF ln_iso_header_id_stg IS NOT NULL
            THEN
                BEGIN
                    SELECT COUNT (*)
                      INTO ln_source_iso_lines_count
                      FROM oe_order_lines_all
                     WHERE     header_id = ln_iso_header_id_stg
                           AND NVL (cancelled_flag, 'N') = 'N';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_source_iso_lines_count   := 0;
                END;

                BEGIN
                    SELECT COUNT (*)
                      INTO ln_stg_iso_lines_count
                      FROM xxd_po_modify_details_t
                     WHERE     source_po_header_id = ln_source_po_header_id
                           AND batch_id = ln_batch_id
                           AND source_iso_header_id IS NOT NULL
                           AND status = 'N';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_stg_iso_lines_count   := 0;
                END;

                IF ln_source_iso_lines_count = ln_stg_iso_lines_count
                THEN
                    ln_iso_header_cancel_flag   := 'Y';
                ELSE
                    ln_iso_header_cancel_flag   := 'N';
                END IF;
            ELSE
                ln_iso_header_cancel_flag   := 'N';
            END IF;

            --Updating staging table with header cancel flags
            BEGIN
                UPDATE xxd_po_modify_details_t
                   SET cancel_po_header_flag = ln_po_header_cancel_flag, cancel_iso_header_flag = ln_iso_header_cancel_flag
                 WHERE     batch_id = ln_batch_id
                       AND source_po_header_id = ln_source_po_header_id
                       AND status = 'N';

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || 'Error While Updating Staging Table '
                        || SQLERRM;
                    p_err_msg   := lv_error_message;
                    RETURN;
            END;

            BEGIN
                SELECT DISTINCT intercompany_po_flag
                  INTO lv_intercompany_validation
                  FROM xxd_po_modify_details_t
                 WHERE     source_po_header_id = ln_source_po_header_id
                       AND batch_id = ln_batch_id
                       AND status = 'N';
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    BEGIN
                        UPDATE xxd_po_modify_details_t
                           SET intercompany_po_flag   = 'Y'
                         WHERE     batch_id = ln_batch_id
                               AND source_po_header_id =
                                   ln_source_po_header_id
                               AND status = 'N';

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_error_message   :=
                                   lv_error_message
                                || 'Error While Updating Staging Table '
                                || SQLERRM;
                    END;
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || 'Error While Updating Staging Table '
                        || SQLERRM;
            END;

            -- END IF;
            BEGIN
                SELECT COUNT (*)
                  INTO ln_error_count
                  FROM xxd_po_modify_details_t
                 WHERE     batch_id = ln_batch_id
                       AND source_po_header_id = ln_source_po_header_id
                       AND status = 'E';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                           'Errror while Coutning Error Records In Staging Table'
                        || SQLERRM;
                    p_err_msg   := lv_error_message;
                    RETURN;
            END;

            IF ln_error_count = 0
            THEN
                BEGIN
                    lv_error_message   := NULL;
                    submit_process_trans_prog (ln_user_id,
                                               p_resp_id,
                                               ln_batch_id,
                                               ln_request_id,       -- ver 3.0
                                               lv_error_message);
                    p_err_msg          := 'Success';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                               'Errror while calling process trnasaction: '
                            || SQLERRM;
                        p_err_msg   := lv_error_message;
                        RETURN;
                END;
            ELSE
                BEGIN
                    UPDATE xxd_po_modify_details_t
                       SET status = 'E', error_message = 'One or more PO line has errors.'
                     WHERE     status = 'N'
                           AND source_po_header_id = ln_source_po_header_id
                           AND batch_id = ln_batch_id;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                               'Errror while Updating Staging Table With Error: '
                            || SQLERRM;
                        p_err_msg   := lv_error_message;
                        RETURN;
                END;

                p_err_msg   := 'Success';
            END IF;
        ELSE
            p_err_msg   := lv_error_message;
        END IF;
    EXCEPTION
        WHEN exit_validation_exception
        THEN
            NULL;
        WHEN OTHERS
        THEN
            lv_error_message   :=
                   lv_error_message
                || ' '
                || SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            p_err_msg   := lv_error_message;
    END upload_proc;

    PROCEDURE process_transaction (pv_errbuf         OUT VARCHAR2,
                                   pv_retcode        OUT NUMBER,
                                   p_batch_id     IN     NUMBER,
                                   p_request_id   IN     NUMBER,    -- ver 3.0
                                   p_user_id      IN     NUMBER DEFAULT NULL)
    IS
        CURSOR stg_header_cur IS
            SELECT DISTINCT source_po_header_id, action_type, move_inv_org_id,
                            supplier_id, supplier_site_id, move_po,
                            move_po_header_id, status, org_id,
                            source_pr_header_id, batch_id, move_org_operating_unit_flag,
                            intercompany_po_flag, cancel_po_header_flag, cancel_iso_header_flag
              FROM xxd_po_modify_details_t
             WHERE status = 'N' AND batch_id = p_batch_id;

        lv_error_message      VARCHAR2 (4000);
        lv_error_msg          VARCHAR2 (4000);
        ln_user_id            NUMBER;
        -- begin ver 3.0
        lc_phase              VARCHAR2 (50);
        lc_status             VARCHAR2 (50);
        lc_dev_phase          VARCHAR2 (50);
        lc_dev_status         VARCHAR2 (50);
        lc_message            VARCHAR2 (50);
        l_req_return_status   BOOLEAN;
    -- end ver 3.0
    BEGIN
        -- ver 3.0 begin
        IF p_request_id IS NOT NULL
        THEN
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Inside Loop. Waiting for the Dependent program to complete processing '
                    || p_request_id);
                --To make process execution to wait
                --
                l_req_return_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => p_request_id,
                        INTERVAL     => 5 --interval Number of seconds to wait between checks
                                         ,
                        max_wait     => 60 --Maximum number of seconds to wait for the request completion
                                          -- out arguments
                                          ,
                        phase        => lc_phase,
                        STATUS       => lc_status,
                        dev_phase    => lc_dev_phase,
                        dev_status   => lc_dev_status,
                        MESSAGE      => lc_message);
                EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                          OR UPPER (lc_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'Process transaction started');

        --  ver 3.0 end
        IF p_user_id IS NULL
        THEN
            ln_user_id   := fnd_global.user_id;
        ELSE
            ln_user_id   := p_user_id;
        END IF;

        FOR stg_header_rec IN stg_header_cur
        LOOP
            lock_po (stg_header_rec.batch_id,
                     stg_header_rec.source_po_header_id,
                     lv_error_message);

            IF lv_error_message IS NOT NULL
            THEN
                BEGIN
                    UPDATE xxd_po_modify_details_t
                       SET status = 'E', error_message = SUBSTR (lv_error_message, 1, 2000)
                     WHERE     status = 'N'
                           AND batch_id = stg_header_rec.batch_id
                           AND source_po_header_id =
                               stg_header_rec.source_po_header_id;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error While Updating Staging Table With Error'
                            || SQLERRM);
                END;
            ELSE
                lv_error_msg   := NULL;

                IF stg_header_rec.action_type = 'Move Org'
                THEN
                    move_org_action (
                        ln_user_id,
                        stg_header_rec.batch_id,
                        stg_header_rec.source_po_header_id,
                        stg_header_rec.source_pr_header_id,
                        stg_header_rec.move_inv_org_id,
                        stg_header_rec.action_type,
                        stg_header_rec.intercompany_po_flag,
                        stg_header_rec.move_org_operating_unit_flag,
                        lv_error_message);

                    IF lv_error_message IS NOT NULL
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET status = 'E', error_message = SUBSTR (lv_error_message, 1, 2000)
                             WHERE     status = 'N'
                                   AND batch_id = stg_header_rec.batch_id
                                   AND source_po_header_id =
                                       stg_header_rec.source_po_header_id;

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error While Updating Staging Table With Error'
                                    || SQLERRM);
                        END;
                    END IF;
                END IF;

                IF stg_header_rec.action_type = 'Change Supplier'
                THEN
                    change_supplier_action (
                        ln_user_id,
                        stg_header_rec.batch_id,
                        stg_header_rec.source_po_header_id,
                        stg_header_rec.supplier_id,
                        stg_header_rec.supplier_site_id,
                        stg_header_rec.action_type,
                        stg_header_rec.intercompany_po_flag,
                        lv_error_message);

                    IF lv_error_message IS NOT NULL
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET status = 'E', error_message = SUBSTR (lv_error_message, 1, 2000)
                             WHERE     status = 'N'
                                   AND batch_id = stg_header_rec.batch_id
                                   AND source_po_header_id =
                                       stg_header_rec.source_po_header_id;

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error While Updating Staging Table With Error'
                                    || SQLERRM);
                        END;
                    END IF;
                END IF;

                IF stg_header_rec.action_type = 'Move'
                THEN
                    move_po_action (ln_user_id,
                                    stg_header_rec.batch_id,
                                    stg_header_rec.source_po_header_id,
                                    stg_header_rec.source_pr_header_id,
                                    stg_header_rec.move_po_header_id,
                                    stg_header_rec.action_type,
                                    stg_header_rec.intercompany_po_flag,
                                    lv_error_message);

                    IF lv_error_message IS NOT NULL
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET status = 'E', error_message = SUBSTR (lv_error_message, 1, 2000)
                             WHERE     status = 'N'
                                   AND batch_id = stg_header_rec.batch_id
                                   AND source_po_header_id =
                                       stg_header_rec.source_po_header_id;

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Error While Updating Staging Table With Error'
                                    || SQLERRM);
                        END;
                    END IF;
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error in process_transaction procedure' || SQLERRM);
    END process_transaction;

    PROCEDURE move_po_action (pn_user_id               IN     NUMBER,
                              pn_batch_id              IN     NUMBER,
                              pn_po_header_id          IN     NUMBER,
                              pn_source_pr_header_id   IN     NUMBER,
                              pn_move_po_header_id     IN     NUMBER,
                              pv_action_type           IN     VARCHAR2,
                              pv_intercompany_flag     IN     VARCHAR2,
                              pv_error_message            OUT VARCHAR2)
    IS
        CURSOR stg_lines_rec_cur IS
            SELECT DISTINCT source_po_header_id, source_po_line_id, batch_id,
                            po_cancelled_flag
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id
                   AND cancel_po_header_flag = 'N'
            UNION
            SELECT DISTINCT source_po_header_id, 1 source_po_line_id, batch_id,
                            po_cancelled_flag
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id
                   AND cancel_po_header_flag = 'Y';

        CURSOR drop_ship_rec_cur IS
            SELECT *
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id
                   AND drop_ship_source_id IS NOT NULL;

        CURSOR stg_lines_cur IS
            SELECT *
              FROM xxd_po_modify_details_t a
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id;

        CURSOR stg_iso_cur IS
            SELECT DISTINCT source_iso_header_id
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id;

        lv_status_flag             VARCHAR2 (2);
        lv_error_message           VARCHAR2 (4000);
        lv_error_flag              VARCHAR2 (2);
        ln_error_count             NUMBER;
        lv_error_msg               VARCHAR2 (4000);
        lv_exp_error               VARCHAR2 (4000);
        po_line_det                xxdo.xxd_po_line_det_type;
        po_iso_det                 xxdo.xxd_po_iso_det_type;
        ln_po_int_batch_id         NUMBER;
        lv_req_number              VARCHAR2 (50);
        ln_req_import_id           NUMBER;
        ln_req_header_id           NUMBER;
        ln_new_line_location_id    NUMBER;
        ln_po_line_id              NUMBER;
        -- Added for CCR0010003
        ln_source_po_num           VARCHAR2 (240);
        ln_source_vendor_id        NUMBER;
        ln_source_vendor_site_id   NUMBER;
        ln_move_po_num             VARCHAR2 (240);
        ln_move_vendor_id          NUMBER;
        ln_move_vendor_site_id     NUMBER;
        ln_calc_transit_days       NUMBER;
        lv_po_type                 VARCHAR2 (240) := NULL;
        ln_vendor_site_code_dff    VARCHAR2 (240) := NULL;
    BEGIN
        --Start changes for CCR0010003
        fnd_file.put_line (fnd_file.LOG, 'pn_user_id : ' || pn_user_id); -- Added by Gowrishankar for CCR0010003 on 01-Sep-2022
        fnd_file.put_line (fnd_file.LOG, 'pn_batch_id : ' || pn_batch_id); -- Added by Gowrishankar for CCR0010003 on 01-Sep-2022
        fnd_file.put_line (fnd_file.LOG,
                           'pn_po_header_id : ' || pn_po_header_id); -- Added by Gowrishankar for CCR0010003 on 01-Sep-2022
        fnd_file.put_line (
            fnd_file.LOG,
            'pn_source_pr_header_id : ' || pn_source_pr_header_id); -- Added by Gowrishankar for CCR0010003 on 01-Sep-2022
        fnd_file.put_line (fnd_file.LOG,
                           'pn_move_po_header_id : ' || pn_move_po_header_id); -- Added by Gowrishankar for CCR0010003 on 01-Sep-2022
        fnd_file.put_line (fnd_file.LOG,
                           'pv_action_type : ' || pv_action_type); -- Added by Gowrishankar for CCR0010003 on 01-Sep-2022
        fnd_file.put_line (fnd_file.LOG,
                           'pv_intercompany_flag : ' || pv_intercompany_flag); -- Added by Gowrishankar for CCR0010003 on 01-Sep-2022


        IF NVL (pv_intercompany_flag, 'N') = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Inside pv_intercompany_flag = Y '); -- Added by Gowrishankar for CCR0010003 on 01-Sep-2022

            po_line_det      := xxdo.xxd_po_line_det_type (NULL);
            po_iso_det       := xxdo.xxd_po_iso_det_type (NULL);
            ln_error_count   := 0;
            SAVEPOINT xxd_transaction;
            lv_error_msg     := NULL;

            FOR stg_lines_rec IN stg_lines_rec_cur
            LOOP
                IF stg_lines_rec.po_cancelled_flag = 'N'
                THEN
                    IF stg_lines_rec.source_po_line_id = 1
                    THEN
                        ln_po_line_id   := NULL;
                    ELSE
                        ln_po_line_id   := stg_lines_rec.source_po_line_id;
                    END IF;


                    --Start changes for CCR0010003

                    BEGIN
                        SELECT pha.segment1, pha.vendor_id, pha.vendor_site_id,
                               TRIM (pla.attribute7)
                          INTO ln_source_po_num, ln_source_vendor_id, ln_source_vendor_site_id, ln_vendor_site_code_dff
                          FROM po_headers_all pha, po_lines_all pla
                         WHERE     1 = 1
                               AND pla.po_header_id = pha.po_header_id
                               AND pha.po_header_id = pn_po_header_id
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                lv_error_message || ' ' || SQLERRM;
                            pv_error_message   := lv_exp_error;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'pv_error_message : ' || pv_error_message);
                    END;

                    BEGIN
                        SELECT pha.segment1, vendor_id, vendor_site_id,
                               TRIM (pla.attribute7)
                          INTO ln_move_po_num, ln_move_vendor_id, ln_move_vendor_site_id, ln_vendor_site_code_dff
                          FROM po_headers_all pha, po_lines_all pla
                         WHERE     1 = 1
                               AND pla.po_header_id = pha.po_header_id
                               AND pha.po_header_id = pn_move_po_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                lv_error_message || ' ' || SQLERRM;
                            pv_error_message   := lv_exp_error;
                    END;


                    --IF ln_vendor_id IS NOT NULL AND ln_vendor_site_id IS NOT NULL
                    --THEN
                    --Get Intransit days from lookup for change supplier\site
                    BEGIN
                        ln_calc_transit_days   :=
                            xxd_po_pomodify_utils_pkg.get_pol_transit_days (
                                ln_source_po_num,            --ln_move_po_num,
                                pv_action_type,
                                ln_source_vendor_id,           --ln_vendor_id,
                                ln_source_vendor_site_id,  --ln_vendor_site_id
                                ln_vendor_site_code_dff);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_calc_transit_days   := 0;
                    END;

                    BEGIN
                        SELECT pha.attribute10                      -- PO Type
                          INTO lv_po_type
                          FROM po_headers_all pha
                         WHERE pha.segment1 = ln_move_po_num;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error while getting PO Type. ');
                    END;

                    IF ln_calc_transit_days < 0 AND lv_po_type <> 'INTL_DIST'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Transit days not defined for the Supplier in Lookup. '); -- Added by Gowrishankar for CCR0010003 on 01-Sep-2022

                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Transit days not defined for the Supplier in Lookup. '
                                || ln_po_line_id
                                || lv_error_message,
                                1,
                                2000);

                        fnd_file.put_line (fnd_file.LOG,
                                           'lv_error_msg: ' || lv_error_msg);
                    END IF;


                    IF ln_error_count > 0
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET po_cancelled_flag = 'E', pr_cancelled_flag = 'E', --DECODE (pr_cancelled_flag, 'N', 'E', ''),
                                                                                     iso_cancelled_flag = 'E',
                                   ir_cancelled_flag = 'E', --DECODE (ir_cancelled_flag, 'N', 'E', ''),
                                                            status = 'E', error_message = lv_error_msg,
                                   last_updated_date = SYSDATE, last_updated_by = pn_user_id
                             WHERE     status = 'N'
                                   AND source_po_header_id =
                                       stg_lines_rec.source_po_header_id --pn_source_pr_header_id
                                   AND batch_id = pn_batch_id;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'After UPDATE xxd_po_modify_details_t po_cancelled_flag = E. '); -- Added by Gowrishankar for CCR0010003 on 01-Sep-2022

                            --COMMIT;
                            CONTINUE;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ROLLBACK TO SAVEPOINT xxd_transaction;
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;

                        ROLLBACK TO SAVEPOINT xxd_transaction;

                        RETURN;

                        pv_error_message   :=
                               'Transit days not defined for the Supplier in Lookup. '
                            || pv_error_message;
                        RETURN;
                    END IF;

                    xxd_po_pomodify_utils_pkg.cancel_po_line (
                        pn_user_id,
                        stg_lines_rec.source_po_header_id,
                        ln_po_line_id,
                        'Y',                              --cancel_requisition
                        lv_status_flag,
                        lv_error_message);


                    IF lv_status_flag = 'S'
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET po_cancelled_flag = 'Y', pr_cancelled_flag = DECODE (pr_cancelled_flag, 'N', 'Y', ''), last_updated_date = SYSDATE,
                                   last_updated_by = pn_user_id
                             WHERE     batch_id = pn_batch_id
                                   AND status = 'N'
                                   AND source_po_header_id =
                                       stg_lines_rec.source_po_header_id
                                   AND source_po_line_id =
                                       NVL (ln_po_line_id, source_po_line_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ROLLBACK TO SAVEPOINT xxd_transaction;
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    ELSE
                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Error while cancelling po_line_id:'
                                || stg_lines_rec.source_po_line_id
                                || lv_error_message,
                                1,
                                2000);
                    END IF;
                END IF;
            END LOOP;

            IF ln_error_count > 0
            THEN
                ROLLBACK TO SAVEPOINT xxd_transaction;

                BEGIN
                    UPDATE xxd_po_modify_details_t
                       SET po_cancelled_flag = 'E', pr_cancelled_flag = DECODE (pr_cancelled_flag, 'N', 'E', ''), status = 'E',
                           error_message = lv_error_msg, last_updated_date = SYSDATE, last_updated_by = pn_user_id
                     WHERE     status = 'N'
                           AND source_po_header_id = pn_po_header_id
                           AND batch_id = pn_batch_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ROLLBACK TO SAVEPOINT xxd_transaction;
                        lv_exp_error       :=
                            'Error while updating staging table:' || SQLERRM;
                        pv_error_message   := lv_exp_error;
                        RETURN;
                END;

                lv_exp_error       :=
                       'Could not cancel Purcahse Order lines or Sales Order Lines '
                    || lv_exp_error;
                pv_error_message   := lv_exp_error;
                RETURN;
            ELSE
                COMMIT;

                --commiting PO,PR,ISO,IR cancellation
                --create pr
                FOR stg_lines IN stg_lines_cur
                LOOP
                    po_line_det.EXTEND;
                    po_line_det (po_line_det.COUNT)   :=
                        xxdo.xxd_po_line_det_tab (
                            stg_lines.source_po_line_id,
                            stg_lines.source_pr_line_id,
                            stg_lines.open_qty                      -- ver 3.0
                                              );
                END LOOP;

                FOR stg_iso_rec IN stg_iso_cur
                LOOP
                    po_iso_det.EXTEND;
                    po_iso_det (po_iso_det.COUNT)   :=
                        xxdo.xxd_po_iso_det_tab (
                            stg_iso_rec.source_iso_header_id);
                END LOOP;

                xxd_po_pomodify_utils_pkg.create_pr_from_iso (
                    po_iso_det,
                    --stg_iso_rec.source_iso_header_id, --ISO to process
                    po_line_det,
                    '',
                    '',
                    pn_user_id,
                    lv_req_number,
                    ln_req_import_id,
                    lv_error_flag,
                    lv_error_message);

                BEGIN
                    SELECT requisition_header_id
                      INTO ln_req_header_id
                      FROM po_requisition_headers_all
                     WHERE segment1 = lv_req_number;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_req_header_id   := NULL;
                END;

                IF ln_req_header_id IS NULL
                THEN
                    BEGIN
                        UPDATE xxd_po_modify_details_t stg
                           SET status              = 'E',
                               error_message      =
                                   SUBSTR (
                                       (NVL (
                                            (SELECT 'Purchase Requisition interface error: ' || pe.error_message
                                               FROM po_interface_errors pe, po_requisitions_interface_all pri
                                              WHERE     pri.request_id =
                                                        ln_req_import_id
                                                    AND pri.transaction_id =
                                                        pe.interface_transaction_id
                                                    AND pri.line_attribute1 =
                                                        stg.source_po_line_id
                                                    AND pri.line_attribute2 =
                                                        stg.source_pr_line_id
                                                    AND ROWNUM = 1),
                                            'Error While Creating Purchase Requisition')),
                                       1,
                                       2000),
                               last_updated_date   = SYSDATE,
                               last_updated_by     = pn_user_id
                         WHERE     source_po_header_id = pn_po_header_id
                               AND action_type = pv_action_type
                               AND batch_id = pn_batch_id
                               AND status = 'N';

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                   'Error while updating staging table:'
                                || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;

                    RETURN;
                ELSE
                    --Updating stgaing table with new requistion
                    BEGIN
                        UPDATE xxd_po_modify_details_t stg
                           SET new_pr_number       = lv_req_number,
                               new_pr_header_id    = ln_req_header_id,
                               (new_pr_line_num, new_pr_line_id)   =
                                   (SELECT prla.line_num, prla.requisition_line_id
                                      FROM po_requisition_headers_all prha, po_requisition_lines_all prla
                                     WHERE     prha.requisition_header_id =
                                               prla.requisition_header_id
                                           AND prha.segment1 = lv_req_number
                                           AND prla.attribute1 =
                                               stg.source_po_line_id
                                           AND prla.attribute2 =
                                               stg.source_pr_line_id),
                               last_updated_date   = SYSDATE,
                               last_updated_by     = pn_user_id
                         WHERE     source_po_header_id = pn_po_header_id
                               AND action_type = pv_action_type
                               AND batch_id = pn_batch_id
                               AND status = 'N';

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                lv_error_message || ' ' || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;

                    --ADD_LINES_TO_PO
                    xxd_po_pomodify_utils_pkg.add_lines_to_po (
                        pv_intercompany_flag,                       -- VER 3.0
                        pn_user_id,
                        pn_move_po_header_id,
                        ln_req_header_id,
                        --new_requisition_header_id
                        po_line_det,
                        ln_po_int_batch_id,
                        lv_error_flag,
                        lv_error_message);

                    IF lv_error_message IS NULL
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t stg
                               SET new_po_number       = stg.move_po,
                                   (new_po_header_id,
                                    new_po_line_num,
                                    new_po_line_id)   =
                                       (SELECT pla.po_header_id, pla.line_num, pla.po_line_id
                                          FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_req_distributions_all prd,
                                               po_distributions_all pda, po_lines_all pla
                                         WHERE     prha.requisition_header_id =
                                                   ln_req_header_id
                                               AND prha.requisition_header_id =
                                                   prla.requisition_header_id
                                               AND prd.requisition_line_id =
                                                   prla.requisition_line_id
                                               AND pda.req_distribution_id =
                                                   prd.distribution_id
                                               AND pda.po_line_id =
                                                   pla.po_line_id
                                               AND prla.requisition_line_id =
                                                   stg.new_pr_line_id),
                                   last_updated_date   = SYSDATE,
                                   last_updated_by     = pn_user_id
                             WHERE     source_po_header_id = pn_po_header_id
                                   AND action_type = pv_action_type
                                   AND batch_id = pn_batch_id
                                   AND status = 'N';

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                    lv_error_message || ' ' || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    ELSE
                        BEGIN
                            UPDATE xxd_po_modify_details_t stg
                               SET status              = 'E',
                                   po_cancelled_flag   = 'N',
                                   error_message      =
                                       SUBSTR (
                                           (NVL (
                                                (SELECT 'Purchase order interface error: ' || pe.error_message
                                                   FROM po_interface_errors pe, po_headers_interface phi, po_lines_interface pli
                                                  WHERE     phi.batch_id =
                                                            ln_po_int_batch_id
                                                        AND phi.interface_header_id =
                                                            pli.interface_header_id
                                                        AND phi.interface_header_id =
                                                            NVL (
                                                                pe.interface_line_id,
                                                                pli.interface_line_id)
                                                        AND pli.requisition_line_id =
                                                            stg.new_pr_line_id
                                                        AND ROWNUM = 1),
                                                'Error While Adding Lines To Purchase Order')),
                                           1,
                                           2000),
                                   last_updated_date   = SYSDATE,
                                   last_updated_by     = pn_user_id
                             WHERE     stg.source_po_header_id =
                                       pn_po_header_id
                                   AND action_type = pv_action_type
                                   AND batch_id = pn_batch_id
                                   AND status = 'N';

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                    lv_error_message || ' ' || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    END IF;
                END IF;

                FOR stg_iso_rec IN stg_iso_cur
                LOOP
                    xxd_po_pomodify_utils_pkg.link_iso_and_po (
                        stg_iso_rec.source_iso_header_id,
                        lv_error_msg);
                END LOOP;

                IF lv_error_msg IS NOT NULL
                THEN
                    UPDATE xxd_po_modify_details_t stg
                       SET status = 'E', error_message = lv_error_msg, last_updated_date = SYSDATE,
                           last_updated_by = pn_user_id
                     WHERE     batch_id = pn_batch_id
                           AND source_po_header_id = pn_po_header_id
                           AND action_type = pv_action_type
                           AND status = 'N';
                END IF;
            END IF;



            --Start changes for CCR0010003

            IF     ln_move_vendor_id IS NOT NULL
               AND ln_move_vendor_site_id IS NOT NULL
            THEN
                --Calling procedure to update calculated New Promise\Need by Dates
                xxd_po_pomodify_utils_pkg.update_calc_need_by_date (
                    pn_user_id,
                    ln_move_po_num,                        -- ln_source_po_num
                    ln_calc_transit_days,
                    ln_move_vendor_id,                  --ln_source_vendor_id,
                    ln_move_vendor_site_id,        --ln_source_vendor_site_id,
                    NULL,
                    NVL (ln_req_header_id, pn_source_pr_header_id), --pn_source_pr_header_id, -- Added by Gowrishankar for CCR0010003 on 01-Sep-2022
                    pv_action_type, -- Added by Gowrishankar for CCR0010003 on 14-Sep-2022
                    lv_error_flag,
                    lv_error_message);
            ELSE
                --End Added for CCR0010003
                --Calling below procedure for change 1.1
                --Calling procedure to update po need_by_date when there is mismatach between PR ans PO
                xxd_po_pomodify_utils_pkg.update_po_need_by_date (
                    pn_user_id,
                    ln_move_po_num,
                    lv_error_flag,
                    lv_error_message);
            END IF;                                     --Added for CCR0010003

            COMMIT;                     -- Added for CCR0010003 on 23-Aug-2022



            BEGIN
                UPDATE xxd_po_modify_details_t stg
                   SET status = 'S', last_updated_date = SYSDATE, last_updated_by = pn_user_id
                 WHERE     batch_id = pn_batch_id
                       AND source_po_header_id = pn_po_header_id
                       AND action_type = pv_action_type
                       AND status = 'N'
                       AND new_po_number IS NOT NULL
                       AND new_po_line_num IS NOT NULL;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exp_error       :=
                           pv_error_message
                        || ' Error while updating staging table with success '
                        || SQLERRM;
                    pv_error_message   := lv_exp_error;
                    RETURN;
            END;

            BEGIN
                UPDATE xxd_po_modify_details_t stg
                   SET status = 'E', error_message = NVL (lv_error_message, 'Error while cancelling po lines and creating new po'), last_updated_date = SYSDATE,
                       last_updated_by = pn_user_id
                 WHERE     batch_id = pn_batch_id
                       AND source_po_header_id = pn_po_header_id
                       AND action_type = pv_action_type
                       AND status = 'N'
                       AND (new_po_number IS NULL OR new_po_line_num IS NULL);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exp_error       :=
                           pv_error_message
                        || ' Error while updating staging table with error '
                        || SQLERRM;
                    pv_error_message   := lv_exp_error;
                    RETURN;
            END;
        END IF;



        IF NVL (pv_intercompany_flag, 'N') = 'N'
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Inside pv_intercompany_flag = N ');

            po_line_det      := xxdo.xxd_po_line_det_type (NULL);
            ln_error_count   := 0;
            SAVEPOINT xxd_transaction;
            lv_error_msg     := NULL;



            FOR stg_lines_rec IN stg_lines_rec_cur
            LOOP
                IF stg_lines_rec.po_cancelled_flag = 'N'
                THEN
                    IF stg_lines_rec.source_po_line_id = 1
                    THEN
                        ln_po_line_id   := NULL;
                    ELSE
                        ln_po_line_id   := stg_lines_rec.source_po_line_id;
                    END IF;


                    --Start changes for CCR0010003

                    BEGIN
                        SELECT pha.segment1, pha.vendor_id, pha.vendor_site_id
                          INTO ln_source_po_num, ln_source_vendor_id, ln_source_vendor_site_id
                          FROM po_headers_all pha, po_lines_all pla
                         WHERE     1 = 1
                               AND pla.po_header_id = pha.po_header_id
                               AND pha.po_header_id = pn_po_header_id
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                lv_error_message || ' ' || SQLERRM;
                            pv_error_message   := lv_exp_error;
                    END;

                    BEGIN
                        SELECT pha.segment1, vendor_id, vendor_site_id,
                               pla.attribute7
                          INTO ln_move_po_num, ln_move_vendor_id, ln_move_vendor_site_id, ln_vendor_site_code_dff
                          FROM po_headers_all pha, po_lines_all pla
                         WHERE     1 = 1
                               AND pla.po_header_id = pha.po_header_id
                               AND pha.po_header_id = pn_move_po_header_id
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                lv_error_message || ' ' || SQLERRM;
                            pv_error_message   := lv_exp_error;
                    END;


                    --IF ln_vendor_id IS NOT NULL AND ln_vendor_site_id IS NOT NULL
                    --THEN
                    --Get Intransit days from lookup for change supplier\site
                    BEGIN
                        ln_calc_transit_days   :=
                            xxd_po_pomodify_utils_pkg.get_pol_transit_days (
                                ln_move_po_num,            --ln_source_po_num,
                                pv_action_type,
                                ln_move_vendor_id,             --ln_vendor_id,
                                ln_move_vendor_site_id,    --ln_vendor_site_id
                                ln_vendor_site_code_dff);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_calc_transit_days   := 0;
                    END;

                    BEGIN
                        SELECT pha.attribute10                      -- PO Type
                          INTO lv_po_type
                          FROM po_headers_all pha
                         WHERE pha.segment1 = ln_move_po_num;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error while getting PO Type. ');
                    END;

                    IF ln_calc_transit_days < 0 AND lv_po_type <> 'INTL_DIST'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Transit days not defined for the Supplier in Lookup. '); -- Added by Gowrishankar for CCR0010003 on 08-Sep-2022

                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Transit days not defined for the Supplier in Lookup. '
                                || ln_po_line_id
                                || lv_error_message,
                                1,
                                2000);
                    END IF;


                    IF ln_error_count > 0
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET po_cancelled_flag = 'E', pr_cancelled_flag = 'E', --DECODE (pr_cancelled_flag, 'N', 'E', ''),
                                                                                     iso_cancelled_flag = 'E',
                                   ir_cancelled_flag = 'E', --DECODE (ir_cancelled_flag, 'N', 'E', ''),
                                                            status = 'E', error_message = lv_error_msg,
                                   last_updated_date = SYSDATE, last_updated_by = pn_user_id
                             WHERE     status = 'N'
                                   AND source_po_header_id =
                                       stg_lines_rec.source_po_header_id --pn_source_pr_header_id
                                   AND batch_id = pn_batch_id;

                            --COMMIT;
                            CONTINUE;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ROLLBACK TO SAVEPOINT xxd_transaction;
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;


                        ROLLBACK TO SAVEPOINT xxd_transaction;

                        RETURN;

                        pv_error_message   :=
                               'Transit days not defined for the Supplier in Lookup. '
                            || pv_error_message;
                        RETURN;
                    END IF;

                    xxd_po_pomodify_utils_pkg.cancel_po_line (
                        pn_user_id,
                        stg_lines_rec.source_po_header_id,
                        ln_po_line_id,
                        'N',                              --cancel_requisition
                        lv_status_flag,
                        lv_error_message);

                    IF lv_status_flag = 'S'
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET po_cancelled_flag = 'Y', pr_cancelled_flag = DECODE (pr_cancelled_flag, 'N', 'Y', ''), last_updated_date = SYSDATE,
                                   last_updated_by = pn_user_id
                             WHERE     batch_id = pn_batch_id
                                   AND status = 'N'
                                   AND source_po_header_id =
                                       stg_lines_rec.source_po_header_id
                                   AND source_po_line_id =
                                       NVL (ln_po_line_id, source_po_line_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ROLLBACK TO SAVEPOINT xxd_transaction;
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    ELSE
                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Error while cancelling po_line_id:'
                                || ln_po_line_id
                                || lv_error_message,
                                1,
                                2000);
                    END IF;
                END IF;
            END LOOP;

            IF ln_error_count > 0
            THEN
                ROLLBACK TO SAVEPOINT xxd_transaction;

                BEGIN
                    UPDATE xxd_po_modify_details_t
                       SET po_cancelled_flag = 'E', pr_cancelled_flag = DECODE (pr_cancelled_flag, 'N', 'E', ''), iso_cancelled_flag = 'E',
                           ir_cancelled_flag = DECODE (ir_cancelled_flag, 'N', 'E', ''), status = 'E', error_message = lv_error_msg,
                           last_updated_date = SYSDATE, last_updated_by = pn_user_id
                     WHERE     status = 'N'
                           AND source_po_header_id = pn_po_header_id
                           AND batch_id = pn_batch_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ROLLBACK TO SAVEPOINT xxd_transaction;
                        lv_exp_error       :=
                            'Error while updating staging table:' || SQLERRM;
                        pv_error_message   := lv_exp_error;
                        RETURN;
                END;

                pv_error_message   :=
                       'Could not cancel Purcahse Order lines or Sales Order Lines '
                    || pv_error_message;
                RETURN;
            ELSE
                COMMIT;             -- Commented for CCR0010003 on 23-AUG-2022

                --commiting PO,PR,ISO,IR cancellation

                FOR stg_lines IN stg_lines_cur
                LOOP
                    po_line_det.EXTEND;
                    po_line_det (po_line_det.COUNT)   :=
                        xxdo.xxd_po_line_det_tab (
                            stg_lines.source_po_line_id,
                            stg_lines.source_pr_line_id,
                            stg_lines.open_qty                      -- ver 3.0
                                              );

                    xxd_po_pomodify_utils_pkg.update_po_req_link (
                        stg_lines.source_po_line_id,
                        lv_status_flag,
                        lv_error_message);
                END LOOP;

                --Add po lines to target po with source PR
                xxd_po_pomodify_utils_pkg.add_lines_to_po (
                    pv_intercompany_flag,                           -- VER 3.0
                    pn_user_id,
                    pn_move_po_header_id,
                    '',
                    --NO NEW REQUISITION
                    po_line_det,
                    ln_po_int_batch_id,
                    lv_error_flag,
                    lv_error_message);

                IF lv_error_message IS NULL
                THEN
                    BEGIN
                        UPDATE xxd_po_modify_details_t stg
                           SET new_po_number       = stg.move_po,
                               (new_po_header_id,
                                new_po_line_num,
                                new_po_line_id)   =
                                   (SELECT pla.po_header_id, pla.line_num, pla.po_line_id
                                      FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_req_distributions_all prd,
                                           po_distributions_all pda, po_lines_all pla
                                     WHERE     prha.requisition_header_id =
                                               pn_source_pr_header_id
                                           AND prha.requisition_header_id =
                                               prla.requisition_header_id
                                           AND prd.requisition_line_id =
                                               prla.requisition_line_id
                                           AND pda.req_distribution_id =
                                               prd.distribution_id
                                           AND pda.po_line_id =
                                               pla.po_line_id
                                           AND prla.requisition_line_id =
                                               stg.source_pr_line_id),
                               last_updated_date   = SYSDATE,
                               last_updated_by     = pn_user_id
                         WHERE     source_po_header_id = pn_po_header_id
                               AND action_type = pv_action_type
                               AND batch_id = pn_batch_id
                               AND status = 'N';

                        COMMIT;     -- Commented for CCR0010003 on 23-Aug-2022
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                   'Error while updating staging table:'
                                || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;
                ELSE
                    BEGIN
                        UPDATE xxd_po_modify_details_t stg
                           SET status              = 'E',
                               po_cancelled_flag   = 'N',
                               error_message      =
                                   SUBSTR (
                                       (NVL (
                                            (SELECT 'Purchase order interface error: ' || pe.error_message
                                               FROM po_interface_errors pe, po_headers_interface phi, po_lines_interface pli
                                              WHERE     phi.batch_id =
                                                        ln_po_int_batch_id
                                                    AND phi.interface_header_id =
                                                        pli.interface_header_id
                                                    AND phi.interface_header_id =
                                                        NVL (
                                                            pe.interface_line_id,
                                                            pli.interface_line_id)
                                                    AND pli.requisition_line_id =
                                                        stg.source_pr_line_id
                                                    AND ROWNUM = 1),
                                            'Error While Adding Lines To Purchase Order')),
                                       1,
                                       2000),
                               last_updated_date   = SYSDATE,
                               last_updated_by     = pn_user_id
                         WHERE     stg.source_po_header_id = pn_po_header_id
                               AND action_type = pv_action_type
                               AND batch_id = pn_batch_id
                               AND status = 'N';

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                   'Error while updating staging table:'
                                || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;
                END IF;
            END IF;

            FOR drop_ship_rec IN drop_ship_rec_cur
            LOOP
                BEGIN
                    SELECT line_location_id
                      INTO ln_new_line_location_id
                      FROM po_line_locations_all
                     WHERE     po_header_id = drop_ship_rec.new_po_header_id
                           AND po_line_id = drop_ship_rec.new_po_line_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_flag   := 'E';
                        pv_error_message   :=
                               lv_error_message
                            || ' Error while getting line location_id '
                            || SQLERRM;
                        RETURN;
                END;

                xxd_po_pomodify_utils_pkg.update_drop_ship (
                    pn_user_id,
                    drop_ship_rec.source_pr_header_id,
                    drop_ship_rec.source_pr_line_id,
                    drop_ship_rec.new_po_header_id,
                    drop_ship_rec.new_po_line_id,
                    ln_new_line_location_id,
                    lv_error_flag,
                    lv_error_message);

                IF lv_error_message IS NOT NULL
                THEN
                    BEGIN
                        UPDATE xxd_po_modify_details_t
                           SET status = 'E', error_message = 'Error while updating drop ship sources ' || lv_error_message, last_updated_date = SYSDATE,
                               last_updated_by = pn_user_id
                         WHERE     batch_id = pn_batch_id
                               AND status = 'N'
                               AND record_id = drop_ship_rec.record_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                   'Error while updating staging table:'
                                || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;
                ELSE
                    COMMIT;
                END IF;

                COMMIT;
            END LOOP;

            --Start changes for CCR0010003

            IF     ln_move_vendor_id IS NOT NULL
               AND ln_move_vendor_site_id IS NOT NULL
            THEN
                --Calling procedure to update calculated New Promise\Need by Dates
                xxd_po_pomodify_utils_pkg.update_calc_need_by_date (
                    pn_user_id,
                    ln_move_po_num,                     --ln_source_po_num, --
                    ln_calc_transit_days,
                    ln_move_vendor_id,                  --ln_source_vendor_id,
                    ln_move_vendor_site_id,        --ln_source_vendor_site_id,
                    NULL,
                    NVL (ln_req_header_id, pn_source_pr_header_id), --pn_source_pr_header_id, -- Modified by Gowrishankar for CCR0010003 on 07-Sep-2022
                    pv_action_type, -- Added by Gowrishankar for CCR0010003 on 14-Sep-2022
                    lv_error_flag,
                    lv_error_message);
            ELSE
                --End Added for CCR0010003
                --Calling below procedure for change 1.1
                --Calling procedure to update po need_by_date when there is mismatach between PR ans PO
                xxd_po_pomodify_utils_pkg.update_po_need_by_date (
                    pn_user_id,
                    ln_move_po_num,
                    lv_error_flag,
                    lv_error_message);
            END IF;                                     --Added for CCR0010003

            COMMIT;                     -- Added for CCR0010003 on 23-Aug-2022



            BEGIN
                UPDATE xxd_po_modify_details_t stg
                   SET status = 'S', last_updated_date = SYSDATE, last_updated_by = pn_user_id
                 WHERE     batch_id = pn_batch_id
                       AND source_po_header_id = pn_po_header_id
                       AND action_type = pv_action_type
                       AND status = 'N'
                       AND new_po_number IS NOT NULL
                       AND new_po_line_num IS NOT NULL;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exp_error       :=
                        'Error while updating staging table:' || SQLERRM;
                    pv_error_message   := lv_exp_error;
                    RETURN;
            END;

            BEGIN
                UPDATE xxd_po_modify_details_t stg
                   SET status = 'E', error_message = NVL (lv_error_message, 'Error while cancelling po lines and creating new po'), last_updated_date = SYSDATE,
                       last_updated_by = pn_user_id
                 WHERE     batch_id = pn_batch_id
                       AND source_po_header_id = pn_po_header_id
                       AND action_type = pv_action_type
                       AND status = 'N'
                       AND (new_po_number IS NULL OR new_po_line_num IS NULL);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exp_error       :=
                        'Error while updating staging table:' || SQLERRM;
                    pv_error_message   := lv_exp_error;
                    RETURN;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_exp_error       := 'Error In move_po_action' || SQLERRM;
            pv_error_message   := lv_exp_error;
            RETURN;
    END move_po_action;


    PROCEDURE change_supplier_action (pn_user_id             IN     NUMBER,
                                      pn_batch_id            IN     NUMBER,
                                      pn_po_header_id        IN     NUMBER,
                                      pn_vendor_id           IN     NUMBER,
                                      pn_vendor_site_id      IN     NUMBER,
                                      pv_action_type         IN     VARCHAR2,
                                      pv_intercompany_flag   IN     VARCHAR2,
                                      pv_error_message          OUT VARCHAR2)
    IS
        CURSOR stg_lines_rec_cur IS
            SELECT DISTINCT source_po_header_id, source_po_line_id, batch_id,
                            po_cancelled_flag, cancel_po_header_flag
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id
                   AND cancel_po_header_flag = 'N'
            UNION
            SELECT DISTINCT source_po_header_id, 1 source_po_line_id, batch_id,
                            po_cancelled_flag, cancel_po_header_flag
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id
                   AND cancel_po_header_flag = 'Y';

        CURSOR drop_ship_rec_cur IS
            SELECT *
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id
                   AND drop_ship_source_id IS NOT NULL;

        CURSOR stg_lines_cur (cp_req_header_id IN NUMBER)
        IS
            SELECT *
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND source_pr_header_id =
                       NVL (cp_req_header_id, source_pr_header_id)
                   AND batch_id = pn_batch_id;

        CURSOR stg_req_cur IS
            SELECT DISTINCT source_pr_header_id
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id;

        CURSOR stg_iso_cur IS
            SELECT DISTINCT source_iso_header_id
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id;


        lv_status_flag            VARCHAR2 (2);
        lv_error_message          VARCHAR2 (4000);
        lv_error_flag             VARCHAR2 (2);
        ln_error_count            NUMBER;
        lv_error_msg              VARCHAR2 (4000);
        lv_exp_error              VARCHAR2 (4000);
        po_line_det               xxdo.xxd_po_line_det_type;
        po_iso_det                xxdo.xxd_po_iso_det_type;
        ln_po_int_batch_id        NUMBER;
        lv_req_number             VARCHAR2 (50);
        ln_req_import_id          NUMBER;
        ln_req_header_id          NUMBER;
        lv_new_po_num             NUMBER;
        ln_new_line_location_id   NUMBER;
        ln_po_line_id             NUMBER;
        --Start Added for CCR0010003
        ln_po_header_id           NUMBER;
        ln_calc_transit_days      NUMBER;
        ln_move_po_num            NUMBER;
        ln_vendor_id              NUMBER;
        ln_vendor_site_id         NUMBER;
        lv_po_type                VARCHAR2 (240) := NULL;
        ln_vendor_site_code_dff   VARCHAR2 (240) := NULL;
    --End Added for CCR0010003

    BEGIN
        --Start changes for CCR0010003
        fnd_file.put_line (fnd_file.LOG, 'pn_user_id : ' || pn_user_id); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (fnd_file.LOG, 'pn_batch_id : ' || pn_batch_id); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (fnd_file.LOG,
                           'pn_po_header_id : ' || pn_po_header_id); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (fnd_file.LOG, 'pn_vendor_id : ' || pn_vendor_id); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (fnd_file.LOG,
                           'pn_vendor_site_id : ' || pn_vendor_site_id); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (fnd_file.LOG,
                           'pv_action_type : ' || pv_action_type); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (fnd_file.LOG,
                           'pv_intercompany_flag : ' || pv_intercompany_flag); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022


        IF NVL (pv_intercompany_flag, 'N') = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Inside pv_intercompany_flag = Y'); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022

            po_line_det      := xxdo.xxd_po_line_det_type (NULL);
            po_iso_det       := xxdo.xxd_po_iso_det_type (NULL);
            ln_error_count   := 0;
            SAVEPOINT xxd_transaction;
            lv_error_msg     := NULL;

            FOR stg_lines_rec IN stg_lines_rec_cur
            LOOP
                IF stg_lines_rec.po_cancelled_flag = 'N'
                THEN
                    IF stg_lines_rec.source_po_line_id = 1
                    THEN
                        ln_po_line_id   := NULL;
                    ELSE
                        ln_po_line_id   := stg_lines_rec.source_po_line_id;
                    END IF;

                    --Start changes for CCR0010003

                    BEGIN
                        SELECT pha.segment1, vendor_id, vendor_site_id
                          INTO ln_move_po_num, ln_vendor_id, ln_vendor_site_id
                          FROM po_headers_all pha
                         WHERE pha.po_header_id = pn_po_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                lv_error_message || ' ' || SQLERRM;
                            pv_error_message   := lv_exp_error;
                    END;


                    --Get Intransit days from lookup for change supplier\site
                    BEGIN
                        ln_calc_transit_days   :=
                            xxd_po_pomodify_utils_pkg.get_pol_transit_days (
                                ln_move_po_num,
                                pv_action_type,
                                pn_vendor_id,                  --ln_vendor_id,
                                pn_vendor_site_id,        --ln_vendor_site_id,
                                ln_vendor_site_code_dff);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_calc_transit_days   := 0;
                    END;


                    BEGIN
                        SELECT pha.attribute10                      -- PO Type
                          INTO lv_po_type
                          FROM po_headers_all pha
                         WHERE pha.segment1 = ln_move_po_num;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error while getting PO Type. ');
                    END;

                    IF ln_calc_transit_days < 0 AND lv_po_type <> 'INTL_DIST'
                    THEN
                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Transit days not defined for the Supplier in Lookup. '
                                || ln_po_line_id
                                || lv_error_message,
                                1,
                                2000);
                    END IF;



                    IF ln_error_count > 0
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET po_cancelled_flag = 'E', pr_cancelled_flag = 'E', --DECODE (pr_cancelled_flag, 'N', 'E', ''),
                                                                                     iso_cancelled_flag = 'E',
                                   ir_cancelled_flag = 'E', --DECODE (ir_cancelled_flag, 'N', 'E', ''),
                                                            status = 'E', error_message = lv_error_msg,
                                   last_updated_date = SYSDATE, last_updated_by = pn_user_id
                             WHERE     status = 'N'
                                   AND source_po_header_id = pn_po_header_id --pn_source_pr_header_id
                                   AND batch_id = pn_batch_id;

                            --COMMIT;
                            CONTINUE;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ROLLBACK TO SAVEPOINT xxd_transaction;
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;

                        ROLLBACK TO SAVEPOINT xxd_transaction;

                        RETURN;

                        pv_error_message   :=
                               'Transit days not defined for the Supplier in Lookup. '
                            || pv_error_message;
                        RETURN;
                    END IF;



                    xxd_po_pomodify_utils_pkg.cancel_po_line (
                        pn_user_id,
                        stg_lines_rec.source_po_header_id,
                        ln_po_line_id,
                        'Y',                              --cancel_requisition
                        lv_status_flag,
                        lv_error_message);

                    IF lv_status_flag = 'S'
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET po_cancelled_flag = 'Y', pr_cancelled_flag = DECODE (pr_cancelled_flag, 'N', 'Y', ''), last_updated_date = SYSDATE,
                                   last_updated_by = pn_user_id
                             WHERE     batch_id = pn_batch_id
                                   AND status = 'N'
                                   AND source_po_header_id =
                                       stg_lines_rec.source_po_header_id
                                   AND source_po_line_id =
                                       NVL (ln_po_line_id, source_po_line_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    ELSE
                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Error while cancelling po_line_id:'
                                || ln_po_line_id
                                || lv_error_message,
                                1,
                                2000);
                    END IF;
                END IF;
            END LOOP;

            IF ln_error_count > 0
            THEN
                ROLLBACK TO SAVEPOINT xxd_transaction;

                BEGIN
                    UPDATE xxd_po_modify_details_t
                       SET po_cancelled_flag = 'E', pr_cancelled_flag = DECODE (pr_cancelled_flag, 'N', 'E', ''), iso_cancelled_flag = 'E',
                           ir_cancelled_flag = DECODE (ir_cancelled_flag, 'N', 'E', ''), status = 'E', error_message = lv_error_msg,
                           last_updated_date = SYSDATE, last_updated_by = pn_user_id
                     WHERE     status = 'N'
                           AND source_po_header_id = pn_po_header_id
                           AND batch_id = pn_batch_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_exp_error       :=
                            'Error while updating staging table:' || SQLERRM;
                        pv_error_message   := lv_exp_error;
                        RETURN;
                END;

                pv_error_message   :=
                       'Could not cancel Purcahse Order lines or Sales Order Lines '
                    || lv_error_message;
                RETURN;
            ELSE
                COMMIT;

                --commiting PO,PR,ISO,IR cancellation
                --create pr
                FOR stg_lines IN stg_lines_cur ('')
                LOOP
                    po_line_det.EXTEND;
                    po_line_det (po_line_det.COUNT)   :=
                        xxdo.xxd_po_line_det_tab (
                            stg_lines.source_po_line_id,
                            stg_lines.source_pr_line_id,
                            NULL);
                END LOOP;

                FOR stg_iso_rec IN stg_iso_cur
                LOOP
                    po_iso_det.EXTEND;
                    po_iso_det (po_iso_det.COUNT)   :=
                        xxdo.xxd_po_iso_det_tab (
                            stg_iso_rec.source_iso_header_id);
                END LOOP;

                xxd_po_pomodify_utils_pkg.create_pr_from_iso (
                    po_iso_det,
                    --ISO to process
                    po_line_det,
                    pn_vendor_id,
                    pn_vendor_site_id,
                    pn_user_id,
                    lv_req_number,
                    ln_req_import_id,
                    lv_error_flag,
                    lv_error_message);

                BEGIN
                    SELECT requisition_header_id
                      INTO ln_req_header_id
                      FROM po_requisition_headers_all
                     WHERE segment1 = lv_req_number;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_req_header_id   := NULL;
                END;

                IF ln_req_header_id IS NULL
                THEN
                    BEGIN
                        UPDATE xxd_po_modify_details_t stg
                           SET status              = 'E',
                               error_message      =
                                   SUBSTR (
                                       (NVL (
                                            (SELECT 'Purchase Requisition interface error: ' || pe.error_message
                                               FROM po_interface_errors pe, po_requisitions_interface_all pri
                                              WHERE     pri.request_id =
                                                        ln_req_import_id
                                                    AND pri.transaction_id =
                                                        pe.interface_transaction_id
                                                    AND pri.line_attribute1 =
                                                        stg.source_po_line_id
                                                    AND pri.line_attribute2 =
                                                        stg.source_pr_line_id
                                                    AND ROWNUM = 1),
                                            'Error While Creating Purchase Requisition05')),
                                       1,
                                       2000),
                               last_updated_date   = SYSDATE,
                               last_updated_by     = pn_user_id
                         WHERE     source_po_header_id = pn_po_header_id
                               AND action_type = pv_action_type
                               AND batch_id = pn_batch_id
                               AND status = 'N';

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                   'Error while updating staging table:'
                                || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;

                    lv_error_message   :=
                        'Error While Creating Requistion ' || SQLERRM;
                    RETURN;
                ELSE
                    --Updating stgaing table with new requistion
                    BEGIN
                        UPDATE xxd_po_modify_details_t stg
                           SET new_pr_number       = lv_req_number,
                               new_pr_header_id    = ln_req_header_id,
                               (new_pr_line_num, new_pr_line_id)   =
                                   (SELECT prla.line_num, prla.requisition_line_id
                                      FROM po_requisition_headers_all prha, po_requisition_lines_all prla
                                     WHERE     prha.requisition_header_id =
                                               prla.requisition_header_id
                                           AND prha.segment1 = lv_req_number
                                           AND prla.attribute1 =
                                               stg.source_po_line_id
                                           AND prla.attribute2 =
                                               stg.source_pr_line_id),
                               last_updated_date   = SYSDATE,
                               last_updated_by     = pn_user_id
                         WHERE     source_po_header_id = pn_po_header_id
                               AND action_type = pv_action_type
                               AND batch_id = pn_batch_id
                               AND status = 'N';

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                   'Error while updating staging table:'
                                || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;

                    xxd_po_pomodify_utils_pkg.create_po (pn_user_id, pn_po_header_id, pn_vendor_id, --vendor_id
                                                                                                    pn_vendor_site_id, --vendor_site_id
                                                                                                                       po_line_det, ln_req_header_id, '', --ln_move_org_id,
                                                                                                                                                          pv_intercompany_flag, -- Ver 3.0
                                                                                                                                                                                pv_action_type, lv_new_po_num, ln_po_int_batch_id, lv_error_flag
                                                         , lv_error_message);

                    IF lv_new_po_num IS NOT NULL
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t stg
                               SET new_po_number       = lv_new_po_num,
                                   (new_po_header_id,
                                    new_po_line_num,
                                    new_po_line_id)   =
                                       (SELECT pla.po_header_id, pla.line_num, pla.po_line_id
                                          FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_req_distributions_all prd,
                                               po_distributions_all pda, po_lines_all pla
                                         WHERE     prha.requisition_header_id =
                                                   prla.requisition_header_id
                                               AND prha.segment1 =
                                                   lv_req_number
                                               AND prd.requisition_line_id =
                                                   prla.requisition_line_id
                                               AND pda.req_distribution_id =
                                                   prd.distribution_id
                                               AND pda.po_line_id =
                                                   pla.po_line_id
                                               AND prla.line_num =
                                                   stg.new_pr_line_num),
                                   last_updated_date   = SYSDATE,
                                   last_updated_by     = pn_user_id
                             WHERE     source_po_header_id = pn_po_header_id
                                   AND action_type = pv_action_type
                                   AND batch_id = pn_batch_id
                                   AND status = 'N';

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    ELSE
                        BEGIN
                            UPDATE xxd_po_modify_details_t stg
                               SET status              = 'E',
                                   error_message      =
                                       SUBSTR (
                                           (NVL (
                                                (SELECT 'Purchase order interface error: ' || pe.error_message
                                                   FROM po_interface_errors pe, po_headers_interface phi, po_lines_interface pli
                                                  WHERE     phi.batch_id =
                                                            ln_po_int_batch_id
                                                        AND phi.interface_header_id =
                                                            pli.interface_header_id
                                                        AND phi.interface_header_id =
                                                            pe.interface_header_id
                                                        AND pli.interface_line_id =
                                                            NVL (
                                                                pe.interface_line_id,
                                                                pli.interface_line_id)
                                                        AND pli.requisition_line_id =
                                                            stg.new_pr_line_id
                                                        AND ROWNUM = 1),
                                                'Error While Creating Purchase Order')),
                                           1,
                                           2000),
                                   last_updated_date   = SYSDATE,
                                   last_updated_by     = pn_user_id
                             WHERE     source_po_header_id = pn_po_header_id
                                   AND action_type = pv_action_type
                                   AND batch_id = pn_batch_id
                                   AND status = 'N';

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    END IF;
                END IF;

                FOR stg_iso_rec IN stg_iso_cur
                LOOP
                    xxd_po_pomodify_utils_pkg.link_iso_and_po (
                        stg_iso_rec.source_iso_header_id,
                        lv_error_msg);
                END LOOP;

                IF lv_error_msg IS NOT NULL
                THEN
                    UPDATE xxd_po_modify_details_t stg
                       SET status = 'E', error_message = lv_error_msg, last_updated_date = SYSDATE,
                           last_updated_by = pn_user_id
                     WHERE     batch_id = pn_batch_id
                           AND source_po_header_id = pn_po_header_id
                           AND action_type = pv_action_type
                           AND status = 'N';
                END IF;


                IF pn_vendor_id IS NOT NULL AND pn_vendor_site_id IS NOT NULL
                THEN
                    --Get Intransit days from lookup for change supplier\site
                    BEGIN
                        ln_calc_transit_days   :=
                            xxd_po_pomodify_utils_pkg.get_pol_transit_days (
                                lv_new_po_num,
                                pv_action_type,
                                pn_vendor_id,                  --ln_vendor_id,
                                pn_vendor_site_id,        --ln_vendor_site_id,
                                ln_vendor_site_code_dff);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_calc_transit_days   := 0;
                    END;

                    --Calling procedure to update calculated New Promise\Need by Dates
                    xxd_po_pomodify_utils_pkg.update_calc_need_by_date (
                        pn_user_id,
                        lv_new_po_num,
                        ln_calc_transit_days,
                        pn_vendor_id,
                        pn_vendor_site_id,
                        NULL,
                        NULL,
                        pv_action_type, -- Added by Gowrishankar for CCR0010003 on 14-Sep-2022
                        lv_error_flag,
                        lv_error_message);

                    IF lv_error_message IS NOT NULL
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t stg
                               SET status = 'E', error_message = 'Promise\Needby Date Calc failure'
                             WHERE     source_po_header_id = pn_po_header_id
                                   AND action_type = pv_action_type
                                   AND batch_id = pn_batch_id;

                            --AND status = 'N';

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    END IF;
                ELSE
                    --End Added for CCR0010003
                    --Calling below procedure for change 1.1
                    --Calling procedure to update po need_by_date when there is mismatach between PR ans PO
                    xxd_po_pomodify_utils_pkg.update_po_need_by_date (
                        pn_user_id,
                        lv_new_po_num,
                        lv_error_flag,
                        lv_error_message);

                    IF lv_error_message IS NOT NULL
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t stg
                               SET status = 'E', error_message = 'Needby Date Update failure'
                             WHERE     source_po_header_id = pn_po_header_id
                                   AND action_type = pv_action_type
                                   AND batch_id = pn_batch_id;

                            --AND status = 'N';

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    END IF;
                END IF;                                 --Added for CCR0010003
            -- Change for CCR0010003 Ends

            END IF;

            BEGIN
                UPDATE xxd_po_modify_details_t stg
                   SET status = 'S', last_updated_date = SYSDATE, last_updated_by = pn_user_id
                 WHERE     batch_id = pn_batch_id
                       AND source_po_header_id = pn_po_header_id
                       AND action_type = pv_action_type
                       AND status = 'N'
                       AND new_po_number IS NOT NULL
                       AND new_po_line_num IS NOT NULL;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exp_error       :=
                        'Error while updating staging table:' || SQLERRM;
                    pv_error_message   := lv_exp_error;
                    RETURN;
            END;

            BEGIN
                UPDATE xxd_po_modify_details_t stg
                   SET status = 'E', error_message = NVL (lv_error_message, 'Error while cancelling po lines and creating new po'), last_updated_date = SYSDATE,
                       last_updated_by = pn_user_id
                 WHERE     batch_id = pn_batch_id
                       AND source_po_header_id = pn_po_header_id
                       AND action_type = pv_action_type
                       AND status = 'N'
                       AND (new_po_number IS NULL OR new_po_line_num IS NULL);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exp_error       :=
                        'Error while updating staging table:' || SQLERRM;
                    pv_error_message   := lv_exp_error;
                    RETURN;
            END;
        END IF;

        IF NVL (pv_intercompany_flag, 'N') = 'N'
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Inside pv_intercompany_flag = N '); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022

            ln_error_count   := 0;
            SAVEPOINT xxd_transaction;
            lv_error_msg     := NULL;

            FOR stg_lines_rec IN stg_lines_rec_cur
            LOOP
                IF stg_lines_rec.po_cancelled_flag = 'N'
                THEN
                    IF stg_lines_rec.source_po_line_id = 1
                    THEN
                        ln_po_line_id   := NULL;
                    ELSE
                        ln_po_line_id   := stg_lines_rec.source_po_line_id;
                    END IF;

                    --Start changes for CCR0010003

                    BEGIN
                        BEGIN
                            SELECT pha.segment1, vendor_id, vendor_site_id
                              INTO ln_move_po_num, ln_vendor_id, ln_vendor_site_id
                              FROM po_headers_all pha
                             WHERE pha.po_header_id = pn_po_header_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                    lv_error_message || ' ' || SQLERRM;
                                pv_error_message   := lv_exp_error;
                        END;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                lv_error_message || ' ' || SQLERRM;
                            pv_error_message   := lv_exp_error;
                    END;


                    --Get Intransit days from lookup for change supplier\site
                    BEGIN
                        ln_calc_transit_days   :=
                            xxd_po_pomodify_utils_pkg.get_pol_transit_days (
                                ln_move_po_num,
                                pv_action_type,
                                pn_vendor_id,                  --ln_vendor_id,
                                pn_vendor_site_id,        --ln_vendor_site_id,
                                ln_vendor_site_code_dff);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_calc_transit_days   := 0;
                    END;

                    BEGIN
                        SELECT pha.attribute10                      -- PO Type
                          INTO lv_po_type
                          FROM po_headers_all pha
                         WHERE pha.segment1 = ln_move_po_num;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error while getting PO Type. '); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
                    END;

                    IF ln_calc_transit_days < 0 AND lv_po_type <> 'INTL_DIST'
                    THEN -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Transit days not defined for the Supplier in Lookup. ');

                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Transit days not defined for the Supplier in Lookup. '
                                || ln_po_line_id
                                || lv_error_message,
                                1,
                                2000);
                    END IF;


                    IF ln_error_count > 0
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET po_cancelled_flag = 'E', pr_cancelled_flag = 'E', --DECODE (pr_cancelled_flag, 'N', 'E', ''),
                                                                                     iso_cancelled_flag = 'E',
                                   ir_cancelled_flag = 'E', --DECODE (ir_cancelled_flag, 'N', 'E', ''),
                                                            status = 'E', error_message = lv_error_msg,
                                   last_updated_date = SYSDATE, last_updated_by = pn_user_id
                             WHERE     status = 'N'
                                   AND source_po_header_id = pn_po_header_id --pn_source_pr_header_id
                                   AND batch_id = pn_batch_id;

                            --COMMIT;
                            CONTINUE;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ROLLBACK TO SAVEPOINT xxd_transaction;
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;


                        ROLLBACK TO SAVEPOINT xxd_transaction;


                        RETURN;

                        pv_error_message   :=
                               'Transit days not defined for the Supplier in Lookup. '
                            || pv_error_message;
                        RETURN;
                    END IF;


                    xxd_po_pomodify_utils_pkg.cancel_po_line (
                        pn_user_id,
                        stg_lines_rec.source_po_header_id,
                        ln_po_line_id,
                        'N',                              --cancel_requisition
                        lv_status_flag,
                        lv_error_message);

                    IF lv_status_flag = 'S'
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET po_cancelled_flag = 'Y', pr_cancelled_flag = 'N', last_updated_date = SYSDATE,
                                   last_updated_by = pn_user_id
                             WHERE     batch_id = pn_batch_id
                                   AND status = 'N'
                                   AND source_po_header_id =
                                       stg_lines_rec.source_po_header_id
                                   AND source_po_line_id =
                                       NVL (ln_po_line_id, source_po_line_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    ELSE
                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Error while cancelling po_line_id:'
                                || ln_po_line_id
                                || lv_error_message,
                                1,
                                2000);
                    END IF;
                END IF;
            END LOOP;

            IF ln_error_count > 0
            THEN
                ROLLBACK TO SAVEPOINT xxd_transaction;

                BEGIN
                    UPDATE xxd_po_modify_details_t
                       SET po_cancelled_flag = 'E', pr_cancelled_flag = DECODE (pr_cancelled_flag, 'N', 'E', ''), iso_cancelled_flag = 'E',
                           ir_cancelled_flag = DECODE (ir_cancelled_flag, 'N', 'E', ''), status = 'E', error_message = lv_error_msg,
                           last_updated_date = SYSDATE, last_updated_by = pn_user_id
                     WHERE     status = 'N'
                           AND source_po_header_id = pn_po_header_id
                           AND batch_id = pn_batch_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_exp_error       :=
                            'Error while updating staging table:' || SQLERRM;
                        pv_error_message   := lv_exp_error;
                        RETURN;
                END;

                pv_error_message   :=
                       'Could not cancel Purcahse Order lines or Sales Order Lines '
                    || lv_error_message;
                RETURN;
            ELSE
                COMMIT;

                --commiting PO,PR,ISO,IR cancellation
                FOR stg_req_rec IN stg_req_cur
                LOOP
                    po_line_det   := xxdo.xxd_po_line_det_type (NULL);

                    FOR stg_lines
                        IN stg_lines_cur (stg_req_rec.source_pr_header_id)
                    LOOP
                        po_line_det.EXTEND;
                        po_line_det (po_line_det.COUNT)   :=
                            xxdo.xxd_po_line_det_tab (
                                stg_lines.source_po_line_id,
                                stg_lines.source_pr_line_id,
                                NULL);

                        xxd_po_pomodify_utils_pkg.update_po_req_link (
                            stg_lines.source_po_line_id,
                            lv_status_flag,
                            lv_error_message);
                    END LOOP;

                    xxd_po_pomodify_utils_pkg.update_po_requisition_line (
                        pn_user_id,
                        stg_req_rec.source_pr_header_id,
                        pn_vendor_id,
                        pn_vendor_site_id,
                        '',
                        po_line_det,
                        'Y',                               --req_auto_approval
                        lv_error_flag,
                        lv_error_message);

                    IF     lv_error_message IS NULL
                       AND NVL (lv_error_flag, 'S') <> 'E'
                    THEN
                        xxd_po_pomodify_utils_pkg.approve_requisition (
                            stg_req_rec.source_pr_header_id,
                            lv_error_flag,
                            lv_error_message);

                        IF lv_error_message IS NOT NULL
                        THEN
                            UPDATE xxd_po_modify_details_t stg
                               SET status = 'E', error_message = 'Error while approving purchase requisition: ' || lv_error_msg, last_updated_date = SYSDATE,
                                   last_updated_by = pn_user_id
                             WHERE     source_po_header_id = pn_po_header_id
                                   AND action_type = pv_action_type
                                   AND batch_id = pn_batch_id
                                   AND status = 'N';
                        END IF;
                    END IF;
                END LOOP;

                IF    lv_error_message IS NOT NULL
                   OR NVL (lv_error_flag, 'S') = 'E'
                THEN
                    BEGIN
                        UPDATE xxd_po_modify_details_t stg
                           SET status = 'E', error_message = 'Error while updating requisition01 ' || lv_error_message
                         WHERE     source_po_header_id = pn_po_header_id
                               AND action_type = pv_action_type
                               AND batch_id = pn_batch_id
                               AND status = 'N';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                   'Error while updating staging table:'
                                || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;

                    COMMIT;
                ELSE
                    BEGIN
                        xxd_po_pomodify_utils_pkg.create_po (
                            pn_user_id,
                            pn_po_header_id,
                            pn_vendor_id,
                            pn_vendor_site_id,
                            po_line_det,
                            '',                            --new_req_header_id
                            '',                                  --move_org_id
                            pv_intercompany_flag,                   -- ver 3.0
                            pv_action_type,
                            lv_new_po_num,
                            ln_po_int_batch_id,
                            lv_error_flag,
                            lv_error_message);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                   'Error in caling xxd_po_pomodify_utils_pkg.create_po '
                                || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;


                    IF lv_new_po_num IS NOT NULL
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t stg
                               SET new_po_number       = lv_new_po_num,
                                   (new_po_header_id,
                                    new_po_line_num,
                                    new_po_line_id)   =
                                       (SELECT pla.po_header_id, pla.line_num, pla.po_line_id
                                          FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_req_distributions_all prd,
                                               po_distributions_all pda, po_lines_all pla
                                         WHERE     prha.requisition_header_id =
                                                   stg.source_pr_header_id
                                               AND prha.requisition_header_id =
                                                   prla.requisition_header_id
                                               AND prd.requisition_line_id =
                                                   prla.requisition_line_id
                                               AND pda.req_distribution_id =
                                                   prd.distribution_id
                                               AND pda.po_line_id =
                                                   pla.po_line_id
                                               AND prla.requisition_line_id =
                                                   stg.source_pr_line_id),
                                   last_updated_date   = SYSDATE,
                                   last_updated_by     = pn_user_id
                             WHERE     source_po_header_id = pn_po_header_id
                                   AND action_type = pv_action_type
                                   AND batch_id = pn_batch_id
                                   AND status = 'N';

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    ELSE
                        BEGIN
                            UPDATE xxd_po_modify_details_t stg
                               SET status              = 'E',
                                   error_message      =
                                       SUBSTR (
                                           (NVL (
                                                (SELECT 'Purchase order interface error: ' || pe.error_message
                                                   FROM po_interface_errors pe, po_headers_interface phi, po_lines_interface pli
                                                  WHERE     phi.batch_id =
                                                            ln_po_int_batch_id
                                                        AND phi.interface_header_id =
                                                            pli.interface_header_id
                                                        AND phi.interface_header_id =
                                                            pe.interface_header_id
                                                        AND pli.interface_line_id =
                                                            NVL (
                                                                pe.interface_line_id,
                                                                pli.interface_line_id)
                                                        AND pli.requisition_line_id =
                                                            stg.source_pr_line_id
                                                        AND ROWNUM = 1),
                                                'Error While Creating Purchase Order')),
                                           1,
                                           2000),
                                   last_updated_date   = SYSDATE,
                                   last_updated_by     = pn_user_id
                             WHERE     source_po_header_id = pn_po_header_id
                                   AND action_type = pv_action_type
                                   AND batch_id = pn_batch_id
                                   AND status = 'N';

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    END IF;
                END IF;
            END IF;

            FOR drop_ship_rec IN drop_ship_rec_cur
            LOOP
                BEGIN
                    SELECT line_location_id
                      INTO ln_new_line_location_id
                      FROM po_line_locations_all
                     WHERE     po_header_id = drop_ship_rec.new_po_header_id
                           AND po_line_id = drop_ship_rec.new_po_line_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_flag      := 'E';
                        lv_exp_error       :=
                            'Error while updating staging table:' || SQLERRM;
                        pv_error_message   := lv_exp_error;
                        RETURN;
                        RETURN;
                END;

                xxd_po_pomodify_utils_pkg.update_drop_ship (
                    pn_user_id,
                    drop_ship_rec.source_pr_header_id,
                    drop_ship_rec.source_pr_line_id,
                    drop_ship_rec.new_po_header_id,
                    drop_ship_rec.new_po_line_id,
                    ln_new_line_location_id,
                    lv_error_flag,
                    lv_error_message);

                IF lv_error_message IS NOT NULL
                THEN
                    BEGIN
                        UPDATE xxd_po_modify_details_t
                           SET status = 'E', error_message = 'Error while updating drop ship sources ' || lv_error_message, last_updated_date = SYSDATE,
                               last_updated_by = pn_user_id
                         WHERE     batch_id = pn_batch_id
                               AND status = 'N'
                               AND record_id = drop_ship_rec.record_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                   'Error while updating staging table:'
                                || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;
                ELSE
                    COMMIT;
                END IF;
            END LOOP;

            --Start changes for CCR0010003

            IF pn_vendor_id IS NOT NULL AND pn_vendor_site_id IS NOT NULL
            THEN
                --Get Intransit days from lookup for change supplier\site
                BEGIN
                    ln_calc_transit_days   :=
                        xxd_po_pomodify_utils_pkg.get_pol_transit_days (
                            lv_new_po_num,
                            pv_action_type,
                            pn_vendor_id,                      --ln_vendor_id,
                            pn_vendor_site_id,            --ln_vendor_site_id,
                            ln_vendor_site_code_dff);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_calc_transit_days   := 0;
                END;

                --Calling procedure to update calculated New Promise\Need by Dates
                xxd_po_pomodify_utils_pkg.update_calc_need_by_date (
                    pn_user_id,
                    lv_new_po_num,
                    ln_calc_transit_days,
                    pn_vendor_id,
                    pn_vendor_site_id,
                    NULL,
                    NULL,
                    pv_action_type, -- Added by Gowrishankar for CCR0010003 on 14-Sep-2022
                    lv_error_flag,
                    lv_error_message);
            ELSE
                --End Added for CCR0010003
                --Calling below procedure for change 1.1
                --Calling procedure to update po need_by_date when there is mismatach between PR ans PO
                xxd_po_pomodify_utils_pkg.update_po_need_by_date (
                    pn_user_id,
                    lv_new_po_num,
                    lv_error_flag,
                    lv_error_message);
            END IF;                                     --Added for CCR0010003

            IF lv_error_message IS NOT NULL
            THEN
                BEGIN
                    UPDATE xxd_po_modify_details_t stg
                       SET status = 'E', error_message = 'Promise\Needby Date Calc failure'
                     WHERE     source_po_header_id = pn_po_header_id
                           AND action_type = pv_action_type
                           AND batch_id = pn_batch_id;

                    -- AND status = 'N';

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_exp_error       :=
                            'Error while updating staging table:' || SQLERRM;
                        pv_error_message   := lv_exp_error;
                        RETURN;
                END;
            END IF;

            BEGIN
                UPDATE xxd_po_modify_details_t stg
                   SET status = 'S', last_updated_date = SYSDATE, last_updated_by = pn_user_id
                 WHERE     batch_id = pn_batch_id
                       AND source_po_header_id = pn_po_header_id
                       AND action_type = pv_action_type
                       AND status = 'N'
                       AND new_po_number IS NOT NULL
                       AND new_po_line_num IS NOT NULL;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exp_error       :=
                        'Error while updating staging table:' || SQLERRM;
                    pv_error_message   := lv_exp_error;
                    RETURN;
            END;

            BEGIN
                UPDATE xxd_po_modify_details_t stg
                   SET status = 'E', error_message = NVL (lv_error_message, 'Error while cancelling po lines and creating new po'), last_updated_date = SYSDATE,
                       last_updated_by = pn_user_id
                 WHERE     batch_id = pn_batch_id
                       AND source_po_header_id = pn_po_header_id
                       AND action_type = pv_action_type
                       AND status = 'N'
                       AND (new_po_number IS NULL OR new_po_line_num IS NULL);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exp_error       :=
                        'Error while updating staging table:' || SQLERRM;
                    pv_error_message   := lv_exp_error;
                    RETURN;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_exp_error       :=
                'Error in change_supplier_action procedure' || SQLERRM;
            pv_error_message   := lv_exp_error;
            RETURN;
    END change_supplier_action;



    PROCEDURE move_org_action (pn_user_id IN NUMBER, pn_batch_id IN NUMBER, pn_po_header_id IN NUMBER, pn_source_pr_header_id IN NUMBER, pn_dest_org_id IN NUMBER, pv_action_type IN VARCHAR2
                               , pv_intercompany_flag IN VARCHAR2, move_org_operating_unit_flag IN VARCHAR2, pv_error_message OUT VARCHAR2)
    IS
        CURSOR stg_lines_rec_cur IS
            SELECT DISTINCT source_po_header_id, source_po_line_id, batch_id,
                            po_cancelled_flag
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id
                   AND cancel_po_header_flag = 'N'
            UNION
            SELECT DISTINCT source_po_header_id, 1 source_po_line_id, batch_id,
                            po_cancelled_flag
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id
                   AND cancel_po_header_flag = 'Y';

        CURSOR stg_iso_rec_cur (cp_po_type IN VARCHAR2)
        IS
            SELECT DISTINCT source_iso_header_id, source_iso_line_id, batch_id
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id
                   AND cp_po_type <> 'DIRECT_SHIP' -- VER 2.0  -- NO iso cancellation for direct ship
                   AND source_iso_header_id IS NOT NULL
                   AND cancel_iso_header_flag = 'N'
            UNION
            SELECT DISTINCT source_iso_header_id, 1 source_iso_line_id, batch_id
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND cp_po_type <> 'DIRECT_SHIP' -- VER 2.0  -- NO iso cancellation for direct ship
                   AND batch_id = pn_batch_id
                   AND source_iso_header_id IS NOT NULL
                   AND cancel_iso_header_flag = 'Y';

        CURSOR stg_lines_cur IS
            SELECT *
              FROM xxd_po_modify_details_t
             WHERE     1 = 1
                   AND status = 'N'
                   AND source_po_header_id = pn_po_header_id
                   AND action_type = pv_action_type
                   AND batch_id = pn_batch_id;


        CURSOR cur_transit_day_check (p_po_header_id NUMBER)
        IS
              SELECT pha.segment1 po_num, pha.po_header_id, pha.vendor_id,
                     pha.vendor_site_id, pha.attribute10 po_type, pla.po_line_id,
                     pla.line_num po_line_num, TRIM (pla.attribute7) po_line_vendor_site, prha.requisition_header_id,
                     prha.segment1 requisition_num, prla.line_num requisition_line_num
                FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla,
                     po_distributions_all pda, po_requisition_headers_all prha, po_requisition_lines_all prla,
                     po_req_distributions_all prda
               WHERE     1 = 1
                     AND pla.po_header_id = pha.po_header_id
                     AND plla.po_header_id = pha.po_header_id
                     AND plla.po_line_id = pla.po_line_id
                     AND plla.line_location_id = pda.line_location_id
                     AND pda.po_header_id = pha.po_header_id
                     AND pda.req_distribution_id = prda.distribution_id
                     AND prda.requisition_line_id = prla.requisition_line_id
                     AND prla.requisition_header_id =
                         prha.requisition_header_id
                     AND pha.po_header_id = p_po_header_id
            ORDER BY pha.segment1, pla.line_num;


        lv_status_flag             VARCHAR2 (2);
        lv_error_message           VARCHAR2 (10000);
        lv_error_flag              VARCHAR2 (2);
        ln_error_count             NUMBER := 0;
        lv_error_msg               VARCHAR2 (4000);
        lv_exp_error               VARCHAR2 (10000);
        po_line_det                xxdo.xxd_po_line_det_type;
        ln_po_int_batch_id         NUMBER;
        lv_req_number              VARCHAR2 (50);
        ln_req_import_id           NUMBER;
        ln_req_header_id           NUMBER;
        lv_new_po_num              NUMBER;
        ln_po_line_id              NUMBER;
        ln_iso_line_id             NUMBER;
        ln_vendor_id               NUMBER;
        ln_vendor_site_id          NUMBER;
        ln_vendor_site_code        VARCHAR2 (50);
        --Start Added for CCR0010003
        ln_po_header_id            NUMBER;
        ln_calc_transit_days       NUMBER;
        lv_po_type                 VARCHAR2 (240) := NULL;
        ln_source_po_num           VARCHAR2 (240);
        ln_source_vendor_id        NUMBER;
        ln_source_vendor_site_id   NUMBER;
        ln_move_po_num             VARCHAR2 (240);
        ln_vendor_site_code_dff    VARCHAR2 (240) := NULL;
    --End Added for CCR0010003
    BEGIN
        --Start changes for CCR0010003
        fnd_file.put_line (fnd_file.LOG, 'pn_user_id : ' || pn_user_id); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (fnd_file.LOG, 'pn_batch_id : ' || pn_batch_id); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (fnd_file.LOG,
                           'pn_po_header_id : ' || pn_po_header_id); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (
            fnd_file.LOG,
            'pn_source_pr_header_id : ' || pn_source_pr_header_id); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (fnd_file.LOG,
                           'pn_dest_org_id : ' || pn_dest_org_id); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (fnd_file.LOG,
                           'pv_action_type : ' || pv_action_type); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (fnd_file.LOG,
                           'pv_intercompany_flag : ' || pv_intercompany_flag); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
        fnd_file.put_line (
            fnd_file.LOG,
            'move_org_operating_unit_flag : ' || move_org_operating_unit_flag); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022

        IF    (NVL (pv_intercompany_flag, 'N') = 'Y')
           OR (NVL (move_org_operating_unit_flag, 'N') = 'Y')
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Inside pv_intercompany_flag = Y OR move_org_operating_unit_flag = Y'); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022

            po_line_det    := xxdo.xxd_po_line_det_type (NULL);
            SAVEPOINT xxd_transaction;
            lv_error_msg   := NULL;

            FOR stg_lines_rec IN stg_lines_rec_cur
            LOOP
                IF stg_lines_rec.po_cancelled_flag = 'N'
                THEN
                    IF stg_lines_rec.source_po_line_id = 1
                    THEN
                        ln_po_line_id   := NULL;
                    ELSE
                        ln_po_line_id   := stg_lines_rec.source_po_line_id;
                    END IF;

                    --Start changes for CCR0010003
                    BEGIN
                        SELECT pha.segment1, pha.vendor_id, pha.vendor_site_id,
                               TRIM (pla.attribute7)
                          INTO ln_source_po_num, ln_source_vendor_id, ln_source_vendor_site_id, ln_vendor_site_code_dff
                          FROM po_headers_all pha, po_lines_all pla
                         WHERE     1 = 1
                               AND pla.po_header_id = pha.po_header_id
                               AND pha.po_header_id = pn_po_header_id
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                lv_error_message || ' ' || SQLERRM;
                            pv_error_message   := lv_exp_error;
                    END;

                    --Get Intransit days from lookup for change supplier\site
                    BEGIN
                        ln_calc_transit_days   :=
                            xxd_po_pomodify_utils_pkg.get_pol_transit_days (
                                ln_source_po_num,            --ln_move_po_num,
                                pv_action_type,
                                ln_source_vendor_id,           --ln_vendor_id,
                                ln_source_vendor_site_id,  --ln_vendor_site_id
                                ln_vendor_site_code_dff);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_calc_transit_days   := 0;
                    END;

                    BEGIN -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
                        SELECT pha.attribute10                      -- PO Type
                          INTO lv_po_type
                          FROM po_headers_all pha
                         WHERE pha.segment1 = ln_source_po_num;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error while getting PO Type. '); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
                    END;

                    IF ln_calc_transit_days < 0 AND lv_po_type <> 'INTL_DIST'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Transit days not defined for the Supplier in Lookup. ');

                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Transit days not defined for the Supplier in Lookup. '
                                || ln_po_line_id
                                || lv_error_message,
                                1,
                                2000);

                        fnd_file.put_line (fnd_file.LOG,
                                           'lv_error_msg: ' || lv_error_msg); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
                    END IF;


                    IF ln_error_count > 0
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET po_cancelled_flag = 'E', pr_cancelled_flag = 'E', --DECODE (pr_cancelled_flag, 'N', 'E', ''),
                                                                                     --iso_cancelled_flag = 'E',
                                                                                     --ir_cancelled_flag = 'E', --DECODE (ir_cancelled_flag, 'N', 'E', ''),
                                                                                     status = 'E',
                                   error_message = lv_error_msg, last_updated_date = SYSDATE, last_updated_by = pn_user_id
                             WHERE     status = 'N'
                                   AND source_po_header_id =
                                       stg_lines_rec.source_po_header_id --pn_source_pr_header_id
                                   AND batch_id = pn_batch_id;

                            --COMMIT;
                            CONTINUE;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ROLLBACK TO SAVEPOINT xxd_transaction;
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;

                        ROLLBACK TO SAVEPOINT xxd_transaction;

                        RETURN;

                        pv_error_message   :=
                               'Transit days not defined for the Supplier in Lookup. '
                            || pv_error_message;
                        RETURN;
                    END IF;

                    xxd_po_pomodify_utils_pkg.cancel_po_line (
                        pn_user_id,
                        stg_lines_rec.source_po_header_id,
                        ln_po_line_id,
                        'Y',                              --cancel_requisition
                        lv_status_flag,
                        lv_error_message);

                    IF lv_status_flag = 'S'
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET po_cancelled_flag = 'Y', pr_cancelled_flag = DECODE (pr_cancelled_flag, 'N', 'Y', ''), last_updated_date = SYSDATE,
                                   last_updated_by = pn_user_id
                             WHERE     batch_id = pn_batch_id
                                   AND status = 'N'
                                   AND source_po_header_id =
                                       stg_lines_rec.source_po_header_id
                                   AND source_po_line_id =
                                       NVL (ln_po_line_id, source_po_line_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table1:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    ELSE
                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Error while cancelling po_line_id:'
                                || stg_lines_rec.source_po_line_id
                                || lv_error_message,
                                1,
                                2000);
                    END IF;
                END IF;
            END LOOP;

            IF ln_error_count > 0
            THEN
                ROLLBACK TO SAVEPOINT xxd_transaction;

                BEGIN
                    UPDATE xxd_po_modify_details_t
                       SET po_cancelled_flag = 'E', pr_cancelled_flag = DECODE (pr_cancelled_flag, 'N', 'E', ''), iso_cancelled_flag = 'E',
                           ir_cancelled_flag = DECODE (ir_cancelled_flag, 'N', 'E', ''), status = 'E', error_message = lv_error_msg,
                           last_updated_date = SYSDATE, last_updated_by = pn_user_id
                     WHERE     status = 'N'
                           AND source_po_header_id = pn_po_header_id
                           AND batch_id = pn_batch_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_exp_error       :=
                            'Error while updating staging table2:' || SQLERRM;
                        pv_error_message   := lv_exp_error;
                        RETURN;
                END;

                pv_error_message   :=
                       'Could not cancel Purcahse Order lines or Sales Order Lines '
                    || lv_error_message;
                RETURN;
            ELSE
                FOR stg_iso_rec IN stg_iso_rec_cur (gn_po_type)     -- ver 2.0
                LOOP
                    IF stg_iso_rec.source_iso_line_id = 1
                    THEN
                        ln_iso_line_id   := NULL;
                    ELSE
                        ln_iso_line_id   := stg_iso_rec.source_iso_line_id;
                    END IF;

                    xxd_po_pomodify_utils_pkg.cancel_so_line (
                        pn_user_id,
                        stg_iso_rec.source_iso_header_id,
                        ln_iso_line_id,
                        lv_status_flag,
                        lv_error_message);

                    IF lv_status_flag = 'S'
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET iso_cancelled_flag = 'Y', ir_cancelled_flag = DECODE (ir_cancelled_flag, 'N', 'Y', ''), last_updated_date = SYSDATE,
                                   last_updated_by = pn_user_id
                             WHERE     batch_id = pn_batch_id
                                   AND status = 'N'
                                   AND source_iso_header_id =
                                       stg_iso_rec.source_iso_header_id
                                   AND source_iso_line_id =
                                       NVL (ln_iso_line_id,
                                            source_iso_line_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table3:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    ELSE
                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Error while cancelling so_line_id:'
                                || ln_iso_line_id
                                || lv_error_message,
                                1,
                                2000);
                    END IF;
                END LOOP;
            END IF;

            IF ln_error_count > 0
            THEN
                ROLLBACK TO SAVEPOINT xxd_transaction;

                BEGIN
                    UPDATE xxd_po_modify_details_t
                       SET po_cancelled_flag = 'E', pr_cancelled_flag = DECODE (pr_cancelled_flag, 'N', 'E', ''), iso_cancelled_flag = 'E',
                           ir_cancelled_flag = DECODE (ir_cancelled_flag, 'N', 'E', ''), status = 'E', error_message = lv_error_msg,
                           last_updated_date = SYSDATE, last_updated_by = pn_user_id
                     WHERE     status = 'N'
                           AND source_po_header_id = pn_po_header_id
                           AND batch_id = pn_batch_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_exp_error       :=
                            'Error while updating staging table4:' || SQLERRM;
                        pv_error_message   := lv_exp_error;
                        RETURN;
                END;

                pv_error_message   :=
                       'Could not cancel Purcahse Order lines or Sales Order Lines '
                    || lv_error_message;
                RETURN;
            ELSE
                COMMIT;

                --commiting PO,PR,ISO,IR cancellation
                FOR stg_lines IN stg_lines_cur
                LOOP
                    po_line_det.EXTEND;
                    po_line_det (po_line_det.COUNT)   :=
                        xxdo.xxd_po_line_det_tab (
                            stg_lines.source_po_line_id,
                            stg_lines.source_pr_line_id,
                            NULL);
                END LOOP;

                --create pr
                BEGIN
                    SELECT pha.vendor_id, apsa.vendor_site_code
                      INTO ln_vendor_id, ln_vendor_site_code
                      FROM po_headers_all pha, ap_supplier_sites_all apsa
                     WHERE     pha.vendor_site_id = apsa.vendor_site_id
                           AND pha.po_header_id = pn_po_header_id
                           AND apsa.org_id = pha.org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_vendor_id       := NULL;
                        lv_exp_error       :=
                            'Error while Getting Vendor IDs:' || SQLERRM;
                        pv_error_message   := lv_exp_error;
                        RETURN;
                END;

                BEGIN
                    SELECT vendor_site_id
                      INTO ln_vendor_site_id
                      FROM ap_supplier_sites_all
                     WHERE     vendor_id = ln_vendor_id
                           AND org_id =
                               (SELECT operating_unit
                                  FROM org_organization_definitions
                                 WHERE organization_id = pn_dest_org_id)
                           AND (inactive_date IS NULL OR TRUNC (inactive_date) >= TRUNC (SYSDATE))
                           AND vendor_site_code = ln_vendor_site_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_vendor_site_id   := NULL;
                        lv_exp_error        :=
                            'Error while Getting Vendor Site6:' || SQLERRM;
                        pv_error_message    := lv_exp_error;
                        RETURN;
                END;

                xxd_po_pomodify_utils_pkg.create_purchase_req (
                    pn_user_id,
                    pn_po_header_id,
                    po_line_det,
                    pn_dest_org_id,
                    --new_dest_org_id
                    ln_vendor_id,
                    ln_vendor_site_id,
                    lv_req_number,
                    ln_req_import_id,
                    lv_error_flag,
                    lv_error_message);

                BEGIN
                    SELECT requisition_header_id
                      INTO ln_req_header_id
                      FROM po_requisition_headers_all
                     WHERE segment1 = lv_req_number;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_req_header_id   := NULL;
                END;

                IF ln_req_header_id IS NULL
                THEN
                    BEGIN
                        UPDATE xxd_po_modify_details_t stg
                           SET status              = 'E',
                               error_message      =
                                   SUBSTR (
                                       (NVL (
                                            (SELECT 'Purchase Requisition interface error: ' || pe.error_message
                                               FROM po_interface_errors pe, po_requisitions_interface_all pri
                                              WHERE     pri.request_id =
                                                        ln_req_import_id
                                                    AND pri.transaction_id =
                                                        pe.interface_transaction_id
                                                    AND pri.line_attribute1 =
                                                        stg.source_po_line_id
                                                    AND pri.line_attribute2 =
                                                        stg.source_pr_line_id
                                                    AND ROWNUM = 1),
                                            'Error While Creating Purchase Requisition')),
                                       1,
                                       2000),
                               last_updated_date   = SYSDATE,
                               last_updated_by     = pn_user_id
                         WHERE     source_po_header_id = pn_po_header_id
                               AND action_type = pv_action_type
                               AND batch_id = pn_batch_id
                               AND status = 'N';

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                   'Error while updating staging table8:'
                                || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;

                    pv_error_message   :=
                        'Error While Creating Requistion ' || SQLERRM;
                    RETURN;
                ELSE
                    --Updating stgaing table with new requistion
                    BEGIN
                        UPDATE xxd_po_modify_details_t stg
                           SET new_pr_number       = lv_req_number,
                               new_pr_header_id    = ln_req_header_id,
                               (new_pr_line_num, new_pr_line_id)   =
                                   (SELECT prla.line_num, prla.requisition_line_id
                                      FROM po_requisition_headers_all prha, po_requisition_lines_all prla
                                     WHERE     prha.requisition_header_id =
                                               prla.requisition_header_id
                                           AND prha.segment1 = lv_req_number
                                           AND prla.attribute1 =
                                               stg.source_po_line_id
                                           AND prla.attribute2 =
                                               stg.source_pr_line_id),
                               last_updated_date   = SYSDATE,
                               last_updated_by     = pn_user_id
                         WHERE     source_po_header_id = pn_po_header_id
                               AND action_type = pv_action_type
                               AND batch_id = pn_batch_id
                               AND status = 'N';

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                   'Error while updating staging table9:'
                                || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;

                    xxd_po_pomodify_utils_pkg.create_po (pn_user_id, pn_po_header_id, ln_vendor_id, ln_vendor_site_id, po_line_det, ln_req_header_id, pn_dest_org_id, pv_intercompany_flag, -- Ver 3.0
                                                                                                                                                                                            pv_action_type, lv_new_po_num, ln_po_int_batch_id, lv_error_flag
                                                         , lv_error_message);

                    IF lv_new_po_num IS NOT NULL
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t stg
                               SET new_po_number       = lv_new_po_num,
                                   (new_po_header_id,
                                    new_po_line_num,
                                    new_po_line_id)   =
                                       (SELECT pla.po_header_id, pla.line_num, pla.po_line_id
                                          FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_req_distributions_all prd,
                                               po_distributions_all pda, po_lines_all pla
                                         WHERE     prha.requisition_header_id =
                                                   prla.requisition_header_id
                                               AND prha.segment1 =
                                                   lv_req_number
                                               AND prd.requisition_line_id =
                                                   prla.requisition_line_id
                                               AND pda.req_distribution_id =
                                                   prd.distribution_id
                                               AND pda.po_line_id =
                                                   pla.po_line_id
                                               AND prla.line_num =
                                                   stg.new_pr_line_num),
                                   last_updated_date   = SYSDATE,
                                   last_updated_by     = pn_user_id
                             WHERE     source_po_header_id = pn_po_header_id
                                   AND action_type = pv_action_type
                                   AND batch_id = pn_batch_id
                                   AND status = 'N';

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;

                        --Start changes for CCR0010003

                        IF     ln_vendor_id IS NOT NULL
                           AND ln_vendor_site_id IS NOT NULL
                        THEN
                            --Calling procedure to update calculated New Promise\Need by Dates
                            BEGIN
                                xxd_po_pomodify_utils_pkg.update_calc_need_by_date (
                                    pn_user_id,
                                    lv_new_po_num, --ln_move_po_num, --ln_source_po_num, --,
                                    ln_calc_transit_days,
                                    ln_vendor_id,
                                    ln_vendor_site_id,
                                    NULL,
                                    ln_req_header_id, --pn_source_pr_header_id,
                                    pv_action_type, -- 'Move Org',     -- Added by Gowrishankar for CCR0010003 on 14-Sep-2022
                                    lv_error_flag,
                                    lv_error_message);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_exp_error       :=
                                           'Error in caling xxd_po_pomodify_utils_pkg.update_calc_need_by_date:'
                                        || SQLCODE
                                        || ' - '
                                        || SQLERRM;
                                    pv_error_message   := lv_exp_error;
                                    RETURN;
                            END;
                        ELSE
                            --End Added for CCR0010003
                            --Calling below procedure for change 1.1
                            --Calling procedure to update po need_by_date when there is mismatach between PR ans PO
                            BEGIN
                                xxd_po_pomodify_utils_pkg.update_po_need_by_date (
                                    pn_user_id,
                                    lv_new_po_num,           --ln_move_po_num,
                                    lv_error_flag,
                                    lv_error_message);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_exp_error       :=
                                           'Error in caling xxd_po_pomodify_utils_pkg.update_po_need_by_date:'
                                        || SQLCODE
                                        || ' - '
                                        || SQLERRM;
                                    pv_error_message   := lv_exp_error;
                                    RETURN;
                            END;
                        END IF;                         --Added for CCR0010003

                        COMMIT;         -- Added for CCR0010003 on 23-Aug-2022

                        IF lv_error_message IS NOT NULL
                        THEN
                            BEGIN
                                UPDATE xxd_po_modify_details_t stg
                                   SET status = 'E', error_message = 'Promise\Needby Date Calc failure'
                                 WHERE     source_po_header_id =
                                           pn_po_header_id
                                       AND action_type = pv_action_type
                                       AND batch_id = pn_batch_id;

                                --AND status = 'N';
                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_exp_error       :=
                                           'Error while updating staging table:'
                                        || SQLERRM;
                                    pv_error_message   := lv_exp_error;
                                    RETURN;
                            END;
                        END IF;
                    ELSE
                        BEGIN
                            UPDATE xxd_po_modify_details_t stg
                               SET status              = 'E',
                                   error_message      =
                                       SUBSTR (
                                           (NVL (
                                                (SELECT 'Purchase order interface error: ' || pe.error_message
                                                   FROM po_interface_errors pe, po_headers_interface phi, po_lines_interface pli
                                                  WHERE     phi.batch_id =
                                                            ln_po_int_batch_id
                                                        AND phi.interface_header_id =
                                                            pli.interface_header_id
                                                        AND phi.interface_header_id =
                                                            pe.interface_header_id
                                                        AND pli.interface_line_id =
                                                            NVL (
                                                                pe.interface_line_id,
                                                                pli.interface_line_id)
                                                        AND pli.requisition_line_id =
                                                            stg.new_pr_line_id
                                                        AND ROWNUM = 1),
                                                'Error While Creating Purchase Order')),
                                           1,
                                           2000),
                                   last_updated_date   = SYSDATE,
                                   last_updated_by     = pn_user_id
                             WHERE     source_po_header_id = pn_po_header_id
                                   AND action_type = pv_action_type
                                   AND batch_id = pn_batch_id
                                   AND status = 'N';

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table11:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    END IF;
                END IF;
            END IF;

            BEGIN
                UPDATE xxd_po_modify_details_t stg
                   SET status = 'S', last_updated_date = SYSDATE, last_updated_by = pn_user_id
                 WHERE     batch_id = pn_batch_id
                       AND source_po_header_id = pn_po_header_id
                       AND action_type = pv_action_type
                       AND status = 'N'
                       AND new_po_number IS NOT NULL
                       AND new_po_line_num IS NOT NULL;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exp_error       :=
                        'Error while updating staging table12:' || SQLERRM;
                    pv_error_message   := lv_exp_error;
                    RETURN;
            END;

            BEGIN
                UPDATE xxd_po_modify_details_t stg
                   SET status = 'E', error_message = NVL (lv_error_message, 'Error while cancelling po lines and creating new po'), last_updated_date = SYSDATE,
                       last_updated_by = pn_user_id
                 WHERE     batch_id = pn_batch_id
                       AND source_po_header_id = pn_po_header_id
                       AND action_type = pv_action_type
                       AND status = 'N'
                       AND (new_po_number IS NULL OR new_po_line_num IS NULL);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exp_error       :=
                        'Error while updating staging table:' || SQLERRM;
                    pv_error_message   := lv_exp_error;
                    RETURN;
            END;
        END IF;

        IF     (NVL (pv_intercompany_flag, 'N') = 'N')
           AND ((NVL (move_org_operating_unit_flag, 'N') = 'N'))
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Inside pv_intercompany_flag = N AND move_org_operating_unit_flag = N '); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022

            po_line_det      := xxdo.xxd_po_line_det_type (NULL);
            ln_error_count   := 0;
            SAVEPOINT xxd_transaction;
            lv_error_msg     := NULL;

            FOR stg_lines_rec IN stg_lines_rec_cur
            LOOP
                IF stg_lines_rec.po_cancelled_flag = 'N'
                THEN
                    IF stg_lines_rec.source_po_line_id = 1
                    THEN
                        ln_po_line_id   := NULL;
                    ELSE
                        ln_po_line_id   := stg_lines_rec.source_po_line_id;
                    END IF;

                    --Start changes for CCR0010003

                    BEGIN
                        SELECT pha.segment1, pha.vendor_id, pha.vendor_site_id,
                               TRIM (pla.attribute7)
                          INTO ln_source_po_num, ln_source_vendor_id, ln_source_vendor_site_id, ln_vendor_site_code_dff
                          FROM po_headers_all pha, po_lines_all pla
                         WHERE     1 = 1
                               AND pla.po_header_id = pha.po_header_id
                               AND pha.po_header_id = pn_po_header_id
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                lv_error_message || ' ' || SQLERRM;
                            pv_error_message   := lv_exp_error;
                    END;

                    --IF ln_vendor_id IS NOT NULL AND ln_vendor_site_id IS NOT NULL
                    --THEN
                    --Get Intransit days from lookup for change supplier\site
                    BEGIN
                        ln_calc_transit_days   :=
                            xxd_po_pomodify_utils_pkg.get_pol_transit_days (
                                ln_source_po_num,            --ln_move_po_num,
                                pv_action_type,
                                ln_source_vendor_id,           --ln_vendor_id,
                                ln_source_vendor_site_id, --ln_vendor_site_id,
                                ln_vendor_site_code_dff);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_calc_transit_days   := 0;
                    END;

                    BEGIN
                        SELECT pha.attribute10                      -- PO Type
                          INTO lv_po_type
                          FROM po_headers_all pha
                         WHERE pha.segment1 = ln_move_po_num;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error while getting PO Type. '); -- Added by Gowrishankar for CCR0010003 on 09-Sep-2022
                    END;

                    IF ln_calc_transit_days < 0 AND lv_po_type <> 'INTL_DIST'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Transit days not defined for the Supplier in Lookup. ');

                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Transit days not defined for the Supplier in Lookup. '
                                || ln_po_line_id
                                || lv_error_message,
                                1,
                                2000);
                    END IF;


                    IF ln_error_count > 0
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET po_cancelled_flag = 'E', pr_cancelled_flag = 'E', --DECODE (pr_cancelled_flag, 'N', 'E', ''),
                                                                                     --iso_cancelled_flag = 'E',
                                                                                     --ir_cancelled_flag = 'E', --DECODE (ir_cancelled_flag, 'N', 'E', ''),
                                                                                     status = 'E',
                                   error_message = lv_error_msg, last_updated_date = SYSDATE, last_updated_by = pn_user_id
                             WHERE     status = 'N'
                                   AND source_po_header_id =
                                       stg_lines_rec.source_po_header_id --pn_source_pr_header_id
                                   AND batch_id = pn_batch_id;

                            --COMMIT;
                            CONTINUE;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ROLLBACK TO SAVEPOINT xxd_transaction;
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;

                        ROLLBACK TO SAVEPOINT xxd_transaction;

                        RETURN;

                        pv_error_message   :=
                               'Transit days not defined for the Supplier in Lookup. '
                            || pv_error_message;
                        RETURN;
                    END IF;

                    xxd_po_pomodify_utils_pkg.cancel_po_line (
                        pn_user_id,
                        stg_lines_rec.source_po_header_id,
                        ln_po_line_id,
                        'N',                              --cancel_requisition
                        lv_status_flag,
                        lv_error_message);

                    IF lv_status_flag = 'S'
                    THEN
                        BEGIN
                            UPDATE xxd_po_modify_details_t
                               SET po_cancelled_flag = 'Y', pr_cancelled_flag = 'N', last_updated_date = SYSDATE,
                                   last_updated_by = pn_user_id
                             WHERE     batch_id = pn_batch_id
                                   AND status = 'N'
                                   AND source_po_header_id =
                                       stg_lines_rec.source_po_header_id
                                   AND source_po_line_id =
                                       NVL (ln_po_line_id, source_po_line_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exp_error       :=
                                       'Error while updating staging table:'
                                    || SQLERRM;
                                pv_error_message   := lv_exp_error;
                                RETURN;
                        END;
                    ELSE
                        ln_error_count   := ln_error_count + 1;
                        lv_error_msg     :=
                            SUBSTR (
                                   lv_error_msg
                                || ' '
                                || 'Error while cancelling po_line_id:'
                                || ln_po_line_id
                                || lv_error_message,
                                1,
                                2000);
                    END IF;
                END IF;
            END LOOP;

            IF ln_error_count > 0
            THEN
                ROLLBACK TO SAVEPOINT xxd_transaction;

                BEGIN
                    UPDATE xxd_po_modify_details_t
                       SET po_cancelled_flag = 'E', pr_cancelled_flag = DECODE (pr_cancelled_flag, 'N', 'E', ''), iso_cancelled_flag = 'E',
                           ir_cancelled_flag = DECODE (ir_cancelled_flag, 'N', 'E', ''), status = 'E', error_message = lv_error_msg,
                           last_updated_date = SYSDATE, last_updated_by = pn_user_id
                     WHERE     status = 'N'
                           AND source_po_header_id = pn_po_header_id
                           AND batch_id = pn_batch_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_exp_error       :=
                            'Error while updating staging table:' || SQLERRM;
                        pv_error_message   := lv_exp_error;
                        RETURN;
                END;

                pv_error_message   :=
                       'Could not cancel Purcahse Order lines or Sales Order Lines '
                    || lv_error_message;
                RETURN;
            ELSE
                COMMIT;

                --commiting PO,PR,ISO,IR cancellation
                FOR stg_lines IN stg_lines_cur
                LOOP
                    po_line_det.EXTEND;
                    po_line_det (po_line_det.COUNT)   :=
                        xxdo.xxd_po_line_det_tab (
                            stg_lines.source_po_line_id,
                            stg_lines.source_pr_line_id,
                            NULL);
                    xxd_po_pomodify_utils_pkg.update_po_req_link (
                        stg_lines.source_po_line_id,
                        lv_status_flag,
                        lv_error_message);
                END LOOP;

                xxd_po_pomodify_utils_pkg.update_po_requisition_line (
                    pn_user_id,
                    pn_source_pr_header_id,
                    '',                                        --pn_vendor_id,
                    '',
                    --pn_vendor_site_id,
                    pn_dest_org_id,
                    po_line_det,
                    'Y',
                    --req_auto_approval
                    lv_error_flag,
                    lv_error_message);

                IF    lv_error_message IS NOT NULL
                   OR NVL (lv_error_flag, 'S') = 'E'
                THEN
                    BEGIN
                        UPDATE xxd_po_modify_details_t stg
                           SET status = 'E', error_message = 'Error while updating requisition02 ' || lv_error_message
                         WHERE     source_po_header_id = pn_po_header_id
                               AND action_type = pv_action_type
                               AND batch_id = pn_batch_id
                               AND status = 'N';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_exp_error       :=
                                   'Error while updating staging table:'
                                || SQLERRM;
                            pv_error_message   := lv_exp_error;
                            RETURN;
                    END;

                    COMMIT;
                ELSE
                    xxd_po_pomodify_utils_pkg.approve_requisition (
                        pn_source_pr_header_id,
                        lv_error_flag,
                        lv_error_message);

                    IF lv_error_message IS NULL
                    THEN
                        xxd_po_pomodify_utils_pkg.create_po (
                            pn_user_id,
                            pn_po_header_id,
                            '',                                --pn_vendor_id,
                            '',                           --pn_vendor_site_id,
                            po_line_det,
                            '',                            --new_req_header_id
                            pn_dest_org_id,                      --move_org_id
                            pv_intercompany_flag,                   -- Ver 3.0
                            pv_action_type,
                            lv_new_po_num,
                            ln_po_int_batch_id,
                            lv_error_flag,
                            lv_error_message);

                        IF lv_new_po_num IS NOT NULL
                        THEN
                            BEGIN
                                UPDATE xxd_po_modify_details_t stg
                                   SET new_po_number       = lv_new_po_num,
                                       (new_po_header_id,
                                        new_po_line_num,
                                        new_po_line_id)   =
                                           (SELECT pla.po_header_id, pla.line_num, pla.po_line_id
                                              FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_req_distributions_all prd,
                                                   po_distributions_all pda, po_lines_all pla
                                             WHERE     prha.requisition_header_id =
                                                       pn_source_pr_header_id
                                                   AND prha.requisition_header_id =
                                                       prla.requisition_header_id
                                                   AND prd.requisition_line_id =
                                                       prla.requisition_line_id
                                                   AND pda.req_distribution_id =
                                                       prd.distribution_id
                                                   AND pda.po_line_id =
                                                       pla.po_line_id
                                                   AND prla.requisition_line_id =
                                                       stg.source_pr_line_id),
                                       last_updated_date   = SYSDATE,
                                       last_updated_by     = pn_user_id
                                 WHERE     source_po_header_id =
                                           pn_po_header_id
                                       AND action_type = pv_action_type
                                       AND batch_id = pn_batch_id
                                       AND status = 'N';

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_exp_error       :=
                                           'Error while updating staging table:'
                                        || SQLERRM;
                                    pv_error_message   := lv_exp_error;
                                    RETURN;
                            END;

                            --Start changes for CCR0010003

                            --IF ln_vendor_id IS NOT NULL AND ln_vendor_site_id IS NOT NULL
                            IF     ln_source_vendor_id IS NOT NULL
                               AND ln_source_vendor_site_id IS NOT NULL
                            THEN
                                --Calling procedure to update calculated New Promise\Need by Dates
                                BEGIN
                                    xxd_po_pomodify_utils_pkg.update_calc_need_by_date (
                                        pn_user_id,
                                        lv_new_po_num,       --ln_move_po_num,
                                        ln_calc_transit_days,
                                        ln_source_vendor_id,   --ln_vendor_id,
                                        ln_source_vendor_site_id, --ln_vendor_site_id,
                                        NULL,
                                        NVL (ln_req_header_id,
                                             pn_source_pr_header_id), -- pn_source_pr_header_id, --
                                        pv_action_type, --'Move Org',   -- Added by Gowrishankar for CCR0010003 on 14-Sep-2022
                                        lv_error_flag,
                                        lv_error_message);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_exp_error       :=
                                               'Error in caling xxd_po_pomodify_utils_pkg.update_calc_need_by_date: '
                                            || SQLERRM;
                                        pv_error_message   := lv_exp_error;
                                        RETURN;
                                END;
                            ELSE
                                --End Added for CCR0010003
                                --Calling below procedure for change 1.1
                                --Calling procedure to update po need_by_date when there is mismatach between PR ans PO
                                BEGIN
                                    xxd_po_pomodify_utils_pkg.update_po_need_by_date (
                                        pn_user_id,
                                        lv_new_po_num,       --ln_move_po_num,
                                        lv_error_flag,
                                        lv_error_message);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_exp_error       :=
                                               'Error in caling xxd_po_pomodify_utils_pkg.update_po_need_by_date: '
                                            || SQLERRM;
                                        pv_error_message   := lv_exp_error;
                                        RETURN;
                                END;
                            END IF;                     --Added for CCR0010003

                            COMMIT;     -- Added for CCR0010003 on 23-Aug-2022
                        ELSE
                            BEGIN
                                UPDATE xxd_po_modify_details_t stg
                                   SET status              = 'E',
                                       error_message      =
                                           SUBSTR (
                                               (NVL (
                                                    (SELECT 'Purchase order interface error: ' || pe.error_message
                                                       FROM po_interface_errors pe, po_headers_interface phi, po_lines_interface pli
                                                      WHERE     phi.batch_id =
                                                                ln_po_int_batch_id
                                                            AND phi.interface_header_id =
                                                                pli.interface_header_id
                                                            AND phi.interface_header_id =
                                                                pe.interface_header_id
                                                            AND pli.interface_line_id =
                                                                NVL (
                                                                    pe.interface_line_id,
                                                                    pli.interface_line_id)
                                                            AND pli.requisition_line_id =
                                                                stg.source_pr_line_id
                                                            AND ROWNUM = 1),
                                                    'Error While Creating Purchase Order')),
                                               1,
                                               2000),
                                       last_updated_date   = SYSDATE,
                                       last_updated_by     = pn_user_id
                                 WHERE     source_po_header_id =
                                           pn_po_header_id
                                       AND action_type = pv_action_type
                                       AND batch_id = pn_batch_id
                                       AND status = 'N';

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_exp_error       :=
                                           'Error while updating staging table:'
                                        || SQLERRM;
                                    pv_error_message   := lv_exp_error;
                                    RETURN;
                            END;
                        END IF;
                    ELSE
                        UPDATE xxd_po_modify_details_t stg
                           SET status = 'E', error_message = 'Error while approving purchase requisition: ' || lv_error_msg, last_updated_date = SYSDATE,
                               last_updated_by = pn_user_id
                         WHERE     source_po_header_id = pn_po_header_id
                               AND action_type = pv_action_type
                               AND batch_id = pn_batch_id
                               AND status = 'N';
                    END IF;
                END IF;
            END IF;

            BEGIN
                UPDATE xxd_po_modify_details_t stg
                   SET status = 'S', last_updated_date = SYSDATE, last_updated_by = pn_user_id
                 WHERE     batch_id = pn_batch_id
                       AND source_po_header_id = pn_po_header_id
                       AND action_type = pv_action_type
                       AND status = 'N'
                       AND new_po_number IS NOT NULL
                       AND new_po_line_num IS NOT NULL;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exp_error       :=
                        'Error while updating staging table:' || SQLERRM;
                    pv_error_message   := lv_exp_error;
                    RETURN;
            END;

            BEGIN
                UPDATE xxd_po_modify_details_t stg
                   SET status = 'E', error_message = NVL (lv_error_message, 'Error while cancelling po lines and creating new po'), last_updated_date = SYSDATE,
                       last_updated_by = pn_user_id
                 WHERE     batch_id = pn_batch_id
                       AND source_po_header_id = pn_po_header_id
                       AND action_type = pv_action_type
                       AND status = 'N'
                       AND (new_po_number IS NULL OR new_po_line_num IS NULL);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_exp_error       :=
                        'Error while updating staging table:' || SQLERRM;
                    pv_error_message   := lv_exp_error;
                    RETURN;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_exp_error       :=
                'Error in move_org_action procedure ' || SQLERRM;
            pv_error_message   := lv_exp_error;
            RETURN;
    END move_org_action;

    PROCEDURE submit_process_trans_prog (pn_user_id         IN     NUMBER,
                                         pn_resp_id         IN     NUMBER,
                                         pn_batch_id        IN     NUMBER,
                                         pn_request_id      IN     NUMBER, -- VER 3.0
                                         pv_error_message      OUT VARCHAR2)
    IS
        ln_request_id       NUMBER;
        lv_exp_error        VARCHAR2 (4000);
        ln_application_id   NUMBER;
    BEGIN
        SELECT application_id
          INTO ln_application_id
          FROM apps.fnd_responsibility_vl
         WHERE responsibility_id = pn_resp_id;

        apps.fnd_global.apps_initialize (pn_user_id,
                                         pn_resp_id,
                                         ln_application_id);
        ln_request_id   :=
            apps.fnd_request.submit_request (application => 'XXDO', program => 'XXD_PO_MODIFY_PRG', argument1 => pn_batch_id
                                             , argument2 => pn_request_id -- ver 3.0
                                                                         );

        -- ver 3.0
        UPDATE xxd_po_modify_details_t stg
           SET request_id   = ln_request_id
         WHERE batch_id = pn_batch_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_exp_error       :=
                'Error in move_org_action procedure ' || SQLERRM;
            pv_error_message   := lv_exp_error;
            RETURN;
    END;

    /* Added below pacakge for change 1.1*/
    --Main Procedure called by OAF to modify PR
    PROCEDURE upload_pr_proc (p_user_id IN NUMBER, p_resp_id IN NUMBER, p_action IN VARCHAR2, p_seq_number IN NUMBER, p_header_id IN NUMBER, p_new_vendor_id IN NUMBER, p_new_vendor_site_id IN NUMBER, p_org_id IN NUMBER, p_line_record IN xxd_po_util_pr_upd_obj_typ
                              , p_err_msg OUT VARCHAR2)
    IS
        CURSOR pr_details_cur IS
            SELECT prl.requisition_header_id, itm.style_number || '-' || itm.color_code style_color, prl.vendor_id,
                   prl.vendor_site_id, prl.requisition_line_id
              FROM po_requisition_lines_all prl, xxd_common_items_v itm, TABLE (p_line_record) pr_det
             WHERE     prl.requisition_header_id = p_header_id
                   AND itm.inventory_item_id = prl.item_id
                   AND itm.organization_id = prl.destination_organization_id
                   AND itm.style_number = pr_det.style
                   AND itm.color_code = pr_det.color
                   AND TRUNC (prl.need_by_date) =
                       TO_DATE (pr_det.needby_date, 'DD/MM/YYYY')
                   AND prl.org_id = p_org_id
                   AND NVL (prl.cancel_flag, 'N') = 'N'
                   AND NVL (prl.vendor_id, -999) = pr_det.vendor_id
                   AND NVL (prl.vendor_site_id, -998) = pr_det.vendor_site_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM po_distributions_all pda, po_req_distributions_all prda
                             WHERE     1 = 1
                                   AND pda.req_distribution_id =
                                       prda.distribution_id
                                   AND prda.requisition_line_id =
                                       prl.requisition_line_id);

        ld_creation_date       DATE := SYSDATE;
        ln_count               NUMBER := 0;
        ln_internal_pr_count   NUMBER := 0;
        lv_error_message       VARCHAR2 (4000);
    BEGIN
        FOR pr_details_rec IN pr_details_cur
        LOOP
            ln_count   := ln_count + 1;

            BEGIN
                INSERT INTO xxd_po_pr_modify_details_t (record_id, batch_id, org_id, source_pr_header_id, source_pr_line_id, style_color, action_type, supplier_id, supplier_site_id, new_supplier_id, new_supplier_site_id, pr_modify_source, request_id, status, error_message, creation_date, created_by, last_updated_date
                                                        , last_updated_by)
                     VALUES (xxd_po_pr_modify_details_s.NEXTVAL, p_seq_number, p_org_id, pr_details_rec.requisition_header_id, pr_details_rec.requisition_line_id, pr_details_rec.style_color, p_action, pr_details_rec.vendor_id, pr_details_rec.vendor_site_id, p_new_vendor_id, p_new_vendor_site_id, 'OAF', -1, 'N', '', ld_creation_date, p_user_id, ld_creation_date
                             , p_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                           'Errror while Inserting Data Into Staging Table: '
                        || SQLERRM;
                    p_err_msg   := lv_error_message;
                    RETURN;
            END;
        END LOOP;

        COMMIT;

        IF ln_count = 0
        THEN
            p_err_msg   := 'No Eligible Lines For Given Details To Process';
        ELSIF ln_count > 0 AND lv_error_message IS NULL
        THEN
            BEGIN
                SELECT COUNT (*)
                  INTO ln_internal_pr_count
                  FROM xxd_po_pr_modify_details_t stg
                 WHERE     stg.batch_id = p_seq_number
                       AND EXISTS
                               (SELECT 1
                                  FROM po_requisition_lines_all prl
                                 WHERE     prl.requisition_line_id =
                                           stg.source_pr_line_id
                                       AND prl.requisition_header_id =
                                           stg.source_pr_header_id
                                       AND NVL (prl.transferred_to_oe_flag,
                                                'N') =
                                           'Y');
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                           'Errror while Validation Staging Table Data: '
                        || SQLERRM;
                    p_err_msg   := lv_error_message;
                    RETURN;
            END;

            IF ln_internal_pr_count > 0
            THEN
                BEGIN
                    UPDATE xxd_po_pr_modify_details_t stg
                       SET status = 'E', error_message = 'One Or More Requisition Lines is placed onto Sales Order..Line cannot be updated'
                     WHERE batch_id = p_seq_number;

                    COMMIT;
                    p_err_msg   := 'Success';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                               'Errror while updating staging table with validation errors: '
                            || SQLERRM;
                        p_err_msg   := lv_error_message;
                        RETURN;
                END;
            ELSE
                BEGIN
                    lv_error_message   := NULL;
                    submit_pr_trans_prog (p_user_id, p_resp_id, p_seq_number,
                                          lv_error_message);
                    p_err_msg          := 'Success';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_error_message   :=
                               'Errror while calling process trnasaction: '
                            || SQLERRM;
                        p_err_msg   := lv_error_message;
                        RETURN;
                END;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   :=
                   lv_error_message
                || ' '
                || SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            p_err_msg   := lv_error_message;
    END upload_pr_proc;

    --Added below procedure for change 1.1
    PROCEDURE submit_pr_trans_prog (pn_user_id IN NUMBER, pn_resp_id IN NUMBER, pn_batch_id IN NUMBER
                                    , pv_error_message OUT VARCHAR2)
    IS
        ln_request_id       NUMBER;
        lv_exp_error        VARCHAR2 (4000);
        ln_application_id   NUMBER;
    BEGIN
        SELECT application_id
          INTO ln_application_id
          FROM apps.fnd_responsibility_vl
         WHERE responsibility_id = pn_resp_id;

        apps.fnd_global.apps_initialize (pn_user_id,
                                         pn_resp_id,
                                         ln_application_id);
        ln_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'XXDO',
                program       => 'XXD_PO_PR_MODIFY_PRG',
                argument1     => pn_batch_id);
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_exp_error       :=
                'Error in move_org_action procedure ' || SQLERRM;
            pv_error_message   := lv_exp_error;
            RETURN;
    END;

    --Added below procedure for change 1.1
    PROCEDURE process_pr_transaction (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER, p_batch_id IN NUMBER
                                      , p_user_id IN NUMBER DEFAULT NULL)
    IS
        lv_error_message   VARCHAR2 (4000);
        lv_error_msg       VARCHAR2 (4000);
        ln_user_id         NUMBER;

        CURSOR stg_header_cur IS
            SELECT DISTINCT batch_id, action_type
              FROM xxd_po_pr_modify_details_t
             WHERE status = 'N' AND batch_id = p_batch_id;
    BEGIN
        IF p_user_id IS NULL
        THEN
            ln_user_id   := fnd_global.user_id;
        ELSE
            ln_user_id   := p_user_id;
        END IF;

        FOR stg_header_rec IN stg_header_cur
        LOOP
            IF stg_header_rec.action_type = 'CHG_SUPPLIER'
            THEN
                change_pr_supplier (ln_user_id,
                                    stg_header_rec.batch_id,
                                    lv_error_msg);
            END IF;
        END LOOP;
    END;

    --Added below procedure for change 1.1
    PROCEDURE change_pr_supplier (pn_user_id IN NUMBER, pn_batch_id IN NUMBER, pv_error_message OUT VARCHAR2)
    IS
        CURSOR stg_rec_det IS
            SELECT DISTINCT source_pr_header_id, action_type, new_supplier_id,
                            new_supplier_site_id
              FROM xxd_po_pr_modify_details_t
             WHERE batch_id = pn_batch_id AND status = 'N';

        CURSOR stg_pr_det (cn_pr_header_id NUMBER, cv_action_type VARCHAR2, cn_new_supplier_id NUMBER
                           , cn_new_supplier_site_id NUMBER)
        IS
            SELECT *
              FROM xxd_po_pr_modify_details_t
             WHERE     batch_id = pn_batch_id
                   AND status = 'N'
                   AND source_pr_header_id = cn_pr_header_id
                   AND action_type = cv_action_type
                   AND new_supplier_id = cn_new_supplier_id
                   AND new_supplier_site_id = cn_new_supplier_site_id;

        pr_line_det        xxdo.xxd_po_line_det_type;
        lv_error_flag      VARCHAR2 (1);
        lv_error_message   VARCHAR2 (4000);
    BEGIN
        FOR stg_rec IN stg_rec_det
        LOOP
            pr_line_det   := xxdo.xxd_po_line_det_type (NULL);

            FOR stg_pr_rec IN stg_pr_det (stg_rec.source_pr_header_id, stg_rec.action_type, stg_rec.new_supplier_id
                                          , stg_rec.new_supplier_site_id)
            LOOP
                pr_line_det.EXTEND;
                pr_line_det (pr_line_det.COUNT)   :=
                    xxdo.xxd_po_line_det_tab ('',
                                              stg_pr_rec.source_pr_line_id,
                                              NULL);
            END LOOP;

            xxd_po_pomodify_utils_pkg.update_po_requisition_line (
                pn_user_id,
                stg_rec.source_pr_header_id,
                stg_rec.new_supplier_id,
                stg_rec.new_supplier_site_id,
                '',
                pr_line_det,
                'Y',                                       --req_auto_approval
                lv_error_flag,
                lv_error_message);

            IF lv_error_message IS NULL AND NVL (lv_error_flag, 'S') <> 'E'
            THEN
                xxd_po_pomodify_utils_pkg.approve_requisition (
                    stg_rec.source_pr_header_id,
                    lv_error_flag,
                    lv_error_message);

                IF lv_error_message IS NOT NULL
                THEN
                    UPDATE xxd_po_pr_modify_details_t
                       SET status = 'E', error_message = lv_error_message
                     WHERE     batch_id = pn_batch_id
                           AND status = 'N'
                           AND source_pr_header_id =
                               stg_rec.source_pr_header_id
                           AND action_type = stg_rec.action_type
                           AND new_supplier_id = stg_rec.new_supplier_id
                           AND new_supplier_site_id =
                               stg_rec.new_supplier_site_id;
                ELSE
                    UPDATE xxd_po_pr_modify_details_t
                       SET status = 'S', error_message = lv_error_message
                     WHERE     batch_id = pn_batch_id
                           AND status = 'N'
                           AND source_pr_header_id =
                               stg_rec.source_pr_header_id
                           AND action_type = stg_rec.action_type
                           AND new_supplier_id = stg_rec.new_supplier_id
                           AND new_supplier_site_id =
                               stg_rec.new_supplier_site_id;
                END IF;

                COMMIT;
            ELSE
                UPDATE xxd_po_pr_modify_details_t
                   SET status = 'E', error_message = 'Error While Updating Requisition03' || lv_error_message
                 WHERE     batch_id = pn_batch_id
                       AND status = 'N'
                       AND source_pr_header_id = stg_rec.source_pr_header_id
                       AND action_type = stg_rec.action_type
                       AND new_supplier_id = stg_rec.new_supplier_id
                       AND new_supplier_site_id =
                           stg_rec.new_supplier_site_id;

                COMMIT;
            END IF;
        END LOOP;
    END change_pr_supplier;
END xxd_po_pomodify_pkg;
/
