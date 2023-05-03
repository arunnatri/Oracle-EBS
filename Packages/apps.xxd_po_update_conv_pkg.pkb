--
-- XXD_PO_UPDATE_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_UPDATE_CONV_PKG"
IS
    PROCEDURE UPDATE_ORDER_ATTRIBUTE (P_SCENARIO IN VARCHAR2, P_PO_NUMBER IN VARCHAR2, P_ERRBUF OUT VARCHAR2
                                      , P_RETCODE OUT NUMBER)
    IS
        CURSOR get_line_id_c IS
                SELECT ola.line_id, pll.line_location_id
                  FROM apps.po_headers_all poh, apps.po_lines_all pol, apps.po_line_locations_all pll,
                       apps.po_distributions_all pod, APPS.hr_operating_units hou, apps.po_requisition_lines_all prla,
                       apps.oe_order_lines_all ola, apps.oe_order_headers_all ooha
                 WHERE     1 = 1
                       AND pll.po_header_id = poh.po_header_id
                       AND pol.po_header_id = poh.po_header_id
                       AND pol.po_header_id = pod.po_header_id
                       AND pol.po_line_id = pll.po_line_id
                       AND pod.po_line_id = pll.po_line_id
                       AND POD.LINE_LOCATION_ID = PLL.LINE_LOCATION_ID
                       --AND poh.authorization_status IN ('APPROVED')
                       AND hou.organization_id = poh.org_id
                       AND hou.name LIKE 'Deckers Macau OU'
                       AND PRLA.ATTRIBUTE14 = POL.ATTRIBUTE15
                       AND TO_CHAR (pll.line_location_id) != ola.attribute16
                       AND ooha.header_id = ola.header_id
                       AND prla.requisition_line_id = ola.source_document_line_id
                       AND EXISTS
                               (SELECT 1
                                  FROM XXD_PO_REQUISITION_CONV_STG_T XPRC
                                 WHERE     XPRC.REQUISITION_NUMBER =
                                           ooha.ORIG_SYS_DOCUMENT_REF
                                       AND XPRC.record_status = 'P' --AND SCENARIO = 'EUROPE'
                                       AND XPRC.scenario = p_scenario)
            FOR UPDATE OF ola.attribute16;

        TYPE get_line_id_TAB IS TABLE OF get_line_id_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        get_line_id_T   get_line_id_TAB;
    BEGIN
        OPEN get_line_id_c;

        LOOP
            FETCH get_line_id_c BULK COLLECT INTO get_line_id_T LIMIT 5000;

            IF get_line_id_T.COUNT > 0
            THEN
                FORALL i IN 1 .. get_line_id_T.COUNT SAVE EXCEPTIONS
                    UPDATE oe_order_lines_all
                       SET attribute16   = get_line_id_T (i).line_location_id
                     WHERE line_id = get_line_id_T (i).line_id;
            ELSE
                EXIT;
            END IF;

            get_line_id_T.DELETE;
        END LOOP;

        CLOSE get_line_id_c;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_line_id_c%ISOPEN
            THEN
                CLOSE get_line_id_c;
            END IF;

            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
            LOOP
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    SQLERRM (-(SQL%BULK_EXCEPTIONS (indx).ERROR_CODE)));
            END LOOP;
    END;

    PROCEDURE UPDATE_EDI_FLAG (P_SCENARIO IN VARCHAR2, P_PO_NUMBER IN VARCHAR2, P_ERRBUF OUT VARCHAR2
                               , P_RETCODE OUT NUMBER)
    IS
        CURSOR cur_update_edi IS
            SELECT DISTINCT pha.po_header_id, XPO.EDI_PROCESSED_FLAG, xpo.EDI_PROCESSED_STATUS
              FROM po_headers_all pha, hr_operating_units hou, XXD_po_REQUISITION_CONV_STG_T XPO
             WHERE     pha.org_id = hou.orgANIZATION_id
                   AND hou.name = 'Deckers Macau OU'
                   AND xpo.PO_NUMBER = pha.segment1
                   AND XPO.po_header_id = pha.attribute15
                   AND SCENARIO = P_SCENARIO
                   AND pha.segment1 = NVL (P_PO_NUMBER, pha.segment1)
                   AND (pha.EDI_PROCESSED_FLAG != xpo.EDI_PROCESSED_FLAG OR pha.EDI_PROCESSED_STATUS != xpo.EDI_PROCESSED_STATUS);
    BEGIN
        FOR i IN CUR_UPDATE_EDI
        LOOP
            UPDATE po_headers_all
               SET EDI_PROCESSED_FLAG = i.EDI_PROCESSED_FLAG, EDI_PROCESSED_STATUS = i.EDI_PROCESSED_STATUS
             WHERE po_header_id = i.po_header_id;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'others while updating edi flag' || SQLERRM);
    END;

    PROCEDURE MAIN_PRC (P_ERRBUF OUT VARCHAR2, P_RETCODE OUT NUMBER, P_SCENARIO IN VARCHAR2
                        , P_RUN_TYPE IN VARCHAR2 DEFAULT NULL, P_PO_NUMBER IN VARCHAR2 DEFAULT NULL, P_ORDER_NUMBER IN VARCHAR2 DEFAULT NULL)
    IS
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'IN MAIN PRC');
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Run type' || P_RUN_TYPE);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'SCENARIO' || P_SCENARIO);

        IF P_RUN_TYPE = 'UPDATE_FLOW_STATUS_CODE'
        THEN
            XXD_UPDATE_FLOW_STATUS_CODE (P_SCENARIO, P_ORDER_NUMBER, P_ERRBUF
                                         , P_RETCODE);
        ELSIF P_RUN_TYPE = 'UPDATE_note_to_receiver'
        THEN
            XXD_UPDATE_note_to_receiver (P_SCENARIO, P_PO_NUMBER, P_ERRBUF,
                                         P_RETCODE);
        ELSIF P_RUN_TYPE = 'UPDATE_NEEDBY_DATE'
        THEN
            XXD_UPDATE_NEEDBY_DATE (P_SCENARIO, P_PO_NUMBER, P_ERRBUF,
                                    P_RETCODE);
        ELSIF P_RUN_TYPE IS NULL OR P_RUN_TYPE = 0
        THEN
            UPDATE_ORDER_ATTRIBUTE (P_SCENARIO, P_PO_NUMBER, P_ERRBUF,
                                    P_RETCODE);
            UPDATE_EDI_FLAG (P_SCENARIO, P_PO_NUMBER, P_ERRBUF,
                             P_RETCODE);
            XXD_UPDATE_note_to_receiver (P_SCENARIO, P_PO_NUMBER, P_ERRBUF,
                                         P_RETCODE);
            XXD_UPDATE_NEEDBY_DATE (P_SCENARIO, P_PO_NUMBER, P_ERRBUF,
                                    P_RETCODE);
            XXD_UPDATE_FLOW_STATUS_CODE (P_SCENARIO, P_ORDER_NUMBER, P_ERRBUF
                                         , P_RETCODE);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.put_line (FND_FILE.LOG,
                               ' Error in the base script : ' || SQLERRM);
            p_errbuf    := SUBSTR (SQLERRM, 1, 250);
            p_retcode   := 2;
            FND_FILE.put_line (FND_FILE.LOG, 'errbuf => ' || p_errbuf);
            ROLLBACK;
    END;

    PROCEDURE XXD_UPDATE_FLOW_STATUS_CODE (P_SCENARIO IN VARCHAR2, P_ORDER_NUMBER IN VARCHAR2, P_ERRBUF OUT VARCHAR2
                                           , P_RETCODE OUT NUMBER)
    AS
        l_line_id                NUMBER;
        l_org_id                 NUMBER;
        l_result                 VARCHAR2 (30);
        l_activity_id            NUMBER;
        l_file_val               VARCHAR2 (1000);
        l_activity_status_code   VARCHAR2 (8);
        l_ret_status             NUMBER;


        CURSOR issue_lines IS
              SELECT OLA.line_id, OLA.header_id, oha.order_number,
                     ola.flow_status_code, ola.line_number
                FROM mtl_reservations mr, oe_order_lines_all OLA, OE_ORDER_HEADERS_ALL OHA,
                     APPS.hr_operating_units hou, po_requisition_lines_all prla, po_line_locations_all plla,
                     po_lines_all pla, po_headers_all pha, xxd_conv.XXD_PO_REQUISITION_CONV_STG_T xprc
               WHERE     OHA.HEADER_ID = OLA.HEADER_ID
                     AND hou.organization_id = oha.org_id
                     AND mr.DEMAND_SOURCE_LINE_ID = ola.line_id
                     AND mr.ORIG_SUPPLY_SOURCE_LINE_ID =
                         prla.REQUISITION_LINE_ID
                     AND mr.SUPPLY_SOURCE_TYPE_ID = 1
                     AND hou.name = 'Deckers Macau OU'
                     AND prla.line_location_id = ola.attribute16
                     --and ola.line_id = 665883
                     AND prla.note_to_agent LIKE '%' || oha.order_number || '%'
                     AND ola.booked_flag = 'Y'
                     AND NVL (ola.open_flag, 'X') = 'Y'
                     AND UPPER (ola.flow_status_code) =
                         UPPER ('EXTERNAL_REQ_OPEN')
                     AND oha.order_number =
                         NVL (P_ORDER_NUMBER, oha.order_number)
                     --and oha.order_number = '61828' --'50498995'
                     AND plla.line_location_id = prla.line_location_id
                     AND pla.po_line_id = plla.po_line_id
                     AND plla.po_header_id = pha.po_header_id
                     AND pha.org_id = oha.org_id
                     AND pha.AUTHORIZATION_STATUS = 'APPROVED'
                     -- AND NVL (xprc.order_number, xprc.po_number) =
                     --  oha.order_number
                     AND xprc.po_number = pha.segment1
                     AND xprc.po_line_id = pla.attribute15
                     AND XPRC.record_status = 'P'
                     AND SCENARIO = P_SCENARIO
                     AND EXISTS
                             (SELECT 1
                                FROM wf_item_activity_statuses wias, wf_process_activities wpa
                               WHERE     wias.item_type = 'OEOL'
                                     AND wias.item_key = TO_CHAR (ola.line_id)
                                     AND wias.process_activity =
                                         wpa.instance_id
                                     AND wpa.activity_name = 'SHIP_LINE'
                                     AND wias.activity_status IN ('NOTIFIED'))
            ORDER BY line_number;
    BEGIN
        FND_FILE.put_line (FND_FILE.LOG, 'Processing...');
        mo_global.init ('ONT');                            -- Required for R12
        mo_global.set_policy_context ('S', 99);            -- Required for R12
        oe_debug_pub.debug_on;
        oe_debug_pub.initialize;
        l_file_val   := OE_DEBUG_PUB.Set_Debug_Mode ('FILE');

        oe_Debug_pub.setdebuglevel (5);
        fnd_profile.PUT ('ONT_DEBUG_LEVEL', '5');

        FND_FILE.put_line (FND_FILE.LOG, 'File : ' || l_file_val);

        FND_FILE.put_line (
            FND_FILE.LOG,
               RPAD ('Order Number', 15)
            || CHR (9)
            || CHR (9)
            || RPAD ('Line Number', 5)
            || CHR (9)
            || CHR (9)
            || RPAD ('Flow Status Code', 30)
            || CHR (9)
            || CHR (9)
            || RPAD ('PO Number', 15)
            || CHR (9)
            || CHR (9)
            || RPAD ('PO Line Number', 5));
        FND_FILE.put_line (
            FND_FILE.LOG,
               RPAD ('------------', 15)
            || CHR (9)
            || CHR (9)
            || RPAD ('-----------', 5)
            || CHR (9)
            || CHR (9)
            || RPAD ('----------------', 30));

        FOR b2b_lines IN issue_lines
        LOOP
            FND_FILE.put_line (
                FND_FILE.LOG,
                   RPAD (b2b_lines.ORDER_NUMBER, 15)
                || CHR (9)
                || CHR (9)
                || RPAD (b2b_lines.LINE_NUMBER, 5)
                || CHR (9)
                || CHR (9)
                || RPAD (b2b_lines.flow_status_code, 30));



            l_line_id   := b2b_lines.line_id;


            OE_Standard_WF.OEOL_SELECTOR (p_itemtype   => 'OEOL',
                                          p_itemkey    => TO_CHAR (l_line_id),
                                          p_actid      => 12345 --- this is a constant , do not change
                                                               ,
                                          p_funcmode   => 'SET_CTX',
                                          p_result     => l_result);

            FND_FILE.put_line (FND_FILE.LOG, 'Result: ' || l_result);

            oe_debug_pub.ADD ('Before the call');
            l_ret_status   :=
                CTO_WORKFLOW_API_PK.display_wf_status (l_line_id);
            oe_debug_pub.ADD ('After the call');

            FND_FILE.put_line (FND_FILE.LOG, 'returned::' || l_ret_status);
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.put_line (FND_FILE.LOG,
                               ' Error in the base script : ' || SQLERRM);
            p_errbuf    := SUBSTR (SQLERRM, 1, 250);
            p_retcode   := 2;
            FND_FILE.put_line (FND_FILE.LOG, 'errbuf => ' || p_errbuf);
            ROLLBACK;
    END;

    PROCEDURE XXD_UPDATE_note_to_receiver (P_SCENARIO IN VARCHAR2, P_PO_NUMBER IN VARCHAR2, P_ERRBUF OUT VARCHAR2
                                           , P_RETCODE OUT NUMBER)
    IS
        CURSOR get_line_id_c IS
            SELECT plla.line_location_id, prla.note_to_receiver, XPRC.NEED_BY_DATE
              FROM                                     -- mtl_reservations mr,
                   oe_order_lines_all OLA, OE_ORDER_HEADERS_ALL OHA, APPS.hr_operating_units hou,
                   po_requisition_lines_all prla, po_line_locations_all plla, po_lines_all pla,
                   po_headers_all pha, xxd_conv.XXD_PO_REQUISITION_CONV_STG_T xprc
             WHERE     OHA.HEADER_ID = OLA.HEADER_ID
                   AND hou.organization_id = oha.org_id
                   -- AND mr.DEMAND_SOURCE_LINE_ID = ola.line_id
                   -- AND mr.ORIG_SUPPLY_SOURCE_LINE_ID = prla.REQUISITION_LINE_ID
                   -- AND mr.SUPPLY_SOURCE_TYPE_ID = 1
                   AND hou.name = 'Deckers Macau OU'
                   AND prla.line_location_id = ola.attribute16
                   --and ola.line_id = 665883
                   AND prla.note_to_agent LIKE '%' || oha.order_number || '%'
                   AND prla.note_to_receiver !=
                       NVL (plla.note_to_receiver, 'ABC')
                   --and oha.order_number = '61828' --'50498995'
                   AND plla.line_location_id = prla.line_location_id
                   AND pla.po_line_id = plla.po_line_id
                   AND plla.po_header_id = pha.po_header_id
                   AND pha.org_id = oha.org_id
                   AND pha.segment1 = NVL (P_PO_NUMBER, pha.segment1)
                   -- AND pha.AUTHORIZATION_STATUS = 'APPROVED'
                   --AND NVL (xprc.order_number, xprc.po_number) =
                   --  oha.order_number
                   AND xprc.po_number = pha.segment1
                   AND xprc.po_line_id = pla.attribute15
                   AND XPRC.record_status = 'P'
                   AND SCENARIO = NVL (P_SCENARIO, SCENARIO);

        TYPE get_line_id_TAB IS TABLE OF get_line_id_c%ROWTYPE
            INDEX BY BINARY_INTEGER;

        get_line_id_T   get_line_id_TAB;
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'In Note_to_receiver_update');

        OPEN get_line_id_c;

        LOOP
            FETCH get_line_id_c BULK COLLECT INTO get_line_id_T LIMIT 5000;

            IF get_line_id_T.COUNT > 0
            THEN
                FND_FILE.PUT_LINE (FND_FILE.LOG, 'IN LOOP');

                FORALL i IN 1 .. get_line_id_T.COUNT SAVE EXCEPTIONS
                    UPDATE po_line_locations_all
                       SET note_to_receiver = get_line_id_T (i).note_to_receiver
                     WHERE line_location_id =
                           get_line_id_T (i).line_location_id;
            ELSE
                EXIT;
            END IF;

            get_line_id_T.DELETE;
        END LOOP;

        CLOSE get_line_id_c;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_line_id_c%ISOPEN
            THEN
                CLOSE get_line_id_c;
            END IF;

            FOR indx IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
            LOOP
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    SQLERRM (-(SQL%BULK_EXCEPTIONS (indx).ERROR_CODE)));
            END LOOP;

            ROLLBACK;
    END;

    PROCEDURE XXD_UPDATE_NEEDBY_DATE (P_SCENARIO IN VARCHAR2, P_PO_NUMBER IN VARCHAR2, P_ERRBUF OUT VARCHAR2
                                      , P_RETCODE OUT NUMBER)
    IS
        v_resp_appl_id     NUMBER;
        v_resp_id          NUMBER;
        v_user_id          NUMBER;
        l_result           NUMBER;
        V_LINE_NUM         NUMBER;
        V_SHIPMENT_NUM     NUMBER;
        V_REVISION_NUM     NUMBER;
        l_api_errors       PO_API_ERRORS_REC_TYPE;

        CURSOR cur_po_headers IS
              SELECT poh.segment1 po_num, poh.po_header_id, prha.segment1 requisition_num,
                     prla.line_num requisition_line_num, plla.shipment_num, prla.need_by_date,
                     xprc.promised_date, poh.org_id, pla.line_num,
                     poh.agent_id, pdt.document_subtype, pdt.document_type_code,
                     poh.wf_item_key
                FROM po_headers_all poh, po_requisition_headers_all prha, po_requisition_lines_all prla,
                     po_distributions_all pda, po_line_locations_all plla, PO_LINES_ALL pla,
                     po_req_distributions_all prda, po_document_types_all pdt, APPS.hr_operating_units hou,
                     xxd_conv.XXD_PO_REQUISITION_CONV_STG_T xprc
               WHERE     1 = 1
                     AND (prla.need_by_date != plla.need_by_date OR xprc.promised_date != plla.promised_date)
                     AND pda.po_header_id = poh.po_header_id
                     AND plla.po_header_id = poh.po_header_id
                     AND pla.po_header_id = poh.po_header_id
                     AND plla.PO_LINE_ID = pla.PO_LINE_ID
                     AND plla.line_location_id = pda.line_location_id
                     AND pda.req_distribution_id = prda.distribution_id
                     AND prda.requisition_line_id = prla.requisition_line_id
                     AND prla.requisition_header_id =
                         prha.requisition_header_id
                     AND pdt.org_id = poh.org_id
                     AND poh.type_lookup_code = pdt.document_subtype
                     AND pdt.document_type_code = 'PO'
                     -- AND POH.AUTHORIZATION_STATUS = 'APPROVED'
                     AND hou.organization_id = POH.org_id
                     AND hou.name = 'Deckers Macau OU'
                     AND xprc.po_number = POH.segment1
                     AND xprc.po_line_id = pla.attribute15
                     AND XPRC.record_status = 'P'
                     AND POH.segment1 = NVL (P_PO_NUMBER, POH.segment1)
                     AND SCENARIO = NVL (P_SCENARIO, SCENARIO)
            ORDER BY poh.segment1, pla.line_num;

        CURSOR cur_po_appr IS
            SELECT poh.segment1 po_num, poh.po_header_id, poh.org_id,
                   poh.agent_id, poh.wf_item_key
              FROM po_headers_all poh, APPS.hr_operating_units hou
             WHERE     1 = 1
                   AND hou.organization_id = POH.org_id
                   AND hou.name = 'Deckers Macau OU'
                   AND POH.AUTHORIZATION_STATUS != 'APPROVED'
                   AND POH.segment1 = NVL (P_PO_NUMBER, POH.segment1)
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_conv.XXD_PO_REQUISITION_CONV_STG_T xprc, po_lines_all pla
                             WHERE     xprc.po_number = POH.segment1
                                   AND pla.po_header_id = poh.po_header_id
                                   AND xprc.po_line_id = pla.attribute15
                                   AND XPRC.record_status = 'P'
                                   AND SCENARIO = NVL (P_SCENARIO, SCENARIO))
            MINUS
            SELECT DISTINCT poh.segment1 po_num, poh.po_header_id, poh.org_id,
                            poh.agent_id, poh.wf_item_key
              FROM po_headers_all poh, po_requisition_headers_all prha, po_requisition_lines_all prla,
                   po_distributions_all pda, po_line_locations_all plla, PO_LINES_ALL pla,
                   po_req_distributions_all prda, po_document_types_all pdt, APPS.hr_operating_units hou,
                   xxd_conv.XXD_PO_REQUISITION_CONV_STG_T xprc
             WHERE     1 = 1
                   AND (prla.need_by_date != plla.need_by_date OR xprc.promised_date != plla.promised_date)
                   AND pda.po_header_id = poh.po_header_id
                   AND plla.po_header_id = poh.po_header_id
                   AND pla.po_header_id = poh.po_header_id
                   AND plla.PO_LINE_ID = pla.PO_LINE_ID
                   AND plla.line_location_id = pda.line_location_id
                   AND pda.req_distribution_id = prda.distribution_id
                   AND prda.requisition_line_id = prla.requisition_line_id
                   AND prla.requisition_header_id =
                       prha.requisition_header_id
                   AND pdt.org_id = poh.org_id
                   AND poh.type_lookup_code = pdt.document_subtype
                   AND pdt.document_type_code = 'PO'
                   AND hou.organization_id = POH.org_id
                   AND hou.name = 'Deckers Macau OU'
                   AND xprc.po_number = POH.segment1
                   AND xprc.po_line_id = pla.attribute15
                   AND XPRC.record_status = 'P'
                   AND POH.segment1 = NVL (P_PO_NUMBER, POH.segment1)
                   AND SCENARIO = NVL (P_SCENARIO, SCENARIO);

        cur_po_appr_rec    cur_po_appr%ROWTYPE;

        TYPE cur_po_headers_TAB IS TABLE OF cur_po_headers%ROWTYPE
            INDEX BY BINARY_INTEGER;

        cur_po_headers_T   cur_po_headers_TAB;
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'In Needby_date_update');
        mo_global.init ('ONT');                            -- Required for R12
        mo_global.set_policy_context ('S', 99);            -- Required for R12

        OPEN cur_po_headers;

        LOOP
            FETCH cur_po_headers
                BULK COLLECT INTO cur_po_headers_T
                LIMIT 5000;

            FND_FILE.PUT_LINE (FND_FILE.LOG, 'after line loop');
            EXIT WHEN cur_po_headers_T.COUNT = 0;
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'after exit');

            -- IF cur_po_headers_T.COUNT >0
            -- THEN
            FOR i IN cur_po_headers_T.FIRST .. cur_po_headers_T.LAST
            LOOP
                SELECT NVL (REVISION_NUM, 0)
                  INTO V_REVISION_NUM
                  FROM PO_HEADERS_ALL
                 WHERE     SEGMENT1 = cur_po_headers_t (i).po_num
                       AND ORG_ID = cur_po_headers_t (i).ORG_ID;

                BEGIN
                    l_result   :=
                        po_change_api1_s.update_po (
                            x_po_number             => cur_po_headers_t (i).po_num,
                            x_release_number        => NULL,
                            x_revision_number       => V_revision_num,
                            x_line_number           =>
                                cur_po_headers_t (i).line_num,
                            x_shipment_number       =>
                                cur_po_headers_t (i).SHIPMENT_NUM,
                            new_quantity            => NULL,
                            new_price               => NULL,
                            new_promised_date       =>
                                cur_po_headers_t (i).promised_date,
                            new_need_by_date        =>
                                cur_po_headers_t (i).need_by_date,
                            launch_approvals_flag   => 'N',                 --
                            update_source           => NULL,
                            version                 => '1.0',
                            x_override_date         => NULL,
                            x_api_errors            => l_api_errors,
                            p_buyer_name            => NULL,
                            p_secondary_quantity    => NULL,
                            p_preferred_grade       => NULL,
                            p_org_id                =>
                                cur_po_headers_t (i).ORG_ID);


                    IF l_result <> 1
                    THEN
                        FOR i IN 1 .. l_api_errors.MESSAGE_TEXT.COUNT
                        LOOP
                            P_ERRBUF   :=
                                P_ERRBUF || l_api_errors.MESSAGE_TEXT (i);
                        -- || FND_MSG_PUB.Get (p_msg_index => i, p_encoded => 'F');
                        END LOOP;

                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'update api error PO#'
                            || cur_po_headers_t (i).po_num
                            || ' line_num:'
                            || cur_po_headers_t (i).line_num
                            || P_ERRBUF);
                        P_RETCODE   := 1;
                    ELSE
                        -- P_RETCODE := 0;
                        P_ERRBUF   := NULL;
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'update api success PO#'
                            || cur_po_headers_t (i).po_num
                            || ' line_num:'
                            || cur_po_headers_t (i).line_num);
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        P_ERRBUF    := 'When others API' || SQLERRM;
                        P_RETCODE   := 1;
                        FND_FILE.PUT_LINE (FND_FILE.LOG, P_ERRBUF);
                -- return;
                END;
            END LOOP;
        --       cur_po_headers_t.DELETE;
        --ELSE
        -- EXIT;
        -- END IF;
        END LOOP;

        CLOSE cur_po_headers;



        OPEN cur_po_appr;

        LOOP
            FETCH cur_po_appr INTO cur_po_appr_rec;

            EXIT WHEN cur_po_appr%NOTFOUND;
            po_reqapproval_init1.start_wf_process (
                ItemType                 => 'POAPPRV',
                ItemKey                  => cur_po_appr_rec.wf_item_key,
                WorkflowProcess          => 'XXDO_POAPPRV_TOP',
                ActionOriginatedFrom     => 'PO_FORM',
                DocumentID               => cur_po_appr_rec.po_header_id -- po_header_id
                                                                        ,
                DocumentNumber           => cur_po_appr_rec.po_num -- Purchase Order Number
                                                                  ,
                PreparerID               => cur_po_appr_rec.agent_id -- Buyer/Preparer_id
                                                                    ,
                DocumentTypeCode         => 'PO'                        --'PO'
                                                ,
                DocumentSubtype          => 'STANDARD'            --'STANDARD'
                                                      ,
                SubmitterAction          => 'APPROVE',
                forwardToID              => NULL,
                forwardFromID            => NULL,
                DefaultApprovalPathID    => NULL,
                Note                     => NULL,
                PrintFlag                => 'N',
                FaxFlag                  => 'N',
                FaxNumber                => NULL,
                EmailFlag                => 'N',
                EmailAddress             => NULL,
                CreateSourcingRule       => 'N',
                ReleaseGenMethod         => 'N',
                UpdateSourcingRule       => 'N',
                MassUpdateReleases       => 'N',
                RetroactivePriceChange   => 'N',
                OrgAssignChange          => 'N',
                CommunicatePriceChange   => 'N',
                p_Background_Flag        => 'N',
                p_Initiator              => NULL,
                p_xml_flag               => NULL,
                FpdsngFlag               => 'N',
                p_source_type_code       => NULL);
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'wf approval success: ' || cur_po_appr_rec.po_num);
        END LOOP;

        CLOSE cur_po_appr;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF cur_po_appr%ISOPEN
            THEN
                CLOSE cur_po_appr;
            END IF;

            IF cur_po_headers%ISOPEN
            THEN
                CLOSE cur_po_headers;
            END IF;

            P_RETCODE   := 1;
            P_ERRBUF    := P_ERRBUF || SQLERRM;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'need by date update error' || P_ERRBUF);
            ROLLBACK;
    END XXD_UPDATE_NEEDBY_DATE;
END;
/
