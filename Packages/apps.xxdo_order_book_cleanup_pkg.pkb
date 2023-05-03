--
-- XXDO_ORDER_BOOK_CLEANUP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ORDER_BOOK_CLEANUP_PKG"
--****************************************************************************************************
--*  NAME       : xxdo_ont_order_book_cleanup_pkg
--*  APPLICATION: Oracle Order Management
--*
--*  AUTHOR     : Sivakumar Boothathan
--*  DATE       : 08-Oct-2016
--*
--*  DESCRIPTION: This package will do the following
--*               A. It takes the input as Operating Unit
--*               B. Remove the orderride ATP for the lines for which the override ATP is set to Yes
--*               C. To copy the cancel date to LAD when LAD is null
--*               D. To sync the LAD with Cancel Date
--*  REVISION HISTORY:
--*  Change Date     Version             By                          Change Description
--****************************************************************************************************
--*  08-Oct-2016                    Siva Boothathan                  Initial Creation
--****************************************************************************************************
IS
    -------------------------------------------------------------
    -- Control procedure to navigate the control for the package
    -- Input Operating Unit
    -- Functionality :
    -- A. The input : Operating Unit is taken as the input Parameter
    -- B. Execute the delete scripts which will find the records
    -- in the interface table with the change sequence and delete
    -- C. Call the next procedures for ATP, LAD etc.
    -------------------------------------------------------------
    PROCEDURE main_control (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_operating_unit IN NUMBER
                            , p_change_sequence IN NUMBER)
    IS
        ----------------------
        -- Declaring Variables
        ----------------------
        v_ou_id             NUMBER := p_operating_unit;
        v_change_sequence   NUMBER := p_change_sequence;
        v_user_id           NUMBER := 0;
    -------------------------------------------------------
    -- This script will delete the error'ed records from
    -- oe_headers_iface_all and oe_lines_iface_all
    -- when the error_flag = Y and for this OU and change
    -- sequence
    -------------------------------------------------------
    BEGIN
        --------------------------
        -- To Get the Batch.O2F ID
        --------------------------
        SELECT user_id
          INTO v_user_id
          FROM apps.fnd_user
         WHERE user_name = 'BATCH.O2F';

        -----------------------------------

        -- Delete from oe_headers_iface_all
        -----------------------------------
        DELETE FROM
            apps.oe_headers_iface_all
              WHERE     operation_code = 'UPDATE'
                    AND org_id = v_ou_id
                    AND change_sequence = v_change_sequence;

        -----------------------------------
        -- Delete from oe_lines_iface_all
        -----------------------------------
        DELETE FROM
            apps.oe_lines_iface_all
              WHERE     operation_code = 'UPDATE'
                    AND org_id = v_ou_id
                    AND change_sequence = v_change_sequence;

        -----------------------------
        -- Committing the transaction
        -----------------------------
        COMMIT;
        ----------------------------------------------------------
        -- Calling a procedure to remove the override ATP
        ----------------------------------------------------------
        remove_override_atp (v_ou_id, v_change_sequence, v_user_id);
        --------------------------------------
        -- Calling a procedure to Sync the LAD
        --------------------------------------
        sync_lad (v_ou_id, v_change_sequence, v_user_id);

        --------------------------------------
        -- Calling a procedure to Sync the LAD
        --------------------------------------
        ssd_outside_lad (v_ou_id, v_change_sequence, v_user_id);
    EXCEPTION
        --------------------
        -- Exception Handler
        --------------------
        WHEN OTHERS
        THEN
            -----------
            -- Rollback
            -----------
            ROLLBACK;
            ----------------------
            -- Logging a message
            ----------------------
            fnd_file.put_line (fnd_file.LOG,
                               'Exception In the Procedure : Main Control');
            fnd_file.put_line (fnd_file.LOG, 'SQL Error COde :' || SQLCODE);
            fnd_file.put_line (fnd_file.LOG,
                               'SQL Error Message :' || SQLERRM);
    END;

    -------------------------------------------------------------
    -- Procedure to remove the override ATP
    -------------------------------------------------------------
    PROCEDURE remove_override_ATP (p_ou_id IN NUMBER, p_change_sequence IN NUMBER, p_user_id IN NUMBER)
    IS
    BEGIN
        ---------------------------------------------------
        -- Insert query to load up the oe_headers_iface_all
        -- and oe_lines_iface_all with the data which is
        -- having the override ATP is set to Y
        ---------------------------------------------------
        INSERT INTO apps.oe_headers_iface_all (orig_sys_document_ref,
                                               created_by,
                                               creation_date,
                                               last_updated_by,
                                               last_update_date,
                                               operation_code,
                                               header_id,
                                               org_id,
                                               order_source_id,
                                               change_sequence,
                                               force_apply_flag)
            SELECT /*+ parallel(2) */
                   DISTINCT ooh.orig_sys_document_ref, ooh.created_by, ooh.creation_date,
                            p_user_id, SYSDATE, 'UPDATE',
                            ooh.header_id, ooh.org_id, ooh.order_source_id,
                            p_change_sequence, 'Y'
              FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool
             WHERE     ooh.header_id = ool.header_id
                   AND ooh.org_id = p_ou_id
                   AND ool.line_category_code = 'ORDER'
                   AND ooh.open_flag = 'Y'
                   AND ool.open_flag = 'Y'
                   AND ool.schedule_ship_date IS NOT NULL
                   AND NVL (ool.override_atp_date_code, 'N') = 'Y'
                   AND EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_details
                             WHERE     source_line_id = ool.line_id
                                   AND released_status IN ('B', 'R'))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.mtl_reservations
                             WHERE ool.line_id = demand_source_line_id);

        ----------------------------------------------------------
        -- Insert query to load up the oe_lines_iface_all
        -- To load the override flag as N
        ---------------------------------------------------------
        INSERT INTO apps.oe_lines_iface_all (order_sourcE_id, orig_sys_document_ref, created_by, creation_date, last_updated_by, last_update_date, operation_code, line_id, orig_sys_line_ref, latest_acceptable_date, override_atp_date_code, org_id
                                             , change_sequence)
            SELECT /*+ parallel(2) */
                   ooh.order_source_id, ooh.orig_sys_document_ref, ool.created_by,
                   ool.creation_date, p_user_id, SYSDATE,
                   'UPDATE', ool.line_id, ool.orig_sys_line_ref,
                   TRUNC (TO_DATE (ool.attribute1, 'RRRR/MM/DD HH24:MI:SS')), 'N', ool.org_id,
                   p_change_sequence
              FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool
             WHERE     ooh.header_id = ool.header_id
                   AND ooh.org_id = p_ou_id
                   AND ool.schedule_ship_date IS NOT NULL
                   AND ool.line_category_code = 'ORDER'
                   AND ooh.open_flag = 'Y'
                   AND ool.open_flag = 'Y'
                   AND NVL (ool.override_atp_date_code, 'N') = 'Y'
                   AND EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_details
                             WHERE     source_line_id = ool.line_id
                                   AND released_status IN ('B', 'R'))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.mtl_reservations
                             WHERE ool.line_id = demand_source_line_id);

        -----------------------------
        -- Committing the transaction
        -----------------------------
        COMMIT;
    EXCEPTION
        --------------------
        -- Exception Handler
        --------------------
        WHEN OTHERS
        THEN
            -----------
            -- Rollback
            -----------
            ROLLBACK;
            ----------------------
            -- Logging a message
            ----------------------
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception In the Procedure : While Overriding ATP');
            fnd_file.put_line (fnd_file.LOG, 'SQL Error COde :' || SQLCODE);
            fnd_file.put_line (fnd_file.LOG,
                               'SQL Error Message :' || SQLERRM);
    END;

    -------------------------------------------------------------
    -- Procedure to adjust and sync the LAD
    -------------------------------------------------------------
    PROCEDURE sync_LAD (p_ou_id             IN NUMBER,
                        p_change_sequence   IN NUMBER,
                        p_user_id           IN NUMBER)
    IS
    BEGIN
        ---------------------------------------------------
        -- Insert query to load up the oe_headers_iface_all
        -- and oe_lines_iface_all with the data which is
        -- having the override ATP is set to Y
        ---------------------------------------------------
        INSERT INTO apps.oe_headers_iface_all (orig_sys_document_ref,
                                               created_by,
                                               creation_date,
                                               last_updated_by,
                                               last_update_date,
                                               operation_code,
                                               header_id,
                                               org_id,
                                               order_source_id,
                                               change_sequence,
                                               force_apply_flag)
            SELECT /*+ parallel(2) */
                   DISTINCT ooh.orig_sys_document_ref, ooh.created_by, ooh.creation_date,
                            p_user_id, SYSDATE, 'UPDATE',
                            ooh.header_id, ooh.org_id, ooh.order_source_id,
                            p_change_sequence, 'Y'
              FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool
             WHERE     ooh.header_id = ool.header_id
                   AND ooh.org_id = p_ou_id
                   AND ool.schedule_ship_date IS NOT NULL
                   AND ool.line_category_code = 'ORDER'
                   AND ooh.open_flag = 'Y'
                   AND ool.open_flag = 'Y'
                   AND (TRUNC (ool.latest_acceptable_date) IS NULL OR TRUNC (ool.latest_acceptable_date) <> TRUNC (TO_DATE (ool.attribute1, 'RRRR/MM/DD HH24:MI:SS')))
                   AND EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_details
                             WHERE     source_line_id = ool.line_id
                                   AND released_status IN ('B', 'R'))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.mtl_reservations
                             WHERE ool.line_id = demand_source_line_id)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.oe_headers_iface_all
                             WHERE     orig_sys_document_ref =
                                       ooh.orig_sys_document_ref
                                   AND change_sequence = p_change_sequence
                                   AND error_flag IS NULL
                                   AND request_id IS NULL);

        ----------------------------------------------------------
        -- Insert query to load up the oe_lines_iface_all
        -- To load the LAD when the LAD is null
        -- or not in sync with Cancel Date
        ---------------------------------------------------------
        INSERT INTO apps.oe_lines_iface_all (order_sourcE_id,
                                             orig_sys_document_ref,
                                             created_by,
                                             creation_date,
                                             last_updated_by,
                                             last_update_date,
                                             operation_code,
                                             line_id,
                                             orig_sys_line_ref,
                                             latest_acceptable_date,
                                             org_id,
                                             change_sequence)
            SELECT /*+ parallel(2) */
                   ooh.order_source_id, ooh.orig_sys_document_ref, ool.created_by,
                   ool.creation_date, p_user_id, SYSDATE,
                   'UPDATE', ool.line_id, ool.orig_sys_line_ref,
                   TRUNC (TO_DATE (ool.attribute1, 'RRRR/MM/DD HH24:MI:SS')), ool.org_id, p_change_sequence
              FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool
             WHERE     ooh.header_id = ool.header_id
                   AND ooh.org_id = p_ou_id
                   AND ool.schedule_ship_date IS NOT NULL
                   AND ool.line_category_code = 'ORDER'
                   AND ooh.open_flag = 'Y'
                   AND ool.open_flag = 'Y'
                   AND (TRUNC (ool.latest_acceptable_date) IS NULL OR TRUNC (ool.latest_acceptable_date) <> TRUNC (TO_DATE (ool.attribute1, 'RRRR/MM/DD HH24:MI:SS')))
                   AND EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_details
                             WHERE     source_line_id = ool.line_id
                                   AND released_status IN ('B', 'R'))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.mtl_reservations
                             WHERE ool.line_id = demand_source_line_id)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.oe_lines_iface_all
                             WHERE     orig_sys_document_ref =
                                       ooh.orig_sys_document_ref
                                   AND orig_sys_line_ref =
                                       ool.orig_sys_line_ref
                                   AND change_sequence = p_change_sequence
                                   AND error_flag IS NULL
                                   AND request_id IS NULL);

        -----------------------------
        -- Committing the transaction
        -----------------------------
        COMMIT;
    EXCEPTION
        --------------------
        -- Exception Handler
        --------------------
        WHEN OTHERS
        THEN
            -----------
            -- Rollback
            -----------
            ROLLBACK;
            ----------------------
            -- Logging a message
            ----------------------
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception In the Procedure : While to Keep LAD In SYNC');
            fnd_file.put_line (fnd_file.LOG, 'SQL Error COde :' || SQLCODE);
            fnd_file.put_line (fnd_file.LOG,
                               'SQL Error Message :' || SQLERRM);
    END;

    -------------------------------------------------------------
    -- Procedure to adjust and sync the LAD
    -------------------------------------------------------------
    PROCEDURE ssd_outside_LAD (p_ou_id IN NUMBER, p_change_sequence IN NUMBER, p_user_id IN NUMBER)
    IS
    BEGIN
        ---------------------------------------------------
        -- Insert query to load up the oe_headers_iface_all
        -- and oe_lines_iface_all with the data which is
        -- having the override ATP is set to Y
        ---------------------------------------------------
        INSERT INTO apps.oe_headers_iface_all (orig_sys_document_ref,
                                               created_by,
                                               creation_date,
                                               last_updated_by,
                                               last_update_date,
                                               operation_code,
                                               header_id,
                                               org_id,
                                               order_source_id,
                                               change_sequence,
                                               force_apply_flag)
            SELECT /*+ parallel(2) */
                   DISTINCT ooh.orig_sys_document_ref, ooh.created_by, ooh.creation_date,
                            p_user_id, SYSDATE, 'UPDATE',
                            ooh.header_id, ooh.org_id, ooh.order_source_id,
                            p_change_sequence, 'Y'
              FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool
             WHERE     ooh.header_id = ool.header_id
                   AND ooh.org_id = p_ou_id
                   AND ool.schedule_ship_date IS NOT NULL
                   AND ool.line_category_code = 'ORDER'
                   AND ooh.open_flag = 'Y'
                   AND ool.open_flag = 'Y'
                   AND (TRUNC (ool.schedule_ship_date) > TRUNC (ool.latest_acceptable_date) OR TRUNC (ool.schedule_ship_date) > TRUNC (TO_DATE (ool.attribute1, 'RRRR/MM/DD HH24:MI:SS')))
                   AND EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_details
                             WHERE     source_line_id = ool.line_id
                                   AND released_status IN ('B', 'R'))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.mtl_reservations
                             WHERE ool.line_id = demand_source_line_id)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.oe_headers_iface_all
                             WHERE     orig_sys_document_ref =
                                       ooh.orig_sys_document_ref
                                   AND change_sequence = p_change_sequence
                                   AND error_flag IS NULL
                                   AND request_id IS NULL);

        ----------------------------------------------------------
        -- Insert query to load up the oe_lines_iface_all
        -- To load the LAD when the LAD is null
        -- or not in sync with Cancel Date
        ---------------------------------------------------------
        INSERT INTO apps.oe_lines_iface_all (order_sourcE_id,
                                             orig_sys_document_ref,
                                             created_by,
                                             creation_date,
                                             last_updated_by,
                                             last_update_date,
                                             operation_code,
                                             line_id,
                                             orig_sys_line_ref,
                                             latest_acceptable_date,
                                             org_id,
                                             change_sequence)
            SELECT /*+ parallel(2) */
                   ooh.order_source_id, ooh.orig_sys_document_ref, ool.created_by,
                   ool.creation_date, p_user_id, SYSDATE,
                   'UPDATE', ool.line_id, ool.orig_sys_line_ref,
                   TRUNC (TO_DATE (ool.attribute1, 'RRRR/MM/DD HH24:MI:SS')), ool.org_id, p_change_sequence
              FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool
             WHERE     ooh.header_id = ool.header_id
                   AND ooh.org_id = p_ou_id
                   AND ool.schedule_ship_date IS NOT NULL
                   AND ool.line_category_code = 'ORDER'
                   AND ooh.open_flag = 'Y'
                   AND ool.open_flag = 'Y'
                   AND (TRUNC (ool.schedule_ship_date) > TRUNC (ool.latest_acceptable_date) OR TRUNC (ool.schedule_ship_date) > TRUNC (TO_DATE (ool.attribute1, 'RRRR/MM/DD HH24:MI:SS')))
                   AND EXISTS
                           (SELECT 1
                              FROM apps.wsh_delivery_details
                             WHERE     source_line_id = ool.line_id
                                   AND released_status IN ('B', 'R'))
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.mtl_reservations
                             WHERE ool.line_id = demand_source_line_id)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.oe_lines_iface_all
                             WHERE     orig_sys_document_ref =
                                       ooh.orig_sys_document_ref
                                   AND orig_sys_line_ref =
                                       ool.orig_sys_line_ref
                                   AND change_sequence = p_change_sequence
                                   AND error_flag IS NULL
                                   AND request_id IS NULL);

        -----------------------------
        -- Committing the transaction
        -----------------------------
        COMMIT;
    EXCEPTION
        --------------------
        -- Exception Handler
        --------------------
        WHEN OTHERS
        THEN
            -----------
            -- Rollback
            -----------
            ROLLBACK;
            ----------------------
            -- Logging a message
            ----------------------
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception In the Procedure : While to Keep LAD In SYNC');
            fnd_file.put_line (fnd_file.LOG, 'SQL Error COde :' || SQLCODE);
            fnd_file.put_line (fnd_file.LOG,
                               'SQL Error Message :' || SQLERRM);
    END;
END;
/
