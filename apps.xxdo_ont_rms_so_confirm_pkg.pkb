--
-- XXDO_ONT_RMS_SO_CONFIRM_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ONT_RMS_SO_CONFIRM_PKG"
IS
    /****************************************************************************************
    * Package      : XXDO_ONT_RMS_SO_CONFIRM_PKG
    * Design       : This package will be used for EBS RMS Inegration.
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 30-Mar-2020  1.0        Gaurav Joshi            Initial Version
    -- 23-Sep-2020  1.1        Aravind Kannuri         Changes as per CCR0008948
    -- 23-May-2021  2.0        Shivanshu Talwar        Modified for Oracle 19C Upgrade - Integration through Business Event
    -- 01-Jan-2022  2.1        Shivanshu Talwar        Modified for CCR0009751 - Fix for sending correct Cancellation Message - Split Line Scenario
    ******************************************************************************************/

    gn_org_id         NUMBER := fnd_global.org_id;
    gn_request_id     NUMBER := fnd_global.conc_request_id;
    gc_enable_debug   VARCHAR2 (1);

    -- ======================================================================================
    -- This procedure prints the Debug Messages in Log File
    -- ======================================================================================
    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
    BEGIN
        IF gc_enable_debug = 'Y'
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
    -- This procedure generate DS scheduled confirmation lines
    -- ======================================================================================
    PROCEDURE generate_ds_confirmation (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_enable_debug IN VARCHAR2)
    AS
        CURSOR cur_ds_lines IS
            SELECT DISTINCT oeh.order_number, oeh.header_id, oel.line_number order_line_num,
                            oel.line_id, stg.distro_number, stg.dest_id,
                            stg.dc_dest_id, stg.document_type, oel.ordered_quantity qty,
                            stg.xml_id, oel.schedule_status_code, oeh.booked_flag,
                            oel.inventory_item_id, DECODE (oel.schedule_status_code, 'SCHEDULED', 'DS', 'NI') status, stg.ROWID
              FROM oe_order_headers_all oeh, oe_order_lines_all oel, oe_order_sources oes,
                   xxdo_inv_int_026_stg2 stg, apps.fnd_lookup_values_vl flv, apps.hr_operating_units hou,
                   apps.oe_transaction_types_tl ottl
             WHERE     oeh.header_id = oel.header_id
                   AND oeh.order_source_id = oes.order_source_id
                   AND oel.schedule_status_code = 'SCHEDULED'
                   AND oel.cancelled_flag = 'N'
                   AND oeh.creation_date >= TRUNC (SYSDATE - 7)
                   AND oes.name = 'Retail'
                   AND oeh.org_id = gn_org_id
                   AND oeh.order_type_id = ottl.transaction_type_id
                   AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND UPPER (flv.lookup_code) = UPPER (ottl.name)
                   AND hou.name = flv.tag
                   AND flv.description IN ('SHIP', 'LSHIP')
                   AND hou.organization_id = oeh.org_id
                   AND ottl.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND (flv.attribute1 = stg.dc_vw_id OR flv.attribute2 = stg.dc_vw_id OR flv.attribute3 = stg.dc_vw_id OR flv.attribute4 = stg.dc_vw_id OR flv.attribute5 = stg.dc_vw_id OR flv.attribute6 = stg.dc_vw_id OR flv.attribute7 = stg.dc_vw_id OR flv.attribute8 = stg.dc_vw_id OR flv.attribute9 = stg.dc_vw_id OR flv.attribute10 = stg.dc_vw_id OR flv.attribute11 = stg.dc_vw_id OR flv.attribute12 = stg.dc_vw_id OR flv.attribute13 = stg.dc_vw_id OR flv.attribute14 = stg.dc_vw_id OR flv.attribute15 = stg.dc_vw_id)
                   AND stg.requested_qty > 0
                   AND stg.distro_number = REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                          , 1)
                   AND TO_CHAR (stg.xml_id) = REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                             , 4)
                   AND TO_CHAR (stg.seq_no) = REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                             , 3)
                   AND 'RMS' || '-' || stg.dest_id || '-' || stg.dc_dest_id =
                       SUBSTR (oeh.orig_sys_document_ref,
                               1,
                                 INSTR (oeh.orig_sys_document_ref, '-', 1,
                                        3)
                               - 1)
                   AND stg.item_id = oel.inventory_item_id
                   AND NVL (stg.schedule_check, 'N') <> 'Y'
                   --Start Added as per ver CCR0009751
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo_inv_int_009_stg
                             WHERE     distro_number =
                                       SUBSTR (oel.orig_sys_line_ref,
                                               1,
                                                 INSTR (oel.orig_sys_line_ref, '-', 1
                                                        , 1)
                                               - 1)
                                   AND order_line_nbr = oel.line_id
                                   AND status = 'DS')
                   --End Added as per ver CCR0009751
                   AND NVL (stg.status, 0) = 1
            UNION ALL
            SELECT oeh.order_number, oeh.header_id, oel1.line_number order_line_num,
                   oel1.line_id, stg.distro_number, stg.dest_id,
                   stg.dc_dest_id, stg.document_type, oel1.ordered_quantity qty,
                   stg.xml_id, oel1.schedule_status_code, oeh.booked_flag,
                   oel1.inventory_item_id, DECODE (oel1.schedule_status_code, 'SCHEDULED', 'DS', 'NI') status, stg.ROWID
              FROM oe_order_headers_all oeh, oe_order_lines_all oel, oe_order_lines_all oel1,
                   oe_order_sources oes, xxdo_inv_int_026_stg2 stg, apps.fnd_lookup_values_vl flv,
                   apps.hr_operating_units hou, apps.oe_transaction_types_tl ottl
             WHERE     oel1.header_id = oeh.header_id
                   AND oel1.order_source_id = oes.order_source_id
                   AND oeh.order_source_id = oes.order_source_id
                   AND oel1.schedule_status_code = 'SCHEDULED'
                   AND oel.line_id = oel1.split_from_line_id
                   AND oeh.creation_date >= TRUNC (SYSDATE - 7)
                   AND oel1.split_from_line_id IS NOT NULL
                   AND oel1.cancelled_flag = 'N'
                   AND oel.cancelled_flag = 'N'
                   AND oes.name = 'Retail'
                   AND oeh.org_id = gn_org_id
                   AND oel1.open_flag = 'Y'
                   AND oel.open_flag = 'Y'
                   AND oeh.order_type_id = ottl.transaction_type_id
                   AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND UPPER (flv.lookup_code) = UPPER (ottl.name)
                   AND hou.name = flv.tag
                   AND flv.description IN ('SHIP', 'LSHIP')
                   AND hou.organization_id = oeh.org_id
                   AND ottl.language = 'US'
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND (flv.attribute1 = stg.dc_vw_id OR flv.attribute2 = stg.dc_vw_id OR flv.attribute3 = stg.dc_vw_id OR flv.attribute4 = stg.dc_vw_id OR flv.attribute5 = stg.dc_vw_id OR flv.attribute6 = stg.dc_vw_id OR flv.attribute7 = stg.dc_vw_id OR flv.attribute8 = stg.dc_vw_id OR flv.attribute9 = stg.dc_vw_id OR flv.attribute10 = stg.dc_vw_id OR flv.attribute11 = stg.dc_vw_id OR flv.attribute12 = stg.dc_vw_id OR flv.attribute13 = stg.dc_vw_id OR flv.attribute14 = stg.dc_vw_id OR flv.attribute15 = stg.dc_vw_id)
                   AND stg.distro_number = REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                          , 1)
                   AND TO_CHAR (stg.xml_id) = REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                             , 4)
                   AND TO_CHAR (stg.seq_no) = REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                             , 3)
                   AND 'RMS' || '-' || stg.dest_id || '-' || stg.dc_dest_id =
                       SUBSTR (oeh.orig_sys_document_ref,
                               1,
                                 INSTR (oeh.orig_sys_document_ref, '-', 1,
                                        3)
                               - 1)
                   AND stg.item_id = oel1.inventory_item_id
                   AND stg.item_id = oel.inventory_item_id
                   AND NVL (stg.schedule_check, 'N') <> 'Y'
                   --Start Added as per ver CCR0009751
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo_inv_int_009_stg
                             WHERE     distro_number =
                                       SUBSTR (oel.orig_sys_line_ref,
                                               1,
                                                 INSTR (oel.orig_sys_line_ref, '-', 1
                                                        , 1)
                                               - 1)
                                   AND order_line_nbr = oel1.line_id
                                   AND status = 'DS')
                   --End Added as per ver CCR0009751
                   AND NVL (stg.status, 0) = 1
                   AND stg.requested_qty > 0
            ORDER BY 1, 3;

        lv_errbuf        VARCHAR2 (100);
        lv_retcode       VARCHAR2 (100);
        l_debug_string   VARCHAR2 (4000);
        l_debug_header   VARCHAR2 (4000);
        ln_count         NUMBER := 0;
    BEGIN
        gc_enable_debug   := NVL (p_enable_debug, 'N');

        fnd_file.put_line (fnd_file.LOG, 'Debug flag :' || gc_enable_debug);

        FOR rec_order_sch IN cur_ds_lines
        LOOP
            insert_prc (lv_errbuf,
                        lv_retcode,
                        rec_order_sch.dc_dest_id,
                        rec_order_sch.distro_number,
                        rec_order_sch.document_type,
                        rec_order_sch.distro_number,
                        rec_order_sch.dest_id,
                        rec_order_sch.inventory_item_id,
                        --   rec_order_sch.order_line_num, --commented w.r.t CCR0009751
                        rec_order_sch.line_id,        --added w.r.t CCR0009751
                        rec_order_sch.qty,
                        rec_order_sch.status,
                        p_enable_debug);

            IF ln_count = 0
            THEN
                l_debug_header   :=
                       RPAD ('Order Num', 10)
                    || RPAD ('Line Num', 9)
                    || RPAD ('Distro Number', 15)
                    || RPAD ('Qty', 7)
                    || RPAD ('Book Flag', 10)
                    || RPAD ('Sch Status ', 11)
                    || RPAD ('Status', 20);
                debug_msg (l_debug_header);
            END IF;

            l_debug_string   := '';
            l_debug_string   :=
                   RPAD (rec_order_sch.order_number, 10)
                || RPAD (rec_order_sch.order_line_num, 9)
                || RPAD (rec_order_sch.distro_number, 15)
                || RPAD (rec_order_sch.qty, 7)
                || RPAD (rec_order_sch.booked_flag, 10)
                || RPAD (rec_order_sch.schedule_status_code, 11)
                || RPAD (rec_order_sch.status, 10);
            debug_msg (l_debug_string);
            ln_count         := ln_count + 1;


            BEGIN
                UPDATE xxdo_inv_int_026_stg2 stg
                   SET schedule_check   = 'Y'
                 WHERE stg.ROWID = rec_order_sch.ROWID;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while Updating Schedule Check DS '
                        || rec_order_sch.header_id
                        || ' - '
                        || rec_order_sch.line_id
                        || ' --- '
                        || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error In Procedure generate_ds_confirmation '
                || ' --- '
                || SQLERRM);
    END generate_ds_confirmation;

    -- ======================================================================================
    -- This procedure generate NI un-scheduled confirmation lines
    -- ======================================================================================
    PROCEDURE generate_ni_confirmation (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_enable_debug IN VARCHAR2
                                        , p_num_days IN NUMBER) --w.r.t CCR0009751
    AS
        CURSOR cur_ni_lines IS
            SELECT DISTINCT oeh.order_number, oeh.header_id, oel.line_number order_line_num,
                            oel.line_id, stg.distro_number, stg.dest_id,
                            stg.dc_dest_id, stg.document_type, --oel.ordered_quantity qty,     --Commented as per ver 1.1
                                                               oel.cancelled_quantity qty, --Added as per ver 1.1
                            stg.xml_id, oel.schedule_status_code, oeh.booked_flag,
                            oel.inventory_item_id, DECODE (oel.schedule_status_code, 'SCHEDULED', 'DS', 'NI') status, stg.ROWID
              FROM oe_order_headers_all oeh, oe_order_lines_all oel, oe_order_sources oes,
                   xxdo_inv_int_026_stg2 stg, apps.fnd_lookup_values_vl flv, apps.hr_operating_units hou,
                   apps.oe_transaction_types_tl ottl
             WHERE     oeh.header_id = oel.header_id
                   AND oeh.order_source_id = oes.order_source_id
                   AND oel.schedule_status_code IS NULL       -- This means NI
                   AND oel.cancelled_flag = 'Y'          --- line is cancelled
                   AND oes.name = 'Retail'
                   AND oeh.org_id = gn_org_id
                   AND oeh.creation_date >=
                       TRUNC (SYSDATE - NVL (p_num_days, 7))
                   AND oeh.order_type_id = ottl.transaction_type_id
                   AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND UPPER (flv.lookup_code) = UPPER (ottl.name)
                   AND hou.name = flv.tag
                   AND flv.description IN ('SHIP', 'LSHIP')
                   AND hou.organization_id = oeh.org_id
                   AND ottl.language = 'US'
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND (flv.attribute1 = stg.dc_vw_id OR flv.attribute2 = stg.dc_vw_id OR flv.attribute3 = stg.dc_vw_id OR flv.attribute4 = stg.dc_vw_id OR flv.attribute5 = stg.dc_vw_id OR flv.attribute6 = stg.dc_vw_id OR flv.attribute7 = stg.dc_vw_id OR flv.attribute8 = stg.dc_vw_id OR flv.attribute9 = stg.dc_vw_id OR flv.attribute10 = stg.dc_vw_id OR flv.attribute11 = stg.dc_vw_id OR flv.attribute12 = stg.dc_vw_id OR flv.attribute13 = stg.dc_vw_id OR flv.attribute14 = stg.dc_vw_id OR flv.attribute15 = stg.dc_vw_id)
                   AND stg.requested_qty > 0
                   AND stg.distro_number = REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                          , 1)
                   AND TO_CHAR (stg.xml_id) = REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                             , 4)
                   AND TO_CHAR (stg.seq_no) = REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                             , 3)
                   AND 'RMS' || '-' || stg.dest_id || '-' || stg.dc_dest_id =
                       SUBSTR (oeh.orig_sys_document_ref,
                               1,
                                 INSTR (oeh.orig_sys_document_ref, '-', 1,
                                        3)
                               - 1)
                   AND stg.item_id = oel.inventory_item_id
                   --AND NVL (stg.schedule_check, 'N') <> 'Y'   --Commented as per ver 1.1
                   --Start Added as per ver 1.1
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo_inv_int_009_stg
                             WHERE     distro_number =
                                       SUBSTR (oel.orig_sys_line_ref,
                                               1,
                                                 INSTR (oel.orig_sys_line_ref, '-', 1
                                                        , 1)
                                               - 1)
                                   -- AND order_line_nbr = oel.line_number -- Added for CCR0008282 (commented w.r.t CCR0009751)
                                   AND order_line_nbr = oel.line_id -- Added for CCR0009751
                                   AND status = 'NI')
                   --End Added as per ver 1.1
                   AND NVL (stg.status, 0) = 1
            UNION ALL
            SELECT oeh.order_number, oeh.header_id, oel1.line_number order_line_num,
                   oel1.line_id, stg.distro_number, stg.dest_id,
                   stg.dc_dest_id, stg.document_type, --oel1.ordered_quantity qty,  --Commented as per ver 1.1
                                                      oel1.cancelled_quantity qty, --Added as per ver 1.1
                   stg.xml_id, oel1.schedule_status_code, oeh.booked_flag,
                   oel1.inventory_item_id, DECODE (oel1.schedule_status_code, 'SCHEDULED', 'DS', 'NI') status, stg.ROWID
              FROM oe_order_headers_all oeh, oe_order_lines_all oel, oe_order_lines_all oel1,
                   oe_order_sources oes, xxdo_inv_int_026_stg2 stg, apps.fnd_lookup_values_vl flv,
                   apps.hr_operating_units hou, apps.oe_transaction_types_tl ottl
             WHERE     oel1.header_id = oeh.header_id
                   AND oel1.order_source_id = oes.order_source_id
                   AND oel1.schedule_status_code IS NULL
                   AND oeh.order_source_id = oes.order_source_id
                   AND oel.line_id = oel1.split_from_line_id
                   AND oel1.split_from_line_id IS NOT NULL
                   AND oel1.cancelled_flag = 'Y'
                   AND oeh.creation_date >=
                       TRUNC (SYSDATE - NVL (p_num_days, 7))
                   --  AND oel.cancelled_flag = 'Y'  --Commented w.r.t CCR0009751
                   AND oel1.cancelled_flag = 'Y'      --added w.r.t CCR0009751
                   AND oes.name = 'Retail'
                   AND oeh.org_id = gn_org_id
                   AND oeh.order_type_id = ottl.transaction_type_id
                   AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND UPPER (flv.lookup_code) = UPPER (ottl.name)
                   AND hou.name = flv.tag
                   AND flv.description IN ('SHIP', 'LSHIP')
                   AND hou.organization_id = oeh.org_id
                   AND ottl.language = 'US'
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND (flv.attribute1 = stg.dc_vw_id OR flv.attribute2 = stg.dc_vw_id OR flv.attribute3 = stg.dc_vw_id OR flv.attribute4 = stg.dc_vw_id OR flv.attribute5 = stg.dc_vw_id OR flv.attribute6 = stg.dc_vw_id OR flv.attribute7 = stg.dc_vw_id OR flv.attribute8 = stg.dc_vw_id OR flv.attribute9 = stg.dc_vw_id OR flv.attribute10 = stg.dc_vw_id OR flv.attribute11 = stg.dc_vw_id OR flv.attribute12 = stg.dc_vw_id OR flv.attribute13 = stg.dc_vw_id OR flv.attribute14 = stg.dc_vw_id OR flv.attribute15 = stg.dc_vw_id)
                   AND stg.distro_number = REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                          , 1)
                   AND TO_CHAR (stg.xml_id) = REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                             , 4)
                   AND TO_CHAR (stg.seq_no) = REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                             , 3)
                   AND 'RMS' || '-' || stg.dest_id || '-' || stg.dc_dest_id =
                       SUBSTR (oeh.orig_sys_document_ref,
                               1,
                                 INSTR (oeh.orig_sys_document_ref, '-', 1,
                                        3)
                               - 1)
                   AND stg.item_id = oel1.inventory_item_id
                   AND stg.item_id = oel.inventory_item_id
                   --AND NVL (stg.schedule_check, 'N') <> 'Y'     --Commented as per ver 1.1
                   --Start Added as per ver 1.1
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo_inv_int_009_stg
                             WHERE     distro_number =
                                       SUBSTR (oel.orig_sys_line_ref,
                                               1,
                                                 INSTR (oel.orig_sys_line_ref, '-', 1
                                                        , 1)
                                               - 1)
                                   -- AND order_line_nbr = oel.line_number -- Added for CCR0008282 (commented w.r.t CCR0009751)
                                   AND order_line_nbr = oel1.line_id -- Added for CCR0009751
                                   AND status = 'NI')
                   --End Added as per ver 1.1
                   AND NVL (stg.status, 0) = 1
                   AND stg.requested_qty > 0
            ORDER BY 1, 3;

        lv_errbuf        VARCHAR2 (100);
        lv_retcode       VARCHAR2 (100);
        l_debug_string   VARCHAR2 (4000);
        l_debug_header   VARCHAR2 (4000);
        ln_count         NUMBER := 0;
    BEGIN
        gc_enable_debug   := NVL (p_enable_debug, 'N');

        FOR rec_order_sch IN cur_ni_lines
        LOOP
            insert_prc (lv_errbuf,
                        lv_retcode,
                        rec_order_sch.dc_dest_id,
                        rec_order_sch.distro_number,
                        rec_order_sch.document_type,
                        rec_order_sch.distro_number,
                        rec_order_sch.dest_id,
                        rec_order_sch.inventory_item_id,
                        --   rec_order_sch.order_line_num, --commented w.r.t CCR0009751
                        rec_order_sch.line_id,        --added w.r.t CCR0009751
                        rec_order_sch.qty,
                        rec_order_sch.status,
                        p_enable_debug);

            IF ln_count = 0
            THEN
                l_debug_header   :=
                       RPAD ('Order Num', 10)
                    || RPAD ('Line Num', 9)
                    || RPAD ('Distro Number', 15)
                    || RPAD ('Qty', 7)
                    || RPAD ('Book Flag', 10)
                    || RPAD ('Sch Status ', 11)
                    || RPAD ('Status', 20);
                debug_msg (l_debug_header);
            END IF;

            l_debug_string   := '';
            l_debug_string   :=
                   RPAD (rec_order_sch.order_number, 10)
                || RPAD (rec_order_sch.order_line_num, 9)
                || RPAD (rec_order_sch.distro_number, 15)
                || RPAD (rec_order_sch.qty, 7)
                || RPAD (rec_order_sch.booked_flag, 10)
                || RPAD (rec_order_sch.schedule_status_code, 11)
                || RPAD (rec_order_sch.status, 10);
            debug_msg (l_debug_string);
            ln_count         := ln_count + 1;


            BEGIN
                UPDATE xxdo_inv_int_026_stg2 stg
                   -- SET schedule_check = 'Y'         --Commented as per ver 1.1
                   SET schedule_check   = 'N'           --Added as per ver 1.1
                 WHERE stg.ROWID = rec_order_sch.ROWID;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while Updating Schedule Check NI '
                        || rec_order_sch.header_id
                        || ' - '
                        || rec_order_sch.line_id
                        || ' --- '
                        || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error In Procedure generate_ni_confirmation '
                || ' --- '
                || SQLERRM);
    END generate_ni_confirmation;

    -- ======================================================================================
    -- This procedure performs order line split and schedules
    -- ======================================================================================
    PROCEDURE split_and_schedule (errbuf              OUT VARCHAR2,
                                  retcode             OUT VARCHAR2,
                                  p_enable_debug   IN     VARCHAR2)
    AS
        CURSOR cur_split_line IS
              SELECT COUNT (*), ooha.order_number, ooha.header_id,
                     ooha.booked_flag, ooha.org_id, stg.dc_vw_id
                FROM apps.oe_order_sources oes, apps.oe_order_headers_all ooha, apps.oe_transaction_types_tl ottt,
                     apps.hr_operating_units hou, apps.fnd_lookup_values_vl flv, apps.oe_order_lines_all oola,
                     apps.xxdo_inv_int_026_stg2 stg
               WHERE     oes.name = 'Retail'
                     AND ooha.order_source_id = oes.order_source_id
                     AND ooha.creation_date >= TRUNC (SYSDATE - 7)
                     AND ooha.org_id = gn_org_id
                     AND ottt.transaction_type_id = ooha.order_type_id
                     AND ottt.language = 'US'
                     AND UPPER (flv.lookup_code) = UPPER (ottt.name)
                     AND hou.organization_id = ooha.org_id
                     AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                     AND flv.description IN ('SHIP', 'LSHIP')
                     AND flv.enabled_flag = 'Y'
                     AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                     AND flv.tag = hou.name
                     AND oola.header_id = ooha.header_id
                     AND oola.cancelled_flag = 'N'
                     AND stg.distro_number = REGEXP_SUBSTR (oola.orig_sys_line_ref, '[^-]+', 1
                                                            , 1)
                     AND TO_CHAR (stg.xml_id) = REGEXP_SUBSTR (oola.orig_sys_line_ref, '[^-]+', 1
                                                               , 4)
                     AND TO_CHAR (stg.seq_no) = REGEXP_SUBSTR (oola.orig_sys_line_ref, '[^-]+', 1
                                                               , 3)
                     AND (stg.schedule_check IS NULL OR stg.schedule_check != 'Y')
                     AND (stg.status IS NOT NULL OR stg.status = 1)
                     AND stg.requested_qty > 0
                     AND stg.item_id = oola.inventory_item_id
                     AND stg.dc_vw_id IN
                             (flv.attribute11, flv.attribute9, flv.attribute2,
                              flv.attribute1, flv.attribute3, flv.attribute4,
                              flv.attribute5, flv.attribute6, flv.attribute7,
                              flv.attribute8, flv.attribute10, flv.attribute12,
                              flv.attribute13, flv.attribute14, flv.attribute15)
                     AND 'RMS' || '-' || stg.dest_id || '-' || stg.dc_dest_id =
                         SUBSTR (ooha.orig_sys_document_ref,
                                 1,
                                   INSTR (ooha.orig_sys_document_ref, '-', 1,
                                          3)
                                 - 1)
            GROUP BY ooha.order_number, ooha.header_id, ooha.booked_flag,
                     ooha.org_id, stg.dc_vw_id;

        lv_errbuf        VARCHAR2 (100);
        lv_retcode       VARCHAR2 (100);
        l_debug_string   VARCHAR2 (4000);
        l_debug_header   VARCHAR2 (4000);
        ln_count         NUMBER := 0;
    BEGIN
        gc_enable_debug   := NVL (p_enable_debug, 'N');

        FOR rec_split_line IN cur_split_line
        LOOP
            BEGIN
                do_oe_utils.split_and_schedule (
                    p_oi_header_id => rec_split_line.header_id);


                debug_msg ('Order Number :-' || rec_split_line.order_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while Doing Split and Schedule. Error Code : '
                        || SQLCODE
                        || '. Error Message : '
                        || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error In Procedure split_and_schedule '
                || ' --- '
                || SQLERRM);
    END split_and_schedule;

    -- ======================================================================================
    -- This procedure cancells the unscheduled order line
    -- ======================================================================================
    PROCEDURE cancel_unscheduled_lines (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_enable_debug IN VARCHAR2)
    AS
        CURSOR cur_headers IS
            SELECT ooha.order_number, ooha.header_id, ooha.org_id
              FROM apps.oe_order_sources oes, apps.oe_order_headers_all ooha, apps.oe_transaction_types_tl ottt,
                   apps.hr_operating_units hou, apps.fnd_lookup_values_vl flv, apps.oe_order_holds_all ooh,
                   apps.oe_hold_sources_all ohs, apps.oe_hold_definitions hd
             WHERE     oes.name = 'Retail'
                   AND ooha.order_source_id = oes.order_source_id
                   AND ooha.creation_date >= TRUNC (SYSDATE - 7)
                   AND ooha.org_id = gn_org_id
                   AND ottt.transaction_type_id = ooha.order_type_id
                   AND ottt.language = 'US'
                   AND UPPER (flv.lookup_code) = UPPER (ottt.name)
                   AND hou.organization_id = ooha.org_id
                   AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND flv.description IN ('SHIP', 'LSHIP')
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND flv.tag = hou.name
                   AND ooh.header_id = ooha.header_id
                   AND ooh.hold_source_id = ohs.hold_source_id
                   AND hd.hold_id = ohs.hold_id
                   AND ohs.released_flag = 'Y'
                   AND hd.name = 'RMS PICK HOLD'
                   AND EXISTS
                           (     -- has atleast one line which is not schedule
                            SELECT 1
                              FROM oe_order_lines_all ola1
                             WHERE     ola1.header_id = ooha.header_id
                                   AND schedule_status_code IS NULL
                                   AND cancelled_flag = 'N')
                   AND EXISTS            --- order has atleast one picked line
                           (SELECT 1
                              FROM oe_order_lines_all ola
                             WHERE     ola.header_id = ooha.header_id
                                   AND (   EXISTS
                                               (SELECT 1
                                                  FROM mtl_reservations mr
                                                 WHERE mr.demand_source_line_id =
                                                       ola.line_id)
                                        OR EXISTS
                                               (SELECT 1
                                                  FROM wsh_delivery_details wdd
                                                 WHERE     wdd.source_code =
                                                           'OE'
                                                       AND wdd.source_line_id =
                                                           ola.line_id
                                                       AND wdd.released_status IN
                                                               ('S', 'Y', 'C'))))
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_order_lines_all oola, apps.xxdo_inv_int_026_stg2 stg
                             WHERE     oola.header_id = ooha.header_id
                                   AND oola.cancelled_flag = 'N'
                                   AND oola.open_flag = 'Y'
                                   AND stg.distro_number =
                                       REGEXP_SUBSTR (oola.orig_sys_line_ref, '[^-]+', 1
                                                      , 1)
                                   AND TO_CHAR (stg.xml_id) =
                                       REGEXP_SUBSTR (oola.orig_sys_line_ref, '[^-]+', 1
                                                      , 4)
                                   AND TO_CHAR (stg.seq_no) =
                                       REGEXP_SUBSTR (oola.orig_sys_line_ref, '[^-]+', 1
                                                      , 3)
                                   AND (stg.schedule_check IS NULL OR stg.schedule_check != 'Y')
                                   AND (stg.status IS NOT NULL OR stg.status = 1)
                                   AND stg.requested_qty > 0
                                   AND stg.item_id = oola.inventory_item_id
                                   AND stg.dc_vw_id IN
                                           (flv.attribute11, flv.attribute9, flv.attribute2,
                                            flv.attribute1, flv.attribute3, flv.attribute4,
                                            flv.attribute5, flv.attribute6, flv.attribute7,
                                            flv.attribute8, flv.attribute10, flv.attribute12,
                                            flv.attribute13, flv.attribute14, flv.attribute15)
                                   AND    'RMS'
                                       || '-'
                                       || stg.dest_id
                                       || '-'
                                       || stg.dc_dest_id =
                                       SUBSTR (ooha.orig_sys_document_ref,
                                               1,
                                                 INSTR (ooha.orig_sys_document_ref, '-', 1
                                                        , 3)
                                               - 1)
                            UNION ALL
                            SELECT 1
                              FROM oe_order_lines_all oel, oe_order_lines_all oel1, xxdo_inv_int_026_stg2 stg1
                             WHERE     oel1.header_id = ooha.header_id
                                   AND oel.header_id = ooha.header_id
                                   AND oel.line_id = oel1.split_from_line_id
                                   AND oel1.split_from_line_id IS NOT NULL
                                   AND stg1.distro_number =
                                       REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                      , 1)
                                   AND TO_CHAR (stg1.xml_id) =
                                       REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                      , 4)
                                   AND TO_CHAR (stg1.seq_no) =
                                       REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                      , 3)
                                   AND    'RMS'
                                       || '-'
                                       || stg1.dest_id
                                       || '-'
                                       || stg1.dc_dest_id =
                                       SUBSTR (ooha.orig_sys_document_ref,
                                               1,
                                                 INSTR (ooha.orig_sys_document_ref, '-', 1
                                                        , 3)
                                               - 1)
                                   AND stg1.item_id = oel1.inventory_item_id
                                   AND stg1.item_id = oel.inventory_item_id);

        CURSOR cur_lines (p_header_id IN NUMBER)
        IS
            SELECT oel.header_id, oel.line_number || '.' || oel.shipment_number line_number, oel.line_id,
                   oel.ordered_quantity ordered_quantity
              FROM oe_order_lines_all oel
             WHERE     oel.header_id = p_header_id
                   AND oel.cancelled_flag = 'N'
                   AND oel.open_flag = 'Y'
                   AND oel.schedule_status_code IS NULL
                   /*AND NOT EXISTS  --- not a valid condition after checking with krishna to identify picked lines
                          (SELECT 1
                             FROM mtl_reservations mr
                            WHERE mr.demand_source_line_id = oel.line_id)*/
                   AND NOT EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd
                             WHERE     wdd.source_code = 'OE'
                                   AND wdd.source_line_id = oel.line_id
                                   AND wdd.released_status IN ('S', 'Y', 'C'));

        ln_msg_count               NUMBER (20);
        ln_msg_index_out           NUMBER;
        ln_line_tbl_count          NUMBER;
        ln_total_count             NUMBER := 0;
        lc_msg_data                VARCHAR2 (4000);
        lc_error_message           VARCHAR2 (4000);
        lc_return_status           VARCHAR2 (1);
        l_header_rec               oe_order_pub.header_rec_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
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
    BEGIN
        gc_enable_debug   := NVL (p_enable_debug, 'N');
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', gn_org_id);

        FOR rec_hdr IN cur_headers
        LOOP
            SAVEPOINT order_header;
            ln_total_count           := ln_total_count + 1;
            ln_msg_count             := 0;
            lc_return_status         := NULL;
            lc_msg_data              := NULL;
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            l_header_rec             := oe_order_pub.g_miss_header_rec;
            l_line_tbl               := oe_order_pub.g_miss_line_tbl;
            ln_line_tbl_count        := 0;

            -- Header Details
            l_header_rec.header_id   := rec_hdr.header_id;
            l_header_rec.operation   := oe_globals.g_opr_update;
            debug_msg ('Processing Order ' || rec_hdr.order_number);

            -- Line Details
            FOR rec_cancel_so IN cur_lines (rec_hdr.header_id)
            LOOP
                ln_line_tbl_count                                 := ln_line_tbl_count + 1;
                l_line_tbl (ln_line_tbl_count)                    :=
                    oe_order_pub.g_miss_line_rec;
                l_line_tbl (ln_line_tbl_count).header_id          :=
                    rec_hdr.header_id;
                l_line_tbl (ln_line_tbl_count).line_id            :=
                    rec_cancel_so.line_id;
                l_line_tbl (ln_line_tbl_count).cancelled_flag     := 'Y';
                l_line_tbl (ln_line_tbl_count).ordered_quantity   := 0;
                l_line_tbl (ln_line_tbl_count).change_reason      := 'SCH';
                l_line_tbl (ln_line_tbl_count).change_comments    :=
                       'Line cancelled by RMS Cancellation program on '
                    || SYSDATE
                    || ' by program request_id: '
                    || gn_request_id;
                l_line_tbl (ln_line_tbl_count).operation          :=
                    oe_globals.g_opr_update;
            END LOOP;

            oe_order_pub.process_order (
                p_org_id                   => gn_org_id,
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => lc_return_status,
                x_msg_count                => ln_msg_count,
                x_msg_data                 => lc_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
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
            debug_msg (
                'Order Lines Cancellation Status = ' || lc_return_status);

            ---------------------------------------------------------------------------------
            -- IF the API returns Error then the error message is displayed in log to track
            ---------------------------------------------------------------------------------
            IF lc_return_status <> 'S'
            THEN
                ROLLBACK TO order_header;

                FOR i IN 1 .. oe_msg_pub.count_msg
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                    , p_msg_index_out => ln_msg_index_out);
                    lc_error_message   := lc_error_message || lc_msg_data;
                END LOOP;

                lc_error_message   :=
                    NVL (lc_error_message, 'OE_ORDER_PUB Failed');
                debug_msg (lc_error_message);
            ELSE
                COMMIT;
            END IF;
        END LOOP;

        IF ln_total_count = 0
        THEN
            fnd_file.put_line (fnd_file.LOG, 'No Data Found');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in CANCEL_UNSCHEDULED_LINES - ' || SQLERRM);
    END cancel_unscheduled_lines;

    -- ======================================================================================
    -- This procedure cancells the unscheduled order line for DC Cutoff
    -- ======================================================================================
    PROCEDURE cancel_unsched_lines_cuttoff (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_enable_debug IN VARCHAR2)
    AS
        CURSOR cur_headers IS
            SELECT ooha.order_number, ooha.header_id, org_id
              FROM apps.oe_order_sources oes, apps.oe_order_headers_all ooha, apps.oe_transaction_types_tl ottt,
                   apps.hr_operating_units hou, apps.fnd_lookup_values_vl flv
             WHERE     oes.name = 'Retail'
                   AND ooha.order_source_id = oes.order_source_id
                   AND ooha.creation_date >= TRUNC (SYSDATE - 7)
                   AND ooha.org_id = gn_org_id
                   AND ottt.transaction_type_id = ooha.order_type_id
                   AND ottt.language = 'US'
                   AND UPPER (flv.lookup_code) = UPPER (ottt.name)
                   AND hou.organization_id = ooha.org_id
                   AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND flv.description IN ('SHIP', 'LSHIP')
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND flv.tag = hou.name
                   AND EXISTS
                           --- Select the header if one of the line is not picked to avoid picking up header when all the lines are picked
                           (SELECT 1
                              FROM oe_order_lines_all ola
                             WHERE     ola.header_id = ooha.header_id
                                   AND (NOT EXISTS
                                            (SELECT 1
                                               FROM wsh_delivery_details wdd
                                              WHERE     wdd.source_code =
                                                        'OE'
                                                    AND wdd.source_line_id =
                                                        ola.line_id
                                                    AND wdd.org_id =
                                                        ola.org_id
                                                    AND wdd.released_status IN
                                                            ('S', 'Y', 'C'))))
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_order_lines_all oola, apps.xxdo_inv_int_026_stg2 stg
                             WHERE     oola.header_id = ooha.header_id
                                   AND oola.cancelled_flag = 'N'
                                   AND oola.open_flag = 'Y'
                                   AND stg.distro_number =
                                       REGEXP_SUBSTR (oola.orig_sys_line_ref, '[^-]+', 1
                                                      , 1)
                                   AND TO_CHAR (stg.xml_id) =
                                       REGEXP_SUBSTR (oola.orig_sys_line_ref, '[^-]+', 1
                                                      , 4)
                                   AND TO_CHAR (stg.seq_no) =
                                       REGEXP_SUBSTR (oola.orig_sys_line_ref, '[^-]+', 1
                                                      , 3)
                                   /* AND (   stg.schedule_check IS NULL
                                         OR stg.schedule_check != 'Y') */
                                   AND (stg.status IS NOT NULL OR stg.status = 1)
                                   AND stg.requested_qty > 0
                                   AND stg.item_id = oola.inventory_item_id
                                   AND stg.dc_vw_id IN
                                           (flv.attribute11, flv.attribute9, flv.attribute2,
                                            flv.attribute1, flv.attribute3, flv.attribute4,
                                            flv.attribute5, flv.attribute6, flv.attribute7,
                                            flv.attribute8, flv.attribute10, flv.attribute12,
                                            flv.attribute13, flv.attribute14, flv.attribute15)
                                   AND    'RMS'
                                       || '-'
                                       || stg.dest_id
                                       || '-'
                                       || stg.dc_dest_id =
                                       SUBSTR (ooha.orig_sys_document_ref,
                                               1,
                                                 INSTR (ooha.orig_sys_document_ref, '-', 1
                                                        , 3)
                                               - 1)
                            UNION ALL
                            SELECT 1
                              FROM oe_order_lines_all oel, oe_order_lines_all oel1, xxdo_inv_int_026_stg2 stg1
                             WHERE     oel1.header_id = ooha.header_id
                                   AND oel.header_id = ooha.header_id
                                   AND oel.line_id = oel1.split_from_line_id
                                   AND oel1.split_from_line_id IS NOT NULL
                                   AND stg1.distro_number =
                                       REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                      , 1)
                                   AND TO_CHAR (stg1.xml_id) =
                                       REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                      , 4)
                                   AND TO_CHAR (stg1.seq_no) =
                                       REGEXP_SUBSTR (oel.orig_sys_line_ref, '[^-]+', 1
                                                      , 3)
                                   AND    'RMS'
                                       || '-'
                                       || stg1.dest_id
                                       || '-'
                                       || stg1.dc_dest_id =
                                       SUBSTR (ooha.orig_sys_document_ref,
                                               1,
                                                 INSTR (ooha.orig_sys_document_ref, '-', 1
                                                        , 3)
                                               - 1)
                                   AND stg1.item_id = oel1.inventory_item_id
                                   AND stg1.item_id = oel.inventory_item_id);

        -- pick all non picked lines and canclled
        CURSOR cur_lines (p_header_id IN NUMBER)
        IS
            SELECT oel.header_id, oel.line_number || '.' || oel.shipment_number line_number, oel.line_id,
                   oel.ordered_quantity ordered_quantity
              FROM oe_order_lines_all oel
             WHERE     oel.header_id = p_header_id
                   AND oel.cancelled_flag = 'N'
                   AND oel.open_flag = 'Y'
                   AND NOT EXISTS                               --- not picked
                           (SELECT 1
                              FROM wsh_delivery_details wdd
                             WHERE     wdd.source_code = 'OE'
                                   AND wdd.source_line_id = oel.line_id
                                   AND wdd.org_id = oel.org_id
                                   AND wdd.released_status IN ('S', 'Y', 'C'));

        ln_msg_count               NUMBER (20);
        ln_msg_index_out           NUMBER;
        ln_line_tbl_count          NUMBER;
        ln_total_count             NUMBER := 0;
        lc_msg_data                VARCHAR2 (4000);
        lc_error_message           VARCHAR2 (4000);
        lc_return_status           VARCHAR2 (1);
        l_header_rec               oe_order_pub.header_rec_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
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
    BEGIN
        gc_enable_debug   := NVL (p_enable_debug, 'N');
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', gn_org_id);

        FOR rec_hdr IN cur_headers
        LOOP
            SAVEPOINT order_header;
            ln_total_count           := ln_total_count + 1;
            ln_msg_count             := 0;
            lc_return_status         := NULL;
            lc_msg_data              := NULL;
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            l_header_rec             := oe_order_pub.g_miss_header_rec;
            l_line_tbl               := oe_order_pub.g_miss_line_tbl;
            ln_line_tbl_count        := 0;

            -- Header Details
            l_header_rec.header_id   := rec_hdr.header_id;
            l_header_rec.operation   := oe_globals.g_opr_update;
            debug_msg ('Processing Order ' || rec_hdr.order_number);

            -- Line Details
            FOR rec_cancel_so IN cur_lines (rec_hdr.header_id)
            LOOP
                debug_msg ('Processing Lines ' || rec_cancel_so.line_id);
                ln_line_tbl_count                                 := ln_line_tbl_count + 1;
                l_line_tbl (ln_line_tbl_count)                    :=
                    oe_order_pub.g_miss_line_rec;
                l_line_tbl (ln_line_tbl_count).header_id          :=
                    rec_hdr.header_id;
                l_line_tbl (ln_line_tbl_count).line_id            :=
                    rec_cancel_so.line_id;
                l_line_tbl (ln_line_tbl_count).cancelled_flag     := 'Y';
                l_line_tbl (ln_line_tbl_count).ordered_quantity   := 0;
                l_line_tbl (ln_line_tbl_count).change_reason      := 'SCH';
                l_line_tbl (ln_line_tbl_count).change_comments    :=
                       'Line cancelled by RMS DC CutOff RMS Cancellation program on '
                    || SYSDATE
                    || ' by program request_id: '
                    || gn_request_id;
                l_line_tbl (ln_line_tbl_count).operation          :=
                    oe_globals.g_opr_update;
            END LOOP;

            oe_order_pub.process_order (
                p_org_id                   => gn_org_id,
                p_api_version_number       => 1.0,
                p_init_msg_list            => fnd_api.g_false,
                p_return_values            => fnd_api.g_false,
                p_action_commit            => fnd_api.g_false,
                x_return_status            => lc_return_status,
                x_msg_count                => ln_msg_count,
                x_msg_data                 => lc_msg_data,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
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

            debug_msg (
                'Order Lines Cancellation Status = ' || lc_return_status);

            ---------------------------------------------------------------------------------
            -- IF the API returns Error then the error message is displayed in log to track
            ---------------------------------------------------------------------------------
            IF lc_return_status <> 'S'
            THEN
                ROLLBACK TO order_header;

                FOR i IN 1 .. oe_msg_pub.count_msg
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                    , p_msg_index_out => ln_msg_index_out);
                    lc_error_message   := lc_error_message || lc_msg_data;
                END LOOP;

                lc_error_message   :=
                    NVL (lc_error_message, 'OE_ORDER_PUB Failed');
                debug_msg (lc_error_message);
            ELSE
                COMMIT;
            END IF;
        END LOOP;

        IF ln_total_count = 0
        THEN
            fnd_file.put_line (fnd_file.LOG, 'No Data Found');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in CANCEL_UNSCHED_LINES_CUTTOFF - '
                || SQLERRM);
    END cancel_unsched_lines_cuttoff;

    -- ======================================================================================
    -- This procedure releases hold on the order
    -- ======================================================================================
    PROCEDURE release_hold (errbuf              OUT VARCHAR2,
                            retcode             OUT VARCHAR2,
                            p_enable_debug   IN     VARCHAR2)
    IS
        CURSOR order_holds_cur IS
            SELECT ooha.order_number, ooha.header_id, hd.hold_id,
                   ohs.hold_entity_code, ohs.hold_entity_id, ohs.hold_source_id,
                   hou.name operating_unit, oes.name order_source, ottt.name order_type
              FROM apps.oe_order_sources oes, apps.oe_order_headers_all ooha, apps.oe_transaction_types_tl ottt,
                   apps.hr_operating_units hou, apps.fnd_lookup_values_vl flv, apps.oe_order_holds_all ooh,
                   apps.oe_hold_sources_all ohs, apps.oe_hold_definitions hd
             WHERE     oes.name = 'Retail'
                   AND ooha.order_source_id = oes.order_source_id
                   AND ooha.org_id = gn_org_id
                   AND ottt.transaction_type_id = ooha.order_type_id
                   AND ottt.language = 'US'
                   AND UPPER (flv.lookup_code) = UPPER (ottt.name)
                   AND hou.organization_id = ooha.org_id
                   AND flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND flv.description IN ('SHIP', 'LSHIP')
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute_category = 'XXDO_RMS_SO_RMA_ALLOCATION'
                   AND flv.tag = hou.name
                   AND ooh.header_id = ooha.header_id
                   AND ooh.hold_source_id = ohs.hold_source_id
                   AND hd.hold_id = ohs.hold_id
                   AND ohs.released_flag = 'N'
                   AND hd.name = 'RMS PICK HOLD';

        ln_order_lines_count   NUMBER;
        ln_unscduled_per       NUMBER;
        ln_scduled_per         NUMBER;
        ln_threshold           NUMBER;
        l_order_tbl_type       oe_holds_pvt.order_tbl_type;
        lv_return_status       VARCHAR2 (20);
        ln_msg_count           NUMBER := 0;
        lv_msg_data            VARCHAR2 (2000);
        lv_error_message       VARCHAR2 (4000);
        ln_msg_index_out       NUMBER;
        lv_operating_unit      VARCHAR2 (2000);
        lv_order_source        VARCHAR2 (2000);
        lv_order_type          VARCHAR2 (2000);
        l_hold_release_rec     oe_holds_pvt.hold_release_rec_type;
        l_hold_source_rec      oe_holds_pvt.hold_source_rec_type;
        lv_inv_org             VARCHAR2 (200);
        ln_unscdule_count      NUMBER;
        ln_dest_org_id         NUMBER;
        l_debug_string         VARCHAR2 (4000);
        l_debug_header         VARCHAR2 (4000);
        ln_count               NUMBER;
    BEGIN
        gc_enable_debug   := NVL (p_enable_debug, 'N');

        FOR order_holds_rec IN order_holds_cur
        LOOP
            l_debug_string   := '';
            l_debug_header   := '';

            BEGIN ---  total number of active lines in the order; since all the lines has same warehouse for RMS;pick any
                ---  anyone using aggreate function
                SELECT COUNT (*), MIN (ship_from_org_id)
                  INTO ln_order_lines_count, ln_dest_org_id
                  FROM oe_order_lines_all oola
                 WHERE     oola.header_id = order_holds_rec.header_id
                       AND oola.cancelled_flag = 'N';
            EXCEPTION
                WHEN OTHERS
                THEN
                    debug_msg (
                           'Error while Getting Sales Order Lines01 '
                        || ' --- '
                        || SQLERRM);
            END;

            IF ln_order_lines_count <> 0
            THEN
                --- getting unshceduled lines count  to calculation % of lines scheduled from this order

                BEGIN
                    SELECT COUNT (*)
                      INTO ln_unscdule_count
                      FROM oe_order_lines_all a
                     WHERE     a.header_id = order_holds_rec.header_id
                           AND a.schedule_status_code IS NULL
                           AND cancelled_flag = 'N';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_unscdule_count   := 0;
                END;


                BEGIN
                    SELECT organization_code
                      INTO lv_inv_org
                      FROM mtl_parameters mp
                     WHERE 1 = 1 AND mp.organization_id = ln_dest_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        debug_msg (
                               'Error while Getting the Inventory org'
                            || ' --- '
                            || SQLERRM);
                END;

                ln_unscduled_per   :=
                    (ln_unscdule_count / ln_order_lines_count) * 100;
                ln_scduled_per   := 100 - ln_unscduled_per;

                --Get threshold from lookup
                BEGIN
                    SELECT attribute5
                      INTO ln_threshold
                      FROM fnd_lookup_values flvv
                     WHERE     lookup_type = 'XXD_RMS_PIK_HOLD_REL_THRESHOLD'
                           AND language = 'US'
                           AND attribute1 = order_holds_rec.operating_unit
                           AND attribute2 = order_holds_rec.order_source
                           AND attribute3 = order_holds_rec.order_type
                           AND attribute4 = lv_inv_org
                           AND flvv.enabled_flag = 'Y'
                           AND (TRUNC (SYSDATE) BETWEEN NVL (TRUNC (flvv.start_date_active), TRUNC (SYSDATE) - 1) AND NVL (TRUNC (flvv.end_date_active), TRUNC (SYSDATE) + 1));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        debug_msg (
                               'Error while Getting threshold '
                            || ' --- '
                            || SQLERRM);
                END;
            END IF;

            IF p_enable_debug = 'Y'
            THEN
                l_debug_string   :=
                       'operating_unit :'
                    || order_holds_rec.operating_unit
                    || ' order_source: '
                    || order_holds_rec.order_source
                    || ' order_type: '
                    || order_holds_rec.order_type
                    || ' inventory org %: '
                    || lv_inv_org;
                debug_msg (l_debug_string);
                l_debug_string   := '';
                l_debug_string   :=
                       'Order Number :'
                    || order_holds_rec.order_number
                    || ' Total Un schedule line: '
                    || ln_unscdule_count
                    || ' Total lines: '
                    || ln_order_lines_count
                    || ' Un schedule %: '
                    || ln_unscduled_per
                    || ' schedule %: '
                    || ln_scduled_per
                    || ' Threshold %: '
                    || ln_threshold;
                debug_msg (l_debug_string);
            END IF;

            IF ln_scduled_per >= ln_threshold OR ln_order_lines_count = 0 -- realease the hold for the order even if there is no line
            THEN
                lv_msg_data                              := NULL;
                ln_msg_count                             := NULL;
                lv_return_status                         := NULL;
                lv_error_message                         := NULL;
                ln_msg_index_out                         := 0;
                -- Call Process Order to release hold
                l_hold_source_rec.hold_id                := order_holds_rec.hold_id;
                l_hold_source_rec.hold_entity_code       :=
                    order_holds_rec.hold_entity_code;
                l_hold_source_rec.hold_entity_id         :=
                    order_holds_rec.hold_entity_id;
                l_hold_release_rec.hold_source_id        :=
                    order_holds_rec.hold_source_id;
                l_hold_release_rec.release_reason_code   := 'OM_MODIFY'; -- NEED TO CHECK AND CHANGE LATER ln_scduled_per >= ln_threshold
                l_hold_release_rec.release_comment       :=
                       'Hold released since scheduled threshold '
                    || ln_scduled_per
                    || ' is greater than '
                    || ln_threshold;         -- NEED TO CHECK AND CHANGE LATER
                l_hold_release_rec.request_id            :=
                    NVL (fnd_global.conc_request_id, -100);
                mo_global.init ('ONT');
                oe_holds_pub.release_holds (
                    p_api_version        => 1.0,
                    p_init_msg_list      => fnd_api.g_true,
                    p_commit             => fnd_api.g_false,
                    p_validation_level   => fnd_api.g_valid_level_none,
                    p_hold_source_rec    => l_hold_source_rec,
                    p_hold_release_rec   => l_hold_release_rec,
                    x_msg_count          => ln_msg_count,
                    x_msg_data           => lv_msg_data,
                    x_return_status      => lv_return_status);

                IF lv_return_status = 'S'
                THEN
                    COMMIT;
                    debug_msg (
                        'SUCCESSFUL released Hold:-' || order_holds_rec.order_number);
                ELSE
                    FOR i IN 1 .. oe_msg_pub.count_msg
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lv_msg_data
                                        , p_msg_index_out => ln_msg_index_out);

                        lv_error_message   := lv_error_message || lv_msg_data;
                    END LOOP;

                    debug_msg (
                           'API Error While Releasing Hold For Order: '
                        || order_holds_rec.order_number
                        || ' Error Is: '
                        || lv_error_message);
                    ROLLBACK;
                END IF;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error In Procedure release_hold ' || ' --- ' || SQLERRM);
    END release_hold;

    -- ======================================================================================
    -- This procedure inserts records in the custom table
    -- ======================================================================================
    PROCEDURE insert_prc (p_errfbuf              OUT VARCHAR2,
                          p_retcode              OUT VARCHAR2,
                          p_dc_dest_id        IN     NUMBER,
                          p_distro_no         IN     VARCHAR2,
                          p_distro_doc_type   IN     VARCHAR2,
                          p_cust_ord_no       IN     VARCHAR2,
                          p_dest_id           IN     NUMBER,
                          p_item_id           IN     NUMBER,
                          p_order_line_nbr    IN     NUMBER,
                          p_unit_qty          IN     NUMBER,
                          p_status            IN     VARCHAR2,
                          p_enable_debug      IN     VARCHAR2)
    IS
        v_dc_dest_id                   VARCHAR2 (100) := p_dc_dest_id;
        v_distro_no                    VARCHAR2 (100) := p_distro_no;
        v_distro_doc_type              VARCHAR2 (100) := p_distro_doc_type;
        v_cust_ord_no                  VARCHAR2 (100) := p_cust_ord_no;
        v_dest_id                      NUMBER := p_dest_id;
        v_item_id                      NUMBER := p_item_id;
        v_order_line_nbr               NUMBER := p_order_line_nbr;
        v_unit_qty                     NUMBER := p_unit_qty;
        v_status                       VARCHAR2 (100) := p_status;
        v_sku                          VARCHAR2 (100) := NULL;
        v_item_desc                    VARCHAR2 (100) := NULL;
        v_seq_no                       NUMBER := 0;
        v_rec_status                   VARCHAR2 (100) := NULL;
        v_transmission_date            DATE := NULL;
        v_error_code                   VARCHAR2 (240) := NULL;
        v_xml_data                     CLOB;
        lc_return                      CLOB;
        lv_wsdl_ip                     VARCHAR2 (25) := NULL;
        lv_wsdl_url                    VARCHAR2 (4000) := NULL;
        lv_namespace                   VARCHAR2 (4000) := NULL;
        lv_service                     VARCHAR2 (4000) := NULL;
        lv_port                        VARCHAR2 (4000) := NULL;
        lv_operation                   VARCHAR2 (4000) := NULL;
        lv_targetname                  VARCHAR2 (4000) := NULL;
        lx_xmltype_in                  SYS.XMLTYPE;
        lx_xmltype_out                 SYS.XMLTYPE;
        lv_errmsg                      VARCHAR2 (240) := NULL;
        l_http_request                 UTL_HTTP.req;
        l_http_response                UTL_HTTP.resp;
        l_buffer_size                  NUMBER (10) := 512;
        l_line_size                    NUMBER (10) := 50;
        l_lines_count                  NUMBER (10) := 20;
        l_string_request               CLOB;
        l_line                         VARCHAR2 (128);
        l_substring_msg                VARCHAR2 (512);
        l_raw_data                     RAW (512);
        l_clob_response                CLOB;
        lv_ip                          VARCHAR2 (100);
        buffer                         VARCHAR2 (32767);
        httpdata                       CLOB;
        eof                            BOOLEAN;
        xml                            CLOB;
        env                            VARCHAR2 (32767);
        resp                           XMLTYPE;
        v_xmldata                      CLOB := NULL;
        gv_xxdo_schedule_debug_value   VARCHAR2 (2) := NULL;


        CURSOR cur_int_009 IS
            SELECT 'A' temp,
                   (SELECT XMLELEMENT (
                               "v1:SOStatusDesc",
                               XMLELEMENT ("v1:dc_dest_id", v_dc_dest_id),
                               XMLELEMENT ("v1:distro_nbr", v_distro_no),
                               XMLELEMENT ("v1:distro_document_type",
                                           v_distro_doc_type),
                               XMLELEMENT (
                                   "v1:SOStatusDtl",
                                   XMLELEMENT ("v1:cust_order_nbr",
                                               v_order_line_nbr),
                                   XMLELEMENT ("v1:dest_id", v_dest_id),
                                   XMLELEMENT ("v1:item_id", v_item_id),
                                   XMLELEMENT ("v1:order_line_nbr",
                                               v_order_line_nbr),
                                   XMLELEMENT ("v1:unit_qty", v_unit_qty),
                                   XMLELEMENT ("v1:status", v_status) --XMLELEMENT ("v1:user_id",v_user_id),
                                                                     --XMLELEMENT ("v1:updated_date",null)
                                                                     ) -- SOStatusDtl
                                                                      ) xml -- SOStatusDesc
                      FROM DUAL) xml_data
              FROM DUAL;
    BEGIN
        BEGIN
            SELECT xxdo_int_009_seq.NEXTVAL INTO v_seq_no FROM DUAL;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'No Data Found When Getting The Value Of The Sequence');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Others Data Found When Getting The Value Of The Sequence');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
        END;


        BEGIN
            SELECT DECODE (applications_system_name,  'EBSPROD', apps.fnd_profile.VALUE ('XXDO: RETAIL PROD'), --Updated on 02-17-16
                                                                                                                'PCLN', apps.fnd_profile.VALUE ('XXDO: RETAIL DEV'),  apps.fnd_profile.VALUE ('XXDO: RETAIL TEST')) file_server_name
              INTO lv_wsdl_ip
              FROM apps.fnd_product_groups;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'No Data Found When Getting The IP');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Others Data Found When Getting The IP');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
        END;

        --------------------------------------------------------------
        -- Initializing the variables for calling the webservices
        -- The webservices takes the input parameter as wsd URL,
        -- name space, service, port, operation and target name
        --------------------------------------------------------------
        lv_wsdl_url   :=
               'http://'
            || lv_wsdl_ip
            || '//SOStatusPublishingBean/SOStatusPublishingService?WSDL';


        BEGIN
            INSERT INTO xxdo_inv_int_009_stg (dc_dest_id, distro_number, distro_doc_type, cust_order_nbr, dest_id, item_id, order_line_nbr, unit_qty, status
                                              , creation_date, seq_no)
                 VALUES (v_dc_dest_id, v_distro_no, v_distro_doc_type,
                         v_cust_ord_no, v_dest_id, v_item_id,
                         v_order_line_nbr, v_unit_qty, v_status,
                         SYSDATE, v_seq_no);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'No Data Found While Inserting Into The Custom Table');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Erroe Message :' || SQLERRM);
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Others Error While Inserting Into The Custom Table');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Erroe Message :' || SQLERRM);
        END;

        COMMIT;

        -------------------------------------------------------------------
        -- insert into the custom staging table : xxdo_inv_int_008
        -------------------------------------------------------------------
        FOR c_cur_int_009 IN cur_int_009
        LOOP
            /* v_xmldata := xmltype.getclobval (c_cur_int_009.xml_data);  -- commented as part of 2.0

              BEGIN
                 UPDATE xxdo_inv_int_009_stg
                    SET xmldata = xmltype.getclobval (c_cur_int_009.xml_data)
                  WHERE seq_no = v_seq_no;
              EXCEPTION
                 WHEN OTHERS
                 THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'No Data Found While Inserting The Data');
                    fnd_file.put_line (fnd_file.LOG, 'SQL Error Code:' || SQLCODE);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);

                    UPDATE xxdo_inv_int_009_stg
                       SET rec_status = 'VE', errorcode = 'Validation Error'
                     WHERE seq_no = v_seq_no;
              END;

              COMMIT;*/
            -- commented as part of 2.0

            -------------------------------------------------------------
            -- Assigning the variables to call the webservices function
            -------------------------------------------------------------
            IF p_enable_debug = 'Y'
            THEN
                debug_msg ('*********Begin:  XML Data**********');
                debug_msg (v_xmldata);
                debug_msg ('*********End:  XML Data**********');
            END IF;


            /* commented as part of 2.0

            l_string_request :=
                  '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"><soapenv:Header><v20:RoutingInfos xmlns:v20="http://www.oracle.com/retail/integration/bus/gateway/services/RoutingInfos/v1"><v20:routingInfo><name>consumer_direct</name><value>N</value></v20:routingInfo></v20:RoutingInfos></soapenv:Header><soapenv:Body><publishSOStatusCreateUsingSOStatusDesc xmlns="http://www.oracle.com/retail/igscustom/integration/services/SOStatusPublishingService/v1" xmlns:v1="http://www.oracle.com/retail/integration/base/bo/SOStatusDesc/v1" xmlns:v11="http://www.oracle.com/retail/integration/custom/bo/ExtOfSOStatusDesc/v1" xmlns:v12="http://www.oracle.com/retail/integration/base/bo/LocOfSOStatusDesc/v1" xmlns:v13="http://www.oracle.com/retail/integration/localization/bo/InSOStatusDesc/v1" xmlns:v14="http://www.oracle.com/retail/integration/custom/bo/EOfInSOStatusDesc/v1" xmlns:v15="http://www.oracle.com/retail/integration/localization/bo/BrSOStatusDesc/v1" xmlns:v16="http://www.oracle.com/retail/integration/custom/bo/EOfBrSOStatusDesc/v1">'
               || v_xmldata
               || '</publishSOStatusCreateUsingSOStatusDesc></soapenv:Body></soapenv:Envelope>';

      */
            --commented as part of 2.0

            IF p_enable_debug = 'Y'
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'STRING :' || l_string_request);
                debug_msg ('*********Begin : Request String**********');
                debug_msg (l_string_request);
                debug_msg ('*********End : Request String**********');
            END IF;

            BEGIN
                /* commented as part of 2.0
                    UTL_HTTP.set_transfer_timeout (60);

                            l_http_request :=
                               UTL_HTTP.begin_request (url            => lv_wsdl_url,
                                                       method         => 'POST',
                                                       http_version   => 'HTTP/1.1');

                            UTL_HTTP.set_header (l_http_request,
                                                 'User-Agent',
                                                 'Mozilla/4.0 (compatible)');
                            UTL_HTTP.set_header (l_http_request,
                                                 'Content-Type',
                                                 'text/xml; charset=utf-8');
                            UTL_HTTP.set_header (l_http_request,
                                                 'Content-Length',
                                                 LENGTH (l_string_request));
                            UTL_HTTP.set_header (l_http_request, 'SOAPAction', '');
                            UTL_HTTP.write_text (l_http_request, l_string_request);
                            ---------------------------------------
                            -- Below command will get the response
                            ---------------------------------------
                            l_http_response := UTL_HTTP.get_response (l_http_request);

                            ----------------------------------
                            -- Reading the text
                            ----------------------------------
                            BEGIN
                               UTL_HTTP.read_text (l_http_response, env);
                            EXCEPTION
                               WHEN UTL_HTTP.end_of_body
                               THEN
                                  UTL_HTTP.end_response (l_http_response);
                            END;

                            ----------------------------------------------------
                            -- If Env is null, which means response is null
                            ----------------------------------------------------
                            IF env IS NULL
                            THEN
                               fnd_file.put_line (fnd_file.LOG, 'No Response');
                            END IF;


                            UTL_HTTP.end_response (l_http_response);

                            IF p_enable_debug = 'Y'
                            THEN
                               debug_msg ('*********Begin:  XML Data**********');
                               debug_msg (env);
                               debug_msg ('*********End:  XML Data**********');
                            END IF;

                            resp := xmltype.createxml (env);

                            -----------------------------
                            -- If there is a response
                            -----------------------------
                            IF env IS NOT NULL
                            THEN
                               lc_return := env;

                               ------------------------------------------------------
                               -- update the staging table : xxdo_inv_int_009
                               ------------------------------------------------------
                               UPDATE xxdo_inv_int_009_stg
                                  SET retval = lc_return,
                                      processed_flag = 'Y',
                                      rec_status = 'P',
                                      transmission_date = SYSDATE
                                WHERE seq_no = v_seq_no;

                               COMMIT;
                            ---------------------------------------------
                            -- If there is no response from web services
                            ---------------------------------------------
                            ELSE
                               fnd_file.put_line (fnd_file.output, 'Response is NULL  ');
                               lc_return := NULL;


                               UPDATE xxdo_inv_int_009_stg
                                  SET retval = lc_return,
                                      rec_status = 'VE',
                                      transmission_date = SYSDATE
                                WHERE seq_no = v_seq_no;

                               COMMIT;
                            END IF;
                */
                -- commented as part of 2.0
                BEGIN
                    apps.wf_event.RAISE (p_event_name => 'oracle.apps.xxdo.retail_order_status_event', p_event_key => TO_CHAR (v_seq_no), p_event_data => NULL
                                         , p_parameters => NULL);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_errmsg   :=
                               'Error Message from event call :'
                            || apps.fnd_api.g_ret_sts_error
                            || ' SQL Error '
                            || SQLERRM;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error Message from event call :'
                            || apps.fnd_api.g_ret_sts_error
                            || ' SQL Error '
                            || SQLERRM);

                        UPDATE xxdo_inv_int_009_stg
                           SET rec_status = 'VE', errorcode = lv_errmsg
                         WHERE seq_no = v_seq_no;
                END;

                COMMIT;
            --Added as part of 2.0


            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_errmsg   := SQLERRM;


                    UPDATE xxdo_inv_int_009_stg
                       SET rec_status = 'VE', errorcode = lv_errmsg
                     WHERE seq_no = v_seq_no;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'PROBLEM IN SENDING THE MESSAGE DETAILS STORED IN THE ERRORCODE OF THE STAGING TABLE   '
                        || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error In Procedure insert_prc ' || ' --- ' || SQLERRM);
    END insert_prc;
END xxdo_ont_rms_so_confirm_pkg;
/
