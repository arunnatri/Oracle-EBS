--
-- XXD_ONT_EDI_VALIDATION_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_EDI_VALIDATION_PKG"
AS
    /********************************************************************************************
     * Package         : XXD_ONT_EDI_VALIDATION_PKG
     * Description     : This package is used for EDI Prevalidation
     * Notes           :
     * Modification    :
     *-------------------------------------------------------------------------------------------
     * Date          Version#    Name                   Description
     *-------------------------------------------------------------------------------------------
     * 08-JUL-2020   1.0         Aravind Kannuri        Initial Version
     * 12-FEB-2021   1.1         Aravind Kannuri        Modified for CCR0009192
     * 22-Mar-2021   1.2         Viswanathan Pandian    Modified for CCR0009265
     * 01-Sep-2021   1.3         Shivanshu Talwar       Modified for CCR0009525
     * 23-Sep-2021   1.4         Aravind Kannuri        Modified for CCR0009616
     *******************************************************************************************/

    --Global Variables Declaration
    gn_user_id      NUMBER := fnd_global.user_id;
    gn_login_id     NUMBER := fnd_global.login_id;
    gn_request_id   NUMBER := fnd_global.conc_request_id;
    gd_sysdate      DATE := SYSDATE;
    gc_delimiter    VARCHAR2 (1000);

    /********************************************************************************************
    Staging Table Statuses
    N - New
    I - Ignore
    X - SOA populated
    V - Valid
    E - Error
    P - Processed
    ********************************************************************************************/

    -- ======================================================================================
    -- This procedure prints the Debug Messages in Concurrent Log
    -- ======================================================================================
    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, gc_delimiter || p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Others Exception in DEBUG_MSG = ' || SQLERRM);
    END debug_msg;

    -------------------------------------------------------------
    --Procedure to Reprocess the staging data
    -------------------------------------------------------------
    PROCEDURE reprocess_data (p_operating_unit   IN NUMBER,
                              p_osid             IN NUMBER,
                              p_cust_po_num         VARCHAR2)
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start REPROCESS_DATA');

        --Rest header records
        UPDATE xxd_ont_oe_lines_iface_stg_t xool
           SET xool.tp_attribute4 = NULL, xool.tp_attribute6 = NULL, xool.request_id = NULL
         WHERE     1 = 1
               AND xool.tp_attribute6 = 'SOA-REFERENCE'
               AND xool.tp_attribute4 = 'E'
               AND xool.customer_po_number =
                   NVL (p_cust_po_num, xool.customer_po_number)
               AND xool.org_id = p_operating_unit
               AND xool.order_source_id = p_osid
               AND EXISTS
                       (SELECT 1
                          FROM xxd_ont_oe_headers_iface_stg_t xooh
                         WHERE     xooh.sold_to_org_id = xool.sold_to_org_id
                               AND xooh.customer_po_number =
                                   xool.customer_po_number
                               AND xooh.org_id = xool.org_id
                               AND xooh.tp_attribute4 = 'E'
                               AND xooh.tp_attribute6 = 'SOA-REFERENCE');

        UPDATE xxd_ont_oe_headers_iface_stg_t
           SET tp_attribute4 = NULL, tp_attribute5 = NULL, request_id = NULL
         WHERE     1 = 1
               AND tp_attribute6 = 'SOA-REFERENCE'
               AND tp_attribute4 = 'E'
               AND customer_po_number =
                   NVL (p_cust_po_num, customer_po_number)
               AND org_id = p_operating_unit
               AND order_source_id = p_osid;

        debug_msg ('End REPROCESS_DATA');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in REPROCESS_DATA' || SQLERRM);
    END reprocess_data;

    -------------------------------------------------------------
    --Procedure to Update Staging data status for SOA reference
    -------------------------------------------------------------
    PROCEDURE update_staging_status (p_operating_unit IN NUMBER, p_osid IN NUMBER, p_cust_po_num IN VARCHAR2)
    IS
        --Cursor to Derive Header data in Staging table
        CURSOR c_soa_hdr IS
              SELECT xooh.*
                FROM xxd_ont_oe_headers_iface_stg_t xooh
               WHERE     1 = 1
                     AND xooh.customer_po_number =
                         NVL (p_cust_po_num, xooh.customer_po_number)
                     AND xooh.org_id = p_operating_unit
                     AND xooh.order_source_id = p_osid
                     AND xooh.tp_attribute4 = 'X'
            ORDER BY TO_NUMBER (xooh.tp_attribute1);

        -- Variables Declaration
        ln_exists          NUMBER := 0;
        ln_request_id      NUMBER;
        lc_status          VARCHAR2 (1);
        lc_error_message   VARCHAR2 (4000);
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start UPDATE_STAGING_STATUS');

        --Update header records as Q if it alreadys exists in iface
        UPDATE xxd_ont_oe_headers_iface_stg_t xooh
           SET xooh.tp_attribute4 = 'Q', xooh.request_id = gn_request_id
         WHERE     1 = 1
               AND EXISTS
                       (SELECT 1
                          FROM oe_headers_iface_all ohia
                         WHERE     ohia.sold_to_org_id = xooh.sold_to_org_id
                               AND ohia.customer_po_number =
                                   xooh.customer_po_number
                               AND ohia.org_id = xooh.org_id
                               AND ohia.global_attribute1 =
                                   xooh.global_attribute1)
               AND xooh.tp_attribute4 IS NULL;

        --Update header records as Q if it alreadys exists in header
        UPDATE xxd_ont_oe_headers_iface_stg_t xooh
           SET xooh.tp_attribute4 = 'Q', xooh.request_id = gn_request_id
         WHERE     1 = 1
               AND ROWID NOT IN
                       (SELECT MIN (ROWID)
                          FROM xxd_ont_oe_headers_iface_stg_t xooh_1
                         WHERE     xooh_1.sold_to_org_id =
                                   xooh.sold_to_org_id
                               AND xooh_1.customer_po_number =
                                   xooh.customer_po_number
                               AND xooh_1.org_id = xooh.org_id
                               AND xooh.tp_attribute4 IS NULL
                               AND xooh_1.global_attribute1 =
                                   xooh.global_attribute1)
               AND xooh.tp_attribute4 IS NULL;

        --Update lines records as Q if it alreadys exists in iface
        UPDATE xxd_ont_oe_lines_iface_stg_t xool
           SET xool.tp_attribute4 = 'Q', xool.request_id = gn_request_id
         WHERE     1 = 1
               AND EXISTS
                       (SELECT 1
                          FROM xxd_ont_oe_headers_iface_stg_t xooh
                         WHERE     xooh.sold_to_org_id = xool.sold_to_org_id
                               AND xooh.customer_po_number =
                                   xool.customer_po_number
                               AND xooh.org_id = xool.org_id
                               AND xooh.tp_attribute1 = xool.tp_attribute1
                               AND xooh.tp_attribute4 = 'Q')
               AND xool.tp_attribute4 IS NULL;

        --Update Q header records to process if it is old run record
        UPDATE xxd_ont_oe_headers_iface_stg_t xooh
           SET xooh.tp_attribute4 = NULL, xooh.request_id = NULL
         WHERE     1 = 1
               AND xooh.tp_attribute4 = 'Q'
               AND NVL (xooh.request_id, -99) <> gn_request_id
               AND xooh.tp_attribute1 =
                   (SELECT MIN (xooh_1.tp_attribute1)
                      FROM xxd_ont_oe_headers_iface_stg_t xooh_1
                     WHERE     xooh_1.sold_to_org_id = xooh.sold_to_org_id
                           AND xooh_1.customer_po_number =
                               xooh.customer_po_number
                           AND xooh_1.org_id = xooh.org_id
                           AND xooh_1.tp_attribute4 = 'Q'
                           AND xooh_1.global_attribute1 =
                               xooh.global_attribute1)
               AND NOT EXISTS
                       (SELECT 1
                          FROM oe_headers_iface_all ohia
                         WHERE     ohia.sold_to_org_id = xooh.sold_to_org_id
                               AND ohia.customer_po_number =
                                   xooh.customer_po_number
                               AND ohia.org_id = xooh.org_id
                               AND ohia.global_attribute1 =
                                   xooh.global_attribute1);

        --Update Q line records to process if it is old run record
        UPDATE xxd_ont_oe_lines_iface_stg_t xool
           SET xool.tp_attribute4 = NULL, xool.request_id = NULL
         WHERE     1 = 1
               AND tp_attribute4 = 'Q'
               AND NVL (request_id, -99) <> gn_request_id
               AND EXISTS
                       (SELECT 1
                          FROM xxd_ont_oe_headers_iface_stg_t xooh
                         WHERE     xooh.sold_to_org_id = xool.sold_to_org_id
                               AND xooh.customer_po_number =
                                   xool.customer_po_number
                               AND xooh.org_id = xool.org_id
                               AND xooh.tp_attribute1 = xool.tp_attribute1
                               AND xooh.tp_attribute4 IS NULL);

        --Update Invalid Change Code
        UPDATE xxd_ont_oe_lines_iface_stg_t
           SET tp_attribute4 = 'E', tp_attribute5 = 'Invalid Change Codes', request_id = gn_request_id
         WHERE     1 = 1
               AND customer_po_number =
                   NVL (p_cust_po_num, customer_po_number)
               AND org_id = p_operating_unit
               AND order_source_id = p_osid
               AND NVL (tp_attribute4, 'N') = 'N'
               AND NVL (tp_attribute2, 'CT') NOT IN ('AI', 'CA', 'CE',
                                                     'CT', 'DI', 'NCH',
                                                     'PC', 'PQ', 'QD',
                                                     'QI', 'RQ', 'RZ');

        --Update Header Staging Table for SOA Reference
        UPDATE xxd_ont_oe_headers_iface_stg_t
           SET tp_attribute4 = 'X', tp_attribute6 = 'SOA-REFERENCE', last_updated_by = gn_user_id,
               last_update_date = SYSDATE, last_update_login = gn_login_id, request_id = gn_request_id
         WHERE     1 = 1
               AND customer_po_number =
                   NVL (p_cust_po_num, customer_po_number)
               AND org_id = p_operating_unit
               AND order_source_id = p_osid
               AND tp_attribute4 IS NULL
               AND tp_attribute5 IS NULL;

        debug_msg ('Header staging update count = ' || SQL%ROWCOUNT);

        --Update Line Staging Table for SOA Reference
        UPDATE xxd_ont_oe_lines_iface_stg_t
           SET tp_attribute4 = 'X', tp_attribute6 = 'SOA-REFERENCE', last_updated_by = gn_user_id,
               last_update_date = SYSDATE, last_update_login = gn_login_id, request_id = gn_request_id
         WHERE     1 = 1
               AND customer_po_number =
                   NVL (p_cust_po_num, customer_po_number)
               AND org_id = p_operating_unit
               AND order_source_id = p_osid
               AND tp_attribute1 IS NOT NULL
               AND tp_attribute4 IS NULL
               AND tp_attribute5 IS NULL;

        debug_msg ('Line staging update count = ' || SQL%ROWCOUNT);

        --Validate SOA Records with Base Table
        FOR r_soa_hdr IN c_soa_hdr
        LOOP
            debug_msg ('Validating Seq Num: ' || r_soa_hdr.tp_attribute1);

            SELECT COUNT (1)
              INTO ln_exists
              FROM oe_order_headers_all ooha
             WHERE     1 = 1
                   AND ooha.open_flag = 'Y'
                   AND ooha.booked_flag = 'Y'
                   AND ooha.org_id = r_soa_hdr.org_id
                   AND ooha.cust_po_number = r_soa_hdr.customer_po_number
                   AND ooha.sold_to_org_id = r_soa_hdr.sold_to_org_id
                   AND ((r_soa_hdr.global_attribute1 = 'BK' AND ooha.global_attribute1 = r_soa_hdr.global_attribute1) OR (r_soa_hdr.global_attribute1 <> 'BK' AND NVL (ooha.global_attribute1, r_soa_hdr.global_attribute1) = r_soa_hdr.global_attribute1) OR (NVL (r_soa_hdr.global_attribute1, 'X') = NVL (NVL (ooha.global_attribute1, r_soa_hdr.global_attribute1), 'X')))
                   AND NOT EXISTS                       --Start as part of 1.3
                           (SELECT 1
                              FROM oe_transaction_types_tl ot, fnd_lookup_values_vl flv
                             WHERE     ot.name = flv.meaning
                                   AND flv.lookup_type =
                                       'XXD_EDI_EXCL_ORDER_TYPE'
                                   AND ot.language = 'US'
                                   AND SYSDATE BETWEEN NVL (
                                                           flv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           SYSDATE + 1)
                                   AND flv.enabled_flag = 'Y'
                                   AND ot.transaction_type_id =
                                       ooha.order_type_id);

            --End as part of 1.3

            IF ln_exists > 1
            THEN
                lc_error_message   := 'Duplicate Customer PO Number';
                ln_request_id      := 40;
                lc_status          := 'E';
                debug_msg ('Error: ' || lc_error_message);
            ELSIF ln_exists = 0
            THEN
                lc_error_message   := 'No Open PO Exists';
                ln_request_id      := 41;
                lc_status          := 'E';
                debug_msg ('Error: ' || lc_error_message);
            ELSE
                lc_error_message   := NULL;
                ln_request_id      := gn_request_id;
                lc_status          := 'X';

                BEGIN
                    -- Update OSDR separetley to avoid duplicate data error
                    UPDATE xxd_ont_oe_headers_iface_stg_t xooh
                       SET orig_sys_document_ref   =
                               (SELECT ooha.orig_sys_document_ref
                                  FROM oe_order_headers_all ooha
                                 WHERE     1 = 1
                                       AND ooha.open_flag = 'Y'
                                       AND ooha.booked_flag = 'Y'
                                       AND ooha.org_id = r_soa_hdr.org_id
                                       AND ooha.cust_po_number =
                                           r_soa_hdr.customer_po_number
                                       AND ooha.sold_to_org_id =
                                           r_soa_hdr.sold_to_org_id
                                       AND ((r_soa_hdr.global_attribute1 = 'BK' AND ooha.global_attribute1 = r_soa_hdr.global_attribute1) OR (r_soa_hdr.global_attribute1 <> 'BK' AND NVL (ooha.global_attribute1, r_soa_hdr.global_attribute1) = r_soa_hdr.global_attribute1) OR (NVL (r_soa_hdr.global_attribute1, 'X') = NVL (NVL (ooha.global_attribute1, r_soa_hdr.global_attribute1), 'X'))))
                     WHERE     1 = 1
                           AND xooh.tp_attribute1 = r_soa_hdr.tp_attribute1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_error_message   := SUBSTR (SQLERRM, 1, 500);
                        lc_status          := 'E';
                END;

                debug_msg (
                    'Updated OSDR in Header Staging Count = ' || SQL%ROWCOUNT);
            END IF;

            --Update header status
            UPDATE xxd_ont_oe_headers_iface_stg_t
               SET tp_attribute4 = lc_status, tp_attribute5 = lc_error_message, request_id = ln_request_id
             WHERE     1 = 1
                   AND customer_po_number = r_soa_hdr.customer_po_number
                   AND org_id = r_soa_hdr.org_id
                   AND sold_to_org_id = r_soa_hdr.sold_to_org_id
                   AND tp_attribute4 = 'X'
                   AND tp_attribute1 = r_soa_hdr.tp_attribute1;

            --Update line status
            UPDATE xxd_ont_oe_lines_iface_stg_t xool
               SET tp_attribute4   = lc_status,
                   tp_attribute5   = lc_error_message,
                   request_id      = ln_request_id,
                   orig_sys_document_ref   =
                       (SELECT orig_sys_document_ref
                          FROM xxd_ont_oe_headers_iface_stg_t xooh
                         WHERE     xool.tp_attribute1 = xooh.tp_attribute1
                               AND tp_attribute4 = 'X')
             WHERE     1 = 1
                   AND customer_po_number = r_soa_hdr.customer_po_number
                   AND org_id = r_soa_hdr.org_id
                   AND sold_to_org_id = r_soa_hdr.sold_to_org_id
                   AND tp_attribute4 = 'X'
                   AND tp_attribute1 = r_soa_hdr.tp_attribute1;
        END LOOP;

        debug_msg ('End UPDATE_STAGING_STATUS');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in UPDATE_STAGING_STATUS' || SQLERRM);
    END update_staging_status;

    -- Start changes for CCR0009616
    -----------------------------------------------
    --Procedure to Apply Header Ship-To-Org for 860
    -----------------------------------------------
    PROCEDURE apply_hdr_ship_to (p_operating_unit IN NUMBER, p_osid IN NUMBER, p_cust_po_num IN VARCHAR2)
    IS
        lv_apply_hdr_chk   VARCHAR2 (1) := 'N';
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start APPLY_HDR_SHIP_TO');

        FOR c_rec
            IN (SELECT DISTINCT xooh.orig_sys_document_ref osdr, xooh.sold_to_org_id, ooha.ship_to_org_id
                  FROM oe_order_headers_all ooha, xxd_ont_oe_headers_iface_stg_t xooh
                 WHERE     1 = 1
                       AND ooha.orig_sys_document_ref =
                           xooh.orig_sys_document_ref
                       AND ooha.org_id = p_operating_unit
                       AND ooha.order_source_id = p_osid
                       AND xooh.request_id = gn_request_id
                       AND xooh.tp_attribute4 = 'X')
        LOOP
            BEGIN
                SELECT flv.attribute5
                  INTO lv_apply_hdr_chk
                  FROM fnd_lookup_values flv
                 WHERE     flv.lookup_type = 'XXDO_EDI_CUSTOMERS'
                       AND flv.language = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND lookup_code =
                           (SELECT account_number
                              FROM hz_cust_accounts
                             WHERE     status = 'A'
                                   AND cust_account_id = c_rec.sold_to_org_id)
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       flv.start_date_active,
                                                       TRUNC (SYSDATE))
                                               AND NVL (flv.end_date_active,
                                                        TRUNC (SYSDATE) + 1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_apply_hdr_chk   := NULL;
            END;

            debug_msg (
                'apply_hdr_ship_to_chk :' || NVL (lv_apply_hdr_chk, 'N'));

            IF NVL (lv_apply_hdr_chk, 'N') = 'Y'
            THEN
                --Update Ship to Org in Header Stg Iface for 860
                UPDATE xxd_ont_oe_lines_iface_stg_t xool
                   SET xool.ship_to_org_id   = c_rec.ship_to_org_id
                 WHERE     1 = 1
                       AND xool.tp_attribute4 = 'X'
                       AND xool.orig_sys_document_ref = c_rec.osdr
                       AND xool.org_id = p_operating_unit
                       AND xool.order_source_id = p_osid
                       AND EXISTS
                               (SELECT 1
                                  FROM xxd_ont_oe_headers_iface_stg_t xooh
                                 WHERE     1 = 1
                                       AND xooh.orig_sys_document_ref =
                                           xool.orig_sys_document_ref
                                       AND xooh.tp_attribute1 =
                                           xool.tp_attribute1
                                       AND xooh.org_id = xool.org_id
                                       AND xooh.request_id = gn_request_id
                                       AND xooh.tp_attribute4 = 'X');

                --Update Ship to Org in Line Stg
                UPDATE xxd_ont_oe_headers_iface_stg_t
                   SET ship_to_org_id   = c_rec.ship_to_org_id
                 WHERE     1 = 1
                       AND orig_sys_document_ref = c_rec.osdr
                       AND org_id = p_operating_unit
                       AND order_source_id = p_osid
                       AND request_id = gn_request_id
                       AND tp_attribute4 = 'X';
            END IF;
        END LOOP;

        debug_msg ('End APPLY_HDR_SHIP_TO ');
        debug_msg ((RPAD ('=', 100, '=')));
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in APPLY_HDR_SHIP_TO' || SQLERRM);
    END apply_hdr_ship_to;

    -- End changes for CCR0009616

    -------------------------------------------------------------
    --Procedure to Insert Staging data based on table data
    -------------------------------------------------------------
    PROCEDURE insert_staging_data (p_operating_unit IN NUMBER, p_osid IN NUMBER, p_cust_po_num IN VARCHAR2)
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start INSERT_STAGING_DATA');

        INSERT INTO xxd_ont_oe_headers_iface_stg_t (order_source_id, org_id, customer_po_number, cancelled_flag, ship_to_org_id, sold_from_org_id, request_date, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, orig_sys_document_ref, order_number, ordered_date, order_type_id, shipping_method_code, transactional_curr_code, sold_to_org_id, customer_id, created_by, creation_date, last_updated_by, last_update_date, last_update_login, request_id, operation_code, force_apply_flag, change_reason, change_sequence, tp_attribute1, tp_attribute2, tp_attribute4
                                                    , global_attribute1)
            SELECT ooha.order_source_id,
                   ooha.org_id,
                   ooha.cust_po_number
                       customer_po_number,
                   NVL (xooh.cancelled_flag, ooha.cancelled_flag),
                   ooha.ship_to_org_id,
                   ooha.sold_from_org_id,
                   CASE
                       WHEN     xooh.request_date IS NOT NULL
                            AND xooh.request_date <> ooha.request_date
                       THEN
                           xooh.request_date
                       WHEN    xooh.request_date IS NULL
                            OR xooh.request_date = ooha.request_date
                       THEN
                           ooha.request_date
                   END,
                   CASE
                       WHEN     xooh.attribute1 IS NOT NULL
                            AND xooh.attribute1 <> ooha.attribute1
                       THEN
                           xooh.attribute1
                       WHEN    xooh.attribute1 IS NULL
                            OR xooh.attribute1 = ooha.attribute1
                       THEN
                           ooha.attribute1
                   END,
                   ooha.attribute2,
                   ooha.attribute3,
                   ooha.attribute4,
                   ooha.attribute5,
                   ooha.attribute6,
                   ooha.attribute7,
                   ooha.attribute8,
                   ooha.attribute9,
                   ooha.attribute10,
                   ooha.attribute11,
                   ooha.attribute12,
                   ooha.attribute13,
                   ooha.attribute14,
                   ooha.attribute15,
                   ooha.attribute16,
                   ooha.attribute17,
                   ooha.attribute18,
                   ooha.attribute19,
                   ooha.attribute20,
                   ooha.orig_sys_document_ref,
                   ooha.order_number,
                   ooha.ordered_date,
                   ooha.order_type_id,
                   ooha.shipping_method_code,
                   ooha.transactional_curr_code,
                   ooha.sold_to_org_id,
                   ooha.sold_to_org_id
                       customer_id,
                   gn_user_id,
                   gd_sysdate,
                   gn_user_id,
                   gd_sysdate,
                   gn_login_id,
                   gn_request_id,
                   'UPDATE',
                   'Y',
                   'SYSTEM',
                   2,
                   xooh.tp_attribute1,
                   xooh.tp_attribute2,
                   'N',
                   xooh.global_attribute1
              FROM oe_order_headers_all ooha, xxd_ont_oe_headers_iface_stg_t xooh
             WHERE     1 = 1
                   AND ooha.orig_sys_document_ref =
                       xooh.orig_sys_document_ref
                   AND xooh.request_id = gn_request_id
                   AND xooh.tp_attribute4 = 'X';

        debug_msg ('Insert Header Staging Count = ' || SQL%ROWCOUNT);

        INSERT INTO xxd_ont_oe_lines_iface_stg_t (org_id,
                                                  order_source_id,
                                                  inventory_item_id,
                                                  ship_to_org_id,
                                                  ordered_quantity,
                                                  unit_selling_price,
                                                  unit_list_price,
                                                  customer_po_number,
                                                  shipping_method_code,
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
                                                  request_date,
                                                  latest_acceptable_date,
                                                  orig_sys_document_ref,
                                                  orig_sys_line_ref,
                                                  change_sequence,
                                                  pricing_quantity,
                                                  sold_to_org_id,
                                                  pricing_date,
                                                  order_quantity_uom,
                                                  calculate_price_flag,
                                                  created_by,
                                                  creation_date,
                                                  last_updated_by,
                                                  last_update_date,
                                                  last_update_login,
                                                  request_id,
                                                  change_reason,
                                                  operation_code,
                                                  tp_attribute1,
                                                  tp_attribute2,
                                                  tp_attribute4)
            SELECT oola.org_id,
                   oola.order_source_id,
                   oola.inventory_item_id,
                   oola.ship_to_org_id,
                   oola.ordered_quantity,
                   oola.unit_selling_price,
                   oola.unit_list_price,
                   oola.cust_po_number,
                   oola.shipping_method_code,
                   CASE
                       WHEN xooh.attribute1 <> oola.attribute1
                       THEN
                           xooh.attribute1
                       ELSE
                           oola.attribute1
                   END,
                   oola.attribute2,
                   oola.attribute3,
                   oola.attribute4,
                   oola.attribute5,
                   oola.attribute6,
                   oola.attribute7,
                   oola.attribute8,
                   oola.attribute9,
                   oola.attribute10,
                   oola.attribute11,
                   oola.attribute12,
                   NVL (
                       (SELECT MIN (attribute13)               -- Customer USP
                          FROM xxd_ont_oe_lines_iface_stg_t xool
                         WHERE     xool.tp_attribute1 = xooh.tp_attribute1
                               AND NVL (xool.tp_attribute2, 'CT') = 'PC'
                               AND xool.tp_attribute4 = 'X'
                               AND xool.inventory_item_id =
                                   oola.inventory_item_id
                               AND ((xool.ship_to_org_id IS NOT NULL AND xool.ship_to_org_id = oola.ship_to_org_id) OR (xool.ship_to_org_id IS NULL AND 1 = 1))
                               AND xool.request_id = gn_request_id),
                       oola.attribute13),
                   oola.attribute14,
                   oola.attribute15,
                   oola.attribute16,
                   oola.attribute17,
                   oola.attribute18,
                   oola.attribute19,
                   oola.attribute20,
                   CASE
                       WHEN xooh.request_date <> oola.request_date
                       THEN
                           xooh.request_date
                       ELSE
                           oola.request_date
                   END,
                   CASE
                       WHEN fnd_date.canonical_to_date (xooh.attribute1) <>
                            oola.latest_acceptable_date
                       THEN
                           fnd_date.canonical_to_date (xooh.attribute1)
                       ELSE
                           oola.latest_acceptable_date
                   END,
                   oola.orig_sys_document_ref,
                   oola.orig_sys_line_ref,
                   2,
                   oola.pricing_quantity,
                   oola.sold_to_org_id,
                   oola.pricing_date,
                   oola.order_quantity_uom,
                   oola.calculate_price_flag,
                   gn_user_id,
                   gd_sysdate,
                   gn_user_id,
                   gd_sysdate,
                   gn_login_id,
                   gn_request_id,
                   'SYSTEM',
                   'UPDATE',
                   xooh.tp_attribute1,
                   xooh.tp_attribute2,
                   'N'
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, xxd_ont_oe_headers_iface_stg_t xooh
             WHERE     1 = 1
                   AND ooha.header_id = oola.header_id
                   AND ooha.orig_sys_document_ref =
                       xooh.orig_sys_document_ref
                   AND ooha.open_flag = 'Y'
                   AND oola.open_flag = 'Y'
                   AND NVL (xooh.cancelled_flag, 'N') <> 'Y'
                   AND xooh.request_id = gn_request_id
                   AND xooh.tp_attribute4 = 'X';

        debug_msg ('Insert Line Staging Count = ' || SQL%ROWCOUNT);
        COMMIT;
        debug_msg ('End INSERT_STAGING_DATA ');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in INSERT_STAGING_DATA' || SQLERRM);
    END insert_staging_data;

    -------------------------------------------------------------
    --Procedure to validate Ship To and SKU combination
    -------------------------------------------------------------
    PROCEDURE validate_ship_to (p_operating_unit   IN NUMBER,
                                p_osid             IN NUMBER,
                                p_cust_po_num      IN VARCHAR2)
    IS
        ln_exists          NUMBER := 0;
        lc_status          VARCHAR2 (1);
        lc_error_message   VARCHAR2 (4000);
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start VALIDATE_SHIP_TO');

        FOR line_rec
            IN (  SELECT *
                    FROM xxd_ont_oe_lines_iface_stg_t
                   WHERE     1 = 1
                         AND customer_po_number =
                             NVL (p_cust_po_num, customer_po_number)
                         AND org_id = p_operating_unit
                         AND order_source_id = p_osid
                         AND tp_attribute4 = 'X'
                         AND NVL (tp_attribute2, 'CT') NOT IN ('NCH', 'AI', 'CA',
                                                               'RZ', 'DI')
                         AND request_id = gn_request_id
                ORDER BY tp_attribute1)
        LOOP
            debug_msg ('Change Type = ' || line_rec.tp_attribute2);
            debug_msg ('Item ID = ' || line_rec.inventory_item_id);
            debug_msg ('Ship To Org ID = ' || line_rec.ship_to_org_id);
            lc_status          := 'S';
            lc_error_message   := NULL;
            gc_delimiter       := CHR (9);

            IF line_rec.ship_to_org_id IS NULL
            THEN
                SELECT COUNT (DISTINCT xool.ship_to_org_id)
                  INTO ln_exists
                  FROM xxd_ont_oe_lines_iface_stg_t xool
                 WHERE     xool.tp_attribute1 = line_rec.tp_attribute1
                       AND xool.tp_attribute4 = 'N'
                       AND xool.inventory_item_id =
                           line_rec.inventory_item_id
                       AND xool.request_id = gn_request_id;

                IF ln_exists = 0
                THEN
                    lc_error_message   :=
                           'Ship-To not available for the current SKU and Change Code '
                        || line_rec.tp_attribute2;
                    lc_status   := 'E';
                ELSIF ln_exists > 1
                THEN
                    lc_error_message   :=
                           'Multiple Ship-To found for the current SKU and Change Code '
                        || line_rec.tp_attribute2;
                    lc_status   := 'E';
                END IF;
            ELSE
                SELECT COUNT (DISTINCT xool.ship_to_org_id)
                  INTO ln_exists
                  FROM xxd_ont_oe_lines_iface_stg_t xool
                 WHERE     xool.tp_attribute1 = line_rec.tp_attribute1
                       AND xool.tp_attribute4 = 'N'
                       AND xool.inventory_item_id =
                           line_rec.inventory_item_id
                       AND xool.ship_to_org_id = line_rec.ship_to_org_id
                       AND xool.request_id = gn_request_id;

                IF ln_exists = 0
                THEN
                    lc_error_message   :=
                           'Ship-To not available for the current SKU and Change Code '
                        || line_rec.tp_attribute2;
                    lc_status   := 'E';
                ELSIF ln_exists > 1
                THEN
                    lc_error_message   :=
                           'Multiple Ship-To found for the current SKU and Change Code '
                        || line_rec.tp_attribute2;
                    lc_status   := 'E';
                END IF;
            END IF;

            IF lc_status = 'E'
            THEN
                debug_msg ('Error: ' || lc_error_message);

                UPDATE xxd_ont_oe_lines_iface_stg_t
                   SET tp_attribute4 = lc_status, tp_attribute5 = lc_error_message, request_id = 42
                 WHERE     tp_attribute1 = line_rec.tp_attribute1
                       AND inventory_item_id = line_rec.inventory_item_id
                       AND request_id = gn_request_id;

                debug_msg ('Ship To Error Update Count = ' || SQL%ROWCOUNT);
            ELSE
                debug_msg ('No error for this SKU and Ship-To combination');
            END IF;

            gc_delimiter       := '';
        END LOOP;

        -- Update all as E if atleast one line is E
        UPDATE xxd_ont_oe_lines_iface_stg_t xool
           SET xool.tp_attribute4 = 'E', tp_attribute5 = 'One or more line is in error'
         WHERE     1 = 1
               AND EXISTS
                       (SELECT 1
                          FROM xxd_ont_oe_lines_iface_stg_t x
                         WHERE     1 = 1
                               AND x.tp_attribute1 = xool.tp_attribute1
                               AND x.tp_attribute4 = 'E')
               AND xool.tp_attribute4 <> 'E';

        debug_msg (
            'Update Line Status for other records Count = ' || SQL%ROWCOUNT);

        COMMIT;
        debug_msg ('End VALIDATE_SHIP_TO ');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in VALIDATE_SHIP_TO' || SQLERRM);
    END validate_ship_to;

    -------------------------------------------------------------
    --Procedure to Process DI; Delete Item
    --Update OQ to 0 and Cancel Flag as Y
    -------------------------------------------------------------
    PROCEDURE change_code_di (p_osdr          IN VARCHAR2,
                              p_seq_num       IN VARCHAR2,
                              p_change_type   IN VARCHAR2)
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start CHANGE_CODE_DI');

        FOR line_rec
            IN (SELECT *
                  FROM xxd_ont_oe_lines_iface_stg_t
                 WHERE     orig_sys_document_ref = p_osdr
                       AND tp_attribute1 = p_seq_num
                       AND tp_attribute4 = 'X'
                       AND NVL (tp_attribute2, 'CT') = p_change_type
                       AND request_id = gn_request_id)
        LOOP
            debug_msg ('Item ID = ' || line_rec.inventory_item_id);
            debug_msg ('Ship To Org ID = ' || line_rec.ship_to_org_id);

            --Mark as valid if SKU and Ship-to matches
            UPDATE xxd_ont_oe_lines_iface_stg_t
               SET ordered_quantity = 0, pricing_quantity = 0, cancelled_flag = 'Y',
                   tp_attribute4 = 'V'
             WHERE     orig_sys_document_ref = line_rec.orig_sys_document_ref
                   AND tp_attribute1 = line_rec.tp_attribute1
                   AND ship_to_org_id =
                       NVL (line_rec.ship_to_org_id, ship_to_org_id)
                   AND inventory_item_id = line_rec.inventory_item_id
                   AND tp_attribute4 = 'N'
                   AND request_id = gn_request_id;

            debug_msg (
                   'Updated Qty as 0 and status as Valid. Count = '
                || SQL%ROWCOUNT);
        END LOOP;

        debug_msg ('End CHANGE_CODE_DI ');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in CHANGE_CODE_DI' || SQLERRM);
    END change_code_di;

    -- Start changes for CCR0009265
    -------------------------------------------------------------
    --Procedure to Process DI for CA and RZ; Delete Item
    --Update OQ to 0 and Cancel Flag as Y
    --Ignore the Ship to Org ID validation that was in change_code_di
    -------------------------------------------------------------
    PROCEDURE change_code_di_gen (p_osdr          IN VARCHAR2,
                                  p_seq_num       IN VARCHAR2,
                                  p_change_type   IN VARCHAR2)
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start CHANGE_CODE_DI_GEN');

        FOR line_rec
            IN (SELECT *
                  FROM xxd_ont_oe_lines_iface_stg_t
                 WHERE     orig_sys_document_ref = p_osdr
                       AND tp_attribute1 = p_seq_num
                       AND tp_attribute4 = 'X'
                       AND NVL (tp_attribute2, 'CT') = p_change_type
                       AND request_id = gn_request_id)
        LOOP
            debug_msg ('Item ID = ' || line_rec.inventory_item_id);
            debug_msg ('Ship To Org ID = ' || line_rec.ship_to_org_id);

            --Mark as valid if SKU and Ship-to matches
            UPDATE xxd_ont_oe_lines_iface_stg_t
               SET ordered_quantity = 0, pricing_quantity = 0, cancelled_flag = 'Y',
                   tp_attribute4 = 'V'
             WHERE     orig_sys_document_ref = line_rec.orig_sys_document_ref
                   AND tp_attribute1 = line_rec.tp_attribute1
                   AND inventory_item_id = line_rec.inventory_item_id
                   AND tp_attribute4 = 'N'
                   AND request_id = gn_request_id;

            debug_msg (
                   'Updated Qty as 0 and status as Valid. Count = '
                || SQL%ROWCOUNT);
        END LOOP;

        debug_msg ('End CHANGE_CODE_DI_GEN');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in CHANGE_CODE_DI_GEN' || SQLERRM);
    END change_code_di_gen;

    -- End changes for CCR0009265

    -------------------------------------------------------------
    --Procedure to Process AI; Add Item
    --Insert a new line staging record
    -------------------------------------------------------------
    PROCEDURE change_code_ai (p_osdr          IN VARCHAR2,
                              p_seq_num       IN VARCHAR2,
                              p_change_type   IN VARCHAR2)
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start CHANGE_CODE_AI');

        INSERT INTO xxd_ont_oe_lines_iface_stg_t (org_id,
                                                  order_source_id,
                                                  inventory_item_id,
                                                  ship_to_org_id,
                                                  ordered_quantity,
                                                  unit_selling_price,
                                                  unit_list_price,
                                                  customer_po_number,
                                                  shipping_method_code,
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
                                                  request_date,
                                                  latest_acceptable_date,
                                                  orig_sys_document_ref,
                                                  orig_sys_line_ref,
                                                  change_sequence,
                                                  pricing_quantity,
                                                  sold_to_org_id,
                                                  pricing_date,
                                                  order_quantity_uom,
                                                  calculate_price_flag,
                                                  created_by,
                                                  creation_date,
                                                  last_updated_by,
                                                  last_update_date,
                                                  last_update_login,
                                                  request_id,
                                                  change_reason,
                                                  operation_code,
                                                  tp_attribute1,
                                                  tp_attribute2,
                                                  tp_attribute4)
            SELECT xool.org_id, xool.order_source_id, xool.inventory_item_id,
                   xool.ship_to_org_id, xool.ordered_quantity, xool.unit_selling_price,
                   xool.unit_list_price, xool.customer_po_number, xooh.shipping_method_code,
                   xooh.attribute1, xool.attribute2, xool.attribute3,
                   xool.attribute4, xool.attribute5, xool.attribute6,
                   xool.attribute7, xool.attribute8, xool.attribute9,
                   xool.attribute10, xool.attribute11, xool.attribute12,
                   xool.attribute13, xool.attribute14, xool.attribute15,
                   xool.attribute16, xool.attribute17, xool.attribute18,
                   xool.attribute19, xool.attribute20, xooh.request_date,
                   fnd_date.canonical_to_date (xooh.attribute1), xool.orig_sys_document_ref, (REPLACE (REPLACE (xool.ROWID || xooh.ROWID, '/', 1), '+', '2')),
                   2, xool.pricing_quantity, xool.sold_to_org_id,
                   xool.request_date, xool.order_quantity_uom, xool.calculate_price_flag,
                   gn_user_id, gd_sysdate, gn_user_id,
                   gd_sysdate, gn_login_id, gn_request_id,
                   'SYSTEM', 'INSERT', xooh.tp_attribute1,
                   xooh.tp_attribute2, 'V'
              FROM xxd_ont_oe_headers_iface_stg_t xooh, xxd_ont_oe_lines_iface_stg_t xool
             WHERE     1 = 1
                   AND xooh.tp_attribute1 = xool.tp_attribute1
                   AND xooh.orig_sys_document_ref =
                       xool.orig_sys_document_ref
                   AND xooh.request_id = gn_request_id
                   AND xool.request_id = gn_request_id
                   AND xooh.tp_attribute4 = 'N'
                   AND xool.tp_attribute4 = 'X'
                   AND NVL (xool.tp_attribute2, 'CT') = p_change_type
                   AND xooh.orig_sys_document_ref = p_osdr
                   AND xooh.tp_attribute1 = p_seq_num;

        debug_msg (
               'Inserted new lines with status as Valid. Count = '
            || SQL%ROWCOUNT);

        debug_msg ('End CHANGE_CODE_AI ');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in CHANGE_CODE_AI' || SQLERRM);
    END change_code_ai;

    -------------------------------------------------------------
    --Procedure to Process CA; Change All
    -------------------------------------------------------------
    PROCEDURE change_code_ca (p_osdr          IN VARCHAR2,
                              p_seq_num       IN VARCHAR2,
                              p_change_type   IN VARCHAR2)
    IS
    BEGIN
        gc_delimiter   := CHR (9) || CHR (9);
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start CHANGE_CODE_CA');

        --First Delete Item
        -- Start changes for CCR0009265
        change_code_di_gen (p_osdr          => p_osdr,
                            --change_code_di (p_osdr          => p_osdr,
                            -- End changes for CCR0009265
                            p_seq_num       => p_seq_num,
                            p_change_type   => p_change_type);
        --Then Add Item
        change_code_ai (p_osdr          => p_osdr,
                        p_seq_num       => p_seq_num,
                        p_change_type   => p_change_type);

        debug_msg ('End CHANGE_CODE_CA ');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in CHANGE_CODE_CA' || SQLERRM);
    END change_code_ca;

    -------------------------------------------------------------
    --Procedure to Process RZ; Replace All
    -------------------------------------------------------------
    PROCEDURE change_code_rz (p_osdr          IN VARCHAR2,
                              p_seq_num       IN VARCHAR2,
                              p_change_type   IN VARCHAR2)
    IS
    BEGIN
        gc_delimiter   := CHR (9) || CHR (9);
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start CHANGE_CODE_RZ');

        --First Delete Item
        -- Start changes for CCR0009265
        change_code_di_gen (p_osdr          => p_osdr,
                            --change_code_di (p_osdr          => p_osdr,
                            -- End changes for CCR0009265
                            p_seq_num       => p_seq_num,
                            p_change_type   => p_change_type);
        --Then Add Item
        change_code_ai (p_osdr          => p_osdr,
                        p_seq_num       => p_seq_num,
                        p_change_type   => p_change_type);

        debug_msg ('End CHANGE_CODE_RZ ');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in CHANGE_CODE_RZ' || SQLERRM);
    END change_code_rz;

    -------------------------------------------------------------
    --Procedure to Mimic AI but for a specific OQ
    --Insert a new line staging record
    -------------------------------------------------------------
    PROCEDURE change_code_ai_with_qty (p_osdr                IN VARCHAR2,
                                       p_seq_num             IN VARCHAR2,
                                       p_change_type         IN VARCHAR2,
                                       p_inventory_item_id   IN VARCHAR2,
                                       p_qty                 IN NUMBER)
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start CHANGE_CODE_AI_WITH_QTY');

        INSERT INTO xxd_ont_oe_lines_iface_stg_t (org_id,
                                                  order_source_id,
                                                  inventory_item_id,
                                                  ship_to_org_id,
                                                  ordered_quantity,
                                                  unit_selling_price,
                                                  unit_list_price,
                                                  customer_po_number,
                                                  shipping_method_code,
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
                                                  request_date,
                                                  latest_acceptable_date,
                                                  orig_sys_document_ref,
                                                  orig_sys_line_ref,
                                                  change_sequence,
                                                  pricing_quantity,
                                                  sold_to_org_id,
                                                  pricing_date,
                                                  order_quantity_uom,
                                                  calculate_price_flag,
                                                  created_by,
                                                  creation_date,
                                                  last_updated_by,
                                                  last_update_date,
                                                  last_update_login,
                                                  request_id,
                                                  change_reason,
                                                  operation_code,
                                                  tp_attribute1,
                                                  tp_attribute2,
                                                  tp_attribute4)
            SELECT xool.org_id, xool.order_source_id, xool.inventory_item_id,
                   xool.ship_to_org_id, p_qty, xool.unit_selling_price,
                   xool.unit_list_price, xool.customer_po_number, xooh.shipping_method_code,
                   xooh.attribute1, xool.attribute2, xool.attribute3,
                   xool.attribute4, xool.attribute5, xool.attribute6,
                   xool.attribute7, xool.attribute8, xool.attribute9,
                   xool.attribute10, xool.attribute11, xool.attribute12,
                   xool.attribute13, xool.attribute14, xool.attribute15,
                   xool.attribute16, xool.attribute17, xool.attribute18,
                   xool.attribute19, xool.attribute20, xooh.request_date,
                   fnd_date.canonical_to_date (xooh.attribute1), xool.orig_sys_document_ref, UPPER (REPLACE (REPLACE (xool.ROWID, '/', 1), '+', '2')),
                   2, p_qty, xool.sold_to_org_id,
                   xool.request_date, xool.order_quantity_uom, xool.calculate_price_flag,
                   gn_user_id, gd_sysdate, gn_user_id,
                   gd_sysdate, gn_login_id, gn_request_id,
                   'SYSTEM', 'INSERT', xooh.tp_attribute1,
                   xooh.tp_attribute2, 'V'
              FROM xxd_ont_oe_headers_iface_stg_t xooh, xxd_ont_oe_lines_iface_stg_t xool
             WHERE     1 = 1
                   AND xooh.tp_attribute1 = xool.tp_attribute1
                   AND xooh.orig_sys_document_ref =
                       xool.orig_sys_document_ref
                   AND xooh.request_id = gn_request_id
                   AND xool.request_id = gn_request_id
                   AND xooh.tp_attribute4 = 'N'
                   AND xool.tp_attribute4 = 'X'
                   AND xool.inventory_item_id = p_inventory_item_id
                   AND NVL (xool.tp_attribute2, 'CT') = p_change_type
                   AND xooh.orig_sys_document_ref = p_osdr
                   AND xooh.tp_attribute1 = p_seq_num;

        debug_msg (
               'Inserted new lines with status as Valid. Count = '
            || SQL%ROWCOUNT);

        debug_msg ('End CHANGE_CODE_AI_WITH_QTY ');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg (
                'Other Exception in CHANGE_CODE_AI_WITH_QTY' || SQLERRM);
    END change_code_ai_with_qty;

    -------------------------------------------------------------
    --Procedure to Decrease Qty
    -------------------------------------------------------------
    PROCEDURE qty_decrease (p_osdr IN VARCHAR2, p_seq_num IN VARCHAR2, p_change_type IN VARCHAR2
                            , p_inventory_item_id IN NUMBER, p_ship_to_org_id IN NUMBER, p_new_qty IN NUMBER)
    IS
        ln_exp_qty    NUMBER := p_new_qty;
        ln_curr_qty   NUMBER := 0;
        ln_new_oq     NUMBER := 0;
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start QTY_DECREASE');

        --Select all N records
        FOR qty_rec
            IN (  SELECT orig_sys_line_ref, ordered_quantity avail_qty
                    FROM xxd_ont_oe_lines_iface_stg_t
                   WHERE     orig_sys_document_ref = p_osdr
                         AND tp_attribute1 = p_seq_num
                         AND inventory_item_id = p_inventory_item_id
                         AND ship_to_org_id =
                             NVL (p_ship_to_org_id, ship_to_org_id)
                         AND tp_attribute4 = 'N'
                         AND request_id = gn_request_id
                ORDER BY 2 DESC)
        LOOP
            debug_msg ('New Expected Qty = ' || ln_exp_qty);

            IF ln_exp_qty > qty_rec.avail_qty
            THEN
                debug_msg (
                       'New Expected Qty = '
                    || ln_exp_qty
                    || ' > than Available Qty '
                    || qty_rec.avail_qty);
                ln_curr_qty   := qty_rec.avail_qty;

                IF ln_curr_qty <= ln_exp_qty
                THEN
                    debug_msg (
                           'Current Qty = '
                        || ln_curr_qty
                        || ' <= than New Expected Qty '
                        || ln_exp_qty);
                    debug_msg ('Update OQ as 0');
                    ln_new_oq    := 0;
                    ln_exp_qty   := ln_exp_qty - ln_curr_qty;
                ELSE
                    debug_msg (
                           'Current Qty = '
                        || ln_curr_qty
                        || ' > than New Expected Qty '
                        || ln_exp_qty);
                    debug_msg (
                        'Update OQ as New Expected Qty ' || ln_exp_qty);
                    ln_new_oq   := ln_exp_qty;
                END IF;
            ELSE
                debug_msg (
                       'New Expected Qty = '
                    || ln_exp_qty
                    || ' <= than Available Qty '
                    || qty_rec.avail_qty);
                ln_new_oq    := qty_rec.avail_qty - ln_exp_qty;
                ln_exp_qty   := 0;
                debug_msg ('No more Qty Reduction needed');
            END IF;

            UPDATE xxd_ont_oe_lines_iface_stg_t
               SET ordered_quantity = ln_new_oq, pricing_quantity = ln_new_oq, cancelled_flag = DECODE (ln_new_oq, 0, 'Y', NULL),
                   tp_attribute4 = 'V'
             WHERE     orig_sys_document_ref = p_osdr
                   AND tp_attribute1 = p_seq_num
                   AND inventory_item_id = p_inventory_item_id
                   AND ship_to_org_id =
                       NVL (p_ship_to_org_id, ship_to_org_id)
                   AND orig_sys_line_ref = qty_rec.orig_sys_line_ref
                   AND tp_attribute4 = 'N'
                   AND request_id = gn_request_id;
        END LOOP;

        debug_msg ('End QTY_DECREASE ');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in QTY_DECREASE' || SQLERRM);
    END qty_decrease;

    -------------------------------------------------------------
    --Procedure to Calculate Staging Vs Base Table data
    -------------------------------------------------------------
    PROCEDURE qty_calc (p_osdr          IN VARCHAR2,
                        p_seq_num       IN VARCHAR2,
                        p_change_type   IN VARCHAR2)
    IS
        ln_new_qty        NUMBER := 0;
        ln_stg_qty_sum    NUMBER := 0;
        ln_base_qty_sum   NUMBER := 0;
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start QTY_CALC');

        FOR line_rec
            IN (  SELECT tp_attribute1, orig_sys_document_ref, orig_sys_line_ref,
                         inventory_item_id, ship_to_org_id
                    FROM xxd_ont_oe_lines_iface_stg_t
                   WHERE     orig_sys_document_ref = p_osdr
                         AND tp_attribute1 = p_seq_num
                         AND tp_attribute4 = 'X'
                         AND NVL (tp_attribute2, 'CT') = p_change_type
                         AND request_id = gn_request_id
                GROUP BY tp_attribute1, orig_sys_document_ref, orig_sys_line_ref,
                         inventory_item_id, ship_to_org_id)
        LOOP
            --Staging Data Sum (X records)
            SELECT SUM (ordered_quantity)
              INTO ln_stg_qty_sum
              FROM xxd_ont_oe_lines_iface_stg_t
             WHERE     orig_sys_document_ref = line_rec.orig_sys_document_ref
                   AND tp_attribute1 = line_rec.tp_attribute1
                   AND inventory_item_id = line_rec.inventory_item_id
                   AND ((ship_to_org_id IS NOT NULL AND line_rec.ship_to_org_id IS NOT NULL AND ship_to_org_id = line_rec.ship_to_org_id) OR ((ship_to_org_id IS NULL OR line_rec.ship_to_org_id IS NULL) AND 1 = 1))
                   AND tp_attribute4 = 'X'
                   AND NVL (tp_attribute2, 'CT') = p_change_type
                   AND request_id = gn_request_id;

            debug_msg ('Staging Data Sum = ' || ln_stg_qty_sum);

            --Base Table Data Sum (N records)
            SELECT SUM (ordered_quantity)
              INTO ln_base_qty_sum
              FROM xxd_ont_oe_lines_iface_stg_t
             WHERE     orig_sys_document_ref = line_rec.orig_sys_document_ref
                   AND tp_attribute1 = line_rec.tp_attribute1
                   AND inventory_item_id = line_rec.inventory_item_id
                   AND ship_to_org_id =
                       NVL (line_rec.ship_to_org_id, ship_to_org_id)
                   AND tp_attribute4 = 'N'
                   AND request_id = gn_request_id;

            debug_msg ('Base Table Data Sum = ' || ln_base_qty_sum);

            gc_delimiter   := CHR (9) || CHR (9);

            IF ln_stg_qty_sum - ln_base_qty_sum > 0
            THEN
                ln_new_qty   := ln_stg_qty_sum - ln_base_qty_sum;
                debug_msg ('New Qty = ' || ln_new_qty);
                --Mimic AI but for a specific qty
                change_code_ai_with_qty (
                    p_osdr                => line_rec.orig_sys_document_ref,
                    p_seq_num             => line_rec.tp_attribute1,
                    p_change_type         => p_change_type,
                    p_inventory_item_id   => line_rec.inventory_item_id,
                    p_qty                 => ln_new_qty);
            ELSIF ln_base_qty_sum - ln_stg_qty_sum > 0
            THEN
                ln_new_qty   := ln_base_qty_sum - ln_stg_qty_sum;
                debug_msg ('New Qty = ' || ln_new_qty);
                qty_decrease (
                    p_osdr                => line_rec.orig_sys_document_ref,
                    p_seq_num             => line_rec.tp_attribute1,
                    p_change_type         => p_change_type,
                    p_inventory_item_id   => line_rec.inventory_item_id,
                    p_ship_to_org_id      => line_rec.ship_to_org_id,
                    p_new_qty             => ln_new_qty);
            END IF;
        END LOOP;

        debug_msg ('End QTY_CALC ');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in QTY_CALC' || SQLERRM);
    END qty_calc;

    -------------------------------------------------------------
    --Procedure to Process QI; Quantity Increase
    -------------------------------------------------------------
    PROCEDURE change_code_qi (p_osdr          IN VARCHAR2,
                              p_seq_num       IN VARCHAR2,
                              p_change_type   IN VARCHAR2)
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start CHANGE_CODE_QI');

        qty_calc (p_osdr          => p_osdr,
                  p_seq_num       => p_seq_num,
                  p_change_type   => p_change_type);

        debug_msg ('End CHANGE_CODE_QI ');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in CHANGE_CODE_QI' || SQLERRM);
    END change_code_qi;

    -------------------------------------------------------------
    --Procedure to Process QD; Quantity Decrease
    -------------------------------------------------------------
    PROCEDURE change_code_qd (p_osdr          IN VARCHAR2,
                              p_seq_num       IN VARCHAR2,
                              p_change_type   IN VARCHAR2)
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start CHANGE_CODE_QD');
        qty_calc (p_osdr          => p_osdr,
                  p_seq_num       => p_seq_num,
                  p_change_type   => p_change_type);

        gc_delimiter   := CHR (9);
        debug_msg ('End CHANGE_CODE_QD');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in CHANGE_CODE_QD' || SQLERRM);
    END change_code_qd;

    -------------------------------------------------------------
    --Procedure to Process RQ; Reschedule or Qty Change
    -------------------------------------------------------------
    PROCEDURE change_code_rq (p_osdr          IN VARCHAR2,
                              p_seq_num       IN VARCHAR2,
                              p_change_type   IN VARCHAR2)
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start CHANGE_CODE_RQ');
        qty_calc (p_osdr          => p_osdr,
                  p_seq_num       => p_seq_num,
                  p_change_type   => p_change_type);

        gc_delimiter   := CHR (9);
        debug_msg ('End CHANGE_CODE_RQ');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in CHANGE_CODE_RQ' || SQLERRM);
    END change_code_rq;

    -------------------------------------------------------------
    --Procedure to Process PQ; Quantity Change
    -------------------------------------------------------------
    PROCEDURE change_code_pq (p_osdr          IN VARCHAR2,
                              p_seq_num       IN VARCHAR2,
                              p_change_type   IN VARCHAR2)
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start CHANGE_CODE_PQ');
        qty_calc (p_osdr          => p_osdr,
                  p_seq_num       => p_seq_num,
                  p_change_type   => p_change_type);

        gc_delimiter   := CHR (9);
        debug_msg ('End CHANGE_CODE_PQ');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in CHANGE_CODE_PQ' || SQLERRM);
    END change_code_pq;

    -------------------------------------------------------------
    --Procedure to Process the Change Code Types
    -------------------------------------------------------------
    PROCEDURE validate_change_code (p_operating_unit IN NUMBER, p_osid IN NUMBER, p_cust_po_num IN VARCHAR2)
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start VALIDATE_CHANGE_CODE');
        debug_msg ('Processing Change Types');

        FOR osdr_rec
            IN (  SELECT DISTINCT xool.orig_sys_document_ref, xool.tp_attribute1 seq_num, NVL (xool.tp_attribute2, 'CT') change_type
                    FROM xxd_ont_oe_lines_iface_stg_t xool
                   WHERE     request_id = gn_request_id
                         AND xool.tp_attribute4 = 'X'
                ORDER BY seq_num)
        LOOP
            debug_msg (RPAD ('=', 100, '='));
            debug_msg ('OSDR = ' || osdr_rec.orig_sys_document_ref);
            debug_msg ('Sequence Number = ' || osdr_rec.seq_num);
            debug_msg ('Change Type = ' || osdr_rec.change_type);

            --Delete Item
            IF osdr_rec.change_type = 'DI'
            THEN
                gc_delimiter   := CHR (9);
                change_code_di (p_osdr          => osdr_rec.orig_sys_document_ref,
                                p_seq_num       => osdr_rec.seq_num,
                                p_change_type   => osdr_rec.change_type);
            --Add Item
            ELSIF osdr_rec.change_type = 'AI'
            THEN
                gc_delimiter   := CHR (9);
                change_code_ai (p_osdr          => osdr_rec.orig_sys_document_ref,
                                p_seq_num       => osdr_rec.seq_num,
                                p_change_type   => osdr_rec.change_type);
            --Change All
            ELSIF osdr_rec.change_type = 'CA'
            THEN
                gc_delimiter   := CHR (9);
                change_code_ca (p_osdr          => osdr_rec.orig_sys_document_ref,
                                p_seq_num       => osdr_rec.seq_num,
                                p_change_type   => osdr_rec.change_type);
            --Replace All
            ELSIF osdr_rec.change_type = 'RZ'
            THEN
                gc_delimiter   := CHR (9);
                change_code_rz (p_osdr          => osdr_rec.orig_sys_document_ref,
                                p_seq_num       => osdr_rec.seq_num,
                                p_change_type   => osdr_rec.change_type);
            --Quantity Increase
            ELSIF osdr_rec.change_type = 'QI'
            THEN
                gc_delimiter   := CHR (9);
                change_code_qi (p_osdr          => osdr_rec.orig_sys_document_ref,
                                p_seq_num       => osdr_rec.seq_num,
                                p_change_type   => osdr_rec.change_type);
            --Quantity Decrease
            ELSIF osdr_rec.change_type = 'QD'
            THEN
                gc_delimiter   := CHR (9);
                change_code_qd (p_osdr          => osdr_rec.orig_sys_document_ref,
                                p_seq_num       => osdr_rec.seq_num,
                                p_change_type   => osdr_rec.change_type);
            --Reschedule or Qty Change
            ELSIF osdr_rec.change_type = 'RQ'
            THEN
                gc_delimiter   := CHR (9);
                change_code_rq (p_osdr          => osdr_rec.orig_sys_document_ref,
                                p_seq_num       => osdr_rec.seq_num,
                                p_change_type   => osdr_rec.change_type);
            --Qty Change
            ELSIF osdr_rec.change_type = 'PQ'
            THEN
                gc_delimiter   := CHR (9);
                change_code_pq (p_osdr          => osdr_rec.orig_sys_document_ref,
                                p_seq_num       => osdr_rec.seq_num,
                                p_change_type   => osdr_rec.change_type);
            END IF;

            gc_delimiter   := '';
        END LOOP;

        debug_msg ('End VALIDATE_CHANGE_CODE ');
        debug_msg ((RPAD ('=', 100, '=')));
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in VALIDATE_CHANGE_CODE' || SQLERRM);
    END validate_change_code;

    -------------------------------------------------------------
    --Procedure to prepare staging data before iface insert
    -------------------------------------------------------------
    PROCEDURE prepare_staging
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start PREPARE_STAGING');

        -- Update Header as E if atleast one line is E
        UPDATE xxd_ont_oe_headers_iface_stg_t xooh
           SET xooh.tp_attribute4 = 'E', xooh.tp_attribute5 = 'One or more line is in error'
         WHERE     EXISTS
                       (SELECT 1
                          FROM xxd_ont_oe_lines_iface_stg_t xool
                         WHERE     xool.tp_attribute1 = xooh.tp_attribute1
                               AND xool.request_id = gn_request_id
                               AND xool.tp_attribute4 = 'E')
               AND xooh.tp_attribute4 IN ('X', 'N');

        COMMIT;
        debug_msg ('End PREPARE_STAGING ');
        debug_msg ((RPAD ('=', 100, '=')));
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in PREPARE_STAGING' || SQLERRM);
    END prepare_staging;

    -------------------------------------------------------------
    --Procedure to Insert IFACE records
    -------------------------------------------------------------
    PROCEDURE insert_iface (p_osid IN NUMBER)
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start INSERT_IFACE');

        --Lines Iface
        INSERT INTO oe_lines_iface_all (orig_sys_document_ref, customer_po_number, org_id, order_source_id, change_sequence, orig_sys_line_ref, inventory_item_id, ordered_quantity, ship_to_org_id, --unit_list_price,      --Commented as per ver 1.1
                                                                                                                                                                                                     --unit_selling_price,   --Commented as per ver 1.1
                                                                                                                                                                                                     created_by, creation_date, attribute1, attribute2, attribute3, attribute6, attribute7, attribute8, attribute10, attribute13, attribute14, attribute4, attribute5, attribute9, attribute11, attribute12, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, request_date, latest_acceptable_date, sold_to_org_id, last_updated_by, last_update_date, last_update_login, tp_attribute1, operation_code
                                        , change_reason)
            SELECT xool.orig_sys_document_ref, xool.customer_po_number, xool.org_id,
                   p_osid, xool.change_sequence, xool.orig_sys_line_ref,
                   xool.inventory_item_id, xool.ordered_quantity, xool.ship_to_org_id,
                   --xool.unit_list_price,      --Commented as per ver 1.1
                   --xool.unit_selling_price,   --Commented as per ver 1.1
                   xool.created_by, xool.creation_date, xool.attribute1,
                   xool.attribute2, xool.attribute3, xool.attribute6,
                   xool.attribute7, xool.attribute8, xool.attribute10,
                   xool.attribute13, xool.attribute14, xool.attribute4,
                   xool.attribute5, xool.attribute9, xool.attribute11,
                   xool.attribute12, xool.attribute15, xool.attribute16,
                   xool.attribute17, xool.attribute18, xool.attribute19,
                   xool.attribute20, xool.request_date, xool.latest_acceptable_date,
                   xool.sold_to_org_id, xool.last_updated_by, xool.last_update_date,
                   xool.last_update_login, xool.tp_attribute1, xool.operation_code,
                   xool.change_reason
              FROM xxd_ont_oe_lines_iface_stg_t xool, xxd_ont_oe_headers_iface_stg_t xooh
             WHERE     xool.tp_attribute1 = xooh.tp_attribute1
                   AND xool.tp_attribute1 IS NOT NULL
                   AND xool.tp_attribute4 IN ('V', 'N')
                   AND xooh.tp_attribute4 = 'N'
                   AND xool.request_id = gn_request_id;

        debug_msg ('Header IFACE Insert count = ' || SQL%ROWCOUNT);

        --Headers Iface
        INSERT INTO oe_headers_iface_all (orig_sys_document_ref, order_number, order_source_id, org_id, change_sequence, ordered_date, order_type_id, price_list_id, transactional_curr_code, customer_po_number, sold_to_org_id, ship_to_org_id, customer_id, cancelled_flag, attribute1, force_apply_flag, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, request_date, change_reason, sold_from_org_id, creation_date, created_by, last_updated_by, last_update_date, last_update_login, tp_attribute1, operation_code
                                          , global_attribute1)
            SELECT orig_sys_document_ref, order_number, p_osid,
                   org_id, change_sequence, ordered_date,
                   order_type_id, price_list_id, transactional_curr_code,
                   customer_po_number, sold_to_org_id, ship_to_org_id,
                   customer_id, cancelled_flag, attribute1,
                   force_apply_flag, attribute2, attribute3,
                   attribute4, attribute5, attribute6,
                   attribute7, attribute8, attribute9,
                   attribute10, attribute11, attribute12,
                   attribute13, attribute14, attribute15,
                   attribute16, attribute17, attribute18,
                   attribute19, attribute20, request_date,
                   change_reason, sold_from_org_id, creation_date,
                   created_by, last_updated_by, last_update_date,
                   last_update_login, tp_attribute1, operation_code,
                   global_attribute1
              FROM xxd_ont_oe_headers_iface_stg_t
             WHERE     tp_attribute1 IS NOT NULL
                   AND tp_attribute4 = 'N'
                   AND request_id = gn_request_id;

        debug_msg ('Line IFACE Insert count = ' || SQL%ROWCOUNT);
        debug_msg ('End INSERT_IFACE');
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in INSERT_IFACE' || SQLERRM);
    END insert_iface;

    -------------------------------------------------------------
    --Procedure to post iface insert, update staging status as P
    -------------------------------------------------------------
    PROCEDURE post_interface
    IS
    BEGIN
        debug_msg ((RPAD ('=', 100, '=')));
        debug_msg ('Start POST_INTERFACE');

        -- Update Header as P if exists in iface
        UPDATE xxd_ont_oe_headers_iface_stg_t xooh
           SET xooh.tp_attribute4 = 'P', xooh.tp_attribute5 = NULL
         WHERE     EXISTS
                       (SELECT 1
                          FROM oe_headers_iface_all ohia
                         WHERE     ohia.tp_attribute1 = xooh.tp_attribute1
                               AND ohia.sold_to_org_id = xooh.sold_to_org_id
                               AND ohia.customer_po_number =
                                   xooh.customer_po_number
                               AND ohia.org_id = xooh.org_id)
               AND xooh.request_id = gn_request_id
               AND xooh.tp_attribute4 IN ('X', 'N');

        debug_msg ('Line Staging Update count = ' || SQL%ROWCOUNT);

        -- Update Line as P if P in header
        UPDATE xxd_ont_oe_lines_iface_stg_t xool
           SET xool.tp_attribute4 = 'P', xool.tp_attribute5 = NULL
         WHERE     EXISTS
                       (SELECT 1
                          FROM xxd_ont_oe_headers_iface_stg_t xooh
                         WHERE     xooh.tp_attribute1 = xool.tp_attribute1
                               AND xooh.sold_to_org_id = xool.sold_to_org_id
                               AND xooh.customer_po_number =
                                   xooh.customer_po_number
                               AND xooh.org_id = xool.org_id
                               AND xooh.tp_attribute4 = 'P')
               AND xool.request_id = gn_request_id;

        debug_msg ('Line Staging Update count = ' || SQL%ROWCOUNT);
        COMMIT;
        debug_msg ('End POST_INTERFACE ');
        debug_msg ((RPAD ('=', 100, '=')));
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Other Exception in POST_INTERFACE' || SQLERRM);
    END post_interface;

    -----------------------------------
    --Main Procedure to call in program
    -----------------------------------
    PROCEDURE main_control (p_errbuf              OUT VARCHAR2,
                            p_retcode             OUT VARCHAR2,
                            p_operating_unit   IN     NUMBER,
                            p_osid             IN     NUMBER,
                            p_cust_po_num      IN     VARCHAR2,
                            p_reprocess_flag   IN     VARCHAR2)
    IS
    BEGIN
        gc_delimiter   := '';

        IF p_reprocess_flag = 'Y'
        THEN
            --Reprocess Data
            reprocess_data (p_operating_unit, p_osid, p_cust_po_num);
        END IF;

        --Update Staging data status for SOA reference
        update_staging_status (p_operating_unit, p_osid, p_cust_po_num);

        -- Start changes for CCR0009616
        apply_hdr_ship_to (p_operating_unit, p_osid, p_cust_po_num);
        -- End changes for CCR0009616

        --Insert Staging data based on base table data
        insert_staging_data (p_operating_unit, p_osid, p_cust_po_num);

        --Validate Ship Tos
        validate_ship_to (p_operating_unit, p_osid, p_cust_po_num);

        --Validate Change Code
        validate_change_code (p_operating_unit, p_osid, p_cust_po_num);

        --Prepare Staging Data
        prepare_staging;

        --Insert IFACE Records
        insert_iface (p_osid);

        --Post Interface Staging Update
        post_interface;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Exp in main_control: ' || SQLERRM);
    END main_control;
END xxd_ont_edi_validation_pkg;
/
