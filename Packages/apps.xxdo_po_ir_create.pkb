--
-- XXDO_PO_IR_CREATE  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_IR_CREATE"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_po_ir_create.sql   1.0    2015/05/20    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_po_ir_create
    --
    -- Description  :  This is package  for creating Internal Requsition for Open POs.
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 20-May-2015  Infosys            1.0       Created
    -- 01-Jun-2015  Infosys            2.0       Modified for BT
    -- ***************************************************************************

    --------------------------------------------------------------------------------
    -- Procedure  : msg
    -- Description: procedure to print debug messages
    --------------------------------------------------------------------------------
    PROCEDURE msg (in_var_message IN VARCHAR2)
    IS
        c_num_debug   NUMBER := 1;
    BEGIN
        IF c_num_debug = 1
        THEN
            fnd_file.put_line (fnd_file.LOG, in_var_message);
        END IF;
    END msg;

    PROCEDURE main (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT NUMBER, p_from_whse IN VARCHAR2, p_to_whse IN VARCHAR2, p_srv_inv IN VARCHAR2, p_des_inv IN VARCHAR2, p_user IN VARCHAR, p_po_number IN VARCHAR, p_brand IN VARCHAR2
                    , p_gender IN VARCHAR2, p_prod_grp IN VARCHAR2)
    IS
        --Apps Initlialize parameters

        l_num_user_id            NUMBER;
        l_num_resp_id            NUMBER;
        l_num_resp_appl_id       NUMBER;

        l_num_hdr_id             NUMBER;
        l_num_ccid               NUMBER;
        l_num_del_to_loc_id      NUMBER;
        l_num_person_id          NUMBER;
        l_chr_source_code        VARCHAR2 (30);
        l_num_req_id             NUMBER;
        l_num_target_org_id      NUMBER;
        l_interface_batch_name   VARCHAR2 (100);
        l_num_count              NUMBER := 0;

        CURSOR cur_po_details IS
            SELECT poh.segment1, msi.concatenated_segments item_number, msi.inventory_item_id,
                   (poll.quantity - NVL (poll.quantity_cancelled, 0) - NVL (poll.quantity_received, 0)) qty, muom.uom_code uom, poll.promised_date,
                   mp.organization_code frm_wh, mp.organization_id frm_wh_id
              FROM po_headers_all poh, po_lines_all pol, po_line_locations_all poll,
                   mtl_system_items_kfv msi, mtl_parameters mp, mtl_uom_conversions muom,
                   mtl_categories_b mc, mtl_item_categories mic
             WHERE     poh.po_header_id = pol.po_header_id
                   AND poh.segment1 = NVL (p_po_number, poh.segment1)
                   AND poh.approved_flag = 'Y'
                   AND pol.po_line_id = poll.po_line_id
                   AND poll.ship_to_organization_id = mp.organization_id
                   AND poll.closed_code = 'OPEN'
                   AND pol.item_id = msi.inventory_item_id
                   AND msi.organization_id = mp.organization_id
                   AND mc.category_id = mic.category_id                --Start
                   AND msi.organization_id = mic.organization_id
                   AND mic.category_set_id = 1
                   AND mic.inventory_item_id = msi.inventory_item_id
                   AND mc.segment1 = NVL (p_brand, mc.segment1)
                   AND mc.segment2 = NVL (p_gender, mc.segment2)
                   AND mc.segment3 = NVL (p_prod_grp, mc.segment3)      --Ends
                   AND mp.organization_code =
                       NVL (p_from_whse, mp.organization_code)
                   AND muom.unit_of_measure =
                       NVL (poll.unit_meas_lookup_code,
                            pol.unit_meas_lookup_code)
                   AND muom.inventory_item_id = 0
                   AND (poll.quantity - NVL (poll.quantity_cancelled, 0) - NVL (poll.quantity_received, 0)) >
                       0
                   /*  Not IRIS */
                   AND NOT EXISTS
                           (SELECT 1
                              FROM Apps.Oe_Order_Lines_All Oola
                             WHERE     Attribute16 =
                                       TO_CHAR (Poll.Line_Location_Id)
                                   AND Oola.Org_Id = Poll.Org_Id);
    BEGIN
        msg ('Beginning of the program');

        msg ('Input Parameters Received From Warehouse  ' || p_from_whse);
        msg ('To Warehouse  ' || p_to_whse);
        msg ('Source Subinventory  ' || p_srv_inv);
        msg ('Destination Subinventory  ' || p_des_inv);
        msg ('PO Number  ' || p_po_number);

        SELECT responsibility_id, application_id
          INTO l_num_resp_id, l_num_resp_appl_id
          FROM apps.fnd_responsibility_vl
         WHERE responsibility_name = 'Purchasing Super User'; -- Modified for BT

        msg (
               'Responsibility and Application ID  derived  '
            || l_num_resp_id
            || l_num_resp_appl_id);

        SELECT material_account, organization_id
          INTO l_num_ccid, l_num_target_org_id
          FROM apps.mtl_parameters
         WHERE organization_code = p_to_whse;


        msg ('material_account derived  ' || l_num_ccid);

        msg ('Target_org_id derived  ' || l_num_target_org_id);

        SELECT location_id
          INTO l_num_del_to_loc_id
          FROM apps.hr_organization_units_v
         WHERE organization_id = l_num_target_org_id;

        msg ('Location_id derived  ' || l_num_del_to_loc_id);


        SELECT employee_id, user_id
          INTO l_num_person_id, l_num_user_id
          FROM apps.fnd_user
         WHERE user_name = p_user;

        msg ('employee_id derived  ' || l_num_person_id);
        msg ('User ID  derived  ' || l_num_user_id);

        l_interface_batch_name   := 'BTCONV-' || p_po_number;

        FOR cur_po_details_rec IN cur_po_details
        LOOP
            INSERT INTO po_requisitions_interface_all (
                            Interface_source_code,
                            Requisition_type,
                            Org_id,
                            Authorization_status,
                            Charge_account_id,
                            quantity,
                            uom_code,
                            group_code,
                            item_id,
                            Preparer_id,
                            deliver_to_requestor_id,
                            Source_type_code,
                            source_organization_id,
                            source_subinventory,
                            destination_type_code,
                            destination_organization_id,
                            destination_subinventory,
                            deliver_to_location_id,
                            --               batch_id
                            need_by_date,
                            --              transaction_id,
                            creation_date,
                            created_by,
                            last_update_date,
                            last_updated_by)
                 VALUES (l_interface_batch_name, --'INV', -- interface_source_code
                                                 'INTERNAL', -- Requisition_type
                                                             95, --g_num_org_id , --Org_id of the given operating unit
                         'INCOMPLETE',                 -- Authorization_Status
                                       l_num_ccid,               -- Valid ccid
                                                   cur_po_details_rec.qty, -- Quantity
                         cur_po_details_rec.uom,                   -- UOm Code
                                                 cur_po_details_rec.segment1, cur_po_details_rec.inventory_item_id, --     SYSDATE, -- neeed by date
                                                                                                                    l_num_person_id, -- Person id of the preparer
                                                                                                                                     l_num_person_id, -- Person_id of the requestor
                                                                                                                                                      'INVENTORY', -- source_type_code
                                                                                                                                                                   cur_po_details_rec.frm_wh_id, -- Source org id - US4
                                                                                                                                                                                                 p_srv_inv, --- source subinventory
                                                                                                                                                                                                            'INVENTORY', -- destination_type_code
                                                                                                                                                                                                                         l_num_target_org_id, -- Destination org id - US1
                                                                                                                                                                                                                                              p_des_inv, -- destination sub inventory
                                                                                                                                                                                                                                                         l_num_del_to_loc_id, --                g_num_request_id
                                                                                                                                                                                                                                                                              cur_po_details_rec.promised_date, -- neeed by date
                                                                                                                                                                                                                                                                                                                --                 l_num_trans_interface_id,
                                                                                                                                                                                                                                                                                                                SYSDATE, l_num_user_id
                         , SYSDATE, l_num_user_id);

            l_num_count   := SQL%ROWCOUNT;

            COMMIT;
        END LOOP;

        apps.fnd_global.apps_initialize (user_id        => l_num_user_id,
                                         resp_id        => l_num_resp_id,
                                         resp_appl_id   => l_num_resp_appl_id);

        IF l_num_count >= 1
        THEN
            BEGIN
                l_num_req_id   :=
                    fnd_request.submit_request (
                        application   => 'PO',       -- application short name
                        program       => 'REQIMPORT',    -- program short name
                        description   => 'Requisition Import',  -- description
                        start_time    => SYSDATE,                -- start date
                        sub_request   => FALSE,                 -- sub-request
                        argument1     => l_interface_batch_name, -- interface source code
                        argument2     => NULL,                     -- Batch Id
                        argument3     => 'ALL',                    -- Group By
                        argument4     => NULL,      -- Last Requisition Number
                        argument5     => NULL,          -- Multi Distributions
                        argument6     => 'Y' -- Initiate Requisition Approval after Requisition Import
                                            );
                COMMIT;
                msg ('Request Id Submitted' || l_num_req_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg (
                           'Error Occured while submitting Requisition Import '
                        || SQLERRM);
                    p_out_chr_errbuf    := SQLERRM;
                    p_out_chr_retcode   := 2;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Error Occured in Main Program ' || SQLERRM);
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := 2;
    END main;
END;
/
