--
-- XXDO_PO_CLOSE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_CLOSE_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  XXDO_PO_CLOSE_PKG.sql   1.0    2016/05/03    10:00:00   Bala Murugesan $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  XXDO_PO_CLOSE_PKG
    --
    -- Description  :  This package is to close the PO line
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 03-May-16    Bala Murugesan            1.0       Created
    -- ***************************************************************************



    PROCEDURE close_po_lines (pv_errbuf    OUT VARCHAR2,
                              pv_retcode   OUT VARCHAR2)
    IS
        --  ###################################################################################
        --
        --  System          : Oracle Applications
        --  Subsystem       : ASCP
        --  Project         : [ISC-205] 02003: Supply Planning
        --  Description     : Procedure to Close PO Lines
        --  Module          : Close PO Lines
        --  File            : close_po_lines_proc.sql
        --  Schema          : XXDO
        --  Date            : 27-Aug-2013
        --  Version         : 1.0
        --  Author(s)       : Abdul Gaffar [ Suneratech Consulting]
        --  Purpose         : Used to close po lines - New shipment status should be passed with one of the values - CLOSED, FINALLY CLOSED, CLOSED FOR RECEIVING or CLOSED FOR INVOICE
        --  dependency      : None
        --  Change History
        --  --------------
        --  Date            Name                Ver     Change                  Description
        --  ----------      --------------      -----   --------------------    ------------------
        --  27-Aug-2013     Abdul Gaffar      1.0                             Initial Version
        --  05-Sep-2013        Sachin Sonalkar   2.0       CHANGE-001        Added custom table and joins in the cursor.
        --
        --  ###################################################################################

        x_action                  VARCHAR2 (60) := 'CLOSE';
        x_calling_mode   CONSTANT VARCHAR2 (2) := 'PO';
        x_conc_flag      CONSTANT VARCHAR2 (1) := 'N';
        x_return_code_h           VARCHAR2 (100);
        x_auto_close     CONSTANT VARCHAR2 (1) := 'N';
        x_origin_doc_id           NUMBER;
        x_returned                BOOLEAN;
        ln_resp_id                NUMBER;
        ln_resp_appl_id           NUMBER;
        pn_conc_request_id        NUMBER := apps.fnd_global.conc_request_id;

        CURSOR c_po_details IS
              SELECT DISTINCT pha.po_header_id, pla.po_line_id, pla.line_num,
                              msi.segment1 item_name, pha.org_id, hou.name org_name,
                              pha.segment1, pha.agent_id, pdt.document_subtype,
                              pdt.document_type_code, NVL (pha.closed_code, 'OPEN') header_closed_status, NVL (pla.closed_code, 'OPEN') line_closed_status,
                              NVL (plla.closed_code, 'OPEN') shipment_closed_status, pha.closed_date header_closed_date, pla.closed_date line_closed_date,
                              xcpt.new_shipment_status
                FROM apps.po_headers_all pha, apps.po_document_types_all pdt, apps.po_lines_all pla,
                     apps.po_line_locations_all plla, apps.mtl_system_items_b msi, apps.mtl_item_categories mic,
                     apps.mtl_categories_b mc, apps.mtl_category_sets mcs, apps.hr_operating_units hou,
                     apps.po_agents_v pav, apps.ap_suppliers sup, apps.hr_locations ship_to,
                     apps.mtl_parameters mp, apps.hr_locations loc, xxdo_close_po_temp xcpt -- Added for CHANGE-001
               WHERE     pha.po_header_id = pla.po_header_id
                     AND pha.type_lookup_code = pdt.document_subtype
                     AND pha.org_id = pdt.org_id
                     AND pdt.document_type_code = 'PO'
                     --AND     pha.authorization_status = 'APPROVED'
                     AND NVL (pha.closed_code, 'OPEN') NOT IN
                             ('CLOSED', 'FINALLY CLOSED')
                     AND NVL (pla.closed_code, 'OPEN') NOT IN
                             ('CLOSED', 'FINALLY CLOSED')
                     AND NVL (pla.cancel_flag, 'N') = 'N'
                     AND pla.po_line_id = plla.po_line_id
                     AND pla.item_id = msi.inventory_item_id
                     AND msi.organization_id = plla.ship_to_organization_id
                     AND msi.inventory_item_id = mic.inventory_item_id
                     AND msi.organization_id = mic.organization_id
                     AND mic.category_set_id = mcs.category_set_id
                     AND mic.category_id = mc.category_id
                     AND mc.structure_id = mcs.structure_id
                     AND mcs.category_set_name = 'Inventory'
                     --               AND mc.segment2 = 'FOOTWEAR'
                     AND pha.org_id = hou.organization_id
                     AND pha.agent_id = pav.agent_id
                     AND pha.vendor_id = sup.vendor_id
                     AND pha.ship_to_location_id = ship_to.ship_to_location_id
                     AND plla.ship_to_organization_id = mp.organization_id
                     AND plla.ship_to_location_id = loc.ship_to_location_id
                     -- Added for CHANGE-001 -- Start
                     AND pha.segment1 = xcpt.po_number
                     AND pla.line_num = xcpt.line_number
                     AND hou.name = xcpt.org_description
            -- Added for CHANGE-001 -- End
            ORDER BY pha.segment1, pla.line_num;
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Program Start Time '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Purchase Order Number,PO Line Number,Item Number,Old Shipment Status, New Shipment Status,Status');

        FOR po_head IN c_po_details
        LOOP
            ln_resp_id        := NULL;
            ln_resp_appl_id   := NULL;

            BEGIN
                SELECT frv.responsibility_id, frv.application_id resp_application_id
                  INTO ln_resp_id, ln_resp_appl_id
                  FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
                 WHERE     fpo.user_profile_option_name =
                           'MO: Operating Unit'
                       AND fpo.profile_option_id = fpov.profile_option_id
                       AND fpov.level_value = frv.responsibility_id
                       AND frv.responsibility_name LIKE
                               'Deckers Purchasing User%'
                       AND fpov.profile_option_value =
                           TO_CHAR (po_head.org_id)
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Error getting Resp Id and Resp Appl Id:' || SQLERRM);
            END;

            apps.mo_global.init (po_head.document_type_code);
            apps.mo_global.set_policy_context ('S', po_head.org_id);
            apps.fnd_global.apps_initialize (pn_conc_request_id,
                                             ln_resp_id,
                                             ln_resp_appl_id);

            CASE
                WHEN UPPER (po_head.new_shipment_status) = 'CLOSED'
                THEN
                    x_action   := 'CLOSE';
                WHEN UPPER (po_head.new_shipment_status) = 'FINALLY CLOSED'
                THEN
                    x_action   := 'FINALLY CLOSE';
                WHEN UPPER (po_head.new_shipment_status) =
                     'CLOSED FOR RECEIVING'
                THEN
                    x_action   := 'RECEIVE CLOSE';
                WHEN UPPER (po_head.new_shipment_status) =
                     'CLOSED FOR INVOICE'
                THEN
                    x_action   := 'INVOICE CLOSE';
                ELSE
                    x_action   := 'CLOSE';
            END CASE;

            x_returned        :=
                apps.po_actions.close_po (p_docid => po_head.po_header_id, p_doctyp => po_head.document_type_code, p_docsubtyp => po_head.document_subtype, p_lineid => po_head.po_line_id, p_shipid => NULL, p_action => x_action, p_reason => NULL, p_calling_mode => x_calling_mode, p_conc_flag => x_conc_flag, p_return_code => x_return_code_h, p_auto_close => x_auto_close, p_action_date => SYSDATE
                                          , p_origin_doc_id => NULL);

            IF x_returned = TRUE
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       po_head.segment1
                    || ','
                    || po_head.line_num
                    || ','
                    || po_head.item_name
                    || ','
                    || po_head.shipment_closed_status
                    || ','
                    || po_head.new_shipment_status
                    || ','
                    || 'Success');

                COMMIT;
            ELSE
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       po_head.segment1
                    || ','
                    || po_head.line_num
                    || ','
                    || po_head.item_name
                    || ','
                    || po_head.shipment_closed_status
                    || ','
                    || po_head.new_shipment_status
                    || ','
                    || 'Failure');
            END IF;
        END LOOP;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Program End Time '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf    := 'Unexpected Error : ' || SQLERRM;
            pv_retcode   := '2';
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_errbuf);
    END close_po_lines;
END XXDO_PO_CLOSE_PKG;
/
