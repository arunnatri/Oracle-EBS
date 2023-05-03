--
-- XXD_PO_PRC_MODIFY_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_PRC_MODIFY_PKG"
/****************************************************************************************
* Package      : XXD_PO_PRC_MODIFY_PKG
* Design       : This package is used to modify purchase order Price from PO Price Utility OA Page
* Notes        :
* Modification :
-- ======================================================================================
-- Date         Version#   Name                    Comments
-- ======================================================================================
-- 16-Aug-2020  1.0        Gaurav               Initial version
-- 13-Apr-2020  1.1        Gaurav/Balavenu      CCR0009290 CSR 10301 - upload validation performance issue
******************************************************************************************/
AS
    PROCEDURE send_email (p_action      IN VARCHAR2,
                          p_batch_id    IN VARCHAR2,
                          p_header_id   IN VARCHAR2)
    IS
        l_brand_width      NUMBER := 8;
        l_number_width     NUMBER := 12;
        l_data_exists      BOOLEAN;
        l_ret_val          NUMBER;
        idx                NUMBER;
        ex_no_recips       EXCEPTION;
        ex_no_sender       EXCEPTION;
        ex_no_data_found   EXCEPTION;
        lc_mail_data       VARCHAR2 (2000);
        l_instance_name    VARCHAR2 (50);

        CURSOR c_managers IS
            SELECT email_address
              FROM apps.fnd_lookup_values a, fnd_user b
             WHERE     lookup_type = 'XXD_PO_PRICE_UPDATE_APPROVERS'
                   AND language = 'US'
                   AND enabled_flag = 'Y'
                   AND a.meaning = b.user_name
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1);

        --- this cursor is to send all pending PO for approval to Managers defined in the XXD_PO_PRICE_UPDATE_APPROVERS
        CURSOR c_pending_approval IS
              SELECT po_number, SUM (open_qty * new_unit_price - open_qty * unit_price) po_amount_change, brand
                FROM xxd_po_prc_upd_rpt_detailed_v a
               WHERE status = p_action
            GROUP BY po_number, po_header_id, brand
            ORDER BY brand, po_number;

        -- this cursor is get the PO details that has been approved/rejected  and send the email to the requester/buyer
        CURSOR c_users_approved_rejected IS
              SELECT email_address, user_id
                FROM xxd_po_prc_upd_rpt_detailed_v a, po_agents_v b, fnd_user v
               WHERE     po_header_id IN
                             (    SELECT TRIM (REGEXP_SUBSTR (str, '[^,]+', 1
                                                              , LEVEL)) str
                                    FROM (SELECT p_header_id str FROM DUAL)
                              CONNECT BY INSTR (str, ',', 1,
                                                LEVEL - 1) > 0)
                     AND batch_id IN (    SELECT TRIM (REGEXP_SUBSTR (str, '[^,]+', 1
                                                                      , LEVEL)) str
                                            FROM (SELECT p_batch_id str FROM DUAL)
                                      CONNECT BY INSTR (str, ',', 1,
                                                        LEVEL - 1) > 0)
                     AND b.agent_name = a.price_updated_by
                     AND status = p_action
                     AND b.agent_id = v.employee_id
            GROUP BY email_address, status, user_id;

        CURSOR c_po_details_apprv_reject (p_user_id NUMBER)
        IS
            SELECT DISTINCT po_number, status, brand
              FROM xxd_po_prc_upd_rpt_detailed_v a, po_agents_v b, fnd_user v
             WHERE     po_header_id IN
                           (    SELECT TRIM (REGEXP_SUBSTR (str, '[^,]+', 1
                                                            , LEVEL)) str
                                  FROM (SELECT p_header_id str FROM DUAL)
                            CONNECT BY INSTR (str, ',', 1,
                                              LEVEL - 1) > 0)
                   AND batch_id IN (    SELECT TRIM (REGEXP_SUBSTR (str, '[^,]+', 1
                                                                    , LEVEL)) str
                                          FROM (SELECT p_batch_id str FROM DUAL)
                                    CONNECT BY INSTR (str, ',', 1,
                                                      LEVEL - 1) > 0)
                   AND b.agent_name = a.price_updated_by
                   AND status = p_action
                   AND b.agent_id = v.employee_id
                   AND user_id = p_user_id;
    BEGIN
        SELECT DECODE (applications_system_name, 'EBSPROD', 'PRODUCTION', applications_system_name)
          INTO l_instance_name
          FROM apps.fnd_product_groups;

        IF p_action = ('Sent for Approval')
        THEN
            FOR i IN c_pending_approval
            LOOP
                lc_mail_data   :=
                       lc_mail_data
                    || RPAD (i.brand, 10, '   ')
                    || LPAD (i.po_number, 10, '   ')
                    || LPAD (i.po_amount_change, 10, '   ')
                    || CHR (10);
            END LOOP;

            -- get the Managers and send to all of them
            FOR i IN c_managers
            LOOP
                do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), i.email_address, l_instance_name || ' - POs Awaiting Price Update Approval submitted from PO Price Update Utility'
                                                , l_ret_val);
                do_mail_utils.send_mail_line ('', l_ret_val);
                do_mail_utils.send_mail_line (
                       RPAD ('Brand', 15, ' ')
                    || LPAD ('PO Number', 10, ' ')
                    || LPAD ('PO Amount Change', 20, ' '),
                    l_ret_val);

                do_mail_utils.send_mail_line (lc_mail_data, l_ret_val);

                do_mail_utils.send_mail_close (l_ret_val);
            END LOOP;
        END IF;

        IF p_action IN ('Approved', 'Rejected')
        THEN
            FOR i IN c_users_approved_rejected
            LOOP
                FOR j IN c_po_details_apprv_reject (i.user_id)
                LOOP
                    lc_mail_data   :=
                           lc_mail_data
                        || RPAD (j.brand, 15, '   ')
                        || LPAD (j.po_number, 10, '   ')
                        || CHR (10);
                END LOOP;

                do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), i.email_address, l_instance_name || ' - PO(s) submitted for price change is/are ' || UPPER (p_action) || ' (PO Price Update Utility)'
                                                , l_ret_val);
                do_mail_utils.send_mail_line ('', l_ret_val);
                do_mail_utils.send_mail_line (
                    RPAD ('Brand', 15, ' ') || LPAD ('PO Number', 10, ' '),
                    l_ret_val);

                do_mail_utils.send_mail_line (lc_mail_data, l_ret_val);

                do_mail_utils.send_mail_close (l_ret_val);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            do_mail_utils.send_mail_close (l_ret_val);               --be safe
    END send_email;

    PROCEDURE process_file (p_file_id IN NUMBER, x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2
                            , x_batch_id OUT NOCOPY VARCHAR2)
    IS
        l_file                   UTL_FILE.file_type;
        v_line                   VARCHAR2 (1000);
        l_po_number              VARCHAR2 (1000);
        l_style                  VARCHAR2 (100);
        l_color                  VARCHAR2 (100);
        l_xf_date                VARCHAR2 (100);
        l_fob_cost               VARCHAR2 (100);
        l_moq_surcharge          VARCHAR2 (100);
        l_ship_to_id_surcharge   VARCHAR2 (100);
        l_file_name              VARCHAR2 (100);
        l_blob                   BLOB;
        v_sql_stmt               VARCHAR2 (1000);
        l_buffer                 RAW (32767);
        l_amount                 BINARY_INTEGER := 32767;
        l_pos                    INTEGER := 1;
        l_blob_len               INTEGER;
        l_line_err_string        VARCHAR2 (1000);
        v_new_num1               NUMBER;
        v_new_num2               NUMBER;
        v_new_num3               NUMBER;
        l_po_count               NUMBER;
        l_valid_sty_color        NUMBER;
        l_line_validation_flag   VARCHAR2 (1) := 'N';
        l_line_error_count       NUMBER;
        l_ret_status             VARCHAR2 (4000);
        l_err_msg                VARCHAR2 (4000);
        l_final_error            VARCHAR2 (4000);
        l_line_count             NUMBER := 1;
        v_date                   DATE;
        l_commit_trans           VARCHAR2 (1) := 'Y';
        l_facility_site_code     NUMBER;
        ln_request_id            NUMBER;
        l_extracted_count        NUMBER;
        v_type                   xxdo.xxd_po_price_upd_tbl_typ
                                     := xxdo.xxd_po_price_upd_tbl_typ ();
        ln_po_header_id          NUMBER := 0; --Added by KKB on 15May21 CCR0009290
        ln_org_id                NUMBER := 0; --Added by KKB on 15May21 CCR0009290

        --Cursor to parse file and get the PO details
        CURSOR cur_lines IS
            (SELECT REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   1, NULL, 1) po_number,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   2, NULL, 1) vendor_site_code,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   3, NULL, 1) style,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   4, NULL, 1) color,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   5, NULL, 1) conf_xf_date,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   6, NULL, 1) fob_cost,
                    REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                   7, NULL, 1) global_surcharge,
                    TRANSLATE (REGEXP_SUBSTR (x.col1 || ',', '([^,]*),|$', 1,
                                              8, NULL, 1),
                               'x' || CHR (10) || CHR (13),
                               'x') ship_to_id_surcharge
               FROM xxdo.xxd_file_upload_t src, XMLTABLE ('/a/b' PASSING xmltype ('<a><b>' || REPLACE (xxd_common_utils.conv_to_clob (src.file_data), CHR (10), '</b><b>') || '</b></a>') COLUMNS col1 VARCHAR2 (2000) PATH '.') x
              WHERE     1 = 1
                    AND src.file_source = 'FOB'
                    AND src.file_id = p_file_id
                    AND REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                       1)
                            IS NOT NULL
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             'PURCHASE%')
                    AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                                     1))) NOT LIKE
                             'PO%'));
    BEGIN
        x_batch_id   := xxdo.xxd_po_price_update_batch_s.NEXTVAL ();

        --- loop thru all the rows; do the validation and at the end; isnert the record
        FOR i IN cur_lines
        LOOP
            l_line_err_string        := NULL;
            l_line_validation_flag   := 'N';

            IF (i.conf_xf_date IS NOT NULL)
            THEN
                BEGIN
                    v_date   := TO_DATE (i.conf_xf_date);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_line_err_string        :=
                               l_line_err_string
                            || 'Invalid Date format for Conf XF Date '
                            || i.conf_xf_date
                            || ' ;';
                        l_line_validation_flag   := 'Y';
                END;
            END IF;                                               -- Added 1.1

            -- Begin 1.1 commented due to performance issue
            -- validate order first
            /*    SELECT COUNT (po_number)
                  INTO l_po_count
                  FROM XXD_PO_PRICE_UPDATE_DETAILS_V
                 WHERE po_number = i.po_number; */

            SELECT COUNT (segment1)
              INTO l_po_count
              FROM po_headers_all pha
             WHERE     1 = 1
                   AND pha.segment1 = i.po_number
                   AND pha.authorization_status = 'APPROVED'
                   AND NVL (pha.closed_code, 'OPEN') = 'OPEN'
                   -- Exclude SFS PO (Added on 15May21 for CCR0009290)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM ap_suppliers aps
                             WHERE     aps.vendor_id = pha.vendor_id
                                   AND vendor_name = 'Deckers Retail Stores')
                   AND EXISTS
                           (SELECT 1
                              FROM po_lines_all pla, po_line_locations_all poll
                             --  hr_operating_units hou,
                             --mtl_system_items_b msib,
                             -- ap_supplier_sites_all aps,
                             --fnd_user fu -- commented CCR0009290
                             WHERE     1 = 1
                                   AND pha.po_header_id = pla.po_header_id
                                   AND pla.quantity != 0
                                   AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                                   --AND fu.employee_id = pha.agent_id  -- commented CCR0009290
                                   AND pla.po_header_id = poll.po_header_id
                                   AND pla.po_line_id = poll.po_line_id
                                   AND poll.closed_code = 'OPEN'
                                   AND pla.item_id IS NOT NULL
                                   AND poll.quantity_received = 0
                                   AND (pla.cancel_flag != 'Y' OR pla.cancel_flag IS NULL)
                                   AND (poll.cancel_flag != 'Y' OR poll.cancel_flag IS NULL)
                                   --AND aps.org_id = pha.org_id
                                   -- AND aps.vendor_site_id = pha.vendor_site_id
                                   --AND msib.inventory_item_id = pla.item_id
                                   --AND msib.organization_id =poll.ship_to_organization_id
                                   -- AND pha.org_id = hou.organization_id
                                   --                                AND NOT EXISTS   --commented CCR0009290
                                   --                                           (SELECT 1
                                   --                                              FROM custom.do_items di
                                   --                                             WHERE     di.order_id =
                                   --                                                          pha.po_header_id
                                   --                                                   AND di.order_line_id =
                                   --                                                          pla.po_line_id
                                   --                                                   AND di.entered_quantity
                                   --                                                          IS NOT NULL)
                                   --        AND NOT EXISTS (  -- added CCR0009290
                                   --         SELECT
                                   --          1
                                   --         FROM
                                   --          custom.do_items        di,
                                   --          custom.do_containers   dc
                                   --         WHERE
                                   --          di.order_id = pha.po_header_id
                                   ----          AND di.order_line_id = pla.po_line_id
                                   --          AND di.entered_quantity IS NOT NULL
                                   --          AND di.container_id = dc.container_id
                                   --          AND dc.extract_status = 'Extracted'
                                   --        )
                                   AND EXISTS
                                           (SELECT 1
                                              FROM fnd_lookup_values flv
                                             WHERE     1 = 1
                                                   AND flv.lookup_type =
                                                       'XXD_PO_PRICE_UPDATE_OU'
                                                   AND flv.language = 'US'
                                                   AND TO_NUMBER (
                                                           flv.lookup_code) =
                                                       pha.org_id
                                                   AND flv.enabled_flag = 'Y'
                                                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                                   NVL (
                                                                                       flv.start_date_active,
                                                                                       SYSDATE))
                                                                           AND TRUNC (
                                                                                   NVL (
                                                                                       flv.end_date_active,
                                                                                       SYSDATE))));


            -- end 1.1

            --Extarxt statys validate
            --  SELECT
            --   COUNT(*) INTO l_extracted_count
            --  FROM
            --   custom.do_items        di,
            --   custom.do_containers   dc
            --  WHERE
            --   di.order_id IN (SELECT po_header_id FROM po_headers_all pha WHERE  1 = 1 AND pha.segment1 = i.po_number)
            --   AND di.entered_quantity IS NOT NULL
            --   AND di.container_id = dc.container_id
            --   AND dc.extract_status = 'Extracted';
            --  IF(l_extracted_count>0) THEN
            --   l_line_err_string :=
            --                  l_line_err_string
            --                  || 'ASN is Extracted for this PO ; ';
            --            l_line_validation_flag := 'Y';
            --  END IF;
            --
            --Added by KKB on 15May21 CCR0009290
            IF l_po_count > 0
            THEN
                BEGIN
                    SELECT pha.po_header_id, pha.org_id
                      INTO ln_po_header_id, ln_org_id
                      FROM po_headers_all pha
                     WHERE 1 = 1 AND pha.segment1 = i.po_number;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_line_err_string        :=
                            l_line_err_string || 'PO does not exist ; ';
                        l_line_validation_flag   := 'Y';
                END;
            END IF;

            --Added for CCR0009290 --START

            SELECT COUNT (1)
              INTO l_extracted_count
              FROM rcv_shipment_lines rsl
             WHERE     1 = 1
                   AND rsl.po_header_id = ln_po_header_id --Added by KKB on 15May21 CCR0009290
                   AND rsl.shipment_line_status_code <> 'CANCELLED'; -- added CCR0009290

            IF (l_extracted_count = 0)
            THEN
                SELECT COUNT (1)
                  INTO l_extracted_count
                  FROM apps.rcv_transactions_interface rti
                 WHERE     rti.interface_source_code = 'RCV'
                       AND rti.source_document_code = 'PO'
                       AND rti.po_header_id = ln_po_header_id;
            END IF;


            IF (l_extracted_count > 0)
            THEN
                l_line_err_string        :=
                    l_line_err_string || 'ASN is Extracted for this PO ; ';
                l_line_validation_flag   := 'Y';
            END IF;

            --Added for CCR0009290 --END

            -- VALIDATE VENDOR SITE CODE

            /*--Commented by KKB on 15May21 CCR0009290
            SELECT COUNT (*)
              INTO l_facility_site_code
              FROM po_headers_all poh,
                   po_lines_all pla,
                   po_line_locations_all plla,
                   mtl_system_items_b msib
             WHERE     1 = 1
                   AND l_po_count <> 0 -- po is valid then only validate SITE CODE
                   AND poh.po_header_id = pla.po_header_id
                   AND pla.po_header_id = plla.po_header_id
                   AND pla.po_line_id = plla.po_line_id
                   AND poh.segment1 = i.po_number
                   AND NVL (poh.closed_code, 'OPEN') = 'OPEN'
                   AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                   AND plla.closed_code = 'OPEN'
                   AND poh.authorization_status = 'APPROVED'
                   AND NVL (pla.cancel_flag, 'N') = 'N'
                   AND NVL (plla.cancel_flag, 'N') = 'N'
                   AND pla.item_id = msib.inventory_item_id
                   AND msib.inventory_item_id = pla.item_id
                   AND msib.organization_id = plla.ship_to_organization_id
                   AND plla.quantity_received = 0
                   AND REGEXP_SUBSTR (msib.segment1,
                                      '[^-]+',
                                      1,
                                      1) = i.style
                   AND REGEXP_SUBSTR (msib.segment1,
                                      '[^-]+',
                                      1,
                                      2) = i.color
                   AND msib.organization_id = plla.ship_to_organization_id
                   AND ROWNUM = 1
                   AND EXISTS
                          (SELECT 1
                             FROM ap_supplier_sites_all aps
                            WHERE     aps.org_id = poh.org_id
                                  AND aps.vendor_site_code = i.vendor_site_code)
   --                AND NOT EXISTS    -- commented CCR0009290
   --                           (SELECT 1
   --                              FROM custom.do_items di
   --                             WHERE     di.order_id = pla.po_header_id
   --                                   AND di.order_line_id = pla.po_line_id
   --                                   AND di.entered_quantity IS NOT NULL)
       */
            --Added by KKB on 15May21 CCR0009290
            SELECT COUNT (*)
              INTO l_facility_site_code
              FROM ap_supplier_sites_all aps
             WHERE     1 = 1
                   AND l_po_count <> 0                              --Valid PO
                   AND aps.org_id = ln_org_id
                   AND aps.vendor_site_code = UPPER (i.vendor_site_code);

            --PO valid but facility site in Invalid
            IF l_facility_site_code = 0 AND l_po_count <> 0
            THEN
                l_line_err_string        :=
                       l_line_err_string
                    || 'facility site not valid for the given style-color combination; ';
                l_line_validation_flag   := 'Y';
            END IF;

            IF l_po_count = 0
            THEN
                l_line_err_string        :=
                    l_line_err_string || 'Invalid PO Number; ';
                l_line_validation_flag   := 'Y';
            END IF;

            --Style Color Validation
            /* Commented by KKB on 15May21 CCR0009290
            SELECT COUNT (poh.po_header_id)
              INTO l_valid_sty_color
              FROM po_headers_all poh,
                   po_lines_all pla,
                   po_line_locations_all plla,
                   mtl_system_items_b msib
             WHERE     1 = 1
                   AND l_po_count <> 0 -- po is valid then only validate style color w.r.t the given PO
                   AND poh.po_header_id = pla.po_header_id
                   AND pla.po_header_id = plla.po_header_id
                   AND pla.po_line_id = plla.po_line_id
                   AND poh.segment1 = i.po_number
                   AND NVL (poh.closed_code, 'OPEN') = 'OPEN'
                   AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                   AND plla.closed_code = 'OPEN'
                   AND poh.authorization_status = 'APPROVED'
                   AND NVL (pla.cancel_flag, 'N') = 'N'
                   AND NVL (plla.cancel_flag, 'N') = 'N'
                   AND pla.item_id = msib.inventory_item_id
                   AND msib.inventory_item_id = pla.item_id
                   AND msib.organization_id = plla.ship_to_organization_id
                   AND plla.quantity_received = 0
                   AND REGEXP_SUBSTR (msib.segment1,
                                      '[^-]+',
                                      1,
                                      1) = i.style
                   AND REGEXP_SUBSTR (msib.segment1,
                                      '[^-]+',
                                      1,
                                      2) = i.color
                   AND msib.organization_id = plla.ship_to_organization_id
                   AND ROWNUM = 1
                     --commented CCR0009290
   --                AND NOT EXISTS
   --                           (SELECT 1
   --                              FROM custom.do_items di
   --                             WHERE     di.order_id = pla.po_header_id
   --                                   AND di.order_line_id = pla.po_line_id
   --                                   AND di.entered_quantity IS NOT NULL)

      */
            SELECT COUNT (pla.po_header_id)
              INTO l_valid_sty_color
              FROM po_lines_all pla, po_line_locations_all plla, mtl_system_items_b msib
             WHERE     1 = 1
                   AND l_po_count <> 0 -- po is valid then only validate style color w.r.t the given PO
                   AND pla.po_header_id = ln_po_header_id
                   AND pla.po_header_id = plla.po_header_id
                   AND pla.po_line_id = plla.po_line_id
                   AND pla.item_id = msib.inventory_item_id
                   AND msib.organization_id = plla.ship_to_organization_id
                   AND REGEXP_SUBSTR (msib.segment1, '[^-]+', 1,
                                      1) = i.style
                   AND REGEXP_SUBSTR (msib.segment1, '[^-]+', 1,
                                      2) = i.color
                   AND ROWNUM = 1;

            IF l_valid_sty_color = 0
            THEN
                l_line_err_string        :=
                    l_line_err_string || 'Style-Color is not valid; ';
                l_line_validation_flag   := 'Y';
            END IF;

            IF     i.fob_cost IS NULL
               AND i.global_surcharge IS NULL
               AND i.ship_to_id_surcharge IS NULL
            THEN
                l_line_err_string        :=
                    l_line_err_string || 'All the price elements are blank; ';
                l_line_validation_flag   := 'Y';
            END IF;

            IF     i.fob_cost = 0
               AND i.global_surcharge = 0
               AND i.ship_to_id_surcharge = 0
            THEN
                l_line_err_string        :=
                       l_line_err_string
                    || 'All the price elements cannot be zero; ';
                l_line_validation_flag   := 'Y';
            END IF;


            IF i.fob_cost <= 0
            --            AND i.global_surcharge <> 0 -- comented CCR0009290
            --          AND i.ship_to_id_surcharge <> 0 -- comented CCR0009290
            THEN
                l_line_err_string        :=
                       l_line_err_string
                    || 'FOB Cost cannot be Zero Or Negative; ';
                l_line_validation_flag   := 'Y';
            END IF;

            IF    NVL (i.global_surcharge, 0) < 0
               OR NVL (i.ship_to_id_surcharge, 0) < 0      -- Added CCR0009290
            THEN
                l_line_err_string        :=
                       l_line_err_string
                    || 'Global Surcharge And Ship To Surcharge values Should not be Negative ; ';
                l_line_validation_flag   := 'Y';
            END IF;

            IF i.fob_cost IS NOT NULL
            THEN
                BEGIN
                    v_new_num1   := TO_NUMBER (i.fob_cost);
                EXCEPTION
                    WHEN VALUE_ERROR
                    THEN
                        l_line_err_string        :=
                            l_line_err_string || 'Invalid FOB Amount; ';
                        l_line_validation_flag   := 'Y';
                END;
            END IF;

            IF i.global_surcharge IS NOT NULL
            THEN
                BEGIN
                    v_new_num2   := TO_NUMBER (i.global_surcharge);
                EXCEPTION
                    WHEN VALUE_ERROR
                    THEN
                        l_line_err_string        :=
                               l_line_err_string
                            || 'Invalid Global Surcharge Amount; ';
                        l_line_validation_flag   := 'Y';
                END;
            END IF;

            IF i.ship_to_id_surcharge IS NOT NULL
            THEN
                BEGIN
                    v_new_num3   := TO_NUMBER (i.ship_to_id_surcharge);
                EXCEPTION
                    WHEN VALUE_ERROR
                    THEN
                        l_line_err_string        :=
                               l_line_err_string
                            || 'Invalid Ship to Surcharge Amount; ';
                        l_line_validation_flag   := 'Y';
                END;
            END IF;

            l_line_count             := l_line_count + 1;

            -- CURRENT ROW HAS VALIDATION
            -- Line#<> in file for PO#<> -

            IF l_line_validation_flag = 'Y'
            THEN
                l_final_error    :=
                    SUBSTR (
                           l_final_error
                        || 'Line '
                        || l_line_count
                        || ' in File for '
                        || 'PO '
                        || i.po_number
                        || '- '
                        || l_line_err_string
                        || '#',
                        1,
                        3999);

                l_commit_trans   := 'N';
            END IF;
        --  l_line_count := l_line_count + 1;
        END LOOP;

        IF l_commit_trans = 'Y'        -- all the rows are clean and validated
        THEN
            UPDATE xxdo.xxd_file_upload_t
               SET process_status = 'SUCCESS', batch_id = x_batch_id, last_update_date = SYSDATE --Added by KKB on 15May21 CCR0009290
             WHERE file_id = p_file_id;

            x_ret_status   := 'S';

            COMMIT;
            --Now proceed with inserting into staging table and update price elements on PO
            main (p_batch_id      => x_batch_id,
                  p_org_id        => NULL,
                  p_resp_id       => NULL,
                  p_resp_app_id   => NULL,
                  p_user_id       => fnd_global.user_id,
                  p_style_color   => v_type,
                  p_mode          => 'OFFLINE',
                  x_ret_status    => l_ret_status,
                  x_err_msg       => l_err_msg);
        ELSE
            x_ret_status   := 'E';
            x_err_msg      :=
                SUBSTR (l_final_error, 0, LENGTH (l_final_error) - 1);

            UPDATE xxdo.xxd_file_upload_t
               SET process_status = 'ERROR', last_update_date = SYSDATE --Added by KKB on 15May21 CCR0009290
             WHERE file_id = p_file_id;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_err_msg   := SUBSTR (SQLERRM, 1, 999);
    END process_file;


    PROCEDURE user_role (p_user_id IN NUMBER, x_role OUT NOCOPY VARCHAR2)
    IS
        l_count_approver   NUMBER;
        l_count_user       NUMBER;
    BEGIN
        SELECT COUNT (user_id)
          INTO l_count_approver
          FROM apps.fnd_lookup_values a, fnd_user b
         WHERE     lookup_type = 'XXD_PO_PRICE_UPDATE_APPROVERS'
               AND language = 'US'
               AND enabled_flag = 'Y'
               AND a.meaning = b.user_name
               AND b.user_id = p_user_id
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                               AND NVL (end_date_active, SYSDATE + 1);


        SELECT COUNT (user_id)
          INTO l_count_user
          FROM apps.fnd_lookup_values a, fnd_user b
         WHERE     lookup_type = 'XXD_PO_PRICE_UPDATE_USERS'
               AND language = 'US'
               AND enabled_flag = 'Y'
               AND a.meaning = b.user_name
               AND b.user_id = p_user_id
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                               AND NVL (end_date_active, SYSDATE + 1);

        IF l_count_approver = 0
        THEN                                                -- NOT AN APPROVER
            -- CHECK IF USER IN THE LIST
            IF l_count_user = 0
            THEN
                x_role   := 'UNATHORIZED';
            ELSE
                x_role   := 'SUBMITTER';
            END IF;
        ELSE
            x_role   := 'APPROVER';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_role   := 'UNATHORIZED';
    END user_role;

    PROCEDURE log_message (p_status IN VARCHAR2, p_msg IN VARCHAR2, p_po_line_id IN NUMBER
                           , p_batch_id IN NUMBER, p_request_id IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_user_role   VARCHAR2 (20);
    BEGIN
        user_role (fnd_global.user_id, l_user_role);

        UPDATE xxd_po_prc_update_details_t
           SET status = p_status, error_message = p_msg, request_id = p_request_id,
               last_updated_date = SYSDATE, last_updated_by = fnd_global.user_id, price_Approved_by = DECODE (l_user_role, 'APPROVER', fnd_global.user_id, NULL),
               price_Approved_date = DECODE (l_user_role, 'APPROVER', SYSDATE, NULL)
         WHERE po_line_id = p_po_line_id AND batch_id = p_batch_id;

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
    END log_message;

    PROCEDURE process_headers (p_batch_id IN NUMBER)
    IS
        CURSOR get_headers IS
              SELECT po_header_id, po_number, MIN (org_id) org_id,
                     SUM (quantity * new_unit_price) new_po_total_offset, SUM (quantity * unit_price) old_po_total_offset, MIN (NVL (moq_surcharge, 0)) moq_surcharge,
                     MIN (NVL (ship_surcharge, 0)) ship_surcharge, MIN (new_moq_surcharge) new_moq_surcharge, MIN (new_ship_surcharge) new_ship_surcharge
                FROM xxd_po_prc_update_details_t
               WHERE 1 = 1 AND batch_id = p_batch_id
            GROUP BY po_header_id, po_number
            ORDER BY org_id;

        lv_error_message   VARCHAR2 (4000);
        ln_request_id      NUMBER;
        l_threshold        NUMBER;
        l_user_role        VARCHAR2 (20);
        l_send_email       VARCHAR2 (1) := 'N';
    BEGIN
        user_role (fnd_global.user_id, l_user_role);

        BEGIN
            SELECT description
              INTO l_threshold
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_PO_PRICE_UPDATE_LIMIT'
                   AND flv.language = 'US'
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (start_date_active,
                                                        SYSDATE))
                                           AND TRUNC (
                                                   NVL (end_date_active,
                                                        SYSDATE));
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE;
        END;

        -- now loop for all the hdr in the batch and find out processing status
        FOR rec_hdr IN get_headers
        LOOP
            -- update all old "sent for approval" request to discard as we have new came in for the
            -- same header id and that can go in any status : direct app or sent for approval
            UPDATE xxd_po_prc_update_details_t
               SET status = 'Discarded', last_updated_by = fnd_global.user_id --Added by KKB on 15May21 CCR0009290
                                                                             , last_updated_date = SYSDATE --Added by KKB on 15May21 CCR0009290
             WHERE     status = 'Sent for Approval'
                   AND po_header_id = rec_hdr.po_header_id
                   AND batch_id <> p_batch_id;

            IF rec_hdr.new_po_total_offset < rec_hdr.old_po_total_offset
            THEN
                -- new unit price update on the POlines sumup to an amount which is less than the existing price on the given lines
                -- mark the lines as approved in custom table and call the standard API to post the changes in standard table
                UPDATE xxd_po_prc_update_details_t
                   SET status = 'Eligible for Auto Approve', last_updated_by = fnd_global.user_id --Added by KKB on 15May21 CCR0009290
                                                                                                 , last_updated_date = SYSDATE --Added by KKB on 15May21 CCR0009290
                 WHERE     po_header_id = rec_hdr.po_header_id
                       AND batch_id = p_batch_id;
            ELSIF rec_hdr.new_po_total_offset > rec_hdr.old_po_total_offset
            THEN    -- price update on lines is increasing the total po amount
                IF rec_hdr.new_po_total_offset - rec_hdr.old_po_total_offset >
                   l_threshold
                THEN
                    -- price delta is above threshold;;; update the custom table as "Sent for Approval"
                    IF l_user_role = 'SUBMITTER'
                    THEN
                        UPDATE xxd_po_prc_update_details_t
                           SET status = 'Sent for Approval', last_updated_by = fnd_global.user_id --Added by KKB on 15May21 CCR0009290
                                                                                                 , last_updated_date = SYSDATE --Added by KKB on 15May21 CCR0009290
                         WHERE     po_header_id = rec_hdr.po_header_id
                               AND batch_id = p_batch_id;

                        l_send_email   := 'Y';
                    -- send_email ('Sent for Approval', NULL, NULL); -- PENDING APPROVAL LIST IS ALWAYS CONSOLIDATED;
                    -- WHERE THERE IS A PO SUBMISSION TRIGGERING MANAGER APPROVAL; WE WILL SEND THE CONSOLIDATED LIST TO MANAGER EVERY TIME
                    ELSIF l_user_role = 'APPROVER'
                    THEN
                        UPDATE xxd_po_prc_update_details_t
                           SET status = 'Eligible for Auto Approve', last_updated_by = fnd_global.user_id --Added by KKB on 15May21 CCR0009290
                                                                                                         , last_updated_date = SYSDATE --Added by KKB on 15May21 CCR0009290
                         WHERE     po_header_id = rec_hdr.po_header_id
                               AND batch_id = p_batch_id;
                    END IF;


                    CONTINUE;
                ELSE
                    -- price delta is less than threshold; update the custom table
                    -- as "Auto Approved" and immeditally call the standard API to
                    UPDATE xxd_po_prc_update_details_t
                       SET status = 'Eligible for Auto Approve', last_updated_by = fnd_global.user_id --Added by KKB on 15May21 CCR0009290
                                                                                                     , last_updated_date = SYSDATE --Added by KKB on 15May21 CCR0009290
                     WHERE     po_header_id = rec_hdr.po_header_id
                           AND batch_id = p_batch_id;
                END IF;
            ELSE --  no changed in the net price, but could be a change in surcharges
                IF    (rec_hdr.moq_surcharge <> rec_hdr.new_moq_surcharge)
                   OR (rec_hdr.ship_surcharge <> rec_hdr.new_ship_surcharge)
                THEN
                    UPDATE xxd_po_prc_update_details_t
                       SET status = 'Eligible for Auto Approve', last_updated_by = fnd_global.user_id --Added by KKB on 15May21 CCR0009290
                                                                                                     , last_updated_date = SYSDATE --Added by KKB on  CCR0009290
                     WHERE     po_header_id = rec_hdr.po_header_id
                           AND batch_id = p_batch_id;
                ELSE
                    UPDATE xxd_po_prc_update_details_t
                       SET status = 'Ignored', error_message = 'No price changes to update', last_updated_by = fnd_global.user_id --Added by KKB on 15May21 CCR0009290
                                                                                                                                 ,
                           last_updated_date = SYSDATE --Added by KKB on 15May21 CCR0009290
                     WHERE     po_header_id = rec_hdr.po_header_id
                           AND batch_id = p_batch_id;
                END IF;
            END IF;
        END LOOP;

        IF l_send_email = 'Y'
        THEN
            send_email ('Sent for Approval', NULL, NULL);
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END process_headers;

    PROCEDURE main (
        p_batch_id      IN            NUMBER,
        p_org_id        IN            NUMBER,
        p_resp_id       IN            NUMBER,
        p_resp_app_id   IN            NUMBER,
        p_user_id       IN            NUMBER,
        p_style_color   IN            xxdo.xxd_po_price_upd_tbl_typ,
        p_mode          IN            VARCHAR2,
        x_ret_status       OUT NOCOPY VARCHAR2,
        x_err_msg          OUT NOCOPY VARCHAR2)
    IS
        CURSOR po_lines_det_cur IS
            SELECT pla.po_header_id,
                   poh.segment1
                       po_number,
                   pla.org_id,
                   pla.po_line_id,
                   plla.line_location_id,
                   poh.revision_num
                       header_rev_num,
                   pla.line_num
                       line_number,
                   plla.shipment_num
                       shipment_number,
                   REGEXP_SUBSTR (msib.segment1, '[^-]+', 1,
                                  1)
                       style,
                   REGEXP_SUBSTR (msib.segment1, '[^-]+', 1,
                                  2)
                       color,
                   TO_CHAR (fnd_date.canonical_to_date (plla.attribute5),
                            'MM/DD/YYYY')
                       conf_xf_date,
                   pla.quantity,
                   pla.unit_price,
                   (pla.attribute11)
                       fob_cost,
                   (pla.attribute8)
                       global_surcharge,
                   (pla.attribute9)
                       ship_to_id_surcharge,
                   --new_unit_price,
                   --new_fob_cost,
                   --new_moq_surcharge,
                   --new_ship_surcharge,
                   TO_NUMBER (
                         NVL (
                             p_style_color_tab.new_fob_cost,
                             (pla.unit_price - (NVL (pla.attribute8, 0) + NVL (pla.attribute9, 0))))
                       + NVL (p_style_color_tab.new_moq_surcharge,
                              NVL (pla.attribute8, 0))
                       + NVL (p_style_color_tab.new_ship_surcharge,
                              NVL (pla.attribute9, 0)))
                       new_unit_price,
                   TO_NUMBER (
                       NVL (
                           p_style_color_tab.new_fob_cost,
                           (pla.unit_price - (NVL (pla.attribute8, 0) + NVL (pla.attribute9, 0)))))
                       new_fob_cost,
                   --TO_NUMBER (NVL (p_style_color_tab.global_surcharge, 0))
                   TO_NUMBER (
                       NVL (p_style_color_tab.new_moq_surcharge,
                            pla.attribute8))
                       new_moq_surcharge,                         -- added 1.1
                   --TO_NUMBER (NVL (p_style_color_tab.new_ship_surcharge, 0))
                   --    TO_NUMBER (NVL (p_style_color_tab.ship_to_id_surcharge, NVL (pla.attribute9, 0)))
                   TO_NUMBER (
                       NVL (p_style_color_tab.new_ship_surcharge,
                            pla.attribute9))
                       new_ship_surcharge,                        -- added 1.1
                   NULL
                       file_name,
                   NVL (pla.attribute7, aps.vendor_site_code)
                       vendor_site_code,
                   pla.attribute1
                       brand
              FROM po_headers_all poh, po_lines_all pla, po_line_locations_all plla,
                   mtl_system_items_b msib, ap_supplier_sites_all aps, TABLE (p_style_color) p_style_color_tab
             WHERE     1 = 1
                   AND p_mode = 'ONLINE'
                   AND poh.po_header_id = p_style_color_tab.po_header_id
                   AND poh.po_header_id = pla.po_header_id
                   AND pla.po_header_id = p_style_color_tab.po_header_id
                   AND pla.po_header_id = plla.po_header_id
                   AND pla.po_line_id = plla.po_line_id
                   AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                   AND NVL (pla.cancel_flag, 'N') = 'N'
                   AND NVL (plla.cancel_flag, 'N') = 'N'
                   AND pla.item_id = msib.inventory_item_id
                   AND msib.inventory_item_id = pla.item_id
                   AND msib.organization_id = plla.ship_to_organization_id
                   AND poh.org_id = aps.org_id
                   AND poh.vendor_site_id = aps.vendor_site_id
                   AND p_style_color_tab.attribute1 =
                       NVL (pla.attribute7, aps.vendor_site_code)
                   /* AND (   poh.vendor_site_id = aps.vendor_site_id
                         OR pla.attribute7 = aps.vendor_site_code)
                    AND (   (    pla.attribute7 IS NOT NULL
                             AND pla.attribute7 = p_style_color_tab.attribute1)
                         OR (    pla.attribute7 IS NULL
                             AND aps.vendor_site_id = poh.vendor_site_id
                             AND p_style_color_tab.attribute1 =
                                    aps.vendor_site_code)) */
                   /*AND (       plla.attribute5 IS NULL
                           AND p_style_color_tab.conf_xf_date IS NULL
                        OR (    plla.attribute5 IS NOT NULL
                            AND p_style_color_tab.conf_xf_date IS NOT NULL
                            AND TRUNC (
                                   fnd_date.canonical_to_date (plla.attribute5)) =
                                   TRUNC (
                                      TO_DATE (p_style_color_tab.conf_xf_date,
                                               'DD-MON-YYYY'))))*/
                   AND plla.quantity_received = 0
                   AND msib.organization_id = plla.ship_to_organization_id
                   AND REGEXP_SUBSTR (msib.segment1, '[^-]+', 1,
                                      1) = p_style_color_tab.style
                   AND REGEXP_SUBSTR (msib.segment1, '[^-]+', 1,
                                      2) = p_style_color_tab.color
            /*AND NOT EXISTS
                       (SELECT 1
                          FROM custom.do_items di
                         WHERE     di.order_id = pla.po_header_id
                               AND di.order_line_id = pla.po_line_id
                               AND di.entered_quantity IS NOT NULL)*/
            --    AND NOT EXISTS ( -- added CCR0009290
            --         SELECT
            --          1
            --         FROM
            --          custom.do_items        di,
            --          custom.do_containers   dc
            --         WHERE
            --          di.order_id = poh.po_header_id
            ----          AND di.order_line_id = pla.po_line_id
            --          AND di.entered_quantity IS NOT NULL
            --          AND di.container_id = dc.container_id
            --          AND dc.extract_status = 'Extracted'
            --        )
            UNION ALL
            SELECT pla.po_header_id,
                   poh.segment1
                       po_number,
                   pla.org_id,
                   pla.po_line_id,
                   plla.line_location_id,
                   poh.revision_num
                       header_rev_num,
                   pla.line_num
                       line_number,
                   plla.shipment_num
                       shipment_number,
                   REGEXP_SUBSTR (msib.segment1, '[^-]+', 1,
                                  1)
                       style,
                   REGEXP_SUBSTR (msib.segment1, '[^-]+', 1,
                                  2)
                       color,
                   -- TO_CHAR (fnd_date.canonical_to_date (plla.attribute5),'MM/DD/YYYY') conf_xf_date, --commented CCR0009290
                   TO_CHAR (TO_DATE (conf_xf_date), 'MM/DD/YYYY')
                       conf_xf_date,                       -- Added CCR0009290
                   pla.quantity,
                   pla.unit_price,
                   (pla.attribute11)
                       fob_cost,
                   (pla.attribute8)
                       global_surcharge,
                   (pla.attribute9)
                       ship_to_id_surcharge,
                   /*TO_NUMBER (
                       NVL (
                          p_style_color_tab.fob_cost,
                          (  pla.unit_price
                           - (NVL (pla.attribute8, 0) + NVL (pla.attribute9, 0))))
                     + NVL (p_style_color_tab.global_surcharge, 0)
                     + NVL (p_style_color_tab.ship_to_id_surcharge, 0))*/
                   TO_NUMBER (
                         NVL (
                             p_style_color_tab.fob_cost,
                             (pla.unit_price - (NVL (pla.attribute8, 0) + NVL (pla.attribute9, 0))))
                       + NVL (p_style_color_tab.global_surcharge,
                              NVL (pla.attribute8, 0))
                       + NVL (p_style_color_tab.ship_to_id_surcharge,
                              NVL (pla.attribute9, 0)))
                       new_unit_price,
                   TO_NUMBER (
                       NVL (
                           p_style_color_tab.fob_cost,
                           (pla.unit_price - (NVL (pla.attribute8, 0) + NVL (pla.attribute9, 0)))))
                       new_fob_cost,
                   --TO_NUMBER (NVL (p_style_color_tab.global_surcharge, 0))
                   TO_NUMBER (
                       NVL (p_style_color_tab.global_surcharge,
                            pla.attribute8))
                       new_moq_surcharge,                         -- added 1.1
                   --TO_NUMBER (NVL (p_style_color_tab.ship_to_id_surcharge, 0))
                   TO_NUMBER (
                       NVL (p_style_color_tab.ship_to_id_surcharge,
                            pla.attribute9))
                       new_ship_surcharge,                        -- added 1.1
                   file_name,
                   NVL (pla.attribute7, aps.vendor_site_code)
                       vendor_site_code,
                   pla.attribute1
                       brand
              FROM po_headers_all poh,
                   po_lines_all pla,
                   po_line_locations_all plla,
                   mtl_system_items_b msib,
                   ap_supplier_sites_all aps,
                   (SELECT FILE_NAME,
                           BATCH_ID,
                           REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                          1, NULL, 1) po_number,
                           REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                          2, NULL, 1) vendor_site_code,
                           REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                          3, NULL, 1) style,
                           REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                          4, NULL, 1) color,
                           REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                          5, NULL, 1) conf_xf_date,
                           REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                          6, NULL, 1) fob_cost,
                           REGEXP_SUBSTR (x.col1, '([^,]*),|$', 1,
                                          7, NULL, 1) global_surcharge,
                           TRANSLATE (REGEXP_SUBSTR (x.col1 || ',', '([^,]*),|$', 1
                                                     , 8, NULL, 1),
                                      'x' || CHR (10) || CHR (13),
                                      'x') ship_to_id_surcharge
                      FROM xxdo.xxd_file_upload_t src, XMLTABLE ('/a/b' PASSING xmltype ('<a><b>' || REPLACE (xxd_common_utils.conv_to_clob (src.file_data), CHR (10), '</b><b>') || '</b></a>') COLUMNS col1 VARCHAR2 (2000) PATH '.') x
                     WHERE     1 = 1
                           AND src.batch_id = p_batch_id
                           AND src.file_source = 'FOB'
                           AND src.process_status = 'SUCCESS'
                           AND REGEXP_SUBSTR (x.col1, '[^,]+', 1,
                                              1)
                                   IS NOT NULL
                           AND (UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1
                                                            , 1))) NOT LIKE
                                    'PO%')
                           AND UPPER (TRIM (REGEXP_SUBSTR (x.col1, '[^,]+', 1
                                                           , 1))) NOT LIKE
                                   'PURCHASE%') p_style_color_tab
             WHERE     1 = 1
                   AND p_mode = 'OFFLINE'
                   AND poh.segment1 = p_style_color_tab.po_number
                   AND poh.po_header_id = pla.po_header_id
                   AND pla.po_header_id = plla.po_header_id
                   AND pla.po_line_id = plla.po_line_id
                   AND poh.org_id = aps.org_id
                   AND poh.vendor_site_id = aps.vendor_site_id
                   AND p_style_color_tab.vendor_site_code =
                       NVL (pla.attribute7, aps.vendor_site_code)
                   /*  AND (   poh.vendor_site_id = aps.vendor_site_id
                          OR pla.attribute7 = aps.vendor_site_code)
                     AND (   (    pla.attribute7 IS NOT NULL
                              AND pla.attribute7 =
                                     p_style_color_tab.vendor_site_code)
                          OR (    pla.attribute7 IS NULL
                              AND aps.vendor_site_id = poh.vendor_site_id
                              AND p_style_color_tab.vendor_site_code =
                                     aps.vendor_site_code))*/
                   AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                   AND NVL (pla.cancel_flag, 'N') = 'N'
                   AND NVL (plla.cancel_flag, 'N') = 'N'
                   AND pla.item_id = msib.inventory_item_id
                   /*AND (       plla.attribute5 IS NULL
                           AND p_style_color_tab.conf_xf_date IS NULL
                        OR (    plla.attribute5 IS NOT NULL
                            AND p_style_color_tab.conf_xf_date IS NOT NULL
                            AND TRUNC (
                                   fnd_date.canonical_to_date (plla.attribute5)) =
                                   TRUNC (
                                      TO_DATE (p_style_color_tab.conf_xf_date,
                                               'DD-MON-YY'))))*/
                   --commented 1.1
                   AND msib.organization_id = plla.ship_to_organization_id
                   AND plla.quantity_received = 0
                   AND REGEXP_SUBSTR (msib.segment1, '[^-]+', 1,
                                      1) = p_style_color_tab.style
                   AND REGEXP_SUBSTR (msib.segment1, '[^-]+', 1,
                                      2) = p_style_color_tab.color/*AND NOT EXISTS
                                                                             (SELECT 1
                                                                                FROM custom.do_items di
                                                                               WHERE     di.order_id = pla.po_header_id
                                                                                     AND di.order_line_id = pla.po_line_id
                                                                                     AND di.entered_quantity IS NOT NULL)*/
                                                                  /*--Commented by KKB on 15MAY21 CCR0009290
                                                      AND NOT EXISTS ( -- added CCR0009290
                                                           SELECT
                                                            1
                                                           FROM
                                                            custom.do_items        di,
                                                            custom.do_containers   dc
                                                           WHERE
                                                            di.order_id = poh.po_header_id
                                                  --          AND di.order_line_id = pla.po_line_id
                                                            AND di.entered_quantity IS NOT NULL
                                                            AND di.container_id = dc.container_id
                                                            AND dc.extract_status = 'Extracted'
                                                          )
                                                          */
                                                                  ;

        CURSOR get_headers IS
              SELECT po_header_id, po_number, MIN (org_id) org_id,
                     SUM (quantity * new_unit_price) new_po_total_offset, SUM (quantity * unit_price) old_po_total_offset, MIN (NVL (moq_surcharge, 0)) moq_surcharge,
                     MIN (NVL (ship_surcharge, 0)) ship_surcharge, MIN (new_moq_surcharge) new_moq_surcharge, MIN (new_ship_surcharge) new_ship_surcharge
                FROM xxd_po_prc_update_details_t
               WHERE 1 = 1 AND batch_id = p_batch_id
            GROUP BY po_header_id, po_number
            ORDER BY org_id;

        TYPE po_lines_type IS TABLE OF po_lines_det_cur%ROWTYPE;

        l_lines            po_lines_type;
        lv_error_message   VARCHAR2 (4000);
        lv_status          VARCHAR2 (10) := 'S';
        ln_request_id      NUMBER;
        l_threshold        NUMBER;
        l_user_role        VARCHAR2 (20);
        l_send_email       VARCHAR2 (1) := 'N';
        ln_extract_count   NUMBER;
        lv_po_number       VARCHAR2 (200);
    BEGIN
        -- added CCR0009290
        --   IF(p_style_color.count>0) THEN
        --  FOR j IN p_style_color.FIRST..p_style_color.LAST
        --  LOOP
        --  SELECT count(1) INTO ln_extract_count
        --                FROM
        --                    custom.do_items        di,
        --                    custom.do_containers   dc,
        --                    TABLE(p_style_color) POTBL
        --                WHERE
        --                    di.order_id = p_style_color(j).po_header_id
        ----                    AND di.order_line_id = pla.po_line_id
        --                    AND di.entered_quantity IS NOT NULL
        --                    AND di.container_id = dc.container_id
        --                    AND dc.extract_status = 'Extracted';
        --  IF(ln_extract_count >0 ) THEN
        --
        --            select segment1 INTO lv_po_number from po_headers_all
        --            where po_header_id=p_style_color(j).po_header_id;
        --   lv_error_message := SUBSTR (lv_error_message||lv_po_number||' ASN is Extracted for this PO ; ', 1, 2000);
        --   lv_status := 'E';
        --  END IF;
        --   END LOOP;
        --   END IF;
        ---added CCR0009290
        IF (lv_status = 'E')
        THEN
            x_err_msg      := lv_error_message;
            x_ret_status   := 'E';
        END IF;

        IF (NVL (lv_status, 'S') <> 'E')
        THEN
            OPEN po_lines_det_cur;

            LOOP
                FETCH po_lines_det_cur BULK COLLECT INTO l_lines LIMIT 1000;

                FORALL i IN 1 .. l_lines.COUNT
                    INSERT INTO xxd_po_prc_update_details_t (action_type, file_name, batch_id, org_id, po_header_id, po_number, revision_num, po_line_id, line_num, shipment_num, style, color, conf_xf_date, quantity, unit_price, fob_cost, moq_surcharge, ship_surcharge, new_unit_price, new_fob_cost, new_moq_surcharge, new_ship_surcharge, request_id, status, error_message, creation_date, created_by, last_updated_date, last_updated_by, vendor_site_code
                                                             , brand)
                         VALUES (p_mode, l_lines (i).file_name, p_batch_id,
                                 l_lines (i).org_id, l_lines (i).po_header_id, l_lines (i).po_number, l_lines (i).header_rev_num, l_lines (i).po_line_id, l_lines (i).line_number, l_lines (i).shipment_number, l_lines (i).style, l_lines (i).color, l_lines (i).conf_xf_date, l_lines (i).quantity, l_lines (i).unit_price, l_lines (i).fob_cost, l_lines (i).global_surcharge, l_lines (i).ship_to_id_surcharge, l_lines (i).new_unit_price, l_lines (i).new_fob_cost, l_lines (i).new_moq_surcharge, l_lines (i).new_ship_surcharge, NULL, -- request id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               NULL, --status
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     NULL, -- error message
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           SYSDATE, p_user_id, SYSDATE, p_user_id, l_lines (i).vendor_site_code
                                 , l_lines (i).brand);

                EXIT WHEN po_lines_det_cur%NOTFOUND;
            END LOOP;

            CLOSE po_lines_det_cur;


            COMMIT;

            ln_request_id   :=
                apps.fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXD_PO_PRICE_UPDATE',
                    argument1     => p_batch_id);
            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   :=
                   lv_error_message
                || ' '
                || SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            x_err_msg   := 'E';
    END main;


    PROCEDURE process_price_update (x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, p_batch_id IN NUMBER)
    IS
        CURSOR get_headers IS
              SELECT po_header_id, org_id, batch_id
                FROM xxd_po_prc_update_details_t
               WHERE     1 = 1
                     AND batch_id = p_batch_id
                     AND status = 'Eligible for Auto Approve'
            GROUP BY po_header_id, org_id, batch_id
            ORDER BY org_id;

        ln_request_id                NUMBER;
        l_user_role                  VARCHAR2 (20);
        l_send_email                 VARCHAR2 (1) := 'N';


        CURSOR get_lines (p_header_id NUMBER)
        IS
              SELECT *
                FROM xxd_po_prc_update_details_t
               WHERE     1 = 1
                     AND batch_id = p_batch_id
                     AND status = 'Eligible for Auto Approve'
                     AND po_header_id = p_header_id
            ORDER BY style, color;

        --, conf_xf_date; COMMENTED 1.1
        --Start Added CCR0009290
        CURSOR c_write IS
              SELECT rpt.batch_id,
                     NVL (rpt.file_name, 'ONLINE') file_name,
                     rpt.status,
                     rpt.po_number,
                     rpt.vendor_site_code,
                     rpt.style,
                     rpt.color,
                     CASE
                         WHEN rpt.conf_xf_date IS NOT NULL
                         THEN
                             TO_CHAR (TO_DATE (rpt.conf_xf_date, 'MM/DD/RRRR'),
                                      'DD-Mon-RRRR')
                         ELSE
                             NULL
                     END conf_xf_date,
                     rpt.open_qty,
                     rpt.unit_price,
                     rpt.fob_cost,
                     rpt.global_surcharge,
                     rpt.ship_to_id_surcharge,
                     rpt.new_unit_price,
                     rpt.new_fob_cost,
                     rpt.new_global_surcharge,
                     rpt.new_ship_to_id_surcharge,
                     rpt.price_update_date,
                     rpt.price_updated_by,
                     rpt.error_message
                FROM apps.xxd_po_prc_upd_rpt_detailed_v rpt
               WHERE 1 = 1 AND rpt.batch_id = p_batch_id
            ORDER BY rpt.status DESC;

        TYPE xxd_write_type IS TABLE OF c_write%ROWTYPE;

        v_write                      xxd_write_type := xxd_write_type ();

        -- end added by CCR0009290
        l_counter                    NUMBER := 1;
        lv_error_message             VARCHAR2 (4000);
        l_org_id                     NUMBER := 0;
        l_invoice_count              NUMBER := 0;
        ln_revision_num              NUMBER;
        ln_line_num                  NUMBER;
        ln_shipment_num              NUMBER;
        l_threshold                  NUMBER;
        lv_update_po                 VARCHAR2 (1);
        ln_result                    NUMBER;
        l_request_id                 NUMBER;
        l_api_errors                 apps.po_api_errors_rec_type;
        lv_authorization_status      VARCHAR2 (400);
        l_eligible_for_autoapprove   VARCHAR2 (1);
        l_error_message              VARCHAR2 (4000);
        l_valid_count                NUMBER;
        l_unit_price_status          VARCHAR2 (1) := 'N';
        lv_error_code                VARCHAR2 (4000) := NULL;
        ln_error_num                 NUMBER;
        lv_error_msg                 VARCHAR2 (4000) := NULL;
    BEGIN
        l_request_id   := apps.fnd_global.conc_request_id;
        process_headers (p_batch_id); -- pre processing on PO to determine their eligibility status
        apps.mo_global.init ('PO');

        FOR rec_hdr IN get_headers
        LOOP
            lv_authorization_status   := NULL;

            --  update all old "sent for approval" request to discard as we have new came in for the
            -- same header id and that can go in any status : direct app or sent for approval

            IF l_counter = 1
            THEN
                l_org_id    := rec_hdr.org_id;
                apps.mo_global.set_policy_context ('S', l_org_id);
                l_counter   := l_counter + 1;
            ELSE
                IF l_org_id <> rec_hdr.org_id
                THEN
                    apps.mo_global.set_policy_context ('S', rec_hdr.org_id);
                    l_org_id   := rec_hdr.org_id;
                END IF;
            END IF;

            -- this for loop[ will be executed only for Auto Approved cases
            FOR rec_lines IN get_lines (rec_hdr.po_header_id)
            LOOP
                BEGIN
                    /*Commented by KKB on 15May21 CCR0009290
                    SELECT COUNT (apinv.invoice_num)
                      INTO l_invoice_count
                      FROM apps.po_lines_all pol,
                           apps.po_headers_all poh,
                           apps.ap_invoice_distributions_all apd,
                           apps.ap_invoices_all apinv,
                           apps.po_distributions_all pod,
                           apps.po_line_locations_all poll
                     WHERE     pol.po_line_id = poll.po_line_id
                           AND poh.po_header_id = pol.po_header_id
                           AND poll.line_location_id = pod.line_location_id
                           AND apd.invoice_id = apinv.invoice_id
                           AND pod.po_distribution_id = apd.po_distribution_id
                           AND pol.po_line_id = rec_lines.po_line_id;*/
                    --Added by KKB on 15May21 to remove unnecessary tables and conditions to improve performance CCR0009290
                    SELECT COUNT (apinv.invoice_num)
                      INTO l_invoice_count
                      FROM apps.po_line_locations_all poll, apps.po_distributions_all pod, apps.ap_invoice_distributions_all apd,
                           apps.ap_invoices_all apinv
                     WHERE     1 = 1
                           AND poll.po_line_id = rec_lines.po_line_id
                           AND poll.line_location_id = pod.line_location_id
                           AND pod.po_distribution_id =
                               apd.po_distribution_id
                           AND apd.invoice_id = apinv.invoice_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Exception in checking invoice number for PO line id'
                            || SQLERRM);
                END;

                --Entire logic to update price has to be inside this if condition
                --Process if l_invoice_count = 0
                IF l_invoice_count = 0
                THEN
                    BEGIN
                        SELECT revision_num
                          INTO ln_revision_num
                          FROM apps.po_headers_all
                         WHERE po_header_id = rec_lines.po_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_revision_num   := 1;
                    END;

                    ln_line_num       := rec_lines.line_num;
                    ln_shipment_num   := rec_lines.shipment_num;

                    ln_result         := 1;
                    lv_update_po      := 'Y';

                    BEGIN
                        SELECT 'N'
                          INTO lv_update_po
                          FROM apps.po_lines_all pol
                         WHERE     pol.po_line_id = rec_lines.po_line_id
                               AND NVL (unit_price, 0) =
                                   (NVL (rec_lines.new_moq_surcharge, 0) + NVL (rec_lines.new_ship_surcharge, 0) + rec_lines.new_fob_cost);
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
                        --Call API to update Unit Price on PO
                        ln_result   :=
                            po_change_api1_s.update_po (
                                x_po_number             => rec_lines.po_number,
                                x_release_number        => NULL,
                                x_revision_number       => ln_revision_num,
                                x_line_number           => ln_line_num,
                                x_shipment_number       => ln_shipment_num,
                                new_quantity            => NULL,
                                new_price               =>
                                    rec_lines.new_unit_price,
                                new_promised_date       => NULL,
                                new_need_by_date        => NULL,
                                launch_approvals_flag   => 'N',
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
                            l_error_message   := NULL;

                            BEGIN
                                SELECT COUNT (*)
                                  INTO l_valid_count
                                  FROM po_lines_all
                                 WHERE     po_line_id = rec_lines.po_line_id
                                       AND unit_price =
                                           rec_lines.new_unit_price;

                                -- doing this becx sometime API returning false error result code as 0 even if the base table updated succecssfully by the above API
                                IF l_valid_count <> 0
                                THEN
                                    l_unit_price_status   := 'Y';
                                    log_message (
                                        p_status       => 'Auto Approved',
                                        p_msg          => NULL,
                                        p_po_line_id   => rec_lines.po_line_id,
                                        p_batch_id     => p_batch_id,
                                        p_request_id   => l_request_id);
                                ELSE -- price is not matching even after API call
                                    FOR i IN 1 ..
                                             l_api_errors.MESSAGE_TEXT.COUNT
                                    LOOP
                                        l_error_message   :=
                                            SUBSTR (
                                                   l_error_message
                                                || l_api_errors.MESSAGE_TEXT (
                                                       i),
                                                1,
                                                3999);
                                    END LOOP;

                                    log_message (
                                        p_status       => 'Error',
                                        p_msg          => l_error_message,
                                        p_po_line_id   => rec_lines.po_line_id,
                                        p_batch_id     => p_batch_id,
                                        p_request_id   => l_request_id);
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;
                        ELSE
                            l_unit_price_status   := 'Y';
                            log_message (
                                p_status       => 'Auto Approved',
                                p_msg          => NULL,
                                p_po_line_id   => rec_lines.po_line_id,
                                p_batch_id     => p_batch_id,
                                p_request_id   => l_request_id);
                        END IF;
                    ELSE
                        l_unit_price_status   := 'Y';
                        log_message (p_status       => 'Auto Approved',
                                     p_msg          => NULL,
                                     p_po_line_id   => rec_lines.po_line_id,
                                     p_batch_id     => p_batch_id,
                                     p_request_id   => l_request_id);
                    END IF;

                    IF l_unit_price_status = 'Y'
                    THEN
                        -- UNIT PRICE GOT UPDATED; NOW UDPATE THE SURCHARGES
                        UPDATE po_lines_all
                           SET attribute_category = 'PO Data Elements', --attribute8 = NVL (rec_lines.new_moq_surcharge, 0), --Commented for 1.1
                                                                        attribute8 = rec_lines.new_moq_surcharge, --added 1.1
                                                                                                                  --attribute9 = NVL (rec_lines.new_ship_surcharge, 0), --Commented 1.1
                                                                                                                  attribute9 = rec_lines.new_ship_surcharge, --added 1.1
                               attribute11 = rec_lines.new_fob_cost
                         WHERE po_line_id = rec_lines.po_line_id;

                        BEGIN
                            -- this needs to be done only for mc1 POs(Setting Intercompany price calculation flag)
                            UPDATE po_line_locations_all
                               SET attribute6   = 'Y'
                             WHERE     po_line_id = rec_lines.po_line_id
                                   AND ship_to_organization_id =
                                       (SELECT organization_id
                                          FROM mtl_parameters
                                         WHERE organization_code = 'MC1');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;
                    END IF;
                --Added ELSE by KKB on 15May21 CCR0009290
                ELSE
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Invoice exists for PO line id: ' || rec_lines.po_line_id);
                END IF;                          -- end if l_invoice_count = 0
            END LOOP;                            --- looping on lines end here

            -- now attempt to approve the PO if the PO is in requires approval state
            lv_authorization_status   := po_status (rec_hdr.po_header_id);

            IF lv_authorization_status = 'REQUIRES REAPPROVAL'
            THEN
                lv_authorization_status   :=
                    approve_po (rec_hdr.po_header_id);
            END IF;
        END LOOP;                               --- looping on header end here

        COMMIT;
        --apps.fnd_file.put_line (apps.fnd_file.OUTPUT, 'Batch ID'||','||'File Name'||','||'Approval Status'||'PO Number'||','||'Facility Site'||','||'Style'||','||'Color'||','||'Conf. Xf Date'||','||'Quantity'||','||'Unit Price'||','|| 'New FOB Cost'||','|| 'New Global Surcharge'||','|| 'New Ship to ID Surcharge'||','|| 'Price Update Date'||','|| 'Price Updated By'||','|| 'Error Message' );
        --apps.fnd_file.put_line(apps.fnd_file.OUTPUT,'Batch ID, File Name, Approval Status, PO Number, Facility Site, Style, Color, Conf. Xf Date, Quantity, Unit Price, FOB Cost, Global Surcharge, Ship to ID Surcharge, New Unit Price, New FOB Cost, New Global Surcharge, New Ship to ID Surcharge, Price Update Date, Price Updated By, Error Message');
        --Start Adding CCR0009290
        apps.fnd_file.put_line (
            apps.fnd_file.OUTPUT,
               'Batch ID'
            || CHR (9)
            || 'File Name'
            || CHR (9)
            || 'Approval Status'
            || CHR (9)
            || 'PO Number'
            || CHR (9)
            || 'Facility Site'
            || CHR (9)
            || 'Style'
            || CHR (9)
            || 'Color'
            || CHR (9)
            || 'Conf. Xf Date'
            || CHR (9)
            || 'Quantity'
            || CHR (9)
            || 'Unit Price'
            || CHR (9)
            || 'FOB Cost'
            || CHR (9)
            || 'Global Surcharge'
            || CHR (9)
            || 'Ship to ID Surcharge'
            || CHR (9)
            || 'New Unit Price'
            || CHR (9)
            || 'New FOB Cost'
            || CHR (9)
            || 'New Global Surcharge'
            || CHR (9)
            || 'New Ship to ID Surcharge'
            || CHR (9)
            || 'Price Update Date'
            || CHR (9)
            || 'Price Updated By'
            || CHR (9)
            || 'Error Message');

        OPEN c_write;

        LOOP
            FETCH c_write BULK COLLECT INTO v_write LIMIT 1000;

            IF (v_write.COUNT > 0)
            THEN
                FOR i IN v_write.FIRST .. v_write.LAST
                LOOP
                    BEGIN
                        --apps.fnd_file.put_line(apps.fnd_file.OUTPUT,v_write(i).BATCH_ID||','||v_write(i).FILE_NAME||','||v_write(i).STATUS||','||v_write(i).PO_NUMBER||','||v_write(i).VENDOR_SITE_CODE||','||v_write(i).STYLE||','||v_write(i).COLOR||','||v_write(i).CONF_XF_DATE||','||v_write(i).OPEN_QTY||','||v_write(i).UNIT_PRICE||','||v_write(i).FOB_COST||','||v_write(i).GLOBAL_SURCHARGE||','||v_write(i).SHIP_TO_ID_SURCHARGE||','||v_write(i).NEW_UNIT_PRICE||','||v_write(i).NEW_FOB_COST||','||v_write(i).NEW_GLOBAL_SURCHARGE||','||v_write(i).NEW_SHIP_TO_ID_SURCHARGE||','||v_write(i).PRICE_UPDATE_DATE||','||'"'||v_write(i).PRICE_UPDATED_BY||'"'||','||v_write(i).ERROR_MESSAGE);
                        apps.fnd_file.put_line (
                            apps.fnd_file.OUTPUT,
                               v_write (i).BATCH_ID
                            || CHR (9)
                            || v_write (i).FILE_NAME
                            || CHR (9)
                            || v_write (i).STATUS
                            || CHR (9)
                            || v_write (i).PO_NUMBER
                            || CHR (9)
                            || v_write (i).VENDOR_SITE_CODE
                            || CHR (9)
                            || v_write (i).STYLE
                            || CHR (9)
                            || v_write (i).COLOR
                            || CHR (9)
                            || v_write (i).CONF_XF_DATE
                            || CHR (9)
                            || v_write (i).OPEN_QTY
                            || CHR (9)
                            || v_write (i).UNIT_PRICE
                            || CHR (9)
                            || v_write (i).FOB_COST
                            || CHR (9)
                            || v_write (i).GLOBAL_SURCHARGE
                            || CHR (9)
                            || v_write (i).SHIP_TO_ID_SURCHARGE
                            || CHR (9)
                            || v_write (i).NEW_UNIT_PRICE
                            || CHR (9)
                            || v_write (i).NEW_FOB_COST
                            || CHR (9)
                            || v_write (i).NEW_GLOBAL_SURCHARGE
                            || CHR (9)
                            || v_write (i).NEW_SHIP_TO_ID_SURCHARGE
                            || CHR (9)
                            || v_write (i).PRICE_UPDATE_DATE
                            || CHR (9)
                            || v_write (i).PRICE_UPDATED_BY
                            || CHR (9)
                            || v_write (i).ERROR_MESSAGE);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            apps.fnd_file.put_line (
                                apps.fnd_file.OUTPUT,
                                   ' Exception while writing into output for PO Number '
                                || v_write (i).PO_NUMBER
                                || ' '
                                || SQLERRM);
                    END;
                END LOOP;
            END IF;

            EXIT WHEN c_write%NOTFOUND;
        END LOOP;

        CLOSE c_write;
    --End Adding CCR0009290
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   :=
                   lv_error_message
                || ' '
                || SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            x_err_msg   := lv_error_message;
            ROLLBACK;
    END process_price_update;

    -- this is called by approve;
    PROCEDURE approver_action (x_ret_status OUT NOCOPY VARCHAR2, x_err_msg OUT NOCOPY VARCHAR2, p_batch_id IN VARCHAR2
                               , p_po_header_id IN VARCHAR2)
    IS
        CURSOR get_headers IS
              SELECT po_header_id, org_id, batch_id
                FROM xxd_po_prc_update_details_t
               WHERE     1 = 1
                     AND status = 'Approval in Progress'
                     AND batch_id IN (    SELECT TRIM (REGEXP_SUBSTR (str, '[^,]+', 1
                                                                      , LEVEL)) str
                                            FROM (SELECT p_batch_id str FROM DUAL)
                                      CONNECT BY INSTR (str, ',', 1,
                                                        LEVEL - 1) > 0)
                     AND po_header_id IN
                             (    SELECT TRIM (REGEXP_SUBSTR (str, '[^,]+', 1
                                                              , LEVEL)) str
                                    FROM (SELECT p_po_header_id str FROM DUAL)
                              CONNECT BY INSTR (str, ',', 1,
                                                LEVEL - 1) > 0)
            GROUP BY po_header_id, org_id, batch_id
            ORDER BY org_id;

        CURSOR get_lines (p_header_id NUMBER)
        IS
            SELECT *
              FROM xxd_po_prc_update_details_t
             WHERE     1 = 1
                   AND status = 'Approval in Progress'
                   AND batch_id IN (    SELECT TRIM (REGEXP_SUBSTR (str, '[^,]+', 1
                                                                    , LEVEL)) str
                                          FROM (SELECT p_batch_id str FROM DUAL)
                                    CONNECT BY INSTR (str, ',', 1,
                                                      LEVEL - 1) > 0)
                   AND po_header_id = p_header_id;

        l_counter                    NUMBER := 1;
        lv_error_message             VARCHAR2 (4000);
        l_org_id                     NUMBER := 0;
        l_invoice_count              NUMBER := 0;
        ln_revision_num              NUMBER;
        ln_line_num                  NUMBER;
        ln_shipment_num              NUMBER;
        l_threshold                  NUMBER;
        lv_update_po                 VARCHAR2 (1);
        ln_result                    NUMBER;
        l_request_id                 NUMBER;
        l_api_errors                 apps.po_api_errors_rec_type;
        lv_authorization_status      VARCHAR2 (400);
        l_eligible_for_autoapprove   VARCHAR2 (1);
        l_error_message              VARCHAR2 (4000);
        l_valid_count                NUMBER;
        l_unit_price_status          VARCHAR2 (1) := 'N';
        l_send_email                 VARCHAR2 (1) := 'N';
    BEGIN
        l_request_id   := apps.fnd_global.conc_request_id;
        apps.mo_global.init ('PO');

        FOR rec_hdr IN get_headers
        LOOP
            lv_authorization_status   := NULL;

            IF l_counter = 1
            THEN
                l_org_id    := rec_hdr.org_id;
                apps.mo_global.set_policy_context ('S', l_org_id);
                l_counter   := l_counter + 1;
            ELSE
                IF l_org_id <> rec_hdr.org_id
                THEN
                    apps.mo_global.set_policy_context ('S', rec_hdr.org_id);
                    l_org_id   := rec_hdr.org_id;
                END IF;
            END IF;

            -- this for loop[ will be executed only for Auto Approved cases
            FOR rec_lines IN get_lines (rec_hdr.po_header_id)
            LOOP
                BEGIN
                    SELECT COUNT (apinv.invoice_num)
                      INTO l_invoice_count
                      FROM apps.po_lines_all pol, apps.po_headers_all poh, apps.ap_invoice_distributions_all apd,
                           apps.ap_invoices_all apinv, apps.po_distributions_all pod, apps.po_line_locations_all poll
                     WHERE     pol.po_line_id = poll.po_line_id
                           AND poh.po_header_id = pol.po_header_id
                           AND poll.line_location_id = pod.line_location_id
                           AND apd.invoice_id = apinv.invoice_id
                           AND pod.po_distribution_id =
                               apd.po_distribution_id
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
                    -- entire logic to update price has to be inside this if condition
                    BEGIN
                        SELECT revision_num
                          INTO ln_revision_num
                          FROM apps.po_headers_all
                         WHERE po_header_id = rec_lines.po_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_revision_num   := 1;
                    END;

                    ln_line_num       := rec_lines.line_num;
                    ln_shipment_num   := rec_lines.shipment_num;

                    ln_result         := 1;
                    lv_update_po      := 'Y';

                    BEGIN
                        SELECT 'N'
                          INTO lv_update_po
                          FROM apps.po_lines_all pol
                         WHERE     pol.po_line_id = rec_lines.po_line_id
                               AND NVL (unit_price, 0) =
                                   (NVL (rec_lines.new_moq_surcharge, 0) + NVL (rec_lines.new_ship_surcharge, 0) + rec_lines.new_fob_cost);
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
                        ln_result   :=
                            po_change_api1_s.update_po (
                                x_po_number             => rec_lines.po_number,
                                x_release_number        => NULL,
                                x_revision_number       => ln_revision_num,
                                x_line_number           => ln_line_num,
                                x_shipment_number       => ln_shipment_num,
                                new_quantity            => NULL,
                                new_price               =>
                                    rec_lines.new_unit_price,
                                new_promised_date       => NULL,
                                new_need_by_date        => NULL,
                                launch_approvals_flag   => 'N',
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
                            l_error_message   := NULL;

                            SELECT COUNT (*)
                              INTO l_valid_count
                              FROM po_lines_all
                             WHERE     po_line_id = rec_lines.po_line_id
                                   AND unit_price = rec_lines.new_unit_price;

                            -- doing this becx sometime API returning false error result code as 0 even if the base table updated succecssfully by the above API
                            IF l_valid_count <> 0
                            THEN
                                l_unit_price_status   := 'Y';
                                log_message (
                                    p_status       => 'Manager Approved',
                                    p_msg          => NULL,
                                    p_po_line_id   => rec_lines.po_line_id,
                                    p_batch_id     => p_batch_id,
                                    p_request_id   => l_request_id);
                            ELSE  -- price is not matching even after API call
                                FOR i IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                                LOOP
                                    l_error_message   :=
                                        SUBSTR (
                                            l_error_message || l_api_errors.MESSAGE_TEXT (i),
                                            1,
                                            3999);
                                END LOOP;

                                log_message (
                                    p_status       => 'Error',
                                    p_msg          => l_error_message,
                                    p_po_line_id   => rec_lines.po_line_id,
                                    p_batch_id     => p_batch_id,
                                    p_request_id   => l_request_id);
                            END IF;
                        ELSE
                            l_unit_price_status   := 'Y';
                            log_message (
                                p_status       => 'Manager Approved',
                                p_msg          => NULL,
                                p_po_line_id   => rec_lines.po_line_id,
                                p_batch_id     => rec_lines.batch_id,
                                p_request_id   => l_request_id);
                        END IF;
                    ELSE
                        log_message (
                            p_status       => 'Unprocessed',
                            p_msg          => 'PO Line amount is upto date.',
                            p_po_line_id   => rec_lines.po_line_id,
                            p_batch_id     => rec_lines.batch_id,
                            p_request_id   => l_request_id);
                    END IF;

                    IF l_unit_price_status = 'Y'
                    THEN
                        -- UNIT PRICE GOT UPDATED; NOW UDPATE THE SURCHARGES
                        UPDATE po_lines_all
                           SET attribute_category = 'PO Data Elements', attribute8 = NVL (rec_lines.new_moq_surcharge, 0), attribute9 = NVL (rec_lines.new_ship_surcharge, 0),
                               attribute11 = rec_lines.new_fob_cost
                         WHERE po_line_id = rec_lines.po_line_id;

                        BEGIN
                            -- this needs to be done only for mc1 POs
                            -- this needs to be done only for mc1 POs
                            UPDATE po_line_locations_all
                               SET attribute6   = 'Y'
                             WHERE     po_line_id = rec_lines.po_line_id
                                   AND ship_to_organization_id =
                                       (SELECT organization_id
                                          FROM MTL_PARAMETERS
                                         WHERE organization_code = 'MC1');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;
                    END IF;
                END IF;                          -- end if l_invoice_count = 0
            END LOOP;                            --- looping on lines end here

            -- now attempt to approve the PO if the PO is in requires approval state
            lv_authorization_status   := po_status (rec_hdr.po_header_id);

            IF lv_authorization_status = 'REQUIRES REAPPROVAL'
            THEN
                lv_authorization_status   :=
                    approve_po (rec_hdr.po_header_id);
            END IF;

            IF (lv_authorization_status = 'APPROVED')
            THEN
                l_send_email   := 'Y';
            --  send_email ('Approved', rec_hdr.batch_id, rec_hdr.po_header_id); -- send FYI to the requester
            END IF;
        END LOOP;                               --- looping on header end here

        IF l_send_email = 'Y'
        THEN
            send_email ('Approved', p_batch_id, p_po_header_id);
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   :=
                   lv_error_message
                || ' '
                || SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            x_err_msg   := lv_error_message;
            ROLLBACK;
    END approver_action;

    PROCEDURE submit_for_approval (p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_user_id IN NUMBER, p_action IN VARCHAR2, p_batch_hdr IN xxdo.xxd_po_batch_hdr_tbl_typ, x_ret_status OUT NOCOPY VARCHAR2
                                   , x_err_msg OUT NOCOPY VARCHAR2)
    IS
        l_counter                 NUMBER := 1;
        lv_error_message          VARCHAR2 (4000);
        l_org_id                  NUMBER := 0;
        l_invoice_count           NUMBER := 0;
        ln_revision_num           NUMBER;
        ln_line_num               NUMBER;
        ln_shipment_num           NUMBER;
        l_threshold               NUMBER;
        lv_update_po              VARCHAR2 (1);
        ln_result                 NUMBER;
        l_request_id              NUMBER;
        l_api_errors              apps.po_api_errors_rec_type;
        lv_authorization_status   VARCHAR2 (400);
        l_batch_id                VARCHAR2 (4000);
        l_po_header_id            VARCHAR2 (4000);
    BEGIN
        SELECT LISTAGG (batch_id, ',') WITHIN GROUP (ORDER BY batch_id), LISTAGG (po_header_id, ',') WITHIN GROUP (ORDER BY po_header_id)
          INTO l_batch_id, l_po_header_id
          FROM (SELECT batch_id, po_header_id FROM TABLE (p_batch_hdr));

        IF p_action = 'REJECT'
        THEN
            UPDATE xxd_po_prc_update_details_t a
               SET status = 'Rejected', last_updated_by = fnd_global.user_id --Added by KKB on 15May21 CCR0009290
                                                                            , last_updated_date = SYSDATE --Added by KKB on 15May21 CCR0009290
             WHERE     status = 'Sent for Approval'
                   AND (batch_id, po_header_id) IN
                           (SELECT batch_id, po_header_id FROM TABLE (p_batch_hdr));

            send_email ('Rejected', l_batch_id, l_po_header_id); -- send FYI to the requesters that their PO Amount changes hasve been discarded by the manager
        ELSIF p_action = 'APPROVE'
        THEN
            UPDATE xxd_po_prc_update_details_t a
               SET status = 'Approval in Progress', last_updated_by = fnd_global.user_id --Added by KKB on 15May21 CCR0009290
                                                                                        , last_updated_date = SYSDATE --Added by KKB on 15May21 CCR0009290
             WHERE     status = 'Sent for Approval'
                   AND (batch_id, po_header_id) IN
                           (SELECT batch_id, po_header_id FROM TABLE (p_batch_hdr));
        END IF;

        COMMIT;

        IF p_action = 'APPROVE'
        THEN
            l_request_id   :=
                apps.fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXD_PO_PRICE_APPROVAL',
                    argument1     => l_batch_id,
                    argument2     => l_po_header_id);
            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   :=
                   lv_error_message
                || ' '
                || SUBSTR (lv_error_message || '.' || SQLERRM, 1, 2000);
            x_err_msg   := lv_error_message;
            ROLLBACK;
    END submit_for_approval;

    FUNCTION approve_po (pn_header_id NUMBER)
        RETURN VARCHAR2
    IS
        ln_loop_cnt               NUMBER := 0;
        lv_approved_flag          VARCHAR2 (10);
        lv_authorization_status   VARCHAR2 (100);
        v_item_key                VARCHAR2 (100);
        x_error_text              VARCHAR2 (1000);
        x_ret_stat                VARCHAR2 (1000);
        l_agent_id                NUMBER;
        l_po_number               VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT agent_id, segment1
              INTO l_agent_id, l_po_number
              FROM po_headers_all
             WHERE po_header_id = pn_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        SELECT TO_CHAR (pn_header_id) || '-' || TO_CHAR (po_wf_itemkey_s.NEXTVAL)
          INTO v_item_key
          FROM DUAL;

        ln_loop_cnt               := ln_loop_cnt + 1;

        BEGIN
            apps.po_reqapproval_init1.start_wf_process (
                itemtype                => 'POAPPRV',
                itemkey                 => v_item_key,
                workflowprocess         => 'POAPPRV_TOP',
                actionoriginatedfrom    => 'PO_FORM',
                documentid              => pn_header_id,
                documentnumber          => l_po_number,
                preparerid              => l_agent_id,
                documenttypecode        => 'PO',
                documentsubtype         => 'STANDARD',
                submitteraction         => 'APPROVE',          --''INCOMPLETE'
                forwardtoid             => NULL,           --null-- EMPLOYEEID
                forwardfromid           => l_agent_id,
                defaultapprovalpathid   => NULL,
                note                    => NULL,
                printflag               => 'N');
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        COMMIT;

        lv_authorization_status   := po_status (pn_header_id);

        RETURN lv_authorization_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;

            apps.fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in PO Approval '
                || l_po_number
                || ': Error Code: '
                || SQLCODE
                || 'Error Message: '
                || SUBSTR (SQLERRM, 1, 900));
    END approve_po;

    FUNCTION style_color_status (pn_header_id         IN NUMBER,
                                 p_style              IN VARCHAR2,
                                 p_color              IN VARCHAR2,
                                 p_factory_date          VARCHAR2,
                                 p_vendor_site_code   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_authorization_status   VARCHAR2 (100);
    BEGIN
        SELECT 'Yes'
          INTO lv_authorization_status
          FROM apps.xxd_po_prc_update_details_t a
         WHERE     1 = 1
               AND a.po_header_id = pn_header_id
               AND style = p_style
               AND color = p_color
               AND vendor_site_code = p_vendor_site_code
               AND status = 'Sent for Approval'
               AND batch_id = (SELECT MAX (batch_id)
                                 FROM xxd_po_prc_update_details_t b
                                WHERE b.po_header_id = pn_header_id)
               AND ROWNUM = 1;

        RETURN lv_authorization_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'No';
            apps.fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in PO Status Function: Error Code: '
                || SQLCODE
                || 'Error Message: '
                || SUBSTR (SQLERRM, 1, 900));
    END style_color_status;

    FUNCTION po_status (pn_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_authorization_status   VARCHAR2 (100);
    BEGIN
        SELECT authorization_status
          INTO lv_authorization_status
          FROM apps.po_headers_all pha
         WHERE 1 = 1 AND pha.po_header_id = pn_header_id;

        RETURN lv_authorization_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
            apps.fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in PO Status Function: Error Code: '
                || SQLCODE
                || 'Error Message: '
                || SUBSTR (SQLERRM, 1, 900));
    END po_status;
END xxd_po_prc_modify_pkg;
/
