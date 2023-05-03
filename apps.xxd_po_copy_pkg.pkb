--
-- XXD_PO_COPY_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_COPY_PKG"
AS
    /*******************************************************************************
       * Program Name : xxd_po_copy_pkg
       * Language     : PL/SQL
       * Description  : This package is used by PO copy form
       *
       * History      :
       *
       * WHO            WHAT              Desc                             WHEN
       * -------------- ---------------------------------------------- ---------------
       * BT Technology          1.0 - Initial Version                        Feb/15/2015
       * BT Technology          1.1 - Drop ship PO Issue modification        May/29/2015
       * BT Technology          1.2 - Modified for defect#108                Oct/26/2015
       * BT Technology          1.3 - Modified for Defect 530                Nov/16/2015
       * Bala Murugesan         1.4 - Modified to fix the bug where
       *                              incorrect style/color combinations     Mar/03/2017
       *                              are copied or moved; Changes
       *                              identified by INCORRECT_COMBINATIONS
       * Bala Murugesan         1.1 - Modified to add logic to copy/move
       *                              PO to a new warehouse;                  Mar/03/2017
       *                              Changes identified by
       *                              PO_COPY_TO_NEW_ORG
       * Infosys                1.5 - Modified to add logic to Cancel the    Sep/12/2017
       *                              linked requisition lines for the
       *                              cancelled POs.
       *                              Changed the logic to send the GTN flag
       *                              information to the new POs.
       *                              Modified the logic so as to fetch the
       *                              supplier information from the Old POs.
       *                              Changes identified by CCR0006633.
       * Infosys                1.6 - Modifed for CCR0007264; IDENTIFIED by CCR0007264
       *                              Changed the logic to create new Requisition 28/05/2018
       *                              before adding or creating new PO lines
       * Viswanathan Pandian    1.7 - Modified for CCR0007445                 22-Aug-2018
       * --------------------------------------------------------------------------- */

    --Begin CCR0007619
    PROCEDURE XXDO_PO_APPROVAL (p_po_num IN VARCHAR2, P_org_id IN NUMBER, p_error_code OUT VARCHAR2
                                , P_ERROR_TEXT OUT VARCHAR2)
    IS
        l_api_errors             PO_API_ERRORS_REC_TYPE;
        v_po_header_id           NUMBER;
        v_org_id                 NUMBER;
        v_po_num                 VARCHAR2 (50);
        v_doc_type               VARCHAR2 (50);
        v_doc_sub_type           VARCHAR2 (50);
        l_return_status          VARCHAR2 (1);
        l_api_version   CONSTANT NUMBER := 2.0;
        l_api_name      CONSTANT VARCHAR2 (50) := 'UPDATE_DOCUMENT';
        g_pkg_name      CONSTANT VARCHAR2 (30) := 'PO_DOCUMENT_UPDATE_GRP';
        l_progress               VARCHAR2 (3) := '000';
        v_agent_id               NUMBER;
        ---
        v_item_key               VARCHAR2 (100);
        v_resp_appl_id           NUMBER;
        v_resp_id                NUMBER;
        v_user_id                NUMBER;
    --
    BEGIN
        v_org_id          := p_org_id;
        v_po_num          := p_po_num;

        BEGIN
            SELECT pha.po_header_id, pha.agent_id, pdt.document_subtype,
                   pdt.document_type_code, pha.wf_item_key
              INTO v_po_header_id, v_agent_id, v_doc_sub_type, v_doc_type,
                                 v_item_key
              FROM apps.po_headers_all pha, apps.po_document_types_all pdt
             WHERE     pha.type_lookup_code = pdt.document_subtype
                   AND pha.org_id = v_org_id
                   AND pdt.document_type_code = 'PO'
                   AND segment1 = v_po_num;

            --
            l_progress   := '001';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error_code   := 0;
        END;

        v_resp_appl_id    := fnd_global.resp_appl_id;
        v_resp_id         := fnd_global.resp_id;
        v_user_id         := fnd_global.user_id;
        APPS.fnd_global.APPS_INITIALIZE (v_user_id,
                                         v_resp_id,
                                         v_resp_appl_id);
        APPS.mo_global.init ('PO');
        --calling seeded procedure to launch the po approval workflow
        --
        po_reqapproval_init1.start_wf_process (ItemType => 'POAPPRV', ItemKey => v_item_key, WorkflowProcess => 'XXDO_POAPPRV_TOP', ActionOriginatedFrom => 'PO_FORM', DocumentID => v_po_header_id -- po_header_id
                                                                                                                                                                                                   , DocumentNumber => v_po_num -- Purchase Order Number
                                                                                                                                                                                                                               , PreparerID => v_agent_id -- Buyer/Preparer_id
                                                                                                                                                                                                                                                         , DocumentTypeCode => 'PO' --'PO'
                                                                                                                                                                                                                                                                                   , DocumentSubtype => 'STANDARD' --'STANDARD'
                                                                                                                                                                                                                                                                                                                  , SubmitterAction => 'APPROVE', forwardToID => NULL, forwardFromID => NULL, DefaultApprovalPathID => NULL, Note => NULL, PrintFlag => 'N', FaxFlag => 'N', FaxNumber => NULL, EmailFlag => 'N', EmailAddress => NULL, CreateSourcingRule => 'N', ReleaseGenMethod => 'N', UpdateSourcingRule => 'N', MassUpdateReleases => 'N', RetroactivePriceChange => 'N', OrgAssignChange => 'N', CommunicatePriceChange => 'N', p_Background_Flag => 'N', p_Initiator => NULL, p_xml_flag => NULL, FpdsngFlag => 'N'
                                               , p_source_type_code => NULL);
        --
        l_progress        := '002';
        l_return_status   := FND_API.G_RET_STS_SUCCESS;

        IF (l_return_status = 'S')
        THEN
            p_error_code   := 1;
            P_ERROR_TEXT   := 'S';
        --
        ELSE
            p_error_code   := 0;
            P_ERROR_TEXT   := 'F';
        END IF;

        l_progress        := '003';
    EXCEPTION
        WHEN FND_API.G_EXC_UNEXPECTED_ERROR
        THEN
            p_error_code   := 0;
            p_error_text   := SQLERRM;
        WHEN OTHERS
        THEN
            p_error_text   := SQLERRM;
            p_error_code   := 0;
    END XXDO_PO_APPROVAL;

    --End CCR0007619

    PROCEDURE xxd_cancel_po_lines (p_header_id    IN     NUMBER,
                                   p_style        IN     xxd_po_copy_style,
                                   p_color        IN     xxd_po_copy_color,
                                   p_error_code      OUT VARCHAR2,
                                   p_po_line_id      OUT xxd_po_line_type)
    IS
        -- INCORRECT_COMBINATIONS - Start
        /*
        CURSOR cur_cancel_lines
         IS
            SELECT pol.*, PRLA.REQUISITION_LINE_ID
              FROM po_headers_all poh,
                   po_lines_all pol,
                   po_line_locations_all poll,
                   po_requisition_lines_all prla,
                   po_req_distributions_all prda,
                   po_distributions_all pda,
                   mtl_item_categories mic,
                   MTL_CATEGORIES_B mcb,
                   MTL_CATEGORY_SETS_VL MCS
             WHERE     poh.po_header_id = P_HEADER_ID
                   AND poh.po_header_id = pol.po_header_id
                   AND pol.po_header_id = poll.po_header_id
                   AND pol.po_line_id = poll.po_line_id
                   AND poll.closed_code = 'OPEN'
                   AND poll.QUANTITY_RECEIVED = 0
                   AND pol.quantity != 0
                   AND pda.po_line_id = pol.po_line_id
                   AND pda.po_header_id = poh.po_header_id
                   AND pda.req_distribution_id = prda.distribution_id(+)
                   AND prda.requisition_line_id = prla.requisition_line_id(+)
                   AND POLL.ship_to_organization_id = MIC.organization_id
                   AND pol.item_id = mic.inventory_item_id
                   AND MCS.CATEGORY_SET_ID = MIC.CATEGORY_SET_ID
                   AND MCS.CATEGORY_SET_NAME = 'Inventory'
                   AND mic.category_id = mcb.category_id
                   AND MCB.attribute_category = 'Item Categories'
                   AND mcb.attribute7 IN (SELECT * FROM TABLE (p_style))
                   AND mcb.attribute8 IN (SELECT * FROM TABLE (P_COLOR))
                   ;
          */

        CURSOR cur_cancel_lines (p_current_style   VARCHAR2,
                                 p_current_color   VARCHAR2)
        IS
            SELECT pol.*, prla.requisition_line_id
              FROM po_headers_all poh, po_lines_all pol, po_line_locations_all poll,
                   po_requisition_lines_all prla, po_req_distributions_all prda, po_distributions_all pda,
                   mtl_item_categories mic, mtl_categories_b mcb, mtl_category_sets_vl mcs
             WHERE     poh.po_header_id = p_header_id
                   AND poh.po_header_id = pol.po_header_id
                   AND pol.po_header_id = poll.po_header_id
                   AND pol.po_line_id = poll.po_line_id
                   AND poll.closed_code = 'OPEN'
                   AND poll.quantity_received = 0
                   AND pol.quantity != 0
                   AND pda.po_line_id = pol.po_line_id
                   AND pda.po_header_id = poh.po_header_id
                   AND pda.req_distribution_id = prda.distribution_id(+)
                   AND prda.requisition_line_id = prla.requisition_line_id(+)
                   AND poll.ship_to_organization_id = mic.organization_id
                   AND pol.item_id = mic.inventory_item_id
                   AND mcs.category_set_id = mic.category_set_id
                   AND mcs.category_set_name = 'Inventory'
                   AND mic.category_id = mcb.category_id
                   AND mcb.attribute_category = 'Item Categories'
                   AND mcb.attribute7 = p_current_style
                   AND mcb.attribute8 = p_current_color;

        -- INCORRECT_COMBINATIONS - End

        v_cur_cancel_lines   cur_cancel_lines%ROWTYPE;

        v_return_status      VARCHAR2 (100);
        v_resp_appl_id       NUMBER;
        v_resp_id            NUMBER;
        v_user_id            NUMBER;
        v_cancel_flag        VARCHAR2 (10);
    BEGIN
        v_resp_appl_id   := fnd_global.resp_appl_id;
        v_resp_id        := fnd_global.resp_id;
        v_user_id        := fnd_global.user_id;
        apps.fnd_global.apps_initialize (v_user_id,
                                         v_resp_id,
                                         v_resp_appl_id);
        /*        MO_GLOBAL.SET_POLICY_CONTEXT('S',81);
     DBMS_OUTPUT.PUT_LINE('after Policy context');*/

        p_po_line_id     := xxd_po_line_type (NULL);

        apps.mo_global.init ('PO');

        -- INCORRECT_COMBINATIONS - Start
        FOR l_index IN p_style.FIRST .. p_style.LAST
        LOOP
            --      OPEN cur_cancel_lines;
            OPEN cur_cancel_lines (p_style (l_index), p_color (l_index));

            -- INCORRECT_COMBINATIONS - End

            LOOP
                FETCH cur_cancel_lines INTO v_cur_cancel_lines;

                EXIT WHEN cur_cancel_lines%NOTFOUND;

                p_po_line_id.EXTEND;
                -- P_PO_LINE_ID(xxd_po_line_tab.EXTEND);

                p_po_line_id (p_po_line_id.COUNT)   :=
                    xxd_po_line_tab (v_cur_cancel_lines.po_line_id,
                                     v_cur_cancel_lines.requisition_line_id);
                --P_PO_LINE_ID (p_po_line_id.COUNT) := v_cur_cancel_lines.po_line_id;

                apps.po_document_control_pub.control_document (
                    p_api_version             => 1.0,
                    p_init_msg_list           => fnd_api.g_true,
                    p_commit                  => fnd_api.g_false,
                    x_return_status           => v_return_status,
                    p_doc_type                => 'PO',
                    p_doc_subtype             => 'STANDARD',
                    p_doc_id                  => p_header_id,
                    p_doc_num                 => NULL,
                    p_release_id              => NULL,
                    p_release_num             => NULL,
                    p_doc_line_id             => v_cur_cancel_lines.po_line_id,
                    p_doc_line_num            => NULL,
                    p_doc_line_loc_id         => NULL,
                    p_doc_shipment_num        => NULL,
                    p_action                  => 'CANCEL',
                    p_action_date             => SYSDATE,
                    p_cancel_reason           => NULL,
                    p_cancel_reqs_flag        => 'N',
                    p_print_flag              => NULL,
                    p_note_to_vendor          => NULL,
                    p_use_gldate              => NULL,    -- <ENCUMBRANCE FPJ>
                    p_org_id                  => v_cur_cancel_lines.org_id, --<Bug#4581621>
                    p_launch_approvals_flag   => NULL         --<Bug#14605476>
                                                     );

                IF (v_return_status = fnd_api.g_ret_sts_success)
                THEN
                    SELECT cancel_flag
                      INTO v_cancel_flag
                      FROM po_lines_all
                     WHERE po_line_id = v_cur_cancel_lines.po_line_id;

                    IF v_cancel_flag = 'Y'
                    THEN
                        --P_ERROR_CODE := 'v_cancel_flag: '||v_cancel_flag;
                        NULL;
                    ELSE
                        p_error_code   := 'cancel api error:';

                        FOR i IN 1 .. fnd_msg_pub.count_msg
                        LOOP
                            p_error_code   :=
                                   p_error_code
                                || fnd_msg_pub.get (p_msg_index   => i,
                                                    p_encoded     => 'F');
                        END LOOP;

                        EXIT;
                    END IF;
                ELSIF v_return_status = (fnd_api.g_ret_sts_error)
                THEN
                    p_error_code   := 'cancel api error:';

                    FOR i IN 1 .. fnd_msg_pub.count_msg
                    LOOP
                        p_error_code   :=
                               p_error_code
                            || fnd_msg_pub.get (p_msg_index   => i,
                                                p_encoded     => 'F');
                    END LOOP;

                    EXIT;
                ELSIF v_return_status = fnd_api.g_ret_sts_unexp_error
                THEN
                    p_error_code   := 'cancel API UNEXPECTED ERROR:';

                    FOR i IN 1 .. fnd_msg_pub.count_msg
                    LOOP
                        p_error_code   :=
                               p_error_code
                            || fnd_msg_pub.get (p_msg_index   => i,
                                                p_encoded     => 'F');
                    END LOOP;

                    EXIT;
                END IF;
            END LOOP;

            CLOSE cur_cancel_lines;
        END LOOP;                      -- INCORRECT_COMBINATIONS - Start - End
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error_code   := 'CANCEL API exception others' || SQLERRM;
    END;

    -- start CCR0006633
    PROCEDURE cancel_requisition_line (
        p_interface_header_id   IN            NUMBER,
        p_error_code               OUT NOCOPY VARCHAR2)
    IS
        CURSOR cur_cancel_req_lines IS
            SELECT --prha.requisition_header_id,prla.requisition_line_id,prha.preparer_id,prha.type_lookup_code  -- Commented CCR0007264
                   porh.requisition_header_id, porl.requisition_line_id, porh.preparer_id,
                   porh.type_lookup_code                   -- Added CCR0007264
              FROM po_requisition_lines_all prla, po_requisition_headers_all prha, po_line_locations_all plla,
                   po_lines_interface pli, po_headers_interface phi, po_requisition_lines_all porl,
                   po_requisition_headers_all porh
             WHERE     phi.interface_header_id = pli.interface_header_id
                   AND phi.interface_header_id = p_interface_header_id
                   AND pli.po_line_id = plla.po_line_id
                   AND plla.line_location_id = prla.line_location_id
                   AND prha.requisition_header_id =
                       prla.requisition_header_id
                   AND prla.attribute2 = TO_CHAR (porl.requisition_line_id) -- CCR0007264
                   AND porl.requisition_header_id =
                       porh.requisition_header_id;               -- CCR0007264

        x_req_control_error_rc   VARCHAR2 (500);
        v_resp_id                NUMBER;
        v_resp_appl_id           NUMBER;
        v_user_id                NUMBER;
    BEGIN
        v_resp_appl_id   := fnd_global.resp_appl_id;
        v_resp_id        := fnd_global.resp_id;
        v_user_id        := fnd_global.user_id;
        apps.fnd_global.apps_initialize (v_user_id,
                                         v_resp_id,
                                         v_resp_appl_id);

        FOR rec_cancel_req_lines IN cur_cancel_req_lines
        LOOP
            BEGIN
                po_reqs_control_sv.update_reqs_status (
                    x_req_header_id          =>
                        rec_cancel_req_lines.requisition_header_id,
                    x_req_line_id            =>
                        rec_cancel_req_lines.requisition_line_id,
                    x_agent_id               => rec_cancel_req_lines.preparer_id,
                    x_req_doc_type           => 'REQUISITION',
                    x_req_doc_subtype        =>
                        rec_cancel_req_lines.type_lookup_code,
                    x_req_control_action     => 'CANCEL',
                    x_req_control_reason     => 'CANCELLED BY API FOR PO COPY',
                    x_req_action_date        => SYSDATE,
                    x_encumbrance_flag       => 'N',
                    x_oe_installed_flag      => 'Y',
                    x_req_control_error_rc   => x_req_control_error_rc);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            --ROLLBACK;
            p_error_code   :=
                   p_error_code
                || 'CANCEL REQUISITION LINES IN ERROR'
                || SQLCODE
                || SQLERRM;
    END;


    PROCEDURE cancel_req_line_move_org (
        p_interface_header_id   IN            NUMBER,
        p_error_code               OUT NOCOPY VARCHAR2)
    IS
        CURSOR cur_cancel_req_lines IS
            SELECT prha.requisition_header_id, prla.requisition_line_id, prha.preparer_id,
                   prha.type_lookup_code
              FROM po_headers_interface phi, po_lines_interface pli, apps.po_distributions_archive_all pda,
                   po_req_distributions_all prda, po_lines_all pla, po_requisition_lines_all prla,
                   po_requisition_headers_all prha
             WHERE     phi.interface_header_id = pli.interface_header_id
                   AND phi.interface_header_id = p_interface_header_id --450650
                   AND pda.req_distribution_id = prda.distribution_id
                   AND pli.line_reference_num = pla.po_line_id
                   AND pla.po_line_id = pda.po_line_id
                   AND prda.requisition_line_id = prla.requisition_line_id
                   AND prha.requisition_header_id =
                       prla.requisition_header_id;

        x_req_control_error_rc   VARCHAR2 (500);
        v_resp_id                NUMBER;
        v_resp_appl_id           NUMBER;
        v_user_id                NUMBER;
    BEGIN
        v_resp_appl_id   := fnd_global.resp_appl_id;
        v_resp_id        := fnd_global.resp_id;
        v_user_id        := fnd_global.user_id;
        apps.fnd_global.apps_initialize (v_user_id,
                                         v_resp_id,
                                         v_resp_appl_id);

        FOR rec_cancel_req_lines IN cur_cancel_req_lines
        LOOP
            BEGIN
                po_reqs_control_sv.update_reqs_status (
                    x_req_header_id          =>
                        rec_cancel_req_lines.requisition_header_id,
                    x_req_line_id            =>
                        rec_cancel_req_lines.requisition_line_id,
                    x_agent_id               => rec_cancel_req_lines.preparer_id,
                    x_req_doc_type           => 'REQUISITION',
                    x_req_doc_subtype        =>
                        rec_cancel_req_lines.type_lookup_code,
                    x_req_control_action     => 'CANCEL',
                    x_req_control_reason     => 'CANCELLED BY API FOR PO COPY',
                    x_req_action_date        => SYSDATE,
                    x_encumbrance_flag       => 'N',
                    x_oe_installed_flag      => 'Y',
                    x_req_control_error_rc   => x_req_control_error_rc);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            --ROLLBACK;
            p_error_code   :=
                   p_error_code
                || 'CANCEL REQUISITION LINES IN ERROR'
                || SQLCODE
                || SQLERRM;
    END;

    -- ENd CCR0006633

    -- START CCR0007264
    PROCEDURE set_om_context (pn_user_id NUMBER, pn_org_id NUMBER, pv_error_stat OUT VARCHAR2
                              , pv_error_msg OUT VARCHAR2)
    IS
        pv_msg            VARCHAR2 (2000);
        pv_stat           VARCHAR2 (1);
        ln_resp_id        NUMBER;
        ln_resp_appl_id   NUMBER;

        ex_get_resp_id    EXCEPTION;
    BEGIN
        BEGIN
            SELECT frv.responsibility_id, frv.application_id resp_application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_profile_option_values fpov, apps.fnd_responsibility_vl frv
             WHERE     fpo.user_profile_option_name =
                       gv_mo_profile_option_name_so     --'MO: Operating Unit'
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpov.level_value = frv.responsibility_id
                   AND frv.responsibility_name LIKE
                           gv_responsibility_name_so || '%' --'Deckers Order Management User%'
                   AND fpov.profile_option_value = TO_CHAR (pn_org_id)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE ex_get_resp_id;
        END;

        apps.fnd_global.apps_initialize (pn_user_id,
                                         ln_resp_id,
                                         ln_resp_appl_id);
        apps.oe_msg_pub.initialize;
        apps.oe_debug_pub.initialize;
        apps.mo_global.init ('ONT');                       -- Required for R12
        apps.mo_global.set_org_context (pn_org_id, NULL, 'ONT');
        apps.fnd_global.set_nls_context ('AMERICAN');
        apps.mo_global.set_policy_context ('S', pn_org_id); -- Required for R12

        pv_error_stat   := 'S';
    EXCEPTION
        WHEN ex_get_resp_id
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    :=
                'Error getting OM Context resp_id : ' || SQLERRM;
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := SQLERRM;
    END;

    -- END CCR0007264

    -- START CCR0007264
    PROCEDURE run_req_import (p_import_source IN VARCHAR2, p_batch_id IN VARCHAR2:= '', p_org_id IN NUMBER, p_inv_org_id IN NUMBER, p_user_id IN NUMBER, p_status OUT VARCHAR
                              , p_msg OUT VARCHAR2, p_request_id OUT NUMBER)
    AS
        l_request_id     NUMBER;
        l_req_id         NUMBER;
        l_req_status     BOOLEAN;
        x_ret_stat       VARCHAR2 (1);
        x_error_text     VARCHAR2 (20000);
        l_phase          VARCHAR2 (80);
        l_status         VARCHAR2 (80);
        l_dev_phase      VARCHAR2 (80);
        l_dev_status     VARCHAR2 (80);
        l_message        VARCHAR2 (255);
        p_resp_id        NUMBER;
        p_app_id         NUMBER;

        n_cnt            NUMBER;
        l_resp_id        NUMBER;
        l_resp_appl_id   NUMBER;
        l_user_id        NUMBER;


        CURSOR c_err IS
            SELECT transaction_id,
                   process_flag,
                   request_id,
                   interface_source_code,
                   batch_id,
                   preparer_id,
                   org_id,
                   line_attribute14 stg_rec_id,
                   (SELECT COUNT (*)
                      FROM po_interface_errors pie
                     WHERE pie.interface_transaction_id = pria.transaction_id) error_cnt
              FROM apps.po_requisitions_interface_all pria
             WHERE     interface_source_code = p_import_source
                   AND request_id = l_request_id
                   AND batch_id = p_batch_id
                   AND process_flag = 'ERROR';
    BEGIN
        l_resp_appl_id   := fnd_global.resp_appl_id;
        l_resp_id        := fnd_global.resp_id;
        l_user_id        := fnd_global.user_id;
        apps.fnd_global.apps_initialize (l_user_id,
                                         l_resp_id,
                                         l_resp_appl_id);
        mo_global.init ('PO');
        mo_global.set_policy_context ('S', p_org_id);
        fnd_request.set_org_id (p_org_id);

        l_request_id     :=
            apps.fnd_request.submit_request (application   => 'PO',
                                             program       => 'REQIMPORT',
                                             argument1     => p_import_source,
                                             argument2     => p_batch_id,
                                             argument3     => 'VENDOR',
                                             argument4     => '',
                                             argument5     => 'N',
                                             argument6     => 'Y');

        COMMIT;
        l_req_status     :=
            apps.fnd_concurrent.wait_for_request (
                request_id   => l_request_id,
                interval     => 10,
                max_wait     => 0,
                phase        => l_phase,
                status       => l_status,
                dev_phase    => l_dev_phase,
                dev_status   => l_dev_status,
                MESSAGE      => l_message);

        IF NVL (l_dev_status, 'ERROR') != 'NORMAL'
        THEN
            IF NVL (l_dev_status, 'ERROR') = 'WARNING'
            THEN
                x_ret_stat   := 'W';
            ELSE
                x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            END IF;

            x_error_text   :=
                NVL (
                    l_message,
                       'The requisition import request ended with a status of '
                    || NVL (l_dev_status, 'ERROR'));
            p_msg   := x_error_text;
        ELSE
            x_ret_stat   := 'S';
        END IF;

        --check for interface records from above request in error state and error out the corresponding stage records
        IF x_ret_stat = 'S'
        THEN
            n_cnt   := 0;

            FOR err_rec IN c_err
            LOOP
                n_cnt   := n_cnt + 1;
            END LOOP;

            IF n_cnt > 0
            THEN
                x_ret_stat   := 'W';
                x_error_text   :=
                    'One or more records failed to interface to a requisition line';
            END IF;
        END IF;

        p_status         := x_ret_stat;
        p_msg            := x_error_text;
        p_request_id     := l_request_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status       := 'U';
            p_msg          :=
                   ' requisition import failed with unexpected error '
                || SQLERRM;
            p_request_id   := NULL;
    END run_req_import;

    -- END CCR0007264

    -- START CCR0007264
    PROCEDURE update_drop_ship_req (p_po_line_id IN xxd_po_line_type, p_new_req_header_id IN NUMBER, p_error_code OUT VARCHAR2)
    IS
        CURSOR cur_update_drop_ship_req IS
            SELECT prha.interface_source_code, prha.org_id, prla.requisition_header_id,
                   prla.requisition_line_id, odss.drop_ship_source_id, p_po_line_tab.requisition_line_id old_req_line_id
              FROM po_requisition_headers_all prha, po_requisition_lines_all prla, TABLE (p_po_line_id) p_po_line_tab,
                   oe_drop_ship_sources odss
             WHERE     prha.requisition_header_id =
                       prla.requisition_header_id
                   AND prha.requisition_header_id = p_new_req_header_id
                   AND prla.attribute2 = TO_CHAR (odss.requisition_line_id)
                   AND odss.requisition_line_id =
                       p_po_line_tab.requisition_line_id;

        v_dropship_msg_count       VARCHAR2 (50) := NULL;
        v_dropship_msg_data        VARCHAR2 (4000) := NULL;
        v_dropship_return_status   VARCHAR2 (50) := NULL;
        lc_ou_name                 VARCHAR2 (100);     -- Added for CCR0007445
    BEGIN
        FOR rec_update_drop_ship_req IN cur_update_drop_ship_req
        LOOP
            BEGIN
                UPDATE oe_drop_ship_sources
                   SET requisition_header_id = NULL, requisition_line_id = NULL
                 WHERE requisition_line_id =
                       rec_update_drop_ship_req.old_req_line_id;


                apps.oe_drop_ship_grp.update_req_info (
                    p_api_version             => 1.0,
                    p_return_status           => v_dropship_return_status,
                    p_msg_count               => v_dropship_msg_count,
                    p_msg_data                => v_dropship_msg_data,
                    p_interface_source_code   => gv_order_entry,
                    p_interface_source_line_id   =>
                        rec_update_drop_ship_req.drop_ship_source_id,
                    p_requisition_header_id   =>
                        rec_update_drop_ship_req.requisition_header_id,
                    p_requisition_line_id     =>
                        rec_update_drop_ship_req.requisition_line_id);

                COMMIT;

                IF (v_dropship_return_status = fnd_api.g_ret_sts_success)
                THEN
                    p_error_code   := NULL;

                    -- Start changes for CCR0007445
                    BEGIN
                        SELECT hou.name
                          INTO lc_ou_name
                          FROM hr_operating_units hou, po_requisition_lines_all prla
                         WHERE     prla.org_id = hou.organization_id
                               AND prla.requisition_line_id =
                                   rec_update_drop_ship_req.old_req_line_id;

                        IF lc_ou_name = 'Deckers Macau OU'
                        THEN
                            UPDATE po_requisition_lines_all
                               SET drop_ship_flag   = 'Y'
                             WHERE requisition_line_id =
                                   rec_update_drop_ship_req.requisition_line_id;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
                -- End changes for CCR0007445
                ELSIF v_dropship_return_status = (fnd_api.g_ret_sts_error)
                THEN
                    p_error_code   := 'DROP SHIP api ERROR:';

                    FOR i IN 1 .. fnd_msg_pub.count_msg
                    LOOP
                        p_error_code   :=
                               p_error_code
                            || fnd_msg_pub.get (p_msg_index   => i,
                                                p_encoded     => 'F');
                    END LOOP;


                    EXIT;
                ELSIF v_dropship_return_status =
                      fnd_api.g_ret_sts_unexp_error
                THEN
                    p_error_code   := 'DROP SHIP UNEXPECTED ERROR:';

                    FOR i IN 1 .. fnd_msg_pub.count_msg
                    LOOP
                        p_error_code   :=
                               p_error_code
                            || fnd_msg_pub.get (p_msg_index   => i,
                                                p_encoded     => 'F');
                    END LOOP;

                    EXIT;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_error_code   := 'drop ship when others: ' || SQLERRM;
                    EXIT;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            RETURN;
    END update_drop_ship_req;

    -- END CCR0007264

    -- START CCR0007264
    PROCEDURE create_purchase_req (
        p_po_line_id          IN     xxd_po_line_type,
        p_vendor_id           IN     NUMBER DEFAULT NULL,
        p_vendor_site_id      IN     NUMBER DEFAULT NULL,
        p_dest_org_id         IN     NUMBER DEFAULT NULL,
        p_new_req_header_id      OUT NUMBER)
    IS
        CURSOR cur_new_req IS
            SELECT prha.interface_source_code,
                   prha.org_id,
                   prla.destination_type_code,
                   prha.authorization_status,
                   prha.preparer_id,
                   mpa.material_account
                       charge_account_id,
                   prla.source_type_code,
                   prla.source_organization_id,
                   msib.primary_uom_code
                       uom_code,
                   prla.line_type_id,
                   prla.quantity,
                   prla.unit_price,
                   NVL (p_dest_org_id, prla.destination_organization_id)
                       destination_organization_id,
                   -- Start changes for CCR0007445
                   DECODE (
                       hou.name,
                       'Deckers Macau OU', prla.deliver_to_location_id,
                       -- End changes for CCR0007445
                       (SELECT location_id
                          FROM hr_organization_units
                         WHERE organization_id =
                               NVL (p_dest_org_id,
                                    prla.destination_organization_id))) -- Added ) for CCR0007445
                       deliver_to_location_id,
                   prla.to_person_id
                       deliver_to_requestor_id,
                   prla.item_id,
                   NVL (p_vendor_id, prla.vendor_id)
                       vendor,
                   NVL (p_vendor_site_id, prla.vendor_site_id)
                       vendor_site,
                   prla.need_by_date,
                   p_po_line_tab.po_line_id,
                   prla.requisition_line_id,
                   (SELECT MAX (plla.promised_date)
                      FROM po_line_locations_all plla
                     WHERE plla.po_line_id = p_po_line_tab.po_line_id)
                       po_promised_date                          ---CCR0007619
              FROM po_requisition_headers_all prha, po_requisition_lines_all prla, mtl_parameters mpa,
                   mtl_system_items_b msib, TABLE (p_po_line_id) p_po_line_tab, hr_operating_units hou -- End changes for CCR0007445
             WHERE     prha.requisition_header_id =
                       prla.requisition_header_id
                   -- Start changes for CCR0007445
                   -- AND prla.destination_organization_id = mpa.organization_id
                   AND ((p_dest_org_id IS NOT NULL AND mpa.organization_id = p_dest_org_id) OR (p_dest_org_id IS NULL AND prla.destination_organization_id = mpa.organization_id))
                   AND hou.organization_id = prha.org_id
                   -- End changes for CCR0007445
                   AND prla.item_id = msib.inventory_item_id
                   AND prla.destination_organization_id =
                       msib.organization_id
                   AND prla.requisition_line_id =
                       p_po_line_tab.requisition_line_id;

        v_resp_appl_id            NUMBER;
        v_resp_id                 NUMBER;
        v_user_id                 NUMBER;
        v_org_id                  NUMBER;
        v_return_status           VARCHAR2 (50);
        lv_org_id                 NUMBER := NULL;
        lv_organization_id        NUMBER := NULL;
        ln_cnt                    NUMBER := 0;
        ln_req_import_req_id      NUMBER := 0;
        ln_new_req_header_id      NUMBER := 0;
        ln_req_imp_batch_id       NUMBER := 1;
        lv_error_stat             VARCHAR2 (100);
        lv_error_msg              VARCHAR2 (4000);
        lv_authorization_status   VARCHAR2 (20) := 'APPROVED';
        lv_batch_id               NUMBER := 1;
    BEGIN
        FOR rec_new_req IN cur_new_req
        LOOP
            lv_org_id            := rec_new_req.org_id;
            lv_organization_id   := rec_new_req.destination_organization_id;

            BEGIN
                INSERT INTO apps.po_requisitions_interface_all (
                                batch_id,
                                interface_source_code,
                                org_id,
                                destination_type_code,
                                authorization_status,
                                preparer_id,
                                charge_account_id,
                                source_type_code,
                                source_organization_id,
                                uom_code,
                                line_type_id,
                                quantity,
                                unit_price,
                                destination_organization_id,
                                deliver_to_location_id,
                                deliver_to_requestor_id,
                                item_id,
                                suggested_vendor_id,
                                suggested_vendor_site_id,
                                need_by_date,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                autosource_flag,
                                line_attribute1,
                                line_attribute2)
                         VALUES (
                                    lv_batch_id,
                                    gv_source_code,
                                    rec_new_req.org_id,
                                    rec_new_req.destination_type_code,
                                    lv_authorization_status,
                                    rec_new_req.preparer_id,
                                    rec_new_req.charge_account_id,
                                    rec_new_req.source_type_code,
                                    rec_new_req.source_organization_id,
                                    rec_new_req.uom_code,
                                    rec_new_req.line_type_id,
                                    rec_new_req.quantity,
                                    rec_new_req.unit_price,
                                    rec_new_req.destination_organization_id,
                                    rec_new_req.deliver_to_location_id,
                                    rec_new_req.deliver_to_requestor_id,
                                    rec_new_req.item_id,
                                    rec_new_req.vendor,
                                    rec_new_req.vendor_site,
                                    -- rec_new_req.need_by_date,
                                    NVL (rec_new_req.po_promised_date,
                                         rec_new_req.need_by_date), --CCR0007619
                                    SYSDATE,
                                    v_user_id,
                                    SYSDATE,
                                    v_user_id,
                                    'P',
                                    rec_new_req.po_line_id,
                                    rec_new_req.requisition_line_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error in Creating Data Into Requisition Interface Table :: '
                        || SQLERRM);
                    RETURN;
            END;
        END LOOP;


        SELECT COUNT (*)
          INTO ln_cnt
          FROM apps.fnd_user
         WHERE user_id = v_user_id AND employee_id IS NOT NULL;

        IF ln_cnt = 0
        THEN
            SELECT user_id
              INTO v_user_id
              FROM fnd_user
             WHERE user_name = gbatcho2f_user;
        END IF;



        --Run req import
        run_req_import (p_import_source   => gv_source_code,
                        p_batch_id        => TO_CHAR (ln_req_imp_batch_id),
                        p_org_id          => lv_org_id,
                        p_inv_org_id      => lv_organization_id,
                        p_user_id         => v_user_id,
                        p_status          => lv_error_stat,
                        p_msg             => lv_error_msg,
                        p_request_id      => ln_req_import_req_id);



        --Get the req header ID created and the count of created records
        BEGIN
              SELECT COUNT (*), prha.requisition_header_id
                INTO ln_cnt, ln_new_req_header_id
                FROM apps.po_requisition_headers_all prha, apps.po_requisition_lines_all prla
               WHERE     prha.requisition_header_id =
                         prla.requisition_header_id
                     AND prha.interface_source_code = gv_source_code
                     AND prha.request_id = ln_req_import_req_id
            GROUP BY prha.requisition_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_new_req_header_id   := NULL;
            WHEN OTHERS
            THEN
                ln_new_req_header_id   := NULL;
        END;

        p_new_req_header_id   := ln_new_req_header_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            RETURN;
    END create_purchase_req;

    -- END CCR0007264

    -- START CCR0007264
    PROCEDURE create_purchase_order (p_new_req_header_id IN NUMBER, p_move_po_header_id IN NUMBER, p_batch_id IN NUMBER
                                     , p_po_line_id IN xxd_po_line_type, p_new_inv_org_id IN NUMBER DEFAULT NULL, pn_interface_header_id IN NUMBER)
    IS
        CURSOR cur_po_header IS
            SELECT segment1 document_num, vendor_id, vendor_site_id,
                   ship_to_location_id, bill_to_location_id, currency_code,
                   agent_id, po_header_id, org_id
              FROM apps.po_headers_all
             WHERE po_header_id = p_move_po_header_id;

        CURSOR cur_po_lines_interface IS
            SELECT prla.requisition_line_id, prla.quantity, prla.item_id,
                   prla.job_id, prla.need_by_date, prla.unit_price,
                   prla.drop_ship_flag, pla.attribute_category, pla.attribute1,
                   pla.attribute2, pla.attribute5, pla.attribute7,
                   pla.attribute8, pla.attribute9, pla.attribute11,
                   pla.attribute13, pla.line_num, plla.attribute_category shipment_attr_category,
                   plla.attribute4 ship_attribute4, plla.attribute5 ship_attribute5, plla.attribute7 ship_attribute7,
                   plla.attribute8 ship_attribute8, plla.attribute10 ship_attribute10, plla.attribute11 ship_attribute11,
                   plla.attribute12 ship_attribute12, plla.attribute13 ship_attribute13, plla.attribute14 ship_attribute14
              FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_lines_all pla,
                   po_line_locations_all plla
             WHERE     prha.requisition_header_id =
                       prla.requisition_header_id
                   AND prha.requisition_header_id = p_new_req_header_id
                   AND pla.po_line_id = plla.po_line_id
                   AND TO_CHAR (pla.po_line_id) = prla.attribute1;

        v_resp_appl_id            NUMBER;
        v_resp_id                 NUMBER;
        v_user_id                 NUMBER;
        v_org_id                  NUMBER;
        v_return_status           VARCHAR2 (50);
        v_line_num                NUMBER := 0;
        lv_org_id                 NUMBER := NULL;
        lv_organization_id        NUMBER := NULL;
        cur_po_header_rec         cur_po_header%ROWTYPE;
        ln_ship_to_location_id    NUMBER := NULL;
        ln_bill_to_location_id    NUMBER := NULL;
        ln_cnt                    NUMBER := 0;
        ln_req_import_req_id      NUMBER := 0;
        ln_new_req_header_id      NUMBER := 0;
        ln_req_imp_batch_id       NUMBER := 1;
        lv_error_stat             VARCHAR2 (100);
        lv_error_msg              VARCHAR2 (4000);
        lv_authorization_status   VARCHAR2 (20) := 'APPROVED';
        lv_batch_id               NUMBER := 1;
        lv_new_line_attribute11   VARCHAR2 (150) := NULL;
        ln_line_interface_id      NUMBER := NULL;
    BEGIN
        OPEN cur_po_header;

        IF cur_po_header%NOTFOUND
        THEN
            CLOSE cur_po_header;
        ELSE
            FETCH cur_po_header INTO cur_po_header_rec;


            v_org_id   := cur_po_header_rec.org_id;
            mo_global.set_policy_context ('S', v_org_id);

            IF p_new_inv_org_id IS NULL
            THEN
                ln_ship_to_location_id   :=
                    cur_po_header_rec.ship_to_location_id;
                ln_bill_to_location_id   :=
                    cur_po_header_rec.bill_to_location_id;
            ELSE
                BEGIN
                    SELECT ship_to_location_id
                      INTO ln_ship_to_location_id
                      FROM hr_locations
                     WHERE inventory_organization_id = p_new_inv_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_ship_to_location_id   :=
                            cur_po_header_rec.ship_to_location_id;
                END;

                ln_bill_to_location_id   :=
                    cur_po_header_rec.bill_to_location_id;
            END IF;

            INSERT INTO po.po_headers_interface (interface_header_id,
                                                 batch_id,
                                                 action,
                                                 org_id,
                                                 document_type_code,
                                                 document_num,
                                                 currency_code,
                                                 agent_id,
                                                 vendor_id,
                                                 vendor_site_id,
                                                 ship_to_location_id,
                                                 bill_to_location_id,
                                                 reference_num,
                                                 po_header_id)
                 VALUES (pn_interface_header_id, p_batch_id, 'UPDATE',
                         cur_po_header_rec.org_id,   -- Your operating unit id
                                                   'STANDARD', cur_po_header_rec.document_num, cur_po_header_rec.currency_code, -- Your currency code
                                                                                                                                cur_po_header_rec.agent_id, -- Your buyer id
                                                                                                                                                            cur_po_header_rec.vendor_id, cur_po_header_rec.vendor_site_id, ln_ship_to_location_id, ln_bill_to_location_id
                         , 'TEST3', cur_po_header_rec.po_header_id); -- Any reference num
        END IF;

        CLOSE cur_po_header;


        SELECT MAX (line_num)
          INTO v_line_num
          FROM po_lines_all pla, po_headers_all pha
         WHERE     pha.po_header_id = pla.po_header_id
               AND pha.po_header_id = p_move_po_header_id;

        FOR po_lines_interface_rec IN cur_po_lines_interface --(p_new_req_header_id)
        LOOP
            v_line_num             := v_line_num + 1;

            BEGIN
                lv_new_line_attribute11   := NULL;
                lv_new_line_attribute11   :=
                      po_lines_interface_rec.unit_price
                    - (NVL (po_lines_interface_rec.attribute8, 0) + NVL (po_lines_interface_rec.attribute9, 0));
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_new_line_attribute11   :=
                        po_lines_interface_rec.unit_price;
            END;

            ln_line_interface_id   := NULL;

            SELECT po_lines_interface_s.NEXTVAL
              INTO ln_line_interface_id
              FROM DUAL;


            BEGIN
                INSERT INTO po_lines_interface (
                                interface_line_id,
                                interface_header_id,
                                line_num,
                                job_id,
                                action,
                                line_type,
                                item_id,
                                requisition_line_id,
                                quantity,
                                unit_price,
                                ship_to_location_id,
                                need_by_date,
                                promised_date,
                                list_price_per_unit,
                                created_by,
                                creation_date,
                                last_updated_by,
                                last_update_date,
                                drop_ship_flag,
                                line_attribute_category_lines,
                                line_attribute1,
                                line_attribute2,
                                line_attribute5,
                                line_attribute7,
                                line_attribute8,
                                line_attribute9,
                                line_attribute11,
                                line_attribute14,
                                shipment_attribute_category,
                                shipment_attribute4,
                                shipment_attribute5,
                                shipment_attribute7,
                                shipment_attribute8,
                                shipment_attribute10,
                                shipment_attribute11,
                                shipment_attribute12,
                                shipment_attribute13,
                                shipment_attribute14,
                                po_header_id)
                         VALUES (
                                    ln_line_interface_id,
                                    pn_interface_header_id,
                                    v_line_num,
                                    po_lines_interface_rec.job_id,
                                    'ADD',
                                    NULL,
                                    po_lines_interface_rec.item_id,
                                    po_lines_interface_rec.requisition_line_id,
                                    po_lines_interface_rec.quantity,
                                    po_lines_interface_rec.unit_price,
                                    ln_ship_to_location_id,
                                    po_lines_interface_rec.need_by_date,
                                    po_lines_interface_rec.need_by_date,
                                    po_lines_interface_rec.unit_price,
                                    v_user_id,
                                    SYSDATE,
                                    v_user_id,
                                    SYSDATE,
                                    po_lines_interface_rec.drop_ship_flag,
                                    po_lines_interface_rec.attribute_category,
                                    po_lines_interface_rec.attribute1,
                                    po_lines_interface_rec.attribute2,
                                    po_lines_interface_rec.attribute5,
                                    po_lines_interface_rec.attribute7,
                                    po_lines_interface_rec.attribute8,
                                    po_lines_interface_rec.attribute9,
                                    lv_new_line_attribute11,
                                    po_lines_interface_rec.line_num,
                                    po_lines_interface_rec.shipment_attr_category,
                                    po_lines_interface_rec.ship_attribute4,
                                    po_lines_interface_rec.ship_attribute5,
                                    po_lines_interface_rec.ship_attribute7,
                                    po_lines_interface_rec.ship_attribute8,
                                    po_lines_interface_rec.ship_attribute10,
                                    po_lines_interface_rec.ship_attribute11,
                                    po_lines_interface_rec.ship_attribute12,
                                    po_lines_interface_rec.ship_attribute13,
                                    po_lines_interface_rec.ship_attribute14,
                                    p_move_po_header_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            RETURN;
    END create_purchase_order;

    -- END CCR0007264

    PROCEDURE xxd_create_po (
        p_header_id          IN            NUMBER,
        p_vendor_id          IN            NUMBER,
        p_vendor_site_id     IN            NUMBER,
        p_po_line_id         IN            xxd_po_line_type,
        p_batch_id           IN            VARCHAR2,
        p_new_document_num      OUT        VARCHAR2,
        p_error_code            OUT NOCOPY VARCHAR2,
        p_new_inv_org_id     IN            NUMBER DEFAULT NULL) -- PO_COPY_TO_NEW_ORG - Start - End
    IS
        v_interface_header_id            NUMBER := po_headers_interface_s.NEXTVAL;

        CURSOR insert_xxd_po_copy_t (p_document_num VARCHAR2)
        IS
            SELECT pla_old.line_num old_line_num, pla_new.line_num new_line_num, pha_old.segment1 old_po_num,
                   pha_new.segment1 new_po_num
              FROM po_lines_interface poli, po_lines_all pla_new, po_lines_all pla_old,
                   po_headers_all pha_old, po_headers_all pha_new
             WHERE     pha_new.segment1 = p_document_num
                   AND pla_new.po_header_id = pha_new.po_header_id
                   AND pla_old.po_header_id = pha_old.po_header_id
                   AND pla_new.po_line_id = poli.po_line_id
                   AND poli.line_reference_num = pla_old.po_line_id;

        CURSOR cur_po_headers_interface IS
            SELECT pha.type_lookup_code, pha.agent_id, pha.creation_date,
                   pha.revision_num, pha.print_count, pha.closed_code,
                   pha.frozen_flag, -- PO_COPY_TO_NEW_ORG - Start
                                    --p_vendor_id vendor_id,
                                    --P_VENDOR_SITE_ID vendor_site_id,
                                    NVL (p_vendor_id, pha.vendor_id) vendor_id, NVL (p_vendor_site_id, pha.vendor_site_id) vendor_site_id,
                   -- PO_COPY_TO_NEW_ORG - End
                   pha.vendor_contact_id, pha.ship_to_location_id, pha.bill_to_location_id,
                   pha.terms_id, pha.ship_via_lookup_code, pha.fob_lookup_code,
                   pha.pay_on_code, pha.freight_terms_lookup_code, pha.confirming_order_flag,
                   pha.currency_code, pha.rate_type, pha.rate_date,
                   pha.rate, pha.acceptance_required_flag, pha.firm_status_lookup_code,
                   pha.min_release_amount, pha.pcard_id, pha.blanket_total_amount,
                   pha.start_date, pha.end_date, pha.amount_limit,
                   pha.global_agreement_flag, pha.consume_req_demand_flag, pha.style_id,
                   pha.created_language, pha.cpa_reference, pha.po_header_id,
                   pha.attribute_category, pha.attribute1, pha.attribute2,
                   pha.attribute3, pha.attribute4, pha.attribute5,
                   pha.attribute6, pha.attribute7, pha.attribute8,
                   pha.attribute9, pha.attribute10, --Start modification for Defect 530,Dt 16-Nov-15 by BT Technology Team
                                                    pha.attribute11, --CCR0006633
                   /* (SELECT attribute2
                            FROM ap_suppliers
                            WHERE vendor_id = p_vendor_id
                            and attribute_category='Supplier Data Elements') attribute11,*/
                   --CCR0006633
                   --End modification for Defect 530,Dt 16-Nov-15 by BT Technology Team
                   pha.attribute12, pha.org_id
              FROM po_headers_all pha
             WHERE pha.po_header_id = p_header_id;


        CURSOR cur_po_lines_interface IS
            SELECT pla.item_id,
                   pla.job_id,
                   pla.category_id,
                   pla.item_description,
                   pla.closed_code,
                   pla.amount,
                   pla.item_revision,
                   pla.un_number_id,
                   pla.hazard_class_id,
                   pla.contract_id,
                   pla.line_type_id,
                   pla.vendor_product_num,
                   pla.firm_status_lookup_code,
                   pla.min_release_amount,
                   pla.price_type_lookup_code,
                   pla.transaction_reason_code,
                   pla.po_header_id,
                   pla.po_line_id,
                   pla.note_to_vendor,
                   pla.oke_contract_header_id,
                   pla.oke_contract_version_id,
                   pla.auction_header_id,
                   pla.auction_line_number,
                   pla.auction_display_number,
                   pla.bid_number,
                   pla.bid_line_number,
                   plla.quantity_cancelled,
                   plla.promised_date,
                   plla.need_by_date,
                   pla.committed_amount,
                   pla.price_break_lookup_code,
                   pla.expiration_date,
                   pla.contractor_first_name,
                   pla.contractor_last_name,
                   pla.retainage_rate,
                   pla.max_retainage_amount,
                   pla.progress_payment_rate,
                   pla.recoupment_rate,
                   pla.ip_category_id,
                   pla.supplier_part_auxid,
                   pla.unit_price,
                   pha.ship_to_location_id,
                   ---added on 29thmay
                   --prla.requisition_line_id,
                   -- PO_COPY_TO_NEW_ORG - Start
                   /*CASE WHEN P_NEW_INV_ORG_ID IS NOT NULL
                          THEN
                             NULL
                          ELSE
                             p_po_line_TAB.requisition_line_id
                          END requisition_line_id,*/
                   -- CCR0007264
                   /*CASE WHEN P_NEW_INV_ORG_ID IS NOT NULL
                          THEN
                             NULL
                          ELSE
                             prla.requisition_line_id
                          END*/
                   prla.requisition_line_id requisition_line_id, -- Added CCR0007264
                   --p_po_line_TAB.requisition_line_id,
                   -- PO_COPY_TO_NEW_ORG - End
                   pla.attribute_category,
                   pla.attribute1,
                   pla.attribute2,
                   pla.attribute3,
                   pla.attribute4,
                   CASE
                       WHEN pla.attribute_category = 'Intercompany PO Copy'
                       THEN
                           NULL
                       ELSE
                           pla.attribute5
                   END AS attribute5,
                   pla.attribute6,
                   /*(SELECT vendor_site_code
                      FROM ap_supplier_sites_all
                     WHERE vendor_site_id = P_VENDOR_SITE_ID)
                         attribute7,*/
                   --CCR0006633
                   NVL ((SELECT vendor_site_code
                           FROM ap_supplier_sites_all
                          WHERE vendor_site_id = p_vendor_site_id),
                        pla.attribute7) attribute7,               --CCR0006633
                   --pla.attribute7,
                   pla.attribute8,
                   pla.attribute9,
                   pla.attribute10,
                   pla.attribute11,
                   pla.attribute12,
                   plla.attribute_category shipment_attribute_category,
                   plla.attribute1 shipment_attribute1,
                   plla.attribute2 shipment_attribute2,
                   plla.attribute3 shipment_attribute3,
                   plla.attribute4 shipment_attribute4,
                   plla.attribute5 shipment_attribute5,
                   plla.attribute6 shipment_attribute6,
                   plla.attribute7 shipment_attribute7,
                   plla.attribute8 shipment_attribute8,
                   plla.attribute9 shipment_attribute9,
                   plla.attribute10 shipment_attribute10,
                   plla.attribute11 shipment_attribute11,
                   plla.attribute12 shipment_attribute12,
                   plla.attribute13 shipment_attribute13,
                   plla.attribute14 shipment_attribute14,
                   plla.attribute15 shipment_attribute15
              FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla,
                   po_requisition_lines_all prla,          -- Added CCR0007264
                                                  -- po_requisition_lines_all prla,
                                                  -- po_req_distributions_all prda,
                                                  --po_distributions_all pda,
                                                  TABLE (p_po_line_id) p_po_line_tab
             WHERE     pha.po_header_id = p_header_id
                   AND pla.cancel_flag = 'Y'
                   AND pla.po_header_id = plla.po_header_id
                   AND pla.po_line_id = plla.po_line_id
                   AND pha.po_header_id = pla.po_header_id
                   AND TO_CHAR (pla.po_line_id) = prla.attribute1 -- Added CCR0007264
                   --AND pda.po_line_id = pla.po_line_id
                   -- AND pda.po_header_id = pha.po_header_id
                   --AND pda.req_distribution_id = prda.distribution_id(+)
                   -- AND prda.requisition_line_id = prla.requisition_line_id(+)
                   AND pla.po_line_id = p_po_line_tab.po_line_id;

        CURSOR cur_po_distributions_interface IS
            SELECT pda.req_distribution_id, pda.deliver_to_location_id, pda.deliver_to_person_id,
                   pda.rate_date, pda.rate, pda.accrued_flag,
                   pda.encumbered_flag, pda.gl_encumbered_date, pda.gl_encumbered_period_name,
                   pda.distribution_num, pda.destination_type_code, pda.destination_organization_id,
                   pda.destination_subinventory, pda.budget_account_id, pda.accrual_account_id,
                   pda.variance_account_id, pda.dest_charge_account_id, pda.dest_variance_account_id,
                   pda.wip_entity_id, pda.wip_line_id, pda.wip_repetitive_schedule_id,
                   pda.wip_operation_seq_num, pda.wip_resource_seq_num, pda.bom_resource_id,
                   pda.project_id, pda.task_id, pda.end_item_unit_number,
                   pda.expenditure_type, pda.project_accounting_context, pda.destination_context,
                   pda.expenditure_organization_id, pda.expenditure_item_date, pda.tax_recovery_override_flag,
                   pda.recovery_rate, pda.award_id, pda.oke_contract_line_id,
                   pda.oke_contract_deliverable_id, pda.code_combination_id, pohi.interface_header_id,
                   poli.interface_line_id
              FROM po_headers_all pha, po_lines_all pla, po_distributions_all pda,
                   po_headers_interface pohi, po_lines_interface poli
             WHERE     pha.po_header_id = p_header_id
                   AND pha.po_header_id = pla.po_header_id
                   AND pla.cancel_flag = 'Y'
                   AND pda.po_line_id = pla.po_line_id
                   AND pda.po_header_id = pha.po_header_id
                   AND pohi.batch_id = p_batch_id
                   AND pohi.interface_header_id = v_interface_header_id
                   AND pohi.interface_header_id = poli.interface_header_id
                   AND poli.line_num = pla.line_num;

        CURSOR cur_update_drop_ship IS
            SELECT DISTINCT phi.po_header_id, pli.po_line_id, plli.line_location_id,
                            porh.requisition_header_id, porl.requisition_line_id
              FROM po_requisition_headers_all porh, po_requisition_lines_all porl, po_line_locations_interface plli,
                   po_lines_interface pli, po_headers_interface phi, po_headers_all poh,
                   oe_drop_ship_sources oedss
             WHERE     porh.requisition_header_id =
                       porl.requisition_header_id
                   AND oedss.requisition_line_id = porl.requisition_line_id
                   AND porl.line_location_id = plli.line_location_id
                   AND plli.interface_line_id = pli.interface_line_id
                   AND pli.interface_header_id = phi.interface_header_id
                   AND phi.po_header_id = poh.po_header_id
                   AND phi.batch_id = p_batch_id;


        v_document_creation_method       po_headers_all.document_creation_method%TYPE;
        v_batch_id                       NUMBER := p_batch_id;
        v_document_id                    NUMBER;
        v_document_number                po_headers_all.segment1%TYPE;
        po_headers_interface_rec         cur_po_headers_interface%ROWTYPE;
        po_lines_interface_rec           cur_po_lines_interface%ROWTYPE;
        po_distributions_interface_rec   cur_po_distributions_interface%ROWTYPE;
        insert_xxd_po_copy_rec           insert_xxd_po_copy_t%ROWTYPE;
        ln_request_id                    VARCHAR2 (100);
        v_return_status                  VARCHAR2 (50);
        v_processed_lines_count          NUMBER := 0;
        v_rejected_lines_count           NUMBER := 0;
        v_err_tolerance_exceeded         VARCHAR2 (100);
        v_resp_appl_id                   NUMBER;
        v_resp_id                        NUMBER;
        v_user_id                        NUMBER;
        v_org_id                         NUMBER;
        cur_update_drop_ship_rec         cur_update_drop_ship%ROWTYPE;
        --INSERT_XXD_PO_COPY_REC           INSERT_XXD_PO_COPY_T%ROWTYPE;
        v_dropship_msg_count             VARCHAR2 (50);
        v_dropship_msg_data              VARCHAR2 (50);
        v_dropship_return_status         VARCHAR2 (50);
        -- PO_COPY_TO_NEW_ORG - Start
        ln_ship_to_location_id           NUMBER;
        ln_bill_to_location_id           NUMBER;
        -- PO_COPY_TO_NEW_ORG - End
        lv_ou_name                       VARCHAR2 (1000) := NULL; -- CCR0007264
        lv_entity                        VARCHAR2 (100) := NULL; -- CCR0007264
        lv_macau_sales_order             VARCHAR2 (100) := NULL; -- CCR0007264
        ln_ds_request_id                 NUMBER := NULL;         -- CCR0007264
        ln_req_imp_batch_id              NUMBER := 1;            -- CCR0007264
        ln_new_req_header_id             NUMBER := 0;            -- CCR0007264
        lv_error_stat                    VARCHAR2 (100);         -- CCR0007264
        lv_error_msg                     VARCHAR2 (4000);        -- CCR0007264
        lv_new_line_attribute11          VARCHAR2 (150);         -- CCR0007264
        ln_line_interface_id             NUMBER := NULL;         -- CCR0007264
    BEGIN
        v_resp_appl_id         := fnd_global.resp_appl_id;
        v_resp_id              := fnd_global.resp_id;
        v_user_id              := fnd_global.user_id;
        apps.fnd_global.apps_initialize (v_user_id,
                                         v_resp_id,
                                         v_resp_appl_id);


        -- START CCR0007264
        -- Check If the PO is Distributor or US
        lv_ou_name             := NULL;
        v_org_id               := NULL;
        lv_entity              := NULL;
        lv_macau_sales_order   := NULL;
        ln_ds_request_id       := NULL;

        BEGIN
            SELECT hou.name, hou.organization_id
              INTO lv_ou_name, v_org_id
              FROM hr_operating_units hou, po_headers_all pha
             WHERE     pha.org_id = hou.organization_id
                   AND pha.po_header_id = p_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_ou_name   := NULL;
                RETURN;
        END;

        ln_new_req_header_id   := NULL;
        create_purchase_req (p_po_line_id, p_vendor_id, p_vendor_site_id,
                             p_new_inv_org_id, ln_new_req_header_id);

        IF lv_ou_name = 'Deckers Macau OU'
        THEN
            lv_entity   := 'MACAU';
            update_drop_ship_req (p_po_line_id,
                                  ln_new_req_header_id,
                                  p_error_code);
        END IF;

        -- End CCR0007264

        mo_global.init ('PO');

        OPEN cur_po_headers_interface;

        FETCH cur_po_headers_interface INTO po_headers_interface_rec;

        IF cur_po_headers_interface%NOTFOUND
        THEN
            CLOSE cur_po_headers_interface;

            RETURN;
        END IF;

        v_org_id               := po_headers_interface_rec.org_id;
        mo_global.set_policy_context ('S', v_org_id);

        -- PO_COPY_TO_NEW_ORG - Start
        IF p_new_inv_org_id IS NULL
        THEN
            ln_ship_to_location_id   :=
                po_headers_interface_rec.ship_to_location_id;
            ln_bill_to_location_id   :=
                po_headers_interface_rec.bill_to_location_id;
        ELSE
            BEGIN
                SELECT ship_to_location_id
                  INTO ln_ship_to_location_id
                  FROM hr_locations
                 WHERE inventory_organization_id = p_new_inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_ship_to_location_id   :=
                        po_headers_interface_rec.ship_to_location_id;
            END;

            ln_bill_to_location_id   :=
                po_headers_interface_rec.bill_to_location_id;
        END IF;

        -- PO_COPY_TO_NEW_ORG - End

        INSERT INTO po_headers_interface (action, process_code, batch_id,
                                          document_type_code, interface_header_id, created_by, org_id, document_subtype, agent_id, creation_date, revision_num, print_count, -- closed_code,  --CCR0006633
                                                                                                                                                                             frozen_flag, vendor_id, vendor_site_id, ship_to_location_id, bill_to_location_id, terms_id, freight_carrier, fob, pay_on_code, freight_terms, confirming_order_flag, currency_code, rate_type, --                    h_rate_date,
                                                                                                                                                                                                                                                                                                                                                                            rate_date, rate, acceptance_required_flag, firm_flag, min_release_amount, pcard_id, amount_agreed, effective_date, expiration_date, amount_limit, global_agreement_flag, consume_req_demand_flag, style_id, created_language, cpa_reference, attribute_category, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10
                                          , attribute11, attribute12)
                 VALUES ('ORIGINAL',
                         NULL,
                         p_batch_id,
                         'STANDARD',
                         v_interface_header_id,
                         fnd_profile.VALUE ('USER_ID'),
                         po_headers_interface_rec.org_id,
                         po_headers_interface_rec.type_lookup_code,
                         po_headers_interface_rec.agent_id,
                         po_headers_interface_rec.creation_date,
                         NULL,
                         po_headers_interface_rec.print_count,
                         -- PO_HEADERS_interface_REC.closed_code,    --CCR0006633
                         po_headers_interface_rec.frozen_flag,
                         po_headers_interface_rec.vendor_id,
                         po_headers_interface_rec.vendor_site_id,
                         -- PO_COPY_TO_NEW_ORG - Start
                         --PO_HEADERS_interface_REC.ship_to_location_id,
                         --PO_HEADERS_interface_REC.bill_to_location_id,
                         ln_ship_to_location_id,
                         ln_bill_to_location_id,
                         -- PO_COPY_TO_NEW_ORG -- End
                         po_headers_interface_rec.terms_id,
                         po_headers_interface_rec.ship_via_lookup_code,
                         po_headers_interface_rec.fob_lookup_code,
                         po_headers_interface_rec.pay_on_code,
                         po_headers_interface_rec.freight_terms_lookup_code,
                         po_headers_interface_rec.confirming_order_flag,
                         po_headers_interface_rec.currency_code,
                         NULL,
                         NULL,
                         NULL,
                         po_headers_interface_rec.acceptance_required_flag,
                         po_headers_interface_rec.firm_status_lookup_code,
                         po_headers_interface_rec.min_release_amount,
                         po_headers_interface_rec.pcard_id,
                         po_headers_interface_rec.blanket_total_amount,
                         po_headers_interface_rec.start_date,
                         po_headers_interface_rec.end_date,
                         po_headers_interface_rec.amount_limit,
                         po_headers_interface_rec.global_agreement_flag,
                         po_headers_interface_rec.consume_req_demand_flag,
                         po_headers_interface_rec.style_id,
                         po_headers_interface_rec.created_language,
                         po_headers_interface_rec.cpa_reference,
                         po_headers_interface_rec.attribute_category,
                         po_headers_interface_rec.attribute1,
                         po_headers_interface_rec.attribute2,
                         po_headers_interface_rec.attribute3,
                         po_headers_interface_rec.attribute4,
                         po_headers_interface_rec.attribute5,
                         po_headers_interface_rec.attribute6,
                         po_headers_interface_rec.attribute7,
                         po_headers_interface_rec.attribute8,
                         po_headers_interface_rec.attribute9,
                         po_headers_interface_rec.attribute10,
                         po_headers_interface_rec.attribute11,
                         po_headers_interface_rec.attribute12);

        CLOSE cur_po_headers_interface;

        OPEN cur_po_lines_interface;

        LOOP
            FETCH cur_po_lines_interface INTO po_lines_interface_rec;

            EXIT WHEN cur_po_lines_interface%NOTFOUND;

            INSERT INTO po_lines_interface (action,
                                            interface_line_id,
                                            interface_header_id,
                                            item_id,
                                            job_id,          -- <SERVICES FPJ>
                                            category_id,
                                            item_description,
                                            --amount,--commented as per defect#108
                                            -- closed_code,   --CCR0006633
                                            item_revision,
                                            un_number_id,
                                            hazard_class_id,
                                            contract_id,
                                            line_type_id,
                                            vendor_product_num,
                                            firm_flag,
                                            min_release_amount,
                                            price_type,
                                            transaction_reason_code,
                                            unit_price,
                                            --   from_header_id,
                                            --from_line_id,
                                            note_to_vendor,
                                            oke_contract_header_id,
                                            oke_contract_version_id,
                                            auction_header_id,
                                            auction_line_number,
                                            auction_display_number,
                                            bid_number,
                                            bid_line_number,
                                            quantity,
                                            committed_amount,
                                            price_break_lookup_code,
                                            expiration_date,
                                            contractor_first_name,
                                            contractor_last_name,
                                            retainage_rate,
                                            max_retainage_amount,
                                            progress_payment_rate,
                                            recoupment_rate,
                                            ip_category_id,
                                            supplier_part_auxid,
                                            ship_to_location_id,
                                            requisition_line_id,
                                            need_by_date,
                                            line_reference_num,
                                            line_attribute_category_lines,
                                            line_attribute1,
                                            line_attribute2,
                                            line_attribute3,
                                            line_attribute4,
                                            line_attribute5,
                                            line_attribute6,
                                            line_attribute7,
                                            line_attribute8,
                                            line_attribute9,
                                            line_attribute10,
                                            line_attribute11,
                                            line_attribute12,
                                            shipment_attribute_category,
                                            shipment_attribute1,
                                            shipment_attribute2,
                                            shipment_attribute3,
                                            shipment_attribute4,
                                            shipment_attribute5,
                                            shipment_attribute6,
                                            shipment_attribute7,
                                            shipment_attribute8,
                                            shipment_attribute9,
                                            shipment_attribute10,
                                            shipment_attribute11,
                                            shipment_attribute12,
                                            shipment_attribute13,
                                            shipment_attribute14,
                                            shipment_attribute15)
                     VALUES (
                                'ORIGINAL',
                                po_lines_interface_s.NEXTVAL,
                                v_interface_header_id,
                                po_lines_interface_rec.item_id,
                                po_lines_interface_rec.job_id,
                                po_lines_interface_rec.category_id,
                                po_lines_interface_rec.item_description,
                                -- PO_LINES_interface_REC.amount,--commented as per defect#108
                                -- PO_LINES_interface_REC.closed_code,   --CCR0006633
                                po_lines_interface_rec.item_revision,
                                po_lines_interface_rec.un_number_id,
                                po_lines_interface_rec.hazard_class_id,
                                po_lines_interface_rec.contract_id,
                                po_lines_interface_rec.line_type_id,
                                po_lines_interface_rec.vendor_product_num,
                                po_lines_interface_rec.firm_status_lookup_code,
                                po_lines_interface_rec.min_release_amount,
                                po_lines_interface_rec.price_type_lookup_code,
                                po_lines_interface_rec.transaction_reason_code,
                                po_lines_interface_rec.unit_price,
                                --  PO_LINES_interface_REC.PO_header_id,
                                --   PO_LINES_interface_REC.PO_line_id,
                                po_lines_interface_rec.note_to_vendor,
                                po_lines_interface_rec.oke_contract_header_id,
                                po_lines_interface_rec.oke_contract_version_id,
                                po_lines_interface_rec.auction_header_id,
                                po_lines_interface_rec.auction_line_number,
                                po_lines_interface_rec.auction_display_number,
                                po_lines_interface_rec.bid_number,
                                po_lines_interface_rec.bid_line_number,
                                po_lines_interface_rec.quantity_cancelled,
                                po_lines_interface_rec.committed_amount,
                                po_lines_interface_rec.price_break_lookup_code,
                                po_lines_interface_rec.expiration_date,
                                po_lines_interface_rec.contractor_first_name,
                                po_lines_interface_rec.contractor_last_name,
                                po_lines_interface_rec.retainage_rate,
                                po_lines_interface_rec.max_retainage_amount,
                                po_lines_interface_rec.progress_payment_rate,
                                po_lines_interface_rec.recoupment_rate,
                                NULL,
                                po_lines_interface_rec.supplier_part_auxid,
                                -- PO_COPY_TO_NEW_ORG - Start
                                -- PO_LINES_interface_REC.ship_to_location_id,
                                ln_ship_to_location_id,
                                -- PO_COPY_TO_NEW_ORG - End
                                po_lines_interface_rec.requisition_line_id,
                                po_lines_interface_rec.need_by_date,
                                po_lines_interface_rec.po_line_id,
                                po_lines_interface_rec.attribute_category,
                                po_lines_interface_rec.attribute1,
                                po_lines_interface_rec.attribute2,
                                po_lines_interface_rec.attribute3,
                                po_lines_interface_rec.attribute4,
                                po_lines_interface_rec.attribute5,
                                po_lines_interface_rec.attribute6,
                                po_lines_interface_rec.attribute7,
                                po_lines_interface_rec.attribute8,
                                po_lines_interface_rec.attribute9,
                                po_lines_interface_rec.attribute10,
                                po_lines_interface_rec.attribute11,
                                po_lines_interface_rec.attribute12,
                                po_lines_interface_rec.shipment_attribute_category,
                                po_lines_interface_rec.shipment_attribute1,
                                po_lines_interface_rec.shipment_attribute2,
                                po_lines_interface_rec.shipment_attribute3,
                                po_lines_interface_rec.shipment_attribute4,
                                po_lines_interface_rec.shipment_attribute5,
                                po_lines_interface_rec.shipment_attribute6,
                                po_lines_interface_rec.shipment_attribute7,
                                po_lines_interface_rec.shipment_attribute8,
                                po_lines_interface_rec.shipment_attribute9,
                                po_lines_interface_rec.shipment_attribute10,
                                po_lines_interface_rec.shipment_attribute11,
                                po_lines_interface_rec.shipment_attribute12,
                                po_lines_interface_rec.shipment_attribute13,
                                po_lines_interface_rec.shipment_attribute14,
                                po_lines_interface_rec.shipment_attribute15);
        END LOOP;

        CLOSE cur_po_lines_interface;


        /* OPEN Cur_PO_DISTRIBUTIONS_interface;

         LOOP
            FETCH Cur_PO_DISTRIBUTIONS_interface
            INTO PO_DISTRIBUTIONS_interface_REC;

            EXIT WHEN Cur_PO_DISTRIBUTIONS_interface%NOTFOUND;

            INSERT INTO po_distributions_interface (INTERFACE_HEADER_ID,
                                                    INTERFACE_LINE_ID,
                                                    INTERFACE_DISTRIBUTION_ID,
                                                    req_distribution_id,
                                                    deliver_to_location_id,
                                                    deliver_to_person_id,
                                                    rate_date,
                                                    rate,
                                                    accrued_flag,
                                                    encumbered_flag,
                                                    gl_encumbered_date,
                                                    gl_encumbered_period_name,
                                                    distribution_num,
                                                    destination_type_code,
                                                    destination_organization_id,
                                                    destination_subinventory,
                                                    budget_account_id,
                                                    accrual_account_id,
                                                    variance_account_id,
                                                    dest_charge_account_id,
                                                    dest_variance_account_id,
                                                    wip_entity_id,
                                                    wip_line_id,
                                                    wip_repetitive_schedule_id,
                                                    wip_operation_seq_num,
                                                    wip_resource_seq_num,
                                                    bom_resource_id,
                                                    project_id,
                                                    task_id,
                                                    end_item_unit_number,
                                                    expenditure_type,
                                                    project_accounting_context,
                                                    destination_context,
                                                    expenditure_organization_id,
                                                    expenditure_item_date,
                                                    tax_recovery_override_flag,
                                                    recovery_rate,
                                                    award_id,
                                                    oke_contract_line_id,
                                                    oke_contract_deliverable_id,
                                                    CHARGE_ACCOUNT_ID)
                 VALUES (
                           PO_DISTRIBUTIONS_interface_REC.INTERFACE_HEADER_ID, ---    INTERFACE_HEADER_ID,
                           PO_DISTRIBUTIONS_interface_REC.INTERFACE_LINE_ID, --- INTERFACE_LINE_ID,
                           po.po_distributions_interface_s.NEXTVAL, --- INTERFACE_DISTRIBUTION_ID,
                           PO_DISTRIBUTIONS_interface_REC.req_distribution_id,
                           PO_DISTRIBUTIONS_interface_REC.deliver_to_location_id,
                           PO_DISTRIBUTIONS_interface_REC.deliver_to_person_id,
                           PO_DISTRIBUTIONS_interface_REC.rate_date,
                           PO_DISTRIBUTIONS_interface_REC.rate,
                           PO_DISTRIBUTIONS_interface_REC.accrued_flag,
                           PO_DISTRIBUTIONS_interface_REC.encumbered_flag,
                           PO_DISTRIBUTIONS_interface_REC.gl_encumbered_date,
                           PO_DISTRIBUTIONS_interface_REC.gl_encumbered_period_name,
                           PO_DISTRIBUTIONS_interface_REC.distribution_num,
                           PO_DISTRIBUTIONS_interface_REC.destination_type_code,
                           PO_DISTRIBUTIONS_interface_REC.destination_organization_id,
                           PO_DISTRIBUTIONS_interface_REC.destination_subinventory,
                           PO_DISTRIBUTIONS_interface_REC.budget_account_id,
                           PO_DISTRIBUTIONS_interface_REC.accrual_account_id,
                           PO_DISTRIBUTIONS_interface_REC.variance_account_id,
                           PO_DISTRIBUTIONS_interface_REC.dest_charge_account_id,
                           PO_DISTRIBUTIONS_interface_REC.dest_variance_account_id,
                           PO_DISTRIBUTIONS_interface_REC.wip_entity_id,
                           PO_DISTRIBUTIONS_interface_REC.wip_line_id,
                           PO_DISTRIBUTIONS_interface_REC.wip_repetitive_schedule_id,
                           PO_DISTRIBUTIONS_interface_REC.wip_operation_seq_num,
                           PO_DISTRIBUTIONS_interface_REC.wip_resource_seq_num,
                           PO_DISTRIBUTIONS_interface_REC.bom_resource_id,
                           PO_DISTRIBUTIONS_interface_REC.project_id,
                           PO_DISTRIBUTIONS_interface_REC.task_id,
                           PO_DISTRIBUTIONS_interface_REC.end_item_unit_number,
                           PO_DISTRIBUTIONS_interface_REC.expenditure_type,
                           PO_DISTRIBUTIONS_interface_REC.project_accounting_context,
                           PO_DISTRIBUTIONS_interface_REC.destination_context,
                           PO_DISTRIBUTIONS_interface_REC.expenditure_organization_id,
                           PO_DISTRIBUTIONS_interface_REC.expenditure_item_date,
                           PO_DISTRIBUTIONS_interface_REC.tax_recovery_override_flag,
                           PO_DISTRIBUTIONS_interface_REC.recovery_rate,
                           PO_DISTRIBUTIONS_interface_REC.award_id,
                           PO_DISTRIBUTIONS_interface_REC.oke_contract_line_id,
                           PO_DISTRIBUTIONS_interface_REC.oke_contract_deliverable_id,
                           PO_DISTRIBUTIONS_interface_REC.code_combination_id);
         END LOOP;

         CLOSE Cur_PO_DISTRIBUTIONS_interface;

         SELECT po_headers_interface_s.CURRVAL
           INTO V_INTERFACE_HEADER_ID
           FROM DUAL;*/


        apps.po_pdoi_pvt.start_process (
            p_api_version                  => 1.0,
            p_init_msg_list                => fnd_api.g_true,
            p_validation_level             => NULL,
            p_commit                       => fnd_api.g_false,
            x_return_status                => v_return_status,
            p_gather_intf_tbl_stat         => 'N',
            p_calling_module               => NULL,
            p_selected_batch_id            => p_batch_id,
            p_batch_size                   => NULL,
            p_buyer_id                     => NULL,
            p_document_type                => 'STANDARD',
            p_document_subtype             => NULL,
            p_create_items                 => 'N',
            p_create_sourcing_rules_flag   => 'N',
            p_rel_gen_method               => NULL,
            p_sourcing_level               => NULL,
            p_sourcing_inv_org_id          => NULL,
            p_approved_status              => 'APPROVED',
            p_process_code                 => NULL,
            p_interface_header_id          => v_interface_header_id,
            p_org_id                       => v_org_id,
            p_ga_flag                      => NULL,
            p_submit_dft_flag              => 'N',
            p_role                         => 'BUYER',
            p_catalog_to_expire            => NULL,
            p_err_lines_tolerance          => NULL,
            p_clm_flag                     => NULL,         --CLM PDOI Project
            x_processed_lines_count        => v_processed_lines_count,
            x_rejected_lines_count         => v_rejected_lines_count,
            x_err_tolerance_exceeded       => v_err_tolerance_exceeded);



        IF (v_return_status = fnd_api.g_ret_sts_success)
        THEN
            /*(SELECT INTERFACE_HEADER_ID
            FROM PO_INTERFACE_ERRORS where interface_type = 'PO_DOCS_OPEN_INTERFACE'
            WHERE INTERFACE_HEADER_ID = po_headers_interface_s.CURRVAL)*/
            BEGIN
                SELECT segment1, phi.po_header_id
                  INTO v_document_number, v_document_id
                  FROM po_headers_all pha, po_headers_interface phi
                 WHERE     pha.po_header_id = phi.po_header_id
                       AND phi.interface_header_id = v_interface_header_id
                       AND phi.process_code = 'ACCEPTED';

                --start CCR0006633
                IF p_new_inv_org_id IS NULL
                THEN
                    cancel_requisition_line (v_interface_header_id,
                                             p_error_code);       --CCR0006633
                ELSE
                    cancel_req_line_move_org (v_interface_header_id,
                                              p_error_code);      --CCR0006633
                END IF;

                --end CCR0006633
                ---------added on 29th may for drop ship----------
                OPEN cur_update_drop_ship;

                IF cur_update_drop_ship%NOTFOUND
                THEN
                    p_new_document_num   := v_document_number;

                    p_error_code         := NULL;

                    OPEN insert_xxd_po_copy_t (v_document_number);

                    LOOP
                        FETCH insert_xxd_po_copy_t
                            INTO insert_xxd_po_copy_rec;

                        EXIT WHEN insert_xxd_po_copy_t%NOTFOUND;

                        INSERT INTO xxdo.xxd_po_copy_t (old_po_num,
                                                        new_po_num,
                                                        old_po_line_num,
                                                        new_po_line_num,
                                                        creation_date,
                                                        created_by)
                                 VALUES (insert_xxd_po_copy_rec.old_po_num,
                                         insert_xxd_po_copy_rec.new_po_num,
                                         insert_xxd_po_copy_rec.old_line_num,
                                         insert_xxd_po_copy_rec.new_line_num,
                                         SYSDATE,
                                         fnd_profile.VALUE ('USER_ID'));
                    END LOOP;

                    CLOSE insert_xxd_po_copy_t;

                    /* -- bsk
                                   DELETE FROM po_headers_interface
                                         WHERE interface_header_id = V_INTERFACE_HEADER_ID;

                                   DELETE FROM po_lines_interface
                                         WHERE interface_header_id = V_INTERFACE_HEADER_ID;

                                   DELETE FROM po_distributions_interface
                                         WHERE interface_header_id = V_INTERFACE_HEADER_ID;
                    */
                    COMMIT;

                    CLOSE cur_update_drop_ship;
                ELSE
                    LOOP
                        FETCH cur_update_drop_ship
                            INTO cur_update_drop_ship_rec;

                        EXIT WHEN cur_update_drop_ship%NOTFOUND;


                        BEGIN
                            apps.oe_drop_ship_grp.update_po_info (
                                p_api_version     => 1.0,
                                p_return_status   => v_dropship_return_status,
                                p_msg_count       => v_dropship_msg_count,
                                p_msg_data        => v_dropship_msg_data,
                                p_req_header_id   =>
                                    cur_update_drop_ship_rec.requisition_header_id,
                                p_req_line_id     =>
                                    cur_update_drop_ship_rec.requisition_line_id,
                                p_po_header_id    =>
                                    cur_update_drop_ship_rec.po_header_id,
                                p_po_line_id      =>
                                    cur_update_drop_ship_rec.po_line_id,
                                p_line_location_id   =>
                                    cur_update_drop_ship_rec.line_location_id);

                            IF (v_return_status = fnd_api.g_ret_sts_success)
                            THEN
                                /*fnd_file.PUT_LINE (fnd_file.LOG,
                                                   'drop ship successs' || CHR (10));*/

                                p_error_code   := NULL;


                                UPDATE po_line_locations_all plla
                                   SET ship_to_location_id   =
                                           (SELECT DISTINCT
                                                   porl.deliver_to_location_id
                                              FROM po_requisition_headers_all porh, po_requisition_lines_all porl
                                             WHERE     porh.requisition_header_id =
                                                       porl.requisition_header_id
                                                   AND plla.line_location_id =
                                                       porl.line_location_id
                                                   AND porl.line_location_id =
                                                       cur_update_drop_ship_rec.line_location_id)
                                 WHERE plla.line_location_id =
                                       cur_update_drop_ship_rec.line_location_id;
                            ELSIF v_return_status = (fnd_api.g_ret_sts_error)
                            THEN
                                p_error_code   := 'DROP SHIP api ERROR:';

                                FOR i IN 1 .. fnd_msg_pub.count_msg
                                LOOP
                                    p_error_code   :=
                                           p_error_code
                                        || fnd_msg_pub.get (
                                               p_msg_index   => i,
                                               p_encoded     => 'F');
                                END LOOP;

                                EXIT;
                            ELSIF v_return_status =
                                  fnd_api.g_ret_sts_unexp_error
                            THEN
                                p_error_code   :=
                                    'DROP SHIP UNEXPECTED ERROR:';

                                FOR i IN 1 .. fnd_msg_pub.count_msg
                                LOOP
                                    p_error_code   :=
                                           p_error_code
                                        || fnd_msg_pub.get (
                                               p_msg_index   => i,
                                               p_encoded     => 'F');
                                END LOOP;

                                EXIT;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_error_code   :=
                                    'drop ship when others: ' || SQLERRM;
                                EXIT;
                        END;
                    END LOOP;

                    IF p_error_code IS NULL
                    THEN
                        p_new_document_num   := v_document_number;

                        OPEN insert_xxd_po_copy_t (v_document_number);

                        LOOP
                            FETCH insert_xxd_po_copy_t
                                INTO insert_xxd_po_copy_rec;

                            EXIT WHEN insert_xxd_po_copy_t%NOTFOUND;

                            INSERT INTO xxdo.xxd_po_copy_t (old_po_num,
                                                            new_po_num,
                                                            old_po_line_num,
                                                            new_po_line_num,
                                                            creation_date,
                                                            created_by)
                                     VALUES (
                                                insert_xxd_po_copy_rec.old_po_num,
                                                insert_xxd_po_copy_rec.new_po_num,
                                                insert_xxd_po_copy_rec.old_line_num,
                                                insert_xxd_po_copy_rec.new_line_num,
                                                SYSDATE,
                                                fnd_profile.VALUE ('USER_ID'));
                        END LOOP;

                        CLOSE insert_xxd_po_copy_t;

                        -- Start CCR0007264
                        /*DELETE FROM po_headers_interface
                              WHERE interface_header_id =
                                       V_INTERFACE_HEADER_ID;

                        DELETE FROM po_lines_interface
                              WHERE interface_header_id =
                                       V_INTERFACE_HEADER_ID;

                        DELETE FROM po_distributions_interface
                              WHERE interface_header_id =
                                       V_INTERFACE_HEADER_ID;*/
                        -- End CCR0007264

                        COMMIT;
                    ELSE
                        ROLLBACK;
                    END IF;
                END IF;

                CLOSE cur_update_drop_ship;


                --Begin CCR0007619
                XXDO_PO_APPROVAL (v_document_number, v_org_id, lv_error_stat,
                                  lv_error_msg);

                --PO Approval failed. This is not fatal. We just need to note the error
                IF lv_error_stat != 1
                THEN                                    --PO Failed to approve
                    p_error_code   :=
                        'PO Failed to approve : ' || lv_error_msg;
                END IF;
            --End CCR0007619


            ---------added on 29th may for drop ship----------
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ROLLBACK;
                    ln_request_id   :=
                        apps.fnd_request.submit_request (
                            application   => 'XXDO'  -- Application Short name
                                                   ,
                            program       => 'XXD_PO_COPY_ERR_REP' -- Concurrent prog short name
                                                                  ,
                            description   => '' -- Concurrent prog description
                                               ,
                            start_time    =>
                                TO_CHAR (SYSDATE, 'DD-MON-YY HH24:MI:SS') -- Start time
                                                                         ,
                            sub_request   => FALSE           -- submit request
                                                  ,
                            argument1     => v_interface_header_id);
                    p_error_code   :=
                           'No Document Created:Refer ''Deckers PO Copy error Program'' : Request ID :'
                        || ln_request_id;

                    COMMIT;
            END;
        ELSIF v_return_status = (fnd_api.g_ret_sts_error)
        THEN
            p_error_code   := 'CREATE api error:';

            FOR i IN 1 .. fnd_msg_pub.count_msg
            LOOP
                p_error_code   :=
                       p_error_code
                    || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;
        ELSIF v_return_status = fnd_api.g_ret_sts_unexp_error
        THEN
            p_error_code   := 'CREATE API UNEXPECTED ERROR:';

            FOR i IN 1 .. fnd_msg_pub.count_msg
            LOOP
                p_error_code   :=
                       p_error_code
                    || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            p_error_code   :=
                p_error_code || 'CREATE CODE IN ERROR' || SQLCODE || SQLERRM;
    END;

    PROCEDURE xxd_add_po_lines (p_header_id IN NUMBER, v_move_po_header_id IN NUMBER, p_po_line_id IN xxd_po_line_type
                                , p_batch_id IN VARCHAR2, p_error_code OUT NOCOPY VARCHAR2, p_new_inv_org_id IN NUMBER DEFAULT NULL) -- PO_COPY_TO_NEW_ORG - Start - End
    IS
        v_interface_header_id        NUMBER := po_headers_interface_s.NEXTVAL;

        -- Commented CCR0007264
        /*CURSOR cur_po_header
        IS
           SELECT segment1 document_num,
                  vendor_id,
                  vendor_site_id,
                  ship_to_location_id,
                  bill_to_location_id,
                  currency_code,
                  agent_id,
                  po_header_id,
                  org_id
             FROM apps.po_headers_all
            WHERE po_header_id = V_MOVE_PO_HEADER_ID;


        CURSOR Cur_PO_LINES_interface
        IS
           SELECT pla.item_id,
                  Pla.job_id,
                  Pla.category_id,
                  Pla.item_description,
                  pla.amount,
                  PLA.UNIT_PRICE,
                  pla.item_revision,
                  pla.un_number_id,
                  pla.hazard_class_id,
                  pla.contract_id,
                  pla.line_type_id,
                  pla.vendor_product_num,
                  pla.firm_status_lookup_code,
                  pla.min_release_amount,
                  pla.price_type_lookup_code,
                  pla.transaction_reason_code,
                  pla.from_header_id,
                  pla.from_line_id,
                  pla.note_to_vendor,
                  pla.oke_contract_header_id,
                  pla.oke_contract_version_id,
                  pla.auction_header_id,
                  pla.auction_line_number,
                  pla.auction_display_number,
                  pla.bid_number,
                  pla.bid_line_number,
                  PLLA.quantity_CANCELLED,
                  plla.need_by_date,
                  pla.committed_amount,
                  pla.price_break_lookup_code,
                  PLA.expiration_date,
                  PLA.contractor_first_name,
                  PLA.contractor_last_name,
                  PLA.retainage_rate,
                  PLA.max_retainage_amount,
                  PLA.progress_payment_rate,
                  PLA.recoupment_rate,
                  PLA.ip_category_id,
                  PLA.supplier_part_auxid,
                  -- prla.requisition_line_id,
                  PHA.SHIP_TO_LOCATION_ID, --ADDED ON 29THMAY
                  p_po_line_TAB.requisition_line_id,
                  PLA.LINE_NUM,
                  pla.attribute_category,
                  pla.attribute1,
                  pla.attribute2,
                  pla.attribute3,
                  pla.attribute4,
                  CASE
                     WHEN pla.attribute_category = 'Intercompany PO Copy'
                     THEN
                        NULL
                     ELSE
                        pla.attribute5
                  END
                     AS attribute5,
                  pla.attribute6,*/
        /* (SELECT assa.vendor_site_code
            FROM ap_supplier_sites_all assa, po_headers_all poh
           WHERE     poh.vendor_site_id = assa.VENDOR_SITE_ID
                 AND poh.po_header_id = V_MOVE_PO_HEADER_ID)
            attribute7,*/
        --CCR0006633
        /*pla.attribute7,        --CCR0006633
        pla.attribute8,
        pla.attribute9,
        pla.attribute10,
        pla.attribute11,
        pla.attribute12,
        plla.attribute_category shipment_attribute_category,
        plla.attribute1 shipment_attribute1,
        plla.attribute2 shipment_attribute2,
        plla.attribute3 shipment_attribute3,
        plla.attribute4 shipment_attribute4,
        plla.attribute5 shipment_attribute5,
        plla.attribute6 shipment_attribute6,
        plla.attribute7 shipment_attribute7,
        plla.attribute8 shipment_attribute8,
        plla.attribute9 shipment_attribute9,
        plla.attribute10 shipment_attribute10,
        plla.attribute11 shipment_attribute11,
        plla.attribute12 shipment_attribute12,
        plla.attribute13 shipment_attribute13,
        plla.attribute14 shipment_attribute14,
        plla.attribute15 shipment_attribute15
   FROM po_headers_all pha,
        po_lines_all pla,
        po_line_locations_all plla,
        -- po_requisition_lines_all prla,
        -- po_req_distributions_all prda,
        -- po_distributions_all pda,
        TABLE (p_po_line_id) p_po_line_TAB
  WHERE     pha.po_header_id = p_header_id
        AND pla.cancel_flag = 'Y'
        AND pha.po_header_id = pla.po_header_id
        AND PLA.PO_HEADER_ID = PLLA.PO_HEADER_ID
        AND PLA.PO_LINE_ID = PLLA.PO_LINE_ID
        -- AND pda.po_line_id = pla.po_line_id
        -- AND pda.po_header_id = pha.po_header_id
        AND pla.po_line_id = p_po_line_TAB.PO_LINE_ID;*/


        --  AND pda.req_distribution_id = prda.distribution_id(+)
        --AND prda.requisition_line_id = prla.requisition_line_id(+);

        -- Commented CCR0007264
        /*CURSOR Cur_PO_DISTRIBUTIONS_interface
        IS
           SELECT pda.req_distribution_id,
                  pda.deliver_to_location_id,
                  pda.deliver_to_person_id,
                  pda.rate_date,
                  pda.rate,
                  pda.accrued_flag,
                  pda.encumbered_flag,
                  pda.gl_encumbered_date,
                  pda.gl_encumbered_period_name,
                  pda.distribution_num,
                  pda.destination_type_code,
                  pda.destination_organization_id,
                  pda.destination_subinventory,
                  pda.budget_account_id,
                  pda.accrual_account_id,
                  pda.variance_account_id,
                  pda.dest_charge_account_id,
                  pda.dest_variance_account_id,
                  pda.wip_entity_id,
                  pda.wip_line_id,
                  pda.wip_repetitive_schedule_id,
                  pda.wip_operation_seq_num,
                  pda.wip_resource_seq_num,
                  pda.bom_resource_id,
                  pda.project_id,
                  pda.task_id,
                  pda.end_item_unit_number,
                  pda.expenditure_type,
                  pda.project_accounting_context,
                  pda.destination_context,
                  pda.expenditure_organization_id,
                  pda.expenditure_item_date,
                  pda.tax_recovery_override_flag,
                  pda.recovery_rate,
                  PDA.award_id,
                  PDA.oke_contract_line_id,
                  PDA.oke_contract_deliverable_id,
                  pda.code_combination_id,
                  POHI.INTERFACE_HEADER_ID,
                  POLI.INTERFACE_LINE_ID
             FROM po_headers_all pha,
                  po_lines_all pla,
                  po_distributions_all pda,
                  PO_HEADERS_INTERFACE POHI,
                  PO_LINES_INTERFACE POLI
            WHERE     pha.po_header_id = p_header_id
                  AND pha.po_header_id = pla.po_header_id
                  --and pla.cancel_flag = 'Y'
                  AND pda.po_line_id = pla.po_line_id
                  AND pla.po_line_id IN
                         (SELECT PO_LINE_ID FROM TABLE (p_po_line_id))
                  AND pda.po_header_id = pha.po_header_id
                  AND POHI.batch_id = p_batch_id
                  AND POHI.INTERFACE_HEADER_ID = V_INTERFACE_HEADER_ID
                  AND POHI.INTERFACE_HEADER_ID = POLI.INTERFACE_HEADER_ID
                  AND poli.line_num = pla.line_num;*/

        CURSOR cur_update_drop_ship IS
            SELECT DISTINCT phi.po_header_id, pli.po_line_id, plli.line_location_id,
                            porh.requisition_header_id, porl.requisition_line_id
              FROM po_requisition_headers_all porh, po_requisition_lines_all porl, po_line_locations_interface plli,
                   po_lines_interface pli, po_headers_interface phi, po_headers_all poh,
                   oe_drop_ship_sources oedss
             WHERE     porh.requisition_header_id =
                       porl.requisition_header_id
                   AND oedss.requisition_line_id = porl.requisition_line_id
                   AND porl.line_location_id = plli.line_location_id
                   AND plli.interface_line_id = pli.interface_line_id
                   AND pli.interface_header_id = phi.interface_header_id
                   AND phi.po_header_id = poh.po_header_id
                   AND phi.batch_id = p_batch_id;


        v_document_creation_method   po_headers_all.document_creation_method%TYPE;
        v_batch_id                   NUMBER := p_batch_id;
        ln_request_id                VARCHAR2 (50);
        --      PO_LINES_interface_REC           Cur_PO_LINES_interface%ROWTYPE;           -- Commented CCR0007264
        --      PO_DISTRIBUTIONS_interface_REC   Cur_PO_DISTRIBUTIONS_interface%ROWTYPE;   -- Commented CCR0007264

        v_return_status              VARCHAR2 (50);
        v_processed_lines_count      NUMBER := 0;
        v_rejected_lines_count       NUMBER := 0;
        v_err_tolerance_exceeded     VARCHAR2 (100);
        v_line_num                   NUMBER;
        --cur_po_header_rec                cur_po_header%ROWTYPE; -- Commented CCR0007264
        v_document_id                NUMBER;
        v_resp_appl_id               NUMBER;
        v_resp_id                    NUMBER;
        v_user_id                    NUMBER;
        v_doc_number                 VARCHAR2 (40);
        v_org_id                     NUMBER;
        cur_update_drop_ship_rec     cur_update_drop_ship%ROWTYPE;
        --INSERT_XXD_PO_COPY_REC           INSERT_XXD_PO_COPY_T%ROWTYPE;
        v_dropship_msg_count         VARCHAR2 (50);
        v_dropship_msg_data          VARCHAR2 (50);
        v_dropship_return_status     VARCHAR2 (50);
        -- PO_COPY_TO_NEW_ORG - Start
        ln_ship_to_location_id       NUMBER;
        ln_bill_to_location_id       NUMBER;
        -- PO_COPY_TO_NEW_ORG - End
        ln_req_imp_batch_id          NUMBER := 1;                -- CCR0007264
        ln_new_req_header_id         NUMBER := 0;                -- CCR0007264
        lv_error_stat                VARCHAR2 (100);             -- CCR0007264
        lv_error_msg                 VARCHAR2 (4000);            -- CCR0007264
        lv_new_line_attribute11      VARCHAR2 (150);             -- CCR0007264
        ln_line_interface_id         NUMBER := NULL;             -- CCR0007264
        lv_ou_name                   VARCHAR2 (1000) := NULL;    -- CCR0007264
        lv_entity                    VARCHAR2 (100) := NULL;     -- CCR0007264
        lv_macau_sales_order         VARCHAR2 (100) := NULL;     -- CCR0007264
        ln_ds_request_id             NUMBER := NULL;             -- CCR0007264
    BEGIN
        --Initializing Apps
        v_resp_appl_id         := fnd_global.resp_appl_id;
        v_resp_id              := fnd_global.resp_id;
        v_user_id              := fnd_global.user_id;
        apps.fnd_global.apps_initialize (v_user_id,
                                         v_resp_id,
                                         v_resp_appl_id);
        mo_global.init ('PO');

        -- START CCR0007264
        -- Check If the PO is Distributor or US
        lv_ou_name             := NULL;
        v_org_id               := NULL;
        lv_entity              := NULL;
        lv_macau_sales_order   := NULL;
        ln_ds_request_id       := NULL;

        BEGIN
            SELECT hou.name, hou.organization_id, pha.segment1
              INTO lv_ou_name, v_org_id, v_doc_number
              FROM hr_operating_units hou, po_headers_all pha
             WHERE     pha.org_id = hou.organization_id
                   AND pha.po_header_id = v_move_po_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_ou_name   := NULL;
                RETURN;
        END;

        ln_new_req_header_id   := NULL;
        create_purchase_req (p_po_line_id, NULL, NULL,
                             p_new_inv_org_id, ln_new_req_header_id);

        IF lv_ou_name = 'Deckers Macau OU'
        THEN
            lv_entity   := 'MACAU';
            update_drop_ship_req (p_po_line_id,
                                  ln_new_req_header_id,
                                  p_error_code);
        END IF;

        create_purchase_order (ln_new_req_header_id,
                               v_move_po_header_id,
                               p_batch_id,
                               p_po_line_id,
                               p_new_inv_org_id,
                               v_interface_header_id);
        -- End CCR0007264

        -- START Commented CCR0007264
        /*OPEN cur_po_header;

        IF cur_po_header%NOTFOUND
        THEN
           CLOSE cur_po_header;
        ELSE
           FETCH cur_po_header INTO cur_po_header_rec;


           V_ORG_ID := cur_po_header_rec.org_id;
           MO_GLOBAL.SET_POLICY_CONTEXT ('S', V_ORG_ID);

        -- PO_COPY_TO_NEW_ORG - Start
        IF P_NEW_INV_ORG_ID IS NULL THEN
          ln_ship_to_location_id := cur_po_header_rec.ship_to_location_id ;
          ln_bill_to_location_id := cur_po_header_rec.bill_to_location_id;

        ELSE
          BEGIN
              SELECT ship_to_location_id
                INTO ln_ship_to_location_id
                FROM hr_locations
               WHERE inventory_organization_id = P_NEW_INV_ORG_ID;
          EXCEPTION
              WHEN OTHERS THEN
                 ln_ship_to_location_id := cur_po_header_rec.ship_to_location_id ;
          END;

          ln_bill_to_location_id := cur_po_header_rec.bill_to_location_id;
        END IF;
        -- PO_COPY_TO_NEW_ORG - End

           INSERT INTO po.po_headers_interface (interface_header_id,
                                                batch_id,
                                                action,
                                                org_id,
                                                document_type_code,
                                                DOCUMENT_NUM,
                                                currency_code,
                                                agent_id,
                                                vendor_id,
                                                vendor_site_id,
                                                ship_to_location_id,
                                                bill_to_location_id,
                                                reference_num,
                                                po_header_id)
                VALUES (V_INTERFACE_HEADER_ID,
                        P_BATCH_ID,
                        'UPDATE',
                        cur_po_header_rec.org_id,      -- Your operating unit id
                        'STANDARD',
                        cur_po_header_rec.document_num,
                        cur_po_header_rec.currency_code,   -- Your currency code
                        cur_po_header_rec.agent_id,             -- Your buyer id
                        cur_po_header_rec.vendor_id,
                        cur_po_header_rec.vendor_site_id,
                        -- PO_COPY_TO_NEW_ORG - Start
                        --cur_po_header_rec.ship_to_location_id,   -- Your ship to
                        --cur_po_header_rec.BILL_to_location_id,   -- Your bill to
                        ln_ship_to_location_id,
                        ln_bill_to_location_id,
                        -- PO_COPY_TO_NEW_ORG - End
                        'TEST3',
                        cur_po_header_rec.po_header_id);    -- Any reference num
        END IF;

        CLOSE cur_po_header;


        SELECT MAX (line_num)
          INTO v_line_num
          FROM po_lines_all pla, po_headers_all pha
         WHERE     pha.po_header_id = pla.po_header_id
               AND pha.po_header_id = V_MOVE_PO_HEADER_ID;

        --OPEN Cur_PO_LINES_interface (ln_new_req_header_id); -- Added Parameter ln_new_req_header_id for CCR0007264
        FOR po_lines_interface_rec IN Cur_PO_LINES_interface (ln_new_req_header_id) -- CCR0007264
        LOOP
           --FETCH Cur_PO_LINES_interface INTO po_lines_interface_rec; -- Commented CCR0007264

           --EXIT WHEN Cur_PO_LINES_interface%NOTFOUND; -- Commented CCR0007264

           -- Start CCR0007264
           v_line_num := v_line_num + 1;

           BEGIN
              lv_new_line_attribute11 := NULL;
              lv_new_line_attribute11 := po_lines_interface_rec.unit_price - (NVL (po_lines_interface_rec.attribute8, 0)
                                                                            + NVL (po_lines_interface_rec.attribute9, 0));
           EXCEPTION
              WHEN OTHERS
              THEN
                  lv_new_line_attribute11 := po_lines_interface_rec.unit_price;
           END;

           ln_line_interface_id := NULL;

           SELECT po_lines_interface_s.nextval
             INTO ln_line_interface_id
             FROM dual;


            BEGIN
           INSERT INTO po_lines_interface (interface_line_id,
                                           interface_header_id,
                                           item_id,
                                           job_id,             -- <SERVICES FPJ>
                                           category_id,
                                           item_description,
                                           UNIT_PRICE,
                                           amount,
                                           item_revision,
                                           un_number_id,
                                           hazard_class_id,
                                           contract_id,
                                           line_type_id,
                                           vendor_product_num,
                                           firm_FLAG,
                                           min_release_amount,
                                           price_type,
                                           transaction_reason_code,
                                           from_header_id,
                                           note_to_vendor,
                                           oke_contract_header_id,
                                           oke_contract_version_id,
                                           auction_header_id,
                                           auction_line_number,
                                           auction_display_number,
                                           quantity,
                                           committed_amount,
                                           price_break_lookup_code,
                                           expiration_date,
                                           contractor_first_name,
                                           contractor_last_name,
                                           retainage_rate,
                                           max_retainage_amount,
                                           progress_payment_rate,
                                           recoupment_rate,
                                           ip_category_id,
                                           supplier_part_auxid,
                                           SHIP_TO_LOCATION_ID,
                                           requisition_line_id,
                                           need_by_date,
                                           line_num,
                                           action,
                                           line_attribute_category_lines,
                                           line_attribute1,
                                           line_attribute2,
                                           line_attribute3,
                                           line_attribute4,
                                           line_attribute5,
                                           line_attribute6,
                                           line_attribute7,
                                           line_attribute8,
                                           line_attribute9,
                                           line_attribute10,
                                           line_attribute11,
                                           line_attribute12,
                                           shipment_attribute_category,
                                           shipment_attribute1,
                                           shipment_attribute2,
                                           shipment_attribute3,
                                           shipment_attribute4,
                                           shipment_attribute5,
                                           shipment_attribute6,
                                           shipment_attribute7,
                                           shipment_attribute8,
                                           shipment_attribute9,
                                           shipment_attribute10,
                                           shipment_attribute11,
                                           shipment_attribute12,
                                           shipment_attribute13,
                                           shipment_attribute14,
                                           shipment_attribute15)
                VALUES (po_lines_interface_s.NEXTVAL,
                        V_INTERFACE_HEADER_ID,
                        PO_LINES_interface_REC.item_id,
                        PO_LINES_interface_REC.job_id,
                        PO_LINES_interface_REC.category_id,
                        PO_LINES_interface_REC.item_description,
                        PO_LINES_interface_REC.UNIT_PRICE,
                        PO_LINES_interface_REC.amount,
                        PO_LINES_interface_REC.item_revision,
                        PO_LINES_interface_REC.un_number_id,
                        PO_LINES_interface_REC.hazard_class_id,
                        PO_LINES_interface_REC.contract_id,
                        PO_LINES_interface_REC.line_type_id,
                        PO_LINES_interface_REC.vendor_product_num,
                        PO_LINES_interface_REC.firm_status_lookup_code,
                        PO_LINES_interface_REC.min_release_amount,
                        PO_LINES_interface_REC.price_type_lookup_code,
                        PO_LINES_interface_REC.transaction_reason_code,
                        PO_LINES_interface_REC.from_header_id,
                        PO_LINES_interface_REC.note_to_vendor,
                        PO_LINES_interface_REC.oke_contract_header_id,
                        PO_LINES_interface_REC.oke_contract_version_id,
                        PO_LINES_interface_REC.auction_header_id,
                        PO_LINES_interface_REC.auction_line_number,
                        PO_LINES_interface_REC.auction_display_number,
                        PO_LINES_interface_REC.quantity_cancelled,
                        PO_LINES_interface_REC.committed_amount,
                        PO_LINES_interface_REC.price_break_lookup_code,
                        PO_LINES_interface_REC.expiration_date,
                        PO_LINES_interface_REC.contractor_first_name,
                        PO_LINES_interface_REC.contractor_last_name,
                        PO_LINES_interface_REC.retainage_rate,
                        PO_LINES_interface_REC.max_retainage_amount,
                        PO_LINES_interface_REC.progress_payment_rate,
                        PO_LINES_interface_REC.recoupment_rate,
                        NULL,
                        PO_LINES_interface_REC.supplier_part_auxid,
                        -- PO_COPY_TO_NEW_ORG - Start
                        --PO_LINES_interface_REC.SHIP_TO_LOCATION_ID,
                        ln_ship_to_location_id,
                        -- PO_COPY_TO_NEW_ORG - End
                        PO_LINES_interface_REC.requisition_line_id,
                        PO_LINES_interface_REC.need_by_date,
                        v_line_num,
                        'ADD',
                        PO_LINES_interface_REC.attribute_category,
                        PO_LINES_interface_REC.attribute1,
                        PO_LINES_interface_REC.attribute2,
                        PO_LINES_interface_REC.attribute3,
                        PO_LINES_interface_REC.attribute4,
                        PO_LINES_interface_REC.attribute5,
                        PO_LINES_interface_REC.attribute6,
                        PO_LINES_interface_REC.attribute7,
                        PO_LINES_interface_REC.attribute8,
                        PO_LINES_interface_REC.attribute9,
                        PO_LINES_interface_REC.attribute10,
                        PO_LINES_interface_REC.attribute11,
                        PO_LINES_interface_REC.attribute12,
                        PO_LINES_interface_REC.shipment_attribute_category,
                        PO_LINES_interface_REC.shipment_attribute1,
                        PO_LINES_interface_REC.shipment_attribute2,
                        PO_LINES_interface_REC.shipment_attribute3,
                        PO_LINES_interface_REC.shipment_attribute4,
                        PO_LINES_interface_REC.shipment_attribute5,
                        PO_LINES_interface_REC.shipment_attribute6,
                        PO_LINES_interface_REC.shipment_attribute7,
                        PO_LINES_interface_REC.shipment_attribute8,
                        PO_LINES_interface_REC.shipment_attribute9,
                        PO_LINES_interface_REC.shipment_attribute10,
                        PO_LINES_interface_REC.shipment_attribute11,
                        PO_LINES_interface_REC.shipment_attribute12,
                        PO_LINES_interface_REC.shipment_attribute13,
                        PO_LINES_interface_REC.shipment_attribute14,
                        PO_LINES_interface_REC.shipment_attribute15);
        END LOOP;*/
        -- Commented CCR0007264


        --CLOSE Cur_PO_LINES_interface;


        /*OPEN Cur_PO_DISTRIBUTIONS_interface;

        LOOP
           FETCH Cur_PO_DISTRIBUTIONS_interface
           INTO PO_DISTRIBUTIONS_interface_REC;

           EXIT WHEN Cur_PO_DISTRIBUTIONS_interface%NOTFOUND;

           INSERT INTO po_distributions_interface (INTERFACE_HEADER_ID,
                                                   INTERFACE_LINE_ID,
                                                   INTERFACE_DISTRIBUTION_ID,
                                                   req_distribution_id,
                                                   deliver_to_location_id,
                                                   deliver_to_person_id,
                                                   rate_date,
                                                   rate,
                                                   accrued_flag,
                                                   encumbered_flag,
                                                   gl_encumbered_date,
                                                   gl_encumbered_period_name,
                                                   distribution_num,
                                                   destination_type_code,
                                                   destination_organization_id,
                                                   destination_subinventory,
                                                   budget_account_id,
                                                   accrual_account_id,
                                                   variance_account_id,
                                                   dest_charge_account_id,
                                                   dest_variance_account_id,
                                                   wip_entity_id,
                                                   wip_line_id,
                                                   wip_repetitive_schedule_id,
                                                   wip_operation_seq_num,
                                                   wip_resource_seq_num,
                                                   bom_resource_id,
                                                   project_id,
                                                   task_id,
                                                   end_item_unit_number,
                                                   expenditure_type,
                                                   project_accounting_context,
                                                   destination_context,
                                                   expenditure_organization_id,
                                                   expenditure_item_date,
                                                   tax_recovery_override_flag,
                                                   recovery_rate,
                                                   award_id,
                                                   oke_contract_line_id,
                                                   oke_contract_deliverable_id,
                                                   CHARGE_ACCOUNT_ID)
                VALUES (
                          PO_DISTRIBUTIONS_interface_REC.INTERFACE_HEADER_ID, ---    INTERFACE_HEADER_ID,
                          PO_DISTRIBUTIONS_interface_REC.INTERFACE_LINE_ID, --- INTERFACE_LINE_ID,
                          po.po_distributions_interface_s.NEXTVAL, --- INTERFACE_DISTRIBUTION_ID,
                          PO_DISTRIBUTIONS_interface_REC.req_distribution_id,
                          PO_DISTRIBUTIONS_interface_REC.deliver_to_location_id,
                          PO_DISTRIBUTIONS_interface_REC.deliver_to_person_id,
                          PO_DISTRIBUTIONS_interface_REC.rate_date,
                          PO_DISTRIBUTIONS_interface_REC.rate,
                          PO_DISTRIBUTIONS_interface_REC.accrued_flag,
                          PO_DISTRIBUTIONS_interface_REC.encumbered_flag,
                          PO_DISTRIBUTIONS_interface_REC.gl_encumbered_date,
                          PO_DISTRIBUTIONS_interface_REC.gl_encumbered_period_name,
                          PO_DISTRIBUTIONS_interface_REC.distribution_num,
                          PO_DISTRIBUTIONS_interface_REC.destination_type_code,
                          PO_DISTRIBUTIONS_interface_REC.destination_organization_id,
                          PO_DISTRIBUTIONS_interface_REC.destination_subinventory,
                          PO_DISTRIBUTIONS_interface_REC.budget_account_id,
                          PO_DISTRIBUTIONS_interface_REC.accrual_account_id,
                          PO_DISTRIBUTIONS_interface_REC.variance_account_id,
                          PO_DISTRIBUTIONS_interface_REC.dest_charge_account_id,
                          PO_DISTRIBUTIONS_interface_REC.dest_variance_account_id,
                          PO_DISTRIBUTIONS_interface_REC.wip_entity_id,
                          PO_DISTRIBUTIONS_interface_REC.wip_line_id,
                          PO_DISTRIBUTIONS_interface_REC.wip_repetitive_schedule_id,
                          PO_DISTRIBUTIONS_interface_REC.wip_operation_seq_num,
                          PO_DISTRIBUTIONS_interface_REC.wip_resource_seq_num,
                          PO_DISTRIBUTIONS_interface_REC.bom_resource_id,
                          PO_DISTRIBUTIONS_interface_REC.project_id,
                          PO_DISTRIBUTIONS_interface_REC.task_id,
                          PO_DISTRIBUTIONS_interface_REC.end_item_unit_number,
                          PO_DISTRIBUTIONS_interface_REC.expenditure_type,
                          PO_DISTRIBUTIONS_interface_REC.project_accounting_context,
                          PO_DISTRIBUTIONS_interface_REC.destination_context,
                          PO_DISTRIBUTIONS_interface_REC.expenditure_organization_id,
                          PO_DISTRIBUTIONS_interface_REC.expenditure_item_date,
                          PO_DISTRIBUTIONS_interface_REC.tax_recovery_override_flag,
                          PO_DISTRIBUTIONS_interface_REC.recovery_rate,
                          PO_DISTRIBUTIONS_interface_REC.award_id,
                          PO_DISTRIBUTIONS_interface_REC.oke_contract_line_id,
                          PO_DISTRIBUTIONS_interface_REC.oke_contract_deliverable_id,
                          PO_DISTRIBUTIONS_interface_REC.code_combination_id);
        END LOOP;

        CLOSE Cur_PO_DISTRIBUTIONS_interface;*/


        apps.po_pdoi_pvt.start_process (
            p_api_version                  => 1.0,
            p_init_msg_list                => fnd_api.g_true,
            p_validation_level             => NULL,
            p_commit                       => fnd_api.g_false,
            x_return_status                => v_return_status,
            p_gather_intf_tbl_stat         => 'N',
            p_calling_module               => NULL,
            p_selected_batch_id            => p_batch_id,
            p_batch_size                   => NULL,
            p_buyer_id                     => NULL,
            p_document_type                => 'STANDARD',
            p_document_subtype             => NULL,
            p_create_items                 => 'N',
            p_create_sourcing_rules_flag   => 'N',
            p_rel_gen_method               => NULL,
            p_sourcing_level               => NULL,
            p_sourcing_inv_org_id          => NULL,
            p_approved_status              => 'APPROVED',
            p_process_code                 => NULL,
            p_interface_header_id          => v_interface_header_id,
            p_org_id                       => v_org_id,
            p_ga_flag                      => NULL,
            p_submit_dft_flag              => 'N',
            p_role                         => 'BUYER',
            p_catalog_to_expire            => NULL,
            p_err_lines_tolerance          => NULL,
            p_clm_flag                     => NULL,         --CLM PDOI Project
            x_processed_lines_count        => v_processed_lines_count,
            x_rejected_lines_count         => v_rejected_lines_count,
            x_err_tolerance_exceeded       => v_err_tolerance_exceeded);

        IF (v_return_status = fnd_api.g_ret_sts_success)
        THEN
            BEGIN
                SELECT phi.po_header_id
                  INTO v_document_id
                  FROM po_headers_interface phi
                 WHERE     phi.interface_header_id = v_interface_header_id
                       AND phi.process_code = 'ACCEPTED';


                -- CCR0006633
                -- commit;
                cancel_requisition_line (v_interface_header_id, p_error_code); --CCR0006633

                -- CCR0006633

                ---------added on 29th may for drop ship----------
                OPEN cur_update_drop_ship;

                IF cur_update_drop_ship%NOTFOUND
                THEN
                    p_error_code   := NULL;

                    DELETE FROM po_headers_interface
                          WHERE interface_header_id = v_interface_header_id;

                    DELETE FROM po_lines_interface
                          WHERE interface_header_id = v_interface_header_id;

                    DELETE FROM po_distributions_interface
                          WHERE interface_header_id = v_interface_header_id;

                    COMMIT;


                    CLOSE cur_update_drop_ship;
                ELSE
                    LOOP
                        FETCH cur_update_drop_ship
                            INTO cur_update_drop_ship_rec;

                        EXIT WHEN cur_update_drop_ship%NOTFOUND;



                        BEGIN
                            apps.oe_drop_ship_grp.update_po_info (
                                p_api_version     => 1.0,
                                p_return_status   => v_dropship_return_status,
                                p_msg_count       => v_dropship_msg_count,
                                p_msg_data        => v_dropship_msg_data,
                                p_req_header_id   =>
                                    cur_update_drop_ship_rec.requisition_header_id,
                                p_req_line_id     =>
                                    cur_update_drop_ship_rec.requisition_line_id,
                                p_po_header_id    =>
                                    cur_update_drop_ship_rec.po_header_id,
                                p_po_line_id      =>
                                    cur_update_drop_ship_rec.po_line_id,
                                p_line_location_id   =>
                                    cur_update_drop_ship_rec.line_location_id);

                            IF (v_return_status = fnd_api.g_ret_sts_success)
                            THEN
                                /*fnd_file.PUT_LINE (fnd_file.LOG,
                                                   'drop ship successs' || CHR (10));*/

                                p_error_code   := NULL;


                                UPDATE po_line_locations_all plla
                                   SET ship_to_location_id   =
                                           (SELECT DISTINCT
                                                   porl.deliver_to_location_id
                                              FROM po_requisition_headers_all porh, po_requisition_lines_all porl
                                             WHERE     porh.requisition_header_id =
                                                       porl.requisition_header_id
                                                   AND plla.line_location_id =
                                                       porl.line_location_id
                                                   AND porl.line_location_id =
                                                       cur_update_drop_ship_rec.line_location_id)
                                 WHERE plla.line_location_id =
                                       cur_update_drop_ship_rec.line_location_id;
                            ELSIF v_return_status = (fnd_api.g_ret_sts_error)
                            THEN
                                p_error_code   := 'DROP SHIP api ERROR:';


                                FOR i IN 1 .. fnd_msg_pub.count_msg
                                LOOP
                                    p_error_code   :=
                                           p_error_code
                                        || fnd_msg_pub.get (
                                               p_msg_index   => i,
                                               p_encoded     => 'F');
                                END LOOP;


                                EXIT;
                            ELSIF v_return_status =
                                  fnd_api.g_ret_sts_unexp_error
                            THEN
                                p_error_code   :=
                                    'DROP SHIP UNEXPECTED ERROR:';

                                FOR i IN 1 .. fnd_msg_pub.count_msg
                                LOOP
                                    p_error_code   :=
                                           p_error_code
                                        || fnd_msg_pub.get (
                                               p_msg_index   => i,
                                               p_encoded     => 'F');
                                END LOOP;


                                EXIT;
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_error_code   :=
                                    'drop ship when others: ' || SQLERRM;
                                EXIT;
                        END;
                    END LOOP;

                    IF p_error_code IS NULL
                    THEN
                        DELETE FROM
                            po_headers_interface
                              WHERE interface_header_id =
                                    v_interface_header_id;

                        DELETE FROM
                            po_lines_interface
                              WHERE interface_header_id =
                                    v_interface_header_id;

                        DELETE FROM
                            po_distributions_interface
                              WHERE interface_header_id =
                                    v_interface_header_id;

                        COMMIT;
                    ELSE
                        ROLLBACK;
                    END IF;
                END IF;

                CLOSE cur_update_drop_ship;

                ---------added on 29th may for drop ship----------

                --Begin CCR0007619
                XXDO_PO_APPROVAL (v_doc_number, v_org_id, lv_error_stat,
                                  lv_error_msg);

                --PO Approval failed. This is not fatal. We just need to note the error
                IF lv_error_stat != 1
                THEN                                    --PO Failed to approve
                    p_error_code   :=
                        'PO Failed to approve : ' || lv_error_msg;
                END IF;
            --End CCR0007619

            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ROLLBACK;

                    ln_request_id   :=
                        apps.fnd_request.submit_request (
                            application   => 'XXDO'  -- Application Short name
                                                   ,
                            program       => 'XXD_PO_COPY_ERR_REP' -- Concurrent prog short name
                                                                  ,
                            description   => '' -- Concurrent prog description
                                               ,
                            start_time    =>
                                TO_CHAR (SYSDATE, 'DD-MON-YY HH24:MI:SS') -- Start time
                                                                         ,
                            sub_request   => FALSE           -- submit request
                                                  ,
                            argument1     => po_headers_interface_s.CURRVAL);
                    p_error_code   :=
                           'No Document updated:Refer ''Deckers PO Copy error Program'' : Request ID :'
                        || ln_request_id;

                    COMMIT;
            END;
        ELSIF v_return_status = (fnd_api.g_ret_sts_error)
        THEN
            p_error_code   := 'UPDATE api error:';

            FOR i IN 1 .. fnd_msg_pub.count_msg
            LOOP
                p_error_code   :=
                       p_error_code
                    || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;
        ELSIF v_return_status = fnd_api.g_ret_sts_unexp_error
        THEN
            p_error_code   := 'UPDATE API UNEXPECTED ERROR:';

            FOR i IN 1 .. fnd_msg_pub.count_msg
            LOOP
                p_error_code   :=
                       p_error_code
                    || fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            p_error_code   :=
                p_error_code || 'UPDATE CODE IN ERROR' || SQLCODE || SQLERRM;
    END;
END xxd_po_copy_pkg;
/
