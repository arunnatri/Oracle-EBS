--
-- XXD_PO_MASS_MOVE_PO  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_MASS_MOVE_PO"
/*
================================================================
 Created By              : Greg Jensen
 Creation Date           : 20-Mar-2018
 File Name               : XXD_PO_MASS_MOVE_PO.pkb
 Incident Num            :
 Description             :
 Latest Version          : 1.0

================================================================
 Date               Version#    Name                    Remarks
================================================================
20-Mar-2018        1.0      GJensen

--does a Move PO destination by cancelling all lines/reqs on a PO then adding new lines to the same PO
--Assumption : ONLY valid for Deckers US POs at this time
======================================================================================
*/
IS
    lv_cancel_reason   CONSTANT VARCHAR2 (100)
                                    := 'Cancelled for PO DC Move process' ;

    FUNCTION get_next_batch_id
        RETURN NUMBER
    IS
        n_val   NUMBER;
    BEGIN
        SELECT XXDO.XXD_PO_MASS_MOVE_BATCH_S.NEXTVAL INTO n_val FROM DUAL;

        RETURN n_val;
    END;

    FUNCTION get_batch_name (pn_batch_id IN NUMBER)
        RETURN VARCHAR
    IS
        l_val         VARCHAR2 (50);
        ln_batch_id   NUMBER;
    BEGIN
        IF pn_batch_id IS NULL
        THEN
            ln_batch_id   := get_next_batch_id;
        ELSE
            ln_batch_id   := pn_batch_id;
        END IF;

        l_val   :=
               'PO_MV '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY')
            || ':'
            || ln_batch_id;
        RETURN l_val;
    END;


    --Cancels the PO lines for a given PO and return a table detaining the cancelled lines
    PROCEDURE cancel_po_lines (p_po_header_id IN NUMBER, P_ERROR_CODE OUT VARCHAR2, P_PO_LINE_ID OUT xxd_po_line_TYPE)
    IS
        CURSOR cur_cancel_lines IS
            SELECT pol.*, PRLA.REQUISITION_LINE_ID
              FROM po_headers_all poh, po_lines_all pol, po_line_locations_all poll,
                   po_requisition_lines_all prla, po_req_distributions_all prda, po_distributions_all pda
             WHERE     poh.po_header_id = p_po_header_id
                   AND poh.po_header_id = pol.po_header_id
                   AND pol.po_header_id = poll.po_header_id
                   AND pol.po_line_id = poll.po_line_id
                   AND poll.closed_code = 'OPEN'
                   AND poll.QUANTITY_RECEIVED = 0
                   AND pol.quantity != 0
                   AND pda.po_line_id = pol.po_line_id
                   AND pda.po_header_id = poh.po_header_id
                   AND pda.req_distribution_id = prda.distribution_id(+)
                   AND prda.requisition_line_id = prla.requisition_line_id(+);


        -- INCORRECT_COMBINATIONS - End

        v_cur_cancel_lines   cur_cancel_lines%ROWTYPE;

        v_return_status      VARCHAR2 (100);
        v_resp_appl_id       NUMBER;
        v_resp_id            NUMBER;
        v_user_id            NUMBER;
        V_CANCEL_FLAG        VARCHAR2 (10);
    BEGIN
        P_ERROR_CODE     := NULL;
        v_resp_appl_id   := fnd_global.resp_appl_id;
        v_resp_id        := fnd_global.resp_id;
        v_user_id        := fnd_global.user_id;
        --  APPS.fnd_global.APPS_INITIALIZE (v_user_id, v_resp_id, v_resp_appl_id);
        /*        MO_GLOBAL.SET_POLICY_CONTEXT('S',81);
     DBMS_OUTPUT.PUT_LINE('after Policy context');*/

        --Use login from caller
        /*     APPS.DO_APPS_INITIALIZE (user_id        => 1876,
                                      --resp_id        => 51395, -- Deckers Purchasing User - Americas
                                      resp_id        => 52535, --Deckers P2P Batch Scheduler Responsibility
                                      resp_appl_id   => 201);*/

        p_po_line_id     := xxd_po_line_TYPE (NULL);

        APPS.mo_global.init ('PO');


        OPEN cur_cancel_lines;

        -- INCORRECT_COMBINATIONS - End

        LOOP
            FETCH cur_cancel_lines INTO v_cur_cancel_lines;

            EXIT WHEN cur_cancel_lines%NOTFOUND;

            p_po_line_id.EXTEND;
            -- P_PO_LINE_ID(xxd_po_line_tab.EXTEND);

            P_PO_LINE_ID (p_po_line_id.COUNT)   :=
                xxd_po_line_tab (v_cur_cancel_lines.po_line_id,
                                 v_cur_cancel_lines.REQUISITION_LINE_ID);
            --P_PO_LINE_ID (p_po_line_id.COUNT) := v_cur_cancel_lines.po_line_id;

            APPS.PO_Document_Control_PUB.control_document (
                p_api_version             => 1.0,
                p_init_msg_list           => FND_API.G_TRUE,
                p_commit                  => FND_API.G_FALSE, --We are not commiting
                x_return_status           => v_return_status,
                p_doc_type                => 'PO',
                p_doc_subtype             => 'STANDARD',
                p_doc_id                  => p_po_header_id,
                p_doc_num                 => NULL,
                p_release_id              => NULL,
                p_release_num             => NULL,
                p_doc_line_id             => v_cur_cancel_lines.po_line_id,
                p_doc_line_num            => NULL,
                p_doc_line_loc_id         => NULL,
                p_doc_shipment_num        => NULL,
                p_action                  => 'CANCEL',
                p_action_date             => SYSDATE,
                p_cancel_reason           => lv_cancel_reason,
                p_cancel_reqs_flag        => 'N',
                p_print_flag              => NULL,
                p_note_to_vendor          => NULL,
                p_use_gldate              => NULL,        -- <ENCUMBRANCE FPJ>
                p_org_id                  => v_cur_cancel_lines.ORG_ID, --<Bug#4581621>
                p_launch_approvals_flag   => NULL             --<Bug#14605476>
                                                 );


            IF (v_return_status = FND_API.g_ret_sts_success)
            THEN
                SELECT cancel_flag
                  INTO v_cancel_flag
                  FROM po_lines_all
                 WHERE po_line_id = v_cur_cancel_lines.po_line_id;

                IF V_CANCEL_FLAG = 'Y'
                THEN
                    --P_ERROR_CODE := 'v_cancel_flag: '||v_cancel_flag;
                    NULL;
                ELSE
                    P_ERROR_CODE   := 'cancel api error:';

                    FOR i IN 1 .. FND_MSG_PUB.count_msg
                    LOOP
                        P_ERROR_CODE   :=
                               P_ERROR_CODE
                            || FND_MSG_PUB.Get (p_msg_index   => i,
                                                p_encoded     => 'F');
                    END LOOP;


                    EXIT;
                END IF;
            ELSIF v_return_status = (FND_API.G_RET_STS_ERROR)
            THEN
                P_ERROR_CODE   := 'cancel api error:';

                FOR i IN 1 .. FND_MSG_PUB.count_msg
                LOOP
                    P_ERROR_CODE   :=
                           P_ERROR_CODE
                        || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F');
                END LOOP;


                EXIT;
            ELSIF v_return_status = FND_API.G_RET_STS_UNEXP_ERROR
            THEN
                P_ERROR_CODE   := 'cancel API UNEXPECTED ERROR:';

                FOR i IN 1 .. FND_MSG_PUB.count_msg
                LOOP
                    P_ERROR_CODE   :=
                           P_ERROR_CODE
                        || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F');
                END LOOP;

                EXIT;
            END IF;
        END LOOP;

        CLOSE cur_cancel_lines;
    EXCEPTION
        WHEN OTHERS
        THEN
            P_ERROR_CODE   := 'CANCEL API exception others' || SQLERRM;
    END;


    --Cancels requisition lines based on the passed in table of PO_lINE_IDs and REQ IDs
    PROCEDURE cancel_requisition_line (
        P_PO_LINE_ID   IN            xxd_po_line_TYPE,
        P_ERROR_CODE      OUT NOCOPY VARCHAR2)
    IS
        CURSOR cur_cancel_req_lines IS
            SELECT prha.requisition_header_id, prla.requisition_line_id, prha.preparer_id,
                   prha.org_id, prha.type_lookup_code, pdt.document_type_code
              FROM po_requisition_lines_all prla, po_requisition_headers_all prha, apps.po_document_types_all pdt,
                   TABLE (p_po_line_id) p_po_line_TAB
             WHERE     prha.requisition_header_id =
                       prla.requisition_header_id
                   AND prha.type_lookup_code = pdt.document_subtype
                   AND prha.org_id = pdt.org_id
                   AND prla.requisition_line_id =
                       p_po_line_TAB.requisition_line_id;

        X_req_control_error_rc   VARCHAR2 (500);
        v_resp_id                NUMBER;
        v_resp_appl_id           NUMBER;
        v_user_id                NUMBER;
    BEGIN
        --DBMS_OUTPUT.put_line ('Cancel REQ enter');
        P_ERROR_CODE     := NULL;
        v_resp_appl_id   := fnd_global.resp_appl_id;
        v_resp_id        := fnd_global.resp_id;
        v_user_id        := fnd_global.user_id;
        --  APPS.fnd_global.APPS_INITIALIZE (v_user_id, v_resp_id, v_resp_appl_id);

        /*  APPS.DO_APPS_INITIALIZE (user_id        => 1876,
                                   --resp_id        => 51395, --Deckers Purchasing User - Americas
                                   resp_id        => 52535, --Deckers P2P Batch Scheduler Responsibility
                                   resp_appl_id   => 201);*/

        mo_global.init ('PO');

        --  apps.mo_global.set_policy_context ('S', 95);

        FOR rec_cancel_req_lines IN cur_cancel_req_lines
        LOOP
            BEGIN
                --DBMS_OUTPUT.put_line (
                --  'Header ID : ' || rec_cancel_req_lines.requisition_header_id);
                --DBMS_OUTPUT.put_line (
                --   'Line ID : ' || rec_cancel_req_lines.requisition_line_id);

                apps.mo_global.set_policy_context (
                    'S',
                    rec_cancel_req_lines.org_id);

                --fnd_file.PUT_LINE (fnd_file.LOG,
                --   'REQ to cancel : ' || rec_cancel_req_lines.requisition_line_id);

                po_reqs_control_sv.update_reqs_status (
                    X_req_header_id          =>
                        rec_cancel_req_lines.requisition_header_id,
                    X_req_line_id            =>
                        rec_cancel_req_lines.requisition_line_id,
                    X_agent_id               => rec_cancel_req_lines.preparer_id,
                    X_req_doc_type           => 'REQUISITION',
                    X_req_doc_subtype        =>
                        rec_cancel_req_lines.type_lookup_code,
                    X_req_control_action     => 'CANCEL',
                    X_req_control_reason     => 'CANCELLED BY API FOR PO COPY',
                    X_req_action_date        => SYSDATE,
                    X_encumbrance_flag       => 'N',
                    X_oe_installed_flag      => 'Y',
                    X_req_control_error_rc   => X_req_control_error_rc);
            -- fnd_file.PUT_LINE (fnd_file.LOG,'Return ; ' || X_req_control_error_rc);

            --   DBMS_OUTPUT.put_line ('Return : ' || X_req_control_error_rc);
            EXCEPTION
                WHEN OTHERS
                THEN
                    --    DBMS_OUTPUT.put_line ('Error cancelling req :' || SQLERRM);
                    fnd_file.PUT_LINE (fnd_file.LOG,
                                       'Exception : ' || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            --  DBMS_OUTPUT.put_line ('Error cancelling req :' || SQLERRM);
            --ROLLBACK;
            P_ERROR_CODE   :=
                   P_ERROR_CODE
                || 'CANCEL REQUISITION LINES IN ERROR'
                || SQLCODE
                || SQLERRM;
    END;

    PROCEDURE open_po (p_po_header_id IN NUMBER)
    IS
        l_return_status      VARCHAR2 (2000);
        l_return_code        VARCHAR2 (2000);
        l_exc_msg            VARCHAR2 (2000);
        l_online_report_id   NUMBER;
    BEGIN
        apps.PO_DOCUMENT_ACTION_PVT.do_manual_close (
            p_action             => 'OPEN',
            p_document_id        => p_po_header_id              --po_header_id
                                                  ,
            p_document_type      => 'PO',
            p_document_subtype   => 'STANDARD' --pass BLANKET in case of a BPA
                                              ,
            p_line_id            => NULL --pass a line ID if specific line is to open
                                        ,
            p_shipment_id        => NULL --pass a line location ID if specific shipment line is to open
                                        ,
            p_reason             => 'Re-Open for DS SO Line Cancel' --give any free-text reason
                                                                   ,
            p_action_date        => SYSDATE  --pass SYSDATE in specific format
                                           ,
            p_calling_mode       => 'PO',
            p_origin_doc_id      => NULL,
            p_called_from_conc   => TRUE --this should be TRUE as it is not called from the GUI
                                        ,
            p_use_gl_date        => NVL (NULL, 'N'),
            x_return_status      => l_return_status,
            x_return_code        => l_return_code,
            x_exception_msg      => l_exc_msg,
            x_online_report_id   => l_online_report_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END;

    --Add the new lines to the PO from the PO lines table. The PO lines are added for the new destination organization
    PROCEDURE add_po_lines (pn_po_header_id IN NUMBER, P_PO_LINE_ID IN xxd_po_line_TYPE, P_BATCH_ID IN VARCHAR2
                            , pn_organization_id IN NUMBER, pv_gtn_update_flag IN VARCHAR2, P_ERROR_CODE OUT NOCOPY VARCHAR2)
    IS
        CURSOR cur_po_header IS
            SELECT segment1 document_num, vendor_id, vendor_site_id,
                   ship_to_location_id, bill_to_location_id, currency_code,
                   agent_id, po_header_id, org_id
              FROM apps.po_headers_all
             WHERE po_header_id = pn_po_header_id;

        CURSOR Cur_PO_LINES_interface IS
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
                   PHA.SHIP_TO_LOCATION_ID,
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
                   END AS attribute5,
                   pla.attribute6,
                   pla.attribute7,
                   pla.attribute8,
                   pla.attribute9,
                   TO_CHAR (p_po_line_TAB.PO_LINE_ID) attribute10, --Assign source PO line ID to attribute10 in Destination line
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
                   TABLE (p_po_line_id) p_po_line_TAB
             WHERE     pha.po_header_id = pn_po_header_id
                   AND pla.cancel_flag = 'Y'
                   AND pha.po_header_id = pla.po_header_id
                   AND PLA.PO_HEADER_ID = PLLA.PO_HEADER_ID
                   AND PLA.PO_LINE_ID = PLLA.PO_LINE_ID
                   AND pla.po_line_id = p_po_line_TAB.PO_LINE_ID;

        V_INTERFACE_HEADER_ID        NUMBER := po_headers_interface_s.NEXTVAL;
        lv_gtn_update_flag           VARCHAR (10);

        v_document_creation_method   po_headers_all.document_creation_method%TYPE;
        -- V_batch_id                   NUMBER := P_BATCH_ID;
        ln_request_id                VARCHAR2 (50);
        PO_LINES_interface_REC       Cur_PO_LINES_interface%ROWTYPE;

        v_return_status              VARCHAR2 (50);
        v_processed_lines_count      NUMBER := 0;
        v_rejected_lines_count       NUMBER := 0;
        v_err_tolerance_exceeded     VARCHAR2 (100);
        v_line_num                   NUMBER := 0;
        cur_po_header_rec            cur_po_header%ROWTYPE;
        v_document_id                NUMBER;
        v_resp_appl_id               NUMBER;
        v_resp_id                    NUMBER;
        v_user_id                    NUMBER;
        V_ORG_ID                     NUMBER;

        n_cnt                        NUMBER;
        n_batch_id                   NUMBER;
        v_process_code               VARCHAR2 (20);
        v_error_code                 VARCHAR2 (2000);

        -- PO_COPY_TO_NEW_ORG - Start
        ln_ship_to_location_id       NUMBER;
        ln_bill_to_location_id       NUMBER;
    -- PO_COPY_TO_NEW_ORG - End

    BEGIN
        P_ERROR_CODE     := NULL;

        IF pv_gtn_update_flag = 'Y'
        THEN
            lv_gtn_update_flag   := 'True';
        ELSE
            lv_gtn_update_flag   := 'False';
        END IF;

        v_resp_appl_id   := fnd_global.resp_appl_id;
        v_resp_id        := fnd_global.resp_id;
        v_user_id        := fnd_global.user_id;
        --  APPS.fnd_global.APPS_INITIALIZE (v_user_id, v_resp_id, v_resp_appl_id);
        /*     APPS.DO_APPS_INITIALIZE (user_id        => 1876,
                                      -- resp_id        => 51395, --Deckers Purchasing User - Americas
                                      resp_id        => 52535, --Deckers P2P Batch Scheduler Responsibility
                                      resp_appl_id   => 201);*/

        --DBMS_OUTPUT.PUT_LINE('after Policy context');

        fnd_file.PUT_LINE (fnd_file.LOG,
                           'GTN Transfer Flag : ' || pv_gtn_update_flag);

        mo_global.init ('PO');

        OPEN cur_po_header;

        IF cur_po_header%NOTFOUND
        THEN
            CLOSE cur_po_header;
        ELSE
            FETCH cur_po_header INTO cur_po_header_rec;

            V_ORG_ID                 := cur_po_header_rec.org_id;
            MO_GLOBAL.SET_POLICY_CONTEXT ('S', V_ORG_ID);


            BEGIN
                SELECT ship_to_location_id
                  INTO ln_ship_to_location_id
                  FROM hr_locations
                 WHERE inventory_organization_id = pn_organization_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_ship_to_location_id   :=
                        cur_po_header_rec.ship_to_location_id;
            END;

            ln_bill_to_location_id   := cur_po_header_rec.bill_to_location_id;

            --fnd_file.PUT_LINE (fnd_file.LOG,'Interface ID: ' || V_INTERFACE_HEADER_ID);

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
                 VALUES (V_INTERFACE_HEADER_ID, P_BATCH_ID, 'UPDATE',
                         cur_po_header_rec.org_id,   -- Your operating unit id
                                                   'STANDARD', cur_po_header_rec.document_num, cur_po_header_rec.currency_code, -- Your currency code
                                                                                                                                cur_po_header_rec.agent_id, -- Your buyer id
                                                                                                                                                            cur_po_header_rec.vendor_id, cur_po_header_rec.vendor_site_id, -- PO_COPY_TO_NEW_ORG - Start
                                                                                                                                                                                                                           --cur_po_header_rec.ship_to_location_id,   -- Your ship to
                                                                                                                                                                                                                           --cur_po_header_rec.BILL_to_location_id,   -- Your bill to
                                                                                                                                                                                                                           ln_ship_to_location_id, ln_bill_to_location_id
                         , -- PO_COPY_TO_NEW_ORG - End
                           'PO Copy', cur_po_header_rec.po_header_id); -- Any reference num
        END IF;

        CLOSE cur_po_header;

        OPEN Cur_PO_LINES_interface;

        LOOP
            FETCH Cur_PO_LINES_interface INTO PO_LINES_interface_REC;

            EXIT WHEN Cur_PO_LINES_interface%NOTFOUND;

            v_line_num   := v_line_num + 1;

            INSERT INTO po_lines_interface (interface_line_id, interface_header_id, item_id, job_id, -- <SERVICES FPJ>
                                                                                                     category_id, item_description, UNIT_PRICE, amount, item_revision, un_number_id, hazard_class_id, contract_id, line_type_id, vendor_product_num, firm_FLAG, min_release_amount, price_type, transaction_reason_code, from_header_id, note_to_vendor, oke_contract_header_id, oke_contract_version_id, auction_header_id, auction_line_number, auction_display_number, quantity, committed_amount, price_break_lookup_code, expiration_date, contractor_first_name, contractor_last_name, retainage_rate, max_retainage_amount, progress_payment_rate, recoupment_rate, ip_category_id, supplier_part_auxid, SHIP_TO_LOCATION_ID, -- requisition_line_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     need_by_date, --          line_num,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   action, line_attribute_category_lines, line_attribute1, line_attribute2, line_attribute3, line_attribute4, line_attribute5, line_attribute6, line_attribute7, line_attribute8, line_attribute9, line_attribute10, line_attribute11, line_attribute12, line_attribute13, shipment_attribute_category, shipment_attribute1, shipment_attribute2, shipment_attribute3, shipment_attribute4, shipment_attribute5, shipment_attribute6, shipment_attribute7, shipment_attribute8, shipment_attribute9, shipment_attribute10, shipment_attribute11, shipment_attribute12, shipment_attribute13, shipment_attribute14
                                            , shipment_attribute15)
                 VALUES (po_lines_interface_s.NEXTVAL, V_INTERFACE_HEADER_ID, PO_LINES_interface_REC.item_id, PO_LINES_interface_REC.job_id, PO_LINES_interface_REC.category_id, PO_LINES_interface_REC.item_description, PO_LINES_interface_REC.UNIT_PRICE, PO_LINES_interface_REC.amount, PO_LINES_interface_REC.item_revision, PO_LINES_interface_REC.un_number_id, PO_LINES_interface_REC.hazard_class_id, PO_LINES_interface_REC.contract_id, PO_LINES_interface_REC.line_type_id, PO_LINES_interface_REC.vendor_product_num, PO_LINES_interface_REC.firm_status_lookup_code, PO_LINES_interface_REC.min_release_amount, PO_LINES_interface_REC.price_type_lookup_code, PO_LINES_interface_REC.transaction_reason_code, PO_LINES_interface_REC.from_header_id, PO_LINES_interface_REC.note_to_vendor, PO_LINES_interface_REC.oke_contract_header_id, PO_LINES_interface_REC.oke_contract_version_id, PO_LINES_interface_REC.auction_header_id, PO_LINES_interface_REC.auction_line_number, PO_LINES_interface_REC.auction_display_number, PO_LINES_interface_REC.quantity_cancelled, PO_LINES_interface_REC.committed_amount, PO_LINES_interface_REC.price_break_lookup_code, PO_LINES_interface_REC.expiration_date, PO_LINES_interface_REC.contractor_first_name, PO_LINES_interface_REC.contractor_last_name, PO_LINES_interface_REC.retainage_rate, PO_LINES_interface_REC.max_retainage_amount, PO_LINES_interface_REC.progress_payment_rate, PO_LINES_interface_REC.recoupment_rate, NULL, PO_LINES_interface_REC.supplier_part_auxid, -- PO_COPY_TO_NEW_ORG - Start
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  --PO_LINES_interface_REC.SHIP_TO_LOCATION_ID,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  ln_ship_to_location_id, -- PO_COPY_TO_NEW_ORG - End
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          -- PO_LINES_interface_REC.requisition_line_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          PO_LINES_interface_REC.need_by_date, --  v_line_num,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               'ADD', PO_LINES_interface_REC.attribute_category, PO_LINES_interface_REC.attribute1, PO_LINES_interface_REC.attribute2, PO_LINES_interface_REC.attribute3, PO_LINES_interface_REC.attribute4, PO_LINES_interface_REC.attribute5, PO_LINES_interface_REC.attribute6, PO_LINES_interface_REC.attribute7, PO_LINES_interface_REC.attribute8, PO_LINES_interface_REC.attribute9, PO_LINES_interface_REC.attribute10, PO_LINES_interface_REC.attribute11, PO_LINES_interface_REC.attribute12, lv_gtn_update_flag, PO_LINES_interface_REC.shipment_attribute_category, PO_LINES_interface_REC.shipment_attribute1, PO_LINES_interface_REC.shipment_attribute2, PO_LINES_interface_REC.shipment_attribute3, PO_LINES_interface_REC.shipment_attribute4, PO_LINES_interface_REC.shipment_attribute5, PO_LINES_interface_REC.shipment_attribute6, PO_LINES_interface_REC.shipment_attribute7, PO_LINES_interface_REC.shipment_attribute8, PO_LINES_interface_REC.shipment_attribute9, PO_LINES_interface_REC.shipment_attribute10, PO_LINES_interface_REC.shipment_attribute11, PO_LINES_interface_REC.shipment_attribute12, PO_LINES_interface_REC.shipment_attribute13, PO_LINES_interface_REC.shipment_attribute14
                         , PO_LINES_interface_REC.shipment_attribute15);
        END LOOP;

        CLOSE Cur_PO_LINES_interface;

        -- DBMS_OUTPUT.put_line ('Before PDOI');

        APPS.PO_PDOI_PVT.start_process (
            p_api_version                  => 1.0,
            p_init_msg_list                => FND_API.G_TRUE,
            p_validation_level             => NULL,
            p_commit                       => FND_API.G_FALSE,
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
            p_interface_header_id          => V_INTERFACE_HEADER_ID,
            p_org_id                       => V_ORG_ID,
            p_ga_flag                      => NULL,
            p_submit_dft_flag              => 'N',
            p_role                         => 'BUYER',
            p_catalog_to_expire            => NULL,
            p_err_lines_tolerance          => NULL,
            p_clm_flag                     => NULL,         --CLM PDOI Project
            x_processed_lines_count        => v_processed_lines_count,
            x_rejected_lines_count         => v_rejected_lines_count,
            x_err_tolerance_exceeded       => v_err_tolerance_exceeded);

        -- DBMS_OUTPUT.put_line (
        --    v_return_status || '-' || FND_API.g_ret_sts_success);

        IF (v_return_status = FND_API.g_ret_sts_success)
        THEN
            BEGIN
                -- fnd_file.PUT_LINE (fnd_file.LOG,
                --   'processed ' || v_processed_lines_count || ' lines');
                -- fnd_file.PUT_LINE (fnd_file.LOG,
                --   'rejected ' || v_rejected_lines_count || ' lines');

                /*  SELECT PHI.PO_HEADER_ID
                    INTO v_document_id
                    FROM PO_HEADERS_INTERFACE PHI
                   WHERE     PHI.INTERFACE_HEADER_ID = V_INTERFACE_HEADER_ID
                         AND PHI.PROCESS_CODE = 'ACCEPTED';*/

                ---  fnd_file.PUT_LINE (fnd_file.LOG,'Accepted');

                cancel_requisition_line (P_PO_LINE_ID, P_ERROR_CODE);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ROLLBACK;

                    P_ERROR_CODE   := 'No Document updated:';
            END;
        ELSIF v_return_status = (FND_API.G_RET_STS_ERROR)
        THEN
            P_ERROR_CODE   := 'UPDATE api error:';

            FOR i IN 1 .. FND_MSG_PUB.count_msg
            LOOP
                P_ERROR_CODE   :=
                       P_ERROR_CODE
                    || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F');
            END LOOP;
        ELSIF v_return_status = FND_API.G_RET_STS_UNEXP_ERROR
        THEN
            P_ERROR_CODE   := 'UPDATE API UNEXPECTED ERROR:';

            FOR i IN 1 .. FND_MSG_PUB.count_msg
            LOOP
                P_ERROR_CODE   :=
                       P_ERROR_CODE
                    || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F');
            END LOOP;
        END IF;
    END;

    /*
    Public acces function to move one PO to a new shipping location
    Parameters
    Output
        pv_error_stat                   Return status
        pv_error_msg                     Return error message
    Input
        pv_po_number                    PO to move
        pn_organization_id              New destination DC (Must be a trade location in the same Operating unit of the current PO shipping location
        pv_gtn_update_flag              Set to 'N' to prevent further transmissions of ths PO to GTN
        pn_batch_id                     Batch ID (Optional)
        pv_batch_name                   Batch Name (Optional) written to PHA.Attribute13
    */
    PROCEDURE move_po (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pv_po_number IN VARCHAR2, pn_organization_id IN NUMBER, pv_gtn_update_flag IN VARCHAR2:= 'N', pn_batch_id IN NUMBER:= NULL
                       , pv_batch_name IN VARCHAR2:= NULL)
    IS
        L_PO_LINE_ID              xxd_po_line_TYPE;
        L_ERROR_CODE              VARCHAR2 (2000);

        ln_po_header_id           NUMBER;
        lv_authorization_status   VARCHAR2 (30);
        lv_closed_code            VARCHAR2 (20);
        ln_org_id                 NUMBER;

        P_BATCH_ID                VARCHAR2 (20);

        n_lines                   NUMBER;
        n_cnt                     NUMBER;
        n_cancelled_lines         NUMBER;
        n_cancelled_reqs          NUMBER;
        ln_dest_org               NUMBER;
        ln_po_organization_id     NUMBER;
        lv_Trade_org              VARCHAR2 (10);

        lv_Message                VARCHAR2 (2000);

        n_new_lines               NUMBER;
        n_xcl_lines               NUMBER;

        ln_batch_id               NUMBER;
        lv_batch_name             VARCHAR2 (50);


        exValidation              EXCEPTION;
        exProcess                 EXCEPTION;
    BEGIN
        --Validate PO to cancel/move

        --Set Batch ID and Batch Name if not passed into function
        IF pn_batch_id IS NULL
        THEN
            ln_batch_id   := get_next_batch_id;
        ELSE
            ln_batch_id   := pn_batch_id;
        END IF;

        IF pv_batch_name IS NULL
        THEN
            lv_batch_name   := get_batch_name (ln_batch_id);
        ELSE
            lv_batch_name   := pv_batch_name;
        END IF;

        fnd_file.PUT_LINE (
            fnd_file.LOG,
               'Move PO - PO Number : '
            || pv_po_number
            || CHR (9)
            || ' Organization ID : '
            || pn_organization_id
            || CHR (9)
            || ' GTN Update Flag : '
            || pv_gtn_update_flag);

        fnd_file.PUT_LINE (fnd_file.LOG, 'Before validation');

        --Validation block
        BEGIN
            BEGIN
                --Check if PO in staging table and is being processed under another batch number
                SELECT COUNT (*)
                  INTO n_cnt
                  FROM XXDO.XXD_PO_MASS_MOVE_STG_T
                 WHERE     po_number = pv_po_number
                       AND status IN ('R', 'P')
                       AND batch_id != ln_batch_id;

                IF n_cnt > 0
                THEN
                    lv_message   :=
                        'PO is being processed from staging table under a different batch number';
                    RAISE exValidation;
                END IF;

                --Check if PO number is in system

                SELECT pha.po_header_id, pha.authorization_status, pha.closed_code,
                       pha.org_id, mp.organization_id, mp.attribute13
                  INTO ln_po_header_id, lv_authorization_status, lv_closed_code, ln_org_id,
                                      ln_po_organization_id, lv_trade_org
                  FROM po_headers_all pha,
                       mtl_parameters mp,
                       (  SELECT po_header_id, MAX (ship_to_organization_id) ship_to_organization_id
                            FROM po_line_locations_all plla1
                           WHERE NVL (plla1.cancel_flag, 'N') = 'N'
                        GROUP BY po_header_id) plla
                 WHERE     pha.segment1 = pv_po_number
                       AND plla.ship_to_organization_id = mp.organization_id
                       AND pha.po_header_id = plla.po_header_id;

                IF NVL (lv_closed_code, 'OPEN') = 'CLOSED'
                THEN
                    lv_message   := 'PO not open';
                    RAISE exValidation;
                END IF;

                --check if PO is in APPROVED state
                IF lv_authorization_status != 'APPROVED'
                THEN
                    lv_message   :=
                        'PO is in ' || lv_authorization_status || ' status';
                    RAISE exValidation;
                END IF;

                IF lv_Trade_org != '2'
                THEN
                    lv_message   :=
                        'PO is shipping to a Non-Trade Organization';
                    RAISE exValidation;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_message   := 'PO Not found';
                    RAISE exValidation;
                WHEN exValidation
                THEN
                    RAISE exValidation;
            END;

            --validate that destination org is in same OU as source.
            BEGIN
                SELECT TO_NUMBER (attribute1)
                  INTO ln_dest_org
                  FROM hr_all_organization_units
                 WHERE organization_id = pn_organization_id;

                IF ln_dest_org != ln_org_id
                THEN
                    lv_message   :=
                        'Destination operating unit does not match source operating unit';
                    RAISE exValidation;
                END IF;
            EXCEPTION
                WHEN exValidation
                THEN
                    RAISE exValidation;
                WHEN OTHERS
                THEN
                    lv_message   :=
                           'Error when retrieving destination operating unit '
                        || SQLERRM;
                    RAISE exValidation;
            END;

            --
            IF ln_po_organization_id = pn_organization_id
            THEN
                lv_message   := 'PO is already shipping to new organization ';
                RAISE exValidation;
            END IF;

            --check if any of the PO shipments are Drop Ships
            SELECT COUNT (*)
              INTO n_cnt
              FROM po_line_locations_all plla
             WHERE     NVL (drop_ship_flag, 'N') = 'Y'
                   AND plla.po_header_id = ln_po_header_id;

            fnd_file.PUT_LINE (fnd_file.LOG, 'Drop ship lines : ' || n_cnt);

            IF n_cnt > 0
            THEN
                lv_message   := 'PO has drop ship lines';
                RAISE exValidation;
            END IF;

            --Check for reservations to a SO
            SELECT COUNT (*)
              INTO n_cnt
              FROM po_line_locations_all plla, mtl_reservations mr
             WHERE     plla.line_location_id = mr.supply_source_line_id
                   AND plla.po_header_id = ln_po_header_id
                   AND demand_source_type_id = 8; --Reservations where the demand is coming from a Sales Order

            fnd_file.PUT_LINE (fnd_file.LOG, 'ISO reservations : ' || n_cnt);

            IF n_cnt > 0
            THEN
                lv_message   :=
                    'PO has reservations to an internal sales order';
                RAISE exValidation;
            END IF;


            --Check if any ASNs already exist
            SELECT COUNT (*)
              INTO n_cnt
              FROM po_lines_all pla, rcv_shipment_lines rsl
             WHERE     pla.po_header_id = ln_po_header_id
                   AND pla.po_line_id = rsl.po_line_id
                   AND rsl.shipment_line_status_code != 'CANCELLED'
                   AND NVL (closed_code, 'OPEN') = 'OPEN';

            IF n_cnt > 0
            THEN
                lv_message   := 'PO contains ASNs';
                RAISE exValidation;
            END IF;

            --get count of open lines
            SELECT COUNT (*)
              INTO n_lines
              FROM po_lines_all pla
             WHERE     pla.po_header_id = ln_po_header_id
                   AND NVL (closed_code, 'OPEN') = 'OPEN';

            IF n_lines = 0
            THEN
                lv_message   := 'No open lines to move';
                RAISE exValidation;
            END IF;
        --Exception handler for validation step
        EXCEPTION
            WHEN exValidation
            THEN
                pv_error_stat   := 'E';
                pv_error_msg    := 'Validation: ' || lv_message;

                RETURN;
            WHEN OTHERS
            THEN
                pv_error_stat   := 'U';
                pv_error_msg    := 'Unexpected error ' || SQLERRM;

                RETURN;
        END;

        --End validation block


        --Processing block
        BEGIN
            --Begin a transacton segment for the movement of this PO
            SAVEPOINT move_rec;

            --Cancel po_lines
            cancel_po_lines (ln_po_header_id, L_ERROR_CODE, L_PO_LINE_ID);

            --validate cancelled_lines

            IF L_ERROR_CODE IS NOT NULL
            THEN
                lv_message   := L_ERROR_CODE;
                RAISE exProcess;
            END IF;

            --Get cancelled lines as count of records in table
            n_cancelled_lines   := L_PO_LINE_ID.COUNT - 1;

            --Validate that all lines were cancelled
            IF n_cancelled_lines != n_lines
            THEN
                lv_message   :=
                       'there were '
                    || n_lines
                    || ' to cancel and only '
                    || n_cancelled_lines
                    || 'were cancelled.';
                RAISE exProcess;
            END IF;


            --Get current closed state of PO
            SELECT closed_code
              INTO lv_closed_code
              FROM po_headers_all
             WHERE po_header_id = ln_po_header_id;


            IF lv_closed_code = 'CLOSED'
            THEN
                open_po (ln_po_header_id);
            END IF;

            --Recheck if PO is open
            SELECT closed_code
              INTO lv_closed_code
              FROM po_headers_all
             WHERE po_header_id = ln_po_header_id;

            IF NVL (lv_closed_code, 'OPEN') != 'OPEN'
            THEN
                lv_message   := 'PO failed to reopen after cancellation';
                RAISE exProcess;
            END IF;


            --add new po_lines
            add_po_lines (ln_po_header_id,
                          L_PO_LINE_ID,
                          pn_BATCH_ID,
                          pn_organization_id,
                          pv_gtn_update_flag,
                          L_ERROR_CODE);

            IF l_error_code IS NOT NULL
            THEN
                lv_message   := L_ERROR_CODE;
                RAISE exProcess;
            END IF;


            BEGIN
                SELECT SUM (DECODE (NVL (cancel_flag, 'N'), 'N', 1, 0)) ttl, SUM (DECODE (NVL (cancel_flag, 'N'), 'N', 0, 1)) xcl
                  INTO n_new_lines, n_xcl_lines
                  FROM po_lines_all
                 WHERE po_header_id = ln_po_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            --Validate that created lines/count matches cancelled lines/count
            fnd_file.PUT_LINE (
                fnd_file.LOG,
                   ' After PO Move Process - New Line Count : '
                || n_new_lines
                || ' - Cancelled line count : '
                || n_xcl_lines);


            --Update header ship_to_location, batch_name and GTN update flag
            UPDATE po_headers_all
               SET ship_to_location_id   =
                       (SELECT location_id
                          FROM hr_all_organization_units
                         WHERE organization_id = pn_organization_id),
                   attribute13   = lv_batch_name,
                   attribute11   = pv_gtn_update_flag
             WHERE po_header_id = ln_po_header_id;

            COMMIT;
        EXCEPTION
            WHEN exProcess
            THEN
                --Rollback changes to record
                ROLLBACK TO move_rec;

                pv_error_stat   := 'E';
                pv_error_msg    := 'Process: ' || lv_message;
            WHEN OTHERS
            THEN
                --Rollback changes to record
                ROLLBACK TO move_rec;

                pv_error_stat   := 'U';
                pv_error_msg    := SQLERRM;
        END;

        pv_error_stat   := 'S';
        pv_error_msg    := '';
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_stat   := 'U';
            pv_error_msg    := 'Global error : ' || SQLERRM;
    END;

    --Public access function for concurrent request execution. This procedure will move all POs listed in the staging table
    --XXDO.XXD_PO_MASS_MOVE_STG_T to the organization (DC) designated in the parameterpn_organization_id

    PROCEDURE move_po_from_table (pv_error_stat OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pn_organization_id IN NUMBER)
    IS
        lv_error_stat   VARCHAR2 (1);
        lv_error_msg    VARCHAR2 (2000);
        ld_recStart     DATE;
        ln_Diff         NUMBER;
        ln_cnt          NUMBER := 0;
        ln_cnt_errors   NUMBER := 0;

        ln_batch_id     NUMBER;
        lv_batch_name   VARCHAR2 (50);
        ln_request_id   NUMBER := fnd_global.conc_request_id;

        CURSOR c_rec (n_batch_id NUMBER)
        IS
              SELECT *
                FROM XXDO.XXD_PO_MASS_MOVE_STG_T
               WHERE status = 'P' AND batch_id = n_batch_id
            ORDER BY po_number ASC;
    BEGIN
        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'Start : ' || TO_CHAR (SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));

        --   first mark all qualifying records for processing

        --Check if selected organization is a Trade org

        SELECT COUNT (*)
          INTO ln_cnt
          FROM mtl_parameters
         WHERE organization_id = pn_organization_id AND attribute13 = '2';

        IF ln_cnt = 0
        THEN
            pv_error_stat   := 'E';
            pv_error_msg    := 'Invalid destination organization.';
            RETURN;
        END IF;


        --get batch number and batch name
        ln_batch_id     := get_next_batch_id;
        lv_batch_name   := get_batch_name (ln_batch_id);

        UPDATE XXDO.XXD_PO_MASS_MOVE_STG_T
           SET status = 'P', batch_id = ln_batch_id, batch_name = lv_batch_name,
               error_message = NULL, request_id = ln_request_id
         WHERE status = 'R';

        COMMIT;

        --Loop through marked records and process

        FOR rec IN c_rec (ln_batch_id)
        LOOP
            ld_recStart   := SYSDATE;
            fnd_file.PUT_LINE (fnd_file.LOG, 'PO # : ' || rec.po_number);
            fnd_file.PUT_LINE (
                fnd_file.LOG,
                '-Rec start : ' || TO_CHAR (SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));

            fnd_file.PUT_LINE (
                fnd_file.LOG,
                   '--Calling move PO : '
                || rec.po_number
                || ' Org ID : '
                || pn_organization_id
                || ' GTN Upd : '
                || rec.gtn_update_flag
                || ' Batch ID : '
                || ln_batch_id
                || ' Batch Name : '
                || lv_batch_name);

            move_po (lv_error_stat, lv_error_msg, rec.po_number,
                     pn_organization_id, rec.gtn_update_flag, ln_batch_id,
                     lv_batch_name);

            --lv_error_stat := 'E';
            -- lv_error_msg := 'Test error';
            fnd_file.PUT_LINE (fnd_file.LOG, ' - Result : ' || lv_error_stat);
            fnd_file.PUT_LINE (fnd_file.LOG, ' - Msg : ' || lv_error_msg);

            ln_cnt        := ln_cnt + 1;

            CASE
                WHEN lv_error_stat = 'S'
                THEN
                    UPDATE XXDO.XXD_PO_MASS_MOVE_STG_T
                       SET status   = 'S'
                     WHERE po_number = rec.po_number;
                WHEN lv_error_stat = 'E'
                THEN
                    UPDATE XXDO.XXD_PO_MASS_MOVE_STG_T
                       SET status = 'E', error_message = lv_error_msg
                     WHERE po_number = rec.po_number;

                    ln_cnt_errors   := ln_cnt_errors + 1;
                ELSE
                    UPDATE XXDO.XXD_PO_MASS_MOVE_STG_T
                       SET status = 'U', error_message = lv_error_msg
                     WHERE po_number = rec.po_number;

                    ln_cnt_errors   := ln_cnt_errors + 1;
            END CASE;

            ln_Diff       := SYSDATE - ld_recStart;

            fnd_file.PUT_LINE (
                fnd_file.LOG,
                '-Rec end : ' || TO_CHAR (SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
            fnd_file.PUT_LINE (
                fnd_file.LOG,
                '-Rec Time : ' || TRUNC (ln_Diff * 24 * 60 * 60) || ' Sec');
            COMMIT;
        END LOOP;

        fnd_file.PUT_LINE (
            fnd_file.LOG,
            'End : ' || TO_CHAR (SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));

        fnd_file.PUT_LINE (fnd_file.LOG, 'No Records processed : ' || ln_cnt);
        fnd_file.PUT_LINE (fnd_file.LOG, 'No Errors : ' || ln_cnt_errors);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.PUT_LINE (fnd_file.LOG,
                               'Process exception occurred : ' || SQLERRM);
    END;
END xxd_po_mass_move_PO;
/
